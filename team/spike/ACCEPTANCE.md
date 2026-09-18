# 验收记录（2026-09-17）

| 验证 | 实际结果 |
|---|---|
| Pester，`Run.Path=@('tests','team/tests')`，关闭 XML 输出 | 114 passed / 0 failed，exit 0；包含既有安装器隔离测试 |
| 后续 Team 回归，`Run.Path='team/tests'` | 39 passed / 0 failed，exit 0；包含新补路由降级与失败集成回滚 |
| 最后子范围修正后，`Run.Path='team/tests/Contracts.Tests.ps1'` | 29 passed / 0 failed，exit 0；与上行有重叠，不相加 |
| `node --test team/tests/native-guard.test.mjs` | 4 passed / 0 failed，exit 0 |
| `GuardEffectiveness.ps1` 正常 → 内存变异 → 正常 | exit 0 → 1 → 0；红因确为 out-of-scope committed file was accepted |
| `tools/dsh-drift-check.ps1` | 17 对、292 条登记差异完全一致，DRIFT none，exit 0 |
| `git diff --check` | exit 0 |
| 本机 doctor | DSH/Codex pin 与路由通过，四项 routing fixture 全部 ROUTING_PASS，exit 0 |

上述 Pester 批次覆盖范围有重叠，不把重跑次数相加当作独立用例数。
所有 Git 集成、进程退出、Worker 错误和回滚测试均在临时仓库；未运行真实配置部署器。
测试替身只用于 CLI 接线/故障注入，不作为模型能力证据。

真实 Harness 验收：

- `SQL-SMOKE-001`：DSH L1 → Result → Git scope → 外部验证 → Lead accept → integration → final，COMPLETED。
- `CRITICAL-SMOKE-002`：真实独立 Codex 9P/9A/9B；9P/9A 的 VN 逐项留有技术处置/实跑证据；9B 无 Blocking/VN；COMPLETED。
- `NATIVE-SMOKE-003`：DSH Worker + 一个 native fresh 子 Agent，实际创建记录与 Result 对齐，严格 SQL 内容检查及集成回归通过；COMPLETED。
- 三条链路都在独立临时仓库，main 未修改；具体 base/Worker/integration SHA 见 VERIFIED_VERSIONS.md。

首批代码已提交为 `a9a8a4a`，第二批预算/审批修正已提交为 `9181dd3`；均未部署到用户项目。
以上是本地实现与隔离 fixture 的验收，不等于任意项目的业务验收。
运行边界（权限声明、未知金额、版本与 fork 的验证级别）见 OPEN_GAPS.md。
# 第二批：执行中的预算与计划审批

2026-09-17：`team/tests` 实际运行 **45 passed / 0 failed**，exit 0；
`node --test team/tests/native-guard.test.mjs` **5 passed / 0 failed**，exit 0。
新增证明：运行中的 coordinator 可接收 soft/hard 费用凭证；原 Worker 完成，
optional 后继未启动；重复账单被拒绝、resume 不重复计费；已运行 native 家族
在软限制后不能创建新 child。费用未知部分仍保持 unknown_usage，不伪装完整计量。
权限测试证明：修改计划权限不会继承旧审批，modify-plan 不等于 approve，
过期升级保持 PAUSED，replan 引入 production_delete 在派发前硬停。
上述为真实 PowerShell 进程/Git 加替身模型 CLI；不是新的真实模型行为验收。

# 第三批：崩溃恢复与仓库锁

`team/tests` 完整回归 **50 passed / 0 failed**，exit 0；native guard **5 passed**，exit 0。
实际终止 coordinator（保留替身 Worker 进程）后，第一次 resume 因原进程仍存活返回 80；
Worker 完成后第二次 resume 到 REVIEW，attempts=1、agents_created=1，无重复派发。
故障注入发现并修复 JSON 时间戳被 PowerShell 读成 DateTime 后的 PID 身份比较错误，
现比较 UTC ticks；单独验证错误启动时间不能匹配同一存活 PID。
事件截断、任务状态字段缺失、集成 HEAD 偏移均被拒绝恢复；linked worktree 另建 run 返回 20。
事件读取异常时显式释放 reader，错误出口保留 80，不再被文件句柄冲突覆盖。
旧真实 `CRITICAL-SMOKE-002` 状态被新 schema 正常读取，仍为 COMPLETED（只读兼容检查，未重跑模型）。
派生漂移检查仍为 17 对/292 行、exit 0；全部集成和故障注入均局限于临时仓库。

# 第四批：真实并行 Worker 与 fork 入口

