# IMPLEMENTATION_PLAN.md — H5A · Validator Foundation

> per-task 文件,Author 的正式实现计划。需求冻结源:`docs/ai/TASK_BRIEF.md`(上游:`IMPROVEMENT_PLAN.md` §H5A,tag `plan-v1.1`)。

## Goal
交付七项检查(原六项 + AC-11 JSON 良构性轻查)的治理 validator(pwsh 7)+ 登记式基线豁免机制 + offline-ci 种子 workflow,在**不修复任何漂移内容**的前提下让当前 HEAD 转绿(已知漂移全部显形为带 payoff 的豁免条目),为 H1–H4「落在绿色 H5A 之上」提供地基。

## Summary
单入口 `tools/validate/validate.ps1` 编排七个独立检查模块(六项 v1.1 §H5A 检查 + 评审补充的 JSON 良构性轻查),共享一个结果模型(check 级 PASS/BASELINE/SKIP/FAIL/ENVIRONMENT_ERROR;run 级 PASS/PASS_WITH_BASELINE/FAIL/ENVIRONMENT_ERROR)与一个机器可审计的豁免登记文件 `tools/validate/VALIDATION_BASELINE.yml`;缺前置产物(PROVENANCE.yml、plugins.resolved.json)时显式 SKIP(唯一合法理由 prerequisite_not_landed,落仓即自动转强制),命中已知漂移时只能经登记豁免转 BASELINE;陈旧豁免 = STALE_BASELINE → FAIL(棘轮只紧不松)。CI 为 windows-latest 单 job,零 credential。
候选比较:①手写六段脚本无框架(会在 H5B/PR1 扩展时重写,漏「陈旧豁免检测」这类横切件——偷懒方案,弃);②引入 Node/Python 校验栈(引入 package manifest,推翻 v1.1「Explicitly excluded: Dependency Review (no package manifests)」的前提——弃);③ **PowerShell 7 模块化 + Pester(选)**:与仓库唯一既有可执行面同栈、PSScriptAnalyzer 原生、Windows 主环境零额外运行时,检查模块横向可扩展(H5B 直接加一个 check)。

## Architectural Layers & Split Assessment
2 层(工具脚本 / CI 配置),<3 层 → 拆分评估 N/A。

## Frozen Acceptance(改实现前冻结;禁从当前实现反推)
来源:TASK_BRIEF Acceptance Criteria(AC-1..AC-11)+ v1.1 §H5A。要成立的性质:
* **P1 确定性**:同一 worktree 状态重复运行,逐检查状态与退出码逐次一致;无网络/时间依赖(本地)。
* **P2 完备性与 SKIP 冻结语义**:七项检查全部实现,可 `-Check <name>` 单独调用;SKIP 的唯一合法理由 = prerequisite_not_landed(`PROVENANCE.yml`→H1、`plugins.resolved.json`→H4),且文件首次入仓即自动转强制校验(无人工开关);文件存在但不可解析/schema 错 = FAIL;工具或模块缺失、CI 下载/校验失败、validator 自身异常 = ENVIRONMENT_ERROR——永不静默跳过、永不误报。
* **P3 基线闭环**:FAIL→BASELINE 的唯一通道是 `VALIDATION_BASELINE.yml` 登记条目(字段见 TASK_BRIEF AC-9);仅精确匹配,禁 glob/整类豁免;未登记违规 = FAIL;陈旧豁免 = STALE_BASELINE → FAIL;豁免变更只能经人类批准的 commit 入仓;BASELINE 不得伪装成 PASS(run 级显示 PASS_WITH_BASELINE)。
* **P4 漂移显形**:三处已知漂移(`./install.sh` 幽灵引用、`skills/` 幽灵引用、git-workflow.md push 指令)在无豁免条件下必被检出——Pester fixture 级证明。
* **P5 退出码契约**:0 = PASS 或 PASS_WITH_BASELINE(摘要区分并逐条列 baseline);1 = FAIL;2 = ENVIRONMENT_ERROR(附安装/修复指引)。
* **P6 可复现依赖**:powershell-yaml/PSScriptAnalyzer/Pester 精确版本冻结于 `tools/validate/requirements.psd1`(本地与 CI 同源);gitleaks 固定 release + 制品 SHA-256 checksum,记录于 workflow。
* **适用范围**:检查对象 = git 跟踪文件;活动策略/引用/唯一性类检查排除 `docs/ai/archive/**`(历史证据非现行规则)与 `tools/validate/tests/fixtures/**`(负向 fixture 经显式 fixture-root 调用测试,不入生产扫描);secret 扫描两者皆含(fixture 假值走精确 allowlist),provenance 全覆盖,字节精确证据不被改写(evidence-scope 与 fixture-scope 契约全文见 TASK_BRIEF Constraints);例外:CI 真实运行结果属人类 push 后确认项(Author 无远程权限)。
* **反例(不得成立)**:当前 HEAD 报 0 FAIL 且 baseline 为空。

