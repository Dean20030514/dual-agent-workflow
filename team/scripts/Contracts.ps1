function Get-TeamRole([string]$Id, [string]$Directory = '') {
    Assert-TeamId $Id
    $path = if ($Directory) { Join-Path $Directory "roles/$Id.yaml" } else { Join-Path $script:TeamRoot "roles/$Id.yaml" }
    if (-not (Test-Path -LiteralPath $path)) { Stop-TeamError 10 "Unknown role: $Id" }
    $role = Read-TeamData $path
    Test-TeamSchema $role 'role'
    if ($role.role_id -cne $Id) { Stop-TeamError 10 'Role filename and identity differ' }
    return $role
}

function Test-TeamTask($Packet) {
    Test-TeamSchema $Packet 'task'
    # Historical packets contain only the ID. New dispatches always include the frozen definition.
    if ($Packet.role['definition']) {
        Test-TeamSchema $Packet.role.definition 'role'
        if ($Packet.role.definition.role_id -cne $Packet.role.id) { Stop-TeamError 10 'Task role definition identity mismatch' }
    }
}

function Read-TeamWorkerOutput([string]$Path, [ValidateSet('result','review')][string]$Schema = 'result') {
    $raw = [IO.File]::ReadAllText($Path).Trim()
    $candidates = @([regex]::Matches($raw, '(?m)^[\t ]*\{'))
    foreach ($match in $candidates) {
        try { $value = ConvertFrom-Json $raw.Substring($match.Index) -AsHashtable -Depth 100 -ErrorAction Stop }
        catch { continue }
        if ($value -isnot [Collections.IDictionary]) { continue }
        # O2 headless output can prepend a plain final-message sentence. Accept one terminal
        # JSON object only; earlier JSON-looking records make the response ambiguous.
        $prefix = $raw.Substring(0,$match.Index).Trim()
        if ($prefix -match '(?m)^[\t ]*[\{\[]' -or $prefix -match '```') {
            Stop-TeamError 10 'Ambiguous worker stdout contains multiple structured records or a fenced preamble'
        }
        Test-TeamSchema $value $Schema
        return @{packet=$value;format=$(if ($prefix) {'plain-prefix-final-json'} else {'json'});stdout_sha256=(Get-TeamHash $Path)}
    }
    Stop-TeamError 10 'Worker stdout does not end with one valid JSON Result Packet'
}

function Read-TeamPlanInput([string]$Path) {
    try { Read-TeamData $Path }
    catch { $_.Exception.Data['TeamEvent']='plan_invalid'; throw }
}

function Test-TeamPlan($Plan, $Manifest) {
    try { Test-TeamPlanContent $Plan $Manifest }
    catch {
        if ($_.Exception.Data['TeamExitCode'] -eq 10) { $_.Exception.Data['TeamEvent']='plan_invalid' }
        throw
    }
}

function Test-TeamPlanContent($Plan, $Manifest) {
    Test-TeamSchema $Manifest 'manifest'
    Test-TeamSchema $Plan 'team-plan'
    $limits = $Manifest.budget
    if ($limits.max_active_workers -gt $limits.max_parallel_agents_total -or
        $limits.max_parallel_agents_total -gt $limits.max_agents_per_run -or
        $limits.soft_limit -gt $limits.hard_limit) { Stop-TeamError 10 'Invalid resource or cost ordering' }
    if ($Plan.tasks.Count -gt $limits.max_agents_per_run) { Stop-TeamError 10 'Plan exceeds cumulative agent budget' }
    if ($Plan.mode -eq 'L1' -and $Plan.tasks.Count -ne 1) { Stop-TeamError 10 'L1 requires exactly one task' }
    if ($Plan.mode -eq 'L3' -and (-not $Manifest.subagents.enabled -or $limits.max_parallel_agents_total -lt 3)) {
        Stop-TeamError 20 'Native delegation is disabled or cannot reserve three agent slots'
    }
    if ($Plan.classification.level -eq 'critical' -and
        (-not $Plan.review.require_9p -or -not $Plan.review.require_fresh_9b)) {
        Stop-TeamError 10 'Critical requires 9P and fresh 9B'
    }
    $ids = @{}
    foreach ($task in $Plan.tasks) {
        if ($ids.ContainsKey($task.id)) { Stop-TeamError 10 "Duplicate task: $($task.id)" }
        $ids[$task.id] = $task
        $role = Get-TeamRole $task.role
        if ($task.role -eq 'integration' -and ($task.permissions.network -or $task.permissions.secrets -or $task.permissions.production)) {
            Stop-TeamError 10 'Integration role cannot request network, secrets, or production access'
        }
        foreach ($scope in $task.write_scope) {
            if ($scope -match '(^/|\\|:|(^|/)\.\.(/|$)|(^|/)\.git(/|$))' -or $scope -in @('*','**','**/*')) {
                Stop-TeamError 10 "Unsafe or unbounded write scope: $scope"
            }
        }
        if ($task.subagents.allowed -and $Plan.mode -ne 'L3') { Stop-TeamError 10 'Native fan-out requires L3' }
        if ($task.subagents.allowed -and $task.subagents.max_depth -ne 2) { Stop-TeamError 10 'Native fan-out depth must be two' }
    }
    $sorted = [Collections.Generic.List[string]]::new()
    while ($sorted.Count -lt $ids.Count) {
        $progress = $false
        foreach ($task in $Plan.tasks) {
            foreach ($dep in $task.dependencies) { if (-not $ids.ContainsKey($dep)) { Stop-TeamError 10 "Unknown dependency: $dep" } }
            if ($sorted.Contains($task.id)) { continue }
            $missing = @($task.dependencies | Where-Object { -not $sorted.Contains($_) })
            if ($missing.Count -eq 0) { $sorted.Add($task.id); $progress = $true }
        }
        if (-not $progress) { Stop-TeamError 10 'Dependency cycle detected' }
    }
    return $sorted.ToArray()
}

