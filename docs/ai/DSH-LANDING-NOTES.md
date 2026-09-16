# DSH landing notes（`dsh/` 的派生记录）

> 本文件是 **DSH 工作流落地的改点清单与状态登记**，不是规则出处。规则判据唯一出处 = `dsh/workflow/AGENTS.md`（DSH 会话）。
> 状态：**已跑 3 轮独立双审**（第 1 轮均"不通过"；第 2 轮均"有条件通过"；第 3 轮 9B"不通过"、9A"有条件通过"→ **归类分歧经人类裁决采纳 9B**，现为第 4 轮修补后待审）。已**人工部署**到本机 `~/.dsh/`（`AGENTS.md`、`workflow/`、`skills/{dual-agent-workflow,independent-review}`），部署为 `install.ps1` 受管面的**手写等价物**（脚本本身受迁移期 guard 锁定，未运行）。详见文末「未偿还的债」。
> **本文件的改点清单本身是审查对象**（且它自己就是最脆的一环——三轮里每轮的主要 finding 都出在这一层）：首轮 9A 的 B2 判定 §2 的"只有这些"声称不成立（≥11 个实际变更未登记）→ 补出 §2.1；第 3 轮 9B 的 B1 判定 AC6 按字面恒红（`<base>` 未钉死 + 声明表缺机械复制面）→ 补出 §2.2 **与 §2.3 机读登记表**，并把 AC6 的判定谓词改为**直接读 §2.3**（旧谓词"文件名是否出现在本文档里"经实测**无区分力**）。

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

phase 文件额外做了三处归一（**`explore.md` 只有前两处；`define.md` / `design-check.md` 另含路径改写**）：加 `name: phase-<原命令名>`（**防御性写法**——嵌套 resources 本就不会被 skill 发现，见 `dsh-skill-filesystem` README 的"`**/SKILL.md` 故意不发现"；加 `name` 是为防止将来有人把它们挪到根层时被误当技能）、加 `disable-model-invocation: true`（同因）、补回文件末尾换行（复制工序曾丢，首轮 9B 的 S3）。

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
| 10 | `debug.md` / `final-review.md` / `plan.md` / `implement.md` / `design-check.md` / `define.md` / `explore.md`（**`explore.md` = 2 增 0 删**，只有 frontmatter 两行 `name:` / `disable-model-invocation:`，**无末尾换行变更**；`define.md` = 4 增 2 删、`design-check.md` = 3 增 1 删，二者另含 `~/.claude` → `~/.dsh` 的路径改写，属 §1 第 2 步的机械改写面。**2026-09-06 第 3/4 轮两次订正**：本括注先后写过"只改了末尾换行"与"三处归一化"，均与 `--numstat` 实测不符） | "继承主对话模型"的判据改为"fresh 上下文"（`subagent` 天然 fresh）；`Reviewer（Codex）` → `Reviewer（DSH subagent / headless）`；加 `exit_plan_mode ≠ Critical 批准门`；`Ready for Review` 改为"可投给 DSH Reviewer 的两份 prompt"+ 调用参数（含 `writes_performed` 证据行；`model_route` 只出现在 `reviewer-prompt.md` 契约与 `independent-review` 手册，不在 phase 正文） | 这几个是 DSH 特有的认知陷阱 |
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
| 18 | `portable/通用prompt-DSH-v1.txt` | **新增** | DSH 便携单文件版（与 `通用prompt-v3.8.txt` 同族并列）。**登记成路径而非文件名**（`DSH-LANDING-NOTES.md` / AC6 的谓词按文件名匹配，故此处须同时给出文件名 `通用prompt-DSH-v1.txt`） |
| 19 | `install.ps1` | **仓级修改** | 新增 DSH 部署段（镜像 `AGENTS.md` / `workflow/` / 本工作流自有两个 skill bundle；整树备份带副作用警告；不触碰机器态） |
| 20 | `README.md` | **仓级修改** | 标题、文首权威段落、锁定说明、布局表 3 行、核心机制 2 条、快照状态节的 DSH 迁移状态 |
| 21 | `AGENTS.md`（仓库根） | **仓级修改** | 新增"两套落地,一套纪律"段；Project Overview 补 `~/.dsh/` |
| 22 | `docs/ai/AUTHORITY_CONTRACT.md` | **仓级修改** | 增补：DSH 部署面进入受管面、机器态例外、seed-only 例外仍只有 `~/.config.toml` 一项、尚未实跑 |
| 23 | `docs/ai/DSH-LANDING-NOTES.md` | **新增** | 本文件（改点登记与债台账） |
| 24 | `docs/ai/TASK_BRIEF.md` | **新增** | 本任务的需求与验收基线（**事后补写**，含两条 Amendment 与人类裁决记录）；它是**交付面**成员，故在 AC6 的判定范围内 |
| 25 | `tools/ac4-reasoning-effort-check.ps1` | **新增** | **AC4-门本身的实现**（枚举 DSH 面 `reasoning_effort` 赋值位 + 适配器 `"medium"` 零命中）。**2026-09-06 第 6 轮补登**：第 5 轮它被新增时既不在 AC6 的 scope、也不在本表内 → "门绿而登记不全"（第 5 轮 9A 的 B-1）。现已在 scope 内。 |

