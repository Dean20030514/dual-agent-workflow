# HANDOFF — 9P 计划审落地(2026-08-27,已收敛并合入 main)

> 本档是该任务的完整交接记录,自 `docs/ai/HANDOFF.md` 文首归档而来。Routine 模式执行(纯规则文档);工作过程曾拆 4 个 commit(feat(workflow) 12 文件 / docs(portable) / chore(settings) / docs(handoff),原 SHA `09b4aa8`·`2966800`·`fa56561`·`1d0297c`),后按人类指示 **squash 为单一 commit 合入 main**(原链仅存 reflog)。

## 任务与裁决

起因 = 人类指出 Codex 只在 `/implement` 后介入,define/explore/plan 阶段的错误无独立制衡;结合 2026-08-15 三病诊断(病 2/病 3 的病灶都在计划期、发作在实现后审查,各烧 5–7 轮),人类裁决新增 **9P 计划审**并定为**默认必跑**(非可选)。定义:Critical 正式路径 `/plan` 置 Pending 后、人类批准前,fresh-context **单跑**审查规划文件(五项:TASK_BRIEF 一致性与 AC 可机检性 / 守护声称负向对照 / 架构理解 vs 仓库实况 / 复用遗漏 / 假设挑战);人类可明示减免;快速版天然 N/A;9P blocking 不进 Fix-Loop、不触发硬停;verdict + Author Responses + 减免记录**只放 `docs/ai/review_9P.md`** 随批准 commit 入库。唯一定义处 = `claude/workflow/reviewer-prompt.md` → 9P 节;证据载体第三句入 `claude/workflow/AGENTS.md` → Reviewer-Lightweight Protocol 第二层。改动 13 文件(含 **`codex/AGENTS.md`**——按 2026-08-15 教训动手前先全仓 grep 复述副本、检索面含 codex/)。

## 五轮独立审查(Routine 临时 Reviewer;blocking 轨迹 2→2→3→1→0)

* **r1 不通过(2B+1S)**——B1「互不相知」承诺与 HANDOFF/diff 输入矛盾→**修改后采纳**(采 Reviewer 备选:收窄为可执行防污染边界,不读 verdict 正文 / prompt 不含 9P 内容 / 元数据可见但不作证据;未采严格版 pathspec+字段剥离的理由:新增仪式,且「互不相知」是 Author 措辞非人类裁决原文);B2 常驻规则未贯穿三分证据模型→采纳(AI Collaboration Rules / codex Layer 2 / CLAUDE 原则(6) 等全部分流);S1 三处导航漏改→采纳。
* **r2 不通过(2B+1S)**——B1 续:Work Log 表态与减免理由仍经 HANDOFF 泄露→采纳,9P 全部散文收进 review_9P.md 单文件,「表态记 Work Log」通用规则加 9P 例外;B2 两处 Role「code review only」与 9P 冲突→采纳并同类扫出 `index.md` 第三处一并改;S1 9A 排除句 re-review 歧义→采纳(「不得自行打开文件」≠「不得使用 prompt 内 Author 提供的上一轮 blocking 上下文」,9B 同步限定)。
* **r3 不通过(3B;B2/S1 判闭合)**——① 全量 `git diff base..tip` 会把 review_9*/archive 正文直接送进 9A/9B 输入(既有隐患,9P 使其必然发生)→采纳:正文 diff 机械加 `:(exclude)docs/ai/review_9*.md` `:(exclude)docs/ai/archive/**`(9B 另排除 IMPLEMENTATION_PLAN.md——原「指令性忽略」升级为机械隔离),未过滤 `--name-only` 仅用于快照自检覆盖核验;② `final-review.md` 第 7 条残留「减免记录可写 HANDOFF」旧措辞→采纳,改单一落点;③ 快速版在 HANDOFF 模板产生 review_9P.md 悬空指针→采纳,改三分支。`:(exclude)` 语法已在本仓实测(负向对照:排除 docs/ai/HANDOFF.md 后该文件从 diff 输出消失;完整排除集运行退出码 0)。
* **r4 不通过(1B+2S;人类指示续审至收敛,解除原「不自行开第 4 轮」边界)**——B:`codex/AGENTS.md` Critical 阅读清单第 5 项与 Layer 2 仍强制读**未过滤 full git diff**(r3-B1 在 Codex 常驻规则侧的漏改)→采纳,两处改为「正文只用 review prompt 规定的带排除项 diff」;S1:条目手写行数与实测漂移→采纳,删除手写计数(与 2026-08-15「手写计数」同病);S2:`claude/CLAUDE.md` Discipline points 行「9A/9B contract」→采纳改 9P/9A/9B。
* **r5 通过——已收敛**:r4 三条判闭合,Blocking / Suggestions / Test Coverage Gaps / Cannot Verify From Diff / Verification Needed 全 None、Debt Clean,Reviewer 判「9P 从发起、锚定、落账、防污染到 9A/9B 过滤正文 diff 的路径一致且唯一可执行」「可交人类扫 diff + commit」。
* 五轮 verdict + raw log 曾存仓外 `~/.codex-review-holding/9p-plan-review-landing/`,**已按人类指示清理删除**。

## 收尾三件套(人类指示由 Agent 执行)

* **portable v3.2 整体再生**——按母本重取受影响各节(非逐条补):序节(角色 / 规范矩阵两格 / 核心原则第 6 行)、第三节第 5 条、4.1(层 2 第三句载体 / AI 协作规则 / Fix-Loop 排除 / per-task 清单)、4.5(plan_review_9P 三分支行)、第七节步骤 11、第八节⑤、第九节(头部 / §9.0① 正文 diff 排除 / 9A/9B prompt / 新增 §9.2 = 9P 定义 + prompt)、第十四节、第十五节第 7 条;1142→1204 行,blob `d569fc9e…`。验证 = 带负向对照的机械检查:9P 锚点新版 37 / 旧版 0;9P 载体句恰 2 处逐字一致;`:(exclude)` 命中 3+2;反向丢失抽查 10/10 在场;主节锚点 18 不变;入库 LF。桌面副本已同步且字节级一致。
* **部署**——受管面 10 个变更文件备份(`.bak-20260827-140038`)后精确同步 `~/.claude/` 与 `~/.codex/`,逐文件字节比对通过;全受管面审计发现 1 处**反向漂移**:live `settings.json` 多 `clangd-lsp` 插件启用(人类在客户端启用、快照未跟上)——按快照仓纪律 **live→仓库晋升**,未覆盖人类选择;**终审计 99/99 零漂移**。

## Remaining Risks / Debt

* **唯一遗留(非债,登记备查)**:缺三种场景(9P 落账后首次 9B / 首次 9A / 携带上一轮 blocking 的 9A re-review)的**行为级重放证据**——本轮全部为静态审查;待下一个真实 Critical 任务实测,发现问题回流母本。
* Debt: none。
