# HANDOFF.md

> per-task 核心交接文件，每次 Agent 切换前更新。简短，证据指向 git log 和 last_test_run.txt。
> 下列每节都保留（无内容写 None/N/A）；Quality Gates 必须逐维度表格，不得用"已过所有闸门"一句话替代。
> **上一个任务的交接记录已改名为 `docs/ai/HANDOFF-2026-09-06-agent-reference-and-phase-rulings.md`**（原文件名会被本任务 `/plan` 的归档动作覆盖）；它不属于本任务。

## Current Phase
Independent Review 已产出、**未收敛** → 停在修补前等人类裁决（`stopped, NOT converged` 尚未成立：本轮走的是"修后重审"路径，但**两条未解决 `[Product Blocking]` 存在期间不得合并**）。

## Task Summary
把本仓的双 Agent 工作流（原 Claude Code Author × Codex CLI Reviewer）落到 **DeepSeek Harness**：Author 与 Reviewer 都是 deepseek/dsh。产出 `dsh/` 一等公民（DSH 侧母本 + 9P/9A/9B prompt + 模板 + 质量清单 + DSH 工具面事实）、两个可加载 skill、DSH 便携 prompt，并登记部署面。本轮为**首轮独立双审**。

## Source of Truth
* PRODUCT_BRIEF.md：N/A（无产品面）
* TASK_BRIEF.md：**不存在**（本任务由人类在对话中直接下达 + 一段 Frozen Acceptance；见下方 Work Log 与两份 verdict 的引用）
* IMPLEMENTATION_PLAN.md：**不存在**（本任务未经 `/plan`、未经人类批准门；Author 直接实现并落 commit）
* Base branch / base commit：`main` @ `bf06c65d0831ebeb2b0982f35ae2d7f4c65c2c17`
* approval_commit_sha: **N/A — 本任务无批准 commit**（未走批准门，属流程缺口，见 Known Issues）
* plan_review_9P: **N/A — 未跑 9P**（本任务无规划文件，9P 天然不适用；但也未取得人类明示减免记录）
* git log 与当前 branch 的 diff / last_test_run.txt

## Review & Test Binding（SHA 绑定；final-review 收敛门与 Reviewer 读；语义见 AGENTS.md）
* review_base_sha: `bf06c65d0831ebeb2b0982f35ae2d7f4c65c2c17`
* review_tip_sha: `a361bc1942546484e0edd102cbd789d4dc498c61`（本轮唯一改动 commit）
* review_verdict_9A: **不通过** | verdict 文件: `docs/ai/review_9A.md`
* review_verdict_9B: **不通过** | verdict 文件: `docs/ai/review_9B.md`
* tested_sha: `a361bc1942546484e0edd102cbd789d4dc498c61`（`docs/ai/last_test_run.txt` 只记录 Author 自跑的机制核验；**本任务没有功能测试套件**）
* guard_effectiveness: N/A（未声称"回归用例有效"）
* review_sensitive_paths: `dsh portable install.ps1 AGENTS.md README.md docs/ai/AUTHORITY_CONTRACT.md docs/ai/DSH-LANDING-NOTES.md`
* handoff_snapshot_sha: `a361bc1942546484e0edd102cbd789d4dc498c61`（= 双审窗口开启时的 HEAD；两份 verdict 的 `observed_head_sha` 均已核验相等且 `worktree_clean: yes`、`writes_performed: none`、无覆盖缺口）
> 有效性：所有 review-sensitive 文件已入 `a361bc19`、这些路径无未提交改动、无未跟踪文件 → 本轮绑定成立。
> **注意**：本文件与 `docs/ai/last_test_run.txt` **不在** `review_sensitive_paths` 内，故它们提交在 `review_tip_sha` 之后；任何 Reviewer 必须从**工作树**读这两个文件。

## Work Log
倒序，每条一行：[日期] [Agent] [做了什么] [commit]

