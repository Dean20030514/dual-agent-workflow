# Snapshot-first authority contract — task record

> Versioned process record for `task/snapshot-first-authority-contract`
> (fast-path task; same dedicated-record pattern as `docs/ai/INSTALLER_GUARD.md`).
> Base: main @ e6a9b7f. Round 1 draft: f63d100. This is the round-2 revision
> after three external reviews (see Reviewer round below).

## Scope

- `README.md`: replace the authority paragraph — the only active-file
  occurrence of the old local-first contract sentence, referred to here only by
  the identifier **`local-first-authority`** (verbatim text deliberately NOT
  quoted in this record so the zero-hit acceptance grep stays meaningful;
  retrieve it via `git show e6a9b7f:README.md`, line 3) — and add a one-line
  historical marker atop the「快照状态」section.
- This record.

Explicitly OUT of scope: the H5A branch's root `AGENTS.md` (realigned by H5A's
own plan amendment and narrow supplemental approval), `install.ps1`,
`claude/**`, `codex/**`, and every other file.

## Applicability Scan (0.1)

Pure documentation / governance-contract task: UI/UX/performance/privacy dims
N/A; documentation-consistency and security-baseline apply. Although
Markdown-only, this changes the authority and deployment behavior contract, so
per reviewer ruling it keeps explicit acceptance, human approval, and
independent review. `install.ps1` is never executed.

## Canonical anchor classification (frozen)

```yaml
deployable_anchors:
  current_canonical: main current tip        # the only default deploy target
  historical_deployable: >
    release/config tags explicitly designated deployable AND pointing at a
    main first-parent integration-boundary commit
deployable_tag_convention: >
  none_registered — until a designation convention is registered, the
  deployable set is exactly {main current tip}
non_deployable:
  - any other main-REACHABLE commit, incl. second-parent/topic-branch
    intermediates (counterexample: 718b31a is main-reachable yet a known-unsafe
    pre-CmdletBinding guard state, never a main integration state)
  - unmerged branches and commits (candidates)
  - migration_baseline               # e.g. workflow-baseline-pre-snapshot-first-2026-07-30
  - eval_baseline
  - evidence                         # e.g. evidence-original-682324d
  - archive
  - superseded
rule: >
  Reachability from main never implies deployability, and neither does the
  existence of a tag or version anchor. Only main's current tip — plus, once a
  designation convention exists, explicitly designated first-parent-boundary
  tags — may be deployed.
migration_overlay_grace: >
  The README's migration-period allowance for unpromoted candidate overlays on
  the managed surface ENDS when the LOCAL-001 selective-promotion task closes;
  any residual unpromoted delta on the managed surface then converts to a
  drift finding (feeds the registered validator drift-check follow-up).
managed_surface_note: >
  Managed runtime copy = install targets the deployer continuously
  mirrors/overwrites. ~/.codex/config.toml is seed-only (created when missing,
  never re-synced) and becomes machine-local / keep-local-only after creation —
  drift checks and H3 must NOT require it to match config.example.toml.
```

## Remaining 「母本」 semantics

The 「母本 / 母本核心」 wording retained elsewhere in README (layout table,
guard-effectiveness mechanism line, historical status section) denotes the
canonical workflow content carried by THIS repository — it no longer refers to
the `~/.claude` / `~/.codex` local installation. Registered follow-up (low
priority, per reviewer 甲 N1): unify the term at the next full README revision.

## Frozen Acceptance (v2)

1. The `local-first-authority` sentence has zero hits in the tip commit's
   tracked files excluding `docs/ai/archive/**` (this record refers to it by
   identifier only). **Methodology: the grep runs against the tip commit
   (`git grep <pat> <tip> -- .`), never against the working tree — round 1's
   false pass came from `git grep` skipping the then-untracked record file.**
2. The new README contract states, each present exactly once: deployable
   boundary (main current tip + designated first-parent-boundary deployable
   tags, none yet registered); non-deployable classes incl. main-reachable
   topic-branch intermediates (evidence/candidates only); managed deploy
   surface = paths the deployer continuously mirrors/overwrites, with the
   seed-only `~/.codex/config.toml` explicitly carved out as machine-local;
   machine-local / keep-local-only exemption; migration-period overlay
   allowance; candidate-overlay promotion duty for reusable changes to the
   managed surface; install.ps1 lock until H3.
3. The migration-lock warning block is preserved verbatim.
4. The branch diff touches only `README.md` and this record.
5. `install.ps1` is not executed at any point (process assertion by the
   Author; not provable from the diff, recorded as such per reviewer note).

## Verification (round 2 — superseded)

> Historical: bound to `8bc67fb`, superseded by round 3 below and by the
> final-tip verification mandated in the Merge gate (per R2-甲 M1 / R2-乙 V1).

Ran against tip commit `8bc67fb` (commit-addressed per the v2 methodology; the
grep pattern for the old sentence is the two-keyword `local-first-authority`
pattern — deliberately not spelled out here, see Scope for the retrieval
pointer):

1. `local-first-authority` pattern vs `8bc67fb`, excluding `docs/ai/archive/**`
   → zero hits (exit 1). ✅
