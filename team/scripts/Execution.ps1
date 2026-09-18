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

function Start-TeamWorker($State, $Task, $Manifest, [string]$Directory, $Plan = $null) {
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
    if (-not (Test-Path -LiteralPath $rolePath)) { Write-TeamData $rolePath (Get-TeamRole $Task.role -Plan $Plan) }
    $role = Get-TeamRole $Task.role $Directory $Plan
    if (-not $Plan) { $Plan=@{tasks=@($Task)} }
    $admission=Get-TeamAgentAdmission $State $Plan $Manifest $Task
    if (-not $admission.admitted) { Stop-TeamError 70 'Remaining required authors and mandatory reviewers exceed the cumulative agent budget; replan before dispatch' }
    $allowChildren=$admission.allow_children; $reservation=$admission.slots
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
        base_sha = $base; result_schema = 'result-v1'; result_schema_sha256 = Get-TeamHash (Join-Path $script:TeamRoot 'schemas/result.schema.json')
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
        '-IdleTimeoutSeconds',[string]$Manifest.runtime.idle_timeout_seconds,'-MaxSingleLogMb',[string]$Manifest.runtime.max_single_log_mb,
        '-MaxPromptChars',[string]$(if ($Manifest.runtime['max_dsh_prompt_chars']) {$Manifest.runtime.max_dsh_prompt_chars} else {24000}),
        '-MaxPromptBytes',[string]$(if ($Manifest.runtime['max_review_input_bytes']) {$Manifest.runtime.max_review_input_bytes} else {4000000}))
    $handle = New-TeamProcess (Join-Path $PSScriptRoot 'Invoke-DshWorker.ps1') $args $item.worktree (Join-Path $item.directory 'adapter.stdout') (Join-Path $item.directory 'adapter.stderr') -MaxOutputBytes ($Manifest.runtime.max_single_log_mb * 1MB)
    $item.pid = $handle.process.Id; $item.process_start = $handle.process.StartTime.ToUniversalTime().ToString('o')
    # Observe real worktree/HEAD changes and native activity so a quiet author that is
    # really editing is not killed by a stdout-only idle deadline.
    $handle['activity_probe'] = New-TeamActivityProbe -Worktree $item.worktree -RootPid $handle.process.Id -ReceiptPath (Join-Path $item.directory 'activity.json')
    $handle['activity_probe_at'] = 0L; $handle['activity_probe_interval'] = 1000
    Save-TeamState $State $Directory
    Add-TeamEvent $Directory 'worker_started' @{ task_id = $Task.id; pid = $item.pid; base_sha = $base }
    return $handle
}

function Get-TeamVerificationLogPath([string]$Directory, [string]$Prefix, [string]$CommandId, [string]$Stream) {
    $plain = Join-Path $Directory "$Prefix-$CommandId.$Stream"
    if (-not (Test-Path -LiteralPath $plain)) { return $plain }
    # A superseded or resumed attempt keeps its previous logs; never overwrite evidence.
    for ($index = 2; $index -le 99; $index++) {
        $candidate = Join-Path $Directory "$Prefix-$CommandId-r$index.$Stream"
        if (-not (Test-Path -LiteralPath $candidate)) { return $candidate }
    }
    return (Join-Path $Directory "$Prefix-$CommandId-$([guid]::NewGuid().ToString('N')).$Stream")
}

