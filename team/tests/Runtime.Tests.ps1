BeforeAll {
    $script:TeamPath = Split-Path $PSScriptRoot -Parent
    . (Join-Path $script:TeamPath 'scripts/Core.ps1')
    $script:OriginalPath = $env:PATH
    $script:OriginalDshHome = $env:DSH_HOME
    $env:PATH = (Join-Path $PSScriptRoot 'fixtures') + [IO.Path]::PathSeparator + $env:PATH
    $env:DSH_HOME = Join-Path $TestDrive 'empty-dsh-home'
    New-Item -ItemType Directory $env:DSH_HOME | Out-Null
    function Invoke-Cli([string[]]$Arguments) {
        $text = & pwsh -NoProfile -File (Join-Path $script:TeamPath 'scripts/team.ps1') @Arguments
        $code = $LASTEXITCODE
        return @{code=$code;data=($text | ConvertFrom-Json -AsHashtable);raw=($text -join "`n")}
    }
    function New-RuntimeFixture([int]$Count=1) {
        $repo = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory $repo | Out-Null
        $null = Invoke-TeamGit $repo @('init','-q','-b','main')
        $null = Invoke-TeamGit $repo @('config','user.name','TeamFixture')
        $null = Invoke-TeamGit $repo @('config','user.email','fixture@example.invalid')
        Set-Content -LiteralPath (Join-Path $repo '.gitignore') -Value "team/runtime/`n.worktrees/"
        $null = Invoke-TeamGit $repo @('add','.gitignore')
        $null = Invoke-TeamGit $repo @('commit','-qm','test: fixture')
        $plan = Read-TeamData (Join-Path $script:TeamPath 'tests/plans/L1-sql.yaml')
        $plan.run.id = 'FIXTURE'; $plan.mode = if ($Count -eq 1) {'L1'} else {'L2'}
        $template = $plan.tasks[0] | ConvertTo-Json -Depth 30
        $plan.tasks = @(1..$Count | ForEach-Object {
            $task = ConvertFrom-Json $template -AsHashtable
            $task.id="T$_"; $task.objective=@('WRITE'); $task.write_scope=@("files/T$_.txt")
            $task.verification=@(@{id='exists';executable='pwsh';args=@('-NoProfile','-Command',"if (-not (Test-Path files/T$_.txt)) { exit 1 }");timeout_seconds=10})
            $task
        })
        $plan.verification.final = @(@{id='all';executable='pwsh';args=@('-NoProfile','-Command',"if (@(Get-ChildItem files).Count -ne $Count) { exit 1 }");timeout_seconds=10})
        $planPath = Join-Path $TestDrive ('plan-' + [guid]::NewGuid().ToString('N') + '.json')
        Write-TeamData $planPath $plan
        return @{repo=$repo;plan=$plan;path=$planPath;base=(Invoke-TeamGit $repo @('rev-parse','HEAD'))}
    }
    function State($Fixture) { Read-TeamData (Join-Path $Fixture.repo 'team/runtime/FIXTURE/state.json') }
    function Accept-All($Fixture) {
        $state = State $Fixture
        foreach ($id in $state.tasks.Keys) {
            if ($state.tasks[$id].status -eq 'REVIEW') {
                $result = Invoke-Cli @('accept','-Repo',$Fixture.repo,'-Run','FIXTURE','-Task',$id,'-Commit',$state.tasks[$id].commit,'-Reason','Synthetic fixture acceptance','-Json')
                $result.code | Should -Be 0 -Because $result.raw
            }
        }
    }
}
AfterAll { $env:PATH=$script:OriginalPath; $env:DSH_HOME=$script:OriginalDshHome }

