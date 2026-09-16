# IMPLEMENTATION_PLAN.md — 切片 B（真实写入路径）

> **⚠️ SUPERSEDED（2026-09-15 人类裁决）**：本计划描述的是**已被放弃的 mirror-replace 方案**（删源树没有的文件 + AC1–AC9 + 冻结批准门）。人类同日裁决改为 **只增/只更新**（覆盖前逐文件备份、**永不删除**、live-only 内容只报告 `[STALE]`）并**降档为 Routine**（Author 改 → 人类扫 diff → 人类 commit，无交接仪式）。本计划因此**不再生效**：D1–D9、§5 步骤、§6 测试计划中与删除/`[SEAL]`/AC8 有关的部分均作废；`Human Approval Status` 保持 `Pending`（不再走批准门）。
> **仍然有效的复用**：D2 的"只备份被覆盖者、不做整树备份"（实际实现为**逐文件备份**）、D8 的白名单段级化（PROBE-D 缺口，已修）、PROBE-A/D/E 的实测结论、§10 的 9P round 3 表态与 VN 代跑结果（历史）。
> **实际落地**：`install.ps1` 的写入路径 + `tests/install.Deploy.Tests.ps1`（见 git 工作树与 `HANDOFF.md` 的 Work Log）。

> **状态：`DRAFT`** · `Human Approval Status`: **`Pending`（待人类亲填 `Approved`）**
> 上游：`docs/ai/TASK_BRIEF.md`（草案；候选冻结 = **AC1–AC9**）· 输入清单：`docs/ai/BACKLOG_sliceB.md` §1/§2（逐条处置状态见该文件 §6）
> 终止规则已生效（`TASK_BRIEF.md` 末节 **8 条**）：Blocking 只认可复现的冻结条款违反；NB/Gaps 进 backlog；文档轮不开审；不得边审边改；同一 tip 才双审；**3 轮封顶，不得再开例外**；`disputed` 需人类裁定；争议不分叉。
> **9P 状态**：round 1（7 Gaps）→ round 2（B1–B4 + Required-1..8 + 4 NB）→ **round 3**（规划文本 `9b125aa`，Plan Verdict = **修订后可批准**，4 条 Blocking B1–B4）——三轮均按「修法必附」逐条表态并落到本文件 §9/§10；verdict 全文与表态见 `docs/ai/review_9P.md`。
> **批准门一并确认的冻结清单**：D1–D9 + AC1–AC9 + 终止规则 8 条 + 取代账目（㉗/K1）+ 9P round 3 Assumption-2 的三点（`[COPY]` 逐文件 / `[SEAL]` 保留 / `RESULT=PARTIAL`+退出码 2 进冻结契约）+ `docs/ai/QUALITY_GATES.md` 在批准门前落地是否接受。
> 本计划**不改任何生产代码**；批准后才进入 `/implement`。

## 1. 设计（一句话）

写入路径 = **同一个 `$Plan` 的"执行器"**：`Build-Plan` → `Get-PlanCounters` → `Show-Plan`（形状不变）→ **`[SEAL]` 计划封存** → **`Test-Plan` 硬门** → **逐目标备份** → **执行前重校验（TOCTOU / 分区 / 互斥）** → **按 `$Plan` 顺序执行动作** → **部署后自检** → `RESULT=PARTIAL`。执行器**不重新推导**要删什么、要留什么：`[DELETE]`/`[PRESERVE]`/`[COPY]`/`[SEED]` 行与执行集合必须同源，否则 AC4 无法成立。

## 2. 关键设计决策（D1–D9；批准门一并确认）

