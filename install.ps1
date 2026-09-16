# Deploys the dual-agent workflow + Claude Code / Codex / DSH global config to this machine.
# PowerShell 5.1 compatible. ASCII only: this file has no BOM, and 5.1 reads -File scripts
# with the ANSI code page, so non-ASCII characters here would come out as mojibake.
#
# Run from the repo root:
#   powershell -ExecutionPolicy Bypass -File .\install.ps1
#
# Safety model (see README.md -> deployment section):
#   * Default (no parameters) = validate, print the plan, copy what differs, then install
#     the marketplace plugins. Every managed file that differs is backed up next to itself
#     as <name>.bak-<yyyyMMdd-HHmmss>-<guid4> and only then overwritten. A file whose
#     content already matches is not touched at all (no write, no backup).
#   * Live-only content (files the source tree does not have) is reported as [STALE] and
#     left on disk. Removing it takes the explicit -RemoveStale switch, which deletes
#     exactly the rows of that same report - nothing else, never a directory that still
#     holds something, and never with -Recurse. The old mirror-replace semantics are gone,
#     and with them the accident class behind the 2026-09-15 incident, when a probe run
#     deleted 127 local-only files (82 archive/** plus 45 *.bak-*).
#   * -NoPluginInstall skips the plugin step; each plugin is then reported as SKIPPED. A
#     missing claude CLI is not a failure either: the exact commands are printed instead.
#     Plugin installs are NETWORK operations and are run as their own process with a
#     per-install timeout (180s; override with INSTALL_PS1_PLUGIN_TIMEOUT_SEC). Measured
#     2026-09-15: the first install stalled for minutes with no output and no CPU, so a
#     stall is now killed and reported instead of hanging the whole deployment.
#   * -DryRun      prints the exact plan plus one [DIFF] row per file a deploy would write,
#     and changes nothing at all. It deliberately does NOT gate on the pre-flight checks, so
#     a plan that -ValidateOnly would refuse still exits 0 here - read the [CHECK] lines
#     before trusting a plan.
#   * -ValidateOnly performs the pre-flight checks only, and changes nothing at all.
#   * Keep-local-only paths (any "archive" path segment, any *.bak-* path segment) and
#     machine-local paths (credentials, sessions, settings.yaml, ...) are never written,
#     deleted or copied - they are only reported.
#
# Exit codes: 0 = OK (deploy, dry run or validate completed); 1 = FAILED (the pre-flight
# checks refused this plan, a write failed, or a plugin install failed).
#
# Counters: planned = planned actions (plugin actions excluded, they are not file work),
# stale / preserve = the live-only faces of the plan, written / unchanged / backups and
# plugins = what the run actually did. -DryRun reports would-write instead.
#
# Targets (defaults; each root is overridable with -ClaudeDir / -CodexDir / -DshDir):
#   ~/.claude  <- CLAUDE.md, settings.json, rules/, workflow/, commands/
#   ~/.codex   <- AGENTS.md, and config.toml only when it is missing (seed-only)
#   ~/.dsh     <- AGENTS.md, workflow/, skills/* (every bundle found in dsh/skills)
#
# Deliberately NOT done by this script:
#   * no deletion at all unless -RemoveStale is given explicitly: live-only content is
#     reported ([STALE]) and left alone by default;
#   * no whole-tree backup: only the individual files it overwrites are copied, because a
#     tree-wide backup copied credentials and had no rollback value;
#   * no copy of credentials, sessions, storages, profiles or settings files:
#     ~/.claude/settings.local.json, ~/.dsh/settings.yaml, ~/.dsh/.credentials.yaml and
#     ~/.claude/projects/*/memory are never read, written, deleted or copied;
#   * no acknowledgement switch - the old -IUnderstandThisReplacesLiveConfig was removed in
#     slice A, so passing it now fails at binding time (unknown parameter, exit code 1).

