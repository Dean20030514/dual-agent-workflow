BeforeAll {
    $script:TeamPath = Split-Path $PSScriptRoot -Parent
    . (Join-Path $script:TeamPath 'scripts/Core.ps1')
    . (Join-Path $script:TeamPath 'scripts/Contracts.ps1')
    . (Join-Path $script:TeamPath 'scripts/Preflight.ps1')
    . (Join-Path $script:TeamPath 'scripts/State.ps1')
    . (Join-Path $script:TeamPath 'scripts/Controls.ps1')
    . (Join-Path $script:TeamPath 'scripts/Execution.ps1')
    . (Join-Path $script:TeamPath 'scripts/Integration.ps1')
    function New-Plan {
        Read-TeamData (Join-Path $script:TeamPath 'tests/plans/L1-sql.yaml')
    }
    $script:ManifestData = Read-TeamData (Join-Path $script:TeamPath 'manifest.yaml')
    function Assert-Code($Action, $Expected) {
        $caught = $null
        try { & $Action | Out-Null } catch { $caught = $_ }
        $caught | Should -Not -BeNullOrEmpty
        $caught.Exception.Data['TeamExitCode'] | Should -Be $Expected
    }
}

Describe 'Plan and routing contracts' {
    It 'accepts the real YAML fixture' {
        @(Test-TeamPlan (New-Plan) $script:ManifestData) | Should -Be @('SQL-001')
    }
    It 'routes <Text> to <Mode>' -ForEach @(
        @{Text='README typo';Mode='L0'}, @{Text='SQL optimization';Mode='L1'},
        @{Text='avatar upload';Mode='L2'}, @{Text='auth redesign';Mode='L3'}, @{Text='hello';Mode='UNKNOWN'}
    ) { (Get-TeamRoute $Text).recommended_mode | Should -Be $Mode }
    It 'rejects a cyclic DAG before dispatch' {
        $p = New-Plan; $p.tasks[0].dependencies = @('SQL-001')
        Assert-Code { Test-TeamPlan $p $script:ManifestData } 10
    }
    It 'rejects missing dependencies' {
        $p = New-Plan; $p.tasks[0].dependencies = @('MISSING')
        Assert-Code { Test-TeamPlan $p $script:ManifestData } 10
    }
    It 'rejects critical self approval through disabled gates' {
        $p = New-Plan; $p.classification.level = 'critical'
        Assert-Code { Test-TeamPlan $p $script:ManifestData } 10
    }
    It 'rejects path traversal and unrestricted scope: <Scope>' -ForEach @(
        @{Scope='../other/**'}, @{Scope='C:/Windows/**'}, @{Scope='**/*'}, @{Scope='.git/config'}
    ) {
        $p = New-Plan; $p.tasks[0].write_scope = @($Scope)
        Assert-Code { Test-TeamPlan $p $script:ManifestData } 10
    }
    It 'rejects invalid schema fields and does not coerce string booleans' {
        $p = New-Plan; $p.tasks[0].permissions.shell = 'false'
        Assert-Code { Test-TeamPlan $p $script:ManifestData } 10
    }
    It 'does not confuse star and recursive star' {
        Test-TeamScope 'src/auth/deep/file.ps1' @('src/*') | Should -BeFalse
        Test-TeamScope 'src/auth/deep/file.ps1' @('src/**') | Should -BeTrue
        Test-TeamScope 'other/file.ps1' @('src/**') | Should -BeFalse
    }
    It 'accepts narrower child scopes while rejecting expansion and traversal' {
        Test-TeamScopeSubset 'src/auth/session.ts' @('src/**') | Should -BeTrue
        Test-TeamScopeSubset 'src/auth/**' @('src/**') | Should -BeTrue
        Test-TeamScopeSubset 'src/**' @('src/auth/**') | Should -BeFalse
        Test-TeamScopeSubset 'src/../secrets/**' @('src/**') | Should -BeFalse
    }
    It 'computes downstream and overlapping siblings while preserving unrelated work' {
        $p = @{tasks=@(
            @{id='A';dependencies=@();write_scope=@('src/a/**')},
            @{id='B';dependencies=@('A');write_scope=@('src/b/**')},
            @{id='C';dependencies=@();write_scope=@('src/shared/**')},
            @{id='D';dependencies=@();write_scope=@('docs/**')})}
        @(Get-TeamAffected $p 'A' @('src/shared/api.ts')) | Should -Be @('A','B','C')
    }
}

