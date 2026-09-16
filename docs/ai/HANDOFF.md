# HANDOFF.md

> **空闲期账本（Idle）**：上一任务 = **installer 只增/只更新收口**（Routine 档），其 per-task 记录已归档于 `docs/ai/archive/2026-09-15-h3c-add-update-only/`（`HANDOFF.md` / `BACKLOG_sliceB.md` / `REAL_DEPLOY_LOG.txt`）。
> **未偿债不随任务消失**：下方 `[DEBT]` 与 `[U]` 逐条承接，改一处必须同改 `docs/ai/DSH-LANDING-NOTES.md` §5。
> 形状唯一定义处 = `claude/workflow/templates/HANDOFF.md` 文首；本节保留模板全部小节，无内容写 N/A。

## Current Phase

**Idle**。installer 只增/只更新收口已完成：`install.ps1` 具备真实部署能力（覆盖前逐文件备份、默认不删除、`-RemoveStale` 为唯一删除路径、插件步带超时、`-DryRun` 逐文件预览），套件 75 条全绿，首次真机运行完成（零写入）。**等人类 push**（本仓规则：agent 不做任何远程操作）。

## Task Summary

N/A（Idle）。上一任务一两句：把 `install.ps1` 从"零写入校验器"恢复为**只增/只更新**的部署器——放弃 mirror-replace 删除语义、降档 Routine、补齐插件步/清理开关/预览，并对真实树完成首次运行。详情见归档目录。

## Source of Truth

* 常驻项目文档（**不随任务归档**）：`README.md`（部署契约与开关一览）· `AGENTS.md`（项目契约）· `docs/ai/AUTHORITY_CONTRACT.md`（权威/部署面契约）· `docs/ai/DSH-LANDING-NOTES.md`（DSH 派生方法与改点）· `docs/ai/INSTALLER_GUARD.md`（guard 过程记录，债已偿还）· `docs/ai/QUALITY_GATES.md`（项目质量清单副本）
* 归档任务记录：`docs/ai/archive/2026-09-15-h3c-add-update-only/`（本轮）· `.../2026-09-15-h3b-mirror-replace-superseded/`（被放弃的删除方案及其 9P 三轮）· `.../2026-09-15-h3a-slice-a/`（参数面与两条零写入路径）· `.../2026-09-06-dsh-landing/`（DSH 落地）
* `install.ps1` 当前形态：无参数 = 计划 → 校验 → 逐文件更新（覆盖前备份）→ 插件步；`-DryRun` / `-ValidateOnly` 零写入；`-RemoveStale` 唯一删除路径；退出码 `0=OK` / `1=FAILED`。
* base branch / base commit：`main`（工作分支即 `main`）· `origin/main` 落后于本地，**推送由人类执行**

## Review & Test Binding（SHA 绑定；final-review 收敛门与 Reviewer 读；语义见 AGENTS.md）

* review_base_sha：N/A — 本轮为 **Routine**（无 Reviewer、无 SHA 绑定）
* review_tip_sha：N/A — 同上
* review_verdict_9A：N/A — 人类选择 Routine 档
* review_verdict_9B：N/A — 人类选择 Routine 档
* tested_sha：证据 = 本文件 Work Log 的 75 条全绿运行（提交前对同一工作树执行；提交后 `git diff HEAD -- . ':(exclude)docs/ai/**'` 为空，即提交内容与受测内容逐字节相同）
* guard_effectiveness：N/A — 本轮未声称"回归用例有效（红→绿）"的装置产物；守护类断言只用**副本变异对照**（旧实现下实测为红），限度已记入债账
* review_sensitive_paths：`install.ps1 tests README.md AGENTS.md`（本轮 Routine，未用于审查绑定，仅登记）
* handoff_snapshot_sha：N/A — Routine（无双审窗口）

## Work Log

倒序，每条一行：[日期] [Agent] [做了什么] [commit]

