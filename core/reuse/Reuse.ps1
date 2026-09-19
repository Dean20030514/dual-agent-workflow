# Reuse-first protocol: pure shared validator for the canonical reuse documents.
# Self-contained by design: no Team state, no global root, no subprocess launch and no
# network access. The only file system reads are the structural backstop, which reads
# reuse.schema.json on every validation, and Get-ReuseProtocolIdentity, which hashes the
# three protocol files. Both resolve next to this script. Error text is English and
# independent of the Team exit-code contract.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:ReuseVersion = 1
$script:ReuseSchemaFile = 'reuse.schema.json'
$script:ReuseReadmeFile = 'README.md'
$script:ReuseValidatorFile = 'Reuse.ps1'
# Identifiers are case sensitive tokens: candidate ids, task refs and deviation refs.
$script:ReuseIdPattern = '^[A-Za-z0-9][A-Za-z0-9._:-]{0,79}$'
$script:ReuseChangeKinds = @('new_implementation', 'new_dependency', 'architecture', 'protocol',
    'docs_only', 'diagnosed_local_bug', 'established_repo_pattern', 'data_only')
# The first four change kinds create new capability: prior art is mandatory for them.
$script:ReusePriorArtKinds = @('new_implementation', 'new_dependency', 'architecture', 'protocol')
# The last four change kinds may justify a skip; the free explanation stays in 'reason'.
$script:ReuseSkipReasons = @('docs_only', 'diagnosed_local_bug', 'established_repo_pattern', 'data_only')
$script:ReuseSearchSources = @('github_repositories', 'github_code', 'primary_docs', 'package_registry')
$script:ReuseSearchOutcomes = @('results', 'no_results', 'unavailable')
# A search that answered is a success: finding nothing is a legitimate zero result.
# Only 'unavailable' is a failure, and a failure blocks instead of completing.
$script:ReuseSuccessfulOutcomes = @('results', 'no_results')
$script:ReuseStrategies = @('adopt', 'port', 'wrap', 'reference', 'build')
$script:ReuseCandidateDecisions = @('adopt', 'port', 'wrap', 'reference', 'reject')
# A completed required decision must have succeeded on all three prior-art channels.
$script:ReuseCompletionSources = @('github_repositories', 'github_code', 'primary_docs')

# Raises the single error shape this protocol uses. Callers can rely on
# Exception.Data.ReuseProtocolError and Exception.Data.ReuseErrorKind.
function Stop-ReuseError {
    param([string]$Kind, [string]$Message)
    $errorObject = [System.InvalidOperationException]::new("reuse/${Kind}: $Message")
    $errorObject.Data['ReuseProtocolError'] = $true
    $errorObject.Data['ReuseErrorKind'] = $Kind
    throw $errorObject
}

$script:ReuseProtocolRoot = if ($PSScriptRoot) { $PSScriptRoot }
    elseif ($PSCommandPath) { Split-Path -Parent $PSCommandPath } else { '' }
if (-not $script:ReuseProtocolRoot) {
    Stop-ReuseError 'load_error' 'cannot resolve the protocol directory of this script'
}

function Get-ReuseTextHash {
    param($Text)
    return [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes([string]$Text))).ToLowerInvariant()
}

function Get-ReuseFileHash {
    param([string]$Path)
    return [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData([IO.File]::ReadAllBytes($Path))).ToLowerInvariant()
}

# Deterministic JSON: object keys sorted ordinally, arrays in order, no whitespace.
function Get-ReuseCanonicalJson {
    param($Value)
    if ($Value -is [Collections.IDictionary]) {
        $members = @(foreach ($key in @($Value.Keys | Sort-Object -CaseSensitive)) {
            (ConvertTo-Json -InputObject ([string]$key) -Compress) + ':' + (Get-ReuseCanonicalJson $Value[$key])
        })
        return '{' + ($members -join ',') + '}'
    }
    if ($Value -is [Collections.IList]) {
        return '[' + (@(foreach ($item in $Value) { Get-ReuseCanonicalJson $item }) -join ',') + ']'
    }
    return ConvertTo-Json -InputObject $Value -Depth 100 -Compress
}

