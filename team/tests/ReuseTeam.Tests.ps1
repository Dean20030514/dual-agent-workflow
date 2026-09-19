# Team-side admission, propagation and legacy tests for the frozen reuse protocol.
# All fixtures are synthetic: the CLI stand-in never performs real DSH work, and every
# artifact is written under $TestDrive (or the run directory inside it).
BeforeAll {
    . (Join-Path $PSScriptRoot "LeadFixture.ps1")
    $script:LeadEnvironment=Enable-TeamLeadFixture $TestDrive
    $script:TeamPath = Split-Path $PSScriptRoot -Parent
    $script:RepoRoot = Split-Path $script:TeamPath -Parent
    foreach ($module in @('Core','PriorArt','Lead','Contracts','Preflight','State','Controls','Execution','IntegrationRecovery',
        'Checkpoints','Revisions','Rollbacks','Integration','Recovery','ReviewRounds','Review','LocalReview','Conflict','Activity',
        'Reuse','Prerequisites','Archive','Report')) {
        . (Join-Path $script:TeamPath "scripts/$module.ps1")
    }
    $script:ManifestData = Read-TeamData (Join-Path $script:TeamPath 'manifest.yaml')
    $script:OriginalPath = $env:PATH
    $script:OriginalDshHome = $env:DSH_HOME
    $env:PATH = (Join-Path $PSScriptRoot 'fixtures') + [IO.Path]::PathSeparator + $env:PATH
    $env:DSH_HOME = Join-Path $TestDrive 'empty-dsh-home'
    New-Item -ItemType Directory $env:DSH_HOME -Force | Out-Null

    function Assert-TeamCode($Action,[int]$Expected) {
        $caught=$null
        try { & $Action | Out-Null } catch { $caught=$_ }
        $caught | Should -Not -BeNullOrEmpty
        $caught.Exception.Data['TeamExitCode'] | Should -Be $Expected -Because $caught.Exception.Message
    }

    function New-SkippedDecision {
        return @{ version=1; applicability='skipped'; status='skipped'
            reason='FIXTURE_DECISION_REASON: every task only writes one local fixture file.'
            searches=@(); candidates=@(); strategy='build'
            rationale='FIXTURE_DECISION_RATIONALE: a local fixture file raises no prior-art question.'
            constraints=@() }
    }

    function New-CompletedDecision {
        return @{ version=1; applicability='required'; status='completed'
            reason='FIXTURE_DECISION_REASON: the task adds a new capability.'
            searches=@(
                @{ source='github_repositories'; query='FIXTURE_SEARCH_QUERY'; outcome='results'; summary='one comparable project'; evidence=@('https://example.org/prior-art') },
                @{ source='github_code'; query='FIXTURE_SEARCH_QUERY code'; outcome='results'; summary='one reusable validator'; evidence=@('https://example.org/prior-art/code') },
                @{ source='primary_docs'; query='FIXTURE_SEARCH_QUERY docs'; outcome='no_results'; summary='no normative page matched'; evidence=@() })
            candidates=@(@{ id='prior-art'; url='https://example.org/prior-art'; revision='0123456789abcdef0123456789abcdef01234567'
                decision='reference'; rationale='FIXTURE_CANDIDATE_RATIONALE: the document shape fits.'; borrow='The single source idea.'; constraints=@('Do not copy external code.') })
            strategy='reference'
            rationale='FIXTURE_DECISION_RATIONALE: borrow the shape only and implement it here.'
            constraints=@('FIXTURE_DECISION_CONSTRAINT: no new dependency.') }
    }

    function New-BlockedDecision {
        return @{ version=1; applicability='required'; status='blocked'
            reason='FIXTURE_DECISION_REASON: the registry search is unavailable, so the prior-art pass cannot complete.'
            searches=@(
                @{ source='github_repositories'; query='FIXTURE_SEARCH_QUERY repositories'; outcome='results'; summary='comparable projects'; evidence=@('https://example.org/prior-art') },
                @{ source='github_code'; query='FIXTURE_SEARCH_QUERY code'; outcome='results'; summary='reusable validator'; evidence=@('https://example.org/prior-art/code') },
                @{ source='primary_docs'; query='FIXTURE_SEARCH_QUERY docs'; outcome='no_results'; summary='no normative page matched'; evidence=@() },
                @{ source='package_registry'; query='FIXTURE_SEARCH_QUERY registry'; outcome='unavailable'; summary='FIXTURE_SEARCH_SUMMARY the endpoint refused the request'; evidence=@('receipt: fixture-registry-20260919T101500Z') })
            candidates=@(); strategy='build'
            rationale='FIXTURE_DECISION_RATIONALE: no candidate can be chosen until the search is repeated.'
            constraints=@('FIXTURE_DECISION_CONSTRAINT: pause before creating any worker worktree.') }
    }

    function New-ReuseTask([string]$Id='T1',[string]$Scope='files/T1.txt',[string[]]$Refs=@(),[switch]$Required) {
        $reuse = if (@($Refs).Count -or $Required) {
            @{ applicability='required'; reason="FIXTURE_TASK_REASON: implements the new capability for $Id."; change_kinds=@('new_implementation'); refs=@($Refs) }
        } else {
            @{ applicability='skipped'; reason='Follows the repository existing fixture pattern.'; change_kinds=@('established_repo_pattern')
                refs=@(); skip_reason='established_repo_pattern' }
        }
        return @{ id=$Id; role='backend'; objective=@('WRITE'); dependencies=@(); write_scope=@($Scope)
            acceptance=@("$Scope exists after the author commits and the worktree is clean")
            permissions=@{ shell=$true; network=$false; secrets=$false; production=$false }
            subagents=@{ allowed=$false; max_depth=0 }; reuse=$reuse
            verification=@(@{ id='exists'; executable='pwsh'; args=@('-NoProfile','-Command',"if (-not (Test-Path $Scope)) { exit 1 }"); timeout_seconds=10 }) }
    }

    function New-ReuseFixture($Decision, $Tasks, [string]$RunId='REUSE', [string]$Mode='L1') {
        $repo = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory $repo | Out-Null
        $null = Invoke-TeamGit $repo @('init','-q','-b','main')
        $null = Invoke-TeamGit $repo @('config','user.name','ReuseFixture')
        $null = Invoke-TeamGit $repo @('config','user.email','fixture@example.invalid')
        [IO.File]::WriteAllText((Join-Path $repo '.gitignore'),"team/runtime/`n.worktrees/`n")
        $null = Invoke-TeamGit $repo @('add','.gitignore')
        $null = Invoke-TeamGit $repo @('commit','-qm','test: reuse fixture')
        $plan = @{ schema_version=1; run=@{ id=$RunId; revision=1 }
            classification=@{ level='routine'; reasons=@('reuse admission fixture') }
            mode=$Mode; capabilities=@('backend'); reuse=$Decision; tasks=@($Tasks)
            verification=@{ final=@(@{ id='final'; executable='pwsh'; args=@('-NoProfile','-Command','exit 0'); timeout_seconds=10 }) }
            review=@{ require_9p=$false; require_fresh_9b=$false } }
        $path = Join-Path $TestDrive ('plan-' + [guid]::NewGuid().ToString('N') + '.json')
        Write-TeamData $path $plan
        return @{ repo=$repo; plan=$plan; path=$path; run_id=$RunId; directory=(Join-Path $repo "team/runtime/$RunId") }
    }

    function Invoke-ReuseCli([string[]]$Arguments) {
        $text = & pwsh -NoProfile -File (Join-Path $script:TeamPath 'scripts/team.ps1') @Arguments
        return @{ code=$LASTEXITCODE; data=($text | ConvertFrom-Json -AsHashtable); raw=($text -join "`n") }
    }
    function Get-ReuseState($Fixture) { Read-TeamData (Join-Path $Fixture.directory 'state.json') }
    function Save-ReuseState($Fixture, $State) { Write-TeamData (Join-Path $Fixture.directory 'state.json') $State }
    function Get-ReuseEscalations($Fixture) {
        return @(Get-ChildItem -LiteralPath (Join-Path $Fixture.directory 'escalations') -Filter '*.yaml' -ErrorAction SilentlyContinue |
            ForEach-Object { Read-TeamData $_.FullName })
    }
    function New-TestRuntime { return @{ max_single_log_mb = 5; idle_timeout_seconds = 30; max_diff_bytes = 2000000; max_review_input_bytes = 4000000 } }
}
AfterAll { Restore-TeamLeadFixture $script:LeadEnvironment; $env:PATH=$script:OriginalPath; $env:DSH_HOME=$script:OriginalDshHome }

