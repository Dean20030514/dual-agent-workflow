# TASK_BRIEF.md — 切片 A（`install.ps1` 参数面 + 两条零写入路径）

> per-task 文件，blind review 的唯一需求依据，必须自洽：只看此文件应能判断实现对不对。
> 骨架出处 = `~/.dsh/workflow/templates/TASK_BRIEF.md`。
> 本文件是验收条款与 **Frozen Acceptance** 的单一事实源（review-sensitive）：实现前冻结，禁从当前实现反推。
> 任务 = **H3 重新拆任务后的切片 A**；分支 `task/h3a-parameter-surface`，base `e9917a1`（= `main`）。

## Dimension Applicability Scan

| # | 维度 | 关注/N/A | N/A 原因 | 关注后展开/验收 |
|---|------|---------|---------|----------------|
| 1 | 产品定位 | N/A | 内部/一次性任务；不满足「真实可发布产品」判据 ①② | — |
| 2 | 用户研究 | N/A | 无外部用户；需求来自人类 2026-09-15 的拆任务裁决（`[证据]` 本仓 HANDOFF / review_9*） | — |
| 3 | 产品策划/PM | 关注 | 切片边界即本任务的核心约束（只做参数面与两条零写入路径） | 下文 Goal / Non-Goals |
| 4 | 交互设计 UX | 关注 | 安装器是面向人类的 CLI：参数面与输出（计划/校验结论/汇总行）就是它的 UX | AC2 / AC3 的输出契约 |
| 5 | 视觉设计 UI | N/A | 无图形界面 | — |
| 6 | 美术/内容表现 | N/A | 无美术资产 | — |
| 7 | 技术开发 | 关注 | 生产面 = `install.ps1`（重写为参数面 + plan 两相） | 全部 AC |
| 8 | 测试/QA | 关注 | 交付含常驻 Pester 套件（本切片只覆盖参数面与两条零写入路径） | AC1–AC3 |
| 9 | 安全/隐私/合规 | 关注 | ① 破坏性意图必须在参数绑定阶段被拒；② 两条零写入路径必须真零写入；③ 目标不得落在源树或机器态面 | AC1 / AC2 / AC3；QUALITY_GATES 11.2 基础组 |
| 10 | 可访问性/普适性 | N/A | 无面向公众的可访问性面 | — |
| 11 | 数据分析 | N/A | 内部任务：成功 = 验收全过 | — |
| 12 | 运营增长 | N/A | 同 11 | — |
| 13 | 商业模式 | N/A | 无商业模式 | — |
| 14 | 品牌 | N/A | 无品牌面 | — |
| 15 | 内容 | N/A（本切片） | 文档改准（README/AGENTS/rules/AUTHORITY_CONTRACT/DSH-LANDING-NOTES）属切片 D；本切片不改这些文件 | — |
| 16 | 客服与用户成功 | N/A | 无外部用户 | — |
| 17 | 项目管理 | N/A | by-trunk：单人单里程碑，由开发主干隐式覆盖 | — |
| 18 | 组织与人才 | N/A | 角色沿用工作流定义（Author / Reviewer / 人类） | — |

**设计层闸门不触发**（第 5/6 维 N/A）；第 4 维的 CLI 交互已转成 AC2/AC3 的可判定输出契约。**`PRODUCT_BRIEF.md` N/A**。

## Original Request

人类 2026-09-15 在 H3 任务 `streak = 2` 硬停后，于三条出路中选择「重新拆任务」，并按 Author 建议选定先做切片 A（在 `main` 上新分支）：「开切片 A（在 main 上新分支）」/「现在就开」。

拆的依据（`[证据]` 两份 verdict + 归档账目）：两轮 4 条 `[Product Blocking]` 全部落在「验收判定形态 + 证据/账目绑定」这一层，安装器行为层只有 2 条（且都已修、都有真实输出）。切片划分见 `docs/ai/HANDOFF.md` → Next Step：A 参数面与两条零写入路径 / B 真部署路径 / C 插件步 / D 文档与验收判定面。

**本切片的历史输入（只读参考，非免审）**：停牌分支 `task/h3-installer-hardening` 的 `install.ps1`（627 行）与 `tests/**`（5 个文件：4 个 `.Tests.ps1` + `TestHelpers.ps1`；用例数见该分支 `last_test_run.txt`）可作起点，但其中每一行都必须落在切片 A 自己的 diff 与审查范围内。

