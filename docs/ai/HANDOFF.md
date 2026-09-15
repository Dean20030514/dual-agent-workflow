# HANDOFF.md

> per-task 核心交接文件。上一任务的交接记录见 `docs/ai/HANDOFF-2026-09-06-agent-reference-and-phase-rulings.md`（不属于本任务）。
> **本文件在工作树中恒滞后于 tip**（按流程它在 `review_tip_sha` **之后**的 docs commit 里提交）——数值以 review prompt 逐字给出的为准。

## Current Phase
**硬停已触发（streak = 2）→ 人类 2026-09-06 裁决走「重新拆任务」**，本文件记录拆法与再启动条件。 **第 8 轮进展**：任务 B 的处置已按人类裁决落地（AC4 选 **2a** 加宽、交付边界**冻结**、**不再开新审查轮**）；矩阵上的岔口**至此全部有裁**——最后一项 PB-2 也已当场偿还（`1e8832e`，Payback-on-Touch）；**人类 2026-09-06 裁决 = 合并**；经核实**本仓的工作分支就是 `main`**（非侧分支）——`main..HEAD = 0`、`origin/main..HEAD` 为正且**笔数不写死**（现查 `git rev-list --count origin/main..HEAD`——原文写死"37"，而记录该数字的提交自身就是下一笔，写死必然自失效），故**本地没有合并动作可做**；**人类已于 2026-09-06 完成 push**（**push 时点** `origin/main` = `9a10db7`；当前值现查 `git rev-parse origin/main`、`git rev-list --count origin/main..HEAD`，推送历史见 `git reflog show origin/main`；原始输出见 `last_test_run.txt §AT/§AU`）。本仓契约禁止 agent 做任何远程操作；**且本仓无 CI 配置**，原文写的"（+ CI）"是空指，已订正。

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
* review_sensitive_paths：`dsh portable tools install.ps1 AGENTS.md README.md docs/ai/AUTHORITY_CONTRACT.md docs/ai/DSH-LANDING-NOTES.md docs/ai/TASK_BRIEF.md`（**2026-09-06 第 7 轮补 `tools`**：`tools/ac4-reasoning-effort-check.ps1` 是 AC4-门的实现，第 6 轮 9B 的 R6-S3 指出本清单与 AC6 的 scope 对同一交付面给出两个定义）
* **第 4 轮隔离核验**：两份 `observed_head_sha` == `fc32899f`、`worktree_clean: yes`、`writes_performed: none`、无覆盖缺口。9A 自报 `deepseek-official/deepseek-flash@high`（与实发参数**逐字一致**）；9B 自报仅 `deepseek-flash` 并**如实说明**它看不到 provider/effort 两项——两份都不回避自证限度。
* **第 3 轮隔离核验**：两份 `observed_head_sha` == `34b60370`、`worktree_clean: yes`、`writes_performed: none`、无覆盖缺口；`model_route` 双双自报 `deepseek-official/deepseek-flash@high`，与实发参数**逐字一致**。
* **两处如实登记的隔离瑕疵**：① 9B 用 `git grep` 做全仓检索时**回显**了 `review_9A*.md` 的 3 行文本（声明未打开该文件、未作为推理输入）；② 9A **自行推断**"人类只要求跑 9A"因而记 `9B = N/A 减档`，而 9B 实际已跑——**本轮不是合法减档轮**。
* 9A 另如实登记一处仓外写入（`%TEMP%\old_handoff.txt`，在仓库与 holding 之外）。

