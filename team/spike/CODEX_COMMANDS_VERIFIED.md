# 已核实的 Codex 命令

```text
codex --version
codex exec --help
codex exec --ephemeral --ignore-user-config -m <lead-model>
  -s read-only -C <review-worktree> --output-schema <review.schema.json>
  -o <out-of-repository-verdict.json> --json -
```

最后的 `-` 从 stdin 读取完整材料。stdout 保存事件；最终 verdict 单独写出。
不会传 `--dangerously-bypass-approvals-and-sandbox`，也不会复用 resume/fork 会话。
schema 的 const 属性仍显式给 type，满足 Codex API 的输出约束。
命令存在与真实网络执行成功分别记录；见 CODEX_CAPABILITY_MATRIX 与 OPEN_GAPS。
