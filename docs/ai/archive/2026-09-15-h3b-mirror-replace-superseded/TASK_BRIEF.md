# TASK_BRIEF.md — 切片 B（真实写入路径）

> **⚠️ SUPERSEDED（2026-09-15 人类裁决）**：本文件写的是**已被放弃的 mirror-replace 方案**（含删除能力与 AC1–AC9 全套闸门）。人类裁决改为 **只增/只更新**（覆盖前逐文件备份、**永不删除**、本机独有内容只报告为 `[STALE]`），并**降档为 Routine**——因此本文件**不再是对齐目标**，其 Critical 规划仪式（9P 批准门、冻结验收、SHA 账本）随该方向一并停用。保留在册仅作历史与判据来源；实际落地见 `install.ps1` 与 `README.md` 部署节。
> **仍然有效**的部分：AC2 的白名单段级化结论（PROBE-D）与 `[STALE]`/`[PRESERVE]` 的判定口径；其余条款（备份/删除/`[SEAL]`/AC8 人类真部署产物）在只增/只更新语义下**不再适用**。

> **状态：`DRAFT — 待人类批准`**（不是冻结验收）。本文件由 Author 按 `/define` 起草；`Human Approval Status` 字段只由人类填写。
> 前置：切片 A 已按冻结验收收敛并 squash 合入 `main`（`ad2404e`）。本切片的输入清单 = `docs/ai/BACKLOG_sliceB.md` 的 §1（切片 B 语义）与 §2（需求裁决）；逐条处置状态见该文件 §6。
> **修订史**：round 1（9P Gap 1/3/4/5/6/7）→ **round 2**（`e9ed321`：AC2 执行期落点、AC4 ②③④、AC6/AC8 拆分、终止规则 8 条）→ **round 3**（`9b125aa`：按 round 2 的 Required-1..8 与 4 条 Non-Blocking 全量改写——U1 取代账目 + AC5 三条改写、U3 写死分支二 + 新增 AC9（含 round 1 Gap 2）、AC4 可判化（磁盘观测 + 独立预言机 + `[SEAL]` + TOCTOU）、AC3 并集锚（D7 采纳）、AC7 扩三根、AC1/D2 命名与唯一性一致、引用改准、债闸门落点实写、NB-2/NB-3/B-7 落条款）→ **本轮（round 3 verdict 后）**：AC2 判定②③ 升级为"实际删除集合 ∩ 白名单 == ∅"+ 逐字节存活（B3）、AC4② 写死"`Show-Plan` 在任何写入之前"与模式无关性（B1）、AC4③ 声明行来源并把文件面/目录面拆开（B2/NB-4）、AC3 点名四处并集落点（B4）、AC9 增逐模式落点表与切片 C 的失效条件（NB-2/Assumption-2）、AC8 写死产物位置（Assumption-3）。

## Goal（一句话）

让 `install.ps1` 在**保持 `-DryRun` / `-ValidateOnly` 零写入**的前提下，落地**真实部署路径**：逐目标备份 → mirror-replace 受管目录（删源树没有且非白名单者）→ 复制/播种 → 插件步（属切片 C，本切片只留调用点）→ 部署后自检汇总；并且**计划与实际执行的集合必须逐条一致**。

## Non-Goals（本切片明确不做）

* 插件步的真实执行与 CLI 缺席分支（**切片 C**）。
* 文档全面改准（README 部署节正文 / `INSTALLER_GUARD.md` / `DSH-LANDING-NOTES.md`）（**切片 D**）。
* 参数面语义变更（切片 A 已冻结：6 参数、3 ParameterSet、无参数 = Deploy 集）。
* 任何"顺手现代化"（`install.ps1` 保持 PS 5.1 兼容、纯 ASCII）。

## 为什么这个切片必须最严（风险陈述）

