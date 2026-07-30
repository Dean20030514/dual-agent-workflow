# Performance Optimization

## Model Selection — no-downgrade rule

**Sub-agents always inherit the main conversation's model.** Omit the `model` parameter when dispatching; never downgrade to a weaker model (haiku/sonnet/etc.), **even for mechanical tasks and even under cost pressure** (user rule, 2026-06-10). To cut cost, merge dispatch batches or trim prompts instead — never swap in a weaker model. Rationale: `~/.claude/workflow/workflow-design-notes.md`.

> This section previously assigned Haiku to "lightweight/worker agents" for cost savings. That directly contradicted the rule above and has been removed (2026-07-25).

Current model family, for reference only — **not** an allocation guide: **Claude 5** — Fable 5 (`claude-fable-5`), Opus 5 (`claude-opus-5`), Sonnet 5 (`claude-sonnet-5`), plus Haiku 4.5 (`claude-haiku-4-5-20251001`). When building AI applications, default to the latest and most capable models. Which model drives the main conversation is the human's choice in the client — the agent does not switch it.

## Context Window Management

Avoid last 20% of context window for:
- Large-scale refactoring
- Feature implementation spanning multiple files
- Debugging complex interactions

Lower context sensitivity tasks:
- Single-file edits
- Independent utility creation
- Documentation updates
- Simple bug fixes

## Extended Thinking + Plan Mode

Extended thinking is enabled by default, reserving up to 31,999 tokens for internal reasoning.

Control extended thinking via:
- **Toggle**: Option+T (macOS) / Alt+T (Windows/Linux)
- **Config**: Set `alwaysThinkingEnabled` in `~/.claude/settings.json`
- **Budget cap**: `export MAX_THINKING_TOKENS=10000`
- **Verbose mode**: Ctrl+O to see thinking output

For complex tasks requiring deep reasoning:
1. Ensure extended thinking is enabled (on by default)
2. Enable **Plan Mode** for structured approach
3. Use multiple critique rounds for thorough analysis
4. Use split role sub-agents for diverse perspectives

## Build Troubleshooting

If build fails:
1. Use **build-error-resolver** agent (availability & fallback: see [agents.md](agents.md))
2. Analyze error messages
3. Fix incrementally
4. Verify after each fix
