param(
    [ValidateSet('All', 'AutoCAD', 'ZWCAD', 'GstarCAD', 'all', 'autocad', 'zwcad', 'gstarcad')]
    [string]$Target = 'All',
    [string]$AutoCADDir = ''
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

Write-Host ''
Write-Host '=============================================================' -ForegroundColor Cyan
Write-Host '          TGIRR CAD - BUILD & PACKAGE SCRIPT                 ' -ForegroundColor Cyan
Write-Host "          Muc tieu: $Target" -ForegroundColor Yellow
Write-Host '=============================================================' -ForegroundColor Cyan
Write-Host ''

$targetNorm = $Target.ToLowerInvariant()
$successList = @()

# -------------------------------------------------------------
# 1) AutoCAD: Co su dung Ribbon (TGIRR.Ribbon.dll)
# -------------------------------------------------------------
if ($targetNorm -in 'all', 'autocad') {
    Write-Host '-------------------------------------------------------------' -ForegroundColor DarkGray
    Write-Host '[1/3] AUTOCAD: Build Ribbon plugin & Dong goi bundle...' -ForegroundColor Cyan
    Write-Host '      (AutoCAD ho tro API Ribbon: Autodesk.Windows.RibbonTab)' -ForegroundColor DarkGray

    $acadProject = Join-Path $root 'src\ribbon\TGIRR.Ribbon.csproj'
    if ($AutoCADDir) {
        dotnet build $acadProject -c Release -p:AutoCADDir="$AutoCADDir"
    } else {
        dotnet build $acadProject -c Release
    }
    if ($LASTEXITCODE -ne 0) { throw "AutoCAD Ribbon build that bai voi ma loi $LASTEXITCODE" }

    $windowsTarget = Join-Path $root 'bundle\TGIRR_CAD_LISP.bundle\Contents\Windows'
    $win2024Target = Join-Path $windowsTarget '2024'
    $win2026Target = Join-Path $windowsTarget '2026'
    $win2027Target = Join-Path $windowsTarget '2027'
    if (-not (Test-Path $win2024Target)) { New-Item -ItemType Directory -Path $win2024Target -Force | Out-Null }
    if (-not (Test-Path $win2026Target)) { New-Item -ItemType Directory -Path $win2026Target -Force | Out-Null }
    if (-not (Test-Path $win2027Target)) { New-Item -ItemType Directory -Path $win2027Target -Force | Out-Null }

    $dllNet48 = Join-Path $root 'src\ribbon\bin\Release\net48\TGIRR.Ribbon.dll'
    $dllNet8  = Join-Path $root 'src\ribbon\bin\Release\net8.0-windows\TGIRR.Ribbon.dll'
    $dllNet10 = Join-Path $root 'src\ribbon\bin\Release\net10.0-windows\TGIRR.Ribbon.dll'

    if (Test-Path $dllNet48) {
        Copy-Item $dllNet48 (Join-Path $win2024Target 'TGIRR.Ribbon.dll') -Force
        # Cung cấp bản .NET 4.8 làm fallback tại thư mục gốc Windows\
        Copy-Item $dllNet48 (Join-Path $windowsTarget 'TGIRR.Ribbon.dll') -Force
    }
    if (Test-Path $dllNet8) {
        Copy-Item $dllNet8 (Join-Path $win2026Target 'TGIRR.Ribbon.dll') -Force
    }
    if (Test-Path $dllNet10) {
        Copy-Item $dllNet10 (Join-Path $win2027Target 'TGIRR.Ribbon.dll') -Force
    }

    $lispSource = Join-Path $root 'src\lisp'
    $lispTarget = Join-Path $root 'bundle\TGIRR_CAD_LISP.bundle\Contents\Lisp'
    if (-not (Test-Path $lispTarget)) { New-Item -ItemType Directory -Path $lispTarget -Force | Out-Null }
    $allowed = @('SBS.lsp','TL.lsp','TGL.lsp','TGN.lsp','TGN.dcl','HBD.lsp','DOITEXT.lsp','TGIRRLoader.lsp')
    Get-ChildItem $lispTarget -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in '.lsp','.dcl' } | Remove-Item -Force
    foreach ($file in $allowed) {
        Copy-Item (Join-Path $lispSource $file) $lispTarget -Force
    }

    Write-Host "  -> AutoCAD Bundle san sang: bundle\TGIRR_CAD_LISP.bundle" -ForegroundColor Green
    $successList += 'AutoCAD (Ribbon)'

    # Tu dong dong bo sang thu muc ApplicationPlugins neu co
    & (Join-Path $PSScriptRoot 'sync-bundle.ps1')
}

# -------------------------------------------------------------
# 2) ZWCAD: KHONG DUNG RIBBON (Dung Palette TGIRRPALETTE + Menu)
# -------------------------------------------------------------
if ($targetNorm -in 'all', 'zwcad') {
    Write-Host '-------------------------------------------------------------' -ForegroundColor DarkGray
    Write-Host '[2/3] ZWCAD: Build .NET net48 (KHONG DUNG RIBBON)...' -ForegroundColor Cyan
    Write-Host '      (ZWCAD dung PaletteSet TGIRRPALETTE + Menu TGIRR_CAD.mnu)' -ForegroundColor DarkGray

    & (Join-Path $PSScriptRoot 'package-zwcad.ps1')
    if ($LASTEXITCODE -ne 0) { throw "ZWCAD package that bai voi ma loi $LASTEXITCODE" }
    $successList += 'ZWCAD (Palette + Menu, Khong Ribbon)'
}

# -------------------------------------------------------------
# 3) GstarCAD: KHONG DUNG RIBBON (Dung Palette TGIRRPALETTE + Menu)
# -------------------------------------------------------------
if ($targetNorm -in 'all', 'gstarcad') {
    Write-Host '-------------------------------------------------------------' -ForegroundColor DarkGray
    Write-Host '[3/3] GstarCAD: Build .NET net8.0 (KHONG DUNG RIBBON)...' -ForegroundColor Cyan
    Write-Host '      (GstarCAD dung PaletteSet TGIRRPALETTE + Menu TGIRR_CAD.mnu)' -ForegroundColor DarkGray

    & (Join-Path $PSScriptRoot 'package-gscad.ps1')
    if ($LASTEXITCODE -ne 0) { throw "GstarCAD package that bai voi ma loi $LASTEXITCODE" }
    $successList += 'GstarCAD (Palette + Menu, Khong Ribbon)'
}

Write-Host ''
Write-Host '=============================================================' -ForegroundColor Green
Write-Host '  DONG GOI THANH CONG CAC NEN TANG CAD:' -ForegroundColor Green
foreach ($s in $successList) {
    Write-Host "    [OK] $s" -ForegroundColor White
}
Write-Host '=============================================================' -ForegroundColor Green
Write-Host ''
