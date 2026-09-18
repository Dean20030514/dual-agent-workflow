# 验收记录（2026-09-17）

以下按实施顺序保留历史批次及失败记录，不能累加重跑数量。
最终结果见文末：常规 158 项、恢复专项 28+2 项、Node guard 6 项通过；
本机 Defender 允许检测类别的条件一并保留，不改写为官方误报确认。

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

# 第十二批：独立本地审查、废弃任务与重复失败

每个成功 Worker 在外部验证后进入独立原生 DSH Local Review，再进入 Critical 9A（如适用）
和 Lead 验收。禁用全部工具，输入不含作者聊天或推理；verdict、输入、plan hash 与 tip 绑定。
补证必须逐项处置并 resume，不能跳过 9A；失败审查不能靠重复模型调用覆盖。
Reviewer 纳入全局 Agent 预留/累计数，独立保存 adapter/native PID 与退出收据。
替身 CLI 加真实进程覆盖审查失败、无效 JSON、写入快照、补证、协调器崩溃恢复和 stop；
崩溃恢复复用原审查，作者 attempt 不变。首次 stop 测试揭示 StrictMode 下缺失 closed 属性的
清理异常，修复为可空键读取后，stop 与跨 attempt 重复失败定向测试 3 passed / 0 failed，exit 0。

replan 把受影响的旧 attempt 归档为 DISCARDED，包含从新计划删除的任务；
cleanup 核对 packet、路径、分支、实际 Git tip 与干净状态，只移除 worktree，保留分支和证据。
实际 Git fixture 覆盖脏目录拒绝、重复修订不重复归档、清理后派发替换 attempt、无关 ACCEPTED 保留。
同类 Worker 失败按不同 attempt 计数，两次升级；Critical 范围违规一次升级。
重复 resume 不重复计数；无效 Result 的失败 run 现明确 PAUSED，避免留在 RUNNING。

真实 LOCAL-NATIVE-013 首次本地审查 pass 并提出一项 Git 补证，run 返回 70，未伪装为直接通过。
随后外部进程实跑补证 exit 0，resume 复用原 verdict，Lead 验收并集成，最终 COMPLETED。
作者和 Reviewer 使用两个不同 DSH session，Reviewer 收据 read_only=true，累计 Agent=2，预留=0；
main 不变且干净。具体 SHA、session 和哈希见 VERIFIED_VERSIONS。

本批自查修复协调器延迟收取已退出 Worker 时的超时误判：仅对仍在运行的进程套用当前时钟，
已退出进程仍检查输出上限并读取 adapter 的真实超时/退出收据，不跳过原生期限。
本批完整 Pester 运行 **141 passed / 2 failed**，exit 1，947.75 秒：失败分别为进程测试漏加载
Controls，以及旧审查文件总数断言未区分新增的两份 LOCAL verdict。前者补齐测试依赖，后者
保留原有四份 Critical verdict 断言并另断言两份 LOCAL；没有跳过或放宽产品门禁。
两个失败及上述并发修复均在以下后续定向运行中验证通过，不合称一次最终全量 144 项通过。
最终进程测试 **25 passed / 0 failed**，exit 0，22.46 秒；并发 DAG 与 Critical 修复轮次
CLI 定向回归 **2 passed / 0 failed**，exit 0，64.71 秒。
native guard **6 passed / 0 failed**、派生漂移门 17 对/292 行均 exit 0。

# 范围候选集交叉与传递边界

以相同通配符前缀猜测范围相交会把 `src/*.ts` 与 `src/*.css`、`src/a` 与 `src/ab`
误判为相交。现在按既有范围语义计算实际交集：`*`/`?` 不跨目录，`**` 可跨目录，
路径大小写和方括号按既有规则处理。失效任务的依赖下游及其相交范围计算到稳定闭包，
保留仅前缀相似而无实际交集的任务；`affected` 未提供具体路径时预览相同候选集。

