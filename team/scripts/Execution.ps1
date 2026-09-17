function New-TeamWorktree([string]$Repo, [string]$RunId, [string]$TaskId, [string]$Role, [string]$Base, [string]$Suffix = '') {
    foreach ($id in @($RunId,$TaskId,$Role)) { Assert-TeamId $id }
    $root = Get-TeamChild $Repo '.worktrees'
    [IO.Directory]::CreateDirectory($root) | Out-Null
    if (@(Get-ChildItem -LiteralPath $root -Directory).Count -ge 12) { Stop-TeamError 20 'Worktree count limit reached' }
    $path = Get-TeamChild $root "$RunId-$TaskId-$Role$Suffix"
    $branch = "codex/team/$RunId/$TaskId/$Role$Suffix"
    $null = Invoke-TeamGit $Repo @('worktree','add','-b',$branch,$path,$Base)
    return @{ path = $path; branch = $branch }
}

function Start-TeamWorker($State, $Task, $Manifest, [string]$Directory) {
    $allowChildren = $Task.subagents.allowed -and $State.known_cost -lt $Manifest.budget.soft_limit
    $reservation = if ($allowChildren) { 3 } else { 1 }
    if (($State.agents_created + $State.agents_reserved + $reservation) -gt $Manifest.budget.max_agents_per_run) { Stop-TeamError 70 'Cumulative agent budget reached' }
    $item = $State.tasks[$Task.id]
    $base = if ($Task.dependencies.Count -or $Task.role -eq 'integration') { $State.last_good_integration_sha } else { $State.run_base_sha }
    if ($Task.dependencies.Count) {
        foreach ($dependency in $Task.dependencies) {
            if ($State.tasks[$dependency].status -notin @('MERGED','CLEANED')) { Stop-TeamError 80 'Dependency not integrated' }
        }
    }
    $item.attempts++
    $worktree = New-TeamWorktree $State.repo $State.run_id $Task.id $Task.role $base "-a$($item.attempts)"
    $item.worktree = $worktree.path; $item.branch = $worktree.branch; $item.base_sha = $base
    $item.directory = Get-TeamChild $Directory "tasks/$($Task.id)/attempt-$($item.attempts)"
    [IO.Directory]::CreateDirectory($item.directory) | Out-Null
    $packet = @{
        schema_version = 1; run_id = $State.run_id; task_id = $Task.id; role = @{ id = $Task.role }
        objective = $Task.objective; dependencies = $Task.dependencies; permissions = $Task.permissions
        write_scope = $Task.write_scope; acceptance = $Task.acceptance; subagents = @{allowed=$allowChildren;max_depth=$(if ($allowChildren) {2} else {0})}
        verification = $Task.verification
        base_sha = $base; result_schema = 'team/schemas/result.schema.json'
    }
    Test-TeamSchema $packet 'task'
    $taskPath = Join-Path $item.directory 'task.yaml'
    Write-TeamData $taskPath $packet
    $item['reserved'] = $reservation
    $item['agent_limit'] = $reservation
    $State.agents_reserved += $reservation
    $patchPath = Join-Path $item.directory 'worker.patch.yaml'
    New-DshPatch $patchPath @{maxAgents=$reservation;maxDepth=$(if ($allowChildren) {2} else {0});cwd=$item.worktree;
        provider=$Manifest.models.worker.provider;model=$Manifest.models.worker.runtime_model;receipt=(Join-Path $item.directory 'agents.json');budgetControl=(Join-Path $Directory 'budget-control.json')}
    $item.status = 'RUNNING'; $State.status = 'RUNNING'
    # Persist intent before launch; an interrupted launch is reconciled, never relaunched blindly.
    Save-TeamState $State $Directory
    $args = @('-TaskFile',$taskPath,'-Worktree',$item.worktree,'-OutputFile',(Join-Path $item.directory 'result.yaml'),
        '-Patch',$patchPath,'-Profile',$Manifest.runtime.profile,
        '-TimeoutSeconds',[string]$Manifest.runtime.timeout_seconds)
    $handle = New-TeamProcess (Join-Path $PSScriptRoot 'Invoke-DshWorker.ps1') $args $item.worktree (Join-Path $item.directory 'adapter.stdout') (Join-Path $item.directory 'adapter.stderr')
    $item.pid = $handle.process.Id; $item.process_start = $handle.process.StartTime.ToUniversalTime().ToString('o')
    Save-TeamState $State $Directory
    Add-TeamEvent $Directory 'worker_started' @{ task_id = $Task.id; pid = $item.pid; base_sha = $base }
    return $handle
}

