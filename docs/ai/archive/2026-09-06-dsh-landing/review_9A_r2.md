# 9A verdict（第 2 轮）— dsh-landing review

> **来源与保真度声明**：Reviewer 把 verdict 作为 **agent 返回正文**交回；本文件由 **Author 在双审窗口结束后转录**，非 Reviewer 手写原始 artifact。Blocking 闭合表、Suggestion、VN、Debt、归类理由为逐条转录；叙述性前言略去。
> 审查对象：`review_base_sha = a361bc19` → `review_tip_sha = 7084fb75`

## 证据首行（隔离五项核验通过）

```
observed_head_sha: 7084fb7515ef36e8191f20a141bf2118cd20ff4e
worktree_clean: yes
read_handoff_from: 工作树（如实写明：HANDOFF 内容仍是第 1 轮数值，与本 prompt 的 7084fb75 不符 → 视该文件"不属于本轮快照"，以 prompt 数值为准，不据此拒审）
model_route: deepseek-official/deepseek-flash@high（自报；Reviewer 声明"本次调用未在会话内显式展示参数，我按 9A 档位声明填写"——这正好是该字段"自报、非证据"的实例）
writes_performed: none（**如实登记一处仓外 scratch**：为核对归档 HANDOFF 的逐字保真，曾把 `git show a361bc19:docs/ai/HANDOFF.md` 重定向到 `%TEMP%\old_handoff.txt` 作比对副本——位于仓库与 holding 之外、未触碰仓库任何文件，按零写入纪律属越界，记此备案）
覆盖缺口: docs/ai/TASK_BRIEF.md（prompt 声明的清单含它，工作树审前 HANDOFF 的清单不含 → 属落账待补）
```
（Author 注：`model_route` 自报值与我实发参数逐字比对 = `provider: deepseek-official` / `model: deepseek-flash` / `reasoning_effort: high` → **一致**；`TASK_BRIEF.md` 已补入清单。）

## Review Verdict

**有条件通过**（Blocking = None；VN 非空）。**无 `caused_by_last_fix: yes` 的 Product Blocking → streak 归 0，不触发硬停。**

## 上轮 B1–B4 闭合核验

| 条 | 结论 | 一手证据要点 |
|---|---|---|
| B1 `9P = medium` 死值 | **已闭合**（静态证成；缺端到端实跑） | DSH 面赋值位实跑枚举 **8 处全为 `high`**，无 `medium`；适配器 `reasoningEffort()` 硬校验只放行 `off/low/high/max`；判据未被消掉（9P 单轮/不进 streak/批准权在人类一字未动）；回滚值写的是 `low` 而非不存在的 `medium`。**未闭合**：TASK_BRIEF 自认必做的 9P `high` 实跑取证未做 → VN1 |
| B2 §2「只有这些改点」不实 | **已闭合**（点名 11 项 100% 入账）；**但新引入 2 处登记不实** → S1/S2 | 逐项在 §2/§2.1 找到 #13–#22 |
| B3 `install.ps1` 注释 vs 代码 | **已闭合**（残留一处从属 clause → S3） | 逐句对读 `:15-21` 与代码 `81-107`：整树镜像 ✓、两个 bundle 整目录 mirror ✓、其余 skill 不触碰 ✓、机器态清单 ✓；`phase-` 假声称消失 |
| B4 `-o` 自相矛盾 | **已闭合** | 全 `dsh/` 面 6 处 `-o` 全为"headless 没有 `-o`"式；headless CLI 面一手复核 = 只有 `-h/--help` + `[task...]` |

## Blocking Issues

**None。**

归类说明（避免误读为漏报）：实测并判定为**登记不实**的 2 条（S1 手册"已逐字补回"不实、S2 §2#10 把 `model_route` 记进 phase 文件不实）属"账本与措辞不一致"，规则明确归 Non-Blocking Suggestions 且不得阻止收敛；归档文件里的损坏字节（S4）是真实数据错误，但影响面为一句可读文本、无产品行为后果。

## Non-Blocking Suggestions（8 条）