Describe 'Persistence, process and repository guards' {
    It 'writes atomic JSON without leaving temporary files' {
        $path = Join-Path $TestDrive 'state.json'
        Write-TeamData $path @{value=1}; Write-TeamData $path @{value=2}
        (Read-TeamData $path).value | Should -Be 2
        @(Get-ChildItem -LiteralPath $TestDrive -Filter '.atomic-*').Count | Should -Be 0
    }
    It 'rejects a resolved path outside the intended root' {
        Assert-Code { Get-TeamChild $TestDrive '../outside' } 82
    }
    It 'degrades routing after three mismatches without requiring a Team run' {
        $repo=Join-Path $TestDrive 'routing-only'; New-Item -ItemType Directory $repo | Out-Null
        1..3 | ForEach-Object { $null=Record-TeamRoute $script:ManifestData $repo 'README typo' 'L2' }
        (Read-TeamData (Join-Path $repo 'team/runtime/routing.json')).auto_route | Should -Be 'degraded'
        (Record-TeamRoute $script:ManifestData $repo 'SQL optimization' 'L1').auto_route | Should -Be 'normal'
        Test-Path (Join-Path $repo 'team/runtime/.team-lock') | Should -BeFalse
    }
    It 'keeps a paused run locked and rejects a second coordinator' {
        $repo = Join-Path $TestDrive 'lock-repo'; New-Item -ItemType Directory $repo | Out-Null
        $handle = Lock-TeamRepo $repo 'ONE'
        try { Assert-Code { Lock-TeamRepo $repo 'TWO' } 20 } finally { $handle.Dispose() }
        Assert-Code { Lock-TeamRepo $repo 'TWO' } 20
        $handle = Lock-TeamRepo $repo 'ONE' -Resume
        $handle.Dispose()
        Unlock-TeamRepo $repo 'ONE'
    }
    It 'captures real process exit and literal arguments' {
        $scriptPath = Join-Path $TestDrive 'literal.ps1'
        Set-Content -LiteralPath $scriptPath -Value 'param([string]$Value) Write-Output $Value; exit 7'
        $handle = New-TeamProcess $scriptPath @('-Value','spaces $() ` quotes " 中文') $TestDrive (Join-Path $TestDrive 'out') (Join-Path $TestDrive 'err')
        Wait-TeamProcess $handle 10 | Should -Be 7
        (Get-Content -LiteralPath (Join-Path $TestDrive 'out') -Raw).Trim() | Should -Be 'spaces $() ` quotes " 中文'
    }
    It 'maps a real external verification failure to 40' {
        $command = @{id='red';executable='pwsh';args=@('-NoProfile','-Command','exit 9');timeout_seconds=10}
        Assert-Code { Invoke-TeamVerification @($command) $TestDrive $TestDrive 'negative' } 40
        (Read-TeamData (Join-Path $TestDrive 'negative-evidence.json')).exit_code | Should -Be 9
    }
    It 'terminates its own child on timeout' {
        $handle = New-TeamProcess 'pwsh' @('-NoProfile','-Command','Start-Sleep -Seconds 30') $TestDrive (Join-Path $TestDrive 'slow-out') (Join-Path $TestDrive 'slow-err')
        Assert-Code { Wait-TeamProcess $handle 1 } 31
    }
}

