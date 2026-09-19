# Reuse-first 复用协议（规范）

> 本目录是「先找轮子」语义的**唯一规范来源**：`core/reuse/README.md` 冻结语义与字段形状，`core/reuse/reuse.schema.json` 冻结结构，`core/reuse/Reuse.ps1` 是纯校验器。Claude / DSH / Codex 三种入口与 Team 运行器只**引用**本目录，不复制规则。代码、注释与错误文本用英文；本文档面向人类读者，用中文。
>
> 本节规则不改变任何权威、权限、验收或 Git 政策；`deviation` 只是声明，**不构成批准**。

## 1. 目的与适用范围

对**新实现、新依赖、新架构选择、新协议**，开工前必须先做一次有记录的复用检索：找到成熟方案就采用 / 移植 / 包装 / 引用，找不到就明确记录「没有可用轮子」，而不是默默从零写。

以下情况允许跳过（必须在任务级给出显式 `skip_reason`，取值只能是下列四类之一；自由文字说明写在 `reason` 里）：

- `skip_reason = docs_only`：纯文档修正；
- `skip_reason = diagnosed_local_bug`：已定位的本地缺陷修复；
- `skip_reason = established_repo_pattern`：沿用仓内既有模式；
- `skip_reason = data_only`：纯数据改动。

`new_implementation` / `new_dependency` / `architecture` / `protocol` 四类**无论任务标签、文件扩展名或 write_scope 长什么样**都强制 `required`，不允许跳过。

本协议**不是通用框架**：它只有三种文档形状、五个校验入口和一个身份哈希；不引入依赖、不调度进程、不访问网络。

## 2. 三种形态：Routine / Critical / Reviewer

- **Routine（默认）**：只在对话里留**一句 inline 结论**——检索范围、找到什么、采用与否及理由。不新建文件、不建账本、不加流程。
- **Critical（人类明确启用时）**：在**既有计划文件**里增加固定的「Reuse / Prior Art」小节，复用该小节承载 decision 与任务级声明；不新增流程、不新增登记表。
- **Reviewer**：**没有重新检索的义务**。复审者只核对声明的约束（constraints）与结果里真实使用的事实；复核不重跑检索、不要求补充检索证据。
- **核心语义规则不依赖任何模型名或 harness 名**：规则只谈「检索来源、结论、候选、策略、引用与偏差」，谁执行检索由消费方决定。

## 3. 文件、身份与证据

| 文件 | 作用 |
| --- | --- |
| `README.md` | 语义规范（本文件） |
| `reuse.schema.json` | 结构契约（draft-07，`oneOf` 三分支：decision / task / result） |
| `Reuse.ps1` | 纯校验器（dot-source 使用，无副作用） |

`Get-ReuseProtocolIdentity` 返回 `version = 1` 与三个协议文件内容的**确定性哈希**（键按 ordinal 排序的规范 JSON 的 SHA-256），并逐个列出文件名、`sha256` 与字节数。它按 `Reuse.ps1` 所在目录解析文件，因此源的 `core/reuse` 与由 `install.ps1` 部署的受管副本 `workflow-core/reuse` 在内容一致时身份相同。

新 run 在开始时冻结该身份并复制这三个文件作为证据；运行中身份不一致即视为协议被改动，不得继续搬运旧的检索结论。

## 4. 机械规则（校验器逐条强制）

### 4.1 decision（计划级复用决策）

必须同时出现：`version = 1`、`applicability`、`status`、`reason`、`searches`、`candidates`、`strategy`、`rationale`、`constraints`。所有 `reason` / `rationale` / `query` / `summary` / `borrow` / `deviation.reason` 都是**非空白**字符串；只含空白的值一律抛错。（`skip_reason` 是枚举 token，不是自由文字，见 4.4。）

