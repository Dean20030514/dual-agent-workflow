# 9A verdict（第 6 轮）— dsh-landing review

> **来源与保真度声明**：Reviewer 把 verdict 作为 **agent 返回正文**交回；本文件由 **Author 在双审窗口结束后转录**，非 Reviewer 手写原始 artifact。
> 审查对象：`review_base_sha = 578ad39` → `review_tip_sha = 1d5f3a9`

## 证据首行（隔离五项通过）

```
observed_head_sha: 1d5f3a9b948b9cbd119e51801f658db5e50007eb   （== review_tip_sha == handoff_snapshot_sha）
worktree_clean: yes    （git status --porcelain 空；--ignored 亦空；探测前后各核一次）
read_handoff_from: 工作树（未用 git show tip）
writes_performed: none
model_route: deepseek-official/deepseek-flash@high（自报值；会话内无法独立验证 provider/effort 两项）
覆盖核验：git diff --name-only 578ad39..1d5f3a9（未过滤）→ 4 个文件，全在 docs/ai，无清单外文件、无遗漏
覆盖缺口：dsh/**、portable/**、install.ps1、README.md、docs/ai/AUTHORITY_CONTRACT.md（本轮 diff 未触及）
```

**实跑的两个门（只读）**：
```
AC6（TASK_BRIEF §AC6 内嵌命令逐字）→ reg=31 scope=31 → AC6: register == scope (exit 0)
AC4（pwsh -File tools/ac4-reasoning-effort-check.ps1）→ DSH-side values = high / out-of-domain = (none)
                                                        / adapter medium hits = 0 → AC4: PASS (exit 0)
```

## Review Verdict

**不通过 —— 1 条 `[Product Blocking]`，`caused_by_last_fix: dispute`。**

### 四条正面确认（Reviewer 独立复核）

1. **B-1 已确认闭合（机械可验）**：`§2.1 #25` 与 `§2.3 - path: tools/ac4-reasoning-effort-check.ps1` 都在；AC6 的 scope 路径串含 `tools`；实跑 `reg=31 scope=31 exit 0`；AC4 `PASS exit 0`。**第 5 轮"门绿而登记不全"的洞在 tip 上不存在。**
2. **订正①到位**：`.tmp-r6.ps1` 已不在 tip 树；工作树干净，9B 上轮拒审的触发条件已消失。
3. **订正③准确**：关于"AC6 路径级 → 已登记路径内部修改零信号 → 第二道门无机械完整性保护、只能人工读 diff → 已记 `[DEBT]`"的新表述**与谓词实际语义一致，无残留过度声称**；DEBT 已落到 `HANDOFF`。
4. **Reviewer 撤回自己上一轮的表述**：第 5 轮 9A 写的"**大写即可走 PASS**"**不成立**。实测：
   ```
   reasoning_effort: high     → captured='high'  → PASS
   reasoning_effort: HIGH     → captured='HIGH'  → FAIL（更严，不逃逸）
   reasoningEffort: medium    → captured=''      → 静默逃逸（真逃逸）
   reasoning_effort: `medium` → captured=''      → 静默逃逸（真逃逸）
   ```
   Reviewer 明确写"9B 的判断正确，我确认并撤回原表述"。

## Blocking Issues

### PB-1 · `HANDOFF.md:65` 的"合并门"条目在 tip 上是假的，且与同一页相隔两行的记录直接矛盾

* **证据**：`:61-63`（本轮新写）写 `streak（当前连续计数）: 2 —— 硬停已触发`、`第 5 轮 9A 单审结论：不通过（3 条 Product Blocking）`、`B-1 归因 yes → streak 由 1 增至 2`；而 `:65`（上一轮遗留、未同步）写 `**合并门：现为 OPEN 的候选**——第 5 轮未新增 Product Blocking…`。另有两处反例可核：`last_test_run.txt` §AC 记载第 5 轮 3 条 Product Blocking；`HANDOFF` 现有 6 笔 `[DEBT]`（不是"两份"）。
* **具体后果**：`HANDOFF` 的 Fix-Loop/合并门块是"能否合入 main"这条硬规则的唯一人类读点。按该行重建状态的人会得到"第 5 轮 Product Blocking = 0、合并门只是等 verdict 的候选"→ 在本轮两份 verdict 交付之后**误判合并门已可打开**，而实际是 streak=2 硬停 + 3 条未解决 Product Blocking。**这是"验收边界账目被反向写宽"，不是无关措辞。**
* **归因 `dispute`**：定义 A（本轮最后一次修引入）= `no`（该行在 base 已存在且本轮未改）；定义 B（本轮未闭合"账本不实内容"这一类）= `yes`。按契约 `dispute` **不自动计数**、交人类裁决；但按 `AGENTS.md:224②`，在被裁定为 Suggestion 级之前**合并门维持关闭**。
* **Author 处置：已当场修**（改成"合并门：关闭"并与 `:61-63` 一致、债笔数改为 6）。

