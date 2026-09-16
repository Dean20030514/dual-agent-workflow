# IMPLEMENTATION_PLAN.md

> per-task 文件，Author 的正式实现计划。
> 任务 = **H3 · Installer Hardening**；分支 `task/h3-installer-hardening`；base `e9917a1`。
> 验收条款与 Frozen Acceptance 的唯一落点是 `docs/ai/TASK_BRIEF.md`（review-sensitive）；本文件不在该清单内。

## Goal

对齐 `TASK_BRIEF.md`：把 `install.ps1` 升级为可演练（`-DryRun` / `-ValidateOnly`）、可自检（部署后哈希核验 + 汇总）、破坏性意图显式（参数绑定硬门）、机械遵守 keep-local-only 白名单的部署器；摘除迁移期 guard（含其 `[DEBT]`），并以根级 `tests/` 的常驻 Pester 套件为上述全部声称提供回归证据。

## Summary

**推荐方案：单一「计划 → 执行」两相结构（plan/apply），参数集硬门，白名单为显式闭集。**

一次脚本运行分三态，共用**同一份动作清单**（避免「dry-run 说的」与「真跑做的」漂移——这本身就是正确性的一部分）：

1. `Build-Plan`：只读地扫描源树与目标树，产出动作清单（`ensure-dir` / `copy-file` / `seed-file` / `mirror-dir` / `install-plugin`），并为每个 `mirror-dir` 预先算出三类子项：`copy`（源有）、`delete`（源无且非白名单）、`preserve`（源无但在白名单）。
2. `-DryRun` → 打印该清单，**不执行任何写入**，退出 0。
   `-ValidateOnly` → 对同一清单做前置校验（源存在且非空、目标可创建/可写、机器态不变量、插件 CLI  presencia、参数自洽），打印逐项检查结果，全过 → 0，任一失败 → 1。
   无参数 → 执行该清单：逐项备份 → 部署 → 删除 → 插件 → **逐文件哈希核验** → 汇总。

**为什么不是别的做法**（备选与取舍）：

* *备选 A：在现有线性脚本上加若干 `if ($DryRun)` 分支*。改动量最小，但 dry-run 的输出与真跑的逻辑是两段独立代码，必然漂移；且「白名单与 mirror-replace 的交互」正是本任务最需要机械保证的部分。**不采用。**
* *备选 B：把安装器拆成模块（`Install.psm1` + 函数导出），测试直接单测函数*。可测性最好，但要引入新文件/模块加载面与 pwsh-only 的模式（5.1 下模块路径与 `using` 兼容成本），且 `install.ps1` 的单文件一键语义是本仓契约的一部分（README 一键命令）。**不采用**——本任务只需「子进程 + 隔离 HOME」即可获得等价的可测性（AC7 即此路径）。
* **采用**：单文件、两相结构、子进程黑盒测试。它同时满足 5.1 兼容、一键语义、以及 AC1–AC8 的可判定性。
* **Reuse-first 检索结论（N10）**：检索范围 = 仓内全部 `.ps1`/模块/测试基建 + 本机已装 PowerShell 模块（Pester 6.0.1 / 3.4.0）。结论：**没有可复用的轮子**——`tools/validate/lib/Common.ps1` 只有 baseline/validator 助手（无树哈希、无临时 HOME、无 CLI shim），且 `tools/validate/` 是**封存档**（H5A 停牌，勿续建、勿依赖）；仓内无根 `tests/`、无 `.gitignore`。故测试辅助层从零自建，**不引入任何新依赖**（Pester 是本仓既有测试框架：`tools/validate/requirements.psd1` 已登记）。

### 已定设计决策

**D1（备份语义）：删除 `~/.dsh` 的整树备份，改为只做逐目标备份。**
* 现状：脚本第 82 行 `Backup-IfExists $dshDir` 把**整个** `~/.dsh`（含 `.credentials.yaml` / `sessions/` / `storages/`）复制成 `~/.dsh.bak-<stamp>`，且不自动清理——README 与 `AUTHORITY_CONTRACT` 都为此专门写了「副作用披露」，`docs/ai/HANDOFF.md` 也有对应残余债。
* 事实依据：脚本**只写** `~/.dsh/{AGENTS.md, workflow/, skills/<本工作流两个>}`，而这三个目标**已经各自**走 `Backup-IfExists`（DSH 段，`install.ps1` 第 83–108 行）→ 整树备份对**回滚没有任何增量价值**，只有两个副作用：复制凭据、无限增长的副本。`[证据]` 代码逐行 + 本机 `~/.dsh` 顶层清单。
* **2026-09-15 事故提供的实测证据（不是推理）**：9P round 1 的 Reviewer 在真机上跑了一次真部署，产生了 `~/.dsh.bak-20260915-033521`。其落账清单显示该备份**含 `.credentials.yaml`**，并且把 `profiles/node_modules/**`（成千上万个第三方包文件）一并复制——**副本体量如此之大，进程在复制过程中被杀，备份停在半途**（缺 `sessions/`、`storages/`、`workflow/`、`skills/`）。即：这个备份既复制了最不该复制的凭据，又大到无法完成、因而在需要它时也不可用。该备份已按人类批准删除（`~/.dsh` 本体未被动过，见 `docs/ai/review_9P.md` → round 1 事故节）。
* 结论：删掉整树备份（首行 `Backup-IfExists $dshDir` 与那两段 WARNING 注释），逐目标备份一条不减。这同时**偿还**了 README/AUTHORITY_CONTRACT 的副作用披露与 `HANDOFF.md` 中与该笔相邻的残余披露。
* *备选*：保留整树备份但排除机器态路径（多约 10 行枚举 + 过滤）。它解决凭据复制，却留下一个无回滚价值的整树副本与更多代码——**不采用**。

