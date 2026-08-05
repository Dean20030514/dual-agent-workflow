#requires -Version 7.0
# Shared result model, baseline registry and aggregation logic for tools/validate.
# Dot-sourced by validate.ps1, the check modules and the Pester tests.
# Contract source: docs/ai/TASK_BRIEF.md AC-1/AC-9 and IMPLEMENTATION_PLAN.md
# Frozen Acceptance P2/P3/P5. Strict mode is set by the validate.ps1 entry point,
# not here, so dot-sourcing into test harnesses stays side-effect free.

$script:ValidatorCheckStatuses = @('PASS', 'BASELINE', 'SKIP', 'FAIL', 'ENVIRONMENT_ERROR')
$script:ValidatorSkipReason = 'prerequisite_not_landed'
$script:ValidatorBaselineRequiredFields = @(
    'id', 'check_id', 'exact_target', 'exact_observation', 'reason',
    'payoff', 'introduced_by_plan', 'owner', 'status'
)

# Reads a named value from either a dictionary (YAML load result) or an object,
# returning $null when absent - keeps schema validation strict-mode safe.
function Get-EntryValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Entry,
        [Parameter(Mandatory)][string]$Name
    )
    if ($Entry -is [System.Collections.IDictionary]) {
        if ($Entry.Contains($Name)) { return $Entry[$Name] }
        return $null
    }
    $prop = $Entry.PSObject.Properties[$Name]
    if ($null -ne $prop) { return $prop.Value }
    return $null
}

function New-ValidationFinding {
    # Pure in-memory object factory: no system state is changed, ShouldProcess
    # semantics do not apply despite the New- verb.
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$CheckId,
        [Parameter(Mandatory)][string]$Target,
        [Parameter(Mandatory)][string]$Observation,
        [int]$Line
    )
    [pscustomobject]@{
        CheckId     = $CheckId
        Target      = $Target
        Observation = $Observation
        Line        = if ($PSBoundParameters.ContainsKey('Line')) { $Line } else { $null }
        Status      = 'FAIL'
        BaselineId  = $null
    }
}

function New-CheckResult {
    # Pure in-memory object factory: no system state is changed, ShouldProcess
    # semantics do not apply despite the New- verb.
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$CheckId,
        [Parameter(Mandatory)][ValidateSet('PASS', 'BASELINE', 'SKIP', 'FAIL', 'ENVIRONMENT_ERROR')]
        [string]$Status,
        [object[]]$Findings = @(),
        [string]$SkipReason,
        [string]$PendingWorkItem,
        [string]$Message
    )
    if ($Status -eq 'SKIP') {
        if ($SkipReason -cne $script:ValidatorSkipReason) {
            throw "SKIP requires reason '$($script:ValidatorSkipReason)' (got '$SkipReason'); any other gap is FAIL or ENVIRONMENT_ERROR."
        }
        if ([string]::IsNullOrWhiteSpace($PendingWorkItem)) {
            throw 'SKIP requires -PendingWorkItem naming the work item whose landing activates the check.'
        }
    }
    if ($Status -eq 'ENVIRONMENT_ERROR' -and [string]::IsNullOrWhiteSpace($Message)) {
        throw 'ENVIRONMENT_ERROR requires -Message with install/repair guidance.'
    }
    [pscustomobject]@{
        CheckId         = $CheckId
        Status          = $Status
        Findings        = @($Findings)
        SkipReason      = $SkipReason
        PendingWorkItem = $PendingWorkItem
        Message         = $Message
    }
}

