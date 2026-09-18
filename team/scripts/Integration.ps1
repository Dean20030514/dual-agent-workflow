function Accept-TeamTask($State, $Plan, [string]$Directory, [string]$TaskId, [string]$Commit, [string]$Reason) {
    Assert-TeamId $TaskId
    if (-not $State.tasks.Contains($TaskId)) { Stop-TeamError 10 'Unknown task' }
    $item = $State.tasks[$TaskId]
    if ($item.status -ne 'REVIEW' -or $item.commit -cne $Commit -or -not $Reason.Trim()) {
        Stop-TeamError 50 'Lead acceptance requires REVIEW state, exact commit, and a reason'
    }
    $task = @($Plan.tasks | Where-Object { $_.id -eq $TaskId })[0]
    if (-not (Test-TeamReviewAccepted $Directory "LOCAL-$TaskId" $State.plan_hash $Commit)) { Stop-TeamError 50 'Lead acceptance requires the bound DSH Local Review and handled evidence items' }
    if (($Plan.classification.level -eq 'critical' -or (Test-TeamGovernanceChange $item.worktree $item.base_sha $Commit)) -and -not (Test-TeamReviewAccepted $Directory "9A-$TaskId" $State.plan_hash $Commit)) {
        Stop-TeamError 50 'Critical acceptance requires the bound independent 9A and handled evidence items'
    }
    $null = Read-WorkerResult $item $task $State.run_id
    $evidencePath = Join-Path $item.directory 'verification-evidence.json'
    $evidence = Read-TeamData $evidencePath
    if (@($evidence | Where-Object { $_.exit_code -ne 0 }).Count) { Stop-TeamError 40 'Verification evidence is not green' }
    $decisionId = 'DEC-' + [guid]::NewGuid().ToString('N').Substring(0,12)
    Write-TeamData (Join-Path $Directory "decisions/$decisionId.json") @{
        id = $decisionId; task_id = $TaskId; decision = 'accept'; actor = 'lead'; reason = $Reason
        commit = $Commit; plan_hash = $State.plan_hash; evidence_hash = Get-TeamHash $evidencePath
        timestamp = [DateTime]::UtcNow.ToString('o')
    }
    $item.status = 'ACCEPTED'; Save-TeamState $State $Directory
    Add-TeamEvent $Directory 'task_accepted' @{ task_id = $TaskId; commit = $Commit; decision = $decisionId }
}

