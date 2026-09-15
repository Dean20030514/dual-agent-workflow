# DSH landing notes（`dsh/` 的派生记录）

> 本文件是 **DSH 工作流落地的改点清单与状态登记**，不是规则出处。规则判据唯一出处 = `dsh/workflow/AGENTS.md`（DSH 会话）。
> 状态：**已跑过一轮独立双审（9A/9B，均"不通过"），修复后待第 2 轮再审**；已**人工部署**到本机 `~/.dsh/`（`AGENTS.md`、`workflow/`、`skills/{dual-agent-workflow,independent-review}`），部署为 `install.ps1` 受管面的**手写等价物**（脚本本身受迁移期 guard 锁定，未运行）。详见文末「未偿还的债」。
> **本文件的改点清单本身是审查对象**：首轮 9A 的 B2 判定 §2 的"只有这些"声称不成立（≥11 个实际变更未登记）；本节已按该裁决补出 §2.1。

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

# 3) 有界人工改点（§2 与 §2.1 逐条列表，改动本身可 diff 复核）

# 4) 派生后必跑的复核（首轮审查要求的最小门禁；无此步 §2 的声称只能靠人肉）
git diff --no-index --numstat claude/<对应文件> dsh/<对应文件>   # 逐对，只打印变更行
#   把每一条变更行与 §2/§2.1 对齐：出现清单里没有的变更行 = 改点登记仍不完整
```

phase 文件额外做了三处归一：加 `name: phase-<原命令名>`（**防御性写法**——嵌套 resources 本就不会被 skill 发现，见 `dsh-skill-filesystem` README 的"`**/SKILL.md` 故意不发现"；加 `name` 是为防止将来有人把它们挪到根层时被误当技能）、加 `disable-model-invocation: true`（同因）、补回文件末尾换行（复制工序曾丢，首轮 9B 的 S3）。

## 2. 有界改点清单（`dsh/` 对 `claude/` 母本的**文本改点**）

> **范围声明（首轮 9A 的 B2 修正）**：本节只列**派生文件内部的文本改点**。**新增文件**（没有母本对应物）与**仓级/运维文件**见 §2.1——两者合起来才构成"全部实际变更"。

| # | 位置 | 改点 | 理由 |
|---|---|---|---|
| 1 | `AGENTS.md` → Mode Scope | 路由指向 `dsh/AGENTS.md`；加"DHS 侧母本"定位句与冲突裁决 | 两套落地需要各自唯一的判据出处 |
| 2 | `AGENTS.md` → Reviewer-Lightweight Protocol | 背景节加 DSH 迁移注：**Codex 沙箱（EPERM）兜底在 DSH 消失**——Reviewer 同机同权限、写得到仓库 | 这是 DSH 落地**唯一**的实质性放松风险点，必须显式写明 |
| 3 | `AGENTS.md` → AI Collaboration Rules | 零写入的落地形态改为"verdict = agent 返回正文，Author 落盘"；headless 侧改为 stdout/stderr 重定向（**`-o` 是 Codex 参数，DSH 没有**） | `subagent`/headless 都没有 `-o`；Reviewer 落盘即破坏零写入。**首轮 9A B4**：首版这里留了"由 Author 启动的 `-o`"，与同文件后文自相矛盾，已修 |
| 4 | `AGENTS.md` → 证据 vs 假设 | 加"模型与推理档断言以 `list_subagent_models` / 适配器目录为准" | 型号换代频繁（`deepseek-flash` = V4.1-Flash），禁止凭记忆 |
| 5 | `AGENTS.md` → 新增 `## DSH Runner` | 主路径（`subagent`）/ 备用路径（headless）/ 两条都不许做的事 | 原母本没有这一节（Codex 时代只有一个调用面） |
| 6 | `AGENTS.md` → Reviewer verdict 分类语义 | "兼容 Codex 强制结构" → "本工作流自己的契约" | 顶层字段契约不再受制于 Codex 的结构要求 |
| 7 | `reviewer-prompt.md` | 全文 DSH 化：调用形态 ③ 换成 `subagent` + headless 两个模板与参数；④ 的 holding 落盘改为 Author 执行；新增 `writes_performed` 与 `model_route` 必填字段；新增 `## Author 侧：发 9A/9B 前置检查` 清单；9P 改为 `reasoning_effort: high` 并重写降档来历节；**把两处 `docs/ai/QUALITY_GATES.md` 指针改回项目副本** | 只改"怎么跑"，判据/字段/阈值不动。**首轮 B1/B3/9B-B3**：首版把 9P 写成 `medium`（适配器无此档）、把 Reviewer 的质量清单输入误改成母本路径（机械替换误伤）、缺档位自报字段 |
| 8 | `QUALITY_GATES.md` | 组织与角色分配节：删掉 Claude 侧专家 agent 的历史叙述，改为 DSH 现实（只有 `subagent`/`subagent_fork`/`workflow`）+ 派发上限指引，**并把母本"派 sub-agent 时要求继承主对话模型不降级"整句替换为"子 agent 一律显式钉住 `provider`/`model`"** | 该节原内容是关于已卸载插件的本机事实，在 DSH 下已失效；DSH 没有"继承即不降级"这条（首轮 9A 的 S5 要求把这个替换写清） |
| 9 | `index.md` | 角色行、命令对照表、Reviewer prompt 行、模式路由指针改为 DSH 形态 | 导航必须指向真实存在的文件 |
| 10 | `debug.md` / `final-review.md` / `plan.md` / `implement.md` / `design-check.md` / `define.md` / `explore.md` | "继承主对话模型"的判据改为"fresh 上下文"（`subagent` 天然 fresh）；`Reviewer（Codex）` → `Reviewer（DSH subagent / headless）`；加 `exit_plan_mode ≠ Critical 批准门`；`Ready for Review` 改为"可投给 DSH Reviewer 的两份 prompt"+ 调用参数（含 `writes_performed` 证据行；`model_route` 只出现在 `reviewer-prompt.md` 契约与 `independent-review` 手册，不在 phase 正文） | 这几个是 DSH 特有的认知陷阱 |
| 11 | `workflow-design-notes.md` | 一行路径指针：`.claude/commands/design-check.md` → `~/.dsh/skills/.../phases/design-check.md` | 路径随命令面迁移 |
| 12 | 新增 `fanout-toolchain.md` | DSH 工具面事实：委派三面、参数与白名单、档位取值域、**headless 钉不住路由**、派发上限、失败语义（含 `model_route` 不符的处置） | 母本没有对应物；把"事实"与"判据"分开，升级包后只需核对这一份 |

