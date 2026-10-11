param()
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'port-config.ps1')

# Dan muc lenh (menu + ToolCatalog.generated.cs + bang docs) duoc sinh lai cho khop tools.json.
& (Join-Path $PSScriptRoot 'gen-catalog.ps1')

# Port src\ribbon + src\shared -> src\zwcad (va menu -> bundle ZWCAD).
$changed = Write-TgirrrPort 'ZWCAD'
if ($changed.Count -eq 0) {
    Write-Host 'Port ZWCAD: all files were already up to date.' -ForegroundColor Green
} else {
    Write-Host ("Port ZWCAD: {0} file(s) updated" -f $changed.Count) -ForegroundColor Yellow
    foreach ($c in $changed) { Write-Host ("  + " + $c) -ForegroundColor DarkGray }
}
