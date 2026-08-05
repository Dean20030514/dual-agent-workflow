# Broken fixture

Missing relative target: [missing](no/such.md)
Traversal escape: [escape](../../outside.md)
Unrecognized tilde in prose: ~/.claude/unknown/thing.md
Mapped tilde with missing target: `~/.claude/rules/common/gone.md`
Case mismatch: [case](Sub/Page.md)
Dot-slash in prose: ./missing-script.sh
Inline directory token: `nosuchdir/`
Known drift replica: `skills/`
Unclaimed weak token stays out: `exampledir/`

```bash
./install.sh typescript
```

Pattern-registry violations (full-token classification):
Brace typo of the managed pattern: `~/.claude/{rulez,workflow,commands}`
Wildcard typo in prose: ~/.claude/projects/*/memroy must not ride the prefix.
Unregistered brace: `~/.claude/{anything}`
Reviewer config pattern typo: `~/.codex/reviewer*.config.tmol`
Unknown wildcard: `~/.claude/unknown/*`
Registered pattern whose expansion targets are missing here: `~/.claude/{rules,workflow,commands}`
Archive path outside the audited exceptions: `~/.claude/workflow/archive/other/thing.md`