# Normalizes any accepted input (hashtable, ordered dictionary, PSCustomObject) into a
# hashtable document so later checks never depend on the caller's object model.
function ConvertTo-ReuseDocument {
    param($Value, [string]$Kind)
    if ($null -eq $Value) { Stop-ReuseError $Kind 'the document is null' }
    if ($Value -is [string] -or $Value -is [ValueType]) {
        Stop-ReuseError $Kind "the document must be a JSON object, not $($Value.GetType().Name)"
    }
    try { $json = ConvertTo-Json -InputObject $Value -Depth 100 -Compress }
    catch { Stop-ReuseError $Kind "the document cannot be serialized: $($_.Exception.Message)" }
    try { $document = ConvertFrom-Json -InputObject $json -AsHashtable -Depth 100 }
    catch { Stop-ReuseError $Kind "the document cannot be parsed: $($_.Exception.Message)" }
    if ($null -eq $document) { Stop-ReuseError $Kind 'the document must be a JSON object, not null or an empty array' }
    if (-not ($document -is [Collections.IDictionary])) {
        Stop-ReuseError $Kind "the document must be a JSON object, not $($document.GetType().Name)"
    }
    return $document
}

function Get-ReuseRequiredField {
    param($Document, [string]$Name, [string]$Kind)
    if (-not $Document.ContainsKey($Name)) { Stop-ReuseError $Kind "required field '$Name' is missing" }
    # The comma operator keeps a one element array an array instead of unrolling it.
    return , $Document[$Name]
}

function Assert-ReuseText {
    # Prose: must be a non-blank string. Whitespace-only values are always rejected.
    param($Value, [string]$Field, [string]$Kind)
    if ($null -eq $Value) { Stop-ReuseError $Kind "'$Field' must be a string, not null" }
    if (-not ($Value -is [string])) { Stop-ReuseError $Kind "'$Field' must be a string, not $($Value.GetType().Name)" }
    if (-not $Value.Trim()) { Stop-ReuseError $Kind "'$Field' must not be empty or whitespace only" }
    return $Value
}

function Assert-ReuseToken {
    # Machine-compared text: no surrounding whitespace, so values cannot drift.
    param($Value, [string]$Field, [string]$Kind)
    $text = Assert-ReuseText $Value $Field $Kind
    if ($text -cne $text.Trim()) { Stop-ReuseError $Kind "'$Field' must not have leading or trailing whitespace" }
    return $text
}

function Assert-ReuseId {
    param($Value, [string]$Field, [string]$Kind)
    $text = Assert-ReuseToken $Value $Field $Kind
    if ($text -cnotmatch $script:ReuseIdPattern) {
        Stop-ReuseError $Kind "'$Field' must be an identifier matching $($script:ReuseIdPattern): '$text'"
    }
    return $text
}

function Assert-ReuseList {
    # Arrays must be arrays. A bare string or object is a malformed collection type and
    # is rejected instead of being coerced into a one-element list.
    param($Value, [string]$Field, [string]$Kind)
    if ($null -eq $Value) { Stop-ReuseError $Kind "'$Field' must be an array" }
    if ($Value -is [string] -or $Value -is [Collections.IDictionary]) {
        Stop-ReuseError $Kind "'$Field' must be an array, not $($Value.GetType().Name)"
    }
    if (-not ($Value -is [Collections.IList])) {
        Stop-ReuseError $Kind "'$Field' must be an array, not $($Value.GetType().Name)"
    }
    # The comma operator keeps empty and one element arrays intact.
    return , @($Value)
}

function Assert-ReuseTextList {
    param($Value, [string]$Field, [string]$Kind)
    $items = @()
    foreach ($item in (Assert-ReuseList $Value $Field $Kind)) {
        $items += Assert-ReuseText $item $Field $Kind
    }
    return , $items
}

