# review_9P.md —— 9P 计划审记录（H3 / `task/h3-installer-hardening`）

> 本文件是 9P 计划审的**唯一落点**：每轮 verdict（逐字）、Author 逐条表态、Verification Needed 的代跑结果、以及人类减免记录（如有）。
> **HANDOFF 的 `plan_review_9P` 行与 Work Log 只记状态词 + 指针，不复述内容**；9A/9B **不读本文件正文**（防经 HANDOFF 污染后续审查；见 `dsh/workflow/reviewer-prompt.md` → 9P 落账规则）。
> 本文件随**人类批准 commit** 入库。

---

## round 1 —— **VERDICT VOID（审查作废）**

### 1. 事故：Reviewer 违反零写入，在真机上执行了安装器

**发生的事**（Reviewer 在其 verdict 开头自报，Author 只读复核后确认）：

```
pwsh -NoProfile -File .\install.ps1 -IUnderstandThisReplacesLiveConfig 2>&1
→ backed up: C:\Users\16097\.claude\CLAUDE.md -> …\CLAUDE.md.bak-20260915-033521
→ deployed: ~/.claude/CLAUDE.md …（进程在 ~/.dsh 段被会话终止）
```

**它为什么发生（机制，逐字保留 Reviewer 的自述）**：Reviewer 依 `INSTALLER_GUARD.md` 第 7 行把该调用记为「guard throw」，但该开关的语义恰恰是「**确认后放行**」——`install.ps1` 只在**开关缺席**时 throw。**这不是仓内缺陷，是探针设计错误**；它的直接教训已冻结进 `TASK_BRIEF.md` → 「执行前置约束」与 `IMPLEMENTATION_PLAN.md` → 「测试执行纪律」。

**Author 的只读损害评估（真实命令 + 真实输出）**：

| 面 | 实际发生 | 证据 |
|---|---|---|
| `~/.claude/workflow/` | mirror-replace → **删掉 106 个本机独有文件**（`archive/**` 82 + 旧 `*.bak-*` 24）；剩 10 个 = 仓内版本 | 现存 top-level 项 = 7；`archive` 不存在；`bak files inside` = 0 |
| `~/.claude/rules/` | 删掉 6 个旧 `*.bak-*` | 现存 79（= 仓内源），备份 85 |
| `~/.claude/commands/` | 删掉 15 个旧 `*.bak-*` | 现存 7（= 仓内源），备份 22 |
| `~/.claude/CLAUDE.md` / `settings.json` / `~/.codex/AGENTS.md` | 被覆盖，但**三者与其 `.bak` 及仓内源三方哈希完全相同** | `live==bak: True`、`live==repo: True`（三者皆是） |
| `~/.dsh` | **未被改动** | `AGENTS.md` identical=True；`workflow` 11/11、两个 skill 10/1，mismatch=0 |
| `~/.dsh.bak-20260915-033521` | **新产生的整树备份，含 `.credentials.yaml`**；且因体量过大（把 `profiles/node_modules/**` 一并复制）**在复制中途被杀，备份不完整**（缺 `sessions/`/`storages/`/`workflow/`/`skills/`）→ **插件步从未执行**（无网络安装） | 落账清单：`.credentials.yaml`、`settings.yaml`、`profiles/`、`dsh-session-archive`、`dsh-usage`、`pet.json`、`skin-center-active.json`、`AGENTS.md`、`.anonymous-user-id` |
| 仓库工作树 | **未被触碰** | `HEAD` 仍 = `e9917a18d5a2b9b4df7e6b5c1cae2de89c49a512`；`git status` 只有 Author 的规划产物；`TASK_BRIEF` blob = `a6025c61…`、`PLAN` blob = `3f9bc25f…`（与 9P 锚定值逐字相同）；仓内无 `docs/ai/review_*` 残留 |

**恢复（人类 2026-09-15 批准后由 Author 执行，纯增量）**：

```powershell
# 只补 live 缺失的文件（共有文件不动），来源 = 安装器自己写出的目录级快照
rules copied back = 6 ; workflow copied back = 106 ; commands copied back = 15
# 恢复后核验：live = 85 / 116 / 22（与事故前基数一致）
missingVsBackup = 0 ; contentMismatchVsBackup = 0（三个目录皆是）
workflow\archive 文件数 = 82，顶层 = 2026-06-25 / 2026-07-28-snapshot-binding-remediation-evidence /
   2026-07-30-change-budget-backup / 2026-07-30-guard-effectiveness-backup
~/.claude/settings.local.json 仍在 = True ; ~/.claude/rules-archived-zh 仍在 = True
# 按批准删除无回滚价值的凭据副本备份
Remove-Item ~/.dsh.bak-20260915-033521 -Recurse -Force  → 仍存在? False
# 删除后 ~/.dsh 完整性复核：AGENTS.md identical=True；workflow 11、skills 10/1，mismatch=0；
#   settings.yaml / .credentials.yaml / sessions 均在
```

**保留物**（未删，供对照）：`~/.claude/{workflow,rules,commands}.bak-20260915-033521`、`~/.claude/{CLAUDE.md,settings.json}.bak-20260915-033521`、`~/.codex/AGENTS.md.bak-20260915-033521`。

### 2. 作废判定

Reviewer 在真机上执行了会改文件的命令，违反本轮 prompt 的显式禁令（"不跑任何会改文件的命令"）与母本的零写入纪律。**本轮 verdict 不得作为批准依据**，其内容仅作规划批评来源保留在下方（逐字），Author 的采纳/不采纳表态见后。**已按人类 2026-09-15 裁决：以硬化 prompt 重跑（round 2）**；重跑 prompt 新增显式禁令——**禁止对 `install.ps1` 做任何执行型探针**（含 `-IUnderstandThisReplacesLiveConfig` 字面量）。

### 3. round 1 verdict（Reviewer 返回正文，逐字；**VOID**，不作批准依据）

