# The production adapter launches Codex; this fixture proves gate wiring only.
if ($args -contains '--version') { Write-Output 'codex-cli 0.153.3'; exit 0 }
$index = [array]::IndexOf($args, '-o')
if ($index -lt 0) { exit 2 }
@{verdict='pass';blocking_issues=@();verification_needed=@();writes_performed=$false;caused_by_last_fix='no'} |
    ConvertTo-Json | Set-Content -LiteralPath $args[$index+1] -Encoding utf8NoBOM
Write-Output '{"type":"fixture_review"}'
