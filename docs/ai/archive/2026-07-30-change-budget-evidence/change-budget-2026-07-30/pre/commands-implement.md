---
description: 人类批准计划后开始写代码。当 IMPLEMENTATION_PLAN 已 Approved 且计划文件已被人类 commit 时使用。小任务走文末「快速版」。
---

# Phase 3：实现（Author）

人类批准后（Status=Approved 且计划文件已被人类 commit）开始：

1. **实现前自检 Pre-Flight**：批准 ≠ 免检。写第一行代码前通读 `IMPLEMENTATION_PLAN.md`，专找三类问题：
   * (a) 自相矛盾步骤（如 Task 3 用 `clearLayers()`、Task 7 写 `clearFullLayers()`）；
   * (b) 计划与 TASK_BRIEF 验收冲突；
   * (c) 计划本身要求的某项会被 Reviewer 判缺陷（绕过校验/缺测试）。
   此外确认 `IMPLEMENTATION_PLAN.md` 有 `Frozen Acceptance` 节（改实现前冻结的验收标准，禁反推自实现）——缺则回 `/plan` 补。
   一次性全列出交人类裁决，不要边做边撞。无问题则 Work Log 记"Pre-Flight 通过"。
2. 严格按计划执行，只做任务相关修改。
3. 发现计划不合理先暂停说明，不擅自扩大范围。
4. 完成后（**顺序严格**，让 `tested_sha` 真含本次实现）：
   1. **清除临时 probe / mutation harness**（值得留的行为先重写为正式 regression test，预期来自验收契约）。
   2. **创建 author commit**：`git commit -m "wip(author): [任务名] implementation"`——这是被测/被审的 tip。
   3. **确认 review-sensitive 路径干净**：`git status --porcelain -- <HANDOFF 的 review_sensitive_paths>` 为空（非空则回 1，先把改动纳入 commit）。
   4. **针对该 commit 跑测试**：`… 2>&1 | tee docs/ai/last_test_run.txt`（按项目实际命令）；`last_test_run.txt` 记 `tested_sha`(=该 author commit) + 真实命令。
   5. 对照 `docs/ai/QUALITY_GATES.md` 适用组自查；有界面/内容过 `/design-check`。
   6. 更新 `HANDOFF.md`（Review & Test Binding 的 tested_sha、Fix-Loop Counter、Runtime Identity、Work Log/Known Issues/Remaining Risks/Quality Gates/Next Step）。
   7. **只提交测试产物 + 普通交接文档**；若之后又改了 **`review_sensitive_paths` 中任一文件（源码 / 测试 / 验收 / 配置 等）** → 回步骤 2 重来（`tested_sha` 失效）。
5. 遵守 `AGENTS.md` 的 Safety Rules。**遇 bug 走 `/debug`，不允许"试着改改看"。修 Reviewer blocking / 任何"修 A 别破 B" 一律走 `/debug` 的回归安全修复协议（blast-radius 枚举 + 全量相关套件 + Fix-Loop Counter 跨轮硬停），不许只盯触发点局部修。** 临时 probe / mutation harness 标 `diagnostic only`、**提交前删除、不作完成证据**（值得留的行为重写为正式 regression test，预期来自验收契约非反推）；同轮改实现与改 harness 须**分开展示各自 diff 与依据**（见 AGENTS 验证三分类）。
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
| 回归用例有效 | **守护有效性装置的结构化产物**（必填字段与失败判据见 `AGENTS.md` → 守护有效性装置，唯一定义处） | 自然语言自述 / 任何未经装置产物支撑的叙述（含"删码变红"口头证明） |

## 输出

* **Implementation Summary**
* **Files Changed**（逐文件：改了什么、为什么）
* **Test Results**（命令 + 结论，完整输出见 last_test_run.txt）
* **Commit**（hash）
* **Ready for Review**：给出可复制给 Reviewer 的 prompt（见 `~/.claude/workflow/reviewer-prompt.md`，**默认双审 9A+9B**，配额吃紧或纯小任务人类可减档只跑 9A）。**不得删减固定要件**：① 先读 AGENTS.md + TASK_BRIEF/PLAN/HANDOFF/git diff/last_test_run.txt；② 原样含 Reviewer-Lightweight Protocol 那句中文；③ 原样含完整输出契约 8 节（Review Verdict / Blocking Issues / Non-Blocking Suggestions / Test Coverage Gaps / Cannot Verify From Diff / Verification Needed / Debt Verdict / Recommended Next Step；**9B 同时含 Recommended Next Step + Requirement-Level Concerns、不替换**）——别只留 Debt Verdict 丢了 Review Verdict 与 Cannot-Verify-From-Diff；④ 粘贴本任务适用的设计/质量清单或指向 `docs/ai/QUALITY_GATES.md`；⑤ **双审隔离三要求**（详见 reviewer-prompt.md「双审隔离协议」）：两份 prompt 锚定**同一** `review_tip_sha` + **同一个 `handoff_snapshot_sha`**（= 交接 docs commit；并写明「代码审 base..tip、HANDOFF 与 last_test_run 读工作树」——**正式版与快速版都一样，tip 里的 HANDOFF 必然是过期版**）；双审窗口内**任何人不得改生产代码 / `review_sensitive_paths` / HANDOFF**；两份 verdict 分别落到**仓外 holding**、后跑的 Reviewer 启动前工作树内不得存在前一份 verdict 或 raw log。

