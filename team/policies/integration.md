# 集成

仅合入 Lead 已 ACCEPTED 的确切 commit，按 DAG 顺序进入 `codex/integration/<run>`。
每次 merge 后 targeted regression，成功才推进 last_good_integration_sha；最后完整回归。
冲突返回 81，保留现场与 `integration-conflict.json` 的文件清单。Lead 用冲突文件加显式
glue scope 形成 integration 角色任务，不得扩大业务需求、改验收或私自修改公共接口。
使用 `repair-integration -Reason ... [-GlueScope ...]` 生成下一 revision 的 bounded Worker，
然后 resume / accept / integrate。它从最近验收 checkpoint 出发，必须将原 incoming commit
纳入祖先链；修复合入后原任务才变成 MERGED。所有计划变更都有 DEC-Integration 记录。
`rollback -Task <last-merged-id> -Reason ...` 使用 revert；未完成 merge 用 abort。
绝不 reset 调用者工作树。回滚与进程恢复是独立操作。
