# 独立审查映射

规则事实源：`claude/workflow/AGENTS.md` 的轻量协议、产品 blocking 分类、真实证据和停止规则；
DSH 的原生权限与 fresh 语义来自 `dsh/workflow/AGENTS.md`、`dsh/workflow/fanout-toolchain.md`。
Team 的结构化 Plan/Task/Result、Git SHA、验证产物取代该运行模式的散文交接输入；
不修改旧 Routine/Critical 流程，也不要求 Routine 临时制造旧 Critical 文档。

Critical：dispatch 前 9P、Worker 外部验证后 9A、集成完整回归后 fresh 9B。
每次都是新的 `codex exec --ephemeral -s read-only`，不用 resume/fork，verdict 位于仓外 holding。
白名单：Plan/Task、目标 diff、验证结果、必要源文件、相关决策。禁止聊天、内部推理、无关日志与全仓历史。
返回缺失/结构错误/非零 exit/写入/快照变化都不算通过。Verification Needed 要逐条处置，不能当产品缺陷。
Routine 的 Lead accept 是日常验收，不是假造独立审查。

Team 按 v5 的两阶段位置映射母本计数：同一 run 的一个计划 revision 中，已经返回的
9A（可有多个 Worker）与 9B 汇总为一个实现审查轮。只有实际返回实现 verdict 的 revision
才占轮数；9P、纯计划修订、同一 SHA/verdict 的重复读取不计新轮。此处没有把不同 Worker
提交声称为旧双审流程的同一 SHA；旧流程的同快照契约保持不变，目标项目额外要求仍须满足。

每条产品问题返回 `id / consequence / evidence / caused_by_last_fix`。同轮按 id 去重；
同一问题归因不一致按 dispute 处理。任何已确认 yes 使该轮 streak 计一次；没有 yes 且
无争议时归零，争议不自动计数或重置。Reviewer 的逐项归因原样保存，人工判断另存，
不能由 Lead 改写 verdict。下一轮只提供相关既有问题和前次 reviewed tip→本次 tip 的精确 diff，
不继承聊天或内部推理；每次 verdict 同时保存不可覆盖的 `reviews/verdict-*.json`。

连续两轮有修复引入缺陷 → exit 60 / hard_stop，优先于其他出口。三轮未收敛 → exit 70；
一轮的全部产品 blocking 都来自前轮修复时提前触发相同轮次出口。early-stop 在轮收口
（请求 replan/集成修复，或最终 9B 返回）时判断，不在只收到部分 9A 时提前推断。
两种轮次出口都记 `stopped, NOT converged`，不把未解决产品问题视为可合并。

`review_round_limit` 升级的 `resolve -Decision approve -Reason ...` 专指人类明确批准额外一轮，
决定绑定当前 revision；不会覆盖 hard_stop、Worker 重试预算或其他权限，也不使失败 verdict 通过。
`modify-plan` 不等于延长批准；可取消此 run，再按人类裁决回退/重拆。原始失败审查已绑定
plan hash 与 tip，同快照再调用复用失败结论，不重新花费一次模型审查来寻找通过答案。

`review_causality` 的 approve 还必须提供 `-Disposition <file>`，文件为数组，例如：

```json
[{"id":"ABS-001","value":"no","reason":"人类核对旧版本，确认问题早于本次修复"}]
```

每个争议 id 必须恰好一次，value 只能 yes/no；裁决只影响归因，不解除产品缺陷。
该入口用于执行已有的人类决定，不授权 Lead 代替人类裁决。
升级前旧版本的 `review_loops` 不能静默转换为零轮；活动旧 run 返回 80，须保留证据后明确协调。
历史已完成 run 的状态与通过记录仍可读取，不需要重跑模型。

`resolve-review -Stage 9P|9A|9B [-Task id] -Disposition <file>` 逐条处理 VN：
每项含 `index`、`action`（verify/decline）、`reason`；verify 还含与 Plan 相同格式的 command。
verify 由外部进程实跑并保存真实输出/退出码；decline 必须给技术理由。
处置绑定 verdict hash，不能替代产品 blocking 的修复或批准不同 SHA。
