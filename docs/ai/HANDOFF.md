# HANDOFF.md

> per-task 核心交接文件。当前任务:H5A · Validator Foundation(Round 1 第一单元)。

## Current Phase
**H5A 已停牌(2026-08-05,人类裁决):stopped, NOT converged — over-engineered** — 经三方外部诊断一致认定过度工程化(工具吃掉目的:原始需求三处漂移 15 分钟可修,流程演化出 81 测试/2 硬停/4 批准门而漂移零修复,且流程文档入扫描面产生自指螺旋)。分支、commit 与全部证据封存留档;不回退、不进 Phase 2、不再新增契约。三处已知漂移与 LICENSE 由普通小任务在本分支之外直接修(Claude 改 + 人类扫 diff + commit,不走批准门)。工作流日常缩回五条核心规则 + 三个机械闸门(见㉒);9A/9B 双审留给真项目

## Task Summary
按 `IMPROVEMENT_PLAN.md` §H5A(tag `plan-v1.1`)建治理 validator(七检查 = 原六项 + AC-11 JSON 良构性轻查,+ 登记式基线豁免 + offline-ci 种子)。详情见 TASK_BRIEF.md。

## Source of Truth
* `docs/ai/TASK_BRIEF.md`(0.1 扫描 + Acceptance Criteria 单一事实源)/ `docs/ai/IMPLEMENTATION_PLAN.md`(Status: Approved,含于 bc6c824/dd0e3fe;现行修订的补充凭证 7fc335d)/ `docs/ai/QUALITY_GATES.md`
* 上游冻结源:`IMPROVEMENT_PLAN.md` @ tag `plan-v1.1`(身份链:`docs/ai/archive/2026-07-30-improvement-plan-v1.1-landing/HANDOFF.md`)
* Base branch:`main` @ `b6ee9ea`(snapshot-first canonical;分支已重建对齐,原 edd8ab5 基链存档 `refs/private/h5a-pre-align-bc6c824`);工作分支:`task/h5a-validator-foundation`

## Plan Amendment(snapshot-first 权威对齐,2026-07-30)

```yaml
plan_amendment:
  reason: "Snapshot-first authority contract became canonical after the original H5A approval"
  canonical_base: b6ee9ea
  original_approval_source_commit: bc6c824      # 原批准凭证(迁移前基链)
  aligned_plan_commit: dd0e3fe                  # 对齐分支上承载原批准内容的实际 commit(cherry-pick -x,作者身份保留)
  private_pre_alignment_ref: refs/private/h5a-pre-align-bc6c824   # 原基链存档
  supplemental_approval_commit: 7fc335d   # = 7fc335d6da322638f76946dd05a2c5197336526e,人类 2026-07-30 创建(五路径精确暂存+机器比对,docs(plan): align H5A project instructions with snapshot-first authority)
  affected_files:
    - AGENTS.md                       # Project Overview 契约翻转 + 退出码/gitleaks 两行同步至修订后语义
    - docs/ai/TASK_BRIEF.md           # 评审修订(已在工作树)+ evidence-scope 约束
    - docs/ai/IMPLEMENTATION_PLAN.md  # 评审修订(已在工作树)+ 适用范围 evidence-scope 细化
    - docs/ai/HANDOFF.md              # 本节 + 流程注记对齐
    - docs/ai/QUALITY_GATES.md        # 七检查计数同步 + fixture-scope 质量契约（fix-round 2 纳入）
  implementation_allowed: true        # 2026-07-30 F1=A 裁决后开闸(Pre-Flight 9 组全绿 @d6028c5,结果落账 68f9800)
  preflight_required: done            # 已执行并落账;唯一裁决项 F1 经人类亲选 = 选项 A
```

## Review & Test Binding
* review_base_sha: [待 /implement 后填]
* review_tip_sha: [待填;9A 与 9B 必须同一个]
* review_verdict_9A: [待填] | verdict 文件: [docs/ai/review_9A.md]
* review_verdict_9B: [待填] | verdict 文件: [docs/ai/review_9B.md]
* tested_sha: [待填]
* guard_effectiveness: N/A(本任务不声称「回归用例有效」契约产物)
* review_sensitive_paths: `tools .github/workflows POLICY_INVARIANTS.yml README.md AGENTS.md CLAUDE.md docs/ai/TASK_BRIEF.md docs/ai/IMPLEMENTATION_PLAN.md docs/ai/QUALITY_GATES.md`
* handoff_snapshot_sha: [Author 统一落账时填]

## Runtime Identity
* model ID: claude-fable-5
* CC 版本 / effort / dynamic-workflow? / compaction 发生?: unknown / not observable / no / no
* 本轮用过的 diagnostic probe: None

