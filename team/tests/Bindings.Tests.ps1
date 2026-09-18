BeforeAll {
    $script:TeamPath=Split-Path $PSScriptRoot -Parent
    foreach ($name in @('Core','Lead','Contracts','Preflight','State','Controls')) { . (Join-Path $script:TeamPath "scripts/$name.ps1") }
    . (Join-Path $PSScriptRoot 'LeadFixture.ps1')
    $script:SavedLead=Enable-TeamLeadFixture $TestDrive
    $script:ManifestData=Read-TeamData (Join-Path $script:TeamPath 'manifest.yaml')
    function Expect-Code($Action,[int]$Code) {
        $caught=$null
        try { & $Action | Out-Null } catch { $caught=$_ }
        $caught | Should -Not -BeNullOrEmpty
        $caught.Exception.Data['TeamExitCode'] | Should -Be $Code
    }
}
AfterAll { Restore-TeamLeadFixture $script:SavedLead }

Describe 'Active Lead model evidence' {
    BeforeEach {
        $null=Enable-TeamLeadFixture (Join-Path $TestDrive ([guid]::NewGuid().ToString('N')))
        $log=(Get-ChildItem (Join-Path $env:CODEX_HOME 'sessions') -Recurse -File)[0].FullName
    }
    It 'verifies active metadata, including its model and turn identity' {
        $proof=Assert-TeamLead $script:ManifestData
        $proof.runtime_verified | Should -BeTrue
        $proof.model | Should -Be 'gpt-6-astra'
        $proof.harness_version | Should -Be 'synthetic-fixture'
        $proof.metadata_sha256 | Should -Match '^[a-f0-9]{64}$'
    }
    It 'does not treat manifest configuration as runtime proof' {
        $env:CODEX_THREAD_ID=''
        Expect-Code { Assert-TeamLead $script:ManifestData } 20
    }
    It 'rejects <Kind> instead of falling back to an older valid turn' -ForEach @(
        @{Kind='model switch';Rows=@(@{type='turn_context';payload=@{turn_id='new';model='other'}},@{type='event_msg';payload=@{type='task_started';turn_id='new'}})},
        @{Kind='completed turn';Rows=@(@{type='event_msg';payload=@{type='task_complete';turn_id='fixture-turn'}})},
        @{Kind='unmatched turn';Rows=@(@{type='event_msg';payload=@{type='task_started';turn_id='other'}})},
        @{Kind='wrong provider';Rows=@(@{type='session_meta';payload=@{id='wrong';source='exec';model_provider='other'}})}
    ) {
        foreach ($row in $Rows) { Add-Content $log (ConvertTo-Json $row -Depth 8 -Compress) }
        Expect-Code { Assert-TeamLead $script:ManifestData } 20
    }
    It 'rejects an incomplete newer metadata record' {
        Add-Content $log '{"type":"turn_context","payload":'
        Expect-Code { Assert-TeamLead $script:ManifestData } 20
    }
    It 'constructs an explicit model launch without claiming runtime verification' {
        $raw=& pwsh -NoProfile -File (Join-Path $script:TeamPath 'scripts/team-lead.ps1') -Repo (Split-Path $script:TeamPath -Parent) -DryRun
        $LASTEXITCODE | Should -Be 0
        $launch=$raw | ConvertFrom-Json
        $launch.arguments | Should -Contain 'gpt-6-astra'
        $launch.runtime_verified | Should -BeFalse
    }
}

