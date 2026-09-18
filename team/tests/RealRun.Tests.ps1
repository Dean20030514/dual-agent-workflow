BeforeAll {
    $script:TeamPath = Split-Path $PSScriptRoot -Parent
    foreach ($module in @('Core','Lead','Contracts','Preflight','State','Controls','Execution','IntegrationRecovery','Checkpoints',
        'Revisions','Rollbacks','Integration','Recovery','ReviewRounds','Review','LocalReview','Conflict','Activity','Reuse',
        'Prerequisites','Archive','Report')) {
        . (Join-Path $script:TeamPath "scripts/$module.ps1")
    }
    $script:ManifestData = Read-TeamData (Join-Path $script:TeamPath 'manifest.yaml')

    function Catch-TeamError($Action) {
        try { & $Action | Out-Null } catch { return $_.Exception }
        throw 'Expected a Team error'
    }
    function New-TestRepo([string]$Name) {
        $repo = Join-Path $TestDrive $Name
        [IO.Directory]::CreateDirectory($repo) | Out-Null
        $null = Invoke-TeamGit $repo @('init','-q')
        $null = Invoke-TeamGit $repo @('config','user.name','Fixture')
        $null = Invoke-TeamGit $repo @('config','user.email','fixture@example.invalid')
        $null = Invoke-TeamGit $repo @('config','core.autocrlf','false')
        return $repo
    }
    function Add-TestCommit([string]$Repo, [string]$Message) {
        $null = Invoke-TeamGit $Repo @('add','-A')
        $null = Invoke-TeamGit $Repo @('commit','-qm',$Message)
        return (Invoke-TeamGit $Repo @('rev-parse','HEAD'))
    }
    # A run worktree the finalizer is allowed to own: it lives under <repo>/.worktrees/.
    function New-TestRunWorktree([string]$Repo, [string]$RunId, [string]$Base) {
        $path = Join-Path $Repo ".worktrees/$RunId-T1-generalist-a1"
        $branch = "codex/team/$RunId/T1/generalist-a1"
        $null = Invoke-TeamGit $Repo @('worktree','add','-q','-b',$branch,$path,$Base)
        return @{ path = $path; branch = $branch }
    }
    function New-TestRunDirectory([string]$Repo, [string]$RunId, [string]$Branch, [string]$Worktree, [string]$Base, [string]$Commit) {
        $directory = Join-Path $Repo "team/runtime/$RunId"
        $attempt = Join-Path $directory 'tasks/T1/attempt-1'
        [IO.Directory]::CreateDirectory($attempt) | Out-Null
        Write-TeamData (Join-Path $attempt 'agents.json') @{ agents = @(@{ id = 'fixture-agent'; depth = 0; state = 'created' }) }
        [IO.File]::WriteAllText((Join-Path $directory 'events.jsonl'), '', [Text.UTF8Encoding]::new($false))
        $state = @{ schema_version = 1; run_id = $RunId; revision = 1; repo = $Repo; status = 'COMPLETED'
            run_base_sha = $Base; integration_base_sha = $Base; last_good_integration_sha = $Commit
            integration_branch = "codex/integration/$RunId"; integration_worktree = ''; plan_hash = ('a' * 64); order = @('T1')
            tasks = @{ T1 = @{ status = 'MERGED'; attempts = 1; commit = $Commit; pid = 0; process_start = ''
                directory = $attempt; worktree = $Worktree; branch = $Branch; base_sha = $Base; reserved = 0 } }
            agents_created = 1; agents_reserved = 0
            cost_ledgers = @{ astra = @{ unit = 'credits'; known_cost = 0.0 }; deepseek = @{ unit = 'USD'; known_cost = 0.0 } }
            unknown_usage = $true; replans = 0 }
        Write-TeamData (Join-Path $directory 'state.json') $state
        return @{ directory = $directory; attempt = $attempt; state = $state }
    }
    function New-TestRuntime { return @{ max_single_log_mb = 5; idle_timeout_seconds = 30; max_diff_bytes = 2000000; max_review_input_bytes = 4000000 } }
}

Describe 'Worktree activity fingerprint' {
    It 'keeps two retries by default and bounds an explicit three-retry configuration' {
        $config = Read-TeamData (Join-Path $script:TeamPath 'manifest.yaml')
        $config.budget.max_worker_retries | Should -Be 2
        $config.budget.max_worker_retries = 3
        { Test-TeamSchema $config 'manifest' } | Should -Not -Throw
        $config.budget.max_worker_retries = 4
        { Test-TeamSchema $config 'manifest' } | Should -Throw
    }
    It 'binds content, so touching an already dirty file is not work' {
        $repo = New-TestRepo 'fingerprint'; Set-Content -LiteralPath (Join-Path $repo 'a.txt') 'one'
        $null = Add-TestCommit $repo 'test: base'
        $clean = Get-TeamWorktreeFingerprint $repo
        $clean.changed_files | Should -Be 0
        Set-Content -LiteralPath (Join-Path $repo 'a.txt') 'two'
        $edited = Get-TeamWorktreeFingerprint $repo
        $edited.material_sha256 | Should -Not -Be $clean.material_sha256
        (Get-Item (Join-Path $repo 'a.txt')).LastWriteTimeUtc = [datetime]::UtcNow.AddMinutes(10)
        (Get-TeamWorktreeFingerprint $repo).material_sha256 | Should -Be $edited.material_sha256
        Set-Content -LiteralPath (Join-Path $repo 'a.txt') 'three'
        (Get-TeamWorktreeFingerprint $repo).material_sha256 | Should -Not -Be $edited.material_sha256
    }
    It 'parses Chinese, spaced and renamed paths from raw NUL fields' {
        $repo = New-TestRepo 'nulpaths'
        Set-Content -LiteralPath (Join-Path $repo 'space name.txt') 'sp'
        Set-Content -LiteralPath (Join-Path $repo '中文 文件.txt') 'cn'
        $null = Add-TestCommit $repo 'test: base'
        $null = Invoke-TeamGit $repo @('mv','space name.txt','renamed name.txt')
        Set-Content -LiteralPath (Join-Path $repo '中文 文件.txt') 'cn2'
        $fingerprint = Get-TeamWorktreeFingerprint $repo
        $fingerprint.changed_files | Should -Be 2
        $fingerprint.status | Should -Match '中文 文件\.txt'
        $fingerprint.status | Should -Not -Match '"'
        $fingerprint.status | Should -Match 'renamed name\.txt'
        $fingerprint.marks | Should -Match '中文 文件\.txt\|\|[0-9]+/[0-9]+/[0-9a-f]{64}'
    }
    It 'excludes dependency, runtime and log loops from authored activity' {
        $repo = New-TestRepo 'exclusions'
        [IO.File]::WriteAllText((Join-Path $repo '.gitignore'), "node_modules/`n", [Text.UTF8Encoding]::new($false))
        Set-Content -LiteralPath (Join-Path $repo 'src.txt') 'one'
        $null = Add-TestCommit $repo 'test: base'
        Set-Content -LiteralPath (Join-Path $repo 'src.txt') 'two'
        $store = Join-Path $repo 'node_modules/.pnpm/foo@1.0.0/node_modules'
        [IO.Directory]::CreateDirectory($store) | Out-Null
        Set-Content -LiteralPath (Join-Path $store 'index.js') 'module.exports=1'
        $null = New-Item -ItemType Junction -Path (Join-Path $repo 'node_modules/foo') -Target $store
        $fingerprint = Get-TeamWorktreeFingerprint $repo
        $fingerprint.changed_files | Should -Be 1
        $fingerprint.truncated | Should -BeFalse
    }
}

Describe 'Idle deadline follows observed work' {
    It 'keeps a quiet child alive while it really edits the worktree' {
        $repo = New-TestRepo 'quiet-worker'
        Set-Content -LiteralPath (Join-Path $repo 'src.txt') 'base'
        $null = Add-TestCommit $repo 'test: base'
        $out = Join-Path $TestDrive 'quiet.stdout'; $err = Join-Path $TestDrive 'quiet.stderr'
        $child = "`$end=[datetime]::UtcNow.AddSeconds(5); while ([datetime]::UtcNow -lt `$end) { Set-Content -LiteralPath (Join-Path `$PWD 'work.txt') ([guid]::NewGuid().ToString()); Start-Sleep -Milliseconds 250 }"
        $handle = New-TeamProcess 'pwsh' @('-NoProfile','-Command',$child) $repo $out $err -MaxOutputBytes 1MB
        try {
            $probe = New-TeamActivityProbe -Worktree $repo -RootPid $handle.process.Id -ReceiptPath (Join-Path $TestDrive 'quiet-activity.json')
            $code = Wait-TeamProcess $handle 60 3 -ActivityProbe $probe
            $handle['activity_probe_error'] | Should -BeNullOrEmpty
            $code | Should -Be 0
            $handle.last_activity_kind | Should -Be 'worktree'
            (Get-Item $out).Length | Should -Be 0
            (Read-TeamData (Join-Path $TestDrive 'quiet-activity.json')).fingerprint_truncated | Should -BeFalse
        } finally { if (-not $handle['closed']) { $null = Close-TeamProcess $handle -Terminate } }
    }
    It 'still kills a child whose only change is a repeated touch of an unchanged file' {
        $repo = New-TestRepo 'touch-worker'
        Set-Content -LiteralPath (Join-Path $repo 'src.txt') 'base'
        Set-Content -LiteralPath (Join-Path $repo 'work.txt') 'constant'
        $null = Add-TestCommit $repo 'test: base'
        Set-Content -LiteralPath (Join-Path $repo 'work.txt') 'constant'
        $out = Join-Path $TestDrive 'touch.stdout'; $err = Join-Path $TestDrive 'touch.stderr'
        $child = "`$end=[datetime]::UtcNow.AddSeconds(30); while ([datetime]::UtcNow -lt `$end) { Set-Content -LiteralPath (Join-Path `$PWD 'work.txt') 'constant'; Start-Sleep -Milliseconds 250 }"
        $handle = New-TeamProcess 'pwsh' @('-NoProfile','-Command',$child) $repo $out $err -MaxOutputBytes 1MB
        try {
            $probe = New-TeamActivityProbe -Worktree $repo -RootPid $handle.process.Id -ReceiptPath (Join-Path $TestDrive 'touch-activity.json')
            $failure = Catch-TeamError { Wait-TeamProcess $handle 60 3 -ActivityProbe $probe }
            $failure.Data['TeamExitCode'] | Should -Be 31
            $failure.Data['TimeoutKind'] | Should -Be 'idle'
            $handle.timeout_kind | Should -Be 'idle'
        } finally { if (-not $handle['closed']) { $null = Close-TeamProcess $handle -Terminate } }
    }
    It 'distinguishes a hard deadline from an idle deadline' {
        $repo = New-TestRepo 'hard-deadline'
        Set-Content -LiteralPath (Join-Path $repo 'src.txt') 'base'
        $null = Add-TestCommit $repo 'test: base'
        $out = Join-Path $TestDrive 'hard.stdout'; $err = Join-Path $TestDrive 'hard.stderr'
        $handle = New-TeamProcess 'pwsh' @('-NoProfile','-Command','Start-Sleep -Seconds 30') $repo $out $err -MaxOutputBytes 1MB
        try {
            $failure = Catch-TeamError { Wait-TeamProcess $handle 2 0 }
            $failure.Data['TimeoutKind'] | Should -Be 'hard'
        } finally { if (-not $handle['closed']) { $null = Close-TeamProcess $handle -Terminate } }
    }
}

