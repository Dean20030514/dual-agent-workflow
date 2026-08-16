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

**单轮任务的 diff 尽量不超过 2000 行**——增删合计，**含测试与证据产物**（不是只算生产代码）。计法按模式取：

* **Critical**：`git diff --shortstat <base>..<tip>`（任务分支相对 base），含 `docs/ai/` 产物。
* **Routine**：`git diff --shortstat HEAD`（本次未提交改动；有新增未跟踪文件时加上其行数）——Routine 不建任务分支、不由 Agent commit，所以计的是"交给人类扫的那一坨"。

* **规划时**：按此切片。切不到 2000 行以内 → 写明理由并请人类批准整体推进（**Critical** 写进计划；**Routine** 在对话里说明）——同「架构层拆分评估」的处理方式，**不按行数机械拒绝**。
* **实现中**：发现将要超出 → **停下报告人类**，由人类决定拆分、缩范围或批准超限；不得默默做完再交一个超大 diff。
* **超限时优先砍哪一边**：先看 `docs/ai/` 证据面占比。若证据面接近或超过生产面，说明这个任务的产物仪式已重于交付本身——**先减叙述性仪式，再减需求**。可减的只有**重复的、非强制的叙述性产物**（同一事实在多处复述、逐轮流水账、可由产物现算的手写数字）。**不得削减**：测试输出与退出码、验收 oracle 与其负向对照、SHA 绑定、安全/隐私相关证据、`[DEBT]` 明账——这些是证据本身，减它们等于用造假换预算。减不动就按上一条请人类批准超限。

> **来历（2026-08-15 实测）**：三个真实项目的当轮任务 diff 分别为 4556 / 5738 / 2820 行，**全部以 `stopped, NOT converged` 或硬停收场**；其中 `docs/ai` 证据面占 74% / 42% / 41%，而后段审查轮的 blocking 几乎全是 `[Verification]`（证据是否证明得了声称），**多轮零 `[Product]`**。超大 diff 同时放大审查面与证据面，是多轮返工与 Fix-Loop 硬停的主要相关因素。

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
* 证据不足以下结论的，写进输出的 Verification Needed，由 Author 代跑，**Reviewer 自己不跑**。
* scratch 清理归属：**Reviewer 不删除仓库工作树内的任何文件**；仓内遗留的 review-* / .codex-review-* scratch 由 **Author 在人类确认后清理**；Reviewer 只清理自己仓外 holding 里的临时产物。

**第二层 · 证据载体（按模式取）**

**要放进 prompt 的整句，按模式从下面直接复制**（纯文本，无强调符号；Critical 那条是配额事故的守门句，须与 `~/.claude/workflow/reviewer-prompt.md` 的 9A/9B 逐字一致）：

```text
Critical：
不要 git archive 重建副本、不要重装依赖、不要重跑全量测试——以 docs/ai/last_test_run.txt 产物 + 读 git diff 推理为准；需要验证的具体行为列出来，由 Author 在正常终端代跑。

Routine + 临时 Reviewer：
不要 git archive 重建副本、不要重装依赖、不要重跑全量测试——以人类指定的文件 / diff + 对话内展示的真实命令输出与退出码为准；需要验证的具体行为列出来，由 Author 在正常终端代跑。
```

* **Critical**：结论只基于 交接文件 + git diff + `last_test_run.txt`。对 `last_test_run.txt`「批判性地读」：命令是否真实存在、输出是否完整、结论是否与输出一致——不自己重跑复核。Verification Needed 由 Author 代跑、把真实输出**追加进 `last_test_run.txt`**、再 re-review。审前快照自检与 SHA 绑定适用（见 `~/.claude/workflow/reviewer-prompt.md` → 双审隔离协议）。
* **Routine + 临时 Reviewer**：结论基于人类指定的文件 / diff + 对话内展示的真实命令输出与退出码。**没有交接文件，也没有 `last_test_run.txt`——不得为此临时创建，也不得因其缺失而拒审**；**不执行审前快照自检、不做 SHA 绑定**（Routine 无此账本）。证据不够就在 verdict 里直说"证据不足 + 缺哪一项"，**不要求 Author 补造 Critical 产物**。Verification Needed 由 Author 代跑后把完整输出与退出码**贴回对话**。
  > 不拆这一层会出真问题：把 Critical 的输入清单原样套到 Routine，Reviewer 会去找根本不存在的交接文件，要么拒审、要么反过来逼 Author 临时造一份假交接。