function Invoke-TeamIntegration($State, $Plan, [string]$Directory, $Manifest = $null) {
    if ($State.status -in @('CANCELLED','COMPLETED','ESCALATED')) { Stop-TeamError 80 'Run is not available for integration' }
    if (-not $Manifest) { $Manifest=Read-TeamData (Join-Path $Directory 'manifest.yaml') }
    Initialize-TeamIntegrationTree $State $Directory
    Restore-TeamIntegration $State $Plan $Manifest $Directory
    $tree = $State.integration_worktree
    if (Invoke-TeamGit $tree @('status','--porcelain','--untracked-files=all')) { Stop-TeamError 80 'Integration worktree is dirty; reconcile before integration' }
    if ((Invoke-TeamGit $tree @('rev-parse','HEAD')) -cne $State.last_good_integration_sha) { Stop-TeamError 80 'Integration HEAD differs from last accepted checkpoint' }
    $State.status = 'INTEGRATING'; Save-TeamState $State $Directory
    foreach ($taskId in $State.order) {
        $item = $State.tasks[$taskId]
        if ($item.status -ne 'ACCEPTED') { continue }
        $task = @($Plan.tasks | Where-Object { $_.id -eq $taskId })[0]
        if (@($task.dependencies | Where-Object { $State.tasks[$_].status -notin @('MERGED','CLEANED') }).Count) { continue }
        $null = Read-WorkerResult $item $task $State.run_id
        $previousPath=Join-Path $Directory "checkpoints/$taskId.json"
        if (Test-Path -LiteralPath $previousPath) {
            $previous=Read-TeamData $previousPath
            if ($previous['rollback_commit'] -and -not $previous['noop'] -and $previous.worker_commit -ceq $item.commit) { Stop-TeamError 80 'A reverted source commit cannot be merged again unchanged; replan or use an integration repair' }
        }
        $before = $State.last_good_integration_sha
        $operation=@{id=('MERGE-'+[guid]::NewGuid().ToString('N'));run_id=$State.run_id;plan_hash=$State.plan_hash;
            task_id=$taskId;attempt=$item.attempts;worker_commit=$item.commit;before=$before;phase='prepared'}
        Save-TeamIntegrationOperation $Directory $operation
        Add-TeamEvent $Directory 'integration_started' @{ task_id = $taskId; base_sha = $before; commit = $item.commit }
        # Merge only into the run-owned integration worktree, never the caller's branch.
        $mergeOutput = & git -C $tree merge --no-ff -m "Team integration $($operation.id)" $item.commit 2>&1
        if ($LASTEXITCODE -ne 0) {
            $conflicts = Invoke-TeamGit $tree @('diff','--name-only','--diff-filter=U')
            if (-not $conflicts) { Stop-TeamError 80 'Git merge failed without merge conflicts; inspect Git state before recovery' }
            Write-TeamData (Join-Path $Directory 'integration-conflict.json') @{
                task_id = $taskId; base_sha = $before; conflicts = @($conflicts -split "`n" | Where-Object { $_ })
                write_scope_policy = 'conflict_files_plus_explicit_glue_scope'; may_change_interfaces = $false
            }
            $operation.phase='conflict'; Save-TeamIntegrationOperation $Directory $operation
            $State.status = 'PAUSED'; Save-TeamState $State $Directory
            Add-TeamEvent $Directory 'integration_conflict' @{ task_id = $taskId }
            Stop-TeamError 81 'Integration conflict retained; Lead must approve a bounded integration task or rollback'
        }
        $mergedHead = Invoke-TeamGit $tree @('rev-parse','HEAD')
        $operation.phase='merged'; $operation['after']=$mergedHead; Save-TeamIntegrationOperation $Directory $operation
        Complete-TeamIntegrationCheckpoint $State $Plan $Manifest $Directory $operation
    }
    $remaining = @($State.tasks.Values | Where-Object { $_.status -notin @('MERGED','CLEANED') })
    if ($remaining.Count) { $State.status = 'PAUSED' }
    else {
        $State.status = 'VERIFYING'; Save-TeamState $State $Directory
        $finalHead = Invoke-TeamGit $tree @('rev-parse','HEAD')
        $State['final_evidence_directory']=Join-Path $Directory "final-evidence/$($State.revision)-$finalHead"
        [IO.Directory]::CreateDirectory($State.final_evidence_directory) | Out-Null
        Save-TeamState $State $Directory
        try { $null = Invoke-TeamVerification $Plan.verification.final $tree $State.final_evidence_directory 'final' $Manifest.runtime -Reuse:([bool]$State['verification_reuse']) -CacheDirectory $Directory }
        catch {
            if ($_.Exception.Data['TeamExitCode'] -eq 40) { Record-TeamIntegrationFailure $State $Plan $Directory }
            throw
        }
        if ((Invoke-TeamGit $tree @('diff','HEAD','--name-only')) -or (Invoke-TeamGit $tree @('rev-parse','HEAD')) -cne $finalHead) { Stop-TeamError 82 'Final verification modified source or HEAD' }
        if ($Plan.classification.level -eq 'critical') {
            $null = Invoke-TeamReview $State $Plan $Manifest $Directory '9B' $tree $State.run_base_sha $State.last_good_integration_sha
        }
        $State.status = 'COMPLETED'
        $failurePath=Join-Path $Directory 'integration-failure.json'
        if (Test-Path -LiteralPath $failurePath) {
            $failure=Read-TeamData $failurePath; $failure.status='resolved'; $failure['resolved_sha']=$finalHead
            Write-TeamData $failurePath $failure
        }
        Save-TeamState $State $Directory
        Unlock-TeamRepo $State.repo $State.run_id
        Add-TeamEvent $Directory 'run_completed' @{ integration_commit = $State.last_good_integration_sha }
    }
    Save-TeamState $State $Directory
    return @{ status = $State.status; integration_branch = $State.integration_branch; commit = $State.last_good_integration_sha }
}

