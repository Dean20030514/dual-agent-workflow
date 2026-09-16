# Test helpers for the install.ps1 regression suite (task H3).
#
# Scope and safety (TASK_BRIEF.md -> "执行前置约束"):
#   * Every helper writes ONLY under $env:TEMP. Nothing here touches the real
#     ~/.claude, ~/.codex or ~/.dsh, and nothing here invokes the installer
#     against a real home.
#   * The mechanical interlock lives INSIDE the generated child wrapper, so it
#     judges the environment the installer actually runs in - not what the
#     parent intended to set (see AC precond 3).
#   * Every test case gets its own fresh temp tree; nothing is reused across
#     cases (S-2).
#
# This file is intentionally NOT named *.Tests.ps1 so Pester does not treat it
# as a container.

Set-StrictMode -Version Latest

$script:RepoRoot = Split-Path -Parent $PSScriptRoot
$script:InstallerPath = Join-Path $script:RepoRoot 'install.ps1'
$script:RealHome = $env:USERPROFILE
$script:PwshExe = (Get-Process -Id $PID).Path
$script:WindowsPsExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'

function Get-RepoRoot { return $script:RepoRoot }
function Get-WindowsPowerShellPath { return $script:WindowsPsExe }

function New-TempDirectory {
    <# Creates and returns a unique directory under $env:TEMP. #>
    param([Parameter(Mandatory)][string]$Prefix)
    $path = Join-Path $env:TEMP ('{0}-{1}' -f $Prefix, [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Force $path | Out-Null
    return $path
}

function New-FakeClaudeShim {
    <#
    .SYNOPSIS
    Creates a claude.cmd shim that records its argv and exits with a fixed code.
    .DESCRIPTION
    Put the returned directory first on PATH and `claude` resolves to this shim
    (measured: PATH directory order wins over extension precedence, so a .cmd
    shim is not shadowed by the real npm claude.ps1).
    #>
    param(
        [Parameter(Mandatory)][string]$Directory,
        [Parameter(Mandatory)][string]$LogPath,
        [int]$ExitCode = 0
    )
    New-Item -ItemType Directory -Force $Directory | Out-Null
    $body = @(
        '@echo off',
        ('echo %*>>"{0}"' -f $LogPath),
        ('exit /b {0}' -f $ExitCode)
    ) -join "`r`n"
    Set-Content -Path (Join-Path $Directory 'claude.cmd') -Value $body -Encoding ascii
    return (Join-Path $Directory 'claude.cmd')
}

function Get-TreeSignature {
    <#
    .SYNOPSIS
    Returns a stable signature of a directory tree (relative paths + SHA-256).
    .DESCRIPTION
    Files contribute "f:<relpath>|<sha256>", directories contribute
    "d:<relpath>". Missing paths return the literal 'MISSING'. Used to prove
    "zero writes" by comparing signatures before and after a call.
    #>
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return 'MISSING' }
    if (-not (Get-Item -LiteralPath $Path -Force).PSIsContainer) {
        return ('f:' + (Split-Path -Leaf $Path) + '|' + (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash)
    }
    $root = (Resolve-Path -LiteralPath $Path).Path.TrimEnd('\')
    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($d in Get-ChildItem -LiteralPath $root -Directory -Recurse -Force) {
        $lines.Add('d:' + $d.FullName.Substring($root.Length + 1))
    }
    foreach ($f in Get-ChildItem -LiteralPath $root -File -Recurse -Force) {
        $rel = $f.FullName.Substring($root.Length + 1)
        $lines.Add('f:' + $rel + '|' + (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash)
    }
    $sorted = $lines | Sort-Object
    return ($sorted -join "`n")
}

function Test-PathInsideDirectory {
    <# True when $Child is the same path as, or lives under, $Parent. #>
    param(
        [Parameter(Mandatory)][string]$Child,
        [Parameter(Mandatory)][string]$Parent
    )
    $c = [System.IO.Path]::GetFullPath($Child).TrimEnd('\')
    $p = [System.IO.Path]::GetFullPath($Parent).TrimEnd('\')
    if ($c -eq $p) { return $true }
    return $c.StartsWith($p + '\', [System.StringComparison]::OrdinalIgnoreCase)
}

function New-TestCase {
    <#
    .SYNOPSIS
    Creates an isolated case: temp home, three temp targets, shim dir and log.
    .PARAMETER SeedTargets
    Pre-creates the mirrored target directories plus the keep-local-only and
    machine-local samples used by AC2/AC4.
    .PARAMETER SeedConfigToml
    Pre-creates ~/.codex/config.toml so the seed-only path is not exercised
    (AC6/AC7 compute a stable expected set that way).
    .PARAMETER FakeRepo
    Builds a temp "fake repo" (full source tree + a copy of install.ps1) and
    points the installer at that copy instead of the real repository.
    #>
    param(
        [Parameter(Mandatory)][string]$Name,
        [switch]$SeedTargets,
        [switch]$SeedConfigToml,
        [switch]$FakeRepo,
        [switch]$IncompleteSourceTree
    )
    $root = New-TempDirectory -Prefix ('h3-' + $Name)
    $homeRoot = Join-Path $root 'home'
    New-Item -ItemType Directory -Force $homeRoot | Out-Null

    $case = [pscustomobject]@{
        Root        = $root
        Home        = $homeRoot
        ClaudeDir   = Join-Path $homeRoot '.claude'
        CodexDir    = Join-Path $homeRoot '.codex'
        DshDir      = Join-Path $homeRoot '.dsh'
        ShimDir     = Join-Path $root 'shim'
        ShimLog     = Join-Path $root 'claude-shim.log'
        Sentinel    = Join-Path $root 'installer-started.flag'
        RepoRoot    = $script:RepoRoot
        Installer   = $script:InstallerPath
    }

    New-FakeClaudeShim -Directory $case.ShimDir -LogPath $case.ShimLog | Out-Null

    if ($FakeRepo) {
        $fake = Join-Path $root 'fakerepo'
        New-Item -ItemType Directory -Force $fake | Out-Null
        Copy-Item (Join-Path $script:RepoRoot 'install.ps1') (Join-Path $fake 'install.ps1') -Force
        foreach ($d in 'claude', 'codex', 'dsh') {
            Copy-Item (Join-Path $script:RepoRoot $d) (Join-Path $fake $d) -Recurse -Force
        }
        if ($IncompleteSourceTree) {
            Remove-Item (Join-Path $fake 'claude\settings.json') -Force
        }
        $case.RepoRoot = $fake
        $case.Installer = Join-Path $fake 'install.ps1'
    }

    if ($SeedTargets) {
        New-Item -ItemType Directory -Force (Join-Path $case.ClaudeDir 'workflow\archive\old') | Out-Null
        New-Item -ItemType Directory -Force (Join-Path $case.ClaudeDir 'rules\common') | Out-Null
        New-Item -ItemType Directory -Force (Join-Path $case.ClaudeDir 'commands') | Out-Null
        Set-Content -Path (Join-Path $case.ClaudeDir 'workflow\archive\old\e.md') -Value 'local evidence archive sample' -Encoding ascii
        Set-Content -Path (Join-Path $case.ClaudeDir 'workflow\AGENTS.md.bak-20260101-000000') -Value 'legacy per-file backup sample' -Encoding ascii
        Set-Content -Path (Join-Path $case.ClaudeDir 'workflow\stray.md') -Value 'live-only file that mirror-replace must delete' -Encoding ascii
        Set-Content -Path (Join-Path $case.ClaudeDir 'settings.local.json') -Value '{"machineLocal":true}' -Encoding ascii
        Set-Content -Path (Join-Path $case.ClaudeDir 'CLAUDE.md') -Value 'stale managed file' -Encoding ascii
        New-Item -ItemType Directory -Force (Join-Path $case.DshDir 'sessions') | Out-Null
        New-Item -ItemType Directory -Force (Join-Path $case.DshDir 'workflow\archive') | Out-Null
        Set-Content -Path (Join-Path $case.DshDir 'sessions\s.json') -Value '{"session":1}' -Encoding ascii
        Set-Content -Path (Join-Path $case.DshDir 'settings.yaml') -Value 'machineLocal: true' -Encoding ascii
        Set-Content -Path (Join-Path $case.DshDir '.credentials.yaml') -Value 'token: do-not-copy' -Encoding ascii
    }
    if ($SeedConfigToml) {
        New-Item -ItemType Directory -Force $case.CodexDir | Out-Null
        Set-Content -Path (Join-Path $case.CodexDir 'config.toml') -Value 'model = "keep-me"' -Encoding ascii
    }
    return $case
}

function New-ChildWrapper {
    <#
    .SYNOPSIS
    Generates the child script that (a) isolates the environment, (b) asserts
    the interlock, (c) records that it reached the invocation, (d) runs the
    installer via a fixed -File call and (e) propagates the exit code.
    #>
    param(
        [Parameter(Mandatory)]$Case,
        [string]$HostExe = $script:PwshExe,
        [string[]]$OverrideTargets
    )
    $claude = $Case.ClaudeDir; $codex = $Case.CodexDir; $dsh = $Case.DshDir
    if ($OverrideTargets) {
        $claude = $OverrideTargets[0]; $codex = $OverrideTargets[1]; $dsh = $OverrideTargets[2]
    }
    $realClaude = Join-Path $script:RealHome '.claude'
    $realCodex = Join-Path $script:RealHome '.codex'
    $realDsh = Join-Path $script:RealHome '.dsh'

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('# Generated by tests/TestHelpers.ps1 - do not edit, do not commit.')
    $lines.Add("`$env:USERPROFILE = '$($Case.Home)'")
    $lines.Add("`$env:PATH = '$($Case.ShimDir);' + `$env:PATH")

    $lines.Add("`$realHome = '$script:RealHome'")
    $lines.Add("`$targets = @('$claude', '$codex', '$dsh')")
    $lines.Add("`$expectedHome = '$($Case.Home)'")
    # The isolation guard is always emitted; there is deliberately no bypass switch.
    $lines.Add('if ($env:USERPROFILE -ne $expectedHome) { Write-Output "INTERLOCK-FAIL userprofile=$env:USERPROFILE"; exit 97 }')
    $lines.Add("`$realHomeTargets = @('$realClaude', '$realCodex', '$realDsh')")
    $lines.Add('foreach ($t in $targets) {')
    $lines.Add('    if (Test-Path -LiteralPath $t) { $full = (Resolve-Path -LiteralPath $t).Path } else { $full = [System.IO.Path]::GetFullPath($t) }')
    $lines.Add('    if (-not $full.StartsWith($expectedHome + ''\'', [System.StringComparison]::OrdinalIgnoreCase)) { Write-Output "INTERLOCK-FAIL target-not-in-temp-home=$full"; exit 97 }')
    $lines.Add('    foreach ($rt in $realHomeTargets) {')
    $lines.Add('        $rf = [System.IO.Path]::GetFullPath($rt)')
    $lines.Add('        if ($full -eq $rf -or $full.StartsWith($rf + ''\'', [System.StringComparison]::OrdinalIgnoreCase)) { Write-Output "INTERLOCK-FAIL target-in-real-home=$full"; exit 97 }')
    $lines.Add('    }')
    $lines.Add('}')
    $lines.Add('$claudeCmd = Get-Command claude -ErrorAction SilentlyContinue')
    $lines.Add("if (-not `$claudeCmd -or `$claudeCmd.Source -notlike '$($Case.ShimDir)*') { Write-Output ('INTERLOCK-FAIL claude=' + `$(if (`$claudeCmd) { `$claudeCmd.Source } else { '<none>' })); exit 97 }")
    # psver / host are recorded by the wrapper, i.e. by the process the installer is
    # actually started from. The 5.1 leg asserts psver=5 and the pwsh leg asserts
    # psver=7, so neither leg can silently run on the wrong host.
    $lines.Add("Write-Output ('CHILD-ENV userprofile=' + `$env:USERPROFILE + ' claude=' + (Get-Command claude).Source + ' targets=' + (`$targets -join ',') + ' psver=' + `$PSVersionTable.PSVersion.Major + ' host=' + (Get-Process -Id `$PID).Path)")
    $lines.Add("Set-Content -LiteralPath '$($Case.Sentinel)' -Value 'installer invoked' -Encoding ascii")
    $lines.Add("& '$HostExe' -NoProfile -File '$($Case.Installer)' @args")
    $lines.Add('exit $LASTEXITCODE')

    $wrapper = Join-Path $Case.Root 'child-wrapper.ps1'
    Set-Content -Path $wrapper -Value ($lines -join "`n") -Encoding utf8NoBOM
    return $wrapper
}

function Invoke-InstallerCase {
    <#
    .SYNOPSIS
    Runs the installer inside an isolated child process and returns the result.
    .DESCRIPTION
    Returns an object with ExitCode, Output, SentinelExists (proof the child
    reached the invocation) and WrapperPath. The real home is never a target:
    the wrapper aborts with exit 97 if it is.
    #>
    param(
        [Parameter(Mandatory)]$Case,
        [string[]]$Arguments = @(),
        [string[]]$OverrideTargets,
        [string]$HostExe = $script:PwshExe,
        [hashtable]$Environment = @{}
    )
    $wrapper = New-ChildWrapper -Case $Case -HostExe $HostExe -OverrideTargets $OverrideTargets 
    $saved = @{}
    foreach ($k in $Environment.Keys) { $saved[$k] = [System.Environment]::GetEnvironmentVariable($k); [System.Environment]::SetEnvironmentVariable($k, $Environment[$k]) }
    try {
        $output = & $HostExe -NoProfile -File $wrapper @Arguments 2>&1
        $exit = $LASTEXITCODE
    } finally {
        foreach ($k in $saved.Keys) { [System.Environment]::SetEnvironmentVariable($k, $saved[$k]) }
    }
    return [pscustomobject]@{
        ExitCode       = $exit
        Output         = ($output | ForEach-Object { $_.ToString() })
        OutputText     = (($output | ForEach-Object { $_.ToString() }) -join "`n")
        SentinelExists = (Test-Path -LiteralPath $Case.Sentinel)
        WrapperPath    = $wrapper
    }
}

function Get-ManagedDeploySet {
    <#
    .SYNOPSIS
    Enumerates the expected deployed surface INDEPENDENTLY of the installer
    (the suite must not ask the code under test what it is supposed to do - N3).
    .DESCRIPTION
    Returns relative paths keyed by target home, e.g. 'claude/CLAUDE.md'.
    #>
    param([Parameter(Mandatory)][string]$RepoRoot)
    $set = New-Object System.Collections.Generic.List[string]
    foreach ($f in 'CLAUDE.md', 'settings.json') { $set.Add('claude/' + $f) }
    foreach ($d in 'rules', 'workflow', 'commands') {
        foreach ($f in Get-ChildItem -LiteralPath (Join-Path $RepoRoot "claude\$d") -File -Recurse) {
            $rel = $f.FullName.Substring((Join-Path $RepoRoot "claude\$d").Length + 1).Replace('\', '/')
            $set.Add(('claude/{0}/{1}' -f $d, $rel))
        }
    }
    $set.Add('codex/AGENTS.md')
    $set.Add('dsh/AGENTS.md')
    foreach ($f in Get-ChildItem -LiteralPath (Join-Path $RepoRoot 'dsh\workflow') -File -Recurse) {
        $rel = $f.FullName.Substring((Join-Path $RepoRoot 'dsh\workflow').Length + 1).Replace('\', '/')
        $set.Add('dsh/workflow/' + $rel)
    }
    foreach ($skill in 'dual-agent-workflow', 'independent-review') {
        foreach ($f in Get-ChildItem -LiteralPath (Join-Path $RepoRoot "dsh\skills\$skill") -File -Recurse) {
            $rel = $f.FullName.Substring((Join-Path $RepoRoot "dsh\skills\$skill").Length + 1).Replace('\', '/')
            $set.Add(('dsh/skills/{0}/{1}' -f $skill, $rel))
        }
    }
    return ($set | Sort-Object)
}

function Get-ExpectedPlugins {
    <#
    .SYNOPSIS
    Expected plugin set, read from claude/settings.json -> enabledPlugins.
    .DESCRIPTION
    Deliberately NOT read from install.ps1: taking the expectation from the code
    under test would make the assertion self-referential (any six names would pass,
    which is how the stale list that started this task went unnoticed).
    #>
    $settings = Join-Path (Split-Path -Parent $PSScriptRoot) 'claude\settings.json'
    $json = Get-Content -Raw -LiteralPath $settings | ConvertFrom-Json
    $names = @()
    foreach ($key in $json.enabledPlugins.PSObject.Properties.Name) {
        if ($key -like '*@claude-plugins-official') { $names += ($key -split '@')[0] }
    }
    return ($names | Sort-Object)
}

function Get-TargetsSignature {
    <#
    .SYNOPSIS
    Signature of the three deployment targets only.
    .DESCRIPTION
    The isolated home also collects files written by the PowerShell HOST itself
    (it derives its known folders from USERPROFILE, so <home>\AppData\... appears
    even during a pure -DryRun). Those are harness artefacts, not installer
    writes, so "zero writes" is measured on the actual deployment targets.
    #>
    param([Parameter(Mandatory)]$Case)
    $parts = New-Object System.Collections.Generic.List[string]
    foreach ($t in @($Case.ClaudeDir, $Case.CodexDir, $Case.DshDir)) { $parts.Add($t + ' => ' + (Get-TreeSignature $t)) }
    return ($parts -join "`n")
}

function Get-TaggedLines {
    <# Lines emitted with an exact output-contract tag, e.g. '[DELETE]'. #>
    param([Parameter(Mandatory)][AllowEmptyCollection()]$Output, [Parameter(Mandatory)][string]$Tag)
    return @($Output | Where-Object { $_.ToString().StartsWith($Tag) })
}

function Remove-TestCase {
    param([Parameter(Mandatory)]$Case)
    if (Test-Path -LiteralPath $Case.Root) { Remove-Item -LiteralPath $Case.Root -Recurse -Force }
}
