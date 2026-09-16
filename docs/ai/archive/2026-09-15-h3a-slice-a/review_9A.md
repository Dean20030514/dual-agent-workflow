# review_9A.md — 切片 A 独立审查（9A 常规审）

> 本文件逐字转录 Reviewer 返回正文，Author 未改写。Author 的逐条表态另附（见 HANDOFF 的 Fix-Loop 节与后续 disposition commit）。

## round 2 — review_tip_sha `7259ee14f3b533ba08019c398f52064305436d53` / handoff_snapshot_sha `21a4f653091d62ea17ee436e6141e5769f0dcc6e`

**判定：不通过（Blocking = 2，均为 `[Product Blocking]`；`caused_by_last_fix` 全为 `no`）**

---

## 证据头

* `observed_head_sha`: `21a4f653091d62ea17ee436e6141e5769f0dcc6e`（== 指定快照；`git rev-parse HEAD` 逐字相等）
* `worktree_clean`: `yes`（全树 `git status --porcelain` 为空；`--ignored` 无任何 verdict/raw-log 残留）
* `read_handoff_from`: 工作树（`docs/ai/HANDOFF.md` 直接读取；未用 `git show <tip>`）
* `model_route`: `deepseek-official/deepseek-flash@high`（自报值，非证据；请 Author 与本轮实发参数逐字比对）
* `writes_performed: none`（全程只读：`rev-parse/status/diff/log/show`、`read`、`grep`、`Get-*`、`Select-String`、哈希；未执行 `install.ps1`、未跑测试/构建、未写任何文件）
* 覆盖缺口：`docs/ai/INSTALLER_GUARD.md`（本切片实际改动，但不在 `review_sensitive_paths`）——请 Author 补记或收窄。
* 已核对的机械事实：`install.ps1` sha256 = `A0D3F677…`（与 `last_test_run.txt:5` 一致）；0 个非 ASCII 字节、无 BOM、0 个 CRLF；无任何写入型 cmdlet（`Copy/Remove/New-Item/Set-Content/Out-File/[IO.File]` 仅出现在注释与字符串）；无 `Position` 属性；11 条机器态闭集与 ㉓ 逐条相同且不含 `codex/config.toml`；白名单为「整段 `archive`（含末段）+ 叶名 `*.bak-*`」且 `myarchive.md` 落 `[DELETE]`；`Test-Plan` 唯一实现在 `install.ps1:315`，被 `:528`（Validate）与 `:551`（Deploy）两处调用；`REFUSED` → `Show-Summary` 返回 1（`:485-486`），与 ㉗②「≠0」逐字相容；用例实数 37（15+7+9+6），与证据文件一致。

## Review Verdict

**不通过**（Blocking = 2，均为 `[Product Blocking]`；`caused_by_last_fix` 全为 `no`）。AC1–AC3 的行为面与退出码/输出契约逐条自查未发现违背，但交付物自身（`install.ps1` 头注释）与仓内规范记录（`INSTALLER_GUARD.md`）都把「切片 B 的语义」写成了当前事实，属产品级错误陈述，必须先修。

## Blocking Issues

**B1 [Product Blocking] — 交付脚本的头注释把切片 B 的语义写成当前行为。**
`install.ps1:9` 断言「Default (no parameters) = real deploy」，`:18-20` 断言「Every deployment target that already exists is backed up next to itself as `<name>.bak-<timestamp>`」；而同一文件 `:467-468` 明写「Slice A contains NO write path」，`:545-555` 的无参数路径打印计划后以 `RESULT=REFUSED` 退出 1，全文件无任何备份代码。
后果：这是本切片唯一交付给操作者的脚本，其头注释（Constraints 指定的产物）与 Payback-on-Touch `[U]` 第 6 项（「该文件注释逐句对读」）恰好要求它准确；按头注释操作的人会得到 exit 1 却以为部署已完成，且切片 B 接手时该注释已宣称自己的工作已完成——正是本切片存在的目的（杜绝「跑了一键命令却什么都没发生」的假成功）的反面。
`caused_by_last_fix: no`（`709649d..7259ee1` 的 install.ps1 diff 未触碰 1–36 行，已逐一核对）。
Fix：把 `:9` 改为「默认（无参数）= 校验 + 打印计划 + 明确拒绝执行（切片 B 才落地写入）」；删除 `:18-20` 的备份断言或移入「Deliberately NOT done by this script」并注明属切片 B；`:35-36` 的「removed by H3」改为本切片（H3 未收敛、其分支未合并）。

**B2 [Product Blocking] — `docs/ai/INSTALLER_GUARD.md` 违反冻结 Non-Goals，且新增正文陈述与本分支实现相反。**
该文件 +34 行（commit `dccb1c1`），但 `TASK_BRIEF.md` Non-Goals 与 `IMPLEMENTATION_PLAN.md:56` 都把 `INSTALLER_GUARD`/`INSTALLER_GUARD.md` 明列为「不改（切片 D）」；HANDOFF 自己也写「本切片不改这些文件」。
新增正文断言「`install.ps1` no longer has `-IUnderstandThisReplacesLiveConfig`; a no-argument run is a real deploy again」——本分支无参数 = `REFUSED`/exit 1（非真部署）；并把证据指向「`docs/ai/last_test_run.txt` (the H3 test run)」，而本分支该文件是切片 A 的运行记录。它还把「逐目标 `.bak-<stamp>` 备份 + 部署汇总」写成已落地（实为切片 B）。
后果：仓库的守卫债规范记录现在对「main 的安装器」给出与实现相反的描述并指向不存在的证据，而 `docs/` 正是本仓的产品本体；同时删/改这段属人的批准范围外动作。
`caused_by_last_fix: no`。
Fix：把该文件还原到 `e9917a1` 版本；若确需保留 `Repaid` 标记，只保留那一行并把 `Guard removal` 整节与无法核验的凭据/时间戳（见 Cannot Verify 第 4 条）移出本分支，或改写成切片 A 的真实状态并请人类追加批准。

## Non-Blocking Suggestions

