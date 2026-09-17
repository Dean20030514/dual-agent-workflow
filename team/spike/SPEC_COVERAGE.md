# v5 范围核对（持续更新）

来源：`Codex_DSH_Dynamic_Agent_Team_Final_v5.md`，SHA-256 见 README。
本表用于防止把已完成的单链路验收当成整份规范完成。`已有`表示代码/文件已实现，
不代表所有运行环境均已验收；真实 Harness、替身 CLI、静态检查分别记录。
当前整份文档状态：**未完成**。既有真实验收见 [ACCEPTANCE](ACCEPTANCE.md)。

| 原文章节 | 对应实现/证据 | 尚需补齐或确认 |
|---|---|---|
| 0–4 架构、自治、Ground Truth、角色 | 原生 Codex/DSH、PS 控制面、Git/外部验证、SHA 验收 | 图中的 DSH Local Review 尚无独立执行阶段 |
| 5 逻辑别名、版本 pin、override | manifest、Preflight；真实 doctor 与错误版本 fixture | 当前只认证精确版本，未宣称更宽区间 |
| 6 复用质量规则 | EXISTING_INTEGRATION_MAP、review-mapping | Review 的计数/硬停仍需逐条对齐母本规则，不能仅凭 gate 接线宣称完整复用 |
| 7–9 能力 Spike、降级矩阵 | 8 份 Spike 文档；L1、fresh child、Critical 真实验收 | 原生 fork 的真实验收、能力矩阵与 L3 准入对应关系仍需补齐 |
| 10–13 L0–L3、纯本地 route、misroute | Core/Preflight、4 固定路由 fixture、连续 3 次降级 | route 尚未结合仓库 metadata；降级状态对 Lead 的通知及重新验证入口需复核 |
| 14–16 计划与分阶段上下文发现 | Lead policy 明确顺序和最多 2 次修复 | 无效计划 exit 10 已有；`plan_invalid` 命名事件尚缺 |
| 17 Team Plan、DAG | team-plan schema、Contracts、真实 Git 的 DAG fixture | 无 |
| 18–19 19 种角色与 role schema | 19 文件存在且校验 | 多数模板能力仍为同名占位；缺 preferred verification，Worker 尚未收到角色专属指导 |
| 20 Integration 约束 | Conflict 生成冲突文件+显式 glue、Decision Log、祖先检查 | 完整角色合同未进入 schema/packet；接口/测试语义限制仍主要依靠提示和 Lead |
| 21–22 子 Agent 权限/深度/三种限额 | native guard 准入、实际创建记录、Result/Git 审计 | 权限为声明+原生继承，非 OS 沙箱；全局并发采取家族保守预留，尚无真实多 Worker+子 Agent 联合验收 |
| 23–25 worktree/base/cleanup | 冻结 base、依赖从集成 SHA、MERGED 清理；Git fixture | DISCARDED 生命周期/清理尚缺 |
| 26–30 Packet、范围、启动 | schemas、adapter、Git diff 范围审计；真实 L1 | `scope_violation` 专属事件尚缺；DSH 启动前失败重试一次尚缺 |
| 31–32 状态机、原子持久化 | State、Core 原子替换 | state schema 仅约束外围字段，需约束任务状态和恢复必填字段 |
| 33 恢复 | PID+起始时间、exit receipt、Result、Git 校验 | events/integration base 的启动检查仍不完整；目前恢复测试是持久状态模拟，尚需实际终止 coordinator 验收 |
| 34–35 受影响子图、修订、保留 ACCEPTED | Contracts/Recovery；fixture 保留无关 ACCEPTED | glob overlap 的候选集需补充交叉/传递边界测试 |
| 36–38 fresh review、输入白名单、9P/A/B | 独立 Codex exec、stdin 白名单、read-only；真实 Critical 完成 | 需核对目标仓库旧 Critical 规则兼容性，不能以隔离 fixture 代替任意项目 |
| 39 硬停 | hard_stop、ESCALATED、禁止下游 | 既有 Fix-Loop 全部判据对齐仍未完成 |
| 40 验证顺序 | self-check→Git→外部命令→review→accept | 无 |
| 41–43 集成/定位/rollback | DAG merge、逐次 checkpoint/回归、最后 checkpoint revert | 多 checkpoint 连续回滚与失败定位任务生成尚缺；当前只支持最近 merge |
| 44 失败目录 | 大多数错误有统一出口，代码模块对应下表 | 启动重试一次、重复同因验证失败升级尚缺；需补逐条故障注入 |
| 45 返回码 | team.ps1 统一 0/10/20/30/31/40/50/60/70/80/81/82/90 | 需确保异常恢复分支不会把可诊断错误误记 90 |
| 46、71 费用软/硬限制 | Controls 收据队列；dispatch 与 native guard 动态读取 | 原生账单仍未知，人工录入有时间差；不得把 unknown usage 宣称为金额硬上限保证 |
| 47–48 观察命令/watch | status/watch/escalations/cost/logs，Json、Since、Task、Follow | 终止/过滤语义仍需专门 CLI 验收 |
| 49–50 升级与处理 | plan hash 绑定、approve/reject/modify-plan、过期保持 PAUSED | 24h 为下次控制命令检查，无后台守护进程；等待期间本已停止派发 |
| 51 disabled | run/resume/repair 拒绝，route 返回 L0、Lead hook | 其他执行命令对 disabled 的一致处理需补齐 |
| 52–53 单 run、锁 | coordinator 排他文件句柄、持久 run 锁、terminal stale repair | 同 Git repo 的不同 linked worktree 路径可能绕过单 run 锁，需修复/测试 |
| 54–57 Lead、AGENTS、既有规则映射 | root/codex AGENTS hook、Lead policy、Case B/map | 未部署本机全局副本；项目契约优先 |
| 58–59 QUICKSTART/首条链路 | QUICKSTART，真实 SQL-SMOKE-001 | Quickstart 尚需完整决策矩阵/内联 Result 示例 |
| 60–69 Phase 0–8 | 单 Worker/worktree/验证/子 Agent/Critical 有真实证据，多 Worker/恢复为 fixture；doctor.route 含 input/output/exit axes | Phase 5/7 实际运行证据待补 |
| 70 A–T 验收矩阵 | 见下方明细 | 未完成项不得用相邻测试替代 |
| 72 资源约束 | 4/6/10、timeout/idle/log、worktree 12 | 验证/审查日志大小限制、worktree cap 的所有创建路径需补齐 |
| 73–74 Claude 定位、Windows | 核心无 Claude；PowerShell 7，安装器保持 5.1 | 无 |
| 75–77 目录、CLI、manifest | 文件/命令见下方映射 | 示例未逐字照搬：原生模型 ID 为已实测 deepseek-flash；脚本按职责合并 |
| 78 风险登记 | security、OPEN_GAPS 和本表明确已知边界 | R4/R8/R11/R13 等随待办补验收 |
| 79 长期演进 | V2+ 明确排除 | 不实现 MCP facade、常驻服务、远程沙箱或多机器调度 |
| 80–83 不变原则、实施顺序、总结 | 首条真实链路已先验证；不裸 API、不跳 Critical、不伪造证据 | 原则 15/24/30 对应能力降级、跨 worktree 锁与 preflight 缺口仍未闭合 |

