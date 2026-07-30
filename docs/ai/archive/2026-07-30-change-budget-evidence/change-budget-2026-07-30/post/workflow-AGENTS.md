# AGENTS.md

> 本文件是项目长期规则与**禁止事项的唯一出处**，以及全流程所有重复硬规则（Reviewer 轻量协议、`[DEBT]` 格式、证据/假设标签）的**单一定义处**。其他文件和 prompt 只引用本文件，不再罗列，引用写法："Follow the Safety Rules in AGENTS.md" / "Follow the Reviewer-Lightweight Protocol in AGENTS.md"。
> 已存在则先读再增量更新，永不覆盖重写。

## Project Overview

项目是什么、技术栈、主要目录。[填写]

## Build / Test / Lint Commands

只列项目中真实存在的命令，不存在的不要编造。[填写]

## Code Style Rules

命名规则、目录结构、格式化工具、测试习惯、错误处理方式。[填写]

## Safety Rules

* Do not remove or skip tests to make them pass.
* Do not comment out core logic to bypass errors.
* Do not bypass validation, authentication, or error handling.
* Do not introduce new dependencies unless the plan explicitly approves it.
* Do not do unrelated refactors. Keep changes minimal and task-scoped. (Scoping only — this constrains touching *unrelated* code, NOT which approach you pick: select the globally-best, durable approach per CLAUDE.md → Decision Making, then keep the diff scoped to it. "Minimal" ≠ pick the smallest/laziest solution.)
* Do not modify lockfiles unless dependencies actually changed.
* Do not commit secrets, tokens, or API keys.
* Do not claim tests passed without writing actual output to docs/ai/last_test_run.txt.
* Do not state uncertain conclusions as certain.
* Do not perform destructive operations without stating the risk first.
* Never edit the Human Approval Status field in IMPLEMENTATION_PLAN.md.

## Reviewer-Lightweight Protocol（唯一定义处）

> 背景（2026-06-10 Codex 配额事故）：Codex 沙箱读不了 node_modules(EPERM)；若允许它"自己验证"会用 git archive 重建整仓 + 重装依赖 + 每轮最高档重跑全量测试，一天耗尽配额。

每个 review / re-review prompt 必须原样包含这句：

> **不要 git archive 重建副本、不要重装依赖、不要重跑全量测试——以 docs/ai/last_test_run.txt 产物 + 读 git diff 推理为准；需要验证的具体行为列出来，由 Author 在正常终端代跑。**

执行规则：
* Reviewer 一切结论只基于：交接文件 + git diff + last_test_run.txt。
* 对 last_test_run.txt"批判性地读"：命令是否真实存在、输出是否完整、结论是否与输出一致——不自己重跑复核。
* 必须实跑才能下结论的，写进输出的 Verification Needed，由 Author 代跑、追加输出、再 re-review。
* scratch 清理归属：**Reviewer 不删除仓库工作树内的任何文件**；仓内遗留的 review-* / .codex-review-* scratch 由 **Author 在人类确认后清理**；Reviewer 只清理自己仓外 holding 里的临时产物。

## No-Hidden-Debt + [DEBT] 格式（唯一定义处）

Any compromise made just to "get it working / save time" (simplification, hardcoding, skipped edge case, temporary workaround) has only two legal exits:

* (a) fix it now, or
* (b) record one line in the current task's `docs/ai/HANDOFF.md` "Remaining Risks", in this exact format:

```
[DEBT] <one-line description> | Payback trigger: <which file/module, when next touched, must repay first> | Impact: <what happens if unpaid>
```

Banned vague phrasings that hide a compromise as untracked debt (their presence = unregistered debt, review sends it back):
`later / temporary / for now / should be fine / probably ok / 暂时 / 先这样 / 回头再说 / a TODO or known-issue without a payback trigger`.

（Plain code TODO comments still follow the global rule — they go to plan/TODO docs, not this debt log; but a code TODO that actually hides a compromise must ALSO be registered here as a [DEBT] line.）

