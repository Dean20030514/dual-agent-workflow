function New-TeamIntegrationRepair($State, $Plan, $Manifest, [string]$Directory, [string[]]$GlueScope, [string]$Reason) {
    if (-not $Reason) { Stop-TeamError 10 'Integration repair requires a Lead Decision Log reason' }
    if ($State.replans -ge $Manifest.budget.max_replans) { Stop-TeamError 60 'Replan limit reached' }
    $conflict = Read-TeamData (Join-Path $Directory 'integration-conflict.json')
    $sourceTask = @($Plan.tasks | Where-Object { $_.id -eq $conflict.task_id })[0]
    $source = $State.tasks[$sourceTask.id]
    if ($source.status -ne 'ACCEPTED') { Stop-TeamError 80 'Conflicting source is no longer ACCEPTED' }
    $scope = @(@($conflict.conflicts) + $GlueScope | Sort-Object -Unique)
    $changed = (Invoke-TeamGit $source.worktree @('diff','--name-only','--no-renames',$source.base_sha,$source.commit)) -split "`n"
    foreach ($path in $changed) {
        if ($path -and -not (Test-TeamScope $path $scope)) { Stop-TeamError 10 "Explicit glue scope is needed for accepted incoming file: $path" }
    }
    $id = 'INTEGRATION-' + ($State.replans + 1)
    $task = @{
        id=$id;role='integration';objective=@(
            "Merge accepted commit $($source.commit) into your assigned branch and resolve its conflicts.",
            "Conflict files: $($conflict.conflicts -join ', '). Explicit glue scope: $($GlueScope -join ', ').",
            'Preserve approved interfaces and acceptance. Do not add business requirements or weaken tests. Commit the resolved merge; the incoming commit must be an ancestor of HEAD.')
        dependencies=@($State.tasks.Keys | Where-Object { $State.tasks[$_].status -in @('MERGED','CLEANED') })
        write_scope=$scope;acceptance=@('Incoming accepted commit is an ancestor; approved contracts preserved; targeted and full regressions pass')
        verification=$sourceTask.verification;permissions=@{shell=$true;network=$false;secrets=$false;production=$false}
        subagents=@{allowed=$false;max_depth=0}
    }
    $next = $Plan | ConvertTo-Json -Depth 80 | ConvertFrom-Json -AsHashtable
    $next.run.revision++; if ($next.mode -eq 'L1') { $next.mode='L2' }; $next.tasks += $task
    $order = @(Test-TeamPlan $next $Manifest)
    Assert-TeamReviewRound $State $Plan $Directory -Close
    # Preserve the failed merge's file list before aborting only our own integration merge.
    $null = Invoke-TeamGit $State.integration_worktree @('merge','--abort')
    if ((Invoke-TeamGit $State.integration_worktree @('rev-parse','HEAD')) -cne $State.last_good_integration_sha) { Stop-TeamError 80 'Integration abort did not restore checkpoint' }
    Write-TeamData (Join-Path $Directory "plan-revision-$($State.revision).yaml") $Plan
    Write-TeamData (Join-Path $Directory 'plan.yaml') $next
    if (-not $State.Contains('repairs')) { $State['repairs']=@{} }
    $State.repairs[$id]=@{source_task=$sourceTask.id;source_commit=$source.commit;write_scope=$scope}
    $State.tasks[$id]=@{status='READY';attempts=0;commit='';pid=0;process_start='';directory='';worktree='';branch='';base_sha=''}
    $source.status='REPAIRING'; $State.revision=$next.run.revision; $State.replans++; $State.order=$order
    $State.plan_hash=Get-TeamHash (Join-Path $Directory 'plan.yaml'); $State.status='PAUSED'
    Write-TeamData (Join-Path $Directory "decisions/DEC-Integration-$($State.revision).json") @{
        reason=$Reason;conflict_files=$conflict.conflicts;glue_scope=$GlueScope;task_id=$id;source_commit=$source.commit;revision=$State.revision
    }
    Save-TeamState $State $Directory
    Add-TeamEvent $Directory 'integration_worker_planned' @{task_id=$id;source_task=$sourceTask.id}
    return @{task_id=$id;revision=$State.revision;next='resume; inspect and accept the repair, then integrate'}
}
