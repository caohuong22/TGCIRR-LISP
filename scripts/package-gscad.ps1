param()
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

# 1) Build the GstarCAD .NET plugin (net8.0)
$gscadProject = Join-Path $root 'src\gscad\TGIRR.Gscad.csproj'
dotnet build $gscadProject -c Release
if ($LASTEXITCODE -ne 0) { throw "GstarCAD plugin build failed with exit code $LASTEXITCODE" }

# Regenerate ported sources (namespace mapping) and rebuild once more to
# guarantee sources & binary are in sync with src/ribbon.
& (Join-Path $PSScriptRoot 'port-gscad.ps1')
dotnet build $gscadProject -c Release
if ($LASTEXITCODE -ne 0) { throw "GstarCAD plugin build failed after port sync" }

$builtDll = Join-Path $root 'src\gscad\bin\Release\TGIRR.Gscad.dll'
if (-not (Test-Path $builtDll)) { throw "Khong tim thay TGIRR.Gscad.dll da build" }

# 2) Assemble bundle
$bundle = Join-Path $root 'bundle\TGIRR_CAD_GSTARCAD.bundle'
$lispDir  = Join-Path $bundle 'Contents\Lisp'
$winDir   = Join-Path $bundle 'Contents\Windows'
New-Item -ItemType Directory -Force -Path $lispDir, $winDir | Out-Null

# LISP files (same as AutoCAD version, plus the GstarCAD loader)
$allowedLisp = @('SBS.lsp','TL.lsp','TGL.lsp','TGN.lsp','TGN.dcl','TGIRRLoaderG.lsp')
Get-ChildItem $lispDir -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in '.lsp','.dcl' } | Remove-Item -Force
foreach ($f in $allowedLisp) {
  Copy-Item (Join-Path $root "src\lisp\$f") $lispDir -Force
}

# Menu support (TGIRR_CAD.mnu/.mnl): MENULOAD in GstarCAD to add the pull-down menu.
Copy-Item (Join-Path $root 'src\menu\TGIRR_CAD.mnu') $lispDir -Force
Copy-Item (Join-Path $root 'src\menu\TGIRR_CAD.mnl') $lispDir -Force

# GstarCAD bundle has no PackageContents equivalent for C#; the loader
# (TGIRRLoaderG.lsp) calls NETLOAD on the DLL. DLL is copied here for a
# single-folder self-contained package.
Copy-Item $builtDll $winDir -Force

# 3) Write a simple README for the bundle
$readme = @'
# TGIRR CAD cho GstarCAD

## Cai dat
1. Build: chay scripts/package-gscad.ps1
2. Copy thu muc Contents vao thu muc luu lisp (vi du C:\Users\<user>\AppData\Roaming\Gstarsoft\GstarCAD\<version>\en-US\Support hoac mot thu muc tim duoc trong Support File Search Path).
3. Mo GstarCAD, go APPLOAD va chon TGIRRLoaderG.lsp, hoac go (load "TGIRRLoaderG.lsp").
4. Go TGIRRLOAD de nap day du (SBS, TL, TGL, TGN + CPLUS, VDNG, TNET) - bang cong cu TGIRR CAD tu mo.
5. (Tuy chon) go MENULOAD va chon TGIRR_CAD.mnu de them menu keo xuong TGIRR CAD.

## Lenh
- TGIRRPALETTE: mo/dong bang cong cu TGIRR CAD (PaletteSet)
- SBS  : chon doi tuong giong mau trong bien kin (LISP)
- TL   : tong chieu dai (LISP)
- TGL  : tao bo layer chuan (LISP)
- TGN  : danh so doi tuong/vung tuoi (LISP + DCL)
- CPLUS: copy theo quy luat (.NET)
- VDNG : rai day nho giot (.NET)
- TNET : tao net ve co chu (.NET)

Luu y: GstarCAD nap DLL .NET bang NETLOAD; cac lenh .NET go bang ten truc tiep, qua bang cong cu TGIRRPALETTE, hoac qua menu keo xuong TGIRR_CAD.mnu (MENULOAD).
'@
[System.IO.File]::WriteAllText((Join-Path $bundle 'README_GSTARCAD.txt'), $readme, (New-Object System.Text.UTF8Encoding($false)))

Write-Host "Bundle GstarCAD san sang: $bundle" -ForegroundColor Green
Get-ChildItem $bundle -Recurse -File | ForEach-Object { Write-Host ("  " + $_.FullName.Substring($bundle.Length + 1)) }