Describe 'Opt-in deterministic verification reuse' {
    BeforeAll {
        function New-ReuseFixture {
            $repo = New-TestRepo ('reuse-' + [guid]::NewGuid().ToString('N'))
            Set-Content -LiteralPath (Join-Path $repo 'src.txt') 'base'
            $null = Add-TestCommit $repo 'test: base'
            $directory = Join-Path $TestDrive ('reuse-state-' + [guid]::NewGuid().ToString('N'))
            [IO.Directory]::CreateDirectory($directory) | Out-Null
            return @{ repo = $repo; directory = $directory
                command = @{ id = 'c1'; executable = 'pwsh'; args = @('-NoProfile','-Command','Write-Output cached-verification')
                    timeout_seconds = 60; environment_fingerprint = 'isolated-fixture:none' }
                runtime = New-TestRuntime }
        }
        function Invoke-ReuseVerification($Fixture, [switch]$Reuse) {
            return Invoke-TeamVerification @($Fixture.command) $Fixture.repo $Fixture.directory 'verification' $Fixture.runtime -Reuse:$Reuse -CacheDirectory $Fixture.directory
        }
    }
    It 'records a missing executable failure when verification reuse is requested' {
        $fixture = New-ReuseFixture
        $fixture.command.executable = Join-Path $TestDrive 'nonexistent-tool.exe'
        $failure = Catch-TeamError { Invoke-ReuseVerification $fixture -Reuse }
        $failure.Data['TeamExitCode'] | Should -Be 40
        $saved = @(Read-TeamData (Join-Path $fixture.directory 'verification-evidence.json'))[0]
        $saved.process_started | Should -BeFalse
        $saved.exit_code | Should -Be 30
        $saved.reused | Should -BeFalse
        $saved.error | Should -Not -BeNullOrEmpty
    }
    It 'executes by default and only reuses when the caller opts in' {
        $fixture = New-ReuseFixture
        $first = @(Invoke-ReuseVerification $fixture)[0]
        $first.reused | Should -BeFalse
        $first.reuse_opted_in | Should -BeFalse
        $second = @(Invoke-ReuseVerification $fixture)[0]
        $second.reused | Should -BeFalse
        $third = @(Invoke-ReuseVerification $fixture -Reuse)[0]
        $third.reused | Should -BeFalse -Because 'the first opt-in run populates the cache'
        $fourth = @(Invoke-ReuseVerification $fixture -Reuse)[0]
        $fourth.reused | Should -BeTrue
        $fourth.exit_code | Should -Be 0
        $fourth.reuse_key | Should -Match '^[a-f0-9]{64}$'
        Get-Content -LiteralPath (Join-Path $fixture.directory 'verification-c1-r4.stdout') | Should -Match 'cached-verification'
    }
    It 'rejects pre-post-binding cache receipts and preserves them when executing again' {
        $fixture = New-ReuseFixture
        $null = Invoke-ReuseVerification $fixture -Reuse
        $binding = Get-TeamVerificationKey $fixture.repo $fixture.command.executable $fixture.command.args $fixture.command
        $path = Get-TeamVerificationCachePath $fixture.directory $binding.key
        $old = Read-TeamData $path; $old.schema_version = 1; Write-TeamData $path $old
        $result = @(Invoke-ReuseVerification $fixture -Reuse)[0]
        $result.reused | Should -BeFalse
        $result.reuse_rejected | Should -Be 'legacy_receipt'
        (Read-TeamData $path).schema_version | Should -Be 2
        @(Get-ChildItem (Split-Path $path) -Filter '*.obsolete-*.json').Count | Should -Be 1
    }
    It 'rejects a changed environment fingerprint, input artifact, tool identity or dirty source' {
        $fixture = New-ReuseFixture
        $null = Invoke-ReuseVerification $fixture -Reuse
        $null = Invoke-ReuseVerification $fixture -Reuse
        (@(Invoke-ReuseVerification $fixture -Reuse)[0]).reused | Should -BeTrue

        $fixture.command.environment_fingerprint = 'isolated-fixture:changed'
        $changed = @(Invoke-ReuseVerification $fixture -Reuse)[0]
        $changed.reused | Should -BeFalse
        $changed.reuse_rejected | Should -Be 'no_receipt'
        $fixture.command.environment_fingerprint = 'isolated-fixture:none'

        $artifact = Join-Path $fixture.repo 'input.txt'
        Set-Content -LiteralPath $artifact 'v1'
        $fixture.command['input_artifacts'] = @('input.txt')
        $null = Invoke-ReuseVerification $fixture -Reuse
        (@(Invoke-ReuseVerification $fixture -Reuse)[0]).reused | Should -BeTrue
        Set-Content -LiteralPath $artifact 'v2'
        (@(Invoke-ReuseVerification $fixture -Reuse)[0]).reused | Should -BeFalse
        Remove-Item -LiteralPath $artifact
        (@(Invoke-ReuseVerification $fixture -Reuse)[0]).reuse_rejected | Should -Be 'missing_input_artifact'
        $fixture.command.Remove('input_artifacts')

        $tool = Join-Path $TestDrive ('tool-' + [guid]::NewGuid().ToString('N') + '.ps1')
        Set-Content -LiteralPath $tool 'Write-Output one'
        $fixture.command.executable = $tool
        $fixture.command.args = @()
        $null = Invoke-ReuseVerification $fixture -Reuse
        (@(Invoke-ReuseVerification $fixture -Reuse)[0]).reused | Should -BeTrue
        Set-Content -LiteralPath $tool 'Write-Output two'
        (Get-Item $tool).LastWriteTimeUtc = (Get-Item $tool).LastWriteTimeUtc.AddMinutes(-30)
        (@(Invoke-ReuseVerification $fixture -Reuse)[0]).reused | Should -BeFalse -Because 'tool identity is bound to content'

        $fixture.command.executable = 'pwsh'
        $fixture.command.args = @('-NoProfile','-Command','Write-Output cached-verification')
        Set-Content -LiteralPath (Join-Path $fixture.repo 'src.txt') 'dirty'
        (@(Invoke-ReuseVerification $fixture -Reuse)[0]).reuse_rejected | Should -Be 'dirty_sources'
    }
    It 'rejects tampered receipts and undeclared environments while keeping failures inspectable' {
        $fixture = New-ReuseFixture
        $null = Invoke-ReuseVerification $fixture -Reuse
        $null = Invoke-ReuseVerification $fixture -Reuse
        $key = (@(Invoke-ReuseVerification $fixture -Reuse)[0]).reuse_key
        $cachePath = Get-TeamVerificationCachePath $fixture.directory $key
        $receipt = Read-TeamData $cachePath
        Add-Content -LiteralPath (Join-Path $fixture.directory $receipt.receipts.stdout.file) 'tampered'
        (@(Invoke-ReuseVerification $fixture -Reuse)[0]).reuse_rejected | Should -Be 'tampered_stdout_receipt'

        $fixture.command.Remove('environment_fingerprint')
        (@(Invoke-ReuseVerification $fixture -Reuse)[0]).reuse_rejected | Should -Be 'undeclared_environment_fingerprint'

        $fixture.command['environment_fingerprint'] = 'isolated-fixture:failing'
        $fixture.command.args = @('-NoProfile','-Command','Write-Output failing; exit 3')
        $failed = Catch-TeamError { Invoke-ReuseVerification $fixture -Reuse }
        $failed.Data['TeamExitCode'] | Should -Be 40
        (Test-Path -LiteralPath (Join-Path $fixture.directory 'verification-c1.stdout')) | Should -BeTrue
        @(Read-TeamData (Join-Path $fixture.directory 'verification-evidence.json'))[0]['exit_code'] | Should -Be 3
    }
    It 'never publishes a success whose source, declared input or tool changed while it ran' {
        $fixture = New-ReuseFixture
        $mutating = @{ id = 'mutate'; executable = 'pwsh'; timeout_seconds = 30; environment_fingerprint = 'isolated-fixture:none'
            args = @('-NoProfile','-Command',"[IO.File]::WriteAllText((Join-Path (Get-Location) 'src.txt'),'mutated'); 'ok'") }
        $first = @(Invoke-TeamVerification @($mutating) $fixture.repo $fixture.directory 'verification' $fixture.runtime -Reuse -CacheDirectory $fixture.directory)[0]
        $first.exit_code | Should -Be 0
        $first.reuse_publish_rejected | Should -Match 'binding_drift'
        $null = Invoke-TeamGit $fixture.repo @('restore','--source=HEAD','--','src.txt')
        (Get-Content -LiteralPath (Join-Path $fixture.repo 'src.txt') -Raw).Trim() | Should -Be 'base'
        $second = @(Invoke-TeamVerification @($mutating) $fixture.repo $fixture.directory 'verification' $fixture.runtime -Reuse -CacheDirectory $fixture.directory)[0]
        $second.reused | Should -BeFalse -Because 'a success produced under mutated source was never published'
        (Get-Content -LiteralPath (Join-Path $fixture.repo 'src.txt') -Raw).Trim() | Should -Be 'mutated'

        # A declared input artifact outside Git is bound by its hash alone.
        Add-Content -LiteralPath (Join-Path $fixture.repo '.gitignore') 'artifact.txt'
        Set-Content -LiteralPath (Join-Path $fixture.repo 'artifact.txt') 'v1'
        $null = Add-TestCommit $fixture.repo 'test: ignore artifact'
        $artifactCommand = @{ id = 'artifact'; executable = 'pwsh'; timeout_seconds = 30; environment_fingerprint = 'isolated-fixture:none'
            input_artifacts = @('artifact.txt')
            args = @('-NoProfile','-Command',"[IO.File]::WriteAllText((Join-Path (Get-Location) 'artifact.txt'),'v2'); 'ok'") }
        $artifactRun = @(Invoke-TeamVerification @($artifactCommand) $fixture.repo $fixture.directory 'verification' $fixture.runtime -Reuse -CacheDirectory $fixture.directory)[0]
        $artifactRun.reuse_publish_rejected | Should -Match 'binding_drift'
        Set-Content -LiteralPath (Join-Path $fixture.repo 'artifact.txt') 'v1'
        @(Invoke-TeamVerification @($artifactCommand) $fixture.repo $fixture.directory 'verification' $fixture.runtime -Reuse -CacheDirectory $fixture.directory)[0].reused |
            Should -BeFalse -Because 'the input hash changed during the execution that tried to publish it'

        $tool = Join-Path $TestDrive ('self-tool-' + [guid]::NewGuid().ToString('N') + '.ps1')
        Set-Content -LiteralPath $tool "Set-Content -LiteralPath `$PSCommandPath 'Write-Output changed'"
        $toolCommand = @{ id = 'tool'; executable = $tool; args = @(); timeout_seconds = 30; environment_fingerprint = 'isolated-fixture:none' }
        @(Invoke-TeamVerification @($toolCommand) $fixture.repo $fixture.directory 'verification' $fixture.runtime -Reuse -CacheDirectory $fixture.directory)[0].reuse_publish_rejected |
            Should -Match 'binding_drift'
        @(Invoke-TeamVerification @($toolCommand) $fixture.repo $fixture.directory 'verification' $fixture.runtime -Reuse -CacheDirectory $fixture.directory)[0].reused |
            Should -BeFalse -Because 'tool identity is part of the published binding'
    }
}

