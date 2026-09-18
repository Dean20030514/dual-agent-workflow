# 集成

仅合入 Lead 已 ACCEPTED 的确切 commit，按 DAG 顺序进入 `codex/integration/<run>`。
每次 merge 后 targeted regression，成功才推进 last_good_integration_sha；最后完整回归。
冲突返回 81，保留现场与 `integration-conflict.json` 的文件清单。Lead 用冲突文件加显式
glue scope 形成 integration 角色任务，不得扩大业务需求、改验收或私自修改公共接口。
使用 `repair-integration -Reason ... [-GlueScope ...]` 生成下一 revision 的 bounded Worker，
然后 resume / accept / integrate。它从最近验收 checkpoint 出发，必须将原 incoming commit
纳入祖先链；修复合入后原任务才变成 MERGED。所有计划变更都有 DEC-Integration 记录。
`rollback -Task <id> -Reason ...` 对该任务、下游、相交写入范围和相关 Integration 修复
按实际 merge 历史倒序执行 revert，可以选择更早的任务，也可以连续回滚多个检查点。
无关的 MERGED/CLEANED 任务保留。每一步记录意图、原 merge 与 revert SHA；重复回滚已撤销
的检查点会拒绝。没有产生 merge 的空变更任务只改变任务状态，不撤销其他 commit。
已撤销的非空源 commit 不能直接再 merge；必须显式 replan 产生修复，或使用 Integration Worker。
未完成 merge 只有与记录的 source/base 相符才可 abort；revert 冲突保留现场，下一次 rollback
只对本运行已记录的冲突执行 revert --abort。脏树、错误分支和未登记 HEAD 一律拒绝。
全程不 reset，所有操作仅在本 run 的集成 worktree。回滚与进程恢复是独立操作。
合并操作使用 durable intent，恢复核对 exact parents、操作消息、task/attempt/plan 和验证证据。
已知失败的验证不会在 resume 中重跑以替换失败；中断的输出保存在独立目录。
回滚先冻结整个受影响检查点列表，再逐次写入撤销收据、检查点和状态；恢复能接续这项
已授权操作，不重复撤销已完成项。stop 后禁止接续残留回滚，取消状态保持不变。

最终回归失败返回 40，同时生成 `integration-failure.json` 和
`integration-failure-task.json`（draft，不自动派发）。失败记录保存 exact SHA、最近 merge、
当时的全部活动检查点；原始 final 命令、输出和退出码复制到独立 `integration-failures/FAIL-*/`，
后续重试不覆盖。检查点和 targeted 验证分别按 task/attempt/SHA 保存历史，final 验证按 revision/SHA 保存。

存在该失败记录时，每次成功 rollback 后重跑原完整回归并保存独立 probe。
`passes_after_rollback` 只是定位线索；`inconclusive_still_fails` 明确表示不能定位，
可能是缺少已回滚功能或另有故障。两者都不使 REWORK 任务通过验收。

Lead 判断原因后使用 `repair-integration -Task <suspect-id> -Reason ...`：
从该任务的受影响子图及诊断期间实际撤销的任务生成下一 revision 的受限 Integration Worker。
write_scope 来自这些已批准任务，作为本次 Lead Decision 的显式 glue_scope 记录（conflict_files 为空）；
沿用 Integration 角色的 conflict+glue 政策，不扩大角色权限。原 acceptance、targeted 验证及完整回归均进入修复任务，
不会把失败输出改成新验收标准。相关原任务暂为 REPAIRING，无关已集成任务保留；
修复仍须 Git/外部验证/适用审查/Lead accept，合入后相关源任务恢复 MERGED。
只有最终完整回归及适用 fresh 9B 通过，failure 才记 resolved。
`-GlueScope` 仅用于 merge 冲突，回归修复需要额外范围时须单独重规划。
