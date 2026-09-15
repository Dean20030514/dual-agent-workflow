# HANDOFF.md

> per-task 核心交接文件，每次 Agent 切换前更新。简短，证据指向 git log 和 last_test_run.txt。
> 下列每节都保留（无内容写 None/N/A）；Quality Gates 必须逐维度表格，不得用"已过所有闸门"一句话替代。
> **空闲期形状**（任务归档后、下一任务 `/plan` 之前）：本文件仍保留下列全部节、不自创骨架——Current Phase 写 `Idle`，Remaining Risks / Debt 承接未偿 `[DEBT]` 账本，Next Step 指向候选任务，其余各节写 N/A。（形状唯一定义处 = `claude/workflow/templates/HANDOFF.md` 文首；DSH 侧镜像 `dsh/workflow/templates/HANDOFF.md`。本文件即该形状的实例。）

## Current Phase
**`Idle`** —— 无进行中任务。上一任务（DSH 落地）已收口、已推送、并已归档于 `docs/ai/archive/2026-09-06-dsh-landing/`；本文件此刻的唯一职责是**承接未偿 `[DEBT]` 与未验证 `[U]` 清单**，等下一个任务的 `/plan` 接管。

## Task Summary
N/A —— 无进行中任务。上一任务（把双 Agent 工作流落到 DeepSeek Harness，Author 与 Reviewer 都是 deepseek/dsh）的完整叙述见归档副本 `docs/ai/archive/2026-09-06-dsh-landing/HANDOFF.md`。

## Source of Truth
N/A —— 无进行中任务。上一任务的 `TASK_BRIEF.md`（含 Frozen Acceptance 与人类裁决记录）、`last_test_run.txt`、6 轮 verdict 均在上述归档目录内。

## Review & Test Binding（SHA 绑定；final-review 收敛门与 Reviewer 读；语义见 AGENTS.md）
N/A —— 无进行中任务，无待审 delta。
* 上一任务的绑定（`review_base_sha = bf06c65`、`review_tip_sha = 89d5cae`、`tested_sha`、`review_sensitive_paths`、逐轮 verdict）见归档副本 `docs/ai/archive/2026-09-06-dsh-landing/HANDOFF.md`。
* **复核提醒**：`review_sensitive_paths` 里的 `docs/ai/TASK_BRIEF.md` 已随任务归档；`README.md` 等文件在其后又有收口性改动，**这些改动都在已审 tip 之外**（权威清单 = `git log --oneline 89d5cae..HEAD`，不写死条数）。

## Work Log
倒序，每条一行：[日期] [Agent] [做了什么] [commit]
* [2026-09-06] [Author] 上一任务归档；把未偿账从自造的 `docs/ai/DEBT.md` 搬回本文件的空闲期形态（母本 `templates/HANDOFF.md` 文首已定义该形状，自造产物属偏离，已纠正）。 | 本文档 commit

（上一任务的逐轮 Work Log 随任务归档，见归档副本 `HANDOFF.md`。）

## Known Issues
* **`AC6`（改点登记门）在 HEAD 上按构造为红**：唯一差异项是 `docs/ai/TASK_BRIEF.md`（`stale=1`、`missing=0`）。该文件在钉死的 `base` `bf06c65` 时**尚不存在**，任务归档后其净变更只落在新路径 `docs/ai/archive/2026-09-06-dsh-landing/TASK_BRIEF.md`（不在 AC6 的 pathspec 内）→ 登记表那条旧路径不再进 `$scope`。**绑定任务收口 tip `32e6ac3` 复核为绿**（`reg=31 scope=31 missing=0 stale=0`）。**这不是产品缺陷、不推翻该任务已收口的结论**——它是"任务级验收门随任务归档"的必然结果；下一个任务会按模板重新实例化自己的 AC6。**`AC4`-门是常驻工具，仍可用且仍绿**（`pwsh -File tools/ac4-reasoning-effort-check.ps1` → `AC4: PASS`，`exit=0`）。
  > **若要让它回到"HEAD 上可判绿"**：需同时把 `docs/ai/DSH-LANDING-NOTES.md` §2.3 的登记行与 AC6 判定命令的 pathspec 改到归档路径——**这属于修改已冻结的验收判据，须人类逐次裁决**；本文件不自行改，也不假装它现在是绿的。
