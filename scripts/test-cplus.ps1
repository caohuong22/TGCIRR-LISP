$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Write-Host '[1/3] CPLUS regression tests' -ForegroundColor Cyan
dotnet run --project (Join-Path $root 'tests\CPLUS.Regression\CPLUS.Regression.csproj') -c Release
if($LASTEXITCODE-ne 0){throw 'CPLUS regression failed'}
Write-Host '[2/3] Build and package' -ForegroundColor Cyan
& (Join-Path $PSScriptRoot 'package.ps1');if($LASTEXITCODE-ne 0){throw 'Package failed'}
# Doi chieu dung cap build <-> bundle (moi ban CAD dung 1 TFM rieng),
# khong lay "file moi nhat" vi se lam lan giua net48 / net8 / net10.
$checks = @(
    @{ Built = 'src\ribbon\bin\Release\net48\TGIRR.Ribbon.dll';           Packaged = 'bundle\TGIRR_CAD_LISP.bundle\Contents\Windows\TGIRR.Ribbon.dll' },
    @{ Built = 'src\ribbon\bin\Release\net8.0-windows\TGIRR.Ribbon.dll';  Packaged = 'bundle\TGIRR_CAD_LISP.bundle\Contents\Windows\2026\TGIRR.Ribbon.dll' },
    @{ Built = 'src\ribbon\bin\Release\net10.0-windows\TGIRR.Ribbon.dll'; Packaged = 'bundle\TGIRR_CAD_LISP.bundle\Contents\Windows\2027\TGIRR.Ribbon.dll' }
)
foreach ($c in $checks) {
    $built = Join-Path $root $c.Built
    $packaged = Join-Path $root $c.Packaged
    if (-not (Test-Path $built)) { throw "Thieu DLL build: $($c.Built)" }
    if (-not (Test-Path $packaged)) { throw "Thieu DLL trong bundle: $($c.Packaged)" }
    if ((Get-FileHash $built).Hash -ne (Get-FileHash $packaged).Hash) { throw "DLL hash mismatch: $($c.Packaged)" }
    Write-Host "PASS: $($c.Packaged) == $($c.Built)" -ForegroundColor Green
}
