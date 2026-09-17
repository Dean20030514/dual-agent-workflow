# The coordinator alone writes state. Concurrent cost reporters append immutable receipts.
function Submit-TeamCost([string]$Directory, [double]$Amount, [string]$Evidence) {
    if ($Amount -lt 0 -or -not [double]::IsFinite($Amount) -or -not $Evidence) {
        Stop-TeamError 10 'Cost report requires a finite nonnegative amount and evidence file'
    }
    $hash = Get-TeamHash $Evidence
    $receiptDirectory = Join-Path $Directory 'cost-receipts'
    [IO.Directory]::CreateDirectory($receiptDirectory) | Out-Null
    try { $handle = [IO.File]::Open((Join-Path $receiptDirectory '.lock'), 'OpenOrCreate', 'ReadWrite', 'None') }
    catch { Stop-TeamError 20 'Another cost report is being recorded; retry the same evidence' }
    try {
        $path = Join-Path $receiptDirectory "$hash.json"
        if (Test-Path -LiteralPath $path) { Stop-TeamError 10 'Cost evidence already recorded' }
        Write-TeamData $path @{amount=$Amount;evidence_hash=$hash;recorded_at=[DateTime]::UtcNow.ToString('o')}
    } finally { $handle.Dispose() }
    return $hash
}

function Sync-TeamCost($State, $Manifest, [string]$Directory) {
    $receipts = @(Get-ChildItem -LiteralPath (Join-Path $Directory 'cost-receipts') -Filter '*.json' -ErrorAction SilentlyContinue)
    $total = 0.0
    foreach ($file in $receipts) {
        $receipt = Read-TeamData $file.FullName
        if ($receipt.evidence_hash -cne $file.BaseName -or $receipt.amount -isnot [ValueType] -or
            -not [double]::IsFinite([double]$receipt.amount) -or $receipt.amount -lt 0) {
            Stop-TeamError 80 'Invalid cost receipt; reconcile before dispatch'
        }
        $total += [double]$receipt.amount
    }
    if (-not [double]::IsFinite($total) -or $total -lt $State.known_cost) { Stop-TeamError 80 'Cost ledger regressed or overflowed' }
    $soft = $total -ge $Manifest.budget.soft_limit
    $hard = $total -ge $Manifest.budget.hard_limit
    # Native admission checks this control before creating another child, even in an existing worker.
    $changed = $State.known_cost -ne $total
    $control = Join-Path $Directory 'budget-control.json'
    if ($changed -or -not (Test-Path -LiteralPath $control)) {
        Write-TeamData $control @{stop_new_children=$soft;known_cost=$total}
    }
    $State.known_cost = $total
    foreach ($limit in @('soft','hard')) {
        $reached = if ($limit -eq 'soft') { $soft } else { $hard }
        $marker = "cost_${limit}_notified"
        if ($reached -and -not $State[$marker]) {
            Add-TeamEvent $Directory "cost_${limit}_limit_reached" @{cost=$total}
            $State[$marker] = $true; $changed = $true
        }
    }
    if ($hard -and $State.status -notin @('COMPLETED','CANCELLED','FAILED','ESCALATED')) {
        $State.status = 'PAUSED'; $changed = $true
    }
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