1. **它第一次真的删东西**：mirror-replace 会删除 `~/.claude/{rules,workflow,commands}` 等目录里"源树没有且非白名单"的内容。本仓已发生过两次真实事故——**一次就删掉 127 个本机独有文件**（82 个 `archive/**` + 45 个旧 `*.bak-*`），其中一类正是"白名单目录的内容被当成 live-only 删掉"。
2. **同族缺口今天就存在（2026-09-15 Author 只读实跑，PROBE-D）**：源树**自带** `*.bak-*` 目录时，目标侧同名目录内的本机独有文件当前被判 `[DELETE]`（对照样本：源树没有该同名目录时同型内容被 `[PRESERVE]`）。这是切片 A 冻结 AC2"白名单 = 子树继承"的**可复现违反**（样本集缺该形态），在写入路径下就是**真实误删**，与 2026-07-30 那 45 个旧 `*.bak-*` 同族。⇒ 本切片必须修（见 AC2 与计划 D8）。
3. **它触碰凭据邻居**：`~/.dsh/.credentials.yaml`、`~/.claude/.credentials.json`、`settings.local.json`；历史上"整树备份"因此**复制过凭据**。
4. **不可逆**：删除是最终动作，回滚只能靠逐目标备份。

## 验收（AC1–AC9；**待人类冻结**）

> 每条含：性质 / 适用范围 / 明确例外 / 判定方式（可复现命令形态 + 区分力对照）。判定命令一律在 `docs/ai/last_test_run.txt` 留真实输出与退出码。

* **AC1 备份先于任何写入，且备份本身可校验**
  * 范围：写入前，每个**将被覆盖或删除**的受管目标（将被 mirror-replace 的目录、将被覆盖的单文件）。**例外**：已存在且按 seed-only 保留的 `~/.codex/config.toml` **不备份**（它不被写入）。
  * 命名与布局：备份为**紧邻目标的 sibling** `<name>.bak-<YYYYMMDD-HHMMSS>-<guid6>`（`<guid6>` = 每次备份独立生成的 6 位小写十六进制；sibling 布局意味着备份永不落在任何 mirror 根的枚举范围内）。
  * 判定：① 每个此类目标旁恰有一个备份；② 备份内容 == 写入前该目标的签名（文件 = SHA-256，目录 = 整树签名）；③ **唯一性（择定：guid）**：同一目标在同一秒被备份两次 ⇒ 两个不同的备份名、两份各自可辨的内容，第二次**不得**写进第一次的备份内部；④ **布局校验**：目录目标的 `<bak>` 直接子项 == 原目标的直接子项（文件目标是单文件副本，只需 ②）。必须排除 `Copy-Item` 的"目标已存在则嵌套 `<bak>\<原目录>\…`"语义，实现方式自选但须有断言。
  * 本条措辞与计划 D2 完全一致。
* **AC2 白名单 = 子树继承（任一段命中），且在执行期强制**
  * 谓词：路径中**任一段** `-ieq 'archive'`，**或任一段** `-like '*.bak-*'` ⇒ 该路径及其**整棵子树** keep-local-only（现状只判 `archive` 段与 `*.bak-*` **叶名**，PROBE-D 证明这留下的缺口会真实误删）。
  * 无关大小写：白名单比较与计划内所有路径比较统一 `OrdinalIgnoreCase`（现状 `$Action.Files -contains $rel` 为大小写敏感）。
  * 执行期实现点：**真实删除只允许来自 `$Plan` 的 `[DELETE]` 行**；执行器**不得**采用"删掉 live-only 父目录"的捷径（PROBE-B：`Remove-Item -Recurse` 会吞掉白名单子树）。
  * 执行前硬校验三件套（任一不过 ⇒ **中止、非零退出、零写入**）：① **分区校验**——任何 `[DELETE] (dir)` 行不得是任何 `[PRESERVE]` 行的祖先；② **目标互斥**——不得存在两条动作，其目标相同或互为祖先/后代（现状只查根相等；样本：`-ClaudeDir <tmp>\a` + `-DshDir <tmp>\a\workflow` 会命中）；③ **根可写性**——每个有效根位于本地固定卷（显式 UNC `\\…` 直接 FAIL）且最长计划目标路径 < 260 字符（5.1 无长路径支持）。映射网络盘无法可靠识别，此限度如实写进头注释。
  * 判定：① `-DryRun` 计划中不含任何位于白名单子树内的 `[DELETE]` 行；② **实际删除集合 ∩ 白名单路径集合 == ∅**（集合断言，用 AC4③ 的**同一**磁盘观测函数取部署前后差；白名单集合 = 任一段 `archive` 或任一段 `*.bak-*` 的路径集合）；③ **逐字节存活**：对每个白名单路径 P，部署前后 `Get-TreeSignature(P)` 相等（9P round 3 B3：原措辞"驱动器签名差为空"既写错对象又配不上"逐字节存活"）；④ **区分力对照**（在 `$env:TEMP` 的 `install.ps1` 副本上注入，绝不改仓内文件）：把谓词改回"只看叶名" ⇒ **实际删除集合里出现白名单路径**，②③ 必红。