所有原文 CLI 入口已存在：`doctor route validate run status watch escalations resolve result logs cost stop resume cleanup`。
新增决策入口：`accept integrate affected replan rollback report-cost record-route repair-integration resolve-review`。

原文按函数拆分的脚本在此实现中按职责合并；统一 CLI 不变，不添加空包装文件：

| 原文入口 | 当前实现 |
|---|---|
| Test-TeamDoctor / Test-DshRoute | Preflight.ps1 同名函数 |
| New-TeamRun | State.ps1 |
| New-Worktree / New-Worker / Wait-Worker | Execution.ps1 的 New-TeamWorktree / Start-TeamWorker / Invoke-TeamDispatch |
| Invoke-DshWorker | Invoke-DshWorker.ps1（独立子进程） |
| Read-WorkerResult | Contracts.ps1 |
| Invoke-Verification | Execution.ps1 的 Invoke-TeamVerification |
| Invoke-ReviewGate | Review.ps1 的 Invoke-TeamReview |
| Invoke-Integration | Integration.ps1；冲突任务在 Conflict.ps1 |
| Invoke-Replan / Stop-Worker | Recovery.ps1 的 Invoke-TeamReplan / Stop-TeamOwnedProcesses |
| Resume-TeamRun / Remove-Worktree | Integration.ps1 的 Resume-TeamRun / Remove-TeamWorktrees |

MVP A–T 的证据层级：A–D 路由为本地真实函数；E/O 合并冲突为真实 Git + 替身 Worker；
F 生产删除只注入声明并验证硬停，不执行生产删除；G/T 错误路由/版本为替身 preflight；
H 进程 timeout 有机械测试，完整超时→replan 仍待验；I 尚待真实 coordinator crash；
J 子 Agent 越权由静态/机械 guard 与 Git 审计测试覆盖，未宣称对抗式 OS 安全；
K 由 schema 拒绝缺失 Critical gate、真实 fresh Critical 链路覆盖；
L 动态费用限制的 soft/hard 运行中收据测试与 native guard 测试已通过；M/N 连续错路由记录已有测试；
P/Q/R/S 为隔离 CLI 测试，其中 S 的 linked-worktree 变体尚缺。