Describe 'Optional plan, task and list fields stay backwards compatible' {
    It 'reads an absent prerequisites list as an empty list, never a one element list' {
        @(Get-TeamOptionalList $null).Count | Should -Be 0
        @(Get-TeamPlanPrerequisites @{}).Count | Should -Be 0
        (ConvertTo-Json -InputObject @(Get-TeamPlanPrerequisites @{}) -Compress) | Should -Be '[]'
        @(Get-TeamPlanPrerequisites @{ prerequisites = @(@{ id = 'p1' }) }).Count | Should -Be 1
    }
    It 'builds an issue-to-acceptance map from a task that declares none' {
        $map = Get-TeamIssueAcceptanceMap @{ objective = @('issue one'); acceptance = @('criterion one') }
        $map.declared_count | Should -Be 0
        @($map.mapping).Count | Should -Be 0
        @($map.unmapped_acceptance).Count | Should -Be 1
        $mapped = Get-TeamIssueAcceptanceMap @{ objective = @('issue one'); acceptance = @('criterion one')
            issue_acceptance_map = @(@{ objective_index = 0; acceptance_indexes = @(0) }) }
        $mapped.declared_count | Should -Be 1
        @($mapped.unmapped_acceptance).Count | Should -Be 0
    }
    It 'rejects an out-of-range issue map instead of inventing acceptance text' {
        $task = @{ objective = @('one'); acceptance = @('one'); issue_acceptance_map = @(@{ objective_index = 4; acceptance_indexes = @(0) }) }
        (Catch-TeamError { Assert-TeamIssueAcceptanceMap $task }).Data['TeamExitCode'] | Should -Be 10
        $task.issue_acceptance_map = @(@{ objective_index = 0; acceptance_indexes = @(7) })
        (Catch-TeamError { Assert-TeamIssueAcceptanceMap $task }).Data['TeamExitCode'] | Should -Be 10
    }
    It 'previews a plan that declares no prerequisites' {
        $plan = Read-TeamData (Join-Path $script:TeamPath 'tests/plans/L1-sql.yaml')
        $preview = Get-TeamPlanPreview $plan $script:ManifestData (Get-Location).Path
        @($preview.declared_prerequisites).Count | Should -Be 0
        @($preview.notes).Count | Should -BeGreaterThan 0
    }
}

