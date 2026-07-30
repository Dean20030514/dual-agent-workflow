---
description: 探索完成后撰写正式实现计划。当需要把方向落成可批准的 IMPLEMENTATION_PLAN、并停下等人类批准时使用。
---

# Phase 2：正式规划（Author）

基于探索结果：
1. 归档旧 per-task 文件到 `docs/ai/archive/`。
2. 创建/增量更新 `AGENTS.md`(+`CLAUDE.md`)、`PRODUCT_BRIEF.md`（若 0.1 判为产品类）。
3. 创建 `TASK_BRIEF.md`（含 0.1 扫描）、`IMPLEMENTATION_PLAN.md`、`HANDOFF.md`（模板见 `docs/ai/templates/`）。
4. 不实现代码。计划最小化改动，必须有测试计划。
5. **Unknown 即 blocking**：进 Approval=Pending 前，任何"不确定会否引入妥协/破坏现有行为"都算 Unknown；标「唯一依据=是」的高影响假设未验证也算 Unknown。带 Unknown 的计划是草稿——必须在探索阶段查清，降为"确定不引入债 / 已写成 `[DEBT]` 明账"或"假设已验证/已降级"之一才能停 Pending；不允许把 Unknown 留到实现阶段边做边看。
6. `IMPLEMENTATION_PLAN.md` 的 Approval Status 写 Pending，停止，等人类批准。

输出：
* **Planning Files Created/Updated**
* **Recommended Plan Summary**
* **Files Planned for Modification**
* **Awaiting Approval**：提醒人类——检查计划 → `git add` 计划文件并 commit（该 commit 即批准凭证）→ Status 改 Approved → 通知 Author 开始 `/implement`。

> 长期规则（Safety / [DEBT] / 证据假设标签）见 `AGENTS.md`，无需在计划里复述。
