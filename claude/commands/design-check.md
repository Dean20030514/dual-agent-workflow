---
description: 任务产出界面或面向用户内容时的设计层验收。当本次涉及 UX/UI/美术/文案（0.1 第 4/5/6/15 维标关注）时使用；纯后端/库跳过。
---

# 设计层闸门（UX / UI / 美术内容 / 文案）

> 门控：0.1 第 4/5/6/15 维；无界面或面向用户内容则整节跳过。

本命令负责"何时跑、怎么跑"；**逐项清单的唯一定义处在 `docs/ai/QUALITY_GATES.md` 的「设计层闸门」节**（Reviewer 独立进程也读那里），本命令不复制清单，只驱动复核：

1. **门控判断**：本任务是否触及 0.1 第 4/5/6/15 维；不触及则整节跳过。
2. **三道复核**：Phase 0/规划期先勾（预判，未想清算 Open Question）→ 实现完成自检 → Reviewer 复核（受 Reviewer-Lightweight Protocol 约束）。
3. **产物化**：需渲染才能判定的项，证据须为截图，命名 `docs/ai/screenshots/<task>-<断点>.png`，HANDOFF 指向；无截图不得勾过。响应式/多主题分别覆盖项目声明的最小/最大断点与各主题，不支持则该项 N/A。
4. **逐项对照**：按 `docs/ai/QUALITY_GATES.md` 设计层闸门（5.1 UX / 5.2 UI / 5.3 美术内容 / 5.4 文案）自检（项目无此文件则从 `~/.claude/workflow/QUALITY_GATES.md` 母本 scaffold），结果记入 HANDOFF 的 Quality Gates。
