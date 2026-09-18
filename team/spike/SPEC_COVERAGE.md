# v5 范围核对（持续更新）

来源：`Codex_DSH_Dynamic_Agent_Team_Final_v5.md`，SHA-256 见 README。
本表用于防止把已完成的单链路验收当成整份规范完成。`已有`表示代码/文件已实现，
不代表所有运行环境均已验收；真实 Harness、替身 CLI、静态检查分别记录。
当前整份文档状态：**未完成**。既有真实验收见 [ACCEPTANCE](ACCEPTANCE.md)。

| 原文章节 | 对应实现/证据 | 尚需补齐或确认 |
|---|---|---|
| 0–4 架构、自治、Ground Truth、角色 | 原生 Codex/DSH、PS 控制面、Git/外部验证、SHA 验收；独立 DSH Local Review 必经阶段，真实 LOCAL-NATIVE-013 完成交付 | 本地审查不替代 Critical Codex 9A/9B |
| 5 逻辑别名、版本 pin、override | manifest、Preflight；真实 doctor 与错误版本 fixture | 当前只认证精确版本，未宣称更宽区间 |
| 6 复用质量规则 | ReviewRounds 按已审 revision 聚合 9A/9B；逐问题归因/去重、争议裁决、streak/三轮上限/early-stop；真实两次 9A 失败→修复通过 | Team 两阶段映射不替代目标项目旧双审同 SHA 等额外要求；活动旧计数拒绝静默重置 |
| 7–9 能力 Spike、降级矩阵 | 8 份 Spike 文档；L1/L2、fresh child、fork 空/非空前缀、Critical 真实验收；doctor 矩阵与 run/resume 准入接线；人类裁决保留明确标记的 L3 适配器扩展 | 原生 I1/O2 未改称 I3/O4；非空 fork 为专门双回合探针，不把普通单回合 Worker 声称为自动继承历史 |
| 10–13 L0–L3、纯本地 route、misroute | Core/Preflight、固定领域路径 metadata 与风险标记、4 固定路由 fixture、连续 3 次降级；route/doctor/run/resume 通知；revalidate-route 重放固定与真实任务 | 本地启发式不替代 Lead 判断；验证结果见 ACCEPTANCE |
| 14–16 计划与分阶段上下文发现 | Lead policy 明确顺序和最多 2 次修复；无效计划 exit 10 + `plan_invalid`，无 run 时只返回 JSON | 无 |
| 17 Team Plan、DAG | team-plan schema、Contracts、真实 Git 的 DAG fixture | 无 |
| 18–19 19 种角色与 role schema | 19 种领域能力/验证建议/指导；run 冻结定义，Task Packet 携带；真实 backend/frontend Worker 已验收 | 默认值是规划建议，不扩张具体 Task 的有效权限 |
| 20 Integration 约束 | 完整角色合同进入 schema/packet；必须来自已记录冲突或回归，scope 绑定 conflict+显式 glue 决定；真实 Integration Worker 保留合同 | 接口/测试的语义判断由 Lead 审核，机械门负责范围和源提交祖先关系 |
| 21–22 子 Agent 权限/深度/三种限额 | native guard 准入、实际创建记录、Result/Git 审计 | 权限为声明+原生继承，非 OS 沙箱；全局并发采取家族保守预留，尚无真实多 Worker+子 Agent 联合验收 |
| 23–25 worktree/base/cleanup | 冻结 base、依赖从集成 SHA、MERGED 清理；replan 归档 DISCARDED，干净且身份匹配才清理；Git fixture 覆盖删除任务、脏目录、重复修订与替换恢复 | 废弃分支及证据保留，不强删脏 worktree |
| 26–30 Packet、范围、启动 | schemas、adapter、Git diff 范围审计、`scope_violation` 事件；真实 L1；确认未启动才重试一次，逐次 launch 收据及二次失败升级 | 重试为本地真实进程/故障注入验收，不声称模拟了原生服务端故障 |
| 31–32 状态机、原子持久化 | State、Core 原子替换；state schema 约束任务状态、SHA、计数、恢复必填字段 | 各持久化步骤间的中断点尚未逐一注入 |
| 33 恢复 | PID+UTC ticks、native PID、exit receipt、Result、Git、events、集成 checkpoint；CRASH-NATIVE-011 在真实 DSH 等待点终止 coordinator 后单 attempt 恢复并集成；独立 Local Review 的崩溃/stop 由真实进程与替身 CLI 验证 | checkpoint 落盘窗口自动协调尚待补齐；一次进程崩溃点不代表全部持久化窗口 |
| 34–35 受影响子图、修订、保留 ACCEPTED | Contracts/Recovery；精确通配符交集、依赖及相交范围传递闭包；fixture 保留无关 ACCEPTED；affected 无具体路径时与 replan 使用相同候选集 | 范围是确定性候选，最终语义确认仍由 Lead 完成；计划/状态跨文件中断验收另见 31–33 |
| 36–38 fresh review、输入白名单、9P/A/B | 独立 Codex exec、stdin 白名单、read-only；真实 Critical 完成 | 需核对目标仓库旧 Critical 规则兼容性，不能以隔离 fixture 代替任意项目 |
| 39 硬停 | hard_stop、ESCALATED、禁止下游；连续两轮 yes 硬停优先于轮次出口；CLI 反例覆盖 | 硬停后新任务的重拆/架构批准仍属于人类决策，不自动清除 hard_stop |
| 40 验证顺序 | self-check→Git→外部命令→独立 DSH Local Review→Critical 9A（如适用）→Lead accept | 无 |
| 41–43 集成/定位/rollback | DAG merge、task/attempt/SHA 检查点历史；按受影响子图倒序/连续 revert；原失败与 probe 保留；生成 Regression Task 并接入 Integration Worker；隔离 CLI 和真实 DSH 修复验收 | probe 是定位线索，失败可能来自缺失功能；V1 不自动宣称因果或运行完整 git bisect |
| 44 失败目录 | Worker escalated Result 真实验收；跨 attempt 相同验证失败二次升级；启动二次失败升级且不消费 Agent；同类 scope/timeout/invalid Result/review/missing evidence 二次升级，Critical scope 首次升级；重复恢复不重复计数 | 不同输出是否同因仍由 Lead 判断；故障升级由进程/Git/替身 CLI 验证 |
| 45 返回码 | team.ps1 统一 0/10/20/30/31/40/50/60/70/80/81/82/90 | 需确保异常恢复分支不会把可诊断错误误记 90 |
| 46、71 费用软/硬限制 | Controls 收据队列；dispatch 与 native guard 动态读取 | 原生账单仍未知，人工录入有时间差；不得把 unknown usage 宣称为金额硬上限保证 |
| 47–48 观察命令/watch | status/watch/escalations/cost/logs，Json、Since、Task、Follow | 终止/过滤语义仍需专门 CLI 验收 |
| 49–50 升级与处理 | plan hash 绑定、approve/reject/modify-plan、过期保持 PAUSED | 24h 为下次控制命令检查，无后台守护进程；等待期间本已停止派发 |
| 51 disabled | 执行/验收/修订/清理命令统一拒绝，route 返回 L0；stop 和事实查询仍可用；CLI fixture 覆盖 | 关闭开关不会主动终止已经启动的进程，须 stop |
| 52–53 单 run、锁 | coordinator 排他文件句柄、持久 run 锁、terminal stale repair；禁止 linked worktree 另建 run | 当前只允许主仓库根目录作为控制根，linked worktree 内调用必须显式指向主根目录 |
| 54–57 Lead、AGENTS、既有规则映射 | root/codex AGENTS hook、Lead policy、Case B/map | 未部署本机全局副本；项目契约优先 |
| 58–59 QUICKSTART/首条链路 | QUICKSTART 含能力矩阵、Task/Result 示例及操作链路，真实 SQL-SMOKE-001 | 无 |
| 60–69 Phase 0–8 | 单/双 Worker、worktree、验证、fresh/fork 子 Agent、Critical 有真实证据；coordinator crash 已有真实 DSH 保活/恢复/集成验收；doctor.route 含 input/output/exit axes | 真实多 Worker 的依赖串接、真实模型 crash 后需要 replan 的组合仍待验 |
| 70 A–T 验收矩阵 | 见下方明细 | 未完成项不得用相邻测试替代 |
| 72 资源约束 | 4/6/10；Worker/验证/审查 stdout 与 stderr 写入时有界；异步 stdin、timeout/idle；所有 Team worktree 创建路径共享 12 目录限制；父进程退出后继续限时 drain、取消未完成流；Windows 按身份清理可确认的直接子进程树 | 直接 verdict 文件仅轮询上限；无法关联的退出中间进程之后代及其他平台脱离进程，不保证自动清除；不宣称任意子进程树均已受控 |
| 73–74 Claude 定位、Windows | 核心无 Claude；PowerShell 7，安装器保持 5.1 | 无 |
| 75–77 目录、CLI、manifest | 文件/命令见下方映射 | 示例未逐字照搬：原生模型 ID 为已实测 deepseek-flash；脚本按职责合并 |
| 78 风险登记 | security、OPEN_GAPS 和本表明确已知边界 | R4/R8/R11/R13 等随待办补验收 |
| 79 长期演进 | V2+ 明确排除 | 不实现 MCP facade、常驻服务、远程沙箱或多机器调度 |
| 80–83 不变原则、实施顺序、总结 | 首条真实链路已先验证；不裸 API、不跳 Critical、不伪造证据；原则 24 跨 worktree 锁旁路已关闭；原则 15/30 的矩阵与 preflight 准入已接线 | L3 扩展遵守此次人类裁决，不将局部验收表述为整份规范完成 |