function Assert-ReuseObjectList {
    param($Value, [string]$Field, [string]$Kind)
    $items = @()
    foreach ($item in (Assert-ReuseList $Value $Field $Kind)) {
        $items += (ConvertTo-ReuseDocument $item $Kind)
    }
    return , $items
}

function Assert-ReuseIdList {
    # Ids are unique, case sensitive and never empty. Order is preserved.
    param($Value, [string]$Field, [string]$Kind)
    $ids = @()
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($item in (Assert-ReuseList $Value $Field $Kind)) {
        $id = Assert-ReuseId $item $Field $Kind
        if (-not $seen.Add($id)) { Stop-ReuseError $Kind "'$Field' contains the duplicate identifier '$id'" }
        $ids += $id
    }
    return , $ids
}

function Assert-ReuseEnum {
    param($Value, [string]$Field, [string]$Kind, [string[]]$Allowed)
    $text = Assert-ReuseToken $Value $Field $Kind
    if ($text -cnotin $Allowed) { Stop-ReuseError $Kind "'$Field' must be one of: $($Allowed -join ', '); got '$text'" }
    return $text
}

function Assert-ReuseLong {
    # JSON integers arrive as Int64 after normalization; anything else is a type error.
    param($Value, [string]$Field, [string]$Kind, [long]$Expected)
    if (-not ($Value -is [long]) -or $Value -ne $Expected) {
        Stop-ReuseError $Kind "'$Field' must be the integer $Expected"
    }
    return [long]$Value
}

function Test-ReuseSchema {
    # Structural backstop for types, enums and unknown fields. Field level messages come
    # from the explicit checks; this keeps the frozen schema load bearing.
    param($Document, [string]$Kind)
    $schemaPath = Join-Path $script:ReuseProtocolRoot $script:ReuseSchemaFile
    if (-not (Test-Path -LiteralPath $schemaPath -PathType Leaf)) {
        Stop-ReuseError 'protocol_incomplete' "the protocol schema is missing: $schemaPath"
    }
    $json = ConvertTo-Json -InputObject $Document -Depth 100 -Compress
    $valid = $false
    try { $valid = Test-Json -Json $json -SchemaFile $schemaPath -ErrorAction Stop }
    catch { Stop-ReuseError $Kind "the document does not match $($script:ReuseSchemaFile): $($_.Exception.Message)" }
    if (-not $valid) { Stop-ReuseError $Kind "the document does not match $($script:ReuseSchemaFile)" }
}

function Assert-ReuseSearch {
    param($Search)
    $kind = 'invalid_decision'
    $document = ConvertTo-ReuseDocument $Search $kind
    $source = Assert-ReuseEnum (Get-ReuseRequiredField $document 'source' $kind) 'searches[].source' $kind $script:ReuseSearchSources
    $null = Assert-ReuseText (Get-ReuseRequiredField $document 'query' $kind) 'searches[].query' $kind
    $outcome = Assert-ReuseEnum (Get-ReuseRequiredField $document 'outcome' $kind) 'searches[].outcome' $kind $script:ReuseSearchOutcomes
    $null = Assert-ReuseText (Get-ReuseRequiredField $document 'summary' $kind) 'searches[].summary' $kind
    $evidence = Assert-ReuseTextList (Get-ReuseRequiredField $document 'evidence' $kind) 'searches[].evidence' $kind
    # A search that returned hits must cite what it found. A failed (unavailable) search
    # must cite the receipt that proves the failure. A genuine zero-result search answered
    # successfully: it may cite its receipt, but it is never required to produce a hit.
    if ($outcome -ceq 'results' -and $evidence.Count -eq 0) {
        Stop-ReuseError $kind "searches[] with outcome 'results' for source '$source' needs at least one evidence entry"
    }
    if ($outcome -ceq 'unavailable' -and $evidence.Count -eq 0) {
        Stop-ReuseError $kind "searches[] with outcome 'unavailable' for source '$source' needs a receipt reference in evidence"
    }
    return $document
}

