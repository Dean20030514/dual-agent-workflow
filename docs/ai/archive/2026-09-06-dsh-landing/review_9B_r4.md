# 9B verdict（第 4 轮）— dsh-landing review

> **来源与保真度声明**：Reviewer 把 verdict 作为 **agent 返回正文**交回；本文件由 **Author 在双审窗口结束后转录**，非 Reviewer 手写原始 artifact。
> 审查对象：`review_base_sha = 34b60370` → `review_tip_sha = fc32899f`

## 证据首行（隔离五项通过）

```
writes_performed: none
observed_head_sha: fc32899f5d6addd0cbafd43ab33fd56c607e9cd3
worktree_clean: yes（git status --porcelain 与 --ignored 均空，无 verdict/raw log 残留）
read_handoff_from: 工作树
model_route: deepseek-flash（自报；provider 与 effort 两项 Reviewer 声明无法自证，请与实发参数逐字比对）
覆盖缺口: 无
```
（Author 注：实发参数 = `provider: deepseek-official` / `model: deepseek-flash` / `reasoning_effort: high`，与本轮 9A 的自报值一致，与 9B 的"仅 model 可见"不矛盾——9B 如实说明了它看不到后两项。）

## Review Verdict

**不通过**（1 条 `[Product Blocking]`，其 `caused_by_last_fix` 标 **`dispute`** → 交人类裁决，**不自动累加 streak**）。

## 上轮 B1 的闭合：Reviewer 自己实跑确认（摘要）

| 检验 | 结果 |
|---|---|
| AC6 正向（钉死 base） | `reg = 30`、`scope = 30`、`missing`/`stale` 均空 → `exit 0`；Author 的"30 == 30"**属实** |
| TASK_BRIEF 是否已登记 | 在表内（NOTES:183）→ 上轮"零命中"已消除 |
| `<base>` 是否钉死 | `BASE_SHA = bf06c65` 且是 HEAD 的祖先 → 红集合可复现 |
| 排除条款 | 旧的"仅补末尾换行的 phase 正文"条款已删除 |
| 机械复制面 | §2.2 五行声明经 `git diff --no-index --numstat` 五对全空验证为真 |
| `dsh/**` 同步 | 23/23 SHA256 全等（本轮 delta 未碰 `dsh/**`） |

**批判性判断（谓词区分力）**：有，但**只有路径级**。纸面反例 H1：在**已登记路径内部**做未登记的内容改动（例：给 `dsh/workflow/index.md` 追加一行未登记进 §2 #9 的判据文本）→ `$scope`/`$reg` 不变 → 仍 `exit 0`，而"改点登记覆盖全部实际变更"已不成立。**Author 的 NC1–NC3 不足以否掉 H1**——三条变异对象全是 §2.3 的 `- path:` 行本身，没有一条从内容侧下手。

## Blocking Issues

### B-1 · [Product Blocking] AC9 判定方式①（"被禁模糊措辞零命中扫描"）没有定义扫描范围，且按最自然范围（交付面全体）读恒红、从未执行

* **具体后果**：同一 tip 会因 scope 选择得出**相反结论**——扫交付面全体得"非零命中 → AC9 未满足"，只扫声明类文档得"零命中 → 满足"。合并门上"AC9 是否满足"因此**不可复现**；照最自然范围办事还会把一个实质满足 AC9 的 tip 判为不满足。这正是"可复现"要件被违反。
* **具体反例（Reviewer 实跑）**：交付面全体扫描 → **10 处命中**：`dsh/workflow/AGENTS.md:114`（禁令词表本身）、`dsh/AGENTS.md:62`、`conflict-hard-stop.md:65`、`phases/final-review.md:67`、`workflow-design-notes.md:8`、`portable/通用prompt-DSH-v1.txt:153`、**`TASK_BRIEF.md:73`（AC9 自身引用被禁措辞表）**、`AUTHORITY_CONTRACT.md:192`（英文时间副词 `later`）、`install.ps1:118`（`manually later:`）。其中 **8 处是"禁令原文引用"** → 任何包含 `TASK_BRIEF.md` 或 `dsh/workflow/AGENTS.md` 的 scope 都不可能零命中。
* **为何按 Product 记**：上轮 B1 的"`<base>` 未定义 → 红集合随 base 变 → 不可复现"已由人类裁决为 Product；本条是**同型缺陷**（判定参数未定义 → 结论随 scope 变），只是落在 AC9。
* **`caused_by_last_fix: dispute`**：按本轮定义（"修的是上轮 B1 或 S-1…S-10 的同一问题"）**不是**同一问题 → 倾向 `no`；按 AGENTS.md 的"**修复引入的** Product Blocking"定义，这段判定正是本轮新写入的 → 倾向 `yes`。**Reviewer 不自行择一，交人类裁决**：裁 `yes` → streak 达 2 → 硬停（回退／重拆任务／架构升级，**不得**改走"限制交付"）；裁 `no` → 本轮 0 计、streak 归 0。
* **Proposed Fix**：给 AC9 判定①钉死 scope 与排除规则并留产物（可复制命令形态已在 verdict 中给出）。**注意**：`TASK_BRIEF.md` 是 Frozen Acceptance 唯一落点，此修改属验收条款修订，**只能经人类裁决 Amendment**。

