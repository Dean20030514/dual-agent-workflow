# 9A verdict（第 3 轮）— dsh-landing review

> **来源与保真度声明**：Reviewer 把 verdict 作为 **agent 返回正文**交回；本文件由 **Author 在双审窗口结束后转录**，非 Reviewer 手写原始 artifact。
> **减档说明（如实登记）**：本轮 Reviewer **自行判定走了减档路径**——它的证据头写"审查模式 = 9A 第 3 轮（人类裁决②只要求 9A → **9B = N/A，减档原因：人类裁决只跑 9A**）"。**这是它的推断，不是人类的减档指令**：人类说的是"跑第 3 轮 9A"，而 9B **实际也已跑过**（见 `review_9B_r3.md`，结论"不通过"）。因此本轮**不是合法减档轮**，两份 verdict 并存——该误判记此备案。
> 审查对象：`review_base_sha = 7084fb75` → `review_tip_sha = 34b60370`

## 证据头（隔离五项通过）

```
observed_head_sha: 34b60370fdac02b3d2670a0058b729bc99a7589f
worktree_clean: yes
read_handoff_from: 工作树
model_route: deepseek-official/deepseek-flash@high（自报值、非证据）
writes_performed: none
覆盖缺口: 无
```
delta = 两个 commit：`956db71`（修 S1–S8/收 VN）+ `34b6037`（偿还 install.ps1 债 #4 + 收尾 9B-S1）。

## Review Verdict

**有条件通过**（Blocking = None；VN = 4 条）。streak 不递增（0 条 Product Blocking）。

**归类理由（Author 注：这是与 9B 的实质分歧点）**：Reviewer 把本轮主要缺陷——**登记/账本/判据文本与事实不一致**（HANDOFF、README、`DSH-LANDING-NOTES` 的状态块与 tip 不同步）——按 `AGENTS.md`/`conflict-hard-stop.md` 的规定归为 Non-Blocking Suggestions（"账本与措辞不一致…写进 Non-Blocking Suggestions"），理由写不出"哪个用户操作/哪条数据/哪个安全边界会出错"的具体后果。**其中它把与 9B-B1 同源的 AC6 缺陷也定为 Suggestion 级**（S1）。

### README 措辞（第 4 笔债偿还）与 `install.ps1` 逐句核对 —— 相符，未发现反向过度声称

逐句对照结论：只读写受管路径 ✓；机器态不被修改/删除 ✓；整树备份会把它们复制一份 ✓（**主动披露**，方向正确）；不自动清理 ✓；"要避免复制凭据需先修 install.ps1" ✓。**同一文件内无三笔/四笔冲突**；矛盾在**跨文件**（`README:54` 与 `TASK_BRIEF:60` 说三笔，`DSH-LANDING-NOTES:83`/HANDOFF 说四笔）。

### 上轮 8 条 Suggestion + 3 条 VN 逐条核

S1 **真修（这次是真的）**——`conflict-hard-stop.md:25/:47` 已含两条反滥用条件，与母本逐字同形。S2 修。S3 **只修一半**（`:97` 同族 clause 仍在）。S4 修。S5 修。S6 修（两行指针同时接上两份手册）。S7 **部分修**。S8 修但落账内容已失实。VN1 **未真正闭合**（探针不能证明档位送达）。VN2 闭合。VN3 **形式闭合、产物不可复现**。

**额外独立复核（Reviewer 实跑）**：`dsh/**` 23 文件 vs `~/.dsh` → **23 SAME / 0 DIFF**；17 对 `--no-index --numstat` 全表；**未发现任何阈值/轮次/判据漂移**。

## Blocking Issues

**None.** 逐项否掉的理由：AC6 按字面红 → 属"验收条款写法的散文判定"缺陷，契约明文归 Suggestion；AC1 降级 → 属"没有偿还触发器的 known-issue"，`conflict-hard-stop.md:64-65` 明文"不构成 blocking"；账本/状态块滞后 → 明文归 Suggestion；`install.ps1:97` → 同族原文上轮即判 Suggestion 级。