function Get-TeamAffected($Plan, [string]$FailedTask, [string[]]$ChangedPaths) {
    $affected = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $null = $affected.Add($FailedTask)
    foreach ($task in $Plan.tasks) {
        foreach ($path in $ChangedPaths) { if (Test-TeamScope $path $task.write_scope) { $null = $affected.Add($task.id) } }
    }
    do {
        $before = $affected.Count
        foreach ($task in $Plan.tasks) {
            if (@($task.dependencies | Where-Object { $affected.Contains($_) }).Count) { $null = $affected.Add($task.id) }
        }
    } while ($affected.Count -ne $before)
    return @($affected | Sort-Object)
}

function Get-TeamAffectedByScope($Plan, [string]$FailedTask) {
    $root=@($Plan.tasks | Where-Object id -eq $FailedTask)
    if ($root.Count -ne 1) { Stop-TeamError 10 'Unknown failed task' }
    $affected=@(Get-TeamAffected $Plan $FailedTask @($root[0].write_scope))
    foreach ($task in $Plan.tasks) {
        foreach ($scope in $task.write_scope) {
            foreach ($failedScope in $root[0].write_scope) {
                $a=($scope -split '[*?]',2)[0]; $b=($failedScope -split '[*?]',2)[0]
                if ($a.StartsWith($b) -or $b.StartsWith($a)) { $affected+=@(Get-TeamAffected $Plan $task.id @()) }
            }
        }
    }
    return @($affected | Sort-Object -Unique)
}

function Read-WorkerResult($TaskState, $Task, [string]$RunId, [switch]$AllowIncomplete) {
    $result = Read-TeamData (Join-Path $TaskState.directory 'result.yaml')
    Test-TeamSchema $result 'result'
    if ($result.run_id -cne $RunId -or $result.task_id -cne $Task.id) { Stop-TeamError 10 'Result identity mismatch' }
    if (-not $AllowIncomplete -and ($result.status -ne 'completed' -or -not $result.verification.passed)) { Stop-TeamError 30 'Worker did not complete its self-check' }
    $head = Invoke-TeamGit $TaskState.worktree @('rev-parse', 'HEAD')
    $branch = Invoke-TeamGit $TaskState.worktree @('branch', '--show-current')
    if ($result.git.commit -cne $head -or $branch -cne $TaskState.branch -or $result.git.branch -cne $branch) {
        Stop-TeamError 80 'Worker result does not match its assigned Git branch and HEAD'
    }
    $null = Invoke-TeamGit $TaskState.worktree @('merge-base', '--is-ancestor', $TaskState.base_sha, $head)
    $dirty = Invoke-TeamGit $TaskState.worktree @('status', '--porcelain', '--untracked-files=all')
    if ($dirty) { Stop-TeamError 82 'Worker left uncommitted or untracked changes' }
    # Disable rename folding: both sides of a rename must be in scope.
    $raw = Invoke-TeamGit $TaskState.worktree @('-c','core.quotepath=false','diff','--name-only','--no-renames', $TaskState.base_sha, $head)
    $changed = @($raw -split "`n" | Where-Object { $_ })
    foreach ($path in $changed) {
        if (-not (Test-TeamScope $path $Task.write_scope)) { Stop-TeamError 82 "Out-of-scope file: $path" }
        $null = Get-TeamChild $TaskState.worktree $path
    }
    $reported = @($result.changed_files | Sort-Object -Unique)
    if (@(Compare-Object $reported @($changed | Sort-Object -Unique)).Count) { Stop-TeamError 10 'changed_files differs from Git' }
    if ($result.subagents_used.Count -and -not $Task.subagents.allowed) { Stop-TeamError 82 'Unauthorized subagent use' }
    foreach ($child in $result.subagents_used) {
        foreach ($permission in @('shell','network','production','secrets')) {
            if ($child.permissions[$permission] -and -not $Task.permissions[$permission]) { Stop-TeamError 82 'Subagent permission expansion' }
        }
        foreach ($scope in $child.write_scope) {
            if (-not (Test-TeamScopeSubset $scope $Task.write_scope)) { Stop-TeamError 82 'Subagent scope expansion' }
        }
    }
    return @{ result = $result; commit = $head; changed_files = $changed }
}
