# IMPLEMENTATION_PLAN.md — 切片 A（参数面 + 两条零写入路径）

> per-task 文件，Author 的正式实现计划。任务 = H3 重新拆任务后的**切片 A**；分支 `task/h3a-parameter-surface`，base `e9917a1`（= `main`）。
> 验收条款与 Frozen Acceptance 的唯一落点是 `docs/ai/TASK_BRIEF.md`（review-sensitive）；本文件不在该清单内。

## Goal

对齐 `TASK_BRIEF.md`：把 `install.ps1` 的参数面做成**绑定期硬门**（3 个 ParameterSet、6 参数、无位置绑定），落地 `-ValidateOnly`（前置校验、零写入）与 `-DryRun`（完整计划、零写入）两条路径，二者与真部署路径共用**同一个** `Test-Plan` 谓词；给出确定的退出码契约与 `[PLAN]` / `[CHECK]` / `[SUMMARY]` 输出契约；并交付常驻 Pester 套件覆盖 AC1–AC3。

## Summary

**推荐方案：单文件两相结构（plan → execute），切片 A 只实现 plan 相 + 谓词。**

1. `Build-Plan`：只读地扫描源树与目标树，产出**动作清单**——`copy-file`（单文件目标）、`seed-file`（`codex/config.toml` seed-only）、`mirror-dir`（把源目录内容镜像到目标；附**源文件/源目录相对路径清单**）、`plugin`（6 个插件名，**仅作计划数据**——本切片不执行）。
2. `Show-Plan`：打印 `[PLAN]` 行；对每个 `mirror-dir` 预先算出并打印 `[DELETE]`（源里没有且**非**白名单）/ `[PRESERVE]`（白名单）逐条绝对路径。
3. `Test-Plan`：**唯一**校验谓词——源是否齐备、目标形态是否可用、三根是否自冲突（**归一化后**比较）、动作目标是否落在源树内、是否落在机器态面内。`-ValidateOnly` 打印它的 `[CHECK]` 结果；真部署路径（切片 B）在写入前调用它。
4. **模式分流**：`-ValidateOnly` → 校验 + `[SUMMARY]`；`-DryRun` → 计划 + `[SUMMARY]`；**Deploy（无参数）在本切片只做"计划 + 校验 + 明确拒绝执行"**——打印计划与机器态清单后以非零退出并给出 `RESULT=REFUSED (deployment execution is slice B)`。**理由（防"静默空转"）**：切片 A 不含任何写入；让无参数调用**看起来成功**比拒绝更危险。这一取舍与 `TASK_BRIEF.md` AC1 的 K1 措辞一致（K1 只要求"**不因绑定而失败**"——它能进入主流程，失败原因是"本切片不执行部署"，而**不是**绑定诊断）。

**为什么不是别的做法**：
* *让 Deploy 静默返回 0* → 会造出"跑了一键命令却什么都没发生"的假成功（本仓两次假绿的同类风险）。**不采用。**
* *把切片 B 的写入实现一并做掉* → 违反切片边界（`TASK_BRIEF` 的 Non-Goals）。**不采用。**
* *把 plan 相做成"半成品写入"（只建目录）* → 破坏 AC2 的零写入，且给切片 B 留半态。**不采用。**

**Reuse-first 检索结论**：仓内无可用轮子（`tools/validate/lib/Common.ps1` 只有 validator 助手且该目录**已封存**、不得依赖；`tools/ac4-*` 与本题无关）。**参考而非免审**：停牌分支 `task/h3-installer-hardening` 的 `install.ps1`（627 行）与 `tests/**` 提供了已验证的形状（ParameterSet 写法、归一化根、`Test-PathInside`、签名比对、子进程互锁 wrapper），**可作起点，但带过来的每一行都必须落在本切片自己的 diff 与审查范围内**。不引入任何新依赖（Pester 6.0.1 为仓内既有测试框架）。

## Architectural Layers & Split Assessment

触及层 = **CLI/脚本 1 层** + 测试基建 1 层。< 3 层 → **N/A**。本切片本身就是 H3 拆分后的切片，不再二次拆分；它与切片 B/C/D 的回退边界互不重叠（本切片只新增"计划与校验"，不产生任何写入）。

## Frozen Acceptance（指针）

