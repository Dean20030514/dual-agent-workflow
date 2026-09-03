# Development Workflow

> This file extends [common/git-workflow.md](./git-workflow.md) with the full feature development process that happens before git operations.

The Feature Implementation Workflow describes the development pipeline: research, planning, testing, code review, then committing to git. **Mode routing (2026-08-05 adjudication)**: steps 0 and 4–5 apply in all modes; the full artifact chain inside steps 1–3 is **Critical-mode** discipline. Routine tasks (the default) satisfy the same intent at task scale — brief inline direction, risk-scaled tests, self-review of the diff. See global CLAUDE.md → Mode Routing.

## Feature Implementation Workflow

0. **Research & Reuse** _(for new implementations, new dependencies, and architecture choices; pure doc fixes, already-diagnosed bug fixes, and changes following established in-repo patterns may skip)_
   - **GitHub code search first:** Run `gh search repos` and `gh search code` to find existing implementations, templates, and patterns before writing anything new.
   - **Library docs second:** Use Context7 or primary vendor docs to confirm API behavior, package usage, and version-specific details before implementing.
   - **Web search only when the first two are insufficient:** Use `WebSearch` / `WebFetch` for broader web research or discovery, after GitHub search and primary docs. (The Exa MCP previously named here is retired — see CLAUDE.md "MCP servers loaded".)
   - **Check package registries:** Search npm, PyPI, crates.io, and other registries before writing utility code. Prefer battle-tested libraries over hand-rolled solutions.
   - **Search for adaptable implementations:** Look for open-source projects that solve most of the problem and can be forked, ported, or wrapped; judge adoption by requirement fit, maintenance status, license, integration cost, and security risk — no fixed percentage threshold.
   - Prefer adopting or porting a proven approach over writing net-new code when it meets the requirement.

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
