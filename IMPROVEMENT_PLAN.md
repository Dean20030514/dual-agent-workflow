# IMPROVEMENT_PLAN — dual-agent-workflow

Consensus baseline v1.1 · 2026-07-30
Status (2026-08-05): **REFERENCE ONLY** — Round 1 execution stopped by human adjudication (H5A sealed `stopped, NOT converged — over-engineered`; known drifts fixed directly; workflow minimized to five rules + three gates, see `docs/ai/HANDOFF.md`). Do not execute phases from this document without a fresh explicit human decision. The line below is the historical v1.1 status, preserved for the record.
Status: APPROVED FOR PLANNING INPUT (feed into `/plan`; each PR still goes through the normal Frozen Acceptance + Human Approval gate)
Changelog v1.0 → v1.1: integrates final-review items I-01..I-07 and non-blocking additions A, B (GPT-R6 review of v1.0, target `1ff8f6dc…` / blob `691ed4a5…`). No architectural decision reopened.

---

## 0. Provenance & Artifact Identity

Derived from the three-party review:

- **Claude-R1..R7** (external ecosystem harvest → per-item adjudication → forensic verification → dispute-list closure → v1.0/v1.1 authoring)
- **GPT-R1..R6** (repo-ground-truth audit → cross-verification → implementation constraints → v1.0 contract review)
- **Primary sources**: OpenAI Codex Configuration Reference (`developers.openai.com/codex/config-reference`), Claude Code docs (`code.claude.com/docs/en/memory`, `/debug-your-config`, `/hooks`), `openai/codex-plugin-cc`, `github/spec-kit`, arXiv:2602.11988, and the local master copy (`~/.claude/`, `~/.codex/`).

### Artifact identity protocol (I-01)

Every relayed or committed review artifact carries a **dual identity**:

```yaml
artifact_filename: IMPROVEMENT_PLAN.md
artifact_sha256_raw: <raw-byte SHA-256>      # transport identity
git_blob_oid:       <git hash-object OID>    # repository identity (LF-normalized)
source_commit:      <commit containing it>   # filled at commit time
encoding: UTF-8 (no BOM)
line_endings: LF
```

Rules:
- **Model-to-model transport**: verify the raw-byte SHA-256.
- **In-repo review**: bind to Git blob OID + commit SHA (Windows worktrees may carry CRLF; raw SHA of a checkout can legitimately differ from the committed blob).
- **Commit messages**: record identity as trailers, never in the subject line:

```text
Artifact-SHA256: <raw sha256>
Artifact-Git-Blob: <blob oid>
```

- Any critique must declare the identity of the artifact under review. Identity values for this file live in HANDOFF and the commit trailers, not embedded here (self-reference would invalidate them).

---

## 1. Scope & Batching

Two independent batches. **Do not mix them into one diff.**

| Batch | Name | Content | Risk profile |
|---|---|---|---|
| **H** | Repo Hygiene (Track A) | Governance + drift fixes. **No intended change to the dual-review protocol; some agent, installer, and CI behavior changes remain and require normal review** (I-02) | Low–moderate, mostly mechanical |
| **W** | Workflow Architecture (Track B) | PR0A → PR1 → PR2 → PR0B → PR3 | Behavioral; eval-gated |

Batch H ordering (I-02, breaks the H2↔H5 cycle):

```text
H5A (validator foundation)  →  H1 / H2 / H3 / H4 land against a green H5A
PR1 lands                   →  H5B (JSON Schema + example validation) activates
```

---

## 2. Batch H — Repo Hygiene (P0)

### H1 · License + Provenance Audit
Not "just add MIT". Steps:
1. **File-level** provenance inventory (I-03) — directories are mixed-origin (verbatim ECC files, heavily-modified ECC derivatives, fully original files, Anthropic/OpenAI-derived adaptations can coexist in one directory).
2. Choose a root license for original content.
3. Add `THIRD_PARTY_NOTICES.md` preserving upstream copyright + license notices (ECC is MIT; MIT requires notice retention in substantial copies). Do not re-license third-party content under the root license by omission.
4. Add machine-readable `PROVENANCE.yml`:

