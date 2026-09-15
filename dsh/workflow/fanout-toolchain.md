# DSH 派发与审查调用 · 工具面事实（唯一出处）

> 本文件只记录**DSH 侧"怎么跑"的机器事实**：可用的委派工具、调用参数、隔离程度、派发上限、失败语义。
> **规则判据不在这里**——Reviewer 轻量协议、零写入、双审隔离、Fix-Loop、SHA 绑定一律以 `AGENTS.md`（唯一定义处）与 `reviewer-prompt.md` 为准，本文件只解释它们在 DSH 里落到哪个工具调用上。
> 事实来源：本机 `@deepseek-ai/dsh` 0.1.5-rc.x 的包内 README/`lib`（`dsh-tool-subagent`、`dsh-agent-presets/presets/standard`、`dsh-llm-deepseek`）与一次 `dsh --profile headless` 冒烟。**包升级后需重新核对**（对应「证据 vs 假设标签」：本文件每条都应能指回包内文件，指不回的就是待核）。

## 1. 可用的委派面（DSH 只有这三个）

| 工具 | 上下文 | 能指定模型路由 | 适合什么 |
|---|---|---|---|
| `subagent` | **fresh**——子 agent 看不到本会话历史 | **是**（`provider` / `model` / `reasoning_effort`） | 独立审查（9A/9B/9P）、独立研究、独立复现 |
| `subagent_fork` | **继承本会话已完成的轮次** | 否（固定继承父路由，为了 KV Cache 复用） | 续写、复审自己刚做的事（**不能用于独立审查**） |
| `workflow` | 每个 stage 都是 fresh 子 agent | 是（每个 `agent()` 可单独指定） | 批量编排（多文件审计、扇出验证） |

* 三者都受**深度上限**约束（`maxDepth` 默认 3，`0` 禁止再委派）。
* **`subagent_fork` 不能当 Reviewer**：它带着 Author 的上下文与结论进场，"独立判断"从根上不成立。
* **每个 `subagent` / `workflow` 子 agent 都是一个完整 DSH agent**：有文件工具、shell、网络。它们**技术上写得到仓库**——零写入是纪律，不是沙箱（见 `AGENTS.md` → Reviewer-Lightweight Protocol 的 DSH 注）。

## 2. 审查调用范式（Reviewer = `subagent`）

```
subagent(
  description: "9B blind review",           # 显示用，3-5 词
  run_in_background: false,                 # 审查要等结果：前台
  provider: "deepseek-official",
  model: "deepseek-flash",
  reasoning_effort: "high",                 # 9A/9B 与 9P 都是 high（无 medium 档）
  prompt: <reviewer-prompt.md 中对应的一节，变量逐字填好>
)
```

