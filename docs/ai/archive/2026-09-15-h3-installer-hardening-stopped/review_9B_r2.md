# review_9B_r2.md — 9B blind review, round 2

> 审查对象：`review_base_sha = e9917a1` → `review_tip_sha = 56d9878c1addd95d6d251795c532e205b1684691`；
> `handoff_snapshot_sha = 3d8c98ab607aa6b7716df3f0fb88466cb31cf11e`。
> 本文件是 Reviewer 返回正文的**原样落盘**（Author 转录，未改一字）。调用形态：`subagent` 前台 + `provider: deepseek-official` + `model: deepseek-flash` + `reasoning_effort: high`。
> **本轮未跑 9A round 2**：9B 的 Blocking #1 被标 `caused_by_last_fix: yes`，与 round 1 的 `yes` 叠加后 **streak = 2 → 触发 Critical 正式硬停**；依母本「停止事件优先级 ①」，未获人类确认前不得继续编码、不得再审（含 9A round 2）。

## 证据头

```
observed_head_sha: 3d8c98ab607aa6b7716df3f0fb88466cb31cf11e   （== handoff_snapshot_sha；审前快照自检通过）
worktree_clean: yes   （git status --porcelain 与 --porcelain --ignored 均为空；工作树内无 9A*/9B*/review_9*/review-*/*_raw.log/.dsh-review-*/.codex-review-* 模式文件 → 无污染；未打开 IMPLEMENTATION_PLAN.md / review_9*.md / archive/**，盲审隔离成立）
read_handoff_from: 工作树   （docs/ai/HANDOFF.md、docs/ai/last_test_run.txt 直接读工作树；未用 git show <tip>:…）
model_route: unknown-provider/deepseek-flash@unknown   （自报：本会话上下文不暴露 provider 与 reasoning effort，harness 自标仅 deepseek-flash；请 Author 与实发参数逐字比对，不得择一采信）
writes_performed: none   （零写入：未创建/修改任何文件或目录、未 commit、未跑测试与格式化器；本轮全部命令 = git rev-parse/status/diff/show/grep、Select-String、Get-ChildItem、Get-FileHash 等只读操作）
覆盖缺口: docs/ai/QUALITY_GATES.md   （在本轮 base..tip diff 内，但未列入 HANDOFF 的 review_sensitive_paths；照常审查，已读）
```

审查范围自核：`git merge-base e9917a1 HEAD == e9917a1`、`56d9878` 是 HEAD 的父提交（线性）、`56d9878:install.ps1` 与工作树 install.ps1 blob 相同。`git diff --name-only e9917a1..56d9878` 的非 docs 面 = `install.ps1` + `tests/*` + 6 处文档，与任务描述一致。

## Review Verdict

**不通过**（Blocking 非空：2 条 [Product]）。

**上一轮 blocking 闭核（先核后审，闭核不替代全量审查）**：
* **B-1（AC9① 冻结谓词假绿）→ 未闭合**。人类 Amendment 后的新判定形态**按构造恒真**：`git grep` 的输出是 `System.String`，字符串无 `.Line` 属性（`$_.Line` 恒为 `$null`），而 `$null -notmatch <pattern>` 恒 `$true`，故该 `Where-Object` 是空过滤器。我实跑精确形态 → **过滤后仍是 2 命中，不是零命中**；HANDOFF 的「内容(第15维) Pass | 否定过滤零命中」与其自己引用的 §E2（同一命令下打印了 2 行、标注「预期无输出」）直接矛盾 → 同类假绿复发。见 Blocking #1。
* **B-2（AC6 真部署路径缺「未被部署的机器态清单」）→ 已闭合**。`install.ps1:651-652` 在真部署**写入之前**打印 `[TARGETS]` 与逐行 `[PRESERVE] … (machine-local, never touched)`；`tests/install.Deploy.Tests.ps1:200-204` 有断言（≥1 行 + 两条精确路径）。残余问题降级为 Non-Blocking #1/#2。
* 另核上一轮 9A 的 B2（尾分隔符绕过 roots 冲突）→ **已闭合**：`Get-NormalizedRoot`（`install.ps1:600-607`）先归一化再用归一化后的 `$RootSpecs` 判冲突，`last_test_run §VN3` 第二条给出 `roots FAIL -ClaudeDir and -CodexDir …` 的真实输出。其余「另处置」项逐条核过：`-Force` 补齐（154/157/210/216/337/501）、逐项复制（501-503）、`archive` 末段保留（130-132，含新用例 88-90）、插件名由 `settings.json→enabledPlugins` 派生（`Get-ExpectedPlugins`，实测 6 项）、精确样本路径豁免（Deploy 测试 44-54）、`-SkipInterlock`/`RuntimeDir`/`ProgressLog` 已无残留、`machine-local-untouched` 改包含关系并有负向对照（AC3 case 7）——均成立。

