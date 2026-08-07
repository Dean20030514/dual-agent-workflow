# HANDOFF.md

> 当前无进行中任务。本文件是仓库现状的极简交接;历史任务全部在 `docs/ai/archive/<日期-任务>/`。

## 状态(2026-08-07 更新)
* **Commit B 落地(2026-08-07)**:Reviewer 调用形态收敛入 `claude/workflow/reviewer-prompt.md` 双审隔离协议 ③(唯一定义处)——显式 sandbox/model/效力档 + `--ephemeral --ignore-user-config --ignore-rules` + 机器键 `-c windows.sandbox="elevated"`(缺它则全命令被 policy 拒,冒烟实测)。**read-only 未晋升**:六轮行为冒烟证实明文 HTTP 出网在两种沙箱模式下均放行(实拉真页面 200/559B),「网络阻断」验收不成立——继续显式 workspace-write(fallback 形态已在一次性 fixture 仓行为验证);沙箱≠网络边界已记为已知风险,复测晋升需人类明确决定。
* **Commit A + mini A/B 结案(2026-08-06,Complete)**:Routine/Critical 模式路由已落地并部署(`3925b5c` 主体 + `83985f5` 措辞修正);Routine 减重与 Critical 完整性均有**行为级**证据;复发即重开裁决,不得静默。全档:`archive/2026-08-06-routine-critical-routing/HANDOFF.md`。
* **H5A validator:停牌封存**(`stopped, NOT converged — over-engineered`,人类裁决)。代码留在 `tools/validate/`(Common + PathReferences + 81 测试):非门禁、勿续建、勿修;`validate.ps1` 入口从未建成;真仓断言绑定修漂移前的仓库状态,套件对当前 main **预期失败**——这是封存标记,不是 bug。全部过程、裁决与账目①–㉒:`archive/2026-08-05-h5a-validator-foundation-stopped/HANDOFF.md`。
* **已知漂移已直接修复**:install.sh/skills 幽灵引用、push 指令冲突(b13859d);根 LICENSE(MIT)+ THIRD_PARTY_NOTICES 含 ECC 上游原文(a5802cf);ecc marketplace 残留与可执行恢复指令清除(78cb432)。
* **IMPROVEMENT_PLAN v1.1 = 参考材料(REFERENCE ONLY)**,不按其 phase 开工;重启任何一项需人类明确决定。
* **部署**:`install.ps1` 受迁移期 guard 锁定,勿直接运行;部署 = 从 main 精确同步受管文件 + 哈希比对(最近一次:2026-08-06 随 `83985f5` 同步 2 文件 2/2 MATCH;此前 2026-08-05 随 `3925b5c` 同步 15 文件 15/15 MATCH)。

## 工作方式(五规则三闸门,裁决㉒)
日常改动 = Claude 改 + 人类扫 diff + 人类 commit/merge。五条核心规则:快照仓 SSOT / 真改动人类批准 / Author 交真实测试产物 / Reviewer 零写入只读 diff 与证据 / 连续 blocking 硬停拆新任务。三个机械闸门:审查 SHA 绑定干净工作树、实际 diff 不超批准范围、测试真实执行退出码可信。9A/9B 双审等重流程仅用于人类明确要求的真项目;**任何新增流程/规则/登记表/检查项默认「不」**,除非一句话说清净收益。模式路由(Routine 默认/Critical 人类启用)唯一出处:全局 `CLAUDE.md` → Mode Routing。
