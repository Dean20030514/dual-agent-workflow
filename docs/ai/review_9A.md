# 9A verdict — dsh-landing review

> **来源与保真度声明（Author 落账，如实标注）**：本轮 Reviewer 把 verdict 作为 **agent 返回正文**交回，本文件由 **Author 在双审窗口结束后转录**，**不是 Reviewer 亲手写的原始 artifact**。Blocking Issues、Non-Blocking Suggestions、Verification Needed、Debt Verdict、Test Coverage Gaps、Cannot Verify From Diff 为**逐条转录**；叙述性前言略去（不携带判据）。协议缺陷见 `docs/ai/HANDOFF.md` → Known Issues。
> 审查对象：`review_base_sha=bf06c65d0831ebeb2b0982f35ae2d7f4c65c2c17` → `review_tip_sha=a361bc1942546484e0edd102cbd789d4dc498c61`

## 证据首行（5 项 Author 核验通过）

```
observed_head_sha: a361bc1942546484e0edd102cbd789d4dc498c61
worktree_clean: yes
read_handoff_from: 不存在（本任务无交接文件）
writes_performed: none
review_base_sha: bf06c65d0831ebeb2b0982f35ae2d7f4c65c2c17
review_tip_sha: a361bc1942546484e0edd102cbd789d4dc498c61
handoff_snapshot_sha: a361bc1942546484e0edd102cbd789d4dc498c61
```
覆盖核验：未过滤 `--name-only` 共 29 个文件，全部落在 `review_sensitive_paths` 内 → **无覆盖缺口**。

## Review Verdict

**不通过**（Blocking 非空）

## Blocking Issues

### B1 — 9P 的 `reasoning_effort: "medium"` 在本部署里必然抛错，9P 计划审按文档跑不起来

* **具体后果（可执行反例）**：`@deepseek-ai/dsh-llm-deepseek/lib/index.js:26-29` 的 `reasoningEffort()` 只放行 `off|low|high|max`，其余抛 `LlmError(..., "UNSUPPORTED_REASONING_EFFORT")`；`Config.reasoningEffort` 的 z.union 同此四项。用户操作 = Author 照 `reviewer-prompt.md` → 9P 的调用模板发 9P → 必失败、拿不到 verdict；按 `fanout-toolchain.md` §5 重跑一次仍失败 → 连续两次失败即停手。**结果：DSH 下 Critical 的强制前置门（批准前的 9P）按文档无法执行。** 自相矛盾尤其硬：`fanout-toolchain.md:33` 与 `portable/通用prompt-DSH-v1.txt:166` 同一句话里既写「9P = medium」又写「可接受值 off/low/high/max」。
* 受影响站点（11 处）：`dsh/workflow/reviewer-prompt.md:44,51,135,214,222`、`dsh/workflow/fanout-toolchain.md:27,33`、`dsh/skills/independent-review/SKILL.md:35`、`portable/通用prompt-DSH-v1.txt:61,166`、`README.md:47`。（母本与 `portable/通用prompt-v3.8.txt` 里的 `medium` 属 Codex 侧 `model_reasoning_effort`，**合法，不算缺陷**。）
* **caused_by_last_fix: yes**
* **Proposed Fix**：改成适配器取值域内的**下一档 `low`**（保留"比 9A/9B 低一档"的母本意图；`high` 是默认档、等于取消分档；`off` 过弱；改 `high` 属人类裁决）。逐处改这 11 个站点，并把唯一定义处句改为 `9A/9B = high，9P = low`，同时补一句"母本 514s/采纳率基线量自 Codex 时代，DSH 档位阶梯为 off/low/high/max，观察量重新起算"。改完须实跑一次 9P 调用取证。

### B2 — `DSH-LANDING-NOTES.md` §2「只有这些改点」的完整性声称不成立：≥11 个实际变更未登记

