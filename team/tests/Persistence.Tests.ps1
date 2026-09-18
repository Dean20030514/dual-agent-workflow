BeforeAll {
    . (Join-Path $PSScriptRoot "LeadFixture.ps1")
    $script:LeadEnvironment=Enable-TeamLeadFixture $TestDrive
    $script:TeamPath=Split-Path $PSScriptRoot -Parent
    foreach ($module in @('Core','Lead','Contracts','Preflight','State','Controls','Execution','IntegrationRecovery','Checkpoints','Revisions','Rollbacks','Integration','Recovery','ReviewRounds','Review','LocalReview','Conflict')) {
        . (Join-Path $script:TeamPath "scripts/$module.ps1")
    }
    $script:OriginalPath=$env:PATH; $script:OriginalDshHome=$env:DSH_HOME
    $env:PATH=(Join-Path $PSScriptRoot 'fixtures')+[IO.Path]::PathSeparator+$env:PATH
    $env:DSH_HOME=Join-Path $TestDrive 'dsh-home'; [IO.Directory]::CreateDirectory($env:DSH_HOME) | Out-Null
    function Invoke-PersistenceCli($Fixture, [string[]]$Arguments, [int]$ExpectedExit=0) {
        $raw=& pwsh -NoProfile -File (Join-Path $script:TeamPath 'scripts/team.ps1') @Arguments -Repo $Fixture.repo -Json
        $code=$LASTEXITCODE
        if ($code -ne $ExpectedExit) { throw "CLI exit ${code}, expected ${ExpectedExit}: $raw" }
        return $raw | ConvertFrom-Json -AsHashtable
    }
    function New-PersistenceFixture([int]$Count=1, [switch]$FailIntegration) {
        $repo=Join-Path $TestDrive ([guid]::NewGuid().ToString('N')); [IO.Directory]::CreateDirectory($repo) | Out-Null
        $null=Invoke-TeamGit $repo @('init','-q','-b','main')
        $null=Invoke-TeamGit $repo @('config','user.name','Persistence Fixture')
        $null=Invoke-TeamGit $repo @('config','user.email','fixture@example.invalid')
        [IO.File]::WriteAllText((Join-Path $repo '.gitignore'),"team/runtime/`n.worktrees/`n")
        $null=Invoke-TeamGit $repo @('add','.gitignore'); $null=Invoke-TeamGit $repo @('commit','-qm','test: seed persistence fixture')
        $plan=Read-TeamData (Join-Path $script:TeamPath 'tests/plans/L1-sql.yaml'); $plan.run.id='PERSIST'; $plan.tasks[0].id='T1'
        $plan.tasks[0].objective=@('WRITE'); $plan.tasks[0].write_scope=@('files/T1.txt')
        $plan.tasks[0].verification=@(@{id='exists';executable='pwsh';args=@('-NoProfile','-Command','if (-not (Test-Path files/T1.txt)) {exit 1}');timeout_seconds=10})
        $plan.verification.final=$plan.tasks[0].verification
        if ($FailIntegration) {
            $plan.tasks[0].verification[0].args=@('-NoProfile','-Command','if ((Get-Location).Path.EndsWith("-integration")) { Write-Output "preserved failure"; exit 9 }')
        }
        if ($Count -eq 2) {
            $second=$plan.tasks[0] | ConvertTo-Json -Depth 30 | ConvertFrom-Json -AsHashtable
            $second.id='T2'; $second.write_scope=@('files/T2.txt')
            $second.verification[0].args=@('-NoProfile','-Command','if (-not (Test-Path files/T2.txt)) {exit 1}')
            $plan.tasks+=@($second); $plan.mode='L2'
        }
        $f=@{repo=$repo;plan=$plan;path=(Join-Path $repo 'team/runtime-input.json');directory=(Join-Path $repo 'team/runtime/PERSIST')}
        $f.path=Join-Path $TestDrive ([guid]::NewGuid().ToString('N')+'.json'); Write-TeamData $f.path $plan
        $null=Invoke-PersistenceCli $f @('run','-Plan',$f.path)
        $f.state=(Read-TeamRun $repo 'PERSIST').state
        $null=Invoke-PersistenceCli $f @('accept','-Run','PERSIST','-Task','T1','-Commit',$f.state.tasks.T1.commit,'-Reason','Fixture evidence accepted')
        if ($Count -eq 2) { $null=Invoke-PersistenceCli $f @('accept','-Run','PERSIST','-Task','T2','-Commit',$f.state.tasks.T2.commit,'-Reason','Unrelated fixture evidence accepted') }
        $f.state=(Read-TeamRun $repo 'PERSIST').state
        $f.manifest=Read-TeamData (Join-Path $f.directory 'manifest.yaml')
        return $f
    }
}

