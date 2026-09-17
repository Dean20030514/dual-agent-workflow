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