**没有改的**：Safety Rules、`[DEBT]` 格式、Payback-on-Touch、验证三分类、守护有效性装置（含四条失败判据与负向对照）、验收可复现判定、review-sensitive paths + SHA 绑定、Fix-Loop 计数/硬停/轮次上限/三者优先级、最后一轮独立审查门、Git Discipline、单轮 diff 预算、停止事件优先级、输出契约的七个顶层字段、9A/9B/9P 的检查重点与 9P 的单轮规则。**这些判据与阈值一字未改。**

## 2.1 清单外的其余变更（新增文件与仓级/运维文件）

> 这些**没有母本对应物**（"新增"）或**不属于 `dsh/` 派生面**（"仓级"），因此不适用"与母本逐字一致"的判据；但它们同样是本任务的变更，任何"改了什么"的完整性复核都必须覆盖它们（首轮 9A 的 B2）。

| # | 路径 | 性质 | 内容 |
|---|---|---|---|
| 13 | `dsh/AGENTS.md` | **新增**（改写自 `claude/CLAUDE.md` 的思路，非逐字派生） | DSH 每会话必载的全局入口：Mode Routing / Roles / Workflow / Decision Making / Safety / Communication / Environment / Git / Code·Testing·Dependencies / Security / File·Config Safety / Documentation / Tooling / Configuration Hierarchy |
| 14 | `dsh/skills/dual-agent-workflow/SKILL.md` | **新增** | 路由技能（阶段表、产物、风险点、脚手架步骤） |
| 15 | `dsh/skills/independent-review/SKILL.md` | **新增** | 审查执行手册（开审清单、调用形态、收回后 5 项核验、异常处置） |
| 16 | `dsh/skills/dual-agent-workflow/references/conflict-hard-stop.md` | **新增**（母本判据的执行手册，**非逐字复制**） | 停止优先级 / verdict 分类 / Fix-Loop / 收敛门 / 债与偿还 / 验收与守护声称 / 落账模板 |
| 17 | `dsh/skills/dual-agent-workflow/references/verification-evidence.md` | **新增**（同上） | 证据先于断言 / 验证三分类 / 守护有效性装置 / diff 预算 / 派发上限 / `last_test_run.txt` 写法 |
| 18 | `portable/通用prompt-DSH-v1.txt` | **新增** | DSH 便携单文件版（与 `通用prompt-v3.8.txt` 同族并列） |
| 19 | `install.ps1` | **仓级修改** | 新增 DSH 部署段（镜像 `AGENTS.md` / `workflow/` / 本工作流自有两个 skill bundle；整树备份带副作用警告；不触碰机器态） |
| 20 | `README.md` | **仓级修改** | 标题、文首权威段落、锁定说明、布局表 3 行、核心机制 2 条、快照状态节的 DSH 迁移状态 |
| 21 | `AGENTS.md`（仓库根） | **仓级修改** | 新增"两套落地,一套纪律"段；Project Overview 补 `~/.dsh/` |
| 22 | `docs/ai/AUTHORITY_CONTRACT.md` | **仓级修改** | 增补：DSH 部署面进入受管面、机器态例外、seed-only 例外仍只有 `~/.config.toml` 一项、尚未实跑 |
| 23 | `docs/ai/DSH-LANDING-NOTES.md` | **新增** | 本文件 |

