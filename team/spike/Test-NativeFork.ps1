# A paid, real DSH capability probe. Never part of the offline Pester suite.
# It records facts and hashes only; native stderr remains in its private TEMP directory.
#requires -Version 7.4
[CmdletBinding()]
param([int]$TimeoutSeconds = 180)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../scripts/Core.ps1')
. (Join-Path $PSScriptRoot '../scripts/Preflight.ps1')
$root=Join-Path ([IO.Path]::GetTempPath()) ('team-fork-inheritance-'+[guid]::NewGuid().ToString('N').Substring(0,10))
[IO.Directory]::CreateDirectory($root) | Out-Null
$manifest=Read-TeamData (Join-Path $script:TeamRoot 'manifest.yaml')
$doctor=Test-TeamDoctor $manifest $root
if (-not $doctor.success) { Stop-TeamError 20 ($doctor.problems -join '; ') }
Assert-TeamCapability @{mode='L3'} $doctor
Write-TeamData (Join-Path $root 'preflight.json') $doctor
$nativeRoot=Join-Path (Split-Path (Get-Command dsh).Source -Parent) 'node_modules/@deepseek-ai/dsh/node_modules'
$llm=Join-Path $nativeRoot '@deepseek-ai/dsh-llm/lib/index.js'
if (-not (Test-Path -LiteralPath $llm)) { Stop-TeamError 20 'Cannot locate the installed native DSH message helper' }
$marker='FORK_MEMORY_'+[guid]::NewGuid().ToString('N')
$patchPath=Join-Path $root 'patch.json'
$guard=@{maxAgents=2;maxDepth=2;cwd=$root;provider=$manifest.models.worker.provider;model=$manifest.models.worker.runtime_model;
    receipt=(Join-Path $root 'agents.json');budgetControl=(Join-Path $root 'budget.json')}
Write-TeamData $guard.budgetControl @{stop_new_children=$false}
New-DshPatch $patchPath $guard
$patch=@(Read-TeamData $patchPath)
$patch+=@{insert=@(@{id='team-fork-inheritance-probe';name=(Join-Path $PSScriptRoot 'native-fork-probe.mjs');config=@{
    marker=$marker;llmModule=([uri]$llm).AbsoluteUri;evidence=(Join-Path $root 'inheritance.json')}})}
Write-TeamData $patchPath $patch
$prompt=@'
This is the second turn of a native fork acceptance probe. Invoke subagent_fork exactly once, foreground.
Ask the child to recall the synthetic acceptance marker from the PREVIOUS COMPLETED conversation turn
and reply with only that marker. Do not include the marker value in the child's task, persona, or any tool argument.
Tell the child to use no tools and read no files: it must answer solely from inherited conversation context.
Do not invoke fresh subagent, shell, files, or any other tools. Do not write or commit anything.
After the child returns, reply only FORK_PROBE_DONE.
'@
$handle=$null
try {
    $handle=Start-TeamDshProcess $root $root @('--profile','headless','--patch',$patchPath,$prompt) 1MB
    $exitCode=Wait-TeamProcess $handle $TimeoutSeconds 90
    if ($exitCode -ne 0) { Stop-TeamError 30 "Native fork probe exited $exitCode; evidence directory: $root" }
    $facts=Read-TeamData (Join-Path $root 'inheritance.json')
    $agents=Read-TeamData $guard.receipt
    $child=@($facts.children)
    $passed=$facts.parent.completed -and $facts.parent.tool_calls -eq 0 -and $child.Count -eq 1 -and
        $child[0].seed_events -gt 0 -and $child[0].seed_last_type -eq 'turn/end' -and
        $child[0].seed_contains_marker -and $child[0].prompt_contains_marker -eq $false -and
        $child[0].completed -and $child[0].recalled_marker -and $child[0].own_tool_calls -eq 0 -and
        $agents.agents.Count -eq 2 -and $child[0].depth -eq 1
    $result=@{passed=$passed;native_exit_code=$exitCode;directory=$root;facts=$facts;
        guard_sha256=(Get-TeamHash $guard.receipt);evidence_sha256=(Get-TeamHash (Join-Path $root 'inheritance.json'));
        stdout_sha256=(Get-TeamHash (Join-Path $root 'worker.stdout'))}
    Write-TeamData (Join-Path $root 'acceptance.json') $result
    $result | ConvertTo-Json -Depth 20 -Compress
    if (-not $passed) { exit 1 }
} finally {
    if ($handle -and -not $handle.closed) { $null=Close-TeamProcess $handle -Terminate }
}
