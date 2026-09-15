---
name: independent-review
description: Use when dispatching or receiving an independent review in DSH — running 9P plan review, 9A standard review, or 9B blind review; setting up dual-review isolation; verifying the pre-review snapshot; deciding what verdicts may and may not do; or handling a Reviewer that failed, returned nothing, or wrote into the repo.
whenToUse: Load before sending any review prompt, when collecting verdicts, when a review round is about to start or just ended, or when the human asks for "一次独立审查" without enabling Critical.
---

# Independent review（DSH 执行手册）

> **prompt 全文与判据唯一定义处**：`~/.dsh/workflow/reviewer-prompt.md`（9P/9A/9B 三段 prompt + 输出契约 + 双审隔离协议 5 条）。
> **角色与零写入定义处**：`~/.dsh/workflow/AGENTS.md` → AI Collaboration Rules / Reviewer-Lightweight Protocol。
> **工具面事实（参数、准入白名单、失败语义、派发上限）**：`~/.dsh/workflow/fanout-toolchain.md`。
> 本文件只做两件事：**把 prompt 投出去的机械清单**，和**收回来之后必须核的东西**。**规则不在本文件里，别在这里找判据。**

## 1. 开审前（Author 逐项打勾）

1. **模式确认**：这次是 Critical 双审，还是 Routine 的临时单审？
   * Critical → 用 `reviewer-prompt.md` 的 9A/9B（+ 开局 9P）。
   * Routine 临时单审 → **不要**用那三段 prompt（它们会索取 Routine 没有、也不得创建的交接文件而拒审）。写明模式、点名要审的文件/diff，证据载体取 `AGENTS.md` 第二层的 **Routine 那一句**。
2. **三个 SHA 逐字填进两份 prompt**：`review_base_sha` / `review_tip_sha` / `handoff_snapshot_sha`。**不写"见 HANDOFF"**。
3. **自核快照**：`git rev-parse HEAD` == `handoff_snapshot_sha`，且全树 `git status --porcelain` 为空；不满足 → 先形成明确的 reviewable commit，**别发审**。
4. **无残留**：`git status --porcelain --ignored` 里没有任何 verdict / raw log 模式（`9A*.md` / `9B*.md` / `.dsh-review-*` / `.codex-review-*` / `review_9*` / `review-*` / `*_raw.log`）。**`--ignored` 必带**——普通 status 看不见被 ignore 的残留。
5. **仓外 holding 已建**：`$HOME/.dsh-review-holding/<task>`，与仓库工作树不同子树。
6. **两条恒等成立**：两份 prompt 都内嵌对应模式的证据载体整句；两份都写了「零写入 + `writes_performed` 字段」。**9A 的 prompt 里不得出现 9B 的任何内容**，9A/9B 的任何 prompt 都不得出现 9P 的内容。

## 2. 派发（主路径 / 备用路径）

**主路径（默认）—— 同会话 `subagent`，前台等结果：**

```
subagent(
  description: "9B blind review",       # 或 "9A standard review" / "9P plan review"
  run_in_background: false,             # 审查必须前台
  provider: "deepseek-official",
  model: "deepseek-flash",
  reasoning_effort: "high",             # 9A/9B = high；9P = high（DSH 无 medium 档）
  prompt: <reviewer-prompt.md 对应段落，变量逐字填好>
)
```

**备用路径 —— 独立 `dsh --profile headless` 进程**：verdict = stdout、raw log = stderr，两者都重定向到**仓外** holding；headless **没有 `-o`**。命令模板见 `reviewer-prompt.md` → 双审隔离协议 ③(b)。

**顺序硬约束：9B 先、9A 后**（盲审最需要干净上下文）；两次调用之间再核一次"工作树无 verdict 残留"。9P 发生在实现之前，不属于这两轮，也不计入双审轮次上限。

## 3. 收回后必须核的 5 项（缺一项该轮作废重跑）

