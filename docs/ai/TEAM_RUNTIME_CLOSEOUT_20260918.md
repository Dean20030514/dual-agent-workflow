# Team 首轮真实使用后的运行器收尾（2026-09-18）

状态：代码候选 6927aa59363d42172ceb8b80dae0f0af57520f81 独立审查无阻断；全量回归 375 passed、0 failed、0 skipped，2992.68 秒，退出 0。按用户授权提交记录后合入本地 main 并部署；部署与原生验收另行追加实测结果。

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

## 待填写的最终验收

已完成全量回归：pwsh -NoProfile -File run-closeout-full.ps1，Pester Run.Path 为 team/tests 与 tests，15 个文件，TestResult.Enabled=false。6 项 native guard 与派生漂移检查另行通过。后续部署、七项目接入、小型原生任务和自身遗留归档待实际执行。

全量原始日志（本机）：C:/Users/16097/.codex/tmp/team-first-run-remediation-20260918/closeout-full-regression.log；SHA256：948822e3f34382f86115dc8349fea36866b0ae8344481f346861bbb0a2fd8871。独立审查摘录：C:/Users/16097/.codex/tmp/team-first-run-remediation-20260918/closeout-review-record.md。