**D2（白名单闭集）：`archive/**` + `*.bak-*` 进入 keep-local-only。**
* 事实依据（探针，只读）：本机 `~/.claude/{rules,workflow,commands}` 相对仓内源树共有 **127 个仅存在于本机的文件**，其中 `archive/**` 82 个、`*.bak-*` 45 个——**全部**落在这两条 glob 内（`claude/workflow` 106、`claude/commands` 15、`claude/rules` 6）。`[证据]` 本次会话的递归比对命令输出。
* 若不白名单化 `*.bak-*`：真跑一次会**不可逆地删掉 45 个回滚副本**（它们是 2026-08 之前受管文件的唯一旧版本），而 H3 从不要求删它们。
* 若不白名单化 `archive/**`：真跑一次会删掉 82 个本机证据归档（`INSTALLER_GUARD` 继承要求第 4 条明确点名要"decide its fate"，且 keep-local-only 列表里就有 "local evidence archives"）。
* 结论：白名单 = `archive/**`（任意层级名为 `archive` 的目录下的全部内容）+ `*.bak-*`（文件名）；两者对**每个被镜像目录**按相对路径判断。**附带的安全性质**：今天真跑一次，mirror-replace 的删除集合为**空**。
* **2026-09-15 事故提供的实测证据**：那次真部署**恰好**删除了 106 + 6 + 15 = **127 个**本机独有文件，与上表的 82/45 分解**逐类吻合**（82 个 `archive/**` + 45 个 `*.bak-*`）——D2 的前提不是推演，而是已发生过的数据丢失；恢复也正是靠安装器自己写出的目录级快照完成的（见 `docs/ai/review_9P.md` → round 1 事故节）。
* 机器态（`settings.local.json`、`settings.yaml`、`sessions/**`、`storages/**`、`.credentials.yaml`、`.credentials.json`、`auth.json`、既有 `config.toml`、`~/.claude/projects/*/memory`）本就不在受管目录内；本任务要求的是**不被删改也不被复制**（D1 之后由构造保证，并由 AC4 ③ 的「全树反查样本哈希零命中」机械证明）。

**D3（退出码契约）：只有 0 / 1 两个值。**
* `0` = 本次请求的语义全部达成（dry-run：计划产出；validate：全部检查通过；真跑：全部目标部署且哈希核验通过、且无失败的插件步）。
* `1` = 其他一切（绑定失败、参数自洽失败、前置校验失败、复制/核验失败、插件步返回非零）。
* 明确边界（**不作隐藏**）：`claude` CLI 不在 PATH 时，插件步记为 `SKIPPED`、打印人工命令、**不**导致退出码非 0（沿用今天的行为与 README 的说法）；`-NoPluginInstall` 时同样记 `SKIPPED`。汇总里 `SKIPPED ≠ verified`，逐行可见。

**D4（输出契约，供 AC 机械断言）：每条动作一行、方括号标签起首、路径为绝对路径。**
```
[PLAN]     <动作> <目标>            # -DryRun 专用前缀
[CHECK]    <检查项> OK|FAIL <细节>  # -ValidateOnly 专用前缀
[BACKUP]   <目标> -> <备份路径>
[DEPLOY]   <目标>
[DELETE]   <仅存在于本机的路径>
[PRESERVE] <白名单路径>
[VERIFY]   <目标> sha256=<值> OK|MISMATCH
[PLUGIN]   <名字> INSTALLED|FAILED|SKIPPED <原因>
[SUMMARY]  deployed=<n> verified=<n> deleted=<n> preserved=<n> plugins=<n> skipped=<n> failed=<n> seeded=<n>   # seeded= 为实现期增补（见 HANDOFF Work Log 与 9A 的 S3）
```
`[SUMMARY]` 行的字段顺序与拼写冻结（测试按它断言）。

