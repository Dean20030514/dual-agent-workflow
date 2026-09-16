# AC1 - the parameter surface must fail at BINDING time, with zero side effects.
# Frozen input domain K1-K9 lives in docs/ai/TASK_BRIEF.md; the samples below are
# taken from it. Every case runs inside an isolated child process whose interlock
# (inside the child) refuses anything that would touch the real home.

BeforeAll {
    . "$PSScriptRoot/TestHelpers.ps1"
    # Diagnostic family for binding failures. This machine's UI is Chinese, so the
    # English wording alone would never match (Pre-Flight finding, see HANDOFF).
    $script:BindingPattern = 'matches parameter name|parameter cannot be found|Parameter set cannot be resolved|无法使用指定的命名参数解析参数集|找不到与参数名称|找不到接受自变量'
}

Describe 'AC1 parameter surface (binding-time rejection, zero side effects)' {

    BeforeEach {
        $case = New-TestCase -Name 'params' -SeedTargets -SeedConfigToml
        $script:Before = Get-TargetsSignature -Case $case
    }
    AfterEach {
        Remove-TestCase $case
    }

    It 'K2 pair baseline: -DryRun with explicit temp targets exits 0 and writes nothing' {
        $r = Invoke-InstallerCase -Case $case -Arguments @('-DryRun', '-ClaudeDir', $case.ClaudeDir, '-CodexDir', $case.CodexDir, '-DshDir', $case.DshDir)
        $r.ExitCode | Should -Be 0 -Because 'the paired pass sample must pass for the failures to mean anything'
        $r.SentinelExists | Should -BeTrue
        (Get-TargetsSignature -Case $case) | Should -Be $script:Before
    }

    It 'K3 independent pass sample: -ValidateOnly with explicit temp targets exits 0 and writes nothing' {
        $r = Invoke-InstallerCase -Case $case -Arguments @('-ValidateOnly', '-ClaudeDir', $case.ClaudeDir, '-CodexDir', $case.CodexDir, '-DshDir', $case.DshDir)
        $r.ExitCode | Should -Be 0
        $r.SentinelExists | Should -BeTrue
        (Get-TargetsSignature -Case $case) | Should -Be $script:Before
    }

    It 'K4a: the removed acknowledgement switch fails at binding and writes nothing' {
        $r = Invoke-InstallerCase -Case $case -Arguments @('-IUnderstandThisReplacesLiveConfig')
        $r.ExitCode | Should -Not -Be 0
        $r.OutputText | Should -Match 'IUnderstandThisReplacesLiveConfig'
        $r.OutputText | Should -Match $script:BindingPattern
        (Get-TargetsSignature -Case $case) | Should -Be $script:Before
    }

    It 'K4b: the :$false form of the removed switch also fails at binding' {
        $r = Invoke-InstallerCase -Case $case -Arguments @('-IUnderstandThisReplacesLiveConfig:$false')
        $r.ExitCode | Should -Not -Be 0
        $r.OutputText | Should -Match $script:BindingPattern
        (Get-TargetsSignature -Case $case) | Should -Be $script:Before
    }

    It 'K5: a misspelled parameter fails at binding (typo can never be swallowed)' {
        $r = Invoke-InstallerCase -Case $case -Arguments @('-DyrRun')
        $r.ExitCode | Should -Not -Be 0
        $r.OutputText | Should -Match 'DyrRun'
        $r.OutputText | Should -Match $script:BindingPattern
        (Get-TargetsSignature -Case $case) | Should -Be $script:Before
    }

    It 'K6: a positional token fails at binding when the legacy switch follows it' {
        $r = Invoke-InstallerCase -Case $case -Arguments @('DryRun', '-IUnderstandThisReplacesLiveConfig')
        $r.ExitCode | Should -Not -Be 0
        $r.OutputText | Should -Match $script:BindingPattern
        (Get-TargetsSignature -Case $case) | Should -Be $script:Before
    }

    It 'K6 clean sample: a positional token fails even with valid path parameters (no unknown-parameter noise)' {
        $r = Invoke-InstallerCase -Case $case -Arguments @('DryRun', '-ClaudeDir', $case.ClaudeDir, '-CodexDir', $case.CodexDir, '-DshDir', $case.DshDir)
        $r.ExitCode | Should -Not -Be 0 -Because 'no parameter may carry a Position binding'
        $r.OutputText | Should -Match $script:BindingPattern
        (Get-TargetsSignature -Case $case) | Should -Be $script:Before
    }

    It 'K7: -DryRun together with -ValidateOnly fails at binding (parameter sets, not a body check)' {
        $r = Invoke-InstallerCase -Case $case -Arguments @('-DryRun', '-ValidateOnly', '-ClaudeDir', $case.ClaudeDir, '-CodexDir', $case.CodexDir, '-DshDir', $case.DshDir)
        $r.ExitCode | Should -Not -Be 0
        $r.OutputText | Should -Match $script:BindingPattern
        (Get-TargetsSignature -Case $case) | Should -Be $script:Before
    }

    It 'interlock negative control: real-home targets are refused and the installer never starts' {
        $real = @(
            (Join-Path $env:USERPROFILE '.claude'),
            (Join-Path $env:USERPROFILE '.codex'),
            (Join-Path $env:USERPROFILE '.dsh')
        )
        $r = Invoke-InstallerCase -Case $case -Arguments @('-DryRun') -OverrideTargets $real
        $r.ExitCode | Should -Be 97
        $r.OutputText | Should -Match 'INTERLOCK-FAIL'
        $r.SentinelExists | Should -BeFalse -Because 'the sentinel is written immediately before the installer is invoked'
    }
}