## No-Hidden-Debt + [DEBT] 格式（唯一定义处；**两模式恒适用**）

Any compromise made just to "get it working / save time" (simplification, hardcoding, skipped edge case, temporary workaround) has only two legal exits:

* (a) fix it now, or
* (b) register it — **Critical**: one line in the current task's `docs/ai/HANDOFF.md` "Remaining Risks", in the exact format below; **Routine** (no HANDOFF): stop and surface the compromise in conversation — the human either approves fixing it now or upgrades the task to Critical, where it gets its `[DEBT]` line. No silent third path:

```
[DEBT] <one-line description> | Payback trigger: <which file/module, when next touched, must repay first> | Impact: <what happens if unpaid>
```

Banned vague phrasings that hide a compromise as untracked debt (their presence = unregistered debt, review sends it back):
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
* The Reviewer agent reviews the git diff independently. It never implements anything — every fix, including for a blocking issue it found, is made by the Author after the dual-review window closes.
* Before any work, read docs/ai/HANDOFF.md and docs/ai/last_test_run.txt.
* After implementing or fixing, the Author updates docs/ai/HANDOFF.md and re-runs tests with output piped to docs/ai/last_test_run.txt.
* **The Reviewer writes NOTHING into the repository — not even HANDOFF.md, and never a commit.** Its verdict goes to the out-of-tree holding file the Author passes via `codex exec -o` (see `~/.claude/workflow/reviewer-prompt.md` → 双审隔离协议). It never runs tests — it lists what to verify under "Verification Needed" for the Author to run. Any fix, including `wip(review-fix)`, is made by the **Author after the dual-review window closes**.
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
  * **Critical**：下述全部条款按字面执行（常驻装置、必填字段产物、`tested_sha`、`IMPLEMENTATION_PLAN.md` 的 Frozen Acceptance 冻结输入域、Reviewer 复核、HANDOFF 落账与 `[DEBT]`）。
  * **Routine**：**没有 HANDOFF / PLAN / `tested_sha` / Reviewer 落账，也不得为此创建**（见 Mode Scope）。**判据一条不减**——等价形式是**把同一套协议在对话里跑完并逐步展示**：① 基线绿（命令 + 完整输出 + 退出码）→ ② 撤销/变异目标生产行为（说明改了哪些文件的什么）→ ③ 目标测试**因预期断言**而红（完整输出 + 退出码，**禁 grep 判红**）→ ④ 还原并确认内容与基线一致 → ⑤ 复跑变绿（完整输出 + 退出码）→ ⑥ 说明执行真实性（缓存旁路方式，或"无缓存层"）。输入域与等价类由**人类当场确认**。**少任何一步 = 未证明**，此时必须当场把声称收窄到已覆盖范围、或撤回声称并报告风险——不允许用"Routine 没有装置"当借口把未验证的守护说成已启用。**省掉的只有产物形式（八字段文件 / `tested_sha` / HANDOFF 落账），不是判据。**
