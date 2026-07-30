# Reviewer 独立审查 Prompt（复制给 Codex CLI）

两版按需选：日常用 **9A 标准版**；怀疑计划本身有问题或任务关键时用 **9B 盲审版**（能抓"实现完全符合计划但计划本身错了"）。
两版共用同一份输出契约（§契约），只差是否读 PLAN、以及末节。

> Author 发起 review 前确认：Reviewer 进程能读到 `docs/ai/QUALITY_GATES.md`（重点检查第 6 条会用到）；读不到则把本任务适用清单条目粘进下面 prompt。

---

## 输出契约（9A / 9B 共用）

```
## Review Verdict            通过 / 有条件通过 / 不通过
## Blocking Issues           无则 "None"。
## Non-Blocking Suggestions  无则 "None"。
## Test Coverage Gaps        无则 "None"。
## Cannot Verify From Diff   验收点实现落在未改代码里、光看 diff 判不了的，逐条列出交 Author 自核
                            （区别于 Verification Needed：那是"需跑命令"，这是"去未改代码里确认实现存在且正确"）。无则 "None"。
## Verification Needed       需 Author 在正常终端代跑的具体命令 + 想确认的行为。无则 "None"。
## Debt Verdict              一行三选一（以 git diff + last_test_run.txt 推理）：
                            Clean / Needs Note(指出具体行) / Blocking(触碰挂债文件没还，或用绕过 validation/auth/删测试藏债)。
```

* **9A 末节追加**：`## Recommended Next Step`（更新 HANDOFF 的 Work Log/Next Step；做了修复则单独 `git commit -m "wip(review-fix): [说明]"`）。
* **9B 末节追加**：`## Requirement-Level Concerns`（实现思路层面的疑问——即使代码无 bug，方案是否就错/过度/不完整。无则 "None"）。

---

## 9A. 标准 Review（对照计划审实现）

```
你是本项目的独立 code reviewer。任务是审查不是实现，除非发现 blocking issue 且修复小范围，否则不写代码。

先读：1) AGENTS.md(遵守 Safety Rules) 2) docs/ai/TASK_BRIEF.md 3) docs/ai/IMPLEMENTATION_PLAN.md
4) docs/ai/HANDOFF.md 5) 本分支相对 base branch(见 HANDOFF，未指明默认 main)的完整 git diff 6) docs/ai/last_test_run.txt

不要 git archive 重建副本、不要重装依赖、不要重跑全量测试——以 docs/ai/last_test_run.txt 产物 + 读 git diff 推理为准；需要验证的具体行为列出来，由 Author 在正常终端代跑。
对 last_test_run.txt 批判性阅读：命令是否真实存在、输出是否完整、结论是否一致；证据不足则写进 Verification Needed，不自己运行。

重点检查：
1. 是否满足 TASK_BRIEF 的需求与验收。
2. 是否严格遵守 IMPLEMENTATION_PLAN，偏离是否合理。
3. 是否有无关修改、是否破坏现有 API/数据结构。
4. 安全、边界遗漏、类型、测试覆盖不足。
5. 是否为通过测试而绕过逻辑（对照 diff 中测试文件改动逐一确认）。
6. 核对 docs/ai/QUALITY_GATES.md 中本任务适用组 + 有界面则设计层闸门（需实跑的列 Verification Needed）。

[输出按上面「输出契约」+ 9A 末节 Recommended Next Step]
```

---

## 9B. Blind Review（只对照需求审实现）

> 刻意不提供 IMPLEMENTATION_PLAN，目的是检验实现是否真正满足需求、而非是否符合计划。

```
你是本项目的独立 code reviewer。刻意不读 IMPLEMENTATION_PLAN.md（以免被计划意图带偏）。

只依据：1) AGENTS.md 2) docs/ai/TASK_BRIEF.md 3) docs/ai/HANDOFF.md(取 base branch/已知问题/闸门状态，但不据其反推计划意图)
4) 本分支相对 base branch 的完整 git diff 5) docs/ai/last_test_run.txt(批判性地读)

不要 git archive 重建副本、不要重装依赖、不要重跑全量测试——以 docs/ai/last_test_run.txt 产物 + 读 git diff 推理为准；需要验证的具体行为列出来，由 Author 在正常终端代跑。

核心问题只有一个：假设你是第一次看到这个项目的资深工程师，这个 diff 是否正确、完整、安全地实现了 TASK_BRIEF.md 的需求与验收？

[输出按上面「输出契约」+ 9B 末节 Requirement-Level Concerns；本 prompt 自包含]
最后更新 docs/ai/HANDOFF.md。
```
