# 声明与强制

强制：schema、DAG、版本 pin、实际 native 创建模型路由、Agent 数量/深度/cwd、
Git 范围审计、Result 身份、进程超时、单 Run 锁、SHA 验收、外部验证、fresh 审查。

声明：Worker 的 shell/network/secrets/production 布尔值与细粒度 write_scope 不是 OS 沙箱。
Worktree 只隔离 Git。DSH 原生子 Agent 继承父权限；guard 不能阻止同权限恶意 shell 访问其他目录。
Git 审计会拒绝已提交越界、未提交和未跟踪改动，不能恢复已发生的外部副作用。
需要不可信代码隔离时，应在受限用户/容器/独立机器运行；不得声称本运行器提供了该隔离。

不复制凭据或修改 DSH_HOME；Harness 使用原有登录态。只记录路由/版本和任务证据。
stderr 含模型内部推理，仅留在本地 runtime；review 输入不包含这些日志。
不要提交 runtime、凭据、session 或包含业务数据的原始日志。
