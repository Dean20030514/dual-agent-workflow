# Development Workflow

> This file extends [common/git-workflow.md](./git-workflow.md) with the full feature development process that happens before git operations.

The Feature Implementation Workflow describes the development pipeline: research, planning, testing, code review, then committing to git. **Mode routing (2026-08-05 adjudication)**: steps 0 and 4–5 apply in all modes; the full artifact chain inside steps 1–3 is **Critical-mode** discipline. Routine tasks (the default) satisfy the same intent at task scale — brief inline direction, risk-scaled tests, self-review of the diff. See global CLAUDE.md → Mode Routing.

## Feature Implementation Workflow

0. **Research & Reuse** _(new implementations, new dependencies, architecture choices and new protocols; pure doc fixes, already-diagnosed local bug fixes, changes following established in-repo patterns, and data-only changes may be skipped with an explicit reason)_
   - **One canonical source, no duplicate rules here:** the semantics, frozen field shapes and the validators live in `~/.claude/workflow-core/reuse/README.md` (deployed by `install.ps1` from `core/reuse/`). Read it before writing anything new; this step is the trigger and the pointer, not the procedure.
   - Four change kinds force a recorded prior-art pass; a skip must carry one of the protocol's fixed `skip_reason` values (the free-text justification goes in `reason`).
   - Native channels for this landing: `gh search repos` / `gh search code` (github_repositories / github_code), vendor or Context7 docs (primary_docs), npm / PyPI / crates.io (package_registry) — web search only when those are insufficient.
   - Record the conclusion as one inline sentence (Routine) or in `/explore`'s **Reuse Findings** plus the **Reuse / Prior Art** section of `IMPLEMENTATION_PLAN.md` (Critical).
   - Reviewers do not re-run the search: they check the declared constraints against the references actually used.

1. **Plan First**
   - Routine: state a brief plan/direction inline (in conversation); ask only when a real ambiguity would change the outcome.
   - Critical: create the full planning docs via `/plan` (TASK_BRIEF / IMPLEMENTATION_PLAN / HANDOFF, per `~/.claude/workflow/templates/`), run the default 9P plan review (one fresh-context run; further rounds only on explicit human request; see `~/.claude/workflow/reviewer-prompt.md` → 9P), then stop for human approval.
   - In both modes: identify dependencies and risks; break large work into phases.

2. **Test as You Implement**
   - Follow [testing.md](testing.md): risk-scaled tests by default; the TDD loop for Critical-mode tasks and risk-bearing features.
   - Coverage follows the project's own configured gate — no global percentage.

3. **Code Review**
   - Self-review the diff against [code-review.md](code-review.md) after writing code.
   - Independent Codex review (9A/9B) runs only in Critical mode — see the workflow master.
   - Address CRITICAL and HIGH issues; fix MEDIUM issues when possible (severity levels of the self-review only; independent Reviewer findings follow `reviewer-prompt.md`: Product Blocking / Verification Needed / Suggestion, each answered per item).

4. **Commit**
   - Actor: Routine — the human commits/merges after reviewing the diff; Critical — the agent creates only the stage commits the approved workflow explicitly requires.
   - Detailed commit messages, conventional commits format.
   - Prepare the exact push command for the human when needed — the agent NEVER executes remote operations. See [git-workflow.md](./git-workflow.md) for commit message format and PR process.

5. **Pre-Review Checks**
   - Routine: run the locally available checks relevant to the change; explicitly report anything not run (CI included).
   - Critical: full pre-review gate — verify all automated checks (CI/CD) are passing, resolve any merge conflicts, ensure the branch is up to date with the target branch, and only request review after these checks pass.
