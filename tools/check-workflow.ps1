#requires -Version 7.4
[CmdletBinding()]
param(
    [string]$Repo = (Get-Location).Path,
    [string]$SourceRoot = (Split-Path $PSScriptRoot -Parent),
    [string]$ClaudeDir = (Join-Path $env:USERPROFILE '.claude'),
    [string]$CodexDir = $(if ($env:CODEX_HOME) {$env:CODEX_HOME} else {Join-Path $env:USERPROFILE '.codex'}),
    [string]$DshDir = $(if ($env:DSH_HOME) {$env:DSH_HOME} else {Join-Path $env:USERPROFILE '.dsh'})
)
$ErrorActionPreference = 'Stop'
$result = [ordered]@{
    status = 'CHECK_FAILED'; read_only = $true; runtime_checked = $false
    source = $SourceRoot; global = @{status='NOT_CHECKED'}
    project = @{status='NOT_CHECKED';path=$Repo}; next_steps = @()
}
try {
    $SourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
    $installer = Join-Path $SourceRoot 'install.ps1'
    $enroller = Join-Path $SourceRoot 'tools/enable-team-project.ps1'
    foreach ($file in @($installer,$enroller)) {
        if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "Workflow source unavailable: $file" }
    }
    # Preview is the installer's own file/hash oracle. Never invoke a write mode.
    $preview = @(& pwsh -NoProfile -File $installer -DryRun -NoPluginInstall -ClaudeDir $ClaudeDir -CodexDir $CodexDir -DshDir $DshDir 2>&1)
    $previewCode = $LASTEXITCODE
    $text = ($preview | ForEach-Object ToString) -join "`n"
    $count = [regex]::Match($text, '\[SUMMARY\]\s+would-write=(\d+) unchanged=(\d+)')
    $problems = @($preview | ForEach-Object ToString | Where-Object {$_ -match '^\[CHECK\].*\sFAIL\s|^\[WARN\]'})
    $differences = @($preview | ForEach-Object ToString | Where-Object {$_ -match '^\[DIFF\]'} | ForEach-Object {$_ -replace '^\[DIFF\]\s*',''})
    $valid = $previewCode -eq 0 -and $count.Success -and $problems.Count -eq 0
    $result.global = @{
        status = $(if (-not $valid) {'INVALID'} elseif ([int]$count.Groups[1].Value -gt 0) {'OUTDATED_OR_MISSING'} else {'COMPLETE'})
        different_files = $differences; problems = $problems
        scope = 'installer-managed files; excludes credentials, machine-local settings and plugin installation'
    }
    if ($result.global.status -ne 'COMPLETE') {
        $result.next_steps += "Review $installer -DryRun -NoPluginInstall; deploy the canonical main version with the same target roots when authorized."
    }
    $Repo = (Resolve-Path -LiteralPath $Repo).Path
    $gitRoot = & git -C $Repo rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0) {
        $result.project = @{status='NOT_A_GIT_PROJECT';path=$Repo}
        $result.next_steps += 'Initialize the intended project as a Git repository, then enroll it when authorized.'
    } else {
        $root = [IO.Path]::GetFullPath($gitRoot)
        $manifest = Join-Path $root 'team/manifest.yaml'
        $launcher = Join-Path $root 'team/scripts/team.ps1'
        $result.project = @{status='NOT_ENROLLED';path=$root;missing_files=@()}
        foreach ($file in @($manifest,$launcher)) {
            if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { $result.project.missing_files += $file }
        }
        if ($result.project.missing_files.Count) {
            $result.project.status = if ($result.project.missing_files.Count -eq 2) {'NOT_ENROLLED'} else {'INCOMPLETE'}
        } elseif (Test-Path -LiteralPath (Join-Path $root 'team/runtime/.team-lock')) {
            $result.project.status = 'ACTIVE_RUN_NOT_CHECKED'
            $result.next_steps += 'Inspect the existing Team run before changing its deployment.'
        } elseif ($result.global.status -ne 'COMPLETE') {
            $result.project.status = 'PRESENT_GLOBAL_REPAIR_REQUIRED'
        } else {
            # The enrollment preview checks the actual hook, launcher and ignore rules,
            # while preserving project-specific manifest settings.
            $projectPreview = @(& pwsh -NoProfile -File $enroller -Repo $root -RuntimeRoot (Join-Path $CodexDir 'team') -DryRun 2>&1)
            if ($LASTEXITCODE -ne 0) { throw 'Project enrollment preview failed; inspect the existing launcher, active run and instructions before repair.' }
            $enrollment = ($projectPreview -join "`n") | ConvertFrom-Json
            $result.project.different_files = @($enrollment.files)
            . (Join-Path $SourceRoot 'team/scripts/Core.ps1')
            $config = Read-TeamData $manifest
            Test-TeamSchema $config 'manifest'
            $result.project.enabled = $config.team.enabled
            $result.project.status = if ($enrollment.files.Count) {'INCOMPLETE'} elseif (-not $config.team.enabled) {'DISABLED'} else {'COMPLETE'}
        }
        if ($result.project.status -in @('NOT_ENROLLED','INCOMPLETE')) {
            $result.next_steps += "Review $enroller -Repo '$root' -DryRun; enroll when authorized."
        }
    }
    $result.status = if ($result.global.status -eq 'COMPLETE' -and $result.project.status -in @('COMPLETE','DISABLED')) {'READY'} else {'ATTENTION'}
} catch {
    $result.status = 'CHECK_FAILED'
    $result['error'] = $_.Exception.Message
}
$result | ConvertTo-Json -Depth 8 -Compress
if ($result.status -eq 'CHECK_FAILED') { exit 2 }
if ($result.status -eq 'ATTENTION') { exit 1 }
exit 0
