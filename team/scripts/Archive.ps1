# Explicit archive/finalize lifecycle. Preview is read-only and is the default; removal
# requires -Apply and a verified archive. Nothing here touches main, unrelated refs or
# unrelated worktrees, and no broad recursive delete is ever used on the repository.
Set-StrictMode -Version Latest

$script:TeamFinalizeMaxFiles = 20000
$script:TeamFinalizeMaxBytes = 512MB

function ConvertFrom-TeamGitPath([string]$Value) {
    $text = $Value.Trim()
    if ($text.Length -ge 2 -and $text.StartsWith('"') -and $text.EndsWith('"')) {
        try { return [string](ConvertFrom-Json $text) } catch { return $text.Trim('"') }
    }
    return $text
}

function Get-TeamWorktreeRegistry([string]$Repo) {
    $entries = @(); $current = $null
    foreach ($line in @((Invoke-TeamGit $Repo @('worktree', 'list', '--porcelain')) -split "`n")) {
        if ($line.StartsWith('worktree ')) {
            if ($current) { $entries += $current }
            $current = @{ path = ConvertFrom-TeamGitPath $line.Substring(9); branch = ''; head = ''; detached = $false; bare = $false; prunable = $false }
        } elseif ($current -and $line.StartsWith('branch ')) { $current.branch = $line.Substring(7).Trim() }
        elseif ($current -and $line.StartsWith('HEAD ')) { $current.head = $line.Substring(5).Trim() }
        elseif ($current -and $line -eq 'detached') { $current.detached = $true }
        elseif ($current -and $line -eq 'bare') { $current.bare = $true }
        elseif ($current -and $line.StartsWith('prunable')) { $current.prunable = $true }
    }
    if ($current) { $entries += $current }
    return @($entries)
}

function Get-TeamRefState([string]$Repo, [string]$Branch) {
    if (-not $Branch) { return @{ exists = $false; sha = $null; ref = $null } }
    $ref = "refs/heads/$Branch"
    $output = & git -C $Repo rev-parse -q --verify $ref 2>$null
    if ($LASTEXITCODE -ne 0) { return @{ exists = $false; sha = $null; ref = $ref } }
    return @{ exists = $true; sha = $output.Trim(); ref = $ref }
}

function Get-TeamWorktreeStateText([string]$Worktree) {
    $lines = @(& git -C $Worktree status --porcelain --untracked-files=all --ignored=matching 2>$null | Where-Object { $_ } | Sort-Object)
    if ($LASTEXITCODE -ne 0) { Stop-TeamError 80 "Cannot read worktree status: $Worktree" }
    return ($lines -join "`n")
}

function Get-TeamFinalizeTargets($State, [string]$Directory) {
    $targets = @()
    $ordered = @($State.order) + @($State.tasks.Keys | Where-Object { $_ -notin @($State.order) })
    foreach ($taskId in $ordered) {
        $item = $State.tasks[$taskId]
        if (-not $item['attempts'] -or -not $item['worktree']) { continue }
        $targets += @{ kind = 'task'; key = "$taskId-a$($item['attempts'])"; task_id = $taskId; attempt = [int]$item.attempts
            path = $item['worktree']; branch = $item['branch']; directory = $item['directory']; base_sha = $item['base_sha']
            expected_head = $(if ($item['commit']) { $item['commit'] } else { $null }); status = $item['status'] }
    }
    if ($State['discarded_tasks']) {
        foreach ($key in @($State.discarded_tasks.Keys)) {
            $item = $State.discarded_tasks[$key]
            if (-not $item['worktree']) { continue }
            $targets += @{ kind = 'discarded'; key = $key; task_id = $item['task_id']; attempt = [int]$item['attempts']
                path = $item['worktree']; branch = $item['branch']; directory = $item['directory']; base_sha = $item['base_sha']
                expected_head = $(if ($item['discard_commit']) { $item['discard_commit'] } else { $null }); status = $item['status'] }
        }
    }
    if ($State['integration_worktree']) {
        $targets += @{ kind = 'integration'; key = 'integration'; task_id = $null; attempt = 0
            path = $State['integration_worktree']; branch = $State['integration_branch']; directory = $null
            base_sha = $State['run_base_sha']; expected_head = $State['last_good_integration_sha']; status = $State['status'] }
    }
    # A recovered attempt and its retired copy share one worktree under two receipt keys.
    # The same verified path/branch/attempt is one target; later aliases are reported only.
    $sorted = @($targets | Sort-Object { "$($_.kind)/$($_.key)" })
    $seen = @{}; $unique = @()
    foreach ($target in $sorted) {
        $identity = "$([IO.Path]::GetFullPath($target.path).TrimEnd('\', '/').ToLowerInvariant())|$($target.branch)|$($target.attempt)"
        if ($seen.ContainsKey($identity)) { $seen[$identity]['aliases'] += @{ kind = $target.kind; key = $target.key }; continue }
        $seen[$identity] = $target
        $target['aliases'] = @()
        $unique += $target
    }
    return @($unique)
}

function Get-TeamFinalizeOwners($State, $Target) {
    # Read ownership from the attempt that recorded it: a retired attempt must never borrow
    # the PID held by whatever task currently shares its ID. A task target also includes any
    # retired copy that still points at the same directory.
    $owners = @()
    if ($Target.kind -eq 'discarded') {
        if ($State['discarded_tasks'] -and $State.discarded_tasks.ContainsKey($Target.key)) { $owners += $State.discarded_tasks[$Target.key] }
        return @($owners)
    }
    if ($Target.kind -ne 'task') { return @() }
    if ($State.tasks.Contains($Target.task_id)) { $owners += $State.tasks[$Target.task_id] }
    if ($State['discarded_tasks'] -and $Target.path) {
        foreach ($key in @($State.discarded_tasks.Keys)) {
            $retired = $State.discarded_tasks[$key]
            if ($retired['worktree'] -and [IO.Path]::GetFullPath([string]$retired['worktree']) -ieq [IO.Path]::GetFullPath([string]$Target.path)) { $owners += $retired }
        }
    }
    return @($owners)
}

function Get-TeamFinalizeOwnership($State, $Target, [string]$Directory = '') {
    $live = @(); $unknown = @(); $unresolved = @()
    foreach ($owner in @(Get-TeamFinalizeOwners $State $Target)) {
        $ownership = Get-TeamOwnedProcessState $owner
        $live += @($ownership.live); $unknown += @($ownership.unknown); $unresolved += @($ownership.unresolved)
    }
    if ($Target.kind -eq 'integration' -and $Directory) {
        # Integration verification and reviews run synchronously under the coordinator. A
        # review attempt that never wrote its exit record leaves quiescence unproven.
        foreach ($file in @(Get-ChildItem -LiteralPath (Join-Path $Directory 'reviews') -Filter 'attempt-*.json' -File -ErrorAction SilentlyContinue)) {
            try { $attempt = Read-TeamData $file.FullName } catch { $unresolved += @{ source = 'review_attempt'; detail = "unreadable $($file.Name)" }; continue }
            if ($attempt['status'] -eq 'started') { $unresolved += @{ source = 'review_attempt'; detail = "$($file.Name) has no durable exit record" } }
        }
    }
    return @{ live = @($live); unknown = @($unknown); unresolved = @($unresolved)
        settled = ((@($live).Count + @($unknown).Count + @($unresolved).Count) -eq 0) }
}