## Architectural Layers & Split Assessment

触及层 = **CLI/部署脚本 1 层**（`install.ps1`）+ 测试基建 1 层（根级 `tests/`，新增）。文档为伴随改动，不计层。< 3 层 → **N/A**（不触发拆分评估）。

不宜拆的理由（备查）：控制面与其回归证据是同一次交付的两个半边——只上控制面则 AC1–AC8 全部无判定方式，只上测试则无被测对象；拆开会产生一个「不可验收的中间态」。

## Frozen Acceptance（指针）

**唯一落点 = `docs/ai/TASK_BRIEF.md` → `Acceptance Criteria`（AC1–AC11，含冻结输入域 K1–K9、执行前置约束与判定环境冻结；**编号与样本一律以该文件为唯一出处，本文件不复制编号**）。本节不复述条款**，只记实现期必须守住的边界：

* 所有部署/删除只发生在**临时目标目录 / 临时 HOME**；真实 `~/.claude`、`~/.codex`、`~/.dsh` 只允许**只读**（AC7 会读它们的哈希）。
* AC1 的「绑定阶段失败」由**参数集**实现（不是函数体内的检查）——`-DryRun` 与 `-ValidateOnly` 属不同 ParameterSet，`K7` 因此在绑定期即失败。
* AC9 的三条 grep 与 AC10 的两条计数必须在 `last_test_run.txt` 里留真实输出与退出码。
* AC11 的「两处文档逐条一致」不变式（`HANDOFF.md` 与 `DSH-LANDING-NOTES.md` §5）必须同改。

## Current Architecture Understanding

* `install.ps1`（126 行，5.1 兼容，`[CmdletBinding()]` + 单一确认开关）当前结构：① guard throw；② `Backup-IfExists`；③ 建三个 home 目录；④ `~/.claude` 单文件（`CLAUDE.md`/`settings.json`）；⑤ `~/.claude/{rules,workflow,commands}` mirror-replace；⑥ `~/.codex/AGENTS.md` + `config.toml` seed-only；⑦ DSH 段：整树备份 + `~/.dsh/AGENTS.md` + `~/.dsh/workflow/` mirror-replace + 两个 skill 目录 mirror-replace；⑧ 5 个插件 `claude plugin install`；⑨ 裸 `Done` 与一段「刻意不部署」说明。
* 受管面来自 `README.md` 布局表与 `AUTHORITY_CONTRACT`：`~/.claude/{CLAUDE.md,settings.json,rules/,workflow/,commands/}`、`~/.codex/AGENTS.md`（`config.toml` seed-only）、`~/.dsh/{AGENTS.md,workflow/,skills/{dual-agent-workflow,independent-review}/}`。**刻意不部署**项（凭据 / 登录态 / session / `settings.local.json` / `~/.dsh/settings.yaml` / `~/.claude/projects/*/memory` 等）在 README 的「刻意不部署」段，**不在布局表内**（S-7：不要把两者混列）。
* 现有测试基建：`tools/validate/`（H5A 封存：Pester + powershell-yaml + PSScriptAnalyzer + gitleaks，**对本任务无关且对当前 main 预期红**）；`tools/ac4-reasoning-effort-check.ps1`（常驻门，本任务不触碰）。本机 Pester = 6.0.1，`Invoke-Pester` 具备 `-Path` / `-CI` / `-PassThru`（已核实）。
* `docs/ai/` 当前状态：`HANDOFF.md` 为空闲期形态（Idle），`TASK_BRIEF.md` 为本任务新建，`INSTALLER_GUARD.md` 为 guard 的版本化过程记录（含 7 行证据表 + 5 条 H3 继承要求 + 一笔 `[DEBT]`）。

## Proposed Changes