## Work Log
* [2026-08-05] [人类 Dean + Claude Code] ㉒ 停牌裁决(人类亲选,经三方外部诊断一致认定过度工程化):H5A 分支状态 = **stopped, NOT converged — over-engineered**;保留分支、commit 与全部证据,不回退、不进 Phase 2、不再新增契约;Phase 1 replan 四文件随本 commit 封存(作记录、非批准,批准门未走);三处已知漂移 + LICENSE 改由独立小分支直接修(不走批准门);工作流日常缩回**五条核心规则**(快照仓 SSOT / 人类批准计划后才实现 / Author 交真实测试输出 / Reviewer 只读 diff 与测试证据零写入 / 同一修复再引 blocking 即停并拆新任务)+ **三个机械闸门**(审查 SHA 绑定干净工作树 / 实际 diff 不超批准文件范围 / 测试真实执行退出码可信);9A/9B 双审留给真项目(SeedLink、翻译工具级);元规则:任何新增流程/规则/登记表/检查项默认「不」,除非一句话说清省下的多于维护成本;真值钱保留项:snapshot-first、v1.1 文档作参考清单、真改动人类批准、「审本体不审转述」教训 [本 commit]
* [2026-08-04] [Claude Code] ㉑ 批准门审计第二轮三 verdict 处置(甲 approve 零新增 / 乙 一项 Verification Blocking / 丙 两项 Verification Blocking;两方均自声明规划审计不入 streak,计数 +0):**丙 B1' 经核实为真**——TASK_BRIEF 条款⑤、PLAN 契约节、QUALITY_GATES 排除范围 QA 三处「逐字一致」跨 YAML/psd1 格式机器不可执行,且 psd1 schema 与失败语义未冻结;修法 = 三处改「规范化语义等价」(四组集合 ordinal、`/` 分隔、去重后逐组相等)+ PLAN 冻结 psd1 schema(SchemaVersion + 四列表键与 AC-2 四组一一对应[采丙四键形,未采乙样例三键合并形,理由:保持与批准源分组 1:1]、非空字符串、prefix 必以 `/` 结尾、键内跨键禁重复、durable∩exclusion 判红、未知键判红、缺失/不可解析/schema 失败 = ENVIRONMENT_ERROR 禁静默回退)+ 验收比对定性为时点断言(随 per-task 归档出集,standing 测试只断言 psd1 自身 schema 合法性);**乙 V1 与丙 B2' 同源经核实为真**——原例外文本「由下一次运行/CI 承接」未冻结「SecretScan/Provenance 针对最终提交字节实际运行」的证明机制,与 final-tip fresh GREEN 冲突、证据不持久,「9B/9A 读 diff ≠ 运行检查」成立;修法 = QUALITY_GATES 11.1 冻结 **prospective-tree 闭环协议 A**(精确暂存恰两文件 + 工作树 index 一致零未跟踪 → `git write-tree` 记 prospective_tree_oid → 对该字节实跑 SecretScan/Provenance → 证据仓外不可变 + SHA-256 不回写 → 提交后 `HEAD^{tree}` 等值证明 → evidence 哈希附 9B/9A prompt、Reviewer verdict 回写双向绑定 → 任一条件不满足回退完整 fresh GREEN),PLAN Testing Plan 冻结最小证据字段;**丙主张终态协议属人类选择:协议 B(豁免边界 + Reviewer 审读替代)已并列文档化为批准门可改选项,默认 = 协议 A**(乙已给可执行全文、丙选项 (a) 与之实质一致,故以 A 为默认呈选——继⑮⑳后偏差明示惯例第三例);TASK_BRIEF 仅动条款⑤措辞(乙判定其无 last_test_run 回写暗示,核实属实:全文零该文件引用);乙 psd1 样例其余 Phase 2 测试建议(重复拒绝 / `/` 规范化 / 近名 / 分隔符 / 交集判红 / 缺失 fail-closed)已并入 Testing Plan psd1 schema 用例条;甲本轮自录方法论账(「原则正确性审查代替可行性审查」漏检形态)并提议「运行期数据文件」升格母本默认习语——登记 LOCAL-001 第三回流项;甲门前注记落 Next Step ②(批准句显式涵盖各决策点、否决互相独立);复跑全套 Pester GREEN(XML 仓外)、生产 finding 集 16 处零扰动、工作树恰四文件、diff --check 净;重停:先定点复核、后批准门 [待人类批准 commit]
* [2026-08-04] [Claude Code] ⑳ Phase 1 批准门审计三 verdict 处置(甲 approve / 乙 approve / 丙 暂缓批准两 blocking;丙自声明系批准门审计非正式审查轮,不入 streak 计数):**丙 B1 经核实为真**——PLAN 原文「单一定义处 = TASK_BRIEF」与 TASK_BRIEF:3 per-task 属性(任务末归档)矛盾,运行期若不硬编码即须解析短命任务文件;修法 = 运行期 SSOT 落 `tools/validate/path-references-scope.psd1`(与 requirements.psd1 / gitleaks.toml / VALIDATION_BASELINE.yml 同族,Import-PowerShellDataFile 原生零新依赖),TASK_BRIEF AC-2 改定位为批准语义与初始内容冻结源(新增条款⑤),psd1 变更纪律与 baseline registry 同级(仅人类批准 commit),Proposed Changes 增行、QUALITY_GATES 排除范围 QA 同步;丙所请「加入审查敏感路径」核实为已覆盖(review_sensitive_paths 首项 `tools` 前缀);**丙 B2 经核实为真**——原 docs-GREEN 措辞含「验证记录」类别,与母本审前冻结序(HANDOFF+last_test_run 测试后提交、两者均不在 review_sensitive_paths,核实本文件 :43)构成「跑测试→落产物→GREEN 失效→再跑」无穷回归;修法 = 类别表删「验证记录」、增**审前冻结最终交接 commit 结构性例外**(diff 机器可验限两文件 + AC-2 排除生效为成立条件 + 不豁免 SecretScan/Provenance 覆盖),QUALITY_GATES 11.1 为单一定义处、PLAN Testing Plan 指针引用;**该例外相对裁决⑰④乙文本基底构成收窄,按⑮先例偏差明示、供人类批准门单独否决**;甲预置注记落账:PLAN 反例表增 Phase 2 转写纪律(HOME/ 代写按语义还原为真实 tilde 前缀,RED 阶段 N1–N7 七例真实失败为还原正确性证明);乙两注记落账:Testing Plan 增排除边界用例(近名不排除 / 前缀带目录分隔符禁裸 StartsWith)、临时 10 处断言与 baseline-aware 替换完成时同步删除不得并存;复跑全套 Pester GREEN(XML 仓外)、生产 finding 集 16 处零扰动;四文件仍留工作树未 commit,重停批准门 [待人类批准 commit]
* [2026-08-04] [Claude Code] ⑲ Phase 1 四文件小型 replan 执行(新上下文,按 Next Step 任务书①–⑤,零实现文件触碰):a) TASK_BRIEF AC-2 重写——默认全量跟踪 .md + `path_references_v1_scan_scope` 机器可执行枚举(excluded_exact_paths 四件 / excluded_review_artifacts 两件 / excluded_prefixes 两条 / explicitly_included_durable_records 两件)+ 四条契约条款(禁宽排目录级通配、排除仅限扫描主体且 SecretScan/Provenance 不缩、其他检查不随缩面、v1 语义指针);2026-08-04 复核 `git ls-files` 全量 .md:仓内规范命名过程文件恰为枚举六件、无遗漏;安装映射短语含既钉身份 token 原样保留(期望集零扰动);b) PLAN 增「PathReferences v1 契约」节——四层排除体系判定表(⑱甲预检注记:层名/依据文件/判定时机/冲突时谁赢;层 1–3 文件级并集与层 4 token 级正交)、V1 六步执行规则 + 三冻结条款(?[] 永不可登记 / 未登记 ** fail-closed / 禁截断重分类)+ 类名约定(新类逐字 unsupported_pattern_syntax,既有类沿用现码名)、机械反例全表 N1–N7+P1–P4(HOME/ 代写前缀守去毒化,字面串只落 fixture;N4/N5 现行为截断放行标注为缺陷)、真仓 exact-set 回稳 3 身份 10 处标注 Step 2→Step 6 临时迁移断言(baseline-aware 替换 = H5A 最终 merge gate)、实现落点约束(AC-2 排除禁落共享 Select-ActiveScanFile);Testing Plan 增五条(反例全表 / 两类防回归 R-A·R-B / 临时迁移断言 / docs-GREEN 可执行措辞 / 正式轮四 SHA+标准产物要件);c) QUALITY_GATES 11.1 增三条(docs-GREEN / final-tip fresh GREEN / 排除范围 QA);d) 本文件:Ledger Writing Discipline 节(⑰④)、LOCAL-001 两回流项、PR0A backlog 登记、Current Phase 与 Next Step 改批准门入口;e) 验证:全套 Pester 复跑 GREEN(XML 定向仓外),生产 finding 集 16 处零扰动(编辑前后逐身份计数不变);四文件留工作树未 commit——批准凭证 = 人类七步门 commit [待人类批准 commit]
* [2026-08-04] [Claude Code] ⑱ 裁决⑰三方复核收讫,零阻断交棒:**甲**零阻断确认(自记 B1/V1 两项建议相左后归队:丙形经呈选核实事实复盘为更优、V1 独立类别换得 ?[] 显式封印;点名呈选环节暴露乙口径张力,证明「先核对可查事实」对评审方对称适用);预检注记——AC-2 排除清单+machine-local·managed registry+fixture-scope+evidence-scope 构成**四层排除体系**,PLAN 须写清判定顺序与互斥关系(表列:层名/依据文件/判定时机/冲突时谁赢);**乙**裁决包通过、Blocking Issues: None、实现继续硬停;Phase 1 细化约束全部并入 Next Step ⑤(机器可执行排除契约完整枚举、两类防回归用例、V1 冻结条款、docs-GREEN 可执行措辞落 11.1、七步批准门+plan-level Pre-Flight、Phase 1 获批不归零 streak);**③计数附则定性为 H5A 任务级人类裁决、canonical_workflow_change: false,全局复用须经 LOCAL-001 晋升(已按乙建议补录 Fix-Loop 附则范围注)**;**丙**核验 742e1ab 仅改 HANDOFF、树净、diff --check 无误,确认 Next Step 自包含可直接作新上下文入口;本上下文完成本落账后停止,零实现改动 [本 commit]
* [2026-08-04] [人类 Dean + Claude Code] ⑰ 裁决包四项经结构化问询亲选落账(甲乙丙三方推荐先行收讫;Author 核实分歧矩阵后呈选,零自裁——核实要点:两种 A 形均使真仓 exact-set 回稳 3 身份 10 处、乙形额外使 7 条 registry 中 4 条变生产死条目、V1 两案机械核心相同仅 finding 类别有别、乙裁决稿 exclude docs/ai/** 与其 round-4 红线「不接受宽泛豁免」存在口径张力已呈报):**① B1=方案 A 丙形**——生产扫描面默认全部跟踪 md,仅精确枚举排除 per-task 过程产物(TASK_BRIEF/IMPLEMENTATION_PLAN/HANDOFF/QUALITY_GATES/review verdict 文件)+ 既有 archive 与 fixtures 排除;AUTHORITY_CONTRACT、INSTALLER_GUARD 等耐久治理文档与 claude、codex 树继续扫描;禁宽排 docs/ai/**,排除清单逐文件枚举;属 AC-2 范围调整,须四文件小型 replan + 人类补充批准后方可实现;**② V1=unsupported_pattern_syntax fail-closed**——tokenizer 保留完整原始 token(至少 {}*?[], 直至真终止符),已登记 {}/* pattern 整串精确匹配优先(managed 展开逐目标验证/machine-local 按登记理由通过),未登记且含 pattern 元字符产 unsupported_pattern_syntax finding,普通未映射走 unrecognized-tilde,任何情况禁截断成父路径再分类;?[] 在 v1 永不可登记;乙合法/非法反例全表(新增 ?、[abc]、**+拼写变体三形)入测试,断言 finding 保留完整 original_token 且不退化为父前缀;**③ streak 维持 2 + 计数法附则**(附则逐字见 Fix-Loop ⑰行);**④ 甲两建议合并落点**——docs-GREEN 条款以乙文本为基底(凡改动生产扫描输入面/期望 finding 集/baseline 或 claim 数据/fixture 定义/验证记录的 commit 使先前 GREEN 失效,须对最终 review tip 重跑标准验证,docs-only 不豁免)入 QUALITY_GATES + PLAN Testing Plan 并引⑬⑭为判例;HANDOFF 写作纪律(finding ID/fixture 路径/git show 指针替代逐字复述扫描敏感 token);PR0A fixture backlog 登记 self-referential-verification-artifact;母本级推广列 LOCAL-001 回流;本轮不改母本 AGENTS.md;**执行序与禁改面**:Phase 1 仅四规划文件,人类补充批准前禁改 PathReferences.ps1/PathReferences.Tests.ps1/fixtures/Common.ps1;Phase 2 真仓 exact-set 回稳 3 身份 10 处,该 10 处断言标注为 Step 2–6 间临时迁移断言、H5A 合入前须 baseline-aware 替换;Phase 3 五步冻结后 9B 先 9A 后 [本 commit]
* [2026-08-04] [Claude Code] ⑯ round-4 复核三 verdict 收讫落账(甲 approve+两建议/乙 暂不通过/丙 审前停),逐项对照仓库核实:**丙 3 项全真**——审查绑定四字段确未冻结(:37-44)、last_test_run.txt 确不存在、Next Step 曾写「8 身份 15 处」与账目⑮/测试逐项计数的 16 矛盾(系⑮定稿前旧句未回改——发现 config.example 引文第二处后只改了测试与账目,本 commit 订正为 16);**乙 B1 机制经核实属实**(账目引文→finding→改期望集→再落账的循环链真实存在;新增 5 身份 6 处元引用无 H2 payoff,按 baseline 契约不可登记,现设计下 Step 6 无法仅凭有 payoff 的 baseline 达 PASS_WITH_BASELINE;README 真漂移 3 身份 10 处不受影响),修法方案 A(缩生产扫描面至规范表面;经查触 TASK_BRIEF:52 AC-2「抽取全部跟踪 .md」原文,构成计划范围调整需补充批准——乙亦自陈此风险)/方案 B(non-literal quote registry,file+exact_original_token 序数匹配、禁 glob、与 baseline 分离)均不由本上下文选;**乙 V1 经机械探针验证升级 Product Blocking**(乙自订条款):projects/?/memory 与 projects/[abc]/memory 两形在现实现下捕获截断为合法父前缀放行(charset 未含 ?[]),projects/**/memroy 形正确 FAIL——修法两选(charset 纳入 ?[] 走未登记拒绝 / 紧邻 pattern 元字符产 unsupported_pattern_syntax finding)入裁决包,未动代码;**streak 计数悬置**:乙票 caused_by_last_fix: yes(候选 2→3),丙票自声明不入 streak 且指出本轮快照未冻结、正式审查轮效力待认定——计数连同硬停解除条件交人类;甲两建议(活动扫描面 commit 含纯账目必以全套 GREEN 收尾入 QUALITY_GATES;账目引用敏感 token 去毒化书写,AUTHORITY_CONTRACT B1 先例)不阻塞待落点;本轮改动仅本账目与 15→16 订正,复跑全套 GREEN 确认账目文本零扰动 [本 commit]
* [2026-08-04] [Claude Code] ⑮ round-4 定点修复完成(执行⑭裁决任务书,新上下文 Author,Step-2-only):a) tilde 捕获扩至完整原始 token——charset 纳入 brace/wildcard/逗号,句尾 `.`/`,` 按标点修剪、pattern 字符零截断(证据:'captures brace and wildcard tilde tokens whole' / 'trims sentence punctuation without touching pattern characters');b) 精确 pattern registry 整串序数匹配,pattern token 永不触 file/prefix 名单(Resolve-PathReference tilde 分支 pattern-first):managed 4 条(`~/.claude/{rules,workflow,commands}` 展开三目录逐一验证、claude/CLAUDE.md:173 七命令文件 brace 展开、claude/CLAUDE.md:215 与 codex/AGENTS.md:8 两条 glob 按容器目录验证)+ machine-local 3 条(`~/.claude/projects/*/memory` 整串、claude/CLAUDE.md:196 rollout glob 整串、INSTALLER_GUARD.md:72 archive 通配全串),未登记一律 unrecognized-tilde→FAIL(证据:'resolves registered managed patterns to their audited expansion target lists' / 'treats registered machine-local patterns as machine-local by whole-string match only' / 'flags every unregistered brace or wildcard token as unrecognized - no truncation bypass'——乙机械反例五连全组,其中 memroy 变体在 RED 实录中经旧码 prefix 放行、修后必 FAIL;finding 保留完整 original_token:broken fixture 'preserves the complete original token on pattern findings');c) archive 前缀条目已删,仅两条精确例外——README.md:47 ARCHIVE_NOTE 全串(MachineLocalFiles 精确文件条目)+ GUARD:72 全串 pattern 条目;**「token 全串」条款适用说明(偏差明示供否决):完整捕获下 GUARD:72 实证 token 带通配尾缀,登记该全串而非裁决文字的裸目录转写;裸目录串引用现仅存于本文件 :81 账目引文,按「其余引用走受管映射」落为 finding**;archive 其余路径经 workflow 映射做存在性检查(证据:'registers exactly two audited archive exceptions; other archive paths use the managed mapping' + broken fixture archive 反例);d) 事实注释更正:install.ps1:43-48 mirror-replace 整个 workflow 目录,archive 属混合命名空间、最终解归 H3,此处仅两条精确例外(check 文件 Fact note 段,替换原「excluded from the mirror」错误表述);真仓 exact-set 重审计:3 身份 10 处 → 8 身份 16 处——新增 HANDOFF 账目引文 3 身份 4 处(rulez 变体、archive 裸串、config.example.toml×2;后者系⑬⑭转录 commit 引账目原文且未重跑测试而致的**预存红灯**,本轮 RED 实录首次曝光,登记入期望集并注明来历)+ PLAN:30 与 TASK_BRIEF:52 映射记号缩写各 1 处(未登记 pattern 按政策 FAIL);全部逐条分类注释在生产测试段,随 per-task 文档任务末归档而出集;RED(Passed 72/Failed 9,exit 9,失败全为行为缺失)→ GREEN(Passed 81/Failed 0,exit 0);PSSA Error 0/Warning 0(Information 15 不入门);触碰面:PathReferences.ps1、PathReferences.Tests.ps1、path-references fixtures(broken/clean 各扩,clean 增两展开目标桩)、本文件现行区与本账目——裁决范围外零改动 [wip commit e5d8579 + 本 commit]
* [2026-07-30] [人类 Dean] ⑭ 硬停裁决(经结构化问询亲选,逐字落账):乙 blocking 修法 = **方案 A**(完整 token + 精确 pattern registry:brace/wildcard 整串登记分类、managed brace 展开逐一验证、未登记 pattern 一律 FAIL);archive 边界 = **精确条目**(仅 README.md:47 与 docs/ai/INSTALLER_GUARD.md:72 两处实证 token 全串登记为 local-only 精确例外,非前缀;混合命名空间最终解归 H3);定点修复由新上下文 Author 执行,本上下文实现工作就此关闭 [本 commit]
* [2026-07-30] [Claude Code] ⑬ round 3 verdict 收讫,硬停落账:两项 Product Blocking 经只读核实为真(乙:token 正则截断致 {rulez,...}/memroy 类拼写错误绕过 FAIL;丙:workflow/archive 归类依据与 install.ps1:43-48 mirror-replace 事实相反——守卫存在恰因 archive **未被**排除于镜像,⑫ 所记"live-only, excluded from mirror"为事实错误,在此更正);本上下文未再触碰任何代码;待人类裁决事项与新上下文携带清单见 Next Step [本 commit]
* [2026-07-30] [Claude Code] ⑫ B-partial 窄修(Step-2-only,三 verdict 合并处置):**更正⑪两处不实叙述**——TildeFileMap 有效映射实为六条(3 文件+3 目录,`~/.codex/config.example.toml` 条目为照搬评审表未逐条核定 install.ps1 的事实错误,已删),所称「config.example 映射合法专项用例」当时不存在(声称闸门单句失守,今已以真实用例补上:example→unrecognized-tilde);真仓全量 93 finding 逐条审计分类:真漂移 3 身份 10 处(README 的 ./install.sh×7、skills/×2、引用语境示例链接 ../common/coding-style.md×1,均可带 H2 payoff 入 baseline)+ 机器本地/凭据/退役 ~15 处(machine-local 清单按证据扩至 7 精确条目+4 前缀)+ 结构性示例/速记/元引用 ~60 处;**弱信号令牌分类契约**:R3/R4 默认 non-literal 不查,(文件,令牌) 显式 literal-claim 表才查(生产表恰 AC-2 钦点两条,claim 按文件定位使规划文档元引用自然豁免;fixture 模式传自有 claim 表证明机理+未 claim 令牌不报用例);**真仓测试从包含断言改为完整精确集合约束**(期望集=审计 3 身份,含出现次数,无意外 finding;能力断言永久活在 broken fixture,新增 skills/ 复刻);大小写用例已有(broken fixture Sub/Page.md,序数比对 tracked 集非 Test-Path);RED(Passed 66/Failed 8,exit 8)→ GREEN(Passed 74/Failed 0,exit 0);PSSA 0/0 [wip commit]
* [2026-07-30] [Claude Code] ⑪ Execution Step 2(TDD)完成:PathReferences 检查(AC-2)——抽取规则集四条窄规则(R1 链接/图片/定义行·仅散文区;R2 `~/` 令牌·全文含代码区;R3 `./` 令牌·全文;R4 行内代码尾斜杠目录令牌),因 AC-2 指定的两处已知漂移(`./install.sh` 在围栏内、`skills/` 在行内代码)非链接语法,纯链接抽取无法满足 AC-2——规则集列明供审;`~/` 仅显式映射(与 install.ps1 同源核定)+ machine-local 显式清单(config.toml/projects/ + 裸根 `~/.claude`·`~/.codex` 两条,概念引用非文件断言);RED(Passed 44/Failed 25+1 BeforeAll,exit 26)→ GREEN(Passed 70/Failed 0,exit 0,含 clean/broken fixture 树、8 类违规各命中、fixture-root 越界拒绝、生产扫描双排除诱饵断言、P4 两漂移真仓检出);PSSA Error 0/Warning 0(1 闭包误报带理由压制、1 复数名词真改名);Select-ActiveScanFile 共享排除助手入 Common(甲的逐 AC 锁矩阵标配)[wip commit]
* [2026-07-30] [Claude Code] ⑩ Checkpoint A 复核处置(Step 2 暂缓):经代码核实接受第三方 Reviewer 两 blocking(重复 id 经 stale 判定的 id 键掩蔽真实陈旧条目、缺 baseline 根键静默空表无诊断)→ RED(新 fixture ×3 + 用例 ×3:Passed 41 / Failed 2,exit 2,失败均为 SchemaErrors 为空的行为缺失)→ 实现根键强制声明 + 重复 id 检出 → GREEN(Passed 43 / Failed 0,exit 0);PSSA Error 0 / Warning 0;.gitignore 按乙/丙共识**不加**,Pester XML 自本轮起经 PesterConfiguration.TestResult.OutputPath 定向仓外(仓根无 testResults.xml);Fix-Loop streak 0→1 逐字转录 [wip commit + 本 commit]
* [2026-07-30] [Claude Code] ⑨ Execution Step 1(TDD)完成:tests/Common.Tests.ps1(40 用例)+ fixtures/common ×3 → **红灯实录**(Passed 5 / Failed 35,exit 35,失败全为 NotImplementedException 行为缺失,非环境故障)→ lib/Common.ps1 实现(五态结果模型、SKIP 契约校验、baseline 精确匹配 + 未跑检查不判 STALE、run 级聚合与退出码、requirements 清单加载、git 跟踪枚举)→ **绿灯**(Passed 40 / Failed 0,exit 0);PSSA:Error 0 / Warning 0(em-dash 触发的 BOM 告警以去非 ASCII 根治,两处 New-* ShouldProcess 误报带理由 SuppressMessage,Information 8 不入门)[wip commit]
* [2026-07-30] [人类 Dean + Reviewer] 批准证据澄清裁决(逐字落账):HANDOFF 结构化三字段(Status=Approved / Approved by: Dean / Date: 2026/07/30)确认为人类亲笔,与 7fc335d 五文件 commit 共同构成有效补充批准证据;Reviewer 撤回其先前「占位符未填」Verification Blocking(第 93 行仅未清理模板占位,不推翻批准);不计 blocking、streak 保持 0;按指示本次落账将该占位改注 N/A,无需新批准 commit、无需重跑 Pre-Flight [本 commit]
* [2026-07-30] [Claude Code] ⑧ Execution Step 0 完成:三模块查定并冻结于 `tools/validate/requirements.psd1`(powershell-yaml 0.4.12 / PSScriptAnalyzer 1.25.0 / Pester 6.0.1——6.0.1 经实证含 `-Path`/`-CI` 参数,兼容 Testing Plan 命令;5.9.0 为备选未采用);gitleaks pinned **v8.30.1** windows_x64,官方 checksums 校验 SHA-256 = `d29144deff3a68aa93ced33dddf84b7fdc26070add4aa0f4513094c8332afc4e` 一致后落 `C:\Users\16097\bin\gitleaks.exe`(已在用户 PATH),`gitleaks version` 验证 8.30.1;三模块经 Install-Module -Scope CurrentUser 代装(人类已授权);该 release+checksum 待步骤 7 写入 offline-ci.yml [wip commit + 本 commit]
* [2026-07-30] [人类 Dean] ⑦ 裁决(经结构化问询亲选,Author 逐字落账):**F1 = 选项 A**——Change Budget 按仓内母本执行,IMPLEMENTATION_PLAN Proposed Changes 表(含于批准凭证 7fc335d)为 de-facto 白名单,不重开批准门;**依赖安装 = 授权 Author 代装**(Pester≥5/PSScriptAnalyzer/powershell-yaml 经 Install-Module + gitleaks pinned release 下载 + SHA-256 校验,版本查定与安装全程入 HANDOFF/diff 供审) [本 commit]
* [2026-07-30] [Claude Code] ⑦ /implement Pre-Flight(绑最终 tip d6028c5):Frozen Acceptance 存在且内部一致、计划无自相矛盾/无验收冲突/无 Reviewer 陷阱项、五态模型三文件口径一致、evidence-scope×fixture-scope 逐 AC 矩阵无冲突、依赖 pinning 无矛盾、零命中断言 4 组 @tip 全绿、事实抽查(三处漂移存在/唯一跟踪 json/.gitattributes/引用文件)全证实;**发现 F1 交人类裁决**(TASK_BRIEF 无「Change Budget & Allowed Paths」节:家目录母本 :133 要求之、仓内母本无「改动面预算」节,LOCAL-001 收敛未落仓,/implement 4.3 预算自检无基准);非阻断陈旧描述 2 处(PLAN "106 跟踪文件"现 140、"install.ps1:53"现 :67,不动);环境探查:pwsh 7.6.3 ✓,Pester 仅 3.4.0(需≥5)/PSScriptAnalyzer/powershell-yaml/gitleaks 全缺(涉网络,待人类确认安装方式) [本 commit]
* [2026-07-30] [Claude Code] ⑥ SHA 补录:supplemental_approval_commit = 7fc335d 落入 Plan Amendment 与 Human Approval Evidence,Current Phase/Next Step 同步;implementation_allowed 保持 false,待最终 tip Pre-Flight [本 commit]
* [2026-07-30] [人类 Dean] 窄批准补充 commit **7fc335d**:亲笔批准证据(Status=Approved/Dean/2026-07-30)写入 HANDOFF 后,五路径精确暂存 + `git diff --cached --name-only` 机器比对恰为五文件,创建批准 commit——现行计划正式凭证 [7fc335d]
* [2026-07-30] [Claude Code] ⑥ 硬停处置(新上下文定点任务):affected_files 补 QUALITY_GATES 第 5 项 + Fix-Loop 第 2 轮账目落账;经 3 份独立 verdict 复核通过(0 blocking/0 归因),按母本重置条款 streak 归零落账 [含于 7fc335d]
* [2026-07-30] [Claude Code] ⑥ snapshot-first 权威对齐:分支重建至 main@b6ee9ea(cherry-pick -x bc6c824→dd0e3fe,原链存档 refs/private/h5a-pre-align-bc6c824,wip 三文件对私有快照零漂移恢复)、根 AGENTS.md 契约翻转 + 两行过期语义同步、evidence-scope 约束入 TASK_BRIEF/PLAN、本文件流程注记对齐 [未 commit,待人类窄批准]
* [2026-07-30] [Claude Code] 并入双方规划评审:状态模型五态(PASS/BASELINE/SKIP/FAIL/ENVIRONMENT_ERROR + run 级 PASS_WITH_BASELINE)、豁免登记 registry(`VALIDATION_BASELINE.yml` 完整字段+精确匹配+STALE_BASELINE)、SKIP 冻结语义(仅 prerequisite_not_landed,落仓自动激活)、依赖 pinning(requirements.psd1 + gitleaks release+checksum)、JSON 良构性纳入 / TOML 显式推迟给 PR2;批准顺序按 B1 修正 [未 commit]
* [2026-07-30] [人类 Dean] 审阅规划产物并亲改 IMPLEMENTATION_PLAN Status=Approved(先改状态、后 commit,符合 B1 修正序)[工作树]
* [2026-07-30] [Claude Code] /plan(H5A):建分支、归档上任务 HANDOFF、脚手架根 AGENTS.md+CLAUDE.md+QUALITY_GATES、落 TASK_BRIEF+IMPLEMENTATION_PLAN(Pending)[未 commit——批准凭证=人类 commit]
* [2026-07-30] [Claude Code] 前序任务收尾:v1.1 落仓(e4092c3)+ 身份链闭合(edd8ab5)+ tag plan-v1.1 [main]

