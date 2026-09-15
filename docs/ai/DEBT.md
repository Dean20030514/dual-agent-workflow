# DEBT.md —— 跨任务的**活**债台账（唯一权威）

> **本文件是未偿还 `[DEBT]`、未验证 `[U]` 清单与"不得标已收敛"这一状态限制的唯一活台账。**
> 它**不是** per-task 交接文件：per-task 的 `HANDOFF.md` / `TASK_BRIEF.md` / `last_test_run.txt` / `review_9*.md` 在任务收口后归档到 `docs/ai/archive/<日期-任务>/`，随任务消失；未偿债不能随任务消失，故集中在本文件。
>
> **来源（Provenance）**：以下条目**原样承接**自 DSH 落地任务的 `docs/ai/HANDOFF.md` → `Remaining Risks / Debt`（`[DEBT]` 块）与 `docs/ai/TASK_BRIEF.md` → AC11（`[U]` 清单）。该任务的 per-task 文件已归档于 **`docs/ai/archive/2026-09-06-dsh-landing/`**。条目里的 `last_test_run §X` / `TASK_BRIEF` 等指针，一律指**同目录下的归档副本**。
>
> **口径（重要，避免重犯 PB-1）**：本文件**不写死笔数**。核验命令：
> ```powershell
> (Select-String -Path docs/ai/DEBT.md -Pattern '^\[DEBT\]').Count
> ```
> **改债必须改本文件**；`docs/ai/DSH-LANDING-NOTES.md` §3 只是导读、不是权威，它与本文件的集合不保证等集。

## 1. 未偿还与历史 `[DEBT]`（原样承接，未改一字）

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

**已偿还但仍保留在册的理由**：上面第 3、5 两条分别标注"已偿还 / 已闭合"，**保留为历史记录**——删掉它们会让"这笔债曾经存在、如何处理"这段历史消失（本任务已被 9A/9B 抓到过一次"静默删除历史"的苗头）。核验命令只数 `^[DEBT]` 行，**不区分已偿还与否**。

**第 4 笔债（installer 整树备份复制凭据）已按人类裁决偿还**（收窄 README 措辞，commit `34b6037`）；两份第 3 轮 verdict 的 Reviewer 都逐句核对了"代码 ↔ README"并确认未出现反向过度声称。**残余行为**（备份仍会复制 `sessions/`/`storages/`/凭据且不自动清理）已改为"`~/.dsh` 运行副本由人工同步"这一笔与之相邻披露，**未静默删除该项的历史**。

## 2. 未验证 `[U]` 清单（原样承接自 `TASK_BRIEF.md` → AC11；**不是债**，故无 Payback trigger）

以下**未验证**，如实登记，附触发时机：

1. 除 `AGENTS.md` 外的**其余派生对**（`reviewer-prompt.md` / `QUALITY_GATES.md` / `index.md` / `workflow-design-notes.md` / 7 个 phase）相对母本是否存在判据漂移 —— 触发：下一次改动任一该文件之前。
2. **备用路径（headless）完整审查轮** —— 触发：首次用备用路径发审之前。
3. **真实 9P 审查轮**（两次都只是档位探针）—— 触发：下一次启用 Critical 之前。
4. **`~/.dsh/settings.yaml` 的 `reasoningEffort` 是否真被适配器读取**（现只有 schema 层证据）—— 触发：首次依赖 settings 层钉档位之前。
5. **AC8 的机器态实跑**（临时 HOME / 一次性 profile 下跑安装器 + 三项哈希）—— 触发：`install.ps1` 解锁后首次运行。
6. **`install.ps1` 的其余注释逐句对读**（AC7 只核了备份/镜像语义那一组）—— 触发：下次改动该文件之前。

**本清单与 `docs/ai/DSH-LANDING-NOTES.md` §5 的"未做/未验证"节必须逐条一致**（这条一致性要求本身，是已归档任务 AC9 的 `[O]` 人工读点）；**改一处必须同改另一处**。

## 3. 状态限制：**不得标"已收敛"**（push 不解除）

