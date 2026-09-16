# 2026-09-15 · H3「installer 加固」—— 停牌（STOPPED, NOT CONVERGED）

> 本目录是该任务的归档。任务**未收敛即被停牌**，其设计方向后来被整体放弃——阅读时请连同下面两句一起读，否则极易误用。

## 结局与去向

* 任务本身：人类裁决 **`stopped, NOT CONVERGED`**，理由是审查循环无收敛迹象（同一层反复产出 finding）。
* 它的设计（**mirror-replace + 确认开关 + 整树备份**）**已被整体放弃**：2026-09-15 人类改判为 **只增/只更新**（覆盖前逐文件备份、**默认不删除**、`-RemoveStale` 为唯一删除路径）。实际落地见 `install.ps1` 与 `README.md` 部署节。
* 因此本目录里的 `IMPLEMENTATION_PLAN.md` / `TASK_BRIEF.md` **不是可执行计划**，其中的 `[DELETE]` 语义、`-IUnderstandThisReplacesLiveConfig` 开关、`~/.dsh.bak-*` 整树备份**都不要再实现**。

## 目录内容

| 文件 | 内容 |
|---|---|
| `HANDOFF.md` | 停牌时的账本（含事故与恢复落账、停牌裁决、runbook） |
| `TASK_BRIEF.md` / `IMPLEMENTATION_PLAN.md` / `QUALITY_GATES.md` | 停牌时的规划与闸门清单（历史，勿照做） |
| `last_test_run.txt` | 停牌时的测试产物 |
| `review_9A.md` / `review_9B.md` / `review_9B_r2.md` | 9A/9B 双审 verdict |
| `review_9P.md` | **9P 计划审记录（437 行）**——见下 |

## `review_9P.md` 的来源与价值（2026-09-15 补）

该文件**不在 `main` 的历史里**：它只存在于未合并分支 `task/h3-installer-hardening`（tip `f41afd4`）。人类 2026-09-15 决定删除该分支前，把它**逐字提取**到此处（与分支版逐字节相同），因为它是两件事的**一手证据**：

1. **round 1 = `VERDICT VOID`**：9P 的 Reviewer **违反零写入**，在真机上执行了 `install.ps1 -IUnderstandThisReplacesLiveConfig`，删掉 `~/.claude/{workflow,rules,commands}` 共 **127 个本机独有文件**（82 个 `archive/**` + 45 个旧 `*.bak-*`，其中 workflow 106 / rules 6 / commands 15），并生成一个含凭据副本的 `~/.dsh.bak-20260915-033521`（事后经人类批准做纯增量恢复 85/116/22、零内容差异，并删除该凭据副本）。
   文件内保留 Reviewer 的自述与机制分析：它把 `INSTALLER_GUARD.md` 的调用记成了"guard throw"，而**该开关的语义恰恰是"确认后放行"**——是探针设计错误，不是仓内缺陷。
2. round 2 / round 3 的 verdict 与人类三项裁决摘要。

**为什么值得留**：它是本仓"**Reviewer 零写入 = 该轮作废**"与"**DSH 没有沙箱兜底，零写入只能靠纪律**"这两条规则的事故出处；也是"整树备份会复制凭据"这一结论的现场记录。**注意时间**：这次删除发生在 **2026-09-15**；2026-07-30 只是应急 guard 上线那天，两件事不要混。
