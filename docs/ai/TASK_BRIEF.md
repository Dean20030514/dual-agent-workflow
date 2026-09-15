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

1. **一等公民**：仓内出现 `dsh/`，与 `claude/`、`codex/` 并列；`dsh/workflow/AGENTS.md` 是 DSH 会话的判据唯一出处，且**与 `claude/workflow/AGENTS.md` 的判据、阈值、轮次上限逐条一致**（只允许"怎么跑"不同）。**判定方式（Amendment 2026-09-06 第 4 轮：原表述属"散文对读"，且底下的降级理由张冠李戴）**：判定对象 = **`claude/workflow/AGENTS.md` ↔ `dsh/workflow/AGENTS.md` 这一对文件**；判定 = `git diff --no-index --numstat` 的**每一条变更行**都能归入 §2 第 1–6 条或 §1 第 2 步的机械路径改写，且**未触及任何判据、阈值、轮次上限**。**第 3 轮 9A 已按此做过一次全量核验并给出"无漂移"结论**（40 行变更逐行读完）；本条**不要求**核验全部 17 对派生文件——那是 AC10 首句的活（见该条）。
2. **可加载**：`dsh/skills/` 下至少一个 bundle 能被 DSH 的 skill 发现面加载（判定方式：把 bundle 放进 `<dshHome>/skills/` 后，一个 fresh DSH 会话的技能目录里出现它；**不是**靠读包内 README 推断）。
3. **两条 Reviewer 路径**：主路径 = 同会话 `subagent` 前台调用，显式 `provider`/`model`/`reasoning_effort`；备用路径 = 独立 `dsh --profile headless` 进程。**两条路径给出的命令都必须真的能跑**（判定方式：主路径产生过真实 verdict；备用路径的 CLI 面经 `--help` 或实跑确认）。
4. **模型档可指回一手来源**：Author 与 Reviewer 的模型/档位断言必须能指回官方公告、`list_subagent_models` 的实时返回或包内 `DEFAULT_MODELS`；**不得凭记忆**。所有写进文档的 `reasoning_effort` 取值必须落在适配器取值域（`off/low/high/max`）内。**判定方式（Amendment 2026-09-06，第 2 轮 9A 的 S7 指出原表述会假红）**：
   * 输入域 = **仅 DSH 侧面**：`dsh/**`、`portable/通用prompt-DSH-v1.txt`、`README.md` 的 DSH 段；**明确排除** `claude/**` 与 `portable/通用prompt-v3.8.txt`（那里的 `medium` 属 Codex 侧 `model_reasoning_effort`，合法）。
   * 判定命令：对上述范围枚举 `reasoning_effort` 的**赋值位**，每个值都必须 ∈ `{off, low, high, max}`；且 `Select-String -Path <dsh-llm-deepseek>/lib/index.js -Pattern '"medium"'` 零命中。
   * **反例（负向对照，必须实际跑过一次并留产物）**：把 `dsh/workflow/fanout-toolchain.md` 的 `high` 临时改成 `medium` → 上述判定必须红（退出码非 0）→ 还原并确认 `git status --porcelain` 为空。
