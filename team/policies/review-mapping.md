# 独立审查映射

规则事实源：`claude/workflow/AGENTS.md` 的轻量协议、产品 blocking 分类、真实证据和停止规则；
DSH 的原生权限与 fresh 语义来自 `dsh/workflow/AGENTS.md`、`dsh/workflow/fanout-toolchain.md`。
Team 的结构化 Plan/Task/Result、Git SHA、验证产物取代该运行模式的散文交接输入；
不修改旧 Routine/Critical 流程，也不要求 Routine 临时制造旧 Critical 文档。

Routine/Critical 的 Worker 都先通过 Git 审计和外部验证，再执行独立 DSH Local Review。
它使用新原生进程、禁用全部工具，仅接收 Task、精确 diff、AGENTS 快照、外部验证证据、
已核验的 Result 子代理声明及协调器观测的原生身份/路由收据；
不接收作者会话或推理。原生身份收据、输入与 verdict 哈希绑定 plan hash 和提交，
Lead accept 强制核对该结论和补证处置。Local Review 不计入 Critical 的 9A/9B 修复轮数。

AGENTS 快照来自 run 基线提交，包含嵌套及 override 文件和 Team manifest/policies，
不是待审 tip 的规则；state 与每次审查都绑定 authority.json 哈希。提案中的治理改动仅作 diff 证据，
且触发 fresh 9A（Routine 分类不自动改变）。Local/9A 接收该任务 risks，9B 接收运行中各任务 risks，
明确标为作者待核实声明。验证 stdout 只传有界摘录及完整日志哈希，必要补证仍走 VN。
输入超限时拒绝启动审查、保留原始数据并交 Lead 拆分，不截断 diff 或把未读内容当已审。

原始 holding 持久保存到 `$CODEX_HOME/team-review-holding/`，未设置时为 `~/.codex/team-review-holding/`。
`reviews/archives/` 封存 prompt/verdict 并校验哈希，后续验收使用此副本；
原始 holding 丢失不使已封存审查失效，封存被改或缺失则返回 80。旧 run 缺少此证据链时
不补造过去的 authority/verdict，保留旧现场并另建明确计划的运行。

Critical：dispatch 前 9P、Worker 本地审查通过后 9A、集成完整回归后 fresh 9B。
每次都是新的 `codex exec --ephemeral -s read-only`，不用 resume/fork，verdict 位于仓外 holding。
显式 `--ignore-user-config --ignore-rules --disable memories`；9P 的 reasoning effort 为 medium，
9A/9B 为 high，沿用审查母本的隔离及推理档要求。目标 AGENTS 快照仍作为审查合同传入，
关闭额外 execpolicy 加载不表示可以忽略目标合同。
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

`resolve-review -Stage LOCAL|9P|9A|9B [-Task id] -Disposition <file>` 逐条处理 VN：
每项含 `index`、`action`（verify/decline）、`reason`；verify 还含与 Plan 相同格式的 command。
verify 由外部进程实跑并保存真实输出/退出码；decline 必须给技术理由。
处置绑定 verdict hash，不能替代产品 blocking 的修复或批准不同 SHA。
每次 verify 在独立 `reviews/evidence/` 子目录保存请求、输出及真实退出码；
再次补证不覆盖失败记录，成功 disposition 引用本次证据目录及哈希。
LOCAL 补证处置后须 resume，随后才可进入 Critical 9A 或 Routine Lead 验收。
