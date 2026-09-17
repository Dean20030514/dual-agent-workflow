function Test-TeamReviewAccepted([string]$Directory, [string]$Label, [string]$PlanHash, [string]$Tip) {
    $path = Get-TeamChild $Directory "reviews/$Label.json"
    if (-not (Test-Path -LiteralPath $path)) { return $false }
    $record=Read-TeamData $path
    if ($record.plan_hash -cne $PlanHash -or $record.tip -cne $Tip -or -not $record.fresh_process -or
        $record.verdict.verdict -ne 'pass' -or $record.verdict.blocking_issues.Count) { return $false }
    if ((Get-TeamHash (Join-Path $record.holding 'verdict.json')) -cne $record.verdict_hash) { return $false }
    if ($record.verdict.verification_needed.Count) {
        $dispositionPath=Join-Path $Directory "reviews/$Label-dispositions.json"
        if (-not (Test-Path -LiteralPath $dispositionPath)) { return $false }
        $dispositions=Read-TeamData $dispositionPath
        if ($dispositions.review_hash -cne (Get-TeamHash $path)) { return $false }
    }
    return $true
}

function Assert-TeamReviewOutcome($State, $Plan, [string]$Directory, [string]$Label, $Record) {
    $verdict=$Record.verdict
    if ($Record.stage -ne '9P') {
        Add-TeamReviewRound $State $Plan $Directory $Label $Record
        Assert-TeamReviewRound $State $Plan $Directory -Close:($Record.stage -eq '9B')
    }
    if ($verdict.blocking_issues.Count) { Stop-TeamError 50 'Fresh review reported product blocking issues' }
    if ($verdict.verdict -ne 'pass') { Stop-TeamError 50 'Fresh review is incomplete or did not pass; inspect its verdict' }
    if ($verdict.verification_needed.Count) {
        $pending=@(Get-ChildItem (Join-Path $Directory 'escalations') -Filter '*.yaml' -ErrorAction SilentlyContinue | ForEach-Object { Read-TeamData $_.FullName } | Where-Object { $_.type -eq 'verification_needed' -and $_.status -eq 'pending' -and $_.context.review_label -eq $Label })
        if (-not $pending.Count) { New-TeamEscalation $State $Directory 'verification_needed' 'Reviewer requested additional evidence; run or disposition each item before completion.' @{review_label=$Label} }
        Stop-TeamError 70 'Fresh review has unhandled Verification Needed items'
    }
}