## Current Architecture Understanding
* 仓库 = 母本发布快照:106 个跟踪文件,可执行面仅 `install.ps1`(PS 5.1 兼容,勿动);其余为 Markdown + `claude/settings.json` + `codex/config.example.toml` + portable 文本。无 package manifest(v1.1 刻意保持)。
* 插件清单三处现状一致(install.ps1:53 五插件 = README 部署节 = settings.json enabledPlugins 五键),`plugins.resolved.json` 尚不存在(H4)。
* 已知漂移(H2 修理对象,本任务只检出+登记):`claude/rules/README.md` 引用不存在的 `./install.sh` 与 `skills/`;`claude/rules/common/git-workflow.md` 含 "Push with `-u` flag" 类指令,与全局 NEVER-push 红线共载;`claude/settings.json` 的 `extraKnownMarketplaces.ecc` 残留(H2 决策项,invariant 不覆盖,不登记豁免)。
* `.gitattributes` = `* text=auto eol=lf`,行尾无歧义;`~/.claude/**` 形式的家目录引用与仓内 `claude/**` 存在 install.ps1 定义的确定映射。

## PathReferences v1 契约(裁决⑰ 2026-08-04;Phase 1 范围修订,待人类补充批准 commit 生效,凭证 SHA 由 Author 批准后补录于 HANDOFF)

### 扫描主体排除面
批准语义冻结源 = TASK_BRIEF AC-2 的 `path_references_v1_scan_scope` 枚举(本文件不复述清单,防「同一事实多份权威副本」);**运行期 SSOT = `tools/validate/path-references-scope.psd1`**(⑳丙 B1:TASK_BRIEF 为 per-task 文件、任务末归档,不能作长期运行载体——psd1 与 requirements.psd1 / gitleaks.toml / VALIDATION_BASELINE.yml 同族,`Import-PowerShellDataFile` 原生解析零新依赖;Phase 2 落地时初始内容与 AC-2 枚举**规范化语义等价**[验收时点比对,见下],此后变更仅经人类批准 commit、纪律与 baseline registry 同级;review_sensitive_paths 首项 `tools` 前缀已覆盖该文件,核实于 HANDOFF Review & Test Binding)。
**psd1 schema(㉑丙冻结,fail-closed)**:`SchemaVersion`(整数,初始 = 1)+ 四列表键必需且与 AC-2 四组一一对应(`ExcludedExactPaths` / `ExcludedReviewArtifacts` / `ExcludedPrefixes` / `DurableInclusionAssertions`;采四键形而非合并形,保持与批准源分组 1:1);元素一律非空字符串、`/` 分隔、ordinal 比较;键内与三排除键跨键均禁重复;prefix 条目必须以 `/` 结尾(目录分隔符界定匹配);`DurableInclusionAssertions` 与任何排除键相交 = schema 失败;未知键 = schema 失败;文件缺失 / 不可解析 / schema 失败 = ENVIRONMENT_ERROR(exit 2,禁静默回退硬编码默认)。**验收比对定性**:psd1 四组与 AC-2 枚举规范化后逐组相等系 Phase 2 验收**时点断言**(随 per-task 文档归档出集);永久 standing 测试只断言 psd1 自身 schema 合法性(不依赖短命任务文件)。实现落点约束:AC-2 排除为 path-references **专属**主体过滤,PathReferences 运行时只读该 psd1,禁止实现在共享 `Select-ActiveScanFile` 上——共享层继续只承载 fixture-scope / evidence-scope 两契约,保证 AC-4/AC-5/AC-11 范围不随本条缩面;排除只过滤扫描主体,存在性目标宇宙保持全部跟踪文件。