Describe 'Run-local role contracts' {
    BeforeEach {
        $plan=Read-TeamData (Join-Path $script:TeamPath 'tests/plans/L1-sql.yaml')
        $role=Get-TeamRole 'database'; $role.role_id='query-specialist'
        $plan['dynamic_roles']=@{'query-specialist'=$role}; $plan.tasks[0].role='query-specialist'
        $manifestCopy=Read-TeamData (Join-Path $script:TeamPath 'manifest.yaml')
    }
    It 'validates a complete custom definition and binds it to a task' {
        @(Test-TeamPlan $plan $manifestCopy) | Should -Be @('SQL-001')
        (Get-TeamRole 'query-specialist' -Plan $plan).role_id | Should -Be 'query-specialist'
    }
    It 'honors the dynamic role switch' {
        $manifestCopy.team.dynamic_roles=$false
        Expect-Code { Test-TeamPlan $plan $manifestCopy } 10
    }
    It 'rejects builtin shadowing and incomplete custom contracts' {
        $role.role_id='database'; $plan.dynamic_roles=@{database=$role}; $plan.tasks[0].role='database'
        Expect-Code { Test-TeamPlan $plan $manifestCopy } 10
        $plan.dynamic_roles=@{'query-specialist'=@{role_id='query-specialist'}}; $plan.tasks[0].role='query-specialist'
        Expect-Code { Test-TeamPlan $plan $manifestCopy } 10
    }
    It 'detects changes to a frozen role while ignoring dictionary key order' {
        $dir=Join-Path $TestDrive 'frozen-role'
        Write-TeamData (Join-Path $dir 'roles/query-specialist.yaml') $role
        (Get-TeamRole 'query-specialist' $dir $plan).role_id | Should -Be 'query-specialist'
        $role.guidance+=@('Changed definition')
        Expect-Code { Get-TeamRole 'query-specialist' $dir $plan } 80
    }
}

Describe 'Separate explicit currency ledgers' {
    BeforeEach {
        $dir=Join-Path $TestDrive ([guid]::NewGuid().ToString('N')); [IO.Directory]::CreateDirectory($dir) | Out-Null
        $state=@{status='READY';cost_ledgers=@{astra=@{unit='credits';known_cost=0.0};deepseek=@{unit='USD';known_cost=0.0}}}
        Mock Save-TeamState {}
        Mock Add-TeamEvent {}
        $a=Join-Path $dir 'astra.txt'; Set-Content $a 'Astra receipt'
        $d=Join-Path $dir 'deepseek.txt'; Set-Content $d 'DeepSeek receipt'
    }
    It 'keeps 9 credits and 9 USD below either soft limit' {
        $null=Submit-TeamCost $dir 9 $a astra credits $script:ManifestData 'synthetic-astra'
        $null=Submit-TeamCost $dir 9 $d deepseek USD $script:ManifestData 'synthetic-deepseek'
        Sync-TeamCost $state $script:ManifestData $dir
        $budget=Get-TeamBudgetSnapshot $state $script:ManifestData
        $budget.soft_reached | Should -BeFalse
        $budget.ledgers.astra.known_cost | Should -Be 9
        $budget.ledgers.deepseek.known_cost | Should -Be 9
        (Read-TeamData (Join-Path $dir 'budget-control.json')).stop_new_children | Should -BeFalse
        Expect-Code { Submit-TeamCost $dir 9 $a astra credits $script:ManifestData 'duplicate' } 10
    }
    It 'rejects wrong units before writing any receipt' {
        Expect-Code { Submit-TeamCost $dir 1 $a astra USD $script:ManifestData 'wrong-unit' } 10
        Expect-Code { Submit-TeamCost $dir 1 $a ASTRA credits $script:ManifestData 'wrong-ledger-case' } 10
        Test-Path (Join-Path $dir 'cost-receipts') | Should -BeFalse
    }
    It 'pauses on the hard limit of either ledger' -ForEach @(@{Ledger='astra';Unit='credits'},@{Ledger='deepseek';Unit='USD'}) {
        $null=Submit-TeamCost $dir 20 $a $Ledger $Unit $script:ManifestData 'synthetic-limit'
        Sync-TeamCost $state $script:ManifestData $dir
        $state.status | Should -Be 'PAUSED'
        (Get-TeamBudgetSnapshot $state $script:ManifestData).hard_reached | Should -BeTrue
    }
    It 'preserves and refuses untyped historical receipts' {
        $hash=Get-TeamHash $a; $receipt=Join-Path $dir "cost-receipts/$hash.json"
        Write-TeamData $receipt @{amount=5;evidence_hash=$hash}
        $before=Get-TeamHash $receipt
        Expect-Code { Sync-TeamCost $state $script:ManifestData $dir } 80
        Get-TeamHash $receipt | Should -Be $before
        $state.cost_ledgers.astra.known_cost | Should -Be 0
        $state['known_cost']=5
        Expect-Code { Get-TeamBudgetSnapshot $state $script:ManifestData } 80
    }
    It 'rejects loss of receipts previously recorded in the state' {
        $state.cost_ledgers.astra.known_cost=3
        Expect-Code { Sync-TeamCost $state $script:ManifestData $dir } 80
    }
}
