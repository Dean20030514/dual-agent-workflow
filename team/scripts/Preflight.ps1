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
    $nativeServices=@('subagent','subagent-spawn-in-process','subagent-fork-in-process','tool-subagent','tool-subagent-fork')
    $available=@($nativeServices | Where-Object { $id=$_; @($nodes | Where-Object { $_['id'] -eq $id -and -not $_['disabled'] }).Count -eq 1 })
    return @{ verified = $true; provider = $route.provider; model = $route.model; evidence = 'composed config + effective settings'; input = 'I1'; output = 'O2'; exit = 'E2-source'
        native_available=($available.Count -eq $nativeServices.Count);native_services=$available }
}

function Get-TeamCapabilityDecision([string]$InputAxis, [string]$OutputAxis, [string]$ExitAxis,
    [bool]$RouteVerified, [bool]$NativeAvailable, [bool]$NativeObservable, [bool]$VerifiedAdapter = $false) {
    $modes=@('L0'); $action='no production Team dispatch'; $experimental=@(); $extension=$false
    if ($RouteVerified) {
        if ($InputAxis -in @('I3','I2') -and $OutputAxis -in @('O4','O3') -and $ExitAxis -eq 'E2') {
            $modes+=@('L1','L2','L3'); $action='structured native transport'
        } elseif (($InputAxis -in @('I3','I2') -and $OutputAxis -eq 'O2' -or
            $InputAxis -eq 'I1' -and $OutputAxis -in @('O3','O2')) -and $ExitAxis -eq 'E2') {
            $modes+=@('L1','L2'); $action='adapter input/output wrapping required'
        } elseif ($InputAxis -eq 'I1' -and $OutputAxis -eq 'O1' -and $ExitAxis -in @('E1','E2')) {
            $experimental=@('L1'); $action='stabilize adapter before production dispatch'
        }
    } else { $action='unverified model route; dispatch forbidden' }
    if (-not $NativeAvailable) { $modes=@($modes | Where-Object { $_ -ne 'L3' }) }
    $matrixModes=@($modes)
    # This is an explicit existing adapter extension, not a reclassification of
    # native I1/O2 as I3/O4. Its scope and evidence are recorded in the spike decision.
    if ($VerifiedAdapter -and $RouteVerified -and $NativeAvailable -and $NativeObservable -and
        $InputAxis -eq 'I1' -and $OutputAxis -eq 'O2' -and $ExitAxis -eq 'E2') {
        $modes+=@('L3'); $extension=$true
    }
    $limited=$NativeAvailable -and -not $NativeObservable -and 'L3' -in $modes
    return @{input=$InputAxis;output=$OutputAxis;exit=$ExitAxis;matrix_modes=$matrixModes;allowed_modes=$modes;
        experimental_modes=$experimental;action=$action;adapter_l3_extension=$extension;
        native_available=$NativeAvailable;native_observable=$NativeObservable;l3_limited=$limited;
        result_child_summary_required=$true;decision='team/spike/INTEGRATION_DECISION.md'}
}

function Assert-TeamCapability($Plan, $Doctor) {
    if ($Plan.mode -notin $Doctor.capabilities.allowed_modes) {
        Stop-TeamError 20 "Mode $($Plan.mode) is not admitted by the current capability profile; revise the plan explicitly. $($Doctor.capabilities.action)"
    }
}

