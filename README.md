# 双 Agent 协作开发工作流（Author × Reviewer；Claude Code / DSH 两套落地）

个人双 Agent 工作流 + Claude Code/Codex 全局配置的**规范事实源（canonical source）**。当前规范版本 = **`main` 当前 tip**；历史可部署版本仅限**明确标记为可部署、且指向 `main` first-parent 集成边界的 release/config tag**（此类 tag 目前尚未登记——登记约定建立前，可部署集合即 `main` 当前 tip）。其余一切 commit/tag——`main` 可达但属 topic 分支中间态的 commit、未合入的分支与 commit、以及迁移基线、评测、取证、归档等历史用途锚点——**仅作证据或候选，不代表当前可部署版本**。

本机 `~/.claude/`、`~/.codex/` 与 `~/.dsh/` 中**由部署器持续镜像/覆盖的路径**（下方「布局与安装位置」表的安装目标；**`~/.codex/config.toml` 除外**——它仅在缺失时播种，创建后即属 machine-local，不受持续镜像管理）是本仓库的运行副本；其余机器态——凭据、登录态、session/日志/缓存、`settings.local.json`、`~/.dsh/settings.yaml`、私有 auto-memory 及其他明确 machine-local / keep-local-only 内容——不属于部署副本、不要求晋升。迁移期间运行副本可暂含尚未晋升的 candidate overlay；任何针对**受管部署面的可复用本机修改**均视为 candidate overlay（候选增强/应急补丁），须先经仓库可见 diff、审查与版本绑定完成晋升，方构成规范版本并部署回本机。在 H3 提供真实 `-DryRun`/`-ValidateOnly` 前，`install.ps1` 保持迁移安全锁定（见下方警告）。

> **两套落地、一套纪律（2026-09-06）**：`claude/` 是 Claude Code（Author）+ Codex CLI（Reviewer）落地；`dsh/` 是 **DeepSeek Harness** 落地——**Author 与 Reviewer 都是 deepseek/dsh**（Author = 当前 DSH 会话主 agent；Reviewer = `subagent` 子 agent 或 `dsh --profile headless` 独立进程），模型档统一 `provider: deepseek-official` + `model: deepseek-flash`（= DeepSeek-V4.1-Flash）。**两套的规则判据与阈值一致，只允许"怎么跑"不同**（命令形态、Reviewer 进程形态、推理档）；`dsh/workflow/AGENTS.md` 是 DSH 会话的判据唯一出处，冲突时以它为准。DSH 侧的关键差异：**没有 Codex 进程沙箱兜底**——Reviewer 同机同权限、技术上写得到仓库，因此零写入从"沙箱帮你挡"变成"纪律 + verdict 的 `writes_performed` 字段自证"，违反即该轮审查作废重跑。

## 一键部署（新设备）

