# Read-only accounting and status summary. Nothing here mutates state: a read must never
# rewrite a historical run, and unknown usage stays unknown instead of being reported as zero.
Set-StrictMode -Version Latest

function Get-TeamVerificationUsage([string]$Directory) {
    $usage = @{ executed = 0; reused = 0; cache_rejected = 0; opted_in = 0; commands = 0; evidence_files = 0 }
    $patterns = @(
        'tasks/*/attempt-*/verification-evidence.json',
        'final-evidence/*/final-evidence.json',
        'integration-evidence/*/*/verification-evidence.json',
        'reviews/evidence/*/verification-evidence.json'
    )
    foreach ($pattern in $patterns) {
        foreach ($file in @(Get-ChildItem -Path (Join-Path $Directory $pattern) -File -ErrorAction SilentlyContinue)) {
            $usage.evidence_files++
            foreach ($entry in @(Read-TeamData $file.FullName)) {
                $usage.commands++
                if ($entry['reused']) { $usage.reused++ } else { $usage.executed++ }
                if ($entry['reuse_opted_in']) { $usage.opted_in++ }
                if ($entry['reuse_rejected']) { $usage.cache_rejected++ }
            }
        }
    }
    return $usage
}

function Get-TeamAuthorReceipts([string]$Directory) {
    # Observed author identities come from the native creation receipts on disk, so a
    # retired, replanned or renamed attempt is still counted once. Nothing here is derived
    # from a dispatch intent or from a model self-report.
    $receipts = @()
    $root = Join-Path $Directory 'tasks'
    foreach ($taskDirectory in @(Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue)) {
        foreach ($attempt in @(Get-ChildItem -LiteralPath $taskDirectory.FullName -Directory -Filter 'attempt-*' -ErrorAction SilentlyContinue)) {
            $receiptPath = Join-Path $attempt.FullName 'agents.json'
            if (-not (Test-Path -LiteralPath $receiptPath -PathType Leaf)) { continue }
            try { $agents = @(Get-TeamOptionalList (Read-TeamData $receiptPath)['agents']) } catch { continue }
            $receipts += @{ task_id = $taskDirectory.Name; attempt = $attempt.Name; path = $receiptPath
                agents = $agents.Count; children = @($agents | Where-Object { [int]$_['depth'] -gt 0 }).Count
                read_only = [bool](@($agents | Where-Object { $_['read_only'] -eq $true }).Count) }
        }
    }
    return @($receipts)
}

function Get-TeamReviewerReceipts($State) {
    # A local review record exists from PREPARING onward; only a durable native creation
    # receipt proves a reviewer actually started.
    $records = @($State.tasks.Values)
    if ($State['discarded_tasks']) { $records += @($State.discarded_tasks.Values) }
    $receipts = @(); $seen = @{}
    foreach ($item in $records) {
        $review = $item['local_review']
        if (-not $review -or -not $review['directory']) { continue }
        $directory = [string]$review['directory']
        if ($seen.ContainsKey($directory)) { continue }
        $seen[$directory] = $true
        $receiptPath = Join-Path $directory 'agents.json'
        $started = ((Test-Path -LiteralPath $receiptPath -PathType Leaf) -and ([string]$review['status']) -ne 'PREPARING')
        $agents = 0
        if ($started) {
            try { $agents = @(Get-TeamOptionalList (Read-TeamData $receiptPath)['agents']).Count } catch { $started = $false }
        }
        $receipts += @{ directory = $directory; status = [string]$review['status']; started = $started
            reserved = [int]$review['reserved']; agents = $agents }
    }
    return @($receipts)
}