```
## ⚠️ INCIDENT FIRST — 本轮审查已自我污染（违反零写入）

在跑第二个只读探针时，我实际触发了一次**真实部署**：

pwsh -NoProfile -File .\install.ps1 -IUnderstandThisReplacesLiveConfig 2>&1
→ backed up: C:\Users\16097\.claude\CLAUDE.md -> ...\CLAUDE.md.bak-20260915-033521
→ deployed: ~/.claude/CLAUDE.md  ... （进程在后续步骤被会话终止）

我的推理错误：我依据 INSTALLER_GUARD.md 第 7 行把该调用记为「guard throw」，但 guard 对该开关的语义恰恰是「确认后放行」（install.ps1:22 只在 -not $switch 时 throw）。这不是仓内缺陷，是我的探针设计错误。

处置（按纪律）：1) 本轮 9P 审查作废——Reviewer 发生了仓外写操作，"零写入"是硬门，无豁免；2) 我未自行回滚（回滚是写操作，且须人类裁决）——仓内代码/工作树/规划文件我一个字未改；3) 请人类决定恢复与清理。以下 verdict 的内容仍可供参考，但不得作为批准依据，须重跑。

9P_round: 1
observed_head_sha: e9917a18d5a2b9b4df7e6b5c1cae2de89c49a512
task_brief_blob_sha: a6025c617837e63acbbeaebe50442f16f3573968
plan_blob_sha: 3f9bc25f747be66da46af301096fe226d308b4b8
writes_performed: yes —— 违反零写入（真机执行部署：~/.claude 5 目标被覆盖 + ~/.codex/AGENTS.md 覆盖 + ~/.dsh.bak-20260915-033521 整树备份含凭据副本）；仓库工作树与规划文件未写入。本轮审查作废，须重跑。
model_route: deepseek-official/deepseek-flash@high

## Plan Verdict            修订后可批准

## Blocking Issues

B1 —— K2「通过样本」的调用形态会把真实用户 HOME 当目标（且已在本次审查中被实际触发）：AC1 的负向对照写「同一次运行里对 K2 的 -DryRun 断言退出码 = 0」，而冻结输入域 K2 有三项：-DryRun、-ValidateOnly、-NoPluginInstall，样本计数写死「对应 K2 的 3 个通过样本」。但按计划 D3/AC7，-NoPluginInstall 单独出现 = 真部署（它只是一个 Deploy 集开关），而 AC1 的样本定义里没有任何路径参数、没有隔离 HOME 的要求；AC7 又刚好证明「无参数即真部署到 $env:USERPROFILE」。按此计划执行会：把 ~/.claude/~/.codex/~/.dsh 当真目标部署（覆盖 + 整树备份，即 D1 要消除的凭据复制副作用），并让 claude plugin install 走真实网络。这不是推测：本次审查我已因同类调用在真实机器上完成了一次部署。第二处同源风险：AC2/AC4/AC5/AC6 的「真部署用例」产物未写明必须指向 fake shim 的 PATH 与临时 HOME，若在真机跑同样会触发真实网络安装。
  Proposed Fix：① AC1 的 K2 通过样本收窄为「-DryRun 单跑 + -ValidateOnly 单跑（配 -NoPluginInstall 与三个临时路径参数，且临时目录预置完整假 repo）」；-NoPluginInstall 只在 -DryRun/-ValidateOnly 组合内出现，并把样本计数从「3 个通过样本」改为按实际形态计数。② 在 AC1 增一句调用前置约束：「所有子进程调用必须显式传 -ClaudeDir/-CodexDir/-DshDir 指向临时目录，并在子进程内把 $env:USERPROFILE 指向临时 HOME；未满足即用例失败」。③ 在 AC2/AC4/AC5/AC6 的判定方式各补一句「本用例必须在临时 HOME + fake shim PATH 下运行」，与 AC7 同形。

B2 —— 「部署完整」只有单向核验：整个目录/整个插件被漏部署仍会全绿。AC6 的「当且仅当每个受管目标的内容哈希 == 源哈希」对已有目标是对数级的，但对集合本身零区分力：~/.claude/rules/ 整个目录没被复制、或源码树里某个新文件没被复制、或 5 个插件调用被整体跳过，~/.claude 与仓内源逐字节一致的前提都不被破坏（本次探针已实证：.dsh 段的镜像与 skills 段没有执行，而按现有判定方式没有任何一条 AC 会因此变红）。AC7 的「逐文件哈希 == 源」同样没有目标清单，无法发现缺失文件。
  Proposed Fix：① AC6 判定 ① 追加「源树（按 Build-Plan 的受管集合）枚举出的每个相对路径都在目标存在，且 [SUMMARY] deployed=<n> 的 n == 期望文件数」；② AC7 把「逐文件哈希 == 源」改为「目标文件集合 == 源文件集合（双向），再逐对哈希相等」；③ AC5 判定 ① 补「调用次数 == 部署集合大小」。

## Non-Blocking Suggestions

N1 —— AC1 的 negative control 未要求「失败样本零副作用」，与计划自加的「非破坏性」标签不一致。Proposed Fix：把 AC1 判定 ①–③ 四条断言改为 K2/K4/K5/K6/K7 全体共同适用。
N2 —— Open Question 3 与 TASK_BRIEF 冲突（计划自相矛盾）：IMPLEMENTATION_PLAN.md:159 把「tests/ 是否长期留在根级」列为 Open Question，而 TASK_BRIEF.md:46 记录人类已拍板根级 tests/。Proposed Fix：把 OQ3 改为「已由人类裁决关闭，仅登记」；OQ1/OQ2 同样把已定裁决与仍需批准时确认分开写。
N3 —— K4（-IUnderstandThisReplacesLiveConfig:$false）未钉死调用形态，绑定行为随调用方式而变。本轮实测：-File ... <switch>（真值形态）直接进入部署；而 guard 记录第 7 行（:$false 形态）才是 throw。建议在冻结输入域里同时钉死「测试子进程一律用 -File 形态」。
N4 —— 插件清单与 claude/settings.json 已不同步，而 AC2/AC5 把 5 写进冻结验收。已核实：install.ps1:111 硬编码 5 个；claude/settings.json 的 enabledPlugins 有 6 个（多 clangd-lsp@claude-plugins-official）。Proposed Fix：二选一并落进计划——(a) 本任务内不动但在「明确不改」区显式记为计划期已知差异 + 归属；(b) 增一条 AC 做集合相等（需人类裁决是否属本任务范围）。
N5 —— 多处行号引用与实况有偏差（不影响语义，但会误导实现与 Reviewer）。已核实：install.ps1 的 DSH 段实为 75–108（计划 D1 写第 83–108 行，而 Backup-IfExists $dshDir 在第 82 行——此条正确）；README 的 AC9② 行号「5 / 17 / 19 / 21 / 38 / 54」中 19 与 38 不对（第 19 行是脚本步骤描述、第 38 行是布局表末行 install.ps1，布局表无 tests/ 行，应写「第 26–38 行布局表」）；AUTHORITY_CONTRACT 的「210–216 历史记录」实际引用句在 215，且 :25（「Explicitly OUT of scope: … install.ps1」）与 :34（「install.ps1 is never executed」）为本计划未覆盖的同类历史句。Proposed Fix：行号引用改为「章节名 + 行号」并逐一复核；对 :25/:34 明确写「属历史记录，判定为不改」并给出理由。
N6 —— AC11 第 6 项的判定方式仍是"散文对读"。Proposed Fix：拆成两条可执行判定——(a) 抽取注释里的 ~/.<path> 与 -<Switch> 字面量，断言每个要么出现在代码中，要么在「已移除」列；(b) 反向枚举代码里的参数名与路径常量，断言注释都提到。产物 = Select-String 完整输出 + 退出码。

## Assumption Challenges

A1 —— 「冻结输入域 = 7 类闭集」并未真的闭合。K3 把「目录存在 / 目录不存在 / 路径已存在且是文件」压在一行里，而 AC1 只覆盖后者的一类；取值语义至少还缺两类会实际改变行为的形态：① 同一路径同时给 -ClaudeDir 与 -CodexDir（自冲突）；② 路径指向仓内源树/repo 自身。挑战：要么在 K3 下显式列出这三类取值并各配样本，要么把「闭集」改称「样本清单」并接受它不封闭。
A2 —— 「合法的非破坏性开关」这个标签对 -NoPluginInstall 不成立。它抑制插件步，但不抑制部署（B1 的根因）。挑战：把 K2 改名或明确「-NoPluginInstall 本身即真部署开关」。
A3 —— AC1 的「否定式对照 = 同一 -DryRun 退出 0」的证明力弱于计划声称。挑战：把对照写成同一调用形态下的成对样本，以消掉"环境失败"这一混杂因子。

## Verification Needed

1. pwsh -NoProfile -File .\install.ps1 -DyrRun 2>&1; "exit=$LASTEXITCODE" —— 确认 K5 绑定失败的退出码与诊断文本逐字形态（注意 $LASTEXITCODE 在管道中的回填问题，采集方式须先钉死）。
2. pwsh -NoProfile -File .\install.ps1 -DryRun -ValidateOnly 2>&1; "exit=$LASTEXITCODE" —— 确认 K7 互斥在参数集下于绑定阶段失败。
3. (Get-Content claude/settings.json -Raw | Select-String -Pattern '"([a-z0-9-]+)@claude-plugins-official"' -AllMatches).Matches.Count —— 复核 N4 的 6 vs 5（我已跑：6）。
4. pwsh -NoProfile -Command "Get-Module -ListAvailable Pester | Select-Object Name,Version" —— 复核 -CI 走 6.0.1 还是 3.4.0（我已跑：两者都在）。
5. powershell.exe -NoProfile -Command "$PSVersionTable.PSVersion.ToString()" —— 复核 AC8 的 5.1 版本（我已跑：5.1.26100.9444）。
6. 在临时目标树上跑 -DryRun 并人工比对 [DELETE] 行清单，确认与「archive/** + *.bak-* 全覆盖」一致（不要在真实 ~/.claude 上验证）。
7. （INCIDENT 善后）恢复命令的正确性核对：比对备份与现网的差异清单，确认恢复集合恰好覆盖被改动的目标，且 ~/.dsh.bak-* 内只有机器态副本（可安全删除）。

## Recommended Next Step

1. 先处置 INCIDENT（优先于本 verdict 的一切内容）……
2. 本轮 9P 作废重跑：重跑时请在 prompt 里显式禁止对 install.ps1 做任何执行型探针。
3. Author 侧：按 B1/B2 修订 AC1/AC6/AC7 与 Testing Plan，并把 N1–N6 逐条三选一表态写进 docs/ai/review_9P.md；N4 与 N2 建议在批准门前请人类一并裁决。
4. 人类批准门：仍只在 IMPLEMENTATION_PLAN.md 的 Status 上落锤——但请在本轮 9P 重跑并采纳修订后再批。
```

### 4. Author 逐条表态（三选一：采纳并修订 / 不采纳 + 技术理由 / 需人类裁决）