**手册 16/17 是有意精简的执行手册，不是母本副本**：其中两条曾被首轮 9B 的 S1 指出丢了母本的反滥用条件（`conflict-hard-stop.md` 的收敛门 ③(a) 少了"新 `last_test_run.txt` 收集用例总数 ≥ 快照那次"；§1 的 Blocking 判据少了"Reviewer 须写出该测试仍能检出的具体缺陷或可达路径，写不出的记 Non-Blocking Suggestion"）——**已在第 3 轮逐字补回**（2026-09-06；第 2 轮我在此处误写"已补回"而实际未改，第 2 轮 9A 的 S1 用 blob 哈希抓到了这个假声称）。设计原则：**手册可以省略解释性文字，但不得省略任何判据、阈值或反滥用条件**；与母本冲突时以母本为准。

## 2.2 派生后逐字节未改的文件（机械复制面）

> **为什么单列一节**：这些文件在派生时**逐字节复制、无任何文本改点**，因此**不出现在任何 diff 的产出里**——既不在 §2（那里列"文本改点"），也不在 §2.1（那里列"新增/改写文件"）。但它们是交付面的一部分，AC6 的判定要覆盖它们，就必须有人把它们**声明出来**；本节即该声明，`git diff --no-index --numstat` 全 0 是它的机械证据。
> **AC6 现在只引用 §2.3**（本节是它的散文说明与理由，不再是判定的读取对象）——故本节改编号**不再**改验收基线；**§2.3 的编号与 `- path:` 行形态才是被 AC6 直接引用的部分**。

| 文件 | 机械证据 |
|---|---|
| `dsh/workflow/AB-model-diagnostic.md` | 与 `claude/workflow/AB-model-diagnostic.md` 逐字节相同（`--numstat` 空输出） |
| `dsh/workflow/templates/HANDOFF.md` | 与 `claude/workflow/templates/HANDOFF.md` 逐字节相同 |
| `dsh/workflow/templates/IMPLEMENTATION_PLAN.md` | 与 `claude/workflow/templates/IMPLEMENTATION_PLAN.md` 逐字节相同 |
| `dsh/workflow/templates/PRODUCT_BRIEF.md` | 与 `claude/workflow/templates/PRODUCT_BRIEF.md` 逐字节相同 |
| `dsh/workflow/templates/TASK_BRIEF.md` | 与 `claude/workflow/templates/TASK_BRIEF.md` 逐字节相同 |

（复核：`git diff --no-index --numstat claude/workflow/templates/HANDOFF.md dsh/workflow/templates/HANDOFF.md` → 空；其余四对同理。**将来给其中任一文件加文本改点，必须把它从本节移入 §2**，否则声明表与事实脱节。）

## 2.3 机读登记表（AC6 判定的唯一依据）

