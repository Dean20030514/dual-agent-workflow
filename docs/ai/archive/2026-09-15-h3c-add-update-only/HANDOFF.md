# HANDOFF.md

> 任务账本：切片 A 已按冻结验收收敛并归档。**当前 = Routine 档的 `install.ps1` 部署器收口**（人类 2026-09-15 裁决放弃 mirror-replace 方案；该方案的规划产物已归档于 `docs/ai/archive/2026-09-15-h3b-mirror-replace-superseded/`）。上一任务 = **切片 A**（`task/h3a-parameter-surface`，按冻结验收收敛后经人类裁决 squash 合入 `main`）；其 per-task 记录与五轮 verdict 已归档于 `docs/ai/archive/2026-09-15-h3a-slice-a/`。
> **未偿债不随任务消失**：下方 `[DEBT]` 与 `[U]` 逐字承接（本文件生成时从归档 HANDOFF 程序化提取，未人工转录）。
> **切片 A 的教训**：审查循环缺终止条件 —— 冻结验收被 amend 四次、切片 B 的语义被拉进切片 A 的审查、两轮之间只改文档就重开审，共同造成五轮无收敛迹象。下一任务开工前先立终止规则。

## Current Phase

**Routine — `install.ps1` 部署器收口**。人类 2026-09-15 裁决:写入路径为**只增/只更新**(永不删除)、降档 Routine。随后按人类「把 5 项残余全部处理了」的指示完成:**插件步落地**(6 个官方插件、CLI 缺席走手工命令、失败即 FAILED)、**`-RemoveStale`**(唯一的删除路径、显式开关、绝不递归)、**`-DryRun` 预览**(`[DIFF]` 逐文件 + `would-write=N` + `[WARN]` 形状警告)、**A3/skills 债清偿**(目录枚举 + 区分力用例)、**首次真部署已对真实树执行**(exit 0、零写入)、**被取代的规划产物已归档**、**`[U]` 第 3 项与 `DSH-LANDING-NOTES.md` §5 已同改**。套件 **73 条全绿**。工作树改动**未 commit**(Routine:agent 不 commit)。

## Source of Truth

* 切片 A 的冻结验收（AC1–AC3 + K1–K9 + ㉓–㉜）：`docs/ai/archive/2026-09-15-h3a-slice-a/TASK_BRIEF.md`
* 实现计划 · 冻结证据 · 五轮 verdict：同目录的 `IMPLEMENTATION_PLAN.md` / `last_test_run.txt` / `review_9{P,A,B}.md`
* **下一任务的输入 = `docs/ai/BACKLOG_sliceB.md`**（切片 B 语义 7 条 / 需求裁决 5 条 / 测试增强 12 条 / 文档改准 3 条 / 人类动作 3 条）
* 常驻规范：`docs/ai/AUTHORITY_CONTRACT.md`、`docs/ai/DSH-LANDING-NOTES.md`、`docs/ai/INSTALLER_GUARD.md`（guard 债的偿还事实见下方债账）
* `install.ps1` 当前状态（合入 main 后）：参数面 + `-ValidateOnly` / `-DryRun` 两条**零写入**路径；无参数 = 打印计划 + 校验 + `RESULT=REFUSED` 非零退出；`-IUnderstandThisReplacesLiveConfig` 已移除（传它 = 绑定期失败）

## Work Log

倒序，每条一行：[日期] [Agent] [做了什么] [commit]

