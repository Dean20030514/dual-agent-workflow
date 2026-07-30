---
description: 探索完成后撰写正式实现计划。当需要把方向落成可批准的 IMPLEMENTATION_PLAN、并停下等人类批准时使用。
---

# Phase 2：正式规划（Author）

基于探索结果：
1. 归档旧 per-task 文件到 `docs/ai/archive/`。
2. 创建/增量更新 `AGENTS.md`(+`CLAUDE.md`)、`PRODUCT_BRIEF.md`（若 0.1 判为产品类）。
3. 创建 `TASK_BRIEF.md`（含 0.1 扫描）、`IMPLEMENTATION_PLAN.md`、`HANDOFF.md`。**一律按 `~/.claude/workflow/templates/` 的 canonical 骨架建（结构按此抄）；archive 最近实例只供内容/项目约定参考，绝不作结构模板（这是模板漂移根源）。** 同时从 `~/.claude/workflow/QUALITY_GATES.md` 把质量清单 scaffold 进 `docs/ai/QUALITY_GATES.md`（供 Reviewer 独立读），项目已有则跳过。
4. 不实现代码。计划采用**满足 Frozen Acceptance 的最小完整方案**——既不选漏需求/会返工的偷懒小方案，也不为抽象/统一而扩大范围；**扩大架构必须有证据且经人类批准**（反的是"偷懒选差方案"，不是"越大越好"）。「最小」约束**实现范围**（不夹带无关改动/重构）。必须有测试计划（命令须真实存在）。**计划自检**：通读确保无自相矛盾步骤、无与 TASK_BRIEF 验收冲突、无"计划要求但会被 Reviewer 判缺陷"处——让实现期 `/implement` 的 Pre-Flight 能一次通过。
   * **架构层拆分评估（触发式，非机械拒绝）**：任务同时涉及 **≥3 架构层**（DB / core / API / CLI / GUI / 真实软件兼容）→ **必须做拆分评估 + 请人类批准**。判据 = 能否拆成**有独立验收性质 / 独立测试 / 独立回退边界**的切片；能拆则拆成独立可交付切片；确属正常纵向功能不宜拆的，在计划里记理由、请人类批准整体推进——**不按层数机械拒绝**。
   * **冻结验收标准（改实现前）**：在 `IMPLEMENTATION_PLAN.md` 的 `Frozen Acceptance` 节先列 要成立的性质 / 适用范围 / 明确例外 / 正反案例 / 边界 / 必经真实路径，**来源 TASK_BRIEF·接口契约·批准计划·人工确认，禁从当前实现反推**。
5. **Unknown 即 blocking**：进 Approval=Pending 前，任何"不确定会否引入妥协/破坏现有行为"都算 Unknown；标「唯一依据=是」的高影响假设未验证也算 Unknown。带 Unknown 的计划是草稿——必须在探索阶段查清，降为"确定不引入债 / 已写成 `[DEBT]` 明账"或"假设已验证/已降级"之一才能停 Pending；不允许把 Unknown 留到实现阶段边做边看。
6. `IMPLEMENTATION_PLAN.md` 的 Approval Status 写 Pending，停止，等人类批准。

输出：
* **Planning Files Created/Updated**
* **Recommended Plan Summary**
* **Files Planned for Modification**
* **Awaiting Approval**：提醒人类——审阅计划 → **先**由人类亲自在 `IMPLEMENTATION_PLAN.md` 填 `Status: Approved / Approved by / Date` → **再** `git add` 本阶段创建/更新的**全部规划产物**（不止计划文件）并创建批准 commit（建议消息 `docs(plan): approve <task>`；Approved 状态因此在批准 commit 内、工作树干净；该 commit 即批准凭证）→ 之后才允许开始 `/implement`。批准 commit SHA 由 Author 在下一次交接文档 commit 补录进 `HANDOFF.md`（`approval_commit_sha` 行）。

> 长期规则（Safety / [DEBT] / 证据假设标签）见 `AGENTS.md`，无需在计划里复述。
