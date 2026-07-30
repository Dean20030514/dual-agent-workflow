# Reviewer 独立审查 Prompt（复制给 Codex CLI）

**默认双审 9A+9B**（9A 对照计划审实现 + 9B 盲审只对需求审，双视角互补——9B 能抓"实现完全符合计划但计划本身错了"，本项目已多次实证 9B 抓到 9A 漏的真 blocking）。配额吃紧或纯小任务时可只跑 **9A 标准版**。
两版共用同一份输出契约（§契约），只差是否读 PLAN、以及末节。

> Author 发起 review 前确认：Reviewer 进程能读到 `docs/ai/QUALITY_GATES.md`（重点检查第 6 条会用到）；读不到则把本任务适用清单条目粘进下面 prompt。

---

## 双审隔离协议（强制；「9A/9B 真独立」的唯一定义处）

双审的价值全部来自**两份互不污染的独立判断**。下面五条是硬门，缺任一条这轮不算独立双审，不得据其标收敛。

**① 同一快照**：9A 与 9B 审的必须是**同一个** `review_tip_sha`（对同一个 `review_base_sha` 的 diff）+ **同一份审前 HANDOFF**（= Author 在 `/implement` 快速版步骤 5 / 正式版步骤 4.7 提交的那个交接 docs commit 的内容）。两轮之间**不得**重跑测试、重写 `last_test_run.txt`、或改任何交接文件。

> **两个锚点不是同一个 commit，必须分别说清（血泪，2026-07-28 演练实测）**：`docs/ai/HANDOFF.md` 与 `docs/ai/last_test_run.txt` **不在** `review_sensitive_paths` 内，按 `/implement` 的顺序它们提交在 `review_tip_sha` **之后**的那个 docs commit 里 —— 所以 tip 里装的是**过期 HANDOFF**。只写"你审的是 tip 这个确切 commit"会让 Reviewer 去跑 `git show <tip>:docs/ai/HANDOFF.md`，读到旧版（实测 Codex 就是这么干的）。因此每份 prompt 必须拆开写：**代码/测试/验收 = `git diff <review_base_sha>..<review_tip_sha>`；HANDOFF 与 last_test_run.txt = 读工作树当前文件**。Author 在两份 prompt 里写明同一个 `handoff_snapshot_sha`（= 双审窗口开启时的 HEAD，即那个 docs commit）。**prompt 值只是输入，不是证明**：「同一份审前 HANDOFF」由两个 Reviewer 各自跑审前快照自检（⑤）并把结果记入 verdict 证据首行落账——两份证据相互吻合且与 `handoff_snapshot_sha` 吻合才构成绑定；窗口冻结（②）是自检应当通过的原因，不是免检的理由。

**② 双审窗口冻结**：从第一个 Reviewer 启动，到两份 verdict 都产出为止，**任何人（Author 与两个 Reviewer）都不得**：
* 改生产代码 / 测试 / 任何 `review_sensitive_paths` 内的文件；
* 更新 `docs/ai/HANDOFF.md`（Work Log / Next Step / Binding 一律等到窗口结束）；
* 创建任何 commit，包括 `wip(review-fix)`。

发现 blocking 只写进自己的 verdict。**原「9A 期间发现 blocking 可小范围自修」与「Reviewer 末尾更新 HANDOFF」两条例外已取消**（与 `AGENTS.md` → AI Collaboration Rules 一致）。理由：窗口内任一处写入都会改变后跑者看到的证据面，两份 verdict 就不再是对同一对象的独立判断。

