function Save-TeamCheckpoint([string]$Directory, $Checkpoint) {
    Write-TeamData (Join-Path $Directory "checkpoints/$($Checkpoint.task_id).json") $Checkpoint
    $key=if ($Checkpoint.Contains('attempt')) {"$($Checkpoint.task_id)-a$($Checkpoint.attempt)-$($Checkpoint.after)"} else {"$($Checkpoint.task_id)-$($Checkpoint.after)"}
    Write-TeamData (Join-Path $Directory "checkpoints/history/$key.json") $Checkpoint
}

function Get-TeamActiveCheckpoints([string]$Directory) {
    return @(Get-ChildItem (Join-Path $Directory 'checkpoints') -Filter '*.json' -ErrorAction SilentlyContinue |
        ForEach-Object { Read-TeamData $_.FullName } | Where-Object { -not $_['rollback_commit'] })
}

function Get-TeamRepairSources($Repair) {
    if ($Repair['source_tasks']) { return @($Repair.source_tasks) }
    return @($Repair.source_task)
}

function New-TeamRegressionTask($State, $Plan, $Failure, [string]$RootTask) {
    $affected=@(Get-TeamAffectedByScope $Plan $RootTask)
    foreach ($probe in $Failure['probes']) {
        foreach ($id in $probe.rolled_back) { $affected+=@(Get-TeamAffectedByScope $Plan $id) }
    }
    $affected=@($affected | Sort-Object -Unique)
    $sources=@($affected | Where-Object { $State.tasks[$_].commit -and $State.tasks[$_].status -in @('MERGED','CLEANED','REWORK','ACCEPTED') })
    if (-not $sources.Count) { Stop-TeamError 80 'No accepted integration inputs match the selected failure task' }
    $scope=@(); $acceptance=@(); $verification=@()
    foreach ($id in $sources) {
        $task=@($Plan.tasks | Where-Object id -eq $id)[0]
        $scope+=@($task.write_scope)
        $acceptance+=@($task.acceptance | ForEach-Object { "${id}: $_" })
        foreach ($command in $task.verification) {
            $copy=$command | ConvertTo-Json -Depth 20 | ConvertFrom-Json -AsHashtable
            $copy.id="task-$($verification.Count)"; $verification+=$copy
        }
    }
    foreach ($command in $Plan.verification.final) {
        $copy=$command | ConvertTo-Json -Depth 20 | ConvertFrom-Json -AsHashtable
        $copy.id="final-$($verification.Count)"; $verification+=$copy
    }
    $task=@{
        id=('INTEGRATION-' + ($State.replans + 1));role='integration'
        objective=@(
            "Repair the recorded final regression at commit $($Failure.failed_sha). Restore the approved contracts for tasks $($sources -join ', ') without changing interfaces, acceptance, or verification commands.",
            "Compare the original source commits: $(@($sources | ForEach-Object { $State.tasks[$_].commit }) -join ', '). Read the preserved failure evidence at $($Failure.directory) and any rollback probes. A passing rollback probe is a localization hint, not proof that missing features satisfy acceptance.",
            "There are no merge conflict files in this regression task. Lead-approved glue scope: $(@($scope | Sort-Object -Unique) -join ', '). This is the explicit glue allowance under the integration role policy.",
            'Implement only the bounded correction on the assigned integration base. Preserve unrelated accepted work and escalate any new business decision.')
        dependencies=@($State.tasks.Keys | Where-Object { $_ -notin $sources -and $State.tasks[$_].status -in @('MERGED','CLEANED') })
        write_scope=@($scope | Sort-Object -Unique);acceptance=$acceptance;verification=$verification
        permissions=@{shell=$true;network=$false;secrets=$false;production=$false};subagents=@{allowed=$false;max_depth=0}
    }
    return @{task=$task;sources=$sources}
}

function Record-TeamIntegrationFailure($State, $Plan, [string]$Directory) {
    $head=Invoke-TeamGit $State.integration_worktree @('rev-parse','HEAD')
    $id='FAIL-' + [guid]::NewGuid().ToString('N').Substring(0,12)
    $path=Join-Path $Directory "integration-failures/$id"
    [IO.Directory]::CreateDirectory($path) | Out-Null
    $evidenceDirectory=if ($State['final_evidence_directory']) {$State.final_evidence_directory} else {$Directory}
    foreach ($file in Get-ChildItem $evidenceDirectory -Filter 'final-*' -File) { [IO.File]::Copy($file.FullName,(Join-Path $path $file.Name)) }
    $checkpoints=@(Get-TeamActiveCheckpoints $Directory)
    $latest=@($checkpoints | Where-Object { $_.after -eq $head -and (-not $State['last_merged_task'] -or $_.task_id -eq $State.last_merged_task) })
    if (-not $latest.Count) { Stop-TeamError 80 'Final regression has no bound integration checkpoint' }
    $failure=@{id=$id;directory=$path;failed_sha=$head;last_targeted_good_sha=$State.last_good_integration_sha;last_merged_task=$latest[0].task_id;
        plan_hash=$State.plan_hash;revision=$State.revision;checkpoints=$checkpoints;status='unresolved';probes=@();created_at=[DateTime]::UtcNow.ToString('o')}
    Write-TeamData (Join-Path $path 'failure.json') $failure
    Write-TeamData (Join-Path $Directory 'integration-failure.json') $failure
    $draft=New-TeamRegressionTask $State $Plan $failure $failure.last_merged_task
    Write-TeamData (Join-Path $Directory 'integration-failure-task.json') @{status='draft';failure_id=$id;integration_sha=$head;task=$draft.task;sources=$draft.sources}
    Add-TeamEvent $Directory 'integration_regression_failed' @{failure_id=$id;failed_sha=$head;last_merged_task=$failure.last_merged_task}
}

