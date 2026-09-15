$repo = 'C:\Users\16097\Desktop\workflow'
Set-Location $repo
$f = Join-Path $repo 'docs\ai\last_test_run.txt'
$add = @'

---

# 第 6 轮：修 B-1（人类裁决：先只修 B-1 + 恢复 9B 跑一轮，用真实双审决定 B 能否收口）

人类 2026-09-06 裁决：走「重新拆任务」退出硬停；任务 B 的交付边界先不定，**只修 B-1、恢复 9B 跑一轮，拿到两份 verdict 后再决定**。

## AG. B-1 的修法与取证

**修法（比 9A 给的两条更彻底）**：不仅把 `tools/ac4-reasoning-effort-check.ps1` 登记进 §2.1 #25 与 §2.3，而且**把 `tools` 加进 AC6 的 scope**。理由：该脚本是 **AC4-门本身的实现**——若它既不在 scope 也不在登记表内，那么"把 `high` 从 `$allowed` 里去掉"这类**削弱第二道门的改动既不进账、也不触发 AC6**。9A 给的路线 (a)（只登记不扩 scope）会让这个洞留着：脚本被改了，scope 里却没有它。

**正向（scope 现含 `tools`）**：
```
reg=31  scope=31  →  register == scope  → GREEN (exit 0)
```
（第 5 轮是 `reg=30 scope=30`，因为当时 `tools` 既不在 scope 也不在登记表。）

**负向对照 NC-A（删掉 `tools/...` 的 §2.3 登记行，只改一个变量）**：
```
差异项 = 1  →  RED ✅ 抓到: tools/ac4-reasoning-effort-check.ps1
```

**负向对照 NC-B（削弱第二道门：把 `high` 从脚本的 `$allowed` 里去掉）**：
```
AC6 差异项 = 0  → GREEN
  （该文件已登记，故不红 —— 这正是修复的目的：它现在进账了）
AC4-门在该变异下: AC4: FAIL
```
→ 两条合起来证明：**"削弱第二道门"这个动作现在至少会进账**（要么被 AC4 判 FAIL，要么因未登记被 AC6 判红）；而在修复前，它可以悄无声息地发生。

**还原核验**：两次变异后均还原，`git status --porcelain` 回到只剩本轮正常改动；`$allowed` 行与 `- path: tools/...` 行均确认复原。
**脚本清理**：用于变异的一次性脚本已删除（`null` 参数误用与临时 `.tmp-*.ps1` 均已清）。

## AH. 本轮仍未处理（留给任务 B）

* **B-2**（AC4-门只枚举 20 处站点中的 7 处；域外取值写成反引号/散文/大写即可走 PASS）——按人类裁决**本轮不修**，等两份 verdict 后再定方向（加宽正则 vs 收窄声称）。
* **第 4 轮那条 `dispute`**（AC9 归类）仍未裁。
* **VN-B**：`TASK_BRIEF` AC1/AC10 引用的"第 3 轮 9A 全量核验 40 行"——Author 已打开 `docs/ai/review_9A_r3.md` 核实，`:43` 确有该结论（"Reviewer 逐行读完 40 行变更、未发现判据/阈值漂移 → AC1 实质满足"）→ **引用属实**，不是"把未做写成已做"。本条从悬置清单移除。
'@
Add-Content -LiteralPath $f -Value $add -Encoding utf8NoBOM
$b = [System.IO.File]::ReadAllBytes($f)
if ($b -contains 13) { $t = [System.IO.File]::ReadAllText($f) -replace "`r`n","`n" -replace "`r","`n"; [System.IO.File]::WriteAllText($f, $t, (New-Object System.Text.UTF8Encoding($false))) }
Write-Output "last_test_run 行数 = $((Get-Content $f).Count)"
git add -A
git commit -q -m "fix(register): put the second gate's own script on the books

B-1 was that the new gate script was neither in AC6's scope nor in the register,
so the gate report read green while the delivery surface was not covered. Register
it and widen the scope to include tools/, which also closes the hole that let the
gate itself be weakened with no ledger signal. Record both negative controls: one
proves a missing register line now goes red, the other proves weakening the gate
is now either counted or caught by AC4."
Write-Output "HEAD = $(git rev-parse HEAD)"
git status --porcelain