function Assert-ReuseCandidate {
    param($Candidate)
    $kind = 'invalid_decision'
    $document = ConvertTo-ReuseDocument $Candidate $kind
    $id = Assert-ReuseId (Get-ReuseRequiredField $document 'id' $kind) 'candidates[].id' $kind
    $null = Assert-ReuseToken (Get-ReuseRequiredField $document 'url' $kind) 'candidates[].url' $kind
    $null = Assert-ReuseToken (Get-ReuseRequiredField $document 'revision' $kind) 'candidates[].revision' $kind
    $decision = Assert-ReuseEnum (Get-ReuseRequiredField $document 'decision' $kind) 'candidates[].decision' $kind $script:ReuseCandidateDecisions
    $null = Assert-ReuseText (Get-ReuseRequiredField $document 'rationale' $kind) 'candidates[].rationale' $kind
    $borrow = Get-ReuseRequiredField $document 'borrow' $kind
    if ($null -eq $borrow) { Stop-ReuseError $kind "'candidates[].borrow' must be a string, not null" }
    if (-not ($borrow -is [string])) { Stop-ReuseError $kind "'candidates[].borrow' must be a string, not $($borrow.GetType().Name)" }
    if ($borrow -cne $borrow.Trim()) {
        Stop-ReuseError $kind "'candidates[].borrow' must not have leading or trailing whitespace"
    }
    # A rejected candidate borrows nothing; every candidate kept for use must state what
    # is borrowed from it.
    if ($decision -cne 'reject' -and -not $borrow.Trim()) {
        Stop-ReuseError $kind "'candidates[].borrow' must state what is borrowed from '$id'"
    }
    $null = Assert-ReuseTextList (Get-ReuseRequiredField $document 'constraints' $kind) 'candidates[].constraints' $kind
    return $document
}

function Get-ReuseDecisionDocument {
    # Internal: validates a plan level reuse decision and returns its normalized form.
    param($Decision)
    $kind = 'invalid_decision'
    $document = ConvertTo-ReuseDocument $Decision $kind
    foreach ($name in @('version', 'applicability', 'status', 'reason', 'searches', 'candidates', 'strategy', 'rationale', 'constraints')) {
        $null = Get-ReuseRequiredField $document $name $kind
    }
    $version = Assert-ReuseLong (Get-ReuseRequiredField $document 'version' $kind) 'version' $kind $script:ReuseVersion
    $applicability = Assert-ReuseEnum $document['applicability'] 'applicability' $kind @('required', 'skipped')
    $status = Assert-ReuseEnum $document['status'] 'status' $kind @('completed', 'blocked', 'skipped')
    $null = Assert-ReuseText $document['reason'] 'reason' $kind
    $strategy = Assert-ReuseEnum $document['strategy'] 'strategy' $kind $script:ReuseStrategies
    $null = Assert-ReuseText $document['rationale'] 'rationale' $kind
    $null = Assert-ReuseTextList $document['constraints'] 'constraints' $kind

    $searches = @()
    foreach ($search in (Assert-ReuseObjectList $document['searches'] 'searches' $kind)) {
        $searches += (Assert-ReuseSearch $search)
    }
    $candidates = @()
    $candidateIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($candidate in (Assert-ReuseObjectList $document['candidates'] 'candidates' $kind)) {
        $validated = Assert-ReuseCandidate $candidate
        if (-not $candidateIds.Add([string]$validated['id'])) {
            Stop-ReuseError $kind "candidate ids must be unique; '$($validated['id'])' appears more than once"
        }
        $candidates += $validated
    }
    $null = Test-ReuseSchema $document $kind

    $unavailable = @($searches | Where-Object { $_.outcome -ceq 'unavailable' })
    if ($applicability -ceq 'skipped') {
        if ($status -cne 'skipped') { Stop-ReuseError $kind "a skipped decision must have status 'skipped', not '$status'" }
        if ($searches.Count -gt 0) { Stop-ReuseError $kind 'a skipped decision must not record searches' }
        if ($candidates.Count -gt 0) { Stop-ReuseError $kind 'a skipped decision must not record candidates' }
    } else {
        if ($status -ceq 'skipped') { Stop-ReuseError $kind "a required decision must have status 'completed' or 'blocked', not 'skipped'" }
        # An unavailable search is a network-side failure: it pauses the decision instead
        # of being absorbed into a completed one.
        if ($unavailable.Count -gt 0 -and $status -cne 'blocked') {
            Stop-ReuseError $kind "an unavailable search must block the decision; status is '$status'"
        }
        if ($status -ceq 'blocked' -and $unavailable.Count -eq 0) {
            Stop-ReuseError $kind "a blocked decision needs at least one search whose outcome is 'unavailable'"
        }
        if ($status -ceq 'completed') {
            # Every mandatory channel must have answered. An answer of 'no_results' counts:
            # a zero-result prior-art pass is a legitimate completed decision, so the check
            # is on the outcome being successful, never on a positive result count.
            foreach ($source in $script:ReuseCompletionSources) {
                $hits = @($searches | Where-Object { $_.source -ceq $source -and $_.outcome -cin $script:ReuseSuccessfulOutcomes })
                if ($hits.Count -eq 0) {
                    Stop-ReuseError $kind "a completed required decision needs a successful '$source' search (outcome 'results' or 'no_results')"
                }
            }
        }
        if ($strategy -cne 'build') {
            $chosen = @($candidates | Where-Object { $_.decision -ceq $strategy })
            if ($chosen.Count -eq 0) {
                Stop-ReuseError $kind "strategy '$strategy' needs at least one candidate whose decision is '$strategy'"
            }
        }
    }
    return $document
}