Describe 'Git-backed result audit' {
    BeforeEach {
        $script:Fixture = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory $script:Fixture | Out-Null
        $null = Invoke-TeamGit $script:Fixture @('init','-q','-b','fixture')
        $null = Invoke-TeamGit $script:Fixture @('config','user.name','TeamFixture')
        $null = Invoke-TeamGit $script:Fixture @('config','user.email','fixture@example.invalid')
        Set-Content -LiteralPath (Join-Path $script:Fixture 'allowed.txt') -Value 'base'
        $null = Invoke-TeamGit $script:Fixture @('add','allowed.txt')
        $null = Invoke-TeamGit $script:Fixture @('commit','-qm','test: base')
        $script:Base = Invoke-TeamGit $script:Fixture @('rev-parse','HEAD')
        Set-Content -LiteralPath (Join-Path $script:Fixture 'allowed.txt') -Value 'changed'
        $null = Invoke-TeamGit $script:Fixture @('commit','-qam','test: change')
        $script:Head = Invoke-TeamGit $script:Fixture @('rev-parse','HEAD')
        $script:ResultDir = Join-Path $TestDrive ('result-' + [guid]::NewGuid().ToString('N'))
        $script:Item = @{worktree=$script:Fixture;directory=$script:ResultDir;branch='fixture';base_sha=$script:Base}
        $script:TaskData = @{id='T1';write_scope=@('allowed.txt');subagents=@{allowed=$false};permissions=@{shell=$true;network=$false;secrets=$false;production=$false}}
        $script:ResultData = @{schema_version=1;run_id='R1';task_id='T1';status='completed';summary=@('done');changed_files=@('allowed.txt');verification=@{passed=$true};subagents_used=@();risks=@();git=@{branch='fixture';commit=$script:Head}}
        Write-TeamData (Join-Path $script:ResultDir 'result.yaml') $script:ResultData
    }
    It 'accepts a result bound to real clean Git changes' {
        (Read-WorkerResult $script:Item $script:TaskData 'R1').commit | Should -Be $script:Head
    }
    It 'detects out-of-scope committed files even if omitted from result' {
        Set-Content -LiteralPath (Join-Path $script:Fixture 'secret.txt') -Value 'fixture-only'
        $null = Invoke-TeamGit $script:Fixture @('add','secret.txt')
        $null = Invoke-TeamGit $script:Fixture @('commit','-qm','test: forbidden')
        $script:ResultData.git.commit = Invoke-TeamGit $script:Fixture @('rev-parse','HEAD')
        Write-TeamData (Join-Path $script:ResultDir 'result.yaml') $script:ResultData
        Assert-Code { Read-WorkerResult $script:Item $script:TaskData 'R1' } 82
    }
    It 'rejects untracked leftovers' {
        Set-Content -LiteralPath (Join-Path $script:Fixture 'leftover.txt') -Value 'fixture-only'
        Assert-Code { Read-WorkerResult $script:Item $script:TaskData 'R1' } 82
    }
    It 'rejects forged commit and result identity' {
        $script:ResultData.git.commit = $script:Base
        Write-TeamData (Join-Path $script:ResultDir 'result.yaml') $script:ResultData
        Assert-Code { Read-WorkerResult $script:Item $script:TaskData 'R1' } 80
    }
    It 'audits the old side of a rename' {
        $null = Invoke-TeamGit $script:Fixture @('mv','allowed.txt','new.txt')
        $null = Invoke-TeamGit $script:Fixture @('commit','-qm','test: rename')
        $script:TaskData.write_scope = @('new.txt')
        $script:ResultData.git.commit = Invoke-TeamGit $script:Fixture @('rev-parse','HEAD')
        $script:ResultData.changed_files = @('new.txt')
        Write-TeamData (Join-Path $script:ResultDir 'result.yaml') $script:ResultData
        Assert-Code { Read-WorkerResult $script:Item $script:TaskData 'R1' } 82
    }
}