## Blocking Issues

### 1. [Product] AC9① 的冻结判定形态恒真 → 判定输出 2 命中 ≠ 零命中；HANDOFF 仍记 Pass（假绿，与上一轮同类）
* `caused_by_last_fix: yes`（该判定形态是上一轮 review-fix 依人类 Amendment 新落的，见 HANDOFF Work Log 第 1 条 ⑩）。
* 证据（我在快照上实跑，只读）：
  * 命令：`git grep -n 'IUnderstandThisReplacesLiveConfig' -- . ':(exclude)docs/ai/**' ':(exclude)tests/**' | Where-Object { $_.Line -notmatch '已移除|不再是参数|removed|no longer' }`
  * 结果：`raw hit count = 2` / `filtered count = 2`，输出 `README.md:25` 与 `install.ps1:35`；`$hits[0].GetType().FullName = System.String`；`[string]$s='x'; ($null -eq $s.Line) = True`。
  * 因此 AC9①「否定过滤 → 零命中」在 tip 上**客观不成立**；退一步说，即使把 `tests/**` 域与 Amendment 全部计入，HANDOFF 的 `Pass` 也与其引用的 §E2 输出（2 行）矛盾，属**证据与账目相反的假绿**——这正是上一轮 B-1 的同一失效模式。
* 需注意：**被审文档的实质是好的**（两条命中都是「已移除/不再是参数/removed」的订正叙述）。缺陷在判定形态 + 账目：`git grep` 的 string 输出必须用 `Select-String`（返回 `MatchInfo` 才有 `.Line`）或在**字符串本身**上做否定匹配。
* **Proposed Fix**：① 把谓词改为 `… | Select-String -NotMatch '已移除|不再是参数|removed|no longer'`（或 `| Where-Object { $_ -notmatch '…' }`，注意作用在 `$_` 而非 `$_.Line`）；② 因 AC9① 的冻结文本本身要求了恒真形态，需**人类 Amendment（㉓）**记录订正后的形态（与 Amendment ⑳ 同形）；③ 重跑并把**新命令 + 完整输出 + 退出码**追加进 `last_test_run.txt`（含 base 负向对照——注意旧 §E2 的 base 对照用 `git grep -c` 标签却给出 `-n` 形态输出，对恒真过滤器没有任何区分力，须重做）；④ 同步修正 HANDOFF `Quality Gates` 的「内容(第15维)」行与 `Known Issues`。

### 2. [Product] README（review-sensitive，同 patch）声称「无 claude CLI 时记 SKIPPED **并打印手动命令**」，而重写后的安装器只打印 SKIPPED，从不打印手动命令（base 会打印）
* `caused_by_last_fix: no`（由实现 commit `8adc119f` 引入，本轮 review-fix 未触碰该行为）。
* 证据：
  * `README.md:27`：「…安装 **6 个**官方插件（… ；无 claude CLI 时记 SKIPPED 并打印手动命令）」。
  * `Select-String -Path install.ps1 -Pattern 'plugin install'` → 只有 `install.ps1:559: & claude plugin install $spec`（调用，无回显）；缺 CLI 分支 `install.ps1:553-556` 只输出 `[PLUGIN]   <name> SKIPPED (claude CLI not on PATH)` 并 `skipped++`。
  * base `e9917a1:install.ps1` 的缺 CLI 分支**确实**逐条打印 `  claude plugin install <name>@claude-plugins-official`——即这是重写引入的**行为收窄 + 同 patch 文档失准**（本仓 AGENTS.md：代码行为变化必须在同一 patch 内改准直接相关文档）。
  * 该分支同时是**零覆盖**分支（HANDOFF 自认的覆盖缺口之一，本轮未修）——所以文档错误不会被任何门发现。