| # | 核什么 | 合格判据 |
|---|---|---|
| 1 | `observed_head_sha` | 两份**相互相等**且 == `handoff_snapshot_sha` |
| 2 | `worktree_clean` | 两份都是 `yes`（全树 `git status --porcelain` 为空） |
| 3 | `read_handoff_from` | 两份都是「工作树」；出现 `git show tip` 即作废 |
| 4 | `writes_performed` | 两份都是 `none`；有任何写入尝试 → **该轮作废重跑**（DSH 无沙箱兜底，这是纪律的唯一落点） |
| 4b | `model_route` | 两份都写了 `<provider>/<model>@<effort>`；**Author 必须拿它与自己实发的调用参数逐字比对**——不符即记 Work Log 并报告人类，不得自行择一采信。它是**自报值、不是证据**，只为让档位漂移可见 |
| 5 | 覆盖率 | 每份的「覆盖缺口：<路径>」行已记下，Author 落账时补进 `review_sensitive_paths` |

**作废就是作废**：不要"下不为例"、不要"反正内容看着没问题"。一份被污染的独立判断不是独立判断。

## 4. 落账（Author，双审窗口**结束之后**）

1. 把两份返回正文分别写进**仓外** `$HOME/.dsh-review-holding/<task>/9A.md` / `9B.md`。
2. 收进 `docs/ai/review_9A.md` / `docs/ai/review_9B.md`（仓内副本 —— 这一步在窗口结束后才做）。
3. **一次性**更新 HANDOFF：`review_verdict_9A` / `review_verdict_9B` / `handoff_snapshot_sha` / Work Log / Fix-Loop Counter（`caused_by_last_fix` **逐字转录**）。
4. 9P 例外：只进 `docs/ai/review_9P.md`（verdict + 该轮 Author Responses），**HANDOFF 只记 Plan Verdict 词 + 文件指针**，Work Log 一句话。**9P 内容不得进入任何 9A/9B 的输入**（读它等于间接读计划，尤其会毁掉 9B 的盲审）。
5. 人类确认后再清仓外 scratch。

## 5. 异常处置（不要发明第三条路）

* **subagent 失败**（`Error: <stop reason>` / 超时 / 配额拒绝）→ 该轮审查**没发生**。重跑同一 prompt；仍失败 → 停手报告人类。**不得把"没有 verdict"记成 `通过`，不得由 Author 代写 verdict。**
* **返回空**（或只有推理没正文）→ 照实记"空返回"并重跑一次；两次都空 → 停手报告人类。
* **意外返回 job id / child id** → 调用形态写错了（应显式 `run_in_background: false`）。按失败处理、重跑，并把这次误用记进 HANDOFF Work Log。
* **Reviewer 写了仓库**（`writes_performed` 非 none，或工作树出现新文件/新 commit）→ **该轮作废**；把写入物按人类确认处置（Author 清理，Reviewer 不清理仓内任何文件）；重跑。
* **连续两次同处失败** → 停止事件优先级第 ② 条：立即停手报告人类，不自动回退、不重启。

## 6. Reviewer 侧的口径（派发前确认 prompt 里已写明）

* **只审不改**：不改生产代码/测试/验收文件、不改 HANDOFF、不 commit、不落盘 verdict。
* **不做的事**：不 `git archive` 重建副本、不重装依赖、不重跑全量测试、不跑装置（只核产物字段完整性与自洽）。
* **不得打开**：`docs/ai/archive/**`、已落账的 `docs/ai/review_9*.md`（含 `review_9P.md`）——历史 verdict 不是本轮输入。
* **输出必须落契约**：三行证据首行 + `writes_performed` + 七个顶层字段；每条 Blocking / Suggestion 必附 `Proposed Fix`。
* **9B 额外**：不读 `IMPLEMENTATION_PLAN.md`（已在正文 diff 里机械排除）；专攻遗漏入口 / 状态生命周期 / 边界值 / 回归。
* **9P 额外**：不执行审前快照自检、不要 `last_test_run.txt`、不因缺 SHA 账本拒审；锚定只记 `9P_round` + 三行哈希 + `writes_performed`。