### 四层排除体系判定表(⑱甲预检注记)
| 层 | 层名 | 依据文件(单一事实源) | 判定时机 | 冲突时谁赢 |
|---|---|---|---|---|
| 1 | fixture-scope | TASK_BRIEF Constraints「fixture 范围契约」;实现:Common.ps1 `Select-ActiveScanFile` | 主体选择期(token 抽取之前) | 层 1–3 为主体排除**并集**,先后无别;命中任一 = 该文件零 token 进入 path-references;SecretScan/Provenance 不用此过滤,各按自身契约覆盖 |
| 2 | evidence-scope | TASK_BRIEF Constraints「扫描范围契约」;实现:同层 1 | 同层 1 | 同上;归档文件仍是合法链接目标 |
| 3 | AC-2 过程产物排除(本次新增) | TASK_BRIEF AC-2 机器可执行枚举 | 主体选择期;实现于 path-references 专属过滤 | 同上;`explicitly_included_durable_records` 与任何排除集相交 = 契约违规,由防回归用例直接判红(不存在运行时仲裁) |
| 4 | machine-local·managed registry | PathReferences.ps1 内五张 registry 表(TildeFileMap / TildeDirMap / MachineLocalFiles+Prefixes / ManagedPatternMap / MachineLocalPatterns) | token 级,主体过滤之后、逐 token 分类时 | 仅对已入主体的文件生效——主体排除(层 1–3)先于并高于 token 分类;registry 各表键互斥为构造契约,重键 = registry 错误 fail-fast,不做优先级仲裁 |

互斥关系:层 1–3 决定「谁被扫」(文件级),层 4 决定「已捕获 token 如何分类」(token 级),两级正交、无交叉仲裁;四层均不影响存在性目标集。

### V1 tilde-token 六步执行规则(顺序即优先级,全程禁截断重分类)
1. **完整捕获**:token charset 至少含字母数字、`. _ - /` 与 pattern 元字符 `{ } * ? [ ] ,`,捕获至真终止符(空白/反引号/括号闭合);句尾 `.`/`,` 按标点修剪,pattern 元字符零修剪。
2. **精确 registry 整串匹配优先**:已登记 pattern 按 ordinal 全串匹配,先于一切前缀/映射判定。
3. registered **managed** pattern → 展开为显式仓内目标清单,逐目标存在性验证,任一缺失 = finding(保留完整 original_token)。
4. registered **machine-local** pattern → 按登记理由通过,永不做存在性检查。
5. **未登记且含 pattern 元字符**(`{ } * ? [ ]` 任一)→ `unsupported_pattern_syntax` finding(fail-closed 独立 finding 类;保留完整 original_token)。
6. 无 pattern 元字符的未映射 tilde → unrecognized-tilde finding。

冻结条款:`?` 与 `[ ]` 在 v1 **永不可登记**(registry 加载时校验,出现即 registry 错误);未登记的 `**` 组合(含拼写变体)一律走第 5 步 fail-closed;任何 token 不得截断为合法父路径后重新分类——第 2–6 步的输入永远是第 1 步的完整 token。类名约定:新 finding 类按裁决逐字为 `unsupported_pattern_syntax`;既有类沿用现码 `unrecognized-tilde`(裁决文中下划线书写为同一类的变体记法,不构成更名要求)。