**唯一落点 = `docs/ai/TASK_BRIEF.md` → `Acceptance Criteria`（AC1–AC3 + 冻结输入域 K1–K9 + 执行前置约束 + 谓词冻结前实跑证据）。本节不复述条款**，只记实现期必须守住的边界：
* **本切片零写入**：任何模式下都不得创建目录、复制、删除或备份。`Test-Plan` 与 `Show-Plan` 只读。
* **谓词形态**：所有 grep/`Select-String` 谓词采用 `$_ -notmatch` / `Select-String -NotMatch`（**不得**用 `$_.Line` 过滤 `git grep` 的 String 输出——恒真，见 TASK_BRIEF 的 P3）。
* **K1 的语义**：无参数 → 能进主流程（非绑定失败）、打印计划与机器态清单、**以非零退出明确拒绝执行**（切片 B 才执行）。
* **互锁按冻结条款 ③ 完整实现（人类 2026-09-15 裁决 (a)）**：wrapper 在子进程内断言 ① 生效的 `$env:USERPROFILE`、② 解析出的三目标均为期望临时值且不在真实 home 之下、③ **`(Get-Command claude).Source` 指向 fake shim**。shim 的用途 = 隔离互锁 + 让 K8 的"不执行插件步"可判（断言 shim 日志为空）；插件步的执行语义仍属切片 C。**不得**删掉该断言。

## Current Architecture Understanding

* 本分支的 `install.ps1` = **main 版旧脚本**（126 行）：单一确认开关 `-IUnderstandThisReplacesLiveConfig`、guard throw、`Backup-IfExists`、mirror-replace（`Remove-Item` + `Copy-Item`）、`~/.dsh` 整树备份、5 个插件、裸 `Done`。**它会被本切片整体替换**（改写为 plan 相 + 谓词）。
* 停牌分支的 `install.ps1`（627 行）已实现过同一形状并提供已验证细节：ParameterSet 声明、`Get-NormalizedRoot`（含盘根保护）、`Test-PathInside`（`TrimEnd('\')` + `OrdinalIgnoreCase`）、`Get-MirrorDelta` 的 delete/preserve 分类、机器态清单与其**包含关系**检查、纯 ASCII 约束。
* 测试基建：本分支**没有** `tests/`；停牌分支的 `tests/{TestHelpers,install.Parameters,install.DryRun,install.Deploy,install.IsolatedHome}.Tests.ps1` 可作起点（本切片取前两者 + 新写的 Plan/Validate 用例；Deploy/IsolatedHome 属切片 B）。
* 已知环境事实（一手实测）：Pester 6.0.1；`Invoke-Pester -Configuration` 与 `-PassThru` 在 Pester 6 下**不能同时传**（开发期用 `Run.PassThru`，验收用冻结形态）；`Run.Exit=$true` 会终止宿主进程（故验收用子进程承载）；`get-FileHash` 5.1 可用；`[System.IO.Path]::GetFullPath` **保留尾分隔符**（故必须归一化）。

## Proposed Changes

| # | 文件 | 类型 | 计划内容 | 原因 / 风险 |
|---|------|------|---------|------------|
| 1 | `install.ps1` | **修改（rewrite）** | 参数块（3 ParameterSet / 6 参数 / 无 `Position`）；`Get-NormalizedRoot`、`Test-PathInside`、`Test-PathKeepLocalOnly`（`archive` **含末段** + `*.bak-*`）；`Build-Plan` / `Show-Plan` / `Get-MirrorDelta` / `Test-Plan` / `Show-Summary`；模式分流（Validate / DryRun / Deploy=拒绝执行）；纯 ASCII 头注释（含 6 个参数与"刻意不做"清单） | 本切片生产面主体。风险：5.1 兼容、ParameterSet 解析、路径归一化边界、`-File` 下的退出码 |
| 2 | `tests/TestHelpers.ps1` | **新增** | 每用例新建临时 HOME/目标树/假 repo 副本 + 用例后清理；`Get-TargetsSignature`（三个目标根的 relpath\|SHA256 清单）；只封装 `-File` 形态的子进程调用；**子进程内互锁 wrapper**（USERPROFILE + 三目标 + 哨兵文件，无 bypass 开关） | AC1–AC3 的共同基建；不含 `*.Tests.ps1` 后缀故不被 Pester 当容器 |
| 3 | `tests/install.Parameters.Tests.ps1` | **新增** | AC1：K2/K3 通过样本、K4 两形态、K5、K6（含干净样本）、K7、K8 绑定可接受，5 对同形配对 + 零副作用 + 互锁负向对照 | 7 行拒绝矩阵的常驻化（切片 A 部分） |
| 4 | `tests/install.Plan.Tests.ps1` | **新增** | AC2：`-DryRun` 零写入 + 计划完整性（`[PLAN]` 覆盖全部动作、`[DELETE]`/`[PRESERVE]` 双向、`[SUMMARY]` 存在）+ 哈希清单能检出写入的负向对照 | 计划相的可判定性 |
| 5 | `tests/install.Validate.Tests.ps1` | **新增** | AC3 的 7 条（假 repo 承载；含 K9③/⑤/⑥、机器态包含关系、去 `-ValidateOnly` 的执行路径同判定） | 单一谓词的可判定性 |
| 6 | `docs/ai/HANDOFF.md` | **修改** | 实现后填 Review & Test Binding（`review_tip_sha` / `tested_sha` / `review_sensitive_paths`）、Quality Gates、Work Log、`[U]` 第 6 项的履行记录 | `/implement` 阶段产物 |