## Work Log
* [2026-09-06] [Author] 第二次 push 落账 + **订正我自己上一笔引入的可失效字面量**：`README.md` 与本文档里的"`origin/main` = `9a10db7`"改为**"push 时点"历史记录 + 现值现查命令**（写死 sha 与写死笔数是同一种病——同一个坑在两笔内踩了两次）；证据 `last_test_run.txt §AU`。 | 本文档 commit
* [2026-09-06] [Author] push 完成落账：`README.md` 与本文档 3 处"剩余动作 = 人类 push"改为**已完成 + 可复核证据**（`origin/main` = `9a10db7`、reflog `update by push`、双计数为 0）；订正"（+ CI）"**空指**（本仓无任何 CI 配置）；push 后证据落 `last_test_run.txt §AT`。 | 本文档 commit
* [2026-09-06] [Author] 账本自失效数字订正：`README.md` 与本文档 3 处写死的 `origin/main..HEAD = 37` 改为**现查命令**（写下该数字的提交自身即下一笔——与第 7 轮 9B 的 PB-1"写死数字必然过期"同类）；同时落新 tip 的双门复跑证据（`last_test_run.txt` §AS）。 | 本文档 commit
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
* **关闭阀状态**：① 第 3 轮那条 Product Blocking **已实质闭合**（两份独立实跑确认）；② 第 4 轮 9B 那条**已随处置闭合**（AC9 判定①在第 5 轮收口时废弃 → 归类问题不再有下游后果；见 §一 A1 与 §五）；③ 轮次账已 4 > 上限 3，**再开完整双审须人类再次逐次批准**（本收口轮为单审，不占双审轮次）。
* **合并门：关闭。** 第 5 轮 9A 报 **3 条 Product Blocking**（B-1 归因 `yes`）→ streak = 2 硬停；按 `AGENTS.md` → Fix-Loop 三者优先级 ②，**存在未解决 `[Product Blocking]` 时"限制交付"不含合并**。第 6 轮：9B **拒审**（无 verdict）、9A **不通过**（1 条 Product Blocking，归因 `dispute`）。**债台账见下节代码块**（**不在此写死数字**——第 7 轮 9B 的 PB-1 就是"本行写 6 笔而块内 7 条"导致合并门输入不唯一；写死数字必然随加账过期）。**核验方式**：`Select-String -Path docs/ai/HANDOFF.md -Pattern '^\[DEBT\]'` 的条数即当前笔数。**第 8 轮更新**：A3（第 5 轮 9A 的 B-2）已由人类裁决选 **2a** 落地（`f670fdc`）→ **随处置闭合**；**当前唯一未决的 Product Blocking 候选 = 第 7 轮 9B 的 PB-2**（AC4 判定脚本硬绑本机路径 vs 声称"可复制执行"，归因 `dispute`）→ **同日当场偿还**（`1e8832e`）→ **当前无未解决 `[Product Blocking]`，本门的阻断输入已清零**；`streak = 2` 仍为历史事实，不因处置回退。**是否合并 / 限制交付由人类决定**（2a 与 PB-2 这两处 review-sensitive delta 按人类 2026-09-06"不再开新审查轮"的裁决处理，与 AC4 改写出自人类裁决的既有先例一致）。