真实 Pester 合同与 CLI 预览回归 **66 passed / 0 failed**，exit 0，9.96 秒。
新增九组交集正反例和一组依赖/范围传递案例；这不是持久化中断验收的替代品。
同轮恢复事务实现尚未提交：专项 Persistence.Tests.ps1 被 Defender/AMSI 拦截，
尚未完成对应中断点验收；未关闭防护、添加排除项或将被拦截测试迁移到其他执行入口。

2026-09-17 只读核查：Defender 1116/1117 记录该文件在 18:54:54、18:57:37（本机时间）
触发 `HackTool:PowerShell/ApexToolkit.A`，来源 AMSI，随后记录隔离动作。
当前可读文件 SHA-256 为 `5226721c41e60067c1afed7667ee50425f8bba37435820af02243e74bf0e9b58`；
静态内容为临时 Git 仓库的持久化边界测试，未发现下载、窃密或修改安全设置的代码。
19:00:52 的另一条 `Trojan:PowerShell/PsAttack.R` 告警指向只读关键词搜索的完整命令行，
解释了当时一次进程启动拒绝访问；不能据此宣称文件已获安全放行。
防护保持启用，安全情报版本 1.459.258.0。结论为疑似误报、尚未权威确认；未再次执行该文件，
未向外部服务提交文件。普通 Runtime 回归可执行不代表专项测试已通过。

# 并行任务补证与观察命令

真实 DAG-NATIVE-014 暴露：一个 Local Review 请求补证时，协调器错误清理了仍在运行的
另一作者。原 run 及失败证据保留并显式停止，没有把它改写为成功。
现在仅暂停新增派发，让已启动作者在原超时/输出限额内完成，记录 RESULT_READY；
补证后 resume 审计既有结果，不重复启动作者或覆盖原 verdict。
Local Review 输入补入已核验的子代理声明与原生身份/路由收据，不传作者聊天或内部推理。
定向 Pester（`*lets a parallel author finish*`、`*handles local evidence requests before Critical*`）
**2 passed / 0 failed**，exit 0，42.84 秒；这是替身 CLI/真实进程验收，不能冒称真实模型重演。

观察命令原来把空结果输出为空文本、单项结果展开为对象；现稳定输出 JSON 数组。
实际 CLI 还发现 `-Since` 参数的本地时间与 UTC 事件直接比较，错误纳入更早事件；现统一为 UTC。
新 Runtime 用例覆盖空/单项/多项 JSON、Task/Since 过滤、PAUSED 默认返回、Follow 保持及
CANCELLED 自动退出且不重复事件，**1 passed / 0 failed**，exit 0，17.95 秒。
该测试首次发现时间过滤问题，保留原断言；未通过修改预期来掩盖产品缺陷。
native guard **6 passed / 0 failed**，派生漂移门 17 对/292 行均 exit 0。

# 真实多 Worker、依赖与超时修订

`Start-NativeDependencyAcceptance.ps1 -PrepareOnly -RunId DAG-NATIVE-015` 创建独立临时 Git 仓库，
预先固定 LABEL/TOTAL/SUMMARY 共 14 个合同案例。实际 DSH 同时运行两个父进程，各创建一个
depth-1 子代理；按 PID+UTC 创建时间确认同时存活，SUMMARY attempt=0，全局保守预留=6。
这只是原生并发观测，未把 creation 收据声称为所有子代理同时执行模型推理。

LABEL 完成并通过独立 Local Review；TOTAL 首次 300 秒无输出，真实触发 idle timeout / exit 31。
保留失败 attempt 和预算记账，Lead 接受 LABEL 后显式 replan r2，仅影响 TOTAL/SUMMARY；
TOTAL 改为直接实现、不再委派子代理，累计上限仍为 10。LABEL 未重跑，TOTAL attempt=2。
随后两个上游各自验收并集成，SUMMARY 从包含两者的集成 SHA 启动，复用两个函数。
TOTAL 与 SUMMARY 的 Local Review 分别提出边界类型、de-DE 小数格式补证；外部命令实跑后
复用原 verdict，没有多跑 Reviewer 寻找通过结论。三份最终 Local Review 均 pass、无 blocking。

