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
    # A replan mutates the frozen plan; a legacy run must start a new run instead.
    $null = Assert-TeamReuseRunProtocol $State $Directory
    if (@(Get-TeamPendingIntegration $Directory).Count) { Stop-TeamError 80 'Reconcile or roll back the pending integration before replanning' }
    $order = @(Test-TeamPlan $NewPlan $Manifest)
    # Role identities are immutable across revisions. A changed specialty gets a
    # new ID, leaving old attempts and their frozen packets reproducible.
    if ($OldPlan['dynamic_roles'] -and $NewPlan['dynamic_roles']) {
        foreach ($id in $OldPlan.dynamic_roles.Keys) {
            if ($NewPlan.dynamic_roles.Contains($id) -and
                (Get-TeamCanonicalJson $OldPlan.dynamic_roles[$id]) -cne (Get-TeamCanonicalJson $NewPlan.dynamic_roles[$id])) {
                Stop-TeamError 10 "Replan changed an existing dynamic role; use a new role ID: $id"
            }
        }
    }
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
    # Reuse is part of the task contract: a changed decision or a changed task declaration
    # invalidates inference and review evidence even when every file scope is unchanged.
    # Each affected existing task is then closed over the same dependency/scope closure a
    # failed task would use: a task accepted on the old declaration of its dependency or on
    # an overlapping scope cannot keep its acceptance.
    $reuseAffected = Get-TeamReuseAffected $OldPlan $NewPlan
    $reuseInvalidated = @($reuseAffected.tasks)
    $frozenIds = @($OldPlan.tasks | ForEach-Object { [string]$_.id })
    foreach ($id in @($reuseAffected.tasks)) {
        # A task introduced by this revision has no frozen entry yet, so the closure has no
        # root to expand from; its own new identity is the whole invalidation.
        if ([string]$id -in $frozenIds) { $reuseInvalidated += @(Get-TeamAffectedByScope $OldPlan ([string]$id)) }
    }
    if (@($reuseInvalidated).Count) {
        $affected = @(@($affected) + @($reuseInvalidated) | Sort-Object -Unique)
    }
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
        $item = $State.tasks[$taskId]
        # A task introduced by this revision carries no attempt history to cap.
        if ($item -and [int]$item['attempts'] -gt $Manifest.budget.max_worker_retries) { Stop-TeamError 60 'Worker retry budget exhausted' }
    }
    Assert-TeamReviewRound $State $OldPlan $Directory -Close
    # Prepare a separate candidate so a failed transaction cannot leak into the
    # CLI error handler's last known committed state.
    $State=$State | ConvertTo-Json -Depth 100 | ConvertFrom-Json -AsHashtable
    # Retire the old attempt before READY can be dispatched into a new worktree.
    # Keep its exact Git tip and all evidence even when its task ID is removed.
    if (-not $State['discarded_tasks']) { $State['discarded_tasks']=@{} }
    foreach ($taskId in $affected) {
        $item=$State.tasks[$taskId]
        # A newly introduced task has no old attempt or worktree to retire.
        if (-not $item -or -not $item['attempts'] -or $item['worktree_removed']) { continue }
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
    $State.status = 'PAUSED'
    foreach ($task in $NewPlan.tasks) {
        if ($State.tasks[$task.id].status -eq 'READY' -and -not $task['optional'] -and
            -not (Get-TeamAgentAdmission $State $NewPlan $Manifest $task).admitted) {
            Stop-TeamError 70 'Revised plan cannot fund its remaining required authors and reviewers'
        }
    }
    # An owner exception is bound to one exact plan hash, so the new revision invalidates any
    # previous approval. The prior approval must be captured before Save-TeamPlanRevision
    # rebinds state.plan_hash, otherwise this event could never be reached. A revised plan
    # that is still blocked re-registers the pause instead of inheriting the old approval.
    $priorException = @(Get-TeamReuseOwnerException $State $Directory)
    Save-TeamPlanRevision $State $OldPlan $NewPlan $Directory "DEC-Replan-$($State.revision)" @{
        decision='replan'; reason=$Reason; affected=$affected; revision=$State.revision
    }
    if ($priorException.Count) {
        Add-TeamEvent $Directory 'reuse_exception_invalidated' @{ revision=$State.revision; plan_hash=$State.plan_hash
            previous_plan_hash = [string]$priorException[0]['plan_hash']; escalation = [string]$priorException[0].id }
    }
    $decision = Assert-TeamReusePlanContent $NewPlan
    if ([string]$decision['status'] -ceq 'blocked') { Suspend-TeamReuseUnavailable $State $Directory $decision }
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
        $batchPath=Join-Path $Directory 'rollback-pending.json'
        if (Test-Path -LiteralPath $batchPath) {
            $batch=Read-TeamData $batchPath
            if ($batch.id -ceq $pending[0]['batch_id']) { $batch.status='aborted'; Write-TeamData $batchPath $batch }
        }
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
    $restored=Restore-TeamRollback $State $Directory
    if ($restored) { return $restored }
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
    $entries=@($selected | ForEach-Object { @{id=('ROLLBACK-'+[guid]::NewGuid().ToString('N'));checkpoint=$_} })
    Write-TeamData (Join-Path $Directory 'rollback-pending.json') @{
        id=('UNDO-'+[guid]::NewGuid().ToString('N'));run_id=$State.run_id;plan_hash=$State.plan_hash;
        before=$head;reason=$Reason;status='prepared';affected=$affected;entries=$entries
    }
    return Restore-TeamRollback $State $Directory
}

