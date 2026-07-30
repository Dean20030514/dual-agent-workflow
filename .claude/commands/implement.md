---
description: 人类批准计划后开始写代码。当 IMPLEMENTATION_PLAN 已 Approved 且计划文件已被人类 commit 时使用。小任务走文末「快速版」。
---

# Phase 3：实现（Author）

人类批准后（Status=Approved 且计划文件已被人类 commit）开始：

1. **实现前自检 Pre-Flight**：批准 ≠ 免检。写第一行代码前通读 `IMPLEMENTATION_PLAN.md`，专找三类问题：
   * (a) 自相矛盾步骤（如 Task 3 用 `clearLayers()`、Task 7 写 `clearFullLayers()`）；
   * (b) 计划与 TASK_BRIEF 验收冲突；
   * (c) 计划本身要求的某项会被 Reviewer 判缺陷（绕过校验/缺测试）。
   一次性全列出交人类裁决，不要边做边撞。无问题则 Work Log 记"Pre-Flight 通过"。
2. 严格按计划执行，只做任务相关修改。
3. 发现计划不合理先暂停说明，不擅自扩大范围。
4. 完成后：
   * 跑测试，输出 `npm test 2>&1 | tee docs/ai/last_test_run.txt`（按项目实际命令）。
   * 对照 `docs/ai/QUALITY_GATES.md` 中本任务适用组逐项自查；有界面/内容则过 `/design-check`。
   * 更新 `HANDOFF.md`（Work Log / Known Issues / Remaining Risks / Quality Gates / Next Step）。
   * `git commit -m "wip(author): [任务名] implementation"`。
5. 遵守 `AGENTS.md` 的 Safety Rules。**遇 bug 走 `/debug`，不允许"试着改改看"。**
6. 声称"完成/通过/修好"前走声称闸门（见下）。

## 声称完成纪律（心理闸门，与产物化互补）

说"完成/通过/修好"前先走一遍：
1. IDENTIFY：哪条命令能证明这结论？
2. RUN：新鲜地跑一遍（不引用上次输出）。
3. READ：读完整输出 + exit code，数清 failure 数。
4. VERIFY：输出是否真支持结论？不支持就如实陈述当前状态（带证据）。
5. 到此才允许下结论，且必须附证据。

**禁止词（红旗，出现即代表你在替证据打包票）**：`should work` / `probably` / `seems to` / `应该没问题` / `大概` / `八成`；以及没跑就说 `Done!` / `Perfect!` / `搞定了`。

| 你想声称 | 真正要求的证据 | 不充分（会被打回） |
|---|---|---|
| 测试通过 | 本次命令输出明确 0 failures | "上次跑过了" / "应该会过" |
| Bug 已修 | 复现原症状的用例现在通过 | "代码改了，应该修好了" |
| 回归用例有效 | 写完跑(绿)→ 临时撤 fix 跑(必须红)→ 还原跑(绿) | "我写了回归用例"（没验证红→绿） |

## 输出

* **Implementation Summary**
* **Files Changed**（逐文件：改了什么、为什么）
* **Test Results**（命令 + 结论，完整输出见 last_test_run.txt）
* **Commit**（hash）
* **Ready for Review**：给出可复制给 Reviewer 的 prompt（见 `reviewer-prompt.md`，9A 标准 / 9B 盲审，人类选）。**不得删减固定要件**：① 先读 AGENTS.md + TASK_BRIEF/PLAN/HANDOFF/git diff/last_test_run.txt；② 含 Reviewer-Lightweight Protocol；③ 含完整输出契约；④ 粘贴本任务适用的设计/质量清单或指向 `docs/ai/QUALITY_GATES.md`。

---

# 小任务快速版

> 小 bug/小作业/小文件修改默认**跳过产品展开**：`/define` 的 0.2~0.5 与上线后清单整段 N/A，只走开发主干 + 三条硬规则。仍保留：0.1 快扫（写进 HANDOFF）、QUALITY_GATES 11.2 基础安全恒查、设计/质量清单中与本次改动**实际相关**的项；无关项 N/A。
> **升级触发（强制回流）**：若发现"这小任务其实是新功能/新产品/会产生真实用户可见行为变化"，立即停止快速版，回 `/define` 跑 0.1 扫描再继续。
> **hotfix 裁决**：改动落在已上线、有真实用户的产品上，凡改变用户可见行为或新增/改变埋点，不得走跳过——至少过上线后适用项 + 质量相关组；纯内部重构/无行为变化的 hotfix 才可走快速版。

三条硬规则不变：git 分支与 commit；测试输出写 last_test_run.txt；人类批准门（凭证 = 人类一句话批准记入 HANDOFF 的 Human Approval Evidence）。

1. Author 只读分析（plan mode）。
2. Author 输出简短计划（可只在对话中），等人类一句话批准。
3. Author 实现，跑测试（tee 到 last_test_run.txt），commit。
4. Author 更新 HANDOFF（快速版唯一必须的交接文件），至少填：Applicability Scan(0.1)、Human Approval Evidence、Remaining Risks/Debt、Quality Gates(本次相关行)。零暗债红线同样适用（格式见 `AGENTS.md`，无债写 "Debt: none"）；Payback-on-Touch 照常生效。
5. 可选：Reviewer 用 9A 做快速 review（Reviewer-Lightweight Protocol 同样强制）。
6. 人类检查 diff 后提交。
