# HANDOFF.md

> per-task 核心交接文件。上一任务的交接记录见 `docs/ai/HANDOFF-2026-09-06-agent-reference-and-phase-rulings.md`（不属于本任务）。
> **本文件在工作树中恒滞后于 tip**（按流程它在 `review_tip_sha` **之后**的 docs commit 里提交）——数值以 review prompt 逐字给出的为准。

## Current Phase
**第 4 轮双审已产出**：9A「有条件通过（Blocking = None）」、9B「不通过（1 条 Product Blocking，归因标 `dispute`）」。**两份对该条给出相反归类 → 停在人类裁决前。** 另：第 3 轮那条 Product Blocking（AC6）经两份独立实跑确认**已闭合**。

## Task Summary
把本仓的双 Agent 工作流（原 Claude Code Author × Codex CLI Reviewer）落到 **DeepSeek Harness**：Author 与 Reviewer 都是 deepseek/dsh。产出 `dsh/` 一等公民、两个可加载 skill、DSH 便携 prompt，并登记部署面。**已跑 3 轮 9A/9B**：第 1 轮两份"不通过"、第 2 轮两份"有条件通过"、第 3 轮 9B"不通过（1 条 Product）"而 9A"有条件通过（同一条判为 Suggestion）"。

## Source of Truth
* `docs/ai/TASK_BRIEF.md`：本轮补写 + 两条 Amendment（人类 2026-09-06 接受）
* `IMPLEMENTATION_PLAN.md`：不存在（本任务无批准门，已如实登记）
* base：`main` @ `bf06c65` · approval_commit_sha：N/A · plan_review_9P：N/A（无规划文件）

## Review & Test Binding
| 轮 | review_base_sha → review_tip_sha | 9B | 9A |
|---|---|---|---|
| 1 | `bf06c65` → `a361bc19` | **不通过**（3 Product，全 `no`） | **不通过**（4 Product，全 `yes`）|
| 2 | `a361bc19` → `7084fb75` | **有条件通过**（0 Product） | **有条件通过**（0 Product）|
| 3 | `7084fb75` → `34b60370` | **不通过**（1 Product，`yes`）| **有条件通过**（0 Product）|
| 4 | `34b60370` → `fc32899f` | **不通过**（1 Product，**`dispute`** → 不计）| **有条件通过**（0 Product）|

* verdict 文件：`docs/ai/review_9{A,B}.md`（第 1 轮）、`_r2.md`、`_r3.md`、`_r4.md`
* tested_sha：`fc32899f5d6addd0cbafd43ab33fd56c607e9cd3`（第 4 轮审 tip；`last_test_run.txt` 的 §Q/§T 绑此值）
* review_sensitive_paths：`dsh portable install.ps1 AGENTS.md README.md docs/ai/AUTHORITY_CONTRACT.md docs/ai/DSH-LANDING-NOTES.md docs/ai/TASK_BRIEF.md`
* **第 4 轮隔离核验**：两份 `observed_head_sha` == `fc32899f`、`worktree_clean: yes`、`writes_performed: none`、无覆盖缺口。9A 自报 `deepseek-official/deepseek-flash@high`（与实发参数**逐字一致**）；9B 自报仅 `deepseek-flash` 并**如实说明**它看不到 provider/effort 两项——两份都不回避自证限度。
* **第 3 轮隔离核验**：两份 `observed_head_sha` == `34b60370`、`worktree_clean: yes`、`writes_performed: none`、无覆盖缺口；`model_route` 双双自报 `deepseek-official/deepseek-flash@high`，与实发参数**逐字一致**。
* **两处如实登记的隔离瑕疵**：① 9B 用 `git grep` 做全仓检索时**回显**了 `review_9A*.md` 的 3 行文本（声明未打开该文件、未作为推理输入）；② 9A **自行推断**"人类只要求跑 9A"因而记 `9B = N/A 减档`，而 9B 实际已跑——**本轮不是合法减档轮**。
* 9A 另如实登记一处仓外写入（`%TEMP%\old_handoff.txt`，在仓库与 holding 之外）。

