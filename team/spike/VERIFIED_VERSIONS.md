# 版本与可复现锚点

| 项目 | 本机核验值 | 运行门 |
|---|---|---|
| Codex CLI | 0.153.3 | 精确 pin |
| DSH CLI | 0.1.5-rc.1 | 精确 pin |
| PowerShell | 7.6.6 | ≥7.4 |
| powershell-yaml | 0.4.12 | ≥0.4.12（用户已批准） |
| Node | 24.19.0 | 由 DSH 使用；guard tests 实跑此版本 |
| Worker | deepseek-official / deepseek-flash | composed config、settings、实际 native 创建三处核对 |
| Lead alias | astra-lead → gpt-6-astra | Codex 原生；独立审查实测另记 |

逻辑别名不硬编码在算法中。DSH 实际模型 id 与规格示例不同，按 Phase 0 绑定实际可用 id，
不把模型自报的营销名称作为路由证据。升级默认拒绝；override 明确记录 UNVERIFIED_RUNTIME。

首条真实 L1（临时仓库 `team-live-f2cd0576de`）：
base `df1114952cb532e0d4e6ac1b281829af7f49a192`；
Worker `75976b714dd135d8889a710b6c0a4e5699de592f`；
integration `dc58a8a35f04ce283bdb20f38650c97f5f2d2feb`。
外部 query-content exit 0，Lead inspect/accept 后集成 targeted/final exit 0。
该首次记录早于 native guard 接入；guard 的主/子 Agent 探针另有真实 receipt。

真实 native probe `team-native-b5a9a7a2`：根 session
`session-822f3584-6afc-4ab4-a882-b288bd188bcd`，子 session
`8bec721e-10b1-4f1e-9f68-7d91c88d1246`；depth=0/1、路由一致，exit 0。

真实 Critical `CRITICAL-SMOKE-002`：base `ca475e7ddcec6bb2fa5c4a396436894c976c8636`，
Worker `8a9a6862c433e460a0ff991207d90162a7a33674`，integration
`7026ecb4d5f9fe98ecea1b6a386e10cc59f4a04f`；9P/9A/9B pass，全部 VN 逐条处置，COMPLETED。
9B verdict hash `fe225ff4c76024b3593ccfc68e939067883d74d6738600300b218e413da1afbe`。

真实 L3 `NATIVE-SMOKE-003`：同一 base，Worker `a46d511d3a63aa7106e91792553aae96b7820601`，
integration `4fff690b6ee9947c92df828a3b13e062e44b746c`；root+fresh child 共 2 个实际 Agent，
Result 汇总与 native receipt 一致，严格 SQL 内容验证 exit 0，Lead accept 后 targeted/final exit 0，COMPLETED。
两次运行后 main 仍为上述 base，调用者工作树干净；这些 fixture Worker 未向 workflow 仓库写入或执行 merge。

真实 L2 `L2-NATIVE-004`（临时仓库 `team-l2-live-0a45e9b6f0`）：
base/main `61cfe04a9153189eede41c974d0062508dcde908`；两个独立 DSH Worker
在 `21:58:02.849Z` / `21:58:03.146Z` 启动，首个在 `21:58:33.206Z` 进入 REVIEW，确认执行重叠。
Worker commits `ebf7d5bacfe07671647c5c4decaf2025ef4c814b` / `15da801cb8f7af18d1e3caad13dd3d29fc55c24b`；
integration `f312f2ea8199d2e5ee1d251320f02c95d638ab1d`，agents_created=2，两个 targeted/final 检查 exit 0，COMPLETED。
实际 root sessions：`session-e6dd8cb9-c12a-4e30-9829-abc3835cc19c`、`session-1636a146-808d-489c-8c34-e8ef57a88922`；路由均为 manifest 指定值。

真实 fork 入口 `FORK-NATIVE-005`（同一临时仓库/base）：
Worker `16620d5d15c53c788ab366be077dbcc7e0221e9b`；integration `6c75b622e38dd1a7cf0c09a9e32733059b9ce564`；COMPLETED。
root `session-452a4934-cf5b-4196-8b3b-ecc2f96a5c69`；child `e8c66848-b030-432b-af35-f2f0456a6436`，depth 1、同路由。
从原生日志的 `tool/call` 事件提取到唯一 `subagent_fork`，call ID `call_00_KfZAC4mETw2igpHCym8e6538`。
会话文件 SHA-256 `4073de0a3a5e8cea04154a5e3421e8bc1724775df606b40f3c7800b3c07a2b59`。
只导出工具名/ID和 session metadata，未导出推理或工具参数；证据在该 run 的 `native-fork-evidence.json`。
边界：首次 headless 回合没有已完成的父回合前缀，native fork 按其实现创建 isSeeded=false 的子会话；
此验收证明 fork 工具和交付链路可用，不证明非空历史继承。非空前缀现另见 FORK-INHERIT-012。

