# Team-side adapter for the frozen Reuse-first protocol in core/reuse.
# One bounded module: it resolves the protocol from fixed Team-relative locations, loads the
# pure validator once at script scope and maps its errors onto the Team exit-code contract.
# It never copies protocol rules, never resolves the protocol from a caller working directory
# and never launches a process or a search of its own.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# A run-level marker is written by New-TeamRun; runs without it stay readable but are not
# executable. The marker holds the protocol identity plus the copied evidence files.
$script:TeamPriorArtMarker = 'reuse_protocol'
$script:TeamPriorArtEvidenceDirectory = 'reuse-protocol'
$script:TeamPriorArtProtocolRoot = $null
$script:TeamPriorArtLoadError = $null

function Get-TeamPriorArtRoot {
    <#
    .SYNOPSIS
    Fixed candidate locations of the frozen protocol: the repository sibling core/reuse and
    the installed sibling workflow-core/reuse, both relative to the Team installation root.
    #>
    $installRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    return @((Join-Path $installRoot 'core/reuse'), (Join-Path $installRoot 'workflow-core/reuse'))
}

function Resolve-TeamReuseProtocolRoot {
    <#
    .SYNOPSIS
    Returns the first fixed candidate that holds a protocol validator. Caller working
    directories, environment variables and personal absolute paths are never consulted.
    #>
    foreach ($candidate in @(Get-TeamPriorArtRoot)) {
        if (Test-Path -LiteralPath (Join-Path $candidate 'Reuse.ps1') -PathType Leaf) {
            return [IO.Path]::GetFullPath($candidate)
        }
    }
    Stop-TeamError 20 "The frozen reuse protocol is unavailable next to this Team installation; expected Reuse.ps1 under: $((Get-TeamPriorArtRoot) -join ', ')"
}

# Resolution happens at file scope so the protocol functions survive this script. A missing
# installation is deferred to first use: historical run reads, stop and cleanup still work.
try { $script:TeamPriorArtProtocolRoot = Resolve-TeamReuseProtocolRoot }
catch { $script:TeamPriorArtLoadError = $_.Exception.Message }
if ($script:TeamPriorArtProtocolRoot) {
    try { . (Join-Path $script:TeamPriorArtProtocolRoot 'Reuse.ps1') }
    catch { $script:TeamPriorArtLoadError = $_.Exception.Message; $script:TeamPriorArtProtocolRoot = $null }
}

function Assert-TeamPriorArtLoaded {
    <#
    .SYNOPSIS
    Fails closed when the frozen protocol is missing or unreadable, without breaking the
    read-only commands that never call this adapter.
    #>
    if (-not $script:TeamPriorArtProtocolRoot -or $script:TeamPriorArtLoadError) {
        Stop-TeamError 20 "The frozen reuse protocol could not be loaded from $((Get-TeamPriorArtRoot) -join ', '): $($script:TeamPriorArtLoadError)"
    }
    return $script:TeamPriorArtProtocolRoot
}

function Invoke-TeamReuseValidation {
    # Maps a core protocol failure onto the Team contract. Core stays independent of Team
    # exit codes; the adapter is the only translation point. The parameter names are
    # deliberately unusual: an unbound scriptblock resolves names dynamically, so a plain
    # '$Context' here would shadow the caller's variable of the same name.
    param([scriptblock]$TeamReuseValidator, [string]$TeamReuseSubject)
    try { return & $TeamReuseValidator }
    catch {
        $failure = $_.Exception
        if (-not $failure.Data.Contains('ReuseProtocolError')) { throw }
        $kind = [string]$failure.Data['ReuseErrorKind']
        $code = if ($kind -in @('protocol_incomplete', 'load_error')) { 20 } else { 10 }
        Stop-TeamError $code "$TeamReuseSubject was rejected by the frozen reuse protocol: $($failure.Message)"
    }
}