* **义务（Critical 形式）**：需要声称「回归用例有效（红→绿）」的项目必须提供**技术栈适配的守护有效性命令/脚本**（常驻脚手架；命令名项目自定，记录在项目文档与 HANDOFF）。**该声称的唯一可接受证据 = 装置产出的结构化产物**——不接受自然语言自述（含"删码变红"口头叙述）。
* **协议**：基线绿 → 撤销或变异目标生产行为 → 目标测试红 → 还原（内容哈希验证）→ 复绿；全程由装置执行并记录。
* **产物必填字段**：① 目标测试（文件 + 用例名）；② 被撤销/变异的生产行为（逐文件）；③ 基线绿退出码；④ 负向运行退出码；⑤ 预期失败断言/原因；⑥ 恢复后绿退出码 + 还原哈希验证结果；⑦ tested_sha（产物绑定被测 commit——tested_sha 失效连带产物失效，按 SHA 绑定语义回炉）；⑧ 执行真实性证据（证明测试确实执行而非缓存回放：缓存旁路方式或"无缓存层"说明，**按构建系统提供**——Turborepo 项目用 `TURBO_FORCE=true` 只是实例，直跑 runner 的记"无缓存层"；不存在跨技术栈唯一方式）。
* **失败判据**（任一不满足 → 产物不构成守护证据）：
  1. 负向运行必须**因目标测试的预期断言**而红——编译/加载失败、环境失败、目标测试未执行、仅无关测试失败均不算；
  2. 红/绿判定以**真实退出码**为准，**禁止 grep 关键词判红**；解析 runner 输出仅用于确认"哪个测试、因何断言失败"；
  3. 还原必须经内容哈希验证，且恢复后重跑变绿；
  4. 产物含执行真实性证据（字段 ⑧）。
* **无装置项目**：不得把该能力写成已启用；装置落地前「回归用例有效」= 未证明——**Critical**：列 Reviewer Verification Needed 并记 `[DEBT]`（Payback trigger：下次需要守护证据时先落地装置）；**Routine**：在对话里说明未证明，并按 No-Hidden-Debt 的 Routine 分支当场向人类提出（无 HANDOFF 可记）。两模式都可在当前任务顺带落地装置。
* **与验证三分类的边界**：装置及其变异 spec 是**常驻项目脚手架**，不属 diagnostic probe；运行期变异必须还原并产物化。Author 不得自证规则保持不变——Reviewer 不运行装置，只核产物完整性与字段自洽（见 `~/.claude/workflow/reviewer-prompt.md` 9A）。
* **负向对照：适用范围扩展到一切守护声称（2026-08-15）**——本节的"区分力"要求**不限于测试守护**。任何「机制 X 会拒绝 Y」的声称（构建/编译配置、lint 规则、类型检查、CI 门禁、扫描器等）都必须提供**负向对照**：样本须「**若移除 X 则会通过**」，以证明拒绝确由 X 造成——**用「本来就会失败」的样本验证守护 = 无效验证，等同空守护测试**。
  * **覆盖范围决定样本数，不是"至少一个"**：对照必须**覆盖声称所主张的全部等价类**（如声称"拒绝一切内置模块导入"，则静态 import / 动态 import / 模板串 / 变量串 / 类型标注串等每一类都要有样本）。**一个合格样本只证明该等价类，不证明整条声称。** 覆盖不到的类，声称必须当场收窄到覆盖得到的范围。
  * **等价类的封闭方式（防止"永远还有一类"的新回归）**：等价类必须**枚举自一个人类批准并冻结的输入域**（语言语法子集 / 接口取值域 / 威胁模型条目），该枚举**Critical** 写进 `IMPLEMENTATION_PLAN.md` 的 Frozen Acceptance、**Routine** 由人类在对话里确认并复述一遍，冻结后即为本任务的完整集。**Reviewer 主张"还有一类未覆盖"时，必须给出该域内的具体反例**（能实际触发漏过的输入）——给得出即为有效 `[Verification Blocking]`；**给不出则记 Non-Blocking Suggestion，不阻止收敛**。域本身需要扩大 = 验收变更，走人类批准，不在本轮 fix-loop 内解决。
  * 还须核对**失败原因**：拒绝必须由目标机制以预期诊断产生，而非编译错误、解析失败、依赖缺失等无关原因。
  > 实证（2026-08-15）：某项目声称 `tsconfig` 的 `"types": []` 能拒绝 Node 内置模块导入，并写进验收、测试产物与配置注释三处。实测七个探针中**五个本该被拒的全部通过**（含最朴素的 `import 'node:fs'`）。根因：此前所有"验证通过"的样本要么是**环境全局**（`module`/`require`/`process`——移除该配置也照样被拒），要么是**未安装的包**（拒绝原因是解析不到）。**每个通过的样本，就算机制完全不存在也会照样通过。**

