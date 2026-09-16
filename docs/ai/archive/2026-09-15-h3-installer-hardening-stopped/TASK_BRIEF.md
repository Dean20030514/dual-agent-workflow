# TASK_BRIEF.md

> per-task 文件，blind review 的唯一需求依据，必须自洽：只看此文件应能判断实现对不对。
> 骨架出处 = `claude/workflow/templates/TASK_BRIEF.md`（DSH 侧同一骨架）。
> 本文件是验收条款与 **Frozen Acceptance** 的单一事实源（review-sensitive）：实现前冻结，禁从当前实现反推。
> 任务 = **H3 · Installer Hardening（`install.ps1`）**，分支 `task/h3-installer-hardening`，base `e9917a1`。

## Dimension Applicability Scan

18 维逐维判定（结果写在此处，草稿过程不照抄）：

| # | 维度 | 关注/N/A | N/A 原因 | 关注后展开/验收 |
|---|------|---------|---------|----------------|
| 1 | 产品定位 | N/A | 内部/一次性任务：本仓是个人 master-copy 仓库，不满足「真实可发布产品」判据 ①（无本团队外用户）②（无独立发布动作） | — |
| 2 | 用户研究 | N/A | 无外部用户；需求来自人类 2026-09-06 的裁决与 `docs/ai/INSTALLER_GUARD.md` 的 H3 继承要求（`[证据]` 仓库内文件） | — |
| 3 | 产品策划/PM | 关注 | 范围边界与优先级须显式（本任务有破坏性语义） | 下文 Goal / Non-Goals / Acceptance |
| 4 | 交互设计 UX | 关注 | 安装器是面向人类的 CLI：参数面与输出（计划 / 汇总 / 诊断）就是它的 UX | AC2 / AC3 / AC5 / AC6 |
| 5 | 视觉设计 UI | N/A | 无图形界面 | — |
| 6 | 美术/内容表现 | N/A | 无美术资产 | — |
| 7 | 技术开发 | 关注 | 生产面 = `install.ps1`（rewrite 级改动） | 全部 AC |
| 8 | 测试/QA | 关注 | 本任务的核心交付之一 = 7 行拒绝矩阵转成的常驻 Pester 回归套件 | AC1–AC8 |
| 9 | 安全/隐私/合规 | 关注 | ① 破坏性 mirror-replace 的确认语义；② keep-local-only 白名单（凭据 / 登录态 / session / 私有 memory / `settings.local.json` / 既有 `config.toml` / 本机证据归档）不得被删改或复制 | AC4 / AC6 / AC7；QUALITY_GATES 11.2 基础组 |
| 10 | 可访问性/普适性 | N/A | 无面向公众的可访问性面；CLI 输出为纯文本 | — |
| 11 | 数据分析 | N/A | 内部任务：成功 = 验收全过（无北极星指标、无埋点） | — |
| 12 | 运营增长 | N/A | 同 11 | — |
| 13 | 商业模式 | N/A | 无商业模式 | — |
| 14 | 品牌 | N/A | 无品牌面 | — |
| 15 | 内容 | 关注 | README / 根 `AGENTS.md` / `claude/rules/README.md` / `AUTHORITY_CONTRACT` / `INSTALLER_GUARD` 关于「迁移期锁定 / 整树备份 / 确认开关」的陈述必须与代码同 patch 改准 | AC9 |
| 16 | 客服与用户成功 | N/A | 无外部用户 | — |
| 17 | 项目管理 | N/A | by-trunk：单人、单里程碑，由双 Agent 主干隐式覆盖 | — |
| 18 | 组织与人才 | N/A | 角色分配沿用工作流既有定义（Author / Reviewer / 人类） | — |

**设计层闸门（`/design-check`）不触发**：0.1 第 4 维关注的是「安装器的 CLI 交互」，但本仓无界面、无视觉/内容表现层（5/6 维 N/A），故不跑 `/design-check`，只在本文件的 AC2/AC3/AC6 里对 CLI 输出下达可判定要求。
**`PRODUCT_BRIEF.md` N/A**：产品/上线性（11/12/13/14/16）全部 N/A，无产品级长期结论要落盘。

## Original Request

人类在 2026-09-06 于 DSH 会话中选定本仓 `docs/ai/HANDOFF.md` → `Next Step` 的**候选 1**，并明确选择 **Critical** 模式：

> 「继续本项目的下一步」→ 候选 1「给 `install.ps1` 真正的 `-DryRun` / `-ValidateOnly`（H3）—— 解锁迁移期 guard，让部署可演练」，模式 = **Critical：走完整流程（冻结验收 → 计划 → 9P 审 → 人类批准门 → 实现 → 9A/9B 双审 → final-review）**。

人类同时就三处会改变结果的分叉当场拍板（均为 `[证据]` 本次会话问答，逐字记录）：

1. **分支**：新建侧分支 `task/h3-installer-hardening`（母本 Git Discipline 字面要求）。
2. **H3 落地后的默认语义**：**无参数 = 真部署**（移除确认开关 `-IUnderstandThisReplacesLiveConfig`）。
3. **回归测试位置**：新建根级 `tests/`。

`docs/ai/HANDOFF.md` 对该候选的既定提示（`[证据]` 仓库内文件）：**触及部署/回滚面，按纪律应先建议 Critical 并停下等人类确认**——已完成。

## Goal

把 `install.ps1` 从「迁移期 guard 锁定的不可演练脚本」升级为**可演练、可自检、破坏性意图显式**的部署器，并让它的守护语义获得**常驻回归证据**：

