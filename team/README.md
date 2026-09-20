# Team Mode V1

Codex Lead → `scripts/team.ps1` → DSH native Workers → Git 范围审计 → 外部验证 → 独立 DSH Local Review → Lead 验收 → 独立集成分支。

规格来源：`Codex_DSH_Dynamic_Agent_Team_Final_v5.md`，SHA-256
`69cee29bb2affb98c92d3075d8c0eaa7fa63223f18ca430f488f1efbdab3c6c4`。
先读 [QUICKSTART](QUICKSTART.md)，能力证据与限制见 [spike/OPEN_GAPS.md](spike/OPEN_GAPS.md)。
本轮已执行的测试与真实 Harness 链路见 [验收记录](spike/ACCEPTANCE.md)。
v5 的 V1 实现与本机验收已完成，包含人类确认的 L3 适配器扩展；逐章证据及适用边界见
[范围核对](spike/SPEC_COVERAGE.md)。全局共享运行器由仓库安装器部署到 `~/.codex/team/`。

依赖：PowerShell ≥ 7.4、Git、DSH native CLI、Codex native CLI、powershell-yaml ≥ 0.4.12。
YAML 模块由用户在本任务中明确批准；运行器不会安装依赖、修改全局配置或调用部署器。
JSON 是协议文件的规范写出形式（YAML 1.2 子集）；输入支持普通 YAML 与 JSON。
DSH 的正文输出可带普通说明前缀，但必须以唯一、符合 Result schema 的 JSON 对象结束；
多份结构化结果或有歧义的围栏前缀会被拒绝。`result-source.json` 记录提取方式与原始 stdout 哈希，原文保留。

运行模型由 manifest 中逻辑别名解析。`runtime.codex_version` / `dsh_version` 保留为历史验收基线，
不再仅因安装版本不同就拒绝；doctor 的 `version_drift` / `warnings` 如实记录差异。
Codex 每次检查实际 `exec --help` 是否保留隔离、只读 sandbox、结构化输出等所需接口；
即使版本与基线相同，接口缺失也拒绝。此检查不调用模型，不等于完成了一次真实独立审查。
DSH 仍须匹配安装版本、profile、模型和 native guard 的 `certifications/` 验收证据；
已验收的新版本可直接使用，不必逐个修改项目 manifest。尚无证据的新版本明确报告缺失验收，
不能仅修改版本号或凭 `--help` 就继承原生工具隔离、退出语义或 L3 的已验证结论。
Claude Code 没有精确版本 pin；doctor 对已安装的 Claude 做可选的版本/CLI 接口检查，
不检查订阅、不调用模型，也不使其成为 Codex + DSH Team 的运行依赖。
`cli_checks` 区分本地接口、原生验收证据和未测试的模型访问；版本变化且兼容检查通过时，
`runtime_status=COMPATIBILITY_CHECKED`。无变化保留历史状态名 `PINNED_RUNTIME`，
它不表示三端在线验收全部通过。失败为 `INCOMPATIBLE_RUNTIME`，旧运行记录不回写。
doctor 和执行/验收入口读取 `CODEX_THREAD_ID` 对应的当前活动轮次元数据，核对 Lead 实际模型。
缺少活动轮次、模型不符或只有已结束轮次时返回 20；`-AllowUnverifiedRuntime` 不绕过此检查。
这是本地 Harness 证据，不是服务端模型证明或对同权限进程的防篡改保证。
在普通终端可通过 `scripts/team-lead.ps1 -Repo <项目>` 显式选择 manifest 模型启动 Codex，
再由该活动会话执行 Team。单纯启动参数、manifest 或 config.toml 不算运行证明。
`roles/` 的 19 个模板提供领域能力、默认读写范围、验证建议、升级触发条件和工作指导。
run 会保存角色定义，Worker 的 Task Packet 携带该定义；模板默认值不扩张任务已声明的权限或范围。
Plan 可用 `dynamic_roles: {角色ID: 完整角色定义}` 定义本次运行的临时角色，并在 task.role 引用。
须启用 manifest 的 dynamic_roles；禁止覆盖内置角色。同名角色跨 revision 不可改定义，变更须用新 ID，
旧定义及任务包保留。此项是审计后授权增加的能力，原文 18–19 节列举默认模板及角色 schema。
Integration 角色只能由记录在案的冲突或集成回归生成，并绑定 conflict/glue scope；它不得更改已批准接口或验收，
只能为集成破坏的有效测试或既有已批准合同适配测试。语义判断仍由 Lead 审核，Git 范围由程序强制检查。
`-AllowUnverifiedRuntime` 保留为显式的未验收 DSH L1/L2 调试入口，记录 `UNVERIFIED_RUNTIME`，
不授予 L3，不放宽 Codex 必需接口、模型路由、协议、范围或审查；正常升级无需添加该参数。

