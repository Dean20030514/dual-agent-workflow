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
* git log 与当前 branch 的 diff / last_test_run.txt

## Work Log
倒序，每条一行：[日期] [Agent] [做了什么] [commit]

## Known Issues
无则 "None"。

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