* [2026-09-06] [Author] 人类下令"将这套工作流作用于 dsh，Author 与 Reviewer 都是 deepseek/dsh"。先核模型档（DeepSeek 官方公告：V4.1-Flash 超过 V4 Pro，`deepseek-v4-pro`/`deepseek-v4-flash` 已下线或路由到它；DSH 对应 id = `deepseek-flash`），再探明 DSH 可挂载面（preset/persona/skill/subagent/headless），产出 `dsh/` + 两个 skill + 便携版 + 部署登记。 | `a361bc19`
* [2026-09-06] [Author] 人工等价部署到 `~/.dsh/{AGENTS.md,workflow,skills/{dual-agent-workflow,independent-review}}`（`install.ps1` 受迁移期 guard 锁定、**未运行**）；仓内 `dsh/**` 与 `~/.dsh` 副本 23 个文件 SHA256 全等。 | 未入 commit（机器态）
* [2026-09-06] [Author] 人类授权建 reviewable commit（本仓 Routine 下 agent 不自建 commit，此处为 Critical 阶段 commit）。 | `a361bc19`
* [2026-09-06] [Reviewer 9B（盲审，先跑）] 结论 **不通过**：3 条 `[Product Blocking]`、8 条 Suggestion、5 条 VN、4 条 Requirement-Level Concerns；Debt `Noted`。 | 仓外 holding `~/.dsh-review-holding/dsh-landing/9B.md`
* [2026-09-06] [Reviewer 9A（标准审，后跑）] 结论 **不通过**：4 条 `[Product Blocking]`、8 条 Suggestion、4 条 VN；Debt `Noted`。 | 仓外 holding `~/.dsh-review-holding/dsh-landing/9A.md`
* [2026-09-06] [Author] 落账：两份 verdict 收进 `docs/ai/review_9A.md` / `docs/ai/review_9B.md`；把上一任务的 `docs/ai/HANDOFF.md` 改名为 `docs/ai/HANDOFF-2026-09-06-agent-reference-and-phase-rulings.md` 并加归档说明头。 | `c91b7c5`
* [2026-09-06] [Author] 自查发现归档文件的工作树副本被写成了 CRLF（`.gitattributes` 要求 `eol=lf`），已就地归一为 LF 并复扫（`crlf_files=0`）。**注**：git 侧因 `text=auto` 归一化，`c91b7c5` 里存的本就是 LF，无历史污染；但工作树出现 CRLF 是我用 PowerShell 字符串替换写文件造成的，属本轮自造缺陷，记此备案。 | 未产生新 commit（`git status` 为空）

## Known Issues

* **两条未解决的 `[Product Blocking]` 存在 → 合并门关闭**（判据唯一出处 = `dsh/workflow/AGENTS.md` → Fix-Loop 三者优先级 ②）。必须修复并重审，或由人类裁决；期间**不得合入 main**。
* **本任务跳过了批准门与 9P**：没有 TASK_BRIEF / IMPLEMENTATION_PLAN，人类只在对话里下达命令即进入实现。这不构成本轮 blocking（本轮审的是"改动本身是否正确"），但它是真实的流程缺口：9P 的输入不存在，`approval_commit_sha` 无从填写。
* **协议缺口（本轮实发，已在两份 verdict 的落账头如实标注）**：`reviewer-prompt.md` 说"verdict 由 Author 在窗口结束后落盘"，但**未规定 verdict 文本在哪里被捕获**——窗口关闭后它只存在于 Author 上下文里，而落账通常发生在上下文压力最大的时刻。本轮即因此只能以**转录**形式落账，而非 Reviewer 手写的原始 artifact。Codex 时代的 `-o` 之所以重要，正因为它让 Reviewer 直接把 verdict 写进文件；DSH 主路径没有这个通道。**这是本次 DSH 落地引入的真实缺陷**，应修（例如：主路径要求 Reviewer 把 verdict 同时写入仓外 holding，或在返回后**立即**落盘再进入落账流程）。
* **两轮 Reviewer 各自报了 1 次误输入的非写命令**（9B 的 `Copy-Item -Path $null`、9A 未触发写入）。属噪声，均已复核全树为空，但说明"零写入"只能靠自证字段，没有机械约束。
* `docs/ai/DSH-LANDING-NOTES.md` §2 的"只有这些改点"声称**已被 Reviewer 证伪**（≥11 个实际变更未登记，其中含实质漂移）；修 B2 时必须一并修。

## Fix-Loop Counter（review-fix 循环用；无则 "None"）
* 第 1 轮 | 改了什么：**尚未修改**（本轮只审不改；Author 在等人类裁决是否进入修补） | [Product] 条数 + 归因（逐字转录）：**4 条 `caused_by_last_fix: yes`**（9A: B1/B2/B3/B4）+ **3 条 `caused_by_last_fix: no`**（9B: B1/B2/B3，均为落地 commit 自身引入、非修复引入）→ 按问题去重后本轮计数 **1**（同一轮内重复发现不计多次）
* streak（当前连续计数）: **1**
> 递增/重置/停止/轮次上限及其与合并门的优先级，**一律以 `AGENTS.md` → Fix-Loop 计数与跨轮硬停为准**。**`caused_by_last_fix` 由 Reviewer 判定；Author 只逐字转录，不自判。**
> **提醒**：若下一轮（第 2 轮）仍出现 `caused_by_last_fix: yes` 的 `[Product Blocking]`，streak 达 **2** → **立即停止编码**，只能回退 / 重新拆任务 / 请求人类批准架构升级，**禁止"再试一轮"**。

