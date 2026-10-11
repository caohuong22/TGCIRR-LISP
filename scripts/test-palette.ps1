param()
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

# ===========================================================================
# test-palette.ps1 - Chu kiem tra "mot nguon that" cua giao dien TGIRR:
#   [1/4] src/catalog/tools.json -> menu + ToolCatalog + docs (khong duoc lech)
#   [2/4] src/ribbon + src/shared -> src/zwcad + src/gscad (khong duoc lech)
#   [3/4] Palette.Regression (danh muc, menu, docs, Ribbon, state stores)
#   [4/4] VDNG.Regression (giu nguyen batch lenh cu)
# Chay: powershell -File scripts\test-palette.ps1
# ===========================================================================

Write-Host '[1/4] Kiem tra catalog (tools.json -> menu/docs/ToolCatalog)' -ForegroundColor Cyan
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'gen-catalog.ps1') -Check
if ($LASTEXITCODE -ne 0) { throw 'Catalog drift: chay scripts/gen-catalog.ps1 roi commit lai dau ra.' }

Write-Host '[2/4] Kiem tra ban port ZWCAD / GstarCAD' -ForegroundColor Cyan
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'port-verify.ps1')
if ($LASTEXITCODE -ne 0) { throw 'Port drift: chay scripts/port-zwcad.ps1 va scripts/port-gscad.ps1.' }

Write-Host '[3/4] Chay Palette.Regression' -ForegroundColor Cyan
dotnet run --project (Join-Path $root 'tests\Palette.Regression') -c Release
if ($LASTEXITCODE -ne 0) { throw 'Palette.Regression that bai' }

Write-Host '[4/4] Chay VDNG.Regression (batch lenh cu)' -ForegroundColor Cyan
dotnet run --project (Join-Path $root 'tests\VDNG.Regression') -c Release
if ($LASTEXITCODE -ne 0) { throw 'VDNG.Regression that bai' }

Write-Host ''
Write-Host 'TEST PALETTE: PASSED' -ForegroundColor Green