* **AC3 机器态闭集（11 项）永不被删/改/复制；锚 = 有效三根映射 ∪ 真实 home 映射（计划 D7，采纳 9P round 2 建议）**
  * 机器态面 = 把 11 条相对路径（`install.ps1` 的 `$MachineLocalPaths`）分别映射到**有效三根**与**真实 home**（`$env:USERPROFILE`）两套锚后的**并集（去重）**。
  * 同源要求：`Test-Plan` 的 `machine-local-untouched` 谓词与打印的 `[PRESERVE] … (machine-local, never touched)` 清单**必须来自这一个并集**（修 R-3：现状谓词锚 `$env:USERPROFILE`、报告锚生效根，二者不同源）。**实现落点（9P round 3 B4）**：并集由一个共享构造器产出，**四处**统一消费——谓词（`install.ps1:474-480`）与**三处报告调用点**（`:575`/`:586`/`:595`，今日都写死 `-HomeRoot (Split-Path -Parent $ClaudeRoot)`）；`Get-MachineLocalReport` 的 `-HomeRoot` 语义随之改为"真实 home 锚"（`$env:USERPROFILE`），**不再**由 `Split-Path -Parent` 推导（重定向根样本下后者给的是 `<home>\sub`，会同时丢锚且与屏上清单不一致）。
  * **例外**：`~/.codex/config.toml` 仅在缺失时播种、存在则保留。
  * 判定：① 同一用例内，测试侧独立算出的并集 == 屏上机器态行集合（集合相等，含**重定向根**样本：`-ClaudeDir <home>\sub\.claude` 与真实 home 锚不同源）；② 既有"目标落在机器态路径内 ⇒ FAIL"样本仍红；③ 真实部署后 11 项在**有效根**上的哈希全面不变。真实 home 一面在测试内**不可实跑**（interlock 禁止以真实 home 为目标），只由 ①（谓词同源）与 AC8 的人类产物覆盖——此限度如实记，不声称测试覆盖了它。
