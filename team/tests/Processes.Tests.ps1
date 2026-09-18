BeforeAll {
    $script:TeamPath=Split-Path $PSScriptRoot -Parent
    . (Join-Path $script:TeamPath 'scripts/Core.ps1')
    . (Join-Path $script:TeamPath 'scripts/Contracts.ps1')
    . (Join-Path $script:TeamPath 'scripts/State.ps1')
    . (Join-Path $script:TeamPath 'scripts/Execution.ps1')
    $script:RealNewProcess=(Get-Command New-TeamProcess).ScriptBlock
    function Catch-TeamError($Action) {
        try { & $Action | Out-Null } catch { return $_.Exception }
        throw 'Expected a Team error'
    }
    function Start-FixtureProcess([string]$Command, [long]$Limit=4096, [string]$InputText='') {
        New-TeamProcess 'pwsh' @('-NoProfile','-Command',$Command) $TestDrive (Join-Path $TestDrive 'stdout') (Join-Path $TestDrive 'stderr') $InputText -MaxOutputBytes $Limit
    }
}

Describe 'Bounded real subprocess transport' {
    It 'does not start a child when the second log cannot be opened' {
        $marker=Join-Path $TestDrive 'never-started'
        $failure=Catch-TeamError { New-TeamProcess 'pwsh' @('-NoProfile','-Command','Set-Content never-started started') $TestDrive (Join-Path $TestDrive 'stdout') $TestDrive }
        $failure.Data['TeamExitCode'] | Should -Be 30
        $failure.Data['ProcessStarted'] | Should -BeFalse
        Test-Path $marker | Should -BeFalse
        # The first stream must also have been released.
        $stream=[IO.File]::Open((Join-Path $TestDrive 'stdout'),'Open','ReadWrite','None'); $stream.Dispose()
    }
    It 'caps both streams even when a fast child has already exited' {
        $handle=Start-FixtureProcess '[Console]::Out.Write("o" * 65536); [Console]::Error.Write("e" * 65536)' 4096
        try {
            $handle.process.WaitForExit(10000) | Should -BeTrue
            (Catch-TeamError { Wait-TeamProcess $handle 15 }).Data['TeamExitCode'] | Should -Be 31
            (Get-Item $handle.stdout).Length | Should -Be 4096
            (Get-Item $handle.stderr).Length | Should -Be 4096
            $handle.closed | Should -BeTrue
        } finally { $null=Close-TeamProcess $handle -Terminate }
    }
    It 'terminates a live stdout flood and retains only the configured prefix' {
        $handle=Start-FixtureProcess 'while ($true) { [Console]::Out.Write("x" * 8192) }'
        $owned=$handle.process.Id
        try {
            $failure=Catch-TeamError { Wait-TeamProcess $handle 10 }
            $failure.Data['TeamExitCode'] | Should -Be 31
            $failure.Message | Should -Match 'output limit'
            (Get-Item $handle.stdout).Length | Should -Be 4096
            Get-Process -Id $owned -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        } finally { $null=Close-TeamProcess $handle -Terminate }
    }
    It 'bounds an idle child without mistaking silence for completion' {
        $handle=Start-FixtureProcess 'Start-Sleep -Seconds 30'
        try {
            (Catch-TeamError { Wait-TeamProcess $handle 15 1 }).Message | Should -Match 'idle timeout'
            $handle.closed | Should -BeTrue
        } finally { $null=Close-TeamProcess $handle -Terminate }
    }
    It 'can time out while a child never reads its large stdin' {
        $watch=[Diagnostics.Stopwatch]::StartNew()
        $handle=Start-FixtureProcess 'Start-Sleep -Seconds 30' 4096 ('p' * 2MB)
        try {
            $watch.Elapsed.TotalSeconds | Should -BeLessThan 5
            (Catch-TeamError { Wait-TeamProcess $handle 1 }).Data['TeamExitCode'] | Should -Be 31
            $watch.Elapsed.TotalSeconds | Should -BeLessThan 10
        } finally { $null=Close-TeamProcess $handle -Terminate }
    }
    It 'rejects an oversized direct verdict file even if the child exits zero' {
        $handle=Start-FixtureProcess '[IO.File]::WriteAllText("verdict.json", "v" * 8192)'
        try {
            (Catch-TeamError { Wait-TeamProcess $handle 10 0 @((Join-Path $TestDrive 'verdict.json')) }).Data['TeamExitCode'] | Should -Be 31
        } finally { $null=Close-TeamProcess $handle -Terminate }
    }
    It 'records native process evidence separately from an output-limit verification failure' {
        $commands=@(@{id='flood';executable='pwsh';args=@('-NoProfile','-Command','[Console]::Out.Write("x" * 2MB)');timeout_seconds=10})
        (Catch-TeamError { Invoke-TeamVerification $commands $TestDrive $TestDrive 'verify' @{max_single_log_mb=1;idle_timeout_seconds=5} }).Data['TeamExitCode'] | Should -Be 40
        $evidence=@(Read-TeamData (Join-Path $TestDrive 'verify-evidence.json'))[0]
        $evidence.process_started | Should -BeTrue
        $evidence.exit_code | Should -Be 31
        $evidence.error | Should -Match 'output limit'
        (Get-Item (Join-Path $TestDrive 'verify-flood.stdout')).Length | Should -Be 1MB
        $evidence.stdout_sha256 | Should -Be (Get-TeamHash (Join-Path $TestDrive 'verify-flood.stdout'))
    }
    It 'does not invent a native exit code for a verification command that never started' {
        $commands=@(@{id='missing';executable=(Join-Path $TestDrive 'missing.exe');args=@();timeout_seconds=10})
        (Catch-TeamError { Invoke-TeamVerification $commands $TestDrive $TestDrive 'missing' }).Data['TeamExitCode'] | Should -Be 40
        $evidence=@(Read-TeamData (Join-Path $TestDrive 'missing-evidence.json'))[0]
        $evidence.process_started | Should -BeFalse
        $evidence.process_exit_code | Should -BeNullOrEmpty
        $evidence.exit_code | Should -Be 30
    }
    It 'preserves a confirmed start when the process factory fails during post-start setup' {
        Mock New-TeamProcess {
            $failure=[InvalidOperationException]::new('Post-start setup failed after the child was cleaned up')
            $failure.Data['ProcessStarted']=$true; $failure.Data['TeamExitCode']=30; throw $failure
        }
        $commands=@(@{id='setup';executable='pwsh';args=@();timeout_seconds=10})
        (Catch-TeamError { Invoke-TeamVerification $commands $TestDrive $TestDrive 'setup' }).Data['TeamExitCode'] | Should -Be 40
        $evidence=@(Read-TeamData (Join-Path $TestDrive 'setup-evidence.json'))[0]
        $evidence.process_started | Should -BeTrue
        $evidence.process_exit_code | Should -BeNullOrEmpty
        $evidence.exit_code | Should -Be 30
    }
}