* [2026-09-15] [Author] **真机首次带插件的运行暴露并修掉 3 个缺陷**：人类在真机跑无参数部署，运行卡在插件步第 1 个（`claude.exe plugin install context7@…`，起于 19:24:25，数分钟零 CPU 零输出；文件面已在此之前完成且零写入）。诊断后 kill 该次运行（受管面复核仍为零改动：`would-write=0`、零新备份）。修复：① 每个插件安装**开始前**先打印 `[PLUGIN] installing … (timeout Ns)`，卡住可归因；② 加**每插件 180s 超时**（`INSTALL_PS1_PLUGIN_TIMEOUT_SEC` 可覆盖），超时 kill 并计 `failed`；③ 插件步纳入 try/catch，异常不再跳过汇总；④ 插件调用改用自持的 `ProcessStartInfo` 而非 `Start-Process -PassThru`——**5.1 腿当场抓到后者在 Windows PowerShell 5.1 下 `ExitCode` 为空**，会把 6 次成功调用全报成 `FAILED (exit )`；⑤ 载体优先 `.cmd`（不被 npm 的 `claude.ps1` 在进程内执行）；⑥ 更正 `[PLAN] stale rows …` 那句已过期的措辞（现在有 `-RemoveStale`）。证据：套件 **75 条全绿**（含新增"逐个播报"与"超时被 kill"两例），两宿主（pwsh7 / PS5.1）实测插件步各 6 次调用且 exit 0。 | 待人类 commit
* [2026-09-15] [Author] 按人类指示**收口 5 项残余**：① 插件步落地（6 个官方插件、经 PATH 查找故可用录制 shim 离线测、CLI 缺席打印手工命令、任一失败 ⇒ `FAILED`）；② `-RemoveStale`（**唯一的删除路径**、显式开关、只删本次 `[STALE]` 行、目录仅空时删、**全文件无递归删除**）；③ `-DryRun` 预览（`[DIFF]` 逐文件 + `would-write=N` + 计划会被拒时 `[WARN]`）；④ A3/skills 债清偿（两侧改目录枚举 + FakeRepo 第三个 bundle 区分力用例，旧实现下实测为红）；⑤ 顺带修 B-1（空根三模式一致 FAIL，绝不回落真机）、B-2（大小写不敏感成员判定）、R-4/T-6（`planned` 契约与行级交叉核对）、T-3（seed 缺失分支）。**首次真部署已对真实树执行**（`-NoPluginInstall`，exit 0；`would-write=0 / written=0 / backups=0`——本机本就全同步）。被取代的规划产物 `git mv` 归档 + 归档 README；`[U]` 第 3 项与 `DSH-LANDING-NOTES.md` §5 同改。证据：套件 **73 条全绿**（exit 0）+ 真实树运行记录 `REAL_DEPLOY_LOG.txt`。 | 待人类 commit
* [2026-09-15] [Author] **人类裁决改向**：切片 B 由 mirror-replace 收窄为**只增/只更新**（永不删除；覆盖前逐文件备份为同级 `<name>.bak-<stamp>-<guid4>`；live-only 内容只报告 `[STALE]`）并**降档 Routine**。实现落地：`install.ps1`（写入路径 + `[DELETE]`→`[STALE]` + 退出码 `REFUSED` 退役）、新增 `tests/install.Deploy.Tests.ps1`（9 条，含"live-only 逐字节存活""二次运行 no-op""PROBE-D 回归"）、四处既有测试契约改准、README 部署节改准；顺带**清偿"死代码六处"债**（trigger 已触发）。证据：套件 55 条全绿（exit 0）。 | `8fbae9e`
* [2026-09-15] [Author] 9P **round 3**（Plan Verdict = 修订后可批准；B1–B4）→ 代跑其 6 条 Verification Needed（含 **PROBE-E**：live-only 空目录确实进 `[DELETE] (dir)`；**VN-4**：取代账目的两处归档引文逐字属实；**VN-5**：9P 给的债闸门宽模式有两类假阳性，已改用收紧模式）→ 按裁定改文本（AC2 集合断言 / AC4② 写入前封存与模式无关性 / AC4③ 行来源 + 文件面·目录面拆账 / AC3 四处并集落点 / AC9 逐模式表 + 切片 C 自带失效条件 / AC8 产物位置）。`review_9P.md` 已逐字落 verdict + 逐条表态。 | `9e3ab59`
* [2026-09-15] [Author] 切片 B 规划：两轮 9P（round 1 = 7 Gaps；round 2 = B1–B4 + Required-1..8 + 4 NB）后按逐条要求改写 brief/plan（AC1–AC9 + D1–D9 + ㉗/K1 取代账目 + 终止规则 8 条 + 债闸门步骤 0）；补跑 **PROBE-D** 复现切片 A 白名单谓词在 `*.bak-*` **目录**形态的子树继承缺口（源树自带同名目录时目标侧本机独有文件被判 `[DELETE]`）；scaffold `docs/ai/QUALITY_GATES.md`。 | `9b125aa`
* [2026-09-15] [Author] 切片 A 收敛处置：按人类裁决 A 宣布「按冻结验收收敛」（最近三轮无可复现的冻结条款违反），残余逐条分类移交 `BACKLOG_sliceB.md`；per-task 文件归档；本文件换为空闲期账本。 | main 的 squash commit
* [2026-09-15] [Author] 切片 A 五轮双审（9P + 9A/9B round 1–5）：3 条修复（退出码 / 计数同源 / 枚举守卫 / 子树继承）+ 1 条 `disputed`（实测推翻）+ 1 条文本改准；套件 26 → 46 用例。 | 见归档目录

