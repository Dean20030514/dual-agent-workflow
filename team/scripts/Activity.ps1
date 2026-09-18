# Bounded observation of meaningful work activity; no model calls, no retries.
# A stdout-only idle deadline must not kill a worker that is really editing files,
# and must not be refreshed by a timer heartbeat, a live process or an untouched log.
Set-StrictMode -Version Latest

# Runtime, dependency and log loops never count as authored work.
$script:TeamActivityExclusions = @('team/runtime/', '.worktrees/', 'node_modules/', '.git/')
# Per-poll bounds. Content hashing is what makes "touched but unchanged" invisible to
# the idle deadline, so it is bounded per file and in total instead of being skipped.
$script:TeamActivityMaxPaths = 64
$script:TeamActivityHashBytes = 256KB
$script:TeamActivityHashTotalBytes = 4MB
$script:TeamActivityStatusBytes = 4MB

function ConvertFrom-TeamPorcelainZ([string]$Raw) {
    # `git status --porcelain=v1 -z` never C-quotes a path and terminates every field
    # with NUL, so Chinese/quoted/spaced names arrive verbatim. A rename or copy entry
    # is followed by its original path as one more NUL-terminated field.
    $entries = @()
    if (-not $Raw) { return $entries }
    $fields = $Raw -split "`0"
    $index = 0
    while ($index -lt $fields.Count) {
        $field = $fields[$index]; $index++
        if ($field.Length -lt 4) { continue }
        $code = $field.Substring(0, 2); $path = $field.Substring(3)
        $original = $null
        if ($code[0] -eq 'R' -or $code[0] -eq 'C') {
            if ($index -lt $fields.Count) { $original = $fields[$index]; $index++ }
        }
        $entries += @{ code = $code; path = $path; original = $original }
    }
    return $entries
}

function Get-TeamFileContentMark([string]$Path, [long]$ByteLimit) {
    # A file that a worker is writing at this instant must never break the poll: a brief
    # sharing violation is retried, and a persistent one is reported as a mark instead of
    # an exception. Length and hashed prefix length are both bound, so truncation stays visible.
    $entry = $null
    try { $entry = Get-Item -LiteralPath $Path -Force -ErrorAction Stop } catch { return '-' }
    if (-not $entry -or $entry.PSIsContainer) { return '-' }
    if ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) { return ('link/{0}' -f $entry.Length) }
    for ($attempt = 0; $attempt -lt 4; $attempt++) {
        $stream = $null; $hasher = $null
        try {
            $stream = [IO.File]::Open($Path, 'Open', 'Read', ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
            $length = $stream.Length
            $take = [int][Math]::Min($length, $ByteLimit)
            $buffer = [byte[]]::new($take); $read = 0
            while ($read -lt $take) {
                $count = $stream.Read($buffer, $read, $take - $read)
                if ($count -le 0) { break }
                $read += $count
            }
            $hasher = [Security.Cryptography.IncrementalHash]::CreateHash([Security.Cryptography.HashAlgorithmName]::SHA256)
            $hasher.AppendData($buffer, 0, $read)
            return ('{0}/{1}/{2}' -f $length, $read, [Convert]::ToHexString($hasher.GetHashAndReset()).ToLowerInvariant())
        } catch [IO.IOException] {
            if ($attempt -ge 3) { return ('busy/{0}' -f $entry.Length) }
            Start-Sleep -Milliseconds 20
        } catch [UnauthorizedAccessException] {
            if ($attempt -ge 3) { return ('busy/{0}' -f $entry.Length) }
            Start-Sleep -Milliseconds 20
        } finally {
            if ($hasher) { $hasher.Dispose() }
            if ($stream) { $stream.Dispose() }
        }
    }
    return ('busy/{0}' -f $entry.Length)
}

