# Reviewer 独立审查 Prompt（复制给 Codex CLI）

**实现审默认双审 9A+9B**（9A 对照计划审实现 + 9B 盲审只对需求审，双视角互补——9B 能抓"实现完全符合计划但计划本身错了"，本项目已多次实证 9B 抓到 9A 漏的真 blocking）。配额吃紧或纯小任务时可只跑 **9A 标准版**。
两版共用同一份输出契约（§契约），只差是否读 PLAN、以及末节。
**另有 9P 计划审（2026-08-27 新增）**：Critical 正式路径在计划批准前**默认必跑、默认单跑一轮**的审查（再审仅凭人类明示要求），审规划文件而非实现——定义、prompt 与专用契约见文末 → 9P 节（**不**共用 9A/9B 的输出契约与审前快照自检）。

> Author 发起 review 前确认：Reviewer 进程能读到 `docs/ai/QUALITY_GATES.md`（重点检查第 6 条会用到）；读不到则把本任务适用清单条目粘进下面 prompt。

> **适用范围（2026-08-15 补）**：本文件全部内容——9P 计划审、9A/9B 双审、双审隔离协议、审前快照自检、SHA 绑定——**只属 Critical 模式**。
> **Routine 下由人类临时要求的一次性只读审查不走本文件**：它没有交接文件、没有 `last_test_run.txt`，照本文件执行审前快照自检必然失败而拒审。其证据依据、拒审边界与"不得为审查临时造交接文件"的红线，见 `AGENTS.md` → **Reviewer-Lightweight Protocol 第二层**（唯一定义处，本文件不复述）。
> 误把本文件套到 Routine 的后果是实测过的：Reviewer 会去索取不存在且不得创建的产物，只能靠人类在每份 prompt 里手写覆盖来绕开——那是规则缺失的症状，不是正常用法。

---

## 双审隔离协议（强制；「9A/9B 真独立」的唯一定义处）

双审的价值全部来自**两份互不污染的独立判断**。下面五条是硬门，缺任一条这轮不算独立双审，不得据其标收敛。

**① 同一快照**：9A 与 9B 审的必须是**同一个** `review_tip_sha`（对同一个 `review_base_sha` 的 diff）+ **同一份审前 HANDOFF**（= Author 在 `/implement` 快速版步骤 5 / 正式版步骤 4.7 提交的那个交接 docs commit 的内容）。两轮之间**不得**重跑测试、重写 `last_test_run.txt`、或改任何交接文件。

> **两个锚点不是同一个 commit，必须分别说清（血泪，2026-07-28 演练实测）**：`docs/ai/HANDOFF.md` 与 `docs/ai/last_test_run.txt` **不在** `review_sensitive_paths` 内，按 `/implement` 的顺序它们提交在 `review_tip_sha` **之后**的那个 docs commit 里 —— 所以 tip 里装的是**过期 HANDOFF**。只写"你审的是 tip 这个确切 commit"会让 Reviewer 去跑 `git show <tip>:docs/ai/HANDOFF.md`，读到旧版（实测 Codex 就是这么干的）。因此每份 prompt 必须拆开写：**代码/测试/验收 = 带排除项的正文 diff `git diff <review_base_sha>..<review_tip_sha> -- . ":(exclude)docs/ai/review_9*.md" ":(exclude)docs/ai/archive/**"`（9B 另加 `":(exclude)docs/ai/IMPLEMENTATION_PLAN.md"`；排除只作用于正文输入——防止历史与本任务的 verdict 正文经 diff 输出进入 Reviewer 输入；快照自检的覆盖核验用未过滤 `--name-only`）；HANDOFF 与 last_test_run.txt = 读工作树当前文件**。Author 在两份 prompt 里写明同一个 `handoff_snapshot_sha`（= 双审窗口开启时的 HEAD，即那个 docs commit），并把 `review_base_sha` / `review_tip_sha` 逐字写进 prompt（不写『见 HANDOFF』——2026-07-28 那次正是 Reviewer 去 tip 里找 HANDOFF 才读到旧版）。**prompt 值只是输入，不是证明**：「同一份审前 HANDOFF」由两个 Reviewer 各自跑审前快照自检（⑤）并把结果记入 verdict 证据首行落账——两份证据相互吻合且与 `handoff_snapshot_sha` 吻合才构成绑定；窗口冻结（②）是自检应当通过的原因，不是免检的理由。

**② 双审窗口冻结**：从第一个 Reviewer 启动，到两份 verdict 都产出为止，**任何人（Author 与两个 Reviewer）都不得**：
* 改生产代码 / 测试 / 任何 `review_sensitive_paths` 内的文件；
* 更新 `docs/ai/HANDOFF.md`（Work Log / Next Step / Binding 一律等到窗口结束）；
* 创建任何 commit，包括 `wip(review-fix)`。

发现 blocking 只写进自己的 verdict。**原「9A 期间发现 blocking 可小范围自修」与「Reviewer 末尾更新 HANDOFF」两条例外已取消**（与 `AGENTS.md` → AI Collaboration Rules 一致）。理由：窗口内任一处写入都会改变后跑者看到的证据面，两份 verdict 就不再是对同一对象的独立判断。

