function Invoke-TeamCapture([string]$Command, [string[]]$Arguments, [string]$Directory) {
    $temp = Join-Path ([IO.Path]::GetTempPath()) ('team-probe-' + [guid]::NewGuid().ToString('N'))
    [IO.Directory]::CreateDirectory($temp) | Out-Null
    try {
        $handle = New-TeamProcess $Command $Arguments $Directory (Join-Path $temp 'out') (Join-Path $temp 'err')
        $code = Wait-TeamProcess $handle 45
        if ($code -ne 0) { Stop-TeamError 20 "Capability command failed (exit $code)" }
        return [IO.File]::ReadAllText((Join-Path $temp 'out'))
    } finally {
        # Only remove our two exact probe files; no recursive filesystem deletion.
        foreach ($name in @('out','err')) {
            $path = Join-Path $temp $name
            if (Test-Path -LiteralPath $path) { [IO.File]::Delete($path) }
        }
        if (Test-Path -LiteralPath $temp) { [IO.Directory]::Delete($temp) }
    }
}

function Test-DshRoute($Manifest, [string]$Repo, [string]$Patch = '') {
    $dsh = (Get-Command dsh -ErrorAction Stop).Source
    $arguments = @('--profile', $Manifest.runtime.profile)
    if ($Patch) { $arguments += @('--patch', $Patch) }
    $arguments += '--dump-config'
    $dump = Invoke-TeamCapture $dsh $arguments $Repo
    Import-Module powershell-yaml -MinimumVersion 0.4.12
    $nodes = ConvertFrom-Yaml $dump
    $default = @($nodes | Where-Object { $_['id'] -eq 'agent-default-model' -and -not $_['disabled'] })
    if ($default.Count -ne 1) { Stop-TeamError 20 'Cannot resolve one DSH model service' }
    $route = $default[0].config
    $dshHome = if ($env:DSH_HOME) { $env:DSH_HOME } else { Join-Path $env:USERPROFILE '.dsh' }
    $settingsPath = Join-Path $dshHome 'settings.yaml'
    if (Test-Path -LiteralPath $settingsPath) {
        $settings = Read-TeamData $settingsPath
        if ($settings.Contains('agent-default-model')) { $route = $settings['agent-default-model'] }
    }
    if ($route.provider -cne $Manifest.models.worker.provider -or $route.model -cne $Manifest.models.worker.runtime_model) {
        Stop-TeamError 20 'DSH effective model route differs from manifest; dispatch forbidden'
    }
    foreach ($required in @('llm-deepseek','headless-startup','headless-runner')) {
        if (-not @($nodes | Where-Object { $_['id'] -eq $required -and -not $_['disabled'] }).Count) {
            Stop-TeamError 20 "Required DSH service missing: $required"
        }
    }
    if ($Patch) {
        foreach ($tool in @('tool-subagent','tool-subagent-fork','tool-workflow','tool-ralph')) {
            if (@($nodes | Where-Object { $_['id'] -eq $tool -and -not $_['disabled'] }).Count) {
                Stop-TeamError 20 "L1/L2 delegation tool was not disabled: $tool"
            }
        }
    }
    return @{ verified = $true; provider = $route.provider; model = $route.model; evidence = 'composed config + effective settings'; input = 'I1'; output = 'O2'; exit = 'E2-source' }
}

