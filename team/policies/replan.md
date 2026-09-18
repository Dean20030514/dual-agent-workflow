# 重规划与恢复

`affected -Plan ... -Task ... -ChangedPaths ...` 返回下游与相交范围候选集，Lead 负责语义确认。
`replan` 必须同 Run、revision+1、说明原因；保留无关任务的内容和 ACCEPTED 状态。
相交范围按路径通配符交集判定，再计算依赖与相交范围的传递闭包；已合入的受影响任务先 rollback。
revision 与 Decision Log 持久化，最多三次 replan；失败尝试最多两次重试。
resume 检查 plan hash、PID+启动时间、exit receipt、Git 与集成 checkpoint；
仍活着的原 Worker 不会重复启动。缺失退出证据返回 80，不猜成功。
计划修订先持久化暂存内容与哈希，再依次提交旧计划存档、新计划、Decision Log 和 state。
持锁命令重放未完成修订；仅接受原版本或该事务准备的新版本，外部改动和缺失证据返回 80。
stop 发送取消请求；运行中 coordinator 杀掉自己创建的进程树并保留证据。

Worker 返回 `status: escalated` 时先完成身份、Git 和范围审计；通过后保存 `worker_request`
升级文件，任务进入 ESCALATED、exit 70，不运行验收命令，也不允许 accept。
升级内容绑定结果哈希、任务、attempt、commit 与风险。resolve 不把旧结果变成成功，
须按决定显式 replan，再 resume；旧 attempt 的结果和日志保留。

同一任务的不同 attempt 若有相同验证命令、参数、退出码及 stdout/stderr 哈希，
第二次失败生成 `repeated_verification_failure` 升级并暂停（原验证返回码仍为 40）。
同一 attempt 的重复协调不重复计数；失败证据不同则重新计数，验证成功则清除计数。
这是相同证据的机械判定，不能替代 Lead 对带时间戳等不同输出的同因判断。
范围违规记 `scope_violation`；计划读取/校验失败记 `plan_invalid`。
还没有 run 时，plan_invalid 只在 CLI JSON 返回，不为错误计划创建运行目录。
