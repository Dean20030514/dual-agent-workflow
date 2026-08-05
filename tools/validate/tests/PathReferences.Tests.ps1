#requires -Version 7.0
# Pester tests for tools/validate/checks/PathReferences.ps1 (AC-2).
# Extraction rules under test (each locked by fixtures):
#   R1 markdown links/images/reference definitions - prose only (not fenced/inline code)
#   R2 ~/ tokens - everywhere including code contexts (docs quote paths in backticks)
#   R3 ./ prefixed tokens - everywhere (AC-2 mandates detecting ./install.sh in fences)
#   R4 inline-code directory tokens ending with '/' (AC-2 mandates detecting `skills/`)
# Resolution: query/fragment stripped; scheme URLs and pure anchors excluded;
# ~/ resolved only via the explicit install.ps1 mapping; brace/wildcard tilde
# tokens are captured WHOLE and classified only through the exact pattern
# registry (unregistered patterns FAIL - 2026-07-30 adjudication, plan A);
# machine-local paths (seeded ~/.codex/config.toml, undeployed
# ~/.claude/projects/) never checked; workflow/archive has exactly two audited
# local-only exceptions, every other archive reference resolves through the
# managed mapping; traversal escapes and case mismatches are findings.

BeforeAll {
    . (Join-Path $PSScriptRoot '..' 'lib' 'Common.ps1')
    . (Join-Path $PSScriptRoot '..' 'checks' 'PathReferences.ps1')
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..' '..' '..')).Path
    $script:CleanRoot = Join-Path $PSScriptRoot 'fixtures' 'path-references' 'clean'
    $script:BrokenRoot = Join-Path $PSScriptRoot 'fixtures' 'path-references' 'broken'
}

Describe 'Get-MarkdownReference' {
    It 'extracts inline link and image targets from prose' {
        $refs = @(Get-MarkdownReference -Lines @('See [a](x/y.md) and ![img](p/q.png).') -SourceFile 'd/f.md')
        @($refs | Where-Object RawTarget -EQ 'x/y.md').Count | Should -Be 1
        @($refs | Where-Object RawTarget -EQ 'p/q.png').Count | Should -Be 1
    }

    It 'extracts reference definition targets' {
        $refs = @(Get-MarkdownReference -Lines @('[ref]: sub/doc.md') -SourceFile 'd/f.md')
        @($refs | Where-Object RawTarget -EQ 'sub/doc.md').Count | Should -Be 1
    }

    It 'ignores link syntax inside fenced code blocks' {
        $lines = @('```', '[fake](nope/missing.md)', '```')
        @(Get-MarkdownReference -Lines $lines -SourceFile 'd/f.md' |
            Where-Object RawTarget -EQ 'nope/missing.md').Count | Should -Be 0
    }

    It 'ignores link syntax inside inline code spans' {
        $lines = @('Use `[fake](also/missing.md)` as an example.')
        @(Get-MarkdownReference -Lines $lines -SourceFile 'd/f.md' |
            Where-Object RawTarget -EQ 'also/missing.md').Count | Should -Be 0
    }

    It 'extracts tilde tokens from prose, inline code and fenced blocks' {
        $lines = @(
            'Prose ~/.claude/rules/a.md here.',
            'Inline `~/.claude/rules/b.md` here.',
            '```',
            'cp x ~/.claude/rules/c.md',
            '```'
        )
        $refs = @(Get-MarkdownReference -Lines $lines -SourceFile 'd/f.md' | Where-Object Kind -EQ 'tilde')
        @($refs).Count | Should -Be 3
        @($refs | ForEach-Object RawTarget) | Should -Contain '~/.claude/rules/c.md'
    }

    It 'extracts dot-slash tokens inside fenced blocks' {
        $lines = @('```bash', './install.sh typescript', '```')
        $refs = @(Get-MarkdownReference -Lines $lines -SourceFile 'd/f.md' | Where-Object Kind -EQ 'dotslash')
        @($refs).Count | Should -Be 1
        $refs[0].RawTarget | Should -Be './install.sh'
    }

    It 'extracts trailing-slash directory tokens from inline code only' {
        $lines = @(
            'The `skills/` directory provides material.',
            '```',
            'tree entry python/ stays out',
            '```'
        )
        $refs = @(Get-MarkdownReference -Lines $lines -SourceFile 'd/f.md' | Where-Object Kind -EQ 'inline-dir')
        @($refs).Count | Should -Be 1
        $refs[0].RawTarget | Should -Be 'skills/'
    }

    It 'does not extract tokens containing glob characters' {
        $lines = @('Pattern `tools/validate/tests/fixtures/**` and `docs/ai/archive/<x>/` stay out.')
        @(Get-MarkdownReference -Lines $lines -SourceFile 'd/f.md' |
            Where-Object Kind -EQ 'inline-dir').Count | Should -Be 0
    }

    It 'records the 1-based line number' {
        $refs = @(Get-MarkdownReference -Lines @('', '[a](x.md)') -SourceFile 'd/f.md')
        $refs[0].Line | Should -Be 2
    }

    It 'captures brace and wildcard tilde tokens whole - no truncation at special characters' {
        $lines = @(
            'Deploy dirs `~/.claude/{rules,workflow,commands}` are mirror-replaced.',
            'Memory ~/.claude/projects/*/memory stays local.',
            '```',
            'tail ~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl',
            '```'
        )
        $targets = @(Get-MarkdownReference -Lines $lines -SourceFile 'd/f.md' |
                Where-Object Kind -EQ 'tilde' | ForEach-Object RawTarget)
        $targets | Should -Contain '~/.claude/{rules,workflow,commands}'
        $targets | Should -Contain '~/.claude/projects/*/memory'
        $targets | Should -Contain '~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl'
    }

    It 'trims sentence punctuation without touching pattern characters' {
        $targets = @(Get-MarkdownReference -Lines @('See ~/.claude/projects/*/memory, then ~/.claude/CLAUDE.md.') -SourceFile 'd/f.md' |
                ForEach-Object RawTarget)
        $targets | Should -Contain '~/.claude/projects/*/memory'
        $targets | Should -Contain '~/.claude/CLAUDE.md'
    }
}

