BeforeAll {
    $script:TeamPath=Split-Path $PSScriptRoot -Parent
    foreach ($name in @('Core','Lead','Contracts','Preflight','Controls')) { . (Join-Path $script:TeamPath "scripts/$name.ps1") }
}

Describe 'Runtime compatibility instead of baseline version equality' {
    BeforeEach {
        $manifest=Read-TeamData (Join-Path $script:TeamPath 'manifest.yaml')
        $script:probe=@{
            codex='codex-cli 0.155.1';dsh='0.1.5-rc.1';claude='2.1.246 (Claude Code)';claudePresent=$true
            codexHelp='--ephemeral --ignore-user-config --ignore-rules --disable --config --model --sandbox --cd --output-schema --output-last-message --json read-only'
            claudeHelp='--print --model --permission-mode --output-format --settings'
        }
        Mock Get-TeamLeadEvidence { @{runtime_verified=$true;reason='synthetic active Lead'} }
        Mock Get-Command {
            param($Name)
            if ($Name -eq 'claude' -and -not $script:probe.claudePresent) { return $null }
            @{Source=$Name}
        } -ParameterFilter { $Name -in @('codex','dsh','claude','pwsh') }
        Mock Invoke-TeamCapture {
            param($Command,$Arguments)
            if ($Arguments -contains '--version') { return $script:probe[$Command] }
            if ($Arguments -contains '--help') { return $script:probe["${Command}Help"] }
            throw 'Unexpected probe'
        }
        Mock Test-DshRoute { @{verified=$true;provider='deepseek-official';model='deepseek-flash';native_available=$true} }
    }
    It 'accepts a changed Codex version with required interfaces and records the drift honestly' {
        $doctor=Test-TeamDoctor $manifest $TestDrive
        $doctor.success | Should -BeTrue
        $doctor.runtime_status | Should -Be 'COMPATIBILITY_CHECKED'
        $doctor.version_drift[0].installed | Should -Be '0.155.1'
        $doctor.cli_checks.codex.verified | Should -BeTrue
        $doctor.cli_checks.claude.model_access | Should -Be 'NOT_TESTED'
        $doctor.warnings.Count | Should -Be 1
    }
    It 'does not mistake a prerelease or a major update for missing compatibility evidence' -ForEach @(
        @{Version='0.155.0-alpha.9.2'},@{Version='0.155.0-alpha.9.2+build.123'},@{Version='1.0.0'}
    ) {
        $script:probe.codex="codex-cli $Version"
        (Test-TeamDoctor $manifest $TestDrive).success | Should -BeTrue
    }
    It 'rejects lost sandbox support even at the exact baseline version and with override' {
        $script:probe.codex="codex-cli $($manifest.runtime.codex_version)"
        $script:probe.codexHelp=$script:probe.codexHelp.Replace('--sandbox','--sandbox-new')
        foreach ($override in @($false,$true)) {
            $doctor=Test-TeamDoctor $manifest $TestDrive -AllowUnverifiedRuntime:$override
            $doctor.success | Should -BeFalse
            $doctor.problems -join ' ' | Should -Match 'Required CLI options missing: --sandbox'
        }
    }
    It 'rejects unrecognized version output instead of treating a broken CLI as compatible' {
        $script:probe.codex='please log in'
        $doctor=Test-TeamDoctor $manifest $TestDrive
        $doctor.success | Should -BeFalse
        $doctor.runtime_status | Should -Be 'INCOMPATIBLE_RUNTIME'
    }
    It 'admits an installed certified DSH version without updating every project baseline' {
        $manifest.runtime.dsh_version='0.1.0'
        $doctor=Test-TeamDoctor $manifest $TestDrive
        $doctor.success | Should -BeTrue
        $doctor.cli_checks.dsh.verified | Should -BeTrue
        $doctor.version_drift.Count | Should -Be 2
    }
    It 'does not promote an untested DSH version by changing the manifest baseline' {
        $script:probe.dsh='0.1.5-rc.2';$manifest.runtime.dsh_version='0.1.5-rc.2'
        $doctor=Test-TeamDoctor $manifest $TestDrive
        $doctor.success | Should -BeFalse
        $doctor.problems -join ' ' | Should -Match 'no matching transport/native-guard acceptance evidence'
        $doctor.capabilities.allowed_modes | Should -Not -Contain 'L1'
        $doctor.capabilities.allowed_modes | Should -Not -Contain 'L3'
        $override=Test-TeamDoctor $manifest $TestDrive -AllowUnverifiedRuntime
        $override.success | Should -BeTrue
        $override.runtime_status | Should -Be 'UNVERIFIED_RUNTIME'
        $override.capabilities.allowed_modes | Should -Not -Contain 'L3'
    }
    It 'keeps a failed route blocked regardless of version and override' {
        Mock Test-DshRoute { throw 'DSH effective model route differs from manifest' }
        (Test-TeamDoctor $manifest $TestDrive -AllowUnverifiedRuntime).success | Should -BeFalse
    }
    It 'keeps an unverified Lead blocked despite compatible CLIs' {
        Mock Get-TeamLeadEvidence { @{runtime_verified=$false;reason='completed turn'} }
        (Test-TeamDoctor $manifest $TestDrive).success | Should -BeFalse
    }
    It 'does not make an absent Claude installation a Team dependency' {
        $script:probe.claudePresent=$false
        $doctor=Test-TeamDoctor $manifest $TestDrive -IncludeOptionalHarnesses
        $doctor.success | Should -BeTrue
        $doctor.cli_checks.claude.status | Should -Be 'NOT_INSTALLED'
    }
    It 'reports a Claude interface failure without blocking Codex and DSH' {
        $script:probe.claudeHelp='--model'
        $doctor=Test-TeamDoctor $manifest $TestDrive -IncludeOptionalHarnesses
        $doctor.success | Should -BeTrue
        $doctor.cli_checks.claude.status | Should -Be 'CHECK_FAILED'
        $doctor.warnings -join ' ' | Should -Match 'Optional Claude CLI check failed'
    }
    It 'does not probe the unused Claude CLI during dispatch checks' {
        $doctor=Test-TeamDoctor $manifest $TestDrive
        $doctor.success | Should -BeTrue
        $doctor.cli_checks.claude.status | Should -Be 'NOT_CHECKED'
        Should -Invoke Invoke-TeamCapture -Times 0 -Exactly -ParameterFilter { $Command -eq 'claude' }
    }
}
