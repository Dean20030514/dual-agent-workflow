#requires -Version 7.0
# AC-2 path-references check: extract references from tracked markdown, resolve
# them (relative + explicit ~/ install mapping), verify existence against the
# tracked-file set (ordinal, case-sensitive - git tree is the authority).
#
# Extraction rules (deliberately narrow, each locked by fixtures; widening any
# of them needs a plan change, never an ad-hoc tweak):
#   R1 markdown inline links/images and reference definitions - prose only
#      (fenced blocks and inline code spans excluded: link syntax there is
#      exemplary, not referential)
#   R2 ~/ tokens - everywhere INCLUDING code contexts (docs quote deploy paths
#      in backticks and shell examples; the reference is real); captured WHOLE
#      including brace/wildcard/comma characters, so classification always
#      sees the full original token (2026-07-30 adjudication: truncating at a
#      special character and classifying the stem is forbidden)
#   R3 ./ prefixed tokens - everywhere (AC-2 mandates catching ./install.sh
#      inside fenced install examples)
#   R4 trailing-slash directory tokens inside inline code spans (AC-2 mandates
#      catching `skills/`)
# Resolution: query/fragment stripped; scheme URLs (incl. drive letters) and
# pure anchors excluded; ~/ resolves ONLY through the explicit mapping below
# (source of truth: install.ps1 deploy steps); brace/wildcard tokens resolve
# ONLY through the exact pattern registry (managed patterns expand to repo
# targets verified one by one; machine-local patterns are never checked; an
# unregistered pattern is a finding); plain machine-local paths are recognized
# but never checked; traversal above the scan root is a finding.

$script:PathRefCheckId = 'path-references'

# Mirrors install.ps1: single-file copies, mirror-replaced directories.
# NOTE: ~/.codex/config.example.toml is deliberately NOT here - install.ps1
# seeds codex/config.example.toml INTO ~/.codex/config.toml; no deploy step
# ever creates ~/.codex/config.example.toml on a machine, so a doc referencing
# that home path is an error (the repo file is referenced by its repo path).
$script:TildeFileMap = @{
    '~/.claude/CLAUDE.md'     = 'claude/CLAUDE.md'
    '~/.claude/settings.json' = 'claude/settings.json'
    '~/.codex/AGENTS.md'      = 'codex/AGENTS.md'
}
$script:TildeDirMap = @{
    '~/.claude/rules/'    = 'claude/rules/'
    '~/.claude/workflow/' = 'claude/workflow/'
    '~/.claude/commands/' = 'claude/commands/'
}
# Machine-local references: recognized, never checked against the repo. Exact
# entries or exact prefixes only - every line justified by install.ps1 deploy
# semantics or by audited canonical-doc evidence (2026-07-30 full-repo dump).
$script:MachineLocalFiles = @(
    '~/.codex/config.toml'                            # seeded once, then machine state
    '~/.claude.json'                                  # client machine state
    '~/.codex/auth.json'                              # credentials, never deployed
    '~/.codex/reviewer-readonly.config.toml'          # planned PR2 local reviewer profiles
    '~/.codex/reviewer-workspace-write.config.toml'
    '~/.codex/reviewer.config.toml'
    '~/.claude/agents/'                               # retired path; docs reference it only to forbid it
    # README.md:47 evidenced token, full string - one of exactly two audited
    # workflow/archive exceptions (2026-07-30 adjudication; see fact note below).
    '~/.claude/workflow/archive/2026-07-30-guard-effectiveness-backup/ARCHIVE_NOTE.md'
)
$script:MachineLocalPrefixes = @(
    '~/.claude/projects/'                             # auto-memory, never deployed
    '~/.codex/sessions/'                              # session logs, machine state
    '~/.claude/rules-archived-zh/'                    # retired rules kept local-only
)
# Fact note (corrects the pre-round-3 comment that called workflow/archive
# "live-only, excluded from the mirror"): install.ps1:43-48 mirror-replaces the
# ENTIRE ~/.claude/workflow directory, so nothing under workflow/archive
# survives a deploy - it is a mixed namespace whose final resolution belongs to
# H3. Until H3 lands, exactly two audited references are local-only exceptions
# (2026-07-30 adjudication, exact strings, never prefixes): the README.md:47
# ARCHIVE_NOTE.md file entry above and the docs/ai/INSTALLER_GUARD.md:72
# pattern entry below; every other workflow/archive reference resolves through
# the managed directory mapping and is existence-checked like any workflow path.
#
# Exact pattern registry (2026-07-30 adjudication, plan A): tilde tokens that
# contain brace/wildcard characters are classified ONLY by exact whole-string
# ordinal match against this registry - never by prefix, never after
# truncation. An unregistered pattern token is unrecognized-tilde and FAILs.
# Managed patterns map to explicit repo targets, each verified against the
# tracked tree; machine-local patterns are recognized and never checked.
$script:ManagedPatternMap = [System.Collections.Generic.Dictionary[string, string[]]]::new([System.StringComparer]::Ordinal)
# README.md:15 (and handoff quotes): the three mirror-replaced deploy dirs.
$script:ManagedPatternMap.Add('~/.claude/{rules,workflow,commands}',
    @('claude/rules', 'claude/workflow', 'claude/commands'))
