# 2026-09-15 · H3-C「installer 只增/只更新收口」—— 已完成（Routine 档）

> 本目录是本轮任务的 per-task 记录。任务**已完成并落地 `main`**，此处保留过程与证据。

## 这一轮做了什么

`install.ps1` 从"零写入校验器"恢复为**真实部署器**，语义定为 **只增/只更新**：

* 无参数运行 = 打印完整计划 → 前置校验 → 逐文件更新受管目标（**覆盖前把旧内容备份成同级 `<name>.bak-<时间戳>-<4位guid>`**）→ 装 6 个官方插件；内容已一致的文件完全不碰（同版本重跑是 no-op）。
* **默认不删除任何东西**：本机独有内容只以 `[STALE]` 报告；`-RemoveStale` 是唯一删除路径，目录仅在已空时删，**全文件无递归删除**。
* `-DryRun` 加逐文件 `[DIFF]` 预览（`would-write=N`）与 `[WARN]` 形状警告；`-ValidateOnly` 不变。
* 插件步落地：逐插件播报、**每插件 180s 超时 kill**（`INSTALL_PS1_PLUGIN_TIMEOUT_SEC` 可覆盖）、CLI 缺席打印手工命令、失败计入 `failed=N` 并以 `RESULT=FAILED` 退出。
* 顺带闭合：空显式根 FAIL（绝不回落真机）、大小写不敏感路径成员判定、`dsh/skills` 按目录枚举（新增 bundle 自动纳入）、`planned` 契约行级核对、seed 缺失分支。

## 为什么方向变了（重要背景）

同一轮的前半段曾按 **mirror-replace（含删除）** 走 Critical 全套（AC1–AC9、三轮 9P、冻结批准门），跑了 3 轮计划审仍未进实现。**人类 2026-09-15 裁决放弃该方向**，理由：删除是这条线上全部风险与全部仪式成本的来源，而它买到的只是"清理残留"。被放弃方案的规划产物与 9P verdict 归档在 `../2026-09-15-h3b-mirror-replace-superseded/`。

**若将来仍需要删除能力，属新任务，须重新立项**——不要在后续改动里顺手加回。

## 目录内容

| 文件 | 内容 |
|---|---|
| `HANDOFF.md` | 本轮的完整账本快照（Current Phase / Work Log / Known Issues / 债账 / Quality Gates / Next Step 全骨架） |
| `BACKLOG_sliceB.md` | 切片 A 移交的残余清单 + §6/§7 的逐条最终状态（B/R/T/D/H 全部条目的归宿） |
| `REAL_DEPLOY_LOG.txt` | 真实树的运行记录：`-DryRun` 与真部署的逐字 summary 行、退出码、计数，以及插件状态与历史备份堆积的说明 |

## 关键证据（真实执行）

* 套件 **75 条全绿**（`Tests Passed: 75, Failed: 0`，exit 0；含新增 20 条部署契约用例）。
* 真机首次运行：`RESULT=OK`，`written=0 unchanged=123 backups=0`——本机本就与仓库逐字节一致，故零覆盖、零备份。
* 插件步在 pwsh 7 与 Windows PowerShell 5.1 两宿主下各跑 6 次调用、exit 0；超时路径实测会 kill 并报 `TIMEOUT`。
* 区分力证据：新用例对旧实现（`git show HEAD` 的 `install.ps1`）实测为红（第三个 skill bundle 不进计划、插件步 0 次调用）。

## 债的处置

偿还：`INSTALLER_GUARD` 的 guard 债（真实控制全部落地）· A3/skills 常量自指债 · 切片 A 死代码六处 · `~/.dsh` 人工同步债（部署器接管且已跑通）。
仍开：见 `../../HANDOFF.md` → Remaining Risks / Debt（唯一活台账）。