## Goal

把 `install.ps1` 的参数面做成绑定期硬门，并落地两条零写入路径，二者与真部署共用同一个校验谓词：

1. `[CmdletBinding()]` + 3 个 ParameterSet（`Deploy` 默认 / `DryRun` / `Validate`）；6 个参数：`-DryRun`、`-ValidateOnly`、`-NoPluginInstall`、`-ClaudeDir`、`-CodexDir`、`-DshDir`。
2. `-ValidateOnly`：只跑前置校验，零写入，逐项输出 `[CHECK]` 行，全过 → 退出码 0，任一失败 → 1 并点名失败项。
3. `-DryRun`：打印完整计划（将复制什么、将删除哪些"仅存在于本机"的路径、将保留哪些；本切片不执行任何动作），零写入，退出码 0。
4. 单一谓词 `Test-Plan`：真部署路径在写入前调用它，`-ValidateOnly` 打印它的结果——不存在"两套校验逻辑"。
5. 确定的退出码契约（0 = 请求的语义全部达成；1 = 其余一切）与 `[PLAN]` / `[CHECK]` / `[SUMMARY]` 输出契约。
6. 交付常驻 Pester 套件（参数面 + 两条零写入路径 + 围栏负向对照）。

## Non-Goals

* 不实现任何真实写入：不 mirror-replace、不备份、不删除、不复制、不创建目标目录 —— 属切片 B。
* 不实现插件步（`claude plugin install` / `-NoPluginInstall` 的执行语义 / CLI 缺席分支）—— 属切片 C。本切片只冻结参数面里 `-NoPluginInstall` 存在且属三个 ParameterSet。
* 不做部署后自检与汇总（`[VERIFY]` / 逐文件哈希核验 / `[SUMMARY] deployed=` 等计数）—— 属切片 B。
* 不改文档（README / 根 `AGENTS.md` / `claude/rules/README.md` / `AUTHORITY_CONTRACT` / `INSTALLER_GUARD` / `DSH-LANDING-NOTES`）—— 属切片 D；本切片只写自己需要的 `install.ps1` 头注释（纯 ASCII）。
* 不碰 `tools/**`（含封存的 `tools/validate/` 与常驻 AC4 门）、`dsh/**`、`claude/**`、`codex/**`、`portable/**`。
* 不为将来切片预建抽象（不引入插件接口、不把镜像引擎"插件化"）。

## Constraints

* `install.ps1` 保持 Windows PowerShell 5.1 兼容（本机 `powershell.exe` = 5.1.26100.9444）且纯 ASCII（UTF-8 无 BOM + 5.1 按 ANSI 读 `-File` → 非 ASCII 乱码；实测旧版含 7 处 em dash 在 CP936 下读成 `鈥?`）。
* 禁用位置绑定：不得给任何参数加 `Position`（K6 样本要求位置 token 在绑定期失败）。
* K7（`-DryRun -ValidateOnly`）必须由显式 `ParameterSetName` 在绑定阶段实现，不得用"放通配集 + 函数体内检查"。
* 文件编码 UTF-8 无 BOM、行尾 LF（`.gitattributes` 强制）。不要用 `Set-Content`/`WriteAllLines` 写出 CRLF（本轮已出现一次：归档文件的 CRLF 只是被 git 归一化掩盖）。
* 执行型探针的硬规则（2026-09-15 事故导出，强制）：任何执行 `install.ps1` 的探针，跑之前必须先读被执行的那一份脚本、确认该参数在这一版上的语义；"在另一分支/另一版上是安全的"不构成理由。已知会真机部署的形态（旧版 `install.ps1` + `-IUnderstandThisReplacesLiveConfig`）永远不得再跑。测试与人工复核一律遵守：目标必须显式指向临时目录，且只在临时 HOME 下运行。
* 单轮 diff 预算 ≤ 4000 行（只计 `docs/ai/` 之外）；本切片预估远低于预算。
* Payback-on-Touch：本切片改 `install.ps1` → 承接账目里 `[U]` 第 6 项（该文件注释逐句对读）在本切片内履行；`INSTALLER_GUARD` 的 guard 债已由停牌任务偿还并在活树保留。

## Acceptance Criteria（含 Frozen Acceptance；review-sensitive）

