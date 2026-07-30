# 工作流设计原理 + 文档维护规范

> 本文件给"维护这套工作流 / 写那些 command"的人（通常仍是 Agent），**不在任何执行路径上**。把论证从执行文件里挪到这里，是为了让 command 正文只剩指令、不占 context。

## 一、设计原理（从正文移来的论证）

### 为何外部制衡之外还要内部自律（核心原则 9）
双 Agent + 人类门 + 产物化是「外部」制衡，保证"证据存在且被独立检查"。但 Author 这个 Agent 在实现、调试、最终审查时仍会对自己自欺（"应该过了""先这样""大概没问题"）。所以三个关键纪律点统一采用反合理化手法、各按场景取形：

* **验证**（`/implement` 声称完成纪律）：声称闸门 + 禁止词 + claim/要求/不充分表。
* **调试**（`/debug` 系统化调试）：红旗·借口 → 现实表。
* **对待 Reviewer 意见**（`/final-review`）：READ→VERIFY→EVALUATE + 禁止 performative agreement。

核心都是把 Agent 真会用的开脱/敷衍话术摆到台面、当场反制。外部保证证据被检查，内部保证 Author 声称前真看了证据、没用模糊措辞蒙混。两者互补，缺一不可。

### 为何 sub-agent 默认不降级（成本直觉）
便宜模型常需 2~3 倍 turn 完成同一任务，turn 翻倍往往比单 turn 的单价更贵；加上降级后判断质量下降，会把成本转移到返工。所以默认继承主模型——既保质量也未必更费钱。要省成本，别从降级上省，从"交接走文件而非粘大段上下文""prompt 精简"上省（本流程交接已全走 docs/ai 文件，正是为此）。

## 二、文档写法规范

### 形式要匹配失败类型（Match the Form to the Failure）
* **纪律滑坡型**（压力下想跳步）→「禁止 + 借口→现实表 + 红旗清单」。正面说教没用，要把开脱话术逐条堵死。
* **输出形状型**（格式/结构错）→ 正面示范（"输出 IS …" + 模板），不要"不要写成 X"——禁止句会被拿去讨价还价。
* **缺必要元素型**（总忘带某项）→ 用结构：模板里留 REQUIRED 槽位（如 PLAN 的 Approval Status、HANDOFF 的 Quality Gates 表）。
* **条件依赖型**（某情况才适用）→ `if X then Y` 条件句（如各门控"标 N/A 则整节跳过"）。

### 关键措辞先 Micro-Test
吃重的硬门/红线定稿前，用几次 fresh-context 采样（裸开新会话或单发 subagent）验证是否被一致解读；同一句话被解读出多种意思 = 措辞不够约束，要收紧。run-to-run 差异本身就是信号。

### slash command 描述只写"何时触发"（SDO）
每个 command 的 `description` 字段只写"什么场景/什么时候用"，不要总结内部步骤。Agent 可能只读描述就照做、跳过正文——描述里塞半套流程会导致执行走样。描述是触发器，正文才是指令。

## 三、单一定义处索引（改规则时只改一处）

| 规则 | 唯一定义处 |
|------|-----------|
| Safety Rules（禁止事项） | `AGENTS.md` |
| Reviewer 轻量协议 | `AGENTS.md` |
| `[DEBT]` 格式 + No-Hidden-Debt + Payback-on-Touch | `AGENTS.md` |
| 证据 vs 假设标签 | `AGENTS.md` |
| Git 纪律 | `AGENTS.md` |
| 横切质量/安全/隐私/可访问性清单 | `docs/ai/QUALITY_GATES.md` |
| 设计层闸门（清单） | `docs/ai/QUALITY_GATES.md`（§5）；驱动在 `.claude/commands/design-check.md` |
| Reviewer 输出契约 | `reviewer-prompt.md` |
| 四个交接文件结构 | `docs/ai/templates/` |