## Non-Blocking Suggestions（8 条）

| # | 要点 | Author 处置 |
|---|---|---|
| S1 | §AH 仍写"反引号/散文/**大写**即可走 PASS"——"大写"已被实测否掉，而真逃逸形态**驼峰键**反倒没写进去；与 `HANDOFF` 的 `[DEBT]` 互斥 | **已修**：§AH 按实测重写，`§AC` 转录行加订正指针 |
| S2 | AC6 的产物指针称 §AG 含"把登记名改错 → 必红"，但 §AG 实有只有 NC-A / NC-B | **已修**：指针改为 §AG 实有的 NC-A |
| S3 | `tools` 入 scope 把 H5A 封存档也纳入门禁面 | **已修**：写明"落在 pathspec 内但不属交付面、不是门禁、本 AC 不执行测试" |
| S4 | 债台账两份且不一致（`HANDOFF` 6 笔 vs `NOTES` 4 笔） | **已修**：`HANDOFF` 为唯一权威，`NOTES §3` 改为指针 + 计数 |
| S5 | 订正②的根因归因不成立（两份被提交的临时脚本里都没有 `Remove-Item`，而都含 `git add -A`；r6 那份自身被扫入是必然） | **已修**：教训改为有证据的两条（一次性脚本不落仓内 / 不用 `git add -A`） |
| S6 | 被撤回的声称仍留在**不可改的 commit message**（`f7d88e9`）里 | **已修**：在 §AG 加一句指认该 commit message，以订正为准 |
| S7 | 两处状态条目滞后（"解答 VN-B" 已解答；`Open Questions` 仍写 None 而实有 3 个岔口） | **已修** |
| S8 | 第 6 轮 9B 的账目口径自相矛盾（写"拒审、无 verdict"，却以"第 6 轮 9B 的 R6-*"为依据） | **已修**：`HANDOFF` 待裁决节列明该混用**须人类确认** |

## Test Coverage Gaps

* **AC4-门**：声明输入域内 `reasoning[_ ]?[Ee]ffort` 键提及共 **23 处**（snake_case 20 + 驼峰 3），脚本正则只命中 **7 处**；3 处驼峰站点零覆盖。已按人类裁决不修并记 `[DEBT]`——Reviewer **不重复计为 Blocking**。
* **AC6**：只有路径级区分力（已收窄声称，本轮再次被 NC-B 输出证实）。
* **账本自洽无任何机械检查**：`HANDOFF` ↔ `TASK_BRIEF` ↔ `NOTES` ↔ `last_test_run` 之间的计数/状态一致性无门无对照；本轮 PB-1 与 S1/S2/S4/S7 **全部落在这个盲区**。这解释了六轮 finding 100% 落在同一层的结构原因。
* Reviewer 依母本"**任何新增流程/规则/登记表/检查项默认「不」**"，**不建议**为此新增判据或门。

## Cannot Verify From Diff

* 第 6 轮 9B `worktree_clean: no` 的确切所指（已提交的 `.tmp-r6.ps1` 是**跟踪文件**，不会出现在 `git status --porcelain` 中，故"提交了临时脚本 → worktree_clean: no"这条因果链**在纸面上并不闭合**——更可能是当时另有未跟踪残留，或 9B 对"树内残留"做了扩展读法）。
* `.tmp-r6.ps1` 的删除命令原文（删除发生在仓外 shell，"用了位置参数"这一归因无 artifact 可核）。
* 9A 第 5 轮 verdict 原文（按契约不得打开）。

## Verification Needed

