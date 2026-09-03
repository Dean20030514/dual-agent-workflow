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
5. **逐条对 Reviewer 的 `Proposed Fix` 表态**——三种表态的确切义务（含"不采纳允许零改动"与 Suggestion 不构成合并门）**以 `reviewer-prompt.md` → 修法必附为唯一定义处，本文件不复述**。Reviewer 写 `需人类裁决` 的原样上交人类，Author 无裁定权。
6. **YAGNI**：要求"补全 X"时先 grep 确认真有人用；没人用就反提"按 YAGNI 删掉"。

**禁止 performative agreement**：不写"完全正确！""好建议！"这类赞美套话——用动作证明你听进去了。**但这不替代步骤 5 的逐条三选一表态**：diff 本身不能代替表态，每条仍须一句话写明 `采纳 / 修改后采纳 / 不采纳`。

**跨轮硬停**：先按 **`AGENTS.md` → 停止事件优先级** 判该停什么；Critical 的 streak 计数值再读 HANDOFF 的 Fix-Loop Counter，按 **`AGENTS.md` → Fix-Loop 计数与跨轮硬停（唯一定义处）** 判定——递增条件、重置、硬停阈值、轮次上限、以及三者与合并门的优先级**全部以母本为准，本文件不复述**。执行纪律：`caused_by_last_fix` 由 Reviewer 判定、Author 逐字转录（不得自填来源），争议交人类。修任何 `[Product Blocking]`（改生产代码）一律走回归安全修复协议（blast-radius 枚举 + 全量相关套件），不许只盯触发点；纯证据代跑与账本修正不走该协议。

> 本节先于下面"重点判断"：先确定哪些意见真该采纳，再逐条确认是否已解决。

重点判断：① blocking 是否全解决（两份 verdict 逐条过，9A/9B 同一问题按问题去重）；② **双审隔离是否成立**——两份 verdict 绑定同一 `review_tip_sha`；核验所用的**权威 `handoff_snapshot_sha` 来源 = HANDOFF 的 Review & Test Binding**（统一落账时由 Author 持久化，见 reviewer-prompt.md 双审隔离协议 ④），**不依赖仓外 holding 的 prompt 文件**（prompt 文件若尚在可作旁证——两份所写应相同——但其缺失不阻断核验）；审前快照用**持久化证据**核验，**禁止**用「最近一次修改 HANDOFF 的 commit」（如 `git log -1 --format=%H -- docs/ai/HANDOFF.md`）去核——落账后它指向审后 docs commit，必然失真：核两份 verdict 证据首行的 `observed_head_sha` 相互相等且 == `handoff_snapshot_sha`；`worktree_clean` 皆 yes；`read_handoff_from` 皆「工作树」（出现 `git show tip` = 该轮建立在过期 HANDOFF 上，作废重跑）；用 `git show <handoff_snapshot_sha>:docs/ai/HANDOFF.md` 取出审前 `review_sensitive_paths` 与当前 HANDOFF 比对——出现移除条目、改窄 glob、移出文件即缩窄，作废重跑；**覆盖核验**：跑 `git diff --name-only <review_base_sha>..HEAD`，其中每个必含类别文件（生产源码 / tests / migrations·schema / 构建配置 + 依赖声明 + lockfile / TASK_BRIEF）都须被当前清单覆盖，两份 verdict 首行之后的「覆盖缺口」路径须已在当前清单——任一未覆盖 → 不得可提交；补清单后对新纳入路径跑 `git diff --quiet <review_tip_sha> -- <路径>`，非零即审后有未审改动 → 须对该 delta 再审；`git diff <review_tip_sha> -- docs/ai/QUALITY_GATES.md` 非空 → 原样列进 Manual Check Before Commit 由人类决定是否再审；双审窗口内无人改生产代码/`review_sensitive_paths`/HANDOFF（核对 git log 无窗口内 commit、两份 verdict 文件各自独立）；不成立则这轮双审无效，重跑而非将就；③ 是否需文档/配置/迁移/README 更新；④ 测试是否可信（必要时 Author 在正常终端重跑——与 Reviewer 禁令无关）；⑤ 是否有"测试通过但实现不稳"；⑥ Verification Needed 是否已逐条处置——代跑并追加真实输出与退出码，或以技术理由「不采纳」；每条在 Manual Check Before Commit 占一行（命令 → 退出码 → 判定「产品缺陷 是/否」，或「不采纳 + 理由」），退出码非 0 / 装置判 NOT PROVEN 的不得省略；处置产生的 review-sensitive delta 是否再审按收敛门 ③ 判（纯代跑与 HANDOFF 落账不再审）；走收敛门 ③ 例外 (a) 时核对新旧 `last_test_run.txt` 的收集用例总数（新 ≥ 旧）；⑦ 是否残留 scratch 目录 / 诊断 probe（有则列出，probe 提交前删）。