真实非空继承 `FORK-INHERIT-012`（2026-09-17）：
执行仓库内 `pwsh -NoProfile -File team/spike/Test-NativeFork.ps1`，exit 0；
独立证据目录 `C:/Users/16097/AppData/Local/Temp/team-fork-inheritance-cc7832c1bc`。
探针 overlay 只驱动原生 Agent 完成一个额外父回合并记录事实，不直接调用模型 API，
不替换原生 fork provider。测试自身的预热文本为随机合成标记，不涉及用户文件。
父 session `session-9156e0c5-128f-492c-901b-d40758c14711` 完成首轮、无工具调用；
子 `cb39a708-b998-4399-9d02-4109a9655824` 深度 1、同为 deepseek-official/deepseek-flash。
子创建参数包含 19 条真实父事件，末条为 turn/end；seed 含标记，子任务新提示不含标记。
子自己的回合无工具调用、完成并准确返回标记；native guard 记录恰好两个 Agent。
这证明已完成非空前缀的行为继承；不声称普通单回合 Worker 自带历史，也不用于 fresh Reviewer。
`inheritance.json` SHA-256 `77fbc8e4ad72c08925dcdba498c53a5a9841c36668b963f148e5b098c0454158`；
`agents.json` SHA-256 `1b71c7060b08a84fa1847721ec293b3f62fd7f2781041c12b0c8f6a28985639a`；
`worker.stdout` SHA-256 `6ea5ef4e860c324705d514cf5e65d88e2a8aa3c32caab323d9a94bf455f797dd`。
摘要仅包含布尔断言、计数、会话 ID 和哈希，stderr/原生推理不复制到仓库。

真实角色/冲突集成 `ROLES-NATIVE-006`（同一临时仓库/base，最终 revision 3）：
backend commit `0e44879bcddf4a23880b3dbdd5cc0403a5798764`，frontend commit `3d0237fb430024ad7bfe9b78380613c18b1b6b57`。
两者均收到冻结角色定义并通过外部验证；合并同一 JSON 的两个字段产生真实 add/add 冲突，exit 81。
Integration Worker 从已合并 backend 的 checkpoint `eba88c44e56c961c74909aeebda838316acff82b` 启动，
repair commit `fbdc520a4b2cc342ff96850e6f0c54cac8c6bbcc` 包含 frontend 源提交祖先，且只改 `contracts/components.json`。
最终 integration `7b735242243d545681a547ea706760016ac02af9`；完整计划验证 backend/frontend 两个布尔值同时为 true，exit 0，COMPLETED。
三个成功 Worker 的实际 session：`session-5e4c7161-3035-4637-8579-64c3967b2540`、
`session-ac4ce94e-5791-4285-9ff5-cf949edbc8ba`、`session-d3fcf08d-8a90-4af6-a96a-b90ea47b6a19`。
首次 frontend stdout 在合法 JSON 前带说明句，被原严格正文适配器拒绝；原文 SHA-256
`4eb370051ff1d77577976f15b160e1009632768d4b0f2bddb42500fc8fc62a5f`。
适配器修正后对该原文回放成功，并通过显式 replan 重跑受影响任务；失败 attempt-1 全部保留，累计计入 5 个 Agent。
测试仓库 main 仍为 `61cfe04a9153189eede41c974d0062508dcde908`，调用者工作树干净；未部署业务系统。

真实升级 `ESCALATE-NATIVE-007`（临时仓库 `team-escalation-live-3cbc450344`）：
缺少业务开关取值，明确禁止 Worker 猜测；DSH 返回 `status=escalated`、空 changed_files、self-check=false。
base/Worker HEAD/main 均为 `e4fcfaa6ddcf9b71622523f517b51a383179420b`，没有实现提交。
原生 session `session-cd9f4be9-00fb-4f87-a6cd-b041c985bdd3`，deepseek-official/deepseek-flash，depth 0。
Result SHA-256 `6546ab24d1267e431bdd2a17192c40eac5a152eca25ad01ff0a7a477a7b16df0`。
控制器 exit 70，run/task 均 ESCALATED，生成 `ESC-59825732a9` 并绑定结果哈希，未生成外部验证证据。
main 未改变、调用者工作树干净；验收断言完成后以明确的测试结束理由 resolve reject，最终 CANCELLED，证据保留。
这是实际原生 Worker 的缺失决定升级验收，不是业务实现完成或人工业务决策验证。

