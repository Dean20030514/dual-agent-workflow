# Codex Lead + DSH Workers + Dynamic Agent Team + Native Sub-Agent
## 最终完整架构方案 v5.0
### Production-Oriented Architecture + Team Mode Protocol + Implementation Semantics

> **状态**：Final v5.0  
> **用途**：作为 `dual-agent-workflow` 下一代 Team Mode 的正式架构规范、协议规范、实施语义、验收基线与运维参考。  
> **核心目标**：以 **GPT-6 Astra + Codex 原生 Harness** 作为自主 Team Lead，以 **DeepSeek V4.1 Flash + DSH 原生 Harness** 作为动态 Worker Pool；Worker 内部按需创建 **DSH Native Sub Agent**；所有写入型 Worker 使用 **Git Worktree 隔离**；普通开发默认全自动，仅在高风险、不可逆、生产级、无法自动恢复等场景升级给人类。
>
> **模型名称说明**：`gpt-6-astra` 与 `deepseek-v4.1-flash` 通过逻辑别名绑定，实际实施时由 Preflight 验证当前环境真实可用的模型标识；架构逻辑不得硬编码具体小版本号。
>
> **融合基础**：现有 `dual-agent-workflow`。  
> **继续复用**：Routine/Critical、9P/9A/9B、Fresh Reviewer、Hard-stop、Evidence、Debt、独立审查、验证优先。  
> **新增能力**：自动路由、动态 Worker、Native Sub Agent、Worktree、Thin Orchestrator、结构化跨 Harness 协议、恢复、回滚、可观测性、预算、失败目录、协议实施语义。

---

# 0. 一句话结论

> **Astra 决定“是否组队、谁来做、怎么拆、是否接受”；DSH Worker 决定“内部是否需要 Sub Agent”；Thin Orchestrator 只负责进程、Worktree、状态、协议、验证、Integration、Recovery；Git/Test/Evidence 负责证明结果；普通任务不需要人类批准，只有高风险、不可逆、连续失败或无法恢复时升级给人类。**

---

# 1. 最终架构

```text
                                   USER
                                    │
                                    ▼
                         GPT-6 Astra / Codex
                      AUTONOMOUS TEAM LEAD
                                    │
                    ┌───────────────┴───────────────┐
                    │                               │
               Mode Selection                  Team Planning
              L0 / L1 / L2 / L3             Capability + DAG
                    │                               │
                    └───────────────┬───────────────┘
                                    ▼
                            Thin Orchestrator
                     PowerShell V1 / Service V2+
                       （执行机构，不是大脑）
                                    │
             ┌──────────────────────┼──────────────────────┐
             │                      │                      │
             ▼                      ▼                      ▼
      Dynamic DSH Worker     Dynamic DSH Worker     Dynamic DSH Worker
     DeepSeek V4.1 Flash    DeepSeek V4.1 Flash    DeepSeek V4.1 Flash
        DSH Native             DSH Native              DSH Native
             │                      │                      │
       ┌─────┴─────┐          ┌─────┴─────┐          ┌─────┴─────┐
       ▼           ▼          ▼           ▼          ▼           ▼
   DSH Sub      DSH Sub    DSH Sub      DSH Sub   DSH Sub      DSH Sub
    Agent        Agent      Agent        Agent     Agent        Agent
             │                      │                      │
             └──────────────────────┼──────────────────────┘
                                    ▼
                          Deterministic Verification
                      test / lint / build / typecheck
                                    │
                                    ▼
                              DSH Local Review
                                    │
                                    ▼
                              Astra Lead Review
                                    │
                      ┌─────────────┴─────────────┐
                      │                           │
                    ACCEPT                      REPLAN
                      │                           │
                      ▼                           └────→ affected subgraph
                Integration Branch
                      │
                      ▼
                Full Regression
                      │
                      ▼
                Fresh Final Review
                      │
                      ▼
                    Deliver
```

异常旁路：

```text
Human Escalation
      ▲
      │
仅用于：
- destructive
- production
- secrets
- financial
- legal/compliance owner decision
- mutually exclusive business ambiguity
- repeated autonomous failure
- unrecoverable repository integrity problem
```

---

# 2. 目标与非目标

## 2.1 目标

1. 用户正常描述任务，不必说“启动 Team”。
2. Codex 自动判断 L0/L1/L2/L3。
3. 小任务不组队。
4. 复杂任务按 capability 动态组队。
5. Worker 自主决定是否 fan-out DSH Native Sub Agent。
6. 每个写入 Worker 拥有独立 Worktree。
7. Agent 间使用结构化协议，不传完整对话历史。
8. Astra 主要做高价值判断，不承担低价值 bulk coding。
9. 普通开发无需人类审批。
10. Critical 保持独立审查。
11. 系统可恢复、可回滚、可观察、可限额。
12. 复用现有 `dual-agent-workflow`，避免重复实现。
13. 所有“完成”必须由 Git/Test/CI/Schema/Evidence 证明。

## 2.2 非目标

V1 不做：

- 自研 LLM Runtime；
- 自研 Codex/DSH Harness；
- Web 控制台；
- Kubernetes；
- multi-machine scheduler；
- message broker；
- universal Agent OS；
- LangGraph/AutoGen 作为核心控制面；
- 任意深度递归 Agent；
- 把 Native Harness 降级成裸 API。

---

# 3. 核心原则

## 3.1 Native Harness First

```text
GPT-6 Astra
→ Codex Native Harness

DeepSeek V4.1 Flash
→ DSH Native Harness
```

## 3.2 两级自治

```text
Astra Lead
→ 选择 Worker

DSH Worker
→ 选择 Sub Agent
```

## 3.3 Thin Orchestrator

```text
Astra = Brain
Orchestrator = Machinery
```

## 3.4 Ground Truth

优先级：

```text
1. Git state / diff
2. Test / build / lint / typecheck
3. Schema validation
4. Evidence artifacts
5. Structured Result Packet
6. Raw model claims
```

