# Child process owns the native harness and writes a durable exit receipt.
# A coordinator crash cannot turn a missing process into a successful result.
#requires -Version 7.4
param(
    [Parameter(Mandatory)][string]$TaskFile,
    [Parameter(Mandatory)][string]$Worktree,
    [Parameter(Mandatory)][string]$OutputFile,
    [Parameter(Mandatory)][string]$Patch,
    [string]$Profile = 'headless',
    [int]$TimeoutSeconds = 3600,
    [int]$IdleTimeoutSeconds = 900,
    [int]$MaxSingleLogMb = 50,
    [int]$MaxPromptChars = 24000,
    [long]$MaxPromptBytes = 4000000,
    [ValidateSet('worker','local-review')][string]$Mode = 'worker',
    [string]$PromptFile
)
. (Join-Path $PSScriptRoot 'Core.ps1')
. (Join-Path $PSScriptRoot 'Contracts.ps1')
$directory = Split-Path $OutputFile -Parent
$code = 30
$handle=$null; $startupExhausted=$false; $launchAttempts=0; $inputTooLarge=$false
try {
    $task = Read-TeamData $TaskFile
    Test-TeamTask $task
    if ($task['result_schema_sha256'] -and $task.result_schema_sha256 -cne (Get-TeamHash (Join-Path $script:TeamRoot 'schemas/result.schema.json'))) { Stop-TeamError 80 'Result schema differs from the frozen task schema identity' }
    $prompt = @"
Execute the attached task packet using the DSH native harness. Read the target
repository AGENTS.md first. The packet is the exact scope of this assignment.
Use role.definition for domain guidance and preferred verification. Its default scopes
and permissions are planning suggestions, never authorization to expand this packet's
effective write_scope, permissions, acceptance, verification, or subagent limits.
Integration role restrictions are mandatory: preserve approved interfaces and acceptance;
adapt a test only for an integration break or an already-approved contract, never to
hide a defect. Escalate a new business or architecture decision to the Lead.
Do not modify main, other worktrees, runtime files, profiles, or credentials.
Native subagents are permitted only if task.subagents.allowed is true. When allowed,
use only native subagent/subagent_fork, at most two children total across this worker,
depth at most two. Pass the same permission and write-scope limits to every child.
Include each child in subagents_used. The native guard rejects extra creations.
Network/secrets/production permissions are declarations, not an OS sandbox.
If the task requires any disallowed action, return status=escalated.
Implement only the objective, run self-checks, commit only assigned files on
your assigned branch, and leave a clean worktree. Never use git add -A.
Return ONLY a JSON Result Packet matching this schema; no Markdown fences.
Do not create the result file yourself; stdout is collected by the adapter.
Task packet:
$(Get-Content -LiteralPath $TaskFile -Raw)
Result schema:
$(Get-Content -LiteralPath (Join-Path $script:TeamRoot 'schemas/result.schema.json') -Raw)
"@
    if ($Mode -eq 'local-review') {
        if (-not $PromptFile) { Stop-TeamError 10 'Local review requires its allowlisted prompt file' }
        $prompt=[IO.File]::ReadAllText($PromptFile)
    }
    $promptBytes=[Text.Encoding]::UTF8.GetByteCount($prompt)
    if ($promptBytes -gt $MaxPromptBytes) {
        $startupExhausted=$true; $inputTooLarge=$true
        Stop-TeamInputCapacity "DSH prompt input too large ($promptBytes UTF-8 bytes, limit $MaxPromptBytes); split/replan the task"
    }
    # The native runner accepts config.task. A JSON patch carries literal UTF-8 text without
    # asking the model to read a file (local reviewers deliberately have no tools).
    $transport='argv'; $promptPatch=$null
    if ($prompt.Length -gt $MaxPromptChars) {
        $transport='native-config-file'
        $promptPatch=Join-Path $directory 'prompt-input.patch.json'
        # -InputObject preserves the top-level array when it contains a single patch entry.
        $patchJson=ConvertTo-Json -InputObject @(@{id='headless-runner';config=@{task=$prompt}}) -Depth 10
        [IO.File]::WriteAllText($promptPatch,$patchJson,[Text.UTF8Encoding]::new($false))
        $dshArguments=@('--profile',$Profile,'--patch',$Patch,'--patch',$promptPatch,'Team task supplied through native runner configuration.')
    } else {
        $dshArguments=@('--profile',$Profile,'--patch',$Patch,$prompt)
    }
    Write-TeamData (Join-Path $directory 'input-transport.json') @{
        transport=$transport;characters=$prompt.Length;utf8_bytes=$promptBytes
        prompt_sha256=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($prompt))).ToLowerInvariant()
        patch_file=$promptPatch
    }
    # Check the second native launch made by the installed npm PowerShell shim too.
    if ($IsWindows) {
        $shimCommand=Get-Command dsh -ErrorAction SilentlyContinue
        $shim=if ($shimCommand) {$shimCommand.Source} else {''}
        $bin=if ($shim) {Join-Path (Split-Path $shim -Parent) 'node_modules/@deepseek-ai/dsh/lib/bin.js'} else {''}
        if ($bin -and (Test-Path -LiteralPath $bin)) {
            $node=Join-Path (Split-Path $shim -Parent) 'node.exe'
            if (-not (Test-Path -LiteralPath $node)) {$node=(Get-Command node -ErrorAction Stop).Source}
            $null=Assert-TeamCommandLine $node (@($bin)+$dshArguments)
        }
    }
    $handle = Start-TeamDshProcess $directory $Worktree $dshArguments ($MaxSingleLogMb * 1MB)
    $launchAttempts=$handle.launch_attempts
    Write-TeamData (Join-Path $directory 'native-process.json') @{
        pid = $handle.process.Id; start = $handle.process.StartTime.ToUniversalTime().ToString('o')
    }
    $code = Wait-TeamProcess $handle $TimeoutSeconds $IdleTimeoutSeconds
    if ($code -eq 0) {
        $parsed = Read-TeamWorkerOutput (Join-Path $directory 'worker.stdout') -Schema $(if ($Mode -eq 'local-review') {'review'} else {'result'})
        Write-TeamData (Join-Path $directory 'result-source.json') @{format=$parsed.format;stdout_sha256=$parsed.stdout_sha256}
        Write-TeamData $OutputFile $parsed.packet
    }
} catch {
    $code = if ($_.Exception.Data.Contains('TeamExitCode')) { [int]$_.Exception.Data['TeamExitCode'] } else { 30 }
    $inputTooLarge=$inputTooLarge -or $_.Exception.Data['InputTooLarge'] -eq $true
    $startupExhausted=$inputTooLarge -or $_.Exception.Data['StartupExhausted'] -eq $true
    if ($_.Exception.Data.Contains('LaunchAttempts')) { $launchAttempts=[int]$_.Exception.Data['LaunchAttempts'] }
    [Console]::Error.WriteLine($_.Exception.Message)
} finally {
    try { if ($handle -and -not $handle['closed']) { $null=Close-TeamProcess $handle -Terminate } }
    finally {
        Write-TeamData (Join-Path $directory 'exit.json') @{
            exit_code=$code;native_exit_code=$(if ($handle) {$handle['exit_code']} else {$null})
            startup_exhausted=$startupExhausted;input_too_large=$inputTooLarge;launch_attempts=$launchAttempts
            transport_cleanup=(Get-TeamProcessCleanupEvidence $handle);finished_at=[DateTime]::UtcNow.ToString('o')
        }
    }
}
exit $code
