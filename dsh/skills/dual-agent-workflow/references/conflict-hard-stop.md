---
name: conflict-hard-stop
description: Use when a task has already produced review findings, failed fix attempts, or ledger/log entries that must trigger a stop — deciding whether to keep fixing, whether a Reviewer verdict blocks merge, how to count Fix-Loop rounds, when a stop is mandatory, or how to record [DEBT]/payback and acceptance-criteria findings. Covers the DSH translated verdict taxonomy, the fix-loop hard stop and its three exits vs the merge gate, and the always-on stopping-priority order.
whenToUse: Load when a review round just ended, when a fix failed twice, when a [Product Blocking] or Verification Needed item exists, when a verdict's Debt Verdict field must be decided, or when someone is about to run "one more round".
---

# Conflict, debt, and the hard stop（DSH 版）

> **判据的唯一定义处是 `~/.dsh/workflow/AGENTS.md`**（部署前 = 本仓 `dsh/workflow/AGENTS.md`）。本文件是它的**执行手册**：把它翻成"现在这一步该做什么动作"。两者冲突时以母本为准。
> 本文件不涉及"怎么跑 Reviewer"——那在 `independent-review` 技能里。

## 0. 先判：现在是不是该停

同一时刻可能有多个"该停了"的信号。**按顺序判，命中即按该条处置，不再往下走**：

1. **Critical 正式硬停已触发**（Fix-Loop streak 达阈值 / 双审轮次上限）→ 只走对应那组出路，**一律先停下交人类裁决**：未获人类确认，不得继续编码、不得再审、不得自行选定某条出路。**此时禁止 fresh-context 重启**——它是重新开始的手段，不是绕过硬停的第四条出路。
2. **同一处修复连续两次失败**（两模式恒适用）→ **立即停手、报告人类**（试了什么 / 真实报错原文 / 根因查到哪一步）。**不自动回退、不自动重启、也不在同一回合继续往下查**——把控制权交回人类。调试循环内"一个假设被证伪就换下一个"**不受**此限；触发本条的是**已落地的修复尝试**连续两次失败。
3. ①② 都没命中，或人类已明确说"回退重来" → 才可进入 `/debug` 的 fresh-context 分支。
4. **任何回退之前**：先说明会丢弃哪些未提交改动并等人类确认——不得默默丢弃人类的在途修改。

## 1. verdict 怎么读（分类语义；Reviewer 实际运行时适用）

顶层字段：`## Review Verdict` / `## Blocking Issues` / `## Non-Blocking Suggestions` / `## Test Coverage Gaps` / `## Cannot Verify From Diff` / `## Verification Needed` / `## Debt Verdict`。

