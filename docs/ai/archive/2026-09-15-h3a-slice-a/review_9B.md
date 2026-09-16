# review_9B.md — 切片 A 独立审查（9B 盲审）

> 本文件逐字转录 Reviewer 返回正文，Author 未改写。Author 的逐条表态另附（round 2 表态见下方节末，尚未落账者以 HANDOFF 的 Fix-Loop 节为准）。

## round 2 — review_tip_sha `7259ee14f3b533ba08019c398f52064305436d53` / handoff_snapshot_sha `21a4f653091d62ea17ee436e6141e5769f0dcc6e`

**判定：不通过（3 条 `[Product Blocking]`）**

---

**证据头**
* `observed_head_sha`: `21a4f653091d62ea17ee436e6141e5769f0dcc6e`（== 要求值）
* `worktree_clean`: **yes**（`git status --porcelain` 0 行；`--ignored` 亦为空，无 verdict 类残留）
* `read_handoff_from`: **工作树**（`docs/ai/HANDOFF.md` + `docs/ai/last_test_run.txt` 均从工作树读，未用 `git show <tip>:…`）
* `model_route`: `deepseek-official/deepseek-flash@high`（子 agent 自报值，非证据；请 Author 与实发参数逐字比对）
* `writes_performed`: **none**（全程仅 `git rev-parse/status/diff/log/show`、`Get-Content/Select-String/Get-ChildItem/Get-FileHash`；未执行 `install.ps1` 任何形态，未出现 `-IUnderstandThisReplacesLiveConfig`）
* 隔离：未打开 `IMPLEMENTATION_PLAN.md`、`docs/ai/review_9*`、`docs/ai/archive/**`；diff 带全部排除项。
* 我独立核到的事实：`install.ps1` 工作树 sha256 = `A0D3F677…0061F` == `last_test_run.txt:5` 的 `installer_sha256`；`It` 计数 15+7+9+6 = **37** == 声称；`7259ee1..HEAD` 只有两份文档变更（代码/测试即 tip 内容）；§F 的 Pester 修复哈希独立复算相符（`len=17212 sha256=A5E038F8…`，mtime 2026/7/18）。

## Review Verdict

**不通过**（3 条 `[Product Blocking]`）。

* ① 三谓词判别力：`REFUSED` 非零退出**按构造可判**（`Show-Summary` 现仅 OK→0）；5.1 腿**可判且无静默空转**（宿主存在性用例 + §E-3 的 4 红/2 绿解析差分）；**计数器谓词不可靠** → BL-1。
* ② `planned` 与模式无关（`install.ps1:524`，分支前一次计算，成立）；`delete/preserve` **不同源** → BL-1。
* ③ K1 与 K9 闭集关系无冲突（K1a=Deploy 集+K9 取值域、K1b=字面零参数，符合 ㉗ 与执行前置约束②）；但**退出码契约与文件头注释仍自相矛盾** → BL-3。
* ④ 5.1 腿确实把安装器交给 `powershell.exe`：`$HostExe` 同一字面量用于启动 wrapper 与 wrapper 内启动安装器，且 §E-3 证明安装器**被 5.1 解析**；残余仅为 `psver`/`host` 由 wrapper 自报（无用例断言 `host=`）。

## Blocking Issues

* **[Product Blocking] `[SUMMARY] delete=/preserve=` 在 `-ValidateOnly` 下是结构性 0，且断言自证同源。**
  `install.ps1:299-300` 只在 `Show-Plan` 内累加，而 validate 分支（`:526-536`）从不调用 `Show-Plan`：同一棵树 `-ValidateOnly` 报 `delete=0 preserve=0`，`-DryRun` 报 `delete=2 preserve=3`；且该 validate 运行自己会打印 11 行 `[PRESERVE] … (machine-local, never touched)`（`:529-531`）配 `preserve=0`。`:522-523` 的注释「Counters are mode independent」对 3 个计数器中的 2 个为假。
  具体后果：以 validate 输出为准的下游（人或切片 B 的机械门）会得出「这次部署什么也不删」；同名计数器在两种模式下语义不同。
  另：§C 声称「两处独立产物交叉校验」，但行与计数器出自**同一个 `$delta`**（`:291-300`），delta 本身算错时两者同步缩小、用例仍绿——该谓词只能判别 BL-2 那一次具体变异。
  `caused_by_last_fix`: **yes**（`7259ee1` 把累加放进 `Show-Plan`，新增的 test 1b 只交叉核 `planned` 一项）。

* **[Product Blocking] `docs/ai/INSTALLER_GUARD.md` 在本 diff 内新增「Repaid」证书，其引用的能力不在本树。**
  `:85`「a no-argument run is a real deploy again」↔ ㉗ 与 `install.ps1:555`（REFUSED、exit 1）；`:95-100`「the plugin step is exercised offline through a fake `claude.cmd` shim whose argv is recorded」「`-DryRun`/`-ValidateOnly` cover the plugin step」↔ TASK_BRIEF Non-Goals（插件步属切片 C）与套件自身的 K8 断言「shim 日志为空」（`install.Parameters.Tests.ps1:107`）；`:101-105`「per-target `<name>.bak-<stamp>` copies … plus a deployment summary」↔ `install.ps1:467-468`（写入/备份函数被**故意移除**）。
  具体后果：requirement 5 的前置条件（guard 只在「真实控制落地」的同一次变更中移除）未满足，而账本已记 Repaid → trigger 用尽，切片 B/C 失去「补备份与插件步覆盖」的提醒；读者拿到三条与活代码相反的契约陈述。
  `caused_by_last_fix`: **no**（`dccb1c1` Define 期落地，早于 ㉗；`7259ee1` 未触碰）。

* **[Product Blocking] `install.ps1` 头部注释把切片 B 的终态写成这一版的行为。**
  `:9`「Default (no parameters) = real deploy」↔ ㉗ / `:545-555`（拒绝并 exit 1）；`:10-11`「the summary states how many were suppressed」↔ `Show-Summary`（`:470-487`）无此计数；`:18-20`/`:30-31`「Every deployment target … is backed up next to itself as `<name>.bak-<timestamp>`」↔ 无任何备份代码（`:467-468`）。而 `:22`「1 = anything failed」与 `Show-Summary` 的 `OK→0 / 其余→1` 本身不冲突——冲突在于被文档化的「默认即真部署」。
  具体后果：破坏性部署脚本的**唯一** in-file 安全模型谎报了默认动作与备份保证；HANDOFF:69/87 声称 Payback-on-Touch `[U]`-6（注释逐句对读）已在切片内履行 → 该声称不成立。
  `caused_by_last_fix`: **no**（继承自 `709649d`；本轮的退出码修复反而让「文档化契约 vs 实现契约」的分歧更显眼）。

## Non-Blocking Suggestions

