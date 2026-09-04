# AGENTS.md

> 本文件是项目长期规则与**禁止事项的唯一出处**，以及全流程所有重复硬规则（Reviewer 轻量协议、`[DEBT]` 格式、证据/假设标签）的**单一定义处**。其他文件和 prompt 只引用本文件，不再罗列，引用写法："Follow the Safety Rules in AGENTS.md" / "Follow the Reviewer-Lightweight Protocol in AGENTS.md"。
> 已存在则先读再增量更新，永不覆盖重写。

## Mode Scope（2026-08-05 裁决；**两模式恒适用**——本节定义路由本身）

> 路由定义唯一出处：全局 `CLAUDE.md` → Mode Routing。默认 **Routine**；**Critical** 仅人类明确启用。

* **两种模式恒适用**：Safety Rules、真实执行证据（真实命令 / 完整输出 / 退出码）、**单轮任务 diff 预算**、No-Hidden-Debt / `[DEBT]` 红线、**Payback-on-Touch**、**证据 vs 假设标签**、**停止事件优先级**。
  > 本清单列的是**跨全流程的红线**，**不是全文规则的完整目录**。其余各节的模式适用**以该节自身的标注为准**——**每个具有模式适用性的规则节**，标题都写明「仅 Critical」/「两模式恒适用」/「Reviewer 实际运行时适用」/「按模式取」；**`Project Overview` 这类项目事实模板不是规则节，不要求标注**。**不存在「未标注即恒适用」这条默认规则**：漏标是缺陷，按缺陷修，不得据此反推作用域。
* **仅 Critical 适用**：TASK_BRIEF / IMPLEMENTATION_PLAN / HANDOFF 交接文件、`docs/ai/last_test_run.txt` 持久化、SHA 绑定、任务分支与阶段 commit（Git Discipline）、Reviewer 与双审协议（AI Collaboration Rules 及各审查相关节）。
* **Reviewer 零写入**：只要有 Reviewer 实际运行——任何模式——零写入规则恒适用。
* **「Routine + 临时 Reviewer」是合法状态，且不构成模式升级**：人类可以在不启用 Critical 的前提下临时要求跑一次独立审查。此时继承零写入 + Reviewer-Lightweight Protocol **第一层**（资源纪律），并按**第二层**取 **Routine 证据载体**；**不继承 Critical 账本**——不产生 HANDOFF / `last_test_run.txt` / SHA 绑定 / Fix-Loop 账本，**也不得为审查临时创建它们**。要这些账本 → 由人类明确启用 Critical。

## Project Overview

项目是什么、技术栈、主要目录。[填写]

## Build / Test / Lint Commands（**两模式恒适用**）

只列项目中真实存在的命令，不存在的不要编造。[填写]

## Code Style Rules（**两模式恒适用**）

命名规则、目录结构、格式化工具、测试习惯、错误处理方式。[填写]

## Safety Rules（**两模式恒适用**）

* Do not remove or skip tests to make them pass.
* Do not comment out core logic to bypass errors.
* Do not bypass validation, authentication, or error handling.
* Do not introduce new dependencies unless explicitly approved by the human — via the approved plan in Critical, or explicit in-conversation approval in Routine.
* Do not do unrelated refactors. Keep changes minimal and task-scoped. (Scoping only — this constrains touching *unrelated* code, NOT which approach you pick: select the minimal sufficient, long-term-correct approach per CLAUDE.md → Decision Making, then keep the diff scoped to it. "Minimal" ≠ pick the smallest/laziest solution.)
* Respect the per-task diff budget — threshold, counting method and over-budget handling are defined once in 单轮任务 diff 预算 below; never quietly finish an oversized task.
* Do not modify lockfiles unless dependencies actually changed.
* Do not commit secrets, tokens, or API keys.
* Do not claim tests passed without real execution evidence — Routine: show the real command, full output, and exit code in conversation; Critical: write actual output to docs/ai/last_test_run.txt.
* Do not state uncertain conclusions as certain.
* Do not perform destructive operations without stating the risk first.
* Never edit the Human Approval Status field in IMPLEMENTATION_PLAN.md.

## 单轮任务 diff 预算（唯一定义处；**两模式恒适用**）

**单轮任务的 diff 尽量不超过 4000 行——只计生产面**：`docs/ai/` **之外**的全部改动（生产源码、测试、迁移/schema、构建配置与依赖声明等），增删合计。**`docs/ai/**` 一律不计**（交接文件、验收、`last_test_run.txt`、review verdict、守护产物、截图）。证据面不设行数上限，但仍受各产物自身「简短、指向 git log 与产物」的要求约束。计法按模式取：

* **Critical**：`git diff --shortstat <base>..<tip> -- . ':(exclude)docs/ai/**'`（任务分支相对 base）。
* **Routine**：`git diff --shortstat HEAD -- . ':(exclude)docs/ai/**'`（本次未提交改动；`docs/ai/` 之外有新增未跟踪文件时加上其行数）——Routine 不建任务分支、不由 Agent commit，所以计的是"交给人类扫的那一坨"。

* **规划时**：按此切片。切不到 4000 行以内 → 写明理由并请人类批准整体推进（**Critical** 写进计划；**Routine** 在对话里说明）——同「架构层拆分评估」的处理方式，**不按行数机械拒绝**。
* **实现中**：发现将要超出 → **停下报告人类**，由人类决定拆分、缩范围或批准超限；不得默默做完再交一个超大 diff。
* **超限时**：先去掉无关改动与顺手重构，再与人类商量缩范围或拆片；**不得为凑预算删减或弱化测试**。证据面不计预算，因此不存在"砍证据凑预算"这个选项。