5. **零写入闭环**：verdict 契约含 `writes_performed` 字段；三份 prompt 都要求它；Author 侧明确"落盘由 Author 在窗口结束后做"；零写入违反 = 该轮作废。
6. **改点可复核**：`docs/ai/DSH-LANDING-NOTES.md` 的改点登记**覆盖全部实际变更**。**判定方式（Amendment 2026-09-06 第 2 轮：原表述含不可满足项；Amendment 2026-09-06 第 4 轮：`<base>` 未钉死 → 红集合随 base 变，且声明表本身缺机械复制面。两次都由 9B 的 B1 指出）**：
   * **钉死的 base**：`BASE_SHA = bf06c65d0831ebeb2b0982f35ae2d7f4c65c2c17`（本次改动前的 `main` tip）。**不写 `<base>` 占位符**——红集合若不锚定就不可复现。
   * **交付面**（判定范围，逐字）：`git diff --name-only $BASE_SHA..<tip> -- dsh portable install.ps1 AGENTS.md README.md docs/ai/AUTHORITY_CONTRACT.md docs/ai/DSH-LANDING-NOTES.md docs/ai/TASK_BRIEF.md`
   * **判定谓词**：上列输出的**每一项**都必须出现在 `DSH-LANDING-NOTES.md` → **§2.3 机读登记表**的 `- path:` 行里（**§2.3 是 AC6 的唯一判定依据**；§2 / §2.1 / §2.2 是它的散文说明与理由）。**双向**：scope 的每一项都要在表里（漏登记 = 红），表里的每一项也都必须在 scope 里（登记了却没改 = 表与事实脱节 = 红）。
   * **判定命令（可复制执行）**——读 §2.3 的机读表（**`dsh/workflow/` 不在 scope 里，是因为它的改动全部由 §2 派生面覆盖；scope 见上**）：
     ```powershell
     $base = 'bf06c65d0831ebeb2b0982f35ae2d7f4c65c2c17'
     $notes = Get-Content docs/ai/DSH-LANDING-NOTES.md -Raw
     $reg = [regex]::Matches($notes, '(?m)^- path:\s*(\S+)\s*$') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
     $scope = git -c core.quotepath=false diff --name-only "$base..HEAD" -- dsh portable install.ps1 AGENTS.md README.md docs/ai/AUTHORITY_CONTRACT.md docs/ai/DSH-LANDING-NOTES.md docs/ai/TASK_BRIEF.md | Sort-Object -Unique
     $missing = $scope | Where-Object { $_ -notin $reg }      # 改了却没登记
     $stale   = $reg   | Where-Object { $_ -notin $scope }    # 登记了却没改
     if ($missing -or $stale) { $missing; $stale; exit 1 } else { 'AC6: register == scope'; exit 0 }
     ```
     **两条纪律**：① `core.quotepath=false` **必带**——否则非 ASCII 路径（`portable/通用prompt-DSH-v1.txt`）会被 git 转义成 `\351\200\232…`，判定假红（第 4 轮实测）；② 谓词必须**直接读 §2.3 的 `- path:` 行**，**不得**用"文件名是否出现在本文档里"这种自由文本匹配——那种谓词没有区分力（同一个名字在正文别处出现也会匹配，第 4 轮实测两个负向对照都绿）。
   * **反例（负向对照，必须实际跑过一次并留产物）**：删掉 §2.3 里任意一行 `- path: …`（**只改这一个变量**）→ 判定**必须红（exit 1，且 `$missing` 列出该文件）** → 还原并确认 `git status --porcelain` 为空。**注**：不能用"临时新增一个未登记文件"做反例——新文件本身就在 scope 里，会因自己未登记而红，那是同义反复。   * **明确排除**（过程产物，不属"改点登记"面，也不进上述 scope）：`docs/ai/HANDOFF*.md`、`docs/ai/last_test_run.txt`、`docs/ai/review_9*.md`。
   * **反例（负向对照，必须实际跑过一次并留产物）**：把 §2.2 任一模板声明行改成不存在的文件名（例：`templates/HANDOFF.md` → `templates/HANDOFF-X.md`）→ 判定**必须红（exit 1，且列出未登记文件）** → 还原并确认 `git status --porcelain` 为空。**注**：不能靠"临时加一个未登记的新文件"做反例——新增文件本身就在 scope 里，判定会因它自己未登记而红，那是同义反复；必须用"已登记文件在登记表里被改名"这种**只改一个变量**的形态。
7. **说与做一致**：`install.ps1` 的注释、`README.md` 的布局表与快照状态节、`AUTHORITY_CONTRACT.md` 的增补、`DSH-LANDING-NOTES` §4 对"镜像哪些路径 / 不碰哪些机器态"的描述必须与代码一致（判定方式：逐条对读，最近的反例是首轮 9A 的 B3）。
8. **机器态不可触碰**：`~/.dsh` 下的 `settings.yaml`、`sessions/`、`storages/`、`.credentials.yaml`、`profiles/` 不被部署动作修改或删除（判定方式：安装器解锁后在一次性 profile/临时 HOME 下实跑并比对哈希；本轮只做静态核验并如实标注未实跑）。
9. **如实标注**：未经审查/未实跑/未验证的东西必须写成未验证（含 `[DEBT]` **四笔**与验证记录节——**计数以 `DSH-LANDING-NOTES` §3 为准，改那里必须同步改这里**）；**不得把"未做"写成"已验证"**。**判定方式**：① 对被禁模糊措辞做零命中扫描（`later` / `temporary` / `for now` / `should be fine` / `probably ok` / `暂时` / `先这样` / `回头再说`）＝ 必须零命中；② `last_test_run.txt` 末尾的"未做/未验证"节与 `[DEBT]` 清单逐条对应，缺一即红。**反例**：故意在任一文档写一句"先这样" → 判定①必须红。
10. **判据无漂移**：`dsh/` 派生文件相对母本不存在"改判据而不是改执行器"的地方；`docs/ai/QUALITY_GATES.md`（项目副本）仍必须是 Reviewer 的质量清单输入。**判定方式（Amendment 2026-09-06 第 4 轮：原"指针行数相等"对它自己的声称没有区分力——漂移 10 处该计数也不变；来历 = 第 3 轮 9A 的 S4）**：判定 = `DSH-LANDING-NOTES` §1 第 4 步的**逐对** `git diff --no-index --numstat`，要求**每一条变更行都能归入 §2/§2.1 的某个改点**（AC1 已对其中一对给出全量结论），并**单列**任何触及判据/阈值/轮次的行。判定范围 = 有文本改点的派生对（`AGENTS.md` / `reviewer-prompt.md` / `QUALITY_GATES.md` / `index.md` / `workflow-design-notes.md` / 7 个 phase）；逐字节未改的 5 个文件见 §2.2，不参与本判定。`docs/ai/QUALITY_GATES.md` 的指针判定 = `reviewer-prompt.md` 里**指向项目副本的匹配数 == 母本对应匹配数**（第 3 轮实测 4 : 4；DSH 版另新增 2 处母本兜底，属有意的执行器差异，已在 §2 登记）。