> **为什么要这一节**：前三轮 AC6 的判定一直靠"文件名是否出现在本文件里"，而那种谓词**没有区分力**——正文里任何一次提到某个名字都会让判定变绿，于是"删掉一条声明"也照样通过（第 4 轮实测：两个负向对照都绿）。**可机读的登记表**才是可判定的形态。
> **判定谓词**：AC6 的交付面 scope 里的**每一项**，都必须出现在下表的 `- path:` 行里；**双向**——表里的每一项也都必须真的在 scope 里（登记了却没改的文件 = 表与事实脱节）。
> **只允许用这一种形态**：`- path: <仓库相对路径>` 之后跟 `  disposition:` / `  entry:` 两行。不要在别处另起第二份清单——两份清单就是两个事实源。

```yaml
# canonical change register — AC6 判定据此
- path: dsh/AGENTS.md
  disposition: added
  entry: "§2.1 #13"
- path: dsh/workflow/AGENTS.md
  disposition: derived-edited
  entry: "§2 #1-#6"
- path: dsh/workflow/reviewer-prompt.md
  disposition: derived-edited
  entry: "§2 #7"
- path: dsh/workflow/QUALITY_GATES.md
  disposition: derived-edited
  entry: "§2 #8"
- path: dsh/workflow/index.md
  disposition: derived-edited
  entry: "§2 #9"
- path: dsh/workflow/workflow-design-notes.md
  disposition: derived-edited
  entry: "§2 #11"
- path: dsh/workflow/fanout-toolchain.md
  disposition: added
  entry: "§2 #12"
- path: dsh/workflow/AB-model-diagnostic.md
  disposition: verbatim-copy
  entry: "§2.2"
- path: dsh/workflow/templates/HANDOFF.md
  disposition: verbatim-copy
  entry: "§2.2"
- path: dsh/workflow/templates/IMPLEMENTATION_PLAN.md
  disposition: verbatim-copy
  entry: "§2.2"
- path: dsh/workflow/templates/PRODUCT_BRIEF.md
  disposition: verbatim-copy
  entry: "§2.2"
- path: dsh/workflow/templates/TASK_BRIEF.md
  disposition: verbatim-copy
  entry: "§2.2"
- path: dsh/skills/dual-agent-workflow/SKILL.md
  disposition: added
  entry: "§2.1 #14"
- path: dsh/skills/dual-agent-workflow/references/conflict-hard-stop.md
  disposition: added
  entry: "§2.1 #16"
- path: dsh/skills/dual-agent-workflow/references/verification-evidence.md
  disposition: added
  entry: "§2.1 #17"
- path: dsh/skills/dual-agent-workflow/references/phases/debug.md
  disposition: derived-edited
  entry: "§2 #10"
- path: dsh/skills/dual-agent-workflow/references/phases/define.md
  disposition: derived-edited
  entry: "§2 #10 + §1 路径改写"
- path: dsh/skills/dual-agent-workflow/references/phases/design-check.md
  disposition: derived-edited
  entry: "§2 #10 + §1 路径改写"
- path: dsh/skills/dual-agent-workflow/references/phases/explore.md
  disposition: derived-edited
  entry: "§2 #10（仅 §1 归一化）"
- path: dsh/skills/dual-agent-workflow/references/phases/final-review.md
  disposition: derived-edited
  entry: "§2 #10"
- path: dsh/skills/dual-agent-workflow/references/phases/implement.md
  disposition: derived-edited
  entry: "§2 #10"
- path: dsh/skills/dual-agent-workflow/references/phases/plan.md
  disposition: derived-edited
  entry: "§2 #10"
- path: dsh/skills/independent-review/SKILL.md
  disposition: added
  entry: "§2.1 #15"
- path: portable/通用prompt-DSH-v1.txt
  disposition: added
  entry: "§2.1 #18"
- path: install.ps1
  disposition: modified
  entry: "§2.1 #19"
- path: README.md
  disposition: modified
  entry: "§2.1 #20"
- path: AGENTS.md
  disposition: modified
  entry: "§2.1 #21"
- path: docs/ai/AUTHORITY_CONTRACT.md
  disposition: modified
  entry: "§2.1 #22"
- path: docs/ai/DSH-LANDING-NOTES.md
  disposition: added
  entry: "§2.1 #23"
- path: docs/ai/TASK_BRIEF.md
  disposition: added
  entry: "§2.1 #24"
- path: tools/ac4-reasoning-effort-check.ps1
  disposition: added
  entry: "§2.1 #25"
```
## 3. 债台账 —— **唯一权威副本在活的 `docs/ai/HANDOFF.md` → `Remaining Risks / Debt`（空闲期形态）**

