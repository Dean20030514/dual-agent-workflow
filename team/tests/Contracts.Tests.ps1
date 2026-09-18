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
    It 'does not admit L3 when tools exist but a native provider is disabled' {
        Mock Invoke-TeamCapture {
            @(@{id='agent-default-model';config=@{provider='deepseek-official';model='deepseek-flash'}},
                @{id='llm-deepseek'},@{id='headless-startup'},@{id='headless-runner'},@{id='subagent'},
                @{id='subagent-spawn-in-process'},@{id='subagent-fork-in-process';disabled=$true},
                @{id='tool-subagent'},@{id='tool-subagent-fork'}) | ConvertTo-Json -Depth 8
        }
        $old=$env:DSH_HOME; $env:DSH_HOME=Join-Path $TestDrive 'provider-probe-home'
        try {
            $route=Test-DshRoute $script:ManifestData $TestDrive
            $route.verified | Should -BeTrue
            $route.native_available | Should -BeFalse
            $route.native_services | Should -Contain 'tool-subagent-fork'
            $route.native_services | Should -Not -Contain 'subagent-fork-in-process'
            $cap=Get-TeamCapabilityDecision 'I1' 'O2' 'E2' $route.verified $route.native_available $true $true
            Assert-Code { Assert-TeamCapability @{mode='L3'} @{capabilities=$cap} } 20
        } finally { $env:DSH_HOME=$old }
    }
    It 'applies the capability matrix to <InputAxis>/<OutputAxis>/<ExitAxis>' -ForEach @(
        @{InputAxis='I3';OutputAxis='O4';ExitAxis='E2';Modes=@('L0','L1','L2','L3')},
        @{InputAxis='I2';OutputAxis='O3';ExitAxis='E2';Modes=@('L0','L1','L2','L3')},
        @{InputAxis='I2';OutputAxis='O2';ExitAxis='E2';Modes=@('L0','L1','L2')},
        @{InputAxis='I1';OutputAxis='O3';ExitAxis='E2';Modes=@('L0','L1','L2')},
        @{InputAxis='I1';OutputAxis='O2';ExitAxis='E2';Modes=@('L0','L1','L2')},
        @{InputAxis='I1';OutputAxis='O1';ExitAxis='E1';Modes=@('L0')},
        @{InputAxis='I0';OutputAxis='O2';ExitAxis='E1';Modes=@('L0')},
        @{InputAxis='I0';OutputAxis='O0';ExitAxis='E0';Modes=@('L0')}
    ) {
        $cap=Get-TeamCapabilityDecision $InputAxis $OutputAxis $ExitAxis $true $true $true
        $cap.allowed_modes | Should -Be $Modes
        $cap.adapter_l3_extension | Should -BeFalse
        if ($InputAxis -eq 'I1' -and $OutputAxis -eq 'O1') { $cap.experimental_modes | Should -Contain 'L1' }
    }
    It 'requires verified route and native tools even for structured transports' {
        (Get-TeamCapabilityDecision 'I3' 'O4' 'E2' $false $true $true).allowed_modes | Should -Be @('L0')
        (Get-TeamCapabilityDecision 'I3' 'O4' 'E2' $true $false $true).allowed_modes | Should -Be @('L0','L1','L2')
        $cap=Get-TeamCapabilityDecision 'I3' 'O4' 'E2' $true $true $false
        $cap.l3_limited | Should -BeTrue
        $cap.result_child_summary_required | Should -BeTrue
    }
    It 'keeps the verified adapter extension distinct and fails closed when a prerequisite disappears' {
        $cap=Get-TeamCapabilityDecision 'I1' 'O2' 'E2' $true $true $true $true
        $cap.matrix_modes | Should -Be @('L0','L1','L2')
        $cap.allowed_modes | Should -Contain 'L3'
        $cap.adapter_l3_extension | Should -BeTrue
        Assert-TeamCapability @{mode='L3'} @{capabilities=$cap}
        foreach ($flags in @(@($false,$true,$true),@($true,$false,$true),@($true,$true,$false))) {
            $cap=Get-TeamCapabilityDecision 'I1' 'O2' 'E2' $flags[0] $flags[1] $flags[2] $true
            $cap.allowed_modes | Should -Not -Contain 'L3'
            Assert-Code { Assert-TeamCapability @{mode='L3'} @{capabilities=$cap} } 20
        }
    }
    It 'loads all role contracts and rejects integration authority expansion' {
        $roles=@(Get-ChildItem (Join-Path $script:TeamPath 'roles') -Filter '*.yaml')
        $roles.Count | Should -Be 19
        foreach ($file in $roles) { $null = Get-TeamRole $file.BaseName }
        $role=Get-TeamRole 'integration'; $role.may_change_interfaces=$true
        Assert-Code { Test-TeamSchema $role 'role' } 10
        $p=New-Plan; $p.tasks[0].role='integration'; $p.tasks[0].permissions.network=$true
        Assert-Code { Test-TeamPlan $p $script:ManifestData } 10
        Assert-Code { Start-TeamWorker @{repairs=@{}} @{id='UNOWNED';role='integration'} @{} $TestDrive } 10
    }
    It 'rejects a packet whose domain contract differs from the assigned role' {
        $plan=New-Plan; $task=$plan.tasks[0]
        $packet=@{schema_version=1;run_id=$plan.run.id;task_id=$task.id;role=@{id='database';definition=(Get-TeamRole 'backend')};objective=$task.objective;
            dependencies=$task.dependencies;permissions=$task.permissions;write_scope=$task.write_scope;acceptance=$task.acceptance;
            subagents=$task.subagents;base_sha=('a'*40);result_schema='result.schema.json';verification=$task.verification}
        Assert-Code { Test-TeamTask $packet } 10
        $packet.role.definition=Get-TeamRole 'database'
        Test-TeamTask $packet
    }
    It 'accepts the real YAML fixture' {
        @(Test-TeamPlan (New-Plan) $script:ManifestData) | Should -Be @('SQL-001')
    }
    It 'routes <Text> to <Mode>' -ForEach @(
        @{Text='README typo';Mode='L0'}, @{Text='SQL optimization';Mode='L1'},
        @{Text='avatar upload';Mode='L2'}, @{Text='auth redesign';Mode='L3'}, @{Text='hello';Mode='UNKNOWN'}
    ) { (Get-TeamRoute $Text).recommended_mode | Should -Be $Mode }
    It 'uses bounded repository markers only for ambiguous implementation tasks' {
        $repo=Join-Path $TestDrive 'routing-metadata'
        New-Item -ItemType Directory (Join-Path $repo 'frontend') -Force | Out-Null
        (Get-TeamRoute '实现搜索功能' $repo).recommended_mode | Should -Be 'L1'
        New-Item -ItemType Directory (Join-Path $repo 'backend') | Out-Null
        $route=Get-TeamRoute '实现搜索功能' $repo
        $route.recommended_mode | Should -Be 'L2'
        $route.confidence | Should -BeLessThan 0.8
        $route.lead_action | Should -Be 'lead_assessment_required'
        $route.repo_metadata.markers | Should -Contain 'frontend'
        $route.repo_metadata.markers | Should -Contain 'backend'
        (Get-TeamRoute 'README typo' $repo).recommended_mode | Should -Be 'L0'
        (Get-TeamRoute 'hello' $repo).recommended_mode | Should -Be 'UNKNOWN'
        Test-Path (Join-Path $repo 'team/runtime') | Should -BeFalse
    }
    It 'reports risk flags independently of mode and the enabled switch' {
        $route=Get-TeamRoute 'README production credentials'
        $route.recommended_mode | Should -Be 'UNKNOWN'
        $route.risk_flags | Should -Contain 'owner_decision_required'
        $route.lead_action | Should -Be 'assess_owner_escalation'
        $config=Read-TeamData (Join-Path $script:TeamPath 'manifest.yaml'); $config.team.enabled=$false
        $route=Get-TeamRoute 'auth redesign production' '' $config
        $route.recommended_mode | Should -Be 'L0'
        $route.risk_flags | Should -Contain 'security_sensitive'
        $route.lead_action | Should -Be 'use_normal_codex'
    }
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
        # A new passing example is not evidence that the earlier regression was fixed.
        (Record-TeamRoute $script:ManifestData $repo 'SQL optimization' 'L1').auto_route | Should -Be 'degraded'
        $route=Get-TeamRoute 'avatar upload' $repo $script:ManifestData
        $route.auto_route | Should -Be 'degraded'
        $route.notice | Should -Match 'revalidate-route'
        $route.lead_action | Should -Be 'explicit_route_for_each_complex_task_until_revalidated'
        $check=Reset-TeamRoutingHealth $script:ManifestData $repo 'Check known regression'
        $check.success | Should -BeFalse
        $check.auto_route | Should -Be 'degraded'
        @($check.checks | Where-Object status -eq 'ROUTING_MISMATCH').Count | Should -Be 1
        $null=Record-TeamRoute $script:ManifestData $repo 'README typo' 'L0'
        (Get-TeamRoute '' $repo).auto_route | Should -Be 'degraded'
        $check=Reset-TeamRoutingHealth $script:ManifestData $repo 'Corrected the explicit task expectation after inspection'
        $check.success | Should -BeTrue
        $check.auto_route | Should -Be 'normal'
        $saved=Read-TeamData (Join-Path $repo 'team/runtime/routing.json')
        $saved.last_revalidation.checks.Count | Should -Be 6
        $saved.consecutive_misroutes | Should -Be 0
        Test-Path (Join-Path $repo 'team/runtime/.team-lock') | Should -BeFalse
    }
    It 'revalidates real mismatches against current repository metadata' {
        $repo=Join-Path $TestDrive 'routing-revalidate'
        New-Item -ItemType Directory $repo | Out-Null
        1..3 | ForEach-Object { $null=Record-TeamRoute $script:ManifestData $repo '新增搜索功能' 'L2' }
        (Reset-TeamRoutingHealth $script:ManifestData $repo 'Before metadata correction').success | Should -BeFalse
        foreach ($name in @('frontend','backend')) { New-Item -ItemType Directory (Join-Path $repo $name) | Out-Null }
        (Reset-TeamRoutingHealth $script:ManifestData $repo 'Repository domain markers are now available').success | Should -BeTrue
    }
    It 'does not clear legacy degradation with only the fixed examples or accept an empty reason' {
        $repo=Join-Path $TestDrive 'routing-legacy'; $path=Join-Path $repo 'team/runtime/routing.json'
        Write-TeamData $path @{auto_route='degraded';consecutive_misroutes=3}
        Assert-Code { Reset-TeamRoutingHealth $script:ManifestData $repo 'Fixed examples only' } 20
        Assert-Code { Reset-TeamRoutingHealth $script:ManifestData $repo '' } 10
        (Read-TeamData $path).auto_route | Should -Be 'degraded'
    }
    It 'serializes route observations and revalidation using the same lock' {
        $repo=Join-Path $TestDrive 'routing-locked'; $root=Join-Path $repo 'team/runtime'
        New-Item -ItemType Directory $root -Force | Out-Null
        $handle=[IO.File]::Open((Join-Path $root '.routing-lock'),'OpenOrCreate','ReadWrite','None')
        try {
            Assert-Code { Record-TeamRoute $script:ManifestData $repo 'README typo' 'L0' } 20
            Assert-Code { Reset-TeamRoutingHealth $script:ManifestData $repo 'Test lock' } 20
        } finally { $handle.Dispose() }
        Test-Path (Join-Path $root 'routing.json') | Should -BeFalse
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
        Close-TeamProcess $handle -Terminate | Should -Be 7
        (Get-Content -LiteralPath (Join-Path $TestDrive 'out') -Raw).Trim() | Should -Be 'spaces $() ` quotes " 中文'
    }
    It 'retains the original document when a reader persistently denies replacement' {
        $path=Join-Path $TestDrive 'held-state.json'; Write-TeamData $path @{value='before'}
        $reader=[IO.File]::Open($path,'Open','Read','Read')
        try { { Write-TeamData $path @{value='after'} } | Should -Throw }
        finally { $reader.Dispose() }
        (Read-TeamData $path).value | Should -Be 'before'
        Write-TeamData $path @{value='after'}
        (Read-TeamData $path).value | Should -Be 'after'
        @(Get-ChildItem -LiteralPath $TestDrive -Filter '.atomic-*').Count | Should -Be 0
    }
    It 'maps a real external verification failure to 40' {
        $command = @{id='red';executable='pwsh';args=@('-NoProfile','-Command','exit 9');timeout_seconds=10}
        Assert-Code { Invoke-TeamVerification @($command) $TestDrive $TestDrive 'negative' } 40
        (Read-TeamData (Join-Path $TestDrive 'negative-evidence.json')).exit_code | Should -Be 9
    }
    It 'counts repeated failure evidence once per attempt and resets on a different failure' {
        $directory=Join-Path $TestDrive 'verification-failures'
        [IO.Directory]::CreateDirectory($directory) | Out-Null
        $state=@{tasks=@{T1=@{directory=$directory;attempts=1}}}
        $failure=@{id='check';executable='pwsh';args=@('-Command','exit 9');exit_code=9;stdout_sha256=('a'*64);stderr_sha256=('b'*64)}
        Write-TeamData (Join-Path $directory 'verification-evidence.json') @($failure)
        Mock New-TeamEscalation {}
        Record-TeamVerificationFailure $state $directory 'T1'
        Record-TeamVerificationFailure $state $directory 'T1'
        $state.verification_failures.T1.count | Should -Be 1
        $state.tasks.T1.attempts=2
        Record-TeamVerificationFailure $state $directory 'T1'
        Record-TeamVerificationFailure $state $directory 'T1'
        $state.verification_failures.T1.count | Should -Be 2
        Should -Invoke New-TeamEscalation -Exactly -Times 1
        $state.tasks.T1.attempts=3; $failure.exit_code=8
        Write-TeamData (Join-Path $directory 'verification-evidence.json') @($failure)
        Record-TeamVerificationFailure $state $directory 'T1'
        $state.verification_failures.T1.count | Should -Be 1
        @(Get-Content (Join-Path $directory 'events.jsonl')).Count | Should -Be 3
    }
    It 'terminates its own child on timeout' {
        $handle = New-TeamProcess 'pwsh' @('-NoProfile','-Command','Start-Sleep -Seconds 30') $TestDrive (Join-Path $TestDrive 'slow-out') (Join-Path $TestDrive 'slow-err')
        Assert-Code { Wait-TeamProcess $handle 1 } 31
    }
    It 'binds a live PID to its exact start time after a JSON timestamp round trip' {
        $process=Get-Process -Id $PID
        $path=Join-Path $TestDrive 'process-receipt.json'
        Write-TeamData $path @{pid=$PID;start=$process.StartTime.ToUniversalTime().ToString('o')}
        $record=Read-TeamData $path
        (Get-TeamOwnedProcess $record.pid $record.start).Id | Should -Be $PID
        Get-TeamOwnedProcess $record.pid (([datetime]$record.start).AddSeconds(-1)) | Should -BeNullOrEmpty
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
    It 'audits native child usage before honoring a worker escalation' {
        $script:ResultData.status='escalated'; $script:ResultData.verification.passed=$false
        Write-TeamData (Join-Path $script:ResultDir 'result.yaml') $script:ResultData
        Write-TeamData (Join-Path $script:ResultDir 'exit.json') @{exit_code=0}
        Write-TeamData (Join-Path $script:ResultDir 'agents.json') @{agents=@(@{depth=0;state='created'},@{depth=1;state='created'})}
        $script:Item['agent_limit']=3; $script:Item['reserved']=0
        $script:TaskData.subagents.allowed=$true
        $state=@{tasks=@{T1=$script:Item};run_id='R1'}
        Assert-Code { Complete-TeamWorker $state $script:TaskData $script:ResultDir } 82
        Test-Path (Join-Path $script:ResultDir 'escalations') | Should -BeFalse
    }
    It 'extracts one terminal Result Packet from plain stdout while rejecting ambiguous or invalid output' {
        $path=Join-Path $script:ResultDir 'worker.stdout'
        $json=$script:ResultData | ConvertTo-Json -Depth 30
        [IO.File]::WriteAllText($path,"Checks completed.`n`n$json")
        $parsed=Read-TeamWorkerOutput $path
        $parsed.format | Should -Be 'plain-prefix-final-json'
        $parsed.packet.git.commit | Should -Be $script:Head
        $parsed.stdout_sha256 | Should -Be (Get-TeamHash $path)
        [IO.File]::WriteAllText($path,"$json`n$json")
        Assert-Code { Read-TeamWorkerOutput $path } 10
        [IO.File]::WriteAllText($path,"Checks completed.`n{bad json}")
        Assert-Code { Read-TeamWorkerOutput $path } 10
        [IO.File]::WriteAllText($path,"Checks completed.`n{`"status`":`"completed`"}")
        Assert-Code { Read-TeamWorkerOutput $path } 10
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
