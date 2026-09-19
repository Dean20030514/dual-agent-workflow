# Contract tests for the canonical Reuse-first protocol in core/reuse.
# Fixtures are in-memory only: no network, no child process, no write outside $TestDrive.
BeforeAll {
    $script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $script:ProtocolRoot = Join-Path $script:RepoRoot 'core/reuse'
    . (Join-Path $script:ProtocolRoot 'Reuse.ps1')
    $script:PlanHash = 'a' * 64

    function Invoke-ReuseExpectingFailure([scriptblock]$Action) {
        try { $null = & $Action } catch { return $_ }
        return $null
    }

    function Assert-ReuseFailure([scriptblock]$Action, [string]$Kind) {
        $failure = Invoke-ReuseExpectingFailure $Action
        $failure | Should -Not -BeNullOrEmpty
        if ($null -eq $failure) { return }
        $failure.Exception.Data['ReuseProtocolError'] | Should -BeTrue
        $failure.Exception.Data['ReuseErrorKind'] | Should -Be $Kind
        $failure.Exception.Message | Should -Match '^reuse/'
        # Core errors stay independent of the Team exit-code contract.
        $failure.Exception.Data.Contains('TeamExitCode') | Should -BeFalse
    }

    function New-ValidSearch([string]$Source = 'github_repositories', [string]$Outcome = 'results') {
        $evidence = @()
        if ($Outcome -ceq 'results') { $evidence = @("https://example.org/$Source") }
        # An unavailable search is a failure and must cite the receipt that proves it.
        if ($Outcome -ceq 'unavailable') { $evidence = @("receipt: $Source-20260919T101500Z") }
        return @{
            source = $Source
            query = "prior art for $Source"
            outcome = $Outcome
            summary = "summary for $Source"
            evidence = $evidence
        }
    }

    function New-ValidCandidate([string]$Id = 'prior-art', [string]$Decision = 'reference') {
        $borrow = 'the single source idea'
        if ($Decision -ceq 'reject') { $borrow = '' }
        return @{
            id = $Id
            url = "https://github.com/example/$Id"
            revision = '0123456789abcdef0123456789abcdef01234567'
            decision = $Decision
            rationale = "rationale for $Id"
            borrow = $borrow
            constraints = @("constraint for $Id")
        }
    }

    function New-ValidDecision {
        return @{
            version = 1
            applicability = 'required'
            status = 'completed'
            reason = 'The plan adds a new protocol surface.'
            searches = @(
                (New-ValidSearch 'github_repositories' 'results'),
                (New-ValidSearch 'github_code' 'results'),
                (New-ValidSearch 'primary_docs' 'results')
            )
            candidates = @(
                (New-ValidCandidate 'prior-art' 'reference'),
                (New-ValidCandidate 'rejected-lib' 'reject')
            )
            strategy = 'reference'
            rationale = 'Borrow the idea only and implement the validator here.'
            constraints = @('No new dependency.')
        }
    }

    function New-SkippedDecision {
        return @{
            version = 1
            applicability = 'skipped'
            status = 'skipped'
            reason = 'Documentation only.'
            searches = @()
            candidates = @()
            strategy = 'build'
            rationale = 'No prior-art question to answer.'
            constraints = @()
        }
    }

    function New-BlockedDecision {
        # A required decision paused by a network failure: the unavailable registry search
        # carries the receipt that proves the failure.
        return @{
            version = 1
            applicability = 'required'
            status = 'blocked'
            reason = 'The package registry could not be queried, so the prior-art pass cannot complete.'
            searches = @(
                (New-ValidSearch 'github_repositories' 'results'),
                (New-ValidSearch 'github_code' 'results'),
                (New-ValidSearch 'primary_docs' 'no_results'),
                (New-ValidSearch 'package_registry' 'unavailable')
            )
            candidates = @()
            strategy = 'build'
            rationale = 'No candidate can be chosen until the unavailable registry search is repeated.'
            constraints = @('Pause before creating any worker worktree.')
        }
    }

    function New-ValidTask {
        return @{
            applicability = 'required'
            reason = 'Implements the shared validator.'
            change_kinds = @('new_implementation')
            refs = @('prior-art')
        }
    }

    function New-SkippedTask {
        return @{
            applicability = 'skipped'
            reason = 'Rewrites existing wording only.'
            change_kinds = @('docs_only')
            refs = @()
            skip_reason = 'docs_only'
        }
    }

    function New-ValidResult {
        return @{ references_used = @('prior-art'); deviations = @() }
    }

    function Get-ProtocolExample([string]$Kind) {
        $path = Join-Path $script:ProtocolRoot 'README.md'
        $text = [IO.File]::ReadAllText($path)
        $pattern = '(?ms)^```json ' + [regex]::Escape($Kind) + '\s*\r?\n(.*?)^```'
        $blocks = @()
        foreach ($match in [regex]::Matches($text, $pattern)) { $blocks += $match.Groups[1].Value }
        # Callers wrap the result in @(): return the blocks unrolled so that zero, one
        # and many blocks all arrive as a flat array.
        return $blocks
    }

    function ConvertFrom-Example([string]$Json) {
        return ConvertFrom-Json -InputObject $Json -AsHashtable -Depth 100
    }

    function New-ProtocolCopy([string]$Name) {
        $target = Join-Path $TestDrive $Name
        [IO.Directory]::CreateDirectory($target) | Out-Null
        foreach ($file in @('README.md', 'reuse.schema.json', 'Reuse.ps1')) {
            [IO.File]::Copy((Join-Path $script:ProtocolRoot $file), (Join-Path $target $file), $true)
        }
        return $target
    }
}