Describe 'Plan reuse admission documents' {
    It 'rejects a legacy plan without a top-level decision before any run metadata exists' {
        $fixture=New-ReuseFixture (New-SkippedDecision) @((New-ReuseTask))
        $legacy=$fixture.plan | ConvertTo-Json -Depth 40 | ConvertFrom-Json -AsHashtable
        $legacy.Remove('reuse')
        $path=Join-Path $TestDrive 'legacy-plan.json'; Write-TeamData $path $legacy
        $result=Invoke-ReuseCli @('run','-Repo',$fixture.repo,'-Plan',$path,'-Json')
        $result.code | Should -Be 10 -Because $result.raw
        $result.data.event | Should -Be 'plan_invalid'
        $result.data.error | Should -Match 'top-level reuse decision'
        Test-Path (Join-Path $fixture.repo 'team/runtime') | Should -BeFalse
    }
    It 'requires one declaration per task and rejects an illegal skip reason' {
        $fixture=New-ReuseFixture (New-SkippedDecision) @((New-ReuseTask))
        $noTask=$fixture.plan | ConvertTo-Json -Depth 40 | ConvertFrom-Json -AsHashtable
        $noTask.tasks[0].Remove('reuse')
        Assert-TeamCode { Test-TeamPlan $noTask $script:ManifestData } 10
        $illegal=$fixture.plan | ConvertTo-Json -Depth 40 | ConvertFrom-Json -AsHashtable
        $illegal.tasks[0].reuse.skip_reason='not needed'
        Assert-TeamCode { Test-TeamPlan $illegal $script:ManifestData } 10
        $forced=$fixture.plan | ConvertTo-Json -Depth 40 | ConvertFrom-Json -AsHashtable
        $forced.tasks[0].reuse.change_kinds=@('new_implementation')
        Assert-TeamCode { Test-TeamPlan $forced $script:ManifestData } 10
        $undeclared=$fixture.plan | ConvertTo-Json -Depth 40 | ConvertFrom-Json -AsHashtable
        $undeclared.Remove('reuse')
        Assert-TeamCode { Test-TeamPlan $undeclared $script:ManifestData } 10
        @(Test-TeamPlan $fixture.plan $script:ManifestData) | Should -Be @('T1')
    }
    It 'fails closed when a dispatch carries no plan-level decision' {
        $fixture=New-ReuseFixture (New-SkippedDecision) @((New-ReuseTask))
        $result=Invoke-ReuseCli @('run','-Repo',$fixture.repo,'-Plan',$fixture.path,'-Json')
        $result.code | Should -Be 0 -Because $result.raw
        $state=Get-ReuseState $fixture
        # Start-TeamWorker keeps a task-only fallback plan for a missing -Plan. That shape must
        # never admit a dispatch, and the only production caller (Invoke-TeamDispatch) always
        # passes the full plan. A source search for Start-TeamWorker confirms that call site.
        Assert-TeamCode { Assert-TeamReuseAdmission $state @{ tasks=@($fixture.plan.tasks[0]) } $fixture.directory } 10
    }
    It 'derives a bounded context without search logs or decision prose' {
        $plan=@{ tasks=@((New-ReuseTask 'T1' 'files/T1.txt' @('prior-art'))); reuse=(New-CompletedDecision) }
        $context=Get-TeamReuseTaskContext $plan $plan.tasks[0] ('c'*64)
        @($context.candidates | ForEach-Object { $_.id }) | Should -Be @('prior-art')
        $context.decision.constraints | Should -Contain 'FIXTURE_DECISION_CONSTRAINT: no new dependency.'
        $serialized=$context | ConvertTo-Json -Depth 20
        $serialized | Should -Not -Match 'FIXTURE_SEARCH_QUERY'
        $serialized | Should -Not -Match 'FIXTURE_DECISION_REASON'
        $serialized | Should -Not -Match 'FIXTURE_DECISION_RATIONALE'
    }
}