| # | 决策 | 定稿 | 理由 |
|---|---|---|---|
| D1 | **AC4 粒度** | `[PLAN]` 行形状**不变**；逐文件明细走**新 tag**：`[COPY] <target>`（**逐文件**：将被创建或内容变化的受管文件各一行）、`[SEED] <target>`（将真正播种的 seed-only 目标，**不**重复进 `[COPY]`）；mirror 仍打印 `(N files)` 计数，`planned` 语义不变。**行来源**：`[DELETE]`/`[PRESERVE]` 行由读侧 `Get-MirrorDelta` 产出，执行器消费的就是这批行对象本身（不另算一套）——故 live-only **空目录**也进 `[DELETE] (dir)` 并被真的删掉（PROBE-E）。（9P round 2 Required-3 方案 (a) + round 3 B2/NB-3） | 选 (a) 则切片 A 的 A3 `[PLAN]` 过滤器（`install.Plan.Tests.ps1:154`）与 43 条断言不动、无需共用取代账目；(b) 会改 A3 断言并在同一轮里混入两处取代 |
| D2 | 备份范围与命名 | **只备份"将被覆盖或删除的受管目标"**（① 将被 mirror-replace 的目录 ② 将被覆盖的单文件；**不**做整树备份）；命名 `<name>.bak-<YYYYMMDD-HHMMSS>-<guid6>`，**sibling 布局** | 与 ㉗ 承诺一致、避免再复制凭据；PROBE-C 证明固定名字会同秒嵌套；sibling 保证备份永不落进任何 mirror 根 |
| D3 | 删除方式 | 按 `$Plan` 的 `[DELETE]` 集合**逐条删除**（深路径优先）；**永不**删除"live-only 父目录"这种捷径；目录行仅在该行本身是 `[DELETE] (dir)` 且分区校验通过时执行 | PROBE-B 实测 `Remove-Item -Recurse` 会吞掉白名单子树 |
| D4 | 失败语义 | 任一动作失败 ⇒ **立即停止**、非零退出、`[SUMMARY] RESULT=FAILED` + 已完成/未完成清单 + **逐目标恢复命令**（须在临时 home 上字面可执行） | 不可逆操作必须留可执行回滚指引 |
| D5 | 插件步 | 本切片**只留调用点**，执行体为空并标 slice C；与 D9 的 `PARTIAL` 绑定，**禁止"静默跳过却报成功"** | 插件步属切片 C（Non-Goal）；9P round 1 Gap 2 / round 2 Required-2 的分支二 |
| D6 | 空显式根 | `-ClaudeDir`/`-CodexDir`/`-DshDir` 任一被**显式传入**但为空/空白/`$null` ⇒ 解析根**之前** FAIL，点名参数，三模式一致 | BACKLOG B-1：写入路径下"空串回落真机" = 部署到真机 |
| D7 | 机器态锚（原"待人类裁决"） | **采纳 9P round 2 建议**：机器态面 = **有效三根映射 ∪ 真实 home 映射**（去重）；谓词与打印清单**同源于这一个并集** | R-3：谓词锚 `$env:USERPROFILE`(:475)、报告锚生效根(:575/:586) 不同源；并集是唯一让"护真机"与"护生效根"同时成立的写法 |
| D8 | 白名单段级化（**新，PROBE-D 证据**） | `Test-PathKeepLocalOnly` 改为：**任一段** `-ieq 'archive'` **或任一段** `-like '*.bak-*'` ⇒ 该路径及整棵子树 keep-local-only；同时把 `Get-MirrorDelta` 的 `-contains`(:220/:226) 统一为大小写不敏感比较 | PROBE-D：源树自带 `*.bak-*` 目录时，目标侧同名目录内的本机独有文件被判 `[DELETE]`——切片 A 冻结 AC2"子树继承"的可复现违反，写入路径下即真实误删 |
| D9 | 输出契约与退出码 | `0=OK` / `1=FAILED` / `2=PARTIAL`（部署完成但插件步 NOT IMPLEMENTED），**`REFUSED` 退役**；新增并冻结前缀 `[COPY]`·`[SEED]`·`[SEAL]`·`[WARN]`；`planned` = 计划动作数（不含 plugin）；`-DryRun` 不 gate 但打印 `[WARN]` 形状警告；**逐模式落点表见 AC9**（哪个模式打印 `[SEAL]` 与 plugin 行、RESULT/退出码各是什么）；本条**自带失效条件**：切片 C 落地插件步后作废，且切片 C 必须带同型取代账目 | 9P round 2 Required-1/2 要求"写死 token 与退出码"；round 3 NB-2 要求把 token 落到具体模式；Assumption-2 要求预留失效条件 |

## 3. 逐文件改动（指示性行号，实现时以实际为准）

**`install.ps1`（唯一生产文件）**

1. **债闸门清偿（§5 步骤 0，先做）**：删 `$script:Plan`(:112)、`$script:checkFailed`(:372，只写不读)、`$Roots`(:562)、首个 `$RootSpecs`(:543-547)；`Build-Plan` 的 skill 枚举(:191)从硬编码两常量改为 `Get-ChildItem (Join-Path $RepoRoot 'dsh\skills') -Directory`（HANDOFF:52 的 A3 自指债，trigger = "切片 B 落地 skill 枚举"）。
2. **白名单段级化（D8）**：改 `Test-PathKeepLocalOnly`(:125-141) 与 `Get-MirrorDelta` 的两处 `-contains`(:220/:226)。
3. **恢复/新增四个写入函数**（切片 A 故意删除；`:510-511` 的说明同时改写）：`Backup-TargetIfExists`、`Invoke-MirrorAction`、`Invoke-FileAction`、`Invoke-PluginStep`（空体 + slice C 注释）。`Invoke-MirrorAction` 消费**读侧 `Get-MirrorDelta` 产出的那批 `[DELETE]`/`[PRESERVE]` 行对象**（含 live-only 空目录行，PROBE-E），不另算一套。
4. **执行前硬校验**：`Test-Plan` 增 `target-mutual-exclusion`（两条动作的目标相同或互为祖先/后代 ⇒ FAIL）与 `target-roots-writable`（显式 UNC `\\…` ⇒ FAIL；最长计划目标路径 ≥ 260 ⇒ FAIL）；`Invoke-MirrorAction` 删除前做分区断言，不通过 ⇒ 中止、非零退出、零写入（深路径优先，D3/D4）。
5. **计划封存 + TOCTOU（AC4②⑥）**：`Show-Plan` **在任何写入之前运行一次**并收集自己打印的计划行 ⇒ `[SEAL] sha256=<64hex>`（Deploy 与 DryRun 都打印，`-ValidateOnly` 不打印）；Deploy 在**第一次写入前**重算 mirror delta 与计划行比对，不一致 ⇒ `[CHECK] plan-drift FAIL` + `RESULT=FAILED`——**重校验不重新打印计划行**（否则 seal 失去"冻结一次"的含义，且 `[COPY]` 行会重复）。
6. **`[COPY]`/`[SEED]` 行（D1）**：被创建或内容变化的受管文件逐条输出。
7. **Deploy 分支重写**：`Show-Plan` → `[SEAL]` → `Test-Plan`（失败 ⇒ FAILED/1、零写入）→ 备份（AC1）→ 执行（D3/D4）→ 部署后自检 → `RESULT=PARTIAL`(2)（AC9）。
8. **空根守卫（D6/AC7）**：三根 × {空串, 空白, `$null`} ⇒ 解析前 FAIL、点名参数、三模式一致。
9. **机器态并集锚（D7/AC3）**：抽一个共享构造器（建议 `Get-MachineLocalSurface -ClaudeRoot … -CodexRoot … -DshRoot … -HomeRoot $env:USERPROFILE`，返回"有效三根映射 ∪ 真实 home 映射"去重集），**四处统一消费**：谓词（`:474-480`）与**三处报告调用点**（`:575`/`:586`/`:595`——今日都写死 `-HomeRoot (Split-Path -Parent $ClaudeRoot)`，重定向根下会丢真实 home 锚）。`Get-MachineLocalReport` 的 `-HomeRoot` 语义改为"真实 home 锚"。（9P round 3 B4）
10. **`[WARN]` 形状警告（D9/B-7）**：`-DryRun` 仍不调 `Test-Plan`，但计划会被拒时打印一行。
11. **头注释**：改写为现状（本切片**已**落地写入）、退出码 0/1/2、`planned` 语义、UNC 限度、插件步属切片 C；保留 `-IUnderstandThisReplacesLiveConfig` 已移除的说明。纯 ASCII、5.1 兼容。

