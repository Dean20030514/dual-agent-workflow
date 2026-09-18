# Opt-in deterministic verification reuse. A cache hit never replaces a real run by
# default: the caller must opt in and declare what the command depends on.
# The key binds source tree + HEAD, full command, working directory, tool identity,
# a caller-declared environment fingerprint and the caller-declared input artifact hashes.
Set-StrictMode -Version Latest

$script:TeamReuseFileLimitBytes = 64MB
$script:TeamReuseTotalLimitBytes = 256MB

function Get-TeamUntrackedInventory([string]$Worktree) {
    # -z keeps every path raw: no C-quoting for spaces, quotes or non-ASCII names.
    $raw = & git -C $Worktree -c core.quotePath=false ls-files -z --others --exclude-standard 2>$null
    if ($LASTEXITCODE -ne 0) { Stop-TeamError 80 'Cannot read the untracked source inventory' }
    $raw = if ($null -eq $raw) { '' } elseif ($raw -is [array]) { $raw -join "`n" } else { [string]$raw }
    $paths = @($raw -split "`0" | Where-Object { $_ })
    $files = @(); $total = 0L; $unsupported = $null
    foreach ($path in @($paths | Sort-Object)) {
        $full = Get-TeamChild $Worktree $path
        if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { $unsupported = "Untracked path is not a regular file: $path"; break }
        $file = Get-Item -LiteralPath $full -Force
        if ($file.Attributes -band [IO.FileAttributes]::ReparsePoint) { $unsupported = "Untracked entry is a link: $path"; break }
        if ($file.Length -gt $script:TeamReuseFileLimitBytes) { $unsupported = "Untracked file exceeds the bindable size limit: $path"; break }
        $total += $file.Length
        if ($total -gt $script:TeamReuseTotalLimitBytes) { $unsupported = 'Untracked content exceeds the bindable size limit'; break }
        $files += @{ path = $path; bytes = $file.Length; sha256 = Get-TeamHash $full }
    }
    $hash = Get-TeamTextHash (($files | ForEach-Object { "$($_.sha256)  $($_.path)" }) -join "`n")
    return @{ files = $files; sha256 = $hash; count = $files.Count; unsupported = $unsupported }
}

function Get-TeamSourceBinding([string]$Worktree) {
    $binding = @{
        head = Invoke-TeamGit $Worktree @('rev-parse', 'HEAD')
        tree = Invoke-TeamGit $Worktree @('rev-parse', 'HEAD^{tree}')
    }
    # Dirty tracked sources are never reused, whatever the cache says.
    $tracked = Invoke-TeamGit $Worktree @('status', '--porcelain', '--untracked-files=no')
    $untracked = Get-TeamUntrackedInventory $Worktree
    $binding['tracked_dirty'] = [bool]$tracked
    $binding['tracked_status_sha256'] = Get-TeamTextHash $tracked
    $binding['untracked_sha256'] = $untracked.sha256
    $binding['untracked_count'] = $untracked.count
    $binding['unsupported'] = $untracked.unsupported
    return $binding
}

function Get-TeamToolIdentity([string]$Executable) {
    # Identity is bound to content: size plus write time alone let an edited tool keep
    # a stale cache entry. Both the interpreter and the script body are hashed.
    if ([IO.Path]::GetExtension($Executable) -eq '.ps1') {
        $host_ = Get-Command pwsh -ErrorAction Stop
        $script_ = Get-Item -LiteralPath $Executable -ErrorAction Stop
        return @{ kind = 'powershell-script'; declared = $Executable; resolved = $host_.Source
            host_sha256 = Get-TeamHash $host_.Source
            script = $script_.FullName; script_sha256 = Get-TeamHash $script_.FullName
            length = $script_.Length; written = $script_.LastWriteTimeUtc.Ticks }
    }
    $command = Get-Command $Executable -ErrorAction Stop
    $file = Get-Item -LiteralPath $command.Source -ErrorAction Stop
    return @{ kind = 'executable'; declared = $Executable; resolved = $command.Source
        sha256 = Get-TeamHash $file.FullName
        length = $file.Length; written = $file.LastWriteTimeUtc.Ticks }
}