---

# 4. 系统角色

## User

- Goal Owner
- Exception Controller

## Astra / Codex Team Lead

- understand
- route
- plan
- assign
- review
- arbitrate
- replan
- integrate
- accept

## Thin Orchestrator

- create
- start
- wait
- timeout
- validate
- merge
- recover
- cleanup

## DSH Worker

- domain execution
- worker-local planning
- native subagents
- self-check
- result packaging

## Fresh Reviewer

- independent 9P/9A/9B
- read-only by default
- fresh context

---

# 5. 模型与版本绑定

模型逻辑别名：

```yaml
schema_version: 1

models:
  lead:
    alias: astra-lead
    harness: codex
    provider: openai
    runtime_model: gpt-6-astra

  worker:
    alias: deepseek-worker
    harness: dsh
    provider: deepseek
    runtime_model: deepseek-v4.1-flash
```

版本记录：

`team/spike/VERIFIED_VERSIONS.md`

示例：

```yaml
verified:
  codex:
    version: 0.x.y
    min: 0.x.y
    max_exclusive: 0.y.0

  dsh:
    version: 0.x.y
    min: 0.x.y
    max_exclusive: 0.y.0

  powershell:
    version: 7.x

  worker_model:
    id: deepseek-v4.1-flash

  lead_model:
    id: gpt-6-astra
```

默认：

```text
reject_if_version_outside_verified_range = true
```

如果用户显式选择 override：

必须记录：

```text
UNVERIFIED_RUNTIME
```

---

# 6. dual-agent-workflow 定位

`dual-agent-workflow` 继续作为：

```text
Quality Discipline
Review Discipline
Evidence Discipline
Harness Rules
```

Team Mode 只是新增运行模式。

原则：

> **复用真实规则路径，不复制“猜测版”规则。**

---

# 7. Phase 0 Capability Spike

正式实现前验证：

## DSH

- headless
- prompt file
- stdin
- CLI arg
- output file
- stdout
- structured JSON/YAML
- TUI-only behavior
- exit code stability
- model routing
- profile
- subagent
- subagent_fork
- workflow
- cwd
- network behavior
- environment inheritance
- timeout
- process termination

## Codex

- AGENTS.md loading
- shell invocation
- PowerShell
- local script invocation
- long-running command
- fresh session
- review context
- worktree compatibility
- JSON/YAML generation
- repo policy compliance

输出：

```text
team/spike/
├─ DSH_CAPABILITY_MATRIX.md
├─ CODEX_CAPABILITY_MATRIX.md
├─ DSH_COMMANDS_VERIFIED.md
├─ CODEX_COMMANDS_VERIFIED.md
├─ VERIFIED_VERSIONS.md
├─ EXISTING_INTEGRATION_MAP.md
├─ INTEGRATION_DECISION.md
└─ OPEN_GAPS.md
```

---

# 8. Phase 0 二维能力矩阵

不再简单使用“有/无 headless”。

分为两个轴。

## 8.1 Input Axis

```text
I3 = structured file
I2 = prompt file
I1 = stdin / CLI arg
I0 = interactive only
```

## 8.2 Output Axis

```text
O4 = structured result file
O3 = machine-readable stdout
O2 = plain stdout
O1 = TUI output, parseable
O0 = TUI-only / unstable
```

## 8.3 Exit Axis

额外记录：

```text
E2 = stable exit code
E1 = partially stable
E0 = unreliable
```

---

# 9. Phase 0 能力组合决策表

| Input | Output | Exit | 允许模式 | 动作 |
|---|---|---|---|---|
| I3/I2 | O4/O3 | E2 | L1/L2/L3 | 全功能 |
| I3/I2 | O2 | E2 | L1/L2 | Adapter 负责结构化 Result |
| I1 | O3/O2 | E2 | L1/L2 | Adapter 负责输入输出封装 |
| I1 | O1 | E1/E2 | 实验性 L1 | 先稳定 Adapter |
| I0 | O2/O1 | E1 | 不进入正式 Team | 评估脚本化交互 |
| I0 | O0 | E0 | L0 only | Team Mode 暂停 |
| 任意 | 任意 | model route 不可验证 | 禁止 dispatch | Fail Closed |
| Native Sub Agent 不可用 | 任意 | 任意 | L1/L2 | L3 disabled |
| Native Sub Agent 可用但不可观测 | 任意 | 任意 | L3 limited | Result Packet 强制汇总 |

原则：

> **不允许为了“凑齐 L3”而绕过 DSH Native Harness。**

---

# 10. 四级执行模式

## L0 — Direct Codex

小、低风险、单点。

## L1 — Single DSH Worker

单领域、明显工作量、不值得并行。

## L2 — Multi-Worker Team

多领域、可并行、可独立验证。

## L3 — Team + Native Sub Agents

大型、Critical、research/architecture-heavy。

---

# 11. Codex 自动路由机制

使用四层：

1. `AGENTS.md`
2. `team/manifest.yaml`
3. `team.ps1`
4. machine-readable `plan.yaml`

进入 L1-L3：

必须有合法 Team Plan。

---

# 12. team.ps1 route 的明确语义

V1：

> **`team.ps1 route` 不调用 LLM。**

它是纯本地辅助判断器。

输入：

```powershell
team.ps1 route -TaskText "..."
```

数据源：

- manifest
- activation policy
- keyword / pattern heuristics
- repo metadata
- risk flags

输出：

```json
{
  "recommended_mode": "L2",
  "confidence": 0.64,
  "reasons": [
    "frontend and backend keywords detected",
    "task appears multi-domain"
  ],
  "source": "local_heuristic"
}
```

规则：

```text
confidence >= 0.80
→ Codex 可直接参考

0.50 <= confidence < 0.80
→ Codex 综合判断

confidence < 0.50
→ 返回 UNKNOWN
→ Codex 自己判断
```

它不是第二个智能体。

---

