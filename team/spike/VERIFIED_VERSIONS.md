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
两次运行后 main 仍为上述 base，调用者工作树干净；未向 workflow 仓库创建提交或执行 merge。