1. **5 个 helper 无任何调用点 = 死代码（与 round-1 BL-3 同型）**：`TestHelpers.ps1:268 Get-ManagedDeploySet`、`:300 Get-ExpectedPlugins`、`:24/:25 Get-RepoRoot/Get-InstallerPath`、`:87 Get-FileSha256`、`:92 Test-PathInsideDirectory`。其中 `Get-ManagedDeploySet`/`Get-ExpectedPlugins` 的注释明确声称是「不向被测代码问期望」的独立期望源，却从未被断言使用 → 计划 A3 的「受管面一致」与插件清单漂移都没有机械门。Fix：接入用例，或删除并登记。
2. **A3 的检查名不副实**：`install.Plan.Tests.ps1:55` 标题写「covers exactly the managed surface (A3)」，实际是 `Get-PlanPathKeys` 抽每行**第一个**绝对路径（对 `copy/mirror` 行即**源**路径）做的 `-like '*needle*'` 存在性检查，无 equality、无目标侧。Fix：改为对**目标**路径集合做集合相等断言（可复用 `Get-ManagedDeploySet`）。
3. **受管面存在潜在（当前未发作）漂移**：旧脚本 `dsh/skills/*` 为**动态枚举所有子目录**，新 `Build-Plan:186` 硬编码两个名字；仓内今日恰为 2 个目录故集合相等，但新增第三个 bundle 会被静默漏部署，而计划承诺「受管面与旧脚本一致」。Fix：恢复枚举或加一条断言锁死同步。
4. **机器态判定与报告用了两个不同的锚**：`Test-Plan:432` 用 `$env:USERPROFILE`，`Get-MachineLocalReport` 用 `Split-Path -Parent $ClaudeRoot`。把根覆盖到另一个 home 时（如 `-DshDir D:\o\.dsh -ClaudeDir D:\o\.dsh\storages`）不会被 `machine-local-untouched` 拦住。Fix：判定锚改为「有效三根 ∪ 真实 home」，报告沿用同一函数。
5. **`-DryRun` 对会被拒绝的计划仍报 `RESULT=OK`（exit 0）**：`Test-Plan` 不在 DryRun 分支调用，故 `[SUMMARY] RESULT=OK` 与「该部署能通过校验」不等价。冻结条款未要求，但削弱了「0 = 请求的语义全部达成」。Fix：在 brief 里冻结措辞，或让 DryRun 附一行 `[CHECK]` 概览（需新增前缀 → 需人类冻结）。
6. **死状态与死赋值**：`Test-Plan:329` 的 `$script:checkFailed` 全文件只写不读；`:500-504` 的 `$RootSpecs` 与 `:519` 的 `$Roots` 在 `:514` 后被覆盖/从未使用。Fix：删除。
7. **HANDOFF 自述与事实不符（自述不构成证据，但会误导下一读者）**：`:109`「Human Approval Evidence：待人类批准」（计划已 `Approved`/`bc3cb39`）；`:28`「`review_9A.md` 目前为空」（该文件不存在）；`:26/:31/:44/:57` 声称不改文档，与 B2 冲突。

## Test Coverage Gaps

1. ㉓ 冻结的第二个前缀样本 `.claude\projects.bak-20260101-000000` 无用例（只有 `projects-x`，`install.Validate.Tests.ps1:55`）。
2. AC3 ⑦ 只覆盖 ⑤（源树内），冻结措辞要求的 ④（尾分隔符冲突）与 ⑥（机器态）的「去掉 `-ValidateOnly`」形态未测。
3. ㉙ 要求的**目录形态** `[PRESERVE]` 行（`workflow/archive`、`workflow/archive/old`）未断言（只断言了其中的文件）。
4. AC1 标为 K6 的那条用例（`install.Parameters.Tests.ps1:60`）用 `DryRun` + 已移除开关，失败族可来自未知参数而非位置参数 → 该行本身无区分力（`:67` 的干净样本补上了，故非 Blocking）；冻结的「5 对配对」也只由单一 K2 baseline 承担。
5. `install.ps1` 的 6 个插件名从未与 `claude/settings.json` 交叉核对（`Get-ExpectedPlugins` 存在但死代码），即「本任务的起因（陈旧插件清单）」无回归门。
6. 计划承诺的 5 个测试文件之外多出 `install.Host51.Tests.ps1`（由 ㉔/BL-3 正当要求），但计划文件未追加该文件与 A3 的落地记录 → 计划文本与实现不同步。

## Cannot Verify From Diff

1. 冻结命令的真实执行（37/37、exit 0、`tests` 四容器）——`last_test_run.txt` 是 Author 产物，本轮未复跑。
2. H3 round-1 verdict 的 **BL-4 与 `## Test Coverage Gaps` 之后正文**：`docs/ai/review_9B.md` 不存在，无法判断是否仍有未处置的 `[Product Blocking]`。
3. 切片 B 是否真会在写入前调用 `Test-Plan`：本切片不存在写入路径，只能看到 Deploy 分支现在会调用它。
4. `INSTALLER_GUARD.md` 新增正文引用的 `~/.dsh.bak-20260915-033521` 与 HANDOFF 记录的 `…-104625` 时间戳不一致；两者现均不存在（`Test-Path` 皆为 False），无法判定是两次事故还是笔误。
5. 5.1 下 `$PSNativeCommandUseErrorActionPreference = $false`（`install.ps1:71`）与 `Set-StrictMode -Version 3.0` 的相容性：由「5.1 腿全绿」间接支撑，未独立实跑。

## Verification Needed

1. 在 `7259ee1` 上复跑冻结命令并贴完整输出：`pwsh -NoProfile -Command "$c = New-PesterConfiguration; $c.Run.Path = 'tests'; $c.Run.Exit = $true; $c.TestResult.Enabled = $false; Invoke-Pester -Configuration $c"` → 期望 `Tests Passed: 37, Failed: 0`、exit 0。
2. B1 修好后需另有一条断言或人工核对记录：现有 37 条**没有一条**会因头注释错误而变红——请说明该修复如何被验证（否则只是又一处自证）。
3. 取回并落账 9B round-1 正文（含 BL-4），再决定 round 2 窗口是否有效。
4. 明确 `docs/ai/INSTALLER_GUARD.md` 的处置（还原 vs 改写）并同步 `review_sensitive_paths`。
5. 下一窗口开启前：`git status --porcelain --ignored` 必须为空、`git rev-parse HEAD` == 新 `handoff_snapshot_sha`。

## Debt Verdict

**Noted**。台账本身无隐藏债：`^\[DEBT\]` 计 9 条、本轮只新增 1 条（守护有效性装置），无量删；`~/.dsh` 首次真部署仍 **Unpaid**（HANDOFF 明示不得声称 converged），与 `last_test_run.txt §G` 一致。判 Noted 的理由：① `[U]` 第 6 项「注释逐句对读」被记为已在本切片履行，但 B1 直接反证；② 死 helper、A3 名不副实、受管面潜在漂移、`INSTALLER_GUARD` 越界四处新残渣未开 `[DEBT]`、也未当场修——按「零暗债」必须在修或开账之间二选一。

## Recommended Next Step

Author 处置 B1（重写 `install.ps1` 头注释）与 B2（还原/改写 `INSTALLER_GUARD.md`）→ 对 Suggestion 1/2/3 与覆盖缺口 1/3/5 选择「当场修」或开 `[DEBT]`/补用例 → 复跑冻结命令落新 `last_test_run.txt` → 更新 HANDOFF（含 `review_sensitive_paths`、Quick-Version 字段、`[U]`#6 的诚实状态）→ 在新 tip 上开 **9B + 9A round 3**（本窗口只对 `7259ee1` 有效；人类未 commit 前不得收敛）。

## Requirement-Level Concerns

