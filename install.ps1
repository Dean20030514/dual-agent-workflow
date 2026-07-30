# Deploys the dual-agent workflow + Claude Code global config to this machine.
# PowerShell 5.1 compatible. Existing targets are backed up to *.bak-<timestamp>.
# Run from the repo root:  powershell -ExecutionPolicy Bypass -File .\install.ps1

[CmdletBinding()]
param([switch]$IUnderstandThisReplacesLiveConfig)

# Guard for the snapshot-first migration window (remove when H3 lands real
# -DryRun/-ValidateOnly): this script mirror-replaces ~/.claude/{rules,workflow,
# commands} — including live-only content such as workflow/archive/** — and
# overwrites ~/.codex/AGENTS.md. [CmdletBinding()] makes unknown parameters
# (-DryRun, -ValidateOnly, typos) fail at binding time before any statement
# runs, instead of being silently swallowed by $args; the switch below is the
# only way to reach the deploy path.
if (-not $IUnderstandThisReplacesLiveConfig) {
    throw 'install.ps1 is guarded during the snapshot-first migration (MORATORIUM-LOCAL-001). Re-run with -IUnderstandThisReplacesLiveConfig after the migration gates pass.'
}

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $MyInvocation.MyCommand.Path
$claudeDir = Join-Path $env:USERPROFILE '.claude'
$codexDir = Join-Path $env:USERPROFILE '.codex'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'

function Backup-IfExists([string]$path) {
    if (Test-Path $path) {
        Copy-Item $path ("$path.bak-$stamp") -Recurse -Force
        Write-Host "backed up: $path -> $path.bak-$stamp"
    }
}

New-Item -ItemType Directory -Force $claudeDir | Out-Null
New-Item -ItemType Directory -Force $codexDir | Out-Null

# 1. Global instructions + settings (single files)
foreach ($f in 'CLAUDE.md', 'settings.json') {
    $target = Join-Path $claudeDir $f
    Backup-IfExists $target
    Copy-Item (Join-Path $repo "claude\$f") $target -Force
    Write-Host "deployed: ~/.claude/$f"
}

# 2. Rules / workflow / commands (mirror-replace so removed files do not linger)
foreach ($d in 'rules', 'workflow', 'commands') {
    $target = Join-Path $claudeDir $d
    Backup-IfExists $target
    if (Test-Path $target) { Remove-Item $target -Recurse -Force }
    Copy-Item (Join-Path $repo "claude\$d") $target -Recurse -Force
    Write-Host "deployed: ~/.claude/$d/"
}

# 3. Codex side
$target = Join-Path $codexDir 'AGENTS.md'
Backup-IfExists $target
Copy-Item (Join-Path $repo 'codex\AGENTS.md') $target -Force
Write-Host 'deployed: ~/.codex/AGENTS.md'

$codexConfig = Join-Path $codexDir 'config.toml'
if (-not (Test-Path $codexConfig)) {
    Copy-Item (Join-Path $repo 'codex\config.example.toml') $codexConfig
    Write-Host 'seeded: ~/.codex/config.toml from config.example.toml (adjust model if needed)'
} else {
    Write-Host 'kept: existing ~/.codex/config.toml (reference: codex/config.example.toml)'
}

# 4. Plugins (settings.json already enables them; install populates the cache)
$plugins = 'context7', 'chrome-devtools-mcp', 'pyright-lsp', 'typescript-lsp', 'frontend-design'
$claudeCli = Get-Command claude -ErrorAction SilentlyContinue
if ($claudeCli) {
    foreach ($p in $plugins) {
        Write-Host "installing plugin: $p@claude-plugins-official"
        & claude plugin install "$p@claude-plugins-official"
    }
} else {
    Write-Host 'claude CLI not on PATH - install plugins manually later:'
    foreach ($p in $plugins) { Write-Host "  claude plugin install $p@claude-plugins-official" }
}

Write-Host ''
Write-Host 'Done. NOT deployed by design: credentials, session state, logs, and'
Write-Host 'auto-memory (~/.claude/projects/*/memory) - migrate memory privately'
Write-Host 'by copying those folders yourself if you want it on the new machine.'