1. 参数面：`-DryRun` / `-ValidateOnly` / `-NoPluginInstall` / `-ClaudeDir` / `-CodexDir` / `-DshDir` 六个参数；保留 `[CmdletBinding()]`——未知参数、拼写错误、位置参数在**参数绑定阶段**失败，绝不静默落进 `$args`。
2. `-DryRun` 打印完整计划、**零写入**；`-ValidateOnly` 只做前置校验并给出可复现结论。
3. keep-local-only 白名单被**机械遵守**：mirror-replace 只删「源里没有且不在白名单」的文件；机器态与白名单内容不被删改、不被复制。
4. 部署后**自检每个受管目标的内容哈希**并输出部署汇总（取代裸 `Done`）；插件步可离线测试，`-NoPluginInstall` 可跳过。
5. **摘除 guard**（含其债务条目）——`docs/ai/INSTALLER_GUARD.md` 的 5 条 H3 继承要求全部落地。
6. 上述控制能力由**根级 `tests/` 的常驻 Pester 套件**机械证明，其中包含「guard 记录所载的 7 行拒绝矩阵」与「正向路径首次可执行」。

## Non-Goals

* **不执行 agent 侧的真实部署**：agent 的一切部署/删除动作只在临时目标目录、临时 HOME 与子进程中发生。**唯一例外 = AC10 第二笔：由人类对真实 `~/.dsh` 执行一次首次自动部署**（人类 2026-09-15 裁决在本任务内偿还该债；agent 不得代跑，只做只读核验与落账）。
* **不动 `tools/validate/`**（H5A 封存档：非门禁、勿续建、勿修；其真仓断言绑定修漂移前的仓库状态，对当前 main 预期失败）。新套件落在根级 `tests/`，与它无关。
* **不动 `dsh/**`**（会触发 `[DEBT]`「dsh/ 判据漂移缺少机械门禁」的偿还义务，与本任务无关；H3 不改变 DSH 侧判据）。
* **不实现 `IMPROVEMENT_PLAN.md` 的 H1 / H2 / H4 / H5**（`-ClaudeDir` 之外的 H3 原文条目已按 `INSTALLER_GUARD.md` 扩写；H4 的 `plugins.resolved.json`、H5 的 validator/CI 均不在本任务）。`IMPROVEMENT_PLAN.md` 自 2026-08-05 起为 **REFERENCE ONLY**，本任务只把它当历史输入，不作为判据。
* **不引入新依赖**（Pester 6.0.1 已是本仓既有测试框架：`tools/validate/requirements.psd1` 登记、本机已装）。
* **不做与 H3 无关的重构**（不改 `claude/**` / `codex/**` / `portable/**` 的内容语义；不改部署路径集合）。
* **不 push / 不 merge / 不做任何远程操作**（本仓契约）。

## Constraints

* `install.ps1` **保持 Windows PowerShell 5.1 兼容**（本机 `powershell.exe` = 5.1.26100.9444）；不得顺手现代化（不用 `??`、三元、`-Parallel`、`Get-FileHash -Algorithm` 之外的 pwsh-only 能力）。
* `install.ps1` 重写后**保持纯 ASCII**（S-4：UTF-8 无 BOM + 5.1 按 ANSI/CP936 读 `-File` 脚本 → 非 ASCII 会乱码；现有 7 处 em dash 即实例）。输出与注释一律用 ASCII 标点（`-` 而非 `—`）。
* 文件编码 UTF-8 无 BOM；行尾 LF（`.gitattributes` 强制）。
* 测试运行环境 = `pwsh 7.6.6` + Pester 6.0.1（`Invoke-Pester -Path tests -CI` 已核实为真实存在的形态）。
* 单轮 diff 预算 ≤ 4000 行（只计 `docs/ai/` 之外的生产面）。估算（区间；实现后**如实记录实际行数**，N11）：`install.ps1` rewrite 200–300 行 + `tests/**` 400–800 行 + 文档 60–100 行 ≪ 预算（参照：`tools/validate/tests/Common.Tests.ps1` 单文件即 348 行，故 400 行的乐观值已上调）。
* 破坏性动作前置条件：任何删除/覆盖都必须在**临时目标**内进行，且执行前先说明风险（本文件与 `IMPLEMENTATION_PLAN.md` 即该说明）。
* **Payback-on-Touch 已触发**（改 `install.ps1`）：`docs/ai/INSTALLER_GUARD.md` 的 emergency guard 债（trigger = H3 本身）**必须在同一次改动内偿还**（AC10 第一笔）；`docs/ai/HANDOFF.md` 的 `[DEBT]`「`~/.dsh` 人工同步无落账规范」（trigger = 「首次用 install.ps1 覆盖 `~/.dsh` 之前」）**经人类 2026-09-15 裁决在本任务内一并偿还**（AC10 第二笔 + `IMPLEMENTATION_PLAN.md` Execution Step 9；由**人类**执行真实部署，agent 只读核验落账）。

## Acceptance Criteria（含 Frozen Acceptance；review-sensitive）