* **Proposed Fix**：二选一，优先前者——① 在 `Invoke-PluginAction` 的缺 CLI 分支补回逐条手动命令（`Write-Line ('[PLUGIN]   {0} SKIPPED (claude CLI not on PATH); run: claude plugin install {1}@{2}' -f …)`，保持纯 ASCII）；② 若刻意不再打印，则把 README 该句改为「记 SKIPPED（汇总 `skipped=<n>`）」。两者都要顺带补一条缺 CLI 分支的用例（PATH 前置一个不含 `claude` 的空目录 + `-DryRun`/真部署任选其一，断言输出与 `skipped=6`、退出码 0）。

## Non-Blocking Suggestions

1. **[测试]`[TARGETS]` 无人断言。** 本轮 B-2 声称「真部署路径现在打印 `[TARGETS]` + 每行 `[PRESERVE]`；AC6 用例新增该断言」，但 `Select-String -Path tests\*.ps1 -Pattern '\[TARGETS\]'` = 0 命中——只有 `[PRESERVE]` 机器态行被断言。**Proposed Fix**：在 AC6 用例里加 `[TARGETS] claude=… codex=… dsh=…` 的断言（用临时路径转义匹配），否则该声称只剩一半有守护。
2. **[实现] 机器态清单不含 `~/.codex/config.toml`，且清单是「固定 inventory」而非「本次实际未被部署的项」。** `MachineLocalPaths`（`install.ps1:93-105`）列 11 项，但 AC4③ 与 README 都把「既有 `config.toml`」定义为本机态（seed-only、永不改）。**Proposed Fix**：把 `.codex/config.toml` 纳入报告（仅当存在时打印），并让测试断言清单的**完备性**（例如断言报告集合 == 测试独立算出的机器态集合，而不是现在的「≥1 行 + 2 条路径」）。
3. **[实现] 机器态清单印在真部署开头，不在结尾汇总块。** AC6 措辞是「汇总同时给出插件步逐项结果与未被部署的机器态清单」。**Proposed Fix**：在 `Show-Summary` 里再给一行 `[SUMMARY]  machine-local-not-deployed=<n>`（或重印清单），使「汇总」在字面上自洽。
4. **[测试/实现域不一致，latent] 源集枚举缺 `-Force`。** 本轮给镜像面补了 `-Force`（隐藏属性条目入镜像域），但测试侧 `Get-ManagedDeploySet`（`TestHelpers.ps1:277/284/289`）仍无 `-Force`。当前源树实测 0 个 Hidden 文件故不红，但一旦 `claude/rules` 等出现 Hidden 文件：安装器会多部署它 → `deployed=123` ≠ 测试期望 122（假红），反向扫描还会报「unexpected live-only file left behind」。**Proposed Fix**：三处源枚举补 `-Force`。
5. **[清理] 两处死代码，与本轮「删死字段」的声称不一致。** `TestHelpers.ps1:92 Test-PathInsideDirectory` 零引用（仅定义处 1 命中）；`Invoke-InstallerCase` 的 `-Environment` 参数无任何调用者（`-Environment` 0 命中），其 `SetEnvironmentVariable` 通路不可达。**Proposed Fix**：删除二者，或给 `-Environment` 找到用途（例如用它传递 `CLAUDE_SHIM_EXIT` 而不是重建 shim）。
6. **[清理] `install.ps1:594-598` 的 `$RootSpecs` 首次构造是死代码**（608 行立即用归一化值覆盖）。**Proposed Fix**：删掉第一处构造，只保留归一化后的那次。
7. **[账目] HANDOFF 的绑定块与缺口表未随 round 2 更新。** `HANDOFF:26` 仍写 `review_tip_sha: 8adc119f`、`:30` 仍写 `tested_sha: 8adc119f`（本轮实际 tip = `56d9878`）、`:33` `handoff_snapshot_sha` 仍未填；`:116` 的覆盖缺口表仍含「`machine-local-untouched` 无负向对照」（本轮已由 AC3 case 7 补齐）。**Proposed Fix**：落账时（窗口关闭后）一次性更新绑定块，并把缺口表改为 round 2 的实测状态（同时保留仍真实的缺口，如 CLI 缺席分支）。
8. **[边界值] `-ClaudeDir ''` 会静默回落到真实 HOME。** `Resolve-TargetDirectory` 用 `if ($Explicit)` 判空（`install.ps1:140`），空/空白串被当成"未提供" → 目标变成真实 `~/.claude`（K9 域外的边界值，故按 Non-Blocking 记）。**Proposed Fix**：三个路径参数加 `[ValidateNotNullOrEmpty()]`，或对显式空串直接报错退出（真部署语义下这条比 dry-run 更值得挡）。
9. **[行为收窄] dsh skills 由 base 的「枚举 `dsh/skills/*` 目录」改为硬编码两个名字**（`install.ps1:186`）。与 README 的「只有本工作流自有的两个目录被镜像」一致，故非缺陷；但新增 skill 将不再被部署且无任何测试/校验提示。**Proposed Fix**：在 `Test-Plan` 里加一条「源树 `dsh/skills/` 下存在未登记目录 → 提示」的信息行，或用一个用例把「第三个目录不被镜像」冻成显式行为。

