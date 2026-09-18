function Assert-TeamWorktreeCapacity([string]$Repo) {
    $root = Get-TeamChild $Repo '.worktrees'
    if ((Test-Path -LiteralPath $root) -and @(Get-ChildItem -LiteralPath $root -Directory).Count -ge 12) { Stop-TeamError 20 'Worktree count limit reached' }
}

function New-TeamWorktree([string]$Repo, [string]$RunId, [string]$TaskId, [string]$Role, [string]$Base, [string]$Suffix = '') {
    foreach ($id in @($RunId,$TaskId,$Role)) { Assert-TeamId $id }
    Assert-TeamWorktreeCapacity $Repo
    $root = Get-TeamChild $Repo '.worktrees'
    [IO.Directory]::CreateDirectory($root) | Out-Null
    $path = Get-TeamChild $root "$RunId-$TaskId-$Role$Suffix"
    $branch = "codex/team/$RunId/$TaskId/$Role$Suffix"
    $null = Invoke-TeamGit $Repo @('worktree','add','-b',$branch,$path,$Base)
    return @{ path = $path; branch = $branch }
}

function Start-TeamWorker($State, $Task, $Manifest, [string]$Directory) {
    if ($Task.role -eq 'integration') {
        if (-not $State.Contains('repairs') -or -not $State.repairs.Contains($Task.id)) {
            Stop-TeamError 10 'Integration workers must be generated from a recorded integration conflict or regression'
        }
        $repair = $State.repairs[$Task.id]
        if ($repair['write_scope'] -and @(Compare-Object @($repair.write_scope | Sort-Object) @($Task.write_scope | Sort-Object)).Count) {
            Stop-TeamError 82 'Integration task scope differs from its recorded conflict and glue decision'
        }
    }
    $rolePath = Join-Path $Directory "roles/$($Task.role).yaml"
    if (-not (Test-Path -LiteralPath $rolePath)) { Write-TeamData $rolePath (Get-TeamRole $Task.role) }
    $role = Get-TeamRole $Task.role $Directory
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
    $nextAttempt=$item.attempts+1
    $worktree = New-TeamWorktree $State.repo $State.run_id $Task.id $Task.role $base "-a$nextAttempt"
    $item.attempts=$nextAttempt
    $item.worktree = $worktree.path; $item.branch = $worktree.branch; $item.base_sha = $base
    $item['worktree_removed']=$false
    $item.directory = Get-TeamChild $Directory "tasks/$($Task.id)/attempt-$($item.attempts)"
    [IO.Directory]::CreateDirectory($item.directory) | Out-Null
    $packet = @{
        schema_version = 1; run_id = $State.run_id; task_id = $Task.id; role = @{ id = $Task.role; definition = $role }
        objective = $Task.objective; dependencies = $Task.dependencies; permissions = $Task.permissions
        write_scope = $Task.write_scope; acceptance = $Task.acceptance; subagents = @{allowed=$allowChildren;max_depth=$(if ($allowChildren) {2} else {0})}
        verification = $Task.verification
        base_sha = $base; result_schema = 'team/schemas/result.schema.json'
    }
    Test-TeamTask $packet
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
        '-TimeoutSeconds',[string]$Manifest.runtime.timeout_seconds,
        '-IdleTimeoutSeconds',[string]$Manifest.runtime.idle_timeout_seconds,'-MaxSingleLogMb',[string]$Manifest.runtime.max_single_log_mb)
    $handle = New-TeamProcess (Join-Path $PSScriptRoot 'Invoke-DshWorker.ps1') $args $item.worktree (Join-Path $item.directory 'adapter.stdout') (Join-Path $item.directory 'adapter.stderr') -MaxOutputBytes ($Manifest.runtime.max_single_log_mb * 1MB)
    $item.pid = $handle.process.Id; $item.process_start = $handle.process.StartTime.ToUniversalTime().ToString('o')
    Save-TeamState $State $Directory
    Add-TeamEvent $Directory 'worker_started' @{ task_id = $Task.id; pid = $item.pid; base_sha = $base }
    return $handle
}