Describe 'Reuse protocol identity' {
    It 'reports version 1 with a deterministic hash over the three protocol files' {
        $identity = Get-ReuseProtocolIdentity
        $identity.version | Should -Be 1
        $identity.hash | Should -Match '^[a-f0-9]{64}$'
        @('readme', 'schema', 'validator') | ForEach-Object { $identity.files.ContainsKey($_) | Should -BeTrue }
        foreach ($key in @('readme', 'schema', 'validator')) {
            $file = Join-Path $script:ProtocolRoot $identity.files[$key].name
            $identity.files[$key].sha256 | Should -Be (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()
            $identity.files[$key].bytes | Should -Be (Get-Item -LiteralPath $file).Length
        }
        (Get-ReuseProtocolIdentity).hash | Should -Be $identity.hash
    }

    It 'changes the identity when <File> changes' -ForEach @(
        @{ File = 'README.md' }, @{ File = 'reuse.schema.json' }, @{ File = 'Reuse.ps1' }
    ) {
        $copy = New-ProtocolCopy ("copy-" + [guid]::NewGuid().ToString('N'))
        $before = (Get-ReuseProtocolIdentity -Root $copy).hash
        [IO.File]::AppendAllText((Join-Path $copy $File), "`n")
        (Get-ReuseProtocolIdentity -Root $copy).hash | Should -Not -Be $before
    }

    It 'fails when a protocol file is missing' {
        $copy = New-ProtocolCopy ("partial-" + [guid]::NewGuid().ToString('N'))
        [IO.File]::Delete((Join-Path $copy 'README.md'))
        Assert-ReuseFailure { Get-ReuseProtocolIdentity -Root $copy } 'protocol_incomplete'
    }

    It 'fails when the protocol directory does not exist' {
        Assert-ReuseFailure { Get-ReuseProtocolIdentity -Root (Join-Path $TestDrive 'missing') } 'protocol_incomplete'
    }
}

Describe 'Reuse decision validation' {
    It 'accepts a complete required decision and returns a normalized object' {
        $validated = Assert-ReuseDecision -Decision (New-ValidDecision)
        $validated | Should -BeOfType [hashtable]
        $validated.status | Should -Be 'completed'
        @($validated.searches).Count | Should -Be 3
        @($validated.candidates).Count | Should -Be 2
    }

    It 'accepts a decision given as a JSON object' {
        $document = ConvertFrom-Example (ConvertTo-Json (New-ValidDecision) -Depth 100)
        (Assert-ReuseDecision -Decision $document).strategy | Should -Be 'reference'
    }

    It 'rejects a document that is not an object' {
        Assert-ReuseFailure { Assert-ReuseDecision -Decision 'not-a-document' } 'invalid_decision'
        Assert-ReuseFailure { Assert-ReuseDecision -Decision @() } 'invalid_decision'
    }

    It 'reports a missing -Decision argument as an argument error' {
        Assert-ReuseFailure { Assert-ReuseDecision } 'invalid_argument'
    }

    It 'rejects a missing <Field> field' -ForEach @(
        @{ Field = 'version' }, @{ Field = 'applicability' }, @{ Field = 'status' }, @{ Field = 'reason' },
        @{ Field = 'searches' }, @{ Field = 'candidates' }, @{ Field = 'strategy' }, @{ Field = 'rationale' },
        @{ Field = 'constraints' }
    ) {
        $document = New-ValidDecision
        $document.ContainsKey($Field) | Should -BeTrue
        $document.Remove($Field)
        Assert-ReuseFailure { Assert-ReuseDecision -Decision $document } 'invalid_decision'
    }

    It 'rejects a version other than the integer 1' {
        $document = New-ValidDecision
        $document.version = 2
        Assert-ReuseFailure { Assert-ReuseDecision -Decision $document } 'invalid_decision'
        $document = New-ValidDecision
        $document.version = '1'
        Assert-ReuseFailure { Assert-ReuseDecision -Decision $document } 'invalid_decision'
    }

    It 'rejects unknown properties instead of ignoring them' {
        $document = New-ValidDecision
        $document['extra'] = 'typo'
        Assert-ReuseFailure { Assert-ReuseDecision -Decision $document } 'invalid_decision'
    }

    It 'rejects whitespace-only <Field> text' -ForEach @(
        @{ Field = 'reason' }, @{ Field = 'rationale' }
    ) {
        $document = New-ValidDecision
        $document[$Field] = "   "
        Assert-ReuseFailure { Assert-ReuseDecision -Decision $document } 'invalid_decision'
    }

    It 'rejects whitespace-only search text and blank constraints' {
        $document = New-ValidDecision
        $document.searches[0].query = "`t "
        Assert-ReuseFailure { Assert-ReuseDecision -Decision $document } 'invalid_decision'
        $document = New-ValidDecision
        $document.searches[0].summary = ' '
        Assert-ReuseFailure { Assert-ReuseDecision -Decision $document } 'invalid_decision'
        $document = New-ValidDecision
        $document.constraints = @('ok', '  ')
        Assert-ReuseFailure { Assert-ReuseDecision -Decision $document } 'invalid_decision'
    }

    It 'rejects malformed collection types instead of coercing them' {
        $document = New-ValidDecision
        $document.searches = 'github_repositories'
        Assert-ReuseFailure { Assert-ReuseDecision -Decision $document } 'invalid_decision'
        $document = New-ValidDecision
        $document.candidates = @{ id = 'prior-art' }
        Assert-ReuseFailure { Assert-ReuseDecision -Decision $document } 'invalid_decision'
        $document = New-ValidDecision
        $document.constraints = 'No new dependency.'
        Assert-ReuseFailure { Assert-ReuseDecision -Decision $document } 'invalid_decision'
        $document = New-ValidDecision
        $document.searches[0].evidence = 'https://github.com/example/prior-art'
        Assert-ReuseFailure { Assert-ReuseDecision -Decision $document } 'invalid_decision'
    }

    It 'rejects unknown enum values' {
        $document = New-ValidDecision
        $document.strategy = 'copy-paste'
        Assert-ReuseFailure { Assert-ReuseDecision -Decision $document } 'invalid_decision'
        $document = New-ValidDecision
        $document.searches[0].source = 'web_search'
        Assert-ReuseFailure { Assert-ReuseDecision -Decision $document } 'invalid_decision'
        $document = New-ValidDecision
        $document.searches[0].outcome = 'maybe'
        Assert-ReuseFailure { Assert-ReuseDecision -Decision $document } 'invalid_decision'
        $document = New-ValidDecision
        $document.candidates[0].decision = 'maybe'
        Assert-ReuseFailure { Assert-ReuseDecision -Decision $document } 'invalid_decision'
    }

    It 'rejects duplicate candidate ids' {
        $document = New-ValidDecision
        $document.candidates += (New-ValidCandidate 'prior-art' 'adopt')
        Assert-ReuseFailure { Assert-ReuseDecision -Decision $document } 'invalid_decision' | Out-Null
    }

    It 'requires a successful <Source> search for a completed required decision' -ForEach @(
        @{ Source = 'github_repositories' }, @{ Source = 'github_code' }, @{ Source = 'primary_docs' }
    ) {
        $document = New-ValidDecision
        $document.searches = @($document.searches | Where-Object { $_.source -cne $Source })
        Assert-ReuseFailure { Assert-ReuseDecision -Decision $document } 'invalid_decision'
    }

    It 'accepts a genuine zero-result decision with no candidate to adopt' {
        $document = New-ValidDecision
        $document.candidates = @()
        $document.strategy = 'build'
        $document.rationale = 'No reusable implementation exists, so the smallest local shape is built.'
        (Assert-ReuseDecision -Decision $document).strategy | Should -Be 'build'
    }

    It 'counts a <Source> search answered with no_results as a successful mandatory channel' -ForEach @(
        @{ Source = 'github_repositories' }, @{ Source = 'github_code' }, @{ Source = 'primary_docs' }
    ) {
        $document = New-ValidDecision
        $document.searches = @($document.searches | Where-Object { $_.source -cne $Source })
        $document.searches += (New-ValidSearch $Source 'no_results')
        # The channel answered, even though it answered with nothing; the chosen candidate
        # is still reused, so this is not merely a "candidates are empty" case.
        $validated = Assert-ReuseDecision -Decision $document
        @($validated.searches | Where-Object { $_.source -ceq $Source })[0].outcome | Should -Be 'no_results'
        @($validated.candidates | Where-Object { $_.decision -ceq 'reference' }).Count | Should -Be 1
    }

    It 'accepts a completed required decision when every mandatory channel answers no_results' {
        $document = New-ValidDecision
        $document.searches = @(
            (New-ValidSearch 'github_repositories' 'no_results'),
            (New-ValidSearch 'github_code' 'no_results'),
            (New-ValidSearch 'primary_docs' 'no_results')
        )
        $document.candidates = @()
        $document.strategy = 'build'
        $document.rationale = 'No reusable implementation exists, so the smallest local shape is built.'
        $validated = Assert-ReuseDecision -Decision $document
        $validated.status | Should -Be 'completed'
        @($validated.searches | Where-Object { $_.outcome -ceq 'no_results' }).Count | Should -Be 3
        @($validated.candidates).Count | Should -Be 0
    }

    It 'lets a no_results search cite its receipt and never demands a positive result' {
        $document = New-ValidDecision
        $search = New-ValidSearch 'github_code' 'no_results'
        $search.evidence = @('receipt: search-github-code-20260919T101500Z')
        $document.searches = @($document.searches | Where-Object { $_.source -cne 'github_code' }) + @($search)
        $validated = Assert-ReuseDecision -Decision $document
        @($validated.searches | Where-Object { $_.source -ceq 'github_code' })[0].evidence.Count | Should -Be 1
        # A zero-result search with no citation at all stays valid as well.
        $document = New-ValidDecision
        $document.searches = @($document.searches | Where-Object { $_.source -cne 'github_code' }) + @((New-ValidSearch 'github_code' 'no_results'))
        (Assert-ReuseDecision -Decision $document).searches.Count | Should -Be 3
    }

    It 'requires a chosen candidate for a non-build strategy' {
        $document = New-ValidDecision
        $document.candidates = @((New-ValidCandidate 'rejected-lib' 'reject'))
        Assert-ReuseFailure { Assert-ReuseDecision -Decision $document } 'invalid_decision'
        $document = New-ValidDecision
        $document.candidates = @((New-ValidCandidate 'ported-lib' 'port'))
        Assert-ReuseFailure { Assert-ReuseDecision -Decision $document } 'invalid_decision'
    }

    It 'requires evidence for a successful search and allows none for a zero-result search' {
        $document = New-ValidDecision
        $document.searches[0].evidence = @()
        Assert-ReuseFailure { Assert-ReuseDecision -Decision $document } 'invalid_decision'
        $document = New-ValidDecision
        $document.searches += (New-ValidSearch 'package_registry' 'no_results')
        (Assert-ReuseDecision -Decision $document).searches.Count | Should -Be 4
    }

    It 'requires a non-blank borrow description except for rejected candidates' {
        $document = New-ValidDecision
        $document.candidates[0].borrow = '  '
        Assert-ReuseFailure { Assert-ReuseDecision -Decision $document } 'invalid_decision'
        $document = New-ValidDecision
        $document.candidates[1].borrow | Should -Be ''
        $null = Assert-ReuseDecision -Decision $document
    }
}

Describe 'Reuse skip and blocked semantics' {
    It 'accepts a skipped decision with no searches and no candidates' {
        $decision = Assert-ReuseDecision -Decision (New-SkippedDecision)
        $decision.status | Should -Be 'skipped'
        @($decision.searches).Count | Should -Be 0
        @($decision.candidates).Count | Should -Be 0
    }

    It 'requires a skipped decision to have skipped status' {
        $document = New-SkippedDecision
        $document.status = 'completed'
        Assert-ReuseFailure { Assert-ReuseDecision -Decision $document } 'invalid_decision'
    }

    It 'rejects a skipped decision that still records prior-art work' {
        $document = New-SkippedDecision
        $document.searches = @(New-ValidSearch 'github_code' 'results')
        Assert-ReuseFailure { Assert-ReuseDecision -Decision $document } 'invalid_decision'
        $document = New-SkippedDecision
        $document.candidates = @(New-ValidCandidate 'prior-art' 'reference')
        Assert-ReuseFailure { Assert-ReuseDecision -Decision $document } 'invalid_decision'
    }

    It 'rejects a required decision marked skipped' {
        $document = New-ValidDecision
        $document.status = 'skipped'
        Assert-ReuseFailure { Assert-ReuseDecision -Decision $document } 'invalid_decision'
    }

    It 'accepts a blocked decision backed by an unavailable search' {
        $document = New-ValidDecision
        $document.status = 'blocked'
        $document.searches = @(
            (New-ValidSearch 'github_repositories' 'results'),
            (New-ValidSearch 'github_code' 'unavailable'),
            (New-ValidSearch 'primary_docs' 'no_results')
        )
        $document.candidates = @()
        $document.strategy = 'build'
        (Assert-ReuseDecision -Decision $document).status | Should -Be 'blocked'
    }

    It 'rejects a blocked decision with no unavailable search' {
        $document = New-ValidDecision
        $document.status = 'blocked'
        Assert-ReuseFailure { Assert-ReuseDecision -Decision $document } 'invalid_decision'
    }

    It 'rejects a completed decision that hides an unavailable search' {
        $document = New-ValidDecision
        $document.searches = @(
            (New-ValidSearch 'github_repositories' 'results'),
            (New-ValidSearch 'github_code' 'unavailable'),
            (New-ValidSearch 'primary_docs' 'results')
        )
        Assert-ReuseFailure { Assert-ReuseDecision -Decision $document } 'invalid_decision'
    }

    It 'requires a receipt for an unavailable search' {
        $document = New-ValidDecision
        $document.status = 'blocked'
        $document.searches = @(
            (New-ValidSearch 'github_repositories' 'results'),
            @{ source = 'github_code'; query = 'q'; outcome = 'unavailable'; summary = 'refused'; evidence = @() }
        )
        $document.candidates = @()
        $document.strategy = 'build'
        Assert-ReuseFailure { Assert-ReuseDecision -Decision $document } 'invalid_decision'
    }
}

Describe 'Reuse task validation' {
    It 'accepts a required task that references an existing candidate' {
        $task = Assert-ReuseTask -Decision (New-ValidDecision) -TaskReuse (New-ValidTask)
        @($task.refs) | Should -Be @('prior-art')
    }

    It 'reports missing arguments as argument errors' {
        Assert-ReuseFailure { Assert-ReuseTask -Decision (New-ValidDecision) } 'invalid_argument'
        Assert-ReuseFailure { Assert-ReuseTask -TaskReuse (New-ValidTask) } 'invalid_argument'
    }

    It 'forces <Kind> to be required even when the task tries to skip it' -ForEach @(
        @{ Kind = 'new_implementation' }, @{ Kind = 'new_dependency' }, @{ Kind = 'architecture' }, @{ Kind = 'protocol' }
    ) {
        $decision = New-ValidDecision
        if ($Kind -ceq 'new_dependency') { $decision.searches += (New-ValidSearch 'package_registry' 'results') }
        $task = New-SkippedTask
        $task.change_kinds = @($Kind)
        Assert-ReuseFailure { Assert-ReuseTask -Decision $decision -TaskReuse $task } 'invalid_task'
    }

    It 'allows <Kind> to be skipped with an explicit reason' -ForEach @(
        @{ Kind = 'docs_only' }, @{ Kind = 'diagnosed_local_bug' }, @{ Kind = 'established_repo_pattern' }, @{ Kind = 'data_only' }
    ) {
        $decision = New-ValidDecision
        $task = New-SkippedTask
        $task.change_kinds = @($Kind)
        $task.skip_reason = $Kind
        (Assert-ReuseTask -Decision $decision -TaskReuse $task).applicability | Should -Be 'skipped'
    }

    It 'requires a non-blank skip_reason for a skipped task' {
        $task = New-SkippedTask
        $task.skip_reason = '   '
        Assert-ReuseFailure { Assert-ReuseTask -Decision (New-ValidDecision) -TaskReuse $task } 'invalid_task'
        $task = New-SkippedTask
        $task.ContainsKey('skip_reason') | Should -BeTrue
        $task.Remove('skip_reason')
        Assert-ReuseFailure { Assert-ReuseTask -Decision (New-ValidDecision) -TaskReuse $task } 'invalid_task'
    }

    It 'rejects arbitrary skip_reason text instead of treating it as free prose' {
        # The free-form explanation belongs to 'reason'; skip_reason only names the category.
        $task = New-SkippedTask
        $task.skip_reason = 'not needed'
        Assert-ReuseFailure { Assert-ReuseTask -Decision (New-ValidDecision) -TaskReuse $task } 'invalid_task'
        $task = New-SkippedTask
        $task.skip_reason = 'Pure documentation edit; no new capability.'
        Assert-ReuseFailure { Assert-ReuseTask -Decision (New-ValidDecision) -TaskReuse $task } 'invalid_task'
        $task = New-SkippedTask
        $task.skip_reason = 'DOCS_ONLY'
        Assert-ReuseFailure { Assert-ReuseTask -Decision (New-ValidDecision) -TaskReuse $task } 'invalid_task'
    }

    It 'rejects a skip_reason naming a new-capability change kind' -ForEach @(
        @{ Kind = 'new_implementation' }, @{ Kind = 'new_dependency' }, @{ Kind = 'architecture' }, @{ Kind = 'protocol' }
    ) {
        $task = New-SkippedTask
        $task.change_kinds = @('docs_only')
        $task.skip_reason = $Kind
        Assert-ReuseFailure { Assert-ReuseTask -Decision (New-ValidDecision) -TaskReuse $task } 'invalid_task'
    }

    It 'rejects skip_reason on a required task' {
        $task = New-ValidTask
        $task['skip_reason'] = 'not needed'
        Assert-ReuseFailure { Assert-ReuseTask -Decision (New-ValidDecision) -TaskReuse $task } 'invalid_task'
    }

    It 'rejects an empty or unknown change kind list' {
        $task = New-ValidTask
        $task.change_kinds = @()
        Assert-ReuseFailure { Assert-ReuseTask -Decision (New-ValidDecision) -TaskReuse $task } 'invalid_task'
        $task = New-ValidTask
        $task.change_kinds = @('performance')
        Assert-ReuseFailure { Assert-ReuseTask -Decision (New-ValidDecision) -TaskReuse $task } 'invalid_task'
        $task = New-ValidTask
        $task.change_kinds = @('docs_only', 'docs_only')
        Assert-ReuseFailure { Assert-ReuseTask -Decision (New-ValidDecision) -TaskReuse $task } 'invalid_task'
    }

    It 'rejects refs that are unknown, rejected or duplicated' {
        $task = New-ValidTask
        $task.refs = @('missing-candidate')
        Assert-ReuseFailure { Assert-ReuseTask -Decision (New-ValidDecision) -TaskReuse $task } 'invalid_task'
        $task = New-ValidTask
        $task.refs = @('rejected-lib')
        Assert-ReuseFailure { Assert-ReuseTask -Decision (New-ValidDecision) -TaskReuse $task } 'invalid_task'
        $task = New-ValidTask
        $task.refs = @('prior-art', 'prior-art')
        Assert-ReuseFailure { Assert-ReuseTask -Decision (New-ValidDecision) -TaskReuse $task } 'invalid_task'
    }

    It 'rejects a required task covered by a skipped decision' {
        $task = New-ValidTask
        $task.refs = @()
        Assert-ReuseFailure { Assert-ReuseTask -Decision (New-SkippedDecision) -TaskReuse $task } 'invalid_task'
    }

    It 'requires a successful package_registry search for a completed new_dependency decision' {
        $task = New-ValidTask
        $task.change_kinds = @('new_dependency')
        $task.refs = @('prior-art')
        # The decision completed without ever querying the registry: the task cannot pass.
        Assert-ReuseFailure { Assert-ReuseTask -Decision (New-ValidDecision) -TaskReuse $task } 'invalid_task'
        $decision = New-ValidDecision
        $decision.searches += (New-ValidSearch 'package_registry' 'results')
        (Assert-ReuseTask -Decision $decision -TaskReuse $task).applicability | Should -Be 'required'
    }

    It 'accepts a zero-result package_registry pass for a completed new_dependency task' {
        $task = New-ValidTask
        $task.change_kinds = @('new_dependency')
        $task.refs = @('prior-art')
        $decision = New-ValidDecision
        $decision.searches += (New-ValidSearch 'package_registry' 'no_results')
        (Assert-ReuseTask -Decision $decision -TaskReuse $task).applicability | Should -Be 'required'
    }

    It 'accepts a blocked decision for a new_dependency task so it reaches the owner exception path' {
        $task = New-ValidTask
        $task.change_kinds = @('new_dependency')
        $task.refs = @()
        $blocked = New-BlockedDecision
        # No completed registry pass exists here on purpose: the declaration is still valid
        # and must reach the Team pause instead of failing as a task error.
        (Assert-ReuseTask -Decision $blocked -TaskReuse $task).applicability | Should -Be 'required'
        # The same unavailable registry search cannot be laundered into a completed decision.
        $laundered = New-BlockedDecision
        $laundered.status = 'completed'
        Assert-ReuseFailure { Assert-ReuseTask -Decision $laundered -TaskReuse $task } 'invalid_decision'
    }

    It 'does not force a task to reference a candidate' {
        # Empty refs stay legitimate for a build strategy and for skipped tasks. A
        # non-build strategy with an unused prescription is caught by the deviation rule.
        $task = New-ValidTask
        $task.refs = @()
        (Assert-ReuseTask -Decision (New-ValidDecision) -TaskReuse $task).refs.Count | Should -Be 0
    }
}

Describe 'Reuse context derivation' {
    It 'carries identity, plan hash, task applicability and only the referenced candidates' {
        $decision = New-ValidDecision
        $decision.candidates += (New-ValidCandidate 'other-lib' 'wrap')
        $context = Get-ReuseContext -Decision $decision -TaskReuse (New-ValidTask) -PlanHash $script:PlanHash
        $context.version | Should -Be 1
        $context.plan_hash | Should -Be $script:PlanHash
        $context.identity.hash | Should -Be (Get-ReuseProtocolIdentity).hash
        $context.decision.strategy | Should -Be 'reference'
        $context.decision.constraints | Should -Be @('No new dependency.')
        $context.task.applicability | Should -Be 'required'
        @($context.task.change_kinds) | Should -Be @('new_implementation')
        @($context.candidates).Count | Should -Be 1
        @($context.candidates)[0].id | Should -Be 'prior-art'
        @($context.candidates)[0].keys.Count | Should -Be 7
        @($context.candidates)[0].constraints | Should -Be @('constraint for prior-art')
        # The bounded context never leaks full search logs or decision prose.
        $context.ContainsKey('searches') | Should -BeFalse
        $context.decision.ContainsKey('rationale') | Should -BeFalse
        $context.ContainsKey('reason') | Should -BeFalse
        @($context.Keys | Where-Object { $_ -eq 'rationale' }).Count | Should -Be 0
    }

    It 'keeps a skipped task context empty and explicit' {
        $context = Get-ReuseContext -Decision (New-ValidDecision) -TaskReuse (New-SkippedTask) -PlanHash $script:PlanHash
        $context.task.applicability | Should -Be 'skipped'
        $context.task.skip_reason | Should -Be 'docs_only'
        @($context.candidates).Count | Should -Be 0
    }

    It 'rejects a missing, blank or malformed plan hash' {
        $decision = New-ValidDecision
        Assert-ReuseFailure { Get-ReuseContext -Decision $decision -TaskReuse (New-ValidTask) } 'invalid_argument'
        Assert-ReuseFailure { Get-ReuseContext -Decision $decision -TaskReuse (New-ValidTask) -PlanHash '   ' } 'invalid_argument'
        Assert-ReuseFailure { Get-ReuseContext -Decision $decision -TaskReuse (New-ValidTask) -PlanHash ' abc ' } 'invalid_argument'
        Assert-ReuseFailure { Get-ReuseContext -Decision $decision -TaskReuse (New-ValidTask) -PlanHash @('a') } 'invalid_argument'
    }

    It 'rejects an invalid decision or task before building a context' {
        Assert-ReuseFailure { Get-ReuseContext -Decision (New-SkippedDecision) -TaskReuse (New-ValidTask) -PlanHash $script:PlanHash } 'invalid_task'
    }
}

Describe 'Reuse result validation' {
    It 'accepts a result that used every prescribed reference' {
        $context = Get-ReuseContext -Decision (New-ValidDecision) -TaskReuse (New-ValidTask) -PlanHash $script:PlanHash
        (Assert-ReuseResult -Context $context -ResultReuse (New-ValidResult)).references_used | Should -Be @('prior-art')
    }

    It 'requires a deviation explanation for a prescribed reference left unused' {
        $context = Get-ReuseContext -Decision (New-ValidDecision) -TaskReuse (New-ValidTask) -PlanHash $script:PlanHash
        $result = @{ references_used = @(); deviations = @() }
        Assert-ReuseFailure { Assert-ReuseResult -Context $context -ResultReuse $result } 'invalid_result'
        $result = @{
            references_used = @()
            deviations = @(@{ reference = 'prior-art'; reason = 'The revision was unreachable; the local shape was rebuilt.' })
        }
        (Assert-ReuseResult -Context $context -ResultReuse $result).deviations.Count | Should -Be 1
    }

    It 'rejects an unknown or out-of-task reference' {
        $decision = New-ValidDecision
        $decision.candidates += (New-ValidCandidate 'other-lib' 'wrap')
        $context = Get-ReuseContext -Decision $decision -TaskReuse (New-ValidTask) -PlanHash $script:PlanHash
        $result = @{ references_used = @('other-lib'); deviations = @() }
        Assert-ReuseFailure { Assert-ReuseResult -Context $context -ResultReuse $result } 'invalid_result'
        $result = @{ references_used = @('never-seen'); deviations = @() }
        Assert-ReuseFailure { Assert-ReuseResult -Context $context -ResultReuse $result } 'invalid_result'
        $result = @{ references_used = @(); deviations = @(@{ reference = 'other-lib'; reason = 'why not' }) }
        Assert-ReuseFailure { Assert-ReuseResult -Context $context -ResultReuse $result } 'invalid_result'
    }

    It 'accepts empty references for a skipped task and for a build strategy' {
        $skippedContext = Get-ReuseContext -Decision (New-ValidDecision) -TaskReuse (New-SkippedTask) -PlanHash $script:PlanHash
        $empty = @{ references_used = @(); deviations = @() }
        (Assert-ReuseResult -Context $skippedContext -ResultReuse $empty).references_used.Count | Should -Be 0

        $decision = New-ValidDecision
        $decision.candidates = @()
        $decision.strategy = 'build'
        $task = New-ValidTask
        $task.refs = @()
        $buildContext = Get-ReuseContext -Decision $decision -TaskReuse $task -PlanHash $script:PlanHash
        (Assert-ReuseResult -Context $buildContext -ResultReuse $empty).deviations.Count | Should -Be 0
    }

    It 'rejects whitespace-only deviation reasons' {
        $context = Get-ReuseContext -Decision (New-ValidDecision) -TaskReuse (New-ValidTask) -PlanHash $script:PlanHash
        $result = @{ references_used = @(); deviations = @(@{ reference = 'prior-art'; reason = '   ' }) }
        Assert-ReuseFailure { Assert-ReuseResult -Context $context -ResultReuse $result } 'invalid_result'
    }

    It 'rejects duplicate and malformed result entries' {
        $context = Get-ReuseContext -Decision (New-ValidDecision) -TaskReuse (New-ValidTask) -PlanHash $script:PlanHash
        $result = @{ references_used = @('prior-art', 'prior-art'); deviations = @() }
        Assert-ReuseFailure { Assert-ReuseResult -Context $context -ResultReuse $result } 'invalid_result'
        $result = @{ references_used = @('prior-art'); deviations = @(
                @{ reference = 'prior-art'; reason = 'first' },
                @{ reference = 'prior-art'; reason = 'second' }
            ) }
        Assert-ReuseFailure { Assert-ReuseResult -Context $context -ResultReuse $result } 'invalid_result'
        $result = @{ references_used = 'prior-art'; deviations = @() }
        Assert-ReuseFailure { Assert-ReuseResult -Context $context -ResultReuse $result } 'invalid_result'
        $result = @{ references_used = @(); deviations = 'none' }
        Assert-ReuseFailure { Assert-ReuseResult -Context $context -ResultReuse $result } 'invalid_result'
        $result = @{ references_used = @(); deviations = @(@{ reference = 'prior-art' }) }
        Assert-ReuseFailure { Assert-ReuseResult -Context $context -ResultReuse $result } 'invalid_result'
    }

    It 'allows a deviation for a reference that was still used' {
        $context = Get-ReuseContext -Decision (New-ValidDecision) -TaskReuse (New-ValidTask) -PlanHash $script:PlanHash
        $result = @{
            references_used = @('prior-art')
            deviations = @(@{ reference = 'prior-art'; reason = 'Used only the document shape, not the wording.' })
        }
        (Assert-ReuseResult -Context $context -ResultReuse $result).references_used | Should -Be @('prior-art')
    }

    It 'rejects a context that does not match its declared candidates' {
        $context = Get-ReuseContext -Decision (New-ValidDecision) -TaskReuse (New-ValidTask) -PlanHash $script:PlanHash
        $context.candidates = @()
        Assert-ReuseFailure { Assert-ReuseResult -Context $context -ResultReuse (New-ValidResult) } 'invalid_context'
        Assert-ReuseFailure { Assert-ReuseResult -ResultReuse (New-ValidResult) } 'invalid_argument'
        Assert-ReuseFailure { Assert-ReuseResult -Context $context } 'invalid_argument'
    }
}

Describe 'Reuse protocol documents' {
    It 'freezes a draft-07 schema with one branch per document shape' {
        $schema = ConvertFrom-Json -InputObject ([IO.File]::ReadAllText((Join-Path $script:ProtocolRoot 'reuse.schema.json'))) -AsHashtable -Depth 100
        $schema['$schema'] | Should -Be 'http://json-schema.org/draft-07/schema#'
        @($schema.oneOf).Count | Should -Be 3
        @($schema.oneOf | ForEach-Object { $_.title }) | Should -Be @('reuse decision', 'task reuse declaration', 'result reuse declaration')
        # The schema branch for a task declaration freezes the skip_reason enum too.
        $taskBranch = @($schema.oneOf | Where-Object { $_.title -ceq 'task reuse declaration' })[0]
        @($taskBranch.properties.skip_reason.enum) | Should -Be @('docs_only', 'diagnosed_local_bug', 'established_repo_pattern', 'data_only')
    }

    It 'keeps the documented skipped, completed and blocked decision examples valid and complete' {
        $examples = @(Get-ProtocolExample 'reuse-decision')
        $examples.Count | Should -Be 4
        $statuses = @()
        foreach ($json in $examples) {
            $document = ConvertFrom-Example $json
            $null = Assert-ReuseDecision -Decision $document
            $statuses += [string]$document['status']
        }
        @($statuses | Sort-Object) | Should -Be @('blocked', 'completed', 'completed', 'skipped')
    }

    It 'documents a completed decision whose mandatory channels all answered no_results' {
        $zeroResult = @()
        foreach ($json in @(Get-ProtocolExample 'reuse-decision')) {
            $document = ConvertFrom-Example $json
            if ([string]$document['status'] -cne 'completed') { continue }
            if (@($document['searches'] | Where-Object { $_.outcome -ceq 'results' }).Count -gt 0) { continue }
            $zeroResult += $document
        }
        $zeroResult.Count | Should -Be 1 -Because 'the zero-result completed shape must stay documented'
        $document = $zeroResult[0]
        @($document['searches'] | Where-Object { $_.outcome -ceq 'no_results' }).Count | Should -Be 3
        @($document['candidates']).Count | Should -Be 0
        $document['strategy'] | Should -Be 'build'
        (Assert-ReuseDecision -Decision $document).status | Should -Be 'completed'
    }

    It 'reads reuse.schema.json from disk instead of inlining the structural rules' {
        $copy = New-ProtocolCopy ("schema-" + [guid]::NewGuid().ToString('N'))
        $originalRoot = $script:ReuseProtocolRoot
        try {
            # A missing schema file is a protocol level failure, never a silent pass.
            [IO.File]::Delete((Join-Path $copy 'reuse.schema.json'))
            $script:ReuseProtocolRoot = $copy
            Assert-ReuseFailure { Assert-ReuseDecision -Decision (New-ValidDecision) } 'protocol_incomplete'
            # A tightened schema changes the verdict, which proves the file is consulted.
            [IO.File]::WriteAllText((Join-Path $copy 'reuse.schema.json'),
                '{"$schema":"http://json-schema.org/draft-07/schema#","oneOf":[{"type":"object","properties":{"version":{"const":2}},"required":["version"]}]}')
            Assert-ReuseFailure { Assert-ReuseDecision -Decision (New-ValidDecision) } 'invalid_decision'
        } finally {
            $script:ReuseProtocolRoot = $originalRoot
        }
    }

    It 'keeps every documented task example valid against a documented decision' {
        $decisions = @(Get-ProtocolExample 'reuse-decision' | ForEach-Object { ConvertFrom-Example $_ })
        $tasks = @(Get-ProtocolExample 'reuse-task')
        $tasks.Count | Should -BeGreaterThan 0
        foreach ($json in $tasks) {
            $task = ConvertFrom-Example $json
            $accepted = $false
            foreach ($decision in $decisions) {
                if ($null -ne (Invoke-ReuseExpectingFailure { Assert-ReuseTask -Decision $decision -TaskReuse $task })) { continue }
                $accepted = $true
                break
            }
            $accepted | Should -BeTrue -Because "documented task example must match a documented decision: $json"
        }
    }

    It 'keeps every documented result example valid against a documented context' {
        $contexts = @()
        foreach ($decisionJson in @(Get-ProtocolExample 'reuse-decision')) {
            $decision = ConvertFrom-Example $decisionJson
            foreach ($taskJson in @(Get-ProtocolExample 'reuse-task')) {
                $task = ConvertFrom-Example $taskJson
                $candidate = $null
                try { $candidate = Get-ReuseContext -Decision $decision -TaskReuse $task -PlanHash $script:PlanHash } catch { $candidate = $null }
                if ($null -eq $candidate) { continue }
                $contexts += $candidate
            }
        }
        $contexts.Count | Should -BeGreaterThan 0
        foreach ($json in @(Get-ProtocolExample 'reuse-result')) {
            $result = ConvertFrom-Example $json
            $accepted = $false
            foreach ($context in $contexts) {
                if ($null -ne (Invoke-ReuseExpectingFailure { Assert-ReuseResult -Context $context -ResultReuse $result })) { continue }
                $accepted = $true
                break
            }
            $accepted | Should -BeTrue -Because "documented result example must match a documented context: $json"
        }
    }

    It 'states the operational rules that keep the protocol lightweight' {
        $text = [IO.File]::ReadAllText((Join-Path $script:ProtocolRoot 'README.md'))
        $text | Should -Match 'Routine（默认）'
        $text | Should -Match '一句 inline 结论'
        $text | Should -Match '既有计划文件'
        $text | Should -Match 'Reuse / Prior Art'
        $text | Should -Match '没有重新检索的义务'
        $text | Should -Match 'unavailable'
        $text | Should -Match '确切 Team Plan hash'
        $text | Should -Match '机械准入由 Team 运行器负责'
        $text | Should -Match '不依赖任何模型名或 harness 名'
        $text | Should -Match '不构成批准'
    }

    It 'documents the zero-result, completed-only registry and skip_reason rules' {
        $text = [IO.File]::ReadAllText((Join-Path $script:ProtocolRoot 'README.md'))
        # A mandatory channel answered with a zero result is a successful channel.
        $text | Should -Match 'results.*或.*no_results'
        # The registry requirement is bound to a completed decision, so a blocked
        # declaration still reaches the pause and owner exception path.
        $text | Should -Match '仅在决策 `status = completed` 时'
        # skip_reason is an enum token and the explanation lives in reason.
        $text | Should -Match 'skip_reason = docs_only'
        $text | Should -Match '写在 `reason` 里'
        # The validator reads its schema file on every validation.
        $text | Should -Match '校验都会读取本目录的'
        $text | Should -Match 'reuse\.schema\.json'
    }

    It 'discloses the dot-source side effects and the exact scope of the selected-candidate rule' {
        $text = [IO.File]::ReadAllText((Join-Path $script:ProtocolRoot 'README.md'))
        # Dot-sourcing is not scope neutral: both session-level settings are disclosed instead
        # of the protocol claiming it has no side effects at all.
        $text.Contains('Set-StrictMode -Version Latest') | Should -BeTrue
        $text.Contains('$ErrorActionPreference = ''Stop''') | Should -BeTrue
        $text.Contains('dot-source 使用，无副作用') | Should -BeFalse
        # The non-build selected-candidate rule is limited to required decisions, exactly as
        # the validator enforces it (a skipped decision never reaches that check).
        $text.Contains('仅对 `applicability = required` 的决策') | Should -BeTrue
    }

    It 'shares one candidate-evaluation sentence through the canonical source' {
        $text = [IO.File]::ReadAllText((Join-Path $script:ProtocolRoot 'README.md'))
        foreach ($token in @('需求适配度', '维护状态', '许可证', '集成成本', '安全风险')) {
            $text.Contains($token) | Should -BeTrue -Because "the canonical protocol must carry the shared evaluation criterion: $token"
        }
        $text.Contains('不设固定百分比阈值') | Should -BeTrue -Because 'the criteria carry no fixed percentage threshold'
        # The three entrypoints only point at this file, so the single sentence is shared by
        # construction instead of being copied into three rule sets.
        foreach ($file in @('claude/CLAUDE.md', 'dsh/AGENTS.md', 'codex/AGENTS.md')) {
            $path = Join-Path $script:RepoRoot $file
            [IO.File]::ReadAllText($path).Contains('workflow-core/reuse/README.md') | Should -BeTrue -Because "$file must reference the canonical protocol"
        }
    }

    It 'keeps the validator free of process and network launches' {
        $text = [IO.File]::ReadAllText((Join-Path $script:ProtocolRoot 'Reuse.ps1'))
        foreach ($token in @('Start-Process', 'Invoke-WebRequest', 'Invoke-RestMethod', 'Invoke-Expression',
                'Add-Type', 'New-Object', 'curl ', 'wget ', 'npm ', 'node ', '& git', 'git -C')) {
            $text.Contains($token) | Should -BeFalse -Because "the protocol validator must stay pure: $token"
        }
    }

    It 'keeps the protocol directory self-contained' {
        $files = @(Get-ChildItem -LiteralPath $script:ProtocolRoot -File | Select-Object -ExpandProperty Name)
        @($files | Sort-Object) | Should -Be @('README.md', 'Reuse.ps1', 'reuse.schema.json')
    }
}