## Payback-on-Touch（唯一强制偿还机制，优先于任何 due date）

Before modifying a file/module, scan the current `docs/ai/HANDOFF.md` plus `docs/ai/archive/**/HANDOFF.md` ("Remaining Risks / Debt" sections). A `[DEBT]` Payback trigger must name a concrete file/module path or glob. If a trigger matches the file/module you are about to touch, repay that debt in the same commit (or explicitly request to downgrade/defer it in the plan, with a reason); otherwise this change must not be committed. Debt does not follow a list — it follows the code and finds you the next time you touch it.

## 证据 vs 假设标签（反脑补，唯一定义处）

任何关于用户/市场/需求的判断必须区分「证据」与「假设」，不得把假设当事实：

* 每条判断后紧跟标注：`[证据] <来源>`（访谈/数据/现有反馈/竞品事实）或 `[假设]`。
  * 例：`用户每天手工导出报表 3 次以上 [证据] 来自 5 次访谈`
  * 例：`用户愿为自动化付费 [假设]`
* 所有 `[假设]` 进待验证清单并写明最低成本验证方式；没有验证方式的 `[假设]` = 脑补，审查打回。
* 标「唯一依据 = 是」的高影响假设，进入实现前必须已验证转 `[证据]` 或显式降级；否则计划停在 Pending。

## AI Collaboration Rules

* The Author agent plans, implements, fixes tests, and updates docs/ai/HANDOFF.md.
* The Reviewer agent reviews the git diff independently. It never implements anything — every fix, including for a blocking issue it found, is made by the Author after the dual-review window closes.
* Before any work, read docs/ai/HANDOFF.md and docs/ai/last_test_run.txt.
* After implementing or fixing, the Author updates docs/ai/HANDOFF.md and re-runs tests with output piped to docs/ai/last_test_run.txt.
* **The Reviewer writes NOTHING into the repository — not even HANDOFF.md, and never a commit.** Its verdict goes to the out-of-tree holding file the Author passes via `codex exec -o` (see reviewer-prompt.md → 双审隔离协议). It never runs tests — it lists what to verify under "Verification Needed" for the Author to run. Any fix, including `wip(review-fix)`, is made by the **Author after the dual-review window closes**.
* **双审窗口冻结（9A/9B 真独立的前置）**：从第一个 Reviewer 启动到两份 verdict 都产出为止，Author 与两个 Reviewer 都不得改生产代码 / `review_sensitive_paths` / HANDOFF，也不得 commit。两份 verdict 分开保存、互不可见（9B 先跑，不接收 9A 输出）；两份都完成后 Author 才**一次性**更新 HANDOFF。协议全文与调用范式见 `reviewer-prompt.md` → 双审隔离协议（唯一定义处）。

## 验证三分类（唯一定义处）

任何"验证"必须归入三类，混用即无效：
* **Acceptance test（验收测试）**：证明"需求规定的性质在真实生产路径上成立"。预期值来自 TASK_BRIEF / 接口契约 / 批准计划 / 人工确认——**禁止从当前实现反推**。
* **Regression test（回归测试）**：锁定已确认缺陷或既有行为；预期同样来自验收契约或已确认缺陷，非反推自实现。
* **Diagnostic probe（诊断探针）**：临时定位用（一次性脚本 / mutation harness / 红探针 / instrumentation）。**只能定位、不得作为完成证据**，**提交前删除**；其中值得长期保留的行为 → **重写为正式 regression test** 再留。

**Author 不得自证**：自编 mutation harness / 红探针 / "删码后测试变红" **不能单独证明实现正确**——Reviewer 须复核：变异内容 + 目标测试确实执行 + 具体失败原因。守护证据的产物契约见下节「守护有效性装置」。

## 守护有效性装置（唯一定义处；「回归用例有效」的证据契约）