**明确不改**：README / 根 `AGENTS.md` / `claude/rules/README.md` / `docs/ai/AUTHORITY_CONTRACT.md` / `docs/ai/DSH-LANDING-NOTES.md` / `docs/ai/INSTALLER_GUARD.md`（**切片 D**）；`tools/**`、`dsh/**`、`claude/**`、`codex/**`、`portable/**`；`install.ps1` 的部署路径集合本身（`Build-Plan` 的受管面与旧脚本一致，除整树备份按 H3 结论不复活——**本切片根本不执行备份**）。

## Risks & Edge Cases

1. **5.1 兼容**：ParameterSet 多 `[Parameter()]` 属性写法、`[System.IO.Path]::GetFullPath`、`Get-FileHash` 均在 5.1 可用；`-File` 下的退出码与诊断文案必须实测（AC 的 5.1 腿）。
2. **ParameterSet 解析**：`DefaultParameterSetName='Deploy'` 必须让 K1 落 Deploy 集；`-NoPluginInstall` 与三个路径参数需同时属三个集；K7 必须由参数集在**绑定阶段**拒绝——**不得**用体内检查。
3. **路径归一化边界**：尾分隔符（`C:\a\` vs `C:\a`）、盘根（`C:\` **不得** `TrimEnd` 成 `C:`）、大小写不敏感、UNC 前缀。**风险中**——AC3 的 ④ 直接针对它。
4. **"零写入"的度量域**：隔离 HOME 下 pwsh **宿主自身**会按 `USERPROFILE` 推导 known folder 并写 `<home>\AppData\Local\Microsoft\PowerShell\*`（实测：重定向 `LOCALAPPDATA` 无效）→ 故"零写入"只测**三个目标根**（AC 已按人类裁决如此措辞）。**风险低**（有据）。
5. **K1 不得静默空转**：Deploy 集必须**明确拒绝**并非零退出；测试要断言"失败原因**不是**绑定诊断族"。
6. **纯 ASCII / LF**：重写后 `(Get-Content -Raw install.ps1) -match '[^\x00-\x7F]'` 必须为 `False`；行尾 LF（**不要**用 `Set-Content`/`WriteAllLines` 造成 CRLF）。
7. **测试基建的隔离粒度**：每用例各建一套临时树，禁止跨用例复用（AC2 的"部署前已存在"与 AC3 的"把目标建成文件/目录"会互相污染）。
8. **探针纪律**：任何执行 `install.ps1` 的动作都必须在临时目标 + 临时 HOME 下，且**先确认被执行脚本的版本语义**（2026-09-15 事故；见 HANDOFF Known Issues）。

## Execution Steps

1. `docs/ai/TASK_BRIEF.md` 定稿（已完成）→ **9P 计划审**（`subagent` 前台 / `deepseek-official`·`deepseek-flash`·`high` / 零写入；prompt 内显式禁止任何执行型探针与 `-IUnderstandThisReplacesLiveConfig` 字面量）→ Author 逐条表态修订 → 记 `docs/ai/review_9P.md` → **人类批准门**（人类亲填 `Status: Approved` 并 commit）。
2. **测试基建先行**：写 `tests/TestHelpers.ps1`（含子进程内互锁与其负向对照），先让"互锁会拒绝"这条用例绿。
3. 实现 `install.ps1`：参数块 → 归一化/白名单/路径谓词 → `Build-Plan`/`Show-Plan`/`Get-MirrorDelta` → `Test-Plan` → 模式分流与 `Show-Summary`。
4. 写三个测试文件（AC1 / AC2 / AC3），逐条对应冻结条款与负向对照。
5. 清 probe → `wip(author)` commit → 确认 `review_sensitive_paths` 干净 → **针对该 commit** 跑冻结命令，输出落 `docs/ai/last_test_run.txt`（含 5.1 腿、ASCII 判据、每条谓词的实跑输出）→ 更新 `HANDOFF.md` → `docs(handoff)` 快照 commit。
6. 9B → 9A 双审（各自独立 `subagent`、零写入、prompt 内硬化禁令）→ Author 逐条处置 → `/final-review` 收敛门 → 人类 commit。
7. **本切片不做**：任何真实写入、插件步、部署后自检汇总、文档改准（分别属 B/C/D）。

## Testing Plan

真实存在的命令（均已实测形态）：

```powershell
# 主套件（切片 A；不落 testResults.xml）
pwsh -NoProfile -Command "$c = New-PesterConfiguration; $c.Run.Path = 'tests'; $c.Run.Exit = $true; $c.TestResult.Enabled = $false; Invoke-Pester -Configuration $c"