**`tests/`**

* **新增 `tests/install.Deploy.Tests.ps1`**：AC1–AC4、AC6、AC9 的判定用例（逐条见 §6）。
* `tests/TestHelpers.ps1`：加 `Get-BackupSignature`、`Invoke-RestoreRehearsal`、`Get-CopyRowSet`；`Get-ManagedDeploySet` 的 skill 臂(:285)改目录枚举；删死代码 `Test-PathInsideDirectory`(:86-96) 与 `Invoke-InstallerCase -Environment`(:242 + :246/:251 相关代码)。
* `tests/install.Parameters.Tests.ps1`：K1a(:133-140)/K1b(:142-152) 按 AC5② 改写；新增 AC7 的六样本。
* `tests/install.Host51.Tests.ps1`：refusal sample(:48-54) 改写为 5.1 下的真部署样本（AC5②）。
* `tests/install.Plan.Tests.ps1`：新增 A3 **区分力**用例（FakeRepo 内建第三个 skill bundle ⇒ 计划必须包含它；旧的硬编码实现下必红）+ `[COPY]`/`[SEAL]`/`[WARN]` 的形状与集合断言。
* `tests/install.Validate.Tests.ps1`：**不改**——其 case 7/10/11/12（Deploy 形态被拒 ⇒ 零写入）在写入路径下继续有效，正是 AC5③ 的承载。

**`docs/`**

* `docs/ai/last_test_run.txt`（实现期产物）、`docs/ai/HANDOFF.md`（实现期快照；含 `review_sensitive_paths`）。
* **`docs/ai/QUALITY_GATES.md` 已落地**（`9b125aa`，157 行：6 行来源头 + 逐字 scaffold 自 `dsh/workflow/QUALITY_GATES.md`，**未新增任何检查项**；`Compare-Object` 差集 == 那 6 行）。本切片**不再改动**它。9P round 3 记了一笔事实：它在**批准门之前**由规划 commit 落地；若人类认为"实现期 docs 先落"越界，请在批准门一并裁决（不影响本计划的技术成立性）。
* README / `AGENTS.md` / `INSTALLER_GUARD.md` / `DSH-LANDING-NOTES.md` **本切片不改**（属切片 D）；`install.ps1` 头注释随代码同 patch（属代码内文档）。

## 4. 风险与缓解

| 风险 | 缓解 |
|---|---|
| 重演"删掉 127 个本机独有文件" | ① AC2 分区/互斥/根可写性**执行前硬校验**；② 白名单**段级化**（D8，修掉今天可复现的 `*.bak-*` 缺口）；③ 所有删除只来自 `$Plan` 的 `[DELETE]` 行；④ 备份先于删除（AC1） |
| 备份复制凭据 | D2：只备份受管目标；备份内容断言只比对受管面 |
| 首次真部署不可逆 | AC8：人类先复核真实 `-DryRun` 全量输出（含 `[SEAL]`）；实现期只对**临时 home** 实跑 |
| 计划与执行漂移 | AC4：同源 `$Plan` + `[SEAL]` 封存 + 磁盘观测（非自报）+ 独立源树预言机 + TOCTOU 重校验 + 副本变异负向对照 |
| 插件步未落地被误读为已落地 | D5/D9：计划行标 slice C、汇总恒打印 `plugin step: NOT IMPLEMENTED (slice C)`、Deploy **永不返回 OK**（退出码 2） |
| 取代 ㉗ 被当成"悄悄放松" | `TASK_BRIEF.md` 的取代账目 + 人类批准门显式确认；归档不改；替代保护逐条列名 |

## 5. 执行步骤

