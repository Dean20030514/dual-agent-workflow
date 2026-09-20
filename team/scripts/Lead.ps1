function Get-TeamLeadEvidence($Manifest) {
    $expected = $Manifest.models.lead.runtime_model
    $result = @{configured=$true;runtime_verified=$false;expected_model=$expected;model=$null;
        evidence_kind='codex_active_turn_metadata';reason='No active Codex thread identity';thread_id=$null;turn_id=$null}
    $id = $env:CODEX_THREAD_ID
    if (-not $id -or $id -notmatch '^[a-fA-F0-9-]{36}$') { return $result }
    $result.thread_id=$id
    $homeRoot=if ($env:CODEX_HOME) {$env:CODEX_HOME} else {Join-Path $env:USERPROFILE '.codex'}
    try {
        # Desktop continuations retain the thread identity but append a rollout UUID.
        # Discover both names; select by recorded chronology, never by file mtime or
        # by searching for whichever older log happens to contain an acceptable model.
        $namePattern='-' + [regex]::Escape($id) + '(?:_[a-fA-F0-9-]{36})?\.jsonl$'
        $files=@(Get-ChildItem -LiteralPath (Join-Path $homeRoot 'sessions') -File -Recurse -Filter "*-$id*.jsonl" -ErrorAction Stop |
            Where-Object { $_.Name -match $namePattern })
        if ($files.Count -eq 0) { throw 'No session log for CODEX_THREAD_ID' }
        if (($files | Measure-Object Length -Sum).Sum -gt 256MB) { throw 'Session logs exceed the bounded evidence scan; start a fresh Lead session' }
        $sessions=@()
        foreach ($file in $files) {
            $meta=$null; $turn=$null; $event=$null; $turnLine=''
            $latest=[DateTimeOffset]::MinValue
            $stream=[IO.File]::Open($file.FullName,'Open','Read',([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
            $reader=[IO.StreamReader]::new($stream,[Text.Encoding]::UTF8,$true)
            try {
                while ($null -ne ($line=$reader.ReadLine())) {
                    if ($line -notmatch '"type"\s*:\s*"(session_meta|turn_context|event_msg)"') { continue }
                    if ($line -notmatch '"type"\s*:\s*"(session_meta|turn_context|task_started|task_complete|task_aborted)"') { continue }
                    try { $record=ConvertFrom-Json $line -AsHashtable -Depth 100 -ErrorAction Stop }
                    catch { throw 'Incomplete or invalid Lead metadata; retry after the session log is flushed' }
                    if ($record.type -ne 'session_meta' -and $record.type -ne 'turn_context' -and
                        -not ($record.type -eq 'event_msg' -and $record.payload.type -in @('task_started','task_complete','task_aborted'))) { continue }
                    if ($files.Count -gt 1) {
                        if (-not $record['timestamp']) { throw 'Multiple session logs require recorded metadata timestamps' }
                        $timestamp=[DateTimeOffset]$record.timestamp
                        if ($timestamp -gt $latest) { $latest=$timestamp }
                    }
                    if ($record.type -eq 'session_meta') {$meta=$record.payload}
                    elseif ($record.type -eq 'turn_context') {$turn=$record.payload;$turnLine=$line}
                    elseif ($record.type -eq 'event_msg' -and $record.payload.type -in @('task_started','task_complete','task_aborted')) {$event=$record.payload}
                }
            } finally {$reader.Dispose()}
            if (-not $meta -or $meta.id -cne $id -or $meta.model_provider -cne 'openai' -or
                $meta.source -notin @('cli','exec','vscode','appServer')) { throw 'Lead identity/provider/source does not match a direct Codex session' }
            $sessions+=@{meta=$meta;turn=$turn;event=$event;turnLine=$turnLine;latest=$latest;path=$file.FullName}
        }
        if (@($sessions | Where-Object { $_.event -and $_.event.type -eq 'task_started' }).Count -gt 1) {
            throw 'Multiple active session logs for CODEX_THREAD_ID; cannot identify the current Lead turn'
        }
        $ordered=@($sessions | Sort-Object latest -Descending)
        if ($ordered.Count -gt 1 -and $ordered[0].latest -eq $ordered[1].latest) {
            throw 'Ambiguous session log chronology for CODEX_THREAD_ID'
        }
        $selected=$ordered[0]
        $meta=$selected.meta; $turn=$selected.turn; $event=$selected.event; $turnLine=$selected.turnLine
        if (-not $turn -or -not $turn['turn_id'] -or -not $event -or $event.type -cne 'task_started' -or
            $event.turn_id -cne $turn.turn_id) { throw 'No matching active Codex turn; configuration or a completed turn is not runtime proof' }
        $result.model=$turn.model; $result.turn_id=$turn.turn_id
        $result['harness_version']=$meta.cli_version
        $result['session_log']=$selected.path
        $result['metadata_sha256']=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($turnLine))).ToLowerInvariant()
        if ($turn.model -cne $expected) { throw "Active Lead model is $($turn.model); expected $expected" }
        $result.runtime_verified=$true; $result.reason='Current Codex turn metadata matches the manifest (local harness evidence, not provider attestation)'
    } catch { $result.reason=$_.Exception.Message }
    return $result
}

function Assert-TeamLead($Manifest) {
    $evidence=Get-TeamLeadEvidence $Manifest
    if (-not $evidence.runtime_verified) { Stop-TeamError 20 "Lead model not verified: $($evidence.reason). Start Codex with the manifest model, then run Team from that active session." }
    return $evidence
}
