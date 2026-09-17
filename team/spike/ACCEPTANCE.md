# 验收记录（2026-09-17）

| 验证 | 实际结果 |
|---|---|
| Pester，`Run.Path=@('tests','team/tests')`，关闭 XML 输出 | 114 passed / 0 failed，exit 0；包含既有安装器隔离测试 |
| 后续 Team 回归，`Run.Path='team/tests'` | 39 passed / 0 failed，exit 0；包含新补路由降级与失败集成回滚 |
| 最后子范围修正后，`Run.Path='team/tests/Contracts.Tests.ps1'` | 29 passed / 0 failed，exit 0；与上行有重叠，不相加 |
| `node --test team/tests/native-guard.test.mjs` | 4 passed / 0 failed，exit 0 |
| `GuardEffectiveness.ps1` 正常 → 内存变异 → 正常 | exit 0 → 1 → 0；红因确为 out-of-scope committed file was accepted |
| `tools/dsh-drift-check.ps1` | 17 对、292 条登记差异完全一致，DRIFT none，exit 0 |
| `git diff --check` | exit 0 |
| 本机 doctor | DSH/Codex pin 与路由通过，四项 routing fixture 全部 ROUTING_PASS，exit 0 |

上述 Pester 批次覆盖范围有重叠，不把重跑次数相加当作独立用例数。
所有 Git 集成、进程退出、Worker 错误和回滚测试均在临时仓库；未运行真实配置部署器。
测试替身只用于 CLI 接线/故障注入，不作为模型能力证据。

真实 Harness 验收：

- `SQL-SMOKE-001`：DSH L1 → Result → Git scope → 外部验证 → Lead accept → integration → final，COMPLETED。
- `CRITICAL-SMOKE-002`：真实独立 Codex 9P/9A/9B；9P/9A 的 VN 逐项留有技术处置/实跑证据；9B 无 Blocking/VN；COMPLETED。
- `NATIVE-SMOKE-003`：DSH Worker + 一个 native fresh 子 Agent，实际创建记录与 Result 对齐，严格 SQL 内容检查及集成回归通过；COMPLETED。
- 三条链路都在独立临时仓库，main 未修改；具体 base/Worker/integration SHA 见 VERIFIED_VERSIONS.md。

首批代码已提交为 `a9a8a4a`，第二批预算/审批修正已提交为 `9181dd3`；均未部署到用户项目。
以上是本地实现与隔离 fixture 的验收，不等于任意项目的业务验收。
运行边界（权限声明、未知金额、版本与 fork 的验证级别）见 OPEN_GAPS.md。
# 第二批：执行中的预算与计划审批

2026-09-17：`team/tests` 实际运行 **45 passed / 0 failed**，exit 0；
`node --test team/tests/native-guard.test.mjs` **5 passed / 0 failed**，exit 0。
新增证明：运行中的 coordinator 可接收 soft/hard 费用凭证；原 Worker 完成，
optional 后继未启动；重复账单被拒绝、resume 不重复计费；已运行 native 家族
在软限制后不能创建新 child。费用未知部分仍保持 unknown_usage，不伪装完整计量。
权限测试证明：修改计划权限不会继承旧审批，modify-plan 不等于 approve，
过期升级保持 PAUSED，replan 引入 production_delete 在派发前硬停。
上述为真实 PowerShell 进程/Git 加替身模型 CLI；不是新的真实模型行为验收。

# 第三批：崩溃恢复与仓库锁

`team/tests` 完整回归 **50 passed / 0 failed**，exit 0；native guard **5 passed**，exit 0。
实际终止 coordinator（保留替身 Worker 进程）后，第一次 resume 因原进程仍存活返回 80；
Worker 完成后第二次 resume 到 REVIEW，attempts=1、agents_created=1，无重复派发。
故障注入发现并修复 JSON 时间戳被 PowerShell 读成 DateTime 后的 PID 身份比较错误，
现比较 UTC ticks；单独验证错误启动时间不能匹配同一存活 PID。
事件截断、任务状态字段缺失、集成 HEAD 偏移均被拒绝恢复；linked worktree 另建 run 返回 20。
事件读取异常时显式释放 reader，错误出口保留 80，不再被文件句柄冲突覆盖。
旧真实 `CRITICAL-SMOKE-002` 状态被新 schema 正常读取，仍为 COMPLETED（只读兼容检查，未重跑模型）。
派生漂移检查仍为 17 对/292 行、exit 0；全部集成和故障注入均局限于临时仓库。

# 第四批：真实并行 Worker 与 fork 入口

`L2-NATIVE-004`：真实双 DSH Worker 并行启动，分别提交独立 SQL 文件；Git scope、外部验证、
逐 merge targeted 回归、双命令 final 回归均 exit 0；COMPLETED，main 不变、调用者工作树干净。
`FORK-NATIVE-005`：真实 native `subagent_fork` 唯一调用的工具事件已核对，parent/child 创建记录
与 Result 相符；父 Worker 的 SQL 提交、外部验证和集成回归 exit 0，COMPLETED。
fork 子会话 isSeeded=false（首次回合没有已完成前缀），不宣称非空上下文继承已验收。
两个新 run 的 SHA、实际 session 和日志哈希见 VERIFIED_VERSIONS；真实 run 不替代业务数据库测试。
