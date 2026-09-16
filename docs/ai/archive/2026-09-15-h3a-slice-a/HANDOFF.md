# HANDOFF.md

> per-task 核心交接文件，每次 Agent 切换前更新。简短，证据指向 git log 和 last_test_run.txt。
> 下列每节都保留（无内容写 None/N/A）；Quality Gates 必须逐维度表格，不得用"已过所有闸门"一句话替代。
> **本文件当前是切片 A 的任务态**（`Current Phase: Planning`）。上一任务（H3 停牌）的记录已归档于 `docs/ai/archive/2026-09-15-h3-installer-hardening-stopped/`；更早的空闲期账本归档于 `docs/ai/archive/2026-09-15-idle-debt-ledger/HANDOFF.md`。**未偿债不随任务消失**：下方 9 笔 `[DEBT]` 从该账本逐字承接。

## Current Phase

**`Converged (frozen acceptance)` / 切片 A 实现收敛（人类 2026-09-15 裁决 A）** —— **判据**：五轮审查（9P + 9A/9B round 1–5）里，最近三轮**没有任何存活且可复现的"实现违反冻结条款"**：round 3 的一条已修（守卫）、round 4 的一条已修（子树继承）、round 5 的两条一条**被实跑推翻**（`disputed`，见证据 §G-1）、一条是**文本落后于裁决**（已按人类授权改准 `9b3e623`）。round 3/4/5 其余发现全部属"切片 B 语义 / 需求裁决 / 测试增强 / 文档改准"，已逐条分类移交 → **`docs/ai/BACKLOG_sliceB.md`**（不再对切片 A 开审；若将来重开，先立终止规则）。
**本切片当前状态**：代码 tip `8efeead`（`install.ps1` 601 行 + `tests/` 五个文件 **46 用例**），冻结命令 **46/46 exit 0**，installer sha256 `5A67C53C…`，证据 `last_test_run.txt`（`tested_sha` 已同步本代）。**Fix-Loop streak = 2**（round 3 计一次 `yes`；round 4/5 的 Blocking 均 `no` 不递增）——两次窄修复例外均由人类逐次批准，本轮例外仅用于"取证 + 文档改准 + 断言"，**未改生产语义**。
⚠️ **任务级仍不得声称 converged**：`~/.dsh` 首次真部署债（AC10 第二项）**Unpaid**（人类动作，见 BACKLOG §5 H-1）；切片 A 的收敛是**按冻结验收的实现收敛**，不是任务级收敛。
**上一任务状态**：`task/h3-installer-hardening` = **`STOPPED, NOT CONVERGED`**（streak 2 硬停）。其产出（`install.ps1` 627 行 + `tests/` 44 用例 + 文档改准 + 三轮 verdict）**只作参考**，不是可交付版本；**其文档改准属切片 D，本分支不含**。
**上一任务状态**：`task/h3-installer-hardening` = **`STOPPED, NOT CONVERGED`**（streak 2 硬停）。其产出（`install.ps1` 627 行 + `tests/` 44 用例 + 文档改准 + 三轮 verdict）**只作参考**，不是可交付版本；**其文档改准属切片 D，本分支不含**。

## Task Summary

**切片 A**：把 `install.ps1` 的**参数面**做成绑定期硬门（6 参数 + 3 ParameterSet），落地 `-ValidateOnly`（前置校验）与 `-DryRun`（完整计划）两条**零写入**路径，二者与真部署共用**同一个校验谓词** `Test-Plan`；确定退出码契约与 `[PLAN]` / `[CHECK]` / `[SUMMARY]` 输出契约。**范围外**：任何真实写入（mirror-replace / 备份 / 删除）、插件步、部署后自检汇总（属切片 B/C）。详见 `docs/ai/TASK_BRIEF.md`。

## Source of Truth

