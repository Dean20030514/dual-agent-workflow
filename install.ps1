# Deploys the dual-agent workflow + Claude Code / Codex / DSH global config to this machine.
# PowerShell 5.1 compatible. ASCII only: this file has no BOM, and 5.1 reads -File scripts
# with the ANSI code page, so non-ASCII characters here would come out as mojibake.
#
# Run from the repo root:
#   powershell -ExecutionPolicy Bypass -File .\install.ps1
#
# Safety model (see README.md -> deployment section):
#   * Default (no parameters) = validate, print the plan, then REFUSE to execute: the
#     deployment execution (mirror-replace, backups, plugin step) is slice B and is
#     deliberately NOT in this build, so a no-argument run exits non-zero with
#     RESULT=REFUSED. This version never writes anything, with or without parameters.
#   * -NoPluginInstall skips the plugin step (offline or restricted runs); each plugin
#     is then reported as SKIPPED. The suppressed-count summary line is slice B.
#   * -DryRun      prints the exact plan and changes nothing at all.
#   * -ValidateOnly performs the pre-flight checks only, and changes nothing at all.
#   * Mirror-replaced directories drop files that the source tree does not have, EXCEPT
#     keep-local-only paths (the "archive" segment anywhere, and *.bak-* file names) and
#     machine-local paths (credentials, sessions, settings.yaml, ...), which are never
#     modified, deleted or copied.
#   * SLICE B ONLY (not implemented in this build): every deployment target that already
#     exists is backed up next to itself as <name>.bak-<timestamp>; there is deliberately
#     no whole-tree backup, because it copied credentials and had no rollback value.
#
# Exit codes: 0 = OK (validate or dry run completed); 1 = FAILED (the pre-flight checks
# refused this plan) or REFUSED (deployment execution is not implemented in this build).
#
# Targets (defaults; each root is overridable with -ClaudeDir / -CodexDir / -DshDir):
#   ~/.claude  <- CLAUDE.md, settings.json, rules/, workflow/, commands/
#   ~/.codex   <- AGENTS.md, and config.toml only when it is missing (seed-only)
#   ~/.dsh     <- AGENTS.md, workflow/, skills/dual-agent-workflow, skills/independent-review
#
# Deliberately NOT done by this script:
#   * no write path at all in this build - no mirror-replace, no copy, no delete, no
#     backup and no plugin install; slice B lands the writes and will back up each managed
#     target individually instead of taking a whole-tree backup;
#   * no copy of credentials, sessions, storages, profiles or settings files:
#     ~/.claude/settings.local.json, ~/.dsh/settings.yaml, ~/.dsh/.credentials.yaml and
#     ~/.claude/projects/*/memory are never read, written, deleted or copied;
#   * no acknowledgement switch - the old -IUnderstandThisReplacesLiveConfig was removed in
#     this slice, so passing it now fails at binding time (unknown parameter, exit code 1).

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

# Paths that only exist on this machine and must survive mirror-replace:
#   * any path with an "archive" segment (local evidence archives),
#   * any *.bak-* file (rollback copies written by an older installer).
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

$script:Plan = New-Object System.Collections.Generic.List[object]
$script:Summary = @{ planned = 0; toDelete = 0; preserve = 0 }

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
    True when a path relative to a mirrored directory must survive mirror-replace.
    .DESCRIPTION
    Matches whole path segments only, so "my-archive-notes.md" is NOT preserved
    while "archive/x/y.md" and any "*.bak-*" file name are.
    #>
    param([Parameter(Mandatory)][string]$RelativePath)
    $segments = $RelativePath -split '[\\/]'
    for ($i = 0; $i -lt $segments.Count; $i++) {
        if ($segments[$i] -ieq 'archive') { return $true }
    }
    $leaf = $segments[$segments.Count - 1]
    if ($leaf -like '*.bak-*') { return $true }
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
    foreach ($skill in 'dual-agent-workflow', 'independent-review') {
        $plan.Add((New-MirrorAction -Source (Join-Path $RepoRoot "dsh\skills\$skill") -Target (Join-Path $DshRoot "skills\$skill")))
    }
    # Always planned: with -NoPluginInstall each one is reported as SKIPPED, so the
    # deployment summary states what was suppressed instead of staying silent.
    foreach ($p in $PluginNames) { $plan.Add((New-PluginAction -Name $p)) }
    return $plan
}

