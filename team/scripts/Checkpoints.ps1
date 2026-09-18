function Save-TeamIntegrationOperation([string]$Directory, $Operation) {
    Assert-TeamId $Operation.id
    Write-TeamData (Join-Path $Directory "integration-operations/$($Operation.id).json") $Operation
}

function Get-TeamPendingIntegration([string]$Directory) {
    return @(Get-ChildItem (Join-Path $Directory 'integration-operations') -Filter '*.json' -ErrorAction SilentlyContinue |
        ForEach-Object { Read-TeamData $_.FullName } | Where-Object { $_.phase -in @('prepared','merged','verification_failed') })
}

function Initialize-TeamIntegrationTree($State, [string]$Directory) {
    $expected=Get-TeamChild $State.repo ".worktrees/$($State.run_id)-integration"
    if (-not $State.integration_worktree) {
        Assert-TeamWorktreeCapacity $State.repo
        $State.integration_worktree=$expected; $State['integration_creation_pending']=$true
        Save-TeamState $State $Directory
    }
    if ($State.integration_worktree -cne $expected) { Stop-TeamError 82 'Integration worktree identity mismatch' }
    if ($State['integration_creation_pending']) {
        if (-not (Test-Path -LiteralPath $expected)) {
            $existing=& git -C $State.repo rev-parse --verify "refs/heads/$($State.integration_branch)" 2>$null
            if ($LASTEXITCODE -eq 0) {
                if ($existing -cne $State.run_base_sha) { Stop-TeamError 80 'Pending integration branch moved before worktree creation' }
                $null=Invoke-TeamGit $State.repo @('worktree','add',$expected,$State.integration_branch)
            } else {
                $null=Invoke-TeamGit $State.repo @('worktree','add','-b',$State.integration_branch,$expected,$State.run_base_sha)
            }
        }
        if ((Invoke-TeamGit $expected @('branch','--show-current')) -cne $State.integration_branch -or
            (Invoke-TeamGit $expected @('rev-parse','HEAD')) -cne $State.run_base_sha -or
            (Invoke-TeamGit $expected @('status','--porcelain','--untracked-files=all'))) { Stop-TeamError 80 'Pending integration worktree differs from its creation intent' }
        $State.integration_creation_pending=$false; Save-TeamState $State $Directory
    }
}