* `docs/ai/TASK_BRIEF.md`（切片 A 的验收与 Frozen Acceptance 唯一落点）· `IMPLEMENTATION_PLAN.md`：`Status: Approved`（人类亲填，批准 commit `bc3cb39`）· `PRODUCT_BRIEF.md`：N/A · 项目 `QUALITY_GATES.md`：本分支无（用 `~/.dsh/workflow/QUALITY_GATES.md` 母本）
* Base branch / base commit：`task/h3a-parameter-surface` @ `e9917a1`（= `main` tip）
* approval_commit_sha: `bc3cb39`（人类批准切片 A 计划）
* plan_review_9P: round 1 已完成 → `docs/ai/review_9P.md`（verdict 逐字 + Author 逐条表态 + VN 实跑结果）；**round 2 未跑**（人类裁决：切片 A 不再补跑 9P，改为冻结前谓词实跑）
* 参考材料（只读）：`git show task/h3-installer-hardening:install.ps1`、该分支 `tests/**`、归档目录

## Review & Test Binding（SHA 绑定；final-review 收敛门与 Reviewer 读；语义见 AGENTS.md）

* review_base_sha: `e9917a1`（= `main`；切片 A 的分支点）
* review_tip_sha: `8efeead5a5217df7b5011aa789898a405d343ee3`（round 5 处置：分区不变式用例 + 嵌套样本；**9A 与 9B round 6 必须同一个**）
* review_verdict_9A / review_verdict_9B: round 1 = 9B 不通过（正文不完整）；round 2 = 两侧均不通过（去重 3 个独立 Blocking，已处置）；round 3 = 9A 通过 / 9B 不通过（1 条 `caused_by_last_fix: yes` → **streak = 2 触硬停**，人类批准窄修复例外）；round 4 = 9B 有条件通过 / 9A 不通过（1 条 `no`：白名单子树语义 → 人类裁决子树继承 + 第二次例外）；**round 5 = 9B 通过（0 Blocking）/ 9A 不通过（2 条 `no`）——PB-1「嵌套形态仍不分区」经 VN-1 实跑**推翻**（`disputed`，见证据 §G-1）、PB-2「冻结文本落后于裁决」**已按人类授权改准**（`9b3e623`）**；五轮 verdict 逐字落 `docs/ai/review_9{A,B}.md`。**round 6 待跑**
* tested_sha: `8efeead5a5217df7b5011aa789898a405d343ee3`（= `review_tip_sha`；`last_test_run.txt` 的 `tested_sha` 行已同步为本代；installer sha256 `5A67C53C…`）
* guard_effectiveness: N/A —— 不声称「回归用例有效（红→绿）」的结构化产物（见 Remaining Risks 的对应 `[DEBT]`）
* review_sensitive_paths: `install.ps1 tests docs/ai/TASK_BRIEF.md`（切片 A 的生产面；`docs/ai/INSTALLER_GUARD.md` 已还原到 base，故**不在**清单内）
* handoff_snapshot_sha: 本文件所在 commit（`docs(handoff)` 快照；Author 在窗口开启时按 `git log -1` 逐字写进两份 review prompt）

## Work Log

倒序，每条一行：[日期] [Agent] [做了什么] [commit]

* [2026-09-15] [Author] `/implement`（切片 A）：从停牌分支取参考实现 → **删掉全部写入函数**（切片 A 零写入）→ Deploy 集改为"计划+校验+**REFUSED**"（㉗）→ 归一化根/白名单（含末段）/机器态**包含关系**（㉓）→ 写 `tests/{TestHelpers,install.Parameters,install.Plan,install.Validate}`（26 用例）→ `wip(author)` 后跑冻结命令 26/26。**实现期自查抓到一处测试侧过宽判定**（`-like '*archive*'` 会把 ㉙ 的反例 `myarchive.md` 误算）→ 改为路径段判定。 | `709649d`
* [2026-09-15] [Author] `/define`（切片 A）：18 维适用性扫描 + 冻结验收 AC1–AC3，含**每条谓词的冻结前实跑与其负向对照**（见 `TASK_BRIEF.md` → 「谓词冻结前实跑证据」）。 | 本文档 commit
* [2026-09-15] [Author] 人类裁决「重新拆任务」→ 从 `main` 建 `task/h3a-parameter-surface`；承接账目：停牌任务 8 份 per-task 记录归档、`INSTALLER_GUARD.md` 的 `Repaid` 标记回活树、旧空闲期 HANDOFF 归档、本文件按模板重写并逐字承接 9 笔 `[DEBT]`。 | 本文档 commit

## Known Issues

