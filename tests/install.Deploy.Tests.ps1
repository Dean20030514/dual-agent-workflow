# Deploy path (human ruling 2026-09-15): the installer copies and updates, and NEVER deletes.
#
# These cases exist because the guarantee changed: the old build was a zero-write validator,
# and the build before that was a mirror-replace that once deleted 127 local-only files. The
# contract now under test is "update the managed files, leave everything else exactly alone".

BeforeAll {
    . "$PSScriptRoot/TestHelpers.ps1"
}

Describe 'Deploy - updates the managed surface and deletes nothing' {
    BeforeEach {
        $case = New-TestCase -Name 'deploy' -SeedTargets -SeedConfigToml
        $script:Args = @('-ClaudeDir', $case.ClaudeDir, '-CodexDir', $case.CodexDir, '-DshDir', $case.DshDir)
        $script:StrayFile = Join-Path $case.ClaudeDir 'workflow\stray.md'
        $script:StrayBefore = (Get-FileHash -LiteralPath $script:StrayFile).Hash
        # live-only shapes that must all survive: a directory with content, an EMPTY directory.
        $script:LiveDir = Join-Path $case.ClaudeDir 'workflow\live-only'
        New-Item -ItemType Directory -Force $script:LiveDir | Out-Null
        Set-Content -Path (Join-Path $script:LiveDir 'mine.md') -Value 'machine-specific notes' -Encoding ascii
        $script:EmptyDir = Join-Path $case.ClaudeDir 'workflow\empty-live-only'
        New-Item -ItemType Directory -Force $script:EmptyDir | Out-Null
        $script:LiveDirFileBefore = (Get-FileHash -LiteralPath (Join-Path $script:LiveDir 'mine.md')).Hash
        $script:MachineLocalBefore = (Get-FileHash -LiteralPath (Join-Path $case.ClaudeDir 'settings.local.json')).Hash
        $script:R = Invoke-InstallerCase -Case $case -Arguments $script:Args
    }
    AfterEach { Remove-TestCase $case }

    It 'exits 0 with RESULT=OK and really writes the managed files' {
        $script:R.ExitCode | Should -Be 0
        $script:R.OutputText | Should -Match 'RESULT=OK'
        @(Get-TaggedLines -Output $script:R.Output -Tag '[WRITE]').Count | Should -BeGreaterThan 0
        (Get-FileHash -LiteralPath (Join-Path $case.ClaudeDir 'CLAUDE.md')).Hash | Should -Be (Get-FileHash -LiteralPath (Join-Path (Get-RepoRoot) 'claude\CLAUDE.md')).Hash
        (Get-FileHash -LiteralPath (Join-Path $case.DshDir 'AGENTS.md')).Hash | Should -Be (Get-FileHash -LiteralPath (Join-Path (Get-RepoRoot) 'dsh\AGENTS.md')).Hash
    }

    It 'never emits a delete tag, and reports the live-only surface as STALE instead' {
        $script:R.OutputText | Should -Not -Match '\[DELETE\]' -Because 'this build has no delete path at all'
        $stale = Get-TaggedLines -Output $script:R.Output -Tag '[STALE]'
        @($stale | Where-Object { $_ -like ('*' + $script:StrayFile) }).Count | Should -BeGreaterThan 0 -Because 'stale.md is live-only and must be named'
        @($stale | Where-Object { $_ -like ('*' + $script:EmptyDir + ' (dir)') }).Count | Should -BeGreaterThan 0 -Because 'an empty live-only directory is stale too'
        $m = [regex]::Match($script:R.OutputText, 'planned=(\d+) stale=(\d+) preserve=(\d+)')
        $m.Success | Should -BeTrue
        [int]$m.Groups[2].Value | Should -Be @($stale).Count -Because 'the counter and the printed rows must agree'
    }

    It 'leaves every live-only file and directory on disk, byte for byte' {
        (Test-Path -LiteralPath $script:StrayFile) | Should -BeTrue
        (Get-FileHash -LiteralPath $script:StrayFile).Hash | Should -Be $script:StrayBefore
        (Test-Path -LiteralPath (Join-Path $script:LiveDir 'mine.md')) | Should -BeTrue
        (Get-FileHash -LiteralPath (Join-Path $script:LiveDir 'mine.md')).Hash | Should -Be $script:LiveDirFileBefore
        (Test-Path -LiteralPath $script:EmptyDir) | Should -BeTrue
        # the seeded keep-local-only samples must be untouched as well
        (Test-Path -LiteralPath (Join-Path $case.ClaudeDir 'workflow\archive\old\e.md')) | Should -BeTrue
        (Test-Path -LiteralPath (Join-Path $case.ClaudeDir 'workflow\AGENTS.md.bak-20260101-000000')) | Should -BeTrue
    }

    It 'backs an overwritten file up next to itself, holding the pre-deploy content' {
        $backups = @(Get-ChildItem -LiteralPath $case.ClaudeDir -Filter 'CLAUDE.md.bak-*' -File)
        $backups.Count | Should -Be 1 -Because 'CLAUDE.md was the only stale managed file in this case'
        (Get-Content -LiteralPath $backups[0].FullName -Raw).Trim() | Should -Be 'stale managed file'
        $backups[0].Name | Should -Match '^CLAUDE\.md\.bak-\d{8}-\d{6}-[0-9a-f]{4}$' -Because 'the backup name must carry a per-run stamp and a guid suffix'
    }

    It 'does not touch machine-local files: no write, no backup' {
        (Get-FileHash -LiteralPath (Join-Path $case.ClaudeDir 'settings.local.json')).Hash | Should -Be $script:MachineLocalBefore
        @(Get-ChildItem -LiteralPath $case.ClaudeDir -Filter 'settings.local.json.bak-*' -File).Count | Should -Be 0
        @(Get-ChildItem -LiteralPath $case.DshDir -Filter '.credentials.yaml.bak-*' -File).Count | Should -Be 0
        (Get-Content -LiteralPath (Join-Path $case.DshDir '.credentials.yaml') -Raw) | Should -Match 'do-not-copy'
    }

    It 'keeps a seed-only config.toml as it is, and says so' {
        (Get-Content -LiteralPath (Join-Path $case.CodexDir 'config.toml') -Raw) | Should -Match 'keep-me'
        $script:R.OutputText | Should -Match '\[SKIP\]'
    }

    It 'seeds config.toml from the example when it is missing (BACKLOG T-3)' {
        $missing = New-TestCase -Name 'deploy-seed' -SeedTargets
        try {
            $r = Invoke-InstallerCase -Case $missing -Arguments @('-NoPluginInstall', '-ClaudeDir', $missing.ClaudeDir, '-CodexDir', $missing.CodexDir, '-DshDir', $missing.DshDir)
            $r.ExitCode | Should -Be 0
            $r.OutputText | Should -Match '\[PLAN\]\s+seed'
            (Test-Path -LiteralPath (Join-Path $missing.CodexDir 'config.toml')) | Should -BeTrue
            (Get-FileHash -LiteralPath (Join-Path $missing.CodexDir 'config.toml')).Hash | Should -Be (Get-FileHash -LiteralPath (Join-Path (Get-RepoRoot) 'codex\config.example.toml')).Hash
        } finally { Remove-TestCase $missing }
    }

    It 'is a no-op on a second run: nothing written, nothing backed up' {
        $first = $script:R
        $first.ExitCode | Should -Be 0
        $before = @(Get-ChildItem -LiteralPath $case.Home -Recurse -Force -Filter '*.bak-*' -File | ForEach-Object FullName)
        $second = Invoke-InstallerCase -Case $case -Arguments $script:Args
        $second.ExitCode | Should -Be 0
        $second.OutputText | Should -Match 'written=0 unchanged=\d+ backups=0'
        $after = @(Get-ChildItem -LiteralPath $case.Home -Recurse -Force -Filter '*.bak-*' -File | ForEach-Object FullName)
        ($after -join "`n") | Should -Be ($before -join "`n") -Because 'a second run of the same version must not add backups'
    }

    It 'a refused plan still writes nothing at all' {
        $repoClaude = Join-Path (Get-RepoRoot) 'claude'
        $homeBefore = Get-TargetsSignature -Case $case
        $r = Invoke-InstallerCase -Case $case -Arguments @('-ClaudeDir', $repoClaude, '-CodexDir', $case.CodexDir, '-DshDir', $case.DshDir)
        $r.ExitCode | Should -Not -Be 0
        $r.OutputText | Should -Match 'RESULT=FAILED'
        $r.OutputText | Should -Match 'target-inside-source-tree FAIL'
        @(Get-TaggedLines -Output $r.Output -Tag '[WRITE]').Count | Should -Be 0
        (Get-TargetsSignature -Case $case) | Should -Be $homeBefore
    }
}

