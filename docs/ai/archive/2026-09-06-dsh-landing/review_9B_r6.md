# 9B verdict（第 6 轮）— dsh-landing review

> **来源与保真度声明**：Reviewer 把 verdict 作为 **agent 返回正文**交回；本文件由 **Author 在双审窗口结束后转录**，非 Reviewer 手写原始 artifact。
> 审查对象：`review_base_sha = 578ad39` → `review_tip_sha = f7d88e9`

## Review Verdict

**拒审（快照不一致）** —— **本轮不产生有效 9B verdict**，Reviewer 明确不给出"通过/不通过"。

## 证据首行

```
writes_performed: none
observed_head_sha: f7d88e9e3c8473ae1c587795f3859a4c4128c448   （== handoff_snapshot_sha ✅）
worktree_clean: NO
read_handoff_from: 工作树
model_route: deepseek-official/deepseek-flash@high（自报值；Reviewer 如实说明它看不到实际 provider/effort 两项）
覆盖缺口: .tmp-r6.ps1
```

**自检实测（Reviewer 原样给出）**：
```
$ git status --porcelain
 D .tmp-r6.ps1        → 非空
$ git status --porcelain --ignored
 D .tmp-r6.ps1        → 非空
```

**拒审依据**（Reviewer 逐字引用交付面自身的契约）：`dsh/workflow/reviewer-prompt.md:157` / `:198` ——「**HEAD 不符或工作树不净 → 在审查正文前报告「快照不一致」（写明失败项与实际观察值）并拒审。**」

**Author 注（责任归属）**：检出的直接原因（`.tmp-r6.ps1` 未落账）由 **Author** 造成——删除时 `Remove-Item` 传了位置参数而非 `-LiteralPath`，静默失败，随后 `git add -A` 将其一并提交。9B 的拒审是**正确的**，且它顺带证明了这套快照门在 DSH 下真的会拦住东西（首轮起从未被实际触发过）。

## 即便拒审，Reviewer 仍如实登记了三组事实（均锚在 tip commit 上，与工作树脏污无关）

> Reviewer 声明："这些事实全部锚在 tip commit 上、与工作树脏污无关；我用确定性只读命令独立复跑过。**我不替人类把它们计入 streak——本轮无 verdict，计数应为 N/A(0)。**"

### R6-B1 · 一次性脚本进了规范事实源，且同一 commit 里的账目声称被该 commit 自身推翻
* `git ls-tree f7d88e9 .tmp-r6.ps1` → blob `d8a9747`；同一 commit 的 `last_test_run.txt:527` 断言"临时 `.tmp-*.ps1` **均已清**" → **该声称被承载它的那个 commit 直接证伪**。
* 后果：该脚本可执行、内容含 `Add-Content` 向证据文件追加**已过期的第 6 轮叙事**，随后 `git add -A` + commit；仓库无 `.gitignore`（实测 `Test-Path .gitignore` = false）。
* 归类：`[Product Blocking]`（与第 5 轮触发硬停的 B-1 同类、同一文件复发）；`caused_by_last_fix: yes`。
* **Author 处置：已当场修**（`git rm` + 订正该句 + 修 streak 计数，commit `1d5f3a9`）。

### R6-B2 · HANDOFF 的 Fix-Loop 计数自相矛盾：同文件同时写"当前 = 1"与"streak = 2 → 硬停"
* `F7d88e9` 新增了把 streak 记到 2 的行，而"streak（当前连续计数）: 1"那一行是上下文行、未被触碰。
* 后果：Fix-Loop 计数器是决定"是否必须停手并请示人类"的**机械状态位**；读到 1 会走错误分支。
* 归类：`[Product Blocking]`；`caused_by_last_fix: yes`。**Author 处置：已当场修**。

### R6-B3 · "防削弱"的声称被 Author 自己的负向对照证伪（**最重的一条**）
* Author 在 `last_test_run.txt` §AG 写过"两条对照合起来证明：**削弱第二道门现在至少会进账**"。
* Reviewer 用**同一段输出**反驳：NC-B 自己打印的是 `AC6 差异项 = 0 → GREEN`。AC6 是**路径级**谓词；`tools/ac4-reasoning-effort-check.ps1` 一旦登记，其任何内容修改都同时出现在 `$scope` 与 `$reg` 里 → **双门全绿、零账目信号**。修复**前后**对同一次修改的 AC6 输出完全相同。
* 后果：一个把 `$bad` 检查改成无条件 `exit 0`、或把正则收窄到只匹配 1 个站点的改动，将在**双门全绿**下进入交付面。
* 归类：`[Product Blocking]`（边界项；Reviewer 说明若沿用第 5 轮 B-1 的同一标准则应升为 Product）；`caused_by_last_fix: yes`。
* **Author 处置：已当场修**——把该段改成"AC6 买到的是『`tools/` 下新出现未登记路径会判红』，**不是**防削弱；已登记路径的内部修改零信号，只能靠人工读 diff"，并登记为 `[DEBT]`（`HANDOFF` 第 5 笔）。

## Non-Blocking Suggestions（5 条，均已被 Author 采纳处置）