function Get-TeamWorktreeFingerprint([string]$Worktree) {
    if (-not $Worktree -or -not (Test-Path -LiteralPath $Worktree -PathType Container)) { return $null }
    $raw = & git -C $Worktree -c core.quotePath=false status --porcelain=v1 -z --untracked-files=all 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }
    # A path containing a raw newline is the only case where the native pipeline splits.
    # `[string]` does not normalise PowerShell's empty-pipeline value, so assign it explicitly.
    $raw = if ($null -eq $raw) { '' } elseif ($raw -is [array]) { $raw -join "`n" } else { [string]$raw }
    $statusTruncated = $false
    if ($raw.Length -gt $script:TeamActivityStatusBytes) {
        $raw = $raw.Substring(0, $script:TeamActivityStatusBytes); $statusTruncated = $true
    }
    $head = @(& git -C $Worktree rev-parse HEAD 2>$null)
    if ($LASTEXITCODE -ne 0) { return $null }
    $entries = @(foreach ($entry in @(ConvertFrom-TeamPorcelainZ $raw)) {
        $path = [string]$entry.path
        $excluded = $false
        foreach ($prefix in $script:TeamActivityExclusions) {
            if ($path.StartsWith($prefix, [StringComparison]::Ordinal)) { $excluded = $true; break }
        }
        if (-not $excluded) { $entry }
    })
    $lines = @(foreach ($entry in $entries) { '{0}|{1}|{2}' -f $entry.code, $entry.path, $entry.original })
    # Bound the per-poll cost. A huge dirty tree is reported as truncated instead of
    # being read on every tick; the porcelain text still reveals any set change.
    $limited = @($entries | Sort-Object { $_.path })
    $pathTruncated = $limited.Count -gt $script:TeamActivityMaxPaths
    if ($pathTruncated) { $limited = @($limited | Select-Object -First $script:TeamActivityMaxPaths) }
    $budget = [long]$script:TeamActivityHashTotalBytes; $unhashed = 0; $marks = @()
    foreach ($entry in $limited) {
        if ($budget -le 0) {
            $unhashed++
            $marks += ('{0}|{1}|{2}|over-budget' -f $entry.code, $entry.path, $entry.original)
            continue
        }
        $allowance = [Math]::Min([long]$script:TeamActivityHashBytes, $budget)
        $mark = try { Get-TeamFileContentMark (Join-Path $Worktree $entry.path) $allowance } catch { 'error' }
        if ($mark -ne '-' -and $mark -notlike 'link/*' -and $mark -notlike 'busy/*') { $budget -= $allowance }
        $marks += ('{0}|{1}|{2}|{3}' -f $entry.code, $entry.path, $entry.original, $mark)
    }
    $material = (@($head[0]) + $lines + $marks) -join "`n"
    return @{
        head = ([string]$head[0]).Trim(); status = ($lines -join "`n"); marks = ($marks -join "`n")
        changed_files = $entries.Count; hashed_files = $limited.Count - $unhashed; unhashed_files = $unhashed
        truncated = ($statusTruncated -or $pathTruncated)
        material_sha256 = Get-TeamTextHash $material
    }
}

function Get-TeamNativeProcessSet([int]$RootPid, [int]$MaxDepth = 2, [int]$MaxProcesses = 48) {
    if (-not $IsWindows -or $RootPid -le 0) { return @{ supported = $false; pids = @(); truncated = $false; error = $null } }
    $pids = [Collections.Generic.List[int]]::new(); $frontier = @($RootPid); $truncated = $false; $errorText = $null
    for ($depth = 1; $depth -le $MaxDepth -and $frontier.Count; $depth++) {
        $next = @()
        foreach ($parent in $frontier) {
            if ($pids.Count -ge $MaxProcesses) { $truncated = $true; break }
            try { $children = @(Get-CimInstance Win32_Process -Filter "ParentProcessId = $parent" -Property ProcessId -OperationTimeoutSec 1 -ErrorAction Stop) }
            catch { $errorText = $_.Exception.Message; break }
            foreach ($child in $children) {
                if ($pids.Count -ge $MaxProcesses) { $truncated = $true; break }
                $pids.Add([int]$child.ProcessId); $next += [int]$child.ProcessId
            }
        }
        if ($errorText) { break }
        $frontier = $next
    }
    return @{ supported = $true; pids = @($pids | Sort-Object -Unique); truncated = $truncated; error = $errorText }
}