* [2026-09-16] [Author] **harness 适配性收口（Routine；一轮把三个已裁项做完）**：① 堵住「Reviewer 可自行运行安装器」——DSH 无沙箱兜底下零写入只剩散文，且事故已发生两次；母本第一层 + `reviewer-prompt` ③(c) + 9A/9B/9P 三 prompt + 全局 File & Config Safety 共五处**具名**禁令（泛化禁令实测无效），并把「隔离临时 HOME 的 `tests/` 套件」写成唯一安全路径。② 两侧同改 Mode Routing「建议而不自我降级」+ Fix-Loop「早期停牌探针」。③ 偿还「`dsh/` 判据漂移无机械门禁」债（`tools/dsh-drift-check.ps1` + 冻结基线 292 行，负向对照实测）。④ 三分类契约可复现性测量（5 Reviewer × 7 项）→ 结论登记 `DSH-LANDING-NOTES.md` §7，**未据此改判据**。**`~/.dsh` 尚未同步**（部署须人类指示）。 | 未提交（Routine：人类扫 diff 后 commit）

* [2026-09-15] [Author] **任务收口**：squash 未推送的全部提交为 `main` 上的一笔；per-task 文件归档 `docs/ai/archive/2026-09-15-h3c-add-update-only/`；清掉仓外审查 scratch（`~/.dsh-review-holding/{dsh-landing,h3-installer-hardening}`）；按收口后的现状改准 `AGENTS.md` / `README.md` / `AUTHORITY_CONTRACT.md`（含"整树备份"副作用的订正）/ `INSTALLER_GUARD.md`（guard 债标记已偿还）。 | 见 git log
* [2026-09-15] [Author] **真机首次带插件的运行暴露并修掉 3 个缺陷**：人类在真机跑无参数部署，运行卡在插件步第 1 个（`claude.exe plugin install context7@…`，起于 19:24:25，数分钟零 CPU 零输出；文件面已在此之前完成且零写入）。诊断后 kill 该次运行（受管面复核仍为零改动：`would-write=0`、零新备份）。修复：① 每个插件安装**开始前**先打印 `[PLUGIN] installing … (timeout Ns)`，卡住可归因；② 加**每插件 180s 超时**（`INSTALL_PS1_PLUGIN_TIMEOUT_SEC` 可覆盖），超时 kill 并计 `failed`；③ 插件步纳入 try/catch，异常不再跳过汇总；④ 插件调用改用自持的 `ProcessStartInfo` 而非 `Start-Process -PassThru`——**5.1 腿当场抓到后者在 Windows PowerShell 5.1 下 `ExitCode` 为空**，会把 6 次成功调用全报成 `FAILED (exit )`；⑤ 载体优先 `.cmd`（不被 npm 的 `claude.ps1` 在进程内执行）；⑥ 更正 `[PLAN] stale rows …` 那句已过期的措辞。证据：套件 **75 条全绿**（含"逐个播报"与"超时被 kill"两例），两宿主（pwsh7 / PS5.1）实测插件步各 6 次调用且 exit 0。 | `ecbec13`
* [2026-09-15] [Author] 按人类指示**收口 5 项残余**：① 插件步落地；② `-RemoveStale`（**唯一的删除路径**、显式开关、目录仅空时删、**全文件无递归删除**）；③ `-DryRun` 预览（`[DIFF]` 逐文件 + `would-write=N` + `[WARN]`）；④ A3/skills 债清偿（两侧改目录枚举 + 第三 bundle 区分力用例，旧实现下实测为红）；⑤ 顺带修 B-1（空根三模式一致 FAIL）、B-2（大小写不敏感成员判定）、R-4/T-6（`planned` 契约与行级核对）、T-3（seed 缺失分支）。**首次真部署已对真实树执行**（`-NoPluginInstall`，exit 0；`would-write=0 / written=0 / backups=0`）。被取代的规划产物 `git mv` 归档；`[U]` 第 3 项与 `DSH-LANDING-NOTES.md` §5 同改。证据：套件 73 条全绿 + `REAL_DEPLOY_LOG.txt`。 | `d89062e` `02b7208`
* [2026-09-15] [Author] **人类裁决改向**：切片 B 由 mirror-replace 收窄为**只增/只更新**（永不删除；覆盖前逐文件备份为同级 `<name>.bak-<stamp>-<guid4>`；live-only 内容只报告 `[STALE]`）并**降档 Routine**。实现落地：`install.ps1` 写入路径 + `[DELETE]`→`[STALE]` + `RESULT=REFUSED` 退役、新增 `tests/install.Deploy.Tests.ps1`、四处测试契约改准、README 部署节改准；顺带**清偿"死代码六处"债**。证据：套件 55 条全绿。 | `8fbae9e` `3326759`
* [2026-09-15] [Author] 切片 B 规划（后被取代）：三轮 9P（round 1 = 7 Gaps；round 2 = B1–B4 + Required-1..8；round 3 = 修订后可批准 + B1–B4）→ 逐条表态并改写 AC1–AC9 / D1–D9；补跑 PROBE-D（白名单 `*.bak-*` 目录形态缺口，实测复现）与 PROBE-E（live-only 空目录确实进 `[DELETE] (dir)`）；scaffold `docs/ai/QUALITY_GATES.md`。 | `9b125aa` `9e3ab59` 等
* [2026-09-15] [Author] 切片 A 收敛处置：按人类裁决 A 宣布「按冻结验收收敛」（最近三轮无可复现的冻结条款违反），残余逐条分类移交 `BACKLOG_sliceB.md`（现随本轮归档）；per-task 文件归档；本文件换为空闲期账本。 | main 的 squash commit
* [2026-09-15] [Author] 切片 A 五轮双审（9P + 9A/9B round 1–5）：3 条修复（退出码 / 计数同源 / 枚举守卫 / 子树继承）+ 1 条 `disputed`（实测推翻）+ 1 条文本改准；套件 26 → 46 用例。 | 见归档目录