1. `tests/TestHelpers.ps1` 有 6 个函数**无任何调用点**（`Get-ManagedDeploySet:268`、`Get-ExpectedPlugins:300`、`Get-FileSha256:87`、`Test-PathInsideDirectory:92`、`Get-RepoRoot:24`、`Get-InstallerPath:25`）——与 round 1 的 BL-3 同型。Proposed Fix: 删除，或把 `Get-ExpectedPlugins` 接进一条断言（`$PluginNames` 与 `claude/settings.json` 的 `enabledPlugins` 今日恰好 6/6 一致，可直接变绿），另把 `Get-ManagedDeploySet` 用于 AC2。
2. `install.Plan.Tests.ps1:55` 用例名自称「covers **exactly** the managed surface」，断言却只是 10 条 needle 的包含检查。Proposed Fix: 用 `Get-ManagedDeploySet` 做集合相等，或改名去掉 "exactly"。
3. `install.ps1:432` 的机器态包含判定用真实 `$env:USERPROFILE`，而 `Get-MachineLocalReport:244-276` 把清单映射到**生效根**——同一概念两套根。Proposed Fix: 抽一个根映射函数两处共用，或加注释说明「校验护真机、报告述本次」的有意差异。
4. `install.ps1:329` 的 `$script:checkFailed` 只写不读（死状态，`$ok` 才是返回值）。Proposed Fix: 删除该行。
5. wrapper 第 224 行输出了 `host=<进程路径>`，但四个测试文件都不断言它。Proposed Fix: 5.1 腿加 `$r.OutputText | Should -Match ([regex]::Escape($script:WinPs))`，让「宿主是谁」也变成机械判定。
6. `HANDOFF.md:109`「Human Approval Evidence：待人类批准切片 A 的计划」与 `:18`「Status: Approved（批准 commit bc3cb39）」自相矛盾。Proposed Fix: 同步 Quick-Version 字段。

## Test Coverage Gaps

* **K9④（父路径是文件）无任何用例**：`install.ps1:387-392` 的祖先回溯分支从未被执行。域内具体反例：把 `<T>\afile` 造成文件，跑 `-ClaudeDir <T>\afile\sub`。
* **AC3⑦ 只覆盖 ⑤ 形体**：`install.Validate.Tests.ps1:61-66`（case 7）只跑「目标在源树内」的 Deploy 形态；AC3⑦ 点名的 ④（尾分隔符冲突）与 ⑥（机器态）**去掉 `-ValidateOnly`** 的形态未跑。
* `-ValidateOnly` 的 `[SUMMARY]` 计数行**无任何断言**；test 1b 只核 `planned`（这正是 BL-1 逃逸处）。
* 无任何用例把 `$PluginNames` 与 `claude/settings.json` 对齐（能对齐的那个 helper 是死代码）。
* §E-1 的对照数字不可自洽：`TOTAL=15 FAILED=2 PASSED=1`（该文件恰 15 条用例，2+1≠15），且未贴任何原始尾部与退出码 → BL-1 所指谓词的「移除修复即变红」从产物无法核验（§E-2 的 7=1+6、§E-3 的 6=4+2 自洽，可采信）。

## Cannot Verify From Diff

* 9B round 1 的 `BL-4` 与 `## Test Coverage Gaps` 之后的小节（`HANDOFF.md:94/114` 自述未收到；`review_9*.md` 属我的盲审禁读面）→ 无法排除「仍有未表态的 round-1 blocking」。
* `IMPLEMENTATION_PLAN.md` 的批准范围（被机械排除）→ 无法判定 `INSTALLER_GUARD.md` 那 34 行是否在人类批准范围内。
* 「承载安装器的子进程」是否就是 `$script:WinPs` 那个二进制：`psver`/`host` 由 wrapper 自报；我只能核到构造上同一字面量与 §E-3 的解析差分，不能观察子进程路径。
* §E-2/§E-3 的变异实跑：仅有 Author 的摘要数字，无原始输出（数字自洽，方向可信）。
* [假设] `install.ps1:387-392` 的祖先回溯在 UNC 根上可能自环（`Split-Path -Parent '\\srv\share'` 可能返回自身）→ 潜在死循环；不在冻结的 K9 域内，未验证，不据此定级。

## Verification Needed

1. **证伪 BL-1**：隔离 HOME + 显式临时根 + 已播种目标树，先后跑 `-ValidateOnly` 与 `-DryRun`，打印两次 `[SUMMARY]` 行与 validate 输出的 `[PRESERVE]` 行数。**不写文件**（仅临时目录；禁止旧开关、禁止对真实 home 执行）。
2. **补 K9④**：`New-Item <T>\afile -ItemType File` 后跑 `-ValidateOnly -ClaudeDir <T>\afile\sub -CodexDir <T>\codex -DshDir <T>\dsh`，期望 exit 1 且含 `target-roots FAIL … is a file`。**不写文件**（临时目录内建样本除外）。
3. **补 ㉔ 的证据形态**：逐条贴出 4 个「跑安装器」的 5.1 用例的真实 `CHILD-ENV … psver=5 host=…` 行与各自退出码，并断言 `host=` == `powershell.exe` 路径。**不写文件**。
4. **复核 BL-1 谓词的判别力**：把 `Show-Summary` 临时改回 `if ($Result -eq 'FAILED') { return 1 }` + `return 0`，只跑 `install.Parameters.Tests.ps1`，贴完整 Pester 尾部 + `exit code`。**会写文件**（临时改 `install.ps1` 再还原；按 §F 纪律，写盘/跑 Pester/还原必须分处不同命令）。
5. **复核 BL-2/BL-3 的文档声称**：`Select-String -Path install.ps1,docs/ai/INSTALLER_GUARD.md -Pattern 'real deploy|bak-<|suppressed|plugin step is exercised'`，与 `install.ps1:467`、`:545-555` 对读。**不写文件**。

## Debt Verdict

**Unpaid**。`~/.dsh` 首次真部署债自报 Unpaid（诚实）；但 `INSTALLER_GUARD.md` 的 guard 债在 requirement 5 前置未满足时被记为 **Repaid**（BL-2），而 6 个无调用点 helper 与「插件表与 `settings.json` 无机械对齐」两条属**未登记的隐性负债**（违反 No-Hidden-Debt）。§E 的手工变异对照**不等于**母本要求的常驻守护有效性装置——`HANDOFF.md:82` 那条 `[DEBT]` 必须继续在册，不得用 §E 顶替。

## Recommended Next Step

本轮**不通过**，不要在此 tip 上直接开 round 3 的 9A/收敛；先由 Author 出一次性修复轮：(a) 让 validate 模式的计数器与 `[SUMMARY]` 语义自洽（要么该模式不打印 delete/preserve，要么从同一 `$delta` 算出并同步打印 `[DELETE]`/`[PRESERVE]`，要么把注释与声称收窄），并补上 validate 侧的计数断言；(b) 让 `install.ps1` 头部与 `INSTALLER_GUARD.md` 与 ㉗ 一致——要么撤回「Repaid」并按现状重开一条带 trigger 的 `[DEBT]`（guard 开关已移除，替换控制待 B/C），要么把两处文字改准；(c) 补 K9④ 用例与 ㉔ 要求的逐用例 5.1 宿主证据。之后以新的 `review_tip_sha` + `handoff_snapshot_sha` 重发 9B（干净工作树），再跑 9A。

