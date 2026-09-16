# review_9P.md — 切片 B 计划审（9P，round 1）

> 本文件逐字转录 Reviewer 返回正文，Author 未改写。Author 的逐条表态在下一轮修订时一并落在此文件。

**审前状态**：`observed_head_sha = 8350caac121f57bb9ade7df05d7ab1e3a088f4f9`（== 要求值）· `worktree_clean = yes` · `model_route = deepseek-official/deepseek-flash@high`（自报）· `writes_performed: none`
**审查对象**：`docs/ai/TASK_BRIEF.md`（切片 B 草案）、`docs/ai/IMPLEMENTATION_PLAN.md`（草案）、`docs/ai/BACKLOG_sliceB.md`、`docs/ai/HANDOFF.md`、`install.ps1` 与 `tests/**` 的可行性判断。

## Plan Verdict

**不批准**。核心理由：本计划的批准门要求在**输出契约、执行集合语义、退出码契约尚未冻结**的状态下放行"第一次真删文件"的写入路径（`IMPLEMENTATION_PLAN.md:71-75` 的 U1–U3 仍是"进实现前才有答案"），而 AC1–AC6 里至少 2 条恒真/不可判、1 条当前不可判。方向正确（同源 `$Plan` 执行器 + 备份先于写入），但不满足"够安全、够可判"。

## Blocking Plan Gaps

1. **U1 未决 ⇒ 执行语义与退出码未冻结**（`IMPLEMENTATION_PLAN.md:73`、`:30`）。后果：D5/AC5/`Show-Summary`（`install.ps1:513-530`）的成败语义悬空，写路径无法验收。该改：把 U1 提入 §5 步骤 1，作为 AC 冻结的一部分，答案写进 AC 文本而非留白。
2. **U3+D5 组合制造"静默跳过插件却报成功"**（`:20`、`:47`）。后果：`[PLAN] plugin` 动作永不执行，但路径返回 `RESULT=OK` ⇒ AC4 的"计划==执行"被自证违反，且首次真部署被读成"已部署完成"。该改：AC4 显式豁免 plugin 行 **且** 汇总必须写 `plugin step: NOT IMPLEMENTED` 并规定该路径**不得**返回 OK。
3. **AC1 与 D2 范围分歧 ⇒ 恒真/不可判**（`TASK_BRIEF.md:25` vs `IMPLEMENTATION_PLAN.md:17`）。后果：AC1 说"每个已存在目标都备份"，D2 只备份"将被覆盖或删除"的；`config.toml` 已存在时属 seed-only（`install.ps1:330-336`、测试样本 `TestHelpers.ps1:167-170`），备份断言必失败。该改：AC1 与 D2 用同一措辞，并点名 seed 目标的规则。
4. **AC2 的执行期硬校验没有任何实现落点**（`TASK_BRIEF.md:26`；`IMPLEMENTATION_PLAN.md:25-30` 逐文件改动里无此项）。后果：计划里的"分区不变式"实现在**读侧** `Get-MirrorDelta`（`install.ps1:230-258`），但真正删文件的是**计划缺失的 `Invoke-MirrorAction`**；若该函数不消费 `DeleteFiles` 而是自算，AC2 在计划侧全绿、在磁盘上真删。该改：写明不变式的执行期实现位置 + 执行前中止测试。
5. **AC4 不可判 + 证伪力自指**（`TASK_BRIEF.md:28`、`IMPLEMENTATION_PLAN.md:16`、`:69`）。后果：B-5 被推给 U2，而"独立预言机"是同一棵源树的文件数 ⇒ 自指，无法证伪；"实际被删集合"无观测方法。该改：冻结 D1 粒度 + 定义实际集合的捕获方式 + 反例（计划与实际故意不一致须被拦）。
6. **AC6 是目前唯一不可判条款**（`TASK_BRIEF.md:30`）。后果：纯过程陈述、无产物、实现期禁用真实 home ⇒ 永不可验。该改：要么产物化（人工复核 dry-run 全量输出留仓内指针）+ 批准 commit，要么移出冻结 AC 明确标为人工门。
7. **R-3 未决涉及写入保护范围**（`BACKLOG_sliceB.md:25`）。后果：机器态谓词锚 `$env:USERPROFILE`（`install.ps1:475`）与报告锚（生效根，`:575/:586`）不同源；重定向 `-ClaudeDir` 而 HOME 未重定向时，备份/保护范围与判定谓词可能不同源。该改：开工前冻结"护真机 vs 护本次生效根"。

