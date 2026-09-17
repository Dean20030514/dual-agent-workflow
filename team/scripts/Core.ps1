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
        $raw = [IO.File]::ReadAllText([IO.Path]::GetFullPath($Path))
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
        [IO.File]::Move($temp, [IO.Path]::GetFullPath($Path), $true)
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

function New-TeamProcess([string]$Executable, [string[]]$Arguments, [string]$Directory, [string]$Stdout, [string]$Stderr, [string]$InputText = '') {
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
    if (-not $process.Start()) { Stop-TeamError 30 'Process did not start' }
    $outStream = [IO.File]::Create($Stdout)
    $errStream = [IO.File]::Create($Stderr)
    $handle = @{
        process = $process; started = [DateTime]::UtcNow; last_activity = [DateTime]::UtcNow; last_size = 0L
        stdout = $Stdout; stderr = $Stderr; out_stream = $outStream; err_stream = $errStream
        out_copy = $process.StandardOutput.BaseStream.CopyToAsync($outStream)
        err_copy = $process.StandardError.BaseStream.CopyToAsync($errStream)
    }
    if ($InputText) { $process.StandardInput.Write($InputText) }
    $process.StandardInput.Close()
    return $handle
}

function Close-TeamProcess($Handle, [switch]$Terminate) {
    if ($Terminate -and -not $Handle.process.HasExited) { $Handle.process.Kill($true) }
    $Handle.process.WaitForExit()
    try { $null = $Handle.out_copy.GetAwaiter().GetResult(); $null = $Handle.err_copy.GetAwaiter().GetResult() }
    finally { $Handle.out_stream.Dispose(); $Handle.err_stream.Dispose() }
    $code = $Handle.process.ExitCode
    $Handle.process.Dispose()
    return $code
}

function Wait-TeamProcess($Handle, [int]$TimeoutSeconds = 60) {
    if (-not $Handle.process.WaitForExit($TimeoutSeconds * 1000)) {
        $null = Close-TeamProcess $Handle -Terminate
        Stop-TeamError 31 "Process exceeded $TimeoutSeconds seconds"
    }
    return Close-TeamProcess $Handle
}

function Get-TeamRoute([string]$TaskText) {
    $mode = 'UNKNOWN'; $confidence = 0.3; $reasons = @('insufficient local signals')
    if ($TaskText -match '(?i)(auth.*redesign|redesign.*auth|认证.*重构|重构.*认证)') {
        $mode = 'L3'; $confidence = 0.9; $reasons = @('authentication architecture change')
    } elseif ($TaskText -match '(?i)(avatar.*upload|upload.*avatar|头像.*上传|上传.*头像|frontend.*backend|前端.*后端)') {
        $mode = 'L2'; $confidence = 0.85; $reasons = @('multiple implementation domains')
    } elseif ($TaskText -match '(?i)(sql|数据库|query optimization)') {
        $mode = 'L1'; $confidence = 0.85; $reasons = @('substantial single database domain')
    } elseif ($TaskText -match '(?i)(typo|readme|错别字|拼写)') {
        $mode = 'L0'; $confidence = 0.95; $reasons = @('localized documentation edit')
    }
    return @{ recommended_mode = $mode; confidence = $confidence; reasons = $reasons; source = 'local_heuristic' }
}