## Requirement-Level Concerns

1. **同一份冻结文件里 K1 有两个验收文本**：`TASK_BRIEF.md:74`（K1 闭集条目）仍写「本切片不执行，仅要求它不因绑定而失败」，㉗ 则要求 exit≠0 + `RESULT=REFUSED` + 零写入。只读 K1 条目的 Reviewer 会接受一个 exit 0 的实现——请就地修订 K1 条目，别靠「㉗ 覆盖」隐式生效。
2. **㉔ 的证据契约未被交付物满足**：㉔ 定义「证据 = `last_test_run.txt` 内每条 5.1 腿的实际宿主路径与退出码」，而 §A 只给聚合 37/37、§D 只给用例描述，无逐用例宿主路径与退出码。冻结措辞与交付证据形态不一致（见 VN-3）。
3. **AC2 的「计划与切片 B 执行集合一致」目前无机械载体**：只由 10 条 needle 的包含断言支撑，而为之准备的独立预言机（`Get-ManagedDeploySet`，docstring 自述 N3 要求）没有调用点。
4. **TASK_BRIEF Non-Goals（`:57`）把 `INSTALLER_GUARD` 划给切片 D，本 diff 却改了它**：冻结边界与 diff 二者必有一错；且该文件同时是 guard 债的偿还证书，需要人类裁决按哪一份为准。
5. **§E 的三条对照是手工一次性变异**（`last_test_run.txt:58` 自述「写文件、跑 Pester、还原分处不同命令」），不是常驻装置；本轮三条新谓词由此获得部分判别力，但**不得**据此声称满足母本的「回归用例有效」结构化产物要求。

---

## round 1 — review_tip_sha `709649dbc56f5a699d54c989e9c33e7903217a1d`（正文不完整）

* 已收到并处置的条目：**BL-1**（`REFUSED` 退出码恒 0）、**BL-2**（`toDelete`/`preserve` 为死常量、`planned` 只在 `Show-Plan` 内赋值）、**BL-3**（5.1 腿为从未调用的死代码）。三条均在 `7259ee1` 修复，各带冻结前负向对照（`last_test_run.txt` §E-1/§E-2/§E-3）。
* **正文丢失**：该 Reviewer 的返回正文在 Author 侧被截断，`BL-4` 与 `## Test Coverage Gaps` 之后的小节从未到达；`list_agents` 显示该子 agent 已不可续（无法取回）。
* **处置**：round 1 记为「正文不完整」，其未取回条目**不得假定为无害**；因 round 2 已在**新 tip** 上由两名独立 Reviewer（9B 盲审 + 9A 常规审）完整重审，**以 round 2 为准**；round 1 仅保留上述三条的溯源价值。

## Author 表态（round 2）

**人类裁决（2026-09-15，两条均按 Reviewer 建议）**：① `docs/ai/INSTALLER_GUARD.md` **还原到 `e9917a1` 版本**（切片 A 不再改文档），guard 债「已偿还」的事实改记进 `HANDOFF.md` 债册并带 trigger；② `TASK_BRIEF.md` **三处改准**（K1 条目与 ㉗ 一致、A3 补进 AC2、`-DryRun` 的 `RESULT=OK` 语义写清为「已打印计划」而非「计划可行」）。

| 条目 | 表态 | 处置 |
|---|---|---|
| BL-1 validate 侧 `delete/preserve` 结构性 0 | **confirmed**，`caused_by_last_fix: yes` → Fix-Loop **streak = 1** | 计数移出 `Show-Plan` → 新增 `Get-PlanCounters`（三模式同源）；validate 侧补计数断言 |
| BL-2 `INSTALLER_GUARD.md` 证书与实现相反 | **confirmed** | 按人类裁决还原到 `e9917a1`；偿还事实移入 HANDOFF 债册 |
| BL-3 `install.ps1` 头注释 | **confirmed** | 重写 1–40 行安全模型为切片 A 实况（默认 = 校验 + 打印计划 + 拒绝；备份/插件步显式标为切片 B） |
| NB-1 / NB-4 / NB-6 死代码与死状态 | accepted | 删 6 个无调用点 helper（保留并入用例的两支）、删 `$script:checkFailed`、同步 HANDOFF Quick-Version |
| NB-2 / NB-3 A3 名不副实 + `dsh/skills/*` 硬编码 | accepted | AC2 改为对**目标**路径集合做集合相等（用 `Get-ManagedDeploySet`）；`dsh/skills/*` 恢复动态枚举 |
| NB-5 `host=` 未被断言 | accepted | 5.1 腿补 `host=` == `$script:WinPs` 断言 |
| §E-1「TOTAL=15 FAILED=2 PASSED=1 不自洽」 | **partly dispute** | 差额是 Pester 的过滤计数（我方原始输出同一行含 `NotRun: 12`，见 probe A 记录）；**接受**「应贴完整尾部与退出码」→ 重跑时贴全 |
| 覆盖缺口（K9④ / AC3⑦④⑥ / validate 计数 / 插件清单对齐 / ㉔ 逐用例宿主证据） | accepted | 本轮全部补测：插件清单接入 `Get-ExpectedPlugins`（并与 `claude/settings.json` 交叉核对） |
| 需求层 K1 双文本 / A3 / DryRun 语义 | **human ruling** | 已获授权改准（见上） |
| 需求层「§E 不等于常驻守护装置」 | accepted | 对应 `[DEBT]` 继续在册，不用 §E 顶替 |

## round 3 — review_tip_sha `976d2e17be364a95df94498c794b82e1b31ca02e` / handoff_snapshot_sha `b530d9bdaa4a0c5d2b9e354375496ed9dfb4d595`

**判定：不通过（Blocking 1 条，`caused_by_last_fix: yes`，若按 HANDOFF 自身计数规则 → streak 1→2 = 硬停阈值，须人类裁决）**

**证据头**

| 项 | 值 |
|---|---|
| `observed_head_sha` | `b530d9bdaa4a0c5d2b9e354375496ed9dfb4d595` ✅ == 要求值 |
| `worktree_clean` | `yes`（`git status --porcelain` 空；`--ignored` 无 verdict 残留） |
| `read_handoff_from` | **工作树**（`docs/ai/HANDOFF.md`、`TASK_BRIEF.md`、`last_test_run.txt` 均按工作树读；未用 `git show <tip>:…`） |
| `model_route` | 会话内**无** `DSH_*` 路由变量可自证 → `not self-observable`；派发契约为 `deepseek-official/deepseek-flash@high`（未验证，供 Author 逐字比对） |
| `writes_performed` | `none`（仓/工作树零写入、无 commit）。**须披露一处过程偏差**：为读 diff 曾用 shell 重定向把 `git diff` 落到 `%TEMP%\h3a_install.diff`（仓外 scratch，非仓内产物）；此后所有检查均为只读命令。 |

