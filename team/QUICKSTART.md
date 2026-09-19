# 最小可操作链路

```text
Codex → 合法 Plan → DSH Worker 的独立 worktree → Result → 范围审计
      → 外部验证 → 独立 DSH Local Review → Lead accept → integration → final verification
```

当前 DSH：短输入用命令行，长输入由运行专属 patch 传入原生 runner 配置；O2 正文 stdout / E2 有界退出。
适配器把 Task Packet 放入 prompt，将严格 JSON 正文转换为 `result.yaml`。
原生子代理可用；主进程与子进程路由由 native registry guard 记录。

Phase 0 的准入决策（I=输入，O=输出，E=退出码）：

| 原生能力 | 可选模式 | 处理 |
|---|---|---|
| I3/I2 文件输入 + O4/O3 结构化输出 + E2 | L1/L2/L3 | 另核验原生子 Agent |
| I3/I2 + O2 正文 + E2 | L1/L2 | Adapter 校验 Result |
| I1 参数/stdin + O3/O2 + E2 | L1/L2 | 原文矩阵；已认证组合的 L3 扩展另见下文 |
| I1 + O1 可解析 TUI + E1/E2 | 实验 L1 | 先稳定 Adapter |
| I0 仅交互或 O0/E0 不稳定 | L0 | 不进入正式 Team |
| 路由不可验证 | 无派发 | fail closed |
| 子 Agent 不可用 | L1/L2 | 禁止 L3 |

本机已通过 native fresh/fork 入口和非空已完成父回合继承探针；普通 headless Worker
仍是单回合，fork 不继承正在进行中的不完整回合，也不能用于 fresh Reviewer。
完整能力证据和边界见 `spike/DSH_CAPABILITY_MATRIX.md`、`spike/VERIFIED_VERSIONS.md`。
按 2026-09-17 人类裁决保留 L3 适配器扩展，见 `spike/INTEGRATION_DECISION.md`。
doctor 同时返回原文 `matrix_modes` 与实际 `allowed_modes`；L3 要求已验证的 DSH 版本/
profile/模型组合、子 Agent 开关、原生工具及其 provider 可用和 guard 存在。run/resume 重新检查，
不满足返回 20，不静默改计划。`-AllowUnverifiedRuntime` 不授予未知版本的 L3 扩展。

```powershell
pwsh -NoProfile -File ./team/scripts/team.ps1 doctor -Json
pwsh -NoProfile -File ./team/scripts/team.ps1 route -TaskText 'SQL optimization' -Json
pwsh -NoProfile -File ./team/scripts/team.ps1 validate -Plan ./team/tests/plans/L1-sql.yaml -Json
```

这些命令应由当前 Codex Lead 活动会话执行。doctor 会读取当前轮次元数据并核对 manifest
指定模型；普通终端只有配置而无活动轮次时不能通过。需要新开 CLI Lead 时，可执行
`pwsh -NoProfile -File "$env:USERPROFILE/.codex/team/scripts/team-lead.ps1" -Repo <项目目录>`；
自定义 CODEX_HOME 时使用其下的 `team/scripts/team-lead.ps1`。启动参数不替代后续 doctor。

临时角色放在 Plan 的 `dynamic_roles`，例如先复制 `roles/database.yaml` 的完整定义，
把 `role_id` 改为 `query-specialist`，保留全部必填字段并调整 `guidance`，再嵌入：

```yaml
dynamic_roles:
  query-specialist: # 此处填写修改后的完整角色对象，不是文件路径或角色名字符串
    # ...完整 role schema 字段...
tasks:
  - id: SQL-001
    role: query-specialist
    # ...原任务其余字段...
```

该片段只说明嵌入位置，不能直接作为完整 Plan 运行。`validate` 会验证角色 schema、ID、
manifest 开关及禁止覆盖内置角色的规则。运行时冻结角色，修订其定义须使用新 ID。

账单以已知增量分账录入（`$bill` 是实际账单文件路径，`$amount` 是该笔增量）：