* DSH 落地自 `bf06c65` 起的产出**已随 `main` 推送到 `origin/main`**（推送由人类执行、agent 绝不做远程操作）。**但 push 不等于收敛**：
  * AC4 门**不覆盖散文式取值陈述**（见上文第 2 条残余）；
  * 上面 6 项 `[U]` 仍未验证；
  * 已审 tip = 第 7 轮 9B 的 `review_tip_sha = 89d5cae`；其后存在**未再审的 review-sensitive delta**（权威清单 = `git log --oneline 89d5cae..HEAD`，**不写死条数**）。人类 2026-09-06 裁决"不再开新审查轮"，故这些 delta 按该裁决处理，**不等于它们已被审过**。
* 因此：**README 与任何状态面都不得出现"已收敛 / Ready to Commit"字样**，直到人类另行裁决。

## 4. 不在本台账内的历史叙述（不要来这里找）

轮次账（`Review & Test Binding` / `Fix-Loop Counter`）、5 条 `dispute` 的裁决矩阵、`Known Issues` 里的 14 条未处置建议、每一步的 Work Log —— 全部保留在**归档副本** `docs/ai/archive/2026-09-06-dsh-landing/HANDOFF.md` 内，属**历史记录**，不再是活状态面。

**两道机械门的归档后状态**（含一处 Author 误判的如实登记）：见 §5。最近一次**双门同时绿**的真实输出在归档的 `last_test_run.txt` §AS / §AT / §AU。

## 5. 归档后两道机械门的状态（含一处 Author 误判的如实登记）

**AC4-门是常驻工具，归档后照旧可用**：

```powershell
pwsh -File tools/ac4-reasoning-effort-check.ps1
```

在归档后的 tip 上实测：`DSH-side values = high / out-of-domain = (none) / adapter medium hits = 0 → AC4: PASS`，`exit=0`。

**AC6（改点登记门）是任务级门，它的绿值绑定"该任务的收口 tip"**：判定命令写在归档的 `TASK_BRIEF.md` → AC6，`base` 钉死 `bf06c65d…`。**绑定任务收口 tip `32e6ac3` 复核为绿**（`reg=31 scope=31 missing=0 stale=0`，`exit=0`）。**但在归档提交之后的 HEAD 上，它按构造必然为红**：唯一差异项是 `docs/ai/TASK_BRIEF.md`（`stale=1`，`missing=0`）——该文件在 `base` 时**尚不存在**，归档后其净变更落在新路径 `docs/ai/archive/2026-09-06-dsh-landing/TASK_BRIEF.md`（**不在** AC6 的 pathspec 内），于是登记表里那条旧路径不再出现在 `$scope` 里。**这不是产品缺陷，也不推翻该任务已收口的结论**——它是"任务级验收门随任务归档"的必然结果。**下一个任务会按模板重新实例化自己的 AC6，不复用这一份。**

**如实登记 Author 的一处误判（本任务第四次踩同一条规律）**：动手归档**之前**，我在临时仓里"实测"过 AC6 是否会受影响，结论是"改名后按 pathspec 过滤仍会看到旧路径 → 登记表仍匹配 → 不会红"。**那次预检的配置与真实配置不同**：临时仓里 `base` **已经有**那个文件（改名 → 删除侧匹配 pathspec，故看到旧路径）；而真实 `base` `bf06c65` **没有**这个文件（净变更 = 只在新路径上新增，旧路径根本不进 `$scope`）。**预检给出假绿，只有真实运行才暴露。** 这是本任务已归档 `last_test_run.txt` §AK 那条规律的**第四次**复发：**"命令可复制"不够，还必须让预检的配置与真实配置一致**；凡"我测过了"的结论，附的是那次运行的环境，不是别的环境。

**若将来要让它回到"在 HEAD 上可判绿"**：需要**同时**把 `DSH-LANDING-NOTES.md` §2.3 的那条登记行与 AC6 判定命令的 pathspec 改到归档路径。**这属于修改已冻结的验收判据，须人类逐次裁决**——本文件不自行改，也不假装它现在是绿的。