# claude/CLAUDE.md:173: the seven per-phase command files, expanded one by one.
$script:ManagedPatternMap.Add('~/.claude/commands/{define,explore,plan,design-check,implement,debug,final-review}.md',
    @('claude/commands/define.md', 'claude/commands/explore.md', 'claude/commands/plan.md',
        'claude/commands/design-check.md', 'claude/commands/implement.md', 'claude/commands/debug.md',
        'claude/commands/final-review.md'))
# claude/CLAUDE.md:215: glob over deployed rule packs; container dir verified.
$script:ManagedPatternMap.Add('~/.claude/rules/*.md', @('claude/rules'))
# codex/AGENTS.md:8: glob over deployed command files; container dir verified.
$script:ManagedPatternMap.Add('~/.claude/commands/*.md', @('claude/commands'))
$script:MachineLocalPatterns = @(
    '~/.claude/projects/*/memory'                     # README.md:19 auto-memory pattern, never deployed
    '~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl'    # claude/CLAUDE.md:196 rollout-log glob, machine state
    # docs/ai/INSTALLER_GUARD.md:72 evidenced token, full string - the second
    # audited workflow/archive exception (see fact note above). Under
    # full-token capture the token at that line carries the trailing wildcard
    # suffix; the registry stores the evidenced full string, not a bare-dir
    # transcription of it.
    '~/.claude/workflow/archive/**'
)
$script:TildePatternChars = [char[]]('{', '}', '*')
# Literal claims for weak-signal token kinds (dotslash / inline-dir). Those
# kinds are non-literal examples by default - language rule packs and workflow
# docs quote generic project layouts (src/, ./gradlew, docs/ai/) that are not
# claims about THIS repo. Each pair below asserts "this token in this file IS
# a genuine path claim" (AC-2 mandated drift forms). Meta-references to the
# same tokens in planning docs stay exempt because claims are file-scoped.
$script:ProductionLiteralClaims = @(
    'claude/rules/README.md|./install.sh'
    'claude/rules/README.md|skills/'
)

$script:FenceMarkerRegex = '^\s*(```|~~~)'
$script:InlineCodeRegex = '`([^`]+)`'
$script:LinkRegex = '!?\[[^\]]*\]\(\s*([^)\s]+)(?:\s+"[^"]*")?\s*\)'
$script:DefinitionRegex = '^\s*\[[^\]]+\]:\s+(\S+)'
$script:TildeTokenRegex = '(?<![\w~.])~/[A-Za-z0-9._{},*\-/]+'
$script:DotSlashTokenRegex = '(?<![\w.])\./[A-Za-z0-9._\-/]+'
$script:InlineDirTokenRegex = '^[A-Za-z0-9._\-]+(/[A-Za-z0-9._\-]+)*/$'