> **冻结声明**：下列条款在实现开始前冻结。实现期不得从当前实现反推预期值；修订只能经人类裁决（记「人类裁决 / Amendment」+ 日期）。
> **修订记录（批准前属正常规划迭代，不构成 Amendment）**：2026-09-15 依 **9P round 1**（该轮因 Reviewer 违反零写入而**作废**，见 `docs/ai/review_9P.md`）的 B1/B2 与 A1/A2 修订：① 冻结输入域由 7 类重划为 **K1–K9**（把「真部署类开关」从"非破坏性开关"里拆出，并补齐路径取值的取值域）；② 新增**执行前置约束与机械互锁**（下节）；③ AC1 的零副作用断言扩到全部样本、负向对照改为**同形配对**；④ AC5/AC6/AC7 补**集合相等**（双向）而非单向哈希核验；⑤ AC11 的判定改为机械形态。**随后依 9P round 2（`修订后可批准`，6 条 Blocking）再修订**：⑥ 互锁判定**下沉到子进程内**（并给互锁自身加负向对照）；⑦ AC3 的 K9⑤ 样本改由**临时假 repo** 承载（真实仓库不在互锁覆盖范围内，不能用它当部署目标）；⑧ AC5 的 `-NoPluginInstall` 用例改为 **K8 真部署配对**（原表述落在冻结域外且对被测机制无区分力）；⑨ AC9 的两条机械谓词的**域与 pattern 改准**（否则批准 commit 之后按构造不可能通过）；⑩ PLAN/HANDOFF 的 K 域与用例数同步、AC6 期望集合改由测试独立枚举、AC7 增加 shim 与子进程环境回显断言、测试命令改为无落盘产物的 Pester 配置形态。**人类 2026-09-15 的三项裁决（批准门问答）**：⑪ **插件清单 5 → 6**（`install.ps1` 补上 `clangd-lsp`；依据见 AC5）——AC2 的"6 个插件名"、AC5 的部署集合、README 的"5 个官方插件"叙述随本任务同改；⑫ D3 的 `SKIPPED` 边界**维持**（CLI 缺失 → 退出码仍 0，汇总逐行可见）；⑬ **`~/.dsh` 人工同步债在本任务内一并偿还**（落账规范进 README + 首次自动部署由人类按 runbook 执行并落账，见 AC10 末段）。**再依 9P round 3（`修订后可批准`，5 条 Blocking）修订**：⑭ 前置约束 3③ 补**可满足性实测**（B-1 被反证：PATH 目录顺序优先，`claude.cmd` shim 可用）；⑮ K8 明确"属全部三个参数集"，Testing Plan 去掉无意义的手工组合（B-2）；⑯ AC1 的配对通过样本**逐字冻结**并规定 K7 必须用 `ParameterSetName` 实现（B-3）；⑰ Non-Goals/Constraints 与 AC10 第二笔对齐、该笔改为**承诺项**（B-4/B-5）；⑱ 落 S-1（`[U]` 落点写准为 §5 第 5/6 项）、S-2（每用例新建临时树）、S-3（`[DELETE]` 起首行断言）、S-4（`install.ps1` 纯 ASCII + 5.1 输出无乱码）、S-5（`-ClaudeDir` 落在源树内的混叠样本）、S-6（AC10 的可执行谓词）、S-7（PLAN 两处陈旧文字）；⑲ A-1（干净 K6 样本，禁止位置绑定）。**再依双审 round 1 与人类 2026-09-15 裁决修订（Amendment）**：⑳ AC9① 的域排除 `tests/**` 并改为否定过滤（原形态与 AC11(a) 冲突、按构造不可能满足）；㉑ AC1/AC2/AC4 的零写入域按实测收窄为**三个部署目标根**（宿主自产物不计）；㉒ `AUTHORITY_CONTRACT.md` 的 2026-09-06 增补块**声明为历史、不属 AC9② 判定域**。三条均为人类裁决，日期 = 2026-09-15。批准后这些条款即冻结。
> **冻结输入域（守护类 AC 的等价类封闭依据）**：本任务「机制 X 拒绝 Y」类声称的输入域 = **`install.ps1` 的参数面调用形态**，闭集枚举如下（9 类；K4–K7 与 `INSTALLER_GUARD.md` 的 7 行拒绝矩阵同源，按新参数面扩展并补齐取值域）：
> * **K1** 无参数（= 真部署；只在 AC7 的隔离 HOME 下使用）
> * **K2** `-DryRun` 单跑（非破坏性计划态）
> * **K3** `-ValidateOnly` 单跑（非破坏性校验态）
> * **K4** 已移除的确认开关：`-IUnderstandThisReplacesLiveConfig`、`-IUnderstandThisReplacesLiveConfig:$false`（**两种拼写**）
> * **K5** 拼写错误参数：`-DyrRun`
> * **K6** 位置参数：`DryRun`（无 `-`）
> * **K7** 互斥组合：`-DryRun -ValidateOnly`
> * **K8** 真部署类开关：`-NoPluginInstall`——**在真部署语境里单独出现即为真部署**（只抑制插件步），**不得与 `-DryRun`/`-ValidateOnly` 混为一类"非破坏性开关"**；同时它**属于全部三个参数集**，故 `-DryRun -NoPluginInstall` 是合法调用（在计划/校验态下该开关不改变结论，因为这两态本就不执行插件步——验证"插件步被抑制"这件事只能在真部署语境下做，见 AC5）。
> * **K9** 路径参数取值域（`-ClaudeDir` / `-CodexDir` / `-DshDir`）：① 目录已存在 ② 目录不存在 ③ **该路径已存在且是文件** ④ 两个参数指向**同一个**路径 ⑤ 指向**仓内源树或仓库自身**
>
> 各 AC 的样本必须取自该闭集；Reviewer 主张「还有一类未覆盖」时须给出域内**具体反例**（能实际触发漏过的调用），给不出则记 Non-Blocking Suggestion。
> **执行前置约束（本任务全部用例共同适用，违反即用例失败）**：
> 1. **调用形态固定**：`pwsh -NoProfile -File <被测 install.ps1 的实际路径> <args>`（AC8 用 `powershell.exe` 同形）；**其所在目录即该用例认定的「源树」**（AC3 的假 repo 用例即此形态）。**不得混用** `&` / `-Command` 形态（同一断言在不同形态下的诊断与退出码不同）。
> 2. **目标必须显式隔离**：每次子进程调用必须显式传 `-ClaudeDir`/`-CodexDir`/`-DshDir` 指向临时目录；K1 另需在子进程内把 `$env:USERPROFILE` 指向临时 HOME（AC7）。
> 3. **机械互锁（2026-09-15 事故后新增；判定在子进程内，不在辅助函数的"预期值"上）**：用例生成的 wrapper 脚本必须在**子进程内**断言 ① 生效的 `$env:USERPROFILE` == 期望临时 HOME；② 由它解析出的三个目标路径 == 期望临时路径且**任一都不在**真实 `$env:USERPROFILE` 的 `.claude`/`.codex`/`.dsh` 之下；③ `(Get-Command claude).Source` 指向 fake shim（本机**确实**装有真实 `claude`：`Get-Command claude` → `%APPDATA%\npm\claude.ps1`，故这条是硬门）。任一条不成立 → wrapper 以非零退出且**不调用** `install.ps1`。**该互锁自身必须有负向对照**：用真实 HOME 路径构造的调用 → 判定辅助函数失败且**未启动子进程**（以哨兵文件不存在为证）。
>    * **③ 的可满足性已实测（回应 9P round 3 的 B-1，该条被反证）**：在临时目录放 `claude.cmd` 并把该目录前插 `PATH` 后，`Get-Command claude` → **该 shim**（`Application …\Temp\shim-…\claude.cmd`），真实 npm launcher 退居其后；即 **PATH 目录顺序优先于扩展名优先级**，故 `claude.cmd` 作为 shim 可用，不必改名为 `.ps1`。原始输出见 `docs/ai/review_9P.md` → round 3 的 Author 代跑节。
> 4. **判定环境冻结**：所有用例在临时目录内构造目标树与临时 HOME，绝不触碰真实 `~/.claude` / `~/.codex` / `~/.dsh`（AC7 只**读**真实受管面的哈希）；**任何用例的"源树"都不得用真实仓库自身充当 `-DshDir`/`-ClaudeDir` 的目标**（K9 ⑤ 的样本改用临时假 repo 承载，理由见 AC3）。
>
> **本节的来历（2026-09-15 事故，强制记录）**：9P round 1 的 Reviewer 违反零写入，在真机上执行了 `install.ps1 -IUnderstandThisReplacesLiveConfig`，导致 `~/.claude/workflow/` 的 106 个本机独有文件（`archive/**` 82 + 旧 `*.bak-*` 24）、`rules/` 6 个、`commands/` 15 个被删，并生成含 `.credentials.yaml` 副本的 `~/.dsh.bak-<stamp>`。**已按人类批准以纯增量方式从部署快照恢复**（85/116/22，零内容差异），凭据备份副本已删除。完整事实、命令与恢复证据见 `docs/ai/review_9P.md` → round 1 事故节。**上面前置约束 1/3 即由该事故直接导出。**