0. **债闸门（开工前必须完成；trigger 已触发）**：清偿 **install.ps1 死代码 4 处**（`$script:Plan` / `$script:checkFailed` / `$Roots` / 首个 `$RootSpecs`）+ **tests 死代码 2 处**（`Test-PathInsideDirectory` / `Invoke-InstallerCase -Environment`）+ **A3/skills 常量自指**（生产侧与预言机侧改目录枚举 + 新增区分力用例）。证据要求：**收紧模式** `Select-String -Path install.ps1,tests\TestHelpers.ps1 -Pattern '\$script:Plan\b|\$script:checkFailed|\$Roots\b|Test-PathInsideDirectory|\$Environment'` **零命中**（9P round 3 VN-5 实测：9P 给的宽模式有假阳性——`\$Roots` 会命中 `$RootSpecs`、`-Environment` 会命中注释与 `[System.Environment]::`，故不能用作证据）+ 一条"`$RootSpecs` 赋值只剩 1 处"的行数断言 + 冻结套件全绿（三条改写之后）。**清偿与重新登记二选一，不得只声明**（9P round 2 B4）。
1. **人类冻结（当前所在步骤）**：D1–D9 + AC1–AC9 + 终止规则 8 条 + 取代账目 + 9P round 3 的 Assumption-2 三点（`[COPY]` 逐文件 / `[SEAL]` 保留 / `RESULT=PARTIAL`+退出码 2 进冻结契约）+ `docs/ai/QUALITY_GATES.md` 在批准门前落地是否接受。冻结后任何改动按终止规则第 4 条（占配额）。
2. **9P 计划审**：**round 1–3 已完成**（round 3 Plan Verdict = 修订后可批准，4 条 Blocking 已全部按「修法必附」表态并落到本文件 §10；verdict 全文与逐条表态见 `docs/ai/review_9P.md`）。9P 默认单轮、其轮次不计入双审上限；**是否再跑 round 4 由人类明示要求**。9P 的 blocking 不进 Fix-Loop。
3. **人类亲填** `IMPLEMENTATION_PLAN.md` 的 `Human Approval Status: Approved` + 批准 commit（**含** `docs/ai/review_9P.md`）。
4. `/implement`（顺序硬约束）：测试基础设施（备份签名 / 恢复演练 / `[COPY]` 行解析）→ 实现写入路径 → 冻结命令跑全绿 → 落 `docs/ai/last_test_run.txt` → `docs(handoff)` 快照（含 `review_sensitive_paths`）。
5. **9B / 9A 双审**（同一 tip + 同一快照；9B 先跑；终止规则生效）。
6. **人类按 AC8 复核**真实 `-DryRun` 全量输出（存仓内证据）→ 由人类执行首次真部署（本切片**只覆盖文件面**，`RESULT` 必为 `PARTIAL`）。**插件债（切片 C）与 `~/.dsh` 首次真部署债分列**：本条只偿还后者的一半（文件面），插件面仍 Unpaid。

## 6. Testing Plan（命令真实存在）

* 冻结套件（子进程承载 `Run.Exit`）：
  `pwsh -NoProfile -Command "$c = New-PesterConfiguration; $c.Run.Path = 'tests'; $c.Run.Exit = $true; $c.TestResult.Enabled = $false; Invoke-Pester -Configuration $c"`
* 5.1 腿：既有 `tests/install.Host51.Tests.ps1` 机制（`-HostExe (Get-WindowsPowerShellPath)`，子包装器自报 `psver`/`host`）。
* **AC5 的三条改写必须"先红后绿"**（旧断言下必红，新断言下绿）——这是该改写的证据，非推断。
* **守护样本的通用对照规则**：凡"机制 X 拒绝 Y"的样本，都配一个**副本变异对照**——把 `install.ps1` 复制到 `$env:TEMP`、在副本上移除该机制 X，断言"该样本此时**通过**（或行为按预期改变）"。副本变异**绝不改仓内文件**；所有用例都在子进程 wrapper 的 interlock 下运行（目标必须落在临时 home 内），故变异副本也到不了真实 home（空根守卫的对照即依赖这一点：变异后它会部署进临时 home，而不是真机）。
* 新增必测（**每条都要有负向对照**，按终止规则第 1 条；标注 AC）：
  1. **AC1**：备份存在且内容 == 写入前（逐目标哈希）；**唯一性**（同秒两次 ⇒ 两个不同名、互不嵌套）；**布局**（`<bak>` 直接子项 == 原目标直接子项）；seed 已存在时不备份。
  2. **AC2**：mirror-replace 后 live-only 已删、源树有者已更新、白名单子树**逐字节存活**；**PROBE-D 回归用例**（源树自带 `*.bak-*` 目录 + 目标侧同类目录内的 live-only 文件 ⇒ 必须 `[PRESERVE]`）；源树自带 `archive/` 同型样本（PROBE-A）；**PROBE-E 回归用例**（live-only **空目录** ⇒ 必须进 `[DELETE] (dir)` 且部署后磁盘上确实消失，目录面逐条对账）；**集合断言**：实际删除集合 ∩ 白名单路径集合 == ∅（用 AC4③ 的同一观测函数；9P round 3 B3）；**副本变异对照**（谓词改回只看叶名 ⇒ 实际删除集合出现白名单路径 ⇒ 必红）；分区不变式 + **互斥**（`-ClaudeDir <tmp>\a` + `-DshDir <tmp>\a\workflow` ⇒ 执行前 FAIL、零写入；变异对照：移除该检查 ⇒ 该样本通过）+ **根可写性**（显式 UNC ⇒ FAIL；变异对照同型）。
  3. **AC3**：机器态 11 项在有效根上部署后**哈希不变**；测试侧独立算出的**并集** == 屏上机器态行集合（含重定向根样本 `-ClaudeDir <home>\sub\.claude`，该样本下 `Split-Path -Parent` 会给出 `<home>\sub` ⇒ 必须看到"真实 home 锚"那一半）；既有"目标落在机器态内 ⇒ FAIL"样本仍红。
  4. **AC4**：seal 自洽（按屏上计划行重算 == `[SEAL]`）；seal(dry-run) == seal(deploy)（**这条同时是"计划行必须在写入前算"的机械证明**——9P round 3 B1）；**磁盘观测 == 计划行**：文件面（`-File -Recurse` 差 + 哈希变化者 vs `[DELETE]` 文件行 + `[COPY]`/`[SEED]` 行）与**目录面**（目录差 vs `[DELETE] (dir)` 行）**分别**逐条相等；源树预言机 == `[COPY]`/`[SEED]` 集合；**副本变异对照**（执行器多删一条 ⇒ 相等断言必红）；TOCTOU（写入前注入 live 树变化 ⇒ 中止、零写入、且屏上不出现第二份计划行）。
  5. **AC6**：恢复正常；备份半写注入 ⇒ 不进入写入阶段；中断点回滚清单 + 恢复命令**字面可执行**。
  6. **AC7**：argv 面六样本（3 根 × {空串, 空白串}）× 三模式 + 进程内面 `$null` × 三模式 ⇒ 非零退出 + 点名参数 + 零写入；对照样本（去掉该参数 ⇒ 正常）；变异对照（移除守卫 ⇒ 部署进临时 home，因 wrapper 已重定向 `USERPROFILE`，到不了真机）。
  7. **AC9**：Deploy 完成 ⇒ 退出码 2 + `RESULT=PARTIAL` + `plugin step: NOT IMPLEMENTED`；无 Deploy 路径打印 `RESULT=OK`（副本变异成 OK ⇒ 必红）；**逐模式落点表逐格断言**（Deploy/DryRun/ValidateOnly × {`[SEAL]` 行, plugin 行, RESULT/退出码}，见 `TASK_BRIEF.md` AC9）；`[WARN]` 行在非法计划下存在、合法计划下不存在。
  8. **AC5③**：`--DryRun`/`-ValidateOnly` 零写入（含 `*.bak-*` 全量比对）；被拒的 Deploy 路径零写入（既有 case 7/10/11/12）。
  9. 顺带落地（BACKLOG §3 非阻断项，各一行）：T-1（deploy 形态补 home 签名断言）、T-2（`.claude\projects.bak-20260101-000000` 样本）、T-3（seed 缺失分支用例）、T-5（DryRun 语义钉住）、T-6（`planned` 行级交叉核对）、T-11（空根样本）。
  10. 仍在 backlog（本切片不动，理由一句话）：T-4（正面机器态断言的部分由 AC3 判定①承载）、T-8（生产注释的枚举顺序前提随 §3 步骤 11 的头注释一并声明）、T-10（argv 逐字冻结样本）、T-12（断言 `*` 通配 vs 字面量——留待有含 `[` 的路径样本时）。

