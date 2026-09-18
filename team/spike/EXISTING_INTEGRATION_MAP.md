# 真实复用路径

| 能力 | 事实源 | Team 落点 |
|---|---|---|
| Routine/Critical、产品 blocking、停止规则 | claude/workflow/AGENTS.md | policies/review-mapping.md |
| 9P/9A/9B 的角色与盲审边界 | claude/workflow/reviewer-prompt.md | scripts/Review.ps1 |
| DSH 原生 fresh/fork、权限继承 | dsh/workflow/fanout-toolchain.md | native-guard.mjs、DSH overlay |
| DSH 专属规则 | dsh/workflow/AGENTS.md | Worker 尊重目标与原生规则 |
| 真实测试证据纪律 | claude/workflow/AGENTS.md、dsh/skills/dual-agent-workflow/references/verification-evidence.md | verification-evidence.json + stdout/stderr |
| 部署与机器态边界 | README.md、docs/ai/AUTHORITY_CONTRACT.md | 不改 installer 和全局运行设置 |

新增的是结构化跨 Harness 传输、运行状态、DAG/worktree、范围审计和原生预算适配；
旧母本的规则不复制成另一份散文判据，未重启封存 H5A validator。

具体审查调用复用 `claude/workflow/reviewer-prompt.md` 的新进程、配置/规则隔离、禁用 memories
和推理档要求（9P medium，9A/9B high）；Team 的参数由 `scripts/Review.ps1` 构造。
Team 按 v5 在 Worker 后做 9A、完整集成后做 9B，各绑定自己的实际 SHA，不声称符合旧流程
“两份实现审查同时绑定同一快照”的额外契约。Team 保留已实测的 read-only/stdin 传输；
不迁移旧模板的 workspace-write 沙箱或触发系统提权。
目标项目若明确要求旧双审同 SHA、人工批准或旧账本，Lead 必须先满足该项目契约再交付；
结构化 Team gate 只证明本运行模式的顺序、隔离与证据绑定，不能自动替它批准这些额外条件。
