#requires -Version 7.4
[CmdletBinding()]
param([string]$Repo=(Get-Location).Path,[string]$Manifest,[string]$Prompt,[switch]$DryRun)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Core.ps1')
$Repo=(Resolve-Path -LiteralPath $Repo).Path
if (-not $Manifest) {$Manifest=Join-Path $Repo 'team/manifest.yaml'}
$config=Read-TeamData $Manifest; Test-TeamSchema $config 'manifest'
$arguments=@('-C',$Repo,'-m',$config.models.lead.runtime_model)
if ($Prompt) {$arguments+=@($Prompt)}
if ($DryRun) {
    @{executable='codex';arguments=$arguments;runtime_verified=$false;next='Team validates the actual active turn before dispatch'} | ConvertTo-Json -Depth 5
    exit 0
}
& codex @arguments
exit $LASTEXITCODE