> 实证依据：2026-07-28 翻译项目 4 个空守护测试（删掉被守护代码测试仍绿）致全绿闸门失效、整轮回退；2026-07-29 SeedLink turbo 缓存回放假通过（`TURBO_FORCE=true` 才暴露）。

* **义务**：需要声称「回归用例有效（红→绿）」的项目必须提供**技术栈适配的守护有效性命令/脚本**（常驻脚手架；命令名项目自定，记录在项目文档与 HANDOFF）。**该声称的唯一可接受证据 = 装置产出的结构化产物**——不接受自然语言自述（含"删码变红"口头叙述）。
* **协议**：基线绿 → 撤销或变异目标生产行为 → 目标测试红 → 还原（内容哈希验证）→ 复绿；全程由装置执行并记录。
* **产物必填字段**：① 目标测试（文件 + 用例名）；② 被撤销/变异的生产行为（逐文件）；③ 基线绿退出码；④ 负向运行退出码；⑤ 预期失败断言/原因；⑥ 恢复后绿退出码 + 还原哈希验证结果；⑦ tested_sha（产物绑定被测 commit——tested_sha 失效连带产物失效，按 SHA 绑定语义回炉）；⑧ 执行真实性证据（证明测试确实执行而非缓存回放：缓存旁路方式或"无缓存层"说明，**按构建系统提供**——Turborepo 项目用 `TURBO_FORCE=true` 只是实例，直跑 runner 的记"无缓存层"；不存在跨技术栈唯一方式）。
* **失败判据**（任一不满足 → 产物不构成守护证据）：
  1. 负向运行必须**因目标测试的预期断言**而红——编译/加载失败、环境失败、目标测试未执行、仅无关测试失败均不算；
  2. 红/绿判定以**真实退出码**为准，**禁止 grep 关键词判红**；解析 runner 输出仅用于确认"哪个测试、因何断言失败"；
  3. 还原必须经内容哈希验证，且恢复后重跑变绿；
  4. 产物含执行真实性证据（字段 ⑧）。
* **无装置项目**：不得把该能力写成已启用；装置落地前「回归用例有效」= 未证明——列 Reviewer Verification Needed 并记 `[DEBT]`（Payback trigger：下次需要守护证据时先落地装置），或在当前任务顺带落地装置。
* **与验证三分类的边界**：装置及其变异 spec 是**常驻项目脚手架**，不属 diagnostic probe；运行期变异必须还原并产物化。Author 不得自证规则保持不变——Reviewer 不运行装置，只核产物完整性与字段自洽（见 reviewer-prompt 9A）。

## Reviewer verdict 分类语义（唯一定义处；reviewer-prompt / final-review 引用本节，不得产生冲突契约）

顶层输出字段保持不变（兼容 Codex 强制结构），语义分类如下：
* **Blocking Issues** 每条标 `[Product Blocking]`（用户可见正确性 / 用户数据错误 / 安全）或 `[Verification Blocking]`（验证不健全：probe 冒充证据、测试不走真实路径、审后弱化测试或改验收、绕过 validation/auth/删测试藏错），并由 **Reviewer** 标 `caused_by_last_fix: yes/no`。**只有 Blocking Issues（Product/Verification）默认阻止合并。**
* **Debt Verdict** 取值 **`Clean / Noted / Deferred`**（**无 "Blocking" 值**）：**Clean**=无债；**Noted**=**未触发** Payback-on-Touch 的普通存量债（行数债等，不阻止合并，**不得与用户数据错误等价**）；**Deferred**=触发 Payback-on-Touch 但**已获人类批准延期**（不阻止）。**触发 Payback-on-Touch 但未偿还、又无批准延期 → 不是 Process Debt，移入 Blocking Issues 标 `[Verification Blocking]`**（与本文件 Payback-on-Touch "otherwise must not be committed" 一致，消除矛盾）。
* **Review Verdict 语义**：Blocking Issues 非空 → **必须"不通过"**；"有条件通过"**不得**与任何 Product/Verification Blocking 并存；Process Debt、Suggestion 本身不影响"通过"。
* **不得把 Author 的自我总结 / "已修复" 叙述当作证据。**

