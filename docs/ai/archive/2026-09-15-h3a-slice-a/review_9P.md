# review_9P.md — 9P 计划审记录（切片 A / `task/h3a-parameter-surface`）

> 本文件是 9P 计划审的唯一落点：每轮 verdict（逐字）、Author 逐条表态、Verification Needed 代跑结果、人类减免记录（如有）。HANDOFF 的 `plan_review_9P` 行与 Work Log 只记状态词 + 指针，不复述内容；9A/9B 不读本文件正文。

## round 1（有效）

**调用**：`subagent` 前台 + `provider: deepseek-official` + `model: deepseek-flash` + `reasoning_effort: high`；prompt 内硬化禁令（**禁止任何执行型探针**、**禁止 `-IUnderstandThisReplacesLiveConfig` 字面量**——本分支 `install.ps1` 是 main 版旧脚本，该开关会**真机部署**；禁打开 `docs/ai/archive/**` 与 `review_9*`）。

### round 1 verdict（Reviewer 返回正文，逐字）

```
9P_round: 1
observed_head_sha: 54665e43c636105703a38500a1060b791934b46c
task_brief_blob_sha: 57e37c9f268e80043a31252b06854633134c581d
plan_blob_sha: 3702f412f81db5f2b2bee149443f60a5973a0cd0
writes_performed: none
model_route: deepseek-official/deepseek-flash@high

## Plan Verdict
修订后可批准

## Blocking Issues

B1 — 计划自行弱化的"执行前置约束 ③"与 TASK_BRIEF 的冻结条款直接冲突；按计划实现会让 AC1 全部用例在冻结条款下判失败。
证据：`IMPLEMENTATION_PLAN.md` L36「互锁简化（本切片）…不需要 claude shim 与 `(Get-Command claude).Source` 断言（该断言属切片 C）」；而 `TASK_BRIEF.md` L85 的冻结执行前置约束 ③ 明写「wrapper 在子进程内断言生效的 `$env:USERPROFILE` 与解析出的三目标…」并且该约束是全部用例共同适用、违反即用例失败——其冻结范围并未排除 claude 断言，计划却在 Frozen Acceptance 指针里把它划掉。这不是"细节自由度"，是改冻结验收条款（计划 L4 自己声明 TASK_BRIEF 是唯一落点、本文件不在该清单内）。
具体后果：Author 按计划写出只在子进程内断言 USERPROFILE + 三目标的 wrapper；Reviewer 按 L85 逐字核对，判定"执行前置约束 ③ 未满足 → AC1 每条用例失败"。两边都能自圆其说，收敛门无法判定。
参考实现已在停牌分支给出该断言的确切形态与成本（`git show task/h3-installer-hardening:tests/TestHelpers.ps1`）：`New-FakeClaudeShim`（15 行 `.cmd`）+ 一行 `if (-not $claudeCmd -or $claudeCmd.Source -notlike '<shim>*') { ... exit 97 }`，且该 shim 只记录 argv、不执行插件，与切片 C 的"插件步执行语义"无关。
Proposed Fix（二选一，需人类裁决）：(a) 保留断言——计划删掉"互锁简化"整段，TestHelpers 照停牌分支形态带上 shim 与 .Source 断言，同时断言"调用 -NoPluginInstall 样本时 shim 日志为空/未产生"（顺带把 K8 的"不执行插件步"变成可判定的）；(b) 收窄冻结条款——由人类批准把 L85 的 ③ 改为"本切片断言 USERPROFILE + 三目标；claude shim 与 Get-Command claude 断言随插件步推迟到切片 C"，并同步 TASK_BRIEF 的冻结文本与其哈希。默认建议 (a)：不削减既有轮子、不牺牲独立性。

B2 — AC3⑥ 的"机器态面"没有封闭清单，AC2 又把 codex/config.toml 归入"机器态样本"，与旧脚本的受管 seed 语义冲突；按字面实现会漏检或误删用户 config。
证据：install.ps1（本分支，L67-73）里 codex/config.toml 是受管路径（不存在 → 从 codex\config.example.toml 播种；已存在 → 打印 kept: 保留）；停牌分支 $MachineLocalPaths 是 11 条不含 .codex/config.toml 的闭集（.claude/settings.local.json、.claude/.credentials.json、.claude.json、.claude/sessions、.claude/projects、.codex/auth.json、.dsh/settings.yaml、.dsh/.credentials.yaml、.dsh/sessions、.dsh/storages、.dsh/profiles）。而 TASK_BRIEF.md L98 的机器态样本清单含 config.toml，且 L103/L104 要求 Test-Plan 判定"是否落在机器态面内"、AC3⑥ 只给了一个正例（<tempHome>\.claude\projects）。
具体后果（两条都真实可发生）：① 逆否形态——Test-Plan 的机器态谓词若为"在 ~/.dsh/sessions 等之下即失败"，一个把 config.toml 当"机器态"处理的实现会把它排除在 seed/保留之外，AC2 的判据里 config.toml 既不在 [DELETE] 也不在 [PRESERVE] 清单内 → 无任何判定覆盖它，切片 B 接手后可能直接 mirror-replace 覆盖用户的 model 配置（旧脚本明确不会）；② 正例形态——只测 .claude/projects 无法区分"包含关系判定"与"仅比较根下第一个路径段"：<tempHome>\.claude\projects-x 与 <tempHome>\.claude\projects.bak-20260101-000000 是两个尚未被任何样本覆盖的域内取值（K9 闭集允许"路径已存在"形态），前缀式误判会漏检。
Proposed Fix：(a) 在 TASK_BRIEF.md 冻结一个机器态闭集（建议逐字采用停牌分支那 11 条 + 明确声明 ~/.codex/config.toml 不在其中、它是受管 seed 目标且"已存在即保留"），并在 AC2/AC3 共用它；(b) AC3 增补两个域内样本：-ClaudeDir <T>\.claude\projects-x → ≠0，与 -ClaudeDir <T>\.claude\projects.bak-20260101-000000 → ≠0（并把这两个值登记进 K9 闭集，避免"域外反例"争议）；(c) AC2 的样本清单把 config.toml 的期望写明：已存在 → [PRESERVE]（或 kept: 行），不存在 → seed 动作行，且两条都不得出现在 [DELETE]。

B3 — AC1 的 K8 样本断言是恒真谓词，且计划在绑定层对其"属三个 ParameterSet"的确认不可判。
证据：TASK_BRIEF.md L81 冻结「K8 -NoPluginInstall（属三个 ParameterSet…本切片只断言绑定层可接受）」；L93 样本计数把 K8 记为"绑定可接受 1"。但 K8 的输入是单独 -NoPluginInstall——该参数在三个集合中都存在，PowerShell 只需匹配任一集合即绑定成功，故"exit 0"在任何一种声明形态下都成立（含"只声明在 Deploy 集"这种错误实现）。这正是本项目刚发生过的"谓词恒真"假绿同型：判定不含 X 也能通过，"移除 X 则会通过"的负向对照不存在。计划 L51 照抄了这条恒真断言，未提供任何对照。
具体后果：切片 A 声称已冻结 -NoPluginInstall 的参数面归属，实际上该归属零信号；切片 C 据此假设"参数面已验收"再改参数声明，参数面回归无人拦截。
Proposed Fix：把 K8 的判定改为三样本并可判：(a) -NoPluginInstall -DryRun … → 绑定成功且非绑定诊断；(b) -NoPluginInstall -ValidateOnly … → 同理；(c) 负向对照 -NoPluginInstall -DryRun -ValidateOnly → 绑定失败（证明互斥仍是绑定期硬门，而非"全放通配集"）。计数改写为"K8 绑定可接受 3（Deploy 形态由 K1 另计）"。若人类认为 (c) 属切片 C，则须把 L81 的声称降级为"本切片不声称 -NoPluginInstall 的参数集归属"，不得留恒真断言在册。

B4 — "5.1 兼容腿"与"5.1 腿用 powershell.exe 同形"的语义在本机不可同时成立，且计划未给实施方案；按此执行会得到"跑不通"或"用 Pester 3.4.0 跑套件"两种意外结果。
证据（一手实测）：Get-Module -ListAvailable Pester → 6.0.1 只装在 pwsh 7 的 ~/Documents/PowerShell/Modules；C:\Program Files\WindowsPowerShell\Modules 下只有 Pester 3.4.0。即 Windows PowerShell 5.1 上没有任何可用的 Pester 5+/6。IMPLEMENTATION_PLAN.md 的 Testing Plan 只有一条主套件命令（pwsh -NoProfile -Command … Invoke-Pester），5.1 腿只给了一条裸跑 install.ps1 的形态；而 TASK_BRIEF.md L85 ① 写「5.1 腿用 powershell.exe 同形」——"同形"指的是整个用例（含 Pester 宿主）用 powershell.exe 跑，还是被测脚本的 -File 宿主取 powershell.exe？两者结论完全相反。
具体后果：若按字面在 5.1 宿主跑套件 → 落到 Pester 3.4.0，Describe/It/-Configuration/Should -BeExactly 全套 API 不兼容，套件直接崩，而 Author 会把它解释成"环境问题"；若按"后者"理解 → AC 里那条"5.1 腿"在 last_test_run.txt 里没有可判定的证据形态，Reviewer 无法验收。
Proposed Fix：在 IMPLEMENTATION_PLAN.md 的 Testing Plan 与 TASK_BRIEF.md L85 ① 同时写明：5.1 腿 = 在 pwsh 7 的 Pester 套件内，以 HostExe = C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe 逐用例发起子进程（停牌分支 New-ChildWrapper -HostExe 已支持），并明确"Pester 套件本身只在 pwsh 7 下运行，不得在 powershell.exe 下跑 Pester（本机 5.1 侧只有 Pester 3.4.0）"；验收证据 = last_test_run.txt 内每条 5.1 腿的实际宿主路径与退出码。

## Non-Blocking Suggestions

S1 — "零副作用"里的"无新建目录"只按文件清单判定会漏报空目录。停牌分支 Get-TreeSignature 只枚举文件，而 TASK_BRIEF.md L89 要求"无新建目录"。旧脚本 L40-42 的三条 New-Item -ItemType Directory -Force 正是会创建空目录的动作。Proposed Fix：Get-TargetsSignature 同时输出目录相对路径标记行（如 d:settings/），并在 AC1③/AC2② 的断言里显式覆盖；建议保留 Test-Path 已知根不存在的初始态，使"新建根目录"成为可判信号。
S2 — K1 的判定形态（Deploy 集明确拒绝 vs 绑定失败）应与 AC1 的否定族断言一起冻结。计划 L17/L35/L64 三处声称"失败原因不是绑定诊断族"，但 TASK_BRIEF.md 的 K1 只写"不因绑定而失败"，未写"必须以非零拒绝执行"。Proposed Fix：在 TASK_BRIEF.md K1 条目补一句"K1 的验收 = ① 输出不含绑定诊断族；② 退出码 ≠ 0；③ 三个目标根零写入"。这样 K1 的"Deploy 拒绝"实现不再是计划单方面的自由选择。
S3 — 白名单判定建议增补"包含 archive 路径段"与"以 archive 结尾"的域内样本。TASK_BRIEF.md L98 明确白名单闭集含 archive 作为末段，但预置样本只有 workflow/archive/old/e.md（archive 为中间段），"含末段"这一半无判定。Proposed Fix：再加 workflow/archive 目录 + workflow/archive/e.md，断言两者均出现在 [PRESERVE]；并加一个域内反例 workflow/myarchive.md（叶子名含 archive 但非路径段）断言其出现在 [DELETE] 而非 [PRESERVE]。
S4 — P1 证据的"实现后必须转为 exit 0"应改为新增条目而非就地改写。TASK_BRIEF.md L111 的 P1 是"实现前"取证（当前 -DryRun → exit 1「找不到与参数名称 'DryRun' 匹配的参数。」），实现后 install.ps1 被整体替换，该证据将不可复现，Reviewer 无法在 tip 上重跑。Proposed Fix：保留 P1 原文为历史，另记 P1'（实现后同命令 = exit 0 + [PLAN]/[SUMMARY]）并把命令与输出落 last_test_run.txt；两者并存即构成"红→绿"的可读对照。
S5 — 输出契约的行前缀族应一次冻结。计划新增 [PRESERVE]（机器态清单）、[PLAN] plugin …、RESULT=REFUSED …，而 TASK_BRIEF.md L49 只冻结了 [PLAN] / [CHECK] / [SUMMARY]。Proposed Fix：在 TASK_BRIEF.md 的输出契约条目里一次性列出全部前缀族与它们的语义，避免切片 B/C 各自发明。
S6 — TASK_BRIEF.md L39 的"5 文件 44 用例"与事实有出入（非阻塞，防误引用）。Proposed Fix：把该句改为"5 个文件（4 个 .Tests.ps1 + TestHelpers.ps1），用例数见该分支 last_test_run.txt"，去掉易过期的硬数字。

## Assumption Challenges

A1 — "本切片零写入"的度量域选择（三个目标根）是对的，但计划把它当作"已知事实"而非"冻结裁决"。挑战点：如果切片 B/C 的人只读 AC 正文，会以为"零写入"覆盖整个临时 HOME，从而得出错误的"失败"结论。最低成本处置：把该收窄写进 AC2/AC3 的性质行（一句"零写入的度量域 = 三个目标根；宿主自产物不计"），而非只留在计划里。
A2 — "Deploy（无参数）明确拒绝执行并以非零退出"与 AC1/K1、Non-Goals 自洽性核查（本项结论：自洽，但建议把理由写进 TASK_BRIEF）。唯一缺口：K1 的"非零拒绝"目前只在计划里，TASK_BRIEF.md 的 K1 无此措辞 → 见 S2；若不加，切片 B 落地后 K1 从"拒绝"变"真执行"时，没有任何冻结条款记录这个语义跃迁。
A3 — "Build-Plan 的受管面与旧脚本一致"目前无法在切片 A 内验收，计划却把它写在"明确不改"里当作既定。挑战点：一个只列出 claude/* 而漏掉 dsh/skills/<bundle> 的 Build-Plan 能完整通过 AC2，而切片 B 会因此少部署两个 skill bundle。最低成本处置：AC2 增补一条"[PLAN] 覆盖的路径集合 = 旧脚本受管面清单（逐个点名，含两个 skill bundle 与 codex/config.toml seed 动作）"的判定。

## Verification Needed

1. `git show task/h3-installer-hardening:install.ps1 | Select-String -Pattern 'MachineLocalPaths = @\(' -Context 0,14` —— 核对机器态 11 条闭集（B2 的整改输入）。只读，不写文件。
2. `git show task/h3-installer-hardening:tests/TestHelpers.ps1 | Select-String -Pattern 'New-FakeClaudeShim|claudeCmd|Sentinel' -Context 2,2` —— 核对互锁三条断言与哨兵在 wrapper 内的顺序（B1 的整改输入）。只读，不写文件。
3. `Get-Module -ListAvailable -Name Pester | Select-Object Name,Version,Path`；`powershell.exe -NoProfile -Command "$PSVersionTable.PSVersion; (Get-Module -ListAvailable Pester).Version"` —— 复核 B4 的"5.1 侧只有 Pester 3.4.0"。不写文件。
4. `(Get-Content -Raw install.ps1) -match '[^\x00-\x7F]'` 与 `[System.IO.File]::ReadAllLines('install.ps1').Count` —— 基线取证：本分支旧脚本含 7 处 em dash、非 ASCII 判据 = True、126 行。只读，不写文件。
5. `git show task/h3-installer-hardening:install.ps1 | Select-String -Pattern 'PluginNames = @\(' -Context 0,8` —— 确认停牌分支的插件条数与 claude/settings.json 的 enabledPlugins（本分支实测 6 条）一致。只读，不写文件。
6. 待实现后（不属本轮）：`pwsh -NoProfile -Command "$c = New-PesterConfiguration; $c.Run.Path='tests'; $c.Run.Exit=$true; $c.TestResult.Enabled=$false; Invoke-Pester -Configuration $c"` —— 确认主套件命令在 Pester 6.0.1 下真能跑。会写文件；由 Author 在正常终端代跑。
7. 明确不列、也不得执行任何 install.ps1 的调用命令，直至 Approved plan commit 落地。

## Recommended Next Step

1. Author：按 B1 先行——向人类提出"保留 claude shim 断言（推荐）"还是"由人类批准收窄冻结条款"这一个二选一；在人类裁决前不要动 tests/TestHelpers.ps1 的互锁设计。
2. Author：按 B2 补齐 TASK_BRIEF.md 的机器态闭集与 config.toml 期望，按 B3 把 K8 改成可判负向对照，按 B4 在计划与冻结文本里把"5.1 腿"的实现形态写死（含"不得在 5.1 宿主跑 Pester"）。
3. Author：采纳 S1–S6 与 A1–A3 中不改变范围的部分（多为判据补句），落成 docs/ai/review_9P.md 的逐条 Author Responses（本轮修订后按流程由人类决定是否重跑 9P round 2）。
4. 人类：只对三个真取舍拍板——(a) B1 的两条路、(b) B2(a) 的机器态闭集内容（是否含 ~/.codex/config.toml）、(c) B4 的 5.1 腿定义；其余为计划内可用文字修掉的一致性缺陷。批准动作仍是：人类亲填 IMPLEMENTATION_PLAN.md 的 Status: Approved 并创建批准 commit。
```