L0 不建立 run。L1 单 Worker；L2 按 DAG 并行调度；L3 可由 Worker 使用 DSH 原生
`subagent` / `subagent_fork`，每个 Worker 最多两个子 Agent、深度最多 2。
Native guard 在原生 registry 创建前同步预留额度，不调用模型、不替代 Harness。
Plan 的最低 Agent 需求按每个必需任务的作者和 Local Reviewer 共 2 个计算，
依赖链中必需的 optional 前置任务同样计入。默认总额 10 最多容纳 5 个必需任务的首次执行；
重试和子 Agent 另耗额度。派发与 replan 还会核对已花费、已预留和剩余必需审查，
先缩减可选 fan-out，再跳过会挤占必需额度的 optional 任务。被跳过的任务仍须显式 replan 处置。
V1 保守预留整个 Worker 家族的并发槽位，空闲子 Agent 不提前归还槽位，避免并发超发。
`workflow` / `ralph` 在 Team profile overlay 中关闭，避免绕过同一预算入口。

运行目录在目标仓库 `team/runtime/<run-id>`，Worktree 在 `.worktrees/`，分支使用 `codex/` 前缀。
完成只产出集成分支与证据；主分支的发布、推送、合并由目标仓库自己的契约决定。
本 workflow 仓库仍由人类 commit，仍禁止 Agent push/pull/merge；测试仅在临时仓库运行 Git 集成。

审查规则冻结在 run 基线提交的 `authority.json`，涵盖根/嵌套 AGENTS、AGENTS.override、
`team/manifest.yaml` 和 `team/policies/`，以哈希绑定 state 与 verdict。待审 diff 中的规则改动
不能成为其自身的审查依据；实际修改这些治理文件的 Routine 任务也须 fresh 9A，分类仍保持 Routine。
Worker risks 以待核实声明传给 Local/9A/9B，不传作者聊天或推理。
Local/9A/9B 的 prompt 额外携带：机器派生的变更统计（`git diff --numstat --no-renames`，
含二进制标记）、任务 issue-to-acceptance 映射、结构化命令结果摘要（每条命令的退出码、
超时种类、是否复用、stdout/stderr 字节数与哈希），以及每条命令的有界头尾摘录。
其中 issue 原文只来自任务自己的 objective/acceptance，运行器**不发明** issue 文本；
可选的结构化映射由作者声明，缺省即视为空（旧任务包照常工作）。
被测 diff 始终完整生成并给出 `diff_bytes`，不截断、不豁免。
原始审查 holding 位于 `$CODEX_HOME/team-review-holding/`（默认 `~/.codex/team-review-holding/`），
按项目/run/attempt 隔离；prompt 和 verdict 另封存在运行目录 `reviews/archives/`，
accept 以封存哈希为准，不依赖系统临时目录。`reviews/evidence/` 保留给独立补证执行。
未含冻结规则/封存证据的旧 run 可查询，但不能自动继承为新审查通过，须保留现场并另建明确计划的 run。

