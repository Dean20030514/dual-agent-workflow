# HANDOFF — 删除 `[Verification Blocking]` 类 · 9P 默认单轮 · 七字段减三 · 便携版 v3.5（2026-09-03，已合入 main）

> 本档是该任务的完整交接记录，自 `docs/ai/HANDOFF.md` 文首归档而来。Routine 模式执行（纯规则文档）；全部改动含一轮独立审查的修复以**单一 commit** 合入 main（本档随该 commit 入库）。人类命题：「Codex 过度工程化已刻不容缓，必须解决」。

## 诊断（量化）

数据面 = 三个真实项目（SeedLink / game-translator / xlsx-organizer）`docs/ai/archive` 全量 + 7 个最大任务的 `review_9A/9B/9P.md` 逐条分类（335 条 blocking）+ `~/.codex` 线程库与 rollout。

| 指标 | 数值 |
|---|---|
| 8 月起每任务证据产物膨胀 | 5–70 倍（SeedLink 每任务 535 → 5801 → 37696 行；单份 `last_test_run.txt` 4 MB） |
| 月吞吐（每项目） | 6 月约 100 任务 → 8 月 18 任务 |
| 335 条 blocking 中标 `[Verification]` | 177 条 |
| 用户可感知的缺陷 | 46 条（14%） |
| 账本 / 格式 / 负向对照覆盖三类 | 63% |
| Proposed Fix 要求"再跑证据 / 加装置 / 加产物 / 改规则"的 | 231 条（69%） |
| SeedLink 09-02（3 行代码改动） | 4 轮 8 份 verdict 全「不通过」、全部零 Product、Reviewer 自述"产品需求实质已解决"；2 天、11 次 Codex、5 次十闸门重跑、20 次手工六步 |
| game-translator 切片 ① | 一份 9B 因 `.pytest_cache/` 不可枚举整轮拒审 |

**根因是契约不是 Codex**：`[Verification Blocking]` 面无界 → 任一条即「不通过」→ 收敛门要每份 verdict 通过 → 整个 PLAN / TASK_BRIEF / tests 皆 review-sensitive，改证据即换 tip 全量重跑 → 新账本数字 → 新证据发现。2026-08-15 只把该类移出 streak、2026-08-30 只加成立门槛，合并门始终没动。Reviewer 在忠实执行契约。

## 改动（15 文件，+306 / −279，rename 感知；删根不打补丁）

