function Restore-TeamPlanRevision([string]$Directory, [string]$Repo, [string]$RunId) {
    $path=Join-Path $Directory 'revision-pending.json'
    if (-not (Test-Path -LiteralPath $path)) { return }
    $journal=Read-TeamData $path
    if ($journal.phase -eq 'completed') { return }
    if ($journal.phase -ne 'prepared' -or $journal.run_id -cne $RunId -or $journal.repo -cne $Repo) { Stop-TeamError 80 'Plan transaction identity mismatch' }
    Assert-TeamId $journal.id; Assert-TeamId $journal.decision_id
    $staging=Get-TeamChild $Directory "revision-transactions/$($journal.id)"
    foreach ($name in @('plan','state','decision','old-plan')) {
        $stagedPath=Join-Path $staging "$name.json"
        if (-not (Test-Path -LiteralPath $stagedPath) -or (Get-TeamHash $stagedPath) -cne $journal.hashes[$name]) { Stop-TeamError 80 'Prepared revision content changed or is missing; preserve transaction evidence' }
    }
    $currentPlan=Get-TeamHash (Join-Path $Directory 'plan.yaml')
    $currentState=Get-TeamHash (Join-Path $Directory 'state.json')
    if ($currentPlan -cne $journal.old_plan_hash -and $currentPlan -cne $journal.hashes.plan) { Stop-TeamError 80 'Plan changed outside the pending revision' }
    if ($currentState -cne $journal.old_state_hash -and $currentState -cne $journal.hashes.state) { Stop-TeamError 80 'State changed outside the pending revision' }
    $state=Read-TeamData (Join-Path $staging 'state.json'); $plan=Read-TeamData (Join-Path $staging 'plan.json')
    Test-TeamSchema $state 'state'
    $null=Test-TeamPlan $plan (Read-TeamData (Join-Path $Directory 'manifest.yaml'))
    if ($state.repo -cne $Repo -or $state.run_id -cne $RunId -or $plan.run.id -cne $RunId -or
        $state.plan_hash -cne $journal.hashes.plan -or $state.revision -ne $plan.run.revision -or
        $state.revision -ne ($journal.previous_revision+1)) { Stop-TeamError 80 'Prepared plan and state are inconsistent' }
    $targets=[ordered]@{'old-plan'="plan-revision-$($journal.previous_revision).yaml";plan='plan.yaml';decision="decisions/$($journal.decision_id).json";state='state.json'}
    foreach ($name in $targets.Keys) {
        $target=Get-TeamChild $Directory $targets[$name]
        if ((Test-Path -LiteralPath $target) -and (Get-TeamHash $target) -ceq $journal.hashes[$name]) { continue }
        if ($name -in @('old-plan','decision') -and (Test-Path -LiteralPath $target)) { Stop-TeamError 80 'Revision archive or decision already contains different evidence' }
        Write-TeamTextAtomic $target ([IO.File]::ReadAllText((Join-Path $staging "$name.json")))
    }
    $journal.phase='completed'; Write-TeamData $path $journal
    Add-TeamEvent $Directory 'plan_revision_committed' @{revision=$state.revision;transaction_id=$journal.id;decision=$journal.decision_id}
}

function Save-TeamPlanRevision($State, $OldPlan, $NewPlan, [string]$Directory, [string]$DecisionId, $Decision) {
    $pendingPath=Join-Path $Directory 'revision-pending.json'
    if ((Test-Path -LiteralPath $pendingPath) -and (Read-TeamData $pendingPath).phase -ne 'completed') { Stop-TeamError 80 'An unfinished revision must be reconciled first' }
    $oldPlanHash=Get-TeamHash (Join-Path $Directory 'plan.yaml'); $oldStateHash=Get-TeamHash (Join-Path $Directory 'state.json')
    $id='REV-'+[guid]::NewGuid().ToString('N'); $staging=Get-TeamChild $Directory "revision-transactions/$id"
    Write-TeamData (Join-Path $staging 'plan.json') $NewPlan
    # Preserve the exact old bytes, including historical YAML representations.
    Write-TeamTextAtomic (Join-Path $staging 'old-plan.json') ([IO.File]::ReadAllText((Join-Path $Directory 'plan.yaml')))
    $State.plan_hash=Get-TeamHash (Join-Path $staging 'plan.json')
    $State.updated_at=[DateTime]::UtcNow.ToString('o'); Test-TeamSchema $State 'state'
    $Decision['plan_hash']=$State.plan_hash
    Write-TeamData (Join-Path $staging 'state.json') $State
    Write-TeamData (Join-Path $staging 'decision.json') $Decision
    $hashes=@{}; foreach ($name in @('plan','state','decision','old-plan')) { $hashes[$name]=Get-TeamHash (Join-Path $staging "$name.json") }
    Write-TeamData $pendingPath @{id=$id;run_id=$State.run_id;repo=$State.repo;phase='prepared';previous_revision=$OldPlan.run.revision;
        old_plan_hash=$oldPlanHash;old_state_hash=$oldStateHash;hashes=$hashes;decision_id=$DecisionId}
    Restore-TeamPlanRevision $Directory $State.repo $State.run_id
}