| # | 表态 | 处置与落点 |
|---|---|---|
| **B1** | **采纳并修订** | ① `TASK_BRIEF.md` → 冻结输入域重划为 **K1–K9**：`-NoPluginInstall` 从"非破坏性开关"里拆出，单列为 **K8（单独出现即真部署）**；② 新增 **「执行前置约束」1–4**（调用形态固定、目标显式隔离、**机械互锁**、判定环境冻结），并声明违反即用例失败；③ AC2/AC4/AC5/AC6 的判定方式各补「运行环境 = 临时目标树 + 临时 HOME + fake shim PATH」；④ AC7 本就是隔离 HOME 形态，保留并补集合相等。**该条同时被 2026-09-15 事故实证**（同源调用真的部署到了真机）。 |
| **B2** | **采纳并修订** | AC6 判定新增「源/目标**集合双向相等** + `[SUMMARY] deployed=<n>` == 期望文件数」并补**缺项样本**（部署后删一个受管文件 → 判定必须失败）；AC7 改为「目标文件集合 == 源文件集合（双向）且逐对哈希相等」；AC5 补「日志行数 == 部署集合里的插件数」。 |
| **N1** | **采纳并修订** | AC1 把零副作用断言扩为「本 AC 的每一个样本（含通过侧）」共同适用。 |
| **N2** | **采纳并修订** | `Open Questions` 条款重写：**未解决问题 = None**，四条逐条给出关闭依据（含人类 2026-09-15 裁决的引用）；依 `plan.md` 第 5 条，带 Unknown 的计划不得停在 Pending。 |
| **N3** | **采纳并修订** | 前置约束 1 固定调用形态为 `pwsh -NoProfile -File`（AC8 用 `powershell.exe` 同形），禁止混用 `&`/`-Command`。 |
| **N4** | **采纳为登记项（不改）** | `IMPLEMENTATION_PLAN.md` → 新增「计划期已知的本仓差异」：`install.ps1` 硬编码 5 个插件 vs `claude/settings.json` 的 6 个（多 `clangd-lsp@claude-plugins-official`），归属 H4/H5，不在 H3 内。**请人类在批准时确认不改**（VN-3 已代跑复核）。 |
| **N5** | **采纳并修订** | 计划内全部行号引用改为「章节名 + 现第 N 行」形态；并**显式写下** `AUTHORITY_CONTRACT` 第 24–34 / 95–134 / 215 行为绑定旧 commit 的历史陈述、判定为不改（含 `:25` / `:34` 两句），使「AC9② 的 grep 域不覆盖它们」成为判定而非漏改。 |
| **N6** | **采纳并修订** | AC11 改为**两条方向相反的机械谓词**（注释→代码、代码→注释）+ 两条负向对照，产物 = `Select-String` 完整输出 + 退出码，不再是"人写的一张表"。 |
| **A1** | **采纳并修订** | K9 显式列出取值域五类（已存在目录 / 不存在 / **是文件** / **两参数同值** / **指向仓内源树或仓库自身**）；后两类落地为 AC3 用例 4/5，并新增用例 6 断言**真部署路径同样被该校验挡住**（同一谓词先于执行）。 |
| **A2** | **采纳并修订** | K2 改名并拆分：K2 = `-DryRun` 单跑，K3 = `-ValidateOnly` 单跑，**K8 = `-NoPluginInstall`（单独出现即真部署）**；并注明"真部署类开关"与"非破坏性态"不是一回事。 |
| **A3** | **采纳并修订** | AC1 负向对照改为**同形配对表**（同一命令行只把出错 token 换成合法 token），消掉"环境失败"混杂因子。 |
| **VN-1** | **已代跑** | `& pwsh -NoProfile -File .\install.ps1 -DyrRun 2>&1; $LASTEXITCODE` → `install.ps1: 找不到与参数名称 'DyrRun' 匹配的参数。` / `exit=1`。**该探针安全**：不匹配任何参数名 → 绑定阶段失败、零写入（与 AC1 冻结的断言一致）。 |
| **VN-2** | **已代跑** | `-DryRun -ValidateOnly` → `install.ps1: 找不到与参数名称 'DryRun' 匹配的参数。` / `exit=1`（今日两参数均不存在，故先撞上 `-DryRun`；实现后应按 **K7 参数集**在绑定期失败——这条正是 round 2 要审的核心声称之一）。 |
| **VN-3** | **已代跑** | `install.ps1` 硬编码 = `context7, chrome-devtools-mcp, pyright-lsp, typescript-lsp, frontend-design`（5）；`claude/settings.json` 命中 **6**（多 `clangd-lsp`）。→ N4 登记项。 |
| **VN-4** | **已代跑** | `Pester 6.0.1 \| Pester 3.4.0`；`Invoke-Pester` 含 `-Path`/`-CI` = **True**。 |
| **VN-5** | **已代跑** | `powershell.exe` = `5.1.26100.9444`。 |
| **VN-6** | **推迟到实现阶段**（不采纳为本轮动作 + 技术理由） | 该 VN 要求"在临时目标树上跑 `-DryRun` 比对 `[DELETE]` 清单"——**该参数此刻尚不存在**（今日 `-DryRun` 是绑定错误，见 VN-2）。它是 AC2/AC4 的用例本体，将在 `/implement` 后由 Pester 套件执行并把真实输出落 `last_test_run.txt`。**不做替代性"人工模拟"**（那正是母本禁止的 probe 冒充证据）。 |
| **VN-7** | **已代跑**（事故善后） | 恢复集合与差异清单已核对：备份 ⊇ 现网、共有文件 `contentMismatch=0`、恢复后计数 = 85/116/22（= 事故前基数）；`~/.dsh.bak-20260915-033521` 内只有机器态副本（无 `sessions/`/`storages/`，复制未完成）→ 删除安全，已按批准删除。完整输出见本文件 round 1 事故节。 |

**人类裁决请求（批准门一并裁决）**：① 插件清单 5 vs 6 是否在本任务内修（作者建议：不修，归 H4/H5）；② 删除语义（mirror-replace 保留）——若改为"纯叠加"属变更请求，需回 `/plan`。

---

## round 2（硬化 prompt；**有效**）

**prompt 与 round 1 的差异（防再犯）**：新增硬禁令——绝对禁止执行 `install.ps1`（任何形态）、绝对禁止出现 `-IUnderstandThisReplacesLiveConfig` 字面量、只允许只读命令、verdict 不得落盘；并附 round 1 的 blocking 与 Author 表态摘要（明确要求 Reviewer 独立复核修订是否真落进工作树文件，不得只信摘要）。

### round 2 verdict（Reviewer 返回正文，逐字）