> **来历**：2026-08-15 实测三个真实项目的当轮任务 diff 分别为 4556 / 5738 / 2820 行，**全部以 `stopped, NOT converged` 或硬停收场**，其中 `docs/ai` 证据面占 74% / 42% / 41%，后段审查轮的 blocking 几乎全是 `[Verification]`（该类 2026-09-03 已删）——当时定 2000 行**含**证据面；2026-08-27 因 per-task 交接产物常占六七百行上调到 4000；**2026-09-04 人类裁决改为只计生产面**：预算的本意是约束一次交付的生产面大小，含证据面计数时每一切片的实际内容被挤得极小。证据膨胀的病根已由 2026-09-03 删除 `[Verification Blocking]` 类处理，不再靠预算约束。

## 停止事件优先级（唯一定义处；**两模式恒适用**。`/debug`、`/final-review` 只引用，不复述阈值与权限）

同一时刻可能有多个"该停了"的信号。**按下列顺序判，命中即按该条处置，不再往下走**：

1. **Critical 正式硬停已触发**（streak 达阈值 / 双审轮次上限——阈值与出路见下方 Fix-Loop 计数与跨轮硬停）→ **只走该节中与触发项（streak 硬停 / 轮次上限）对应的那组出路，且一律先停下交人类裁决：未获人类确认，不得继续编码、不得再审、不得自行选定某条出路往下走。** **此时禁止 fresh-context 重启**：它是重新开始的手段，**不是绕过硬停的第四条出路**。
2. **同一处修复连续两次失败（两模式恒适用）** → **立即停手、报告人类**（试了什么、真实报错原文、根因查到哪一步）。**不自动回退、不自动重启，也不在同一回合继续往下调查**——把控制权交回人类。（调试循环内"一个假设被证伪就换下一个"不受此限；触发本条的是**已落地的修复尝试**连续两次失败。）
3. **① ② 都未命中，或人类已明确要求"回退并重新开始"** → 才可进入 `/debug` 的 fresh-context 分支。
4. **任何回退动作之前**：先说明会丢弃哪些未提交改动并等人类确认——**不得默默丢弃人类的在途修改**。

## Reviewer-Lightweight Protocol（唯一定义处；**Reviewer 实际运行时适用**，任何模式）

> 背景（2026-06-10 Codex 配额事故）：Codex 沙箱读不了 node_modules(EPERM)；若允许它"自己验证"会用 git archive 重建整仓 + 重装依赖 + 每轮最高档重跑全量测试，一天耗尽配额。

**本协议分两层，别混用**——第一层与模式无关，第二层的证据载体按模式取。

**第一层 · 资源纪律与零写入（任何模式，只要 Reviewer 实际运行就恒适用）**

每个 review / re-review prompt 必须携带"不重建副本 / 不重装依赖 / 不重跑全量测试；需实跑的列出来交 Author"这条语义，**具体落笔时从第二层直接复制对应模式的整句，不要自己拼**（载体半句嵌在句中，所以第一层不是可独立出现的连续字串——**不要机械检查"第一层整句是否原样出现"**；要机械检查就检查第二层那两条整句）。

* **不重建副本 / 不重装依赖 / 不重跑全量测试。**
* **对仓库零写入**：不改任何文件（含 HANDOFF）、不创建任何 commit；verdict 与 raw log 一律落仓库工作树之外的 holding。
* 证据不足以下结论的，写进输出的 Verification Needed，由 Author 代跑或以技术理由「不采纳」，**Reviewer 自己不跑**。
* scratch 清理归属：**Reviewer 不删除仓库工作树内的任何文件**；仓内遗留的 review-* / .codex-review-* scratch 由 **Author 在人类确认后清理**；Reviewer 只清理自己仓外 holding 里的临时产物。

**第二层 · 证据载体（按模式取）**

**要放进 prompt 的整句，按模式从下面直接复制**（纯文本，无强调符号；Critical 那条是配额事故的守门句，须与 `~/.claude/workflow/reviewer-prompt.md` 的 9A/9B 逐字一致；Critical 计划审那条须与同文件 9P prompt 逐字一致）：

```text
Critical：
不要 git archive 重建副本、不要重装依赖、不要重跑全量测试——以 docs/ai/last_test_run.txt 产物 + 读 git diff 推理为准；需要验证的具体行为列出来，由 Author 在正常终端代跑。

Critical 计划审（9P）：
不要 git archive 重建副本、不要重装依赖、不要跑任何测试——此时尚无实现与测试产物；以工作树中的规划文件 + 只读检索仓库现状为准；需要实跑确认的具体命令列出来，由 Author 在正常终端代跑。

Routine + 临时 Reviewer：
不要 git archive 重建副本、不要重装依赖、不要重跑全量测试——以人类指定的文件 / diff + 对话内展示的真实命令输出与退出码为准；需要验证的具体行为列出来，由 Author 在正常终端代跑。
```

* **Critical**：结论只基于 交接文件 + git diff + `last_test_run.txt`。对 `last_test_run.txt`「批判性地读」：命令是否真实存在、输出是否完整、结论是否与输出一致——不自己重跑复核。Verification Needed 由 Author 代跑、把真实输出**追加进 `last_test_run.txt`**，供人类合并前查看，或逐条以技术理由「不采纳」；**VN 本身与纯代跑不触发再审**——处置产生了「最后一轮独立审查门」③ 例外之外的 review-sensitive delta 时仍按该门再审。审前快照自检与 SHA 绑定适用（见 `~/.claude/workflow/reviewer-prompt.md` → 双审隔离协议）。
* **Critical 计划审（9P）**：结论只基于 工作树中的规划文件（TASK_BRIEF / IMPLEMENTATION_PLAN，+ PRODUCT_BRIEF / QUALITY_GATES 如有）+ 只读检索仓库现状。**没有实现 diff、没有 `last_test_run.txt`、没有批准 commit 与 SHA 账本——不得因缺失拒审、不得要求补造**；不执行审前快照自检（锚定只记 `observed_head_sha` + 两个规划文件的 blob sha 三行，定义见 `~/.claude/workflow/reviewer-prompt.md` → 9P）。Verification Needed 由 Author 代跑，结果用于修订计划（此时无 `last_test_run.txt` 可追加）；命令 + 退出码 + 一句话结论记进 `docs/ai/review_9P.md` 该轮 Author Responses 节。
* **Routine + 临时 Reviewer**：结论基于人类指定的文件 / diff + 对话内展示的真实命令输出与退出码。**没有交接文件，也没有 `last_test_run.txt`——不得为此临时创建，也不得因其缺失而拒审**；**不执行审前快照自检、不做 SHA 绑定**（Routine 无此账本）。证据不够就在 verdict 里直说"证据不足 + 缺哪一项"，**不要求 Author 补造 Critical 产物**。Verification Needed 由 Author 代跑后把完整输出与退出码**贴回对话**。
  > 不拆这一层会出真问题：把 Critical 的输入清单原样套到 Routine，Reviewer 会去找根本不存在的交接文件，要么拒审、要么反过来逼 Author 临时造一份假交接。