# 13. 自动路由健康检查

`team.ps1 doctor` 必须包含 routing compliance test。

固定测试：

```text
README typo → L0
SQL optimization → L1
avatar upload → L2
auth redesign → L3
```

记录：

```text
ROUTING_PASS
ROUTING_MISMATCH
```

如果连续 N 次真实任务 misroute：

```yaml
routing:
  misroute_threshold: 3
```

达到阈值：

```text
auto_route = degraded
```

行为：

```text
Codex 每次复杂任务显式调用 team.ps1 route
```

直到重新验证。

---

# 14. Plan Generation Protocol

顺序固定：

```text
1. Read root AGENTS.md
2. Read manifest
3. Read activation/delegation/review policy
4. Read repo top-level tree
5. Locate target modules
6. Read relevant docs/config
7. Read relevant interfaces/tests
8. Read relevant recent decisions
9. Classify Routine/Critical
10. Select L0-L3
11. Identify capabilities
12. Map capability → role
13. Build DAG
14. Define acceptance
15. Define verification
16. Validate schema
17. Dispatch
```

---

# 15. Plan Schema 失败协议

如果：

```text
plan schema validation fails
```

行为：

```text
exit code = 10
event = plan_invalid
dispatch = forbidden
```

Codex 收到 exit 10 后：

```text
Attempt 1:
regenerate plan using validation errors

Attempt 2:
regenerate simplified plan

If still invalid:
stop run
surface implementation error
```

禁止：

```text
schema invalid
→ silently downgrade to L0
```

除非 Astra 明确写 Decision Log 说明为什么降级。

---

# 16. Repo Context Discovery

不允许一开始读整个 repo。

顺序：

```text
root tree
build/package files
top-level docs
target module entry points
related tests
contracts/interfaces
decisions
```

大 repo：

先生成 Repo Map。

---

# 17. Team Plan Schema 关键字段

```yaml
schema_version: 1

run:
  id: AUTH-20260917-001
  revision: 1

classification:
  level: critical
  reasons:
    - auth boundary change

mode: L3

capabilities:
  - architecture
  - backend
  - database
  - security
  - qa

tasks:
  - id: TASK-101
    role: architecture
    dependencies: []
    write_scope:
      - docs/auth/**

  - id: TASK-102
    role: backend
    dependencies:
      - TASK-101
    write_scope:
      - src/auth/**
      - tests/auth/**

verification:
  final:
    - full_test
    - build

review:
  require_9p: true
  require_fresh_9b: true
```

---

# 18. Dynamic Worker Pool

默认模板：

```text
generalist
product
research
architecture
ux
ui
frontend
backend
database
security
qa
performance
devops
data
ml
documentation
release
game-dev
integration
```

---

# 19. Role Schema

```yaml
schema_version: 1

role_id: backend
display_name: Backend Worker

capabilities:
  - api
  - auth
  - session
  - service-layer

default_permissions:
  shell: true
  network: false
  production: false
  secrets: false

default_read_scope:
  - src/**
  - tests/**
  - docs/**

default_write_scope:
  - src/**
  - tests/**

verification:
  preferred:
    - unit
    - integration
    - typecheck

subagents:
  allowed: true
  max_depth: 2

critical_triggers:
  - auth_boundary_change

escalation_triggers:
  - production_access_required
  - real_secret_required
```

---

# 20. Integration Worker 权限模型

`team/roles/integration.yaml`

```yaml
schema_version: 1

role_id: integration
display_name: Integration Worker

capabilities:
  - merge-conflict-resolution
  - glue-code
  - contract-alignment

permissions:
  shell: true
  network: false
  production: false
  secrets: false

write_scope_policy:
  mode: conflict_files_plus_explicit_glue_scope

may_change_interfaces: false
may_change_acceptance: false

may_change_tests:
  allowed: true
  only_if:
    - integration broke an existing valid test
    - test requires adaptation to an already-approved contract

forbidden:
  - introducing new business requirements
  - changing approved public contract without Astra replan
  - expanding scope without Decision Log

escalate_if:
  - requires_business_decision
  - requires_new_architecture
  - conflict cannot be solved without invalidating accepted task
```

Integration Worker 的 scope 由 Orchestrator 生成：

```text
conflict_files
+
approved glue paths
```

不是无限跨仓库写权限。

---

# 21. Sub Agent 权限

统一：

```yaml
subagents:
  max_depth: 2
  max_depth_future: 3
```

规则：

```text
SubAgent.permissions ⊆ Worker.permissions
```

不能：

- 扩大 write_scope
- 开网络
- 新拿 secret
- 改 main
- 改别的 worktree

---

# 22. Agent 数量三个指标

明确：

```text
max_agents_per_run
= 本 Run 累计创建的 Agent 数量
= 顶层 Worker + Sub Agent
= 不包含 Lead

max_parallel_agents_total
= 同时处于 RUNNING 状态的 Worker + Sub Agent

max_active_workers
= 同时 RUNNING 的顶层 Worker 数量
```

必须满足：

```text
max_active_workers
<= max_parallel_agents_total
<= max_agents_per_run
```

示例：

```yaml
max_active_workers: 4
max_parallel_agents_total: 6
max_agents_per_run: 10
```

可以：

```text
累计创建 10 个
同时最多跑 6 个
其中顶层 Worker 同时最多 4 个
```

第 11 个 Agent：

```text
禁止创建
→ Lead replan / reuse existing worker
```

---

# 23. Worktree 操作规范

`team/policies/worktree.md`

```yaml
base_branch:
  default: main
  integration_run: integration/<run-id>

branch_naming:
  pattern: team/<run-id>/<task-id>/<role>

worktree_root:
  path: .worktrees

worktree_naming:
  pattern: <run-id>-<task-id>-<role>

cleanup_when:
  - task_merged
  - task_discarded

keep_if:
  - escalation_pending
  - review_pending
  - unresolved_failure
```

---

# 24. Worktree 创建规则