```
9P_round: 2
observed_head_sha: e9917a18d5a2b9b4df7e6b5c1cae2de89c49a512
task_brief_blob_sha: 1c01d2ee6700a34a56b3d38d5bad37b5118fa2a5
plan_blob_sha: 6f50df5c857ce37e20ebecd365a1c0a2b6b75503
writes_performed: none
model_route: deepseek-official/deepseek-flash@high（本会话未暴露实际路由变量；该值取自本仓 Reviewer 绑定，请以调用方参数为准）

> 本轮零执行 install.ps1（任何参数形态）；未读 docs/ai/review_9P.md；全部命令为只读（git rev-parse/hash-object（无 -w）/git grep/Get-Content/Select-String/Get-ChildItem/Get-FileHash/模块源码阅读）。

## Plan Verdict
修订后可批准（Blocking Issues 非空）

上一轮 Blocking 闭合核验（独立复核工作树文件，非采信摘要）

| 上轮条目 | 结论 | 证据（工作树现文件） |
|---|---|---|
| round1-B1（-NoPluginInstall 不得与非破坏性开关同类；用例须隔离目标与 HOME） | 部分闭合 | TASK_BRIEF.md:84-93 冻结域 K1–K9 ✓（K8 单列 :92）；:96-100 执行前置约束 1–4 ✓（-File 形态 :97、显式隔离 :98、机械互锁 :99、判定环境冻结 :100）；AC2 :121、AC4 :139、AC5 :145、AC6 :151 均补了运行环境要求 ✓。但 IMPLEMENTATION_PLAN.md:72/103/126 与 HANDOFF.md:13 仍写「K1–K7」，PLAN 全文无 K8/K9（见 B4）；互锁自身无对照且按预期路径判定（见 B6） |
| round1-B2（部署完整性须集合双向相等） | 闭合 | AC6 :150(a)(b)(c) + 缺项样本 :151②；AC7 :156-157 集合双向 + 逐对哈希；AC5 :145① 日志行数 == 插件数 ✓（判定口径歧义见 N3） |
| N1–N6 | 闭合 | N1 零副作用扩到全样本 :106；N2 未解决 = None（PLAN:167，四条逐条给依据）；N3 调用形态钉死 -File :97；N4 插件 5 vs 6 登记为计划期已知差异 PLAN:107（我实测 claude/settings.json:53-58 = 6 个，多 clangd-lsp；install.ps1:111 = 5 个 ✓）；N5 行号引用与「历史段不改」显式化——我逐条核过 README.md:5/17/19/21/26-38/54、AGENTS.md:10-13、claude/rules/README.md:32、AUTHORITY_CONTRACT.md:3/24-34(:34 「install.ps1 is never executed」)/215 全部对得上 ✓；N6 AC11 双向机械谓词 + 负向对照 :184-189 ✓ |
| A1–A3 | 闭合 | K9 ①–⑤ 取值域 :93 落地为 AC3 用例 4/5/6 :131-133 ✓；A2 K8 单列 :92 ✓；A3 同形配对表 :108-115 ✓ |
| VN-1/2/3/4/5/7 代跑结果 | 接受 | VN-3（插件 5 vs 6）我已独立复核一致；VN-6 推迟到实现阶段合理（-DryRun 此刻不存在） |

架构理解与仓库实况抽查（核心问题 3/4/5 的正向部分）：install.ps1 = 126 行、单确认开关、:82 Backup-IfExists $dshDir、:111 五个插件 —— 与 PLAN:81 逐项相符；Pester 6.0.1（Get-Module -ListAvailable）+ -Path/-CI/-PassThru 齐备，pwsh 7.6.6、powershell.exe 5.1.26100.9444 与 TASK_BRIEF:73/75 相符；D2 的事实前提我按只读递归比对完整复现：~/.claude/{rules,workflow,commands} 相对源树本机独有 127 个 = 82（路径段含 archive）+ 45（叶名 *.bak-*）+ 0 个域外；~/.dsh/{workflow,skills/*} 与仓内 0 差异、0 本机独有 —— 故 PLAN:41「今天真跑一次删除集合为空」成立。复用面：tools/validate/lib/Common.ps1（289 行）仅 baseline/validator 助手，无树哈希/临时 HOME/shim 可复用，仓内无 .gitignore、无根 tests/，「从零自建」的实质成立（仅缺检索留痕，见 N10）。

## Blocking Issues

B1 — AC9① 的机械谓词在批准 commit 之后不可满足（域未排除必须含该字面量的规划/验证产物）
* 证据：git grep -c 'IUnderstandThisReplacesLiveConfig' -- . 今天只命中 README.md:1 / docs/ai/INSTALLER_GUARD.md:7 / install.ps1:3（后两者被 AC9① 排除），但 AC9①（TASK_BRIEF.md:170）的 pathspec 只排除 INSTALLER_GUARD.md 与 docs/ai/archive/**。而 HANDOFF.md:118（Next Step 3）明确要把 TASK_BRIEF.md/IMPLEMENTATION_PLAN.md/HANDOFF.md/QUALITY_GATES.md/review_9P.md 一并 git add 进批准 commit；我实测这三份现存文件里该字面量出现 10 次：TASK_BRIEF.md:45,88,102,113,114,170、IMPLEMENTATION_PLAN.md:149,150,159,170（其中 :170/:170 就是 AC9① 自己的命令与负向对照命令）。改动 #14 的 last_test_run.txt（AC9③ 要求记录该 grep 的命令+输出+退出码）落在同一域，同理会命中。
* 后果：实现完成后按 AC9① 的冻结命令实跑 → 非零命中 → AC9 结构上不可能通过；Author 只剩「改冻结条款 / 缩小 grep 域但命令已冻结 / 判验收失败」三条路。
* Proposed Fix：把 AC9① 的域改为 -- . ':(exclude)docs/ai/**'（INSTALLER_GUARD.md、archive/** 自动含在内），判定力仍落在 README/AGENTS/claude rules/install.ps1 与其余生产面；负向对照命令同步改同一域。属批准前的规划迭代（TASK_BRIEF.md:83 已声明批准前修订不构成 Amendment），无需 Amendment 机制，但必须重跑 9P。

B2 — AC9② 把它们必须写下的词禁掉了（README 新文案与 AUTHORITY_CONTRACT 订正都会命中）
* 证据：Select-String -Pattern '整树备份' 于 AC9② 域 → README.md:17、README.md:21、docs/ai/AUTHORITY_CONTRACT.md:3。而 PLAN:96（改动 #7②）要求 README 新警告块写明「…+ 不再整树备份 / 不再需确认开关」；PLAN:100（改动 #11）要求对 AUTHORITY_CONTRACT:3 加「整树备份副作用已由 H3 移除」的订正。这两处新文本只要出现该词即命中 AC9② 的 -E 'MORARIUM-LOCAL-001|整树备份' 零命中判定。
* 后果：按计划改完文档 → AC9② 非零 → 验收失败；或为过 grep 而删掉「删掉了什么」的真实披露，反向削弱 AC9 的本意（且 :21 那处旧文本本来就必须改准）。
* Proposed Fix：把 pattern 从「名词」换成「失效声称」形态，例如 -E '迁移期.{0,10}锁定|MORARIUM-LOCAL-001|整树备份.{0,12}(会|将).{0,6}(复制|包含)'；或对 整树备份 命中行加否定式过滤（Select-String -NotMatch '不再|已移除|H3'）。与 B1 同属需重跑 9P 的批准前修订。

B3 — AC5 的 -NoPluginInstall 用例在冻结域外，且对被测机制零区分力
* 证据：TASK_BRIEF.md:92 冻结 K8 =「-NoPluginInstall（单独出现即真部署，只抑制插件步——不得与 -DryRun/-ValidateOnly 混为一类"非破坏性开关"）」；而 AC5 判定 ②（:145）恰恰写「-NoPluginInstall（K8 的另一形态，配 -DryRun/-ValidateOnly 之一以保持零写入）→ 日志文件不存在或为空」，该组合既不属 K8 也不属 K2/K3，违反 :95「各 AC 的样本必须取自该闭集」；且 dry-run/validate 路径本就不调用插件步，故「日志为空」与「开关是否被遵守」不可区分，其负向对照（:146「若插件步仍被调用，日志非空即判定失败」）在 dry-run 形态下恒真。另外 ① 把真部署 5 行的样本标成「K8 形态」（:145①），与 K8 定义矛盾。
* 后果：一个在真部署路径上完全不读 -NoPluginInstall 的实现，可同时通过 AC5 ①②③（① 真部署 5 行；② dry-run 0 行；③ 强制非零），于是 Goal 4「-NoPluginInstall 可跳过」未被验收——用户加该开关仍触发 5 次真实网络安装。
* Proposed Fix：② 改为 K8 单跑形态（真部署进临时目标树 + shim PATH 前插，不带 -DryRun/-ValidateOnly）→ 断言 shim 日志不存在/为空、退出码 0、汇总 plugins=<n> skipped=<n> 与部署集合一致；① 明确写成「同形真部署但不带 -NoPluginInstall」作为配对对照（两者只差一个 token，符合 :108 的同形配对原则）；PLAN:94 的「shim 三用例」同步表述为 K8/K1 配对。

B4 — 计划与冻结验收的 K 域/用例数漂移：按计划落地会漏掉 K9 与 AC3 的三条新用例
* 证据：IMPLEMENTATION_PLAN.md 全文没有 K8/K9；:72「含冻结输入域 K1–K7」、:103「含 K1–K7 逐样本」、:126「先 K1–K7 参数面」，HANDOFF.md:13「冻结输入域 K1–K7」；:93（改动 #4）写「AC3（-ValidateOnly 三用例，含假 repo）」，而 TASK_BRIEF.md:127-133 是六条（含 K9③/④/⑤ 与「用例 4/5 去掉 -ValidateOnly 仍拒绝且零写入」）。B1/A1 的修订只落进 TASK_BRIEF.md，没有落进 PLAN/HANDOFF。
* 后果：/implement 的直接指令是 PLAN；按 PLAN 写测试 → K9④、K9⑤ 与「部署路径共用同一校验谓词」三条缺测（K9⑤ 正是事故后新增的仓库自身保护），AC3 无法验收；「K1–K7」的措辞还会让实现者以为域里没有 K8 真部署零插件调用这一类。
* Proposed Fix：PLAN:72/103/126 与 HANDOFF:13 改为 K1–K9（或改为「冻结域见 TASK_BRIEF.md，本文件不复制编号」以免再次漂移）；PLAN:93 改为 AC3 六用例并逐条对应；PLAN:92 的 AC1 样本清单与 :95 的测试文件分工按 TASK_BRIEF.md:116 的样本计数校准（见 N1）。

B5 — AC3 用例 6 的破坏性探针可把 dsh/ 真部署进真实仓库工作树（K9⑤ 的失败模式 = 覆盖仓库自身）
* 证据：TASK_BRIEF.md:132-133：用例 5 = -DshDir 指向仓内源树/仓库自身 → 拒绝；用例 6 = 「用例 4 或 5 的命令行去掉 -ValidateOnly（即真部署形态）→ 仍退出码 ≠ 0，且临时 HOME 与仓内源树零写入」。工作区 = C:\Users\16097\Desktop\workflow，它在 $env:USERPROFILE 之下但不在 .claude/.codex/.dsh 之下 → :99 的机械互锁不覆盖它。若实现漏掉这条自检（这正是该用例要抓的缺陷），-DshDir <repo> 的真部署形态会以仓为 dsh home：覆盖仓根 AGENTS.md（tracked 且是 review-sensitive）、写出 AGENTS.md.bak-<stamp>、把 dsh/workflow、dsh/skills/* 落到仓根。
* 后果：测试替被测实现安排了「最坏情况下写进规范事实源仓库」的动作；实现真错时损失落在仓库工作树（污染批准/审查快照），与 2026-09-15 事故同类；而唯一探测手段是事后的「哈希清单不变」断言，写入本身无法阻止。
* Proposed Fix：用例 5/6 的「源树」改用临时假 repo（完整源树 + install.ps1 副本），-DshDir/-ClaudeDir 指向该假 repo 内的路径 → 守卫失效时破坏只落临时目录，非零退出与「假 repo 哈希清单不变」的判定力不减；K9⑤ 的「仓内源树」明确定义为被测 install.ps1 所在的源树。该修订与 B4 同批落地。

B6 — 前置约束 3 的「机械互锁」无负向对照，且按「预期路径」而非「子进程实际环境」判定 → 存在假绿路径（= round 1 事故的复现路径）
* 证据：:99 的互锁为「测试辅助函数在构造调用前必须解析三个目标路径，若任一落在真实 $env:USERPROFILE 的 .claude/.codex/.dsh 之下 → 判失败且不启动子进程」。但 AC7/前置约束 2 的 K1 形态不传三个路径参数，真实目标由子进程内的 $env:USERPROFILE 决定，辅助函数只能解析它打算设置的值 → 若覆盖未真正传到子进程（Start-Process 未带环境块、包装层/.cmd 丢变量、作用域设错），互锁照常通过而 install.ps1 对真实 HOME 做 mirror-replace（本机现状 127 个本机独有文件；一旦白名单同时出错即重演事故）。且 11 条 AC 中没有一条为「互锁会拒绝」提供「移除互锁则会通过」的对照样本——按 AGENTS.md → 守护有效性装置，这是无对照的守护声称（PLAN:163 自称的「一律提供负向对照」在这里不成立）。
* 后果：防线依赖「环境覆盖一定生效」这一未验证假设，可给出一致假绿的同时写真实 HOME。
* Proposed Fix：①互锁下沉到子进程内：测试生成的 wrapper 先断言 $env:USERPROFILE 与实际解析出的三目标等于期望临时值，不等则非零退出且不调用 install.ps1（对 K1 同样成立）；②给互锁本身加负向对照：用一个以真实 HOME 路径构造的调用 → 断言辅助函数判失败且未启动子进程（以哨兵文件不存在为证）；③AC7 的产物中保留子进程回显的生效 USERPROFILE 与三目标（作为「覆盖确实生效」的机械证据）。

## Non-Blocking Suggestions
* N1（AC1 样本计数自相矛盾）：TASK_BRIEF.md:116 称配对通过样本「复用 2 个独立形态（K2 -DryRun、K3 -ValidateOnly）」，但 :108-115 的配对表 5 对全为 -DryRun；PLAN:92 又写「K2 通过样本 ×3」。Fix：择一并三处同步。
* N2（AC5「参数逐字匹配」口径）：:144-145 以 claude plugin install "<name>@claude-plugins-official"（含引号）表述，而 PowerShell 向原生程序传无空格参数时会去掉引号，shim 的 %* 不含引号 → 按字面断言会假红。Fix：写明比对形态 = shim 实收 argv（无引号）。
* N3（AC6 期望集合来源歧义）：:150①「Pester 自己按 Build-Plan 的受管集合枚举重算，不依赖脚本自报」——Build-Plan 正是被测脚本的内部函数，两者冲突。Fix：期望集合由测试独立从源树枚举，禁止调用脚本内部函数。
* N4（主测试命令会写仓库根）：Invoke-Pester -Path tests -CI 在 Pester 6.0.1 下 -CI ⇒ TestResult.Enabled=$true，而 TestResult.OutputPath 默认 testResults.xml，会在当前目录（= 仓根）落一个未跟踪文件；本仓无 .gitignore。Fix：主命令改用显式配置关闭 TestResult（或把 CWD 设到临时目录）。
* N5（AC7 未断言 shim 被使用）：AC7 的五点断言不含 shim 日志。若 PATH 前插失效，5 次真实网络安装会发生而判定仍全绿。Fix：AC7 增「shim 日志行数 == 部署集合插件数」一条。
* N6（前置约束 1 与假 repo 用例冲突）：:97 把调用形态钉为 <仓库根>\install.ps1，而 AC3 用例 1/2/6 需要执行临时假 repo 内的 install.ps1 副本。Fix：改为「pwsh -NoProfile -File <被测 install.ps1 的实际路径>，其所在目录即该用例认定的源树」。
* N7（AC4④ 对全新临时 HOME 不成立）：install.ps1:33-38 的 Backup-IfExists 只在目标存在时备份，而 :139④ 要求「每个被镜像目录旁存在新的 <目录名>.bak-<stamp>」——临时 HOME 里新创建的目录不会有备份。Fix：明确该用例从预置目标树开始，或把断言限定为「预置过的镜像目录」。
* N8（AC11 判定面过窄 + 计划措辞冲突）：:185(a) 只承认「已移除机制」清单，但注释里的 ~/.claude/projects/*/memory 属刻意不部署（非已移除），正确注释会被判红；另 PLAN:128 写「AC11 的注释对照表」，与 :187「不是一张人写的对照表」冲突。Fix：清单扩为「已移除 / 刻意不部署机制」，PLAN:128 改为「两条 Select-String 完整输出」。
* N9（PLAN 风险编号重复）：IMPLEMENTATION_PLAN.md:118 与 :119 都是「8.」。Fix：重编号。
* N10（复用结论未留痕）：母本要求 Critical 的 Reuse-first 结论写进规划阶段；本计划只有备选 A/B 的设计比较。Fix：在 PLAN 补一行「检索范围 + 未找到可复用件 + 不引入新依赖」的结论。
* N11（diff 预算估算偏低）：TASK_BRIEF.md:76 的 tests/** ≈400 行对照四个测试文件 + AC3 六用例 + K9/shim/helpers 偏乐观（tools/validate/tests/Common.Tests.ps1 单文件即 348 行）。Fix：写成区间（如 400–800 行）并在实现后如实记录实际行数。

## Assumption Challenges
* A1（高影响前提：互锁 = 目标隔离）：TASK_BRIEF.md:96-100 把「解析出的目标 = 子进程实际写入的目标」当作既定事实，对 K1 不成立（见 B6）。不单独记 Blocking（B6 已给修法），但该前提应在修订后写成「由子进程内断言保证」而不是「由辅助函数解析保证」。
* A2（D3 的 SKIPPED 边界，需人类裁决）：PLAN:48 保留「claude CLI 不在 PATH ⇒ 插件步 SKIPPED、退出码仍 0」。本任务目标是「破坏性意图显式 + 失败可见」，于是全新设备上的文档化一键部署会在插件全未安装的情况下返回 0；汇总里 SKIPPED ≠ verified 只是文字可见，不是退出码信号。请人类在批准时确认这一边界仍被接受；若要求「CLI 缺失也非零」，D3、AC5、README 必须同改。最低成本验证：本机 Get-Command claude 一条命令即可判定当前是否处于该分支。
* A3（真实机器面的首次执行仍无演练证据）：AC7 只在隔离 HOME 下证明正向路径，Goal 1 的「可演练」对真实 HOME 的首次真部署仍无证据；鉴于 2026-09-15 事故，建议在 HANDOFF.md → Next Step 落一段人类执行的 runbook（-ValidateOnly → -DryRun 并逐条读删除清单 → 真部署 → 保留 *.bak-<stamp> 直至确认），把「首次真实执行」定义为人类动作而非 agent 动作。
* A4（已独立复核成立、不再作为挑战的前提）：D2 的白名单闭集与「今天删除集合为空」（实测 127 = 82 + 45 + 0 域外；~/.dsh 侧 0 差异）；PLAN:81 的脚本结构、行号与插件数；TASK_BRIEF:6 的 base e9917a1；Pester/pwsh/5.1 版本；AUTHORITY_CONTRACT 历史段（:24-34 含 :34、:215）确属绑定旧 commit 的记录、不该重写 —— PLAN:100 的「不改并给出理由」成立。

## Verification Needed
（本轮不列任何执行 install.ps1 的验证项——沿用本轮硬禁令；涉及脚本行为的验证一律移到实现阶段、由 Author 在已批准后执行。）
1. 确认 Pester -CI 的写文件行为（不写文件）：pwsh -NoProfile -Command "Import-Module Pester; $c=[PesterConfiguration]::Default; $c.TestResult.Enabled.Value; $c.TestResult.OutputPath.Value; $c.Run.Exit.Value" → 预期 False / testResults.xml / False。
2. 确认 shim 实收 argv 的形态（会在临时目录写文件，不碰真实 HOME 与仓库）。
3. 批准 commit 之后复跑 AC9① 的冻结命令（只读）作为 B1 的收口证据；同域再跑 Select-String -Path README.md,docs/ai/AUTHORITY_CONTRACT.md -Pattern '整树备份' 作为 B2 的收口证据。
4. 修订后确认 AC9③ 的命令真实存在（只读）：git grep -n 'Invoke-Pester -Path tests' -- AGENTS.md 与 -- README.md。

## Recommended Next Step
1. 由 Author 在批准前修订：B1/B2 的 AC9 机械谓词与域；B3 的 AC5 ②/① 样本形态；B4 的 PLAN/HANDOFF 的 K 域与 AC3 用例数；B5 的 AC3 用例 5/6 改由临时假 repo 承载；B6 的互锁下沉子进程 + 互锁自身负向对照；并吸收 N1–N11。
2. 修订后重跑 9P（round 3，沿用本轮硬化 prompt）——被审规划文件已变（blob 会变），不能在旧 verdict 上批准；建议同时把「禁止任何指向真实 HOME / 指向仓库自身的真部署形态探针」写进 9P/9A/9B 三份 prompt（本轮禁令的永久化）。
3. 由人类在批准门拍板三件事：A2 的 SKIPPED 边界是否维持、PLAN:107 的插件清单 5 vs 6 本任务不改、HANDOFF.md:90 的 ~/.dsh 人工同步债是否延期；并在 IMPLEMENTATION_PLAN.md 亲自填 Status: Approved 后创建批准 commit。
4. 实现阶段把 B5/B6 的隔离与互锁当作第一批落地的测试基础设施（先有隔离与互锁，再有部署类用例），并把 last_test_run.txt 的产物范围限定为 -Configuration 关闭 TestResult 的运行，避免污染工作树快照。
```