function Get-MarkdownReference {
    # False positive: $SourceFile is consumed inside the $addRef scriptblock
    # closure below, which PSSA's static analysis does not traverse.
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'SourceFile')]
    [CmdletBinding()]
    param(
        [string[]]$Lines = @(),
        [Parameter(Mandatory)][string]$SourceFile
    )
    $references = [System.Collections.Generic.List[object]]::new()
    $addRef = {
        param([string]$Kind, [string]$RawTarget, [int]$LineNumber)
        # Trailing '.'/',' is sentence punctuation swallowed by the token
        # charset, never path content; pattern characters are kept intact.
        $trimmed = $RawTarget.TrimEnd('.', ',')
        if ([string]::IsNullOrWhiteSpace($trimmed)) { return }
        $references.Add([pscustomobject]@{
                Kind       = $Kind
                RawTarget  = $trimmed
                Line       = $LineNumber
                SourceFile = $SourceFile
            })
    }
    $inFence = $false
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        $line = [string]$Lines[$i]
        $lineNumber = $i + 1
        if ($line -match $script:FenceMarkerRegex) {
            $inFence = -not $inFence
            continue
        }
        if ($inFence) {
            # Fenced code: only path-shaped tokens (R2/R3); link syntax is exemplary.
            foreach ($m in [regex]::Matches($line, $script:TildeTokenRegex)) { & $addRef 'tilde' $m.Value $lineNumber }
            foreach ($m in [regex]::Matches($line, $script:DotSlashTokenRegex)) { & $addRef 'dotslash' $m.Value $lineNumber }
            continue
        }
        # 1. Inline code spans: R2/R3 tokens plus R4 whole-span directory tokens.
        foreach ($span in [regex]::Matches($line, $script:InlineCodeRegex)) {
            $code = $span.Groups[1].Value
            foreach ($m in [regex]::Matches($code, $script:TildeTokenRegex)) { & $addRef 'tilde' $m.Value $lineNumber }
            foreach ($m in [regex]::Matches($code, $script:DotSlashTokenRegex)) { & $addRef 'dotslash' $m.Value $lineNumber }
            if ($code -cmatch $script:InlineDirTokenRegex) { & $addRef 'inline-dir' $code $lineNumber }
        }
        # 2. Prose remainder: links/images/definitions (R1), then bare tokens.
        $prose = [regex]::Replace($line, $script:InlineCodeRegex, { param($m) ' ' * $m.Length })
        foreach ($m in [regex]::Matches($prose, $script:LinkRegex)) { & $addRef 'link' $m.Groups[1].Value $lineNumber }
        $defMatch = [regex]::Match($prose, $script:DefinitionRegex)
        if ($defMatch.Success) { & $addRef 'link' $defMatch.Groups[1].Value $lineNumber }
        $prose = [regex]::Replace($prose, $script:LinkRegex, { param($m) ' ' * $m.Length })
        foreach ($m in [regex]::Matches($prose, $script:TildeTokenRegex)) { & $addRef 'tilde' $m.Value $lineNumber }
        foreach ($m in [regex]::Matches($prose, $script:DotSlashTokenRegex)) { & $addRef 'dotslash' $m.Value $lineNumber }
    }
    return @($references)
}