function Invoke-TeamVerification($Commands, [string]$Worktree, [string]$Directory, [string]$Prefix) {
    $evidence = @()
    foreach ($command in $Commands) {
        Assert-TeamId $command.id
        $out = Join-Path $Directory "$Prefix-$($command.id).stdout"
        $err = Join-Path $Directory "$Prefix-$($command.id).stderr"
        $handle = New-TeamProcess $command.executable @($command.args) $Worktree $out $err
        try { $exitCode = Wait-TeamProcess $handle $command.timeout_seconds }
        catch { $exitCode = 31 }
        $evidence += @{ id = $command.id; executable = $command.executable; args = $command.args; exit_code = $exitCode; stdout_sha256 = Get-TeamHash $out; stderr_sha256 = Get-TeamHash $err }
        Write-TeamData (Join-Path $Directory "$Prefix-evidence.json") $evidence
        if ($exitCode -ne 0) { Stop-TeamError 40 "Verification failed: $($command.id), exit $exitCode" }
    }
    return $evidence
}

function Complete-TeamWorker($State, $Task, [string]$Directory, $Plan = $null, $Manifest = $null) {
    $item = $State.tasks[$Task.id]
    $receiptPath = Join-Path $item.directory 'exit.json'
    if (-not (Test-Path -LiteralPath $receiptPath)) { Stop-TeamError 80 'Worker process ended without exit receipt; evidence retained' }
    $receipt = Read-TeamData $receiptPath
    if ($receipt.exit_code -ne 0) {
        $mapped = if ($receipt.exit_code -in @(10,31)) { $receipt.exit_code } else { 30 }
        Stop-TeamError $mapped "Worker $($Task.id) exited $($receipt.exit_code)"
    }
    $native = Read-TeamData (Join-Path $item.directory 'agents.json')
    if ($native.agents.Count -lt 1 -or $native.agents.Count -gt $item.agent_limit) { Stop-TeamError 82 'Native agent receipt violates reservation' }
    if ($item.reserved) {
        $State.agents_created += $native.agents.Count; $State.agents_reserved -= $item.reserved; $item.reserved = 0
        Save-TeamState $State $Directory
    }
    $audit = Read-WorkerResult $item $Task $State.run_id
    if ($State.Contains('repairs') -and $State.repairs.Contains($Task.id)) {
        $null = Invoke-TeamGit $item.worktree @('merge-base','--is-ancestor',$State.repairs[$Task.id].source_commit,$audit.commit)
    }
    if ($audit.result.subagents_used.Count -ne @($native.agents | Where-Object { $_.depth -gt 0 -and $_.state -eq 'created' }).Count) {
        Stop-TeamError 82 'Native child count differs from Result Packet'
    }
    $item.commit = $audit.commit; $item.status = 'VERIFYING'
    Save-TeamState $State $Directory
    $null = Invoke-TeamVerification $Task.verification $item.worktree $item.directory 'verification'
    # Verification may generate files, but must not change tracked source or HEAD.
    if ((Invoke-TeamGit $item.worktree @('rev-parse','HEAD')) -cne $item.commit -or
        (Invoke-TeamGit $item.worktree @('diff','HEAD','--name-only'))) { Stop-TeamError 82 'Verification modified source' }
    if ($Plan -and $Plan.classification.level -eq 'critical') {
        $null = Invoke-TeamReview $State $Plan $Manifest $Directory '9A' $item.worktree $item.base_sha $item.commit $Task.id
    }
    $item.status = 'REVIEW'; $State.status = 'PAUSED'
    Save-TeamState $State $Directory
    Add-TeamEvent $Directory 'lead_review_required' @{ task_id = $Task.id; commit = $item.commit }
}