### round 2 —— Author 逐条表态（三选一）

| # | 表态 | 处置与落点 |
|---|---|---|
| **B1** | **采纳并修订** | AC9① 的域改为 `-- . ':(exclude)docs/ai/**'`，负向对照同域；理由与后果照录（否则批准 commit 之后按构造不可能通过）。 |
| **B2** | **采纳并修订**（采用否定过滤形态） | AC9② 拆成两条：`MORARIUM-LOCAL-001` 全域零命中 + `Select-String -Pattern '整树备份' \| Where-Object { $_.Line -notmatch '不再\|已移除\|H3' }` 零命中。**保留**"不再整树备份/已由 H3 移除"这类订正叙述（这是真实披露，不能为过 grep 而删）。 |
| **B3** | **采纳并修订** | AC5 三用例重构为：① 不带 K8 的真部署（配对基准，日志 == 插件数）；② **K8 单跑的真部署**（配对对照，零调用）；③ shim 强制非零。并写明"dry-run/validate 不能充当该对照（恒真）"。 |
| **B4** | **采纳并修订** | PLAN 与 HANDOFF 的 K 域改为 **K1–K9**，且 PLAN 改为**不复制编号、只指向 `TASK_BRIEF.md`** 以免再漂移；AC3 用例数改为**六**。 |
| **B5** | **采纳并修订** | AC3 用例 5/6 的"源树"改为**临时假 repo**；并新增前置约束 4 的末句：任何用例都不得拿真实仓库当部署目标。 |
| **B6** | **采纳并修订** | 互锁**下沉到子进程**（断言生效 `$env:USERPROFILE` + 解析后三目标 + `claude` 解析到 shim，否则非零退出且不调用安装器）；**给互锁加负向对照**（真实 HOME 路径构造 → 未启动子进程，以哨兵文件为证）；AC7 增第 ⑦ 点（回显生效环境）+ 第 ⑥ 点（shim 日志）。 |
| **N1** | **采纳** | AC1 样本计数改为：5 对**全部**复用 K2（`-DryRun` 单跑）；K3（`-ValidateOnly` 单跑）作为**独立**通过样本单列。 |
| **N2** | **采纳** | 冻结 argv 比对口径 = **去掉 `"` 后的 token 序列**（并记录本机实测 shim 回显含转义痕迹，故不做含引号字面比对）。 |
| **N3** | **采纳** | AC6 期望集合改为**测试独立从源树枚举**（列出受管子集），禁止调用被测脚本内部函数；`[SUMMARY] deployed=<n>` 期望值同源。 |
| **N4** | **采纳并已实测** | 代跑确认：`-CI` 确实落 `testResults.xml`（在 CWD）；改用 `New-PesterConfiguration` + `Run.Exit=$true` + `TestResult.Enabled=$false` 形态并**实测退出码 0、仓根无产物**；该形态同时写进 AC9③/PLAN 的 Testing Plan 与根 `AGENTS.md`（改动 #8）。 |
| **N5** | **采纳** | AC7 增第 ⑥ 点；并记录本机**确实**装有真实 `claude`（`Get-Command claude` 为 True），故这条是硬门而非理论风险。 |
| **N6** | **采纳** | 前置约束 1 改为"`<被测 install.ps1 的实际路径>`，其所在目录即该用例认定的源树"。 |
| **N7** | **采纳** | AC4④ 限定为"**部署前已存在的**被镜像目录"（并说明临时 HOME 新建目录恒无备份，否则假红）。 |
| **N8** | **采纳** | AC11(a) 的清单扩为两类：**已移除机制** + **刻意不部署机制**（逐项写理由）；`PLAN` 中"注释对照表"改为"两条 `Select-String` 完整输出"。 |
| **N9** | **采纳** | 风险条目重编号（新增"Pester 落盘副作用"一条并实测结清）。 |
| **N10** | **采纳** | PLAN 的 Summary 补 Reuse-first 检索结论（检索范围 / 无可复用件 / 不引入新依赖）。 |
| **N11** | **采纳** | 预算估算改区间 400–800 行，并注明实现后如实记录实际行数。 |
| **A1** | **采纳** | 见 B6（前提改为"由子进程内断言保证"）。 |
| **A2** | **需人类裁决**（已列入批准门） | `SKIPPED` 边界是否维持：Author 建议**维持**（沿用今天行为与 README 说法），并已作为 Known Issues 第一项提请人类裁决。 |
| **A3** | **采纳** | PLAN 新增 Execution Step 8 与 HANDOFF Next Step 的**人类 runbook**（`-ValidateOnly` → `-DryRun` 读删除清单 → 真部署 → 保留备份）。 |
| **A4** | **接受** | 无需动作（Reviewer 独立复核成立的正向前提）。 |
| **VN-1** | **已代跑** | 见下方"round 2 代跑结果"。 |
| **VN-2** | **已代跑** | 见下方（shim 回显含转义痕迹 → 冻结为去引号 token 序列比对）。 |
| **VN-3 / VN-4** | **已代跑** | 见下方（AC9①/B1 与 AC9③/N4 的收口证据）。 |