* **Blocking 只收 `[Product Blocking]`**（`claude/workflow/AGENTS.md` → Reviewer verdict 分类语义，唯一定义处）：每条须写出具体后果；验收未满足须有具体反例（缺证据 ≠ 未满足）；删/弱化测试须三处无说明或理由经核实不成立。证据缺口一律进 Verification Needed（每条一个最小可证伪检查；Author 代跑或以技术理由不采纳；`/final-review` 的 Manual Check Before Commit 逐条列给人类）；账本/措辞进 Non-Blocking Suggestions；「所称路径实际未运行」归 VN、「纯措辞过度」归 Suggestion、兼具者拆两条。verdict 三值重定义：`有条件通过` = 零 Product + 有 VN。Debt Verdict 加 `Unpaid`（替代原「移入 Blocking」）。
* **收敛门重写**（最后一轮独立审查门）：① 无未解决 Product（修复再审通过 / 不采纳且人类裁决不成立）；② VN 逐条处置；③ 内容 == tip，例外 (a) 纯新增独立测试用例文件（不含 conftest / fixtures / runner 配置）且用例总数不减、(b) 非验收文档、(c) 人类裁决的验收修订、(d) QUALITY_GATES 审后改动交人类复核。证据层出口整段删除。VN 本身与纯代跑不触发再审；处置产生门 ③ 例外之外的 review-sensitive delta 时按该门再审。
* **9P 默认单跑一轮**，撤回 2026-08-27「逐轮复审至收敛」；verdict + 表态 + 修订计划交人类知情批准；再审仅凭人类明示；缺摘要照常审；无轮次上限与四条出路。
* **七字段快照证据减为三**：`observed_head_sha` / `worktree_clean` / `read_handoff_from`（HEAD == 快照 commit 且工作树干净即保证工作树 HANDOFF 与快照一致，blob hash 冗余；保留 `read_handoff_from` 是为了 2026-07-28 那类过期读取）；base/tip sha 由 Author 逐字写进 prompt；覆盖缺口报告不拒审、`/final-review` 复核；不可枚举目录不构成污染。
* **IMPLEMENTATION_PLAN 与 QUALITY_GATES 退出 review-sensitive 必含清单**；Frozen Acceptance 迁入 `TASK_BRIEF.md` → Acceptance Criteria（**有意让步**：9B 由此读到冻结验收的必经路径与等价类）。「扩大清单须重跑」删除；缩窄改由 `/final-review` 用 `git show <handoff_snapshot_sha>:docs/ai/HANDOFF.md` 比对。
* 守护产物字段 ⑦ 改按内容比对绑定 `tested_sha`（只比字段 ①② 文件）；反例产物义务限守护类与人类判定 AC；「声称超出覆盖」「暗债措辞扫描」「覆盖不足」降为非阻塞；Runtime Identity 节删除；blast-radius 协议限 Product / 改代码修复。
* 调用模板加 `--disable memories`；`codex/AGENTS.md` 镜像全部改动，另加 3 行「非审查会话」比例原则（起因 2026-08-14 拒写、2026-08-23 一次 `winget upgrade` 变成 143 次调用 / ≥4 次 UAC / 改注册表与代理 / 杀 VPN / 遗留 3.3 GB）。
* 复述点全仓同步：`claude/CLAUDE.md`（便携版指针）、`README.md`、`claude/rules/common/development-workflow.md`、`claude/commands/{plan,implement,final-review,debug}.md`、三份 templates。便携版按母本整体重生 v3.4 → v3.5（`git mv` 保留历史，1228 行），桌面副本哈希一致。

**保留不动**：9A/9B 双审 `high`（样本里的真 bug 出自 9P 与 9A/9B 前两轮或 Product 修复轮）、零写入、仓外 holding、9B 先跑、污染扫描、SHA 内容比对失效判定、streak 仅 Product 与硬停、3 轮上限逐次延长、diff 预算、No-Hidden-Debt 格式、守护协议与负向对照区分力。

**推翻的既有裁决**：2026-08-27 9P 逐轮收敛；2026-08-15 / 08-30 `[Verification Blocking]` 作合并门 + 成立门槛；2026-08-15 证据层出口。

## 验证轨迹

* **方案对抗验证（Claude 侧三视角：事故重放 / 全仓矛盾扫描 / Codex 措辞漏洞）**：两条 fatal（「可能造成」「证据表明未满足」可被改标 Product）封住；删测试理由核实、VN 有界、人类裁决非自述、conftest 排除、`read_handoff_from` 保留（七→三而非二）、Frozen Acceptance 迁移的四处漏改等并入。
* **一轮 Routine 临时独立审查（Codex，high 档，模板 flag + `--disable memories`；按新契约约定只跑一轮）**：判「不通过」，3 Blocking + 5 Suggestion，回文件核实**全部成立、全部采纳**——B1「VN 不再审」被写窄成「只有改生产代码」、与门 ③ 冲突，且「可不采纳」与「必须代跑」并存 → 统一；B2「声称宽于证据」同时列在 VN 与 Suggestion → 按原子事实拆分；B3 完成标准 #11 旧句「已显式申请降级」与 `Unpaid` 冲突 → 改「已获人类明确批准延期」。S1 「三项例外」改指门 ③ 全部分支；S2 PLAN 模板补 Amendment 例外；S3 「`review_sensitive_paths` 变化」改「review-sensitive 内容变化」；S4 review-fix 节按模式起句；S5 development-workflow 的 CRITICAL/HIGH 限定为自审严重度。四项专攻结论：SeedLink 09-02 r4 三条旧 Verification 发现在新契约下 = 2 条 VN + 1 条 Suggestion、verdict「有条件通过」、不再审；九起历史事故 + 两个恶意 Author 场景全部仍被拦住；母本↔便携版阈值与三条证据载体句逐字一致；新 prompt 与 `codex/AGENTS.md` 无可被读成「以证据不足继续阻塞或拒审」的句子。单轮约 9 分钟、25.5 万 token。verdict 与 raw log 曾存仓外 `~/.codex-review-holding/verification-class-removal/`，**已按人类指示清理删除**。
* **机械检查**：12 个旧措辞（`Verification Blocking` / 证据层出口 / 逐轮复审至收敛 / Awaiting Human Adjudication / `review_sensitive_paths_snapshot` / `handoff_blob_sha` / Runtime Identity / 七行 / 成立门槛 / 三项例外 / 已显式申请降级 / 「只有改生产代码才再审」）在便携版全为 0、在母本只剩带日期的删除来历注；三条证据载体句母本 1+2 / 1+1 / 1、便携版 3 / 2 / 1 逐字一致；阈值 4000 / streak 2 / 3 轮 / 9A9B high / 9P medium 两边一致；全部改动文件无 CRLF、无 BOM。