**手册 16/17 是有意精简的执行手册，不是母本副本**：其中两条曾被首轮 9B 的 S1 指出丢了母本的反滥用条件（`conflict-hard-stop.md` 的收敛门 ③(a) 少了"新 `last_test_run.txt` 收集用例总数 ≥ 快照那次"；§1 的 Blocking 判据少了"Reviewer 须写出该测试仍能检出的具体缺陷或可达路径，写不出的记 Non-Blocking Suggestion"）——**已在第 3 轮逐字补回**（2026-09-06；第 2 轮我在此处误写了"已补回"，实际两份手册的 blob 在第 2 轮未变——第 2 轮 9A 的 S1 抓到了这个假声称）。设计原则：**手册可以省略解释性文字，但不得省略任何判据、阈值或反滥用条件**；与母本冲突时以母本为准。

## 3. 未偿还的债（登记，不藏）

```
[DEBT] dsh/ 全套与 portable/通用prompt-DSH-v1.txt 尚余第 2 轮审查未跑（首轮已跑、未收敛） | Payback trigger: 下一次改动 dsh/** 的那一轮必须带独立审查（本任务内即第 2 轮） | Impact: 未审的判据副本可能含语义漂移，却被当作权威执行（且它已是本机生效的运行副本）
[DEBT] dsh/workflow/fanout-toolchain.md 的 DSH 事实绑定 @deepseek-ai/dsh 0.1.5-rc.x | Payback trigger: 下次改动 dsh/workflow/fanout-toolchain.md 之前，或 @deepseek-ai/dsh 升级后首次派发审查之前 | Impact: 参数/工具名变化会让调用范式静默失效
[DEBT] ~/.dsh 的运行副本由人工复制产生，`.dsh.bak-*` 不存在 | Payback trigger: 首次用 install.ps1（或任何镜像脚本）覆盖 ~/.dsh 之前 | Impact: 首次自动部署没有上一版可回退
[DEBT] install.ps1 的 DSH 段会把整个 ~/.dsh（含 sessions/storages/.credentials.yaml）整树备份为 ~/.dsh.bak-<stamp>，与 README「凭据从不触碰」的措辞不一致 | Payback trigger: 下次改动 install.ps1 的 DSH 段之前 | Impact: 凭据被复制到备份目录且从不自动清理，人类核验"凭据未被触碰"时会得出错误结论（已在代码注释与本节写明副作用）
```