- `applicability = skipped` ⇒ `status` 必须是 `skipped`，且 `searches` 与 `candidates` 必须为空数组。「全局跳过」不能掩盖任何 `required` 任务：任务级 `required` 配上跳过决策会在任务校验处被拒。
- `applicability = required` ⇒ `status` 只能是 `completed` 或 `blocked`。
- `status = completed` ⇒ 三个强制渠道 `github_repositories`、`github_code`、`primary_docs` 必须各自有一条**成功**检索；「成功」= `outcome` 为 `results` **或** `no_results`（检索答了话，哪怕答的是「没有」）。零候选因此完全合法：三个渠道都 `no_results`、`candidates` 为空、`strategy = build` + 非空 `rationale` 即为有效的完成决策，协议**不要求**候选数大于零，也不允许把「没有可用轮子」判成失败。
- `status = blocked` ⇒ 必须至少有一条 `outcome = unavailable` 的检索，且该检索的 `evidence` 非空。
- 任一检索 `unavailable` ⇒ 决策**不能**是 `completed`，只能是 `blocked`（网络失败必须暂停，不允许被吞进「已完成」）。
- `strategy ∈ {adopt, port, wrap, reference, build}`；非 `build` 策略必须存在至少一个 `candidate.decision` 与之一致的候选（被选中者）。
- `candidate.id` 全局唯一（区分大小写）。
- `constraints` 是字符串数组，供 worker 与盲审共同可见；不得为空白的条目。

### 4.2 search（检索记录）

`source ∈ {github_repositories, github_code, primary_docs, package_registry}`，`outcome ∈ {results, no_results, unavailable}`，并带 `query`、`summary`、`evidence`（字符串数组）。

- `outcome = results` ⇒ `evidence` 至少一条（链接或收据引用）。
- `outcome = unavailable` ⇒ `evidence` 至少一条（失败收据引用），用于支撑 `blocked`。
- `outcome = no_results` ⇒ **合法的零结果**：检索成功但没有匹配。允许 `evidence` 为空，也允许写一条收据引用（此时只是记录这次检索发生过）；协议**不要求**它给出任何正向结果 URL。检索不到不构成失败，也不要求候选数大于零。
- 任务 `change_kinds` 含 `new_dependency` ⇒ **仅在决策 `status = completed` 时**要求一条成功的 `package_registry` 检索（`results` 或 `no_results` 都算成功）。决策 `blocked` 时不适用该要求：此时的声明必须原样送达暂停 / owner 例外流程，不能因为「注册表查不到结论」被判成任务错误。
- 校验器**不推断检索的真实性**：它只检查结构与交叉字段一致性，不判断链接是否真实存在、检索是否真的发生过。

### 4.3 candidate（候选）

`id`、`url`、`revision`、`decision ∈ {adopt, port, wrap, reference, reject}`、`rationale`、`borrow`、`constraints`。

- `decision = reject` 的候选**不能被任务引用**（`refs` 指向它即报错），也不能出现在结果的 `references_used` 中。
- `borrow` 说明「借用什么」；除 `reject` 外必须非空白（`reject` 允许空串，表示什么也不借）。

### 4.4 task reuse（任务级声明）

`applicability`、`reason`、`change_kinds`（≥1，去重，值属于 8 类枚举）、`refs`、以及仅在跳过时出现的 `skip_reason`。

- 前四类 change kind ⇒ 强制 `required`，写了 `skip_reason` 也无效（直接报错）。
- 后四类允许 `skipped`，但**必须**给出显式 `skip_reason`，且 `skip_reason` 只能取 `docs_only` / `diagnosed_local_bug` / `established_repo_pattern` / `data_only` 这四个枚举值之一；「为什么这次可以跳过」的自由说明写在 `reason` 里，`skip_reason` 只负责标注类别（`"not needed"` 这类任意文字一律报错）。
- `required` 任务出现 `skip_reason` ⇒ 报错（字段只属于跳过形态）。
- 每个 `refs` 条目必须存在于决策候选中且**不是** `reject`；`refs` 去重（ID 唯一）。
- 决策为 `skipped` 时任务不能是 `required`。
- `refs` 可以为空：`strategy = build` 或任务 `skipped` 时为空是合法的；协议不强制任务必须引用候选。被引用却未被使用的情况由 4.5 的偏差规则兜底。

### 4.5 result reuse 与 deviation（真实使用）

`references_used`（字符串数组，去重）与 `deviations`（`{reference, reason}` 数组，reference 去重）。