# 5.1 兼容腿（定义见 TASK_BRIEF 的 Amendment ㉔）：套件只在 pwsh 7 下运行；5.1 腿 = 以 powershell.exe 作**被测脚本的子进程宿主**（HostExe）。**不得在 powershell.exe 下跑 Pester**（本机 5.1 侧只有 Pester 3.4.0）。
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -DryRun `
    -ClaudeDir "$env:TEMP\h3a-claude" -CodexDir "$env:TEMP\h3a-codex" -DshDir "$env:TEMP\h3a-dsh"

# 纯 ASCII 判据（负向对照：在 base e9917a1 上同一判据返回 True）
(Get-Content -Raw install.ps1) -match '[^\x00-\x7F]'    # 预期 False

# 谓词形态（只读；禁止任何会执行安装器的探针）
git grep -n '<token>' -- install.ps1 | Where-Object { $_ -notmatch '<pattern>' }   # 正确形态（注意不是 $_.Line）
```

**守护有效性装置**：本切片对「机制 X 拒绝 Y」类声称（参数集拒绝、零写入、白名单保留、根冲突拒绝）一律提供**负向对照**，形态为"同一判定在对照样本上失败"。本仓**没有**常驻守护装置，故**不声称**「回归用例有效（红→绿）」的结构化产物（对应 `[DEBT]` 已在册）。**Author 不得自证**：负向对照由 Pester 用例在真实运行中触发（真实退出码），不是 grep 判红。

## Open Questions

**未解决问题：None。** 三处会改变结果的歧义已由人类 2026-09-15 裁决关闭：① 切片边界（A = 参数面 + 两条零写入路径，不做任何写入）；② Deploy 集在本切片的语义（**明确拒绝执行**，非静默返回 0——Author 在 Summary 里给出取舍理由，人类批准本计划即认可）；③ 零写入的度量域（三个目标根；宿主自产物不计）。其余实现级细节（函数划分、输出措辞）不构成 Unknown。

## Human Approval Status

* Status: Approved
* Approved by: [Dean]
* Date: [2026/09/15]

> 此字段任何 Agent 不得修改；Status 由人类批准时亲自改为 Approved——**先改 Status、再 commit**。批准正式凭证 = **内含 `Status: Approved` 的**人类 git commit（建议消息 `docs(plan): approve h3a-parameter-surface`）。非 Approved 禁止进实现。

## 9P round 1 整改纪要（人类 2026-09-15 裁决；权威条款见 `TASK_BRIEF.md` 的 Amendment ㉓–㉜）

* **B1（㉖）**：保留冻结的执行前置约束 ③ 全文（含 `claude` 解析断言与 fake shim），不收窄条款。
* **B2（㉓）**：机器态谓词用**冻结闭集 11 条**、**包含关系**判定；`~/.codex/config.toml` **不在闭集内**（受管 seed：缺失→播种、已存在→保留），AC2 需断言其期望（不得出现在 `[DELETE]`）；AC3 增补 `.claude\projects-x` 与 `.claude\projects.bak-20260101-000000`。
* **B3（㉕）**：AC1 的 K8 改**三样本**（两个绑定成功 + 负向对照 `-NoPluginInstall -DryRun -ValidateOnly` → 绑定失败），并断言 shim 日志为空。
* **B4（㉔）**：见上 5.1 腿定义；证据 = 每条 5.1 腿的实际宿主路径与退出码。
* **S1（㉘）**：`Get-TargetsSignature` 输出**目录行**（`d:<rel>/`），"无新建目录"因此可判（含空目录）。
* **A3**：AC2 增补"`[PLAN]` 的路径集合 == 旧脚本受管面清单"（逐个点名，含两个 skill bundle 与 `codex/config.toml` seed）——把"与切片 B 执行集合一致"变成域内可判。
* **S4（㉛）**：P1 保留为历史，实现后另记 **P1'**（同命令 → exit 0 + `[PLAN]`/`[SUMMARY]`）。
* **S5（㉚）**：输出契约前缀族一次冻结（`[PLAN]`/`[CHECK]`/`[DELETE]`/`[PRESERVE]`/`[SUMMARY]`）。
* **K1（㉗）**：Deploy 集明确拒绝执行并非零退出、输出不含绑定诊断族——该措辞已升进 TASK_BRIEF 的 Amendment。