function Sync-TeamTerminalReservations($State, [string]$Directory, $Manifest) {
    $settled=0; $unknown=0; $held=0
    foreach ($taskId in @($State.tasks.Keys)) {
        $item=$State.tasks[$taskId]
        if (-not $item['reserved']) { continue }
        if ($item.status -notin @('FAILED','FAILED_SCOPE','ESCALATED','CANCELLED')) { continue }
        # Budget is only ever moved on positive quiescence evidence. A live owner, an
        # unprovable PID/start pair or an unresolved child cleanup keeps the reservation
        # exactly where it is: unknown usage stays unknown instead of being released.
        $ownership = Get-TeamOwnedProcessState $item
        if (-not $ownership.settled) {
            $unknown++; $held += [int]$item.reserved
            Add-TeamEvent $Directory 'reservation_reconciliation_held' @{ task_id=$taskId; reserved=[int]$item.reserved
                live=@($ownership.live | ForEach-Object { $_.pid }); unknown=@($ownership.unknown | ForEach-Object { $_.pid })
                unresolved=@($ownership.unresolved | ForEach-Object { $_.detail }) }
            continue
        }
        $receiptPath=Join-Path $item.directory 'exit.json'
        if (-not $item.directory -or -not (Test-Path -LiteralPath $receiptPath)) { $unknown++; continue }
        $receipt=Read-TeamData $receiptPath
        $nativePath=Join-Path $item.directory 'native-process.json'
        if ($receipt['startup_exhausted'] -eq $true -and -not (Test-Path -LiteralPath $nativePath)) {
            # Durable proof that no native process was created: release without charging.
            $released=[int]$item.reserved
            $State.agents_reserved-=$item.reserved; $item.reserved=0; $settled++
            Add-TeamEvent $Directory 'reservation_reconciled' @{task_id=$taskId;result='never_started';released=$released}
            continue
        }
        $settledStreams=[bool]($receipt['transport_cleanup'] -and $receipt.transport_cleanup['streams_settled'])
        if (-not $settledStreams) { $unknown++; continue }
        $created=$null
        if (Test-Path -LiteralPath (Join-Path $item.directory 'agents.json')) {
            try { $created=@((Read-TeamData (Join-Path $item.directory 'agents.json')).agents).Count } catch { $created=$null }
        }
        if ($null -eq $created) { $unknown++; continue }
        # Charge only what the native receipt proves; release the rest.
        $charge=[Math]::Min([int]$item.reserved,[int]$created)
        $State.agents_created+=$charge; $State.agents_reserved-=$item.reserved; $item.reserved=0; $settled++
        Add-TeamEvent $Directory 'reservation_reconciled' @{task_id=$taskId;result='native_receipt';created=$charge;released=([int]$charge -eq 0)}
    }
    return @{settled=$settled;unknown=$unknown;held=$held}
}