每个 Worker 从本 Run 的固定 base SHA 切出。

```text
Run Start
→ record run_base_sha
```

Worker：

```text
branch starts from run_base_sha
```

如果 Task 明确依赖已合并上游：

则从：

```text
integration branch latest accepted SHA
```

切出。

这样避免“每个 Worker 随意从不同状态启动”。

---

# 25. Worktree 清理

只在：

```text
MERGED
DISCARDED
```

时自动删除。

状态为：

```text
ESCALATED
REVIEW
FAILED_WITH_EVIDENCE
```

默认保留。

---

# 26. Cross-Harness Contract

Codex ↔ DSH 只通过：

```text
Task Packet
Result Packet
Git
Verification
Decision Log
Evidence
```

---

# 27. Task Packet

```yaml
schema_version: 1

run_id: AUTH-20260917-001
task_id: TASK-104

role:
  id: backend

objective:
  - implement authentication backend contract

dependencies:
  - TASK-101

permissions:
  shell: true
  network: false
  secrets: false
  production: false

write_scope:
  - src/auth/**
  - tests/auth/**

acceptance:
  - unit tests pass
  - integration tests pass

subagents:
  allowed: true
  max_depth: 2
```

---

# 28. Result Packet

```yaml
schema_version: 1

run_id: AUTH-20260917-001
task_id: TASK-104
status: completed

summary:
  - implemented refresh rotation

changed_files:
  - src/auth/session.ts

verification:
  passed: true

subagents_used:
  - type: fresh
    purpose: api-review

risks: []

git:
  branch: team/AUTH-20260917-001/TASK-104/backend
  commit: abc123
```

---

# 29. Scope Violation 检测

由 Orchestrator 检测，不由 Astra 猜。

时机：

```text
Worker process exit
→ Read-WorkerResult
→ before verification/review
```

算法：

```text
actual_changed_files
=
git diff --name-only <task_base_sha>..<worker_branch>

allowed_files
=
Task Packet.write_scope patterns

violations
=
actual_changed_files - allowed_files
```

如果 violation：

```text
exit 82
state = FAILED_SCOPE
event = scope_violation
```

Astra 决定：

```text
reject
replan
or explicitly allow
```

如果允许：

必须写：

```text
DEC-xxx
```

并更新 Plan revision。

禁止“口头忽略”。

---

# 30. DSH Worker 启动契约

```powershell
Invoke-DshWorker `
  -TaskFile "task.yaml" `
  -Worktree ".worktrees/..." `
  -OutputFile "result.yaml" `
  -Profile "team-worker" `
  -TimeoutSeconds 3600
```

真实 CLI 由 Spike 固化。

---

# 31. Runtime State

Run：

```text
CREATED
PLANNING
READY
RUNNING
VERIFYING
INTEGRATING
FINAL_REVIEW
PAUSED
COMPLETED
FAILED
CANCELLED
ESCALATED
```

Task：

```text
CREATED
BLOCKED
READY
RUNNING
SELF_CHECK
RESULT_READY
VERIFYING
REVIEW
ACCEPTED
REWORK
FAILED
FAILED_SCOPE
MERGED
CLEANED
```

---

# 32. State Persistence

原子写：

```text
state.tmp
→ close
→ rename state.json
```

---

# 33. Orchestrator Recovery

```powershell
team.ps1 resume -Run <id>
```

检查：

- PID
- result
- worktree
- branch
- state
- events
- integration base

---

# 34. Replan 受影响子图算法

V1 不交给 LLM 全凭语义判断。

由 Orchestrator 计算候选 affected set。

输入：

```text
Task.dependencies
Task.reverse_dependencies
write_scope overlap
integration conflict ownership
```

算法：

```text
affected = failed_task

add all downstream tasks
where dependency path exists

add sibling tasks
only if write_scope overlaps changed/invalidated paths