* **本分支的文档面是 H3 之前的状态**（README 仍写"迁移期 guard 锁定"、根 `AGENTS.md` 同）：**有意为之**——文档改准属切片 D；读这两处时须知其对 `install.ps1` 的描述已过期。
* **停牌任务的两处未处置发现（不得当成已修）**：① AC9① 的判定形态曾两次为假绿（`git grep` 输出是 String，被 `.Line` 过滤 → 恒真），修法与教训见归档的 `review_9B_r2.md`；② README 声称"无 claude CLI 时打印手动命令"而实现只打印 SKIPPED。两者在本分支都还不存在相关代码，但它们是后续切片的输入（切片 C 补 CLI 缺席分支；切片 D 把"谓词实跑 + 负向对照"做成硬前置）。
* **承接的 `[U]` 未验证清单**（**不是债**；与 `docs/ai/DSH-LANDING-NOTES.md` §5 **必须逐条一致**，改一处必须同改另一处）。**本分支 §5 为 H3 之前原措辞**，故此处同样按原措辞承接（停牌任务对第 5/6 项的"已处置"改写**随其未收敛而不作数**）：
  1. 除 `AGENTS.md` 外的其余派生对（`reviewer-prompt.md` / `QUALITY_GATES.md` / `index.md` / `workflow-design-notes.md` / 7 个 phase）相对母本是否存在判据漂移 —— 触发：下一次改动任一该文件之前。
  2. 备用路径（headless）完整审查轮 —— 触发：首次用备用路径发审之前。
  3. 真实 9P 审查轮（两次都只是档位探针）—— 触发：下一次启用 Critical 之前。
  4. `~/.dsh/settings.yaml` 的 `reasoningEffort` 是否真被适配器读取 —— 触发：首次依赖 settings 层钉档位之前。
  5. AC8 的机器态实跑（临时 HOME / 一次性 profile 下跑安装器 + 三项哈希）—— 触发：`install.ps1` 解锁后首次运行。
  6. `install.ps1` 的其余注释逐句对读（AC7 只核了备份/镜像语义那一组）—— 触发：下次改动该文件之前。

* **⚠️ 事故（2026-09-15，Author 自查自报；与 H3 停牌任务的 round-1 事故同型，但这次是 Author 造成的）**：为给切片 A 的 AC 做"谓词冻结前实跑"，我跑了 `pwsh -NoProfile -File .\install.ps1 -IUnderstandThisReplacesLiveConfig`——**在本分支（`main` 版 = 仍带 guard 释放语义的旧脚本）上该开关不是"报错"而是"确认后放行"**，于是它在真机上真的部署了，120s 超时被杀。后果：`~/.claude/{rules,workflow,commands}` 被 mirror-replace 删掉 **127 个本机独有文件**（workflow `archive/**` 82 + 旧 `*.bak-*` 45），并生成含 `.credentials.yaml` 的 `~/.dsh.bak-20260915-104625`（19963 文件）。**已按人类批准纯增量恢复**（85/116/22、archive 82 全回、共同文件零内容差异）并删除该凭据副本；`~/.dsh` 内容未被改；仓库工作树未被触碰。**根因**：我把该探针当成只读样本（在停牌分支它确是"未知参数"），**跑之前没有先确认本分支的 `install.ps1` 是哪一版**。**教训（已写进切片 A 的 Constraints）**：任何执行型探针在跑之前，必须先读**被执行的那份脚本**、确认该参数在**这一版**上的语义；"在另一分支上是安全的"不构成理由。
* **由此对切片 A 的直接约束**：AC1 的 K4 样本（已移除开关）在本分支实现前的**预跑**就是上面那条命令——**它不可再跑**（旧脚本会释放 guard）。故 TASK_BRIEF 的「谓词冻结前实跑证据」只对**安全可跑**的谓词取证（已记录 P1 的真实输出：今日本分支 `-DryRun` → exit 1「找不到与参数名称 'DryRun' 匹配的参数。」= 通过样本当前失败，判定有区分力），其余谓词的冻结前取证改为**只读形态**（`Get-Command`/`Select-String`/`git grep`/签名比对），不得触发任何脚本执行。

## Fix-Loop Counter（review-fix 循环用；无则 "None"）