## Remaining Risks / Debt
```
[DEBT] AC4-门（档位取值域）的实现自身无机械完整性保护：AC6 是路径级谓词，已登记路径的内部修改零信号，削弱该脚本只能靠人工读 diff（2026-09-06 第 6 轮 9B 的 R6-B3）| Payback trigger: 下次改动 tools/ac4-reasoning-effort-check.ps1 之前；或下次由人类复核 dsh/** 判据面之前 | Impact: 一道机械门可在双门全绿的情况下被静默削弱
[DEBT] AC4 门的残余覆盖边界（**处置已定，本条只剩残余**）：人类 2026-09-06 选选项 **2a** → 谓词现已覆盖**两种拼写的赋值位**（`reasoning_effort` / `reasoningEffort`，门级负向对照见 `last_test_run §AQ`）；**残余 = 散文式取值陈述**（如 `` 9A/9B = `high` ``）仍不在域内——人类**未选 2b**，故已按"只声明赋值位"如实收窄声称（`TASK_BRIEF` → AC4「声称边界」），**不记为暗账** | Payback trigger: 若将来确有散文式取值写错、或有人主张本门覆盖散文式之前 | Impact: 散文面写错档位不会被任何机械门发现（实测散文行取值全为 `high`、**当前无活假绿**）
[DEBT] AC4 判定脚本的路径绑定——**已偿还**（2026-09-06 人类裁决"修路径推导 + 把声称改准"；`1e8832e`）：`$repo` 改为 `Split-Path -Parent $PSScriptRoot`，故**任意 checkout 均可执行**；`TASK_BRIEF` 的"可复制执行"同时改准（残余一条环境依赖：适配器取自 `%LOCALAPPDATA%\npm-cache\_npx\*`，**需本机存在 npx 缓存的 dsh 适配器**，找不到时报错退出、非静默通过）| Payback trigger: —（已偿还）| Impact: —（残余限度已写进 AC4 声称）。**本条目同时订正此前账目里的错误机制描述**：原文写"换 checkout 会在 `Set-Location` 处直接终止、拿不到 verdict"，**实测不成立**——同机异 checkout 下旧脚本**静默读错树并给出假绿**（副本 README 注入 `medium` 仍报 `AC4: PASS / exit=0`，原始输出 `last_test_run §AR ①`）；只有换到不存在该硬编码路径的机器才会终止。保留原文描述供对照：~~换 checkout/换机执行会在 `Set-Location` 处因 `$ErrorActionPreference='Stop'` 直接终止~~
[DEBT] AC6 对**未跟踪文件不可见**：其 scope 来自 `git diff --name-only <base>..HEAD`，而 `git diff` 不列未跟踪文件（2026-09-06 第 7 轮实测 VN-4：在 `tools/validate/` 下新建一个未登记且**未提交**的文件 → 判定仍 GREEN、`missing` 为空）| Payback trigger: 下次依赖"新增文件一定会被 AC6 拦住"这个假设之前 | Impact: 门只能在**提交之后**才发现漏登记；"提交前自查"这一步没有任何机械保证——本任务的 `.tmp-r6.ps1` 正是这样进过一次 tip
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
| 文档一致性 | **有限 Pass（收敛判定交人类）** | 唯一一处"说与做"不符（PB-2：声称"可复制执行" vs 脚本硬绑本机路径）**已偿还**（`1e8832e`；异 checkout 假绿对照见 `last_test_run §AR`）→ AC4/AC6 的声称 ↔ 实现已一致。**未核面**（`install.ps1` 其余注释、AC10 其余派生对）按 `[U]` 登记、**不声称已核**，故为"有限"而非"全绿"；**是否标"收敛"由人类决定**（本行按第 7 轮 9B 的"状态过期"意见刷新）。 |
| 依赖引入 | **Pass** | 未引入新依赖 |
| 设计层闸门(§5) | **N/A** | 无界面 |

## Quick-Version Fields
* Applicability Scan(0.1)：文档/配置类；改的是部署面与判据副本，故走完整双审。
* Human Approval Evidence：人类给出 ①发首轮 ②授权建 reviewable commit ③进入第 2 轮 / `high` / 先跑审查 / 补 TASK_BRIEF ④偿还债 #4（收窄 README 措辞）/ 跑第 3 轮 9A / 接受 Amendment。

## Next Step
**任务 A 与任务 B 分别收口；矩阵上的岔口已由 §五「人类裁决记录」全部收口，人类并已裁决「合并」** → 经核实本仓工作分支即 `main`，**本地无 merge 可做**；**人类已于 2026-09-06 完成 push**（推送一律由人类执行；**sha 与笔数不写死**——现查 `git rev-parse origin/main` 与 `git reflog show origin/main`；证据 `last_test_run.txt §AT/§AU`）→ **本任务不再有本机待办动作**。**唯一剩余的"动作"其实是状态而非动作**：在收敛门通过前不得标"已收敛"（AC4 的散文式残余 + AC11 的 `[U]` 清单须继续如实保留）；其余未决项全部是挂触发器的 `[DEBT]`（唯一权威 = 下方债台账，笔数现查：`Select-String -Path docs/ai/HANDOFF.md -Pattern '^\[DEBT\]'`）。

**立即执行顺序（四项均已执行：① 修 B-1 / ② 交付边界已冻结 / ③ 恢复 9B 并取得第一份有效 verdict / ④ 解答 VN-B）**：① 收口任务 A（把 `tools/ac4-reasoning-effort-check.ps1` 登记进 §2.1/§2.3，修 B-1）；② 按人类选择处理任务 B 的交付边界；③ **恢复 9B 双审**（第 5 轮我错误地让 9B 缺席，而 B-1/B-3 恰是盲审最易捞到的"改动副作用"型缺陷）；④ ~~解答 9A 悬置的 VN-B~~ —— **已解答**：Author 打开 `docs/ai/review_9A_r3.md` 核实，`:43` 确有"逐行读完 40 行变更、未发现判据/阈值漂移"→ **引用属实**（第 6 轮 9A 也据此撤回了该悬置项）。

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

## 待人类裁决（硬停后的岔口）—— **已全部收口：唯一权威见 §五「人类裁决记录」；本节保留供对照**

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

## 第 7 轮（9B 在干净 tip 上重跑）——目标项"两份 verdict"至此达成

**为什么这一轮必要**：第 6 轮 9B 因工作树不净**拒审**（Author 提交了 `.tmp-r6.ps1`），按契约"拒审 = 该轮审查没发生"，故不算 verdict。本轮 9B 在干净 tip 上重跑，取得**第一份有效的 9B verdict**。

**锚定**：`review_base_sha = 578ad39` → `review_tip_sha = 89d5cae`

### 9B 结论：不通过（2 条 Product Blocking，1 条归因 `yes`）

| 条 | 内容 | 归因 | Author 处置 |
|---|---|---|---|
| **PB-1** | **债台账在同一文件内自相矛盾**：合并门那行写"6 笔"而同块实为 7 条；`NOTES §3` 声称"与 `HANDOFF` 逐条一致"而两集合差 4 项；`last_test_run §AI` 却断言"计数自洽…达成" | **`yes`** | **已修**：合并门行**不再写死数字**（改为指向 `[DEBT]` 块 + 核验命令；写死数字必然随加账过期）；`NOTES §3` 的假声称订正为"同源但不等集、唯一权威是 `HANDOFF`"；`§AI` 改标"当时并未达成" |
| **PB-2** | **一条已知未修项在台账外 → 暗账**：`tools/ac4-reasoning-effort-check.ps1` 硬绑 `C:\Users\16097\Desktop\workflow`，而 `TASK_BRIEF` 两处写它"可复制执行"；两份台账**零登记** | `dispute` | **已登记**（新增一笔 `[DEBT]`，写明"只在本机 checkout 可执行"）；**是否修脚本、还是把声称收窄为"本机可执行"，属人类裁决** |

**9B 另纠正我三处数字**（均已采纳）：域内提及总数是 **20 处 / 18 行**（我写 23，错）；未捕获是 **13 处提及（11 行）**（我写成"13 行"）；真正"陈述取值"的未捕获行是 **4 行**（我写 6，"7+6=13"是把提及当行）。**方向结论不变**：赋值位 **7/7 全被覆盖**、当前**无活假绿**。

**9B 对"账本层能否收口"的独立结论：不能。** 其列举的未解决项（除 B-2 与 `[U]` 六项外）为：① PB-1 计数/集合不一致（**已修**）；② PB-2 暗账（**已登记，修法待裁决**）；③ `review_sensitive_paths` 缺 `tools`（**已补**）；④ 5 条 `dispute` 未裁 + 第 6 轮拒审的"事实被采纳但轮次按未发生计"这一混用未获确认（**待人类**）；⑤ `HANDOFF` 的"文档一致性 = Fail"行状态过期（未修）。

### 本轮同时完成的两件实质工作

1. **B-2 风险面量化**（`last_test_run §AL–§AO`）：把差集逐行分类，证明 7 行是键名提及/占位模板（本非赋值位）、4 行是散文式陈述且取值全为 `high`。**B-2 的真实风险是"未来写法可逃逸"，不是"现在有活假绿"**——比原描述窄得多。据此建议**收窄 AC4 声称**（而非加宽正则），依据全部落在 `last_test_run` 的原始枚举输出上。
2. **补齐 `review_sensitive_paths` 的 `tools`**（第 6 轮 9B 的 R6-S3）：该清单与 AC6 的 scope 此前对同一交付面给出两个定义。

### 本轮 delta 尚未重审（如实登记）

第 7 轮 9B 是在 `89d5cae` 上判的；其后 Author 又有多笔提交（账目对齐、暗账登记、数字更正、矩阵整理、账目数字订正）。按收敛门 ③，这些是 **review-sensitive delta**（含 `HANDOFF`/`NOTES`/`TASK_BRIEF` 的计数与集合定义）。**条数与本清单一律不在此写死**（写死必然随加账过期——第 7 轮 PB-1 的教训）；权威清单 = `git log --oneline 89d5cae..HEAD`。**是否再审由人类定**——9A 在第 6 轮已明确"这几条修完后不必再审一轮"。

## 裁决矩阵（2026-09-06，第 8 轮整理）—— 把岔口收敛到"真需要人判"的那几项

> **本节的用途**：此前的"待人类裁决"节把 5 条 `dispute` + 3 个岔口并列，读起来像 8 项都要人判。逐条核过之后，**其中 6 项已由后续事实自行闭合**，真正需要判断的只剩 **2 项**。本节给出每项的**判定依据与 Author 建议**（Author 无裁定权，建议仅供参考）。

### 一、5 条 `dispute`：逐条核，谁还需要判

| # | 条目 | 现状 | 需要人判吗 | 依据 |
|---|---|---|---|---|
| A1 | 第 4 轮 9B-B1（AC9 判定①按字面恒红） | **所指缺陷已不存在** | **否** | `TASK_BRIEF` 已不含该判定（实测 `-match '被禁模糊措辞做零命中扫描'` = False）；AC9 现标 `[O] 单点观测（**原判定方式已废弃**）`。**归类一个已废弃的判定**没有下游后果 → 建议直接记为"随判定废弃而闭合"。 |
| A2 | 第 4 轮 9B-NS-12 / 9A-S4（AC6 谓词只有路径级区分力） | **已按"收窄声称"处置** | **否** | AC6 条目已写明"路径级" + "**本任务不声称**"（两项实测为 True）；第 6 轮 9A 独立确认该表述"与谓词实际语义一致、无残留过度声称"。**归类不改变任何文本或门的行为** → 建议随处置闭合。 |
| A3 | 第 5 轮 9A-B2（AC4 门只覆盖声明域内的 7 处） | **已按人类裁决的选项 2a 落地**（谓词加宽到两种拼写 + 新增一条门级负向对照） | **否**（已裁） | 人类 2026-09-06 选 2a → 逃逸面已堵（`f670fdc`，原始输出 `last_test_run §AQ`）；**归类问题随处置闭合**（与 A1/A2 同一处理）；streak 仍记 2（历史事实，不因处置回退）。 |
| A4 | 第 5 轮 9A-B3（`HANDOFF` 的 `@` → `x`） | **已当场修** | **否**（归类可径判 `yes`） | 逐提交 blob 证据：`1c40e7a` = 4 个 `@`，`3f445b8a` = **0 个**（损坏由该 commit 引入），`578ad39` = 4 个（修复）。**A（由修复引入）与 B（修复未闭合）两套定义同向给出 `yes`** → 无需裁。 |
| A5 | 第 6 轮 9A-PB-1（合并门条目写"OPEN 候选"） | **已当场修**（现为"合并门：关闭"） | **否**（归类可径判 `yes`） | 同一文件同时写"streak=2 硬停"与"合并门是 OPEN 候选"——**是修复未同步造成的自相矛盾**，两套定义同向。 |

**结论**：5 条里 **A4、A5 可按 `yes` 径判**（两套定义同向）；**A1、A2 随处置闭合**；**只有 A3 真需要人判**。

### 二、A3 的实质：AC4 的 `[M]` 标记现在是否名不副实（**唯一需要判的 `dispute`**）

**已量化的风险面**（`last_test_run` §AL–§AO，原始枚举输出在案）：
* 域内 `reasoning_effort|reasoningEffort` 共 **20 处提及 / 18 行**；**赋值位 7/7 全部被门覆盖**，取值唯一 = `high`。
* 未捕获 11 行中，**7 行是键名提及或 `<…>` 占位模板**（本非赋值位），**4 行是散文式取值陈述**（取值全为 `high`）。
* **当前无活假绿**（`out-of-domain = (none)`、`adapter medium hits = 0`，两份 Reviewer 各自独立复现）。

**三个选项与后果**（**2026-09-06 第 8 轮修订**：原先把"驼峰键"与"散文式"捆成一项；`last_test_run §AP` 把两者拆开实测后代价差一个数量级，故拆成 2a / 2b）：
* **选项 1：收窄声称** —— 把 AC4 的域明确写成"只覆盖 `reasoning_effort: <未加引号小写>` 的**赋值位**；散文式与驼峰式取值不在覆盖内"。**代价**：AC4 从"全域声称"降为"赋值位声称"（仍保留 `[M]`——有命令、有退出码、有负向对照）；**代价之二**：`reasoningEffort: medium` 这类**驼峰赋值位**仍可走绿（实测：现正则对它是零命中），而 `reasoningEffort` 恰是 settings 层的**官方键名拼写**（`fanout-toolchain.md:50`），不是生造写法。
* **选项 2a（Author 现推荐）：把正则加宽到"两种拼写的赋值位"** —— 键名部分改为 `reasoning_?[Ee]ffort`、值域字符类改为 `[A-Za-z]`，其余逻辑一字不动。**代价**：**1 行改动 + 1 条门级负向对照**（写 `reasoningEffort: medium` → 必须 FAIL）；实测在全部域内文件上**新增命中 0 处、取值集合不变（仍只有 `high`）**（`§AP`）→ 不引入任何新的自由文本判据。**收益**：堵掉上面那条"官方拼写可逃逸"的口子，且**文案无需降级**——"枚举赋值位"这句话在两种拼写下都成立。
* **选项 2b（不推荐）：连散文式一起纳入** —— 覆盖 `` 9A/9B = `high` `` 这类陈述。**代价**：散文匹配天然脆（本任务 Author 自己的枚举脚本就因行号读错而失败一次）；会把"文档措辞"变成门禁对象。

**Author 建议：选项 2a**（修订前建议选项 1——那时把驼峰与散文当成同一代价；`§AP` 实测两者代价不同，故改）。依据全部是 `last_test_run §AM–§AN` + `§AP` 的原始枚举输出，不是推理。**人类若选 2a**：落地时须实跑那条负向对照并留原始输出，再重跑正向确认 `AC4: PASS / exit=0`；`§AP ④` 已如实标注"regex 级对照不代替门级实跑"。

**裁决（2026-09-06）**：人类选 **2a**，并裁**不再开新审查轮** → 已落地：正则加宽（`f670fdc`）+ 门级负向对照实跑（`last_test_run §AQ`）+ AC4「声称边界」写明"散文式不在域内"。**选项 1 / 2b 均未采纳**（1 的对照说明保留在上一段，不删）。

### 三、3 个岔口：逐条核，谁还需要判

| # | 岔口 | 需要人判吗 | 说明与建议 |
|---|---|---|---|
| B1 | 任务 B 的交付边界是否现在冻结 | **已裁：现在冻结** | 人类 2026-09-06 按建议冻结 → 边界文字已写入 `TASK_BRIEF.md`「判据白名单」节末（**机读登记表 §2.3 + AC4/AC6 两个 `[M]` 门 + AC9 的 `[O]` 读点 + `HANDOFF` 唯一债台账**；边界外一律 `[U]`，不再新增判据/登记表/AC）。 |
| B2 | B-2 的处置方向 | **是**（= 上面 A3，同一项） | 见 §二。 |
| B3 | 第 6 轮 9B 的拒审是否按"该轮审查没发生"处理 | **Author 已在 §四 记录一致性裁决，供人类否决** | 见下。 |

### 四、Author 对 B3 的一致性处理（记录，人类可否决）

**问题**（第 6 轮 9A 的 S8 提出）：账目一边写第 6 轮 9B"因工作树不净**拒审（无 verdict）**"，一边以"**第 6 轮 9B 的 R6-B3/R6-S1**"作为两处订正的依据。按契约"拒审 = 该轮审查没发生"，两者不能同时为真。

**Author 的处理（区分两种内容，并写明理由）**：
* **不算 verdict / 不计轮次**：该轮不产生 `Review Verdict`，不计入双审轮次（第 6 轮记 9B = 拒审）。
* **但它的机械事实可用**：R6-B1/B2/B3 与 R6-S1 中**可机械复核的事实**（`.tmp-r6.ps1` 的 blob 与逐提交存在性、`git status --porcelain` 输出、`AC6 差异项 = 0`、逐行枚举计数）**属"任何人可重跑的命令输出"，不是"审查结论"**——Author 采信的是**自己复跑后的结果**（每处都在 `last_test_run` 留了原始输出），引用它们时标注了出处，未把"该轮 verdict"当作成立的前提。
* **边界**：该轮**没有任何归类、归因或 blocking 判定**被计入（其 Blocking 三条当时即写明"本轮不计"）。若人类认为"连事实也不该引用"，**Author 接受否决**——届时 R6-B3/R6-S1 所指的两处订正须改为仅凭 Author 自跑的证据重新确立（证据已在案，改的是引用出处，不是结论）。

**为什么值得记这一笔**：这是本任务唯一一次"审查轮被作废、但它的事实被采用"，属于过程口径问题；不写清就会在下游被读成"作废的轮次仍算数"。

## 五、人类裁决记录（2026-09-06，第 8 轮）—— 矩阵上的岔口至此全部有裁

| 项 | 人类裁决 | 落地位置 |
|---|---|---|
| **A3**（AC4 覆盖边界） | **选项 2a**：正则加宽到两种拼写的赋值位 | `f670fdc`（正则 1 行 + 英文注释 1 行）+ `last_test_run §AQ` + `TASK_BRIEF` AC4「声称边界」 |
| **B1**（任务 B 交付边界） | **现在冻结**（按矩阵建议的 4 项边界） | `TASK_BRIEF.md`「判据白名单」节末的冻结段 |
| **C**（第 7 轮 verdict 之后的 delta 是否再审） | **不再开新审查轮**；2a 的配套证据 = Author 的门级负向对照实跑 | 本文件 + `last_test_run §AQ` |
| **A4 / A5** | 按 `yes` **径判**（呈报时写明"无异议即照此记录"，人类未异议） | 本文件 §一 表 |
| **A1 / A2 / A3 的归类** | **随处置闭合**（呈报时同上，人类未异议） | 本文件 §一 表 + §二 |
| **B3**（第 6 轮 9B 拒审的处理口径） | **按 Author 的一致处理记录**（不计 verdict / 不计轮次，其可机械复核的事实按 Author 复跑采信）；人类保留否决权 | 本文件 §四 |

**因此**：矩阵上的 5 条 `dispute` + 3 个岔口**至此全部有裁 / 有处置**——最后一项 **PB-2** 也按人类裁决当场偿还（`1e8832e`；它的 Payback trigger 正是"下次改动该脚本之前"，而 2a 刚改动过它；原始输出 `last_test_run §AR`，其中"异 checkout 假绿"对照同时订正了此前账目对该失效形态的错误描述）。**当前无未解决 `[Product Blocking]`**；`streak = 2` 作为历史事实保留。**下一步 = 人类决定"合并"还是"限制交付"** → 见下。

**（二）合并裁决（2026-09-06）**：人类选 **合并**。**并附一处事实更正**——此前把本任务当作"侧分支待合"，经核实**本仓的工作分支就是 `main`**：`main..HEAD = 0`、`HEAD..main = 0`、`origin/main..HEAD` 为正（`origin/main` tip = `bf06c65`；**笔数现查** `git rev-list --count origin/main..HEAD`，**不写死**——原文写 37，而本行所在的这笔提交自身就是下一笔）。**因此本地没有任何 merge 动作可做**；~~剩余动作 = **人类 push 到 `origin/main`（+ CI）**~~（该"剩余动作"**已于同日完成**，见下（三）；且其中"（+ CI）"是**空指**——本仓无任何 CI 配置）。本仓契约明令 agent 绝不做远程操作，故推送只能由人类执行。**若届时改主意**：领先 `origin/main` 的这批提交可整体回退（`git revert` 逐笔，或把 `main` 重置回 `origin/main`）。**push 之后仍不得标"已收敛"**：AC4 的散文式残余 + AC11 的 6 项 `[U]` 须在 README / HANDOFF 如实保留。

**（三）push 完成（2026-09-06）**：人类执行 push 后，本机核验**当时** `main` = `HEAD` = `origin/main` = `9a10db7`（`origin/main..HEAD = 0`、`HEAD..origin/main = 0`、`git branch -vv` 显示 `[origin/main]`），`git reflog show origin/main` 首条为 `update by push`，工作树干净——**原始输出见 `last_test_run.txt §AT`**。**本节只作"push 时点"的历史记录**：此后人类又完成一次 push，`origin/main` 的**当前值一律现查** `git rev-parse origin/main`（第二次 push 的核验、以及本节原文那个"写死 `origin/main` = `9a10db7`"字面量的订正，见 `last_test_run.txt §AU`）。**一处如实订正**：本行原文与 README 同段写的"（+ CI）"是**空指**——本仓**没有任何 CI 配置**（无 `.github/` 或其他流水线文件），push 不会触发流水线。**这是本地 ref 证据，不是对 GitHub 的网络回读**：本仓契约禁止 agent 做任何远程操作（含 `fetch`/`ls-remote`），故"远端确实收到了"这一点由人类陈述 + 本机 `update by push` 共同担保，**agent 未独立复核远端**。