## Work Log
* [2026-09-06] [Author] 第 3 轮修补：偿还第 4 笔债（README 措辞收窄）、修 9B-S1（`--patch` 钉不住推理档）、补 SKILL 计数与 §2 第 10 条、TASK_BRIEF 记人类接受 Amendment。 | `34b6037`
* [2026-09-06] [Author] 第 2 轮修补：修 B1–B4（`medium`/`-o`/QG 指针/改点登记）+ 收 Suggestion + 补 TASK_BRIEF。 | `7084fb75`
* [2026-09-06] [Author] 代跑第 3 轮 VN：**`medium` 被拒的负向对照首次实跑**（`Error: … does not support reasoning effort "medium"`）、23/23 同副本核验、AC4 判定重扫。 | 本文档 commit
* [2026-09-06] [Reviewer 9B 第 3 轮] **不通过**：1 条 `[Product Blocking]`（AC6 改写后按字面仍红、`<base>` 未钉死）+ 10 条 Suggestion。 | `review_9B_r3.md`
* [2026-09-06] [Reviewer 9A 第 3 轮] **有条件通过**：把同一条 AC6 缺陷判为 Suggestion 级；4 条 VN。 | `review_9A_r3.md`
* [2026-09-06] [Author] 首轮双审落账 + 归档上一任务 HANDOFF。 | `7c5505f` / `46316e2`

## Known Issues
* **两份 verdict 对同一条给出相反归类**（AC6 是 Product 还是 Suggestion）——**归因与分类的分歧交人类裁决，Author 不择一采信**。Author 的读法：偏向 9B——AC6 是**判定方式**本身恒红的验收条款，且 Amendment 把 `<base>` 留成占位符，按「验收条款必须可复现判定」它确实拿不到确定结论；但这只是 Author 读法，**无裁定权**。
* **本任务的流程缺口（不修，如实登记）**：无批准门、无 9P、TASK_BRIEF 事后补写、Amendment 由 Author 起草。
* **协议缺口仍在**：`reviewer-prompt.md` 未规定 verdict 文本在何处被捕获；三轮 verdict 全是 Author 转录，非 Reviewer 手写 artifact。
* **9B 的边缘隔离接触**与 **9A 的减档误判**（见上「隔离瑕疵」）。
* **未处置的建议**（第 3 轮两份共 14 条，以登记/措辞类为主）：AC6 补登记与钉 base、AC4 域对齐、AC1 改回可判定或补 `[DEBT]`、AC9 补判定方式、README/DSH-LANDING-NOTES 状态块按轮次更新、`install.ps1:97` 残留 clause 与注释口径、`AUTHORITY_CONTRACT` 补备份副作用。

## Fix-Loop Counter
* 第 1 轮 | 修 B1–B4 | **[Product] 1**（四条同轮去重）| 9A 全 `yes`、9B 全 `no`
* 第 2 轮 | 未修 Product（Blocking = None）| **[Product] 0** → **streak 归 0**
* 第 3 轮 | 修 Suggestion + 偿还债 #4（未修任何 Product）| **[Product]：9B 判 1 条 `caused_by_last_fix: yes`；9A 判 0 条** → 按 9B 计 **streak = 1**
* 第 4 轮 | 修 AC6（第 3 轮那条 Product）+ 补 AC1/AC4/AC9/AC10 判定方式 + 状态块收口 | **[Product]：9B 判 1 条但归因标 `dispute`；9A 判 0 条** → 按契约**`dispute` 不自动计数**，且 9A 同条判 Suggestion → **本轮暂计 0，streak 维持 1**；最终归属**交人类裁决**
* **streak（当前连续计数）: 1** · **双审轮次已用: 4**（上限 3；第 4 轮出自人类"修完再跑一轮"的**逐次批准**）
* **关闭阀状态**：① 第 3 轮那条 `caused_by_last_fix: yes` 的 Product Blocking **已实质闭合**（两份独立实跑确认）；② 第 4 轮 9B 的 Product Blocking **归因待人类裁决**——**裁 `yes` 则 streak 达 2 → 硬停**（只能回退／重新拆任务／架构升级，**不得**改走"限制交付"）；**裁 `no`（或采纳 9A 的 Suggestion 归类）则 streak 维持 1**；③ 轮次账已达 4 > 上限 3，**再开一轮须人类再次逐次批准**。
* **合并门**：第 4 轮 9A 判 Blocking = None，但 9B 那条归类未决 + 两份 Debt 均为 **Unpaid** → **现在不得合并、不得标"已收敛"**。