## 验收条款必须可复现判定（唯一定义处；**两模式恒适用**）

**每条验收条款（AC）的「判定方式」必须同时满足两条：① 可复现——换个人、换一轮，按同一步骤得到同一结论；② 有区分力——存在一个「若该性质不成立则判定会失败」的对照。** 命令 + 退出码是首选形态，但**命令形态本身不等于合格**：一个永远返回 0 的脚本、一个只检查字段存在的扫描，都满足形态而没有区分力（见「守护有效性装置」的负向对照要求）。

* **能自动化的一律自动化**；不能可靠自动化的**产品 / 安全 / 合规**性质**仍可作 AC 并阻止合并**，但必须写成**明确的人类判定步骤**：给出判定人、固定的判定输入（具体文件/界面/数据的确定指向）、逐条判据、以及"什么情况判不通过"的反例。
* **反例必须实际触发失败，不接受纸面反例**：AC 落地时须留下产物，证明**把该反例喂给这套判定方法时，判定确实判不通过**（自动化的记退出码，人工的记判定人 + 判定结论 + 时间）。只写出反例而从未让它跑一次 = 无区分力，等同空守护测试。**判定人之间有分歧 → 交人类裁决，不得由 Author 择一采信。**
* **不合格的是"无判据的散文对读"**：判定方式写成「Reviewer 逐条核对 / 对照两表核 / 核清单完整性」而不给判据与反例的，**不是验收条款**——降级为 Non-Blocking Suggestion 或移交清单条目，**不得阻止收敛**。这类性质通常可以改写成有区分力的形式（清单条目数 == 源表条目数、某扫描命令零命中、某路径必被真实生产入口覆盖）。
* **声称不得超出判定实际覆盖的范围**——**Critical / 有 Reviewer 运行时**：超出即 `[Verification Blocking]`；**Routine 无 Reviewer 时**：由人类判定，Author 须当场把声称收窄到已覆盖范围或撤回并报告风险（没有 Reviewer 可签发该分类，**不得因此静默拉一个进来**）。

> **来历（2026-08-15 实测）**：某任务 AC1/AC2（退出码类）四轮零缺陷；AC5/AC9/AC13（"Reviewer 对照…逐条核"、判定对象是散文清单的完整性）逐轮产出新 blocking，第 4 轮又挑出 7 条遗漏。**散文完整性永远可以再被挑出一条——拿它当 blocking 依据，等于在构造上把收敛做成不可能。**

## Reviewer verdict 分类语义（唯一定义处；**Reviewer 实际运行时适用**——分类语义与 Debt Verdict 取值两模式通用；**`caused_by_last_fix` 与 streak 计数仅 Critical**（Routine 无 Fix-Loop 账本，见 Mode Scope）。`~/.claude/workflow/reviewer-prompt.md` / `/final-review` 引用本节，不得产生冲突契约）