## review-sensitive paths + SHA 绑定（唯一定义处）

**review_sensitive_paths（审查/测试共用同一份精确 pathspec，每任务在 HANDOFF 显式列出）** 至少含：生产源码、tests、migrations/schema、构建配置 + 依赖声明 + lockfile、`docs/ai/TASK_BRIEF.md`、**整个 `docs/ai/IMPLEMENTATION_PLAN.md`**（含 Frozen Acceptance——用整文件，因无法对"某一节"做 Git pathspec）、`docs/ai/QUALITY_GATES.md`。**排除**：普通说明文档。**审查后弱化测试或修改验收标准 = `review_sensitive_paths` 变化 → 使审查失效。** **测试与审查用同一份 `review_sensitive_paths`（不另设单独的测试清单）。**

**SHA 绑定语义**（HANDOFF 记 `review_base_sha / review_tip_sha / review_verdict_9A / review_verdict_9B / tested_sha / handoff_snapshot_sha` + 该任务 `review_sensitive_paths`；`handoff_snapshot_sha` 由 **Author 在统一落账时记入**——快照 commit 本身无法自记自身 sha；**9A、9B 必须绑定同一个 `review_tip_sha`**，减档只跑 9A 时 `review_verdict_9B` 记 `N/A — 人类减档 + 原因`）：
* `review_tip_sha` / `tested_sha` **仅在**满足下列时才算有效快照绑定：① 所有 `review_sensitive_paths` 文件已进入对应 commit；② 这些路径无未提交修改；③ 这些路径无未跟踪文件。**带未提交/未跟踪的 review-sensitive 改动去跑正式测试或提审 = 不算 SHA 绑定，必须先形成明确的 reviewable commit。**
* **HANDOFF 与 last_test_run.txt 不在 `review_sensitive_paths` 内，按 `/implement` 顺序提交在 `review_tip_sha` 之后**（先更新 HANDOFF 再 docs commit）。故 **tip 里装的是过期 HANDOFF**：任何 Reviewer 都必须**从工作树读**这两个文件，禁止 `git show <review_tip_sha>:docs/ai/HANDOFF.md`。Author 在两份 review prompt 里写明同一个 `handoff_snapshot_sha`（= 双审窗口开启时的 HEAD）作为"同一份审前 HANDOFF"的凭证。**该凭证必须经 Reviewer 侧核验并落账为证据**——两份 verdict 各自记录 `observed_head_sha` + HANDOFF 与 last_test_run.txt 的 blob hash + 全工作树干净（命令与拒审规则唯一定义处：reviewer-prompt.md → 双审隔离协议 ⑤）；仅两份 prompt 数值相同**不构成**绑定。
* **失效判定用内容比对、非 HEAD 相等**（可执行）：`git diff --quiet <review_tip_sha> -- <review_sensitive_paths>` 且 `git diff --quiet <tested_sha> -- <review_sensitive_paths>` 且 `git status --porcelain -- <review_sensitive_paths>` 为空 → 审查/测试仍有效。**不在 `review_sensitive_paths` 内的纯文档提交改变 HEAD 不使审查失效。**

## Fix-Loop 计数与跨轮硬停（唯一定义处；/debug、/final-review 引用）

* **递增**：某一轮**只要存在至少一个经确认的 `caused_by_last_fix: yes` 的 Product/Verification Blocking**，该轮 streak 计 1。9A、9B **重复发现同一问题不重复计数**（按问题去重）。
* **判定权与写入**：`caused_by_last_fix` **由 Reviewer 在其 verdict 里判定**；Author 只能把该值**逐字转录**进 HANDOFF（附 review 文件/轮次来源），**不得自行判断或改写**（Reviewer 对仓库零写入、verdict 产于仓外 holding——见 AI Collaboration Rules；故 HANDOFF 里的该字段只能由 Author 落账时逐字转录，Author 无裁定权）。Reviewer 标 `dispute` → **不自动计数、交人类裁决**。
* **重置**：某一轮无"修复引入的 Product/Verification Blocking"（该轮 0 计），streak 归 0。
* **停止（硬门）**：streak 连续达 **2** → **立即停止编码**，只能：回退 / 重新拆任务 / 请求人类批准架构升级；**禁止"再试一轮"**（未获人类确认不得继续）。

