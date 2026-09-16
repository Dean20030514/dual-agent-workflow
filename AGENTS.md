# AGENTS.md — dual-agent-workflow(项目工作契约)

> 本文件是在**本仓库内做开发任务**时的项目级 Agent 契约。跨项目纪律不在此复述——本仓库在树内自带母本 `claude/workflow/AGENTS.md`(Safety Rules / Reviewer-Lightweight Protocol / No-Hidden-Debt·[DEBT] / 证据 vs 假设标签 / 验证三分类 / 守护有效性装置 / Fix-Loop / Git Discipline,各节均为唯一定义处),**全部条款对本仓库任务原样适用**。本文件只记录项目特有事实、命令与差异。

## Project Overview
个人双 Agent 工作流 + Claude Code/Codex 全局配置的**规范事实源(canonical source)**。当前规范版本 = `main` 当前 tip;本机 `~/.claude/`、`~/.codex/` 与 `~/.dsh/` 中**由部署器持续更新/覆盖的受管路径**是本仓库的运行副本,受管面上的可复用修改须经仓库可见 diff 晋升——受管面边界、seed-only 与 machine-local 例外**以 README 文首契约与 `docs/ai/AUTHORITY_CONTRACT.md` 为唯一定义处,此处不另行定义**。`IMPROVEMENT_PLAN.md`(tag `plan-v1.1`)自 2026-08-05 起为**参考材料(REFERENCE ONLY)**——Round 1 执行经人类裁决停止(H5A 停牌 `stopped, NOT converged — over-engineered`,已知漂移已直接修复);不按其 phase 开工,重启需人类明确决定。

**两套落地,一套纪律(2026-09-06)**:`claude/` = Claude Code(Author)+ Codex CLI(Reviewer);`dsh/` = **DeepSeek Harness**——**Author 与 Reviewer 都是 deepseek/dsh**(Author = 当前 DSH 会话主 agent;Reviewer = `subagent` 子 agent / `dsh --profile headless` 进程,模型档 `provider: deepseek-official` + `model: deepseek-flash`)。两套判据与阈值一致,**只允许「怎么跑」不同**;DSH 会话的判据唯一出处是 `dsh/workflow/AGENTS.md`(与 `claude/workflow/AGENTS.md` 冲突时以它为准)。派生方法的改点清单与**未偿还的审查债**见 `docs/ai/DSH-LANDING-NOTES.md`。

## Build / Test / Lint Commands
可执行面 = `install.ps1`(PS 5.1 兼容)。**当前状态(2026-09-15)**:部署语义 = **只增/只更新** —— 无参数运行 = 打印完整计划 → 前置校验 → 逐文件更新受管目标(**覆盖前把旧内容备份成同级 `<name>.bak-<时间戳>-<4位guid>`**)→ 装 6 个官方插件;内容已一致的文件完全不碰(同版本重跑是 no-op)。**默认不删除任何东西**:本机独有内容只以 `[STALE]` 报告,删除须**显式传 `-RemoveStale`**(唯一的删除路径,目录仅在已空时删,**全文件无递归删除**)。`-DryRun`(逐文件 `[DIFF]` 预览 + `would-write=N` + 计划会被拒时 `[WARN]`)与 `-ValidateOnly` 仍是**零写入**路径;`-NoPluginInstall` 跳过插件步(插件步是网络操作,逐插件 180s 超时后 kill 并计 `failed`);`-IUnderstandThisReplacesLiveConfig` **已移除**(传它 = 参数绑定阶段失败)。退出码:`0=OK` / `1=FAILED`。**mirror-replace(删除)语义已整体移除**——2026-09-15 那次真机事故（一次探针式执行删掉 127 个本机独有文件）就是它造成的;该方向的规划产物归档于 `docs/ai/archive/2026-09-15-h3b-mirror-replace-superseded/`,本轮 per-task 记录见 `docs/ai/archive/2026-09-15-h3c-add-update-only/`。
* `tools/validate/` 为 **H5A 封存档**(2026-08-05 停牌,`stopped, NOT converged`):非门禁、勿续建、勿修;`validate.ps1` 入口从未建成;其真仓断言绑定修漂移前的仓库状态,Pester 套件对当前 main **预期失败**——封存标记,不是待修 bug。
* 存档参考命令(仅需要时):`pwsh -Command "Invoke-Pester -Path tools/validate/tests -CI"`;依赖模块(powershell-yaml、PSScriptAnalyzer、Pester ≥5,版本见 `tools/validate/requirements.psd1`)仅跑存档测试时需要,不是仓库门禁。

## Code Style Rules
* 用户可读文档中文为主;代码、注释、提交信息英文(Conventional Commits)。
* UTF-8 无 BOM;LF(`.gitattributes` 强制)。
* PowerShell 新代码目标 pwsh 7;`install.ps1` 保持 5.1 兼容,勿顺手"现代化"。
* 已知内容漂移已于 2026-08-05 直接修复(b13859d);后续发现漂移随手修,不再登记豁免。

## Safety / Workflow(2026-08-05 起,五规则三闸门)
* **日常改动(文档/配置)= Claude 改 + 人类扫 diff + 人类 commit/merge**。五条核心规则:快照仓 SSOT / 真改动人类批准 / Author 交真实测试产物 / Reviewer 零写入 / 连续 blocking 硬停(递增条件/阈值/轮次上限/与合并门优先级,唯一定义处 = `claude/workflow/AGENTS.md` → Fix-Loop 计数与跨轮硬停;此处不复述判据);三个机械闸门**按模式取用**:**审查 SHA 绑定干净工作树仅 Critical**(Routine 一律记 N/A,含人类临时要求跑一次 Reviewer 的情形——那不构成模式升级)、**实际 diff 不超批准范围**与**测试真实执行退出码可信**两模式恒适用。裁决落点:`docs/ai/archive/2026-08-05-h5a-validator-foundation-stopped/HANDOFF.md` 账目㉒。
* 重流程(9P 计划审、9A/9B 双审、Frozen Acceptance、批准门,全文仍在 `claude/workflow/AGENTS.md` 与 `claude/workflow/reviewer-prompt.md`)仅在人类明确要求的真项目任务启用;**任何新增流程/规则/登记表/检查项默认「不」**,除非一句话说清净收益。
* per-task 交接文件在 `docs/ai/`,旧任务归档 `docs/ai/archive/<日期-任务>/`。
* 共识基线引用方式:一律指 tag `plan-v1.1`(现为参考材料),不要复述 SHA;artifact 身份链见 `docs/ai/archive/2026-07-30-improvement-plan-v1.1-landing/HANDOFF.md` 与 commit trailers。
* 本仓库无远程操作(NEVER push/pull/merge);push/CI 由人类执行。