## No-Hidden-Debt + [DEBT] 格式（唯一定义处；**两模式恒适用**）

Any compromise made just to "get it working / save time" (simplification, hardcoding, skipped edge case, temporary workaround) has only two legal exits:

* (a) fix it now, or
* (b) register it — **Critical**: one line in the current task's `docs/ai/HANDOFF.md` "Remaining Risks", in the exact format below; **Routine** (no HANDOFF): stop and surface the compromise in conversation — the human either approves fixing it now or upgrades the task to Critical, where it gets its `[DEBT]` line. No silent third path:

```
[DEBT] <one-line description> | Payback trigger: <which file/module, when next touched, must repay first> | Impact: <what happens if unpaid>
```

Banned vague phrasings that hide a compromise as untracked debt (their presence = unregistered debt; the Reviewer lists the phrase and the compromise it hides under Non-Blocking Suggestions, and the Author registers or removes it before merge — not a blocking item):
`later / temporary / for now / should be fine / probably ok / 暂时 / 先这样 / 回头再说 / a TODO or known-issue without a payback trigger`.

（Plain code TODO comments still follow the global rule — they go to plan/TODO docs, not this debt log; but a code TODO that actually hides a compromise must ALSO be registered here as a [DEBT] line.）

## Payback-on-Touch（唯一强制偿还机制，优先于任何 due date；**两模式恒适用**——账本位置与延期出口按模式取，见本节）

Before modifying a file/module, scan whatever debt ledger the project has: **Critical** — the current `docs/ai/HANDOFF.md` plus `docs/ai/archive/**/HANDOFF.md` ("Remaining Risks / Debt" sections); **Routine** — there is no live HANDOFF, but any `docs/ai/archive/**/HANDOFF.md` debts **still bind**, so scan those. This rule itself is always-on in both modes; only the ledger's location differs. A `[DEBT]` Payback trigger must name a concrete file/module path or glob. If a trigger matches the file/module you are about to touch, repay that debt in the same commit (or explicitly request to downgrade/defer it — **Critical**: in the approved plan, with a reason; **Routine**: in the conversation, with a reason, and only proceed after the human explicitly approves); otherwise this change must not be committed. Debt does not follow a list — it follows the code and finds you the next time you touch it.

## 证据 vs 假设标签（反脑补，唯一定义处；**两模式恒适用**）

任何关于用户/市场/需求的判断必须区分「证据」与「假设」，不得把假设当事实：

* 每条判断后紧跟标注：`[证据] <来源>`（访谈/数据/现有反馈/竞品事实）或 `[假设]`。
  * 例：`用户每天手工导出报表 3 次以上 [证据] 来自 5 次访谈`
  * 例：`用户愿为自动化付费 [假设]`
* 所有 `[假设]` 进待验证清单并写明最低成本验证方式；没有验证方式的 `[假设]` = 脑补，审查打回。
* 标「唯一依据 = 是」的高影响假设，进入实现前必须已验证转 `[证据]` 或显式降级；否则**不得进入实现**——**Critical**：计划停在 Pending；**Routine**：停下向人类说明该假设与影响，等人类确认后再动手。
* 工具能力与行为断言必须以官方文档、官方 changelog 或源码等一手来源为依据；次级文章仅可作为检索线索，不得单独作为采纳或晋升证据。

## AI Collaboration Rules（仅 Critical 模式）

* The Author agent plans, implements, fixes tests, and updates docs/ai/HANDOFF.md.
* In implementation reviews (9A/9B), the Reviewer reviews the git diff independently. It never implements anything — every fix, including for a blocking issue it found, is made by the Author (after the dual-review window closes for 9A/9B; as a direct plan revision for 9P, which has no window).
* **计划批准前的 9P 计划审**（正式路径默认必跑；人类可明示减免；快速版 N/A）同属 Reviewer 职责：单跑一轮、零写入、只审工作树规划文件；Author 逐条表态并修订计划后交人类知情批准，**再审仅凭人类明示要求**（见该节），发生在实现与双审窗口之前；其 blocking 不进 Fix-Loop Counter。定义与 prompt：`~/.claude/workflow/reviewer-prompt.md` → 9P。
* Before any implementation-review work, read docs/ai/HANDOFF.md and docs/ai/last_test_run.txt（9P 计划审改读工作树规划文件——彼时 `last_test_run.txt` 尚不存在，见下条）。
* After implementing or fixing, the Author updates docs/ai/HANDOFF.md and re-runs tests with output piped to docs/ai/last_test_run.txt.
* **The Reviewer writes NOTHING into the repository — not even HANDOFF.md, and never a commit.** Its verdict goes to the out-of-tree holding file the Author passes via `codex exec -o` (see `~/.claude/workflow/reviewer-prompt.md` → 双审隔离协议). It never runs tests — it lists what to verify under "Verification Needed" for the Author to run. Any fix, including `wip(review-fix)`, is made by the **Author after the dual-review window closes** (9P has no dual-review window — the Author revises the plan directly after collecting the verdict).
* **双审窗口冻结（9A/9B 真独立的前置）**：从第一个 Reviewer 启动到两份 verdict 都产出为止，Author 与两个 Reviewer 都不得改生产代码 / `review_sensitive_paths` / HANDOFF，也不得 commit。两份 verdict 分开保存、互不可见（9B 先跑，不接收 9A 输出）；两份都完成后 Author 才**一次性**更新 HANDOFF。协议全文与调用范式见 `~/.claude/workflow/reviewer-prompt.md` → 双审隔离协议（唯一定义处）。

