# HANDOFF.md

> per-task 核心交接文件，每次 Agent 切换前更新。简短，证据指向 git log 和 last_test_run.txt。
> 下列每节都保留（无内容写 None/N/A）；Quality Gates 必须逐维度表格，不得用"已过所有闸门"一句话替代。

## Current Phase
Planning / Author Implementation / Independent Review / Final Review / Ready to Commit

## Task Summary
一两句。详情见 TASK_BRIEF.md。

## Source of Truth
* PRODUCT_BRIEF.md(如适用) / TASK_BRIEF.md / IMPLEMENTATION_PLAN.md
* Base branch / base commit：[Reviewer 按此审 diff]
* approval_commit_sha: [计划批准 commit 的 SHA（内含 Status: Approved）；Author 在批准后的下一次交接文档 commit 补录；快速版写 N/A——以 Human Approval Evidence 替代]
* git log 与当前 branch 的 diff / last_test_run.txt

## Review & Test Binding（SHA 绑定；final-review 收敛门与 Reviewer 读；语义见 AGENTS.md）
* review_base_sha: [Reviewer 审的 base commit]
* review_tip_sha:  [Reviewer verdict 绑定的确切 commit；**9A 与 9B 必须是同一个**]
* review_verdict_9A: [9A 对该 tip 的 Review Verdict] | verdict 文件: [docs/ai/review_9A.md]
* review_verdict_9B: [9B 对该 tip 的 Review Verdict；减档只跑 9A 则记 `N/A — 人类减档 + 原因`] | verdict 文件: [docs/ai/review_9B.md]
* tested_sha:      [last_test_run.txt 的测试所针对的 commit]
* guard_effectiveness: [声称「回归用例有效」时必填：产物路径 + 装置结论（契约见 AGENTS.md → 守护有效性装置）；未声称写 N/A]
* review_sensitive_paths: [本任务精确 pathspec，审查/测试共用，须能直接喂给 `git status/diff -- <pathspec>`；例 `src tests prisma package.json pnpm-lock.yaml docs/ai/TASK_BRIEF.md docs/ai/IMPLEMENTATION_PLAN.md docs/ai/QUALITY_GATES.md`]
* handoff_snapshot_sha: [审前 HANDOFF 快照 commit = 双审窗口开启时的 HEAD；写进两份 review prompt；**本行由 Author 在统一落账时填写**（快照 commit 无法自记自身 sha，见下方说明），落账后即 final-review 核验的权威来源]
> 有效性：需所有 review-sensitive 文件已入对应 commit、这些路径无未提交改动、无未跟踪文件（否则先形成 reviewable commit）。失效判定用**内容比对**（`review_sensitive_paths` 内容 vs `review_tip_sha`，及 vs `tested_sha`）、非 HEAD 相等；纯文档提交不使审查失效；**审后弱化测试 / 改验收标准 = 失效**。
> **两个 verdict 字段在两份 review 都产出后一次性填写**（双审窗口内本节与全文都不得改动；协议见 `reviewer-prompt.md` → 双审隔离协议）。
> **本文件与 `last_test_run.txt` 的快照 commit 在 `review_tip_sha` 之后**（它们不在 review_sensitive_paths 内）——故 Reviewer 必须从工作树读这两个文件，禁止 `git show <review_tip_sha>:docs/ai/HANDOFF.md`（会取到过期版）。该快照 commit 的 sha = `handoff_snapshot_sha`，由 Author 写进两份 review prompt（两份必须相同）；**本文件无法自记自身 commit**，故上方 `handoff_snapshot_sha` 行只能等统一落账时由 Author 补记——落账后 final-review 以该行（而非仓外 holding 的 prompt 文件）为权威核验来源。

## Runtime Identity（每轮记；取不到写 `unknown` / `not observable`，禁按昵称或表现推测；缺失不作交付 blocking）
* model ID: [实际 model ID，禁"Opus 5"这类昵称]
* CC 版本 / effort / dynamic-workflow? / compaction 发生?: [各填实测或 unknown/not observable]
* 本轮用过的 diagnostic probe（提交前须删 / 或已重写为正式 regression）: [列出或 None]

## Work Log
倒序，每条一行：[日期] [Agent] [做了什么] [commit]

## Known Issues
无则 "None"。

## Fix-Loop Counter（review-fix 循环用；无则 "None"）
每轮记一行：`[轮次] | 改了什么 | 本轮 Reviewer 判定的 blocking：[Product/Verification/ProcessDebt/Suggestion] + caused_by_last_fix(yes/no/dispute)`。
* streak（当前连续计数）: [数]
> 递增/重置/停止/轮次上限及其与合并门的优先级，**一律以 `AGENTS.md` → Fix-Loop 计数与跨轮硬停为准**（本模板不复述判据，避免与母本漂移）。**`caused_by_last_fix` 由 Reviewer 在其 verdict 判定；Author 只能逐字转录进本表（附 review 文件/轮次来源），不得自行判断或改写。**

## Remaining Risks / Debt
技术债唯一落点。无债写 "Debt: none"。格式（见 AGENTS.md）：
[DEBT] <description> | Payback trigger: <file/module> | Impact: <...>

## Quality Gates
对照 /define 0.1 标「关注」的维度 + 恒查安全基础，逐行：

| 维度/闸门 | 状态(Pass/N/A) | 证据文件或 N/A 原因 |
|---|---|---|
| 测试 QA(11.1) | | docs/ai/last_test_run.txt |
| 安全基础(11.2) | | |
| ...(按 0.1 关注维度逐行补) | | |

## Quick-Version Fields（快速版填，正式可省）
* Applicability Scan(0.1)：[关注/N/A + 原因]
* Human Approval Evidence：[人类一句话批准：谁/何时/批准了什么]

## Next Step
给下一个 Agent 或人类的明确动作。