function Resolve-PathReference {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Reference)
    $result = [pscustomobject]@{
        Category        = ''
        ResolvedTarget  = $null
        ResolvedTargets = @()
        IsDirectory     = $false
    }
    $raw = [string]$Reference.RawTarget
    if ($Reference.Kind -eq 'tilde') {
        # Pattern-shaped tokens (brace/wildcard) classify ONLY through the
        # exact pattern registry - they never consult the exact-file or prefix
        # lists, so a typo like a misspelled memory dir cannot ride a valid
        # prefix into machine-local (round-3 blocking, plan A).
        if ($raw.IndexOfAny($script:TildePatternChars) -ge 0) {
            if ($script:MachineLocalPatterns -ccontains $raw) { $result.Category = 'machine-local'; return $result }
            if ($script:ManagedPatternMap.ContainsKey($raw)) {
                $result.Category = 'resolved-pattern'
                $result.ResolvedTargets = @($script:ManagedPatternMap[$raw])
                return $result
            }
            $result.Category = 'unrecognized-tilde'
            return $result
        }
        # Bare home-config roots are concept references to the LOCAL deploy
        # location itself (with or without trailing slash) - machine-local by
        # definition. Only mapped subpaths assert repo counterparts; this is an
        # explicit two-entry list, not a generalization of ~/.
        if ($raw.TrimEnd('/') -cin @('~/.claude', '~/.codex')) { $result.Category = 'machine-local'; return $result }
        if ($script:MachineLocalFiles -ccontains $raw) { $result.Category = 'machine-local'; return $result }
        foreach ($prefix in $script:MachineLocalPrefixes) {
            if ($raw.StartsWith($prefix, [System.StringComparison]::Ordinal)) { $result.Category = 'machine-local'; return $result }
        }
        if ($script:TildeFileMap.ContainsKey($raw)) {
            $result.Category = 'resolved'
            $result.ResolvedTarget = $script:TildeFileMap[$raw]
            return $result
        }
        foreach ($prefix in $script:TildeDirMap.Keys) {
            if ($raw.StartsWith($prefix, [System.StringComparison]::Ordinal)) {
                $result.Category = 'resolved'
                $mapped = $script:TildeDirMap[$prefix] + $raw.Substring($prefix.Length)
                $result.IsDirectory = $mapped.EndsWith('/')
                $result.ResolvedTarget = $mapped.TrimEnd('/')
                return $result
            }
            # Bare directory reference like ~/.claude/rules (no trailing slash).
            if (($raw + '/') -ceq $prefix) {
                $result.Category = 'resolved'
                $result.IsDirectory = $true
                $result.ResolvedTarget = $script:TildeDirMap[$prefix].TrimEnd('/')
                return $result
            }
        }
        $result.Category = 'unrecognized-tilde'
        return $result
    }
    # link / dotslash / inline-dir: strip query and fragment first.
    $target = ($raw -split '[#?]')[0]
    if ([string]::IsNullOrWhiteSpace($target)) { $result.Category = 'anchor'; return $result }
    if ($target -match '^[A-Za-z][A-Za-z0-9+.\-]*:') { $result.Category = 'external'; return $result }
    $result.IsDirectory = $target.EndsWith('/')
    # Pure path math against the source file's directory - no filesystem probing,
    # so case sensitivity and traversal semantics stay deterministic.
    $segments = [System.Collections.Generic.List[string]]::new()
    $sourceDir = @(([string]$Reference.SourceFile) -split '/' | Select-Object -SkipLast 1)
    foreach ($seg in $sourceDir) { $segments.Add($seg) }
    if ($target.StartsWith('/')) { $segments.Clear() }
    foreach ($part in ($target -split '/')) {
        switch ($part) {
            '' { continue }
            '.' { continue }
            '..' {
                if ($segments.Count -eq 0) { $result.Category = 'traversal'; return $result }
                $segments.RemoveAt($segments.Count - 1)
            }
            default { $segments.Add($part) }
        }
    }
    if ($segments.Count -eq 0) { $result.Category = 'traversal'; return $result }
    $result.Category = 'resolved'
    $result.ResolvedTarget = ($segments -join '/')
    return $result
}

function Test-TargetExistence {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Target,
        [Parameter(Mandatory)][System.Collections.Generic.HashSet[string]]$FileSet,
        [Parameter(Mandatory)][object[]]$FileList
    )
    if ($FileSet.Contains($Target)) { return $true }
    $prefix = $Target + '/'
    foreach ($file in $FileList) {
        if (([string]$file).StartsWith($prefix, [System.StringComparison]::Ordinal)) { return $true }
    }
    return $false
}