## 验证三分类（唯一定义处；**两模式恒适用**）

任何"验证"必须归入三类，混用即无效：
* **Acceptance test（验收测试）**：证明"需求规定的性质在真实生产路径上成立"。预期值来自 TASK_BRIEF / 接口契约 / 批准计划 / 人工确认——**禁止从当前实现反推**。
* **Regression test（回归测试）**：锁定已确认缺陷或既有行为；预期同样来自验收契约或已确认缺陷，非反推自实现。
* **Diagnostic probe（诊断探针）**：临时定位用（一次性脚本 / mutation harness / 红探针 / instrumentation）。**只能定位、不得作为完成证据**，**提交前删除**；其中值得长期保留的行为 → **重写为正式 regression test** 再留。

**Author 不得自证**：自编 mutation harness / 红探针 / "删码后测试变红" **不能单独证明实现正确**——须由 Author 之外的一方复核**变异内容 + 目标测试确实执行 + 具体失败原因**这三项。复核者按模式取：**Critical** 由 Reviewer 复核；**Routine** 把这三项连同完整输出与退出码展示在对话里、由**人类**确认（默认 Routine 没有 Reviewer——**不得为此静默拉一个 Reviewer 进来，也不得因此升级模式或创建 Critical 产物**；人类另行要求临时 Reviewer 时才由其复核）。守护证据的产物契约见下节「守护有效性装置」。

## 守护有效性装置（唯一定义处；**判据两模式恒适用，证据形式按模式取**——见本节 ★ 模式分流；「回归用例有效」的证据契约）

> 实证依据：2026-07-28 翻译项目 4 个空守护测试（删掉被守护代码测试仍绿）致全绿闸门失效、整轮回退；2026-07-29 SeedLink turbo 缓存回放假通过（`TURBO_FORCE=true` 才暴露）。

* **★ 模式分流（先读这条，再读下面全部条款）**：本节的**判据**——负向对照必须有区分力、下述四条失败判据、声称不得超出已覆盖范围——**两模式恒适用**；本节的**证据形式**按模式取：
  * **Critical**：下述全部条款按字面执行（常驻装置、必填字段产物、`tested_sha`、`TASK_BRIEF.md` → Acceptance Criteria 的 Frozen Acceptance 冻结输入域、Reviewer 复核、HANDOFF 落账与 `[DEBT]`）。
  * **Routine**：**没有 HANDOFF / PLAN / `tested_sha` / Reviewer 落账，也不得为此创建**（见 Mode Scope）。**判据一条不减**——等价形式是**把同一套协议在对话里跑完并逐步展示**：① 基线绿（命令 + 完整输出 + 退出码）→ ② 撤销/变异目标生产行为（说明改了哪些文件的什么）→ ③ 目标测试**因预期断言**而红（完整输出 + 退出码，**禁 grep 判红**）→ ④ 还原并确认内容与基线一致 → ⑤ 复跑变绿（完整输出 + 退出码）→ ⑥ 说明执行真实性（缓存旁路方式，或"无缓存层"）。输入域与等价类由**人类当场确认**。**少任何一步 = 未证明**，此时必须当场把声称收窄到已覆盖范围、或撤回声称并报告风险——不允许用"Routine 没有装置"当借口把未验证的守护说成已启用。**省掉的只有产物形式（八字段文件 / `tested_sha` / HANDOFF 落账），不是判据。**
* **义务（Critical 形式）**：需要声称「回归用例有效（红→绿）」的项目必须提供**技术栈适配的守护有效性命令/脚本**（常驻脚手架；命令名项目自定，记录在项目文档与 HANDOFF）。**该声称的唯一可接受证据 = 装置产出的结构化产物**——不接受自然语言自述（含"删码变红"口头叙述）。
* **协议**：基线绿 → 撤销或变异目标生产行为 → 目标测试红 → 还原（内容哈希验证）→ 复绿；全程由装置执行并记录。
* **产物必填字段**：① 目标测试（文件 + 用例名）；② 被撤销/变异的生产行为（逐文件）；③ 基线绿退出码；④ 负向运行退出码；⑤ 预期失败断言/原因；⑥ 恢复后绿退出码 + 还原哈希验证结果；⑦ 生成时 commit（产物绑定被测**内容**：`git diff --quiet <该 commit> <tested_sha> -- <字段①的测试文件> <字段②的生产文件>` 退出 0 即产物仍有效，不要求 sha 相等；`tested_sha` 回炉时按同法重判）；⑧ 执行真实性证据（证明测试确实执行而非缓存回放：缓存旁路方式或"无缓存层"说明，**按构建系统提供**——Turborepo 项目用 `TURBO_FORCE=true` 只是实例，直跑 runner 的记"无缓存层"；不存在跨技术栈唯一方式）。
* **失败判据**（任一不满足 → 产物不构成守护证据）：
  1. 负向运行必须**因目标测试的预期断言**而红——编译/加载失败、环境失败、目标测试未执行、仅无关测试失败均不算；
  2. 红/绿判定以**真实退出码**为准，**禁止 grep 关键词判红**；解析 runner 输出仅用于确认"哪个测试、因何断言失败"；
  3. 还原必须经内容哈希验证，且恢复后重跑变绿；
  4. 产物含执行真实性证据（字段 ⑧）。
