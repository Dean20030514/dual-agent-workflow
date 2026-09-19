# dual-agent-workflow 调查与优化报告
## GitHub 对标研究 + Reuse-first 长期弱执行根因分析

> **调查日期**：2026-09-18  
> **目标仓库**：[`Dean20030514/dual-agent-workflow`](https://github.com/Dean20030514/dual-agent-workflow)  
> **目标仓库调查快照**：`dde413c76d64beed48e50489100806685ae4b87b`  
> **报告范围**：
>
> 1. 从 GitHub 寻找与本项目相似、可借鉴或可直接复用的 Agent 编排 / Coding Agent / Worktree / Sub-Agent / Review / Research 项目，用于完善和优化 `dual-agent-workflow`。
> 2. 独立调查现有工作流中 **“Research / Reuse first：先找轮子、尽量复用、不重复造轮子”** 为什么长期缺乏实际体感；该问题不限于最近新增的 Agent Team + Sub-Agent 混合架构。
>
> **本报告不是实现计划批准文件**。其中“建议”部分是基于当前仓库和外部项目的技术判断，落地时仍应按本仓库现有治理约束执行。

---

# 1. 执行摘要

## 1.1 两个问题需要分开看

本次调查的两个问题虽然相关，但根因并不相同。

### 问题 A：`dual-agent-workflow` 整体还能从 GitHub 学什么？

当前仓库已经非常强的部分集中在：

- Git worktree 隔离
- SHA / snapshot 绑定
- Author / Reviewer 隔离
- Local Review + 9A / 9B
- 结构化 Result / Review contract
- Git scope 审计
- 外部验证证据
- recovery / rollback / replan
- native Agent 创建记录
- cost / budget / timeout / idle / lifecycle
- 冻结 authority
- 失败证据保留
- Team Mode 的 L0–L3 路由

也就是说，你的系统现在**不是“缺编排能力”**，而是开始出现一种明显的不对称：

> **任务开始以后，控制面极其严格；任务开始以前，“应该自己做还是找现成方案”这一层仍主要靠自然语言纪律。**

这会造成一个很反直觉的结果：

> 一个非常严格、证据链非常完整、审查非常重的系统，  
> 可以非常严格地从零实现 GitHub 上已经有人做过的东西。

因此下一步最有价值的优化，不是继续增加 Reviewer 层数、状态机或恢复协议，而是：

1. 把 **Reuse / Prior-Art Discovery** 变成真正的准入机制；
2. 降低控制面本身的复杂度增长；
3. 改善上下文发现和任务拆分质量；
4. 把 Team / Sub-Agent 的职责边界进一步机械化；
5. 把已有复杂机制的运行状态变得更容易观察。

---

## 1.2 “Reuse-first 没体感”不是错觉

结论很明确：

> **规则存在，但历史上长期属于“高强度文字规定、低强度机械执行”。**

而且这个问题在 Team Mode 出现之前就存在。

当前工作流确实写了：

- GitHub repository / code search first
- Context7 / 官方文档
- package registry
- 优先 adopt / port / wrap
- 从零自建要说明为什么拒绝现成方案

但是它缺少几个关键条件：

1. 默认 **Routine** 只要求在对话中“简记”；
2. `/explore` 的 `Reuse Findings` 没有独立、持久、机器可校验的产物；
3. `IMPLEMENTATION_PLAN.md` 的 canonical 模板**没有专门的 Reuse / Alternatives 小节**；
4. `TASK_BRIEF.md` 也没有 Reuse 字段；
5. Critical 下主要靠 9P Reviewer“发现你忘写了”，而不是 validation fail-closed；
6. DSH 顶层 Reuse 规则比 Claude 侧更弱，对外部 GitHub 搜索表达不完全一致；
7. 到 Team Mode 后，Reuse 信息干脆没有进入 Plan Schema、Task Packet 或 Result Schema；
8. `research` 角色默认 `network: false`；
9. `team/scripts/Reuse.ps1` 实际是“验证缓存复用”，和“方案复用”同名，概念发生碰撞；
10. 没有任何 Reuse telemetry，所以就算偶尔真的搜了，也很难感知它到底发生过多少次、产生了什么价值。

所以目前的真实状态更接近：

```text
Reuse-first = policy / instruction
而不是
Reuse-first = protocol / admission gate
```

这就是低体感的核心原因。

---

# 2. 调查方法与快照

## 2.1 本仓库重点检查面

本次重点检查了：

- `claude/CLAUDE.md`
- `claude/rules/common/development-workflow.md`
- `claude/commands/explore.md`
- `claude/commands/plan.md`
- `claude/workflow/templates/IMPLEMENTATION_PLAN.md`
- `claude/workflow/templates/TASK_BRIEF.md`
- `claude/workflow/reviewer-prompt.md`
- `dsh/AGENTS.md`
- `dsh/workflow/AGENTS.md`
- `dsh/skills/dual-agent-workflow/**`
- `team/policies/codex-lead-prompt.md`
- `team/policies/delegation.md`
- `team/roles/research.yaml`
- `team/schemas/team-plan.schema.json`
- `team/schemas/task.schema.json`
- `team/schemas/result.schema.json`
- `team/scripts/Execution.ps1`
- `team/scripts/Invoke-DshWorker.ps1`
- `team/scripts/Reuse.ps1`
- `team/README.md`
- 历史 `docs/ai/archive/**`
- Reuse-first 相关 Git commit 历史

---

## 2.2 重点外部项目

本次深入或定向检查的项目包括：

1. [`obra/superpowers`](https://github.com/obra/superpowers)
2. [`wshobson/agents`](https://github.com/wshobson/agents)
3. [`jtmilan/agent-teams`](https://github.com/jtmilan/agent-teams)
4. [`ruvnet/ruflo`](https://github.com/ruvnet/ruflo)
5. [`eyaltoledano/claude-task-master`](https://github.com/eyaltoledano/claude-task-master)
6. [`SWE-agent/mini-swe-agent`](https://github.com/SWE-agent/mini-swe-agent)
7. [`ClipboardHealth/groundcrew`](https://github.com/ClipboardHealth/groundcrew)
8. [`Aider-AI/aider`](https://github.com/Aider-AI/aider)
9. [`smtg-ai/claude-squad`](https://github.com/smtg-ai/claude-squad)
10. [`epilande/ccmux`](https://github.com/epilande/ccmux)
11. [`OpenHands/OpenHands`](https://github.com/OpenHands/OpenHands)
12. `SWE-agent/SWE-agent`（主要作为“复杂版本被 mini 版本替代”的对照）

另外还做了更广泛的 GitHub repository 搜索，但没有把所有搜到的小项目都列入最终推荐，因为“搜到相似”不等于“值得引入”。

---

# 3. 当前 dual-agent-workflow 的总体判断

## 3.1 已经做得很强的部分

你的系统在“执行以后”已经非常成熟。

### 3.1.1 独立工作空间

Team Mode：

```text
Lead
  ↓
Task
  ↓
Worker-specific worktree
  ↓
Worker branch
```

每个 Worker 独立 worktree / branch，是目前多数成熟 Coding Agent 并发系统采用的正确基础。

这一点与：

- Claude Squad
- Groundcrew
- Agent Teams
- 多数 tmux/worktree 编排器

方向一致。

---

### 3.1.2 证据优先而不是模型自述

你已经强制：

- Git diff / SHA
- 真实 command
- exit code
- stdout / stderr receipt
- review snapshot
- frozen authority
- native Agent 创建记录
- external verification
- result schema

这是明显优于大量“纯 Prompt 多 Agent 项目”的地方。

很多 GitHub 上的 Agent Team 项目，本质上只是：

```text
spawn agents
→ agents talk
→ merge
```

而你的项目已经进入：

```text
spawn
→ scope
→ evidence
→ verify
→ independent review
→ exact commit acceptance
→ integration
→ recovery
```

这一部分不应推倒重来。

---

### 3.1.3 对失败状态的保守处理

你的 Team Mode 对：

- input too large
- timeout
- idle
- output overflow
- verification failure
- review failure
- scope violation
- integration failure
- interrupted recovery
- cost unknown

均倾向于保留证据而不是“自动假装成功”。

这是正确方向。

---

## 3.2 当前最大结构性问题

问题不在“后半程”。

问题是前半程：

```text
问题理解
   ↓
现成方案发现
   ↓
是否应自建
   ↓
架构选择
   ↓
任务拆分
```

这几步的机械约束明显弱于：

```text
编码
 ↓
验证
 ↓
审查
 ↓
集成
 ↓
恢复
```

因此建议下一阶段的设计原则变成：

> **Thin Core + Strong Admission Gates**
>
> 核心编排尽可能薄；真正重要的决策变成结构化准入条件，而不是继续叠自然语言规定。

---

# 4. GitHub 对标项目与可借鉴机制

---

# 4.1 `obra/superpowers`

调查快照附近最新提交：

```text
b36e0829c6d0140e93cfef2ca599b1b07d4a7797
```

## 值得学什么

Superpowers 最关键的设计思想不是它有多少 Skill，而是：

> **The agent checks for relevant skills before any task. Mandatory workflows, not suggestions.**

它把：

```text
“最好先使用某个流程”
```

变成：

```text
“开始任务之前就触发流程”
```

其典型链路是：

```text
brainstorming
→ git worktree
→ writing plans
→ subagent-driven-development / executing-plans
→ TDD
→ code review
→ finish branch
```

Sub-Agent Driven Development 又倾向：

```text
fresh subagent
→ 实现一个有界任务
→ spec compliance review
→ code quality review
```

## 对本项目的启发

**最值得借：**

1. 重要流程必须从“建议”升级成“触发器 / gate”；
2. Skill / workflow 是可组合单元；
3. Fresh Agent 用于有界任务；
4. Review 分“需求符合度”和“代码质量”，而不是让一个 Reviewer 什么都看。

## 不建议直接照搬

你已经有自己的：

- Critical / Routine
- 9P / 9A / 9B
- DSH / Codex 双路径
- Team runner

没有必要把整套 Superpowers 再嵌套进去。

真正值得借的是 **“mandatory workflow trigger”** 这条机制思想。

---

# 4.2 `wshobson/agents`

调查快照：

```text
4236bb91f8395b0435f1d8b8baf9e8e4c69a8620
```

这是本次调查中与 `dual-agent-workflow` **概念匹配度最高**的项目之一。

它当前把单一源内容生成到多个 harness：

- Claude Code
- Codex CLI
- Cursor
- OpenCode
- Antigravity
- Copilot
- Pi

其 README 明确强调：

> 一个 source-of-truth，但给每个 harness 生成 harness-native artifact，  
> 而不是 lowest-common-denominator translation。

## 值得学什么

### A. Agent Team 是技能组合，不是一个无限扩张的 Runner

`plugins/agent-teams` 中包含：

- team-lead
- team-reviewer
- team-debugger
- team-implementer

并提供：

- Parallel Research
- Parallel Feature Development
- Multi-Reviewer Review
- Hypothesis-driven Debugging
- Security Audit
- Migration

### B. Research 是一等 Team 模式

它直接支持：

```text
/team-spawn research
```

并让多个 Research Agent 分别调查：

- codebase
- web
- 不同问题维度

最后汇总并带 source。

这非常适合你的 Reuse-first 问题。

### C. “One owner per file”

它的 parallel-feature-development 明确写：

> **One owner per file.**

共享文件时：

1. 指定唯一 owner；
2. 其他 Worker 请求 owner 修改；
3. 或抽出 interface contract；
4. interface contract 由 Lead / 指定 owner 持有。

你的 `write_scope` 已经非常接近这套模型，只差再做一层 overlap validation。

### D. 小 Team

其建议：

```text
2–4 teammates
```

而不是越多越好。

这与当前你的：

```text
max_active_workers: 4
max_parallel_agents_total: 6
```

其实很接近。

这意味着你现在**不需要继续提高 Agent 数量**。

真正缺的是：

- 更好的任务拆分；
- 更明确的 contract owner；
- 更好的 prior-art discovery。

## 建议借用

- Parallel Research 模式思想
- one-owner-per-file
- interface contract ownership
- 小 Team 原则
- source-of-truth → harness-native adapter
- progressive disclosure

## 不建议

不要把 202 个 Agent 全搬进本仓库。

你的目标不是做 Agent Marketplace。

---

# 4.3 `jtmilan/agent-teams`

调查快照：

```text
191dd9adcf1c2043c49ddb0dd54bb17b77dfed42
```

这是本次对 **运行时架构** 最有帮助的参考项目之一。

## 关键架构

README 描述的主要组件：

```text
core/state-adapter
    ↓
normalize harness events
→ state
→ waiting_reason
→ needs_human

core/supervisor
    ↓
在 scoped git worktree 中启动 harness

core/flywheel
    ↓
orchestrate
synthesize
fold
test-gate
verdict
```

## 最值得你借的点：Verdict 是 Trust Boundary

它自己的设计记录对 verdict 很谨慎。

例如：

- worktree 可能被清理，所以 artifact 不能只绑定路径；
- 应绑定 commit OID；
- fold base 应是正确 fork-point；
- main 前进后旧 verdict 可能 stale；
- acceptance 应重新跑 deterministic guard；
- security surface 改变时旧 PASS 不应直接继续有效。

你现在已经做了：

- SHA binding
- frozen authority
- review evidence
- exact commit acceptance

因此这里反而说明：

> 你的大方向是对的。

建议进一步借的是：

### A. normalized state adapter

把不同 Harness：

```text
Claude
Codex
DSH
未来其它 Agent
```

统一成：

```yaml
state: working | waiting | blocked | done | failed
waiting_reason: ...
needs_human: true|false
```

不要让 Lead 或 UI 直接理解每个 Harness 的所有原始状态。

### B. controller-owned verdict trust boundary

不要让 Worker / Reviewer 自己决定：

```text
“我的结果可以被复用”
“我的 verdict 还有效”
```

由 controller 根据：

- source identity
- commit
- policy
- evidence
- staleness

判定。

---

# 4.4 `ruvnet/ruflo`

调查快照：

```text
e558f0c0fc29c1a658085f6e6f80ad27d4fe811f
```

这是一个非常大的系统。

**不建议整体引入。**

但有两个理念很有价值。

## A. Orchestrator 和 Executor 分离

其 AGENTS 明确表达：

```text
Ruflo = coordination ledger
Codex = executor
```

这非常适合继续收紧你的 Lead 职责。

你的 Lead 理想上只应该：

```text
discover
decide
decompose
freeze contracts
route
observe
accept / reject
integrate
```

而不应该变成：

```text
Lead 自己修一部分
Worker 再修
Sub-Agent 再重新设计
Integration Agent 再重构
```

## B. Memory / Pattern Search Before Work

它把：

```text
memory search
```

放在工作开始前。

这可以轻量地借到你的 Reuse 体系：

```text
local reuse catalog
    ↓ miss
GitHub search
    ↓
freeze reuse decision
```

不需要搬它整个 memory / swarm / policy platform。

---

# 4.5 `eyaltoledano/claude-task-master`

调查快照：

```text
c0c98d367c55296bfe69e65680625b6db437af02
```

Taskmaster 值得看的不是 Runtime。

而是：

- task dependencies
- research command
- research model
- main model
- fallback model

## 最大启发

> **Research 是一种一等任务，而不是一句 Prompt。**

你的 Team DAG 已经很成熟。

最自然的演化不是再加一句：

```text
“记得先研究”
```

而是让 DAG 支持：

```yaml
kind: discovery
```

然后：

```yaml
implementation_task:
  dependencies:
    - DISCOVERY-001
```

或者更轻：

```text
Lead-side reuse admission
→ freeze result
→ implementation DAG
```

---

# 4.6 `SWE-agent/mini-swe-agent`

调查快照：

```text
04d809ceab9df28f9adaed044884180159172930
```

这个项目对你现在其实非常重要。

它的核心问题是：

> “如果 Agent 简化 100 倍，效果还能不能接近原系统？”

README 强调：

- Agent class 约百行级；
- 几乎只用 Bash；
- linear history；
- `subprocess.run`；
- 少特殊工具；
- 易调试；
- 易 sandbox；
- 简单而稳定。

而原来的大 `SWE-agent` 已经明确推荐大多数用户转向 `mini-swe-agent`。

## 对你的重要启发

你的历史里已经真实发生过：

```text
stopped, NOT converged — over-engineered
```

因此后续优化应该加一个原则：

> **控制面复杂度本身也必须有准入门。**

任何新增：

- 新状态
- 新 schema
- 新 runner 层
- 新 recovery protocol
- 新 review 阶段
- 新 daemon
- 新 registry

都应该先回答：

1. 现有机制具体解决不了什么？
2. 有真实 failure evidence 吗？
3. 能不能用已有 primitive 组合解决？
4. 新机制是否能替代 / 删除一个旧机制？

否则：

```text
“完善 workflow”
```

很容易再次演变成：

```text
“完善 workflow 的 workflow”
```

---

# 4.7 `ClipboardHealth/groundcrew`

调查快照：

```text
17bdf86cfc0c9b26c3f2cd230dea596af9ad68f8
```

它的定位：

```text
task backlog
→ one worktree per task
→ local interactive coding agent
→ sandbox
→ PR-ready branch
```

## 值得学什么

### A. Sandbox by default

它把：

```text
Safehouse / Docker sandbox
```

作为默认运行形态。

你的当前 DSH Reviewer 是：

```text
same host
same permission
discipline-enforced read-only
```

这在你仓库里已经真实发生过事故。

因此长期可以考虑：

```text
runner:
  host
  docker
  safehouse-like
```

但这不是 P0。

不要为了 sandbox 再造一个容器编排平台。

### B. local / remote 状态分层

Groundcrew 的：

```text
status-local.json
status-remote.json
```

很值得借。

原因：

- local process / worktree / git 信息便宜，可高频；
- remote board / PR / network 信息慢且可能失败；
- 网络失败不能污染本地真实状态。

你的 `status` / `watch` 已经很强，但未来如果继续扩展 UI / operator observability，建议采用这一思路。

---

# 4.8 `Aider-AI/aider`

调查快照：

```text
5dc9490bb35f9729ef2c95d00a19ccd30c26339c
```

Aider 对你最有帮助的是两个点。

## A. Repository Map

Aider 用 tree-sitter 构建 repo map，从整个 repo 中抽取：

- class
- function
- variable
- symbol relationship

然后只向模型提供最相关的信息。

你的 Lead Prompt 当前主要是：

```text
读 AGENTS
读 manifest / policies
看顶层目录
看目标模块
看接口
看测试
```

这依赖 Agent 自己逐步发现。

随着项目变大，这会越来越不稳定。

可以考虑一个轻量的：

```text
repo-context map
```

不需要复制 Aider 整个系统。

你已经有：

- LSP
- Grep / Glob
- language plugins

所以更适合生成：

```yaml
modules:
symbols:
entrypoints:
tests:
contracts:
ownership:
recent_decisions:
```

供 Lead / Worker 按需读取。

## B. Architect / Editor 分离

Aider 的 Architect Mode：

```text
先提出 change plan
→ 再由 editor model 执行修改
```

它说明一个简单事实：

> “想清楚”和“编辑文件”可以是两个不同能力面。

你目前：

```text
Lead / Worker / Reviewer
```

已经更进一步。

所以不必照搬，但这支持一个建议：

> Worker 的 Sub-Agent 更适合做 Specialist / Investigator，  
> 不要再成为递归的小型 Orchestrator。

---

# 4.9 `smtg-ai/claude-squad`

调查快照：

```text
ce1ffb4392b01f38e2c4599c7c84d2a93973b138
```

它非常简单：

```text
tmux
+
git worktree
+
多 Agent session
+
review before apply
```

## 为什么值得保留为对照

它不是因为“比你的好”。

而是它可以成为一个 **复杂度 baseline**。

每次你准备新增 Team 控制面能力，可以问：

> 这个功能为什么不能通过：
>
> - worktree
> - task prompt
> - lifecycle status
> - human review
>
> 这几个简单 primitive 解决？

如果不能，才扩展 Team Runner。

---

# 4.10 `epilande/ccmux`

调查快照：

```text
caeaf60cf340e1164d19b83ea26a9a04d2c251b0
```

它解决的是 operator experience：

- agent working / idle / waiting
- tmux pane tracking
- worktree
- diff review
- subagents/background agents
- handoff
- live preview
- notifications

## 对你的价值

不要急着自己做 Team Dashboard。

如果未来需要：

```text
“我现在到底有哪些 Agent 在跑？”
“谁在等我？”
“哪个 Worktree 有 diff？”
```

优先：

- 复用 ccmux 类 operator 工具；
- 或借它的 hook / state detection 思路。

**不要把 UI 再塞进 Team Runner。**

---

# 4.11 `OpenHands/OpenHands`

调查快照：

```text
a07364828c8f202e7745c6bce3dcef3915ae7ac1
```

当前 OpenHands 的 Agent Canvas 更强调：

```text
control center
        ↓
Agent Server
        ↓
different backends
```

并支持：

- OpenHands
- Claude Code
- Codex
- Gemini
- ACP-compatible agents

## 对你的价值

如果未来：

```text
Claude / DSH / Codex
```

继续扩张到更多 Harness，建议逐渐形成：

```text
semantic protocol
      ↓
harness adapter
```

而不是：

```text
Team Runner
里面到处 if harness == ...
```

但目前不用急着做 ACP 级大改。

---

# 5. 外部项目对本仓库的优先级矩阵

| 项目 | 最值得借的机制 | 适配度 | 建议 |
|---|---|---:|---|
| `obra/superpowers` | mandatory workflow trigger；fresh bounded subagent | 很高 | 借机制，不引入整套 |
| `wshobson/agents` | Parallel Research、one-owner-per-file、small team、harness-native artifacts | 很高 | 重点研究 |
| `jtmilan/agent-teams` | state adapter、supervisor、verdict trust boundary、commit-bound artifact | 很高 | 重点研究 |
| `mini-swe-agent` | 极简 control flow、反过度工程 | 很高 | 作为复杂度基准 |
| `groundcrew` | sandbox、task/worktree、local/remote observability | 高 | 借运行面思想 |
| `Aider` | repo map、上下文选择、Architect/Editor separation | 高 | 借 Context Discovery |
| `Taskmaster` | Research 一等任务、task dependency | 高 | 借 discovery DAG 思想 |
| `Ruflo` | orchestrator/executor 分离、memory-first、small topology | 中高 | 借原则，勿整套引入 |
| `Claude Squad` | 极薄 worktree baseline | 中 | 当复杂度对照 |
| `ccmux` | operator observability / handoff | 中 | 优先复用而非自建 UI |
| `OpenHands` | control-plane/runtime/automation boundary | 中 | 未来多 Harness 再考虑 |

---

# 6. Reuse-first 的历史审计

这是第二个独立问题。

---

# 6.1 这条规则是什么时候真正加入的？

Git 历史显示：

## 2026-08-05

commit：

```text
1d8d2a5b3a15d66520f04ca7dccbec859551837b
```

message：

```text
docs(workflow): mandate research-reuse-first - search GitHub for mature reusable work before building anything new
```

这一版第一次明确加入：

```text
gh search repos
gh search code
Context7
npm / PyPI / crates.io
```

并加入：

```text
/explore → Reuse Findings
/plan → reuse comparison
```

### 因此一个重要事实是：

> 你“很早就有先找轮子的印象”没错，  
> 但当前这套明确的 **GitHub-first** 规则实际上是 2026-08-05 才进入仓库的。

---

## 2026-08-07

commit：

```text
37d30739431ebe2bfca3af946ebc2da2d759b035
```

message：

```text
fix(rules): scope research-reuse-first; drop fixed 80 percent threshold
```

这一轮把：

```text
mandatory before any new implementation
```

收窄成：

```text
new implementation
new dependency
architecture choice
```

以下可以 skip：

```text
pure docs
already-diagnosed bug
established in-repo pattern
```

同时取消固定“80% 覆盖”阈值。

这个修改是合理的，因为固定 80% 没有技术依据。

但它也产生一个副作用：

> 是否属于“可以 skip”的任务，主要由 Agent 自己判断。

如果 Agent 把一个实际上涉及新架构的 bug fix 判成：

```text
already-diagnosed bug
```

就可能合法跳过 Reuse。

---

## 2026-08-27

commit：

```text
f78535791aa309c22ffeeef77fe364cb7df21381
```

加入 mandatory 9P Plan Review。

commit 信息明确提到 Reviewer 会检查：

```text
reuse gaps
```

这让 Reuse 多了一层人工智能审查。

但是：

> **它仍然不是机械 Gate。**

Reviewer 忘了看：

```text
→ 计划仍然可能继续
```

而且这是 Critical 才有。

---

# 7. 为什么旧工作流长期“没体感”

---

# 7.1 原因一：默认 Routine 把 Reuse 降成“对话里简记”

当前 `claude/CLAUDE.md`：

```text
Routine：在对话中简记
Critical：写进 /explore Reuse Findings 与 /plan 方案比较
```

默认又是：

```text
Routine
```

所以绝大多数日常任务的 Reuse 最终是：

```text
短暂自然语言
```

而不是：

```text
结构化 evidence
```

自然会出现：

- 下一轮看不到；
- compact 后弱化；
- 交给 Sub-Agent 时丢失；
- 无法机器统计；
- 无法验证“到底搜没搜”。

---

# 7.2 原因二：`/explore` 有 Reuse Findings，但没有独立持久产物

`claude/commands/explore.md` 明确要求输出：

```text
Reuse Findings
```

但是 `/explore` 本身主要输出到当前会话。

没有：

```text
docs/ai/reuse_findings.yaml
```

也没有：

```text
reuse_decision
```

这种结构化对象。

Critical 虽然要求“进计划”，但这又带来下一个问题。

---

# 7.3 原因三：canonical `IMPLEMENTATION_PLAN.md` 模板根本没有 Reuse 小节

当前模板有：

```text
Goal
Summary
Architectural Layers & Split Assessment
Frozen Acceptance
Current Architecture Understanding
Proposed Changes
Risks & Edge Cases
Execution Steps
Testing Plan
Open Questions
Human Approval Status
```

但是没有：

```text
Reuse Findings
Prior Art
Alternatives Considered
Build vs Reuse
```

这是一个非常关键的结构漏洞。

因为 `/plan` 同时又要求：

> 严格按 canonical 模板骨架。

结果变成：

```text
规则说必须写 Reuse
模板却没有给 Reuse 一个固定位置
```

Agent 只能把它塞进：

```text
Summary
```

或者干脆忘掉。

---

# 7.4 原因四：历史证据证明 9P 只能“补漏”，不是“准入门”

历史：

```text
docs/ai/archive/2026-09-15-h3-installer-hardening-stopped/review_9P.md
```

Reviewer 明确抓到：

```text
N10（复用结论未留痕）
```

修法：

```text
在 PLAN 补一行：
检索范围
+
未找到可复用件
+
不引入新依赖
```

这件事本身就说明：

> Reuse-first 并不是 Plan schema / template validator 保证的，  
> 而是 Reviewer 恰好发现了。

---

# 7.5 原因五：即使“补了 Reuse”，也不代表真的 GitHub-first

同一历史任务的 `IMPLEMENTATION_PLAN.md` 最终写了：

```text
Reuse-first 检索范围 =
仓内全部 .ps1 / 模块 / 测试基建
+
本机已安装 PowerShell 模块
```

然后得出：

```text
没有可复用轮子
```

问题是：

> 顶层规则写的是 GitHub search first。

但该 Reuse 记录中没有留下：

```text
gh search repos
gh search code
```

的外部 GitHub 检索证据。

所以当前系统实际上可以把：

```text
“只搜了本仓库”
```

包装成：

```text
“Reuse-first 已完成”
```

这正是“规则有、体感没有”的直接实例。

---

# 7.6 原因六：DSH 顶层 Reuse 规则与 Claude 侧不完全等价

`dsh/AGENTS.md` 的顶层 Reuse-first 大意是：

```text
官方文档
包注册表
仓内既有实现
```

这里没有像 Claude 的：

```text
gh search repos
gh search code
```

那样明确。

虽然 DSH 的 deeper workflow / explore skill 有仓外 Reuse Findings，但：

> 顶层自动加载规则比按需 skill 更容易实际影响普通 Routine 行为。

因此 DSH 日常任务中，GitHub-first 的实际触发强度比 Claude 侧弱。

---

# 7.7 原因七：skip 规则缺少机械分类

当前允许跳过：

```text
pure doc
already-diagnosed bug
existing in-repo pattern
```

但没有结构化 classifier。

所以：

```text
“这是不是新实现？”
“这是 bug fix 还是架构变化？”
```

最终由同一个要执行任务的 Agent 自己判断。

这很容易出现：

```text
bug fix
→ 为了修 bug 新造一个 subsystem
→ 仍然没有 Reuse search
```

---

# 7.8 原因八：没有 Reuse telemetry

当前你能看到：

- Agent 数
- budget
- cost
- retry
- verification
- review
- status
- recovery

但是看不到：

```text
本月 20 个适用任务
其中 17 个做了外部检索
5 个直接采用现成库
4 个移植现有实现
6 个参考外部模式
2 个最终从零自建
3 个违规未检索
```

所以用户体感必然弱。

---

# 8. Team Mode 为什么把问题进一步放大

Team Mode 并不是 Reuse-first 的起源问题，但它把旧问题变成了协议缺口。

---

# 8.1 Lead Prompt 没有 Reuse Admission

当前：

```text
team/policies/codex-lead-prompt.md
```

Lead 被要求：

- 读 rules
- route
- plan
- DAG
- role
- write_scope
- acceptance
- verification
- budget
- review
- integrate
- replan

但没有强制：

```text
prior-art discovery
GitHub search
package search
reuse decision
```

---

# 8.2 Team Plan Schema 没有 Reuse 字段

当前：

```text
team/schemas/team-plan.schema.json
```

Task 有：

```yaml
id:
role:
objective:
dependencies:
write_scope:
acceptance:
verification:
permissions:
subagents:
```

但没有：

```yaml
research:
reuse:
reuse_findings:
prior_art:
reuse_decision:
borrow_map:
```

并且：

```json
"additionalProperties": false
```

所以不是“大家忘了用”。

而是：

> 当前协议本身没有给 Reuse 一个合法数据位置。

---

# 8.3 Task Packet 丢掉 Reuse 上下文

`Execution.ps1` 给 Worker 的 packet 主要是：

```text
role
objective
dependencies
permissions
write_scope
acceptance
subagents
verification
base_sha
```

没有：

```text
Lead 找到了哪些外部实现
哪些机制应该借
哪些方案已经被拒绝
为什么拒绝
引用的 commit / version 是什么
```

因此 Worker 合理地会认为：

```text
“我的任务就是实现 objective”
```

而不是：

```text
“我的任务是在冻结的 reuse decision 约束下实现 objective”
```

---

# 8.4 Worker Prompt 没有 GitHub Research 责任

`Invoke-DshWorker.ps1` 主要强调：

- 读 AGENTS
- scope
- role
- permission
- subagent limit
- implement
- self-check
- commit
- Result Packet

没有明确要求重新做 prior-art discovery。

这一点本身未必错。

实际上：

> **Worker 不应该全部重复 GitHub Research。**

正确设计应该是：

```text
Lead / Reuse Scout 搜索一次
      ↓
冻结 ReuseDecision
      ↓
Worker 消费 Borrow Map
```

---

# 8.5 `research` 角色默认 `network: false`

当前：

```yaml
role_id: research

default_permissions:
  shell: true
  network: false
  secrets: false
  production: false
```

所以 Team Mode 里最正式的“研究角色”默认更像：

```text
local repository researcher
```

而不是：

```text
external prior-art researcher
```

建议以后区分：

```text
research-local
research-external
```

或者让 network 权限成为 Reuse Scout 的显式 task permission。

---

# 8.6 `Reuse.ps1` 的名字产生概念碰撞

当前：

```text
team/scripts/Reuse.ps1
```

做的是：

```text
deterministic verification reuse / verification cache
```

也就是：

```text
同一个命令
同一个源码
同一个环境
同一个输入
能否复用之前成功的验证结果
```

它不是：

```text
“有没有现成方案可以复用”
```

建议术语彻底拆开：

```text
Solution Reuse / Prior-Art Discovery
```

vs.

```text
Verification Cache
```

甚至脚本未来可以直接改名：

```text
Reuse.ps1
→ VerificationCache.ps1
```

减少整个仓库的语义混乱。

---

# 9. 推荐的新总流程

不建议新增一个庞大的“Research Framework”。

建议只插入一个很窄的准入层：

```text
User Task
   │
   ▼
Task Classification
   │
   ▼
Reuse Applicability
   │
   ├─ skipped（合法枚举理由）
   │
   └─ required
          │
          ▼
     Prior-Art Discovery
          │
          ├─ local catalog
          ├─ repo search
          ├─ code search
          ├─ package registry
          └─ primary docs
          │
          ▼
      ReuseDecision
          │
          ▼
   Architecture / Plan
          │
          ▼
      Task DAG
          │
    ┌─────┴─────┐
    ▼           ▼
 Worker A    Worker B
    │           │
 Specialist  Specialist
 Sub-Agent    Sub-Agent
    │           │
    └─────┬─────┘
          ▼
      Verification
          ▼
       Review
          ▼
      Integration
```

---

# 10. ReuseDecision：建议新增的最小数据契约

核心原则：

> 不再要求模型“记得 Reuse”，而要求任务在首次实现前存在一个合法 `ReuseDecision`。

建议最小结构：

```yaml
reuse:
  applicability: required

  searches:
    - source: github_repositories
      query: "multi agent coding worktree orchestration"
    - source: github_code
      query: "worktree reviewer subagent"

  candidates:
    - id: REF-001
      source: github
      repository: jtmilan/agent-teams
      revision: 191dd9adcf1c2043c49ddb0dd54bb17b77dfed42
      relevant_paths:
        - core/state-adapter
        - core/supervisor
      decision: reference
      rationale:
        - "状态归一化与 worktree supervisor 适配当前问题"
        - "不适合直接作为 PowerShell Team Runner 依赖"

  final_decision:
    strategy: adapt
    rationale:
      - "保留现有控制面，只移植 state normalization 思路"
```

---

## 10.1 合法 skip

Routine 小任务不能因此变重。

所以允许：

```yaml
reuse:
  applicability: skipped
  reason: diagnosed_local_bug
```

但是 `reason` 应该是枚举：

```text
docs_only
diagnosed_local_bug
established_repo_pattern
data_only
```

不要接受：

```text
reason: not needed
```

这种万能出口。

---

## 10.2 一个重要修正

“bug fix”不能自动免检。

如果一个 bug fix：

- 新增 dependency
- 新增 subsystem
- 新增 protocol
- 引入新的 control-plane primitive
- 改 architecture

那仍然应该：

```text
reuse = required
```

也就是说 classifier 应看：

```text
任务实际解法
```

而不只是：

```text
用户把任务叫 bug 还是 feature
```

---

# 11. Reuse Gate 应该怎么机械执行

---

# 11.1 Claude / Critical

在 `/plan` 进入 Pending 前：

```text
ReuseDecision required
+
结构合法
+
适用任务至少完成要求的 search source
```

否则：

```text
PLAN_INVALID_REUSE_EVIDENCE
```

不要等 9P 才发现。

---

# 11.2 Claude / Routine

Routine 不应该生成一堆 docs/ai 文件。

建议：

在第一次写文件 / 引入 dependency / 做 architecture change 之前，要求当前任务上下文存在一个简化的：

```text
Reuse Decision
- applicability:
- searched:
- decision:
```

它可以只占几行。

关键是由 hook / workflow bootstrap 检查“有没有”，而不是靠模型记忆。

---

# 11.3 DSH

DSH 顶层规则应与 Claude 对齐：

明确写：

```text
GitHub repository search
GitHub code search
primary docs
package registry
```

不要只写：

```text
官方文档 / 包注册表 / 仓内实现
```

同时：

> DSH 的 detailed skill 可以定义执行细节，顶层 AGENTS 负责不可错过的 trigger。

---

# 11.4 Team Mode

Team Plan 加：

```yaml
reuse:
```

Task 可只引用：

```yaml
reuse_refs:
  - REF-001
  - REF-003
```

不要把完整研究材料复制到每个 Worker。

---

# 12. Team Worker 应收到 Borrow Map，而不是完整调查报告

建议 Task Packet 新增：

```yaml
reuse_context:
  strategy: adapt

  references:
    - id: REF-001
      repository: jtmilan/agent-teams
      revision: 191dd9adcf1c2043c49ddb0dd54bb17b77dfed42
      paths:
        - core/state-adapter
      borrow:
        - normalized runtime state
        - waiting_reason
        - needs_human

  constraints:
    - do_not_vendor_entire_project
    - preserve_existing_team_protocol
```

这样 Worker 明确知道：

```text
“借什么”
“不要借什么”
```

而不是让 Worker 自己再次漫游 GitHub。

---

# 13. Result 也应该记录 Reuse 偏离

可以加：

```yaml
reuse:
  references_used:
    - REF-001

  deviations:
    - reference: REF-001
      reason: "其 Unix process lifecycle 不适合 Windows PowerShell runner"
```

Reviewer 只需要检查：

> Plan 冻结说要借 A，Worker 为什么最后完全写了 B？

而不是 Reviewer 自己重新做一次大规模 GitHub 搜索。

---

# 14. Reuse Scout 的正确定位

不建议：

```text
每个 Worker → 自己 GitHub 搜索
```

这会产生：

- 重复 token
- 不同版本
- 不同结论
- 重复网络访问
- Worker context 膨胀
- implementation / research 职责混乱

建议：

```text
Lead
  ↓
一个 Reuse Scout
  ↓
ReuseDecision
  ↓
Lead freeze
  ↓
Workers
```

复杂任务最多：

```text
Scout A → GitHub implementation
Scout B → package/library
Scout C → architecture/reference
```

然后 Lead synthesis。

---

# 15. Agent Team + Sub-Agent 混合架构的建议边界

---

# 15.1 Team Agent

Team Worker 负责：

- persistent task ownership
- worktree
- branch
- commit
- dependencies
- result
- review lifecycle

---

# 15.2 Sub-Agent

Sub-Agent 只负责：

- bounded investigation
- narrow specialist analysis
- hypothesis test
- narrowly delegated implementation
- test analysis

---

# 15.3 不要递归 Orchestration

推荐：

```text
Lead
  → Worker
      → Specialist
```

避免：

```text
Lead
  → Worker
      → Coordinator
          → Workers
              → Subagents
```

后者会造成：

- authority 模糊
- scope 传播难
- budget 难算
- review ownership 模糊
- 上下文指数级增长
- error attribution 困难

你的当前：

```text
max_active_workers = 4
max_parallel_agents_total = 6
subagent max_depth = 2
```

数量本身已经足够。

下一步不应该继续加 Agent。

---

# 16. 任务拆分：把 `write_scope` 升级成真正的 ownership contract

借鉴 `wshobson/agents`：

> One owner per file.

建议 `team validate` 增加：

```text
并行 task 的 write_scope 有交集？
```

如果有：

```text
拒绝
```

除非 Plan 明确：

```yaml
shared_contract:
  path: src/contracts/foo.ts
  owner: TASK-CONTRACT
```

或者：

```yaml
integration_owner: TASK-INTEGRATE
```

这样可以减少：

- merge conflict
- implicit interface drift
- integration agent 二次重设计

---

# 17. Context Discovery：建议借 Aider，而不是让 Lead “多读点文件”

目前 Lead 的上下文发现仍比较依赖：

```text
自己看目录
自己找接口
自己找测试
```

建议未来加入轻量 `repo-context`。

例如：

```yaml
repo_context:
  entrypoints:
  modules:
  symbols:
  tests:
  public_contracts:
  config_surfaces:
  ownership:
  recent_decisions:
```

信息来源优先：

- Git
- LSP
- tree-sitter（如果值得）
- manifest
- AGENTS
- tests

而不是把整个 repo 丢进模型。

---

# 18. 观测性：建议借 Groundcrew / ccmux，而不是继续加业务状态

你已经有很多内部 state。

下一步更重要的是让人能看懂：

```text
谁在跑？
谁在等待？
谁需要人类？
哪个 worktree 脏？
哪个 review 在准备？
哪个 task 卡在 dependency？
```

建议统一成很少的 operator state：

```yaml
state: working | waiting | blocked | review | done | failed
reason:
needs_human:
task:
agent:
worktree:
commit:
```

原始内部状态仍保留。

但 UI / status summary 不要直接暴露几十种内部实现细节。

---

# 19. 一个需要特别警惕的问题：你的系统可能开始“治理过度”

你已经有真实历史：

```text
stopped, NOT converged — over-engineered
```

而 mini-SWE-agent 的发展方向恰恰证明：

> 更强模型时代，Agent scaffold 不一定越大越好。

建议新增一个非常简单的设计纪律：

## Control-plane Complexity Gate

新增控制面机制之前必须回答：

```text
1. 哪个真实 failure mode 证明现有机制不够？
2. 最小已有 primitive 组合为什么解决不了？
3. 新机制引入几个新 state / schema / persistent artifacts？
4. 能删掉 / 合并哪个旧机制？
5. 如果不做，新系统真正会出现什么用户可观察错误？
```

如果这些问题回答不了：

```text
不新增控制面。
```

这可能比再加 10 条 Quality Gate 更重要。

---

# 20. 建议的优先级

---

# P0：最应该先做

## P0-1. Reuse Admission Gate

覆盖：

```text
Claude Routine
Claude Critical
DSH Routine
DSH Critical
Team Mode
```

目标：

```text
Reuse-first 从文字规定 → 机器可判断的协议。
```

---

## P0-2. 解决 Reuse 术语冲突

把：

```text
Solution Reuse / Prior-Art
```

和：

```text
Verification Reuse / Cache
```

彻底分开。

建议：

```text
team/scripts/Reuse.ps1
→ team/scripts/VerificationCache.ps1
```

如果暂时不改文件名，也至少文档和函数概念统一改叫：

```text
verification cache
```

不要再简称 Reuse。

---

## P0-3. 给 canonical Plan Template 增加固定 Reuse 小节

新增：

```md
## Reuse / Prior Art Decision
```

这一步非常小，但价值很高。

因为当前模板和规则本身是矛盾的。

---

## P0-4. Team Plan / Task Packet 传播 Reuse Context

必须解决：

```text
Lead 研究了
→ Worker 却不知道
```

---

# P1：高价值优化

## P1-1. `write_scope` overlap validator

实现：

```text
one owner per file
```

并显式支持 contract owner。

---

## P1-2. Context Map

减少 Lead / Worker 的盲目探索。

---

## P1-3. normalized harness state

借鉴：

```text
jtmilan state-adapter
```

把 Harness 原始状态映射成少数稳定语义。

---

## P1-4. Reuse telemetry

例如：

```yaml
reuse_stats:
  applicable: 12
  searched: 11
  adopted: 2
  adapted: 4
  wrapped: 1
  referenced: 3
  built_new: 1
  skipped: 8
  violations: 1
```

这会直接解决“我怎么一点体感都没有”。

---

# P2：有需要再做

## P2-1. local Reuse Catalog

成功采用过的模式进入一个很小的 catalog：

```yaml
patterns:
  - id: worktree-lifecycle
    source: ...
    revision: ...
    use_when:
    borrowed:
    last_verified:
```

以后：

```text
catalog search
→ miss
→ GitHub search
```

不要做成新的大型向量数据库。

---

## P2-2. pluggable sandbox runner

例如：

```text
host
docker
safe sandbox
```

但只在实际安全需求驱动下做。

---

## P2-3. Harness Adapter 层

未来 Harness 真正增加后，再考虑：

```text
semantic protocol
→ Claude adapter
→ Codex adapter
→ DSH adapter
```

目前不要提前造 ACP 框架。

---

# 21. 建议修改的具体文件

下面不是要求一次全部改完，而是推荐改点。

---

## 21.1 Claude 侧

### `claude/CLAUDE.md`

改：

- 只保留 Reuse trigger 和指针；
- 不继续加更多散文；
- 明确 `ReuseDecision` 是准入对象。

---

### `claude/rules/common/development-workflow.md`

作为唯一详细定义处，增加：

```text
Reuse applicability
skip enum
minimum search evidence
candidate decision
build-new justification
```

---

### `claude/commands/explore.md`

输出从：

```text
Reuse Findings
```

升级为：

```text
ReuseDecision
```

---

### `claude/workflow/templates/IMPLEMENTATION_PLAN.md`

必须增加：

```md
## Reuse / Prior Art Decision
```

并明确：

```text
required / skipped
search scope
candidates
decision
build-new rationale
```

---

### `claude/workflow/templates/TASK_BRIEF.md`

不需要塞完整搜索报告。

只要可选写：

```text
Reuse Applicability
```

或者让 Plan 是唯一落点。

不要重复事实源。

---

# 21.2 DSH 侧

### `dsh/AGENTS.md`

与 Claude 统一：

```text
GitHub repository search
GitHub code search
primary docs
package registry
```

---

### `dsh/skills/dual-agent-workflow/references/phases/explore.md`

输出同一个 ReuseDecision 结构。

---

### `dsh/skills/dual-agent-workflow/references/phases/plan.md`

不要再只靠自然语言：

```text
“方案必须先过复用检索”
```

而应：

```text
“缺合法 ReuseDecision，不得进 Pending”
```

---

# 21.3 Team Mode

### `team/policies/codex-lead-prompt.md`

增加：

```text
L1–L3 规划前先完成 Reuse Applicability。
required → 必须冻结 ReuseDecision。
```

但不要把详细搜索程序复制一遍。

---

### `team/schemas/team-plan.schema.json`

增加 top-level：

```yaml
reuse:
```

推荐 top-level，而不是每个 Task 各自做 research。

---

### `team/scripts/Contracts.ps1` / Plan validation 路径

增加：

```text
required task + no reuse evidence
→ fail
```

这是真正的关键。

---

### `team/roles/research.yaml`

选择其一：

#### 方案 A

拆成：

```text
research-local
research-external
```

#### 方案 B

保持一个角色，但外部 Reuse Task 显式：

```yaml
permissions:
  network: true
```

不建议简单粗暴把所有 research 默认网络永久打开。

---

### `team/scripts/Execution.ps1`

Task Packet 增加：

```yaml
reuse_context:
```

只发送 Worker 需要的 Borrow Map。

---

### `team/schemas/task.schema.json`

增加：

```yaml
reuse_context:
```

---

### `team/schemas/result.schema.json`

增加：

```yaml
references_used:
deviations:
```

---

### `team/scripts/Reuse.ps1`

建议重命名：

```text
VerificationCache.ps1
```

并同步 `team.ps1` 模块加载。

这是概念清晰度优化，不是功能改动。

---

### `team/tests/**`

至少新增：

1. applicable + no ReuseDecision → reject
2. legitimate skip enum → accept
3. arbitrary skip reason → reject
4. external research required but network not authorized → fail / escalate
5. Reuse refs propagate into Task Packet
6. Worker Result can report reference used
7. Worker deviation is visible
8. parallel write_scope overlap → reject
9. explicit shared contract owner → accept

---

# 22. 不建议做什么

---

## 22.1 不要引入整个 Ruflo

太重。

你真正需要的只有少数理念。

---

## 22.2 不要再造一个 Research Framework

你只需要：

```text
Reuse Applicability
+
small Scout
+
ReuseDecision
+
Gate
```

---

## 22.3 不要每个 Worker 都 GitHub 搜索

浪费且会产生不一致。

---

## 22.4 不要再增加 Reviewer 层来解决 Reuse

Reuse 缺失应该：

```text
plan invalid
```

而不是：

```text
再多一个 Reviewer 来发现。
```

---

## 22.5 不要把 Sub-Agent 变成递归 Team Lead

Sub-Agent 应该是 specialist。

---

## 22.6 不要为了“可观测性”自己造大 Dashboard

先复用：

- tmux
- ccmux 类工具
- current CLI status

---

## 22.7 不要把“参考外部项目”误解为“直接复制代码”

Reuse 有很多层级：

```text
adopt
wrap
port
adapt
reference
reject-with-reason
```

只要能避免重新犯已经被别人解决过的设计错误，`reference` 本身就是有效复用。

---

# 23. 推荐的最终目标架构

```text
                     ┌────────────────────┐
                     │     User Task      │
                     └─────────┬──────────┘
                               │
                               ▼
                     ┌────────────────────┐
                     │  Task Classification│
                     └─────────┬──────────┘
                               │
                               ▼
                     ┌────────────────────┐
                     │ Reuse Admission Gate│
                     └───────┬───────┬────┘
                             │       │
                          skip     required
                             │       │
                             │       ▼
                             │  Prior-Art Scout
                             │       │
                             │       ▼
                             │  ReuseDecision
                             │       │
                             └───┬───┘
                                 ▼
                         Context Discovery
                                 │
                                 ▼
                         Plan / Task DAG
                                 │
                 ┌───────────────┴───────────────┐
                 ▼                               ▼
          Worker / Worktree                Worker / Worktree
                 │                               │
                 ▼                               ▼
          bounded specialist              bounded specialist
            subagents                       subagents
                 │                               │
                 └───────────────┬───────────────┘
                                 ▼
                           Verification
                                 │
                                 ▼
                        Independent Review
                                 │
                                 ▼
                          Lead Acceptance
                                 │
                                 ▼
                            Integration
```

---

# 24. 这次调查最重要的三个结论

## 结论 1

你的 Agent Team / Sub-Agent 主要问题不是“还缺更多 Agent 能力”。

而是：

> **控制面已经很强，但 discovery / reuse / context / decomposition 仍比执行与审查弱。**

---

## 结论 2

Reuse-first 长期没体感不是错觉。

当前机制仍主要是：

```text
规则
+
Prompt
+
Reviewer 事后补漏
```

而不是：

```text
结构化对象
+
validator
+
admission gate
+
telemetry
```

---

## 结论 3

下一轮不要继续“全面优化 Team Mode”。

推荐先做一个范围非常窄的改造主题：

# `Reuse-First Admission & Contract Propagation`

只解决：

1. Reuse applicability
2. ReuseDecision
3. validator
4. Plan template
5. Claude / DSH parity
6. Team Lead → Plan → Worker 的 Reuse context 传播
7. Reuse telemetry
8. `VerificationCache` 与 `SolutionReuse` 术语拆分

做完以后，再继续：

```text
write_scope ownership
→ repo context map
→ normalized state
→ optional sandbox
```

这样比继续给当前 Team Runner 打补丁，更有可能真正改善你日常使用时的效果。

---

# 25. 推荐落地顺序

## Slice A — 修复 Reuse-first 的“规则—模板—协议”断裂

只做：

- ReuseDecision 定义
- IMPLEMENTATION_PLAN 固定小节
- Claude / DSH 一致
- skip enum
- basic validator

先不要碰 Team Runtime。

---

## Slice B — Team Mode 传播

做：

- team-plan `reuse`
- Lead gate
- Task Packet `reuse_context`
- Result refs / deviations
- tests

---

## Slice C — Team ownership

做：

- overlapping write_scope 检测
- one-owner-per-file
- shared contract owner

---

## Slice D — Context discovery

做：

- lightweight repo context map

---

## Slice E — Operator experience

先评估能否直接利用：

- ccmux
- tmux
- 现有 status/watch

只有现成工具满足不了时再自建。

---

# 26. 外部参考项目索引

## 强相关

- [obra/superpowers](https://github.com/obra/superpowers)
- [wshobson/agents](https://github.com/wshobson/agents)
- [jtmilan/agent-teams](https://github.com/jtmilan/agent-teams)
- [SWE-agent/mini-swe-agent](https://github.com/SWE-agent/mini-swe-agent)
- [ClipboardHealth/groundcrew](https://github.com/ClipboardHealth/groundcrew)
- [Aider-AI/aider](https://github.com/Aider-AI/aider)

## 中度相关

- [ruvnet/ruflo](https://github.com/ruvnet/ruflo)
- [eyaltoledano/claude-task-master](https://github.com/eyaltoledano/claude-task-master)
- [smtg-ai/claude-squad](https://github.com/smtg-ai/claude-squad)
- [epilande/ccmux](https://github.com/epilande/ccmux)
- [OpenHands/OpenHands](https://github.com/OpenHands/OpenHands)

---

# 27. 本仓库关键证据索引

- [`claude/CLAUDE.md`](https://github.com/Dean20030514/dual-agent-workflow/blob/main/claude/CLAUDE.md)
- [`claude/rules/common/development-workflow.md`](https://github.com/Dean20030514/dual-agent-workflow/blob/main/claude/rules/common/development-workflow.md)
- [`claude/commands/explore.md`](https://github.com/Dean20030514/dual-agent-workflow/blob/main/claude/commands/explore.md)
- [`claude/commands/plan.md`](https://github.com/Dean20030514/dual-agent-workflow/blob/main/claude/commands/plan.md)
- [`claude/workflow/templates/IMPLEMENTATION_PLAN.md`](https://github.com/Dean20030514/dual-agent-workflow/blob/main/claude/workflow/templates/IMPLEMENTATION_PLAN.md)
- [`dsh/AGENTS.md`](https://github.com/Dean20030514/dual-agent-workflow/blob/main/dsh/AGENTS.md)
- [`team/policies/codex-lead-prompt.md`](https://github.com/Dean20030514/dual-agent-workflow/blob/main/team/policies/codex-lead-prompt.md)
- [`team/schemas/team-plan.schema.json`](https://github.com/Dean20030514/dual-agent-workflow/blob/main/team/schemas/team-plan.schema.json)
- [`team/scripts/Execution.ps1`](https://github.com/Dean20030514/dual-agent-workflow/blob/main/team/scripts/Execution.ps1)
- [`team/scripts/Invoke-DshWorker.ps1`](https://github.com/Dean20030514/dual-agent-workflow/blob/main/team/scripts/Invoke-DshWorker.ps1)
- [`team/roles/research.yaml`](https://github.com/Dean20030514/dual-agent-workflow/blob/main/team/roles/research.yaml)
- [`team/scripts/Reuse.ps1`](https://github.com/Dean20030514/dual-agent-workflow/blob/main/team/scripts/Reuse.ps1)
- [`team/schemas/result.schema.json`](https://github.com/Dean20030514/dual-agent-workflow/blob/main/team/schemas/result.schema.json)

## Reuse-first 历史提交

### 首次正式加入 GitHub-first

[`1d8d2a5b3a15d66520f04ca7dccbec859551837b`](https://github.com/Dean20030514/dual-agent-workflow/commit/1d8d2a5b3a15d66520f04ca7dccbec859551837b)

```text
2026-08-05
docs(workflow): mandate research-reuse-first
```

### 收窄适用面并取消固定 80% 阈值

[`37d30739431ebe2bfca3af946ebc2da2d759b035`](https://github.com/Dean20030514/dual-agent-workflow/commit/37d30739431ebe2bfca3af946ebc2da2d759b035)

```text
2026-08-07
fix(rules): scope research-reuse-first; drop fixed 80 percent threshold
```

### 计划审查开始负责发现 reuse gap

[`f78535791aa309c22ffeeef77fe364cb7df21381`](https://github.com/Dean20030514/dual-agent-workflow/commit/f78535791aa309c22ffeeef77fe364cb7df21381)

```text
2026-08-27
feat(workflow): add mandatory 9P plan review
```

---

# 28. 最终建议

如果下一轮只选一件事做，不建议继续扩 Team Mode 的功能面。

建议任务标题直接定为：

```text
Reuse-First Admission & Contract Propagation
```

验收目标不是：

```text
“文档里又强调了一遍先找轮子”
```

而是：

```text
对于需要 Reuse 检索的任务，
如果没有合法 ReuseDecision，
系统在实现开始前机械拒绝；
一旦完成，ReuseDecision 能从 Lead / Plan
稳定传播到 Worker / Reviewer，
且 status 能看到它实际发生过。
```

只有做到这一点，“先找轮子”才会从一句长期规则变成你真正能感受到的工作流能力。