```powershell
git clone https://github.com/Dean20030514/dual-agent-workflow.git
cd dual-agent-workflow
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

> **⚠️ 迁移期安全锁定（临时）**：安装器当前处于 snapshot-first 迁移锁定状态，**上面的一键命令会被脚本直接拒绝**。它的真实语义是 **mirror-replace** 本机受管目录（`~/.claude/{rules,workflow,commands}`，含其中仅存在于本机的内容如 `workflow/archive/**`）、覆盖 `~/.codex/AGENTS.md`，并镜像 `~/.dsh/AGENTS.md` / `~/.dsh/workflow/` / `~/.dsh/skills/{dual-agent-workflow,independent-review}/`（`~/.dsh` 为 harness home）。**关于机器态，分两句说清（2026-09-06 修正：原文"从不触碰"与代码不符）**：脚本**只读写受管路径**，`settings.yaml`、`sessions/`、`storages/`、`profiles/`、凭据**不被修改或删除**；**但脚本会先把整个 `~/.dsh` 整树备份为 `~/.dsh.bak-<时间戳>`**，因此那些文件会**被复制一份**到备份目录（且不自动清理——人类确认后自行删除）。要避免复制凭据，需先修 `install.ps1`（已登记为 `[DEBT]`）；未知参数（如 `-DryRun`，尚未实现）会在参数绑定阶段直接失败。只有在明确接受上述覆盖语义时，才手动附加确认开关 `-IUnderstandThisReplacesLiveConfig`（这是破坏性确认，不是常规默认参数，故不写入上方示例）。待 H3 提供真实 `-DryRun`/`-ValidateOnly` 与 keep-local-only 保护后，此锁定与本说明一并移除。

脚本（PowerShell 5.1 兼容）会：备份现有目标为 `*.bak-<时间戳>` → 部署全局 CLAUDE.md / settings.json / rules / workflow / commands → 部署 Codex 侧 AGENTS.md（config.toml 仅在缺失时用 example 播种）→ 部署 DSH 侧 `AGENTS.md` / `workflow/` / 本工作流自有的两个 skill 目录 → 安装 5 个官方插件（`context7` `chrome-devtools-mcp` `pyright-lsp` `typescript-lsp` `frontend-design`；无 claude CLI 时打印手动命令）。

**刻意不部署**（换设备需自行私有迁移或重新登录）：`.credentials.json` / `~/.claude.json` / `~/.codex/auth.json` / `~/.dsh/.credentials.yaml` 等凭据与登录态（**注**：`install.ps1` 不修改它们，但整树备份会把它们复制进 `~/.dsh.bak-<时间戳>`，见上方锁定说明）；session/日志/缓存等机器状态；`settings.local.json`（本机临时授权）；**`~/.dsh/settings.yaml`**（本机用户设置：权限预设、模型白名单）；**auto-memory**（`~/.claude/projects/*/memory`，含私有项目内情，不进公开仓库——需要时整目录自行拷贝）。

## 布局与安装位置

| 目录/文件 | 安装到 | 内容 |
|------|--------|------|
| `claude/CLAUDE.md` | `~/.claude/CLAUDE.md` | 全局指令（跨项目红线 + 工作流导航，每会话自动加载） |
| `claude/settings.json` | `~/.claude/settings.json` | 权限白名单、启用插件清单、偏好（无凭据） |
| `claude/rules/` | `~/.claude/rules/` | 自动加载规则包：`common/` + 14 个语言/领域目录（79 文件） |
| `claude/workflow/` | `~/.claude/workflow/` | 母本核心：`AGENTS.md`（Safety Rules / Reviewer 零写入 / `[DEBT]` 零暗债 / Payback-on-Touch，禁止事项唯一出处）· `index.md`（阶段↔命令↔产出导航）· `reviewer-prompt.md`（9P 计划审 + 9A 标准审 + 9B 盲审 prompt、输出契约、双审隔离协议、审前快照绑定）· `QUALITY_GATES.md`（质量/安全/隐私/可访问性横切清单 + 设计闸门）· `AB-model-diagnostic.md` · `workflow-design-notes.md` · `templates/`（TASK_BRIEF / IMPLEMENTATION_PLAN / HANDOFF / PRODUCT_BRIEF 骨架） |
| `claude/commands/` | `~/.claude/commands/` | 7 个阶段 slash command：`/define` `/explore` `/plan` `/design-check` `/implement` `/debug` `/final-review` |
| `codex/AGENTS.md` | `~/.codex/AGENTS.md` | Codex 侧长期规则（Reviewer 规则 + 非审查会话比例原则） |
| `codex/config.example.toml` | `~/.codex/config.toml`（缺失时播种） | Codex 持久偏好（信任目录表等本机生成段刻意省略） |
| `dsh/AGENTS.md` | `~/.dsh/AGENTS.md` | **DSH 每会话必载的全局指令**（跨项目策略层：Mode Routing、Author/Reviewer 角色与写权、Safety 红线、Fan-out 上限、Configuration Hierarchy；细节一律指向 `~/.dsh/workflow/` 与 `~/.dsh/skills/`，不复制判据） |
| `dsh/workflow/` | `~/.dsh/workflow/` | DSH 侧母本：`AGENTS.md`（**判据唯一出处**——Safety Rules / Reviewer 零写入与轻量协议 / `[DEBT]` 零暗债 / Payback-on-Touch / 证据 vs 假设 / 验证三分类 / 守护有效性装置 / Fix-Loop 硬停 / review-sensitive paths + SHA 绑定 / Git Discipline）· `reviewer-prompt.md`（9P/9A/9B prompt + 输出契约 + **双审隔离协议 5 条 + DSH 调用形态**）· `fanout-toolchain.md`（**DSH 工具面事实**：委派三面、审查调用参数、派发上限、Reviewer 失败语义）· `index.md` · `QUALITY_GATES.md` · `workflow-design-notes.md` · `AB-model-diagnostic.md` · `templates/` |
| `dsh/skills/` | `~/.dsh/skills/` | DSH 原生 skill 包（按需加载，**只有本工作流自有的两个目录被镜像**）：`dual-agent-workflow/`（路由 + phase 正文 `references/phases/*.md` + 证据/派发/冲突手册）与 `independent-review/`（开审清单、调用形态、收回后 5 项核验、异常处置） |
| `portable/` | — | 便携单文件版。**两族并存**：Claude Code/Codex 侧 `通用prompt-v3.8.txt`（2026-09-06 按 `main` 母本整体重新生成：模式路由/Routine · Reviewer 零写入 · 双审隔离与 SHA 绑定 · 归因与 Fix-Loop 硬停 · 轮次上限 · 单轮 diff 预算 · 守护有效性装置与负向对照 · 验收可复现判定 · 修法必附 · **Blocking 仅 Product、证据缺口走 Verification Needed** · **9P 默认单跑一轮** · **diff 预算只计生产面、`docs/ai/**` 不计** · **三件套写完机械对照骨架 · 空闲期 HANDOFF 保留全骨架** · 推理档按审别取值）；**DSH 侧 `通用prompt-DSH-v1.txt`**（同一套纪律的 DSH 压缩版：Author/Reviewer 都是 deepseek/dsh、`subagent` 调用范式与零写入 `writes_performed` 字段、headless 备用路径、9P/9A/9B 精简 prompt、派发上限）。**每次整体重生即退役旧版**，同一族只保留当前版一份，历史版本查 git 历史（v3.7 见 `git show 5847c43:portable/通用prompt-v3.7.txt`，v3.6 见 `git show 8cdce08:portable/通用prompt-v3.6.txt`，v3.5 见 `git show 986a1ed:portable/通用prompt-v3.5.txt`，v3.4 见 `git show 77244d1:portable/通用prompt-v3.4.txt`，v3.3 见 `git show 4861875:portable/通用prompt-v3.3.txt`，v3.2 见 `git show 76c3138:portable/通用prompt-v3.2.txt`，v3.1 见 `git show f7dd03f^:portable/通用prompt-v3.1.txt`）。母本再变时同样**整体重新生成**，勿逐条打补丁 |
| `install.ps1` | — | 上述一切的一键部署脚本 |

## 核心机制（2026-08 版）

- **模式路由（2026-08-05 裁决）**：日常任务默认 **Routine**——对话内简短方向 + 真实验证输出（命令 / 完整输出 / 退出码），人类扫 diff 后 commit/merge，无交接文件仪式；**Critical** 仅人类明确启用，才进入下述完整机制。任务级「做吧」不构成模式确认；触及 auth / 迁移 / 部署 / 资金等高风险面须先建议 Critical 并停下等确认。
- **交接走文件、验证产物化（Critical）**：交接经 `docs/ai/`，测试输出落 `last_test_run.txt`，下一个 Agent 读产物不信自述；git 作阶段门，回滚靠 revert。
- **Reviewer 零仓库写入 + 双审隔离**：计划批准前默认必跑 **9P 计划审**（默认单跑一轮、再审凭人类明示要求、审规划文件、无快照自检，2026-08-27 新增，2026-09-03 改单轮）；实现审 9B 盲审先行、9A 对照审后行，verdict 与 raw log 一律写仓外 holding；实现审正文前强制快照自检（HEAD == `handoff_snapshot_sha`、工作树干净、HANDOFF 从工作树读，不一致即拒审）；**Blocking 只收 `[Product Blocking]`，证据缺口走 Verification Needed 由人类合并前查看，本身不触发再审，处置产生 review-sensitive delta 时按收敛门再审（2026-09-03）**。
- **Fix-Loop 外部化硬停**：blocking 的归因（`caused_by_last_fix`）由 Reviewer 判、Author 逐字转录，达阈值即停手交人类，禁止原上下文滚补丁；**递增条件、阈值、轮次上限与合并门优先级以 `claude/workflow/AGENTS.md` → Fix-Loop 计数与跨轮硬停为唯一定义处**（DSH 会话则取 `dsh/workflow/AGENTS.md` 同名节；本文不复述判据）。
- **零暗债**：任何妥协要么当场修，要么写成带偿还触发器的 `[DEBT]` 明账；触碰挂债文件必须同 commit 偿还（Payback-on-Touch）。
- **DSH 落地（2026-09-06）**：`dsh/` 是同一套纪律的 DeepSeek Harness 落地，**Author 与 Reviewer 都是 deepseek/dsh**。差异只在执行器：命令形态（DSH 无 markdown slash command 面，phase = 本项目 skill 正文 `~/.dsh/skills/dual-agent-workflow/references/phases/*.md`）、Reviewer 进程形态（`subagent` 子 agent 前台调用 / `dsh --profile headless` 独立进程，**不再是 `codex exec`**）、推理档（`reasoning_effort`：9A/9B = `high`，9P = `high`）、以及**零写入的自证方式**（`writes_performed` 字段 + 纪律，无沙箱兜底）。判据、阈值、轮次上限、双审隔离五条硬门全部沿用不变；**冲突时以 `dsh/workflow/AGENTS.md` 为准**（DSH 会话）。
- **守护有效性契约**（已定稿；**判据两模式恒适用，证据形式按模式取——下述结构化产物是 Critical 形式，Routine 形式见 `claude/workflow/AGENTS.md` → 守护有效性装置 ★ 模式分流；DSH 侧同一节见 `dsh/workflow/AGENTS.md`**）：Critical 下「回归用例有效」的唯一可接受证据 = 守护有效性装置的结构化产物——基线绿→变异后因预期断言而红→内容哈希验证还原后复绿，真实退出码为准（禁 grep 判红），并携带按构建系统提供的缓存旁路或等价执行真实性证据；母本只定义契约，脚本由各项目按技术栈实现（首个实现：SeedLink `pnpm guard:verify`）。

## 快照状态（2026-07-30）

>（历史记录：snapshot-first 迁移前时点的状态描述，行文沿用当时的「快照/母本」视角；现行权威契约见文首。）

> **DSH 侧迁移状态（2026-09-06；本轮次账在 `docs/ai/HANDOFF.md`）**：`dsh/` 与 `portable/通用prompt-DSH-v1.txt` 由 `claude/workflow/` 母本**派生**（骨骼机械复制 + 有界 DSH 化改点，改点清单与机读登记表见 `docs/ai/DSH-LANDING-NOTES.md` §2 / §2.1 / §2.2 / §2.3）。**已跑多轮独立双审**（**轮次与结论的唯一权威 = `docs/ai/HANDOFF.md` 的 Review & Test Binding 表**；此处不复述逐轮结论，避免与账本漂移）。**历轮 finding 全部落在**"改点登记表 + 验收条款判定方式"这一层，且每轮修复又在该层新增不可执行判定 → **人类 2026-09-06 裁决：停止在此层续修，按 `[M]/[O]/[U]` 三级收口 AC，只保留 AC6 与 AC4-门两个机械门**（见 `docs/ai/TASK_BRIEF.md`）。`~/.dsh/{AGENTS.md,workflow,skills/{dual-agent-workflow,independent-review}}` 已由**人工等价部署**落位（`install.ps1` 受迁移期 guard 锁定、未运行；该副本没有脚本会产生的 `*.bak-*`，改仓后也不会自动跟随——须由 Author 手工同步）。**当前状态 = 已生效、已多轮审查但未标注收敛的候选 overlay**：`[DEBT]` 明账按 No-Hidden-Debt 登记，**唯一权威 = `docs/ai/HANDOFF.md` 的债台账**（`DSH-LANDING-NOTES` §3 是**同源但不等集**的历史登记，第 7 轮 9B 的 PB-1 已订正——此处不写死笔数，写死必然随加账过期）。**在收敛门通过前不得标"已收敛"或 Ready to Commit。** **人类 2026-09-06 裁决「合并」**：本机工作分支即 `main`，已含上述全部产出（领先 `origin/main` 37 笔）——**本地无 merge 可做，push 由人类执行**（本仓契约禁止 agent 远程操作）；push 前本段的状态措辞仍然成立。

守护有效性契约任务**已闭合**：契约条文经两轮独立双审确认，装置侧五轮审查（含盲审与一轮作废重跑）收敛零 blocking，SeedLink 实证 绿→预期断言红→恢复后绿 的结构化产物落档（冻结哈希与证据位置见 `~/.claude/workflow/archive/2026-07-30-guard-effectiveness-backup/ARCHIVE_NOTE.md`，本地文件）。本快照所含六个母本文件即定稿版。历史基线（2026-06-25 的 v3.1 拆分版）保留在本仓库首个 commit。`~/.claude/rules-archived-zh/`（已退役的中文规则包）与本地演练证据 archive 刻意不发布。