## Non-Blocking Suggestions（12 条，要点）

* **NS-1**：**AC6 第二条负向对照按字面恒绿、且无产物**——它指向"§2.2 任一模板声明行"，而 §2.2 是 markdown 表（行首 `|`），谓词只认 `^- path:`（全在 §2.3）→ 注册集合不变、判定仍 GREEN；作者的实际 NC1–NC3 全是 §2.3 变异，**本条无反例产物**。含"注"里"同义反复"的错误推理。*（9A 独立命中同一条，见 R4-S1）*
* **NS-2**：`TASK_BRIEF:58`"`dsh/workflow/` 不在 scope 里"**是假的**（scope 的 `dsh` 覆盖它；§2.3 有 11 条 `dsh/workflow/…`；AC6 自己的反例只有在它们在 scope 里时才成立）。
* **NS-3**：**§2.3 不是真标题**（粘在 §2.2 括注行尾）；文中"下表的 `docs/` 行"与"`--check` 方向"都是草稿残留；谓词对**整篇文档**匹配 `^- path:`，未来任何位置出现该行都会静默进入登记表。
* **NS-4**：AC10 写"第 3 轮实测 4 : 4"，与 NOTES 的"3 / 3+2"及实测（各 3 处）矛盾。
* **NS-5**：AC10 的谓词只允许归入"§2/§2.1"，与 AC1 的"或 §1 第 2 步机械路径改写"不一致 → 假红。
* **NS-6**：AC9 判定②"与 `[DEBT]` 清单逐条对应"：两集合**无逐条对应关系**（债 #2/#3/#4 在 §S 里完全没有），且未定义比对方向。
* **NS-7**：S-4 未修——`README:36`、`NOTES:62` 仍写"5 项"，SKILL 实为 6 项。
* **NS-8**：S-6 未修——`install.ps1:97` 的 `and new files are added only when missing` 仍在。
* **NS-9**：S-10 未修——`AUTHORITY_CONTRACT.md:3` 未提整树备份会复制凭据（与 README 披露不一致）。
* **NS-10**：§Q 缺 `tested_sha` 绑定行。
* **NS-11**：§2 #10 把"补末尾换行"列为 phase 归一化之一，但任何一对的 diff 里都没有 EOF 换行变更 → 无法由 diff 证成。
* **NS-12**：谓词区分力上限（H1），见上；建议给 §2.3 每条加内容绑定字段（`numstat` 或 tip blob sha），或**收窄 AC6 的声称**为"路径级覆盖"。

## Test Coverage Gaps

本轮新增/改写的 4 条判定里**只有 AC6 正向有产物**；AC6 第二条反例、AC9①、AC9②、AC9 的反例都无可执行产物。NC1–NC3 只有摘要表，缺命令原文级输出与退出码。`~/.dsh` 23/23 经 Reviewer 复核。AC8、headless 完整轮、真实 9P 审查轮仍未跑。

## Cannot Verify From Diff

人类裁决的发生过程（按契约按人类决定对待，不核实）；`TASK_BRIEF:46` 引用的"第 3 轮 9A 全量核验 40 行"（该 verdict 不在 Reviewer 输入面，它用**自己的** 40 行复核替代，结论一致）；§5 的 17 对逐对对齐；§Q 各条是否真由 Author 执行（无机械手段）；AC6 合并后的生命周期（`BASE_SHA` 是任务前锚点，合并后退化为任务期判据）。