function Complete-TeamIntegrationCheckpoint($State, $Plan, $Manifest, [string]$Directory, $Operation) {
    $id=$Operation.task_id; $item=$State.tasks[$id]; $tree=$State.integration_worktree
    $task=@($Plan.tasks | Where-Object id -eq $id)[0]
    $head=Invoke-TeamGit $tree @('rev-parse','HEAD')
    $path=Join-Path $Directory "checkpoints/$id.json"
    $checkpoint=$null
    if (Test-Path -LiteralPath $path) {
        $candidate=Read-TeamData $path
        if ($candidate['operation_id'] -ceq $Operation.id) { $checkpoint=$candidate }
    }
    if (-not $checkpoint) {
        $checkpoint=@{task_id=$id;attempt=$item.attempts;before=$Operation.before;after=$head;
            worker_commit=$item.commit;verified=$false;noop=($head -ceq $Operation.before);operation_id=$Operation.id}
        Save-TeamCheckpoint $Directory $checkpoint
    }
    if ($checkpoint.before -cne $Operation.before -or $checkpoint.after -cne $head -or
        $checkpoint.worker_commit -cne $item.commit -or $checkpoint.attempt -ne $item.attempts -or $checkpoint['rollback_commit']) {
        Stop-TeamError 80 'Pending integration checkpoint identity changed'
    }
    if ($Operation.phase -eq 'verification_failed') { Stop-TeamError 40 'Preserved integration verification failed; rollback or repair before continuing' }
    if ($checkpoint.verified) {
        $evidencePath=Join-Path $checkpoint.evidence_directory 'verification-evidence.json'
        if (-not $checkpoint['evidence_hash'] -or -not (Test-Path -LiteralPath $evidencePath) -or (Get-TeamHash $evidencePath) -cne $checkpoint.evidence_hash) { Stop-TeamError 80 'Integration verification evidence changed or is missing' }
        foreach ($entry in @(Read-TeamData $evidencePath)) {
            foreach ($stream in @('stdout','stderr')) {
                # Newer evidence records its own (possibly suffixed) log file; legacy evidence
                # keeps the original derived name.
                $name=if ($entry["${stream}_file"]) {[string]$entry["${stream}_file"]} else {"verification-$($entry.id).$stream"}
                $streamPath=Get-TeamChild $checkpoint.evidence_directory $name
                if (-not (Test-Path -LiteralPath $streamPath) -or (Get-TeamHash $streamPath) -cne $entry["${stream}_sha256"]) { Stop-TeamError 80 'Integration verification output changed or is missing' }
            }
        }
    } else {
        if ($Operation['verification_directory']) {
            $priorEvidence=Join-Path $Operation.verification_directory 'verification-evidence.json'
            if ((Test-Path -LiteralPath $priorEvidence) -and @(Read-TeamData $priorEvidence | Where-Object { $_.exit_code -ne 0 }).Count) {
                $Operation.phase='verification_failed'; Save-TeamIntegrationOperation $Directory $Operation
                Stop-TeamError 40 'Recovered failed integration evidence; do not rerun it to replace the failure'
            }
        }
        # Every replay gets its own evidence directory; interrupted output is preserved.
        $verificationDirectory=Join-Path $Directory ("integration-evidence/$id-a$($item.attempts)-$head/"+[guid]::NewGuid().ToString('N'))
        [IO.Directory]::CreateDirectory($verificationDirectory) | Out-Null
        $Operation['verification_directory']=$verificationDirectory; Save-TeamIntegrationOperation $Directory $Operation
        try { $null=Invoke-TeamVerification $task.verification $tree $verificationDirectory 'verification' $Manifest.runtime }
        catch {
            $Operation.phase='verification_failed'; $Operation['evidence_directory']=$verificationDirectory
            Save-TeamIntegrationOperation $Directory $Operation
            $State.status='PAUSED'; Save-TeamState $State $Directory; throw
        }
        if ((Invoke-TeamGit $tree @('status','--porcelain','--untracked-files=all')) -or (Invoke-TeamGit $tree @('rev-parse','HEAD')) -cne $head) { Stop-TeamError 82 'Integration verification modified source or HEAD' }
        $checkpoint.verified=$true; $checkpoint['evidence_directory']=$verificationDirectory
        $checkpoint['evidence_hash']=Get-TeamHash (Join-Path $verificationDirectory 'verification-evidence.json')
    }
    $sourceIds=@()
    if ($State['repairs'] -and $State.repairs.Contains($id)) {
        $repair=$State.repairs[$id]
        $sources=if ($repair['source_commits']) {@($repair.source_commits)} else {@($repair.source_commit)}
        foreach ($source in $sources) { $null=Invoke-TeamGit $tree @('merge-base','--is-ancestor',$source,$head) }
        $sourceIds=@(Get-TeamRepairSources $repair)
    }
    Save-TeamCheckpoint $Directory $checkpoint
    $State.last_good_integration_sha=$head; $item.status='MERGED'; $State['last_merged_task']=$id
    foreach ($sourceId in $sourceIds) { $State.tasks[$sourceId].status='MERGED' }
    $State.status='PAUSED'; Save-TeamState $State $Directory
    $Operation.phase='completed'; $Operation['after']=$head; Save-TeamIntegrationOperation $Directory $Operation
    Add-TeamEvent $Directory 'task_merged' @{task_id=$id;commit=$head;operation_id=$Operation.id}
}