### round 1 — Author 逐条表态（三选一）

| # | 表态 | 处置 |
|---|---|---|
| **B1** | **采纳并修订（取 (a)）** | 计划删掉"互锁简化"整段：**保留 claude shim + `(Get-Command claude).Source` 断言**（冻结条款 ③ 不动）。shim 在切片 A 的用途 = 隔离互锁（证明子进程内 `claude` 解析到临时目录）+ K8 的"不执行插件步"可判（断言 shim 日志为空）。**不削减既有轮子、不改冻结文本。** |
| **B2** | **采纳并修订** | (a) 在 `TASK_BRIEF.md` 冻结**机器态闭集**（11 条，逐字采用停牌分支那份），并**明确 `~/.codex/config.toml` 不在其中**——它是**受管 seed 目标**（缺失→播种、已存在→保留），AC2/AC3 共用该闭集；(b) AC3 增补两个域内样本 `-ClaudeDir <T>\.claude\projects-x` 与 `…projects.bak-20260101-000000` → ≠0，并把这两个值登记进 K9；(c) AC2 写明 `config.toml` 的期望（已存在 → `[PRESERVE]`/kept 行；不存在 → seed 动作行；两者都不得出现在 `[DELETE]`）。 |
| **B3** | **采纳并修订** | K8 改为三样本可判：`-NoPluginInstall -DryRun` / `-NoPluginInstall -ValidateOnly`（绑定成功且非绑定诊断）+ **负向对照** `-NoPluginInstall -DryRun -ValidateOnly`（绑定失败，证明互斥仍是绑定期硬门）；计数改写为"K8 绑定可接受 3"。 |
| **B4** | **采纳并修订** | 计划与 `TASK_BRIEF.md` 同时写死：**5.1 腿 = 套件在 pwsh 7 下运行、以 `HostExe = powershell.exe` 逐用例发起子进程**；**不得在 `powershell.exe` 下跑 Pester**（本机 5.1 侧只有 Pester 3.4.0）；证据 = 每条 5.1 腿的实际宿主路径与退出码。 |
| **S1** | 采纳 | `Get-TargetsSignature` 输出目录标记行（`d:<rel>/`），AC1③/AC2② 显式覆盖"无新建目录"（含空目录）。 |
| **S2/A2** | 采纳 | `TASK_BRIEF.md` 的 K1 补判定：① 输出**不含**绑定诊断族；② 退出码 ≠ 0；③ 三个目标根零写入（把"Deploy 拒绝执行"从计划自由选择升为冻结语义）。 |
| **S3** | 采纳 | 白名单样本补 `workflow/archive`（末段形态）+ `workflow/archive/e.md`，并加域内反例 `workflow/myarchive.md`（叶名含 archive 但非路径段）→ 必须出现在 `[DELETE]`。 |
| **S4** | 采纳 | P1 保留为历史，另记 **P1'**（实现后同命令 = exit 0 + `[PLAN]`/`[SUMMARY]`），两者并存构成红→绿对照；输出落 `last_test_run.txt`。 |
| **S5** | 采纳 | `TASK_BRIEF.md` 的输出契约条目一次列全前缀族：`[PLAN]` / `[CHECK]` / `[DELETE]` / `[PRESERVE]` / `[SUMMARY]`（切片 B/C 另加者在其自己的 AC 里冻结）。 |
| **S6** | 采纳 | 去掉"5 文件 44 用例"的硬数字，改为"5 个文件（4 个 `.Tests.ps1` + `TestHelpers.ps1`），用例数见该分支 `last_test_run.txt`"。 |
| **A1** | 采纳 | 把"零写入的度量域 = 三个目标根；宿主自产物不计"写进 AC2/AC3 的性质行，不只留在计划里。 |
| **A3** | 采纳 | AC2 增补："`[PLAN]` 覆盖的路径集合 = 旧脚本受管面清单（逐个点名，含两个 skill bundle 与 `codex/config.toml` seed 动作）"→ 把"与切片 B 执行集合一致"从散文变成域内可判。 |
| **VN1–VN5** | 已代跑（见下节） | 全部为只读命令，用于本轮的整改输入。 |
| **VN6** | 推迟到实现后 | 主套件命令的真实性验证属 `/implement` 后的证据（会写文件）。 |
| **VN7** | 遵守 | 本轮与后续在计划批准前**不执行任何 `install.ps1` 调用**。 |