## 7. 决定（9P round 1/2/3 后定稿；批准门一并确认）

* **U1 无参数运行 = 真部署**（本切片的核心目标），**并且取代 Amendment ㉗/K1 的三条落地断言**。9P round 2 的 B1 成立：U1 直接证伪 `tests/install.Parameters.Tests.ps1:133-140`(K1a)、`:142-152`(K1b)、`tests/install.Host51.Tests.ps1:48-54` 三条**已落地**的冻结断言，而 AC5 又要求套件全绿——**不能**用"切片 B 是新任务、自有验收"绕过它。处置：AC5 改为"43 条不动 + 三条改写（逐条列旧/新）"，取代账目写在 `TASK_BRIEF.md`（含归档指针、㉗ 自身"切片 B 落地后才转为真执行"的原文、替代保护清单），并由人类在批准门确认。退出码契约（原 §3 步骤 5 的"待确认"）**写死**为 D9。
* **U2 / D1 粒度 = 9P round 2 Required-3 的方案 (a)**：`[PLAN]` 行形状不变，逐文件明细走新 tag `[COPY]`/`[SEED]`（不被 A3 的 `[PLAN]` 过滤器看见），故 43 条与 A3 集合相等断言**无需改写**；切片 A 已冻结的 `[PLAN]` 契约不回溯修改（其归档记录保持原样）。
* **U3 插件步 = 分支二（写死）**：plugin 行**不计入** AC4 的"计划==执行"；新增冻结条款 **AC9**：Deploy 完成 ⇒ `RESULT=PARTIAL` / 退出码 **2**（**不得 OK、也不得 FAILED**）+ 汇总恒打印 `plugin step: NOT IMPLEMENTED (slice C)`；`-NoPluginInstall` 不改变该结果。AC8 的 runbook 注明本切片跳过插件步。
* **D3 删除方式定稿**：逐条删除 `[DELETE]` 行，永不删除"live-only 父目录"；目录行仅在其本身被列为 `[DELETE] (dir)` 且分区校验通过时执行。
* **D4 失败语义定稿**：失败即停 + 已完成/未完成清单 + 逐目标恢复命令（AC6③ 要求字面可执行）。
* **D7 定稿（采纳 9P round 2 Recommended-3）**：机器态锚 = 有效三根映射 ∪ 真实 home 映射，不再留白。
* **引用改准（9P round 2 Required-5）**：本文件头部与 §5 的"首次真部署 = **AC8**"（原误写 AC6）、冻结清单 = **D1–D9 + AC1–AC9 + 终止规则 8 条**、`TASK_BRIEF.md` 的修订史补齐 round 2 的 Gap 2（U3）。

### Author 对 9P round 1 的逐条表态（保留）

