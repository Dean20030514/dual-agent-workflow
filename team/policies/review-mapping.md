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

`resolve-review -Stage 9P|9A|9B [-Task id] -Disposition <file>` 逐条处理 VN：
每项含 `index`、`action`（verify/decline）、`reason`；verify 还含与 Plan 相同格式的 command。
verify 由外部进程实跑并保存真实输出/退出码；decline 必须给技术理由。
处置绑定 verdict hash，不能替代产品 blocking 的修复或批准不同 SHA。