Describe 'Resolve-PathReference' {
    BeforeAll {
        function script:New-Ref([string]$Kind, [string]$Target, [string]$Source = 'docs/index.md') {
            [pscustomobject]@{ Kind = $Kind; RawTarget = $Target; Line = 1; SourceFile = $Source }
        }
    }

    It 'classifies scheme URLs as external (including mailto and drive letters)' {
        (Resolve-PathReference -Reference (New-Ref 'link' 'https://example.com/a.md')).Category | Should -Be 'external'
        (Resolve-PathReference -Reference (New-Ref 'link' 'mailto:x@example.com')).Category   | Should -Be 'external'
        (Resolve-PathReference -Reference (New-Ref 'link' 'C:/Users/x/file.md')).Category     | Should -Be 'external'
    }

    It 'classifies pure anchors as anchor' {
        (Resolve-PathReference -Reference (New-Ref 'link' '#section')).Category | Should -Be 'anchor'
    }

    It 'strips query and fragment before resolving' {
        $r = Resolve-PathReference -Reference (New-Ref 'link' 'sub/page.md#sec')
        $r.Category       | Should -Be 'resolved'
        $r.ResolvedTarget | Should -Be 'docs/sub/page.md'
        (Resolve-PathReference -Reference (New-Ref 'link' 'sub/page.md?view=1')).ResolvedTarget |
            Should -Be 'docs/sub/page.md'
    }

    It 'resolves relative targets against the source directory' {
        (Resolve-PathReference -Reference (New-Ref 'link' '../img/pic.png')).ResolvedTarget |
            Should -Be 'img/pic.png'
        (Resolve-PathReference -Reference (New-Ref 'link' './sub/page.md')).ResolvedTarget |
            Should -Be 'docs/sub/page.md'
    }

    It 'flags traversal escaping the scan root' {
        (Resolve-PathReference -Reference (New-Ref 'link' '../../escape.md')).Category | Should -Be 'traversal'
    }

    It 'resolves tilde references only through the explicit mapping' {
        $r = Resolve-PathReference -Reference (New-Ref 'tilde' '~/.claude/rules/common/testing.md')
        $r.Category       | Should -Be 'resolved'
        $r.ResolvedTarget | Should -Be 'claude/rules/common/testing.md'
        (Resolve-PathReference -Reference (New-Ref 'tilde' '~/.codex/AGENTS.md')).ResolvedTarget |
            Should -Be 'codex/AGENTS.md'
    }

    It 'treats seeded and undeployed paths as machine-local, never checked' {
        (Resolve-PathReference -Reference (New-Ref 'tilde' '~/.codex/config.toml')).Category |
            Should -Be 'machine-local'
        (Resolve-PathReference -Reference (New-Ref 'tilde' '~/.claude/projects/x/memory/MEMORY.md')).Category |
            Should -Be 'machine-local'
    }

    It 'treats evidenced machine-state, credential and local-only paths as machine-local' {
        foreach ($token in @(
                '~/.claude.json',
                '~/.codex/auth.json',
                '~/.codex/sessions/2026/07/30/rollout-x.jsonl',
                '~/.claude/rules-archived-zh/',
                '~/.codex/reviewer-readonly.config.toml',
                '~/.codex/reviewer-workspace-write.config.toml',
                '~/.codex/reviewer.config.toml')) {
            (Resolve-PathReference -Reference (New-Ref 'tilde' $token)).Category |
                Should -Be 'machine-local' -Because $token
        }
    }

    It 'resolves registered managed patterns to their audited expansion target lists' {
        # ~/.claude/{rules,workflow,commands} (README.md:15): the three
        # mirror-replaced deploy dirs, each verified against the tracked tree.
        $r = Resolve-PathReference -Reference (New-Ref 'tilde' '~/.claude/{rules,workflow,commands}')
        $r.Category        | Should -Be 'resolved-pattern'
        $r.ResolvedTargets | Should -Be @('claude/rules', 'claude/workflow', 'claude/commands')
        # claude/CLAUDE.md:173: the seven per-phase command files, one target each.
        $cmd = Resolve-PathReference -Reference (New-Ref 'tilde' '~/.claude/commands/{define,explore,plan,design-check,implement,debug,final-review}.md')
        $cmd.Category                 | Should -Be 'resolved-pattern'
        @($cmd.ResolvedTargets).Count | Should -Be 7
        $cmd.ResolvedTargets          | Should -Contain 'claude/commands/design-check.md'
        # claude/CLAUDE.md:215 and codex/AGENTS.md:8: globs over deployed files,
        # verified via their container directories.
        (Resolve-PathReference -Reference (New-Ref 'tilde' '~/.claude/rules/*.md')).ResolvedTargets |
            Should -Be @('claude/rules')
        (Resolve-PathReference -Reference (New-Ref 'tilde' '~/.claude/commands/*.md')).ResolvedTargets |
            Should -Be @('claude/commands')
    }

    It 'treats registered machine-local patterns as machine-local by whole-string match only' {
        foreach ($token in @(
                '~/.claude/projects/*/memory',                  # README.md:19 auto-memory
                '~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl', # claude/CLAUDE.md:196 rollout glob
                '~/.claude/workflow/archive/**')) {             # docs/ai/INSTALLER_GUARD.md:72 audited exception
            (Resolve-PathReference -Reference (New-Ref 'tilde' $token)).Category |
                Should -Be 'machine-local' -Because $token
        }
    }

    It 'flags every unregistered brace or wildcard token as unrecognized - no truncation bypass' {
        foreach ($token in @(
                '~/.claude/{rulez,workflow,commands}',  # brace typo of the managed pattern
                '~/.claude/projects/*/memroy',          # wildcard typo (old code passed it via prefix truncation)
                '~/.claude/{anything}',                 # unregistered brace
                '~/.codex/reviewer*.config.tmol',       # wildcard + extension typo
                '~/.claude/unknown/*')) {               # unregistered wildcard
            (Resolve-PathReference -Reference (New-Ref 'tilde' $token)).Category |
                Should -Be 'unrecognized-tilde' -Because $token
        }
    }

    It 'registers exactly two audited archive exceptions; other archive paths use the managed mapping' {
        # README.md:47 evidenced token, full string, exact file entry.
        (Resolve-PathReference -Reference (New-Ref 'tilde' '~/.claude/workflow/archive/2026-07-30-guard-effectiveness-backup/ARCHIVE_NOTE.md')).Category |
            Should -Be 'machine-local'
        # Any other archive path is a plain workflow subpath: managed mapping,
        # existence-checked (the old prefix entry wrongly blanket-exempted these).
        $other = Resolve-PathReference -Reference (New-Ref 'tilde' '~/.claude/workflow/archive/2026-07-30-x/ARCHIVE_NOTE.md')
        $other.Category       | Should -Be 'resolved'
        $other.ResolvedTarget | Should -Be 'claude/workflow/archive/2026-07-30-x/ARCHIVE_NOTE.md'
    }

    It 'treats the retired agents dir (referenced only to forbid it) as machine-local' {
        (Resolve-PathReference -Reference (New-Ref 'tilde' '~/.claude/agents/')).Category |
            Should -Be 'machine-local'
    }

    It 'treats the example config as repo content, not a deploy target' {
        # install.ps1 seeds codex/config.example.toml INTO ~/.codex/config.toml;
        # nothing ever creates ~/.codex/config.example.toml on a machine.
        (Resolve-PathReference -Reference (New-Ref 'tilde' '~/.codex/config.example.toml')).Category |
            Should -Be 'unrecognized-tilde'
    }

    It 'treats bare home-config roots as machine-local concept references' {
        (Resolve-PathReference -Reference (New-Ref 'tilde' '~/.claude')).Category  | Should -Be 'machine-local'
        (Resolve-PathReference -Reference (New-Ref 'tilde' '~/.claude/')).Category | Should -Be 'machine-local'
        (Resolve-PathReference -Reference (New-Ref 'tilde' '~/.codex/')).Category  | Should -Be 'machine-local'
    }

    It 'flags tilde references outside the mapping as unrecognized' {
        (Resolve-PathReference -Reference (New-Ref 'tilde' '~/.claude/unknown/thing.md')).Category |
            Should -Be 'unrecognized-tilde'
    }
}