Describe 'Blocked reuse admission' {
    It 'pauses before prerequisites, worktrees and workers' {
        $marker=Join-Path $TestDrive ('prereq-' + [guid]::NewGuid().ToString('N') + '.txt')
        $fixture=New-ReuseFixture (New-BlockedDecision) @((New-ReuseTask -Required))
        $fixture.plan['prerequisites']=@(@{ id='setup'; executable='pwsh'; timeout_seconds=30
            args=@('-NoProfile','-Command',"Set-Content -LiteralPath '$marker' ran") })
        Write-TeamData $fixture.path $fixture.plan
        $result=Invoke-ReuseCli @('run','-Repo',$fixture.repo,'-Plan',$fixture.path,'-Json')
        $result.code | Should -Be 70 -Because $result.raw
        Test-Path -LiteralPath $marker | Should -BeFalse
        Test-Path (Join-Path $fixture.repo '.worktrees') | Should -BeFalse
        Test-Path (Join-Path $fixture.directory 'tasks') | Should -BeFalse
        Test-Path (Join-Path $fixture.directory 'prerequisites.json') | Should -BeFalse
        $state=Get-ReuseState $fixture
        $state.status | Should -Be 'ESCALATED'
        $state.tasks.T1.attempts | Should -Be 0
        $state.reuse_protocol.hash | Should -Match '^[a-f0-9]{64}$'
        foreach ($name in @('README.md','reuse.schema.json','Reuse.ps1')) {
            Test-Path (Join-Path $fixture.directory "reuse-protocol/$name") | Should -BeTrue
        }
        $escalations=@(Get-ReuseEscalations $fixture)
        @($escalations | Where-Object type -eq 'reuse_unavailable').Count | Should -Be 1
        $escalations[0].plan_hash | Should -Be $state.plan_hash
        $escalations[0].expires_at | Should -Not -BeNullOrEmpty
        # A resume without an owner decision pauses again and still spawns nothing.
        $result=Invoke-ReuseCli @('resume','-Repo',$fixture.repo,'-Run',$fixture.run_id,'-Json')
        $result.code | Should -Be 70 -Because $result.raw
        Test-Path (Join-Path $fixture.repo '.worktrees') | Should -BeFalse
        @(Get-ReuseEscalations $fixture).Count | Should -Be 1
        # The read-only summary reports the decision and the blocking fact, never telemetry.
        $status=Invoke-ReuseCli @('status','-Repo',$fixture.repo,'-Run',$fixture.run_id,'-Json')
        $status.code | Should -Be 0 -Because $status.raw
        $status.data.summary.reuse.status | Should -Be 'blocked'
        $status.data.summary.reuse.decision.strategy | Should -Be 'build'
        $status.data.summary.reuse.tasks[0].usage.declared | Should -BeFalse
        ($status.data.summary.reuse | ConvertTo-Json -Depth 20) | Should -Not -Match 'FIXTURE_SEARCH_QUERY'
    }
    It 'does not admit a rejected escalation' {
        $fixture=New-ReuseFixture (New-BlockedDecision) @((New-ReuseTask -Required))
        $result=Invoke-ReuseCli @('run','-Repo',$fixture.repo,'-Plan',$fixture.path,'-Json')
        $result.code | Should -Be 70 -Because $result.raw
        $escalation=@(Get-ReuseEscalations $fixture)[0]
        $result=Invoke-ReuseCli @('resolve','-Repo',$fixture.repo,'-Run',$fixture.run_id,'-Escalation',$escalation.id,'-Decision','reject','-Reason','No exception for the unavailable search','-Json')
        $result.code | Should -Be 0 -Because $result.raw
        $result=Invoke-ReuseCli @('resume','-Repo',$fixture.repo,'-Run',$fixture.run_id,'-Json')
        $result.code | Should -Be 80 -Because $result.raw
        Test-Path (Join-Path $fixture.repo '.worktrees') | Should -BeFalse
        (Get-ReuseState $fixture).tasks.T1.attempts | Should -Be 0
    }
    It 'ignores an approval bound to another plan hash and an expired approval' {
        foreach ($case in @('mismatched','expired')) {
            $fixture=New-ReuseFixture (New-BlockedDecision) @((New-ReuseTask -Required))
            $result=Invoke-ReuseCli @('run','-Repo',$fixture.repo,'-Plan',$fixture.path,'-Json')
            $result.code | Should -Be 70 -Because $result.raw
            $state=Get-ReuseState $fixture
            $escalations=@(Get-ReuseEscalations $fixture)
            $escalations.Count | Should -Be 1 -Because $result.raw
            $path=Join-Path $fixture.directory "escalations/$($escalations[0].id).yaml"
            $record=Read-TeamData $path
            $record.status='approve'; $record['reason']='Owner approved an exception'
            if ($case -eq 'mismatched') { $record['plan_hash']=('f'*64) } else { $record['expires_at']=[DateTime]::UtcNow.AddHours(-1).ToString('o') }
            Write-TeamData $path $record
            $result=Invoke-ReuseCli @('resume','-Repo',$fixture.repo,'-Run',$fixture.run_id,'-Json')
            $result.code | Should -Be 70 -Because "$case : $($result.raw)"
            Test-Path (Join-Path $fixture.repo '.worktrees') | Should -BeFalse
            # A fresh pending escalation is registered for the exact current plan hash.
            $pending=@(Get-ReuseEscalations $fixture | Where-Object { $_.type -eq 'reuse_unavailable' -and $_.status -eq 'pending' })
            $pending.Count | Should -Be 1
            $pending[0].plan_hash | Should -Be $state.plan_hash
        }
    }
    It 'resumes after a same-plan approval and propagates the bounded context to result and review' {
        $fixture=New-ReuseFixture (New-BlockedDecision) @((New-ReuseTask -Required))
        $result=Invoke-ReuseCli @('run','-Repo',$fixture.repo,'-Plan',$fixture.path,'-Json')
        $result.code | Should -Be 70 -Because $result.raw
        $escalation=@(Get-ReuseEscalations $fixture)[0]
        $result=Invoke-ReuseCli @('resolve','-Repo',$fixture.repo,'-Run',$fixture.run_id,'-Escalation',$escalation.id,'-Decision','approve','-Reason','Owner accepts the unavailable search for this plan hash','-Json')
        $result.code | Should -Be 0 -Because $result.raw
        $status=Invoke-ReuseCli @('status','-Repo',$fixture.repo,'-Run',$fixture.run_id,'-Json')
        $status.data.summary.reuse.exception.escalation | Should -Be $escalation.id
        $result=Invoke-ReuseCli @('resume','-Repo',$fixture.repo,'-Run',$fixture.run_id,'-Json')
        $result.code | Should -Be 0 -Because $result.raw
        $state=Get-ReuseState $fixture
        $state.tasks.T1.attempts | Should -Be 1
        $state.tasks.T1.status | Should -Be 'REVIEW'
        Test-Path (Join-Path $fixture.repo '.worktrees') | Should -BeTrue
        # The dispatched packet carries the derived context and the worker Result answers it.
        $packet=Read-TeamData (Join-Path $state.tasks.T1.directory 'task.yaml')
        $packet.reuse_context.plan_hash | Should -Be $state.plan_hash
        $packet.reuse_context.decision.status | Should -Be 'blocked'
        @($packet.reuse_context.task.change_kinds) | Should -Be @('new_implementation')
        $workerResult=Read-TeamData (Join-Path $state.tasks.T1.directory 'result.yaml')
        @($workerResult.reuse.references_used) | Should -Be @()
        @($workerResult.reuse.deviations) | Should -Be @()
        # The LOCAL reviewer received the bounded facts and never the search log or decision prose.
        $archive=Join-Path $fixture.directory "reviews/archives/$([IO.Path]::GetFileName($state.tasks.T1.local_review.directory))"
        $prompt=[IO.File]::ReadAllText((Join-Path $archive 'prompt.txt'))
        $prompt | Should -Match 'Reuse decision and declarations \(bounded; search logs and decision rationale are not supplied\)'
        $prompt | Should -Match ([regex]::Escape('FIXTURE_DECISION_CONSTRAINT: pause before creating any worker worktree.'))
        $prompt | Should -Match 'reuse_context'
        $prompt | Should -Not -Match 'FIXTURE_SEARCH_QUERY'
        $prompt | Should -Not -Match 'FIXTURE_SEARCH_SUMMARY'
        $prompt | Should -Not -Match 'FIXTURE_DECISION_REASON'
        $prompt | Should -Not -Match 'FIXTURE_DECISION_RATIONALE'
    }
    It 'rejects a run whose frozen protocol evidence or availability changed' {
        $fixture=New-ReuseFixture (New-SkippedDecision) @((New-ReuseTask))
        $result=Invoke-ReuseCli @('run','-Repo',$fixture.repo,'-Plan',$fixture.path,'-Json')
        $result.code | Should -Be 0 -Because $result.raw
        $before=Get-ReuseState $fixture
        [IO.File]::AppendAllText((Join-Path $fixture.directory 'reuse-protocol/README.md'),"`nchanged")
        $result=Invoke-ReuseCli @('resume','-Repo',$fixture.repo,'-Run',$fixture.run_id,'-Json')
        $result.code | Should -Be 80 -Because $result.raw
        $result.data.error | Should -Match 'Frozen reuse protocol evidence changed'
        $after=Get-ReuseState $fixture
        $after.tasks.T1.attempts | Should -Be $before.tasks.T1.attempts
        @(Get-ChildItem (Join-Path $fixture.directory 'tasks/T1') -Directory).Count | Should -Be $before.tasks.T1.attempts
    }
}

