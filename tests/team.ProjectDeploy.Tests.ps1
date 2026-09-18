BeforeAll {
    $script:EnableTeam = Join-Path (Split-Path $PSScriptRoot -Parent) 'tools/enable-team-project.ps1'
    $script:TeamSource = Join-Path (Split-Path $PSScriptRoot -Parent) 'team'
    $script:OriginalCodexHome = $env:CODEX_HOME
}
Describe 'Project Team enrollment' {
    BeforeEach {
        $script:CaseRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $script:Project = Join-Path $CaseRoot '中文 project'
        New-Item -ItemType Directory -Path $Project -Force | Out-Null
        git -C $Project init -q
        $env:CODEX_HOME = Join-Path $CaseRoot 'codex'
        $script:OldRules = "# Original rules`r`nNever push.`r`n" + ('Long retained rule.' * 3000)
        [IO.File]::WriteAllText((Join-Path $Project 'AGENTS.md'), $OldRules)
    }
    AfterEach { $env:CODEX_HOME = $OriginalCodexHome }
    It 'prepends the hook, preserves existing rules, backs up, and repeats without writes' {
        $first = & $EnableTeam -Repo $Project -RuntimeRoot $TeamSource | ConvertFrom-Json
        $first.projects[0].changed | Should -Be 4
        $current = [IO.File]::ReadAllText((Join-Path $Project 'AGENTS.md'))
        $current.StartsWith('<!-- codex-team:start -->') | Should -BeTrue
        $current.EndsWith($OldRules) | Should -BeTrue
        $backup = Get-Content (Join-Path $first.backup_root 'index.jsonl') | ConvertFrom-Json
        [IO.File]::ReadAllText($backup.backup) | Should -BeExactly $OldRules
        $second = & $EnableTeam -Repo $Project -RuntimeRoot $TeamSource | ConvertFrom-Json
        $second.files.Count | Should -Be 0
        git -C $Project check-ignore team/runtime/run/state.json .worktrees/worker/file.txt | Should -HaveCount 2
    }
    It 'has zero-write dry run and preserves a project manifest on enrollment' {
        $dry = & $EnableTeam -Repo $Project -RuntimeRoot $TeamSource -DryRun | ConvertFrom-Json
        $dry.files.Count | Should -Be 4
        Test-Path (Join-Path $Project 'team') | Should -BeFalse
        [IO.File]::ReadAllText((Join-Path $Project 'AGENTS.md')) | Should -BeExactly $OldRules
        New-Item -ItemType Directory -Path (Join-Path $Project 'team') | Out-Null
        Set-Content (Join-Path $Project 'team/manifest.yaml') 'custom: preserve'
        $before = (Get-FileHash (Join-Path $Project 'team/manifest.yaml')).Hash
        $null = & $EnableTeam -Repo $Project -RuntimeRoot $TeamSource
        (Get-FileHash (Join-Path $Project 'team/manifest.yaml')).Hash | Should -Be $before
    }
    It 'forwards spaced arguments and binds the project from an unrelated working directory' {
        $null = & $EnableTeam -Repo $Project -RuntimeRoot $TeamSource
        $scripts = Join-Path $env:CODEX_HOME 'team/scripts'
        New-Item -ItemType Directory -Path $scripts -Force | Out-Null
        @'
param([string]$Command,[string]$TaskText,[string]$Repo,[string]$Manifest,[switch]$Json)
@{command=$Command;task=$TaskText;repo=$Repo;manifest=$Manifest;json=[bool]$Json} | ConvertTo-Json -Compress
exit 17
'@ | Set-Content (Join-Path $scripts 'team.ps1')
        $result = & pwsh -NoProfile -File (Join-Path $Project 'team/scripts/team.ps1') route -TaskText 'SQL optimization 中文' -Json | ConvertFrom-Json
        $LASTEXITCODE | Should -Be 17
        $result.task | Should -Be 'SQL optimization 中文'
        $result.repo | Should -Be $Project
        $result.manifest | Should -Be (Join-Path $Project 'team/manifest.yaml')
        $result.json | Should -BeTrue
    }
    It 'uses the actual override file and refuses an unrelated launcher before writing' {
        Set-Content (Join-Path $Project 'AGENTS.override.md') 'Override rules'
        New-Item -ItemType Directory -Path (Join-Path $Project 'team/scripts') -Force | Out-Null
        Set-Content (Join-Path $Project 'team/scripts/team.ps1') 'unrelated launcher'
        { & $EnableTeam -Repo $Project -RuntimeRoot $TeamSource } | Should -Throw '*unrelated launcher*'
        (Get-Content (Join-Path $Project 'AGENTS.override.md') -Raw).Trim() | Should -Be 'Override rules'
        Test-Path (Join-Path $Project '.gitignore') | Should -BeFalse
    }
}