function Test-TeamDoctor($Manifest, [string]$Repo, [switch]$AllowUnverifiedRuntime) {
    Test-TeamSchema $Manifest 'manifest'
    $problems = [Collections.Generic.List[string]]::new()
    $lead = Get-TeamLeadEvidence $Manifest
    if (-not $lead.runtime_verified) { $problems.Add("Lead: $($lead.reason)") }
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
    $routing = @(Test-TeamRoutingFixtures)
    if (@($routing | Where-Object status -ne 'ROUTING_PASS').Count) { $problems.Add('Local routing compliance fixtures failed') }
    $routingHealth = Get-TeamRoute '' $Repo $Manifest
    # The certified transport profile is tied to the actual version, not merely a
    # user-edited manifest pin. An override keeps diagnostics available, not L3 proof.
    $certified=$versions['dsh'] -ceq '0.1.5-rc.1' -and $Manifest.runtime.profile -ceq 'headless'
    $native=$Manifest.subagents.enabled -and $route['native_available'] -eq $true
    $observable=Test-Path -LiteralPath (Join-Path $PSScriptRoot 'native-guard.mjs')
    $adapterVerified=$certified -and $route['provider'] -ceq 'deepseek-official' -and $route['model'] -ceq 'deepseek-flash'
    $capabilities=Get-TeamCapabilityDecision $(if ($certified) {'I1'} else {'UNKNOWN'}) $(if ($certified) {'O2'} else {'UNKNOWN'}) `
        $(if ($certified) {'E2'} else {'UNKNOWN'}) ($route.verified -eq $true) $native $observable $adapterVerified
    $capabilities['unverified_transport_override']=$false
    if (-not $certified -and $AllowUnverifiedRuntime -and $route.verified -eq $true -and $Manifest.runtime.profile -ceq 'headless') {
        $capabilities.allowed_modes=@('L0','L1','L2')
        $capabilities.action='explicit UNVERIFIED_RUNTIME override; transport assumptions are not certified; L3 extension unavailable'
        $capabilities.unverified_transport_override=$true
    }
    if (-not $Manifest.team.enabled) { $capabilities.allowed_modes=@('L0');$capabilities.action='Team disabled' }
    $lockPath = Join-Path $Repo 'team/runtime/.team-lock'
    return @{
        success = ($problems.Count -eq 0); versions = $versions; powershell = $PSVersionTable.PSVersion.ToString()
        route = $route; lead = $lead; routing = $routing; problems = $problems.ToArray()
        routing_health = @{auto_route=$routingHealth.auto_route;consecutive_misroutes=$routingHealth.consecutive_misroutes;notice=$routingHealth.notice;lead_action=$routingHealth.lead_action}
        capabilities = $capabilities
        runtime_status = $(if ($AllowUnverifiedRuntime) { 'UNVERIFIED_RUNTIME' } else { 'PINNED_RUNTIME' })
        codex_shell = [bool](Get-Command pwsh -ErrorAction SilentlyContinue)
        lock = $(if (Test-Path -LiteralPath $lockPath) { Read-TeamData $lockPath } else { $null })
        integration_map = 'team/spike/EXISTING_INTEGRATION_MAP.md'
        native_subagents = @{enabled=$Manifest.subagents.enabled;available=$native;observable=$observable;max_depth=2;max_agents_per_worker=3;mechanism='native registry admission guard; parent permission inheritance'}
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
    if ([string]::IsNullOrWhiteSpace($TaskText)) { Stop-TeamError 10 'TaskText is required for a routing observation' }
    $runtime=Get-TeamChild $Repo 'team/runtime'; [IO.Directory]::CreateDirectory($runtime) | Out-Null
    try { $handle=[IO.File]::Open((Join-Path $runtime '.routing-lock'),'OpenOrCreate','ReadWrite','None') }
    catch { Stop-TeamError 20 'Routing observation is already being updated' }
    try {
        $path=Join-Path $runtime 'routing.json'
        $routing=if (Test-Path -LiteralPath $path) {Read-TeamData $path} else {@{consecutive_misroutes=0;auto_route='normal'}}
        $recommendation=Get-TeamRoute $TaskText $Repo $Manifest
        $actual=$recommendation.recommended_mode
        if ($actual -ne $ExpectedMode) {$routing.consecutive_misroutes++} else {$routing.consecutive_misroutes=0}
        if ($routing.consecutive_misroutes -ge $Manifest.routing.misroute_threshold) {$routing.auto_route='degraded'}
        # Retain the latest explicit expectation for each observed task so revalidation
        # exercises the real regressions, not just four permanently passing examples.
        $prior=@(); if ($routing.Contains('observations')) { $prior=@($routing.observations | Where-Object task -CNE $TaskText) }
        $routing['observations']=@($prior)+@(@{task=$TaskText;expected=$ExpectedMode;actual=$actual;timestamp=[DateTime]::UtcNow.ToString('o')})
        $routing['notice']=if ($routing.auto_route -eq 'degraded') {'Call route explicitly for every complex task until revalidate-route succeeds.'} else {$null}
        Write-TeamData $path $routing
        Add-TeamEvent $runtime $(if ($actual -eq $ExpectedMode) {'ROUTING_PASS'} else {'ROUTING_MISMATCH'}) @{actual=$actual;expected=$ExpectedMode}
        return $routing
    } finally { $handle.Dispose() }
}

function Test-TeamRoutingFixtures {
    $fixtures = [ordered]@{ 'README typo' = 'L0'; 'SQL optimization' = 'L1'; 'avatar upload' = 'L2'; 'auth redesign' = 'L3' }
    foreach ($text in $fixtures.Keys) {
        # Compliance tests the heuristic independently of an enabled=false switch.
        $actual = (Get-TeamRoute $text).recommended_mode
        @{ task=$text;expected=$fixtures[$text];actual=$actual;status=$(if ($actual -eq $fixtures[$text]) {'ROUTING_PASS'} else {'ROUTING_MISMATCH'}) }
    }
}

function Reset-TeamRoutingHealth($Manifest, [string]$Repo, [string]$Reason) {
    if ([string]::IsNullOrWhiteSpace($Reason)) { Stop-TeamError 10 'Revalidation requires -Reason describing the routing correction' }
    $runtime=Get-TeamChild $Repo 'team/runtime'; [IO.Directory]::CreateDirectory($runtime) | Out-Null
    try { $handle=[IO.File]::Open((Join-Path $runtime '.routing-lock'),'OpenOrCreate','ReadWrite','None') }
    catch { Stop-TeamError 20 'Routing observation is already being updated' }
    try {
        $path=Join-Path $runtime 'routing.json'
        $routing=if (Test-Path -LiteralPath $path) {Read-TeamData $path} else {@{consecutive_misroutes=0;auto_route='normal'}}
        $checks=@(Test-TeamRoutingFixtures)
        if ($routing.Contains('observations')) {
            foreach ($observation in $routing.observations) {
                $actual=(Get-TeamRoute $observation.task $Repo $Manifest).recommended_mode
                $checks+=@{task=$observation.task;expected=$observation.expected;actual=$actual;
                    status=$(if ($actual -eq $observation.expected) {'ROUTING_PASS'} else {'ROUTING_MISMATCH'})}
            }
        } elseif ($routing.auto_route -eq 'degraded') {
            # A historical counter does not contain enough evidence to replay its failures.
            Stop-TeamError 20 'Legacy degraded routing has no observations; record the affected tasks before revalidating'
        }
        $passed=@($checks | Where-Object status -ne 'ROUTING_PASS').Count -eq 0
        $evidence=@{passed=$passed;reason=$Reason;checks=$checks;timestamp=[DateTime]::UtcNow.ToString('o')}
        $routing['last_revalidation']=$evidence
        if ($passed) { $routing.auto_route='normal';$routing.consecutive_misroutes=0;$routing['notice']=$null }
        Write-TeamData $path $routing
        Add-TeamEvent $runtime 'routing_revalidated' $evidence
        return @{success=$passed;auto_route=$routing.auto_route;checks=$checks;reason=$Reason}
    } finally { $handle.Dispose() }
}