`L2-NATIVE-004`：真实双 DSH Worker 并行启动，分别提交独立 SQL 文件；Git scope、外部验证、
逐 merge targeted 回归、双命令 final 回归均 exit 0；COMPLETED，main 不变、调用者工作树干净。
`FORK-NATIVE-005`：真实 native `subagent_fork` 唯一调用的工具事件已核对，parent/child 创建记录
与 Result 相符；父 Worker 的 SQL 提交、外部验证和集成回归 exit 0，COMPLETED。
fork 子会话 isSeeded=false（首次回合没有已完成前缀），不宣称非空上下文继承已验收。
两个新 run 的 SHA、实际 session 和日志哈希见 VERIFIED_VERSIONS；真实 run 不替代业务数据库测试。

# 第五批：领域角色与真实冲突修复

最终 `team/tests` 完整回归 **55 passed / 0 failed**，exit 0；native guard **5 passed**，exit 0。
19 个角色均包含领域能力、默认范围、验证建议、升级条件和指导；run/Task Packet 保存冻结定义。
合同测试拒绝角色身份错配、集成角色扩权及没有冲突记录的集成 Worker；L2/L3 冲突用例均通过，L3 不再被修复计划降级。
早期回归曾暴露 Windows 原子替换被读取句柄短暂阻止，保留了该失败；现读取允许 delete sharing，写入对共享冲突有界重试，
永久拒绝仍失败并保留旧文档。进程关闭可重复调用，不再以二次清理错误覆盖原始退出码。

真实 `ROLES-NATIVE-006`：backend/frontend 各自提交一个兼容 JSON 字段，原生 Worker 收到新角色合同。
首次 stdout 说明前缀导致 adapter 拒绝（exit 10），原文回放证明问题后增加唯一末尾 JSON 提取，
显式 replan 保留失败 attempt，再次运行通过；多份 JSON、无效 JSON 和无效 schema 仍被拒绝。
真实 add/add 冲突返回 81；Lead Decision Log 保留双方字段，受限 Integration Worker 从已接受 checkpoint 启动，
修复后 Git 范围/源提交祖先/外部验证/最终双字段回归均通过，run=COMPLETED、main 未改变。
这证明的是角色协议与集成执行链路；JSON fixture 不是实际前后端应用的业务验收。

# 第六批：失败升级与禁用开关

Team 完整回归 **60 passed / 0 failed**，exit 0（299.86 秒）。随后将 native child 数量核对
移到 escalated 分支之前，新增隐藏子 Agent 反例；合同测试重新执行 **36 passed / 0 failed**，exit 0。
受影响的升级 CLI 场景再次执行 **3 passed / 0 failed**，exit 0；未将分次测试合称为一次 61 项完整回归。
跨 attempt 验证失败、Worker 升级→拒绝验收→决定→重规划、越界升级、无效计划事件、
错误 Result 不误报 plan_invalid、disabled 执行阻断/stop 可用均有隔离 CLI 用例。
重复失败计数按命令、参数、退出码和输出哈希；同 attempt 幂等、不同失败重置。
派生漂移门 17 对/292 行通过，exit 0；git diff --check 通过。

真实 `ESCALATE-NATIVE-007` 已返回升级结果：实际 DSH Worker 未改文件、未提交、self-check=false，
控制器保存 worker_request 和结果哈希，run/task=ESCALATED、exit 70，未运行外部验证。
验收断言完成后明确取消该临时测试 run，最终 CANCELLED；原始证据保留，main 未变。
具体 base、session、Result 哈希见 VERIFIED_VERSIONS。
重复验证失败升级是替身 Worker + 真实 Git/外部进程测试，未宣称做过真实模型重复失败试验。

# 第七批：Critical 审查轮次与逐问题归因

Team 完整回归 **73 passed / 0 failed**，exit 0（347.67 秒）。随后把旧 review_loops 的拒绝点
前移到 Reviewer 启动之前，审查测试重新执行 **9 passed / 0 failed**，exit 0。
CLI 场景验证了 9P 不占轮、9A/9B 同轮聚合、mixed yes/no 连续两轮硬停、
全部修复引入问题在 replan 前 early-stop、明确批准额外一轮、逐项争议裁决且仍禁止验收产品缺陷。
聚合测试补充同问题去重、归因不一致、无 yes 时重置、三轮上限、同快照失败 verdict 复用、
硬停优先且不能用轮次延长解除；每次原始 verdict 与人工裁决分别保留。
漂移门 17 对/292 行、git diff --check 均 exit 0。

