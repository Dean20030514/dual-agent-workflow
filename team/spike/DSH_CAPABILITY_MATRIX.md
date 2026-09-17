# DSH 能力矩阵（2026-09-17）

已安装 `@deepseek-ai/dsh 0.1.5-rc.1`，Node 24.19.0。

| 能力 | 证据 | 判定 |
|---|---|---|
| headless / CLI arg | 本机 `dsh --profile headless --help` + 真实 SQL Worker | I1 |
| prompt file / stdin | startup.js 仅解析位置 task；不将其他 Harness 参数套进来 | 无原生输入接口，adapter 组装 Task |
| stdout / exit | 真实 SQL Result、无工具 guard probe、native child probe均 exit 0 | O2 / E2（已测成功路径） |
| 严格结构化结果 | adapter schema 拒绝非法正文；Git 再核对 Result | adapter 提供 |
| model route | composed config + settings；native guard 记录实际创建的 provider/model | deepseek-official / deepseek-flash |
| cwd / worktree | SQL Worker 在独立 temp worktree 提交，main SHA 未变 | 已实测 |
| subagent | 真实 fresh/foreground 子 Agent 返回 TEAM_CHILD_OK，父子 receipt 路由一致 | 已实测 |
| subagent_fork | 安装源码和 overlay 可用；不是 fresh reviewer | 源码核验，未单独实跑 |
| workflow | Team V1 overlay 禁用，防止另一套 fan-out 入口 | 有意不开放 |
| 深度/数量/cwd/路由拒绝 | 原生 registry 创建前 guard；Node 负向测试 | 已测机械拒绝 |
| 权限继承 | DSH subagent native delegatedPolicies / parent composition | 原生机制；非 OS 沙箱 |
| 超时 / 进程树回收 | PowerShell 真实子进程 timeout 测试 | 已测；非用户应用 |
| 环境继承 / 网络 | 沿用原 Harness 环境；仅模型请求与原生权限机制 | 不声称网络隔离 |

真实证据的摘要、提交和运行目录见 `VERIFIED_VERSIONS.md` 与 `OPEN_GAPS.md`。
stderr 可能有模型推理，不进入 Reviewer 输入、不复制到仓库。