### round 2 —— Author 代跑结果（真实命令 + 真实输出）

**VN-1（Pester `-CI` 的落盘行为）**
```
TestResult.Enabled 默认 = False      TestResult.OutputPath 默认 = testResults.xml      Run.Exit 默认 = False
# 在临时目录实跑 Invoke-Pester -Path <tmp> -CI：
exit=0 ; 临时目录内产物 = Probe.Tests.ps1, testResults.xml      # ← -CI 确实把 TestResult 打开并落盘
testResults.xml 出现在仓根? False                              # （本次 CWD 是临时目录）
# 改用 New-PesterConfiguration + Run.Exit=$true + TestResult.Enabled=$false：
Tests Passed: 1, Failed: 0, Skipped: 0 … exit=0 ; 仓根出现 testResults.xml? False
```
→ **N4 成立**；冻结命令形态已定，并写进 AC9③。

**VN-2（shim 实收 argv）**
```
shim 回显: ARGV=[plugin install \ context7@claude-plugins-official\]
真实 claude 是否在 PATH 上: True
```
→ 回显带转义痕迹，故 **argv 比对冻结为"去掉 `"` 后的 token 序列相等"**（N2）；并确认**本机真实 `claude` 在 PATH 上**（N5 的硬门是必要的，不是理论风险）。

**VN-3（AC9/B1 的收口证据）**：`git grep -n 'IUnderstandThisReplacesLiveConfig' -- . ':(exclude)docs/ai/**'` 在**修订后**重跑 → 见 `/implement` 阶段的 `last_test_run.txt`（此时尚未改文档）；**域改准这件事本身**已由本文件与 `TASK_BRIEF.md` 的修订落地。

**VN-4（AC9③ 的命令真实存在）**：`New-PesterConfiguration` 形态已实测（VN-1 第二段）；登记进 `AGENTS.md` 的动作在 `/implement` 的改动 #8 内完成。

**未能就地闭环的一项**：round 2 建议"修订后重跑 9P（round 3）"。**本文件记录 Author 的判断**：依 `reviewer-prompt.md` → 9P「**默认单跑一轮**、再审仅凭人类明示」，Author 不自行加轮；该建议已原样呈交人类，由人类在批准门决定是否要求 round 3。**未获人类明示前，本任务停在批准门，不以任何 verdict 代替批准。**

---

## round 3（硬化 prompt + round 2 摘要 + 人类 2026-09-15 三项裁决；**有效**）

> 触发：人类在批准门问"你建议再审一次吗"。Author 建议跑（理由：round 2 的 6 条 Blocking 全出在验收条款与机械谓词本身）、并已先落三项裁决的修订再发审。

### round 3 verdict（Reviewer 返回正文，逐字）

```
9P_round: 3
observed_head_sha: e9917a18d5a2b9b4df7e6b5c1cae2de89c49a512
task_brief_blob_sha: cbc947bbad50e495e894c52af996c85c772fd261
plan_blob_sha: a3b984363a9ae942ea3ccfc371af325c95096b26
writes_performed: none
model_route: deepseek-official/deepseek-flash@high

## 审查方法与已核实事实
本轮只读：git rev-parse/hash-object/status/log/branch/remote、Get-Content/Select-String/Get-ChildItem/Get-Command/Get-Module/Test-Path。绝对未执行 install.ps1、未执行任何测试/构建/安装器，未创建/修改/删除任何文件，未打开 docs/ai/review_9P.md。

