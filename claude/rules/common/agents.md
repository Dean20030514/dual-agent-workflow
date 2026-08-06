# Agent Orchestration

## Available agents (single source of truth)

**The authoritative list is the agent list in each session's system-reminder** — typically generic types such as general-purpose / Explore / Plan.

**There are no domain-specialist agents on this machine.** They used to come from the `ecc` plugin (planner, architect, tdd-guide, code-reviewer, security-reviewer, build-error-resolver, e2e-runner, refactor-cleaner, doc-updater, language-specific reviewers); **that plugin was uninstalled on 2026-07-25** because it went unused, and its marketplace entry was removed from settings.json on 2026-08-05. `~/.claude/agents/` does not exist — never reference it. (Historical origin, for the record only: affaan-m/everything-claude-code.)

## Fallback rule (mandatory)

When no specialist agent exists for a job, **the main agent takes on that responsibility itself — only *who executes* degrades, never *whether it gets done*.** Other rule files point here for exactly this rule:

| Job | Do this instead |
|-----|-----------------|
| Code review | Walk the [code-review.md](code-review.md) checklist yourself |
| Security review | Walk the [security.md](security.md) checklist yourself — **never skipped** |
| Testing discipline | Follow the risk-scaled testing rules in [testing.md](testing.md) yourself; use the TDD loop for Critical-mode / high-risk work |
| Implementation planning | Routine: brief inline direction; Critical: `/plan`, with `/define` + `/explore` as needed |
| Build errors | Diagnose yourself via systematic debugging (`/debug`) |

**Model rule:** sub-agents always inherit the main conversation's model — omit the `model` parameter, never downgrade (see [performance.md](performance.md)).

## Parallel Task Execution

ALWAYS use parallel Task execution for independent operations:

```markdown
# GOOD: Parallel execution
Launch 3 agents in parallel:
1. Agent 1: Security analysis of auth module
2. Agent 2: Performance review of cache system
3. Agent 3: Type checking of utilities

# BAD: Sequential when unnecessary
First agent 1, then agent 2, then agent 3
```

## Multi-Perspective Analysis

For complex problems, use split role sub-agents:
- Factual reviewer
- Senior engineer
- Security expert
- Consistency reviewer
- Redundancy checker
