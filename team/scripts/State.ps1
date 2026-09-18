function Save-TeamState($State, [string]$Directory) {
    $State.updated_at = [DateTime]::UtcNow.ToString('o')
    Test-TeamSchema $State 'state'
    Write-TeamData (Join-Path $Directory 'state.json') $State
}

function Add-TeamEvent([string]$Directory, [string]$Event, $Details = @{}) {
    $entry = @{ timestamp = [DateTime]::UtcNow.ToString('o'); event = $Event; details = $Details }
    [IO.File]::AppendAllText((Join-Path $Directory 'events.jsonl'), ($entry | ConvertTo-Json -Depth 30 -Compress) + "`n", [Text.UTF8Encoding]::new($false))
}

function Lock-TeamRepo([string]$Repo, [string]$RunId, [switch]$Resume) {
    $runtime = Get-TeamChild $Repo 'team/runtime'
    [IO.Directory]::CreateDirectory($runtime) | Out-Null
    # Process-wide exclusive handle serializes all mutating CLI calls, including resume.
    $mutexPath = Get-TeamChild $runtime '.coordinator-lock'
    try { $handle = [IO.File]::Open($mutexPath, 'OpenOrCreate', 'ReadWrite', 'None') }
    catch { Stop-TeamError 20 'Repository coordinator is already active' }
    $lockPath = Get-TeamChild $runtime '.team-lock'
    try {
        if (Test-Path -LiteralPath $lockPath) {
            $existing = Read-TeamData $lockPath
            if (-not $Resume -or $existing.run_id -cne $RunId) { Stop-TeamError 20 'Repository team lock active' }
        }
        Write-TeamData $lockPath @{ run_id = $RunId; pid = $PID; created_at = [DateTime]::UtcNow.ToString('o') }
        return $handle
    } catch { $handle.Dispose(); throw }
}

function Unlock-TeamRepo([string]$Repo, [string]$RunId) {
    $path = Get-TeamChild $Repo 'team/runtime/.team-lock'
    if (Test-Path -LiteralPath $path) {
        $record = Read-TeamData $path
        if ($record.run_id -cne $RunId) { Stop-TeamError 80 'Refusing to release another run lock' }
        [IO.File]::Delete($path)
    }
}

function New-TeamEscalation($State, [string]$Directory, [string]$Type, [string]$Summary, $Context = @{}) {
    $id = 'ESC-' + [guid]::NewGuid().ToString('N').Substring(0, 10)
    Write-TeamData (Join-Path $Directory "escalations/$id.yaml") @{
        schema_version = 1; id = $id; run_id = $State.run_id; status = 'pending'; type = $Type
        summary = $Summary; options = @('approve','reject','modify-plan'); default_if_unresolved = 'pause'
        context = $Context; plan_hash = $State.plan_hash
        created_at = [DateTime]::UtcNow.ToString('o'); expires_at = [DateTime]::UtcNow.AddHours(24).ToString('o')
    }
    $State.status = 'ESCALATED'
    Save-TeamState $State $Directory
    Add-TeamEvent $Directory 'escalation_required' @{ id = $id; type = $Type }
}

function Read-TeamRun([string]$Repo, [string]$RunId) {
    Assert-TeamId $RunId
    $directory = Get-TeamChild $Repo "team/runtime/$RunId"
    try {
        $state = Read-TeamData (Join-Path $directory 'state.json')
        Test-TeamSchema $state 'state'
    } catch { Stop-TeamError 80 "Invalid persisted run state: $($_.Exception.Message)" }
    if ($state.run_id -cne $RunId -or $state.repo -cne $Repo) { Stop-TeamError 80 'Run identity mismatch' }
    return @{ directory = $directory; state = $state }
}

function New-TeamRun($Plan, $Manifest, [string]$Repo, [string[]]$Order, [string]$RuntimeStatus) {
    $directory = Get-TeamChild $Repo "team/runtime/$($Plan.run.id)"
    if (Test-Path -LiteralPath $directory) { Stop-TeamError 20 'Run ID already exists; use resume or a new ID' }
    [IO.Directory]::CreateDirectory($directory) | Out-Null
    Write-TeamData (Join-Path $directory 'plan.yaml') $Plan
    Write-TeamData (Join-Path $directory 'manifest.yaml') $Manifest
    foreach ($roleId in @($Plan.tasks.role | Sort-Object -Unique)) {
        Write-TeamData (Join-Path $directory "roles/$roleId.yaml") (Get-TeamRole $roleId -Plan $Plan)
    }
    New-DshPatch (Join-Path $directory 'worker.patch.yaml')
    $base = Invoke-TeamGit $Repo @('rev-parse','HEAD')
    $state = @{
        schema_version = 1; run_id = $Plan.run.id; revision = $Plan.run.revision; repo = $Repo
        status = 'READY'; run_base_sha = $base; integration_base_sha = $base; last_good_integration_sha = $base
        integration_branch = "codex/integration/$($Plan.run.id)"; integration_worktree = ''; order = @($Order)
        tasks = @{}; agents_created = 0; agents_reserved = 0
        cost_ledgers = @{astra=@{unit='credits';known_cost=0.0};deepseek=@{unit='USD';known_cost=0.0}}
        unknown_usage = $true; replans = 0
        plan_hash = Get-TeamHash (Join-Path $directory 'plan.yaml'); runtime_status = $RuntimeStatus
        updated_at = [DateTime]::UtcNow.ToString('o'); created_at = [DateTime]::UtcNow.ToString('o')
    }
    foreach ($task in $Plan.tasks) { $state.tasks[$task.id] = @{ status = 'READY'; attempts = 0; commit = ''; pid = 0; process_start = ''; directory = ''; worktree = ''; branch = ''; base_sha = '' } }
    Save-TeamState $state $directory
    Add-TeamEvent $directory 'run_created' @{ base_sha = $base; runtime_status = $RuntimeStatus }
    return @{ state = $state; directory = $directory }
}