| 9P 条目 | 表态 | 落点 |
|---|---|---|
| Gap 1 U1 未决 | **fixed（本轮按 B1 重写处置）** | §7 U1 + AC5 + 取代账目 |
| Gap 2 插件步静默成功 | fixed | D5/D9 + AC9 |
| Gap 3 AC1/D2 矛盾 | fixed | AC1 与 D2 同措辞 |
| Gap 4 AC2 无执行期落点 | fixed | AC2 + D3 |
| Gap 5 AC4 不可判/自指 | fixed | AC4 ①–⑥ + D1 |
| Gap 6 AC6 不可判 | fixed | 拆为 AC6（恢复演练）+ AC8（首次真部署，产物化） |
| Gap 7 R-3 未决 | fixed | D7（并集锚） |
| Required-1 U1–U3 提前定稿 | fixed | §7 |
| Required-2/3/4 AC4/AC2/恢复演练增补 | fixed | AC4 / AC2 / AC6 |
| Required-5 终止规则两漏洞 | fixed | `TASK_BRIEF.md` 终止规则第 4/7/8 条 |
| Required-6 B-3 复现 + B-6/B-7 落条款 | fixed | §8 PROBE-A/D + AC5③ + AC9 |
| Required-7 空根进 AC | fixed | AC7（三根 × 三模式） |
| NB-1 备份唯一性 | fixed | AC1③④（择定 guid） |
| NB-2 长路径/UNC、NB-3 同目标双动作互斥 | **fixed（本轮实写）** | AC2 执行前硬校验 ②③ + §3 步骤 4 + §6 用例 2 |
| NB-4/NB-6/NB-7 | fixed | AC4④ / §2 / §3 |
| Debt：install.ps1 死代码（trigger 已触发） | **fixed（本轮实写落点）** | §5 步骤 0 |
| Debt：A3/skills 预言机自指（trigger 与切片 B 匹配） | **fixed（本轮实写落点）** | §5 步骤 0 + §6 用例 2/A3 区分力用例 |

## 8. 9P 点名的取证结果（Author 实跑，2026-09-15；只读 + 临时目录/wrapper；全部在 `$env:TEMP`，仓内零写入）

**PROBE-A（BACKLOG B-3：源树自带 `archive`/`*.bak-*` 时，目标侧同名目录里的本机独有内容归属）**

```
$ … -DryRun（FakeRepo + 源树注入 claude/workflow/archive/src.md；目标侧注入 workflow/archive/local-only.md）
EXIT=0
  [PRESERVE] …\.claude\workflow\archive\local-only.md      ← 目标侧 live-only 内容被保留（非 [DELETE]）
  [PRESERVE] …\.claude\workflow\archive\old\e.md
  [PRESERVE] …\.dsh\workflow\archive (dir)
```
* `archive` 面结论：**担忧不成立**——白名单按**路径段**判定，与源树是否也有同名目录无关。

**PROBE-D（round 2 Non-Blocking 点名补齐的样本：`*.bak-*` **目录**形态）**

```
$ 源树自带 claude\workflow\old.bak-20260101-000000\src.md
  目标侧 .claude\workflow\old.bak-20260101-000000\local-only.md      ← 同名目录，源树也有
  目标侧 .claude\workflow\keep.bak-20260101-000000\local-only.md     ← 同名目录，源树没有（对照）
EXIT=0
  [DELETE]   …\.claude\workflow\old.bak-20260101-000000\local-only.md
  [PRESERVE] …\.claude\workflow\keep.bak-20260101-000000\local-only.md
  [PRESERVE] …\.claude\workflow\keep.bak-20260101-000000 (dir)
```
* 结论：**缺口成立**——`*.bak-*` 只按**叶名**判定，故"同名 `*.bak-*` 目录存在与否"改变了同型内容的归属；源树自带时目标侧本机独有文件被判 `[DELETE]`。这是切片 A 冻结 AC2"子树继承"的**可复现违反**（样本集缺该形态），也是 2026-07-30 那 45 个旧 `*.bak-*` 的同族事故。⇒ D8 + AC2 判定③。

**PROBE-B（9P VN-2：整目录递归删除会不会吞掉白名单子树）**

```
建 parent\{archive\keep.md, stray.md} → Remove-Item parent -Recurse -Force
whitelisted_child_survived=False
```
* 结论：**会吞** ⇒ 执行器绝不采用"删掉 live-only 父目录"的捷径（D3/AC2）。

**PROBE-E（9P round 3 VN-2：live-only 空目录是否进 `[DELETE] (dir)`）**

```
$ 目标侧 .claude\rules\empty-live-only\（空）+ .claude\rules\has-file\x.md，-DryRun
EXIT=0
  [DELETE]   …\.claude\rules\has-file\x.md
  [DELETE]   …\.claude\rules\empty-live-only (dir)
  [DELETE]   …\.claude\rules\has-file (dir)
```
* 结论：**进**——`Get-MirrorDelta` 读侧会为 live-only 空目录产出 `[DELETE] (dir)` 行。故 D1 必须声明"执行器消费的就是这批行对象本身"，否则按"只消费 `$Plan`（源树侧）的行"的字面理解会出现"行在计划里、执行器不删"的永久不一致（9P round 3 B2）。同时确认：文件行与目录行会同时出现（`has-file\x.md` 与其父目录 `has-file (dir)`），故 AC4③ 必须**文件面/目录面分别对账**，且 D3 的"深路径优先"保证文件先删、目录后删。

**PROBE-C（9P VN-3：同秒备份命名唯一性与 `Copy-Item` 布局）**