* **AC4 计划 == 执行（可判化）**
  * **D1 粒度（冻结）**：`[DELETE]` / `[PRESERVE]` 行维持切片 A 形状；`[PLAN]` 行形状**不变**（A3 的 `[PLAN]` 过滤器与切片 A 的 43 条断言不受影响）；逐文件明细走**本切片新增并冻结的 tag**：`[COPY] <target>`（**逐文件**：将被创建或内容变化的受管文件各一行）、`[SEED] <target>`（将真正播种的 seed-only 目标；**不**重复进 `[COPY]`）。mirror 行仍打印 `(N files)` 计数，`planned` = 计划动作数、不因新 tag 变化。
  * ① **由构造保证**：执行器只消费 `Show-Plan` 打印的那批计划行（含读侧 `Get-MirrorDelta` 产出的 `[DELETE]`/`[PRESERVE]` 行——行来源见 ③），**不**重新推导另一套删/留。
  * ② **计划封存**：`Show-Plan` **在任何写入之前**运行一次，其打印的全部计划行按顺序以 LF 连接、UTF-8 取 SHA-256，打印为 `[SEAL] sha256=<64hex>`。**顺序与模式无关性是本条的一部分**（9P round 3 B1）：执行器**不得**在写入之后重新打印计划行（AC4⑥ 的重校验同样不得打印），故 `-DryRun` 与真部署跑在同一 live 树上时计划行集合恒同 ⇒ seal **必须相等**；seal 不等即视为"计划行在写入后才被计算"的实现违规。seal 覆盖计划行文本（含绝对目标路径），只在同一台机器、同一 live 树内可比。
  * ③ **实际处理清单 = 磁盘观测，不由执行器自报**（9P round 3 B2：先声明**行来源**）：`[DELETE]`/`[PRESERVE]` 行来自读侧 `Get-MirrorDelta`，执行器**消费的就是这批行对象本身**（不另算一套）；因此目标侧 live-only **空目录**同样进 `[DELETE] (dir)`（2026-09-15 实测，PROBE-E），执行器必须真的删掉它。判定按**面**拆开：**文件面** = 部署前后 `-File -Recurse` 集合差 + 哈希变化者之并（与 `[DELETE]` 文件行、`[COPY]`/`[SEED]` 行**逐条相等**）；**目录面** = 部署前后目录集合差（与 `[DELETE] (dir)` 行**逐条相等**）。`-DryRun` 侧同一口径（`tests/TestHelpers.ps1:59-84` 的 `Get-TreeSignature` 把目录算进签名，故两个面必须分开取，不能混成一个集合）。机器态 `[PRESERVE]` 行不参与本比较；plugin 行见 AC9。
  * ④ **独立预言机**：`copy`/`seed`/mirror 的**期望**集合由**测试侧**独立枚举源树得出（`TestHelpers.Get-ManagedDeploySet` 家族），**不得**取自 `$Plan` 的计数或执行器自报（修 NB-4 自指）。
  * ⑤ **负向对照**：在 `$env:TEMP` 的 `install.ps1` 副本上故意让"执行集合 ≠ 计划行"（例如执行器多删一条）⇒ ③ 的相等断言必须变红（证明该断言有区分力）。
  * ⑥ **TOCTOU**：`Show-Plan`/seal 之后、**第一次写入之前**重新校验（`Test-Plan` + 重算 mirror delta 与计划行比对）；不一致 ⇒ 中止、非零退出、零写入（打印 `[CHECK] plan-drift FAIL …`）。**重校验不得重新打印计划行**（否则屏上出现两份 `[COPY]` 行、且 seal 失去"冻结一次"的含义）。
  * 判定：①seal 自洽（测试按屏上计划行重算 SHA-256 == `[SEAL]` 值）；② seal(dry-run) == seal(deploy)；③ 磁盘观测 == 计划行（逐条）；④ ⑤⑥ 的对照样本。
* **AC5 零写入模式回归 + 三条按 U1 改写（取代账目见下节）**
  * ① **43 条不动**：切片 A 的 46 条用例中，除下表三条外**断言逐字不变且全绿**（含 5.1 腿、K2–K9、A3 集合相等、分区不变式、两个计数器用例）。
  * ② **三条改写**（U1：无参数 = 真部署）：
    | 用例 | 旧断言 | 新断言 |
    |---|---|---|
    | `tests/install.Parameters.Tests.ps1:133-140`（K1a） | 显式临时目标 + 无模式开关 ⇒ 退出码 ≠ 0 + `RESULT=REFUSED` + 输出不含绑定诊断族 + 三目标根零写入 | 同参数 ⇒ **真部署**：退出码 **= 2** + `RESULT=PARTIAL` + 输出不含绑定诊断族（判别力保留）+ 受管文件在磁盘上确实落地（`CLAUDE.md` 等与源树一致） |
    | 同文件 `:142-152`（K1b） | 零参数运行 ⇒ 退出码 ≠ 0 + `RESULT=REFUSED` + 报告解析出的隔离根 + 零写入 | 零参数运行（子进程已重定向 `USERPROFILE`）⇒ **部署进临时 home**：退出码 = 2 + `RESULT=PARTIAL` + 报告解析出的根 == 隔离根 + 真实 home 路径不出现在输出 + 写入只落在临时 home 内 |
    | `tests/install.Host51.Tests.ps1:48-54`（refusal sample） | Deploy 集在 5.1 下退出码 ≠ 0 + `RESULT=REFUSED` | Deploy 集在 5.1 下**真部署**：退出码 = 2 + `RESULT=PARTIAL` + 文件确实落地（5.1 腿首次覆盖写入路径） |
    * 旁证：`K1c`（`:154-158`，同一 argv + `-DryRun` ⇒ 0 + `RESULT=OK`）**不变**，改写后仍是 K1a 的配对对照（DryRun=0/OK vs Deploy=2/PARTIAL）。
  * ③ **拒绝路径零写入升为硬要求**（BACKLOG B-6）：现在有真实写入路径，故"被前置校验拒绝 ⇒ 零写入"不再恒真——由 `tests/install.Validate.Tests.ps1` 的 case 7/10/11/12（Deploy 形态被拒）与 AC7/AC9 的样本共同钉住。
  * 判定：冻结套件命令（见计划 §6）真实执行、输出与退出码落 `docs/ai/last_test_run.txt`；三条改写后的用例必须**先红后绿**（旧断言下必红）。