DSH 短任务沿用 I1 命令行输入；超过 `max_dsh_prompt_chars`（默认 24,000 UTF-16 单元）时，
适配器把完整提示词写入运行专属 JSON patch，通过原生 `headless-runner.config.task` 传入。
命令行仅携带 patch 路径；不要求模型读取文件，不开放审查工具，也不截断规则或 diff。
`input-transport.json` 记录方式、字符数、UTF-8 字节数和提示词 SHA-256。原生端到端证据见
[长输入传输验收](spike/LONG_INPUT_TRANSPORT.md)。这是适配器扩展，不声称 DSH CLI 新增了文件参数。
Windows 启动长度检查仍保留。完整提示词继续受 `max_review_input_bytes` 限制（默认 4,000,000 字节），
审查 diff 继续受 `max_diff_bytes` 限制（默认 2,000,000 字节）；超限仍返回 70 / `input_too_large`。
验证日志按命令各得一份**头尾两段**摘录（每文件预算均分，合计不超过上限），同时给出完整日志大小、
SHA-256、已覆盖字节数、省略字节数和截断标记；单条超大日志不再挤掉其后的命令。
`Get-TeamReviewOutput` 保持 JSON 数组形状，旧调用方仍可按 `file/bytes/sha256/excerpt/truncated` 读取。
三个 runtime 配置项均有兼容默认值；`max_dsh_prompt_chars` 现在是切换文件传输的阈值，
`max_review_input_bytes` 同时约束 Worker 与 Reviewer 的完整原生输入。旧项目无需修改 manifest。

`certifications/*.json` 登记精确版本/profile/provider/model、I/O/E 轴、guard 哈希和历史验收索引；
doctor 从记录准入，不硬编码版本元组。更换 native guard 后须重验并更新记录，版本 pin 本身不构成认证。
该记录是本地可审计登记，不是服务端证明，也不会自动重跑付费模型。
新 Task Packet 使用逻辑 `result_schema: result-v1` 与 `result_schema_sha256`，
适配器核对共享运行器的实际 schema；历史无哈希 Packet 仍可读取。
watch 使用文件字节偏移读取新增事件，保留跨读取边界的 UTF-8 字符和未结束行。

返回码：0 成功/已到 Lead 决策点；10 协议错误；20 前置校验/锁失败；30 Worker 失败；
31 超时；40 验证失败；50 审查失败；60 硬停；70 升级；80 恢复冲突；81 集成冲突；
82 越界；90 编排器内部错误。`run` 返回 0 不等于 `COMPLETED`，必须读取 status。

状态、事件、Result Packet 都是普通本地文件，不是对恶意同权限进程的防篡改设施。
实际权限边界见 [security](policies/security.md)。不会以模型自报代替 Git、外部测试或 native 创建记录。

`report-cost -Ledger deepseek -Unit USD -Source <账单来源> -Amount <增量金额> -Evidence <账单文件>` 可在 Worker 运行时提交。
另一个账本为 `-Ledger astra -Unit credits`，两者分别设软/硬阈值 10/20，不进行换算或合计。
cost 输出 schema_version=3 的 ledgers，并附带只读 `summary`（观测到的作者/审查者计数、预留、
基础设施与语义尝试分类、验证执行/复用、已知与未知用量）。旧的无单位状态和收据保留原样，
不能自动归入任一货币；旧运行的 status/logs 仍可查阅，继续执行须先明确费用归属和配置，
或保留旧运行并另建新 run。`summary` 里的 `unknown_usage=true` 只表示"账单不完整"，
不会被表述为零成本或提速。
同一证据哈希只接收一次；QUEUED 表示凭证已持久保存、等待 coordinator 消费，
RECORDED 表示 state 已更新。软上限阻止 optional Worker 和新增原生子 Agent；
硬上限暂停后续派发；已运行 Worker 继续完成。`unknown_usage=true` 仍表示账单不完整。
restricted_action 的 approve 只对记录中的 plan hash 有效；modify-plan 必须实际修改计划，
新增权限不会沿用旧审批。升级过期后保持暂停，等待明确决定。

run 的 `-Repo` 必须是主仓库根目录；linked worktree 不能独立拥有另一个 run 锁。
resume 会检查事件记录、计划/状态图、所有已创建 worktree 的分支与 base、
集成 checkpoint，以及 adapter/native 的 PID 和启动时间。原 Worker 尚存活时返回 80，
等它写出 durable exit receipt 后再恢复；不会盲目创建第二个 Worker。
事件截断、状态损坏或集成 HEAD 偏移会保留证据并拒绝派发，须先协调或 rollback。
集成先保存操作意图，再合并和验证；恢复时核对确切父提交、任务 attempt 和证据哈希，
补齐中断的 checkpoint/state 写入，不重复合并、不用新验证覆盖已知失败。
计划修订将旧计划、新计划、状态与决定暂存并记录哈希；持锁命令先重放未完成事务，
外部修改或缺失证据返回 80。回滚也保存整批检查点与逐次撤销收据，
`rollback` 或 `resume` 可接续已授权的中断回滚；任务进入 REWORK 后仍须明确 replan。
恢复遇到不属于事务的提交或脏文件时保留现场，禁止自动覆盖。

