# dual-agent-workflow 通用性问题专项报告
## Harness / Agent / Model 绑定过深导致的可移植性不足

> **日期**：2026-09-18  
> **目标仓库**：`Dean20030514/dual-agent-workflow`  
> **主题**：当前工作流对 Claude Code / Codex / DSH 的具体能力绑定过深，导致更换主力 Harness 时需要重新适配甚至重新实现工作流能力，整体通用性不足。

---

# 1. 问题定义

当前 `dual-agent-workflow` 在设计之初，实际上默认了明确的执行角色绑定：

```text
Claude Code = Author
Codex CLI   = Reviewer
```

随后随着实际使用变化，又扩展为：

```text
Codex = Lead / Reviewer
DSH   = Worker / Sub-Agent / Local Reviewer
```

这使得当前工作流并不是一个真正独立于 Agent / Model / Harness 的开发协议，而是：

```text
工作流方法论
+
Claude Code 原生能力
+
Codex 原生能力
+
DSH 专门适配
```

因此当某个 Harness 暂停使用、替换或升级时，影响的不只是“运行器”，而是整套 Workflow 能力。

最典型的现实问题就是：

> 暂时停用 Claude Code，改用 Codex + DSH 后，Codex 并没有 Claude Code 原来的那套 commands / rules / Plan Mode / Task-Agent 等能力，DSH 也必须重新做专门 Landing 和适配。

这说明当前架构存在明显的 **Harness Coupling（Harness 耦合）**。

---

# 2. 当前仓库中的结构性表现

目前仓库的主要结构大致是：

```text
dual-agent-workflow/
├── claude/
│   ├── CLAUDE.md
│   ├── commands/
│   ├── rules/
│   ├── settings.json
│   └── workflow/
│
├── codex/
│   ├── AGENTS.md
│   └── config.example.toml
│
├── dsh/
│   ├── AGENTS.md
│   ├── skills/
│   └── workflow/
│
├── portable/
│   ├── 通用prompt-v3.8.txt
│   └── 通用prompt-DSH-v1.txt
│
└── team/
    ├── manifest.yaml
    ├── policies/
    ├── roles/
    ├── schemas/
    ├── scripts/
    └── tests/
```

从这个结构可以看出：

- Claude Code 有完整的一套 Workflow 实现；
- DSH 又有自己的一套 Workflow / Skill 实现；
- Codex 主要承担 Reviewer / Team Lead 职责；
- Portable 又有两份不同 Harness 的大 Prompt；
- Team Mode 还直接把 Codex 和 DSH 写进 Runtime 与 Policy。

这实际上形成了：

```text
Claude-specific Workflow
DSH-specific Workflow
Codex-specific Rules
Team-specific Codex/DSH Runtime
```

而不是：

```text
Generic Workflow Core
        ↓
Harness Adapters
```

---

# 3. 最典型的历史证据：DSH Landing

仓库历史中已经发生过一次完整的 DSH Landing。

目标本质上是：

```text
把原来的 Claude Code Author × Codex Reviewer 工作流
迁移到 DeepSeek Harness
```

因此新增了：

```text
dsh/AGENTS.md
dsh/workflow/
dsh/skills/dual-agent-workflow/
dsh/skills/independent-review/
portable/通用prompt-DSH-v1.txt
```

并重新处理了大量 Harness 差异：

- DSH 没有 Claude Code 的 slash commands；
- DSH 的 subagent / subagent_fork 行为不同；
- DSH 的 Reviewer 没有 Codex sandbox 那种物理只读边界；
- DSH headless 输入方式不同；
- structured output 需要 adapter；
- provider / model / reasoning effort 路由不同；
- Reviewer verdict 通过 stdout，而不是 Codex 的 `-o`；
- fresh-context 的实现方式不同；
- holding / zero-write / review isolation 也要重新设计。

这证明：

> 当前更换 Harness 的成本，接近“重新实现一遍 Workflow”。

理想状态应该是：

```text
换 Harness ≈ 新增 / 修改 Adapter
```