1. **AC3 ⑦ 在本切片不可判（验收判定的可判性）**：brief 自述「若部署路径不调用该校验，⑦ 会实际执行 → 哈希变化 → 判定失败」，但切片 A 根本无写入路径，Deploy 分支无论如何都 exit 1/REFUSED → 该负向对照对「谓词把守部署」零区分力。实现（Deploy 调 `Test-Plan`）合于条款，但**中心声称的一半只由读代码支撑**。建议改为断言 deploy 形态输出中出现 `[CHECK] target-inside-source-tree FAIL`（这才证明谓词真跑过且其结论驱动了退出码）。
2. **计划记录的 A3 未进入冻结验收**：`IMPLEMENTATION_PLAN.md:119` 记「A3：AC2 增补 `[PLAN]` 路径集合 == 旧脚本受管面清单」，但 `TASK_BRIEF.md` 的 AC2 与 Amendment ㉓–㉜ 均无该条 → 计划自称增补了验收条款，唯一权威文件里却没有；test 却按 A3 命名。请人类裁决：补进 brief（只有人类能改）或标注 A3 为放弃。
3. **`-DryRun` 的退出码语义弱于 Goal 5**：Goal 5「0 = 请求的语义全部达成」。DryRun 对必被拒绝的计划仍返回 0，故「请求的语义」实际是「打印了计划」而非「计划可行」；若这是有意的，请写进 brief 的措辞，否则 `RESULT=OK` 会被下游当门用。
4. **机器态面覆盖随根覆盖而失效**（见 Suggestion 4）：AC3 性質要求「目标落在机器态面内 → ≠0」，当前只在「目标根 = 真实 home 的那一套」上成立。
5. **round-1 的账目不可核**：`review_verdict_9B` 记「不通过（4 条）」但正文未落仓、`review_9B.md` 不存在，BL-4 内容未知；在此状态下把 round 2 记为「已修复三条」的账目证据链断裂，final-review 时无法回溯。

## Author 表态（round 2）

B1/B2 与 `review_9B.md` 的 BL-3/BL-2 是同一问题，处置见该文件「Author 表态（round 2）」表（含人类裁决：`INSTALLER_GUARD.md` 还原到 `e9917a1`、`TASK_BRIEF.md` 三处改准）。9A 特有项：

| 条目 | 表态 | 处置 |
|---|---|---|
| B1 头注释把切片 B 写成当前行为 | **confirmed** | 重写 `install.ps1` 1–40 行安全模型 |
| B2 `INSTALLER_GUARD.md` | **confirmed** | 已执行：`e9917a1` 版本（74 行）回树，切片 A 的 +34 行移出 |
| NB-3 `dsh/skills/*` 由动态枚举改硬编码 | accepted | 恢复动态枚举（或加断言锁死同步） |
| NB-5 `-DryRun` 对必被拒计划仍报 `RESULT=OK` | accepted（需 brief 措辞） | 已获授权把语义写清为「已打印计划」 |
| 覆盖缺口 1/2/3（㉓ 第二个前缀样本、AC3⑦ 的 ④⑥、目录形态 `[PRESERVE]`） | accepted | 本轮补测 |
| 覆盖缺口 6 计划文本与实现不同步 | accepted | `IMPLEMENTATION_PLAN.md` 追加 `install.Host51.Tests.ps1` 与 A3 落地记录 |
| 需求层 1（AC3⑦ 在零写入切片不可判） | accepted | 改为断言 deploy 形态输出含 `[CHECK] target-inside-source-tree FAIL`（证明谓词真跑过且驱动退出码） |
| 需求层 2/3（A3 进 brief、DryRun 语义） | **human ruling** | 已获授权改准 |
| 需求层 5（round-1 账目不可核） | accepted | round 1 记为「正文不完整」，以 round 2 为准；`list_agents` 证实该子 agent 不可续 |

## round 3 — review_tip_sha `976d2e17be364a95df94498c794b82e1b31ca02e` / handoff_snapshot_sha `b530d9bdaa4a0c5d2b9e354375496ed9dfb4d595`

**判定：通过（无 `[Product Blocking]`）**，附 7 条非阻塞项 + 6 条覆盖缺口 + 4 条 Verification Needed。产品面满足 AC1–AC3 的冻结条款；**审查绑定账目（HANDOFF）存在一处硬性失准，须在人类 commit 前一次性对齐**（NB-5）。

### 证据头

- `observed_head_sha`: `b530d9bdaa4a0c5d2b9e354375496ed9dfb4d595`（== 提示的快照值）
- `worktree_clean`: **yes**（`git status --porcelain` 空；`--ignored` 无 verdict/raw-log 残留；审查前后各核一次）
- `read_handoff_from`: **工作树**（`docs/ai/HANDOFF.md` = HEAD 版本；未用 `git show` 取 tip）
- `model_route`: `deepseek-official/deepseek-flash@high`（**自报值，非证据**）
- `writes_performed`: **none**（全程只读；未执行 `install.ps1` 任何形态，未跑测试/构建/格式化）
- 提示的 `review_tip_sha=976d2e1` 与 HEAD（`b530d9b`）差两个 docs-only commit；生产面逐字节相同（`install.ps1` blob 在 `91b283e`/`976d2e1`/`HEAD` 均为 `24ecca7`，sha256 `029C44BA…` 与 `last_test_run.txt:5` 一致；`tests/**` 未变），故本轮对生产面的审查有效。

### Review Verdict

**通过（无 `[Product Blocking]`）**，附 7 条非阻塞项 + 6 条覆盖缺口 + 4 条 Verification Needed。产品面（`install.ps1` 参数面、两条零写入路径、单一谓词、退出码与输出契约）满足 AC1–AC3 的冻结条款；**审查绑定账目（HANDOFF）存在一处硬性失准，须在人类 commit 前一次性对齐**（NB-5）。

### Blocking Issues

None.

### Non-Blocking Suggestions

