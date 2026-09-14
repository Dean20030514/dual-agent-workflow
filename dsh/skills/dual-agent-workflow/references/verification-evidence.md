---
name: verification-evidence
description: Use when a claim needs proof in DSH — labelling evidence vs assumptions, classifying a test as acceptance/regression/diagnostic probe, producing guard-effectiveness (mutation) evidence with negative controls, applying the per-task diff budget, setting up the DSH subagent/workflow fan-out within its cap, or writing test output to docs/ai/last_test_run.txt.
whenToUse: Load before claiming "tests pass"/"this guards against X"/"the mechanism rejects Y", before a fan-out of subagents or workflows, or when deciding how much diff a single round may carry.
---

# 验证、守护证据与派发纪律（DSH 执行手册）

> **判据唯一定义处**：`~/.dsh/workflow/AGENTS.md`（守护有效性装置 / 验证三分类 / 验收条款必须可复现判定 / 单轮任务 diff 预算 / 证据 vs 假设标签）。本文件是执行手册：怎么摆一条能通过审查的证据。
> **工具面事实**：`~/.dsh/workflow/fanout-toolchain.md`。

## 1. 证据先于断言（两模式恒适用）

任何"通过了 / 修好了 / 能满足"的说法，必须附**真实执行的命令 + 完整输出 + 退出码**。

* **Routine**：在对话里展示真实命令、完整输出、退出码。
* **Critical**：真实输出写进 `docs/ai/last_test_run.txt`；Reviewer 只读它 + `git diff`，**不重跑**。
* **测试没跑就说没跑**，不得用推理代替执行结论；失败要如实报。
* **不确定就标注**：关于用户/市场/需求的判断一律 `[证据] <来源>` 或 `[假设]`，`[假设]` 必须附**最低成本验证方式**；没有验证方式的假设 = 脑补，审查打回。标「唯一依据 = 是」的高影响假设，进入实现前必须转 `[证据]` 或显式降级，否则不得进入实现。
* **一手来源**：AI 能力、工具行为、模型档位等断言必须指回官方文档 / changelog / 源码（模型档位用 `list_subagent_models` 的实时目录，别凭记忆）。

## 2. 验证三分类（混用即无效）

| 类别 | 证明什么 | 预期值来源 | 能否作为完成证据 |
|---|---|---|---|
| **Acceptance test** | 需求规定的性质在**真实生产路径**上成立 | TASK_BRIEF / 接口契约 / 批准计划 / 人工确认——**禁止从当前实现反推** | 能 |
| **Regression test** | 锁定已确认缺陷或既有行为 | 验收契约或已确认缺陷，非反推自实现 | 能 |
| **Diagnostic probe** | 临时定位（一次性脚本 / 变异 harness / 红探针 / instrumentation） | — | **不能**；**提交前删除**，值得长期保留的行为要**重写成正式 regression test** |

**Author 不得自证**：自编 mutation harness / 红探针 / "删码后测试变红"**不能单独证明实现正确**——须由 Author 之外的一方复核三项：**变异内容** + **目标测试确实执行** + **具体失败原因**。Critical 由 Reviewer 复核；Routine 把这三项连同完整输出与退出码展示在对话里、由**人类**确认（**不得为此静默拉一个 Reviewer 进来，也不得因此升级模式或创建 Critical 产物**）。

## 3. 守护有效性装置（"回归用例有效"的唯一可接受证据）

> 判据两模式恒适用，**证据形式按模式取**。实证来源：2026-07-28 四个空守护测试（删掉被守护代码测试仍绿）致全绿闸门失效；2026-07-29 缓存回放假通过。

**协议**：基线绿 → 撤销/变异目标生产行为 → 目标测试**因预期断言**而红 → 还原（内容哈希验证）→ 复绿。