**合并门（阻止合并只由未解决的 `[Product Blocking]` 与 Unpaid 债）**：有未解决 `[Product Blocking]`（未修复且未经人类裁决不成立）、或 Debt Verdict 为 Unpaid（触发 Payback-on-Touch 未还且未获延期批准）→ 不得可提交；verdict 词不是独立条件；`有条件通过` 在 Verification Needed 逐条处置后视同通过；Process Debt（Noted/Deferred）与 Suggestion **记录但不阻止**；Verification Needed 未逐条处置（代跑或不采纳）亦不得标可提交——它是收敛前置条件（见收敛门），不是问题级阻塞。

**收敛门（硬）**：标 `可以提交 / Ready to Commit / 已收敛` 的全部条件——含 `review_tip_sha` 内容绑定及门 ③ 列出的例外（含 QUALITY_GATES 审后改动交人类复核的分支）、「无未解决 `[Product Blocking]`」的判法、Verification Needed 逐条处置、以及失效判定的内容比对法——**一律以 `AGENTS.md` → 最后一轮独立审查门（唯一定义处）为准，本文件不复述**。恒记住其结论：**人类因成本叫停 ≠ 质量通过**，记 `stopped, NOT converged`，未经审代码不得标已收敛/可提交。

输出（6 节不得空白或合并；Evidence 要引具体 diff/测试位置；PR Description 5 子项缺一不可）：

```
## Final Verdict   可以提交 / 需要小修 / 不建议提交
## Evidence        相关文件、关键 diff、测试命令与结果。
## Manual Check Before Commit   人类提交前应手动检查处——逐条列：每条 Verification Needed 的处置行（命令 → 退出码 → 判定，或 不采纳 + 理由）；本任务依赖的每条人类裁决（日期 / 内容 / 落点）；审后 `docs/ai/QUALITY_GATES.md` 的 diff 与收敛门 ③ 例外 delta。
## Remaining Risks  无则 "None"。
## Recommended Commit Message
## PR Description   ### What changed ### Why ### How tested ### Risks ### Notes for reviewer
```

仅当结论"可以提交"时，把 HANDOFF 的 Current Phase 更新为 Ready to Commit。最终 squash/merge 由人类执行。

> 最终审查期间若发现 bug/失败，走 `/debug`（系统化调试），不临时试错改。

---

# 最终完成标准

> 本节 13 点是**权威完成清单**，不要另起并行清单；任一条不满足，上面 Final Verdict 不得为「可以提交」（门控项如第 13 点不适用则标 N/A + 一句原因）。

满足以下全部才算完成：

1. 原始需求与验收已实现（正式对照 TASK_BRIEF；快速版对照 HANDOFF 的扫描/简短计划/批准证据）。
2. 任务分支 diff 范围合理，无无关修改。
3. AGENTS.md、PRODUCT_BRIEF.md 没被错误覆盖。
4. per-task 交接文件齐全且已更新（快速版至少有 HANDOFF）。
5. last_test_run.txt 有最新真实测试输出且可信。
6. 没删测试或绕过逻辑（对照 diff 中测试文件改动确认）。
7. 阶段 commit 齐全：计划批准 commit（正式版内含 `docs/ai/review_9P.md`——该文件含 9P verdict（默认一轮；人类明示加轮的依次追加）+ Author Responses，或人类减免记录；快速版以 Human Approval Evidence 替代、9P 记 `N/A — 快速版`）、author commit、review-fix commit（如有）。
8. 有 Remaining Risks 说明、commit message 和 PR description。
9. Reviewer 未重建副本/重装依赖/重跑全量测试；其 Verification Needed 已由 Author 逐条处置（代跑并产物化，或以技术理由不采纳）；scratch 目录经人类确认后清理。
10. Author 最终审查结论是"可以提交"，**且过收敛门**（条件以 `AGENTS.md` → 最后一轮独立审查门为准），且双审隔离成立（同一 tip、窗口内无人写入、两份 verdict 分开保存）；**人类成本叫停记 `stopped, NOT converged`、不算收敛**。
11. **零暗债结论**：所有妥协要么已修，要么已在 HANDOFF 写成带触发偿还的 `[DEBT]` 明账；diff 中无 later/temporary/for now 等模糊遗留；若触碰挂债文件，该债已还、或已获人类明确批准延期（Debt Verdict = Deferred）；仅提出申请未获批 = Unpaid，不得判「可以提交」。
12. **适用维度验收闭环**：0.1 标「关注」的每维验收项已满足（过设计/质量清单）；标 N/A 的已写原因。扫描与闸门状态已记录（正式在 TASK_BRIEF + HANDOFF Quality Gates；快速版在 HANDOFF）。无"既没做也没记原因"的维度。
13. **真实产品的度量与归属**（门控）：若为真实可发布产品，成功度量定义与上线后归属已记入 PRODUCT_BRIEF；关键埋点已验证可触发的证据在 last_test_run.txt 或 HANDOFF；用户/市场判断已区分证据/假设，高影响假设已验证或降级。非真实产品标 N/A。