function Invoke-TeamDispatch($State, $Plan, $Manifest, [string]$Directory) {
    Assert-TeamActionApproval $State $Plan $Directory
    $handles = @{}
    try {
        $State.status = 'RUNNING'; Save-TeamState $State $Directory
        do {
            Sync-TeamCost $State $Manifest $Directory
            if (Test-Path -LiteralPath (Join-Path $Directory 'cancel.request.json')) {
                foreach ($key in @($handles.Keys)) { $null = Close-TeamProcess $handles[$key] -Terminate; $handles.Remove($key) }
                Stop-TeamOwnedProcesses $State $Directory
                return @{status='CANCELLED';run_id=$State.run_id}
            }
            foreach ($taskId in $State.order) {
                Sync-TeamCost $State $Manifest $Directory
                $task = @($Plan.tasks | Where-Object { $_.id -eq $taskId })[0]
                $item = $State.tasks[$taskId]
                if ($item.status -ne 'READY') { continue }
                if (@($task.dependencies | Where-Object { $State.tasks[$_].status -notin @('MERGED','CLEANED') }).Count) { continue }
                if ($handles.Count -ge $Manifest.budget.max_active_workers) { break }
                $slots = if ($task.subagents.allowed -and $State.known_cost -lt $Manifest.budget.soft_limit) {3} else {1}
                if (($State.agents_reserved + $slots) -gt $Manifest.budget.max_parallel_agents_total) { continue }
                if ($State.known_cost -ge $Manifest.budget.hard_limit) {
                    $State.status = 'PAUSED'; break
                }
                if ($State.known_cost -ge $Manifest.budget.soft_limit) {
                    if ($task['optional']) { Add-TeamEvent $Directory 'optional_dispatch_skipped' @{ task_id = $taskId }; continue }
                    if ($handles.Count -gt 0) { break }
                }
                $handles[$taskId] = Start-TeamWorker $State $task $Manifest $Directory
            }
            foreach ($taskId in @($handles.Keys)) {
                $handle = $handles[$taskId]; $item = $State.tasks[$taskId]
                $logs = @(Get-ChildItem -LiteralPath $item.directory -File | Where-Object { $_.Extension -in @('.stdout','.stderr') })
                $size = ($logs | Measure-Object Length -Sum).Sum
                if ($size -ne $handle.last_size) { $handle.last_activity = [DateTime]::UtcNow; $handle.last_size = $size }
                $timeout = ([DateTime]::UtcNow - $handle.started).TotalSeconds -gt ($Manifest.runtime.timeout_seconds + 10)
                $idle = ([DateTime]::UtcNow - $handle.last_activity).TotalSeconds -gt $Manifest.runtime.idle_timeout_seconds
                $overLog = @($logs | Where-Object { $_.Length -gt ($Manifest.runtime.max_single_log_mb * 1MB) }).Count -gt 0
                if ($timeout -or $idle -or $overLog) {
                    $null = Close-TeamProcess $handle -Terminate; $handles.Remove($taskId)
                    $State.agents_created += $item.reserved; $State.agents_reserved -= $item.reserved; $item.reserved=0
                    $item.status = 'FAILED'; Save-TeamState $State $Directory
                    Stop-TeamError 31 'Worker timeout, idle timeout, or output limit reached'
                }
                if ($handle.process.HasExited) {
                    $null = Close-TeamProcess $handle; $handles.Remove($taskId)
                    $task = @($Plan.tasks | Where-Object { $_.id -eq $taskId })[0]
                    try { Complete-TeamWorker $State $task $Directory $Plan $Manifest }
                    catch {
                        if ($item.reserved) {
                            # Unknown usage consumes the entire reservation; never undercount a failed launch.
                            $State.agents_created += $item.reserved; $State.agents_reserved -= $item.reserved; $item.reserved=0
                        }
                        $item.status = if ($_.Exception.Data['TeamExitCode'] -eq 82) { 'FAILED_SCOPE' }
                            elseif ($_.Exception.Data['TeamExitCode'] -eq 70 -and $State.status -eq 'ESCALATED') { 'REVIEW' }
                            else { 'FAILED' }
                        Save-TeamState $State $Directory; throw
                    }
                }
            }
            if ($handles.Count) { Start-Sleep -Milliseconds 250 }
        } while ($handles.Count)
        Sync-TeamCost $State $Manifest $Directory
        if ($State.status -eq 'RUNNING') { $State.status = 'PAUSED' }
        Save-TeamState $State $Directory
        return @{ status = $State.status; run_id = $State.run_id; next = 'Inspect evidence; accept task with a SHA-bound Lead decision, then integrate/resume.' }
    } finally {
        # On coordinator errors, terminate only child processes created by this invocation.
        foreach ($taskId in @($handles.Keys)) {
            $null = Close-TeamProcess $handles[$taskId] -Terminate
            $item = $State.tasks[$taskId]
            $State.agents_created += $item.reserved; $State.agents_reserved -= $item.reserved; $item.reserved=0
            $item.status = 'FAILED'
        }
        Save-TeamState $State $Directory
    }
}