# Returns $null when the command cannot be bound safely; the caller then executes it.
function Get-TeamVerificationKey([string]$Worktree, [string]$Executable, [string[]]$Arguments, $Command) {
    $declared = if ($Command['environment_fingerprint']) { [string]$Command.environment_fingerprint } else { '' }
    if (-not $declared) { return @{ key = $null; reason = 'undeclared_environment_fingerprint' } }
    $source = Get-TeamSourceBinding $Worktree
    if ($source.tracked_dirty) { return @{ key = $null; reason = 'dirty_sources' } }
    if ($source.unsupported) { return @{ key = $null; reason = 'unsupported_source_inventory'; detail = $source.unsupported } }
    $inputs = @()
    foreach ($artifact in @($Command['input_artifacts'])) {
        if (-not $artifact) { continue }
        $full = Get-TeamChild $Worktree $artifact
        if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { return @{ key = $null; reason = 'missing_input_artifact'; detail = [string]$artifact } }
        $inputs += @{ path = [string]$artifact; bytes = (Get-Item -LiteralPath $full).Length; sha256 = Get-TeamHash $full }
    }
    $material = @{
        schema_version = 1
        command = @{ id = [string]$Command.id; executable = $Executable; args = @($Arguments) }
        cwd = [IO.Path]::GetFullPath($Worktree).TrimEnd('\', '/')
        environment_fingerprint = $declared
        input_artifacts = @($inputs | Sort-Object { $_.path })
        source = $source
        tool = Get-TeamToolIdentity $Executable
    }
    return @{ key = (Get-TeamTextHash (Get-TeamCanonicalJson $material)); material = $material; reason = $null }
}

function Get-TeamVerificationCachePath([string]$CacheDirectory, [string]$Key) {
    return (Get-TeamChild $CacheDirectory "verification-cache/$Key.json")
}

function Read-TeamVerificationCache([string]$CacheDirectory, $Binding) {
    if (-not $CacheDirectory -or -not $Binding['key']) { return @{ hit = $false; reason = $(if ($Binding['reason']) { $Binding.reason } else { 'reuse_not_opted_in' }) } }
    $path = Get-TeamVerificationCachePath $CacheDirectory $Binding.key
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return @{ hit = $false; reason = 'no_receipt' } }
    try { $receipt = Read-TeamData $path } catch { return @{ hit = $false; reason = 'unreadable_receipt' } }
    # Version 1 did not require a matching post-command binding; never reuse its successes.
    if ($receipt['schema_version'] -ne 2 -or -not $receipt['key'] -or -not $receipt['material'] -or -not $receipt['receipts']) {
        return @{ hit = $false; reason = 'legacy_receipt' }
    }
    if ($receipt.key -cne $Binding.key) { return @{ hit = $false; reason = 'key_mismatch' } }
    if ((Get-TeamCanonicalJson $receipt.material) -cne (Get-TeamCanonicalJson $Binding.material)) { return @{ hit = $false; reason = 'material_changed' } }
    # A receipt whose own key does not hash its material is self-inconsistent (hand edited,
    # truncated or written by an obsolete version) and is never trusted as a hit.
    if ((Get-TeamTextHash (Get-TeamCanonicalJson $receipt.material)) -cne [string]$receipt.key) { return @{ hit = $false; reason = 'receipt_key_mismatch' } }
    if ($receipt['exit_code'] -ne 0) { return @{ hit = $false; reason = 'cached_failure' } }
    $logs = @{}
    foreach ($stream in @('stdout', 'stderr')) {
        $record = $receipt.receipts[$stream]
        if (-not $record -or -not $record['file']) { return @{ hit = $false; reason = "missing_${stream}_receipt" } }
        $file = Get-TeamChild $CacheDirectory $record.file
        if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { return @{ hit = $false; reason = "missing_${stream}_receipt" } }
        if ((Get-TeamHash $file) -cne $record.sha256 -or (Get-Item -LiteralPath $file).Length -ne [long]$record.bytes) {
            return @{ hit = $false; reason = "tampered_${stream}_receipt" }
        }
        $logs[$stream] = $file
    }
    return @{ hit = $true; reason = $null; receipt = $receipt; path = $path; logs = $logs }
}

function Write-TeamVerificationCache([string]$CacheDirectory, $Binding, [string]$Stdout, [string]$Stderr) {
    if (-not $CacheDirectory -or -not $Binding['key']) { return $null }
    $root = Get-TeamChild $CacheDirectory 'verification-cache/logs'
    [IO.Directory]::CreateDirectory($root) | Out-Null
    $receipts = @{}
    foreach ($stream in @('stdout', 'stderr')) {
        $source = if ($stream -eq 'stdout') { $Stdout } else { $Stderr }
        $target = Join-Path $root "$($Binding.key).$stream"
        # Never overwrite an existing cache body: a partial earlier write must be visible.
        if (Test-Path -LiteralPath $target) { $target = Join-Path $root "$($Binding.key)-$([guid]::NewGuid().ToString('N')).$stream" }
        $temporary = "$target.tmp-$([guid]::NewGuid().ToString('N'))"
        try {
            [IO.File]::Copy($source, $temporary, $false)
            [IO.File]::Move($temporary, $target)
        } finally { if (Test-Path -LiteralPath $temporary) { [IO.File]::Delete($temporary) } }
        $file = Get-Item -LiteralPath $target
        $receipts[$stream] = @{ file = Get-TeamRootRelativePath $CacheDirectory $target; bytes = $file.Length; sha256 = Get-TeamHash $target }
    }
    $receipt = @{ schema_version = 2; key = $Binding.key; material = $Binding.material; exit_code = 0
        receipts = $receipts; created_at = [DateTime]::UtcNow.ToString('o') }
    $receiptPath = Get-TeamVerificationCachePath $CacheDirectory $Binding.key
    if (Test-Path -LiteralPath $receiptPath -PathType Leaf) {
        # Preserve a receipt written by an obsolete version instead of overwriting it; it is
        # never readable as a current hit, but it stays available as evidence.
        $obsolete = Join-Path ([IO.Path]::GetDirectoryName($receiptPath)) "$($Binding.key).obsolete-$([guid]::NewGuid().ToString('N').Substring(0,8)).json"
        try { [IO.File]::Move($receiptPath, $obsolete) } catch { throw "Cannot preserve the obsolete cache receipt: $($_.Exception.Message)" }
    }
    Write-TeamData $receiptPath $receipt
    return $receipt
}