* **R6-S1**：B-2 为真但 9A 的表述不准——**"大写即可走 PASS"不成立**（`Select-String` 默认不区分大小写，大写只会造成假红）；真逃逸形态是**驼峰键 `reasoningEffort: <v>`** 与**反引号包裹的值**；且**当前无活的假绿**（域内无域外取值）。**已采纳**：§AH 与 `[DEBT]` 按实测重写，并给 9A 的原文加了订正指针。
* **R6-S2**：`tools` 入 scope 把 **H5A 封存档 `tools/validate/**`** 也拉进门禁面（项目 `AGENTS.md` 明令"非门禁、勿续建、勿修"，其 Pester 对当前 main **预期失败**）。**已采纳**：在 AC6 条目里写明"它落在 pathspec 内但不属交付面、不是门禁，且本 AC 不执行任何测试"。
* **R6-S3**：`HANDOFF` 的 `review_sensitive_paths` 不含 `tools`，与 AC6 scope 及本轮 prompt 不一致。**已记入待办**（未改：属 `review_sensitive_paths` 变更，按契约其本身是 review-sensitive，须在下一轮以 `[O]`/`[M]` 口径统一）。
* **R6-S4**：两条既有债条目与"关闭阀状态"互相矛盾；"两份 Debt"无法对应到任何两份。**已采纳**：债台账统一（`HANDOFF` 为唯一权威、`NOTES §3` 改为指针 + 计数）。
* **R6-S5**：AC4 脚本硬编码仓库路径与 npx 缓存路径，不可在他机/他缓存复现。**未修**（记入待办）。

## Test Coverage Gaps（Reviewer 给出，Author 如实转录）

1. **AC4 的负向对照全部避开了真正的逃逸形态**——已跑的对照（§R、§AG NC-B）都是朴素形态，而真逃逸是驼峰键与反引号值。
2. **AC6 的负向对照全部作用在 register 侧**，没有一条作用在 (a) 新增 scope 外文件、(b) 修改已登记路径内容 → "路径级上限"与"防削弱声称"之间的落差结构上无法暴露（R6-B3 就是这么漏掉的）。
3. **仓库根一次性脚本无任何面覆盖**（`.tmp-r6.ps1` 不在 `review_sensitive_paths`、不在 AC6 scope、不在 §2.3 登记表）——这是 R6-B1 得以发生的直接条件。

## Verification Needed（Reviewer 提出，择要）

`git rm .tmp-r6.ps1` + 单独 commit（**已做**）；订正假声称（**已做**）；订正 streak 计数（**已做**）；补驼峰键/反引号两类负向对照（**未做，按人类裁决留待 B-2 方向确定**）；把 `tools` 同步进 `review_sensitive_paths`（**未做**）；订正"防削弱"理由并按 No-Hidden-Debt 记债（**已做**）。

## Debt Verdict

**Unpaid**，且本轮新增两笔（R6-D1：`.tmp-r6.ps1` 进 tip；R6-D2：Fix-Loop 计数不一致）。**Author 注**：这两笔所指缺陷均已当场修，但 Reviewer 是在 tip `f7d88e9` 上判的，故其结论在该 tip 上成立——**这一点不因后续修复而改变**。

## Requirement-Level Concerns（4 条，Author 认为第 1、3 条最有价值）

1. **AC9 的现行判定读不到本轮这类缺陷**：AC9 的判定点收窄为"人工单点读 `HANDOFF` 的 Known Issues / Remaining Risks 与 `NOTES §5`"，**`last_test_run.txt` 不在读点内**——而第 5 轮的 B-1 假声称与本轮的 R6-B1 假声称**都发生在这个文件里**。收了「如实标注」这条 AC，却把最常出现不实声称的文件排除在判定面之外，这是同一缺陷类得以原样复发的**结构原因**。
2. **AC6 把一条可满足的声称与一条不可满足的声称写在同一节里**：「路径级覆盖」可满足（实测 GREEN）；同节的「防篡改」声称路径级谓词原理上交付不了。**验收条款不该同时声称两件强度不同的事。**
3. **"收口"目前没有冻结的定义**（`HANDOFF` 逐字写着"任务 B 的交付边界先不定"）→ 没有边界就没有"未满足"的判据，任何"可收口/不可收口"的结论都会退化回自由文本判据。**人类若要本例判定可复现，必须先冻结任务 B 的交付边界。**
4. **B-2 的处置方向会改变 AC4 的类型**：加宽正则 → 仍是 `[M]`；收窄声称 → 退化为近似 `[O]`。**合并前必须定**，否则 `[M]` 标记本身即不实标注。

## Reviewer 对"账本层能否收口"的结论

**不能收口。** 其六条理由：① 账本层在 tip 上仍有可核查的不实内容（R6-B1，且是该类在同一文件里的第 2 次出现）；② 账本自我计数不可信（R6-B2 以及两处债台账不一致）；③ 修复理由本身不成立（R6-B3）；④ 第二个机械门仍未覆盖它声称的域（B-2，且真逃逸形态比 9A 的描述更接近本仓实际写法）；⑤ 交付边界尚未冻结；⑥ **本轮连自己的快照门都没守住**。

**并给出"可收口"的样子**（供人类冻结边界时参考）：① tip 上 `git status --porcelain` 为空；② `last_test_run` / `HANDOFF` / `TASK_BRIEF` / `NOTES` 四者之间**无相互矛盾的事实陈述**（streak、债计数、scope、`review_sensitive_paths` 各只有一份定义）；③ 每个 `[M]` 门的能力声称与其谓词实际能力一致；④ 剩余项可逐条归入 `[U]`（有触发时机、未被写成"已验证"）或 `[DEBT]`（有 Payback trigger），且计数一致。**当前状态在 ①②③ 上均不满足。**

**对拆法的直接回应（Reviewer 原话要点）**：不反对拆法，但指出本轮为修 B-1 所动的东西**全部落在任务 B**（登记表、AC6 的 scope 与理由文本、取证叙事、HANDOFF 计数）——即"先只修 B-1"这个决定，结果是**又给任务 B 加了 2 条新账**，而不是让它更接近收口。这与 `HANDOFF` 自己记录的模式（五轮 finding 100% 落在该层）完全一致。
