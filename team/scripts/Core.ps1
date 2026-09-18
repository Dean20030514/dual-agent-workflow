# Shared deterministic primitives; no model calls.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:TeamRoot = Split-Path $PSScriptRoot -Parent

function Stop-TeamError([int]$Code, [string]$Message) {
    $errorObject = [InvalidOperationException]::new($Message)
    $errorObject.Data['TeamExitCode'] = $Code
    throw $errorObject
}

function Read-TeamData([string]$Path) {
    try {
        $stream = [IO.File]::Open([IO.Path]::GetFullPath($Path), 'Open', 'Read', ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
        $reader = [IO.StreamReader]::new($stream, [Text.Encoding]::UTF8, $true)
        try { $raw = $reader.ReadToEnd() } finally { $reader.Dispose() }
        if ($raw.TrimStart().StartsWith('{') -or $raw.TrimStart().StartsWith('[')) {
            return ConvertFrom-Json -InputObject $raw -AsHashtable -Depth 100
        }
        Import-Module powershell-yaml -MinimumVersion 0.4.12 -ErrorAction Stop
        return ConvertFrom-Yaml -Yaml $raw -Ordered
    } catch { Stop-TeamError 10 "Cannot read protocol document '$Path': $($_.Exception.Message)" }
}

function Write-TeamData([string]$Path, $Value) {
    $parent = [IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($Path))
    [IO.Directory]::CreateDirectory($parent) | Out-Null
    $temp = Join-Path $parent ('.atomic-' + [guid]::NewGuid().ToString('N'))
    try {
        [IO.File]::WriteAllText($temp, ($Value | ConvertTo-Json -Depth 100) + "`n", [Text.UTF8Encoding]::new($false))
        # Windows readers outside our control may omit FileShare.Delete. Retry only a bounded
        # sharing window; persistent ACL/read-only failures still surface with the old file intact.
        for ($attempt=0; ; $attempt++) {
            try { [IO.File]::Move($temp, [IO.Path]::GetFullPath($Path), $true); break }
            catch [IO.IOException] { if ($attempt -ge 8) { throw }; Start-Sleep -Milliseconds 25 }
            catch [UnauthorizedAccessException] { if ($attempt -ge 8) { throw }; Start-Sleep -Milliseconds 25 }
        }
    } finally { if (Test-Path -LiteralPath $temp) { [IO.File]::Delete($temp) } }
}

function Get-TeamHash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }

function Get-TeamOwnedProcess([int]$ProcessId, $StartedAt) {
    if ($ProcessId -le 0 -or -not $StartedAt) { return $null }
    $process = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
    if (-not $process) { return $null }
    # ConvertFrom-Json may deserialize ISO timestamps as DateTime on newer PowerShell.
    # Compare UTC ticks, not a formatted string against a culture-converted DateTime.
    try {
        if ($process.StartTime.ToUniversalTime().Ticks -eq ([datetime]$StartedAt).ToUniversalTime().Ticks) { return $process }
    } catch { return $null }
    return $null
}

function Assert-TeamId([string]$Value) {
    if ($Value -notmatch '^[A-Za-z0-9][A-Za-z0-9_-]{0,79}$') { Stop-TeamError 10 "Unsafe identifier: $Value" }
}

function Get-TeamChild([string]$Root, [string]$Relative) {
    $base = [IO.Path]::GetFullPath($Root).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    $path = [IO.Path]::GetFullPath((Join-Path $base $Relative))
    if (-not $path.StartsWith($base, [StringComparison]::OrdinalIgnoreCase)) { Stop-TeamError 82 'Path escapes its assigned root' }
    $cursor = $path
    while ($cursor -and $cursor.Length -ge $base.TrimEnd([IO.Path]::DirectorySeparatorChar).Length) {
        if (Test-Path -LiteralPath $cursor) {
            if ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
                Stop-TeamError 82 "Reparse point is not allowed: $cursor"
            }
        }
        $cursor = [IO.Path]::GetDirectoryName($cursor)
    }
    return $path
}

function Invoke-TeamGit([string]$Repo, [string[]]$Arguments) {
    $output = & git -C $Repo @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) { Stop-TeamError 80 "Git failed ($($Arguments[0])): $($output -join ' ')" }
    return ($output -join "`n").TrimEnd()
}

function Test-TeamScope([string]$Path, [string[]]$Scopes) {
    foreach ($scope in $Scopes) {
        $pattern = [regex]::Escape($scope).Replace('\*\*', '.*').Replace('\*', '[^/]*').Replace('\?', '[^/]')
        if ($Path -cmatch ('^' + $pattern + '$')) { return $true }
    }
    return $false
}

