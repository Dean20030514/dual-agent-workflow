# Reviewer 独立审查 Prompt（投给 DSH 子 agent / headless 进程）

**实现审默认双审 9A+9B**（9A 对照计划审实现 + 9B 盲审只对需求审，双视角互补——9B 能抓"实现完全符合计划但计划本身错了"，本项目已多次实证 9B 抓到 9A 漏的真 blocking）。配额吃紧或纯小任务时可只跑 **9A 标准版**。
两版共用同一份输出契约（§契约），只差是否读 PLAN、以及末节。
**另有 9P 计划审（2026-08-27 新增）**：Critical 正式路径在计划批准前**默认必跑、默认单跑一轮**的审查（再审仅凭人类明示要求），审规划文件而非实现——定义、prompt 与专用契约见文末 → 9P 节（**不**共用 9A/9B 的输出契约与审前快照自检）。

> Author 发起 review 前确认：Reviewer 能读到**项目内**的 `docs/ai/QUALITY_GATES.md`（重点检查第 6 条会用到）——**审查对象永远是项目适配过的那一份**；项目没有该文件或读不到时，把本任务适用清单条目粘进 prompt，或退到 `~/.dsh/workflow/QUALITY_GATES.md` 的母本并把"用的是母本"写进 verdict。

> **适用范围（2026-08-15 补；2026-09-06 DSH 化）**：本文件全部内容——9P 计划审、9A/9B 双审、双审隔离协议、审前快照自检、SHA 绑定——**只属 Critical 模式**。
> **Routine 下由人类临时要求的一次性只读审查不走本文件**：它没有交接文件、没有 `last_test_run.txt`，照本文件执行审前快照自检必然失败而拒审。其证据依据、拒审边界与"不得为审查临时造交接文件"的红线，见 `AGENTS.md` → **Reviewer-Lightweight Protocol 第二层**（唯一定义处，本文件不复述）。
> 误把本文件套到 Routine 的后果是实测过的：Reviewer 会去索取不存在且不得创建的产物，只能靠人类在每份 prompt 里手写覆盖来绕开——那是规则缺失的症状，不是正常用法。

> **DSH 落地差异（2026-09-06；只改"怎么跑"，判据一字未改）**：原母本投的是 `codex exec`，靠 Codex 进程沙箱（读不了 `node_modules` 的 EPERM）**物理兜底**零写入。DSH 没有那一层：`subagent` 与 headless 进程**同机、同权限、同工作目录**，**技术上写得到仓库**。所以本文件在 DSH 下**只更严不更松**——零写入从"沙箱帮你挡"变成"你必须自己不做"。工具面事实（可用委派面、参数、派发上限、失败语义）唯一定义处：`~/.dsh/workflow/fanout-toolchain.md`。

---

## 双审隔离协议（强制；「9A/9B 真独立」的唯一定义处）

双审的价值全部来自**两份互不污染的独立判断**。下面五条是硬门，缺任一条这轮不算独立双审，不得据其标收敛。

**① 同一快照**：9A 与 9B 审的必须是**同一个** `review_tip_sha`（对同一个 `review_base_sha` 的 diff）+ **同一份审前 HANDOFF**（= Author 在 `/implement` 快速版步骤 5 / 正式版步骤 4.7 提交的那个交接 docs commit 的内容）。两轮之间**不得**重跑测试、重写 `last_test_run.txt`、或改任何交接文件。

> **两个锚点不是同一个 commit，必须分别说清（血泪，2026-07-28 演练实测）**：`docs/ai/HANDOFF.md` 与 `docs/ai/last_test_run.txt` **不在** `review_sensitive_paths` 内，按 `/implement` 的顺序它们提交在 `review_tip_sha` **之后**的那个 docs commit 里 —— 所以 tip 里装的是**过期 HANDOFF**。只写"你审的是 tip 这个确切 commit"会让 Reviewer 去跑 `git show <tip>:docs/ai/HANDOFF.md`，读到旧版（实测原 Codex 就是这么干的）。因此每份 prompt 必须拆开写：**代码/测试/验收 = 带排除项的正文 diff `git diff <review_base_sha>..<review_tip_sha> -- . ":(exclude)docs/ai/review_9*.md" ":(exclude)docs/ai/archive/**"`（9B 另加 `":(exclude)docs/ai/IMPLEMENTATION_PLAN.md"`；排除只作用于正文输入——防止历史与本任务的 verdict 正文经 diff 输出进入 Reviewer 输入；快照自检的覆盖核验用未过滤 `--name-only`）；HANDOFF 与 last_test_run.txt = 读工作树当前文件**。Author 在两份 prompt 里写明同一个 `handoff_snapshot_sha`（= 双审窗口开启时的 HEAD，即那个 docs commit），并把 `review_base_sha` / `review_tip_sha` 逐字写进 prompt（不写『见 HANDOFF』——2026-07-28 那次正是 Reviewer 去 tip 里找 HANDOFF 才读到旧版）。**prompt 值只是输入，不是证明**：「同一份审前 HANDOFF」由两个 Reviewer 各自跑审前快照自检（⑤）并把结果记入 verdict 证据首行落账——两份证据相互吻合且与 `handoff_snapshot_sha` 吻合才构成绑定；窗口冻结（②）是自检应当通过的原因，不是免检的理由。

**② 双审窗口冻结**：从第一个 Reviewer 启动，到两份 verdict 都产出为止，**任何人（Author 与两个 Reviewer）都不得**：
* 改生产代码 / 测试 / 任何 `review_sensitive_paths` 内的文件；
* 更新 `docs/ai/HANDOFF.md`（Work Log / Next Step / Binding 一律等到窗口结束）；
* 创建任何 commit，包括 `wip(review-fix)`。

发现 blocking 只写进自己的 verdict。**原「9A 期间发现 blocking 可小范围自修」与「Reviewer 末尾更新 HANDOFF」两条例外已取消**（与 `AGENTS.md` → AI Collaboration Rules 一致）。理由：窗口内任一处写入都会改变后跑者看到的证据面，两份 verdict 就不再是对同一对象的独立判断。