## 活动观测：idle 期限只跟随真实改动（2026-09-18）

只在 stdout 上计算 idle 会杀掉"安静但确实在改文件"的作者。适配器等待与协调器等待（以及
只读的 Local Reviewer 等待）现在都接同一套有界观测：

* 指纹来自 `git status --porcelain=v1 -z --untracked-files=all`，路径按 NUL 原样解析，
  因此中文、含空格、含引号以及重命名条目都不会被误读；
* 每条变更路径绑定**有界内容 SHA-256**（每文件上限 256 KiB、单轮合计上限 4 MiB、最多 64 条路径），
  长度与已哈希字节数一并入指纹。**不再使用 mtime**：把一个已经 dirty 的文件重新 touch 一遍
  不会延长 idle；文件被并发写入时的短暂共享冲突会重试，不会让整次观测失败；
* `node_modules/`、`team/runtime/`、`.worktrees/`、`.git/` 等依赖/运行时/日志循环被排除，
  不计为创作活动；原生进程增删只作为证据记录，**本身不延长 idle**；
* 超过上限时明确标记 `truncated` 并报告 `changed_files`/`hashed_files`/`unhashed_files`；
* `activity.json` 保存协调器观测到的最近活动种类与时间、原生进程集合与错误；适配器在
  `activity-adapter.json` 写自己的观测（两个写者不会互相覆盖结论），`exit.json` 只报告
  适配器自己看到的活动。停止原因区分 `hard`（总超时）/`idle`（空闲）/`output`（输出上限）
  /`drain`，并写入 `exit.json`。仍然没有盲目自动重试。

## 验证复用：显式 opt-in 且绑定环境（2026-09-18）

默认仍然每条命令都真实执行。只有显式开启后才查缓存：

```powershell
pwsh -NoProfile -File ./team/scripts/team.ps1 run -Plan <plan> -Repo <repo> -ReuseVerification -Json
pwsh -NoProfile -File ./team/scripts/team.ps1 resume -Run <run-id> -Repo <repo> -ReuseVerification -Json
# resume 上可用 -ReuseVerification:$false 关闭；一旦显式设置即按 run 粘滞保存
```

命中要求**同时**满足：精确源码树与 HEAD（tracked 有脏改动即拒绝）、完整命令与参数、
工作目录、工具身份（可执行文件或 pwsh + 脚本的**内容哈希**，不是大小+mtime）、
调用方声明的 `environment_fingerprint`，以及调用方声明的 `input_artifacts` 哈希、
成功退出码与完好的 stdout/stderr 收据。命令可用 `environment_fingerprint` 与
`input_artifacts` 声明依赖（schema 已支持）；缺少声明即不复用。缺失/变更的键、旧格式收据、
脏源码、失败、被篡改的收据、未 opt-in 一律重新真实执行，并在证据里记录
`reuse_rejected` 原因。SHA 未变**不代表**数据库或外部服务未变，所以环境指纹必须由调用方声明。
**发布也要复核绑定**：命令退出 0 之后会重新计算一次源码/工具/输入/环境绑定，只有与执行前
完全一致才写入收据；命令自己改了 tracked 源码、声明输入或工具内容时，记为
`reuse_publish_rejected=binding_drift:*` 并保留完整命令证据，绝不把它当成可复用的成功。
命中还会核对收据自身的一致性（`key` 必须等于其 `material` 的哈希）；被旧版本写下的收据
会被改名保留而不是覆盖，也永远不会被当作命中。
每次尝试的日志都保留（重名自动加 `-rN` 后缀），失败与被取代的尝试不会被覆盖。

## 复用准入：先找轮子（2026-09-19）