1. **NB-1（最实质）机器态谓词与机器态报告锚点不一致**：`install.ps1:457` 用 `$env:USERPROFILE` 拼机器态根做包含判定，而同一文件的 `Get-MachineLocalReport`（`:249-281`）刻意改用**生效目标根**，其 docstring 还写明"报告真实 home 是错的且有误导"。后果：`-ClaudeDir <X>\.claude\projects`（X ≠ 真实 home）时谓词报 OK，而同一次运行会把该路径打印为 machine-local；切片 B 会照此写入。**域内反例给不出**（AC3⑥ 的冻结样本是隔离 HOME）→ 按 brief 规则记非阻塞。`Proposed Fix`: 用与 `Get-MachineLocalReport` 同一套生效根映射构造判定集。
2. **NB-2 `[CHECK] … FAIL` 不足以支撑"谓词结论驱动退出码"**：Deploy 路径的 FAILED 与 REFUSED **都 `exit 1`**（`install.ps1:580-583`；`Show-Summary:507-511`），且 Goal 5 冻结"1 = 其余一切"。断言只证明 `Test-Plan` **跑过并判 FAIL**，不证明分支被消费——若部署路径恒打印 REFUSED，用例仍绿。`last_test_run.txt:41` 的"这才是…其结论驱动退出码的证据"是**过强声称**。`Proposed Fix`: 用例 10/11 增断言 `RESULT=FAILED`。
3. **NB-3 A3 只在动作粒度相等**：`install.Plan.Tests.ps1:97-110` 把预言机 `Get-ManagedDeploySet` 的**文件级**清单折叠成动作目标再比较，故 `New-MirrorAction`（`install.ps1:159-164`）的每文件清单若被写坏，A3 仍绿——切片 B 下这会删光受管文件。`Proposed Fix`: 用预言机已有的每目录文件数交叉核对 `[PLAN] mirror … (N files)`。
4. **NB-4 死代码（且未进债册）**：`install.ps1:112 $script:Plan`、`:354 $script:checkFailed`、`:544 $Roots` 只写不读；`tests/TestHelpers.ps1:86 Test-PathInsideDirectory` 无调用点（`last_test_run.txt:87` 自认"仍未办"，但 HANDOFF Remaining Risks 未登记）。`Proposed Fix`: 直接删除（它们不是待办，是死代码）。
5. **NB-5 HANDOFF 审查绑定字段失准（人类面对的收敛门）**：`:28/:30` `review_tip_sha`/`tested_sha` 仍写 `91b283e8`（round 2 修复 commit），而受审 tip 是 `976d2e1`、快照是 `b530d9b`，`last_test_run.txt:4` 写 `976d2e1` → HANDOFF"last_test_run.txt 的 tested_sha 行绑此值"**为假**；`:66` streak=**0** 与 `:9`"Fix-Loop streak = 1"及 round-2 `caused_by_last_fix: yes` 矛盾（硬停读该字段）；`:100` 仍"37/37 … sha `A0D3F677…`"；`:114`"待人类批准"（`:19` 已 Approved/`bc3cb39`）；`:116-123` Next Step 仍写 round 2；`:10-11` 段落重复。`Proposed Fix`: commit 前一次 docs-only 对齐。
6. **NB-6 计划未声明的文件**：`tests/install.Host51.Tests.ps1`（`7259ee1` 新增）不在批准计划的 Proposed Changes 表（6 行/4 个测试文件）内。它由 Amendment ㉔ 与计划 Testing Plan 的 5.1 腿所需，**判为批准意图之内但账目未记**；按"实际 diff 不超批准范围"闸门应由人类落一句记录。
7. **NB-7 5.1 腿上的无效 pin**：`install.ps1:74-76` 的 `$PSNativeCommandUseErrorActionPreference` 是 PS 7.3+ 偏好变量，在 5.1 下只是普通变量（无副作用，本切片也无原生命令步），注释的功效说明仅对 pwsh 腿成立。

### Test Coverage Gaps

- **G1** A3 文件粒度（见 NB-3）：预言机含文件清单却只比动作名。
- **G2** ㉙ 的**目录形态**样本无直接断言：`workflow/archive`（末段）应产出 `[PRESERVE] …(dir)`，用例只断言其子文件（`install.Plan.Tests.ps1:48-50`）；且 `:52` 的 `'\\archive(\\|$)'` 也抓不到 `[DELETE] …\archive (dir)`。
- **G3** 无"`*.bak-*` 样本不得出现在 `[DELETE]`"的负向断言（`:52` 只覆盖 archive 段）。
- **G4** Deploy 形态未断言进入 FAILED 分支（见 NB-2）。
- **G5** `dsh/skills` 枚举在 `install.ps1:191` 与预言机 `TestHelpers.ps1:285` **同样硬编码**两个 bundle → A3 检不出新增第三个 skill（本仓今日恰为 2 个；`last_test_run.txt:87` 已自认）。
- **G6** AC1② 的"参数名"半句在 K4b / K6 / K6-clean / K7 未断言（K7 客观不可满足，见 RC-3）。

### Cannot Verify From Diff

- 测试真实结果（43/43 exit 0）：本轮禁止执行；该声称只由 `docs/ai/last_test_run.txt` 承载，而其 **HEAD 版本晚于 `review_tip_sha`**（`b530d9b` vs `976d2e1`，属窗口外 docs-only 提交）。可静态复核的部分已复核：四个 `.Tests.ps1` 的 `It` 计数 = 15+9+13+6 = **43**，与证据行一致。
- 5.1 腿的运行期行为（NB-7 的 no-op、5.1 参数集诊断文案）只能由实跑定论。
- `HANDOFF:47` 声称其 `[U]` 清单与 `docs/ai/DSH-LANDING-NOTES.md` §5 逐条一致——该文件不在本次读取范围。
- `HANDOFF` Remaining Risks 的 `[DEBT]` 行数是否即活账（读命令只读，未代跑）。
- `覆盖缺口：docs/ai/HANDOFF.md`（审查绑定/streak/Quality Gates/Next Step 字段失准，commit 前必须覆盖）
- `覆盖缺口：docs/ai/last_test_run.txt`（HEAD 版本晚于 review tip）

### Verification Needed

1. **VN-1** 在快照上复跑冻结命令并贴原始输出（坐实 43/43 + exit 0）。
2. **VN-2** 给 Validate 用例 10/11 增 `RESULT=FAILED` 断言后复跑（证明 Deploy 路径**消费**谓词结论，NB-2）。
3. **VN-3** 在临时 HOME 下（真实 home 绝不入目标）跑 `-ValidateOnly -ClaudeDir <T>\elsewhere\.claude\projects`，报告判定（坐实 NB-1 是否拼写依赖）。
4. **VN-4** 跑 `(Select-String -Path docs/ai/HANDOFF.md -Pattern '^\[DEBT\]').Count`，与债册对齐前后各一次。
5. **VN-5** `Get-FileHash install.ps1`（已算得 `029C44BA…`）与 `last_test_run.txt:5` 一致——Author 复算一次即可，不必重跑套件。
6. 本切片**不得**被记为 converged，直到 AC10 的 `~/.dsh` 首次真部署完成（`HANDOFF:122`）。

### Debt Verdict

**Unpaid**。理由：① AC10 的 `~/.dsh` 首次真部署仍未发生（已披露，非暗账）；② 本轮三项已知残余（NB-4 死代码/死 helper、G5 共享硬编码枚举）只写在证据文件里，**未进唯一债落点** HANDOFF Remaining Risks，属"明账未登"；③ 承接 `[U]` 第 5/6 项在本轮不可核（第 6 项被声称已履行，但无逐句对读记录）。承接的 9 笔 `[DEBT]` 本身逐字保留、未被静默删除，这一点是干净的。

### Recommended Next Step

Author **一次性 docs-only 对齐轮**：改 `HANDOFF` 的 Review & Test Binding / `Fix-Loop Counter` / Quality Gates / Human Approval Evidence / Next Step / 去重段落（NB-5），把 NB-4 与 G5 二选一（当场删除/修，或写成带 trigger 的 `[DEBT]`），补 NB-2 / NB-3 / G2 / G3 四处断言，复跑冻结命令并落新 `last_test_run.txt`（`tested_sha` 指向新 tip），随后交人类 commit。**不需要**重写产品面；本轮无 `[Product Blocking]`，Fix-Loop 无需递增。

### Requirement-Level Concerns

