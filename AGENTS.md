# AGENTS.md — dual-agent-workflow(项目工作契约)

> 本文件是在**本仓库内做开发任务**时的项目级 Agent 契约。跨项目纪律不在此复述——本仓库在树内自带母本 `claude/workflow/AGENTS.md`(Safety Rules / Reviewer-Lightweight Protocol / No-Hidden-Debt·[DEBT] / 证据 vs 假设标签 / 验证三分类 / 守护有效性装置 / Fix-Loop / Git Discipline,各节均为唯一定义处),**全部条款对本仓库任务原样适用**。本文件只记录项目特有事实、命令与差异。

## Project Overview
个人双 Agent 工作流 + Claude Code/Codex 全局配置的**规范事实源(canonical source)**。当前规范版本 = `main` 当前 tip;本机 `~/.claude/` 与 `~/.codex/` 中**由部署器持续镜像的受管路径**是本仓库的运行副本,受管面上的可复用修改须经仓库可见 diff 晋升——受管面边界、seed-only 与 machine-local 例外**以 README 文首契约与 `docs/ai/AUTHORITY_CONTRACT.md` 为唯一定义处,此处不另行定义**。当前执行 `IMPROVEMENT_PLAN.md`(tag `plan-v1.1` = commit `e4092c3`,blob `7d9530f6…`;APPROVED FOR PLANNING INPUT)的 Round 1;每个 PR 单独过 Frozen Acceptance + Human Approval 闸门。

## Build / Test / Lint Commands
可执行面 = `install.ps1`(PS 5.1 兼容,部署脚本)+ H5A 起的 `tools/validate/` 与 `.github/workflows/`。
* 全量校验:`pwsh -File tools/validate/validate.ps1`(退出码 0 = PASS 或 PASS_WITH_BASELINE / 1 = FAIL / 2 = ENVIRONMENT_ERROR;BASELINE 不得伪装成 PASS)
* 单项:`pwsh -File tools/validate/validate.ps1 -Check <name>`
* 单测:`pwsh -Command "Invoke-Pester -Path tools/validate/tests -CI"`
* 依赖模块(**不自动安装**,缺失 = ENVIRONMENT_ERROR,exit 2 + 安装指引):powershell-yaml、PSScriptAnalyzer、Pester ≥5,精确版本冻结于 `tools/validate/requirements.psd1`;gitleaks 为本地前置工具(一次性安装,pinned release + checksum),缺失同为 ENVIRONMENT_ERROR,CI 强制。

## Code Style Rules
* 用户可读文档中文为主;代码、注释、提交信息英文(Conventional Commits)。
* UTF-8 无 BOM;LF(`.gitattributes` 强制)。
* PowerShell 新代码目标 pwsh 7;`install.ps1` 保持 5.1 兼容,勿顺手"现代化"。
* 检出的内容漂移按所属 PR 修(H1/H2/H3/H4),validator 任务只登记豁免、不代修。

## Safety / Workflow(指向唯一出处)
* 禁止事项、Reviewer 协议、SHA 绑定、Fix-Loop 硬停:`claude/workflow/AGENTS.md`。
* per-task 交接文件在 `docs/ai/`,旧任务归档 `docs/ai/archive/<日期-任务>/`;质量清单 `docs/ai/QUALITY_GATES.md`。
* 共识基线引用方式:一律指 tag `plan-v1.1`,不要复述 SHA;artifact 身份链见 `docs/ai/archive/2026-07-30-improvement-plan-v1.1-landing/HANDOFF.md` 与 commit trailers。
* 本仓库无远程操作(NEVER push/pull/merge);CI 真实结果由人类 push 后确认。