* **无装置项目**：不得把该能力写成已启用；装置落地前「回归用例有效」= 未证明——**Critical**：列 Reviewer Verification Needed 并记 `[DEBT]`（Payback trigger：下次需要守护证据时先落地装置）；**Routine**：在对话里说明未证明，并按 No-Hidden-Debt 的 Routine 分支当场向人类提出（无 HANDOFF 可记）。两模式都可在当前任务顺带落地装置。
* **与验证三分类的边界**：装置及其变异 spec 是**常驻项目脚手架**，不属 diagnostic probe；运行期变异必须还原并产物化。Author 不得自证规则保持不变——Reviewer 不运行装置，只核产物完整性与字段自洽（见 `~/.claude/workflow/reviewer-prompt.md` 9A）。
* **负向对照：适用范围扩展到一切守护声称（2026-08-15）**——本节的"区分力"要求**不限于测试守护**。任何「机制 X 会拒绝 Y」的声称（构建/编译配置、lint 规则、类型检查、CI 门禁、扫描器等）都必须提供**负向对照**：样本须「**若移除 X 则会通过**」，以证明拒绝确由 X 造成——**用「本来就会失败」的样本验证守护 = 无效验证，等同空守护测试**。
  * **覆盖范围决定样本数，不是"至少一个"**：对照必须**覆盖声称所主张的全部等价类**（如声称"拒绝一切内置模块导入"，则静态 import / 动态 import / 模板串 / 变量串 / 类型标注串等每一类都要有样本）。**一个合格样本只证明该等价类，不证明整条声称。** 覆盖不到的类，声称必须当场收窄到覆盖得到的范围。Reviewer 认为覆盖不足时写进 Verification Needed 或 Non-Blocking Suggestion（域内反例规则见下），**不构成 blocking**。
  * **等价类的封闭方式（防止"永远还有一类"的新回归）**：等价类必须**枚举自一个人类批准并冻结的输入域**（语言语法子集 / 接口取值域 / 威胁模型条目），该枚举**Critical** 写进 `TASK_BRIEF.md` → Acceptance Criteria（Frozen Acceptance 的唯一落点，review-sensitive）、**Routine** 由人类在对话里确认并复述一遍，冻结后即为本任务的完整集。**Reviewer 主张"还有一类未覆盖"时，必须给出该域内的具体反例**（能实际触发漏过的输入）——给得出即写进 Verification Needed 由 Author 代跑；**给不出则记 Non-Blocking Suggestion，不阻止收敛**。域本身需要扩大 = 验收变更，走人类批准，不在本轮 fix-loop 内解决。
  * 还须核对**失败原因**：拒绝必须由目标机制以预期诊断产生，而非编译错误、解析失败、依赖缺失等无关原因。
  > 实证（2026-08-15）：某项目声称 `tsconfig` 的 `"types": []` 能拒绝 Node 内置模块导入，并写进验收、测试产物与配置注释三处。实测七个探针中**五个本该被拒的全部通过**（含最朴素的 `import 'node:fs'`）。根因：此前所有"验证通过"的样本要么是**环境全局**（`module`/`require`/`process`——移除该配置也照样被拒），要么是**未安装的包**（拒绝原因是解析不到）。**每个通过的样本，就算机制完全不存在也会照样通过。**

## 验收条款必须可复现判定（唯一定义处；**两模式恒适用**）

**每条验收条款（AC）的「判定方式」必须同时满足两条：① 可复现——换个人、换一轮，按同一步骤得到同一结论；② 有区分力——存在一个「若该性质不成立则判定会失败」的对照。** 命令 + 退出码是首选形态，但**命令形态本身不等于合格**：一个永远返回 0 的脚本、一个只检查字段存在的扫描，都满足形态而没有区分力（见「守护有效性装置」的负向对照要求）。

* **能自动化的一律自动化**；不能可靠自动化的**产品 / 安全 / 合规**性质**仍可作 AC 并阻止合并**，但必须写成**明确的人类判定步骤**：给出判定人、固定的判定输入（具体文件/界面/数据的确定指向）、逐条判据、以及"什么情况判不通过"的反例。
* **反例必须实际触发失败，不接受纸面反例**（**适用于守护类 AC（「机制 X 拒绝 Y」）与人类判定 AC**；命令 + 退出码形态的 AC 以套件自身的失败用例为对照，不另留反例产物）：AC 落地时须留下产物，证明**把该反例喂给这套判定方法时，判定确实判不通过**（自动化的记退出码，人工的记判定人 + 判定结论 + 时间）。只写出反例而从未让它跑一次 = 无区分力，等同空守护测试。**判定人之间有分歧 → 交人类裁决，不得由 Author 择一采信。**
* **不合格的是"无判据的散文对读"**：判定方式写成「Reviewer 逐条核对 / 对照两表核 / 核清单完整性」而不给判据与反例的，**不是验收条款**——降级为 Non-Blocking Suggestion 或移交清单条目，**不得阻止收敛**。这类性质通常可以改写成有区分力的形式（清单条目数 == 源表条目数、某扫描命令零命中、某路径必被真实生产入口覆盖）。
* **声称不得超出判定实际覆盖的范围**——Reviewer 指出后（纯措辞的归 Non-Blocking Suggestion；所称路径实际未运行的归 Verification Needed，判法见 Reviewer verdict 分类语义），Author 落账时把声称收窄到已覆盖范围（声称在 HANDOFF / last_test_run 的直接改；写在 TASK_BRIEF 验收条款里的只能经人类裁决 Amendment 修订，见最后一轮独立审查门 ③）或撤回并报告风险；Routine 由人类指出。**不构成 blocking。**

> **来历（2026-08-15 实测）**：某任务 AC1/AC2（退出码类）四轮零缺陷；AC5/AC9/AC13（"Reviewer 对照…逐条核"、判定对象是散文清单的完整性）逐轮产出新 blocking，第 4 轮又挑出 7 条遗漏。**散文完整性永远可以再被挑出一条——拿它当 blocking 依据，等于在构造上把收敛做成不可能。**

## Reviewer verdict 分类语义（唯一定义处；**Reviewer 实际运行时适用**——分类语义与 Debt Verdict 取值两模式通用；**`caused_by_last_fix` 与 streak 计数仅 Critical**（Routine 无 Fix-Loop 账本，见 Mode Scope）。`~/.claude/workflow/reviewer-prompt.md` / `/final-review` 引用本节，不得产生冲突契约）

