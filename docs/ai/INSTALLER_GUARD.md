# Installer emergency guard — process record (G3)

> Versioned process record for the `chore/installer-guard` branch (equivalent
> of a task HANDOFF for this narrow emergency fix; kept separate from
> `docs/ai/HANDOFF.md` to avoid rewriting a closed task's records).

## Debt registration

[DEBT] Emergency installer acknowledgement guard intentionally disables the
legacy no-argument install path until H3 implements real DryRun/ValidateOnly
and plugin-step controls | Payback trigger: H3, or the next modification to
install.ps1, whichever comes first | Impact: the documented legacy one-click
install command fails by design (README discloses this); the guard must not
become a permanent substitute for safe deployment semantics.

## Approved deviation record

```yaml
approved_deviation:
  from: "IMPROVEMENT_PLAN v1.1 — PR0A defines the eval harness before workflow behavior changes"
  change:
    - approval-protocol correction (candidate commit 62b07d1)
    - emergency installer guard (718b31a + d526ff1 + this record's commit)
  justification: "correctness fix and destructive-operation safety fix could not wait for the harness"
  baseline_preservation: workflow-baseline-pre-snapshot-first-2026-07-30 (annotated tag on pre-migration main, enables retrospective PR0A baseline)
  human_approval:
    status: approved
    approved_by: Yanxiao Zheng
    approved_at: 2026-07-30
    evidence: >
      merge commit e058de1 — created by the human with --no-ff, carrying the
      Approved-Deviation and Installer-Guard-Debt trailers; 62b07d1 landed by
      human fast-forward the same day (Author transcribed this record post-merge;
      the durable evidence is the merge commit itself, not this transcription).
      The [DEBT] above stays active until H3 or the next install.ps1 touch.
```

## Guard behavior evidence (2026-07-30, PowerShell 7 `-File` invocation)

| # | invocation                                        | result                             | exit | side effects |
|---|---------------------------------------------------|------------------------------------|------|--------------|
| 1 | (no arguments)                                    | guard throw                        | 1    | none         |
| 2 | `-DryRun`                                         | binding error (unknown parameter)  | 1    | none         |
| 3 | `-DryRun -IUnderstandThisReplacesLiveConfig`      | binding error (bypass closed)      | 1    | none         |
| 4 | `-ValidateOnly -IUnderstandThisReplacesLiveConfig`| binding error                      | 1    | none         |
| 5 | `-DyrRun -IUnderstandThisReplacesLiveConfig`      | binding error (typo caught)        | 1    | none         |
| 6 | `DryRun -IUnderstandThisReplacesLiveConfig`       | binding error (positional caught)  | 1    | none         |
| 7 | `-IUnderstandThisReplacesLiveConfig:$false`       | guard throw (false ≠ acknowledged) | 1    | none         |

Side-effect proof for all rows: no new `*.bak-*` under `~/.claude` or
`~/.codex`, no `installing plugin` output, and the 11-file deployment-surface
blob handshake unchanged. Rows 6–7 required no code change: `[CmdletBinding()]`
rejects positional arguments at binding time, and an explicit `:$false` switch
falls through to the guard throw. The positive path (`-IUnderstandThisReplacesLiveConfig`
alone) is intentionally unexecuted: the plugin step (`claude plugin install` ×5)
performs real network installs and is not scoped by `USERPROFILE`, so no
sandboxed positive test exists before H3.

## H3 inheritance requirements (the guard is temporary; these are not)

1. Keep `[CmdletBinding()]` (or stricter) on the real H3 param block — the
   pre-fix bypass (`-DryRun -IUnderstandThisReplacesLiveConfig` deployed for
   real with `-DryRun` silently in `$args`) must stay structurally impossible.
2. Convert the 7-row rejection matrix above into Pester regression tests that
   survive guard removal.
3. Make the plugin step testable offline via a fake `claude` CLI shim on PATH
   (records arguments, exits 0) — same pattern as the offline-ci fake-Codex
   process; real network installs only in the live channel.
4. Dry-run/validate must cover the plugin step, honor a closed keep-local-only
   whitelist (credentials, auth/session state, private memory, settings.local,
   existing config.toml, local evidence archives), and decide the fate of
   `~/.claude/workflow/archive/**` (mirror-replace currently deletes it in place).
5. Remove the guard and this record's debt entry in the same change that lands
   the real controls (Payback-on-Touch).
