# AI 协作开发工作流 · 入口索引（结构化版；规范版本 = `main` 当前 tip，见 README，本文件不另设版本号）

> 本套工作流已拆分为多个按需加载的文件。**长期规则集中在 `AGENTS.md`（自动生效），各 Phase 拆成 DSH skill 正文（用到才加载）**——DSH 没有 Claude Code 那种 markdown slash command 面（`/command` 由插件注册，纯 markdown 进不去），所以命令 = **本项目 skill 目录 `dsh/skills/dual-agent-workflow/references/phases/*.md`，部署后 = `~/.dsh/skills/`**，会话里说「跑 /plan」即读对应文件。
> 本文件只做总览与导航，不含可执行指令；指令在各 phase 正文里。

> **模式路由（2026-08-05 裁决）**：本命令体系与全部交接产物是 **Critical 模式**的执行细节，仅在人类明确要求时启用。日常任务默认走 **Routine**（Author 改 → 人类扫 diff → 人类 commit/merge，无交接文件要求）——路由定义唯一出处：全局 `dsh/AGENTS.md` → Mode Routing。五规则与 Safety Rules 两种模式恒适用；三闸门按模式取用——Routine：diff 范围与真实退出码闸门适用，无 Reviewer 时审查 SHA 绑定闸门为 N/A；Critical：三个机械闸门全部适用。

## 双 Agent 协作模式

* **Author**（= 当前 DSH 会话的主 agent）：探索、规划、实现、修测试、更新交接文件。**写权只属于 Author。**
* **Reviewer**（= DSH `subagent` 子 agent，或独立 `dsh --profile headless` 进程）：独立轻量审查（9P 计划审 + 9A/9B 实现审）。**零写入**，价值在 fresh context 与独立判断，不替 Author 干活。调用范式见 `reviewer-prompt.md` → 双审隔离协议 ③。
* **人类**：批准计划、检查 diff、决定取舍、最终提交。

## 核心原则（精简）

1. 交接走文件，不靠口头；两 Agent 不共享记忆。
2. 验证产物化：测试输出写文件，下一个 Agent 读文件验证，不信自述。
3. 关键节点用 git 做门：阶段完成必 commit，回滚靠 revert。
4. `IMPLEMENTATION_PLAN.md` 的 Human Approval Status 只能人类编辑。
5. 所有修改可解释、可验证、可回滚。
6. Reviewer 轻量审查：不重建副本/不重装依赖/不重跑全量测试（定义见 `AGENTS.md`）。
7. 先做对的东西再把东西做对：实现前先过 Phase 0（`/define`）。
8. 适用性门控：18 维按任务触发，不相关者标 N/A + 原因；小任务走快速版。
9. 外部制衡（双 Agent + 人类门 + 产物化）+ 内部自律（三处反合理化手法）互补，缺一不可。

> 原理详解（核心原则 9、不降级成本直觉等）见 `~/.dsh/workflow/workflow-design-notes.md`。

## 命令 → 阶段 → 文件对照

| 阶段 | 命令 | 正文文件 | 输出落点 |
|------|------|---------|---------|
| Phase 0 产品定义 | `/define` | `~/.dsh/skills/dual-agent-workflow/references/phases/define.md` | PRODUCT_BRIEF / TASK_BRIEF |
| Phase 1 只读探索 | `/explore` | `~/.dsh/skills/dual-agent-workflow/references/phases/explore.md` | 探索输出 → PLAN 起草 |
| Phase 2 正式规划 | `/plan` | `~/.dsh/skills/dual-agent-workflow/references/phases/plan.md` | IMPLEMENTATION_PLAN（Pending）+ 9P 计划审 verdict（review_9P）|
| 设计层闸门 | `/design-check` | `~/.dsh/skills/dual-agent-workflow/references/phases/design-check.md` | HANDOFF Quality Gates |
| Phase 3 实现 | `/implement` | `~/.dsh/skills/dual-agent-workflow/references/phases/implement.md` | 代码 + last_test_run.txt + HANDOFF |
| 调试（横切）| `/debug` | `~/.dsh/skills/dual-agent-workflow/references/phases/debug.md` | 修复 + 回归用例 |
| Phase 4 最终审查 | `/final-review` | `~/.dsh/skills/dual-agent-workflow/references/phases/final-review.md` | Final Verdict + PR Description |

## 不走命令的长期/共享内容

| 内容 | 文件 |
|------|------|
| Safety Rules / [DEBT] / Reviewer 协议 / 证据假设标签 / Git 纪律 / DSH Runner | `AGENTS.md` |
| 四个交接文件模板 | `~/.dsh/workflow/templates/`（项目内落到 `docs/ai/`） |
| 横切质量·安全·隐私·可访问性清单 + 设计闸门（供 Reviewer 读） | `~/.dsh/workflow/QUALITY_GATES.md`（项目内落到 `docs/ai/QUALITY_GATES.md`） |
| Reviewer 独立审查 prompt（9P/9A/9B，投给 DSH subagent / headless 进程） | `reviewer-prompt.md` |
| 最终完成标准 | 见 `~/.dsh/skills/dual-agent-workflow/references/phases/final-review.md` 末尾 |
| 小任务快速版 | 见 `~/.dsh/skills/dual-agent-workflow/references/phases/implement.md` 的「快速版」节 |
| 设计原理 / 文档维护规范 | `~/.dsh/workflow/workflow-design-notes.md` |