function Assert-TeamReusePlanContent {
    <#
    .SYNOPSIS
    Mechanically requires the plan-level reuse decision and one declaration per task, then
    validates both against the frozen protocol. Historical plans stay readable elsewhere but
    cannot pass plan validation, so legacy execution is rejected clearly instead of silently.
    #>
    param($Plan)
    $null = Assert-TeamPriorArtLoaded
    $decision = $Plan['reuse']
    if ($null -eq $decision) {
        Stop-TeamError 10 'This plan has no top-level reuse decision. The frozen reuse protocol requires a new plan with a plan-level reuse decision and one reuse declaration per task before any execution'
    }
    $normalized = Invoke-TeamReuseValidation { Assert-ReuseDecision $decision } 'plan reuse decision'
    foreach ($task in @($Plan.tasks)) {
        if ($null -eq $task['reuse']) {
            Stop-TeamError 10 "Task '$($task.id)' has no reuse declaration. Every task requires an explicit reuse declaration before any execution"
        }
        $null = Invoke-TeamReuseValidation { Assert-ReuseTask -Decision $normalized -TaskReuse $task['reuse'] } "task '$($task.id)' reuse declaration"
    }
    return $normalized
}

function Get-TeamReuseTaskContext {
    <#
    .SYNOPSIS
    Derives the bounded reuse context handed to one worker: identity, plan hash, task
    applicability and only the candidates the task references. Search logs and decision
    prose are never part of it.
    #>
    param($Plan, $Task, [string]$PlanHash)
    $null = Assert-TeamPriorArtLoaded
    return Invoke-TeamReuseValidation { Get-ReuseContext -Decision $Plan['reuse'] -TaskReuse $Task['reuse'] -PlanHash $PlanHash } "task '$($Task.id)' reuse context"
}

function Assert-TeamReuseResultDocument {
    <#
    .SYNOPSIS
    Rejects a Result reuse declaration that references unknown or out-of-task candidates or
    that silently drops a prescribed reference without a deviation explanation.
    #>
    param($Context, $ResultReuse)
    $null = Assert-TeamPriorArtLoaded
    $null = Invoke-TeamReuseValidation { Assert-ReuseResult -Context $Context -ResultReuse $ResultReuse } 'result reuse declaration'
}

function New-TeamReuseProtocolEvidence {
    <#
    .SYNOPSIS
    Freezes the protocol identity for a new run and copies the three protocol files into the
    run directory as durable evidence. The copy is verified byte for byte.
    #>
    param([string]$Directory)
    $root = Assert-TeamPriorArtLoaded
    $identity = Invoke-TeamReuseValidation { Get-ReuseProtocolIdentity -Root $root } 'protocol identity'
    $target = Get-TeamChild $Directory $script:TeamPriorArtEvidenceDirectory
    [IO.Directory]::CreateDirectory($target) | Out-Null
    foreach ($key in @('readme', 'schema', 'validator')) {
        $entry = $identity.files[$key]
        if (-not $entry -or -not $entry['name'] -or -not $entry['sha256']) { Stop-TeamError 20 "The reuse protocol identity is incomplete: $key" }
        $destination = Get-TeamChild $target ([string]$entry.name)
        [IO.File]::Copy((Join-Path $root ([string]$entry.name)), $destination, $true)
        if ((Get-TeamHash $destination) -cne [string]$entry.sha256) { Stop-TeamError 80 "Frozen reuse protocol evidence differs after copy: $($entry.name)" }
    }
    return @{ version = [int]$identity.version; hash = [string]$identity.hash; files = $identity.files
        directory = (Get-TeamRootRelativePath $Directory $target); frozen_at = [DateTime]::UtcNow.ToString('o') }
}

