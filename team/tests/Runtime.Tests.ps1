BeforeAll {
    . (Join-Path $PSScriptRoot "LeadFixture.ps1")
    $script:LeadEnvironment=Enable-TeamLeadFixture $TestDrive
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
AfterAll { Restore-TeamLeadFixture $script:LeadEnvironment; $env:PATH=$script:OriginalPath; $env:DSH_HOME=$script:OriginalDshHome }

Describe 'End-to-end CLI on isolated Git with synthetic native executables' {
    It 'keeps an optional ancestor of a required task runnable at the soft limit' {
        $f=New-RuntimeFixture 2; $f.plan.tasks[0]['optional']=$true; $f.plan.tasks[1].dependencies=@('T1'); Write-TeamData $f.path $f.plan
        $manifest=Read-TeamData (Join-Path $script:TeamPath 'manifest.yaml'); $manifest.budget.ledgers.deepseek.soft_limit=0
        $path=Join-Path $TestDrive 'soft-required-ancestor.json'; Write-TeamData $path $manifest
        $r=Invoke-Cli @('run','-Repo',$f.repo,'-Plan',$f.path,'-Manifest',$path,'-Json'); $r.code | Should -Be 0 -Because $r.raw
        (State $f).tasks.T1.status | Should -Be 'REVIEW'; (State $f).tasks.T2.status | Should -Be 'READY'
    }
    It 'refuses an unfunded replan without committing the candidate revision' {
        $f=New-RuntimeFixture
        $manifest=Read-TeamData (Join-Path $script:TeamPath 'manifest.yaml')
        $manifest.budget.max_active_workers=1; $manifest.budget.max_parallel_agents_total=2; $manifest.budget.max_agents_per_run=2
        $path=Join-Path $TestDrive 'replan-minimum.json'; Write-TeamData $path $manifest
        $r=Invoke-Cli @('run','-Repo',$f.repo,'-Plan',$f.path,'-Manifest',$path,'-Json'); $r.code | Should -Be 0 -Because $r.raw
        $old=State $f; $f.plan.run.revision=2; Write-TeamData $f.path $f.plan
        $r=Invoke-Cli @('replan','-Repo',$f.repo,'-Run','FIXTURE','-Task','T1','-Plan',$f.path,'-Manifest',$path,'-Reason','Must account for already spent agents','-Json')
        $r.code | Should -Be 70 -Because $r.raw
        $current=State $f; $current.revision | Should -Be 1; $current.plan_hash | Should -Be $old.plan_hash
        $current.tasks.T1.commit | Should -Be $old.tasks.T1.commit; $current.agents_created | Should -Be 2
        Test-Path (Join-Path $f.repo 'team/runtime/FIXTURE/revision-pending.json') | Should -BeFalse
    }
    It 'finishes five required authors and reviews at the default ten-agent budget' {
        $f=New-RuntimeFixture 5
        $r=Invoke-Cli @('run','-Repo',$f.repo,'-Plan',$f.path,'-Json'); $r.code | Should -Be 0 -Because $r.raw
        # Dispatch returns at a Lead decision point after its active wave drains.
        if (@((State $f).tasks.Values | Where-Object status -eq 'READY').Count) {
            $r=Invoke-Cli @('resume','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 0 -Because $r.raw
        }
        $state=State $f; $state.agents_created | Should -Be 10; $state.agents_reserved | Should -Be 0
        @($state.tasks.Values | Where-Object status -eq 'REVIEW').Count | Should -Be 5
        Accept-All $f
        $r=Invoke-Cli @('integrate','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 0 -Because $r.raw
        $r.data.status | Should -Be 'COMPLETED'
    }
    It 'rejects oversized local review authority without charging a reviewer' {
        $f=New-RuntimeFixture
        Set-Content (Join-Path $f.repo 'AGENTS.md') ('Base authority. '*2000)
        $null=Invoke-TeamGit $f.repo @('add','AGENTS.md'); $null=Invoke-TeamGit $f.repo @('commit','-qm','test: large base authority')
        $r=Invoke-Cli @('run','-Repo',$f.repo,'-Plan',$f.path,'-Json'); $r.code | Should -Be 70 -Because $r.raw
        $r.data.event | Should -Be 'input_too_large'
        $state=State $f; $state.agents_created | Should -Be 1; $state.agents_reserved | Should -Be 0
        $state.status | Should -Be 'PAUSED'
        $receipt=Read-TeamData (Join-Path $state.tasks.T1.local_review.directory 'exit.json')
        $receipt.input_too_large | Should -BeTrue; $receipt.launch_attempts | Should -Be 0
        Test-Path (Join-Path $state.tasks.T1.local_review.directory 'native-process.json') | Should -BeFalse
    }
    It 'reviews governance against frozen base rules and accepts durable evidence after raw loss' {
        $f=New-RuntimeFixture
        Set-Content (Join-Path $f.repo 'AGENTS.md') 'BASE_RULE: inspect changes independently.'
        $null=Invoke-TeamGit $f.repo @('add','AGENTS.md'); $null=Invoke-TeamGit $f.repo @('commit','-qm','test: seed governing rules')
        $f.plan.tasks[0].objective=@('GOVERNANCE'); $f.plan.tasks[0].write_scope=@('AGENTS.md')
        $f.plan.tasks[0].verification[0].args=@('-NoProfile','-Command','if ((Get-Content AGENTS.md -Raw) -notmatch "TIP_RULE") {exit 1}')
        $f.plan.verification.final=$f.plan.tasks[0].verification; Write-TeamData $f.path $f.plan
        $r=Invoke-Cli @('run','-Repo',$f.repo,'-Plan',$f.path,'-Json'); $r.code | Should -Be 0 -Because $r.raw
        $dir=Join-Path $f.repo 'team/runtime/FIXTURE'; $state=State $f
        foreach($label in @('LOCAL-T1','9A-T1')) {
            $record=Read-TeamData (Join-Path $dir "reviews/$label.json")
            $record.holding.StartsWith((Join-Path $env:CODEX_HOME 'team-review-holding')) | Should -BeTrue
            $prompt=Get-Content (Join-Path $record.holding 'prompt.txt') -Raw
            $authorityPart=($prompt -split 'Frozen AGENTS authority:',2)[1] -split '(External verification:|Worker-declared risks)',2
            $authorityPart[0] | Should -Match 'BASE_RULE'; $authorityPart[0] | Should -Not -Match 'TIP_RULE'
            $prompt | Should -Match 'TIP_RULE'; $prompt | Should -Match 'FIXTURE_WORKER_RISK'
            [IO.File]::Delete((Join-Path $record.holding 'verdict.json'))
            [IO.File]::Delete((Join-Path $record.holding 'prompt.txt'))
        }
        Accept-All $f
        $r=Invoke-Cli @('integrate','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 0 -Because $r.raw
        $r.data.status | Should -Be 'COMPLETED'
    }
    It 'rejects oversized worker input without native launches or agent charges' {
        $f=New-RuntimeFixture; $f.plan.tasks[0].objective=@('x'*25000); Write-TeamData $f.path $f.plan
        $r=Invoke-Cli @('run','-Repo',$f.repo,'-Plan',$f.path,'-Json'); $r.code | Should -Be 70 -Because $r.raw
        $r.data.event | Should -Be 'input_too_large'
        $state=State $f; $state.status | Should -Be 'PAUSED'; $state.agents_created | Should -Be 0; $state.agents_reserved | Should -Be 0
        $receipt=Read-TeamData (Join-Path $state.tasks.T1.directory 'exit.json')
        $receipt.input_too_large | Should -BeTrue; $receipt.launch_attempts | Should -Be 0
        Test-Path (Join-Path $state.tasks.T1.directory 'native-process.json') | Should -BeFalse
    }
    It 'reserves mandatory reviewer capacity before admitting L3 fan-out' {
        $f=New-RuntimeFixture; $f.plan.mode='L3'; $f.plan.tasks[0].subagents=@{allowed=$true;max_depth=2}; Write-TeamData $f.path $f.plan
        $manifest=Read-TeamData (Join-Path $script:TeamPath 'manifest.yaml')
        $manifest.budget.max_active_workers=1; $manifest.budget.max_parallel_agents_total=3; $manifest.budget.max_agents_per_run=3
        $path=Join-Path $TestDrive 'tight-agent-budget.json'; Write-TeamData $path $manifest
        $r=Invoke-Cli @('run','-Repo',$f.repo,'-Plan',$f.path,'-Manifest',$path,'-Json'); $r.code | Should -Be 0 -Because $r.raw
        $state=State $f; $state.tasks.T1.status | Should -Be 'REVIEW'; $state.agents_created | Should -Be 2
        (Read-TeamData (Join-Path $state.tasks.T1.directory 'task.yaml')).subagents.allowed | Should -BeFalse
    }
    It 'freezes a run-local role through dispatch, replan, and resume' {
        $f=New-RuntimeFixture
        $role=Read-TeamData (Join-Path $script:TeamPath 'roles/database.yaml'); $role.role_id='custom-query'
        $f.plan['dynamic_roles']=@{'custom-query'=$role}; $f.plan.tasks[0].role='custom-query'
        Write-TeamData $f.path $f.plan
        $r=Invoke-Cli @('run','-Repo',$f.repo,'-Plan',$f.path,'-Json')
        $r.code | Should -Be 0 -Because $r.raw
        $s=State $f; $s.tasks.T1.status | Should -Be 'REVIEW'
        $packet=Read-TeamData (Join-Path $s.tasks.T1.directory 'task.yaml')
        $packet.role.definition.role_id | Should -Be 'custom-query'
        $f.plan.run.revision=2
        $f.plan.dynamic_roles.'custom-query'.guidance+=@('Check query performance')
        Write-TeamData $f.path $f.plan
        $r=Invoke-Cli @('replan','-Repo',$f.repo,'-Run','FIXTURE','-Task','T1','-Plan',$f.path,'-Reason','Change role specialization','-Json')
        $r.code | Should -Be 10 -Because $r.raw
        $newRole=$f.plan.dynamic_roles.'custom-query'; $newRole.role_id='custom-query-v2'
        $f.plan.dynamic_roles=@{'custom-query-v2'=$newRole}; $f.plan.tasks[0].role='custom-query-v2'
        Write-TeamData $f.path $f.plan
        $r=Invoke-Cli @('replan','-Repo',$f.repo,'-Run','FIXTURE','-Task','T1','-Plan',$f.path,'-Reason','New role identity preserves prior evidence','-Json')
        $r.code | Should -Be 0 -Because $r.raw
        $r=Invoke-Cli @('resume','-Repo',$f.repo,'-Run','FIXTURE','-Json')
        $r.code | Should -Be 0 -Because $r.raw
        $s=State $f; $s.tasks.T1.status | Should -Be 'REVIEW'
        (Read-TeamData (Join-Path $s.tasks.T1.directory 'task.yaml')).role.definition.role_id | Should -Be 'custom-query-v2'
        $dir=Join-Path $f.repo 'team/runtime/FIXTURE/roles'
        Test-Path (Join-Path $dir 'custom-query.yaml') | Should -BeTrue
        Test-Path (Join-Path $dir 'custom-query-v2.yaml') | Should -BeTrue
    }
    It 'refuses an unidentified Lead before creating run state or worktrees' {
        $f=New-RuntimeFixture; $saved=$env:CODEX_THREAD_ID
        try {
            $env:CODEX_THREAD_ID=''
            $r=Invoke-Cli @('run','-Repo',$f.repo,'-Plan',$f.path,'-Json')
            $r.code | Should -Be 20 -Because $r.raw
            Test-Path (Join-Path $f.repo 'team/runtime/FIXTURE') | Should -BeFalse
            Test-Path (Join-Path $f.repo '.worktrees') | Should -BeFalse
        } finally { $env:CODEX_THREAD_ID=$saved }
    }
    It 'keeps observation collections valid and follows paused runs until cancellation' {
        $f=New-RuntimeFixture
        $r=Invoke-Cli @('run','-Repo',$f.repo,'-Plan',$f.path,'-Json')
        $r.code | Should -Be 0 -Because $r.raw
        $r=Invoke-Cli @('logs','-Repo',$f.repo,'-Run','FIXTURE','-Task','T1','-Json')
        $r.code | Should -Be 0; $r.raw | Should -Match '^\['
        @($r.data).Count | Should -BeGreaterThan 1
        @($r.data | Where-Object {$_.details.task_id -ne 'T1'}).Count | Should -Be 0
        $since=([datetime]$r.data[-1].timestamp).ToUniversalTime().ToString('o')
        $r=Invoke-Cli @('logs','-Repo',$f.repo,'-Run','FIXTURE','-Task','T1','-Since',$since,'-Json')
        $r.raw | Should -Match '^\['; @($r.data).Count | Should -Be 1
        $r=Invoke-Cli @('logs','-Repo',$f.repo,'-Run','FIXTURE','-Since','2099-01-01T00:00:00Z','-Json')
        $r.code | Should -Be 0; $r.raw | Should -Be '[]'
        $r=Invoke-Cli @('escalations','-Repo',$f.repo,'-Run','FIXTURE','-Json')
        $r.raw | Should -Be '[]'
        $r=Invoke-Cli @('watch','-Repo',$f.repo,'-Run','FIXTURE','-Since','2099-01-01T00:00:00Z','-Json')
        $r.code | Should -Be 0; $r.data.status | Should -Be 'PAUSED'
        $stdout=Join-Path $TestDrive 'watch.out'
        $handle=New-TeamProcess 'pwsh' @('-NoProfile','-File',(Join-Path $script:TeamPath 'scripts/team.ps1'),'watch','-Repo',$f.repo,'-Run','FIXTURE','-Task','T1','-Since',$since,'-Follow','-Json') $f.repo $stdout (Join-Path $TestDrive 'watch.err')
        try {
            Start-Sleep -Seconds 3
            $handle.process.HasExited | Should -BeFalse
            $r=Invoke-Cli @('stop','-Repo',$f.repo,'-Run','FIXTURE','-Json')
            $r.code | Should -Be 0
            Wait-TeamProcess $handle 10 | Should -Be 0; $handle=$null
            $entries=@(Get-Content $stdout | ForEach-Object {ConvertFrom-Json $_ -AsHashtable})
            $entries[-1].status | Should -Be 'CANCELLED'
            @($entries | Where-Object {$_['event']}).Count | Should -Be 1
        } finally {
            $null=Invoke-Cli @('stop','-Repo',$f.repo,'-Run','FIXTURE','-Json')
            if ($handle -and -not $handle['closed']) { $null=Close-TeamProcess $handle -Terminate }
        }
    }
    It 'lets a parallel author finish when another local review requests evidence' {
        $f=New-RuntimeFixture 2
        $f.plan.tasks[0].objective=@('LOCAL_VN'); $f.plan.tasks[1].objective=@('WAIT_FOR_RELEASE')
        Write-TeamData $f.path $f.plan
        $handle=New-TeamProcess 'pwsh' @('-NoProfile','-File',(Join-Path $script:TeamPath 'scripts/team.ps1'),'run','-Repo',$f.repo,'-Plan',$f.path,'-Json') $f.repo (Join-Path $TestDrive 'parallel-review.out') (Join-Path $TestDrive 'parallel-review.err')
        try {
            $deadline=[datetime]::UtcNow.AddSeconds(25); $ready=$false
            do {
                Start-Sleep -Milliseconds 100
                if (Test-Path (Join-Path $f.repo 'team/runtime/FIXTURE/state.json')) {
                    $s=State $f; $ready=$s.tasks.T1.status -eq 'LOCAL_REVIEW' -and $s.status -eq 'ESCALATED'
                }
            } while (-not $ready -and [datetime]::UtcNow -lt $deadline)
            $ready | Should -BeTrue
            $native=Read-TeamData (Join-Path $s.tasks.T2.directory 'native-process.json')
            $live=Get-TeamOwnedProcess $native.pid $native.start
            $live | Should -Not -BeNullOrEmpty
            if ($live) { $live.Dispose() }
            Set-Content (Join-Path $s.tasks.T2.directory 'release.test') 'continue'
            Wait-TeamProcess $handle 20 | Should -Be 70
            $handle=$null
            $s=State $f; $s.status | Should -Be 'ESCALATED'; $s.tasks.T2.status | Should -Be 'RESULT_READY'
            (Read-TeamData (Join-Path $s.tasks.T2.directory 'exit.json')).exit_code | Should -Be 0
            Test-Path (Join-Path $f.repo 'team/runtime/FIXTURE/reviews/LOCAL-T2.json') | Should -BeFalse
            $disposition=Join-Path $TestDrive 'parallel-review-vn.json'
            Write-TeamData $disposition @(@{index=0;action='verify';reason='Check the requested fixture fact';command=@{id='fact';executable='pwsh';args=@('-NoProfile','-Command','exit 0');timeout_seconds=10}})
            $r=Invoke-Cli @('resolve-review','-Repo',$f.repo,'-Run','FIXTURE','-Task','T1','-Stage','LOCAL','-Disposition',$disposition,'-Json')
            $r.code | Should -Be 0 -Because $r.raw
            $r=Invoke-Cli @('resume','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 0 -Because $r.raw
            $s=State $f; $s.agents_created | Should -Be 4; $s.agents_reserved | Should -Be 0
            foreach ($item in $s.tasks.Values) { $item.status | Should -Be 'REVIEW'; $item.attempts | Should -Be 1 }
            Accept-All $f
            $r=Invoke-Cli @('integrate','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 0 -Because $r.raw
            $r.data.status | Should -Be 'COMPLETED'
        } finally {
            if (Test-Path (Join-Path $f.repo 'team/runtime/FIXTURE/state.json')) { $null=Invoke-Cli @('stop','-Repo',$f.repo,'-Run','FIXTURE','-Json') }
            if ($handle -and -not $handle['closed']) { $null=Close-TeamProcess $handle -Terminate }
        }
    }
    It 'recovers a live local reviewer after coordinator crash without launching it twice' {
        $f=New-RuntimeFixture; $f.plan.tasks[0].objective=@('LOCAL_WAIT'); Write-TeamData $f.path $f.plan
        $handle=New-TeamProcess 'pwsh' @('-NoProfile','-File',(Join-Path $script:TeamPath 'scripts/team.ps1'),'run','-Repo',$f.repo,'-Plan',$f.path,'-Json') $f.repo (Join-Path $TestDrive 'local-crash-out') (Join-Path $TestDrive 'local-crash-err')
        try {
            $deadline=[datetime]::UtcNow.AddSeconds(25); $ready=$false
            do {
                Start-Sleep -Milliseconds 100
                if (Test-Path (Join-Path $f.repo 'team/runtime/FIXTURE/state.json')) {
                    $s=State $f
                    $ready=$s.tasks.T1['local_review'] -and (Test-Path (Join-Path $s.tasks.T1.local_review.directory 'agents.json'))
                }
            } while (-not $ready -and [datetime]::UtcNow -lt $deadline)
            $ready | Should -BeTrue
            $review=$s.tasks.T1.local_review
            $handle.process.Kill(); $handle.process.WaitForExit()
            $r=Invoke-Cli @('resume','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 80 -Because $r.raw
            Set-Content (Join-Path $review.directory 'release.test') 'continue'
            $deadline=[datetime]::UtcNow.AddSeconds(15)
            do { Start-Sleep -Milliseconds 100 } while (-not (Test-Path (Join-Path $review.directory 'exit.json')) -and [datetime]::UtcNow -lt $deadline)
            Test-Path (Join-Path $review.directory 'exit.json') | Should -BeTrue
            $adapter=Get-TeamOwnedProcess $review.pid $review.process_start
            if ($adapter) { $adapter.WaitForExit(5000) | Should -BeTrue }
            $null=Close-TeamProcess $handle; $handle=$null
            $r=Invoke-Cli @('resume','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 0 -Because $r.raw
            $s=State $f; $s.tasks.T1.status | Should -Be 'REVIEW'; $s.tasks.T1.attempts | Should -Be 1
            $s.tasks.T1.local_review.directory | Should -Be $review.directory
            $s.agents_created | Should -Be 2; $s.agents_reserved | Should -Be 0
            Accept-All $f
        } finally {
            if ($handle) { $null=Close-TeamProcess $handle -Terminate }
            if (Test-Path (Join-Path $f.repo 'team/runtime/FIXTURE/state.json')) { $null=Invoke-Cli @('stop','-Repo',$f.repo,'-Run','FIXTURE','-Json') }
        }
    }
    It 'honors stop during a local review and releases only its owned processes and reservation' {
        $f=New-RuntimeFixture; $f.plan.tasks[0].objective=@('LOCAL_SLEEP'); Write-TeamData $f.path $f.plan
        $handle=New-TeamProcess 'pwsh' @('-NoProfile','-File',(Join-Path $script:TeamPath 'scripts/team.ps1'),'run','-Repo',$f.repo,'-Plan',$f.path,'-Json') $f.repo (Join-Path $TestDrive 'local-stop-out') (Join-Path $TestDrive 'local-stop-err')
        try {
            $deadline=[datetime]::UtcNow.AddSeconds(25); $ready=$false
            do {
                Start-Sleep -Milliseconds 100
                if (Test-Path (Join-Path $f.repo 'team/runtime/FIXTURE/state.json')) {
                    $s=State $f; $ready=$s.tasks.T1['local_review'] -and (Test-Path (Join-Path $s.tasks.T1.local_review.directory 'agents.json'))
                }
            } while (-not $ready -and [datetime]::UtcNow -lt $deadline)
            $ready | Should -BeTrue
            $review=$s.tasks.T1.local_review
            $r=Invoke-Cli @('stop','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 0 -Because $r.raw
            $processExit=Wait-TeamProcess $handle 20; $handle=$null
            $processExit | Should -Be 0 -Because ((Get-Content (Join-Path $TestDrive 'local-stop-out') -Raw) + ((State $f).tasks.T1.local_review | ConvertTo-Json -Depth 10))
            $s=State $f; $s.status | Should -Be 'CANCELLED'; $s.agents_reserved | Should -Be 0
            Get-TeamOwnedProcess $review.pid $review.process_start | Should -BeNullOrEmpty
            Test-Path (Join-Path $review.directory 'worker.stdout') | Should -BeTrue
        } finally {
            if (Test-Path (Join-Path $f.repo 'team/runtime/FIXTURE/state.json')) { $null=Invoke-Cli @('stop','-Repo',$f.repo,'-Run','FIXTURE','-Json') }
            if ($handle -and -not $handle['closed']) { $null=Close-TeamProcess $handle -Terminate }
        }
    }
    It 'requires a bound DSH local review and preserves its failure or mutation evidence for <Objective>' -ForEach @(
        @{Objective='LOCAL_FAIL';Code=50},@{Objective='LOCAL_INVALID';Code=50},@{Objective='LOCAL_WRITE';Code=82}
    ) {
        $f=New-RuntimeFixture; $f.plan.tasks[0].objective=@($Objective); Write-TeamData $f.path $f.plan
        $r=Invoke-Cli @('run','-Repo',$f.repo,'-Plan',$f.path,'-Json'); $r.code | Should -Be $Code -Because $r.raw
        $s=State $f; $s.agents_created | Should -Be 2; $s.agents_reserved | Should -Be 0
        $s.tasks.T1.status | Should -Not -Be 'REVIEW'
        Test-Path (Join-Path $s.tasks.T1.local_review.directory 'exit.json') | Should -BeTrue
        $r=Invoke-Cli @('accept','-Repo',$f.repo,'-Run','FIXTURE','-Task','T1','-Commit',$s.tasks.T1.commit,'-Reason','Cannot waive local review','-Json')
        $r.code | Should -Be 50
        (State $f).agents_created | Should -Be 2
        if ($Objective -eq 'LOCAL_WRITE') { Test-Path (Join-Path $s.tasks.T1.worktree 'forbidden-review.txt') | Should -BeTrue }
        (Invoke-TeamGit $f.repo @('rev-parse','main')) | Should -Be $f.base
    }
    It 'preserves a failed evidence attempt when the same review item is verified again' {
        $f=New-RuntimeFixture; $f.plan.tasks[0].objective=@('LOCAL_VN'); Write-TeamData $f.path $f.plan
        $r=Invoke-Cli @('run','-Repo',$f.repo,'-Plan',$f.path,'-Json'); $r.code | Should -Be 70 -Because $r.raw
        $dir=Join-Path $f.repo 'team/runtime/FIXTURE'
        $reviewHash=Get-TeamHash (Join-Path $dir 'reviews/LOCAL-T1.json')
        $disposition=Join-Path $TestDrive 'retry-evidence.json'
        $entry=@{index=0;action='verify';reason='Exercise preserved failure output';command=@{id='fact';executable='pwsh';args=@('-NoProfile','-Command','Write-Output FIRST_ATTEMPT_FAILED; exit 7');timeout_seconds=10}}
        Write-TeamData $disposition @($entry)
        $r=Invoke-Cli @('resolve-review','-Repo',$f.repo,'-Run','FIXTURE','-Task','T1','-Stage','LOCAL','-Disposition',$disposition,'-Json')
        $r.code | Should -Be 40 -Because $r.raw
        Test-Path (Join-Path $dir 'reviews/LOCAL-T1-dispositions.json') | Should -BeFalse
        $failed=@(Get-ChildItem (Join-Path $dir 'reviews/evidence') -Directory)
        $failed.Count | Should -Be 1
        $hashes=@{}; foreach($file in Get-ChildItem $failed[0].FullName -File) { $hashes[$file.Name]=Get-TeamHash $file.FullName }
        (Read-TeamData (Join-Path $failed[0].FullName 'verification-evidence.json')).exit_code | Should -Be 7
        $entry.command.args=@('-NoProfile','-Command','Write-Output SECOND_ATTEMPT_PASSED; exit 0')
        $entry.reason='Correct the fixture verification command without replacing the original failure'
        Write-TeamData $disposition @($entry)
        $r=Invoke-Cli @('resolve-review','-Repo',$f.repo,'-Run','FIXTURE','-Task','T1','-Stage','LOCAL','-Disposition',$disposition,'-Json')
        $r.code | Should -Be 0 -Because $r.raw
        @(Get-ChildItem (Join-Path $dir 'reviews/evidence') -Directory).Count | Should -Be 2
        foreach($name in $hashes.Keys) { Get-TeamHash (Join-Path $failed[0].FullName $name) | Should -Be $hashes[$name] }
        $saved=Read-TeamData (Join-Path $dir 'reviews/LOCAL-T1-dispositions.json')
        $saved.review_hash | Should -Be $reviewHash
        $saved.items[0].evidence_directory | Should -Not -Be $failed[0].FullName
        $saved.items[0].evidence_hash | Should -Be (Get-TeamHash (Join-Path $saved.items[0].evidence_directory 'verification-evidence.json'))
        $r=Invoke-Cli @('resume','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 0 -Because $r.raw
        (State $f).tasks.T1.status | Should -Be 'REVIEW'; (State $f).agents_created | Should -Be 2
        Get-TeamHash (Join-Path $dir 'reviews/LOCAL-T1.json') | Should -Be $reviewHash
        Accept-All $f
        $r=Invoke-Cli @('integrate','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 0 -Because $r.raw
        $r.data.status | Should -Be 'COMPLETED'
    }
    It 'handles local evidence requests before Critical 9A without repeating the author or local reviewer' {
        $f=New-RuntimeFixture; $f.plan.tasks[0].objective=@('LOCAL_VN'); $f.plan.classification.level='critical'
        $f.plan.review.require_9p=$true; $f.plan.review.require_fresh_9b=$true; Write-TeamData $f.path $f.plan
        $r=Invoke-Cli @('run','-Repo',$f.repo,'-Plan',$f.path,'-Json'); $r.code | Should -Be 70 -Because $r.raw
        $s=State $f; $s.tasks.T1.status | Should -Be 'LOCAL_REVIEW'
        $dir=Join-Path $f.repo 'team/runtime/FIXTURE'
        Test-Path (Join-Path $dir 'reviews/9A-T1.json') | Should -BeFalse
        $disposition=Join-Path $TestDrive 'local-disposition.json'
        Write-TeamData $disposition @(@{index=0;action='verify';reason='Run the requested independent fact';command=@{id='fact';executable='pwsh';args=@('-NoProfile','-Command','exit 0');timeout_seconds=10}})
        $r=Invoke-Cli @('resolve-review','-Repo',$f.repo,'-Run','FIXTURE','-Task','T1','-Stage','LOCAL','-Disposition',$disposition,'-Json')
        $r.code | Should -Be 0 -Because $r.raw
        $r=Invoke-Cli @('accept','-Repo',$f.repo,'-Run','FIXTURE','-Task','T1','-Commit',$s.tasks.T1.commit,'-Reason','Critical review still missing','-Json')
        $r.code | Should -Be 50
        $r=Invoke-Cli @('resume','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 0 -Because $r.raw
        (State $f).tasks.T1.status | Should -Be 'REVIEW'; (State $f).agents_created | Should -Be 2
        (State $f).tasks.T1.attempts | Should -Be 1
        Test-Path (Join-Path $dir 'reviews/9A-T1.json') | Should -BeTrue
        Accept-All $f
        $r=Invoke-Cli @('integrate','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 0 -Because $r.raw
        $r.data.status | Should -Be 'COMPLETED'
    }
    It 'archives replanned attempts as DISCARDED and cleans them without losing branches or result evidence' {
        $f=New-RuntimeFixture 2
        $r=Invoke-Cli @('run','-Repo',$f.repo,'-Plan',$f.path,'-Json'); $r.code | Should -Be 0 -Because $r.raw
        $old=(State $f).tasks.T1; Accept-All $f
        $f.plan.run.revision=2; $f.plan.mode='L1'; $f.plan.tasks=@($f.plan.tasks | Where-Object id -eq 'T2')
        $f.plan.verification.final[0].args=@('-NoProfile','-Command','if (-not (Test-Path files/T2.txt)) {exit 1}')
        Write-TeamData $f.path $f.plan
        $r=Invoke-Cli @('replan','-Repo',$f.repo,'-Run','FIXTURE','-Plan',$f.path,'-Task','T1','-Reason','Explicitly drop task one from the approved work','-Json')
        $r.code | Should -Be 0 -Because $r.raw
        $s=State $f; $s.tasks.Contains('T1') | Should -BeFalse
        $s.discarded_tasks['T1-a1-r1'].status | Should -Be 'DISCARDED'
        Test-Path $old.worktree | Should -BeTrue
        $r=Invoke-Cli @('cleanup','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 0 -Because $r.raw
        $r.data.discarded_removed | Should -Contain 'T1-a1-r1'
        Test-Path $old.worktree | Should -BeFalse
        Test-Path (Join-Path $old.directory 'result.yaml') | Should -BeTrue
        (Invoke-TeamGit $f.repo @('rev-parse',$old.branch)) | Should -Be $old.commit
        (State $f).tasks.T2.status | Should -Be 'ACCEPTED'
        $r=Invoke-Cli @('cleanup','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 0
        $r.data.discarded_removed.Count | Should -Be 0
        $r=Invoke-Cli @('integrate','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 0 -Because $r.raw
        $r.data.status | Should -Be 'COMPLETED'
    }
    It 'preserves dirty discarded evidence and resumes a replacement after clean retirement' {
        $f=New-RuntimeFixture
        $r=Invoke-Cli @('run','-Repo',$f.repo,'-Plan',$f.path,'-Json'); $r.code | Should -Be 0 -Because $r.raw
        $old=(State $f).tasks.T1
        $f.plan.run.revision=2; $f.plan.tasks[0].objective=@('WRITE AGAIN'); Write-TeamData $f.path $f.plan
        $r=Invoke-Cli @('replan','-Repo',$f.repo,'-Run','FIXTURE','-Plan',$f.path,'-Task','T1','-Reason','Replace old attempt','-Json'); $r.code | Should -Be 0
        $note=Join-Path $old.worktree 'retain-me.txt'; Set-Content $note 'Uncommitted evidence'
        $r=Invoke-Cli @('cleanup','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 80
        Test-Path $note | Should -BeTrue
        $f.plan.run.revision=3; Write-TeamData $f.path $f.plan
        $r=Invoke-Cli @('replan','-Repo',$f.repo,'-Run','FIXTURE','-Plan',$f.path,'-Task','T1','-Reason','Refine pending replacement without duplicating its retired attempt','-Json')
        $r.code | Should -Be 0 -Because $r.raw
        (State $f).discarded_tasks.Count | Should -Be 1
        # Only remove the exact file created by this fixture, never runtime evidence.
        [IO.File]::Delete($note)
        $r=Invoke-Cli @('cleanup','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 0 -Because $r.raw
        $r=Invoke-Cli @('resume','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 0 -Because $r.raw
        (State $f).tasks.T1.attempts | Should -Be 2
        (State $f).tasks.T1.worktree | Should -Not -Be $old.worktree
    }
    It 'escalates repeated <Objective> across distinct attempts and does not double count resume' -ForEach @(
        @{Objective='SCOPE';Code=82;Kind='scope_violation'},@{Objective='MALFORMED';Code=10;Kind='invalid_result'}
    ) {
        $f=New-RuntimeFixture; $f.plan.tasks[0].objective=@($Objective); Write-TeamData $f.path $f.plan
        $r=Invoke-Cli @('run','-Repo',$f.repo,'-Plan',$f.path,'-Json'); $r.code | Should -Be $Code -Because $r.raw
        (State $f).status | Should -Be 'PAUSED'
        $f.plan.run.revision=2; Write-TeamData $f.path $f.plan
        $r=Invoke-Cli @('replan','-Repo',$f.repo,'-Run','FIXTURE','-Plan',$f.path,'-Task','T1','-Reason','Retry the same concrete failure','-Json'); $r.code | Should -Be 0
        $r=Invoke-Cli @('resume','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be $Code -Because $r.raw
        $s=State $f; $s.status | Should -Be 'ESCALATED'; $s.worker_failures["T1/$Kind"].count | Should -Be 2
        $r=Invoke-Cli @('escalations','-Repo',$f.repo,'-Run','FIXTURE','-Json'); @($r.data | Where-Object type -eq $Kind).Count | Should -Be 1
        $r=Invoke-Cli @('resume','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 70
        (State $f).worker_failures["T1/$Kind"].count | Should -Be 2
    }
    It 'escalates the first Critical scope violation before local or 9A review' {
        $f=New-RuntimeFixture; $f.plan.tasks[0].objective=@('SCOPE'); $f.plan.classification.level='critical'
        $f.plan.review.require_9p=$true; $f.plan.review.require_fresh_9b=$true; Write-TeamData $f.path $f.plan
        $r=Invoke-Cli @('run','-Repo',$f.repo,'-Plan',$f.path,'-Json'); $r.code | Should -Be 82 -Because $r.raw
        $s=State $f; $s.status | Should -Be 'ESCALATED'; $s.tasks.T1.status | Should -Be 'FAILED_SCOPE'
        $r=Invoke-Cli @('escalations','-Repo',$f.repo,'-Run','FIXTURE','-Json'); @($r.data | Where-Object type -eq 'scope_violation').Count | Should -Be 1
        Test-Path (Join-Path $f.repo 'team/runtime/FIXTURE/reviews/LOCAL-T1.json') | Should -BeFalse
        Test-Path (Join-Path $f.repo 'team/runtime/FIXTURE/reviews/9A-T1.json') | Should -BeFalse
    }
    It 'admits the observed L3 extension and rejects missing native tools before worktree creation and resume' {
        $f=New-RuntimeFixture; $f.plan.mode='L3'; $f.plan.tasks[0].subagents=@{allowed=$true;max_depth=2}; Write-TeamData $f.path $f.plan
        $old=$env:TEAM_FIXTURE_NO_NATIVE
        try {
            $env:TEAM_FIXTURE_NO_NATIVE='1'
            $r=Invoke-Cli @('run','-Repo',$f.repo,'-Plan',$f.path,'-Json')
            $r.code | Should -Be 20 -Because $r.raw
            Test-Path (Join-Path $f.repo '.worktrees') | Should -BeFalse
            Test-Path (Join-Path $f.repo 'team/runtime/FIXTURE') | Should -BeFalse
            $env:TEAM_FIXTURE_NO_NATIVE=$null
            $r=Invoke-Cli @('run','-Repo',$f.repo,'-Plan',$f.path,'-Json'); $r.code | Should -Be 0 -Because $r.raw
            $proof=Read-TeamData (Join-Path $f.repo 'team/runtime/FIXTURE/preflight.json')
            $proof.capabilities.input | Should -Be 'I1'
            $proof.capabilities.matrix_modes | Should -Not -Contain 'L3'
            $proof.capabilities.allowed_modes | Should -Contain 'L3'
            $proof.capabilities.adapter_l3_extension | Should -BeTrue
            $env:TEAM_FIXTURE_NO_NATIVE='1'
            $r=Invoke-Cli @('resume','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 20 -Because $r.raw
            (State $f).tasks.T1.attempts | Should -Be 1
            $g=New-RuntimeFixture
            $r=Invoke-Cli @('run','-Repo',$g.repo,'-Plan',$g.path,'-Json'); $r.code | Should -Be 0 -Because $r.raw
        } finally { $env:TEAM_FIXTURE_NO_NATIVE=$old }
    }
    It 'keeps explicit runtime override available for L1 but never labels an unknown version as verified L3' {
        $f=New-RuntimeFixture; $old=$env:TEAM_FIXTURE_VERSION
        try {
            $env:TEAM_FIXTURE_VERSION='0.1.5-unknown'
            $r=Invoke-Cli @('run','-Repo',$f.repo,'-Plan',$f.path,'-Json'); $r.code | Should -Be 20
            $r=Invoke-Cli @('run','-Repo',$f.repo,'-Plan',$f.path,'-AllowUnverifiedRuntime','-Json'); $r.code | Should -Be 0 -Because $r.raw
            (State $f).runtime_status | Should -Be 'UNVERIFIED_RUNTIME'
            $proof=Read-TeamData (Join-Path $f.repo 'team/runtime/FIXTURE/preflight.json')
            $proof.capabilities.unverified_transport_override | Should -BeTrue
            $proof.capabilities.input | Should -Be 'UNKNOWN'
            $proof.capabilities.allowed_modes | Should -Not -Contain 'L3'
            $g=New-RuntimeFixture; $g.plan.mode='L3'; $g.plan.tasks[0].subagents=@{allowed=$true;max_depth=2}; Write-TeamData $g.path $g.plan
            $r=Invoke-Cli @('run','-Repo',$g.repo,'-Plan',$g.path,'-AllowUnverifiedRuntime','-Json'); $r.code | Should -Be 20 -Because $r.raw
            Test-Path (Join-Path $g.repo '.worktrees') | Should -BeFalse
        } finally { $env:TEAM_FIXTURE_VERSION=$old }
    }
    It 'exposes degraded routing to the Lead and requires explicit replay before recovery' {
        $f=New-RuntimeFixture
        foreach ($i in 1..3) {
            $r=Invoke-Cli @('record-route','-Repo',$f.repo,'-TaskText','新增搜索功能','-ExpectedMode','L2','-Json')
            $r.code | Should -Be 0 -Because $r.raw
        }
        $r=Invoke-Cli @('route','-Repo',$f.repo,'-TaskText','avatar upload','-Json')
        $r.data.auto_route | Should -Be 'degraded'
        $r.data.notice | Should -Match 'revalidate-route'
        $r=Invoke-Cli @('doctor','-Repo',$f.repo,'-Json')
        $r.code | Should -Be 0 -Because $r.raw
        $r.data.routing_health.auto_route | Should -Be 'degraded'
        $r=Invoke-Cli @('run','-Repo',$f.repo,'-Plan',$f.path,'-Json')
        $r.code | Should -Be 0 -Because $r.raw
        $r.data.routing_health.auto_route | Should -Be 'degraded'
        $r=Invoke-Cli @('logs','-Repo',$f.repo,'-Run','FIXTURE','-Json')
        @($r.data | Where-Object event -eq 'routing_degraded').Count | Should -Be 1
        $r=Invoke-Cli @('revalidate-route','-Repo',$f.repo,'-Reason','Check actual routing failure','-Json')
        $r.code | Should -Be 20 -Because $r.raw
        $r.data.success | Should -BeFalse
        foreach ($name in @('frontend','backend')) { New-Item -ItemType Directory (Join-Path $f.repo $name) | Out-Null }
        $r=Invoke-Cli @('revalidate-route','-Repo',$f.repo,'-Reason','Restore missing domain markers','-Json')
        $r.code | Should -Be 0 -Because $r.raw
        $r.data.auto_route | Should -Be 'normal'
        $r.data.checks.Count | Should -Be 5
        $r=Invoke-Cli @('route','-Repo',$f.repo,'-TaskText','新增搜索功能','-Json')
        $r.data.recommended_mode | Should -Be 'L2'
        $r.data.auto_route | Should -Be 'normal'
        (Invoke-TeamGit $f.repo @('rev-parse','main')) | Should -Be $f.base
    }
    It 'blocks execution while process cleanup is pending and allows stop to clear it' {
        $f=New-RuntimeFixture
        $r=Invoke-Cli @('run','-Repo',$f.repo,'-Plan',$f.path,'-Json'); $r.code | Should -Be 0 -Because $r.raw
        $s=State $f; $s.tasks.T1['cleanup_pending']=$true; $s.tasks.T1.status='FAILED'
        Write-TeamData (Join-Path $f.repo 'team/runtime/FIXTURE/state.json') $s
        foreach ($command in @('resume','integrate')) {
            $r=Invoke-Cli @($command,'-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 80 -Because $r.raw
        }
        $f.plan.run.revision=2; $f.plan.tasks[0].objective=@('WRITE AGAIN'); Write-TeamData $f.path $f.plan
        $r=Invoke-Cli @('replan','-Repo',$f.repo,'-Run','FIXTURE','-Plan',$f.path,'-Task','T1','-Reason','Must not replace pending ownership','-Json')
        $r.code | Should -Be 80 -Because $r.raw
        (State $f).revision | Should -Be 1
        (State $f).tasks.T1.attempts | Should -Be 1
        $r=Invoke-Cli @('stop','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 0 -Because $r.raw
        (State $f).status | Should -Be 'CANCELLED'
        (State $f).tasks.T1.cleanup_pending | Should -BeFalse
    }
    It 'rejects a complete Result when a surviving native child keeps the output pipe open' {
        $f=New-RuntimeFixture; $f.plan.tasks[0].objective=@('PIPE_HOLDER'); Write-TeamData $f.path $f.plan
        $r=Invoke-Cli @('run','-Repo',$f.repo,'-Plan',$f.path,'-Json')
        $r.code | Should -Be 31 -Because $r.raw
        $item=(State $f).tasks.T1
        $item.status | Should -Be 'FAILED'
        $receipt=Read-TeamData (Join-Path $item.directory 'exit.json')
        $receipt.native_exit_code | Should -Be 0
        $receipt.transport_cleanup.drain_expired | Should -BeTrue
        $receipt.transport_cleanup.streams_settled | Should -BeTrue
        $receipt.transport_cleanup.children.terminated.Count | Should -Be 1
        (Read-TeamData (Join-Path $item.directory 'worker.stdout')).status | Should -Be 'completed'
        Test-Path (Join-Path $item.directory 'result.yaml') | Should -BeFalse
        Test-Path (Join-Path $item.directory 'verification-evidence.json') | Should -BeFalse
        $child=Read-TeamData (Join-Path $item.directory 'pipe-child.json')
        Get-TeamOwnedProcess $child.pid $child.start | Should -BeNullOrEmpty
    }
    It 'enforces the configured log cap through the <Surface> entry point' -ForEach @(@{Surface='worker'},@{Surface='verification'},@{Surface='review'},@{Surface='final'}) {
        $f=New-RuntimeFixture
        $config=Read-TeamData (Join-Path $script:TeamPath 'manifest.yaml'); $config.runtime.max_single_log_mb=1
        $configPath=Join-Path $TestDrive 'bounded-manifest.json'; Write-TeamData $configPath $config
        $flood=@('-NoProfile','-Command','[Console]::Out.Write("x" * 2MB)')
        if ($Surface -eq 'worker') { $f.plan.tasks[0].objective=@('FLOOD') }
        if ($Surface -eq 'verification') { $f.plan.tasks[0].verification[0].args=$flood }
        if ($Surface -eq 'final') { $f.plan.verification.final[0].args=$flood }
        if ($Surface -eq 'review') {
            $f.plan.classification.level='critical'; $f.plan.review.require_9p=$true; $f.plan.review.require_fresh_9b=$true
            $f.plan.tasks[0].objective=@('FIXTURE_REVIEW_FLOOD')
        }
        Write-TeamData $f.path $f.plan
        $r=Invoke-Cli @('run','-Repo',$f.repo,'-Plan',$f.path,'-Manifest',$configPath,'-Json')
        if ($Surface -eq 'final') {
            $r.code | Should -Be 0 -Because $r.raw
            Accept-All $f
            $r=Invoke-Cli @('integrate','-Repo',$f.repo,'-Run','FIXTURE','-Json')
        }
        $expected=switch ($Surface) {'worker' {31};'review' {50};default {40}}
        $r.code | Should -Be $expected -Because $r.raw
        $s=State $f
        $s.status | Should -Not -Be 'COMPLETED'
        if ($Surface -eq 'review') {
            $attempt=Get-ChildItem (Join-Path $f.repo 'team/runtime/FIXTURE/reviews') -Filter 'attempt-*.json' | Select-Object -First 1
            $receipt=Read-TeamData $attempt.FullName; $receipt.exit_code | Should -Be 31
            $receipt.error | Should -Match 'output limit'
            (Get-Item (Join-Path $receipt.holding 'events.jsonl')).Length | Should -Be 1MB
            Test-Path (Join-Path $f.repo 'team/runtime/FIXTURE/reviews/9P.json') | Should -BeFalse
            $s.tasks.T1.attempts | Should -Be 0
        } else {
            $log=switch ($Surface) {
                'worker' {Join-Path $s.tasks.T1.directory 'worker.stdout'}
                'verification' {Join-Path $s.tasks.T1.directory 'verification-exists.stdout'}
                'final' {Join-Path $s.final_evidence_directory 'final-all.stdout'}
            }
            (Get-Item $log).Length | Should -Be 1MB
            if ($Surface -eq 'worker') {
                $exitReceipt=Read-TeamData (Join-Path $s.tasks.T1.directory 'exit.json')
                $exitReceipt.exit_code | Should -Be 31; $exitReceipt.launch_attempts | Should -Be 1
                $exitReceipt.startup_exhausted | Should -BeFalse
            }
        }
        (Invoke-TeamGit $f.repo @('rev-parse','main')) | Should -Be $f.base
    }
    It 'applies the twelve-directory worktree cap before worker attempts or integration branches are created' {
        $f=New-RuntimeFixture
        foreach ($i in 1..12) { [IO.Directory]::CreateDirectory((Join-Path $f.repo ".worktrees/reserved-$i")) | Out-Null }
        $r=Invoke-Cli @('run','-Repo',$f.repo,'-Plan',$f.path,'-Json'); $r.code | Should -Be 20 -Because $r.raw
        (State $f).tasks.T1.attempts | Should -Be 0
        (Invoke-TeamGit $f.repo @('branch','--list','codex/team/*')) | Should -BeNullOrEmpty
        $g=New-RuntimeFixture
        $r=Invoke-Cli @('run','-Repo',$g.repo,'-Plan',$g.path,'-Json'); $r.code | Should -Be 0 -Because $r.raw
        Accept-All $g
        foreach ($i in 1..11) { [IO.Directory]::CreateDirectory((Join-Path $g.repo ".worktrees/reserved-$i")) | Out-Null }
        $r=Invoke-Cli @('integrate','-Repo',$g.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 20 -Because $r.raw
        $s=State $g; $s.integration_worktree | Should -BeNullOrEmpty
        $s.tasks.T1.status | Should -Be 'ACCEPTED'
        $s.tasks.T1.attempts | Should -Be 1
        (Invoke-TeamGit $g.repo @('branch','--list',$s.integration_branch)) | Should -BeNullOrEmpty
        @(Get-ChildItem (Join-Path $g.repo '.worktrees') -Directory).Count | Should -Be 12
    }
    It 'preserves an abnormal worker exit and requires explicit replan before replacement' {
        $f=New-RuntimeFixture; $f.plan.tasks[0].objective=@('CRASH'); Write-TeamData $f.path $f.plan
        $r=Invoke-Cli @('run','-Repo',$f.repo,'-Plan',$f.path,'-Json'); $r.code | Should -Be 30 -Because $r.raw
        $s=State $f; $s.tasks.T1.status | Should -Be 'FAILED'; $s.tasks.T1.attempts | Should -Be 1
        $first=$s.tasks.T1.directory
        $receipt=Read-TeamData (Join-Path $first 'exit.json')
        $receipt.exit_code | Should -Be 9
        $receipt.launch_attempts | Should -Be 1
        $receipt.startup_exhausted | Should -BeFalse
        Test-Path (Join-Path $first 'result.yaml') | Should -BeFalse
        $hash=Get-TeamHash (Join-Path $first 'exit.json')
        $r=Invoke-Cli @('resume','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 80 -Because $r.raw
        (State $f).tasks.T1.attempts | Should -Be 1
        $f.plan.run.revision=2; $f.plan.tasks[0].objective=@('WRITE'); Write-TeamData $f.path $f.plan
        $r=Invoke-Cli @('replan','-Repo',$f.repo,'-Run','FIXTURE','-Task','T1','-Plan',$f.path,'-Reason','Replace the failed native fixture after inspecting its durable exit receipt','-Json')
        $r.code | Should -Be 0 -Because $r.raw
        $r=Invoke-Cli @('resume','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 0 -Because $r.raw
        $s=State $f; $s.tasks.T1.attempts | Should -Be 2; $s.tasks.T1.status | Should -Be 'REVIEW'
        $s.agents_created | Should -Be 3; $s.agents_reserved | Should -Be 0
        Get-TeamHash (Join-Path $first 'exit.json') | Should -Be $hash
        @($s.discarded_tasks.Values | Where-Object retired_from -eq FAILED).Count | Should -Be 1
        Accept-All $f
        $r=Invoke-Cli @('integrate','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 0 -Because $r.raw
        $r.data.status | Should -Be 'COMPLETED'
        (Invoke-TeamGit $f.repo @('rev-parse','main')) | Should -Be $f.base
    }
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
            $s.agents_created | Should -Be 2; $s.agents_reserved | Should -Be 0 # Author plus mandatory local reviewer.
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
            $r=Invoke-Cli @('report-cost','-Repo',$f.repo,'-Run','FIXTURE','-Amount',"$Amount",'-Evidence',$evidence,'-Ledger','deepseek','-Unit','USD','-Source','synthetic-test','-Json')
            $r.code | Should -Be 0 -Because $r.raw; $r.data.status | Should -Be 'QUEUED'
            $r=Invoke-Cli @('report-cost','-Repo',$f.repo,'-Run','FIXTURE','-Amount',"$Amount",'-Evidence',$evidence,'-Ledger','deepseek','-Unit','USD','-Source','synthetic-test','-Json')
            $r.code | Should -Be 10 -Because $r.raw
            $workerExit=Wait-TeamProcess $handle 25
            $handle=$null
            $workerExit | Should -Be $(if ($Limit -eq 'hard') {70} else {0}) -Because ((Get-Content (Join-Path $TestDrive "cost-$Limit-out") -Raw) + (Get-Content (Join-Path $TestDrive "cost-$Limit-err") -Raw))
            $s=State $f; $s.status | Should -Be $(if ($Limit -eq 'hard') {'ESCALATED'} else {'PAUSED'}); $s.cost_ledgers.deepseek.known_cost | Should -Be $Amount
            $s.tasks.T1.status | Should -Be $(if ($Limit -eq 'hard') {'LOCAL_REVIEW'} else {'REVIEW'}); $s.tasks.T1.attempts | Should -Be 1
            $s.tasks.T2.status | Should -Be 'READY'; $s.tasks.T2.attempts | Should -Be 0
            $r=Invoke-Cli @('resume','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be $(if ($Limit -eq 'hard') {70} else {0}) -Because $r.raw
            (State $f).cost_ledgers.deepseek.known_cost | Should -Be $Amount
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
        $packet=Read-TeamData (Join-Path $s.tasks.T1.directory 'task.yaml')
        $packet.role.definition.capabilities | Should -Contain 'sql'
        $packet.role.definition.verification.preferred | Should -Contain 'integration'
        # Role defaults do not overwrite the task's exact assigned file or its L2 delegation limit.
        $packet.write_scope | Should -Be @('files/T1.txt'); $packet.subagents.allowed | Should -BeFalse
        (Read-TeamData (Join-Path $f.repo 'team/runtime/FIXTURE/roles/database.yaml')).role_id | Should -Be 'database'
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
        (State $f).agents_created | Should -Be 6 # Each author has one mandatory DSH local reviewer.
        (Invoke-TeamGit $f.repo @('rev-parse','main')) | Should -Be $f.base
        $r = Invoke-Cli @('cleanup','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 0 -Because $r.raw
        $r.data.removed.Count | Should -Be 3
    }
    It 'rejects schema errors without creating runtime or worktrees' {
        $f=New-RuntimeFixture; $f.plan.tasks[0].dependencies=@('T1'); Write-TeamData $f.path $f.plan
        $r=Invoke-Cli @('run','-Repo',$f.repo,'-Plan',$f.path,'-Json')
        $r.code | Should -Be 10
        $r.data.event | Should -Be 'plan_invalid'
        Test-Path (Join-Path $f.repo '.worktrees') | Should -BeFalse
        Test-Path (Join-Path $f.repo 'team/runtime') | Should -BeFalse
    }
    It 'rejects scope violations from actual Git and preserves evidence' {
        $f=New-RuntimeFixture; $f.plan.tasks[0].objective=@('SCOPE'); Write-TeamData $f.path $f.plan
        $r=Invoke-Cli @('run','-Repo',$f.repo,'-Plan',$f.path,'-Json')
        $r.code | Should -Be 82 -Because $r.raw
        (State $f).tasks.T1.status | Should -Be 'FAILED_SCOPE'
        Test-Path (State $f).tasks.T1.worktree | Should -BeTrue
        $events=Get-Content (Join-Path $f.repo 'team/runtime/FIXTURE/events.jsonl') | ForEach-Object { ConvertFrom-Json $_ }
        @($events | Where-Object event -eq 'scope_violation').Count | Should -Be 1
    }
    It 'keeps an escalated worker out of acceptance until an owner decision and explicit replan' {
        $f=New-RuntimeFixture; $f.plan.tasks[0].objective=@('ESCALATE'); Write-TeamData $f.path $f.plan
        $r=Invoke-Cli @('run','-Repo',$f.repo,'-Plan',$f.path,'-Json'); $r.code | Should -Be 70 -Because $r.raw
        $s=State $f; $s.status | Should -Be 'ESCALATED'; $s.tasks.T1.status | Should -Be 'ESCALATED'
        $originalResult=Join-Path $s.tasks.T1.directory 'result.yaml'; $originalHash=Get-TeamHash $originalResult
        Test-Path (Join-Path $s.tasks.T1.directory 'verification-evidence.json') | Should -BeFalse
        $r=Invoke-Cli @('accept','-Repo',$f.repo,'-Run','FIXTURE','-Task','T1','-Commit',$s.tasks.T1.commit,'-Reason','Must not accept an escalated result','-Json')
        $r.code | Should -Not -Be 0
        $r=Invoke-Cli @('escalations','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $record=@($r.data)[0]
        $record.type | Should -Be 'worker_request'; $record.context.result_hash | Should -Be $originalHash
        $r=Invoke-Cli @('resume','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 70
        (State $f).tasks.T1.attempts | Should -Be 1
        $r=Invoke-Cli @('resolve','-Repo',$f.repo,'-Run','FIXTURE','-Escalation',$record.id,'-Decision','modify-plan','-Reason','Owner supplies missing contract','-Json'); $r.code | Should -Be 0
        $f.plan.run.revision=2; $f.plan.tasks[0].objective=@('WRITE'); Write-TeamData $f.path $f.plan
        $r=Invoke-Cli @('replan','-Repo',$f.repo,'-Run','FIXTURE','-Plan',$f.path,'-Task','T1','-Reason','Apply owner contract','-Json'); $r.code | Should -Be 0 -Because $r.raw
        $r=Invoke-Cli @('resume','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 0 -Because $r.raw
        (State $f).tasks.T1.status | Should -Be 'REVIEW'; (State $f).tasks.T1.attempts | Should -Be 2
        (Get-TeamHash $originalResult) | Should -Be $originalHash
    }
    It 'still audits the Git scope of an escalated worker' {
        $f=New-RuntimeFixture; $f.plan.tasks[0].objective=@('ESCALATE_SCOPE'); Write-TeamData $f.path $f.plan
        $r=Invoke-Cli @('run','-Repo',$f.repo,'-Plan',$f.path,'-Json'); $r.code | Should -Be 82 -Because $r.raw
        (State $f).tasks.T1.status | Should -Be 'FAILED_SCOPE'
        $r=Invoke-Cli @('escalations','-Repo',$f.repo,'-Run','FIXTURE','-Json')
        @($r.data | Where-Object type -eq 'worker_request').Count | Should -Be 0
    }
    It 'does not label malformed worker output as an invalid plan' {
        $f=New-RuntimeFixture; $f.plan.tasks[0].objective=@('MALFORMED'); Write-TeamData $f.path $f.plan
        $r=Invoke-Cli @('run','-Repo',$f.repo,'-Plan',$f.path,'-Json'); $r.code | Should -Be 10 -Because $r.raw
        $r.data.ContainsKey('event') | Should -BeFalse
        (State $f).tasks.T1.status | Should -Be 'FAILED'
    }
    It 'escalates the second identical verification failure and preserves both attempts' {
        $f=New-RuntimeFixture; $f.plan.tasks[0].verification[0].args=@('-NoProfile','-Command','Write-Output "repeatable failure"; exit 9'); Write-TeamData $f.path $f.plan
        $r=Invoke-Cli @('run','-Repo',$f.repo,'-Plan',$f.path,'-Json'); $r.code | Should -Be 40 -Because $r.raw
        $s=State $f; $s.status | Should -Be 'PAUSED'; $s.verification_failures.T1.count | Should -Be 1
        $firstEvidence=Join-Path $s.tasks.T1.directory 'verification-evidence.json'
        $f.plan.run.revision=2; Write-TeamData $f.path $f.plan
        $r=Invoke-Cli @('replan','-Repo',$f.repo,'-Run','FIXTURE','-Plan',$f.path,'-Task','T1','-Reason','One explicit retry','-Json'); $r.code | Should -Be 0 -Because $r.raw
        $r=Invoke-Cli @('resume','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 40 -Because $r.raw
        $s=State $f; $s.status | Should -Be 'ESCALATED'; $s.verification_failures.T1.count | Should -Be 2
        Test-Path $firstEvidence | Should -BeTrue
        Test-Path (Join-Path $s.tasks.T1.directory 'verification-evidence.json') | Should -BeTrue
        $r=Invoke-Cli @('escalations','-Repo',$f.repo,'-Run','FIXTURE','-Json'); @($r.data)[0].type | Should -Be 'repeated_verification_failure'
        $r=Invoke-Cli @('resume','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 70 -Because $r.raw
        (State $f).tasks.T1.attempts | Should -Be 2
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
        foreach ($label in @('9P','9A-T1','9B')) {
            $review=Read-TeamData (Join-Path $dir "reviews/$label.json")
            $arguments=@(Read-TeamData (Join-Path $review.holding 'invocation.json'))
            foreach ($flag in @('--ephemeral','--ignore-user-config','--ignore-rules')) { $arguments | Should -Contain $flag }
            $memoryIndex=[array]::IndexOf($arguments,'--disable')
            $memoryIndex | Should -BeGreaterOrEqual 0
            $arguments[$memoryIndex+1] | Should -Be 'memories'
            $effort=if ($label -eq '9P') {'medium'} else {'high'}
            $arguments | Should -Contain ('model_reasoning_effort="'+$effort+'"')
            $arguments[[array]::IndexOf($arguments,'-s')+1] | Should -Be 'read-only'
            $arguments | Should -Not -Contain 'resume'; $arguments | Should -Not -Contain 'fork'
        }
        $s=State $f; $s.review_rounds.Count | Should -Be 1
        $s.review_rounds['1'].number | Should -Be 1; $s.review_rounds['1'].streak | Should -Be 0
        $s.review_rounds['1'].records.Keys | Should -Contain '9A-T1'; $s.review_rounds['1'].records.Keys | Should -Contain '9B'
        $s.review_rounds['1'].records.Keys | Should -Not -Contain '9P'
    }
    It 'blocks replan on all-fix findings until an explicit one-round owner extension' {
        $f=New-RuntimeFixture; $f.plan.classification.level='critical'; $f.plan.review.require_9p=$true; $f.plan.review.require_fresh_9b=$true
        $f.plan.tasks[0].objective=@('FIXTURE_REVIEW_YES'); Write-TeamData $f.path $f.plan
        $r=Invoke-Cli @('run','-Repo',$f.repo,'-Plan',$f.path,'-Json'); $r.code | Should -Be 50 -Because $r.raw
        $f.plan.run.revision=2; $f.plan.tasks[0].objective=@('WRITE'); Write-TeamData $f.path $f.plan
        $r=Invoke-Cli @('replan','-Repo',$f.repo,'-Run','FIXTURE','-Plan',$f.path,'-Task','T1','-Reason','Fixture repair request','-Json'); $r.code | Should -Be 70 -Because $r.raw
        $s=State $f; $s.revision | Should -Be 1; $s.tasks.T1.attempts | Should -Be 1; $s.review_stop.reason | Should -Be 'early_stop'
        $r=Invoke-Cli @('escalations','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $entry=@($r.data | Where-Object type -eq 'review_round_limit')[0]
        $r=Invoke-Cli @('resolve','-Repo',$f.repo,'-Run','FIXTURE','-Escalation',$entry.id,'-Decision','approve','-Reason','Fixture owner explicitly authorizes one additional round','-Json'); $r.code | Should -Be 0 -Because $r.raw
        $r=Invoke-Cli @('replan','-Repo',$f.repo,'-Run','FIXTURE','-Plan',$f.path,'-Task','T1','-Reason','Approved bounded repair','-Json'); $r.code | Should -Be 0 -Because $r.raw
        $r=Invoke-Cli @('resume','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 0 -Because $r.raw
        $s=State $f; $s.tasks.T1.status | Should -Be 'REVIEW'; $s.review_rounds['2'].streak | Should -Be 0
        $review=Read-TeamData (Join-Path $f.repo 'team/runtime/FIXTURE/reviews/9A-T1.json')
        (Get-Content (Join-Path $review.holding 'prompt.txt') -Raw) | Should -Match 'Previous reviewed tip: [a-f0-9]{40}'
        $verdicts=@(Get-ChildItem (Join-Path $f.repo 'team/runtime/FIXTURE/reviews') -Filter 'verdict-*.json' | ForEach-Object { Read-TeamData $_.FullName })
        @($verdicts | Where-Object stage -ne 'LOCAL').Count | Should -Be 4
        @($verdicts | Where-Object stage -eq 'LOCAL').Count | Should -Be 2
    }
    It 'hard-stops two confirmed fix-introduced rounds even when other blocking issues remain' {
        $f=New-RuntimeFixture; $f.plan.classification.level='critical'; $f.plan.review.require_9p=$true; $f.plan.review.require_fresh_9b=$true
        $f.plan.tasks[0].objective=@('FIXTURE_REVIEW_MIXED'); Write-TeamData $f.path $f.plan
        $r=Invoke-Cli @('run','-Repo',$f.repo,'-Plan',$f.path,'-Json'); $r.code | Should -Be 50 -Because $r.raw
        $f.plan.run.revision=2; Write-TeamData $f.path $f.plan
        $r=Invoke-Cli @('replan','-Repo',$f.repo,'-Run','FIXTURE','-Plan',$f.path,'-Task','T1','-Reason','Fixture repair request','-Json'); $r.code | Should -Be 0 -Because $r.raw
        $r=Invoke-Cli @('resume','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 60 -Because $r.raw
        $s=State $f; $s.hard_stop | Should -BeTrue; $s.review_rounds['2'].streak | Should -Be 2
        $r=Invoke-Cli @('resume','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 60
        (State $f).tasks.T1.attempts | Should -Be 2
    }
    It 'requires explicit per-issue causality dispositions instead of treating approve as attribution' {
        $f=New-RuntimeFixture; $f.plan.classification.level='critical'; $f.plan.review.require_9p=$true; $f.plan.review.require_fresh_9b=$true
        $f.plan.tasks[0].objective=@('FIXTURE_REVIEW_DISPUTE'); Write-TeamData $f.path $f.plan
        $r=Invoke-Cli @('run','-Repo',$f.repo,'-Plan',$f.path,'-Json'); $r.code | Should -Be 70 -Because $r.raw
        $r=Invoke-Cli @('escalations','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $entry=@($r.data | Where-Object type -eq 'review_causality')[0]
        $r=Invoke-Cli @('resolve','-Repo',$f.repo,'-Run','FIXTURE','-Escalation',$entry.id,'-Decision','approve','-Reason','Missing attribution','-Json'); $r.code | Should -Be 10 -Because $r.raw
        $dispositions=Join-Path $TestDrive 'causality.json'; Write-TeamData $dispositions @(@{id='fixture-dispute';value='no';reason='Fixture owner confirms it predates the repair'})
        $r=Invoke-Cli @('resolve','-Repo',$f.repo,'-Run','FIXTURE','-Escalation',$entry.id,'-Decision','approve','-Reason','Explicit fixture attribution','-Disposition',$dispositions,'-Json'); $r.code | Should -Be 0 -Because $r.raw
        $s=State $f; $s.review_rounds['1'].causality_decisions['fixture-dispute'].value | Should -Be 'no'
        $s.review_rounds['1'].records['9A-T1'].issues[0].caused_by_last_fix | Should -Be 'dispute'
        $r=Invoke-Cli @('accept','-Repo',$f.repo,'-Run','FIXTURE','-Task','T1','-Commit',$s.tasks.T1.commit,'-Reason','Attribution is not defect resolution','-Json'); $r.code | Should -Be 50
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
        (State $f).agents_created | Should -Be 2 # A cached local verdict is reused on recovery.
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
    It 'creates a bounded integration worker for a real merge conflict in <Mode>' -ForEach @(@{Mode='L2'},@{Mode='L3'}) {
        $f=New-RuntimeFixture 2
        $f.plan.mode=$Mode
        if ($Mode -eq 'L3') { $f.plan.tasks[0].subagents=@{allowed=$true;max_depth=2} }
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
        (Read-TeamData (Join-Path $f.repo 'team/runtime/FIXTURE/plan.yaml')).mode | Should -Be $Mode
        $r=Invoke-Cli @('resume','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 0 -Because $r.raw
        $repair=(State $f).tasks['INTEGRATION-1']
        $packet=Read-TeamData (Join-Path $repair.directory 'task.yaml')
        $packet.role.definition.may_change_interfaces | Should -BeFalse
        $packet.role.definition.may_change_acceptance | Should -BeFalse
        $packet.role.definition.may_change_tests.only_if | Should -Contain 'adaptation_to_approved_contract'
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
        $manifest.team.enabled=$true; $manifest.budget.ledgers.deepseek.soft_limit=0; $manifest.budget.ledgers.deepseek.hard_limit=0; Write-TeamData $path $manifest
        $r=Invoke-Cli @('run','-Repo',$f.repo,'-Plan',$f.path,'-Manifest',$path,'-Json'); $r.code | Should -Be 0
        (State $f).status | Should -Be 'PAUSED'
        (State $f).tasks.T1.attempts | Should -Be 0
        $manifest.team.enabled=$false; Write-TeamData $path $manifest
        foreach ($command in @('resume','accept','integrate','replan','repair-integration','resolve-review','rollback','cleanup')) {
            $r=Invoke-Cli @($command,'-Repo',$f.repo,'-Run','FIXTURE','-Manifest',$path,'-Json'); $r.code | Should -Be 20 -Because "$command : $($r.raw)"
        }
        $r=Invoke-Cli @('stop','-Repo',$f.repo,'-Run','FIXTURE','-Manifest',$path,'-Json'); $r.code | Should -Be 0 -Because $r.raw
        (State $f).status | Should -Be 'CANCELLED'
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
    It 'rolls back multiple historical checkpoints and preserves failed final evidence' {
        $f=New-RuntimeFixture 2
        $f.plan.verification.final[0].args=@('-NoProfile','-Command','Write-Output "stable failure"; exit 9'); Write-TeamData $f.path $f.plan
        $r=Invoke-Cli @('run','-Repo',$f.repo,'-Plan',$f.path,'-Json'); $r.code | Should -Be 0
        Accept-All $f
        $r=Invoke-Cli @('integrate','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 40 -Because $r.raw
        $dir=Join-Path $f.repo 'team/runtime/FIXTURE'; $failure=Read-TeamData (Join-Path $dir 'integration-failure.json')
        $failure.last_merged_task | Should -Be 'T2'; $failure.checkpoints.Count | Should -Be 2
        $evidencePath=Join-Path $failure.directory 'final-evidence.json'; $hash=Get-TeamHash $evidencePath
        $first=Read-TeamData (Join-Path $dir 'checkpoints/T1.json'); $second=Read-TeamData (Join-Path $dir 'checkpoints/T2.json')
        foreach ($taskId in @('T2','T1')) {
            $r=Invoke-Cli @('rollback','-Repo',$f.repo,'-Run','FIXTURE','-Task',$taskId,'-Reason','Locate isolated final failure','-Json'); $r.code | Should -Be 0 -Because $r.raw
            (State $f).tasks[$taskId].status | Should -Be 'REWORK'
        }
        $s=State $f
        (Invoke-TeamGit $s.integration_worktree @('rev-parse','HEAD^{tree}')) | Should -Be (Invoke-TeamGit $f.repo @('rev-parse',"$($f.base)^{tree}"))
        $null=Invoke-TeamGit $s.integration_worktree @('merge-base','--is-ancestor',$first.after,'HEAD')
        $null=Invoke-TeamGit $s.integration_worktree @('merge-base','--is-ancestor',$second.after,'HEAD')
        (Get-TeamHash $evidencePath) | Should -Be $hash
        $failure=Read-TeamData (Join-Path $dir 'integration-failure.json'); $failure.probes.Count | Should -Be 2
        @($failure.probes | Where-Object result -eq 'inconclusive_still_fails').Count | Should -Be 2
        $draft=Read-TeamData (Join-Path $dir 'integration-failure-task.json')
        $draft.status | Should -Be 'draft'; $draft.sources | Should -Be @('T1','T2')
        $r=Invoke-Cli @('rollback','-Repo',$f.repo,'-Run','FIXTURE','-Task','T1','-Reason','Must not duplicate a revert','-Json'); $r.code | Should -Be 80
        (Invoke-TeamGit $f.repo @('rev-parse','main')) | Should -Be $f.base
    }
    It 'repairs a rolled-back earlier task while preserving unrelated later integrations and cleanup evidence' {
        $f=New-RuntimeFixture 3
        $f.plan.verification.final[0].args=@('-NoProfile','-Command','if (-not (Test-Path files/T1.txt) -or (Get-Content files/T1.txt -Raw).Trim() -ne "INTEGRATION-1" -or -not (Test-Path files/T2.txt) -or -not (Test-Path files/T3.txt)) { exit 9 }')
        Write-TeamData $f.path $f.plan
        $r=Invoke-Cli @('run','-Repo',$f.repo,'-Plan',$f.path,'-Json'); $r.code | Should -Be 0
        Accept-All $f
        $r=Invoke-Cli @('integrate','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 40 -Because $r.raw
        $s=State $f; $unrelated=@($s.tasks.T2.commit,$s.tasks.T3.commit)
        $r=Invoke-Cli @('cleanup','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 0
        $r=Invoke-Cli @('rollback','-Repo',$f.repo,'-Run','FIXTURE','-Task','T1','-Reason','Known fixture defect in the earliest independent task','-Json'); $r.code | Should -Be 0 -Because $r.raw
        $s=State $f; $s.tasks.T1.status | Should -Be 'REWORK'; $s.tasks.T2.status | Should -Be 'CLEANED'; $s.tasks.T3.status | Should -Be 'CLEANED'
        Test-Path (Join-Path $s.integration_worktree 'files/T1.txt') | Should -BeFalse
        Test-Path (Join-Path $s.integration_worktree 'files/T3.txt') | Should -BeTrue
        $r=Invoke-Cli @('repair-integration','-Repo',$f.repo,'-Run','FIXTURE','-Task','T1','-Reason','Restore the existing approved contract only','-Json'); $r.code | Should -Be 0 -Because $r.raw
        $s=State $f; $s.repairs['INTEGRATION-1'].source_tasks | Should -Be @('T1')
        $s.repairs['INTEGRATION-1'].write_scope | Should -Be @('files/T1.txt')
        $s.repairs['INTEGRATION-1'].glue_scope | Should -Be @('files/T1.txt')
        $s.repairs['INTEGRATION-1'].conflict_files.Count | Should -Be 0
        $decision=Read-TeamData (Join-Path $f.repo 'team/runtime/FIXTURE/decisions/DEC-Integration-2.json')
        $decision.glue_scope | Should -Be @('files/T1.txt')
        $r=Invoke-Cli @('resume','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 0 -Because $r.raw
        Accept-All $f
        $r=Invoke-Cli @('integrate','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 0 -Because $r.raw
        $r.data.status | Should -Be 'COMPLETED'
        $s=State $f; @($s.tasks.T2.commit,$s.tasks.T3.commit) | Should -Be $unrelated
        $s.tasks.T2.attempts | Should -Be 1; $s.tasks.T3.attempts | Should -Be 1
        (Read-TeamData (Join-Path $f.repo 'team/runtime/FIXTURE/integration-failure.json')).status | Should -Be 'resolved'
        $r=Invoke-Cli @('cleanup','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 0 -Because $r.raw
        (Invoke-TeamGit $f.repo @('rev-parse','main')) | Should -Be $f.base
    }
    It 'rolls back a dependency closure in reverse merge order and only replans that closure' {
        $f=New-RuntimeFixture 3; $f.plan.tasks[2].dependencies=@('T1'); Write-TeamData $f.path $f.plan
        $r=Invoke-Cli @('run','-Repo',$f.repo,'-Plan',$f.path,'-Json'); $r.code | Should -Be 0
        Accept-All $f
        $r=Invoke-Cli @('integrate','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 0
        $r=Invoke-Cli @('resume','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 0
        Accept-All $f
        $r=Invoke-Cli @('integrate','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 0
        $unrelated=(State $f).tasks.T2.commit
        $r=Invoke-Cli @('rollback','-Repo',$f.repo,'-Run','FIXTURE','-Task','T1','-Reason','Rework one dependency chain only','-Json'); $r.code | Should -Be 0 -Because $r.raw
        $r.data.rolled_back | Should -Be @('T3','T1')
        $s=State $f; $s.tasks.T2.status | Should -Be 'MERGED'; $s.tasks.T3.status | Should -Be 'REWORK'
        $f.plan.run.revision=2; Write-TeamData $f.path $f.plan
        $r=Invoke-Cli @('replan','-Repo',$f.repo,'-Run','FIXTURE','-Plan',$f.path,'-Task','T1','-Reason','Re-run the affected closure','-Json'); $r.code | Should -Be 0 -Because $r.raw
        foreach ($wave in 1..2) {
            $r=Invoke-Cli @('resume','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 0 -Because $r.raw
            Accept-All $f
            $r=Invoke-Cli @('integrate','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 0 -Because $r.raw
        }
        $r.data.status | Should -Be 'COMPLETED'
        (State $f).tasks.T2.commit | Should -Be $unrelated; (State $f).tasks.T2.attempts | Should -Be 1
        (State $f).tasks.T1.attempts | Should -Be 2; (State $f).tasks.T3.attempts | Should -Be 2
        @(Get-ChildItem (Join-Path $f.repo 'team/runtime/FIXTURE/checkpoints/history') -Filter '*.json').Count | Should -Be 5
    }
    It 'does not revert an unrelated commit when an accepted task is a no-op' {
        $f=New-RuntimeFixture; $f.plan.tasks[0].objective=@('NOOP')
        $f.plan.tasks[0].verification[0].args=@('-NoProfile','-Command','exit 0'); $f.plan.verification.final=$f.plan.tasks[0].verification
        Write-TeamData $f.path $f.plan
        $r=Invoke-Cli @('run','-Repo',$f.repo,'-Plan',$f.path,'-Json'); $r.code | Should -Be 0 -Because $r.raw
        Accept-All $f
        $r=Invoke-Cli @('integrate','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 0
        $r.data.commit | Should -Be $f.base
        $r=Invoke-Cli @('rollback','-Repo',$f.repo,'-Run','FIXTURE','-Task','T1','-Reason','Invalidate the no-op task only','-Json'); $r.code | Should -Be 0 -Because $r.raw
        $r.data.commit | Should -Be $f.base
        (State $f).tasks.T1.status | Should -Be 'REWORK'
        $f.plan.run.revision=2; Write-TeamData $f.path $f.plan
        $r=Invoke-Cli @('replan','-Repo',$f.repo,'-Run','FIXTURE','-Plan',$f.path,'-Task','T1','-Reason','Explicitly repeat the no-op task','-Json'); $r.code | Should -Be 0
        $r=Invoke-Cli @('resume','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 0
        Accept-All $f
        $r=Invoke-Cli @('integrate','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 0 -Because $r.raw
        @(Get-ChildItem (Join-Path $f.repo 'team/runtime/FIXTURE/checkpoints/history') -Filter '*.json').Count | Should -Be 2
    }
    It 'refuses rollback on an altered integration branch or untracked user file' {
        $f=New-RuntimeFixture
        $r=Invoke-Cli @('run','-Repo',$f.repo,'-Plan',$f.path,'-Json'); $r.code | Should -Be 0
        Accept-All $f
        $r=Invoke-Cli @('integrate','-Repo',$f.repo,'-Run','FIXTURE','-Json'); $r.code | Should -Be 0
        $s=State $f; $head=$s.last_good_integration_sha
        $untracked=Join-Path $s.integration_worktree 'owner-note.txt'; Set-Content $untracked 'Preserve this file'
        $r=Invoke-Cli @('rollback','-Repo',$f.repo,'-Run','FIXTURE','-Task','T1','-Reason','Must refuse dirty tree','-Json'); $r.code | Should -Be 80
        (Get-Content $untracked -Raw).Trim() | Should -Be 'Preserve this file'
        [IO.File]::Delete($untracked)
        $null=Invoke-TeamGit $s.integration_worktree @('switch','-c','fixture-unexpected')
        $r=Invoke-Cli @('rollback','-Repo',$f.repo,'-Run','FIXTURE','-Task','T1','-Reason','Must refuse wrong branch','-Json'); $r.code | Should -Be 82
        (Invoke-TeamGit $s.integration_worktree @('rev-parse','HEAD')) | Should -Be $head
    }
}