- **RC-1（零写入 + REFUSED 契约）**：**通过**。`install.ps1` 对写入型 cmdlet 的 grep 无命中（退出码 1），写入型函数是"刻意缺席"（`:492-493`）；套件写入只落 `$env:TEMP`。K1（`TASK_BRIEF:74`）与 ㉗（`:137`）**已不再冲突**：㉗ 的 ①②③ 由 `install.ps1:580-583` 与 K1a/K1b 逐条覆盖，K1 多出的"输出含 `RESULT=REFUSED`"正是 ㉗ 语义句里的同一 token（`:583` 仅在预检通过时打印）。残余只是编排列举不对称，非冲突。
- **RC-2（单谓词与 AC3⑦ 可判性）**：`Test-Plan` 被 `-ValidateOnly`（`:556`）与 Deploy（`:579`）调用、**不**被 `-DryRun` 调用，与 `TASK_BRIEF:101` 的冻结措辞一致；AC3⑦ 的 deploy 形态按条款字面**可判**（≠0 + 假 repo 与临时 HOME 哈希不变）。但"谓词结论驱动退出码"在 Deploy 上**不可判**（两条分支同为 1）→ 见 NB-2。
- **RC-3（AC1② 不可满足的一半）**：PowerShell 的参数集冲突文案不回显参数名，而 Constraints 又禁止用体内互斥诊断（K7 必须绑定期失败），故"输出含该样本的参数名 + 绑定诊断族"这一合取对 **K7 客观不可满足**。`Proposed Fix`: 把 AC1② 改为"未知/错拼样本含参数名，位置样本含该 token，参数集样本含诊断族"。
- **RC-4（A3）**：A3 **已具备机械载体**（`install.Plan.Tests.ps1:94-141` + 独立预言机 `Get-ManagedDeploySet`），且 `TASK_BRIEF:100`（进 AC2）与 `IMPLEMENTATION_PLAN:119` 已一致；不满足处只剩粒度（NB-3）与共享硬编码（G5）。
- **RC-5（闭集与白名单宽窄）**：机器态闭集与 ㉓ 的 11 条**逐字相同**，`~/.codex/config.toml` 正确不在集内且按 seed 处理；判定为段式包含（`projects-x` / `projects.bak-*` 反例在用例 6b 落地）。keep-local-only = 任一路径段 `archive`（含末段）+ 叶名 `*.bak-*`，与 ㉓/㉙ 一致：**不过宽**、**不过窄**（`myarchive.md` 反例有用例）。唯一宽窄缺口是锚点问题（NB-1）。
- **RC-6（计划 vs 实现漂移）**：计划 row 1 点名的函数与模式分流**全部落地**；Non-Goals 的禁止面**在范围内零净变更**（`INSTALLER_GUARD.md` 净回到 base，`6cf2ebc`）。两处声明-实现落差：未声明的 Host51 文件（NB-6）、计划 `:118`/㉘ 承诺的目录行字面 `d:<rel>/` 实际实现为 `d:<rel>`（`TestHelpers.ps1:76`；能力在、格式不同，纯文本差异）。编码面独立复核通过：`NON_ASCII=False`、`CRLF=0`、无 BOM、`:1-41` 头注释纯 ASCII。

## round 4 — review_tip_sha `c4224fa3c1a20094b0650790ba94897557c2985b` / handoff_snapshot_sha `9e081bf3b0e5be0864099709bc7a11024b9e5da4`

**判定：不通过（Blocking Issues 非空）**

```
observed_head_sha: 9e081bf3b0e5be0864099709bc7a11024b9e5da4
worktree_clean: yes
read_handoff_from: 工作树
model_route: deepseek-official/deepseek-flash@high
writes_performed: none
覆盖缺口: 无（diff --name-only 的生产/测试/验收文件均由 HANDOFF 的 review_sensitive_paths 覆盖）
```

审前快照与 prompt 一致；正文 diff `e9917a1..c4224fa` 已逐文件读；HANDOFF / `last_test_run.txt` 取工作树。上轮唯一 `caused_by_last_fix: yes` 的 BL-1（镜像目标为文件时 `Substring` 崩溃）**已真修**：守卫 `:217` 改成「存在且是容器」，既有形状检查 `:392-393` 重新可达，回归用例 12 对 validate 与 deploy 两形态断言 `RESULT=FAILED` + 点名 FAIL + 无 `startIndex` 异常（按 diff 复核成立）。㉗ 四项判定齐全；退出码契约 `0=OK / 1=FAILED 或 REFUSED` 与实现、K1、㉗ 逐字一致；`install.ps1` 全文件无任何写入型 cmdlet（grep 实测）、`NON_ASCII=False`、CRLF=0、586 行、worktree sha256 = `AAC42698…` 与 `last_test_run.txt` 头部一致、44 条 `It` 计数与证据自洽。但白名单分类存在一处**计划自相矛盾**（Blocking-1）。

### Blocking Issues

**B1 `[Product Blocking]` — 白名单只命中「目录叶名」时，其内容仍被列为 `[DELETE]`，计划同时声称保留该目录与删除其内文件。** `caused_by_last_fix: no`（分类逻辑自首轮实现起未变，守卫修复只改了枚举前置条件，未触及分类）
* 具体反例（域内输入：白名单闭集含「叶名匹配 `*.bak-*`」，且 ㉙ 已确立目录形态也算样本）：在被镜像目录里预置 `…\<ClaudeDir>\workflow\old.bak-20260101-000000\`（**目录**）内含 `note.md`，跑 `-DryRun`。`Get-MirrorDelta` 的文件循环 `:218-222` 完全不看祖先目录是否已判 preserve，故实际输出同时含 `[PRESERVE] …\workflow\old.bak-20260101-000000 (dir)` 与 `[DELETE] …\workflow\old.bak-20260101-000000\note.md`（目录循环 `:230-242` 只在「目录是否可删」一侧做了祖先/后代一致性检查，文件侧没有对称检查）。
* 具体后果：`-DryRun` 的保留/删除分区不是分区——同一子树同时出现在两个清单里，Goal 3「将删除哪些'仅存在于本机'的路径、将保留哪些」对该输入失效；切片 B 按 `[DELETE]` 集合执行镜像替换时，会删掉一个**同一份计划声明为保留**的 `*.bak-*` 目录里的本机独有内容（正是本切片要防的那类事故：HANDOFF 记的事故中被删的 45 个旧 `*.bak-*` 条目同属这一族）。`Get-MirrorDelta` 自己的 doc 注释（`:204-207`：目录在下游有 keep-local 内容时必须存活、计划也必须这么说）与其文件侧实现相矛盾。
* 归类说明（按母本「后果写得出、可达性不确定 → 按 Product 记交人类裁决」）：冻结闭集是**逐路径**措辞，字面读法下这些 `[DELETE]` 行是合规的，冲突源于闭集语义本身（见 RL-1）。
* `Proposed Fix`（首选）：在 `Get-MirrorDelta` 中把文件分类移到目录分类之后，并把「祖先目录已判 preserve」作为保留条件——即对每个 live-only 文件，除 `Test-PathKeepLocalOnly($rel)` 外再检一次任一祖先 rel 是否在 `$preserveDirs` 中，命中则进 `$preserveFiles`；同时补 ㉙ 的目录形态样本（`*.bak-*` 目录 + 目录内文件）。备选（需人类裁决）：若无意为子树语义，则保留现行为但改 TASK_BRIEF 闭集措辞为显式逐路径并写明「目录被保留不等于其内容被保留」——TASK_BRIEF 是 review-sensitive，只能由人类改。

### Non-Blocking Suggestions

**NB-1（上轮 NB-5 复验：账目绑定代际不一致，且在同轮"对齐"后一个 commit 内又漂）** HANDOFF `review_tip_sha` / `tested_sha` = `2bb5a26`、Quality Gates 写「44/44，`tested_sha = 2bb5a26`」，而本轮 prompt 的 tip 与 `last_test_run.txt` 头部均为 `c4224fa`。同文件内另有三处旧代际：`## Current Phase` 仍是 round 2、`## Next Step` 仍是 round 2 指令、Quick-Version 的 Human Approval Evidence 仍写"待人类批准"（实际 `bc3cb39` 已批准）；`上一任务状态` 一行重复出现两次。后果：三道闸门里的"审查 SHA 绑定"账面上指向未被审的 commit。`Proposed Fix`：窗口结束后由 Author 一次性重写 Review & Test Binding / Current Phase / Next Step / Quick-Version（`review_tip_sha = tested_sha = c4224fa` 或新 tip；`streak = 2`），并删掉重复行。