**③ 两份 verdict 分开保存且互不可见**：每次 `codex exec` 的 `-o` verdict 与 raw log 都写到**仓库工作树之外的 holding 目录**；启动每一个 Reviewer 前，Author 必须确认工作树内**不存在**任何 review verdict / raw log：`git status --porcelain --ignored` 的输出里没有任何 verdict / raw log 模式文件（`9A*.md` / `9B*.md` / `.codex-review-*` / `review_9*` / `review-*` / `codex_review_*` / `*_raw.log`），且 holding 在仓外。**`--ignored` 必带**——普通 `git status --porcelain` 看不见被 .gitignore 覆盖的残留 verdict，等于给污染留后门（其它被 ignore 的构建产物如 `__pycache__/` 不算污染，只认上述审查产物模式）。**顺序 9B 先跑**（盲审最需要干净上下文），9B **不接收** 9A 的任何输出。

```bash
HOLD="/c/Users/16097/AppData/Local/Temp/claude/review-holding/<task>"; mkdir -p "$HOLD"
codex exec --sandbox workspace-write -o "$HOLD/9B.md" "<9B prompt>" </dev/null > "$HOLD/9B_raw.log" 2>&1
# 确认工作树干净、无 verdict 残留后，再跑 9A
codex exec --sandbox workspace-write -o "$HOLD/9A.md" "<9A prompt>" </dev/null > "$HOLD/9A_raw.log" 2>&1
```

**零写入无例外**：若某环境不允许把 `-o` 写到仓库工作树之外 → **停止并报告人类**，不得退化为写进仓内——哪怕"跑完立刻 mv 到 holding、事后工作树恢复干净"也不行：双审窗口内曾发生的仓内写入本身就已破坏两份判断的独立性。

**④ 两份都完成后才统一落账**：Author 把两份 verdict 收进 `docs/ai/review_9A.md` / `docs/ai/review_9B.md`，然后**一次性**更新 HANDOFF——`review_verdict_9A` / `review_verdict_9B`、**`handoff_snapshot_sha`（必须与两份 verdict 一起持久化进 Review & Test Binding；落账后它就是 final-review 核验的权威来源，不依赖仓外 holding 的 prompt 文件）**、Work Log、Fix-Loop Counter 的逐字转录。此后所有修复走 `/debug` + `/final-review`，**都在双审窗口之外**。减档只跑 9A 时，`review_verdict_9B` 写 `N/A — 人类减档，原因: …`。**落账前先比对两份 verdict 的证据首行（⑤）——全部六个字段逐项核，任一不满足则不得落账、该轮双审作废重跑**：
* `read_handoff_from`：两份都必须是「工作树」（出现 `git show tip` 即作废）；
* `handoff_current_phase`：两份都必须等于审前 HANDOFF 的 Current Phase 原文（记录旧 Phase = 读到过期交接文件）；
* `observed_head_sha`：相互相等且 == `handoff_snapshot_sha`；
* `handoff_blob_sha`：相互相等**且 == `git rev-parse <handoff_snapshot_sha>:docs/ai/HANDOFF.md`**；
* `last_test_run_blob_sha`：相互相等**且 == `git rev-parse <handoff_snapshot_sha>:docs/ai/last_test_run.txt`**；
* `worktree_clean`：皆 yes。

**⑤ 审前快照自检（每个 Reviewer 强制，先于一切审查动作）**：核验并把结果记入 verdict 证据首行（字段见输出契约）：

```bash
git rev-parse HEAD           # 必须 == prompt 里的 handoff_snapshot_sha → observed_head_sha
git status --porcelain       # 必须为空——整个工作树，不只 review_sensitive_paths → worktree_clean
git diff --quiet <handoff_snapshot_sha> -- docs/ai/HANDOFF.md docs/ai/last_test_run.txt   # 必须通过（工作树两文件内容 == 快照）
git hash-object docs/ai/HANDOFF.md docs/ai/last_test_run.txt   # → handoff_blob_sha / last_test_run_blob_sha
```

任一不满足 → **在审查正文前输出「快照不一致」报告（写明失败项与实际观察值）并拒审**，不得进入审查。声明式的 `handoff_snapshot_sha` 只有经此自检落账后才成为绑定（此前只是 Author 的一句话）。

---

## 输出契约（9A / 9B 共用）