**③ 两份 verdict 分开保存且互不可见**：每次 `codex exec` 的 `-o` verdict 与 raw log 都写到**仓库工作树之外的 holding 目录**；启动每一个 Reviewer 前，Author 必须确认工作树内**不存在**任何 review verdict / raw log：`git status --porcelain --ignored` 的输出里没有任何 verdict / raw log 模式文件（`9A*.md` / `9B*.md` / `.codex-review-*` / `review_9*` / `review-*` / `codex_review_*` / `*_raw.log`），且 holding 在仓外。**`--ignored` 必带**——普通 `git status --porcelain` 看不见被 .gitignore 覆盖的残留 verdict，等于给污染留后门（其它被 ignore 的构建产物如 `__pycache__/` 不算污染，只认上述审查产物模式）。**顺序 9B 先跑**（盲审最需要干净上下文），9B **不接收** 9A 的任何输出。

```bash
HOLD="$HOME/.codex-review-holding/<task>"; mkdir -p "$HOLD"
codex exec --sandbox workspace-write --ephemeral --ignore-user-config --ignore-rules --disable memories -c 'windows.sandbox="elevated"' -m gpt-6-astra -c 'model_reasoning_effort="high"' -o "$HOLD/9B.md" "<9B prompt>" </dev/null > "$HOLD/9B_raw.log" 2>&1
# 确认工作树干净、无 verdict 残留后，再跑 9A
codex exec --sandbox workspace-write --ephemeral --ignore-user-config --ignore-rules --disable memories -c 'windows.sandbox="elevated"' -m gpt-6-astra -c 'model_reasoning_effort="high"' -o "$HOLD/9A.md" "<9A prompt>" </dev/null > "$HOLD/9A_raw.log" 2>&1
```

> **调用形态（2026-08-07 Commit B 收敛；唯一定义处）**：`--sandbox` 与 `-m` **必须显式**（双路径皆然，不依赖任何默认）；**模型 = `gpt-6-astra`**（2026-09-04 由 `gpt-5.6-sol` 换代：推理档集合不变，`high` / `medium` 取值沿用；**CLI 须 ≥ 0.153**——0.147 对该模型返回 400 `requires a newer version of Codex`；此前 8 月 30 日的 9P p50 514s 与采纳率基线均量自 5.6-sol，观察量自此重新起点）；`--ephemeral --ignore-user-config --ignore-rules` 隔离用户配置与规则注入，但 **`-c 'windows.sandbox="elevated"'` 必须随行**——本机 Windows 沙箱后端键在用户配置里，单用 `--ignore-user-config` 会令全部命令被 policy 拒绝（2026-08-07 冒烟首轮实测）；推理档同理**必须显式**（否则隔离掉用户配置后静默降为默认）；**`--disable memories` 必带**——`memories` 是默认开启的 stable feature（`codex features list`），本模板其余 flag 都不以关闭它为目的（2026-09-03 探针：模板 flag 下未见注入，但那是副作用不是保证）；2026-09-02 实测有一组未按本模板启动的审查（rollout 落盘、沙箱 read-only）带着 `MEMORY.md` 里「complete category/value-range coverage」的经验做审查，fresh context 前提失效——**取值按审别，本处为唯一定义处：9A / 9B = `high`，9P = `medium`**（9P 于 2026-08-30 降档，理由与可执行命令见文末 9P 节；上面两条模板是 9A/9B 的实例，**勿照抄给 9P**）。**read-only 未晋升**：行为冒烟证实其明文 HTTP 出网放行（实拉 example.com 200/559B）、「网络阻断」验收不成立，六项未全过——继续显式 workspace-write；复测晋升需人类明确决定。**已知风险（沙箱≠网络边界）**：本机 Codex 沙箱在 read-only 与 workspace-write 下明文 HTTP 出网均放行，Reviewer 网络纪律由 lean protocol（不重装依赖/不重建副本）与人审 verdict 兜底，不依赖沙箱。**单审同源**：人类减档只跑 9A 时同用本模板（一对 `-o` verdict + raw log），输出同样必须落仓外 holding——Reviewer 输出零例外不入工作树（原 CLAUDE.md 的仓内单审路径示例已废止）。**holding 位置（2026-08-12 改，来历）**：原示例落在 `%LOCALAPPDATA%\Temp\claude\`，该子树被 harness 会话清理不定时整树清扫——实测某次六轮审查跑到第三轮时 holding 已被扫掉、输出重定向无处可写致 `codex exec` 启动即败；清扫若发生在某轮跑完后、读取前，就是白烧一轮高档推理配额加整轮重跑。故改用 home 下持久目录（`$HOME` 展开——**不要写成双引号内的 `~`，那不展开、会造出字面波浪号目录**）。代价是失去 Temp 的自动清理：holding 生命周期本就由「人类确认后删 scratch」显式管理（见 `AGENTS.md` → Reviewer-Lightweight Protocol），收口时照删即可。

**零写入无例外**：若某环境不允许把 `-o` 写到仓库工作树之外 → **停止并报告人类**，不得退化为写进仓内——哪怕"跑完立刻 mv 到 holding、事后工作树恢复干净"也不行：双审窗口内曾发生的仓内写入本身就已破坏两份判断的独立性。

**④ 两份都完成后才统一落账**：Author 把两份 verdict 收进 `docs/ai/review_9A.md` / `docs/ai/review_9B.md`，然后**一次性**更新 HANDOFF——`review_verdict_9A` / `review_verdict_9B`、**`handoff_snapshot_sha`（必须与两份 verdict 一起持久化进 Review & Test Binding；落账后它就是 final-review 核验的权威来源，不依赖仓外 holding 的 prompt 文件）**、Work Log、Fix-Loop Counter 的逐字转录。此后所有修复走 `/debug` + `/final-review`，**都在双审窗口之外**。减档只跑 9A 时，`review_verdict_9B` 写 `N/A — 人类减档，原因: …`。**落账前先比对两份 verdict 的证据首行（⑤）——三个字段逐项核，任一不满足则不得落账、该轮双审作废重跑**：
* `observed_head_sha`：相互相等且 == `handoff_snapshot_sha`；
* `worktree_clean`：皆 yes；
* `read_handoff_from`：两份都必须是「工作树」（出现 `git show tip` 即作废）。
（HEAD 等于快照 commit 且工作树干净，即保证工作树中的 HANDOFF / last_test_run.txt 与快照逐字节一致——blob hash、Current Phase 原文与清单逐字抄录已于 2026-09-03 删除；清单缩窄改由 `/final-review` 用 `git show <handoff_snapshot_sha>:docs/ai/HANDOFF.md` 比对。）

**⑤ 审前快照自检（每个 Reviewer 强制，先于一切审查动作）**：核验并把结果记入 verdict 证据首行（字段见输出契约）：

```bash
git rev-parse HEAD           # 必须 == prompt 里的 handoff_snapshot_sha → observed_head_sha
git status --porcelain       # 必须为空——整个工作树，不只 review_sensitive_paths → worktree_clean
# read_handoff_from：HANDOFF 与 last_test_run.txt 直接读工作树当前文件 → 记「工作树」（用了 git show <tip>:… 即记「git show tip」，该轮作废）
git diff --name-only <review_base_sha>..<review_tip_sha>   # 覆盖核验：diff 里每个必含类别的文件（类别以 `AGENTS.md` → review-sensitive paths + SHA 绑定为准：生产源码 / tests / migrations·schema / 构建配置 + **依赖声明 + lockfile** / TASK_BRIEF）都被 HANDOFF 的清单覆盖；IMPLEMENTATION_PLAN / QUALITY_GATES 出现在 --name-only 里不算缺口（已排除于必含清单）
```

HEAD ≠ `handoff_snapshot_sha`、或工作树不净 → **在审查正文前输出「快照不一致」报告（写明失败项与实际观察值）并拒审**，不得进入审查。清单未覆盖必含类别的文件 → 在三行证据首行之后写一条「覆盖缺口：<路径>」并**照常审查**（缺口由 Author 落账时补入清单，`/final-review` 复核）。声明式的 `handoff_snapshot_sha` 只有经此自检落账后才成为绑定（此前只是 Author 的一句话）。

---

## 输出契约（9A / 9B 共用）

```
## Review Verdict            通过 / 有条件通过 / 不通过
                            （硬规则：Blocking Issues 非空 → 不通过；Blocking None 且 Verification Needed 非空 → 有条件通过；两者皆空 → 通过。Process Debt、Suggestion 不影响通过。**不得以证据充分性为由判不通过。**）