而不是：

```text
换 Harness ≈ 再做一次 Landing
```

---

# 4. 根本问题：Workflow Semantic 与 Harness Feature 混在一起

现在很多工作流语义，其实暗含了具体 Harness 能力。

例如：

```text
/explore
/plan
/implement
/debug
/final-review
```

它们在语义上本应只是：

```text
Explore Phase
Planning Phase
Implementation Phase
Debug Phase
Final Review Phase
```

但实际实现却与 Claude Code 的：

```text
Slash Commands
Plan Mode
CLAUDE.md
Rules
Task / Agent
Skill / Plugin
```

绑定。

因此最初的工作流实际上默认：

> Claude Code 拥有的能力 = Workflow 拥有的能力。

一旦 Claude Code 暂停使用：

```text
Workflow Capability
```

也一起消失。

正确关系应当是：

```text
Workflow requires capability X
        ↓
Harness Adapter decides how to provide X
```

而不是：

```text
Workflow directly calls Claude/Codex/DSH-specific feature X
```

---

# 5. Model / Agent / Harness 三层耦合

当前需要区分三个概念。

## 5.1 Model

例如：

```text
GPT-6 Astra
DeepSeek Flash
Claude Opus
```

Model 决定：

- 推理质量；
- 成本；
- 上下文；
- structured output 能力；
- 工具使用能力。

Model 不应该决定 Workflow 结构。

---

## 5.2 Agent Role

例如：

```text
Lead
Author
Worker
Reviewer
Researcher
Integrator
Specialist
```

这是 Workflow Semantic。

这些角色应该独立于具体 Harness。

---

## 5.3 Harness

例如：

```text
Claude Code
Codex CLI
DSH
Gemini CLI
OpenCode
Cursor Agent
Pi
```

Harness 决定：

- 怎么传 Prompt；
- 怎么调用工具；
- 怎么启动子 Agent；
- 有没有 sandbox；
- 怎么获得 structured output；
- 怎么 cancel / resume；
- 怎么获得 runtime state。

Harness 应该是实现层。

---

# 6. 当前 Team Mode 的耦合尤其明显

当前 Team Mode 中：

```text
Codex = Lead
DSH   = Worker
DSH   = Local Reviewer
Codex = Critical Reviewer
```

而且仓库中存在：

```text
team/policies/codex-lead-prompt.md
team/scripts/Invoke-DshWorker.ps1
```

文件名本身就已经说明：

> Team Runtime 认识具体 Harness。

长期更合理的形式应该是：

```text
team/policies/lead.md
team/runtime/Invoke-Worker.ps1
```

然后由：

```text
Harness Adapter
```

决定到底调用：

```text
Codex
DSH
Claude Code
其它 CLI Agent
```

---

# 7. 推荐目标：Harness-Agnostic Workflow Core

下一阶段应该明确引入一个真正的：

# Harness-Agnostic Workflow Core

建议目标结构：

```text
dual-agent-workflow/
│
├── core/
│   ├── policies/
│   ├── phases/
│   ├── contracts/
│   ├── schemas/
│   ├── roles/
│   ├── review/
│   ├── reuse/
│   └── capabilities/
│
├── adapters/
│   ├── claude-code/
│   ├── codex/
│   ├── dsh/
│   └── generic-cli/
│
├── team/
│   ├── coordinator/
│   ├── runtime/
│   └── schemas/
│
├── distributions/
│   ├── claude-code/
│   ├── codex/
│   └── dsh/
│
└── generated/
```

核心原则：

```text
core = Workflow 的真正事实源
adapter = Harness-specific 实现
distribution = 最终给各 Harness 使用的产物
```

---

# 8. Core 中不应该出现 Claude / Codex / DSH

Workflow Core 应该只认识：

```text
Lead
Author
Worker
Reviewer
Researcher
Integrator
Specialist
```

或者更抽象：

```text
planner
implementer
reviewer
researcher
integrator
```

Core 不应该知道执行它们的是：

