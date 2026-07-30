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
* Do not do unrelated refactors. Keep changes minimal and task-scoped.
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
* review 结束删除 Reviewer 的 review-* / .codex-review-* scratch 目录（删前经人类确认）。

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
* The Reviewer agent reviews the git diff independently. It does not implement features unless fixing a blocking issue it found.
* Before any work, read docs/ai/HANDOFF.md and docs/ai/last_test_run.txt.
* After implementing or fixing, the Author updates docs/ai/HANDOFF.md and re-runs tests with output piped to docs/ai/last_test_run.txt.
* The Reviewer edits only HANDOFF.md, with one exception: a small, scoped review-fix commit for a blocking issue it found. Even after a review-fix it never runs tests — it lists what to verify under "Verification Needed" for the Author to run.

## Git Discipline（全程强制）

* 任务开始从主分支建任务分支：`git checkout -b task/[简短任务名]`。
* 阶段性 commit 强制：计划批准由人类 commit（即批准凭证）；Author 实现 `wip(author): ...`；review 修复 `wip(review-fix): ...`。
* 回滚 = revert 对应 commit；Reviewer 审的是明确 commit range；最终由人类 squash。