最终 COMPLETED，固定全量合同 **5+5+4=14 cases**，exit 0；主分支不变且干净，原验证文件
在全部工作树中的 Git blob 不变。累计保守记账=10、实际记录的不同原生身份=9、预留=0。
两者差额来自超时 attempt 的保守家族记账，不是金额账单，也不人为回填为零。
`watch -Task LABEL -Follow` 跨暂停/补证持续等待，最后自动退出 0 / COMPLETED，仅输出该任务事件。

补证脚本首次直接比对跨工作树文件字节，因本机 Git CRLF 转换失败；确认 Git blob 相同且
工作树干净后改按 Git 内容校验，首次失败输出另存，后续补证通过。探针模板现对临时仓库
显式设置 core.autocrlf=false，避免后续探针的字节差异；未改本机全局 Git 配置。
精确 SHA、原生身份及证据哈希见 VERIFIED_VERSIONS。该运行经过尚未提交的恢复事务工作树，
证明正常 replan/集成路径，不代替被 Defender 阻塞的持久化中断窗口验收。

# 补证历史与 fresh 审查启动参数

实际 DAG-NATIVE-015 补证曾需要手工备份首次失败输出：旧 resolve-review 对同一项复用文件名。
现每次 verify 使用独立目录，保留请求的 review/plan/tip 绑定、命令、stdout/stderr 和退出码，
成功 disposition 指向本次证据及哈希。异常退出 7 后重试成功的 Runtime 用例确认第一次全部
文件哈希不变、原 Reviewer 未重跑，最终可正常验收集成；与 Critical LOCAL→9A 用例合跑，
**2 passed / 0 failed**，exit 0，37.85 秒。

本机 Codex 0.153.3 help 支持所用隔离参数，features list 显示 memories 为 stable/true。
Team 审查现显式关闭 memories、忽略用户配置与额外 execpolicy，9P medium、9A/9B high，
不依赖个人配置默认值。9P→9A→9B CLI 接线用例检查实际传给替身进程的每组参数，
**1 passed / 0 failed**，exit 0，14.17 秒；没有为参数调整再次调用付费 Codex 模型。
此证据证明本机参数支持和调用接线，不声称重新完成更新参数后的真实模型审查。

Worker 异常退出专项用例：替身原生 CLI 实际退出 9，Team 返回 30，保存 adapter 退出收据；
直接 resume 返回 80 且 attempt 不变。明确 replan 后第二次完成，旧收据哈希不变、累计 Agent=3，
最终 COMPLETED 且 main 不变。**1 passed / 0 failed**，exit 0，20.29 秒；
这属于原文 §68 的故障模拟，未声称发生真实模型服务崩溃。

Defender 后续核查（2026-09-17）：获得用户明确授权后执行 Update-MpSignature，exit 0，
安全情报由 1.459.258.0 更新为 1.459.263.0，实时防护及防病毒均保持启用。
确认原 Persistence.Tests.ps1 的 SHA-256 与已核查文件相同后，仅复测一次。
Pester 在 discovery 阶段仍被 AMSI 拦截，exit 1 / Container failed=1，七项测试均未执行；
不可将输出中的 Tests Failed=0 解释为通过。新 1116 告警时间 19:54:31（本机时间），
威胁名仍为 HackTool:PowerShell/ApexToolkit.A，1117 于 19:54:44 记录隔离动作。
未再次重跑、改名迁移、关闭防护或添加排除项；疑似误报尚待外部复核。

随后完成当前工作树的四文件回归：Pester Run.Path 显式为 Contracts.Tests.ps1、Processes.Tests.ps1、
ReviewRounds.Tests.ps1、Runtime.Tests.ps1，Run.Exit=true、TestResult.Enabled=false。
**158 passed / 0 failed**，exit 0，858.09 秒；四文件内 Skipped=0、NotRun=0。
它覆盖已提交的补证/隔离修复及当前未提交恢复事务的常规路径，不包括被拦截的
Persistence.Tests.ps1，不能称为完整 Team 套件通过或事务中断窗口已验收。

# 本机显式允许检测项后的恢复验收