## Required Changes Before Approval

1. U1–U3 移出 §7，作为 §5 步骤 1 的一部分在**批准前**定稿；冻结后任何改动按 `TASK_BRIEF.md:45` 第 4 条（人类批准 + 声明本轮作废）执行——不得在实现阶段以"决断"名义改契约。
2. AC4 增补：实际集合捕获方法、负向对照、TOCTOU（`Show-Plan` 与执行之间 live 树变化）的 re-validate 规则。
3. AC2 增补执行期实现点与"任何真实删除都必须来自 `$Plan` 行"的机械断言。
4. 恢复演练（`:68` 第 5 条）升格进**冻结 AC**，并补三项：备份自身完整性（半写检测）、中断点回滚（执行中途杀进程）、D4 打印命令的字面可执行性。
5. termination 规则补两条：作废轮是否占 3 轮配额（防 `TASK_BRIEF.md:45`+`:47` 组合无限续命，这正是切片 A 五轮的成因）；争议裁定人（无人裁定时 Author 不能以 `disputed` 结案）。
6. B-3 用只读方式先复现（临时 HOME + 现有 `-DryRun`）并把结论写进计划；B-6/B-7 在计划里落成具体断言/DryRun 语义条款，而不是只在 BACKLOG 里。
7. `-ClaudeDir ''`（D6，`install.ps1:145`）需要一个冻结条款 + 用例（含 `$null`，见 `BACKLOG_sliceB.md:43` T-11）；仅"计划里这么做"不进 AC 就不可判。

## Non-Blocking Suggestions

1. 备份命名 `<name>.bak-<stamp>` 无唯一性保证（同秒两次运行、大小写变体目标）建议改 `<name>.bak-<stamp>-<short guid>` 或写明"存在即在该秒内 FAIL"，并落成 AC1 子项。
2. 长路径/UNC/符号链接：`Resolve-TargetDirectory`（`:143-147`）不做校验，建议 `Test-Plan` 增"根在本地卷 + 长度可写"检查；当前用例都在浅 `$env:TEMP` 下，风险不可见。
3. `Test-Plan` 缺"同一目标被两条动作命中"的互斥检查（root 碰撞已有 `:444-455`，但 mirror 目录内部与文件动作的祖先-后代关系未查）。
4. `$Plan` 的 `Files`/`Dirs` 计数在测试侧抽样交叉核对可保留，但不应被当成 AC4 的预言机（自指）。
5. §2 R-4 的 `planned` 语义（`BACKLOG_sliceB.md:26`）随 D1 一并写进输出契约，否则下游会读成文件数。
6. §2 R-1/R-2 是切片 A 验收措辞的欠账，与本次写入安全性无关，可随切片 B 文本一并改准，不必单独前置。
7. `[PLAN]` 行 `planned` 与 `[DELETE]` 行数的"行级交叉核对"已由 `install.Validate.Tests.ps1:93` 覆盖 delete 面，建议 copy/seed 面照抄同型断言。

## Cannot Verify From Plan

1. **`Invoke-MirrorAction` 是否真的只消费 `$Plan` 的 `[DELETE]` 行**：该函数在本快照根本不存在（`install.ps1:510-511` 明确"deliberately absent"），计划只给函数名（`:26`）不给契约；AC2/AC4 的安全声称此刻全部落在这个未写的函数上。
2. **备份是否会被当成 live-only 删掉**：`<name>.bak-*` 目标是 sibling，不在任何 mirror 根的枚举范围内，风险较低；但目标树内既有 `*.bak-*`（`install.ps1:139`、`:217-242`）在**执行期**是否跳过，计划未写。
3. workspace 债务陈述与实测是否一致（`HANDOFF.md:39` 的核验命令、`:50-53` 的 `[DEBT]` 笔数）：未运行该命令（计划审不需要）。
4. `~/.dsh` 债的落账规范与首次真部署 runbook：属切片 D / 人类动作。

## Verification Needed

