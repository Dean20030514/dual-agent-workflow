# 首次集成决策：Case B

原仓库已有质量/审查纪律和 DSH 原生工具事实，但没有 Team CLI、schema、状态机、
Git worktree 调度或结构化 Result 适配。先补这些执行前提，再接独立审查。
普通任务沿用 Routine；当前实现任务本身未升级为旧 Critical 流程、未制造旧交接账本。
净收益：减少复杂任务的手工派发与证据搬运，同时让越界、重复派发和未经验证的集成被机械拒绝。
规格中的简略 YAML 示例被补成可执行合同：每个任务必须有 objective/acceptance 和实际
executable/args/timeout 验证命令，不把 `full_test` 这类抽象名称当成存在的命令执行。

实施解释：PowerShell 为控制面；DSH 原生 registry guard 是小型 Cordis overlay，
只管准入和遥测，不执行模型推理。保守预留额度比跨进程抢占协调更容易证明上限。
所有变更留在仓库可见 diff，不部署本机 managed 副本、不修改全局设置。

V1 的结构化 Team 审查使用 Plan/Task/Result/Git/验证产物作为材料；目标仓库若仍要求
旧 Critical 的人工批准/快照账本，必须遵守目标契约，不能靠 Team policy 覆盖。
