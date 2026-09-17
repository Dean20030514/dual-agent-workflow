# 重规划与恢复

`affected -Plan ... -Task ... -ChangedPaths ...` 返回下游与相交范围候选集，Lead 负责语义确认。
`replan` 必须同 Run、revision+1、说明原因；保留无关任务的内容和 ACCEPTED 状态。
相交范围按固定前缀保守判定；已合入的受影响任务先 rollback。
revision 与 Decision Log 持久化，最多三次 replan；失败尝试最多两次重试。
resume 检查 plan hash、PID+启动时间、exit receipt、Git 与集成 checkpoint；
仍活着的原 Worker 不会重复启动。缺失退出证据返回 80，不猜成功。
stop 发送取消请求；运行中 coordinator 杀掉自己创建的进程树并保留证据。