function Assert-TeamReuseRunProtocol {
    <#
    .SYNOPSIS
    Verifies that this run froze a reuse protocol, that its copied evidence is unchanged and
    that the available protocol still has the frozen identity. Every mutating execution path
    calls this before it can move state.
    #>
    param($State, [string]$Directory)
    if (-not $State[$script:TeamPriorArtMarker]) {
        Stop-TeamError 80 'This run predates the frozen reuse protocol (no run-level reuse_protocol marker). Status, logs, cost, result, escalations, stop and cleanup remain available, but resume, replan, repair-integration, recover, accept and integrate require a new plan and a new run'
    }
    $frozen = $State[$script:TeamPriorArtMarker]
    if ([int]$frozen['version'] -ne 1 -or -not $frozen['hash']) { Stop-TeamError 80 'The frozen reuse protocol identity of this run is malformed' }
    $target = Join-Path $Directory $script:TeamPriorArtEvidenceDirectory
    foreach ($key in @('readme', 'schema', 'validator')) {
        $entry = $frozen.files[$key]
        if (-not $entry -or -not $entry['name'] -or -not $entry['sha256']) { Stop-TeamError 80 "Frozen reuse protocol evidence is incomplete: $key" }
        $path = Join-Path $target ([string]$entry.name)
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { Stop-TeamError 80 "Frozen reuse protocol evidence is missing: $($entry.name)" }
        if ((Get-TeamHash $path) -cne [string]$entry.sha256) { Stop-TeamError 80 "Frozen reuse protocol evidence changed: $($entry.name)" }
    }
    $root = Assert-TeamPriorArtLoaded
    $live = Invoke-TeamReuseValidation { Get-ReuseProtocolIdentity -Root $root } 'protocol identity'
    if ([string]$live.hash -cne [string]$frozen.hash) {
        Stop-TeamError 80 'The available reuse protocol differs from the identity frozen at run start; prior-art conclusions cannot be carried across a changed protocol. Start a new run'
    }
    return $frozen
}

function Get-TeamReuseOwnerException {
    <#
    .SYNOPSIS
    Returns approved owner exceptions for the exact plan hash of this run. A rejected,
    expired, re-bound or missing reason never passes, and an approval is never created here.
    #>
    param($State, [string]$Directory)
    $records = @(Get-ChildItem -LiteralPath (Join-Path $Directory 'escalations') -Filter '*.yaml' -ErrorAction SilentlyContinue |
        ForEach-Object { Read-TeamData $_.FullName })
    $approved = @()
    foreach ($record in $records) {
        if ($record.type -cne 'reuse_unavailable' -or $record.status -cne 'approve') { continue }
        if ([string]$record['plan_hash'] -cne [string]$State.plan_hash) { continue }
        if (-not ([string]$record['reason']).Trim()) { continue }
        if (-not $record['expires_at'] -or [DateTime]$record['expires_at'] -le [DateTime]::UtcNow) { continue }
        # An approval that names a protocol identity is only valid while that identity still
        # matches this run; a malformed record is never read as a valid approval.
        $context = $record['context']
        if ($null -ne $context -and $context -isnot [Collections.IDictionary]) { continue }
        $identity = if ($context) { $context['reuse_identity'] } else { $null }
        if ($identity -and ([string]$identity) -cne ([string]$State[$script:TeamPriorArtMarker].hash)) { continue }
        $approved += $record
    }
    return @($approved)
}

function Suspend-TeamReuseUnavailable {
    <#
    .SYNOPSIS
    Registers the blocked reuse decision with the existing escalation mechanism
    (type reuse_unavailable) exactly once per plan hash. No worktree, worker or
    prerequisite is created by this path.
    #>
    param($State, [string]$Directory, $Decision)
    $unavailable = @($Decision['searches'] | Where-Object { $_.outcome -ceq 'unavailable' } | ForEach-Object { [string]$_.source })
    $pending = @(Get-ChildItem -LiteralPath (Join-Path $Directory 'escalations') -Filter '*.yaml' -ErrorAction SilentlyContinue |
        ForEach-Object { Read-TeamData $_.FullName } |
        Where-Object { $_.type -ceq 'reuse_unavailable' -and $_.status -eq 'pending' -and [string]$_.plan_hash -ceq [string]$State.plan_hash })
    if (-not $pending.Count) {
        New-TeamEscalation $State $Directory 'reuse_unavailable' 'The frozen reuse decision is blocked by an unavailable prior-art search. No author, worktree or prerequisite may start until the owner approves an exception bound to this exact plan hash.' @{
            decision_status = [string]$Decision['status']; unavailable_sources = $unavailable
            reuse_identity = [string]$State[$script:TeamPriorArtMarker].hash }
    }
}

