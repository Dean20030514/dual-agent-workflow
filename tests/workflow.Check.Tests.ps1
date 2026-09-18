BeforeAll {
    . "$PSScriptRoot/TestHelpers.ps1"
    $script:CheckPath = Join-Path (Get-RepoRoot) 'tools/check-workflow.ps1'
    $script:EnrollPath = Join-Path (Get-RepoRoot) 'tools/enable-team-project.ps1'
    function Invoke-CheckFixture {
        # Reuse the existing child interlock for the checker's nested installer preview.
        $case.Installer = $CheckPath
        $r = Invoke-InstallerCase -Case $case -Arguments @('-SourceRoot',(Get-RepoRoot),'-Repo',$project,
            '-ClaudeDir',$case.ClaudeDir,'-CodexDir',$case.CodexDir,'-DshDir',$case.DshDir)
        $json = @($r.Output | Where-Object { $_.ToString().StartsWith('{') })[-1] | ConvertFrom-Json
        return @{exit_code=$r.ExitCode;data=$json}
    }
}
Describe 'Read-only workflow deployment check' {
    BeforeEach {
        $case = New-TestCase -Name 'workflow-check' -SeedConfigToml
        $project = Join-Path $case.Root 'project'
        New-Item -ItemType Directory -Path $project | Out-Null
        git -C $project init -q
        $installed = Invoke-InstallerCase -Case $case -Arguments @('-NoPluginInstall',
            '-ClaudeDir',$case.ClaudeDir,'-CodexDir',$case.CodexDir,'-DshDir',$case.DshDir)
        $installed.ExitCode | Should -Be 0
    }
    AfterEach { Remove-TestCase $case }
    It 'detects an unenrolled new project without writing global or project files' {
        $before = Get-TargetsSignature -Case $case
        $projectBefore = Get-TreeSignature $project
        $r = Invoke-CheckFixture
        $r.exit_code | Should -Be 1
        $r.data.global.status | Should -Be 'COMPLETE'
        $r.data.project.status | Should -Be 'NOT_ENROLLED'
        $r.data.project.missing_files.Count | Should -Be 2
        Get-TargetsSignature -Case $case | Should -Be $before
        Get-TreeSignature $project | Should -Be $projectBefore
    }
    It 'detects modified global files instead of trusting the dry-run zero exit code' {
        Add-Content (Join-Path $case.ClaudeDir 'CLAUDE.md') 'local drift'
        $before = Get-TargetsSignature -Case $case
        $r = Invoke-CheckFixture
        $r.exit_code | Should -Be 1
        $r.data.global.status | Should -Be 'OUTDATED_OR_MISSING'
        $r.data.global.different_files | Should -Contain (Join-Path $case.ClaudeDir 'CLAUDE.md')
        Get-TargetsSignature -Case $case | Should -Be $before
    }
    It 'accepts enrollment, validates the manifest, and respects disabled Team Mode' {
        $null = & $EnrollPath -Repo $project -RuntimeRoot (Join-Path $case.CodexDir 'team') -BackupRoot (Join-Path $case.Root 'backups')
        $before = Get-TreeSignature $project
        $r = Invoke-CheckFixture
        $r.exit_code | Should -Be 0
        $r.data.project.status | Should -Be 'COMPLETE'
        Get-TreeSignature $project | Should -Be $before
        $manifest = Join-Path $project 'team/manifest.yaml'
        $content = [IO.File]::ReadAllText($manifest).Replace('enabled: true','enabled: false')
        [IO.File]::WriteAllText($manifest,$content)
        $r = Invoke-CheckFixture
        $r.exit_code | Should -Be 0
        $r.data.project.status | Should -Be 'DISABLED'
        Set-Content $manifest 'schema_version: wrong'
        $r = Invoke-CheckFixture
        $r.exit_code | Should -Be 2
        $r.data.status | Should -Be 'CHECK_FAILED'
    }
    It 'reports incomplete project instructions while preserving their current content' {
        $null = & $EnrollPath -Repo $project -RuntimeRoot (Join-Path $case.CodexDir 'team') -BackupRoot (Join-Path $case.Root 'backups')
        Set-Content (Join-Path $project 'AGENTS.md') '# Replaced project rules'
        $before = Get-TreeSignature $project
        $r = Invoke-CheckFixture
        $r.exit_code | Should -Be 1
        $r.data.project.status | Should -Be 'INCOMPLETE'
        $r.data.project.different_files | Should -Contain (Join-Path $project 'AGENTS.md')
        Get-TreeSignature $project | Should -Be $before
    }
    It 'identifies a new non-Git folder and leaves it empty' {
        $project = Join-Path $case.Root 'new-folder'
        New-Item -ItemType Directory -Path $project | Out-Null
        $r = Invoke-CheckFixture
        $r.exit_code | Should -Be 1
        $r.data.project.status | Should -Be 'NOT_A_GIT_PROJECT'
        @(Get-ChildItem -LiteralPath $project -Force).Count | Should -Be 0
    }
    It 'rejects invalid target roots even when dry-run itself exits zero' {
        # Both are inside the interlocked temp home, but the installer refuses overlap.
        $case.DshDir = $case.CodexDir
        $r = Invoke-CheckFixture
        $r.exit_code | Should -Be 1
        $r.data.global.status | Should -Be 'INVALID'
        $r.data.global.problems.Count | Should -BeGreaterThan 0
    }
}
