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
此验收证明 fork 工具和交付链路可用，不证明非空历史继承。非空前缀行为仍需单独验收。

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