* **Critical**：必须由**常驻装置**执行并产出结构化产物，**八项必填字段**：① 目标测试（文件 + 用例名）；② 被撤销/变异的生产行为（逐文件）；③ 基线绿退出码；④ 负向运行退出码；⑤ 预期失败断言/原因；⑥ 恢复后绿退出码 + 还原哈希验证结果；⑦ 生成时 commit（产物绑定被测**内容**：`git diff --quiet <该 commit> <tested_sha> -- <①的测试文件> <②的生产文件>` 退出 0 即仍有效，**不要求 sha 相等**）；⑧ 执行真实性证据（缓存旁路方式或"无缓存层"说明，**按构建系统提供**——Turborepo 用 `TURBO_FORCE=true` 只是实例，直跑 runner 记"无缓存层"）。**不接受自然语言自述**（含"删码变红"口头叙述）。
* **Routine**：没有 HANDOFF / PLAN / `tested_sha` / Reviewer 落账，**也不得为此创建**。**判据一条不减**——等价形式是把同一套协议**在对话里逐步展示**：① 基线绿（命令 + 完整输出 + 退出码）→ ② 说明改了哪些文件的什么 → ③ 目标测试因预期断言而红（完整输出 + 退出码，**禁 grep 判红**）→ ④ 还原并确认与基线一致 → ⑤ 复跑变绿 → ⑥ 说明执行真实性。输入域与等价类由**人类当场确认**。**少任何一步 = 未证明**——此时必须当场把声称收窄到已覆盖范围、或撤回并报告风险。
* **四条失败判据**（任一不满足 → 不构成守护证据）：① 负向运行必须因**目标测试的预期断言**而红（编译/加载失败、环境失败、目标测试未执行、仅无关测试失败都不算）；② 红/绿以**真实退出码**为准，**禁止 grep 关键词判红**；③ 还原必须经内容哈希验证且复跑变绿；④ 产物含执行真实性证据。
* **无装置的项目**：不得把该能力写成已启用；装置落地前「回归用例有效」= **未证明**（Critical 列 VN 并记 `[DEBT]`；Routine 在对话里说明并按 No-Hidden-Debt 当场提出）。两模式都可以在当前任务顺带落地装置。

**负向对照的适用范围是"一切守护声称"**（构建/编译配置、lint 规则、类型检查、CI 门禁、扫描器……）：样本必须"**若移除 X 则会通过**"，且**覆盖声称主张的全部等价类**；等价类**枚举自一个人类批准并冻结的输入域**；**Reviewer 主张"还有一类没覆盖"必须给出该域内的具体反例**，给不出就只算 Suggestion、不阻止收敛。**用"本来就会失败"的样本验证守护 = 无效验证，等同空守护测试。**

## 4. 单轮任务 diff 预算（只计生产面）

**尽量不超过 4000 行**——`docs/ai/` **之外**的全部改动（生产源码、测试、迁移/schema、构建配置与依赖声明）增删合计。**`docs/ai/**` 一律不计**（交接文件、验收、`last_test_run.txt`、verdict、守护产物、截图）。

* 计法：**Critical** `git diff --shortstat <base>..<tip> -- . ':(exclude)docs/ai/**'`；**Routine** `git diff --shortstat HEAD -- . ':(exclude)docs/ai/**'`（`docs/ai/` 之外有新增未跟踪文件时加上其行数）。
* **规划时**按此切片；切不到 4000 行以内 → 写明理由请人类批准整体推进（不按行数机械拒绝）。
* **实现中发现将要超出 → 停下报告人类**，由人类决定拆分 / 缩范围 / 批准超限；**不得默默做完再交一个超大 diff**。
* **超限时**先去掉无关改动与顺手重构，再与人类商量缩范围或拆片；**不得为凑预算删减或弱化测试**。证据面不计预算，所以"砍证据凑预算"这个选项不存在。

## 5. 派发与工具面（Fan-out 上限；两模式恒适用）

三个委派面：`subagent`（fresh 上下文，可指定模型）/ `subagent_fork`（继承本会话，**不可当 Reviewer**）/ `workflow`（批量编排）。细节与参数见 `~/.dsh/workflow/fanout-toolchain.md`。

* **上限**：一次 fan-out **≤ 10 个 agent**、**并发 ≤ 6**、一轮 **≤ 3 个 `workflow`**。
* **不得一事一 agent**（一文件/一发现/一声称一个 agent）——把清单**按批分组，一组一个 agent**。
* **对抗性复核 = 每批一个复核者**，不是每条发现 N 个投票者；**不做 loop-until-dry**。
* 只有人类在本次请求里写了**显式预算**才可超过，并按 `budget.total` 缩放。
* **撞上用量上限而死的一轮：先缩小再恢复**（失败的 agent 不缓存）。
* **给子 agent 派活时把写权限与范围写死在 prompt 里**——它们都是完整 agent、都能写文件。

> 理由不是账单而是**可审性**：一次实测的 97 个 agent fan-out 烧光配额，而真正有用的只需 4–10 个。

## 6. `last_test_run.txt` 的写法

* 它是**产物**，不是叙述：命令 + 完整输出 + 退出码，逐轮**追加**（VN 代跑结果也追加，不覆盖）。
* 每轮测试以 `tested_sha` 绑定；新增测试导致 delta 时 `tested_sha` **回炉**到含该 delta 的 commit。
* 保持"简短、指向 git log 与产物"——不要把它写成第二份 HANDOFF。
* Reviewer 对它是**批判性阅读**：命令是否真实存在、输出是否完整、结论是否与输出一致；**不自己重跑**。
