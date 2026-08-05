#requires -Version 7.0
# Pester tests for tools/validate/lib/Common.ps1 - shared result model, baseline
# registry loading/matching/stale detection, and run-level aggregation.
# Fixture files live under tests/fixtures/common/ (fixture-scope contract:
# active checks never scan tests/fixtures/**; tests reach them explicitly).

BeforeAll {
    . (Join-Path $PSScriptRoot '..' 'lib' 'Common.ps1')
    $script:FixtureRoot = Join-Path $PSScriptRoot 'fixtures' 'common'

    function script:New-ValidBaselineEntry {
        param([string]$Id = 'BL-X-001', [string]$CheckId = 'path-references',
              [string]$Target = 'docs/example.md', [string]$Observation = './missing.sh')
        @{
            id                 = $Id
            check_id           = $CheckId
            exact_target       = $Target
            exact_observation  = $Observation
            reason             = 'unit-test entry'
            payoff             = @{ work_item = 'H2'; condition = 'removed when H2 lands' }
            introduced_by_plan = 'docs/ai/IMPLEMENTATION_PLAN.md (H5A)'
            owner              = 'Dean'
            status             = 'active'
        }
    }
}

Describe 'New-ValidationFinding' {
    It 'creates a FAIL finding carrying check id, target, observation and line' {
        $f = New-ValidationFinding -CheckId 'path-references' -Target 'claude/rules/README.md' `
            -Observation './install.sh' -Line 34
        $f.CheckId     | Should -Be 'path-references'
        $f.Target      | Should -Be 'claude/rules/README.md'
        $f.Observation | Should -Be './install.sh'
        $f.Line        | Should -Be 34
        $f.Status      | Should -Be 'FAIL'
        $f.BaselineId  | Should -BeNullOrEmpty
    }

    It 'leaves line empty when not provided' {
        $f = New-ValidationFinding -CheckId 'x' -Target 't' -Observation 'o'
        $f.Line | Should -BeNullOrEmpty
    }
}

Describe 'New-CheckResult' {
    It 'creates a PASS result with no findings' {
        $r = New-CheckResult -CheckId 'path-references' -Status 'PASS'
        $r.CheckId  | Should -Be 'path-references'
        $r.Status   | Should -Be 'PASS'
        @($r.Findings).Count | Should -Be 0
    }

    It 'carries findings on a FAIL result' {
        $f = New-ValidationFinding -CheckId 'c' -Target 't' -Observation 'o'
        $r = New-CheckResult -CheckId 'c' -Status 'FAIL' -Findings @($f)
        @($r.Findings).Count | Should -Be 1
    }

    It 'rejects unknown status values' {
        { New-CheckResult -CheckId 'c' -Status 'BOGUS' } | Should -Throw
    }

    It 'rejects SKIP with a reason other than prerequisite_not_landed' {
        { New-CheckResult -CheckId 'c' -Status 'SKIP' -SkipReason 'not-implemented' -PendingWorkItem 'H1' } |
            Should -Throw
    }

    It 'rejects SKIP without a pending work item reference' {
        { New-CheckResult -CheckId 'c' -Status 'SKIP' -SkipReason 'prerequisite_not_landed' } |
            Should -Throw
    }

    It 'accepts SKIP with prerequisite_not_landed and a pending work item' {
        $r = New-CheckResult -CheckId 'provenance' -Status 'SKIP' `
            -SkipReason 'prerequisite_not_landed' -PendingWorkItem 'H1'
        $r.Status          | Should -Be 'SKIP'
        $r.SkipReason      | Should -Be 'prerequisite_not_landed'
        $r.PendingWorkItem | Should -Be 'H1'
    }

    It 'rejects ENVIRONMENT_ERROR without guidance message' {
        { New-CheckResult -CheckId 'secret-scan' -Status 'ENVIRONMENT_ERROR' } | Should -Throw
    }

    It 'accepts ENVIRONMENT_ERROR with guidance message' {
        $r = New-CheckResult -CheckId 'secret-scan' -Status 'ENVIRONMENT_ERROR' `
            -Message 'gitleaks not found in PATH; install pinned release v8.30.1'
        $r.Message | Should -Match 'gitleaks'
    }
}

Describe 'Get-BaselineEntrySchemaError' {
    It 'accepts a complete entry' {
        $entry = New-ValidBaselineEntry
        @(Get-BaselineEntrySchemaError -Entry $entry).Count | Should -Be 0
    }

    It 'reports a missing required field' {
        $entry = New-ValidBaselineEntry
        $entry.Remove('reason')
        $errors = @(Get-BaselineEntrySchemaError -Entry $entry)
        $errors.Count | Should -BeGreaterThan 0
        ($errors -join '; ') | Should -Match 'reason'
    }

    It 'requires payoff.work_item and payoff.condition' {
        $entry = New-ValidBaselineEntry
        $entry.payoff = @{ work_item = 'H2' }
        $errors = @(Get-BaselineEntrySchemaError -Entry $entry)
        ($errors -join '; ') | Should -Match 'payoff.condition'
    }

    It 'rejects status other than active' {
        $entry = New-ValidBaselineEntry
        $entry.status = 'retired'
        $errors = @(Get-BaselineEntrySchemaError -Entry $entry)
        ($errors -join '; ') | Should -Match 'active'
    }
}

Describe 'Import-BaselineRegistry' {
    It 'returns an empty registry when the file does not exist' {
        $r = Import-BaselineRegistry -Path (Join-Path $TestDrive 'no-such-baseline.yml')
        @($r.Entries).Count      | Should -Be 0
        $r.ParseError            | Should -BeNullOrEmpty
        @($r.SchemaErrors).Count | Should -Be 0
    }

    It 'parses entries from a valid registry file' {
        $r = Import-BaselineRegistry -Path (Join-Path $script:FixtureRoot 'baseline-valid.yml')
        @($r.Entries).Count | Should -Be 2
        $r.ParseError       | Should -BeNullOrEmpty
        @($r.SchemaErrors).Count | Should -Be 0
        $r.Entries[0].id    | Should -Be 'BL-TEST-001'
    }

    It 'reports a parse error for malformed YAML' {
        $r = Import-BaselineRegistry -Path (Join-Path $script:FixtureRoot 'baseline-malformed.yml')
        $r.ParseError | Should -Not -BeNullOrEmpty
    }

    It 'reports schema errors for entries with missing fields' {
        $r = Import-BaselineRegistry -Path (Join-Path $script:FixtureRoot 'baseline-bad-schema.yml')
        $r.ParseError | Should -BeNullOrEmpty
        @($r.SchemaErrors).Count | Should -BeGreaterThan 0
    }

    It 'accepts an explicit empty baseline list' {
        $r = Import-BaselineRegistry -Path (Join-Path $script:FixtureRoot 'baseline-empty-list.yml')
        @($r.Entries).Count      | Should -Be 0
        $r.ParseError            | Should -BeNullOrEmpty
        @($r.SchemaErrors).Count | Should -Be 0
    }

    It 'reports a schema error when the file exists without a baseline root key' {
        $r = Import-BaselineRegistry -Path (Join-Path $script:FixtureRoot 'baseline-missing-root.yml')
        $r.ParseError | Should -BeNullOrEmpty
        (@($r.SchemaErrors) -join '; ') | Should -Match "baseline' root key"
    }

    It 'reports a schema error for duplicate entry ids' {
        $r = Import-BaselineRegistry -Path (Join-Path $script:FixtureRoot 'baseline-duplicate-id.yml')
        $r.ParseError | Should -BeNullOrEmpty
        (@($r.SchemaErrors) -join '; ') | Should -Match 'duplicate'
    }
}

Describe 'Resolve-BaselineMatch' {
    It 'converts an exactly matching finding to BASELINE with the entry id' {
        $finding = New-ValidationFinding -CheckId 'path-references' -Target 'docs/example.md' -Observation './missing.sh'
        $entry   = New-ValidBaselineEntry -Id 'BL-1'
        $res = Resolve-BaselineMatch -Findings @($finding) -Entries @($entry) -ExecutedCheckIds @('path-references')
        $res.Findings[0].Status     | Should -Be 'BASELINE'
        $res.Findings[0].BaselineId | Should -Be 'BL-1'
        @($res.StaleEntries).Count  | Should -Be 0
    }

    It 'leaves non-matching findings as FAIL and marks the entry stale' {
        $finding = New-ValidationFinding -CheckId 'path-references' -Target 'docs/other.md' -Observation './other.sh'
        $entry   = New-ValidBaselineEntry -Id 'BL-1'
        $res = Resolve-BaselineMatch -Findings @($finding) -Entries @($entry) -ExecutedCheckIds @('path-references')
        $res.Findings[0].Status    | Should -Be 'FAIL'
        @($res.StaleEntries).Count | Should -Be 1
    }

    It 'does not glob-match targets' {
        $finding = New-ValidationFinding -CheckId 'path-references' -Target 'docs/example.md' -Observation './missing.sh'
        $entry   = New-ValidBaselineEntry -Target 'docs/*'
        $res = Resolve-BaselineMatch -Findings @($finding) -Entries @($entry) -ExecutedCheckIds @('path-references')
        $res.Findings[0].Status    | Should -Be 'FAIL'
        @($res.StaleEntries).Count | Should -Be 1
    }

    It 'does not pattern-match observations' {
        $finding = New-ValidationFinding -CheckId 'path-references' -Target 'docs/example.md' -Observation './missing.sh'
        $entry   = New-ValidBaselineEntry -Observation './missing.*'
        $res = Resolve-BaselineMatch -Findings @($finding) -Entries @($entry) -ExecutedCheckIds @('path-references')
        $res.Findings[0].Status | Should -Be 'FAIL'
    }

    It 'matches case-sensitively' {
        $finding = New-ValidationFinding -CheckId 'path-references' -Target 'docs/example.md' -Observation './MISSING.SH'
        $entry   = New-ValidBaselineEntry
        $res = Resolve-BaselineMatch -Findings @($finding) -Entries @($entry) -ExecutedCheckIds @('path-references')
        $res.Findings[0].Status | Should -Be 'FAIL'
    }

    It 'covers multiple identical findings with one entry without staleness' {
        $f1 = New-ValidationFinding -CheckId 'path-references' -Target 'docs/example.md' -Observation './missing.sh' -Line 3
        $f2 = New-ValidationFinding -CheckId 'path-references' -Target 'docs/example.md' -Observation './missing.sh' -Line 9
        $entry = New-ValidBaselineEntry -Id 'BL-1'
        $res = Resolve-BaselineMatch -Findings @($f1, $f2) -Entries @($entry) -ExecutedCheckIds @('path-references')
        @($res.Findings | Where-Object Status -EQ 'BASELINE').Count | Should -Be 2
        @($res.StaleEntries).Count | Should -Be 0
    }

    It 'does not mark entries stale when their check did not run' {
        $entry = New-ValidBaselineEntry -CheckId 'policy-invariants'
        $res = Resolve-BaselineMatch -Findings @() -Entries @($entry) -ExecutedCheckIds @('path-references')
        @($res.StaleEntries).Count | Should -Be 0
    }
}

Describe 'Get-CheckStatus' {
    It 'returns PASS for no findings' {
        Get-CheckStatus -Findings @() | Should -Be 'PASS'
    }

    It 'returns FAIL when any finding is FAIL' {
        $f1 = New-ValidationFinding -CheckId 'c' -Target 't' -Observation 'o'
        $f2 = New-ValidationFinding -CheckId 'c' -Target 't2' -Observation 'o2'
        $f2.Status = 'BASELINE'
        Get-CheckStatus -Findings @($f1, $f2) | Should -Be 'FAIL'
    }

    It 'returns BASELINE when all findings are baselined' {
        $f = New-ValidationFinding -CheckId 'c' -Target 't' -Observation 'o'
        $f.Status = 'BASELINE'
        Get-CheckStatus -Findings @($f) | Should -Be 'BASELINE'
    }
}

Describe 'Get-RunSummary' {
    BeforeAll {
        function script:New-ResultOf([string]$Status) {
            switch ($Status) {
                'SKIP' { New-CheckResult -CheckId 'c' -Status 'SKIP' -SkipReason 'prerequisite_not_landed' -PendingWorkItem 'H1' }
                'ENVIRONMENT_ERROR' { New-CheckResult -CheckId 'c' -Status 'ENVIRONMENT_ERROR' -Message 'guidance' }
                default { New-CheckResult -CheckId 'c' -Status $Status }
            }
        }
    }

    It 'is PASS with exit 0 when all checks pass' {
        $s = Get-RunSummary -CheckResults @((New-ResultOf 'PASS'), (New-ResultOf 'PASS'))
        $s.RunStatus | Should -Be 'PASS'
        $s.ExitCode  | Should -Be 0
    }

    It 'is PASS_WITH_BASELINE with exit 0 when a check is baselined (not disguised as PASS)' {
        $s = Get-RunSummary -CheckResults @((New-ResultOf 'PASS'), (New-ResultOf 'BASELINE'))
        $s.RunStatus | Should -Be 'PASS_WITH_BASELINE'
        $s.ExitCode  | Should -Be 0
    }

    It 'is FAIL with exit 1 when any check fails' {
        $s = Get-RunSummary -CheckResults @((New-ResultOf 'PASS'), (New-ResultOf 'FAIL'))
        $s.RunStatus | Should -Be 'FAIL'
        $s.ExitCode  | Should -Be 1
    }

    It 'is FAIL with exit 1 when a stale baseline entry exists even if all checks pass' {
        $s = Get-RunSummary -CheckResults @((New-ResultOf 'PASS')) -StaleEntries @((New-ValidBaselineEntry))
        $s.RunStatus | Should -Be 'FAIL'
        $s.ExitCode  | Should -Be 1
    }

    It 'is FAIL with exit 1 on registry parse/schema errors' {
        $s = Get-RunSummary -CheckResults @((New-ResultOf 'PASS')) -RegistryErrors @('malformed yaml')
        $s.RunStatus | Should -Be 'FAIL'
        $s.ExitCode  | Should -Be 1
    }

    It 'is ENVIRONMENT_ERROR with exit 2 and takes precedence over FAIL' {
        $s = Get-RunSummary -CheckResults @((New-ResultOf 'FAIL'), (New-ResultOf 'ENVIRONMENT_ERROR'))
        $s.RunStatus | Should -Be 'ENVIRONMENT_ERROR'
        $s.ExitCode  | Should -Be 2
    }

    It 'treats SKIP as neutral (PASS run when only PASS and SKIP)' {
        $s = Get-RunSummary -CheckResults @((New-ResultOf 'PASS'), (New-ResultOf 'SKIP'))
        $s.RunStatus | Should -Be 'PASS'
        $s.ExitCode  | Should -Be 0
    }
}

Describe 'Select-ActiveScanFile' {
    It 'filters archive and fixture paths out of active scans' {
        $paths = @(
            'README.md',
            'docs/ai/archive/2026-07-30-old-task/HANDOFF.md',
            'tools/validate/tests/fixtures/common/baseline-valid.yml',
            'claude/rules/README.md'
        )
        $result = @(Select-ActiveScanFile -Paths $paths)
        $result | Should -Be @('README.md', 'claude/rules/README.md')
    }

    It 'keeps paths that merely resemble the excluded roots' {
        $paths = @('docs/ai/archives.md', 'tools/validate/tests/fixtures.md')
        @(Select-ActiveScanFile -Paths $paths).Count | Should -Be 2
    }
}

Describe 'Test-RequiredModule' {
    It 'finds an installed module' {
        Test-RequiredModule -Name 'Microsoft.PowerShell.Utility' | Should -BeTrue
    }

    It 'reports a missing module' {
        Test-RequiredModule -Name 'surely-not-a-real-module-h5a' | Should -BeFalse
    }
}

Describe 'Import-RequirementManifest' {
    It 'loads the pinned module list from requirements.psd1' {
        $manifest = Import-RequirementManifest -Path (Join-Path $PSScriptRoot '..' 'requirements.psd1')
        @($manifest.Modules).Count | Should -Be 3
        @($manifest.Modules | ForEach-Object { $_.Name }) | Should -Contain 'Pester'
        foreach ($m in $manifest.Modules) { $m.RequiredVersion | Should -Match '^\d+\.\d+\.\d+$' }
    }
}

Describe 'Get-TrackedFile' {
    It 'lists tracked files from the repository root' {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..' '..' '..')).Path
        $files = Get-TrackedFile -RepoRoot $repoRoot
        $files | Should -Contain 'install.ps1'
        @($files).Count | Should -BeGreaterThan 100
    }

    It 'throws when the directory is not a git repository' {
        $nonRepo = Join-Path $TestDrive 'not-a-repo'
        New-Item -ItemType Directory -Path $nonRepo -Force | Out-Null
        { Get-TrackedFile -RepoRoot $nonRepo } | Should -Throw
    }
}