## Known Issues
None(本任务)。跨任务注记:「H5A 走了无 Change Budget 节的 /implement(F1=A 裁决)」登记为 **LOCAL-001**(改动面预算条款落仓)的输入案例——预算特性落仓前最后一个豁免样本,供校验追溯口径(新条款要求补节还是承认历史豁免)。原登记的流程级 follow-up(plan.md 批准顺序矛盾)**已闭环**:修正经独立任务落仓(62b07d1,现已在 canonical main),权威关系同日翻转为 snapshot-first;活母本收敛由 LOCAL-001 晋升 + 部署承接,不再是 follow-up。
* **LOCAL-001 增补两回流项(裁决⑰④,⑲落账)**:①母本级账目去毒化写作纪律(HANDOFF 模板 / 母本 AGENTS.md 层面);②Fix-Loop 计数附则全局化(正式轮要件:四 SHA 冻结 + 标准测试产物 + 结构化 reviewer verdict)。均须经 LOCAL-001 晋升流程落仓;本任务不改母本 AGENTS.md。
* **PR0A backlog 登记(裁决⑰④,⑲落账)**:fixture_id `self-referential-verification-artifact`,expected: detect_input_surface_changed / invalidate_previous_green / require_fresh_final_tip_run——纵深防御,不替代 scanner scope 与 parser 正确性。
* **LOCAL-001 第三回流项(㉑甲)**:「运行期要消费的契约落 tools/validate 数据文件,规划文件只做批准语义与初始内容冻结源」升格为母本默认习语(psd1 系仓内该家族第四成员,判例⑳㉑)。

