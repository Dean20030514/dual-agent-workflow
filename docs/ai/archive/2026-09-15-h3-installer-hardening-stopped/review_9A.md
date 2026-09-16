# review_9A.md — 9A standard review, round 1

> 审查对象：`review_base_sha = e9917a1` → `review_tip_sha = 8adc119fc453a016602fdc274e9a60c8fb003468`；
> `handoff_snapshot_sha = e56451a8390ac7524cc04651ca76290aea6be84c`（= 审前 HEAD）。
> 本文件是 Reviewer 返回正文的**原样落盘**（Author 于双审窗口结束后转录，未改一字）。调用形态：`subagent` 前台 + `provider: deepseek-official` + `model: deepseek-flash` + `reasoning_effort: high`。

# Review Verdict 证据头

```
observed_head_sha: e56451a8390ac7524cc04651ca76290aea6be84c   (== handoff_snapshot_sha 给出值)
worktree_clean: yes        (git status --porcelain 全工作树为空；--ignored 亦无 review/verdict/raw-log 残留)
read_handoff_from: 工作树   (docs/ai/HANDOFF.md 与 docs/ai/last_test_run.txt 均直接读取工作树文件，未使用 git show <tip>:)
model_route: unknown-provider/deepseek-flash@unknown   （本会话上下文中未暴露 provider 与 reasoning_effort；系统指令仅自述 "powered by deepseek-flash"。项目约定应为 deepseek-official/deepseek-flash@high，但那是推断、不作为证据——请 Author 与实发调用参数逐字比对）
writes_performed: none
coverage_check: review_sensitive_paths 覆盖 base..tip 全部必含类别（生产源码 install.ps1 / tests / TASK_BRIEF / 文档），diff 中无 migrations·schema、无构建配置与依赖声明/lockfile 改动 → 无覆盖缺口
extra_note_1: 工作树 HANDOFF 的 handoff_snapshot_sha 字段仍为「待统一落账时由 Author 填写」；本次快照绑定以「HEAD == prompt 给出的 handoff_snapshot_sha」为准（已核验通过），base/tip 两值与该文件 Review & Test Binding 逐字一致。
extra_note_2: 无意的输入越界——`git grep -n "clangd-lsp" -- .`（未加 `:(exclude)docs/ai/**`）使 docs/ai/review_9P.md 的 3 行匹配文本出现在我的工具输出里。我未主动 read/open 该文件，也未使用其任何内容作为本轮判据（本 verdict 的全部依据 = TASK_BRIEF 冻结条款 + 带排除项的正文 diff + 工作树 last_test_run.txt / HANDOFF + 只读检索）。如实登记，供 Author 落账判断。
```

---

# Review Verdict

**`不通过`**（Blocking Issues 非空，2 条 `[Product Blocking]`）。

审查范围 = `git diff e9917a1..8adc119f`（排除 `docs/ai/review_9*.md`、`docs/ai/archive/**`）：`install.ps1`（773 行改动，重写为 653 行 / 纯 ASCII，我独立复核非 ASCII 字节 = 0）、`tests/`（5 个新文件，42 个用例）、6 处文档、`docs/ai/INSTALLER_GUARD.md`（Repaid + 历史保留）。

**测试改动逐一确认（为过测试而绕过逻辑）**：`tests/**` 全部为新增文件，无既有测试被删/改/跳过；全文件无 `-Skip`、无 `Set-ItResult`、无用 `try/catch` 吞掉安装器失败（`Invoke-InstallerCase` 只做环境还原，异常路径仍取 `$LASTEXITCODE`）。测试侧**唯一**弱化点是「反向残留扫描的豁免过宽」「期望插件名取自被测源码」「零写入只测三个目标根」——分别记入 Non-Blocking Suggestions / Test Coverage Gaps / Verification Needed，均不与"为过测试而弱化产品行为"同级。未发现任何测试断言被写成恒真。

**回归面核验（被改字段/路径的其它生产者与消费者）**：
* 插件清单：第二生产者 = `claude/settings.json` → `enabledPlugins`（我实读 = 6 个，名称与 `install.ps1` 的 `$PluginNames` **逐字相同**，含 `clangd-lsp`）与 `claude/CLAUDE.md:151`（散文）→ 一致；README 的 5→6 与 `[SUMMARY]` 字段说明同步改准。
* 被移除开关 `-IUnderstandThisReplacesLiveConfig`：`docs/ai/**` 之外的其它引用（`portable/**`、`claude/**`、`dsh/**`、`IMPROVEMENT_PLAN.md`）实读**无残留**；`IMPROVEMENT_PLAN.md` 只作为 REFERENCE ONLY 未改，符合其状态。
* 部署路径集合：`Build-Plan` 与改动前一致（`~/.dsh/skills` **不整树**镜像，只两个 skill 目录；`codex/config.toml` 仍 seed-only）→ 未破坏既有镜像契约，`AUTHORITY_CONTRACT` 的相关陈述仍然成立。
* 本机 127 个 live-only 文件（82 `archive/**` + 45 `*.bak-*`）：`Test-PathKeepLocalOnly` 用「`archive` 整段匹配 + `*.bak-*` 叶名」实现，与该闭集吻合（`-contains`/`-ieq` 为大小写不敏感）→ 未发现新的误删类。
* `[SUMMARY]` 输出契约：消费者 = `tests/**`（前缀正则）与 README（已含新字段）→ 无破坏；但字段表本身相对 PLAN D4 有偏离（S3）。

## Blocking Issues

### B1 `[Product Blocking]` AC9① 按冻结判定**未满足**，且 `last_test_run.txt` 与自己写下的预期相反却记为通过

* **具体反例（来自 `last_test_run.txt` 本身）**：`docs/ai/last_test_run.txt` §E 第 169 行自己写明 `# 预期零命中（exit 1）`，紧接着的输出是 **4 条命中**（`README.md:25`、`install.ps1:33`、`tests/install.Parameters.Tests.ps1:38`、`:46`、`:61`）与 **`exit code: 0`**；而 §「结论」第 285 行写「**本轮无未跑项**」。`TASK_BRIEF.md` AC9① 的判定被逐字冻结为：`git grep -n 'IUnderstandThisReplacesLiveConfig' -- . ':(exclude)docs/ai/**'` → **零命中**，域 = 除 `docs/ai/**` 外的全部。
* **具体后果**：这条「已移除开关零引用」的验收点在冻结形态下**为假**，却被证据文件与 HANDOFF → Quality Gates「内容(第 15 维) = Pass（§E/§F 的零命中）」当成通过。`README.md:25` 与 `install.ps1:33` 的命中是本次实现 commit 新写进去的措辞（PLAN 改动 #7② 要求 README 点名该开关），`tests/install.Parameters.Tests.ps1` 的三处命中的 token **是拒绝断言的必需输入——按构造无法消除**：即 AC9① 的域与 pattern 在批准 commit 之后**按构造不可能通过**（这正是 round 2 的 B1 想修掉的形态，只把域收窄到排除 `docs/ai/**` 并不足够）。AC 的「性质」句虽写「除历史记录外」，但 `tests/**` 是当前代码、不是历史。
* **caused_by_last_fix: yes** —— 命中由本次实现（`8adc119f` 的 README/注释措辞与新增测试）+ 上一轮规划修订（round 2 B1 / round 3 ⑨ 的域与 pattern 改准）共同引入；本轮为双审首轮，按母本 streak 至多计 1（未达硬停阈值 2）。
* **Proposed Fix**：二选一（属验收修订，**须人类裁决**）——(a) 把 AC9① 改成与 AC9② 同形的**否定过滤**谓词（允许「已移除 / 不再是参数 / H3」这类订正叙述），并显式把 `tests/**` 排除在域外；(b) 保留零命中，但把域收窄为「文档面（README / 根 AGENTS.md / `claude/rules/README.md` / `docs/ai/AUTHORITY_CONTRACT.md`）+ `install.ps1`」并把 `tests/**` 排除。两条都必须同时更正 `last_test_run.txt` §E 的预期行与「结论」节，把 AC9① 记为**未满足**而不是「无未跑项」。

### B2 `[Product Blocking]` K9④「同一个路径」的拼写变体绕过 `roots` 互锁：自冲突配置被放行并报 RESULT=OK

* **代码路径（从 diff 读出）**：`install.ps1:138-142` `Resolve-TargetDirectory` → `Get-FullPath`（`[System.IO.Path]::GetFullPath`）**保留尾部分隔符**（我实测：`GetFullPath('C:\temp\a\')` → `'C:\temp\a\'`，且与 `'C:\temp\a'` 的 `-ieq` 结果为 **False**）；`install.ps1:399-408` 的互锁直接比较 `$RootSpecs[$i].Path -ieq $RootSpecs[$j].Path`，**未做归一化**；同一文件的 `Test-PathInside:457-458` 却做了 `.TrimEnd('\')`，说明这是局部遗漏而非设计选择。`Join-Path` 会把双分隔符折叠（实测 `Join-Path 'C:\temp\a\' 'workflow'` → `'C:\temp\a\workflow'`），所以两个根最终**指向同一目录**、镜像互相覆盖。
* **具体输入 → 预期 vs 观察（域内 K9④，两值就是同一个路径）**：
  `pwsh -NoProfile -File .\install.ps1 -ValidateOnly -ClaudeDir <T>\shared -CodexDir <T>\shared\ -DshDir <T>\other`
  期望（AC3 用例 4 + D3「参数自洽失败」）：退出码 1 且同时点名 `-ClaudeDir` / `-CodexDir`。按代码读出的观察：命中不了 `roots` 冲突分支 → 打印 `[CHECK] roots OK three distinct target roots` → `RESULT=OK`、退出码 0。
* **具体后果**：当是 `-ClaudeDir <T>\shared -DshDir <T>\shared\` 这一对时，`claude\workflow` 与 `dsh\workflow` 两个 mirror 动作目标同址；我实读两者文件集：`claude/workflow` 的 10 个文件**全部**存在于 `dsh/workflow`（仅 `fanout-toolchain.md` 为 dsh 独有）→ 后执行的 DSH mirror 直接把 claude 母本内容**覆盖**为 DSH 母本（两套判据不同源），同时 `codex/AGENTS.md`、`config.toml` 会被写进 claude 树、`~/.codex` 完全没有被部署；全过程 `RESULT=OK`、退出码 0、`[VERIFY] ... OK`。触发方式是**一个字符**：从资源管理器地址栏复制目录路径会带尾部反斜杠，另一个参数手打——正是这个互锁存在的理由。可达性确定（纯参数取值），后果确定（静默合并/覆盖 + 报成功）。
* **caused_by_last_fix: yes** —— 参数面与 `roots` 互锁整体由 `8adc119f` 引入（不存在上一轮 9A/9B 修复）。本轮 streak 至多 1。
* **Proposed Fix**：在解析根之后立刻归一化一次，并用归一化值构建 `$RootSpecs` 与 `$Roots`，例如 `$ClaudeRoot = (Resolve-TargetDirectory ...).TrimEnd('\')`（三个根同法）；或把冲突判定改为 `(Test-PathInside -Child A -Parent B) -and (Test-PathInside -Child B -Parent A)`（该函数已带 `TrimEnd`）。修完请用上面的 `-ValidateOnly` 命令在临时目录复现确认（零写入），并把真实输出追加进 `last_test_run.txt`。

## Non-Blocking Suggestions

* **S1（README 声称宽于实现）** `README.md:19` 说 `-ValidateOnly` 会检查三个目标根是否「落在**机器态面上**」。实现的 `machine-local-untouched:`（`install.ps1:424-440`）是把 `$a.Target` 与 `Join-Path $env:USERPROFILE $m` 做**相等**比较：① 一旦传了 `-ClaudeDir/-CodexDir/-DshDir`（也就是所有测试场景），比较对象是**真实** home，该分支在测试里恒不可达；② 即便在默认 home 下，它也**抓不到"目标落在机器态目录之内"**（如 `-ClaudeDir <home>\.claude\projects` → 目标 `<...>\projects\CLAUDE.md` 不相等 → 仍打印 `machine-local-untouched OK`，然后在机器态目录里写入并对其子目录做 mirror-replace）。**Proposed Fix**：把 README 该句收窄为「三个目标根是否互相冲突、是否落在源树内」，或把检查改为**包含关系**判定（`Test-PathInside -Child $a.Target -Parent $mFull`）并补 VN3 的对照。
* **S2（AC6 性质句 vs 实现）** AC6 性质要求「汇总同时给出插件步逐项结果与**未被部署的机器态清单**」，但 `Get-MachineLocalReport` 只在 `-ValidateOnly`（`install.ps1:606`）与 `-DryRun`（`:619`）分支打印；**真部署路径从不打印该清单**（只打 `[PLUGIN]` 行 + `[SUMMARY]`）。**Proposed Fix**：真部署路径也在 `Show-Summary` 前打印同一份 `[PRESERVE] ... (machine-local, never touched)` 清单；或请人类把该半句从 AC6 移除（TASK_BRIEF 修订只能由人类裁决）。
* **S3（偏离 PLAN 的冻结输出契约）** 实现把 `[SUMMARY]` 扩展为 8 字段（新增 `seeded=<n>`），而 `IMPLEMENTATION_PLAN.md` → D4 写明字段「顺序与拼写冻结」。测试只用前缀正则，故无破坏，但台账与实现不一致。**Proposed Fix**：在 PLAN 的 D4 补上 `seeded=<n>`（`docs/ai/` 非审查敏感面），或去掉该字段改由 `deployed` 计数。
* **S4（注释与代码不符）** `tests/TestHelpers.ps1:206-208` 的注释写「把 LOCALAPPDATA/APPDATA 指向同级临时目录」，但生成器里**没有任何**对应行（`$lines.Add` 只有 `USERPROFILE` / `PATH` / `realHome` / `targets` / `expectedHome`）；HANDOFF → Known Issues 自己也记录了「重定向实测无效」。**Proposed Fix**：删掉该注释，或改写为实际原因（宿主产物 \<home\>\AppData\…，故零写入只测三个目标根）——这正是 AC11 那条「注释不得描述不存在的机制」在测试基建上的同类情形。
* **S5（反向残留扫描豁免过宽）** `tests/install.Deploy.Tests.ps1:46-50`：`if ($leaf -like '*.yaml') { continue }`、`$leaf -eq 's.json'`、`sessions\*` 等豁免覆盖的是**目标根**里的机器态样本，却对所有层级生效 → 镜像目录内出现非白名单 `.yaml` 残留时同一判定不会报。**Proposed Fix**：把豁免收窄为样本的精确相对路径（`settings.yaml`、`.credentials.yaml`、`sessions\s.json`、`config.toml`、`settings.local.json`）。
* **S6（AC9② 在 `AUTHORITY_CONTRACT.md` 上是假绿 + 同文件仍有现在时的失效声称）** 该文件的那一行（「2026-09-06 增补」块）**仍然以现在时写着**「会先把**整个 `~/.dsh` 整树备份**为 `~/.dsh.bak-<stamp>`（含 `sessions/`、`storages/`、`.credentials.yaml`）」并说「与 `README.md` 锁定说明同口径」（README 现在说的是相反的）；H3 的订正追加在同一行末尾。AC9② 的谓词逐**行**过滤 `-notmatch '不再|已移除|H3'`，而这一行本来就含 `H3`（「H3 的差别」「H3 的 drift check」）→ 该文件上这条判定**恒真、无区分力**。计划改动 #11 明确「只加日期订正、不改历史陈述」，所以这不是施工偏差，而是**判定设计与措辞的落差**。**Proposed Fix**：① 请人类裁决把 `AUTHORITY_CONTRACT` 的这一段显式声明为「历史记录、不属 AC9② 判定域」；或把谓词改成要求订正词与「整树备份」**同句相邻**；② 顺手把「与 README.md 锁定说明同口径」这句失效指针就地标注为已作废。
* **S7（无暗账措辞扫描）** 我按母本对 diff 全文扫 `later / temporary / for now / 暂时 / 先这样 / 回头再说 / should be fine / TODO`（生产面 + 测试 + 新增文档）：未发现隐藏妥协措辞；`[DEBT]` 一侧新增的那条（无常驻守护装置）已按格式登记并带 trigger。此项无 finding，仅登记已扫。

## Test Coverage Gaps

1. **期望插件名取自被测源码**：`tests/TestHelpers.ps1:304-326` `Get-PluginsFromSource` 用 AST 解析 `install.ps1` 的 `$PluginNames`，`install.DryRun.Tests.ps1:45-48` 与 `install.Deploy.Tests.ps1:136,145-149` 以它为期望值 → AC2/AC5 的「6 个插件名」断言是**自指**的：把 `clangd-lsp` 换成任意别的名字（仍 6 个）42/42 全绿，而人类 2026-09-15 裁决的正是这个名字。`Count -Be 6` 只锁住数量。**建议**：期望名单改由 `claude/settings.json` 的 `enabledPlugins`（真实第二生产者）或 AC5 冻结的六个字面量派生。
2. **AC6① 的 `[VERIFY]` 断言只抽样**：`install.Deploy.Tests.ps1:182-185` 只断言 `CLAUDE.md/settings.json/rules/workflow/commands` + `dsh\workflow`；`codex/AGENTS.md`、`dsh/AGENTS.md`、`dsh/skills/*` 虽被实现打印，但无断言（AC6 原文是「每个受管目标」）。
3. **5.1 腿只覆盖 `-DryRun`**：AC8 冻结的正是 `-DryRun`，故 AC 达标；但真部署路径（备份/删除/插件/汇总）在 `powershell.exe` 5.1 下**完全未被执行**——`Get-FileHash -Algorithm`、`Join-Path`、`$LASTEXITCODE` 等的 5.1 行为只有 DryRun 覆盖。属已知残余，建议登记而非补测。
4. **`machine-local-untouched` 无任何负向对照**（套件与 `last_test_run.txt` 都没有）；见 VN3。
5. **AC1/AC2 的零写入断言只覆盖三个目标根**（见 VN1）；`*.bak-*` 的全 HOME 扫描只在 DryRun 用例里有（`install.DryRun.Tests.ps1:13,22`）。

## Cannot Verify From Diff

* **AC10③ 的「≥ 既有笔数」**：只能确认当前 `docs/ai/HANDOFF.md` 的 `^\[DEBT\]` = **9** 行（我实读 89–97 行）与 `last_test_run.txt` §H 的 9 一致；「既有 8 笔」出自被我禁读的 `docs/ai/archive/**`（空闲期 HANDOFF），无法独立复核。
* **AC11 的判定器**：`last_test_run.txt` 第 6 行自述 driver = `%TEMP%\h3-verify.ps1`，**该文件不在仓库**，§I 展示的是它的**汇总输出**（`declared params = …` / `unexplained =`），而不是 AC11 冻结的「两条 `Select-String` 的完整输出 + 退出码」；其中 `-File` / `-ExecutionPolicy` 两个只在注释 usage 行出现、既不在 param 块也不在「Deliberately NOT done」清单里的 token 被判为「已解释」，判定逻辑不可复现（→ VN5）。
* **AC8 的 5.1 stdout 完整性**：`last_test_run.txt` §D 只存了一行 `[PRESERVE]` + `[SUMMARY]` 的摘录，不是 AC8 要求的「完整 stdout」，无法复核乱码扫描是对全文做的（→ VN6）。
* 我未打开、也未使用 `docs/ai/archive/**`、`docs/ai/review_9*.md`（含 `review_9P.md`）的任何内容；上文 extra_note_2 记录了一次意外命中。

## Verification Needed

> 均为单个最小检查（非全量套件），请 Author 代跑并把真实输出 + 退出码**追加**进 `docs/ai/last_test_run.txt`。全部可在临时目录 / 子进程内完成，**不得**指向真实 HOME（PLAN 测试纪律）。

1. **VN1 — AC1 的零副作用是不是真的覆盖「临时 HOME 递归」**：AC1 性质与判定 ③ 写的是「目标树与**临时 HOME** 的递归内容哈希前后逐字节相同」，而套件用的是 `Get-TargetsSignature`（只有三个目标根），HANDOFF → Known Issues 第 3 条自述是刻意调整。最小检查：在 K5 样本前后对 `<T>\home` 递归签名、**排除 `<T>\home\AppData`**（宿主自产物），一次即可。若仍相同 → AC1 的声称可保留；若不同 → 请按母本把声称收窄（或请人类订正 AC1 措辞）。
2. **VN2 — 隐藏条目类：AC2「完整计划」与 AC6(a)「无源外非白名单残留」**：在预置目标树里放一个**带 Hidden 属性**的 live-only 文件（如 `attrib +h <T>\home\.claude\workflow\.local.md`），跑 `-DryRun` 与真部署。依据：`install.ps1:210,216` 的 `Get-ChildItem -File/-Directory -Recurse` **不带 `-Force`**，`Invoke-MirrorAction` 的删除也走同一份 delta，且实现**从不反向枚举目标树**。预期（按 AC2/AC6(a)）：该文件出现在 `[DELETE]` 行并被删除；若「既不列也不删、仍 `RESULT=OK`」，即 AC2「完整计划」与 AC6(a) 有具体反例。
3. **VN3 — `machine-local-untouched` 的对照（可隔离执行，不碰真实 HOME）**：在子进程内（`$env:USERPROFILE` = 临时 HOME，既有互锁照常生效）预建 `<tempHome>\.claude\projects\`，跑 `-ValidateOnly -ClaudeDir <tempHome>\.claude\projects -CodexDir <tempHome>\.codex -DshDir <tempHome>\.dsh`。预期：该检查应 `FAIL`（等值命中）；再跑 `-ClaudeDir <tempHome>\.claude\projects\x` 观察**嵌套**情形是否仍报 `OK`（我的代码读出是 OK）。这一条同时给出该守护的「若移除 X 则会通过」对照。
4. **VN4 — AC9② 否定过滤谓词在 base 上的区分力**：`git show e9917a1:docs/ai/AUTHORITY_CONTRACT.md | Select-String -Pattern '整树备份' | Where-Object { $_.Line -notmatch '不再|已移除|H3' }`。若 base 上也是零命中 → 该谓词对本文件无区分力（与 S6 同一发现，用于决定是否需人类订正 AC9②）。
5. **VN5 — AC11(a) 的两条谓词原样复现**：按 AC11 冻结的形态实跑并从 `install.ps1` 注释抽取全部 `-<Switch>` 与 `~/.<path>` 字面量，**贴上完整输出 + 退出码**；特别说明 `-File` / `-ExecutionPolicy` 归入哪一类（若归入「注释显式清单」，请把该清单写进 `install.ps1` 注释或把判定脚本纳入仓库，否则该谓词不可复现）。
6. **VN6 — AC8 的完整 5.1 stdout**：把 `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -DryRun -ClaudeDir <T>\... ` 的**完整 stdout** 落 `last_test_run.txt`（或写明 §D 用了什么过滤），并说明乱码扫描覆盖的是全文。
7. **VN7 — AC9③ 冻结命令逐字执行一次**：§A 实跑的是加了 `$c.Output.Verbosity = 'Normal'` 的形态；请用 `AGENTS.md` 登记的那条**逐字**命令再跑一次，确认退出码 0 且仓根无 `testResults.xml`（该差分不影响 tested_sha 绑定，但台账要一致）。

## Debt Verdict

**`Unpaid`**。

* `[DEBT]「~/.dsh 的运行副本由人工同步产生、无 *.bak-*，且每次同步无落账规范」`（Payback trigger = 首次用 `install.ps1` 覆盖 `~/.dsh` 之前）：**已被本任务触碰**（H3 正是解锁该部署的改动），人类 2026-09-15 裁决「本任务内一并偿还」。偿还面 ①（README 落账规范）已落（`git grep 'SUMMARY' -- README.md` 命中）；但**首次真实自动部署尚未发生**——`last_test_run.txt` §H 末条实测 `~/.dsh` 下 `*.bak-*` = 0，AC10 第二笔自述「未完成」、HANDOFF 也写明「执行前不得预先宣告已偿还」。按 Debt Verdict 枚举，这正是 **Unpaid**（不进 Blocking Issues、不触发再审，但 `/final-review` 第 11 条据此**不得判「可以提交」**，由人类在合并前决定偿还或批准延期）。
* `INSTALLER_GUARD.md` 的 emergency guard 债（trigger = H3 本身）→ **已在本改动内偿还**（`Repaid: 2026-09-15` + 7 行证据表与 5 条继承要求原样保留，我按 AC10① 的谓词复核：`Repaid` = 1、`^\|\s*[1-7]\s*\|` = 7、`^\d+\.\s` = 5）→ 不构成 Unpaid。
* 「本仓无常驻守护有效性装置」这条**已如实登记**为 `[DEBT]`（含 Payback trigger）。HANDOFF `guard_effectiveness: N/A` 与 PLAN「本任务不声称『回归用例有效（红→绿）』」一致——**没有**把未证明的能力写成已启用，故这条不升为 VN、也不阻止收敛（但 B1/B2 与本条无关，收敛仍受 B1/B2 阻止）。
* 其余存量债（`tools/ac4-*`、`dsh/**` 判据漂移、`@deepseek-ai/dsh` 版本绑定、AC6 未跟踪文件假设）trigger 与本任务触碰面不匹配 → **Noted**。

## Recommended Next Step

> 只给建议，不自行执行。

1. **人类裁决两项验收文本**（只有人类能改 TASK_BRIEF，属「最后一轮独立审查门 ③(c)」）：① AC9① 的域/pattern（B1 的两条出路任选其一）；② AC6 末尾「汇总给出未被部署的机器态清单」与 AC1「临时 HOME 递归」两处措辞是否收窄（S2 / VN1）。同时确认 S6 中 `AUTHORITY_CONTRACT.md` 历史段是否明确排除出 AC9② 判定域。
2. **Author 在双审窗口关闭后**按「review-fix 最小生产范围」修 B2（三行内的根归一化）+ 按其结果复跑冻结套件、把真实输出**追加**进 `last_test_run.txt`（`tested_sha` 回炉），并更正 §E 的预期行与「结论」节的 AC9① 表述。
3. B2 动了 `install.ps1`（review-sensitive 生产代码）→ 该 delta **必须再审**（9A/9B round 2，人类可减档只跑 9A）；round 1 的 streak 至多 1，未触发硬停。
4. 逐条处置本轮的 7 条 Verification Needed 与 S1–S6（`/final-review` 的 Manual Check Before Commit 需逐行列出）；**在 AC10 第二笔（人类按 runbook 对真实 `~/.dsh` 执行首次自动部署并由 Author 只读核验落账）完成之前，不得标「已收敛 / Ready to Commit」**——本轮 verdict 亦为 `不通过`，不具备任何收敛含义。