**round 1（实现审，9B 盲审）= 不通过**：4 条 `[Product Blocking]`，`caused_by_last_fix` 全部 = `no`（首次实现引入，无上一轮修复）→ **streak 不递增，仍为 0**。Author 逐条核验：BL-1/BL-2/BL-3 成立并已修（各带冻结前负向对照），BL-4 正文未取回（该子 agent 已不可续 → round 1 记为**正文不完整**）。修复 commit `7259ee1`，证据 `1434102`。

**round 2（9B 盲审 + 9A 常规审，同一 tip `7259ee1` / 快照 `21a4f65`）= 两侧均不通过**：9B 3 条、9A 2 条 `[Product Blocking]`，去重后 **3 个独立问题**——① validate 侧 `delete/preserve` 是结构性 0（`Show-Plan` 内累加，validate 从不调用它）→ **`caused_by_last_fix: yes` → streak = 1**（未达硬停阈值 2）；② `install.ps1` 头注释把切片 B 的终态写成当前行为（两侧独立命中）；③ `INSTALLER_GUARD.md` 越出冻结 Non-Goals 且证书引用的能力不在本树（两侧独立命中）。两张 verdict 已逐字落 `docs/ai/review_9{A,B}.md`（`d8a0bc5`），Author 逐条表态见各文件节末。

**下一动作 = 一次性修复轮**：`Get-PlanCounters` 让三模式计数同源 + 重写 `install.ps1` 1–40 行 + `INSTALLER_GUARD.md` 已还原到 `e9917a1`（人类裁决）+ `TASK_BRIEF.md` 三处改准（K1 与 ㉗ 一致 / A3 进 AC2 / `-DryRun` 的 `RESULT=OK` 语义）+ 补测（K9④、AC3⑦ 的 ④⑥、validate 侧计数断言、5.1 腿 `host=` 断言、插件清单与 `claude/settings.json` 对齐、㉔ 逐用例宿主证据）→ 复跑冻结命令 → 落新证据与 HANDOFF → 开 **round 3**（9B + 9A，新 tip + 新快照）。

**round 3（9A 常规审 + 9B 盲审，同一 tip `976d2e1` / 快照 `b530d9b`）= 9A 通过、9B 不通过（1 条）**：9B 的 BL-1 判 `caused_by_last_fix: yes`——镜像目标存在为**文件**时，`Get-MirrorDelta` 的枚举返回该文件本身、相对路径 `Substring` 抛异常，而 `Get-PlanCounters` 在模式分支前无条件调用它 → `-ValidateOnly` 丢掉点名 `[CHECK] … FAIL` 与 `[SUMMARY]`（Author 已独立实测该 cmdlet 语义与 `:215` 的枚举形态）。**人类裁决：采信 `yes` → streak 1→2 触硬停；同时批准「窄修复例外」**（母本第三个出口）。已按例外执行：枚举前加容器守卫（`:214`），使既有的 `Test-Plan` 形状检查（`:392-393`）重新可达并点名失败；新增回归用例 12（validate + deploy 两形态）。9A 的 7 条 NB 中 NB-5（本文件账目失准）本轮同轮对齐，NB-1/G5（A3 的 skills 臂共享硬编码，预言机会与被测代码抄同一常量）登记为 `[DEBT]`。

* streak（当前连续计数）: **2 —— 已达硬停阈值**（round 2 的 9B BL-1 计一次 + round 3 的 9B BL-1 计一次）。硬停的三个合法出口里，人类选择「人类批准的例外」：仅允许本轮这一处窄修复（守卫 + 回归用例 + 账目对齐），**不得**据此再开常规修复轮；round 4 若再出现 `caused_by_last_fix: yes` 的 `[Product Blocking]`，只能回退 / 重新拆任务。