function Invoke-TeamVerification($Commands, [string]$Worktree, [string]$Directory, [string]$Prefix, $Runtime = $null, [switch]$Reuse, [string]$CacheDirectory = '') {
    $evidence = @()
    $limit=if ($Runtime) { [long]$Runtime.max_single_log_mb * 1MB } else { 50MB }
    $idle=if ($Runtime) { [int]$Runtime.idle_timeout_seconds } else { 900 }
    foreach ($command in $Commands) {
        Assert-TeamId $command.id
        $out = Get-TeamVerificationLogPath $Directory $Prefix $command.id 'stdout'
        $err = Get-TeamVerificationLogPath $Directory $Prefix $command.id 'stderr'
        $handle=$null; $errorText=$null; $processStarted=$false; $reused=$false; $reuseRejected=$null
        $reuseKey=$null; $reuseSource=$null; $reuseHash=$null; $binding=$null; $timeoutKind=$null; $publishRejected=$null
        $watch=[Diagnostics.Stopwatch]::StartNew()
        if ($Reuse) {
            $binding = Get-TeamVerificationKey $Worktree $command.executable @($command.args) $command
            $lookup = Read-TeamVerificationCache $CacheDirectory $binding
            if ($lookup.hit) {
                foreach ($stream in @('stdout', 'stderr')) {
                    $target = if ($stream -eq 'stdout') { $out } else { $err }
                    $temporary = "$target.tmp-$([guid]::NewGuid().ToString('N'))"
                    try { [IO.File]::Copy($lookup.logs[$stream], $temporary, $false); [IO.File]::Move($temporary, $target) }
                    finally { if (Test-Path -LiteralPath $temporary) { [IO.File]::Delete($temporary) } }
                }
                $reused=$true; $reuseKey=$binding.key; $exitCode=0
                $reuseSource=Get-TeamRootRelativePath $CacheDirectory $lookup.path
                $reuseHash=Get-TeamHash $lookup.path
            } else { $reuseRejected=$lookup.reason }
        }
        if (-not $reused) {
            try {
                $handle = New-TeamProcess $command.executable @($command.args) $Worktree $out $err -MaxOutputBytes $limit
                $processStarted=$true
                $exitCode = Wait-TeamProcess $handle $command.timeout_seconds $idle
            } catch {
                $errorText=$_.Exception.Message
                if ($_.Exception.Data.Contains('ProcessStarted')) { $processStarted=[bool]$_.Exception.Data['ProcessStarted'] }
                if ($_.Exception.Data.Contains('TimeoutKind')) { $timeoutKind=[string]$_.Exception.Data['TimeoutKind'] }
                $exitCode=if ($_.Exception.Data.Contains('TeamExitCode')) {[int]$_.Exception.Data['TeamExitCode']} else {30}
            } finally { if ($handle -and -not $handle['closed']) { $null=Close-TeamProcess $handle -Terminate } }
            $watch.Stop()
            if ($exitCode -eq 0 -and $Reuse -and $binding -and $binding['key'] -and (Test-Path -LiteralPath $out) -and (Test-Path -LiteralPath $err)) {
                # A successful exit is published only when the source tree, tool identity,
                # declared inputs and environment fingerprint are byte-identical to the
                # binding taken before the command. A command that edits tracked source (or
                # the tool, or a declared input) therefore never becomes a reusable success.
                try {
                    $post = Get-TeamVerificationKey $Worktree $command.executable @($command.args) $command
                    if (-not $post['key']) { $publishRejected = "binding_drift: $($post.reason)" }
                    elseif ($post.key -cne $binding.key) { $publishRejected = 'binding_drift: key_changed' }
                    else { $null=Write-TeamVerificationCache $CacheDirectory $binding $out $err }
                }
                catch { $publishRejected="cache_write_failed: $($_.Exception.Message)" }
            }
        } else { $watch.Stop() }
        $evidence += @{ id=$command.id;executable=$command.executable;args=$command.args;exit_code=$exitCode
            process_started=$processStarted;process_exit_code=$(if ($handle) {$handle.exit_code} else {$null});error=$errorText
            timeout_kind=$timeoutKind;duration_seconds=[Math]::Round($watch.Elapsed.TotalSeconds,3)
            transport_cleanup=(Get-TeamProcessCleanupEvidence $handle)
            cwd=[IO.Path]::GetFullPath($Worktree)
            environment_fingerprint=$(if ($command['environment_fingerprint']) {[string]$command.environment_fingerprint} else {$null})
            input_artifacts=@(@($command['input_artifacts']) | Where-Object { $_ })
            tool_identity=$(if ($binding -and $binding['material']) {$binding.material.tool} else {$null})
            reuse_opted_in=[bool]$Reuse;reused=$reused;reuse_key=$reuseKey;reuse_source=$reuseSource
            reuse_receipt_sha256=$reuseHash;reuse_rejected=$reuseRejected;reuse_publish_rejected=$publishRejected
            stdout_file=[IO.Path]::GetFileName($out);stderr_file=[IO.Path]::GetFileName($err)
            stdout_bytes=$(if (Test-Path -LiteralPath $out -PathType Leaf) {(Get-Item -LiteralPath $out).Length} else {$null})
            stderr_bytes=$(if (Test-Path -LiteralPath $err -PathType Leaf) {(Get-Item -LiteralPath $err).Length} else {$null})
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
    if ($receipt['input_too_large']) {
        $State.agents_reserved-=$item.reserved; $item.reserved=0; $item.status='FAILED'; $State.status='PAUSED'
        Save-TeamState $State $Directory
        Stop-TeamInputCapacity 'DSH input too large; replan/split the task. No launch retry or model charge was recorded'
    }
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
    $null = Invoke-TeamVerification $Task.verification $item.worktree $item.directory 'verification' $runtime -Reuse:([bool]$State['verification_reuse']) -CacheDirectory $Directory
    if ($State['verification_failures']) { $State.verification_failures.Remove($Task.id) }
    # Verification may generate files, but must not change tracked source or HEAD.
    if ((Invoke-TeamGit $item.worktree @('rev-parse','HEAD')) -cne $item.commit -or
        (Invoke-TeamGit $item.worktree @('diff','HEAD','--name-only'))) { Stop-TeamError 82 'Verification modified source' }
    if (-not (Invoke-TeamLocalReview $State $Task $Manifest $Directory)) { return }
    $item['governance_sensitive']=Test-TeamGovernanceChange $item.worktree $item.base_sha $item.commit
    Save-TeamState $State $Directory
    if ($Plan -and ($Plan.classification.level -eq 'critical' -or $item.governance_sensitive)) {
        $null = Invoke-TeamReview $State $Plan $Manifest $Directory '9A' $item.worktree $item.base_sha $item.commit $Task.id
    }
    $item.status = 'REVIEW'; $State.status = 'PAUSED'
    Clear-TeamWorkerFailures $State $Task.id
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
        $item.status = if ($item['cleanup_pending']) { 'LOCAL_REVIEW' }
            elseif ($_.Exception.Data['TeamExitCode'] -eq 82) { 'FAILED_SCOPE' }
            elseif ($item.status -eq 'ESCALATED') { 'ESCALATED' }
            elseif ($item['local_review_pending'] -and $_.Exception.Data['TeamExitCode'] -in @(70,80)) { 'LOCAL_REVIEW' }
            elseif ($_.Exception.Data['TeamExitCode'] -eq 70 -and $State.status -eq 'ESCALATED') { 'REVIEW' }
            else { 'FAILED' }
        if ($_.Exception.Data['TeamExitCode'] -eq 82) { Add-TeamEvent $Directory 'scope_violation' @{task_id=$Task.id;message=$_.Exception.Message} }
        if ($_.Exception.Data['TeamExitCode'] -eq 40) { Record-TeamVerificationFailure $State $Directory $Task.id }
        Record-TeamWorkerFailure $State $Plan $Directory $Task.id ([int]$_.Exception.Data['TeamExitCode']) $_.Exception.Message
        if ($State.status -notin @('ESCALATED','CANCELLED')) { $State.status='PAUSED' }
        Save-TeamState $State $Directory
        throw
    }
}

function Close-TeamDispatchWorkers($State, $Handles, [string]$Directory) {
    foreach ($taskId in @($Handles.Keys)) {
        $item=$State.tasks[$taskId]; $cleanupErrors=@()
        try { Stop-TeamTaskProcesses $item } catch { $cleanupErrors+=$_.Exception.Message }
        try { $null=Close-TeamProcess $Handles[$taskId] -Terminate } catch { $cleanupErrors+=$_.Exception.Message }
        $item['transport_cleanup']=Get-TeamProcessCleanupEvidence $Handles[$taskId]
        $item['cleanup_pending']=$cleanupErrors.Count -gt 0
        if ($item.cleanup_pending) {
            # Preserve both ownership and reservation until an explicit stop can finish cleanup.
            $item.status='RUNNING'
            Add-TeamEvent $Directory 'process_cleanup_failed' @{task_id=$taskId;errors=$cleanupErrors}
        } else {
            $State.agents_created+=$item.reserved; $State.agents_reserved-=$item.reserved; $item.reserved=0
            $item.status='FAILED'
        }
    }
    Save-TeamState $State $Directory
}

function Invoke-TeamDispatch($State, $Plan, $Manifest, [string]$Directory) {
    Assert-TeamActionApproval $State $Plan $Directory
    $handles = @{}
    $deferredFailure=$null
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
                if ($deferredFailure) { break }
                Sync-TeamCost $State $Manifest $Directory
                $task = @($Plan.tasks | Where-Object { $_.id -eq $taskId })[0]
                $item = $State.tasks[$taskId]
                if ($item.status -ne 'READY') { continue }
                if (@($task.dependencies | Where-Object { $State.tasks[$_].status -notin @('MERGED','CLEANED') }).Count) { continue }
                if ($handles.Count -ge $Manifest.budget.max_active_workers) { break }
                $admission=Get-TeamAgentAdmission $State $Plan $Manifest $task
                if (-not $admission.admitted) {
                    if ($task['optional'] -and $task.id -notin @(Get-TeamRequiredTasks $Plan)) {
                        Add-TeamEvent $Directory 'optional_dispatch_skipped' @{task_id=$taskId;reason='preserve required author and reviewer capacity'}
                        continue
                    }
                    Stop-TeamError 70 'Required author/reviewer capacity exhausted; replan before dispatch'
                }
                $slots=$admission.slots
                if (($State.agents_reserved + $slots) -gt $Manifest.budget.max_parallel_agents_total) { continue }
                if ((Get-TeamBudgetSnapshot $State $Manifest).hard_reached) {
                    $State.status = 'PAUSED'; break
                }
                if ((Get-TeamBudgetSnapshot $State $Manifest).soft_reached) {
                    if ($task['optional'] -and $task.id -notin @(Get-TeamRequiredTasks $Plan)) { Add-TeamEvent $Directory 'optional_dispatch_skipped' @{ task_id = $taskId }; continue }
                    if ($handles.Count -gt 0) { break }
                }
                $handles[$taskId] = Start-TeamWorker $State $task $Manifest $Directory $Plan
            }
            foreach ($taskId in @($handles.Keys)) {
                $handle = $handles[$taskId]; $item = $State.tasks[$taskId]
                $logs = @(Get-ChildItem -LiteralPath $item.directory -File | Where-Object { $_.Extension -in @('.stdout','.stderr') })
                $size = ($logs | Measure-Object Length -Sum).Sum
                if ($size -ne $handle.last_size) { $handle.last_activity = [DateTime]::UtcNow; $handle.last_size = $size; $item['last_activity_kind']='output' }
                # Meaningful worktree/HEAD edits refresh the idle deadline; native process
                # churn is reported through the probe but never counted as authored work.
                if ($handle['activity_probe'] -and ($handle.elapsed.ElapsedMilliseconds - $handle['activity_probe_at']) -ge $handle['activity_probe_interval']) {
                    $handle['activity_probe_at'] = $handle.elapsed.ElapsedMilliseconds
                    try {
                        $observed = Get-TeamActivityProbeResult $handle.activity_probe
                        if ($observed -and $observed['active']) {
                            $handle.last_activity = [DateTime]::UtcNow
                            $item['last_activity_kind'] = $observed['kind']; $item['last_activity_at'] = $observed['at']
                        }
                    } catch { $handle['activity_probe_error'] = $_.Exception.Message }
                }
                $timeout = ([DateTime]::UtcNow - $handle.started).TotalSeconds -gt ($Manifest.runtime.timeout_seconds + 10)
                $idle = ([DateTime]::UtcNow - $handle.last_activity).TotalSeconds -gt $Manifest.runtime.idle_timeout_seconds
                $overLog = (Test-TeamProcessOutputLimit $handle) -or @($logs | Where-Object { $_.Length -gt ($Manifest.runtime.max_single_log_mb * 1MB) }).Count -gt 0
                # Synchronous verification/review can delay observing another worker.
                # Its adapter already enforces native deadlines and persists the outcome;
                # elapsed coordinator time must not turn an exited success into a timeout.
                if ((-not $handle.process.HasExited -and ($timeout -or $idle)) -or $overLog) {
                    $timeoutKind = if ($overLog) { 'output' } elseif ($timeout) { 'hard' } else { 'idle' }
                    $null = Close-TeamProcess $handle -Terminate; $handles.Remove($taskId)
                    $State.agents_created += $item.reserved; $State.agents_reserved -= $item.reserved; $item.reserved=0
                    $item.status = 'FAILED'; $item['timeout_kind']=$timeoutKind
                    Add-TeamEvent $Directory 'worker_timeout' @{task_id=$taskId;kind=$timeoutKind;last_activity_kind=$item['last_activity_kind']}
                    Save-TeamState $State $Directory
                    Record-TeamWorkerFailure $State $Plan $Directory $taskId 31 "Worker timeout ($timeoutKind); no blind automatic retry" -InfraKind $timeoutKind
                    Save-TeamState $State $Directory
                    Stop-TeamError 31 "Worker timeout ($timeoutKind); no blind automatic retry"
                }
                if ($handle.process.HasExited) {
                    $null = Close-TeamProcess $handle; $handles.Remove($taskId)
                    $task = @($Plan.tasks | Where-Object { $_.id -eq $taskId })[0]
                    if ($deferredFailure) {
                        # Let already dispatched authors finish under their original
                        # deadlines. Resume will audit their durable results after the
                        # pending decision; no new author or reviewer starts here.
                        $item.status='RESULT_READY'; Save-TeamState $State $Directory
                        Add-TeamEvent $Directory 'worker_result_deferred' @{task_id=$taskId;reason='pending_review_decision'}
                    } else {
                        try { Complete-TeamWorkerSafely $State $task $Directory $Plan $Manifest }
                        catch {
                            if ($_.Exception.Data['TeamExitCode'] -eq 70 -and $item.status -eq 'LOCAL_REVIEW') { $deferredFailure=$_ }
                            else { throw }
                        }
                    }
                }
            }
            if ($handles.Count) { Start-Sleep -Milliseconds 250 }
        } while ($handles.Count)
        if ($deferredFailure) { throw $deferredFailure }
        Sync-TeamCost $State $Manifest $Directory
        if ($State.status -eq 'RUNNING') { $State.status = 'PAUSED' }
        Save-TeamState $State $Directory
        return @{ status = $State.status; run_id = $State.run_id; next = 'Inspect evidence; accept task with a SHA-bound Lead decision, then integrate/resume.' }
    } finally {
        # On coordinator errors, terminate only child processes created by this invocation.
        Close-TeamDispatchWorkers $State $handles $Directory
    }
}
