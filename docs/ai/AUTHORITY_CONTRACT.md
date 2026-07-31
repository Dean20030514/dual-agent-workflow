# Snapshot-first authority contract — task record

> Versioned process record for `task/snapshot-first-authority-contract`
> (fast-path task; same dedicated-record pattern as `docs/ai/INSTALLER_GUARD.md`).
> Base: main @ e6a9b7f.

## Scope

- `README.md` line 3: flip the authority sentence from local-first
  ("以本机安装为准，本仓库不独立演进") to snapshot-first — the ONLY active-file
  occurrence of the old contract in the repository (verified by full grep,
  including the evidence archive).
- This record.

Explicitly OUT of scope: the H5A branch's root `AGENTS.md` (exists only on
`task/h5a-validator-foundation`; realigned by H5A's own plan amendment and
narrow supplemental approval), `install.ps1` (guard stays as merged), and every
other file.

## Applicability Scan (0.1)

Pure documentation / governance-contract task: UI/UX/performance/privacy dims
N/A; documentation-consistency and security-baseline apply. Although
Markdown-only, this changes the authority and deployment behavior contract, so
per reviewer ruling it keeps: explicit acceptance, human approval, and at least
one independent reviewer round. `install.ps1` is never executed.

## Frozen Acceptance

1. Old contract sentence「以本机安装为准，本仓库不独立演进」has zero hits in
   tracked files (historical copies under `docs/ai/archive/**` would be
   permitted, but none exist today — the pre-change count was exactly one, in
   README.md:3).
2. The new README authority sentence states all five contract elements:
   (a) repo `main`/tag/commit is the canonical source; (b) `~/.claude` and
   `~/.codex` are deployed runtime copies; (c) local modifications are
   candidate overlays that must be promoted through visible repo diffs and do
   not constitute the canonical version; (d) credentials, auth/session state,
   logs/caches, `settings.local.json`, and private auto-memory never enter the
   repo; (e) the install.ps1 migration lock stays effective until H3 lands real
   `-DryRun`/`-ValidateOnly`.
3. The migration-lock warning block in README is preserved verbatim.
4. The branch diff touches only `README.md` and this record.
5. `install.ps1` is not executed at any point.

## Out-of-scope note on remaining 「母本」 wording

README lines 26/30/39/43 use 「母本」 to denote the workflow-master content
itself; under snapshot-first the canonical carrier of that content is this
repository, so the wording stays coherent and is not part of the contract flip.
The「快照状态」section is a historical record and keeps its original text. If
the reviewer judges any of these need adjustment, they go into a fix round.

## Verification

Ran on this branch, 2026-07-30 (base main @ e6a9b7f):

1. `git grep "以本机安装为准\|不独立演进" -- .` → zero hits (exit 1). ✅
2. Five contract-element keywords each present exactly once in README
   (`规范事实源` / `运行副本` / `candidate overlay` / `不入仓` /
   `迁移安全锁定`). ✅
3. `git diff main -- README.md` = exactly one line changed (line 3); the
   migration-lock warning block is untouched. ✅
4. Branch diff = `README.md` (1 line) + this record only. ✅
5. install.ps1 not executed. ✅

## Human Approval Evidence

[待人类一句话批准：谁/何时/批准了什么——快速版凭证；批准后本任务方可由人类合入]

## Reviewer round

[待：本分支 diff 经至少一轮独立 Reviewer 审查；verdict 摘要与处置记于此]