## Test Coverage Gaps

* **`claude` CLI 缺席分支零覆盖**（与 Blocking #2 直接相关）：`-ValidateOnly` 的 `plugin-cli OK claude CLI not on PATH…` 与真部署的 `SKIPPED` 全无用例；当前只有 `-NoPluginInstall` 的 SKIPPED 被覆盖。
* **AC9①/②/③、AC10①②③、AC11(a)(b) 无 Pester 断言**，只有 `last_test_run.txt` 里的一次性驱动输出；而 AC11 的 (a)/(b) 驱动是**仓外机器态脚本** `%TEMP%\h3-verify.ps1`（本轮已两次因它的取域错误被订正：§I3、§VN3a）——不可独立复现。
* **白名单样本只落 2/6 被镜像目录**（claude/workflow、dsh/workflow）；`claude/rules`、`claude/commands`、`dsh/skills/*` 内的 `archive/**` 与 `*.bak-*` 无样本（HANDOFF 自认缺口，未修）。
* **K8（`-NoPluginInstall`）与 `-DryRun` / `-ValidateOnly` 的合法组合无用例**（K8 明言属三个参数集，`-DryRun -NoPluginInstall` 合法且未被任何用例触碰）。
* **`[TARGETS]` 与机器态清单完备性无断言**（见 NB #1/#2）。
* **AC6① (c)「`[SUMMARY] deployed=n` 的 n == 期望文件数」只在正常部署上断过一次**，没有"n 是恒真谓词"的负向对照（现有负向对照只在**测试侧重算**的判定上，不在被测汇总上）。

## Cannot Verify From Diff