真实逐问题审查 `REVIEW-NATIVE-008`（临时仓库 `team-review-live-7ec409dc2d`）：
这是独立 Reviewer adapter 的负例→修复验收，未运行 DSH/9P/9B，不称为完整 Critical 交付。
base/main `9850bc5265cd182db4c24b8306ebf2150b27c11e`；首个 fixture 提交
`13dff821e81d3173e19a3a7a11632f2cae518c11` 故意对负整数原样返回，外部检查只测正整数。
真实 fresh Codex 给出 `ABS-001`：`-3` 返回 `-3` 而不是 `3`，归因为 no；exit 50，round 1/streak 0。
verdict SHA-256 `ebc35dc1b870695e9995a3c944a5aa9a6e16c43fd4f48393460a4f8c4230be9e`。
显式 replan 到 revision 2，修复提交 `1b8b2ff609dfe411764934855901055075ebb4c6`；
外部进程验证 -100..100 共 201 个整数，exit 0，stdout SHA-256
`c9a3fdefe2c636738a62cf7129d655a87534f64736c8de3ecf777b6b56878661`。
第二次 fresh Codex 收到相关问题、前次 tip 和精确修复 diff，返回 pass、无 blocking/VN、writes_performed=false；
verdict SHA-256 `51283908197cefed617492aca9fe15079fde0c6b2a27ed0dd7d70b640162c768`，
输入 SHA-256 `5fd977066447fafe9884dd8514510ab9260097ec70f91f67c1bf0f78fc839ce0`。
两份 verdict 历史均保留，round 2/streak 0；main 不变、两个审查快照干净。验收后 stop，最终 CANCELLED。

真实回归修复 `REGRESSION-NATIVE-009`（临时仓库 `team-regression-live-8b43232241`）：
两个初始 Worker 输入由测试替身故意制造并接受，以触发 final 失败；**并非真实双 Worker 交付验收**。
base/main `1839aa9c7be57019335a496732b748fc99de626d`；失败集成 SHA
`346dec44e00c3a1ee58905ca4e9cf024ef627d0b`，失败记录 `FAIL-144e606860a6`，
原始验证证据 SHA-256 `a43d6fe9227e90449f327827b601832778000ee3dcb83c64566cb70569816ca5`。
回滚较早的 T1 后，集成 SHA `8dcd0579fd3bae17b578d3e718c2de21c0fcc5b6`；
较晚的无关 T2 保留，commit `d91d12b070cabecedaf0f67c000310c3bd99afb5`、attempt=1。
Regression Task 经显式 Lead 决定生成 revision 2，然后调用**真实 DSH Integration Worker**，
session `session-851b9b38-42de-4de7-9013-48684f83dcd0`，deepseek-official/deepseek-flash，depth 0。
Worker 只把 `files/T1.txt` 恢复为已批准的 `42`，T2 原样保留；repair commit
`54c9689a9498d10789df850dee599804c10c7494`。Git scope、原命令及完整合同验证 exit 0，Lead 按实际 SHA 验收。
最终 integration `1111af407973c76699f2661344e49dc38620c296`，run=COMPLETED、failure=resolved；
final stdout SHA-256 `b46cc5e6634d0e0b8bd41c963947a14f218b811ca29d373f22a081727205e497`。
原失败证据哈希不变、main 未变、调用者工作树干净；这证明恢复协议与原生修复执行，不是业务项目验收。