* **承接的 `[U]` 未验证清单**（**不是债**；与 `docs/ai/DSH-LANDING-NOTES.md` §5 **必须逐条一致**，改一处必须同改另一处）。**本分支 §5 为 H3 之前原措辞**，故此处同样按原措辞承接（停牌任务对第 5/6 项的"已处置"改写**随其未收敛而不作数**）：
  1. 除 `AGENTS.md` 外的其余派生对（`reviewer-prompt.md` / `QUALITY_GATES.md` / `index.md` / `workflow-design-notes.md` / 7 个 phase）相对母本是否存在判据漂移 —— 触发：下一次改动任一该文件之前。
  2. 备用路径（headless）完整审查轮 —— 触发：首次用备用路径发审之前。
  3. ~~真实 9P 审查轮（两次都只是档位探针）—— 触发：下一次启用 Critical 之前。~~ **已履行（2026-09-15）**：切片 B 规划期跑了 round 1/2/3 三轮真实 9P（verdict 全文见 `docs/ai/archive/2026-09-15-h3b-mirror-replace-superseded/review_9P.md`）；`DSH-LANDING-NOTES.md` §5 同条已同改。
  4. `~/.dsh/settings.yaml` 的 `reasoningEffort` 是否真被适配器读取 —— 触发：首次依赖 settings 层钉档位之前。
  5. AC8 的机器态实跑（临时 HOME / 一次性 profile 下跑安装器 + 三项哈希）—— 触发：`install.ps1` 解锁后首次运行。
  6. `install.ps1` 的其余注释逐句对读（AC7 只核了备份/镜像语义那一组）—— 触发：下次改动该文件之前。

## Remaining Risks / Debt

