# review_9B.md — 9B blind review, round 1

> 审查对象：`review_base_sha = e9917a1` → `review_tip_sha = 8adc119fc453a016602fdc274e9a60c8fb003468`；
> `handoff_snapshot_sha = e56451a8390ac7524cc04651ca76290aea6be84c`（= 审前 HEAD）。
> 本文件是 Reviewer 返回正文的**原样落盘**（Author 于双审窗口结束后转录，未改一字）。调用形态：`subagent` 前台 + `provider: deepseek-official` + `model: deepseek-flash` + `reasoning_effort: high`。

## 审前快照自检与隔离核验

```
observed_head_sha: e56451a8390ac7524cc04651ca76290aea6be84c  (== handoff_snapshot_sha ✓)
worktree_clean: yes  (git status --porcelain 全工作树为空 ✓)
read_handoff_from: 工作树  (docs/ai/HANDOFF.md 与 docs/ai/last_test_run.txt 均直接读工作树，未用 git show <tip>:)
model_route: deepseek-official/deepseek-flash@high  (自报：harness 系统提示只言明 "deepseek-flash"；reasoning_effort 对我不可见，此处按派发默认 high 填写，供 Author 与实发参数逐字比对)
writes_performed: none  (本轮无任何写操作、无 commit、无测试/格式化执行、未落盘 verdict)
```

* **污染扫描**：`git status --porcelain --ignored` 为空；对 `9A*.md` / `9B*.md` / `.codex-review-*` / `.dsh-review-*` / `review_9*` / `review-*` / `*_raw.log` 做全树 `-Force` 递归显式扫描，命中项全部是**已提交历史产物**（`docs/ai/review_9P.md`、`docs/ai/archive/2026-09-06-dsh-landing/review_9{A,B}*.md`）——按流程不算本轮污染，**我未打开其中任何一份**。**无污染，本轮双审隔离成立。** 未发现不可枚举目录（无权限受限缓存目录命中）。
* **覆盖缺口：none**。`git diff --name-only e9917a1..8adc119` 的必含类别（生产源码 `install.ps1` / tests `tests/**` / 无 migrations·schema / 无构建配置 / 无依赖声明与 lockfile / `docs/ai/TASK_BRIEF.md`）全部被 HANDOFF 的 `review_sensitive_paths` 覆盖；`IMPLEMENTATION_PLAN.md`、`QUALITY_GATES.md`、`HANDOFF.md`、`archive/**`、`review_9P.md` 的出现按规则不计缺口。
* 正文 diff 命令按 `:(exclude)` 三项执行，输出中**未出现** `IMPLEMENTATION_PLAN.md` 与 `review_9*` 正文；我未单独打开该计划文件。
* 独立复核的账目：`task_brief_blob_sha` = `e2453702…` 与 tip 上 `docs/ai/TASK_BRIEF.md` blob **逐字相符** ✓；AC10 谓词 `Repaid=1` / 7 行证据表 / 5 条继承要求 / `[DEBT]=9`（base 归档账本 = 8，不减少）**全部独立复现通过** ✓；AC9② 两条谓词 exit 1（无输出）✓；AC9③ 已登记 ✓；AC11 两条 `[U]` 第 5/6 项文本**逐字相等 = True/True** ✓；测试计数 9+11+14+8 = **42** 与 §A 一致 ✓。

## Review Verdict

**不通过（Request Changes）** —— 2 条 [Product Blocking]。实现主体（参数集硬门、plan/execute 两相、单校验谓词、白名单删除语义、逐目标备份、部署后逐文件哈希核验、42 用例常驻套件、`-Force` 无关的隔离互锁）质量高、负向对照真实、账目大体诚实（AC10 第二笔明确拒绝宣告已偿还，是本轮最值得肯定的一点）。但**冻结验收有一条机械谓词客观失败且被闸门记成 Pass**，另有**一条冻结的汇总输出要求未实现且无测试覆盖**，故不得进入收敛。

## Blocking Issues