| # | 文件 | 类型 | 计划内容 | 原因 / 风险 |
|---|------|------|---------|------------|
| 1 | `install.ps1` | **修改（rewrite）** | 新参数面（6 个参数 + 3 个 ParameterSet）；`Build-Plan` / `Show-Plan` / `Test-Plan` / `Invoke-Plan` / `Show-Summary` + 白名单与机器态两个显式清单；删 guard 与整树备份；**插件清单 5 → 6（补 `clangd-lsp`）**；部署后逐文件哈希核验 + 汇总；退出码按 D3 | 本任务生产面主体。风险：5.1 兼容（AC8）、参数集与 `-File` 调用形态、`$LASTEXITCODE` 捕获（AC5） |
| 2 | `tests/TestHelpers.ps1` | **新增** | 临时 HOME / 目标树 / 假 repo 副本的**每用例新建 + 用例后清理**（S-2：禁止跨用例复用——AC6③ 的"目标建成目录"、AC2 的"覆盖为新内容"、AC4④ 的"部署前已存在"会互相干扰）、`Get-TreeSignature`（相对路径 + SHA-256 排序清单）、fake `claude.cmd` shim、**只封装 `-File` 形态**的子进程调用（S-7：前置约束 1 禁 `-Command`，测试基建不得留这条禁路）、子进程内互锁断言 wrapper | 供四个测试文件共用；不含 `*.Tests.ps1` 后缀，故不被 Pester 当容器发现 |
| 3 | `tests/install.Parameters.Tests.ps1` | **新增** | AC1：K2 通过样本 ×3 + K4/K5/K6/K7 失败样本 ×5，逐样本断言退出码、诊断文本、零副作用 | 7 行拒绝矩阵的常驻化（`INSTALLER_GUARD` 继承要求 2） |
| 4 | `tests/install.DryRun.Tests.ps1` | **新增** | AC2（`-DryRun` 零写入 + 计划内容）与 AC3（`-ValidateOnly` 与真部署**共用同一校验谓词**，**六用例**，含临时假 repo 承载的 K9③/④/⑤ 与"去掉 `-ValidateOnly` 仍拒绝"） | 零写入声称的负向对照就在本文件（真部署用例） |
| 5 | `tests/install.Deploy.Tests.ps1` | **新增** | AC4（白名单双向）、AC5（插件步三用例：不带 K8 的真部署配对基准 / K8 单跑配对对照 / shim 强制非零）、AC6（自检 + 汇总 + 缺项与破坏性样本） | 需在预置的临时目标树内真部署 |
| 6 | `tests/install.IsolatedHome.Tests.ps1` | **新增** | AC7（隔离 HOME 下无参数完整部署 + 真实受管面哈希不变）与 AC8（5.1 `-DryRun`） | 首次让「正向路径」可执行（guard 记录称其在此之前不可测） |
| 7 | `README.md` | **修改** | ① 文首权威段末句（现第 5 行）删「在 H3 提供真实 `-DryRun`/`-ValidateOnly` 前…保持迁移安全锁定」；② 「一键部署」段的 ⚠️ 警告块（现第 17 行）整块替换为 H3 后的真实语义（mirror-replace + `-DryRun`/`-ValidateOnly` + keep-local-only 白名单 + 白名单闭集 `archive/**` / `*.bak-*` + 不再整树备份 / 不再需确认开关）；③ 同段末的脚本步骤描述（现第 19 行）；④ 「刻意不部署」段（现第 21 行）删「整树备份会把凭据复制进 `~/.dsh.bak-*`」；⑤ 「布局与安装位置」表（现第 26–38 行）内更新 `install.ps1` 行描述并**新增 `tests/` 行**；⑥ 「快照状态」段的 DSH 迁移状态块（现第 54 行）给「install.ps1 受迁移期 guard 锁定、未运行」加日期订正；⑦ 同段末的插件计数 **5 → 6**（`clangd-lsp`，人类 2026-09-15 裁决）并补**「同步与落账规范」**一两行（每次部署记录：命令 + `[SUMMARY]` + 备份路径；`~/.dsh` 运行副本不再靠人工同步） | 行为变化必须同 patch 改准（AC9）；⑦ 同时服务插件一致性（人类裁决）与 `~/.dsh` 债的偿还（AC10 第二笔） |
| 8 | `AGENTS.md`（仓库根） | **修改** | ① 「Build / Test / Lint Commands」节（现第 11 行）删「受迁移期 installer guard 锁定，勿直接运行」并改为 H3 后语义；② 同节补**真实存在**的测试命令 `pwsh -NoProfile -Command "$c = New-PesterConfiguration; $c.Run.Path = 'tests'; $c.Run.Exit = $true; $c.TestResult.Enabled = $false; Invoke-Pester -Configuration $c"`（**不落 `testResults.xml` 的形态**，见 Risks #11）与 5.1 兼容检查命令，并注明 `tests/` 是本任务的验收套件、与封存的 `tools/validate/` 无关 | 同上（AC9 ③）；本仓 AGENTS.md 明令「只列真实存在的命令」 |
| 9 | `claude/rules/README.md` | **修改** | 该文件的安装器段（现第 32 行）：删「currently locked by the migration-period installer guard … do not run it directly」，改为指向根 README 的部署段与 `-DryRun` | 该文件是**受管部署面**成员（本机副本与仓内逐字节一致），其陈述失效必须同改 |
| 10 | `docs/ai/INSTALLER_GUARD.md` | **修改** | ① `[DEBT]` 条目标 **Repaid**（附本任务 commit + 验证命令）；② 增一节记录 guard 摘除与 7 行矩阵的去向（指向 `tests/install.Parameters.Tests.ps1`）；③ **保留**取证表 7 行与 5 条继承要求的原文 | AC10：偿还但不删历史 |
| 11 | `docs/ai/AUTHORITY_CONTRACT.md` | **修改（只动一处，加日期订正）** | 「2026-09-06 增补」块（现第 3 行）中两处**当前状态**陈述加订正：整树备份副作用已由 H3 移除、部署面镜像语义已由 H3 的隔离 HOME 实跑覆盖（不再是「已登记但未实测」）。**明确不改并给出理由**：第 24–34 行（该任务 Scope 与 Applicability，含 `:25` 的「Explicitly OUT of scope: … `install.ps1`」与 `:34` 的「`install.ps1` is never executed」）、第 95–134 行（冻结的 anchor classification 与 Verification round 1/2）、第 215 行（round 3 对 `迁移安全锁定` 的校验记录）——**这些都是绑定旧 commit 的历史陈述**（该文件自述为记录），重写即伪造历史；AC9② 的 grep 域因此不覆盖它们，这是判定而非漏改 | 同 patch 改准；**边界写进计划以免被误判为漏改** |
| 12 | `docs/ai/DSH-LANDING-NOTES.md` | **修改** | §4 的「脚本受 guard 锁定、未运行」加日期订正；**§4 增记"首次自动部署"（命令 + `[SUMMARY]` + 备份路径，由人类执行，AC10 第二笔）**；§5 的 `[U]` 第 5、6 项改写为已处置并给出等价物说明（与 `HANDOFF.md` 逐字一致） | AC11 的两处一致不变式 + AC10 的债偿还落账 |
| 13 | `docs/ai/HANDOFF.md` | **修改** | 从空闲期形态切到本任务：Current Phase / Task Summary / Source of Truth / Review & Test Binding / Work Log / Known Issues / Fix-Loop / Debt / Quality Gates / Next Step | `/implement` 阶段产物（AC10 的台账同步） |
| 14 | `docs/ai/last_test_run.txt` | **新增** | 全部 AC 的真实命令 + 完整输出 + 退出码（含 K1–K9 逐样本、同形配对负向对照、5.1 与 pwsh 7 两跑、AC11 的两条 `Select-String` 输出、AC9 的三条 grep 与 base 负向对照） | Critical 的验证载体 |