function Invoke-TeamVerification($Commands, [string]$Worktree, [string]$Directory, [string]$Prefix, $Runtime = $null) {
    $evidence = @()
    $limit=if ($Runtime) { [long]$Runtime.max_single_log_mb * 1MB } else { 50MB }
    $idle=if ($Runtime) { [int]$Runtime.idle_timeout_seconds } else { 900 }
    foreach ($command in $Commands) {
        Assert-TeamId $command.id
        $out = Join-Path $Directory "$Prefix-$($command.id).stdout"
        $err = Join-Path $Directory "$Prefix-$($command.id).stderr"
        $handle=$null; $errorText=$null; $processStarted=$false
        try {
            $handle = New-TeamProcess $command.executable @($command.args) $Worktree $out $err -MaxOutputBytes $limit
            $processStarted=$true
            $exitCode = Wait-TeamProcess $handle $command.timeout_seconds $idle
        } catch {
            $errorText=$_.Exception.Message
            if ($_.Exception.Data.Contains('ProcessStarted')) { $processStarted=[bool]$_.Exception.Data['ProcessStarted'] }
            $exitCode=if ($_.Exception.Data.Contains('TeamExitCode')) {[int]$_.Exception.Data['TeamExitCode']} else {30}
        } finally { if ($handle -and -not $handle['closed']) { $null=Close-TeamProcess $handle -Terminate } }
        $evidence += @{ id=$command.id;executable=$command.executable;args=$command.args;exit_code=$exitCode
            process_started=$processStarted;process_exit_code=$(if ($handle) {$handle.exit_code} else {$null});error=$errorText
            stdout_sha256=$(if (Test-Path -LiteralPath $out -PathType Leaf) {Get-TeamHash $out} else {$null})
            stderr_sha256=$(if (Test-Path -LiteralPath $err -PathType Leaf) {Get-TeamHash $err} else {$null}) }
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
    if ($receipt['startup_exhausted']) {
        # Both launch attempts are known not to have created a native process.
        $State.agents_reserved -= $item.reserved; $item.reserved=0; $item.status='ESCALATED'
        New-TeamEscalation $State $Directory 'worker_start_failure' 'DSH did not start after two launch attempts' @{
            task_id=$Task.id;attempt=$item.attempts;launch_attempts=$receipt.launch_attempts
        }
        Stop-TeamError 30 'DSH startup retry exhausted; owner decision required'
    }
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
    $audit = Read-WorkerResult $item $Task $State.run_id -AllowIncomplete
    if ($audit.result.subagents_used.Count -ne @($native.agents | Where-Object { $_.depth -gt 0 -and $_.state -eq 'created' }).Count) {
        Stop-TeamError 82 'Native child count differs from Result Packet'
    }
    if ($audit.result.status -eq 'escalated') {
        $item.commit=$audit.commit; $item.status='ESCALATED'
        New-TeamEscalation $State $Directory 'worker_request' ($audit.result.summary -join ' ') @{
            task_id=$Task.id;attempt=$item.attempts;commit=$audit.commit;risks=$audit.result.risks
            result_hash=(Get-TeamHash (Join-Path $item.directory 'result.yaml'))
        }
        Stop-TeamError 70 'Worker requested an owner decision; no verification or acceptance performed'
    }
    if ($audit.result.status -ne 'completed' -or -not $audit.result.verification.passed) { Stop-TeamError 30 'Worker did not complete its self-check' }
    if ($State.Contains('repairs') -and $State.repairs.Contains($Task.id)) {
        $repair=$State.repairs[$Task.id]
        $sources=if ($repair['source_commits']) {@($repair.source_commits)} else {@($repair.source_commit)}
        foreach ($source in $sources) { $null = Invoke-TeamGit $item.worktree @('merge-base','--is-ancestor',$source,$audit.commit) }
    }
    $item.commit = $audit.commit; $item.status = 'VERIFYING'
    Save-TeamState $State $Directory
    $runtime=if ($Manifest) {$Manifest.runtime} else {$null}
    $null = Invoke-TeamVerification $Task.verification $item.worktree $item.directory 'verification' $runtime
    if ($State['verification_failures']) { $State.verification_failures.Remove($Task.id) }
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

function Complete-TeamWorkerSafely($State, $Task, [string]$Directory, $Plan, $Manifest) {
    try { Complete-TeamWorker $State $Task $Directory $Plan $Manifest }
    catch {
        $item = $State.tasks[$Task.id]
        if ($item.reserved) {
            # Unknown usage consumes the reservation, including a worker orphaned by a coordinator crash.
            $State.agents_created += $item.reserved; $State.agents_reserved -= $item.reserved; $item.reserved=0
        }
        $item.status = if ($_.Exception.Data['TeamExitCode'] -eq 82) { 'FAILED_SCOPE' }
            elseif ($item.status -eq 'ESCALATED') { 'ESCALATED' }
            elseif ($_.Exception.Data['TeamExitCode'] -eq 70 -and $State.status -eq 'ESCALATED') { 'REVIEW' }
            else { 'FAILED' }
        if ($_.Exception.Data['TeamExitCode'] -eq 82) { Add-TeamEvent $Directory 'scope_violation' @{task_id=$Task.id;message=$_.Exception.Message} }
        if ($_.Exception.Data['TeamExitCode'] -eq 40) { Record-TeamVerificationFailure $State $Directory $Task.id }
        Save-TeamState $State $Directory
        throw
    }
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
                $overLog = (Test-TeamProcessOutputLimit $handle) -or @($logs | Where-Object { $_.Length -gt ($Manifest.runtime.max_single_log_mb * 1MB) }).Count -gt 0
                if ($timeout -or $idle -or $overLog) {
                    $null = Close-TeamProcess $handle -Terminate; $handles.Remove($taskId)
                    $State.agents_created += $item.reserved; $State.agents_reserved -= $item.reserved; $item.reserved=0
                    $item.status = 'FAILED'; Save-TeamState $State $Directory
                    Stop-TeamError 31 'Worker timeout, idle timeout, or output limit reached'
                }
                if ($handle.process.HasExited) {
                    $null = Close-TeamProcess $handle; $handles.Remove($taskId)
                    $task = @($Plan.tasks | Where-Object { $_.id -eq $taskId })[0]
                    Complete-TeamWorkerSafely $State $task $Directory $Plan $Manifest
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