function Get-TeamLiveOwnedProcess($State, $Target, [string]$Directory = '') {
    $ownership = Get-TeamFinalizeOwnership $State $Target $Directory
    if (@($ownership.live).Count) { return @($ownership.live)[0] }
    return $null
}

function Assert-TeamTargetQuiescent($State, $Target, [string]$Directory = '') {
    $ownership = Get-TeamFinalizeOwnership $State $Target $Directory
    if (@($ownership.live).Count) {
        $first = @($ownership.live)[0]
        Stop-TeamError 80 "Run-owned process $($first.pid) ($($first.source)) is still active; wait for its durable receipt before archiving $($Target.key)"
    }
    if (@($ownership.unknown).Count) {
        $first = @($ownership.unknown)[0]
        Stop-TeamError 80 "Run-owned process $($first.pid) ($($first.source)) has no provable start time; quiescence cannot be proven for $($Target.key)"
    }
    if (@($ownership.unresolved).Count) {
        $first = @($ownership.unresolved)[0]
        Stop-TeamError 80 "Run-owned cleanup is unresolved for $($Target.key) ($($first.source): $($first.detail))"
    }
}

function Get-TeamReparseDetails([IO.FileSystemInfo]$Entry) {
    $linkType = [string]$Entry.LinkType
    $target = [string]$Entry.Target
    if (-not $target) {
        try { $target = [IO.Directory]::ResolveLinkTarget($Entry.FullName, $false).FullName } catch { $target = '' }
    }
    $kind = switch ($linkType) {
        'Junction' { 'junction' }
        'SymbolicLink' { $(if ($Entry.PSIsContainer) { 'directory-symlink' } else { 'file-symlink' }) }
        default { $null }
    }
    return @{ kind = $kind; link_type = $linkType; target = $target; supported = ($null -ne $kind) }
}

function Get-TeamWorktreeLooseInventory([string]$Path, [switch]$FilesystemOnly, [switch]$IncludeTracked) {
    # Real pnpm worktrees contain many INTERNAL directory junctions. They are archived as
    # descriptors and never traversed: following one would duplicate content, and an
    # outside target would silently pull unrelated files into the archive. An entry type
    # this finalizer cannot restore is reported and preserved, never quietly deleted.
    $base = [IO.Path]::GetFullPath($Path).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    $entries = @(); $total = 0L; $unsupported = $null
    $pending = [Collections.Generic.Stack[IO.FileSystemInfo]]::new()
    if ($FilesystemOnly -or $IncludeTracked) {
        # An unregistered residue is no longer a usable Git worktree, so Git cannot list its
        # loose/ignored content. The directory itself is walked instead; nothing is followed.
        foreach ($child in @(Get-ChildItem -LiteralPath $Path -Force -ErrorAction Stop)) {
            # Git metadata belongs to the parent repository, never to a restored worktree.
            if ($IncludeTracked -and $child.Name -eq '.git') { continue }
            $pending.Push($child)
        }
    } else {
        $lines = @(& git -C $Path -c core.quotePath=false status --porcelain=v1 -z --untracked-files=all --ignored=matching 2>$null)
        if ($LASTEXITCODE -ne 0) { Stop-TeamError 80 "Cannot read worktree status: $Path" }
        $raw = if ($lines.Count -eq 0) { '' } else { $lines -join "`n" }
        $fields = @($raw -split "`0")
        $index = 0
        while ($index -lt $fields.Count -and -not $unsupported) {
            $field = $fields[$index]; $index++
            if ($field.Length -lt 4) { continue }
            if ($field.Substring(0, 2) -notin @('??', '!!')) { continue }
            $relative = $field.Substring(3)
            $full = [IO.Path]::GetFullPath((Join-Path $Path $relative))
            if (-not $full.StartsWith($base, [StringComparison]::OrdinalIgnoreCase)) { Stop-TeamError 82 "Loose path escapes the run worktree: $relative" }
            $root = Get-Item -LiteralPath $full -Force -ErrorAction SilentlyContinue
            if (-not $root) { continue }
            $pending.Push($root)
        }
    }
    while ($pending.Count -and -not $unsupported) {
        $current = $pending.Pop()
        $currentRelative = Get-TeamRootRelativePath $Path $current.FullName
        if ($current.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            $details = Get-TeamReparseDetails $current
            if (-not $details.supported) { $unsupported = "Unsupported link type '$($details.link_type)' in run worktree: $currentRelative"; break }
            if ($entries.Count -ge $script:TeamFinalizeMaxFiles) { $unsupported = 'Run worktree loose/ignored inventory exceeds the bounded archive limit'; break }
            $targetRelative = $null
            if ($details.target) {
                try { $targetRelative = Get-TeamRootRelativePath $Path $details.target } catch { $targetRelative = $null }
            }
            $entries += @{ path = $currentRelative; kind = 'link'; link_type = $details.kind; target = $details.target
                target_relative = $targetRelative; bytes = 0; sha256 = $null }
            continue
        }
        if ($current.PSIsContainer) {
            foreach ($child in @(Get-ChildItem -LiteralPath $current.FullName -Force -ErrorAction Stop)) { $pending.Push($child) }
            continue
        }
        if ($entries.Count -ge $script:TeamFinalizeMaxFiles -or ($total + $current.Length) -gt $script:TeamFinalizeMaxBytes) {
            $unsupported = 'Run worktree loose/ignored inventory exceeds the bounded archive limit'
            break
        }
        $total += $current.Length
        $entries += @{ path = $currentRelative; kind = 'file'; link_type = $null; target = $null; target_relative = $null
            bytes = $current.Length; sha256 = (Get-TeamHash $current.FullName) }
    }
    $sorted = @($entries | Sort-Object { $_.path })
    return @{ entries = $sorted; bytes = $total
        files = @($sorted | Where-Object { $_.kind -eq 'file' }).Count
        links = @($sorted | Where-Object { $_.kind -eq 'link' }).Count
        bounded = (-not $unsupported); unsupported = $unsupported }
}

function Get-TeamLooseInventoryText($Inventory) {
    return (@(foreach ($entry in @($Inventory.entries)) {
        '{0}|{1}|{2}|{3}|{4}' -f $entry.kind, $entry.path, $entry.link_type, $entry.target, $entry.sha256
    }) -join "`n")
}