审查输入：正文 diff（`e9917a1..976d2e1`，排除 review_9*/archive/IMPLEMENTATION_PLAN）+ 工作树文档。未打开 `IMPLEMENTATION_PLAN.md`、`review_9*`、`archive/**`；未执行 `install.ps1`（任何形态）、未跑测试/构建、未出现被禁开关字面。

### Review Verdict

**不通过（round 3）** —— Blocking 1 条（`caused_by_last_fix: yes`，若按 HANDOFF 自身计数规则 → streak 1→2 = 硬停阈值，须人类裁决）。

本轮四项特别核查结论：
* **① 计数同源**：成立。`Get-PlanCounters`（:283，主流程 :549 模式分支之前算一次）与 `Show-Plan` 共用 `Get-MirrorDelta`；`script:Summary` 全文件仅 :550–552 赋值、:506 读取，`Show-Plan` 内**无残留累加**。validate 的 `[SUMMARY]` 与它自己的 `[PRESERVE]` 行之间**没有新的**语义不一致——仅 tag 一词两义（白名单 vs machine-local），由 `(machine-local, never touched)` 后缀可判，且测试正是靠该后缀相减（`install.Plan.Tests.ps1:69`），与 TASK_BRIEF:102 的收窄措辞一致。
* **② 断言区分力**：计数相等（case 8）、A3 集合相等、插件清单交叉核对、5.1 `host=`、deploy 形态 `[CHECK] … FAIL`、K9④ **均按构造可判且非恒真**（细节见下）。唯一盲区 = A3 的 `dsh/skills/*` 臂（NB-1）。
* **③ 头注释**：备份/插件步已明确标注 `SLICE B ONLY` / slice B，被移除开关归属写对（:40–41）；仍余 :1 与 :5–6 的现在时表述、:8 指向本分支**故意过期**的 README 部署节（NB-3）。
* **④ TASK_BRIEF 三处改准**：K1↔㉗ 一致（含 `RESULT=REFUSED` 与零写入）、A3 已进 AC2、`RESULT=OK`/validate 计数收窄与实现相符；未发现新的自相矛盾（仅 :91 的逐字样本 `<T>\claude` 与测试实际用的 `<T>\home\.claude` 有字面差，NB-3 末条）。

### Blocking Issues

* **[Product Blocking]** 镜像目标的子路径存在为**文件**时：`install.ps1:215` 只做 `Test-Path` 就枚举，`Get-ChildItem -LiteralPath <file> -File -Recurse` 实测返回该文件本身（count=1、`FullName.Length == Target.Length`），随即 `Substring(len+1)` **抛 MethodInvocationException**（实测：`startIndex cannot be larger than length of string`），全脚本无 try/catch。
* 后果：`Get-PlanCounters`（:549，本轮修复新增的**无条件**前置遍历）先于模式分支执行 → `-ValidateOnly` 在 `Test-Plan` 之前崩溃，:390 那条本该点名的 `[CHECK] target:… FAIL` **永不可达**；屏幕上是原始异常，既**不点名具体路径**也**没有 `[SUMMARY]`/`RESULT=`**，仅退出码 1。AC3 的冻结性质"目标不可用 → 退出码 ≠ 0 并**点名具体路径或参数**"对该输入不成立；AC2 的 `[SUMMARY]` 行要求同样丢失。无写入风险（本切片无写路径）。
* 域内具体反例（按 TASK_BRIEF:84 的要求给出）：`-ClaudeDir <T>\claude` 且 `<T>\claude\rules` 是文件（同型：`<DshDir>\workflow`、`<DshDir>\skills\independent-review`）；AC2 的判定本身就预置目标树，种一个文件即命中。
* `caused_by_last_fix`: **yes** —— 修复前（`7259ee1`）validate 支路先调 `Test-Plan`（该版本 :526–535），同一输入会被 `[CHECK] target:… FAIL` 干净拒绝；新增的无条件 `Get-PlanCounters` 把崩溃提前，是**修复引入的回归**。
* `Proposed Fix`：`Get-MirrorDelta`（:215/:221）与 `New-MirrorAction`（:159/:162）在枚举前加 `.PSIsContainer` 判定（非容器 → 空 delta，交给 `Test-Plan` 报 shape FAIL）；补一条回归用例：把 `<ClaudeDir>\rules` 种成文件，断言退出 ≠0 + 输出含 `[CHECK] target:<该路径> FAIL` + `[SUMMARY] RESULT=FAILED`。

### Non-Blocking Suggestions

* **NB-1（A3 的 skills 臂无区分力 / 且是未登记残余）**：`install.ps1:191` 与 `tests/TestHelpers.ps1:285` 是**同一字面** `'dual-agent-workflow', 'independent-review'` —— 预言机把被测代码的常量抄了一份，新增第 3 个 `dsh/skills/<bundle>` 时两侧同时缺失 → 集合相等断言**恒绿**（该仓库"谓词无区分力"的第 5 次同型）。今日仓内恰为 2 个目录（实测），故无当前行为偏差，不判 Blocking。`last_test_run.txt §F⑤` 自认"仍未办"，但 HANDOFF 9 条 `[DEBT]` 中 **0 条**提及 skills（实测）→ 违反 No-Hidden-Debt。`Proposed Fix`：预言机改 `Get-ChildItem dsh/skills -Directory`（并给 `Build-Plan` 同改），或**登记 `[DEBT]` + 触发器**"下次新增 skill bundle 之前"。
* **NB-2（HANDOFF 账目自相矛盾，须在 final-review 前修）**：① `Review & Test Binding` 写 `review_tip_sha`/`tested_sha = 91b283e8…`，而 `last_test_run.txt` 绑 `tested_sha = 976d2e1…`、本轮实际审查 tip 也是 `976d2e1`；② `Fix-Loop Counter` 行写 `streak: 0`，同文件 :9/:62 写 `= 1`；③ `Quality Gates` 行引 `37/37` 与 installer `A0D3F677…`，与冻结的 `43/43`、`029C44BA…` 不同代。`Proposed Fix`：一次性刷新这三处（本 Reviewer 不动文件）。
* **NB-3（残余文档/注释与实现不一致）**：:1 `Deploys … to this machine` 与 :5–6 把"无参数运行"当作使用方式，但该运行 `REFUSED`；:8 `see README.md -> deployment section` 指向**本分支故意过期**的 README:17（称 guard 锁定、`-DryRun` 未实现、并教人加已移除开关）；`$PSNativeCommandUseErrorActionPreference` 注释以"the plugin step"（本 build 不存在）为理由；TASK_BRIEF:91 逐字样本 `<T>\claude` 与测试实参 `<T>\home\.claude` 字面不符。`Proposed Fix`：改标题为"计划/校验器（本切片无写路径）"、删除或加"(stale until slice D)"限定该指针、注释改为将来时、样本补 `.`。
* **NB-4（死代码/名不副实）**：`$script:checkFailed`（:354）只写不读；`$script:Plan`（:111）无引用；`plugin-cli` 两个分支都 `Report $true`（:600–609）——恒绿却计入 `[CHECK] … OK` 行，易被读成谓词（建议注明 informational）；文件**结尾无换行**（末字节 `27 29`，仓约定 LF 文本）。`Proposed Fix`：删除死变量，或把 `plugin-cli` 标为信息项并补行尾 LF。