## Remaining Risks / Debt
技术债唯一落点。格式（见 AGENTS.md）：

```
[DEBT] dsh/ 全套与 portable/通用prompt-DSH-v1.txt 未经 9P/9A/9B 审查 | Payback trigger: 下次在 DSH 会话里启用 Critical，或下次改动 dsh/** 之前 | Impact: 未审的判据副本可能含语义漂移，却被当作权威执行（且它已是本机生效的运行副本）
[DEBT] dsh/workflow/fanout-toolchain.md 的 DSH 事实绑定 @deepseek-ai/dsh 0.1.5-rc.x | Payback trigger: 下次改动 dsh/workflow/fanout-toolchain.md 之前，或 @deepseek-ai/dsh 升级后首次派发审查之前 | Impact: 参数/工具名变化会让调用范式静默失效
[DEBT] ~/.dsh 的运行副本由人工复制产生，无 *.bak-* | Payback trigger: 首次用 install.ps1（或任何镜像脚本）覆盖 ~/.dsh 之前 | Impact: 首次自动部署没有上一版可回退
[DEBT] install.ps1 会把整个 ~/.dsh（含 sessions/storages/.credentials.yaml）整树备份为 ~/.dsh.bak-<stamp>，与 README「凭据从不触碰」的措辞不一致（9A S7）| Payback trigger: 下次改动 install.ps1 的 DSH 段之前 | Impact: 凭据被复制到备份目录且从不清理，人类核验"凭据未被触碰"时会得出错误结论
```

* **第 1 笔债的 Payback-on-Touch 已在本轮触发**（本 commit 就是"改动 `dsh/**`"）→ 人类需在「先跑一轮审查」与「明确批准延期」之间选一个；本轮**已经**跑了首轮双审（部分偿还），但未收敛，**不得**因此标为已偿还。

## Quality Gates
对照 /define 0.1 标「关注」的维度 + 恒查安全基础，逐行：

| 维度/闸门 | 状态(Pass/N/A) | 证据文件或 N/A 原因 |
|---|---|---|
| 测试 QA(11.1) | **N/A** | 本任务无功能测试套件；`docs/ai/last_test_run.txt` 只记机制核验（hash 全等 / skill 发现 / 解析 0 error） |
| 安全基础(11.2) | **Pass（有限）** | 无密钥写入仓；`install.ps1` 的备份会复制凭据 → 已登记为 `[DEBT]`；Reviewer 未报安全类 Product Blocking |
| 文档一致性 | **Fail** | 9A B2/B3/B4 + 8 条 Suggestion 全部落在"说与做不一致/登记不完整"；修复后需重审 |
| 依赖引入 | **Pass** | 未引入任何新依赖 |
| 设计层闸门(§5) | **N/A** | 无界面 / 无面向用户内容 |

## Quick-Version Fields（快速版填，正式可省）
* Applicability Scan(0.1)：文档/配置类任务——UI/UX/性能/隐私维度 N/A；文档一致性与安全基线适用。**但本任务改的是部署面与判据副本，仍走了独立双审**（人类明确要求）。
* Human Approval Evidence：人类先后给出 ①「现在就发这一轮」（授权发审）②「A：你授权我建一个 reviewable commit」（授权建 commit）；**未批准实现计划**（本任务无计划）。

## Next Step
**停在人类裁决前，不得继续编码**（两条未解决 `[Product Blocking]`）。人类需决定：
1. **是否进入第 2 轮修补**（修 B1–B4 + 收 Suggestion），修完按流程重跑 9B→9A（`reasoning_effort` 用 `high`）——注意 streak 已 = 1，第 2 轮若再出现 `caused_by_last_fix: yes` 的 Product Blocking 即达 **2 → 硬停**；
2. **B1 的档位取值**（`low` = 保留"比 9A/9B 低一档"的母本意图 / `high` = 取消分档，属人类裁决）；
3. **第 3 笔与新增第 4 笔债**的处置（本机 `~/.dsh` 运行副本与 `install.ps1` 的备份语义）；
4. 是否先补一份 TASK_BRIEF（含本任务 Frozen Acceptance）以修补"跳过批准门与 9P"这个流程缺口。