Describe 'Run-owned process ownership guards' {
    BeforeAll {
        function New-OwnedAttempt([int]$ProcessId, [string]$Start, [int]$Reserved, [string]$Status) {
            $directory = Join-Path $TestDrive ('owned-' + [guid]::NewGuid().ToString('N'))
            [IO.Directory]::CreateDirectory($directory) | Out-Null
            return @{ item = @{ pid = $ProcessId; process_start = $Start; directory = $directory; reserved = $Reserved
                    status = $Status; attempts = 1; task_id = 'T1' }; directory = $directory }
        }
    }
    It 'detects a live retired attempt and holds its reservation instead of releasing it' {
        $fixture = New-OwnedAttempt $PID ((Get-Process -Id $PID).StartTime.ToUniversalTime().ToString('o')) 1 'FAILED'
        $state = @{ tasks = @{ T1 = $fixture.item }; discarded_tasks = @{ old = $fixture.item }; agents_reserved = 1; agents_created = 0 }
        $target = @{ kind = 'discarded'; key = 'old'; task_id = 'T1'; directory = $fixture.directory }
        (Get-TeamLiveOwnedProcess $state $target).pid | Should -Be $PID
        Write-TeamData (Join-Path $fixture.directory 'exit.json') @{ exit_code = 31; transport_cleanup = @{ streams_settled = $true } }
        Write-TeamData (Join-Path $fixture.directory 'agents.json') @{ agents = @(@{ id = 'fixture'; depth = 0; state = 'created' }) }
        $sync = Sync-TeamTerminalReservations $state $fixture.directory @{}
        $sync.settled | Should -Be 0
        $sync.unknown | Should -Be 1
        $sync.held | Should -Be 1
        $state.agents_reserved | Should -Be 1
        $state.tasks.T1.reserved | Should -Be 1
    }
    It 'never releases a startup_exhausted reservation while its wrapper is still alive' {
        $fixture = New-OwnedAttempt $PID ((Get-Process -Id $PID).StartTime.ToUniversalTime().ToString('o')) 1 'ESCALATED'
        Write-TeamData (Join-Path $fixture.directory 'exit.json') @{ exit_code = 30; startup_exhausted = $true
            launch_attempts = 2; transport_cleanup = @{ streams_settled = $true } }
        $state = @{ tasks = @{ T1 = $fixture.item }; agents_reserved = 1; agents_created = 0 }
        (Sync-TeamTerminalReservations $state $fixture.directory @{}).held | Should -Be 1
        $state.agents_reserved | Should -Be 1
    }
    It 'keeps unknown usage when child cleanup is unresolved and settles only proven receipts' {
        $unresolved = New-OwnedAttempt 0 '' 2 'FAILED'
        Write-TeamData (Join-Path $unresolved.directory 'exit.json') @{ exit_code = 31
            transport_cleanup = @{ streams_settled = $true; children = @{ unverified = 2; error = 'discovery unavailable' } } }
        Write-TeamData (Join-Path $unresolved.directory 'agents.json') @{ agents = @(@{ id = 'a1'; depth = 0 }) }
        $state = @{ tasks = @{ T1 = $unresolved.item }; agents_reserved = 2; agents_created = 0 }
        $sync = Sync-TeamTerminalReservations $state $unresolved.directory @{}
        $sync.held | Should -Be 2
        $state.agents_reserved | Should -Be 2
        $state.agents_created | Should -Be 0

        # Positive control: a proven, quiescent receipt still settles and charges exactly once.
        $proven = New-OwnedAttempt 0 '' 2 'FAILED'
        Write-TeamData (Join-Path $proven.directory 'exit.json') @{ exit_code = 31
            transport_cleanup = @{ streams_settled = $true; children = @{ unverified = 0; error = $null } } }
        Write-TeamData (Join-Path $proven.directory 'agents.json') @{ agents = @(@{ id = 'a1'; depth = 0 }) }
        $settledState = @{ tasks = @{ T1 = $proven.item }; agents_reserved = 2; agents_created = 0 }
        (Sync-TeamTerminalReservations $settledState $proven.directory @{}).settled | Should -Be 1
        $settledState.agents_created | Should -Be 1
        $settledState.agents_reserved | Should -Be 0
    }
    It 'refuses finalize while a discarded attempt still owns a live process' {
        $fixture = New-OwnedAttempt $PID ((Get-Process -Id $PID).StartTime.ToUniversalTime().ToString('o')) 0 'DISCARDED'
        $state = @{ run_id = 'run9'; tasks = @{ T1 = @{ status = 'FAILED'; attempts = 0; pid = 0; process_start = ''
                    commit = ''; directory = ''; worktree = ''; branch = ''; base_sha = '' } }
            discarded_tasks = @{ 'T1-a1' = @{ task_id = 'T1'; attempts = 1; worktree = (Join-Path $TestDrive 'unused')
                    branch = 'codex/team/run9/T1/generalist-a1'; directory = $fixture.directory; status = 'DISCARDED'
                    discard_commit = ''; pid = $PID; process_start = $fixture.item.process_start } } }
        $target = @{ kind = 'discarded'; key = 'T1-a1'; task_id = 'T1'; attempt = 1
            path = (Join-Path $TestDrive 'unused'); branch = 'codex/team/run9/T1/generalist-a1'; directory = $fixture.directory }
        (Catch-TeamError { Assert-TeamTargetQuiescent $state $target $TestDrive }).Data['TeamExitCode'] | Should -Be 80
        (Catch-TeamError { Assert-TeamTargetQuiescent $state $target $TestDrive }).Message | Should -Match 'still active'
    }
}
Describe 'Archive and finalize partial safety' {
    It 'retires tracked residue using the original dirty archive and remains idempotent' {
        $repo = New-TestRepo 'tracked-residue'
        Set-Content -LiteralPath (Join-Path $repo 'src.txt') 'base'
        $base = Add-TestCommit $repo 'test: base'
        $worktree = New-TestRunWorktree $repo 'run-tracked' $base
        $source = Join-Path $worktree.path 'src.txt'
        Set-Content -LiteralPath $source 'staged'
        $null = Invoke-TeamGit $worktree.path @('add','src.txt')
        Set-Content -LiteralPath $source 'unstaged'
        $bytes = [IO.File]::ReadAllBytes($source)
        $run = New-TestRunDirectory $repo 'run-tracked' $worktree.branch $worktree.path $base $base
        $target = @(Get-TeamFinalizeTargets $run.state $run.directory)[0]
        $inspection = Get-TeamFinalizeInspection $run.state $target $run.directory
        $receipt = Invoke-TeamFinalizeArchive $run.state $run.directory $target $inspection
        $receipt.restore_proof.verified | Should -BeTrue -Because $receipt.restore_proof.error
        @($receipt.evidence.files | Where-Object path -eq 'src.txt').Count | Should -Be 1
        # Deterministically emulate Git unregistering but leaving a tracked file behind.
        $null = Invoke-TeamGit $repo @('worktree','remove','--force',$worktree.path)
        [IO.Directory]::CreateDirectory($worktree.path) | Out-Null
        [IO.File]::WriteAllBytes($source, $bytes)
        $applied = Invoke-TeamFinalize $run.state $run.directory -Apply
        $applied.outcome | Should -Be 'completed'
        (Test-Path -LiteralPath $worktree.path) | Should -BeFalse
        (Get-TeamRefState $repo $worktree.branch).exists | Should -BeFalse
        $again = Invoke-TeamFinalize $run.state $run.directory -Apply
        $again.outcome | Should -Be 'completed'
        $saved = Read-TeamData (Join-Path $run.directory 'finalize/targets/T1-a1/receipt.json')
        ([datetime]$saved.archived_at).ToUniversalTime() | Should -Be ([datetime]$receipt.archived_at).ToUniversalTime()
        $saved.evidence.files[0].sha256 | Should -Be $receipt.evidence.files[0].sha256
        (Invoke-TeamGit $repo @('rev-parse','HEAD')) | Should -Be $base
    }
    It 'adopts unregistered run residue, archives it and removes only verified bytes' {
        $repo = New-TestRepo 'residue'
        Set-Content -LiteralPath (Join-Path $repo 'src.txt') 'base'
        $base = Add-TestCommit $repo 'test: base'
        $worktree = New-TestRunWorktree $repo 'run4' $base
        # The documented Windows shape: removal unregisters the worktree but leaves the tree.
        $null = Invoke-TeamGit $repo @('worktree','remove','--force',$worktree.path)
        [IO.Directory]::CreateDirectory($worktree.path) | Out-Null
        Set-Content -LiteralPath (Join-Path $worktree.path 'left.txt') 'leftover'
        Set-Content -LiteralPath (Join-Path $worktree.path '中文 residue.txt') 'cn'
        $run = New-TestRunDirectory $repo 'run4' $worktree.branch $worktree.path $base $base

        $preview = Invoke-TeamFinalize $run.state $run.directory
        $entry = @($preview.targets)[0]
        $entry.registered | Should -BeFalse
        $entry.unregistered_pending | Should -BeTrue
        $entry.archivable | Should -BeTrue
        (Test-Path -LiteralPath $worktree.path) | Should -BeTrue

        $applied = Invoke-TeamFinalize $run.state $run.directory -Apply
        $applied.outcome | Should -Be 'completed'
        $result = @($applied.results)[0]
        $result.worktree_removed | Should -BeTrue
        $result.directory_removal_pending | Should -BeFalse
        $result.ref_deleted | Should -BeTrue
        (Test-Path -LiteralPath $worktree.path) | Should -BeFalse
        (Get-TeamRefState $repo $worktree.branch).exists | Should -BeFalse
        (Invoke-TeamGit $repo @('rev-parse','HEAD')) | Should -Be $base
        $receipt = Read-TeamData (Join-Path $run.directory 'finalize/targets/T1-a1/receipt.json')
        $receipt.residue | Should -BeTrue
        $receipt.origin_proven | Should -BeFalse -Because 'no prior phase receipt existed, so no original Git state is inferred'
        $receipt.restore_proof.method | Should -Be 'isolated-temp-tree'
        $receipt.restore_proof.verified | Should -BeTrue
        @($receipt.evidence.files).Count | Should -Be 2
        $receipt.residue_removal.archived_files_removed | Should -Be 2
        $receipt.residue_removal.remaining_files | Should -Be 0

        $again = Invoke-TeamFinalize $run.state $run.directory -Apply
        @($again.results)[0].worktree_removed | Should -BeTrue
        (Invoke-TeamGit $repo @('rev-parse','HEAD')) | Should -Be $base
    }
    It 'compare-and-deletes only archived bytes and retains unrecorded residue' {
        $directory = Join-Path $TestDrive ('residue-' + [guid]::NewGuid().ToString('N'))
        [IO.Directory]::CreateDirectory($directory) | Out-Null
        Set-Content -LiteralPath (Join-Path $directory 'archived.txt') 'archived'
        Set-Content -LiteralPath (Join-Path $directory 'arrived-later.txt') 'later'
        $entry = @{ path = 'archived.txt'; bytes = (Get-Item -LiteralPath (Join-Path $directory 'archived.txt')).Length
            sha256 = (Get-TeamHash (Join-Path $directory 'archived.txt')) }
        $removal = Remove-TeamFinalizeResidue $directory @($entry) @()
        $removal.archived_files_removed | Should -Be 1
        @($removal.retained) | Should -Contain 'arrived-later.txt'
        $removal.removed | Should -BeFalse -Because 'content that is not archived is never deleted'
        (Test-Path -LiteralPath (Join-Path $directory 'archived.txt')) | Should -BeFalse
        (Test-Path -LiteralPath (Join-Path $directory 'arrived-later.txt')) | Should -BeTrue
    }
    It 'isolates an unsupported target so safe run-owned targets are still archived and removed' {
        $repo = New-TestRepo 'isolated-target'
        Set-Content -LiteralPath (Join-Path $repo 'src.txt') 'base'
        $base = Add-TestCommit $repo 'test: base'
        $worktree = New-TestRunWorktree $repo 'run7' $base
        Set-Content -LiteralPath (Join-Path $worktree.path 'dirty.txt') 'dirty'
        $run = New-TestRunDirectory $repo 'run7' $worktree.branch $worktree.path $base $base
        $outside = Join-Path $TestDrive 'outside-run7-T2'
        [IO.Directory]::CreateDirectory($outside) | Out-Null
        $run.state.order = @('T1','T2')
        $run.state.tasks['T2'] = @{ status = 'FAILED'; attempts = 1; pid = 0; process_start = ''; commit = ''
            directory = (Join-Path $run.directory 'tasks/T2/attempt-1'); worktree = $outside
            branch = 'codex/team/run7/T2/generalist-a1'; base_sha = $base }

        $eventsHash = Get-TeamHash (Join-Path $run.directory 'events.jsonl')
        $filesBefore = @(Get-ChildItem -LiteralPath $run.directory -Recurse -Force | ForEach-Object FullName)
        $preview = Invoke-TeamFinalize $run.state $run.directory
        (Get-TeamHash (Join-Path $run.directory 'events.jsonl')) | Should -Be $eventsHash
        @(Get-ChildItem -LiteralPath $run.directory -Recurse -Force | ForEach-Object FullName) | Should -Be $filesBefore
        $preview.summary.unsupported | Should -Be 1
        $preview.summary.targets | Should -Be 2
        $applied = Invoke-TeamFinalize $run.state $run.directory -Apply
        $applied.outcome | Should -Be 'partial'
        $applied.summary.failed | Should -Be 1
        $applied.summary.worktrees_removed | Should -Be 1
        (Test-Path -LiteralPath $worktree.path) | Should -BeFalse
        (Test-Path -LiteralPath $outside) | Should -BeTrue -Because 'a target this finalizer cannot bind to the run is never touched'
        (Invoke-TeamGit $repo @('rev-parse','HEAD')) | Should -Be $base
    }
    It 'archives, proves and compare-deletes the integration ref and refuses a moved integration HEAD' {
        $repo = New-TestRepo 'integration-target'
        Set-Content -LiteralPath (Join-Path $repo 'src.txt') 'base'
        $base = Add-TestCommit $repo 'test: base'
        $path = Join-Path $repo '.worktrees/run8-integration'
        $branch = 'codex/integration/run8'
        $null = Invoke-TeamGit $repo @('worktree','add','-q','-b',$branch,$path,$base)
        Set-Content -LiteralPath (Join-Path $path 'integrated.txt') 'merged'
        $null = Invoke-TeamGit $path @('add','integrated.txt')
        $null = Invoke-TeamGit $path @('commit','-qm','test: integration')
        $head = Invoke-TeamGit $path @('rev-parse','HEAD')
        function New-IntegrationState([string]$Repo,[string]$RunId,[string]$Worktree,[string]$Ref,[string]$BaseSha,[string]$Expected) {
            $directory = Join-Path $Repo "team/runtime/$RunId"
            [IO.Directory]::CreateDirectory($directory) | Out-Null
            return @{ schema_version = 1; run_id = $RunId; revision = 1; repo = $Repo; status = 'COMPLETED'
                run_base_sha = $BaseSha; integration_base_sha = $BaseSha; last_good_integration_sha = $Expected
                integration_branch = $Ref; integration_worktree = $Worktree; plan_hash = ('a' * 64); order = @('T1')
                tasks = @{ T1 = @{ status = 'MERGED'; attempts = 0; commit = ''; pid = 0; process_start = ''
                    directory = ''; worktree = ''; branch = ''; base_sha = '' } }
                agents_created = 0; agents_reserved = 0
                cost_ledgers = @{ astra = @{ unit = 'credits'; known_cost = 0.0 }; deepseek = @{ unit = 'USD'; known_cost = 0.0 } }
                unknown_usage = $true; replans = 0 }
        }
        $run = New-IntegrationState $repo 'run8' $path $branch $base $head
        $applied = Invoke-TeamFinalize $run (Join-Path $repo 'team/runtime/run8') -Apply
        $result = @($applied.results)[0]
        $result.key | Should -Be 'integration'
        $result.worktree_removed | Should -BeTrue
        $result.ref_deleted | Should -BeTrue
        (Test-Path -LiteralPath $path) | Should -BeFalse
        (Get-TeamRefState $repo $branch).exists | Should -BeFalse
        $receipt = Read-TeamData (Join-Path $repo 'team/runtime/run8/finalize/targets/integration/receipt.json')
        $receipt.restore_proof.verified | Should -BeTrue
        $receipt.evidence.bundle.verified | Should -BeTrue
        (Invoke-TeamGit $repo @('rev-parse','HEAD')) | Should -Be $base

        # A recorded checkpoint that differs from the worktree HEAD is refused, not archived.
        $repo2 = New-TestRepo 'integration-moved'
        Set-Content -LiteralPath (Join-Path $repo2 'src.txt') 'base'
        $base2 = Add-TestCommit $repo2 'test: base'
        $path2 = Join-Path $repo2 '.worktrees/run9-integration'
        $branch2 = 'codex/integration/run9'
        $null = Invoke-TeamGit $repo2 @('worktree','add','-q','-b',$branch2,$path2,$base2)
        Set-Content -LiteralPath (Join-Path $path2 'moved.txt') 'moved'
        $null = Invoke-TeamGit $path2 @('add','moved.txt')
        $null = Invoke-TeamGit $path2 @('commit','-qm','test: moved')
        $run2 = New-IntegrationState $repo2 'run9' $path2 $branch2 $base2 $base2
        $refused = Invoke-TeamFinalize $run2 (Join-Path $repo2 'team/runtime/run9') -Apply
        @($refused.results)[0].failed | Should -BeTrue
        @($refused.results)[0].error | Should -Match 'differs from the recorded run commit'
        (Test-Path -LiteralPath $path2) | Should -BeTrue
        (Get-TeamRefState $repo2 $branch2).exists | Should -BeTrue
        (Invoke-TeamGit $repo2 @('rev-parse','HEAD')) | Should -Be $base2
    }
}