* **`Blocking Issues` 只收 `[Product Blocking]`**，每条必须写出**具体后果**：哪个用户操作 / 哪条数据 / 哪个安全边界会出错（已造成或可达都算）。"不能排除""可能有影响"**不是后果**——写不出后果的一律进 `Verification Needed`。含：为过测试而真实弱化 validation·auth·错误处理；diff 里删/跳/弱化了覆盖本任务行为的测试且三处（commit message、HANDOFF Work Log、测试内注释）都没说明、或说明经核实不成立；某条验收点**有具体反例**表明未满足。**缺证据 ≠ 未满足**——缺证据走 Verification Needed。每条由 **Reviewer** 标 `caused_by_last_fix: yes/no/dispute`（**仅 Critical**）。
* **证据缺口不是 blocking**：probe 冒充证据、测试没走真实路径但被测行为本身正确、守护产物字段不全、负向对照覆盖不足、"实际运行未覆盖所称路径"——写进 `Verification Needed`：点名哪条声称 / 由哪份产物支撑 / 缺什么 + **一个能证伪该声称的最小检查**（单个测试 / 单个样本 / 单条 grep；不得列全量套件、整批装置重跑、或同 tip 已有输出的命令）。
* **账本与措辞不一致**（HANDOFF 字段、手写计数、阶段文本、SHA 写法、不涉及未核验产品/AC 行为的纯措辞过度声称）→ `Non-Blocking Suggestions` + Proposed Fix；Author 落账时改正或收窄声称，一句话表态即可。一条发现兼具"路径未实际运行"与"措辞过度"时，**拆成一条 VN + 一条 Suggestion**。
* **`Review Verdict` 语义**：`不通过` ⇔ Blocking 非空；`有条件通过` = Blocking 为 None 且 VN 非空；`通过` = 两者皆空。Process Debt 与 Suggestion 不影响通过。**Reviewer 不得以证据充分性为由判不通过。**
* **`Debt Verdict` 取值**：`Clean` 无债 / `Noted` 未触发 Payback 的普通存量债（不阻止合并，**不得与用户数据错误等价**） / `Deferred` 触发了 Payback 但**已获人类批准延期**（Critical 凭批准的 plan，Routine 凭对话内明确批准） / `Unpaid` 触发了 Payback 且未还、无批准延期——**不进 Blocking、不触发再审**，但 `/final-review` 第 11 条据此不得判"可以提交"，由人类在合并前决定偿还或批准延期。
* **不把 Author 的自我总结当证据**；但 HANDOFF / TASK_BRIEF 中**注明日期、标「人类裁决 / Amendment / 批准」**的条目一律按人类决定对待——不核实过程、不因由 Author 转录而降为自述、不要求它出现在人类 commit；异议只进 Assumption / Requirement-Level Concerns，**不得据此立 blocking**。

## 2. Fix-Loop：计数、判定权、硬停、轮次上限

* **递增（只数 Product）**：某一轮**只要存在至少一个经确认的 `caused_by_last_fix: yes` 的 `[Product Blocking]`**，该轮 streak 计 1。VN 与 Suggestion 不计数。9A/9B 重复发现同一问题**按问题去重**、不重复计数。**9P 的 blocking 发生在实现之前，一律不计入 streak，也不计入 9A/9B 的轮次上限。**
* **判定权与写入**：`caused_by_last_fix` **由 Reviewer 在 verdict 里判定**；Author 只能**逐字转录**进 HANDOFF（附 review 文件/轮次来源），**不得自行判断或改写**。Reviewer 标 `dispute` → 不自动计数、交人类裁决。
* **重置**：某轮没有"修复引入的 Product Blocking"（该轮 0 计）→ streak 归 0。
* **硬门**：streak 连续达 **2** → **立即停止编码**，只能：回退 / 重新拆任务 / 请求人类批准架构升级；**禁止"再试一轮"**。
* **关闭阀**：同一任务的双审达 **3 轮**仍未收敛 → **停止再审**，交人类在「带如实登记的限制交付 / 重新拆任务 / 回退」三者中裁决。人类可明确批准延长，但**延长须逐次批准**，不得默认。
* **优先级（唯一判据）**：① **硬停优先于轮次上限**——streak=2 时只能走硬停的三条出路，不得改走"限制交付"。② **合并门优先于一切出口**——存在**未解决的 `[Product Blocking]`（含任何安全/隐私影响）**时，"带限制交付"**不含合并**：可以停、可以记账、可以移交，**不得合入 main**。③ 只要没过收敛门，一律记 `stopped, NOT converged`，**不得**标 Ready to Commit / 已收敛。"限制交付"的合法含义**仅限**：零未解决 Product Blocking + 剩余 VN 已逐条处置。

> 来历（为什么硬停只数 Product）：2026-08-15 实测三个真实任务后段的 blocking 几乎全是证据类，多轮双审零 `[Product]`，却被记账瑕疵逼到 streak=6/硬停。账本瑕疵与用户数据错误不同级，不应等价计数。

## 3. 最后一轮独立审查门（标"已收敛"要同时成立）

