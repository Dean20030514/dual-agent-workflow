---
description: Reviewer 完成审查后 Author 做最终把关、决定能否提交。当需要核验 blocking 是否解决、产出 PR description、判定可提交时使用。
---

# Phase 4：最终审查（Author）

Reviewer 完成后做最终审查。先读 `HANDOFF.md`、Reviewer 输出、最新 git diff、`last_test_run.txt`。

## 对待 Reviewer 意见的纪律（先验证，再决定改不改）

Reviewer（Codex）context 比 Author 少，**意见不一定对**。盲目照收 = 把它的 context 缺失变成你代码里的 bug。每条 blocking/建议按此处理：

1. **READ**：读完整意见，先不反应。
2. **VERIFY**：回代码核对——现象/缺陷真存在吗？
3. **EVALUATE**：在这个 codebase 里技术上成立吗？照改会否破坏现有功能？它看了全上下文吗？
4. **决定**：成立就改；不成立就**带技术理由反驳**（disagree 要逐条说理，不默默忽略也不默默照办）。
5. **YAGNI**：要求"补全 X"时先 grep 确认真有人用；没人用就反提"按 YAGNI 删掉"。

**禁止 performative agreement**：不写"完全正确！""好建议！"——用动作代替表态，改了 diff 本身就证明你听进去了。

> 本节先于下面"重点判断"：先确定哪些意见真该采纳，再逐条确认是否已解决。

重点判断：① blocking 是否全解决；② Reviewer 修复是否偏离计划/引入新问题；③ 是否需文档/配置/迁移/README 更新；④ 测试是否可信（必要时 Author 在正常终端重跑——与 Reviewer 禁令无关）；⑤ 是否有"测试通过但实现不稳"；⑥ Verification Needed 命令是否已全部代跑并追加输出；⑦ 是否残留 scratch 目录（有则列出请人类确认后删）。

输出（6 节不得空白或合并；Evidence 要引具体 diff/测试位置；PR Description 5 子项缺一不可）：

```
## Final Verdict   可以提交 / 需要小修 / 不建议提交
## Evidence        相关文件、关键 diff、测试命令与结果。
## Manual Check Before Commit   人类提交前应手动检查处。
## Remaining Risks  无则 "None"。
## Recommended Commit Message
## PR Description   ### What changed ### Why ### How tested ### Risks ### Notes for reviewer
```

仅当结论"可以提交"时，把 HANDOFF 的 Current Phase 更新为 Ready to Commit。最终 squash/merge 由人类执行。

---

# 最终完成标准

满足以下全部才算完成：

1. 原始需求与验收已实现（正式对照 TASK_BRIEF；快速版对照 HANDOFF 的扫描/简短计划/批准证据）。
2. 任务分支 diff 范围合理，无无关修改。
3. AGENTS.md、PRODUCT_BRIEF.md 没被错误覆盖。
4. per-task 交接文件齐全且已更新（快速版至少有 HANDOFF）。
5. last_test_run.txt 有最新真实测试输出且可信。
6. 没删测试或绕过逻辑（对照 diff 中测试文件改动确认）。
7. 阶段 commit 齐全：计划批准 commit（快速版以 Human Approval Evidence 替代）、author commit、review-fix commit（如有）。
8. 有 Remaining Risks 说明、commit message 和 PR description。
9. Reviewer 未重建副本/重装依赖/重跑全量测试；其 Verification Needed 已由 Author 代跑并产物化；scratch 目录经人类确认后清理。
10. Author 最终审查结论是"可以提交"。
11. **零暗债结论**：所有妥协要么已修，要么已在 HANDOFF 写成带触发偿还的 `[DEBT]` 明账；diff 中无 later/temporary/for now 等模糊遗留；若触碰挂债文件，该债已还或已显式申请降级。
12. **适用维度验收闭环**：0.1 标「关注」的每维验收项已满足（过设计/质量清单）；标 N/A 的已写原因。扫描与闸门状态已记录（正式在 TASK_BRIEF + HANDOFF Quality Gates；快速版在 HANDOFF）。无"既没做也没记原因"的维度。
13. **真实产品的度量与归属**（门控）：若为真实可发布产品，成功度量定义与上线后归属已记入 PRODUCT_BRIEF；关键埋点已验证可触发的证据在 last_test_run.txt 或 HANDOFF；用户/市场判断已区分证据/假设，高影响假设已验证或降级。非真实产品标 N/A。
