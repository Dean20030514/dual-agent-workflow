BeforeAll {
    $script:TeamPath=Split-Path $PSScriptRoot -Parent
    foreach ($module in @('Core','State','ReviewRounds','Review')) { . (Join-Path $script:TeamPath "scripts/$module.ps1") }
    function Issue([string]$Id, [string]$Cause) { @{id=$Id;consequence='Concrete fixture consequence';evidence='Fixture input produces incorrect output';caused_by_last_fix=$Cause} }
    function Record([string]$Stage, $Issues=@(), [string]$Verdict='') {
        if (-not $Verdict) { $Verdict=if ($Issues.Count) {'fail'} else {'pass'} }
        @{stage=$Stage;tip=('a'*40);verdict_hash=[guid]::NewGuid().ToString('N');holding='fixture';verdict=@{verdict=$Verdict;blocking_issues=@($Issues);verification_needed=@();writes_performed=$false}}
    }
    function Code($Action, [int]$Expected) {
        $caught=$null
        try { & $Action | Out-Null } catch { $caught=$_ }
        $caught | Should -Not -BeNullOrEmpty
        $caught.Exception.Data['TeamExitCode'] | Should -Be $Expected -Because $caught.Exception.Message
    }
}
Describe 'Critical review round aggregation' {
    BeforeEach {
        $script:Dir=Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        [IO.Directory]::CreateDirectory($script:Dir) | Out-Null
        $script:StateData=@{revision=1;run_id='FIXTURE';plan_hash=('a'*64);status='PAUSED'}
        $script:PlanData=@{classification=@{level='critical'}}
        # This unit layer isolates the reducer; the real persistence/schema path is covered by CLI tests.
        Mock Save-TeamState {}
    }
    It 'counts repeated 9A and 9B findings once within a revision and copies issue attribution' {
        $record=Record '9A' @((Issue 'same-bug' 'yes'),(Issue 'old-bug' 'no'))
        Add-TeamReviewRound $script:StateData $script:PlanData $script:Dir '9A-T1' $record
        Add-TeamReviewRound $script:StateData $script:PlanData $script:Dir '9A-T1' $record
        Add-TeamReviewRound $script:StateData $script:PlanData $script:Dir '9B' (Record '9B' @((Issue 'same-bug' 'yes')))
        Assert-TeamReviewRound $script:StateData $script:PlanData $script:Dir -Close
        $round=$script:StateData.review_rounds['1']; $round.number | Should -Be 1; $round.streak | Should -Be 1
        (Get-TeamReviewRoundSummary $script:StateData $round).blocking_count | Should -Be 2
        $round.records['9A-T1'].issues[0].caused_by_last_fix | Should -Be 'yes'
        $round.records['9A-T1'].issues[1].caused_by_last_fix | Should -Be 'no'
        @((Get-Content (Join-Path $script:Dir 'events.jsonl')) | Where-Object { $_ -match 'review_round_recorded' }).Count | Should -Be 2
    }
    It 'does not count 9P or Routine verdicts' {
        Code { Assert-TeamReviewOutcome $script:StateData $script:PlanData $script:Dir '9P' (Record '9P' @((Issue 'plan' 'yes'))) } 50
        $script:StateData.ContainsKey('review_rounds') | Should -BeFalse
        $script:PlanData.classification.level='routine'
        Add-TeamReviewRound $script:StateData $script:PlanData $script:Dir '9A-T1' (Record '9A' @((Issue 'x' 'yes')))
        $script:StateData.ContainsKey('review_rounds') | Should -BeFalse
    }
    It 'resets the streak on a round with no fix-introduced issue and excludes evidence requests' {
        Add-TeamReviewRound $script:StateData $script:PlanData $script:Dir '9A-T1' (Record '9A' @((Issue 'new' 'yes'),(Issue 'old' 'no')))
        Assert-TeamReviewRound $script:StateData $script:PlanData $script:Dir -Close
        $script:StateData.revision=2
        $record=Record '9A'; $record.verdict.verification_needed=@('Run one focused check')
        Code { Assert-TeamReviewOutcome $script:StateData $script:PlanData $script:Dir '9A-T1' $record } 70
        $script:StateData.review_rounds['2'].streak | Should -Be 0
        $script:StateData.review_rounds['2'].number | Should -Be 2
        $script:StateData.ContainsKey('hard_stop') | Should -BeFalse
    }
    It 'prioritizes the consecutive hard stop over early-stop and refuses an owner round extension' {
        Add-TeamReviewRound $script:StateData $script:PlanData $script:Dir '9A-T1' (Record '9A' @((Issue 'new1' 'yes'),(Issue 'old' 'no')))
        Assert-TeamReviewRound $script:StateData $script:PlanData $script:Dir -Close
        $script:StateData.revision=2
        Add-TeamReviewRound $script:StateData $script:PlanData $script:Dir '9B' (Record '9B' @((Issue 'new2' 'yes')))
        Code { Assert-TeamReviewRound $script:StateData $script:PlanData $script:Dir -Close } 60
        $script:StateData.hard_stop | Should -BeTrue
        $script:StateData.review_rounds['2'].streak | Should -Be 2
        Code { Resolve-TeamReviewControl $script:StateData $script:Dir @{type='review_round_limit'} 'approve' 'Try again' @() } 60
    }
    It 'waits for round closure before early-stop and allows only an explicit one-round extension' {
        Add-TeamReviewRound $script:StateData $script:PlanData $script:Dir '9A-T1' (Record '9A' @((Issue 'new' 'yes')))
        Assert-TeamReviewRound $script:StateData $script:PlanData $script:Dir
        $script:StateData.ContainsKey('review_stop') | Should -BeFalse
        Code { Assert-TeamReviewRound $script:StateData $script:PlanData $script:Dir -Close } 70
        $script:StateData.review_stop.reason | Should -Be 'early_stop'
        $entry=Read-TeamData @(Get-ChildItem (Join-Path $script:Dir 'escalations') -Filter '*.yaml')[0].FullName
        Resolve-TeamReviewControl $script:StateData $script:Dir $entry 'approve' 'Owner authorizes one additional round' @()
        Assert-TeamReviewRound $script:StateData $script:PlanData $script:Dir -Close
        $script:StateData.review_rounds['1'].extension_approved | Should -BeTrue
        $script:StateData.ContainsKey('review_stop') | Should -BeFalse
    }
    It 'caps unconverged implementation revisions at three without counting skipped plan-only revisions' {
        foreach ($revision in @(1,4,6)) {
            $script:StateData.revision=$revision
            Add-TeamReviewRound $script:StateData $script:PlanData $script:Dir '9A-T1' (Record '9A' @((Issue "old-$revision" 'no')))
            if ($revision -eq 6) { Code { Assert-TeamReviewRound $script:StateData $script:PlanData $script:Dir } 70 }
            else { Assert-TeamReviewRound $script:StateData $script:PlanData $script:Dir -Close }
        }
        $script:StateData.review_stop.reason | Should -Be 'round_cap'
        $script:StateData.review_stop.round | Should -Be 3
        $script:StateData.ContainsKey('hard_stop') | Should -BeFalse
    }
    It 'requires per-issue owner decisions for disagreement and never rewrites reviewer attribution' {
        Add-TeamReviewRound $script:StateData $script:PlanData $script:Dir '9A-T1' (Record '9A' @((Issue 'x' 'yes')))
        Add-TeamReviewRound $script:StateData $script:PlanData $script:Dir '9B' (Record '9B' @((Issue 'x' 'no'),(Issue 'y' 'dispute')))
        Code { Assert-TeamReviewRound $script:StateData $script:PlanData $script:Dir } 70
        $entry=Read-TeamData @(Get-ChildItem (Join-Path $script:Dir 'escalations') -Filter '*.yaml')[0].FullName
        Code { Resolve-TeamReviewControl $script:StateData $script:Dir $entry 'approve' 'Incomplete' @(@{id='x';value='no';reason='Known existing bug'}) } 10
        Resolve-TeamReviewControl $script:StateData $script:Dir $entry 'approve' 'Owner attribution' @(@{id='x';value='no';reason='Known existing bug'},@{id='y';value='no';reason='Predates the repair'})
        Assert-TeamReviewRound $script:StateData $script:PlanData $script:Dir -Close
        $round=$script:StateData.review_rounds['1']
        $round.streak | Should -Be 0
        $round.records['9A-T1'].issues[0].caused_by_last_fix | Should -Be 'yes'
        $round.records['9B'].issues[1].caused_by_last_fix | Should -Be 'dispute'
        $round.causality_decisions.y.value | Should -Be 'no'
    }
    It 'rejects replacing a verdict or silently resetting legacy counters' {
        Add-TeamReviewRound $script:StateData $script:PlanData $script:Dir '9A-T1' (Record '9A')
        Code { Add-TeamReviewRound $script:StateData $script:PlanData $script:Dir '9A-T1' (Record '9A') } 80
        $script:StateData.Remove('review_rounds'); $script:StateData['review_loops']=@{'9A-T1'=@{rounds=2;streak=1}}
        Code { Add-TeamReviewRound $script:StateData $script:PlanData $script:Dir '9A-T1' (Record '9A') } 80
        Code { Assert-TeamReviewRound $script:StateData $script:PlanData $script:Dir } 80
        Mock New-TeamProcess { throw 'Must not launch a reviewer before legacy reconciliation' }
        Code { Invoke-TeamReview $script:StateData $script:PlanData @{} $script:Dir '9A' $script:Dir ('b'*40) ('a'*40) 'T1' } 80
        Should -Invoke New-TeamProcess -Exactly -Times 0
    }
    It 'reuses a bound failing verdict without launching another reviewer or another round' {
        $record=Record '9A' @((Issue 'x' 'no'))
        $record['plan_hash']=$script:StateData.plan_hash; $record['fresh_process']=$true
        $record.holding=Join-Path $script:Dir 'holding'
        Write-TeamData (Join-Path $record.holding 'verdict.json') $record.verdict
        $record.verdict_hash=Get-TeamHash (Join-Path $record.holding 'verdict.json')
        Write-TeamData (Join-Path $script:Dir 'reviews/9A-T1.json') $record
        Mock New-TeamProcess { throw 'Must not launch another reviewer' }
        foreach ($attempt in 1..2) {
            Code { Invoke-TeamReview $script:StateData $script:PlanData @{} $script:Dir '9A' $script:Dir ('b'*40) $record.tip 'T1' } 50
        }
        $script:StateData.review_rounds['1'].number | Should -Be 1
        $script:StateData.review_rounds['1'].records.Count | Should -Be 1
        Should -Invoke New-TeamProcess -Exactly -Times 0
    }
}