function Record-TeamRollbackProbe($State, $Plan, [string]$Directory, [string[]]$RolledBack) {
    $path=Join-Path $Directory 'integration-failure.json'
    if (-not (Test-Path -LiteralPath $path)) { return }
    $failure=Read-TeamData $path
    if ($failure.status -ne 'unresolved') { return }
    $head=Invoke-TeamGit $State.integration_worktree @('rev-parse','HEAD')
    if (@($failure.probes | Where-Object { $_.sha -ceq $head -and (@($_.rolled_back) -join '|') -ceq ($RolledBack -join '|') }).Count) { return }
    $probePath=Join-Path $failure.directory ('probe-' + $head + '-' + [guid]::NewGuid().ToString('N'))
    [IO.Directory]::CreateDirectory($probePath) | Out-Null
    $result='passes_after_rollback'
    $manifest=Read-TeamData (Join-Path $Directory 'manifest.yaml')
    try { $null=Invoke-TeamVerification $Plan.verification.final $State.integration_worktree $probePath 'final' $manifest.runtime }
    catch {
        if ($_.Exception.Data['TeamExitCode'] -ne 40) { throw }
        $result='inconclusive_still_fails'
    }
    if ((Invoke-TeamGit $State.integration_worktree @('rev-parse','HEAD')) -cne $head -or
        (Invoke-TeamGit $State.integration_worktree @('status','--porcelain','--untracked-files=all'))) { Stop-TeamError 82 'Rollback probe modified the integration snapshot' }
    $failure.probes+=@{sha=$head;rolled_back=$RolledBack;result=$result;evidence=(Join-Path $probePath 'final-evidence.json')}
    Write-TeamData $path $failure
    $draft=New-TeamRegressionTask $State $Plan $failure $RolledBack[-1]
    Write-TeamData (Join-Path $Directory 'integration-failure-task.json') @{status='draft';failure_id=$failure.id;integration_sha=$head;task=$draft.task;sources=$draft.sources}
    Add-TeamEvent $Directory 'integration_rollback_probe' @{failure_id=$failure.id;sha=$head;result=$result;rolled_back=$RolledBack}
}

function New-TeamRegressionRepair($State, $Plan, $Manifest, [string]$Directory, [string]$RootTask, [string]$Reason) {
    $failure=Read-TeamData (Join-Path $Directory 'integration-failure.json')
    if ($failure.status -ne 'unresolved' -or $failure.plan_hash -cne $State.plan_hash) { Stop-TeamError 80 'Regression evidence belongs to a resolved or different plan' }
    $head=Invoke-TeamGit $State.integration_worktree @('rev-parse','HEAD')
    if ($head -cne $State.last_good_integration_sha -or (Invoke-TeamGit $State.integration_worktree @('status','--porcelain','--untracked-files=all'))) { Stop-TeamError 80 'Regression repair requires the exact clean integration checkpoint' }
    if (-not $RootTask) { $RootTask=$failure.last_merged_task }
    $draft=New-TeamRegressionTask $State $Plan $failure $RootTask
    $task=$draft.task; $next=$Plan | ConvertTo-Json -Depth 80 | ConvertFrom-Json -AsHashtable
    $next.run.revision++; if ($next.mode -eq 'L1') { $next.mode='L2' }; $next.tasks+=@($task)
    $order=@(Test-TeamPlan $next $Manifest)
    Assert-TeamReviewRound $State $Plan $Directory -Close
    $State=$State | ConvertTo-Json -Depth 100 | ConvertFrom-Json -AsHashtable
    if (-not $State['repairs']) { $State['repairs']=@{} }
    $State.repairs[$task.id]=@{kind='regression';failure_id=$failure.id;source_tasks=$draft.sources;
        source_commits=@($draft.sources | ForEach-Object { $State.tasks[$_].commit });write_scope=$task.write_scope;conflict_files=@();glue_scope=$task.write_scope}
    foreach ($id in $draft.sources) {
        if ($State.tasks[$id].status -eq 'CLEANED') { $State.tasks[$id]['worktree_removed']=$true }
        $State.tasks[$id].status='REPAIRING'
    }
    $State.tasks[$task.id]=@{status='READY';attempts=0;commit='';pid=0;process_start='';directory='';worktree='';branch='';base_sha=''}
    $State.revision=$next.run.revision; $State.replans++; $State.order=$order; $State.status='PAUSED'
    Save-TeamPlanRevision $State $Plan $next $Directory "DEC-Integration-$($State.revision)" @{reason=$Reason;kind='regression';failure_id=$failure.id;source_tasks=$draft.sources;task_id=$task.id;revision=$State.revision;integration_sha=$head;conflict_files=@();glue_scope=$task.write_scope}
    Add-TeamEvent $Directory 'integration_worker_planned' @{task_id=$task.id;kind='regression';failure_id=$failure.id;source_tasks=$draft.sources}
    return @{task_id=$task.id;revision=$State.revision;next='resume; inspect and accept the regression repair, then integrate'}
}