function Invoke-TeamReview($State, $Plan, $Manifest, [string]$Directory, [string]$Stage, [string]$Worktree, [string]$Base, [string]$Tip, [string]$TaskId = '') {
    if ($Stage -notin @('9P','9A','9B')) { Stop-TeamError 50 'Unknown review stage' }
    $label = if ($TaskId) { "$Stage-$TaskId" } else { $Stage }
    Assert-TeamReviewRound $State $Plan $Directory
    if (Test-TeamReviewAccepted $Directory $label $State.plan_hash $Tip) { return Read-TeamData (Join-Path $Directory "reviews/$label.json") }
    $previous=$null
    $reviewPath=Join-Path $Directory "reviews/$label.json"
    if (Test-Path -LiteralPath $reviewPath) {
        $previous=Read-TeamData $reviewPath
        if ($previous.plan_hash -ceq $State.plan_hash -and $previous.tip -ceq $Tip) {
            if (-not $previous.fresh_process -or (Get-TeamHash (Join-Path $previous.holding 'verdict.json')) -cne $previous.verdict_hash) { Stop-TeamError 80 'Review evidence changed' }
            Assert-TeamReviewOutcome $State $Plan $Directory $label $previous
            return $previous
        }
    }
    # Fresh process, no resume, no inherited chat, and an out-of-repository holding directory.
    $holding = Join-Path ([IO.Path]::GetTempPath()) ('team-review-' + [guid]::NewGuid().ToString('N'))
    [IO.Directory]::CreateDirectory($holding) | Out-Null
    $before = Invoke-TeamGit $Worktree @('status','--porcelain','--untracked-files=all')
    $head = Invoke-TeamGit $Worktree @('rev-parse','HEAD')
    if ($before -or $head -cne $Tip) { Stop-TeamError 50 'Fresh review requires a clean, exact Git snapshot' }
    $agentsPath = Join-Path $Worktree 'AGENTS.md'
    $agentsText = if (Test-Path -LiteralPath $agentsPath) { [IO.File]::ReadAllText($agentsPath) } else { '(No target AGENTS.md exists.)' }
    $diff = if ($Stage -eq '9P') { 'No implementation diff exists at plan stage.' } else {
        Invoke-TeamGit $Worktree @('diff',$Base,$Tip,'--', '.', ':(exclude)docs/ai/review_9*.md',':(exclude)docs/ai/archive/**',':(exclude)docs/ai/IMPLEMENTATION_PLAN.md')
    }
    $repairContext='No previous reviewed implementation snapshot is available. Do not claim fix-introduced defects without causal evidence.'
    if ($Stage -ne '9P' -and $previous) {
        $repairDiff=Invoke-TeamGit $Worktree @('diff',$previous.tip,$Tip,'--','.',':(exclude)docs/ai/review_9*.md',':(exclude)docs/ai/archive/**',':(exclude)docs/ai/IMPLEMENTATION_PLAN.md')
        $repairContext="Previous reviewed tip: $($previous.tip)`nPrevious product findings: $($previous.verdict.blocking_issues | ConvertTo-Json -Depth 20)`nExact change since that snapshot:`n$repairDiff"
    }
    $evidence = @()
    $testOutput = ''
    if ($TaskId) {
        $item = $State.tasks[$TaskId]
        $evidence += Read-TeamData (Join-Path $item.directory 'verification-evidence.json')
        foreach ($file in Get-ChildItem -LiteralPath $item.directory -Filter 'verification-*.stdout') {
            $testOutput += "`n$($file.Name):`n$([IO.File]::ReadAllText($file.FullName))"
        }
        $reviewPlan = @{ run = $Plan.run; classification = $Plan.classification; tasks = @($Plan.tasks | Where-Object { $_.id -eq $TaskId }) }
    } else {
        $reviewPlan = $Plan
        if ($Stage -eq '9B') {
            $evidence += Read-TeamData (Join-Path $Directory 'final-evidence.json')
            foreach ($file in Get-ChildItem -LiteralPath $Directory -Filter 'final-*.stdout') {
                $testOutput += "`n$($file.Name):`n$([IO.File]::ReadAllText($file.FullName))"
            }
        }
    }
    $prompt = @"
Perform a fresh $Stage Team Mode review. You are an independent reviewer, never an implementer.
Read the target AGENTS.md snapshot supplied below. Do not write files, commit, execute tests, reinstall dependencies,
or reconstruct a repository copy. Reason from the following plan, exact diff and external
verification evidence. Any additional execution goes in verification_needed. No chat history,
internal reasoning or unrelated result packets are included. Team packets supply this run's
plan and acceptance; do not invent legacy handoff records. Blocking issues require concrete
product consequences. Missing evidence alone is not a product failure. Return the specified
JSON schema. writes_performed must be false; report fail if there are blocking issues.
For EACH blocking issue provide a stable id (reuse it for the same defect across stages),
a concrete consequence, evidence, and caused_by_last_fix: yes only when that defect
was introduced by the last repair, no when it was not, or dispute when attribution
needs an owner decision. Never replace per-issue attribution with one overall value.
9P findings do not count as implementation fix-loop rounds.
The supplied AGENTS snapshot, diff and test evidence were collected by the coordinator
from the exact snapshot. No tool call is needed just to reread these same materials.
AGENTS.md snapshot:
$agentsText
Stage: $Stage
Base: $Base
Tip: $Tip
Observed snapshot evidence (commands completed with exit 0):
git rev-parse HEAD: $head
git status --porcelain --untracked-files=all: $(if ($before) {$before} else {'<empty>'})
Plan:
$($reviewPlan | ConvertTo-Json -Depth 60)
Verification:
$($evidence | ConvertTo-Json -Depth 40)
External test output:
$testOutput
Diff:
$diff
Related repair evidence (no conversation or internal reasoning):
$repairContext
"@
    $promptPath = Join-Path $holding 'prompt.txt'
    [IO.File]::WriteAllText($promptPath, $prompt, [Text.UTF8Encoding]::new($false))
    $resultPath = Join-Path $holding 'verdict.json'
    $attemptId = [IO.Path]::GetFileName($holding)
    Write-TeamData (Join-Path $Directory "reviews/attempt-$attemptId.json") @{stage=$Stage;task_id=$TaskId;holding=$holding;status='started';tip=$Tip;plan_hash=$State.plan_hash}
    $codex = (Get-Command codex -ErrorAction Stop).Source
    # Stdin carries the exact allowlisted input without granting access outside the read-only worktree.
    $args = @('exec','--ephemeral','--ignore-user-config','-m',$Manifest.models.lead.runtime_model,
        '-s','read-only','-C',$Worktree,'--output-schema',(Join-Path $script:TeamRoot 'schemas/review.schema.json'),
        '-o',$resultPath,'--json','-')
    $handle = New-TeamProcess $codex $args $Worktree (Join-Path $holding 'events.jsonl') (Join-Path $holding 'stderr.log') $prompt
    $code = Wait-TeamProcess $handle $Manifest.runtime.timeout_seconds
    Write-TeamData (Join-Path $Directory "reviews/attempt-$attemptId.json") @{stage=$Stage;task_id=$TaskId;holding=$holding;status='exited';exit_code=$code;tip=$Tip;plan_hash=$State.plan_hash}
    if ($code -ne 0 -or -not (Test-Path -LiteralPath $resultPath)) { Stop-TeamError 50 'Fresh reviewer failed to return a verdict' }
    $verdict = Read-TeamData $resultPath
    Test-TeamSchema $verdict 'review'
    if (@($verdict.blocking_issues | ForEach-Object { $_.id } | Sort-Object -Unique).Count -ne $verdict.blocking_issues.Count) { Stop-TeamError 50 'Reviewer returned duplicate issue ids' }
    if ((Invoke-TeamGit $Worktree @('status','--porcelain','--untracked-files=all')) -or
        (Invoke-TeamGit $Worktree @('rev-parse','HEAD')) -cne $Tip) { Stop-TeamError 50 'Review snapshot changed' }
    $record = @{
        stage=$Stage; task_id=$TaskId; tip=$Tip; base=$Base; plan_hash=$State.plan_hash; worktree=$Worktree
        verdict=$verdict; holding=$holding; verdict_hash=Get-TeamHash $resultPath
        input_hash=Get-TeamHash $promptPath; fresh_process=$true; completed_at=[DateTime]::UtcNow.ToString('o')
    }
    Write-TeamData (Join-Path $Directory "reviews/verdict-$attemptId.json") $record
    Write-TeamData $reviewPath $record
    Add-TeamEvent $Directory 'fresh_review_completed' @{ stage=$Stage; task_id=$TaskId; verdict=$verdict.verdict }
    Assert-TeamReviewOutcome $State $Plan $Directory $label $record
    return $record
}