> **2026-09-06 归档时的订正（本节第三次改口径，前两次都是"两份台账互相矛盾"引起的）**：本任务的 per-task 文件（`HANDOFF.md` / `TASK_BRIEF.md` / `last_test_run.txt` / `review_9{A,B}*.md`）已归档到 `docs/ai/archive/2026-09-06-dsh-landing/`，而**未偿债不能随任务消失**——故 8 笔 `[DEBT]` 与 6 项 `[U]` 已**原样承接**进**活的 `docs/ai/HANDOFF.md`（空闲期形态：`Current Phase: Idle`，其余节写 N/A）**，它是**唯一权威活台账**。本节**只保留导读**，不再复制条目文本；改债必须改 `HANDOFF.md`。
> **核验命令**（**不写死笔数**——第 7 轮 9B 的 PB-1 就是"写死数字随加账过期"）：`(Select-String -Path docs/ai/HANDOFF.md -Pattern '^\[DEBT\]').Count`

**导读（**曾在此处列 8 条，其中两条已随处置过期**——此处不静默删除，改为点明)**：原导读第 1 条（"`dsh/` 全套 + portable 的阶段性 delta 待审"）已随"不再开新审查轮"的裁决与归档失效；第 6 条（"AC4-门只覆盖未加引号小写形态"）已随人类选择 **2a** 加宽而失效；第 8 条原写的机制（"换 checkout 会在 `Set-Location` 处直接终止"）**经第 8 轮实测证伪**（真实失效形态是同机异 checkout **静默读错树给出假绿**），`HANDOFF.md` 内保留的是**订正后**的文本。**权威条目一律读 `HANDOFF.md`。**

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

