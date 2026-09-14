# 9B verdict — dsh-landing review

> **来源与保真度声明（Author 落账，如实标注）**：本轮 Reviewer 把 verdict 作为 **agent 返回正文**交回，`~/.dsh-review-holding/dsh-landing/9B.md` 由 **Author 在双审窗口结束后转录**，**不是 Reviewer 亲手写的原始 artifact**。下方「契约字段」「Blocking Issues」「Non-Blocking Suggestions」「Verification Needed」「Debt Verdict」「Requirement-Level Concerns」为**逐条转录**；Reviewer 的叙述性前言与独立复核摘要作者选择略去（不携带判据）。此次转录本身暴露的协议缺陷见 `docs/ai/HANDOFF.md` → Known Issues。
> 审查对象：`review_base_sha=bf06c65d0831ebeb2b0982f35ae2d7f4c65c2c17` → `review_tip_sha=a361bc1942546484e0edd102cbd789d4dc498c61`

## 证据首行（5 项 Author 核验通过）

```
observed_head_sha: a361bc1942546484e0edd102cbd789d4dc498c61
worktree_clean: yes
read_handoff_from: 不存在（本任务无交接文件）
writes_performed: none
```
覆盖核验：未过滤 `--name-only` 共 29 个文件，全部落在 Author 声明的 `review_sensitive_paths` 内 → **无覆盖缺口**。（附注：Reviewer 报告一次误输入的 `Copy-Item -Path $null -Destination $null`，在参数绑定阶段即失败、未触及任何路径；Author 复核后全树仍为空、无残留，不构成写入。）

## Review Verdict

**不通过**

## Blocking Issues

* **[Product Blocking]** 9P 的推理档 `medium` 在 deepseek-flash 上不存在 —— 默认必跑的 9P 计划审**调用必然被拒**，Critical 流程卡死在计划门。*caused_by_last_fix: no*
* **[Product Blocking]** 备用路径（headless）的调用形态与 `dsh` 真实 CLI 面不符：`-o` 不存在、provider/model/推理档也钉不住。*caused_by_last_fix: no*
* **[Product Blocking]** 9A 让 Reviewer 读的 QUALITY_GATES 换了文档，与同一落地里 8 处"项目副本才是审查对象"直接冲突。*caused_by_last_fix: no*

## Non-Blocking Suggestions（8 条）

1. `DSH-LANDING-NOTES` §1/§2 的"只有这些/逐字一致"与事实不符（含一处真实判据省略：`conflict-hard-stop.md` 收敛门 ③(a) 丢了母本的"收集用例总数 ≥ 快照那次"条件）。
2. 两个执行手册以"技能"之名出现，但按 skill 发现规则永远不可被发现（嵌套 `**/SKILL.md` 不被发现）；SKILL.md 里的引用应改成完整路径。
3. 7 个 phase 副本丢了文件末尾换行（母本均以 LF 结尾）。
4. `dsh/AGENTS.md` 缺两个被判据文件引用的节：`Decision Making` 与可指名的 `Fan-out`。
5. `install.ps1` 顶部 guard 注释与实现不符（注释说按 `phase-` 文件名判定，代码是按目录镜像）。
6. `dsh/**` 里的残留 Claude 侧措辞/笔误（重复词、`sub-agent 继承主对话模型` 尾注与改点 #10 不一致、`AB-model-diagnostic.md` 的"同一 Codex prompt"）。
7. `fanout-toolchain.md:32` 的理由与 `:34` 自相矛盾（本落地 Author 与 Reviewer 同模型，"换模型视角"不成立）。
8. 债账措辞：第 2 笔债在 README 里查不到。

## Test Coverage Gaps

* "派生副本除改点外逐字一致"这条最大风险面，全仓没有任何活的门禁覆盖（`tools/validate/` 是 H5A 封存档，其 `PathReferences.ps1` 也没有 `dsh/` 映射）→ Author 的验证只能是自述，本轮 9B 不得不手工重做 17 对逐字比对。
* `install.ps1` 的 DSH 段没有任何演练/干跑。
* 两个 skill 的"可加载性"只在当前机器被间接证明，没有针对 frontmatter 的机械检查。

## Cannot Verify From Diff

* `dsh --profile headless … -o <file>` 的确切退出码（机制结论有把握，数字需实跑）。
* `medium` 失败发生在工具调用边界还是首次模型请求。
* `~/.dsh/skills` 在人工部署前是否有过其它内容。
* `~/.dsh/workflow/` 是否有过仅存于本机的文件。

## Verification Needed（5 条）

1. 证伪 B1：发一个只回 "OK"、禁工具的 `subagent`，参数取 `provider: deepseek-official` / `model: deepseek-flash` / `reasoning_effort: medium`；预期被拒并含 `UNSUPPORTED_REASONING_EFFORT`。
2. 证伪 B2：`dsh --profile headless --help` 确认只有 `[task...]` 与 `-h`；再追加 `-o x.md` 看是否报未知选项并非零退出。
3. H3 解锁后的安装器实跑（基线哈希 → 一次性 profile/临时 HOME 下带确认开关跑 → 比对 settings/sessions/凭据三项）。
4. Author 修完后重跑：17 对派生文件逐对 diff，每一条变更行与改点清单对齐。
5. 确认 skill 发现面：`references/**` 不进入模型可见目录，且 `disable-model-invocation: true` 在这批文件上是空转的。

## Debt Verdict

**Noted**（三笔债如实登记、格式合规、无"未验证写成已验证"；三笔 trigger 均未触发。提醒：第 1 笔的 trigger 对落地 commit 自身不可满足，建议改成"下一次改动 `dsh/**` 的那一轮必须带独立审查"。）

## Requirement-Level Concerns（4 条）

* **R1**｜"只改怎么跑"这条边界没有机械强制手段（本轮实测出三类清单外变更）。
* **R2**｜verdict 契约缺"模型路由"自证字段；备用路径钉不住档位，两条路径的 verdict 长得一样。
* **R3**｜"deepseek-flash = 当前最强档"目前只有目录/公告层面的支撑，"最强"没有质量证据。
* **R4**｜本轮 `handoff_snapshot_sha == review_tip_sha`，且工作树里躺着一份**上一任务**的 `HANDOFF.md`；母本缺"HANDOFF 存在但不属于本任务"的分支判据。

## Recommended Next Step（转录要点）

先修 B1（不修则 9P 门不可用，档位取值请人类裁决）；再修 B2/B3；顺手收 1–8；修复落在 `review_sensitive_paths` → 必须重跑一轮（9B 先、9A 后，`reasoning_effort` 用 `high`）。