function Get-TeamFinalizeInspection($State, $Target, [string]$Directory) {
    $repo = $State.repo
    $worktreesRoot = [IO.Path]::GetFullPath((Get-TeamChild $repo '.worktrees')).TrimEnd('\', '/')
    $path = [IO.Path]::GetFullPath($Target.path)
    if ($Target.path -ine $path) { Stop-TeamError 82 "Recorded worktree path differs from the repository path: $($Target.path)" }
    if ($Target.path -cne $path) { Stop-TeamError 82 "Unsupported path case in the recorded worktree path: $($Target.path)" }
    if ([IO.Path]::GetDirectoryName($path) -ine $worktreesRoot) { Stop-TeamError 82 "Worktree is outside the run worktree root: $path" }
    if (-not ([IO.Path]::GetFileName($path)).StartsWith([string]$State.run_id + '-', [StringComparison]::Ordinal)) {
        Stop-TeamError 82 "Worktree directory name does not belong to this run: $path"
    }
    Assert-TeamTargetQuiescent $State $Target $Directory
    $registry = @(Get-TeamWorktreeRegistry $repo | Where-Object { [IO.Path]::GetFullPath($_.path) -ieq $path })
    $record = @{ kind = $Target.kind; key = $Target.key; task_id = $Target.task_id; attempt = $Target.attempt
        path = $path; branch = $Target.branch; exists = (Test-Path -LiteralPath $path -PathType Container)
        registered = ($registry.Count -eq 1); unregistered_pending = $false; live_process = $null; head = $null
        expected_head = $Target.expected_head; status = $Target.status; tracked_dirty = $false
        entries = @(); loose_files = 0; loose_links = 0; bounded = $true; unsupported = $null; state_text = ''
        residue = $false; origin_proven = $false; aliases = @($Target['aliases'])
        ref = (Get-TeamRefState $repo $Target.branch) }
    if ($registry.Count -gt 1) { Stop-TeamError 82 "Worktree is registered more than once: $path" }
    if (-not $record.exists) {
        if ($record.registered) { Stop-TeamError 80 "Worktree path is missing but still registered; preserve Git state for reconciliation: $path" }
        $record['inventory_sha256'] = Get-TeamTextHash ((@($record.kind, $record.key, $record.path, $record.branch, 'absent', $record.ref.sha) -join "`n"))
        return $record
    }
    if ($registry.Count -eq 1 -and $registry[0].prunable) { Stop-TeamError 82 "Worktree is not a live registered worktree: $path" }
    if (-not $record.registered) {
        # `git worktree remove` unregisters before it deletes files, so a Windows long-path
        # failure, the `cleanup` command or a retired attempt can leave a run-owned directory
        # behind with no registry entry. The directory name and the recorded branch bind it to
        # this run, so it is adopted as explicit residue: inventoried without Git, archived,
        # and only then compared-and-deleted. Its original Git state is never invented.
        $priorPath = Join-Path (Join-Path $Directory "finalize/targets/$($Target.key)") 'receipt.json'
        $prior = if (Test-Path -LiteralPath $priorPath) { Read-TeamData $priorPath } else { $null }
        $record['unregistered_pending'] = $true
        $record['residue'] = $true
        $record['origin_proven'] = [bool]($prior -and $prior['phases'] -and $prior.phases['worktree_unregistered'])
        $inventory = Get-TeamWorktreeLooseInventory $path -FilesystemOnly
        $record['entries'] = $inventory.entries; $record['loose_files'] = $inventory.files; $record['loose_links'] = $inventory.links
        $record['bounded'] = $inventory.bounded; $record['unsupported'] = $inventory.unsupported
        $record['inventory_sha256'] = Get-TeamTextHash ((@($record.kind, $record.key, $record.path, $record.branch,
            'unregistered-pending', (Get-TeamLooseInventoryText $inventory), $record.ref.sha) -join "`n"))
        return $record
    }
    if ($registry[0].branch -cne "refs/heads/$($Target.branch)" -or $registry[0].detached) { Stop-TeamError 80 "Worktree is not on its assigned run branch: $path" }
    if (Test-Path -LiteralPath (Join-Path $path '.gitmodules')) { Stop-TeamError 82 "Submodule worktrees are not supported by this finalizer: $path" }
    $record.head = Invoke-TeamGit $path @('rev-parse', 'HEAD')
    if ($Target.expected_head -and $record.head -cne $Target.expected_head) { Stop-TeamError 80 "Worktree HEAD $($record.head) differs from the recorded run commit $($Target.expected_head)" }
    if ((Invoke-TeamGit $path @('branch', '--show-current')) -cne $Target.branch) { Stop-TeamError 80 "Worktree branch differs from its recorded run branch: $path" }
    $record.state_text = Get-TeamWorktreeStateText $path
    $record.tracked_dirty = [bool](Invoke-TeamGit $path @('status', '--porcelain', '--untracked-files=all'))
    $looseInventory = Get-TeamWorktreeLooseInventory $path
    $inventory = Get-TeamWorktreeLooseInventory $path -IncludeTracked
    $record['entries'] = $inventory.entries; $record['loose_files'] = $looseInventory.files; $record['loose_links'] = $looseInventory.links
    $record['bounded'] = $inventory.bounded; $record['unsupported'] = $inventory.unsupported
    $record['inventory_sha256'] = Get-TeamTextHash ((@($record.kind, $record.key, $record.path, $record.branch, $record.head,
        $record.state_text, (Invoke-TeamGit $path @('ls-files', '--stage', '-z')), (Get-TeamLooseInventoryText $inventory), $record.ref.sha) -join "`n"))
    return $record
}

function Copy-TeamArchiveFile([string]$Source, [string]$TargetRoot, [string]$Relative) {
    $entry = Get-Item -LiteralPath $Source -Force -ErrorAction Stop
    if ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) { Stop-TeamError 82 "Unsafe link in run worktree: $Relative" }
    $targetPath = Get-TeamChild $TargetRoot $Relative
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($targetPath)) | Out-Null
    [IO.File]::Copy($Source, $targetPath, $false)
    $sourceHash = Get-TeamHash $Source
    if ((Get-TeamHash $targetPath) -cne $sourceHash) { Stop-TeamError 80 "Archive copy changed bytes: $Relative" }
    return @{ path = $Relative; bytes = $entry.Length; sha256 = $sourceHash
        archived = Get-TeamRootRelativePath $TargetRoot $targetPath }
}