Describe 'Result reuse enforcement' {
    BeforeEach {
        $script:Repo = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory $script:Repo | Out-Null
        $null=Invoke-TeamGit $script:Repo @('init','-q','-b','fixture')
        $null=Invoke-TeamGit $script:Repo @('config','user.name','ReuseFixture')
        $null=Invoke-TeamGit $script:Repo @('config','user.email','fixture@example.invalid')
        Set-Content -LiteralPath (Join-Path $script:Repo 'allowed.txt') -Value 'base'
        $null=Invoke-TeamGit $script:Repo @('add','allowed.txt')
        $null=Invoke-TeamGit $script:Repo @('commit','-qm','test: base')
        $script:Base=Invoke-TeamGit $script:Repo @('rev-parse','HEAD')
        Set-Content -LiteralPath (Join-Path $script:Repo 'allowed.txt') -Value 'changed'
        $null=Invoke-TeamGit $script:Repo @('commit','-qam','test: change')
        $script:Head=Invoke-TeamGit $script:Repo @('rev-parse','HEAD')
        $script:Attempt=Join-Path $TestDrive ('attempt-' + [guid]::NewGuid().ToString('N'))
        [IO.Directory]::CreateDirectory($script:Attempt) | Out-Null
        $script:Task=New-ReuseTask 'T1' 'allowed.txt' @('prior-art')
        $plan=@{ tasks=@($script:Task); reuse=(New-CompletedDecision) }
        $script:Context=Get-TeamReuseTaskContext $plan $script:Task ('c'*64)
        $packet=@{ schema_version=1; run_id='R1'; task_id='T1'; role=@{ id='backend' }; objective=@('WRITE')
            dependencies=@(); permissions=@{ shell=$true; network=$false; secrets=$false; production=$false }
            write_scope=@('allowed.txt'); acceptance=@('allowed.txt exists'); subagents=@{ allowed=$false; max_depth=0 }
            base_sha=$script:Base; result_schema='result-v1'; verification=$script:Task.verification
            reuse=$script:Task.reuse; reuse_context=$script:Context }
        Write-TeamData (Join-Path $script:Attempt 'task.yaml') $packet
        $script:Result=@{ schema_version=1; run_id='R1'; task_id='T1'; status='completed'; summary=@('done')
            changed_files=@('allowed.txt'); verification=@{ passed=$true }; subagents_used=@(); risks=@()
            git=@{ branch='fixture'; commit=$script:Head } }
        Write-TeamData (Join-Path $script:Attempt 'result.yaml') $script:Result
        $script:Item=@{ worktree=$script:Repo; directory=$script:Attempt; branch='fixture'; base_sha=$script:Base }
    }
    It 'requires a declaration and rejects unknown, out-of-task and unexplained references' {
        Assert-TeamCode { Read-WorkerResult $script:Item $script:Task 'R1' } 10
        $script:Result['reuse']=@{ references_used=@('outside-candidate'); deviations=@() }
        Write-TeamData (Join-Path $script:Attempt 'result.yaml') $script:Result
        Assert-TeamCode { Read-WorkerResult $script:Item $script:Task 'R1' } 10
        $script:Result['reuse']=@{ references_used=@(); deviations=@() }
        Write-TeamData (Join-Path $script:Attempt 'result.yaml') $script:Result
        Assert-TeamCode { Read-WorkerResult $script:Item $script:Task 'R1' } 10
        $script:Result['reuse']=@{ references_used=@(); deviations=@(@{ reference='prior-art'; reason='The referenced revision was unreachable.' }) }
        Write-TeamData (Join-Path $script:Attempt 'result.yaml') $script:Result
        (Read-WorkerResult $script:Item $script:Task 'R1').commit | Should -Be $script:Head
        $script:Result['reuse']=@{ references_used=@('prior-art'); deviations=@() }
        Write-TeamData (Join-Path $script:Attempt 'result.yaml') $script:Result
        (Read-WorkerResult $script:Item $script:Task 'R1').commit | Should -Be $script:Head
        $script:Result['reuse']=@{ references_used='prior-art'; deviations=@() }
        Write-TeamData (Join-Path $script:Attempt 'result.yaml') $script:Result
        Assert-TeamCode { Read-WorkerResult $script:Item $script:Task 'R1' } 10
    }
    It 'accepts empty usage for a skipped declaration and rejects a deviation for an unknown reference' {
        $task=New-ReuseTask 'T1' 'allowed.txt'
        $plan=@{ tasks=@($task); reuse=(New-SkippedDecision) }
        $context=Get-TeamReuseTaskContext $plan $task ('d'*64)
        $packet=Read-TeamData (Join-Path $script:Attempt 'task.yaml')
        $packet.reuse=$task.reuse; $packet.reuse_context=$context
        Write-TeamData (Join-Path $script:Attempt 'task.yaml') $packet
        $script:Result['reuse']=@{ references_used=@(); deviations=@() }
        Write-TeamData (Join-Path $script:Attempt 'result.yaml') $script:Result
        (Read-WorkerResult $script:Item $task 'R1').commit | Should -Be $script:Head
        $script:Result['reuse']=@{ references_used=@(); deviations=@(@{ reference='prior-art'; reason='Not prescribed here.' }) }
        Write-TeamData (Join-Path $script:Attempt 'result.yaml') $script:Result
        Assert-TeamCode { Read-WorkerResult $script:Item $task 'R1' } 10
    }
    It 'keeps an incomplete result on its escalation path when the reuse declaration is absent' {
        $fixture=New-ReuseFixture (New-CompletedDecision) @((New-ReuseTask -Required -Refs @('prior-art')))
        $fixture.plan.tasks[0].objective=@('ESCALATE_NO_REUSE')
        Write-TeamData $fixture.path $fixture.plan
        $result=Invoke-ReuseCli @('run','-Repo',$fixture.repo,'-Plan',$fixture.path,'-Json')
        $result.code | Should -Be 70 -Because $result.raw
        $state=Get-ReuseState $fixture
        $state.status | Should -Be 'ESCALATED'
        $state.tasks.T1.status | Should -Be 'ESCALATED'
        # The packet really carried a context and the Result really omitted the declaration.
        $packet=Read-TeamData (Join-Path $state.tasks.T1.directory 'task.yaml')
        $packet.Contains('reuse_context') | Should -BeTrue
        $workerResult=Read-TeamData (Join-Path $state.tasks.T1.directory 'result.yaml')
        $workerResult.status | Should -Be 'escalated'
        $workerResult.Contains('reuse') | Should -BeFalse
        $requests=@(Get-ReuseEscalations $fixture | Where-Object type -eq 'worker_request')
        $requests.Count | Should -Be 1 -Because 'the escalated worker request must survive the reuse contract'
        # A completed Result with the same omission is still refused by the ingestion contract.
        $workerResult.status='completed'; $workerResult.verification.passed=$true
        Write-TeamData (Join-Path $state.tasks.T1.directory 'result.yaml') $workerResult
        Assert-TeamCode { Read-WorkerResult $state.tasks.T1 $fixture.plan.tasks[0] $fixture.run_id -AllowIncomplete } 10
    }
}