function Get-ReuseTaskDocument {
    # Internal: validates a task level reuse declaration against its decision.
    param($DecisionDocument, $TaskReuse)
    $kind = 'invalid_task'
    $document = ConvertTo-ReuseDocument $TaskReuse $kind
    foreach ($name in @('applicability', 'reason', 'change_kinds', 'refs')) {
        $null = Get-ReuseRequiredField $document $name $kind
    }
    $applicability = Assert-ReuseEnum $document['applicability'] 'applicability' $kind @('required', 'skipped')
    $null = Assert-ReuseText $document['reason'] 'reason' $kind
    $changeKinds = @()
    $kindSeen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($item in (Assert-ReuseList $document['change_kinds'] 'change_kinds' $kind)) {
        $value = Assert-ReuseEnum $item 'change_kinds[]' $kind $script:ReuseChangeKinds
        if (-not $kindSeen.Add($value)) { Stop-ReuseError $kind "'change_kinds' contains the duplicate value '$value'" }
        $changeKinds += $value
    }
    if ($changeKinds.Count -eq 0) { Stop-ReuseError $kind "'change_kinds' must list at least one change kind" }
    $refs = Assert-ReuseIdList $document['refs'] 'refs' $kind

    if ($document.ContainsKey('skip_reason')) {
        if ($applicability -cne 'skipped') { Stop-ReuseError $kind "'skip_reason' is only allowed when applicability is 'skipped'" }
        # skip_reason names the skip category and stays inside the four permitted values;
        # the free-form explanation belongs to 'reason'.
        $null = Assert-ReuseEnum $document['skip_reason'] 'skip_reason' $kind $script:ReuseSkipReasons
    } elseif ($applicability -ceq 'skipped') {
        Stop-ReuseError $kind "a skipped task needs an explicit 'skip_reason'"
    }

    if ($applicability -ceq 'skipped') {
        $priorArt = @($changeKinds | Where-Object { $_ -cin $script:ReusePriorArtKinds })
        if ($priorArt.Count -gt 0) {
            Stop-ReuseError $kind "change kind(s) $($priorArt -join ', ') create new capability and can never be skipped"
        }
    }
    if ($DecisionDocument['applicability'] -ceq 'skipped' -and $applicability -ceq 'required') {
        Stop-ReuseError $kind 'a skipped decision cannot cover a task that requires reuse'
    }

    $byId = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
    foreach ($candidate in @($DecisionDocument['candidates'])) { $byId[[string]$candidate['id']] = $candidate }
    foreach ($ref in $refs) {
        if (-not $byId.ContainsKey($ref)) {
            Stop-ReuseError $kind "ref '$ref' does not exist in the decision candidates"
        }
        if ([string]$byId[$ref]['decision'] -ceq 'reject') {
            Stop-ReuseError $kind "ref '$ref' points at a rejected candidate and cannot be prescribed for reuse"
        }
    }

    # A dependency is only admitted on the strength of a completed registry pass. A blocked
    # decision stays admissible here so that it can reach the Team pause and owner exception
    # path; rejecting it would turn a network pause into a task error. A registry pass that
    # answered with no publishable match ('no_results') is a completed pass.
    if ($changeKinds -ccontains 'new_dependency' -and $DecisionDocument['status'] -ceq 'completed') {
        $registry = @($DecisionDocument['searches'] | Where-Object {
                $_.source -ceq 'package_registry' -and $_.outcome -cin $script:ReuseSuccessfulOutcomes
            })
        if ($registry.Count -eq 0) {
            Stop-ReuseError $kind "a task with change kind 'new_dependency' needs a successful 'package_registry' search once the decision is completed (outcome 'results' or 'no_results')"
        }
    }
    $null = Test-ReuseSchema $document $kind
    return $document
}