```powershell
pwsh -NoProfile -File ./team/scripts/team.ps1 report-cost -Run <run-id> -Ledger astra -Unit credits -Source 'Astra usage statement' -Amount $amount -Evidence $bill -Json
pwsh -NoProfile -File ./team/scripts/team.ps1 report-cost -Run <run-id> -Ledger deepseek -Unit USD -Source 'DeepSeek billing statement' -Amount $amount -Evidence $bill -Json
```

两条命令对应不同凭证，不能重复录入同一证据哈希。各账本软/硬阈值分别为 10/20；
任一账本触限即采取相应措施，不把 Credits 与 USD 相加。旧无单位记录保留，拒绝静默换算。

`route -Repo ...` 会参考固定领域路径标记，并返回 `repo_metadata`、`risk_flags` 和
`lead_action`。模糊任务的 L1/L2 建议仍需 Lead 判断，不因仓库大而把小改动升级。
连续误判进入 degraded 后，doctor 与 run/resume 也会返回通知；单次匹配不解除降级。
修正启发式、仓库元数据或有事实依据的任务期望后，显式重放已记录任务：

```powershell
pwsh -NoProfile -File ./team/scripts/team.ps1 record-route -Repo C:/path/to/test-repo -TaskText '新增搜索功能' -ExpectedMode L2 -Json
pwsh -NoProfile -File ./team/scripts/team.ps1 revalidate-route -Repo C:/path/to/test-repo -Reason '修正了导致误判的原因' -Json
```

重新验证还包含四个固定路由示例；任何一项仍不匹配均返回 20 并保留降级。

先用独立测试仓库作为 `-Repo`；其中应有初始 commit，Git 提交身份已配置，
`.gitignore` 忽略 `/team/runtime/` 与 `/.worktrees/`。计划和验证命令必须按实际项目填写。
运行器不替你修改目标仓库的忽略规则、Git 身份或权限设置。

```powershell
pwsh -NoProfile -File ./team/scripts/team.ps1 run -Plan ./team/tests/plans/L1-sql.yaml -Repo C:/path/to/test-repo -Json
pwsh -NoProfile -File ./team/scripts/team.ps1 status -Run SQL-SMOKE-001 -Repo C:/path/to/test-repo -Json
pwsh -NoProfile -File ./team/scripts/team.ps1 result -Run SQL-SMOKE-001 -Task SQL-001 -Repo C:/path/to/test-repo -Json
```

到 `REVIEW` 后，Lead 阅读实际 diff、Result 和 `verification-evidence.json`。
没有重新请求人类审批；下面的 accept 是 Lead 对确切 commit 的验收记录。
每个成功 Worker 还需一个独立 DSH Local Reviewer，两者都计入 Agent 总量和并发预算。
本地审查禁用原生工具，只读取冻结的 Task、diff、项目规则和外部验证证据。
若停在 `LOCAL_REVIEW` 并提出补证，用 `resolve-review -Stage LOCAL -Task <id> -Disposition <file>`
逐条处置，再 `resume`；它复用原 verdict，不重跑作者或审查来寻找通过答案。
Critical 在本地审查后仍须通过独立 9A，最终集成后仍须 fresh 9B。

```powershell
pwsh -NoProfile -File ./team/scripts/team.ps1 accept -Repo C:/path/to/test-repo -Run SQL-SMOKE-001 -Task SQL-001 -Commit <full-worker-sha> -Reason '实际 diff 和外部验证满足验收' -Json
pwsh -NoProfile -File ./team/scripts/team.ps1 integrate -Repo C:/path/to/test-repo -Run SQL-SMOKE-001 -Json
```

L2 有依赖的任务在上游 `MERGED` 后 `resume` 派发，从最新已验收集成 SHA 启动。
独立任务始终从固定 `run_base_sha` 切出。重复执行 run 不会重复派发，须使用 resume。
Task 示例见 `tests/plans/L1-sql.yaml`，完整字段由 `schemas/task.schema.json` 与
`schemas/result.schema.json` 约束；Result 的 changed_files、branch、commit 会与 Git 对照。

最小 Result 形状（commit 必须替换成实际完整 SHA，不能直接提交这个示例）：

```yaml
schema_version: 1
run_id: SQL-SMOKE-001
task_id: SQL-001
status: completed
summary: [已实现并验证健康查询]
changed_files: [queries/health.sql]
verification: {passed: true}
subagents_used: []
risks: []
git:
  branch: codex/team/SQL-SMOKE-001/SQL-001/database-a1
  commit: <actual-full-sha>
```

