# DSH landing notes（`dsh/` 的派生记录）

> 本文件是 **DSH 工作流落地的改点清单与状态登记**，不是规则出处。规则判据唯一出处 = `dsh/workflow/AGENTS.md`（DSH 会话）。
> 状态：**候选 overlay（candidate），未经本工作流自己的 9P/9A/9B 审查**；已**人工部署**到本机 `~/.dsh/`（`AGENTS.md`、`workflow/`、`skills/{dual-agent-workflow,independent-review}`），部署为 `install.ps1` 受管面的**手写等价物**（脚本本身受迁移期 guard 锁定，未运行）。详见文末「未偿还的债」。

## 1. 派生方法（可复现）

不是为了省事，而是为了**降低转录漂移**：DSH 侧与 Claude 侧必须共享同一套判据，逐字重打一遍必然产生悄悄的分歧。

```
# 1) 机械复制骨骼（不改一字）
claude/workflow/AGENTS.md          → dsh/workflow/AGENTS.md
claude/workflow/reviewer-prompt.md → dsh/workflow/reviewer-prompt.md
claude/workflow/{index,QUALITY_GATES,workflow-design-notes,AB-model-diagnostic}.md → dsh/workflow/
claude/workflow/templates/         → dsh/workflow/templates/
claude/commands/*.md               → dsh/skills/dual-agent-workflow/references/phases/

# 2) 机械路径改写（无歧义，可脚本化）
~/.claude/workflow/   → ~/.dsh/workflow/
.claude/commands/X.md → ~/.dsh/skills/dual-agent-workflow/references/phases/X.md
~/.claude/rules/common/agents.md 引用 → 删除，改用 dsh/AGENTS.md → Roles

# 3) 有界人工改点（下表逐条列表，改动本身可 diff 复核）
```

phase 文件额外做了两处 frontmatter 归一：加 `name: phase-<原命令名>`（skill 发现要求 name 字段）与 `disable-model-invocation: true`（这些是**流程正文**，不该作为 skill 出现在模型可见目录里；它们由人和 Author 按路径读取）。

## 2. 有界改点清单（**只有这些**，其余与母本逐字一致）

| # | 位置 | 改点 | 理由 |
|---|---|---|---|
| 1 | `AGENTS.md` → Mode Scope | 路由指向 `dsh/AGENTS.md`；加"DHS 侧母本"定位句与冲突裁决 | 两套落地需要各自唯一的判据出处 |
| 2 | `AGENTS.md` → Reviewer-Lightweight Protocol | 背景节加 DSH 迁移注：**Codex 沙箱（EPERM）兜底在 DSH 消失**——Reviewer 同机同权限、写得到仓库 | 这是 DSH 落地**唯一**的实质性放松风险点，必须显式写明 |
| 3 | `AGENTS.md` → AI Collaboration Rules | 零写入的落地形态改为"verdict = agent 返回正文，Author 落盘" | `subagent` 没有 `-o`；Reviewer 落盘即破坏零写入 |
| 4 | `AGENTS.md` → 证据 vs 假设 | 加"模型与推理档断言以 `list_subagent_models` / 适配器目录为准" | 型号换代频繁（`deepseek-flash` = V4.1-Flash），禁止凭记忆 |
| 5 | `AGENTS.md` → 新增 `## DSH Runner` | 主路径（`subagent`）/ 备用路径（headless）/ 两条都不许做的事 | 原母本没有这一节（Codex 时代只有一个调用面） |
| 6 | `AGENTS.md` → Reviewer verdict 分类语义 | "兼容 Codex 强制结构" → "本工作流自己的契约" | 顶层字段契约不再受制于 Codex 的结构要求 |
| 7 | `reviewer-prompt.md` | 全文 DSH 化：调用形态 ③ 换成 `subagent` + headless 两个模板与参数；④ 的 holding 落盘改为 Author 执行；新增 `writes_performed` 必填字段；新增 `## Author 侧：发 9A/9B 前置检查` 清单；9P 节换成 `reasoning_effort: medium` 的调用模板 | 只改"怎么跑"，判据/字段/阈值不动 |
| 8 | `QUALITY_GATES.md` | 组织与角色分配节：删掉 Claude 侧专家 agent 的历史叙述，改为 DSH 现实（只有 `subagent`/`subagent_fork`/`workflow`）+ 派发上限指引 | 该节原内容是关于已卸载插件的本机事实，在 DSH 下已失效 |
| 9 | `index.md` | 角色行、命令对照表、Reviewer prompt 行改为 DSH 形态 | 导航必须指向真实存在的文件 |
| 10 | `debug.md` / `final-review.md` | "继承主对话模型"的判据改为"fresh 上下文"（`subagent` 天然 fresh）；`Reviewer（Codex）` → `Reviewer（DSH subagent / headless）` | DSH 下"模型不同"不是独立性来源，"上下文不同"才是 |
| 11 | `plan.md` / `implement.md` | 加 `exit_plan_mode ≠ Critical 批准门`；`Ready for Review` 改为"可投给 DSH Reviewer 的两份 prompt"+ 调用参数 | 这两个是 DSH 特有的认知陷阱 |
| 12 | 新增 `fanout-toolchain.md` | DSH 工具面事实：委派三面、参数与白名单、派发上限、失败语义 | 母本没有对应物；把"事实"与"判据"分开，升级包后只需核对这一份 |