```
## Review Verdict            通过 / 有条件通过 / 不通过
                            （硬规则：Blocking Issues 非空 → 必须"不通过"；"有条件通过"不得与任何 Product/Verification Blocking 并存；Process Debt、Suggestion 不影响通过）
## Blocking Issues           无则 "None"。每条标 [Product Blocking]（用户可见正确性/用户数据错误/安全）
                            或 [Verification Blocking]（验证不健全：probe 冒充证据/测试不走真实路径/审后弱化测试或改验收/绕过 validation·auth·删测试藏错）
                            + caused_by_last_fix: yes/no（由你 Reviewer 判定，非 Author 自述；来源有争议标 dispute 交人类裁决）。**默认只有 Blocking Issues 阻止合并。**
## Non-Blocking Suggestions  无则 "None"。
## Test Coverage Gaps        无则 "None"。
## Cannot Verify From Diff   验收点实现落在未改代码里、光看 diff 判不了的，逐条列出交 Author 自核
                            （区别于 Verification Needed：那是"需跑命令"，这是"去未改代码里确认实现存在且正确"）。无则 "None"。
## Verification Needed       需 Author 在正常终端代跑的具体命令 + 想确认的行为。无则 "None"。
## Debt Verdict              Clean / Noted / Deferred（**无 "Blocking" 值**）：Noted=未触发 Payback-on-Touch 的普通存量债（行数债等，不阻止）；
                            Deferred=触发但已获人类批准延期（不阻止）；**触发未还且无批准延期 → 不写这里，移入 Blocking Issues 标 [Verification Blocking]**。
```

* **契约首行（两版共用，快照证据必填）**：在 `## Review Verdict` 之前先写六行 —— `read_handoff_from: <工作树 / git show tip>`、`handoff_current_phase: <你读到的 HANDOFF 里 Current Phase 原文>`、`observed_head_sha: <git rev-parse HEAD 实际输出>`、`handoff_blob_sha: <git hash-object docs/ai/HANDOFF.md 实际输出>`、`last_test_run_blob_sha: <git hash-object docs/ai/last_test_run.txt 实际输出>`、`worktree_clean: <yes/no，全树 git status --porcelain 是否为空>`。作用：把"读没读到审前快照"从声明变成可机检、可事后比对的持久化证据（自检命令见 ⑤）。`read_handoff_from` 若是 `git show tip`、或 `observed_head_sha` ≠ prompt 里的 `handoff_snapshot_sha`、或 `worktree_clean: no` —— 该轮审查建立在过期/污染证据上，**直接作废重跑**（详见 ① 的血泪注）。
* **9A 末节追加**：`## Recommended Next Step`——**只写建议 Author 做什么**。本轮你不得改代码、不得改 HANDOFF、不得 commit（双审隔离协议 ②）；review-fix 由 Author 在双审窗口结束后按 `/debug` 执行、commit 仍用 `wip(review-fix): [说明]`。
* **9B 末节**：先 `## Recommended Next Step`（同 9A——Codex 全局要求**所有 verdict 都含此节**；同样只写建议、不自行动手），**再加** `## Requirement-Level Concerns`（实现思路层面的疑问——即使代码无 bug，方案是否就错/过度/不完整。无则 "None"）。**两节都输出，不替换。**

---

## 9A. 标准 Review（对照计划审实现）