语义与字段形状的唯一规范来源是仓内 `core/reuse/`（README + `reuse.schema.json` + 纯校验器
`Reuse.ps1`）。Team 侧只引用、不复制规则，适配器是**一个**有界模块
`team/scripts/PriorArt.ps1`；它按 `team/scripts` 的固定位置解析协议
（源仓同级 `core/reuse`，安装副本同级 `workflow-core/reuse`），**从不**读调用方工作目录或
个人绝对路径。协议文件缺失时只有需要准入的命令失败，`status`/`logs`/`cost`/`result`/
`escalations`/`stop`/`cleanup` 等只读与收尾路径照常可用。

* **新计划必须带复用文档**：顶层 `reuse`（decision）+ 每个 task 的 `reuse`（task 声明），
  `Test-TeamPlanContent` 逐条用 `core/reuse` 校验。缺任何一条都在 `validate`/`run`/`replan`
  阶段以 10 明确拒绝，**不会**静默派发一个没有先例检索结论的计划；
* **新 run 冻结协议身份**：`New-TeamRun` 把 `version` + 三文件确定性哈希 + 逐文件 sha256/字节数
  写进 `state.reuse_protocol`，并把 README/schema/validator 复制到
  `team/runtime/<run>/reuse-protocol/`。`resume`/`replan`/`repair-integration`/`recover`/
  `accept`/`integrate` 与真正的派发点都会重新核对：冻结副本未被改动、且当前可用协议与冻结
  身份一致。任一不符即 80 并提示**开新 run**，绝不把旧检索结论搬过一条已经改变的协议；
* **blocked 决策在作者之前暂停**：任一检索 `unavailable` ⇒ 决策只能 `blocked`。首派、resume、
  重规划、集成修复与恢复路径都会在**前置条件、worktree、worker**之前停下，并登记既有升级机制
  中的一条 `reuse_unavailable`（只创建 run 元数据与升级记录）。恢复**只**接受 owner 对
  **确切 plan hash** 的显式 `resolve ... -Decision approve -Reason ...`；reject、过期（24h）、
  哈希不匹配或身份不匹配的批准一律不通过，且不会自动产生任何批准；
* **replan 使例外失效**：批准绑定单一 plan hash，新修订必须重新取得批准；同时顶层决策或任务
  声明的变化会让相关任务进入 `affected`（即使文件范围未变），其推断与审查证据一并作废。
  仍为 `blocked` 的新修订会重新登记暂停，而不是继承旧批准；
* **集成修复任务不得自带 blanket skip**：`repair-integration` 生成的 task 继承嫌疑任务的
  声明（冲突修复继承冲突来源，回归修复要求所有来源声明一致），不一致或缺失时要求显式 replan；
* **派发内容有界**：worker 收到由 `Get-ReuseContext` 派生的 `reuse_context`（身份、plan hash、
  决策字段、任务声明、仅本任务引用的候选摘要；**不含**检索日志与决策级 reason/rationale）。
  带 `reuse_context` 的 Result **必须**返回 `reuse`（`references_used` / `deviations`）：
  未知引用、任务外引用、被规定却未使用且没有同名 deviation 解释，都会在验收前被拒；
* **审查面**：LOCAL 与 9A 拿到有界决策字段 + 任务声明（含任务级 `reason`）+ 被引用候选的来源事实
  （`id`/`url`/`revision`/`borrow`/`constraints`）+ worker 声明的真实使用；9B **只**拿冻结 constraints、实际使用
  引用的来源事实（`id`/`url`/`revision`/`constraints`）与实际使用声明——计划级 `reason`/`rationale`/`strategy`、
  候选 rationale、检索日志、未被使用的候选以及 deviation 的自由文字都被显式剥离；9P 直接审阅计划文件本身（含完整
  决策），不再声称「本阶段没有复用决策」；
* **只读汇总**：`status`/`cost` 的 `summary.reuse` 给出协议身份、决策、owner 例外与每个任务
  的 usage 声明，全部按「worker 声明」呈现。适配器**不重放检索、不伪造遥测**、不声称某次
  检索真的发生过；