function Assert-TeamReuseAdmission {
    <#
    .SYNOPSIS
    The dispatch gate. It verifies the frozen run protocol, the plan documents and, for a
    blocked decision, an approved owner exception bound to this exact plan hash. It is
    called before a worker worktree or process and before unrelated setup actions.
    #>
    param($State, $Plan, [string]$Directory)
    $frozen = Assert-TeamReuseRunProtocol $State $Directory
    $decision = Assert-TeamReusePlanContent $Plan
    if ([string]$decision['applicability'] -ceq 'skipped' -or [string]$decision['status'] -ceq 'completed') {
        return @{ admitted = $true; exception = $null; decision = $decision; protocol = $frozen }
    }
    $approved = @(Get-TeamReuseOwnerException $State $Directory)
    if ($approved.Count) {
        return @{ admitted = $true; exception = $approved[0]; decision = $decision; protocol = $frozen }
    }
    Suspend-TeamReuseUnavailable $State $Directory $decision
    Stop-TeamError 70 'The frozen reuse decision is blocked by an unavailable prior-art search; dispatch stays paused until the owner approves an exception (escalation reuse_unavailable) for this exact plan hash'
}

function Get-TeamReuseAffected {
    <#
    .SYNOPSIS
    Replan input: tasks whose reuse declaration changed, or every task when the plan-level
    decision changed. Inference and review evidence cannot be carried across either change,
    even when the file scopes are unchanged.
    #>
    param($OldPlan, $NewPlan)
    $changed = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    if ((Get-TeamCanonicalJson $OldPlan['reuse']) -cne (Get-TeamCanonicalJson $NewPlan['reuse'])) {
        foreach ($task in @($NewPlan.tasks)) { $null = $changed.Add([string]$task.id) }
        return @{ decision_changed = $true; tasks = @($changed) }
    }
    foreach ($task in @($OldPlan.tasks)) {
        $next = @($NewPlan.tasks | Where-Object { $_.id -eq $task.id })
        if ($next.Count -ne 1) { continue }
        if ((Get-TeamCanonicalJson $task['reuse']) -cne (Get-TeamCanonicalJson $next[0]['reuse'])) { $null = $changed.Add([string]$task.id) }
    }
    return @{ decision_changed = $false; tasks = @($changed) }
}

function Get-TeamReuseUsageFacts {
    <#
    .SYNOPSIS
    Read-only worker-declared usage from a durable Result. The coordinator never replays a
    search or claims that one happened. A missing, legacy or unreadable Result is normalized
    to declared=false with empty lists, so a projection can never invent usage or index a
    null entry from an absent key.
    #>
    param([string]$ResultPath)
    $undeclared = @{ declared = $false; references_used = @(); deviations = @() }
    if (-not $ResultPath -or -not (Test-Path -LiteralPath $ResultPath -PathType Leaf)) { return $undeclared }
    try {
        $result = Read-TeamData $ResultPath
        if (-not $result['reuse']) { $undeclared['reason'] = 'result has no reuse declaration'; return $undeclared }
        $referencesUsed = $result.reuse['references_used']
        $deviations = $result.reuse['deviations']
        return @{ declared = $true
            references_used = @(if ($null -ne $referencesUsed) { $referencesUsed } else { @() })
            deviations = @(if ($null -ne $deviations) { $deviations } else { @() }) }
    } catch {
        $undeclared['reason'] = "result could not be read: $($_.Exception.Message)"
        return $undeclared
    }
}

