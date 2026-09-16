# BACKLOG_sliceB.md — 切片 A 收敛时移交的残余清单

> **用途**：切片 A（`install.ps1` 参数面 + 两条零写入路径）按**冻结验收**（`TASK_BRIEF.md` 的 AC1–AC3 + K1–K9 + ㉓–㉜）收敛时，把五轮审查（9P + 9A/9B round 1–5）里**所有未闭合但非「冻结条款的可复现违反」**的条目一次性移交，避免它们继续留在切片 A 的审查循环里。
> **收敛判据（人类 2026-09-15 裁决 A）**：最近三轮（round 3/4/5）**没有任何存活且可复现的实现违反冻结条款**——round 3 的一条已修、round 4 的一条已修、round 5 的两条一条被实跑推翻（`disputed`）、一条是文本落后于裁决（已改准）。其余发现全部属于下列四类之一。
> **不在本文件**：`~/.dsh` 首次真部署债（人类动作，仍 **Unpaid**）；`HANDOFF.md` 债册里与本切片无关的历史债。

## 1. 切片 B 语义（有真实写入路径后才有意义 / 才有致命性）

| # | 条目 | 来源 | 为什么不属于切片 A |
|---|---|---|---|
| B-1 | `-ClaudeDir ''`（空串）静默回落到真实 `~/.claude`（`install.ps1:145` 用 `if ($Explicit)`） | 9B round 4 NB-4 / 9A round 5 NB | 切片 A 零写入，传空串只是打得难看；**切片 B 会真的部署到真机**——这是部署地雷，切片 B 必须改为"传了但为空 → 点名 FAIL" |
| B-2 | `:220`/`:226` 的 `-contains`（大小写敏感）与同函数其余 `OrdinalIgnoreCase` 不一致 | 9B round 5 NB-2 | 今日解析路径大小写与源一致故不可达；切片 B 据此删文件时会变成真实误删 |
| B-3 | 源树**自带**同名 `archive`/`*.bak-*` 目录时，其内本机独有文件是否仍进 `[DELETE]` | 9B round 5 TCG-4 | **未复现**（推演，未实跑）。切片 B 冻结执行语义前必须先复现或排除 |
| B-4 | `[CHECK] plugin-cli` 两支都 `Report $true`（恒真） | 9A round 5 NB-6 | 插件步与 CLI 缺席分支属切片 C；切片 C 冻结后再决定缺席是否 FAIL |
| B-5 | `[PLAN] mirror … (N files)` 只有计数、无逐文件行；AC2 的"计划与切片 B 执行集合一致"目前只在**动作粒度**成立 | 9A round 4/5 NB-3 + RC-2 + 9B TCG-6 | 逐文件粒度是**执行器契约**，切片 B 落地执行器时必须同时冻结"是逐文件行还是计数+校验和" |
| B-6 | AC3⑦ 的"部署形态零写入"在切片 A 近乎恒真（Deploy 路径失败即返回、写入函数被移除） | 9A round 4 RL-2 | 该断言要到切片 B 有写入路径时才具区分力；切片 B 应把它升为硬要求 |
| B-7 | `-DryRun` 不调用 `Test-Plan`，故对"必被拒的计划"仍 `RESULT=OK`（语义已收窄进 brief，但用户可见面没有提示） | 9A round 4 NB-5 / 9B round 4 NB-3 / RL-3 | 是否给 DryRun 加形状警告属产品语义；切片 B 冻结 DryRun 语义时一并定 |

## 2. 需求裁决（只有人类能改 `TASK_BRIEF.md` / 计划文本）

| # | 条目 | 来源 | 待裁的点 |
|---|---|---|---|
| R-1 | AC1② 的"输出含该样本的**参数名** + 绑定诊断族"对 **K7**（参数集冲突）**客观不可满足**（PowerShell 不回显参数名，而约束又禁止体内互斥诊断） | 9A round 3 RC-3 / round 5 G6 | 把该合取拆成"未知/错拼样本含参数名、位置样本含 token、参数集样本含诊断族" |
| R-2 | 执行前置约束② 要求"每次子进程调用都显式传三个路径参数"，但 K1（无参数）、K4/K5（只传出错 token）字面违反 | 9B round 5 RC-3 / 9A round 5 NB-3 | 把②改写成实质判据（"解析后的三目标必须落在临时 HOME 内"）或注明例外 |
| R-3 | 机器态谓词锚（`$env:USERPROFILE`，`:475`）与机器态报告锚（生效根，`:575/:586`）**不同源**；重定向 `-ClaudeDir` 而 HOME 未重定向时谓词不拦 | 9A round 3 NB-1 / round 4 NB-5 / round 5 NB | 决定"机器态面"是护真机还是护本次生效根（影响切片 B 的写入保护范围） |
| R-4 | `planned=11` 的语义（计划**动作**数，不含插件）未在验收或头注释定义 | 9B round 4 RC-4 | 是否写进输出契约，避免下游读成"将复制的文件数" |
| R-5 | `IMPLEMENTATION_PLAN.md` 的 Proposed Changes 表未含 `tests/install.Host51.Tests.ps1`（㉔ 5.1 腿的承载文件） | 9A round 3 NB-6 / round 4 NB-2 | 落一句授权记录，使"实际 diff ⊆ 批准范围"可机械核对 |

