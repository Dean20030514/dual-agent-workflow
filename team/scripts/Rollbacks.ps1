function Restore-TeamRollback($State, [string]$Directory) {
    $path=Join-Path $Directory 'rollback-pending.json'
    if (-not (Test-Path -LiteralPath $path)) { return }
    $batch=Read-TeamData $path
    if ($batch.status -in @('completed','aborted')) { return }
    if ($State.status -eq 'CANCELLED' -or (Test-Path -LiteralPath (Join-Path $Directory 'cancel.request.json'))) {
        Stop-TeamError 80 'Cancelled run cannot continue a pending rollback'
    }
    if ($batch.status -ne 'prepared' -or $batch.run_id -cne $State.run_id -or $batch.plan_hash -cne $State.plan_hash) {
        Stop-TeamError 80 'Rollback transaction belongs to another run or plan'
    }
    $tree=Get-TeamChild $State.repo ".worktrees/$($State.run_id)-integration"
    if ($State.integration_worktree -cne $tree -or (Invoke-TeamGit $tree @('branch','--show-current')) -cne $State.integration_branch) {
        Stop-TeamError 82 'Rollback worktree or branch identity changed'
    }
    if (@($State.tasks.Values | Where-Object { $_.status -in @('RUNNING','LOCAL_REVIEW') }).Count) { Stop-TeamError 80 'Rollback requires quiescent workers and reviewers' }
    $revertHead=& git -C $tree rev-parse -q --verify REVERT_HEAD 2>$null
    if ($LASTEXITCODE -eq 0) { Stop-TeamError 80 'Rollback has an unfinished revert; inspect it and use rollback to abort the owned conflict' }
    if (Invoke-TeamGit $tree @('status','--porcelain','--untracked-files=all')) { Stop-TeamError 80 'Pending rollback contains dirty changes; preserve them for reconciliation' }
    $expected=$batch.before
    $rolled=@()
    foreach ($entry in $batch.entries) {
        Assert-TeamId $entry.id
        $checkpoint=$entry.checkpoint; $taskId=$checkpoint.task_id
        if (-not $State.tasks.Contains($taskId) -or $State.tasks[$taskId].commit -cne $checkpoint.worker_commit -or
            $State.tasks[$taskId].attempts -ne $checkpoint.attempt) { Stop-TeamError 80 'Rollback source task identity changed' }
        $checkpointPath=Join-Path $Directory "checkpoints/$taskId.json"
        $current=Read-TeamData $checkpointPath
        foreach ($field in @('before','after','worker_commit','attempt','noop','operation_id')) {
            if ($current[$field] -cne $checkpoint[$field]) { Stop-TeamError 80 'Rollback checkpoint identity changed' }
        }
        $recordPath=Join-Path $Directory "rollbacks/$($entry.id).json"
        $record=$null
        if (Test-Path -LiteralPath $recordPath) {
            $record=Read-TeamData $recordPath
            if ($record.id -cne $entry.id -or $record.before -cne $expected -or $record.reverted_merge -cne $checkpoint.after -or
                $record.task_id -cne $taskId -or $record['batch_id'] -cne $batch.id) { Stop-TeamError 80 'Rollback receipt identity changed' }
            if ($record.status -eq 'completed') {
                if ($current['rollback_commit'] -cne $record.after -or $State.tasks[$taskId].status -ne 'REWORK') { Stop-TeamError 80 'Completed rollback receipt disagrees with durable state' }
                $expected=$record.after; $rolled+=$taskId
                continue
            }
            if ($record.status -ne 'started') { Stop-TeamError 80 'Rollback receipt cannot be replayed' }
        }
        $head=Invoke-TeamGit $tree @('rev-parse','HEAD')
        if (-not $record) {
            if ($head -cne $expected) { Stop-TeamError 80 'Rollback HEAD moved before its recorded intent' }
            $record=@{id=$entry.id;batch_id=$batch.id;task_id=$taskId;before=$expected;reverted_merge=$checkpoint.after;reason=$batch.reason;status='started'}
            Write-TeamData $recordPath $record
        }
        if ($head -ceq $expected) {
            if ($current['rollback_commit'] -and -not ($checkpoint['noop'] -and $current.rollback_commit -ceq $head)) { Stop-TeamError 80 'Rollback checkpoint claims a commit absent from HEAD' }
            if (-not $checkpoint['noop']) { $null=Invoke-TeamGit $tree @('revert','-m','1','--no-edit',$checkpoint.after) }
            $head=Invoke-TeamGit $tree @('rev-parse','HEAD')
        }
        if (-not $checkpoint['noop']) {
            $parents=(Invoke-TeamGit $tree @('show','-s','--format=%P',$head)) -split ' '
            $subject=Invoke-TeamGit $tree @('show','-s','--format=%s',$checkpoint.after)
            $message="Revert `"$subject`"`n`nThis reverts commit $($checkpoint.after), reversing`nchanges made to $($checkpoint.before)."
            if ($parents.Count -ne 1 -or $parents[0] -cne $expected -or (Invoke-TeamGit $tree @('show','-s','--format=%B',$head)) -cne $message) {
                Stop-TeamError 80 'Rollback HEAD is not the exact revert described by its intent'
            }
        } elseif ($head -cne $expected) { Stop-TeamError 80 'No-op rollback cannot adopt another commit' }
        if (($current['rollback_commit'] -and $current.rollback_commit -cne $head) -or
            ($record['after'] -and $record.after -cne $head)) { Stop-TeamError 80 'Rollback commit changed during recovery' }
        $record['after']=$head; Write-TeamData $recordPath $record
        $current['rollback_commit']=$head; $current['rollback_before']=$expected
        Save-TeamCheckpoint $Directory $current
        foreach ($operation in @(Get-TeamPendingIntegration $Directory)) {
            if ($operation.task_id -ceq $taskId -and $operation.worker_commit -ceq $checkpoint.worker_commit) {
                $operation.phase='rolled_back'; $operation['rollback_commit']=$head; Save-TeamIntegrationOperation $Directory $operation
            }
        }
        $ids=@($taskId)
        if ($State['repairs'] -and $State.repairs.Contains($taskId)) { $ids+=@(Get-TeamRepairSources $State.repairs[$taskId]) }
        foreach ($id in $ids) {
            if ($State.tasks[$id].status -eq 'CLEANED') { $State.tasks[$id]['worktree_removed']=$true }
            $State.tasks[$id].status='REWORK'
        }
        $State.last_good_integration_sha=$head; $State.status='PAUSED'; Save-TeamState $State $Directory
        $record.status='completed'; Write-TeamData $recordPath $record
        Add-TeamEvent $Directory 'integration_rollback' @{task_id=$taskId;reason=$batch.reason;reverted_merge=$checkpoint.after;commit=$head;transaction_id=$batch.id}
        $expected=$head; $rolled+=$taskId
    }
    if ((Invoke-TeamGit $tree @('rev-parse','HEAD')) -cne $expected -or $State.last_good_integration_sha -cne $expected) {
        Stop-TeamError 80 'Rollback final checkpoint differs from its completed receipts'
    }
    Record-TeamRollbackProbe $State (Read-TeamData (Join-Path $Directory 'plan.yaml')) $Directory $rolled
    $batch.status='completed'; $batch['after']=$expected; Write-TeamData $path $batch
    return @{status='PAUSED';commit=$expected;rolled_back=$rolled;affected=$batch.affected}
}