## 顺带实测（登记备查）

* 母本模板 flag（`--ephemeral --ignore-user-config --ignore-rules`）下 Codex 自动记忆**不会**注入（SeedLink 目录内基线 / `--disable memories` 各两次探针均 NO、token 数一致）。
* SeedLink 09-02 round-4 那组审查未按模板启动：rollout 落盘、沙箱 read-only、注入 27 KB「## Memory」开发者消息并 rg 了 `MEMORY.md`（其中写着"a repair succeeds only when … complete category/value-range coverage"）；归档里记的 `xhigh` 与实跑 `high` 不符。**下游 Author 的调用在漂移，账本记的命令不是实跑的命令**——核下游时先看 rollout。
* `codex features list`：`memories` 为 stable、默认开启；`--disable <feature>` 有效。

## 未验证与观察量

尚无新契约下的真实 Critical 任务。观察量（与本档诊断数据比）：每任务 Codex 运行次数（基线 11–27）、双审轮次（基线 4–10）、`last_test_run.txt` 行数、Product 发现是否仍集中于首轮。任一项无明显改善 → 重开裁决，不加新规则。2026-08-27 遗留重放场景中「9P round 2 缺摘要拒审」「round 3 达限四分支裁决」已随本次作废；其余场景仍待真实 Critical 任务实测。

## 部署

**已执行（2026-09-03，人类 push `9c37efe` 之后）**：字节级审计 99 个受管文件，恰 12 个为正向差异（本机 == HEAD~1 版本）、零反向漂移、`settings.json` 一致；备份 `*.bak-20260903-124339` 后逐文件复制、字节比对全部 OK；复审计 99/99 零漂移；本机独有 82 个 `workflow/archive/**` 与 26 个历史 `.bak-*` 未动。桌面便携副本 v3.5 哈希一致，v3.4 副本已按人类指示删除。受管面变更 = `claude/CLAUDE.md`、`claude/commands/{debug,final-review,implement,plan}.md`、`claude/rules/common/development-workflow.md`、`claude/workflow/{AGENTS,reviewer-prompt}.md`、`claude/workflow/templates/{HANDOFF,IMPLEMENTATION_PLAN,TASK_BRIEF}.md`（11 文件 → `~/.claude/`）+ `codex/AGENTS.md`（→ `~/.codex/AGENTS.md`）。照惯例精确同步（备份 `*.bak-<时间戳>` → 逐文件字节比对 → 全受管面审计零漂移），非 mirror-replace。桌面便携副本 v3.5 已同步；桌面 v3.4 副本已删。

## Remaining Risks / Debt

* `codex/AGENTS.md` 顶部「Scope: sessions without a review prompt」3 行与本次主改动同一 commit 入库（人类审 diff 时未要求拆分）。
* Debt: none。