### Test Coverage Gaps

1. **`(dir)` 形态的 `[PRESERVE]` 行无断言**：㉙ 要求 `workflow/archive`（**目录、末段形态**）须 `[PRESERVE]`，但 `install.Plan.Tests.ps1:48` 只断言三个**文件**样本；反向过滤 `\\archive(\\|$)`（:52）对 `…\workflow\archive (dir)` 这种行**看不见** → 归档目录被误判为可删也无法变红（目录内文件仍被断言）。
2. **`seed src -> tgt` 行形态从未被断言**：全部 Plan 用例都带 `-SeedConfigToml`，只走到 `keep … (seed-only, already present)`；缺 config.toml 的分支只有代码里覆盖。
3. **case 8 标题过度声称**：`…and they are not structural zeros` 只钉了 `delete > 0`，未钉 validate 侧 `preserve > 0`（由另一文件间接覆盖），也未钉 `planned` 与动作数（11）的关系。
4. **缺"镜像子目标为文件"的用例** —— 正是 BL-1 的崩溃路径（K9③ 只覆盖参数本身是文件）。
5. **未被任何用例触达的现有面**：`Test-PathInsideDirectory`（`TestHelpers.ps1:86`）无调用点；5.1 腿未跑 `-NoPluginInstall`/K8 与 K9④。

### Cannot Verify From Diff

* `43/43 exit 0` 与 probe D 的变异输出（Author 自跑；`guard_effectiveness: N/A`，母本要求的结构化装置产物仍缺，HANDOFF 已自记 `[DEBT]`）。
* A3"首跑即报 planned=10 vs managed=11、点名 `codex/config.toml`"是历史红→绿叙述，当前树无法复现（只能从代码判定其可判性）。
* BL-1 的**端到端**结论（`-File` 下是否吐出 `RESULT=` 行、5.1 侧退出码）：我实测了 `Get-ChildItem` 语义与 `Substring` 抛出，未执行安装器，故"崩溃即中止且无 `[SUMMARY]`"为推断。
* round 1/2 的 verdict 原文（盲审隔离，`review_9*` 未读），故 HANDOFF 转述的 `caused_by_last_fix` 判词无法交叉核对。

### Verification Needed

1. 证伪 BL-1（写文件：仅 `%TEMP%`）：建 `%TEMP%\bl1\claude\rules` **文件** 与三个临时根，跑 `pwsh -NoProfile -File .\install.ps1 -ValidateOnly -ClaudeDir %TEMP%\bl1\claude -CodexDir %TEMP%\bl1\codex -DshDir %TEMP%\bl1\dsh` → 预期：裸异常、无 `[CHECK] target:… FAIL`、无 `[SUMMARY]`；修复后预期：exit 1 + 点名该路径 + `RESULT=FAILED`。
2. 同输入跑 `-DryRun` 与无开关 deploy 形态（写文件：仅 `%TEMP%`）：预期 dry run 丢 `[SUMMARY]`，deploy 丢 `RESULT=REFUSED`；三目标根哈希含目录行不变。
3. 证伪 NB-1（**不写文件**）：`Select-String -Path install.ps1,tests/TestHelpers.ps1 -Pattern "'dual-agent-workflow', 'independent-review'"` → 预期两处同字面（我已实测）；红对照（写文件：临时假仓）→ 在假仓加 `dsh\skills\zzz-probe\SKILL.md` 后跑 A3 断言，预期仍绿 = 盲区被证实。
4. 证伪 NB-2（**不写文件**）：`Select-String -Path docs/ai/HANDOFF.md -Pattern 'review_tip_sha|tested_sha|streak|43/43|37/37'` 与 `last_test_run.txt` 的 `tested_sha` 对读 → 预期两文件 SHA/计数不同代（我已实测）。
5. 证伪"无未登记债"（**不写文件**）：`(Select-String -Path docs/ai/HANDOFF.md -Pattern '^\[DEBT\]').Count` = 9 且 skills 命中 0 → 残余未登记（我已实测）。

### Debt Verdict

**Noted**。本切片按 Payback-on-Touch 履行了 `[U]` 第 6 项（`install.ps1` 注释逐句对读）——我逐句对读后仍点名 2 处不一致（NB-3），故该笔只算**部分**偿还。9 条 `[DEBT]` 其余与本切片 trigger 不匹配，维持原状；`~/.dsh` 首次真部署债仍 **Unpaid**（切片边界外，`last_test_run §F` 亦自认不得声称 converged）。**新增一笔应登记**：A3 skills 臂的硬编码/预言机盲区（NB-1）。

### Recommended Next Step

1. 先请人类裁决 BL-1 的 `caused_by_last_fix: yes` 归属：若采信 → streak 1→2 触硬停，**停止自动修复轮**，由人类在"修 / 裁范围 / 重规划"中择一；若不采信（视作既有缺陷的延续）→ 允许一次性修复轮。
2. 修复轮最小集：BL-1 的 `.PSIsContainer` 守卫 + 回归用例；NB-1 修预言机或登记 `[DEBT]`；NB-2 刷新 HANDOFF 三处账目；NB-3 改标题与过期指针；然后复跑冻结命令并落新证据，再开 round 4。
3. 本轮**不得**据此判 converged；`/final-review` 前必须先关 BL-1 与 NB-2。

### Requirement-Level Concerns

1. **AC3 的"目标不可用"边界未定义**：它是否包含"镜像目标**子路径**存在为文件"？实现里恰有该判定（:390）却被前置遍历击穿——请人类要么把该输入明写进 K9，要么把 AC3 措辞收窄到根级。
2. **A3 的独立预言机要求只被部分满足**：N3"不向被测代码问期望"在 skills 臂被常量转录绕过；若 A3 的意图是"防未来漂移"（本任务起因正是脚本内自维护清单陈旧），则此条须按 NB-1 收紧到措辞里。
3. **`-DryRun` 的 `RESULT=OK` 语义仍是产品级风险点**：同一命令行若根自冲突或落机器态面，validate/deploy 会拒，dry run 仍报 OK（仅靠 TASK_BRIEF:101 的收窄措辞兜底，屏幕无任何提示）。是否在 dry run 也打印一次前置判定（信息性、不影响退出码），请人类定。
4. **`planned=11` 的语义未在任何验收/头注释中定义**（计的是计划**动作**数、不含插件），下游若把它读成"将复制的文件数"会误判规模。