function Test-TeamScopeSubset([string]$Child, [string[]]$Parents) {
    if ($Child -match '(^/|\\|:|(^|/)\.\.(/|$))') { return $false }
    if ($Child -cin $Parents) { return $true }
    if ($Child -notmatch '[*?]') { return Test-TeamScope $Child $Parents }
    foreach ($parent in $Parents) {
        if ($parent.EndsWith('/**')) {
            $prefix=$parent.Substring(0,$parent.Length-2)
            if ($prefix -notmatch '[*?]' -and $Child.StartsWith($prefix,[StringComparison]::Ordinal)) { return $true }
        }
    }
    return $false
}

function Test-TeamSchema($Value, [string]$Name) {
    $jsonText = $Value | ConvertTo-Json -Depth 100 -Compress
    $schema = Join-Path $script:TeamRoot "schemas/$Name.schema.json"
    try { $valid = Test-Json -Json $jsonText -SchemaFile $schema -ErrorAction Stop }
    catch { Stop-TeamError 10 "${Name}: $($_.Exception.Message)" }
    if (-not $valid) { Stop-TeamError 10 "Invalid $Name document" }
}

function New-TeamProcess([string]$Executable, [string[]]$Arguments, [string]$Directory, [string]$Stdout, [string]$Stderr, [string]$InputText = '', [long]$MaxOutputBytes = 50MB) {
    if ($MaxOutputBytes -lt 1) { Stop-TeamError 10 'Output limit must be positive' }
    if (-not ('TeamRuntime.BoundedCopy' -as [type])) { Add-Type -Path (Join-Path $PSScriptRoot 'ProcessStreams.cs') }
    # ArgumentList passes literal arguments; never build a command shell string.
    $info = [Diagnostics.ProcessStartInfo]::new()
    if ([IO.Path]::GetExtension($Executable) -eq '.ps1') {
        $info.FileName = (Get-Command pwsh -ErrorAction Stop).Source
        foreach ($arg in @('-NoProfile', '-File', $Executable) + $Arguments) { $info.ArgumentList.Add($arg) }
    } else {
        $info.FileName = $Executable
        foreach ($arg in $Arguments) { $info.ArgumentList.Add($arg) }
    }
    $info.WorkingDirectory = $Directory
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardInput = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $info
    $started=$false; $outStream=$null; $errStream=$null; $outCopy=$null; $errCopy=$null; $inputCancellation=$null
    try {
        # A log creation failure must never leave a process behind.
        $outStream = [IO.File]::Create($Stdout)
        $errStream = [IO.File]::Create($Stderr)
        $started=$process.Start()
        if (-not $started) { Stop-TeamError 30 'Process did not start' }
        $outCopy=[TeamRuntime.BoundedCopy]::Start($process.StandardOutput.BaseStream,$outStream,$MaxOutputBytes)
        $errCopy=[TeamRuntime.BoundedCopy]::Start($process.StandardError.BaseStream,$errStream,$MaxOutputBytes)
        $inputCancellation=[Threading.CancellationTokenSource]::new()
        return @{
            process=$process;started=[DateTime]::UtcNow;elapsed=[Diagnostics.Stopwatch]::StartNew();last_activity=[DateTime]::UtcNow;last_size=0L
            stdout=$Stdout;stderr=$Stderr;out_stream=$outStream;err_stream=$errStream;max_output_bytes=$MaxOutputBytes
            out_copy=$outCopy.Completion;err_copy=$errCopy.Completion;out_capture=$outCopy;err_capture=$errCopy
            input_cancellation=$inputCancellation
            input_write=[TeamRuntime.BoundedCopy]::WriteInputAsync($process.StandardInput,$InputText,$inputCancellation.Token)
        }
    } catch {
        $failure=[InvalidOperationException]::new("Process launch failed: $($_.Exception.Message)",$_.Exception)
        $failure.Data['TeamExitCode']=30; $failure.Data['ProcessStarted']=$started
        try { if ($started -and -not $process.HasExited) { $process.Kill($true); $null=$process.WaitForExit(5000) } }
        finally {
            if ($inputCancellation) { $inputCancellation.Cancel() }
            if ($outCopy) { $outCopy.Cancel() }; if ($errCopy) { $errCopy.Cancel() }
            if ($outStream) { $outStream.Dispose() }; if ($errStream) { $errStream.Dispose() }; $process.Dispose()
        }
        throw $failure
    }
}