Describe 'Invoke-PathReferencesCheck (fixture mode)' {
    BeforeAll {
        # Fixture-scoped literal claims: weak-signal kinds (dotslash/inline-dir)
        # are non-literal examples by default; these pairs assert the fixture's
        # genuine path claims, mirroring the production claim table's mechanism.
        $script:BrokenClaims = @(
            'docs/bad.md|./missing-script.sh',
            'docs/bad.md|nosuchdir/',
            'docs/bad.md|./install.sh',
            'docs/bad.md|skills/'
        )
    }

    It 'passes a clean fixture tree with zero findings' {
        $r = Invoke-PathReferencesCheck -RepoRoot $script:RepoRoot -FixtureRoot $script:CleanRoot
        @($r.Findings).Count | Should -Be 0
        $r.Status | Should -Be 'PASS'
    }

    It 'detects every violation category in the broken fixture tree (P4 capability, permanent)' {
        $r = Invoke-PathReferencesCheck -RepoRoot $script:RepoRoot -FixtureRoot $script:BrokenRoot -LiteralClaims $script:BrokenClaims
        $r.Status | Should -Be 'FAIL'
        $obs = @($r.Findings | ForEach-Object Observation)
        $obs | Should -Contain 'no/such.md'                        # missing relative target
        $obs | Should -Contain '../../outside.md'                  # traversal escape
        $obs | Should -Contain '~/.claude/unknown/thing.md'        # unrecognized tilde
        $obs | Should -Contain '~/.claude/rules/common/gone.md'    # mapped tilde, missing target
        $obs | Should -Contain 'Sub/Page.md'                       # case mismatch vs tracked set
        $obs | Should -Contain './missing-script.sh'               # claimed dot-slash token (prose)
        $obs | Should -Contain './install.sh'                      # claimed dot-slash token (fenced, AC-2 drift form)
        $obs | Should -Contain 'skills/'                           # claimed inline-dir token (AC-2 drift form)
        $obs | Should -Contain 'nosuchdir/'                        # claimed inline-dir token
        $obs | Should -Contain '~/.claude/{rulez,workflow,commands}'       # brace typo - unregistered pattern
        $obs | Should -Contain '~/.claude/projects/*/memroy'               # wildcard typo - old truncation bypass, now FAIL
        $obs | Should -Contain '~/.claude/{anything}'                      # unregistered brace
        $obs | Should -Contain '~/.codex/reviewer*.config.tmol'            # wildcard + extension typo - unregistered pattern
        $obs | Should -Contain '~/.claude/unknown/*'                       # unregistered wildcard
        $obs | Should -Contain '~/.claude/{rules,workflow,commands}'       # registered pattern, expansion targets missing in this tree
        $obs | Should -Contain '~/.claude/workflow/archive/other/thing.md' # archive path outside the two audited exceptions
        @($r.Findings).Count | Should -Be 16
    }

    It 'preserves the complete original token on pattern findings' {
        $r = Invoke-PathReferencesCheck -RepoRoot $script:RepoRoot -FixtureRoot $script:BrokenRoot -LiteralClaims $script:BrokenClaims
        # Case-sensitive whole-string equality: braces, commas and wildcards
        # survive extraction into the finding - classification and reporting
        # both see the original token, never a truncated stem.
        @($r.Findings | Where-Object Observation -CEQ '~/.claude/{rulez,workflow,commands}').Count | Should -Be 1
        @($r.Findings | Where-Object Observation -CEQ '~/.codex/reviewer*.config.tmol').Count | Should -Be 1
        @($r.Findings | Where-Object Observation -CEQ '~/.claude/projects/*/memroy').Count | Should -Be 1
    }

    It 'skips weak-signal tokens that carry no literal claim' {
        $r = Invoke-PathReferencesCheck -RepoRoot $script:RepoRoot -FixtureRoot $script:BrokenRoot -LiteralClaims $script:BrokenClaims
        @($r.Findings | Where-Object Observation -EQ 'exampledir/').Count | Should -Be 0
    }

    It 'reports findings against the containing file with line numbers' {
        $r = Invoke-PathReferencesCheck -RepoRoot $script:RepoRoot -FixtureRoot $script:BrokenRoot -LiteralClaims $script:BrokenClaims
        $f = @($r.Findings | Where-Object Observation -EQ 'no/such.md')[0]
        $f.Target  | Should -Be 'docs/bad.md'
        $f.CheckId | Should -Be 'path-references'
        $f.Line    | Should -BeGreaterThan 0
    }

    It 'rejects a fixture root outside tools/validate/tests/fixtures' {
        { Invoke-PathReferencesCheck -RepoRoot $script:RepoRoot -FixtureRoot $TestDrive } | Should -Throw
    }
}

