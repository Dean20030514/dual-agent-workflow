# AC2 - -DryRun prints the complete plan and writes absolutely nothing (slice A has no write path).

BeforeAll {
    . "$PSScriptRoot/TestHelpers.ps1"
    function Get-PlanPathKeys {
        param([Parameter(Mandatory)]$Output)
        $keys = New-Object System.Collections.Generic.List[string]
        foreach ($line in $Output) {
            if (-not $line.ToString().StartsWith('[PLAN]')) { continue }
            $m = [regex]::Match($line.ToString(), '([A-Za-z]:\\[^ ]+)')
            if ($m.Success) {
                $full = $m.Groups[1].Value.TrimEnd('\')
                $keys.Add(($full -replace '\\', '/'))
            }
        }
        return ($keys | Sort-Object -Unique)
    }
}

Describe 'AC2 -DryRun' {
    BeforeEach {
        $case = New-TestCase -Name 'plan' -SeedTargets -SeedConfigToml
        # Amendment ㉙: archive as the LAST segment, plus a leaf-name-only counter example.
        New-Item -ItemType Directory -Force (Join-Path $case.ClaudeDir 'workflow\archive') | Out-Null
        Set-Content -Path (Join-Path $case.ClaudeDir 'workflow\archive\e.md') -Value 'last-segment archive sample' -Encoding ascii
        Set-Content -Path (Join-Path $case.ClaudeDir 'workflow\myarchive.md') -Value 'leaf name contains archive but is NOT a path segment' -Encoding ascii
        $script:Args = @('-ClaudeDir', $case.ClaudeDir, '-CodexDir', $case.CodexDir, '-DshDir', $case.DshDir)
        $script:Before = Get-TargetsSignature -Case $case
        $script:BakBefore = (@(Get-ChildItem -LiteralPath $case.Home -Recurse -Force -Filter '*.bak-*' | ForEach-Object FullName) -join "`n")
        $script:R = Invoke-InstallerCase -Case $case -Arguments (@('-DryRun') + $script:Args)
    }
    AfterEach { Remove-TestCase $case }

    It 'exits 0 and writes nothing at all (files AND directories)' {
        $script:R.ExitCode | Should -Be 0
        (Get-TargetsSignature -Case $case) | Should -Be $script:Before
        (@(Get-ChildItem -LiteralPath $case.Home -Recurse -Force -Filter '*.bak-*' | ForEach-Object FullName) -join "`n") | Should -Be $script:BakBefore
    }

    It 'lists the live-only path as STALE (reported, never deleted), and the leaf-name look-alike' {
        $staleLines = Get-TaggedLines -Output $script:R.Output -Tag '[STALE]'
        @($staleLines | Where-Object { $_ -like ('*' + (Join-Path $case.ClaudeDir 'workflow\stray.md') + '*') }).Count | Should -BeGreaterThan 0
        @($staleLines | Where-Object { $_ -like '*myarchive.md*' }).Count | Should -BeGreaterThan 0 -Because 'a leaf name containing archive is NOT a path segment'
    }

    It 'preserves every keep-local-only sample, including archive as the last segment' {
        $preserve = Get-TaggedLines -Output $script:R.Output -Tag '[PRESERVE]'
        foreach ($sample in 'workflow\archive\old\e.md', 'workflow\archive\e.md', 'workflow\AGENTS.md.bak-20260101-000000') {
            @($preserve | Where-Object { $_ -like ('*' + (Join-Path $case.ClaudeDir $sample) + '*') }).Count | Should -BeGreaterThan 0
        }
        $stale = Get-TaggedLines -Output $script:R.Output -Tag '[STALE]'
        @($stale | Where-Object { $_ -match '\\archive(\\|$)' }).Count | Should -Be 0 -Because 'only a path SEGMENT named archive is keep-local; myarchive.md is not'
        # Review 9A round 3, G2/G3: the DIRECTORY form must be asserted too (the \\archive
        # filter above cannot see "[STALE] …\archive (dir)"), and *.bak-* must never be stale.
        @($preserve | Where-Object { $_ -like ('*' + (Join-Path $case.ClaudeDir 'workflow\archive') + ' (dir)') }).Count | Should -BeGreaterThan 0 -Because 'the archive directory itself (last segment) is keep-local-only'
        @($stale | Where-Object { $_ -like '*archive (dir)' }).Count | Should -Be 0 -Because 'a keep-local-only directory must never be reported as stale'
        @($stale | Where-Object { $_ -like '*.bak-*' }).Count | Should -Be 0 -Because 'a *.bak-* leaf name is keep-local-only as well'
    }

    It 'covers exactly the managed surface of the old script (A3) and keeps config.toml out of [STALE]' {
        $planned = @(Get-PlanPathKeys -Output $script:R.Output)
        foreach ($needle in 'claude/CLAUDE.md', 'claude/rules', 'claude/workflow', 'claude/commands', 'codex/AGENTS.md', 'codex/config.toml', 'dsh/AGENTS.md', 'dsh/workflow', 'dsh/skills/dual-agent-workflow', 'dsh/skills/independent-review') {
            @($planned | Where-Object { $_ -like ('*' + $needle + '*') }).Count | Should -BeGreaterThan 0 -Because "$needle must appear in the plan"
        }
        @(Get-TaggedLines -Output $script:R.Output -Tag '[STALE]' | Where-Object { $_ -like '*config.toml*' }).Count | Should -Be 0
    }

    It 'prints a [SUMMARY] line' { $script:R.OutputText | Should -Match '\[SUMMARY\]\s+RESULT=OK' }

    It 'summary counters equal the rows actually printed (Amendment ㉚)' {
        $m = [regex]::Match($script:R.OutputText, 'planned=(\d+) stale=(\d+) preserve=(\d+)')
        $m.Success | Should -BeTrue -Because 'the counter line is part of the frozen output contract'
        $staleRows = @(Get-TaggedLines -Output $script:R.Output -Tag '[STALE]').Count
        $preserveRows = @(Get-TaggedLines -Output $script:R.Output -Tag '[PRESERVE]' | Where-Object { $_ -notlike '*(machine-local, never touched)*' }).Count
        [int]$m.Groups[2].Value | Should -Be $staleRows -Because 'stale=0 while [STALE] rows are on screen under-reports what the reader has to review'
        [int]$m.Groups[3].Value | Should -Be $preserveRows
        [int]$m.Groups[1].Value | Should -BeGreaterThan 0
        [int]$m.Groups[2].Value | Should -BeGreaterThan 0 -Because 'this case seeds stray.md, so something must be reported as stale'
        [int]$m.Groups[3].Value | Should -BeGreaterThan 0 -Because 'this case seeds archive/ and *.bak-* samples'
    }

    It 'planned= equals the number of action rows printed (BACKLOG T-6)' {
        $m = [regex]::Match($script:R.OutputText, 'planned=(\d+) stale=(\d+) preserve=(\d+)')
        $m.Success | Should -BeTrue
        $actionRows = @($script:R.Output | ForEach-Object {
                $text = $_.ToString()
                if ($text -match '^\s*\[PLAN\]\s+(\S+)') { $matches[1] }
            } | Where-Object { $_ -in 'copy', 'seed', 'keep', 'mirror' }).Count
        [int]$m.Groups[1].Value | Should -Be $actionRows -Because 'planned counts actions, and every action prints exactly one [PLAN] row'
        [int]$m.Groups[1].Value | Should -BeGreaterThan 0
    }

    It 'negative control: a single test-side write DOES change the signature (the probe is not vacuous)' {        Set-Content -Path (Join-Path $case.ClaudeDir 'written-by-the-test.txt') -Value 'x' -Encoding ascii
        (Get-TargetsSignature -Case $case) | Should -Not -Be $script:Before
    }

    It 'a preserved DIRECTORY keeps its subtree: no [STALE] row may target its contents (9A round 4 B1)' {
        $bakDir = Join-Path $case.ClaudeDir 'workflow\old.bak-20260101-000000'
        New-Item -ItemType Directory -Force $bakDir | Out-Null
        Set-Content -Path (Join-Path $bakDir 'note.md') -Value 'live-only content inside a preserved directory' -Encoding ascii
        $r = Invoke-InstallerCase -Case $case -Arguments (@('-DryRun') + $script:Args)
        $r.ExitCode | Should -Be 0
        $preserve = Get-TaggedLines -Output $r.Output -Tag '[PRESERVE]'
        @($preserve | Where-Object { $_ -like ('*' + $bakDir + ' (dir)') }).Count | Should -BeGreaterThan 0 -Because 'the *.bak-* directory itself is keep-local-only'
        $stale = Get-TaggedLines -Output $r.Output -Tag '[STALE]'
        @($stale | Where-Object { $_ -like ('*' + $bakDir + '*') }).Count | Should -Be 0 -Because 'the whitelist is subtree-inheriting: a directory that stays keeps its whole content'
    }

    It 'invariant (9B round 5 TCG-1 / AC2 assertion 6): no [STALE] (dir) row may be an ancestor of a [PRESERVE] row' {
        # The nested live-only form that review 9A round 5 predicted would break the partition:
        # a live-only directory whose only whitelisted descendant is a *.bak-* DIRECTORY.
        $legacyDir = Join-Path $case.ClaudeDir 'workflow\legacy'
        $nestedBakDir = Join-Path $legacyDir 'old.bak-20260101-000000'
        New-Item -ItemType Directory -Force $nestedBakDir | Out-Null
        Set-Content -Path (Join-Path $nestedBakDir 'note.md') -Value 'nested live-only content' -Encoding ascii
        $r = Invoke-InstallerCase -Case $case -Arguments (@('-DryRun') + $script:Args)
        $r.ExitCode | Should -Be 0
        $stale = @(Get-TaggedLines -Output $r.Output -Tag '[STALE]')
        $preserve = @(Get-TaggedLines -Output $r.Output -Tag '[PRESERVE]' | Where-Object { $_ -notlike '*(machine-local, never touched)*' })
        @($preserve | Where-Object { $_ -like ('*' + $legacyDir + ' (dir)') }).Count | Should -BeGreaterThan 0 -Because 'the live-only ancestor of a preserved path must itself be preserved'
        foreach ($staleLine in $stale) {
            $stalePath = (($staleLine -replace '^\[STALE\]\s+', '') -replace ' \(dir\)$', '')
            foreach ($preLine in $preserve) {
                $prePath = (($preLine -replace '^\[PRESERVE\]\s+', '') -replace ' \(dir\)$', '')
                $prePath.StartsWith($stalePath + '\', [System.StringComparison]::OrdinalIgnoreCase) | Should -BeFalse -Because "the plan must be a partition, but a row below the stale '$stalePath' is preserved as '$prePath'"
            }
        }
    }

    It 'the planned plugins are exactly the ones claude/settings.json enables (A3, independent oracle)' {
        $expected = @(Get-ExpectedPlugins)
        $expected.Count | Should -BeGreaterThan 0
        $plannedPlugins = @()
        foreach ($line in $script:R.Output) {
            $m = [regex]::Match($line.ToString(), '^\[PLAN\]\s+plugin\s+([^\s@]+)@')
            if ($m.Success) { $plannedPlugins += $m.Groups[1].Value }
        }
        @($plannedPlugins).Count | Should -BeGreaterThan 0
        ((@($plannedPlugins | Sort-Object -Unique)) -join ',') | Should -Be (($expected | Sort-Object) -join ',') -Because 'the shipped plugin list must match settings.json, not a copy kept inside the installer'
    }

    It 'covers exactly the managed surface (A3): the plan action targets EQUAL the independent oracle set' {
        # Helpers live here on purpose: they are used by this case only, and keeping them
        # local makes the oracle read as one self-contained statement.
        function Get-ManagedActionTargets {
            $managed = @()
            foreach ($entry in (Get-ManagedDeploySet -RepoRoot (Get-RepoRoot))) {
                $parts = $entry -split '/'
                if ($parts[0] -eq 'claude') { $managed += ('claude/' + $parts[1]) }
                elseif ($parts[0] -eq 'codex') {
                    if ($parts[1] -ne 'team') { $managed += ('codex/' + $parts[1]) }
                    elseif ($parts[2] -eq 'spike') { $managed += $entry }
                    else { $managed += ('codex/team/' + $parts[2]) }
                }
                elseif ($parts[0] -eq 'dsh') {
                    if ($parts[1] -eq 'skills') { $managed += ('dsh/skills/' + $parts[2]) }
                    else { $managed += ('dsh/' + $parts[1]) }
                }
            }
            $managed += 'codex/config.toml'
            return ($managed | Sort-Object -Unique)
        }
        function Get-PlannedActionTargets {
            param([Parameter(Mandatory)]$Output, [Parameter(Mandatory)][string]$HomeRoot)
            $targets = @()
            foreach ($line in $Output) {
                $text = $line.ToString()
                if (-not $text.StartsWith('[PLAN]')) { continue }
                if ($text -match '\bplugin\b') { continue }
                $target = $null
                $m = [regex]::Match($text, '->\s+([A-Za-z]:\\[^\s]+)')
                if ($m.Success) { $target = $m.Groups[1].Value }
                else {
                    # A seed action whose target already exists prints "keep <path> (seed-only...)"
                    # instead of "seed src -> dst", and it still belongs to the managed surface.
                    $m = [regex]::Match($text, '^\s*\[PLAN\]\s+keep\s+([A-Za-z]:\\[^\s]+)')
                    if ($m.Success) { $target = $m.Groups[1].Value }
                }
                if (-not $target) { continue }
                if (-not $target.StartsWith($HomeRoot, [System.StringComparison]::OrdinalIgnoreCase)) { continue }
                $rel = $target.Substring($HomeRoot.Length).TrimStart('\') -replace '\\', '/'
                # The oracle names the surface without the leading dot (.claude -> claude).
                if ($rel.StartsWith('.')) { $rel = $rel.Substring(1) }
                $targets += $rel
            }
            return ($targets | Sort-Object -Unique)
        }

        $planned = @(Get-PlannedActionTargets -Output $script:R.Output -HomeRoot $case.Home)
        $managed = @(Get-ManagedActionTargets)
        $planned.Count | Should -Be $managed.Count -Because "the plan must carry exactly the managed surface: planned=[$($planned -join ',')] managed=[$($managed -join ',')]"
        ($planned -join ',') | Should -Be ($managed -join ',')
    }
}