function Test-TeamInfrastructureFailure($State, [string]$Directory, [string]$TaskId, $Manifest) {
    $item=$State.tasks[$TaskId]
    if (-not $item -or [int]$item['attempts'] -lt 1) { return @{eligible=$false;reason='task has no failed attempt'} }
    if ($item.status -notin @('FAILED','ESCALATED')) { return @{eligible=$false;reason="task status $($item.status) is not an infrastructure failure state"} }
    if ($item.status -eq 'ESCALATED') {
        $pending=@(Get-ChildItem -LiteralPath (Join-Path $Directory 'escalations') -Filter '*.yaml' -ErrorAction SilentlyContinue |
            ForEach-Object { Read-TeamData $_.FullName } | Where-Object { $_.status -eq 'pending' -and $_.context['task_id'] -eq $TaskId })
        if ($pending.Count) { return @{eligible=$false;reason='a pending escalation must be resolved before infrastructure recovery'} }
    }
    $ownership = Get-TeamOwnedProcessState $item
    if (@($ownership.live).Count) { return @{eligible=$false;reason='a run-owned process is still active; wait for its durable receipt'} }
    if (@($ownership.unknown).Count) {
        $sources = @($ownership.unknown | ForEach-Object { "$($_.source):$($_.pid)" }) -join ', '
        return @{eligible=$false;reason="run-owned process ownership cannot be proven ($sources); usage stays unknown"}
    }
    if (@($ownership.unresolved).Count) {
        $details = @($ownership.unresolved | ForEach-Object { "$($_.source): $($_.detail)" }) -join '; '
        return @{eligible=$false;reason="owned process cleanup is not settled ($details)"}
    }
    $nativePath=Join-Path $item.directory 'native-process.json'
    $receiptPath=Join-Path $item.directory 'exit.json'
    if (-not (Test-Path -LiteralPath $receiptPath)) { return @{eligible=$false;reason='no durable adapter exit receipt; usage stays unknown'} }
    $receipt=Read-TeamData $receiptPath
    if ($receipt['input_too_large'] -eq $true) { return @{eligible=$false;reason='input capacity failure requires an explicit replan/split'} }
    $startupExhausted=$receipt['startup_exhausted'] -eq $true
    $settledStreams=[bool]($receipt['transport_cleanup'] -and $receipt.transport_cleanup['streams_settled'])
    if (-not $settledStreams -and -not $startupExhausted) { return @{eligible=$false;reason='adapter streams are not settled; unknown usage is retained'} }
    # A successful author exit cannot explain a later verification/review failure.
    if (-not $receipt.Contains('exit_code') -or [int]$receipt.exit_code -eq 0) {
        return @{eligible=$false;reason='no failed adapter exit for this attempt; verification and review failures require a replan'}
    }
    $failures=@()
    if ($State['worker_failures']) {
        foreach ($key in @($State.worker_failures.Keys)) {
            $record=$State.worker_failures[$key]
            if ($key.StartsWith("$TaskId/",[StringComparison]::Ordinal) -and
                [int]$record['attempt'] -eq [int]$item.attempts -and $record['directory'] -and
                [IO.Path]::GetFullPath($record.directory) -ieq [IO.Path]::GetFullPath($item.directory)) { $failures+=$record }
        }
    }
    if (@($failures | Where-Object { $_['infra_kind'] -notin @('idle','start','transport','hard','output') }).Count) {
        return @{eligible=$false;reason='this attempt has a non-infrastructure failure; preserve its counters and replan'}
    }
    $kinds=@($failures | ForEach-Object { $_.infra_kind } | Sort-Object -Unique)
    if ($kinds.Count -gt 1) { return @{eligible=$false;reason='conflicting infrastructure evidence for this attempt'} }
    $failure=if ($failures.Count) {$failures[0]} else {$null}
    $kind=$null
    if ($startupExhausted) { $kind='start' }
    elseif ($failure -and $failure['infra_kind'] -in @('idle','start','transport')) { $kind=[string]$failure['infra_kind'] }
    elseif ($receipt['timeout_kind'] -eq 'idle') { $kind='idle' }
    elseif ($receipt['exit_code'] -eq 30 -and -not (Test-Path -LiteralPath $nativePath)) { $kind='transport' }
    if (-not $kind) {
        # A hard total timeout or an output overflow is still an infrastructure-class attempt
        # (it is never relabelled as a semantic failure), but it is deliberately not
        # auto-recoverable: the bound was reached, so an owner decision is required.
        $recordedKind = if ($failure) {[string]$failure['infra_kind']} else {[string]$receipt['timeout_kind']}
        if ($recordedKind -in @('hard','output')) {
            return @{eligible=$false;reason="recorded '$recordedKind' termination is bounded but not auto-recoverable; hard timeouts and output overflows keep their counters pending an owner decision";failure=$failure}
        }
        $recorded=if ($failure) {$failure['kind']} else {"exit $($receipt['exit_code'])"}
        return @{eligible=$false;reason="recorded failure ($recorded) is not transport/start/idle; verification, business, review and scope failures keep their counters";failure=$failure}
    }
    return @{eligible=$true;infra_kind=$kind;failure=$failure;receipt=$receipt;settled=$true}
}

