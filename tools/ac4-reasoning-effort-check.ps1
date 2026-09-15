$ErrorActionPreference = 'Stop'
$repo = 'C:\Users\16097\Desktop\workflow'
Set-Location $repo
$adapter = (Get-ChildItem "$env:LOCALAPPDATA\npm-cache\_npx\*\node_modules\@deepseek-ai\dsh-llm-deepseek\lib\index.js" | Select-Object -First 1).FullName

# 输入域 = 仅 DSH 面（AC4 声明）；排除 claude/** 与 portable/通用prompt-v3.8.txt
$files = @()
$files += (Get-ChildItem dsh -Recurse -File -Include *.md,*.txt).FullName
$files += (Resolve-Path 'portable\通用prompt-DSH-v1.txt').Path
$files += (Resolve-Path 'README.md').Path

$allowed = @('off','low','high','max')
$vals = @()
# Assignment sites are matched for both spellings of the key: reasoning_effort and reasoningEffort.
foreach ($f in $files) {
  $m = (Select-String -Path $f -Pattern 'reasoning_?[Ee]ffort`?\s*[:=]\s*"?([A-Za-z]+)"?' -AllMatches).Matches
  foreach ($x in $m) { if ($x.Groups.Count -ge 2 -and $x.Groups[1].Value) { $vals += $x.Groups[1].Value } }
}
$vals = $vals | Sort-Object -Unique
$bad = @($vals | Where-Object { $_ -notin $allowed })
$mediumHits = (Select-String -Path $adapter -Pattern '"medium"').Count

Write-Output "adapter            = $adapter"
Write-Output "DSH-side values    = $($vals -join ', ')"
Write-Output "out-of-domain      = $(if($bad){$bad -join ', '}else{'(none)'})"
Write-Output "adapter medium hits= $mediumHits"

if ($bad.Count -gt 0 -or $mediumHits -ne 0) { Write-Output 'AC4: FAIL'; exit 1 } else { Write-Output 'AC4: PASS'; exit 0 }