2026-09-17 用户选择本机放行，亲自执行 Add-MpPreference，为本机核实的
Threat ID 2147749462（HackTool:PowerShell/ApexToolkit.A）设置 Allow。
只读核对确认设置为 6，防病毒及实时防护均仍启用；这属于检测类别允许，
不限于单个文件，也不是微软确认误报。Agent 未关闭 Defender 或添加路径排除项。
确认原文件 SHA-256 仍为 5226721c41e60067c1afed7667ee50425f8bba37435820af02243e74bf0e9b58 后，
按用户操作接续复测：Run.Path=team/tests/Persistence.Tests.ps1，Run.Exit=true，
TestResult.Enabled=false，**7 passed / 0 failed**，exit 0，104.14 秒。
此前被拦截的七个集成写入边界现已实际执行；后续新增修订/回滚验收另记结果。

新增持久化专项：同一文件完整运行 **28 passed / 0 failed**，exit 0，395.78 秒，
Skipped=0、NotRun=0。其中包含原 7 个集成边界、5 个计划事务写入边界、3 个修订证据反例、
7 个回滚写入边界、跨两个任务的恢复及无关提交拒绝、3 个集成身份/输出反例和已知失败保留。
所有 Git 操作均在 TestDrive 临时仓库；Worker 和 Reviewer 为测试替身，使用真实子进程与 Git。
确认不重复 merge/revert、不重派作者、不增加原有 attempt/Agent 计数、main 不变，
并核对无关 ACCEPTED 的完整状态、旧计划原始字节、历史 checkpoint 和原验证证据。

随后补齐 stop 与终态保护：取消运行不接续尚未开始的回滚；拒绝已完成 run 的 resume 后，
保持 COMPLETED 与 state 原始哈希，不由统一错误处理器改成 PAUSED。
仅选这两项运行 **2 passed / 0 failed**，exit 0，28.78 秒；NotRun=28 是本次明确过滤的既有用例，
不是跳过失败测试。因此当前文件 30 个不同用例的证据为 28+2 两批，不声称单次跑出 30。

本机真实 doctor 再次返回 exit 0 / success=true：DSH 0.1.5-rc.1、Codex 0.153.3、pwsh 7.6.6，
deepseek-official/deepseek-flash 路由核对通过、四个路由样例通过、无活动仓库锁；
原生能力仍为 I1/O2/E2，L3 通过既定适配器扩展准入。该诊断未调用付费模型。
Node native-guard **6 passed / 0 failed**，exit 0；17 对派生文件仍为登记的 292 行差异，
dsh-drift-check exit 0 / DRIFT: none。

最终常规回归使用当前工作树执行：

```powershell
$c = New-PesterConfiguration
$c.Run.Path = @('team/tests/Contracts.Tests.ps1', 'team/tests/Processes.Tests.ps1',
    'team/tests/ReviewRounds.Tests.ps1', 'team/tests/Runtime.Tests.ps1')
$c.Run.Exit = $true
$c.TestResult.Enabled = $false
Invoke-Pester -Configuration $c
```

实际结果：**158 passed / 0 failed**，exit 0，868.12 秒；Skipped=0、NotRun=0。
Contracts 10.46 秒、Processes 18.13 秒、ReviewRounds 0.531 秒、Runtime 838.99 秒。
本轮恢复专项与常规文件不重叠，合计覆盖当前 188 个不同 Pester 用例；这不是一次全目录运行。
末尾两项终态修复以其独立定向批次验证，没有因重跑将同一用例重复计数。

交付核对：原 v5 文件 SHA-256 不变，SPEC_COVERAGE 逐章映射及 A–T 的实现/证据均已闭合；
DAG-NATIVE-015 当前仍为 COMPLETED/revision=2，main 干净，acceptance.json 与 observations.jsonl
的完整 SHA-256 与 VERIFIED_VERSIONS 一致。本轮没有再次调用付费模型，也没有执行全局部署。
所有改动文件 UTF-8 无 BOM、LF，git diff --check exit 0。此前失败、首次超时及边界说明保留。

