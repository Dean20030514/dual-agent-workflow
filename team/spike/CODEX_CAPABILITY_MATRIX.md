# Codex 能力矩阵（2026-09-17）

本机 CLI 0.153.3；当前 Lead 运行在 Codex 原生环境，shell 为 PowerShell 7.6.6。
本任务实际读写源码、执行测试、Git 临时 worktree 验收，证明 shell/script/worktree 接线。

本机 `codex exec --help` 确认 stdin、`--ephemeral`、`--output-schema`、`-s read-only`、
`--json`、`-o`。官方说明：
[Non-interactive mode](https://learn.chatgpt.com/docs/non-interactive-mode)、
[Developer commands](https://learn.chatgpt.com/docs/developer-commands?surface=cli)。

审查默认新进程、全新会话、只读沙箱；白名单材料通过 stdin 传递。
首次真实 probe 的 schema 缺少 boolean type 被 API 拒绝，已补齐；随后文件路径方式
被只读执行策略拒绝，改用 stdin。失败没有被标记通过，也没有放宽沙箱。
真实 Critical 端到端状态见 OPEN_GAPS；替身 gate 接线测试不能证明模型审查质量。
