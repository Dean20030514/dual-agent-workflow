# Plan-declared pre-dispatch prerequisites. The runner never assumes a database,
# service or fixture exists, and never restarts a service: the plan declares the exact
# commands (and their optional restore) and the coordinator preserves their evidence.
Set-StrictMode -Version Latest

function Invoke-TeamDeclaredCommand($Command, [string]$WorkRoot, [string]$EvidenceDirectory, [string]$Prefix, $Runtime) {
    [IO.Directory]::CreateDirectory($EvidenceDirectory) | Out-Null
    $out = Join-Path $EvidenceDirectory "$Prefix.stdout"
    $err = Join-Path $EvidenceDirectory "$Prefix.stderr"
    $limit = if ($Runtime) { [long]$Runtime.max_single_log_mb * 1MB } else { 50MB }
    $idle = if ($Runtime) { [int]$Runtime.idle_timeout_seconds } else { 900 }
    $handle = $null; $errorText = $null; $processStarted = $false; $timeoutKind = $null
    try {
        $handle = New-TeamProcess $Command.executable @($Command.args) $WorkRoot $out $err -MaxOutputBytes $limit
        $processStarted = $true
        $exitCode = Wait-TeamProcess $handle $Command.timeout_seconds $idle
    } catch {
        $errorText = $_.Exception.Message
        if ($_.Exception.Data.Contains('ProcessStarted')) { $processStarted = [bool]$_.Exception.Data['ProcessStarted'] }
        if ($_.Exception.Data.Contains('TimeoutKind')) { $timeoutKind = [string]$_.Exception.Data['TimeoutKind'] }
        $exitCode = if ($_.Exception.Data.Contains('TeamExitCode')) { [int]$_.Exception.Data['TeamExitCode'] } else { 30 }
    } finally { if ($handle -and -not $handle['closed']) { $null = Close-TeamProcess $handle -Terminate } }
    $evidence = @{ id = $Prefix; executable = $Command.executable; args = @($Command.args); exit_code = $exitCode
        process_started = $processStarted; process_exit_code = $(if ($handle) { $handle.exit_code } else { $null })
        timeout_kind = $timeoutKind; error = $errorText; cwd = [IO.Path]::GetFullPath($WorkRoot)
        transport_cleanup = (Get-TeamProcessCleanupEvidence $handle)
        stdout_file = "$Prefix.stdout"; stderr_file = "$Prefix.stderr"
        stdout_bytes = $(if (Test-Path -LiteralPath $out -PathType Leaf) { (Get-Item -LiteralPath $out).Length } else { $null })
        stderr_bytes = $(if (Test-Path -LiteralPath $err -PathType Leaf) { (Get-Item -LiteralPath $err).Length } else { $null })
        stdout_sha256 = $(if (Test-Path -LiteralPath $out -PathType Leaf) { Get-TeamHash $out } else { $null })
        stderr_sha256 = $(if (Test-Path -LiteralPath $err -PathType Leaf) { Get-TeamHash $err } else { $null }) }
    Write-TeamData (Join-Path $EvidenceDirectory "$Prefix-evidence.json") $evidence
    return $evidence
}

function Read-TeamPrerequisiteState([string]$Directory) {
    $path = Join-Path $Directory 'prerequisites.json'
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    return Read-TeamData $path
}

function Test-TeamPrerequisitesSatisfied([string]$Directory, [string]$PlanHash) {
    $state = Read-TeamPrerequisiteState $Directory
    if (-not $state) { return $false }
    return ($state.status -eq 'PASSED' -and $state['plan_hash'] -ceq $PlanHash)
}

function Get-TeamPlanPrerequisites($Plan) {
    # Plans written before this capability have no `prerequisites` key; that must read
    # as an empty list, never as a one-element list holding $null.
    return @(Get-TeamOptionalList $Plan['prerequisites'])
}