## Fix-Loop Counter
`[⑥ fix-round 2 | 修 B1 fixture-scope/B2 边界指针/B3 时态 | 新增触碰: docs/ai/QUALITY_GATES.md(计数同步) | Reviewer(丙)判定: 1× Verification Blocking(HANDOFF 批准命令仍目录级暂存)caused_by_last_fix: yes + 1× Product/Process Blocking(七检查未同步六处)caused_by_last_fix: no]`
`[⑥ fix-round 3 前 | Reviewer(丙)判定: 1× Verification Blocking(affected_files 漏列 QUALITY_GATES)caused_by_last_fix: yes]`
`[⑥ fix-round 3 | 定点复核通过,3 份独立 verdict 均 approve;Blocking Issues: None;零新增 Product/Verification Blocking,零 caused_by_last_fix: yes;affected_files 五路径、精确暂存面与硬停记账闭合;硬停处置链(硬停→人类裁决→定点任务→新上下文 Author→零越权→外审通过)按设计走完,留档为硬停 SOP 判例]`
`[⑨ 实现期 round 1(Checkpoint A 复核) | Reviewer(第三方)判定: Common registry 两缺口——重复 id 未检出(掩蔽 stale 检测)+ 文件存在但缺 baseline 根键静默按空 registry | caused_by_last_fix: yes | 处置: Step 2 暂缓,Step 1 内 RED→GREEN 补齐(含 baseline: [] 合法空 registry 用例),落账后再复核]`
`[⑨ 实现期 round 1 复核(A re-review) | 修复经 3 份独立 verdict 一致通过(65fed3a/ebc050c);Blocking Issues: None;caused_by_last_fix yes 计 0;丙注记:最终验收仍须冻结标准 Pester 命令产证,仓外 OutputPath 仅日常轮次]`
`[⑪ 实现期 round 2(B-partial 复核) | 乙判定: B1 Verification Blocking(真仓 P4 包含断言构成反向棘轮——H2 清漂移即测试变红)+ B2 Product Blocking(未映射 ~/ 一律 FAIL 与 canonical 文档冲突,须建分类契约+完整 finding 集约束);丙判定: 1× 事实错误(TildeFileMap 含 install.ps1 从不产生的 ~/.codex/config.example.toml + 报告声称的 config.example 专项用例不存在);甲: 零阻断放行(被更严 verdict 覆盖) | caused_by_last_fix: yes(同轮多项计 1) | 处置: Step 3 暂缓,Step-2-only 窄修]`
`[⑫ 实现期 round 3(B-partial-review-fix 复核) | 乙判定: 1× Product Blocking(brace/wildcard tilde 令牌被正则截断后按合法父路径分类——~/.claude/{rulez,...} 截为 ~/.claude/ 裸根放行、projects/*/memroy 截为前缀放行,未知模式与拼写错误绕过 unrecognized_tilde→FAIL;修法人类二选:方案 A 完整 token+精确 pattern registry[推荐]/方案 B 受控 brace 展开)caused_by_last_fix: yes | 丙判定: 1× Product Blocking(~/.claude/workflow/archive/ 误归 machine-local,注释"excluded from the mirror"与 install.ps1:43-48 全目录 mirror-replace 事实相反,前缀例外构成整段逃逸,PathReferences.Tests.ps1 反把错误分类锁为预期)caused_by_last_fix: yes | 甲: 修复通过零新增(被两票否决覆盖),自认上轮核销了不存在的声称用例,新增结构规则:合规声称须附证据指针(测试名/文件:行)+丙侧定点抽验 | 同轮多项按问题去重计 1 | streak 1→2,**硬停触发**]`
`[⑮ 实现期 round 4(硬停后定点修复,新上下文) | 执行⑭:方案 A + archive 精确条目;RED 9 失败→GREEN 81/0;真仓 exact-set 重审计 8 身份 16 处(含⑬⑭转录 commit 预存红灯 config.example 引文×2 曝光落账);「全串登记」偏差已明示待裁;自查裁决范围外零改动 | streak 判定待独立 Reviewer(归零或递增)]`
`[⑯ 实现期 round 4 复核 | 甲: approve,建议 docs-commit 不豁免 GREEN + 账目去毒化;乙: B1 Verification Blocking(exact-set 与活动任务记录自我引用循环)caused_by_last_fix: yes + V1 经 Author 探针验证升级 Product Blocking(?/[] 元字符截断为合法父前缀放行);丙: Snapshot/Evidence/Verification 三 blocking(审前冻结缺口,自声明不入 streak) | streak 是否 2→3 悬置交人类(乙票按条款计 yes;本轮快照未冻结的程序效力由人类认定) | 硬停持续,零实现改动]`
`[⑰ 计数法附则(人类亲选,2026-08-04,一次落账以后不逐轮争议) | round-4 复核轮因审前快照未冻结、无正式测试产物,不构成有效正式审查轮:其产品判断(B1/V1)作为人类确认的硬停后整改输入照修不打折,但不具 streak 计数效力;自此计数效力(递增与归零)均绑定正式审查轮——四 SHA 冻结+标准测试产物齐备;streak 维持 2]`
`[⑰ 附则适用范围注(乙复核建议,⑱落账) | scope: H5A 本任务;canonical_workflow_change: false——不构成对母本 Fix-Loop 契约的修改,全局复用须经 LOCAL-001 晋升;正式轮要件:四 SHA 冻结+标准测试产物+结构化 reviewer verdict]`
* streak: 2(计数法附则见⑰行;round-4 复核轮不计数;硬停持续;B1/V1 按⑰裁决整改;归零条件=新批准周期正式 9B/9A 双审 Blocking Issues: None;历史账目⑪–⑰保留不删不改)