## Known Issues

* **[U] 未验证清单**（**不是债**；与 `docs/ai/DSH-LANDING-NOTES.md` §5 **必须逐条一致**）：
  1. 除 `AGENTS.md` 外的其余派生对（`reviewer-prompt.md` / `QUALITY_GATES.md` / `index.md` / `workflow-design-notes.md` / 7 个 phase）相对母本是否存在判据漂移 —— 触发：下一次改动任一该文件之前。
  2. 备用路径（headless）完整审查轮 —— 触发：首次用备用路径发审之前。
  3. ~~真实 9P 审查轮（两次都只是档位探针）~~ **已履行（2026-09-15）**：切片 B 规划期跑了 round 1/2/3 三轮真实 9P（verdict 全文见 `archive/2026-09-15-h3b-mirror-replace-superseded/review_9P.md`）。
  4. `~/.dsh/settings.yaml` 的 `reasoningEffort` 是否真被适配器读取 —— 触发：首次依赖 settings 层钉档位之前。
  5. ~~AC8 的机器态实跑~~ **已履行（2026-09-15）**：隔离 home 的机器态实跑由 `tests/install.Deploy.Tests.ps1` 承担，另对真实树跑过 `-DryRun` + 真部署（零写入），记录见本轮归档 `REAL_DEPLOY_LOG.txt`。
  6. `install.ps1` 的其余注释逐句对读（AC7 只核了备份/镜像语义那一组）—— 触发：下次改动该文件之前。**2026-09-15 部分履行**：写入路径那几段注释已随实现改准；其余段落仍待对读。
* **非阻断的测试增强遗留**（承接自归档的 `BACKLOG_sliceB.md` §7，均为"可以更好"而非缺陷）：T-4（机器态正面断言）、T-8（枚举顺序前提：已写进头注释）、T-10（argv 逐字冻结样本）、T-12（断言 `*` 通配 vs 字面量，路径含 `[` 时失配）。

## Fix-Loop Counter（review-fix 循环用；无则 "None"）