### 机械反例全表(乙全表 + ⑰三新形;`HOME/` 代写家目录 tilde 前缀以守账目去毒化纪律,完整字面串只落 fixture 文件)
| # | 反例形 | 现行为 | V1 必需行为 |
|---|---|---|---|
| N1 | `HOME/.claude/{rulez,workflow,commands}`(brace 拼写错,round-3 反例) | unrecognized-tilde FAIL | `unsupported_pattern_syntax`,整 token 保留 |
| N2 | `HOME/.claude/{rules,workflow}`(未登记 brace 子集,目标全存在) | unrecognized-tilde FAIL | `unsupported_pattern_syntax`(登记与否只看 registry,不看目标存在性) |
| N3 | `HOME/.claude/projects/*/memroy`(`*` 拼写变体,round-3 反例) | unrecognized-tilde FAIL | `unsupported_pattern_syntax` |
| N4 | `HOME/.claude/projects/?/memory`(`?` 形,round-4 探针) | **截断为合法前缀 → machine-local 放行(缺陷)** | `unsupported_pattern_syntax`;`?` 永不可登记 |
| N5 | `HOME/.claude/projects/[abc]/memory`(字符类形,round-4 探针) | **同 N4 截断放行(缺陷)** | `unsupported_pattern_syntax`;`[ ]` 永不可登记 |
| N6 | `HOME/.claude/projects/**/memroy`(`**` + 拼写变体) | unrecognized-tilde FAIL | `unsupported_pattern_syntax`(未登记 `**` 组合 fail-closed) |
| N7 | 已登记 machine-local glob 加尾斜杠 / 大小写变体 | 整串不匹配 → unrecognized-tilde | `unsupported_pattern_syntax`(近似串不继承登记身份) |
| P1 | ManagedPatternMap 4 条字面串(PathReferences.ps1:81–93) | resolved-pattern,逐目标验证 | 不变 |
| P2 | MachineLocalPatterns 3 条字面串(PathReferences.ps1:94–103) | machine-local,永不检查 | 不变 |
| P3 | 无元字符已映射文件/目录与两条裸根 | resolved / machine-local | 不变 |
| P4 | 无元字符未映射家目录文件(fixture 例) | unrecognized-tilde | 不变 |

每反例断言三件:finding 类别精确匹配 + `original_token` 完整保留 + 不得出现父前缀形态的 finding 或放行。
**Phase 2 转写纪律(⑳甲)**:fixture 落字面串时必须把 `HOME/` 代写**按语义还原**为真实家目录 tilde 前缀形态——否则测的是 HOME/ 字面串而非 tilde 通路,反例全表集体空转;还原正确性的证明 = RED 阶段 N1–N7 七例以真实 tilde 通路失败。

### 真仓 exact-set:临时迁移断言标注
Phase 2 排除契约落地后,真仓期望集回稳为 **3 身份 10 处**(README 幽灵 installer 引用 ×7、幽灵目录引用 ×2、引用语境示例链接 ×1;身份字面串见 PathReferences.Tests.ps1 生产段)。该 10 处断言标注为 **Step 2→Step 6 临时迁移断言**:证明「当前债务状态」,永不解读为「缺陷字符串必须永远存在」;Step 6 升级为 baseline-aware(期望集派生自 `VALIDATION_BASELINE.yml`,而非硬编码),该替换为 H5A 最终 merge gate;**替换完成时临时 10 处断言必须同步删除——两套断言不得并存(⑳乙)**。

## Proposed Changes