```yaml
entries:
  - paths: ["claude/rules/common/**"]
    upstream: {repository: "affaan-m/ECC", commit: "<pinned>", license: "MIT"}
    derivation: "modified"
    notice: "THIRD_PARTY_NOTICES.md#ecc"
  - paths: ["claude/workflow/**"]
    origin: "original"
    copyright_holder: "<your legal name>"
  - paths: ["claude/workflow/templates/REVIEW_OUTPUT.schema.json"]
    upstream: {repository: "openai/codex-plugin-cc", commit: "<pinned>", license: "Apache-2.0"}
    derivation: "adapted"
```

**Acceptance:** LICENSE + THIRD_PARTY_NOTICES.md + PROVENANCE.yml present; **every tracked file is covered by exactly one provenance rule; overlapping or uncovered rules fail validation** (H5A check).

### H2 · Rules Drift Fixes
1. `claude/rules/common/git-workflow.md`: delete `Push with -u`; replace with *"Prepare the exact push command for the human, but never execute remote operations."* (removes two contradictory instructions that can currently co-load in one session — note this **changes agent behavior by design**).
2. `claude/rules/README.md`: remove ghost references to `./install.sh` and the nonexistent `skills/` directory.
3. Decide and document the `extraKnownMarketplaces.ecc` residue: "kept for recovery convenience" or delete.

**Acceptance:** H5A reports zero registered-invariant violations and zero dangling path references.

### H3 · Installer Hardening (`install.ps1`)
Add parameters: `-ClaudeDir`, `-CodexDir`, `-NoPluginInstall`, `-DryRun`, `-ValidateOnly`. Post-install: verify deployed files and plugin state; emit a deployment summary instead of bare "Done". Keep default behavior backward-compatible.

### H4 · Plugin State Reproducibility
Ship **`plugins.resolved.json`** (I-04): the resolved plugin state of this machine — IDs, versions, sources, checksums — used by the validator to detect drift. Checksum scope = stable content only (`plugin manifest + commands/ + skills/ + hooks/ + scripts/`), excluding cache, logs, and generated state.

**Upgrade path:** rename to `plugins.lock.json` only when the installer can *restore* from it (new machine → install from lock → identical IDs, versions, sources, normalized content digests → validator green). Until restore capability exists, the name must not promise it.

### H5 · Validator + Minimal CI (split per I-02)

**H5A — Validator foundation** (no PR1 dependency):
- Markdown reference-path check (files referenced in README/rules exist)
- Plugin-list consistency across installer / README / `settings.json` / `plugins.resolved.json`
- **Registered policy invariants** (non-blocking item A): validator checks only deterministic, registered hard rules from `POLICY_INVARIANTS.yml` — not "all semantic conflicts", which stays a human-review responsibility:

```yaml
invariants:
  - id: remote-ops-human-only
    forbidden_agent_actions: [git push, git pull, git merge, git rebase, force-push]
  - id: reviewer-zero-repo-write
    forbidden_review_invocations: [direct-codex-exec-outside-runner, sandbox-cli-override]
```

- PowerShell parsing/static checks (PSScriptAnalyzer)
- Provenance manifest validation (PROVENANCE.yml coverage, exactly-one rule per file)
- Secret scan (Gitleaks)

**H5B — Schema lane** (activates after PR1): JSON Schema + example validation; schema/renderer sync check.

**Explicitly excluded:** CodeQL (no supported languages in this repo), Dependency Review (no package manifests), CONTRIBUTING/CoC boilerplate (personal master-copy repo, not a community project).

---

## 3. Batch W — Workflow Architecture

Dependency DAG (final, agreed):

```
PR0A ──▶ PR1 ──▶ PR2 ──▶ PR0B ──▶ PR3
```

### PR0A — Eval Contract + Baseline Fixtures
Define the eval harness **before any behavior change**; baseline the *current* Markdown workflow. No production changes in this PR.

Fixture set (minimum):
true Product Blocking · true Verification Blocking · Debt only · Suggestion only · 9B reads PLAN (isolation breach) · SHA/blob mismatch · ignored-verdict contamination · sandbox initialization failure · all commands blocked (`shell_policy_blocked`) · empty output · timeout · high-confidence hallucinated finding · `caused_by_last_fix` yes/no/dispute · tests not exercising the real production path · requirement without a corresponding test · same-input repeat run (determinism check — must execute a **real fresh call**, see C7).

**Two CI lanes** (non-blocking item B):

```text
offline-ci  (every PR, deterministic, no credentials):
  fixture parser · schema validator · renderer · fake Codex process ·
  timeout / empty-output / blocked-shell simulation · preflight/postflight logic ·
  profile-file validation

live-eval   (manual or controlled schedule, fixed budget):
  real models · manifests archived · never a required check on ordinary PRs
```

