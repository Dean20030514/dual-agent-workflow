function Accept-TeamTask($State, $Plan, [string]$Directory, [string]$TaskId, [string]$Commit, [string]$Reason) {
    Assert-TeamId $TaskId
    if (-not $State.tasks.Contains($TaskId)) { Stop-TeamError 10 'Unknown task' }
    $item = $State.tasks[$TaskId]
    if ($item.status -ne 'REVIEW' -or $item.commit -cne $Commit -or -not $Reason.Trim()) {
        Stop-TeamError 50 'Lead acceptance requires REVIEW state, exact commit, and a reason'
    }
    $task = @($Plan.tasks | Where-Object { $_.id -eq $TaskId })[0]
    if ($Plan.classification.level -eq 'critical' -and -not (Test-TeamReviewAccepted $Directory "9A-$TaskId" $State.plan_hash $Commit)) {
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
    if (-not $State.integration_worktree) {
        $path = Get-TeamChild $State.repo ".worktrees/$($State.run_id)-integration"
        $null = Invoke-TeamGit $State.repo @('worktree','add','-b',$State.integration_branch,$path,$State.run_base_sha)
        $State.integration_worktree = $path
        Save-TeamState $State $Directory
    }
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
        $before = $State.last_good_integration_sha
        Add-TeamEvent $Directory 'integration_started' @{ task_id = $taskId; base_sha = $before; commit = $item.commit }
        # Merge only into the run-owned integration worktree, never the caller's branch.
        $mergeOutput = & git -C $tree merge --no-ff --no-edit $item.commit 2>&1
        if ($LASTEXITCODE -ne 0) {
            $conflicts = Invoke-TeamGit $tree @('diff','--name-only','--diff-filter=U')
            if (-not $conflicts) { Stop-TeamError 80 'Git merge failed without merge conflicts; inspect Git state before recovery' }
            Write-TeamData (Join-Path $Directory 'integration-conflict.json') @{
                task_id = $taskId; base_sha = $before; conflicts = @($conflicts -split "`n" | Where-Object { $_ })
                write_scope_policy = 'conflict_files_plus_explicit_glue_scope'; may_change_interfaces = $false
            }
            $State.status = 'PAUSED'; Save-TeamState $State $Directory
            Add-TeamEvent $Directory 'integration_conflict' @{ task_id = $taskId }
            Stop-TeamError 81 'Integration conflict retained; Lead must approve a bounded integration task or rollback'
        }
        $mergedHead = Invoke-TeamGit $tree @('rev-parse','HEAD')
        Write-TeamData (Join-Path $Directory "checkpoints/$taskId.json") @{ task_id=$taskId;before=$before;after=$mergedHead;worker_commit=$item.commit;verified=$false }
        try { $null = Invoke-TeamVerification $task.verification $tree $Directory "integration-$taskId" }
        catch { $State.status = 'PAUSED'; Save-TeamState $State $Directory; throw }
        $checkpoint = Invoke-TeamGit $tree @('rev-parse','HEAD')
        if ((Invoke-TeamGit $tree @('diff','HEAD','--name-only')) -or $checkpoint -cne $mergedHead) { Stop-TeamError 82 'Integration verification modified source or HEAD' }
        $State.last_good_integration_sha = $checkpoint; $item.status = 'MERGED'
        if ($State.Contains('repairs') -and $State.repairs.Contains($taskId)) {
            $repair = $State.repairs[$taskId]
            $null = Invoke-TeamGit $tree @('merge-base','--is-ancestor',$repair.source_commit,$checkpoint)
            $State.tasks[$repair.source_task].status='MERGED'
        }
        Write-TeamData (Join-Path $Directory "checkpoints/$taskId.json") @{ task_id = $taskId; before = $before; after = $checkpoint; worker_commit = $item.commit; verified=$true }
        Save-TeamState $State $Directory
        Add-TeamEvent $Directory 'task_merged' @{ task_id = $taskId; commit = $checkpoint }
    }
    $remaining = @($State.tasks.Values | Where-Object { $_.status -notin @('MERGED','CLEANED') })
    if ($remaining.Count) { $State.status = 'PAUSED' }
    else {
        $State.status = 'VERIFYING'; Save-TeamState $State $Directory
        $finalHead = Invoke-TeamGit $tree @('rev-parse','HEAD')
        $null = Invoke-TeamVerification $Plan.verification.final $tree $Directory 'final'
        if ((Invoke-TeamGit $tree @('diff','HEAD','--name-only')) -or (Invoke-TeamGit $tree @('rev-parse','HEAD')) -cne $finalHead) { Stop-TeamError 82 'Final verification modified source or HEAD' }
        if ($Plan.classification.level -eq 'critical') {
            $null = Invoke-TeamReview $State $Plan $Manifest $Directory '9B' $tree $State.run_base_sha $State.last_good_integration_sha
        }
        $State.status = 'COMPLETED'
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
    Assert-TeamRecovery $State $Plan $Directory
    Assert-TeamActionApproval $State $Plan $Directory
    if ($Plan.classification.level -eq 'critical') {
        if (-not (Test-TeamReviewAccepted $Directory '9P' $State.plan_hash $State.run_base_sha)) {
            $base = $State.run_base_sha
            $null = Invoke-TeamReview $State $Plan $Manifest $Directory '9P' $State.repo $base $base
        }
    }
    foreach ($task in $Plan.tasks) {
        $item = $State.tasks[$task.id]
        if ($item.status -notin @('RUNNING','VERIFYING')) { continue }
        if ($item.pid) {
            $process = Get-TeamOwnedProcess $item.pid $item.process_start
            if ($process) {
                Stop-TeamError 80 'Original worker is still active; use status and resume after it exits'
            }
        }
        Complete-TeamWorkerSafely $State $task $Directory $Plan $Manifest
    }
    if (@($State.tasks.Values | Where-Object { $_.status -in @('FAILED','FAILED_SCOPE','REWORK') }).Count) {
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
        $expected = Get-TeamChild $State.repo ".worktrees/$($State.run_id)-$taskId-$((Read-TeamData (Join-Path $item.directory 'task.yaml')).role.id)-a$($item.attempts)"
        if ($item.worktree -cne $expected) { Stop-TeamError 82 'Cleanup path mismatch' }
        if (Invoke-TeamGit $expected @('status','--porcelain','--untracked-files=all')) { Stop-TeamError 80 'Cleanup refuses a dirty worktree' }
        if ((Invoke-TeamGit $expected @('rev-parse','HEAD')) -cne $item.commit) { Stop-TeamError 80 'Cleanup refuses an altered worktree' }
        $null = Invoke-TeamGit $State.repo @('worktree','remove',$expected)
        $item.status = 'CLEANED'; $removed += $taskId
        Save-TeamState $State $Directory
    }
    return @{ removed = $removed; integration_preserved = $true }
}
