# TASK_BRIEF.md

> per-task 需求与验收的唯一落点。**本文件是事后补写的**（见「补写说明」），用于修补本任务跳过批准门与 9P 计划审造成的流程缺口。

## 补写说明（如实登记）

本任务由人类在对话中直接下达（"将我这套本应用于 claude code 和 codex 的工作流作用于 dsh，但是 Author 和 Reviewer 都是 deepseek/dsh"），Author **直接进入实现**并落 commit，未走 `/plan`、未产出 TASK_BRIEF、未跑 9P、未取得计划批准门——因此首轮双审是在**没有需求文件**的情况下进行的（两份 prompt 里的 Frozen Acceptance 由 Author 当场写入 prompt）。人类在首轮双审后裁决"补一份 TASK_BRIEF 含本任务 Frozen Acceptance"，本文件即该裁决的产物。

**这修补的是流程缺口，不是给已完成的实现补一张事后授权单**：首轮双审的 verdict（9A/9B 均"不通过"）与 Fix-Loop 计数不因本文件而改变；本文件的作用是让**第 2 轮修补**有可对照的验收基线。

## Goal

让本仓的双 Agent 工作流可在 **DeepSeek Harness（DSH）** 上运行，且 **Author 与 Reviewer 都是 deepseek/dsh**；既有的 Claude Code × Codex 落地保持不动。

## Summary（推荐方案）

骨骼由 `claude/` 一侧**机械复制**，再做**有界 DSH 化改点**（改点必须逐条登记），另新增 DSH 特有的执行面文件。理由：两套落地必须共享同一套判据与阈值，逐字重打一遍必然产生悄悄的分歧；机械复制 + 有界改点让"哪里不一样"可 diff、可复核。

**明确不采用**：① 从零重写一份 DSH 工作流（判据必漂移）；② 只写一份便携 prompt 不做结构化落地（DSH 有 skill 发现面，可用按需加载换取常驻 token）；③ 改动 `claude/` 一侧去迁就 DSH（会把两套落地焊死成一套，且 DSH 化的事实对 Claude 侧是错的）。

## Current Architecture Understanding

* `claude/`（Claude Code 侧工作流母本 + `CLAUDE.md` 全局指令）、`codex/`（Codex 侧长期规则）、`portable/`（便携单文件版）、`install.ps1`（唯一的可执行部署面，**受迁移期 guard 锁定**）。
* 受管部署面 = 部署器持续镜像/覆盖的路径（`~/.claude/{rules,workflow,commands}`、`~/.codex/AGENTS.md`）；`~/.codex/config.toml` 是 seed-only。
* DSH 侧事实（一手来源：`@deepseek-ai/dsh` 0.1.5-rc.x 包内 README/lib）：每会话必载的用户全局指令 = `$DSH_HOME/AGENTS.md`；skill 发现根含 `<dshHome>/skills`（只认 `<name>/SKILL.md` 与顶层 `<name>.md`，**嵌套 `**/SKILL.md` 故意不发现**）；委派三面 = `subagent`（fresh context）/ `subagent_fork`（继承本会话）/ `workflow`；模型档位枚举 = `off/low/high/max`；`subagent` 的模型选择受宿主 `subagent-model-selection.allowedModels` 约束。
* 关键差异：**DSH 没有 Codex 那种进程沙箱兜底**——Reviewer 同机同权限，技术上写得到仓库。

## Proposed Changes

| # | 文件 | 性质 | 内容 |
|---|---|---|---|
| 1 | `dsh/AGENTS.md` | 新增 | DSH 每会话必载的全局入口（路由 / 角色与写权 / Safety 红线 / Fan-out 上限 / Configuration Hierarchy） |
| 2 | `dsh/workflow/AGENTS.md` | 派生 + 有界改点 | DSH 侧判据唯一出处 |
| 3 | `dsh/workflow/reviewer-prompt.md` | 派生 + 有界改点 | 9P/9A/9B prompt、输出契约、双审隔离协议、DSH 调用形态 |
| 4 | `dsh/workflow/fanout-toolchain.md` | 新增 | DSH 工具面事实（委派三面、参数、白名单、派发上限、失败语义） |
| 5 | `dsh/workflow/{index,QUALITY_GATES,workflow-design-notes,AB-model-diagnostic}.md` + `templates/` | 派生 | 导航 / 质量清单 / 设计说明 / 模板 |
| 6 | `dsh/skills/dual-agent-workflow/**` | 新增 | 路由技能 + 7 个 phase 正文 + 两份执行手册 |
| 7 | `dsh/skills/independent-review/**` | 新增 | 审查执行手册 |
| 8 | `portable/通用prompt-DSH-v1.txt` | 新增 | DSH 便携单文件版（与 v3.8 同族并列） |
| 9 | `install.ps1` | 修改 | 新增 DSH 部署段 |
| 10 | `README.md` / `AGENTS.md` / `docs/ai/AUTHORITY_CONTRACT.md` / `docs/ai/DSH-LANDING-NOTES.md` | 修改/新增 | 布局表、受管面契约、改点清单与债登记 |

## Acceptance Criteria（Frozen Acceptance；本任务的验收基线）