Deliverables: fixture files, expected verdicts, scoring rules, baseline scores, offline-ci Windows job.

### PR1 — Review JSON Schema v1 + Validator + Renderer
Pipeline: `Codex → strict JSON → schema validation → cross-field semantic validation → Markdown rendering (review_9A.md / review_9B.md) → Author reads only validated output`. JSON is the source of truth; Markdown is a render.

Adopt from `openai/codex-plugin-cc`: `severity` enum, `confidence` (0–1), `additionalProperties:false`. **Preserve all local semantics.** Determinism constraints from I-05:

1. **`review_verdict` is computed by the validator, not emitted by the model.** The model outputs evidence and findings only.

```text
run_status != success                                   → review_verdict = unavailable
run_status == success ∧ ≥1 product/verification blocking → needs_attention
run_status == success ∧ 0 blocking findings              → approve
```

Debt, Suggestion, and confidence values never alter this computation. Contradictory states ("approve" alongside a product-blocking finding) become structurally impossible.

2. **Frozen top-level enum; extensible detail layer.**

```text
run_status:  success | invalid_snapshot | execution_failed        (frozen in v1)
exit_class:  success | schema_invalid | sandbox_initialization_failed |
             shell_policy_blocked | timeout | empty_output |
             orphaned_process | mcp_hang | postflight_repo_mutated |
             execution_failed                                      (extensible)
```

3. **Location union — no fabricated line numbers.** Reviewer findings include snapshot pollution, HANDOFF/blob binding errors, plan-level gaps, untrusted test artifacts, repo-level config issues — none of which map to a line.

```json
{"location": {"kind": "file_line | file | artifact | repository",
              "file": "…", "line_start": 10, "line_end": 15, "artifact_section": null}}
```

Line numbers are required **only** when `kind = file_line`; mandating them everywhere induces hallucinated `line_start: 1`.

Field/control map (unchanged from v1.0):

| Field | Values | Controls |
|---|---|---|
| `run_status` | see frozen enum | `!= success` ⇒ verdict unavailable |
| `review_mode` | 9A \| 9B | dual-review bookkeeping |
| `review_verdict` | approve \| needs_attention \| unavailable | **derived by validator** |
| `findings[].blocking_class` | product \| verification \| none | **merge gate** |
| `findings[].caused_by_last_fix` | yes \| no \| dispute | **Fix-Loop counter** |
| `findings[].severity` | critical/high/medium/low | triage ordering |
| `findings[].confidence` | 0–1 | **ranking + human judgment only; never auto-controls merge or hard-stop** |
| SHA bindings | review_base_sha / review_tip_sha / handoff_snapshot_sha | snapshot binding |
| plus | six snapshot self-check evidence items, Cannot-Verify-From-Diff, Verification-Needed, Debt verdict, 9B Requirement-Level Concerns | existing protocol |

### PR2 — Reviewer Profiles + Single Runner + Run Manifest
One **atomic** change set (C1):
1. **Single Runner entry point** (I-06): all reviewer invocations flow `workflow runner → codex exec --profile <resolved-profile>`. Commands, templates, and README invoke the Runner only — nothing else assembles Codex arguments. The `reviewer-zero-repo-write` invariant (H5A) enforces this.
2. Deploy **three** profile files:

```toml
# ~/.codex/reviewer.config.toml            — the currently-selected default
# ~/.codex/reviewer-readonly.config.toml   — read-only candidate/final
# ~/.codex/reviewer-workspace-write.config.toml — Windows-compat fallback
```

```toml
# reviewer-workspace-write.config.toml (initial production baseline)
approval_policy = "never"
sandbox_mode    = "workspace-write"
[sandbox_workspace_write]
network_access = false
```

```toml
# reviewer-readonly.config.toml (promote after smoke)
approval_policy = "never"
sandbox_mode    = "read-only"
```

