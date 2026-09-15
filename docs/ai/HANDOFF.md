# HANDOFF.md

> per-task 核心交接文件。上一任务的交接记录见 `docs/ai/HANDOFF-2026-09-06-agent-reference-and-phase-rulings.md`（不属于本任务）。
> **本文件在工作树中恒滞后于 tip**（按流程它在 `review_tip_sha` **之后**的 docs commit 里提交）——数值以 review prompt 逐字给出的为准。

## Current Phase
**硬停已触发（streak = 2）→ 人类 2026-09-06 裁决走「重新拆任务」**，本文件记录拆法与再启动条件。

**拆法**（依据第 5 轮 9A 的 finding 分布：五轮下来 finding **100% 落在"改点登记表 + 验收条款判定方式"这一层**，判据层 0；且两个机械门各自也不稳）：
* **任务 A — 交付物本体**：`dsh/`（母本 + reviewer-prompt + fanout 工具面 + QUALITY_GATES + index + templates + 两个 skill + 7 个 phase + 2 份手册）、`portable/通用prompt-DSH-v1.txt`、`install.ps1` 的 DSH 段、部署登记（README / 根 `AGENTS.md` / `AUTHORITY_CONTRACT`）。
  * **状态**：自第 2 轮起未再出现实质缺陷；判据层经多次独立逐行核验零漂移；两个机械门曾各自跑绿。**它不依赖任务 B 的收敛**（本会话此刻正在用 `~/.dsh` 里的这套东西跑第 5 轮审查）。
* **任务 B — 本任务的账本层**：改点登记表（§2/§2.1/§2.2/§2.3）与全部 AC 的判定方式、降级/未验证的账目口径。**本任务至今在这一层的产出为负**：五轮 0 条产品缺陷、两个门各自不稳、且它自己在第 5 轮又一次漏面。

**再启动条件（不是"再试一轮"）**：任务 A 与任务 B 分别按各自范围收口；任务 B 收口后才决定整体是否合并。**人类 2026-09-06 明确同意按此拆法执行**（原话"按照你的建议"），并已确认恢复 9B。

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
| 5（收口轮） | `1c40e7a` → `3f445b8a` | **未跑**（Author 误判为"可减档"，已确认是判断错误）| **不通过**（3 Product；B-1 `yes` → **streak = 2 硬停**）|
| 6 | `578ad39` → `1d5f3a9` | **拒审**（`worktree_clean: no`，因 Author 提交了 `.tmp-r6.ps1`；无 verdict）| **不通过**（1 Product，`dispute`）+ 4 条正面确认 |

* verdict 文件：`docs/ai/review_9{A,B}.md`（第 1 轮）、`_r2.md`、`_r3.md`、`_r4.md`
* tested_sha：`87528d49d658eec5f52efae7e75783dd15d18207`（收口轮 tip；`last_test_run.txt` 的 §X/§Y/§Z 绑此值）
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
* 第 4 轮 | 修 AC6（第 3 轮那条 Product）+ 补 AC1/AC4/AC9/AC10 判定方式 + 状态块收口 | **[Product]：9B 判 1 条但归因标 `dispute`；9A 判 0 条** → 按契约 `dispute` 不自动计数，本轮计 0，streak 维持 1
* 第 5 轮（收口） | **未修任何 Product**；按人类裁决把 AC 分三级、只留两个机械门、废弃 AC9 两条坏判定 | **[Product] 0** → **streak 维持 1**
* **streak（当前连续计数）: 2 —— 硬停已触发**（第 5 轮 9A 的 B-1 归因 `yes`）。第 6 轮 9B 因工作树不净**拒审**（无 verdict），不改变该计数。
* **双审轮次已用: 4**（上限 3；第 4 轮出自人类"修完再跑一轮"的逐次批准）。**第 5 轮是收口轮**：只跑了 9A 单审（现在判定为**判断错误**——它正是漏掉 B-1/B-3 的原因，人类已确认**恢复 9B**）。**第 6 轮起恢复双审 9B + 9A。**
* **第 5 轮 9A 单审结论：不通过（3 条 Product Blocking）** → **B-1 归因 `yes`（两套定义一致）→ streak 由 1 增至 2 → 硬停触发**。B-2/B-3 归因 `dispute`（未计）。
* **关闭阀状态**：① 第 3 轮那条 Product Blocking **已实质闭合**（两份独立实跑确认）；② 第 4 轮 9B 那条的**归类与归因仍待人类裁决**——裁 `yes` 则 streak 达 2 → 硬停；③ 轮次账已 4 > 上限 3，**再开完整双审须人类再次逐次批准**（本收口轮为单审，不占双审轮次）。
* **合并门：关闭。** 第 5 轮 9A 报 **3 条 Product Blocking**（B-1 归因 `yes`）→ streak = 2 硬停；按 `AGENTS.md` → Fix-Loop 三者优先级 ②，**存在未解决 `[Product Blocking]` 时"限制交付"不含合并**。第 6 轮：9B **拒审**（无 verdict）、9A **不通过**（1 条 Product Blocking，归因 `dispute`）。**债台账现为 6 笔**（其中 1 笔为已实质闭合的历史记录）。**在人类裁定本轮那条 `dispute` 之前，本门保持关闭。**