## Blocking Issues           无则 "None"。每条即 [Product Blocking]：须写出具体后果（哪个用户操作 / 哪条数据 / 哪个安全边界出错），「不能排除」不是后果；验收点未满足须有具体反例，缺证据 ≠ 未满足；删/弱化测试的说明经核实不成立须写出该测试仍能检出的缺陷（判据与举例唯一定义处 = `AGENTS.md` → Reviewer verdict 分类语义）
                            + caused_by_last_fix: yes/no（由你 Reviewer 判定，非 Author 自述；来源有争议标 dispute 交人类裁决）。**只有 Blocking Issues 阻止合并。**
                            **+ Proposed Fix（每条 Blocking 必填，见下方「修法必附」）**
                            证据缺口写 Verification Needed；账本/措辞不一致写 Non-Blocking Suggestions。
## Non-Blocking Suggestions  无则 "None"。**每条同样必附 Proposed Fix。**
## Test Coverage Gaps        无则 "None"。
## Cannot Verify From Diff   验收点实现落在未改代码里、光看 diff 判不了的，逐条列出交 Author 自核
                            （区别于 Verification Needed：那是"需跑命令"，这是"去未改代码里确认实现存在且正确"）。无则 "None"。
## Verification Needed       每条 = 能证伪某一具体声称的最小命令（单个测试 / 单个样本 / 单条 grep）+ 想确认的行为；不得列全量套件、整批装置重跑、或同 tip 已有输出的命令；
                            证据缺口一律写这里（哪条声称 / 由哪份产物支撑 / 缺什么）。无则 "None"。
