# 验收边界

已证实：真实 DSH L1 全链路、L3 单 Worker 加原生 fresh 子 Agent 的完整交付、真实 native 主/子 Agent 路由记录；
真实 L2 双 Worker 并行交付、原生 subagent_fork 入口（空前缀）的完整交付；
schema/DAG/范围/锁/进程超时的机械测试；使用替身 CLI 的 L2 DAG 与 Critical gate 接线。
当前测试数与最终结果由本任务的实际输出记录，不把历史通过数当本次回归结论。

真实 DAG-NATIVE-015 还完成两个父 Worker 各创建一个子代理的并发观测、idle timeout 后显式
replan、保留无关 ACCEPTED、下游从已集成 SHA 启动及 14 案例最终回归。首次 TOTAL 超时保留，
第二次直接实现不再委派；不是两个首轮家族均成功。累计保守记账 10、不同原生身份 9。
持久化事务专项已实际运行：28 项覆盖集成/修订/回滚写入边界、批量撤销和负向证据检查；
另 2 项覆盖取消后的残留回滚及终态保护，分批通过，未跳过所选用例。
这些是临时 Git 上的确定性落盘状态注入，不是额外付费模型调用或物理断电测试。
Defender 阻塞由用户在本机显式允许 ApexToolkit.A 检测类别后解除，实时防护仍开启；
安全情报更新本身未解决拦截，历次失败仍保留在 ACCEPTANCE。
该允许不限于单个测试文件，不代表微软确认误报，也不随仓库部署。

真实独立 DSH Local Review 已由 LOCAL-NATIVE-013 验证：作者与 Reviewer 为不同原生 session，
后者禁用工具、提出一项 Git 补证，经外部进程实跑后复用原 verdict，Lead 验收并完成集成。
本地 Reviewer 中断/恢复、stop、拒绝写入及 DISCARDED 清理由真实进程/Git 加替身 CLI 验证，
不将这些故障注入称为真实模型故障验收。

真实 Critical 端到端已完成：`CRITICAL-SMOKE-002` 的 9P、9A、fresh 9B 均返回 pass，
9P 的未来实现检查以技术理由逐项处置，9A 要求的 git status 检查实际执行 exit 0；
9B 无 Blocking/VN，run=COMPLETED。首次 schema 与仓外读取失败仍保留，未伪装为通过。
这证明的是隔离 SQL fixture 的 Harness/审查/恢复协议，不代表任意业务项目质量已被保证。

固有边界：

- Lead 检查使用当前 Codex 会话的活动轮次元数据，不把配置字符串当作证明；本地文件不是服务端签名，也不能抵御同权限恶意修改。
- Plan 临时角色的首次派发、独立审查和集成已由 DYNAMIC-NATIVE-016 真实 DSH 小任务验证；修订新 ID 与恢复由替身 CLI 验证。它不扩张 Task 权限，也不等于增加 OS 沙箱。
- Worktree 不是 OS 沙箱；声明的网络/凭据权限不等于操作系统阻断。
- CLI headless 不给出完整金额账单。cost 明确 unknown_usage=true，外部账单按 Astra Credits / DeepSeek USD 分账录入，保留 source 与唯一 evidence hash；不把未知费用记作零，不合并单位。
- 版本 pin 是已测试单版本，不代表整个语义版本区间都兼容。
- certifications 将已登记版本/profile/路由/guard 哈希与历史验收索引数据化；更换记录不等于自动重验，也不是服务端签名。
- 默认累计预算包含必需作者和 Local Reviewer，但不保证任意重试次数都能完成；可选任务因余量不足而未派发时仍需 Lead 明确 replan。
- DSH I1 输入仍受命令行长度约束，已在启动前拒绝超限，日志摘录不会替代完整 diff；超大规则或 diff 需拆分任务，未新增文件/stdin Harness 输入能力。
- run-base 规则冻结和治理变更新鲜审查已接线；本轮治理自审反例由替身 CLI 验证，未再次付费运行 Codex 9A。不能把规则隔离提示当作对任意提示注入的安全证明。
- 新审查双份保存原始 holding 与规范封存，不依赖系统临时目录；缺少冻结规则/封存证据的旧运行须保留并另建明确计划的 run，不能伪造历史通过链。
- 原生 fork 的空前缀与非空已完成父回合继承均已实测；正常 headless Worker 仍为单回合，
  不自动获得此前会话。双回合探针只验证原生继承行为，不扩张 Reviewer 的 fresh 规则。
- 替身 Critical 接线测试不代表真实模型审查质量，更不等于用户项目的业务验收。
- runtime/原生会话/仓外 holding 是本地证据，不随仓库部署；不要将其中的推理与私有数据公开。
