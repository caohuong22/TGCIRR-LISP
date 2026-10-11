param()
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'port-config.ps1')

# Dan muc lenh (menu + ToolCatalog.generated.cs + bang docs) duoc sinh lai cho khop tools.json.
& (Join-Path $PSScriptRoot 'gen-catalog.ps1')

# Port src\ribbon + src\shared -> src\gscad.
# Danh muc lenh (menu + ToolCatalog.generated.cs) phai duoc cap nhat truoc do,
# bang cach chay scripts\gen-catalog.ps1 (test-palette.ps1 kiem tra buoc nay).
$changed = Write-TgirrrPort 'GstarCAD'
if ($changed.Count -eq 0) {
    Write-Host 'Port GstarCAD: all files were already up to date.' -ForegroundColor Green
} else {
    Write-Host ("Port GstarCAD: {0} file(s) updated" -f $changed.Count) -ForegroundColor Yellow
    foreach ($c in $changed) { Write-Host ("  + " + $c) -ForegroundColor DarkGray }
}