| 文件 | 类型 | 内容 | 原因/风险 |
|---|---|---|---|
| `tools/validate/validate.ps1` | 新增 | 入口:参数 `-Check <name>`(可选),加载 lib+七检查,聚合摘要,按 P5 退出 | 单 Runner 入口先例(呼应 PR2 思路);风险:无 |
| `tools/validate/lib/Common.ps1` | 新增 | 结果对象、baseline 加载/匹配/陈旧检测、YAML 读取(powershell-yaml 缺失→exit 2+指引)、跟踪文件枚举(`git ls-files`) | 横切唯一实现处;风险:YAML 模块外部依赖(显式声明,不自动装) |
| `tools/validate/checks/PathReferences.ps1` | 新增 | 抽取跟踪 .md 的相对 markdown 链接 + `~/` 映射解析,存在性校验;URL/锚点排除;误报走 baseline;扫描主体按 AC-2 排除契约过滤(专属层,不动共享 `Select-ActiveScanFile`);pattern token 走 v1 六步规则(本文件契约节) | 抽取规则刻意收窄到链接语法保证确定性;风险:示例路径误报→baseline 带 reason |
| `tools/validate/checks/PluginConsistency.ps1` | 新增 | 解析 install.ps1 `$plugins`、README 部署节、settings.json enabledPlugins 三方比对;`plugins.resolved.json` 缺失→SKIP(pending H4) | AC-3;风险:README 解析靠标记行,fixture 锁定 |
| `tools/validate/checks/PolicyInvariants.ps1` | 新增 | 按 `POLICY_INVARIANTS.yml` 的 {scan_paths, forbidden_regex, allow_regex} 逐条扫描 | AC-4;确定性=只跑注册规则,语义冲突仍归人审(v1.1 原文) |
| `tools/validate/checks/ScriptAnalysis.ps1` | 新增 | PSScriptAnalyzer 包装(Error 阈值硬红,Warning 可豁免) | AC-5;风险:PSSA 版本差异→CI pinned |
| `tools/validate/checks/Provenance.ps1` | 新增 | `PROVENANCE.yml` 缺失→SKIP(pending H1);存在→exactly-one 覆盖判定 | AC-6;H1 前靠 fixture 证明逻辑 |
| `tools/validate/checks/SecretScan.ps1` | 新增 | gitleaks 包装(pinned;范围=跟踪文件;allowlist=`tools/validate/gitleaks.toml` 精确条目);未安装/下载校验失败→ENVIRONMENT_ERROR | AC-7;本地前置=一次性安装 gitleaks |
| `tools/validate/checks/ConfigWellFormedness.ps1` | 新增 | 跟踪 `*.json` 良构性(现即 settings.json);TOML 显式推迟给 PR2 | AC-11(评审补充项) |
| `tools/validate/path-references-scope.psd1` | 新增(Phase 2) | AC-2 扫描主体排除契约的运行期 SSOT(excluded_exact_paths / excluded_review_artifacts / excluded_prefixes / explicitly_included_durable_records;初始内容 = TASK_BRIEF AC-2 枚举) | ⑳丙 B1:per-task 文件不能作长期运行载体;变更仅经人类批准 commit,纪律与 baseline registry 同级 |
| `tools/validate/requirements.psd1` | 新增 | 三模块精确版本冻结(实现第 0 步定值);本地指引与 CI 安装同源 | P6;「无 manifest ≠ 无依赖管理」 |
| `tools/validate/gitleaks.toml` | 新增 | secret 扫描配置与 allowlist(初始为空或仅 fixture 假值条目,逐条 reason) | AC-7;禁目录级忽略 |
| `POLICY_INVARIANTS.yml` | 新增(仓库根) | v1.1 §H5A 两条 invariant 落成可执行注册项(id/scan_paths/forbidden_regex/allow_regex) | 文件名与两条内容由 v1.1 冻结 |
| `tools/validate/VALIDATION_BASELINE.yml` | 新增 | 豁免登记 registry:初始条目 = install.sh 引用(payoff H2)、skills/ 引用(payoff H2)、push 指令(payoff H2)、install.ps1 PSSA Warning 如有(payoff H3)+ 实跑后逐条补记 | AC-9;字段 id/check_id/exact_target/exact_observation/reason/payoff{work_item,condition}/introduced_by_plan/owner/status;仅精确匹配 |
| `tools/validate/tests/*.Tests.ps1` + `tools/validate/tests/fixtures/**` | 新增 | Pester ≥5:每检查正反用例(经显式 fixture-root 调用,活动扫描排除 fixtures——fixture-scope 契约见 TASK_BRIEF);P4 三处漂移无豁免必红;baseline 闭环/陈旧豁免/退出码用例 | AC-8;TDD 红→绿 |
| `.github/workflows/offline-ci.yml` | 新增 | windows-latest:checkout→按 `requirements.psd1` 安装模块→validator→Pester→pinned gitleaks(下载 release 后 SHA-256 校验再执行;失败=ENVIRONMENT_ERROR) | AC-10;零 credential;PR0A 在同一 lane 上扩展 |
| `README.md` | 修改 | 增「校验与 CI」小节(命令、退出码、baseline 语义、依赖模块) | sync-on-code-change;不动其余叙述 |
| `AGENTS.md`、`CLAUDE.md`(仓库根) | 新增(本次规划已落盘) | 项目工作契约(薄指针→`claude/workflow/AGENTS.md`)+ `@AGENTS.md` | /plan 脚手架步骤;规划文件,随本计划一并由人类审 |
| `docs/ai/{TASK_BRIEF,IMPLEMENTATION_PLAN,HANDOFF,QUALITY_GATES}.md` | 新增(本次规划已落盘) | per-task 交接四件套 | /plan 产物 |

