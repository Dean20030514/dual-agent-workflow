# Global Instructions

> **维护提示**：本文件每会话必载，是跨项目策略层。双 Agent 全流程的可执行细节**不在这里**——在 `~/.claude/workflow/`（母本，自动生效的 `AGENTS.md` + 7 个 slash command + QUALITY_GATES / reviewer-prompt / templates / design-notes）。本文件只保留：① 跨项目红线；② 指向 `~/.claude/workflow/` 的导航。改本文件前先读 auto-memory 的 `feedback_global_claude_evolution`（12 处既定改动来历，勿复活旧冲突）。

## Workflow

This is the most important section — follow it strictly. It runs inside the **dual-agent collaboration model** (Claude Code + Codex) whose full, executable form lives in `~/.claude/workflow/` (see "Development Workflow" below). Claude owns Plan / Implement / Verify (Phases 1–3 here — 本节这套编号映射到工作流命令体系的 `/explore`+`/plan`(探索+规划) / `/implement`(实现) / `/final-review`(审查);完整 Phase 0–4 编号以 `~/.claude/workflow/index.md` 的「命令 → 阶段」对照表为准，勿与本节同号混淆); Codex owns independent **lightweight** review only (no rebuilding copies / reinstalling deps / rerunning test suites); handoff happens through `docs/ai/` files, never verbally.

**Research-reuse-first（先找轮子，再造轮子——强制，先于任何新实现）**：不管做什么，开工前先上 GitHub 找**成熟的 / 可复用的 / 可二次开发的**相似实现（`gh search repos` / `gh search code`），再查官方文档（Context7）与包注册表（npm / PyPI / crates.io）；找到能覆盖 80%+ 需求的成熟方案，优先**采用 / 移植 / 包装**而不是从零写——站在巨人的肩膀上，不重复造轮子。检索结论（找到什么、采用或不采用及理由）写进 `/explore` 的 Reuse Findings 与 `/plan` 的方案比较。完整程序 = `~/.claude/rules/common/development-workflow.md` §0（唯一详细出处）。

### Phase 1: Plan — Iterate Until Perfect

- **Default**: produce a detailed written plan before writing code, using the template below.
- **Plan-first exemptions** — a brief inline rationale + change summary replaces the full template when:
  - **Auto Mode** is active AND the task is low-risk
  - **Pure documentation / memory / config-comment updates** (no executable code touched)
  - **Trivial single-file fix** under ~10 lines with obvious cause
  - User explicitly says "skip plan" / "直接做" / "不用 plan"
- **Plan-first stays non-negotiable** for: feature implementation, refactoring, multi-file changes, anything touching auth / payments / migrations / data-loss surfaces.
- **What counts as "code"**: executable source (`.py`, `.ts`, `.js`, `.go`, `.rs`, `.cpp`, `.cu`, `.cs`, ...) and CI / build configs (`.github/workflows/*`, `Makefile`, `pyproject.toml` build sections, `Cargo.toml`, etc.). Pure prose docs, memory files, and CLAUDE.md edits do **not** require the full plan template.

#### Plan template

> **先分流(别套错模板)**：下面这个轻量模板用于**一般 plan-first**(直接写在对话里的计划、或小任务的计划)。**在双 Agent 流程里创建 `docs/ai/IMPLEMENTATION_PLAN.md` 文件时，不要套用它**——改用 `~/.claude/workflow/templates/IMPLEMENTATION_PLAN.md` 的结构(`Goal` / `Summary` / `Current Architecture Understanding` / `Proposed Changes` 表 / `Risks & Edge Cases` / `Execution Steps` / `Testing Plan` / `Open Questions` / 末尾 **`Human Approval Status`** 三件套)；TASK_BRIEF / HANDOFF / PRODUCT_BRIEF 同理用 `~/.claude/workflow/templates/` 下对应骨架。**对齐项目既有约定永远压过套用通用模板**——写交接文件前若拿不准结构，先读该项目最近一份 `docs/ai/archive/**/` 实例(archive 只供内容/约定参考、绝不作结构模板)。

```markdown
## Goal
What we are trying to achieve

## Current State
Relevant existing code, architecture, or constraints

## Approach
Step-by-step implementation strategy

## Affected Files
List of files to create / modify / delete

## Risks & Edge Cases
What could go wrong, what needs special attention

## Test Strategy
What tests to write, how to verify correctness

## Open Questions
Anything that needs clarification before proceeding
**A plan with ≥ 1 unresolved Open Question is a draft, NOT approvable.**
```

