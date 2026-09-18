# 激活

无 manifest 或 team.enabled=false：普通 Codex 模式，旧流程照常。
CLI 在当前 manifest 的 enabled=false 时拒绝 run/resume、accept/integrate、replan、
repair-integration、resolve-review、rollback 和 cleanup（exit 20），不进入任务执行路径。
既有运行仍可查询、提交费用事实、记录升级决定和 stop；这些入口不派发 Worker，
关闭开关也不会中途杀掉原来已启动的工作。需要终止时显式 stop。
L0 小且单点；L1 单领域明显工作量；L2 可独立验证的多任务；L3 确实需要原生子 Agent。
`route` 是纯本地启发式，不调用模型或执行仓库脚本。除关键词外，只检查固定领域路径名
（如 frontend、backend、src/components、prisma/schema.prisma），不读项目内容。
模糊实现任务可据这些标记建议 L1/L2，置信度低于 0.8，仍由 Lead 判断；大型仓库中的 typo
不会因此自动升级。生产/凭据等风险另列 risk_flags，不代表已经取得授权。
confidence<0.5 返回 UNKNOWN，0.5–0.8 需 Lead 判断。
`record-route` 记录真实任务期望与结果；连续三次 mismatch 标记 degraded。后续单次匹配只
清零连续次数，不解除降级。route、doctor、run/resume 返回 Lead 提示，执行事件保留通知。
降级期间每个复杂任务显式调用 route。修正后运行 `revalidate-route -Reason '修正说明'`，
它会重跑四个固定示例与本仓库记录的真实任务。全部通过才恢复 normal；失败返回 20，
保留降级和检查结果。每个任务保留最近一次明确期望，修正期望本身必须有事实依据。
历史降级计数若没有任务样本，须先补录受影响任务，不能用固定示例代替它们。
Team Plan 不改变目标仓库的既有审批与发布权限。