不触碰:`claude/**`(settings.json 在内)、`codex/**`、`portable/**`、`install.ps1`、`IMPROVEMENT_PLAN.md`。

## Risks & Edge Cases
* **误报管理**:文档里的示例/约定路径(如规则文说「勿引用 `~/.claude/agents/`」)会被抽取——处理=baseline 豁免带 reason,或该行匹配 allow_regex;绝不因误报放宽抽取规则本身(会漏真漂移)。
* **外部依赖缺失**:powershell-yaml/PSSA/Pester/gitleaks 缺失一律 = ENVIRONMENT_ERROR(exit 2 + 指引,不自动装,不降格为 SKIP);本地前置 = 一次性安装 gitleaks(实现期在 README 校验节写明来源与 pinned 版本)。
* **TOML 良构性显式推迟**:`codex/config.example.toml` 校验需 TOML 解析依赖,登记给 PR2(profile TOML 工具链到位时)——显式登记的偏差,非静默缩水。
* **install.ps1 解析**:`$plugins` 用正则锚定该赋值行,install.ps1 被 H3 改造后若解析失败=FAIL(倒逼同步),fixture 锁定两种形态。
* **README 部署节解析**:锚定「插件」列举行;H3 改 README 时同上。
* **CI 不可本地证真**:workflow 文件本地只能静态校验;真实绿灯=人类 push 后确认,已写入 Frozen Acceptance 例外。
* **性能**:106 文件全量扫描,秒级,无需优化。
* 回归面:仓库现有内容零改动(README 除外),回滚 = revert 单 commit。

## Execution Steps
0. 冻结依赖:查定三模块当前稳定版写入 `tools/validate/requirements.psd1`;查定 gitleaks release 版本 + 制品 SHA-256(网络查询,先告知)——全部入 diff 供审。
1. lib/Common:结果模型(五态/run 级聚合)、baseline 精确匹配、STALE_BASELINE 检测、退出码聚合——Pester 先红后绿。
2. PathReferences(fixtures:好/坏链接、`~/` 映射、URL/锚点排除、示例路径误报)——红→绿。
3. PluginConsistency(fixtures:三源一致/缺一/resolved 缺失 SKIP)——红→绿。
4. PolicyInvariants + `POLICY_INVARIANTS.yml`(fixtures:push 指令命中、allow_regex 放行)——红→绿。
5. ScriptAnalysis、Provenance(exactly-one 判定 fixtures)、SecretScan(含 gitleaks.toml、ENVIRONMENT_ERROR 路径)、ConfigWellFormedness——红→绿。
6. validate.ps1 聚合;对真仓实跑,把全部真实命中逐条登记进 `VALIDATION_BASELINE.yml`(完整字段,逐条人可读 reason+payoff),达成 PASS_WITH_BASELINE / 退出码 0。
7. `.github/workflows/offline-ci.yml` + README「校验与 CI」节。
8. 全量 Pester + validator 终跑,产物写 `docs/ai/last_test_run.txt`。