### round 1 — Author 代跑结果（真实命令 + 真实输出，全部只读）

```
$ git show task/h3-installer-hardening:install.ps1 | Select-String 'MachineLocalPaths = @\(' -Context 0,14
  → 11 条闭集：.claude/settings.local.json · .claude/.credentials.json · .claude.json · .claude/sessions ·
    .claude/projects · .codex/auth.json · .dsh/settings.yaml · .dsh/.credentials.yaml · .dsh/sessions ·
    .dsh/storages · .dsh/profiles         （确认不含 ~/.codex/config.toml → B2(a) 的闭集内容据此冻结）

$ git show task/h3-installer-hardening:tests/TestHelpers.ps1 | Select-String 'New-FakeClaudeShim|claudeCmd|Sentinel' -Context 2,2
  → wrapper 顺序：断言 USERPROFILE → 断言三目标（TempHome 内 + 不在真实 home 下）→ 断言 claude 解析到 shim
    → 打印 CHILD-ENV → 写哨兵 → 调用安装器       （确认"哨兵不存在"确证安装器未被启动；B1 取 (a) 的直接依据）

$ Get-Module -ListAvailable -Name Pester | Select-Object Name,Version,Path
  → Pester 6.0.1 (…\Documents\PowerShell\Modules) ; Pester 3.4.0 (…\WindowsPowerShell\Modules)
$ powershell.exe -NoProfile -Command "$PSVersionTable.PSVersion; (Get-Module -ListAvailable Pester).Version"
  → 5.1.26100.9444 ; 3.4.0                       （确认 B4：5.1 侧无 Pester 5+/6 → 不得在 5.1 宿主跑 Pester）

$ (Get-Content -Raw install.ps1) -match '[^\x00-\x7F]' ; (Get-Content install.ps1).Count
  → True ; 126                                   （基线底本：旧脚本含非 ASCII（7 处 em dash）、126 行 → 计划里的
                                                  ASCII 负向对照有了可引用底本）

$ git show task/h3-installer-hardening:install.ps1 | Select-String 'PluginNames = @\(' -Context 0,8
  → 6 条：context7 / chrome-devtools-mcp / pyright-lsp / typescript-lsp / frontend-design / clangd-lsp
    （与本分支 claude/settings.json 的 enabledPlugins 6 条一致；本分支旧脚本只有 5 条、缺 clangd-lsp
     → 切片 C 的"双向一致"断言有实证依据）
```

**未跑项**：VN6（属实现后）。**本轮不执行任何 `install.ps1` 调用**（VN7）。

### 待人类裁决（三个真取舍；其余为计划/验收文本内可修的一致性缺陷）

* **(a) B1 的两条路** —— Author **建议 (a)：保留 claude shim 与 `.Source` 断言**（冻结条款 ③ 不动，不削减既有轮子）。
* **(b) B2(a) 的机器态闭集内容** —— Author **建议**：逐字采用上述 11 条，并**明确 `~/.codex/config.toml` 不在其中**（它是受管 seed 目标：缺失→播种、已存在→保留）。
* **(c) B4 的 5.1 腿定义** —— Author **建议**：套件只在 pwsh 7 下运行，5.1 腿 = 以 `powershell.exe` 作为**被测脚本的子进程宿主**；**不得在 `powershell.exe` 下跑 Pester**。