1. Author 代跑一次**只读**复现：临时 HOME + 源树自带 `archive/` 与 `*.bak-*` 时 `-DryRun` 的 `[DELETE]` 集合（B-3 的裁决输入）。
2. Author 代跑现壳的递归删除危险探针：对含白名单子树的临时目录调用 `Remove-Item -Recurse`，记录它是否**递归吞掉** `archive/`/`*.bak-*` 子树——这决定执行期必须逐条删还是可整目录删。
3. Author 代跑：备份目标为 sibling 时，第二次同秒运行是否覆盖首个备份（唯一性验证）。
4. 批准前由人类确认 AC 冻结文本（尤其 AC1/AC2/AC4/AC6 的 4 处改准），并明确"本轮 9P verdict 是否随之作废"。

## Debt Verdict

`Unpaid`，且本切片**新增 3 笔计划期债**：① 执行期分区不变式无实现落点（Gap 4，若按现计划落地即成为暗债）；② 插件步空实现 + OK 退出的语义债（Gap 2）；③ AC6 无产物的"人工门"债。承接面：`HANDOFF.md:53` 的 install.ps1 死代码 5 处 trigger = "下一次改动 install.ps1 之前" ⇒ **本切片开工前必须清偿或重新登记**；`HANDOFF.md:52` 的 A3/skills 常量自指债 trigger 与"切片 B 落地 skill 枚举"直接匹配 ⇒ 同步处理。`HANDOFF.md:50` 的 `~/.dsh` 运行副本无备份债在本切片偿还之前仍为 `Unpaid`。

## Recommended Next Step

1. **冻结前**：Author 在计划内一次性完成 4 件事——U1–U3 定稿、AC1/AC2/AC4/AC6 四处改准、B-1/B-2/B-3 落成条款与用例、恢复演练升格进 AC。
2. 同步修订终止规则（作废轮配额 + 争议裁定人），否则切片 A 的"五轮不收敛"会以"作废续命"的形式重演。
3. 上述完成后再发**第二轮 9P**（同一份计划文本，Author 逐条 Response），通过后再由人类填 `Human Approval Status: Approved`。
4. 清偿/重登记 install.ps1 死代码债（trigger 已触发），再进 `/implement`；首次真部署按 AC6 由人类执行，agent 全程不得对真实 home 运行安装器。

---

## round 2 — review_tip_sha（规划文本）`e9ed321d82d47162ecdca33c8fad2b710b9f6b79`

**判定：不批准**。修订确有三处真实进步（AC2 执行期落点、AC4 ②③④、AC6/AC8 拆分），但候选冻结文本里仍存在 3 处**自相矛盾**（U1×AC5、U2×A3 测试、U3 未择一×AC6/AC8），Round 1 的 7 条 Gap 中 4 条实质未闭，且一条已触发的债闸门无落点。方向不坏，缺口可在一轮内闭合。

`observed_head_sha = e9ed321…`（== 要求值）· `worktree_clean = yes` · `writes_performed: none`

### Round 1 对账

- **Gap1（U1 未决）→ 未闭**：`IMPLEMENTATION_PLAN.md:73` 定「REFUSED 退役」，同文件 `:30` 仍留「按 D5 保留 REFUSED？**待确认**」——退出码契约仍带问号。
- **Gap2（插件步静默成功）→ 未闭 + 新引入**：`:75` 只写「二者择一写死」而**没有择一**；分支一自毁：plugin 动作**恒在**计划内（`install.ps1:194-196`），故「有 plugin 动作即 FAILED」使部署永不 OK，`TASK_BRIEF.md:30`(AC6①)、`:32`(AC8) 随之不可达。
- **Gap3（AC1 vs D2）→ 已闭（措辞层）**；残留见 Required-6。
- **Gap4（AC2 执行期落点）→ 已闭**。
- **Gap5（AC4 不可判/自指）→ 部分未闭**：① 的「执行器输出的实际处理清单」是**执行器自报**，D1 的「独立预言机」全文未定义 ⇒ round 1 点名的「实际集合捕获方式」仍自指。
- **Gap6（AC6 不可判）→ 已闭（文本层）**；但 `:45`、`:56` 仍把首次真部署写作「AC6」——交叉引用腐坏。
- **Gap7（R-3/D7）→ 未闭**：降为「批准门一并定」，但冻结步骤只列 D1–D6 + AC1–AC6，D7 与 AC7/AC8 不在清单内 ⇒ AC3 保护范围仍不可判。
- **Req1 → 未闭**：§7 已定稿但 §5 步骤 1 未同步；`:4-5` 仍写「AC1–AC6 待冻结」「终止规则…六条」，实为 AC1–AC8 + 8 条。
- **Req2 → 已闭** · **Req3 → 已闭** · **Req4 → 已闭** · **Req5 → 已闭**。
- **Req6 → 部分未闭**：B-3 已实跑（§8 PROBE-A，自承 `*.bak-*` 目录形态样本未取到）；**B-7（DryRun 语义/形状警告）在 brief 与 §6 测试计划里都无落点**。
- **Req7 → 已闭 + 新引入**：AC7 只点名 `-ClaudeDir`，而回落机制对三个根同型（`install.ps1:143-147`）。
- **NB-1 → 已闭（残留）**：AC1③ 仍是**未择一的析取**；D2(`:17`) 命名仍为 `<name>.bak-<stamp>`，与 AC1 的 `-<guid6>` 和 PROBE-C 结论不一致，而 AC1 又自称「必须与 D2 完全一致」。