* 逐对 diff 审计：17 对派生文件的变更行数与 §2/§2.1 对齐（命令见 §1 第 4 步；输出见归档副本 `docs/ai/archive/2026-09-06-dsh-landing/last_test_run.txt`）。**首轮 9A 的 B2 就是这么被发现的**（`dsh/workflow/AGENTS.md` 25 增 15 删，而登记表只覆盖 12 处）。
* `docs/ai/QUALITY_GATES.md` 指针：**母本 3 处、DSH 版 3 处项目副本 + 2 处母本兜底**（首轮曾被机械替换成 1 处项目副本 + 2 处母本，已修回并与母本处数一致）。
* 档位取值：`Select-String <dsh-llm-deepseek/lib/index.js> -Pattern '"medium"'` **零命中**；适配器 `reasoningEffort()` 只放行 `off/low/high/max`。`dsh/**` 与 portable 里剩余的 `medium` 字样**全部是解释性引用**（说明"该档不存在"或"母本为何这么写"），没有任何一处把它当作可用取值（首轮 B1 的独立复现）。
* skill 结构：两个 `SKILL.md` 的 frontmatter 含 `name`（kebab-case、与目录名一致）/`description`；7 个 phase 文件带 `disable-model-invocation: true` 且末尾换行已补。
* 工具面事实来源（一手）：`@deepseek-ai/dsh-agent-presets/presets/standard/agent.cordis.yml`、`@deepseek-ai/dsh-tool-subagent/README.md`、`@deepseek-ai/dsh-llm-deepseek/lib/index.js`、`@deepseek-ai/dsh-headless/lib/startup.js`（helpOption/argument）、`@deepseek-ai/dsh-skill-filesystem/README.md`；模型档位佐证 = [DeepSeek 官方公告 2026-09-10](https://api-docs.deepseek.com/zh-cn/news/news260910/)（V4.1-Flash 超过 V4 Pro；旧 id 下线或路由到它）。
* 首轮独立双审（真实发生）：9A/9B 均"不通过"，4+3 条 Product Blocking，隔离协议五项核验两份全过。**6 轮 verdict 均已随任务归档**：`docs/ai/archive/2026-09-06-dsh-landing/review_9A.md` / `review_9B.md`（第 1 轮）与同目录的 `_r2` / `_r3` / `_r4` / `_r6`；轮次账见同目录 `HANDOFF.md`。**活树不再保留 `docs/ai/review_9*.md`**——那是每一轮任务自己落账的位置（见 `dsh/skills/independent-review/SKILL.md` 的收件规则）。
* **未做/未验证（不得当作通过）** —— **本清单的活台账是 `docs/ai/HANDOFF.md` → Known Issues 的未验证清单**（由已归档的 `TASK_BRIEF.md` → AC11 **原样承接**，归档副本在 `docs/ai/archive/2026-09-06-dsh-landing/TASK_BRIEF.md`）；**两处必须逐条一致，改一处必须同改另一处**。注意：这条"逐条一致"说的是"未验证清单"，不是 `[DEBT]` 集合：
  1. 除 `AGENTS.md` 外的其余派生对（`reviewer-prompt.md` / `QUALITY_GATES.md` / `index.md` / `workflow-design-notes.md` / 7 个 phase）相对母本是否存在判据漂移 —— 触发：下一次改动任一该文件之前。
  2. 备用路径（headless）完整审查轮 —— 触发：首次用备用路径发审之前。
  3. ~~真实 9P 审查轮（两次都只是档位探针）—— 触发：下一次启用 Critical 之前。~~ **已履行（2026-09-15）**：切片 B 规划期跑了 round 1/2/3 三轮真实 9P（verdict 全文见 `docs/ai/archive/2026-09-15-h3b-mirror-replace-superseded/review_9P.md`）；`HANDOFF.md` 承接清单同条已同改。
  4. `~/.dsh/settings.yaml` 的 `reasoningEffort` 是否真被适配器读取 —— 触发：首次依赖 settings 层钉档位之前。
  5. AC8 的机器态实跑（临时 HOME / 一次性 profile 下跑安装器 + 三项哈希）—— 触发：`install.ps1` 解锁后首次运行。 **已履行（2026-09-15）**：写入路径落地后，隔离 home 的机器态实跑由 `tests/install.Deploy.Tests.ps1` 承担（机器态哈希/备份缺席断言），并另对**真实树**跑过一次 `-DryRun` + 一次真部署（零写入）；记录见 `docs/ai/REAL_DEPLOY_LOG.txt`。
  6. `install.ps1` 的其余注释逐句对读（AC7 只核了备份/镜像语义那一组）—— 触发：下次改动该文件之前。

## 6. DSH 侧相对母本的**有意判据分歧**登记（2026-09-16 新增）

> **为什么单独一节**：仓库契约为「两套落地，一套纪律——判据与阈值一致，只允许『怎么跑』不同」。本节登记**故意不一致**的条目，每条必须写明机制为什么只在一侧成立。**本节为空 = 两侧判据一致**；不为空时，它就是那份差额的唯一定义处。
> **机械门**：`tools/dsh-drift-check.ps1` 把两侧 17 对派生文件的全部差异行冻结进 `tools/dsh-drift-baseline.txt`；任何新增 / 改动 / 消失的差异行都判红。**用 `-Update` 重生成基线即等于声明一条分歧**——同一个 commit 必须在本节登记它。

| # | 位置（DSH 侧） | 分歧内容 | 为什么只在一侧成立 |
|---|---|---|---|
| **D1** | `workflow/AGENTS.md` → Reviewer-Lightweight Protocol 第一层（新 bullet）；`workflow/reviewer-prompt.md` → ③(c) 红线 + 9A / 9B / 9P 三处 prompt 的「具名禁区」；`AGENTS.md` → File & Config Safety | **具名禁止 Reviewer 执行 `install.ps1` 的任何形态**，并点明唯一安全路径（隔离临时 HOME 的 `tests/` 套件） | **机制是 DSH 特有的**：Codex 进程沙箱是零写入的物理兜底，DSH 没有（Reviewer 同机同权限）；事故也发生在 DSH 侧——2026-09-15 同型两次（9P Reviewer 删掉 `~/.claude/` 下 127 个本机独有文件、该轮 verdict 作废；Author 一次）。Claude 侧母本保留「不跑任何会改文件的命令」的泛化表述。**若将来 Codex 侧也失去沙箱兜底，本条应升为两侧共有。** |

**以下两条不属于分歧**（两侧已同改，故不登记；它们的证据都是跨模型的——2026-08-15 三病诊断早于 DSH 落地）：`workflow/AGENTS.md` → Fix-Loop 的「早期停牌探针」；全局 Mode Routing 的「建议而不自我降级」。

## 7. 分类契约的可复现性测量（2026-09-16；**未据此改动任何判据**）

> 只作证据登记：它指出「Product / Verification Needed / Suggestion」三分类在**边界项**上不可复现，但是否收窄契约由人类决定——**本轮没有改判据**。

**设计（预注册）**：7 条冻结 finding（4 条历史争议项 I1–I4 + 3 条对照 I5–I7）× **5 个互不可见的 fresh-context Reviewer**（`deepseek-official` / `deepseek-flash` / `reasoning_effort: high`，与 9A 实发参数一致）；提示词逐字节相同；禁止读仓库与归档；只输出类别名。
**预注册判据**：对照项须 ≥4/5 一致（否则仪器本身无效，不对契约下结论）；任一争议项出现 ≥2 个类别 → 契约在该项上欠定。

| 项 | 5 次判定 | 历史判定 |
|---|---|---|
| I1（AC6 判定方式恒红、`<base>` 未钉死、谓词无区分力） | Suggestion×4, VN×1 → **0/5 Product** | 9B=Product，9A=Suggestion |
| I2（AC4 脚本硬绑本机 checkout 路径 vs 声称「可复制执行」） | Suggestion×4, Product×1 | 9B=Product（`dispute`） |
| I3（AC4 门只覆盖声明域 20 处中的 7 处） | VN×4, Product×1 | 9A=Product（`dispute`） |
| I4（AC9 判定①恒红且从未执行） | Suggestion×4, VN×1 → **0/5 Product** | 9B=Product（`dispute`） |
| I5（`medium` 档不存在致 9P 不可执行） | **Product×5** | 两份均 Product |
| I6（「三个 `SKILL.md`」实际两个） | **Suggestion×5** | Suggestion |
| I7（headless 默认模型需实跑确认） | **VN×5** | VN |

**结果**：对照项 **15/15 一致**（仪器有效）；**4 条争议项每一条都出现 ≥2 个类别**（每次均为 4:1 分裂）；争议项 20 次判定中仅 **2 次**给出 Product。

**为什么这条重要**：dsh-landing 的 round 3 与 round 4 的**唯一** Product 项分别是 I1 与 I4——今天各得 **0/5** Product，那两轮的 streak 输入因此不可复现。round 5 触发硬停的那条（B-1）**不在本项集内**，不属本结论。

**限度（与结论同读）**：本测量给的是 finding **陈述**、未给 diff，故证明的是「同一输入 → 不同桶」，**不能单独证明历史上的 Product 判定错了**；少数派票方向不一致（I2/I3 偶跳 Product、I1/I4 从不跳），说明不是一致地读松或读严，而是**边界无确定解**。**更强的复现已执行（2026-09-16）→ 见 §7.1；它修正了本节的框架。**

### 7.1 修正：真实 diff 上的 5 次 9A 重放（2026-09-16；**判据未据此改动**）

> **为什么必须做**：§7 给的是 finding **陈述**、未给 diff，所以那里的"欠定"可能只是"没给 diff"的产物。本节用当轮真实输入重放，去掉这个混淆项。

**设计（预注册）**：5 个互不可见的 fresh-context 评审员，角色 = 9A；输入全部取自 git 对象，且**只许读 `7084fb75`（base）与 `34b60370`（tip）**；`handoff_snapshot = 34b60370`（历史隔离记录载当轮两份 `observed_head_sha` 均为 tip）；prompt 逐字节相同；`deepseek-official` / `deepseek-flash` / `high`。
**两条不可消除的偏差**：① 审前快照自检不执行（当前 HEAD ≠ 当轮 HEAD）；② HANDOFF / TASK_BRIEF / `last_test_run.txt` 从 git 对象读，而非当轮工作树（当轮那份未提交）。

**结果（5/5 有效，全部 `writes_performed: none`、仓内零写入）**

| 轮 | Review Verdict | AC6 归类 | AC6 事实 |
|---|---|---|---|
| 1 | 有条件通过 | 检出但**静默适用 ③(c) 例外**，未写进任何一节 | 手对时发现缺登记行 |
| 2 | **不通过** | `[Product Blocking]`（`caused_by_last_fix: yes`） | 10 项里 1 项零登记 |
| 3 | **不通过** | `[Product Blocking]`（`yes`） | 9 HIT / 1 MISS |
| 4 | 有条件通过 | Non-Blocking Suggestion（明写"若人类认为未满足的 AC 必须阻断合并，可直接升格"） | 9/10 HIT，唯一落空 = `TASK_BRIEF.md` |
| 5 | **不通过** | `[Product Blocking]`（`yes`） | `TASK_BRIEF` 在 NOTES 全文 0 命中 |

**结论（对 §7 的修正）**

1. **检出是可复现的**：5/5 都发现了同一个事实缺口，其中 4/5 给出的数字与我独立复跑**逐字一致**（10 项、唯一落空 = `docs/ai/TASK_BRIEF.md`）。因此 **§7 的"4:1 散开"不能外推成"评审员查不出"**——真实条件下的检出率是 5/5。
2. **不稳定的是归类**：同一输入、同一角色 → `[Product Blocking]` ×3、Non-Blocking Suggestion ×1、静默放过 ×1。机制 = 分类契约里**两个子句同时适用于该条、且没有优先级规则**：①「某条验收点**有具体反例**表明未满足 → Product」（3 轮据它判 Product）；②「判定方式写成散文对读的 → 不是验收条款、降级 Non-Blocking Suggestion；散文完整性不得作 blocking 依据」（1 轮据它判 Suggestion——**与历史 9A 同侧**）。
3. **verdict 层随之分裂**：同一 tip 上 **不通过 3 / 有条件通过 2** → 合并门与 Fix-Loop 的输入**不是确定值**。
4. **历史 9A 的读数是少数派**：4 次给出归类的重放里只有 1 次复现「AC6 = Suggestion」（= 历史 9A 的读数），3 次落在历史 **9B** 的读数上。**这与 §7 之后的推断相反，照实登记。**
5. **新发现（比归类噪声更该修）**：轮 1 的"有条件通过"来自两个**未落笔**的动作——(a) 用 `--stat` / `--name-status` **推断**"文件集合与 AC 命令相同"（实测不等：AC6 的命令不带审查排除项，会同时列出 `TASK_BRIEF.md` 与 `HANDOFF.md`，正是这个并置让缺登记显形）；(b) 把已检出的缺登记项按 ③(c) 例外**静默放过**。**verdict 看起来干净，实际对它自己已发现的缺陷零记录**——比归类分歧更难发现，因为它不留痕。（轮 1 的解释系事后追问所得，属**自述、非证据**。）
   > **可复现的一半**：账本/措辞类 finding 跨轮次稳定复现（`install.ps1:97` 残留 "added only when missing"、债笔数「三笔 vs 4 条」、README L54 与账本冲突、NOTES 状态停在旧轮），5 轮各自独立报出。

**未决（交人类，本轮未据此改任何判据）**：① 是否给分类契约补一条**优先级**（如"AC 有具体反例表明未满足时，优先于『散文判定降级』子句"）；② 是否要求"**适用例外必须落笔**"（否则该类静默放过无痕）。

**方法论教训（建议进协议）**：本次**第一版重放已作废**——我把 `handoff_snapshot` 错取为 tip 的**后裔** `40c61bb`，而该 commit 的 HANDOFF 逐字含两份历史 verdict 与 Author 的倾向，**等于把答案发给了盲审**。抓住它的是评审员自己（跑 `git merge-base --is-ancestor` 判定"快照是 tip 的后裔、按定义不可能是审前交接"）。
**根因是我主动豁免了「审前快照自检」**（理由是"重放必然偏差"），而 `observed_head_sha == handoff_snapshot_sha` 正是唯一能拦住这个错误的检查。**结论：⑤ 不是仪式，它是输入完整性检查**——重放/复现场景尤其不能豁免。
