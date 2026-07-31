# Migration Evidence Index — snapshot-first authority migration (2026-07-30)

Versioned, **byte-exact archival** copies of migration evidence that previously
existed only as single-copy live files under `~/.claude/workflow/archive/` (a
path the current installer's mirror-replace deletes in place). Preserved BEFORE
any merge/deploy action: evidence preservation is the first protection layer;
the installer guard and future H3 keep-local-only protection are the second.

**Location rationale**: this set lives under `docs/ai/archive/**` so that
canonical uniqueness/reference scanners (which exclude archives) never ingest
historical snapshots as active policy. These files are historical evidence,
not active rules.

**Publication note (not content-sanitized)**: `pre/` and `post/` are verbatim
snapshots of managed config files whose current versions are already published
in this repo's `claude/` and `codex/` trees; the two `reviewer-prompt.md`
snapshots contain the same local tool paths that the published active file
(`claude/workflow/reviewer-prompt.md`) and `claude/CLAUDE.md` already contain —
no new exposure category. The one file whose entire content was absolute local
paths (`mapping.txt`) was removed and replaced by repo-relative
`change-budget-2026-07-30/MAPPING.md`, which records the original's sha256.
No credentials, tokens, auto-memory, or out-of-repo raw logs are included.
Final publication call rests with the human at branch-merge review.

## Identity conventions (normative for all evidence in this tree)

Four distinct identity values — never conflate, always label which one a claim
uses:

| name                | definition                                                        |
|---------------------|-------------------------------------------------------------------|
| `repo_blob_oid`     | blob OID recorded in a git commit/tree                            |
| `live_raw_sha256`   | SHA-256 of the live file's raw bytes (transport identity)         |
| `live_raw_blob_oid` | `git hash-object --no-filters` of the live file (byte identity)   |
| `live_lf_blob_oid`  | blob OID after normalization `eol-lf-v1`, then git blob hashing   |

Byte identity MUST use `--no-filters`: bare `git hash-object` silently applies
`.gitattributes`/autocrlf eol filters and reports LF-normalized identity.

```yaml
normalization:
  id: eol-lf-v1
  crlf_to_lf: true
  lone_cr_to_lf: true
  preserve_final_newline: true
  trim_trailing_whitespace: false
  unicode_normalization: none
  bom_removal: false
consumption_rule: >
  Any consumer of manifest/list files MUST strip trailing \r from each field
  (or normalize per a declared parse spec) before use. Observed failure mode:
  pre-sha256.txt is CRLF; filenames carried \r and produced 10 false MISMATCHes
  on first verification. Validator and H3 verification code inherit this rule.
```

## Scanner scope contract (requirement for H5A planning)

```yaml
active_policy_scope:  { exclude: ["docs/ai/archive/**"] }        # incl. this tree
secret_scan_scope:    { include: ["docs/ai/archive/**"] }        # evidence is scanned
provenance_scope:     { include: "every tracked evidence file" }
reference_check_scope: { targets: "current active docs only" }
```

## Inventory freeze (LOCAL-DELTA-2026-07-30T160241-0700)

```yaml
inventory_id: LOCAL-DELTA-2026-07-30T160241-0700
frozen_at_local: "2026-07-30 16:02:41 -0700"
candidate_snapshot_commit: 62b07d1   # merged into main fast-forward 2026-07-30
canonical_rebind_commit: f2273cb     # commit the inventory rebind ran against (62b07d1 ff → e058de1 guard no-ff → f2273cb evidence squash)
canonical_rebind_tree: 87908df8785b19fe534135afa5b355512a38d81a   # the tree is the authoritative anchor; commits are readable pointers
closeout_commit: 119e20a             # docs-only close-out; deploy surface unchanged
deploy_surface_changed_after_rebind: false
rebinding_result: exact              # deploy surface byte-identical between 62b07d1 and main; three approval-protocol anchors verified unique on main
gc_anchor: evidence-original-682324d # local-only lightweight tag pinning commit 682324d (pre-removal mapping.txt provenance); NEVER push; future validator drift checks should assert liveness via `git cat-file -e 682324d^{commit}`
result_summary: "10 content / 78 eol_only / 11 identical / 1 no_live_counterpart / 0 live-only strays (100 files)"
content_delta_set: LOCAL-001         # exactly ten files; see manifest below
raw_private_evidence:                # machine-local file, referenced by hash only
  file: LOCAL_DELTA_INVENTORY_freeze.txt (local scratchpad, absolute paths + mtimes)
  sha256: f501eafd85461507144dc306a93d8ac27cb21f89bb66aca3adb71f1a974a7a5d
private_bundle:                      # durable off-repo backup of the provenance branch
  file: ~/Documents/private-evidence/change-budget-evidence-2026-07-30.bundle (machine-local; never enters the repo)
  sha256: 5E8D4E48D460D628A7A643C0ACA8413E879EAA48529B2142C79B40678ADC2EBE
  contains: refs/heads/docs/evidence-preservation @ c2165df, complete history incl. 682324d
  verified: git bundle verify OK, 2026-07-30 (human-run)
handshake: "recomputed post-freeze: 11/11 lf-blob equal (content handshake)"
moratorium: "MORATORIUM-LOCAL-001 closed 2026-07-30 — report #1 hash-verified; all other master-side sessions confirmed closed by the human"
```

Full-surface manifest (repo-relative paths only):
`DEPLOY_SURFACE_MANIFEST-2026-07-30.txt`

## change-budget-2026-07-30/ — pre/post evidence chain (LOCAL-001 source)

Byte-exact copies (scoped `.gitattributes` `* -text` prevents eol rewriting;
staged-blob == `--no-filters` source verified) of
`~/.claude/workflow/archive/2026-07-30-change-budget-backup/`:

- `pre/`  — the ten managed files BEFORE the change-budget batch (frozen 11:00)
- `post/` — the ten files as left by the unreviewed subtask A implementation
  (15:35); live state equals `post/` 10/10 by raw sha256 at verification time
- `pre-sha256.txt`, `post-sha256.txt` — the backup's own manifests (CRLF;
  apply the consumption_rule above)
- `MAPPING.md` — repo-relative mapping; records the removed original
  mapping.txt's sha256

Copy fidelity: every copied file matches its manifest hash (pre 10/10,
post 10/10).

Consumers: the LOCAL-001 selective-promotion task (`finalize / register_debt /
reject / defer` per hunk) uses `pre/`→`post/` as the candidate-change source
and must protect the three canonical anchors from the approval-protocol patch
(candidate commit 62b07d1): the full Awaiting-Approval order, the
"Status first, commit second" template footer, and `approval_commit_sha`.