**③ 调用形态与零写入（DSH 唯一出处）**

Reviewer 有两条落地路径，**都要显式换模型路由、都要前台、都不许写仓库**。工具面细节（参数含义、准入白名单、headless 无 `-o` 等）见 `~/.dsh/workflow/fanout-toolchain.md`；本节点明的是**审查侧必须遵守的调用形态**：

**(a) 主路径 — 同会话 `subagent`（默认；Author = 当前会话主 agent）**

```
subagent(
  description: "9B blind review",     # 9A 那轮写 "9A standard review"
  run_in_background: false,           # 审查必须前台等结果
  provider: "deepseek-official",
  model: "deepseek-flash",
  reasoning_effort: "high",           # 9A/9B = high；9P = high（DSH 无 medium 档）
  prompt: "<把本节 9B（或 9A/9P）的 prompt 整段粘进来，变量逐字填好>"
)
```

* 子 agent 是 **fresh context**（看不到本会话历史），独立性的"上下文"一层由工具保证；**"零写入"一层没有任何工具帮你保证**——所以每份 prompt 都必须内嵌零写入硬约束，且 Reviewer 侧必须**拒绝执行任何写操作**（包括"顺手把 verdict 存下来"）。
* **模型档必须显式给**：不带 `provider`/`model` 就继承父路由，独立判断退化成同模型复读。两者都要落在宿主 `subagent-model-selection.allowedModels` 白名单内，否则调用被拒。
* **不写 `reasoning_effort` 会落部署默认**（本机 = 父会话档）。取值按审别，**本处为唯一定义处：9A / 9B = `high`，9P = `high`**——**DSH 侧三类审查同档**：DeepSeek 适配器的取值域是 `off / low / high / max`，**没有 `medium`**；母本"9P 比实现审低一档"的设计在 DSH 上不可表达，强行取 `off`/`low` 只会引入未经实测的档位假设（2026-09-06 人类裁决取 `high`；理由与来历见文末 9P 节）。适配器取值域是**硬校验**：写 `medium` 会在子 agent 创建前的路径预检就抛 `UNSUPPORTED_REASONING_EFFORT`（`dsh-llm-deepseek` 的 `reasoningEffort()`）。
* **9B 先跑**（盲审最需要干净上下文），9B **不接收** 9A 的任何输出；两次调用之间，Author 确认工作树内**不存在**任何 verdict / raw log 残留。
* 调用返回的是 **verdict 正文**。**落盘由 Author 在双审窗口结束后做**（写进仓外 holding，见 ④）——Reviewer 自己不落盘，这是 DSH 下"零写入"最容易被无意破坏的一点。

**(b) 备用路径 — 独立 headless 进程（需要物理隔离或可复现证据时）**

```powershell
$HOLD = "$env:USERPROFILE\.dsh-review-holding\<task>"; New-Item -ItemType Directory -Force $HOLD | Out-Null
$env:DSH_HOME = "$env:USERPROFILE\.dsh"
# 两份 prompt 先各自写进仓外文件，再逐轮启动（9B 先、9A 后）
npx -y @deepseek-ai/dsh --profile headless (Get-Content "$HOLD\9B_prompt.txt" -Raw) > "$HOLD\9B.md" 2> "$HOLD\9B_raw.log"
# 确认工作树无 verdict 残留后
npx -y @deepseek-ai/dsh --profile headless (Get-Content "$HOLD\9A_prompt.txt" -Raw) > "$HOLD\9A.md" 2> "$HOLD\9A_raw.log"
```

* headless **没有 `-o`**（`-o` 是原 Claude 侧 `codex exec` 的参数，DSH 无对应项）：verdict = **stdout**，raw log = **stderr**，二者都必须重定向到**仓外** holding。
* headless 每次运行落一个持久化会话，天然是 fresh 进程；它与 `subagent` 路径在**证据强度上等价**（同一份 prompt、同一套自检），差别只是进程隔离度与可复现性。
* **两条路径的证据面必须一致**：证据头（三行基底 + `model_route`）与 `writes_performed` 在两条路径上都要落账。**缺项的后果是「记 Work Log + 报告人类」，不是作废**——这两个字段都是**自报值**，缺一项抓不到不诚实的 Reviewer、却会废掉一份合规的独立判断。**作废只留给经独立核验确认的违反**：④ 的启动前扫描发现残留、`observed_head_sha` 不符、`worktree_clean` 非 `yes`、`read_handoff_from` 出现 `git show tip`。（分级依据：2026-09-16 人类裁决 + `docs/ai/DSH-LANDING-NOTES.md` §7.1/§7.2 的 10 轮重放——`model_route` 的漂移暴露只能靠 Author 逐字比对实发参数，属可见性工具。）

**(c) 两条路径共同的红线**

* **对仓库零写入无例外**：不改任何文件（含 HANDOFF）、不创建任何 commit、不落任何 verdict/raw log 到工作树内。若某环境不允许把输出写到仓外 → **停止并报告人类**，不得退化为写进仓内——哪怕"跑完立刻 mv 到 holding、事后工作树恢复干净"也不行：双审窗口内曾发生的仓内写入本身就已破坏两份判断的独立性。
* **零写入违反 = 该轮作废重跑**，不因"写的是无害文件""只是顺便记一下"而豁免。
* **审查不许跑测试、不许重建副本、不许重装依赖**：证据载体整句按模式从 `AGENTS.md` → Reviewer-Lightweight Protocol 第二层**直接复制**，不要自己拼。
* **不许执行 `install.ps1` 的任何形态**（无参数 = 真实部署：覆盖 `~/.claude` / `~/.codex` / `~/.dsh` 并触发网络插件安装；`-DryRun` / `-ValidateOnly` 虽零写入，也不由 Reviewer 跑）。**具名禁止是刻意的**——2026-09-15 的 9P round 1 正是违反了泛泛的"不跑任何会改文件的命令"，在真机上删掉 **127 个本机独有文件**、该轮 verdict 作废（损害表与恢复见 `docs/ai/archive/2026-09-15-h3-installer-hardening-stopped/review_9P.md`）。安装器行为一律列进 Verification Needed，由 Author 在隔离临时 HOME 下跑 `tests/` 套件代跑。唯一定义处 = `AGENTS.md` → Reviewer-Lightweight Protocol 第一层。
* **subagent 调用失败 / 返回空 / 意外变成后台**：按 `~/.dsh/workflow/fanout-toolchain.md` → 失败语义处理（重跑 → 两次失败即停手交人类）。**不得由 Author 代写 verdict、不得把"没有 verdict"记成 `通过`。**