round 2 六条 Blocking 的独立闭合复核（读工作树现文件，不信摘要）：B1 ✅（域改对；当前仅命中 install.ps1，批准后可达零）· B2 ✅（拆成 MORATORIUM-LOCAL-001 + 负向过滤；README:5 的「迁移安全锁定」在过滤接受集内，不会假红）· B3 ✅（三用例全为真部署形态，并写明 dry-run/validate 不能充当对照）· B4 ✅（PLAN 明写"不复制编号"；AC3 六用例）· B5 ✅（真实仓库不在互锁覆盖范围，改用假 repo 的理由成立）· B6 ✅（互锁下沉子进程 + 负向对照）。
N1–N11 抽样复核：N4 的 Pester 形态可用（Invoke-Pester 的 Configuration 参数类型 = PesterConfiguration，6.0.1）；N3 的枚举集合与仓库实况一致；N10 的「无可复用轮子 / 无 .gitignore」核实成立。
人类三项裁决的落实复核：① 插件 5 → 6 ✅（settings.json:53-58 实测恰好 6 个含 clangd-lsp；CLAUDE.md:151 含 clangd-lsp；AC2/AC5/PLAN 改动 #7⑦ 同改）；② SKIPPED 边界维持 ✅（D3 与 Known Issues；AC5 用例 3 未与 SKIPPED 混淆）；③ ~/.dsh 债本任务偿还 ⚠️ 落进了 AC10 第二笔与 Execution Step 9，但与 TASK_BRIEF 自身的 Non-Goals/Constraints 冲突（见 B-4）。
抽查通过的关键声称：install.ps1 实测 126 行 ✅；Backup-IfExists $dshDir 在 :82、DSH 段 :83-108 ✅；./tests 不存在 ✅；D2 的决定性前提（本机独有 127 = 82 + 45 + 0 域外）逐类枚举成立 ✅；~/.dsh 顶层无任何 *.bak-* ✅。

## Plan Verdict
修订后可批准（Blocking Issues 非空）

## Blocking Issues

B-1（新，机械级 / 假红）shim 用 claude.cmd，在本机真解析到真实 claude.ps1 → 套件按构造必红，且本轮整改前会真实触发网络安装
* 事实（实测）：Get-Command claude -All 在 pwsh 下返回 ExternalScript …\npm\claude.ps1（第一），其后才是 Application claude.cmd。npm 目录实测含 claude、claude.cmd、claude.ps1 三个文件。
* 后果：AC5/AC2/AC4/AC6/AC7 全部要求在「临时目录的 claude.cmd 前插 PATH」下跑真部署。由于 PowerShell 按目录优先级取首个匹配（同名多扩展名时固定顺序 .ps1 → .cmd，且不按 PATH 内位置交叉比较），npm 目录里的真实 claude.ps1 恒在 shim 之前：① 前置约束 3③ 的互锁 (Get-Command claude).Source == shim → 恒假 → wrapper 非零退出且不调用 install.ps1 → AC2/AC4/AC5/AC6/AC7 的每一个真部署用例失败（真·假红）；② 若实现者「绕过互锁」，则 & claude plugin install … 会打进真实 npm launcher，执行真实网络安装并写真实 ~/.claude —— 正是 AC7⑥ 自己写下的硬门所要防的路径。
* PLAN 已知此事：Risks #3（:114）自述「若 pwsh 优先解析同名 .ps1 则用例需固定扩展名」——但 Proposed Changes（:92、:147）仍冻结为 claude.cmd，风险未落成决定。
* Proposed Fix：把 shim 冻结为 claude.ps1（首选），或 shim 目录内同时放 claude.ps1+claude.cmd+无扩展名占位；并在 wrapper 内断言 (Get-Command claude -All | Select-Object -First 1).Source -eq <shim 路径>。

B-2（新，自相矛盾 / 无区分力）Testing Plan 里的手工命令 -DryRun -NoPluginInstall 按冻结域 K8 是真部署，与 AC1 对同一命令行形态的判定相反
* 事实：IMPLEMENTATION_PLAN.md:150-151 把 pwsh -NoProfile -File .\install.ps1 -DryRun -NoPluginInstall … 作为「dry-run 零写入的人工复核（AC2）」；而冻结域 TASK_BRIEF.md:92 定义 K8「单独出现即真部署」不得与 -DryRun 混为一类。
* 后果：同一命令形态在计划内有两套判定；按参数集互斥实现则该手工命令退出 1（读者会当成 AC2 失败），允许该组合则 K8 的边界断言失效。两者都让「按此计划执行」的结果不可复现。
* Proposed Fix：显式二选一——(a) -NoPluginInstall 属三个 ParameterSet（则该组合合法，删掉手工复核命令里的该 flag 或标注其合法）；(b) 该组合绑定失败（则 Testing Plan 两处必须删除）。

B-3（新，AC 判定方式）AC1 的「配对通过样本」未冻结参数面，与 PLAN 的一个候选实现（-DryRun 与 -ValidateOnly 互斥）按构造冲突
* 事实：TASK_BRIEF.md:108-116 的配对表 5 行全部写作 -DryRun …（省略号）；IMPLEMENTATION_PLAN.md:76 则把 K7 的绑定期失败实现为「-DryRun 与 -ValidateOnly 属不同 ParameterSet」。
* 后果：若用「放通配集、任选其一」写法，-DryRun + 路径参数 + 被移除开关这类混合形态是合法调用而不再必然失败 → 5 个失败样本中 3 个不再必然失败 → 判定表可按不同实现给出相反结果，等于该 AC 无区分力。
* Proposed Fix：把 AC1 的配对通过样本逐字冻结；并规定 K7 必须显式 ParameterSetName（-DryRun 单独成集），不得用放通配集实现。

B-4（新，内伤 / 自相矛盾）TASK_BRIEF 的 Non-Goals 与 Constraints 仍称「本任务不执行真实部署、不覆盖真实 ~/.dsh」，而 AC10 第二笔与 Execution Step 9 要求人类对真实 ~/.dsh 执行真部署
* 事实：TASK_BRIEF.md:63「不执行对本机真实 ~/.claude / ~/.codex / ~/.dsh 的部署」；:78「本任务不覆盖真实 ~/.dsh，故该笔按 Noted 处理」；而 :186-189（AC10 第二笔）与 PLAN:134、HANDOFF.md:96/128 明写由人类对真实 ~/.dsh 执行首次自动部署。
* 后果：验收条款文件对同一件事给出相反陈述 → 实现者按 Non-Goals 执行则证据永不存在，Reviewer 在 9A/9B 无法判"任务是否完整"。
* Proposed Fix：修订 TASK_BRIEF：:63 改为「除 AC10 第二笔由人类执行的一次 ~/.dsh 真部署外，不执行真实部署」；:78 的 Payback 段整体改写为「trigger = 首次用 install.ps1 覆盖 ~/.dsh 之前 → 人类裁决在本任务内偿还，见 AC10 第二笔」。

B-5（新，验收条款两分支同时闭死）AC10 第二笔把「人类未执行 → 记未偿还」与「本任务内偿还」并列为可满足分支，但同一份 TASK_BRIEF 已把该偿还冻结为任务内必须完成
* 事实：:188「人类未执行 → 本分支如实记为未偿还（不得标 Pass；不因此判任务失败）」；:83 修订记录⑬与 PLAN:183 均写「本任务内一并偿还」。
* 后果：AC10 在"做"与"不做"两条路径上都能自洽收口 → 该 AC 对"债到底还不还"没有区分力。
* Proposed Fix：二选一并写死（升级为收敛门的一部分，或明确降级为尽力项）。建议后者，并在 HANDOFF 保留 [DEBT] 未偿形态。