```text
Claude Code
Codex
DSH
Gemini
OpenCode
Cursor
Pi
```

---

# 9. 从“按 Harness 名字路由”改成“按 Capability 路由”

当前架构容易出现：

```powershell
if ($Harness -eq 'dsh') {
    ...
}

if ($Harness -eq 'codex') {
    ...
}
```

长期应该变成：

```text
Workflow Role
    ↓
Capability Requirements
    ↓
Harness Capability Match
    ↓
Adapter
```

例如 Reviewer 要求：

```yaml
reviewer:
  required_capabilities:
    - repo_read
    - diff_read
    - fresh_context
    - structured_output
    - zero_write

  preferred_capabilities:
    - filesystem_readonly
    - sandbox
```

---

# 10. 建议建立 Harness Capability Contract

当前仓库已经有一个很好的雏形：

```text
team/spike/DSH_CAPABILITY_MATRIX.md
```

它已经在记录：

- 输入；
- 输出；
- exit；
- structured result；
- model route；
- subagent；
- adapter 能力。

建议把它提升成正式通用能力模型。

例如：

```yaml
harness: dsh

capabilities:
  execution:
    interactive: true
    headless: true

  input:
    argv: true
    stdin: false
    file: false
    native_config: true

  output:
    stdout: true
    structured_native: false

  agents:
    spawn: true
    fork: true
    max_depth: 2

  isolation:
    fresh_context: true
    filesystem_readonly: false
    sandbox: false

  tools:
    shell: true
    git: true
    network: conditional

  lifecycle:
    observable: true
    cancel: true
    resume: limited
```

Codex / Claude Code 各自再有对应 capability 描述。

---

# 11. Workflow 要求 Capability，而不是要求具体 Harness

例如 Core 定义：

```yaml
phase: explore

requires:
  - repo_read
  - search
  - external_research
  - no_repository_write
```

Claude Adapter：

```text
Plan Mode
+
Claude tools
```

Codex Adapter：

```text
sandbox
+
Codex tool policy
```

DSH Adapter：

```text
prompt discipline
+
behavioral zero-write
+
post-run verification
```

因此：

> 统一的是语义，不是具体实现方式。

---

# 12. 不要为了通用性降成 Lowest Common Denominator

通用化不意味着：

```text
所有 Harness 只使用大家共同拥有的最低能力
```

这样会浪费高级 Harness 功能。

正确模式：

```text
Core:
需要 read-only exploration
```

Claude：

```text
用 Plan Mode
```

Codex：

```text
用 read-only / sandbox 能力
```

DSH：

```text
无物理只读
→ 使用行为约束 + 事后证据验证
```

因此：

```text
Semantic Contract 一致
Implementation 可以不同
```

---

# 13. Role Binding 应与 Workflow 分离

当前：

```yaml
models:
  lead:
    harness: codex
    runtime_model: gpt-6-astra

  worker:
    harness: dsh
    runtime_model: deepseek-flash
```

作为当前机器的配置没问题。

问题是它不应该变成 Workflow 的定义。

建议改成：

```yaml
roles:
  lead:
    requires:
      - planning
      - repo_read
      - git
      - structured_output
      - external_research

  worker:
    requires:
      - repo_read
      - repo_write
      - shell
      - git

  reviewer:
    requires:
      - repo_read
      - diff_read
      - fresh_context
      - zero_write
```

然后另设：

```yaml
bindings:
  lead:
    harness: codex
    model: gpt-6-astra

  worker:
    harness: dsh
    model: deepseek-flash

  reviewer:
    harness: codex
    model: gpt-6-astra
```

以后换组合：

```yaml
bindings:
  lead:
    harness: dsh

  worker:
    harness: codex

  reviewer:
    harness: claude-code
```

Core 不需要修改。

---

# 14. 模型也应该属于 Binding / Certification 层

Critical Review 不应该在 Workflow Core 中写：

```text
必须 GPT-X
必须 DeepSeek-X
```

Core 更适合写：