顶层输出字段保持不变（兼容 Codex 强制结构），语义分类如下：
* **Blocking Issues** 每条标 `[Product Blocking]`（用户可见正确性 / 用户数据错误 / 安全）或 `[Verification Blocking]`（验证不健全：probe 冒充证据、测试不走真实路径、审后弱化测试或改验收、绕过 validation/auth/删测试藏错），并由 **Reviewer** 标 `caused_by_last_fix: yes/no`（**仅 Critical** ——该字段只服务 Fix-Loop streak；Routine 无此账本，不填）。**只有 Blocking Issues（Product/Verification）默认阻止合并。**（**阻止合并 ≠ 计入硬停**：streak 只由 `[Product Blocking]` 递增，见「Fix-Loop 计数与跨轮硬停」；两审零 Product 时 Verification 的收口方式见「最后一轮独立审查门 → 证据层出口」。）
* **分类优先级（两类重叠时的唯一判据）**：**只要已造成或可能造成用户可见行为、用户数据或安全/隐私影响 → 一律 `[Product Blocking]`**，不论它同时是否符合 Verification 的举例。`[Verification Blocking]` **仅限没有产品影响的证据充分性缺陷**。故「为过测试而弱化认证/绕过 validation」属 **Product**（它改变了真实的安全行为），而「认证测试没走真实路径、但认证本身正确」属 Verification。**分类不得被用来规避硬停**——归类存疑时按 Product 记，交人类裁决。
* **Debt Verdict** 取值 **`Clean / Noted / Deferred`**（**无 "Blocking" 值**）：**Clean**=无债；**Noted**=**未触发** Payback-on-Touch 的普通存量债（行数债等，不阻止合并，**不得与用户数据错误等价**）；**Deferred**=触发 Payback-on-Touch 但**已获人类批准延期**（不阻止）——**Critical** 凭批准的 plan，**Routine** 凭对话内人类明确批准（见 Payback-on-Touch）。**触发 Payback-on-Touch 但未偿还、又无批准延期 → 不是 Process Debt，移入 Blocking Issues 标 `[Verification Blocking]`**（与本文件 Payback-on-Touch "otherwise must not be committed" 一致，消除矛盾）。
* **Review Verdict 语义**：Blocking Issues 非空 → **必须"不通过"**；"有条件通过"**不得**与任何 Product/Verification Blocking 并存；Process Debt、Suggestion 本身不影响"通过"。
* **不得把 Author 的自我总结 / "已修复" 叙述当作证据。**

## review-sensitive paths + SHA 绑定（唯一定义处；**仅 Critical**——Routine 无 SHA 账本，见 Mode Scope）

**该清单本身是 review-sensitive（2026-08-15 补）**：`review_sensitive_paths` 在双审窗口开启时即**冻结**——审后**不得缩窄**（移除条目、改窄 glob、把文件移出清单皆属缩窄）。清单本身的任何变更**使本轮审查失效**，须重跑；扩大清单同样须重跑（新纳入的路径未经审）。Reviewer 在审前快照自检时**逐字记录该清单原文**进 verdict 证据首行，落账时与 HANDOFF 比对；两者不一致 → 该轮作废。**理由**：出口与失效判定都以此清单为边界，清单可事后修改 = 边界可事后自定，整套绑定失去意义。

**review_sensitive_paths（审查/测试共用同一份精确 pathspec，每任务在 HANDOFF 显式列出）** 至少含：生产源码、tests、migrations/schema、构建配置 + 依赖声明 + lockfile、`docs/ai/TASK_BRIEF.md`、**整个 `docs/ai/IMPLEMENTATION_PLAN.md`**（含 Frozen Acceptance——用整文件，因无法对"某一节"做 Git pathspec）、`docs/ai/QUALITY_GATES.md`。**排除**：普通说明文档。**审查后弱化测试或修改验收标准 = `review_sensitive_paths` 变化 → 使审查失效。** **测试与审查用同一份 `review_sensitive_paths`（不另设单独的测试清单）。**

**SHA 绑定语义**（HANDOFF 记 `review_base_sha / review_tip_sha / review_verdict_9A / review_verdict_9B / tested_sha / handoff_snapshot_sha` + 该任务 `review_sensitive_paths`；`handoff_snapshot_sha` 由 **Author 在统一落账时记入**——快照 commit 本身无法自记自身 sha；**9A、9B 必须绑定同一个 `review_tip_sha`**，减档只跑 9A 时 `review_verdict_9B` 记 `N/A — 人类减档 + 原因`）：
* `review_tip_sha` / `tested_sha` **仅在**满足下列时才算有效快照绑定：① 所有 `review_sensitive_paths` 文件已进入对应 commit；② 这些路径无未提交修改；③ 这些路径无未跟踪文件。**带未提交/未跟踪的 review-sensitive 改动去跑正式测试或提审 = 不算 SHA 绑定，必须先形成明确的 reviewable commit。**
* **HANDOFF 与 last_test_run.txt 不在 `review_sensitive_paths` 内，按 `/implement` 顺序提交在 `review_tip_sha` 之后**（先更新 HANDOFF 再 docs commit）。故 **tip 里装的是过期 HANDOFF**：任何 Reviewer 都必须**从工作树读**这两个文件，禁止 `git show <review_tip_sha>:docs/ai/HANDOFF.md`。Author 在两份 review prompt 里写明同一个 `handoff_snapshot_sha`（= 双审窗口开启时的 HEAD）作为"同一份审前 HANDOFF"的凭证。**该凭证必须经 Reviewer 侧核验并落账为证据**——两份 verdict 各自记录 `observed_head_sha` + HANDOFF 与 last_test_run.txt 的 blob hash + 全工作树干净（命令与拒审规则唯一定义处：`~/.claude/workflow/reviewer-prompt.md` → 双审隔离协议 ⑤）；仅两份 prompt 数值相同**不构成**绑定。
* **失效判定用内容比对、非 HEAD 相等**（可执行）：`git diff --quiet <review_tip_sha> -- <review_sensitive_paths>` 且 `git diff --quiet <tested_sha> -- <review_sensitive_paths>` 且 `git status --porcelain -- <review_sensitive_paths>` 为空 → 审查/测试仍有效。**不在 `review_sensitive_paths` 内的纯文档提交改变 HEAD 不使审查失效。**

