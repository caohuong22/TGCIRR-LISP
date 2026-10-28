param([switch]$AssetsPrepared)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

if (-not $AssetsPrepared) {
  & (Join-Path $PSScriptRoot 'prepare-package-assets.ps1')
}

# 1) Build the ZWCAD .NET plugin (net48)
$zwProject = Join-Path $root 'src\zwcad\TGIRR.Zwcad.csproj'
dotnet build $zwProject -c Release
if ($LASTEXITCODE -ne 0) { throw "ZWCAD plugin build failed with exit code $LASTEXITCODE" }

# Regenerate ported sources (namespace mapping + ctor patches) and rebuild once
# more to guarantee sources & binary are in sync with src/ribbon.
& (Join-Path $PSScriptRoot 'port-zwcad.ps1')
dotnet build $zwProject -c Release
if ($LASTEXITCODE -ne 0) { throw "ZWCAD plugin build failed after port sync" }

$builtDll = Join-Path $root 'src\zwcad\bin\Release\TGIRR.Zwcad.dll'
if (-not (Test-Path $builtDll)) { throw "Khong tim thay TGIRR.Zwcad.dll da build" }

# 2) Assemble bundle
$bundle = Join-Path $root 'bundle\TGIRR_CAD_ZWCAD.bundle'
$lispDir  = Join-Path $bundle 'Contents\Lisp'
$winDir   = Join-Path $bundle 'Contents\Windows'
New-Item -ItemType Directory -Force -Path $lispDir, $winDir | Out-Null

# Danh sach file LISP suy ra tu src/catalog/tools.json (scripts/package-config.ps1)
. (Join-Path $PSScriptRoot 'package-config.ps1')
$allowedLisp = Get-TgirrrLispFiles 'TGIRRLoaderZ.lsp'
Get-ChildItem $lispDir -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in '.lsp','.dcl' } | Remove-Item -Force
Get-ChildItem $lispDir -File -Filter '*.bmp' -ErrorAction SilentlyContinue | Remove-Item -Force
foreach ($f in $allowedLisp) {
  Copy-Item (Join-Path $root "src\lisp\$f") $lispDir -Force
}

# Menu support (TGIRR_CAD.mnu/.mnl): MENULOAD in ZWCAD to add the pull-down menu.
Copy-Item (Join-Path $root 'src\menu\TGIRR_CAD.mnu') $lispDir -Force
Copy-Item (Join-Path $root 'src\menu\TGIRR_CAD.mnl') $lispDir -Force
# Icon BMP cho toolbar native (***TOOLBARS) - phai nam cung thu muc .mnu
Copy-Item (Join-Path $root 'src\menu\icons\*.bmp') $lispDir -Force

# Dictionary copy conveniences:
# A ZWCAD bundle has no PackageContents equivalent for C#; the loader (TGIRRLoaderZ.lsp)
# calls NETLOAD on the DLL. DLL is copied here for a single-folder self-contained package.
Copy-Item $builtDll $winDir -Force

# 3) Write a simple README for the bundle
$readme = @'
# TGIRR CAD cho ZWCAD

## Cai dat
1. Build: chay scripts/package-zwcad.ps1
2. Copy thu muc Contents vao thu muc luu lisp (vi du C:\Users\<user>\AppData\Roaming\ZWSOFT\ZWCAD\2026\en-US\Support hoac mot thu muc tim duoc trong Support File Search Path).
3. Mo ZWCAD, go APPLOAD va chon TGIRRLoaderZ.lsp, hoac go (load "TGIRRLoaderZ.lsp").
4. Go TGIRRLOAD de nap day du (SBS, HBD, DOITEXT + CPLUS, VDNG, TNET, TL, TGL, CVPL, TGN) - bang cong cu TGIRR CAD tu mo.
5. (Tuy chon) go MENULOAD va chon TGIRR_CAD.mnu de them menu keo xuong TGIRR CAD.

## Lenh
- TGIRRPALETTE: mo/dong bang cong cu TGIRR CAD (PaletteSet)
- SBS  : chon doi tuong giong mau trong bien kin (LISP)
- HBD  : ve duong bao boundary cho hatch co (LISP, lenh tat BH/TGBOUND)
- TL   : tong chieu dai (.NET)
- TGL  : tao bo layer chuan (.NET)
- TGN  : danh so doi tuong/vung tuoi (.NET)
- CVPL : convert LINE/ARC/CIRCLE/ELLIPSE/SPLINE/POLYLINE/REGION sang Polyline (.NET)
- CPLUS: copy theo quy luat (.NET)
- VDNG : rai day nho giot (.NET)
- TNET : tao net ve co chu (.NET)

Luu y: ZWCAD KHONG DUNG RIBBON (khong co API Ribbon lap trinh duoc nhu AutoCAD); thay vao do dung bang cong cu TGIRRPALETTE (dockable WPF PaletteSet) hoac menu keo xuong TGIRR_CAD.mnu (MENULOAD).
'@
[System.IO.File]::WriteAllText((Join-Path $bundle 'README_ZWCAD.txt'), $readme, (New-Object System.Text.UTF8Encoding($false)))

Write-Host "Bundle ZWCAD san sang: $bundle" -ForegroundColor Green
Get-ChildItem $bundle -Recurse -File | ForEach-Object { Write-Host ("  " + $_.FullName.Substring($bundle.Length + 1)) }
