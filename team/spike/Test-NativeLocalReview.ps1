# Paid native author + independent DSH local review in an isolated Git repository.
# This does not invoke Codex review or modify/deploy the user's repository.
#requires -Version 7.4
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../scripts/Core.ps1')
$root=Join-Path ([IO.Path]::GetTempPath()) ('team-local-review-live-'+[guid]::NewGuid().ToString('N').Substring(0,10))
$repo=Join-Path $root 'repo'; [IO.Directory]::CreateDirectory($repo) | Out-Null
$cli=Join-Path $script:TeamRoot 'scripts/team.ps1'
function Invoke-NativeReviewCli([string[]]$Arguments) {
    $raw=& pwsh -NoProfile -File $cli @Arguments -Repo $repo -Json
    $code=$LASTEXITCODE; $data=$raw | ConvertFrom-Json -AsHashtable
    if ($code -ne 0) { throw "Team command exited ${code}; evidence: $root; response: $($raw -join ' ')" }
    return $data
}
$null=Invoke-TeamGit $repo @('init','-q','-b','main')
$null=Invoke-TeamGit $repo @('config','user.name','Team Native Acceptance')
$null=Invoke-TeamGit $repo @('config','user.email','fixture@example.invalid')
[IO.File]::WriteAllText((Join-Path $repo '.gitignore'),"team/runtime/`n.worktrees/`n",[Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $repo 'AGENTS.md'),"# Fixture contract`nUse PowerShell. Modify and commit only the assigned query file. Do not change verification.ps1. Reviewers must not write or run tests.`n",[Text.UTF8Encoding]::new($false))
$verify=@'
$ErrorActionPreference='Stop'
$actual=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'queries/health.sql'))
if ($actual -cnotmatch '^SELECT 1;\r?\n\z') { throw 'Query must contain exactly SELECT 1; and a final newline' }
Write-Output 'QUERY_CONTENT_PASS'
'@
[IO.File]::WriteAllText((Join-Path $repo 'verification.ps1'),$verify,[Text.UTF8Encoding]::new($false))
$null=Invoke-TeamGit $repo @('add','--','.gitignore','AGENTS.md','verification.ps1')
$null=Invoke-TeamGit $repo @('commit','-qm','test: seed local review acceptance fixture')
$base=Invoke-TeamGit $repo @('rev-parse','HEAD')
$plan=Read-TeamData (Join-Path $script:TeamRoot 'tests/plans/L1-sql.yaml')
$plan.run.id='LOCAL-NATIVE-013'
$command=@{id='query-content';executable='pwsh';args=@('-NoProfile','-File','verification.ps1');timeout_seconds=15}
$plan.tasks[0].verification=@($command); $plan.verification.final=@($command)
$planPath=Join-Path $root 'plan.json'; Write-TeamData $planPath $plan
$null=Invoke-NativeReviewCli @('run','-Plan',$planPath)
$state=Invoke-NativeReviewCli @('status','-Run',$plan.run.id)
$task=$state.tasks['SQL-001']
$record=Read-TeamData (Join-Path $repo "team/runtime/$($plan.run.id)/reviews/LOCAL-SQL-001.json")
if ($task.status -ne 'REVIEW' -or $state.agents_created -ne 2 -or $record.verdict.verdict -ne 'pass') { throw 'Native local review did not reach the expected bound acceptance state' }
$author=Read-TeamData (Join-Path $task.directory 'agents.json')
$reviewer=Read-TeamData (Join-Path $record.holding 'agents.json')
if ($author.agents[0].id -ceq $reviewer.agents[0].id -or -not $reviewer.agents[0].read_only) { throw 'Local reviewer identity or tool restriction was not established' }
$null=Invoke-NativeReviewCli @('accept','-Run',$plan.run.id,'-Task','SQL-001','-Commit',$task.commit,'-Reason','Exact query contract, external verification and independent DSH local verdict passed')
$integrated=Invoke-NativeReviewCli @('integrate','-Run',$plan.run.id)
if ($integrated.status -ne 'COMPLETED' -or (Invoke-TeamGit $repo @('rev-parse','main')) -cne $base -or
    (Invoke-TeamGit $repo @('status','--porcelain','--untracked-files=all'))) { throw 'Native acceptance altered main or failed final integration' }
$summary=@{passed=$true;directory=$root;base=$base;worker_commit=$task.commit;integration_commit=$integrated.commit;
    author_session=$author.agents[0].id;review_session=$reviewer.agents[0].id;read_only=$reviewer.agents[0].read_only;
    verdict_sha256=$record.verdict_hash;input_sha256=$record.input_hash;agents_created=$state.agents_created}
Write-TeamData (Join-Path $root 'acceptance.json') $summary
$summary | ConvertTo-Json -Compress