## 改动面预算（唯一定义处；/plan、/implement、/debug、/final-review、reviewer-prompt 引用本节，不得另行定义）

> 实证依据：2026-07-30 守护有效性契约任务——3 轮 16 条 blocking 全为 `caused_by_last_fix: no` 的**范围膨胀型审查循环**（审查不断加深攻击面而非修复引入回归），Fix-Loop 硬停（只管修复引入回归）无从触发，靠人类收敛裁决令终止；该任务 TASK_BRIEF 的允许路径白名单与 Threat Model 节是本节前身（流程产物两次经人类追认补入白名单 = 「标准流程产物清单」的由来）。

* **任务预算（计划期声明；SSOT = TASK_BRIEF，9B 可见）**：/plan 期由 Author 起草、随计划一并经人类批准，写入 `docs/ai/TASK_BRIEF.md` 的「Change Budget & Allowed Paths」节。维度：① 允许 pathspec（白名单，须能直接喂 `git status/diff -- <pathspec>`）；② 生产文件/模块清单；③ 公共接口变化（新增/修改的导出、API、schema；默认零）；④ 触及架构层；⑤ 依赖与迁移变化（默认零；含 lockfile）；⑥ 生产代码 LOC 量级——**仅预警量**：超出记 HANDOFF 偏差并提醒人类，**不作质量判据**。批准后的预算/允许路径/威胁模型**只定义在 TASK_BRIEF**：PLAN 只解释实施方式（Proposed Changes 逐文件清单须与预算一致），HANDOFF 只记实际消耗与偏差（Change Budget Ledger），两处均不得重复定义。**核对基准双轨**：9B 依据 TASK_BRIEF（Acceptance + Change Budget + Threat Model）；9A additionally 依据 PLAN 的 Frozen Acceptance——不得要求 9B 核对 PLAN 内容（9B 禁读 PLAN）。
* **标准流程产物清单（/plan 起草义务；非隐式豁免）**：清单 = per-task 交接文件 TASK_BRIEF / IMPLEMENTATION_PLAN / HANDOFF、last_test_run.txt、review_9A*/9B* 落账文件、守护有效性装置产物、归档移动（**约束的是归档动作发生于当前任务生命周期**，被归档文件可来自上一任务；**写入批准 pathspec 时须同时列出源路径与归档目标路径**——Git rename 的 diff 两端都体现）；资格四条限定缺一不可——① 标准文件类型；② 位于标准目录（`docs/ai/` 及其 `archive/`）；③ 当前任务生命周期内生成；④ 不含生产逻辑或额外需求。**该清单是起草义务而非豁免**：正式流程由 /plan 将其逐项写入 TASK_BRIEF 允许 pathspec、随计划经人类批准。**Reviewer 只按批准 pathspec 核对，不承认任何隐式并集**；新产物类型或非标准位置仍需人类追认——清单不得成为"冠以归档/证据名义绕过预算"的通道。
* **fix 预算（每 review-fix 轮）**：允许面 = 当前 blocking 所需**最小生产范围**，且 ⊆ 任务预算 pathspec；每轮在 HANDOFF 的 Fix-Loop Counter 记录**相对上一 review tip 新增触碰的文件/接口**。**扩面判据（机械）= 任何已批准预算维度发生变化（LOC 量级维度除外——仅预警路径，不触发扩面）**，至少含：新文件 / 新模块 / 新公共接口、新架构层、新依赖 / lockfile / 迁移变化、pathspec 外文件——任一即扩面。
* **超预算 / 扩面处置**：立即停止 → 上报人类 → 回 `/plan` 修订 TASK_BRIEF 预算节并经人类重新批准后才可继续；**白名单修订必须人类追认，Author 不得自扩**。
* **收敛预算（补 Fix-Loop 盲区：`caused_by_last_fix: no` 型范围膨胀）**：默认阈值 = **3 个有效且未收敛的任务审查轮**（人类可在 TASK_BRIEF 改值）。**计数口径**：计数对象 = 对本任务改动面的**正式审查轮**——两份 verdict 完成统一落账且双审隔离成立的轮（人类批准的减档单审仅在正式替代该任务的一轮审查时计 1）；**演练、探针及验证性调用不计；作废轮（隔离破损/快照不一致/重跑）不计**；计数跨轮累计，仅在人类裁决进入新批准周期（收敛裁决令或回 /plan 重批）后归零。**达到阈值 → 只能**：冻结「新可选要求 / 新超界加固」（Reviewer 仍必须继续报告违反既有验收、Safety Rules、真实用户/数据安全的问题——**冻结不封缺陷**）+ 保留全部未解决 blocking 原样上交 + 人类收敛裁决 / 重新规划 / 换上下文。**禁止**：降级缺陷、据此标 Ready to Commit——「最后一轮独立审查门」的 `stopped, NOT converged` 语义不变。
* **威胁模型定界**：TASK_BRIEF 必含「Threat Model」节（骨架见 templates/TASK_BRIEF.md），是安全类审查要求的解释边界。**超出威胁模型的可选加固默认记入 Non-Blocking Suggestions 并交人类，不得判 Blocking**（不用 "Noted" 一词——避免与 Debt Verdict 的 Noted 值撞词）；但以下五项**仍可判 Blocking**：① Reviewer 证明威胁模型本身错误（附证据）；② 违反 AGENTS Safety Rules；③ 违反 QUALITY_GATES 适用安全闸门（含 11.2 恒查基础安全）；④ 违反该 Reviewer 可见且有权核对的批准验收（9B 核对 TASK_BRIEF Acceptance；9A 另核对 PLAN Frozen Acceptance）；⑤ 真实用户与数据安全问题。
* **快速版（临时 fail-safe）**：快速版预算契约由独立任务定稿中；在此之前：快速版任务只要触及 `review_sensitive_paths`，必须升级走正式流程（TASK_BRIEF 预算）；快速版代码审查路径暂停。