**明确不改**：`claude/**` 除 `claude/rules/README.md` 外的一切、`codex/**`、`dsh/**`、`portable/**`、`tools/**`（含封存的 `tools/validate/` 与常驻的 AC4 门）、`.gitattributes`、部署路径集合本身。

**插件清单差异（人类 2026-09-15 裁决：本任务内一并修）**：`install.ps1` 硬编码 5 个插件，而 `claude/settings.json` 的 `enabledPlugins` 有 6 个（多 `clangd-lsp@claude-plugins-official`）。**修法 = 给 `install.ps1` 补上第 6 个**（5 → 6），不是从 `settings.json` 删掉它：`[证据]` `claude/settings.json:58` 启用它、`claude/CLAUDE.md:151` 把它列为 LSP 后端之一、上一任务（2026-09-06 Routine）明确"补录 `clangd-lsp`"并把该条从 live 反向晋升进仓（`docs/ai/archive/2026-09-06-agent-reference-and-phase-rulings/HANDOFF.md`）——**陈旧的是安装器那份清单，不是 settings**。受影响的判定与文档：AC2（6 个插件名）、AC5（部署集合 = 6）、README「一键部署」段的"5 个官方插件"叙述（改动 #7⑦）。**不再作为"已知差异不改"登记。**

## Risks & Edge Cases

