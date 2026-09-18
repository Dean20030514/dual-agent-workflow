#requires -Version 7.4
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string[]]$Repo,
    [string]$RuntimeRoot,
    [string]$BackupRoot,
    [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
$codexRoot = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE '.codex' }
if (-not $RuntimeRoot) { $RuntimeRoot = Join-Path $codexRoot 'team' }
$RuntimeRoot = [IO.Path]::GetFullPath($RuntimeRoot)
if (-not $BackupRoot) {
    $BackupRoot = Join-Path $codexRoot ('deployment-backups/team-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0,8))
}
foreach ($required in @('scripts/team.ps1', 'scripts/Core.ps1', 'manifest.yaml', 'policies/codex-lead-prompt.md')) {
    if (-not (Test-Path -LiteralPath (Join-Path $RuntimeRoot $required) -PathType Leaf)) { throw "Missing shared runtime asset: $required. Run install.ps1 first." }
}
$launcher = @'
#requires -Version 7.4
# Team shared-runtime launcher. Project configuration and state stay in this repo.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$codexRoot = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE '.codex' }
$entry = Join-Path $codexRoot 'team/scripts/team.ps1'
if (-not (Test-Path -LiteralPath $entry -PathType Leaf)) {
    throw 'Shared Team runtime missing. Deploy workflow/install.ps1 before using this launcher.'
}
& pwsh -NoProfile -File $entry @args -Repo $repoRoot -Manifest (Join-Path $repoRoot 'team/manifest.yaml')
exit $LASTEXITCODE
'@
$hook = @'
<!-- codex-team:start -->
## Codex Team Mode

本项目启用 Codex Lead + DSH Worker。实现任务先读 `team/manifest.yaml`。
共享运行器位于 `$CODEX_HOME/team`（未设置时为 `~/.codex/team`）；先读取其中
`policies/` 下的 `codex-lead-prompt.md`、`activation.md`、`delegation.md`、`review-mapping.md`。
按任务价值选择 L0/L1/L2/L3；L0 直接完成，L1–L3 先生成并验证 Team Plan，再派发原生 DSH。
项目入口：`pwsh -NoProfile -File ./team/scripts/team.ps1 doctor -Json`；
同一入口提供 route/validate/run/status/resume，自动绑定本项目 Repo 和 manifest。
先确认当前工作树与任务基线；未提交的既有修改不能被 worktree Worker 当作已包含的输入。
Team 不扩大任务授权，不替代本文件的业务规则、Git 限制或审查模式；审查请求仍遵守 Reviewer 零写入。
若后文因文件较长未完整加载，应按当前任务定位并读取相关原有规则。
<!-- codex-team:end -->

'@
$changes = [Collections.Generic.List[object]]::new()
$results = [Collections.Generic.List[object]]::new()
foreach ($path in $Repo) {
    $root = (Resolve-Path -LiteralPath $path).Path.TrimEnd('\','/')
    $gitRoot = & git -C $root rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0 -or [IO.Path]::GetFullPath($gitRoot).TrimEnd('\','/') -ine $root) { throw "Expected a Git repository root: $root" }
    if (Test-Path -LiteralPath (Join-Path $root 'team/runtime/.team-lock')) { throw "Team run lock exists: $root" }
    if (Test-Path -LiteralPath (Join-Path $root 'team/scripts/Core.ps1')) {
        $results.Add([pscustomobject]@{repo=$root;runtime='repository';changed=0})
        continue
    }
    $agentName = if (Test-Path -LiteralPath (Join-Path $root 'AGENTS.override.md')) {'AGENTS.override.md'} else {'AGENTS.md'}
    $agentPath = Join-Path $root $agentName
    $oldAgent = if (Test-Path -LiteralPath $agentPath) {[IO.File]::ReadAllText($agentPath)} else {''}
    $body = [regex]::Replace($oldAgent, '(?s)\A<!-- codex-team:start -->.*?<!-- codex-team:end -->\r?\n(?:\r?\n)?', '')
    if ($body.Contains('<!-- codex-team:start -->')) { throw "Unexpected Team block position in $agentPath; preserve and inspect manually." }
    $ignorePath = Join-Path $root '.gitignore'
    $oldIgnore = if (Test-Path -LiteralPath $ignorePath) {[IO.File]::ReadAllText($ignorePath)} else {''}
    $newIgnore = $oldIgnore
    foreach ($pattern in @('/team/runtime/', '/.worktrees/')) {
        if ($pattern -notin ($newIgnore -split '\r?\n')) {
            if ($newIgnore.Length -and -not $newIgnore.EndsWith("`n")) { $newIgnore += "`n" }
            $newIgnore += "$pattern`n"
        }
    }
    $files = [ordered]@{
        $agentName = $hook.TrimEnd() + "`n`n" + $body
        '.gitignore' = $newIgnore
        'team/scripts/team.ps1' = $launcher.TrimEnd() + "`n"
    }
    $manifestPath = Join-Path $root 'team/manifest.yaml'
    if (-not (Test-Path -LiteralPath $manifestPath)) { $files['team/manifest.yaml'] = [IO.File]::ReadAllText((Join-Path $RuntimeRoot 'manifest.yaml')) }
    $count = 0
    foreach ($relative in $files.Keys) {
        $target = Join-Path $root $relative
        $exists = Test-Path -LiteralPath $target
        if ($exists -and [IO.File]::ReadAllText($target) -ceq $files[$relative]) { continue }
        if ($relative -eq 'team/scripts/team.ps1' -and $exists -and -not ([IO.File]::ReadAllText($target).Contains('# Team shared-runtime launcher.'))) {
            throw "Existing unrelated launcher will not be overwritten: $target"
        }
        $changes.Add([pscustomobject]@{path=$target;content=$files[$relative];existing=$exists})
        $count++
    }
    $results.Add([pscustomobject]@{repo=$root;runtime='shared';changed=$count})
}
# All projects are checked before any writes. Back up each exact file before replacing it.
foreach ($change in $changes) {
    if ($DryRun) { continue }
    if ($change.existing) {
        [IO.Directory]::CreateDirectory($BackupRoot) | Out-Null
        $backup = Join-Path $BackupRoot ([guid]::NewGuid().ToString('N') + '-' + [IO.Path]::GetFileName($change.path))
        [IO.File]::Copy($change.path, $backup, $false)
        Add-Content -LiteralPath (Join-Path $BackupRoot 'index.jsonl') -Value (@{path=$change.path;backup=$backup} | ConvertTo-Json -Compress) -Encoding utf8NoBOM
    }
    [IO.Directory]::CreateDirectory((Split-Path $change.path -Parent)) | Out-Null
    [IO.File]::WriteAllText($change.path, $change.content, [Text.UTF8Encoding]::new($false))
}
[pscustomobject]@{dry_run=[bool]$DryRun;backup_root=$BackupRoot;projects=$results.ToArray();files=@($changes | Select-Object -ExpandProperty path)} | ConvertTo-Json -Depth 5
