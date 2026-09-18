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

2026-09-17 人类裁决：保留已实测 L3，明确记录适配器扩展及额外准入条件。
v5 §9 的 I1/O2/E2 原文矩阵仅给 L1/L2；当前 DSH 的原生轴仍如实报告 I1/O2，
不因为 adapter 接受 Task 文件、产出 Result 文件就改称原生 I3/O4。
doctor 的 `matrix_modes` 保留原文决策，`allowed_modes` 单列经此次裁决保留的 L3 扩展，
并用 `adapter_l3_extension=true` 标识。扩展依据是已有真实 fresh/fork 入口与主子路由验收，
以及 schema、Git 审计、原生 registry guard、资源预留共同提供的受控适配路径。

L3 扩展只对实际 DSH 0.1.5-rc.1 / headless / deepseek-official / deepseek-flash 准入；
还要求 manifest 开启子 Agent、两个原生工具与 subagent/spawn/fork provider 服务均可用、guard 文件存在。run 在创建 run/worktree
之前检查，resume 在接续派发之前重新检查；原始 preflight 和最近恢复 preflight 均落入 runtime。
缺失能力返回 20，由 Lead 明确修订计划，不能静默把 L3 改为 L2。版本 override 继续支持
L1/L2 的 UNVERIFIED_RUNTIME 运行，但不会把未知版本的 L3 标记成已验证。
当前 guard 是代码准入与观测机制，不是 OS 沙箱。非空 fork 继承现由独立真实双回合探针验证，
不代表正常单回合 Worker 已自动拥有额外历史；它仍只继承原生定义的已完成父回合前缀。
