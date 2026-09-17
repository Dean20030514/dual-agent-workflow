# Critical implementation reviews share one round per reviewed plan revision.
function Get-TeamReviewRoundSummary($State, $Round) {
    $issues=@{}
    foreach ($record in $Round.records.Values) {
        foreach ($issue in $record.issues) {
            if (-not $issues.ContainsKey($issue.id)) { $issues[$issue.id]=@() }
            $issues[$issue.id]+=$issue.caused_by_last_fix
        }
    }
    $yes=@(); $no=@(); $disputed=@()
    foreach ($id in $issues.Keys) {
        $values=@($issues[$id] | Sort-Object -Unique)
        $value=if ($values.Count -eq 1) {$values[0]} else {'dispute'}
        $decisions=$Round['causality_decisions']
        if ($value -eq 'dispute' -and $decisions -and $decisions.Contains($id)) { $value=$decisions[$id].value }
        switch ($value) {
            'yes' { $yes+=$id }
            'no' { $no+=$id }
            'dispute' { $disputed+=$id }
        }
    }
    return @{yes=@($yes | Sort-Object);no=@($no | Sort-Object);disputed=@($disputed | Sort-Object);blocking_count=$issues.Count}
}

function Add-TeamReviewRound($State, $Plan, [string]$Directory, [string]$Label, $Record) {
    if ($Plan.classification.level -ne 'critical' -or $Record.stage -eq '9P') { return }
    if ($State['review_loops'] -and -not $State['review_rounds']) {
        Stop-TeamError 80 'Legacy per-stage review counters require explicit reconciliation before continuing; they cannot be reset'
    }
    if (-not $State['review_rounds']) { $State['review_rounds']=@{} }
    $key=[string]$State.revision
    if (-not $State.review_rounds.Contains($key)) {
        $State.review_rounds[$key]=@{revision=$State.revision;records=@{};closed=$false;extension_approved=$false;causality_decisions=@{}}
    }
    $round=$State.review_rounds[$key]
    if ($round.records.Contains($Label)) {
        if ($round.records[$Label].verdict_hash -cne $Record.verdict_hash -or $round.records[$Label].tip -cne $Record.tip) {
            Stop-TeamError 80 'A review result for this revision and stage already exists; revise the plan before another review'
        }
        return
    }
    if ($round.closed) { Stop-TeamError 80 'Review round is already closed' }
    $round.records[$Label]=@{tip=$Record.tip;verdict_hash=$Record.verdict_hash;holding=$Record.holding;issues=$Record.verdict.blocking_issues;verdict=$Record.verdict.verdict}
    Save-TeamState $State $Directory
    Add-TeamEvent $Directory 'review_round_recorded' @{revision=$State.revision;label=$Label;verdict_hash=$Record.verdict_hash}
}