Describe 'Shared activity receipt' {
    It 'keeps a receipt parseable while a second real process rewrites it' -Skip:(-not $IsWindows) {
        $receipt = Join-Path $TestDrive 'shared-activity.json'
        $core = Join-Path $script:TeamPath 'scripts/Core.ps1'
        $child = ". '$core'; for (`$i = 0; `$i -lt 200; `$i++) { Write-TeamData '$receipt' @{ schema_version = 1; kind = `$(if (`$i % 2) { 'a' } else { 'b' }); i = `$i }; Start-Sleep -Milliseconds 1 }"
        $handle = New-TeamProcess 'pwsh' @('-NoProfile','-Command',$child) $TestDrive (Join-Path $TestDrive 'shared.out') (Join-Path $TestDrive 'shared.err') -MaxOutputBytes 1MB
        try {
            $reads = 0
            $watch = [Diagnostics.Stopwatch]::StartNew()
            Start-Sleep -Milliseconds 200
            while ($watch.Elapsed.TotalSeconds -lt 20 -and $reads -lt 300) {
                if (Test-Path -LiteralPath $receipt -PathType Leaf) {
                    $parsed = Read-TeamData $receipt
                    $parsed.kind | Should -BeIn @('a','b')
                    [int]$parsed.i | Should -BeGreaterOrEqual 0
                    $reads++
                }
                if ($handle.process.HasExited) { break }
                Start-Sleep -Milliseconds 1
            }
            $reads | Should -BeGreaterThan 0
            (Wait-TeamProcess $handle 30) | Should -Be 0
            (Read-TeamData $receipt).i | Should -Be 199
            @(Get-ChildItem -LiteralPath $TestDrive -Filter '.atomic-*' -Force).Count | Should -Be 0
        } finally { if (-not $handle['closed']) { $null = Close-TeamProcess $handle -Terminate } }
    }
    It 'gives the coordinator and the adapter probes separate receipts for one worktree' {
        $repo = New-TestRepo 'activity-split'
        Set-Content -LiteralPath (Join-Path $repo 'src.txt') 'base'
        $null = Add-TestCommit $repo 'test: base'
        $coordinator = New-TeamActivityProbe -Worktree $repo -RootPid 0 -ReceiptPath (Join-Path $TestDrive 'coordinator-activity.json')
        $adapter = New-TeamActivityProbe -Worktree $repo -RootPid 0 -ReceiptPath (Join-Path $TestDrive 'adapter-activity.json')
        $null = Get-TeamActivityProbeResult $coordinator
        $null = Get-TeamActivityProbeResult $adapter
        Set-Content -LiteralPath (Join-Path $repo 'src.txt') 'changed'
        (Get-TeamActivityProbeResult $coordinator).kind | Should -Be 'worktree'
        (Get-TeamActivityProbeResult $adapter).kind | Should -Be 'worktree'
        foreach ($name in @('coordinator-activity.json','adapter-activity.json')) {
            $record = Read-TeamData (Join-Path $TestDrive $name)
            $record.last_activity_kind | Should -Be 'worktree'
            $record.fingerprint_truncated | Should -BeFalse
        }
    }
}

Describe 'Archive and finalize lifecycle' {
    It 'attaches nonadjacent duplicate aliases to their own target instead of the last target' {
        $state = @{ order=@('T1','T2'); tasks=@{}; discarded_tasks=@{}
            integration_worktree=(Join-Path $TestDrive 'integration'); integration_branch='codex/integration/probe'
            run_base_sha=('a'*40); last_good_integration_sha=('a'*40); status='CANCELLED' }
        foreach ($id in @('T1','T2')) {
            $item = @{task_id=$id;attempts=1;worktree=(Join-Path $TestDrive $id);branch="codex/team/probe/$id/generalist-a1"
                directory=(Join-Path $TestDrive "evidence/$id");status='DISCARDED';base_sha=('a'*40)}
            $state.tasks[$id]=$item; $state.discarded_tasks["old-$id"]=$item
        }
        $targets=@(Get-TeamFinalizeTargets $state $TestDrive)
        $targets.Count | Should -Be 3
        @(@($targets | Where-Object kind -eq 'integration')[0].aliases).Count | Should -Be 0
        foreach ($id in @('T1','T2')) {
            $target=@($targets | Where-Object path -eq $state.tasks[$id].worktree)[0]
            @($target.aliases).Count | Should -Be 1
            $target.aliases[0].key | Should -Be "$id-a1"
        }
    }
    It 'previews read only, then archives, proves restoration and removes only run owned state' {
        $repo = New-TestRepo 'finalize'
        [IO.File]::WriteAllText((Join-Path $repo '.gitignore'), "node_modules/`n", [Text.UTF8Encoding]::new($false))
        Set-Content -LiteralPath (Join-Path $repo 'src.txt') 'base'
        $base = Add-TestCommit $repo 'test: base'
        $worktree = New-TestRunWorktree $repo 'run1' $base
        Set-Content -LiteralPath (Join-Path $worktree.path 'src.txt') 'dirty'
        Set-Content -LiteralPath (Join-Path $worktree.path '中文 untracked.txt') 'cn'
        Set-Content -LiteralPath (Join-Path $worktree.path 'committed.txt') 'committed'
        $null = Invoke-TeamGit $worktree.path @('add','committed.txt')
        $null = Invoke-TeamGit $worktree.path @('commit','-qm','test: worker commit')
        $head = Invoke-TeamGit $worktree.path @('rev-parse','HEAD')
        $store = Join-Path $worktree.path 'node_modules/.pnpm/foo@1.0.0/node_modules'
        [IO.Directory]::CreateDirectory($store) | Out-Null
        Set-Content -LiteralPath (Join-Path $store 'index.js') 'module.exports=1'
        $null = New-Item -ItemType Junction -Path (Join-Path $worktree.path 'node_modules/foo') -Target $store
        $run = New-TestRunDirectory $repo 'run1' $worktree.branch $worktree.path $base $head

        $preview = Invoke-TeamFinalize $run.state $run.directory
        $preview.mode | Should -Be 'preview'
        $preview.summary.targets | Should -Be 1
        @($preview.targets)[0].loose_links | Should -Be 1
        @($preview.targets)[0].archivable | Should -BeTrue
        (Test-Path -LiteralPath $worktree.path) | Should -BeTrue
        (Get-TeamRefState $repo $worktree.branch).exists | Should -BeTrue

        $applied = Invoke-TeamFinalize $run.state $run.directory -Apply
        $result = @($applied.results)[0]
        $result.preserved | Should -BeFalse -Because $result.preserve_reason
        $result.worktree_removed | Should -BeTrue
        $result.ref_deleted | Should -BeTrue
        $result.directory_removal_pending | Should -BeFalse
        (Test-Path -LiteralPath $worktree.path) | Should -BeFalse
        (Invoke-TeamGit $repo @('rev-parse','HEAD')) | Should -Be $base
        (Get-TeamRefState $repo $worktree.branch).exists | Should -BeFalse

        $receipt = Read-TeamData (Join-Path $run.directory 'finalize/targets/T1-a1/receipt.json')
        $receipt.restore_proof.verified | Should -BeTrue
        $receipt.restore_proof.links_checked | Should -Be 1
        @($receipt.evidence.links).Count | Should -Be 1
        @($receipt.evidence.files).Count | Should -BeGreaterThan 1
        $receipt.evidence.unstaged.bytes | Should -BeGreaterThan 0

        $again = Invoke-TeamFinalize $run.state $run.directory -Apply
        @($again.results)[0].worktree_removed | Should -BeTrue
        (Invoke-TeamGit $repo @('rev-parse','HEAD')) | Should -Be $base
    }
    It 'preserves a target whose inventory cannot be archived instead of deleting it' {
        $repo = New-TestRepo 'preserve'
        Set-Content -LiteralPath (Join-Path $repo 'src.txt') 'base'
        $base = Add-TestCommit $repo 'test: base'
        $worktree = New-TestRunWorktree $repo 'run2' $base
        foreach ($name in @('a.txt','b.txt','c.txt')) { Set-Content -LiteralPath (Join-Path $worktree.path $name) $name }
        $run = New-TestRunDirectory $repo 'run2' $worktree.branch $worktree.path $base $base
        $script:TeamFinalizeMaxFiles = 1
        try {
            $applied = Invoke-TeamFinalize $run.state $run.directory -Apply
            $result = @($applied.results)[0]
            $result.preserved | Should -BeTrue
            $result.preserve_reason | Should -Match 'bounded archive limit'
            $result.worktree_removed | Should -BeFalse
            $result.directory_removal_pending | Should -BeFalse
            (Test-Path -LiteralPath $worktree.path) | Should -BeTrue
            (Get-TeamRefState $repo $worktree.branch).exists | Should -BeTrue
            (Invoke-TeamGit $repo @('rev-parse','HEAD')) | Should -Be $base
        } finally { $script:TeamFinalizeMaxFiles = 20000 }
        $oldReceipt = Join-Path $run.directory 'finalize/targets/T1-a1/receipt.json'
        $oldHash = Get-TeamHash $oldReceipt
        $retry = Invoke-TeamFinalize $run.state $run.directory -Apply
        $retry.outcome | Should -Be 'completed'
        (Test-Path -LiteralPath $worktree.path) | Should -BeFalse
        (Get-TeamRefState $repo $worktree.branch).exists | Should -BeFalse
        $history = @(Get-ChildItem -LiteralPath (Join-Path $run.directory 'finalize/preserved') -Recurse -Filter receipt.json)
        $history.Count | Should -Be 1
        (Get-TeamHash $history[0].FullName) | Should -Be $oldHash
    }
    It 'refuses to finalize a run that can still be resumed' {
        $repo = New-TestRepo 'resumable'
        Set-Content -LiteralPath (Join-Path $repo 'src.txt') 'base'
        $base = Add-TestCommit $repo 'test: base'
        $worktree = New-TestRunWorktree $repo 'run3' $base
        $run = New-TestRunDirectory $repo 'run3' $worktree.branch $worktree.path $base $base
        $run.state.status = 'PAUSED'
        $failure = Catch-TeamError { Invoke-TeamFinalize $run.state $run.directory -Apply }
        $failure.Data['TeamExitCode'] | Should -Be 80
        (Test-Path -LiteralPath $worktree.path) | Should -BeTrue
    }
}