Describe 'Deploy - the plugin step (offline, through a recording shim on PATH)' {
    BeforeEach {
        $case = New-TestCase -Name 'deploy-plugins' -SeedTargets -SeedConfigToml
        $script:Args = @('-ClaudeDir', $case.ClaudeDir, '-CodexDir', $case.CodexDir, '-DshDir', $case.DshDir)
    }
    AfterEach { Remove-TestCase $case }

    It 'installs every plugin that claude/settings.json enables, one call each' {
        $r = Invoke-InstallerCase -Case $case -Arguments $script:Args
        $r.ExitCode | Should -Be 0
        $calls = @(Get-Content -LiteralPath $case.ShimLog -ErrorAction SilentlyContinue)
        $expected = @(Get-ExpectedPlugins | ForEach-Object { 'plugin install {0}@claude-plugins-official' -f $_ })
        @($calls).Count | Should -Be $expected.Count -Because 'one CLI call per enabled plugin, no more'
        (($calls | Sort-Object) -join '|') | Should -Be (($expected | Sort-Object) -join '|')
        $r.OutputText | Should -Match ('plugins: installed={0} skipped=0 manual=0 failed=0' -f $expected.Count)
    }

    It 'announces each install before it starts, so a stall is attributable' {
        $r = Invoke-InstallerCase -Case $case -Arguments $script:Args
        $r.ExitCode | Should -Be 0
        foreach ($name in @(Get-ExpectedPlugins)) {
            $r.OutputText | Should -Match ('\[PLUGIN\]\s+installing {0}@claude-plugins-official \(timeout \d+s' -f [regex]::Escape($name))
        }
    }

    It 'kills an install that stalls past the timeout and reports it as failed (measured 2026-09-15)' {
        $shim = Join-Path $case.ShimDir 'claude.cmd'
        Set-Content -Path $shim -Value ("@echo off`r`necho %*>>`"$($case.ShimLog)`"`r`nping -n 20 127.0.0.1 >nul`r`nexit /b 0") -Encoding ascii
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $r = Invoke-InstallerCase -Case $case -Arguments $script:Args -PluginTimeoutSec 2
        $sw.Stop()
        $r.ExitCode | Should -Be 1
        $r.OutputText | Should -Match 'TIMEOUT after 2s'
        $r.OutputText | Should -Match 'plugins: installed=0 skipped=0 manual=0 failed=6'
        $sw.Elapsed.TotalSeconds | Should -BeLessThan 60 -Because 'the timeout must stop the run instead of hanging it'
        (Get-FileHash -LiteralPath (Join-Path $case.ClaudeDir 'CLAUDE.md')).Hash | Should -Be (Get-FileHash -LiteralPath (Join-Path (Get-RepoRoot) 'claude\CLAUDE.md')).Hash -Because 'the file face is deployed before the plugin step'
    }

    It '-NoPluginInstall skips the CLI entirely and says so' {
        $r = Invoke-InstallerCase -Case $case -Arguments (@('-NoPluginInstall') + $script:Args)
        $r.ExitCode | Should -Be 0
        @(Get-Content -LiteralPath $case.ShimLog -ErrorAction SilentlyContinue).Count | Should -Be 0 -Because 'a skipped plugin step must not touch the CLI'
        $r.OutputText | Should -Match 'plugins: installed=0 skipped=6 manual=0 failed=0'
        $r.OutputText | Should -Match 'SKIPPED by -NoPluginInstall'
    }

    It 'a missing claude CLI prints the manual commands instead of failing' {
        $r = Invoke-InstallerCase -Case $case -Arguments $script:Args -WithoutClaudeCli
        $r.ExitCode | Should -Be 0 -Because 'an absent CLI is an environment fact, not a deployment failure'
        $r.OutputText | Should -Match 'NOT INSTALLED - run manually: claude plugin install context7@claude-plugins-official'
        $r.OutputText | Should -Match 'plugins: installed=0 skipped=0 manual=6 failed=0'
        @(Get-Content -LiteralPath $case.ShimLog -ErrorAction SilentlyContinue).Count | Should -Be 0
        (Get-FileHash -LiteralPath (Join-Path $case.ClaudeDir 'CLAUDE.md')).Hash | Should -Be (Get-FileHash -LiteralPath (Join-Path (Get-RepoRoot) 'claude\CLAUDE.md')).Hash -Because 'the file face must still be deployed'
    }

    It 'a failing plugin install is reported as FAILED with the file counts kept' {
        $shim = Join-Path $case.ShimDir 'claude.cmd'
        Set-Content -Path $shim -Value ("@echo off`r`necho %*>>`"$($case.ShimLog)`"`r`nexit /b 3") -Encoding ascii
        $r = Invoke-InstallerCase -Case $case -Arguments $script:Args
        $r.ExitCode | Should -Be 1
        $r.OutputText | Should -Match 'FAILED \(exit 3\)'
        $r.OutputText | Should -Match 'plugins: installed=0 skipped=0 manual=0 failed=6'
        $r.OutputText | Should -Match 'written=\d+'
    }
}

Describe 'Deploy - -RemoveStale is the only delete path, and it is opt-in' {
    BeforeEach {
        $case = New-TestCase -Name 'deploy-stale' -SeedTargets -SeedConfigToml
        $script:Args = @('-ClaudeDir', $case.ClaudeDir, '-CodexDir', $case.CodexDir, '-DshDir', $case.DshDir)
        $script:StaleFile = Join-Path $case.ClaudeDir 'workflow\stray.md'
        $script:StaleDir = Join-Path $case.ClaudeDir 'workflow\empty-live-only'
        New-Item -ItemType Directory -Force $script:StaleDir | Out-Null
    }
    AfterEach { Remove-TestCase $case }

    It 'without the switch nothing stale is deleted, and no delete tag appears' {
        $r = Invoke-InstallerCase -Case $case -Arguments $script:Args
        $r.ExitCode | Should -Be 0
        (Test-Path -LiteralPath $script:StaleFile) | Should -BeTrue
        (Test-Path -LiteralPath $script:StaleDir) | Should -BeTrue
        $r.OutputText | Should -Not -Match '\[REMOVED\]'
    }

    It 'with the switch it deletes exactly the stale rows and never a keep-local-only path' {
        $r = Invoke-InstallerCase -Case $case -Arguments (@('-RemoveStale') + $script:Args)
        $r.ExitCode | Should -Be 0
        (Test-Path -LiteralPath $script:StaleFile) | Should -BeFalse
        (Test-Path -LiteralPath $script:StaleDir) | Should -BeFalse -Because 'an empty live-only directory is part of the stale set'
        $r.OutputText | Should -Match 'stale-removed: files=1 dirs=1'
        (Test-Path -LiteralPath (Join-Path $case.ClaudeDir 'workflow\archive\old\e.md')) | Should -BeTrue -Because 'keep-local-only content is never in the stale set'
        (Test-Path -LiteralPath (Join-Path $case.ClaudeDir 'workflow\AGENTS.md.bak-20260101-000000')) | Should -BeTrue
        (Get-Content -LiteralPath (Join-Path $case.DshDir '.credentials.yaml') -Raw) | Should -Match 'do-not-copy'
        (Get-FileHash -LiteralPath (Join-Path $case.ClaudeDir 'CLAUDE.md')).Hash | Should -Be (Get-FileHash -LiteralPath (Join-Path (Get-RepoRoot) 'claude\CLAUDE.md')).Hash -Because 'the deploy half still runs'
    }

    It 'a non-empty stale directory is left alone instead of being removed recursively' {
        $nested = Join-Path $case.ClaudeDir 'workflow\live-only\nested'
        New-Item -ItemType Directory -Force $nested | Out-Null
        Set-Content -Path (Join-Path $nested 'mine.md') -Value 'live-only' -Encoding ascii
        # make the directory survive the file sweep: a whitelisted file below it keeps the PARENT
        New-Item -ItemType Directory -Force (Join-Path $nested 'archive') | Out-Null
        Set-Content -Path (Join-Path $nested 'archive\e.md') -Value 'evidence' -Encoding ascii
        $r = Invoke-InstallerCase -Case $case -Arguments (@('-RemoveStale') + $script:Args)
        $r.ExitCode | Should -Be 0
        (Test-Path -LiteralPath (Join-Path $nested 'archive\e.md')) | Should -BeTrue
        $r.OutputText | Should -Not -Match 'SKIPPED \(not empty\)' -Because 'a directory holding preserved content is never in the stale set in the first place'
    }
}

Describe 'Deploy - -DryRun previews what a deploy would write' {
    It 'lists one [DIFF] row per differing managed file and writes nothing' {
        $case = New-TestCase -Name 'deploy-preview' -SeedTargets -SeedConfigToml
        try {
            $before = Get-TargetsSignature -Case $case
            $r = Invoke-InstallerCase -Case $case -Arguments @('-DryRun', '-ClaudeDir', $case.ClaudeDir, '-CodexDir', $case.CodexDir, '-DshDir', $case.DshDir)
            $r.ExitCode | Should -Be 0
            $diffs = @(Get-TaggedLines -Output $r.Output -Tag '[DIFF]')
            @($diffs | Where-Object { $_ -like ('*' + (Join-Path $case.ClaudeDir 'CLAUDE.md')) }).Count | Should -Be 1 -Because 'the seeded CLAUDE.md differs from the source tree'
            $r.OutputText | Should -Match 'would-write=\d+ unchanged=\d+'
            (Get-TargetsSignature -Case $case) | Should -Be $before
        } finally { Remove-TestCase $case }
    }

    It 'previews exactly the files a deploy then writes (same pair expansion)' {
        $case = New-TestCase -Name 'deploy-preview-match' -SeedTargets -SeedConfigToml
        try {
            $targets = @('-ClaudeDir', $case.ClaudeDir, '-CodexDir', $case.CodexDir, '-DshDir', $case.DshDir)
            $preview = Invoke-InstallerCase -Case $case -Arguments (@('-DryRun') + $targets)
            $deploy = Invoke-InstallerCase -Case $case -Arguments (@('-NoPluginInstall', '-RemoveStale') + $targets)
            $diffPaths = @(Get-TaggedLines -Output $preview.Output -Tag '[DIFF]' | ForEach-Object { $_.Substring('[DIFF]'.Length).Trim() } | Sort-Object)
            $writePaths = @(Get-TaggedLines -Output $deploy.Output -Tag '[WRITE]' | ForEach-Object { $_.Substring('[WRITE]'.Length).Trim() } | Sort-Object)
            ($writePaths -join '|') | Should -Be ($diffPaths -join '|') -Because 'the preview and the writer must agree, file for file'
        } finally { Remove-TestCase $case }
    }

    It 'warns when the plan would be refused instead of silently looking green (BACKLOG B-7)' {
        $case = New-TestCase -Name 'deploy-preview-warn' -FakeRepo -IncompleteSourceTree
        try {
            $before = Get-TargetsSignature -Case $case
            $r = Invoke-InstallerCase -Case $case -Arguments @('-DryRun', '-ClaudeDir', $case.ClaudeDir, '-CodexDir', $case.CodexDir, '-DshDir', $case.DshDir)
            $r.ExitCode | Should -Be 0 -Because 'a dry run does not gate'
            $r.OutputText | Should -Match 'RESULT=OK'
            $r.OutputText | Should -Match '\[CHECK\].*FAIL'
            $r.OutputText | Should -Match '\[WARN\].*would be refused'
            (Get-TargetsSignature -Case $case) | Should -Be $before
        } finally { Remove-TestCase $case }
    }

    It 'a valid plan prints no warning at all (the warning discriminates)' {
        $case = New-TestCase -Name 'deploy-preview-clean' -SeedTargets -SeedConfigToml
        try {
            $r = Invoke-InstallerCase -Case $case -Arguments @('-DryRun', '-ClaudeDir', $case.ClaudeDir, '-CodexDir', $case.CodexDir, '-DshDir', $case.DshDir)
            $r.ExitCode | Should -Be 0
            $r.OutputText | Should -Not -Match '\[WARN\]'
        } finally { Remove-TestCase $case }
    }
}

Describe 'Deploy - the plan follows dsh/skills instead of a hard-coded bundle list' {
    It 'picks up a third bundle that exists in the source tree, and deploys it' {
        $case = New-TestCase -Name 'deploy-third-skill' -FakeRepo -SeedTargets -SeedConfigToml
        try {
            $third = Join-Path $case.RepoRoot 'dsh\skills\third-bundle'
            New-Item -ItemType Directory -Force $third | Out-Null
            Set-Content -Path (Join-Path $third 'SKILL.md') -Value '# third bundle' -Encoding ascii
            $targets = @('-ClaudeDir', $case.ClaudeDir, '-CodexDir', $case.CodexDir, '-DshDir', $case.DshDir)

            $plan = Invoke-InstallerCase -Case $case -Arguments (@('-DryRun') + $targets)
            $plan.ExitCode | Should -Be 0
            $plan.OutputText | Should -Match ([regex]::Escape((Join-Path $case.DshDir 'skills\third-bundle'))) -Because 'a hard-coded two-bundle list would silently ignore this one'

            $r = Invoke-InstallerCase -Case $case -Arguments (@('-NoPluginInstall') + $targets)
            $r.ExitCode | Should -Be 0
            (Test-Path -LiteralPath (Join-Path $case.DshDir 'skills\third-bundle\SKILL.md')) | Should -BeTrue
        } finally { Remove-TestCase $case }
    }
}

Describe 'Deploy - a source tree that itself carries a *.bak-* directory (PROBE-D regression)' {
    It 'still reports the live-only files below it as PRESERVE, not STALE' {
        $case = New-TestCase -Name 'deploy-bakdir' -FakeRepo -SeedTargets -SeedConfigToml
        try {
            # the SOURCE tree ships a *.bak-* directory ...
            $srcBak = Join-Path $case.RepoRoot 'claude\workflow\old.bak-20260101-000000'
            New-Item -ItemType Directory -Force $srcBak | Out-Null
            Set-Content -Path (Join-Path $srcBak 'src.md') -Value 'source-side legacy backup dir' -Encoding ascii
            # ... and the TARGET has a machine-local file inside the same-named directory
            $tgtBak = Join-Path $case.ClaudeDir 'workflow\old.bak-20260101-000000'
            New-Item -ItemType Directory -Force $tgtBak | Out-Null
            Set-Content -Path (Join-Path $tgtBak 'local-only.md') -Value 'machine-local, must survive' -Encoding ascii

            $r = Invoke-InstallerCase -Case $case -Arguments @('-DryRun', '-ClaudeDir', $case.ClaudeDir, '-CodexDir', $case.CodexDir, '-DshDir', $case.DshDir)
            $r.ExitCode | Should -Be 0
            $preserve = Get-TaggedLines -Output $r.Output -Tag '[PRESERVE]'
            $stale = Get-TaggedLines -Output $r.Output -Tag '[STALE]'
            @($preserve | Where-Object { $_ -like ('*' + (Join-Path $tgtBak 'local-only.md')) }).Count | Should -BeGreaterThan 0 -Because 'the *.bak-* SEGMENT is keep-local-only wherever it appears, source tree or not'
            @($stale | Where-Object { $_ -like ('*old.bak-20260101-000000*') }).Count | Should -Be 0
        } finally { Remove-TestCase $case }
    }
}

Describe 'Deploy - completeness into an empty home (ported from the stopped H3 branch)' {
    It 'lands exactly the managed surface, file for file, with the source content' {
        # No -SeedTargets: the three targets start out empty, so "what ends up there" is the
        # deploy's own doing and any extra file is a real finding.
        $fresh = New-TestCase -Name 'deploy-full-surface'
        try {
            $r = Invoke-InstallerCase -Case $fresh -Arguments @('-NoPluginInstall', '-ClaudeDir', $fresh.ClaudeDir, '-CodexDir', $fresh.CodexDir, '-DshDir', $fresh.DshDir)
            $r.ExitCode | Should -Be 0
            $expected = @(Get-ManagedDeploySet -RepoRoot (Get-RepoRoot)) + 'codex/config.toml'

            $missing = New-Object System.Collections.Generic.List[string]
            $mismatch = New-Object System.Collections.Generic.List[string]
            foreach ($rel in $expected) {
                $target = switch -Regex ($rel) {
                    '^claude/' { Join-Path $fresh.ClaudeDir $rel.Substring(7) }
                    '^codex/' { Join-Path $fresh.CodexDir $rel.Substring(6) }
                    '^dsh/' { Join-Path $fresh.DshDir $rel.Substring(4) }
                }
                if (-not (Test-Path -LiteralPath $target -PathType Leaf)) { $missing.Add($rel); continue }
                $source = switch -Regex ($rel) {
                    '^claude/' { Join-Path (Get-RepoRoot) ('claude\' + $rel.Substring(7)) }
                    '^codex/config\.toml$' { Join-Path (Get-RepoRoot) 'codex\config.example.toml' }
                    '^codex/' { Join-Path (Get-RepoRoot) ('codex\' + $rel.Substring(6)) }
                    '^dsh/' { Join-Path (Get-RepoRoot) ('dsh\' + $rel.Substring(4)) }
                }
                if ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash) { $mismatch.Add($rel) }
            }
            ($missing -join ', ') | Should -Be '' -Because 'a deploy must land every file the managed surface declares'
            ($mismatch -join ', ') | Should -Be '' -Because 'every landed file must hold the source content'

            $found = New-Object System.Collections.Generic.List[string]
            foreach ($pair in @(@($fresh.ClaudeDir, 'claude'), @($fresh.CodexDir, 'codex'), @($fresh.DshDir, 'dsh'))) {
                if (-not (Test-Path -LiteralPath $pair[0])) { continue }
                foreach ($f in Get-ChildItem -LiteralPath $pair[0] -File -Recurse -Force) {
                    $found.Add($pair[1] + '/' + $f.FullName.Substring($pair[0].Length + 1).Replace('\', '/'))
                }
            }
            # the seed-only config.toml is the only managed file that is not mirrored from dsh/codex sources
            (($found | Sort-Object -Unique) -join "`n") | Should -Be (($expected | Sort-Object -Unique) -join "`n") -Because 'an empty home must end up holding the managed surface and nothing else'
        } finally { Remove-TestCase $fresh }
    }
}

Describe 'Deploy - the shipped installer stays ASCII-only (PowerShell 5.1 reads -File with the ANSI code page)' {
    It 'install.ps1 has no non-ASCII byte, and the probe is able to see one' {
        $installer = Join-Path (Get-RepoRoot) 'install.ps1'
        $raw = Get-Content -Raw -LiteralPath $installer
        ($raw -match '[^\x00-\x7F]') | Should -BeFalse -Because 'a non-ASCII byte would come out as mojibake under Windows PowerShell 5.1'

        # Negative control: the same predicate must fire on a copy with one injected byte,
        # otherwise "no non-ASCII" would pass even if the check were broken.
        $probeDir = New-TempDirectory -Prefix 'ascii-probe'
        try {
            $probe = Join-Path $probeDir 'install.ps1'
            Set-Content -LiteralPath $probe -Value ($raw + "`n# caf" + [char]0x00E9 + "`n") -Encoding utf8NoBOM
            ((Get-Content -Raw -LiteralPath $probe) -match '[^\x00-\x7F]') | Should -BeTrue -Because 'the probe must be able to detect a non-ASCII byte at all'
        } finally { Remove-Item -LiteralPath $probeDir -Recurse -Force }
    }
}