四笔登记在本文件；`README.md` 快照节记录其存在与指针（首轮 9B 的 S8 指出了第 2 笔在 README 里查不到——已收窄措辞为"存在与指针"）。**没有第三种状态**：要么跑一轮审查转成已审版本，要么人类明确批准延期。

## 4. 部署（本轮已人工执行）

`install.ps1` 已加入 DSH 部署段（`~/.dsh/AGENTS.md`、`~/.dsh/workflow/` 镜像；`~/.dsh/skills/{dual-agent-workflow,independent-review}/` 镜像；其余 `~/.dsh/skills` 内容不动；`~/.dsh` 整树先备份一次并带副作用警告）。**但脚本受迁移期 guard 锁定，本轮没有运行它**（AGENTS.md 明令：受迁移期 installer guard 锁定，勿直接运行）。因此本轮改走人工等价部署：

```
dsh/AGENTS.md                                   → ~/.dsh/AGENTS.md
dsh/workflow/**                                 → ~/.dsh/workflow/**
dsh/skills/{dual-agent-workflow,independent-review}/** → ~/.dsh/skills/ 同名目录
（未触碰：settings.yaml、sessions/、storages/、.credentials.yaml、profiles/、以及 ~/.dsh/skills 下其它内容）
```

**两处与将来 `install.ps1` 部署的差异，升级时要补**：① 本轮没有产生 `*.bak-<时间戳>`（脚本会先备份 `~/.dsh` 与每个目标）；② 本轮复制后，若仓内 `dsh/**` 再有改动，`~/.dsh` 副本不会自动跟随——**改仓为唯一真相，改完手动同步，或等 H3 解锁脚本**。这条差异已登记为 `[DEBT]`（见上）。

## 5. 验证记录（**Author 自报，未构成独立证据**）

* 逐对 diff 审计：17 对派生文件的变更行数与 §2/§2.1 对齐（命令见 §1 第 4 步；输出见 `docs/ai/last_test_run.txt`）。**首轮 9A 的 B2 就是这么被发现的**（`dsh/workflow/AGENTS.md` 25 增 15 删，而登记表只覆盖 12 处）。
* `docs/ai/QUALITY_GATES.md` 指针：**母本 3 处、DSH 版 3 处项目副本 + 2 处母本兜底**（首轮曾被机械替换成 1 处项目副本 + 2 处母本，已修回并与母本处数一致）。
* 档位取值：`Select-String <dsh-llm-deepseek/lib/index.js> -Pattern '"medium"'` **零命中**；适配器 `reasoningEffort()` 只放行 `off/low/high/max`。`dsh/**` 与 portable 里剩余的 `medium` 字样**全部是解释性引用**（说明"该档不存在"或"母本为何这么写"），没有任何一处把它当作可用取值（首轮 B1 的独立复现）。
* skill 结构：两个 `SKILL.md` 的 frontmatter 含 `name`（kebab-case、与目录名一致）/`description`；7 个 phase 文件带 `disable-model-invocation: true` 且末尾换行已补。
* 工具面事实来源（一手）：`@deepseek-ai/dsh-agent-presets/presets/standard/agent.cordis.yml`、`@deepseek-ai/dsh-tool-subagent/README.md`、`@deepseek-ai/dsh-llm-deepseek/lib/index.js`、`@deepseek-ai/dsh-headless/lib/startup.js`（helpOption/argument）、`@deepseek-ai/dsh-skill-filesystem/README.md`；模型档位佐证 = [DeepSeek 官方公告 2026-09-10](https://api-docs.deepseek.com/zh-cn/news/news260910/)（V4.1-Flash 超过 V4 Pro；旧 id 下线或路由到它）。
* 首轮独立双审（真实发生）：9A/9B 均"不通过"，4+3 条 Product Blocking，隔离协议五项核验两份全过。verdict 落 `docs/ai/review_9A.md` / `review_9B.md`。
* **未做/未验证（不得当作通过）**：① 第 2 轮审查尚未跑；② 未实跑 `install.ps1`（guard 锁定）；③ 未实跑 headless 的完整审查轮；④ `model_route` 字段未经真实审查轮验证；⑤ 未在真实 Critical 项目任务上端到端跑过这套 DSH 流程。