Describe 'Plan revision transactions' {
    It 'reconciles the <Boundary> revision boundary while preserving unrelated accepted work' -ForEach @(
        @{Boundary='prepared'},@{Boundary='archive_written'},@{Boundary='plan_written'},@{Boundary='decision_written'},@{Boundary='state_written'}
    ) {
        $f=New-PersistenceFixture 2
        $oldState=[IO.File]::ReadAllText((Join-Path $f.directory 'state.json'))
        $oldPlan=[IO.File]::ReadAllText((Join-Path $f.directory 'plan.yaml'))
        $unrelated=$f.state.tasks.T2 | ConvertTo-Json -Depth 60 -Compress
        $f.plan.run.revision=2; Write-TeamData $f.path $f.plan
        $null=Invoke-PersistenceCli $f @('replan','-Run','PERSIST','-Task','T1','-Plan',$f.path,'-Reason','Revise the affected task only')
        $journalPath=Join-Path $f.directory 'revision-pending.json'; $journal=Read-TeamData $journalPath
        $journal.phase='prepared'; Write-TeamData $journalPath $journal
        $archive=Join-Path $f.directory 'plan-revision-1.yaml'
        $decision=Join-Path $f.directory "decisions/$($journal.decision_id).json"
        if ($Boundary -eq 'prepared') { [IO.File]::Delete($archive) }
        if ($Boundary -in @('prepared','archive_written','plan_written')) { [IO.File]::Delete($decision) }
        if ($Boundary -in @('prepared','archive_written')) { Write-TeamTextAtomic (Join-Path $f.directory 'plan.yaml') $oldPlan }
        if ($Boundary -ne 'state_written') { Write-TeamTextAtomic (Join-Path $f.directory 'state.json') $oldState }
        # Cleanup acquires the real coordinator lock and replays the transaction,
        # without dispatching another author or reviewer.
        $null=Invoke-PersistenceCli $f @('cleanup','-Run','PERSIST')
        $disk=(Read-TeamRun $f.repo 'PERSIST').state
        $disk.revision | Should -Be 2; $disk.replans | Should -Be 1
        $disk.agents_created | Should -Be 4; $disk.tasks.T1.attempts | Should -Be 1
        $disk.tasks.T1.status | Should -Be 'READY'
        ($disk.tasks.T2 | ConvertTo-Json -Depth 60 -Compress) | Should -Be $unrelated
        $disk.discarded_tasks.Count | Should -Be 1
        (Get-TeamHash (Join-Path $f.directory 'plan.yaml')) | Should -Be $disk.plan_hash
        (Read-TeamData $journalPath).phase | Should -Be 'completed'
        (Read-TeamData $decision).plan_hash | Should -Be $disk.plan_hash
        [IO.File]::ReadAllText($archive) | Should -Be $oldPlan
        Assert-TeamRecovery $disk (Read-TeamData (Join-Path $f.directory 'plan.yaml')) $f.directory
        $stateHash=Get-TeamHash (Join-Path $f.directory 'state.json')
        $null=Invoke-PersistenceCli $f @('cleanup','-Run','PERSIST')
        (Read-TeamRun $f.repo 'PERSIST').state.replans | Should -Be 1
        (Invoke-TeamGit $f.repo @('rev-parse','main')) | Should -Be $disk.run_base_sha
    }

    It 'refuses a pending revision with <Damage> without overwriting its evidence' -ForEach @(
        @{Damage='changed_staging'},@{Damage='missing_staging'},@{Damage='external_state'}
    ) {
        $f=New-PersistenceFixture
        $f.plan.run.revision=2; Write-TeamData $f.path $f.plan
        $null=Invoke-PersistenceCli $f @('replan','-Run','PERSIST','-Task','T1','-Plan',$f.path,'-Reason','Create the durable revision fixture')
        $journalPath=Join-Path $f.directory 'revision-pending.json'; $journal=Read-TeamData $journalPath
        $journal.phase='prepared'; Write-TeamData $journalPath $journal
        $staging=Join-Path $f.directory "revision-transactions/$($journal.id)/decision.json"
        if ($Damage -eq 'changed_staging') { [IO.File]::AppendAllText($staging,' ') }
        if ($Damage -eq 'missing_staging') { [IO.File]::Delete($staging) }
        if ($Damage -eq 'external_state') {
            $disk=(Read-TeamRun $f.repo 'PERSIST').state; $disk['owner_note']='Preserve this external change'
            Write-TeamData (Join-Path $f.directory 'state.json') $disk
        }
        $hashes=@{}; foreach ($name in @('plan.yaml','state.json','revision-pending.json')) { $hashes[$name]=Get-TeamHash (Join-Path $f.directory $name) }
        $null=Invoke-PersistenceCli $f @('cleanup','-Run','PERSIST') 80
        foreach ($name in $hashes.Keys) { (Get-TeamHash (Join-Path $f.directory $name)) | Should -Be $hashes[$name] }
    }
}

