# TASK_BRIEF.md — H5A · Validator Foundation

> per-task 文件,blind review 的唯一需求依据。上游需求冻结源:`IMPROVEMENT_PLAN.md` §H5A(tag `plan-v1.1`)。

## Dimension Applicability Scan

| # | 维度 | 关注/N/A | N/A 原因 | 关注后展开/验收 |
|---|------|---------|---------|----------------|
| 1 | 产品定位 | N/A | 内部工具,「真实可发布产品」判据①②皆否 | — |
| 2 | 用户研究 | N/A | 同上,唯一用户即仓库维护者本人 | — |
| 3 | 产品策划/PM | N/A | 需求已由 IMPROVEMENT_PLAN v1.1 五轮评审冻结,不再重策划 | — |
| 4 | 交互设计 UX | N/A | 无界面;CLI 输出面向维护者,非面向用户内容 | — |
| 5 | 视觉设计 UI | N/A | 同上 | — |
| 6 | 美术/内容表现 | N/A | 同上 | — |
| 7 | 技术开发 | **关注** | — | 开发主干 |
| 8 | 测试/QA | **关注** | — | QUALITY_GATES 11.1(Pester 单测 + fixture) |
| 9 | 安全/隐私/合规 | **关注(基础组)** | 敏感面扩展 N/A:无 auth/支付/用户数据/对外服务;secret scan 本身是任务交付物 | QUALITY_GATES 11.2 基础组 |
| 10 | 可访问性/普适性 | N/A | 无界面;CLI 无鼠标/图形依赖 | — |
| 11 | 数据分析 | N/A | 非发布产品,成功=验收全过 | — |
| 12 | 运营增长 | N/A | 非发布产品 | — |
| 13 | 商业模式 | N/A | 非发布产品 | — |
| 14 | 品牌 | N/A | 非发布产品 | — |
| 15 | 内容 | N/A | validator 消息为工程输出,非面向用户内容 | — |
| 16 | 客服与用户成功 | N/A | 非发布产品 | — |
| 17 | 项目管理 | N/A | by-trunk(单任务单批,依赖序已由 v1.1 §1 冻结) | — |
| 18 | 组织与人才 | N/A | 单人仓;Author 兼全部角色(专家 agent 缺位按 `rules/common/agents.md` Fallback rule 降级执行方式、不降级职责) | — |

## Original Request
IMPROVEMENT_PLAN v1.1(APPROVED FOR PLANNING INPUT)Round 1 第一单元:**H5A — Validator foundation**。人类经双方终审转达后指示直接进入正式 `/plan`,H5A 与 PR0A 为两个独立规划单元,本 brief 只覆盖 H5A。

## Goal
建立仓库治理 validator 及其最小 CI(offline-ci 种子),使 H1/H2/H3/H4 之后能「落在绿色 H5A 之上」:七项检查(引用路径 / 插件清单一致性 / 注册策略不变量 / PowerShell 静态分析 / provenance 校验 / secret 扫描 / JSON 良构性轻查[AC-11 评审补充])全部可运行、确定性、带登记式基线豁免,已知漂移被显形登记而非掩盖。

## Non-Goals
* 不修复任何被检出的漂移内容——`install.sh`/`skills/` 幽灵引用与 push 指令归 H2,installer 参数化归 H3,LICENSE/PROVENANCE 内容归 H1,`plugins.resolved.json` 生成归 H4。
* 不实现 H5B(JSON Schema + example validation,PR1 后激活)。
* 不实现 PR0A 的 eval fixture / 评分(独立规划单元)。
* 不改动 `claude/**`、`codex/**`、`portable/**` 任何内容文件。