function Test-TeamDoctor($Manifest, [string]$Repo, [switch]$AllowUnverifiedRuntime) {
    Test-TeamSchema $Manifest 'manifest'
    $problems = [Collections.Generic.List[string]]::new()
    $versions = @{}; $route = @{ verified = $false }
    foreach ($command in @('dsh','codex')) {
        try {
            $source = (Get-Command $command -ErrorAction Stop).Source
            $version = (Invoke-TeamCapture $source @('--version') $Repo).Trim() -replace '^codex-cli\s+', ''
            $versions[$command] = $version
            if ($version -cne $Manifest.runtime["${command}_version"] -and -not $AllowUnverifiedRuntime) {
                $problems.Add("$command outside verified version pin")
            }
        } catch { $problems.Add("$command unavailable: $($_.Exception.Message)") }
    }
    try { $route = Test-DshRoute $Manifest $Repo } catch { $problems.Add($_.Exception.Message) }
    $fixtures = @{ 'README typo' = 'L0'; 'SQL optimization' = 'L1'; 'avatar upload' = 'L2'; 'auth redesign' = 'L3' }
    $routing = @($fixtures.Keys | ForEach-Object {
        $actual = (Get-TeamRoute $_).recommended_mode
        @{ task = $_; expected = $fixtures[$_]; actual = $actual; status = $(if ($actual -eq $fixtures[$_]) { 'ROUTING_PASS' } else { 'ROUTING_MISMATCH' }) }
    })
    $lockPath = Join-Path $Repo 'team/runtime/.team-lock'
    return @{
        success = ($problems.Count -eq 0); versions = $versions; powershell = $PSVersionTable.PSVersion.ToString()
        route = $route; routing = $routing; problems = $problems.ToArray()
        runtime_status = $(if ($AllowUnverifiedRuntime) { 'UNVERIFIED_RUNTIME' } else { 'PINNED_RUNTIME' })
        codex_shell = [bool](Get-Command pwsh -ErrorAction SilentlyContinue)
        lock = $(if (Test-Path -LiteralPath $lockPath) { Read-TeamData $lockPath } else { $null })
        integration_map = 'team/spike/EXISTING_INTEGRATION_MAP.md'
        native_subagents = @{enabled=$Manifest.subagents.enabled;max_depth=2;max_agents_per_worker=3;mechanism='native registry admission guard; parent permission inheritance'}
    }
}

function New-DshPatch([string]$Path, $Guard = $null) {
    $native = $Guard -and $Guard.maxDepth -eq 2
    $patch = @('tool-subagent','tool-subagent-fork') | ForEach-Object {
        $fork = $_ -eq 'tool-subagent-fork'
        @{ id = $_; disabled = (-not $native); config = @{maxDepth=2; backgroundMode='one-shot';
            provider=$(if ($fork) {'fork'} else {'spawn'});toolName=$(if ($fork) {'subagent_fork'} else {'subagent'});modelSelectionSettings=$false} }
    }
    $patch += @('tool-workflow','tool-ralph') | ForEach-Object { @{id=$_;disabled=$true} }
    if ($Guard) {
        $patch += @{insert=@(@{id='team-native-guard';name=(Join-Path $PSScriptRoot 'native-guard.mjs');config=$Guard})}
    }
    Write-TeamData $Path @($patch)
}

function Record-TeamRoute($Manifest, [string]$Repo, [string]$TaskText, [string]$ExpectedMode) {
    if ($ExpectedMode -notin @('L0','L1','L2','L3')) { Stop-TeamError 10 'ExpectedMode must be L0-L3' }
    $runtime=Get-TeamChild $Repo 'team/runtime'; [IO.Directory]::CreateDirectory($runtime) | Out-Null
    try { $handle=[IO.File]::Open((Join-Path $runtime '.routing-lock'),'OpenOrCreate','ReadWrite','None') }
    catch { Stop-TeamError 20 'Routing observation is already being updated' }
    try {
        $path=Join-Path $runtime 'routing.json'
        $routing=if (Test-Path -LiteralPath $path) {Read-TeamData $path} else {@{consecutive_misroutes=0;auto_route='normal'}}
        $actual=(Get-TeamRoute $TaskText).recommended_mode
        if ($actual -ne $ExpectedMode) {$routing.consecutive_misroutes++} else {$routing.consecutive_misroutes=0;$routing.auto_route='normal'}
        if ($routing.consecutive_misroutes -ge $Manifest.routing.misroute_threshold) {$routing.auto_route='degraded'}
        Write-TeamData $path $routing
        Add-TeamEvent $runtime $(if ($actual -eq $ExpectedMode) {'ROUTING_PASS'} else {'ROUTING_MISMATCH'}) @{actual=$actual;expected=$ExpectedMode}
        return $routing
    } finally { $handle.Dispose() }
}