* **必须显式给 `provider` + `model`**：不带这两项时子 agent 继承父路由的档位——**注意本落地 Author 与 Reviewer 本来就是同一个模型**，所以这条的目的不是"换模型视角"，而是**钉住档位、防止部署默认漂移**（部署的 `agentDefaultModel` 若被改，显式给参数的那一轮不受影响），并使每轮审查的档位可复现、可与 verdict 里的 `model_route` 自报值比对。两者都要落在宿主 `subagent-model-selection.allowedModels` 白名单内，否则调用被拒。
* **`reasoning_effort` 取值**（唯一定义处 = `reviewer-prompt.md` → 双审隔离协议 ③）：**三类审查统一 `high`**（9A / 9B / 9P）。DeepSeek 适配器接受的取值只有 `off` / `low` / `high` / `max`（`dsh-llm-deepseek` 的 `reasoningEffort()` 是**硬校验**）——**没有 `medium`**，写它会抛 `UNSUPPORTED_REASONING_EFFORT`；母本"9P 比实现审低一档"在 DSH 上不可表达，故不降档（2026-09-06 人类裁决）。不写则落部署默认（本机 = 父会话档）。
* **模型档位（2026-09-06，一手来源已补）**：`deepseek-flash` = DeepSeek-V4.1-Flash（**当前最强档**）。**旧 id 的状态请勿只凭本机目录判断**：本机 `list_subagent_models` 与 `dsh-llm-deepseek` 的 `DEFAULT_MODELS` 仍把 `deepseek-v4-pro` 列为一个独立模型并给出"更强"的描述，那是**适配器目录里的 legacy 条目**，不反映 API 侧现状。据 [DeepSeek 官方公告（2026-09-10）](https://api-docs.deepseek.com/zh-cn/news/news260910/)：V4.1-Flash 在基准上超过 V4 Pro；`deepseek-v4-flash` / `deepseek-v4-flash-vision-exp` 已下线；**2026-09-14 12:00 起 `deepseek-v4-pro` 的请求全部路由到 V4.1 Flash 并按 V4.1 Flash 计费**。所以 Author 与 Reviewer 都取 `deepseek-flash` 不是"降级"，而是取同一个最强模型、靠**独立上下文**而非不同模型取得独立性。改档前先跑 `list_subagent_models` 核实实时目录。
* **准入**：`subagent` 的模型选择受宿主设置 `subagent-model-selection.allowedModels` 白名单约束（本机 `~/.dsh/settings.yaml`）；选了白名单外的路由会被拒。要给 Reviewer 换档，先确认该项在 `allowedModels` 里。
* **前台 vs 后台**：审查必须**前台**等待（`run_in_background: false`）。后台路径只通知"某次运行结束了"，verdict 要从子会话里另取，等于把"一次调用拿回一份 verdict"这条账目关系弄糊。

## 3. 备用路径（Reviewer = 独立进程）

需要物理级隔离、或要把某轮审查留成可复现证据时：

```powershell
$env:DSH_HOME = "$env:USERPROFILE\.dsh"
$HOLD = "$env:USERPROFILE\.dsh-review-holding\<task>"; New-Item -ItemType Directory -Force $HOLD | Out-Null
# prompt 写进仓外文件（不要塞进命令行，长 prompt 会被 shell 转义弄坏）
npx -y @deepseek-ai/dsh --profile headless (Get-Content "$HOLD\9B_prompt.txt" -Raw) > "$HOLD\9B.md" 2> "$HOLD\9B_raw.log"
```

* headless 进程**没有 `-o`**（`-o` 是原 Claude 侧 `codex exec` 的参数，DSH 无对应项），verdict 走 **stdout**，raw log 走 stderr。
* **headless 也钉不住模型档**：`dsh --profile headless` 只接受 `-h/--help` 与位置参数 `[task...]`（源：`@deepseek-ai/dsh-headless/lib/startup.js`），**没有 `--provider` / `--model` / 推理档参数**——它读部署的 `agentDefaultModel`。因此备用路径下"Author 与 Reviewer 都取 `deepseek-flash`"这条**不由调用参数保证**；要钉死须先用 `--patch` 或 profile patch 固定 `agent-default-model`，否则只能靠 verdict 里的 `model_route` 自报值暴露漂移。
* headless 会话**是持久化的**（每次运行落一个新 session），因此它比 `subagent` 更接近原 Codex 形态：fresh 进程、独立会话、可事后回看。
* 该路径下 Reviewer 同样**不能**把 verdict 写进仓库——重定向目标由 **Author 指定为仓外 holding**。
* 两条路径都遵守同一条顺序：**9B 先跑、9A 后跑**，两次之间确认工作树内无 verdict 残留。

## 4. 派发上限（成本纪律，机器可读形式）

> 母本的成本纪律来自 Claude 侧实测（一次 fan-out 97/69/59 个 agent、单 agent 25–30 万 token 烧光配额，而真正有用的只需 4–10 个）。DSH 侧模型便宜不等于可以一事一 agent：**并发上限保护的是一次交付的可审性，不只是账单**。

* 一次 fan-out：**≤ 10 个 agent**，**并发 ≤ 6**，一轮 **≤ 3 个 `workflow`**。
* **不得一事一 agent**（一文件 / 一发现 / 一声称一个 agent）：把清单**按批分组，一组一个 agent**。
* 对抗性复核 = **每批一个复核者**，不是"每条发现 N 个投票者"；**不做 loop-until-dry**。
* 例外：只有当**人类在本次请求里写了显式预算**（如 `+20k`）时才可超过，并按 `budget.total` 缩放。
* 撞上用量上限而死的一轮：**先缩小再恢复**（失败的 agent 不缓存）。

## 5. 失败语义（Reviewer 没给出可用 verdict 时怎么办）

* `subagent` 前台调用**失败**（`Error: <stop reason>`、超时、配额拒绝）→ **该轮审查没发生**。重跑同一 prompt；重跑仍失败 → 停手报告人类。**不得把"没有 verdict"记成 `通过`，也不得由 Author 代写一份 verdict。**
* 调用**成功但返回空**（或只有推理没有正文）→ 把"空返回"照实记进 verdict 文件并**重跑一次**；两次都空 → 停手报告人类。
* 前台审查**不会**变成后台 job；如果调用意外返回了 job id / child id，说明调用形态写错了（应显式 `run_in_background: false`）——按失败处理，重跑，并把这次误用写进 HANDOFF Work Log。
* **`model_route` 自报值与 Author 实发参数不符** → 本轮审查的档位不可信：把不符项照实记进 Work Log 并报告人类（这是 `model_route` 字段存在的**唯一目的**——它不是证据，只是让档位漂移可见）。是否作废重跑由人类裁决，不由 Author 自行择一采信。
* **连续两次失败即停**（`AGENTS.md` → 停止事件优先级 ②）：不自动回退、不换第三条路，把控制权交回人类。

## 6. 与其他工具的边界

* `workflow` 可以一次并行跑多轮审查（例如同一份 diff 的多个独立视角），但**每个 stage 仍是一份独立 verdict**；摘要与合并由 Author 做，**不得让某个 stage 去"综合"别的 stage 的 verdict**（那会把两份独立判断重新焊成一份）。
* `job_*`（后台作业）与审查无关：审查用 `subagent` 前台，长测试才用后台作业。
* `dsh web`（本 GUI）与 headless 是**不同 profile**，加载同一套宿主插件；`~/.dsh/AGENTS.md` 的基线在两条路径上都会注入（已冒烟确认）。因此**同一份 reviewer prompt 在两条路径上都成立**，差别只有进程隔离度。
