# IMPLEMENTATION_PLAN.md

> per-task 文件，Author 的正式实现计划。

## Goal
本次实现要达成什么（对齐 TASK_BRIEF；Goal 说目标，Summary 说做法）。

## Summary
推荐方案（多候选则简要比较为何选这个）。**选择标准 = 满足 Frozen Acceptance 的最小完整方案**——不选漏需求/会返工的偷懒小方案，也不为抽象/统一而扩大范围；**扩大架构须有证据并经人类批准**。

## Architectural Layers & Split Assessment
本任务触及的架构层（DB / core / API / CLI / GUI / 真实软件兼容）。**≥3 层 → 必做拆分评估 + 人类批准**：能否拆成有独立验收性质/独立测试/独立回退边界的切片？能拆则列切片；不宜拆则记理由请人类批准整体推进（非机械拒绝）。<3 层写 "N/A"。

## Frozen Acceptance（指针）
冻结验收的**唯一落点是 `TASK_BRIEF.md` → Acceptance Criteria**（review-sensitive；Author 自行改动使审查失效，人类裁决的 Amendment 例外见 AGENTS.md → 最后一轮独立审查门 ③）。本节只写指针与实现期需要注意的边界，不复述条款——本文件不在 review-sensitive 清单内，计划散文的修订不使审查失效。

## Current Architecture Understanding
当前项目结构与相关逻辑。

## Proposed Changes
逐文件：文件路径、改动类型(新增/修改/删除)、计划内容、原因、风险。

## Risks & Edge Cases
跨文件/系统级风险与边界（空值/越界/并发/超时/外部依赖失败/迁移/回归/兼容）。无则 "None"。

## Execution Steps
1. ...
2. ...

## Testing Plan
应运行的测试命令（必须真实存在）。

## Open Questions
无则 "None"。

## Human Approval Status
* Status: Pending
* Approved by: [人类填写]
* Date: [人类填写]

> 此字段任何 Agent 不得修改；Status 由人类批准时亲自改为 Approved——**先改 Status、再 commit**。批准正式凭证 = **内含 `Status: Approved` 的**人类 git commit（建议消息 `docs(plan): approve <task>`）。非 Approved 禁止进实现。
