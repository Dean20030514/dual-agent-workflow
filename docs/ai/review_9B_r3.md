# 9B verdict（第 3 轮）— dsh-landing review

> **来源与保真度声明**：Reviewer 把 verdict 作为 **agent 返回正文**交回；本文件由 **Author 在双审窗口结束后转录**，非 Reviewer 手写原始 artifact。
> 审查对象：`review_base_sha = 7084fb75` → `review_tip_sha = 34b60370`

## 证据首行（隔离五项通过）

```
observed_head_sha: 34b60370fdac02b3d2670a0058b729bc99a7589f
worktree_clean: yes
read_handoff_from: 工作树
model_route: deepseek-official/deepseek-flash@high（自报值、非证据：本会话系统提示只声明 "deepseek-flash"，reasoning_effort 在本侧不可见）
writes_performed: none
覆盖缺口: 无（15 项逐项落在清单内；4 项过程产物（HANDOFF×2、last_test_run、review_9{A,B}_r2）不属必含类别）
```
**完整性披露**：Reviewer 用 `git grep` 做全仓检索时命中并回显了 `docs/ai/review_9A.md` 与 `review_9A_r2.md` 的 3 行文本；它声明**未打开**这两个文件、未将其内容作为审查输入，且为免污染未再检索该类文件。**Author 注**：这仍是一次**边缘接触**（机械检索回显了另一 Reviewer 的输出），虽未进入推理，按双审隔离的严格口径应记在案——本轮不再重跑，如实登记供人类判断。

## Review Verdict

**不通过**（1 条 `[Product Blocking]`）。`caused_by_last_fix: yes` → **streak = 1**。

## Blocking Issues

### B1 · AC6（经人类接受的 Amendment 版）在 `review_tip_sha` 上是红的，且其排除条款建立在错误事实上

`caused_by_last_fix: yes`

**具体后果**：AC6 指定的复核动作 = "人类在合并前按 §2/§2.1 核对交付面已全部登记"。执行该动作的人会得到"登记完整"的结论，而**验收基线文件本身在本轮被改写（AC4/AC6 重写、AC1 降级）这件事不在登记表里**——即 AC6 要防的那类漏登恰好发生了，且发生在验收标准自己身上。同时 `<base>` 未定义使结论随基准而变，复核者无法复现一个确定的红/绿。

**具体反例（实跑，两种合理 base 都红）**：
* `docs/ai/TASK_BRIEF.md` 在 `DSH-LANDING-NOTES.md` 全文**零命中**，而 AC6 的判定范围逐字包含它。
* `base=a361bc19` → 19 项，未登记 = `docs/ai/TASK_BRIEF.md`。
* `base=bf06c65` → 29 项，未登记者再增 `dsh/workflow/templates/{HANDOFF,IMPLEMENTATION_PLAN,PRODUCT_BRIEF,TASK_BRIEF}.md` 与 `dsh/workflow/AB-model-diagnostic.md`。
* 排除条款写"仅补末尾换行的 phase 正文"，实测：`explore.md` 2 增 0 删（只有 frontmatter 两行，**根本没有末尾换行改动**）、`define.md` 4 增 2 删（frontmatter + 两处路径改写）、`design-check.md` 3 增 1 删（frontmatter + 一处路径改写）。

**Proposed Fix**：路线 A（收紧 AC，推荐）——AC6 钉死 `<base>` 为字面 SHA；判定谓词改为"每一项都能在 §2/§2.1 找到，**或**属 §1 机械复制面（在 §2.1 列出 templates 与 AB-model-diagnostic）"；排除条款改为真实描述。路线 B（补登记）——§2.1 增设 `docs/ai/TASK_BRIEF.md` 一行 + §2 第 10 条补记路径改写。二者都须重跑 AC6 判定并把原始命令 + 输出 + 退出码落 `last_test_run.txt`。

## Non-Blocking Suggestions（10 条，全部 `Proposed Fix` 一行可执行）