### B-1 [Product Blocking] AC9① 的冻结谓词客观失败，而 HANDOFF 把「内容(第15维)」记为 Pass
`caused_by_last_fix: No`（首轮 9B，无上一轮 fix 输入）

* **具体反例（我独立实跑，非引用自述）**：`git grep -n 'IUnderstandThisReplacesLiveConfig' -- . ':(exclude)docs/ai/**'` → **6 处命中，exit 0**（`README.md:25`、`install.ps1:33`、`tests/install.Parameters.Tests.ps1:38/40/46/61`）。AC9① 冻结文本要求「**零命中**」，域 = 除 `docs/ai/**` 外全部，命中项全在域内。
* **具体后果**：① 冻结验收条款未满足；② `docs/ai/last_test_run.txt` §E **自己**把期望写成「预期零命中（exit 1）」，紧接着打印 6 行命中与 `exit code: 0`，却未标注失败；§结论 仍写「本轮无未跑项」；③ HANDOFF `Quality Gates` → 「内容(第15维) | **Pass** | AC9：§E/§F 的零命中」是**基于被自身证据推翻的假绿**——这正是本仓上一任务反复吃亏的失效模式。测试套件不含任何 AC9① 的机械断言，所以 42/42 全绿与这条失败**可以并存**。
* **Proposed Fix（二选一，须显式落账；不要静默重解释）**：
  * (a) **按冻结文本实现**：把 `README.md:25` 改写为不含字面量的表述（如「旧的确认开关已移除，带上它会在绑定阶段报错」），`install.ps1:33` 同改（用不含该字面量的机制名），`tests/install.Parameters.Tests.ps1` 用拼接构造令牌（如 `('-IUnderstandThis' + 'ReplacesLiveConfig')`）以免被 grep 命中；改完重跑该谓词，期望零命中/exit 1。
  * (b) **走人类 Amendment**：请人类裁决把 AC9① 的域收窄（例如允许「不再…/已移除…」类订正叙述，与 AC9② 的否定过滤同口径），把裁决与日期记入 TASK_BRIEF 的修订记录，并按新文本重跑记录。
  * (c) 无论选哪条，**同步订正** `HANDOFF.md` 的「内容(第15维)」证据行与 `last_test_run.txt` §E 的判定（当前为矛盾证据）。

### B-2 [Product Blocking] AC6 要求真部署汇总给出「未被部署的机器态清单」——真部署路径根本没有该输出，且无任何测试
`caused_by_last_fix: No`

* **具体反例（读 diff + 调用点枚举）**：`Get-MachineLocalReport` 全脚本只有两个调用点 —— `install.ps1:606`（`-ValidateOnly` 分支）与 `:619`（`-DryRun` 分支）。真部署路径（`:626`–`:653`）只跑 `Test-Plan` → 写循环 → `Show-Summary`，**从不打印** `[PRESERVE] … (machine-local, never touched)` 机器态清单。`Show-Summary` 也只输出计数。
* **具体后果**：AC6 的性质句冻结了「汇总同时给出插件步逐项结果与『未被部署的机器态清单』」。真部署的执行者（尤其 AC10 第二笔由**人类**对真实 `~/.dsh` 执行的那一次）在其部署日志里看不到机器态面清单，也就无法用该次运行自证「机器态未被指向」；而 `tests/install.Deploy.Tests.ps1` 的 AC6 四个用例只断言退出码、`[VERIFY]` 行、集合双向相等与计数，**该性质无任何用例覆盖**——属 9B 职责内的「遗漏入口」。
* **Proposed Fix**：在真部署路径（`Test-Plan` 通过之后、写循环之前或 `Show-Summary` 之前）调用 `Get-MachineLocalReport` 并逐行打印 `[PRESERVE] … (machine-local, never touched)`；同时给 AC6 增一条断言（真部署形态的 stdout 必须含 `<ClaudeDir>\settings.local.json … machine-local, never touched` 与 `.dsh\.credentials.yaml` 行），否则该性质仍是「实现说了、测试没说」。
* 注：`-DryRun`/`-ValidateOnly` 已有该输出（§B 可见），所以这是**真部署独有的缺口**，不是全局缺失。