## Debt Verdict              Clean / Noted / Deferred / Unpaid（取值语义唯一定义处 = `AGENTS.md` → Reviewer verdict 分类语义；Unpaid = 触发 Payback-on-Touch 未还且无批准延期——不进 Blocking、由人类合并前裁决）
```

* **修法必附（2026-08-15 新增，唯一定义处）**：**每条 Blocking 与 Suggestion 都必须附 `Proposed Fix`**——写清**具体怎么改**（改哪个文件/哪一节、加什么或删什么、判据如何变），而不只是"应当明确/应当收紧"这类方向性表述。有多种合理修法时给出**首选 + 备选并说明取舍**；若你认为无法给出具体修法（如需要人类裁决取舍），写 `Proposed Fix: 需人类裁决 — <待定的选项与各自后果>`。
  * **`Proposed Fix` 是可审议的建议，不转移实现决策权**——判断修法是否成立、是否有更好的改法，始终是 Author 的责任；Reviewer 给方案时须**列明所依赖的假设**，上下文不足以给出可执行方案时写 `需人类裁决` 而不是硬凑一个。
  * **Author 侧对称义务（逐条表态，三选一）**：
    * `采纳` / `修改后采纳`（写明改了什么、为何比原方案好）→ **必须有对应改动**，不得只说不改；
    * `不采纳` → **必须给技术理由**，**不要求产生任何改动**（验证后认定修法错误而不改，是这条的正当结果，不是违规）；
    * Suggestion 可以不实施、**不影响通过**（`AGENTS.md` → Reviewer verdict 分类语义），但仍须**一句话**表态，不得沉默跳过。
    * 表态记进 HANDOFF Work Log 供下一轮核对；**一句话足够，不要为每条写长叙述**（避免把刚削减的叙述性仪式又加回来）。（**9P 例外**：其表态只写 `docs/ai/review_9P.md` 的 Author Responses 节、不进 Work Log——防止经 HANDOFF 污染后续 9A/9B，见 9P 节。）
  * **为什么强制**：只报"哪里错了"而不给修法，Author 只能反推 Reviewer 的意图，双方极易各说各话、多轮不收敛；把修法摆到台面上，分歧就从"猜对方想要什么"变成"对同一个具体方案表态"，一轮内即可裁决。

* **契约首行（两版共用，快照证据必填）**：在 `## Review Verdict` 之前先写**三行**：`observed_head_sha: <git rev-parse HEAD 实际输出>`、`worktree_clean: <yes/no，全树 git status --porcelain 是否为空>`、`read_handoff_from: <工作树 / git show tip>`；有覆盖缺口则在其后追加 `覆盖缺口: <路径>` 行。作用：把"读没读到审前快照"从声明变成可机检、可事后比对的持久化证据（自检命令见 ⑤）。`read_handoff_from` 若是 `git show tip`、或 `observed_head_sha` ≠ prompt 里的 `handoff_snapshot_sha`、或 `worktree_clean: no` —— 该轮审查建立在过期/污染证据上，**直接作废重跑**（详见 ① 的血泪注）。
* **9A 末节追加**：`## Recommended Next Step`——**只写建议 Author 做什么**。本轮你不得改代码、不得改 HANDOFF、不得 commit（双审隔离协议 ②）；review-fix 由 Author 在双审窗口结束后按 `/debug` 执行、commit 仍用 `wip(review-fix): [说明]`。
* **9B 末节**：先 `## Recommended Next Step`（同 9A——Codex 全局要求**所有 verdict 都含此节**；同样只写建议、不自行动手），**再加** `## Requirement-Level Concerns`（实现思路层面的疑问——即使代码无 bug，方案是否就错/过度/不完整。无则 "None"）。**两节都输出，不替换。**

---

## 9A. 标准 Review（对照计划审实现）