function Invoke-TeamPrerequisites($State, $Plan, $Manifest, [string]$Directory, [switch]$Restore, [string]$Reason = '') {
    $declared = @(Get-TeamPlanPrerequisites $Plan)
    $revision = [int]$Plan.run.revision
    $root = Get-TeamChild $Directory "prerequisites/rev$revision"
    $runtime = $Manifest.runtime
    if ($Restore) {
        if (-not $Reason) { Stop-TeamError 10 'Explicit prerequisite restore requires a -Reason' }
        $restored = @()
        foreach ($item in $declared) {
            $command = $item['restore']
            if (-not $command) { continue }
            $evidenceDirectory = Get-TeamChild $root ("restore-$($item.id)-" + [guid]::NewGuid().ToString('N'))
            $entry = Invoke-TeamDeclaredCommand $command $State.repo $evidenceDirectory "restore-$($item.id)" $runtime
            $restored += @{ id = $item.id; exit_code = $entry.exit_code; directory = (Get-TeamRootRelativePath $Directory $evidenceDirectory) }
            if ($entry.exit_code -ne 0) { Stop-TeamError 40 "Prerequisite restore failed for '$($item.id)'; earlier failure evidence was preserved" }
        }
        Add-TeamEvent $Directory 'prerequisite_restore' @{ reason = $Reason; restored = $restored; revision = $revision }
        return @{ status = 'RESTORED'; restored = $restored; revision = $revision }
    }
    if (-not $declared.Count) {
        Write-TeamData (Join-Path $Directory 'prerequisites.json') @{ status = 'NOT_DECLARED'; plan_hash = $State.plan_hash
            revision = $revision; attempts = @(); timestamp = [DateTime]::UtcNow.ToString('o') }
        return @{ status = 'NOT_DECLARED'; declared = 0 }
    }
    if (Test-TeamPrerequisitesSatisfied $Directory $State.plan_hash) {
        return @{ status = 'PASSED'; declared = $declared.Count; reused = $true }
    }
    $previous = Read-TeamPrerequisiteState $Directory
    $attempts = @()
    if ($previous -and $previous['attempts']) { $attempts = @($previous.attempts) }
    foreach ($item in $declared) {
        Assert-TeamId $item.id
        $evidenceDirectory = Get-TeamChild $root ("$($item.id)-" + [guid]::NewGuid().ToString('N'))
        $entry = Invoke-TeamDeclaredCommand $item $State.repo $evidenceDirectory $item.id $runtime
        $restoreResult = $null
        if ($entry.exit_code -ne 0 -and $item['restore']) {
            # Undo a partially applied fixture before reporting, and keep both receipts.
            $restoreDirectory = Get-TeamChild $root ("$($item.id)-restore-" + [guid]::NewGuid().ToString('N'))
            $restoreResult = Invoke-TeamDeclaredCommand $item.restore $State.repo $restoreDirectory "$($item.id)-restore" $runtime
        }
        $attempts += @{ id = $item.id; status = $(if ($entry.exit_code -eq 0) { 'PASSED' } else { 'FAILED' })
            exit_code = $entry.exit_code; directory = (Get-TeamRootRelativePath $Directory $evidenceDirectory)
            timeout_kind = $entry.timeout_kind; restore_exit_code = $(if ($restoreResult) { $restoreResult.exit_code } else { $null })
            restore_directory = $(if ($restoreResult) { Get-TeamRootRelativePath $Directory $restoreDirectory } else { $null })
            timestamp = [DateTime]::UtcNow.ToString('o') }
        if ($entry.exit_code -ne 0) {
            Write-TeamData (Join-Path $Directory 'prerequisites.json') @{ status = 'FAILED'; plan_hash = $State.plan_hash
                revision = $revision; failed_id = $item.id; attempts = $attempts; reason = 'prerequisite command failed'
                stdout_sha256 = $entry.stdout_sha256; stderr_sha256 = $entry.stderr_sha256
                timestamp = [DateTime]::UtcNow.ToString('o') }
            Add-TeamEvent $Directory 'prerequisite_failed' @{ id = $item.id; exit_code = $entry.exit_code; directory = $attempts[-1].directory }
            $restoreHint = if ($item['restore']) { " A declared restore command was executed; inspect '$($attempts[-1].restore_directory)'." } else { '' }
            Stop-TeamError 40 "Prerequisite '$($item.id)' failed (exit $($entry.exit_code)) before any worker or worktree was admitted. Evidence: $($attempts[-1].directory).$restoreHint Re-run after correcting the environment; earlier failure evidence is preserved."
        }
    }
    Write-TeamData (Join-Path $Directory 'prerequisites.json') @{ status = 'PASSED'; plan_hash = $State.plan_hash
        revision = $revision; attempts = $attempts; timestamp = [DateTime]::UtcNow.ToString('o') }
    Add-TeamEvent $Directory 'prerequisites_passed' @{ declared = $declared.Count; revision = $revision }
    return @{ status = 'PASSED'; declared = $declared.Count; attempts = $attempts }
}

