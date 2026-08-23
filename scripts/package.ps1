param([string]$AutoCADDir='')
$ErrorActionPreference = 'Stop'
$project = "$PSScriptRoot\..\src\ribbon\TGIRR.Ribbon.csproj"

if ($AutoCADDir) {
    dotnet build $project -c Release -p:AutoCADDir="$AutoCADDir"
} else {
    dotnet build $project -c Release
}
if ($LASTEXITCODE -ne 0) { throw "Ribbon build failed with exit code $LASTEXITCODE" }

$binRelease = "$PSScriptRoot\..\src\ribbon\bin\Release"
$builtDll = Get-ChildItem -Path $binRelease -Filter "TGIRR.Ribbon.dll" -Recurse -File |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if (-not $builtDll -or -not (Test-Path $builtDll.FullName)) {
    throw "Khong tim thay TGIRR.Ribbon.dll da build trong $binRelease"
}

$windowsTarget = "$PSScriptRoot\..\bundle\TGIRR_CAD_LISP.bundle\Contents\Windows"
if (-not (Test-Path $windowsTarget)) { New-Item -ItemType Directory -Path $windowsTarget -Force | Out-Null }
Copy-Item $builtDll.FullName (Join-Path $windowsTarget 'TGIRR.Ribbon.dll') -Force

$lispSource = "$PSScriptRoot\..\src\lisp"
$lispTarget = "$PSScriptRoot\..\bundle\TGIRR_CAD_LISP.bundle\Contents\Lisp"
if (-not (Test-Path $lispTarget)) { New-Item -ItemType Directory -Path $lispTarget -Force | Out-Null }
$allowed = @('SBS.lsp','TL.lsp','TGL.lsp','TGN.lsp','TGN.dcl')
Get-ChildItem $lispTarget -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in '.lsp','.dcl' } | Remove-Item -Force
foreach ($file in $allowed) {
    Copy-Item (Join-Path $lispSource $file) $lispTarget -Force
}

Write-Host "Bundle ready: bundle\TGIRR_CAD_LISP.bundle (Ribbon DLL source: $($builtDll.Directory.Name))" -ForegroundColor Green
