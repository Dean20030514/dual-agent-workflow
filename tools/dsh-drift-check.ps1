# Mechanical drift gate between the two landings (claude/ and dsh/).
#
# WHY THIS EXISTS
#   `docs/ai/DSH-LANDING-NOTES.md` §2 registers every intended text change of the DSH
#   landing relative to the Claude-side mother copy. Nothing checked that the set of
#   differences still equals the registered set, so a criteria-level rule could drift on
#   one side alone and no gate would notice. That was the open [DEBT] this file repays
#   (Payback trigger: "next change under dsh/**").
#
# WHAT IT DOES
#   For each derived pair it recomputes the line-level difference and compares it against
#   a frozen baseline (tools/dsh-drift-baseline.txt). Any added, changed or removed
#   difference line is reported and the gate exits 1.
#     * editing BOTH sides identically -> difference set unchanged -> green (that is a
#       shared change, not drift);
#     * editing ONE side -> difference set changes -> red.
#   Exit codes: 0 = the difference set equals the baseline, 1 = it does not (or a pair
#   file is missing).
#
# BASELINE
#   Regenerating it with -Update is the moment a deliberate divergence is declared: the
#   same commit must register the change in `docs/ai/DSH-LANDING-NOTES.md` (§2 for a
#   change carried on both sides, §6 for a DSH-only divergence). The gate cannot check
#   prose registration; the human reading the diff is the check for that half.
#
# STATED LIMITS (not hidden debt)
#   It detects difference; it does not classify it. It cannot tell a criteria change from
#   a mechanical path rewrite — classification stays human/reviewer work. It also cannot
#   see a change applied identically to both sides (by construction: then there is no
#   difference), which is exactly what "one discipline, two landings" wants.
#
# READ-ONLY unless -Update is passed: a plain run writes nothing.