## Fix-Loop 计数与跨轮硬停（唯一定义处；**仅 Critical**——Routine 无 Fix-Loop 账本，其停手判据见「停止事件优先级」②。/debug、/final-review 引用）

* **递增（仅 Product 计数）**：某一轮**只要存在至少一个经确认的 `caused_by_last_fix: yes` 的 `[Product Blocking]`**，该轮 streak 计 1。**`[Verification Blocking]` 不计入 streak**——照常如实落账、照常修复，但**不触发硬停**。9A、9B **重复发现同一问题不重复计数**（按问题去重）。
  > 理由（2026-08-15 实测）：硬停的本意是防「修 A 坏 B」的产品级恶化。三个真实任务后段的 blocking 几乎全是 `[Verification]`（证据能否证明声称），多轮**双审零 `[Product]`**，却被自己的记账瑕疵逼到 streak=6 / 硬停。账本瑕疵与用户数据错误不同级，不应等价计数。
* **判定权与写入**：`caused_by_last_fix` **由 Reviewer 在其 verdict 里判定**；Author 只能把该值**逐字转录**进 HANDOFF（附 review 文件/轮次来源），**不得自行判断或改写**（Reviewer 对仓库零写入、verdict 产于仓外 holding——见 AI Collaboration Rules；故 HANDOFF 里的该字段只能由 Author 落账时逐字转录，Author 无裁定权）。Reviewer 标 `dispute` → **不自动计数、交人类裁决**。
* **重置**：某一轮无"修复引入的 `[Product Blocking]`"（该轮 0 计），streak 归 0。
* **停止（硬门）**：streak 连续达 **2** → **立即停止编码**，只能：回退 / 重新拆任务 / 请求人类批准架构升级；**禁止"再试一轮"**（未获人类确认不得继续）。
* **轮次上限（关闭阀，2026-08-15 新增）**：同一任务的双审达 **3 轮**仍未收敛 → **停止再审**，交人类在「带如实登记的限制交付 / 重新拆任务 / 回退」三者中裁决。**收敛不是唯一出口**——把"再审一轮"当默认出口，是四个真实任务全部停在 `stopped, NOT converged` 的直接原因（实测轮次：7 / 6 / 5 / 3）。人类可明确批准延长，但延长须逐次批准，不得默认。
* **三者优先级（硬停 / 轮次上限 / 合并门，唯一判据）**：① **硬停优先于轮次上限**——streak 达 2 时只能走硬停的三条出路，不得改走"限制交付"。② **合并门优先于一切出口**——存在**未解决的 `[Product Blocking]`（含任何安全/隐私影响）** 时，「带限制交付」**不含合并**：可以停、可以记账、可以移交，**不得合入 main**。③ 无论走哪条出口，只要没过收敛门，一律记 `stopped, NOT converged`，**不得**标 Ready to Commit / 已收敛。「限制交付」的合法含义仅限：**零未解决 Product Blocking**，剩余 Verification 项已如实登记并经人类确认。