function Invoke-TeamInfrastructureRecovery($State, $Plan, $Manifest, [string]$Directory, [string]$TaskId, [string]$Reason) {
    Assert-TeamId $TaskId
    if (-not $Reason -or -not $Reason.Trim()) { Stop-TeamError 10 'Infrastructure recovery requires a -Reason' }
    if (-not $State.tasks.Contains($TaskId)) { Stop-TeamError 10 'Unknown task' }
    if ($State.status -in @('COMPLETED','CANCELLED')) { Stop-TeamError 80 'Terminal run cannot recover a task' }
    # Recovery retires an attempt and makes its task dispatchable again: the frozen protocol
    # identity is verified before any of that can move.
    $null = Assert-TeamReuseRunProtocol $State $Directory
    Assert-TeamCleanupSettled $State
    # Eligibility is decided from durable evidence before anything can move the budget: a
    # rejected recovery must leave reservations exactly as they were.
    $eligibility=Test-TeamInfrastructureFailure $State $Directory $TaskId $Manifest
    if (-not $eligibility.eligible) { Stop-TeamError 10 "Task $TaskId is not eligible for infrastructure recovery: $($eligibility.reason)" }
    $item=$State.tasks[$TaskId]
    $null=Sync-TeamTerminalReservations $State $Directory $Manifest
    if ([int]$item['reserved']) {
        Stop-TeamError 10 "Reservation usage for $TaskId cannot be proven settled; unknown usage is retained and a retry would double count it"
    }
    if ([int]$item.attempts -gt [int]$Manifest.budget.max_worker_retries) {
        New-TeamEscalation $State $Directory 'infra_retry_limit' 'Worker attempt cap reached; infrastructure recovery does not bypass it.' @{task_id=$TaskId;attempts=$item.attempts}
        Stop-TeamError 60 'Worker attempt cap reached; owner decision required'
    }
    if ([int]$State['infra_retries'] -ge [int]$Manifest.budget.max_worker_retries) { Stop-TeamError 60 'Infrastructure recovery cap reached; owner decision required' }
    $task=@($Plan.tasks | Where-Object { $_.id -eq $TaskId })[0]
    if (-not $task) { Stop-TeamError 10 'Task is not part of the frozen plan' }
    # Retire the failed attempt as evidence, never as a new baseline: the replacement starts
    # from the original base and the prior worktree, branch and dirty content stay on disk.
    $worktreeExists=$item['worktree'] -and (Test-Path -LiteralPath $item['worktree'] -PathType Container)
    $head=if ($worktreeExists) { Invoke-TeamGit $item.worktree @('rev-parse','HEAD') } else { '' }
    $dirty=if ($worktreeExists) { Invoke-TeamGit $item.worktree @('status','--porcelain','--untracked-files=all') } else { '' }
    $retired=$item | ConvertTo-Json -Depth 60 | ConvertFrom-Json -AsHashtable
    $retired['task_id']=$TaskId; $retired['retired_from']=$item.status; $retired.status='DISCARDED'
    $retired['discard_reason']="infrastructure recovery ($($eligibility.infra_kind)): $Reason"
    $retired['discard_revision']=[int]$State.revision
    $retired['discard_commit']=$(if ($item['commit']) {$item['commit']} else {$head})
    $retired['retire_kind']='infrastructure'; $retired['infra_kind']=$eligibility.infra_kind
    $retired['retired_head']=$head; $retired['retired_dirty']=[bool]$dirty; $retired['retired_dirty_sha256']=Get-TeamTextHash $dirty
    $retired['retired_base_sha']=$item['base_sha']
    if (-not $State['discarded_tasks']) { $State['discarded_tasks']=@{} }
    $key="$TaskId-a$($item.attempts)-i$([int]$State.revision)"
    while ($State.discarded_tasks.ContainsKey($key)) { $key+='-b' }
    $State.discarded_tasks[$key]=$retired
    $State['infra_retries']=[int]$State['infra_retries']+1
    $nextAttempt=[int]$item.attempts+1
    $item.status='READY'; $item.commit=''; $item.pid=0; $item.process_start=''
    $State.status='PAUSED'
    $id='REC-'+[guid]::NewGuid().ToString('N').Substring(0,12)
    Write-TeamData (Join-Path $Directory "recovery/$id.json") @{ id=$id; run_id=$State.run_id; task_id=$TaskId
        plan_hash=$State.plan_hash; revision=[int]$State.revision; kind=$eligibility.infra_kind; reason=$Reason
        retired_key=$key; retired_head=$head; retired_dirty=[bool]$dirty; attempt=[int]$item.attempts
        next_attempt=$nextAttempt; base_sha=$item['base_sha']; semantic_replans=[int]$State.replans
        infra_retries=[int]$State['infra_retries']
        evidence=@{ receipt=(Get-TeamRootRelativePath $Directory (Join-Path $item.directory 'exit.json'))
            startup_exhausted=[bool]$eligibility.receipt['startup_exhausted']; timeout_kind=$eligibility.receipt['timeout_kind']
            settled=$eligibility.settled; run_owned_processes='none active' }
        created_at=[DateTime]::UtcNow.ToString('o') }
    Save-TeamState $State $Directory
    Add-TeamEvent $Directory 'infrastructure_recovery_recorded' @{task_id=$TaskId;kind=$eligibility.infra_kind;recovery_id=$id
        retired_key=$key;next_attempt=$nextAttempt;semantic_replans=[int]$State.replans;infra_retries=[int]$State['infra_retries']}
    return @{ status='PAUSED'; task_id=$TaskId; recovery_id=$id; infra_kind=$eligibility.infra_kind; retired_key=$key
        attempt=[int]$item.attempts; next_attempt=$nextAttempt; base_sha=$item['base_sha']
        semantic_replans=[int]$State.replans; infra_retries=[int]$State['infra_retries']
        retired_dirty=[bool]$dirty
        next='resume; the retired attempt keeps its worktree, branch and evidence and is never silently baselined.' }
}