Describe 'Blind 9B and 9A reuse material' {
    BeforeAll {
        $script:BlindRepo = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory $script:BlindRepo | Out-Null
        $null=Invoke-TeamGit $script:BlindRepo @('init','-q','-b','fixture')
        $null=Invoke-TeamGit $script:BlindRepo @('config','user.name','ReuseFixture')
        $null=Invoke-TeamGit $script:BlindRepo @('config','user.email','fixture@example.invalid')
        Set-Content -LiteralPath (Join-Path $script:BlindRepo 'a.txt') 'one'
        $null=Invoke-TeamGit $script:BlindRepo @('add','a.txt')
        $null=Invoke-TeamGit $script:BlindRepo @('commit','-qm','test: base')
        $script:BlindBase=Invoke-TeamGit $script:BlindRepo @('rev-parse','HEAD')
        Set-Content -LiteralPath (Join-Path $script:BlindRepo 'a.txt') 'one two'
        $null=Invoke-TeamGit $script:BlindRepo @('commit','-qam','test: change')
        $script:BlindTip=Invoke-TeamGit $script:BlindRepo @('rev-parse','HEAD')
        $script:BlindDirectory=Join-Path $TestDrive ('blind-' + [guid]::NewGuid().ToString('N'))
        [IO.Directory]::CreateDirectory($script:BlindDirectory) | Out-Null
        $script:BlindAttempt=Join-Path $script:BlindDirectory 'tasks/T1/attempt-1'
        [IO.Directory]::CreateDirectory($script:BlindAttempt) | Out-Null
        Write-TeamData (Join-Path $script:BlindAttempt 'result.yaml') @{ subagents_used=@(); risks=@('untrusted claim')
            reuse=@{ references_used=@('prior-art'); deviations=@() } }
        Write-TeamData (Join-Path $script:BlindAttempt 'verification-evidence.json') @(@{ id='exists'; executable='pwsh'
            args=@('-NoProfile'); exit_code=0; process_started=$true; timeout_kind=$null; reused=$false; duration_seconds=0.2
            stdout_file='verification-exists.stdout'; stdout_bytes=16; stdout_sha256=('a'*64)
            stderr_file='verification-exists.stderr'; stderr_bytes=0; stderr_sha256=('b'*64) })
        $script:BlindFinal=Join-Path $script:BlindDirectory 'final-evidence'
        [IO.Directory]::CreateDirectory($script:BlindFinal) | Out-Null
        Write-TeamData (Join-Path $script:BlindFinal 'final-evidence.json') @(@{ id='final'; executable='pwsh'; args=@('-NoProfile')
            exit_code=0; process_started=$true; timeout_kind=$null; reused=$false; duration_seconds=0.1 })
        $script:BlindAuthority=New-TeamAuthority $script:BlindRepo $script:BlindBase $script:BlindDirectory
        $script:BlindState=@{ run_id='R1'; run_base_sha=$script:BlindBase; plan_hash=('c'*64); order=@('T1')
            authority_hash=$script:BlindAuthority; final_evidence_directory=$script:BlindFinal
            tasks=@{ T1=@{ directory=$script:BlindAttempt } } }
        $script:BlindDecision=New-CompletedDecision
        # A second candidate nobody uses: the blind stage must never receive its source facts.
        $script:BlindDecision.candidates+=@{ id='unused-candidate'; url='https://example.org/unused-source'; revision='v9'
            decision='reference'; rationale='FIXTURE_UNUSED_RATIONALE: not part of this task.'; borrow='Nothing yet.'
            constraints=@('FIXTURE_UNUSED_CONSTRAINT') }
        $blindTask=New-ReuseTask 'T1' 'a.txt' @('prior-art')
        # Objective prose is the author's implementation strategy; 9B must not receive it.
        $blindTask.objective=@('OBJECTIVE_STRATEGY_MUST_NOT_LEAK: implement the fixture with a bespoke parser.')
        $blindTask['issue_acceptance_map']=@(@{ objective_index=0; acceptance_indexes=@(0) })
        $script:BlindPlan=@{ schema_version=1; run=@{ id='R1'; revision=1 }
            classification=@{ level='critical'; reasons=@('reuse review fixture') }; mode='L2'; capabilities=@('backend')
            reuse=$script:BlindDecision; tasks=@($blindTask)
            verification=@{ final=@(@{ id='final'; executable='pwsh'; args=@('-NoProfile'); timeout_seconds=10 }) }
            review=@{ require_9p=$true; require_fresh_9b=$true } }
    }
    It 'gives 9B constraints and the used source facts but never the decision rationale, search log or objectives' {
        $material=Get-TeamReviewMaterial $script:BlindState $script:BlindPlan @{ runtime=(New-TestRuntime) } $script:BlindDirectory '9B' $script:BlindRepo $script:BlindBase $script:BlindTip
        $material.prompt | Should -Match 'Reuse facts supplied to this stage'
        $material.prompt | Should -Match ([regex]::Escape('FIXTURE_DECISION_CONSTRAINT: no new dependency.'))
        $material.prompt | Should -Match '"references_used"'
        # The blind reviewer must be able to judge the actual source, so the used reference
        # arrives with its identity, version and its own constraints.
        $material.prompt | Should -Match ([regex]::Escape('https://example.org/prior-art'))
        $material.prompt | Should -Match ([regex]::Escape('0123456789abcdef0123456789abcdef01234567'))
        $material.prompt | Should -Match ([regex]::Escape('Do not copy external code.'))
        $material.reuse_facts.usage[0].sources[0].id | Should -Be 'prior-art'
        # The blind projection is narrowed to source identity/version/constraints: the
        # per-candidate decision and borrow statement stay out with the plan strategy.
        @($material.reuse_facts.usage[0].sources[0].Keys | Sort-Object) | Should -Be @('constraints', 'id', 'revision', 'url')
        # Everything that could carry the selection decision stays out, including a candidate
        # that no task actually used.
        $material.prompt | Should -Not -Match 'example\.org/unused-source'
        $material.prompt | Should -Not -Match 'FIXTURE_UNUSED_CONSTRAINT'
        $material.prompt | Should -Not -Match 'FIXTURE_UNUSED_RATIONALE'
        $material.prompt | Should -Not -Match 'FIXTURE_CANDIDATE_RATIONALE'
        $material.prompt | Should -Not -Match 'FIXTURE_TASK_REASON'
        $material.prompt | Should -Not -Match 'FIXTURE_SEARCH_QUERY'
        $material.prompt | Should -Not -Match 'FIXTURE_DECISION_REASON'
        $material.prompt | Should -Not -Match 'FIXTURE_DECISION_RATIONALE'
        # The author's objective prose is an implementation-strategy channel, and the author
        # declared issue map would bring it straight back, so neither reaches the blind stage.
        $material.prompt | Should -Not -Match 'OBJECTIVE_STRATEGY_MUST_NOT_LEAK'
        @($material.issue_map[0].mapping.issues).Count | Should -Be 0
        @($material.issue_map[0].mapping.mapping).Count | Should -Be 0
        @($material.issue_map[0].mapping.unmapped_acceptance).Count | Should -Be 1
        $material.review_plan.Contains('reuse') | Should -BeFalse
        @($material.review_plan.tasks | Where-Object { $_['reuse'] }).Count | Should -Be 0
        @($material.review_plan.tasks | Where-Object { $_['objective'] }).Count | Should -Be 0
        $material.reuse_facts.constraints | Should -Contain 'FIXTURE_DECISION_CONSTRAINT: no new dependency.'
        $material.reuse_facts.usage[0].usage.references_used | Should -Be @('prior-art')
    }
    It 'tells 9P that the plan itself carries the reuse decision instead of denying it' {
        $material=Get-TeamReviewMaterial $script:BlindState $script:BlindPlan @{ runtime=(New-TestRuntime) } $script:BlindDirectory '9P' $script:BlindRepo $script:BlindBase $script:BlindBase
        $material.reuse_facts | Should -BeNullOrEmpty
        $material.prompt | Should -Not -Match 'No reuse decision applies to this stage'
        $material.prompt | Should -Match 'the plan below carries the plan-level reuse decision'
        # Plan review is not blind: it reads the decision and the search log in place.
        $material.prompt | Should -Match 'FIXTURE_SEARCH_QUERY'
    }
    It 'gives 9A the bounded decision, the task reason and the referenced source facts' {
        $material=Get-TeamReviewMaterial $script:BlindState $script:BlindPlan @{ runtime=(New-TestRuntime) } $script:BlindDirectory '9A' $script:BlindRepo $script:BlindBase $script:BlindTip 'T1'
        $material.reuse_facts.available | Should -BeTrue
        $material.reuse_facts.decision.status | Should -Be 'completed'
        $material.reuse_facts.decision.strategy | Should -Be 'reference'
        $material.reuse_facts.decision.constraints | Should -Contain 'FIXTURE_DECISION_CONSTRAINT: no new dependency.'
        $material.reuse_facts.task.refs | Should -Be @('prior-art')
        $material.reuse_facts.task.reason | Should -Match 'FIXTURE_TASK_REASON'
        $material.reuse_facts.candidates[0].url | Should -Be 'https://example.org/prior-art'
        $material.reuse_facts.candidates[0].revision | Should -Be '0123456789abcdef0123456789abcdef01234567'
        $material.reuse_facts.candidates[0].borrow | Should -Be 'The single source idea.'
        $material.reuse_facts.candidates[0].constraints | Should -Contain 'Do not copy external code.'
        @($material.reuse_facts.candidates).Count | Should -Be 1 -Because 'only the candidates this task references belong to it'
        ($material.reuse_facts | ConvertTo-Json -Depth 20) | Should -Not -Match 'example\.org/unused-source'
        $material.reuse_facts.usage.references_used | Should -Be @('prior-art')
        $material.prompt | Should -Not -Match 'FIXTURE_CANDIDATE_RATIONALE'
        $material.prompt | Should -Not -Match 'example\.org/unused-source'
        $material.prompt | Should -Not -Match 'FIXTURE_SEARCH_QUERY'
        $material.prompt | Should -Not -Match 'FIXTURE_DECISION_RATIONALE'
    }
    It 'keeps deviation free text out of the blind facts' {
        $receiptDir=Join-Path $TestDrive ('blind-receipt-' + [guid]::NewGuid().ToString('N'))
        [IO.Directory]::CreateDirectory($receiptDir) | Out-Null
        Write-TeamData (Join-Path $receiptDir 'result.yaml') @{ reuse=@{ references_used=@()
            deviations=@(@{ reference='prior-art'; reason='DEVIATION_REASON_MUST_NOT_LEAK: the plan chose a bespoke shape.' }) } }
        $facts=Get-TeamReuseBlindFacts $script:BlindPlan @{ tasks=@{ T1=@{ directory=$receiptDir } } }
        $json=$facts | ConvertTo-Json -Depth 30
        # The deviation reason is free worker prose and must not become a rationale channel,
        # while the fact that a prescribed reference was skipped stays visible.
        $json.Contains('DEVIATION_REASON_MUST_NOT_LEAK') | Should -BeFalse
        @($facts.usage[0].usage.deviations) | Should -Be @('prior-art')
        @($facts.usage[0].sources).Count | Should -Be 0 -Because 'a reference declared as not used contributes no source facts'
        @($facts.constraints) | Should -Contain 'FIXTURE_DECISION_CONSTRAINT: no new dependency.'
    }
    It 'projects an unexecuted optional task with no Result through the real 9B material' {
        # 9A counterexample: an optional task that never ran owns no Result, so its usage is
        # undeclared. The real 9B material must still be produced, without inventing usage and
        # without indexing a null deviation entry.
        $plan=$script:BlindPlan | ConvertTo-Json -Depth 40 | ConvertFrom-Json -AsHashtable
        $optional=New-ReuseTask 'T2' 'b.txt'
        $optional['optional']=$true
        $plan.tasks=@($plan.tasks)+@($optional)
        $state=$script:BlindState | ConvertTo-Json -Depth 40 | ConvertFrom-Json -AsHashtable
        $state.order=@('T1','T2'); $state.tasks['T2']=@{status='READY';attempts=0;directory=''}
        $material=Get-TeamReviewMaterial $state $plan @{ runtime=(New-TestRuntime) } $script:BlindDirectory '9B' $script:BlindRepo $script:BlindBase $script:BlindTip
        @($material.reuse_facts.usage).Count | Should -Be 2
        $entry=@($material.reuse_facts.usage | Where-Object { $_.task_id -eq 'T2' })
        $entry.Count | Should -Be 1
        $entry[0].usage.declared | Should -BeFalse
        @($entry[0].usage.references_used).Count | Should -Be 0
        @($entry[0].usage.deviations).Count | Should -Be 0
        @($entry[0].sources).Count | Should -Be 0 -Because 'an unexecuted task declares no used source'
        # The unexecuted task still reaches the blind reviewer as plan scope, and its entry
        # opens no channel for the decision rationale, search log or task reason.
        $material.prompt | Should -Match '"task_id":\s*"T2"'
        $material.prompt | Should -Not -Match 'FIXTURE_SEARCH_QUERY'
        $material.prompt | Should -Not -Match 'FIXTURE_DECISION_REASON'
        $material.prompt | Should -Not -Match 'FIXTURE_DECISION_RATIONALE'
        $material.prompt | Should -Not -Match 'FIXTURE_TASK_REASON'
    }
}

