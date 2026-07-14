$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Write-Host '[1/3] VDNG regression tests' -ForegroundColor Cyan
dotnet run --project (Join-Path $root 'tests\VDNG.Regression\VDNG.Regression.csproj') -c Release
if($LASTEXITCODE-ne 0){throw 'VDNG regression failed'}
Write-Host '[2/3] Build and package' -ForegroundColor Cyan
& (Join-Path $PSScriptRoot 'package.ps1')
if($LASTEXITCODE-ne 0){throw 'Package failed'}
Write-Host '[3/3] Verify DLL hashes' -ForegroundColor Cyan
$a=Get-FileHash (Join-Path $root 'src\ribbon\bin\Release\net48\TGIRR.Ribbon.dll')
$b=Get-FileHash (Join-Path $root 'bundle\TGIRR_CAD_LISP.bundle\Contents\Windows\TGIRR.Ribbon.dll')
if($a.Hash-ne$b.Hash){throw 'Packaged DLL hash mismatch'}
Write-Host "PASS: DLL SHA256 $($a.Hash)" -ForegroundColor Green
