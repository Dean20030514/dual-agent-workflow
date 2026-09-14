---
name: dual-agent-workflow
description: Use when running the full Critical-mode dual-agent workflow in DSH — entering a phase (/define, /explore, /plan, /implement, /debug, /final-review), deciding Routine vs Critical, deciding which handoff artifact to write, or scaffolding a new project's docs/ai. Routes to the phase procedures, handoff templates, and the always-on red lines; it does not restate the playbook.
whenToUse: Load when a task is or may become Critical (human asked for the heavy process, or the task touches auth/money/migrations/deploy/public API/many layers), when a handoff file is needed, or when starting a phase and you need its procedure.
---

# Dual-agent workflow（Author × Reviewer，DSH 执行面）

> **母本 / 判据唯一定义处**：`~/.dsh/workflow/AGENTS.md`（部署前 = 本仓 `dsh/workflow/AGENTS.md`）。**规则判据不复制到本技能**——本技能只负责"现在该读哪个文件、按什么顺序动手"。
> **命令 = phase 正文**：DSH 没有 Claude Code 那种 markdown slash command 面（`/command` 必须由插件注册），所以本项目把 7 个 phase 写成可读正文。用户说「跑 /plan」，意思就是**读 `references/phases/plan.md` 并照它做**，不是凭记忆复述。

## 0. 先定模式（每次任务开始都判一次）

* **Routine（默认）**：Author（当前会话主 agent）改 → 人类扫 diff → 人类 commit。**不建** TASK_BRIEF / PLAN / HANDOFF / SHA 账本，**默认不派 Reviewer**。循环 = 先读相关代码与规则 → 一句话方向 → 最小充分且任务内的改动 → 跑直接证明这次改动的测试 → 给 diff + 真实输出（命令 / 完整输出 / 退出码）+ 残余风险。
* **Critical（仅人类明确启用）**：走下面的 phase 全流程 + 交接文件 + 双审。**任务级祈使句（"做吧" / "直接做"）不构成模式确认。**
* **建议而不自我升级**：触及 auth/permissions/secrets、资金/计费、DB 迁移或不可逆数据操作、部署/回滚/CI 核心、公共 API 或兼容契约、或跨多层架构 → **停下、建议 Critical、等人类确认**再动文件或装依赖。
* **「Routine + 临时 Reviewer」是合法状态**：人类可以只要求跑一次独立审查而不启用 Critical。此时继承零写入 + 轻量协议**第一层**，证据载体取 **Routine 那一句**；**不继承 Critical 账本**（不产生 HANDOFF / `last_test_run.txt` / SHA 绑定，**也不得为审查临时创建**）。
* **两模式恒适用**：Safety Rules、真实执行证据、单轮 diff 预算、No-Hidden-Debt / Payback-on-Touch、证据 vs 假设、停止事件优先级、Fan-out 上限。三闸门按模式取：**SHA 绑定干净工作树**仅 Critical；**diff 不超批准范围**与**退出码可信**两模式恒适用。

## 1. 阶段顺序（Critical）与最小产物

```
/define → /explore → /plan → 9P 计划审 → 人类批准门(commit) → /implement → 9B+9A 双审 → /final-review → 人类 commit/merge
                 ↑                                                    ↑
           /design-check（有界面/设计层时）                    /debug（修复循环，横切）
```

| 阶段 | 正文 | 最小产物（`docs/ai/`） |
|---|---|---|
| 产品定义 + 18 维适用性扫描 | `references/phases/define.md` | `PRODUCT_BRIEF.md`（有产品面时）、`TASK_BRIEF.md` |
| 只读探索 | `references/phases/explore.md` | 探索输出 → 计划起草（Reuse Findings 进计划） |
| 正式规划 + 9P + 批准门 | `references/phases/plan.md` | `IMPLEMENTATION_PLAN.md`（含 Human Approval Status）、`docs/ai/review_9P.md` |
| 设计层闸门 | `references/phases/design-check.md` | HANDOFF 的 Quality Gates 节 |
| 实现 + 测试产物 + 闸门 | `references/phases/implement.md` | 代码 + `last_test_run.txt` + `HANDOFF.md` |
| 调试（横切） | `references/phases/debug.md` | 修复 + 回归用例 + 证据 |
| 最终审查（含代跑 VN） | `references/phases/final-review.md` | Final Verdict + PR Description |
| 独立审查 9P/9A/9B | `independent-review` 技能 | verdict 落 `docs/ai/review_9*.md`（窗口结束后） |