3. **Delete every hardcoded `--sandbox workspace-write`** from invocation commands, docs, and templates; validator greps for residue.
4. **Promotion mechanics** (I-06): promoting read-only to default updates only `reviewer.config.toml` (or the Runner's controlled selector) — never a repo-wide command replacement.
5. Runner writes a run manifest per review: `review_run_id`, `review_mode`, `input_fingerprint`, `prompt_sha256`, `schema_sha256`, `model_id`, `reasoning_effort`, `codex_cli_version`, `profile`, `profile_file_hash`, **effective resolved** `sandbox_mode`/`network_access` (C6), three SHAs, `exit_code`, `exit_class`, preflight/postflight block (C4), JSONL event stream.
6. **C6 acceptance criterion** (I-06): PR2 does not pass unless the Runner obtains the effective resolved configuration **from the Codex runtime itself**. Reading the TOML, recording the selected profile name, or copying intended values does not constitute C6 evidence. If no stable resolved-config interface exists:

```json
{"effective_config_verified": false, "sandbox_mode": "unknown", "network_access": "unknown"}
```

Such runs are valid reviews but **must not** be used as evidence for the read-only promotion decision.
7. **Cache semantics** (C7 / I-07): the v1.0 "idempotent reuse" is renamed **explicit successful-result cache**:

```text
Formal 9A/9B:   fresh run by default; no automatic verdict reuse
Process retry:  reuse only via explicit --reuse-successful, and only for
                run_status = success with a valid postflight
PR0B eval:      forced --no-cache; identical fixtures make real repeat calls
```

Fingerprint composition (minimum): review_mode · review_base_sha · review_tip_sha · handoff_snapshot_sha · HANDOFF blob SHA · last_test_run blob SHA · TASK_BRIEF/PLAN/QUALITY_GATES hashes · prompt SHA · schema SHA · validator version · renderer version · model ID · reasoning effort · Codex CLI version · profile-file hash · effective sandbox/network config · allowed-input policy. (Same code under a different prompt/profile/CLI must never hit the cache.)
8. Windows smoke tests for both sandbox profiles. **Promotion rule:** read-only becomes the default only after all Windows smoke fixtures pass **with `effective_config_verified: true`**.

### PR0B — Executable Eval Matrix
Wire PR0A fixtures into the real runner (live-eval lane, `--no-cache`). Comparison axes: current vs new workflow · workspace-write vs read-only · Markdown vs JSON output · prompt versions · native retrieval vs Serena · single review vs 9A+9B · cost / latency / blocking recall / false-positive rate.

### PR3 — Traceability Gate (after PR0B)
Stable IDs: `AC-xxx / NFR-xxx / TASK-xxx / TEST-xxx / PROD-xxx / VER-xxx`. New `/analyze` (or `/plan-check`) step between `/plan` and human approval, modeled on `github/spec-kit`: requirement→task coverage matrix, orphan detection both directions, ambiguity/duplication/underspecification checks, coverage % output, read-only, no auto-edits. Completes the chain: `requirement → plan task → implementation files → test → real-path evidence → reviewer finding`.

---

## 4. Hard Implementation Constraints

- **C1 · Atomic profile cutover + single entry.** Deployed profile + surviving hardcoded `--sandbox` flag = the most dangerous drift class (config looks locked, runtime never uses it). Explicit CLI sandbox flags can override inherited settings. Remedies: delete all hardcoded flags, route every invocation through the Runner, validator greps for residue and for `codex exec` outside the Runner.
- **C2 · Measurement tools are telemetry, not gates.** `/context` (startup context breakdown), `/memory` (which instruction files loaded), `/doctor` v2.1.206+ (CLAUDE.md trim proposals — documented for *checked-in* CLAUDE.md; equal treatment of `~/.claude/CLAUDE.md` must be smoke-tested, not assumed), `InstructionsLoaded` hook (`load_reason`: session_start / path_glob_match / nested_traversal / include / compact). InstructionsLoaded is async observation only — it cannot block or alter loading. Logging hygiene: off by default, path redaction option, size/rotation caps, no file bodies, never committed to the public repo, defined retention.
- **C3 · Never mix `default_permissions` with `sandbox_mode` / `[sandbox_workspace_write]`** (official constraint; built-ins `:read-only` / `:workspace` / `:danger-full-access`). Beta permission profiles are a *third experimental branch* later, not part of v1.
- **C4 · `postflight_repo_unchanged` is derived, never asserted.** Required evidence (pre + post): `head_sha`, `review_sensitive_tree_hash`, `worktree_porcelain_sha256`, `ignored_review_artifact_scan`. Judgment: pre HEAD == post HEAD ∧ review-sensitive content hash unchanged ∧ post `git status --porcelain` clean ∧ no new ignored verdict/raw-log/scratch files. Do **not** hash `.git/` wholesale (read-only git ops legitimately touch internal metadata); the proof target is repo content + worktree.
- **C5 · Holding outside the repo remains the first defense.** Postflight proof is the second detection layer, not a license for the reviewer to write and "check for residue later".
- **C6 · Record effective config, verified from the runtime.** Manifest sandbox/network fields must be echoed from the resolved runtime configuration. Unverifiable runs carry `effective_config_verified: false` and are excluded from promotion decisions.
- **C7 · Fresh-run default; explicit cache; eval never caches.** See PR2 §7.

---

## 5. Decision Log (all disputes resolved)

| # | Dispute | Resolution | Decided by |
|---|---|---|---|
| 1 | Reinstall Serena by default | No. Keep uninstalled; A/B in PR0B (token, retrieval accuracy, tool calls, latency) | Local master-copy record (uninstalled 2026-07-28) |
| 2 | Unconditional read-only on Windows | No. Smoke-gated read-only default; workspace-write + network off + postflight proof as fallback | Public Windows sandbox issues + local failure records |
| 3 | `[profiles.reviewer]` vs separate file | Separate `reviewer*.config.toml` files as the single source; selection via `--profile`; project-scoped `profile`/`profiles` keys are ignored by Codex | Official config reference |
| 4 | Stop-hook in the main dual-review loop | No. Sentinel-only end state (blocks once, prints the review command, never invokes a model); borrow runtime protections (reentry guard, PID identity, timeout-fails-closed, atomic state) | Dual-review isolation + Fix-Loop hard-stop design |
| 5 | Fix-Loop driven by severity+confidence | No. `blocking_class` gates merges; `caused_by_last_fix` drives Fix-Loop; confidence is advisory ranking only; verdict computed by validator | Workflow semantics + I-05 |
| 6 | 79 rules = full per-session load | No. `paths:` rules load on file match; slim target = global CLAUDE.md (~219 lines) + pathless common rules; measure with `/context` + `InstructionsLoaded` before cutting | Official Claude Code memory docs |
| 7 | "Just add LICENSE" | Upgraded to License + Provenance Audit with file-level PROVENANCE.yml (H1) | ECC MIT lineage + I-03 |

## 6. Adopted / Not Adopted / Deferred

**Adopt now:** eval harness (PR0A/PR0B) with offline-ci + live-eval lanes · JSON as review source of truth · validator-computed verdict · location union · run manifest with frozen run_status + extensible exit_class · single Runner entry · three profile files with atomic cutover · Windows dual-profile smoke · runtime-verified effective config · `/context` + `/memory` + `/doctor` + `InstructionsLoaded` measurement · derived postflight no-write proof · explicit-cache semantics · manifest before traceability · dual artifact identity (raw SHA + git blob OID).

**Do not adopt:** default Serena reinstall · model-invoking Stop-hook · wholesale rules→Skills migration · confidence-driven blocking or Fix-Loop · model-emitted verdicts · untested read-only as sole production path · mixing `default_permissions` with `sandbox_mode` · mandatory line numbers on non-line findings · automatic verdict reuse in formal reviews · CodeQL / Dependency Review / community-governance boilerplate for this repo.

**Deferred:** traceability gate (PR3) · sentinel hook · Serena A/B · beta permission-profile A/B · worktree parallelism (only on a real parallel-task need) · context-budget trim execution (after measurement) · `plugins.resolved.json` → `plugins.lock.json` upgrade (after restore capability).

## 7. First Implementation Round

**Scope:** Batch H in order H5A → (H1‖H2‖H3‖H4) → H5B-ready, plus PR0A + PR1 + PR2.

**Round-1 definition of done:**
1. H5A validator green in offline-ci; H1–H4 merged; PROVENANCE.yml covers every tracked file exactly once; `plugins.resolved.json` drift check active.
2. PR0A baseline scores recorded for the current Markdown workflow; offline-ci lane green on Windows.
3. PR1 schema + validator + renderer merged; verdict derivation and location union enforced; example passes; H5B activated; eval fixtures updated to expect JSON.
4. PR2: three profiles live, Runner is the only Codex entry, zero hardcoded `--sandbox` anywhere, manifests generated per review with runtime-verified effective config, Windows smoke results recorded, read-only promotion decision made **only** from `effective_config_verified: true` runs.

PR0B and PR3 enter planning only after Round 1 closes.