## 2026-09-17 审计后四项修复验收

范围由人类明确选择：Lead 绑定、运行内临时角色、费用单位、可迁移的源仓路径。
费用裁决为 Astra Credits / DeepSeek USD 分账，两个账本各自软/硬阈值 10/20；
旧的无单位收据和状态保留，不自动解释成任何货币。

新增 `Bindings.Tests.ps1` 18 项通过（exit 0）：活动轮次/模型/缺失及残缺元数据、启动参数，
完整动态角色合同/禁止覆盖/冻结一致性，分账不合计/单位拒绝/阈值/旧收据及回退保护。
Runtime 新增 2 项定向通过（exit 0）：真实临时 Git 加替身 CLI 的自定义角色派发→修订新 ID→恢复，
以及未识别 Lead 时拒绝创建运行/worktree。它们的 Codex 元数据明确标记 synthetic-fixture。
恢复专项 30 passed（474.93 秒，exit 0）；Processes 25 与 ReviewRounds 9 全部通过。
Contracts 66 passed（10.05 秒，exit 0）。各文件的选择与是否定向运行明确区分，重复执行不重复计数。
原 Runtime 58 项完整回归亦通过（898.94 秒，exit 0）；加新增 2 项定向用例，
当前 Team 的 208 个不同 Pester 用例已分批通过。所有所选用例均无跳过，未把定向批次的 NotRun 当通过。

安装器首批 87 passed / 1 failed（exit 1）：失败为 planned 计数测试未包含新增 locator 动作。
补齐动作集合后，Plan 12 + workflow.Check 7 共 19 passed（84.26 秒，exit 0）；
新增定位文件覆盖前备份/只读预览/重跑不变的用例 1 passed（8.97 秒，exit 0）。
PowerShell 5.1、全受管面部署、参数/校验与项目接入用例包含在首批通过项内。
以上覆盖当前 89 个不同安装器/接入用例，未把重跑算成新增覆盖。
Node native guard 6 passed，17 对派生漂移检查 DRIFT: none，均 exit 0。

真实链路 `DYNAMIC-NATIVE-016`（非替身、实际调用 DeepSeek）：

- 临时主仓位于 `%TEMP%/team-dynamic-native-da94db990c/repo`，未使用业务项目。
- Plan 定义 `health-query-specialist`，由 database 完整角色合同派生；Worker Packet 携带该自定义定义。
- 当前 Lead 元数据实际为 `gpt-6-astra`、活动轮次匹配；桌面 Harness 版本 `0.155.0-alpha.2.6`。
  独立 Codex CLI pin 仍为 `0.153.3`，两者不是同一个版本证据。
- 原生创建记录为 `deepseek-official/deepseek-flash`；一个作者加一个独立 Local Reviewer，累计 2 Agent。
- 唯一业务文件 `queries/health.sql` 为 `SELECT 1;` 加换行；外部验证 exit 0。
  Local verdict=pass、Blocking/VN 均空、writes_performed=false；核对 diff 后才执行 SHA 绑定 accept。
- `run`、`accept`、`integrate` 均 exit 0，最终 COMPLETED；集成 SHA
  `a2e70f9619ae1be6959f10d1a876ffdda5916276`。
- Plan SHA-256 `0584596bc7d01916b73a382015325bb5d43195a1b165a0cdd92b63c5b3cc0d15`；
  Packet `e6ca81984cec507bdd0a26bcc42d575cfee074eab73696fb535d67687d5bbde2`；
  native agents `b3ba28d69c464e845b1e687fd488c739f55cb7716d8071427e95bd7f382f93a4`；
  Local verdict `d5144d739e7d02564fb956790c1876b8067a4e865384bba9679b03878cbad547`。

此轮真实链路证明临时角色的首次派发、外部验证、独立审查与集成；角色修订/恢复仍为替身验收。
费用仍依赖外部账单，未宣称得到了完整服务端账单。Lead 证据来自本地 Harness 元数据，
不是服务端模型签名，不防同权限进程修改；此次没有扩建 OS 沙箱、常驻强制入口或版本重认证机制。