> 递增/重置/停止/轮次上限及其与合并门的优先级，**一律以 `AGENTS.md` → Fix-Loop 计数与跨轮硬停为准**。`caused_by_last_fix` 由 Reviewer 判定，Author 只逐字转录。

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
[DEBT] ~/.dsh 的运行副本由人工同步产生，无 *.bak-*，且每次同步无落账规范 | Payback trigger: 首次用 install.ps1 覆盖 ~/.dsh 之前 | Impact: 首次自动部署没有上一版可回退；人工同步可能被遗忘
[DEBT] 本仓**没有常驻的守护有效性装置**（无「变异生产代码 → 目标测试因预期断言而红」的结构化产物能力）：本任务的守护类 AC 只用**测试套件自身的负向对照**（同一判定在对照样本上失败）证明区分力，**不构成**母本要求的装置产物（2026-09-15 H3 计划期登记）| Payback trigger: 下次需要声称「回归用例有效（红→绿）」的结构化产物、或有 AC 依赖该更强声称之前 | Impact: 「把机制删掉这些用例会不会变红」这一层未被机械证明；目前无 AC 依赖它，故**不阻止本任务收敛**
[DEBT] A3 的 dsh/skills 臂无区分力：`install.ps1` 的 `Build-Plan` 与测试侧独立预言机 `Get-ManagedDeploySet` **硬编码同一常量列表**（`'dual-agent-workflow','independent-review'`），故"计划动作目标 == 受管面"这条集合相等断言在新增第三个 skill bundle 时**两侧同时缺失、恒绿**（2026-09-15 9B round 3 的 NB-1 / 9A 的 G5；本仓"谓词无区分力"第 5 次同型）| Payback trigger: 下一次新增或改名 `dsh/skills/<bundle>` 之前；或切片 B 落地 skill 枚举之前（改 `Get-ChildItem dsh/skills -Directory`）| Impact: 新增 skill 会被静默漏部署，而 A3 仍报"集合相等"；今日仓内恰为 2 个目录故无当前行为偏差
[DEBT] 切片 A 遗留的五处死代码/死参数未清：`install.ps1` 的 `$script:Plan`、`$script:checkFailed`（只写不读）、`$Roots`、首个 `$RootSpecs` 赋值，以及 `tests/TestHelpers.ps1` 的 `Test-PathInsideDirectory`（无调用点）与 `Invoke-InstallerCase -Environment`（无调用者）（2026-09-15 review 9A NB-4 / 9B NB-6，两轮点名未清）| Payback trigger: 下一次改动 `install.ps1` 或 `tests/TestHelpers.ps1` 之前 | Impact: 死状态会让后续读者误判控制流；不影响当前任何验收判定（无 AC 依赖它们）
```

**已偿还/已闭合但仍保留在册的理由**：第 3、4、5 条分别标注"已偿还 / 已闭合"，**保留为历史记录**；核验命令只数 `^[DEBT]` 行、不区分是否已偿还。

**本任务触碰面与 Payback-on-Touch 判决**：切片 A 要改 `install.ps1` → `[U]` 第 6 项（注释逐句对读）在本切片内履行；`INSTALLER_GUARD` 的 guard 债已由停牌任务偿还并保留在活树；其余各笔 trigger 与本切片不匹配（`tools/ac4-*`、`dsh/**`、`@deepseek-ai/dsh` 升级、AC6 未跟踪假设），维持原状态。`~/.dsh` 那笔的**落账规范**在停牌分支（属切片 D），**首次真部署未发生**（9A 的 Debt Verdict = `Unpaid`）。

## Quality Gates

对照 `/define` 0.1 标「关注」的维度 + 恒查安全基础，逐行（**实现与测试完成前不填 Pass**）：

| 维度/闸门 | 状态(Pass/N/A) | 证据文件或 N/A 原因 |
|---|---|---|
| 测试 QA(11.1) | **Pass** | `docs/ai/last_test_run.txt`：冻结命令 **45/45 exit 0**（绑定 installer sha256 `5A67C53C…`，`tested_sha = 09df8d7`）；AC1（K1 三形态 + K8 三样本）/AC2（含 A3 集合相等 + 子树继承样本）/AC3（K9③④、尾分隔符与机器态的 **deploy 形态**）的负向对照均在用例内；probe D/E 各为该轮新谓词的冻结前负向对照 |
| 安全基础(11.2) | **Pass** | 绑定期硬门（K1/K4/K5/K6/K7 + K8 负向对照）；`REFUSED`/`FAILED` 均**非零退出**；`-DryRun`/`-ValidateOnly` 零写入（目标根哈希含目录行不变）；目标不落源树/机器态面（含尾分隔符变体）；镜像目标存在为**文件**时点名拒绝而非崩溃（用例 12）；白名单**子树继承**（保留目录的内容不得进 `[DELETE]`）；5.1 腿真跑 `powershell.exe` 并逐用例留证（证据 §E）；无凭据/密钥面（纯 ASCII、无网络） |
| 敏感面扩展(11.2) | N/A | 不涉及认证/支付/用户数据/对外网络 |
| 隐私/合规(11.3) | N/A | 不处理 PII |
| 可访问性(11.4) | N/A | 无界面；CLI 输出为纯文本 |
| 设计层闸门(§5) | N/A | 0.1 第 5/6 维 N/A；第 4 维转为 AC 的输出契约 |
| 产品策划/PM(第 3 维) | Pass | 范围边界显式：`TASK_BRIEF.md` → Goal / Non-Goals |
| 内容(第 15 维) | N/A（本切片） | 文档改准属切片 D |

* **⚠️ 事故（2026-09-15，Author 探针协议缺陷；第三方模块受损并已修复）**：为给三条新谓词做冻结前负向对照，我在**同一 pwsh 进程里既写 `install.ps1` 又跑 Pester**。PowerShell 的 Pester 在**调用者作用域**运行测试容器并覆盖同名变量（旁证：同命令内 `$d` 被覆盖成 `System.Collections.Hashtable`），于是我随后的 `[System.IO.File]::WriteAllText($p, …)` 把安装器正文写进了 `~\.dsh` 之外的第三方模块文件 `C:\Users\16097\Documents\PowerShell\Modules\Pester\6.0.1\Pester.ScriptScope.ps1`，使 **Pester 6.0.1 完全不可用**（容器加载期即失败：`找不到与参数名称 'ScriptBlock' 匹配的参数`）。**损害范围** = 该目录内仅此一个文件（其余 mtime 仍为安装时的 2026/7/18）。**修复**：经人类授权联网 `Save-PSResource -Name Pester -Version 6.0.1` 取回原件、**只替换该文件**，还原后 `sha256=A5E038F8…` 与包内一致，最简测试 + 主套件 37/37 均通过。**由此产生的作废项**：受损期间跑出的 Probe B/C 首次输出（全红）**作废**，已按新协议重做（见 `last_test_run.txt` §E/§F）。**纪律（本任务内生效）**：写文件、跑 Pester、还原必须分处不同命令；绝不在同一进程里既写盘又跑 Pester。

## Quick-Version Fields（快速版填，正式可省）

* Applicability Scan(0.1)：见 `docs/ai/TASK_BRIEF.md` → Dimension Applicability Scan。
* Human Approval Evidence：待人类批准切片 A 的计划。

## Next Step

1. **重跑双审（round 2）**：同一 `review_tip_sha`（`7259ee1`）+ 同一 `handoff_snapshot_sha`（本文件所在 commit）上跑 **9B（盲审）** 与 **9A**（`subagent`、`deepseek-official` / `deepseek-flash` / `high`、零写入）。prompt 必须逐字包含：**禁止任何执行型探针**（尤其禁止 `install.ps1` 的一切执行形态与 `-IUnderstandThisReplacesLiveConfig` 字面）、禁止打开 `docs/ai/review_9*` 与 `docs/ai/archive/**`、审前快照自检（HEAD == handoff_snapshot_sha + 工作树干净）。
2. **取回 9B round 1 的缺失正文**：`BL-4` 与 `## Test Coverage Gaps` 之后的小节（返回正文被截断），连同已确认的 BL-1/BL-2/BL-3 一并逐字落 `docs/ai/review_9B.md`；Author 逐条表态（`fixed` / `wontfix + 理由` / `deferred + [DEBT]`）。
3. **落 9A verdict** 到 `docs/ai/review_9A.md`（当前为空）。
4. **`/final-review` 收敛门** + 人类 commit（Agent 不 push、不 merge）。
5. **仍未偿还**：`~/.dsh` 首次真部署（AC10 第二项）需人类按 runbook 执行 → 在那之前**不得**声称 converged。
6. 切片 B（真实写入路径）、C（插件步 + CLI 缺席分支）、D（文档改准 + 验收判定层）待定义。