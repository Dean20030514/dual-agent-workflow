# TASK_BRIEF.md

> per-task 文件，blind review 的唯一需求依据，必须自洽：只看此文件应能判断实现对不对。

## Dimension Applicability Scan
粘贴 /define 0.1 的 18 维结果（关注/N/A + 原因）。

## Original Request
[粘贴或总结用户原始需求]

## Goal
本次任务最终要达成什么。

## Non-Goals
明确哪些不做。

## Constraints
限制条件。

## Acceptance Criteria（含 Frozen Acceptance；review-sensitive）
可验证（具体测试命令 + 预期结果）。本字段是验收条件与 **Frozen Acceptance** 的单一事实源：改实现前冻结、禁从当前实现反推（要成立的性质 / 适用范围 / 明确例外 / 正反案例 / 边界 / 必经真实路径；来源 TASK_BRIEF·接口契约·批准计划·人工确认）；守护类 AC 的冻结输入域与等价类枚举也写在这里（AGENTS.md → 守护有效性装置）。审后修改使审查失效——除非修订出自人类裁决（记「人类裁决 / Amendment」+ 日期，见 AGENTS.md → 最后一轮独立审查门 ③）。

## Relevant User Preferences
如 不夹带无关改动 / 输出中文说明 / 不要大规模重构。
