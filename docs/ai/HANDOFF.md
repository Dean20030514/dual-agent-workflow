# HANDOFF.md

> 当前无进行中任务。本文件是仓库现状的极简交接;历史任务全部在 `docs/ai/archive/<日期-任务>/`。

## 状态(2026-08-15 更新)
* **流程修正(2026-08-15)**:四个真实项目的 Critical 任务**全部** `stopped, NOT converged`/硬停,诊断出三病——① 证据层自指螺旋(后段 blocking 几乎全 `[Verification]`,多轮双审零 `[Product]`,docs/ai 证据面占 diff 41–74%);② 声称被**无区分力样本**验过(某 AC 的七个探针中五个本该被拒的全部通过,此前"验证通过"样本在机制不存在时也会照样通过);③ **判定权不在命令而在人读**(退出码类 AC 四轮零缺陷,"Reviewer 逐条核散文清单"类 AC 逐轮产新 blocking)。已落库**六条**修正:**单轮 diff 预算 ~2000 行**(`9dd07e1`)+ **streak 只由 `[Product]` 递增 / 轮次上限 3 轮 / 证据层出口 / 负向对照扩到一切守护声称 / 验收必须可复现判定**(`018579b`)。经外部审查(不通过,7 条 blocking,全部核实成立)后**全部修补并收敛为单一事实源**:分类优先级(有产品/安全影响一律 Product,不得靠归类规避硬停)、证据层出口限定在 `review_sensitive_paths` 之外、负向对照按等价类覆盖而非"至少一个"、可机检改判据为"可复现+有区分力"(命令形态不等于合格;不可自动化的产品/安全性质仍可阻断合并)、硬停>轮次上限>合并门的优先级写明、"先砍仪式"限定为叙述性产物且明列不得削减项;`/debug` `/final-review` `templates/HANDOFF.md` 三处 streak 复述与 `/plan` `/implement` `/define` 的数值复述**全部收敛为纯指针**。完整诊断与实测数据:auto-memory `critical-mode-diagnosis-2026-08-15`。
* **四个停滞任务未合并**:各自 HANDOFF 均记录当前不可合并(「Author 不得标 Ready to Commit」/「双审通过后才 merge」而双审未过 / 任务进行中 / 6 条 blocking 未修复已移交),待人类逐个裁决「带如实登记的限制交付 vs 按新预算重拆」。

## 状态(2026-08-12 更新)
* **Commit B 落地(2026-08-07)**:Reviewer 调用形态收敛入 `claude/workflow/reviewer-prompt.md` 双审隔离协议 ③(唯一定义处)——显式 sandbox/model/效力档 + `--ephemeral --ignore-user-config --ignore-rules` + 机器键 `-c windows.sandbox="elevated"`(缺它则全命令被 policy 拒,冒烟实测)。**read-only 未晋升**:六轮行为冒烟证实明文 HTTP 出网在两种沙箱模式下均放行(实拉真页面 200/559B),「网络阻断」验收不成立——继续显式 workspace-write(fallback 形态已在一次性 fixture 仓行为验证);沙箱≠网络边界已记为已知风险,复测晋升需人类明确决定。
* **Commit A + mini A/B 结案(2026-08-06,Complete)**:Routine/Critical 模式路由已落地并部署(`3925b5c` 主体 + `83985f5` 措辞修正);Routine 减重与 Critical 完整性均有**行为级**证据;复发即重开裁决,不得静默。全档:`archive/2026-08-06-routine-critical-routing/HANDOFF.md`。
* **H5A validator:停牌封存**(`stopped, NOT converged — over-engineered`,人类裁决)。代码留在 `tools/validate/`(Common + PathReferences + 81 测试):非门禁、勿续建、勿修;`validate.ps1` 入口从未建成;真仓断言绑定修漂移前的仓库状态,套件对当前 main **预期失败**——这是封存标记,不是 bug。全部过程、裁决与账目①–㉒:`archive/2026-08-05-h5a-validator-foundation-stopped/HANDOFF.md`。
* **已知漂移已直接修复**:install.sh/skills 幽灵引用、push 指令冲突(b13859d);根 LICENSE(MIT)+ THIRD_PARTY_NOTICES 含 ECC 上游原文(a5802cf);ecc marketplace 残留与可执行恢复指令清除(78cb432)。
* **IMPROVEMENT_PLAN v1.1 = 参考材料(REFERENCE ONLY)**,不按其 phase 开工;重启任何一项需人类明确决定。
* **部署**:`install.ps1` 受迁移期 guard 锁定,勿直接运行;部署 = 从 main 精确同步受管文件 + 哈希比对。**受管持续镜像面(边界唯一定义处 = README 文首 + `AUTHORITY_CONTRACT.md`)** = `claude/{CLAUDE.md,settings.json,rules/,workflow/,commands/}`(98 文件)+ `codex/AGENTS.md`;`codex/config.example.toml` 为 seed-only(缺失时播种、创建后 machine-local),**不参与同步**。审计史:2026-08-07 的 blob 级审计**范围仅 `claude/**`**(检出 67 文件 EOL-only 分歧,已双侧规范化为 LF、内容级零变化;更早:2026-08-05 15/15、2026-08-06 2/2);**2026-08-12 首次把 `codex/AGENTS.md` 纳入审计**——检出本机多 8 行 H5A 时代过期条款(change budget / 快速版 code-review 暂停 fail-safe,正是 Codex 误判该类流程要求的根源),备份后 mirror-replace(101→93 行),**两面现均 blob 级零漂移**。教训:审计范围须覆盖两个 agent 的受管面。

## 工作方式(五规则三闸门,裁决㉒)
日常改动 = Claude 改 + 人类扫 diff + 人类 commit/merge。五条核心规则:快照仓 SSOT / 真改动人类批准 / Author 交真实测试产物 / Reviewer 零写入只读 diff 与证据 / 连续 blocking 硬停拆新任务。三个机械闸门:审查 SHA 绑定干净工作树、实际 diff 不超批准范围、测试真实执行退出码可信。9A/9B 双审等重流程仅用于人类明确要求的真项目;**任何新增流程/规则/登记表/检查项默认「不」**,除非一句话说清净收益。模式路由(Routine 默认/Critical 人类启用)唯一出处:全局 `CLAUDE.md` → Mode Routing。