* **一处 Author 误判的如实登记（第四次踩同一条规律）**：动手归档**之前**，我在临时仓里"实测"过 AC6 是否受影响，结论是"不会红"。**那次预检的配置与真实配置不同**——临时仓里 `base` **已经有**那个文件（改名 → 删除侧匹配 pathspec），真实 `base` `bf06c65` **没有**（净变更 = 只在新路径上新增）。**预检给出假绿，真实运行才暴露。**"命令可复制"不够，**预检的配置必须与真实配置一致**；这条规律的完整版见归档的 `last_test_run.txt` §AK。
* **关于本文件的形态失误（同一类病）**：归档时我**没有查 `templates/HANDOFF.md`**，自造了一个 `docs/ai/DEBT.md` 来承接未偿账——而母本自 2026-09-06 起已明确规定"空闲期 HANDOFF 承接未偿 `[DEBT]`"。该规定正是为治"各项目自创空闲期形状、被下一任务当先例抄"而立的裁决。**已按母本纠正**：`DEBT.md` 撤销，本文件即空闲期实例。
* **上一任务未处置的建议**（第 3 轮两份共 14 条，以登记/措辞类为主）与其余历史条目：随任务归档，见归档副本 `HANDOFF.md`。
* **未验证 `[U]` 清单**（**不是债**，故无 Payback trigger）——**本清单与 `docs/ai/DSH-LANDING-NOTES.md` §5 的"未做/未验证"节必须逐条一致，改一处必须同改另一处**（该不变式源自上一任务 AC9 的人工读点，保留）：
  1. 除 `AGENTS.md` 外的**其余派生对**（`reviewer-prompt.md` / `QUALITY_GATES.md` / `index.md` / `workflow-design-notes.md` / 7 个 phase）相对母本是否存在判据漂移 —— 触发：下一次改动任一该文件之前。
  2. **备用路径（headless）完整审查轮** —— 触发：首次用备用路径发审之前。
  3. **真实 9P 审查轮**（两次都只是档位探针）—— 触发：下一次启用 Critical 之前。
  4. **`~/.dsh/settings.yaml` 的 `reasoningEffort` 是否真被适配器读取**（现只有 schema 层证据）—— 触发：首次依赖 settings 层钉档位之前。
  5. **AC8 的机器态实跑**（临时 HOME / 一次性 profile 下跑安装器 + 三项哈希）—— 触发：`install.ps1` 解锁后首次运行。
  6. **`install.ps1` 的其余注释逐句对读**（AC7 只核了备份/镜像语义那一组）—— 触发：下次改动该文件之前。

## Fix-Loop Counter（review-fix 循环用；无则 "None"）
None —— 无进行中任务、无双审窗口。上一任务的轮次账（streak = 2 硬停、双审轮次 4 > 上限 3、5 条 `dispute` 的裁决矩阵）见归档副本 `HANDOFF.md`。

## Remaining Risks / Debt
技术债唯一落点。核验命令（**不写死笔数**——写死必然随加账过期，上一任务的 PB-1 就是这么错的）：
```powershell
(Select-String -Path docs/ai/HANDOFF.md -Pattern '^\[DEBT\]').Count
```

```
[DEBT] AC4-门（档位取值域）的实现自身无机械完整性保护：AC6 是路径级谓词，已登记路径的内部修改零信号，削弱该脚本只能靠人工读 diff（2026-09-06 第 6 轮 9B 的 R6-B3）| Payback trigger: 下次改动 tools/ac4-reasoning-effort-check.ps1 之前；或下次由人类复核 dsh/** 判据面之前 | Impact: 一道机械门可在双门全绿的情况下被静默削弱
[DEBT] AC4 门的残余覆盖边界（**处置已定，本条只剩残余**）：人类 2026-09-06 选选项 **2a** → 谓词现已覆盖**两种拼写的赋值位**（`reasoning_effort` / `reasoningEffort`，门级负向对照见归档 `last_test_run §AQ`）；**残余 = 散文式取值陈述**（如 `` 9A/9B = `high` ``）仍不在域内——人类**未选 2b**，故已按"只声明赋值位"如实收窄声称（归档 `TASK_BRIEF` → AC4「声称边界」），**不记为暗账** | Payback trigger: 若将来确有散文式取值写错、或有人主张本门覆盖散文式之前 | Impact: 散文面写错档位不会被任何机械门发现（实测散文行取值全为 `high`、**当前无活假绿**）
[DEBT] AC4 判定脚本的路径绑定——**已偿还**（2026-09-06 人类裁决"修路径推导 + 把声称改准"；`1e8832e`）：`$repo` 改为 `Split-Path -Parent $PSScriptRoot`，故**任意 checkout 均可执行**；归档 `TASK_BRIEF` 的"可复制执行"同时改准（残余一条环境依赖：适配器取自 `%LOCALAPPDATA%\npm-cache\_npx\*`，**需本机存在 npx 缓存的 dsh 适配器**，找不到时报错退出、非静默通过）| Payback trigger: —（已偿还）| Impact: —（残余限度已写进 AC4 声称）。**本条目同时订正此前账目里的错误机制描述**：原文写"换 checkout 会在 `Set-Location` 处直接终止、拿不到 verdict"，**实测不成立**——同机异 checkout 下旧脚本**静默读错树并给出假绿**（副本 README 注入 `medium` 仍报 `AC4: PASS / exit=0`，原始输出归档 `last_test_run §AR ①`）；只有换到不存在该硬编码路径的机器才会终止。保留原文描述供对照：~~换 checkout/换机执行会在 `Set-Location` 处因 `$ErrorActionPreference='Stop'` 直接终止~~
[DEBT] AC6 对**未跟踪文件不可见**：其 scope 来自 `git diff --name-only <base>..HEAD`，而 `git diff` 不列未跟踪文件（2026-09-06 第 7 轮实测 VN-4：在 `tools/validate/` 下新建一个未登记且**未提交**的文件 → 判定仍 GREEN、`missing` 为空）| Payback trigger: 下次依赖"新增文件一定会被 AC6 拦住"这个假设之前 | Impact: 门只能在**提交之后**才发现漏登记；"提交前自查"这一步没有任何机械保证——上一任务的 `.tmp-r6.ps1` 正是这样进过一次 tip
[DEBT] 第 3 轮 9B 的 B1（AC6 按字面恒红 + <base> 未钉死）——**已实质闭合**（第 4 轮两份独立实跑确认），保留为历史记录 | Payback trigger: —（已闭合）| Impact: —
[DEBT] dsh/ 的相对母本"判据无漂移"缺少机械门禁（AC10 的判定对声称无区分力，9A-S4）| Payback trigger: 下次改动 dsh/** 之前 | Impact: 判据漂移不会被任何门检出（上一任务靠 Reviewer 手工逐行读才排除）
[DEBT] dsh/workflow/fanout-toolchain.md 的 DSH 事实绑定 @deepseek-ai/dsh 0.1.5-rc.x | Payback trigger: @deepseek-ai/dsh 升级后首次派发审查之前 | Impact: 参数/工具名变化会让调用范式静默失效（第 2 轮已复核一次）
[DEBT] ~/.dsh 的运行副本由人工同步产生，无 *.bak-*，且每次同步无落账规范 | Payback trigger: 首次用 install.ps1 覆盖 ~/.dsh 之前 | Impact: 首次自动部署没有上一版可回退；人工同步可能被遗忘
```