Describe 'DSH retries only before native process creation' {
    BeforeEach {
        Mock Get-Command { @{Source='pwsh'} } -ParameterFilter {$Name -eq 'dsh'}
        $script:LaunchCalls=0
    }
    It 'retries once then returns the single started process with both receipts' {
        Mock New-TeamProcess {
            $script:LaunchCalls++
            if ($script:LaunchCalls -eq 1) {
                $errorObject=[InvalidOperationException]::new('Transient pre-start failure'); $errorObject.Data['ProcessStarted']=$false; throw $errorObject
            }
            & $script:RealNewProcess $Executable $Arguments $Directory $Stdout $Stderr -MaxOutputBytes $MaxOutputBytes
        }
        $handle=Start-TeamDshProcess $TestDrive $TestDrive @('-NoProfile','-Command','exit 0') 4096
        try { Wait-TeamProcess $handle 10 | Should -Be 0 } finally { $null=Close-TeamProcess $handle -Terminate }
        $handle.launch_attempts | Should -Be 2
        (Read-TeamData (Join-Path $TestDrive 'launch-1.json')).started | Should -BeFalse
        (Read-TeamData (Join-Path $TestDrive 'launch-2.json')).started | Should -BeTrue
        Should -Invoke New-TeamProcess -Exactly 2
    }
    It 'stops after two confirmed pre-start failures' {
        Mock New-TeamProcess {
            $errorObject=[InvalidOperationException]::new('No process created'); $errorObject.Data['ProcessStarted']=$false; throw $errorObject
        }
        $failure=Catch-TeamError { Start-TeamDshProcess $TestDrive $TestDrive @() 4096 }
        $failure.Data['StartupExhausted'] | Should -BeTrue
        $failure.Data['LaunchAttempts'] | Should -Be 2
        Should -Invoke New-TeamProcess -Exactly 2
    }
    It 'never retries a launch error when process creation is <Known>' -ForEach @(@{Known='started'},@{Known='unknown'}) {
        Mock New-TeamProcess {
            $errorObject=[InvalidOperationException]::new('Launch outcome cannot be retried')
            if ($Known -eq 'started') { $errorObject.Data['ProcessStarted']=$true }
            throw $errorObject
        }
        $failure=Catch-TeamError { Start-TeamDshProcess $TestDrive $TestDrive @() 4096 }
        $failure.Data['StartupExhausted'] | Should -BeFalse
        $failure.Data['LaunchAttempts'] | Should -Be 1
        $receipt=Read-TeamData (Join-Path $TestDrive 'launch-1.json')
        if ($Known -eq 'unknown') { $receipt.started | Should -BeNullOrEmpty }
        else { $receipt.started | Should -BeTrue }
        $receipt.retryable | Should -BeFalse
        Should -Invoke New-TeamProcess -Exactly 1
    }
    It 'does not retry a real process that starts and exits nonzero' {
        $handle=Start-TeamDshProcess $TestDrive $TestDrive @('-NoProfile','-Command','exit 9') 4096
        try { Wait-TeamProcess $handle 10 | Should -Be 9 } finally { $null=Close-TeamProcess $handle -Terminate }
        $handle.launch_attempts | Should -Be 1
    }
}