## round 4 — review_tip_sha `c4224fa3c1a20094b0650790ba94897557c2985b` / handoff_snapshot_sha `9e081bf3b0e5be0864099709bc7a11024b9e5da4`

**判定：有条件通过（Blocking = None；Verification Needed 非空）**

**证据头**
- `observed_head_sha`: `9e081bf3b0e5be0864099709bc7a11024b9e5da4`（== prompt 检查值；审前自检通过）
- `worktree_clean`: `yes`（全树为空；`--ignored` 无 `review_9*` / verdict / raw-log 残留）
- `read_handoff_from`: **工作树**（HEAD 工作树；`9e081bf` 的 docs-only 改动亦取自工作树，未用 `git show <tip>:…`）
- `model_route`: `deepseek-official/deepseek-flash@high`（自报值）
- `writes_performed`: **none**（仅只读 git / `Get-ChildItem` / `Get-FileHash` / `Select-String` / 纯表达式探针，未跑安装器、测试、构建）
- 盲审隔离：未打开 `IMPLEMENTATION_PLAN.md`、`review_9*`、`archive/**`；diff 全程带排除项。生产面 ~1574 行（< 4000 预算），未触碰 README/根 AGENTS/`tools/**`/`dsh/**`/`claude/**`/`codex/**`（Non-Goals ✓）。

### Review Verdict

**有条件通过**（Blocking = None；Verification Needed 非空）。本轮 9B 未发现 `[Product Blocking]`。
关键正面证据（自行判定，不采信自述）：① 源码树形状独立重算得 `planned=11 / delete=1 / preserve=5`，与 `last_test_run` §E 逐字相同（11 = 2 copy + 3 mirror + 1 codex AGENTS + 1 seed + 1 dsh AGENTS + 1 workflow mirror + 2 skill mirror）；`claude/rules/common` 存在于源树（故目标侧 `common` 不计删除）、`claude/workflow/archive` 与 `dsh/workflow/archive` 均**不**存在（故 `archive` 确为 live-only → 目录形态 `[PRESERVE]…(dir)` 断言可判）。② `HEAD` 的 `install.ps1` sha256 = `AAC42698…B7DF96`，与证据绑定值一致；`git diff c4224fa..HEAD -- install.ps1 tests/` 为空 → **被审代码与实跑代码同一状态**（`9e081bf` 仅改 `last_test_run.txt`）。③ 586 行、`NON_ASCII=0`、无 CRLF——头注释 L2-3 的自述属实。④ `INSTALLER_GUARD.md` 在 `e9917a1..c4224fa` 净零，与"已还原到 base"的声称不矛盾。

### Blocking Issues

None.

### Non-Blocking Suggestions

1. **HANDOFF 的 SHA 绑定与账目自相矛盾（本轮最值得处置的一项，非产品面）**：`HANDOFF:28` 写 `review_tip_sha: 2bb5a26…`（并称"9A 与 9B round 4 必须同一个"），而本轮派发的 `review_tip_sha = c4224fa…`；`HANDOFF:30/103` 写 `tested_sha: 2bb5a26`，`last_test_run:4` 写 `tested_sha: c4224fa` —— 同一棵树里两个 `tested_sha`。另：`:9` 仍写"round 3 待开 / streak = 1 / tip 976d2e1 / 43 用例"（与 `:68` 的 streak = 2 冲突）、`Next Step:119-125` 与 `Quick-Version:117` 仍是 round 2 文本、`:10-11` 整段重复。**后果**：账目/SHA 绑定层是历史 Blocking 集中区，人类/9A 若以 HANDOFF 为准则会锚到另一棵树。**Proposed Fix**：一次 docs commit 对齐 `review_tip_sha` / `tested_sha` / Current Phase / Next Step，删重复段。
2. **同型崩溃入口只修了一半（`caused_by_last_fix: no`）**：`Get-MirrorDelta:217` 的容器守卫只覆盖 **target** 侧；`New-MirrorAction:158-164`（**source** 侧）仍是 `Substring($Source.Length + 1)`。实测该 cmdlet 语义：`Get-ChildItem -LiteralPath <file> -File -Recurse` 返回该文件本身（`count=1`、`FullName.Length == Source.Length`），随后 `Substring(L+1)` **抛 `MethodInvocationException`**（与 round 3 BL-1 同型、同一条相对路径计算）。且 `Test-Plan:369` 对"文件" source 会数出 `1 files` 并报 **OK**，即守卫若只加到 source 侧就会把"崩溃"换成**静默通过**。今天**不可达**（source 恒为仓内常量，不在冻结闭集 K1–K9 内，故按 brief 的"必须给域内反例"规则不计 Blocking）。**Proposed Fix**：`New-MirrorAction` 加同一容器守卫 + `Test-Plan` 的 mirror 分支改判 `PSIsContainer` 并点名 `mirrored source is not a directory`。
3. **`-DryRun` 的 `RESULT=OK` 语义收窄只活在 `TASK_BRIEF`，未落到用户可见面**：brief 冻结"OK 只表示计划已完整打印且零写入"，但 `install.ps1` 头注释 L15 仍只写"prints the exact plan and changes nothing"；DryRun 不调用 `Test-Plan`，故目标为文件/根不可用/目标落源树时照样 `RESULT=OK` 且 exit 0。建议在 L15 后加一句"OK does not mean the plan passed the pre-flight checks"。
4. **`-ClaudeDir ''`（空串）静默回落到真实 `~/.claude`**：`Resolve-TargetDirectory:145` 用 `if ($Explicit)`，空串为假 → 用 `$env:USERPROFILE\.claude`。切片 A 无写入故无害，但这是切片 B 的部署地雷。**Proposed Fix**：用 `$PSBoundParameters.ContainsKey('ClaudeDir')` 区分"未传/传空"，空串直接点名 FAIL。域外（K9 未列空串取值）→ Non-Blocking。
5. **头注释两处措辞不严**：① L11-12 "a no-argument run exits non-zero with `RESULT=REFUSED`" 未涵盖校验失败分支（真仓源缺失时给 `RESULT=FAILED`）；② L25-26 "1 = FAILED… or REFUSED" 未含绑定期失败与 `repo not found`。另 L17-20 用现在时描述 mirror-replace 语义（本版从不 mirror-replace），建议句首也标 slice B。
6. **账目分散 + 死代码未进 `[DEBT]` 块**：`install.ps1:112 $script:Plan`、`:357 $script:checkFailed`、`:547 $Roots`、`:528-532` 首个 `$RootSpecs` 赋值均无读者；`tests/TestHelpers.ps1:86 Test-PathInsideDirectory` 无调用点、`Invoke-InstallerCase -Environment` 无调用者。它们只出现在 `last_test_run` §F③ 的散文里，未进 HANDOFF 的 `[DEBT]` 册（该册只数 `^[DEBT]`）。**Proposed Fix**：清掉，或记一条带 trigger 的账。
7. **测试侧路径提取器对环境敏感（会红不会假绿）**：Plan 的两个提取器用 `[A-Za-z]:\\[^ ]+`，若 `$env:TEMP`/用户名含空格则提取被截断、过滤到 `planned=0` 从而整条 A3 失败；本机无空格故当前无碍。