* **历史 run**：没有 `reuse_protocol` 标记的旧 run 依旧可读、可 stop、可 cleanup，但
  `resume`/`replan`/`repair-integration`/`recover`/`accept`/`integrate` 一律以 80 明确要求
  **新计划 + 新 run**，不补造任何历史收据。

## 前置条件：零作者准入门（2026-09-18）

Plan 可选声明 `prerequisites`（命令 + 可选 `restore`）。`run` 与 `resume` 在**任何** worker 或
worktree 被准入之前执行它们：

* 失败即返回 40，**不启动任何作者**，并保留退出码、stdout/stderr 与哈希；
* 声明了 `restore` 的前置失败会先执行一次回滚并同时保留两份收据；
* 同一 `plan_hash` 下通过的结果可复用，改变了计划哈希则重新执行；
* 重跑不覆盖此前的失败记录：`prerequisites.json` 累计 `attempts`；
* `team.ps1 prerequisites -Run <id> [-Restore -Reason ...]` 只读预览 / 显式恢复，恢复不改写失败结论。

不声明 `prerequisites` 的**旧计划**读取为空列表（不是含一个 `$null` 的列表），行为与从前一致。
运行器不假设存在数据库或服务，也不重启服务；共享业务不变量与依赖应写进 task 的
objective/acceptance —— 文件范围不重叠并不证明任务相互独立。

## 归档与 finalize：先证明可恢复，再精确删除（2026-09-18）

`finalize` 默认只预览，`-Apply` 才动手；只处理本 run 拥有的 worktree 与分支：

```powershell
pwsh -NoProfile -File ./team/scripts/team.ps1 finalize -Run <run-id> -Repo <repo> -Json
pwsh -NoProfile -File ./team/scripts/team.ps1 finalize -Run <run-id> -Repo <repo> -Apply -Json
```

* 覆盖当前与已丢弃的 worker attempt、以及集成 worktree/分支；仅在 run 处于
  `COMPLETED`/`CANCELLED`/`FAILED` 时才允许 `-Apply`；同一路径/分支/attempt 的
  「当前指针 + 已退休副本」会按已验证身份去重，只处理一次（别名照实报告）；
* 每个目标先写入**已校验的 git bundle**（必需 ref）、二进制 staged/unstaged patch、
  已跟踪及未跟踪/被忽略文件的实际字节（逐文件哈希）、换行配置与恢复配方；完整文件清单
  限 20,000 项/512 MiB，超出则保留。暂存与未暂存补丁由 Git 直接写出，保留 CRLF；含目录联接
  （junction）时按**描述符**归档，绝不穿越；
* 随后在**隔离临时仓库**里真正恢复并比对 worktree 状态；证明不通过就**保留**该目标
  （`preserved=true`，附原因），不删除、不删 ref；
* 精确比对通过后用 `git worktree remove`（逐命令 `-c core.longpaths=true`）与
  compare-and-delete 删除 ref；`main`、无关 ref/worktree、run 原始证据与草稿均保留；
* 删除**不是原子的**：`git worktree remove` 会先注销再删文件，Windows 上可能留下残树
  （`cleanup` 命令、已退休 attempt 也可能留下同形状的目录）。这种「目录在、Git 已注销、
  没有阶段收据」的残留不会被当成外来目录拒绝，也不会被当成完整 worktree：它按本 run
  的目录名与分支绑定收编为 residue，`origin_proven=false` 明示原始 Git 状态未知——
  **不推断**缺失的原始状态，只按文件系统清点、归档并在临时目录证明可恢复，然后
  **逐个比对哈希后删除**（哈希不符或未归档的内容一律保留并报告）；
* 某个目标无法安全归档（越界路径、大小写不符、不支持的链接、清单变化、HEAD 偏移）时，
  `-Apply` 只拒绝该目标并继续处理其他安全目标，结果逐条给出 `failed`/`preserved` 与原因，
  整体 `outcome=partial`；**只有目录被证实消失才报告 removed**，残留与失败会在下次
  `-Apply` 继续，绝不声称"残树已全部清除"；
* 活的 run-owned 进程、未知归属的 PID/start、未结算的子进程清理会**整体拒绝** finalize
  （不仅凭状态或 `streams_settled` 判定静默）；同一 attempt 的适配器、原生、Local Reviewer
  与集成审查记录都会被枚举，废弃 attempt 按它自己的收据读取，不借用同名 task 现在的 PID；
