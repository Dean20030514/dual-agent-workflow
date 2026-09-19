# Read-only assertions that the three harness entrypoints reference the deployed canonical
# reuse protocol, and that both critical plan templates carry the fixed subsection.
#
# STATED LIMIT (not hidden debt): these assertions prove the shipped TEXT names the
# installed path, the fixed heading and the real Plan/task/Result interfaces. They do NOT
# prove that a harness actually loads the file or that a plan is really produced with the
# subsection - that load is a later real smoke run by the Lead. The runtime enforcement
# itself lives in team/scripts and is covered by the Team suites, not by these text probes.
# Nothing here executes the installer, and nothing here writes inside a managed home.

BeforeAll {
    . "$PSScriptRoot/TestHelpers.ps1"

    function Test-FileHasToken {
        <# True when the file exists and its text contains the literal token. #>
        param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Token)
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
        return ([IO.File]::ReadAllText($Path)).Contains($Token)
    }

    function New-TokenRemovedCopy {
        <#
        .SYNOPSIS
        Writes a temp copy of the file with the guarded token stripped (negative control).
        .DESCRIPTION
        The discriminating power of a text guard is only shown by a sample that would pass if
        the guard were absent. Stripping the token from the REAL content is that sample: the
        probe must return false for it, otherwise the assertion proves nothing.
        #>
        param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Token)
        $dir = New-TempDirectory -Prefix 'entry-probe'
        $text = [IO.File]::ReadAllText($Path).Replace($Token, '<token-removed>')
        $copy = Join-Path $dir (Split-Path -Leaf $Path)
        [IO.File]::WriteAllText($copy, $text, (New-Object Text.UTF8Encoding($false)))
        return @{ Dir = $dir; Path = $copy }
    }

    $script:Repo = Get-RepoRoot
    $script:ProtocolToken = 'workflow-core/reuse/README.md'
}