```yaml
review_requirement:
  independence: fresh
  reasoning: high
  write_access: forbidden
  context_contamination: forbidden
```

Deployment / Certification 再解析为：

```text
Codex + GPT-X + high
```

或者：

```text
DSH + DeepSeek-X + max
```

模型版本 pin 仍然可以保留。

但它属于：

```text
runtime certification
deployment profile
```

而不是：

```text
workflow semantics
```

---

# 15. `/explore` 等 Phase 也应该从 Harness UI 中抽离

Core：

```yaml
phase: explore

goals:
  - understand_repository
  - find_existing_patterns
  - perform_reuse_discovery
  - identify_risks

outputs:
  - project_understanding
  - relevant_files
  - existing_patterns
  - reuse_decision
  - risks
  - recommended_direction

repository_write: false
```

然后：

```text
Claude Code:
/explore
→ Claude Adapter
→ Core Explore
```

```text
DSH:
skill explore
→ DSH Adapter
→ Core Explore
```

```text
Codex:
Codex skill / command
→ Codex Adapter
→ Core Explore
```

这样 `/explore` 只是 UI。

不是 Workflow 本体。

---

# 16. Portable Prompt 也应该成为生成物

当前：

```text
portable/通用prompt-v3.8.txt
portable/通用prompt-DSH-v1.txt
```

本质上说明：

> Core 没有独立出来，所以只能把整套流程展开成 Harness-specific 大 Prompt。

问题包括：

- 内容重复；
- 修规则需要多处同步；
- Harness 之间容易漂移；
- Portable Claude 版本已经非常大；
- 未来每加一个 Harness 可能又多一份 Prompt。

建议未来：

```text
Core Source
    +
Adapter
    ↓
Generated Distribution
```

例如：

```text
core
 + claude adapter
 → CLAUDE.md
 → commands
 → rules

core
 + dsh adapter
 → AGENTS.md
 → skills

core
 + codex adapter
 → AGENTS.md
 → skills/config
```

Portable 也从 Core 自动生成。

---

# 17. 很适合借鉴 `wshobson/agents` 的思路

这个项目的重要理念是：

```text
Single Source of Truth
        ↓
Harness-native artifacts
```

而不是：

```text
所有 Harness 共用一份最低公分母 Prompt
```

对于 `dual-agent-workflow` 最合适的目标也是：

> **共用 Workflow Semantic，生成 Harness-native 表达。**

---

# 18. Team Runtime 最终也应该 Adapter 化

当前：

```text
Codex Lead
DSH Worker
```

未来：

```text
Lead Role
Worker Role
Reviewer Role
```

Runtime：

```text
Resolve Binding
      ↓
Resolve Harness Adapter
      ↓
Invoke Role
```

例如：

```text
Invoke-AgentRole(
    role = worker,
    binding = profile.worker
)
```

Adapter 再决定：

```text
dsh
codex
claude
```

---

# 19. 推荐三层架构

## Layer 1 — Semantic Core

只定义：

```text
Task
Phase
Role
Capability
Acceptance
ReuseDecision
Review
Evidence
Result
Handoff
State
```

---

## Layer 2 — Harness Adapter

负责：

```text
Prompt transport
Tool mapping
Sub-Agent spawning
Fresh context
Sandbox / zero-write
Structured output
Cancel / resume
Runtime observation
Model routing
```

---

## Layer 3 — Binding / Profile

决定当前环境：

```text
谁做 Lead
谁做 Worker
谁做 Reviewer
用哪个 Harness
用哪个 Model
```

例如：

```yaml
profile: codex-dsh

bindings:
  lead:
    harness: codex
    model: gpt-6-astra

  author:
    harness: dsh
    model: deepseek-flash

  reviewer:
    harness: codex
    model: gpt-6-astra
```

如果重新启用 Claude：

```yaml
profile: claude-codex

bindings:
  author:
    harness: claude-code

  reviewer:
    harness: codex
```

Core 不变。

---

# 20. 最终甚至可以支持 Capability-Based Auto Routing

任务需要：

