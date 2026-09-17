function Invoke-TeamReplan($State, $OldPlan, $NewPlan, $Manifest, [string]$Directory, [string]$FailedTask, [string]$Reason) {
    $order = @(Test-TeamPlan $NewPlan $Manifest)
    if ($State.replans -ge $Manifest.budget.max_replans) { Stop-TeamError 60 'Replan limit reached; hard-stop' }
    if ($NewPlan.run.id -cne $State.run_id -or $NewPlan.run.revision -ne ($State.revision + 1) -or -not $Reason) {
        Stop-TeamError 10 'Replan requires same run ID, next revision, and a Decision Log reason'
    }
    if ($NewPlan.classification.level -cne $OldPlan.classification.level) { Stop-TeamError 10 'Replan cannot silently change Routine/Critical classification' }
    if (@($State.tasks.Values | Where-Object { $_.status -eq 'RUNNING' }).Count) { Stop-TeamError 80 'Replan requires quiescent workers' }
    if (-not $State.tasks.Contains($FailedTask)) { Stop-TeamError 10 'Unknown failed task' }
    $oldTask = @($OldPlan.tasks | Where-Object { $_.id -eq $FailedTask })[0]
    $paths = @($oldTask.write_scope)
    $affected = @(Get-TeamAffected $OldPlan $FailedTask $paths)
    # Glob overlap needs a conservative prefix check when no concrete changed files are available.
    foreach ($task in $OldPlan.tasks) {
        foreach ($scope in $task.write_scope) {
            foreach ($failedScope in $paths) {
                $a = ($scope -split '[*?]',2)[0]; $b = ($failedScope -split '[*?]',2)[0]
                if ($a.StartsWith($b) -or $b.StartsWith($a)) { $affected += @(Get-TeamAffected $OldPlan $task.id @()) }
            }
        }
    }
    $affected = @($affected | Sort-Object -Unique)
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

function Stop-TeamOwnedProcesses($State, [string]$Directory) {
    foreach ($taskId in $State.tasks.Keys) {
        $item = $State.tasks[$taskId]
        if ($item.status -ne 'RUNNING') { continue }
        $nativePath = Join-Path $item.directory 'native-process.json'
        $records = @(@{pid=$item.pid;start=$item.process_start})
        if (Test-Path -LiteralPath $nativePath) { $records += Read-TeamData $nativePath }
        foreach ($record in $records) {
            if (-not $record.pid) { continue }
            $process = Get-Process -Id $record.pid -ErrorAction SilentlyContinue
            if ($process -and $process.StartTime.ToUniversalTime().ToString('o') -ceq $record.start) {
                $process.Kill($true); $process.WaitForExit()
            }
        }
        $item.status = 'FAILED'
        if ($item['reserved']) { $State.agents_created += $item.reserved; $State.agents_reserved -= $item.reserved; $item.reserved=0 }
    }
    $State.status = 'CANCELLED'; Save-TeamState $State $Directory
    Add-TeamEvent $Directory 'run_cancelled'
    Unlock-TeamRepo $State.repo $State.run_id
}

function Undo-TeamIntegration($State, [string]$Directory, [string]$TaskId, [string]$Reason) {
    if (-not $Reason -or -not $State.integration_worktree) { Stop-TeamError 80 'Rollback requires integration worktree and reason' }
    $tree = Get-TeamChild $State.repo ".worktrees/$($State.run_id)-integration"
    if ($tree -cne $State.integration_worktree) { Stop-TeamError 82 'Integration worktree path mismatch' }
    $mergeHead = & git -C $tree rev-parse -q --verify MERGE_HEAD 2>$null
    if ($LASTEXITCODE -eq 0) {
        $null = Invoke-TeamGit $tree @('merge','--abort')
    } else {
        Assert-TeamId $TaskId
        $checkpoint = Read-TeamData (Join-Path $Directory "checkpoints/$TaskId.json")
        $head = Invoke-TeamGit $tree @('rev-parse','HEAD')
        if ($head -cne $checkpoint.after) { Stop-TeamError 80 'Rollback supports the most recent integration checkpoint only' }
        if (Invoke-TeamGit $tree @('status','--porcelain')) { Stop-TeamError 80 'Rollback refuses unrelated dirty changes' }
        $null = Invoke-TeamGit $tree @('revert','-m','1','--no-edit',$head)
        $State.tasks[$TaskId].status = 'REWORK'
    }
    $State.last_good_integration_sha = Invoke-TeamGit $tree @('rev-parse','HEAD')
    $State.status = 'PAUSED'; Save-TeamState $State $Directory
    Add-TeamEvent $Directory 'integration_rollback' @{ task_id=$TaskId; reason=$Reason; commit=$State.last_good_integration_sha }
    return @{status='PAUSED';commit=$State.last_good_integration_sha}
}
