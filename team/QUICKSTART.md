# 最小可操作链路

```text
Codex → 合法 Plan → DSH Worker 的独立 worktree → Result → 范围审计
      → 外部验证 → Lead accept → integration → final verification
```

当前 DSH：I1 命令行输入 / O2 正文 stdout / E2 有界退出。
适配器把 Task Packet 放入 prompt，将严格 JSON 正文转换为 `result.yaml`。
原生子代理可用；主进程与子进程路由由 native registry guard 记录。

Phase 0 的准入决策（I=输入，O=输出，E=退出码）：

| 原生能力 | 可选模式 | 处理 |
|---|---|---|
| I3/I2 文件输入 + O4/O3 结构化输出 + E2 | L1/L2/L3 | 另核验原生子 Agent |
| I3/I2 + O2 正文 + E2 | L1/L2 | Adapter 校验 Result |
| I1 参数/stdin + O3/O2 + E2 | L1/L2 | Adapter 封装 Task/Result，L3 需补原生子 Agent 实测 |
| I1 + O1 可解析 TUI + E1/E2 | 实验 L1 | 先稳定 Adapter |
| I0 仅交互或 O0/E0 不稳定 | L0 | 不进入正式 Team |
| 路由不可验证 | 无派发 | fail closed |
| 子 Agent 不可用 | L1/L2 | 禁止 L3 |

本机额外通过了 native fresh/fork 入口探针；fork 非空上下文继承尚未验证。
完整能力证据和边界见 `spike/DSH_CAPABILITY_MATRIX.md`、`spike/VERIFIED_VERSIONS.md`。

```powershell
pwsh -NoProfile -File ./team/scripts/team.ps1 doctor -Json
pwsh -NoProfile -File ./team/scripts/team.ps1 route -TaskText 'SQL optimization' -Json
pwsh -NoProfile -File ./team/scripts/team.ps1 validate -Plan ./team/tests/plans/L1-sql.yaml -Json
```

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
常用错误：10 修正 schema；20 检查 doctor/锁；31 检查超时证据；40 修正验证失败；
50 处理独立审查；80 先恢复 Git/PID 一致性；82 更新合法 plan revision 或撤销越界改动。
禁止把 schema 失败静默降成 L0，或把无 verdict 当通过。

Worker 的 escalated Result 返回 70，保留证据并等待升级决定；决定后须显式 replan，
不能直接 accept。不同 attempt 两次验证失败的命令和输出完全相同时也会升级，
此时保留原始 exit 40。`team.enabled=false` 拒绝继续执行和验收，仍可查询及 stop 已有任务。

最小验收：result.status=completed、Worker 分支与 worktree 存在、main SHA 不变、
外部验证 exit=0、Lead 验收绑定 commit、集成回归 exit=0、run.status=COMPLETED。