function Restore-TeamIntegration($State, $Plan, $Manifest, [string]$Directory) {
    if ($State['integration_creation_pending']) { Initialize-TeamIntegrationTree $State $Directory }
    $pending=@(Get-TeamPendingIntegration $Directory)
    if (-not $pending.Count) { return }
    if ($pending.Count -ne 1) { Stop-TeamError 80 'Multiple unfinished integration operations require reconciliation' }
    $op=$pending[0]; $id=$op.task_id
    if ($op.run_id -cne $State.run_id -or $op.plan_hash -cne $State.plan_hash -or -not $State.tasks.Contains($id)) { Stop-TeamError 80 'Integration intent belongs to another run or plan' }
    $item=$State.tasks[$id]; $tree=Get-TeamChild $State.repo ".worktrees/$($State.run_id)-integration"
    if ($item.commit -cne $op.worker_commit -or $item.attempts -ne $op.attempt -or
        $item.status -notin @('ACCEPTED','MERGED') -or $State.integration_worktree -cne $tree -or
        (Invoke-TeamGit $tree @('branch','--show-current')) -cne $State.integration_branch) { Stop-TeamError 80 'Integration intent no longer matches accepted work' }
    $head=Invoke-TeamGit $tree @('rev-parse','HEAD')
    $mergeHead=& git -C $tree rev-parse -q --verify MERGE_HEAD 2>$null
    if ($LASTEXITCODE -eq 0) {
        if ($head -cne $op.before -or $mergeHead -cne $op.worker_commit) { Stop-TeamError 80 'Pending integration merge is not owned by this operation' }
        $conflicts=@((Invoke-TeamGit $tree @('diff','--name-only','--diff-filter=U')) -split "`n" | Where-Object { $_ })
        if (-not $conflicts.Count) { Stop-TeamError 80 'Unfinished merge has no unresolved paths; preserve it for reconciliation' }
        Write-TeamData (Join-Path $Directory 'integration-conflict.json') @{task_id=$id;base_sha=$op.before;conflicts=$conflicts;
            write_scope_policy='conflict_files_plus_explicit_glue_scope';may_change_interfaces=$false;operation_id=$op.id}
        $op.phase='conflict'; Save-TeamIntegrationOperation $Directory $op
        $State.status='PAUSED'; Save-TeamState $State $Directory
        Stop-TeamError 81 'Recovered owned integration conflict; approve a bounded repair or rollback'
    }
    if (Invoke-TeamGit $tree @('status','--porcelain','--untracked-files=all')) { Stop-TeamError 80 'Pending integration contains dirty changes; preserve evidence' }
    if ($head -ceq $op.before -and $op.phase -eq 'prepared') {
        $op.phase='not_started'; Save-TeamIntegrationOperation $Directory $op
        Add-TeamEvent $Directory 'integration_reconciled' @{task_id=$id;operation_id=$op.id;result='safe_to_retry'}
        return
    }
    if ($head -cne $op.before) {
        $parents=(Invoke-TeamGit $tree @('show','-s','--format=%P',$head)) -split ' '
        if ($parents.Count -ne 2 -or $parents[0] -cne $op.before -or $parents[1] -cne $op.worker_commit -or
            (Invoke-TeamGit $tree @('show','-s','--format=%B',$head)) -cne "Team integration $($op.id)") { Stop-TeamError 80 'Integration HEAD is not the exact merge recorded by the pending intent' }
    } else {
        $null=Invoke-TeamGit $tree @('merge-base','--is-ancestor',$op.worker_commit,$head)
    }
    if ($State.last_good_integration_sha -cne $op.before -and $State.last_good_integration_sha -cne $head) { Stop-TeamError 80 'Integration state moved beyond the pending operation' }
    if ($op['after'] -and $op.after -cne $head) { Stop-TeamError 80 'Pending merge SHA changed' }
    Complete-TeamIntegrationCheckpoint $State $Plan $Manifest $Directory $op
}