> 冻结输入域（守护类 AC 的等价类封闭依据）：本切片「机制 X 拒绝 Y」类声称的输入域 = `install.ps1` 的参数面调用形态，闭集为：
> * K1 无参数（= Deploy 集）：判定**以 Amendment ㉗ 为准**——① 输出**不含**绑定诊断族；② 退出码 **≠ 0**；③ 输出含 `RESULT=REFUSED`；④ **三个目标根零写入**（本切片明确拒绝执行部署；写入行为属切片 B）
> * K2 `-DryRun` 单跑（+ 三个路径参数）
> * K3 `-ValidateOnly` 单跑（+ 三个路径参数）
> * K4 已移除的旧确认开关：`-IUnderstandThisReplacesLiveConfig`、`-IUnderstandThisReplacesLiveConfig:$false`
> * K5 拼写错误参数：`-DyrRun`
> * K6 位置参数：`DryRun`（无 `-`），及其"干净样本"（三个路径参数均给合法临时值）
> * K7 互斥组合：`-DryRun -ValidateOnly`
> * K8 `-NoPluginInstall`（属三个 ParameterSet；其"单独出现即真部署"的语义在切片 C 冻结，本切片的判定见 Amendment ㉕——原"只断言绑定层可接受"经 9P 判为恒真谓词，已替换）
> * K9 路径参数取值域：① 目录已存在 ② 目录不存在 ③ 路径已存在且是文件 ④ 父路径是文件 ⑤ 两个参数指向同一个路径（含尾分隔符变体） ⑥ 指向源树/仓库自身
>
> 各 AC 的样本必须取自该闭集；Reviewer 主张「还有一类未覆盖」须给出域内具体反例，给不出则记 Non-Blocking Suggestion。
> 执行前置约束（全部用例共同适用，违反即用例失败）：① 调用形态固定 `pwsh -NoProfile -File <被测 install.ps1 的实际路径> <args>`（5.1 腿用 `powershell.exe` 同形），不混用 `&`/`-Command`；② 每次子进程调用必须显式传 `-ClaudeDir`/`-CodexDir`/`-DshDir` 指向临时目录；③ 机械互锁（判定在子进程内）：wrapper 在子进程内断言生效的 `$env:USERPROFILE` 与解析出的三目标均为期望临时值且不在真实 `.claude`/`.codex`/`.dsh` 之下，否则非零退出且不调用安装器；互锁自身配负向对照（真实 HOME 路径构造 → 判定失败且未启动子进程，以哨兵文件为证）；④ 判定环境冻结：所有用例只写临时目录，绝不触碰真实受管面。

### AC1 —— 参数面在绑定阶段失败，且全部样本零副作用（守护类）

* 性质：K4 / K5 / K6 / K7 样本在参数绑定阶段失败（退出码 ≠ 0），诊断指向参数本身；每个样本（含通过侧）都不写入任何目标——三个目标根的递归内容哈希前后逐字节相同、无新建目录、无 `*.bak-*`。
* 判定方式：参数面用例组逐样本断言 ① 退出码（失败侧 ≠0 / 通过侧 =0）；② 输出含该样本的参数名 + 绑定诊断族（中英：`找不到与参数名称` / `无法使用指定的命名参数解析参数集` / `parameter cannot be found` / `Parameter set cannot be resolved`）或脚本自己的互斥诊断；③ 前后目标根哈希清单相同；④ 已满足执行前置约束 ①–③。
* 配对通过样本（逐字冻结）：`-DryRun -ClaudeDir <T>\claude -CodexDir <T>\codex -DshDir <T>\dsh`（`<T>` = 该用例的临时 HOME；不带任何被移除开关/错拼/位置参数/`-NoPluginInstall`）。5 对配对：`-DyrRun`↔ 该样本、`DryRun …`↔ 该样本、`-IUnderstand…`(两形态)↔ 该样本、`-DryRun -ValidateOnly`↔ 该样本。
* 负向对照：失败侧样本在同一命令行把出错 token 换成合法 token 后必须退出 0（消掉"环境失败"混杂因子）；另：K6 的干净样本（`DryRun` + 三个合法临时路径）必须仍 ≠0，以单独证明位置参数被 `[CmdletBinding()]` 拒绝。
* 样本计数：失败 5（K4×2 + K5 + K6 + K7）+ 干净 K6 1 + 通过侧 2（K2/K3 各一）+ **K8 三样本**（Amendment ㉕）+ **K1 一条**（Amendment ㉗）。