function Stop-TeamExitedProcessChildren($Handle) {
    # Windows retains a dead parent's PID in child metadata. Never trust that PID without birth times.
    if (-not $IsWindows -or -not $Handle.process.HasExited) { return }
    $Handle['child_cleanup']=@{terminated=@();unverified=0;error=$null}
    try {
        $rootId=$Handle.process.Id; $born=$Handle.process.StartTime.ToUniversalTime().Ticks
        $ended=$Handle.process.ExitTime.ToUniversalTime().Ticks
        $children=@(Get-CimInstance Win32_Process -Filter "ParentProcessId = $rootId" -Property ProcessId,CreationDate -OperationTimeoutSec 2 -ErrorAction Stop)
        $cleanupWatch=[Diagnostics.Stopwatch]::StartNew()
        foreach ($child in $children) {
            if ($cleanupWatch.ElapsedMilliseconds -ge 2000) { $Handle.child_cleanup.unverified++; continue }
            $process=Get-Process -Id $child.ProcessId -ErrorAction SilentlyContinue
            if (-not $process) { continue }
            try {
                $created=$process.StartTime.ToUniversalTime().Ticks
                if ($created -lt $born -or $created -gt $ended -or -not $child.CreationDate -or
                    [Math]::Abs($created-$child.CreationDate.ToUniversalTime().Ticks) -ge 10) {
                    $Handle.child_cleanup.unverified++; continue
                }
                $process.Kill($true)
                if (-not $process.WaitForExit([int][Math]::Max(1,2000-$cleanupWatch.ElapsedMilliseconds))) { $Handle.child_cleanup.unverified++; continue }
                $Handle.child_cleanup.terminated+=@{pid=[int]$child.ProcessId;start_ticks=$created}
            } finally { $process.Dispose() }
        }
    } catch { $Handle.child_cleanup.error=$_.Exception.Message }
}

function Test-TeamProcessStreamsComplete($Handle) {
    return $Handle.out_copy.IsCompleted -and $Handle.err_copy.IsCompleted -and $Handle.input_write.IsCompleted
}

function Get-TeamProcessCleanupEvidence($Handle) {
    if (-not $Handle) { return $null }
    return @{drain_expired=[bool]$Handle['drain_expired'];children=$Handle['child_cleanup'];streams_settled=(Test-TeamProcessStreamsComplete $Handle)}
}

function Assert-TeamCleanupSettled($State) {
    if (@($State.tasks.Values | Where-Object { $_['cleanup_pending'] }).Count) {
        Stop-TeamError 80 'Owned process cleanup is pending; inspect its evidence and retry stop before further execution'
    }
}

function Close-TeamProcess($Handle, [switch]$Terminate, [int]$DrainTimeoutMilliseconds = 3000) {
    if ($Handle['closed']) { return $Handle.exit_code }
    $code=$null; $drainExpired=$false
    try {
        if ($Terminate -and -not $Handle.process.HasExited) { $Handle.process.Kill($true) }
        if (-not $Handle.process.WaitForExit(5000)) { Stop-TeamError 31 'Process did not exit during bounded cleanup' }
        $code=$Handle.process.ExitCode
        $watch=[Diagnostics.Stopwatch]::StartNew()
        while (-not (Test-TeamProcessStreamsComplete $Handle) -and $watch.ElapsedMilliseconds -lt $DrainTimeoutMilliseconds) { Start-Sleep -Milliseconds 20 }
        if (-not (Test-TeamProcessStreamsComplete $Handle)) {
            $drainExpired=$true
            Stop-TeamExitedProcessChildren $Handle
            Stop-TeamError 31 'Process exited with unfinished pipes; partial output preserved'
        }
        if ($Handle.out_copy.IsFaulted -or $Handle.err_copy.IsFaulted) { Stop-TeamError 30 'Process output capture failed; partial output preserved' }
        $null = $Handle.out_copy.GetAwaiter().GetResult(); $null = $Handle.err_copy.GetAwaiter().GetResult()
        try { $null=$Handle.input_write.GetAwaiter().GetResult() }
        catch { if ($code -eq 0) { Stop-TeamError 30 'Process exited before its full input was delivered' } }
    }
    finally {
        $Handle.input_cancellation.Cancel(); $Handle.out_capture.Cancel(); $Handle.err_capture.Cancel()
        $watch=[Diagnostics.Stopwatch]::StartNew()
        while (-not (Test-TeamProcessStreamsComplete $Handle) -and $watch.ElapsedMilliseconds -lt 1000) { Start-Sleep -Milliseconds 20 }
        # Observe faults even on cancellation; never await a pipe without a deadline.
        foreach ($task in @($Handle.out_copy,$Handle.err_copy,$Handle.input_write)) { if ($task.IsFaulted) { $null=$task.Exception } }
        $Handle.out_stream.Dispose(); $Handle.err_stream.Dispose()
        $Handle['exit_code']=$code; $Handle['closed']=$true; $Handle['drain_expired']=$drainExpired; $Handle.process.Dispose()
    }
    return $code
}