### Still Blocking

- **B1 U1×AC5（证伪已落地冻结断言）**：`TASK_BRIEF.md:29` 要求 46 条全绿并点名 K1–K9；U1 直接使 3 条假：`tests/install.Parameters.Tests.ps1:133-140`（K1a，含零写入断言 `:139`）、`:142-152`（K1b）、`tests/install.Host51.Tests.ps1:48-54`。**U1 的「切片 A 轮次不必作废」打的是错靶：争点不是轮次，而是 Amendment ㉗/K1 的已落地冻结断言被 U1 证伪**（该 Describe 标题即 `:125`）。
- **B2 U3 未择一，且读到分支一即与 AC6/AC8 互斥**（`install.ps1:194-196`）。必须在文本里写死分支二。
- **B3 U2/D1 从严×AC5/A3**：`:74` 改 `[PLAN]` 行形状却称「切片 A 已冻结的 `[PLAN]` 契约不回溯修改」；该契约不只活在文本里，而由**活测试**钉住：`tests/install.Plan.Tests.ps1:132-178` 以 `StartsWith('[PLAN]')`(`:154`) + `-> 目标`(`:157`) 做集合相等，`[PLAN]` 逐文件化后必红，而 AC5 要求它保持全绿。
- **B4 债闸门无落点**：`:99-100` 把**已触发**的 install.ps1 死代码债落点写成「§5 步骤 0」，但 §5 只有步骤 1–6。

### Required Before Approval

1. **U1**：AC5 改为「43 条不动 + K1a/K1b/5.1 refusal sample 三条按 U1 改写（逐条列旧/新断言）」，并在 brief 落一条「㉗/K1 由切片 B 取代」的可核账目；同时删 `:30` 的「待确认」，写死 0=OK / 1=FAILED / 插件降级码。
2. **U3**：写死**分支二**——AC4① 明示 plugin 行不计入「计划==执行」，新增冻结条款定义「部署完成但插件步 NOT IMPLEMENTED」的 RESULT token 与退出码（不得 OK，也不得 FAILED）；AC8 runbook 注明本切片跳过插件步。
3. **U2/D1**：二选一写进 AC4 ——(a) `[PLAN]` 行形状**不变**，逐文件明细走新 tag（`[COPY]`/`[SEED]`，不被 A3 的 `[PLAN]` 过滤器看见）；或 (b) 明写 A3 断言改写并与第 1 条共用取代账目。**推荐 (a)**。
4. **AC4①/②**：把「实际处理清单」定义为**磁盘观测**（临时 HOME 前后签名差），并定义 D1 的「独立预言机」；AC4② 指明注入检测机制（计划封存/哈希）。
5. **引用改准**：`:45`、`:56` 的「AC6＝首次真部署」→ AC8；`:4-5` 与 `:51` 的冻结清单补 D7 + AC7/AC8，终止规则写成 8 条。
6. **AC1/D2 一致**：D2 命名改为 `<name>.bak-<stamp>-<guid6>` + 布局校验，AC1③ 真择一（建议 guid 唯一性）。
7. **AC7 扩到三个根**（`$CodexDir`/`$DshDir` 同型回落）。
8. **债闸门**：§5 步骤 0 实写（清偿或带 trigger 重新登记），或明确移出本切片并说明为何不阻塞「改动 install.ps1」。

### Non-Blocking