### AC1 — 参数面在绑定阶段失败、且全部样本零副作用（守护类）

* **性质**：K4 / K5 / K6 样本（以及 K7 的互斥组合）**在参数绑定阶段失败**（退出码 ≠ 0），诊断信息指向参数本身；并且**本 AC 的每一个样本（含通过侧）都不产生任何写入**——**三个部署目标根**（`.claude` / `.codex` / `.dsh`）的递归内容哈希前后逐字节相同（**临时 HOME 内的宿主自产物不计**：pwsh 按 `USERPROFILE` 推导 known folder 并写 `<home>\AppData\Local\Microsoft\PowerShell\*`，本机实测把 `LOCALAPPDATA` 重定向过去无效——**人类 2026-09-15 裁决（Amendment）** 按实测收窄该域，避免按字面不可满足的断言）、无新建目录、无 `*.bak-*`。
* **判定方式（命令 + 退出码）**：`参数面` 用例组（由 AC9③ 冻结的 Pester 配置形态驱动）逐样本断言：① 子进程退出码 ≠ 0（失败侧）/ = 0（通过侧）；② stderr 或 stdout 含 PowerShell 绑定诊断（`A parameter cannot be found that matches parameter name` 一类）或本脚本自己的互斥诊断；③ 判定前后哈希清单相同；④ 该用例已满足「执行前置约束」1–3（否则用例自身失败）。
* **配对通过样本逐字冻结（B-3）**：全部 5 对使用的通过侧命令**逐字为** `-DryRun -ClaudeDir <T>\claude -CodexDir <T>\codex -DshDir <T>\dsh`（`<T>` = 该用例的临时 HOME；**不带任何**被移除开关 / 错拼 / 位置参数 / `-NoPluginInstall`）。**实现约束**：K7 的互斥**必须由显式 `ParameterSetName` 在绑定阶段实现**（`-DryRun` 与 `-ValidateOnly` 各成独立集；三个路径参数与 `-NoPluginInstall` 属全部三个集），**不得**用"放通配集 + 函数体内检查"实现——否则上述通过侧样本的判定会随实现方式改变。
* **负向对照（同形配对，消掉"环境失败"混杂因子）**：每个失败样本都配一条**同一命令行、只把出错 token 换成合法 token** 的样本，断言后者退出码 = 0：
  | 失败样本（期望 ≠0） | 配对通过样本（期望 =0，逐字如上） |
  |---|---|
  | `-DyrRun …`（K5） | `-DryRun -ClaudeDir <T>\claude -CodexDir <T>\codex -DshDir <T>\dsh` |
  | `DryRun …`（K6，无 `-`） | 同上 |
  | `-IUnderstandThisReplacesLiveConfig …`（K4） | 同上 |
  | `-IUnderstandThisReplacesLiveConfig:$false …`（K4） | 同上 |
  | `-DryRun -ValidateOnly …`（K7） | 同上 |
* **干净 K6 样本（A-1：去掉未知参数的掺杂）**：`DryRun -ClaudeDir <T>\claude -CodexDir <T>\codex -DshDir <T>\dsh`（三个路径参数都给合法临时值）→ 仍须 ≠0——用以单独证明"位置参数被 `[CmdletBinding()]` 在绑定期拒绝"，而不是被未知参数顺带带红。**实现约束**：不得给任何参数加位置绑定（`Position=…`）。
* **样本计数（覆盖声明）**：失败样本 = 5（K4×2 + K5×1 + K6×1 + K7×1）；配对通过样本 = **同一个 K2 形态（`-DryRun` 单跑）被上述 5 对复用**；另有 **K3（`-ValidateOnly` 单跑）作为独立通过样本**，不与配对表混算。

### AC2 — `-DryRun` 零写入且计划完整

