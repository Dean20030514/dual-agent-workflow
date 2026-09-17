# 已核实的 DSH 命令

```powershell
dsh --version
dsh --profile headless --help
dsh --profile headless --dump-config
dsh --profile headless --patch <run-local-overlay.json> <task-text>
```

最后一个参数用 ProcessStartInfo.ArgumentList 原样传递，不经过 shell 拼接。
stdout 是最终正文；stderr 含进度/推理；headless 无 `-o`、无 `--model`，不接收 stdin task。
输入 Task 与 Result schema 由适配器加入任务文本；退出后再 schema/Git 审计。
patch 是 loader entry 列表，`config` 替换整段而非 deep merge，必须提供 provider/toolName。
headless 默认无 model-selection-settings Host 服务，因此不启用该设置入口，子 Agent 继承父路由。
实际创建的路由另外由 native-guard 核对；settings 与模型 pin 不符时 preflight 拒绝派发。
