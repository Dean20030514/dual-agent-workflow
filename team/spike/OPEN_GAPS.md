# 验收边界

已证实：真实 DSH L1 全链路、L3 单 Worker 加原生 fresh 子 Agent 的完整交付、真实 native 主/子 Agent 路由记录；
真实 L2 双 Worker 并行交付、原生 subagent_fork 入口（空前缀）的完整交付；
schema/DAG/范围/锁/进程超时的机械测试；使用替身 CLI 的 L2 DAG 与 Critical gate 接线。
当前测试数与最终结果由本任务的实际输出记录，不把历史通过数当本次回归结论。

真实独立 DSH Local Review 已由 LOCAL-NATIVE-013 验证：作者与 Reviewer 为不同原生 session，
后者禁用工具、提出一项 Git 补证，经外部进程实跑后复用原 verdict，Lead 验收并完成集成。
本地 Reviewer 中断/恢复、stop、拒绝写入及 DISCARDED 清理由真实进程/Git 加替身 CLI 验证，
不将这些故障注入称为真实模型故障验收。

真实 Critical 端到端已完成：`CRITICAL-SMOKE-002` 的 9P、9A、fresh 9B 均返回 pass，
9P 的未来实现检查以技术理由逐项处置，9A 要求的 git status 检查实际执行 exit 0；
9B 无 Blocking/VN，run=COMPLETED。首次 schema 与仓外读取失败仍保留，未伪装为通过。
这证明的是隔离 SQL fixture 的 Harness/审查/恢复协议，不代表任意业务项目质量已被保证。

固有边界：

- Worktree 不是 OS 沙箱；声明的网络/凭据权限不等于操作系统阻断。
- CLI headless 不给出完整金额账单。cost 明确 unknown_usage=true，外部账单通过唯一 evidence hash 录入；不把未知费用记作零。
- 版本 pin 是已测试单版本，不代表整个语义版本区间都兼容。
- 原生 fork 的空前缀与非空已完成父回合继承均已实测；正常 headless Worker 仍为单回合，
  不自动获得此前会话。双回合探针只验证原生继承行为，不扩张 Reviewer 的 fresh 规则。
- 替身 Critical 接线测试不代表真实模型审查质量，更不等于用户项目的业务验收。
- runtime/原生会话/仓外 holding 是本地证据，不随仓库部署；不要将其中的推理与私有数据公开。