- §8 PROBE-A 自承的 `*.bak-*` **目录**形态源树样本缺失 —— 补样本（可并入实现期第一条用例）。
- NB-2/NB-3 表态「accepted → §3」，但 §3 无对应条目；落点补进 §3/§6。
- `TASK_BRIEF.md:23` 的修订说明漏列 Gap 2（U3）。
- §5 步骤 6 把插件债与 `~/.dsh` 债并成一条；分列更可核。

### Debt Verdict

`Unpaid`（同 round 1）。install.ps1 死代码债 trigger **已触发**且落点悬空（B4）⇒ 不满足「开工前清偿或重新登记」；A3/skills 常量自指债 trigger 未触发，但 `:100` 声明清偿而同样无落点；`~/.dsh` 首次真部署债在人类执行 AC8 前仍 Unpaid。

### Recommended Next Step

1. Author 按 Required-1..8 一次性改 brief+plan（**先不动代码**）；AC 尚未冻结，本轮修订不构成「作废轮」，但一旦冻结后任何改动即按终止规则第 4 条占配额。
2. 若选择「U1 取代 K1/㉗」，把取代账目写成 brief 内可核条目交人类在批准门确认；**不要**用「切片 B 是新任务、自有验收」这一理由绕过 B1。
3. D7 建议直接采纳「有效三根 ∪ 真实 home」写进 AC3 文本 + Test-Plan 改动点，不再留白。
4. 修订后再发 round 3（同一份文本 + 逐条 Response）；人类在批准门需同时确认「46 条改为 43+3」是否仍满足切片 A 收敛不被回溯的记账。

---

## round 3 — 规划文本 `9b125aa`（Author 自算锚定：HEAD `5892589` / brief blob `77507825` / plan blob `ab5e584e`；`writes_performed: none`）

> 本文件逐字转录 Reviewer 返回正文（含其证据头与全部小节），Author 未改写。Author 的逐条表态附在本轮末尾的 **Author Responses** 节。

