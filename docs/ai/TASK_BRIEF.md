# TASK_BRIEF.md

> per-task 需求与验收的唯一落点。**本文件是事后补写的**（见「补写说明」），用于修补本任务跳过批准门与 9P 计划审造成的流程缺口。

## 补写说明（如实登记）

> **Amendment 记录（2026-09-06，第 2 轮双审后）**：第 2 轮 9A 的 S7 判定 AC4/AC6 的判定方式按字面不可满足/会假红，AC1/AC8/AC9 属"散文对读"。处置：**AC4 与 AC6 已改写为可执行形态**（限定输入域 + 具体命令 + 反例实跑）；**AC1 保持原判据但判为"本轮只可抽样核验"**——它要求"17 对派生文件逐条一致"，Author 与 Reviewer 都只做了抽样（全量需逐条人工读 2600+ 行），按「验收条款必须可复现判定」这属于**证据面不足而非未满足**；它**不作为阻止合并的 AC**，改列本任务的 Known Limitation。
> **人类裁决（2026-09-06）：按 Author 建议接受本 Amendment**（AC4/AC6 改写为可执行判定；AC1 降为 Known Limitation）。按收敛门 ③(c)，验收条款的修订出自人类裁决 → 该 delta 不使既有审查失效。本任务由人类在对话中直接下达（"将我这套本应用于 claude code 和 codex 的工作流作用于 dsh，但是 Author 和 Reviewer 都是 deepseek/dsh"），Author **直接进入实现**并落 commit，未走 `/plan`、未产出 TASK_BRIEF、未跑 9P、未取得计划批准门——因此首轮双审是在**没有需求文件**的情况下进行的（两份 prompt 里的 Frozen Acceptance 由 Author 当场写入 prompt）。人类在首轮双审后裁决"补一份 TASK_BRIEF 含本任务 Frozen Acceptance"，本文件即该裁决的产物。

**这修补的是流程缺口，不是给已完成的实现补一张事后授权单**：首轮双审的 verdict（9A/9B 均"不通过"）与 Fix-Loop 计数不因本文件而改变；本文件的作用是让**第 2 轮修补**有可对照的验收基线。

## Goal

让本仓的双 Agent 工作流可在 **DeepSeek Harness（DSH）** 上运行，且 **Author 与 Reviewer 都是 deepseek/dsh**；既有的 Claude Code × Codex 落地保持不动。

## Summary（推荐方案）

骨骼由 `claude/` 一侧**机械复制**，再做**有界 DSH 化改点**（改点必须逐条登记），另新增 DSH 特有的执行面文件。理由：两套落地必须共享同一套判据与阈值，逐字重打一遍必然产生悄悄的分歧；机械复制 + 有界改点让"哪里不一样"可 diff、可复核。

**明确不采用**：① 从零重写一份 DSH 工作流（判据必漂移）；② 只写一份便携 prompt 不做结构化落地（DSH 有 skill 发现面，可用按需加载换取常驻 token）；③ 改动 `claude/` 一侧去迁就 DSH（会把两套落地焊死成一套，且 DSH 化的事实对 Claude 侧是错的）。

## Current Architecture Understanding

* `claude/`（Claude Code 侧工作流母本 + `CLAUDE.md` 全局指令）、`codex/`（Codex 侧长期规则）、`portable/`（便携单文件版）、`install.ps1`（唯一的可执行部署面，**受迁移期 guard 锁定**）。
* 受管部署面 = 部署器持续镜像/覆盖的路径（`~/.claude/{rules,workflow,commands}`、`~/.codex/AGENTS.md`）；`~/.codex/config.toml` 是 seed-only。
* DSH 侧事实（一手来源：`@deepseek-ai/dsh` 0.1.5-rc.x 包内 README/lib）：每会话必载的用户全局指令 = `$DSH_HOME/AGENTS.md`；skill 发现根含 `<dshHome>/skills`（只认 `<name>/SKILL.md` 与顶层 `<name>.md`，**嵌套 `**/SKILL.md` 故意不发现**）；委派三面 = `subagent`（fresh context）/ `subagent_fork`（继承本会话）/ `workflow`；模型档位枚举 = `off/low/high/max`；`subagent` 的模型选择受宿主 `subagent-model-selection.allowedModels` 约束。
* 关键差异：**DSH 没有 Codex 那种进程沙箱兜底**——Reviewer 同机同权限，技术上写得到仓库。

