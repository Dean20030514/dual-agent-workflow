#requires -Version 7.4
[CmdletBinding()]
param(
    [Parameter(Position=0,Mandatory)][ValidateSet('doctor','route','validate','run','status','watch','escalations','resolve','result','logs','cost','stop','resume','cleanup','accept','integrate','affected','replan','rollback','report-cost','record-route','repair-integration','resolve-review')][string]$Command,
    [string]$Plan, [string]$Repo = (Get-Location).Path, [string]$Manifest,
    [string]$Run, [string]$Task, [string]$TaskText, [string]$Commit, [string]$Reason,
    [string]$Escalation, [ValidateSet('approve','reject','modify-plan')][string]$Decision,
    [double]$Amount = -1, [string]$Evidence, [string]$ExpectedMode,
    [ValidateSet('9P','9A','9B')][string]$Stage, [string]$Disposition,
    [string[]]$ChangedPaths = @(), [string[]]$GlueScope = @(), [datetime]$Since = [datetime]::MinValue,
    [switch]$Json, [switch]$Follow, [switch]$AllowUnverifiedRuntime, [switch]$RepairLock
)
foreach ($module in @('Core','Contracts','Preflight','State','Execution','Integration','Recovery','Review','Conflict')) { . (Join-Path $PSScriptRoot "$module.ps1") }
$lock = $null; $runData = $null; $exitCode = 0
try {
    $Repo = [IO.Path]::GetFullPath($Repo).TrimEnd([IO.Path]::DirectorySeparatorChar)
    if (-not $Manifest) { $Manifest = Join-Path $script:TeamRoot 'manifest.yaml' }
    $config = Read-TeamData $Manifest
    Test-TeamSchema $config 'manifest'
    if ($Command -in @('run','resume','repair-integration') -and -not $config.team.enabled) { Stop-TeamError 20 'Team disabled; use normal Codex mode' }
    switch ($Command) {
        'doctor' {
            if ($RepairLock) {
                $lockPath = Get-TeamChild $Repo 'team/runtime/.team-lock'
                if (Test-Path -LiteralPath $lockPath) {
                    $stale = Read-TeamData $lockPath
                    $lock = Lock-TeamRepo $Repo $stale.run_id -Resume
                    $saved = Read-TeamRun $Repo $stale.run_id
                    if ($saved.state.status -notin @('COMPLETED','CANCELLED','FAILED')) { Stop-TeamError 80 'Lock belongs to a recoverable run; use resume or stop' }
                    Unlock-TeamRepo $Repo $stale.run_id
                }
            }
            $output = Test-TeamDoctor $config $Repo -AllowUnverifiedRuntime:$AllowUnverifiedRuntime
            if (-not $output.success) { $exitCode = 20 }
        }
        'route' {
            $output = if ($config.team.enabled) { Get-TeamRoute $TaskText } else { @{ recommended_mode = 'L0'; confidence = 1.0; reasons = @('team disabled'); source = 'configuration' } }
        }
        'validate' {
            $order = Test-TeamPlan (Read-TeamData $Plan) $config
            $output = @{ valid = $true; order = @($order) }
        }
        'affected' { $output = @{ affected = @(Get-TeamAffected (Read-TeamData $Plan) $Task $ChangedPaths) } }
        'record-route' { $output = Record-TeamRoute $config $Repo $TaskText $ExpectedMode }
        'run' {
            if (-not $config.team.enabled) { Stop-TeamError 20 'Team disabled; use normal Codex mode' }
            $document = Read-TeamData $Plan
            $order = Test-TeamPlan $document $config
            $doctor = Test-TeamDoctor $config $Repo -AllowUnverifiedRuntime:$AllowUnverifiedRuntime
            if (-not $doctor.success) { Stop-TeamError 20 ($doctor.problems -join '; ') }
            $null = Invoke-TeamGit $Repo @('rev-parse','--show-toplevel')
            if (Test-Path -LiteralPath (Get-TeamChild $Repo "team/runtime/$($document.run.id)")) { Stop-TeamError 20 'Run already exists; use resume' }
            $lock = Lock-TeamRepo $Repo $document.run.id
            $runData = New-TeamRun $document $config $Repo $order $doctor.runtime_status
            $null = Test-DshRoute $config $Repo (Join-Path $runData.directory 'worker.patch.yaml')
            $risky = @($document.tasks | Where-Object { $_.permissions.production -or $_.permissions.secrets -or $_.permissions.network })
            if (@($document['risk_flags'] | Where-Object { $_ -match '^(destructive|production_delete)$' }).Count) {
                Stop-TeamError 60 'Destructive production action requires owner intervention; no worker dispatched'
            }
            if ($risky.Count -or $document['risk_flags']) {
                New-TeamEscalation $runData.state $runData.directory 'restricted_action' 'Plan requests restricted permissions or risk flags. Revise scope or resolve with the owner.'
                Stop-TeamError 70 'Restricted action requires escalation'
            }
            if ($document.classification.level -eq 'critical') {
                $base = $runData.state.run_base_sha
                $null = Invoke-TeamReview $runData.state $document $config $runData.directory '9P' $Repo $base $base
            }
            $output = Invoke-TeamDispatch $runData.state $document $config $runData.directory
        }
        default {
            if (-not $Run) { Stop-TeamError 10 '-Run is required' }
            $runData = Read-TeamRun $Repo $Run
            $state = $runData.state; $directory = $runData.directory
            if ($state['hard_stop'] -and $Command -in @('resume','accept','integrate','replan','repair-integration')) { Stop-TeamError 60 'Run is hard-stopped; preserve evidence and return to the owner' }
            $document = Read-TeamData (Join-Path $directory 'plan.yaml')
            $config = Read-TeamData (Join-Path $directory 'manifest.yaml')
            if ($Command -in @('resume','accept','integrate','replan','rollback','repair-integration','resolve-review') -and
                (Get-TeamHash (Join-Path $directory 'plan.yaml')) -cne $state.plan_hash) { Stop-TeamError 80 'Plan changed outside revision protocol' }
            if ($Command -eq 'stop') {
                Write-TeamData (Join-Path $directory 'cancel.request.json') @{ run_id=$Run; requested_at=[DateTime]::UtcNow.ToString('o') }
                try { $lock = Lock-TeamRepo $Repo $Run -Resume }
                catch {
                    @{ status='STOP_REQUESTED'; run_id=$Run } | ConvertTo-Json -Compress
                    exit 0
                }
            } elseif ($Command -in @('resume','resolve','cleanup','accept','integrate','replan','rollback','report-cost','record-route','repair-integration','resolve-review')) { $lock = Lock-TeamRepo $Repo $Run -Resume }
            switch ($Command) {
                'status' { $output = $state }
                'cost' { $output = @{ schema_version = 1; run_id = $Run; known_cost = $state.known_cost; unknown_usage = $state.unknown_usage; agents_created = $state.agents_created; active_workers = @($state.tasks.Values | Where-Object { $_.status -eq 'RUNNING' }).Count } }
                'result' {
                    Assert-TeamId $Task
                    if (-not $state.tasks.Contains($Task)) { Stop-TeamError 10 'Unknown task' }
                    $output = Read-TeamData (Join-Path $state.tasks[$Task].directory 'result.yaml')
                }
                'logs' { $output = @(Get-Content -LiteralPath (Join-Path $directory 'events.jsonl') | ForEach-Object { ConvertFrom-Json $_ -AsHashtable } | Where-Object { [datetime]$_.timestamp -ge $Since -and (-not $Task -or $_.details['task_id'] -eq $Task) }) }
                'watch' {
                    $seen = 0
                    do {
                        $entries = @(Get-Content -LiteralPath (Join-Path $directory 'events.jsonl'))
                        foreach ($line in ($entries | Select-Object -Skip $seen)) {
                            $entry = ConvertFrom-Json $line -AsHashtable
                            if ([datetime]$entry.timestamp -ge $Since -and (-not $Task -or $entry.details['task_id'] -eq $Task)) { Write-Output $line }
                        }
                        $seen = $entries.Count; $state = Read-TeamData (Join-Path $directory 'state.json')
                        if ($state.status -in @('COMPLETED','FAILED','CANCELLED')) { break }
                        if ($state.status -in @('ESCALATED','PAUSED') -and -not $Follow) { break }
                        Start-Sleep -Seconds 2
                    } while ($true)
                    $output = @{ status = $state.status }
                }
                'escalations' { $output = @(Get-ChildItem -LiteralPath (Join-Path $directory 'escalations') -Filter '*.yaml' -ErrorAction SilentlyContinue | ForEach-Object { Read-TeamData $_.FullName }) }
                'resolve' {
                    Assert-TeamId $Escalation
                    if (-not $Decision -or -not $Reason) { Stop-TeamError 10 'Resolution requires -Decision and -Reason' }
                    $path = Get-TeamChild $directory "escalations/$Escalation.yaml"
                    $record = Read-TeamData $path
                    if ($record.status -ne 'pending') { Stop-TeamError 70 'Escalation already resolved' }
                    $record.status = $Decision; $record['reason'] = $Reason
                    Write-TeamData $path $record
                    $state.status = if ($Decision -eq 'reject') { 'CANCELLED' } else { 'PAUSED' }
                    Save-TeamState $state $directory
                    if ($Decision -eq 'reject') { Unlock-TeamRepo $Repo $Run }
                    Add-TeamEvent $directory 'escalation_resolved' @{ id = $Escalation; decision = $Decision }
                    $output = @{ status = $state.status; next = 'Approval does not rewrite permissions or resume dispatch; revise plan explicitly.' }
                }
                'accept' { Accept-TeamTask $state $document $directory $Task $Commit $Reason; $output = @{ status = 'ACCEPTED'; task_id = $Task } }
                'integrate' { $output = Invoke-TeamIntegration $state $document $directory $config }
                'replan' { $output = Invoke-TeamReplan $state $document (Read-TeamData $Plan) $config $directory $Task $Reason }
                'rollback' { $output = Undo-TeamIntegration $state $directory $Task $Reason }
                'repair-integration' { $output = New-TeamIntegrationRepair $state $document $config $directory $GlueScope $Reason }
                'resolve-review' { $output = Resolve-TeamReview $state $document $directory $Stage $Task (Read-TeamData $Disposition) }
                'report-cost' {
                    if ($Amount -lt 0 -or -not $Evidence) { Stop-TeamError 10 'Cost report requires nonnegative amount and evidence file' }
                    $hash = Get-TeamHash $Evidence
                    $path = Join-Path $directory "cost-receipts/$hash.json"
                    if (Test-Path -LiteralPath $path) { Stop-TeamError 10 'Cost evidence already recorded' }
                    Write-TeamData $path @{amount=$Amount;evidence_hash=$hash;recorded_at=[DateTime]::UtcNow.ToString('o')}
                    $state.known_cost += $Amount
                    if ($state.known_cost -ge $config.budget.soft_limit) { Add-TeamEvent $directory 'cost_soft_limit_reached' @{ cost=$state.known_cost } }
                    if ($state.known_cost -ge $config.budget.hard_limit) { $state.status='PAUSED'; Add-TeamEvent $directory 'cost_hard_limit_reached' }
                    Save-TeamState $state $directory; $output=@{known_cost=$state.known_cost;unknown_usage=$state.unknown_usage}
                }
                'resume' {
                    $doctor = Test-TeamDoctor $config $Repo -AllowUnverifiedRuntime:$AllowUnverifiedRuntime
                    if (-not $doctor.success) { Stop-TeamError 20 ($doctor.problems -join '; ') }
                    $output = Resume-TeamRun $state $document $config $directory
                }
                'cleanup' { $output = Remove-TeamWorktrees $state $directory }
                'stop' {
                    Stop-TeamOwnedProcesses $state $directory
                    $output = @{ status = 'CANCELLED'; evidence_preserved = $true }
                }
            }
        }
    }
    $output | ConvertTo-Json -Depth 100 -Compress:$Json
} catch {
    $exitCode = if ($_.Exception.Data.Contains('TeamExitCode')) { [int]$_.Exception.Data['TeamExitCode'] } else { 90 }
    if ($runData) {
        if ($exitCode -eq 60) {
            $runData.state['hard_stop']=$true
            New-TeamEscalation $runData.state $runData.directory 'hard_stop' $_.Exception.Message
        } elseif ($exitCode -eq 70 -and $runData.state.status -ne 'ESCALATED') {
            New-TeamEscalation $runData.state $runData.directory 'capacity_or_budget' $_.Exception.Message
        }
        if ($exitCode -in @(30,31,40,50,60,80,81,82,90) -and $Command -in @('run','resume','integrate','replan','rollback')) {
            if ($runData.state.status -ne 'ESCALATED') { $runData.state.status = 'PAUSED' }
            Save-TeamState $runData.state $runData.directory
        }
        Add-TeamEvent $runData.directory 'command_failed' @{ command = $Command; exit_code = $exitCode; message = $_.Exception.Message }
    }
    @{ success = $false; exit_code = $exitCode; error = $_.Exception.Message } | ConvertTo-Json -Compress
} finally {
    if ($lock) {
        if ($runData -and $runData.state.status -in @('COMPLETED','CANCELLED')) { Unlock-TeamRepo $Repo $runData.state.run_id }
        $lock.Dispose()
    }
}
exit $exitCode