**NB-2（计划 vs 实现范围漂移，上轮 NB-6 未落记录）** `tests/install.Host51.Tests.ps1` 不在 `IMPLEMENTATION_PLAN.md` 的 Proposed Changes 表（6 行）内，而实际 diff 含它。后果：批准范围与交付范围对不上，`/final-review` 无法机械核对。`Proposed Fix`：人类落一句授权记录（该文件是 Amendment ㉔「5.1 腿」的实现载体）。

**NB-3（执行前置约束 ② 字面未满足，无实际风险）** K4a / K4b / K5 / K6 第一样本未显式传三个路径参数，与「每次子进程调用必须显式传 `-ClaudeDir`/`-CodexDir`/`-DshDir`」字面不符（隔离实际由 ③ 的 wrapper 互锁提供）。`Proposed Fix`：补上三个临时路径参数，或经人类批准把 ② 的范围写成"凡可能进入执行路径的样本"。

**NB-4（死代码，上轮 NB-4/G6 未清）** `$script:Plan`(`:112`)、`$script:checkFailed`(`:357` 只写不读)、`$Roots`(`:547`)、`TestHelpers.Test-PathInsideDirectory`(`:86`)、`Invoke-InstallerCase -Environment`(无调用)。`Proposed Fix`：直接删除（无行为变化）。

**NB-5（机器态谓词锚与报告锚不同源，上轮 NB-1 未修）** 谓词用 `Join-Path $env:USERPROFILE $m`（`:460`），报告用 `Split-Path -Parent $ClaudeRoot`（`:560`）；`-ClaudeDir` 被重定向而 HOME 未重定向时不会被 `machine-local-untouched` 拦住，而报告会打印出错误路径。本切片 AC 样本全在重定向 HOME 下，故 AC 成立。`Proposed Fix`：按生效根展开 11 条机器态子路径，报告与谓词共用同一展开函数。

**NB-6（`[CHECK] plugin-cli` 无区分力）** 两个分支都 `Report $true`（`:474-483`）。若切片 C 期望"CLI 缺席 → 非零"，此载体不会暴露。`Proposed Fix`：注释标 `SLICE C`，切片 C 冻结后把缺席分支改为 FAIL。

### Test Coverage Gaps

* **AC3⑦ 的 ④/⑥ 部署形态缺"零写入"半条**：case 10 只断言假 repo 树不变（未取 HOME 签名），case 11 完全未断言零写入；AC3 ⑦ 要求「≠0 **且**假 repo 与临时 HOME 零写入」。仅 ⑤（case 7）两条都断言。（按母本「缺证据 ≠ 未满足」记此节——`install.ps1` 无任何写入 cmdlet，反例写不出。）`Proposed Fix`：case 10/11 各加 HOME 签名断言。
* **白名单 `*.bak-*` 只有文件形态样本**（`:157`），目录形态无样本 → 与 B1 同一格。
* **`seed src -> dst`（config.toml 缺失分支）从不断言**：所有用例都带 `-SeedConfigToml`。`Proposed Fix`：加一条不带 `-SeedConfigToml` 的 `-DryRun`，断言 `[PLAN]\s+seed` 存在。
* **`[PRESERVE] … (machine-local, never touched)` 家族无正面断言**。`Proposed Fix`：用独立预言机（11 条闭集 × 生效根）断言该行集合。
* **live-only 目录树「父目录 + 子目录同时进 `[DELETE]`」路径无样本**（`:230-242` 对同族目录不去重）→ 切片 B 按清单逐条删除会命中已删除路径。`Proposed Fix`：预置 `straydir\sub\f.md`，与切片 B 的执行器约定一致。

### Cannot Verify From Diff

* 「44/44 exit 0」与 §E 的 5.1 逐用例输出**本身**：未跑（禁令），只能核产物自洽性（sha256 与 worktree 一致、44 条 `It` 计数吻合、宿主路径断言与 `psver=5/7` 互斥对照在 diff 内确实存在）。
* `Get-ManagedDeploySet` 是否真等于**旧脚本**的受管面：预言机是测试侧重写，与旧脚本未逐条对读。
* 真机（未重定向 HOME）下 Deploy 形态的完整输出：切片 A 明确不执行，属切片 B。

### Verification Needed

1. **证伪/证实 B1（单样本）**：临时 HOME + 显式临时目标下，造 `…\claude\workflow\old.bak-20260101-000000\note.md`（目录+文件），跑 `-DryRun`，看该目录是否有 `[PRESERVE] …(dir)` 行、且是否**同时**存在含该目录路径的 `[DELETE]` 行。
2. **AC3⑦ 的 ④/⑥ 零写入**：给 case 10/11 补 HOME 签名断言后单跑这两条。
3. **A3 预言机与旧脚本对读**：`git show task/h3-installer-hardening:install.ps1` 里的受管面清单与 `Get-ManagedDeploySet` 逐条比对（只读）。

### Debt Verdict

**Deferred** —— 本轮唯一新增债（A3 的 `dsh/skills` 预言机与被测代码抄同一常量）已按 No-Hidden-Debt 记入 `[DEBT]` 并带 payback trigger，属合法明账；`~/.dsh` 首次真部署债仍 **Unpaid**。

### Recommended Next Step

1. 人类先裁决 B1 的两种读法：白名单是**子树继承**（则 Author 按首选修法改 `Get-MirrorDelta` + 补目录形态样本）还是**逐路径**（则改 TASK_BRIEF 措辞 + 切片 B 语义，只能人类改）。
2. 若判为需修：Author 在**同一窄修复**上做最小改动，复跑冻结命令并刷新 `last_test_run.txt`，形成新 tip。
3. 双审窗口结束后再一次性重写 HANDOFF 的绑定/Current Phase/Next Step/Quick-Version（NB-1），并把 NB-2 的范围外文件授权记录交由人类落一句。
4. 下一轮仍 **9B 先、9A 后**，同一 tip + 同一快照；若再出 `caused_by_last_fix: yes` 的 Product Blocking，只能回退或重新拆任务（本轮为 `no`，修复轮仍合法）。

### Requirement-Level Concerns