技术债唯一落点。核验命令（**不写死笔数**——写死必然随加账过期）：

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
[DEBT] ~/.dsh 的运行副本由人工同步产生，无 *.bak-*，且每次同步无落账规范 | Payback trigger: 首次用 install.ps1 覆盖 ~/.dsh 之前 | ~~Impact: 首次自动部署没有上一版可回退；人工同步可能被遗忘~~ **已偿还（2026-09-15）**：`install.ps1` 已成为该副本的部署器，并**首次对真实树运行完毕**（`-NoPluginInstall`，exit 0）；本次实测 `would-write=0 / written=0 / backups=0`（本机本就全同步，故无文件被覆盖），且此后每次覆盖都会先落同级 `<name>.bak-<stamp>-<guid4>` 备份；运行记录见 `docs/ai/REAL_DEPLOY_LOG.txt`
[DEBT] 本仓**没有常驻的守护有效性装置**（无「变异生产代码 → 目标测试因预期断言而红」的结构化产物能力）：本任务的守护类 AC 只用**测试套件自身的负向对照**（同一判定在对照样本上失败）证明区分力，**不构成**母本要求的装置产物（2026-09-15 H3 计划期登记）| Payback trigger: 下次需要声称「回归用例有效（红→绿）」的结构化产物、或有 AC 依赖该更强声称之前 | Impact: 「把机制删掉这些用例会不会变红」这一层未被机械证明；目前无 AC 依赖它，故**不阻止本任务收敛**
[DEBT] A3 的 dsh/skills 臂无区分力：`install.ps1` 的 `Build-Plan` 与测试侧独立预言机 `Get-ManagedDeploySet` **硬编码同一常量列表**（`'dual-agent-workflow','independent-review'`），故"计划动作目标 == 受管面"这条集合相等断言在新增第三个 skill bundle 时**两侧同时缺失、恒绿**（2026-09-15 9B round 3 的 NB-1 / 9A 的 G5；本仓"谓词无区分力"第 5 次同型）| Payback trigger: 下一次新增或改名 `dsh/skills/<bundle>` 之前 | ~~Impact: 新增 skill 会被静默漏部署，而 A3 仍报"集合相等"；今日仓内恰为 2 个目录故无当前行为偏差~~ **已偿还（2026-09-15）：两侧均改为枚举 `dsh/skills/*` 目录，并新增区分力用例（FakeRepo 内建第三个 bundle ⇒ 计划必须包含它且必须真的部署）；区分力已实测——同一断言在旧实现（`git show HEAD` 的 install.ps1）下为红（计划里 0 行提到 third-bundle）**
[DEBT] 切片 A 遗留的五处死代码/死参数未清：`install.ps1` 的 `$script:Plan`、`$script:checkFailed`（只写不读）、`$Roots`、首个 `$RootSpecs` 赋值，以及 `tests/TestHelpers.ps1` 的 `Test-PathInsideDirectory`（无调用点）与 `Invoke-InstallerCase -Environment`（无调用者）（2026-09-15 review 9A NB-4 / 9B NB-6，两轮点名未清）| Payback trigger: 下一次改动 `install.ps1` 或 `tests/TestHelpers.ps1` 之前 | ~~Impact: 死状态会让后续读者误判控制流；不影响当前任何验收判定（无 AC 依赖它们）~~ **已偿还（2026-09-15，只增/只更新切片同一 patch）：六处全部删除，证据 = 收紧模式 `Select-String -Path install.ps1,tests\TestHelpers.ps1 -Pattern '\$script:Plan\b|\$script:checkFailed|\$Roots\b|Test-PathInsideDirectory|\$Environment'` 零命中 + 套件 55 条全绿**
```

**已偿还/已闭合但仍保留在册的理由**：第 3、4、5 条分别标注"已偿还 / 已闭合"，**保留为历史记录**；核验命令只数 `^[DEBT]` 行、不区分是否已偿还。

**本任务触碰面与 Payback-on-Touch 判决**：切片 A 要改 `install.ps1` → `[U]` 第 6 项（注释逐句对读）在本切片内履行；`INSTALLER_GUARD` 的 guard 债已由停牌任务偿还并保留在活树；其余各笔 trigger 与本切片不匹配（`tools/ac4-*`、`dsh/**`、`@deepseek-ai/dsh` 升级、AC6 未跟踪假设），维持原状态。`~/.dsh` 那笔的**落账规范**在停牌分支（属切片 D），**首次真部署未发生**（9A 的 Debt Verdict = `Unpaid`）。


## Next Step

1. **人类**：扫 diff → **自行 commit**（Routine：agent 不 commit）。本次改动面 = `install.ps1` / `tests/**` / `README.md` / `docs/ai/**`（含三份 `R` 重命名归档）。
2. **可选：真机插件安装**（**网络操作，按人类指示才做**）：`pwsh -NoProfile -File .\install.ps1`（不带 `-NoPluginInstall`）会为 6 个官方插件各跑一次 `claude plugin install <name>@claude-plugins-official`。⚠️ **2026-09-15 首次实测卡在这里**（见 Work Log）：现已有逐插件播报、180s 超时 kill、失败计入 `failed=N` 并以 `RESULT=FAILED` 退出。若仍卡住：Ctrl-C 即可（文件面早已完成），或先只做文件面（`-NoPluginInstall`），插件手动逐个装以便看到 CLI 的输出。
3. **删除能力若仍需要**：属**新任务**，须重新立项（本次裁决明确不做；不要在后续改动里顺手加回）。
4. 参考实现仍在未合并分支 `task/h3-installer-hardening`（人类裁决保留；627 行 `install.ps1` + 44 用例）：**只读参考，不是可交付版本**（该任务 `STOPPED, NOT CONVERGED`）。已核：该分支的白名单谓词是 `*.bak-*` **只看叶名**（`git show task/h3-installer-hardening:install.ps1` 第 134 行），本次已按段级判定修正。