- 未知引用与**任务外**引用（候选存在但不在本任务 `refs` 中）一律拒绝。
- 决策/任务规定要复用的引用若未出现在 `references_used` 中，**必须**有一条同名 `deviation` 且 `reason` 非空白；未解释的遗漏直接报错。
- 空 `references_used` 在 `build` 策略或 `skipped` 任务下合法。
- `deviation` 只是声明：它**不构成批准**，也不改变任何权限、范围或验收。

### 4.6 网络失败与 owner 例外

任一检索 `unavailable` 时决策必须 `blocked`，执行侧在**创建 worker worktree / 进程之前**暂停，并把暂停登记为既有升级机制中的一条（类型 `reuse_unavailable`）。恢复**只**接受责任人对**确切 Team Plan hash** 的显式例外批准；Plan 变更（replan）后例外失效，必须重新检索或重新取得批准。校验器只提供 `plan_hash` 绑定字段，机械准入由 Team 运行器负责。

`blocked` 是一条**合法的中间状态**，不是声明错误：任务级校验不会因为它而拒绝 `new_dependency` 等 `required` 声明，这些声明必须原样送达上述暂停 / owner 例外流程。反过来，`blocked` 决策也不能被当成 `completed` 使用（4.1 的完成规则只对 `completed` 生效）。

## 5. 冻结字段形状

- **decision**：`version:int(1)`、`applicability`、`status`、`reason`、`searches[]`、`candidates[]`、`strategy`、`rationale`、`constraints[]`（全部必填）。
- **search**：`source`、`query`、`outcome`、`summary`、`evidence[]`（全部必填）。
- **candidate**：`id`、`url`、`revision`、`decision`、`rationale`、`borrow`、`constraints[]`（全部必填）。
- **task reuse**：`applicability`、`reason`、`change_kinds[]`、`refs[]`（必填）+ 可选 `skip_reason`（跳过时必填，取值为后四类 change kind 之一）。
- **result reuse**：`references_used[]`、`deviations[]`（必填）。
- **context**（由 `Get-ReuseContext` 生成，传给 worker）：`version`、`identity`、`plan_hash`、`decision{applicability,status,strategy,constraints}`、`task{applicability,reason,change_kinds,refs[,skip_reason]}`、`candidates[]`（**只含本任务引用的候选摘要**：`id,url,revision,decision,rationale,borrow,constraints`）。context **不含**完整检索日志、也不含决策级 `reason`/`rationale`。

`id` 与 `refs` 的格式：`^[A-Za-z0-9][A-Za-z0-9._:-]{0,79}$`（区分大小写）。

Team 适配层把 decision 放在 Plan 顶层 `reuse`、把任务级声明放在 task 的 `reuse`、把结果声明放在 Result 的 `reuse`；派生出的 `reuse_context` 即上文 context。Team 侧 schema 由 Team 维护，本文档只冻结语义形状。

## 6. 完整示例（下列 JSON 由测试逐个校验，必须始终有效）

### 6.1 跳过（docs_only）

```json reuse-decision
{
  "version": 1,
  "applicability": "skipped",
  "status": "skipped",
  "reason": "Every task in this plan only rewrites user facing wording.",
  "searches": [],
  "candidates": [],
  "strategy": "build",
  "rationale": "Documentation-only work raises no prior-art question and adds no capability.",
  "constraints": []
}
```

```json reuse-task
{
  "applicability": "skipped",
  "reason": "Only rewrites existing user facing wording: no new capability, dependency, protocol or architecture decision.",
  "change_kinds": ["docs_only"],
  "refs": [],
  "skip_reason": "docs_only"
}
```

```json reuse-result
{
  "references_used": [],
  "deviations": []
}
```

### 6.2 完成（required + completed，含零结果与 reject 候选）

