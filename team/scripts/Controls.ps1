# The coordinator alone writes state. Concurrent cost reporters append immutable receipts.
function Record-TeamWorkerFailure($State, $Plan, [string]$Directory, [string]$TaskId, [int]$Code, [string]$Message) {
    $kind=switch ($Code) {82 {'scope_violation'};31 {'worker_timeout'};10 {'invalid_result'};50 {'review_failure'};80 {'missing_worker_evidence'};default {return}}
    $item=$State.tasks[$TaskId]
    if (-not $State['worker_failures']) { $State['worker_failures']=@{} }
    $key="$TaskId/$kind"; $previous=$State.worker_failures[$key]
    if ($previous -and $previous.attempt -eq $item.attempts) { return }
    $count=1; if ($previous) { $count=[int]$previous.count+1 }
    $record=@{task_id=$TaskId;kind=$kind;attempt=$item.attempts;count=$count;exit_code=$Code;message=$Message;directory=$item.directory}
    $State.worker_failures[$key]=$record
    Add-TeamEvent $Directory 'worker_failure_recorded' $record
    if ($count -ge 2 -or ($Code -eq 82 -and $Plan.classification.level -eq 'critical')) {
        New-TeamEscalation $State $Directory $kind 'Worker failure requires an owner decision before another attempt; original result, Git state and logs remain preserved.' $record
    }
}

function Clear-TeamWorkerFailures($State, [string]$TaskId) {
    if ($State['worker_failures']) {
        foreach ($key in @($State.worker_failures.Keys)) { if ($key.StartsWith("$TaskId/",[StringComparison]::Ordinal)) { $State.worker_failures.Remove($key) } }
    }
}

function Record-TeamVerificationFailure($State, [string]$Directory, [string]$TaskId) {
    $item=$State.tasks[$TaskId]
    $path=Join-Path $item.directory 'verification-evidence.json'
    if (-not (Test-Path -LiteralPath $path)) { return }
    $failed=@(Read-TeamData $path | Where-Object { $_.exit_code -ne 0 })
    if (-not $failed.Count) { return }
    $entry=$failed[-1]
    $signature=@($entry.id,$entry.executable,($entry.args | ConvertTo-Json -Compress),$entry.exit_code,$entry.stdout_sha256,$entry.stderr_sha256) -join "`n"
    $fingerprint=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($signature))).ToLowerInvariant()
    if (-not $State['verification_failures']) { $State['verification_failures']=@{} }
    $previous=$State.verification_failures[$TaskId]
    $count=1
    if ($previous -and $previous.fingerprint -ceq $fingerprint) {
        if ($previous.attempt -eq $item.attempts) { return }
        $count=[int]$previous.count
        $count++
    }
    $State.verification_failures[$TaskId]=@{fingerprint=$fingerprint;count=$count;attempt=$item.attempts}
    Add-TeamEvent $Directory 'verification_failed' @{task_id=$TaskId;command=$entry.id;fingerprint=$fingerprint;consecutive_attempts=$count}
    if ($count -ge 2) {
        New-TeamEscalation $State $Directory 'repeated_verification_failure' 'Two worker attempts failed the same verification command with identical output; inspect the preserved evidence before another attempt.' @{task_id=$TaskId;fingerprint=$fingerprint;attempt=$item.attempts}
    }
}
function Get-TeamBudgetSnapshot($State, $Manifest) {
    if (-not $Manifest.budget['ledgers']) { Stop-TeamError 20 'Budget has no named units; explicitly migrate the manifest before dispatch or cost reporting' }
    if ($State['known_cost'] -gt 0) { Stop-TeamError 80 'Legacy untyped cost is retained; explicitly reconcile its units before resuming' }
    $ledgers=@{}; $soft=$false; $hard=$false
    foreach ($id in @('astra','deepseek')) {
        $limit=$Manifest.budget.ledgers[$id]
        $expected=if ($id -eq 'astra') {'credits'} else {'USD'}
        if (-not $limit -or $limit.unit -cne $expected -or $limit.soft_limit -gt $limit.hard_limit) { Stop-TeamError 10 "Invalid budget ledger: $id" }
        $saved=if ($State['cost_ledgers']) {$State.cost_ledgers[$id]} else {$null}
        if ($saved -and $saved.unit -cne $limit.unit) { Stop-TeamError 80 "Persisted cost unit differs from manifest: $id" }
        $amount=if ($saved) {[double]$saved.known_cost} else {0.0}
        if (-not [double]::IsFinite($amount) -or $amount -lt 0) { Stop-TeamError 80 "Invalid persisted cost: $id" }
        $ledgers[$id]=@{unit=$limit.unit;known_cost=$amount;soft_limit=$limit.soft_limit;hard_limit=$limit.hard_limit}
        $soft=$soft -or $amount -ge $limit.soft_limit; $hard=$hard -or $amount -ge $limit.hard_limit
    }
    return @{ledgers=$ledgers;soft_reached=$soft;hard_reached=$hard}
}