* **具体后果**：§2 是 README 快照节 / 仓库根 `AGENTS.md` / `AUTHORITY_CONTRACT.md` 一致指过去的唯一改点登记，却漏登：新增 `dsh/AGENTS.md`（116 行）、两个 `SKILL.md`、两份执行手册（`conflict-hard-stop.md` 108 行 / `verification-evidence.md` 72 行）、`portable/通用prompt-DSH-v1.txt`（175 行）、`workflow-design-notes.md` 的一行路径指针、仓库根 `AGENTS.md` 新增段、`README.md`（+24/-9）、`AUTHORITY_CONTRACT.md` 增补、`install.ps1` DSH 段。后果 = 任何人按 §2 做"是否改了判据"的完整性复核时，**复核面不包含 `dsh/AGENTS.md`**——而它正是 DSH 每会话自动注入、承载 Safety 红线 / Git 纪律 / Roles / Fan-out 上限的文件；也不含 4 份 skill 正文与 portable 全文。且**已有一处实质漂移藏在未登记面内**（见 B4 族 / 9B 的 S1）。
* **caused_by_last_fix: yes**
* **Proposed Fix**：新增 `## 2.1 清单外的其余变更（新增文件与仓级/运维文件）`，把 11 行逐条列出（标注"新增，无母本对应物"或"改写自 `claude/CLAUDE.md`"），并把 §2 标题的"只有这些"限定为"只列 `dsh/` 对 `claude/` 母本的**文本改点**"。（备选：把 §2 扩成 23 行完整清单，可读性差，不推荐。）

### B3 — `install.ps1` 新增的 DSH 注释与其自身代码矛盾（验收点 8「说与做一致」有具体反例）

* **具体后果**：`install.ps1:15-19`（文件头注释）说「`~/.dsh/skills/` 下**文件名以 `phase-` 开头**的文件被 mirror-replace…其余文件一概不动、新文件仅在缺失时补齐」；而 89-102 行代码是**按目录整树 mirror-replace** 每个 bundle（先 `Remove-Item -Recurse -Force` 再拷）。反例：`dsh/skills/**` 下**不存在任何 `phase-*` 文件名**（`phase-` 只出现在 frontmatter 的 `name:` 字段里）→ 注释描述的对象根本不存在。具体后果：用户在这两个 bundle 里放了本机内容（自加 `references/notes.md`、本机调过的 phase 正文）后运行安装器，那些文件会从活动位置被删除（只在 `*.bak-<stamp>` 里留一份，而注释明确说不必期待这种替换），且"其它 skill 一律保留"的承诺被读者误推广到本工作流自有的两个 bundle 上。
* **caused_by_last_fix: yes**
* **Proposed Fix**：把 15-19 行改写为与 89-92 行、README、`AUTHORITY_CONTRACT`、`LANDING-NOTES` §4 一致的三句：「`~/.dsh/AGENTS.md` 与 `~/.dsh/workflow/` 为 mirror-replace；`~/.dsh/skills/` 下**只有本工作流自有的两个 bundle** 被 mirror-replace，其余 skill 目录一律不动；`settings.yaml`、sessions、storages、凭据从不触碰」。

### B4 — `dsh/workflow/AGENTS.md` 仍留下指令性的 `-o`（Codex 专属参数），且与本文件后文自相矛盾

* **具体后果**：`dsh/workflow/AGENTS.md:148`（§2 第 3 条声明"已 DSH 化"的 AI Collaboration Rules 节）写"…**或由 Author 启动的 `-o`（headless 路径）**"，而同一文件 138 行写"`dsh --profile headless` … **`-o` 不可用**，verdict 走 stdout"。两句不可能同真。具体后果：Author 按 148 行字面拼命令（`dsh --profile headless ... -o $HOLD/9B.md "<prompt>"`），`-o` 与路径会被 launcher 透传给 headless app 当作 **task 文本的一部分**（headless 只读位置参数），verdict 不会落到 holding，该轮计一次失败；重跑仍不对即触发"连续两次失败 → 停手报告人类"。
* **caused_by_last_fix: yes**
* **Proposed Fix**：把该括号改成"或由 Author 用 shell 重定向 headless 的 stdout/stderr 到仓外 holding（headless **无 `-o`**，见 `~/.dsh/workflow/reviewer-prompt.md` → 双审隔离协议 ③(b)）"。并全文搜一次 `-o` 的指令性残留（`dsh/**` 内当前只有这一处是错的）。

## Non-Blocking Suggestions（8 条）

