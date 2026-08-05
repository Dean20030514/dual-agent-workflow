# QUALITY_GATES.md — H5A per-task scaffold

> 从母本 `claude/workflow/QUALITY_GATES.md` scaffold 而来,供 Reviewer 独立读。门控依据 = `docs/ai/TASK_BRIEF.md` 的 0.1 扫描:仅 11.1、11.2 基础组适用;设计层闸门(5.1–5.4)、11.3、11.4、上线后(12.x)整组 N/A(原因见 0.1 表)。勾选规则、截图产物化要求等以母本为准。

## 11.1 测试 / QA(适用)
* [ ] 单元/集成覆盖关键路径:七项检查(原六项 + AC-11 JSON 良构性轻查)各有正反 fixture 用例(负向 fixture 按 TASK_BRIEF fixture-scope 契约隔离);validator 端到端真跑一条(真仓 + 退出码断言)。
* [ ] 边界与异常:缺依赖模块(exit 2)、缺前置产物(SKIP)、陈旧豁免(FAIL)、空 baseline(已知漂移必红)各有针对性用例。
* [ ] 覆盖率:无既有覆盖率工具;确保关键判定路径(抽取/匹配/聚合/退出码)全部有用例,不凑百分比、不编造数字。
* [ ] 回归锁定:P4「三处已知漂移无豁免必红」以 fixture 固化(本任务不声称守护有效性装置产物,不适用该契约)。
* [ ] 测试真实运行、产物化到 `docs/ai/last_test_run.txt`。
* [ ] **docs-GREEN(裁决⑰④,可执行措辞;例外条款系⑳偏差明示,供人类批准门单独否决)**:任何会改变生产扫描输入面 / 期望 finding 集 / baseline 或 claim 数据 / fixture 定义的 commit,均使之前的 GREEN 失效——最终 review tip 必须重新运行标准验证命令并产物化;文件扩展名或「docs-only」标签不构成豁免依据(判例:HANDOFF ⑬⑭转录 commit 未重跑,预存红灯至 round-4 RED 才曝光)。**唯一结构性例外(与母本 SHA 绑定语义对齐)**:审前冻结的最终交接 commit——diff 机器可验地仅限 `docs/ai/HANDOFF.md` 与 `docs/ai/last_test_run.txt`(两者均不在 review_sensitive_paths)——不使其所转录的 GREEN 失效,否则「跑测试→落产物→GREEN 失效→再跑」无穷回归;例外仅在 AC-2 排除契约生效(两文件非 path-references 扫描主体)时成立。**两文件的 SecretScan/Provenance 终态覆盖 = prospective-tree 闭环协议 A(㉑乙/丙;默认项,人类批准门可改选协议 B)**:先前 full-suite GREEN 仅可被不读取该两路径的检查继承,SecretScan 与 Provenance 不得继承;两文件最终内容精确暂存(暂存集恰两文件、工作树与 index 一致、零未跟踪)后记录 prospective_tree_oid = `git write-tree`,对该字节状态**实际运行** SecretScan 与 Provenance,结果写仓外不可变 evidence 文件并计 SHA-256(不回写仓库);提交后证明 `git rev-parse HEAD^{tree}` 与 prospective_tree_oid 相等;不得为回填结果再改两文件;evidence SHA-256 附入 9B/9A prompt 并由 Reviewer 在 verdict 回写(仓外证据双向绑定);任一条件不满足回退到完整 final-tip fresh GREEN。**协议 B(替代项,人类亲选方生效)**:明确两文件对最终 SecretScan/Provenance 的豁免边界、由 Reviewer 内容审读替代。diff 越出两文件即回到一般规则。
* [ ] **final-tip fresh GREEN**:正式审查绑定的 review_tip 上须有本 tip 新跑的标准验证产物(`docs/ai/last_test_run.txt` 含命令/完整输出/退出码/tested_sha),不得沿用旧 tip 的 GREEN。
* [ ] **排除范围 QA**:path-references 扫描主体排除面(运行期载体 `tools/validate/path-references-scope.psd1`,⑳丙 B1)与 TASK_BRIEF AC-2 批准枚举在 Phase 2 验收时逐字比对一致(无多排/无漏排/禁通配;此后 psd1 即唯一运行期权威,变更仅经人类批准 commit);`explicitly_included_durable_records` 两文件必须在生产扫描主体内(防回归用例锁定);被排除文件仍受 SecretScan/Provenance 覆盖有断言;排除边界用例(近名不排除/前缀带目录分隔符)见 PLAN Testing Plan。

## 11.2 安全(基础组,恒查)
* [ ] 无硬编码密钥/token/密码/连接串(fixture 中的「泄漏样例」须为显式假值并加注)。
* [ ] 系统边界输入校验:YAML(baseline/invariants/provenance)解析失败=显式报错非静默;git/gitleaks 子进程退出码逐一检查。
* [ ] 错误信息与日志不泄露敏感数据;validator 输出不含环境变量/凭据。
* [ ] 依赖:powershell-yaml/PSScriptAnalyzer/Pester/gitleaks 全部显式声明、CI pinned;无 lockfile 面(仓库无 package manifest,保持)。

**敏感面扩展**:N/A——无 auth/支付/用户数据/文件上传/对外网络服务(gitleaks 与模块安装仅 CI 侧,pinned)。

## 设计层闸门(5.1–5.4):N/A(无界面、无面向用户内容)
## 11.3 隐私/合规:N/A(不处理用户数据/PII;扫描对象为本仓库文本)
## 11.4 可访问性:N/A(CLI 工具,无鼠标/图形依赖)
## 12.x 上线后:N/A(非发布产品)

## 角色分配(轻量)
单人仓,无专家 sub-agent(ecc 已卸载):planner/tdd-guide/code-reviewer/security-review 职责全部由 Author 本人承担(`claude/rules/common/agents.md` Fallback rule);独立第二视角 = Codex 9A/9B 双审(`claude/workflow/reviewer-prompt.md`)。人类:批准计划、审 diff、最终 commit、CI 确认。