**④ 两份 verdict 分开保存且互不可见**：verdict 与 raw log 一律落**仓库工作树之外的 holding**（主路径下由 **Author** 在双审窗口结束后把两份返回正文分别写入 `$HOME/.dsh-review-holding/<task>/9A.md` / `9B.md`——**两个文件都必须在仓外**）。启动每一个 Reviewer 前，Author 必须确认工作树内**不存在**任何 review verdict / raw log：`git status --porcelain --ignored` 的输出里没有任何 verdict / raw log 模式文件（`9A*.md` / `9B*.md` / `.codex-review-*` / `.dsh-review-*` / `review_9*` / `review-*` / `*_raw.log`），且 holding 在仓外。**`--ignored` 必带**——普通 `git status --porcelain` 看不见被 .gitignore 覆盖的残留 verdict，等于给污染留后门（其它被 ignore 的构建产物如 `__pycache__/` 不算污染，只认上述审查产物模式）。

两份都完成后，Author 把两份 verdict 收进 `docs/ai/review_9A.md` / `docs/ai/review_9B.md`（这一步在**双审窗口结束后**），清掉仓外 scratch 前先让人类确认。**减档只跑 9A 时**，`review_verdict_9B` 记 `N/A — 人类减档，原因: …`。

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

* **契约首行（两版共用，快照证据必填）**：在 `## Review Verdict` 之前先写**证据头（三行基底 + `model_route`）**：`observed_head_sha: <git rev-parse HEAD 实际输出>`、`worktree_clean: <yes/no，全树 git status --porcelain 是否为空>`、`read_handoff_from: <工作树 / git show tip>`、`model_route: <provider>/<model>@<reasoning_effort>`；有覆盖缺口则在其后追加 `覆盖缺口: <路径>` 行。作用：把"读没读到审前快照"从声明变成可机检、可事后比对的持久化证据（自检命令见 ⑤）。`read_handoff_from` 若是 `git show tip`、或 `observed_head_sha` ≠ prompt 里的 `handoff_snapshot_sha`、或 `worktree_clean: no` —— 该轮审查建立在过期/污染证据上，**直接作废重跑**（详见 ① 的血泪注）。
* **零写入承诺行（DSH 新增，必填）**：证据首行之后追一行 `writes_performed: none`（或如实写出任何曾尝试/发生的写入并说明）。**DSH 下这是唯一能自证零写入的字段**——没有沙箱兜底，这条字段就是纪律的落点；Author 落账时逐字转录进 HANDOFF。
* **模型路由自报行（DSH 新增，必填；来历 = 首轮双审 9B 的 R2）**：再追一行

  ```
  model_route: <provider>/<model>@<reasoning_effort>
  ```

  按你**实际收到的调用指令**写（不是替你选择）。例如 `deepseek-official/deepseek-flash@high`。**作用与限度，两个都要说清**：它让"Author 与 Reviewer 同取 `deepseek-flash` @ `high`"这条在每份 verdict 里留痕，从而能抓**档位漂移**——尤其备用路径（headless）钉不住路由时，这是唯一的暴露点；但它是**自报值、不是证据**，没有任何机械手段能证明它属实。**Author 落账时的核验义务**：把每份 verdict 的 `model_route` 与**自己实际发出去的调用参数**逐字比对；两者不一致即写进 Work Log 并报告人类（处置见 `fanout-toolchain.md` → 失败语义）。该字段**不改判据**，故不触发母本级变更。
* **9A 末节追加**：`## Recommended Next Step`——**只写建议 Author 做什么**。本轮你不得改代码、不得改 HANDOFF、不得 commit（双审隔离协议 ②）；review-fix 由 Author 在双审窗口结束后按 `/debug` 执行、commit 仍用 `wip(review-fix): [说明]`。
* **9B 末节**：先 `## Recommended Next Step`（同 9A——**所有 verdict 都含此节**；同样只写建议、不自行动手），**再加** `## Requirement-Level Concerns`（实现思路层面的疑问——即使代码无 bug，方案是否就错/过度/不完整。无则 "None"）。**两节都输出，不替换。**

---

## Author 侧：发 9A/9B 前置检查（DSH 清单，逐项打勾再发）

1. `review_base_sha` / `review_tip_sha` / `handoff_snapshot_sha` 三个值已逐字填进**两份** prompt（不写『见 HANDOFF』）。
2. 当前 `git rev-parse HEAD` == `handoff_snapshot_sha`，且全树 `git status --porcelain` 为空。不满足 → 先形成明确的 reviewable commit，别发审。
3. `git status --porcelain --ignored` 无任何 verdict / raw log 残留（模式见 ③/④）。
4. 仓外 holding 已建好（`$HOME/.dsh-review-holding/<task>`），**且与仓库工作树不同子树**。
5. 两份 prompt 都内嵌了对应模式的证据载体整句（从 `AGENTS.md` 第二层直接复制），都写了「零写入 + `writes_performed` 与 `model_route` 字段」。
6. 调用形态已按 ③ 填好：`run_in_background: false`、`provider: "deepseek-official"`、`model: "deepseek-flash"`、`reasoning_effort: "high"`（9P 同为 `high`——DSH 无 `medium` 档）。
7. **9B 先发**；拿到 9B 返回后才发 9A；9A 的 prompt 里**不含** 9B 的任何内容。
8. 两份都拿到后，才统一落账（④）：两个文件写进仓外 holding，再写 `docs/ai/review_9*.md`，再一次性更新 HANDOFF。