```
你是本项目的独立 code reviewer。**只审不改**：本轮任何情况下都不得修改生产代码 / 测试 / 验收文件，不得修改 docs/ai/HANDOFF.md，不得创建任何 commit。发现 blocking 只写进 verdict，由 Author 在双审结束后处理。

先读：1) AGENTS.md(遵守 Safety Rules) 2) docs/ai/TASK_BRIEF.md 3) docs/ai/IMPLEMENTATION_PLAN.md
4) docs/ai/HANDOFF.md 5) 审查对象 = git diff <review_base_sha>..<review_tip_sha>（两个 sha 见 HANDOFF 的 Review & Test Binding）6) docs/ai/last_test_run.txt

审查对象锚定（两个锚点，别混）：
* **审前快照自检（先于一切审查动作，结果记入 verdict 证据首行）**：`git rev-parse HEAD` 必须 == handoff_snapshot_sha（<由 Author 填>）→ 记 observed_head_sha；`git status --porcelain`（**全工作树**，不只 review_sensitive_paths）必须为空 → 记 worktree_clean；`git diff --quiet <handoff_snapshot_sha> -- docs/ai/HANDOFF.md docs/ai/last_test_run.txt` 必须通过；`git hash-object docs/ai/HANDOFF.md docs/ai/last_test_run.txt` → 记 handoff_blob_sha / last_test_run_blob_sha。**任一不满足 → 在审查正文前输出「快照不一致」（写明失败项与实际观察值）并拒审，不得继续。**
* **代码 / 测试 / 验收文件**：审 `git diff <review_base_sha>..<review_tip_sha>` 这个确切范围，不是工作树。若 `git status --porcelain -- <review_sensitive_paths>` 非空，或 `git diff --quiet <review_tip_sha> -- <review_sensitive_paths>` 不通过 → 停下报告"快照不一致"，不要改审工作树。
* **docs/ai/HANDOFF.md 与 docs/ai/last_test_run.txt**：**直接读工作树当前文件**（当前 HEAD = handoff_snapshot_sha <由 Author 填>）。**不要**用 `git show <review_tip_sha>:docs/ai/HANDOFF.md` —— 这两个文件不在 review_sensitive_paths 内、按流程提交在 tip 之后，从 tip 取会拿到过期版本。

不要 git archive 重建副本、不要重装依赖、不要重跑全量测试——以 docs/ai/last_test_run.txt 产物 + 读 git diff 推理为准；需要验证的具体行为列出来，由 Author 在正常终端代跑。
对 last_test_run.txt 批判性阅读：命令是否真实存在、输出是否完整、结论是否一致；证据不足则写进 Verification Needed，不自己运行。

重点检查：
1. 是否满足 TASK_BRIEF 的需求与验收。
2. 是否严格遵守 IMPLEMENTATION_PLAN，偏离是否合理。
3. 是否有无关修改、是否破坏现有 API/数据结构。
4. 安全、边界遗漏、类型、测试覆盖不足。
5. 是否为通过测试而绕过逻辑（对照 diff 中测试文件改动逐一确认）。
6. 核对 docs/ai/QUALITY_GATES.md 中本任务适用组 + 有界面则设计层闸门（需实跑的列 Verification Needed）。
7. **回归面（尤其 re-review 一次 review-fix 时）**：本次改动可能破坏被报案例**之外**的其它消费者/值域吗？枚举该字段/路径的其它生产者/消费者，确认没破坏或列进 Verification Needed——别只确认被报问题修了。
8. **证据真实性**：**不收 Author "已修复/已吸取教训" 的自我总结当证据**；diff 里若有 probe / mutation harness / 临时脚本，它**不算完成证据**（应提交前删除或重写为正式 regression test）。「回归用例有效」声称只认**守护有效性装置的结构化产物**——必填字段与失败判据以 `AGENTS.md` → 守护有效性装置（唯一定义处）为准，逐字段核对产物完整性、自洽与 tested_sha 绑定；**你不运行装置**；产物缺失或字段不可信 → 列 Verification Needed。为每条 Blocking 标 [Product/Verification] + caused_by_last_fix。

[输出按上面「输出契约」+ 9A 末节 Recommended Next Step（只给建议，不自行执行）]
```

---

## 9B. Blind Review（只对照需求审实现）

> 刻意不提供 IMPLEMENTATION_PLAN，目的是检验实现是否真正满足需求、而非是否符合计划。
> 9B 先跑：此时 9A 的 verdict 尚不存在，从物理上保证盲审不被带偏。