* **AC6 恢复演练**
  * ① 播种 → 部署 → 用备份还原 ⇒ 目标树签名回到部署前；② **半写检测**：备份过程被打断（注入）⇒ 不得进入写入阶段；③ **中断点回滚**：执行中途失败 ⇒ 打印已完成/未完成清单 + 逐目标恢复命令，且该命令**字面可执行**（在临时 home 上照抄执行成功）。
* **AC7 显式空根必须在写入前失败（三根同型）**
  * `-ClaudeDir` / `-CodexDir` / `-DshDir` 任一被**显式传入**但为空串、空白串或 `$null`（判定用 `$PSBoundParameters.ContainsKey`）⇒ 在解析根**之前** FAIL：非零退出、**点名该参数**、零写入；**三种模式（Deploy / DryRun / ValidateOnly）行为一致**。
  * 判定：① **argv 面**（`-File` 调用，即真实使用面）：三根 × {空串, 空白串} = 六样本 × 三种模式 ⇒ 各自非零退出 + 参数名在屏上 + 零写入；② **进程内面**：`$null` 经 argv 送达时会退化成空串，故 `$null` 由**进程内调用**样本覆盖（子进程脚本内 `& '<installer>' -ClaudeDir $null …`，仍受 wrapper 的 interlock 与 `USERPROFILE` 重定向约束）× 三种模式；③ 对照样本：同一 argv 去掉该参数 ⇒ 正常（证明失败来自空值而非其它检查）；④ 变异对照：在 `$env:TEMP` 副本上移除该守卫 ⇒ 样本改为"部署进临时 home"（不会到真机，因 wrapper 已重定向 `USERPROFILE` 且 interlock 在位）。
* **AC8 首次真部署由人类执行（产物化）**
  * 人类在**真实目标树**上复核一次 `-DryRun` 全量输出（含逐文件 `[COPY]`/`[DELETE]`/`[PRESERVE]` 行与 `[SEAL]`），该输出存为**仓内证据**：该次运行 stdout 的完整副本（建议 `docs/ai/AC8_dryrun_<YYYYMMDD-HHMMSS>.txt`）+ 其 `[SEAL]` 值，AC8 以这两件产物判定，而非以过程陈述判定。
  * **runbook 注明**：本切片插件步未实现，故本次真部署**只覆盖文件面**，其 `RESULT` 必为 `PARTIAL`（AC9）——不得读成"部署全部完成"。
  * agent 全程不得对真实 home 运行安装器。
