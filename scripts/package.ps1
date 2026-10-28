param(
    [ValidateSet('All', 'AutoCAD', 'ZWCAD', 'GstarCAD', 'all', 'autocad', 'zwcad', 'gstarcad')]
    [string]$Target = 'All',
    [string]$AutoCADDir = '',
    # Bo qua kiem tra CAD dang chay (dung cho CI hoac khi chi build bundle).
    [switch]$AllowRunningCad
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

# --- Kiem tra truoc khi build (bao loi ro rang thay vi MSBuild treo) ---------
function Test-Prerequisite {
    if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
        throw 'Khong tim thay .NET SDK (dotnet). Cai .NET SDK 8.0 tro len: https://dot.net/download'
    }
    $sdk = (& dotnet --version) 2>$null
    Write-Host ("  dotnet SDK {0}" -f $sdk) -ForegroundColor DarkGray

    $targets = @()
    if ($Target -in 'All', 'all', 'AutoCAD', 'autocad') { $targets += 'autocad' }
    if ($Target -in 'All', 'all', 'ZWCAD', 'zwcad') { $targets += 'zwcad' }
    if ($Target -in 'All', 'all', 'GstarCAD', 'gstarcad') { $targets += 'gscad' }

    if ($targets -contains 'autocad') {
        # 3 TFM can 3 bo DLL CAD khac nhau trong Reference\ (bi gitignore ~155MB).
        $needed = @()
        if (-not $AutoCADDir) {
            $needed += @{ Tfm = 'net48'; Dir = 'Reference\Cad2023\net48'; File = 'acmgd.dll' }
            $needed += @{ Tfm = 'net8.0'; Dir = 'Reference\Cad2026\net8.0'; File = 'acmgd.dll' }
            $needed += @{ Tfm = 'net10.0'; Dir = 'Reference\Cad2027'; File = 'acmgd.dll' }
        }
        $missing = @()
        foreach ($n in $needed) {
            if (-not (Test-Path (Join-Path $root (Join-Path $n.Dir $n.File)))) { $missing += ("{0} ({1})" -f $n.Tfm, $n.Dir) }
        }
        if ($missing.Count -gt 0) {
            throw @"
Thieu DLL tham chieu cua AutoCAD (thu muc Reference\ bi gitignore, ~155MB):
  $($missing -join "`r`n  ")

Cach xu ly:
  1. Copy thu muc DLL AutoCAD vao Reference\ (Cad2023\net48, Cad2026\net8.0, Cad2027),
     hoac
  2. Tro thang toi ban CAD da cai tren may:
       scripts\package.ps1 -Target AutoCAD -AutoCADDir 'C:\Program Files\Autodesk\AutoCAD 2025\'
     (chi dung duoc 1 TFM; build ca 3 TFM can du 3 bo DLL)
"@
        }
    }

    foreach ($p in @(@{t='zwcad'; proc='ZWCAD'; dir='Reference\Zwcad\net47'; file='ZwManaged.dll'}, @{t='gscad'; proc='gcad'; dir='Reference\gstarCad'; file='GcMgd.dll'})) {
        if ($targets -contains $p.t) {
            if (-not (Test-Path (Join-Path $root (Join-Path $p.dir $p.file)))) {
                Write-Host ("  (!) Thieu {0}\{1} - se dung DLL cai san cua CAD neu tim thay" -f $p.dir, $p.file) -ForegroundColor Yellow
            }
        }
    }

    if (-not $AllowRunningCad) {
        $running = @()
        foreach ($p in @('acad', 'ZWCAD', 'gcad')) {
            if (Get-Process -Name $p -ErrorAction SilentlyContinue) { $running += $p }
        }
        if ($running.Count -gt 0) {
            Write-Host ("  (!) {0} dang chay: DLL trong ApplicationPlugins co the khong copy duoc." -f ($running -join ', ')) -ForegroundColor Yellow
            Write-Host '      Dong CAD truoc khi dong goi, hoac them -AllowRunningCad de bo qua canh bao nay.' -ForegroundColor Yellow
        }
    }
}

Write-Host '--- Kiem tra moi truong build ---' -ForegroundColor DarkGray
Test-Prerequisite

# Tao lai menu, icon native va catalog tu tools.json truoc khi dong goi.
# Nho vay bundle luon nhan cac nut moi cua Quick Tools va TGIRRBAR.
& (Join-Path $PSScriptRoot 'prepare-package-assets.ps1')

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
    # Danh sach file LISP suy ra tu src/catalog/tools.json (scripts/package-config.ps1)
    . (Join-Path $PSScriptRoot 'package-config.ps1')
    $allowed = Get-TgirrrLispFiles 'TGIRRLoader.lsp'
    Get-ChildItem $lispTarget -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in '.lsp','.dcl' } | Remove-Item -Force
    Get-ChildItem $lispTarget -File -Filter '*.bmp' -ErrorAction SilentlyContinue | Remove-Item -Force
    foreach ($file in $allowed) {
        Copy-Item (Join-Path $lispSource $file) $lispTarget -Force
    }
    # Menu + icon cho thanh cong cu native (lenh TGIRRBAR)
    Copy-Item (Join-Path $root 'src\menu\TGIRR_CAD.mnu') $lispTarget -Force
    Copy-Item (Join-Path $root 'src\menu\TGIRR_CAD.mnl') $lispTarget -Force
    Copy-Item (Join-Path $root 'src\menu\icons\*.bmp') $lispTarget -Force

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

    & (Join-Path $PSScriptRoot 'package-zwcad.ps1') -AssetsPrepared
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

    & (Join-Path $PSScriptRoot 'package-gscad.ps1') -AssetsPrepared
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