## Proposed Changes

| # | 文件 | 性质 | 内容 |
|---|---|---|---|
| 1 | `dsh/AGENTS.md` | 新增 | DSH 每会话必载的全局入口（路由 / 角色与写权 / Safety 红线 / Fan-out 上限 / Configuration Hierarchy） |
| 2 | `dsh/workflow/AGENTS.md` | 派生 + 有界改点 | DSH 侧判据唯一出处 |
| 3 | `dsh/workflow/reviewer-prompt.md` | 派生 + 有界改点 | 9P/9A/9B prompt、输出契约、双审隔离协议、DSH 调用形态 |
| 4 | `dsh/workflow/fanout-toolchain.md` | 新增 | DSH 工具面事实（委派三面、参数、白名单、派发上限、失败语义） |
| 5 | `dsh/workflow/{index,QUALITY_GATES,workflow-design-notes}.md`（有文本改点）与 `AB-model-diagnostic.md` + `templates/`（**逐字节未改，见 `DSH-LANDING-NOTES` §2.2**） | 派生 | 导航 / 质量清单 / 设计说明 / 模板 |
| 6 | `dsh/skills/dual-agent-workflow/**` | 新增 | 路由技能 + 7 个 phase 正文 + 两份执行手册 |
| 7 | `dsh/skills/independent-review/**` | 新增 | 审查执行手册 |
| 8 | `portable/通用prompt-DSH-v1.txt` | 新增 | DSH 便携单文件版（与 v3.8 同族并列） |
| 9 | `install.ps1` | 修改 | 新增 DSH 部署段 |
| 10 | `README.md` / `AGENTS.md` / `docs/ai/AUTHORITY_CONTRACT.md` / `docs/ai/DSH-LANDING-NOTES.md` | 修改/新增 | 布局表、受管面契约、改点清单与债登记 |

## Acceptance Criteria（Frozen Acceptance；本任务的验收基线）

> **本节的形态由人类 2026-09-06 裁决确定（第 4 轮之后）**：四轮双审的 finding **全部**落在"改点登记表 + 验收条款判定方式"这一层，且**每一轮的修复又在这同一层新增了新的不可执行判定**（第 3 轮修好 AC6、同一份 Amendment 写坏 AC9；第 4 轮又发现 AC6 的第二条反例指向谓词永不读取的节）。人类裁决：**按 Author 建议收口**——不再新增自由文本判据，把每条 AC 归入下面三级之一。
>
> **判据白名单（封闭，不得增补）**：
> * **[M] 机械门**——有可复制命令 + 真实退出码 + 已实跑的负向对照。**本任务只设两个机械门：AC6 与 AC4-门。**
> * **[O] 单点观测**——只声称"做过一次并留了产物"，**明确不推广为"不存在"**。
> * **[U] 未验证**——如实登记为未验证，附触发时机。**[U] 不是债**，故不要求 Payback trigger；但**不得**被写成"已验证"。
>
> 本条元规则自身的要求：**任何 AC 若无法归入 [M]/[O]/[U] 之一，必须当场收窄声称，而不是新造一条判据。**（"针对该要求的新判据"即为被禁的第三层判据。）

### AC1 — 一等公民与判据一致性 → **[O] 单点观测（声称已收窄）**