1. **S1（实质）**：`DSH-LANDING-NOTES.md` 的"已在本轮逐字补回"与实际不符——两份手册的 blob 在 `a361bc19` 与 `7084fb75` **完全相同**（`6039958e…` / `75fbe933…`），且全 `dsh/` 树 grep `用例总数|仍能检出` 在 `conflict-hard-stop.md` 内**零命中**。**Fix**：(a) 真抄进手册，或 (b) 改为"已确认两条判据在位：`AGENTS.md:197/231` + `phases/final-review.md:28`"。
2. **S2（实质）**：§2 第 10 条把 `model_route` 记进 phase 文件，实际 `references/phases/*.md` 零命中。**Fix**：括号收窄。
3. **S3**：`install.ps1` 残留无代码支撑的 clause（`new files elsewhere are only copied when missing`）。**Fix**：删除或改写。
4. **S4**：归档 HANDOFF 有一个被 PowerShell 转义吃掉的字符（TAB 取代了 `t`，`task/dsh-landing` 变 `␉ask/dsh-landing`）；对该范围 673 条新增行做了控制字符扫描，**唯一一处**。**Fix**：改回，并避免在双引号串里用 `` `t/`n/`r ``。
5. **S5**：`reviewer-prompt.md:68`（两条路径证据面）与 `:141`（前置检查第 5 项）仍只列 `writes_performed`，未同步 `model_route`。**Fix**：两处补，或加一句"凡称证据首行均含 `model_route`"。
6. **S6**：`conflict-hard-stop.md` 在部署面内是**孤儿手册**（两个 SKILL.md、7 个 phase、`dsh/AGENTS.md`、`dsh/workflow/**` 全不指向它；DSH 又不认嵌套 `**/SKILL.md`）→ 永远不会被加载。**Fix**：在 `SKILL.md` 参考清单加指针。
7. **S7**：TASK_BRIEF 的 AC 判定方式有三处不合格——AC1/AC8/AC9 无判定方式；**AC4 的冻结输入域没有界范围**（按字面会扫进 `portable/通用prompt-v3.8.txt` 的 Codex 侧 `medium` → **假红**）；**AC6 按字面不可满足**（23 项 diff 里 9 项不在 §2/§2.1）。**Fix**：AC4 限定到 DSH 面、AC6 限定到交付面路径集、AC1 补命令或标"本轮不判定"（**需人类 Amendment，属收敛门 ③(c) 例外**）。
8. **S8**：落账待补两项——审前 HANDOFF 的清单未含 `TASK_BRIEF.md`；修补后再同步 `~/.dsh` 的动作未记入 §4/Work Log。

## Test Coverage Gaps

* 无功能测试套件；`last_test_run.txt` 绑 `tested_sha = a361bc19`（修补前），其 §B/§C/§D/§E 记录的是修补前状态，**本轮 tip 无任何绑定测试产物**。
* 未覆盖：`install.ps1` 运行行为、headless 完整审查轮、9P 门在真实任务上的可跑性、`~/.dsh` 机器态哈希比对（AC8）、`model_route` 真实性。

## Cannot Verify From Diff

* `install.ps1` 实际运行效果（须实跑，也是 AC8 标注的"本轮只做静态核验"）。
* 人类四条裁决的发生过程（按规则按人类决定对待）；只核"是否照办"：四条全 ✓。
* `model_route` 自报值真实性；`~/.dsh` 再同步的确切时点意图；已落账 verdict 与 archive 的内容（按规则未打开）。

## Verification Needed（3 条）

1. **VN1**：本轮 tip 缺绑定测试产物，且 TASK_BRIEF 自认必做的 9P 档位实跑未做。**最小检查**：发一次 `subagent(provider: "deepseek-official", model: "deepseek-flash", reasoning_effort: "high", run_in_background: false)` 的 9P 调用，把命令、真实输出与退出码追加进 `last_test_run.txt`，文件头改绑 `tested_sha = 7084fb75`。
2. **VN2**：AC3 备用路径未按 AC 规定方式（`--help` 或实跑）确认。**最小检查**：`npx -y @deepseek-ai/dsh --profile headless --help`，贴退出码与输出。
3. **VN3**：AC4 的负向对照从未实跑（属"反例必须实际触发失败，不接受纸面反例"）。**最小检查**：临时把 `dsh/workflow/reviewer-prompt.md:44` 的 `"high"` 改为 `"medium"` → AC4 判定必须红 → 还原并 `git diff --quiet` 验证（**须在还原并自检干净后再落任何 commit**）。

## Debt Verdict

**Unpaid。**
* 第 4 笔（`install.ps1` 整树备份复制凭据 vs README"凭据从不触碰"）：**Payback-on-Touch 已触发**——本轮改动的正是 `install.ps1` 的 DSH 段，而债未在同 commit 内偿还（README 措辞原样保留、备份行为未收窄），也无人类批准延期记录。写成注释级 WARNING + 债条目属"减轻可见性"，**不构成偿还**。（异议预留：若按"只改了注释、未改行为"理解，trigger 是否命中可争；按 trigger 字面判定命中，**交人类裁决**。）→ `/final-review` 第 11 条据此**不得判「可以提交」**。
* 第 1 笔（未审 delta）本轮已跑第 2 轮，但因 VN 未处置、未收敛，暂不能标已偿还。
* 第 2 笔（fanout 事实绑定 rc 版本）：本轮改动命中 trigger，且新增的一手事实被独立复核（适配器硬校验、headless CLI 面、官方公告 URL 实取 HTTP 200 且内容吻合）→ **视为已偿还**。
* 第 3 笔（运行副本无备份）：未触发，**Noted**。

## Recommended Next Step（只给建议）

1. **先不要合并**：Debt = Unpaid（第 4 笔）+ 本轮 tip 无绑定测试产物——两项都落在合并门上，需人类先裁。
2. **人类裁决两件事**：① 第 4 笔债走"偿还"还是"明确批准延期"；② 本 verdict 的 `model_route` 自报值与 Author 实发参数是否逐字相符。
3. **Author 落账**：三个 SHA 用 prompt 数值、`TASK_BRIEF.md` 补进清单、`caused_by_last_fix` 逐字转录（本轮无 Product Blocking → **streak 归 0**）、VN 逐条登记、工作树 HANDOFF 的第 1 轮数值一并更新。
4. **Author 代跑 VN1–VN3** 并把真实输出**追加**进 `last_test_run.txt`（属收敛门 ③(b) 例外，不触发再审）。
5. **S1–S8 的处置取舍需人类拍板**：这些建议分布在 `docs/ai/DSH-LANDING-NOTES.md`（review-sensitive）、`dsh/**`、`install.ps1`、归档 HANDOFF、`TASK_BRIEF.md` 上——**任何一处落笔都会产生 review-sensitive delta**，按收敛门 ③ 需对该 delta 再审（第 3 轮，仍在双审 3 轮上限内）。建议优先级：S4（损坏字节，数据完整性）> S1/S2（登记不实，正是 B2 的病根）> S6（孤儿手册）> S3/S5（措辞同步）> S7（AC 判定方式，走人类 Amendment、属 ③(c) 例外）。
6. 若人类选择"先合并、Suggestion 留档"：请在 README 的 DSH 迁移状态节如实写明"已审 tip = `7084fb75`，verdict = 有条件通过，8 条 Suggestion 未处置、债 #4 Unpaid"，以免下游把"已审"误读成"已收敛"。
