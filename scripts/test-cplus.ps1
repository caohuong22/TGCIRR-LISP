$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Write-Host '[1/3] CPLUS regression tests' -ForegroundColor Cyan
dotnet run --project (Join-Path $root 'tests\CPLUS.Regression\CPLUS.Regression.csproj') -c Release
if($LASTEXITCODE-ne 0){throw 'CPLUS regression failed'}
Write-Host '[2/3] Build and package' -ForegroundColor Cyan
& (Join-Path $PSScriptRoot 'package.ps1');if($LASTEXITCODE-ne 0){throw 'Package failed'}
$builtDll = Get-ChildItem (Join-Path $root 'src\ribbon\bin\Release') -Filter 'TGIRR.Ribbon.dll' -Recurse -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$a = Get-FileHash $builtDll.FullName
$b = Get-FileHash (Join-Path $root 'bundle\TGIRR_CAD_LISP.bundle\Contents\Windows\TGIRR.Ribbon.dll')
if ($a.Hash -ne $b.Hash) { throw 'DLL hash mismatch' }
Write-Host "PASS: DLL SHA256 $($a.Hash) ($($builtDll.Directory.Name))" -ForegroundColor Green
