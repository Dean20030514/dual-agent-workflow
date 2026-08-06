# HANDOFF.md

> 当前进行中任务:Commit A(见下)。本文件是仓库现状的极简交接;历史任务全部在 `docs/ai/archive/<日期-任务>/`。

## 进行中任务(2026-08-05):Commit A — 统一 live 配置与「五规则三闸门」裁决

* **Human Approval Evidence(批准边界,人类原文)**:仅将 2026-08-05「五规则三闸门」裁决传导到实际每会话配置,使 Routine 成为默认、Critical 仅由人类明确启用;移除全局固定 80% 覆盖率、默认 TDD 仪式、全项目强制双 Agent,并为 `/implement` 提供不含 SHA 账本和强制 Reviewer 的真实轻路径。保留现有五规则三闸门及 Critical 严格机制,不修改 H5A 封存记录,不顺带实施 Commit B、C、D。完成后只做一次三任务 mini A/B 验收,不建立长期评测平台;验收结果单独报告,Commit A 不因 A/B 结果自动扩展范围;发现问题先停下由人类裁决,不以规则修补规则。
* **范围修订(2026-08-05 二次裁决)**:另批 6 个一行修正——5 个语言规则文件(java/rust/perl/csharp/dart 的 testing.md)的固定 80% 覆盖率行改为跟随项目自有门槛,`rules/README.md` 示例行同批清理;最终最多 15 文件,不触碰其他文件。
* **范围修订(2026-08-05 三次裁决)**:人类明确选择路径 B,批准在 mini A/B 前消除已机械确认的模式作用域冲突;新增 `claude/workflow/AGENTS.md`,最终最多 16 文件。本次只处理 Mode Scope、planning/reuse 落点、commit actor 与三闸门 N/A 语义;不加入一手来源规则,不修改 Parallel、全局最优或 Commit B 内容。
* **改动面**:按批准文件与锚点完成编辑;最终范围以 staged diff 为准。
* **状态**:已 commit(3925b5c) + 已部署同步(15 受管文件从 main 精确同步,SHA-256 双侧比对 15/15 MATCH,2026-08-05;含新增受管 `claude/workflow/AGENTS.md`);待新会话 mini A/B(单独报告)。

## 状态(2026-08-05)
* **H5A validator:停牌封存**(`stopped, NOT converged — over-engineered`,人类裁决)。代码留在 `tools/validate/`(Common + PathReferences + 81 测试):非门禁、勿续建、勿修;`validate.ps1` 入口从未建成;真仓断言绑定修漂移前的仓库状态,套件对当前 main **预期失败**——这是封存标记,不是 bug。全部过程、裁决与账目①–㉒:`archive/2026-08-05-h5a-validator-foundation-stopped/HANDOFF.md`。
* **已知漂移已直接修复**:install.sh/skills 幽灵引用、push 指令冲突(b13859d);根 LICENSE(MIT)+ THIRD_PARTY_NOTICES 含 ECC 上游原文(a5802cf);ecc marketplace 残留与可执行恢复指令清除(78cb432)。
* **IMPROVEMENT_PLAN v1.1 = 参考材料(REFERENCE ONLY)**,不按其 phase 开工;重启任何一项需人类明确决定。
* **部署**:`install.ps1` 受迁移期 guard 锁定,勿直接运行;部署 = 从 main 精确同步受管文件 + 哈希比对(2026-08-05 已同步五文件:claude/CLAUDE.md、settings.json、rules/README.md、rules/common/agents.md、rules/common/git-workflow.md)。

## 工作方式(五规则三闸门,裁决㉒)
日常改动 = Claude 改 + 人类扫 diff + 人类 commit/merge。五条核心规则:快照仓 SSOT / 真改动人类批准 / Author 交真实测试产物 / Reviewer 零写入只读 diff 与证据 / 连续 blocking 硬停拆新任务。三个机械闸门:审查 SHA 绑定干净工作树、实际 diff 不超批准范围、测试真实执行退出码可信。9A/9B 双审等重流程仅用于人类明确要求的真项目;**任何新增流程/规则/登记表/检查项默认「不」**,除非一句话说清净收益。