1. **5.1 兼容**：参数集语法、`[System.IO.Path]::GetFullPath`、`Get-FileHash`、`$LASTEXITCODE`（原生命令）均在 5.1 可用；但 `-Command`/`-File` 的调用差异与 `$env:PATH` 处理必须实测（AC8 + AC7 两跑）。**风险中**。
2. **参数集与默认集交互**：`DefaultParameterSetName='Deploy'` 必须让 K1（无参数）落在真部署集；`-NoPluginInstall` / 三个路径参数需同时属三个集。**风险中**，AC1/AC7 覆盖。
3. **`Get-Command claude` 与 shim 的解析**：shim 为 `claude.cmd`。**已实测（9P round 3 的 B-1 被反证）**：在临时目录放 `claude.cmd` 并把该目录前插 `PATH` 后，`Get-Command claude` → 该 shim（`Application …\Temp\shim-…\claude.cmd`），真实 `%APPDATA%\npm\claude.ps1` 退居其次——**PATH 目录顺序优先于扩展名优先级**，故无需把 shim 改名为 `.ps1`；`(Get-Command claude).Source` 的互锁断言可满足。**风险低**（已实测）。
4. **AC7 的 `$env:USERPROFILE` 覆盖**：必须在**子进程**内设置（不能污染父进程环境）；子进程脚本落 `$env:TEMP`，不进仓。**风险低**。
5. **符号链接 / 长路径**：目标树为临时目录，不预期出现；`Copy-Item -Recurse` 沿用现有语义。**风险低**。
6. **白名单判定的路径形态**：必须用**相对路径 + 段匹配**（`archive` 作为路径段），而不是字符串 `-match 'archive'`（否则 `my-archive-notes.md` 会被误保留）；`*.bak-*` 用文件名匹配。**风险中**——AC4 的 stray 样本与 rename 样本需覆盖。
7. **删文件前的人类确认红线**：`dsh/AGENTS.md` 要求「删除或覆盖文件之前先与人类确认（本工作流自身的部署例外：`install.ps1` 的 mirror-replace 语义）」。本计划即该确认的载体：**人类批准本计划 = 批准「安装器保留 mirror-replace 语义」**；而真跑删除只发生在临时目录，真实机器面在本任务内**不执行删除**。**需人类在批准时确认**。
8. **⚠️ 已实际发生的风险（2026-09-15 事故，非假设）**：9P round 1 的 Reviewer 在真机上执行了真部署 —— `~/.claude/workflow/` 的 106 个本机独有文件、`rules/` 6 个、`commands/` 15 个被 mirror-replace 删除，并生成含凭据副本的 `~/.dsh.bak-*`。**已按人类批准从部署快照纯增量恢复**（85/116/22，零内容差异），凭据备份副本已删除。**直接产出的计划修订（已冻结进 `TASK_BRIEF.md`）**：① 全部用例的执行前置约束（调用形态固定为 `pwsh -NoProfile -File`、目标必须显式隔离、插件步必须走 fake shim 且断言 `(Get-Command claude).Source` 指向 shim）；② **机械互锁下沉到子进程内**（断言生效的 `$env:USERPROFILE` 与解析出的三目标均为期望临时值，否则非零退出且**不调用** `install.ps1`）——判定在"实际生效的环境"上，不在辅助函数的"预期值"上（round 2 的 B6 指出后者的假绿路径）；③ 互锁自身配负向对照（用真实 HOME 路径构造 → 判定失败且未启动子进程，以哨兵文件为证）；④ AC3 的 K9⑤ 样本改由**临时假 repo** 承载（真实仓库不在互锁覆盖范围内，不能拿它当部署目标，round 2 的 B5）；⑤ AC3 新增"目标落在源树内 → 拒绝且零写入"，把源树自身纳入保护。
9. **测试套件对 `powershell.exe` 的依赖**：本仓 Windows-only（安装器写 Windows home），故 AC8 在套件内直接调用 `powershell.exe` 是合理的；若将来移植需重估。**风险低**。
10. **`tests/` 被误当门禁**：需在根 `AGENTS.md` 的 Build/Test 节写清它是**本任务的验收套件**、与封存的 `tools/validate/` 无关系。
11. **Pester 的落盘副作用**：`Invoke-Pester -Path tests -CI` 会按 `TestResult.OutputPath` 默认值在当前工作目录写出 `testResults.xml`，而本仓**没有 `.gitignore`** → 会脏化工作树（与"审查快照干净工作树"闸门冲突）。**已实测确认**（见 `review_9P.md` round 2 的 Author 代跑），故测试命令冻结为 `New-PesterConfiguration` + `Run.Exit=$true` + `TestResult.Enabled=$false` 形态（AC9③）。**风险低**（已消除）。

## Execution Steps