## Remaining Risks / Debt
```
[DEBT] 第 3 轮 9B 的 B1（AC6 按字面恒红 + <base> 未钉死）未解决 | Payback trigger: 合并前必须修复该 AC 或由人类裁决归类 | Impact: 人类按 AC6 复核会得到错误的"登记完整"结论；这正是三轮里反复出现的"账/措辞层"缺陷
[DEBT] dsh/ 的相对母本"判据无漂移"缺少机械门禁（AC10 的判定对声称无区分力，9A-S4）| Payback trigger: 下次改动 dsh/** 之前 | Impact: 判据漂移不会被任何门检出（本轮靠 Reviewer 手工逐行读才排除）
[DEBT] dsh/workflow/fanout-toolchain.md 的 DSH 事实绑定 @deepseek-ai/dsh 0.1.5-rc.x | Payback trigger: @deepseek-ai/dsh 升级后首次派发审查之前 | Impact: 参数/工具名变化会让调用范式静默失效（第 2 轮已复核一次）
[DEBT] ~/.dsh 的运行副本由人工同步产生，无 *.bak-*，且每次同步无落账规范 | Payback trigger: 首次用 install.ps1 覆盖 ~/.dsh 之前 | Impact: 首次自动部署没有上一版可回退；人工同步可能被遗忘
```
* **第 4 笔债（installer 整树备份复制凭据）已按人类裁决偿还**（收窄 README 措辞，commit `34b6037`）；两份第 3 轮 verdict 的 Reviewer 都逐句核对了"代码 ↔ README"并确认未出现反向过度声称。**残余行为**（备份仍会复制 `sessions/`/`storages/`/凭据且不自动清理）已改为上面的第 4 笔（人工同步）与之相邻披露，不再单列——**未静默删除该项的历史**。

## Quality Gates
| 维度/闸门 | 状态 | 证据 |
|---|---|---|
| 测试 QA(11.1) | **有限 Pass** | `last_test_run.txt`（A–P 节；含首次 `medium` 负向对照实跑） |
| 安全基础(11.2) | **Pass（有限）** | 无密钥入仓；备份复制凭据已如实披露；第 3 轮两份 verdict 均未报安全类 Product |
| 文档一致性 | **Fail（未收敛）** | 第 3 轮 14 条 Suggestion + 9B 的 1 条 Product 全在登记/措辞层 |
| 依赖引入 | **Pass** | 未引入新依赖 |
| 设计层闸门(§5) | **N/A** | 无界面 |

## Quick-Version Fields
* Applicability Scan(0.1)：文档/配置类；改的是部署面与判据副本，故走完整双审。
* Human Approval Evidence：人类给出 ①发首轮 ②授权建 reviewable commit ③进入第 2 轮 / `high` / 先跑审查 / 补 TASK_BRIEF ④偿还债 #4（收窄 README 措辞）/ 跑第 3 轮 9A / 接受 Amendment。

## Next Step
**停在人类裁决前。** 两条关闭阀同时到达，人类需在以下三条出路中裁决（`AGENTS.md` → Fix-Loop 三者优先级）：
1. **回退**（本任务全部产物可 revert；等价于放弃 DSH 落地）；
2. **重新拆任务**（把"判据副本"与"改点登记表"拆成两个任务——三轮的 finding 全部落在后者）；
3. **请求人类批准架构升级 / 限制交付**：
   * **限制交付的合法含义仅限**「零未解决 Product Blocking」——当前**不满足**（9B 的 B1 未解决），故**不得合并**；
   * 若人类裁决 9B 的归类不成立（即采纳 9A 的 Suggestion 级），则 Product Blocking 归零，限制交付成立，但**仍不得标"已收敛"**：须在 README 与 HANDOFF 如实写明"已审 tip = `34b60370`，残留 14 条 Suggestion 未处置"。
4. **另需裁决**：是否**逐次批准**第 4 轮再审（本轮已 3/3 上限；9A 明确建议不要开——剩余项全是登记/措辞级）；以及 `model_route` 自报值与实发参数逐字一致的核验结果（Author 已核：**一致**）。