## Non-Blocking Suggestions

* **S1（实质）AC6 改后仍不可满足**（`yes`）：判定范围含 `docs/ai/TASK_BRIEF.md`，而它在登记表里**零命中**；`<base>` 未钉死 → 红集合随 base 变（`a361bc19` base 下缺 TASK_BRIEF；`bf06c65` base 下另缺 4 templates + AB-model-diagnostic）。排除条款与 `--no-index --numstat` 实测不符（缺 frontmatter 归一化）。**Fix**：§2.1 增收 `TASK_BRIEF.md` 行 + 把 templates/AB 归入 §2 第 5/11 条或新增行；AC6 钉字面 SHA；排除条款改为"phase 正文的三处归一（`name` / `disable-model-invocation` / 末尾换行）"。
* **S2（实质）AC4 只改了一半**（`yes`）：`TASK_BRIEF:65` 的"冻结输入域"节仍是**旧域**（"文档中出现的每一个取值"），按它判定会因 `claude/workflow/reviewer-prompt.md:168` 的 Codex 侧 `medium` **假红**——S7 要修的假红原地复活。**Fix**：把 `:65-67` 与 Amendment 的收窄域对齐，或删掉该节只留 `:49-52`。
* **S3（实质）AC1 降级：理由与判定对象不符，且无 Payback trigger**（`yes`）：AC1 对象是**单文件对**，"17 对/2600+ 行"属 Testing Plan 与 AC10。Reviewer 逐行读完 40 行变更、**未发现判据/阈值漂移 → AC1 实质满足**。而 "Known Limitation" 无触发器，正属被禁措辞；HANDOFF 四条 `[DEBT]` 里没有 AC1。**Fix**：推荐 (a) AC1 改回可判定并给出本轮结论；或 (b) 对 AC10 首句立 `[DEBT]` + 触发器，并把 Amendment 里的"17 对"改为"单文件对"。另 §2 第 4 条漏记一处同行措辞改写。
* **S4 AC10 的判定方式对它的声称没有区分力**（`no`）："指针行数相等"与判据漂移无因果（漂移 10 处该计数也不变）。实测行计数 claude 4 / dsh 4 相等，**但匹配数 claude 4 / dsh 6**（dsh 多两处母本兜底），`DSH-LANDING-NOTES:101` 的"3 / 3+2"与两种机械计数都对不上。**Fix**：改用逐对 `--no-index --numstat` 映射，并要求"凡触及判据/阈值/轮次的行必须单列"。
* **S5 账本滞后于同轮的后一个 commit**（`yes`）：(a) `HANDOFF:51/:87` 说 9B-S1 未改，实际 `34b6037` 已改；(b) `HANDOFF:60` 的触达清单漏 `README.md`；(c) `:69` 与债 #4 仍写"未偿还"而人类已裁决且已落地；(d) `:67` 的 Impact"README 措辞与之不符"在 tip 已不成立；(e) `last_test_run §K/§L` 写"未再同步"与实测 23/23 矛盾；(f) 债 #2 在 HANDOFF 标"视为已偿还"却仍在未偿还清单。**Fix**：下一次 docs-only commit 按 tip 重写。
* **S6 状态块未随轮次更新**（`no`）：`README:54` 仍"未经过审查""三笔"；`DSH-LANDING-NOTES:4/105/§3#1` 仍"待第 2 轮再审""第 2 轮尚未跑"。方向更保守，不构成安全过度声称，但作为对外入口段是事实错误。**Fix**：按轮次记账、债数统一四笔。
* **S7 AC9 未随 S7 收口**（`yes`）：`TASK_BRIEF:60` 仍"三笔"；且 AC9 无判定方式（缺"判定人/输入/判据/反例"）。**Fix**：改四笔 + 补判定方式（含负向对照：故意写一句"先这样"必须红）。
* **S8 `install.ps1` 内部口径残留两处**（`yes`，其中注释口径半条标 `dispute`）：`:97` 的 clause；`:20-21`/`:76-77` 写凭据 "are never touched" 而 `:81` 会复制整树（README 已按裁决改成"不被修改或删除**但**会被复制一份"，代码注释没跟上）。**Fix**：删 clause + 注释同口径。

