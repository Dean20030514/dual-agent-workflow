# 委派

角色模板是 capability 起点，最终写范围必须由任务明确给出。所有写 Worker 都使用独立 worktree。
L3 的子 Agent 仍为 DSH 原生 Agent，父路由继承，native guard 拒绝换模型、换 cwd、超深度和超数量。
V1 每个 Worker 家族最多三 Agent（含 Worker），深度最多 2；关闭 workflow/ralph 批量旁路。
全 Run 累计与并发分别记账。预留槽位覆盖尚未创建的子 Agent，失败且用量不明时按整个预留计费。
Worker 必须在 Result 汇总子 Agent 类型、目的、权限和范围；实际数量与原生创建记录比对。