## Non-Blocking Suggestions

1. **反向集合核对的白名单豁免比冻结闭集宽** —— `tests/install.Deploy.Tests.ps1:48-50` 用 `$leaf -like '*.yaml'`、`$leaf -eq 's.json'` 等**整类**豁免。可证伪反例：部署后往 `<tempHome>\.claude\rules\notes.yaml` 放一个残留文件，`Get-DeploySetProblems` 仍返回 0 问题——即「目标里没有源树之外的非白名单残留」对整类 `.yaml` 不具区分力。**Proposed Fix**：把整类豁免换成**逐样本绝对路径**豁免（只豁免 `New-TestCase -SeedTargets` 预置的那 6 个机器态样本），或改为断言「残留集合 == 预置样本集合」。
2. **枚举域不对称（实现 vs 验证）** —— `install.ps1` 的 `New-MirrorAction:154/157`、`Get-MirrorDelta:210/216`、`Test-Plan:337` 的 `Get-ChildItem` **均未带 `-Force`**，而测试反向枚举 `Get-ChildItem … -Force`（`install.Deploy.Tests.ps1:36`）。今天是空集（我实测源树与该机受管面**无 Hidden 属性文件**），但带 Hidden 属性的源文件不会被计划、复制或核验，带 Hidden 属性的目标残留不会被 `[DELETE]` 也不会被删。**Proposed Fix**：给上述四处补 `-Force`（并确认 `Copy-Item 'src\*'` 是否复制 Hidden 项，见 Verification Needed 3），或在脚本注释里显式声明「Hidden 属性文件不在镜像域内」。
3. **`TestHelpers.ps1:206-208` 的注释描述了未实现的隔离动作** —— 注释写「把 LOCALAPPDATA/APPDATA 指向同级临时目录」，紧随其后的生成代码（`:209-212`）**没有任何重定向**；`$Case.RuntimeDir`（`:135`）与 `$Case.ProgressLog`（`:139`）**全套件零引用**（我逐文件统计确认）。这正是「零写入」断言不得不从「整个临时 HOME」收窄到「三个目标根」的成因。**Proposed Fix**：删掉该陈旧注释与两个死字段，把 HANDOFF 已记录的实测理由（pwsh 宿主按 USERPROFILE 推导 known folder 并写 `<home>\AppData\…`，重定向 LOCALAPPDATA 实测无效）就地写成一行注释贴在被收窄的断言旁边。
4. **隔离互锁的 `-SkipInterlock` 是未使用的旁路** —— `tests/TestHelpers.ps1:192/213/249/254` 提供该开关，四个测试文件**无一处使用**（零引用确认）。它削弱了「本轮所有真部署都过互锁」这一可断言性。**Proposed Fix**：删除，或显式注明唯一合法用途（如 CLI-absent 分支用例，见 Test Coverage Gaps）与「使用时该轮审查作废」的判据。
5. **互锁/AC7⑦ 回显的是 wrapper 的期望值，不是安装器解析出的目标** —— `New-ChildWrapper:211` 的 `$targets` 来自 `$Case.*`/`OverrideTargets`，与传给安装器的 `@args` **无关联**；AC7⑦「回显三个解析后目标」因此是自指的。今天有下游判别力（隔离目标上做的集合/哈希断言会红），故非 Blocking。**Proposed Fix**：让真部署路径也回显生效的三个目标根（与 `[PLAN] targets …`/`[CHECK] targets …` 同形），并断言该行；或让 wrapper 从实际 argv 反解目标再断言。
6. **`$PluginNames` 与 `claude/settings.json` 的「必须同步」只有注释约束** —— `install.ps1:73-74` 声明同步，但没有任何测试比较二者；`Get-PluginsFromSource`（AST 读取）只核「是 6 个」。本任务正是因为这份硬编码清单陈旧才被立项（人类裁决补 `clangd-lsp`）。**Proposed Fix**：加一条用例，断言 `$PluginNames` 与 `claude/settings.json` → `enabledPlugins` 的键集合（去 `@claude-plugins-official` 后缀）**双向相等**——这是对同一根因最低成本的防复发门。
7. **空 `archive` 目录落入删除侧** —— `Test-PathKeepLocalOnly` 的段循环只检查「非末段」（`install.ps1:128-132`），故 `rel = 'archive'` 本身不保；完全空的 `archive/` 会被列入 `DeleteDirs` 并删除。可证伪反例：预置一个空 `<tempHome>\.claude\workflow\archive` → 真部署后该目录消失（有内容的档案不会，因传播逻辑兜住）。**Proposed Fix**：把「末段等于 `archive`」也判为 keep-local（或对白名单目录本身不做删除），使「archive/**」的父目录语义闭合。
8. **头注释未登记 `-NoPluginInstall`** —— `install.ps1` 头部注释块（`:1-34`）列出 `-DryRun`/`-ValidateOnly`/三个路径参数，`-NoPluginInstall` 仅出现在 `:189` 的行内注释。AC11(b) 若按「注释块」这一较严域解释则不通过（Author 的驱动按「全部注释」域，故报 none missing）。**Proposed Fix**：把六参数与 usage 一起写进头部注释块。
9. **HANDOFF 账目与措辞陈旧（窗口关闭后一次性订正）** —— ① `handoff_snapshot_sha` 仍写「待统一落账时由 Author 填写」，而 HEAD 已 = `e56451a8`；② `Quick-Version Fields` → 「Human Approval Evidence：待人类批准（Status 当前为 `Pending`）」与同文件 `approval_commit_sha: 77d3618e…（含 Status: Approved）` **自相矛盾**；③ `Fix-Loop Counter` 写「本任务尚未进入双审窗口」而 `Current Phase` 已是 `Independent Review`；④ `Current Phase` 段仍内嵌规划期文本（「现停在人类批准门…未获批准前本文件之后不动」）；⑤ `Remaining Risks / Debt` 的 `~/.dsh` 条目前缀用了 ✅，而正文明确「执行前不得预先宣告已偿还」。**Proposed Fix**：在双审窗口结束的 HANDOFF 落账 commit 中一次性改准，并把 ✅ 改为 ⏳/➖（AC10 第二笔未闭合）。

## Test Coverage Gaps

* **`claude` CLI 缺席分支（D3 的 `SKIPPED` + 退出码仍 0）零覆盖**：全部真部署用例都把 shim 前插并强制 `Get-Command claude` 指向 shim（前置约束 3③ 是硬门），故 `Invoke-PluginAction:551-554` 的「CLI not on PATH」分支从未被执行；而人类 D3 裁决的核心正是这条边界。可证伪最小检查见 Verification Needed 5。
* **AC9① 无任何 Pester 断言**：它只存在于手工 §E 里，这正是 B-1 能带着全绿套件漏出去的原因。建议把该 grep 直接做成用例（含 base 负向对照）。
* **AC6 的「机器态清单出现在真部署汇总」无用例**（= B-2）。
* **白名单样本只落在一个被镜像目录**：`archive/**` 与 `*.bak-*` 样本仅存在于 `claude/workflow`；`dsh/workflow`、`claude/rules`、`claude/commands`、两个 skill 镜像无样本，故「应用于**每个**被镜像目录」这一声称只有 1/6 的机械证据。
* **K9① （目录已存在）无专属样本**：只被 AC4/AC6 的预置树顺带覆盖，不构成独立判定。
* **AC8 的两条腿证据不完整**：§D 的 5.1 stdout 用 `...` 截断（无法核「完整 stdout 无乱码」），且「同一命令在 pwsh 7 下也退出 0」只由 §B 的 K2（参数不同）间接体现。

## Cannot Verify From Diff

* Pester 套件在本机真实通过（本轮禁止重跑；仅以 §A 产物为据，且 §A 退出码语义为「失败数」）。
* `Invoke-Pester` 的 `Run.Exit=$true` 是否真的终止宿主进程（HANDOFF 自报，未复跑）。
* `Copy-Item -Path <dir>\* -Recurse` 是否复制 **Hidden 属性**条目（需写操作才能实测，本轮禁止）。
* AC3 用例 2/3/4/5/6 与 §C/§D/§H/§I/§J 的**原始**命令输出：产物给的是 `%TEMP%\h3-verify.ps1` 驱动脚本的**汇总打印**，该驱动**不在仓库**，无法独立复核或重放。
* `IMPLEMENTATION_PLAN.md` 的 Human Approval Status 正文（未提供；仅据 HANDOFF 的 `approval_commit_sha` 陈述）。
* 真实受管面（`~/.claude`/`~/.codex`/`~/.dsh`）当前内容（我只做了与审查相关的只读枚举：该机受管镜像下无 Hidden 属性文件；未做全量哈希比对）。

## Verification Needed

1. **AC9① 原始判定重跑**（可证伪）：`git grep -n 'IUnderstandThisReplacesLiveConfig' -- . ':(exclude)docs/ai/**'; "exit=$LASTEXITCODE"` —— 当前应为 6 命中/exit 0；若按 Fix (a) 改完，期望**零输出且 exit 1**。把原始输出+退出码追加进 `last_test_run.txt`。
2. **真部署的机器态清单**（可证伪）：在 AC6 的临时夹具里跑一次真部署形态，断言 stdout 含 `[PRESERVE] <ClaudeDir>\settings.local.json (machine-local, never touched)`；当前**必然缺失**。
3. **镜像域对 Hidden 属性文件的边界**（可证伪，需写临时树）：`New-TestCase` 后 `attrib +h <tempHome>\.claude\rules\.keepme.md`（以及源树副本里同形文件）→ 真部署后检查：该残留是否出现在 `[DELETE]`、是否仍存在、`Get-DeploySetProblems` 是否报 `unexpected live-only file left behind`。三方结果会直接判定 Non-Blocking #2 该记 Suggestion 还是必须修。
4. **AC11 的冻结产物形式**：按 AC11「产物 = 两条 `Select-String` 的**完整输出 + 退出码**」重跑并原样落盘；(a) 的「已移除机制 / 刻意不做机制」**显式清单**须落在 `install.ps1` 的注释块内（当前只存在于仓外驱动，导致 `-File`/`-ExecutionPolicy` 这类宿主参数的豁免在仓内不可见、不可复核）。
5. **CLI 缺席分支**（可证伪，需 `-SkipInterlock` 或等价形态）：子进程内把 shim 目录与 `%APPDATA%\npm` 同时移出 PATH，跑真部署 → 断言 exit 0 且含 `[PLUGIN] <name> SKIPPED (claude CLI not on PATH)`、`skipped=<插件数>`。
6. **AC8 的完整 5.1 stdout**：把 §D 中被 `...` 省略的完整输出与 pwsh 7 下**同一命令行**的退出码一并贴入 `last_test_run.txt`。
7. **反向豁免的反例固化**：按 Non-Blocking #1 的建议在夹具里注入 `rules\notes.yaml` 残留，证明当前判定确实漏过（若确认，则该 Suggestion 升级为必修）。

## Debt Verdict

* **无新增暗账；两条 Blocking 必须本任务内修，不得转记 `[DEBT]`。** 若 Author 对 B-1 选择「等人类 Amendment」而非当场改，则必须落成带日期的显式裁决/债务条目，禁止用措辞绕过。
* **AC10 第一笔（`INSTALLER_GUARD` guard 债）账目成立**：`Repaid` 命中、7 行证据表与 5 条继承要求**逐条保留**、HANDOFF `[DEBT]` 由 8 增至 9（不减少）——三条谓词我独立复现全部通过；「删债当偿还」未发生。
* **AC10 第二笔（`~/.dsh` 首次自动部署）正确地未宣告偿还**：§H 负向对照 `*.bak-* = 0` 成立，HANDOFF/§结论 均写明「未执行 → 不得标已收敛 / Ready to Commit」。这是本轮最干净的一处账目，**不要**在修复过程中被顺手改绿。
* **新增 `[DEBT]`（无常驻守护有效性装置）**登记合理：trigger/Impact 具体，且 guard_effectiveness 在绑定表里记 N/A 而非假绿，与「不声称红→绿」一致。
* **证据层的一处「准暗账」**：`%TEMP%\h3-verify.ps1` 驱动不在仓库，而 §C/§D/§H/§I/§J 的判定只有它的汇总打印——按现有形态，下一个 Agent 无法区分「判定通过」与「驱动说判定通过」。这不是产品债务，但若不按 Verification Needed 4 补原始输出，就是一处**未登记的复核性缺口**。

## Recommended Next Step

1. 处置 **B-1**（按 Fix (a) 改文/构造令牌，或取得人类 Amendment），处置 **B-2**（真部署路径打印机器态清单 + 增 AC6 断言）。
2. 至少固化 Verification Needed 1、2、3、4、6 的真实输出并**追加**进 `docs/ai/last_test_run.txt`（不得覆盖既有内容），并**重跑冻结命令**确认 42/42 仍绿、仓根无 `testResults.xml`。
3. 一次性订正 Non-Blocking #9 的 HANDOFF 陈旧字段（`handoff_snapshot_sha`、Quick-Version 的审批行、Fix-Loop Counter、Current Phase 遗留段落）——按本工作流规则，若处置引入了新代码/测试改动，应**重跑一轮 9B**（`review_tip_sha` 随之更新，本轮 verdict 不能复用于新 tip）。
4. 之后才进 `/final-review` 收敛门；**人类动作（AC10 第二笔）** 仍须在收敛宣告之前按 runbook 对真实 `~/.dsh` 执行并落账——当前 `~/.dsh` 与仓内 `dsh/**` 逐字节一致这一前提，建议执行前再重跑一次只读比对确认。

## Requirement-Level Concerns

1. **AC9① 与 AC11(a) 互相冲突（冻结文本层）**：AC11(a) 明确要求 `install.ps1` 的注释里存在「**已移除机制**（逐项写替代物）」清单——被移除的机制名正是 `-IUnderstandThisReplacesLiveConfig`，即 AC11(a) 的判定**预期**该字面量出现在脚本注释中；而 AC9① 又要求它在 `docs/ai/**` 之外**零命中**。两条冻结条款不可能同时按字面满足。若 Author 选 Fix (a)（抹掉字面量），则 AC11(a) 的「已移除机制」类别实际变为空类别——请人类确认这是可接受的收窄，而不是下一轮再被判红。
2. **AC1/AC2/AC4 的「临时 HOME 递归内容哈希前后逐字节相同」按字面不可满足**：隔离 HOME 下 pwsh **宿主自身**会写 `<home>\AppData\Local\Microsoft\PowerShell\*`（Author 已实测，且我核对 `TestHelpers` 生成代码确认重定向未实现）。建议人类把该域明确为「三个部署目标根 + 临时 HOME 内的非宿主产物（附宿主产物允许清单）」，避免下一位 Reviewer 以「实现收窄了冻结条款」为由重复开账；同时这也解释了 Non-Blocking #3 的陈旧注释为何危险。
3. **AC6「汇总给出未被部署的机器态清单」缺少对应的判定方式文本**（B-2 的根因之一）：AC6 的判定方式五条里没有一条断言这句话，故它在冻结文本里是「性质有、谓词无」。建议补一条与 B-2 建议一致的判定方式，使性质可机械判。
4. **AC4「白名单（冻结闭集）应用于每个被镜像目录」与判定方式只落一个目录之间存在口径落差**：冻结文本把闭集说成全局不变量，判定方式却只在一个被镜像目录里放样本。建议要么在测试里对每个被镜像目录各放一组样本，要么把声称收窄为「在被镜像目录内按路径段/文件名匹配」并删去「应用于每个」的读法。