function Get-ReuseResultDocument {
    # Internal: validates a result level reuse declaration against a context.
    param($ContextDocument, $ResultReuse)
    $kind = 'invalid_result'
    $document = ConvertTo-ReuseDocument $ResultReuse $kind
    $referencesUsed = Assert-ReuseIdList (Get-ReuseRequiredField $document 'references_used' $kind) 'references_used' $kind
    $deviations = @()
    $deviationRefs = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($deviation in (Assert-ReuseObjectList (Get-ReuseRequiredField $document 'deviations' $kind) 'deviations' $kind)) {
        $reference = Assert-ReuseId (Get-ReuseRequiredField $deviation 'reference' $kind) 'deviations[].reference' $kind
        $null = Assert-ReuseText (Get-ReuseRequiredField $deviation 'reason' $kind) 'deviations[].reason' $kind
        if (-not $deviationRefs.Add($reference)) {
            Stop-ReuseError $kind "'deviations' contains the duplicate reference '$reference'"
        }
        $deviations += $deviation
    }
    $null = Test-ReuseSchema $document $kind

    $prescribed = @($ContextDocument['task']['refs'])
    $known = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($candidate in @($ContextDocument['candidates'])) { $null = $known.Add([string]$candidate['id']) }
    foreach ($used in $referencesUsed) {
        if (-not $known.Contains($used)) {
            Stop-ReuseError $kind "reference '$used' is not prescribed by this task (unknown or out-of-task reference)"
        }
    }
    foreach ($deviation in $deviations) {
        $reference = [string]$deviation['reference']
        if (-not $known.Contains($reference)) {
            Stop-ReuseError $kind "deviation reference '$reference' is not prescribed by this task (unknown or out-of-task reference)"
        }
    }
    # A prescribed reference that was not used must be explained; an unexplained omission
    # is treated as a silent contract break.
    foreach ($ref in $prescribed) {
        if ($referencesUsed -ccontains [string]$ref) { continue }
        if (-not $deviationRefs.Contains([string]$ref)) {
            Stop-ReuseError $kind "prescribed reference '$ref' was not used and has no deviation explanation"
        }
    }
    return $document
}