真实有界传输 `BOUNDED-NATIVE-010`（临时根 `team-bounded-live-be507af01b`，仓库位于其 `repo/`）：
本批仍使用固定 DSH 0.1.5-rc.1、deepseek-official/deepseek-flash。
base/main `8c5ffbcf570e352fa009c224d1eca5f1ac391fa3`；原生 session
`session-58047019-0ff0-4350-9316-8ccf8d1b0e17`，depth 0，仅一个 Worker，无子 Agent。
Worker commit `901155698dde1cfeb79f20587b8242906fc80ad4`，实际 diff 只有 `src/label.ps1`。
外部验证六条固定合同（null、空串、纯空白、英文、中文、制表符与换行），实际 exit 0；原测试未改变。
Result SHA-256 `8aaa570e15ce25e6b6b9b09d8bc52af4bdd253dc659a5f7befe076eb878c1317`。
配置单日志上限 1 MiB，实际 worker.stdout=1218 bytes、worker.stderr=9631 bytes；
launch_attempts=1、startup_exhausted=false、native exit 0。正常路径未触发截断，不称为真实模型洪泛试验。
Lead 绑定真实 commit 接受后，最终 integration `7121b4a9f40255f6dc05602d9474e9f6977229e4`，
run=COMPLETED、final exit/process_exit_code 均为 0，stdout SHA-256
`fb25915d727b421175a83b10d8f7892b2c64d0b79a9df1e2100288667dbbc61f`。
main 仍为原 base 且干净；临时根 `acceptance.json` 保留精简断言结果，原 runtime 日志留在本机。

真实协调器崩溃恢复 `CRASH-NATIVE-011`（临时根 `team-crash-live-eac980226b`，仓库位于 `repo/`）：
base/main `ae9b319fecc339ebaf4a215379958f48f44cdcde`；DSH 0.1.5-rc.1，
deepseek-official/deepseek-flash；session `session-69756695-bd37-44d5-9c49-ef6039d102d9`，depth 0。
真实 Worker 执行受控 `wait.ps1` 写 readiness 后等待外部放行；只终止新建的测试 coordinator PID 928，
原生 PID 32272 仍存活，第一次 resume 返回 80，attempt 仍为 1。
两者 UTC 创建时间、存活断言与拒绝结果保存在临时根 `crash-boundary.json`，SHA-256
`32142289cf92da59f7fff9ff62a5963335cfdda06a2c6bd3df0e362be44a1e6c`；PID 仅为该次证据，不能作为后续终止依据。
外部放行后，同一 Worker 完成 commit `64d45cc25f761e2c5d2856c2119d451e70224177`，只新增 `src/label.ps1`。
native/adapter exit 均 0，drain_expired=false、streams_settled=true，Result SHA-256
`1ece1cb9c342b2424f2582fff1f5e98e307842a2ee0ffb27767b6481520e184e`。
第二次 resume 完成 Git/外部六条合同验证并进入 REVIEW，没有重启 Worker，累计 Agent=1、attempt=1。
Lead 检查真实 diff 并按 SHA 接受，最终 integration `05e651ba2b647e054aa9cc1e0971f57d53f79cd5`，
run=COMPLETED；final exit 0，stdout SHA-256 `d83afd5262e47eb0c5d7d7a17c6be3d038657227c048ff8fbc3960dac8986c43`。
main 不变且干净；固定 wait/verify 脚本未改变。此验收覆盖该受控崩溃点下的真实原生连续执行，
不代表所有 checkpoint 持久化窗口或崩溃后需要 replan 的路径均已验收。

真实独立本地审查 `LOCAL-NATIVE-013`（临时根 `team-local-review-live-bd01faf9fd`，仓库位于 `repo/`）：
DSH 0.1.5-rc.1、deepseek-official/deepseek-flash；作者 session
`session-3048310b-6f94-43e1-b3ed-f2d8d231051d`；独立 Reviewer session
`session-ced277e0-2357-464b-9887-6c1f0110478e`，收据 read_only=true、depth=0。
base/main `9c3b931b6d345dfdf2d00878442e271bcd0d568f`；作者 commit
`8d0f61f62294347701e8a4ebb4de392c70a1bd46`，只新增 `queries/health.sql`，外部验证 exit 0。
本地 verdict=pass、无 blocking，但要求补充 Git 干净状态与唯一目标文件证据；首次 run 返回 70。
随后 resolve-review LOCAL 实际执行所需 Git 检查，exit 0 / GIT_SNAPSHOT_PASS；resume 复用原 verdict，
作者 attempt=1、累计 Agent=2、预留=0。Lead 按 SHA 接受后集成完成，run=COMPLETED；main 不变且干净。
最终 integration `da2ddc7392f7256a8a4c2390cf5c18993cbed031`。
verdict SHA-256 `80b6210f0f8f85873bfcd39e14c9aec3e410f44bc51f26f62478f47282bb2d3a`；
输入 SHA-256 `cf68e2d282043bf240b027e7069d38339c748db90a8f8a2304472b2f44f97161`；
补证 `VN-LOCAL-SQL-001-0-evidence.json` SHA-256
`50c21b2cef14f11c85039e829449a669068bfebb42f7e3b9316d8fd6f2784b13`。
临时根 acceptance.json 保留精简断言；原始审查 holding 与会话仅留在本机。
可复用付费探针为 Test-NativeLocalReview.ps1；若模型提出 VN，脚本保留根目录并停止自动推进，
须按实际请求 resolve-review、resume、accept、integrate，不能自动编造补证处置。