Describe 'Legacy runs stay readable and are not executable' {
    It 'keeps historical reads, stop and cleanup available while every mutating path demands a new run' {
        $fixture=New-ReuseFixture (New-SkippedDecision) @((New-ReuseTask))
        $result=Invoke-ReuseCli @('run','-Repo',$fixture.repo,'-Plan',$fixture.path,'-Json')
        $result.code | Should -Be 0 -Because $result.raw
        # Simulate a run written before the protocol existed: no run marker, no frozen protocol
        # evidence, and a plan that never carried reuse at either level. The frozen hash is
        # rebound to the rewritten plan so the fixture stays internally consistent - otherwise
        # the later mutations would be refused by the "plan changed outside revision protocol"
        # guard instead of by the reuse gate under test.
        $planPath=Join-Path $fixture.directory 'plan.yaml'
        $legacyPlan=Read-TeamData $planPath
        $legacyPlan.Remove('reuse')
        foreach ($task in @($legacyPlan.tasks)) { $task.Remove('reuse') }
        Write-TeamData $planPath $legacyPlan
        $state=Get-ReuseState $fixture
        $state.Remove('reuse_protocol')
        $state.plan_hash=Get-TeamHash $planPath
        Save-ReuseState $fixture $state
        Remove-Item -LiteralPath (Join-Path $fixture.directory 'reuse-protocol') -Recurse -Force
        Test-Path (Join-Path $fixture.directory 'reuse-protocol') | Should -BeFalse
        $statePath=Join-Path $fixture.directory 'state.json'
        $before=Get-TeamHash $statePath
        $beforePlan=Get-TeamHash $planPath
        $result=Invoke-ReuseCli @('status','-Repo',$fixture.repo,'-Run',$fixture.run_id,'-Json'); $result.code | Should -Be 0 -Because $result.raw
        $result.data.tasks.T1.status | Should -Be 'REVIEW'
        $result.data.summary.reuse.status | Should -Be 'unavailable'
        $result.data.summary.reuse.reason | Should -Match 'no frozen reuse protocol marker'
        $result=Invoke-ReuseCli @('logs','-Repo',$fixture.repo,'-Run',$fixture.run_id,'-Json'); $result.code | Should -Be 0 -Because $result.raw
        $result=Invoke-ReuseCli @('cost','-Repo',$fixture.repo,'-Run',$fixture.run_id,'-Json'); $result.code | Should -Be 0 -Because $result.raw
        $result.data.summary.reuse.status | Should -Be 'unavailable'
        $result=Invoke-ReuseCli @('result','-Repo',$fixture.repo,'-Run',$fixture.run_id,'-Task','T1','-Json'); $result.code | Should -Be 0 -Because $result.raw
        $result=Invoke-ReuseCli @('escalations','-Repo',$fixture.repo,'-Run',$fixture.run_id,'-Json'); $result.code | Should -Be 0 -Because $result.raw
        Get-TeamHash $statePath | Should -Be $before -Because 'historical reads never rewrite run state'
        Get-TeamHash $planPath | Should -Be $beforePlan -Because 'historical reads never rewrite the frozen plan'
        (Read-TeamData $planPath).Contains('reuse') | Should -BeFalse -Because 'the fixture is a genuine legacy plan'
        (Read-TeamData $planPath).tasks[0].Contains('reuse') | Should -BeFalse
        $commit=(Get-ReuseState $fixture).tasks.T1.commit
        $mutations=@(
            @{ name='resume'; args=@() },
            @{ name='accept'; args=@('-Task','T1','-Commit',$commit,'-Reason','legacy acceptance') },
            @{ name='integrate'; args=@() },
            @{ name='replan'; args=@('-Task','T1','-Plan',$fixture.path,'-Reason','legacy replan') },
            @{ name='repair-integration'; args=@('-Task','T1','-Reason','legacy repair') },
            @{ name='recover'; args=@('-Task','T1','-Reason','legacy recovery') })
        foreach ($mutation in $mutations) {
            $result=Invoke-ReuseCli (@($mutation.name,'-Repo',$fixture.repo,'-Run',$fixture.run_id) + @($mutation.args) + @('-Json'))
            $result.code | Should -Be 80 -Because "$($mutation.name) : $($result.raw)"
            $result.data.error | Should -Match 'new plan and a new run'
        }
        (Get-ReuseState $fixture).tasks.T1.status | Should -Be 'REVIEW'
        Get-TeamHash $planPath | Should -Be $beforePlan -Because 'refused mutating commands never rewrite the legacy plan'
        $result=Invoke-ReuseCli @('cleanup','-Repo',$fixture.repo,'-Run',$fixture.run_id,'-Json'); $result.code | Should -Be 0 -Because $result.raw
        $result=Invoke-ReuseCli @('stop','-Repo',$fixture.repo,'-Run',$fixture.run_id,'-Json'); $result.code | Should -Be 0 -Because $result.raw
        (Get-ReuseState $fixture).status | Should -Be 'CANCELLED'
    }
}