function Get-TeamReuseCandidateFacts {
    <#
    .SYNOPSIS
    Bounded source facts for one decision candidate: identity, version, what is borrowed and
    the candidate constraints. The selection rationale, the decision prose and every search
    record stay out of this projection. -SourceOnly narrows it to identity, version and
    constraints, which is all the blind stage may receive: the per-candidate decision is the
    same selection information the plan-level strategy would carry.
    #>
    param($Candidate, [switch]$SourceOnly)
    $facts = @{ id = [string]$Candidate['id']; url = [string]$Candidate['url']
        revision = [string]$Candidate['revision']; constraints = @($Candidate['constraints']) }
    if (-not $SourceOnly) {
        $facts['decision'] = [string]$Candidate['decision']; $facts['borrow'] = [string]$Candidate['borrow']
    }
    return $facts
}

function Get-TeamReuseReviewFacts {
    <#
    .SYNOPSIS
    Bounded decision, declaration and usage material for LOCAL and 9A: the plan-level decision
    fields, the task declaration (including its reason), the source facts of the candidates
    that task references and the worker-declared usage. Search logs, the decision
    reason/rationale and every candidate rationale stay out; the reviewers judge the declared
    constraints and the real usage.
    #>
    param($Plan, $Task, [string]$ResultPath)
    if (-not $Task -or -not $Task['reuse']) { return @{ available = $false; reason = 'task has no reuse declaration' } }
    $decision = $Plan['reuse']
    $decisionFacts = @{ applicability = 'unavailable'; status = 'unavailable'; strategy = 'unavailable'; constraints = @() }
    $candidates = @()
    if ($decision) {
        $decisionFacts = @{ applicability = [string]$decision['applicability']; status = [string]$decision['status']
            strategy = [string]$decision['strategy']; constraints = @($decision['constraints']) }
        $refs = @($Task.reuse['refs'])
        foreach ($candidate in @($decision['candidates'])) {
            if ([string]$candidate['id'] -cnotin $refs) { continue }
            $candidates += Get-TeamReuseCandidateFacts $candidate
        }
    }
    $taskFacts = @{ applicability = [string]$Task.reuse.applicability; reason = [string]$Task.reuse['reason']
        change_kinds = @($Task.reuse.change_kinds); refs = @($Task.reuse['refs']) }
    if ($Task.reuse['skip_reason']) { $taskFacts['skip_reason'] = [string]$Task.reuse.skip_reason }
    return @{ available = $true
        decision = $decisionFacts
        task = $taskFacts
        candidates = @($candidates)
        usage = Get-TeamReuseUsageFacts $ResultPath
        note = 'Declarations and referenced source facts only: the coordinator does not replay searches and claims no telemetry.' }
}

function Get-TeamReuseBlindFacts {
    <#
    .SYNOPSIS
    Blind-stage input for 9B: the frozen decision constraints plus, for every reference the
    worker actually declared as used, that source's identity, version and constraints. The
    plan reason/rationale/strategy, every search record, all candidate rationale, unrelated
    candidates and the free-text deviation reasons are deliberately withheld.
    #>
    param($Plan, $State)
    $decision = $Plan['reuse']
    $constraints = @()
    $candidates = @()
    if ($decision) { $constraints = @($decision['constraints']); $candidates = @($decision['candidates']) }
    $usage = @()
    foreach ($task in @($Plan.tasks)) {
        $item = $null
        if ($State -and $State['tasks'] -and $State.tasks.Contains([string]$task.id)) { $item = $State.tasks[[string]$task.id] }
        $resultPath = if ($item -and $item['directory']) { Join-Path $item.directory 'result.yaml' } else { '' }
        $refs = @()
        if ($task['reuse']) { $refs = @($task['reuse']['refs']) }
        $declared = Get-TeamReuseUsageFacts $resultPath
        $used = @($declared['references_used'])
        $sources = @()
        foreach ($candidate in $candidates) {
            if ([string]$candidate['id'] -cnotin $used) { continue }
            $sources += Get-TeamReuseCandidateFacts $candidate -SourceOnly
        }
        # The deviation reason is free worker prose: the blind stage keeps the fact that a
        # prescribed reference was skipped, never the text that could carry decision rationale.
        # A normalized declaration is always a list, and a null entry carries no reference fact.
        $declaredFacts = @{ declared = [bool]$declared['declared']; references_used = @($used)
            deviations = @(foreach ($deviation in @($declared['deviations'])) { if ($null -ne $deviation) { [string]$deviation['reference'] } }) }
        if ($declared['reason']) { $declaredFacts['reason'] = [string]$declared['reason'] }
        $usage += @{ task_id = [string]$task.id; refs = @($refs); sources = @($sources); usage = $declaredFacts }
    }
    return @{ constraints = @($constraints); usage = @($usage)
        note = 'Decision constraints and the worker-declared actual usage source facts only; the plan decision reason/rationale/strategy, every search record, all candidate rationale and unrelated candidates are withheld from the blind stage.' }
}