```
stamp='yyyyMMdd-HHmmss' 同名备份连做两次（第二次前源内容改为 v2-changed）
layout_flat=True  layout_nested=True
content: \a.md=v1 | \workflow\a.md=v2-changed
```
* 结论：同秒第二次**不覆盖也不报错**，而是因"目标已存在"变成**嵌套布局**（`<bak>\<原目录>\…`）⇒ AC1 的唯一性（guid）与布局校验（D2）。

## 9. Author 对 9P round 2 的逐条表态

### Blocking（B1–B4）

| 9P round 2 | 表态 | 落点 |
|---|---|---|
| **B1** U1×AC5（证伪已落地的冻结断言） | **采纳**（原 round 1 的"new task 不回溯"抗辩**撤回**） | AC5 三条改写 + 取代账目 + §7 U1 |
| **B2** U3 未择一，且分支一与 AC6/AC8 互斥 | **采纳** | §7 U3 写死分支二 + AC9 |
| **B3** U2/D1 从严×AC5/A3（活测试钉住 `[PLAN]` 契约） | **采纳** | §7 U2 取方案 (a)（D1） |
| **B4** 债闸门无落点（§5 无步骤 0） | **采纳** | §5 步骤 0（实写，含证据要求） |

### Required Before Approval（1–8）

| # | 要求 | 表态 | 落点 |
|---|---|---|---|
| 1 | U1：AC5 改 43+3 并逐条列旧/新；删"待确认"写死退出码 | 采纳 | AC5② + 取代账目 + D9 |
| 2 | U3：写死分支二；AC4① 豁免 plugin 行；新增 token/退出码条款；AC8 runbook 注明跳过插件步 | 采纳 | AC9 + AC4③ + AC8 |
| 3 | U2/D1：二选一，推荐 (a) | 采纳 (a) | D1 + §7 U2 |
| 4 | AC4①/②：实际清单 = 磁盘观测，定义独立预言机与注入检测（封存/哈希） | 采纳 | AC4③④⑤⑥ + D9 的 `[SEAL]` |
| 5 | 引用改准（AC6→AC8、冻结清单补 D7/AC7/AC8、终止规则 8 条） | 采纳 | 本文件头部/§5/§7；`TASK_BRIEF.md` 修订史 |
| 6 | AC1/D2 一致：命名 `<…>-<guid6>` + 布局校验；AC1③ 真择一 | 采纳（择定 guid） | AC1③④ + D2 |
| 7 | AC7 扩到三个根 | 采纳 | AC7 + D6 |
| 8 | 债闸门实写 | 采纳 | §5 步骤 0 |

### Non-Blocking（4 条）

| # | 条目 | 表态 | 落点 |
|---|---|---|---|
| 1 | §8 PROBE-A 的 `*.bak-*` 目录形态样本缺失 | 采纳（已实跑） | §8 PROBE-D + AC2 判定③ + §6 用例 2 |
| 2 | NB-2/NB-3 表态 accepted 但 §3 无条目 | 采纳 | §3 步骤 4 + §6 用例 2（AC2 硬校验 ②③） |
| 3 | 修订说明漏列 Gap 2（U3） | 采纳 | `TASK_BRIEF.md` 修订史 |
| 4 | §5 步骤 6 把插件债与 `~/.dsh` 债并成一条 | 采纳 | §5 步骤 6（分列） |

### Debt Verdict 相关

| 9P 条目 | 表态 | 落点 |
|---|---|---|
| install.ps1 死代码债 trigger 已触发 | 采纳：**本切片开工前清偿**（不是重新登记） | §5 步骤 0 |
| A3/skills 常量自指债 trigger 匹配 | 采纳：**本切片清偿**（生产侧 + 预言机侧改目录枚举 + 区分力用例） | §5 步骤 0 + §6 用例 2 |
| `~/.dsh` 首次真部署债 | 承认仍 **Unpaid**：本切片只把"文件面可执行"补齐，真人执行在 AC8 | §5 步骤 6（分列） |

## 10. Author 对 9P round 3 的逐条表态（Plan Verdict：修订后可批准）

### Blocking（B1–B4）

| 9P round 3 | 表态 | 处置与理由 |
|---|---|---|
| **B1** `[COPY]` 内容条件 与 `[SEAL]` 跨模式相等"互相矛盾" | **修改后采纳**（修法成立，"必然失败"的结论不成立） | 反证：今日代码顺序已是 `Show-Plan`(`:596`) → `Test-Plan`(`:597`) → 若通过再写入，DryRun 同理(`:587`)——计划行**在写入之前**产生，故两模式在同一 live 树上行集合恒同。AC4② 现在把这一点写成要求（"`Show-Plan` 在任何写入之前运行一次、不得在写入后重印计划行、⑥ 的重校验也不得打印"），并以"seal 必须相等"**反向锁死**该顺序。**未采纳**其"seal 只覆盖 `[PLAN]`/`[DELETE]`/`[PRESERVE]`、排除 `[COPY]`/`[SEED]`"的方案——那会削弱封存面；逐文件面本来就由 AC4③ 的磁盘观测与 AC4④ 的源树预言机独立承担。 |
| **B2** live-only 空目录的落点悬空 | **修改后采纳**（真问题是措辞歧义，不是必然失败） | 实跑 PROBE-E：空 live-only 目录**确实**进 `[DELETE] (dir)` ⇒ 读侧 `Get-MirrorDelta` 已覆盖。D1 与 §3 步骤 3/4 现在明写"执行器消费的就是这批行对象本身（不另算一套）"；AC4③ 增"文件面/目录面分别对账"；§6 增 PROBE-E 回归用例。**未采纳**其"把删除面限定为文件面"的方案 (b)——那要删掉现有能力且仍留不一致。 |
| **B3** AC2 判定②③ 证明不了"白名单子树不被删" | **采纳** | 原措辞"驱动器签名差为空"确系写错对象（部署必然改变整树）。AC2 判定② 改为集合断言 **实际删除集合 ∩ 白名单路径集合 == ∅**（与 AC4③ 共用同一观测函数）；③ 改为对每个白名单路径 P 的 `Get-TreeSignature(P)` 前后相等；④ 变异对照升级为"实际删除集合里出现白名单路径 ⇒ 必红"。 |
| **B4** 并集锚的落点有 4 处（不只 2 处） | **采纳** | 实跑确认 `:575`/`:586`/`:595` 三处调用点都写死 `-HomeRoot (Split-Path -Parent $ClaudeRoot)`（重定向根下给 `<home>\sub`，真实 home 锚丢失）。§3 步骤 9 改为"共享构造器 + 四处消费"，AC3 与 §6 用例 3 同步写明 `-HomeRoot` 语义改为真实 home 锚。 |