function New-TeamActivityProbe([string]$Worktree, [int]$RootPid, [string]$ReceiptPath, [int]$NativeEveryPolls = 5, [int]$MaxEvents = 20) {
    # A plain state object rather than a closure: a closure created in one scope cannot
    # resolve these helpers when another scope polls it, which would silently disable the
    # observation. The poll is a normal function call in the owning session state.
    return @{
        worktree = $Worktree; root_pid = $RootPid; receipt = $ReceiptPath
        native_every = $NativeEveryPolls; max_events = $MaxEvents
        fingerprint = $null; native = @(); last_kind = $null; last_at = $null; native_at = $null
        polls = 0; receipt_polls = 0; events = @(); error = $null; native_error = $null; native_truncated = $false
        native_supported = [bool]$IsWindows; changed_files = 0; hashed_files = 0; truncated = $false
    }
}

function Get-TeamActivityProbeResult($ActivityProbe) {
    # Accepts the state object and, for callers that still supply their own poll, a scriptblock.
    if (-not $ActivityProbe) { return $null }
    if ($ActivityProbe -is [Collections.IDictionary]) { return Invoke-TeamActivityProbeTick $ActivityProbe }
    return (& $ActivityProbe)
}

function Invoke-TeamActivityProbeTick($State) {
    $State.polls++
    $now = [DateTime]::UtcNow
    $kind = $null
    try {
        $current = Get-TeamWorktreeFingerprint $State.worktree
        if ($current) {
            $State.changed_files = $current.changed_files; $State.hashed_files = $current.hashed_files
            $State.truncated = $current.truncated
            if ($null -eq $State.fingerprint) { $State.fingerprint = $current }
            elseif ($current.material_sha256 -cne $State.fingerprint.material_sha256) {
                $kind = if ($current.head -cne $State.fingerprint.head) { 'head' } else { 'worktree' }
                $State.fingerprint = $current
            }
        }
    } catch { $State.error = $_.Exception.Message }
    if ($State.root_pid -gt 0 -and $State.native_supported -and ($State.polls % $State.native_every) -eq 0) {
        try {
            $set = Get-TeamNativeProcessSet $State.root_pid
            $State.native_supported = [bool]$set.supported
            $State.native_error = $set.error; $State.native_truncated = [bool]$set.truncated
            $joined = (@($set.pids) -join ',')
            if ($joined -cne (@($State.native) -join ',')) {
                # Recorded and reported only. A live or freshly spawned process is not
                # authoring work and never extends an idle deadline by itself.
                $State.native = @($set.pids); $State.native_at = $now.ToString('o')
            }
        } catch { $State.native_error = $_.Exception.Message }
    }
    if ($kind) {
        $State.last_kind = $kind; $State.last_at = $now.ToString('o')
        $State.events = @((@($State.events) + @{ kind = $kind; at = $State.last_at }) | Select-Object -Last $State.max_events)
    }
    $State.receipt_polls++
    if ($State.receipt -and ($kind -or $State.receipt_polls -ge 10)) {
        $State.receipt_polls = 0
        try {
            Write-TeamData $State.receipt @{
                schema_version = 1; observed_at = $now.ToString('o'); polls = $State.polls
                worktree = $State.worktree; last_activity_kind = $State.last_kind; last_activity_at = $State.last_at
                native_activity_at = $State.native_at; native_processes = @($State.native)
                native_supported = $State.native_supported; native_truncated = $State.native_truncated
                changed_files = $State.changed_files; hashed_files = $State.hashed_files
                fingerprint_truncated = $State.truncated
                fingerprint_method = 'git status --porcelain=v1 -z (raw NUL paths) + bounded SHA-256 content marks; size and write time are never used'
                events = @($State.events); error = $State.error; native_error = $State.native_error
            }
        } catch { $State.error = $_.Exception.Message }
    }
    return @{ active = [bool]$kind; kind = $kind; at = $(if ($kind) { $now.ToString('o') } else { $null }); error = $State.error }
}
