# Amendment ㉔ 5.1 leg - install.ps1 must stay Windows PowerShell 5.1 compatible.
#
# The suite itself runs on pwsh 7; powershell.exe may only appear as the CHILD host.
# This file is the only place that starts the installer from powershell.exe, and it
# proves the host for every case instead of assuming it: the child wrapper reports
# "psver=<major>", so a leg that silently ran on pwsh 7 would fail here.
#
# It was previously a dead helper (Get-WindowsPowerShellPath had no caller), which
# is exactly the failure mode this leg exists to prevent (review 9B, BL-3).

BeforeAll {
    . "$PSScriptRoot/TestHelpers.ps1"
    $script:WinPs = Get-WindowsPowerShellPath
}

Describe 'Amendment ㉔ 5.1 leg - powershell.exe as the child host' {
    BeforeEach {
        $case = New-TestCase -Name 'ps51' -SeedTargets -SeedConfigToml
        $script:Args = @('-ClaudeDir', $case.ClaudeDir, '-CodexDir', $case.CodexDir, '-DshDir', $case.DshDir)
        $script:Before = Get-TargetsSignature -Case $case
    }
    AfterEach { Remove-TestCase $case }

    It 'the 5.1 host exists and really reports major version 5 (a missing host cannot no-op this leg)' {
        Test-Path -LiteralPath $script:WinPs | Should -BeTrue
        (& $script:WinPs -NoProfile -Command '[int]$PSVersionTable.PSVersion.Major') | Should -Be 5
    }

    It 'pass sample: -ValidateOnly exits 0, reports OK and writes nothing under 5.1' {
        $r = Invoke-InstallerCase -Case $case -Arguments (@('-ValidateOnly') + $script:Args) -HostExe $script:WinPs
        $r.OutputText | Should -Match 'psver=5\b'
        $r.OutputText | Should -Match ([regex]::Escape($script:WinPs)) -Because 'the child must actually be the 5.1 host, not merely claim version 5'
        $r.ExitCode | Should -Be 0
        $r.SentinelExists | Should -BeTrue
        $r.OutputText | Should -Match 'RESULT=OK'
        (Get-TargetsSignature -Case $case) | Should -Be $script:Before
    }

    It 'plan sample: -DryRun prints the delete surface and writes nothing under 5.1' {
        $r = Invoke-InstallerCase -Case $case -Arguments (@('-DryRun') + $script:Args) -HostExe $script:WinPs
        $r.OutputText | Should -Match 'psver=5\b'
        $r.ExitCode | Should -Be 0
        @(Get-TaggedLines -Output $r.Output -Tag '[DELETE]').Count | Should -BeGreaterThan 0
        $r.OutputText | Should -Match 'RESULT=OK'
        (Get-TargetsSignature -Case $case) | Should -Be $script:Before
    }

    It 'refusal sample: the Deploy set exits non-zero with RESULT=REFUSED under 5.1 (K1)' {
        $r = Invoke-InstallerCase -Case $case -Arguments $script:Args -HostExe $script:WinPs
        $r.OutputText | Should -Match 'psver=5\b'
        $r.ExitCode | Should -Not -Be 0
        $r.OutputText | Should -Match 'RESULT=REFUSED'
        (Get-TargetsSignature -Case $case) | Should -Be $script:Before
    }

    It 'binding sample: an unknown parameter is still rejected at binding under 5.1' {
        $r = Invoke-InstallerCase -Case $case -Arguments @('-DyrRun') -HostExe $script:WinPs
        $r.OutputText | Should -Match 'psver=5\b'
        $r.ExitCode | Should -Not -Be 0
        $r.OutputText | Should -Match 'DyrRun' -Because 'the parameter name is echoed by any host language'
        $r.OutputText | Should -Not -Match 'RESULT=OK'
        (Get-TargetsSignature -Case $case) | Should -Be $script:Before
    }

    It 'negative control: the same pass sample under the default host reports psver=7 (the marker discriminates)' {
        $r = Invoke-InstallerCase -Case $case -Arguments (@('-ValidateOnly') + $script:Args)
        $r.ExitCode | Should -Be 0
        $r.OutputText | Should -Match 'psver=7\b'
        $r.OutputText | Should -Not -Match 'psver=5\b'
    }
}