顶层输出字段保持不变（兼容 Codex 强制结构），语义如下（**2026-09-03 起 `[Verification Blocking]` 类已删除**——来历：7 个真实任务 335 条 blocking 中 177 条为该类、用户可感知者 46 条，八份连续「不通过」verdict 都自述产品无缺陷；证据缺口改走 Verification Needed）：
* **Blocking Issues 只收 `[Product Blocking]`**：每条须写出**具体后果**——哪个用户操作 / 哪条数据 / 哪个安全边界会出错（已造成或可达皆可）；「不能排除」「可能有影响」不是后果，写不出具体后果的一律进 Verification Needed。含：为过测试而真实弱化 validation·auth·错误处理；diff 中删除、跳过或弱化（改后原缺陷不再被检出）了覆盖本任务所改行为的测试，且 commit message / HANDOFF Work Log / 测试内注释三处均无说明，或说明的理由经 Reviewer 核实不成立（Reviewer 须写出该测试仍能检出的具体缺陷或可达路径；写不出的记 Non-Blocking Suggestion）；某条验收点**有具体反例**表明未满足（`last_test_run.txt` 中的失败输出 / Reviewer 从 diff 读出的「具体输入 → 错误输出」路径 / Author 代跑 Verification Needed 后暴露的失败）——**缺证据 ≠ 未满足**，缺证据走 Verification Needed。归类存疑（后果写得出、可达性不确定）按 Product 记交人类裁决；后果写不出的不算存疑。每条由 **Reviewer** 标 `caused_by_last_fix: yes/no/dispute`（**仅 Critical**，只服务 Fix-Loop streak；Routine 无此账本，不填）。**只有 Blocking Issues 阻止合并。**
* **证据缺口不是 blocking**：probe 冒充证据、测试不走真实路径但被测行为本身正确、守护产物字段不全、负向对照覆盖不足、**实际运行未覆盖所称路径**（声称宽于运行证据、且该路径承载产品/AC 结论）——写进 **Verification Needed**：点名哪条声称 / 由哪份产物支撑 / 缺什么，并给**一个能证伪该声称的最小检查**（单个测试 / 单个样本 / 单条 grep；不得列全量套件、整批装置重跑、或 `last_test_run.txt` 中同一 tip 已有输出的命令）。由 Author 代跑并把真实输出与退出码追加进 `last_test_run.txt`，或逐条以技术理由「不采纳」（同「修法必附」三选一）；两者都由人类在合并前逐条看到（`/final-review` → Manual Check Before Commit）。**VN 本身与纯代跑不触发新一轮审查**；处置若产生了「最后一轮独立审查门」③ 例外之外的 review-sensitive delta（改生产代码、删/改既有测试或测试基础设施、构建配置等），仍按该门再审。
* **账本与措辞不一致**（HANDOFF 字段、手写计数、当前阶段文本、SHA 字段写法、以及**不涉及未核验产品/AC 行为的纯措辞过度声称**）写进 **Non-Blocking Suggestions** 并附 Proposed Fix；Author 落账时改正或收窄声称，一句话表态即可。一条发现兼具「所称路径未实际运行」与「措辞过度」时，拆成一条 Verification Needed + 一条 Suggestion。
* **Review Verdict 语义**：`不通过` ⇔ Blocking Issues 非空；`有条件通过` = Blocking Issues 为 None 且 Verification Needed 非空；`通过` = 两者皆空。Process Debt、Suggestion 不影响通过。**Reviewer 不得以证据充分性为由判不通过。**
* **Debt Verdict** 取值 **`Clean / Noted / Deferred / Unpaid`**：**Clean**=无债；**Noted**=**未触发** Payback-on-Touch 的普通存量债（行数债等，不阻止合并，**不得与用户数据错误等价**）；**Deferred**=触发 Payback-on-Touch 但**已获人类批准延期**（不阻止）——**Critical** 凭批准的 plan，**Routine** 凭对话内人类明确批准（见 Payback-on-Touch）；**Unpaid**=触发 Payback-on-Touch 且未偿还、无批准延期——不进 Blocking Issues、不触发再审，但 `/final-review` 第 11 条据此不得判「可以提交」，由人类在合并前决定偿还或批准延期。（取值来历：`[Verification Blocking]` 删除后，Payback-on-Touch 的 "must not be committed" 只剩此取值能如实记录——Noted 定义为未触发；成本一个枚举值，不触发再审。）
* **不得把 Author 的自我总结 / "已修复" 叙述当作证据。但 HANDOFF / TASK_BRIEF 中注明日期、标「人类裁决 / Amendment / 批准」的条目一律按人类决定对待**：Reviewer 不核实其发生过程、不因由 Author 转录而降为自述、不要求其出现在人类 commit 中；人类裁决修订过的验收条款以修订后为准；异议只进 Assumption / Requirement-Level Concerns，不得据此立 blocking。（每条裁决由 `/final-review` 在 Manual Check Before Commit 逐条列给人类确认。）
* **分类优先级（历史条款，保留一句）**：为过测试而真实弱化认证 / 绕过 validation 属 **Product**（它改变了真实的安全行为）；「认证测试没走真实路径、但认证本身正确」是证据缺口，走 Verification Needed。

## review-sensitive paths + SHA 绑定（唯一定义处；**仅 Critical**——Routine 无 SHA 账本，见 Mode Scope）