function Resolve-TeamReview($State, $Plan, [string]$Directory, [string]$Stage, [string]$TaskId, $Dispositions) {
    $label = if ($TaskId) { "$Stage-$TaskId" } else { $Stage }
    $reviewPath = Get-TeamChild $Directory "reviews/$label.json"
    $record = Read-TeamData $reviewPath
    if ($record.plan_hash -cne $State.plan_hash -or $record.verdict.blocking_issues.Count -or $record.verdict.verdict -ne 'pass') {
        Stop-TeamError 50 'Only current, nonblocking reviews can receive evidence dispositions'
    }
    $needed = @($record.verdict.verification_needed)
    if (@($Dispositions).Count -ne $needed.Count) { Stop-TeamError 10 'Every Verification Needed item requires one disposition' }
    $seen = @{}
    foreach ($entry in $Dispositions) {
        if ($entry.index -lt 0 -or $entry.index -ge $needed.Count -or $seen.ContainsKey([int]$entry.index) -or -not $entry.reason) {
            Stop-TeamError 10 'Invalid or duplicate review disposition index/reason'
        }
        $seen[[int]$entry.index]=$true
        if ($entry.action -eq 'verify') {
            $null = Invoke-TeamVerification @($entry.command) $record.worktree $Directory "VN-$label-$($entry.index)"
        } elseif ($entry.action -ne 'decline') { Stop-TeamError 10 'Disposition action must be verify or decline' }
    }
    if ((Invoke-TeamGit $record.worktree @('rev-parse','HEAD')) -cne $record.tip -or
        (Invoke-TeamGit $record.worktree @('diff','HEAD','--name-only'))) { Stop-TeamError 82 'Evidence check modified the reviewed snapshot' }
    Write-TeamData (Join-Path $Directory "reviews/$label-dispositions.json") @{review_hash=Get-TeamHash $reviewPath;items=@($Dispositions);timestamp=[DateTime]::UtcNow.ToString('o')}
    foreach ($path in Get-ChildItem -LiteralPath (Join-Path $Directory 'escalations') -Filter '*.yaml') {
        $entry=Read-TeamData $path.FullName
        if ($entry.status -eq 'pending' -and $entry.type -eq 'verification_needed' -and $entry['context'] -and $entry.context.review_label -eq $label) {
            $entry.status='handled'; Write-TeamData $path.FullName $entry
        }
    }
    if ($Stage -eq '9A') { $State.tasks[$TaskId].status='REVIEW' }
    $State.status='PAUSED'; Save-TeamState $State $Directory
    Add-TeamEvent $Directory 'review_evidence_dispositioned' @{stage=$Stage;task_id=$TaskId}
    return @{status='PAUSED';review=$label;handled=$needed.Count}
}