2. Seven boundary elements each appear exactly once in `8bc67fb:README.md`:
   `已接纳的 commit` · `仅作证据锚点，不代表当前可部署版本` ·
   `由部署器明确管理的路径` · `machine-local / keep-local-only` ·
   `尚未晋升的 candidate overlay` · `受管部署面的可复用本机修改` ·
   `迁移安全锁定`. ✅
3. `git diff main 8bc67fb -- README.md` contains zero occurrences of the
   migration-lock warning text — the block is untouched. ✅
4. Branch diff = `README.md` + this record only. ✅
5. `install.ps1` not executed (Author process assertion; not diff-provable). ✅
6. Migration baseline tag present and classified `migration_baseline`
   (non-deployable) by the frozen anchor classification above. ✅
7. `git diff --check` clean. ✅

> The commit carrying this section postdates `8bc67fb` (a record cannot
> self-reference its own commit — same pattern as `handoff_snapshot_sha`);
> it adds only this verification text and changes no contract content.

## Reviewer round

Round 1 (2026-07-30, three external reviewers via human relay), verdicts and
disposition:

- R1-甲: approve, 3 non-blocking — N1 母本-term cleanup → registered above;
  N2 快照状态 present-tense criterion → triggered, one-line historical marker
  applied; N3 push-together + rev-parse-before-push → adopted for post-merge.
- R1-乙: needs_attention — B1 anchor overbreadth (any anchored tag/commit read
  as deployable; the migration baseline tag itself would qualify) and B2
  runtime-copy/overlay overbreadth (whole dirs as deployed copy; all local
  changes as overlay) → both fixed in the round-2 README text (anchor
  classification + managed-path scoping + migration-period allowance +
  machine-local exemption); NB paragraph split → applied ("one-line diff" is
  not an acceptance metric); NB 母本 note → applied.
- R1-丙: 不通过 — B1 zero-hit acceptance contradicted by this record's own
  verbatim quotes (3 hits on f63d100; root cause: check ran pre-commit against
  the working tree where the record was untracked) → fixed via identifier +
  commit-addressed grep; B2 authority-boundary tightening (main-accepted
  commits only; deployed copy = installer-managed paths) → merged into the
  round-2 text.

Round 2 (定点复核, 2026-07-30) verdicts and disposition:

- R2-甲: approve — M1 (acceptance must rerun against the actual tip, not a
  predecessor) → folded into the Merge gate below; N1 deployable-tag
  convention gap → `deployable_tag_convention: none_registered` frozen above;
  N2 overlay grace needs an endpoint → `migration_overlay_grace` bound to
  LOCAL-001 closure above; bundle-hash-into-index suggestion → done on main.
- R2-乙: semantic pass — V1/V2 (verification and merge must bind to the final
  human-approval tip; approval must be a versioned human commit) → encoded in
  the Merge gate below; PR0A fixture `verification-window-untracked-file` →
  registered as follow-up.
- R2-丙: 不通过 — B1 "main-reachable ≠ deployable" (counterexample 718b31a:
  main-reachable, not first-parent, known-unsafe intermediate — verified) and
  B2 seed-only `config.toml` wrongly inside the continuously-managed surface
  (verified: installer copies only when missing) — both `caused_by_last_fix:
  yes` → fixed in round-3 README text + the yaml above.

**Fix-Loop counter** (transcribed per protocol; attribution is the Reviewer's):
round-2→3 counts **1** (R2-丙: two Product blockings, `caused_by_last_fix:
yes`). streak = 1. One more attributed-yes round → hard stop, hand to human.

Round 3: [待定点复核 — 仅审 round-3 改动：README 两段的锚点/受管面收紧 +
上方 yaml 新增字段]

## Merge gate (identity chain; per R2-甲 M1 + R2-乙 V1/V2)

```yaml
sequence:
  1: round-3 re-review passes on the then-current branch tip
  2: human personally fills Human Approval Evidence below and commits it as
     "docs(approval): approve snapshot-first authority contract"
     (that commit may change ONLY the approval field)
  3: Author verifies <reviewed-tip>..<approval-tip> touches only the approval
     field, then reruns the FULL acceptance suite against <approval-tip>
  4: human merges <approval-tip> (never an earlier commit)
  5: post-merge close-out commit on main backfills the chain below
     (a record cannot self-reference its own commit)
chain:  # backfilled at close-out
  reviewed_semantic_tip: pending
  human_approval_tip: pending
  verification_tip: pending   # must equal human_approval_tip
  merge_tip: pending          # must equal human_approval_tip
  verification_result: pending
```

## Registered follow-ups

- PR0A fixture `verification-window-untracked-file` (git grep skips untracked
  files → zero matches must classify as incomplete evidence, never a pass).
- 母本 terminology unification at the next full README revision (R1-甲 N1).
- Validator drift check consumes `migration_overlay_grace` conversion at
  LOCAL-001 closure.

## Human Approval Evidence

[待人类一句话批准：谁/何时/批准了什么——快速版凭证；由人类亲自填写并单独
commit（见 Merge gate 第 2 步），Agent 不得代填]