真实并发/依赖/超时修订 `DAG-NATIVE-015`（临时根 `team-native-dag-2e8c33be1f`，仓库 `repo/`）：
DSH 0.1.5-rc.1、deepseek-official/deepseek-flash；base/main
`37af4281a2f0693646ab9bdd9c062bbd44bc0cfe`，最终集成
`2a8ff79582e55eca7f9d52c44cb7cfb071289c4c`；run=COMPLETED、revision=2、main 不变且干净。

| 任务 | 成功提交 | 作者 session | 独立 Reviewer session |
|---|---|---|---|
| LABEL a1 | `da7efa7259d45bdf40dd814e1425ff7028478c66` | `session-b27f1bd2-6b57-4698-a0a3-bf82eaf4dfba` | `session-38daf653-232e-4a3b-a7e9-2c776fb58f1d` |
| TOTAL a2 | `7cf9e1a1dc8b1cb458a1d15358b7f1612ee3f6a3` | `session-4613cab4-b945-46ca-a34e-ec801598b2f9` | `session-7e6714ee-d08e-4e8d-baf5-9302ff51f6c1` |
| SUMMARY a1 | `b246392c87adfeeedd9af21d46651f826db5c85e` | `session-43aa0a7e-a12a-41d9-a71a-5e7d5448ef02` | `session-43bcdd9a-fd55-44ca-ae05-efe879c0e734` |

LABEL child `32214928-adcb-47c1-b6e5-a43fe09548de`，depth=1。
TOTAL 首次作者 `session-a30dbeca-7b90-4c27-b60f-5b3a9352be02`、child
`da453814-8925-4579-8887-702081f8fccb` 已记录，但该 attempt 实际 idle timeout / exit 31；
没有计作成功交付。并发观测时两个 native PID 4440/26552 均按 UTC 创建时间核对存活，预留=6。
显式 replan r2 保留已接受 LABEL，只重做 TOTAL 及其依赖；SUMMARY 的 base 精确为两个上游
集成后的 `bbce64b1ebaa8a7385f5579d651b767d967d4ab7`，全部源提交为最终集成祖先。

三份 Reviewer 均 read_only=true、与作者身份不同。TOTAL/SUMMARY 各一项 VN 实际执行通过，
分别证明 decimal 类型和值、de-DE 下 `3,75` 控制值与 `x|3.75` 输出；原 verdict 不变。
固定全量测试输出 LABEL 5 / TOTAL 5 / SUMMARY 4 cases，exit 0。
原始验证合同的 Git blob `0ec54d0b034aa309a64dfb20c4ad926f4ffeac28` 在所有工作树一致；
本机 core.autocrlf 的字节差异及一次失败补证另存 `vn-initial-byte-hash-failure/`。
累计保守记账=10、实际不同原生身份=9、预留=0；不将它们当费用金额或实时模型并发数。

证据 SHA-256：

- `acceptance.json`：`82a7e5b18fc4bee5b806ceaeccdc0c4f062b3329089a910f97dc7b947e01390e`
- `observations.jsonl`：`2e0918f6064f307b7caa892d80cccb6334da9568ee912c5faeb0da800fa79d99`
- 最终 stdout：`f77759c365c2f5874badb41145cc2e071a945a4e210e28224c6468167748a6ce`
- LABEL verdict：`d5144d739e7d02564fb956790c1876b8067a4e865384bba9679b03878cbad547`
- TOTAL verdict：`a45815bf3953f7768c551f11cc15cb467d276c9da2f938b836d414c9db7d9dba`
- SUMMARY verdict：`bf91f0cb86d23fcf4e27b69d386f82d22ef3579ef23b5fea33ba082f9e8ffc8d`

前次 `DAG-NATIVE-014` 根 `team-native-dag-7fba5ecf2e` 保留失败记录并已 CANCELLED：
当时 TOTAL 的 Local Review 请求 VN 导致另一个运行中作者被清理；修复与替身并发回归见 ACCEPTANCE。
015 没有重演同一个真实并行 VN 时序，不能把它当该故障的真实模型回归。