## Constraints
* validator 目标运行时 **pwsh 7**(`install.ps1` 保持 5.1 兼容,不受本任务影响、也不被本任务修改)。
* 依赖模块 powershell-yaml / PSScriptAnalyzer / Pester ≥5:**不自动安装**;缺失 = ENVIRONMENT_ERROR(退出码 2 + 明确安装指引)。gitleaks 为本地前置工具(一次性安装),缺失同为 ENVIRONMENT_ERROR;CI 强制运行。
* 可复现依赖:三个 PowerShell 模块的精确版本冻结于 `tools/validate/requirements.psd1`(实现第 0 步定值并入 diff,本地指引与 CI 同源);gitleaks 固定 release + checksum。「无 package manifest」≠「无依赖管理」。
* 确定性:同一 worktree 状态重复运行,输出与退出码一致;不依赖网络与时间(CI 的模块安装步骤除外,版本 pinned)。
* `POLICY_INVARIANTS.yml` 文件名与两条初始 invariant 内容按 v1.1 §H5A 冻结,不重开。
* **扫描范围契约(evidence-scope,随 snapshot-first 迁移冻结;语义出处 = `docs/ai/archive/2026-07-30-change-budget-evidence/EVIDENCE-INDEX.md` → Scanner scope contract)**:活动策略/引用/唯一性类检查(AC-2、AC-4 等)排除 `docs/ai/archive/**`——历史证据快照不作现行规则,防止旧文被判为当前违规;secret 扫描(AC-7)**包含** `docs/ai/archive/**`;provenance 覆盖(AC-6)包含全部跟踪文件、证据文件不例外;字节精确证据(scoped `.gitattributes` `* -text` 目录)不得被 validator 或任何格式化/EOL 步骤改写。
* **fixture 范围契约(冻结)**:负向 fixture(坏链接、非法 JSON、PSSA 违规、假 secret 等)固定位于 `tools/validate/tests/fixtures/**`;活动检查(AC-2 路径引用、AC-4 策略不变量、AC-5 静态分析、AC-11 良构性)一律**排除该目录**,测试经显式 fixture-root 参数调用检查逻辑,生产扫描永不摄取 fixture;SecretScan(AC-7)**包含** fixtures,假 secret 逐条进 `gitleaks.toml` 精确 allowlist + reason;Provenance(AC-6)不排除——fixture 也是跟踪文件,须被覆盖规则命中;**禁止用 `VALIDATION_BASELINE.yml` 豁免掩盖 fixture 命中**(baseline 只登记真实仓库漂移)。
* Author 无远程操作权限:CI 真实转绿的观察与确认由人类在 push 后完成。

## Acceptance Criteria
* **AC-1 入口、状态模型与退出码**:仓库根运行 `pwsh -File tools/validate/validate.ps1` 输出逐检查摘要。check 级状态 = PASS / BASELINE / SKIP / FAIL / ENVIRONMENT_ERROR;run 级状态 = PASS / PASS_WITH_BASELINE / FAIL / ENVIRONMENT_ERROR,**BASELINE 不得伪装成 PASS**(存在任一 BASELINE 条目时 run 级必须显示 PASS_WITH_BASELINE 并逐条列出)。退出码:0 = PASS 或 PASS_WITH_BASELINE,1 = FAIL,2 = ENVIRONMENT_ERROR。当前 HEAD + 交付的 baseline 下 = PASS_WITH_BASELINE,退出码 0。
* **AC-2 引用路径检查**:默认扫描**全部跟踪 `.md`**(耐久治理文档与 `claude/`、`codex/` 树继续全量在扫),抽取相对路径 markdown 链接目标(排除 URL/锚点),并按安装映射(`~/.claude/*`→`claude/*`、`~/.codex/AGENTS.md`→`codex/AGENTS.md`)解析家目录引用;已知漂移(`claude/rules/README.md` 的 `./install.sh` 与 `skills/`)必被检出,且仅能以 baseline 豁免(payoff=H2)转为 BASELINE 状态。**扫描主体排除面 = 机器可执行契约(裁决⑰ B1 丙形,2026-08-04;一次枚举冻结,禁「见假阳性再补」)**:

  ```yaml
  path_references_v1_scan_scope:
    input:
      tracked_markdown: true                  # 默认全量
    excluded_exact_paths:                     # 当前任务过程性产物(审查元引用自指污染源),逐文件枚举
      - docs/ai/TASK_BRIEF.md
      - docs/ai/IMPLEMENTATION_PLAN.md
      - docs/ai/HANDOFF.md
      - docs/ai/QUALITY_GATES.md
    excluded_review_artifacts:                # 规范命名 verdict 文件(落仓即适用)
      - docs/ai/review_9A.md
      - docs/ai/review_9B.md
    excluded_prefixes:                        # 即既有 fixture-scope / evidence-scope 两契约前缀,此处引用、不新增
      - tools/validate/tests/fixtures/
      - docs/ai/archive/
    explicitly_included_durable_records:      # 防回归锚点:永不得出现在任何排除集
      - docs/ai/AUTHORITY_CONTRACT.md
      - docs/ai/INSTALLER_GUARD.md
  ```

  排除契约条款:① **禁宽排**——严禁以 `docs/ai/**` 或任何目录级通配/glob 作排除依据,exact 排除只能逐文件枚举(2026-08-04 复核 `git ls-files` 全量 .md:仓内规范命名过程文件恰为上表六件,无遗漏);② 排除仅作用于**扫描主体**——被排除文件仍是合法链接**目标**(存在性宇宙 = 全部跟踪文件),且仍受 SecretScan(AC-7)与 Provenance(AC-6)全量覆盖;③ 本排除面为 path-references 专属,AC-4/AC-5/AC-11 等其他检查范围**不随本条缩面**;④ pattern token 语义 fail-closed 契约(unsupported_pattern_syntax、v1 不可登记字符、六步执行规则与机械反例全表)冻结于 IMPLEMENTATION_PLAN「PathReferences v1 契约」节;⑤ 本枚举 = **批准语义与初始内容冻结源**,运行期 SSOT = `tools/validate/path-references-scope.psd1`(Phase 2 新增数据文件,与 requirements.psd1 / gitleaks.toml / VALIDATION_BASELINE.yml 同族;初始内容与本枚举**规范化语义等价**——四组集合经 ordinal、`/` 分隔、去重规范化后逐组相等,跨格式禁用「逐字」判据[㉑丙];psd1 schema 与 fail-closed 行为冻结于 IMPLEMENTATION_PLAN 契约节;此后变更仅经人类批准 commit)——本文件任务末归档后,该 psd1 即唯一运行期权威(⑳丙批准门审计 B1)。