观察与例外：

```powershell
pwsh -NoProfile -File ./team/scripts/team.ps1 watch -Repo C:/path/to/test-repo -Run SQL-SMOKE-001 -Json
pwsh -NoProfile -File ./team/scripts/team.ps1 escalations -Repo C:/path/to/test-repo -Run SQL-SMOKE-001 -Json
pwsh -NoProfile -File ./team/scripts/team.ps1 resolve -Repo C:/path/to/test-repo -Run SQL-SMOKE-001 -Escalation ESC-id -Decision reject -Reason '取消该操作' -Json
```

watch 每两秒读取新增事件，支持 `-Since`、`-Task`；PAUSED/ESCALATED 默认返回，`-Follow` 才持续等候。
读取按字节偏移推进，不反复扫描完整历史。默认累计预算 10 需同时容纳作者及必需 Local Reviewer，
所以最多 5 个必需任务的首次执行；子 Agent 和重试另留余量。治理文件变更的 Routine 任务也要求 fresh 9A。
70 / `input_too_large` 表示完整输入超过传输上限：检查保留的 diff/authority/日志，
拆分任务后 replan。运行器不静默截断 diff，也不会重试或收费记账未创建的原生 Agent。
共享运行器新增输入限制有兼容默认值，已有项目 manifest 无须迁移；限制和证据目录详见 README。
一个 Local Review 请求补证时，已经派发的其他作者可在原有期限内完成；结果保存为
`RESULT_READY`，暂停新增作者和审查。处置补证后 `resume` 核验这些结果，不重复派发作者。
常用错误：10 修正 schema；20 检查 doctor/锁；31 检查超时证据；40 修正验证失败；
50 处理独立审查；80 先恢复 Git/PID 一致性；82 更新合法 plan revision 或撤销越界改动。
禁止把 schema 失败静默降成 L0，或把无 verdict 当通过。

Worker 的 escalated Result 返回 70，保留证据并等待升级决定；决定后须显式 replan，
不能直接 accept。不同 attempt 两次验证失败的命令和输出完全相同时也会升级，
此时保留原始 exit 40。`team.enabled=false` 拒绝继续执行和验收，仍可查询及 stop 已有任务。
同一任务跨两次 attempt 的同类超时、Result 无效、审查失败、证据缺失或范围违规也会升级；
Critical 范围违规首次即升级。同一 attempt 的重复恢复不增加次数，完整通过任务流水线才清除计数。

显式 `replan` 将受影响的旧 attempt 归档为 `DISCARDED`，包括被新计划删除的任务。
`cleanup` 只移除身份、分支、提交均匹配且干净的废弃 worktree；保留分支及原始证据，
脏目录返回 80，不强删。归档仍为 DISCARDED，不把未集成工作记成 CLEANED。

Critical 审查按已审 plan revision 聚合 9A/9B；9P 不计入修复轮次。
归因争议需人类逐项裁决，三轮上限/early-stop 需人类决定，连续两轮修复引入缺陷硬停。
`resolve approve` 不使产品 blocking 消失；处理文件及额外一轮的明确含义见
[审查映射](policies/review-mapping.md)。

最终回归失败会保存 `integration-failure.json` 与 draft 修复任务。用
`rollback -Task <id> -Reason ...` 回滚候选任务及受影响下游，再查看保留的 probe；
必要时可继续回滚更早检查点。确认修复范围后，执行
`repair-integration -Task <suspect-id> -Reason ...`，再走 resume / accept / integrate。
无关已集成任务保留；probe 通过不代替原验收，失败证据不会因下一次验证而丢失。
协调器在修订、合并或回滚中断后，保留原 runtime 目录并使用 `resume`。
持久事务会先核对并补齐计划/状态、集成检查点或已授权回滚；不会重复创建作者。
回滚完成后返回需要 replan 的提示是预期行为。若存在未解决的 revert 冲突，
先检查现场，再用原 `rollback -Task <id> -Reason ...` 中止属于本次操作的冲突。