### Non-Blocking（4 条）与 Assumption Challenges（3 条）

| 条目 | 表态 | 落点 |
|---|---|---|
| NB-1 §3 的 docs 一节过期（`QUALITY_GATES.md` 已在 `9b125aa` 落地） | 采纳 | §3 docs 改准为"已落地、本切片不再改"（越界与否交批准门裁决） |
| NB-2 `[SEAL]`/plugin 行的打印模式未冻结 | 采纳 | AC9 新增**逐模式落点表**（3 模式 × 3 列）+ §6 用例 7 逐格断言 |
| NB-3 `[COPY]` 枚举范围与 `planned` 关系 | 采纳 | D1：`[COPY]` **逐文件**、`[SEED]` 不重复进 `[COPY]`、`planned` 语义不变 |
| NB-4 观测口径与 `Get-TreeSignature` 含目录的短板 | 采纳 | AC4③ 把文件面/目录面**分别**取差并各自对账，点名 `TestHelpers.ps1:59-84` 的事实 |
| AC-1（AC2 判定② 太弱） | 采纳（由 B3 的修法消解） | AC2 判定②③ |
| AC-2（冻结验收有"从实现反推"迹象；建议批准门确认三点 + 给切片 C 预留失效条件） | 采纳 | ①`[COPY]` 逐文件已写死；②`[SEAL]` 保留，其判据价值 = 跨模式相等（这条同时是"计划行在写入前算"的机械证明），理由写进 D9/AC4②；③AC9 已写成**自带失效条件**并要求切片 C 带同型取代账目。**三点仍请人类在批准门确认。** |
| AC-3（AC8 的 seal 存档位置） | 采纳 | AC8 写死产物 = 该次 stdout 完整副本 + `[SEAL]` 值 |

### Verification Needed 代跑结果（Author，2026-09-15；只读 + 临时目录，仓内零写入）

| VN | 命令（要点） | 实测 | 结论 |
|---|---|---|---|
| 1（B1 机制） | `Select-String install.ps1 -Pattern 'Show-Plan\|Test-Plan -Plan'` | Deploy：`:596` Show-Plan → `:597` Test-Plan；DryRun：`:587` Show-Plan | seal 机制尚未实现（切片 B 未写），无法实跑 seal 值；但"计划行先于任何写入"的顺序**今日已成立** ⇒ B1 的"必然失败"不成立，已按"把这个顺序写死 + 用 seal 相等反向锁死"处置 |
| 2（B2 空目录） | 临时 FakeRepo + `-DryRun`，目标侧建空 live-only 目录与含文件的 live-only 目录 | `EXIT=0`；`[DELETE] …\empty-live-only (dir)`、`[DELETE] …\has-file\x.md`、`[DELETE] …\has-file (dir)` | 空目录**进计划**（PROBE-E）；B2 属措辞歧义，已按"行来源声明"修死 |
| 3（B4 调用点） | `Select-String install.ps1 -Pattern 'Get-MachineLocalReport' -Context 0,1` | `:575`/`:586`/`:595` 三处，全部 `-HomeRoot (Split-Path -Parent $ClaudeRoot)` | B4 成立，已修 |
| 4（归档原文） | 读 `docs/ai/archive/2026-09-15-h3a-slice-a/TASK_BRIEF.md:74` / `:137` | `:74` = Amendment ㉗ 的 K1 判定四项；`:137` 含"…（`RESULT=REFUSED (deployment execution is slice B)`）；**切片 B 落地后才转为"真执行"**" | 取代账目两处引文**逐字属实**，VN-4 闭合 |
| 5（债闸门证据形态） | 9P 给的宽模式 vs 收紧模式各跑一次 | 宽模式假阳性：`\$Roots` 命中 `$RootSpecs` 8 行、`-Environment` 命中注释与 `[System.Environment]::` 4 行；收紧模式零假阳性、正好 6 处死项 | 步骤 0 的证据改用收紧模式 + `$RootSpecs` 赋值计数断言（已改 §5 步骤 0） |
| 6（QUALITY_GATES 溯源） | `git show 9b125aa --stat -- docs/ai/QUALITY_GATES.md` + `Compare-Object` | 157 行新增、已跟踪；差集 == 6 行来源头 | 逐字 scaffold，未偷带判据改动 |