function Assert-TeamReviewRound($State, $Plan, [string]$Directory, [switch]$Close) {
    if ($Plan.classification.level -ne 'critical') { return }
    if ($State['review_loops'] -and -not $State['review_rounds']) {
        Stop-TeamError 80 'Legacy per-stage review counters require explicit reconciliation before continuing; they cannot be reset'
    }
    if (-not $State['review_rounds']) { return }
    $rounds=@($State.review_rounds.Values | Sort-Object revision)
    $streak=0; $count=0
    foreach ($round in $rounds) {
        $count++
        $summary=Get-TeamReviewRoundSummary $State $round
        # Unknown attribution cannot turn into a count or a reset without an owner decision.
        if ($summary.yes.Count) { $streak++ }
        elseif (-not $summary.disputed.Count) { $streak=0 }
        if ($round.revision -ne $State.revision) { continue }
        $round['number']=$count; $round['streak']=$streak
        if ($Close) { $round.closed=$true }
        Save-TeamState $State $Directory
        if ($streak -ge 2 -and $summary.yes.Count) {
            $State['hard_stop']=$true; Save-TeamState $State $Directory
            Stop-TeamError 60 'Two consecutive implementation review rounds confirmed fix-introduced product defects; rollback, re-split, or seek owner-approved architecture change'
        }
        if ($summary.disputed.Count) {
            $pending=@(Get-ChildItem (Join-Path $Directory 'escalations') -Filter '*.yaml' -ErrorAction SilentlyContinue | ForEach-Object { Read-TeamData $_.FullName } | Where-Object { $_.type -eq 'review_causality' -and $_.status -eq 'pending' -and $_.context.revision -eq $State.revision })
            if (-not $pending.Count) {
                New-TeamEscalation $State $Directory 'review_causality' 'Per-issue causal attribution is disputed; an owner must decide each issue without rewriting the reviewer verdict.' @{revision=$State.revision;issue_ids=$summary.disputed}
            }
            Stop-TeamError 70 'Review causality requires per-issue owner decisions'
        }
        $limit=3
        if ($State['review_round_limit']) { $limit=[int]$State.review_round_limit }
        $incomplete=$summary.blocking_count -gt 0 -or @($round.records.Values | Where-Object verdict -ne 'pass').Count -gt 0
        $early=$Close -and $summary.blocking_count -gt 0 -and $summary.yes.Count -eq $summary.blocking_count
        if ($incomplete -and ($count -ge $limit -or $early) -and -not $round.extension_approved) {
            $reason=if ($early) {'early_stop'} else {'round_cap'}
            $State['review_stop']=@{reason=$reason;revision=$State.revision;round=$count;streak=$streak}
            Save-TeamState $State $Directory
            $pending=@(Get-ChildItem (Join-Path $Directory 'escalations') -Filter '*.yaml' -ErrorAction SilentlyContinue | ForEach-Object { Read-TeamData $_.FullName } | Where-Object { $_.type -eq 'review_round_limit' -and $_.status -eq 'pending' -and $_.context.revision -eq $State.revision })
            if (-not $pending.Count) {
                New-TeamEscalation $State $Directory 'review_round_limit' 'Stopped, NOT converged. Owner may end, re-split, rollback, or explicitly authorize one additional review round. Unresolved product issues still prohibit completion.' $State.review_stop
            }
            Stop-TeamError 70 "Review $reason reached; no automatic repair or further review"
        }
    }
}

function Resolve-TeamReviewControl($State, [string]$Directory, $Escalation, [string]$Decision, [string]$Reason, $Dispositions) {
    if ($Decision -ne 'approve' -or $Escalation.type -notin @('review_causality','review_round_limit')) { return }
    if ($State['hard_stop']) { Stop-TeamError 60 'Owner round extension cannot override the fix-loop hard stop' }
    if ($Escalation.context.revision -ne $State.revision) { Stop-TeamError 70 'Review decision belongs to an earlier revision' }
    $round=$State.review_rounds[[string]$State.revision]
    if ($Escalation.type -eq 'review_causality') {
        $summary=Get-TeamReviewRoundSummary $State $round
        $seen=@{}
        foreach ($entry in @($Dispositions)) {
            if ($entry -isnot [Collections.IDictionary] -or -not $entry.Contains('id') -or -not $entry.Contains('value') -or -not $entry.Contains('reason') -or
                $entry.id -notin $summary.disputed -or $entry.value -notin @('yes','no') -or -not $entry.reason -or $seen.ContainsKey($entry.id)) {
                Stop-TeamError 10 'Causality approval requires each disputed id, yes/no value, and owner reason exactly once'
            }
            $seen[$entry.id]=@{value=$entry.value;reason=$entry.reason;escalation=$Escalation.id;decided_at=[DateTime]::UtcNow.ToString('o')}
        }
        if ($seen.Count -ne $summary.disputed.Count) { Stop-TeamError 10 'Missing per-issue owner causality decisions' }
        foreach ($id in $seen.Keys) { $round.causality_decisions[$id]=$seen[$id] }
    } else {
        $round.extension_approved=$true
        $State['review_round_limit']=[Math]::Max(3, [int]$Escalation.context.round + 1)
        $State.Remove('review_stop')
    }
    Write-TeamData (Join-Path $Directory "decisions/DEC-$($Escalation.id).json") @{type=$Escalation.type;reason=$Reason;revision=$State.revision;escalation=$Escalation.id;items=@($Dispositions);one_round_only=($Escalation.type -eq 'review_round_limit')}
}