## 最后一轮独立审查门（唯一定义处）

标记"已收敛 / Ready to Commit"要求：**最后一轮所有 review-sensitive 生产改动都已被独立审查**（当前 review-sensitive 内容 == `review_tip_sha`，且**本轮实际跑过的每一份 verdict 都 = 通过**——默认双审即 `review_verdict_9A` 与 `review_verdict_9B` 皆通过；减档只跑 9A 时 9B 记 N/A + 减档原因）。**人类因成本叫停 ≠ 质量通过**：记为 `stopped, NOT converged`，未经审代码**不得**标已收敛/已提交。

## review-fix 最小生产范围（Safety Rule 补充）

Review-fix 由 **Author 在双审窗口结束后**执行（Reviewer 不改代码，见 AI Collaboration Rules）。允许范围、扩面判据与处置一律**以「改动面预算（唯一定义处）」的 fix 预算为准**——本节为纯指针，不复述任何判据。

## Git Discipline（全程强制）

* 任务开始从主分支建任务分支：`git checkout -b task/[简短任务名]`。
* 阶段性 commit 强制：计划批准由人类 commit（即批准凭证）；Author 实现 `wip(author): ...`；交接产物（`last_test_run.txt` + `HANDOFF.md`）在 HANDOFF 更新完毕后单独 `docs(handoff): ...`；review 修复 `wip(review-fix): ...`（**由 Author 在双审窗口结束后创建**）。
* 回滚 = revert 对应 commit；Reviewer 审的是明确 commit range；最终由人类 squash。