Describe 'Pre-dispatch prerequisites' {
    It 'records NOT_DECLARED for a plan without prerequisites and admits the run' {
        $directory = Join-Path $TestDrive ('prereq-none-' + [guid]::NewGuid().ToString('N'))
        [IO.Directory]::CreateDirectory($directory) | Out-Null
        $result = Invoke-TeamPrerequisites @{ plan_hash = ('b' * 64); repo = $TestDrive } @{ run = @{ revision = 1 } } @{ runtime = (New-TestRuntime) } $directory
        $result.status | Should -Be 'NOT_DECLARED'
        $result.declared | Should -Be 0
        (Read-TeamData (Join-Path $directory 'prerequisites.json')).status | Should -Be 'NOT_DECLARED'
    }
    It 'fails before any worker is admitted and preserves the failing command evidence' {
        $directory = Join-Path $TestDrive ('prereq-fail-' + [guid]::NewGuid().ToString('N'))
        [IO.Directory]::CreateDirectory($directory) | Out-Null
        $plan = @{ run = @{ revision = 1 }; prerequisites = @(
            @{ id = 'db'; executable = 'pwsh'; args = @('-NoProfile','-Command','Write-Output no-database; exit 4'); timeout_seconds = 60
               restore = @{ executable = 'pwsh'; args = @('-NoProfile','-Command','Write-Output rollback-ran'); timeout_seconds = 60 } }) }
        $state = @{ plan_hash = ('c' * 64); repo = $TestDrive }
        $failure = Catch-TeamError { Invoke-TeamPrerequisites $state $plan @{ runtime = (New-TestRuntime) } $directory }
        $failure.Data['TeamExitCode'] | Should -Be 40
        $failure.Message | Should -Match 'before any worker or worktree was admitted'
        $record = Read-TeamData (Join-Path $directory 'prerequisites.json')
        $record.status | Should -Be 'FAILED'
        $record.failed_id | Should -Be 'db'
        @($record.attempts).Count | Should -Be 1
        @($record.attempts)[0].restore_exit_code | Should -Be 0
        $evidenceDirectory = Join-Path $directory $record.attempts[0].directory
        (Test-Path -LiteralPath $evidenceDirectory) | Should -BeTrue
        (Get-Content -LiteralPath (Join-Path $evidenceDirectory 'db.stdout') -Raw) | Should -Match 'no-database'
        @(Get-ChildItem -LiteralPath (Join-Path $directory 'tasks') -ErrorAction SilentlyContinue).Count | Should -Be 0
        (Test-Path -LiteralPath (Join-Path $directory 'finalize')) | Should -BeFalse

        # A rerun keeps the earlier failure receipt visible instead of overwriting it.
        $null = Catch-TeamError { Invoke-TeamPrerequisites $state $plan @{ runtime = (New-TestRuntime) } $directory }
        $second = Read-TeamData (Join-Path $directory 'prerequisites.json')
        @($second.attempts).Count | Should -Be 2
        (Test-Path -LiteralPath (Join-Path $directory $record.attempts[0].directory)) | Should -BeTrue
    }
    It 'reuses a passed prerequisite only for the same plan hash' {
        $directory = Join-Path $TestDrive ('prereq-pass-' + [guid]::NewGuid().ToString('N'))
        [IO.Directory]::CreateDirectory($directory) | Out-Null
        $marker = Join-Path $directory 'runs.txt'
        $plan = @{ run = @{ revision = 1 }; prerequisites = @(
            @{ id = 'touch'; executable = 'pwsh'; timeout_seconds = 60
               args = @('-NoProfile','-Command',"Add-Content -LiteralPath '$marker' ran") }) }
        $manifest = @{ runtime = (New-TestRuntime) }
        $first = Invoke-TeamPrerequisites @{ plan_hash = ('d' * 64); repo = $TestDrive } $plan $manifest $directory
        $first.status | Should -Be 'PASSED'
        @(Get-Content -LiteralPath $marker).Count | Should -Be 1
        $second = Invoke-TeamPrerequisites @{ plan_hash = ('d' * 64); repo = $TestDrive } $plan $manifest $directory
        $second.reused | Should -BeTrue
        @(Get-Content -LiteralPath $marker).Count | Should -Be 1
        $null = Invoke-TeamPrerequisites @{ plan_hash = ('e' * 64); repo = $TestDrive } $plan $manifest $directory
        @(Get-Content -LiteralPath $marker).Count | Should -Be 2
    }
    It 'runs an explicit restore without hiding the earlier failure receipt' {
        $directory = Join-Path $TestDrive ('prereq-restore-' + [guid]::NewGuid().ToString('N'))
        [IO.Directory]::CreateDirectory($directory) | Out-Null
        $marker = Join-Path $directory 'restore.txt'
        $plan = @{ run = @{ revision = 1 }; prerequisites = @(
            @{ id = 'db'; executable = 'pwsh'; args = @('-NoProfile','-Command','exit 5'); timeout_seconds = 60
               restore = @{ executable = 'pwsh'; args = @('-NoProfile','-Command',"Add-Content -LiteralPath '$marker' restored"); timeout_seconds = 60 } }) }
        $manifest = @{ runtime = (New-TestRuntime) }
        $state = @{ plan_hash = ('f' * 64); repo = $TestDrive }
        $null = Catch-TeamError { Invoke-TeamPrerequisites $state $plan $manifest $directory }
        $failed = Read-TeamData (Join-Path $directory 'prerequisites.json')
        $failed.status | Should -Be 'FAILED'
        # A failing prerequisite already runs its declared rollback once, and keeps that receipt.
        @(Get-Content -LiteralPath $marker).Count | Should -Be 1
        $result = Invoke-TeamPrerequisites $state $plan $manifest $directory -Restore -Reason 'fixture rollback'
        $result.status | Should -Be 'RESTORED'
        @(Get-Content -LiteralPath $marker).Count | Should -Be 2
        (Read-TeamData (Join-Path $directory 'prerequisites.json')).status | Should -Be 'FAILED' -Because 'restore must not overwrite the recorded failure'
        (Test-Path -LiteralPath (Join-Path $directory $failed.attempts[0].directory)) | Should -BeTrue
    }
}