function Get-TeamRunSummary($State, [string]$Directory) {
    $intents = 0; $reservations = 0; $pendingLocal = 0
    foreach ($id in $State.tasks.Keys) {
        $item = $State.tasks[$id]
        $intents += [int]$item['attempts']
        $reservations += [int]$item['reserved']
        if ($item['local_review'] -and $item.local_review['reserved']) { $pendingLocal++ }
    }
    $authorReceipts = @(Get-TeamAuthorReceipts $Directory)
    $reviewerReceipts = @(Get-TeamReviewerReceipts $State)
    $reviewerStarted = @($reviewerReceipts | Where-Object { $_.started })
    $authorAgents = 0; $authorChildren = 0
    foreach ($receipt in $authorReceipts) { $authorAgents += [int]$receipt.agents; $authorChildren += [int]$receipt.children }
    $reviewerAgents = 0
    foreach ($receipt in $reviewerStarted) { $reviewerAgents += [int]$receipt.agents }
    $discarded = 0
    if ($State['discarded_tasks']) { $discarded = @($State.discarded_tasks.Keys).Count }
    $stages = @{ '9P' = 0; '9A' = 0; '9B' = 0; 'LOCAL' = 0 }
    foreach ($file in @(Get-ChildItem -LiteralPath (Join-Path $Directory 'reviews') -Filter '*.json' -File -ErrorAction SilentlyContinue |
        Where-Object { $_.BaseName -notmatch 'disposition' })) {
        $stage = ($file.BaseName -split '-')[0]
        if ($stages.ContainsKey($stage)) { $stages[$stage]++ }
    }
    $infrastructure = 0; $semantic = 0; $recoverable = 0; $nonRecoverable = 0; $reasons = @{}
    if ($State['worker_failures']) {
        foreach ($record in $State.worker_failures.Values) {
            # Infrastructure-class attempts are every non-semantic termination. Only
            # transport/start/idle have a bounded automatic recovery path; a hard total
            # timeout or an output overflow stays an infrastructure attempt that needs an
            # owner decision, so the two sets are reported separately instead of merged.
            if ($record['infra_kind'] -in @('idle', 'start', 'transport')) { $infrastructure++; $recoverable++ }
            elseif ($record['infra_kind'] -in @('hard', 'output')) { $infrastructure++; $nonRecoverable++ }
            else { $semantic++ }
            $key = [string]$record['kind']
            $reasons[$key] = 1 + [int]$reasons[$key]
        }
    }
    $verificationFailures = 0
    if ($State['verification_failures']) { $verificationFailures = @($State.verification_failures.Keys).Count }
    return @{
        # Dispatch intent is what the coordinator asked for; observed counts are what the
        # native creation receipts prove. They are reported separately and never merged.
        authors_dispatched_intents = $intents
        authors_observed = $authorReceipts.Count
        author_agents_observed = $authorAgents
        author_children_observed = $authorChildren
        local_reviewers_started = $reviewerStarted.Count
        local_reviewers_preparing = @($reviewerReceipts | Where-Object { -not $_.started }).Count
        reviewer_agents_observed = $reviewerAgents
        discarded_attempts = $discarded
        review_stages = $stages
        reservations_pending = $reservations + $pendingLocal
        agents_created = [int]$State.agents_created
        agents_reserved = [int]$State.agents_reserved
        attempts = @{ infrastructure = $infrastructure; semantic = $semantic
            infrastructure_recoverable = $recoverable; infrastructure_nonrecoverable = $nonRecoverable
            semantic_replans = [int]$State.replans; infrastructure_recovery = [int]$State['infra_retries']
            repeated_verification_failures = $verificationFailures; reasons = $reasons }
        verification = Get-TeamVerificationUsage $Directory
        prerequisites = Get-TeamPrerequisiteSummary $Directory
        # Read-only reuse summary: frozen protocol identity, decision, owner exception and the
        # usage each Result declared. Declarations are never replayed or upgraded to telemetry.
        reuse = Get-TeamReuseRunSummary $State $Directory
        known_usage = @{ ledgers = $State['cost_ledgers']; unknown_usage = [bool]$State.unknown_usage
            note = 'Known cost is the sum of separately recorded bills. Unrecorded provider spend is not claimed to be zero.' }
        notes = @(
            'Counts are derived from durable run evidence, never from model self-report.'
            'A reused verification command is reported separately from a real execution and is not claimed as a speedup.'
            'Infrastructure retries are counted apart from semantic replans; neither bypasses its own cap.'
            'attempts.infrastructure counts every infrastructure-class attempt; only transport/start/idle are recoverable and hard timeouts or output overflows stay owner decisions.'
            'A local reviewer recorded as PREPARING is reported as not started.'
            'Reuse reporting is declaration-only: it never claims that a search happened or was reproduced, and a historical run without the frozen protocol marker reports that fact instead.'
        )
    }
}