---

## 9A. 标准 Review（对照计划审实现）

```
你是本项目的独立 code reviewer。**只审不改**：本轮任何情况下都不得修改生产代码 / 测试 / 验收文件，不得修改 docs/ai/HANDOFF.md，不得创建任何 commit，不得把任何文件（含你自己的 verdict）写进仓库工作树。发现 blocking 只写进 verdict 文本，由 Author 在双审结束后处理。

先读：1) AGENTS.md(遵守 Safety Rules) 2) docs/ai/TASK_BRIEF.md 3) docs/ai/IMPLEMENTATION_PLAN.md
4) docs/ai/HANDOFF.md 5) 审查对象 = 正文 diff：git diff <review_base_sha>..<review_tip_sha> -- . ":(exclude)docs/ai/review_9*.md" ":(exclude)docs/ai/archive/**"（review_base_sha=<Author 填>、review_tip_sha=<Author 填>，与工作树 HANDOFF 的 Review & Test Binding 一致；排除项防止历史与本任务的 verdict 正文进入你的输入——「不得打开」包括不得让其正文出现在 diff 输出里；未过滤的 git diff --name-only 仅用于快照自检的覆盖核验与确认文件存在）6) docs/ai/last_test_run.txt

审查对象锚定（两个锚点，别混）：
* **审前快照自检（先于一切审查动作，结果记入 verdict 证据首行）**：`git rev-parse HEAD` 必须 == handoff_snapshot_sha（<由 Author 填>）→ 记 observed_head_sha；`git status --porcelain`（**全工作树**，不只 review_sensitive_paths）必须为空 → 记 worktree_clean；HANDOFF 与 last_test_run.txt 从工作树读 → 记 read_handoff_from: 工作树；另追一行 `model_route: <provider>/<model>@<reasoning_effort>`（按你实际收到的调用指令写，见输出契约）。**HEAD 不符或工作树不净 → 在审查正文前输出「快照不一致」（写明失败项与实际观察值）并拒审，不得继续。** 另核 `git diff --name-only <base>..<tip>` 中每个必含类别的文件（类别以 `AGENTS.md` → review-sensitive paths + SHA 绑定为准：生产源码 / tests / migrations·schema / 构建配置 + **依赖声明 + lockfile** / TASK_BRIEF；IMPLEMENTATION_PLAN / QUALITY_GATES 出现不算缺口）都被 HANDOFF 的 `review_sensitive_paths` 覆盖——漏项在证据首行之后写「覆盖缺口：<路径>」并**照常审查**，不拒审。
* **代码 / 测试 / 验收文件**：审上述**带排除项的正文 diff** 这个确切范围，不是工作树。若 `git status --porcelain -- <review_sensitive_paths>` 非空，或 `git diff --quiet <review_tip_sha> -- <review_sensitive_paths>` 不通过 → 停下报告"快照不一致"，不要改审工作树。
* **docs/ai/HANDOFF.md 与 docs/ai/last_test_run.txt**：**直接读工作树当前文件**（当前 HEAD = handoff_snapshot_sha <由 Author 填>）。**不要**用 `git show <review_tip_sha>:docs/ai/HANDOFF.md` —— 这两个文件不在 review_sensitive_paths 内、按流程提交在 tip 之后，从 tip 取会拿到过期版本。

不要 git archive 重建副本、不要重装依赖、不要重跑全量测试——以 docs/ai/last_test_run.txt 产物 + 读 git diff 推理为准；需要验证的具体行为列出来，由 Author 在正常终端代跑。
对 last_test_run.txt 批判性阅读：命令是否真实存在、输出是否完整、结论是否一致；证据不足则写进 Verification Needed，不自己运行。
已提交进历史的审查产物（docs/ai/archive/**、已落账的 docs/ai/review_9*.md，含 review_9P.md）**不得自行打开**；re-review 时上一轮 9A/9B blocking 的上下文由 Author 在本 prompt 内提供，可以且应当使用；9P 的结论或内容任何时候不得提供、不得使用。HANDOFF 的 plan_review_9P 行仅是状态记录，不得据以推断计划质量或当作实现正确性证据。

**零写入硬约束（DSH）**：你有文件工具与 shell，也能写这个仓库——**但本轮禁止任何写操作**：不写文件、不建目录、不 commit、不跑会改文件的命令（含格式化器、代码生成、测试）。你的 verdict 只作为**本次调用的返回正文**交回 Author；不得自行落盘到仓库或任何 holding。若你发现某项结论离不开写操作，写进 Verification Needed，不要动手。verdict 证据首行必须含 `writes_performed: none`（有任何写入尝试则如实写出并说明）。

**具名禁区（违反即该轮作废）**：绝对禁止执行 `install.ps1` 的任何形态——无参数运行 = **真实部署**（逐文件覆盖 `~/.claude` / `~/.codex` / `~/.dsh`，并触发**网络**插件安装）；只有 `-DryRun` / `-ValidateOnly` 是零写入，但也不由你跑。2026-09-15 的 9P round 1 正是违反了上面那条泛泛的"不跑会改文件的命令"、在真机上删掉 **127 个本机独有文件**（该轮 verdict 作废）。安装器行为一律列进 Verification Needed，由 Author 在隔离临时 HOME 下跑 `tests/` 套件代跑（唯一定义处 = `AGENTS.md` → Reviewer-Lightweight Protocol 第一层）。

重点检查：
1. 是否满足 TASK_BRIEF 的需求与验收。
2. 是否严格遵守 IMPLEMENTATION_PLAN，偏离是否合理。
3. 是否有无关修改、是否破坏现有 API/数据结构。
4. 安全、边界遗漏、类型、测试覆盖不足。
5. 是否为通过测试而绕过逻辑（对照 diff 中测试文件改动逐一确认）。
6. 核对 **项目内** `docs/ai/QUALITY_GATES.md` 中本任务适用组 + 有界面则设计层闸门（需实跑的列 Verification Needed）。项目没有该文件或读不到 → 用 prompt 内粘贴的清单条目，或退到 `~/.dsh/workflow/QUALITY_GATES.md` 母本并在 verdict 里注明用的是母本。
7. **回归面（尤其 re-review 一次 review-fix 时）**：本次改动可能破坏被报案例**之外**的其它消费者/值域吗？枚举该字段/路径的其它生产者/消费者，确认没破坏或列进 Verification Needed——别只确认被报问题修了。
8. **证据真实性**：**不收 Author "已修复/已吸取教训" 的自我总结当证据**；diff 里若有 probe / mutation harness / 临时脚本，它**不算完成证据**（应提交前删除或重写为正式 regression test）。「回归用例有效」声称只认**守护有效性装置的结构化产物**——必填字段与失败判据以 `AGENTS.md` → 守护有效性装置（唯一定义处）为准，逐字段核对产物完整性、自洽与生成时 commit 的**内容绑定**（判法 = 该节字段 ⑦，不要求 sha 相等）；**你不运行装置**；产物缺失或字段不可信 → 列 Verification Needed（附一个可证伪的最小检查）。Blocking 只收 [Product Blocking] 并标 caused_by_last_fix（判据 = `AGENTS.md` → Reviewer verdict 分类语义：具体后果 / 具体反例 / 删测试理由不成立）；HANDOFF / TASK_BRIEF 中标日期的人类裁决按人类决定对待——不核实过程、不降为自述、不要求出现在人类 commit；异议只进 Assumption / Requirement-Level Concerns。

[输出按上面「输出契约」+ 9A 末节 Recommended Next Step（只给建议，不自行执行）]
```

