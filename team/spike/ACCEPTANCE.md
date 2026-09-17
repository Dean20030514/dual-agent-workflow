# 本轮验收记录（2026-09-17，未提交工作树）

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

当前变更尚未 commit 或部署；以上是本地工作树与隔离 fixture 的验收，不等于已部署到任意用户项目。
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
