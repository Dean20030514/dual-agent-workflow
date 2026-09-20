BeforeAll {
    $script:TeamPath=Split-Path $PSScriptRoot -Parent
    foreach ($name in @('Core','Lead')) { . (Join-Path $script:TeamPath "scripts/$name.ps1") }
    . (Join-Path $PSScriptRoot 'LeadFixture.ps1')
    $script:SavedLead=Enable-TeamLeadFixture $TestDrive
    $script:ManifestData=Read-TeamData (Join-Path $script:TeamPath 'manifest.yaml')
    function Write-SessionEvidence($Path, [int]$Minute, [string]$Model='gpt-6-astra', [string]$End='task_started') {
        $time=[datetimeoffset]'2026-01-01T00:00:00Z'
        $time=$time.AddMinutes($Minute)
        $rows=@(
            @{timestamp=$time.ToString('o');type='session_meta';payload=@{id=$env:CODEX_THREAD_ID;source='vscode';model_provider='openai';cli_version='synthetic-continuation'}},
            @{timestamp=$time.AddSeconds(1).ToString('o');type='event_msg';payload=@{type=$End;turn_id="turn-$Minute"}},
            @{timestamp=$time.AddSeconds(2).ToString('o');type='turn_context';payload=@{turn_id="turn-$Minute";model=$Model}}
        )
        [IO.File]::WriteAllLines($Path,[string[]]@($rows | ForEach-Object {ConvertTo-Json $_ -Depth 8 -Compress}))
    }
    function Assert-Rejected {
        $proof=Get-TeamLeadEvidence $script:ManifestData
        $proof.runtime_verified | Should -BeFalse
        { Assert-TeamLead $script:ManifestData } | Should -Throw '*Lead model not verified*'
    }
}
AfterAll { Restore-TeamLeadFixture $script:SavedLead }

Describe 'Desktop continuation Lead evidence' {
    BeforeEach {
        $null=Enable-TeamLeadFixture (Join-Path $TestDrive ([guid]::NewGuid().ToString('N')))
        $original=(Get-ChildItem (Join-Path $env:CODEX_HOME 'sessions') -Recurse -File)[0].FullName
        $continuation=Join-Path (Split-Path $original) "rollout-$($env:CODEX_THREAD_ID)_$([guid]::NewGuid()).jsonl"
        Write-SessionEvidence $original 0 -End task_complete
        Write-SessionEvidence $continuation 1
    }
    It 'verifies the unique current continuation using original identity and model checks' {
        # An old file being touched does not turn it into current evidence.
        (Get-Item $original).LastWriteTimeUtc=[datetime]::UtcNow.AddHours(1)
        $proof=Assert-TeamLead $script:ManifestData
        $proof.runtime_verified | Should -BeTrue
        $proof.turn_id | Should -Be 'turn-1'
        $proof.session_log | Should -Be $continuation
        $proof.metadata_sha256 | Should -Match '^[a-f0-9]{64}$'
    }
    It 'rejects a completed or aborted continuation: <End>' -ForEach @(@{End='task_complete'},@{End='task_aborted'}) {
        Write-SessionEvidence $continuation 1 -End $End
        Assert-Rejected
    }
    It 'rejects a newer completed log instead of falling back to an older active log' {
        Write-SessionEvidence $original 0
        Write-SessionEvidence $continuation 1 -End task_complete
        Assert-Rejected
    }
    It 'rejects an active continuation using the wrong model' {
        Write-SessionEvidence $continuation 1 -Model other
        Assert-Rejected
    }
    It 'rejects an invalid continuation identity field: <Field>' -ForEach @(
        @{Field='id';Value='wrong'}, @{Field='model_provider';Value='other'}, @{Field='source';Value='other'}
    ) {
        $rows=@(Get-Content $continuation | ForEach-Object {ConvertFrom-Json $_ -AsHashtable})
        $rows[0].payload[$Field]=$Value
        [IO.File]::WriteAllLines($continuation,[string[]]@($rows | ForEach-Object {ConvertTo-Json $_ -Depth 8 -Compress}))
        Assert-Rejected
    }
    It 'rejects a turn mismatch in the continuation' {
        Add-Content $continuation '{"timestamp":"2026-01-01T00:01:03Z","type":"event_msg","payload":{"type":"task_started","turn_id":"other"}}'
        Assert-Rejected
    }
    It 'rejects incomplete continuation metadata without falling back' {
        Add-Content $continuation '{"type":"turn_context","payload":'
        Assert-Rejected
    }
    It 'rejects multiple active logs even when their timestamps differ' {
        Write-SessionEvidence $original 0
        Assert-Rejected
    }
    It 'rejects tied chronology even if only one log is active' {
        Write-SessionEvidence $original 1 -End task_complete
        Assert-Rejected
    }
    It 'rejects missing timestamps when multiple logs must be ordered' {
        Add-Content $original '{"type":"event_msg","payload":{"type":"task_complete","turn_id":"turn-0"}}'
        Assert-Rejected
    }
    It 'supports a continuation when the original log is absent' {
        Remove-Item -LiteralPath $original
        (Assert-TeamLead $script:ManifestData).session_log | Should -Be $continuation
    }
}