1. **一等公民**：仓内出现 `dsh/`，与 `claude/`、`codex/` 并列；`dsh/workflow/AGENTS.md` 是 DSH 会话的判据唯一出处，且**与 `claude/workflow/AGENTS.md` 的判据、阈值、轮次上限逐条一致**（只允许"怎么跑"不同）。
2. **可加载**：`dsh/skills/` 下至少一个 bundle 能被 DSH 的 skill 发现面加载（判定方式：把 bundle 放进 `<dshHome>/skills/` 后，一个 fresh DSH 会话的技能目录里出现它；**不是**靠读包内 README 推断）。
3. **两条 Reviewer 路径**：主路径 = 同会话 `subagent` 前台调用，显式 `provider`/`model`/`reasoning_effort`；备用路径 = 独立 `dsh --profile headless` 进程。**两条路径给出的命令都必须真的能跑**（判定方式：主路径产生过真实 verdict；备用路径的 CLI 面经 `--help` 或实跑确认）。
4. **模型档可指回一手来源**：Author 与 Reviewer 的模型/档位断言必须能指回官方公告、`list_subagent_models` 的实时返回或包内 `DEFAULT_MODELS`；**不得凭记忆**。所有写进文档的 `reasoning_effort` 取值必须落在适配器取值域（`off/low/high/max`）内（判定方式：`Select-String <适配器> -Pattern '"medium"'` 零命中，且文档里的取值逐个属于该枚举）。
5. **零写入闭环**：verdict 契约含 `writes_performed` 字段；三份 prompt 都要求它；Author 侧明确"落盘由 Author 在窗口结束后做"；零写入违反 = 该轮作废。
6. **改点可复核**：`docs/ai/DSH-LANDING-NOTES.md` 的改点登记**覆盖全部实际变更**（判定方式：`git diff --name-only <base>..<tip>` 的每一项都能在 §2 或 §2.1 找到；逐对 `git diff --no-index` 的每一条变更行都能归到某个改点）。
7. **说与做一致**：`install.ps1` 的注释、`README.md` 的布局表与快照状态节、`AUTHORITY_CONTRACT.md` 的增补、`DSH-LANDING-NOTES` §4 对"镜像哪些路径 / 不碰哪些机器态"的描述必须与代码一致（判定方式：逐条对读，最近的反例是首轮 9A 的 B3）。
8. **机器态不可触碰**：`~/.dsh` 下的 `settings.yaml`、`sessions/`、`storages/`、`.credentials.yaml`、`profiles/` 不被部署动作修改或删除（判定方式：安装器解锁后在一次性 profile/临时 HOME 下实跑并比对哈希；本轮只做静态核验并如实标注未实跑）。
9. **如实标注**：未经审查/未实跑/未验证的东西必须写成未验证（含 `[DEBT]` 三笔与验证记录节）；**不得把"未做"写成"已验证"**。
10. **判据无漂移**：`dsh/` 派生文件相对母本不存在"改判据而不是改执行器"的地方；`docs/ai/QUALITY_GATES.md`（项目副本）仍必须是 Reviewer 的质量清单输入（判定方式：`dsh/workflow/reviewer-prompt.md` 里指向项目副本的行数 == 母本对应行数）。

## Frozen Acceptance 的冻结输入域（供负向对照用）

验收 4 的输入域 = **文档中出现的每一个 `reasoning_effort` 取值**。等价类枚举：
* (a) 9A/9B 的取值；(b) 9P 的取值；(c) portable 与 README 里复述的取值；(d) skill 正文里复述的取值。
**对照样本（"若移除该错误则会通过"的负向对照）**：把任一取值改成 `medium` → 验收 4 的判定命令必须红。

## Risks & Edge Cases

* **最大风险 = 判据漂移**：机械复制 + 人工改点的边界靠人自觉；首轮双审已实测出三类清单外变更（含 2 处指针漂移）。缓解：§2/§2.1 完整登记 + 逐对 diff 作为审查输入。
* **同模型双审的独立性只剩一层**：Codex 时代靠"换模型"提供第二层保险，DSH 下 Author 与 Reviewer 同为 `deepseek-flash`，独立性**完全**来自上下文隔离。若主/备用路径的档位漂移，就没有第二道保险 → 用 `model_route` 自报字段提高可见性（并如实标注它不可被验证）。
* **安装器无法演练**：受迁移期 guard 锁定，只能静态核验 → 验收 8 标注为"未实跑"。
* **不可逆面**：`~/.dsh` 是本机 harness home（含会话与凭据），部署动作一旦写错影响面大于普通仓库改动 → 采用"镜像受管路径 + 绝不触碰机器态"的最小面，并把整树备份的副作用登记为债。

## Execution Steps

1. 机械复制骨骼 + 有界 DSH 化改点（首轮已完成，commit `a361bc19`）。
2. 首轮独立双审（9B 先、9A 后）→ 两份"不通过"（commit `7c5505f` 落账）。
3. **第 2 轮修补**（本轮）：按人类裁决修首轮全部 Product Blocking + 收 Suggestion；9P 档取 `high`；补本 TASK_BRIEF。
4. 第 2 轮独立双审（9B 先、9A 后，`reasoning_effort: high`）。
5. 收敛门 → 人类 commit/merge。

## Testing Plan

* 无功能测试套件。核验 = 机制命令 + 真实输出，落 `docs/ai/last_test_run.txt`。
* 本轮必须新增的实跑：**修复后的 9P 档位实跑取证**（发一次 `reasoning_effort: high` 的 9P 调用，确认不再被拒）。
* 逐对 diff 审计（17 对派生文件）作为"判据无漂移"的机械输入。

## Open Questions

**None**（人类已在首轮双审后逐条裁决：进入第 2 轮、9P 档 = `high`、先跑审查、补 TASK_BRIEF）。

## Human Approval Status

- Status: **N/A — 本任务的批准门在实现后才补**（人类在首轮双审后裁决"进入第 2 轮修补"即为对本 TASK_BRIEF 验收基线的事实批准；**未经** `Status: Approved` 形式的正式批准 commit）
- Approved by: N/A
- Date: N/A