1. `docs/ai/TASK_BRIEF.md` 定稿（已建）→ 9P 计划审：**round 1 已作废**（Reviewer 在真机上执行了安装器，违反零写入；事故与恢复见 `docs/ai/review_9P.md`）→ 依其 B1/B2/A1/A2 修订 → **round 2 以硬化 prompt 重跑**（判 `修订后可批准`，6 条 Blocking）→ 依 B1–B6 与 N1–N11 再修订 → 人类批准门（`docs(plan): approve h3-installer-hardening`，**人类 commit**）。人类可在批准前明示要求再跑一轮（round 3）。
2. 实现 `install.ps1`（参数面 → plan/execute 两相 → 白名单与机器态清单 → 插件步 → 自检与汇总 → 退出码）。
3. **先落测试基础设施（隔离 + 互锁 + shim），再写部署类用例**：`tests/TestHelpers.ps1` 与四个测试文件（先 K1–K9 参数面，再 dry-run/validate，再部署面，最后隔离 HOME 与 5.1）。
4. 同 patch 改文档（README / 根 AGENTS.md / `claude/rules/README.md` / `AUTHORITY_CONTRACT` 订正 / `INSTALLER_GUARD` 偿还 / `DSH-LANDING-NOTES` 的 `[U]`）。
5. 跑全部验证并把真实输出落 `docs/ai/last_test_run.txt`（含 base 上的 grep 负向对照、哈希清单、5.1 与 pwsh 7 两跑、AC11 的两条 `Select-String` 完整输出）。
6. 更新 `docs/ai/HANDOFF.md`（含 `review_base_sha` / `review_tip_sha` / `tested_sha` / `review_sensitive_paths`）→ §4 的 `docs(handoff)` commit → 开双审窗口（9B 先行、9A 后行，各自独立 subagent、零写入）。
7. 收 verdict → Author 逐条处置（代跑 VN 追加进 `last_test_run.txt`）→ `/final-review` 收敛门 → 人类 commit / merge。
8. **给人类的第一台设备 runbook（A3；真实 HOME 的首次真部署由人类执行，不由 agent 执行）**：`-ValidateOnly` → `-DryRun` 并逐条读 `[DELETE]`/`[PRESERVE]` 清单 → 确认为空/符合预期后真部署 → 保留 `*.bak-<stamp>` 直至确认可用。该 runbook 落 `HANDOFF.md` → Next Step。
9. **偿还 `~/.dsh` 人工同步债（人类 2026-09-15 裁决：本任务内）**：在实现与测试全绿、审计通过之后，由**人类**按上面的 runbook 对真实 `~/.dsh` 执行首次自动部署（当前 `~/.dsh` 与仓内 `dsh/**` **逐字节一致**，故内容零变化、只产生逐目标 `*.bak-<stamp>` 与一份真实 `[SUMMARY]`）；**执行前必须先重跑一次只读比对确认该"逐字节一致"在执行时刻仍成立**（round 3 的 assumption 2）；Author 只读核验并把命令 + 输出记入 `HANDOFF.md` Work Log 与 `DSH-LANDING-NOTES.md` §4，**然后**才把该 `[DEBT]` 标为已偿还（AC10 第二笔）。**该笔是承诺项**：未执行 → 本任务不得标"已收敛 / Ready to Commit"（唯一例外 = 人类给出新的明确延期裁决并记入 HANDOFF）。

## Testing Plan

真实存在的命令（全部实测过形态）：

```powershell
# 主套件（AC1–AC8；预期：全部通过，退出码 0；**不落任何产物文件**——见 NC3 与 Risks #11）
pwsh -NoProfile -Command "$c = New-PesterConfiguration; $c.Run.Path = 'tests'; $c.Run.Exit = $true; $c.TestResult.Enabled = $false; Invoke-Pester -Configuration $c"

# 5.1 兼容腿（AC8 的直接命令形态；套件内亦有子进程用例）
#   注意：目标必须指向临时目录（下列形态仅供人工复核；绝不可省 --Dir 参数）
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -DryRun `
    -ClaudeDir "$env:TEMP\h3-claude" -CodexDir "$env:TEMP\h3-codex" -DshDir "$env:TEMP\h3-dsh"

# dry-run 零写入的人工复核（AC2；**不带 -NoPluginInstall**——B-2：计划/校验态本就不执行插件步，
# 该 flag 在 dry-run 下既无意义、又会与 K8 的"真部署语境"定义混淆）
pwsh -NoProfile -File .\install.ps1 -DryRun `
    -ClaudeDir "$env:TEMP\h3-claude" -CodexDir "$env:TEMP\h3-codex" -DshDir "$env:TEMP\h3-dsh"

# AC8 的纯 ASCII 判据（S-4；负向对照 = 在 base e9917a1 上同一判据返回 True）
(Get-Content -Raw install.ps1) -match '[^\x00-\x7F]'    # 预期 False

# AC9① 的 grep 判定（域 = 除 docs/ai/** 外的全部）与 base 负向对照
git grep -n 'IUnderstandThisReplacesLiveConfig' -- . ':(exclude)docs/ai/**'
git grep -n 'IUnderstandThisReplacesLiveConfig' e9917a1 -- .          # 负向对照：非零命中

# AC9② 的"失效声称"零命中（允许"不再整树备份/已由 H3 移除"这类订正叙述）
Select-String -Path README.md,AGENTS.md,claude/rules/README.md,docs/ai/AUTHORITY_CONTRACT.md -Pattern '整树备份' |
    Where-Object { $_.Line -notmatch '不再|已移除|H3' }               # 预期：无输出

# AC4 的机器态反查（套件内实现；人工复核同形）
# AC10 的台账判定
Select-String -Path docs/ai/INSTALLER_GUARD.md -Pattern 'Repaid'
(Select-String -Path docs/ai/HANDOFF.md -Pattern '^\[DEBT\]').Count
```