## Frozen Acceptance 的冻结输入域（供负向对照用）

> **2026-09-06 第 4 轮订正**：本节此前写"输入域 = 文档中出现的每一个 `reasoning_effort` 取值"，与 AC4 已收窄的域**矛盾**——按旧域判定会扫进 `claude/**` 的 Codex 侧 `medium` 而**假红**（第 3 轮 9A 的 S2、9B 的 VN-3）。**冻结输入域的唯一出处 = AC4 的条目本身**，本节不再另立定义，只保留等价类枚举：

验收 4 的输入域 = **仅 DSH 侧面**（`dsh/**`、`portable/通用prompt-DSH-v1.txt`、`README.md` 的 DSH 段；排除 `claude/**` 与 `portable/通用prompt-v3.8.txt`）。等价类枚举：
* (a) 9A/9B 的取值；(b) 9P 的取值；(c) portable 与 README 里复述的取值；(d) skill 正文里复述的取值。
**对照样本（"若移除该错误则会通过"的负向对照）**：把任一取值改成 `medium` → 验收 4 的判定命令必须红。
**已实跑的更强对照（2026-09-06 第 3 轮）**：`reasoning_effort: "medium"` 的真实调用被拒，原文见 `last_test_run.txt` §M。

## Risks & Edge Cases

* **最大风险 = 判据漂移**：机械复制 + 人工改点的边界靠人自觉；首轮双审已实测出三类清单外变更（含 2 处指针漂移）。缓解：§2/§2.1 完整登记 + 逐对 diff 作为审查输入。
* **同模型双审的独立性只剩一层**：Codex 时代靠"换模型"提供第二层保险，DSH 下 Author 与 Reviewer 同为 `deepseek-flash`，独立性**完全**来自上下文隔离。若主/备用路径的档位漂移，就没有第二道保险 → 用 `model_route` 自报字段提高可见性（并如实标注它不可被验证）。
* **安装器无法演练**：受迁移期 guard 锁定，只能静态核验 → 验收 8 标注为"未实跑"。
* **不可逆面**：`~/.dsh` 是本机 harness home（含会话与凭据），部署动作一旦写错影响面大于普通仓库改动 → 采用"镜像受管路径 + 绝不触碰机器态"的最小面，并把整树备份的副作用登记为债。

## Execution Steps

1. 机械复制骨骼 + 有界 DSH 化改点。 | commit `a361bc19`
2. **第 1 轮**独立双审（9B 先、9A 后）→ 两份"不通过"（4+3 条 Product Blocking）。 | 落账 `7c5505f`
3. **第 2 轮修补**：修首轮全部 Product Blocking + 收 Suggestion；9P 档取 `high`（人类裁决）；补本 TASK_BRIEF。 | `7084fb75`
4. **第 2 轮**独立双审 → 两份"有条件通过"（Blocking = None）→ streak 归 0。 | 落账 `956db71`
5. **第 3 轮修补**：偿还 installer 债（收窄 README 措辞，人类裁决）+ 修 9B-S1。 | `34b6037`
6. **第 3 轮**独立双审 → **9B「不通过」（1 条 Product Blocking：AC6 改写后按字面仍红）**、9A「有条件通过」（同一条判为 Suggestion）→ **两份归类分歧交人类裁决**。 | 落账 `40c61bb`
7. **人类裁决 9B 归类成立 → 第 4 轮修补**：把改点登记表改为机读形态（§2.3）、AC6 判定命令按 §2.3 重写并**实跑正例 + 三条负向对照**、AC1/AC4/AC9/AC10 判定方式补全、修 README/台账状态块。 | 见 HANDOFF
8. **第 4 轮**独立双审 → 收敛门 → 人类 commit/merge。**账目提醒：本轮若出现 `caused_by_last_fix: yes` 的 Product Blocking，streak 达 2 → 硬停。** | —

## Testing Plan

* 无功能测试套件。核验 = 机制命令 + 真实输出，落 `docs/ai/last_test_run.txt`。
* 已完成的实跑（见 `last_test_run.txt`）：`high` 探针成功、**`medium` 被拒的负向对照**（§M，原始报错原文）、headless `--help`、`~/.dsh` 23/23 同副本、AC4 判定与负向对照、**AC6 判定与三条负向对照**（§Q）。
* 逐对 diff 审计（17 对派生文件）作为"判据无漂移"的机械输入。

## Open Questions

**None**（人类已在首轮双审后逐条裁决：进入第 2 轮、9P 档 = `high`、先跑审查、补 TASK_BRIEF）。

## Human Approval Status

- Status: **N/A — 本任务的批准门在实现后才补**（人类在首轮双审后裁决"进入第 2 轮修补"即为对本 TASK_BRIEF 验收基线的事实批准；**未经** `Status: Approved` 形式的正式批准 commit）
- Approved by: N/A
- Date: N/A