## Remaining Risks / Debt
```
[DEBT] AC4-门（档位取值域）的实现自身无机械完整性保护：AC6 是路径级谓词，已登记路径的内部修改零信号，削弱该脚本只能靠人工读 diff（2026-09-06 第 6 轮 9B 的 R6-B3）| Payback trigger: 下次改动 tools/ac4-reasoning-effort-check.ps1 之前；或下次由人类复核 dsh/** 判据面之前 | Impact: 一道机械门可在双门全绿的情况下被静默削弱
[DEBT] AC4-门的正则只覆盖"未加引号小写"形态：驼峰键 `reasoningEffort: <v>` 与被反引号包裹的值均可逃逸（2026-09-06 第 6 轮 9B 的 R6-S1，独立实测逃逸）| Payback trigger: 下次改动该脚本或 AC4 声称之前 | Impact: `[M]` 标记名不副实——域外取值可以合法写法进入文档而门报 PASS
[DEBT] 第 3 轮 9B 的 B1（AC6 按字面恒红 + <base> 未钉死）——**已实质闭合**（第 4 轮两份独立实跑确认），保留为历史记录 | Payback trigger: —（已闭合）| Impact: —
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
**任务 A 与任务 B 分别收口；本文件末尾「待人类裁决」一节列出仍需人类定的岔口。**

**立即执行顺序**：① 收口任务 A（把 `tools/ac4-reasoning-effort-check.ps1` 登记进 §2.1/§2.3，修 B-1）；② 按人类选择处理任务 B 的交付边界；③ **恢复 9B 双审**（第 5 轮我错误地让 9B 缺席，而 B-1/B-3 恰是盲审最易捞到的"改动副作用"型缺陷）；④ ~~解答 9A 悬置的 VN-B~~ —— **已解答**：Author 打开 `docs/ai/review_9A_r3.md` 核实，`:43` 确有"逐行读完 40 行变更、未发现判据/阈值漂移"→ **引用属实**（第 6 轮 9A 也据此撤回了该悬置项）。

（以下是第 4→5 轮时写下的说明，保留供对照）
**先跑收口后的 9A 单审**（`review_base_sha = 1c40e7a` → `review_tip_sha = <收口 tip>`；delta 为 AC 分层重写 + 登记表修正 + 两个门的产物）。
**若 9A 判 Blocking = None**，人类仍须先裁第 4 轮那条 `dispute`（Product 还是 Suggestion、`caused_by_last_fix` yes/no）；裁 `no`/Suggestion → streak 归 0，且两个门已绿 → 可进入"限制交付"或直接合并（由人类决定，`[U]` 6 项须在 README/HANDOFF 如实保留）。
**若 9A 又报 Product Blocking** → 按 `AGENTS.md` 三者优先级处理；注意 streak 会由 1 增至 2 → **硬停**。

（以下是第 4 轮时写下的出路说明，保留供对照）
1. **回退**（本任务全部产物可 revert；等价于放弃 DSH 落地）；
2. **重新拆任务**（把"判据副本"与"改点登记表"拆成两个任务——三轮的 finding 全部落在后者）；
3. **请求人类批准架构升级 / 限制交付**：
   * **限制交付的合法含义仅限**「零未解决 Product Blocking」——当前**不满足**（9B 的 B1 未解决），故**不得合并**；
   * 若人类裁决 9B 的归类不成立（即采纳 9A 的 Suggestion 级），则 Product Blocking 归零，限制交付成立，但**仍不得标"已收敛"**：须在 README 与 HANDOFF 如实写明"已审 tip = `34b60370`，残留 14 条 Suggestion 未处置"。
4. **另需裁决**：是否**逐次批准**第 4 轮再审（本轮已 3/3 上限；9A 明确建议不要开——剩余项全是登记/措辞级）；以及 `model_route` 自报值与实发参数逐字一致的核验结果（Author 已核：**一致**）。

## 待人类裁决（硬停后的岔口）

> **2026-09-06 第 6 轮后更新**。第 4/5/6 三轮共产生 **5 条 `dispute`**（按契约 `dispute` 不自动计数、交人类裁决）。

**A. `caused_by_last_fix` 归因未决的 5 条**：
1. **第 4 轮 9B-B1**（AC9 判定①按字面恒红、从未执行）—— 该判定**已在第 5 轮收口时废弃**，故此条的**归类**仍待裁（Product 还是 Suggestion），但其**所指缺陷已不存在**。
2. **第 4 轮 9B-NS-12 / 9A-S4**（AC6 谓词只有路径级区分力）—— 已按"收窄声称"处置并写明；归类待裁。
3. **第 5 轮 9A-B2**（AC4-门只覆盖声明域内 20 处站点中的 7 处）—— **所指缺陷仍在**（真逃逸形态 = 驼峰键 + 反引号值），已记 `[DEBT]`；归类待裁。
4. **第 5 轮 9A-B3**（`HANDOFF` 的 `@` → `x` 损坏）—— **已当场修**；归类待裁。
5. **第 6 轮 9A-PB-1**（合并门条目在硬停状态下仍写"OPEN 候选"）—— **已当场修**；归类待裁。**9A 明确写**：`dispute` → 不自动递增 streak，请人类连同第 4 轮那条一并裁定。

**B. 三个仍需人类定的方向**：
1. **任务 B 的交付边界是否现在冻结**（不冻结则"收口"没有可复现判据——第 6 轮 9B 的 Requirement Concern 3）。
2. **B-2 的处置方向**：加宽 AC4 正则（保持 `[M]`）vs 收窄其声称到"仅未加引号小写赋值位"（AC4 退化为近似 `[O]`）。**合并前必须定**，否则 AC4 的 `[M]` 标记名不副实。
3. **第 6 轮 9B 的拒审是否按"该轮审查没发生"处理**（Author 已按此处理：本轮双审轮次仍计 4，9B 那份不携带 verdict；但它的 R6-B3/R6-S1 事实被采纳为依据，这一混用须人类确认——第 6 轮 9A 的 S8）。
