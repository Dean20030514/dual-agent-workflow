# Child process owns the native harness and writes a durable exit receipt.
# A coordinator crash cannot turn a missing process into a successful result.
#requires -Version 7.4
param(
    [Parameter(Mandatory)][string]$TaskFile,
    [Parameter(Mandatory)][string]$Worktree,
    [Parameter(Mandatory)][string]$OutputFile,
    [Parameter(Mandatory)][string]$Patch,
    [string]$Profile = 'headless',
    [int]$TimeoutSeconds = 3600
)
. (Join-Path $PSScriptRoot 'Core.ps1')
. (Join-Path $PSScriptRoot 'Contracts.ps1')
$directory = Split-Path $OutputFile -Parent
$code = 30
try {
    $task = Read-TeamData $TaskFile
    Test-TeamTask $task
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
    $dsh = (Get-Command dsh -ErrorAction Stop).Source
    $handle = New-TeamProcess $dsh @('--profile',$Profile,'--patch',$Patch,$prompt) $Worktree (Join-Path $directory 'worker.stdout') (Join-Path $directory 'worker.stderr')
    Write-TeamData (Join-Path $directory 'native-process.json') @{
        pid = $handle.process.Id; start = $handle.process.StartTime.ToUniversalTime().ToString('o')
    }
    $code = Wait-TeamProcess $handle $TimeoutSeconds
    if ($code -eq 0) {
        $parsed = Read-TeamWorkerOutput (Join-Path $directory 'worker.stdout')
        Write-TeamData (Join-Path $directory 'result-source.json') @{format=$parsed.format;stdout_sha256=$parsed.stdout_sha256}
        Write-TeamData $OutputFile $parsed.packet
    }
} catch {
    $code = if ($_.Exception.Data.Contains('TeamExitCode')) { [int]$_.Exception.Data['TeamExitCode'] } else { 30 }
    [Console]::Error.WriteLine($_.Exception.Message)
} finally {
    Write-TeamData (Join-Path $directory 'exit.json') @{ exit_code = $code; finished_at = [DateTime]::UtcNow.ToString('o') }
}
exit $code
