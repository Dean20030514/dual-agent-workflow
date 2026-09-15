# 9B verdict（第 2 轮）— dsh-landing review

> **来源与保真度声明**：Reviewer 把 verdict 作为 **agent 返回正文**交回；本文件由 **Author 在双审窗口结束后转录**，非 Reviewer 手写原始 artifact。契约字段、闭合结论、Suggestion、VN、Debt、Requirement-Level Concerns 为逐条转录；叙述性前言略去。
> 审查对象：`review_base_sha = a361bc19` → `review_tip_sha = 7084fb75`

## 证据首行（隔离五项核验通过）

```
observed_head_sha: 7084fb7515ef36e8191f20a141bf2118cd20ff4e
worktree_clean: yes
read_handoff_from: 工作树
model_route: deepseek-official/deepseek-flash@high
writes_performed: none
覆盖缺口: dsh/skills/**（phases 与两个 SKILL.md）、portable/通用prompt-DSH-v1.txt、docs/ai/HANDOFF.md、归档 HANDOFF —— 未全部落在审前 HANDOFF 的 review_sensitive_paths 内
```
（Author 注：该缺口源于审前 HANDOFF 的清单未含 `dsh/skills/**`，本轮已把 `docs/ai/TASK_BRIEF.md` 补入清单；`dsh/skills/**` 属于 `dsh/**` 通配，按声明已覆盖。）

## Review Verdict

**有条件通过**（Blocking = None；Verification Needed 非空）

## 上轮 B1–B3 闭合核验（一手重做，不采信 Author 自述）

* **B1（9P=`medium` 必被拒）→ 已闭合（代码面）**。11 处全改为 `high` 或解释性引用；`dsh/**+portable-DSH+README` 的 `medium` 只剩"该档不存在"的解释句；适配器 `reasoningEffort()` 只放行 `off/low/high/max`（该文件 `"medium"` 零命中）。**残留缺陷只有取证缺失** → VN1/VN2（属证据缺口，不立 Product Blocking）。
* **B2（`-o` 指令性 + 备用路径钉不住路由）→ 已闭合**。`dsh/workflow/AGENTS.md:148` 改为 stdout/stderr 重定向；全仓 grep `-o ` 零命中；两处如实写明 headless 钉不住 provider/model/推理档。**但新增的"钉死办法"只对 provider/model 成立、对推理档不成立** → S1。
* **B3（QUALITY_GATES 指针漂移）→ 已闭合**。`reviewer-prompt.md` 3 处指向项目副本 `docs/ai/QUALITY_GATES.md`，与母本处数一致；母本路径降为兜底且须在 verdict 注明。
* **无新增 `caused_by_last_fix: yes` 的 Product Blocking → streak 不递增。**

## Blocking Issues

**None。**

## Non-Blocking Suggestions（6 条）

1. **S1（`caused_by_last_fix: yes`）**：`fanout-toolchain.md:50` / `dsh/workflow/AGENTS.md` 写"要钉死须先用 `--patch` 或 profile patch 固定 `agent-default-model`"——**对推理档不成立**：`@deepseek-ai/dsh-agent-default-model` 的 `AgentDefaultModelConfig.Config` 只有 `provider` + `model`，`reasoningEffort` 只存在于 `AGENT_DEFAULT_MODEL_SETTINGS_SCHEMA`（落 `settings.yaml`）。**Fix**：拆成两条表述（provider/model 可由 patch 固定；effort 只能写 `settings.yaml` 的 `agent-default-model` 节）。
2. **S2（no）**：工作树 `HANDOFF.md` 仍是第 1 轮内容（窗口冻结使然）。**Fix**：落账时一次性更新，并注明"本文件在工作树中恒滞后于 tip"。
3. **S3（no）**：`last_test_run.txt` 未随修补重跑，仍绑 `tested_sha = a361bc19`，其 A/C/E 节结论已不是当前 tip 的事实。**Fix**：回炉到本轮 tip 并重抄相关节。
4. **S4（no）**：README 快照节的 DSH 状态已过期（"未经审查"、债是**四**笔不是三笔）。**Fix**：改为"已跑一轮 → 第 2 轮修补后待重审"，债指针改四笔。
5. **S5（yes）**：`dual-agent-workflow/SKILL.md` 仍写"收回后必须核的 **5** 项"，清单实为 6 行（含新增 4b）。**Fix**：改"6 项"或把 4b 并入第 4 项。
6. **S6（no）**：`DSH-LANDING-NOTES` §2 第 10 条的文件列未含 `define.md`/`explore.md`/`design-check.md`（它们只改了末尾换行）。**Fix**：补进文件列。

## Test Coverage Gaps

* 本轮修补**零实跑证据**（tip 上无任何绑定产物）；主路径从未产生过真实 verdict 的**错误报文**实测；备用路径只做过可用性冒烟；`install.ps1` 运行行为零覆盖；AC4 负向对照未实跑化。

## Cannot Verify From Diff

* AC1"判据逐条一致"只能抽样（无法在不重建副本下全量比对 2600+ 行）。
* AC2 的 skill 文件系统级发现需 fresh DSH 会话（本会话目录可见两项，属半程证据）。
* `~/.dsh` 部署副本同步状态属机器态，不进 verdict 结论。
* 人类四条裁决的发生过程不核实（按规则按人类决定对待），只核"是否照办"：已照办。

## Verification Needed（5 条）

1. **VN1**（TASK_BRIEF Testing Plan 明文必做项，未做）：发一次 `reasoning_effort: "high"` 的 9P 调用，把参数 + 是否被拒 + `model_route` 抄进 `last_test_run.txt`。
2. **VN2**：`last_test_run.txt` 的 `tested_sha` 改绑本轮 tip，并补 ① 适配器 `"medium"` 零命中（退出码）② 全仓 `medium` 用例面归零扫描 ③ 本轮 `dsh/**` 与 `~/.dsh` SHA256 比对。
3. **VN3**：`Get-Content <dsh-agent-default-model>/lib/index.js | Select-String 'Config = z.object' -Context 0,4`（预期只见 provider/model），据此改文档。
4. **VN4**：AC4 负向对照实跑（临时改 `medium` → 判定必须红 → 还原并确认工作树干净）。
5. **VN5**：一轮完整 headless 审查（stdout 拿 verdict、stderr 有 raw log、holding 在仓外、工作树为空）。

## Debt Verdict

**Unpaid**（第 2 轮新增的第 4 笔债未偿还、无批准延期；第 1 笔债的 Payback 本轮再次触发仍未收口。按定义不进 Blocking、不触发再审，但 `/final-review` 据此不得判"可以提交"。）

## Requirement-Level Concerns（4 条）

1. **TASK_BRIEF 的"Frozen Acceptance"标注不成立**（自记 `Status: N/A`），且 **AC7/AC10/AC8 的判定方式不合格**（散文对读 / 无区分力 / 本轮未跑）；建议改写或由人类补一行"接受抽样核验"。
2. **"补 TASK_BRIEF"与"先跑审查"的时序没有闭合**：HANDOFF 仍写 `TASK_BRIEF.md：不存在`、`plan_review_9P: N/A`，与工作树冲突——合并前必须改到一致。
3. **"9P 低一档"的设计意图被取消后没有替代的成本观察量**（母本那组数据量自 Codex 的 `gpt-6-astra`）；建议在改点清单里登记为"经人类裁决的落地差异"。
4. **`model_route` 字段闭环成立且未被过度声称**（三份 prompt + 手册 + portable 都要求，明写"自报值、不是证据"）——唯一未闭合处即 S1/VN3。