**已偿还/已闭合但仍保留在册的理由**：上面第 3、5 两条分别标注"已偿还 / 已闭合"，**保留为历史记录**——删掉它们会让"这笔债曾经存在、如何处理"这段历史消失（该任务曾被 Reviewer 抓到过一次"静默删除历史"的苗头）。核验命令只数 `^[DEBT]` 行，**不区分已偿还与否**。

**第 4 笔债（installer 整树备份复制凭据）已按人类裁决偿还**（收窄 README 措辞，commit `34b6037`）；**残余行为**（备份仍会复制 `sessions/`/`storages/`/凭据且不自动清理）已改为"`~/.dsh` 运行副本由人工同步"这一笔与之相邻披露，**未静默删除该项的历史**。

## Quality Gates
N/A —— 无进行中任务的验收。上一任务的逐维度闸门表见归档副本 `HANDOFF.md`。
> **状态限制（沿用，未解除）**：上一任务**不得标"已收敛 / Ready to Commit"**——AC4 门不覆盖散文式取值陈述、上面 6 项 `[U]` 未验证、且存在已审 tip 之外的 review-sensitive delta。**push 不解除这条限制。**

| 维度/闸门 | 状态(Pass/N/A) | 证据文件或 N/A 原因 |
|---|---|---|
| 测试 QA(11.1) | N/A | 无进行中任务；上一任务见归档 `last_test_run.txt` |
| 安全基础(11.2) | N/A | 同上 |
| 设计层闸门(§5) | N/A | 无界面 |

## Quick-Version Fields（快速版填，正式可省）
* Applicability Scan(0.1)：N/A —— 无进行中任务。
* Human Approval Evidence：N/A。

## Next Step
**等人类指定下一个任务**（本仓此刻无进行中任务）。候选（均属新任务，需人类点选；`[U]` 与 `[DEBT]` 的触发点见上）：

1. **给 `install.ps1` 真正的 `-DryRun` / `-ValidateOnly`（H3）** —— 解锁迁移期 guard，让部署可演练。触及部署/回滚面，按纪律应先建议 **Critical** 并停下等人类确认。
2. **补 AC8 的机器态实跑** —— 临时 HOME / 一次性 profile 下比对 `settings.yaml`、`sessions/`、`storages/`、`profiles/` 的哈希；依赖第 1 项解锁。
3. **偿还"`~/.dsh` 人工同步无落账规范"这笔债** —— 首次自动部署前到期（当前副本与仓内 `dsh/**` 逐字节一致，未漂移）。
4. **清 `[U]` 清单**（如其余派生对的逐对漂移审计、headless 备用路径跑完整审查轮）—— 工作量大、历轮零判据漂移，**不推荐现在做**。