## 最后一轮独立审查门（唯一定义处；**仅 Critical**——Routine 无双审与收敛门）

标记"已收敛 / Ready to Commit"要求：**最后一轮所有 review-sensitive 生产改动都已被独立审查**（当前 review-sensitive 内容 == `review_tip_sha`，且**本轮实际跑过的每一份 verdict 都 = 通过**——默认双审即 `review_verdict_9A` 与 `review_verdict_9B` 皆通过；减档只跑 9A 时 9B 记 N/A + 减档原因）。**人类因成本叫停 ≠ 质量通过**：记为 `stopped, NOT converged`，未经审代码**不得**标已收敛/已提交。

**证据层出口（2026-08-15 新增，斩断无限回归）**：若某轮**两审均零 `[Product Blocking]`**，则其剩余 `[Verification Blocking]` 的修复**可由人类确认后直接收口**，不再要求为此另跑一整轮独立审查（HANDOFF 记「人类确认收口 + 所修条目」）。

**与收敛门的衔接（否则本出口是死条文）**：含 `[Verification Blocking]` 的 verdict 按分类语义必然为「不通过」，故收敛门"每份 verdict 皆通过"在本出口生效时的**等价满足条件**为：① 该轮两审**零 `[Product Blocking]`**；② 剩余 Verification 项的修复**全部落在下述文件范围内**；③ 人类逐条确认并在 HANDOFF 落账（列出条目 + 确认人 + 日期）。三条同时成立才可标「已收敛」，缺一条则仍为 `stopped, NOT converged`。**本条是收敛门的唯一例外，不得类推扩大。**

**出口的文件范围（硬边界，不可解释放宽）**：本出口**只覆盖 `review_sensitive_paths` 之外的纯账目修正**——HANDOFF 措辞与计数、叙述性文档、落账格式等。**凡修改落在 `review_sensitive_paths` 内**（**范围只以本文件 → review-sensitive paths + SHA 绑定 的必含清单为准，此处不复述类别**）**一律仍须独立复审**，即使该 blocking 被标为 Verification。**本出口对任何 `[Product Blocking]` 一律不适用。**
> 反滥用示例（本出口明令禁止的用法）：Reviewer 报「认证测试没走真实路径」→ Author 改测试或认证配置 → 人类确认后不再审即标收敛。**改动落在 tests / 配置内 = review-sensitive，必须复审**；出口给的是"不必为改一句 HANDOFF 措辞再跑一整轮"，不是"人类确认可替代独立审查"。
> 理由（2026-08-15 实测）：证据层修复本身会产出新的证据层瑕疵，若每次都要求再审一轮，只要 Reviewer 在证据层永远挑得出一条，收敛在构造上就不可能——某任务第 7 轮两审双双「不通过」，争的是**一条文档计数**，其修复方式是把手写计数整条删掉。

## review-fix 最小生产范围（Safety Rule 补充；**两模式恒适用**——其中「双审窗口结束后」仅 Critical）

Review-fix 由 **Author 在双审窗口结束后**执行（Reviewer 不改代码，见 AI Collaboration Rules），且**只允许改当前 blocking 所需的最小生产范围**。要新增模块 / 改公共接口 / 扩大架构 → **停止并重新计划**（走 /plan），不在 fix 循环里做。

## Git Discipline（**按模式取**：Critical 全程强制；Routine 不建任务分支、不由 Agent commit——人类扫 diff 后 commit/merge）

* 任务开始从主分支建任务分支：`git checkout -b task/[简短任务名]`。
* 阶段性 commit 强制：计划批准由人类 commit（即批准凭证）；Author 实现 `wip(author): ...`；交接产物（`last_test_run.txt` + `HANDOFF.md`）在 HANDOFF 更新完毕后单独 `docs(handoff): ...`；review 修复 `wip(review-fix): ...`（**由 Author 在双审窗口结束后创建**）。
* 回滚 = revert 对应 commit；Reviewer 审的是明确 commit range；最终由人类 squash。