* **AC9 输出契约与退出码（本切片冻结）**
  * 退出码：`0 = OK`（仅 `-ValidateOnly` 校验通过、`-DryRun` 计划完成）、`1 = FAILED`（前置校验拒绝 / 执行期失败；宿主绑定失败亦为非零）、`2 = PARTIAL`（**文件面部署完成，但插件步 NOT IMPLEMENTED**）。**`REFUSED` 在本切片退役**。
  * **逐模式落点（9P round 3 NB-2：把 token 落到具体模式，不留歧义）**：

    | 模式 | `[SEAL]` 行 | `plugin step: NOT IMPLEMENTED (slice C)` 行 | RESULT / 退出码 |
    |---|---|---|---|
    | Deploy（无参数） | 打印（**任何写入之前**） | 打印（`[SUMMARY]` 区） | `PARTIAL` / **2**；前置校验或执行失败 ⇒ `FAILED` / 1 |
    | `-DryRun` | 打印 | **不打印**（没有部署发生；计划行本身仍标 slice C） | `OK` / 0 |
    | `-ValidateOnly` | **不打印**（该模式不调用 `Show-Plan`） | 不打印 | `OK` / 0 或 `FAILED` / 1 |

  * Deploy 路径**永远不可能返回 OK**：只要计划含 plugin 动作而执行体为空，汇总必须打印 `plugin step: NOT IMPLEMENTED (slice C)` 与 `RESULT=PARTIAL`（退出码 2）；`-NoPluginInstall` **不改变**该结果（该标志在切片 B 不改变磁盘事实）。
  * **本条自带失效条件（9P round 3 Assumption-2）**：切片 C 落地插件步后，"Deploy 永不返回 OK"作废并改为"完成 ⇒ OK / 失败 ⇒ FAILED"；**切片 C 的 brief 必须带一条与本切片对 ㉗ 同型的取代账目**（否则又会重演"活断言被静默证伪"）。
  * 新增并冻结的前缀：`[COPY]` · `[SEED]` · `[SEAL]` · `[WARN]`（`[PLAN]`/`[CHECK]`/`[DELETE]`/`[PRESERVE]`/`[SUMMARY]` 维持切片 A 语义）。`planned` 明确定义 = **计划动作数**（不含 plugin 动作），写进头注释（BACKLOG R-4）。
  * `-DryRun` 语义（BACKLOG B-7）：**不调用** `Test-Plan`、对"必被拒的计划"仍 `RESULT=OK`/退出 0；但必须附形状警告——当计划会被前置校验拒绝时，额外打印一行 `[WARN] plan shape: <n> pre-flight check(s) would fail; -DryRun does not gate on them`（不改变退出码与 RESULT；该行不在 `[SEAL]` 覆盖的计划行内）。
  * 判定：① Deploy 完成 ⇒ 2 + `PARTIAL` + `plugin step: NOT IMPLEMENTED` 在屏上；② 无任何 Deploy 路径打印 `RESULT=OK`（负向对照：把汇总改成 OK/0 ⇒ 用例必红）；③ `-DryRun`/`-ValidateOnly` 仍 0/1（43 条覆盖）+ 逐模式表逐格断言（`[SEAL]` / plugin 行 / RESULT 三列）；④ 非法计划下 `[WARN]` 行存在、合法计划下不存在（对照证明该行有区分力）。

## 取代账目：Amendment ㉗ / K1 由本切片的 AC5 取代（人类批准门需明确确认）

| 项 | 切片 A 冻结文本（归档，**不改**） | 切片 B 取代后 |
|---|---|---|
| K1 判定（`docs/ai/archive/2026-09-15-h3a-slice-a/TASK_BRIEF.md:74`，Amendment ㉗，同文件 `:137`） | 无参数 = Deploy 集 ⇒ ① 输出不含绑定诊断族 ② 退出码 ≠ 0 ③ 含 `RESULT=REFUSED` ④ 三目标根零写入 | ① 保留 ② 退出码 **= 2** ③ 含 `RESULT=PARTIAL` + `plugin step: NOT IMPLEMENTED (slice C)` ④ **三根被真实写入**（受管面与源树一致） |
| `tests/install.Parameters.Tests.ps1:133-140`（K1a） | 见 AC5 ② 表 | 见 AC5 ② 表 |
| 同文件 `:142-152`（K1b） | 同上 | 同上 |
| `tests/install.Host51.Tests.ps1:48-54` | 同上 | 同上 |

* **不是绕过**：㉗ 的冻结文本自身写明"切片 B 落地后才转为真执行"（归档 `:137`）。取代是该条款预告的下一步，不是事后改口。
* **不改归档**：`docs/ai/archive/2026-09-15-h3a-slice-a/**` 一字不动，切片 A 的五轮 verdict 与收敛结论按当时文本继续成立。
* **代价与替代保护（必须一并确认）**：本切片移除了切片 A"无参数永不写入"的保护，替代 = AC1（备份先于写入）+ AC2（白名单段级化 / 分区 / 互斥 / 根可写性）+ AC9（Deploy 不得返回 OK）+ AC8（人类先复核 dry-run 产物）。**没有这些替代项就不允许取代。**