Describe 'Invoke-PathReferencesCheck (production scan)' {
    BeforeAll {
        $script:ProdResult = Invoke-PathReferencesCheck -RepoRoot $script:RepoRoot
    }

    It 'never ingests fixture or archive sources (decoy assertion)' {
        @($script:ProdResult.Findings | Where-Object {
                $_.Target -clike 'tools/validate/tests/fixtures/*' -or $_.Target -clike 'docs/ai/archive/*'
            }).Count | Should -Be 0
    }

    It 'produces exactly the audited real-repo finding set - no unexpected findings' {
        # Complete-set constraint (review B1): the real repo proves "current debt
        # state", never "the defect string must exist forever". Re-audited on
        # 2026-08-04 after full-token capture landed (round-4 targeted fix):
        # three identities are real drift baselinable with payoff H2; the four
        # identities added by full-token capture are meta-reference casualties
        # of the strict pattern policy (unregistered pattern / bare archive dir)
        # living in per-task docs - they leave the set when those docs archive
        # at task close. Capability proof lives in the broken fixture.
        $expected = @(
            'claude/rules/README.md|../common/coding-style.md',  # quote-context example link (H2 rewrites quote)
            'claude/rules/README.md|./install.sh',               # ghost installer reference (H2 removes)
            'claude/rules/README.md|skills/',                    # ghost directory reference (H2 removes)
            'docs/ai/HANDOFF.md|~/.claude/{rulez,...}',          # immutable ledger quote of the round-3 counter-example; unregistered pattern, policy FAIL
            'docs/ai/HANDOFF.md|~/.claude/workflow/archive/',    # immutable ledger quote; bare archive dir maps to claude/workflow/archive, deliberately untracked
            'docs/ai/HANDOFF.md|~/.codex/config.example.toml',   # immutable ledger quote (round-2 correction record); install.ps1 never creates that home path - pre-existing red introduced by the hard-stop transcription commits, surfaced by the round-4 RED run
            'docs/ai/IMPLEMENTATION_PLAN.md|~/.claude/**',       # mapping-notation shorthand in approved plan prose; unregistered pattern, policy FAIL
            'docs/ai/TASK_BRIEF.md|~/.claude/*'                  # mapping-notation shorthand in AC-2 wording; unregistered pattern, policy FAIL
        ) | Sort-Object
        $actual = @($script:ProdResult.Findings | ForEach-Object { "$($_.Target)|$($_.Observation)" } |
                Sort-Object -Unique)
        $actual | Should -Be $expected
    }

    It 'reports the audited per-identity occurrence counts' {
        $findings = @($script:ProdResult.Findings)
        @($findings | Where-Object Observation -CEQ './install.sh').Count | Should -Be 7
        @($findings | Where-Object Observation -CEQ 'skills/').Count      | Should -Be 2
        @($findings | Where-Object Observation -CEQ '../common/coding-style.md').Count | Should -Be 1
        @($findings | Where-Object Observation -CEQ '~/.claude/{rulez,...}').Count | Should -Be 1
        @($findings | Where-Object Observation -CEQ '~/.claude/workflow/archive/').Count | Should -Be 1
        # config.example.toml sits in TWO immutable ledger lines (round-2 entry
        # and the fix-loop counter transcription), hence occurrence count 2.
        @($findings | Where-Object Observation -CEQ '~/.codex/config.example.toml').Count | Should -Be 2
        @($findings | Where-Object Observation -CEQ '~/.claude/**').Count | Should -Be 1
        @($findings | Where-Object Observation -CEQ '~/.claude/*').Count  | Should -Be 1
        $findings.Count | Should -Be 16
    }
}