### AC2 —— `-DryRun` 打印完整计划且零写入

* 性质：`-DryRun` 退出码 0；零写入（三个目标根哈希不变、无 `*.bak-*`、无新建目录）；输出含每一条将执行的动作（本切片：将复制/播种的文件与将镜像的目录），以及将删除（源里没有且非白名单）与将保留（白名单）的逐条清单——即使本切片不执行，计划也必须完整且与切片 B 的执行集合一致。
* 判定方式：临时预置目标树（含白名单样本 `workflow/archive/old/e.md`、`workflow/AGENTS.md.bak-20260101-000000`、非白名单样本 `workflow/stray.md`、机器态样本 `settings.local.json`/`settings.yaml`/`.credentials.yaml`/`sessions/s.json`/`config.toml`）→ 跑 `-DryRun` → 断言 ① 退出码 0；② 三个目标根哈希清单不变且 `stray.md` 仍在；③ 存在以 `[DELETE]` 起首且含 `stray.md` 绝对路径的行、且不存在以 `[DELETE]` 起首含白名单样本路径的行；④ 存在 `[PRESERVE]` 行的白名单样本；⑤ 输出含 `[SUMMARY]` 行；⑥ **祖先/后代互斥（关系型断言）**：任何以 `[DELETE]` 起首的 `(dir)` 行不得是任何以 `[PRESERVE]` 起首的行的路径前缀。白名单闭集（冻结，**子树继承**；2026-09-15 人类裁决 + review 9A round 5 PB-2 改准）：某路径若**自身或任一祖先路径段**含 `archive`（含作为末段），或**自身叶名或任一祖先叶名**匹配 `*.bak-*`，即命中；命中目录之下的一切内容均须 `[PRESERVE]`，且其任何**祖先目录**不得出现 `[DELETE]`。
* 负向对照：① 用一个写入一个文件的等价探针证明哈希清单判定能检出写入（[证据] 本轮实测：写入后签名相同 = False）；② 计划中的 `[DELETE]` 集合与切片 B 执行集合的一致性由切片 B 的复用用例复核（本切片只冻结"计划必须列出"）。
* **A3（受管面一致性；`IMPLEMENTATION_PLAN.md` 已登记，本轮补进 AC2 使其成为冻结条款）**：`-DryRun` 输出的**目标**路径集合必须与旧脚本的受管面清单**集合相等**，用测试侧的独立预言机 `Get-ManagedDeploySet` 判定（不向被测代码问期望——N3）。仅做 needle 包含检查**不算**满足本条（9A round 2 的 NB-2 指出的名不副实问题）。
* **`RESULT=OK` 的语义收窄（冻结措辞）**：`-DryRun` 的 `RESULT=OK` 只表示「计划已完整打印且本模式零写入」，**不**表示「该计划能通过校验」——`Test-Plan` 只在 `-ValidateOnly` 与 Deploy 两条路径执行（9A round 2 的 NB-5）。
* **`-ValidateOnly` 计数器语义（冻结措辞）**：其 `[SUMMARY] planned/delete/preserve` 与 `-DryRun` **同源同值**（同一 `Get-PlanCounters`，模式分支之前计算一次），但该模式只打印 `[CHECK]` 与机器态 `[PRESERVE]` 行，**不**打印计划的 `[DELETE]`/`[PRESERVE]` 行——故其计数**不**与屏幕上可见的行数逐一对应（9B round 2 的 BL-1 处置：同源计算 + 声称收窄）。

### AC3 —— `-ValidateOnly` 结论可复现、点名失败项，且与真部署共用同一谓词