最小验收：result.status=completed、Worker 分支与 worktree 存在、main SHA 不变、
外部验证 exit=0、Lead 验收绑定 commit、集成回归 exit=0、run.status=COMPLETED。

## 复用决策：计划必须带 reuse（2026-09-19 新增）

规范来源是仓内 `core/reuse/`（README 冻结语义、`reuse.schema.json` 冻结结构、
`Reuse.ps1` 是纯校验器）。Team 只引用它：适配器 `team/scripts/PriorArt.ps1` 从固定位置
（源仓同级 `core/reuse`，安装副本同级 `workflow-core/reuse`）加载，不读调用方工作目录。
**没有顶层 `reuse` 或没有任务级 `reuse` 的计划会被直接判为无效**（exit 10）。

纯文档 / 已定位本地缺陷 / 沿用仓内既有模式 / 纯数据改动可以跳过，但必须写显式
`skip_reason`（四类枚举之一），自由说明写在 `reason` 里：

```yaml
reuse:
  version: 1
  applicability: skipped
  status: skipped
  reason: 三个任务都只改本仓既有 SQL fixture 文件。
  searches: []
  candidates: []
  strategy: build
  rationale: fixture 文件不引入任何新能力、依赖、协议或架构决策。
  constraints: []
tasks:
  - id: SQL-001
    # ...
    reuse:
      applicability: skipped
      reason: 沿用仓内既有 fixture 模式，没有先例检索问题。
      change_kinds: [established_repo_pattern]
      refs: []
      skip_reason: established_repo_pattern
```

`new_implementation` / `new_dependency` / `architecture` / `protocol` 四类**强制检索**：
决策需 `applicability: required`，`status: completed` 时三个强制渠道
（`github_repositories` / `github_code` / `primary_docs`）都要有成功检索
（`results` 或 `no_results` 都算成功，查不到不是失败），`new_dependency` 还需要一次
成功的 `package_registry` 检索。

任一检索 `unavailable` ⇒ 决策只能 `blocked`，运行器在**前置条件、worktree、worker
之前**暂停并登记 `reuse_unavailable` 升级：

```powershell
pwsh -NoProfile -File ./team/scripts/team.ps1 escalations -Run <run-id> -Repo <repo> -Json
pwsh -NoProfile -File ./team/scripts/team.ps1 resolve -Run <run-id> -Repo <repo> -Escalation <esc-id> -Decision approve -Reason 'owner 接受该检索不可用，绑定本 plan hash' -Json
pwsh -NoProfile -File ./team/scripts/team.ps1 resume -Run <run-id> -Repo <repo> -Json
```

批准只对**确切 plan hash** 有效（24h 过期；reject、过期、哈希不符一律不通过），
`replan` 会使其失效并要求重新批准。新 run 会把协议身份冻结进 `state.reuse_protocol`
并把三个协议文件复制到 `team/runtime/<run>/reuse-protocol/`；任何 mutating 执行路径都会
重新核对，协议变了就要求开新 run。没有该标记的旧 run 仍可 `status`/`logs`/`cost`/`result`/
`stop`/`cleanup`，但执行类命令会明确要求**新计划 + 新 run**。

worker 收到派生的有界 `reuse_context`（不含检索日志与决策级 reason/rationale），
Result 必须回 `reuse`（`references_used` / `deviations`）：未知引用、任务外引用、
被规定却未使用又无 deviation 解释都会在验收前被拒。LOCAL/9A 拿到决策字段 + 任务声明 +
被引用候选的来源事实 + 使用声明；9B 只拿冻结 constraints、实际使用来源的
URL/revision/约束与使用声明（决策 reason/rationale/strategy、候选 rationale、检索日志与
未使用的候选都不下发）；9P 审阅计划本身，含完整决策。

## 收尾与恢复（2026-09-18 新增）

只读预览计划规模与预算（不派发、不写运行目录）：

```powershell
pwsh -NoProfile -File ./team/scripts/team.ps1 preview -Plan ./team/tests/plans/L1-sql.yaml -Repo C:/path/to/test-repo -Json
```

显式开启验证复用（默认仍然全部真实执行；一旦设置即按 run 粘滞）：