function Remove-TeamFinalizeTemp([string]$Path) {
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
    $full = [IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
    if (-not $full.StartsWith($tempRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or
        -not ([IO.Path]::GetFileName($full)).StartsWith('team-finalize-', [StringComparison]::Ordinal)) {
        Stop-TeamError 82 "Refusing to remove a path outside the finalize temp root: $Path"
    }
    # Git object files are read-only on Windows; clear the attribute inside our own temp tree only.
    foreach ($entry in @(Get-ChildItem -LiteralPath $full -Recurse -Force -File -ErrorAction SilentlyContinue)) {
        if ($entry.IsReadOnly) { $entry.IsReadOnly = $false }
    }
    [IO.Directory]::Delete($full, $true)
}

function Test-TeamFinalizeRefRestore($Bundle, [string]$ExpectedHead) {
    $temp = Join-Path ([IO.Path]::GetTempPath()) ('team-finalize-' + [guid]::NewGuid().ToString('N'))
    [IO.Directory]::CreateDirectory($temp) | Out-Null
    $proof = @{ method = 'isolated-temp-repo-ref-only'; verified = $false; head = $null; error = $null
        temp_removed = $false; checked_at = [DateTime]::UtcNow.ToString('o') }
    try {
        $clone = Join-Path $temp 'clone'
        $null = Invoke-TeamGit $temp @('clone', '-q', '--no-hardlinks', $Bundle, $clone)
        $null = Invoke-TeamGit $clone @('checkout', '-q', '--detach', '--force', $ExpectedHead)
        $proof.head = Invoke-TeamGit $clone @('rev-parse', 'HEAD')
        if ($proof.head -cne $ExpectedHead) { throw "Bundle head $($proof.head) differs from archived head $ExpectedHead" }
        $proof.verified = $true
    } catch { $proof.error = $_.Exception.Message } finally {
        try { Remove-TeamFinalizeTemp $temp; $proof.temp_removed = $true } catch { $proof['temp_error'] = $_.Exception.Message }
    }
    return $proof
}

function New-TeamRestoredLink($Entry, [string]$Destination, [string]$RestoreRoot) {
    $resolved = [string]$Entry.target
    if ($Entry['target_relative']) { $resolved = Join-Path $RestoreRoot ([string]$Entry.target_relative) }
    if (-not $resolved) { throw "Archived link '$($Entry.path)' has no recorded target" }
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Destination)) | Out-Null
    if ($Entry.link_type -eq 'junction') { $null = New-Item -ItemType Junction -Path $Destination -Target $resolved -ErrorAction Stop }
    else { $null = New-Item -ItemType SymbolicLink -Path $Destination -Target $resolved -ErrorAction Stop }
    $restored = Get-Item -LiteralPath $Destination -Force -ErrorAction Stop
    if (-not ($restored.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "Restored entry is not a link: $($Entry.path)" }
}

function Test-TeamFinalizeRestore($TargetRoot, $Bundle, $Staged, $Unstaged, $InventoryEntries, [string]$ExpectedStateText, [string]$ExpectedHead, [switch]$FilesOnly, $GitConfig = @{}) {
    $temp = Join-Path ([IO.Path]::GetTempPath()) ('team-finalize-' + [guid]::NewGuid().ToString('N'))
    [IO.Directory]::CreateDirectory($temp) | Out-Null
    $proof = @{ method = $(if ($FilesOnly) { 'isolated-temp-tree' } else { 'isolated-temp-repo' }); verified = $false; head = $null; state_matches = $false
        files_checked = 0; links_checked = 0; unsupported = @(); error = $null; temp_removed = $false
        checked_at = [DateTime]::UtcNow.ToString('o') }
    try {
        $clone = Join-Path $temp 'clone'
        if ($FilesOnly) {
            # Residue has no usable Git state; the archived bytes are re-materialized in an
            # isolated temp tree so the restore recipe is proven against the real copies.
            [IO.Directory]::CreateDirectory($clone) | Out-Null
        } else {
            $null = Invoke-TeamGit $temp @('clone', '-q', '--no-hardlinks', $Bundle, $clone)
            foreach ($key in $GitConfig.Keys) { $null = Invoke-TeamGit $clone @('config', '--local', $key, $GitConfig[$key]) }
            # A bundle records refs, not a checkout state: materialize the exact archived commit.
            $null = Invoke-TeamGit $clone @('checkout', '-q', '--detach', '--force', $ExpectedHead)
            $proof.head = Invoke-TeamGit $clone @('rev-parse', 'HEAD')
            if ($proof.head -cne $ExpectedHead) { throw "Bundle head $($proof.head) differs from archived head $ExpectedHead" }
            foreach ($patch in @($Staged, $Unstaged)) {
                if ((Get-Item -LiteralPath $patch).Length -eq 0) { continue }
                $mode = if ($patch -ceq $Staged) { @('apply', '--binary', '--index', $patch) } else { @('apply', '--binary', $patch) }
                $null = Invoke-TeamGit $clone $mode
            }
        }
        $entries = @($InventoryEntries)
        foreach ($file in @($entries | Where-Object { $_.kind -eq 'file' })) {
            $source = Get-TeamChild (Join-Path $TargetRoot 'files') $file.archived
            $destination = Join-Path $clone ([string]$file.path)
            [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination)) | Out-Null
            [IO.File]::Copy($source, $destination, $true)
            if ((Get-TeamHash $destination) -cne $file.sha256) { throw "Restored file hash differs: $($file.path)" }
            $proof.files_checked++
        }
        # A junction may target a directory created by another archived link, so restore
        # links in bounded passes instead of assuming a path order.
        $pending = [Collections.Generic.List[object]]::new()
        foreach ($link in @($entries | Where-Object { $_.kind -eq 'link' })) { $pending.Add($link) }
        $failures = @{}
        for ($pass = 0; $pass -lt 4 -and $pending.Count; $pass++) {
            $remaining = [Collections.Generic.List[object]]::new()
            foreach ($link in $pending) {
                try {
                    New-TeamRestoredLink $link (Join-Path $clone ([string]$link.path)) $clone
                    $proof.links_checked++
                } catch { $failures[[string]$link.path] = $_.Exception.Message; $remaining.Add($link) }
            }
            if ($remaining.Count -eq $pending.Count) { break }
            $pending = $remaining
        }
        foreach ($link in $pending) {
            # Not restorable here: report and preserve instead of deleting the only copy.
            $proof.unsupported += @{ path = [string]$link.path; link_type = [string]$link.link_type
                target = [string]$link.target; error = [string]$failures[[string]$link.path] }
        }
        if ($proof.unsupported.Count) { throw "Unsupported run worktree entries cannot be restored: $(@($proof.unsupported | ForEach-Object { $_.path }) -join ', ')" }
        $restoredState = if ($FilesOnly) { '' } else { Get-TeamWorktreeStateText $clone }
        $proof.state_matches = $FilesOnly -or ($restoredState -ceq $ExpectedStateText)
        if (-not $proof.state_matches) {
            throw "Restored worktree state differs from the archived worktree state: expected [$ExpectedStateText], got [$restoredState]"
        }
        $proof.verified = $true
    } catch { $proof.error = $_.Exception.Message } finally {
        try { Remove-TeamFinalizeTemp $temp; $proof.temp_removed = $true } catch { $proof['temp_error'] = $_.Exception.Message }
    }
    return $proof
}

function Test-TeamFinalizeInventoryComparable($Inspection) {
    # The inventory hash can only be compared while the exact recorded worktree state is
    # still observable: an absent target and a target whose removal already unregistered it
    # have legitimately different inventory text.
    return [bool]($Inspection.exists -and -not $Inspection.unregistered_pending)
}

function New-TeamFinalizePreservedReceipt($Target, $Inspection, [string]$Reason, $Evidence) {
    return @{
        schema_version = 1; key = $Target.key; kind = $Target.kind; task_id = $Target.task_id; attempt = $Target.attempt
        path = $Inspection.path; branch = $Target.branch; branch_head = $Inspection.ref.sha; head = $Inspection.head
        expected_head = $Inspection.expected_head; status = $Inspection.status
        dirty = $Inspection.tracked_dirty; loose_file_count = $Inspection.loose_files; loose_link_count = $Inspection.loose_links
        state_sha256 = $(if ($Inspection.state_text) { Get-TeamTextHash $Inspection.state_text } else { $null })
        inventory_sha256 = $Inspection.inventory_sha256
        evidence = $Evidence; restore_recipe = $null
        restore_proof = @{ method = 'not-attempted'; verified = $false; error = $Reason }
        archived = $false; preserved = $true; preserve_reason = $Reason
        archived_at = [DateTime]::UtcNow.ToString('o')
        phases = @{ worktree_present = $Inspection.exists; worktree_unregistered = [bool]$Inspection.unregistered_pending
            worktree_removed = $false; ref_deleted = $false }
        updated_at = [DateTime]::UtcNow.ToString('o')
    }
}