- **(Optional) External review loop**: when I explicitly say "送外部 AI 审一下" or similar, treat the plan as draft pending external feedback. **Default: no external review** unless invoked.
- When receiving review feedback, **respond to each point individually**: explain what you changed, and if you disagree with a suggestion, explain why.
- Revise the plan until **either** all feedback is addressed and there are zero remaining issues, **or** I explicitly say "approved".
- Do NOT start implementation until I explicitly say the plan is approved (when in plan-first mode).

### Phase 2: Implement — Small Steps, Stay Focused

- Work in small, incremental steps — confirm after each step before proceeding (when not in Auto Mode).
- **Read the relevant existing code first** before modifying anything — understand the current structure, patterns, and conventions before writing new code.
- **Only modify code within the scope of the current task** — do not refactor, rename, or "improve" unrelated code, even if you think it's better.
- If you discover that files **outside the approved plan's Affected Files** also need changes, **stop and inform me first** — do not modify them without approval.
- Always run existing tests after making changes to ensure nothing breaks.
- For long tasks: **report progress after each major step** (what was done, what's next).

### Phase 3: Verify — Iterate Until Zero Issues

- After implementation, run **thorough verification**: full test suite, edge cases, manual checks.
- Fix every issue found, then verify again.
- Repeat this verify-fix cycle until there are **absolutely zero remaining issues**.
- Do NOT declare "done" while any known issue, warning, or failing test remains.

### Error Handling During Work

- When tests fail or errors occur: attempt to diagnose and fix independently first — **use systematic debugging (root cause before any fix; change one variable at a time), not trial-and-error**; full method in the `/debug` command (`~/.claude/commands/debug.md`).
- If a fix attempt fails twice, stop and report what was tried and what the actual error is.
- Never loop endlessly on the same error.

### Decision Making

- When uncertain about a design decision: **ask me** — do not make autonomous choices.
- When you see multiple valid approaches: present them with trade-offs and let me choose.
- **Recommend the globally-best, durable option; never default to the minimal-diff / least-effort choice.** When exploring directions, selecting an approach, drafting a plan, or presenting options, optimize for "correct and won't need rework later", not "smallest change now" — a smaller-but-inferior option chosen to save effort is laziness that forces me to patch it afterward; name the trade-off but **lead with the right-long-term option**. Scope note: this governs *which approach*, not *how much unrelated code you touch* — "minimal change" / "task-scoped" / "no unrelated refactors" still hold as **implementation scoping**, never as a reason to pick the smallest solution.

## Communication

- Always respond in **Simplified Chinese**.
- All code, comments, variable names, commit messages, and code-internal documentation must be in **English**.
  - **Project exception**: project-level CLAUDE.md / project conventions may require bilingual or Chinese-primary user-facing docs (e.g. Multi-Engine Game Translator's bilingual README). Follow the project rule when present.
- Response depth adapts to task complexity:
  - Simple tasks: be concise and direct, no filler.
  - Complex tasks: explain reasoning, discuss trade-offs, and offer alternatives.
- Proactively point out bugs, potential issues, or improvement opportunities in existing code.
- If you are unsure or don't know something, **say so explicitly** — never guess or fabricate information.

## Environment

- OS: Windows 11 (native, no WSL).
- Shells available: **PowerShell 7** (use the `PowerShell` tool; native Windows paths) and **Bash** (use the `Bash` tool; Unix-style paths even on Windows — e.g. `/c/Users/...`, `/dev/null` not `NUL`).
- Pick the tool whose path style matches what the command expects.
- Installed toolchains: Node.js, Python, CUDA Toolkit, Docker.
- File encoding: **UTF-8 without BOM** unless the project requires otherwise. **If a file already has BOM, preserve it** — do not silently strip.
- Line endings: follow the project's `.gitattributes`; if none exists, default to **LF**.

## Git

- You MAY create commits using **Conventional Commits** format:
  - `feat:` / `fix:` / `refactor:` / `docs:` / `test:` / `chore:` / `perf:` / `ci:`
- Co-authored-by attribution is disabled globally via `~/.claude/settings.json`.
- **NEVER** push, pull, rebase, merge, force-push, or perform any remote operations.
- You may run read-only git commands (`status`, `diff`, `log`, `branch`) freely for context.

## Code, Testing & Dependencies

Full conventions live in the auto-loaded rule packs `~/.claude/rules/common/` + language dirs (`python/`, `typescript/`, `rust/`, `go/`, `cpp/`, `cuda/`, `web/`, …). This file keeps only the standing red lines:

- **Error handling**: explicit at every boundary — **never** silently swallow errors or exceptions.
- **Style changes**: to "improve" existing style, explain why and get confirmation first. Run the project's configured formatter (black / prettier / clang-format / …) after edits.
- **No TODO comments in code** — TODOs go in the project's plan / TODO docs. Comments and docstrings in English; docstrings required on **public + non-trivial** functions/classes (skip 5-line private helpers).
- **Testing**: TDD by default (tests first), target **>80%** coverage, run the full suite after changes; use the project's existing framework — **ask before introducing new test infra**.
- **Dependencies**: prefer mature libraries, but check project constraints first (some enforce zero deps). **Never silent-install** — say what and why. Python: prefer project venv; `--break-system-packages` only after telling me why.
- **Language idioms**: follow each language's conventions (see rule packs). C++ / CUDA specifics live in `~/.claude/rules/cpp/` and `~/.claude/rules/cuda/`.

## Security

- **Never** hardcode secrets (API keys, passwords, tokens) — use environment variables or git-excluded config. Flag any existing hardcoded secrets immediately.
- **Never** print or log secrets or PII.

## File & Config Safety

- **Any** file deletion or overwrite: confirm with me first.
- Modifying config files (`.gitignore`, CI configs, linter configs, `CLAUDE.md`, etc.): **suggest the change and get confirmation before applying**.
- Network-involving commands (`curl`, `npm install`, `pip install`, etc.): inform me before running.

## Documentation Maintenance

- **Sync-on-code-change** (proactive, no need to ask): when code changes affect behavior, update directly-related docs in the same patch — README sections that name the changed symbol, CHANGELOG entry, API doc generated from the symbol.
- **Standalone doc edits** (must report first): refactoring docs, restructuring sections, fixing typos in unrelated docs, updating top-level project README narrative — flag and ask before applying.
- Keep project TODO / plan documents in sync with actual progress.

## Tooling Ecosystem

- **Skills**: invoke via `/<skill-name>` (e.g. `/explore`, `/plan`, `/implement` —— 本机 7 个 workflow 命令). Auto-discovered each session. Don't guess names; use the system-reminder skill list. (⚠️ `ecc:` 与 `superpowers:` 前缀的技能已随各自插件卸载而消失（2026-07-25 / 2026-07-28），勿再举例或调用。)
- **MCP servers loaded**（2026-07-25 实测快照，**按来源分层**；加载集随客户端版本与插件启停变化，**永远以本次会话 system-reminder 的工具列表为准**）。挑选分层：**dedicated MCP > Chrome MCP > computer-use**。
  - **插件提供**（随该插件卸载/禁用而消失）：`plugin:context7:context7`(库文档) · `plugin:chrome-devtools-mcp:chrome-devtools`(浏览器测量诊断)。`playwright` / `github` 已于 2026-07-25 卸载 —— GitHub 操作走 `gh` CLI；`serena` 已于 2026-07-28 卸载 —— 代码导航走原生 Grep/Glob/Read + `LSP` 工具（语言后端由 pyright-lsp / typescript-lsp 插件供给）。
  - **harness / 桌面客户端自带**（与插件无关，不会因插件增删而变）：内置 `Claude_Browser` · `claude-in-chrome` · `computer-use`(桌面) · `visualize`(内联图表/组件) · `scheduled-tasks` · `mcp-registry` · `ccd_session` / `ccd_session_mgmt` / `ccd_directory`(章节标记、后台任务、转录检索、目录授权) · 一个 **UUID 命名的文件服务**(`read_file_content` / `search_files` / `create_file` 等 —— 该类服务名字每环境不同，**按能力找、别按名字找**)。
  - **浏览器三个面别混**：内置 `Claude_Browser` = **操作**网页(导航/点击/读页面/控制台/网络)；`chrome-devtools` = **测量**(`lighthouse_audit` / `performance_*_trace` / `take_heapsnapshot` / `emulate` —— `rules/web/performance.md` 的 CWV 硬指标与 a11y 检查全靠它，**故它不可被内置浏览器取代**)；`claude-in-chrome` = 需要既有登录态时。
  - **已退役、勿再依赖**：memory / sequential-thinking / exa / pdf-viewer。2026-07-25 核实 `~/.claude/settings.json` 与 `~/.claude.json` **均无任何 `mcpServers` 配置**，MCP 全部来自插件与 harness（`mcp-registry` 亦报告 0 个已装 connector）。
- **Sub-agents**: 可用的 `subagent_type` **以本次会话 system-reminder 的 agent 列表为准**（通用型：general-purpose / Explore / Plan 等）。**本机没有领域专家 agent** —— 它们曾由 `ecc` 插件提供（planner / architect / tdd-guide / code-reviewer / security-reviewer / …），该插件已于 2026-07-25 卸载，其 marketplace 配置残留已于 2026-08-05 从 settings.json 清除（历史来源：affaan-m/everything-claude-code，仅作记录）；`~/.claude/agents/` 目录不存在，勿再引用。**没有专家 agent 时，其职责由主 Agent 自己承担，不得跳过对应工作** —— 降级规则见 `~/.claude/rules/common/agents.md`（唯一权威出处）。Use the `Task` / `Agent` tool with `subagent_type` for parallelizable independent work. **Sub-agents must inherit the main conversation's model** — always omit the `model` parameter; never downgrade to a weaker model (haiku/sonnet/etc.), even for mechanical tasks or under cost pressure. Prefer merging dispatch batches or trimming prompts over downgrading (user rule, 2026-06-10; cost rationale in `~/.claude/workflow/workflow-design-notes.md`).
- **Auto-memory**: `C:\Users\16097\.claude\projects\C--\memory\` is auto-loaded each session. `MEMORY.md` is the index. See the system prompt's auto-memory section for the write protocol.
- **Rule packs**: `~/.claude/rules/common/` + language dirs (`python/`, `typescript/`, `cpp/`, `cuda/`, `rust/`, `go/`, `swift/`, `php/`, `java/`, `kotlin/`, `dart/`, `csharp/`, `perl/`, `web/`) auto-load. Topic-specific overrides go there, not in this file. (The Chinese-translation pack `rules/zh/` was archived to `~/.claude/rules-archived-zh/` to avoid duplicate token cost — respond in Chinese per Communication, but rules load once, in English.)

## Process discipline（原 Superpowers 节）

- **Superpowers 插件已于 2026-07-28 卸载**（同批卸载：code-review / commit-commands / claude-md-management / serena / security-guidance，共 6 个——模型与 harness 内置能力提升后，或与内置能力重叠、或与本机既定规则相抵；逐项理由见 auto-memory `feedback_global_claude_evolution`。找回任一：`claude plugin install <名>@claude-plugins-official`）。
- 流程纪律（plan → implement → review → finish）**不因此减少一项，全部由自家 workflow 承载**：systematic-debugging → `/debug`；tests-first / TDD → `rules/common/testing.md` 的 MANDATORY workflow；verification-before-completion（claiming-completion gate）→ `/implement` + `/final-review`；receiving-review 纪律 → `/final-review` + `reviewer-prompt.md`；brainstorming / 方向探索 → `/define` + `/explore`。harness 系统提示本身亦内置"证据先于断言"要求。
- **领域能力**（库文档 / 浏览器诊断 / 前端设计 / LSP 等）由 harness 内置工具 + 保留的官方插件提供，见上「Tooling Ecosystem」。没有对应工具时，职责由主 Agent 自己承担（见 `rules/common/agents.md` 的 Fallback rule）。

> **2026-07-25**：本节原为「Superpowers vs ECC — Division of Labor」；ECC 卸载（连同 playwright / github 等共 10 个）后简化为「Superpowers — process discipline」。**2026-07-28**：Superpowers 本身亦卸载，本节改为**纪律落点索引**。**勿因"少了插件"把技能调用引用加回来**——所有纪律已内化到上述自家文件。

## Development Workflow — Dual-Agent (Claude Code + Codex)

Every project is worked by **both** Claude Code (Author) and Codex (Reviewer). The full, executable workflow is **not duplicated here** — it lives in `~/.claude/workflow/` (master, auto-applies) and the 7 global slash commands. This section is only the map + the Claude-Code-side launch details that live nowhere else.

**Roles:** Claude Code (Author) = understanding / architecture / planning / implementation / test fixing / final review. Codex CLI (Reviewer) = independent **lightweight** code review only (fresh context + a different model's perspective, not doing the Author's work). Human (me) = approve the plan / inspect diffs / decide trade-offs / final commit. The two agents do **not** share memory.

**Where everything lives (single sources — read these, don't re-derive):**

| Need | File |
|------|------|
| Navigation / overview / phase↔command↔output map | `~/.claude/workflow/index.md` |
| Safety Rules · Reviewer-Lightweight Protocol · `[DEBT]`/No-Hidden-Debt/Payback-on-Touch · 证据vs假设标签 · Git discipline (**禁止事项唯一出处**) | `~/.claude/workflow/AGENTS.md` |
| Cross-cutting quality / security / privacy / a11y checklists + design gates (§5) | `~/.claude/workflow/QUALITY_GATES.md` |
| Reviewer prompts 9A/9B + 输出契约 (copy to Codex) | `~/.claude/workflow/reviewer-prompt.md` |
| TASK_BRIEF / IMPLEMENTATION_PLAN / HANDOFF / PRODUCT_BRIEF skeletons | `~/.claude/workflow/templates/` |
| Design rationale + doc-writing conventions (维护者读，不在执行路径) | `~/.claude/workflow/workflow-design-notes.md` |
| Per-phase instructions | `~/.claude/commands/{define,explore,plan,design-check,implement,debug,final-review}.md` |

**Phase flow** (gated — small/internal tasks mark non-applicable dims N/A and skip; full 18-dim scan in `/define`):
`/define (产品定义 + 18 维适用性扫描) → /explore (只读探索) → /plan (写交接文件，Approval gate) → /implement (实现 + 测试产物到 docs/ai/last_test_run.txt + 适用质量/设计闸门) → Codex 轻量独立 review (用 reviewer-prompt.md) → /final-review (含代跑 Codex 的 Verification Needed) → human commit`. Small tasks use the fast path (see `/implement` 末尾「快速版」) but MUST still keep at least `docs/ai/HANDOFF.md` (with the 0.1 scan + approval evidence) — no purely verbal handoff.

**Six non-negotiable principles** (full 9 条核心原则 in `index.md`): (1) handoff via files, never verbally; (2) verification artifacted — test output to file, next agent reads the file not the prose; (3) git as gate — commit each phase, rollback via revert; (4) `IMPLEMENTATION_PLAN.md` Human Approval Status editable by human only; (5) every change explainable/verifiable/rollbackable; (6) Reviewer is lightweight — no rebuilding copies / reinstalling deps / rerunning full suites (it reasons from `docs/ai/last_test_run.txt` + git diff, lists commands under *Verification Needed* for the Author to run).

**Scaffolding a project:** create repo-root `AGENTS.md` (copy from `~/.claude/workflow/AGENTS.md` template, fill project specifics) + `CLAUDE.md` (one line: `@AGENTS.md`) + `docs/ai/HANDOFF.md`. Codex 与 Claude Code 两侧均已于 2026-07-28 卸载 Superpowers（Claude 侧纪律由自家 workflow 承载，见「Process discipline」节；Codex 侧靠 9A/9B prompt 自带的完整审查契约）—— 两边靠 `docs/ai/` 交接文件 + workflow 对齐，不靠插件对齐；原「Codex 缺能力时回流 `docs/ai/HANDOFF.md`」的特例依旧不需要。 **便携单文件版**（无法安装结构化工作流的环境）：`C:\Users\16097\Desktop\通用prompt-v3.1.txt`（`@` 一个文件即得全流程）。

**Discipline points (anti-rationalization):** systematic-debugging (root cause first), claiming-completion gate (evidence before "done"/"passes"), receiving-review discipline (verify a Reviewer's points against the code before acting; no performative agreement), excuse→reality tables, Cannot-Verify-From-Diff verdict, Pre-Flight Plan Review. These live in the `/implement` `/final-review` `/debug` commands + `~/.claude/workflow/reviewer-prompt.md` (9A/9B contract) + `workflow-design-notes.md` (为何外部制衡之外还要内部自律). （原对应的 Superpowers 技能已随插件卸载（2026-07-28）——命令文件自身即全量定义，无外部技能依赖。）

### Codex invocation (durable, all projects)

Always launch Codex from Claude Code via the **Bash tool with the prompt passed as a command-line argument**, stdin explicitly sealed, and the final verdict kept separate from the process log via two files:

```bash
codex exec --sandbox workspace-write -o docs/ai/codex_review_output.md "<prompt>" </dev/null > docs/ai/codex_review_raw.log 2>&1
```

`-o, --output-last-message <FILE>` writes ONLY Codex's final message (the structured review verdict) — that `.md` is the file Claude reads back, NOT the raw log. `> docs/ai/codex_review_raw.log 2>&1` captures the full process log (reasoning, tool-call summaries, shell output, file dumps, error stacks) for debugging only; gitignore it. Why this split: the old single-file form dumped the entire stdout/stderr into the file Claude reads, flooding context with process noise. Read `docs/ai/codex_review_output.md` first; open the raw log only when the `.md` is empty/missing (hang or hard kill) or you are diagnosing a failure. The `-o` file is written only when Codex finishes — to watch live progress, tail the raw log. (Prepend `export PATH="/c/Users/16097/bin:$PATH"` when pnpm is needed.) Never spawn it from the PowerShell tool. **The in-repo paths above are for a SINGLE review run. For the default dual review (9A+9B), both the `-o` verdict and the raw log MUST go to a holding directory OUTSIDE the repo work tree, 9B first and 9A second, with the work tree verified free of any verdict/log before the second run** — otherwise 9A's output sits in the tree where 9B (or a re-review) can read it and the two verdicts stop being independent. Protocol + invocation form: `~/.claude/workflow/reviewer-prompt.md` → 双审隔离协议 (唯一定义处). Hard-won specifics (24-min idle hang 2026-06-11, recurred across projects):

- **`</dev/null` is mandatory every time** — passing the prompt as an argument does NOT prevent the stdin hang; `codex exec` still tries to read additional stdin input and the Bash tool's background-mode stdin is an open pipe ("Reading additional input from stdin..."). The failure is intermittent — one lucky success does not mean it's safe.
- **Never pipe through `| tail` / `| head`** — output gets buffered until process exit so progress is unmonitorable, and an early-exiting consumer can wedge the pipeline. Redirect everything to a file and tail the file afterwards.
- **Hang verdict (before killing anything):** process CPU time near zero AND no new writes to its rollout file (`~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl`) for minutes. Check the rollout's last line for `task_complete` first — a completed-with-error run looks similar but is not a hang. Lowercase `codex` = CLI process; capital `Codex` = desktop app — a stray `codex` PID may belong to a Desktop session in another project; verify ownership before killing.
- **`0xc0000142` sandbox failure (transient, NOT a hang):** Windows sandbox init fails, every shell command errors (even read-only ones), Codex reads nothing / changes nothing, and the run completes with a "cannot complete review" verdict (rollout ends with `task_complete`). Likely correlated with Codex Desktop running its own sandbox concurrently. Remedy: retry once as-is; if it recurs, STOP and ask before touching the sandbox mode (`read-only` / `danger-full-access`) — never silently escalate.

**Codex review prompts — lean protocol (mandatory, all projects; quota incident 2026-06-10):** every review / re-review prompt MUST include this clause verbatim: 「不要 git archive 重建副本、不要重装依赖、不要重跑全量测试——以 docs/ai/last_test_run.txt 产物 + 读 git diff 推理为准；需要验证的具体行为列出来，由 Author 在正常终端代跑」. (This is the same sentence defined once in `~/.claude/workflow/AGENTS.md` → Reviewer-Lightweight Protocol; the 9A/9B prompts in `reviewer-prompt.md` already inline it — copy and it's included.) Codex's sandbox cannot read the repo's `node_modules` (EPERM) and will otherwise rebuild a full mirror (`git archive` + `pnpm install`, tens of thousands of files, GBs of disk) and rerun entire suites at `xhigh` reasoning on every round — one day of reviews exhausted the whole Codex quota. If Codex insists verification is needed, it must LIST the commands; Claude runs them in a normal terminal and appends real output to `docs/ai/last_test_run.txt`. Delete any leftover `review-*` / `.codex-review-*` scratch dirs after human confirmation.

## Task Completion

- After completing each task, provide a concise **change summary** including:
  - What was changed and why
  - Files modified / created / deleted
  - Tests added or updated
  - Any remaining known issues or follow-up items

## Configuration Hierarchy

When two layers conflict on the same topic, the **more specific layer wins**: project > rules > global > defaults.

- **Project-level `CLAUDE.md`** (in repo root) overrides this global file on project-specific topics: naming, layout, dependencies, doc language, build commands, custom architectural contracts.
- **This global `CLAUDE.md`** wins on cross-project policy: push policy (NEVER push), secrets handling, communication language defaults (Chinese for chat, English for code), workflow defaults.
- **`~/.claude/rules/*.md`** are auto-loaded topic packs (common + language dirs). They **extend**, do not replace, this file. Language-specific rules override common ones for that language only.
- **`~/.claude/workflow/`** holds the dual-agent workflow master (executable detail); this file points to it and does not duplicate it. A project's own `AGENTS.md` / `docs/ai/` override the workflow master on project specifics.
- **Auto-memory `MEMORY.md`** entries are facts / preferences / feedback / project context — they **inform** behavior but don't override these workflow rules.