## Testing Plan
* `pwsh -Command "Invoke-Pester -Path tools/validate/tests -CI"`(全绿)
* `pwsh -File tools/validate/validate.ps1`(退出码 0;run 级 PASS_WITH_BASELINE,摘要逐条列 baseline)
* `pwsh -File tools/validate/validate.ps1 -Check path-references` 等逐项(退出码语义一致)
* 反证跑法:临时清空 baseline 再跑应退出码 1 且命中 ≥3(仅演示,不入库;fixture 已固化同一断言)
* fixture-scope 反证用例(评审补充,Pester 固化):同一 synthetic secret 位于 `tools/validate/tests/fixtures/**` 内 = allowlist 放行(带 reason);复制到 fixtures 之外 = SecretScan 必 FAIL;fixture-root 参数受约束——仅测试入口可用,或运行时校验 canonical path 必须等于/位于 `tools/validate/tests/fixtures`(生产 CLI 不得借此排除真实文件)
* **V1 机械反例全表用例(Phase 2)**:契约节 N1–N7 / P1–P4 逐条入 Pester(broken/clean fixture 落字面串);每例断言 finding 类别、`original_token` 完整保留、零父前缀降级或放行。
* **两类防回归用例(Phase 2,⑱乙)**:R-A 耐久治理文档悬空 literal path 必检出(fixture 复刻 + 真仓断言 `explicitly_included_durable_records` 两文件在生产扫描主体集合内);R-B 被 AC-2 排除文件中的同一缺陷 token 不入 path-references findings,且该文件仍在 SecretScan 输入集与 Provenance 覆盖集内。
* **排除边界用例(Phase 2,⑳乙)**:精确排除仅命中枚举字面路径——与被排除文件近名的未登记文件(HANDOFF-copy 形)仍入扫描主体;前缀排除以目录分隔符界定——`docs/ai/archive/` 之下排除、相邻 `docs/ai/archive-typo/` 形目录不误伤(禁无分隔符裸 StartsWith)。
* **真仓 exact-set(临时迁移断言)**:回稳后 3 身份 10 处,标注与 baseline-aware 替换条件见契约节;替换完成 = H5A 最终 merge gate。
* **docs-GREEN(裁决⑰④,可执行措辞)**:任何会改变生产扫描输入面 / 期望 finding 集 / baseline 或 claim 数据 / fixture 定义的 commit,均使之前的 GREEN 失效;最终 review tip 必须重跑本节标准验证命令并产物化;文件扩展名或「docs-only」标签不构成豁免依据(判例:⑬⑭转录 commit 未重跑,预存红灯至 round-4 RED 曝光——HANDOFF ⑮⑯)。审前冻结最终交接 commit 的唯一结构性例外及其成立条件 = QUALITY_GATES 11.1 docs-GREEN 条(单一定义处;⑳偏差明示)。
* **正式审查轮要件(计数附则⑰)**:9B/9A 双审前完成审前冻结——标准命令产 `docs/ai/last_test_run.txt`(命令/完整输出/退出码/tested_sha)+ 四 SHA 齐备(review_base_sha / review_tip_sha / tested_sha / handoff_snapshot_sha)+ 树净 + HEAD=快照;缺任一不构成有效正式审查轮。
* **psd1 schema 用例(Phase 2,㉑)**:重复条目拒绝 / 未知键拒绝 / durable∩exclusion 判红 / prefix 未以 `/` 结尾拒绝 / 文件缺失·不可解析·schema 失败 = ENVIRONMENT_ERROR(禁静默回退硬编码默认)。
* **final-handoff 闭环证据字段(㉑乙;机制单一定义处 = QUALITY_GATES 11.1 协议 A)**:staged_paths(恰两文件)/ prospective_tree_oid(`git write-tree`)/ 工作树与 index 一致且零未跟踪 / SecretScan、Provenance 各:命令 + 退出码 + 仓外 evidence 文件 + SHA-256 / committed_tree_oid(`git rev-parse HEAD^{tree}`)/ tree_identity_match: true;证据写仓外不可变、不回写仓库;evidence SHA-256 由 Author 附入 9B/9A prompt、Reviewer 在 verdict 回写,形成仓外证据双向绑定。

## Open Questions
None

## Human Approval Status

* Status: Approved
* Approved by: [Dean]
* Date: [2026/07/30]

> 此字段任何 Agent 不得修改。批准正式凭证 = 人类对本文件的 git commit;Status 由人类批准后自改。非 Approved 禁止进实现。
