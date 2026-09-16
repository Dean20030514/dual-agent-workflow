# AC3 - -ValidateOnly: reproducible verdicts, names the failing item, and the SAME predicate gates deployment.

BeforeAll { . "$PSScriptRoot/TestHelpers.ps1" }

Describe 'AC3 -ValidateOnly' {
    Context 'with a temp fake repository' {
        BeforeEach {
            $case = New-TestCase -Name 'validate' -FakeRepo
            $script:RepoBefore = Get-TreeSignature $case.RepoRoot
            $script:HomeBefore = Get-TargetsSignature -Case $case
        }
        AfterEach { Remove-TestCase $case }

        It 'case 1: a complete source tree passes (exit 0)' {
            $r = Invoke-InstallerCase -Case $case -Arguments @('-ValidateOnly', '-ClaudeDir', $case.ClaudeDir, '-CodexDir', $case.CodexDir, '-DshDir', $case.DshDir)
            $r.ExitCode | Should -Be 0
            $r.OutputText | Should -Match 'RESULT=OK \(validate only'
        }

        It 'case 1b: -ValidateOnly reports the same action count as -DryRun (Amendment ㉚)' {
            $v = Invoke-InstallerCase -Case $case -Arguments @('-ValidateOnly', '-ClaudeDir', $case.ClaudeDir, '-CodexDir', $case.CodexDir, '-DshDir', $case.DshDir)
            $d = Invoke-InstallerCase -Case $case -Arguments @('-DryRun', '-ClaudeDir', $case.ClaudeDir, '-CodexDir', $case.CodexDir, '-DshDir', $case.DshDir)
            $mv = [regex]::Match($v.OutputText, 'planned=(\d+)')
            $md = [regex]::Match($d.OutputText, 'planned=(\d+)')
            $mv.Success | Should -BeTrue
            $md.Success | Should -BeTrue
            [int]$mv.Groups[1].Value | Should -BeGreaterThan 0 -Because 'validate-only must report the real action count, not a constant zero'
            [int]$mv.Groups[1].Value | Should -Be ([int]$md.Groups[1].Value) -Because 'the counters are mode independent'
        }

        It 'case 3 (K9-3): a root that exists as a FILE is refused and named' {
            $file = Join-Path $case.Root 'a-file'; Set-Content -Path $file -Value 'not a directory' -Encoding ascii
            $r = Invoke-InstallerCase -Case $case -Arguments @('-ValidateOnly', '-ClaudeDir', $file, '-CodexDir', $case.CodexDir, '-DshDir', $case.DshDir)
            $r.ExitCode | Should -Not -Be 0; $r.OutputText | Should -Match ([regex]::Escape($file))
        }

        It 'case 4 (K9-5 trailing separator): two spellings of the same root are still a conflict, both parameters named' {
            $shared = Join-Path $case.Root 'shared'
            $r = Invoke-InstallerCase -Case $case -Arguments @('-ValidateOnly', '-ClaudeDir', $shared, '-CodexDir', ($shared + '\'), '-DshDir', $case.DshDir)
            $r.ExitCode | Should -Not -Be 0
            $r.OutputText | Should -Match '-ClaudeDir'; $r.OutputText | Should -Match '-CodexDir'
        }

        It 'case 5 (K9-6): a target inside the source tree is refused and named' {
            $r = Invoke-InstallerCase -Case $case -Arguments @('-ValidateOnly', '-ClaudeDir', (Join-Path $case.RepoRoot 'claude'), '-CodexDir', $case.CodexDir, '-DshDir', $case.RepoRoot)
            $r.ExitCode | Should -Not -Be 0; $r.OutputText | Should -Match 'target-inside-source-tree FAIL'
        }

        It 'case 6 (machine-local containment): a target INSIDE a machine-local path is refused' {
            New-Item -ItemType Directory -Force (Join-Path $case.Home '.claude\projects') | Out-Null
            $r = Invoke-InstallerCase -Case $case -Arguments @('-ValidateOnly', '-ClaudeDir', (Join-Path $case.Home '.claude\projects'), '-CodexDir', $case.CodexDir, '-DshDir', $case.DshDir)
            $r.ExitCode | Should -Not -Be 0; $r.OutputText | Should -Match 'machine-local-untouched FAIL'
        }

        It 'case 6b: a sibling that merely STARTS with the same text is NOT a machine-local hit' {
            New-Item -ItemType Directory -Force (Join-Path $case.Home '.claude\projects-x') | Out-Null
            $r = Invoke-InstallerCase -Case $case -Arguments @('-ValidateOnly', '-ClaudeDir', (Join-Path $case.Home '.claude\projects-x'), '-CodexDir', $case.CodexDir, '-DshDir', $case.DshDir)
            $r.ExitCode | Should -Be 0 -Because 'containment is segment based, not prefix based'
        }

        It 'case 7: the deploy form of a refused plan writes nothing' {
            $r = Invoke-InstallerCase -Case $case -Arguments @('-ClaudeDir', (Join-Path $case.RepoRoot 'claude'), '-CodexDir', $case.CodexDir, '-DshDir', $case.RepoRoot)
            $r.ExitCode | Should -Not -Be 0
            (Get-TreeSignature $case.RepoRoot) | Should -Be $script:RepoBefore
            (Get-TargetsSignature -Case $case) | Should -Be $script:HomeBefore
        }
    }

    It 'case 2: a missing source file is refused and named' {
        $case = New-TestCase -Name 'validate-missing' -FakeRepo -IncompleteSourceTree
        try {
            $missing = Join-Path $case.RepoRoot 'claude\settings.json'
            Test-Path -LiteralPath $missing | Should -BeFalse
            $r = Invoke-InstallerCase -Case $case -Arguments @('-ValidateOnly', '-ClaudeDir', $case.ClaudeDir, '-CodexDir', $case.CodexDir, '-DshDir', $case.DshDir)
            $r.ExitCode | Should -Not -Be 0; $r.OutputText | Should -Match ([regex]::Escape($missing))
        } finally { Remove-TestCase $case }
    }

    It 'case 8 (Amendment ㉚ / review 9B round 2 BL-1): -ValidateOnly reports the same three counters as -DryRun, and they are not structural zeros' {
        $case = New-TestCase -Name 'validate-counters' -SeedTargets -SeedConfigToml
        try {
            $targets = @('-ClaudeDir', $case.ClaudeDir, '-CodexDir', $case.CodexDir, '-DshDir', $case.DshDir)
            $v = Invoke-InstallerCase -Case $case -Arguments (@('-ValidateOnly') + $targets)
            $d = Invoke-InstallerCase -Case $case -Arguments (@('-DryRun') + $targets)
            $mv = [regex]::Match($v.OutputText, 'planned=(\d+) stale=(\d+) preserve=(\d+)')
            $md = [regex]::Match($d.OutputText, 'planned=(\d+) stale=(\d+) preserve=(\d+)')
            $mv.Success | Should -BeTrue
            $md.Success | Should -BeTrue
            foreach ($i in 1..3) {
                [int]$mv.Groups[$i].Value | Should -Be ([int]$md.Groups[$i].Value) -Because 'all three counters are mode independent (one Get-PlanCounters before the mode branches)'
            }
            [int]$mv.Groups[2].Value | Should -BeGreaterThan 0 -Because 'the seeded tree has a live-only stray.md, so validate must not report a structural stale=0'
            [int]$md.Groups[2].Value | Should -Be (@(Get-TaggedLines -Output $d.Output -Tag '[STALE]').Count) -Because 'the counter and the printed rows come from the same delta'
        } finally { Remove-TestCase $case }
    }

    It 'case 9 (K9-4): a target whose PARENT is a file is refused and named' {
        $case = New-TestCase -Name 'validate-parentfile' -FakeRepo
        try {
            $file = Join-Path $case.Root 'afile'
            Set-Content -Path $file -Value 'not a directory' -Encoding ascii
            $child = Join-Path $file 'sub'
            $r = Invoke-InstallerCase -Case $case -Arguments @('-ValidateOnly', '-ClaudeDir', $child, '-CodexDir', $case.CodexDir, '-DshDir', $case.DshDir)
            $r.ExitCode | Should -Not -Be 0 -Because 'a target whose ancestor is a file can never be created'
            $r.OutputText | Should -Match ([regex]::Escape($file)) -Because 'the check must name the offending ancestor'
        } finally { Remove-TestCase $case }
    }

    It 'case 10 (AC3-7 tail separator, DEPLOY form): the conflict is refused without -ValidateOnly and the predicate is named' {
        $case = New-TestCase -Name 'deploy-sep' -FakeRepo
        try {
            $shared = Join-Path $case.Root 'shared'
            New-Item -ItemType Directory -Force $shared | Out-Null
            $before = Get-TreeSignature $case.RepoRoot
            $r = Invoke-InstallerCase -Case $case -Arguments @('-ClaudeDir', $shared, '-CodexDir', ($shared + '\'), '-DshDir', $case.DshDir)
            $r.ExitCode | Should -Not -Be 0
            $r.OutputText | Should -Match '-ClaudeDir'
            $r.OutputText | Should -Match '-CodexDir'
            $r.OutputText | Should -Match '\[CHECK\].*FAIL' -Because 'the deploy path must run the same predicate and its FAIL line must be on screen - that is what shows the verdict drove the exit code'
            $r.OutputText | Should -Match 'RESULT=FAILED' -Because 'review 9A round 3 NB-2: both FAILED and REFUSED exit 1, so the summary token is what proves the deploy path consumed the predicate verdict rather than always refusing'
            (Get-TreeSignature $case.RepoRoot) | Should -Be $before
        } finally { Remove-TestCase $case }
    }

    It 'case 11 (AC3-7 machine-local, DEPLOY form): a target inside a machine-local path is refused and named' {
        $case = New-TestCase -Name 'deploy-ml' -FakeRepo
        try {
            New-Item -ItemType Directory -Force (Join-Path $case.Home '.claude\projects') | Out-Null
            $r = Invoke-InstallerCase -Case $case -Arguments @('-ClaudeDir', (Join-Path $case.Home '.claude\projects'), '-CodexDir', $case.CodexDir, '-DshDir', $case.DshDir)
            $r.ExitCode | Should -Not -Be 0
            $r.OutputText | Should -Match 'machine-local-untouched FAIL'
            $r.OutputText | Should -Match '\[CHECK\].*FAIL'
        } finally { Remove-TestCase $case }
    }

    It 'case 12 (review 9B round 3 BL-1): a mirror target that exists as a FILE is named by the predicate, not crashed on' {
        $case = New-TestCase -Name 'target-is-file' -FakeRepo
        try {
            New-Item -ItemType Directory -Force $case.ClaudeDir | Out-Null
            Set-Content -Path (Join-Path $case.ClaudeDir 'rules') -Value 'a file where a directory is expected' -Encoding ascii
            $targets = @('-ClaudeDir', $case.ClaudeDir, '-CodexDir', $case.CodexDir, '-DshDir', $case.DshDir)
            foreach ($mode in @(@('-ValidateOnly'), @())) {
                $r = Invoke-InstallerCase -Case $case -Arguments ($mode + $targets)
                $r.ExitCode | Should -Not -Be 0
                $r.OutputText | Should -Not -Match 'startIndex cannot be larger' -Because 'the run must not die with a raw Substring exception before any check can speak'
                $r.OutputText | Should -Match 'target exists as a file but a directory is required' -Because 'the shape failure must be named with the offending path'
                $r.OutputText | Should -Match '\[SUMMARY\]' -Because 'the summary line must survive the refusal'
                $r.OutputText | Should -Match 'RESULT=FAILED'
            }
        } finally { Remove-TestCase $case }
    }
}