```
你是本项目的独立 code reviewer。刻意不读 IMPLEMENTATION_PLAN.md（以免被计划意图带偏）。**只审不改**：不得修改任何生产代码 / 测试 / 验收文件，不得修改 docs/ai/HANDOFF.md，不得创建任何 commit。

只依据：1) AGENTS.md 2) docs/ai/TASK_BRIEF.md 3) docs/ai/HANDOFF.md(取 base branch/已知问题/闸门状态，但不据其反推计划意图)
4) 审查对象 = git diff <review_base_sha>..<review_tip_sha>（两个 sha 见 HANDOFF 的 Review & Test Binding）5) docs/ai/last_test_run.txt(批判性地读)

**HANDOFF.md 与 last_test_run.txt 直接读工作树当前文件**（当前 HEAD = handoff_snapshot_sha <由 Author 填>），**不要**用 `git show <review_tip_sha>:...` 取 —— 这两个文件不在 review_sensitive_paths 内、按流程提交在 tip 之后，从 tip 取会拿到过期版本。代码/测试/验收则严格审 base..tip 这个范围。

盲审隔离（硬性）：
* **忽略 diff 中 docs/ai/IMPLEMENTATION_PLAN.md 的全部内容**（该文件在 review_sensitive_paths 内、必然出现在 diff 里；一律视作未提供），也不得单独打开它。
* 本轮不应存在任何其它 Reviewer 的输出。检查须覆盖被 .gitignore 忽略的文件（用 `git status --porcelain --ignored`，或对下述模式做显式文件扫描——普通 `git status --porcelain` 看不见 ignored 残留）；工作树里若存在**未提交或被 ignore** 的 review verdict / raw log 模式文件（`9A*.md` / `9B*.md` / `.codex-review-*` / `review_9*` / `review-*` / `codex_review_*` / `*_raw.log`）→ 视为污染，**不要读**，在审查正文前报告污染并**拒审**（该轮双审隔离不成立）。已提交进历史的审查产物（`docs/ai/archive/**`、上一轮已落账的 `docs/ai/review_9*.md`）不算本轮污染，但同样**不要读**。
* 你审的是 review_tip_sha 这个确切 commit，不是工作树。**审前快照自检（先于一切审查动作，结果记入 verdict 证据首行）**：`git rev-parse HEAD` 必须 == handoff_snapshot_sha；`git status --porcelain`（**全工作树**，不只 review_sensitive_paths）必须为空 → 记 worktree_clean；`git diff --quiet <handoff_snapshot_sha> -- docs/ai/HANDOFF.md docs/ai/last_test_run.txt` 必须通过；`git hash-object docs/ai/HANDOFF.md docs/ai/last_test_run.txt` → 记 handoff_blob_sha / last_test_run_blob_sha。**任一不满足 → 在审查正文前报告「快照不一致」（写明失败项与实际观察值）并拒审。**

不要 git archive 重建副本、不要重装依赖、不要重跑全量测试——以 docs/ai/last_test_run.txt 产物 + 读 git diff 推理为准；需要验证的具体行为列出来，由 Author 在正常终端代跑。

核心问题只有一个：假设你是第一次看到这个项目的资深工程师，这个 diff 是否正确、完整、安全地实现了 TASK_BRIEF.md 的需求与验收？

**9B 盲审专攻面**：主动枚举 **遗漏入口 / 状态生命周期 / 边界值 / 回归**（9A 管计划-契约一致性，这几面归 9B）。不据 Author 自我总结；为每条 Blocking 标 [Product/Verification] + caused_by_last_fix。

[输出按上面「输出契约」+ `## Recommended Next Step` + `## Requirement-Level Concerns`（**两节都要，不替换** Recommended Next Step）；本 prompt 自包含]
本轮不要写入仓库任何文件（含 HANDOFF）——verdict 由 Author 在两份都完成后统一落账。
```