Describe 'AC1 K8 -NoPluginInstall belongs to all three parameter sets (Amendment ㉕)' {
    BeforeEach {
        $case = New-TestCase -Name 'k8' -SeedTargets -SeedConfigToml
        $script:Args = @('-ClaudeDir', $case.ClaudeDir, '-CodexDir', $case.CodexDir, '-DshDir', $case.DshDir)
        $script:Before = Get-TargetsSignature -Case $case
    }
    AfterEach { Remove-TestCase $case }

    It 'binds together with the DryRun set and never starts the plugin step' {
        $r = Invoke-InstallerCase -Case $case -Arguments (@('-NoPluginInstall', '-DryRun') + $script:Args)
        $r.ExitCode | Should -Be 0
        $r.OutputText | Should -Not -Match $script:BindingPattern
        (Get-TargetsSignature -Case $case) | Should -Be $script:Before
        @(Get-Content -LiteralPath $case.ShimLog -ErrorAction SilentlyContinue).Count | Should -Be 0 -Because 'slice A never executes the plugin step'
    }

    It 'binds together with the Validate set' {
        $r = Invoke-InstallerCase -Case $case -Arguments (@('-NoPluginInstall', '-ValidateOnly') + $script:Args)
        $r.ExitCode | Should -Be 0
        $r.OutputText | Should -Not -Match $script:BindingPattern
        @(Get-Content -LiteralPath $case.ShimLog -ErrorAction SilentlyContinue).Count | Should -Be 0
    }

    It 'negative control: with BOTH plan states it still fails at binding (mutual exclusion is binding-time)' {
        $r = Invoke-InstallerCase -Case $case -Arguments (@('-NoPluginInstall', '-DryRun', '-ValidateOnly') + $script:Args)
        $r.ExitCode | Should -Not -Be 0
        $r.OutputText | Should -Match $script:BindingPattern
        (Get-TargetsSignature -Case $case) | Should -Be $script:Before
    }
}

Describe 'AC1 K10 - an explicitly passed but empty root is refused (it must never fall back to the real home)' {
    BeforeEach {
        $case = New-TestCase -Name 'k10' -SeedTargets -SeedConfigToml
        $script:Args = @('-ClaudeDir', $case.ClaudeDir, '-CodexDir', $case.CodexDir, '-DshDir', $case.DshDir)
        $script:Before = Get-TargetsSignature -Case $case
    }
    AfterEach { Remove-TestCase $case }

    It 'names the parameter and exits non-zero for each of the three roots' {
        $cases = @(
            @{ Name = '-ClaudeDir'; Args = @('-ClaudeDir', '', '-CodexDir', $case.CodexDir, '-DshDir', $case.DshDir) },
            @{ Name = '-CodexDir'; Args = @('-ClaudeDir', $case.ClaudeDir, '-CodexDir', '', '-DshDir', $case.DshDir) },
            @{ Name = '-DshDir'; Args = @('-ClaudeDir', $case.ClaudeDir, '-CodexDir', $case.CodexDir, '-DshDir', '') }
        )
        foreach ($c in $cases) {
            $r = Invoke-InstallerCase -Case $case -Arguments $c.Args
            $r.ExitCode | Should -Not -Be 0 -Because "$($c.Name) was passed but empty"
            $r.OutputText | Should -Match ([regex]::Escape($c.Name)) -Because 'the failing parameter has to be named'
            $r.OutputText | Should -Match 'RESULT=FAILED'
        }
        (Get-TargetsSignature -Case $case) | Should -Be $script:Before
    }

    It 'a whitespace-only root is refused as well' {
        $r = Invoke-InstallerCase -Case $case -Arguments @('-ClaudeDir', ' ', '-CodexDir', $case.CodexDir, '-DshDir', $case.DshDir)
        $r.ExitCode | Should -Not -Be 0
        $r.OutputText | Should -Match '-ClaudeDir'
        (Get-TargetsSignature -Case $case) | Should -Be $script:Before
    }

    It 'paired control: the same argv with a real value passes, so the refusal comes from the empty value' {
        $r = Invoke-InstallerCase -Case $case -Arguments $script:Args
        $r.ExitCode | Should -Be 0
        $r.OutputText | Should -Match 'RESULT=OK'
        $r.OutputText | Should -Not -Match 'given explicitly but empty'
    }

    It 'the guard runs in all three modes, so a dry run cannot preview a real-home deploy either' {
        foreach ($mode in @('-DryRun', '-ValidateOnly')) {
            $r = Invoke-InstallerCase -Case $case -Arguments (@($mode, '-ClaudeDir', '', '-CodexDir', $case.CodexDir, '-DshDir', $case.DshDir))
            $r.ExitCode | Should -Not -Be 0 -Because "$mode must refuse the same argument"
            $r.OutputText | Should -Match 'RESULT=FAILED'
        }
        (Get-TargetsSignature -Case $case) | Should -Be $script:Before
    }
}