## Test Coverage Gaps

tip 无任何绑定机制核验产物（delta 改了 6 个 `dsh/**` 文件，`tested_sha` 仍绑 `7084fb75`）；AC2（skill 发现面）在新 tip 未复验（两个 SKILL.md 都改过）；AC8 仍只有静态核验；无功能测试套件。

## Cannot Verify From Diff

`model_route` 真伪；§H 的返回是否逐字照抄；§I/§K 命令原文不可重放（**§K 已由 Reviewer 用等价只读命令复核，结论成立**）；`~/.dsh` 在 20:21 时点是否已同步；前两轮 verdict 原文（本轮禁读）；AC8 机器态哈希基线。

## Verification Needed（4 条）

1. **VN1（最高优先，反滥用条件本身）**：文档三处声称"写 `medium` 会抛 `UNSUPPORTED_REASONING_EFFORT`"，现有证据**只有静态 grep**——按"任何『机制 X 会拒绝 Y』的声称都须负向对照"的规则，**这条守护声称从未实跑**。最小检查：发一次 `reasoning_effort: "medium"` 的 subagent，贴完整报错原文 + 子 agent 是否被创建；若未被拒，则当场把三处声称收窄为"适配器取值域不含 medium（静态核验）"。
2. **VN2**：把 §I 的 AC4 负向对照重跑为字面命令 + 完整输出 + 退出码（绿红两次），或明写"不可复现"并把 §I 降为自述。
3. **VN3**：按 `TASK_BRIEF:65` 的字面域扫全部文档，预期在母本的 `medium` 处得到假红，据此决定改 `:65` 还是保留排除条款。
4. **VN4**：9P `high` 的"值确已送达适配器"——取该探针调用的 `reasoningEffort` 字段，或把 §H 结论收窄为"未观察到拒绝（不等于档位生效）"。

## Debt Verdict

**`Noted`**（无"触发且未获延期"的债 → 不阻止判"可以提交"；但三处账目要改写）：
* 债 #1 → 本轮 9A 即其偿还路径，重审完成后改词；9B 若减档记 `N/A`（但**本轮 9B 实际跑了**，见文首）。
* 债 #4 → Payback trigger 本轮命中，人类选"收窄 README 措辞"且已落地 → **不判 `Unpaid`**；但条目 Impact 已失实，应改写为残留行为（备份仍复制凭据且不自动清理）。**不要静默删条目**。
* 债 #2 → 两账取一。债 #3 → 未触发。
* **AC1 的 "Known Limitation" 不是合法债**：无 Payback trigger，属被禁形态。

## Recommended Next Step（只给建议）

1. **推荐：一次"docs-only 收尾 + 4 条 VN 代跑"，不引入新内容物**——把 S1–S8 的事实错误在同一次 docs commit 内改对，并追加 VN 真实输出。**注意**：`TASK_BRIEF.md` 属验收面，按收敛门 ③(b) 不算"非验收文档" → 这类改动需人类裁决背书（可把已有的"接受 Amendment"扩展为"接受上述收尾"），或走 ③(c)。
2. **若不再批新一轮**：走"限制交付"——前置是剩余 VN 逐条处置 + 零未解决 Product Blocking；**不得标"已收敛"/Ready to Commit**，README 与 HANDOFF 必须如实写明"已审 tip = `34b60370`，残留 Suggestion 见 review 文件"。
3. **不建议再开第 4 轮**：关闭阀是"双审达 3 轮仍未收敛 → 停止再审"，本轮已 3/3；要延必须人类**逐次**明确批准并说明判据（本轮剩余项全是登记/措辞级，重审边际收益低于把账目改对）。
4. 若走 1 或 2，**先做 VN1**：它是唯一一条"文档声称一个守护机制会拒绝、却从未实跑负向对照"的项。
