# Deterministic native-CLI stand-in, used ONLY by isolated runtime tests.
if ($args -contains '--version') { Write-Output $(if ($env:TEAM_FIXTURE_VERSION) {$env:TEAM_FIXTURE_VERSION} else {'0.1.5-rc.1'}); exit 0 }
if ($args -contains '--dump-config') {
    $nodes=@(@{id='agent-default-model';config=@{provider='deepseek-official';model='deepseek-flash'}},@{id='llm-deepseek'},@{id='headless-startup'},@{id='headless-runner'})
    foreach ($id in @('subagent','subagent-spawn-in-process','subagent-fork-in-process')) { $nodes+=@{id=$id} }
    $patchIndex=[array]::IndexOf($args,'--patch')
    $patch=if ($patchIndex -ge 0) {Get-Content -LiteralPath $args[$patchIndex+1] -Raw | ConvertFrom-Json -AsHashtable} else {@()}
    foreach ($id in @('tool-subagent','tool-subagent-fork')) {
        $override=@($patch | Where-Object { $_['id'] -eq $id })
        $nodes+=@{id=$id;disabled=($env:TEAM_FIXTURE_NO_NATIVE -eq '1' -or ($override.Count -gt 0 -and $override[0].disabled))}
    }
    $nodes | ConvertTo-Json -Depth 10 -Compress
    exit 0
}
$patchIndex = [array]::IndexOf($args, '--patch')
$patch = Get-Content -LiteralPath $args[$patchIndex + 1] -Raw | ConvertFrom-Json -AsHashtable
$guard = @($patch | Where-Object { $_.ContainsKey('insert') })[0].insert[0].config
$prompt = $args[-1]
if ($prompt -match '^Perform DSH LOCAL_REVIEW') {
    $localTask=(($prompt -split 'Task packet:',2)[1] -split '(?m)^Base:',2)[0] | ConvertFrom-Json -AsHashtable
    if (-not $guard.readOnly -or $guard.maxAgents -ne 1 -or $guard.maxDepth -ne 0) { exit 7 }
    @{schema_version=1;agents=@(@{id='fixture-local-review';depth=0;state='created';read_only=$true;provider='deepseek-official';model='deepseek-flash';cwd=(Get-Location).Path})} |
        ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $guard.receipt -Encoding utf8NoBOM
    if ($localTask.objective[0] -eq 'LOCAL_SLEEP') { Start-Sleep -Seconds 30 }
    if ($localTask.objective[0] -eq 'LOCAL_WAIT') {
        $release=Join-Path (Split-Path $guard.receipt -Parent) 'release.test'
        $deadline=[DateTime]::UtcNow.AddSeconds(40)
        while (-not (Test-Path $release) -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 100 }
        if (-not (Test-Path $release)) { exit 8 }
    }
    if ($localTask.objective[0] -eq 'LOCAL_INVALID') { Write-Output 'invalid local verdict'; exit 0 }
    if ($localTask.objective[0] -eq 'LOCAL_WRITE') { Set-Content 'forbidden-review.txt' 'invalid mutation' }
    $issues=@(); $needed=@()
    if ($localTask.objective[0] -eq 'LOCAL_FAIL') { $issues=@(@{id='LOCAL-001';consequence='Synthetic local defect';evidence='Fixture input counterexample';caused_by_last_fix='no'}) }
    if ($localTask.objective[0] -eq 'LOCAL_VN') { $needed=@('Check the fixture evidence') }
    @{verdict=$(if ($issues.Count) {'fail'} else {'pass'});blocking_issues=$issues;verification_needed=$needed;writes_performed=$false} | ConvertTo-Json -Depth 20
    exit 0
}
$packet = ($prompt -split 'Task packet:',2)[1] -split 'Result schema:',2
$task = $packet[0] | ConvertFrom-Json -AsHashtable
if (-not $task.role.definition -or $task.role.definition.role_id -cne $task.role.id) { exit 7 }
if ($task.objective[0] -eq 'FLOOD') { [Console]::Out.Write('x' * 2MB) }
if ($task.role.id -eq 'integration') {
    $sourceCommit = [regex]::Match($task.objective[0], '[a-f0-9]{40}').Value
    git merge --no-ff --no-edit $sourceCommit 2>$null | Out-Null
}
if ($task.objective[0] -eq 'SLEEP') { Start-Sleep -Seconds 30 }
if ($task.objective[0] -eq 'WAIT_FOR_COST') {
    $deadline = [DateTime]::UtcNow.AddSeconds(20)
    do {
        Start-Sleep -Milliseconds 100
        $control = Get-Content -LiteralPath $guard.budgetControl -Raw | ConvertFrom-Json
    } while (-not $control.stop_new_children -and [DateTime]::UtcNow -lt $deadline)
    if (-not $control.stop_new_children) { exit 8 }
}
if ($task.objective[0] -eq 'CRASH') { exit 9 }
if ($task.objective[0] -eq 'WAIT_FOR_RELEASE') {
    $release = Join-Path (Split-Path $guard.receipt -Parent) 'release.test'
    $deadline = [DateTime]::UtcNow.AddSeconds(30)
    while (-not (Test-Path -LiteralPath $release) -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 100 }
    if (-not (Test-Path -LiteralPath $release)) { exit 8 }
}
$path = $task.write_scope[0]
if ($task.objective[0] -in @('SCOPE','ESCALATE_SCOPE')) { $path = 'forbidden.txt' }
if ($task.objective[0] -ne 'NOOP') {
$parent = Split-Path $path -Parent
if ($parent) { New-Item -ItemType Directory -Force $parent | Out-Null }
Set-Content -LiteralPath $path -Value $task.task_id -Encoding utf8NoBOM
git add -- $path | Out-Null
if ($task.role.id -eq 'integration') { git commit -qm "test: fixture $($task.task_id)" }
else { git commit -qm "test: fixture $($task.task_id)" -- $path }
if ($LASTEXITCODE) { exit $LASTEXITCODE }
}
$commit = git rev-parse HEAD
$branch = git branch --show-current
@{schema_version=1;agents=@(@{id='fixture-agent';depth=0;state='created';provider='deepseek-official';model='deepseek-flash';cwd=(Get-Location).Path})} | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $guard.receipt -Encoding utf8NoBOM
if ($task.objective[0] -eq 'MALFORMED') { Write-Output 'no result'; exit 0 }
$escalated=$task.objective[0] -in @('ESCALATE','ESCALATE_SCOPE')
$changedFiles=@(); if ($task.objective[0] -ne 'NOOP') { $changedFiles=@($path) }
@{schema_version=1;run_id=$task.run_id;task_id=$task.task_id;status=$(if ($escalated) {'escalated'} else {'completed'});summary=@('synthetic fixture');changed_files=$changedFiles;verification=@{passed=(-not $escalated)};subagents_used=@();risks=@();git=@{branch=$branch;commit=$commit}} | ConvertTo-Json -Depth 20
if ($task.objective[0] -eq 'PIPE_HOLDER') {
    & (Join-Path $PSScriptRoot 'pipe-holder.ps1') -Silent -Receipt (Join-Path (Split-Path $guard.receipt -Parent) 'pipe-child.json')
}