* **VN-1**：补跑"把 `tools/...` 的 §2.3 登记**名**改错 → 必红"这一对照，或把指针改成 §AG 实有的 NC-A。**（已按后者处置）**
* **VN-2**：逐字引证第 6 轮 9B 的拒审行与 R6-B3/R6-S1 的出处、是否携带 verdict、该轮是否计入轮次。**（已落 `review_9B_r6.md`，并在 `HANDOFF` 待裁决节列为须人类确认项）**
* **VN-3**：改完账目后重跑两个门并落盘。**（已做：`AC4: PASS` / `AC6: reg=31 scope=31`）**
* **VN-4（可选）**：在 `tools/validate/` 下新增未登记路径 → AC6 应报 `$missing`（确认封存档纳入 scope 不产生假绿）。**（未做）**

## Debt Verdict

* 本轮新增两笔 `[DEBT]`（AC4 实现自身无机械完整性保护；AC4 正则只覆盖"未加引号小写"形态）**格式与内容合规**：均有 Payback trigger 与 Impact；对 `later / temporary / for now / 暂时 / 先这样 / 回头再说 / TODO` 在被改的三个账目文件里做了**零命中扫描**，**无被禁措辞**；逃逸形态清单与 Reviewer 实测一致（R6-S1 准确）。
* 第 3 轮 9B-B1 那笔已实质闭合、标"保留为历史记录"是正当的历史保留，**不是暗债**。
* **但**：① 两笔只在 `HANDOFF` 登记、`NOTES §3` 未镜像 → 台账不唯一（S4）；② `last_test_run.txt` 的 §AH 与 `[DEBT]` 曾互斥（S1）。**两条均已在 Author 侧处置**。
* **结论：本轮无新增暗债。**

## 账本层能否收口

**直接结论：现在不能收口；但不是因为又出现了产品级缺陷，而是因为 tip 上仍留有 1 条可核查的不实条目 + 3 条同族的不一致，且四条都是一行级修复。**

理由（Reviewer 自己的判断）：
1. **可以确认的部分**：B-1 真闭合（实跑 `reg=31 scope=31 exit 0`）；两个机械门在 tip 上都实跑绿；交付物本体（`dsh/`、`portable/`、`install.ps1` DSH 段、部署登记）本轮 diff **一个字都没动**。
2. **挡住收口的**：PB-1（合并门条目）；S1（逃逸面列表）；S2（产物指针指向不存在的对照）；S4（债台账两份不一致）。**四条共性**：都不是"实现错了"，而是"账目对自己的描述与事实不符"。
3. **为什么给"不能收口"而不是再判一条产品级洞**：拒收依据必须是"有具体反例表明验收点未满足"，而它能给出的反例**全部指向账目文本自身**——**没有任何证据表明 `dsh/**` 的判据有漂移、两个门失效、或交付物有缺陷**。故把唯一的 Product 归到"合并门这一安全边界的账目被反向写宽"上（后果可写、可达性不确定 → 按 `AGENTS.md` 记 Product 交人类裁决）。
4. **收口的可操作判据（Reviewer 建议人类采用）**：① 零可核查的不实条目（PB-1 + S1 + S2 全修）；② 两个门实跑绿且正例数值与文本一致；③ 债与未验证清单单一来源、计数自洽。**三条同时成立即可宣布账本层收口，不需要新增任何判据/门/登记表**；并明确写：**这三条修完后不必再审一轮**（全是一行级文本改动），是否复跑审查由人类定。
5. **与硬停的关系**：PB-1 标 `dispute` → **不自动递增 streak**，请人类连同第 4 轮那条遗留 `dispute` 一并裁定；裁定前合并门继续关闭。**若人类裁定本条为 Suggestion 级，则本轮 Blocking = None，账本层按第 4 点即可收口。**

## Author 对第 4 点三条判据的完成情况（供人类核，不替代 Reviewer 判断）

| 判据 | 状态 |
|---|---|
| ① 零可核查的不实条目 | **已达成**（PB-1 + S1 + S2 全修，commit `1b88cdb`） |
| ② 两个门实跑绿且文本数值一致 | **已达成**（`AC4: PASS` / `AC6: reg=31 scope=31 missing=0 stale=0`） |
| ③ 债与未验证清单单一来源、计数自洽 | **已达成**（`HANDOFF` 为唯一权威；`NOTES §3` 改为指针 + 6 笔计数；`NOTES §5` 与 `TASK_BRIEF` AC11 六项逐条一致） |