真实 `REVIEW-NATIVE-008` 使用两次 fresh Codex 审查：已知负数计算缺陷被逐问题报告并返回 50，
显式 replan 修复后，201 个整数的实际外部检查通过，第二次审查 pass、无 blocking/VN。
Reviewer 输入包含相关前次问题和精确修复 diff；两个独立 verdict 历史保留，round 2/streak 0。
这是 Reviewer adapter 和结构化归因/上下文协议的真实验收，没有运行 DSH、9P 或 9B，
不将它标为新的完整 Critical 交付；详细 SHA 与证据边界见 VERIFIED_VERSIONS。

# 第八批：集成回归定位、连续回滚与原生修复

Team 完整回归 **78 passed / 0 failed**，exit 0（468.21 秒）；检查点按 attempt 保留及历史范围
收窄到 run base 后，对连续回滚、无关结果保留、依赖闭包重做和空变更再次执行 **4 passed / 0 failed**，exit 0。
最后将回归修复的 conflict_files/glue_scope 明确写入 Decision 与记录，该完整修复场景复测 **1 passed / 0 failed**，exit 0。
用例实际执行 Git merge/revert：可回滚更早任务或多次回滚，按下游/相交范围倒序处理，
无关后续任务的 commit/attempt 保持不变。已 cleanup 的源结果可参与受限修复，且不重新创建旧目录。
空变更不会撤销无关 commit，重复回滚、错误分支和未跟踪文件均被拒绝；原失败日志和各次 probe 独立保留。
新增 fixture 的空数组曾被 PowerShell 条件输出展开为 null，被 schema 正确拒绝；已修正 fixture，未放宽结果 schema。

真实 `REGRESSION-NATIVE-009`：最初两个 Worker 是故意制造失败的替身输入，之后回滚 T1，
保持 T2 已集成结果，生成受限回归修复任务，再由真实 DSH Integration Worker 恢复 T1 的既有合同。
实际 diff 只含目标文件，原验证与 final 验证 exit 0，Lead 绑定真实 commit 验收后集成完成。
run=COMPLETED、failure=resolved；main 不变，T2 commit/attempt 不变，原失败证据哈希不变。
这是原生修复链路验收，不声称初始 Author 为真实模型或业务质量已保证。
具体 SHA、session、证据哈希见 VERIFIED_VERSIONS。漂移门 17 对/292 行、git diff --check 均通过。

# 第九批：有界进程输出、启动重试及 worktree 配额

Team 完整回归 **97 passed / 0 failed**，exit 0（575.29 秒）。随后补齐未显式传 manifest 的
集成调用读取冻结配置，以及 post-start 错误的进程启动事实，受影响进程/CLI 测试重新执行
**20 passed / 0 failed**，exit 0。最后把启动状态未知的 launch 收据明确存为 null（禁止重试），
进程测试再次执行 **15 passed / 0 failed**，exit 0。分次结果不合称一次最终全量运行。
native guard **5 passed / 0 failed**、派生漂移门 17 对/292 行、git diff --check 均 exit 0。

真实本地子进程覆盖：第二个日志文件打不开时子进程未启动；快速结束和持续输出均保留有界前缀；
stdout/stderr 分别截断；静默与大 stdin 不读取的超时；verdict 直接文件超限拒绝；
验证未启动时实际进程退出码为 null。注入的首次未启动错误只重试一次，已启动和未知状态不重试；
实际 adapter 在仅对该子进程隐藏 DSH 的 PATH 下写出两次失败收据，升级并释放未使用的 Agent 预留。
CLI 反例覆盖 Worker、外部验证、9P、final 的 1 MiB 限制，均拒绝结果且保留日志；
第 13 个 Worker/集成 worktree 在分支创建和 attempt 递增前拒绝。

真实 `BOUNDED-NATIVE-010` 完成：一个 DSH Worker 只实现指定标签函数，包含空值/空白/中文的
六条原合同由外部进程验证，Lead 检查真实 diff 并按 SHA 验收，随后集成和 final 均 exit 0。
单日志上限设为 1 MiB，Worker stdout 1218 bytes、stderr 9631 bytes，启动一次且无重试，
run=COMPLETED、main 不变且干净。真实模型证明正常传输链路，超限/重试故障仍由前述进程及替身测试证明。
未重复调用 Codex 模型；独立审查限额本批为替身 CLI 接线验收。
直接 verdict 文件只受轮询检查；退出父进程的后代持有管道时的收尾边界仍在 SPEC_COVERAGE 中保留。

# 第十批：退出后管道收尾与真实协调器崩溃恢复