* `cleanup` 命令在 `git worktree remove` 之后重新检查目录；目录仍在时
  `worktree_removed=false` 并记录 `directory_removal_pending`，不会谎报已删除。

Lead 对真实项目 worktree 的归档清理由 Lead 另行决定与执行；本仓库测试只在隔离临时仓库运行。

## 基础设施恢复 vs 业务 replan（2026-09-18）

`recover -Run <id> -Task <id> -Reason ...` 只对**有据可依**的 transport/start/idle 失败生效，
并要求 Lead 证据与协调器锁：

* 合格性来自持久化证据（`exit.json` 的 `timeout_kind`/`startup_exhausted`/settled streams、
  已记录的 `infra_kind`）。验证失败、业务失败、审查失败、范围违规**不会**被改标成基础设施；
* `hard`（总超时）与 `output`（输出溢出）仍算**基础设施类**尝试，但**不可自动恢复**：
  界限已经触达，必须由 owner 决定；只有 transport/start/idle 有这条有界恢复路径；
* 恢复前先按持久证据判定合格性，被拒绝的恢复**不会**改动预留；进入恢复前要求该 attempt 的
  预留已被证明结算（适配器/原生/Local Reviewer/子进程清理全部静默），否则保留为未知并拒绝
  双计，绝不因为 `streams_settled=true` 或状态是终态就释放/记账；
* 恢复不改变已批准的任务语义，**不消耗语义 replan 计数**（`replans` 不变，另有 `infra_retries`），
  但仍受既有 worker attempt、agent、成本与重复失败升级上限约束；
* 先前的 attempt 以 `retire_kind=infrastructure` 退休归档，worktree、分支与脏内容留在原处，
  **不会被静默当成新基线**；恢复记录落在 `recovery/<id>.json`；
* `resume` 会先按已结算的 owned-process/native 证据对账终端预留，无法证实的一律保留为未知；
* 读取（`status`/`cost`/`logs`）永不自动改写历史 run。

## 状态与账目（2026-09-18）

`status` 与 `cost` 的 `summary` 区分**派发意图**与**观测事实**：
`authors_dispatched_intents`（派发次数）与 `authors_observed`/`author_agents_observed`/
`author_children_observed`（来自 `tasks/*/attempt-*/agents.json` 的真实原生创建收据，含已退休
与已重规划 attempt）分别报告；`local_reviewers_started` 只统计有原生收据的审查者，
仍处于 `PREPARING` 的记录计入 `local_reviewers_preparing` 而**不算已启动**。
基础设施与语义尝试分列（`attempts.infrastructure` / `attempts.semantic`），其中
`attempts.infrastructure_recoverable`（transport/start/idle）与
`attempts.infrastructure_nonrecoverable`（hard/output，需 owner 决定）分开报告；
`semantic_replans` 与 `infrastructure_recovery` 各自计数，验证执行数与复用数分列。
`summary.reuse` 汇总冻结协议身份、计划级决策、owner 例外与各任务的 usage 声明（均按
worker 声明呈现，不重放检索、不伪造遥测；旧 run 报告 `status=unavailable`）。
已知费用只等于已单独录入的账单之和；未记录的部分保持"未知"，不声称零成本或提速。

`preview -Plan <plan> -Repo <repo>` 是只读估算：按 HEAD 事实给出每个 task 的范围文件数、
验证命令数、评审固定输入字节下限，以及所需作者+审查者 agent 下限与预算是否装得下。
它是下界，不是被审输入；真实 diff 仍然完整生成、完整计数，不截断、不豁免。

测试：

```powershell
$c = New-PesterConfiguration
$c.Run.Path = 'team/tests'
$c.Run.Exit = $true
$c.TestResult.Enabled = $false
Invoke-Pester -Configuration $c
node --test team/tests/native-guard.test.mjs
```

`tests/fixtures` 是隔离测试用替身，仅测试脚本会把它加入自身 PATH；生产入口没有 mock 开关。
不要把该目录加入日常 PATH。真实 Harness 冒烟与替身接线验收分别记载。