[CmdletBinding()]
param(
    [switch]$Update
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repo = Split-Path -Parent $PSScriptRoot
$baselinePath = Join-Path $PSScriptRoot 'dsh-drift-baseline.txt'

function Get-DerivedPairs {
    <# Returns the derived claude/ -> dsh/ pairs, mirroring DSH-LANDING-NOTES.md §1. #>
    $pairs = [System.Collections.Generic.List[object]]::new()
    $workflowFiles = @(
        'AGENTS.md', 'reviewer-prompt.md', 'index.md', 'QUALITY_GATES.md',
        'workflow-design-notes.md', 'AB-model-diagnostic.md'
    )
    foreach ($name in $workflowFiles) {
        $pairs.Add([pscustomobject]@{
            Id    = "workflow/$name"
            Left  = "claude/workflow/$name"
            Right = "dsh/workflow/$name"
        })
    }
    foreach ($f in (Get-ChildItem (Join-Path $repo 'claude/commands') -Filter *.md -File | Sort-Object Name)) {
        $pairs.Add([pscustomobject]@{
            Id    = "commands/$($f.Name)"
            Left  = "claude/commands/$($f.Name)"
            Right = "dsh/skills/dual-agent-workflow/references/phases/$($f.Name)"
        })
    }
    foreach ($f in (Get-ChildItem (Join-Path $repo 'claude/workflow/templates') -Filter *.md -File | Sort-Object Name)) {
        $pairs.Add([pscustomobject]@{
            Id    = "templates/$($f.Name)"
            Left  = "claude/workflow/templates/$($f.Name)"
            Right = "dsh/workflow/templates/$($f.Name)"
        })
    }
    return $pairs
}

function Get-PairDiffLines {
    <# Returns this pair's changed lines, each keeping its leading '+' or '-'. #>
    param([string]$Id, [string]$Left, [string]$Right)

    foreach ($rel in @($Left, $Right)) {
        if (-not (Test-Path -LiteralPath (Join-Path $repo $rel))) {
            throw "derived pair file is missing: $rel (a rename must not pass silently)"
        }
    }

    $raw = & git -C $repo diff --no-index --no-color --unified=0 -- $Left $Right
    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($line in $raw) {
        if ($line -like '+++*' -or $line -like '---*') { continue }
        if ($line.Length -gt 0 -and ($line[0] -eq '+' -or $line[0] -eq '-')) {
            $lines.Add("$Id`t$line")
        }
    }
    # Returned as a plain unrolled sequence on purpose: callers wrap the call in @(),
    # which normalizes "no differences" to an empty array. Wrapping the List instead
    # (unary comma) would nest it and silently coerce whole pairs into one joined string.
    return $lines
}

function Get-CurrentDiffSet {
    <# Returns the full normalized difference set across all derived pairs. #>
    $all = [System.Collections.Generic.List[string]]::new()
    $perPair = [System.Collections.Specialized.OrderedDictionary]::new()
    foreach ($pair in (Get-DerivedPairs)) {
        $lines = @(Get-PairDiffLines -Id $pair.Id -Left $pair.Left -Right $pair.Right)
        $perPair[$pair.Id] = $lines.Count
        foreach ($l in $lines) { $all.Add($l) }
    }
    $sorted = $all | Sort-Object -CaseSensitive
    return [pscustomobject]@{ Lines = @($sorted); PerPair = $perPair }
}

$current = Get-CurrentDiffSet

if ($Update) {
    if ($current.Lines.Count -eq 0) {
        throw "refusing to write an empty baseline: the derived pairs were not found (check the repo root)"
    }
    $header = @(
        '# Frozen difference set between claude/ and dsh/ derived pairs.',
        '# Generated by tools/dsh-drift-check.ps1 -Update. Do not hand-edit.',
        '# Format: <pair-id><TAB><+ or - diff line>. Regenerating this file declares a',
        '# deliberate divergence: register it in docs/ai/DSH-LANDING-NOTES.md in the same commit.',
        '#'
    )
    # Written as LF + no BOM explicitly: Set-Content emits CRLF on Windows, which the
    # repo's .gitattributes forbids and which would make every regeneration a noisy diff.
    $text = ((($header + $current.Lines) -join "`n") + "`n")
    [System.IO.File]::WriteAllText($baselinePath, $text, (New-Object System.Text.UTF8Encoding($false)))
    Write-Output "baseline written: $baselinePath"
    Write-Output "registered difference lines: $($current.Lines.Count) across $($current.PerPair.Count) pairs"
    exit 0
}

if (-not (Test-Path -LiteralPath $baselinePath)) {
    Write-Output "FAIL: no baseline at $baselinePath - run: pwsh -NoProfile -File tools/dsh-drift-check.ps1 -Update"
    exit 1
}

$baseline = @(Get-Content -LiteralPath $baselinePath | Where-Object { $_ -and -not $_.StartsWith('#') })
$currentSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$current.Lines)
$baselineSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$baseline)

$added = @($current.Lines | Where-Object { -not $baselineSet.Contains($_) })
$removed = @($baseline | Where-Object { -not $currentSet.Contains($_) })

Write-Output "derived pairs checked: $($current.PerPair.Count)"
foreach ($id in $current.PerPair.Keys) {
    Write-Output ("  {0,-42} difference lines = {1}" -f $id, $current.PerPair[$id])
}
Write-Output "baseline difference lines: $($baseline.Count) ; current: $($current.Lines.Count)"

if ($added.Count -eq 0 -and $removed.Count -eq 0) {
    Write-Output 'DRIFT: none - the difference set equals the registered baseline'
    exit 0
}

Write-Output ''
Write-Output "DRIFT DETECTED: $($added.Count) unregistered line(s), $($removed.Count) vanished line(s)"
foreach ($l in ($added | Select-Object -First 40)) { Write-Output "  [NEW]     $l" }
foreach ($l in ($removed | Select-Object -First 40)) { Write-Output "  [GONE]    $l" }
if ($added.Count -gt 40 -or $removed.Count -gt 40) {
    Write-Output '  (list truncated at 40 lines per direction)'
}
Write-Output ''
Write-Output 'Each line above is a difference between the two landings that no baseline records.'
Write-Output 'Either revert it, or - if the divergence is deliberate - register it in'
Write-Output 'docs/ai/DSH-LANDING-NOTES.md and re-run with -Update in the same commit.'
exit 1
