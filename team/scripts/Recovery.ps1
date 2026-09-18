function Assert-TeamRunRoot([string]$Repo) {
    $root = Invoke-TeamGit $Repo @('rev-parse','--show-toplevel')
    $gitDir = Invoke-TeamGit $Repo @('rev-parse','--absolute-git-dir')
    $common = Invoke-TeamGit $Repo @('rev-parse','--path-format=absolute','--git-common-dir')
    if ([IO.Path]::GetFullPath($root).TrimEnd('\','/') -ine [IO.Path]::GetFullPath($Repo).TrimEnd('\','/') -or
        [IO.Path]::GetFullPath($gitDir) -ine [IO.Path]::GetFullPath($common)) {
        Stop-TeamError 20 'Start Team runs from the primary repository root; linked worktrees cannot own a separate run lock'
    }
}

function Assert-TeamRecovery($State, $Plan, [string]$Directory) {
    Assert-TeamCleanupSettled $State
    Assert-TeamRunRoot $State.repo
    if ($State.revision -ne $Plan.run.revision -or $State.run_id -cne $Plan.run.id -or
        @(Compare-Object @($State.tasks.Keys | Sort-Object) @($Plan.tasks.id | Sort-Object)).Count -or
        (@($State.order) -join '|') -cne (@(Test-TeamPlan $Plan (Read-TeamData (Join-Path $Directory 'manifest.yaml'))) -join '|')) {
        Stop-TeamError 80 'State task graph differs from the frozen plan'
    }
    foreach ($sha in @($State.run_base_sha,$State.last_good_integration_sha)) {
        $null = Invoke-TeamGit $State.repo @('cat-file','-e',"${sha}^{commit}")
    }
    $eventPath = Join-Path $Directory 'events.jsonl'
    if (-not (Test-Path -LiteralPath $eventPath)) { Stop-TeamError 80 'Recovery requires the event history' }
    $created = $false
    $reader = [IO.File]::OpenText($eventPath)
    try {
        while ($null -ne ($line = $reader.ReadLine())) {
            try { $entry = ConvertFrom-Json $line -AsHashtable -ErrorAction Stop }
            catch { Stop-TeamError 80 'Event history contains an incomplete or invalid record; preserve it for reconciliation' }
            if (-not $entry['event'] -or -not $entry['timestamp'] -or -not $entry.ContainsKey('details')) { Stop-TeamError 80 'Invalid event record' }
            if ($entry.event -eq 'run_created' -and $entry.details.base_sha -ceq $State.run_base_sha) { $created=$true }
        }
    } finally { $reader.Dispose() }
    if (-not $created) { Stop-TeamError 80 'Event history does not establish the frozen run base' }
    if ($State.integration_worktree) {
        $expected = Get-TeamChild $State.repo ".worktrees/$($State.run_id)-integration"
        if ($State.integration_worktree -cne $expected -or
            (Invoke-TeamGit $expected @('branch','--show-current')) -cne $State.integration_branch -or
            (Invoke-TeamGit $expected @('rev-parse','HEAD')) -cne $State.last_good_integration_sha -or
            (Invoke-TeamGit $expected @('status','--porcelain','--untracked-files=all'))) {
            Stop-TeamError 80 'Integration snapshot differs from the accepted checkpoint; rollback or reconcile before resume'
        }
    }
    $reserved = 0
    foreach ($id in $State.order) {
        $item = $State.tasks[$id]
        $reserved += [int]$item['reserved']
        if ($item['local_review']) { $reserved += [int]$item.local_review.reserved }
        if ($item.attempts -eq 0) {
            if ($item.worktree -or $item.directory -or $item.pid -or $item.status -ne 'READY') { Stop-TeamError 80 'Unstarted task has execution state' }
            continue
        }
        $taskDirectory = Get-TeamChild $Directory "tasks/$id/attempt-$($item.attempts)"
        if ($item.directory -cne $taskDirectory) { Stop-TeamError 80 'Task attempt directory mismatch' }
        $packet = Read-TeamData (Join-Path $taskDirectory 'task.yaml')
        Test-TeamTask $packet
        $expected = Get-TeamChild $State.repo ".worktrees/$($State.run_id)-$id-$($packet.role.id)-a$($item.attempts)"
        if ($item.worktree -cne $expected -or $packet.base_sha -cne $item.base_sha -or $packet.task_id -cne $id -or $packet.run_id -cne $State.run_id) {
            Stop-TeamError 80 'Task worktree or packet identity mismatch'
        }
        if ($item.status -eq 'CLEANED') { continue }
        if ($item['worktree_removed']) {
            if ($item.status -in @('RUNNING','VERIFYING','REVIEW','ACCEPTED') -or (Test-Path -LiteralPath $expected)) { Stop-TeamError 80 'Removed worktree has inconsistent execution state' }
            continue
        }
        if ((Invoke-TeamGit $expected @('branch','--show-current')) -cne $item.branch) { Stop-TeamError 80 'Task is no longer on its assigned branch' }
        $null = Invoke-TeamGit $expected @('merge-base','--is-ancestor',$item.base_sha,'HEAD')
        if ($item.status -in @('RUNNING','RESULT_READY','VERIFYING','LOCAL_REVIEW')) {
            $processes = @(@{pid=$item.pid;start=$item.process_start})
            $nativePath = Join-Path $item.directory 'native-process.json'
            if (Test-Path -LiteralPath $nativePath) { $processes += Read-TeamData $nativePath }
            if ($item['local_review']) {
                $review=$item.local_review
                $processes+=@{pid=$review.pid;start=$review.process_start}
                $reviewNative=Join-Path $review.directory 'native-process.json'
                if (Test-Path $reviewNative) { $processes+=Read-TeamData $reviewNative }
            }
            foreach ($record in $processes) {
                if (-not $record.pid) { continue }
                $process = Get-TeamOwnedProcess $record.pid $record.start
                if ($process) {
                    Stop-TeamError 80 'Original worker or native process is still active; wait for its durable receipt before resume'
                }
            }
        }
    }
    if ($reserved -ne $State.agents_reserved) { Stop-TeamError 80 'Agent reservation ledger differs from task state' }
}

function Invoke-TeamReplan($State, $OldPlan, $NewPlan, $Manifest, [string]$Directory, [string]$FailedTask, [string]$Reason) {
    Assert-TeamCleanupSettled $State
    $order = @(Test-TeamPlan $NewPlan $Manifest)
    if ($State.replans -ge $Manifest.budget.max_replans) { Stop-TeamError 60 'Replan limit reached; hard-stop' }
    if ($NewPlan.run.id -cne $State.run_id -or $NewPlan.run.revision -ne ($State.revision + 1) -or -not $Reason) {
        Stop-TeamError 10 'Replan requires same run ID, next revision, and a Decision Log reason'
    }
    if ($NewPlan.classification.level -cne $OldPlan.classification.level) { Stop-TeamError 10 'Replan cannot silently change Routine/Critical classification' }
    if (@($State.tasks.Values | Where-Object { $_.status -eq 'RUNNING' }).Count) { Stop-TeamError 80 'Replan requires quiescent workers' }
    foreach ($item in $State.tasks.Values) {
        if ($item['local_review'] -and $item.local_review.reserved) { Stop-TeamError 80 'Reconcile the local reviewer before replanning its work' }
    }
    if (-not $State.tasks.Contains($FailedTask)) { Stop-TeamError 10 'Unknown failed task' }
    $affected = @(Get-TeamAffectedByScope $OldPlan $FailedTask)
    foreach ($task in $OldPlan.tasks) {
        $next = @($NewPlan.tasks | Where-Object { $_.id -eq $task.id })
        if ($task.id -notin $affected) {
            if ($next.Count -ne 1 -or ($task | ConvertTo-Json -Depth 50 -Compress) -cne ($next[0] | ConvertTo-Json -Depth 50 -Compress)) {
                Stop-TeamError 10 "Replan changed unrelated task: $($task.id)"
            }
        } elseif ($State.tasks[$task.id].status -in @('MERGED','CLEANED')) {
            Stop-TeamError 80 'Affected task is already integrated; rollback its integration checkpoint first'
        }
    }
    foreach ($taskId in $affected) {
        if ($State.tasks[$taskId].attempts -gt $Manifest.budget.max_worker_retries) { Stop-TeamError 60 'Worker retry budget exhausted' }
    }
    Assert-TeamReviewRound $State $OldPlan $Directory -Close
    # Retire the old attempt before READY can be dispatched into a new worktree.
    # Keep its exact Git tip and all evidence even when its task ID is removed.
    if (-not $State['discarded_tasks']) { $State['discarded_tasks']=@{} }
    foreach ($taskId in $affected) {
        $item=$State.tasks[$taskId]
        if (-not $item.attempts -or $item['worktree_removed']) { continue }
        if (@($State.discarded_tasks.Values | Where-Object { $_.worktree -ceq $item.worktree }).Count) { continue }
        $retired=$item | ConvertTo-Json -Depth 60 | ConvertFrom-Json -AsHashtable
        $retired['task_id']=$taskId; $retired['retired_from']=$item.status; $retired.status='DISCARDED'
        $retired['discard_reason']=$Reason; $retired['discard_revision']=$NewPlan.run.revision
        $retired['discard_commit']=Invoke-TeamGit $item.worktree @('rev-parse','HEAD')
        $State.discarded_tasks["$taskId-a$($item.attempts)-r$($State.revision)"]=$retired
    }
    $State.replans++; $State.revision = $NewPlan.run.revision; $State.order = $order
    foreach ($task in $NewPlan.tasks) {
        if (-not $State.tasks.Contains($task.id)) {
            $State.tasks[$task.id] = @{status='READY';attempts=0;commit='';pid=0;process_start='';directory='';worktree='';branch='';base_sha=''}
        } elseif ($task.id -in $affected) {
            $item = $State.tasks[$task.id]
            $item.status = 'READY'
        }
    }
    foreach ($oldId in @($State.tasks.Keys)) {
        if ($oldId -notin @($NewPlan.tasks | ForEach-Object { $_.id })) { $State.tasks.Remove($oldId) }
    }
    Write-TeamData (Join-Path $Directory "plan-revision-$($OldPlan.run.revision).yaml") $OldPlan
    Write-TeamData (Join-Path $Directory 'plan.yaml') $NewPlan
    $State.plan_hash = Get-TeamHash (Join-Path $Directory 'plan.yaml'); $State.status = 'PAUSED'
    Write-TeamData (Join-Path $Directory "decisions/DEC-Replan-$($State.revision).json") @{
        decision='replan'; reason=$Reason; affected=$affected; revision=$State.revision; plan_hash=$State.plan_hash
    }
    Save-TeamState $State $Directory
    Add-TeamEvent $Directory 'run_replanned' @{ affected=$affected; revision=$State.revision }
    return @{ affected=$affected; revision=$State.revision; status='PAUSED' }
}

function Stop-TeamTaskProcesses($Item) {
    $nativePath = Join-Path $Item.directory 'native-process.json'
    $records = @(@{pid=$Item.pid;start=$Item.process_start})
    if (Test-Path -LiteralPath $nativePath) { $records += Read-TeamData $nativePath }
    $errors=@()
    if ($Item['local_review']) {
        try { Stop-TeamTaskProcesses $Item.local_review } catch { $errors+=$_.Exception.Message }
    }
    foreach ($record in $records) {
        if (-not $record.pid) { continue }
        $process = Get-TeamOwnedProcess $record.pid $record.start
        if ($process) {
            try {
                $process.Kill($true)
                if (-not $process.WaitForExit(5000)) { $errors+='Owned process did not exit during cleanup' }
            } catch { $errors+=$_.Exception.Message }
            finally { $process.Dispose() }
        }
    }
    if ($errors.Count) { Stop-TeamError 31 ($errors -join '; ') }
}

function Stop-TeamOwnedProcesses($State, [string]$Directory) {
    $errors=@()
    foreach ($taskId in $State.tasks.Keys) {
        $item = $State.tasks[$taskId]
        if ($item.status -notin @('RUNNING','LOCAL_REVIEW') -and -not $item['cleanup_pending']) { continue }
        try { Stop-TeamTaskProcesses $item }
        catch { $item['cleanup_pending']=$true; $errors+=@{task_id=$taskId;error=$_.Exception.Message}; continue }
        $item['cleanup_pending']=$false
        $item.status = 'FAILED'
        if ($item['reserved']) { $State.agents_created += $item.reserved; $State.agents_reserved -= $item.reserved; $item.reserved=0 }
        if ($item['local_review']) { Settle-TeamLocalReviewBudget $State $item.local_review; $item.local_review.status='CANCELLED' }
    }
    if ($errors.Count) {
        Save-TeamState $State $Directory; Add-TeamEvent $Directory 'process_cleanup_failed' @{errors=$errors}
        Stop-TeamError 31 'Some owned processes could not be stopped; retry stop after inspecting the preserved evidence'
    }
    $State.status = 'CANCELLED'; Save-TeamState $State $Directory
    Add-TeamEvent $Directory 'run_cancelled'
    Unlock-TeamRepo $State.repo $State.run_id
}

function Undo-TeamIntegration($State, [string]$Directory, [string]$TaskId, [string]$Reason) {
    if (-not $Reason -or -not $State.integration_worktree) { Stop-TeamError 80 'Rollback requires integration worktree and reason' }
    $tree = Get-TeamChild $State.repo ".worktrees/$($State.run_id)-integration"
    if ($tree -cne $State.integration_worktree -or (Invoke-TeamGit $tree @('branch','--show-current')) -cne $State.integration_branch) { Stop-TeamError 82 'Integration worktree or branch mismatch' }
    if (@($State.tasks.Values | Where-Object status -eq 'RUNNING').Count) { Stop-TeamError 80 'Rollback requires quiescent workers' }
    $head=Invoke-TeamGit $tree @('rev-parse','HEAD')
    $revertHead = & git -C $tree rev-parse -q --verify REVERT_HEAD 2>$null
    if ($LASTEXITCODE -eq 0) {
        $pending=@(Get-ChildItem (Join-Path $Directory 'rollbacks') -Filter '*.json' -ErrorAction SilentlyContinue | ForEach-Object { Read-TeamData $_.FullName } | Where-Object { $_.status -eq 'started' -and $_.before -ceq $head -and $_.reverted_merge -ceq $revertHead })
        if ($pending.Count -ne 1) { Stop-TeamError 80 'Unowned revert conflict; preserve Git state for reconciliation' }
        $null=Invoke-TeamGit $tree @('revert','--abort')
        $pending[0].status='aborted'; $pending[0]['abort_reason']=$Reason
        Write-TeamData (Join-Path $Directory "rollbacks/$($pending[0].id).json") $pending[0]
        $State.status='PAUSED'; Save-TeamState $State $Directory
        return @{status='PAUSED';aborted_revert=$pending[0].id;commit=$head}
    }
    $mergeHead = & git -C $tree rev-parse -q --verify MERGE_HEAD 2>$null
    if ($LASTEXITCODE -eq 0) {
        $conflict=Read-TeamData (Join-Path $Directory 'integration-conflict.json')
        if ($head -cne $conflict.base_sha -or $mergeHead -cne $State.tasks[$conflict.task_id].commit -or ($TaskId -and $TaskId -cne $conflict.task_id)) { Stop-TeamError 80 'Unowned integration merge; preserve Git state' }
        $null = Invoke-TeamGit $tree @('merge','--abort')
        $State.status='PAUSED'; Save-TeamState $State $Directory
        Add-TeamEvent $Directory 'integration_merge_aborted' @{task_id=$conflict.task_id;reason=$Reason;commit=$head}
        return @{status='PAUSED';commit=$head;aborted_merge=$conflict.task_id}
    }
    Assert-TeamId $TaskId
    if (Invoke-TeamGit $tree @('status','--porcelain','--untracked-files=all')) { Stop-TeamError 80 'Rollback refuses unrelated dirty changes' }
    $plan=Read-TeamData (Join-Path $Directory 'plan.yaml')
    $affected=@(Get-TeamAffectedByScope $plan $TaskId)
    if ($State['repairs']) {
        do {
            $beforeCount=$affected.Count
            foreach ($id in $State.repairs.Keys) {
                $sources=@(Get-TeamRepairSources $State.repairs[$id])
                if ($id -in $affected -or @($sources | Where-Object { $_ -in $affected }).Count) { $affected+=@($sources)+@(Get-TeamAffectedByScope $plan $id) }
            }
            $affected=@($affected | Sort-Object -Unique)
        } while ($beforeCount -ne $affected.Count)
    }
    $active=@(Get-TeamActiveCheckpoints $Directory)
    $history=@((Invoke-TeamGit $tree @('rev-list','--first-parent',"$($State.run_base_sha)..HEAD")) -split "`n" | Where-Object { $_ }) + @($State.run_base_sha)
    $selected=@($active | Where-Object { $_.task_id -in $affected } | Sort-Object { [array]::IndexOf($history,$_.after) })
    if (-not $selected.Count) { Stop-TeamError 80 'No active integration checkpoint matches the rollback target' }
    if ($head -cne $State.last_good_integration_sha -and -not @($selected | Where-Object { -not $_.verified -and $_.after -ceq $head -and $_.before -ceq $State.last_good_integration_sha }).Count) {
        Stop-TeamError 80 'Integration HEAD moved outside the recorded rollback checkpoints'
    }
    foreach ($checkpoint in $selected) {
        if ($checkpoint.worker_commit -cne $State.tasks[$checkpoint.task_id].commit) { Stop-TeamError 80 'Checkpoint source differs from the accepted task commit' }
        if ($checkpoint.after -notin $history) { Stop-TeamError 80 'Checkpoint is not on the integration first-parent history' }
        if (-not $checkpoint['noop'] -and (Invoke-TeamGit $tree @('rev-parse',"$($checkpoint.after)^1")) -cne $checkpoint.before) { Stop-TeamError 80 'Checkpoint parent differs from its recorded base' }
        $null=Invoke-TeamGit $tree @('merge-base','--is-ancestor',$checkpoint.worker_commit,$checkpoint.after)
    }
    $rolled=@()
    foreach ($checkpoint in $selected) {
        $before=Invoke-TeamGit $tree @('rev-parse','HEAD')
        $id='ROLLBACK-' + [guid]::NewGuid().ToString('N').Substring(0,12)
        $record=@{id=$id;task_id=$checkpoint.task_id;before=$before;reverted_merge=$checkpoint.after;reason=$Reason;status='started'}
        Write-TeamData (Join-Path $Directory "rollbacks/$id.json") $record
        if (-not $checkpoint['noop']) { $null=Invoke-TeamGit $tree @('revert','-m','1','--no-edit',$checkpoint.after) }
        $after=Invoke-TeamGit $tree @('rev-parse','HEAD')
        $record.status='completed'; $record['after']=$after
        Write-TeamData (Join-Path $Directory "rollbacks/$id.json") $record
        $checkpoint['rollback_commit']=$after; $checkpoint['rollback_before']=$before
        Save-TeamCheckpoint $Directory $checkpoint
        $ids=@($checkpoint.task_id)
        if ($State['repairs'] -and $State.repairs.Contains($checkpoint.task_id)) { $ids+=@(Get-TeamRepairSources $State.repairs[$checkpoint.task_id]) }
        foreach ($id in $ids) {
            if ($State.tasks[$id].status -eq 'CLEANED') { $State.tasks[$id]['worktree_removed']=$true }
            $State.tasks[$id].status='REWORK'
        }
        $State.last_good_integration_sha=$after; $State.status='PAUSED'; Save-TeamState $State $Directory
        Add-TeamEvent $Directory 'integration_rollback' @{task_id=$checkpoint.task_id;reason=$Reason;reverted_merge=$checkpoint.after;commit=$after}
        $rolled+=$checkpoint.task_id
    }
    Record-TeamRollbackProbe $State $plan $Directory $rolled
    return @{status='PAUSED';commit=$State.last_good_integration_sha;rolled_back=$rolled;affected=$affected}
}