Describe 'Replan reuse binding' {
    It 'treats a changed task declaration as affected even when its file scope is unchanged' {
        $fixture=New-ReuseFixture (New-SkippedDecision) @((New-ReuseTask 'T1' 'files/T1.txt'),(New-ReuseTask 'T2' 'files/T2.txt')) 'REUSE' 'L2'
        $result=Invoke-ReuseCli @('run','-Repo',$fixture.repo,'-Plan',$fixture.path,'-Json'); $result.code | Should -Be 0 -Because $result.raw
        $before=Get-ReuseState $fixture
        $before.tasks.T2.attempts | Should -Be 1
        $revised=$fixture.plan | ConvertTo-Json -Depth 40 | ConvertFrom-Json -AsHashtable
        $revised.run.revision=2
        $revised.tasks[1].reuse=@{ applicability='skipped'; reason='Reclassified as a pure data change.'
            change_kinds=@('data_only'); refs=@(); skip_reason='data_only' }
        $revisedPath=Join-Path $TestDrive 'reuse-revision.json'; Write-TeamData $revisedPath $revised
        $result=Invoke-ReuseCli @('replan','-Repo',$fixture.repo,'-Run',$fixture.run_id,'-Task','T1','-Plan',$revisedPath,'-Reason','The reuse declaration of T2 changed','-Json')
        $result.code | Should -Be 0 -Because $result.raw
        # The replan response contract is unchanged: a completed replan reports PAUSED.
        $result.data.status | Should -Be 'PAUSED'
        $result.data.affected | Should -Contain 'T2'
        $state=Get-ReuseState $fixture
        $state.tasks.T2.status | Should -Be 'READY'
        $state.discarded_tasks.ContainsKey('T2-a1-r1') | Should -BeTrue
        $state.tasks.T1.status | Should -Be 'READY'
    }
    It 'invalidates a dependent acceptance when only an unrelated task reuse declaration changed' {
        # 9A counterexample: T1 is independent and T3 depends on T2. Replanning T1 while
        # amending only T2.reuse must still invalidate T3, which was accepted on the old
        # declaration; unioning the raw reuse seeds alone left T3 untouched.
        $tasks=@((New-ReuseTask 'T1' 'files/T1.txt'),(New-ReuseTask 'T2' 'files/T2.txt'),(New-ReuseTask 'T3' 'files/T3.txt'))
        $tasks[2].dependencies=@('T2')
        $fixture=New-ReuseFixture (New-SkippedDecision) $tasks 'REUSE' 'L2'
        $state=@{run_id='REUSE';revision=1;replans=0;plan_hash=('a'*64);order=@('T1','T2','T3');tasks=@{}}
        foreach($id in @('T1','T2','T3')){$state.tasks[$id]=@{status='ACCEPTED';attempts=1;worktree=(Join-Path $TestDrive $id);worktree_removed=$false;commit=('b'*40)}}
        Mock Assert-TeamCleanupSettled {}
        Mock Assert-TeamReuseRunProtocol {}
        Mock Get-TeamPendingIntegration { @() }
        Mock Assert-TeamReviewRound {}
        Mock Invoke-TeamGit { 'b'*40 }
        Mock Get-TeamAgentAdmission { @{admitted=$true} }
        Mock Save-TeamPlanRevision { param($State) $script:ObservedRevisionState=$State }
        Mock Get-TeamReuseOwnerException { @() }
        Mock Add-TeamEvent {}
        $revised=$fixture.plan | ConvertTo-Json -Depth 60 | ConvertFrom-Json -AsHashtable
        $revised.run.revision=2; $revised.tasks[1].reuse.reason='Changed T2 reuse decision reason'
        $outcome=Invoke-TeamReplan $state $fixture.plan $revised $script:ManifestData $fixture.directory 'T1' 'Replan T1 and amend T2 reuse'
        # The replan response contract is unchanged: a completed replan reports PAUSED.
        $outcome.status | Should -Be 'PAUSED'
        $outcome.revision | Should -Be 2
        $outcome.affected | Should -Contain 'T2'
        $outcome.affected | Should -Contain 'T3'
        $script:ObservedRevisionState.tasks.T2.status | Should -Be 'READY'
        $script:ObservedRevisionState.tasks.T3.status | Should -Be 'READY'
        # The invalidated attempt is retired as evidence instead of being silently rebaselined.
        $script:ObservedRevisionState.discarded_tasks['T3-a1-r1'].discard_commit | Should -Be ('b'*40)
        $script:ObservedRevisionState.discarded_tasks['T3-a1-r1'].retired_from | Should -Be 'ACCEPTED'
        # An already-integrated dependent still demands a checkpoint rollback before replanning.
        $state.tasks.T3.status='MERGED'
        Assert-TeamCode { Invoke-TeamReplan $state $fixture.plan $revised $script:ManifestData $fixture.directory 'T1' 'Replan T1 and amend T2 reuse' } 80
    }
    It 'admits a task introduced by the revision without a frozen closure root' {
        # A plan-level decision change invalidates every task, including one this revision
        # introduces: it has no frozen entry to close over and no attempt history to retire.
        $fixture=New-ReuseFixture (New-SkippedDecision) @((New-ReuseTask 'T1' 'files/T1.txt')) 'REUSE' 'L2'
        $state=@{run_id='REUSE';revision=1;replans=0;plan_hash=('a'*64);order=@('T1')
            tasks=@{T1=@{status='ACCEPTED';attempts=1;worktree=(Join-Path $TestDrive 'T1');worktree_removed=$false;commit=('b'*40)}}}
        Mock Assert-TeamCleanupSettled {}
        Mock Assert-TeamReuseRunProtocol {}
        Mock Get-TeamPendingIntegration { @() }
        Mock Assert-TeamReviewRound {}
        Mock Invoke-TeamGit { 'b'*40 }
        Mock Get-TeamAgentAdmission { @{admitted=$true} }
        Mock Save-TeamPlanRevision { param($State) $script:ObservedRevisionState=$State }
        Mock Get-TeamReuseOwnerException { @() }
        Mock Add-TeamEvent {}
        $revised=$fixture.plan | ConvertTo-Json -Depth 60 | ConvertFrom-Json -AsHashtable
        $revised.run.revision=2; $revised.reuse=New-CompletedDecision
        $revised.tasks=@($revised.tasks)+@((New-ReuseTask 'T2' 'files/T2.txt' @('prior-art') -Required))
        $outcome=Invoke-TeamReplan $state $fixture.plan $revised $script:ManifestData $fixture.directory 'T1' 'Move to a completed decision and add T2'
        $outcome.status | Should -Be 'PAUSED'
        $outcome.affected | Should -Contain 'T2'
        $script:ObservedRevisionState.tasks.T2.status | Should -Be 'READY'
        $script:ObservedRevisionState.tasks.T2.attempts | Should -Be 0
        $script:ObservedRevisionState.tasks.T1.status | Should -Be 'READY'
        $script:ObservedRevisionState.discarded_tasks.ContainsKey('T1-a1-r1') | Should -BeTrue
    }
    It 'invalidates an owner exception when the plan revision changes' {
        $fixture=New-ReuseFixture (New-BlockedDecision) @((New-ReuseTask -Required))
        $result=Invoke-ReuseCli @('run','-Repo',$fixture.repo,'-Plan',$fixture.path,'-Json')
        $result.code | Should -Be 70 -Because $result.raw
        $escalation=@(Get-ReuseEscalations $fixture)[0]
        $result=Invoke-ReuseCli @('resolve','-Repo',$fixture.repo,'-Run',$fixture.run_id,'-Escalation',$escalation.id,'-Decision','approve','-Reason','Owner accepts the unavailable search for the first revision','-Json')
        $result.code | Should -Be 0 -Because $result.raw
        $oldHash=(Get-ReuseState $fixture).plan_hash
        $revised=$fixture.plan | ConvertTo-Json -Depth 40 | ConvertFrom-Json -AsHashtable
        $revised.run.revision=2; $revised.tasks[0].objective=@('WRITE AGAIN')
        $revisedPath=Join-Path $TestDrive 'blocked-revision.json'; Write-TeamData $revisedPath $revised
        $result=Invoke-ReuseCli @('replan','-Repo',$fixture.repo,'-Run',$fixture.run_id,'-Task','T1','-Plan',$revisedPath,'-Reason','The blocked decision needs a new revision and a new exception','-Json')
        $result.code | Should -Be 0 -Because $result.raw
        $result.data.status | Should -Be 'PAUSED'
        $state=Get-ReuseState $fixture
        $state.plan_hash | Should -Not -Be $oldHash
        # The prior exact-plan approval must be recorded as invalidated by the revision, and the
        # event is only reachable because it is captured before the plan hash is rebound.
        $events=@(Get-Content (Join-Path $fixture.directory 'events.jsonl') | ForEach-Object { ConvertFrom-Json $_ -AsHashtable })
        $invalidated=@($events | Where-Object event -eq 'reuse_exception_invalidated')
        $invalidated.Count | Should -Be 1 -Because 'a prior owner exception must be recorded as invalidated by the new revision'
        $invalidated[0].details.previous_plan_hash | Should -Be $oldHash
        $invalidated[0].details.escalation | Should -Be $escalation.id
        @(Get-TeamReuseOwnerException $state $fixture.directory).Count | Should -Be 0 -Because 'the old approval must no longer satisfy the new plan hash'
        $pending=@(Get-ReuseEscalations $fixture | Where-Object { $_.status -eq 'pending' })
        @($pending | Where-Object { $_.plan_hash -eq $state.plan_hash }).Count | Should -Be 1
        $result=Invoke-ReuseCli @('resume','-Repo',$fixture.repo,'-Run',$fixture.run_id,'-Json')
        $result.code | Should -Be 70 -Because $result.raw
        Test-Path (Join-Path $fixture.repo '.worktrees') | Should -BeFalse
    }
}