[CmdletBinding(DefaultParameterSetName = 'Deploy')]
param(
    [Parameter(ParameterSetName = 'DryRun')]
    [switch]$DryRun,

    [Parameter(ParameterSetName = 'Validate')]
    [switch]$ValidateOnly,

    [Parameter(ParameterSetName = 'Deploy')]
    [Parameter(ParameterSetName = 'DryRun')]
    [Parameter(ParameterSetName = 'Validate')]
    [switch]$NoPluginInstall,

    [Parameter(ParameterSetName = 'Deploy')]
    [Parameter(ParameterSetName = 'DryRun')]
    [Parameter(ParameterSetName = 'Validate')]
    [switch]$RemoveStale,

    [Parameter(ParameterSetName = 'Deploy')]
    [Parameter(ParameterSetName = 'DryRun')]
    [Parameter(ParameterSetName = 'Validate')]
    [string]$ClaudeDir,

    [Parameter(ParameterSetName = 'Deploy')]
    [Parameter(ParameterSetName = 'DryRun')]
    [Parameter(ParameterSetName = 'Validate')]
    [string]$CodexDir,

    [Parameter(ParameterSetName = 'Deploy')]
    [Parameter(ParameterSetName = 'DryRun')]
    [Parameter(ParameterSetName = 'Validate')]
    [string]$DshDir
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0
# Pin this: with it enabled a non-zero exit code from a native command (the plugin step)
# would throw instead of being observable as $LASTEXITCODE - the summary line would be lost.
$PSNativeCommandUseErrorActionPreference = $false

$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

# Plugins are installed from the official marketplace. The list must stay in sync with
# claude/settings.json -> enabledPlugins.
$PluginNames = @(
    'context7',
    'chrome-devtools-mcp',
    'pyright-lsp',
    'typescript-lsp',
    'frontend-design',
    'clangd-lsp'
)
$PluginMarketplace = 'claude-plugins-official'
# Plugin installs are network operations and can stall (measured 2026-09-15: the first
# install sat for minutes with no output and no CPU). Each one is therefore killed after
# this many seconds and reported as a failure. The environment variable exists so the suite
# can exercise the timeout path without waiting three minutes.
$PluginInstallTimeoutSec = 180
if ($env:INSTALL_PS1_PLUGIN_TIMEOUT_SEC -match '^\d+$') { $PluginInstallTimeoutSec = [int]$env:INSTALL_PS1_PLUGIN_TIMEOUT_SEC }

# Paths that only exist on this machine and must stay out of the plan's write/report face:
#   * any path with an "archive" segment (local evidence archives),
#   * any path segment matching *.bak-* (rollback copies written by an older installer).
$KeepLocalOnlyGlobsNote = 'archive segments and *.bak-* names'

# Machine-local surface: never written, never deleted, never copied.
$MachineLocalPaths = @(
    '.claude/settings.local.json',
    '.claude/.credentials.json',
    '.claude.json',
    '.claude/sessions',
    '.claude/projects',
    '.codex/auth.json',
    '.dsh/settings.yaml',
    '.dsh/.credentials.yaml',
    '.dsh/sessions',
    '.dsh/storages',
    '.dsh/profiles'
)

$script:Summary = @{ planned = 0; stale = 0; preserve = 0; written = 0; unchanged = 0; backups = 0; wouldWrite = 0; removedFiles = 0; removedDirs = 0; pluginsInstalled = 0; pluginsSkipped = 0; pluginsManual = 0; pluginsFailed = 0 }

function Write-Line {
    param([AllowEmptyString()][string]$Text = '')
    Write-Host $Text
}

function Get-FullPath {
    param([Parameter(Mandatory)][string]$Path)
    return [System.IO.Path]::GetFullPath($Path)
}

function Test-PathKeepLocalOnly {
    <#
    .SYNOPSIS
    True when a path relative to a managed directory must stay out of the write face.
    .DESCRIPTION
    Matches whole path SEGMENTS only, and the whole subtree below a matching segment:
    "my-archive-notes.md" is NOT keep-local-only, while "archive/x/y.md",
    "old.bak-20260101-000000/note.md" and any "*.bak-*" file name are. The segment test
    matters: a source tree that happens to carry a *.bak-* directory must not turn the
    machine-local files below it into write/report candidates.
    #>
    param([Parameter(Mandatory)][string]$RelativePath)
    foreach ($segment in ($RelativePath -split '[\\/]')) {
        if ($segment -ieq 'archive') { return $true }
        if ($segment -like '*.bak-*') { return $true }
    }
    return $false
}

function Assert-ExplicitRoot {
    <#
    .SYNOPSIS
    Refuses an explicitly passed but empty target root, before any path is resolved.
    .DESCRIPTION
    [string]$ClaudeDir = '' binds fine, and the resolver treats "given but empty" as "not
    given" - it falls back to the real home. With a write path that silently deploys to the
    machine you are sitting on, so an empty explicit root is a hard failure that names the
    parameter. -ClaudeDir $null reaches the same check.
    #>
    param([Parameter(Mandatory)][string]$Name, [AllowEmptyString()][AllowNull()][string]$Value, [Parameter(Mandatory)][bool]$Given)
    if (-not $Given) { return $true }
    if (-not [string]::IsNullOrWhiteSpace($Value)) { return $true }
    Write-Line ('[CHECK]    root:{0} FAIL given explicitly but empty - refusing to fall back to the real home' -f $Name)
    return $false
}

function Test-StringInList {
    <#
    .SYNOPSIS
    Case-insensitive membership test for relative paths.
    .DESCRIPTION
    The plan compares SOURCE-side file lists with TARGET-side enumeration results, and this
    filesystem does not preserve case. A raw -contains would call a file "live-only" merely
    because someone renamed its case, which shows up as a phantom [STALE] row.
    #>
    param([Parameter(Mandatory)][string]$Value, [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$List)
    foreach ($item in $List) { if ($item -ieq $Value) { return $true } }
    return $false
}

function Resolve-TargetDirectory {
    param([string]$Explicit, [Parameter(Mandatory)][string]$LeafName)
    if ($Explicit) { return (Get-FullPath -Path $Explicit) }
    return (Get-FullPath -Path (Join-Path $env:USERPROFILE $LeafName))
}

function New-FileAction {
    param([Parameter(Mandatory)][string]$Source, [Parameter(Mandatory)][string]$Target, [string]$Kind = 'copy')
    return [pscustomobject]@{ Kind = $Kind; Source = $Source; Target = $Target; Files = @(); Dirs = @() }
}

function New-MirrorAction {
    param([Parameter(Mandatory)][string]$Source, [Parameter(Mandatory)][string]$Target)
    $files = @()
    $dirs = @()
    if (Test-Path -LiteralPath $Source) {
        foreach ($f in Get-ChildItem -LiteralPath $Source -File -Recurse -Force) {
            $files += $f.FullName.Substring($Source.Length + 1)
        }
        foreach ($d in Get-ChildItem -LiteralPath $Source -Directory -Recurse -Force) {
            $dirs += $d.FullName.Substring($Source.Length + 1)
        }
    }
    return [pscustomobject]@{ Kind = 'mirror'; Source = $Source; Target = $Target; Files = $files; Dirs = $dirs }
}

function New-PluginAction {
    param([Parameter(Mandatory)][string]$Name)
    return [pscustomobject]@{ Kind = 'plugin'; Source = ''; Target = $Name; Files = @(); Dirs = @() }
}

function Build-Plan {
    param(
        [Parameter(Mandatory)][string]$ClaudeRoot,
        [Parameter(Mandatory)][string]$CodexRoot,
        [Parameter(Mandatory)][string]$DshRoot
    )
    $plan = New-Object System.Collections.Generic.List[object]
    foreach ($f in 'CLAUDE.md', 'settings.json') {
        $plan.Add((New-FileAction -Source (Join-Path $RepoRoot "claude\$f") -Target (Join-Path $ClaudeRoot $f)))
    }
    foreach ($d in 'rules', 'workflow', 'commands') {
        $plan.Add((New-MirrorAction -Source (Join-Path $RepoRoot "claude\$d") -Target (Join-Path $ClaudeRoot $d)))
    }
    $plan.Add((New-FileAction -Source (Join-Path $RepoRoot 'codex\AGENTS.md') -Target (Join-Path $CodexRoot 'AGENTS.md')))
    $plan.Add((New-FileAction -Source (Join-Path $RepoRoot 'codex\config.example.toml') -Target (Join-Path $CodexRoot 'config.toml') -Kind 'seed'))
    $plan.Add((New-FileAction -Source (Join-Path $RepoRoot 'dsh\AGENTS.md') -Target (Join-Path $DshRoot 'AGENTS.md')))
    $plan.Add((New-MirrorAction -Source (Join-Path $RepoRoot 'dsh\workflow') -Target (Join-Path $DshRoot 'workflow')))
    # Enumerated, not hard-coded: a bundle ships by existing under dsh/skills/. A list kept
    # here would silently ignore a third bundle while the test oracle, which used to keep
    # the same list, agreed with it (registered as a debt; repaid 2026-09-15).
    foreach ($skillDir in (Get-ChildItem -LiteralPath (Join-Path $RepoRoot 'dsh\skills') -Directory)) {
        $plan.Add((New-MirrorAction -Source $skillDir.FullName -Target (Join-Path $DshRoot ('skills\' + $skillDir.Name))))
    }
    # Always planned: with -NoPluginInstall each one is reported as SKIPPED, so the
    # deployment summary states what was suppressed instead of staying silent.
    foreach ($p in $PluginNames) { $plan.Add((New-PluginAction -Name $p)) }
    return $plan
}

function Get-MirrorDelta {
    <#
    .SYNOPSIS
    Splits the live-only content of a managed directory into stale / preserve.
    .DESCRIPTION
    Stale means "the source tree does not have it". This build never deletes, so a stale
    row is a report, not work for the executor. Keeping the split exact still matters: a
    directory that holds keep-local-only content, and a stale file that lives inside a
    keep-local-only directory, must both come out as preserved - otherwise the plan points
    the reader at machine-local files the installer may not touch.
    #>
    param([Parameter(Mandatory)]$Action)
    $staleFiles = @()
    $preserveFiles = @()
    $staleDirs = @()
    $preserveDirs = @()
    # Only a real directory can hold live-only content. A target that exists as a FILE has
    # none, and enumerating it would return the file itself, whose relative-path Substring
    # throws and takes the whole run down before any check can name the shape failure.
    if ((Test-Path -LiteralPath $Action.Target) -and (Get-Item -LiteralPath $Action.Target -Force).PSIsContainer) {
        foreach ($f in Get-ChildItem -LiteralPath $Action.Target -File -Recurse -Force) {
            $rel = $f.FullName.Substring($Action.Target.Length + 1)
            if (Test-StringInList -Value $rel -List $Action.Files) { continue }
            if (Test-PathKeepLocalOnly -RelativePath $rel) { $preserveFiles += $rel } else { $staleFiles += $rel }
        }
        $liveOnlyDirs = @()
        foreach ($d in Get-ChildItem -LiteralPath $Action.Target -Directory -Recurse -Force) {
            $rel = $d.FullName.Substring($Action.Target.Length + 1)
            if (Test-StringInList -Value $rel -List $Action.Dirs) { continue }
            $liveOnlyDirs += $rel
            if (Test-PathKeepLocalOnly -RelativePath $rel) { $preserveDirs += $rel }
        }
        foreach ($rel in $liveOnlyDirs) {
            if ($preserveDirs -contains $rel) { continue }
            $holdsPreserved = $false
            foreach ($p in $preserveFiles) {
                if ($p.StartsWith($rel + '\', [System.StringComparison]::OrdinalIgnoreCase)) { $holdsPreserved = $true; break }
            }
            if (-not $holdsPreserved) {
                foreach ($p in $preserveDirs) {
                    if ($p.StartsWith($rel + '\', [System.StringComparison]::OrdinalIgnoreCase)) { $holdsPreserved = $true; break }
                }
            }
            if ($holdsPreserved) { $preserveDirs += $rel } else { $staleDirs += $rel }
        }
    }
    # The whitelist is subtree-inheriting (human ruling, 2026-09-15): a preserved directory
    # keeps everything below it. Without this pass a *.bak-* or archive DIRECTORY would be
    # reported as preserved while the live-only files inside it were still listed as
    # [STALE] - the same plan would both keep and report the same subtree.
    if (@($preserveDirs).Count -gt 0 -and @($staleFiles).Count -gt 0) {
        $stillStale = @()
        foreach ($f in $staleFiles) {
            $insidePreservedDir = $false
            foreach ($pd in $preserveDirs) {
                if ($f.StartsWith($pd + '\', [System.StringComparison]::OrdinalIgnoreCase)) { $insidePreservedDir = $true; break }
            }
            if ($insidePreservedDir) { $preserveFiles += $f } else { $stillStale += $f }
        }
        $staleFiles = $stillStale
    }
    return [pscustomobject]@{
        StaleFiles    = @($staleFiles)
        PreserveFiles = @($preserveFiles)
        StaleDirs     = @($staleDirs)
        PreserveDirs  = @($preserveDirs)
    }
}

function Get-MachineLocalReport {
    <#
    .SYNOPSIS
    Maps the machine-local inventory onto the EFFECTIVE target roots.
    .DESCRIPTION
    Reporting the real home here would be wrong (and misleading) whenever the
    caller passes -ClaudeDir / -CodexDir / -DshDir: the report must describe
    the roots this run would actually use.
    #>
    param(
        [Parameter(Mandatory)][string]$ClaudeRoot,
        [Parameter(Mandatory)][string]$CodexRoot,
        [Parameter(Mandatory)][string]$DshRoot,
        [Parameter(Mandatory)][string]$HomeRoot
    )
    $report = New-Object System.Collections.Generic.List[string]
    foreach ($m in $MachineLocalPaths) {
        $parts = $m -split '[\\/]'
        if ($parts[0] -eq '.claude' -and $parts.Count -gt 1) {
            $rest = $parts[1..($parts.Count - 1)] -join '\'
            $report.Add((Join-Path $ClaudeRoot $rest))
        } elseif ($parts[0] -eq '.codex' -and $parts.Count -gt 1) {
            $rest = $parts[1..($parts.Count - 1)] -join '\'
            $report.Add((Join-Path $CodexRoot $rest))
        } elseif ($parts[0] -eq '.dsh' -and $parts.Count -gt 1) {
            $rest = $parts[1..($parts.Count - 1)] -join '\'
            $report.Add((Join-Path $DshRoot $rest))
        } else {
            $report.Add((Join-Path $HomeRoot $m))
        }
    }
    return $report
}

function Get-PlanCounters {
    <#
    .SYNOPSIS
    Summary counters for a plan; identical in every mode.
    .DESCRIPTION
    Counted from the same Get-MirrorDelta call that Show-Plan prints its rows from, so the
    summary can never disagree with the [STALE] / [PRESERVE] rows of the same run. It is
    computed once, before the mode branches, because -ValidateOnly never calls Show-Plan.
    #>
    param([Parameter(Mandatory)]$Plan)
    $planned = 0
    $stale = 0
    $preserve = 0
    foreach ($a in $Plan) {
        if ($a.Kind -eq 'plugin') { continue }
        $planned++
        if ($a.Kind -ne 'mirror') { continue }
        $delta = Get-MirrorDelta -Action $a
        $stale += @($delta.StaleFiles).Count + @($delta.StaleDirs).Count
        $preserve += @($delta.PreserveFiles).Count + @($delta.PreserveDirs).Count
    }
    return [pscustomobject]@{ Planned = $planned; Stale = $stale; Preserve = $preserve }
}

function Show-Plan {
    param([Parameter(Mandatory)]$Plan, [Parameter(Mandatory)][string[]]$MachineLocalReport)
    foreach ($a in $Plan) {
        switch ($a.Kind) {
            'copy' { Write-Line ('[PLAN]     copy  {0} -> {1}' -f $a.Source, $a.Target) }
            'seed' {
                if (Test-Path -LiteralPath $a.Target) {
                    Write-Line ('[PLAN]     keep  {0} (seed-only, already present)' -f $a.Target)
                } else {
                    Write-Line ('[PLAN]     seed  {0} -> {1}' -f $a.Source, $a.Target)
                }
            }
            'mirror' {
                $delta = Get-MirrorDelta -Action $a
                Write-Line ('[PLAN]     mirror {0} -> {1} ({2} files)' -f $a.Source, $a.Target, $a.Files.Count)
                foreach ($f in $delta.StaleFiles) { Write-Line ('[STALE]    ' + (Join-Path $a.Target $f)) }
                foreach ($d in $delta.StaleDirs) { Write-Line ('[STALE]    ' + (Join-Path $a.Target $d) + ' (dir)') }
                foreach ($f in $delta.PreserveFiles) { Write-Line ('[PRESERVE] ' + (Join-Path $a.Target $f)) }
                foreach ($d in $delta.PreserveDirs) { Write-Line ('[PRESERVE] ' + (Join-Path $a.Target $d) + ' (dir)') }
            }
            'plugin' {
                if ($NoPluginInstall) {
                    Write-Line ('[PLAN]     plugin {0}@{1} (SKIPPED by -NoPluginInstall)' -f $a.Target, $PluginMarketplace)
                } else {
                    Write-Line ('[PLAN]     plugin {0}@{1}' -f $a.Target, $PluginMarketplace)
                }
            }
        }
    }
    Write-Line ('[PLAN]     keep-local-only: ' + $KeepLocalOnlyGlobsNote)
    Write-Line '[PLAN]     stale rows are reported only; pass -RemoveStale to delete them'
    foreach ($m in $MachineLocalReport) { Write-Line ('[PRESERVE] ' + $m + ' (machine-local, never touched)') }
}

function Test-Plan {
    <#
    .SYNOPSIS
    Pre-flight checks for a plan; returns $true when every check passed.
    .DESCRIPTION
    This is the single validation predicate: -ValidateOnly prints its result and
    the real deploy runs it before touching anything, so a refused plan is
    refused on both paths.
    #>
    param([Parameter(Mandatory)]$Plan, [Parameter(Mandatory)]$RootSpecs)
    $ok = $true
    function Report {
        param([bool]$Passed, [string]$Name, [string]$Detail)
        $state = 'OK'
        if (-not $Passed) { $state = 'FAIL' }
        Write-Line ('[CHECK]    {0} {1} {2}' -f $Name, $state, $Detail)
    }

    foreach ($a in $Plan) {
        if ($a.Kind -eq 'plugin') { continue }
        if (-not (Test-Path -LiteralPath $a.Source)) {
            Report $false ('source:' + $a.Source) 'source is missing'
            $ok = $false
            continue
        }
        if ($a.Kind -eq 'mirror') {
            $count = @(Get-ChildItem -LiteralPath $a.Source -File -Recurse -Force).Count
            if ($count -eq 0) {
                Report $false ('source:' + $a.Source) 'mirrored source has no files'
                $ok = $false
            } else {
                Report $true ('source:' + $a.Source) ('{0} files' -f $count)
            }
        } else {
            if ((Get-Item -LiteralPath $a.Source).Length -eq 0) {
                Report $false ('source:' + $a.Source) 'source file is empty'
                $ok = $false
            } else {
                Report $true ('source:' + $a.Source) 'present'
            }
        }
    }

    # Target shape: a directory target must not exist as a file, and the other way round.
    foreach ($a in $Plan) {
        if ($a.Kind -eq 'plugin') { continue }
        if (Test-Path -LiteralPath $a.Target) {
            $item = Get-Item -LiteralPath $a.Target -Force
            $wantsDirectory = ($a.Kind -eq 'mirror')
            if ($wantsDirectory -and (-not $item.PSIsContainer)) {
                Report $false ('target:' + $a.Target) 'target exists as a file but a directory is required'
                $ok = $false
            } elseif ((-not $wantsDirectory) -and $item.PSIsContainer) {
                Report $false ('target:' + $a.Target) 'target exists as a directory but a file is required'
                $ok = $false
            } else {
                Report $true ('target:' + $a.Target) 'shape ok'
            }
        } else {
            Report $true ('target:' + $a.Target) 'does not exist yet (will be created)'
        }
    }

    # Roots must be usable as directories: either absent, or an existing directory.
    $rootProblems = @()
    foreach ($spec in $RootSpecs) {
        $root = $spec.Path
        if (Test-Path -LiteralPath $root) {
            if (-not (Get-Item -LiteralPath $root -Force).PSIsContainer) {
                $rootProblems += ('{0} ({1}) exists as a file' -f $spec.Name, $root)
            }
        } else {
            $ancestor = Split-Path -Parent $root
            while ($ancestor -and (-not (Test-Path -LiteralPath $ancestor))) { $ancestor = Split-Path -Parent $ancestor }
            if ($ancestor -and (Test-Path -LiteralPath $ancestor) -and (-not (Get-Item -LiteralPath $ancestor -Force).PSIsContainer)) {
                $rootProblems += ('{0} ({1}) cannot be created: {2} is a file' -f $spec.Name, $root, $ancestor)
            }
        }
    }
    if ($rootProblems.Count -gt 0) {
        Report $false 'target-roots' ($rootProblems -join '; ')
        $ok = $false
    } else {
        Report $true 'target-roots' 'usable as directories'
    }

    # Roots must not collide with each other (the message names the parameters).
    $collision = $false
    for ($i = 0; $i -lt $RootSpecs.Count; $i++) {
        for ($j = $i + 1; $j -lt $RootSpecs.Count; $j++) {
            if ($RootSpecs[$i].Path -ieq $RootSpecs[$j].Path) {
                Report $false 'roots' ('{0} and {1} point at the same directory: {2}' -f $RootSpecs[$i].Name, $RootSpecs[$j].Name, $RootSpecs[$i].Path)
                $collision = $true
                $ok = $false
            }
        }
    }
    if (-not $collision) { Report $true 'roots' 'three distinct target roots' }

    # No action may write inside the source tree (the repository itself).
    $insideSource = @()
    foreach ($a in $Plan) {
        if ($a.Kind -eq 'plugin') { continue }
        if (Test-PathInside -Child $a.Target -Parent $RepoRoot) { $insideSource += $a.Target }
    }
    if ($insideSource.Count -gt 0) {
        Report $false 'target-inside-source-tree' ($insideSource -join ', ')
        $ok = $false
    } else {
        Report $true 'target-inside-source-tree' 'no target is inside the source tree'
    }

    # No action may write inside the machine-local surface.
    $insideMachineLocal = @()
    foreach ($a in $Plan) {
        if ($a.Kind -eq 'plugin') { continue }
        foreach ($m in $MachineLocalPaths) {
            $mFull = Get-FullPath -Path (Join-Path $env:USERPROFILE $m)
            if (Test-PathInside -Child $a.Target -Parent $mFull) {
                if ($a.Kind -eq 'seed') { continue }
                $insideMachineLocal += $a.Target
            }
        }
    }
    if ($insideMachineLocal.Count -gt 0) {
        Report $false 'machine-local-untouched' ($insideMachineLocal -join ', ')
        $ok = $false
    } else {
        Report $true 'machine-local-untouched' 'no action targets a machine-local path'
    }

    if (-not $NoPluginInstall) {
        $cliPath = Get-PluginCliPath
        if ($cliPath) {
            Report $true 'plugin-cli' ('found: ' + $cliPath + ' (timeout ' + $PluginInstallTimeoutSec + 's per install)')
        } else {
            Report $true 'plugin-cli' 'claude CLI not on PATH; the plugin step will print the commands to run by hand'
        }
    } else {
        Report $true 'plugin-cli' 'skipped by -NoPluginInstall'
    }
    return $ok
}

function Test-PathInside {
    param([Parameter(Mandatory)][string]$Child, [Parameter(Mandatory)][string]$Parent)
    $c = (Get-FullPath -Path $Child).TrimEnd('\')
    $p = (Get-FullPath -Path $Parent).TrimEnd('\')
    if ($c -ieq $p) { return $true }
    return $c.StartsWith($p + '\', [System.StringComparison]::OrdinalIgnoreCase)
}

function Backup-FileIfExists {
    <#
    .SYNOPSIS
    Copies an existing file next to itself and returns the backup path ('' when absent).
    .DESCRIPTION
    The backup is a sibling named <name>.bak-<stamp>-<guid4>, so it never lands inside a
    managed directory it would then be copied back from. The guid is what keeps two runs
    in the same second apart: measured, a fixed name makes the second copy nest itself
    inside the first one instead of failing.
    #>
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Stamp)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return '' }
    $leaf = Split-Path -Leaf $Path
    $backup = Join-Path (Split-Path -Parent $Path) ('{0}.bak-{1}-{2}' -f $leaf, $Stamp, [guid]::NewGuid().ToString('N').Substring(0, 4))
    Copy-Item -LiteralPath $Path -Destination $backup -Force
    return $backup
}

function Get-ManagedFilePairs {
    <#
    .SYNOPSIS
    Expands a plan into the (Source, Target) file pairs a deploy touches.
    .DESCRIPTION
    One place decides what "the managed file set" is, so the -DryRun preview and the real
    deploy can never disagree about which files are in scope. Seed pairs carry SeedOnly so
    the writer knows an existing target must be left alone instead of overwritten.
    #>
    param([Parameter(Mandatory)]$Plan)
    $pairs = New-Object System.Collections.Generic.List[object]
    foreach ($a in $Plan) {
        switch ($a.Kind) {
            'copy' { $pairs.Add([pscustomobject]@{ Source = $a.Source; Target = $a.Target; SeedOnly = $false }) }
            'seed' { $pairs.Add([pscustomobject]@{ Source = $a.Source; Target = $a.Target; SeedOnly = $true }) }
            'mirror' {
                foreach ($rel in $a.Files) {
                    $pairs.Add([pscustomobject]@{ Source = (Join-Path $a.Source $rel); Target = (Join-Path $a.Target $rel); SeedOnly = $false })
                }
            }
            'plugin' { }
        }
    }
    return $pairs
}

function Test-ManagedFileMatches {
    <#
    .SYNOPSIS
    True when the target exists and already holds exactly the source content.
    .DESCRIPTION
    A missing source is NOT "different": the pre-flight checks report it, and the preview
    must not try to hash a file that is not there.
    #>
    param([Parameter(Mandatory)][string]$Source, [Parameter(Mandatory)][string]$Target)
    if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) { return $false }
    if (-not (Test-Path -LiteralPath $Target -PathType Leaf)) { return $false }
    return ((Get-FileHash -LiteralPath $Source -Algorithm SHA256).Hash -eq (Get-FileHash -LiteralPath $Target -Algorithm SHA256).Hash)
}

function Show-WritePreview {
    <#
    .SYNOPSIS
    -DryRun face of the writer: one [DIFF] row per managed file that differs, plus counts.
    .DESCRIPTION
    Uses the same pair expansion as the deploy, so "what the preview lists" and "what a
    deploy would write" are the same set by construction, not by two matching code paths.
    #>
    param([Parameter(Mandatory)]$Plan)
    $wouldWrite = 0
    $unchanged = 0
    foreach ($p in (Get-ManagedFilePairs -Plan $Plan)) {
        # A source that is not there cannot be written; Test-Plan names it separately.
        if (-not (Test-Path -LiteralPath $p.Source -PathType Leaf)) { continue }
        if ($p.SeedOnly -and (Test-Path -LiteralPath $p.Target)) { $unchanged++; continue }
        if (Test-ManagedFileMatches -Source $p.Source -Target $p.Target) { $unchanged++; continue }
        Write-Line ('[DIFF]     ' + $p.Target)
        $wouldWrite++
    }
    $script:Summary.wouldWrite = $wouldWrite
    $script:Summary.unchanged = $unchanged
}

function Copy-ManagedFile {
    <#
    .SYNOPSIS
    Writes one managed file when its content differs; backs the old content up first.
    .DESCRIPTION
    A target whose SHA-256 already matches the source is left completely alone - no write,
    no backup - which keeps a second run of the same version a no-op. Every overwrite is
    preceded by a sibling backup, so any single file can be put back by hand. A SeedOnly
    pair whose target exists is never overwritten at all.
    #>
    param([Parameter(Mandatory)][string]$Source, [Parameter(Mandatory)][string]$Target, [Parameter(Mandatory)][string]$Stamp, [switch]$SeedOnly)
    if ($SeedOnly -and (Test-Path -LiteralPath $Target)) {
        Write-Line ('[SKIP]     {0} (seed-only, already present)' -f $Target)
        $script:Summary.unchanged++
        return
    }
    if (Test-ManagedFileMatches -Source $Source -Target $Target) {
        $script:Summary.unchanged++
        return
    }
    $parent = Split-Path -Parent $Target
    if ($parent -and (-not (Test-Path -LiteralPath $parent))) { New-Item -ItemType Directory -Force $parent | Out-Null }
    if (Test-Path -LiteralPath $Target) {
        $backup = Backup-FileIfExists -Path $Target -Stamp $Stamp
        if ($backup) {
            Write-Line ('[BACKUP]   {0} -> {1}' -f $Target, $backup)
            $script:Summary.backups++
        }
    }
    Copy-Item -LiteralPath $Source -Destination $Target -Force
    $script:Summary.written++
    Write-Line ('[WRITE]    ' + $Target)
}

function Invoke-ManagedDeploy {
    <#
    .SYNOPSIS
    Executes a plan by copying: every managed file is updated in place. Nothing is deleted.
    .DESCRIPTION
    Target files the source tree does not have are never touched here - they were reported
    as [STALE] rows, and removing them happens only through the explicit -RemoveStale path.
    #>
    param([Parameter(Mandatory)]$Plan, [Parameter(Mandatory)][string]$Stamp)
    foreach ($p in (Get-ManagedFilePairs -Plan $Plan)) {
        Copy-ManagedFile -Source $p.Source -Target $p.Target -Stamp $Stamp -SeedOnly:$p.SeedOnly
    }
}

function Remove-StaleContent {
    <#
    .SYNOPSIS
    Deletes exactly the paths the same run reported as [STALE]; reachable only via -RemoveStale.
    .DESCRIPTION
    The set comes from the same Get-MirrorDelta rows the plan printed, so keep-local-only and
    machine-local paths cannot appear here. Files go first, then directories deepest-first,
    and a directory is removed only when it is already empty: there is deliberately no
    recursive delete anywhere in this file (measured: Remove-Item -Recurse swallows
    whitelisted subtrees, which is how the 2026-09-15 incident deleted 127 local-only files).
    #>
    param([Parameter(Mandatory)]$Plan)
    foreach ($a in $Plan) {
        if ($a.Kind -ne 'mirror') { continue }
        $delta = Get-MirrorDelta -Action $a
        foreach ($f in @($delta.StaleFiles)) {
            $full = Join-Path $a.Target $f
            Remove-Item -LiteralPath $full -Force
            Write-Line ('[REMOVED]  ' + $full)
            $script:Summary.removedFiles++
        }
        $dirs = @($delta.StaleDirs) | Sort-Object -Property @{ Expression = { ($_.ToString() -split '[\\/]').Count } } -Descending
        foreach ($d in $dirs) {
            $full = Join-Path $a.Target $d
            if (-not (Test-Path -LiteralPath $full)) { continue }
            if (@(Get-ChildItem -LiteralPath $full -Force).Count -gt 0) {
                Write-Line ('[REMOVED]  {0} SKIPPED (not empty)' -f $full)
                continue
            }
            Remove-Item -LiteralPath $full -Force
            Write-Line ('[REMOVED]  ' + $full)
            $script:Summary.removedDirs++
        }
    }
}

function Get-PluginCliPath {
    <#
    .SYNOPSIS
    The command to run for plugin installs, preferring a real process carrier.
    .DESCRIPTION
    On this host Get-Command resolves npm's claude.ps1 first. Running that shim in-process
    would make this script depend on the wrapper's own exit handling, so the .cmd sibling is
    preferred when it exists: a real child process, with its own exit code and a handle that
    can be killed.
    #>
    $cmd = Get-Command claude -ErrorAction SilentlyContinue
    if (-not $cmd) { return '' }
    if ($cmd.Source -like '*.ps1') {
        $sibling = [System.IO.Path]::ChangeExtension($cmd.Source, '.cmd')
        if (Test-Path -LiteralPath $sibling) { return $sibling }
    }
    return $cmd.Source
}

function Invoke-PluginInstallCall {
    <#
    .SYNOPSIS
    Runs one plugin install as its own process with a hard timeout; returns what happened.
    .DESCRIPTION
    Measured 2026-09-15: "claude plugin install context7@claude-plugins-official" sat for
    minutes with no output and no CPU - a network/marketplace stall. A plain call operator
    would have waited forever with no way to tell which plugin was stuck, so every install
    gets a progress line before it starts and a timeout that kills it.
    The process is started through a ProcessStartInfo this script owns rather than
    Start-Process: on Windows PowerShell 5.1 a -PassThru object reports an empty ExitCode,
    which made every successful install look like a failure (measured, 5.1 leg).
    .cmd carriers go through cmd.exe, because CreateProcess cannot run a batch file.
    #>
    param([Parameter(Mandatory)][string]$Exe, [Parameter(Mandatory)][string[]]$Arguments, [Parameter(Mandatory)][int]$TimeoutSec)
    $quoted = @($Arguments | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } })
    $line = $quoted -join ' '
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.UseShellExecute = $false
    if ($Exe -like '*.cmd' -or $Exe -like '*.bat') {
        $psi.FileName = $env:ComSpec
        if ($Exe -match '\s') { $psi.Arguments = ('/c ""{0}" {1}"' -f $Exe, $line) } else { $psi.Arguments = ('/c "{0}" {1}' -f $Exe, $line) }
    } else {
        $psi.FileName = $Exe
        $psi.Arguments = $line
    }
    $proc = [System.Diagnostics.Process]::Start($psi)
    if (-not $proc.WaitForExit($TimeoutSec * 1000)) {
        try { $proc.Kill() } catch { }
        return [pscustomobject]@{ TimedOut = $true; ExitCode = 0 }
    }
    return [pscustomobject]@{ TimedOut = $false; ExitCode = $proc.ExitCode }
}

function Invoke-PluginStep {
    <#
    .SYNOPSIS
    Installs the marketplace plugins, or prints the commands to run by hand.
    .DESCRIPTION
    Plugins are installed one at a time so one failure neither hides nor blocks the others,
    and each one announces itself before it starts. A missing CLI is not a deployment
    failure: the exact commands are printed instead. A stall past the timeout is killed and
    reported as a failure, because a deployer that can hang forever is worse than one that
    says "this plugin did not install".
    #>
    param([Parameter(Mandatory)]$Plan, [switch]$NoPluginInstall)
    $cliPath = Get-PluginCliPath
    foreach ($a in $Plan) {
        if ($a.Kind -ne 'plugin') { continue }
        $spec = '{0}@{1}' -f $a.Target, $PluginMarketplace
        if ($NoPluginInstall) {
            Write-Line ('[PLUGIN]   {0} SKIPPED by -NoPluginInstall' -f $spec)
            $script:Summary.pluginsSkipped++
            continue
        }
        if (-not $cliPath) {
            Write-Line ('[PLUGIN]   {0} NOT INSTALLED - run manually: claude plugin install {1}' -f $spec, $spec)
            $script:Summary.pluginsManual++
            continue
        }
        Write-Line ('[PLUGIN]   installing {0} (timeout {1}s; this is a network operation)' -f $spec, $PluginInstallTimeoutSec)
        $call = Invoke-PluginInstallCall -Exe $cliPath -Arguments @('plugin', 'install', $spec) -TimeoutSec $PluginInstallTimeoutSec
        if ($call.TimedOut) {
            Write-Line ('[PLUGIN]   {0} TIMEOUT after {1}s - the install was killed; run it by hand to see the CLI output' -f $spec, $PluginInstallTimeoutSec)
            $script:Summary.pluginsFailed++
        } elseif ($call.ExitCode -eq 0) {
            Write-Line ('[PLUGIN]   {0} OK' -f $spec)
            $script:Summary.pluginsInstalled++
        } else {
            Write-Line ('[PLUGIN]   {0} FAILED (exit {1})' -f $spec, $call.ExitCode)
            $script:Summary.pluginsFailed++
        }
    }
}

function Show-Summary {
    <#
    .SYNOPSIS
    Prints the summary line family and returns the process exit code.
    .DESCRIPTION
    RESULT=OK (deploy, validate or dry run completed) or FAILED (the pre-flight checks
    refused this plan, or a write / plugin install failed). Only OK is a success. Each mode
    states what it actually did, so a partial run can never be misread as a complete one:
    -Deploy reports written / unchanged / backups, what -RemoveStale deleted and how the
    plugin step ended; -Preview reports what a deploy would write.
    #>
    param([Parameter(Mandatory)][string]$Result, [Parameter(Mandatory)][string]$Mode, [switch]$Deploy, [switch]$Preview)
    Write-Line ''
    Write-Line ('[SUMMARY]  RESULT={0} ({1})' -f $Result, $Mode)
    Write-Line ('[SUMMARY]  planned={0} stale={1} preserve={2}' -f $script:Summary.planned, $script:Summary.stale, $script:Summary.preserve)
    if ($Preview) {
        Write-Line ('[SUMMARY]  would-write={0} unchanged={1} (this was a dry run: nothing was written)' -f $script:Summary.wouldWrite, $script:Summary.unchanged)
    }
    if ($Deploy) {
        Write-Line ('[SUMMARY]  written={0} unchanged={1} backups={2}' -f $script:Summary.written, $script:Summary.unchanged, $script:Summary.backups)
        if ($script:Summary.removedFiles -gt 0 -or $script:Summary.removedDirs -gt 0) {
            Write-Line ('[SUMMARY]  stale-removed: files={0} dirs={1}' -f $script:Summary.removedFiles, $script:Summary.removedDirs)
        }
        Write-Line ('[SUMMARY]  plugins: installed={0} skipped={1} manual={2} failed={3}' -f $script:Summary.pluginsInstalled, $script:Summary.pluginsSkipped, $script:Summary.pluginsManual, $script:Summary.pluginsFailed)
    }
    if ($Result -eq 'OK') { return 0 }
    return 1
}

# ---------------------------------------------------------------- main

if (-not (Test-Path -LiteralPath $RepoRoot)) {
    Write-Line ('[CHECK]    repo FAIL source tree not found: ' + $RepoRoot)
    exit 1
}
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path

# An explicitly passed but empty root must fail before any path is resolved: the resolver
# would otherwise fall back to the real home and deploy to the machine you are sitting on.
$explicitRootsOk = $true
foreach ($spec in @(
        [pscustomobject]@{ Name = '-ClaudeDir'; Value = $ClaudeDir; Given = $PSBoundParameters.ContainsKey('ClaudeDir') },
        [pscustomobject]@{ Name = '-CodexDir'; Value = $CodexDir; Given = $PSBoundParameters.ContainsKey('CodexDir') },
        [pscustomobject]@{ Name = '-DshDir'; Value = $DshDir; Given = $PSBoundParameters.ContainsKey('DshDir') })) {
    if (-not (Assert-ExplicitRoot -Name $spec.Name -Value $spec.Value -Given $spec.Given)) { $explicitRootsOk = $false }
}
if (-not $explicitRootsOk) {
    exit (Show-Summary -Result 'FAILED' -Mode 'an explicitly passed target root was empty; nothing was written')
}

$ClaudeRoot = Resolve-TargetDirectory -Explicit $ClaudeDir -LeafName '.claude'
$CodexRoot = Resolve-TargetDirectory -Explicit $CodexDir -LeafName '.codex'
$DshRoot = Resolve-TargetDirectory -Explicit $DshDir -LeafName '.dsh'
# Normalise: a trailing separator must not slip past the self-conflict check below.
function Get-NormalizedRoot {
    param([Parameter(Mandatory)][string]$Path)
    if ($Path -match '^[A-Za-z]:\\$') { return $Path }
    return $Path.TrimEnd('\')
}
$ClaudeRoot = Get-NormalizedRoot -Path $ClaudeRoot
$CodexRoot = Get-NormalizedRoot -Path $CodexRoot
$DshRoot = Get-NormalizedRoot -Path $DshRoot
$RootSpecs = @(
    [pscustomobject]@{ Name = '-ClaudeDir'; Path = $ClaudeRoot },
    [pscustomobject]@{ Name = '-CodexDir'; Path = $CodexRoot },
    [pscustomobject]@{ Name = '-DshDir'; Path = $DshRoot }
)

$Plan = Build-Plan -ClaudeRoot $ClaudeRoot -CodexRoot $CodexRoot -DshRoot $DshRoot
# Counters are mode independent: -ValidateOnly must report the same numbers as -DryRun
# even though it never calls Show-Plan, so all three come from one computation here.
$counters = Get-PlanCounters -Plan $Plan
$script:Summary.planned = $counters.Planned
$script:Summary.stale = $counters.Stale
$script:Summary.preserve = $counters.Preserve

if ($ValidateOnly) {
    Write-Line ('[CHECK]    targets claude={0} codex={1} dsh={2}' -f $ClaudeRoot, $CodexRoot, $DshRoot)
    $passed = Test-Plan -Plan $Plan -RootSpecs $RootSpecs
    foreach ($m in (Get-MachineLocalReport -ClaudeRoot $ClaudeRoot -CodexRoot $CodexRoot -DshRoot $DshRoot -HomeRoot (Split-Path -Parent $ClaudeRoot))) {
        Write-Line ('[PRESERVE] ' + $m + ' (machine-local, never touched)')
    }
    $result = 'OK'
    $mode = 'validate only, nothing was written'
    if (-not $passed) { $result = 'FAILED'; $mode = 'validate only, nothing was written' }
    exit (Show-Summary -Result $result -Mode $mode)
}

if ($DryRun) {
    Write-Line ('[PLAN]     targets claude={0} codex={1} dsh={2}' -f $ClaudeRoot, $CodexRoot, $DshRoot)
    $report = Get-MachineLocalReport -ClaudeRoot $ClaudeRoot -CodexRoot $CodexRoot -DshRoot $DshRoot -HomeRoot (Split-Path -Parent $ClaudeRoot)
    Show-Plan -Plan $Plan -MachineLocalReport $report
    if ($RemoveStale) {
        Write-Line '[PLAN]     -RemoveStale was given: a deploy would delete exactly the [STALE] rows above'
    }
    # Preview uses the same file-pair expansion as the deploy, so [DIFF] lists exactly what
    # a deploy would write - the preview cannot drift away from the writer.
    Show-WritePreview -Plan $Plan
    # The checks are informational here: a dry run must print the plan and exit 0 even when
    # the plan would be refused, but staying silent about that would let a refused plan look
    # like a green light.
    $passed = Test-Plan -Plan $Plan -RootSpecs $RootSpecs
    if (-not $passed) {
        Write-Line '[WARN]     this plan would be refused by the pre-flight checks above: a deploy would write nothing'
    }
    exit (Show-Summary -Result 'OK' -Mode 'dry run, nothing was written' -Preview)
}

# Deploy (no parameters): validate, print the plan, then copy. Live-only content is only
# reported ([STALE]) unless -RemoveStale was given explicitly; every file that is
# overwritten is backed up next to itself first, so a single file can be put back by hand.
# The failure reason for a refused plan is NOT a binding error (K1), so a caller can tell
# "the plan was refused" from "wrong arguments".
Write-Line ('[PLAN]     targets claude={0} codex={1} dsh={2}' -f $ClaudeRoot, $CodexRoot, $DshRoot)
$report = Get-MachineLocalReport -ClaudeRoot $ClaudeRoot -CodexRoot $CodexRoot -DshRoot $DshRoot -HomeRoot (Split-Path -Parent $ClaudeRoot)
Show-Plan -Plan $Plan -MachineLocalReport $report
$passed = Test-Plan -Plan $Plan -RootSpecs $RootSpecs
if (-not $passed) {
    exit (Show-Summary -Result 'FAILED' -Mode 'pre-flight checks refused this deployment; nothing was written')
}
$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
try {
    Invoke-ManagedDeploy -Plan $Plan -Stamp $Stamp
    if ($RemoveStale) { Remove-StaleContent -Plan $Plan }
} catch {
    Write-Line ('[ERROR]    ' + $_.Exception.Message)
    Write-Line '[SUMMARY]  every file already written is listed above; each overwritten file has a sibling <name>.bak-* copy'
    exit (Show-Summary -Result 'FAILED' -Mode 'a write failed; the run stopped at the first failure' -Deploy)
}
try {
    Invoke-PluginStep -Plan $Plan -NoPluginInstall:$NoPluginInstall
} catch {
    Write-Line ('[ERROR]    ' + $_.Exception.Message)
    exit (Show-Summary -Result 'FAILED' -Mode 'the plugin step failed; the files are already deployed' -Deploy)
}
if ($script:Summary.pluginsFailed -gt 0) {
    exit (Show-Summary -Result 'FAILED' -Mode 'the files are deployed, but at least one plugin install failed' -Deploy)
}
exit (Show-Summary -Result 'OK' -Mode 'deployed' -Deploy)