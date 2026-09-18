function Get-TeamLeadEvidence($Manifest) {
    $expected = $Manifest.models.lead.runtime_model
    $result = @{configured=$true;runtime_verified=$false;expected_model=$expected;model=$null;
        evidence_kind='codex_active_turn_metadata';reason='No active Codex thread identity';thread_id=$null;turn_id=$null}
    $id = $env:CODEX_THREAD_ID
    if (-not $id -or $id -notmatch '^[a-fA-F0-9-]{36}$') { return $result }
    $result.thread_id=$id
    $homeRoot=if ($env:CODEX_HOME) {$env:CODEX_HOME} else {Join-Path $env:USERPROFILE '.codex'}
    try {
        $files=@(Get-ChildItem -LiteralPath (Join-Path $homeRoot 'sessions') -File -Recurse -Filter "*-$id.jsonl" -ErrorAction Stop)
        if ($files.Count -ne 1) { throw 'Expected exactly one active session log for CODEX_THREAD_ID' }
        if ($files[0].Length -gt 256MB) { throw 'Session log exceeds the bounded evidence scan; start a fresh Lead session' }
        $meta=$null; $turn=$null; $event=$null; $turnLine=''
        $stream=[IO.File]::Open($files[0].FullName,'Open','Read',([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
        $reader=[IO.StreamReader]::new($stream,[Text.Encoding]::UTF8,$true)
        try {
            while ($null -ne ($line=$reader.ReadLine())) {
                if ($line -notmatch '"type"\s*:\s*"(session_meta|turn_context|event_msg)"') { continue }
                if ($line -notmatch '"type"\s*:\s*"(session_meta|turn_context|task_started|task_complete|task_aborted)"') { continue }
                try { $record=ConvertFrom-Json $line -AsHashtable -Depth 100 -ErrorAction Stop }
                catch { throw 'Incomplete or invalid Lead metadata; retry after the session log is flushed' }
                if ($record.type -eq 'session_meta') {$meta=$record.payload}
                elseif ($record.type -eq 'turn_context') {$turn=$record.payload;$turnLine=$line}
                elseif ($record.type -eq 'event_msg' -and $record.payload.type -in @('task_started','task_complete','task_aborted')) {$event=$record.payload}
            }
        } finally {$reader.Dispose()}
        if (-not $meta -or $meta.id -cne $id -or $meta.model_provider -cne 'openai' -or
            $meta.source -notin @('cli','exec','vscode','appServer')) { throw 'Lead identity/provider/source does not match a direct Codex session' }
        if (-not $turn -or -not $turn['turn_id'] -or -not $event -or $event.type -cne 'task_started' -or
            $event.turn_id -cne $turn.turn_id) { throw 'No matching active Codex turn; configuration or a completed turn is not runtime proof' }
        $result.model=$turn.model; $result.turn_id=$turn.turn_id
        $result['harness_version']=$meta.cli_version
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
