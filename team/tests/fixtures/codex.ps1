# The production adapter launches Codex; this fixture proves gate wiring only.
if ($args -contains '--version') { Write-Output 'codex-cli 0.153.3'; exit 0 }
$index = [array]::IndexOf($args, '-o')
if ($index -lt 0) { exit 2 }
@($args) | ConvertTo-Json | Set-Content -LiteralPath (Join-Path (Split-Path $args[$index+1] -Parent) 'invocation.json') -Encoding utf8NoBOM
$prompt=[Console]::In.ReadToEnd()
if ($prompt -match 'FIXTURE_REVIEW_FLOOD') { [Console]::Out.Write('x' * 2MB) }
$stage=[regex]::Match($prompt,'(?m)^Stage: (9[APB])').Groups[1].Value
$issues=@()
if ($stage -eq '9A') {
    if ($prompt -match 'FIXTURE_REVIEW_MIXED') { $causes=@('yes','no') }
    elseif ($prompt -match 'FIXTURE_REVIEW_YES') { $causes=@('yes') }
    elseif ($prompt -match 'FIXTURE_REVIEW_DISPUTE') { $causes=@('dispute') }
    elseif ($prompt -match 'FIXTURE_REVIEW_NO') { $causes=@('no') }
    else { $causes=@() }
    foreach ($cause in $causes) { $issues+=@{id="fixture-$cause";consequence="Fixture product defect ($cause)";evidence='Synthetic review input/output counterexample';caused_by_last_fix=$cause} }
}
@{verdict=$(if ($issues.Count) {'fail'} else {'pass'});blocking_issues=$issues;verification_needed=@();writes_performed=$false} |
    ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $args[$index+1] -Encoding utf8NoBOM
Write-Output '{"type":"fixture_review"}'
