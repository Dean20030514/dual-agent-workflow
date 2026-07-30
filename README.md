# 双 Agent 协作开发工作流（Claude Code Author × Codex Reviewer）

个人开发工作流 + Claude Code 全局配置的母本镜像。活母本安装在本机 `~/.claude/` 与 `~/.codex/`，本仓库是其发布快照——**以本机安装为准，本仓库不独立演进**。

## 一键部署（新设备）

```powershell
git clone https://github.com/Dean20030514/dual-agent-workflow.git
cd dual-agent-workflow
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

脚本（PowerShell 5.1 兼容）会：备份现有目标为 `*.bak-<时间戳>` → 部署全局 CLAUDE.md / settings.json / rules / workflow / commands → 部署 Codex 侧 AGENTS.md（config.toml 仅在缺失时用 example 播种）→ 安装 5 个官方插件（`context7` `chrome-devtools-mcp` `pyright-lsp` `typescript-lsp` `frontend-design`；无 claude CLI 时打印手动命令）。

**刻意不部署**（换设备需自行私有迁移或重新登录）：`.credentials.json` / `~/.claude.json` / `~/.codex/auth.json` 等凭据与登录态；session/日志/缓存等机器状态；`settings.local.json`（本机临时授权）；**auto-memory**（`~/.claude/projects/*/memory`，含私有项目内情，不进公开仓库——需要时整目录自行拷贝）。

## 布局与安装位置

| 目录/文件 | 安装到 | 内容 |
|------|--------|------|
| `claude/CLAUDE.md` | `~/.claude/CLAUDE.md` | 全局指令（跨项目红线 + 工作流导航，每会话自动加载） |
| `claude/settings.json` | `~/.claude/settings.json` | 权限白名单、启用插件清单、偏好（无凭据） |
| `claude/rules/` | `~/.claude/rules/` | 自动加载规则包：`common/` + 14 个语言/领域目录（79 文件） |
| `claude/workflow/` | `~/.claude/workflow/` | 母本核心：`AGENTS.md`（Safety Rules / Reviewer 零写入 / `[DEBT]` 零暗债 / Payback-on-Touch，禁止事项唯一出处）· `index.md`（阶段↔命令↔产出导航）· `reviewer-prompt.md`（9A 标准审 + 9B 盲审 prompt、输出契约、双审隔离协议、审前快照绑定）· `QUALITY_GATES.md`（质量/安全/隐私/可访问性横切清单 + 设计闸门）· `AB-model-diagnostic.md` · `workflow-design-notes.md` · `templates/`（TASK_BRIEF / IMPLEMENTATION_PLAN / HANDOFF / PRODUCT_BRIEF 骨架） |
| `claude/commands/` | `~/.claude/commands/` | 7 个阶段 slash command：`/define` `/explore` `/plan` `/design-check` `/implement` `/debug` `/final-review` |
| `codex/AGENTS.md` | `~/.codex/AGENTS.md` | Reviewer（Codex CLI）侧长期规则 |
| `codex/config.example.toml` | `~/.codex/config.toml`（缺失时播种） | Codex 持久偏好（信任目录表等本机生成段刻意省略） |
| `portable/` | — | 便携单文件版 v3.1（**旧快照**：零写入、快照绑定等新机制尚未移植；v3.2 受控迁移待母本全部前置任务闭合后执行，勿手改此文件补课） |
| `install.ps1` | — | 上述一切的一键部署脚本 |

## 核心机制（2026-07 版）

- **交接走文件、验证产物化**：所有交接经 `docs/ai/`，测试输出落 `last_test_run.txt`，下一个 Agent 读产物不信自述；git 作阶段门，回滚靠 revert。
- **Reviewer 零仓库写入 + 双审隔离**：9B 盲审先行、9A 对照审后行，verdict 与 raw log 一律写仓外 holding；审查正文前强制快照自检（`review_tip_sha` / `handoff_snapshot_sha` 等 SHA 绑定，不一致即拒审）。
- **Fix-Loop 外部化硬停**：每条 blocking 由 Reviewer 判 `caused_by_last_fix` 归因并计 streak，达阈值 Author 立即停手交人类，禁止原上下文滚补丁。
- **零暗债**：任何妥协要么当场修，要么写成带偿还触发器的 `[DEBT]` 明账；触碰挂债文件必须同 commit 偿还（Payback-on-Touch）。
- **守护有效性契约**（进行中）：回归用例必须实证"变异后因预期断言而红→恢复后绿→真实退出码→按构建系统提供缓存旁路或等价执行真实性证据"。

## 快照状态（2026-07-30）

守护有效性契约任务在审中——本快照已包含其对 `AGENTS.md` / `reviewer-prompt.md` / `QUALITY_GATES.md` / `templates/HANDOFF.md` / `commands/{debug,implement}.md` 的改动，**尚未通过独立复审**；复审闭合后会再同步一次。历史基线（2026-06-25 的 v3.1 拆分版）保留在本仓库首个 commit。`~/.claude/rules-archived-zh/`（已退役的中文规则包）与本地演练证据 archive 刻意不发布。