## 3. 测试增强（非阻断；切片 A 的验收判定已不依赖它们）

| # | 条目 | 来源 |
|---|---|---|
| T-1 | case 10/11（deploy 形态）补 **HOME 签名**断言（AC3⑦ 的"零写入"半条；目前只有 case 7 两条都断言） | 9A round 4/5 Gap |
| T-2 | case 6b 参数化补第二样本 `.claude\projects.bak-20260101-000000`（㉓ 点名；现仅 `projects-x`） | 9B round 4 TCG / 9A round 5 Gap |
| T-3 | `seed src -> dst`（config.toml 缺失）分支无用例——所有用例都带 `-SeedConfigToml` | 9B round 4 TCG / 9A round 5 Gap |
| T-4 | 机器态 `[PRESERVE] … (machine-local, never touched)` 家族只有**排除式**断言，无正面断言 | 9A round 5 Gap |
| T-5 | `-DryRun` 语义无机械钉住（无用例断言"DryRun 不执行 Test-Plan / 计划不合法时仍 0"） | 9B round 4 Gap-3 / 9A round 5 Gap |
| T-6 | `planned` 无行级交叉核对（`delete`/`preserve` 都有"计数 == 屏上行数"） | 9B round 4 Gap-2 |
| T-7 | A3 的 `dsh/skills` 臂：预言机与被测代码**抄同一常量**，新增第三个 bundle 时恒绿（已在债册记为 `[DEBT]`，trigger = 下次新增/改名 skill bundle） | 9B round 3/4 NB-1、round 5 RC-3（9A G5） |
| T-8 | `install.ps1` 的枚举顺序前提（`Get-ChildItem -Recurse` 父先于子）未在**生产注释**声明——本轮只落了关系型不变式断言（AC2⑥），未动生产注释（为保持 installer 哈希稳定） | 9B round 5 NB-1 |
| T-9 | 死代码六处（`$script:Plan`、`$script:checkFailed`、`$Roots`、首个 `$RootSpecs` 赋值、`Test-PathInsideDirectory`、`Invoke-InstallerCase -Environment`）——`[DEBT]` 的 trigger 已被触发，需清偿或重新登记 | 9A round 4 NB-4 + round 5 NB |
| T-10 | AC1 的"配对通过样本（逐字冻结）"未在四个失败样本的 argv 里逐字落实（三个路径参数缺失） | 9A round 5 NB |
| T-11 | K9 边角：根冲突未单测"相同拼写"（只测尾分隔符变体）；`-ClaudeDir ''`/`$null` 无样本 | 9B round 4/5 Gap |
| T-12 | 断言用 `*` 通配而非字面量，路径含 `[` 时会失配 | 9B round 5 TCG-5 |

## 4. 文档改准（切片 D）

* D-1 头注释 L15 未写「`-DryRun` 的 `RESULT=OK` ≠ 计划能过校验」（冻结措辞已在 brief，但用户可见面没有）。
* D-2 头注释 L1/L5-6 的现在时表述与 L8 指向**故意过期**的 README 部署节。
* D-3 `HANDOFF.md` 旧轮残留：`Next Step` 仍是 round 2 文本、Quick-Version 的 Human Approval Evidence 仍写"待批准"（实际 `bc3cb39`）、`Current Phase: Planning` 行、`上一任务状态` 重复段、Work Log 停在 `709649d`、`[DEBT]` 笔数陈述（写"9 笔"，实测 11）。

## 5. 人类动作（不属任何切片）

* H-1 **`~/.dsh` 首次真部署**（AC10 第二项）+ 其落账规范 —— 未偿还前，本任务**不得**声称 converged（任务级）。切片 A 的收敛是**按冻结验收的实现收敛**，不是任务级收敛。
* H-2 **扫 diff + commit**（agent 不 push / 不 merge）。
* H-3 决定是否需要 round 6：按本次裁决 A，**不再对切片 A 开审**；若将来重开，建议先立终止规则（Blocking 只认"冻结条款的可复现违反"，NB/Gaps 进 backlog 不阻断，纯文档轮不开审）。