**小任务快速版**（Critical 内）：见 `references/phases/implement.md` 末尾「快速版」——但**至少要留 `docs/ai/HANDOFF.md`**（含 0.1 适用性扫描与批准证据）。

**骨架一律用模板**：`~/.dsh/workflow/templates/{TASK_BRIEF,IMPLEMENTATION_PLAN,HANDOFF,PRODUCT_BRIEF}.md`。**对齐项目既有约定永远压过套用通用模板**——拿不准就先读该项目最近一份 `docs/ai/archive/**/` 实例（archive 只供内容/约定参考，**绝不作结构模板**）。

## 2. 交接与证据（六条不可谈判原则的可执行形态）

1. **交接走文件，不靠口头**；两个 agent 不共享记忆。
2. **验证产物化**：测试输出落文件（`docs/ai/last_test_run.txt`），下一个 agent 读文件而不是读自述。
3. **git 作门**：每个阶段 commit，回滚靠 revert。任务分支 `task/<简短任务名>`；阶段 commit 前缀见母本 Git Discipline。
4. **`IMPLEMENTATION_PLAN.md` 的 Human Approval Status 只能人类编辑**——Author 碰这个字段即为违规。
5. 每个改动**可解释 / 可验证 / 可回滚**。
6. **Reviewer 零写入 + 轻量**：不重建副本 / 不重装依赖 / 不重跑全量测试；需实跑的列进 Verification Needed 交 Author 代跑。

**证据载体整句按模式取**（唯一定义处 = `~/.dsh/workflow/AGENTS.md` → Reviewer-Lightweight Protocol 第二层）：**直接复制那三句里对应的那一句**，不要自己拼——它内嵌在 prompt 句中，机械检查"整句是否原样出现"没意义，但复制是必须的。

## 3. 风险点（本项目实测过的坑，按发生时点排）

* **把 Routine 当 Critical 跑**（或反之）：前者白烧配额与仪式，后者把真改动漏过人类门。**模式不明确时先问一句**，别猜。
* **命令漂移**：凭记忆复述 phase 内容而不是读文件——历史上 27 个会话里 20 个没加载过 phase 命令，写出来的交接文件全部偏离模板。**读文件，别复述。**
* **tip 里装的是过期 HANDOFF**：`HANDOFF.md` / `last_test_run.txt` 不在 `review_sensitive_paths` 内、提交在 `review_tip_sha` 之后。任何 Reviewer 都必须**从工作树读**这两个文件，禁止 `git show <tip>:docs/ai/HANDOFF.md`（实测 Reviewer 真会这么干）。
* **审前快照自检被跳过**：HEAD ≠ `handoff_snapshot_sha` 或工作树不净 → Reviewer 必须拒审。Author 发审前先自己核一遍（清单见 `independent-review` 技能）。
* **Author 自证**：自编 mutation harness / "删码后测试变红"不能单独证明实现正确——须由 Author 之外的一方复核「变异内容 + 目标测试确实执行 + 具体失败原因」三项（Critical 由 Reviewer；Routine 在对话里展示由人类确认）。
* **evidence 面膨胀**：面数多不等于证据强，`docs/ai/**` 不计入 diff 预算但受"简短、指向 git log 与产物"约束。
* **派发失控**：一次 fan-out ≤ 10 agent / 并发 ≤ 6 / 一轮 ≤ 3 workflow，**不得一事一 agent**（定义见 `verification-evidence` 技能 → 派发与工具面，或 `~/.dsh/workflow/fanout-toolchain.md`）。

## 4. 生成项目脚手架（新项目接入本工作流）

1. 仓库根 `AGENTS.md`：从 `~/.dsh/workflow/AGENTS.md` 复制**规则节**，填 Project Overview / Build / Test / Lint / Code Style（**只写真实存在的命令，不存在的不要编**）。
2. 若项目用 DSH：仓库根可再放一个薄 `AGENTS.md` 指针或直接依赖全局 `~/.dsh/AGENTS.md`（DSH 会加载 project → cwd 的整条链，更具体的胜出）。
3. 建 `docs/ai/`（放模板四件套与 `last_test_run.txt` 的落点）。
4. 需要 DSH 侧 reviewer 时，确认 `~/.dsh/workflow/reviewer-prompt.md` 与 `~/.dsh/skills/independent-review/` 在位（即本仓部署已完成），并按该技能派发。
5. **不要**在项目里复制 phase 正文或母本全文——引用路径即可，避免出现"两个事实源"。
