---
description: 正式写计划前的只读探索阶段。当需要在不改任何代码的前提下摸清项目结构、现有模式与风险时使用。
---

# Phase 1：只读探索（Author）

优先用 Claude Code plan mode（Shift+Tab）——工具层禁止写文件，比 prompt 约束可靠。不支持则遵守：
1. 不改任何代码、不创建文件。
2. 读结构/配置/测试/相关源码。
3. 找现有模式，不凭空设计。

输出：
* **Project Understanding**：结构、技术栈、核心流程。
* **Relevant Files**：相关文件及重要性。
* **Existing Patterns**：已有类似实现、命名、测试方式。
* **Risks**：API 兼容 / DB / 类型 / 测试 / 安全 / 回归。
* **Recommended Direction**：初步方向，不写代码。

> 探索阶段是查清 `/plan` 中所有 Unknown 的窗口。下一步：`/plan`。