```
你是本项目的独立 code reviewer。**只审不改**：本轮任何情况下都不得修改生产代码 / 测试 / 验收文件，不得修改 docs/ai/HANDOFF.md，不得创建任何 commit。发现 blocking 只写进 verdict，由 Author 在双审结束后处理。

先读：1) AGENTS.md(遵守 Safety Rules) 2) docs/ai/TASK_BRIEF.md 3) docs/ai/IMPLEMENTATION_PLAN.md
4) docs/ai/HANDOFF.md 5) 审查对象 = 正文 diff：git diff <review_base_sha>..<review_tip_sha> -- . ":(exclude)docs/ai/review_9*.md" ":(exclude)docs/ai/archive/**"（review_base_sha=<Author 填>、review_tip_sha=<Author 填>，与工作树 HANDOFF 的 Review & Test Binding 一致；排除项防止历史与本任务的 verdict 正文进入你的输入——「不得打开」包括不得让其正文出现在 diff 输出里；未过滤的 git diff --name-only 仅用于快照自检的覆盖核验与确认文件存在）6) docs/ai/last_test_run.txt

审查对象锚定（两个锚点，别混）：
* **审前快照自检（先于一切审查动作，结果记入 verdict 证据首行）**：`git rev-parse HEAD` 必须 == handoff_snapshot_sha（<由 Author 填>）→ 记 observed_head_sha；`git status --porcelain`（**全工作树**，不只 review_sensitive_paths）必须为空 → 记 worktree_clean；HANDOFF 与 last_test_run.txt 从工作树读 → 记 read_handoff_from: 工作树。**HEAD 不符或工作树不净 → 在审查正文前输出「快照不一致」（写明失败项与实际观察值）并拒审，不得继续。** 另核 `git diff --name-only <base>..<tip>` 中每个必含类别的文件（类别以 `AGENTS.md` → review-sensitive paths + SHA 绑定为准：生产源码 / tests / migrations·schema / 构建配置 + **依赖声明 + lockfile** / TASK_BRIEF；IMPLEMENTATION_PLAN / QUALITY_GATES 出现不算缺口）都被 HANDOFF 的 `review_sensitive_paths` 覆盖——漏项在证据首行之后写「覆盖缺口：<路径>」并**照常审查**，不拒审。
* **代码 / 测试 / 验收文件**：审上述**带排除项的正文 diff** 这个确切范围，不是工作树。若 `git status --porcelain -- <review_sensitive_paths>` 非空，或 `git diff --quiet <review_tip_sha> -- <review_sensitive_paths>` 不通过 → 停下报告"快照不一致"，不要改审工作树。
* **docs/ai/HANDOFF.md 与 docs/ai/last_test_run.txt**：**直接读工作树当前文件**（当前 HEAD = handoff_snapshot_sha <由 Author 填>）。**不要**用 `git show <review_tip_sha>:docs/ai/HANDOFF.md` —— 这两个文件不在 review_sensitive_paths 内、按流程提交在 tip 之后，从 tip 取会拿到过期版本。

不要 git archive 重建副本、不要重装依赖、不要重跑全量测试——以 docs/ai/last_test_run.txt 产物 + 读 git diff 推理为准；需要验证的具体行为列出来，由 Author 在正常终端代跑。
对 last_test_run.txt 批判性阅读：命令是否真实存在、输出是否完整、结论是否一致；证据不足则写进 Verification Needed，不自己运行。
已提交进历史的审查产物（docs/ai/archive/**、已落账的 docs/ai/review_9*.md，含 review_9P.md）**不得自行打开**；re-review 时上一轮 9A/9B blocking 的上下文由 Author 在本 prompt 内提供，可以且应当使用；9P 的结论或内容任何时候不得提供、不得使用。HANDOFF 的 plan_review_9P 行仅是状态记录，不得据以推断计划质量或当作实现正确性证据。

重点检查：
1. 是否满足 TASK_BRIEF 的需求与验收。
2. 是否严格遵守 IMPLEMENTATION_PLAN，偏离是否合理。
3. 是否有无关修改、是否破坏现有 API/数据结构。
4. 安全、边界遗漏、类型、测试覆盖不足。
5. 是否为通过测试而绕过逻辑（对照 diff 中测试文件改动逐一确认）。
6. 核对 docs/ai/QUALITY_GATES.md 中本任务适用组 + 有界面则设计层闸门（需实跑的列 Verification Needed）。
7. **回归面（尤其 re-review 一次 review-fix 时）**：本次改动可能破坏被报案例**之外**的其它消费者/值域吗？枚举该字段/路径的其它生产者/消费者，确认没破坏或列进 Verification Needed——别只确认被报问题修了。
8. **证据真实性**：**不收 Author "已修复/已吸取教训" 的自我总结当证据**；diff 里若有 probe / mutation harness / 临时脚本，它**不算完成证据**（应提交前删除或重写为正式 regression test）。「回归用例有效」声称只认**守护有效性装置的结构化产物**——必填字段与失败判据以 `AGENTS.md` → 守护有效性装置（唯一定义处）为准，逐字段核对产物完整性、自洽与生成时 commit 的**内容绑定**（判法 = 该节字段 ⑦，不要求 sha 相等）；**你不运行装置**；产物缺失或字段不可信 → 列 Verification Needed（附一个可证伪的最小检查）。Blocking 只收 [Product Blocking] 并标 caused_by_last_fix（判据 = `AGENTS.md` → Reviewer verdict 分类语义：具体后果 / 具体反例 / 删测试理由不成立）；HANDOFF / TASK_BRIEF 中标日期的人类裁决按人类决定对待——不核实过程、不降为自述、不要求出现在人类 commit；异议只进 Assumption / Requirement-Level Concerns。

[输出按上面「输出契约」+ 9A 末节 Recommended Next Step（只给建议，不自行执行）]
```

---

## 9B. Blind Review（只对照需求审实现）

> 刻意不提供 IMPLEMENTATION_PLAN，目的是检验实现是否真正满足需求、而非是否符合计划。
> 9B 先跑：此时 9A 的 verdict 尚不存在，从物理上保证盲审不被带偏。

