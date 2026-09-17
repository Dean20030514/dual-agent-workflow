# 激活

无 manifest 或 team.enabled=false：普通 Codex 模式，旧流程照常。
CLI 在当前 manifest 的 enabled=false 时拒绝 run/resume、accept/integrate、replan、
repair-integration、resolve-review、rollback 和 cleanup（exit 20），不进入任务执行路径。
既有运行仍可查询、提交费用事实、记录升级决定和 stop；这些入口不派发 Worker，
关闭开关也不会中途杀掉原来已启动的工作。需要终止时显式 stop。
L0 小且单点；L1 单领域明显工作量；L2 可独立验证的多任务；L3 确实需要原生子 Agent。
`route` 是关键词启发式，不调用模型。confidence<0.5 返回 UNKNOWN，0.5–0.8 需 Lead 判断。
`record-route` 记录真实任务期望与结果；连续三次 mismatch 标记 degraded。
Team Plan 不改变目标仓库的既有审批与发布权限。