所有原文 CLI 入口已存在：`doctor route validate run status watch escalations resolve result logs cost stop resume cleanup`。
新增决策入口：`accept integrate affected replan rollback report-cost record-route revalidate-route repair-integration resolve-review`。

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
| DSH Local Review | LocalReview.ps1；独立 Invoke-DshWorker.ps1 local-review 模式 |
| Invoke-Integration | Integration.ps1；冲突任务在 Conflict.ps1 |
| Invoke-Replan / Stop-Worker | Recovery.ps1 的 Invoke-TeamReplan / Stop-TeamOwnedProcesses |
| Resume-TeamRun / Remove-Worktree | Integration.ps1 的 Resume-TeamRun / Remove-TeamWorktrees |

MVP A–T 的证据层级：A–D 路由为本地真实函数；E/O 含真实 Git + 替身 Worker，以及 ROLES-NATIVE-006 的真实 DSH 集成 Worker；
F 生产删除只注入声明并验证硬停，不执行生产删除；G/T 错误路由/版本为替身 preflight；
H 进程 timeout 有机械测试，完整超时→replan 仍待验；I 已实际终止 coordinator，并分别保留替身 Worker 与真实 DSH Worker，验证存活时拒绝恢复、结束后接续且无重复派发；
J 子 Agent 越权由静态/机械 guard 与 Git 审计测试覆盖，未宣称对抗式 OS 安全；
K 由 schema 拒绝缺失 Critical gate、真实 fresh Critical 链路覆盖；
L 动态费用限制的 soft/hard 运行中收据测试与 native guard 测试已通过；M/N 连续错路由记录已有测试；
P/Q/R/S 为隔离 CLI 测试，S 含 linked-worktree 变体。
