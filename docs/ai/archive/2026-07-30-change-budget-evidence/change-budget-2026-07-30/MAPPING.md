# Repo-relative mapping (replaces the original mapping.txt)

The backup's original `mapping.txt` mapped flattened names to absolute local
paths and was removed at publication review (2026-07-30). Its bytes remain
provable: sha256 `B325C8F8CA4CF66E2896E0A139E2034413877CA57A159D5C901E2C1755040172`
(uppercase hex; also preserved verbatim in the local-only branch
`docs/evidence-preservation` at commit 682324d, pinned against GC by the
local-only tag `evidence-original-682324d` — neither is ever pushed). The
table below is the 1:1 repo-relative equivalent — each flattened
name corresponds to the managed file's repo path; live deploy targets are
listed in the repository README.

| flattened name                   | repo path                                        |
|----------------------------------|--------------------------------------------------|
| codex-AGENTS.md                  | codex/AGENTS.md                                  |
| commands-debug.md                | claude/commands/debug.md                         |
| commands-final-review.md         | claude/commands/final-review.md                  |
| commands-implement.md            | claude/commands/implement.md                     |
| commands-plan.md                 | claude/commands/plan.md                          |
| reviewer-prompt.md               | claude/workflow/reviewer-prompt.md               |
| templates-HANDOFF.md             | claude/workflow/templates/HANDOFF.md             |
| templates-IMPLEMENTATION_PLAN.md | claude/workflow/templates/IMPLEMENTATION_PLAN.md |
| templates-TASK_BRIEF.md          | claude/workflow/templates/TASK_BRIEF.md          |
| workflow-AGENTS.md               | claude/workflow/AGENTS.md                        |