```json reuse-decision
{
  "version": 1,
  "applicability": "required",
  "status": "completed",
  "reason": "The plan introduces a new protocol surface and considers a new dependency.",
  "searches": [
    {
      "source": "github_repositories",
      "query": "reuse first prior art protocol",
      "outcome": "results",
      "summary": "Comparable protocols with one canonical source were found.",
      "evidence": ["https://github.com/example/prior-art"]
    },
    {
      "source": "github_code",
      "query": "Assert-ReuseDecision validator",
      "outcome": "results",
      "summary": "A validator separating structural and semantic checks was found.",
      "evidence": ["https://github.com/example/prior-art/blob/0123456789abcdef/validator.ps1"]
    },
    {
      "source": "primary_docs",
      "query": "json schema draft-07 oneOf",
      "outcome": "results",
      "summary": "Normative documentation confirms oneOf semantics for the frozen schema.",
      "evidence": ["https://json-schema.org/draft-07/json-schema-release-notes"]
    },
    {
      "source": "package_registry",
      "query": "reuse protocol powershell module",
      "outcome": "no_results",
      "summary": "No published module matches the contract, so no dependency is added.",
      "evidence": []
    }
  ],
  "candidates": [
    {
      "id": "prior-art-protocol",
      "url": "https://github.com/example/prior-art",
      "revision": "0123456789abcdef0123456789abcdef01234567",
      "decision": "reference",
      "rationale": "The document shape fits, but the implementation is out of scope.",
      "borrow": "The idea of one canonical source with thin native entrypoints.",
      "constraints": ["Do not copy external code.", "Keep the validator self-contained."]
    },
    {
      "id": "universal-framework",
      "url": "https://github.com/example/universal-framework",
      "revision": "main",
      "decision": "reject",
      "rationale": "Adds a framework and dependencies the plan forbids.",
      "borrow": "",
      "constraints": []
    }
  ],
  "strategy": "reference",
  "rationale": "Borrow the single-source idea only and implement the validator in this repository.",
  "constraints": ["No new dependency.", "Protocol stays independent of Team error codes."]
}
```

```json reuse-task
{
  "applicability": "required",
  "reason": "Introduces the shared reuse validator and a new protocol surface.",
  "change_kinds": ["new_implementation", "protocol"],
  "refs": ["prior-art-protocol"]
}
```

同一决策还覆盖一个新增依赖的任务：上面 `package_registry` 那条 `no_results` 是**成功**的注册表检索（答了话：没有可用的已发布模块），因此该任务在决策 `completed` 时合法。

```json reuse-task
{
  "applicability": "required",
  "reason": "Adds one dev-time dependency after a completed registry pass that found no publishable match.",
  "change_kinds": ["new_dependency"],
  "refs": ["prior-art-protocol"]
}
```

被引用的候选确实被使用：

```json reuse-result
{
  "references_used": ["prior-art-protocol"],
  "deviations": []
}
```

被引用但未使用时，必须解释：

```json reuse-result
{
  "references_used": [],
  "deviations": [
    {
      "reference": "prior-art-protocol",
      "reason": "The referenced revision was unreachable at implementation time; the local shape was rebuilt instead."
    }
  ]
}
```

### 6.3 阻塞（unavailable ⇒ 暂停）

```json reuse-decision
{
  "version": 1,
  "applicability": "required",
  "status": "blocked",
  "reason": "GitHub code search is unavailable, so the prior-art pass cannot complete.",
  "searches": [
    {
      "source": "github_repositories",
      "query": "reuse first prior art protocol",
      "outcome": "results",
      "summary": "Repository search answered with comparable projects.",
      "evidence": ["https://github.com/example/prior-art"]
    },
    {
      "source": "github_code",
      "query": "Assert-ReuseDecision validator",
      "outcome": "unavailable",
      "summary": "The code search endpoint refused the request.",
      "evidence": ["receipt: search-github-code-20260919T101500Z"]
    },
    {
      "source": "primary_docs",
      "query": "json schema draft-07 oneOf",
      "outcome": "no_results",
      "summary": "No normative page matched this exact query.",
      "evidence": []
    }
  ],
  "candidates": [],
  "strategy": "build",
  "rationale": "No candidate can be chosen until the unavailable search is repeated.",
  "constraints": ["Pause before creating any worker worktree.", "Resume needs an owner exception bound to the exact plan hash."]
}
```

```json reuse-task
{
  "applicability": "required",
  "reason": "The task adds new capability and cannot start while reuse is blocked.",
  "change_kinds": ["new_implementation"],
  "refs": []
}
```

### 6.4 完成但零结果（三个强制渠道全 `no_results` ⇒ 自建）

三个强制渠道都答了话、但都没有匹配：这是**有效**的完成决策（`no_results` 是成功），`candidates` 为空、`strategy = build`。`no_results` 允许引用一条收据（第一条），也允许为空数组（后两条）。