① 最后一轮实际跑过的**每一份 verdict** 的 Blocking 中**无未解决的 `[Product Blocking]`**——"已解决" = 已修复并对该修复再审通过，或 Author `不采纳`（附技术理由）**且人类裁决该项不成立**并记进 HANDOFF Work Log（日期 + 一句话）。verdict 词本身不是门。减档只跑 9A 时 9B 记 `N/A + 减档原因`。
② 该轮**全部 VN 已逐条处置**：Author 代跑、真实输出与退出码追加进 `last_test_run.txt`，或以技术理由「不采纳」；每条在 `/final-review` 的 Manual Check Before Commit 占一行（命令 → 退出码 → 一句话判定"产品缺陷 是/否"）。退出码非 0、装置判 NOT PROVEN 的条目**不得省略**。
③ 当前 review-sensitive 内容 == `review_tip_sha`（内容比对）。**例外（不使审查失效）**：(a) 审后仅新增独立测试用例文件（`test_*` / `*.spec.*` / `*.test.*`）且不删不改既有断言——**不含** conftest / fixtures / 测试与 runner 配置 / setup 文件；此时 `tested_sha` 须回炉到含该 delta 的新 commit；(b) 只改 `docs/ai/` 非验收文档；(c) 验收条款修订出自人类裁决且未改生产代码；(d) `docs/ai/QUALITY_GATES.md` 审后有改动 → 不自动失效，但 `/final-review` 把该 diff 原样列进 Manual Check，由人类决定是否再审（删行 = 删闸门）。凡改了生产源码、迁移/schema、构建配置与依赖、删/改既有测试或测试基础设施、或 Author 自行改验收条款 → **须对该 delta 再审**（人类可减档只跑 9A）。

**人类因成本叫停 ≠ 质量通过**：存在未解决 Product Blocking、或有未经审查的生产改动 → 记 `stopped, NOT converged`。

## 4. No-Hidden-Debt 与 Payback-on-Touch

任何"先让它跑起来/省点时间"的妥协（简化、硬编码、跳过边界、临时绕过）只有两条合法出口：

* (a) **当场修**；或
* (b) **登记**——**Critical**：当前任务 `docs/ai/HANDOFF.md` 的 "Remaining Risks" 里一行，格式：

```
[DEBT] <一句话描述> | Payback trigger: <哪个文件/模块，下次被触碰时必须先偿还> | Impact: <不还会怎样>
```

**Routine**（无 HANDOFF）：停下把妥协摆到对话里——人类要么批准当场修，要么把任务升级为 Critical（在那里拿到它的 `[DEBT]` 行）。**没有第三条静默通道。**

被禁的模糊措辞（出现即 = 未登记债务，Reviewer 把它们与其掩盖的妥协列进 Non-Blocking Suggestions，Author 合并前登记或删除；**不构成 blocking**）：
`later / temporary / for now / should be fine / probably ok / 暂时 / 先这样 / 回头再说 / 一个没有偿还触发器的 TODO 或 known-issue`。

（代码里普通 TODO 仍按全局规则进 plan/TODO 文档，不进这个债务账；但**一个实际掩盖妥协的代码 TODO 同时必须登记成 [DEBT] 行**。）

**Payback-on-Touch（唯一强制偿还机制，优先于任何 due date；两模式恒适用）**：改一个文件/模块之前，先扫项目现有的债务账——**Critical**：当前 `docs/ai/HANDOFF.md` + `docs/ai/archive/**/HANDOFF.md` 的 "Remaining Risks / Debt"；**Routine**：没有活跃 HANDOFF，但 `docs/ai/archive/**/HANDOFF.md` 里的债**照样绑人**。`[DEBT]` 的 Payback trigger 必须点名具体文件/模块路径或 glob。**trigger 命中你正要碰的文件/模块 → 同一个 commit 内先偿还**（或显式申请降级/延期：**Critical** 在批准的计划里写明理由；**Routine** 在对话里说明理由且只在人类明确批准后继续）；否则这次改动**不得提交**。债不跟着清单走——它跟着代码，下次你碰到它时找到你。

## 5. 验收条款与守护声称（落 findings 时的判据）