---

## 9B. Blind Review（只对照需求审实现）

> 刻意不提供 IMPLEMENTATION_PLAN，目的是检验实现是否真正满足需求、而非是否符合计划。
> 9B 先跑：此时 9A 的 verdict 尚不存在，从物理上保证盲审不被带偏。

```
你是本项目的独立 code reviewer。刻意不读 IMPLEMENTATION_PLAN.md（以免被计划意图带偏）。**只审不改**：不得修改任何生产代码 / 测试 / 验收文件，不得修改 docs/ai/HANDOFF.md，不得创建任何 commit，不得把任何文件（含你自己的 verdict）写进仓库工作树。

只依据：1) AGENTS.md 2) docs/ai/TASK_BRIEF.md 3) docs/ai/HANDOFF.md(取 base branch/已知问题/闸门状态，但不据其反推计划意图；其 plan_review_9P 行仅状态记录，不据以推断计划内容)
4) 审查对象 = 正文 diff：git diff <review_base_sha>..<review_tip_sha> -- . ":(exclude)docs/ai/review_9*.md" ":(exclude)docs/ai/archive/**" ":(exclude)docs/ai/IMPLEMENTATION_PLAN.md"（review_base_sha=<Author 填>、review_tip_sha=<Author 填>，与工作树 HANDOFF 的 Review & Test Binding 一致；排除项使历史/本任务 verdict 正文与计划正文都不进入你的输入；未过滤的 git diff --name-only 仅用于快照自检的覆盖核验与确认文件存在）5) docs/ai/last_test_run.txt(批判性地读)

**HANDOFF.md 与 last_test_run.txt 直接读工作树当前文件**（当前 HEAD = handoff_snapshot_sha <由 Author 填>），**不要**用 `git show <review_tip_sha>:...` 取 —— 这两个文件不在 review_sensitive_paths 内、按流程提交在 tip 之后，从 tip 取会拿到过期版本。代码/测试/验收则严格审 base..tip 这个范围。

盲审隔离（硬性）：
* **docs/ai/IMPLEMENTATION_PLAN.md 已从上述正文 diff 机械排除**（`:(exclude)` pathspec；该文件**不在** review_sensitive_paths 内，但会出现在未过滤 --name-only 里，一律视作未提供）；不得单独打开它，也不得换用未带排除项的 diff 命令——若你的 diff 输出里出现了它的内容，说明命令用错了，改用带排除项的正文 diff 重来。
* 本轮不应存在任何其它 Reviewer 的输出。检查须覆盖被 .gitignore 忽略的文件（用 `git status --porcelain --ignored`，或对下述模式做显式文件扫描——普通 `git status --porcelain` 看不见 ignored 残留）；工作树里若存在**未提交或被 ignore** 的 review verdict / raw log 模式文件（`9A*.md` / `9B*.md` / `.codex-review-*` / `.dsh-review-*` / `review_9*` / `review-*` / `*_raw.log`）→ 视为污染，**不要读**，在审查正文前报告污染并**拒审**（该轮双审隔离不成立）。**目录不可枚举**（如权限受限的缓存目录 `.pytest_cache/`、`.vite/`）只在 verdict 里报告，不构成污染、不拒审；污染 = 实际找到匹配文件。已提交进历史的审查产物（`docs/ai/archive/**`、上一轮已落账的 `docs/ai/review_9*.md`）不算本轮污染，但同样**不得自行打开**；re-review 时 Author 只会在 prompt 里提供上一轮 **9B** blocking 的上下文（不含任何计划内容与 9P 内容），可以使用；除此之外的历史 verdict 内容不得接收。
* 你审的是 review_tip_sha 这个确切 commit，不是工作树。**审前快照自检（先于一切审查动作，结果记入 verdict 证据首行）**：`git rev-parse HEAD` 必须 == handoff_snapshot_sha → 记 observed_head_sha；`git status --porcelain`（**全工作树**，不只 review_sensitive_paths）必须为空 → 记 worktree_clean；HANDOFF 与 last_test_run.txt 从工作树读 → 记 read_handoff_from: 工作树；另追一行 `model_route: <provider>/<model>@<reasoning_effort>`（按你实际收到的调用指令写，见输出契约）。**HEAD 不符或工作树不净 → 在审查正文前报告「快照不一致」（写明失败项与实际观察值）并拒审。** 另核 `git diff --name-only <base>..<tip>` 中每个必含类别的文件（类别以 `AGENTS.md` → review-sensitive paths + SHA 绑定为准：生产源码 / tests / migrations·schema / 构建配置 + **依赖声明 + lockfile** / TASK_BRIEF；IMPLEMENTATION_PLAN / QUALITY_GATES 出现不算缺口）都被 HANDOFF 的 `review_sensitive_paths` 覆盖——漏项在证据首行之后写「覆盖缺口：<路径>」并**照常审查**，不拒审。

不要 git archive 重建副本、不要重装依赖、不要重跑全量测试——以 docs/ai/last_test_run.txt 产物 + 读 git diff 推理为准；需要验证的具体行为列出来，由 Author 在正常终端代跑。

**零写入硬约束（DSH）**：你有文件工具与 shell，也能写这个仓库——**但本轮禁止任何写操作**：不写文件、不建目录、不 commit、不跑会改文件的命令（含格式化器、代码生成、测试）。你的 verdict 只作为**本次调用的返回正文**交回 Author；不得自行落盘。若某项结论离不开写操作，写进 Verification Needed，不要动手。verdict 证据首行必须含 `writes_performed: none`。

**具名禁区（违反即该轮作废）**：绝对禁止执行 `install.ps1` 的任何形态——无参数运行 = **真实部署**（逐文件覆盖 `~/.claude` / `~/.codex` / `~/.dsh`，并触发**网络**插件安装）；只有 `-DryRun` / `-ValidateOnly` 是零写入，但也不由你跑。2026-09-15 的 9P round 1 正是违反了上面那条泛泛的"不跑会改文件的命令"、在真机上删掉 **127 个本机独有文件**（该轮 verdict 作废）。安装器行为一律列进 Verification Needed，由 Author 在隔离临时 HOME 下跑 `tests/` 套件代跑（唯一定义处 = `AGENTS.md` → Reviewer-Lightweight Protocol 第一层）。

核心问题只有一个：假设你是第一次看到这个项目的资深工程师，这个 diff 是否正确、完整、安全地实现了 TASK_BRIEF.md 的需求与验收？

**9B 盲审专攻面**：主动枚举 **遗漏入口 / 状态生命周期 / 边界值 / 回归**（9A 管计划-契约一致性，这几面归 9B）。不据 Author 自我总结；Blocking 只收 [Product Blocking] 并标 caused_by_last_fix（判据 = `AGENTS.md` → Reviewer verdict 分类语义：具体后果 / 具体反例 / 删测试理由不成立）；证据缺口写 Verification Needed（附一个可证伪的最小检查），账本/措辞写 Non-Blocking Suggestions；HANDOFF / TASK_BRIEF 中标日期的人类裁决按人类决定对待——不核实过程、不降为自述、不要求出现在人类 commit；异议只进 Requirement-Level Concerns。

[输出按上面「输出契约」+ `## Recommended Next Step` + `## Requirement-Level Concerns`（**两节都要，不替换** Recommended Next Step）；本 prompt 自包含]
本轮不要写入仓库任何文件（含 HANDOFF）——verdict 作为返回正文交回，由 Author 在两份都完成后统一落账。
```

---

## 9P. Plan Review（计划批准前；2026-08-27 新增，唯一定义处）

**定位**：Critical 正式路径的**默认必跑**步骤——`/plan` 产出规划文件并把 Approval Status 置 Pending 之后、人类批准之前，由 Reviewer 对**规划本身**做 fresh-context 审查——**默认单跑一轮**（人类可明示要求再跑，见下）。价值：把 9B 只能在实现后才抓到的"计划本身错了"提前到实现开销发生之前，并独立检查 9A/9B 都拿来当公理的 TASK_BRIEF（2026-08-15 三病诊断中病 2/病 3 的病灶都在计划期、发作在实现后审查，各烧 5–7 轮）。verdict 是人类批准时的辅助判断材料——**批准权仍只在人类**：人类可在 Author 逐条表态后，知情批准带未采纳项的计划。

* **必跑与减免**：默认必跑；跳过仅凭**人类明示减免**。减免记录（谁/何时/一句话理由）由 Author 写进 `docs/ai/review_9P.md`（此时该文件只含减免记录），HANDOFF 的 `plan_review_9P` 行只记 `N/A — 人类减免` + 文件指针，**不写理由正文**。快速版（无 `IMPLEMENTATION_PLAN.md` 文件）天然不适用，记 `N/A — 快速版`（无需创建文件）。
* **默认单跑一轮，不双审（2026-09-03 撤回 2026-08-27「逐轮复审至收敛」：7 个真实任务里 9P 跑出 3–6 轮、仅 1 个任务曾到「可批准」，blocking 数不单调收窄）**——Author 收 verdict 后按「修法必附」契约逐条三选一表态并修订计划，verdict + 表态 + 修订后的计划一并交人类**知情批准**（批准 commit 含 `docs/ai/review_9P.md`）。人类可在批准前**明示要求**再跑一轮（每次一轮；prompt 填 `9P round: <n>` 并附上一轮 blocking 与表态摘要，摘要缺失时 Reviewer 在 verdict 首行注明「上下文缺失」并照常审查）。**不设「逐轮复审至收敛」、不设轮次上限与四条出路**——Plan Verdict 是人类批准时的辅助材料，批准权只在人类。**9P 的 blocking 不进 Fix-Loop Counter、不触发硬停、不标 `[Product]`/`[Verification]`、不填 `caused_by_last_fix`，其轮次也不计入 9A/9B 双审的轮次上限**（那套分类与计数只服务实现后的 9A/9B 轮）；据 9P 反馈修订计划属正常规划迭代，不是 review-fix。
* **审查对象 = 工作树中的规划文件**（此时批准 commit 尚不存在）：`TASK_BRIEF.md`、`IMPLEMENTATION_PLAN.md`（+ `PRODUCT_BRIEF.md` / `QUALITY_GATES.md` 如有）+ 只读检索仓库现状。**没有实现 diff、没有 `last_test_run.txt`、没有 SHA 账本——不适用审前快照自检与三行证据首行**；锚定只记四行哈希（见 prompt）。证据载体整句 = `AGENTS.md` → Reviewer-Lightweight Protocol 第二层的「Critical 计划审（9P）」条（与下方 prompt 内嵌句逐字一致）。
* **调用与零写入**：调用形态同双审隔离协议 ③（显式 provider/model/推理档、前台等待、零写入、`writes_performed` 字段）。**推理档 = `high`，与 9A/9B 同档**——**DSH 侧没有"9P 比 9A/9B 低一档"这回事**：DeepSeek 适配器的档位阶梯是 `off / low / high / max`，**没有 `medium`**，母本那条"9P 降档"在 DSH 上不可表达；取 `off` 会让计划审完全不推理，取 `low` 则引入一个未经 DSH 实测的档位假设，故三类审查统一取 `high`（2026-09-06 人类裁决）。主路径 = 一次 `subagent` 前台调用，返回正文即 verdict；备用路径 = headless 进程，stdout 重定向到仓外 holding（**逐轮换名**——人类明示要求加轮时沿用同一文件名会覆盖上一轮的 verdict 与 raw log）。零写入无例外。

  ```
  subagent(
    description: "9P plan review",
    run_in_background: false,
    provider: "deepseek-official",
    model: "deepseek-flash",
    reasoning_effort: "high",
    prompt: "<下面 9P prompt 整段，变量逐字填好>"
  )
  ```

  ```powershell
  # 备用：headless（<n> = 本轮轮次）
  npx -y @deepseek-ai/dsh --profile headless (Get-Content "$HOLD\9P_r<n>_prompt.txt" -Raw) > "$HOLD\9P_r<n>.md" 2> "$HOLD\9P_r<n>_raw.log"
  ```

  > **为什么 DSH 侧不降档（2026-09-06 人类裁决；取代母本 2026-08-30 的 9P 降档）**：母本那次降档（`high` → `medium`）是为了省成本——9P 审的是规划文件而非代码 diff，三类审查里对深度代码推理的需求最低。**但 DSH 的档位阶梯只有 `off / low / high / max`，根本没有 `medium`**：把 Codex 的 `medium` 原样搬过来会让 9P 调用在子 agent 创建前的路径预检就抛 `UNSUPPORTED_REASONING_EFFORT`（首轮双审的 B1，两份 verdict 独立复现）。人类裁决取 `high`：① 与 9A/9B 同档，不引入未实测的档位假设；② 母本那组降档判据（9P 单轮 p50 514s、28 次累计 3.8h、逐轮 blocking `6 / 5 / 3 / 4` 不单调收窄）**全部量自 Codex 时代的 `gpt-6-astra`**，换模型后本来就要重新起算，拿它当 DSH 的降档依据不成立。**本裁决可逆**：回滚 = 改回 `low`（不是 `medium`——那个值不存在），并重新起算观察量。若要续接母本的成本观察，先量 DSH 侧 9P 单轮时长与 Author 采纳率，再谈降档。
  > **母本那次降档的来历（保留供对照，不适用于 DSH）**：2026-08-30 人类裁决，依据是当日实测（5 个项目最新已结束会话，99 次 Codex 运行、17.1h）：9P 单轮 p50 = 514s、28 次累计 3.8h，且轮次最不收敛；**9A/9B 维持 `high` 不动**——它们审真实 diff，是实测中唯一挡下 `[Product Blocking]` 的环节。本 DSH 落地把这段保留为**历史依据**，不作为取值指令（DSH 侧不存在 `medium` 这个选项）。
* **落账（9P 例外于「表态记 Work Log」的通用规则——防止经 HANDOFF 污染后续 9A/9B）**：Author 把**每轮** verdict 依轮次追加进 `docs/ai/review_9P.md`，各轮逐条三选一表态**附在同文件对应轮的 Author Responses 节**（每条一句话），表态并修订计划后连同 verdict 一起交人类知情批准；Verification Needed 的代跑结果（命令 + 退出码 + 一句话结论）也写进该轮 Author Responses 节，随批准 commit 入库。**9P 的 verdict、表态与减免记录只放这一个文件**——HANDOFF 的 `plan_review_9P` 行只记 Plan Verdict 词 + 文件指针，Work Log 只记一行「9P 已跑/已减免 + 指针」，**都不复述发现内容、修改内容或理由**。**人类批准 commit 应包含 `docs/ai/review_9P.md`**——批准凭证自带独立审查证据。该文件命中双审隔离协议的 `review_9*` 污染模式：随批准 commit 入库后属"已提交进历史的审查产物"，后续 9A/9B **不读**（对 9B 尤其如此——读它等于间接读计划）。
* **与 9A/9B 的防污染边界**：9P 与后续 9A/9B 是各自独立的 fresh 上下文（`subagent` 每次调用都是独立子 agent；headless 每次运行是独立会话）；9A/9B 的 prompt **不得包含 9P 的结论或内容**，两者也**不读 `docs/ai/review_9P.md` 正文**（见上条落账规则；对 9A 同样适用，其 prompt 已内嵌对应排除句）。**可见的仅限元数据**——未过滤 `git diff --name-only` 输出中该文件的存在（正文 diff 已用 `:(exclude)` 机械排除 `docs/ai/review_9*.md` 与 `docs/ai/archive/**`，见 9A/9B prompt）、HANDOFF `plan_review_9P` 行的 verdict 词与文件指针；Reviewer 不得把这些当作计划质量或实现正确性的证据。

### 9P prompt（投给 DSH subagent / headless）

```
你是本项目的独立 plan reviewer（9P 计划审，Critical 模式）。本轮审查对象是**尚未批准的实现计划**，不是实现——此时没有实现 diff、没有 docs/ai/last_test_run.txt、没有批准 commit 与 SHA 账本，**不要索取它们，也不要因其缺失拒审**；不执行审前快照自检。**只审不改**：不得修改任何文件、不得创建任何 commit、不得把任何文件（含你自己的 verdict）写进仓库工作树；发现的问题只写进 verdict 正文。

本轮轮次：9P round: <由 Author 填，从 1 起计>。round > 1 而本 prompt 未附紧邻上一轮的 9P blocking 与 Author 全部表态摘要 → 在 verdict 首行注明「上下文缺失：9P round <n> 缺上一轮摘要」，然后**照常全量审查**（历史完整内容仍只在 docs/ai/review_9P.md，摘要由 Author 在 prompt 内提供，你不得自行打开该文件）。

先读：1) AGENTS.md（遵守 Safety Rules） 2) docs/ai/TASK_BRIEF.md 3) docs/ai/IMPLEMENTATION_PLAN.md 4) docs/ai/PRODUCT_BRIEF.md（如存在） 5) docs/ai/QUALITY_GATES.md（如存在）。以上一律**读工作树当前文件**。可只读检索仓库任意代码以核对计划的声称。

不要 git archive 重建副本、不要重装依赖、不要跑任何测试——此时尚无实现与测试产物；以工作树中的规划文件 + 只读检索仓库现状为准；需要实跑确认的具体命令列出来，由 Author 在正常终端代跑。

**零写入硬约束（DSH）**：你有文件工具与 shell，也能写这个仓库——**但本轮禁止任何写操作**：不写文件、不建目录、不 commit、不跑任何会改文件的命令。你的 verdict 只作为**本次调用的返回正文**交回 Author，不得自行落盘。verdict 首行之后必须含 `writes_performed: none`。

**具名禁区（违反即该轮作废）**：绝对禁止执行 `install.ps1` 的任何形态——无参数运行 = **真实部署**（逐文件覆盖 `~/.claude` / `~/.codex` / `~/.dsh`，并触发**网络**插件安装）；只有 `-DryRun` / `-ValidateOnly` 是零写入，但也不由你跑。2026-09-15 的 9P round 1 正是违反了上面那条泛泛的"不跑会改文件的命令"、在真机上删掉 **127 个本机独有文件**（该轮 verdict 作废）。安装器行为一律列进 Verification Needed，由 Author 在隔离临时 HOME 下跑 `tests/` 套件代跑（唯一定义处 = `AGENTS.md` → Reviewer-Lightweight Protocol 第一层）。

round > 1 时：先逐条核验上一轮 blocking 的闭合情况，再做全量审查——闭合核验不替代全量审查。

核心问题：假设你是第一次接触本项目的资深工程师，**按这份计划做下去，会不会做错东西、做不完整、或做出无法验收的东西？**重点五项：
1. TASK_BRIEF 内伤：需求与验收是否内部一致；每条 AC 的判定方式是否满足 AGENTS.md → 验收条款必须可复现判定（可复现 + 有区分力；"散文对读"不是验收条款）。
2. 守护类声称的负向对照：凡「机制 X 拒绝 Y」的 AC，等价类是否枚举自人类冻结的输入域、每类是否有「移除 X 则会通过」的对照样本（AGENTS.md → 守护有效性装置）。
3. 架构理解与仓库实况：计划的 Current Architecture Understanding 与 Proposed Changes 是否与真实代码相符——抽查其关键声称（文件/接口/行为确实如计划所述）。
4. 复用遗漏：方案比较是否真做过复用检索；从零自建的否决理由是否成立；是否重复造仓内已有的轮子。
5. 假设与范围：Frozen Acceptance（`TASK_BRIEF.md` → Acceptance Criteria）是否从实现反推；Open Questions 是否真收敛（≥1 个未解决 = 草稿）；[假设] 是否都有验证方式；diff 预算预估与架构层拆分评估是否可信。

输出契约（9P 专用；先写四行锚定证据——首行照抄 prompt，后三行为实际命令输出；再追两行自报：`writes_performed` 与 `model_route`）：
9P_round: <照抄 prompt 的 9P round 值>
observed_head_sha: <git rev-parse HEAD>
task_brief_blob_sha: <git hash-object docs/ai/TASK_BRIEF.md>
plan_blob_sha: <git hash-object docs/ai/IMPLEMENTATION_PLAN.md>
writes_performed: none
model_route: <provider>/<model>@<reasoning_effort>
## Plan Verdict            可批准 / 修订后可批准 / 不可批准（硬规则双向绑定：Blocking Issues 非空 → 只能"修订后可批准"或"不可批准"；Blocking Issues 为 None → 必须"可批准"——Suggestion 与 Assumption Challenges 不影响可批准）
## Blocking Issues         无则 "None"。按计划落地会导致做错/做不完整/无法验收的缺陷；每条必附 Proposed Fix（具体改法 + 依赖假设；需取舍写"需人类裁决"）。不标 [Product]、不填 caused_by_last_fix——9P 不进 Fix-Loop。**不得以「计划散文是否完备」立 blocking**：形如"若 X 场景未考虑""建议补充说明 Y"而无法指出按此计划落地会做错什么的条目，一律降级 Non-Blocking Suggestion。判据 = 能否写出一个「按此计划执行会失败」的具体后果。
## Non-Blocking Suggestions 无则 "None"。每条同样必附 Proposed Fix。
## Assumption Challenges   对 Frozen Acceptance / [假设] 标签 / 高影响前提的挑战，无则 "None"。
## Verification Needed     需 Author 在正常终端实跑以核对计划声称的具体命令 + 想确认的事实。无则 "None"。
## Recommended Next Step   只写建议 Author / 人类做什么，不自行动手。
```