* **RL-1（B1 的根因，需人类裁决）**：冻结白名单闭集是**逐路径**判定（"路径段含 archive 或叶名匹配 `*.bak-*`"），而 Goal 3 与事故教训要的是**子树**语义（"仅存在于本机的路径必须存活"）。两者在「`*.bak-*` 目录」形态上必然冲突；本切片把冲突照原样输出。建议把闭集语义一次写清为"命中即整棵子树保留"，否则切片 B 会继承同一歧义（TASK_BRIEF 为 review-sensitive，只能人类改）。
* **RL-2**：AC3⑦ 要求部署形态"零写入"，但本切片 Deploy 路径在 `Test-Plan` 失败即返回、写入函数被刻意删除，故该断言在当前切片近乎恒真（真正有区分力的是 K1a「校验通过仍拒绝」）。建议在切片 B 落地写入后，才把 ④/⑥ 的零写入断言作为硬要求。
* **RL-3（上轮点名，本轮确认仍开放）**：`-DryRun` 对"镜像目标存在为文件"不再崩溃也不再点名（守卫使其静默给出 `delete=0`、`RESULT=OK`），与 AC2 的冻结措辞一致（OK ≠ 计划能过校验），但该形态下 DryRun 的计划完整性无任何可见提示；建议切片 B 冻结时明确 DryRun 是否应附带形状警告。

## round 5 — review_tip_sha `09df8d7738ba05c3d8bd4477da0ab8a001a11183` / handoff_snapshot_sha `9d51a7559a41357d7532390f24804c5dc6607a6b`

**判定：不通过 —— 2 条 `[Product Blocking]`，二者 `caused_by_last_fix: no`**

```
observed_head_sha: 9d51a7559a41357d7532390f24804c5dc6607a6b（== handoff_snapshot_sha）
worktree_clean: yes（全树为空；--ignored 无残留）
read_handoff_from: 工作树 docs/ai/HANDOFF.md（未用 git show tip）
model_route: deepseek-official/deepseek-flash@high（自报值、非证据）
writes_performed: none（0 次写文件、0 次 commit、未打开 review_9* / archive/**）
```

### Blocking Issues

**PB-1 `Get-MirrorDelta` 的目录分类仍与"子树继承"矛盾（祖先 `[DELETE]` / 后代 `[PRESERVE]`）** — `install.ps1:224-242`、`:244-258`
- 机制：目录循环按 `Get-ChildItem -Recurse` 顺序（**父先于子**，本机只读实测 `dsh/` 树确认）逐个判定，`holdsPreserved` 只看**已累积**的 `$preserveFiles`/`$preserveDirs`；round 4 新增的继承通道（`:248-258`）只重分类 `deleteFiles`，**从不回看 `deleteDirs`**。
- 反例（域内、可构造）：`<ClaudeDir>\workflow\legacy\old.bak-20260101-000000\note.md`，其中 `legacy` 是 live-only 目录、其下唯一白名单命中物是那个 `*.bak-*` **目录**（无 `archive` 段、无 `*.bak-*` 文件叶名）。预期输出：`[DELETE] …\legacy (dir)` 与 `[PRESERVE] …\old.bak-… (dir)` / `[PRESERVE] …\note.md` 并存 → 计划不是分区。
- 后果：切片 B 若照 `[DELETE]` 行递归执行镜像替换，将删掉计划声明保留的内容 —— 与真机事故同族（45 个旧 `*.bak-*` 条目），而 AC2 的 needle 式判据（`TASK_BRIEF.md:98` ③）看不见它（祖先行不含样本路径）。`archive` 形态不暴露（其内容带 `archive` 段，先落进 `preserveFiles`，祖先因而是被保留的）；暴露面恰是"`*.bak-*` **目录**位于 live-only 目录之下"。
- `caused_by_last_fix: no` —— `deleteDirs` 分类与祖先守卫在本 fix 之前即如此（对照 `git diff 6384244..09df8d7 -- install.ps1` 只增 `:248-258` 的文件侧通道）。属"修复自称闭合但未覆盖嵌套形态"，非新引入。
- Proposed Fix：目录分类改为在**完整**集合上求闭包（先分类全部 live-only 文件与目录，再迭代到不动点：任一目录若其自身或任一后代在 `preserveDirs`/`preserveFiles` 中即移入 `preserveDirs` 并移出 `deleteDirs`）；补一条不变式用例「任何 `[DELETE] … (dir)` 行不得是任何 `[PRESERVE]` 行的路径前缀」+ 上述嵌套样本。

**PB-2 冻结验收文本与人类裁决「白名单 = 子树继承」不一致** — `docs/ai/TASK_BRIEF.md:98`（同口径还见 `:139` ㉙、`:98` AC2 判定方式 ③、`:107` AC3）
- 现状句（逐字）：`白名单闭集（冻结，应用于每个被镜像目录）：路径段含 archive（含作为末段）或叶名匹配 *.bak-*。` —— 这是**逐路径**读法：`*.bak-*` **目录**被命中，其内文件叶名既不匹配、又无 `archive` 段，按本句仍算 `[DELETE]`，正是 round 4 B1。
- 后果：本文件自称"只看此文件应能判断实现对不对"，切片 B 照此实现即会删掉白名单目录的内容；而实现已按人类裁决做了继承 —— 契约与实现分叉，验收基准失效。
- `caused_by_last_fix: no`（人类裁决领先于文本；实现侧按裁决做了半程，PB-1 是另一半程）。
- **应由人类改的确切句子**：把 `:98` 该句替换为「白名单闭集（冻结）：某路径若**自身或任一祖先路径段**含 `archive`（含作为末段），或**自身叶名或任一祖先叶名**匹配 `*.bak-*`，即命中并**整棵子树继承** —— 命中目录之下的一切内容均须 `[PRESERVE]`，且其任何**祖先目录**不得出现 `[DELETE]`。」并把 `:98` 的 ③ 改为对"祖先/后代关系"的否定断言、`:139`（㉙）同步一句。

### Non-Blocking Suggestions

- **AC1 的"配对通过样本"未逐字落实**（`install.Parameters.Tests.ps1:38,46,53,61,75`）：这四个失败样本的 argv 里没有三个临时路径参数，`TASK_BRIEF.md:91` 冻结的是"同一命令行换 token"。区分力因 wrapper 互锁与同 `BeforeEach` 的 K2/K3 通过样本仍在，故不阻断。
- **头注释未写「`-DryRun` 的 `RESULT=OK` ≠ 计划能过校验」**（`install.ps1:15-16`、`:25-26`；冻结措辞在 `TASK_BRIEF.md:101`）。
- **`-ClaudeDir ''` 静默回落真实 home**（`install.ps1:145`）。切片 A 无写入故不阻断，切片 B 是部署地雷。
- **机器态谓词锚与报告锚不同源**（谓词 `$env:USERPROFILE`：`install.ps1:475`；报告用生效根：`:575`、`:586`）。
- **新样本的断言文本强于其谓词**（`install.Plan.Tests.ps1:96` 写"no [DELETE] row may target its contents"，实现为 needle 包含 `*<bakDir>*`）—— 对文件侧可红（probe E），但结构上永不可命中祖先行；建议改写成路径前缀关系断言（同 PB-1 的不变式）。
- **`[PLAN] mirror … (N files)` 未与 `New-MirrorAction.Files` 交叉核对**（`install.ps1:339`）；A3 只到动作粒度。
- **账目代际：本轮同代 ✓，旧轮残留 ✗** —— `review_tip_sha`/`tested_sha`/`last_test_run` 头部/`Current Phase`/Quality Gates 均为 `09df8d7`+`5A67C53C…`+45 ✓；但 `HANDOFF.md:120-127`（Next Step 仍写 round 2 / `7259ee1` / "取回 9B BL-4" / "落 9A verdict（当前为空）"）、`:118`（Human Approval Evidence 仍写"待批准"）、`:30` 括注、`:5`（`Current Phase: Planning`）、`:10-11`（整段重复）、Fix-Loop 段缺 round 4 记录、Work Log 停在 `709649d` 均过期。
- **`[DEBT]` 计数陈述过期**：`HANDOFF.md:5` 写"下方 9 笔"，实测 `^\[DEBT\]` = **11**。