**该清单本身是 review-sensitive（2026-08-15 补）**：`review_sensitive_paths` 在双审窗口开启时即**冻结**——审后**不得缩窄**（移除条目、改窄 glob、把文件移出清单皆属缩窄）。清单缩窄**使本轮审查失效**，须重跑。缩窄的判定方式：`/final-review` 用 `git show <handoff_snapshot_sha>:docs/ai/HANDOFF.md` 取出审前清单，与当前 HANDOFF 的清单比对；出现移除条目、改窄 glob、移出文件即缩窄。审前清单未覆盖 base..tip 中必含类别的文件 = **覆盖缺口**：Reviewer 在 verdict 首行之后报告并照常审查，Author 落账时补入清单；`/final-review` 重跑同一覆盖核验，未补则不得可提交。**理由**：出口与失效判定都以此清单为边界，清单可事后修改 = 边界可事后自定，整套绑定失去意义。

**review_sensitive_paths（审查/测试共用同一份精确 pathspec，每任务在 HANDOFF 显式列出）** 至少含：生产源码、tests、migrations/schema、构建配置 + 依赖声明 + lockfile、`docs/ai/TASK_BRIEF.md`（验收条款与 Frozen Acceptance 的唯一落点，见 templates）。**排除**：`docs/ai/IMPLEMENTATION_PLAN.md`、`docs/ai/QUALITY_GATES.md` 与普通说明文档——计划散文与清单措辞的修订不使审查失效（QUALITY_GATES 的审后改动由 `/final-review` 列给人类，见最后一轮独立审查门 ③）。**审查后弱化测试或修改验收标准 = review-sensitive 内容变化 → 使审查失效。** **测试与审查用同一份 `review_sensitive_paths`（不另设单独的测试清单）。**

**SHA 绑定语义**（HANDOFF 记 `review_base_sha / review_tip_sha / review_verdict_9A / review_verdict_9B / tested_sha / handoff_snapshot_sha` + 该任务 `review_sensitive_paths`；`handoff_snapshot_sha` 由 **Author 在统一落账时记入**——快照 commit 本身无法自记自身 sha；**9A、9B 必须绑定同一个 `review_tip_sha`**，减档只跑 9A 时 `review_verdict_9B` 记 `N/A — 人类减档 + 原因`）：
* `review_tip_sha` / `tested_sha` **仅在**满足下列时才算有效快照绑定：① 所有 `review_sensitive_paths` 文件已进入对应 commit；② 这些路径无未提交修改；③ 这些路径无未跟踪文件。**带未提交/未跟踪的 review-sensitive 改动去跑正式测试或提审 = 不算 SHA 绑定，必须先形成明确的 reviewable commit。**
* **HANDOFF 与 last_test_run.txt 不在 `review_sensitive_paths` 内，按 `/implement` 顺序提交在 `review_tip_sha` 之后**（先更新 HANDOFF 再 docs commit）。故 **tip 里装的是过期 HANDOFF**：任何 Reviewer 都必须**从工作树读**这两个文件，禁止 `git show <review_tip_sha>:docs/ai/HANDOFF.md`。Author 在两份 review prompt 里写明同一个 `handoff_snapshot_sha`（= 双审窗口开启时的 HEAD）作为"同一份审前 HANDOFF"的凭证。**该凭证必须经 Reviewer 侧核验并落账为证据**——两份 verdict 各自记录 `observed_head_sha`（必须 == `handoff_snapshot_sha`）、`worktree_clean`（全树 `git status --porcelain` 为空）、`read_handoff_from`（必须为「工作树」；出现 `git show tip` 即作废）——HEAD 等于快照 commit 且工作树干净，即保证工作树中的 HANDOFF / last_test_run.txt 与快照逐字节一致，无需另记 blob hash（命令与拒审规则唯一定义处：`~/.claude/workflow/reviewer-prompt.md` → 双审隔离协议 ⑤）；仅两份 prompt 数值相同**不构成**绑定。`review_base_sha` / `review_tip_sha` 由 Author 逐字写进两份 prompt，不写『见 HANDOFF』。
* **失效判定用内容比对、非 HEAD 相等**（可执行）：`git diff --quiet <review_tip_sha> -- <review_sensitive_paths>` 且 `git diff --quiet <tested_sha> -- <review_sensitive_paths>` 且 `git status --porcelain -- <review_sensitive_paths>` 为空 → 审查/测试仍有效。**不在 `review_sensitive_paths` 内的纯文档提交改变 HEAD 不使审查失效。** **唯一例外（与「最后一轮独立审查门」③ 同义）**：审后 delta 仅为纯新增独立测试用例文件（不删改既有断言、不含测试基础设施）、`docs/ai/` 非验收文档、或人类裁决的验收修订 → 审查仍有效、`review_tip_sha` 不变；新增测试时 `tested_sha` 须回炉到含该 delta 的新 commit。

## Fix-Loop 计数与跨轮硬停（唯一定义处；**仅 Critical**——Routine 无 Fix-Loop 账本，其停手判据见「停止事件优先级」②。/debug、/final-review 引用）

* **递增（仅 Product 计数）**：某一轮**只要存在至少一个经确认的 `caused_by_last_fix: yes` 的 `[Product Blocking]`**，该轮 streak 计 1。Verification Needed 与 Suggestion 不计数。9A、9B **重复发现同一问题不重复计数**（按问题去重）。**9P 计划审的 blocking 发生在实现之前、不属任何 review-fix 轮，一律不计入 streak，也不计入本节 9A/9B 双审的轮次上限**（9P 默认单跑一轮、再审仅凭人类明示，见 `~/.claude/workflow/reviewer-prompt.md` → 9P）。
  > 理由（历史，2026-08-15 实测；当时尚有 `[Verification Blocking]` 类，2026-09-03 起该类已删、证据缺口走 Verification Needed）：硬停的本意是防「修 A 坏 B」的产品级恶化。三个真实任务后段的 blocking 几乎全是 `[Verification]`（证据能否证明声称），多轮**双审零 `[Product]`**，却被自己的记账瑕疵逼到 streak=6 / 硬停。账本瑕疵与用户数据错误不同级，不应等价计数。