```powershell
pwsh -NoProfile -File ./team/scripts/team.ps1 run -Plan <plan> -Repo <repo> -ReuseVerification -Json
pwsh -NoProfile -File ./team/scripts/team.ps1 resume -Run <run-id> -Repo <repo> -Json
```

命中的前提是源码树/HEAD、完整命令与参数、工作目录、工具内容哈希、调用方声明的
`environment_fingerprint` 与 `input_artifacts` 哈希、以及成功退出码与完好收据全部一致。
命令在 Plan 里用 `environment_fingerprint` 和 `input_artifacts` 声明依赖；不声明就不复用。
退出 0 之后还会**再核对一次绑定**：如果命令自己改动了 tracked 源码、声明输入或工具内容，
证据里记为 `reuse_publish_rejected=binding_drift:*`，绝不写成缓存命中。

计划可声明前置条件；失败时**不会启动任何作者**：

```yaml
prerequisites:
  - id: fixture-db
    executable: pwsh
    args: [-NoProfile, -Command, "& ./tools/check-db.ps1"]
    timeout_seconds: 60
    restore: {executable: pwsh, args: [-NoProfile, -Command, "& ./tools/rollback-db.ps1"], timeout_seconds: 60}
```

```powershell
pwsh -NoProfile -File ./team/scripts/team.ps1 prerequisites -Run <run-id> -Repo C:/path/to/test-repo -Json
pwsh -NoProfile -File ./team/scripts/team.ps1 prerequisites -Run <run-id> -Repo C:/path/to/test-repo -Restore -Reason '回滚 fixture' -Json
```

run 结束后的归档与收尾：默认只预览，`-Apply` 才归档、证明可恢复并删除本 run 自己的
worktree 与分支（`main`、无关 ref、run 证据都保留）：

```powershell
pwsh -NoProfile -File ./team/scripts/team.ps1 finalize -Run <run-id> -Repo C:/path/to/test-repo -Json
pwsh -NoProfile -File ./team/scripts/team.ps1 finalize -Run <run-id> -Repo C:/path/to/test-repo -Apply -Json
```

真实 pnpm worktree 里的目录联接按描述符归档、绝不穿越；无法在界限内归档或在临时仓库中
证明可恢复的目标会 `preserved=true` 保留并给出原因，**不会**被删。删除不是原子的：
`directory_removal_pending=true` 表示目录尚未删净，下次 `-Apply` 继续。
`git worktree remove` 先注销再删文件，Windows 上可能留下「目录在、Git 已注销」的残树
（`cleanup` 命令或已退休 attempt 也会留下同形状目录）：它按本 run 的目录名/分支绑定收编，
`origin_proven=false` 明示原始 Git 状态未知，只归档文件系统可见内容并在临时目录证明可恢复，
然后**逐个比对哈希后删除**；哈希不符或未归档的内容保留并报告。一个目标无法安全处理时，
`-Apply` 只跳过它（`outcome=partial` + `failed`），其他安全目标照常归档删除；只有目录被证实
消失才报告 removed。

只有 transport/start/idle 这类有持久证据的失败可走基础设施恢复；它不改任务语义、
不消耗语义 replan 计数，且先前 attempt 会带 worktree、分支和脏内容原样退休归档：

```powershell
pwsh -NoProfile -File ./team/scripts/team.ps1 recover -Run <run-id> -Repo C:/path/to/test-repo -Task <task-id> -Reason 'DSH idle 期限，证据见 tasks/<id>/attempt-1/exit.json' -Json
```

`hard`（总超时）与 `output`（输出溢出）仍是基础设施类尝试但**不可自动恢复**；恢复被拒绝时
不会改动预留，且要求该 attempt 的适配器/原生/审查者/子进程清理全部被证明静默，否则保留为未知。
验证失败、业务失败、审查失败和范围违规**不会**被改标成基础设施；它们照旧占用各自的计数并升级。
`status`/`cost` 只读，永远不会自动改写历史 run。`status.summary` 区分派发意图与观测到的原生
创建收据：`authors_dispatched_intents` vs `authors_observed`/`author_agents_observed`，
`local_reviewers_started`（只数有原生收据的）vs `local_reviewers_preparing`（PREPARING 不算已启动），
以及 `attempts.infrastructure_recoverable` vs `attempts.infrastructure_nonrecoverable`。