None —— 本轮为 Routine，无 review-fix 循环，`streak = 0`。

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
[DEBT] dsh/ 的相对母本"判据无漂移"缺少机械门禁（AC10 的判定对声称无区分力，9A-S4）| Payback trigger: 下次改动 dsh/** 之前 | ~~Impact: 判据漂移不会被任何门检出（上一任务靠 Reviewer 手工逐行读才排除）~~ **已偿还（2026-09-16，Payback-on-Touch：本轮即改动 `dsh/**`）**：新增 `tools/dsh-drift-check.ps1` + `tools/dsh-drift-baseline.txt`——17 对派生文件的全部差异行（292 条）冻结为基线，任何新增 / 改动 / 消失的差异行判红（退出码 1）并逐行点名；**区分力已实测**（只在 dsh 侧加一行 → 红且点名该行；内容哈希还原 → 绿）。**残余限度（如实登记）**：门只检「差异变了」，不判它是判据漂移还是机械改写——分类仍属人 / Reviewer；两侧同改（差异集合不变）不触发它，那正是「一套纪律」所要的。DSH 侧有意分歧的登记处 = `docs/ai/DSH-LANDING-NOTES.md` §6（当前仅 D1）
[DEBT] dsh/workflow/fanout-toolchain.md 的 DSH 事实绑定 @deepseek-ai/dsh 0.1.5-rc.x | Payback trigger: @deepseek-ai/dsh 升级后首次派发审查之前 | Impact: 参数/工具名变化会让调用范式静默失效（第 2 轮已复核一次）
[DEBT] ~/.dsh 的运行副本由人工同步产生，无 *.bak-*，且每次同步无落账规范 | Payback trigger: 首次用 install.ps1 覆盖 ~/.dsh 之前 | ~~Impact: 首次自动部署没有上一版可回退；人工同步可能被遗忘~~ **已偿还（2026-09-15）**：`install.ps1` 已成为该副本的部署器并**首次对真实树运行完毕**（`-NoPluginInstall`，exit 0）；本次实测 `would-write=0 / written=0 / backups=0`（本机本就全同步），此后每次覆盖都会先落同级 `<name>.bak-<stamp>-<guid4>` 备份；运行记录见 `archive/2026-09-15-h3c-add-update-only/REAL_DEPLOY_LOG.txt`
[DEBT] Emergency installer acknowledgement guard（原始登记 = `docs/ai/INSTALLER_GUARD.md` 的 `[DEBT]`）——**已偿还（2026-09-15，Payback-on-Touch）**：真实控制全部落地（`-DryRun`/`-ValidateOnly` + 只增/只更新写入路径 + 插件步控制 + keep-local-only 保护），守卫与旧开关已移除；继承要求五条的逐条状态见该文件。本条在此仅作指针，不重复登记
[DEBT] 本仓**没有常驻的守护有效性装置**（无「变异生产代码 → 目标测试因预期断言而红」的结构化产物能力）：本轮守护类断言只用**副本变异对照**（同一断言在旧实现/注入后的副本上必须红）证明区分力，**不构成**母本要求的装置产物（2026-09-15 登记）| Payback trigger: 下次需要声称「回归用例有效（红→绿）」的结构化产物、或有 AC 依赖该更强声称之前 | Impact: 「把机制删掉这些用例会不会变红」这一层未被机械证明；目前无 AC 依赖它
[DEBT] A3 的 dsh/skills 臂无区分力——**已偿还（2026-09-15）**：两侧均改为枚举 `dsh/skills/*`，并新增区分力用例（FakeRepo 内建第三个 bundle ⇒ 计划必须包含它且必须真的部署）；区分力已实测——同一断言在旧实现（`git show HEAD` 的 install.ps1）下为红 | Payback trigger: —（已偿还）| Impact: —
[DEBT] 切片 A 遗留的死代码/死参数（`$script:Plan` / `$script:checkFailed` / `$Roots` / 首个 `$RootSpecs` / `Test-PathInsideDirectory` / `Invoke-InstallerCase -Environment`）——**已偿还（2026-09-15）**：六处全部删除，证据 = 收紧模式 `Select-String -Path install.ps1,tests\TestHelpers.ps1 -Pattern '\$script:Plan\b|\$script:checkFailed|\$Roots\b|Test-PathInsideDirectory|\$Environment'` 零命中 + 套件全绿 | Payback trigger: —（已偿还）| Impact: —
```

**已偿还/已闭合但仍保留在册的理由**：核验命令只数 `^[DEBT]` 行、不区分是否已偿还；保留可让"何时还的、还成什么样"有据可查。

**本轮触碰面与 Payback-on-Touch 判决**：本轮改 `install.ps1` ⇒ `[U]` 第 6 项（注释逐句对读）部分履行（写入路径那几段已改准，其余待下次）；`INSTALLER_GUARD` 债、A3 债、死代码债、`~/.dsh` 债均在本轮偿还；其余各笔 trigger 与本轮不匹配（`tools/ac4-*`、`dsh/**` 判据门、`@deepseek-ai/dsh` 升级、AC6 未跟踪假设），维持原状态。

## Quality Gates

本轮为 Routine（人类明确降档），未走 `/implement` 的闸门流程；下表按归档时的实际证据填：

| 维度/闸门 | 状态(Pass/N/A) | 证据文件或 N/A 原因 |
|---|---|---|
| 测试 QA(11.1) | Pass | 套件 75 条全绿（`Tests Passed: 75, Failed: 0`，exit 0），含新增 20 条部署契约用例；守护类断言配副本变异对照 |
| 安全基础(11.2) | Pass | 无密钥硬编码；凭据/机器态路径的读写一律显式排除（`machine-local-untouched` 谓词 + 用例）；覆盖前逐文件备份；无递归删除 |
| 敏感面扩展(11.2) | Pass | 触面 = 本机受管配置文件的覆盖与备份；路径校验（根冲突 / 空根 / 源树内 / 机器态内 / 形状）全部在执行前拦截 |
| 隐私/合规(11.3) | N/A | 不处理用户数据；脚本刻意不读不写凭据与 PII 面 |
| 可访问性(11.4) | N/A | 无界面；CLI 输出纯 ASCII（5.1 兼容要求） |
| 设计层闸门(§5) | N/A | 无界面 / 无面向用户内容 |

## Quick-Version Fields（快速版填，正式可省）

* Applicability Scan(0.1)：N/A — 本轮为 Routine 降档，未走 `/define` 0.1 扫描
* Human Approval Evidence：人类 2026-09-15 在对话中逐步拍板（放弃 mirror-replace → 只增/只更新；降档 Routine；指示收口 5 项残余；指示 squash / 归档 / 清理）

## Next Step

1. **人类**：`git push`（本仓规则：agent 绝不 push）。当前 `main` 领先 `origin/main` 一笔（本轮 squash 后的收口提交）。
2. **可选：真机插件安装**（**网络操作，按人类指示才做**）：`pwsh -NoProfile -File .\install.ps1`（不带 `-NoPluginInstall`）。⚠️ 2026-09-15 首次实测卡在第 1 个插件（marketplace 拉取无响应）；现已有逐插件播报 + 180s 超时 kill + 失败计入 `failed=N`。本机 6 个插件**已全部安装**（`~/.claude/plugins/installed_plugins.json`），故日常建议直接用 `-NoPluginInstall`。
3. **删除能力若仍需要**：属**新任务**，须重新立项（勿在后续改动里顺手加回）。
4. ~~**未合并分支 `task/h3-installer-hardening`**~~ **已处置（2026-09-15）**：它的设计（mirror-replace + 确认开关 + 整树备份）早被放弃，其文档与 main 的归档副本逐字节相同；删除前先做了两件提取——① 它**独有**的 `docs/ai/review_9P.md`（437 行，含 round 1 作废与那次 127 文件事故的损害表）已逐字落进 `docs/ai/archive/2026-09-15-h3-installer-hardening-stopped/review_9P.md`，并在同目录 README 里说明来源与用途；② 它独有的两条测试用例（**空 home 部署的逐文件完备性**、**install.ps1 纯 ASCII 守卫**）已移植进 `tests/install.Deploy.Tests.ps1`。随后分支删除。
   > 短期可回退窗口：被删分支的提交仍在本地 reflog 里（默认 90 天）；若需要旧实现，也可从 `pre-squash-2026-09-15` 之外的历史中找回相应文件（该分支从未进入 `main`）。
5. **历史备份堆积**：`~/.claude` 等受管面下有 157 个 `*.bak-*`（约 2.3 MB，2026-08/09 旧安装器所留）。它们在 keep-local-only 白名单里 ⇒ **永远不会被报成 `[STALE]`**，`-RemoveStale` 也不会碰；要瘦身只能人工决定。