### Test Coverage Gaps

1. **㉓/K9⑤ 点名的第二个域内样本缺席**：brief 要求 AC3 ⑥/K9⑤ 同时增加 `.claude\projects-x` **与** `.claude\projects.bak-20260101-000000`；套件只有前者（case 6b）。建议把 case 6b 参数化跑两个样本（`.bak-` 后缀同时踩 `*.bak-*` 命名面）。
2. **`planned=` 无行级交叉核对**：只有 `>0` 与跨模式相等，而 `delete/preserve` 都有"计数 == 屏上行数"的核对；`planned` 的语义（含 seed-keep、不含 plugin、不含两条 `[PLAN]` 元数据行）无任何机械钉住。
3. **DryRun 语义只被冻结在文字里**：无用例断言"目标为文件时 `-DryRun` 仍 exit 0 且 `RESULT=OK`"或"DryRun 不打印 `[CHECK]`"。
4. **source 侧形状无用例**：`New-MirrorAction` / `Test-Plan:369` 的"source 是文件"分支（见 NB-2）。
5. **K9⑤/K9 边角**：根冲突只测了"尾分隔符变体"；`-ClaudeDir ''` / `$null` 无取值用例。
6. **AC1② 对 K4b 未断言参数名**：`K4b` 只断言绑定诊断族，未断言输出含 `IUnderstandThisReplacesLiveConfig`。

### Cannot Verify From Diff

1. **44/44、exit 0 本身**：`last_test_run` 为 Author 产物；本轮禁跑，无法复核（见 VN-1）。
2. **"A3 集合相等断言首跑即红"** 无任何 red→green 产物；与 `guard_effectiveness: N/A` 一致，`[DEBT]` 已登记——**不得**据此声称"回归用例有效"。
3. **§E 的 5.1 逐用例 `CHILD-ENV`/退出码**：粘贴文本，无法从 diff 复核；其 `planned=11 delete=1 preserve=5` 按源码树形状独立重算得同一组值（佐证，不替代实跑）。
4. **round 3 两侧 verdict 的逐字内容**（本轮禁读 `review_9*`）→ HANDOFF 的转述**仅为自述**。
5. **A3 的"独立预言机"强度**：`Get-ManagedDeploySet` 与 `Build-Plan` 在 `dsh/skills` 臂共享同一硬编码常量对（已登记 `[DEBT]`）。

### Verification Needed

1. 冻结套件复跑 → 期望 `Tests Passed: 44, Failed: 0`、exit 0。**会写文件**：是（仅 `$env:TEMP`）。
2. 缺失样本证伪：把 case 6b 的 `projects-x` 换成 `.claude\projects.bak-20260101-000000` 跑一次 → 期望 exit 0。**会写文件**：是。
3. source 侧同型崩溃证伪（NB-2）：临时假仓内把 `claude\rules` 换成文件后跑 `-ValidateOnly` → 预测**裸异常、无 `[SUMMARY]`、无 `RESULT=`**。**会写文件**：是；**前置**：先读被执行的这一版 `install.ps1`、临时 HOME + 显式临时三目标，禁用 base 版脚本与任何旧确认开关字面。
4. DryRun 语义证伪（Gap-3）：`-DryRun -ClaudeDir <temp>\shared`（`shared` 为文件）+ 另两目标 → 预测 exit 0 + `RESULT=OK`。**会写文件**：是。
5. 账目一致（NB-1，只读）：`Select-String -Path docs\ai\HANDOFF.md,docs\ai\last_test_run.txt -Pattern 'tested_sha|review_tip_sha'` → 期望两文件同值。

### Debt Verdict

**Noted**（账目存在、多数带 trigger，不构成暗债）。`dsh/skills` 预言机无区分力一笔如实登记且今日无偏差；`~/.dsh` 首次真部署一笔仍 **Unpaid**，故本切片**不得声称 converged**；round 3 的 dead-code / `planned` 语义 / AC1②-对-K7-不可满足等遗留只落在 `last_test_run` §F③ 散文、未进 HANDOFF `[DEBT]` 块 → 记一处**账目分散**（见 NB-6）。

### Recommended Next Step

1. **不要为本轮开常规修复轮**：无 `[Product Blocking]`，且 streak = 2 已触硬停、人类只批了一次性窄修复例外。
2. 在同一 `review_tip_sha`（`c4224fa…`）上跑 **9A**；任何对 `install.ps1`/`tests/**` 的改动都会作废本轮两份绑定。
3. 人类裁决：① `HANDOFF` 账目/SHA 对齐（纯 docs，可在 9A 之后同批落账）；② case 6b 补第二样本 + NB-2 守卫是否并入切片 B（并账目化）。
4. 收敛门之前不得声称 converged。

### Requirement-Level Concerns

1. **`-DryRun` 把"计划已打印"与"计划可用"解耦**：CLI 用户极易把 `RESULT=OK` 读成"这计划能过校验"；建议把该收窄写进 header（NB-3）。
2. **A3 的"独立预言机"声称强于实际**：skills 臂两侧同源硬编码 → 建议把 A3 的**声称边界**写窄。
3. **执行前置约束 ② 与 K1b/K4/K5/K6 样本形态冲突**：② 要求"每次子进程调用都显式传三个路径参数"，但 ㉗ 的 K1 = 无参数、K4/K5 只传出错 token；套件靠**子进程内**重定向 `USERPROFILE` + 互锁满足实质。建议把 ② 改写成实质判据（"解析后的三目标必须落在临时 HOME 内"）或注明例外。
4. **AC1② 有已知不可满足分支**（K7 的绑定诊断不含参数名）：AC 与用例的对应关系仍靠人工记录。
5. **守护有效性仍只有测试侧负向对照**：本轮所有"回归用例能挡住"的说法均无结构化红→绿产物支撑；不阻止本轮收敛（无 AC 依赖它）。

## round 5 — review_tip_sha `09df8d7738ba05c3d8bd4477da0ab8a001a11183` / handoff_snapshot_sha `9d51a7559a41357d7532390f24804c5dc6607a6b`

**判定：通过（Blocking = None，Verification Needed 为空）**

```
observed_head_sha: 9d51a7559a41357d7532390f24804c5dc6607a6b（== handoff_snapshot_sha；快照自检通过）
worktree_clean:    yes（全树为空；--ignored 无 review_9*/verdict 残留）
read_handoff_from: 工作树（9d51a75 为 docs-only commit）
model_route:       (本 Reviewer 侧自查不可得)；派发方参数应为 deepseek-official/deepseek-flash@high，请 Author 逐字比对
writes_performed:  none
盲审隔离:          未打开 IMPLEMENTATION_PLAN.md / review_9* / archive/**
只读额外动作:      一次仓外 Get-ChildItem -Recurse 顺序探针（%TEMP%\ordprobe-*，已删除并实测 CLEANED=True；未写仓库、未运行安装器、未落盘 diff）
```