**没有改的**：Safety Rules、`[DEBT]` 格式、Payback-on-Touch、验证三分类、守护有效性装置（含四条失败判据与负向对照）、验收可复现判定、review-sensitive paths + SHA 绑定、Fix-Loop 计数/硬停/轮次上限/三者优先级、最后一轮独立审查门、Git Discipline、单轮 diff 预算、停止事件优先级、输出契约的七个顶层字段、9A/9B/9P 的检查重点与 9P 的单轮规则。**这些判据与阈值一字未改。**

## 3. 未偿还的债（登记，不藏）

```
[DEBT] dsh/ 全套与 portable/通用prompt-DSH-v1.txt 未经 9P/9A/9B 审查 | Payback trigger: 下次在 DSH 会话里启用 Critical，或下次改动 dsh/** 之前 | Impact: 未审的判据副本可能含语义漂移，却被当作权威执行（且它现在已是本机生效的运行副本）
[DEBT] dsh/workflow/fanout-toolchain.md 的 DSH 事实绑定 @deepseek-ai/dsh 0.1.5-rc.x | Payback trigger: dsh 包升级后首次派发审查之前 | Impact: 参数/工具名变化会让调用范式静默失效
[DEBT] ~/.dsh 的运行副本由本轮人工复制产生，`.dsh.bak-*` 不存在 | Payback trigger: 首次用 install.ps1（或任何镜像脚本）覆盖 ~/.dsh 之前 | Impact: 首次自动部署没有上一版可回退
```

三笔都已在本文件与 `README.md`（快照状态节）如实登记。**没有第三种状态**：要么跑一轮审查转成已审版本，要么人类明确批准延期。

## 4. 部署（本轮已人工执行）

`install.ps1` 已加入 DSH 部署段（`~/.dsh/AGENTS.md`、`~/.dsh/workflow/` 镜像；`~/.dsh/skills/{dual-agent-workflow,independent-review}/` 镜像；其余 `~/.dsh/skills` 内容不动；`~/.dsh` 整树先备份一次）。**但脚本受迁移期 guard 锁定，本轮没有运行它**（AGENTS.md 明令：受迁移期 installer guard 锁定，勿直接运行）。因此本轮改走人工等价部署：

```
dsh/AGENTS.md                                   → ~/.dsh/AGENTS.md
dsh/workflow/**                                 → ~/.dsh/workflow/**
dsh/skills/{dual-agent-workflow,independent-review}/** → ~/.dsh/skills/ 同名目录
（未触碰：settings.yaml、sessions/、storages/、.credentials.yaml、profiles/、以及 ~/.dsh/skills 下其它内容）
```

**两处与将来 `install.ps1` 部署的差异，升级时要补**：① 本轮没有产生 `*.bak-<时间戳>`（脚本会先备份 `~/.dsh` 与每个目标）；② 本轮复制后，若仓内 `dsh/**` 再有改动，`~/.dsh` 副本不会自动跟随——**改仓为唯一真相，改完手动同步，或等 H3 解锁脚本**。这条差异已登记为 `[DEBT]`（见上）。

## 5. 验证记录（本轮，Author 自报；未构成独立证据）

* `dsh/` 骨骼与母本的逐字一致性：脚本级复制 + 12 处有界改点，改点可 `git diff dsh/` 复核。
* skill 结构：三个 `SKILL.md` 的 frontmatter 含 `name` / `description`（`dsh-skill-filesystem` 的必需字段）；7 个 phase 文件额外带 `disable-model-invocation: true`。
* 工具面事实来源：`@deepseek-ai/dsh-agent-presets/presets/standard/agent.cordis.yml`（`subagent` 行配置）、`@deepseek-ai/dsh-tool-subagent/README.md`、`@deepseek-ai/dsh-llm-deepseek/lib/index.js`（`DEFAULT_MODELS`、`reasoningEffort` 取值）、`@deepseek-ai/dsh-skill-filesystem/README.md`（roots 与 frontmatter）；模型档位佐证 = DeepSeek 官方公告（V4.1 Flash 发布，`deepseek-flash` 为最新 id，旧 id 路由到它）。
* `dsh --profile headless` 冒烟（真实运行，各一次）：① 可用，默认模型为 `deepseek-flash`，会加载工作区 AGENTS.md 基线；② 把 `dsh/skills/dual-agent-workflow/` 复制到 `~/.dsh/skills/` 后，一个 fresh 会话的技能目录**确实出现该技能**——即 `<dshHome>/skills` 这个发现根被实证（不是仅凭包内 README 推断）。
* 当前会话自身的实时证据：`~/.dsh/AGENTS.md` 已作为 **user-global 基线注入本会话**（system-reminder 显示 `Instructions from: ~/.dsh/AGENTS.md`），且两个技能都出现在可用技能目录里。**部署面已生效**，这比"文件躺在那里"强一档。
* **未做**：没有跑过 9P/9A/9B；没有在真实 Critical 任务里端到端跑过这套 DSH 流程；没有用 `subagent` 实际派过一次 Reviewer（因此 `provider`/`model`/`reasoning_effort` 三个参数与 `allowedModels` 白名单的**组合**尚未实证，只核过各自的存在与取值域）。**这三项都属于未验证声称之外**——不要把本文件当作"已验证可用"的证据。