function Resume-TeamRun($State, $Plan, $Manifest, [string]$Directory) {
    if ($State.status -in @('COMPLETED','CANCELLED')) { Stop-TeamError 80 'Terminal run cannot resume' }
    if ((Get-TeamHash (Join-Path $Directory 'plan.yaml')) -cne $State.plan_hash) { Stop-TeamError 80 'Plan changed outside revision protocol' }
    $null = Test-TeamPlan $Plan $Manifest
    if (-not $Manifest.team.enabled) { Stop-TeamError 20 'Team disabled' }
    if (Test-Path -LiteralPath (Join-Path $Directory 'cancel.request.json')) { Stop-TeamError 80 'Cancelled run cannot resume' }
    Restore-TeamIntegration $State $Plan $Manifest $Directory
    # Settle terminal reservations from durable owned-process/native evidence before validating.
    $null = Sync-TeamTerminalReservations $State $Directory $Manifest
    Assert-TeamRecovery $State $Plan $Directory
    Assert-TeamActionApproval $State $Plan $Directory
    Assert-TeamReviewRound $State $Plan $Directory
    # Plan-declared prerequisites must hold before any new author is admitted.
    $null = Invoke-TeamPrerequisites $State $Plan $Manifest $Directory
    if ($Plan.classification.level -eq 'critical') {
        if (-not (Test-TeamReviewAccepted $Directory '9P' $State.plan_hash $State.run_base_sha)) {
            $base = $State.run_base_sha
            $null = Invoke-TeamReview $State $Plan $Manifest $Directory '9P' $State.repo $base $base
        }
    }
    foreach ($task in $Plan.tasks) {
        $item = $State.tasks[$task.id]
        # An active pre-local-review run may already be waiting for Lead acceptance.
        # Upgrade that pending task through verification/review without rerunning its author.
        if ($item.status -eq 'REVIEW' -and -not (Test-Path (Join-Path $Directory "reviews/LOCAL-$($task.id).json"))) { $item.status='VERIFYING' }
        if ($item.status -notin @('RUNNING','RESULT_READY','VERIFYING','LOCAL_REVIEW')) { continue }
        if ($item.pid) {
            $process = Get-TeamOwnedProcess $item.pid $item.process_start
            if ($process) {
                Stop-TeamError 80 'Original worker is still active; use status and resume after it exits'
            }
        }
        Complete-TeamWorkerSafely $State $task $Directory $Plan $Manifest
    }
    if (@($State.tasks.Values | Where-Object { $_.status -in @('FAILED','FAILED_SCOPE','REWORK','ESCALATED') }).Count) {
        Stop-TeamError 80 'Failed tasks require an explicit replan; no blind worker retry'
    }
    $pending = @(Get-ChildItem -LiteralPath (Join-Path $Directory 'escalations') -Filter '*.yaml' -ErrorAction SilentlyContinue |
        ForEach-Object { Read-TeamData $_.FullName } | Where-Object { $_.status -eq 'pending' })
    if ($pending.Count) { Stop-TeamError 70 'Unresolved escalation keeps dispatch paused' }
    return Invoke-TeamDispatch $State $Plan $Manifest $Directory
}