仓内出现 `dsh/`，与 `claude/`、`codex/` 并列；`dsh/workflow/AGENTS.md` 是 DSH 会话的判据唯一出处。
**判定**：`claude/workflow/AGENTS.md` ↔ `dsh/workflow/AGENTS.md` 这一对，`git diff --no-index -U0` 的全部 **40 行**变更（25 增 15 删）逐行归类。
**产物**：第 3 轮 9A 全量核验（`docs/ai/review_9A_r3.md:43`）"**未发现判据/阈值漂移**"；第 4 轮 9A 独立复跑同 40 行，结论一致。
**收窄后的声称**：**这一对文件**已核；**本任务不声称**其余派生对（`reviewer-prompt.md` / `QUALITY_GATES.md` / `index.md` / `workflow-design-notes.md` / 7 个 phase）无漂移——那需要逐对人工读，本任务未做（见 AC11 [U]）。

### AC2 — skill 可加载 → **[O] 单点观测**

`dsh/skills/` 下的 bundle 能被 DSH 的 skill 发现面加载。
**产物**：首轮与本机实测——把 bundle 放进 `<dshHome>/skills/` 后，**fresh DSH 会话的技能目录里确实出现它**（`docs/ai/DSH-LANDING-NOTES.md` §5）。**不是**靠读包内 README 推断。
**收窄后的声称**：本机一次观测成立；不声称在所有部署形态下成立。

### AC3 — 两条 Reviewer 路径 → **[O]（主路径）/ [U]（备用路径端到端）**

主路径 = 同会话 `subagent` 前台调用（显式 `provider`/`model`/`reasoning_effort`）；备用路径 = 独立 `dsh --profile headless` 进程。
* 主路径：**[O]** —— 本轮起已用它跑过 **4 轮共 8 次**真实审查调用（verdict 已落账）。
* 备用路径 CLI 面：**[O]** —— `npx -y @deepseek-ai/dsh --profile headless --help` 实测只有 `-h/--help` 与 `[task...]`，`exit=0`（`last_test_run.txt` §J）。
* 备用路径**完整审查轮**：**[U]** —— 从未跑过（见 AC11）。

### AC4-门 — 档位取值域 → **[M] 机械门（本任务两个机械门之一）**

