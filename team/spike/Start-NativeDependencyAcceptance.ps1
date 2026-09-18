# Prepare and optionally launch paid native multi-worker dependency acceptance.
# Later accept/integrate/resume decisions remain with the Lead after inspecting evidence.
#requires -Version 7.4
param([switch]$PrepareOnly, [string]$RunId='DAG-NATIVE-014')
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../scripts/Core.ps1')
Assert-TeamId $RunId
$root=Join-Path ([IO.Path]::GetTempPath()) ('team-native-dag-'+[guid]::NewGuid().ToString('N').Substring(0,10))
$repo=Join-Path $root 'repo'; [IO.Directory]::CreateDirectory($repo) | Out-Null
$null=Invoke-TeamGit $repo @('init','-q','-b','main')
$null=Invoke-TeamGit $repo @('config','user.name','Team Native Acceptance')
$null=Invoke-TeamGit $repo @('config','user.email','fixture@example.invalid')
$null=Invoke-TeamGit $repo @('config','core.autocrlf','false')
[IO.File]::WriteAllText((Join-Path $repo '.gitignore'),"team/runtime/`n.worktrees/`n",[Text.UTF8Encoding]::new($false))
$rules=@'
# Native dependency fixture
Use PowerShell. Only change and commit the assigned source file. Never change verification.ps1 or this contract.
Read-only native children may inspect the supplied contract and source, but cannot write, use network, access secrets or create further children.
Independent Local Review must not use tools, write files or run tests; request any extra execution as Verification Needed.
No production or external system is involved. Preserve the prewritten verification contract.
'@
[IO.File]::WriteAllText((Join-Path $repo 'AGENTS.md'),$rules,[Text.UTF8Encoding]::new($false))
$verify=@'
param([ValidateSet('label','total','summary','all')][string]$Stage='all')
$ErrorActionPreference='Stop'
function Assert-Value($Actual,$Expected,[string]$Case) {
    if ($Actual -cne $Expected) { throw "Contract failed: $Case; expected [$Expected], actual [$Actual]" }
}
if ($Stage -in @('label','all')) {
    . (Join-Path $PSScriptRoot 'src/label.ps1')
    Assert-Value (Get-TeamLabel $null) 'anonymous' 'null label'
    Assert-Value (Get-TeamLabel '') 'anonymous' 'empty label'
    Assert-Value (Get-TeamLabel " `t`r`n") 'anonymous' 'blank label'
    Assert-Value (Get-TeamLabel '  Lily  ') 'Lily' 'trim label'
    Assert-Value (Get-TeamLabel '  你好  ') '你好' 'Chinese label'
    Write-Output 'LABEL_CONTRACT_PASS: 5 cases'
}
if ($Stage -in @('total','all')) {
    . (Join-Path $PSScriptRoot 'src/total.ps1')
    Assert-Value (Get-TeamTotal $null) ([decimal]0) 'null amounts'
    Assert-Value (Get-TeamTotal @()) ([decimal]0) 'empty amounts'
    Assert-Value (Get-TeamTotal @(1,2,3)) ([decimal]6) 'integers'
    Assert-Value (Get-TeamTotal @([decimal]1.25,[decimal]2.5)) ([decimal]3.75) 'fractions'
    Assert-Value (Get-TeamTotal @(-5,2)) ([decimal](-3)) 'signed values'
    Write-Output 'TOTAL_CONTRACT_PASS: 5 cases'
}
if ($Stage -in @('summary','all')) {
    . (Join-Path $PSScriptRoot 'src/summary.ps1')
    Assert-Value (Get-TeamSummary -Label '  Lily ' -Amounts @(1,2,3)) 'Lily|6' 'combined report'
    Assert-Value (Get-TeamSummary -Label $null -Amounts @()) 'anonymous|0' 'empty report'
    Assert-Value (Get-TeamSummary -Label '  你好 ' -Amounts @([decimal]1.25,[decimal]2.5)) '你好|3.75' 'Chinese fractions'
    $oldCulture=[Threading.Thread]::CurrentThread.CurrentCulture
    try {
        [Threading.Thread]::CurrentThread.CurrentCulture=[Globalization.CultureInfo]::GetCultureInfo('de-DE')
        Assert-Value (Get-TeamSummary -Label 'x' -Amounts @([decimal]1.25)) 'x|1.25' 'culture-independent report'
    } finally { [Threading.Thread]::CurrentThread.CurrentCulture=$oldCulture }
    Write-Output 'SUMMARY_CONTRACT_PASS: 4 cases'
}
'@
[IO.File]::WriteAllText((Join-Path $repo 'verification.ps1'),$verify,[Text.UTF8Encoding]::new($false))
$null=Invoke-TeamGit $repo @('add','--','.gitignore','AGENTS.md','verification.ps1')
$null=Invoke-TeamGit $repo @('commit','-qm','test: seed native dependency contracts')
$base=Invoke-TeamGit $repo @('rev-parse','HEAD')
$plan=Read-TeamData (Join-Path $script:TeamRoot 'tests/plans/L1-sql.yaml')
$plan.run.id=$RunId; $plan.mode='L3'; $plan.capabilities=@('backend')
$plan.classification.reasons=@('Isolated native concurrency, child budget, and dependency acceptance')
$template=$plan.tasks[0] | ConvertTo-Json -Depth 30
$child='Before implementing, use exactly one native fresh subagent to independently inspect the edge cases in this task and verification.ps1. Give it read-only instructions: no writing, network, credentials, production or further delegation. Wait for its answer. You implement and commit the source yourself. Record one fresh depth-1 child with shell=true and other permissions=false, write_scope=[] in Result.subagents_used.'
$definitions=@(
    @{id='LABEL';file='src/label.ps1';stage='label';dependencies=@();children=$true;objective=@(
        'Implement Get-TeamLabel([string]$Label) in src/label.ps1. Return trimmed text; null, empty and whitespace-only values return anonymous. Preserve Unicode.', $child)},
    @{id='TOTAL';file='src/total.ps1';stage='total';dependencies=@();children=$true;objective=@(
        'Implement Get-TeamTotal([decimal[]]$Amounts) in src/total.ps1. Return a decimal sum; null and empty arrays return decimal zero. Preserve fractions and accept negative values.', $child)},
    @{id='SUMMARY';file='src/summary.ps1';stage='summary';dependencies=@('LABEL','TOTAL');children=$false;objective=@(
        'Implement Get-TeamSummary([string]$Label,[decimal[]]$Amounts) in src/summary.ps1. Dot-source the already integrated label.ps1 and total.ps1 via PSScriptRoot. Call their existing functions; do not duplicate them. Return label|total using invariant-culture formatting, even under de-DE. Do not edit upstream source files.')}
)
$plan.tasks=@($definitions | ForEach-Object {
    $task=ConvertFrom-Json $template -AsHashtable; $task.id=$_.id; $task.role='backend'; $task.write_scope=@($_.file)
    $task.dependencies=$_.dependencies; $task.objective=$_.objective+@('Run only the assigned verification stage, preserve all original tests and commit only your assigned file on the assigned branch.')
    $task.acceptance=@('All fixed cases for the assigned verification stage pass; clean committed snapshot and scope compliance.')
    $task.subagents=@{allowed=$_.children;max_depth=$(if ($_.children) {2} else {0})}
    $task.verification=@(@{id=$_.stage;executable='pwsh';args=@('-NoProfile','-File','verification.ps1','-Stage',$_.stage);timeout_seconds=20})
    $task
})
$plan.verification.final=@(@{id='all';executable='pwsh';args=@('-NoProfile','-File','verification.ps1','-Stage','all');timeout_seconds=20})
$manifest=Read-TeamData (Join-Path $script:TeamRoot 'manifest.yaml')
$manifest.runtime.timeout_seconds=900; $manifest.runtime.idle_timeout_seconds=300; $manifest.runtime.max_single_log_mb=8
$manifest.budget.max_active_workers=2
$planPath=Join-Path $root 'plan.json'; $manifestPath=Join-Path $root 'manifest.json'
Write-TeamData $planPath $plan; Write-TeamData $manifestPath $manifest
$descriptor=@{root=$root;repo=$repo;run_id=$plan.run.id;base=$base;plan=$planPath;manifest=$manifestPath;
    verification_sha256=(Get-TeamHash (Join-Path $repo 'verification.ps1'))}
Write-TeamData (Join-Path $root 'fixture.json') $descriptor
$descriptor | ConvertTo-Json -Compress
if (-not $PrepareOnly) {
    & pwsh -NoProfile -File (Join-Path $script:TeamRoot 'scripts/team.ps1') run -Repo $repo -Plan $planPath -Manifest $manifestPath -Json
    exit $LASTEXITCODE
}