Describe 'Adapter startup exhaustion and coordinator handoff' {
    It 'retains two real command-resolution failures and escalates without consuming native agents' {
        $task=(Read-TeamData (Join-Path $script:TeamPath 'tests/plans/L1-sql.yaml')).tasks[0]
        $packet=@{schema_version=1;run_id='STARTUP';task_id=$task.id;role=@{id=$task.role;definition=(Get-TeamRole $task.role)}
            objective=$task.objective;dependencies=$task.dependencies;permissions=$task.permissions;write_scope=$task.write_scope
            acceptance=$task.acceptance;subagents=$task.subagents;verification=$task.verification;base_sha=('a'*40);result_schema='team/schemas/result.schema.json'}
        $taskFile=Join-Path $TestDrive 'task.yaml'; Write-TeamData $taskFile $packet
        $oldPath=$env:PATH; $pwsh=(Get-Command pwsh).Source; $handle=$null
        try {
            # Only this child environment lacks DSH; no installed files or user configuration change.
            $env:PATH=Split-Path $pwsh -Parent
            $handle=New-TeamProcess $pwsh @('-NoProfile','-File',(Join-Path $script:TeamPath 'scripts/Invoke-DshWorker.ps1'),
                '-TaskFile',$taskFile,'-Worktree',$TestDrive,'-OutputFile',(Join-Path $TestDrive 'result.yaml'),'-Patch','unused') $TestDrive (Join-Path $TestDrive 'adapter.stdout') (Join-Path $TestDrive 'adapter.stderr')
        } finally { $env:PATH=$oldPath }
        try { Wait-TeamProcess $handle 20 | Should -Be 30 } finally { if ($handle) {$null=Close-TeamProcess $handle -Terminate} }
        $receipt=Read-TeamData (Join-Path $TestDrive 'exit.json')
        $receipt.startup_exhausted | Should -BeTrue; $receipt.launch_attempts | Should -Be 2
        foreach ($n in 1..2) { (Read-TeamData (Join-Path $TestDrive "launch-$n.json")).started | Should -BeFalse }
        Test-Path (Join-Path $TestDrive 'native-process.json') | Should -BeFalse
        Mock Save-TeamState {}
        Mock Add-TeamEvent {}
        $state=@{run_id='STARTUP';plan_hash=('b'*64);status='RUNNING';agents_created=0;agents_reserved=1
            tasks=@{$task.id=@{directory=$TestDrive;attempts=1;status='RUNNING';reserved=1}}}
        (Catch-TeamError { Complete-TeamWorkerSafely $state $task $TestDrive $null $null }).Data['TeamExitCode'] | Should -Be 30
        $state.status | Should -Be 'ESCALATED'; $state.tasks[$task.id].status | Should -Be 'ESCALATED'
        $state.agents_reserved | Should -Be 0; $state.agents_created | Should -Be 0
        $escalation=Get-ChildItem (Join-Path $TestDrive 'escalations') -Filter '*.yaml'
        (Read-TeamData $escalation.FullName).type | Should -Be 'worker_start_failure'
    }
}