**测试执行纪律（2026-09-15 事故后新增，强制）**：
* **禁止**任何用例、辅助函数或人工探针执行**指向真实 HOME** 的 `install.ps1` 调用——包括带 `-IUnderstandThisReplacesLiveConfig` 的形态（该开关的语义是"**确认后放行**"，不是"拒绝"；guard 只在该开关**缺席**时 throw。事故正是这个误读造成的）。Author 自己的只读探针同样受此限。
* **机械互锁下沉到子进程内（B6）**：用例生成的 wrapper 在**子进程里**断言 ① 生效的 `$env:USERPROFILE` == 期望临时 HOME；② 解析出的三个目标 == 期望临时路径且均不在真实 `.claude`/`.codex`/`.dsh` 之下；③ `(Get-Command claude).Source` 指向 fake shim（本机**确实**装有真实 `claude`，实测 `True`）。任一条不成立 → 非零退出且**不调用** `install.ps1`。**判定依据是"实际生效的环境"，不是辅助函数打算设置的值**——否则环境覆盖失效时会给出假绿并写真实 HOME。
* **互锁自身的负向对照**：用真实 HOME 路径构造一次调用 → 判定互锁失败且**未启动子进程**（以哨兵文件不存在为证）。没有这条，互锁就是一条无对照的守护声称。
* Reviewer 的 prompt 已加显式禁令（9P/9A/9B 三份）；对其一切"只读检索"要求都以不执行安装器为前提。
* **用例隔离粒度（S-2）**：每个用例各建一套临时 HOME / 目标树 / 假 repo 副本，用例结束清理，**禁止跨用例复用**——否则 AC6③（把目标建成目录）、AC2 的负向对照（要求"覆盖为新内容"）、AC4④（要求"部署前已存在"）会互相污染。
* **会写文件的两处负向对照（round 3 的 assumption 3）**：AC9③ 的"用 `-CI` 形态实跑一次制造 `testResults.xml`"与 S-4 的临时样本都必须记录**产物路径 + 删除动作 + 事后 `git status` 干净**，落 `last_test_run.txt`——不得留下未跟踪产物污染审查快照。

**守护有效性装置**：本任务对「机制 X 拒绝 Y」类声称（参数绑定拒绝、白名单保留、`-NoPluginInstall` 抑制、退出码非零）一律提供**负向对照**，且对照形态是「**若移除 X 则会通过**」（见 AC1/AC2/AC4/AC5/AC6/AC8 各自的负向对照条）。本仓**没有**常驻的守护有效性装置脚本，故本任务**不声称**「回归用例有效（红→绿）」这一结构化产物能力；如需要，按母本「无装置项目」记 `[DEBT]`。**风险自负声明**：AC 的负向对照由 Pester 用例在真实运行中触发（真实退出码），不是 grep 判红。

## Open Questions

**未解决问题：None（下列四条已在规划期关闭，逐条给出关闭依据）**：

1. **删除语义** —— **已关闭**：人类 2026-09-15 选定「H3 后**无参数 = 真部署**（移除确认开关）」，该选项的含义即「恢复到最初的文档化一键命令」，也就是**保留 mirror-replace 的删除语义**（这是"真部署"的定义本身，不是隐含假设）。`[证据]` 本次会话问答 + `TASK_BRIEF.md` → Original Request。人类若改为"纯叠加/只增不删"，那属**变更请求**（会使 AC4 的 stray 样本改判），需回 `/plan`，不由 Author 自行降级。
2. **原 guard 记录第 7 行的取值（`-IUnderstandThisReplacesLiveConfig:$false`）** —— **已关闭**：人类已选定移除该开关，故它落入 K4（绑定失败）这一等价类。
3. **`tests/` 的长期位置** —— **已关闭**：人类选定根级 `tests/`（`TASK_BRIEF.md` → Original Request 第 3 条）。
4. **插件清单 5 vs 6** —— **已关闭（人类 2026-09-15 裁决：本任务内修）**：修法 = 给 `install.ps1` 补上 `clangd-lsp`（依据见"插件清单差异"节）；AC2/AC5 与 README 的计数同改。
5. **`~/.dsh` 人工同步债是否本任务偿还** —— **已关闭（人类 2026-09-15 裁决：本任务内一并偿还）**：见 AC10 第二笔与 Execution Step 9（落账规范 + 人类执行的首次自动部署）。

> 依 `dsh/skills/dual-agent-workflow/references/phases/plan.md` 第 5 条，带 Unknown 的计划不得停在 Pending——本节的关闭依据即该条的落实；**无遗留 Unknown**。

## Human Approval Status

* Status: Approved
* Approved by: [Dean]
* Date: [2026/09/15]

> 此字段任何 Agent 不得修改；Status 由人类批准时亲自改为 Approved——**先改 Status、再 commit**。批准正式凭证 = **内含 `Status: Approved` 的**人类 git commit（建议消息 `docs(plan): approve h3-installer-hardening`）。非 Approved 禁止进实现。