* **本轮测试证据与 review_tip 无 SHA 绑定**：`last_test_run.txt:289` 记 `ROUND 2 … tested_sha: 23ea5bf06ee024c203ba4cffbe015866f073f4c5`，但 `23ea5bf` 的 install.ps1 **不含** `Get-NormalizedRoot`、**不含** `[TARGETS]`（实测 `False/False`），且 `git diff 23ea5bf..56d9878` 含 `install.ps1` + 4 个测试文件（273 插/75 删）——即被记的 sha 的树里**没有本轮修复**。同理 `HANDOFF:26/30` 的 `review_tip_sha/tested_sha = 8adc119f` 也指向 round 1。**我不重跑全量测试**（契约），故"这些退出码属于 tip 这份代码"无法从产物机械确认；仅能说 §VN3/§A3 的输出形态与 tip 行为一致（且工作树 `It` 计数实测 = 44，与 §A3 的 44/44 吻合）。
* **§J2 diff 预算数字陈旧**：记录 `9 files changed, 1560 insertions(+), 131 deletions(-)`，与 round 1 §J **逐字相同**；实测 `e9917a1..56d9878`（排除 `docs/ai/**`）= **1592 插 / 131 删**，`e9917a1..8adc119f` 才是 1560/131。即 §J2 是复制而非重跑（1592 仍远低于 4000，故不构成 AC 违约）。
* **AC10 第二笔（人类对真实 `~/.dsh` 首次自动部署）未发生**：实测 `~/.dsh` 下 `*.bak-*` 计数 = 0（与 §H 负向对照一致）——该笔债务确实 Unpaid，且账目**没有**预先宣告已偿还（合规）。
* 真实 HOME 受管面我只做了只读存在性/计数核验，不构成"隔离覆盖已生效"的证据（该证据属 AC7 用例内）。
* 5.1 腿的完整 stdout 只有 §D2 一份，且同样未与 tip 绑定。

## Verification Needed

1. **证伪「AC9① 零命中」**：`git grep -n 'IUnderstandThisReplacesLiveConfig' -- . ':(exclude)docs/ai/**' ':(exclude)tests/**' | Where-Object { $_.Line -notmatch '已移除|不再是参数|removed|no longer' }` → 当前输出 2 行；改成 `| Where-Object { $_ -notmatch '…' }` 或 `| Select-String -NotMatch '…'` 后应为空（退出码语义见命令尾）。**不写文件（只读）**。
2. **证伪「README 手动命令声称」**：只读替代 `Select-String -Path install.ps1 -Pattern 'plugin install'` → 仅 559 行的调用、无回显；**要真正证伪需在 PATH 中放一个不含 `claude` 的目录并真部署**（`$env:PATH` 前缀替换 + 临时 `-ClaudeDir/-CodexDir/-DshDir`）→ **会写文件**，必须在临时 HOME + 临时目标下跑，并保留 `[PRESERVE]`/`SUMMARY` 输出。
3. **证伪「tested_sha 即被测内容」**：`git show 23ea5bf:install.ps1 | Select-String 'Get-NormalizedRoot|\[TARGETS\]'` → 空。**不写文件（只读）**。
4. **在 tip 上复跑冻结命令并复核预算**：`pwsh -NoProfile -Command "$c = New-PesterConfiguration; $c.Run.Path = 'tests'; $c.Run.Exit = $true; $c.TestResult.Enabled = $false; Invoke-Pester -Configuration $c"` → 期望 44/44、exit 0、仓根无 `testResults.xml`；随后 `git diff --shortstat e9917a1..56d9878 -- . ':(exclude)docs/ai/**'` → 期望 1592/131。前者**会在 `$env:TEMP` 写临时树（仓内零写入，AC7 用例自带 `git status` 断言）**，后者只读。
5. **核机器态清单是否含 `config.toml`**：在临时 HOME 预置 `config.toml` 后 `pwsh -NoProfile -File .\install.ps1 -ValidateOnly -ClaudeDir <T>\.claude -CodexDir <T>\.codex -DshDir <T>\.dsh | Select-String 'PRESERVE'` → 期望看到 `.codex\config.toml`；实际不会出现（本条的"反例"即输出中缺该项）。**零写入**（`-ValidateOnly`）。
6. **复核 AC10 第二笔状态**：`Get-ChildItem $env:USERPROFILE\.dsh -Force -Filter '*.bak-*' | Measure-Object` → 现为 0（未偿还）。**只读**。

## Debt Verdict

**Unpaid**。

* AC10 第二笔（`~/.dsh` 人工同步无落账规范，trigger = 首次用 `install.ps1` 覆盖 `~/.dsh` 之前）**确实未偿还**：实测 `~/.dsh/*.bak-*` = 0，账目（HANDOFF `Remaining Risks / Debt` 的 ⏳ 行、`last_test_run` 结论）**如实标注未偿还、未预先宣告**，合规。按 TASK_BRIEF AC10 的 B-5，这一条独立于本 verdict 就把「已收敛 / Ready to Commit」封住。
* 无新增暗债：本轮观察到的两处死代码、陈旧账目数字、README 失准都已被我显式登记（Blocking #2 与 NB #5/#6/#7），不构成隐藏项。
* 已偿还/已闭合的历史条目（`tools/ac4-*`、`INSTALLER_GUARD.md` guard 债、第 3/5 条历史）保留在册，符合"不删历史"要求。