```text
fresh_context
network_research
repo_read
zero_write
```

Runtime 可以检查：

```text
Codex reviewer
→ satisfies

DSH reviewer
→ satisfies with degraded isolation

Claude reviewer
→ satisfies
```

然后根据：

```text
policy
availability
certification
cost
user preference
```

选择。

这比：

```text
Reviewer 永远 = Codex
```

更健壮。

---

# 21. 但不要直接做“大一统 Universal Agent Platform”

这是最大的风险。

解决耦合问题，很容易走向：

```text
Universal Agent OS
Universal Runtime
Universal Protocol
Universal Registry
Universal Capability Graph
```

这会再次过度工程。

因此建议渐进式改造。

---

# 22. 推荐实施 Slice

## Slice U1 — 只抽语义，不改 Runtime

建立：

```text
core/
```

先分类已有规则：

```text
Workflow Semantic
Claude-specific
Codex-specific
DSH-specific
Team-specific
```

此阶段：

```text
行为完全不变
```

---

## Slice U2 — Capability Contract

把已有：

```text
DSH_CAPABILITY_MATRIX
```

抽象成：

```text
HarnessCapability Schema
```

先只支持：

```text
Claude Code
Codex
DSH
```

不要支持十几个 Harness。

---

## Slice U3 — 选择一个小协议验证 Core → Adapter

最适合的第一个候选：

# Reuse-first

因为它正好同时存在：

- Claude；
- DSH；
- Team；
- Codex Lead。

目标：

```text
core/reuse
    ↓
Claude Adapter
Codex Adapter
DSH Adapter
Team consumes same contract
```

这样一次同时验证：

1. Harness 解耦是否成立；
2. Reuse-first 能否真正统一。

---

## Slice U4 — 生成 Harness-native Distribution

逐步把：

```text
claude/
dsh/
codex/
portable/
```

从独立事实源变成：

```text
Core + Adapter 的生成物
```

不要一次全部重构。

---

## Slice U5 — Team Runtime Adapter 化

最后再处理：

```text
codex-lead-prompt.md
Invoke-DshWorker.ps1
```

目标：

```text
Lead
Worker
Reviewer
```

不再硬编码具体 Harness。

---

# 23. 与 Reuse-first 问题的关系

前一个问题是：

```text
Reuse-first 有规则
但没有机械 Gate
```

这个问题更底层：

```text
连 Workflow 自己都没有独立于 Harness
```

因此最合理的下一阶段顺序是：

```text
P0-A
Harness-Agnostic Core

P0-B
Reuse-first 作为第一条 Core Protocol

P1
Team Contract Propagation

P1
write_scope ownership

P1
repo context discovery

P2
更多 Harness
```

---

# 24. 当前问题的一句话总结

当前 `dual-agent-workflow` 最大的通用性问题不是：

```text
Codex 不如 Claude 功能多
```

也不是：

```text
DSH 缺少某个工具
```

真正的问题是：

> **Workflow 曾经默认“Claude Code 拥有的能力，就是 Workflow 拥有的能力”。**

因此换 Harness 时：

```text
Harness feature changes
        ↓
Workflow capability also changes
```

正确架构应该是：

```text
Workflow Semantic
       ↓
Capability Requirement
       ↓
Harness Adapter
       ↓
Claude / Codex / DSH / Future Harness
```

---

# 25. 最终建议

下一阶段不要再分别：

```text
完善 Claude 版
完善 DSH 版
完善 Codex 版
```

而应该先建立：

# `Harness-Agnostic Core`

然后把：

# `Reuse-first`

作为第一条真正通用的 Workflow Protocol 迁移进去。

成功标准不是：

```text
三边文档看起来差不多
```

而是：

> 同一个 Core Contract，在不修改 Workflow Semantic 的前提下，可以由 Claude Code、Codex、DSH 三种不同 Harness 分别实现；切换 Binding 时，只需要替换 Adapter / Profile，而不是重新 Landing 一整套 Workflow。

这才算真正解决当前的通用性问题。
