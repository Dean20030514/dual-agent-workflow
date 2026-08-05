# Clean fixture index

A valid relative link: [page](sub/page.md).
Dotted form: [page2](./sub/page.md).
An image: ![pic](../img/pic.png)
Anchor within target: [sec](sub/page.md#section-one)
Query suffix: [view](sub/page.md?view=1)
Pure anchor: [top](#clean-fixture-index)
External links: [site](https://example.com/x.md), [mail](mailto:someone@example.com)
Reference definition below.

[refdef]: sub/page.md

Tilde in inline code: `~/.codex/AGENTS.md` resolves via the mapping.
Tilde in prose: ~/.claude/rules/common/testing.md is deployed.
Machine-local stays unchecked: `~/.codex/config.toml` and `~/.claude/projects/demo/memory/MEMORY.md`.
Directory ref inline: `sub/` exists next to this file.

```
[fake](nope/missing.md) inside a fence is ignored
cp deployed ~/.claude/rules/common/testing.md
```

Inline fake link excluded: `[fake2](also/missing.md)`.

Registered managed pattern, all expansion targets present: `~/.claude/{rules,workflow,commands}`.
Registered machine-local pattern: ~/.claude/projects/*/memory is never checked.
Audited archive exceptions stay local-only: `~/.claude/workflow/archive/2026-07-30-guard-effectiveness-backup/ARCHIVE_NOTE.md` and `~/.claude/workflow/archive/**`.