Describe 'AC1 K1 - the Deploy set writes (add/update only; human ruling 2026-09-15)' {
    BeforeEach {
        $case = New-TestCase -Name 'k1' -SeedTargets -SeedConfigToml
        $script:Args = @('-ClaudeDir', $case.ClaudeDir, '-CodexDir', $case.CodexDir, '-DshDir', $case.DshDir)
        $script:Before = Get-TargetsSignature -Case $case
        $script:StrayBefore = (Get-FileHash -LiteralPath (Join-Path $case.ClaudeDir 'workflow\stray.md')).Hash
    }
    AfterEach { Remove-TestCase $case }

    It 'K1a: explicit temp targets and no mode switch deploy the managed surface (exit 0, RESULT=OK)' {
        $r = Invoke-InstallerCase -Case $case -Arguments $script:Args
        $r.SentinelExists | Should -BeTrue
        $r.ExitCode | Should -Be 0 -Because 'a completed deploy is a success; the old REFUSED exit is gone'
        $r.OutputText | Should -Match 'RESULT=OK'
        $r.OutputText | Should -Not -Match $script:BindingPattern -Because 'K1 must reach the deploy path, not fail at binding'
        (Get-FileHash -LiteralPath (Join-Path $case.ClaudeDir 'CLAUDE.md')).Hash | Should -Be (Get-FileHash -LiteralPath (Join-Path (Get-RepoRoot) 'claude\CLAUDE.md')).Hash -Because 'the stale managed file must have been overwritten from the source tree'
        (Get-FileHash -LiteralPath (Join-Path $case.ClaudeDir 'workflow\stray.md')).Hash | Should -Be $script:StrayBefore -Because 'live-only content is reported as stale and never deleted'
    }

    It 'K1b: a zero-argument run deploys into the home USERPROFILE points at, and reports those roots' {
        $r = Invoke-InstallerCase -Case $case -Arguments @()
        $r.SentinelExists | Should -BeTrue
        $r.ExitCode | Should -Be 0
        $r.OutputText | Should -Match 'RESULT=OK'
        foreach ($root in @($case.ClaudeDir, $case.CodexDir, $case.DshDir)) {
            $r.OutputText | Should -Match ([regex]::Escape($root)) -Because 'the roots the installer reports must be the isolated ones, or this case proves nothing about where it wrote'
        }
        $r.OutputText | Should -Not -Match ([regex]::Escape($env:USERPROFILE + '\.claude'))
        (Test-Path -LiteralPath (Join-Path $case.ClaudeDir 'CLAUDE.md')) | Should -BeTrue -Because 'a zero-argument deploy writes inside the isolated home'
    }

    It 'K1c paired control: the same argument list with -DryRun prints the plan and writes nothing' {
        $r = Invoke-InstallerCase -Case $case -Arguments (@('-DryRun') + $script:Args)
        $r.ExitCode | Should -Be 0
        $r.OutputText | Should -Match 'RESULT=OK'
        (Get-TargetsSignature -Case $case) | Should -Be $script:Before -Because 'deploy writes and dry run does not - that contrast is what this pairing exists for'
    }
}