1. **机读来源与断言不符**：`fanout-toolchain.md:34`、`dsh/AGENTS.md:26`、`portable:27` 断言旧 id"已下线或路由到 V4.1 Flash"，而 `list_subagent_models` 与 `DEFAULT_MODELS` 仍把 `deepseek-v4-pro` 列为独立模型且描述相反；官方公告 URL 未给出。**Fix**：补官方公告 URL 与日期，并注明"本机适配器目录保留旧 id 的 legacy 描述，`list_subagent_models` 单独不足以支持本条断言"。
2. **账本计数错**：`DSH-LANDING-NOTES.md:73` 写"三个 `SKILL.md`"，实际**两个**。**Fix**：改"两个"。
3. **清单枚举被收窄**：`implement.md` 的 `Ready for Review` ③ 删掉了母本的"8 节"并去掉了 `Recommended Next Step`（该节仍是 9A 必填末节）。**Fix**：恢复为"完整输出契约 7 个顶层字段 + 9A 末节 Recommended Next Step（9B 两节）+ DSH 新增的 `writes_performed` 证据行"。
4. **`[DEBT]` trigger 未点名路径**：第 2 笔的 trigger 不含文件/模块路径或 glob，Payback-on-Touch 无法机械命中。**Fix**：改为"下次改动 `dsh/workflow/fanout-toolchain.md` 之前，或 `@deepseek-ai/dsh` 升级后首次派发审查之前"。
5. **§2 第 8 条描述不完整**：母本"派 sub-agent 时要求继承主对话模型不降级"被整句替换为 fan-out 上限指引，而 §2 未说明一条母本规则被替换。**Fix**：在该改点列补一句替换说明。
6. **§1 给出的理由不成立**：phase 文件加 `name: phase-*` 的理由写成"skill 发现要求 name 字段"，实测嵌套 `**/SKILL.md` 故意不被发现。**Fix**：改写理由为"防御性写法，防止未来有人把 phase 文件挪到根层而被误当技能"。
7. **整树备份会把凭据复制一份**：`install.ps1:76` `Backup-IfExists $dshDir` 把整个 `~/.dsh`（含 sessions/storages/`.credentials.yaml`）复制成 `~/.dsh.bak-<stamp>`，而 README 与 AUTHORITY_CONTRACT 都说凭据"从不触碰"。**Fix**：(a) 备份范围收窄到受管路径，或 (b) 明写整树备份的副作用。
8. **同构副作用（低优先）**：`dsh/AGENTS.md` 既是部署源又位于仓库内，工作于 `dsh/` 时会被当目录级指令重复注入（`claude/CLAUDE.md` 有同样性质，非本 commit 独有）。

## Test Coverage Gaps

* `install.ps1` 的 DSH 段没有任何自动检查（`tools/validate/` 是 H5A 封存档、脚本受 guard 锁定）→ B3 这类漂移只能靠人读发现。
* `dsh/**` 没有任何"文档中给出的参数是否在适配器取值域内"的机械检查；B1 若有一行白名单校验就不会漏。

## Cannot Verify From Diff

* "`deepseek-flash` = 当前最强档、旧 id 已路由到它"无法从仓内一手来源证实（目录描述反而相反）。
* `dsh --profile headless` 默认模型确实为 `deepseek-flash`、且备用路径根本不支持钉 provider/model，需实跑确认。
* 三笔 `[DEBT]` 中"无 `*.bak-*`"属机器态，未核。

## Verification Needed（4 条）

1. **证伪 B1（最高优先）**：发一次前台子 agent，参数用文档里的 9P 组合、prompt 写"只回答 OK"；预期返回含 `UNSUPPORTED_REASONING_EFFORT`。静态旁证：`Select-String dsh-llm-deepseek/lib/index.js -Pattern 'does not support reasoning effort'`。
2. **复核 B3 反例**：`Get-ChildItem -Recurse dsh\skills | Where-Object Name -like 'phase-*'`（预期空）与 `Select-String install.ps1 -Pattern "phase-"`（预期命中 15-19 行注释）。
3. **headless 备用路径的档位与默认模型**：`npx -y @deepseek-ai/dsh --profile headless "只回答你的 provider 与 model id"`；并 `--help` 确认无 `-o`、无 provider/model 钉法。
4. **§2 完整性再核**：`git diff --name-only bf06c65..a361bc19` 与改点清单逐项对表，修完后应零遗漏。

## Debt Verdict

**Noted**（格式合规、trigger 可满足、§5 明确把未做项列为未验证——这一点是诚实的。修 B1–B4 的这一轮会**立刻触发第 1 笔**："下次改动 `dsh/**` 之前"须先在「先跑一轮审查」与「人类批准延期」之间选一个。第 2 笔 trigger 不含路径，见 S4。）

## Recommended Next Step（转录要点）

1. 先止住 B1（建议 `low`，同步 11 处，实跑取证）——不修则 9P 门不可用。
2. 改 B3/B4 两处"说与做不一致"。
3. 补 B2 的 `§2.1`，顺带 S2/S4/S6。
4. 下一轮把 §5 的"已验证/未验证"边界更新，把"9P = medium"这类**未经实跑的取值断言**标成 `[假设] + 最低成本验证方式`。
5. 修复落在 `review_sensitive_paths` → 需一轮 9A/9B（或先取得人类对第 1 笔债的延期批准）。
