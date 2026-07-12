param([switch]$SkipBuild)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$bundleName = 'TGIRR_CAD_LISP.bundle'
$sourceBundle = Join-Path $projectRoot "bundle\$bundleName"
$targetRoot = Join-Path $env:ProgramData 'Autodesk\ApplicationPlugins'
$targetBundle = Join-Path $targetRoot $bundleName
$packageScript = Join-Path $PSScriptRoot 'package.ps1'
function Test-AutoCADRunning { return $null -ne (Get-Process -Name 'acad' -ErrorAction SilentlyContinue) }
Write-Host ''; Write-Host '=== CAI DAT TGIRR CAD LISP ===' -ForegroundColor Cyan
if (Test-AutoCADRunning) { Write-Host 'AutoCAD dang mo. Hay dong hoan toan AutoCAD roi chay lai script.' -ForegroundColor Yellow; Write-Host 'DLL Ribbon dang duoc AutoCAD giu nen khong the cap nhat an toan.' -ForegroundColor Yellow; exit 2 }
if (-not $SkipBuild) { Write-Host '[1/4] Build va dong goi ban moi...' -ForegroundColor Cyan; & $packageScript; if ($LASTEXITCODE -ne 0) { throw "Build that bai voi ma loi $LASTEXITCODE. Bundle cu chua bi xoa." } } else { Write-Host '[1/4] Bo qua build theo tham so -SkipBuild.' -ForegroundColor DarkGray }
if (-not (Test-Path (Join-Path $sourceBundle 'PackageContents.xml'))) { throw "Khong tim thay bundle nguon hop le: $sourceBundle" }
Write-Host '[2/4] Tao thu muc Autodesk ApplicationPlugins...' -ForegroundColor Cyan; New-Item -ItemType Directory -Path $targetRoot -Force | Out-Null
Write-Host '[3/4] Xoa bundle TGIRR cu...' -ForegroundColor Cyan; if (Test-Path $targetBundle) { Remove-Item -Path $targetBundle -Recurse -Force }
Write-Host '[4/4] Copy bundle moi...' -ForegroundColor Cyan; Copy-Item -Path $sourceBundle -Destination $targetBundle -Recurse -Force
$sourceFiles = @(Get-ChildItem $sourceBundle -Recurse -File); $targetFiles = @(Get-ChildItem $targetBundle -Recurse -File)
if ($sourceFiles.Count -ne $targetFiles.Count) { throw "Copy khong day du: nguon $($sourceFiles.Count) file, dich $($targetFiles.Count) file." }
Write-Host ''; Write-Host 'CAI DAT THANH CONG!' -ForegroundColor Green; Write-Host "Da cai vao: $targetBundle" -ForegroundColor Green; Write-Host 'Bay gio anh co the mo AutoCAD 2023.' -ForegroundColor White; Write-Host ''