Describe 'Integration repair reuse inheritance' {
    It 'inherits the suspect declaration and refuses a blended repair' {
        $task=New-ReuseTask 'T1' 'files/shared.txt'
        $second=New-ReuseTask 'T2' 'files/shared.txt'
        $plan=@{ tasks=@($task,$second); reuse=(New-SkippedDecision)
            verification=@{ final=@(@{ id='final'; executable='pwsh'; args=@('-NoProfile'); timeout_seconds=10 }) } }
        $state=@{ replans=0; tasks=@{ T1=@{ commit=('a'*40); status='MERGED' }; T2=@{ commit=('b'*40); status='MERGED' } } }
        $failure=@{ probes=@(); directory=$TestDrive; failed_sha=('c'*40) }
        $draft=New-TeamRegressionTask $state $plan $failure 'T1'
        $draft.sources | Should -Be @('T1','T2')
        $draft.task.reuse.applicability | Should -Be 'skipped'
        $draft.task.reuse.skip_reason | Should -Be 'established_repo_pattern'
        $plan.tasks[1]=New-ReuseTask 'T2' 'files/shared.txt'
        $plan.tasks[1].reuse=@{ applicability='skipped'; reason='Reclassified as a pure data change.'
            change_kinds=@('data_only'); refs=@(); skip_reason='data_only' }
        Assert-TeamCode { New-TeamRegressionTask $state $plan $failure 'T1' } 10
    }
    It 'refuses an integration repair on a run without the frozen protocol' {
        $plan=@{ tasks=@((New-ReuseTask 'T1' 'files/T1.txt')); reuse=(New-SkippedDecision) }
        Assert-TeamCode { New-TeamRegressionRepair @{ plan_hash=('a'*64); repo=$TestDrive } $plan $script:ManifestData $TestDrive 'T1' 'legacy repair' } 80
    }
    It 'inherits the suspect declaration through the real integration repair and demands a replan without one' {
        $fixture=New-ReuseFixture (New-CompletedDecision) @((New-ReuseTask -Required -Refs @('prior-art')))
        $result=Invoke-ReuseCli @('run','-Repo',$fixture.repo,'-Plan',$fixture.path,'-Json')
        $result.code | Should -Be 0 -Because $result.raw
        $state=Get-ReuseState $fixture
        $base=$state.run_base_sha
        # A synthetic owned integration conflict: an integrated checkpoint merged with a
        # conflicting accepted commit, built with real Git objects.
        $integrationTree=Join-Path $fixture.repo '.worktrees/synthetic-integration'
        $incomingTree=Join-Path $fixture.repo '.worktrees/synthetic-incoming'
        $null=Invoke-TeamGit $fixture.repo @('worktree','add','-q','-b','synthetic-integration',$integrationTree,$base)
        Set-Content -LiteralPath (Join-Path $integrationTree 'shared.txt') -Value 'integrated'
        $null=Invoke-TeamGit $integrationTree @('add','shared.txt')
        $null=Invoke-TeamGit $integrationTree @('commit','-qm','test: integration checkpoint')
        $null=Invoke-TeamGit $fixture.repo @('worktree','add','-q','-b','synthetic-incoming',$incomingTree,$base)
        Set-Content -LiteralPath (Join-Path $incomingTree 'shared.txt') -Value 'incoming'
        $null=Invoke-TeamGit $incomingTree @('add','shared.txt')
        $null=Invoke-TeamGit $incomingTree @('commit','-qm','test: accepted incoming')
        $accepted=Invoke-TeamGit $incomingTree @('rev-parse','HEAD')
        & git -C $integrationTree merge --no-edit synthetic-incoming 2>$null | Out-Null
        $LASTEXITCODE | Should -Not -Be 0 -Because 'the synthetic merge must really conflict'
        $integrationHead=Invoke-TeamGit $integrationTree @('rev-parse','HEAD')
        $state.tasks.T1.status='ACCEPTED'; $state.tasks.T1.commit=$accepted
        $state.tasks.T1.worktree=$incomingTree; $state.tasks.T1.base_sha=$base
        $state['integration_worktree']=$integrationTree; $state['last_good_integration_sha']=$integrationHead
        Save-ReuseState $fixture $state
        Write-TeamData (Join-Path $fixture.directory 'integration-conflict.json') @{ task_id='T1'; base_sha=$integrationHead
            conflicts=@('shared.txt'); write_scope_policy='conflict_files_plus_explicit_glue_scope'; may_change_interfaces=$false }
        $runPlan=Read-TeamData (Join-Path $fixture.directory 'plan.yaml')
        # (a) A source task without a justified declaration is refused before anything moves.
        $undeclared=$runPlan | ConvertTo-Json -Depth 40 | ConvertFrom-Json -AsHashtable
        $undeclared.tasks[0].Remove('reuse')
        Assert-TeamCode { New-TeamIntegrationRepair $state $undeclared $script:ManifestData $fixture.directory @() 'Synthetic conflict repair' 'T1' } 10
        (Read-TeamData (Join-Path $fixture.directory 'plan.yaml')).tasks.Count | Should -Be 1
        # (b) With the declaration present the repair task inherits it exactly.
        $repair=New-TeamIntegrationRepair $state $runPlan $script:ManifestData $fixture.directory @() 'Synthetic conflict repair' 'T1'
        $repair.task_id | Should -Be 'INTEGRATION-1'
        $revisedPlan=Read-TeamData (Join-Path $fixture.directory 'plan.yaml')
        $repairTask=@($revisedPlan.tasks | Where-Object { $_.id -eq 'INTEGRATION-1' })[0]
        (Get-TeamCanonicalJson $repairTask.reuse) | Should -Be (Get-TeamCanonicalJson $runPlan.tasks[0].reuse)
        $repairTask.reuse.refs | Should -Be @('prior-art')
        (Get-TeamHash (Join-Path $fixture.directory 'plan.yaml')) | Should -Be (Get-ReuseState $fixture).plan_hash
    }
}