function Get-BaselineEntrySchemaError {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Entry)
    $errors = @()
    foreach ($field in $script:ValidatorBaselineRequiredFields) {
        $value = Get-EntryValue -Entry $Entry -Name $field
        if ($null -eq $value -or ($value -is [string] -and [string]::IsNullOrWhiteSpace($value))) {
            $errors += "missing required field '$field'"
        }
    }
    $payoff = Get-EntryValue -Entry $Entry -Name 'payoff'
    if ($null -ne $payoff) {
        foreach ($sub in @('work_item', 'condition')) {
            $subValue = Get-EntryValue -Entry $payoff -Name $sub
            if ($null -eq $subValue -or ($subValue -is [string] -and [string]::IsNullOrWhiteSpace($subValue))) {
                $errors += "missing required field 'payoff.$sub'"
            }
        }
    }
    $status = Get-EntryValue -Entry $Entry -Name 'status'
    if ($null -ne $status -and $status -cne 'active') {
        $errors += "status must be 'active' (got '$status'); paid-off exemptions are removed, never parked"
    }
    return $errors
}

function Import-BaselineRegistry {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)
    $registry = [pscustomobject]@{
        Entries      = @()
        ParseError   = $null
        SchemaErrors = @()
    }
    if (-not (Test-Path -LiteralPath $Path)) {
        # A missing registry file is a valid empty baseline, not an error.
        return $registry
    }
    if (-not (Get-Command -Name 'ConvertFrom-Yaml' -ErrorAction Ignore)) {
        throw 'ENVIRONMENT_ERROR: powershell-yaml module is not available. Install per tools/validate/requirements.psd1.'
    }
    try {
        $raw = Get-Content -LiteralPath $Path -Raw
        $data = ConvertFrom-Yaml -Yaml $raw
    }
    catch {
        $registry.ParseError = "baseline registry '$Path' is not parseable YAML: $($_.Exception.Message)"
        return $registry
    }
    $entries = @()
    $schemaErrors = @()
    # An existing registry file must declare the 'baseline' root key explicitly
    # (baseline: [] for "no exemptions"). A missing or mistyped root key would
    # otherwise silently disable the whole registry - machine-auditable schema
    # (AC-9) demands a loud error instead.
    $rootKeyPresent = ($null -ne $data) -and ($data -is [System.Collections.IDictionary]) -and $data.Contains('baseline')
    if (-not $rootKeyPresent) {
        $schemaErrors += "registry file exists but has no 'baseline' root key; declare ""baseline: []"" for an explicitly empty registry"
    }
    else {
        $baselineList = $data['baseline']
        if ($null -ne $baselineList) { $entries = @($baselineList | Where-Object { $null -ne $_ }) }
    }
    for ($i = 0; $i -lt $entries.Count; $i++) {
        $entryId = Get-EntryValue -Entry $entries[$i] -Name 'id'
        $label = if ($null -ne $entryId) { "entry '$entryId'" } else { "entry #$($i + 1)" }
        foreach ($entryError in @(Get-BaselineEntrySchemaError -Entry $entries[$i])) {
            $schemaErrors += "${label}: $entryError"
        }
    }
    # Duplicate ids poison stale detection (matched entries are tracked by id):
    # a stale twin would be masked by its matching sibling. Reject loudly.
    foreach ($group in ($entries | Group-Object { [string](Get-EntryValue -Entry $_ -Name 'id') })) {
        if ($group.Count -gt 1 -and -not [string]::IsNullOrWhiteSpace($group.Name)) {
            $schemaErrors += "duplicate entry id '$($group.Name)' ($($group.Count) entries); ids must be unique for stale detection to be trustworthy"
        }
    }
    $registry.Entries = $entries
    $registry.SchemaErrors = $schemaErrors
    return $registry
}

