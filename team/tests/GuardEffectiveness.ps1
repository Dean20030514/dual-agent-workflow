# In-memory mutation only; never edits production source or a user's repository.
param([switch]$Mutate)
. (Join-Path $PSScriptRoot '../scripts/Core.ps1')
. (Join-Path $PSScriptRoot '../scripts/Contracts.ps1')
$fixture=Join-Path ([IO.Path]::GetTempPath()) ('team-guard-proof-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($fixture) | Out-Null
$repo=Join-Path $fixture 'repo'; [IO.Directory]::CreateDirectory($repo) | Out-Null
$null=Invoke-TeamGit $repo @('init','-q','-b','fixture')
$null=Invoke-TeamGit $repo @('config','user.name','GuardFixture')
$null=Invoke-TeamGit $repo @('config','user.email','fixture@example.invalid')
[IO.File]::WriteAllText((Join-Path $repo 'allowed.txt'),'base')
$null=Invoke-TeamGit $repo @('add','allowed.txt'); $null=Invoke-TeamGit $repo @('commit','-qm','test: base')
$base=Invoke-TeamGit $repo @('rev-parse','HEAD')
[IO.File]::WriteAllText((Join-Path $repo 'allowed.txt'),'changed')
[IO.File]::WriteAllText((Join-Path $repo 'forbidden.txt'),'out of scope')
$null=Invoke-TeamGit $repo @('add','allowed.txt','forbidden.txt'); $null=Invoke-TeamGit $repo @('commit','-qm','test: violation')
$head=Invoke-TeamGit $repo @('rev-parse','HEAD')
$task=@{id='T1';write_scope=@('allowed.txt');subagents=@{allowed=$false};permissions=@{shell=$true;network=$false;secrets=$false;production=$false}}
Write-TeamData (Join-Path $fixture 'result.yaml') @{schema_version=1;run_id='R1';task_id='T1';status='completed';summary=@('fixture');changed_files=@('allowed.txt','forbidden.txt');verification=@{passed=$true};subagents_used=@();risks=@();git=@{branch='fixture';commit=$head}}
if ($Mutate) { function Test-TeamScope { return $true } }
try {
    $null=Read-WorkerResult @{directory=$fixture;worktree=$repo;branch='fixture';base_sha=$base} $task 'R1'
    [Console]::Error.WriteLine('GUARD_ASSERTION_FAILED: out-of-scope committed file was accepted')
    exit 1
} catch {
    if ($_.Exception.Data['TeamExitCode'] -eq 82) { Write-Output 'GUARD_ASSERTION_PASSED: actual Git scope violation rejected'; exit 0 }
    throw
}
