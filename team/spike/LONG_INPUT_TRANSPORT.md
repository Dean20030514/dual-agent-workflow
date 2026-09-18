# Team 长输入传输验收（2026-09-18）

森驰汇的完整项目规则约 50,000 字符；旧适配器的 24,000 字符命令行上限使本地审查无法启动，拆小代码 diff 也无法解决规则本身超限。

## 实现

- 短输入仍使用原生 CLI 位置参数。
- 长输入保存为运行专属 `prompt-input.patch.json`，设置原生 `headless-runner.config.task`；通过额外 `--patch` 传入。没有改动已安装的 DSH 包、模型或权限守卫。
- JSON 顶层必须是数组，即使只有一项。首次原生探针因 PowerShell 单元素流水线展开而失败，修复为 `ConvertTo-Json -InputObject` 后通过；替身同时增加原生格式约束。
- `input-transport.json` 记录文本 SHA-256、UTF-8 字节数、字符数与传输方式。规则与 diff 均不截断。
- `max_dsh_prompt_chars` 为文件传输切换阈值；`max_review_input_bytes` 为完整输入准入上限，适用于 Worker 和 Reviewer。超限仍拒绝启动且不占原生 Agent 名额。

## 已执行证据

1. `Invoke-Pester`：`Run.Path=team/tests/Runtime.Tests.ps1`，`Filter.FullName=*transports long*`，`Run.Exit=true`，`TestResult.Enabled=false`。
   **2 passed，0 failed，exit 0**。覆盖长规则本地审查、长 Worker 输入、中文/引号/换行逐字保留，以及字节上限拒绝。
2. `node --test team/tests/native-guard.test.mjs`：**6 passed，0 failed，exit 0**。
3. 真实 `Invoke-DshWorker.ps1 -Mode local-review` 原生探针：**70,426 UTF-16 字符 / 76,426 UTF-8 字节，exit 0**。提示词首、中、尾分别放置随机标记，原生模型返回三项完全一致；这只是传输探针，不是产品审查 verdict。
   记录显示 `provider=deepseek-official`、`model=deepseek-flash`、单个 `depth=0` Agent、`read_only=true`。没有模型工具读取提示词文件。
   提示词 SHA-256：`fd54d22cf36ea704dd89a3d7ebaf2b077f717bf80931852d181f94e41b8c0106`。
   本机完整证据：`C:/Users/16097/.codex/team-review-holding/long-input-20260918/`，含提示词、原生 stdout/stderr、路由与退出收据。

4. 收尾定向回归：`Run.Path` 为 `Runtime.Tests.ps1`、`Processes.Tests.ps1`、`Hardening.Tests.ps1`；`Filter.FullName` 为 `*transports long*`、`*retains two real command-resolution failures*`、`*Bounded transport*`，`TestResult.Enabled=false`。
   **6 passed，0 failed，0 skipped，98 NotRun，exit 0**。覆盖长输入、真实命令解析失败、有界传输及日志保留；包含第 1 项的两个用例，不累加为不同用例。
5. `pwsh -NoProfile -File tools/dsh-drift-check.ps1`：**17 对派生文件、292 行登记差异，DRIFT none，exit 0**；`git diff --check` 通过。

6. 完整 Team Pester 回归：`Run.Path=team/tests`，`Run.Exit=true`，`TestResult.Enabled=false`。
   **227 passed，0 failed，0 skipped，0 inconclusive，0 NotRun，exit 0**；7 个测试文件，耗时 **2,568.16 秒**。
   复用实现任务在本机 2026-09-18 00:03:51 启动的原测试进程；收尾独立观察其在 00:46:41 退出为 0，并从该任务已完成的工具记录保存完整输出。没有重复启动整套测试。
   回归期间实现脚本和测试文件的 SHA-256 与收尾开始时一致；仅补充文档。

## 部署与证据保存

实现任务已将候选运行器同步至共享副本并开始真实项目任务；收尾阶段核对了全部 `team/scripts/` 文件与共享副本的 SHA-256，一致。正式提交后通过仓库安装器部署，并保存只读预览、部署输出与七项目检查结果。运行器验收不代表森驰汇或独立计时器的业务验收完成。

本机收尾收据目录：`C:/Users/16097/.codex/deployment-backups/team-long-input-20260918/`。原生提示词与完整日志保存在前述 holding，不随仓库提交或部署公开。