## Verification Needed（6 条）

1. **VN-1（对应 B-1）**：跑 AC9 判定①，**先声明 scope**，贴命令 + 命中行全表 + 退出码 + 一句判读。
2. **VN-2（NS-1）**：把 `TASK_BRIEF:70` 的反例**按字面**跑一次 → Reviewer 的纸面结论是 **GREEN（与 AC 的"必须红"相反）**。
3. **VN-3**：补齐 NC1–NC3 的原始输出 + 退出码。
4. **VN-4**：AC9 的反例（临时写一句"先这样" → 判定①必须红）。
5. **VN-5**：AC4 的字面命令 + 退出码产物（承上轮）。
6. **VN-6**：展示 `last_test_run §S` 与 NOTES §3 的对应关系，或按 NS-6 改写该判定。

## Debt Verdict

**Unpaid**。债 #1（第 4 轮 delta 待重审）：**9B 已跑（本 verdict），但 9A 尚未跑** → 只偿还一半，`/final-review` 在 9A 落账前不得判"可以提交"。债 #2/#3 未触碰（Noted）。债 #4 已按人类裁决记为已偿还、残余行为已披露，披露缺口见 NS-9。另：若人类把 NS-12 列为"不修"，**请登记成一笔带 Payback trigger 的 `[DEBT]`**（trigger：下次改动 §2.3/AC6 之前），不要留在措辞里。

## Recommended Next Step

1. **人类先裁一件**：B-1 的归类与归因（Product 还是 Suggestion；`caused_by_last_fix` 是 `yes` 还是 `no`）——这决定 streak 是 2（硬停）还是 0，也决定合并门是否解锁。**裁决前不要继续改文件、不要标任何"已收敛"。**
2. 裁决后由 Author 用**一批 Amendment** 修 AC 文本 + 改 `README:36`/`NOTES:62`/`AUTHORITY_CONTRACT:3`/`install.ps1:97` + 补 §Q 的 `tested_sha` 与 NC 原始产物，并逐条代跑 VN-1…VN-6。
3. **再跑 9A**（与 9B 同一 tip）：只有 9A 落账后债 #1 才算偿还完毕。
4. 轮次账：**本轮是第 4 轮**（上限 3，本轮出自人类"修完再跑一轮"的逐次批准）。9A 落账后按"轮次上限"条款只能由人类在限制交付／重新拆任务／回退三者中裁决；"限制交付"仅限"零未解决 Product Blocking"。
5. 收敛门前：不得标"已收敛／Ready to Commit"；`caused_by_last_fix` 须**逐字转录**（含 B-1 的 `dispute`）。

## Requirement-Level Concerns（6 条，要点）

1. **三轮的 finding 全部落在"登记表 + 验收条款"层，而本轮的修复又在这同一层新增了新的不可执行判定**——建议**停止扩张机械装置**：把 AC6 的登记谓词（唯一双向机读门）与 §1 第 4 步的逐对 diff（唯一内容级证据）定为两个机械门，其余 AC 判定要么写成命令、要么**收窄声称**。
2. **头号风险（`dsh/` 相对母本的判据漂移）至今没有机械门**（AC1 只覆盖 1 对，AC10 是散文归属判定）。
3. **AC6 是任务期判据**，合并后不再表达"本次交付面"，应在合并时标注失效时点。
4. **验收条款的"可判定性"缺一条成文判准**：同一 AC6 缺陷，9A 判 Suggestion、9B 判 Product，需人类裁决才定案；本轮 B-1 又落进同一分歧。建议在 `AGENTS.md` 的"验收条款必须可复现判定"节补一句默认归类（建议：**判定参数未定义/结论随参数变 = Product；判定能给出确定结论、只是与实际覆盖范围不符 = Suggestion**）。
5. **§2.3 是本轮真正的进步**（实跑确认有区分力、可复现），但注意其维护成本：**scope 里新增任何文件都会让 AC6 立刻变红直到补登记**——这是设计意图，应在 AC6 里写明，避免下一轮误读成回归。
6. **`AUTHORITY_CONTRACT` 与 `README` 对整树备份的披露不一致**（NS-9）——第 3 轮"偿还"只收了 README 一处，同笔债的披露应成组修改。
