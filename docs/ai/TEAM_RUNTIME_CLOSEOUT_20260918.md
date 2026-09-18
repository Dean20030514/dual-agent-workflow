# Team 首轮真实使用后的运行器收尾（2026-09-18）

状态：已完成独立审查、375 项全量回归、本地 main 合入、全局部署、七项目接入检查及小型真实 DSH 任务全流程验收。代码候选为 6927aa59363d42172ceb8b80dae0f0af57520f81；初次收尾记录及部署提交为 4f1a75b86d565e716c05a6e3ebb8ec3f97ca70d1。此后仅追加验收记录，运行器源码未变。

本轮按用户授权由 Lead 集中修复，采用 Routine L0 + Codex 独立只读审查。此前追加一次的 DSH Worker/LOCAL 运行因审查失败终止，保留 CANCELLED、封顶计数和全部失败记录；本次不将它改写为通过。

## 修复范围

- 活动检测同时用于适配器与协调器，观察有界源码内容和 HEAD 变化；区分 idle/hard/output，时间戳变化不冒充工作。idle 真实失败可显式恢复，hard/output 保持人工决策边界。
- 前置检查在 run/resume 的审批和 9P 后执行；显式 restore 在启动前使旧 PASSED 失效并保留历史，失败路径也不能复用已撤销环境。
- 验证复用需显式启用并绑定提交、工作树、命令与环境证据；失败的缓存查询回到正常执行，缺失命令仍记录失败证据。
- 审查材料包含问题到验收的对应及机器事实；汇报区分语义重规划、基础设施恢复、验证执行/复用和已知/未知费用，不把零已知费用解释为免费。
- finalize 先做可恢复归档与真实恢复证明，再比较当前内容/引用后清理；含集成分支、脏/旧候选及已注销残留。拒绝根及祖先链接，中断归档和 preserved 可保留原证据后重试；部分完成如实标记 partial。

## 已完成专项证据

- 前三项反例修复：3 项失败转 3 项通过。
- 独立审查发现的异常路径：6 项失败转 9 项通过。
- RealRun.Tests.ps1：56 passed、0 failed，退出 0。
- native-guard：6 passed，退出 0。
- 派生漂移：17 对、292 行登记差异一致，退出 0。

## 历史遗留及适用边界

森驰汇本轮 9 个分支/worktree 已归档并从项目注册位置清理，main 1e4430a 与具名 stash 保持不变；完整 bundle、114826 个普通文件记录和链接描述以及两处脏现场恢复证明保留在本机，不随公共配置部署。

两次旧 Worker 中断分别发生在 900.26 秒、1800.18 秒，与旧空闲上限吻合；旧检测只观察外层日志，不能判断内部编辑和测试是否仍在进行。第一次中断后只增大超时、未及时收紧任务范围，也是 Lead 的调度问题。新观测不保证任意长时间纯思考或静默只读计算永不超时。

本轮不会修复森驰汇历史导出测试偶发失败、补做 poker-clock 独立产品审查或证明 Team 省钱提速。费用 unknown_usage 仍须保留；下一轮仍从小型 L1 开始，边界独立才使用 L2。

## 最终回归

已完成全量回归：pwsh -NoProfile -File run-closeout-full.ps1，Pester Run.Path 为 team/tests 与 tests，15 个文件，TestResult.Enabled=false。6 项 native guard 与派生漂移检查另行通过。部署、七项目接入、小型原生任务和自身遗留归档结果见下。

全量原始日志（本机）：C:/Users/16097/.codex/tmp/team-first-run-remediation-20260918/closeout-full-regression.log；SHA256：948822e3f34382f86115dc8349fea36866b0ae8344481f346861bbb0a2fd8871。独立审查摘录：C:/Users/16097/.codex/tmp/team-first-run-remediation-20260918/closeout-review-record.md。

## 全局部署与七项目

从 canonical main 执行 `pwsh -NoProfile -File install.ps1 -NoPluginInstall`，退出 0：written=23、unchanged=184、backups=18。未使用 RemoveStale；未操作远程 Git、生产数据库或业务应用。部署后 DryRun 为 would-write=0、unchanged=207，source locator 仍指向桌面 workflow。

SeedLink、xlsx-organizer、森驰汇、workflow、翻译/game-translator、xiafangle_bot、游戏/疯狂夜市王的 installed check-workflow 均返回 READY，global/project 均 COMPLETE。六个业务项目的接入文件哈希未变；workflow launcher 随授权实现合入更新。既有未提交业务改动保留。READY 验证部署完整性，不代表七个业务项目的所有任务已经真实执行或验收。

## 小型真实任务：csv-closeout-20260918

- 使用已部署 `~/.codex/team/scripts/team.ps1`；doctor 确认活动 Lead 为 gpt-6-astra，DSH 0.1.5-rc.1 / deepseek-official / deepseek-flash。Worker 从零实现一个 UTF-8 CSV 分类汇总脚本，未导入 Lead 实现；只提交 sum-categories.ps1 一个文件。
- 运行从 2026-09-18T14:15:19Z 到 14:22:56Z 完成，约 7 分 37 秒（含作者、独立审查、Lead 检查等待和集成）。仅 1 次作者尝试、1 个 fresh-process DSH LOCAL Reviewer，累计 2 Agent、reserved=0，无子代理、重试或重规划。
- 作者提交 e6550e4aee109bc946e38902da9ea0b99e93f85e；独立 LOCAL pass，blocking=[]、verification_needed=[]、writes_performed=false。独立审查与作者同为 DeepSeek，不能称为不同模型交叉审查。
- 协调器外部、集成及最终验证均真实执行并退出 0，未复用结果。覆盖中文分类、重复分组、负数金额、计数、空 CSV、大小写区分、非法金额的非零退出码/错误输出/无成功输出。
- 集成提交 98db53197653e4e8d046e6e57fcb77d1d0e2fbdb，run=COMPLETED；随后在隔离验收仓本地 main 快进合入。finalize 完成真实归档/恢复证明后清理 2 个 worktree 和 2 个分支，failed=0、pending=0，最终只剩干净 main。
- 原生作者的编辑被适配器与协调器双方的活动收据观察到。本任务未制造 timeout/recover；该异常链由专项反例和全量回归覆盖，不能称本任务真实演练了所有故障路径。
- 本机可运行交付：`C:/Users/16097/.codex/tmp/team-first-run-remediation-20260918/native-csv-closeout/repo/sum-categories.ps1`。完整输入、验证脚本、原生身份、审查、接受、集成、费用和归档证据均在该 repo 的 team/runtime/csv-closeout-20260918；外围收据在 native-csv-closeout/。

## 遗留现场收尾与下一轮边界

新运行器实际完成 workflow 两个 CANCELLED 旧运行的 5 个 worktree/分支归档清理，包含两处脏现场；5 份 receipt 均 restore_proof.verified=true、worktree_removed=true、ref_deleted=true。历史 run 状态、失败、封顶及原始输入不改写为成功。源码与恢复 bundle 留在各 run 的 finalize/ 下。

本轮支持继续做边界清楚的小型 L1；小改动 L0，强耦合先单 Worker，确实独立才考虑 L2。暂不据此扩大并行或宣称省时省钱：本轮原生费用仍 unknown_usage=true，known_cost=0 不是免费；环境前置命令仍须计划声明，任务拆分和生成文件预算仍需 Lead 判断。森驰汇既有偶发测试根因、poker-clock 产品审查与真实业务环境验收不在本次已解决范围。