Describe 'Rollback transaction recovery' {
    It 'preserves a completed run when resume is rejected' {
        $f=New-PersistenceFixture
        $null=Invoke-PersistenceCli $f @('integrate','-Run','PERSIST')
        $stateHash=Get-TeamHash (Join-Path $f.directory 'state.json')
        $null=Invoke-PersistenceCli $f @('resume','-Run','PERSIST') 80
        (Read-TeamRun $f.repo 'PERSIST').state.status | Should -Be 'COMPLETED'
        (Get-TeamHash (Join-Path $f.directory 'state.json')) | Should -Be $stateHash
    }

    It 'does not resume a pending rollback after the owner cancels the run' {
        $f=New-PersistenceFixture
        $null=Invoke-PersistenceCli $f @('integrate','-Run','PERSIST')
        $state=(Read-TeamRun $f.repo 'PERSIST').state; $tree=$state.integration_worktree
        $checkpoint=Read-TeamData (Join-Path $f.directory 'checkpoints/T1.json')
        $batch=@{id='UNDO-fixture';run_id='PERSIST';plan_hash=$state.plan_hash;before=$state.last_good_integration_sha;
            reason='Pending rollback before cancellation';status='prepared';affected=@('T1');entries=@(@{id='ROLLBACK-fixture';checkpoint=$checkpoint})}
        $journalPath=Join-Path $f.directory 'rollback-pending.json'; Write-TeamData $journalPath $batch
        $journalHash=Get-TeamHash $journalPath
        $null=Invoke-PersistenceCli $f @('stop','-Run','PERSIST')
        $result=Invoke-PersistenceCli $f @('resume','-Run','PERSIST') 80
        $result.error | Should -Match 'Cancelled run'
        (Invoke-TeamGit $tree @('rev-parse','HEAD')) | Should -Be $batch.before
        (Get-TeamHash $journalPath) | Should -Be $journalHash
        (Read-TeamRun $f.repo 'PERSIST').state.status | Should -Be 'CANCELLED'
        (Read-TeamRun $f.repo 'PERSIST').state.tasks.T1.status | Should -Be 'MERGED'
    }

    It 'finishes an interrupted multi-task rollback during resume without dispatching any worker' {
        $f=New-PersistenceFixture 2
        $null=Invoke-PersistenceCli $f @('integrate','-Run','PERSIST')
        $state=(Read-TeamRun $f.repo 'PERSIST').state; $tree=$state.integration_worktree
        $first=Read-TeamData (Join-Path $f.directory 'checkpoints/T1.json')
        $second=Read-TeamData (Join-Path $f.directory 'checkpoints/T2.json')
        $batch=@{id='UNDO-fixture';run_id='PERSIST';plan_hash=$state.plan_hash;before=$state.last_good_integration_sha;
            reason='Recover the already authorized batch';status='prepared';affected=@('T1','T2');entries=@(
                @{id='ROLLBACK-first';checkpoint=$second},@{id='ROLLBACK-second';checkpoint=$first})}
        Write-TeamData (Join-Path $f.directory 'rollback-pending.json') $batch
        $null=Invoke-TeamGit $tree @('revert','-m','1','--no-edit',$second.after)
        $head=Invoke-TeamGit $tree @('rev-parse','HEAD')
        $second['rollback_commit']=$head; $second['rollback_before']=$batch.before; Save-TeamCheckpoint $f.directory $second
        $state.last_good_integration_sha=$head; $state.status='PAUSED'; $state.tasks.T2.status='REWORK'; Save-TeamState $state $f.directory
        Write-TeamData (Join-Path $f.directory 'rollbacks/ROLLBACK-first.json') @{
            id='ROLLBACK-first';batch_id=$batch.id;task_id='T2';before=$batch.before;after=$head;reverted_merge=$second.after;reason=$batch.reason;status='completed'
        }
        $result=Invoke-PersistenceCli $f @('resume','-Run','PERSIST') 80
        $result.error | Should -Match 'explicit replan'
        $disk=(Read-TeamRun $f.repo 'PERSIST').state
        $disk.tasks.T1.status | Should -Be 'REWORK'; $disk.tasks.T2.status | Should -Be 'REWORK'
        $disk.agents_created | Should -Be 4
        $disk.tasks.T1.attempts | Should -Be 1; $disk.tasks.T2.attempts | Should -Be 1
        (Invoke-TeamGit $tree @('rev-list','--count',"$($batch.before)..HEAD")) | Should -Be '2'
        (Invoke-TeamGit $tree @('rev-parse','HEAD^{tree}')) | Should -Be (Invoke-TeamGit $f.repo @('rev-parse','main^{tree}'))
        (Read-TeamData (Join-Path $f.directory 'rollback-pending.json')).status | Should -Be 'completed'
    }

    It 'refuses an unrelated commit after a rollback intent without changing that commit or checkpoint' {
        $f=New-PersistenceFixture
        $null=Invoke-PersistenceCli $f @('integrate','-Run','PERSIST')
        $state=(Read-TeamRun $f.repo 'PERSIST').state; $tree=$state.integration_worktree
        $checkpointPath=Join-Path $f.directory 'checkpoints/T1.json'; $checkpoint=Read-TeamData $checkpointPath
        $batch=@{id='UNDO-fixture';run_id='PERSIST';plan_hash=$state.plan_hash;before=$state.last_good_integration_sha;
            reason='Authorized rollback';status='prepared';affected=@('T1');entries=@(@{id='ROLLBACK-fixture';checkpoint=$checkpoint})}
        Write-TeamData (Join-Path $f.directory 'rollback-pending.json') $batch
        Write-TeamData (Join-Path $f.directory 'rollbacks/ROLLBACK-fixture.json') @{
            id='ROLLBACK-fixture';batch_id=$batch.id;task_id='T1';before=$batch.before;reverted_merge=$checkpoint.after;reason=$batch.reason;status='started'
        }
        $null=Invoke-TeamGit $tree @('commit','--allow-empty','-qm','test: unrelated owner commit')
        $head=Invoke-TeamGit $tree @('rev-parse','HEAD'); $checkpointHash=Get-TeamHash $checkpointPath
        $result=Invoke-PersistenceCli $f @('rollback','-Run','PERSIST','-Task','T1','-Reason','Reconcile without overwriting owner work') 80
        $result.error | Should -Match 'not the exact revert'
        (Invoke-TeamGit $tree @('rev-parse','HEAD')) | Should -Be $head
        (Get-TeamHash $checkpointPath) | Should -Be $checkpointHash
    }

    It 'replays the <Boundary> rollback boundary exactly once on the integration branch' -ForEach @(
        @{Boundary='batch_prepared'},@{Boundary='revert_intent'},@{Boundary='revert_committed'},
        @{Boundary='receipt_written'},@{Boundary='checkpoint_written'},@{Boundary='state_written'},@{Boundary='receipt_completed'}
    ) {
        $f=New-PersistenceFixture
        $null=Invoke-PersistenceCli $f @('integrate','-Run','PERSIST')
        $state=(Read-TeamRun $f.repo 'PERSIST').state; $tree=$state.integration_worktree
        $checkpoint=Read-TeamData (Join-Path $f.directory 'checkpoints/T1.json')
        $batch=@{id='UNDO-fixture';run_id='PERSIST';plan_hash=$state.plan_hash;before=$state.last_good_integration_sha;
            reason='Recover an authorized interrupted rollback';status='prepared';affected=@('T1');entries=@(@{id='ROLLBACK-fixture';checkpoint=$checkpoint})}
        Write-TeamData (Join-Path $f.directory 'rollback-pending.json') $batch
        $record=@{id='ROLLBACK-fixture';batch_id=$batch.id;task_id='T1';before=$batch.before;reverted_merge=$checkpoint.after;reason=$batch.reason;status='started'}
        $recordPath=Join-Path $f.directory 'rollbacks/ROLLBACK-fixture.json'
        if ($Boundary -ne 'batch_prepared') { Write-TeamData $recordPath $record }
        if ($Boundary -notin @('batch_prepared','revert_intent')) {
            $null=Invoke-TeamGit $tree @('revert','-m','1','--no-edit',$checkpoint.after)
            $revert=Invoke-TeamGit $tree @('rev-parse','HEAD')
            if ($Boundary -ne 'revert_committed') { $record['after']=$revert; Write-TeamData $recordPath $record }
            if ($Boundary -in @('checkpoint_written','state_written','receipt_completed')) {
                $checkpoint['rollback_before']=$batch.before; $checkpoint['rollback_commit']=$revert
                Save-TeamCheckpoint $f.directory $checkpoint
            }
            if ($Boundary -in @('state_written','receipt_completed')) {
                $state.last_good_integration_sha=$revert; $state.status='PAUSED'; $state.tasks.T1.status='REWORK'
                Save-TeamState $state $f.directory
            }
            if ($Boundary -eq 'receipt_completed') { $record.status='completed'; Write-TeamData $recordPath $record }
        }
        $result=Invoke-PersistenceCli $f @('rollback','-Run','PERSIST','-Task','T1','-Reason','Continue the authorized rollback')
        $result.rolled_back | Should -Be @('T1')
        $disk=(Read-TeamRun $f.repo 'PERSIST').state
        $disk.tasks.T1.status | Should -Be 'REWORK'; $disk.tasks.T1.attempts | Should -Be 1
        $disk.agents_created | Should -Be 2; $disk.agents_reserved | Should -Be 0
        $head=Invoke-TeamGit $tree @('rev-parse','HEAD')
        $head | Should -Be $disk.last_good_integration_sha
        (Invoke-TeamGit $tree @('rev-list','--count',"$($batch.before)..HEAD")) | Should -Be '1'
        (Invoke-TeamGit $tree @('rev-parse','HEAD^{tree}')) | Should -Be (Invoke-TeamGit $f.repo @('rev-parse','main^{tree}'))
        (Invoke-TeamGit $f.repo @('rev-parse','main')) | Should -Be $disk.run_base_sha
        (Read-TeamData (Join-Path $f.directory 'rollback-pending.json')).status | Should -Be 'completed'
        (Read-TeamData $recordPath).status | Should -Be 'completed'
        $null=Invoke-PersistenceCli $f @('rollback','-Run','PERSIST','-Task','T1','-Reason','Do not repeat a completed rollback') 80
        (Invoke-TeamGit $tree @('rev-parse','HEAD')) | Should -Be $head
    }
}

