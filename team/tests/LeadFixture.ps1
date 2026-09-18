# Synthetic Codex metadata for deterministic CLI wiring tests, never live evidence.
function Enable-TeamLeadFixture([string]$Directory) {
    $saved=@{home=$env:CODEX_HOME;thread=$env:CODEX_THREAD_ID}
    $env:CODEX_HOME=Join-Path $Directory 'codex-fixture'
    $env:CODEX_THREAD_ID=[guid]::NewGuid().ToString()
    $folder=Join-Path $env:CODEX_HOME 'sessions/2000/01/01'
    [IO.Directory]::CreateDirectory($folder) | Out-Null
    $rows=@(
        @{type='session_meta';payload=@{id=$env:CODEX_THREAD_ID;source='exec';model_provider='openai';cli_version='synthetic-fixture'}},
        @{type='turn_context';payload=@{turn_id='fixture-turn';model='gpt-6-astra'}},
        @{type='event_msg';payload=@{type='task_started';turn_id='fixture-turn'}}
    )
    [IO.File]::WriteAllLines((Join-Path $folder "rollout-$($env:CODEX_THREAD_ID).jsonl"),[string[]]@($rows | ForEach-Object {ConvertTo-Json $_ -Depth 8 -Compress}))
    return $saved
}
function Restore-TeamLeadFixture($Saved) { $env:CODEX_HOME=$Saved.home;$env:CODEX_THREAD_ID=$Saved.thread }
