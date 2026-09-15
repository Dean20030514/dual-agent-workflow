# 9A verdict（第 4 轮）— dsh-landing review

> **来源与保真度声明**：Reviewer 把 verdict 作为 **agent 返回正文**交回；本文件由 **Author 在双审窗口结束后转录**，非 Reviewer 手写原始 artifact。
> 审查对象：`review_base_sha = 34b60370` → `review_tip_sha = fc32899f`

## 证据与快照（隔离五项通过）

```
writes_performed: none
observed_head_sha: fc32899f5d6addd0cbafd43ab33fd56c607e9cd3
worktree_clean: yes
read_handoff_from: 工作树
model_route: deepseek-official/deepseek-flash@high（自报值；provider/effort 无机械手段自证）
覆盖缺口: 无（另含 2 个契约排除项 review_9{A,B}_r3.md，未打开）
```
本轮实测（只读）：AC6 谓词在 tip 上 **GREEN、reg = scope = 30**；`core.quotepath=true` 时 `portable/通用prompt-DSH-v1.txt` 被转义 → 假红（纪律①成立）；**AC1 判定对象 40 条变更行逐行读完**，均可归入 §2 #1–#6 或 §1 第 2 步，未触及判据/阈值/轮次；AC4 域独立复核（DSH 侧 7 个赋值位全为 `high`，适配器 `"medium"` 零命中）；仓内 `dsh/**` 23 文件 vs `~/.dsh` mismatches=0。

## Review Verdict

**有条件通过（Blocking = None）。**

上轮 9B 的 B1 **已实质闭合**。9A 自己上轮的 S1/S2/S3/S4/S5/S6/S7 均已按其判定对象改写或收口，AC1/AC4 的实质被独立核过、成立。**但本轮新写的判定文本里有 5 处"按字面不可执行/恒绿/与事实不符"的缺陷**（R4-S1–S6）——全部属**验收条款的判定方式与登记文本层**，写不出"哪个用户操作/哪条数据/哪个安全边界会出错"的具体后果，故按契约**一律不进 Blocking**。

**归类取舍的说明（Reviewer 主动写出，便于人类复核）**：本轮 delta 只改 5 个文档面文件，未改 `dsh/**`、未改 `install.ps1`、未改判据；其**实质声称逐条核过后全部成立**（AC6 登记等于 scope；AC1 无漂移；AC4 取值域；`~/.dsh` 同步；未发现"把未做写成已验证"的新增声称）。剩下的全是判定方式与登记文本的措辞/形态问题。**streak 不变。**

> **Author 注（分歧记录）**：同一条 AC9 判定①缺陷，9B 判为 `[Product Blocking]`（归因 `dispute`），9A 判为 Suggestion。**两份给出了相反的归类，理由都被写清**（9B：不可复现 = 违反"可复现"要件，且上轮同型缺陷被人类裁为 Product；9A：写不出具体后果）。**该分歧交人类裁决，Author 不择一采信。**

## Blocking Issues

**None.**

## Non-Blocking Suggestions（11 条）