---

# 小任务快速版

> 小 bug/小作业/小文件修改默认**跳过产品展开**：`/define` 的 0.2~0.5 与上线后清单整段 N/A，只走开发主干 + 三条硬规则。仍保留：0.1 快扫（写进 HANDOFF）、QUALITY_GATES 11.2 基础安全恒查、设计/质量清单中与本次改动**实际相关**的项；无关项 N/A。
> **升级触发（强制回流）**：若发现"这小任务其实是新功能/新产品/会产生真实用户可见行为变化"，立即停止快速版，回 `/define` 跑 0.1 扫描再继续。
> **hotfix 裁决**：改动落在已上线、有真实用户的产品上，凡改变用户可见行为或新增/改变埋点，不得走跳过——至少过上线后适用项 + 质量相关组；纯内部重构/无行为变化的 hotfix 才可走快速版。

三条硬规则不变：git 分支与 commit；测试输出写 last_test_run.txt；人类批准门（凭证 = 人类一句话批准记入 HANDOFF 的 Human Approval Evidence）。

1. Author 只读分析（plan mode）。
2. Author 输出简短计划（可只在对话中），等人类一句话批准。
3. Author 实现 → **清 probe → 建 author commit（这就是被测/被审的 tip）→ 确认 review-sensitive 路径干净（`git status --porcelain -- <review_sensitive_paths>` 为空；非空则先把改动纳入 commit 重来）→ 针对该 commit 跑测试（`… 2>&1 | tee docs/ai/last_test_run.txt`），`tested_sha` = `review_tip_sha` = 该 author commit**。**本步不提交任何交接文档**（顺序同正式版步骤 4）。
4. Author 更新 HANDOFF（快速版唯一必须的交接文件），至少填：Review & Test Binding（`review_base_sha` / `review_tip_sha` / `tested_sha` / `review_sensitive_paths`）、Applicability Scan(0.1)、Human Approval Evidence、Remaining Risks/Debt、Quality Gates(本次相关行)。零暗债红线同样适用（格式见 `AGENTS.md`，无债写 "Debt: none"）；Payback-on-Touch 照常生效。
5. **HANDOFF 更新完毕后**才提交交接产物，且只含这两个文件：`git commit -m "docs(handoff): [任务名] test run + handoff" -- docs/ai/last_test_run.txt docs/ai/HANDOFF.md`。二者**不在** `review_sensitive_paths` 内，按 AGENTS 的内容比对不使 `tested_sha` / `review_tip_sha` 失效（tip 仍指步骤 3 的 author commit）。**顺序不可颠倒**——先提交再更新 = 提交的是旧 HANDOFF、更新后的内容没进任何 commit，Reviewer 读到的 HANDOFF 与仓库状态不一致。此后若又改了 `review_sensitive_paths` 任一文件 → 回步骤 3 重来（`tested_sha` 失效）。
6. **有 review-sensitive 改动 → Reviewer 必须执行**（走收敛门；Reviewer-Lightweight Protocol + `reviewer-prompt.md` 的**双审隔离协议**强制）。步骤 5 的 docs commit 即双审共读的**审前 HANDOFF 快照**：记下它的 sha 作为 `handoff_snapshot_sha` 写进两份 review prompt，并在 prompt 里明确「HANDOFF / last_test_run 读工作树，代码审 base..tip」——**tip 里的 HANDOFF 是过期的**，不这么写 Reviewer 会去 `git show <tip>:docs/ai/HANDOFF.md` 读到旧版（2026-07-28 实测）。双审窗口内该快照不得再动。**仅完全不触及 review-sensitive 路径的纯文档任务才可跳过 Reviewer**。
7. 人类检查 diff 后提交。