* **性质**：`-DryRun` 退出码 = 0；**零写入**（三个部署目标根哈希不变、无 `*.bak-*`、不存在创建的目录；临时 HOME 内的宿主自产物不计，见 AC1）；输出含「将被删除的、仅存在于本机的路径」逐条清单（以 `[DELETE]` 起首的行），且含将被安装的 **6 个**插件名。
* **判定方式**：Pester 用例（**运行环境 = 临时目标树 + 临时 HOME + fake `claude` shim 的 PATH 前插，满足前置约束 2/3；不满足即用例失败**）：预置临时目标树（含白名单样本 `workflow/archive/old/e.md`、`workflow/AGENTS.md.bak-20260101-000000`、非白名单样本 `workflow/stray.md`、机器态样本 `settings.local.json` / `settings.yaml` / `sessions/s.json` / `.credentials.yaml` / `config.toml`）→ 跑 `-DryRun` → 断言 ① 退出码 0；② 全部样本哈希不变且 `stray.md` 仍在；③ **存在以 `[DELETE]` 起首且含 `stray.md` 绝对路径的行**（S-3：只断言"含该路径"会被 `[PLAN] copy …` 之类命中而不具区分力），且**不存在以 `[DELETE]` 起首、含白名单样本路径的行**；④ stdout 含**全部 6 个插件名**。
* **负向对照**：**同一次运行里的真部署用例**（不带 `-DryRun`，同样在临时 HOME + shim PATH 下）断言 `stray.md` **被删除**、受管文件被覆盖为新内容——证明「零写入」不是恒真谓词。**该负向对照本身也是真部署，因此它与被测用例受同一组前置约束；未隔离即用例失败。**

### AC3 — `-ValidateOnly` 结论可复现、能点名失败项，且与真部署共用同一判定