* **判定权与写入**：`caused_by_last_fix` **由 Reviewer 在其 verdict 里判定**；Author 只能把该值**逐字转录**进 HANDOFF（附 review 文件/轮次来源），**不得自行判断或改写**（Reviewer 对仓库零写入、verdict 产于仓外 holding——见 AI Collaboration Rules；故 HANDOFF 里的该字段只能由 Author 落账时逐字转录，Author 无裁定权）。Reviewer 标 `dispute` → **不自动计数、交人类裁决**。
* **重置**：某一轮无"修复引入的 `[Product Blocking]`"（该轮 0 计），streak 归 0。
* **停止（硬门）**：streak 连续达 **2** → **立即停止编码**，只能：回退 / 重新拆任务 / 请求人类批准架构升级；**禁止"再试一轮"**（未获人类确认不得继续）。
* **轮次上限（关闭阀，2026-08-15 新增）**：同一任务的双审达 **3 轮**仍未收敛 → **停止再审**，交人类在「带如实登记的限制交付 / 重新拆任务 / 回退」三者中裁决。**收敛不是唯一出口**——把"再审一轮"当默认出口，是四个真实任务全部停在 `stopped, NOT converged` 的直接原因（实测轮次：7 / 6 / 5 / 3）。人类可明确批准延长，但延长须逐次批准，不得默认。
* **三者优先级（硬停 / 轮次上限 / 合并门，唯一判据）**：① **硬停优先于轮次上限**——streak 达 2 时只能走硬停的三条出路，不得改走"限制交付"。② **合并门优先于一切出口**——存在**未解决的 `[Product Blocking]`（含任何安全/隐私影响）** 时，「带限制交付」**不含合并**：可以停、可以记账、可以移交，**不得合入 main**。③ 无论走哪条出口，只要没过收敛门，一律记 `stopped, NOT converged`，**不得**标 Ready to Commit / 已收敛。「限制交付」的合法含义仅限：**零未解决 Product Blocking**，剩余 Verification Needed 已逐条处置（代跑追加或不采纳，见最后一轮独立审查门 ②）。

## 最后一轮独立审查门（唯一定义处；**仅 Critical**——Routine 无双审与收敛门）

标记「已收敛 / Ready to Commit」要求同时成立：
① 最后一轮实际跑过的每一份 verdict 的 Blocking Issues 中**无未解决的 `[Product Blocking]`**——「已解决」= 已修复并对该修复再审通过，或 Author `不采纳`（附技术理由）且**人类裁决该项不成立**并记入 HANDOFF Work Log（日期 + 一句话）；verdict 词本身不是门（`不通过` 的 verdict 在其全部 Product 条目按上法解决后不再阻止）。减档只跑 9A 时 9B 记 N/A + 减档原因。
② 该轮全部 Verification Needed 已逐条处置：由 Author 代跑、真实输出与退出码已追加进 `last_test_run.txt`，或以技术理由「不采纳」；每条在 `/final-review` 的 Manual Check Before Commit 占一行（命令 → 退出码 → Author 一句话判定「产品缺陷 是/否」，或「不采纳 + 理由」）；退出码非 0、装置判 NOT PROVEN 的条目不得省略。处置产生的 review-sensitive delta 是否再审，按 ③ 判。
③ 当前 review-sensitive 内容 == `review_tip_sha`（内容比对）。**例外（不使审查失效、delta 在最终 diff 里由人类直接看到）**：(a) 审后仅新增独立测试用例文件（`test_*` / `*.spec.*` / `*.test.*`）且不删不改既有断言——**不含** conftest / fixtures / 测试与 runner 配置 / setup 文件（这些一律按改既有测试处理，须再审）；此时 `tested_sha` 须回炉到含该 delta 的新 commit，且新 `last_test_run.txt` 的收集用例总数 ≥ `git show <handoff_snapshot_sha>:docs/ai/last_test_run.txt` 那次（两份已有输出对比，不另记字段）；(b) 只改 `docs/ai/` 非验收文档（HANDOFF / last_test_run / review_9*）；(c) 验收条款的修订出自人类裁决（TASK_BRIEF / HANDOFF 记「人类裁决 / Amendment」+ 日期）且未改生产代码；(d) `docs/ai/QUALITY_GATES.md` 审后有改动 → 不自动失效，但 `/final-review` 把该 diff 原样列进 Manual Check Before Commit 由人类决定是否再审（删行 = 删闸门）。凡改了生产源码、迁移/schema、构建配置与依赖、删/改既有测试或测试基础设施、或 Author 自行改验收条款 → 须对该 delta 再审（人类可减档只跑 9A）。
**人类因成本叫停 ≠ 质量通过**：存在未解决 `[Product Blocking]`、或有未经审查的生产改动时，记 `stopped, NOT converged`，不得标已收敛。
> 来历（2026-09-03）：原「证据层出口」及其三条等价满足条件、文件范围与反滥用示例已随 `[Verification Blocking]` 类一并删除——证据缺口不再阻止收敛，出口无需存在。

## review-fix 最小生产范围（Safety Rule 补充；**两模式恒适用**——其中「双审窗口结束后」仅 Critical）

Critical 的 review-fix 由 **Author 在双审窗口结束后**执行（Reviewer 不改代码，见 AI Collaboration Rules；Routine 无此窗口），两模式下都**只允许改当前 blocking 所需的最小生产范围**。要新增模块 / 改公共接口 / 扩大架构 → **停止并重新计划**（走 /plan），不在 fix 循环里做。

## Git Discipline（**按模式取**：Critical 全程强制；Routine 不建任务分支、不由 Agent commit——人类扫 diff 后 commit/merge）

* 任务开始从主分支建任务分支：`git checkout -b task/[简短任务名]`。
* 阶段性 commit 强制：计划批准由人类 commit（即批准凭证）；Author 实现 `wip(author): ...`；交接产物（`last_test_run.txt` + `HANDOFF.md`）在 HANDOFF 更新完毕后单独 `docs(handoff): ...`；review 修复 `wip(review-fix): ...`（**由 Author 在双审窗口结束后创建**）。
* 回滚 = revert 对应 commit；Reviewer 审的是明确 commit range；最终由人类 squash。
