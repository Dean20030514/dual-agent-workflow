# HANDOFF — 9P 逐轮收敛 + diff 预算上调(2026-08-27,已收敛并合入 main)

> 本档是该任务的完整交接记录,自 `docs/ai/HANDOFF.md` 文首归档而来。Routine 模式执行(纯规则文档);全部改动含三轮审查修复已 squash 为**单一 commit**(本档随该 commit 入库)。

## 两处人类裁决

① **9P 计划审由「默认一轮」改为与 9A/9B 同律逐轮复审至收敛**——收敛判据 = 某轮 Plan Verdict「可批准」(与输出契约硬规则双向绑定:Blocking None ⇔ 可批准,Suggestion/Assumption Challenges 不影响);每轮仍单跑;每轮 prompt 必填 `9P round: <n>`,round > 1 必须附紧邻上一轮 blocking 与 Author 全部表态摘要、缺失则 Reviewer 拒审(fail-closed);verdict 锚定四行(首行 9P_round);轮次上限 3,达限停审进入 **Awaiting Human Adjudication**,交人类在「知情批准带未采纳项 / 批准延长复审(逐次批准一轮,延长轮跑完回到裁决点) / 重拆任务 / 回退」四条互斥出路中裁决——仅「知情批准」进入批准门;9P 轮次不进 Fix-Loop streak、不计入 9A/9B 双审轮次上限。唯一定义处 = `claude/workflow/reviewer-prompt.md` → 9P 节。

② **★ 单轮任务 diff 预算 2000 → 4000 行**(per-task 交接产物常占六七百行,2000 过度挤压生产面)。唯一定义处 = `claude/workflow/AGENTS.md`,定义处留有来历句;2026-08-15 状态记录与历史档案中的 2000 为点时史实,刻意保留;auto-memory `critical-mode-diagnosis-2026-08-15` 已加更正注记。

## 三轮 Routine 独立审查(blocking 3→1→0)

* **r1 不通过(3B)**,全部核实成立并采纳:①收敛判据与 Plan Verdict 三值不双向绑定(Blocking None 却可判「修订后可批准」→ 循环空转)→改硬规则双向绑定;②re-review 上下文「若附有」非 fail-closed、prompt 无轮次字段→必填 `9P round`、round>1 缺摘要拒审、锚定改四行;③达限三条出路被 `/plan` 合流进「等人类批准」→拆两态互斥(收敛→Awaiting Approval / 达限→Awaiting Human Adjudication)。
* **r2 不通过(1B)**:「三条互斥出路」与「可逐次批准延长」并存 = 隐性第四出路→**修改后采纳**——延长未删(9A/9B 轮次上限本就保留逐次延长,删则 9P 严于「同律」裁决),改为显式第四条互斥出路;母本/plan/portable 三处同步。
* **r3 通过**:全项 None,判「与 9A/9B 的逐次批准延长同律,未发现新矛盾」。
* r1 的 Cannot Verify(部署/桌面同步声称)由对话内真实 cmp/audit 输出(退出码 0、99/99)在 r2 闭合;r1 的 Verification Needed(仓外 fixture 多轮行为重放)按**修改后采纳**并入人类既有知情延后登记并扩充场景清单,r2/r3 确认该延后。
* 三轮 verdict + raw log 曾存仓外 `~/.codex-review-holding/9p-amendments/`,**已按人类指示清理删除**。

## 同步与部署

复述点全仓 grep 同步(含 codex/AGENTS.md 与 portable);portable v3.2 受影响节整节重取(§9.2 循环语义/四行锚定/prompt 轮次段、第七节步骤 11 与输出两态、4.1 diff 预算与 AI 协作/Fix-Loop 句、序节矩阵两格与核心原则第 6 行);桌面副本字节级一致;受管面精确同步部署,终审计 **99/99 零漂移**(备份 stamp 20260827-151030 / -152232 / -152730)。

## Remaining Risks / Debt

* 行为级重放证据缺口沿用上一任务的人类知情延后登记(场景清单见 live HANDOFF 唯一遗留行,本轮扩充了 9P 多轮三场景)。
* Debt: none。