Describe 'Infrastructure recovery versus business replans' {
    BeforeAll {
        function New-RecoveryFixture([string]$ExitCode, [string]$TimeoutKind) {
            $runId = 'rec' + [guid]::NewGuid().ToString('N').Substring(0, 8)
            $directory = Join-Path $TestDrive $runId
            $attempt = Join-Path $directory 'tasks/T1/attempt-1'
            [IO.Directory]::CreateDirectory($attempt) | Out-Null
            Write-TeamData (Join-Path $attempt 'exit.json') @{ exit_code = [int]$ExitCode; startup_exhausted = $false
                input_too_large = $false; launch_attempts = 1; timeout_kind = $TimeoutKind
                transport_cleanup = @{ streams_settled = $true; drain_expired = $false } }
            Write-TeamData (Join-Path $attempt 'agents.json') @{ agents = @(@{ id = 'a1'; depth = 0; state = 'created' }) }
            $state = @{ schema_version = 1; run_id = $runId; revision = 1; repo = $TestDrive; status = 'FAILED'
                run_base_sha = ('a' * 40); integration_base_sha = ('a' * 40); last_good_integration_sha = ('a' * 40)
                integration_branch = "codex/integration/$runId"; integration_worktree = ''; plan_hash = ('b' * 64); order = @('T1')
                tasks = @{ T1 = @{ status = 'FAILED'; attempts = 1; commit = ''; pid = 0; process_start = ''
                    directory = $attempt; worktree = ''; branch = ''; base_sha = ('a' * 40); reserved = 0 } }
                agents_created = 1; agents_reserved = 0
                cost_ledgers = @{ astra = @{ unit = 'credits'; known_cost = 0.0 }; deepseek = @{ unit = 'USD'; known_cost = 0.0 } }
                unknown_usage = $true; replans = 0; infra_retries = 0 }
            $plan = @{ tasks = @(@{ id = 'T1'; role = 'generalist'; objective = @('work'); acceptance = @('done')
                write_scope = @('src.txt'); dependencies = @(); subagents = @{ allowed = $false; max_depth = 0 }
                permissions = @{ shell = $true } }) }
            $manifest = @{ budget = @{ max_worker_retries = 2; max_agents_per_run = 10; max_parallel_agents_total = 6 } }
            return @{ directory = $directory; attempt = $attempt; state = $state; plan = $plan; manifest = $manifest }
        }
    }
    It 'treats a recorded idle deadline as infrastructure and preserves the retired attempt' {
        $fixture = New-RecoveryFixture 31 'idle'
        $eligibility = Test-TeamInfrastructureFailure $fixture.state $fixture.directory 'T1' $fixture.manifest
        $eligibility.eligible | Should -BeTrue
        $eligibility.infra_kind | Should -Be 'idle'
        $result = Invoke-TeamInfrastructureRecovery $fixture.state $fixture.plan $fixture.manifest $fixture.directory 'T1' 'runner idle deadline'
        $result.infra_kind | Should -Be 'idle'
        $result.semantic_replans | Should -Be 0
        $result.infra_retries | Should -Be 1
        $fixture.state.replans | Should -Be 0
        @($fixture.state.discarded_tasks.Keys).Count | Should -Be 1
        $retired = $fixture.state.discarded_tasks[$result.retired_key]
        $retired.status | Should -Be 'DISCARDED'
        $retired.retire_kind | Should -Be 'infrastructure'
        $retired.directory | Should -Be $fixture.attempt
        $fixture.state.tasks.T1.status | Should -Be 'READY'
        (Test-Path -LiteralPath (Join-Path $fixture.directory "recovery/$($result.recovery_id).json")) | Should -BeTrue
    }
    It 'never relabels a verification, review, scope or business failure as infrastructure' {
        $fixture = New-RecoveryFixture 40 ''
        $fixture.state.worker_failures = @{ 'T1/1' = @{ task_id = 'T1'; kind = 'verification_failure'; attempt = 1; count = 1; exit_code = 40
            message = 'Verification failed'; directory = $fixture.attempt } }
        (Test-TeamInfrastructureFailure $fixture.state $fixture.directory 'T1' $fixture.manifest).eligible | Should -BeFalse
        $failure = Catch-TeamError { Invoke-TeamInfrastructureRecovery $fixture.state $fixture.plan $fixture.manifest $fixture.directory 'T1' 'try to bypass the counter' }
        $failure.Data['TeamExitCode'] | Should -Be 10
        $failure.Message | Should -Match 'not eligible'
        $fixture.state.infra_retries | Should -Be 0
    }
    It 'never lets another attempt or directory classify the current failure as infrastructure' {
        $fixture = New-RecoveryFixture 40 ''
        foreach ($variant in @('previous-attempt','other-directory')) {
            $fixture.state['worker_failures']=@{ 'T1/worker_timeout'=@{
                task_id='T1';kind='worker_timeout';infra_kind='idle'
                attempt=$(if ($variant -eq 'previous-attempt') {0} else {1})
                directory=$(if ($variant -eq 'other-directory') {Join-Path $TestDrive 'other-attempt'} else {$fixture.attempt})
            }}
            (Test-TeamInfrastructureFailure $fixture.state $fixture.directory 'T1' $fixture.manifest).eligible | Should -BeFalse
        }
        # Even an otherwise matching stale timeout cannot override a successful adapter
        # exit followed by a business verification or review failure.
        $fixture.state.worker_failures['T1/worker_timeout'].directory=$fixture.attempt
        Write-TeamData (Join-Path $fixture.attempt 'exit.json') @{exit_code=0;transport_cleanup=@{streams_settled=$true}}
        (Test-TeamInfrastructureFailure $fixture.state $fixture.directory 'T1' $fixture.manifest).eligible | Should -BeFalse
        $fixture.state.infra_retries | Should -Be 0
    }
    It 'keeps unknown usage when the adapter streams never settled' {
        $fixture = New-RecoveryFixture 30 ''
        Write-TeamData (Join-Path $fixture.attempt 'exit.json') @{ exit_code = 30; startup_exhausted = $false
            input_too_large = $false; timeout_kind = $null; transport_cleanup = @{ streams_settled = $false } }
        $fixture.state['worker_failures'] = @{ 'T1/1' = @{ task_id = 'T1'; kind = 'worker_timeout'; attempt = 1; count = 1; exit_code = 31
            infra_kind = 'transport'; message = 'transport'; directory = $fixture.attempt } }
        (Test-TeamInfrastructureFailure $fixture.state $fixture.directory 'T1' $fixture.manifest).eligible | Should -BeFalse
        $fixture.state.infra_retries | Should -Be 0
    }
    It 'enforces both recovery caps and keeps hard or output terminations non-recoverable' {
        $attempts = New-RecoveryFixture 31 'idle'
        $attempts.state.tasks.T1.attempts = 3
        (Catch-TeamError { Invoke-TeamInfrastructureRecovery $attempts.state $attempts.plan $attempts.manifest $attempts.directory 'T1' 'retry' }).Data['TeamExitCode'] | Should -Be 60
        $attempts.state.infra_retries | Should -Be 0
        $attempts.state.tasks.T1.status | Should -Be 'FAILED'
        (Test-Path -LiteralPath (Join-Path $attempts.directory 'recovery')) | Should -BeFalse

        $capped = New-RecoveryFixture 31 'idle'
        $capped.state['infra_retries'] = 2
        (Catch-TeamError { Invoke-TeamInfrastructureRecovery $capped.state $capped.plan $capped.manifest $capped.directory 'T1' 'retry' }).Data['TeamExitCode'] | Should -Be 60
        $capped.state.tasks.T1.status | Should -Be 'FAILED'
        (Test-Path -LiteralPath (Join-Path $capped.directory 'recovery')) | Should -BeFalse

        foreach ($kind in @('hard','output')) {
            $bounded = New-RecoveryFixture 31 $kind
            $eligibility = Test-TeamInfrastructureFailure $bounded.state $bounded.directory 'T1' $bounded.manifest
            $eligibility.eligible | Should -BeFalse
            $eligibility.reason | Should -Match 'not auto-recoverable'
            (Catch-TeamError { Invoke-TeamInfrastructureRecovery $bounded.state $bounded.plan $bounded.manifest $bounded.directory 'T1' 'bypass' }).Data['TeamExitCode'] | Should -Be 10
            $bounded.state.infra_retries | Should -Be 0
        }
    }
}