function Resolve-BaselineMatch {
    [CmdletBinding()]
    param(
        [object[]]$Findings = @(),
        [object[]]$Entries = @(),
        [Parameter(Mandatory)][string[]]$ExecutedCheckIds
    )
    $matchedEntryIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($finding in $Findings) {
        foreach ($entry in $Entries) {
            # Exact ordinal equality on check + target + observation. No globs,
            # no regex, no case folding (AC-9: exact-match-only exemptions).
            if ((Get-EntryValue -Entry $entry -Name 'check_id') -cne $finding.CheckId) { continue }
            if ((Get-EntryValue -Entry $entry -Name 'exact_target') -cne $finding.Target) { continue }
            if ((Get-EntryValue -Entry $entry -Name 'exact_observation') -cne $finding.Observation) { continue }
            $finding.Status = 'BASELINE'
            $finding.BaselineId = [string](Get-EntryValue -Entry $entry -Name 'id')
            [void]$matchedEntryIds.Add($finding.BaselineId)
            break
        }
    }
    # An active entry matching nothing is stale (drift already gone) - but only
    # for checks that actually ran; a skipped or unselected check proves nothing.
    $stale = @($Entries | Where-Object {
            $checkId = [string](Get-EntryValue -Entry $_ -Name 'check_id')
            $entryId = [string](Get-EntryValue -Entry $_ -Name 'id')
            ($ExecutedCheckIds -ccontains $checkId) -and (-not $matchedEntryIds.Contains($entryId))
        })
    [pscustomobject]@{
        Findings     = @($Findings)
        StaleEntries = $stale
    }
}

function Get-CheckStatus {
    [CmdletBinding()]
    param([object[]]$Findings = @())
    if (@($Findings).Count -eq 0) { return 'PASS' }
    if (@($Findings | Where-Object { $_.Status -ceq 'FAIL' }).Count -gt 0) { return 'FAIL' }
    return 'BASELINE'
}

function Get-RunSummary {
    [CmdletBinding()]
    param(
        [object[]]$CheckResults = @(),
        [object[]]$StaleEntries = @(),
        [string[]]$RegistryErrors = @()
    )
    $statuses = @($CheckResults | ForEach-Object { $_.Status })
    $runStatus =
    if ($statuses -ccontains 'ENVIRONMENT_ERROR') {
        # Broken environment makes every other verdict unreliable: report it first.
        'ENVIRONMENT_ERROR'
    }
    elseif ($statuses -ccontains 'FAIL' -or @($StaleEntries).Count -gt 0 -or @($RegistryErrors).Count -gt 0) {
        'FAIL'
    }
    elseif ($statuses -ccontains 'BASELINE') {
        'PASS_WITH_BASELINE'
    }
    else {
        'PASS'
    }
    $exitCode = switch ($runStatus) {
        'PASS' { 0 }
        'PASS_WITH_BASELINE' { 0 }
        'FAIL' { 1 }
        'ENVIRONMENT_ERROR' { 2 }
    }
    [pscustomobject]@{
        RunStatus      = $runStatus
        ExitCode       = $exitCode
        StaleEntries   = @($StaleEntries)
        RegistryErrors = @($RegistryErrors)
    }
}

# Shared active-scan filter (AC-2/AC-4/AC-5/AC-11): archived evidence and
# negative fixtures are never scan SUBJECTS. They stay valid link TARGETS and
# remain covered by SecretScan (AC-7) and Provenance (AC-6) - scope contract in
# docs/ai/TASK_BRIEF.md Constraints.
function Select-ActiveScanFile {
    [CmdletBinding()]
    param([object[]]$Paths = @())
    return @($Paths | Where-Object {
            $path = [string]$_
            (-not ($path -clike 'docs/ai/archive/*')) -and
            (-not ($path -clike 'tools/validate/tests/fixtures/*'))
        })
}

function Test-RequiredModule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [string]$RequiredVersion
    )
    $available = @(Get-Module -ListAvailable -Name $Name -ErrorAction Ignore)
    if ($RequiredVersion) {
        $available = @($available | Where-Object { $_.Version -eq [version]$RequiredVersion })
    }
    return $available.Count -gt 0
}

function Import-RequirementManifest {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)
    return Import-PowerShellDataFile -LiteralPath $Path
}

function Get-TrackedFile {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$RepoRoot)
    $output = & git -C $RepoRoot ls-files 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "git ls-files failed in '$RepoRoot' (exit $LASTEXITCODE): $output"
    }
    return @($output | ForEach-Object { [string]$_ } | Where-Object { $_ })
}