## Recommended Next Step

1. **交人类裁决 AC9①（Amendment ㉓）**：冻结文本要求的过滤形态（`$_.Line` 作用于 `git grep` 的 string 输出）按构造恒真，与 Amendment ⑳ 要修的问题同类。人类需在「改判定形态」与「以订正叙述为准、显式收窄声称」之间拍板；Author 不得自行改冻结的验收文本。
2. **Author 修 Blocking #2**（缺 CLI 分支补回手动命令，或改准 README 那句）并补该分支用例。
3. **Author 顺带清 NB #1（`[TARGETS]` 断言）、#4（源枚举 `-Force`）、#5/#6（死代码）、#8（空串回落真实 HOME）**；#2/#3（机器态清单完备性/落点）建议一并处理，成本很低。
4. **重绑证据**：在 `56d9878`（或其后的新 commit）上重跑冻结命令，把 `tested_sha`、§J2 数字、`last_test_run` round-2 头与 HANDOFF §Review & Test Binding 的 `review_tip_sha` 全部对齐；新增的 Amendment 与命令输出追加（不得覆盖 round 1/2 历史段落）。
5. **9A round 2 在本轮修复完成后跑**（顺序硬约束 9B 先、9A 后；本轮 9B 已完成）。
6. **硬停提示（交人类）**：round 1 与 round 2 均有 [Product Blocking] → 已达母本「连续 blocking 硬停」阈值（HANDOFF Fix-Loop Counter 现记 streak=1、阈值 2）。即便修复完成，也不得由 Author 自动进入 round 3；是否再跑一轮、以及 AC10 第二笔的人类真部署，都必须由人类明确裁决后执行。

## Requirement-Level Concerns

1. **「可判定」被写进冻结条款时没有被前置实跑验证。** AC9① 已因不可满足被 Amendment 修过一次，而新形态**仍然是恒真谓词**——说明"机械判定"这一层缺少最后一道自检。建议：凡在 AC 里写入 `Where-Object`/`Select-String` 谓词的，冻结前必须由 Author 在同一 patch 内**实跑一次该谓词 + 一条负向对照**，把命令与输出贴进规划文件；未贴输出的谓词不得算"机械判定"。同类风险同样存在于 AC10/AC11 的谓词（它们目前只靠仓外驱动的一次性输出托底）。
2. **部分验收条款的判定产物落在仓外、机器态脚本上（`%TEMP%\h3-verify.ps1`）。** 它本轮已两次被订正（§I3 取域错误、§VN3a 锚点错误），而 Reviewer 无法独立复现、也无法审它——即"验收可复现"这一条对 AC9②/AC10/AC11 只是名义成立。建议把该驱动入仓（例如 `tests/` 下的一个非 Pester 脚本或直接把这几条谓词写成 Pester 用例）。
3. **文档—代码一致性只被三条专项谓词覆盖，域外失准无人拦。** Blocking #2 就是域外反例（README 对插件缺 CLI 行为的现在时声称与代码不符，且该分支零覆盖）。建议把 AC11(a)「注释里的每个机制名必须能在代码中找到实现点」的形态**平移到 README**：README 对 `install.ps1` 行为的每句现在时声称都应有对应实现点或一条用例——否则每次重写都会留下一句无人核的假话。
4. **收敛门被人类动作卡住（AC10 第二笔）与代码面审查是两件事，账目上容易被混读。** 现在 `-DryRun`/`-ValidateOnly`/白名单都已可用，人类随时可跑那一次真部署；建议 `/final-review` 的 Manual Check 把它列为第一条显式未闭合项，避免"技术全绿但按定义不得收敛"的悬置被误记成通过。