* **R4-S1（实质，`yes`）**：**AC6 的第二条反例按字面恒绿、且未被执行**。`TASK_BRIEF:70` 要求改"§2.2 任一模板声明行"，而 §2.2 是 markdown 表格（行首 `|`），谓词正则 `(?m)^- path:` 只认 §2.3 的行 → 两边 $reg/$scope 都不变 → Reviewer 在内存复现 **GREEN**，与 AC 的"必须红"相反。实际跑过的 NC1 删的是 **§2.3** 的行——**文字里写的反例与真正跑过的不是同一个**。附：`NOTES:78` 的"本节编号 §2.2 被 AC6 直接引用"把这处错误引用**固化成了稳定性约束**。**Fix**：把反例改指向 §2.3，或把 §2.2 五行也写成 `- path:` 并入 §2.3（**不要两份清单**）。
* **R4-S2（`yes`）**：`NOTES:65`（§2.1 #18）的登记理由仍描述"旧的按文件名匹配谓词"，与同轮把谓词改成"读 `- path:` 全路径"自相矛盾。**Fix**：改为按 `- path:` 全路径比对。
* **R4-S3（`yes`）**：① `TASK_BRIEF:58`"`dsh/workflow/` 不在 scope 里"**与事实相反**（scope 的 `dsh` 覆盖它，实测 30 项里 22 项在 `dsh/` 下）；② `NOTES:91` 的"下表的 `docs/` 行"是草稿残留（表里既有 `dsh/**` 也有 `portable/**`）。**Fix**：① 删或改为"`dsh` 已覆盖它"；② 改"`- path:` 行"。
* **R4-S4（实质，`yes`）**：**AC9 判定① scope 未定义、按交付面全体读必然恒红**——命中含禁令词表本身（`AGENTS.md:114`）、`workflow-design-notes.md:8`、`conflict-hard-stop.md:65`、portable、`dsh/AGENTS.md:62`、以及 `TASK_BRIEF:73` 自己。**恒红项是母本判据本身**；想让变绿须删改判据行，而那会同时触发 AC1/AC10 的红集合 → **AC9① 与 AC1/AC10 互斥**。本轮无任何 AC9① 产物。**Fix**：按 AC4 的先例钉死范围与排除条款（排除判据/禁令原文引用），给可复制命令 + 真实产物。
* **R4-S5（实质，`yes`）**：**AC9 判定②要求的"逐条对应"不存在**——`last_test_run §S`（5 项未做）与 `NOTES §3`（4 笔债）**零交集**，按字面不可满足。**Fix**：改成可判定形态（"每笔未偿债须在产物里有对应句或显式标注 repaid + residual"）。
* **R4-S6（`yes`）**：**AC10 点名 `--numstat`，而该命令不输出变更行**，支撑不了它自己的谓词（"每一条变更行归入某改点"/"单列触及判据的行"）；核心子句本身仍是人对读、无退出码。**Fix**：换成 `git diff --no-index -U0`（或 `--word-diff=porcelain`），产物 = 逐对 diff 全文 + "变更行 → 改点号"对照表。
* **R4-S7（`no`）**：`README:36` 与 `NOTES:62` 的"5 项"未同步为 6 项（两处都不在本轮 delta 内）。
* **R4-S8（`dispute`）**：`install.ps1` 的 `:20-21`/`:76-77` "never touched" 与 `:81` 整树备份矛盾、`:96-97` 的 clause 仍在；而本轮 §3 债 #4 已声明"偿还"。两套归因定义分歧（同问题域被宣布收口 vs 两处未被本 delta 触碰）→ **Reviewer 不自行择一，交人类**。**Fix**：注释与 README 同口径、删 clause。
* **R4-S9（`no`）**：§M 已发现"文档引用的错误码与实际报文不符"但只留了"建议"，三处引用点仍是**未观察到的错误码**；另有一处英文残留。**Fix**：三处改为逐字引用真实报文（或写"预检拒绝、无错误码"）。
* **R4-S10（`yes`）**：§2 #10 说 phase"后三者做了三处归一化"，但 `explore.md` 实测 **2 增 0 删、只有 frontmatter 两行，没有末尾换行变更**。**Fix**：按实测分述。
* **R4-S11（`yes`，低优先）**：AC6 谓词两处脆性——① `$reg` 读**工作树**、`$scope` 读 **HEAD**，工作树脏时可能仍 GREEN；② 两侧 `Sort-Object -Unique` 会静默吞掉重复登记行。**Fix**：加 dirty 检查或把两者锚到同一 SHA；对 `$reg` 做重复检测。

## Test Coverage Gaps

* **AC6 的覆盖粒度是路径级**：Reviewer 独立给出与 9B 相同的纸面反例——**已登记路径内部的内容改动检不出来**（改 `README` 状态块、或改 `dsh/workflow/index.md` 内容而不动任何 `- path:` 行 → `$scope`/`$reg` 不变 → GREEN，登记的 `disposition`/`entry` 失效却无信号）。**Author 的三条负向对照全部只变异"登记表侧"，没有一条变异"文件内容侧"，因此否不掉这个反例。** AC10 本应补这层，但 R4-S6 说它点名的命令给不出变更行。
* 无功能测试套件；AC4 的字面命令 + 退出码产物仍缺（§I 是转述，§M 是另一条更强的对照）。
* `docs/ai/HANDOFF.md` 的 `Current Phase`/`Fix-Loop Counter`/Binding 表仍是第 3 轮视图——按其自己的声明属"恒滞后于 tip"，**不据此判缺陷**。