function Submit-TeamCost([string]$Directory, [double]$Amount, [string]$Evidence, [string]$Ledger, [string]$Unit, $Manifest, [string]$Source) {
    if ($Amount -lt 0 -or -not [double]::IsFinite($Amount) -or -not $Evidence -or
        $Ledger -cnotin @('astra','deepseek') -or [string]::IsNullOrWhiteSpace($Source)) {
        Stop-TeamError 10 'Cost report requires amount, evidence, ledger, explicit unit and source'
    }
    $budget=Get-TeamBudgetSnapshot @{} $Manifest
    if ($Unit -cne $budget.ledgers[$Ledger].unit) { Stop-TeamError 10 'Cost unit differs from its ledger; no implicit conversion or mixed-unit sum is allowed' }
    $hash = Get-TeamHash $Evidence
    $receiptDirectory = Join-Path $Directory 'cost-receipts'
    [IO.Directory]::CreateDirectory($receiptDirectory) | Out-Null
    try { $handle = [IO.File]::Open((Join-Path $receiptDirectory '.lock'), 'OpenOrCreate', 'ReadWrite', 'None') }
    catch { Stop-TeamError 20 'Another cost report is being recorded; retry the same evidence' }
    try {
        $path = Join-Path $receiptDirectory "$hash.json"
        if (Test-Path -LiteralPath $path) { Stop-TeamError 10 'Cost evidence already recorded' }
        Write-TeamData $path @{amount=$Amount;ledger=$Ledger;unit=$Unit;source=$Source;evidence_hash=$hash;recorded_at=[DateTime]::UtcNow.ToString('o')}
    } finally { $handle.Dispose() }
    return $hash
}

function Sync-TeamCost($State, $Manifest, [string]$Directory) {
    $previous=Get-TeamBudgetSnapshot $State $Manifest
    $totals=@{astra=0.0;deepseek=0.0}
    foreach ($file in @(Get-ChildItem -LiteralPath (Join-Path $Directory 'cost-receipts') -Filter '*.json' -ErrorAction SilentlyContinue)) {
        $receipt = Read-TeamData $file.FullName
        if (-not $receipt['ledger'] -or -not $receipt['unit']) { Stop-TeamError 80 'Legacy untyped receipt retained; reconcile its ledger and unit explicitly' }
        if ($receipt.ledger -cnotin @('astra','deepseek') -or $receipt.unit -cne $previous.ledgers[$receipt.ledger].unit -or
            [string]::IsNullOrWhiteSpace($receipt['source']) -or $receipt.evidence_hash -cne $file.BaseName -or
            $receipt.amount -isnot [ValueType] -or -not [double]::IsFinite([double]$receipt.amount) -or $receipt.amount -lt 0) {
            Stop-TeamError 80 'Invalid cost receipt; reconcile before dispatch'
        }
        $totals[$receipt.ledger]+=[double]$receipt.amount
    }
    $ledgers=@{}
    foreach ($id in $totals.Keys) {
        if (-not [double]::IsFinite($totals[$id]) -or $totals[$id] -lt $previous.ledgers[$id].known_cost) { Stop-TeamError 80 "Cost ledger regressed or overflowed: $id" }
        $ledgers[$id]=@{unit=$previous.ledgers[$id].unit;known_cost=$totals[$id]}
    }
    $changed=(Get-TeamCanonicalJson $State['cost_ledgers']) -cne (Get-TeamCanonicalJson $ledgers)
    $State['cost_ledgers']=$ledgers
    $budget=Get-TeamBudgetSnapshot $State $Manifest
    $control=Join-Path $Directory 'budget-control.json'
    if ($changed -or -not (Test-Path -LiteralPath $control)) { Write-TeamData $control @{stop_new_children=$budget.soft_reached;ledgers=$ledgers} }
    foreach ($limit in @('soft','hard')) {
        $reached=$budget["${limit}_reached"]; $marker="cost_${limit}_notified"
        if ($reached -and -not $State[$marker]) {
            Add-TeamEvent $Directory "cost_${limit}_limit_reached" @{ledgers=$budget.ledgers}
            $State[$marker]=$true; $changed=$true
        }
    }
    if ($budget.hard_reached -and $State.status -notin @('COMPLETED','CANCELLED','FAILED','ESCALATED')) { $State.status='PAUSED';$changed=$true }
    if ($changed) { Save-TeamState $State $Directory }
}

function Assert-TeamActionApproval($State, $Plan, [string]$Directory) {
    if (@($Plan['risk_flags'] | Where-Object { $_ -match '^(destructive|production_delete)$' }).Count) {
        Stop-TeamError 60 'Destructive production action requires owner intervention; no worker dispatched'
    }
    $records = @(Get-ChildItem -LiteralPath (Join-Path $Directory 'escalations') -Filter '*.yaml' -ErrorAction SilentlyContinue |
        ForEach-Object { Read-TeamData $_.FullName })
    foreach ($record in $records) {
        if ($record.status -eq 'pending') {
            if ([DateTime]$record.expires_at -le [DateTime]::UtcNow) {
                $State.status = 'PAUSED'; Save-TeamState $State $Directory
                Stop-TeamError 70 'Escalation expired unresolved; dispatch stays paused for an owner decision'
            }
            Stop-TeamError 70 'Unresolved escalation keeps dispatch paused'
        }
        if ($record.status -eq 'modify-plan' -and $record['plan_hash'] -ceq $State.plan_hash) {
            Stop-TeamError 70 'Owner requested a plan revision; unchanged plan cannot resume'
        }
    }
    $risky = @($Plan.tasks | Where-Object { $_.permissions.production -or $_.permissions.secrets -or $_.permissions.network })
    if (-not $risky.Count -and -not $Plan['risk_flags']) { return }
    $approved = @($records | Where-Object {
        $_.type -eq 'restricted_action' -and $_.status -eq 'approve' -and $_['plan_hash'] -ceq $State.plan_hash
    })
    if ($approved.Count) { return }
    New-TeamEscalation $State $Directory 'restricted_action' 'Plan requests restricted permissions or risk flags. Owner approval is bound to this plan revision.'
    Stop-TeamError 70 'Restricted action requires escalation for this exact plan'
}