```
你是本项目的独立 code reviewer。刻意不读 IMPLEMENTATION_PLAN.md（以免被计划意图带偏）。**只审不改**：不得修改任何生产代码 / 测试 / 验收文件，不得修改 docs/ai/HANDOFF.md，不得创建任何 commit。

只依据：1) AGENTS.md 2) docs/ai/TASK_BRIEF.md 3) docs/ai/HANDOFF.md(取 base branch/已知问题/闸门状态，但不据其反推计划意图；其 plan_review_9P 行仅状态记录，不据以推断计划内容)
4) 审查对象 = 正文 diff：git diff <review_base_sha>..<review_tip_sha> -- . ":(exclude)docs/ai/review_9*.md" ":(exclude)docs/ai/archive/**" ":(exclude)docs/ai/IMPLEMENTATION_PLAN.md"（review_base_sha=<Author 填>、review_tip_sha=<Author 填>，与工作树 HANDOFF 的 Review & Test Binding 一致；排除项使历史/本任务 verdict 正文与计划正文都不进入你的输入；未过滤的 git diff --name-only 仅用于快照自检的覆盖核验与确认文件存在）5) docs/ai/last_test_run.txt(批判性地读)

**HANDOFF.md 与 last_test_run.txt 直接读工作树当前文件**（当前 HEAD = handoff_snapshot_sha <由 Author 填>），**不要**用 `git show <review_tip_sha>:...` 取 —— 这两个文件不在 review_sensitive_paths 内、按流程提交在 tip 之后，从 tip 取会拿到过期版本。代码/测试/验收则严格审 base..tip 这个范围。

盲审隔离（硬性）：
* **docs/ai/IMPLEMENTATION_PLAN.md 已从上述正文 diff 机械排除**（`:(exclude)` pathspec；该文件**不在** review_sensitive_paths 内，但会出现在未过滤 --name-only 里，一律视作未提供）；不得单独打开它，也不得换用未带排除项的 diff 命令——若你的 diff 输出里出现了它的内容，说明命令用错了，改用带排除项的正文 diff 重来。
* 本轮不应存在任何其它 Reviewer 的输出。检查须覆盖被 .gitignore 忽略的文件（用 `git status --porcelain --ignored`，或对下述模式做显式文件扫描——普通 `git status --porcelain` 看不见 ignored 残留）；工作树里若存在**未提交或被 ignore** 的 review verdict / raw log 模式文件（`9A*.md` / `9B*.md` / `.codex-review-*` / `review_9*` / `review-*` / `codex_review_*` / `*_raw.log`）→ 视为污染，**不要读**，在审查正文前报告污染并**拒审**（该轮双审隔离不成立）。**目录不可枚举**（如权限受限的缓存目录 `.pytest_cache/`、`.vite/`）只在 verdict 里报告，不构成污染、不拒审；污染 = 实际找到匹配文件。已提交进历史的审查产物（`docs/ai/archive/**`、上一轮已落账的 `docs/ai/review_9*.md`）不算本轮污染，但同样**不得自行打开**；re-review 时 Author 只会在 prompt 里提供上一轮 **9B** blocking 的上下文（不含任何计划内容与 9P 内容），可以使用；除此之外的历史 verdict 内容不得接收。
* 你审的是 review_tip_sha 这个确切 commit，不是工作树。**审前快照自检（先于一切审查动作，结果记入 verdict 证据首行）**：`git rev-parse HEAD` 必须 == handoff_snapshot_sha → 记 observed_head_sha；`git status --porcelain`（**全工作树**，不只 review_sensitive_paths）必须为空 → 记 worktree_clean；HANDOFF 与 last_test_run.txt 从工作树读 → 记 read_handoff_from: 工作树。**HEAD 不符或工作树不净 → 在审查正文前报告「快照不一致」（写明失败项与实际观察值）并拒审。** 另核 `git diff --name-only <base>..<tip>` 中每个必含类别的文件（类别以 `AGENTS.md` → review-sensitive paths + SHA 绑定为准：生产源码 / tests / migrations·schema / 构建配置 + **依赖声明 + lockfile** / TASK_BRIEF；IMPLEMENTATION_PLAN / QUALITY_GATES 出现不算缺口）都被 HANDOFF 的 `review_sensitive_paths` 覆盖——漏项在证据首行之后写「覆盖缺口：<路径>」并**照常审查**，不拒审。

不要 git archive 重建副本、不要重装依赖、不要重跑全量测试——以 docs/ai/last_test_run.txt 产物 + 读 git diff 推理为准；需要验证的具体行为列出来，由 Author 在正常终端代跑。

核心问题只有一个：假设你是第一次看到这个项目的资深工程师，这个 diff 是否正确、完整、安全地实现了 TASK_BRIEF.md 的需求与验收？

**9B 盲审专攻面**：主动枚举 **遗漏入口 / 状态生命周期 / 边界值 / 回归**（9A 管计划-契约一致性，这几面归 9B）。不据 Author 自我总结；Blocking 只收 [Product Blocking] 并标 caused_by_last_fix（判据 = `AGENTS.md` → Reviewer verdict 分类语义：具体后果 / 具体反例 / 删测试理由不成立）；证据缺口写 Verification Needed（附一个可证伪的最小检查），账本/措辞写 Non-Blocking Suggestions；HANDOFF / TASK_BRIEF 中标日期的人类裁决按人类决定对待——不核实过程、不降为自述、不要求出现在人类 commit；异议只进 Requirement-Level Concerns。

[输出按上面「输出契约」+ `## Recommended Next Step` + `## Requirement-Level Concerns`（**两节都要，不替换** Recommended Next Step）；本 prompt 自包含]
本轮不要写入仓库任何文件（含 HANDOFF）——verdict 由 Author 在两份都完成后统一落账。
```

---

## 9P. Plan Review（计划批准前；2026-08-27 新增，唯一定义处）

**定位**：Critical 正式路径的**默认必跑**步骤——`/plan` 产出规划文件并把 Approval Status 置 Pending 之后、人类批准之前，由 Reviewer 对**规划本身**做 fresh-context 审查——**默认单跑一轮**（人类可明示要求再跑，见下）。价值：把 9B 只能在实现后才抓到的"计划本身错了"提前到实现开销发生之前，并独立检查 9A/9B 都拿来当公理的 TASK_BRIEF（2026-08-15 三病诊断中病 2/病 3 的病灶都在计划期、发作在实现后审查，各烧 5–7 轮）。verdict 是人类批准时的辅助判断材料——**批准权仍只在人类**：人类可在 Author 逐条表态后，知情批准带未采纳项的计划。

* **必跑与减免**：默认必跑；跳过仅凭**人类明示减免**。减免记录（谁/何时/一句话理由）由 Author 写进 `docs/ai/review_9P.md`（此时该文件只含减免记录），HANDOFF 的 `plan_review_9P` 行只记 `N/A — 人类减免` + 文件指针，**不写理由正文**。快速版（无 `IMPLEMENTATION_PLAN.md` 文件）天然不适用，记 `N/A — 快速版`（无需创建文件）。
* **默认单跑一轮，不双审（2026-09-03 撤回 2026-08-27「逐轮复审至收敛」：7 个真实任务里 9P 跑出 3–6 轮、仅 1 个任务曾到「可批准」，blocking 数不单调收窄）**——Author 收 verdict 后按「修法必附」契约逐条三选一表态并修订计划，verdict + 表态 + 修订后的计划一并交人类**知情批准**（批准 commit 含 `docs/ai/review_9P.md`）。人类可在批准前**明示要求**再跑一轮（每次一轮；prompt 填 `9P round: <n>` 并附上一轮 blocking 与表态摘要，摘要缺失时 Reviewer 在 verdict 首行注明「上下文缺失」并照常审查）。**不设「逐轮复审至收敛」、不设轮次上限与四条出路**——Plan Verdict 是人类批准时的辅助材料，批准权只在人类。**9P 的 blocking 不进 Fix-Loop Counter、不触发硬停、不标 `[Product]`/`[Verification]`、不填 `caused_by_last_fix`，其轮次也不计入 9A/9B 双审的轮次上限**（那套分类与计数只服务实现后的 9A/9B 轮）；据 9P 反馈修订计划属正常规划迭代，不是 review-fix。
* **审查对象 = 工作树中的规划文件**（此时批准 commit 尚不存在）：`TASK_BRIEF.md`、`IMPLEMENTATION_PLAN.md`（+ `PRODUCT_BRIEF.md` / `QUALITY_GATES.md` 如有）+ 只读检索仓库现状。**没有实现 diff、没有 `last_test_run.txt`、没有 SHA 账本——不适用审前快照自检与三行证据首行**；锚定只记三行哈希（见 prompt）。证据载体整句 = `AGENTS.md` → Reviewer-Lightweight Protocol 第二层的「Critical 计划审（9P）」条（与下方 prompt 内嵌句逐字一致）。
* **调用与零写入**：调用形态同双审隔离协议 ③（显式 sandbox / model / 效力档、`</dev/null` 必带、不接管道），**但推理档取 `medium` 而非 9A/9B 的 `high`**（取值定义见 ③）；一对 `-o` verdict + raw log 落仓外 holding；零写入无例外。可执行命令（`<n>` = 本轮轮次，**逐轮换名**——人类明示要求加轮时沿用同一文件名会覆盖上一轮的 verdict 与 raw log）：

```bash
HOLD="$HOME/.codex-review-holding/<task>"; mkdir -p "$HOLD"
codex exec --sandbox workspace-write --ephemeral --ignore-user-config --ignore-rules --disable memories -c 'windows.sandbox="elevated"' -m gpt-6-astra -c 'model_reasoning_effort="medium"' -o "$HOLD/9P_r<n>.md" "<9P prompt>" </dev/null > "$HOLD/9P_r<n>_raw.log" 2>&1
```

  > **降档来历（2026-08-30 人类裁决）**：9P 审的是规划文件而非代码 diff，三类审查里对深度代码推理的需求最低，而实现级精度本就该由实现期的 9A/9B 承担。当日实测（5 个项目最新已结束会话，99 次 Codex 运行、17.1h）：9P 单轮 p50 = 514s、28 次累计 3.8h，且轮次最不收敛（某项目 9P 跑满 6 轮仍 `修订后可批准`，另一项目归档记录的逐轮 blocking 数为 `6 / 5 / 3 / 4`，不单调收窄）。**9A/9B 维持 `high` 不动**——它们审真实 diff，是实测中唯一挡下 `[Product Blocking]` 的环节，降档最先丢失的正是"读代码 + 构造反例"类发现。本降档可逆：回滚 = 把本条命令的档位改回 `high`。**判断降档是否划算的三个观察量**（与降档前的 high 档基线比）：9P 单轮时长（基线 p50 514s）、每轮 blocking 条数、Author 表态的采纳率（基线 100%）；采纳率明显下降即应回滚。
* **落账（9P 例外于「表态记 Work Log」的通用规则——防止经 HANDOFF 污染后续 9A/9B）**：Author 把**每轮** verdict 依轮次追加进 `docs/ai/review_9P.md`，各轮逐条三选一表态**附在同文件对应轮的 Author Responses 节**（每条一句话），表态并修订计划后连同 verdict 一起交人类知情批准；Verification Needed 的代跑结果（命令 + 退出码 + 一句话结论）也写进该轮 Author Responses 节，随批准 commit 入库。**9P 的 verdict、表态与减免记录只放这一个文件**——HANDOFF 的 `plan_review_9P` 行只记 Plan Verdict 词 + 文件指针，Work Log 只记一行「9P 已跑/已减免 + 指针」，**都不复述发现内容、修改内容或理由**。**人类批准 commit 应包含 `docs/ai/review_9P.md`**——批准凭证自带独立审查证据。该文件命中双审隔离协议的 `review_9*` 污染模式：随批准 commit 入库后属"已提交进历史的审查产物"，后续 9A/9B **不读**（对 9B 尤其如此——读它等于间接读计划）。
* **与 9A/9B 的防污染边界**：9P 与后续 9A/9B 是各自独立的 fresh 进程；9A/9B 的 prompt **不得包含 9P 的结论或内容**，两者也**不读 `docs/ai/review_9P.md` 正文**（见上条落账规则；对 9A 同样适用，其 prompt 已内嵌对应排除句）。**可见的仅限元数据**——未过滤 `git diff --name-only` 输出中该文件的存在（正文 diff 已用 `:(exclude)` 机械排除 `docs/ai/review_9*.md` 与 `docs/ai/archive/**`，见 9A/9B prompt）、HANDOFF `plan_review_9P` 行的 verdict 词与文件指针；Reviewer 不得把这些当作计划质量或实现正确性的证据。

### 9P prompt（复制给 Codex）

```
你是本项目的独立 plan reviewer（9P 计划审，Critical 模式）。本轮审查对象是**尚未批准的实现计划**，不是实现——此时没有实现 diff、没有 docs/ai/last_test_run.txt、没有批准 commit 与 SHA 账本，**不要索取它们，也不要因其缺失拒审**；不执行审前快照自检。**只审不改**：不得修改任何文件、不得创建任何 commit；发现的问题只写进 verdict。

本轮轮次：9P round: <由 Author 填，从 1 起计>。round > 1 而本 prompt 未附紧邻上一轮的 9P blocking 与 Author 全部表态摘要 → 在 verdict 首行注明「上下文缺失：9P round <n> 缺上一轮摘要」，然后**照常全量审查**（历史完整内容仍只在 docs/ai/review_9P.md，摘要由 Author 在 prompt 内提供，你不得自行打开该文件）。

先读：1) AGENTS.md（遵守 Safety Rules） 2) docs/ai/TASK_BRIEF.md 3) docs/ai/IMPLEMENTATION_PLAN.md 4) docs/ai/PRODUCT_BRIEF.md（如存在） 5) docs/ai/QUALITY_GATES.md（如存在）。以上一律**读工作树当前文件**。可只读检索仓库任意代码以核对计划的声称。

不要 git archive 重建副本、不要重装依赖、不要跑任何测试——此时尚无实现与测试产物；以工作树中的规划文件 + 只读检索仓库现状为准；需要实跑确认的具体命令列出来，由 Author 在正常终端代跑。

round > 1 时：先逐条核验上一轮 blocking 的闭合情况，再做全量审查——闭合核验不替代全量审查。

核心问题：假设你是第一次接触本项目的资深工程师，**按这份计划做下去，会不会做错东西、做不完整、或做出无法验收的东西？**重点五项：
1. TASK_BRIEF 内伤：需求与验收是否内部一致；每条 AC 的判定方式是否满足 AGENTS.md → 验收条款必须可复现判定（可复现 + 有区分力；"散文对读"不是验收条款）。
2. 守护类声称的负向对照：凡「机制 X 拒绝 Y」的 AC，等价类是否枚举自人类冻结的输入域、每类是否有「移除 X 则会通过」的对照样本（AGENTS.md → 守护有效性装置）。
3. 架构理解与仓库实况：计划的 Current Architecture Understanding 与 Proposed Changes 是否与真实代码相符——抽查其关键声称（文件/接口/行为确实如计划所述）。
4. 复用遗漏：方案比较是否真做过复用检索；从零自建的否决理由是否成立；是否重复造仓内已有的轮子。
5. 假设与范围：Frozen Acceptance（`TASK_BRIEF.md` → Acceptance Criteria）是否从实现反推；Open Questions 是否真收敛（≥1 个未解决 = 草稿）；[假设] 是否都有验证方式；diff 预算预估与架构层拆分评估是否可信。

输出契约（9P 专用；先写四行锚定证据——首行照抄 prompt，后三行为实际命令输出）：
9P_round: <照抄 prompt 的 9P round 值>
observed_head_sha: <git rev-parse HEAD>
task_brief_blob_sha: <git hash-object docs/ai/TASK_BRIEF.md>
plan_blob_sha: <git hash-object docs/ai/IMPLEMENTATION_PLAN.md>
## Plan Verdict            可批准 / 修订后可批准 / 不可批准（硬规则双向绑定：Blocking Issues 非空 → 只能"修订后可批准"或"不可批准"；Blocking Issues 为 None → 必须"可批准"——Suggestion 与 Assumption Challenges 不影响可批准）
## Blocking Issues         无则 "None"。按计划落地会导致做错/做不完整/无法验收的缺陷；每条必附 Proposed Fix（具体改法 + 依赖假设；需取舍写"需人类裁决"）。不标 [Product]、不填 caused_by_last_fix——9P 不进 Fix-Loop。**不得以「计划散文是否完备」立 blocking**：形如"若 X 场景未考虑""建议补充说明 Y"而无法指出按此计划落地会做错什么的条目，一律降级 Non-Blocking Suggestion。判据 = 能否写出一个「按此计划执行会失败」的具体后果。
## Non-Blocking Suggestions 无则 "None"。每条同样必附 Proposed Fix。
## Assumption Challenges   对 Frozen Acceptance / [假设] 标签 / 高影响前提的挑战，无则 "None"。
## Verification Needed     需 Author 在正常终端实跑以核对计划声称的具体命令 + 想确认的事实。无则 "None"。
## Recommended Next Step   只写建议 Author / 人类做什么，不自行动手。
```