Describe 'Review material completeness' {
    It 'gives every command its own head and tail excerpt instead of starving later logs' {
        $directory = Join-Path $TestDrive ('review-output-' + [guid]::NewGuid().ToString('N'))
        [IO.Directory]::CreateDirectory($directory) | Out-Null
        $big = Join-Path $directory 'verification-big.stdout'
        [IO.File]::WriteAllText($big, ('A' * 4000) + ('Z' * 4000), [Text.UTF8Encoding]::new($false))
        $small = Join-Path $directory 'verification-small.stdout'
        [IO.File]::WriteAllText($small, 'SMALL_COMMAND_MARKER', [Text.UTF8Encoding]::new($false))
        $records = @(Get-TeamReviewOutput $directory verification 400 | ConvertFrom-Json)
        $records.Count | Should -Be 2
        $records[0].bytes | Should -Be 8000
        $records[0].sha256 | Should -Be (Get-TeamHash $big)
        $records[0].truncated | Should -BeTrue
        $records[0].head | Should -Match '^A+$'
        $records[0].tail | Should -Match '^Z+$'
        $records[1].excerpt | Should -Match 'SMALL_COMMAND_MARKER'
        $records[1].truncated | Should -BeFalse
        ($records | Measure-Object -Property excerpt_chars -Sum).Sum | Should -BeLessOrEqual 400
    }
    It 'summarises every command and the machine-derived change counts without truncation' {
        $repo = New-TestRepo 'material'
        Set-Content -LiteralPath (Join-Path $repo 'a.txt') 'one'
        $base = Add-TestCommit $repo 'test: base'
        Set-Content -LiteralPath (Join-Path $repo 'a.txt') 'one two'
        Set-Content -LiteralPath (Join-Path $repo 'b.txt') 'new'
        $null = Invoke-TeamGit $repo @('add','b.txt')
        $tip = Add-TestCommit $repo 'test: change'
        $summary = Get-TeamChangeSummary $repo $base $tip
        $summary.file_count | Should -Be 2
        $summary.additions | Should -BeGreaterThan 0
        $summary.source | Should -Match 'numstat'
        $commands = Get-TeamCommandSummary @(
            @{ id = 'c1'; executable = 'pwsh'; args = @('-NoProfile'); exit_code = 0; process_started = $true; reused = $false }
            @{ id = 'c2'; executable = 'pwsh'; args = @('-NoProfile','-Command','exit 3'); exit_code = 3; process_started = $true
               timeout_kind = 'idle'; reused = $true; reuse_rejected = 'no_receipt' })
        @($commands).Count | Should -Be 2
        $commands[0].args_sha256 | Should -Match '^[a-f0-9]{64}$'
        $commands[1].exit_code | Should -Be 3
        $commands[1].timeout_kind | Should -Be 'idle'
        $commands[1].reused | Should -BeTrue
    }
    It 'builds the LOCAL and 9P reviewer prompts from real material without a model call' {
        $repo = New-TestRepo 'review-material'
        Set-Content -LiteralPath (Join-Path $repo 'a.txt') 'one'
        $base = Add-TestCommit $repo 'test: base'
        Set-Content -LiteralPath (Join-Path $repo 'a.txt') 'one two'
        Set-Content -LiteralPath (Join-Path $repo 'b.txt') 'new'
        $tip = Add-TestCommit $repo 'test: change'
        $directory = Join-Path $TestDrive ('review-state-' + [guid]::NewGuid().ToString('N'))
        $attempt = Join-Path $directory 'tasks/T1/attempt-1'
        [IO.Directory]::CreateDirectory($attempt) | Out-Null
        $authorityHash = New-TeamAuthority $repo $base $directory
        Write-TeamData (Join-Path $attempt 'agents.json') @{ agents = @(@{ id = 'author'; depth = 0; state = 'created'
            provider = 'deepseek-official'; model = 'deepseek-flash'; cwd = $repo }) }
        Write-TeamData (Join-Path $attempt 'result.yaml') @{ subagents_used = @(); risks = @('untrusted claim') }
        Write-TeamData (Join-Path $attempt 'verification-evidence.json') @(@{ id = 'c1'; executable = 'pwsh'; args = @('-NoProfile')
            exit_code = 0; process_started = $true; timeout_kind = $null; reused = $false; duration_seconds = 0.2
            stdout_file = 'verification-c1.stdout'; stdout_bytes = 4096; stdout_sha256 = ('a' * 64)
            stderr_file = 'verification-c1.stderr'; stderr_bytes = 0; stderr_sha256 = ('b' * 64) })
        [IO.File]::WriteAllText((Join-Path $attempt 'verification-c1.stdout'), ('A' * 4000) + ('Z' * 96), [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllText((Join-Path $attempt 'verification-c1.stderr'), '', [Text.UTF8Encoding]::new($false))
        $state = @{ run_id = 'mat1'; run_base_sha = $base; authority_hash = $authorityHash; plan_hash = ('c' * 64) }
        $manifest = @{ runtime = (New-TestRuntime) }
        $task = @{ id = 'T1'; objective = @('issue one'); acceptance = @('criterion one')
            issue_acceptance_map = @(@{ objective_index = 0; acceptance_indexes = @(0) }) }
        $item = @{ worktree = $repo; base_sha = $base; commit = $tip; directory = $attempt; status = 'VERIFYING' }

        $local = Get-TeamLocalReviewMaterial $state $task $item $manifest $directory
        $local.change_summary.file_count | Should -Be 2
        $local.issue_map.declared_count | Should -Be 1
        $local.diff_bytes | Should -Be (Get-TeamTextByteCount $local.diff)
        $local.prompt | Should -Match 'Machine-derived change summary \(git diff --numstat --no-renames\)'
        $local.prompt | Should -Match '"additions":\s*[0-9]+'
        $local.prompt | Should -Match 'Task issue-to-acceptance mapping'
        $local.prompt | Should -Match 'criterion one'
        $local.prompt | Should -Match 'Structured command result summary'
        $local.prompt | Should -Match '"c1"'
        $local.prompt | Should -Match 'External test output \(bounded BOTH head/tail excerpts'
        $local.prompt | Should -Match '"head_bytes":\s*1024'
        $local.prompt | Should -Match '"tail_bytes":\s*1024'
        $local.prompt | Should -Match '"omitted_bytes":\s*2048'
        $local.prompt | Should -Match '"truncated":\s*true'

        $plan = Read-TeamData (Join-Path $script:TeamPath 'tests/plans/L1-sql.yaml')
        $nineP = Get-TeamReviewMaterial $state $plan $manifest $directory '9P' $repo $base $base
        $nineP.diff | Should -Match 'No implementation diff exists at plan stage'
        $nineP.diff_bytes | Should -Be (Get-TeamTextByteCount $nineP.diff)
        $nineP.change_summary.note | Should -Match 'No implementation diff'
        $nineP.prompt | Should -Match 'Stage: 9P'
        $nineP.prompt | Should -Match 'Machine-derived change summary'
        $nineP.prompt | Should -Match 'Task issue-to-acceptance mapping'
        $nineP.prompt | Should -Match 'Structured command result summary'
        $nineP.prompt | Should -Match 'External test output \(bounded BOTH head/tail excerpts'
        $nineP.prompt | Should -Match ([regex]::Escape($plan.tasks[0].id))

        # An absent diff is legitimately zero bytes and must not throw while measuring.
        Get-TeamTextByteCount $null | Should -Be 0
        { Assert-TeamReviewInput $null 'small' (New-TestRuntime) } | Should -Not -Throw
    }
    It 'reports excerpt metadata that agrees with the returned head and tail' {
        $directory = Join-Path $TestDrive ('excerpt-' + [guid]::NewGuid().ToString('N'))
        [IO.Directory]::CreateDirectory($directory) | Out-Null
        $path = Join-Path $directory 'verification-4k.stdout'
        [IO.File]::WriteAllText($path, ('h' * 2048) + ('t' * 2048), [Text.UTF8Encoding]::new($false))
        $window = Read-TeamLogExcerpt $path 512 512
        $window.truncated | Should -BeTrue
        $window.excerpt_chars | Should -Be 1024
        $window.head.Length | Should -Be 512
        $window.tail.Length | Should -Be 512
        $window.head_bytes | Should -Be (Get-TeamTextByteCount $window.head)
        $window.tail_bytes | Should -Be (Get-TeamTextByteCount $window.tail)
        $window.omitted_bytes | Should -Be (4096 - $window.head_bytes - $window.tail_bytes)
        $window.omitted_bytes | Should -BeGreaterThan 0

        $whole = Read-TeamLogExcerpt $path 4096 4096
        $whole.truncated | Should -BeFalse
        $whole.omitted_bytes | Should -Be 0
        $whole.excerpt_chars | Should -Be 4096
    }
}

Describe 'Honest status accounting' {
    BeforeAll {
        function New-SummaryFixture {
            $runId = 'sum' + [guid]::NewGuid().ToString('N').Substring(0, 8)
            $directory = Join-Path $TestDrive $runId
            foreach ($attempt in @('attempt-1','attempt-2')) {
                $path = Join-Path $directory "tasks/T1/$attempt"
                [IO.Directory]::CreateDirectory($path) | Out-Null
                Write-TeamData (Join-Path $path 'agents.json') @{ agents = @(@{ id = "$attempt-root"; depth = 0 }, @{ id = "$attempt-child"; depth = 1 }) }
            }
            $started = Join-Path $directory 'reviews/reviewer-started'
            [IO.Directory]::CreateDirectory($started) | Out-Null
            Write-TeamData (Join-Path $started 'agents.json') @{ agents = @(@{ id = 'reviewer'; depth = 0; read_only = $true }) }
            $preparing = Join-Path $directory 'reviews/reviewer-preparing'
            [IO.Directory]::CreateDirectory($preparing) | Out-Null
            $state = @{ tasks = @{
                    T1 = @{ status = 'REVIEW'; attempts = 2; reserved = 0
                        local_review = @{ directory = $started; status = 'EXITED'; reserved = 0 } }
                    T2 = @{ status = 'READY'; attempts = 1; reserved = 1
                        local_review = @{ directory = $preparing; status = 'PREPARING'; reserved = 0 } } }
                agents_created = 3; agents_reserved = 1; replans = 1; infra_retries = 2; unknown_usage = $true
                worker_failures = @{
                    'T1/1' = @{ task_id = 'T1'; kind = 'worker_timeout'; attempt = 1; count = 1; exit_code = 31; infra_kind = 'idle' }
                    'T2/2' = @{ task_id = 'T2'; kind = 'worker_timeout'; attempt = 2; count = 1; exit_code = 31; infra_kind = 'hard' }
                    'T2/1' = @{ task_id = 'T2'; kind = 'verification_failure'; attempt = 1; count = 1; exit_code = 40 } }
                cost_ledgers = @{ astra = @{ unit = 'credits'; known_cost = 0.0 }; deepseek = @{ unit = 'USD'; known_cost = 0.0 } } }
            return @{ directory = $directory; state = $state }
        }
    }
    It 'separates dispatch intent from observed native identities across retired attempts' {
        $fixture = New-SummaryFixture
        $summary = Get-TeamRunSummary $fixture.state $fixture.directory
        $summary.authors_dispatched_intents | Should -Be 3
        $summary.authors_observed | Should -Be 2
        $summary.author_agents_observed | Should -Be 4
        $summary.author_children_observed | Should -Be 2
        $summary.agents_created | Should -Be 3
        $summary.reservations_pending | Should -Be 1
    }
    It 'never reports a PREPARING local review as started' {
        $fixture = New-SummaryFixture
        $summary = Get-TeamRunSummary $fixture.state $fixture.directory
        $summary.local_reviewers_started | Should -Be 1
        $summary.local_reviewers_preparing | Should -Be 1
        $summary.reviewer_agents_observed | Should -Be 1
    }
    It 'reports infrastructure and semantic attempts separately without claiming zero cost' {
        $fixture = New-SummaryFixture
        $summary = Get-TeamRunSummary $fixture.state $fixture.directory
        $summary.attempts.infrastructure | Should -Be 2
        $summary.attempts.infrastructure_recoverable | Should -Be 1
        $summary.attempts.infrastructure_nonrecoverable | Should -Be 1 -Because 'a hard timeout is infrastructure-class but never auto-recoverable'
        $summary.attempts.semantic | Should -Be 1
        $summary.attempts.semantic_replans | Should -Be 1
        $summary.attempts.infrastructure_recovery | Should -Be 2
        $summary.known_usage.unknown_usage | Should -BeTrue
        @($summary.verification).Count | Should -BeGreaterThan 0
        @($summary.notes | Where-Object { $_ -match 'not auto-recoverable|owner decision' }).Count | Should -BeGreaterThan 0
    }
    It 'keeps the cost document valid at schema version three' {
        $fixture = New-SummaryFixture
        $document = @{ schema_version = 3; run_id = 'costdoc1'; ledgers = @{
                astra = @{ unit = 'credits'; known_cost = 0.0; soft_limit = 10; hard_limit = 20 }
                deepseek = @{ unit = 'USD'; known_cost = 0.0; soft_limit = 10; hard_limit = 20 } }
            unknown_usage = $true; agents_created = 3; active_workers = 0
            summary = (Get-TeamRunSummary $fixture.state $fixture.directory) }
        { Test-TeamSchema $document 'cost' } | Should -Not -Throw
        { Test-TeamSchema ($document + @{ schema_version = 2 }) 'cost' } | Should -Throw
    }
}