## Cannot Verify From Diff

* **《第 3 轮 9A 已全量核验 40 行、结论无漂移》这一引用**（`TASK_BRIEF:46`、`last_test_run` §R）：Reviewer **不能打开** `review_9A_r3.md` 核对，只能自己把同样 40 行重读一遍（结论一致），但"9A 说过这句话"本身**未证**。
* 三条负向对照的**逐字控制台输出**（§Q 给的是汇总表）；`install.ps1` 实跑行为；`settings.yaml` 档位生效面；第 3 轮的仓外写入与 `git grep` 回显。

## Verification Needed（7 条）

* **VN-A（上轮 VN2 仍未闭）**：AC4 负向对照的**字面命令 + 退出码**产物（建议与 R4-S4 的 AC9① 判定共用一个脚本）。
* **VN-B（本轮唯一无法从 diff 判定的实质引用）**：请人类打开 `docs/ai/review_9A_r3.md`，确认其中**确有**"对 `AGENTS.md` 全量逐行核验 / 40 行 / 无漂移"这一结论。**若没有**，则 `TASK_BRIEF:46` 与本文的该引用属"把未做的核验写成已做"，须按 AC9 处置。
* **VN-C** 真实 9P 审查轮；**VN-D** headless 完整审查轮；**VN-E** AC8 机器态实跑；**VN-F** `settings.yaml` 的 `reasoningEffort` 是否真被适配器读取；**VN-G** 下一轮任何 `dsh/**` 改动后重新核仓内 vs `~/.dsh`。

## Debt Verdict

**Unpaid**（未偿还，且不得视为"已收敛"）。
* 债 #1（第 4 轮 delta 待重审）：**本轮审查即其 payback 的执行**；但本轮新开 R4-S1–S6/S10（判定方式层）→ 在处置完这些条目、且下一轮确认可执行之前**不得注销**。
* 债 #2/#3：未触碰，**仍欠**。债 #4：接受人类"已偿还"裁决（仅余残余风险），但 `install.ps1` 注释未收窄（R4-S8）。
* **本轮未新增隐藏债**：被禁模糊措辞在 `HANDOFF` 与 `last_test_run` 中**零命中**（Reviewer 实测）；`§3` 四笔与 `TASK_BRIEF`"四笔"计数一致（上轮 S7 已收口）。
* 两份账簿（HANDOFF 的 Remaining Risks 与 NOTES §3）内容不一致——属滞后文件现象，不计债，但下次落账须合并。

## Recommended Next Step（只给建议）

**建议：不合并；按"限制交付"之外的最小路径再跑一次收口轮**，把 11 条里属"判定方式"的 6 条（R4-S1/S2/S3/S4/S5/S6）一次改完——它们全是同一处文本层的机械改写，**不需要新证据**。优先四条：R4-S1（反例指向 §2.3）、R4-S4（AC9① 钉 scope + 排除判据原文）、R4-S5（AC9② 换成可满足谓词）、R4-S6（AC10 用 `-U0`/`--word-diff`），并为其中至少两条补真实产物（退出码 + 完整输出）。

若不打算再开一轮：按 HANDOFF 已给出的合法出路走"限制交付"——在 README 与 HANDOFF 如实写明"已审 tip = `fc32899f`、Blocking = None、残留 11 条 Suggestion（其中 6 条属判定方式层）未处置"，**不得标"已收敛"或 Ready to Commit**。

**给人类的裁决清单（Reviewer 不自行择一）**：㈠ R4-S8 的 `caused_by_last_fix` 归因；㈡ **VN-B 的引用是否属实**；㈢ 是否**逐次批准**再开一轮（若开请人类明示，因为轮次账已达 3/3，本轮为第 4 轮）。