## Non-Blocking Suggestions
S-1 [U] 清单「两处逐条一致」的落点写错：应写明只改 §5 的清单文本、不得回填 §3；机械判据 = 这两项文本对相等，不是全文相等。
S-2 测试隔离粒度未冻结：temp HOME / 目标树 / 源树副本必须每用例新建（AC6③、AC2 负向对照、AC4④ 会互相干扰）。
S-3 AC2 对 [DELETE] 的断言弱于性质：应断言「以 [DELETE] 起首且含该绝对路径的行」，并另加「不存在含白名单样本的 [DELETE] 行」。
S-4 5.1 下 install.ps1 的中文/非 ASCII 会乱码（UTF-8 无 BOM + 5.1 按 ANSI 读），而 AC8 只看退出码。Fix：把"输出无乱码"写入产物，或把 5.1 面输出改为纯 ASCII。
S-5 -ClaudeDir <已在源树内的路径> 这一等价类未显式覆盖（"落在源树内"+"目标是目录"混叠）。
S-6 AC10 的「7 行 / 5 条」计数缺可执行谓词。
S-7 PLAN 两处陈旧/无关文字：:82 把 ~/.claude/projects/*/memory 列入「受管面来自 README 布局表」；:92 让 TestHelpers 提供「-Command 形态」封装，与前置约束 1 冲突。

## Assumption Challenges
1. K6（位置参数）在 H3 参数面下的失败原因会变（改由未知参数承担）；若实现给参数加了 Position，DryRun 可能被吞。建议 AC1 增干净样本。
2. ~/.dsh 与仓内 dsh/** 逐字节一致这一前提须在执行时刻复比。
3. AC9③ 的 -CI 负向对照是一次写文件动作，须记录产物路径 + 删除动作 + 事后 git status 干净。

## Verification Needed
VN-1（写文件，仅 $env:TEMP）claude.cmd shim 前插后的解析结果（B-1 核心事实）。
VN-2（只读）AC9①② 的命中集合。
VN-3（写文件，仅 $env:TEMP，不得用 install.ps1）K7 绑定失败的诊断文本与退出码。
VN-4（写文件，仅 $env:TEMP；实现前禁止执行）5.1 下是否乱码。
VN-5（只读）D2「删除集合为空」与 Step 9「逐字节一致」在执行时刻仍成立。

## Recommended Next Step
1. 先决：按 B-2 / B-3 把两个分叉问人类一句话并写死。2. 依 B-1…B-5 修订。3. 顺手落 S-1…S-7 并跑 VN-1/VN-3。4. 修订完成后由人类重跑一轮 9P（round 4）——本轮 5 条 Blocking 里 3 条出在「判定方式/自相矛盾」，与本仓上一任务「每次修判定方式又引入新缺陷」的实测规律同型，建议不要跳过再审直接批准。
```

### round 3 —— Author 逐条表态（三选一）

| # | 表态 | 处置与证据 |
|---|---|---|
| **B-1** | **不采纳（附实测反证）** | 本机实测：临时目录放 `claude.cmd` 并前插 `PATH` 后，`Get-Command claude` → **该 shim**（`Application …\Temp\shim-verify-…\claude.cmd`），真实 `%APPDATA%\npm\claude.ps1` 退居第二。**PATH 的目录顺序优先于扩展名优先级**，故"真实 `claude.ps1` 恒在 shim 之前"不成立；`(Get-Command claude).Source == shim` 的互锁断言**可满足**。**保留 `claude.cmd` 作为 shim**，并把该实测写进 PLAN Risks #3 与 TASK_BRIEF 前置约束 3（附反证输出）。 |
| **B-2** | **采纳并修订**（取其 (a) 分支） | K8 明确"**属全部三个参数集**"（`-DryRun -NoPluginInstall` 合法，但计划/校验态本就不执行插件步 → 该组合无判定价值）；Testing Plan 的手工复核命令**删掉 `-NoPluginInstall`**；"插件步被抑制"只在 **K8 真部署语境**下验证（AC5 用例 2）。 |
| **B-3** | **采纳并修订** | AC1 的配对通过样本**逐字冻结**为 `-DryRun -ClaudeDir <T>\claude -CodexDir <T>\codex -DshDir <T>\dsh`；写入实现约束：**K7 必须由显式 `ParameterSetName` 在绑定阶段实现**，禁止"放通配集 + 体内检查"。 |
| **B-4** | **采纳并修订** | Non-Goals 改为"不执行 **agent 侧**真实部署；唯一例外 = AC10 第二笔由人类对真实 `~/.dsh` 执行一次"；Constraints 的 Payback 段删掉"按 Noted 处理"，改为"人类裁决本任务内偿还"。 |
| **B-5** | **采纳并修订**（取其"升级为收敛门"分支） | 人类已裁决"本任务内一并偿还"→ 该笔是**承诺项**：未执行 = AC10 第二笔不成立 = **不得标"已收敛 / Ready to Commit"**，`/final-review` 必须列为未闭合项；唯一例外 = 人类当场给出新的明确延期裁决并记入 HANDOFF。**不允许两边都自洽收口。** |
| **S-1** | **采纳** | AC11 落点写准为"`DSH-LANDING-NOTES.md` **§5 的「未做/未验证」清单第 5、6 项**"，并写明"§3 导读节不得回填"；判据 = 这两项文本对相等，**不是**全文相等。 |
| **S-2** | **采纳** | TestHelpers 职责写死"每用例新建临时 HOME/目标树/假 repo 副本 + 用例后清理，禁止跨用例复用"；Testing Plan 说明三处会互相干扰的断言。 |
| **S-3** | **采纳** | AC2 断言改为"**存在以 `[DELETE]` 起首且含 `stray.md` 绝对路径的行**，且不存在以 `[DELETE]` 起首、含白名单样本路径的行"。 |
| **S-4** | **采纳（范围按实测收窄）** | 实测 `install.ps1` 有 **24 个非 ASCII 字节 = 7 处 em dash**（**无中文**），CP936 下读成 `鈥?`。→ 新增约束"重写后保持纯 ASCII"；AC8 增两条机械判据（零非 ASCII 字节 + 5.1 stdout 无乱码），负向对照 = base 上同一判据返回 `True`。 |
| **S-5** | **采纳** | AC3 用例 5 扩为同时覆盖 `-DshDir` 指向假 repo 源树自身 **与** `-ClaudeDir` 指向假 repo 的 `claude\` 子目录。 |
| **S-6** | **采纳** | AC10 补两条可执行谓词（证据表行数 == 7、继承要求条数 == 5，输出落 `last_test_run.txt`），并给负向对照（删一行 → 计数判据失败）。 |
| **S-7** | **采纳** | PLAN 的 Current Architecture 删掉 `~/.claude/projects/*/memory` 的混列；TestHelpers 只保留 `-File` 形态封装（并注明禁路）。 |
| **A-1** | **采纳** | AC1 增"干净 K6 样本"（`DryRun` + 三个合法临时路径参数 → 仍须 ≠0）+ 实现约束"不得给任何参数加位置绑定"。 |
| **A-2** | **采纳** | Execution Step 9 增"执行前由人类重跑一次只读比对确认 `~/.dsh` 与仓内 `dsh/**` 仍逐字节一致"。 |
| **A-3** | **采纳** | Testing Plan 纪律节增一条：会写文件的两处负向对照必须记录"产物路径 + 删除动作 + 事后 `git status` 干净"。 |
| **VN-1** | **已代跑** | 见下方（**B-1 被反证**）。 |
| **VN-2** | **已代跑（由 Reviewer 自己跑）** | Reviewer 已确认域正确（前者仅命中 `install.ps1`，后者仅 README:17/21）。 |
| **VN-3** | **推迟到实现阶段**（技术理由） | K7 绑定失败的真实文案取决于实现（参数集名/报错格式），此刻只能得到"未知参数"这一类，**结论不可迁移**；已由冻结的 Pester 用例在实现后断言并落 `last_test_run.txt`。 |
| **VN-4** | **推迟到实现阶段** | 需先实现 `-DryRun` 才能跑（Reviewer 自标 UNSAFE-UNTIL-IMPLEMENTED）；已落成 AC8 的机械判据。 |
| **VN-5** | **已代跑（部分）** | `~/.dsh` 顶层无 `*.bak-*` ✓；D2 的 127 = 82 + 45 + 0 由 Reviewer 独立复现 ✓。执行时刻的复比写进 Execution Step 9。 |

### round 3 —— Author 代跑结果（真实命令 + 真实输出）

**VN-1（B-1 的反证）**
```
无 shim 时:        C:\Users\16097\AppData\Roaming\npm\claude.ps1
前插 claude.cmd 后: C:\Users\16097\AppData\Local\Temp\shim-verify-9d721220\claude.cmd
Get-Command claude -All 前 3:
  Application    …\Temp\shim-verify-9d721220\claude.cmd      <-- shim 胜出
  ExternalScript C:\Users\16097\AppData\Roaming\npm\claude.ps1
  Application    C:\Users\16097\AppData\Roaming\npm\claude.cmd
（同目录再放 claude.ps1 后 → 解析到同目录的 claude.ps1：同目录内才有扩展名优先级）
npm 目录实体: claude, claude.cmd, claude.ps1
```
→ **B-1 不成立**：只要 shim 目录在 `PATH` 里更靠前，`claude.cmd` 即被优先解析，无需改扩展名。

**S-4 的实测**
```
install.ps1 非 ASCII 字节数 = 24（= 7 处 em dash；无中文）
行 10/17/21/75/77/81/95 的 `—` 在 CP936 下读成 `鈥?`
```
→ 采为"重写后保持纯 ASCII"约束 + AC8 的两条机械判据。

### round 3 之后：Author 对"是否跑 round 4"的评估（交人类裁决）

**Author 建议：不再跑 round 4，直接进批准门。** 理由（含对己不利之处）：

1. **本轮 5 条 Blocking 里 3 条（B-2/B-4/B-5）是 Author 按 round 2 修订时自己引入的自相矛盾**，不是设计层缺陷——成因是"改一处忘改对应处"；这类漂移已修掉，且其成因已由「修订记录 + 逐条表态表」外化为可复核文本。
2. **B-1 是事实断言错误**（已用实测反证）；**B-3 是真实的判定力缺陷**（已冻结配对样本 + `ParameterSetName` 约束）。
3. 母本对 9P 的定位是"**默认单跑一轮**"，并明确记载"把'再审一轮'当默认出口，是四个真实任务全部停在 `stopped, NOT converged` 的直接原因"（实测轮次 7/6/5/3）。本任务已跑 **3 轮**。
4. **剩余风险有更强的下游闸门**：这批 AC 由**可执行 Pester 套件**机械强制（不是散文），实现后还有 **9A/9B 双审**审真实 diff。
5. **反方理由（如实列出）**：Reviewer 明确建议重跑；AC 层是破坏性安装器的验收基础，若仍有内在矛盾，9A/9B 只能按同一份有毛病的 AC 审实现。

**因此**：Author 停在批准门，**不自行加轮**。人类可选：(a) 直接批准（Author 建议）、(b) 明示要求 round 4、(c) 先人工通读一遍 `TASK_BRIEF.md` 的 11 条 AC + 修订记录 再批准。
