# 双 Agent 协作开发工作流（Claude Code Author × Codex Reviewer）

个人开发工作流的母本镜像。活母本安装在本机 `~/.claude/` 与 `~/.codex/`，本仓库是其发布快照——**以本机安装为准，本仓库不独立演进**。

## 布局与安装位置

| 目录 | 安装到 | 内容 |
|------|--------|------|
| `claude/workflow/` | `~/.claude/workflow/` | 母本核心：`AGENTS.md`（Safety Rules / Reviewer 零写入 / `[DEBT]` 零暗债 / Payback-on-Touch，禁止事项唯一出处）· `index.md`（阶段↔命令↔产出导航）· `reviewer-prompt.md`（9A 标准审 + 9B 盲审 prompt、输出契约、双审隔离协议、审前快照绑定）· `QUALITY_GATES.md`（质量/安全/隐私/可访问性横切清单 + 设计闸门）· `AB-model-diagnostic.md`（模型判因实验设计）· `workflow-design-notes.md`（设计原理，维护者读）· `templates/`（TASK_BRIEF / IMPLEMENTATION_PLAN / HANDOFF / PRODUCT_BRIEF 骨架） |
| `claude/commands/` | `~/.claude/commands/` | 7 个阶段 slash command：`/define` `/explore` `/plan` `/design-check` `/implement` `/debug` `/final-review` |
| `codex/` | `~/.codex/` | Reviewer（Codex CLI）侧长期规则 |
| `portable/` | — | 便携单文件版 v3.1（**旧快照**：零写入、快照绑定等新机制尚未移植；v3.2 受控迁移待母本全部前置任务闭合后执行，勿手改此文件补课） |

## 核心机制（2026-07 版）

- **交接走文件、验证产物化**：所有交接经 `docs/ai/`，测试输出落 `last_test_run.txt`，下一个 Agent 读产物不信自述；git 作阶段门，回滚靠 revert。
- **Reviewer 零仓库写入 + 双审隔离**：9B 盲审先行、9A 对照审后行，verdict 与 raw log 一律写仓外 holding；审查正文前强制快照自检（`review_tip_sha` / `handoff_snapshot_sha` 等 SHA 绑定，不一致即拒审）。
- **Fix-Loop 外部化硬停**：每条 blocking 由 Reviewer 判 `caused_by_last_fix` 归因并计 streak，达阈值 Author 立即停手交人类，禁止原上下文滚补丁。
- **零暗债**：任何妥协要么当场修，要么写成带偿还触发器的 `[DEBT]` 明账；触碰挂债文件必须同 commit 偿还（Payback-on-Touch）。
- **守护有效性契约**（进行中）：回归用例必须实证"变异后因预期断言而红→恢复后绿→真实退出码→按构建系统提供缓存旁路或等价执行真实性证据"。

## 快照状态（2026-07-30）

守护有效性契约任务在审中——本快照已包含其对 `AGENTS.md` / `reviewer-prompt.md` / `QUALITY_GATES.md` / `templates/HANDOFF.md` / `commands/{debug,implement}.md` 的改动，**尚未通过独立复审**；复审闭合后会再同步一次。历史基线（2026-06-25 的 v3.1 拆分版）保留在本仓库首个 commit。
