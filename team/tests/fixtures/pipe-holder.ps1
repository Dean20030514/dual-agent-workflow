param([ValidateSet('Parent','Child')][string]$Mode='Parent', [int]$Delay=30, [Parameter(Mandatory)][string]$Receipt, [switch]$Silent)
$ErrorActionPreference='Stop'
if ($Mode -eq 'Child') {
    [IO.File]::WriteAllText($Receipt + '.ready','ready')
    Start-Sleep -Seconds $Delay
    exit 0
}
$info=[Diagnostics.ProcessStartInfo]::new((Get-Command pwsh).Source)
$info.UseShellExecute=$false; $info.CreateNoWindow=$true
foreach ($arg in @('-NoProfile','-File',$PSCommandPath,'-Mode','Child','-Delay',[string]$Delay,'-Receipt',$Receipt)) { $info.ArgumentList.Add($arg) }
$child=[Diagnostics.Process]::Start($info)
@{pid=$child.Id;start=$child.StartTime.ToUniversalTime().ToString('o')} | ConvertTo-Json | Set-Content -LiteralPath $Receipt -Encoding utf8NoBOM
$deadline=[DateTime]::UtcNow.AddSeconds(5)
while (-not (Test-Path -LiteralPath ($Receipt + '.ready'))) {
    if ([DateTime]::UtcNow -ge $deadline) { $child.Kill($true); throw 'Fixture child did not become ready' }
    Start-Sleep -Milliseconds 20
}
if (-not $Silent) { [Console]::Out.WriteLine('parent output retained') }
exit 0