Describe 'End-to-end CLI on isolated Git with synthetic native executables' {
    It 'recovers after an actual coordinator process crash without duplicating its orphan worker' {
        $f=New-RuntimeFixture; $f.plan.tasks[0].objective=@('WAIT_FOR_RELEASE'); Write-TeamData $f.path $f.plan
        $handle=New-TeamProcess 'pwsh' @('-NoProfile','-File',(Join-Path $script:TeamPath 'scripts/team.ps1'),'run','-Repo',$f.repo,'-Plan',$f.path,'-Json') $f.repo (Join-Path $TestDrive 'crash-out') (Join-Path $TestDrive 'crash-err')
        try {
            $deadline=[datetime]::UtcNow.AddSeconds(15)
            do {
                Start-Sleep -Milliseconds 100
                $statePath=Join-Path $f.repo 'team/runtime/FIXTURE/state.json'
                $started=$false
                if (Test-Path $statePath) {
                    $s=State $f
                    $started=$s.tasks.T1.pid -gt 0 -and (Test-Path (Join-Path $s.tasks.T1.directory 'native-process.json'))
                }
            } while (-not $started -and [datetime]::UtcNow -lt $deadline)
            $started | Should -BeTrue
            # Terminate only the test coordinator, deliberately preserving its worker process tree.
            $handle.process.Kill(); $handle.process.WaitForExit()
            (State $f).tasks.T1.status | Should -Be 'RUNNING'
            $r=Invoke-Cli @('resume','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 80 -Because $r.raw
            (State $f).tasks.T1.attempts | Should -Be 1
            (State $f).tasks.T1.status | Should -Be 'RUNNING' -Because $r.raw
            Set-Content (Join-Path $s.tasks.T1.directory 'release.test') 'continue'
            $deadline=[datetime]::UtcNow.AddSeconds(15)
            do { Start-Sleep -Milliseconds 100 } while (-not (Test-Path (Join-Path $s.tasks.T1.directory 'exit.json')) -and [datetime]::UtcNow -lt $deadline)
            Test-Path (Join-Path $s.tasks.T1.directory 'exit.json') | Should -BeTrue
            $original=Get-Process -Id $s.tasks.T1.pid -ErrorAction SilentlyContinue
            if ($original) { $original.WaitForExit(5000) | Should -BeTrue }
            # Orphans can inherit redirected pipe handles; drain them only after the worker exits.
            $null=Close-TeamProcess $handle; $handle=$null
            (State $f).tasks.T1.status | Should -Be 'RUNNING' -Because ((Get-Content (Join-Path $f.repo 'team/runtime/FIXTURE/events.jsonl')) -join "`n")
            $r=Invoke-Cli @('resume','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 0 -Because $r.raw
            $s=State $f; $s.tasks.T1.status | Should -Be 'REVIEW'; $s.tasks.T1.attempts | Should -Be 1
            $s.agents_created | Should -Be 1; $s.agents_reserved | Should -Be 0
        } finally {
            if ($handle) { $null=Close-TeamProcess $handle -Terminate }
            if (Test-Path (Join-Path $f.repo 'team/runtime/FIXTURE/state.json')) {
                $null=Invoke-Cli @('stop','-Repo',$f.repo,'-Run','FIXTURE','-Json')
            }
        }
    }
    It 'rejects another run started through a linked worktree of the same repository' {
        $f=New-RuntimeFixture
        $r=Invoke-Cli @('run','-Repo',$f.repo,'-Plan',$f.path,'-Json'); $r.code | Should -Be 0
        $linked=Join-Path $TestDrive 'linked-run-root'
        $null=Invoke-TeamGit $f.repo @('worktree','add','-b','fixture-linked',$linked,$f.base)
        $f.plan.run.id='SECOND'; Write-TeamData $f.path $f.plan
        $r=Invoke-Cli @('run','-Repo',$linked,'-Plan',$f.path,'-Json'); $r.code | Should -Be 20 -Because $r.raw
        Test-Path (Join-Path $linked 'team/runtime') | Should -BeFalse
        (State $f).run_id | Should -Be 'FIXTURE'
    }
    It 'refuses to recover when event history is truncated or task state is malformed' {
        $f=New-RuntimeFixture
        $r=Invoke-Cli @('run','-Repo',$f.repo,'-Plan',$f.path,'-Json'); $r.code | Should -Be 0
        $dir=Join-Path $f.repo 'team/runtime/FIXTURE'
        $eventsPath=Join-Path $dir 'events.jsonl'; $events=[IO.File]::ReadAllText($eventsPath)
        [IO.File]::AppendAllText($eventsPath,'{"event":')
        $r=Invoke-Cli @('resume','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 80 -Because $r.raw
        (State $f).tasks.T1.attempts | Should -Be 1
        [IO.File]::WriteAllText($eventsPath,$events)
        $statePath=Join-Path $dir 'state.json'; $s=State $f; $s.tasks.T1.Remove('branch')
        Write-TeamData $statePath $s
        $r=Invoke-Cli @('resume','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 80 -Because $r.raw
        @((Get-ChildItem (Join-Path $dir 'tasks/T1') -Directory)).Count | Should -Be 1
    }
    It 'blocks dependent dispatch if integration HEAD moved outside its accepted checkpoint' {
        $f=New-RuntimeFixture 2; $f.plan.tasks[1].dependencies=@('T1'); Write-TeamData $f.path $f.plan
        $r=Invoke-Cli @('run','-Repo',$f.repo,'-Plan',$f.path,'-Json'); $r.code | Should -Be 0
        Accept-All $f
        $r=Invoke-Cli @('integrate','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 0
        $s=State $f
        $null=Invoke-TeamGit $s.integration_worktree @('commit','--allow-empty','-qm','test: unexpected integration change')
        $r=Invoke-Cli @('resume','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 80 -Because $r.raw
        (State $f).tasks.T2.attempts | Should -Be 0
    }
    It 'consumes live <Limit> cost receipts without killing running work or duplicating charges' -ForEach @(
        @{Limit='soft';Amount=10}, @{Limit='hard';Amount=20}
    ) {
        $f=New-RuntimeFixture 2
        $f.plan.tasks[0].objective=@('WAIT_FOR_COST'); $f.plan.tasks[1]['optional']=$true
        Write-TeamData $f.path $f.plan
        $manifest=Read-TeamData (Join-Path $script:TeamPath 'manifest.yaml'); $manifest.budget.max_active_workers=1
        $manifestPath=Join-Path $TestDrive "cost-$Limit.json"; Write-TeamData $manifestPath $manifest
        $handle=New-TeamProcess 'pwsh' @('-NoProfile','-File',(Join-Path $script:TeamPath 'scripts/team.ps1'),'run','-Repo',$f.repo,'-Plan',$f.path,'-Manifest',$manifestPath,'-Json') $f.repo (Join-Path $TestDrive "cost-$Limit-out") (Join-Path $TestDrive "cost-$Limit-err")
        try {
            $deadline=[datetime]::UtcNow.AddSeconds(15)
            do {
                Start-Sleep -Milliseconds 100
                $statePath=Join-Path $f.repo 'team/runtime/FIXTURE/state.json'
                $started=(Test-Path $statePath) -and (State $f).tasks.T1.pid -gt 0
            } while (-not $started -and [datetime]::UtcNow -lt $deadline)
            $started | Should -BeTrue
            $evidence=Join-Path $TestDrive "bill-$Limit.txt"; Set-Content $evidence "test billing $Limit"
            $r=Invoke-Cli @('report-cost','-Repo',$f.repo,'-Run','FIXTURE','-Amount',"$Amount",'-Evidence',$evidence,'-Json')
            $r.code | Should -Be 0 -Because $r.raw; $r.data.status | Should -Be 'QUEUED'
            $r=Invoke-Cli @('report-cost','-Repo',$f.repo,'-Run','FIXTURE','-Amount',"$Amount",'-Evidence',$evidence,'-Json')
            $r.code | Should -Be 10 -Because $r.raw
            Wait-TeamProcess $handle 25 | Should -Be 0
            $handle=$null
            $s=State $f; $s.status | Should -Be 'PAUSED'; $s.known_cost | Should -Be $Amount
            $s.tasks.T1.status | Should -Be 'REVIEW'; $s.tasks.T1.attempts | Should -Be 1
            $s.tasks.T2.status | Should -Be 'READY'; $s.tasks.T2.attempts | Should -Be 0
            $r=Invoke-Cli @('resume','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 0 -Because $r.raw
            (State $f).known_cost | Should -Be $Amount
            $events=Get-Content (Join-Path $f.repo 'team/runtime/FIXTURE/events.jsonl') | ForEach-Object { ConvertFrom-Json $_ }
            @($events | Where-Object event -eq "cost_${Limit}_limit_reached").Count | Should -Be 1
        } finally { if ($handle) { $null=Close-TeamProcess $handle -Terminate } }
    }
    It 'requires new owner approval when a replan expands restricted permissions' {
        $f=New-RuntimeFixture; $f.plan.tasks[0].permissions.network=$true; Write-TeamData $f.path $f.plan
        $r=Invoke-Cli @('run','-Repo',$f.repo,'-Plan',$f.path,'-Json'); $r.code | Should -Be 70
        (State $f).tasks.T1.attempts | Should -Be 0
        $r=Invoke-Cli @('escalations','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $id=@($r.data)[0].id
        $r=Invoke-Cli @('resolve','-Repo',$f.repo,'-Run','FIXTURE','-Escalation',$id,'-Decision','approve','-Reason','Fixture owner permits this network scope','-Json'); $r.code | Should -Be 0
        $r=Invoke-Cli @('resume','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 0 -Because $r.raw
        $f.plan.run.revision=2; $f.plan.tasks[0].permissions.secrets=$true; Write-TeamData $f.path $f.plan
        $r=Invoke-Cli @('replan','-Repo',$f.repo,'-Run','FIXTURE','-Plan',$f.path,'-Task','T1','-Reason','Fixture adds secret permission','-Json'); $r.code | Should -Be 0
        $r=Invoke-Cli @('resume','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 70 -Because $r.raw
        (State $f).tasks.T1.attempts | Should -Be 1
        $r=Invoke-Cli @('escalations','-Repo',$f.repo,'-Run','FIXTURE','-Json')
        @($r.data | Where-Object status -eq 'pending').Count | Should -Be 1
        @($r.data | Where-Object status -eq 'approve')[0].plan_hash | Should -Not -Be (State $f).plan_hash
    }
    It 'does not treat modify-plan as approval and keeps expired escalation paused' {
        $f=New-RuntimeFixture; $f.plan.tasks[0].permissions.network=$true; Write-TeamData $f.path $f.plan
        $r=Invoke-Cli @('run','-Repo',$f.repo,'-Plan',$f.path,'-Json'); $r.code | Should -Be 70
        $dir=Join-Path $f.repo 'team/runtime/FIXTURE'
        $recordFile=@(Get-ChildItem (Join-Path $dir 'escalations') -Filter '*.yaml')[0].FullName
        $record=Read-TeamData $recordFile; $record.expires_at=[DateTime]::UtcNow.AddHours(-1).ToString('o'); Write-TeamData $recordFile $record
        $r=Invoke-Cli @('resume','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 70
        (State $f).status | Should -Be 'PAUSED'; (State $f).tasks.T1.attempts | Should -Be 0
        @(Get-ChildItem (Join-Path $dir 'escalations') -Filter '*.yaml').Count | Should -Be 1
        $r=Invoke-Cli @('resolve','-Repo',$f.repo,'-Run','FIXTURE','-Escalation',$record.id,'-Decision','modify-plan','-Reason','Remove network access','-Json'); $r.code | Should -Be 0
        $r=Invoke-Cli @('resume','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 70
        (State $f).tasks.T1.attempts | Should -Be 0
        $f.plan.run.revision=2; $f.plan.tasks[0].permissions.network=$false; Write-TeamData $f.path $f.plan
        $r=Invoke-Cli @('replan','-Repo',$f.repo,'-Run','FIXTURE','-Plan',$f.path,'-Task','T1','-Reason','Remove restricted permission','-Json'); $r.code | Should -Be 0
        $r=Invoke-Cli @('resume','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 0 -Because $r.raw
        (State $f).tasks.T1.status | Should -Be 'REVIEW'
    }
    It 'hard-stops a destructive action introduced by replan before another worker starts' {
        $f=New-RuntimeFixture
        $r=Invoke-Cli @('run','-Repo',$f.repo,'-Plan',$f.path,'-Json'); $r.code | Should -Be 0
        $f.plan.run.revision=2; $f.plan['risk_flags']=@('production_delete'); Write-TeamData $f.path $f.plan
        $r=Invoke-Cli @('replan','-Repo',$f.repo,'-Run','FIXTURE','-Plan',$f.path,'-Task','T1','-Reason','Synthetic destructive flag','-Json'); $r.code | Should -Be 0
        $r=Invoke-Cli @('resume','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 60 -Because $r.raw
        (State $f).hard_stop | Should -BeTrue; (State $f).tasks.T1.attempts | Should -Be 1
    }
    It 'runs a concurrent DAG, preserves main, integrates dependencies and cleans only merged worktrees' {
        $f = New-RuntimeFixture 3
        $f.plan.tasks[2].dependencies=@('T1','T2'); Write-TeamData $f.path $f.plan
        $r = Invoke-Cli @('run','-Repo',$f.repo,'-Plan',$f.path,'-Json')
        $r.code | Should -Be 0 -Because $r.raw
        $s = State $f; $s.tasks.T1.status | Should -Be 'REVIEW'; $s.tasks.T2.status | Should -Be 'REVIEW'; $s.tasks.T3.status | Should -Be 'READY'
        $s.tasks.T1.base_sha | Should -Be $f.base; $s.tasks.T2.base_sha | Should -Be $f.base
        (Invoke-TeamGit $f.repo @('rev-parse','main')) | Should -Be $f.base
        $r = Invoke-Cli @('run','-Repo',$f.repo,'-Plan',$f.path,'-Json'); $r.code | Should -Be 20
        Accept-All $f
        $r = Invoke-Cli @('integrate','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 0 -Because $r.raw
        $integration = (State $f).last_good_integration_sha
        $r = Invoke-Cli @('resume','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 0 -Because $r.raw
        (State $f).tasks.T3.base_sha | Should -Be $integration
        Accept-All $f
        $r = Invoke-Cli @('integrate','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 0 -Because $r.raw
        $r.data.status | Should -Be 'COMPLETED'
        (State $f).agents_created | Should -Be 3
        (Invoke-TeamGit $f.repo @('rev-parse','main')) | Should -Be $f.base
        $r = Invoke-Cli @('cleanup','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 0 -Because $r.raw
        $r.data.removed.Count | Should -Be 3
    }
    It 'rejects schema errors without creating runtime or worktrees' {
        $f=New-RuntimeFixture; $f.plan.tasks[0].dependencies=@('T1'); Write-TeamData $f.path $f.plan
        $r=Invoke-Cli @('run','-Repo',$f.repo,'-Plan',$f.path,'-Json')
        $r.code | Should -Be 10
        Test-Path (Join-Path $f.repo '.worktrees') | Should -BeFalse
        Test-Path (Join-Path $f.repo 'team/runtime') | Should -BeFalse
    }
    It 'rejects scope violations from actual Git and preserves evidence' {
        $f=New-RuntimeFixture; $f.plan.tasks[0].objective=@('SCOPE'); Write-TeamData $f.path $f.plan
        $r=Invoke-Cli @('run','-Repo',$f.repo,'-Plan',$f.path,'-Json')
        $r.code | Should -Be 82 -Because $r.raw
        (State $f).tasks.T1.status | Should -Be 'FAILED_SCOPE'
        Test-Path (State $f).tasks.T1.worktree | Should -BeTrue
    }
    It 'wires 9P before workers, 9A before acceptance and 9B before completion' {
        $f=New-RuntimeFixture; $f.plan.classification.level='critical'; $f.plan.review.require_9p=$true; $f.plan.review.require_fresh_9b=$true
        Write-TeamData $f.path $f.plan
        $r=Invoke-Cli @('run','-Repo',$f.repo,'-Plan',$f.path,'-Json'); $r.code | Should -Be 0 -Because $r.raw
        $dir=Join-Path $f.repo 'team/runtime/FIXTURE'
        Test-Path (Join-Path $dir 'reviews/9P.json') | Should -BeTrue
        Test-Path (Join-Path $dir 'reviews/9A-T1.json') | Should -BeTrue
        Accept-All $f
        $r=Invoke-Cli @('integrate','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 0 -Because $r.raw
        Test-Path (Join-Path $dir 'reviews/9B.json') | Should -BeTrue
        $r.data.status | Should -Be 'COMPLETED'
    }
    It 'rejects wrong route and unverified versions before dispatch' {
        $f=New-RuntimeFixture
        $config=Read-TeamData (Join-Path $script:TeamPath 'manifest.yaml'); $config.models.worker.runtime_model='wrong-model'
        $manifestPath=Join-Path $TestDrive 'wrong-manifest.json'; Write-TeamData $manifestPath $config
        $r=Invoke-Cli @('run','-Repo',$f.repo,'-Plan',$f.path,'-Manifest',$manifestPath,'-Json'); $r.code | Should -Be 20
        Test-Path (Join-Path $f.repo '.worktrees') | Should -BeFalse
        $config.models.worker.runtime_model='deepseek-flash'; $config.runtime.dsh_version='0.0.0'; Write-TeamData $manifestPath $config
        $r=Invoke-Cli @('run','-Repo',$f.repo,'-Plan',$f.path,'-Manifest',$manifestPath,'-Json'); $r.code | Should -Be 20
    }
    It 'reconciles a persisted RUNNING snapshot without duplicate worker creation' {
        $f=New-RuntimeFixture
        $r=Invoke-Cli @('run','-Repo',$f.repo,'-Plan',$f.path,'-Json'); $r.code | Should -Be 0
        $s=State $f; $s.tasks.T1.status='RUNNING'; $s.status='RUNNING'
        Write-TeamData (Join-Path $f.repo 'team/runtime/FIXTURE/state.json') $s
        $r=Invoke-Cli @('resume','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 0 -Because $r.raw
        (State $f).tasks.T1.attempts | Should -Be 1
        (State $f).agents_created | Should -Be 1
    }
    It 'replans one failed task while preserving unrelated accepted work' {
        $f=New-RuntimeFixture 2
        $r=Invoke-Cli @('run','-Repo',$f.repo,'-Plan',$f.path,'-Json'); $r.code | Should -Be 0
        Accept-All $f; $accepted=(State $f).tasks.T2.commit
        $f.plan.run.revision=2; $f.plan.tasks[0].objective=@('WRITE AGAIN'); Write-TeamData $f.path $f.plan
        $r=Invoke-Cli @('replan','-Repo',$f.repo,'-Run','FIXTURE','-Plan',$f.path,'-Task','T1','-Reason','Rework task one only','-Json')
        $r.code | Should -Be 0 -Because $r.raw
        (State $f).tasks.T2.status | Should -Be 'ACCEPTED'; (State $f).tasks.T2.commit | Should -Be $accepted
        (State $f).tasks.T1.status | Should -Be 'READY'
    }
    It 'creates a bounded integration worker for a real merge conflict' {
        $f=New-RuntimeFixture 2
        foreach ($task in $f.plan.tasks) {
            $task.write_scope=@('files/shared.txt')
            $task.verification[0].args=@('-NoProfile','-Command',"if (-not (Test-Path files/shared.txt)) { exit 1 }")
        }
        $f.plan.verification.final[0].args=@('-NoProfile','-Command',"if ((Get-Content files/shared.txt -Raw).Trim() -ne 'INTEGRATION-1') { exit 1 }")
        Write-TeamData $f.path $f.plan
        $r=Invoke-Cli @('run','-Repo',$f.repo,'-Plan',$f.path,'-Json'); $r.code | Should -Be 0 -Because $r.raw
        Accept-All $f
        $r=Invoke-Cli @('integrate','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 81 -Because $r.raw
        $r=Invoke-Cli @('repair-integration','-Repo',$f.repo,'-Run','FIXTURE','-Reason','Resolve shared file against accepted contracts','-Json')
        $r.code | Should -Be 0 -Because $r.raw
        $r=Invoke-Cli @('resume','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 0 -Because $r.raw
        Accept-All $f
        $r=Invoke-Cli @('integrate','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 0 -Because $r.raw
        $r.data.status | Should -Be 'COMPLETED'
    }
    It 'stops only its own running worker tree and retains the run evidence' {
        $f=New-RuntimeFixture; $f.plan.tasks[0].objective=@('SLEEP'); Write-TeamData $f.path $f.plan
        $handle=New-TeamProcess 'pwsh' @('-NoProfile','-File',(Join-Path $script:TeamPath 'scripts/team.ps1'),'run','-Repo',$f.repo,'-Plan',$f.path,'-Json') $f.repo (Join-Path $TestDrive 'stop-out') (Join-Path $TestDrive 'stop-err')
        try {
            $deadline=[datetime]::UtcNow.AddSeconds(15)
            do {
                Start-Sleep -Milliseconds 200
                $statePath=Join-Path $f.repo 'team/runtime/FIXTURE/state.json'
                $started=(Test-Path $statePath) -and (State $f).tasks.T1.pid -gt 0
            } while (-not $started -and [datetime]::UtcNow -lt $deadline)
            $started | Should -BeTrue
            $r=Invoke-Cli @('stop','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 0 -Because $r.raw
            Wait-TeamProcess $handle 15 | Should -Be 0
            $handle=$null
            (State $f).status | Should -Be 'CANCELLED'
            Test-Path (Join-Path $f.repo 'team/runtime/FIXTURE/state.json') | Should -BeTrue
            Test-Path (Join-Path $f.repo 'team/runtime/.team-lock') | Should -BeFalse
        } finally { if ($handle) { $null=Close-TeamProcess $handle -Terminate } }
    }
    It 'refuses dispatch while disabled and enforces hard-budget pause' {
        $f=New-RuntimeFixture
        $manifest=Read-TeamData (Join-Path $script:TeamPath 'manifest.yaml')
        $manifest.team.enabled=$false; $path=Join-Path $TestDrive 'disabled.json'; Write-TeamData $path $manifest
        $r=Invoke-Cli @('run','-Repo',$f.repo,'-Plan',$f.path,'-Manifest',$path,'-Json'); $r.code | Should -Be 20
        Test-Path (Join-Path $f.repo 'team/runtime') | Should -BeFalse
        $manifest.team.enabled=$true; $manifest.budget.soft_limit=0; $manifest.budget.hard_limit=0; Write-TeamData $path $manifest
        $r=Invoke-Cli @('run','-Repo',$f.repo,'-Plan',$f.path,'-Manifest',$path,'-Json'); $r.code | Should -Be 0
        (State $f).status | Should -Be 'PAUSED'
        (State $f).tasks.T1.attempts | Should -Be 0
    }
    It 'rolls back a merge whose targeted regression failed, preserving main' {
        $f=New-RuntimeFixture
        $f.plan.tasks[0].verification[0].args=@('-NoProfile','-Command','if ((Get-Location).Path.EndsWith("-integration")) { exit 9 }')
        Write-TeamData $f.path $f.plan
        $r=Invoke-Cli @('run','-Repo',$f.repo,'-Plan',$f.path,'-Json'); $r.code | Should -Be 0 -Because $r.raw
        Accept-All $f
        $r=Invoke-Cli @('integrate','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 40 -Because $r.raw
        $checkpoint=Read-TeamData (Join-Path $f.repo 'team/runtime/FIXTURE/checkpoints/T1.json')
        $checkpoint.verified | Should -BeFalse
        $r=Invoke-Cli @('rollback','-Repo',$f.repo,'-Run','FIXTURE','-Task','T1','-Reason','Targeted regression failed','-Json')
        $r.code | Should -Be 0 -Because $r.raw
        (State $f).tasks.T1.status | Should -Be 'REWORK'
        (Invoke-TeamGit $f.repo @('rev-parse','main')) | Should -Be $f.base
        Test-Path (Join-Path (State $f).integration_worktree 'files/T1.txt') | Should -BeFalse
    }
}
