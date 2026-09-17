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
        if ((Invoke-TeamGit $expected @('branch','--show-current')) -cne $item.branch) { Stop-TeamError 80 'Task is no longer on its assigned branch' }
        $null = Invoke-TeamGit $expected @('merge-base','--is-ancestor',$item.base_sha,'HEAD')
        if ($item.status -in @('RUNNING','VERIFYING')) {
            $processes = @(@{pid=$item.pid;start=$item.process_start})
            $nativePath = Join-Path $item.directory 'native-process.json'
            if (Test-Path -LiteralPath $nativePath) { $processes += Read-TeamData $nativePath }
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
            $process = Get-TeamOwnedProcess $record.pid $record.start
            if ($process) {
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
