$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

Write-Host '[1/5] LayerSet regression (TGL/TGLADD + TL)' -ForegroundColor Cyan
dotnet run --project (Join-Path $root 'tests\LayerSet.Regression\LayerSet.Regression.csproj') -c Release
if ($LASTEXITCODE -ne 0) { throw 'LayerSet regression failed' }

Write-Host '[2/5] CVPL regression (bulge, dao chieu, noi manh)' -ForegroundColor Cyan
dotnet run --project (Join-Path $root 'tests\CVPL.Regression\CVPL.Regression.csproj') -c Release
if ($LASTEXITCODE -ne 0) { throw 'CVPL regression failed' }

Write-Host '[3/5] TGN regression (sap xep, duong dan)' -ForegroundColor Cyan
dotnet run --project (Join-Path $root 'tests\TGN.Regression\TGN.Regression.csproj') -c Release
if ($LASTEXITCODE -ne 0) { throw 'TGN regression failed' }

Write-Host '[4/5] TNET regression (doc/ghi file LIN)' -ForegroundColor Cyan
dotnet run --project (Join-Path $root 'tests\TNET.Regression\TNET.Regression.csproj') -c Release
if ($LASTEXITCODE -ne 0) { throw 'TNET regression failed' }

Write-Host '[5/5] Kiem tra port ZWCAD / GstarCAD khong lech' -ForegroundColor Cyan
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'port-verify.ps1')
if ($LASTEXITCODE -ne 0) { throw 'Port drift: chay scripts/port-zwcad.ps1 va scripts/port-gscad.ps1.' }

Write-Host ''
Write-Host 'TEST NATIVE: PASSED' -ForegroundColor Green