function Invoke-PathReferencesCheck {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [string]$FixtureRoot,
        [string[]]$LiteralClaims
    )
    $checkId = $script:PathRefCheckId
    if (-not $PSBoundParameters.ContainsKey('LiteralClaims')) {
        $LiteralClaims = $script:ProductionLiteralClaims
    }
    if ($PSBoundParameters.ContainsKey('FixtureRoot')) {
        # Fixture mode is a TEST entry point only: the root must live inside
        # tools/validate/tests/fixtures - the production CLI must never be able
        # to exclude real files by pointing the scan at a subtree.
        $fixturesBase = (Resolve-Path -LiteralPath (Join-Path $RepoRoot 'tools/validate/tests/fixtures')).Path
        $canonicalRoot = (Resolve-Path -LiteralPath $FixtureRoot).Path
        $insideFixtures = $canonicalRoot.StartsWith($fixturesBase + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)
        if (-not ($insideFixtures -or $canonicalRoot -eq $fixturesBase)) {
            throw "FixtureRoot must be inside tools/validate/tests/fixtures (got '$FixtureRoot'); production scans must not exclude real files via fixture mode."
        }
        $scanBase = $canonicalRoot
        $allFiles = @(Get-ChildItem -LiteralPath $canonicalRoot -Recurse -File | ForEach-Object {
                $_.FullName.Substring($canonicalRoot.Length + 1) -replace '\\', '/'
            })
        $scanFiles = @($allFiles | Where-Object { $_ -clike '*.md' })
    }
    else {
        $scanBase = $RepoRoot
        # Targets may live anywhere in the tracked tree (archive files are valid
        # link targets); only scan SUBJECTS go through the active-scan filter.
        $allFiles = Get-TrackedFile -RepoRoot $RepoRoot
        $scanFiles = @(Select-ActiveScanFile -Paths $allFiles | Where-Object { $_ -clike '*.md' })
    }
    $fileSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$allFiles, [System.StringComparer]::Ordinal)
    $findings = @()
    foreach ($file in $scanFiles) {
        $fullPath = Join-Path $scanBase ($file -replace '/', [System.IO.Path]::DirectorySeparatorChar)
        $lines = @(Get-Content -LiteralPath $fullPath)
        foreach ($reference in @(Get-MarkdownReference -Lines $lines -SourceFile $file)) {
            if ($reference.Kind -in @('dotslash', 'inline-dir')) {
                # Weak-signal kinds are non-literal examples unless claimed.
                if ($LiteralClaims -cnotcontains "$($reference.SourceFile)|$($reference.RawTarget)") { continue }
            }
            $resolution = Resolve-PathReference -Reference $reference
            $isMissing = $false
            switch ($resolution.Category) {
                'external' { }
                'anchor' { }
                'machine-local' { }
                'traversal' { $isMissing = $true }
                'unrecognized-tilde' { $isMissing = $true }
                'resolved' {
                    if (-not (Test-TargetExistence -Target $resolution.ResolvedTarget -FileSet $fileSet -FileList $allFiles)) {
                        $isMissing = $true
                    }
                }
                'resolved-pattern' {
                    # Managed pattern: every expansion target must exist; the
                    # finding reports the full original token.
                    foreach ($target in $resolution.ResolvedTargets) {
                        if (-not (Test-TargetExistence -Target $target -FileSet $fileSet -FileList $allFiles)) {
                            $isMissing = $true
                            break
                        }
                    }
                }
            }
            if ($isMissing) {
                $findings += New-ValidationFinding -CheckId $checkId -Target $reference.SourceFile `
                    -Observation $reference.RawTarget -Line $reference.Line
            }
        }
    }
    $status = if (@($findings).Count -gt 0) { 'FAIL' } else { 'PASS' }
    return New-CheckResult -CheckId $checkId -Status $status -Findings $findings
}