function Test-TeamProcessOutputLimit($Handle, [string[]]$AdditionalFiles = @()) {
    if ($Handle.out_capture.Exceeded -or $Handle.err_capture.Exceeded) { return $true }
    foreach ($path in $AdditionalFiles) {
        if ((Test-Path -LiteralPath $path -PathType Leaf) -and (Get-Item -LiteralPath $path).Length -gt $Handle.max_output_bytes) { return $true }
    }
    return $false
}

function Wait-TeamProcess($Handle, [int]$TimeoutSeconds = 60, [int]$IdleTimeoutSeconds = 0, [string[]]$AdditionalFiles = @()) {
    $lastBytes=0L; $lastActivity=$Handle.elapsed.Elapsed.TotalSeconds
    $rootExitAt=$null
    while ($true) {
        $bytes=$Handle.out_capture.BytesRead+$Handle.err_capture.BytesRead
        if ($bytes -ne $lastBytes) { $lastActivity=$Handle.elapsed.Elapsed.TotalSeconds; $lastBytes=$bytes }
        $reason=if (Test-TeamProcessOutputLimit $Handle $AdditionalFiles) {'output limit'}
            elseif ($Handle.elapsed.Elapsed.TotalSeconds -ge $TimeoutSeconds) {'timeout'}
            elseif ($IdleTimeoutSeconds -gt 0 -and ($Handle.elapsed.Elapsed.TotalSeconds-$lastActivity) -ge $IdleTimeoutSeconds) {'idle timeout'}
            elseif ($null -ne $rootExitAt -and ($Handle.elapsed.Elapsed.TotalSeconds-$rootExitAt) -ge 3) {'pipe drain deadline'}
            else {''}
        if ($reason) {
            try { $null=Close-TeamProcess $Handle -Terminate -DrainTimeoutMilliseconds 0 }
            catch { if ($_.Exception.Data['TeamExitCode'] -ne 31) { throw } }
            Stop-TeamError 31 "Process exceeded its $reason; partial output preserved"
        }
        if ($Handle.out_copy.IsFaulted -or $Handle.err_copy.IsFaulted) {
            try { $null=Close-TeamProcess $Handle -Terminate -DrainTimeoutMilliseconds 0 } catch { }
            Stop-TeamError 30 'Process output capture failed; partial output preserved'
        }
        if ($Handle.process.HasExited) {
            if ($null -eq $rootExitAt) { $rootExitAt=$Handle.elapsed.Elapsed.TotalSeconds }
            if (Test-TeamProcessStreamsComplete $Handle) {
                $code=Close-TeamProcess $Handle -DrainTimeoutMilliseconds 0
                if (Test-TeamProcessOutputLimit $Handle $AdditionalFiles) { Stop-TeamError 31 'Process exceeded its output limit; partial output preserved' }
                return $code
            }
            Start-Sleep -Milliseconds 100
        } else {
            $null=$Handle.process.WaitForExit(100)
        }
    }
}

function Start-TeamDshProcess([string]$Directory, [string]$Worktree, [string[]]$Arguments, [long]$MaxOutputBytes) {
    for ($attempt=1; $attempt -le 2; $attempt++) {
        $resolved=$false; $handle=$null
        try {
            $command=(Get-Command dsh -ErrorAction Stop).Source; $resolved=$true
            $handle=New-TeamProcess $command $Arguments $Worktree (Join-Path $Directory 'worker.stdout') (Join-Path $Directory 'worker.stderr') -MaxOutputBytes $MaxOutputBytes
            Write-TeamData (Join-Path $Directory "launch-$attempt.json") @{attempt=$attempt;started=$true;pid=$handle.process.Id;timestamp=[DateTime]::UtcNow.ToString('o')}
            $handle['launch_attempts']=$attempt
            return $handle
        } catch {
            $failure=$_.Exception
            $started=if (-not $resolved) {$false} elseif ($failure.Data.Contains('ProcessStarted')) {[bool]$failure.Data['ProcessStarted']} else {$null}
            if ($handle) { $null=Close-TeamProcess $handle -Terminate; $started=$true }
            $notStarted=$started -eq $false
            Write-TeamData (Join-Path $Directory "launch-$attempt.json") @{attempt=$attempt;started=$started;retryable=$notStarted;error=$failure.Message;timestamp=[DateTime]::UtcNow.ToString('o')}
            if (-not $notStarted -or $attempt -eq 2) {
                $failure.Data['StartupExhausted']=$notStarted; $failure.Data['LaunchAttempts']=$attempt
                throw $failure
            }
            Start-Sleep -Milliseconds 200
        }
    }
}

