function Get-TeamRole([string]$Id, [string]$Directory = '', $Plan = $null) {
    Assert-TeamId $Id
    $path = if ($Directory) { Join-Path $Directory "roles/$Id.yaml" } else { Join-Path $script:TeamRoot "roles/$Id.yaml" }
    $dynamic = if ($Plan -and $Plan['dynamic_roles'] -and $Plan.dynamic_roles.Contains($Id)) { $Plan.dynamic_roles[$Id] } else { $null }
    if ($Directory -and (Test-Path -LiteralPath $path)) {
        $role = Read-TeamData $path
        if ($dynamic -and (Get-TeamCanonicalJson $role) -cne (Get-TeamCanonicalJson $dynamic)) {
            Stop-TeamError 80 "Frozen dynamic role differs from the plan: $Id"
        }
    } elseif ($dynamic) { $role = $dynamic }
    elseif (Test-Path -LiteralPath $path) { $role = Read-TeamData $path }
    else { Stop-TeamError 10 "Unknown role: $Id" }
    Test-TeamSchema $role 'role'
    if ($role.role_id -cne $Id) { Stop-TeamError 10 'Role filename and identity differ' }
    return $role
}

function Test-TeamTask($Packet) {
    Test-TeamSchema $Packet 'task'
    if ($Packet['result_schema_sha256'] -and $Packet.result_schema -cne 'result-v1') { Stop-TeamError 10 'A hashed Result schema must use its logical result-v1 identity' }
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

function Get-TeamRequiredTasks($Plan) {
    $required=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($task in $Plan.tasks) { if (-not $task['optional']) { $null=$required.Add($task.id) } }
    do {
        $before=$required.Count
        foreach ($task in $Plan.tasks) {
            if ($required.Contains($task.id)) { foreach ($dep in $task.dependencies) { $null=$required.Add($dep) } }
        }
    } while ($required.Count -ne $before)
    return @($required)
}

function Get-TeamAgentAdmission($State, $Plan, $Manifest, $Task) {
    $required=@(Get-TeamRequiredTasks $Plan)
    $remaining=0
    foreach ($entry in $Plan.tasks) {
        $item=$State.tasks[$entry.id]
        if ($item.status -in @('REVIEW','ACCEPTED','MERGED','CLEANED')) { continue }
        if ($item.status -in @('RUNNING','SELF_CHECK','RESULT_READY','VERIFYING')) { $remaining++; continue }
        if ($item.status -eq 'LOCAL_REVIEW') {
            if (-not $item['local_review'] -or (-not $item.local_review['reserved'] -and $item.local_review['status'] -ne 'EXITED')) { $remaining++ }
            continue
        }
        if ($entry.id -in $required -or $entry.id -eq $Task.id) { $remaining+=2 }
    }
    $minimum=[int]$State.agents_created+[int]$State.agents_reserved+$remaining
    $admitted=$minimum -le $Manifest.budget.max_agents_per_run
    $children=$admitted -and $Task.subagents.allowed -and
        -not (Get-TeamBudgetSnapshot $State $Manifest).soft_reached -and
        ($minimum+2) -le $Manifest.budget.max_agents_per_run
    return @{admitted=$admitted;minimum_required=$minimum;allow_children=$children;slots=$(if ($children) {3} else {1})}
}

function Test-TeamPlanContent($Plan, $Manifest) {
    Test-TeamSchema $Manifest 'manifest'
    Test-TeamSchema $Plan 'team-plan'
    if ($Plan['dynamic_roles']) {
        if (-not $Manifest.team.dynamic_roles) { Stop-TeamError 10 'Dynamic role definitions are disabled by the manifest' }
        foreach ($id in $Plan.dynamic_roles.Keys) {
            Assert-TeamId $id
            if (Test-Path -LiteralPath (Join-Path $script:TeamRoot "roles/$id.yaml")) {
                Stop-TeamError 10 "Dynamic role cannot shadow a built-in role: $id"
            }
            $null = Get-TeamRole $id -Plan $Plan
        }
    }
    $limits = $Manifest.budget
    if ($limits.max_active_workers -gt $limits.max_parallel_agents_total -or
        $limits.max_parallel_agents_total -gt $limits.max_agents_per_run) { Stop-TeamError 10 'Invalid resource ordering' }
    foreach ($ledger in $limits.ledgers.Values) {
        if ($ledger.soft_limit -gt $ledger.hard_limit) { Stop-TeamError 10 'Invalid cost ordering' }
    }
    if ((@(Get-TeamRequiredTasks $Plan).Count*2) -gt $limits.max_agents_per_run) {
        Stop-TeamError 10 'Required tasks and their mandatory local reviewers exceed the cumulative agent budget'
    }
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
        $role = Get-TeamRole $task.role -Plan $Plan
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
    if (-not $ChangedPaths) { return @(Get-TeamAffectedByScope $Plan $FailedTask) }
    if (@($Plan.tasks | Where-Object id -eq $FailedTask).Count -ne 1) { Stop-TeamError 10 'Unknown failed task' }
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
    $affected=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $null=$affected.Add($FailedTask)
    do {
        $before=$affected.Count
        $invalidated=@($Plan.tasks | Where-Object { $affected.Contains($_.id) } | ForEach-Object { $_.write_scope })
        foreach ($task in $Plan.tasks) {
            if ($affected.Contains($task.id)) { continue }
            if (@($task.dependencies | Where-Object { $affected.Contains($_) }).Count) { $null=$affected.Add($task.id); continue }
            foreach ($scope in $task.write_scope) {
                foreach ($other in $invalidated) {
                    if (Test-TeamScopeOverlap $scope $other) { $null=$affected.Add($task.id); break }
                }
            }
        }
    } while ($before -ne $affected.Count)
    return @($affected | Sort-Object)
}

function Test-TeamScopeOverlap([string]$Left, [string]$Right) {
    # Intersect the two glob automata. This uses exactly Test-TeamScope semantics:
    # ** consumes any characters; * and ? cannot consume a path separator.
    $a=@([regex]::Matches($Left,'\*\*|\*|\?|[^*?]') | ForEach-Object Value)
    $b=@([regex]::Matches($Right,'\*\*|\*|\?|[^*?]') | ForEach-Object Value)
    $queue=[Collections.Generic.Queue[object]]::new(); $queue.Enqueue(@(0,0))
    $seen=[Collections.Generic.HashSet[string]]::new()
    while ($queue.Count) {
        $pair=$queue.Dequeue(); $i=[int]$pair[0]; $j=[int]$pair[1]
        if (-not $seen.Add("$i,$j")) { continue }
        if ($i -eq $a.Count -and $j -eq $b.Count) { return $true }
        $x=if ($i -lt $a.Count) {$a[$i]} else {$null}
        $y=if ($j -lt $b.Count) {$b[$j]} else {$null}
        if ($x -in @('*','**')) { $queue.Enqueue(@(($i+1),$j)) }
        if ($y -in @('*','**')) { $queue.Enqueue(@($i,($j+1))) }
        if ($null -eq $x -or $null -eq $y) { continue }
        $xWild=$x -in @('*','**','?'); $yWild=$y -in @('*','**','?')
        $compatible=if ($xWild -and $yWild) {$true}
            elseif ($xWild) {$x -eq '**' -or $y -cne '/'}
            elseif ($yWild) {$y -eq '**' -or $x -cne '/'}
            else {$x -ceq $y}
        if ($compatible) {
            $ni=if ($x -in @('*','**')) {$i} else {$i+1}
            $nj=if ($y -in @('*','**')) {$j} else {$j+1}
            $queue.Enqueue(@($ni,$nj))
        }
    }
    return $false
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
