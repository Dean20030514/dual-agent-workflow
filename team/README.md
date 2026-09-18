# Team Mode V1

Codex Lead → `scripts/team.ps1` → DSH native Workers → Git 范围审计 → 外部验证 → 独立 DSH Local Review → Lead 验收 → 独立集成分支。

规格来源：`Codex_DSH_Dynamic_Agent_Team_Final_v5.md`，SHA-256
`69cee29bb2affb98c92d3075d8c0eaa7fa63223f18ca430f488f1efbdab3c6c4`。
先读 [QUICKSTART](QUICKSTART.md)，能力证据与限制见 [spike/OPEN_GAPS.md](spike/OPEN_GAPS.md)。
本轮已执行的测试与真实 Harness 链路见 [验收记录](spike/ACCEPTANCE.md)。
整份 v5 的逐章完成度与剩余缺口见 [范围核对](spike/SPEC_COVERAGE.md)；目前尚未全部完成。

依赖：PowerShell ≥ 7.4、Git、DSH native CLI、Codex native CLI、powershell-yaml ≥ 0.4.12。
YAML 模块由用户在本任务中明确批准；运行器不会安装依赖、修改全局配置或调用部署器。
JSON 是协议文件的规范写出形式（YAML 1.2 子集）；输入支持普通 YAML 与 JSON。
DSH 的正文输出可带普通说明前缀，但必须以唯一、符合 Result schema 的 JSON 对象结束；
多份结构化结果或有歧义的围栏前缀会被拒绝。`result-source.json` 记录提取方式与原始 stdout 哈希，原文保留。

运行模型由 manifest 中逻辑别名解析。默认精确版本 pin；升级先重新运行能力验收再改 pin。
`roles/` 的 19 个模板提供领域能力、默认读写范围、验证建议、升级触发条件和工作指导。
run 会保存角色定义，Worker 的 Task Packet 携带该定义；模板默认值不扩张任务已声明的权限或范围。
Integration 角色只能由记录在案的冲突或集成回归生成，并绑定 conflict/glue scope；它不得更改已批准接口或验收，
只能为集成破坏的有效测试或既有已批准合同适配测试。语义判断仍由 Lead 审核，Git 范围由程序强制检查。
`-AllowUnverifiedRuntime` 只放宽 CLI 版本，不放宽模型路由、协议、范围或审查；运行记录标记 `UNVERIFIED_RUNTIME`。

L0 不建立 run。L1 单 Worker；L2 按 DAG 并行调度；L3 可由 Worker 使用 DSH 原生
`subagent` / `subagent_fork`，每个 Worker 最多两个子 Agent、深度最多 2。
Native guard 在原生 registry 创建前同步预留额度，不调用模型、不替代 Harness。
V1 保守预留整个 Worker 家族的并发槽位，空闲子 Agent 不提前归还槽位，避免并发超发。
`workflow` / `ralph` 在 Team profile overlay 中关闭，避免绕过同一预算入口。

运行目录在目标仓库 `team/runtime/<run-id>`，Worktree 在 `.worktrees/`，分支使用 `codex/` 前缀。
完成只产出集成分支与证据；主分支的发布、推送、合并由目标仓库自己的契约决定。
本 workflow 仓库仍由人类 commit，仍禁止 Agent push/pull/merge；测试仅在临时仓库运行 Git 集成。

返回码：0 成功/已到 Lead 决策点；10 协议错误；20 前置校验/锁失败；30 Worker 失败；
31 超时；40 验证失败；50 审查失败；60 硬停；70 升级；80 恢复冲突；81 集成冲突；
82 越界；90 编排器内部错误。`run` 返回 0 不等于 `COMPLETED`，必须读取 status。

状态、事件、Result Packet 都是普通本地文件，不是对恶意同权限进程的防篡改设施。
实际权限边界见 [security](policies/security.md)。不会以模型自报代替 Git、外部测试或 native 创建记录。

`report-cost -Amount <增量金额> -Evidence <账单文件>` 可在 Worker 运行时提交。
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