function Assert-ReuseDecision {
    <#
    .SYNOPSIS
    Validates a plan level reuse decision and returns its normalized hashtable form.
    #>
    param($Decision)
    if ($null -eq $Decision) { Stop-ReuseError 'invalid_argument' '-Decision is required' }
    return Get-ReuseDecisionDocument $Decision
}

function Assert-ReuseTask {
    <#
    .SYNOPSIS
    Validates a task level reuse declaration against its decision.
    #>
    param($Decision, $TaskReuse)
    if ($null -eq $Decision) { Stop-ReuseError 'invalid_argument' '-Decision is required' }
    if ($null -eq $TaskReuse) { Stop-ReuseError 'invalid_argument' '-TaskReuse is required' }
    $decisionDocument = Get-ReuseDecisionDocument $Decision
    return Get-ReuseTaskDocument $decisionDocument $TaskReuse
}

function Get-ReuseContext {
    <#
    .SYNOPSIS
    Builds the bounded reuse context handed to a worker: protocol identity, plan hash,
    task applicability, the chosen strategy, decision constraints and only the candidate
    summaries the task references. Search logs and decision prose are never included.
    #>
    param($Decision, $TaskReuse, $PlanHash)
    if ($null -eq $Decision) { Stop-ReuseError 'invalid_argument' '-Decision is required' }
    if ($null -eq $TaskReuse) { Stop-ReuseError 'invalid_argument' '-TaskReuse is required' }
    $planHashValue = Assert-ReuseToken $PlanHash 'PlanHash' 'invalid_argument'
    $decisionDocument = Get-ReuseDecisionDocument $Decision
    $taskDocument = Get-ReuseTaskDocument $decisionDocument $TaskReuse

    $candidates = @()
    foreach ($ref in @($taskDocument['refs'])) {
        foreach ($candidate in @($decisionDocument['candidates'])) {
            if ([string]$candidate['id'] -cne [string]$ref) { continue }
            $candidates += @{
                id = [string]$candidate['id']
                url = [string]$candidate['url']
                revision = [string]$candidate['revision']
                decision = [string]$candidate['decision']
                rationale = [string]$candidate['rationale']
                borrow = [string]$candidate['borrow']
                constraints = @($candidate['constraints'])
            }
            break
        }
    }
    $task = @{
        applicability = [string]$taskDocument['applicability']
        reason = [string]$taskDocument['reason']
        change_kinds = @($taskDocument['change_kinds'])
        refs = @($taskDocument['refs'])
    }
    if ($taskDocument.ContainsKey('skip_reason')) { $task['skip_reason'] = [string]$taskDocument['skip_reason'] }
    return @{
        version = $script:ReuseVersion
        identity = Get-ReuseProtocolIdentity
        plan_hash = $planHashValue
        decision = @{
            applicability = [string]$decisionDocument['applicability']
            status = [string]$decisionDocument['status']
            strategy = [string]$decisionDocument['strategy']
            constraints = @($decisionDocument['constraints'])
        }
        task = $task
        candidates = $candidates
    }
}

