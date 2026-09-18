# 声明与强制

强制：schema、DAG、版本 pin、实际 native 创建模型路由、Agent 数量/深度/cwd、
Git 范围审计、Result 身份、进程超时、单 Run 锁、SHA 验收、外部验证、fresh 审查。

Worker、adapter、外部验证及 Reviewer 的 stdout/stderr 在写入时按 manifest 的
`max_single_log_mb` 截断（默认每个文件 50 MiB）；超限不接受结果，保留已写前缀。
Reviewer 自行写出的 verdict 文件按相同上限轮询检查，超限拒绝审查；轮询期间可短暂超过上限，
这不是直接文件写入的磁盘配额。验证/审查失败收据分别记录控制器结果、进程是否启动和实际退出码。
stdin 异步发送，子进程不读输入也不能阻止控制器开始计时。

进程退出后仍继续检查总超时、idle 和输出上限；管道额外等待最多 3 秒，不把退出码 0
等同于完整输出。未结束的读取/输入发送可取消，前缀日志保留，返回 31；日志写入失败返回 30。
Worker exit、验证证据、审查 attempt 均保存 `transport_cleanup`，记录 drain 是否超时及清理结果；
Worker 的 `native_exit_code` 与适配器 `exit_code` 分别记录。
Windows 清理仍存活的直接子进程时，同时核对父进程生命周期、子 PID 和精确创建时间，再终止该子进程树。
这遵循 [Win32_Process 的 PID 复用说明](https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/win32-process)，
不是按进程名称批量终止。查询/终止失败和身份不符保留为未验证结果；无法关联的退出中间进程的后代、
其他平台的脱离进程仍不保证自动清除，不能声称这里实现了 OS 沙箱或进程 Job 隔离。
已知进程终止失败时记录 `cleanup_pending`，保留 PID、状态与未释放的 Agent 预留；
继续处理其他 Worker。该标记阻断 resume/replan/集成等执行动作（exit 80），事实查询仍可用。
stop 可再次按原身份清理；失败继续保留证据和锁，成功后释放预留并按 stop 的既有语义取消 run。

启动器先创建日志，再启动进程。仅确认 DSH 从未启动时重试一次，每次写独立 launch 收据；
进程已启动、已退出非零或启动结果不明确均不自动重启。两次未启动返回 30 并建立
`worker_start_failure` 升级，释放未使用的 Agent 预留，等待显式决定和 replan。

声明：Worker 的 shell/network/secrets/production 布尔值与细粒度 write_scope 不是 OS 沙箱。
Worktree 只隔离 Git。DSH 原生子 Agent 继承父权限；guard 不能阻止同权限恶意 shell 访问其他目录。
Git 审计会拒绝已提交越界、未提交和未跟踪改动，不能恢复已发生的外部副作用。
需要不可信代码隔离时，应在受限用户/容器/独立机器运行；不得声称本运行器提供了该隔离。

不复制凭据或修改 DSH_HOME；Harness 使用原有登录态。只记录路由/版本和任务证据。
stderr 含模型内部推理，仅留在本地 runtime；review 输入不包含这些日志。
不要提交 runtime、凭据、session 或包含业务数据的原始日志。

DSH Local Review 使用独立原生进程，guard 在 setup 阶段同时隐藏全部工具并注册不可放宽的执行拒绝，
包括后续 scoped/dynamic 工具；收据必须证明单个 depth 0、read_only Agent。
审查前后核对确切 HEAD 和干净工作树；这仍不是操作系统隔离。
Reviewer 单独预留全局 Agent 名额；崩溃恢复读取原进程身份和持久收据，禁止未知结果下重复启动。
stop 同时处理作者及本地 Reviewer；身份清理失败保留预留并阻断 replan，成功才结算。
同快照失败 verdict 原样复用，不能通过重新调用模型抹去失败；额外执行请求须逐项留下处置证据。
