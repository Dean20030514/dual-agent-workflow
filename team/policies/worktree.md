# Worktree

分支 `codex/team/<run>/<task>/<role>-a<attempt>`，独立根 `.worktrees/`。
所有独立任务绑定 run_base_sha；依赖任务从最新已验收 integration SHA 启动。
不自动提交调用者工作树、不修改 main。只对 MERGED 且干净、HEAD 未变的 worktree 执行 cleanup。
失败、REVIEW、升级状态保留，集成 worktree 与分支保留交付。无递归 filesystem 删除。