preserve ACCEPTED unrelated tasks
```

然后 Astra 对候选集做最终语义确认。

即：

```text
Orchestrator = deterministic candidate
Astra = semantic confirmation
```

---

# 35. Replan Protocol

```text
1. Read state
2. Read failed evidence
3. Compute candidate affected subgraph
4. Preserve unrelated ACCEPTED tasks
5. Astra confirms affected set
6. Generate plan revision N+1
7. Validate schema
8. Record DEC-Replan
9. Dispatch changed/new tasks only
```

---

# 36. Fresh Reviewer 定义

> Fresh Reviewer = 新进程/新 Session + 新上下文 + 不继承 Lead 中间 reasoning + 不继承 Worker 聊天历史。

---

# 37. Fresh Reviewer 输入白名单

```yaml
review_inputs:
  allowed:
    - task.yaml
    - result.yaml
    - targeted_diff
    - test_output
    - evidence/**
    - related_decisions
    - explicitly_required_source_files

  forbidden:
    - lead_conversation
    - lead_chain_of_thought
    - worker_internal_conversation
    - unrelated_worker_results
    - unrelated_raw_logs
    - full_repo_history
```

例外：

Reviewer 明确请求更多证据时：

Orchestrator 只补相关材料。

---

# 38. 9P / 9A / 9B

## 9P

Critical Plan dispatch 前。

## 9A

Critical Worker implementation。

## 9B

Critical Integration final gate。

9B 必须 fresh。

---

# 39. Hard-stop

映射机器状态：

```text
HARD_STOP
```

动作：

```text
stop downstream dispatch
preserve evidence
state = ESCALATED or FAILED_SAFE
```

---

# 40. Verification Protocol

```text
Worker self-check
↓
scope audit
↓
external deterministic verification
↓
review
↓
Lead accept
```

---

# 41. Integration Protocol

## 41.1 Freeze Inputs

只接受：

```text
ACCEPTED branch
```

## 41.2 Record Base

```yaml
integration:
  base_sha: abc123
```

## 41.3 Merge by DAG

## 41.4 Targeted Regression After Each Merge

## 41.5 Conflict Detection

## 41.6 Integration Worker if Needed

## 41.7 Full Regression

## 41.8 Fresh 9B if Critical

---

# 42. Integration Failure 定位

每次 merge 后都有 targeted regression。

因此可以定位：

```text
last_good_integration_sha
last_merged_task
```

Full Regression 失败时：

1. Compare last good SHA
2. Identify most recent task merges
3. Run targeted bisect-like rollback on integration branch
4. Generate Integration Failure Task
5. Replan affected tasks only

V1 不要求自动 `git bisect`，但必须保留足够 merge checkpoints。

---

# 43. Rollback / Recovery

区分：

```text
Rollback = undo code/integration change
Recovery = resume runtime after process failure
```

---

# 44. Failure Mode Catalog + 执行入口

| 失败模式 | 检测 | 自动动作 | 执行入口 | 升级条件 |
|---|---|---|---|---|
| Plan schema invalid | schema | reject dispatch | `team.ps1 run` | 2 次重生成仍失败 |
| DSH route 错误 | preflight | fail closed | `Test-DshRoute.ps1` | 立即报告 |
| DSH 未启动 | process | retry once | `Invoke-DshWorker.ps1` | 二次失败 |
| Worker timeout | heartbeat | terminate + collect | `Wait-Worker.ps1` | repeated |
| Result schema invalid | schema | reject result | `Read-WorkerResult.ps1` | repeated |
| Scope violation | git diff | exit 82 | `Read-WorkerResult.ps1` | Critical/重复 |
| Verification fail | test exit | rework | `Invoke-Verification.ps1` | 同因二次 |
| Review fail | reviewer | rework/replan | `Invoke-ReviewGate.ps1` | repeated |
| Hard-stop | policy | stop downstream | `team.ps1` coordinator | policy |
| Merge conflict | git | create Integration Task | `Invoke-Integration.ps1` | unresolved |
| Sub Agent 越权 | scope/permission | reject | Worker + post audit | Critical |
| Orchestrator crash | heartbeat | resume | `Resume-TeamRun.ps1` | inconsistent state |
| PID lost | process | reconcile | `Resume-TeamRun.ps1` | repeated |
| Cost soft limit | budget | stop new optional fan-out | coordinator | 不升级 |
| Cost hard limit | budget | pause dispatch | coordinator | user decision |
| Replan limit | counter | pause | `Invoke-Replan.ps1` | Human |
| Repo unrecoverable | git check | stop | `Test-TeamDoctor.ps1` | Human |
| Fresh review unavailable | gate | block completion | `Invoke-ReviewGate.ps1` | unresolved |

---

# 45. Result Codes 统一映射

Codex 只读取：

```text
team.ps1 final exit code
```

不要求理解每个子脚本的内部 code。

内部脚本：

```text
return internal status
```

`team.ps1` 统一映射：

```text
0   success
10  invalid schema
20  preflight failed
30  worker failed
31  worker timeout
40  verification failed
50  review failed
60  hard-stop
70  escalation required
80  recovery conflict
81  integration conflict
82  scope violation
90  internal orchestrator error
```

---

# 46. Cost Soft Limit 行为

Orchestrator 检测到：

```text
cost >= soft_limit
```

写事件：

```json
{
  "event": "cost_soft_limit_reached"
}
```

行为：

```text
不终止正在运行的 Worker
停止创建 optional worker/subagent
停止非必要 fan-out
下一个 Lead decision point 必须读取该事件
Astra 改为 targeted review / serial execution
```

Hard Limit：

```text
暂停新的 dispatch
run = PAUSED
```

---

# 47. Human Observability

命令：

```powershell
team.ps1 status
team.ps1 watch
team.ps1 escalations
team.ps1 cost
team.ps1 logs
```

全部支持：

```text
-Json
```

---

# 48. team.ps1 watch 的 V1 语义

V1：

```text
poll events.jsonl
interval = 2 seconds
```

支持：

```powershell
-Since <timestamp>
-Task <task-id>
-Json
```

自动退出条件：

```text
COMPLETED
FAILED
CANCELLED
```

如果：

```text
ESCALATED
PAUSED
```

默认继续显示状态并提示用户，但不无限刷屏；可通过 `-Follow` 保持。

---

# 49. Human Escalation 文件

目录：

```text
team/runtime/<run>/escalations/
```

示例：

`ESC-001.yaml`

```yaml
schema_version: 1

id: ESC-001
run_id: AUTH-...
status: pending

type: destructive_operation

summary:
  Production migration appears irreversible.

options:
  - approve
  - reject
  - modify-plan

default_if_unresolved: pause
```

---

# 50. Escalation 人类入口

查看：

```powershell
team.ps1 escalations -Run <id>
```

处理：

```powershell
team.ps1 resolve `
  -Run <id> `
  -Escalation ESC-001 `
  -Decision reject
```

支持：

```text
approve
reject
modify-plan
```

默认超时：

```yaml
escalation:
  timeout_hours: 24
  timeout_action: pause
```

不是自动 reject，也不是自动 approve。

---

# 51. team.enabled = false 行为

明确：

```yaml
team:
  enabled: false
```

则：

```text
Codex → Normal Codex Mode
不生成 Team Plan
不调用 team.ps1 run
不启动 DSH Worker
旧 dual-agent-workflow 继续可用
team/ 目录仅作为静态文件，不进入执行路径
```

---

# 52. Multi-Run 并发策略

## V1

```text
one active Team Run per repo
```

如果已有：

```text
RUNNING / VERIFYING / INTEGRATING / PAUSED
```

新 Run：

```text
默认拒绝
exit 20
message: repository team lock active
```

可选择：

```text
queue
```

但 V1 默认不实现自动队列。

## V2

再支持：

```text
multi-run
per-run worktree
shared repo integration lock
```

---

# 53. Repo Lock

V1 使用：

```text
team/runtime/.team-lock
```

内容：

```yaml
run_id: ...
pid: ...
created_at: ...
```

doctor/resume 能清理 stale lock。

---

# 54. Codex Team Lead Prompt

新增：

`team/policies/codex-lead-prompt.md`

核心内容：

```markdown
# Codex Team Lead Role

You are the repository's autonomous engineering Team Lead.

For every task:
1. respect repository-local AGENTS.md;
2. check team/manifest.yaml;
3. choose L0/L1/L2/L3;
4. do not launch workers unless delegation adds value;
5. for L1-L3 generate a schema-valid Team Plan;
6. invoke only the repository-local team control interface;
7. never bypass DSH by replacing a worker with a raw model call;
8. keep GPT/Astra work focused on planning, arbitration, integration, and review;
9. treat Git/tests/evidence as ground truth;
10. never mark Critical work complete without required fresh review.

Allowed control commands:
- team.ps1 doctor
- team.ps1 route
- team.ps1 run
- team.ps1 status
- team.ps1 result
- team.ps1 logs
- team.ps1 cost
- team.ps1 resume
- team.ps1 stop
- team.ps1 cleanup

Normal repository-local work does not require human approval.

Escalate only for:
- destructive real-world action;
- production;
- real secrets;
- real financial action;
- unresolved business ambiguity;
- repeated autonomous failure;
- unrecoverable repository integrity.

Never:
- silently exceed write scope;
- silently change acceptance criteria;
- silently downgrade Native Harness;
- silently skip Critical review;
- expose internal reasoning to Fresh Reviewer.
```

---

# 55. AGENTS.md Team Policy 最小版

```markdown
## Team Mode

If team/manifest.yaml exists and team.enabled=true:

- evaluate each task for L0/L1/L2/L3;
- do not wait for the user to request Team Mode;
- use L0 for small localized work;
- use L1 for substantial single-domain work;
- use L2 for multiple independent workstreams;
- use L3 only when workers need native subagents or the task is large/critical;
- for L1-L3 create and validate a Team Plan before dispatch;
- use team/scripts/team.ps1 as the only team control entrypoint;
- follow escalation, review, worktree, and budget policies;
- never bypass required Native Harnesses.
```

---

# 56. 首次集成 dual-agent-workflow 的决策

Phase 0 生成：

`team/spike/INTEGRATION_DECISION.md`

分类：

## Case A — Existing mechanism complete

```text
Direct reuse
```

## Case B — Partial missing

```text
Complete missing prerequisite first
then integrate
```

## Case C — Incompatible

```text
Team Mode V1 may proceed without that optional review gate
only if task classification allows it
```

Critical：

如果缺 9P/9B 且它们是硬要求：

```text
Critical Team Mode blocked
```

禁止偷偷跳过。

---

# 57. EXISTING_INTEGRATION_MAP

格式：

```yaml
reuse:
  routine_critical_policy:
    path: <real path>

  review_9p:
    path: <real path or null>

  review_9a:
    path: <real path or null>

  review_9b:
    path: <real path or null>

  evidence:
    path: <real path or null>

  dsh_subagent_rules:
    path: <real path or null>

new:
  - team/policies/review-mapping.md
  - team/scripts/Invoke-ReviewGate.ps1
```

---

# 58. QUICKSTART.md

必须新增：

`team/QUICKSTART.md`

只包含：

1. 最小架构图
2. Phase 0 决策矩阵
3. doctor
4. 单 Worker 链路
5. Task/Result 示例
6. 常见 exit code
7. 如何看 status/watch
8. 如何 resolve escalation
9. Phase 2 最小验收

让实施者不必一开始读完整 v5.0。

---

# 59. Quickstart 最小链路

```text
User
↓
Codex
↓
L1
↓
plan.yaml
↓
team.ps1 run
↓
one DSH worker
↓
result.yaml
↓
scope audit
↓
tests
↓
Astra accept/rework
```

第一阶段只证明这一条。

---

# 60. Phase 实施路线

## Phase 0
Capability + Integration Spike

## Phase 1
Schemas + Policies + Quickstart

## Phase 2
One Worker

## Phase 3
Worktree + Scope Audit

## Phase 4
Verification + Existing Review

## Phase 5
Multi Worker + DAG

## Phase 6
Native Sub Agents

## Phase 7
Integration + Replan + Recovery

## Phase 8
Critical Full Review

---

# 61. Phase 0 验收

```powershell
.\team\scripts\team.ps1 doctor -Json
```

必须输出：

- versions
- DSH input/output capability
- route verified
- Codex shell
- integration map
- team lock state

---

# 62. Phase 1 验收

```powershell
team.ps1 validate -Plan .\team\tests\plans\L1-sql.yaml
```

期望：

```text
0
```

非法：

```text
10
```

---

# 63. Phase 2 验收

```powershell
team.ps1 run -Plan .\team\tests\plans\L1-sql.yaml
```

期望：

```text
result.yaml exists
result.status = completed
```

---

# 64. Phase 3 验收

验证：

```text
worker branch exists
worktree exists
main unchanged
scope audit passes
```

---

# 65. Phase 4 验收

故意测试失败：

```text
exit 40
```

---

# 66. Phase 5 验收

```text
>= 2 tasks
DAG respected
max_active_workers respected
```

---

# 67. Phase 6 验收

```text
subagents_used != empty
max_depth <= 2
permissions not expanded
```

---

# 68. Phase 7 验收

模拟：

- worker crash
- orchestrator crash
- replan
- integration conflict

必须能：

```text
resume
preserve accepted
rollback integration
```

---

# 69. Phase 8 验收

Critical：

```text
9P before dispatch
Fresh 9B before complete
full regression pass
```

---

# 70. MVP 测试矩阵

A. README typo → L0  
B. SQL → L1  
C. Avatar → L2  
D. Auth redesign → L3  
E. Worker conflict → Astra Decision Log  
F. Production delete → Hard-stop  
G. Wrong route → Fail Closed  
H. Worker timeout → terminate/replan  
I. Orchestrator crash → resume  
J. Sub Agent scope expansion → reject  
K. Critical self review → block  
L. Cost soft limit → reduce optional fan-out  
M. Small task misroute → mismatch recorded  
N. Complex task under-route → mismatch recorded  
O. Integration conflict → Integration Worker  
P. Replan preservation → ACCEPTED preserved  
Q. Plan schema invalid → exit 10, no dispatch  
R. team.enabled=false → Normal Codex Mode  
S. second run while active → repo lock rejection  
T. version outside range → preflight fail  

---

# 71. 成本控制

Soft limit：

```text
不终止正在运行 Agent
停止 optional dispatch
停止 optional Sub Agent
Lead 改为 targeted review
```

Hard limit：

```text
run PAUSED
```

---

# 72. 资源限制

```yaml
resources:
  max_active_workers: 4
  max_parallel_agents_total: 6
  max_agents_per_run: 10

  worker:
    timeout_seconds: 3600
    idle_timeout_seconds: 900

  logs:
    max_single_log_mb: 50

  worktrees:
    max_count: 12
```

---

# 73. Claude Code 定位

明确：

```text
Legacy / Optional / Fallback Development Shell
```

不在 Team Mode 核心路径。

核心：

```text
Codex Lead
+
DSH Workers
```

---

# 74. 跨平台

V1：

```text
Windows + PowerShell
```

V2：

```text
PowerShell Core
```

必要时：

```text
thin Python/TypeScript CLI
```

保持同一 CLI Contract。

---

# 75. 目录结构

```text
dual-agent-workflow/
│
├─ AGENTS.md
├─ claude/
├─ codex/
├─ dsh/
│
├─ team/
│  ├─ QUICKSTART.md
│  ├─ manifest.yaml
│  ├─ README.md
│  │
│  ├─ spike/
│  │  ├─ DSH_CAPABILITY_MATRIX.md
│  │  ├─ CODEX_CAPABILITY_MATRIX.md
│  │  ├─ DSH_COMMANDS_VERIFIED.md
│  │  ├─ CODEX_COMMANDS_VERIFIED.md
│  │  ├─ VERIFIED_VERSIONS.md
│  │  ├─ EXISTING_INTEGRATION_MAP.md
│  │  ├─ INTEGRATION_DECISION.md
│  │  └─ OPEN_GAPS.md
│  │
│  ├─ roles/
│  │  ├─ backend.yaml
│  │  ├─ integration.yaml
│  │  └─ ...
│  │
│  ├─ policies/
│  │  ├─ codex-lead-prompt.md
│  │  ├─ activation.md
│  │  ├─ delegation.md
│  │  ├─ escalation.yaml
│  │  ├─ permissions.yaml
│  │  ├─ worktree.md
│  │  ├─ integration.md
│  │  ├─ replan.md
│  │  ├─ review-mapping.md
│  │  ├─ security.md
│  │  └─ budget.yaml
│  │
│  ├─ schemas/
│  │  ├─ manifest.schema.json
│  │  ├─ role.schema.json
│  │  ├─ team-plan.schema.json
│  │  ├─ task.schema.json
│  │  ├─ result.schema.json
│  │  ├─ state.schema.json
│  │  └─ cost.schema.json
│  │
│  ├─ scripts/
│  │  ├─ team.ps1
│  │  ├─ Test-TeamDoctor.ps1
│  │  ├─ Test-DshRoute.ps1
│  │  ├─ New-TeamRun.ps1
│  │  ├─ New-Worktree.ps1
│  │  ├─ New-Worker.ps1
│  │  ├─ Invoke-DshWorker.ps1
│  │  ├─ Wait-Worker.ps1
│  │  ├─ Read-WorkerResult.ps1
│  │  ├─ Invoke-Verification.ps1
│  │  ├─ Invoke-ReviewGate.ps1
│  │  ├─ Invoke-Integration.ps1
│  │  ├─ Invoke-Replan.ps1
│  │  ├─ Stop-Worker.ps1
│  │  ├─ Resume-TeamRun.ps1
│  │  └─ Remove-Worktree.ps1
│  │
│  ├─ tests/
│  │  ├─ plans/
│  │  ├─ routing/
│  │  ├─ contracts/
│  │  └─ integration/
│  │
│  └─ runtime/
│     └─ .gitkeep
│
├─ .worktrees/
└─ .gitignore
```

---

# 76. team.ps1 统一入口

```powershell
team.ps1 doctor
team.ps1 route
team.ps1 validate
team.ps1 run
team.ps1 status
team.ps1 watch
team.ps1 escalations
team.ps1 resolve
team.ps1 result
team.ps1 logs
team.ps1 cost
team.ps1 stop
team.ps1 resume
team.ps1 cleanup
```

全部支持：

```text
-Json
```

---

# 77. 最终基线 manifest

```yaml
schema_version: 1

team:
  enabled: true
  auto_activate: true
  dynamic_roles: true
  default_mode: auto
  single_active_run_per_repo: true

models:
  lead:
    alias: astra-lead
    harness: codex
    runtime_model: gpt-6-astra

  worker:
    alias: deepseek-worker
    harness: dsh
    runtime_model: deepseek-v4.1-flash

subagents:
  native_only: true
  worker_controlled: true
  max_depth: 2
  max_depth_future: 3

execution:
  modes: [L0, L1, L2, L3]

worktrees:
  enabled: true
  per_writing_worker: true
  root: .worktrees

human:
  approval_required_by_default: false
  arbitration_required_by_default: false
  escalation_only: true

review:
  reuse_existing_dual_agent_workflow: true
  critical_requires_9p: true
  critical_requires_fresh_9b: true

budget:
  max_active_workers: 4
  max_parallel_agents_total: 6
  max_agents_per_run: 10
  max_worker_retries: 2
  max_replans: 3

routing:
  local_route_helper: true
  misroute_threshold: 3

orchestrator:
  implementation_v1: powershell
  intelligence: false
  resumable: true

control_interface:
  v1: cli
  mcp: optional_later

source_of_truth:
  - git
  - tests
  - ci
  - schemas
  - evidence
```

---

# 78. 风险登记册

## R1 DSH 自动化能力不足
→ Phase 0 二维矩阵 + Adapter + mode downgrade

## R2 Codex 自动路由退化
→ doctor routing tests + misroute counter + route helper

## R3 Plan 上下文过大
→ Repo Map + staged discovery

## R4 Sub Agent 越权
→ subset permissions + scope audit

## R5 Astra 额度失控
→ structured results + targeted review + soft/hard limits

## R6 Agent 官僚主义
→ L0-L3 + caps

## R7 Worktree 被当作安全沙箱
→ 明示 Git-only isolation

## R8 Orchestrator crash
→ atomic state + resume

## R9 Critical 自我批准
→ Fresh Reviewer

## R10 CLI/模型升级
→ verified versions + reject outside range

## R11 Integration 冲突扩大
→ Integration Worker + base_sha + targeted regression

## R12 Replan 循环
→ deterministic affected subgraph + max_replans

## R13 Multiple runs
→ V1 repo lock

## R14 Escalation 无人处理
→ 24h pause default

---

# 79. 长期演进

V1：

```text
PowerShell + Git + Codex + DSH
```

V2：

```text
PowerShell Core / thin Python or TS CLI
```

V3：

```text
optional MCP facade
```

V4：

```text
persistent service
OpenTelemetry
remote sandbox
multi-machine workers
```

---

# 80. 最终不可破坏原则

1. GPT 与 DeepSeek 绑定 Native Harness。
2. Astra 做高价值判断，不承担大量低价值 bulk work。
3. Worker 动态，不固定组织结构。
4. Worker 决定 Sub Agent。
5. Sub Agent 不能扩权。
6. V1 Sub Agent 深度固定 2。
7. Worktree 仅是 Git 隔离。
8. 跨 Harness 通过结构化协议。
9. Git/Test/Evidence 是事实源。
10. Critical 不能同上下文自我批准。
11. Fresh Reviewer 是新 Session/新上下文。
12. Human Approval 默认关闭。
13. Human Escalation 永远保留。
14. Orchestrator 保持 Thin。
15. Phase 0 失败按矩阵降级，不硬撑。
16. Plan schema invalid 不 dispatch。
17. Scope violation 由 Orchestrator 确定性检测。
18. Replan 默认只处理受影响子图。
19. Integration Worker 不能偷偷改业务目标。
20. 每次 Integration merge 后做 targeted regression。
21. Codex 只消费 team.ps1 统一 exit code。
22. Cost soft limit 不杀正在运行的 Worker。
23. 版本超出 verified range 默认 fail closed。
24. V1 每 repo 单 active run。
25. team.enabled=false 时完全回到 Normal Codex Mode。
26. Quickstart 必须存在。
27. 现有 dual-agent-workflow 的真实路径必须在 Phase 0 映射。
28. Critical review gate 缺失时，不得伪装通过。
29. 所有权限策略必须区分“声明”与“强制”。
30. 所有运行时能力必须由 Preflight 证明，不靠假设。

---

# 81. 最终实施顺序

```text
Phase 0
Capability + Existing Integration Spike
        ↓
Phase 1
Schemas + Policies + QUICKSTART
        ↓
Phase 2
Codex → team.ps1 → ONE DSH Worker
        ↓
Phase 3
Worktree + Scope Audit
        ↓
Phase 4
Verification + Existing Review
        ↓
Phase 5
Multi Worker + DAG
        ↓
Phase 6
Native Sub Agents
        ↓
Phase 7
Integration + Replan + Recovery
        ↓
Phase 8
Critical Full Review
```

第一条必须证明：

```text
User
↓
Codex
↓
L1
↓
Valid Plan
↓
team.ps1
↓
DSH Native Worker
↓
Result Packet
↓
Scope Audit
↓
Tests
↓
Astra Accept / Rework
```

这条链路没稳定：

> **不要扩展成完整 Agent Team。**

---

# 82. 文档状态

v5.0 相比 v4.0，新增并固化了实施语义：

- Phase 0 二维输入/输出/退出码矩阵；
- `team.ps1 route` 明确定义为纯本地辅助器；
- Plan schema fail 行为；
- Integration Worker 权限；
- Replan affected subgraph 算法；
- Failure Mode → script entry 映射；
- Scope Violation 确定性实现；
- Result Codes 统一映射；
- Fresh Reviewer 输入白名单；
- Worktree base/branch/cleanup 规范；
- 三种 Agent 数量指标定义；
- Quickstart；
- Codex Team Lead Prompt；
- 首次 dual-agent-workflow 集成决策；
- `watch` 的 polling 语义；
- Cost Soft Limit 通知方式；
- Escalation 人类入口；
- Codex 自动路由退化检测；
- Verified Versions；
- V1 单 Run 锁；
- `team.enabled=false` 行为。

因此本文件同时充当：

```text
Architecture Specification
+
Protocol Specification
+
Protocol Implementation Notes
+
Operational Semantics
+
Implementation Roadmap
+
Acceptance Baseline
```

---

# 83. 最终一句话定义

> **GPT-6 Astra + Codex 作为自主 Team Lead，通过受控 Repo Discovery 生成结构化 Team Plan，并自动选择 L0/L1/L2/L3；DeepSeek V4.1 Flash 始终运行于 DSH Native Harness 中作为动态 Worker，由 Worker 自主管理 DSH Native Sub Agent；Thin Orchestrator 负责进程、Worktree、状态、范围审计、验证、Integration、Recovery；Critical 流程复用 dual-agent-workflow 的独立 Review 与 Evidence 纪律；普通任务无需人类审批，只有高风险、不可逆、连续失败、预算硬限制或无法恢复时才升级给人类。**
