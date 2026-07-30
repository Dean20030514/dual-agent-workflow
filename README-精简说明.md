# 精简说明 README（v3.0 → v3.1）

本目录提供两份交付物，二选一或并用：

## 交付物 A：单文件精简版
* `通用prompt-v3.1.txt` — 保持原单体结构，应用了去重 + 论证压缩 + 表格合并 + 9A/9B 合并 + 括号瘦身。**1121 → 764 行（约 -32%）；字节 70189 → 53650（约 -24%）**。想继续只用一个 `@文件` 的，用这个。

## 交付物 B：结构化拆分版（推荐长期用）
按"长期规则集中、各 Phase 按需加载"重组，单次进 context 的量降一个数量级：

```
AGENTS.md                          # ★ 所有重复硬规则的唯一定义处（Safety/[DEBT]/Reviewer协议/证据假设/Git）
CLAUDE.md                          # 一行 @AGENTS.md
通用prompt-索引.md                  # 瘦身入口：总览 + 9 条精简原则 + 命令对照（不含可执行指令）
reviewer-prompt.md                 # 9A/9B 合并版，复制给 Codex CLI
.claude/commands/
  define.md  explore.md  plan.md  design-check.md  implement.md  debug.md  final-review.md
docs/ai/QUALITY_GATES.md           # 横切质量/安全/隐私/可访问性 + 上线后（Reviewer 直接读，无需粘贴）
docs/ai/templates/                 # PRODUCT_BRIEF / TASK_BRIEF / IMPLEMENTATION_PLAN / HANDOFF 模板
docs/workflow-design-notes.md      # 移出执行路径的设计原理 + 文档维护规范（附录二）
```

用法：把 `AGENTS.md`/`CLAUDE.md`/`.claude/`/`docs/` 拖进项目根；之后在 Claude Code 直接 `/define`、`/explore`、`/plan` … 各命令只加载当前 Phase。

## 做了哪 6 个精简动作（功能零损失）

1. **结构外置**：长期规则 → AGENTS.md（always 生效、可缓存）；各 Phase → slash command（用到才加载）。原本"禁止整文件读取 + Grep 锚点"那套元协议因此基本消失。
2. **消灭逐字重复**：Reviewer 轻量协议（原全文 5 处）、`[DEBT]` 格式（3 处）、证据/假设标签示例（多处）→ 各自只定义一次，其余引用。
3. **why 与 what 分离**：核心原则 9 长论证、"不降级成本直觉"、事故复述 → 移到 `workflow-design-notes.md`，执行文件只留规则。
4. **合并重叠表格**：0.1 的「18 维扫描表」+「落地章节对照表」合成一张（多一列）。
5. **合并 9A/9B**：输出契约定义一份，9B 只声明"减 PLAN、末节换 Requirement-Level Concerns"。
6. **瘦身行内括号**：保留指针型交叉引用，删解释型括号。

## 没动什么（承重墙，刻意原样保留）
按附录二"形式要匹配失败类型"，下列反合理化设计的冗长是功能性的，全部保留：
* 声称完成纪律（声称闸门 + 禁止词 + claim/要求/不充分表）
* 系统化调试（借口 → 现实 红旗表）
* 对待 Reviewer 意见（READ→VERIFY→EVALUATE + 禁止 performative agreement）
* AGENTS.md 的 Safety Rules

所有规则的"唯一定义"一处不少，门控逻辑、硬门、产物化要求全部保留。
