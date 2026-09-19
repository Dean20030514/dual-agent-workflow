# Installer coverage for the shared reuse-first protocol (core/reuse -> <root>/workflow-core/reuse).
#
# The contract under test: ONE canonical source, THREE managed copies, add/update-only
# semantics unchanged. Nothing here invokes the installer against a real home - every case
# runs through tests/TestHelpers.ps1 (isolated temp home + embedded interlock).

BeforeAll {
    . "$PSScriptRoot/TestHelpers.ps1"
}

Describe 'Reuse protocol - one canonical source deployed to every harness home' {
    It 'lands the same three files under each root, byte for byte' {
        $case = New-TestCase -Name 'reuse-parity' -SeedConfigToml
        try {
            $targets = @('-ClaudeDir', $case.ClaudeDir, '-CodexDir', $case.CodexDir, '-DshDir', $case.DshDir)
            $r = Invoke-InstallerCase -Case $case -Arguments (@('-NoPluginInstall') + $targets)
            $r.ExitCode | Should -Be 0

            $source = Join-Path (Get-RepoRoot) 'core\reuse'
            $sourceFiles = @(Get-ChildItem -LiteralPath $source -File -Recurse |
                    ForEach-Object { $_.FullName.Substring($source.Length + 1) } | Sort-Object)
            $sourceFiles.Count | Should -BeGreaterThan 0 -Because 'the canonical protocol must ship at least one file'

            $landed = 0
            foreach ($pair in @(@($case.ClaudeDir, 'claude'), @($case.CodexDir, 'codex'), @($case.DshDir, 'dsh'))) {
                $dir = Join-Path $pair[0] 'workflow-core\reuse'
                (Test-Path -LiteralPath $dir -PathType Container) | Should -BeTrue -Because "$($pair[1]) must hold a deployed workflow-core/reuse folder"
                $deployed = @(Get-ChildItem -LiteralPath $dir -File -Force | ForEach-Object { $_.Name } | Sort-Object)
                ($deployed -join ',') | Should -Be ($sourceFiles -join ',') -Because "$($pair[1]) must hold exactly the canonical file set"
                foreach ($rel in $sourceFiles) {
                    $landed++
                    (Get-FileHash -LiteralPath (Join-Path $dir $rel) -Algorithm SHA256).Hash | Should -Be (Get-FileHash -LiteralPath (Join-Path $source $rel) -Algorithm SHA256).Hash -Because "$($pair[1]) copy of $rel must equal the canonical source"
                }
            }
            $landed | Should -Be ($sourceFiles.Count * 3) -Because 'three destinations, one content set'
        } finally { Remove-TestCase $case }
    }

    It 'is a no-op on a second run: nothing written, nothing backed up' {
        $case = New-TestCase -Name 'reuse-noop' -SeedConfigToml
        try {
            $targets = @('-ClaudeDir', $case.ClaudeDir, '-CodexDir', $case.CodexDir, '-DshDir', $case.DshDir)
            $first = Invoke-InstallerCase -Case $case -Arguments (@('-NoPluginInstall') + $targets)
            $first.ExitCode | Should -Be 0
            $before = @(Get-ChildItem -LiteralPath $case.Home -Recurse -Force -Filter '*.bak-*' -File | ForEach-Object FullName)

            $second = Invoke-InstallerCase -Case $case -Arguments (@('-NoPluginInstall') + $targets)
            $second.ExitCode | Should -Be 0
            $second.OutputText | Should -Match 'written=0 unchanged=\d+ backups=0'
            @(Get-TaggedLines -Output $second.Output -Tag '[WRITE]' | Where-Object { $_ -like '*workflow-core*' }).Count | Should -Be 0 -Because 'an unchanged protocol copy is not touched at all'
            @(Get-TaggedLines -Output $second.Output -Tag '[BACKUP]' | Where-Object { $_ -like '*workflow-core*' }).Count | Should -Be 0
            $after = @(Get-ChildItem -LiteralPath $case.Home -Recurse -Force -Filter '*.bak-*' -File | ForEach-Object FullName)
            ($after -join "`n") | Should -Be ($before -join "`n") -Because 'a second run of the same version must not add backups'
        } finally { Remove-TestCase $case }
    }

    It 'backs an overwritten protocol copy up next to itself, holding the pre-deploy content' {
        $case = New-TestCase -Name 'reuse-backup' -SeedConfigToml
        try {
            $reuseDir = Join-Path $case.ClaudeDir 'workflow-core\reuse'
            New-Item -ItemType Directory -Force $reuseDir | Out-Null
            $readme = Join-Path $reuseDir 'README.md'
            Set-Content -Path $readme -Value 'locally edited protocol copy' -Encoding ascii
            $oldHash = (Get-FileHash -LiteralPath $readme).Hash

            $r = Invoke-InstallerCase -Case $case -Arguments @('-NoPluginInstall', '-ClaudeDir', $case.ClaudeDir, '-CodexDir', $case.CodexDir, '-DshDir', $case.DshDir)
            $r.ExitCode | Should -Be 0

            $backups = @(Get-ChildItem -LiteralPath $reuseDir -Filter 'README.md.bak-*' -File)
            $backups.Count | Should -Be 1 -Because 'the overwritten copy is backed up exactly once'
            $backups[0].Name | Should -Match '^README\.md\.bak-\d{8}-\d{6}-[0-9a-f]{4}$'
            (Get-FileHash -LiteralPath $backups[0].FullName).Hash | Should -Be $oldHash -Because 'the backup holds the content that was replaced'
            (Get-FileHash -LiteralPath $readme -Algorithm SHA256).Hash | Should -Be (Get-FileHash -LiteralPath (Join-Path (Get-RepoRoot) 'core\reuse\README.md') -Algorithm SHA256).Hash
        } finally { Remove-TestCase $case }
    }

    It 'keeps local-only content in the protocol folder, and -RemoveStale still never deletes a *.bak-* sibling' {
        $case = New-TestCase -Name 'reuse-local' -SeedConfigToml
        try {
            $reuseDir = Join-Path $case.DshDir 'workflow-core\reuse'
            New-Item -ItemType Directory -Force $reuseDir | Out-Null
            $local = Join-Path $reuseDir 'local-notes.md'
            Set-Content -Path $local -Value 'machine-local note' -Encoding ascii
            $legacyBackup = Join-Path $reuseDir 'README.md.bak-20260101-000000'
            Set-Content -Path $legacyBackup -Value 'legacy backup inside the managed folder' -Encoding ascii
            $localHash = (Get-FileHash -LiteralPath $local).Hash
            $targets = @('-ClaudeDir', $case.ClaudeDir, '-CodexDir', $case.CodexDir, '-DshDir', $case.DshDir)

            $r = Invoke-InstallerCase -Case $case -Arguments (@('-NoPluginInstall') + $targets)
            $r.ExitCode | Should -Be 0
            (Get-FileHash -LiteralPath $local).Hash | Should -Be $localHash -Because 'a default deploy reports live-only content and leaves it alone'
            @(Get-TaggedLines -Output $r.Output -Tag '[STALE]' | Where-Object { $_ -like ('*' + $local) }).Count | Should -BeGreaterThan 0
            @(Get-TaggedLines -Output $r.Output -Tag '[PRESERVE]' | Where-Object { $_ -like ('*' + $legacyBackup) }).Count | Should -BeGreaterThan 0 -Because '*.bak-* stays keep-local-only inside the managed folder too'

            $r2 = Invoke-InstallerCase -Case $case -Arguments (@('-RemoveStale', '-NoPluginInstall') + $targets)
            $r2.ExitCode | Should -Be 0
            (Test-Path -LiteralPath $local) | Should -BeFalse -Because 'the explicit switch removes exactly the reported stale row'
            (Test-Path -LiteralPath $legacyBackup) | Should -BeTrue -Because 'the keep-local-only whitelist outranks -RemoveStale'
        } finally { Remove-TestCase $case }
    }

    It '-DryRun previews all nine protocol files and both zero-write modes leave every tree untouched' {
        $case = New-TestCase -Name 'reuse-zero' -SeedConfigToml
        try {
            $targets = @('-ClaudeDir', $case.ClaudeDir, '-CodexDir', $case.CodexDir, '-DshDir', $case.DshDir)
            $before = Get-TargetsSignature -Case $case

            $dry = Invoke-InstallerCase -Case $case -Arguments (@('-DryRun', '-NoPluginInstall') + $targets)
            $dry.ExitCode | Should -Be 0
            (Get-TargetsSignature -Case $case) | Should -Be $before -Because '-DryRun is a zero-write path'
            @(Get-TaggedLines -Output $dry.Output -Tag '[DIFF]' | Where-Object { $_ -like '*workflow-core\reuse*' }).Count | Should -Be 9 -Because 'three files x three homes must all be previewed'

            $validate = Invoke-InstallerCase -Case $case -Arguments (@('-ValidateOnly', '-NoPluginInstall') + $targets)
            $validate.ExitCode | Should -Be 0
            (Get-TargetsSignature -Case $case) | Should -Be $before -Because '-ValidateOnly is a zero-write path'

            $negative = Join-Path $case.DshDir 'workflow-core\reuse\probe.txt'
            New-Item -ItemType Directory -Force (Split-Path -Parent $negative) | Out-Null
            Set-Content -Path $negative -Value 'x' -Encoding ascii
            (Get-TargetsSignature -Case $case) | Should -Not -Be $before -Because 'the signature probe must be able to see a write at all'
        } finally { Remove-TestCase $case }
    }
}