function Get-TeamPrerequisiteSummary([string]$Directory) {
    $state = Read-TeamPrerequisiteState $Directory
    if (-not $state) { return @{ status = 'NOT_RUN'; declared = 0; attempts = @() } }
    return @{ status = $state.status; plan_hash = $state['plan_hash']; failed_id = $state['failed_id']
        declared = $(if ($state['status'] -eq 'NOT_DECLARED') { 0 } else { @(Get-TeamOptionalList $state['attempts']).Count })
        attempts = @(Get-TeamOptionalList $state['attempts']); timestamp = $state['timestamp'] }
}

function Get-TeamPlanPreview($Plan, $Manifest, [string]$Repo) {
    $order = @(Test-TeamPlan $Plan $Manifest)
    $tasks = @()
    $tree = $null
    if ($Repo -and (Test-Path -LiteralPath (Get-TeamChild $Repo '.git'))) {
        $tree = @((Invoke-TeamGit $Repo @('-c', 'core.quotePath=false', 'ls-tree', '-r', '--name-only', 'HEAD')) -split "`n" | Where-Object { $_ })
    }
    foreach ($task in $Plan.tasks) {
        $scopeFiles = if ($null -ne $tree) {
            $scopes = @($task.write_scope)
            @($tree | Where-Object { $candidate = $_; [bool]@($scopes | Where-Object { Test-TeamScope $candidate @($_) }).Count }).Count
        } else { $null }
        $fixedText = (@($task.objective) -join "`n") + (@($task.acceptance) -join "`n") +
            (@($task.verification) | ConvertTo-Json -Depth 20) + (@(Get-TeamOptionalList $task['issue_acceptance_map']) | ConvertTo-Json -Depth 20)
        $fixedBytes = [Text.Encoding]::UTF8.GetByteCount($fixedText)
        $tasks += @{ id = $task.id; role = $task.role; write_scope = @($task.write_scope)
            scope_files_at_head = $scopeFiles; acceptance_count = @($task.acceptance).Count
            objective_count = @($task.objective).Count; verification_commands = @($task.verification).Count
            fixed_review_input_bytes_floor = $fixedBytes }
    }
    $required = @(Get-TeamRequiredTasks $Plan)
    return @{
        run_id = $Plan.run.id; revision = [int]$Plan.run.revision; mode = $Plan.mode; order = $order
        declared_prerequisites = @(foreach ($item in @(Get-TeamPlanPrerequisites $Plan)) { [string]$item['id'] })
        required_tasks = $required.Count
        minimum_author_reviewer_agents = $required.Count * 2
        budget_max_agents_per_run = [int]$Manifest.budget.max_agents_per_run
        fits_agent_budget = (($required.Count * 2) -le [int]$Manifest.budget.max_agents_per_run)
        tasks = $tasks
        limits = @{ max_diff_bytes = $(if ($Manifest.runtime['max_diff_bytes']) { [long]$Manifest.runtime.max_diff_bytes } else { 2000000 })
            max_review_input_bytes = $(if ($Manifest.runtime['max_review_input_bytes']) { [long]$Manifest.runtime.max_review_input_bytes } else { 4000000 }) }
        notes = @(
            'Read-only estimate from source facts at HEAD; it is a lower bound, not the reviewed input.',
            'The reviewed diff is generated complete at review time and is never truncated or exempted.',
            'Scope file counts are not proof of independence: shared invariants belong in objective/acceptance.'
        )
    }
}