function Get-TeamRoute([string]$TaskText, [string]$Repo = '', $Manifest = $null) {
    $mode = 'UNKNOWN'; $confidence = 0.3; $reasons = @('insufficient local signals')
    $metadata = @{ frontend = $false; backend = $false; database = $false; markers = @() }
    # Only inspect a fixed set of path names. Never read package scripts, credentials,
    # instructions or arbitrary project contents to make a routing recommendation.
    if ($Repo) {
        $markers = @{
            frontend = @('frontend','web','client','src/components','app/components','apps/web')
            backend = @('backend','server','api','src/api','apps/api')
            database = @('prisma/schema.prisma','db/migrations','migrations','database')
        }
        foreach ($domain in $markers.Keys) {
            foreach ($marker in $markers[$domain]) {
                if (Test-Path -LiteralPath (Join-Path $Repo $marker)) {
                    $metadata[$domain] = $true; $metadata.markers += $marker
                }
            }
        }
    }
    $riskFlags = @()
    if ($TaskText -match '(?i)(production|生产|credentials?|凭据|secrets?|密钥|irreversible|不可逆|drop\s+table|删除.*数据)') { $riskFlags += 'owner_decision_required' }
    if ($TaskText -match '(?i)(auth|认证|鉴权|authorization|权限|security|安全)') { $riskFlags += 'security_sensitive' }
    if ($TaskText -match '(?i)(auth.*redesign|redesign.*auth|认证.*重构|重构.*认证)') {
        $mode = 'L3'; $confidence = 0.9; $reasons = @('authentication architecture change')
    } elseif ($TaskText -match '(?i)(avatar.*upload|upload.*avatar|头像.*上传|上传.*头像|frontend.*backend|前端.*后端)') {
        $mode = 'L2'; $confidence = 0.85; $reasons = @('multiple implementation domains')
    } elseif ($TaskText -match '(?i)(sql|数据库|query optimization)') {
        $mode = 'L1'; $confidence = 0.85; $reasons = @('substantial single database domain')
    } elseif ($TaskText -match '(?i)(typo|readme|错别字|拼写)') {
        $mode = 'L0'; $confidence = 0.95; $reasons = @('localized documentation edit')
    }
    # Metadata refines ambiguous implementation tasks, never promotes a small edit
    # merely because it happens to live in a large repository.
    if ($mode -eq 'UNKNOWN' -and $TaskText -match '(?i)(implement|build|add|feature|实现|新增|添加|功能)') {
        if ($metadata.frontend -and $metadata.backend) {
            $mode = 'L2'; $confidence = 0.65; $reasons = @('implementation request in a repository with frontend and backend markers')
        } elseif ($metadata.frontend -or $metadata.backend -or $metadata.database) {
            $mode = 'L1'; $confidence = 0.6; $reasons = @('implementation request with one local domain signal')
        }
    }
    if ($riskFlags.Count -and $mode -eq 'L0') {
        $mode = 'UNKNOWN'; $confidence = 0.4; $reasons = @('risk signals require Lead assessment despite small-edit keywords')
    }
    $health = @{auto_route='normal';consecutive_misroutes=0}
    if ($Repo) {
        $healthPath = Get-TeamChild $Repo 'team/runtime/routing.json'
        if (Test-Path -LiteralPath $healthPath) { $health = Read-TeamData $healthPath }
    }
    $disabled = $Manifest -and -not $Manifest.team.enabled
    if ($disabled) { $mode = 'L0'; $confidence = 1.0; $reasons = @('team disabled') }
    $degraded = $health.auto_route -eq 'degraded'
    $leadAction = if ($disabled) {'use_normal_codex'} elseif ($degraded) {'explicit_route_for_each_complex_task_until_revalidated'}
        elseif ($riskFlags -contains 'owner_decision_required') {'assess_owner_escalation'}
        elseif ($confidence -lt 0.8) {'lead_assessment_required'} else {'consider_recommendation'}
    return @{ recommended_mode = $mode; confidence = $confidence; reasons = $reasons; source = $(if ($disabled) {'configuration'} else {'local_heuristic'})
        repo_metadata = $metadata; risk_flags = $riskFlags; auto_route = $health.auto_route
        consecutive_misroutes = $health.consecutive_misroutes; lead_action = $leadAction
        notice = $(if ($degraded) {'Automatic routing is degraded. Call route explicitly for every complex task; use revalidate-route after correcting the observed mismatches.'} else {$null}) }
}