Describe 'Pending integration evidence and identity' {
    It 'refuses a recovered checkpoint with <Damage> and preserves the existing integration' -ForEach @(
        @{Damage='wrong_plan'},@{Damage='changed_stdout'},@{Damage='missing_stdout'}
    ) {
        $f=New-PersistenceFixture
        $null=Invoke-PersistenceCli $f @('integrate','-Run','PERSIST')
        $disk=(Read-TeamRun $f.repo 'PERSIST').state; $head=$disk.last_good_integration_sha
        $disk.status='PAUSED'; Save-TeamState $disk $f.directory
        $checkpoint=Read-TeamData (Join-Path $f.directory 'checkpoints/T1.json')
        $op=Read-TeamData (Join-Path $f.directory "integration-operations/$($checkpoint.operation_id).json")
        $op.phase='merged'
        if ($Damage -eq 'wrong_plan') { $op.plan_hash='f'*64 }
        Save-TeamIntegrationOperation $f.directory $op
        $stdout=Join-Path $checkpoint.evidence_directory 'verification-exists.stdout'
        if ($Damage -eq 'changed_stdout') { [IO.File]::AppendAllText($stdout,'Changed evidence') }
        if ($Damage -eq 'missing_stdout') { [IO.File]::Delete($stdout) }
        $checkpointHash=Get-TeamHash (Join-Path $f.directory 'checkpoints/T1.json')
        $null=Invoke-PersistenceCli $f @('resume','-Run','PERSIST') 80
        (Invoke-TeamGit $disk.integration_worktree @('rev-parse','HEAD')) | Should -Be $head
        (Get-TeamHash (Join-Path $f.directory 'checkpoints/T1.json')) | Should -Be $checkpointHash
        (Read-TeamRun $f.repo 'PERSIST').state.tasks.T1.attempts | Should -Be 1
    }

    It 'preserves a known failed integration verification without rerunning it on recovery' {
        $f=New-PersistenceFixture -FailIntegration
        $null=Invoke-PersistenceCli $f @('integrate','-Run','PERSIST') 40
        $op=@(Get-TeamPendingIntegration $f.directory)[0]
        $evidence=Join-Path $op.verification_directory 'verification-evidence.json'; $hash=Get-TeamHash $evidence
        $op.phase='merged'; Save-TeamIntegrationOperation $f.directory $op
        $null=Invoke-PersistenceCli $f @('resume','-Run','PERSIST') 40
        (Get-TeamHash $evidence) | Should -Be $hash
        @(Get-ChildItem (Split-Path $op.verification_directory -Parent) -Directory).Count | Should -Be 1
        @(Get-TeamPendingIntegration $f.directory)[0].phase | Should -Be 'verification_failed'
        (Read-TeamRun $f.repo 'PERSIST').state.tasks.T1.attempts | Should -Be 1
    }
}
AfterAll { Restore-TeamLeadFixture $script:LeadEnvironment; $env:PATH=$script:OriginalPath; $env:DSH_HOME=$script:OriginalDshHome }