Describe 'Reuse entrypoints name the deployed canonical protocol (read-only)' {
    It 'names the protocol path plus its own home anchor in all three harness entrypoints' {
        # claude = Claude Code global instructions; dsh = DSH global instructions;
        # codex = Codex CLI global instructions (non-review development sessions).
        $cases = @(
            @{ File = 'claude\CLAUDE.md'; Anchor = '~/.claude/workflow-core/reuse' },
            @{ File = 'dsh\AGENTS.md'; Anchor = '~/.dsh/workflow-core/reuse' },
            @{ File = 'codex\AGENTS.md'; Anchor = '$CODEX_HOME/workflow-core/reuse' }
        )
        foreach ($c in $cases) {
            $path = Join-Path $script:Repo $c.File
            (Test-Path -LiteralPath $path -PathType Leaf) | Should -BeTrue -Because "$($c.File) is an entrypoint of this repository"
            Test-FileHasToken -Path $path -Token $script:ProtocolToken | Should -BeTrue -Because "$($c.File) must point at the deployed canonical protocol"
            Test-FileHasToken -Path $path -Token $c.Anchor | Should -BeTrue -Because "$($c.File) must resolve the copy inside its own home"
        }
    }

    It 'names the protocol in both explore phases and requires the subsection in both plan phases' {
        $cases = @(
            @{ File = 'claude\commands\explore.md'; Anchor = 'Reuse Findings' },
            @{ File = 'dsh\skills\dual-agent-workflow\references\phases\explore.md'; Anchor = 'Reuse Findings' },
            @{ File = 'claude\commands\plan.md'; Anchor = 'Reuse / Prior Art' },
            @{ File = 'dsh\skills\dual-agent-workflow\references\phases\plan.md'; Anchor = 'Reuse / Prior Art' }
        )
        foreach ($c in $cases) {
            $path = Join-Path $script:Repo $c.File
            (Test-Path -LiteralPath $path -PathType Leaf) | Should -BeTrue -Because "$($c.File) is a phase of this repository"
            Test-FileHasToken -Path $path -Token $script:ProtocolToken | Should -BeTrue -Because "$($c.File) must point at the deployed canonical protocol"
            Test-FileHasToken -Path $path -Token $c.Anchor | Should -BeTrue -Because "$($c.File) keeps its Reuse Findings / Reuse / Prior Art contract"
        }
    }

    It 'carries the fixed Reuse / Prior Art heading in both critical plan templates, identically' {
        $headings = @()
        foreach ($file in 'claude\workflow\templates\IMPLEMENTATION_PLAN.md', 'dsh\workflow\templates\IMPLEMENTATION_PLAN.md') {
            $path = Join-Path $script:Repo $file
            $lines = @([IO.File]::ReadAllLines($path) | Where-Object { $_ -eq '## Reuse / Prior Art' })
            $lines.Count | Should -Be 1 -Because "$file must carry the fixed subsection exactly once"
            $lines[0] | Should -Be '## Reuse / Prior Art'
            $headings += ($lines[0] + '|' + ([IO.File]::ReadAllText($path).Contains('workflow-core/reuse/README.md')))
        }
        $headings[0] | Should -Be $headings[1] -Because 'the template pair is a derived pair: both sides must stay identical'
    }

    It 'points the Claude rule pack and the DSH phases at the canonical source instead of restating the procedure' {
        $rules = Join-Path $script:Repo 'claude\rules\common\development-workflow.md'
        Test-FileHasToken -Path $rules -Token 'workflow-core/reuse/README.md' | Should -BeTrue -Because 'the rule pack must delegate to the canonical source'
        Test-FileHasToken -Path $rules -Token 'battle-tested libraries' | Should -BeFalse -Because 'the duplicated detailed rule now lives once, in core/reuse'

        # The DSH phase used to cite rules/common/development-workflow.md, which the DSH
        # landing does not deploy - a dangling pointer for every DSH session.
        foreach ($file in 'dsh\skills\dual-agent-workflow\references\phases\explore.md', 'dsh\skills\dual-agent-workflow\references\phases\plan.md') {
            Test-FileHasToken -Path (Join-Path $script:Repo $file) -Token 'rules/common/development-workflow.md' | Should -BeFalse -Because "$file must not cite a path the DSH landing does not deploy"
        }
    }

    It 'points the Team Lead at the actual Plan/task/Result interfaces instead of transitional storage' {
        $lead = Join-Path $script:Repo 'team\policies\codex-lead-prompt.md'
        (Test-Path -LiteralPath $lead -PathType Leaf) | Should -BeTrue -Because 'the Team Lead policy ships with this repository'
        foreach ($token in @('Plan.reuse', 'task.reuse', 'Result.reuse', 'reuse_context')) {
            Test-FileHasToken -Path $lead -Token $token | Should -BeTrue -Because "the Lead policy must name the real reuse interface: $token"
        }
        # The conclusion is no longer stored only in the classification reasons or a task
        # objective, and the mechanical gate is no longer described as a later slice.
        Test-FileHasToken -Path $lead -Token 'classification.reasons' | Should -BeFalse -Because 'the decision lives in Plan.reuse now'
        Test-FileHasToken -Path $lead -Token '尚未接入' | Should -BeFalse -Because 'the runner validates these fields; the later-slice claim is stale'
        Test-FileHasToken -Path $lead -Token '后续切片' | Should -BeFalse -Because 'the mechanical admission is part of the current gate'
        Test-FileHasToken -Path $lead -Token 'plan hash' | Should -BeTrue -Because 'the exact-plan owner exception is part of the current gate'
        Test-FileHasToken -Path $lead -Token 'workflow-core/reuse/README.md' | Should -BeTrue -Because 'the policy points at the canonical protocol instead of restating it'
    }

    It 'shares the canonical candidate-evaluation criteria through the single protocol source' {
        $protocol = Join-Path $script:Repo 'core\reuse\README.md'
        (Test-Path -LiteralPath $protocol -PathType Leaf) | Should -BeTrue -Because 'the canonical protocol ships with this repository'
        foreach ($token in @('需求适配度', '维护状态', '许可证', '集成成本', '安全风险', '不设固定百分比阈值')) {
            Test-FileHasToken -Path $protocol -Token $token | Should -BeTrue -Because "the canonical protocol must carry the shared criterion: $token"
        }
        # Sharing is by reference: every entrypoint names the deployed copy of this one source.
        foreach ($c in @('claude\CLAUDE.md', 'dsh\AGENTS.md', 'codex\AGENTS.md')) {
            $path = Join-Path $script:Repo $c
            Test-FileHasToken -Path $path -Token $script:ProtocolToken | Should -BeTrue -Because "$c must reference the same canonical source"
        }
    }

    It 'negative control: the token probe fails on the same content with the token removed' {
        $probes = @(
            @{ File = 'claude\CLAUDE.md'; Token = $script:ProtocolToken },
            @{ File = 'claude\workflow\templates\IMPLEMENTATION_PLAN.md'; Token = '## Reuse / Prior Art' }
        )
        foreach ($p in $probes) {
            $path = Join-Path $script:Repo $p.File
            $mutated = New-TokenRemovedCopy -Path $path -Token $p.Token
            try {
                Test-FileHasToken -Path $path -Token $p.Token | Should -BeTrue -Because 'the control starts from a passing sample'
                Test-FileHasToken -Path $mutated.Path -Token $p.Token | Should -BeFalse -Because "if the token were absent the guard must fail, or it proves nothing ($($p.File))"
            } finally { Remove-Item -LiteralPath $mutated.Dir -Recurse -Force }
        }
    }
}