先在独立临时目录复现：父进程退出 0、后代持有管道，`Wait-TeamProcess ... 2` 原来约 4.925 秒
才返回 0，越过期限且被当作成功。修复后同一复现约 2.246 秒返回 31，保留已写输出。
父进程退出后继续检查总期限、idle 和输出限制，pipe drain 单独最多 3 秒；可取消读写，
Windows 只清理通过父生命周期、PID 和创建时间核验的直接子进程树。流失败和未知清理事实不伪装为通过。

Team 完整回归 **106 passed / 0 failed**，exit 0（599.50 秒）。随后补齐清理失败的
`cleanup_pending`、预留保留、执行阻断和 stop 重试，受影响进程/CLI 再执行 **12 passed / 0 failed**，exit 0。
最后增加身份查询失败的故障注入：取消后流任务结束、控制流程及时返回 31、未知子进程仍存活且未被猜测终止；
测试自身最后按独立保存的身份清理，**1 passed / 0 failed**，exit 0。分次运行不合称一次全量 109 项。
native guard **5 passed / 0 failed**、派生漂移门 17 对/292 行、git diff --check 均 exit 0。
覆盖完整成功 Result 之后管道仍被占用的反例：adapter 返回 31，native_exit_code 保留真实 0，
不生成可验收 result.yaml、不运行外部验证；Worker/验证/审查的持久记录包含 `transport_cleanup`。
清理失败不会阻止其他 Worker 的终止，也不会释放失败项预留或允许重派；CLI 对 pending 的 resume、
integrate、replan 拒绝 80，stop 仍可重试。测试证明的普通 Windows 子进程清理不扩张为 OS 沙箱承诺。

真实 `CRASH-NATIVE-011`：DSH 在固定 wait 脚本的可观察等待点执行中，外部只终止协调器，
原生 Worker 继续存活；第一次 resume 拒绝 80，未增加 attempt。外部放行后原 session 完成代码提交，
第二次 resume 使用持久 exit/Result/Git 事实接续验证，六条固定合同通过，attempt/Agent 均为 1。
Lead 按实际 SHA 接受，最终集成和 final exit 0，run=COMPLETED；main 不变且干净。
这是实际模型进程崩溃恢复验收，没有用替身 Worker 替代，也没有覆盖全部 checkpoint 崩溃窗口。
具体身份时间、SHA 与哈希见 VERIFIED_VERSIONS；原始 runtime 及简要断言留在临时目录。

2026-09-17 能力与路由收尾：

纯本地 route 增加固定领域路径 metadata 与风险标记，模糊实现建议保持低置信度；
README typo 不因仓库存在前后端就升级。三次误判后持续 degraded，后续一次匹配不会清除；
route/doctor/run/resume 对 Lead 显示通知，显式 revalidate-route 重放四个固定示例与已记录任务，
失败 exit 20、保留降级，全部通过才恢复。合同与独立 Git CLI 覆盖元数据修正前后、旧计数缺样本、
共享更新锁及真实任务回放；替身 Worker 的接线测试不等于真实模型质量验收。

按人类明确选择保留 L3 适配器扩展；矩阵原生 I1/O2/E2 仍列 L1/L2，doctor 单独标记扩展。
run/resume 实际使用 capability 决策；原生子 Agent 服务缺失时在创建 worktree 前拒绝 L3，
恢复时再次拒绝且不增加 attempt，L1 仍可执行。未知版本显式 override 保留 UNVERIFIED_RUNTIME
的 L1/L2 路径，不授予已验证 L3。L2/L3 冲突修复串接继续通过定向测试。

真实本机 doctor exit 0，四个路由示例全通过，PINNED_RUNTIME，原生工具 available、guard observable，
matrix_modes=L0/L1/L2、allowed_modes=L0/L1/L2/L3、adapter_l3_extension=true。
`Test-NativeFork.ps1` 的真实 DSH 双回合 probe exit 0 / passed=true：已完成父回合的 19 条事件
进入子 seed，新子提示没有随机标记，子不调用工具仍准确回忆标记。事实与哈希见 FORK-INHERIT-012。
此 probe 使用临时 overlay 驱动原生 Agent，不是裸模型 API，也不把普通单回合 Worker 改成长期会话。

本批完整 Team Pester 回归 **127 passed / 0 failed**，exit 0，672.46 秒；
native guard **5 passed / 0 failed**、派生漂移门 17 对/292 行、git diff --check 均 exit 0。
完整回归后补上原生 provider 服务准入检查：只有工具名而 provider disabled 不允许 L3；
本机真实 doctor 再次 exit 0，五个必要服务均在启用列表。
该补充之后运行 provider 负例、L3 准入/恢复和 L2/L3 冲突集成定向回归，
**4 passed / 0 failed**，exit 0，72.54 秒。分次测试不合称一次完整 128 项回归。