function Get-MirrorDelta {
    <#
    .SYNOPSIS
    Splits the live-only content of a mirrored directory into delete / preserve.
    .DESCRIPTION
    A live-only DIRECTORY is only deletable when neither it nor anything below
    it is preserved: a directory that holds keep-local-only content survives,
    and the plan must say so too - otherwise -DryRun and the real run disagree.
    #>
    param([Parameter(Mandatory)]$Action)
    $deleteFiles = @()
    $preserveFiles = @()
    $deleteDirs = @()
    $preserveDirs = @()
    # Only a real directory can hold live-only content. A target that exists as a FILE has
    # none, and enumerating it would return the file itself, whose relative-path Substring
    # throws and takes the whole run down before any check can name the shape failure.
    if ((Test-Path -LiteralPath $Action.Target) -and (Get-Item -LiteralPath $Action.Target -Force).PSIsContainer) {
        foreach ($f in Get-ChildItem -LiteralPath $Action.Target -File -Recurse -Force) {
            $rel = $f.FullName.Substring($Action.Target.Length + 1)
            if ($Action.Files -contains $rel) { continue }
            if (Test-PathKeepLocalOnly -RelativePath $rel) { $preserveFiles += $rel } else { $deleteFiles += $rel }
        }
        $liveOnlyDirs = @()
        foreach ($d in Get-ChildItem -LiteralPath $Action.Target -Directory -Recurse -Force) {
            $rel = $d.FullName.Substring($Action.Target.Length + 1)
            if ($Action.Dirs -contains $rel) { continue }
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
            if ($holdsPreserved) { $preserveDirs += $rel } else { $deleteDirs += $rel }
        }
    }
    # The whitelist is subtree-inheriting (human ruling, 2026-09-15): a preserved directory
    # keeps everything below it. Without this pass a *.bak-* or archive DIRECTORY would be
    # reported as preserved while the live-only files inside it were still listed as
    # [DELETE] - the same plan would both keep and delete the same subtree.
    if (@($preserveDirs).Count -gt 0 -and @($deleteFiles).Count -gt 0) {
        $stillDeletable = @()
        foreach ($f in $deleteFiles) {
            $insidePreservedDir = $false
            foreach ($pd in $preserveDirs) {
                if ($f.StartsWith($pd + '\', [System.StringComparison]::OrdinalIgnoreCase)) { $insidePreservedDir = $true; break }
            }
            if ($insidePreservedDir) { $preserveFiles += $f } else { $stillDeletable += $f }
        }
        $deleteFiles = $stillDeletable
    }
    return [pscustomobject]@{
        DeleteFiles   = @($deleteFiles)
        PreserveFiles = @($preserveFiles)
        DeleteDirs    = @($deleteDirs)
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
    summary can never disagree with the [DELETE] / [PRESERVE] rows of the same run. It is
    computed once, before the mode branches, because -ValidateOnly never calls Show-Plan.
    #>
    param([Parameter(Mandatory)]$Plan)
    $planned = 0
    $toDelete = 0
    $preserve = 0
    foreach ($a in $Plan) {
        if ($a.Kind -eq 'plugin') { continue }
        $planned++
        if ($a.Kind -ne 'mirror') { continue }
        $delta = Get-MirrorDelta -Action $a
        $toDelete += @($delta.DeleteFiles).Count + @($delta.DeleteDirs).Count
        $preserve += @($delta.PreserveFiles).Count + @($delta.PreserveDirs).Count
    }
    return [pscustomobject]@{ Planned = $planned; ToDelete = $toDelete; Preserve = $preserve }
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
                foreach ($f in $delta.DeleteFiles) { Write-Line ('[DELETE]   ' + (Join-Path $a.Target $f)) }
                foreach ($d in $delta.DeleteDirs) { Write-Line ('[DELETE]   ' + (Join-Path $a.Target $d) + ' (dir)') }
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
        if (-not $Passed) { $state = 'FAIL'; $script:checkFailed = $true }
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
        $cli = Get-Command claude -ErrorAction SilentlyContinue
        if ($cli) {
            Report $true 'plugin-cli' ('found: ' + $cli.Source)
        } else {
            Report $true 'plugin-cli' 'claude CLI not on PATH; the plugin step will be SKIPPED'
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

# Slice A contains NO write path: backup / mirror-execute / file-copy / plugin-install all live in slice B/C.
# The functions that performed them are deliberately absent rather than merely unused.

function Show-Summary {
    <#
    .SYNOPSIS
    Prints the slice-A summary line family and returns the process exit code.
    .DESCRIPTION
    RESULT=OK (validate / dry run succeeded), FAILED (pre-flight refused) or
    REFUSED (deployment execution belongs to slice B and is deliberately not done here).
    #>
    param([Parameter(Mandatory)][string]$Result, [Parameter(Mandatory)][string]$Mode)
    Write-Line ''
    Write-Line ('[SUMMARY]  RESULT={0} ({1})' -f $Result, $Mode)
    Write-Line ('[SUMMARY]  planned={0} delete={1} preserve={2}' -f $script:Summary.planned, $script:Summary.toDelete, $script:Summary.preserve)
    # Only OK is a success. FAILED (pre-flight refused) and REFUSED (deployment
    # execution not landed yet) must both reach the caller as a non-zero exit code,
    # otherwise "slice B is missing" is indistinguishable from "deployment done".
    if ($Result -eq 'OK') { return 0 }
    return 1
}

# ---------------------------------------------------------------- main

if (-not (Test-Path -LiteralPath $RepoRoot)) {
    Write-Line ('[CHECK]    repo FAIL source tree not found: ' + $RepoRoot)
    exit 1
}
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path

$ClaudeRoot = Resolve-TargetDirectory -Explicit $ClaudeDir -LeafName '.claude'
$CodexRoot = Resolve-TargetDirectory -Explicit $CodexDir -LeafName '.codex'
$DshRoot = Resolve-TargetDirectory -Explicit $DshDir -LeafName '.dsh'
$RootSpecs = @(
    [pscustomobject]@{ Name = '-ClaudeDir'; Path = $ClaudeRoot },
    [pscustomobject]@{ Name = '-CodexDir'; Path = $CodexRoot },
    [pscustomobject]@{ Name = '-DshDir'; Path = $DshRoot }
)
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
$Roots = @($ClaudeRoot, $CodexRoot, $DshRoot)

$Plan = Build-Plan -ClaudeRoot $ClaudeRoot -CodexRoot $CodexRoot -DshRoot $DshRoot
# Counters are mode independent: -ValidateOnly must report the same numbers as -DryRun
# even though it never calls Show-Plan, so all three come from one computation here.
$counters = Get-PlanCounters -Plan $Plan
$script:Summary.planned = $counters.Planned
$script:Summary.toDelete = $counters.ToDelete
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
    exit (Show-Summary -Result 'OK' -Mode 'dry run, nothing was written')
}

# Deploy (no parameters). Slice A deliberately performs NO writes: it validates, prints the
# plan and the machine-local inventory, then refuses - the failure reason is NOT a binding
# error (K1), so a caller can tell "slice B not landed yet" from "wrong arguments".
Write-Line ('[PLAN]     targets claude={0} codex={1} dsh={2}' -f $ClaudeRoot, $CodexRoot, $DshRoot)
$report = Get-MachineLocalReport -ClaudeRoot $ClaudeRoot -CodexRoot $CodexRoot -DshRoot $DshRoot -HomeRoot (Split-Path -Parent $ClaudeRoot)
Show-Plan -Plan $Plan -MachineLocalReport $report
$passed = Test-Plan -Plan $Plan -RootSpecs $RootSpecs
if (-not $passed) {
    exit (Show-Summary -Result 'FAILED' -Mode 'pre-flight checks refused this deployment; nothing was written')
}
exit (Show-Summary -Result 'REFUSED' -Mode 'deployment execution is implemented in slice B; nothing was written')