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

运行模型由 manifest 中逻辑别名解析。默认精确版本 pin；升级先重新运行能力验收再改 pin。
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
`-AllowUnverifiedRuntime` 只放宽 CLI 版本，不放宽模型路由、协议、范围或审查；运行记录标记 `UNVERIFIED_RUNTIME`。

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
验证日志仅传每文件前 1,024、合计 4,096 字符摘录，同时给出完整日志大小、SHA-256 和截断标记。
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
cost 输出 schema_version=2 的 ledgers。旧的无单位状态和收据保留原样，不能自动归入任一货币；
旧运行的 status/logs 仍可查阅，继续执行须先明确费用归属和配置，或保留旧运行并另建新 run。
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