```json reuse-decision
{
  "version": 1,
  "applicability": "required",
  "status": "completed",
  "reason": "The plan adds a small local capability, so a prior-art pass was required before writing it.",
  "searches": [
    {
      "source": "github_repositories",
      "query": "tiny local capability prior art",
      "outcome": "no_results",
      "summary": "Repository search answered with no comparable project.",
      "evidence": ["receipt: search-github-repositories-20260919T110000Z"]
    },
    {
      "source": "github_code",
      "query": "tiny local capability implementation",
      "outcome": "no_results",
      "summary": "Code search answered with no reusable implementation.",
      "evidence": []
    },
    {
      "source": "primary_docs",
      "query": "tiny local capability normative shape",
      "outcome": "no_results",
      "summary": "No normative page matched this exact query.",
      "evidence": []
    }
  ],
  "candidates": [],
  "strategy": "build",
  "rationale": "Every mandatory channel answered with a zero result, so the smallest local shape is built.",
  "constraints": ["Keep the local shape minimal; re-check if a candidate appears later."]
}
```

```json reuse-task
{
  "applicability": "required",
  "reason": "Builds the small local capability; the prior-art pass found nothing reusable.",
  "change_kinds": ["new_implementation"],
  "refs": []
}
```

```json reuse-result
{
  "references_used": [],
  "deviations": []
}
```

## 7. API（dot-source 后可调用）

```powershell
. <protocol-root>/Reuse.ps1
```

| 入口 | 作用 |
| --- | --- |
| `Assert-ReuseDecision -Decision` | 校验计划级决策，返回规范化 hashtable |
| `Assert-ReuseTask -Decision -TaskReuse` | 校验任务级声明与决策的一致性 |
| `Get-ReuseContext -Decision -TaskReuse -PlanHash` | 生成给 worker 的有界 context（含身份与 plan hash） |
| `Assert-ReuseResult -Context -ResultReuse` | 校验真实使用与偏差完整性 |
| `Get-ReuseProtocolIdentity [-Root]` | 返回 `version` + 三文件确定性哈希 |

约定：

- 全部输入接受 hashtable / 有序字典 / `PSCustomObject`；返回值为规范化 hashtable（数组字段保证是数组）。
- `-PlanHash` 必须是非空、无首尾空格的字符串（Team 侧即 `plan.yaml` 的 SHA-256）；它按原样写入 context，不做任何归一化。
- `Get-ReuseContext` 对 `blocked` 决策同样正常返回：它只派生有界上下文，不承担准入判定；「blocked 时不得创建 worktree / worker」由运行器强制。
- 失败统一抛 `System.InvalidOperationException`，`Exception.Data['ReuseProtocolError'] = $true`，`Exception.Data['ReuseErrorKind']` ∈ `{load_error, protocol_incomplete, invalid_argument, invalid_decision, invalid_task, invalid_context, invalid_result}`，消息以 `reuse/<kind>: ` 开头且为英文。core 的错误**不使用** Team 退出码。
- 校验器无网络、无子进程、无临时文件、不读取任何 Team 状态。它的文件读取只有两类：① **每次 `Assert-*` / `Get-ReuseContext` 校验都会读取本目录的 `reuse.schema.json`** 作为结构兜底（文件缺失 ⇒ `protocol_incomplete`；schema 被改动即按改动后的 schema 判定，校验器不内置副本）；② `Get-ReuseProtocolIdentity` 读取并哈希本目录三个文件。两者都按 `Reuse.ps1` 所在目录解析，除此之外不做 I/O。

## 8. 责任与局限

- **机械准入由 Team 运行器负责**：core 只回答「这份声明是否自洽」，不负责在创建 worktree / 进程之前拦住执行；接入选址、暂停与例外绑定属运行器职责。
- **不推断真实性**：结构与交叉字段可以机械判定，「这条链接是否真的存在」「这次检索是否真的发生过」不能由 schema 推断，也不由本校验器声称。
- **不改变权限**：本协议不授权任何生产、凭据、网络或写范围变更；`deviation` 与 `blocked` 都只是声明。
- **不建立通用框架**：三种文档形状 + 五个入口即全部；新增形状或流程需要人类批准。