* **AC-3 插件清单一致性**:`install.ps1 $plugins` vs `README.md` 部署节 vs `claude/settings.json enabledPlugins` 三方一致则 PASS;`plugins.resolved.json` 缺失报 SKIP(唯一合法理由 `prerequisite_not_landed`,pending H4),不误报 FAIL;**该文件一旦入仓即自动转强制校验(无人工开关),存在但不可解析 = FAIL**。任何被解析源(install.ps1 / README / settings.json)解析失败同为 FAIL。
* **AC-4 策略不变量**:`POLICY_INVARIANTS.yml` 存在并含 v1.1 的 `remote-ops-human-only` 与 `reviewer-zero-repo-write` 两条;`claude/rules/common/git-workflow.md` 的 push 指令被 `remote-ops-human-only` 检出→baseline 豁免(payoff=H2)。
* **AC-5 静态分析**:PSScriptAnalyzer 覆盖 `install.ps1` 与 `tools/validate/**/*.ps1`;Error 级 0;Warning 级为 0 或逐条 baseline 豁免(install.ps1 的豁免 payoff=H3)。
* **AC-6 provenance 校验**:`PROVENANCE.yml` 缺失报 SKIP(`prerequisite_not_landed`,pending H1,仅在 H1 未落地期间合法);入仓即自动转强制校验,存在但不可解析/schema 错 = FAIL;校验语义 =「每个跟踪文件恰被一条规则覆盖」(零覆盖/重复覆盖均 FAIL)——该逻辑在 H1 前以 fixture 测试证明。SKIP 与豁免同等待遇:每条 SKIP 输出必引用激活它的 PR;H1/H4 的验收含「对应检查由 SKIP 转纯 PASS」。
* **AC-7 secret 扫描**:gitleaks pinned(固定 release 版本 + 制品 SHA-256 checksum,均记录于 workflow);扫描范围 = git 跟踪文件;本地不在 PATH = **ENVIRONMENT_ERROR**(exit 2 + 安装指引——不是 SKIP、更不是"无泄漏");CI 下载/校验失败 = ENVIRONMENT_ERROR;allowlist 位于 `tools/validate/gitleaks.toml`,仅允许精确条目 + 逐条 reason,禁目录级/整类忽略。
* **AC-8 测试**:`pwsh -Command "Invoke-Pester -Path tools/validate/tests -CI"` 全绿;每项检查的判定逻辑均有正反 fixture 用例(尤其:三处已知漂移在无豁免 fixture 下必红)。
* **AC-9 基线闭环(登记 registry)**:豁免的唯一落点是机器可审计的 `tools/validate/VALIDATION_BASELINE.yml`,每条必含 `{id, check_id, exact_target, exact_observation, reason, payoff: {work_item, condition}, introduced_by_plan, owner, status}`;**仅精确匹配**(精确 check + 精确文件 + 精确命中内容,禁 glob/整类错误/模糊正则豁免);未登记违规 = FAIL;登记内容已消失而条目仍在 = STALE_BASELINE → run 级 FAIL;豁免的新增/扩大/修改只能经人类批准的 commit 入仓;H2/H3 验收 = 删除对应豁免、相关检查转纯 PASS。
* **AC-10 CI 种子**:`.github/workflows/offline-ci.yml` 定义 windows-latest 任务(checkout → pinned 模块安装 → validator → Pester → gitleaks),零 credential 依赖;本地验收 = 文件存在且 YAML 可解析、步骤与本表一致;真实运行转绿由人类 push 后确认。
* **AC-11 配置良构性(评审补充项)**:跟踪的 `*.json`(现即 `claude/settings.json`)必须可解析为合法 JSON,解析失败 = FAIL(实现上与 AC-3 的解析共用);TOML(`codex/config.example.toml`)良构性**显式推迟**——需引入 TOML 解析依赖,登记由 PR2(reviewer profile TOML 工具链到位时)承接,本任务不做,不算静默缩水。
* **反例(不得成立)**:validator 对当前 HEAD 报 0 FAIL 且 baseline 为空——已知漂移必须显形,否则检查未生效。

## Relevant User Preferences
* 不夹带无关改动;不修被检出的漂移(那是 H1–H3 的验收)。
* 中文说明、英文代码与提交信息;UTF-8 无 BOM;LF。
* 不自动安装依赖;网络类命令先告知。
* NEVER push/pull/merge —— 分支合并与 CI 确认由人类执行。
