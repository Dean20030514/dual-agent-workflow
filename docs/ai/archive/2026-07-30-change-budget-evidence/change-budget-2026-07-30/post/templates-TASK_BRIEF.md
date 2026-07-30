# TASK_BRIEF.md

> per-task 文件，blind review 的唯一需求依据，必须自洽：只看此文件应能判断实现对不对。

## Dimension Applicability Scan
粘贴 /define 0.1 的 18 维结果（关注/N/A + 原因）。

## Original Request
[粘贴或总结用户原始需求]

## Goal
本次任务最终要达成什么。

## Non-Goals
明确哪些不做。

## Constraints
限制条件。

## Acceptance Criteria
可验证（具体测试命令 + 预期结果）。本字段是验收条件的单一事实源。

## Change Budget & Allowed Paths（预算唯一事实源；9B 可见；语义见 workflow/AGENTS.md → 改动面预算）
批准后的预算只定义在本节，**自包含、不外链 PLAN**（9B 禁读 PLAN）；PLAN 只解释实施方式，HANDOFF 只记消耗与偏差。
* 允许 pathspec（白名单，**逐项列出**，每项可直接喂 `git status/diff -- <pathspec>`；**标准流程产物清单须逐项列入**——起草义务见 AGENTS → 改动面预算）：[白名单外任何改动 = 审查不通过]
* 生产文件/模块清单：[逐项]
* 公共接口变化：[默认 零；有则逐项]
* 触及架构层：[列层]
* 依赖 / lockfile / 迁移变化：[默认 零]
* 生产代码 LOC 量级（**仅预警**，非质量判据）：[量级]
* 收敛预算阈值：[默认 3 个有效且未收敛的任务审查轮；计数口径见 AGENTS 唯一定义处]

## Threat Model（威胁模型定界；安全类审查要求的解释边界）
[本任务的信任边界与风险面。超出定界的可选加固默认记入 Non-Blocking Suggestions 交人类；仍可判 Blocking 的五项例外见 workflow/AGENTS.md → 改动面预算 → 威胁模型定界。]

## Relevant User Preferences
如 不夹带无关改动 / 输出中文说明 / 不要大规模重构。
