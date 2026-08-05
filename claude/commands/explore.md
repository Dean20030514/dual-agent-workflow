---
description: 正式写计划前的只读探索阶段。当需要在不改任何代码的前提下摸清项目结构、现有模式与风险时使用。
argument-hint: [可选：聚焦范围]
---

# Phase 1：只读探索（Author）

先读 `AGENTS.md` 与 `docs/ai/HANDOFF.md`。聚焦：$ARGUMENTS

优先用 Claude Code plan mode（Shift+Tab）——工具层禁止写文件，比 prompt 约束可靠。不支持则遵守：
1. 不改任何代码、不创建文件。
2. 读结构/配置/测试/相关源码。
3. 找现有模式，不凭空设计。
4. **仓外复用检索（先找轮子）**：GitHub 找成熟的/可复用的/可二次开发的相似实现，再查官方文档与包注册表（完整程序见 `rules/common/development-workflow.md` §0）——站在巨人肩膀上，不重复造轮子。

输出：
* **Project Understanding**：结构、技术栈、核心流程。
* **Relevant Files**：相关文件及重要性。
* **Existing Patterns**：已有类似实现、命名、测试方式。
* **Reuse Findings**：仓外找到的现成实现/库/模板；采用、移植、包装或不采用的理由。
* **Risks**：API 兼容 / DB / 类型 / 测试 / 安全 / 回归。
* **Recommended Direction**：初步方向，不写代码。**推荐针对问题的整体最优 / 耐久方向，不是改动最小的方向**——最优方向即使改动更大也照样推荐、标出 trade-off，别默认拣小的（选小方案图省事会导致后续修补）。

> 探索阶段是查清 `/plan` 中所有 Unknown 的窗口。下一步：`/plan`。