* **AC 判定方式必须同时满足**：① 可复现（换个人、换一轮、同一步骤同一结论）；② 有区分力（存在一个"若该性质不成立则判定会失败"的对照）。命令 + 退出码是首选形态，但**命令形态本身不等于合格**（永远返回 0 的脚本、只检查字段存在的扫描都满足形态而无区分力）。
* **不能可靠自动化的产品/安全/合规性质仍可作 AC 并阻止合并**，但必须写成明确的人类判定步骤：判定人、固定判定输入、逐条判据、以及"什么情况判不通过"的反例。**反例必须实际触发失败，不接受纸面反例**（自动化的记退出码；人工的记判定人 + 结论 + 时间）。判定人有分歧 → 交人类裁决。
* **不合格的是"无判据的散文对读"**：判定方式写成"Reviewer 逐条核对 / 对照两表核 / 核清单完整性"而不给判据与反例的，**不是验收条款**——降级为 Non-Blocking Suggestion 或移交清单条目，**不得阻止收敛**。
* **声称不得超出判定实际覆盖的范围** → Author 落账时把声称收窄到已覆盖范围或撤回并报告风险（**不构成 blocking**）。
* **负向对照适用于一切"机制 X 会拒绝 Y"的声称**（构建配置、lint 规则、类型检查、CI 门禁、扫描器……）：样本必须"**若移除 X 则会通过**"，且**覆盖声称主张的全部等价类**（一个合格样本只证明该类）；等价类必须**枚举自一个人类批准并冻结的输入域**。**Reviewer 主张"还有一类未覆盖"时必须给出该域内的具体反例**——给得出 → VN 交 Author 代跑；**给不出 → Non-Blocking Suggestion，不阻止收敛**。域本身要扩大 = 验收变更，走人类批准，不在本轮 fix-loop 内解决。

> 实证（2026-08-15）：某项目声称 `tsconfig` 的 `"types": []` 能拒绝 Node 内置模块导入。七个探针里**五个本该被拒的全部通过**（含最朴素的 `import 'node:fs'`）——此前"验证通过"的样本要么是环境全局（移除该配置也照样被拒），要么是未安装的包（拒绝原因是解析不到）。**每个通过的样本，就算机制完全不存在也会照样通过。**

## 6. review-fix 的最小生产范围

Critical 的 review-fix 由 **Author 在双审窗口结束后**执行（Reviewer 不改代码），两模式下都**只允许改当前 blocking 所需的最小生产范围**。要新增模块 / 改公共接口 / 扩大架构 → **停止并重新计划**（走 `/plan`），不在 fix 循环里做。

## 7. 落账模板（Author 用，逐字转录，不改写）

```markdown
## Review & Test Binding
review_base_sha: <base>
review_tip_sha: <tip>
tested_sha: <tip 或回炉后的新 commit>
handoff_snapshot_sha: <双审窗口开启时的 HEAD>
review_verdict_9A: <verdict 词>            # 减档时: N/A — 人类减档，原因: …
review_verdict_9B: <verdict 词>
plan_review_9P: <Plan Verdict 词> + <docs/ai/review_9P.md 指针>   # 只记状态，不复述内容
review_sensitive_paths:
  - <pathspec…>

## Fix-Loop Counter
round: <n>   streak: <n>   caused_by_last_fix(yes): <逐字转录，来自 verdict>
outgoing: <0 或 streak 值>   硬停: <未触发 / 已触发 + 人类裁决>

## Work Log
<日期> 9A/9B verdict 收到；逐条表态（采纳 / 修改后采纳 / 不采纳 + 理由）；VN 代跑结果指针
<日期> 人类裁决：<一句话>（如有）
```

**两条硬约束**：`caused_by_last_fix` 只能逐字转录（Reviewer 判、Author 抄）；VN 的代跑输出**追加**进 `last_test_run.txt`（不覆盖），或在 Work Log 记「不采纳 + 技术理由」。