**上轮遗留项逐条处置（按 `last_test_run.txt:58` 的自报清单核对）**：① 机器态锚 —— **未闭**；② A3 每文件粒度 —— **未闭**（`tests/**` 无 `(N files)` 断言，grep 0 命中）；③ source 侧同型崩溃入口 —— **未闭**（今日不可达）；④ 头注释"OK ≠ 过校验" —— **未闭**；⑤ `-ClaudeDir ''` —— **未闭**；⑥ 死代码 —— **以 `[DEBT]` 收编，未清**（实为 6 处而债文写"五处"）；⑦ 覆盖缺口 —— **大部分未闭**；G1–G6 **无法逐条对号**（隔离禁读）。

### Test Coverage Gaps

- 无 PB-1 的嵌套样本，也无"`[DELETE] (dir)` 不得为 `[PRESERVE]` 行祖先"这一**不变式**用例 —— 后者是能机械抓住本类的唯一形态。
- `install.Validate.Tests.ps1:109`（case 10）只比 `RepoRoot` 签名，`:125`（case 11）无任何零写入签名断言（case 7 有 `$script:HomeBefore`）。
- `:55`（case 6b）只有 `.claude\projects-x`，缺 ㉓ 点名的 `.claude\projects.bak-20260101-000000` 第二样本。
- `seed src -> dst`（目标缺失）分支不可达：凡 `SeedTargets` 的用例都带 `SeedConfigToml`。
- 机器态 `[PRESERVE]` 家族只有**排除式**断言（`install.Plan.Tests.ps1:74`），无正面断言。
- DryRun 语义无机械钉住。
- `-ClaudeDir ''`、`-DshDir ''` 无样本（K9 闭集未含空串，故按 NB 计）。

### Cannot Verify From Diff

- `45/45 exit 0`、§E 的 5.1 逐用例宿主、probe D/E 的变异-变红结果：**均为 Author 自报产物**，本轮按轻量协议未重跑（不构成证据）。
- PB-1 反例的**实际输出**：只做了代码路径推演 + "枚举父先于子"的只读实测（`dsh/` 树），未实跑安装器（硬禁令）。
- 上轮 verdict 原文与 NB/G 编号映射：隔离禁读。

### Verification Needed

1. **PB-1 取证（最高优先，改代码前先跑）**：在临时 HOME 下预置 `<ClaudeDir>\workflow\legacy\old.bak-20260101-000000\note.md`，跑 `-DryRun`，逐字贴出 `[DELETE]`/`[PRESERVE]` 全体行 + `[SUMMARY]` + 退出码，确认是否出现 `legacy (dir)` 与 `old.bak-… (dir)` 并存。
2. 补 **PB-1 不变式断言**与嵌套样本后，复跑冻结命令，逐字贴 `Tests Passed: N, Failed: 0` 与 exit code。
3. 人类裁决 PB-2 的精确措辞并落 `TASK_BRIEF.md:98`（+`:139`、`:98` ③），确认后由 Author 同轮对齐账目。
4. 若采纳 NB 的 `(N files)` 交叉核对：给出该断言首次通过的真实输出。

### Debt Verdict

- 在册 **11** 笔（`HANDOFF.md:81-91`），全部带 `Payback trigger` → 无暗债；`:5` 的"9 笔"陈述过期。
- 本任务新增两笔措辞合规；但**死代码笔的 trigger（"下一次改动 `install.ps1` 之前"）在 PB-1 修复轮即被触发** —— 该轮必须同轮清偿或重新登记。
- `~/.dsh` 首次真部署 + AC10 第二项仍 **Unpaid** → 本切片在任何情况下都不得声称 converged。
- `guard_effectiveness: N/A` 与仓内无常驻守护装置的 `[DEBT]` 自洽；probe D/E 不等于装置产物 ✓。

### Recommended Next Step

1. 流程状态：streak 已在硬停阈值 2，`HANDOFF.md:68` 的"窄修复例外"只覆盖第 4 轮；**Author 不得自开第三轮常规修复**。本轮两条 Blocking 均 `no`，不触发"必须回退/重新拆任务"的 `yes` 分支。
2. 选项 A（**推荐**，最小充分）：请人类批准**第三次窄修复例外**，范围严格限于 PB-1 的目录闭包 + 1 条不变式用例 + 嵌套样本；PB-2 的 `TASK_BRIEF.md:98`（+`:139`）措辞由人类改准；同轮对齐 `HANDOFF.md:5/:10-11/:30/:118/:120-127` 与 Fix-Loop/Work Log。
3. 选项 B：按硬停出口回退或重新拆任务 —— 把"计划是分区（祖先/后代互斥）"抽成独立可判 AC，与参数面解耦。
4. 无论 A/B，**先做 VN-1 取证**：不要在未确认的推演反例上直接改代码。

### Requirement-Level Concerns

- **Goal 1–6 逐条满足**：`[CmdletBinding()]`+3 ParameterSet+6 参数 ✓（`install.ps1:43-70`，无 `Position`）；`-ValidateOnly`/`-DryRun` ✓；单一谓词 `Test-Plan` 仅在此两条路径被调用（`:574`、`:597`）✓；退出码语义 ✓；Pester 套件 45 用例（6+15+10+14，实测计数）✓。
- **Non-Goals 逐条守住**：diff 仅 10 文件、全在许可面；`install.ps1` 内写型 cmdlet 实测 **0 命中**；插件步零执行 ✓；生产面 diff ≈1601 行 < 4000 预算 ✓。
- **AC1/AC3 条款可判 ✓**；**AC2 的「计划必须完整且与切片 B 的执行集合一致」在冻结文本里不可判**：`:98` ③ 只做 needle 包含，无法表达"祖先与后代不得同时既删又留"——建议随 PB-2 一并把该句改成关系型断言。
- **口径漂移（低风险）**：`install.ps1:17-20` 头注释把"`archive` 段 + `*.bak-*`"描述成保留面，与 `:244-247` 一致，但同样未写"祖先不得被删"；改注释时与 PB-1 同轮。