## 输入裁决与落点（BACKLOG §1/§2 的处置；逐条状态另见 BACKLOG §6）

* **B-1**（`-ClaudeDir ''` 静默回落真机）→ **AC7**（三根同型，三模式一致）。
* **B-2**（`-contains` 大小写敏感）→ **AC2**（比较统一 `OrdinalIgnoreCase`）。
* **B-3**（源树自带同名 `archive`/`*.bak-*` 目录）→ **已复现**：`archive` 面无问题（PROBE-A）；`*.bak-*` 面**有缺口**（PROBE-D，见风险 §2）→ **AC2 + 计划 D8**。
* **B-4**（`[CHECK] plugin-cli` 恒真）→ 属**切片 C**（本切片只留调用点），保持 open。
* **B-5**（mirror 只有计数、无逐文件行）→ **AC4 的 D1 粒度**（`[PLAN]` 形状不变 + `[COPY]`/`[SEED]` 逐文件）。
* **B-6**（"部署形态零写入"近乎恒真）→ **AC5 ③**（升为硬要求，且现在有区分力）。
* **B-7**（`-DryRun` 无形状警告）→ **AC9**（`[WARN]` 行 + 语义冻结）。
* **R-1 / R-2**（切片 A 归档验收措辞的欠账：K7 不可满足的合取、执行前置约束② 的字面冲突）→ **不回溯改归档**；作为措辞欠账留在 BACKLOG（如需改准属切片 D 的文档面），本切片不据此改任何冻结条款。
* **R-3**（机器态锚不同源）→ **AC3 + 计划 D7**（并集锚，采纳 9P round 2 的建议）。
* **R-4**（`planned` 语义）→ **AC9**（写进冻结文本与头注释）。
* **R-5**（计划文件清单缺 `tests/install.Host51.Tests.ps1`）→ **计划 §3 已列出该文件**（AC5 ② 改写它的样本），授权范围可机械核对。
* **NB-2 / NB-3**（9P round 1：根可写性、目标互斥）→ **AC2 执行前硬校验 ②③** + 计划 §3/§6 的改动点与用例。

## 本切片的**审查终止规则**（8 条；拟一并冻结）

1. **Blocking 只认"冻结条款的可复现违反"**，且必须附**复现命令 + 期望 vs 实测**（含退出码/原始输出）。**没有复现证据的推演一律记 `Verification Needed`，不判 Blocking**。
2. **NB / Coverage Gap 一律进 backlog、不阻断收敛**；verdict 必须显式区分「违反冻结条款」与「可以更好」。
3. **纯文档轮不开审**（docs-only commit 不触发双审）。
4. **冻结后不得 amend 验收**：要改必须先明确「本轮 verdict 作废 + 重开一轮」，由人类批准；禁止边审边改。**作废轮照常占用轮次配额**（不许用"作废不算"续命）。
5. **同一 tip 才可双审**；生产面一改即作废。
6. **轮次上限**：本切片最多 **3 轮**（9P 不计）；第 3 轮仍出现 `caused_by_last_fix: yes` 的 Blocking ⇒ 按硬停出口处理（回退 / 重新拆任务），**不得再开例外**。
7. **`disputed` 需人类裁定**：Author 以 `disputed` 结案**必须**附实跑复现输出（命令 + 期望 vs 实测）；**人类未裁定前该条目保持 open**，不得据此判收敛。
8. **争议不分叉**：同一问题在两侧 verdict 中若结论相反，由人类裁定一次；裁定结果写进本文件（或计划的对应条目），后续轮次不得重开同一争点。

## 模式与批准

* **建议模式：Critical**（不可逆写入 + 触碰凭据邻居 + 部署/回滚核心）。启用 Critical **不等于**批准本文件；批准门仍按母本：人类亲填 `Status: Approved`。
* 本文件为草案；`## 验收` 一旦冻结，任何改动按终止规则第 4 条处理。