* 性质：前置齐备 → 退出码 0 并打印逐项 `[CHECK]`；源缺失 / 目标不可用 / 根自冲突（含尾分隔符变体）/ 目标落在源树或机器态面内 → 退出码 ≠ 0 并点名具体路径或参数。同一份 `Test-Plan` 谓词必须先于真部署执行（`-ValidateOnly` 只是"只校验不执行"的形态）。
* 判定方式（假 repo 承载，避免把真实仓库当目标）：① 完整源树 + `install.ps1` 副本 → 0；② 删掉 `claude/settings.json` → ≠0 且输出含该路径；③ K9③ `-ClaudeDir` 指向已存在文件 → ≠0 点名；④ K9⑤尾分隔符 `-ClaudeDir <T>\shared -CodexDir <T>\shared\` → ≠0 同时点名两个参数；⑤ K9⑥ `-DshDir` 指向假 repo 源树自身、`-ClaudeDir` 指向其 `claude\` 子目录 → ≠0 点名；⑥ 机器态包含关系：在隔离 HOME 下 `-ClaudeDir <tempHome>\.claude\projects` → ≠0 且 `machine-local-untouched FAIL`；⑦ 执行路径同判定：④/⑤/⑥ 的命令行去掉 `-ValidateOnly` → 仍 ≠0 且假 repo 与临时 HOME 零写入（哈希清单不变）。
* 负向对照：②–⑦ 即 ① 的对照（同一判定在 ① 上不失败）；⑦ 是"校验谓词真的挡在部署前面"的对照（若部署路径不调用该校验，⑦ 会实际执行 → 哈希变化 → 判定失败）。

### 谓词冻结前实跑证据（9B round 2 的硬前置；只允许只读形态）

> 规则：凡在 AC 里写入 Where-Object/Select-String/grep 谓词的，冻结前必须实跑一次该谓词 + 一条负向对照，把命令与输出贴在本节。执行型探针受 Constraints 的硬规则约束；本切片只对"不会真机部署"的形态取证。

* P1（AC1 的 K2 通过样本，今日预跑）：`pwsh -NoProfile -File .\install.ps1 -DryRun -ClaudeDir <T>\.claude -CodexDir <T>\.codex -DshDir <T>\.dsh`（`<T>` = 临时目录）→ 实测 exit 1，输出 `install.ps1: 找不到与参数名称 'DryRun' 匹配的参数。`。解读：本切片实现前该样本失败 → 判定确有区分力；实现后必须转为 exit 0。
* P2（AC2 的"哈希清单能检出写入"，负向对照）：临时树上写入一个文件前后各算一次 `relpath|SHA256` 清单 → 实测 相同 = False。解读：零写入判定不是恒真谓词。
* P3（谓词形态的活教材，本轮事故同源教训）：`git grep -n 'X' -- f | Where-Object { $_.Line -notmatch 'p' }` 在 `git grep` 的 String 输出上恒真（`$null -notmatch` = true）；正确形态是 `$_ -notmatch 'p'` 或 `Select-String -NotMatch`。本切片任何 grep/Select-String 谓词都必须在规划文件里采用正确形态，并附实跑输出。
* **P4（K1/K4 依赖的绑定诊断族，2026-09-15 实跑；用临时脚本，未碰 install.ps1）**：参数集冲突 → `exit=1` + `probe.ps1: 无法使用指定的命名参数解析参数集。…`；未知参数 → `exit=1` + `probe.ps1: 找不到与参数名称 'DyrRun' 匹配的参数。`；位置参数 → `exit=1` + `probe.ps1: 找不到接受自变量 'DryRun' 的位置参数。`。**解读**：诊断族四式与本机真实文案一致，且 K8 的负向对照（`-NoPluginInstall -DryRun -ValidateOnly`）确在**绑定期**失败——非恒真。
* **P5（机器态包含关系的新样本，2026-09-15 实跑；纯函数级只读）**：以 `~/.claude/projects` 为父，段式 `Test-PathInside` 对 `projects`/`projects\x` 判命中、对 `projects-x`/`projects.bak-20260101-000000` 判不命中；朴素前缀匹配会把后两者**误判为命中**。**解读**：Amendment ㉓ 新增的两个样本确有区分力（能分开"包含关系"与"仅前缀匹配"）。
* **仍属实现后才能跑的谓词**：K2/K3 通过样本、`-DryRun` 零写入、`-ValidateOnly` 各失败样本——红→绿对照按 Amendment ㉛ 在 `/implement` 落 `last_test_run.txt`。
* 不可预跑的样本（K4 旧开关）：在本分支禁止执行（旧脚本会释放 guard → 真机部署；见 HANDOFF Known Issues 的事故记录）。其"实现后必须失败"的判定只在实现后、且只在临时 HOME + 显式临时目标下跑。

## Relevant User Preferences

* 不夹带无关改动；切片边界（Goal/Non-Goals）是硬约束。
* 人类已明确选择 Critical 全流程（9P → 批准门 → 实现 → 9B/9A 双审）。
* 输出说明用简体中文；代码、注释、commit message 用英文（Conventional Commits）。
* 破坏性操作先说明风险；任何执行安装器的动作都必须在临时目标 + 临时 HOME 下，并遵守 Constraints 的探针硬规则。

## Amendment（人类 2026-09-15 裁决；9P round 1 的整改；批准后随之冻结）

> 触发：9P round 1 判 `修订后可批准`（4 Blocking + 6 Suggestion + 3 Assumption Challenge）。以下更改**均由人类批准**，日期 = 2026-09-15。

* **㉓ 机器态闭集（冻结，AC2/AC3 共用）**：`.claude/settings.local.json` · `.claude/.credentials.json` · `.claude.json` · `.claude/sessions` · `.claude/projects` · `.codex/auth.json` · `.dsh/settings.yaml` · `.dsh/.credentials.yaml` · `.dsh/sessions` · `.dsh/storages` · `.dsh/profiles`（共 **11 条**）。**`~/.codex/config.toml` 不在此闭集内**——它是**受管 seed 目标**（缺失 → 播种；**已存在 → 保留**）。判定 = **包含关系**（落在任一路径之下即失败）；AC3 ⑥ 增加域内样本 `.claude\projects-x` 与 `.claude\projects.bak-20260101-000000`（同时登记进 K9 ⑤）以覆盖"前缀式误判"。
* **㉔ 5.1 腿的定义**：**Pester 套件只在 pwsh 7 下运行**；5.1 腿 = 在套件内以 `HostExe = C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe` **逐用例发起被测脚本的子进程**。**不得在 `powershell.exe` 下运行 Pester**（本机 5.1 侧只有 Pester 3.4.0——一手实测）。证据 = `last_test_run.txt` 内每条 5.1 腿的实际宿主路径与退出码。
* **㉕ K8 的判定（替换原恒真断言）**：三样本——① `-NoPluginInstall -DryRun …` → 绑定成功且**非**绑定诊断族；② `-NoPluginInstall -ValidateOnly …` → 同理；③ **负向对照** `-NoPluginInstall -DryRun -ValidateOnly …` → **绑定失败**；并断言 **shim 日志为空**（"本切片不执行插件步"因此可判）。
* **㉖ B1 的取舍**：**保留**执行前置约束 ③ 全文（含 `(Get-Command claude).Source` 指向 fake shim）；**不**收窄条款。
* **㉗ K1 的判定**：无参数 = Deploy 集 → ① 输出**不含**绑定诊断族（`找不到与参数名称` / `parameter cannot be found` / `Parameter set cannot be resolved` / `无法使用指定的命名参数解析参数集`）；② 退出码 ≠ 0；③ **三个目标根零写入**。语义 = 本切片**明确拒绝执行部署**（`RESULT=REFUSED (deployment execution is slice B)`）；切片 B 落地后才转为"真执行"。
* **㉘ 零写入的度量域（写进条款）**：**三个部署目标根**的递归内容哈希 + **目录行**（`d:<rel>/`，覆盖"无新建目录"含空目录）；临时 HOME 内的**宿主自产物不计**（pwsh 按 `USERPROFILE` 推导 known folder 写 `<home>\AppData\Local\Microsoft\PowerShell\*`；实测重定向 `LOCALAPPDATA` 无效）。
* **㉙ 白名单样本补全**：再加 `workflow/archive`（目录，**末段**形态）与 `workflow/archive/e.md` → 均须 `[PRESERVE]`；域内反例 `workflow/myarchive.md`（叶名含 `archive` 但非路径段）→ 必须 `[DELETE]`。**闭集语义 = 子树继承**（2026-09-15 人类裁决）：命中目录之下的一切内容随其保留，且其任何祖先目录不得出现 `[DELETE]`。
* **㉚ 输出契约前缀族（一次冻结）**：`[PLAN]` · `[CHECK]`（`OK`/`FAIL`）· `[DELETE]` · `[PRESERVE]` · `[SUMMARY]`（含 `RESULT=<OK|FAILED|REFUSED>`）。切片 B/C 新增前缀须各自冻结。
* **㉛ 谓词取证形态**：P1（实现前 = exit 1）保留为历史；实现后另记 **P1'**（同命令 → exit 0 + `[PLAN]`/`[SUMMARY]`），并存构成红→绿对照。
* **㉜ 引用纠偏**："5 文件 44 用例"改为"5 个文件（4 个 `.Tests.ps1` + `TestHelpers.ps1`），用例数见该分支 `last_test_run.txt`"。