function Assert-ReuseResult {
    <#
    .SYNOPSIS
    Validates what a task actually reused. Unknown and out-of-task references are
    rejected, and every prescribed reference left unused needs a deviation reason.
    Deviation text is a declaration: it grants no approval and changes no permission.
    #>
    param($Context, $ResultReuse)
    if ($null -eq $Context) { Stop-ReuseError 'invalid_argument' '-Context is required' }
    if ($null -eq $ResultReuse) { Stop-ReuseError 'invalid_argument' '-ResultReuse is required' }
    $contextDocument = ConvertTo-ReuseDocument $Context 'invalid_context'
    foreach ($name in @('version', 'identity', 'plan_hash', 'decision', 'task', 'candidates')) {
        $null = Get-ReuseRequiredField $contextDocument $name 'invalid_context'
    }
    $null = Assert-ReuseLong $contextDocument['version'] 'version' 'invalid_context' $script:ReuseVersion
    $identity = ConvertTo-ReuseDocument $contextDocument['identity'] 'invalid_context'
    $null = Assert-ReuseLong (Get-ReuseRequiredField $identity 'version' 'invalid_context') 'identity.version' 'invalid_context' $script:ReuseVersion
    $null = Assert-ReuseToken (Get-ReuseRequiredField $identity 'hash' 'invalid_context') 'identity.hash' 'invalid_context'
    $identityFiles = ConvertTo-ReuseDocument (Get-ReuseRequiredField $identity 'files' 'invalid_context') 'invalid_context'
    foreach ($name in @('readme', 'schema', 'validator')) {
        $null = Get-ReuseRequiredField $identityFiles $name 'invalid_context'
    }
    $null = Assert-ReuseToken $contextDocument['plan_hash'] 'context.plan_hash' 'invalid_context'
    $decisionPart = ConvertTo-ReuseDocument $contextDocument['decision'] 'invalid_context'
    foreach ($name in @('applicability', 'status', 'strategy', 'constraints')) {
        $null = Get-ReuseRequiredField $decisionPart $name 'invalid_context'
    }
    $taskPart = ConvertTo-ReuseDocument $contextDocument['task'] 'invalid_context'
    foreach ($name in @('applicability', 'reason', 'change_kinds', 'refs')) {
        $null = Get-ReuseRequiredField $taskPart $name 'invalid_context'
    }
    $prescribed = Assert-ReuseIdList $taskPart['refs'] 'context.task.refs' 'invalid_context'
    $summaryIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($summary in (Assert-ReuseObjectList $contextDocument['candidates'] 'context.candidates' 'invalid_context')) {
        $summaryId = Assert-ReuseId (Get-ReuseRequiredField $summary 'id' 'invalid_context') 'context.candidates[].id' 'invalid_context'
        if (-not $summaryIds.Add($summaryId)) {
            Stop-ReuseError 'invalid_context' "'context.candidates' contains the duplicate identifier '$summaryId'"
        }
    }
    if ($summaryIds.Count -ne $prescribed.Count) {
        Stop-ReuseError 'invalid_context' 'context.candidates must contain exactly the candidates prescribed by the task'
    }
    foreach ($ref in $prescribed) {
        if (-not $summaryIds.Contains([string]$ref)) {
            Stop-ReuseError 'invalid_context' "context.candidates is missing the prescribed reference '$ref'"
        }
    }
    return Get-ReuseResultDocument $contextDocument $ResultReuse
}

function Get-ReuseProtocolIdentity {
    <#
    .SYNOPSIS
    Returns version 1 plus a deterministic content hash of the protocol README, schema
    and validator. The same three files are the evidence a run freezes and copies.
    #>
    param([string]$Root)
    $protocolRoot = if ($Root) { $Root } else { $script:ReuseProtocolRoot }
    if (-not (Test-Path -LiteralPath $protocolRoot -PathType Container)) {
        Stop-ReuseError 'protocol_incomplete' "the protocol directory is missing: $protocolRoot"
    }
    $specs = @(
        @{ key = 'readme'; name = $script:ReuseReadmeFile },
        @{ key = 'schema'; name = $script:ReuseSchemaFile },
        @{ key = 'validator'; name = $script:ReuseValidatorFile }
    )
    $files = @{}
    foreach ($spec in $specs) {
        $path = Join-Path $protocolRoot $spec.name
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            Stop-ReuseError 'protocol_incomplete' "the protocol file is missing: $($spec.name)"
        }
        $item = Get-Item -LiteralPath $path
        $files[$spec.key] = @{
            name = [string]$spec.name
            sha256 = Get-ReuseFileHash $path
            bytes = [long]$item.Length
        }
    }
    return @{
        version = $script:ReuseVersion
        hash = Get-ReuseTextHash (Get-ReuseCanonicalJson @{ version = $script:ReuseVersion; files = $files })
        files = $files
    }
}