function Get-TeamReuseRunSummary {
    <#
    .SYNOPSIS
    Read-only reuse summary for status/cost: frozen protocol identity, decision, exception and
    worker-declared usage. Historical runs without the marker report that fact instead of
    being silently misread, and no search telemetry is invented.
    #>
    param($State, [string]$Directory)
    $summary = @{ status = 'unavailable'; reason = 'this run has no frozen reuse protocol marker'; protocol = $null
        decision = $null; exception = $null; tasks = @()
        notes = @('Reuse fields are worker-declared claims; the coordinator never replays a search or claims that one happened.') }
    if (-not $State[$script:TeamPriorArtMarker]) { return $summary }
    try {
        $summary.protocol = @{ version = [int]$State.reuse_protocol.version; hash = [string]$State.reuse_protocol.hash
            frozen_at = [string]$State.reuse_protocol['frozen_at'];
            evidence_directory = [string]$State.reuse_protocol['directory'] }
        $planPath = Join-Path $Directory 'plan.yaml'
        if (-not (Test-Path -LiteralPath $planPath -PathType Leaf)) { $summary.status = 'unreadable'; $summary.reason = 'the frozen plan is missing'; return $summary }
        $plan = Read-TeamData $planPath
        $decision = $plan['reuse']
        if (-not $decision) { $summary.status = 'unreadable'; $summary.reason = 'the frozen plan has no reuse decision'; return $summary }
        $summary.status = [string]$decision['status']
        $summary['reason'] = $null
        $summary.decision = @{ applicability = [string]$decision['applicability']; status = [string]$decision['status']
            strategy = [string]$decision['strategy']; constraints = @($decision['constraints']) }
        $approved = @(Get-TeamReuseOwnerException $State $Directory)
        if ($approved.Count) {
            $summary['exception'] = @{ escalation = [string]$approved[0].id; plan_hash = [string]$approved[0].plan_hash
                expires_at = [string]$approved[0].expires_at; reason = [string]$approved[0]['reason'] }
        }
        $tasks = @()
        foreach ($task in @($plan.tasks)) {
            if (-not $task['reuse']) { continue }
            $entry = @{ task_id = [string]$task.id; applicability = [string]$task.reuse.applicability
                change_kinds = @($task.reuse.change_kinds); refs = @($task.reuse.refs) }
            if ($task.reuse['skip_reason']) { $entry['skip_reason'] = [string]$task.reuse.skip_reason }
            $item = $null
            if ($State['tasks'] -and $State.tasks.Contains([string]$task.id)) { $item = $State.tasks[[string]$task.id] }
            $entry['usage'] = Get-TeamReuseUsageFacts $(if ($item -and $item['directory']) { Join-Path $item.directory 'result.yaml' } else { '' })
            $tasks += $entry
        }
        $summary.tasks = @($tasks)
    } catch { $summary.status = 'unreadable'; $summary['reason'] = $_.Exception.Message; $summary.tasks = @() }
    return $summary
}