## Ledger Writing Discipline(裁决⑰④,自⑲起生效)
对 path-like 反例与扫描敏感 token:优先以 finding ID / fixture 路径 / `git show <commit>:<path>` 指针引用;除非验证契约要求精确原文,不在活动过程记录中逐字复述完整 token(家目录 tilde 前缀以 HOME/ 代写)。历史账目⑪–⑰的既有逐字引文按不可变账目保留——其 finding 身份现钉在测试期望集,Phase 2 排除契约落地后随扫描主体排除出集。

## Remaining Risks / Debt
Debt: none(已知内容漂移不是本任务的债——它们是 H1–H3 的验收对象,在 validator baseline 中以 payoff 标注)

## Quality Gates
见 `docs/ai/QUALITY_GATES.md`(11.1 + 11.2 基础组适用,其余 N/A);实现完成后逐项回填。

| 维度/闸门 | 状态(Pass/N/A) | 证据文件或 N/A 原因 |
|---|---|---|
| 测试 QA(11.1) | 待实现 | docs/ai/last_test_run.txt(实现后) |
| 安全基础(11.2) | 待实现 | docs/ai/QUALITY_GATES.md 逐项 |
| 其余全部 | N/A | TASK_BRIEF 0.1 扫描 |

## Quick-Version Fields
* Applicability Scan(0.1):见 TASK_BRIEF(7/8/9-基础 关注,其余 N/A)
* Human Approval Evidence:Status=Approved 已由人类亲填(Dean,2026-07-30,含于 bc6c824/dd0e3fe);**现行计划的正式凭证 = 窄批准补充 commit 7fc335d**(= 7fc335d6da322638f76946dd05a2c5197336526e,覆盖评审修订 + 权威对齐 + fix-round 1–3 定点修复,内含下方人类亲笔批准证据):supplemental_approval_commit = 7fc335d(已补录,本交接 commit)
* 人类补充批准句(**由人类在 commit 前亲笔写在下一行,Agent 不得代填**):

* Status: Approved
* Approved by: [Dean]
* Date: [2026/07/30]
  > 批准采用上方结构化三字段(Status / Approved by / Date,人类亲填),本句 N/A——经人类 2026-07-30 澄清裁决与 Reviewer 复核确认(其先前基于本占位符的 Verification Blocking 已撤回、不计数)。
* Phase 1(裁决⑰范围修订)补充批准:**待人类七步门**——批准句由人类亲笔、批准 commit 由人类创建,SHA 由 Author 批准后补录(流程见 Next Step;上方 2026-07-30 凭证不覆盖本次修订)

## Next Step
**无(本任务已停牌封存,㉒)。** 原七步批准门、Phase 2/3 序、携带清单随停牌全部作废(历史文本见本 commit 前的 git 记录)。三处已知漂移与 LICENSE 在独立小分支 `fix/known-drifts-license` 直接修:Claude 改 + 人类扫 diff + commit/merge,不走本文件任何批准门。本仓后续日常改动一律走㉒的五条规则 + 三闸门。