function Remove-TeamWorktrees($State, [string]$Directory) {
    $removed = @()
    foreach ($taskId in $State.tasks.Keys) {
        $item = $State.tasks[$taskId]
        if ($item.status -ne 'MERGED') { continue }
        if ($item['worktree_removed']) { $item.status='CLEANED'; Save-TeamState $State $Directory; continue }
        $expected = Get-TeamChild $State.repo ".worktrees/$($State.run_id)-$taskId-$((Read-TeamData (Join-Path $item.directory 'task.yaml')).role.id)-a$($item.attempts)"
        if ($item.worktree -cne $expected) { Stop-TeamError 82 'Cleanup path mismatch' }
        if (Invoke-TeamGit $expected @('status','--porcelain','--untracked-files=all')) { Stop-TeamError 80 'Cleanup refuses a dirty worktree' }
        if ((Invoke-TeamGit $expected @('rev-parse','HEAD')) -cne $item.commit) { Stop-TeamError 80 'Cleanup refuses an altered worktree' }
        # Long paths are common once a worktree holds a real dependency tree; the flag is
        # per command so no global Git configuration is changed.
        $null = Invoke-TeamGit $State.repo @('-c','core.longpaths=true','worktree','remove',$expected)
        # `git worktree remove` may unregister and still leave the directory behind; only a
        # verified-gone path is reported as removed, so cleanup never claims a false success.
        $directoryGone = -not (Test-Path -LiteralPath $expected -PathType Container)
        $item.status = 'CLEANED'; $item['worktree_removed']=$directoryGone; $item['directory_removal_pending']=(-not $directoryGone)
        $removed += $taskId
        Save-TeamState $State $Directory
        if (-not $directoryGone) {
            Add-TeamEvent $Directory 'cleanup_directory_removal_pending' @{task_id=$taskId;path=$expected}
        }
    }
    $discarded=@()
    if ($State['discarded_tasks']) {
        foreach ($key in @($State.discarded_tasks.Keys)) {
            $item=$State.discarded_tasks[$key]
            if ($item.status -ne 'DISCARDED' -or $item['worktree_removed']) { continue }
            $taskId=$item.task_id; Assert-TeamId $taskId
            $packet=Read-TeamData (Join-Path $item.directory 'task.yaml')
            $expected=Get-TeamChild $State.repo ".worktrees/$($State.run_id)-$taskId-$($packet.role.id)-a$($item.attempts)"
            if ($item.worktree -cne $expected -or $packet.task_id -cne $taskId -or $packet.run_id -cne $State.run_id) { Stop-TeamError 82 'Discarded worktree identity mismatch' }
            if (Invoke-TeamGit $expected @('status','--porcelain','--untracked-files=all')) { Stop-TeamError 80 'Cleanup preserves dirty discarded worktree evidence' }
            if ((Invoke-TeamGit $expected @('branch','--show-current')) -cne $item.branch -or
                (Invoke-TeamGit $expected @('rev-parse','HEAD')) -cne $item.discard_commit) { Stop-TeamError 80 'Discarded worktree changed after its retirement' }
            $null=Invoke-TeamGit $State.repo @('-c','core.longpaths=true','worktree','remove',$expected)
            $directoryGone = -not (Test-Path -LiteralPath $expected -PathType Container)
            $item['worktree_removed']=$directoryGone; $item['directory_removal_pending']=(-not $directoryGone)
            $discarded+=$key
            # A replanned task may still point at its retired attempt until next dispatch.
            if ($State.tasks.Contains($taskId) -and $State.tasks[$taskId].worktree -ceq $expected) { $State.tasks[$taskId]['worktree_removed']=$directoryGone }
            Save-TeamState $State $Directory
            Add-TeamEvent $Directory 'discarded_worktree_cleaned' @{task_id=$taskId;attempt=$item.attempts;commit=$item.discard_commit;directory_removed=$directoryGone}
        }
    }
    return @{ removed = $removed; discarded_removed=$discarded; integration_preserved = $true }
}