```
# 9P Plan Review — 切片 B（真实写入路径）

9P_round: 3
observed_head_sha: 5892589f6b7c8c32ad1deafbd17813694c6da1e5
task_brief_blob_sha: 7750782501a437ab0a0fefe525a780084ab8b7da
plan_blob_sha: ab5e584e7e5a32ea8301f03982af06e37e4fa5b2
writes_performed: none
model_route: deepseek-official/deepseek-flash@high

---

## Plan Verdict            修订后可批准

三行锚定与 Author 自报逐字一致；工作树干净（`git status --porcelain` 空）；未打开 `docs/ai/archive/**`、未打开 `docs/ai/review_9P.md`（遵守 Reviewer 禁读面），未执行任何测试或写入。

**上一轮 blocking 闭合核验（先做）**：B1 ✅（AC5 三条改写逐条列旧/新 + 取代账目含归档指针与替代保护清单，与 `tests/install.Parameters.Tests.ps1:133-140`/`:142-152`、`tests/install.Host51.Tests.ps1:48-54` 实际文本对得上）· B2 ✅（§7 U3 写死分支二 + AC9，且 AC9 的"Deploy 永不 OK"与 AC4③ 豁免 plugin 行互不矛盾）· B3 ✅（D1 取方案 (a)；已核 `install.Plan.Tests.ps1:154` 的 `StartsWith('[PLAN]')` 与 `:157/:162` 的 `-> ` / `keep ` 正则确实看不见 `[COPY]`/`[SEED]`，43 条与 A3 集合相等断言无需动）· B4 ✅（§5 步骤 0 实写，含 `Select-String` 证据要求）。Required-1/2/3/5/6/7/8 全部落点可核（AC5② / AC9 / D1+§7U2 / 头部+§5+§7 / AC1③④+D2 / AC7+D6 / §5 步骤 0）；4 条 Non-Blocking 全部落点可核。**Required-4 只完成一半**（见下 B4）。

---

## Blocking Issues

### B1（新）`[COPY]` 的内容条件定义与 `[SEAL]` 的跨模式相等要求互相矛盾

* **证据**：AC4 D1/③ 把 `[COPY] <target>` 定义成"**将被创建或内容变化**的受管文件"；AC4② 要求 seal 覆盖全部计划行，且 `-DryRun` 与真部署**必须得到同一 seal**。两者不能同时成立：`-DryRun` 与真部署跑在**同一个 live 树**上（AC4⑥ 的 TOCTOU 前提、AC8 的人类流程都要求如此），因此先跑的 `-DryRun` 打印的是"会变的文件"，真部署在写完之后的 `Show-Plan` 打印的是"已经一致、不会再变"的集合——`[COPY]` 行集不同 ⇒ 行文本不同 ⇒ sha256 不同。
* **按此计划执行会失败的具体后果**：AC4 判定② 与 §6 用例 4（`seal(dry-run) == seal(deploy)`）**必然在同一临时 home 上失败**；AC8 的人类流程（先复核 `-DryRun` 产物、后真部署）拿到的 seal 与部署时打印的 seal 也会不一致，人类无从判断"我批准的那份计划有没有被执行"。这是本切片唯一的"计划==执行"机械锚，坏了 AC4 就只剩自报。
* **Proposed Fix**（需 Author 择一，写进 AC4② 与 D1）：(a) seal 只覆盖模式无关的行（排除 `[COPY]`/`[SEED]`）；(b) `[COPY]` 改为无条件列举受管文件。无论选哪个，都要在 AC4② 补一句"seal 的输入行集合必须与模式无关"。

### B2（新）空目录在"删除集合"里的落点悬空：`$Plan` 与 AC4③ 的删除集合不可能相等

* **证据**：`install.ps1:154-167`（`New-MirrorAction`）只枚举 `-File -Recurse` 与**源树**目录；`install.ps1:223-242`（`Get-MirrorDelta`）却会为目标侧 live-only 的**空目录**产生 `[DELETE] (dir)` 行。执行器按 D3/AC2 只消费 `$Plan` 的行 ⇒ 目标侧的 live-only 空目录**永远不被删**；而 AC4③ 要求"实际被删集合（前 ∖ 后，含 `(dir)` 面）逐条等于 `[DELETE]` 行"——断言永远不可能成立。
* **按此计划执行会失败的具体后果**：AC4③ 在"目标侧存在 live-only 空目录"的样本上失败（或实现者为了让断言通过而放宽成"⊆"）；并且镜像根里残留的 live-only 空目录会让**下一次部署**的 delta 与本次不同（幂等性破口）。
* **Proposed Fix**：择一——(a) 目录面与文件面对称取差、对账拆成两条；(b) 把删除集合限定为文件面并同时删掉 `Get-MirrorDelta` 现有的空目录 `[DELETE]` 能力。

### B3（新）AC2 判定②③ 无法证明"白名单子树不被删"（最危险失效会被算作通过）

* **证据**：AC2 判定① 只看 `-DryRun` 计划行（计划 ≠ 执行），判定② 只看"部署前后驱动器签名差"，判定③ 是"谓词改回只看叶名 ⇒ 用例必红"的变异对照。三者都没有"**实际发生的删除集合与白名单集合不相交**"这一条：一个实现可以在 mirror-replace 里用 `Remove-Item -Recurse` 或"删空父目录"的捷径把白名单子树清掉（PROBE-B 实测 `whitelisted_child_survived=False`），而计划行照旧打印 `[PRESERVE]`、驱动器整体签名照旧"有变化"——**两个判据都通过**。
* **按此计划执行会失败的具体后果**：本切片自陈的最大风险（"删掉 127 个本机独有文件"）在验收上不可见；与 BACKLOG B-6 同型。
* **Proposed Fix**：AC2 判定② 补为**集合断言**——实际删除集合 ∩ 白名单路径集合 == ∅；判定③ 的变异对照升级为"实际删除集合出现白名单路径 ⇒ 断言必红"。

### B4（承接 round 2 Required-4，未闭合）并集锚的落点只写了 2 处，实际有 4 处

* **证据**：§3 步骤 9 只写"谓词(:470-487) 与报告(:267-299) 同源到并集"。但把 HomeRoot 交给报告的是**三处调用点**：`install.ps1:575`、`:586`、`:595`，全部写死 `-HomeRoot (Split-Path -Parent $ClaudeRoot)`；AC3 判定① 的重定向样本（`-ClaudeDir <home>\sub\.claude`）下 `Split-Path -Parent` 给出 `<home>\sub`，真实 home 那一路条目既不在谓词并集里也不在屏上清单里。
* **按此计划执行会失败的具体后果**：实现者改完谓词与函数体后，AC3 判定① 在重定向样本上仍然红；或为让断言通过把 `-HomeRoot` 硬编码为 `$env:USERPROFILE`，反向破坏"有效根"锚。
* **Proposed Fix**：§3 步骤 9 改写为"谓词面与三处报告调用点统一改为同一个并集构造（建议抽 `Get-MachineLocalSurface`），`Get-MachineLocalReport` 的 `-HomeRoot` 语义改为真实 home 锚"，并在 AC3 里点名这三处调用点。

---

## Non-Blocking Suggestions

1. **§3 的 `docs/` 一节已过期**：`docs/ai/QUALITY_GATES.md` 已存在、已被跟踪，且是本轮改写同一 commit `9b125aa` 的产物，而 §3 仍写"新增…本仓当前缺"。**Proposed Fix**：改为"已由 `9b125aa` 落地，本切片不再改动"；顺带记一笔：它在批准门之前由规划 commit 落地，若人类认为越界请在批准门裁决。
2. **`[SEAL]` 与 `plugin step: NOT IMPLEMENTED` 的打印模式未冻结**（`-ValidateOnly` 是否打印 `[SEAL]`？DryRun 是否打印 plugin 行？）。**Proposed Fix**：在 AC9 里逐模式列一张小表（Deploy/DryRun/ValidateOnly × {`[SEAL]` 行, plugin 行, RESULT/退出码}）。
3. **`[COPY]` 的枚举范围与 `planned` 的关系没写死**。**Proposed Fix**：D1 补一句"`[COPY]` 为逐文件行，`[PLAN]` 的 `(N files)` 与 `planned` 语义不变"，并明确 `[SEED]` 不重复进 `[COPY]`。
4. **AC4③ 的口径落在测试助手的已知短板上**：`Get-TreeSignature`（`tests/TestHelpers.ps1:59-84`）把目录也算进签名。**Proposed Fix**：AC4③ 写明文件面用 `-File -Recurse` 前后差 + 哈希变化，目录面单列一条。

## Assumption Challenges

1. AC2 判定② 的"驱动器签名差为空"这个判据很弱（BACKLOG B-6 同型）；它需要按 B3 的修法加强后才配得上"逐字节存活"的措辞。
2. Frozen Acceptance 的"从实现反推"风险有抬头迹象：`[COPY]`/`[SEAL]`/`[WARN]` 三个 tag 与退出码 2 都是先有实现意图后写进验收。请在批准门确认三点：① `[COPY]` 是逐文件还是逐动作；② `[SEAL]` 是否值得作为冻结契约（B1 若选 (b) 则 seal 退化成自证）；③ `RESULT=PARTIAL`/退出码 2 是否进入对外契约（一旦冻结，切片 C 会再次造成"活断言被证伪"，建议**现在就为切片 C 预留"条款自带失效条件"的写法**）。
3. AC8 声称"真实 home 一面在测试内不可实跑"如实且可接受；建议补一句最低成本验证方式（人类 `-DryRun` 全量输出 + `[SEAL]` 存档）。

## Verification Needed

1. **B1 机制确认**：同一临时 home 上先 `-DryRun` 记 `[SEAL]`、再真部署记 `[SEAL]`，回报两者是否相等；并对"源树文件已全部一致"的情形重跑，看 `[COPY]` 行是否消失。
2. **B2 机制确认**：在临时 home 的镜像根下建一个**空**的 live-only 目录，跑 `-DryRun`，确认它是否出现在 `[DELETE] (dir)` 行里。
3. **B4 调用点确认**：`Select-String -Path install.ps1 -Pattern 'Get-MachineLocalReport' -Context 0,1`，回报三处是否都仍传 `-HomeRoot (Split-Path -Parent $ClaudeRoot)`。
4. **取代账目的原文核验**（Reviewer 禁读面，只能由 Author/人类核）：确认归档 `:137` 是否确有"切片 B 落地后才转为真执行"的原文、`:74` 是否为 Amendment ㉗ 的 K1 判定。
5. **债闸门证据形态预演**：跑一次 `Select-String -Path install.ps1,tests\TestHelpers.ps1 -Pattern '\$script:Plan|\$script:checkFailed|\$Roots|Test-PathInsideDirectory|-Environment'`，确认"无残留"证据可机械核对。
6. **`docs/ai/QUALITY_GATES.md` 与源文件一致性**：`git show 9b125aa --stat` + `Compare-Object`，确认差集仅为 6 行来源头。

## Recommended Next Step

1. **Author**：只改计划/简报文本，不碰生产代码（B1 → AC4②/D1 择一写死，本审推荐 (a)；B2 → D1/AC4③/§3 择一，推荐 (a)；B3 → AC2 判定② 升级为集合断言；B4 → §3 步骤 9 点名四处落点；NB 4 条按各自 Proposed Fix 落条款）。
2. **Author**：跑上述 VN 的 6 条（尤其 VN-1/VN-2），把真实输出写进 `docs/ai/review_9P.md` 的本轮表态段。
3. **人类**：在批准门一并裁决三件事——① B1 选 (a) 还是 (b)；② `[COPY]` 粒度与 `RESULT=PARTIAL`/退出码 2 是否进入对外冻结契约；③ `docs/ai/QUALITY_GATES.md` 在批准门前落地是否接受。
4. 本 reviewer 未做任何写入、未执行任何测试。
```

### Author Responses（round 3；每条一句话，详细理由与 VN 代跑结果见 `IMPLEMENTATION_PLAN.md` §10）

1. **B1 `[COPY]`/`[SEAL]` 矛盾** → **修改后采纳**：其"必然失败"不成立（今日顺序已是 `Show-Plan`(:596)→`Test-Plan`(:597)→写入，DryRun 同理 `:587`，计划行在写入前产生），但"顺序与模式无关性"必须写死——AC4② 已写明"任何写入之前运行一次、不得在写入后重印、⑥ 的重校验也不得打印"，并以"跨模式 seal 必须相等"反向锁死该顺序；**不采纳**其"seal 排除 `[COPY]`/`[SEED]`"的方案（会削弱封存面，逐文件面已由 AC4③④ 独立承担）。
2. **B2 空目录落点** → **修改后采纳**：实跑 PROBE-E 证明空 live-only 目录**确实**进 `[DELETE] (dir)`（读侧已覆盖），故真问题是"行来源"措辞歧义；D1/§3 已写死"执行器消费的就是这批行对象本身"，AC4③ 拆成文件面/目录面分别对账，§6 增 PROBE-E 回归用例；**不采纳**其"删除面限定为文件面"的方案（要删掉现有能力且仍不一致）。
3. **B3 AC2 判定太弱** → **采纳**：判定② 改为 **实际删除集合 ∩ 白名单路径集合 == ∅**，③ 改为对每个白名单路径 P 的 `Get-TreeSignature(P)` 前后相等，④ 变异对照升级为"实际删除集合出现白名单路径 ⇒ 必红"。
4. **B4 并集锚 4 处落点** → **采纳**：实跑确认 `:575`/`:586`/`:595` 三处都写死 `-HomeRoot (Split-Path -Parent $ClaudeRoot)`；§3 步骤 9 改为"共享构造器 + 四处消费"，AC3 同步写明 `-HomeRoot` 改为真实 home 锚。
5. **NB-1 docs 过期** → 采纳（§3 改为"已由 `9b125aa` 落地、本切片不再改"；越界与否交批准门）。
6. **NB-2 打印模式** → 采纳（AC9 新增逐模式落点表，§6 用例 7 逐格断言）。
7. **NB-3 `[COPY]` 粒度** → 采纳（D1：逐文件、`[SEED]` 不重复、`planned` 不变）。
8. **NB-4 观测口径** → 采纳（AC4③ 文件面/目录面分开，点名 `TestHelpers.ps1:59-84`）。
9. **AC-1 / AC-2 / AC-3** → 采纳：AC-1 由 B3 修法消解；AC-2 三点已在文本定稿（`[COPY]` 逐文件 / `[SEAL]` 保留并给出其判据价值 / AC9 写成**自带失效条件**并要求切片 C 带同型取代账目），**仍请人类在批准门确认**；AC-3 已写死 AC8 产物 = 该次 stdout 完整副本 + `[SEAL]` 值。
10. **VN-1..6** → 全部代跑完毕，结果逐条落 `IMPLEMENTATION_PLAN.md` §10 的表（VN-4 证实取代账目两处引文逐字属实；VN-5 发现 9P 给的宽模式有两类假阳性，已改用收紧模式作为步骤 0 的证据形态）。