四项特别核查中 ①②④ 有实质发现，但均落在"保证弱于声称/覆盖未钉死"层，无当前可实现的反例，故不构成 `[Product Blocking]`。

### Non-Blocking Suggestions

* **NB-1（枚举顺序成为隐藏正确性前提）** `install.ps1:224-241` 的第二遍继承依赖 `Get-ChildItem -Directory -Recurse` **父先于子**；实测该顺序在本机成立（探针：`workflow, workflow\archive, workflow\tools, workflow\zz, workflow\tools\sub`，两次重复一致，PARENT_BEFORE_CHILD=True），但它既未被注释声明为正确性前提，也无断言之钉。**Fix**：`:224` 上方加一句前提说明，并把"目录行不得互为父子矛盾"做成断言（见 TCG-1）。
* **NB-2（`-contains` 大小写敏感，与同函数其余比较不一致）** `install.ps1:220`/`:226` 用 `-contains`（大小写敏感），而 `:234`/`:238`/`:253` 用 `OrdinalIgnoreCase`。若解析出的目标路径大小写与源不符，托管目录会被误列入 `[DELETE]`。**Fix**：归一后比较。
* **NB-3（新样本断言可判，但只覆盖一层）** `install.Plan.Tests.ps1` 的新用例**不恒真**：`Get-TaggedLines` 取 `[DELETE]` 起首行、`-like '*<绝对路径>*'` 按构造可判；缺口在**深度**而非拼写。
* **NB-4（证据措辞继承了歧义）** `last_test_run.txt:35` 的"没有任何 `[DELETE]` 行指向该目录路径"容易被读成"内容也判对了"。**Fix**：把该样本的**声称**收窄为"目录级行不冲突，嵌套深度见覆盖缺口"。

### Test Coverage Gaps

* **TCG-1（核心）** 无任何用例断言"**没有 `[DELETE] … (dir)` 行是某条 `[PRESERVE] … (dir)` 行的祖先**"这一结构不变量；现有断言只做"该特定目录路径下无 DELETE"，故若继承通道对**多层**失效，套件仍全绿。
* **TCG-2** 未覆盖"**同一被镜像目录内**既有 `archive` 分支、又有非保留分支"的样本（`workflow/archive/old/e.md` + `workflow/tools/sub/x.md`）。按父先于子的枚举推出当前实现下**不可达**，但该推理未落成断言。
* **TCG-3** 未覆盖"保留目录位于**嵌套非保留目录**之下"（`workflow/tools/old.bak-x/` 形态）；新样本是顶层。
* **TCG-4** 未覆盖源树**自带**同名 `archive`/`*.bak-*` 目录时，其内的本机独有文件仍会出现在 `[DELETE]`（`$Action.Dirs -contains $rel` 在 `:226` 先 `continue`，该类目录从不进 `preserveDirs`）。这是"计划不是分区"的一个**仍然可达**的小形态，也是 ① 唯一未被本轮修复覆盖的分支。
* **TCG-5** 断言用 `*` 通配而非字面量，路径含 `[` 时会失配（当前无实害，形态脆弱）。
* **TCG-6** `[PLAN] mirror … (N files)` 的每文件清单仍未与 `Get-ManagedDeploySet` 交叉核对。

### Cannot Verify From Diff

* 45/45 exit 0、installer sha256 `5A67C53C…`、§E 的四条 5.1 腿输出、probe D/E 的变异体行为：均为 **Author 自述产物**，不能重跑（禁执行型探针），也无法从 diff 反推。
* `Get-ChildItem -Recurse` 在非本机文件系统/更大目录规模下的父先于子顺序（只在本机 %TEMP% 以 5 个目录验证过一次）。
* 5.1 宿主上 `-contains`/`StartsWith` 行为是否与 7 完全一致（未跑）。

### Verification Needed

* None（无阻断项要求实跑；TCG-1 建议的断言由 Author 在下一轮落测后随常规证据一并给出）。

### Debt Verdict

* **Unpaid，与上轮一致**：`HANDOFF.md:81-91` 仍为 11 笔在册（其中 3 笔标注已偿还/已闭合）；`:96` 的 `~/.dsh` 首次真部署债仍 **Unpaid**（本切片不得声称 converged）。
* 与本轮改动直接相关的两笔**未因本轮加深也未偿还**：`HANDOFF.md:90`（A3 的 `dsh/skills` 臂两侧硬编码同一常量）与 `:91`（五处死代码，trigger = "下一次改动 `install.ps1` 之前"；**本轮正是改动 `install.ps1`**，该 trigger 已被触发而债未清）。
* 无新增暗债证据：本轮改动自身没有留下"先这样"式妥协（继承通道有注释说明与负向对照 probe E）。

### Recommended Next Step

1. **人类 commit / 进 `/final-review`**：本轮 0 Blocking，可收敛；但必须同时声明两件未办：TCG-1 的结构不变量断言与 TCG-4 的分支缺口。
2. **只改文档的准入口（针对 ④，一行）**：`docs/ai/TASK_BRIEF.md:98` 末句改为——"白名单闭集（冻结，应用于每个被镜像目录）：路径段含 `archive`（含作为末段）或叶名匹配 `*.bak-*` 的路径为 keep-local-only；**其下的全部内容随其祖先一并保留（子树继承）**。"`:139`（㉙）建议同句补"且其子树随保留"。**该句只能由人类改**（Frozen Acceptance）。
3. 若人类允许第三次窄修复：只补 TCG-1/TCG-4 的**断言**（不改生产逻辑），避免再动 `install.ps1` 语义。

### Requirement-Level Concerns

* **RC-1（文字 vs 实现，对应 ④）**：实现与 HANDOFF / 证据已是"子树继承"，而 **`TASK_BRIEF.md:98` 末句**仍写成逐路径闭集，没有"其下内容随保留"的措辞。二者不矛盾但**不等价**。**应改的就这一句**（外加 `:139` 的同句补注）。
* **RC-2**：AC2（`TASK_BRIEF.md:97`）要求"输出含**每一条**将执行的动作（将复制/播种的文件…）"，但复制/播种只有 `[PLAN] mirror … (N files)` 级的计数，无逐文件行；条款措辞对复制侧本就宽，故不判 Blocking，但建议在切片 B 的 AC 里把"逐文件行"显式写死或显式放弃。
* **RC-3**：AC2 的 A3 断言在**动作粒度**上等价，但 `HANDOFF.md:90` 的 skills 臂共享常量问题仍在——该条"集合相等"对**新增第三个 skill 目录**无区分力，评审时不应把它当成完整的受管面证明。