1. **S-1｜HANDOFF 与 tip 自相矛盾**（`yes`）：`Known Issues` 仍写"9B-S1 未修…本轮未改"、`Work Log` 无 `34b6037` 的改动集、`Remaining Risks` 第 4 笔仍写"未偿还…未改 README 措辞"。**Fix**：落账时按 tip 重写。
2. **S-2｜`last_test_run.txt` 未绑本轮 tip + §K/§L 时点不实**（`yes`）：`tested_sha` 仍 `7084fb75`；而 Reviewer 实测 `~/.dsh` vs 仓内 **23 SAME / 0 DIFF**（含 `34b6037` 才改的 6 个文件）→ §L"第 3 轮 delta 未再同步"**方向相反**。**Fix**：追加 §M 绑 tip，重抄 AC4 判定与再同步结果，改掉 §K/§L。
3. **S-3｜README 快照节过期 + 同族笔数矛盾**（`yes`）：`README:54` 写"未经审查""三笔"，与 `README:17` 新增的"已登记为 `[DEBT]`"（第 4 笔）冲突。**Fix**：改为"已跑两轮（首轮不过、第 2 轮有条件通过），第 3 轮 delta 在审；债四笔"。
4. **S-4｜"5 项"计数两处未同步**（`yes`）：`README:36`、`DSH-LANDING-NOTES:62` 仍写 5 项，`independent-review/SKILL.md:44` 已改 6 项。**Fix**：两处改 6。
5. **S-5｜§2 第 10 条括注事实前提不成立**（`yes`）：见 B1 反例 ②。**Fix**：同 B1 路线 A 的 ③。
6. **S-6｜`install.ps1` 同一句不实注释只删了一半**（`yes`）：`:19` 已删，`:97` 的 `and new files are added only when missing.` **仍在**，而代码只镜像 `dsh/skills/*` 目录、无"缺失才补"分支。**Fix**：删该 clause。
7. **S-7｜AC1 降级理由写错对象、且降级无 Payback trigger**（`yes`）：AC1 的判定对象是**单文件对**（`dsh/workflow/AGENTS.md` ↔ 母本），"17 对 / 2600+ 行"属 §1 第 4 步与 AC10。Reviewer **逐行读完全部 40 行变更**：每一条都落在 §2 第 1–6 条或 §1 第 2 步，**Fix-Loop 阈值/轮次/判据一字未动 → AC1 实质满足**。而 "Known Limitation" 不是本工作流承认的形态（No-Hidden-Debt 只给两条出口），`DSH-LANDING-NOTES:83` 自己写着"没有第三种状态"。**Fix**：AC1 改回可判定并给出本轮结论；或对 AC10 首句立 `[DEBT]` + 触发器。
8. **S-8｜`README:17` 首句自相矛盾**（`yes`）："脚本只读写受管路径" + 同句"但会整树备份"——代码还会写 `*.bak-<stamp>` 与 `New-Item` 建 `~/.dsh`。**Fix**：改为"只**修改/删除**受管路径（另会写出备份副本）"。
9. **S-9｜债台账未反映"偿还"动作**（`yes`）：`DSH-LANDING-NOTES:80/83` 仍写债 #4"与 README 措辞不一致"（该措辞已不存在）、仍"四笔"且无偿还记录；`HANDOFF:67/69` 同病；债 #1 文本"尚余第 2 轮"已过期。**Fix**：按 S-9 逐条改写，**不要静默删条目**（复制行为仍在）。
10. **S-10｜`AUTHORITY_CONTRACT.md` 未提整树备份副作用**（`no`）：不矛盾但不完整。**Fix**：补半句。

## Test Coverage Gaps

1. 无功能测试套件，全部证据为机制核验。
2. **AC4 的负向对照产物是转述**（§I 的命令是伪码、无字面命令/退出码）——Reviewer 独立复现了正向判定（适配器 `"medium"` 0 命中、DSH 面取值 = `{high}`），但"有区分力"在产物层面无支撑。
3. **AC6 的附加判定从未被机械执行过**（§E 只给 numstat 表，无"每条变更行归到哪条改点"的映射）。
4. **`settings.yaml` 的 `reasoningEffort` 效果的负向对照不存在**。
5. 安装器爆炸半径零覆盖（guard 锁定）。

## Cannot Verify From Diff

* 两份第 2 轮 verdict 原件（按规则不读）；`writes_performed` 的真实性；§H/§J 是否真被执行（无 session id/时间戳/stderr）；AC10 首句的"全部 17 对"残余面；`~/.dsh/settings.yaml` 内容（**故意不读**，避免回显凭据）；`install.ps1` 运行行为；本轮再同步的时点。

## Verification Needed（8 条；摘要）

VN-1 AC4 原始产物（字面命令 + 退出码 + 变异/还原）；VN-2 真实 9P 审查轮（非探针）；VN-3 `settings.yaml` 推理档真能生效；VN-4 AC6 判定重跑；VN-5 AC8 临时 HOME 实跑；VN-6 `~/.dsh` 同步时点落账；VN-7 headless 完整审查轮；VN-8 本轮 `model_route` 与实发参数并列留档。

## Debt Verdict

**按实质 = Paid，按台账 = Unpaid。** 第 4 笔债：人类选的路线（收窄 README 措辞）**确实执行了**，且 Reviewer 逐句核对**未发现反向过度声称**（范围写的是"整个 `~/.dsh`"，与 `install.ps1:81` 一致）；但 `DSH-LANDING-NOTES:80/83` 与 `HANDOFF:67/69` 仍记为未偿（S-9）。第 1 笔文本过期；第 2 笔保留（触发器仍在）；第 3 笔未偿还且本轮又人工同步一次未落账。

## Requirement-Level Concerns（5 条）

1. **改点登记表与本任务的核心承诺绑定过深，而它自己就是最脆的一环**：三轮下来每轮的主要 finding 都出在**账/措辞层**，而不是判据层。逐行核过的实质面（`AGENTS.md` 40 行 vs 母本、AC4 取值域、AC10 指针、S1 的两层事实）**都成立**。建议人类明确：登记表是"审查输入"还是"合并门"？若要当门，就必须有钉死的范围 + 字面命令 + 负向对照。
2. **"用 Known Limitation 掩盖未满足"不成立，但替代风险成立**：AC1 实质满足，问题是**降级理由张冠李戴**且降级无偿还触发器——恰成本工作流明文否认的"第三种状态"。
3. **同模型双审的独立性只剩上下文隔离这一层，本轮再次被证实是"纸面第二层保险"**：`model_route` 是自报值，连 Reviewer 都无法自证档位（§H 的返回即明证）。
4. **部署面是人工同步的，而它是"本机生效"的那一份**：本轮实测 `~/.dsh` == tip，但这次同步**没落账**、也无机械保证下次跟上。合并前值得明确：**改完仓内 `dsh/**` 后由谁、何时、用什么命令同步**。
5. **在"验收标准可被 Author 事后改写"的既定事实下，人类对 AC 的每次 Amendment 都应附"哪个 AC 的哪句话被改、由谁裁"的两行记录**——本轮 Amendment 记录里恰恰缺"AC1 的降级理由对象写错了"这一自我更正。