function Invoke-TeamFinalizeArchive($State, [string]$Directory, $Target, $Inspection) {
    $targetRoot = Get-TeamChild $Directory "finalize/targets/$($Target.key)"
    [IO.Directory]::CreateDirectory($targetRoot) | Out-Null
    $receiptPath = Join-Path $targetRoot 'receipt.json'
    $bundlePath = Join-Path $targetRoot 'branch.bundle'
    $receipt = if (Test-Path -LiteralPath $receiptPath) { Read-TeamData $receiptPath } else { $null }
    if ($receipt -and $receipt['preserved'] -eq $true) {
        if (-not $Inspection.bounded) { return $receipt }
        # A failed preservation attempt is not an accepted archive. Keep all its evidence
        # intact, then retry from the freshly inspected current state after the obstacle clears.
        $historyRoot = Get-TeamChild $Directory 'finalize/preserved'
        $history = Get-TeamChild $historyRoot ($Target.key + '-' + [guid]::NewGuid().ToString('N'))
        $null = Get-TeamRootRelativePath $Directory $targetRoot
        $null = Get-TeamRootRelativePath $Directory $history
        [IO.Directory]::CreateDirectory($historyRoot) | Out-Null
        [IO.Directory]::Move($targetRoot, $history)
        [IO.Directory]::CreateDirectory($targetRoot) | Out-Null
        Add-TeamEvent $Directory 'finalize_preserved_retry' @{ key=$Target.key; previous_archive=(Get-TeamRootRelativePath $Directory $history) }
        $receipt = $null
    }
    if ($receipt -and (Test-TeamFinalizeInventoryComparable $Inspection) -and $receipt['inventory_sha256'] -cne $Inspection.inventory_sha256) {
        Stop-TeamError 80 "Run worktree inventory changed after its archive receipt was written: $($Target.key)"
    }
    # A verified archive is never rebuilt; a resumed finalize continues from it.
    if ($receipt -and $receipt['archived'] -eq $true -and $receipt['restore_proof'] -and $receipt.restore_proof['verified'] -eq $true) {
        return $receipt
    }
    if (-not $Inspection.exists) {
        # The worktree is already gone (for example a completed partial removal). Its branch
        # ref may still hold the only copy of the work, so it must be archived before it is
        # compare-and-deleted; a missing ref simply means this target is already complete.
        $branchHead = $Inspection.ref.sha
        $proof = $null; $evidence = $null
        if ($Inspection.ref.exists) {
            $bundleTemp = Join-Path $targetRoot ('.bundle-' + [guid]::NewGuid().ToString('N'))
            $null = Invoke-TeamGit $State.repo @('bundle', 'create', $bundleTemp, $Inspection.ref.ref)
            $null = Invoke-TeamGit $State.repo @('bundle', 'verify', $bundleTemp)
            if (Test-Path -LiteralPath $bundlePath) { [IO.File]::Delete($bundlePath) }
            [IO.File]::Move($bundleTemp, $bundlePath)
            $evidence = @{ bundle = @{ file = 'branch.bundle'; bytes = (Get-Item -LiteralPath $bundlePath).Length; sha256 = Get-TeamHash $bundlePath
                ref = $Inspection.ref.ref; head = $branchHead; verified = $true } }
            $proof = Test-TeamFinalizeRefRestore $bundlePath $branchHead
            if (-not $proof.verified) { Stop-TeamError 80 "Ref-only archive restore proof failed for $($Target.key): $($proof.error)" }
        }
        $absent = @{
            schema_version = 1; key = $Target.key; kind = $Target.kind; task_id = $Target.task_id; attempt = $Target.attempt
            path = $Inspection.path; branch = $Target.branch; branch_head = $branchHead; head = $null
            expected_head = $Inspection.expected_head; status = $Inspection.status; dirty = $false
            loose_file_count = 0; loose_link_count = 0
            state_sha256 = $null; inventory_sha256 = $Inspection.inventory_sha256
            evidence = $evidence; restore_recipe = $(if ($evidence) { @{ branch = $Target.branch; head = $branchHead; base = $Target.base_sha
                steps = @("git clone --no-hardlinks '$bundlePath' restore-clone", "git -C restore-clone checkout --detach $branchHead") } } else { $null })
            restore_proof = $proof; archived = [bool]$Inspection.ref.exists; preserved = $false
            archived_at = [DateTime]::UtcNow.ToString('o')
            phases = @{ worktree_present = $false; worktree_unregistered = $true
                worktree_removed = (-not $Inspection.registered); ref_deleted = (-not $Inspection.ref.exists) }
            updated_at = [DateTime]::UtcNow.ToString('o')
        }
        Write-TeamData $receiptPath $absent
        if ($Inspection.ref.exists) {
            Add-TeamEvent $Directory 'finalize_ref_archived' @{ key = $Target.key; kind = $Target.kind; ref = $Inspection.ref.ref; head = $branchHead }
        }
        return $absent
    }
    $isResidue = [bool]$Inspection['residue']
    if (-not $Inspection.ref.exists -and -not $isResidue) { Stop-TeamError 80 "Run-owned branch ref is missing while its worktree exists; preserve and reconcile: $($Target.branch)" }
    if (-not $Inspection.bounded) {
        # Explicit preservation. Nothing is removed and no ref is deleted for a target whose
        # loose/ignored inventory this finalizer cannot archive within its bound.
        $preserved = New-TeamFinalizePreservedReceipt $Target $Inspection $Inspection.unsupported $null
        Write-TeamData $receiptPath $preserved
        Add-TeamEvent $Directory 'finalize_target_preserved' @{ key = $Target.key; kind = $Target.kind; reason = $Inspection.unsupported }
        return $preserved
    }
    $bundleEvidence = $null
    if ($Inspection.ref.exists) {
        $bundleTemp = Join-Path $targetRoot ('.bundle-' + [guid]::NewGuid().ToString('N'))
        $null = Invoke-TeamGit $State.repo @('bundle', 'create', $bundleTemp, $Inspection.ref.ref)
        $null = Invoke-TeamGit $State.repo @('bundle', 'verify', $bundleTemp)
        if (Test-Path -LiteralPath $bundlePath) { [IO.File]::Delete($bundlePath) }
        [IO.File]::Move($bundleTemp, $bundlePath)
        $bundleEvidence = @{ file = 'branch.bundle'; bytes = (Get-Item -LiteralPath $bundlePath).Length; sha256 = Get-TeamHash $bundlePath
            ref = $Inspection.ref.ref; head = $Inspection.ref.sha; verified = $true }
    }
    $stagedPath = Join-Path $targetRoot 'staged.patch'
    $unstagedPath = Join-Path $targetRoot 'unstaged.patch'
    $gitConfig = @{}
    if ($isResidue) {
        # The residue is no longer a usable Git worktree: there is no Git state to diff, so
        # only its loose bytes are archived and no original Git state is ever inferred.
        [IO.File]::WriteAllText($stagedPath, '', [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllText($unstagedPath, '', [Text.UTF8Encoding]::new($false))
    } else {
        foreach ($key in @('core.autocrlf', 'core.eol')) {
            $value = & git -C $Inspection.path config --get $key
            if ($LASTEXITCODE -eq 0) { $gitConfig[$key] = [string]$value }
            elseif ($LASTEXITCODE -ne 1) { Stop-TeamError 80 "Cannot read archive checkout setting: $key" }
        }
        # Preserve patch bytes, including CRLF content and trailing whitespace: a line-based
        # shell capture changes the patch and can make staged + unstaged restoration fail.
        $null = Invoke-TeamGit $Inspection.path @('diff', '--cached', '--binary', '--no-color', '--output', $stagedPath)
        $null = Invoke-TeamGit $Inspection.path @('diff', '--binary', '--no-color', '--output', $unstagedPath)
    }
    $filesRoot = Join-Path $targetRoot 'files'
    [IO.Directory]::CreateDirectory($filesRoot) | Out-Null
    # Include tracked bytes so partially removed files can be retired on a later apply.
    $entries = @($Inspection.entries)
    $loose = @(foreach ($entry in @($entries | Where-Object { $_.kind -eq 'file' })) {
        Copy-TeamArchiveFile (Join-Path $Inspection.path ([string]$entry.path)) $filesRoot ([string]$entry.path)
    })
    $links = @(foreach ($entry in @($entries | Where-Object { $_.kind -eq 'link' })) {
        @{ path = [string]$entry.path; link_type = [string]$entry.link_type; target = [string]$entry.target
            target_relative = $(if ($entry['target_relative']) { [string]$entry.target_relative } else { $null }) }
    })
    $evidence = @{
        bundle = $bundleEvidence
        git_config = $gitConfig
        staged = @{ file = 'staged.patch'; bytes = (Get-Item -LiteralPath $stagedPath).Length; sha256 = Get-TeamHash $stagedPath }
        unstaged = @{ file = 'unstaged.patch'; bytes = (Get-Item -LiteralPath $unstagedPath).Length; sha256 = Get-TeamHash $unstagedPath }
        files = @($loose)
        links = @($links)
        residue = @{ adopted = $isResidue; origin_proven = [bool]$Inspection['origin_proven']; git_state_available = (-not $isResidue) }
    }
    $restoreSteps = @()
    if ($bundleEvidence) {
        $restoreSteps += "git clone --no-hardlinks '$bundlePath' restore-clone"
        foreach ($key in $gitConfig.Keys) { $restoreSteps += "git -C restore-clone config --local $key $($gitConfig[$key])" }
        $restoreSteps += "git -C restore-clone checkout --detach --force $($Inspection.head)"
        if (-not $isResidue) { $restoreSteps += @("git -C restore-clone apply --binary --index '$stagedPath'", "git -C restore-clone apply --binary '$unstagedPath'") }
    }
    $restoreSteps += @('copy the archived files/ tree back to its recorded paths',
        'recreate each entry of evidence.links (junction or symbolic link) at its recorded path')
    $restore = @{
        branch = $Target.branch; head = $Inspection.head; base = $Target.base_sha
        steps = $restoreSteps
        patches = @($evidence.staged, $evidence.unstaged); files = @($loose); links = @($links)
    }
    $restoreEntries = @(
        foreach ($file in $loose) { @{ kind = 'file'; path = $file.path; archived = $file.archived; bytes = $file.bytes; sha256 = $file.sha256 } }
        foreach ($link in $links) { @{ kind = 'link'; path = $link.path; link_type = $link.link_type; target = $link.target; target_relative = $link.target_relative } }
    )
    $proof = if ($isResidue) { Test-TeamFinalizeRestore $targetRoot $null $stagedPath $unstagedPath $restoreEntries $Inspection.state_text $null -FilesOnly }
        else { Test-TeamFinalizeRestore $targetRoot $bundlePath $stagedPath $unstagedPath $restoreEntries $Inspection.state_text $Inspection.head -GitConfig $gitConfig }
    if (-not $proof.verified) {
        # The archive exists but restorability is not proven. Preserve the worktree and its
        # ref and report the exact reason; never remove on a failed proof.
        $preserved = New-TeamFinalizePreservedReceipt $Target $Inspection ([string]$proof.error) $evidence
        $preserved['restore_proof'] = $proof
        Write-TeamData $receiptPath $preserved
        Add-TeamEvent $Directory 'finalize_target_preserved' @{ key = $Target.key; kind = $Target.kind; reason = [string]$proof.error }
        return $preserved
    }
    $receipt = @{
        schema_version = 1; key = $Target.key; kind = $Target.kind; task_id = $Target.task_id; attempt = $Target.attempt
        path = $Inspection.path; branch = $Target.branch; branch_head = $Inspection.ref.sha; head = $Inspection.head
        expected_head = $Inspection.expected_head; status = $Inspection.status
        dirty = $Inspection.tracked_dirty; loose_file_count = $Inspection.loose_files; loose_link_count = $Inspection.loose_links
        state_sha256 = Get-TeamTextHash $Inspection.state_text
        inventory_sha256 = $Inspection.inventory_sha256
        evidence = $evidence; restore_recipe = $restore; restore_proof = $proof
        residue = $isResidue; origin_proven = [bool]$Inspection['origin_proven']
        archived = $true; preserved = $false; archived_at = [DateTime]::UtcNow.ToString('o')
        phases = @{ worktree_present = $true; worktree_unregistered = $isResidue; worktree_removed = $false; ref_deleted = $false }
    }
    Write-TeamData $receiptPath $receipt
    Add-TeamEvent $Directory 'finalize_target_archived' @{ key = $Target.key; kind = $Target.kind; head = $Inspection.head
        dirty = $Inspection.tracked_dirty; loose_files = $loose.Count; loose_links = $links.Count
        residue = $isResidue; origin_proven = [bool]$Inspection['origin_proven']
        bundle_sha256 = $(if ($evidence.bundle) { $evidence.bundle.sha256 } else { $null }) }
    return $receipt
}

function Remove-TeamFinalizeResidue([string]$Path, $ArchivedFiles = @(), $ArchivedLinks = @()) {
    # `git worktree remove` unregisters the worktree, deletes its files, and can still leave
    # Windows junctions and their now-empty parents behind. A surviving regular file is
    # deleted only when its bytes still match the archived entry exactly; unrecorded content
    # and unrecorded links are retained and reported, and the walk never descends a link.
    $archived = @{}
    foreach ($file in @($ArchivedFiles)) { if ($file -and $file['path']) { $archived[[string]$file['path']] = $file } }
    $knownLinks = @{}
    foreach ($link in @($ArchivedLinks)) { if ($link -and $link['path']) { $knownLinks[[string]$link['path']] = $true } }
    $links = 0; $blocked = @(); $filesRemoved = 0; $retained = @()
    $pending = [Collections.Generic.Stack[IO.DirectoryInfo]]::new()
    $pending.Push([IO.DirectoryInfo]::new($Path))
    while ($pending.Count) {
        $current = $pending.Pop()
        foreach ($child in @($current.GetFileSystemInfos())) {
            $relative = Get-TeamRootRelativePath $Path $child.FullName
            if ($child.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                if (-not $knownLinks.ContainsKey($relative)) { $retained += $relative; continue }
                try {
                    if ($child -is [IO.DirectoryInfo]) { [IO.Directory]::Delete($child.FullName, $false) } else { [IO.File]::Delete($child.FullName) }
                    $links++
                } catch { $blocked += $child.FullName }
                continue
            }
            if ($child -is [IO.DirectoryInfo]) { $pending.Push($child); continue }
            $entry = $archived[$relative]
            if ($entry -and [long]$entry['bytes'] -eq $child.Length -and (Get-TeamHash $child.FullName) -ceq [string]$entry['sha256']) {
                try { [IO.File]::Delete($child.FullName); $filesRemoved++ } catch { $blocked += $child.FullName }
            } else { $retained += $relative }
        }
    }
    $directories = 0
    if (-not $blocked.Count) {
        for ($pass = 0; $pass -lt 8; $pass++) {
            $emptied = 0
            foreach ($directory in @(Get-ChildItem -LiteralPath $Path -Recurse -Force -Directory -ErrorAction SilentlyContinue |
                Sort-Object { $_.FullName.Length } -Descending)) {
                try { [IO.Directory]::Delete($directory.FullName, $false); $emptied++ } catch { }
            }
            $directories += $emptied
            if ($emptied -eq 0) { break }
        }
    }
    $removed = $false
    try { [IO.Directory]::Delete($Path, $false); $removed = $true } catch { $removed = $false }
    return @{ removed = $removed; links_removed = $links; directories_removed = $directories
        archived_files_removed = $filesRemoved; retained = @($retained); remaining_files = @($retained).Count; blocked = @($blocked) }
}

function Invoke-TeamFinalizeApply($State, [string]$Directory, $Target, $Inspection) {
    # The archive/restore proof can take time; never delete using its earlier inspection.
    $Inspection = Get-TeamFinalizeInspection $State $Target $Directory
    $targetRoot = Get-TeamChild $Directory "finalize/targets/$($Target.key)"
    $receiptPath = Join-Path $targetRoot 'receipt.json'
    $receipt = if (Test-Path -LiteralPath $receiptPath) { Read-TeamData $receiptPath } else { $null }
    $removed = $false; $refDeleted = $false
    $preserved = [bool]($receipt -and $receipt['preserved'])
    if ($receipt -and (Test-TeamFinalizeInventoryComparable $Inspection) -and $receipt['inventory_sha256'] -cne $Inspection.inventory_sha256) {
        Stop-TeamError 80 "Run worktree inventory changed after archive verification; refusing removal: $($Target.key)"
    }
    if ($Inspection.exists -and -not $preserved) {
        if (-not $receipt -or -not $receipt['archived'] -or -not $receipt.restore_proof.verified) {
            Stop-TeamError 80 "Refusing to remove an unarchived or unproven run worktree: $($Target.key)"
        }
        if (-not $Inspection.unregistered_pending) {
            # Long paths are common once a run worktree holds a real dependency tree; the flag
            # is per command so nothing global is changed. Git may still unregister the
            # worktree and then leave content behind, which is why the phases are recorded
            # rather than assumed.
            $arguments = @('-c', 'core.longpaths=true', 'worktree', 'remove')
            # Force is allowed only after a verified archive of the exact dirty/untracked content.
            if ($receipt.dirty -or $receipt.loose_file_count -gt 0 -or $receipt.loose_link_count -gt 0) { $arguments += '--force' }
            $arguments += $Inspection.path
            $removeFailure = $null
            try { $null = Invoke-TeamGit $State.repo $arguments } catch { $removeFailure = $_.Exception.Message }
            $stillRegistered = @(Get-TeamWorktreeRegistry $State.repo | Where-Object { [IO.Path]::GetFullPath($_.path) -ieq $Inspection.path }).Count -ge 1
            if ($stillRegistered) {
                # Nothing was removed; the worktree and its evidence are untouched.
                Stop-TeamError 80 "git worktree remove did not unregister $($Inspection.path); preserve and reconcile: $removeFailure"
            }
            $receipt.phases['worktree_unregistered'] = $true
            $receipt['removal_error'] = $removeFailure
            $receipt['updated_at'] = [DateTime]::UtcNow.ToString('o')
            Write-TeamData $receiptPath $receipt
        }
        if (Test-Path -LiteralPath $Inspection.path) {
            # Removal is deliberately not atomic: unregistration succeeded but a residual
            # tree survived. Clearing it is bounded, reported and safely repeatable; a
            # surviving file is only deleted when it still matches the archived bytes.
            $archivedFiles = @(); $archivedLinks = @()
            if ($receipt['evidence']) { $archivedFiles = @($receipt['evidence']['files']); $archivedLinks = @($receipt['evidence']['links']) }
            $receipt['residue_removal'] = Remove-TeamFinalizeResidue $Inspection.path $archivedFiles $archivedLinks
            $receipt['updated_at'] = [DateTime]::UtcNow.ToString('o')
            Write-TeamData $receiptPath $receipt
        }
        if (Test-Path -LiteralPath $Inspection.path) {
            $receipt.phases['worktree_removed'] = $false
            $receipt['directory_removal_pending'] = $true
            $receipt['updated_at'] = [DateTime]::UtcNow.ToString('o')
            Write-TeamData $receiptPath $receipt
            Add-TeamEvent $Directory 'finalize_directory_removal_pending' @{ key = $Target.key; path = $Inspection.path
                residue = $receipt['residue_removal'] }
        } else {
            $receipt.phases['worktree_removed'] = $true
            $receipt['directory_removal_pending'] = $false
            $removed = $true
            $receipt['updated_at'] = [DateTime]::UtcNow.ToString('o')
            Write-TeamData $receiptPath $receipt
            Add-TeamEvent $Directory 'finalize_worktree_removed' @{ key = $Target.key
                forced = [bool]($receipt.dirty -or $receipt.loose_file_count -gt 0 -or $receipt.loose_link_count -gt 0); path = $Inspection.path }
        }
    }
    if ($Target.branch -and -not $preserved) {
        $ref = Get-TeamRefState $State.repo $Target.branch
        if ($ref.exists) {
            # A run-owned ref is deleted only after an archive that proved restorability.
            if (-not $receipt -or -not $receipt['archived'] -or -not $receipt.restore_proof.verified) {
                Stop-TeamError 80 "Refusing to delete an unarchived or unproven run-owned branch: $($Target.branch)"
            }
            if ($ref.sha -cne $receipt.branch_head) { Stop-TeamError 80 "Run-owned branch moved after archiving; refusing compare-and-delete: $($Target.branch)" }
            $null = Invoke-TeamGit $State.repo @('update-ref', '-d', $ref.ref, $ref.sha)
            if ((Get-TeamRefState $State.repo $Target.branch).exists) { Stop-TeamError 80 "Run-owned branch still exists after compare-and-delete: $($Target.branch)" }
            $refDeleted = $true
            Add-TeamEvent $Directory 'finalize_ref_deleted' @{ key = $Target.key; ref = $ref.ref; sha = $ref.sha }
        }
    }
    $receipt.phases['worktree_removed'] = -not (Test-Path -LiteralPath $Inspection.path)
    $receipt.phases['ref_deleted'] = -not (Get-TeamRefState $State.repo $Target.branch).exists
    $receipt['directory_removal_pending'] = [bool]($Inspection.exists -and -not $preserved -and -not $receipt.phases.worktree_removed)
    $receipt['updated_at'] = [DateTime]::UtcNow.ToString('o')
    Write-TeamData $receiptPath $receipt
    return @{ key = $Target.key; preserved = $preserved
        preserve_reason = $(if ($preserved) { [string]$receipt['preserve_reason'] } else { $null })
        removed_worktree = $removed; deleted_ref = $refDeleted
        worktree_removed = $receipt.phases.worktree_removed; ref_deleted = $receipt.phases.ref_deleted
        directory_removal_pending = $receipt.directory_removal_pending }
}

function Get-TeamFinalizeTargetError($ErrorRecord, $Target, [string]$Path) {
    $code = if ($ErrorRecord.Exception.Data.Contains('TeamExitCode')) { [int]$ErrorRecord.Exception.Data['TeamExitCode'] } else { 90 }
    return @{ key = $Target.key; kind = $Target.kind; task_id = $Target.task_id; attempt = $Target.attempt
        path = $Path; branch = $Target.branch; head = $null; status = $Target.status
        exists = (Test-Path -LiteralPath $Path -PathType Container); registered = $null; unregistered_pending = $null
        dirty = $null; loose_files = $null; loose_links = $null; archivable = $false; unsupported = $ErrorRecord.Exception.Message
        ref_exists = $null; ref_sha = $null; needs_force = $null; inventory_sha256 = $null
        inspection_error = $ErrorRecord.Exception.Message; exit_code = $code }
}

function Invoke-TeamFinalize($State, [string]$Directory, [switch]$Apply) {
    $targets = Get-TeamFinalizeTargets $State $Directory
    $plan = @()
    # One target this finalizer cannot inventory safely must not prevent the others from
    # being inventoried, archived and removed. Every unsupported target is reported in place.
    foreach ($target in $targets) {
        try {
            $inspection = Get-TeamFinalizeInspection $State $target $Directory
            $plan += @{ key = $target.key; kind = $target.kind; task_id = $target.task_id; attempt = $target.attempt
                path = $inspection.path; branch = $target.branch; head = $inspection.head; status = $inspection.status
                exists = $inspection.exists; registered = $inspection.registered; unregistered_pending = $inspection.unregistered_pending
                residue = $inspection['residue']; origin_proven = $inspection['origin_proven']; aliases = @($target['aliases'])
                dirty = $inspection.tracked_dirty; loose_files = $inspection.loose_files; loose_links = $inspection.loose_links
                archivable = $inspection.bounded; unsupported = $inspection.unsupported
                ref_exists = $inspection.ref.exists; ref_sha = $inspection.ref.sha
                needs_force = ($inspection.tracked_dirty -or $inspection.loose_files -gt 0 -or $inspection.loose_links -gt 0)
                inventory_sha256 = $inspection.inventory_sha256; inspection_error = $null; exit_code = $null }
        } catch {
            $plan += Get-TeamFinalizeTargetError $_ $target $target.path
        }
    }
    $unsupportedKeys = @(foreach ($entry in @($plan | Where-Object { $_.inspection_error })) { $entry['key'] })
    if (-not $Apply) {
        return @{ run_id = $State.run_id; status = $State.status; mode = 'preview'
            terminal = ($State.status -in @('COMPLETED', 'CANCELLED', 'FAILED'))
            targets = $plan
            summary = @{ targets = $plan.Count; present = @($plan | Where-Object { $_.exists }).Count
                dirty = @($plan | Where-Object { $_.dirty }).Count
                loose_files = @($plan | Where-Object { $_.loose_files -gt 0 }).Count
                loose_links = @($plan | Where-Object { $_.loose_links -gt 0 }).Count
                unarchivable = @($plan | Where-Object { -not $_.archivable }).Count
                unsupported = $unsupportedKeys.Count
                refs = @($plan | Where-Object { $_.ref_exists }).Count }
            next = 'Preview only. Re-run with -Apply to archive, prove restorability and remove exact run-owned worktrees and refs. Targets that cannot be archived or inventoried are reported in place and preserved, never removed, and never block the safe targets.' }
    }
    if ($State.status -notin @('COMPLETED', 'CANCELLED', 'FAILED')) {
        Stop-TeamError 80 "Refusing to finalize a run that can still be resumed (status $($State.status)); stop or complete it first"
    }
    $owners = @($State.tasks.Values)
    if ($State['discarded_tasks']) { $owners += @($State.discarded_tasks.Values) }
    if (@($owners | Where-Object { $_['cleanup_pending'] }).Count) { Stop-TeamError 80 'Owned process cleanup is pending; retry stop before finalizing' }
    # Live or unprovable run-owned processes are a run-scoped refusal: nothing is archived
    # or removed until quiescence is proven for every target and every attempt alias.
    foreach ($target in $targets) { Assert-TeamTargetQuiescent $State $target $Directory }
    $started = [DateTime]::UtcNow.ToString('o')
    $mainBefore = Invoke-TeamGit $State.repo @('rev-parse', 'HEAD')
    $results = @()
    foreach ($target in $targets) {
        try {
            $inspection = Get-TeamFinalizeInspection $State $target $Directory
            $null = Invoke-TeamFinalizeArchive $State $Directory $target $inspection
            $results += Invoke-TeamFinalizeApply $State $Directory $target $inspection
        } catch {
            $code = if ($_.Exception.Data.Contains('TeamExitCode')) { [int]$_.Exception.Data['TeamExitCode'] } else { 90 }
            $results += @{ key = $target.key; kind = $target.kind; preserved = $false; preserve_reason = $null
                removed_worktree = $false; deleted_ref = $false; worktree_removed = $false; ref_deleted = $false
                directory_removal_pending = (Test-Path -LiteralPath $target.path -PathType Container)
                failed = $true; exit_code = $code; error = $_.Exception.Message }
            Add-TeamEvent $Directory 'finalize_target_failed' @{ key = $target.key; kind = $target.kind; exit_code = $code; message = $_.Exception.Message }
        }
    }
    $mainAfter = Invoke-TeamGit $State.repo @('rev-parse', 'HEAD')
    if ($mainAfter -cne $mainBefore) { Stop-TeamError 80 "Finalize changed the repository HEAD ($mainBefore -> $mainAfter); preserve the repository for reconciliation" }
    # Only a target whose directory is verified gone is marked removed; a preserved or
    # partially removed target keeps its ownership record.
    foreach ($result in @($results | Where-Object { $_['worktree_removed'] })) {
        $target = @($targets | Where-Object { $_.key -eq $result.key })[0]
        if (-not $target) { continue }
        if ($target.kind -eq 'task' -and $State.tasks.Contains($target.task_id)) { $State.tasks[$target.task_id]['worktree_removed'] = $true }
        if ($target.kind -eq 'discarded' -and $State['discarded_tasks']) { $State.discarded_tasks[$target.key]['worktree_removed'] = $true }
    }
    $receiptDirectory = Get-TeamChild $Directory ('finalize/receipts/' + [guid]::NewGuid().ToString('N'))
    [IO.Directory]::CreateDirectory($receiptDirectory) | Out-Null
    Write-TeamData (Join-Path $receiptDirectory 'finalize.json') @{ schema_version = 1; run_id = $State.run_id
        started_at = $started; finished_at = [DateTime]::UtcNow.ToString('o'); results = $results
        main_sha = $mainAfter; integration_preserved = $false; main_preserved = $true; evidence_preserved = $true }
    # Member enumeration on an empty array fails under StrictMode; count explicitly.
    $resultKeys = @(foreach ($entry in $results) { $entry['key'] })
    $removedCount = @($results | Where-Object { $_['worktree_removed'] }).Count
    $refCount = @($results | Where-Object { $_['ref_deleted'] }).Count
    $preservedKeys = @(foreach ($entry in @($results | Where-Object { $_['preserved'] })) { $entry['key'] })
    $failedKeys = @(foreach ($entry in @($results | Where-Object { $_['failed'] })) { $entry['key'] })
    $pendingCount = @($results | Where-Object { $_['directory_removal_pending'] }).Count
    $State['finalized'] = @{ at = [DateTime]::UtcNow.ToString('o'); targets = $resultKeys
        worktrees_removed = $removedCount; refs_deleted = $refCount
        preserved = $preservedKeys; failed = $failedKeys; directory_removal_pending = $pendingCount }
    Save-TeamState $State $Directory
    Add-TeamEvent $Directory 'run_finalized' @{ targets = $resultKeys; summary = $State.finalized }
    return @{ run_id = $State.run_id; status = $State.status; mode = 'apply'
        outcome = $(if ($failedKeys.Count) { 'partial' } else { 'completed' })
        results = $results
        summary = @{ targets = $results.Count; worktrees_removed = $removedCount; refs_deleted = $refCount
            preserved = $preservedKeys.Count; failed = $failedKeys.Count; directory_removal_pending = $pendingCount }
        next = 'Archived evidence and restore recipes are under the run finalize/ directory; run evidence and main are untouched. Removal is not atomic: any target whose directory removal is still pending, preserved or failed is reported and resumed on the next -Apply. Nothing is claimed removed unless its directory is verified gone.' }
}
