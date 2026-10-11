$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Write-Host '[1/3] VDNG regression tests' -ForegroundColor Cyan
dotnet run --project (Join-Path $root 'tests\VDNG.Regression\VDNG.Regression.csproj') -c Release
if($LASTEXITCODE-ne 0){throw 'VDNG regression failed'}
Write-Host '[2/3] Build and package' -ForegroundColor Cyan
& (Join-Path $PSScriptRoot 'package.ps1')
if($LASTEXITCODE-ne 0){throw 'Package failed'}
Write-Host '[3/3] Verify DLL hashes' -ForegroundColor Cyan
# Moi ban CAD dung 1 TFM khac nhau (AutoCAD 2024 = net48, 2026 = net8, 2027 = net10) nen phai doi chieu
# dung cap build <-> bundle thay vi lay DLL moi nhat.
$checks = @(
    @{ Built = 'src\ribbon\bin\Release\net48\TGIRR.Ribbon.dll';              Packaged = 'bundle\TGIRR_CAD_LISP.bundle\Contents\Windows\2024\TGIRR.Ribbon.dll' },
    @{ Built = 'src\ribbon\bin\Release\net48\TGIRR.Ribbon.dll';              Packaged = 'bundle\TGIRR_CAD_LISP.bundle\Contents\Windows\TGIRR.Ribbon.dll' },
    @{ Built = 'src\ribbon\bin\Release\net8.0-windows\TGIRR.Ribbon.dll';     Packaged = 'bundle\TGIRR_CAD_LISP.bundle\Contents\Windows\2026\TGIRR.Ribbon.dll' },
    @{ Built = 'src\ribbon\bin\Release\net10.0-windows\TGIRR.Ribbon.dll';    Packaged = 'bundle\TGIRR_CAD_LISP.bundle\Contents\Windows\2027\TGIRR.Ribbon.dll' },
    @{ Built = 'src\zwcad\bin\Release\TGIRR.Zwcad.dll';                      Packaged = 'bundle\TGIRR_CAD_ZWCAD.bundle\Contents\Windows\TGIRR.Zwcad.dll' },
    @{ Built = 'src\gscad\bin\Release\TGIRR.Gscad.dll';                      Packaged = 'bundle\TGIRR_CAD_GSTARCAD.bundle\Contents\Windows\TGIRR.Gscad.dll' }
)
foreach ($c in $checks) {
    $built = Join-Path $root $c.Built
    $packaged = Join-Path $root $c.Packaged
    if (-not (Test-Path $built)) { throw "Thieu DLL build: $($c.Built)" }
    if (-not (Test-Path $packaged)) { throw "Thieu DLL trong bundle: $($c.Packaged)" }
    $a = Get-FileHash $built
    $b = Get-FileHash $packaged
    if ($a.Hash -ne $b.Hash) { throw "Packaged DLL hash mismatch: $($c.Packaged)" }
    Write-Host "PASS: $($c.Packaged) == $($c.Built)" -ForegroundColor Green
}
Write-Host 'PASS: toan bo DLL trong bundle khop ban build moi nhat' -ForegroundColor Green