Describe 'Integration persistence boundaries on real isolated Git' {
    It 'resumes after the <Boundary> write boundary without merging twice or rerunning the author' -ForEach @(
        @{Boundary='creation_intent'},@{Boundary='tree_created'},@{Boundary='merge_intent'},
        @{Boundary='merge_committed'},@{Boundary='checkpoint_unverified'},@{Boundary='checkpoint_verified'},@{Boundary='state_merged'}
    ) {
        $f=New-PersistenceFixture
        # Construct the durable facts at each interrupted boundary in this fixture.
        # No runtime function interception or hidden process manipulation is needed.
        if ($Boundary -eq 'creation_intent') {
            $f.state.integration_worktree=Get-TeamChild $f.repo '.worktrees/PERSIST-integration'
            $f.state['integration_creation_pending']=$true; Save-TeamState $f.state $f.directory
        } else {
            Initialize-TeamIntegrationTree $f.state $f.directory
            if ($Boundary -eq 'tree_created') {
                $f.state.integration_creation_pending=$true; Save-TeamState $f.state $f.directory
            } else {
                $op=@{id='MERGE-fixture';run_id='PERSIST';plan_hash=$f.state.plan_hash;task_id='T1';attempt=1;
                    worker_commit=$f.state.tasks.T1.commit;before=$f.state.last_good_integration_sha;phase='prepared'}
                Save-TeamIntegrationOperation $f.directory $op
                if ($Boundary -ne 'merge_intent') {
                    $null=Invoke-TeamGit $f.state.integration_worktree @('merge','--no-ff','-m','Team integration MERGE-fixture',$op.worker_commit)
                    if ($Boundary -ne 'merge_committed') {
                        $head=Invoke-TeamGit $f.state.integration_worktree @('rev-parse','HEAD')
                        $op.phase='merged'; $op['after']=$head; Save-TeamIntegrationOperation $f.directory $op
                        $unverified=@{task_id='T1';attempt=1;before=$op.before;after=$head;worker_commit=$op.worker_commit;
                            verified=$false;noop=$false;operation_id=$op.id}
                        Save-TeamCheckpoint $f.directory $unverified
                        if ($Boundary -in @('checkpoint_verified','state_merged')) {
                            $before=[IO.File]::ReadAllText((Join-Path $f.directory 'state.json'))
                            Complete-TeamIntegrationCheckpoint $f.state $f.plan $f.manifest $f.directory $op
                            $op.phase='merged'; Save-TeamIntegrationOperation $f.directory $op
                            if ($Boundary -eq 'checkpoint_verified') {
                                Write-TeamTextAtomic (Join-Path $f.directory 'state.json') $before
                                Write-TeamData (Join-Path $f.directory "checkpoints/history/T1-a1-$head.json") $unverified
                            }
                        }
                    }
                }
            }
        }
        $disk=(Read-TeamRun $f.repo 'PERSIST').state
        $worker=$disk.tasks.T1.commit
        $null=Invoke-PersistenceCli $f @('resume','-Run','PERSIST')
        $result=Invoke-PersistenceCli $f @('integrate','-Run','PERSIST')
        $result.status | Should -Be 'COMPLETED'
        $disk=(Read-TeamRun $f.repo 'PERSIST').state
        $disk.tasks.T1.attempts | Should -Be 1; $disk.tasks.T1.commit | Should -Be $worker
        $disk.agents_created | Should -Be 2; $disk.agents_reserved | Should -Be 0
        (Invoke-TeamGit $disk.integration_worktree @('rev-list','--count','--merges',"$($disk.run_base_sha)..HEAD")) | Should -Be '1'
        (Invoke-TeamGit $f.repo @('rev-parse','main')) | Should -Be $disk.run_base_sha
        $checkpoint=Read-TeamData (Join-Path $f.directory 'checkpoints/T1.json'); $checkpoint.verified | Should -BeTrue
        @(Get-TeamPendingIntegration $f.directory).Count | Should -Be 0
        $history=@(Get-ChildItem (Join-Path $f.directory 'checkpoints/history') -Filter '*.json')
        $history.Count | Should -Be 1
        (Get-TeamHash $history[0].FullName) | Should -Be (Get-TeamHash (Join-Path $f.directory 'checkpoints/T1.json'))
    }
}