* **性质**：前置条件齐备 → 退出码 0 并打印逐项检查结果；源缺失 / 目标不可写 / 目标自冲突 / 目标落在仓内 → 退出码 ≠ 0 且**点名**具体路径或参数。**同一份校验谓词必须先于真部署执行**（`-ValidateOnly` 只是"只校验不执行"的形态，不是另一套逻辑）。
* **判定方式**：Pester 用例六个（全部满足前置约束 1–3；**用例 2–6 一律在临时「假 repo」内进行**——见下方 B5 说明）：
  1. 只在临时目录放**完整源树 + `install.ps1` 副本**的「假 repo」→ `-ValidateOnly` 退出码 0；
  2. 同一假 repo 删掉 `claude/settings.json` → 退出码 ≠ 0 且输出含该路径；
  3. **K9 ③**（`-ClaudeDir` 指向一个已存在的**文件**）→ 退出码 ≠ 0 且输出点名该路径；
  4. **K9 ④**（`-ClaudeDir` 与 `-CodexDir` 指向**同一个**临时路径）→ 退出码 ≠ 0 且输出同时点名两个参数；
  5. **K9 ⑤**（`-DshDir` 指向**该用例的假 repo 源树自身**；**另加 `-ClaudeDir` 指向假 repo 内的 `claude\` 子目录**——S-5：覆盖"落在源树内"与"目标是目录"两种形态的混叠，防止实现只在 `-DshDir` 上做源树自检）→ 退出码 ≠ 0 且点名该路径；
  6. **执行路径同判定**：用例 4 或 5 的命令行**去掉 `-ValidateOnly`**（即真部署形态）→ 仍退出码 ≠ 0，且临时 HOME 与该假 repo **零写入**（哈希清单不变）。
* **为什么用例 5/6 必须用假 repo（B5，2026-09-15 事故同类风险）**：真实仓库位于 `$env:USERPROFILE` 之下但**不在** `.claude`/`.codex`/`.dsh` 之下，因此机械互锁覆盖不到它。若拿真实仓库当 `-DshDir`，一旦被测实现漏了这条自检，破坏就会落在**规范事实源仓库工作树**上（覆盖仓根 `AGENTS.md`、写出 `*.bak-*`、把 `dsh/**` 落到仓根）——而唯一的探测手段是事后的哈希断言，**挡不住写入**。改用假 repo 后，判定力（"目标落在源树内 → 拒绝"）不减，破坏上限被限制在临时目录。
* **负向对照**：用例 2–6 即用例 1 的对照（同一判定在用例 1 上不失败）；用例 6 是"校验谓词真的挡在部署前面"的对照（若部署路径不调用该校验，用例 6 会实际执行部署 → 哈希变化 → 判定失败）。

### AC4 — keep-local-only 白名单（双向可判定）

* **性质**：mirror-replace 只删「源里没有且不在白名单」的文件。**白名单（冻结闭集，应用于每个被镜像目录）** = ① `archive/**`（本机证据归档）② `*.bak-*`（安装器产生的回滚副本）③ 机器态与登录态（`settings.local.json`、`settings.yaml`、`sessions/**`、`storages/**`、`.credentials.yaml`、`.credentials.json`、`auth.json`、既有 `config.toml`）——③ 类不在受管目录内，故要求的是「不被删改**也不被复制**」。
* **判定方式**：Pester 用例（**运行环境 = 临时目标树 + 临时 HOME + fake shim PATH，满足前置约束 2/3**）：真部署到**预置的**临时目标树后断言 ① `archive/**` 与 `*.bak-*` 样本哈希不变；② 机器态样本哈希不变；③ 临时 HOME 内**不存在**任何 `*.bak-*` 目录或文件包含这些机器态样本（用样本文件的 SHA-256 在临时 HOME 内全树反查，零命中）；④ **每个在部署前已存在的**被镜像目录旁**存在**一个新的 `<目录名>.bak-<stamp>` 回滚副本（`Backup-IfExists` 只在目标存在时备份，故本断言限定为预置过的目标——否则临时 HOME 里新建的目录恒无备份，会假红）；⑤ 临时 HOME 内**不存在**任何整树备份（如 `~/.dsh.bak-<stamp>`）。
* **负向对照**：同一次运行中断言非白名单样本 `stray.md` **确实被删除**——证明该判定不是「永不删」的恒真谓词。

### AC5 — 插件步离线可测、`-NoPluginInstall` 生效、失败可见

* **性质**：真部署对**部署集合里的 6 个插件**各调用一次 `claude plugin install <name>@claude-plugins-official`（6 = `context7` / `chrome-devtools-mcp` / `pyright-lsp` / `typescript-lsp` / `frontend-design` / **`clangd-lsp`**；命令行语法中的引号在传给原生命令时会被去掉），调用 argv 被 fake shim 逐条记录；`-NoPluginInstall` **单独出现（K8）时为真部署但插件步零调用**；任一插件返回非零 → 汇总报告该项失败且进程退出码 ≠ 0。
* **6 个的来历（人类 2026-09-15 裁决：本任务内一并修）**：`[证据]` `claude/settings.json:58` 启用 `clangd-lsp@claude-plugins-official`（与其余 5 个同一 marketplace）；`claude/CLAUDE.md:151` 把 `clangd-lsp` 列为 LSP 后端之一；上一任务（2026-09-06 Routine）明确"补录 `clangd-lsp`"并把该条从 live 反向晋升进仓（见 `docs/ai/archive/2026-09-06-agent-reference-and-phase-rulings/HANDOFF.md`）。**陈旧的是安装器那份硬编码清单**，故修法 = 给 `install.ps1` 补上第 6 个，而不是从 `settings.json` 删掉一个刻意安装的插件。
* **判定方式**：Pester 用例三个（**全部为真部署形态**，运行环境 = 临时目标树 + 临时 HOME + fake shim PATH，满足前置约束 1–4；shim = 临时目录下的 `claude.cmd`，把 `%*` 追加到日志文件并按 `CLAUDE_SHIM_EXIT` 退出）：
  1. **配对基准（不带 K8）**：真部署 → shim 日志行数 **==** 部署集合里的插件数，且**去引号后的 token 序列**逐条等于 `plugin install <name>@claude-plugins-official`；退出码 0；
  2. **配对对照（K8 单跑）**：同一命令行**只多一个 `-NoPluginInstall`** → shim 日志**不存在或为空**、退出码 0，且汇总里 `plugins=0 skipped=<n>` 与部署集合一致；
  3. shim 强制 `CLAUDE_SHIM_EXIT=1` → 进程退出码 ≠ 0 且汇总点名该插件。
* **argv 比对口径（N2）**：PowerShell 向原生命令传参会去掉语法引号，且本机实测 shim 回显含转义痕迹，故**冻结为「去掉 `"` 后的 token 序列相等」**，不做含引号的字面比对（避免假红）。
* **负向对照**：用例 2 即用例 1 的对照（两者只差一个 token）——若实现忽略 `-NoPluginInstall`，日志会有 5 行 → 判定失败。（注：dry-run/validate 路径本就不调用插件步，故**不能**用它们充当该对照——那是恒真的。）

### AC6 — 部署后自检 + 汇总（不是裸 `Done`）

* **性质**：真部署退出码 = 0 **当且仅当**（a）**文件集合双向相等**：源树受管集合里的每个相对路径都在目标存在，且目标里没有源树之外的**非白名单**残留；（b）每个共有文件的内容哈希 == 源哈希；（c）汇总的 `[SUMMARY] deployed=<n>` 的 `n` == 期望文件数。任一复制/自检/集合核对失败 → 退出码 ≠ 0 且点名该路径。汇总同时给出插件步逐项结果与「未被部署的机器态清单」。
* **判定方式**（**运行环境 = 临时目标树 + 临时 HOME + fake shim PATH**）：① 正常部署用例断言退出码 0、stdout 含每个受管目标的 verified 行、源/目标**集合双向相等**且哈希逐对相等。**期望集合由测试独立从源树枚举**（`claude/{CLAUDE.md,settings.json,rules/**,workflow/**,commands/**}` + `codex/AGENTS.md` + `dsh/AGENTS.md` + `dsh/workflow/**` + `dsh/skills/{dual-agent-workflow,independent-review}/**`），**禁止调用被测脚本的内部函数**取期望集合，`[SUMMARY] deployed=<n>` 的期望值同源（N3）；② **缺项样本**：部署后从目标树删掉一个受管文件，再用同一判定重算 → 判定必须失败（证明集合核对不是恒真）；③ 破坏性样本：把 `-ClaudeDir` 下目标 `CLAUDE.md` **预先建成目录** → 断言退出码 ≠ 0 且点名该路径。
* **负向对照**：② / ③ 即 ① 的对照（同一判定在 ① 上不失败）。

### AC7 — 无参数默认路径在隔离 HOME 下可完整执行（首次可测）

* **性质**：在子进程 `pwsh -NoProfile` 中把 `$env:USERPROFILE` 指向临时目录、把 fake `claude.cmd` 置于 `PATH` 首位后，运行 `install.ps1`（**K1：不带任何参数**）→ 退出码 0；临时 HOME 下三处受管面被真实部署，且**目标文件集合 == 源文件集合（双向）**、逐对内容哈希相等；**真实** `~/.claude` / `~/.codex` / `~/.dsh` 的受管面哈希前后不变。
* **判定方式**：Pester 用例起子进程执行上述调用（形态固定为 `pwsh -NoProfile -File`）并断言七点：① 退出码；② 集合双向相等；③ 哈希逐对相等；④ `[SUMMARY] deployed=` 与实测文件数一致；⑤ 真实受管面哈希清单前后相同（用例内计算，只读）；⑥ **shim 日志行数 == 部署集合里的插件数**（若 PATH 前插失效，本机**确实存在**真实 `claude`，会发生真实网络安装而判定仍可能全绿——故这条是硬门，N5）；⑦ **子进程回显生效的 `$env:USERPROFILE` 与三个解析后目标**（作为"隔离覆盖确实生效"的机械证据，B6③）。此外，整个套件运行结束后**仓内 `git status --porcelain` 必须与套件开始前一致**（测试产物只落 `$env:TEMP`；该断言把"测试自己污染仓库"也纳入可判定范围）。
* **负向对照**：若默认语义被误做成 dry-run，临时 HOME 内将没有任何受管文件 → 集合相等与哈希断言失败。故「临时 HOME 内文件集合与源集合双向相等」本身即对默认语义的区分力来源。

### AC8 — Windows PowerShell 5.1 兼容不退化

* **性质**：`powershell.exe -NoProfile -ExecutionPolicy Bypass -File install.ps1 -DryRun -ClaudeDir <temp> -CodexDir <temp> -DshDir <temp>` 在 5.1 下退出码 = 0，零写入，**且输出无乱码**；`install.ps1` 本身**保持纯 ASCII**（S-4：本仓 UTF-8 无 BOM，而 5.1 按 ANSI 代码页读 `-File` 脚本——本机 CP936；实测现有脚本里 7 处 em dash 在 CP936 下读成 `鈥?`。注释乱码不影响运行，但输出乱码会污染人类 runbook 的可读性，且这是零成本的机械约束）。
* **判定方式**：Pester 用例（或 `last_test_run.txt` 中的直接命令）记录真实退出码（本机 `powershell.exe` = 5.1.26100.9444）；**另加两条机械判据**：① `(Get-Content -Raw install.ps1) -match '[^\x00-\x7F]'` → `False`（零非 ASCII 字节）；② 5.1 实跑的完整 stdout 中不存在 `鈥`/`ï¿½` 一类乱码字符（把该 stdout 存入 `last_test_run.txt` 供人读）。
* **负向对照**：同一命令在 pwsh 7 下同样退出 0（排除「只是 5.1 恰好不报错」的解读）；解析失败/语法不兼容会直接体现为非 0 退出码。**纯 ASCII 判据的负向对照**：在 base `e9917a1` 上跑同一判据 → `True`（现有脚本含 7 处 em dash），证明该判据有区分力。

### AC9 — 文档与代码同 patch 一致（可复现、有区分力）

* **性质**：① 已移除开关的字面量除历史记录外零引用；② README / 根 `AGENTS.md` / `claude/rules/README.md` / `AUTHORITY_CONTRACT` 不再声称「迁移期锁定」「整树备份会复制凭据」；③ 根 `AGENTS.md` 的 Build/Test/Lint 节列出真实存在的新测试命令。
* **判定方式**：
  ① `git grep -n 'IUnderstandThisReplacesLiveConfig' -- . ':(exclude)docs/ai/**' ':(exclude)tests/**'` 的输出里**不得存在「现在时声称该开关仍存在/仍可用」的行**——判定形态 = 对该 grep 的命中行做否定过滤（`Where-Object { $_.Line -notmatch '已移除|不再是参数|removed|no longer' }` → **零命中**）。**人类 2026-09-15 裁决（Amendment）**：原冻结形态要求「`docs/ai/**` 之外零出现该字面量」，但 ① 它与 AC11(a)（要求脚本注释登记「已移除机制」）**互相冲突**，② `tests/**` 必须引用该 token 才能断言绑定期拒绝——按构造不可能满足；故域排除 `tests/**`，并把判定换成与 AC9② 同形的否定过滤。_修订前形态：`-- . ':(exclude)docs/ai/**'` → 零命中。_
  ② **失效声称零命中**（不是"这个词零命中"——新文案必须能说"不再整树备份"，否则会迫使 Author 删掉真实披露，B2）：`git grep -n 'MORATORIUM-LOCAL-001' -- README.md AGENTS.md install.ps1 claude/rules/README.md docs/ai/AUTHORITY_CONTRACT.md` → 零命中；且 `Select-String -Path README.md,AGENTS.md,claude/rules/README.md,docs/ai/AUTHORITY_CONTRACT.md -Pattern '整树备份' | Where-Object { $_.Line -notmatch '不再|已移除|H3' }` → 零命中；
  ②b **人类 2026-09-15 裁决（Amendment）**：`docs/ai/AUTHORITY_CONTRACT.md` 的「2026-09-06 增补」块**属绑定旧 commit 的历史记录，不属本判定域**（该行本就含 `H3`，否定过滤对它无区分力 = 假绿；计划改动 #11 亦明确「只加日期订正、不改历史陈述」）。判定只覆盖 README / 根 `AGENTS.md` / `claude/rules/README.md` / `install.ps1` 的**现在时**声称；该历史句已就地加「已失效」标记供读者识别。
  ③ 测试命令形态（N4 修订）：`pwsh -NoProfile -Command "$c = New-PesterConfiguration; $c.Run.Path = 'tests'; $c.Run.Exit = $true; $c.TestResult.Enabled = $false; Invoke-Pester -Configuration $c"`，且该命令在 `AGENTS.md` 中被登记（`git grep -n 'New-PesterConfiguration' -- AGENTS.md` ≥1 命中），实跑退出码 0，**且仓根不出现 `testResults.xml`**。
* **负向对照**：① 同一 grep 在 base `e9917a1` 上运行 → **非零命中**（记录命中数与样本行）；② 同域 `Select-String -Pattern '整树备份'`（不加否定过滤）在 base 上命中 README/`AUTHORITY_CONTRACT` 的现存陈述 → 证明否定过滤不是恒真；③ 用 `Invoke-Pester -Path tests -CI` 形态实跑一次 → 仓根**出现** `testResults.xml`（证明 ③ 的"无产物"断言有区分力；该产物记录后立即删除并复跑 `git status` 确认干净）。

### AC10 — Payback-on-Touch：guard 债在同一次改动内偿还且不删历史

* **性质**：`docs/ai/INSTALLER_GUARD.md` 的 `[DEBT]` 条目被标注为**已偿还**并给出偿还证据（本任务的 commit 与验证命令）；其 7 行证据表与 H3 继承要求**保留为历史**（不整段删除）；`docs/ai/HANDOFF.md` 的 Debt 台账同步更新（新任务账本建立、历史条目不静默消失）。
* **判定方式**：① `Select-String -Path docs/ai/INSTALLER_GUARD.md -Pattern 'Repaid'` 命中该债条目行；② 该文件仍含 7 行证据表全部 7 行与 5 条继承要求——**给出可执行谓词（S-6）**：`(Select-String -Path docs/ai/INSTALLER_GUARD.md -Pattern '^\|\s*[1-7]\s*\|').Count` == 7，且 `(Select-String -Path docs/ai/INSTALLER_GUARD.md -Pattern '^\d+\.\s').Count` == 5（两条命令与输出落 `last_test_run.txt`）；③ `docs/ai/HANDOFF.md` 的 `[DEBT]` 行数 ≥ 既有笔数（不减少）。
* **负向对照**：`[DEBT]` 行数若减少 → 判定失败（防「删债当偿还」）；把 7 行证据表删掉一行 → ② 的计数判据失败。
* **第二笔债（`~/.dsh` 人工同步无落账规范；人类 2026-09-15 裁决 = 本任务内一并偿还）**：
  * **性质**：① README 出现**可执行的落账规范**（每次部署记录：命令 + `[SUMMARY]` + 备份路径；`~/.dsh` 运行副本不再靠人工同步）；② **首次自动部署由人类按 runbook 对真实 `~/.dsh` 执行**（本任务内完成；agent 不自行执行破坏性真机动作），其命令与 `[SUMMARY]` 真实输出记入 `docs/ai/HANDOFF.md` Work Log 与 `docs/ai/DSH-LANDING-NOTES.md` §4；③ 该 `[DEBT]` 行**只在真实部署确实发生之后**才标"已偿还"——不得预先宣告。
  * **判定方式**：`git grep -n 'SUMMARY' -- README.md` ≥1 命中（落账规范在位）；`Select-String -Path docs/ai/HANDOFF.md -Pattern '首次自动部署'` ≥1 命中且该处给出 `[SUMMARY]` 真实输出；**`~/.dsh` 的受管面旁存在 `*.bak-<stamp>`**（人类执行后由 Author 只读核验并记录命令与输出）。
  * **B-5：这是承诺项，不是尽力项（不得两边都自洽收口）**：人类 2026-09-15 已裁决"本任务内一并偿还"，故 **未执行 → AC10 第二笔不成立 → 本任务不得标"已收敛 / Ready to Commit"**，且 `/final-review` 的 Manual Check Before Commit 必须把它列为未闭合项。**唯一的合法例外**：人类在执行时点给出**新的明确裁决**（如"改为延期"），该裁决记入 `HANDOFF.md`（日期 + 一句话），AC10 随该裁决改为"已获人类批准延期"（Deferred）——**不得由 Author 自行降级或预先宣告**。
  * **负向对照**：人类执行**之前**用同一判定跑一次 → 必须**不通过**（实测：事故前的本机核验 = `~/.dsh` 下没有任何 `*.bak-*`）——证明该分支要求的是真实发生过的部署，而不是文档措辞。

### AC11 — 未验证清单 `[U]` 的触发点处置（不构成收敛门的额外产物）

* **性质**：`docs/ai/HANDOFF.md` → Known Issues 的 `[U]` 第 6 项（`install.ps1` 其余注释逐句对读，触发 = 下次改动该文件之前）在本任务被**实际执行**并以机械残留检查收口（`install.ps1` 的注释不得再描述已移除的机制；注释中出现的每个机制名必须能在代码中找到对应实现点）；第 5 项（AC8 机器态实跑）由 AC7 的隔离 HOME 实跑等价覆盖，**两处文档（HANDOFF.md 与 `DSH-LANDING-NOTES.md` §5）必须同步改**（该「逐条一致」不变式源自上一任务 AC9，仍然有效）。
* **判定方式（机械形态，两条方向相反的谓词）**：
  * **(a) 注释 → 代码**：从 `install.ps1` 的注释行中抽取全部 `-<Switch>` 形式的参数名与 `~/.<path>` 形式的路径字面量（`Select-String` 正则，输出即产物），断言每一个要么出现在代码的 param 块 / 路径常量中，要么出现在脚本注释的**显式清单**里。该清单分两类，缺一类会把**正确**的注释误判为红（N8）：**已移除机制**（逐项写替代物）与**刻意不部署机制**（如 `~/.claude/projects/*/memory`，逐项写理由）——例如 `~/.dsh/settings.yaml`、凭据路径属后者。
  * **(b) 代码 → 注释**：反向枚举 param 块的全部参数名与路径常量，断言注释块对每一个都有对应说明。
  * 产物 = 两条 `Select-String` 的**完整输出 + 退出码**（落到 `last_test_run.txt`），不是一张人写的对照表。
  * **文档一致性（S-1：落点写准）**：`docs/ai/HANDOFF.md` 与 `docs/ai/DSH-LANDING-NOTES.md` **§5 的「未做/未验证」清单第 5、6 项**必须逐条一致（`Select-String` 取**这两项的新处置文本**比对相等）；**§3 的导读节明确"不再复制条目文本"，故不得回填**——AC11 的机械判据是"这两项文本对相等"，**不是**"两文件全文相等"（后者按构造不成立）。
* **负向对照**：① 把 `install.ps1` 注释里的某个参数名改成代码中不存在的拼写（临时样本，判定后还原）→ (a) 判定必须失败；② 把两处文档之一改回旧文本 → 文档比对失败。

## Relevant User Preferences

* 不夹带无关改动：改动限于 `install.ps1`、根级 `tests/`、以及因行为变化必须同 patch 改准的文档。
* 人类已明确选择 **Critical 全流程**；阶段产物与 SHA 绑定按母本执行。
* 输出说明用简体中文；代码、注释、commit message 用英文。
* 破坏性操作先说明风险；不得静默删除或覆盖任何文件。