**输入域**：仅 DSH 面（`dsh/**`、`portable/通用prompt-DSH-v1.txt`、`README.md`）；**排除** `claude/**` 与 `portable/通用prompt-v3.8.txt`（那里的 `medium` 属 Codex 侧 `model_reasoning_effort`，合法）。
**判定命令（可复制执行，脚本已入库）**：`pwsh -File tools/ac4-reasoning-effort-check.ps1` → 枚举上述范围的 `reasoning_effort` 赋值位，每个值必须 ∈ `{off, low, high, max}`；且适配器 `dsh-llm-deepseek/lib/index.js` 中 `"medium"` 零命中。任一不满足即 `exit 1`。
**产物（真实退出码）**：正向 `DSH-side values = high / out-of-domain = (none) / adapter medium hits = 0 → AC4: PASS, exit=0`。
**负向对照（已实跑）**：把 `dsh/workflow/fanout-toolchain.md` 的 `high` 改成 `medium` → `DSH-side values = high, medium / out-of-domain = medium → AC4: FAIL, exit=1` → 还原并确认工作树干净。→ **有区分力。**
**一手来源断言**：`deepseek-flash` = DeepSeek-V4.1-Flash 及旧 id 路由状态，指回 [DeepSeek 官方公告 2026-09-10](https://api-docs.deepseek.com/zh-cn/news/news260910/)（次级来源不作采纳依据）。

### AC5 — 零写入闭环 → **[O] 单点观测**

verdict 契约含 `writes_performed` 与 `model_route`；三份 prompt 都要求；Author 侧明确"落盘由 Author 在窗口结束后做"。
**产物**：4 轮 8 份 verdict 的 `writes_performed` 全为 `none`（其中 9A 第 3 轮**主动登记**了一处仓外 scratch 越界；9B 第 3 轮主动登记了一次 `git grep` 回显）。**自证字段，无机械手段可证**——这一限度已写进契约。

### AC6 — 改点登记 → **[M] 机械门（本任务两个机械门之一）**

**判定依据**：`docs/ai/DSH-LANDING-NOTES.md` → **§2.3 机读登记表**（`- path:` 行）。
**钉死的 base**：`bf06c65d0831ebeb2b0982f35ae2d7f4c65c2c17`。
**判定命令（可复制执行）**：
```powershell
$base = 'bf06c65d0831ebeb2b0982f35ae2d7f4c65c2c17'
$notes = Get-Content docs/ai/DSH-LANDING-NOTES.md -Raw
$reg   = [regex]::Matches($notes, '(?m)^- path:\s*(\S+)\s*$') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
$scope = git -c core.quotepath=false diff --name-only "$base..HEAD" -- dsh portable install.ps1 AGENTS.md README.md docs/ai/AUTHORITY_CONTRACT.md docs/ai/DSH-LANDING-NOTES.md docs/ai/TASK_BRIEF.md | Sort-Object -Unique
$missing = $scope | Where-Object { $_ -notin $reg }   # 改了却没登记
$stale   = $reg   | Where-Object { $_ -notin $scope } # 登记了却没改
if ($missing -or $stale) { $missing; $stale; exit 1 } else { 'AC6: register == scope'; exit 0 }
```
**三条纪律**：① `core.quotepath=false` **必带**（否则非 ASCII 路径被转义 → 假红）；② 谓词**只读 §2.3 的 `- path:` 行**，不得用"文件名是否出现在文档里"（无区分力）；③ 判定前确认工作树干净（`$reg` 读工作树、`$scope` 读 HEAD）。
**产物**：正向 `reg=30 scope=30 → GREEN, exit=0`；**三条负向对照已实跑且全红**（`last_test_run.txt` §Q）：删登记行→`$missing` 报该文件；改登记路径→`$missing`+`$stale`；加幻影行→`$stale`。
**声称边界（第 4 轮两份 verdict 独立确认，已据此收窄）**：本门保证的是**路径级**覆盖——**已登记路径内部**的未登记内容改动**检不出来**（例：往 `dsh/workflow/index.md` 加一行未登记进 §2 #9 的判据文本 → 判定仍 GREEN）。**本任务不声称"覆盖全部实际变更"**，只声称"覆盖交付面的路径集合"。

### AC7 — 说与做一致 → **[O] 单点观测**

`install.ps1` 注释、`README.md`、`AUTHORITY_CONTRACT.md`、`DSH-LANDING-NOTES` §4 对"镜像哪些路径 / 不碰哪些机器态"的描述必须与代码一致。
**产物**：第 3 轮两份 verdict 各自**逐句核对**了 `README:17/21` ↔ `install.ps1` 的备份语义，确认无反向过度声称。**收窄声称**：只核了备份/镜像语义这一组；`install.ps1` 的**其余**注释未逐句对读（第 3/4 轮各发现 1 处残留 clause，已登记）。

### AC8 — 机器态不被修改 → **[U] 未验证（附触发时机）**

`~/.dsh` 下的 `settings.yaml`、`sessions/`、`storages/`、`.credentials.yaml`、`profiles/` 不被部署动作**修改或删除**（**注意**：整树备份会把它们**复制**一份到 `~/.dsh.bak-<stamp>`，见 README）。
**触发时机**：`install.ps1` 解锁后首次实跑（临时 HOME / 一次性 profile 下比对三项哈希）。
**现状**：只有静态读码核验；脚本受迁移期 guard 锁定，**从未运行**。

### AC9 — 如实标注 → **[O] 单点观测（原判定方式已废弃）**

未经审查 / 未实跑 / 未验证的东西必须写成未验证；不得把"未做"写成"已验证"。
**原判定方式（已废弃，如实登记）**：① "被禁模糊措辞零命中扫描"——**第 4 轮 9B 与 9A 各自独立判定它按最自然范围恒红**（交付面含禁令原文引用，10 处命中，其中 8 处是母本判据自身）；**它从未被执行过**。② "与 `[DEBT]` 清单逐条对应"——**两集合零交集**，按字面不可满足。两条均已删除，不再作为判据。
**现行判定**：**人工单点读** `docs/ai/HANDOFF.md` 的 Known Issues / Remaining Risks 与 `docs/ai/DSH-LANDING-NOTES.md` §5 的"未做/未验证"节，确认二者一致且无"未做写成已验证"。
**产物**：第 4 轮 9A 独立读后结论"本轮未新增隐藏债；`§3` 四笔与 `TASK_BRIEF` 四笔计数一致"。

### AC10 — 判据无漂移 → **[O] 单点观测（声称已收窄）**

**判定对象**：与 AC1 相同的那一对文件，用 `git diff --no-index -U0`（**不是 `--numstat`**——该命令不输出变更行，支撑不了逐行归类，第 4 轮 9A 的 R4-S6）。
**产物**：两轮 9A 独立逐行核验，结论"无判据/阈值/轮次漂移"。
**收窄后的声称**：**只覆盖 `dsh/workflow/AGENTS.md` 这一对**（与 AC1 同一产物）。本任务**不声称**其余派生对无漂移——那是 [U]（见 AC11）。
**`docs/ai/QUALITY_GATES.md` 指针面**：**已停止复述数字**（第 3/4 轮各因复述而出错一次）；如需核，直接读 `dsh/workflow/reviewer-prompt.md` 的对应处与母本比对，**不以本文档的复述为准**。

### AC11 — 未验证清单 → **[U] 汇总（不是债，故无 Payback trigger）**

以下在本任务内**未验证**，如实登记，附触发时机：
1. 除 `AGENTS.md` 外的**其余派生对**（`reviewer-prompt.md` / `QUALITY_GATES.md` / `index.md` / `workflow-design-notes.md` / 7 个 phase）相对母本是否存在判据漂移 —— 触发：下一次改动任一该文件之前。
2. **备用路径（headless）完整审查轮** —— 触发：首次用备用路径发审之前。
3. **真实 9P 审查轮**（两次都只是档位探针）—— 触发：下一次启用 Critical 之前。
4. **`~/.dsh/settings.yaml` 的 `reasoningEffort` 是否真被适配器读取**（现只有 schema 层证据）—— 触发：首次依赖 settings 层钉档位之前。
5. **AC8 的机器态实跑**（见 AC8）。
6. **`install.ps1` 的其余注释逐句对读**（见 AC7）。
**本清单与 `docs/ai/DSH-LANDING-NOTES.md` §5 的"未做/未验证"节必须逐条一致**（这是 AC9 现行判定的人工读点之一）。
## Risks & Edge Cases

* **最大风险 = 判据漂移**：机械复制 + 人工改点的边界靠人自觉；首轮双审已实测出三类清单外变更（含 2 处指针漂移）。缓解：§2/§2.1 完整登记 + 逐对 diff 作为审查输入。
* **同模型双审的独立性只剩一层**：Codex 时代靠"换模型"提供第二层保险，DSH 下 Author 与 Reviewer 同为 `deepseek-flash`，独立性**完全**来自上下文隔离。若主/备用路径的档位漂移，就没有第二道保险 → 用 `model_route` 自报字段提高可见性（并如实标注它不可被验证）。
* **安装器无法演练**：受迁移期 guard 锁定，只能静态核验 → 验收 8 标注为"未实跑"。
* **不可逆面**：`~/.dsh` 是本机 harness home（含会话与凭据），部署动作一旦写错影响面大于普通仓库改动 → 采用"镜像受管路径 + 绝不触碰机器态"的最小面，并把整树备份的副作用登记为债。

## Execution Steps

1. 机械复制骨骼 + 有界 DSH 化改点。 | `a361bc19`
2. **第 1 轮**双审 → 两份"不通过"（4 + 3 条 Product Blocking）。 | 落账 `7c5505f`
3. **第 2 轮修补**：修首轮全部 Product Blocking；9P 档取 `high`（人类裁决）；补本 TASK_BRIEF。 | `7084fb75`
4. **第 2 轮**双审 → 两份"有条件通过"（Blocking = None）→ streak 归 0。 | 落账 `956db71`
5. **第 3 轮修补**：偿还 installer 债（收窄 README 措辞）+ 修 9B-S1。 | `34b6037`
6. **第 3 轮**双审 → 9B「不通过」（AC6 按字面仍红）、9A「有条件通过」（同条判 Suggestion）→ 归类分歧交人类。 | 落账 `40c61bb`
7. **人类裁决 9B 归类成立 → 第 4 轮修补**：登记表改为机读形态（§2.3）、AC6 判定命令重写并实跑正例 + 三条负向对照。 | `fc32899`
8. **第 4 轮**双审 → 9A「有条件通过」、9B「不通过（1 条，归因 `dispute`）」。**该轮又暴露：同一份 Amendment 把 AC9 的判定写坏（未定义 scope → 恒红、从未执行），并让 AC6 的第二条反例指向了谓词永不读取的节。** | 落账 `1c40e7a`
9. **人类裁决（2026-09-06）→ 收口轮（本段）**：**停止在文本层继续加判据**，按 `[M]/[O]/[U]` 三级重写全部 AC；只保留 **AC6 与 AC4-门两个机械门**；废弃 AC9 的两条坏判定；把"其余派生对无漂移"等未核面显式列为 `[U]`。 | 见 HANDOFF
10. **收口后的 9A 单审**（不新开 9B 轮：本次 delta 全是 AC 文本与登记表修正，9B 的盲审面未受影响）→ 由人类决定 commit/merge 或走限制交付。 | —

## Testing Plan

* 无功能测试套件。核验 = 机制命令 + 真实输出，落 `docs/ai/last_test_run.txt`。
* **两个机械门的脚本/命令**：AC6 = 本文件内嵌的 PowerShell 判定块；AC4-门 = `tools/ac4-reasoning-effort-check.ps1`。
* 已完成的实跑：`high` 探针成功（§H）、**`medium` 被拒的负向对照**（§M，原始报错原文）、headless `--help`（§J）、`~/.dsh` 23/23 同副本（§K/§O）、**AC4 字面命令与负向对照**（§R，`PASS/exit=0` ↔ `FAIL/exit=1`）、**AC6 判定与三条负向对照**（§Q）。
* **逐对 diff 审计（17 对派生文件）已降级**：本任务只对 `AGENTS.md` 那一对做了全量逐行核验（AC1/AC10 的 [O] 产物）；其余派生对的逐对审计列为 AC11 `[U]`，**不再声称**为"判据无漂移"的机械输入。

## Open Questions

**None**。人类自首轮起逐条裁决：进入第 2 轮 / 9P 档 = `high` / 先跑审查 / 补 TASK_BRIEF / 偿还 installer 债（收窄 README 措辞）/ 跑第 3 轮 9A / 接受 Amendment / **采纳第 3 轮 9B 的 Product 归类并再跑一轮** / **2026-09-06 按 Author 建议收口 AC 分层**。

## Human Approval Status

- Status: **N/A — 本任务的批准门在实现后才补**（人类在首轮双审后裁决"进入第 2 轮修补"即为对本 TASK_BRIEF 验收基线的事实批准；**未经** `Status: Approved` 形式的正式批准 commit）
- Approved by: N/A
- Date: N/A
