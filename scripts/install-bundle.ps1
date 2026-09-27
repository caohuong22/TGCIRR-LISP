param(
    [ValidateSet('AutoCAD', 'ZWCAD', 'GstarCAD', 'All', '')]
    [string]$Platform = '',
    [switch]$SkipBuild
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$packageScript = Join-Path $PSScriptRoot 'package.ps1'

function Show-Header {
    Write-Host ''
    Write-Host '=============================================================' -ForegroundColor Cyan
    Write-Host '               CAI DAT BO CONG CU TGIRR CAD                  ' -ForegroundColor Cyan
    Write-Host '=============================================================' -ForegroundColor Cyan
    Write-Host ''
}

if (-not $Platform) {
    Show-Header
    Write-Host 'Chon nen tang CAD can cai dat:' -ForegroundColor White
    Write-Host '  [1] AutoCAD   - Dung Ribbon (Tu dong nap qua ApplicationPlugins)' -ForegroundColor Yellow
    Write-Host '  [2] ZWCAD     - KHONG dung Ribbon (Dung Palette TGIRRPALETTE + Menu)' -ForegroundColor Green
    Write-Host '  [3] GstarCAD  - KHONG dung Ribbon (Dung Palette TGIRRPALETTE + Menu)' -ForegroundColor Cyan
    Write-Host '  [4] Dong goi tat ca (Build ca 3 CAD vao thu muc bundle\)' -ForegroundColor Magenta
    Write-Host '  [Q] Thoat' -ForegroundColor DarkGray
    Write-Host ''
    $choice = Read-Host 'Nhap lua chon cua ban (1-4 hoac Q)'
    switch ($choice.Trim()) {
        '1' { $Platform = 'AutoCAD' }
        '2' { $Platform = 'ZWCAD' }
        '3' { $Platform = 'GstarCAD' }
        '4' { $Platform = 'All' }
        default {
            Write-Host 'Da huy thao tac.' -ForegroundColor DarkGray
            exit 0
        }
    }
}

Show-Header

# -------------------------------------------------------------
# 1) Cai dat cho AutoCAD (Co su dung Ribbon)
# -------------------------------------------------------------
if ($Platform -eq 'AutoCAD') {
    Write-Host '>>> CAI DAT CHO AUTOCAD (Ribbon + Lisp Bundle)' -ForegroundColor Cyan
    if (Get-Process -Name 'acad' -ErrorAction SilentlyContinue) {
        Write-Host 'AutoCAD dang mo. Vui long dong AutoCAD truoc khi tiep tuc de cap nhat DLL an toan.' -ForegroundColor Yellow
        exit 2
    }

    if (-not $SkipBuild) {
        Write-Host '[1/4] Build & dong goi bundle AutoCAD...' -ForegroundColor DarkCyan
        & $packageScript -Target AutoCAD
    }

    $sourceBundle = Join-Path $projectRoot 'bundle\TGIRR_CAD_LISP.bundle'
    if (-not (Test-Path (Join-Path $sourceBundle 'PackageContents.xml'))) {
        throw "Khong tim thay bundle nguon hop le: $sourceBundle"
    }

    $targets = @(
        (Join-Path $env:APPDATA 'Autodesk\ApplicationPlugins'),
        (Join-Path $env:ProgramData 'Autodesk\ApplicationPlugins')
    )

    Write-Host '[2/4] Chuan bi thu muc Autodesk ApplicationPlugins...' -ForegroundColor DarkCyan
    foreach ($targetRoot in $targets) {
        if (-not (Test-Path $targetRoot)) { New-Item -ItemType Directory -Path $targetRoot -Force | Out-Null }
        $dest = Join-Path $targetRoot 'TGIRR_CAD_LISP.bundle'
        if (Test-Path $dest) { Remove-Item -Path $dest -Recurse -Force }
        Copy-Item -Path $sourceBundle -Destination $dest -Recurse -Force
        Write-Host "  -> Da sao chep bundle vao: $dest" -ForegroundColor White
    }

    Write-Host ''
    Write-Host 'CAI DAT AUTOCAD THANH CONG!' -ForegroundColor Green
    Write-Host 'Mo AutoCAD se thay tab TGIRR CAD LISP tren thanh Ribbon.' -ForegroundColor White
    Write-Host ''
}

# -------------------------------------------------------------
# 2) Cai dat cho ZWCAD (KHONG DUNG RIBBON - Dung Palette + Menu)
# -------------------------------------------------------------
elseif ($Platform -eq 'ZWCAD') {
    Write-Host '>>> CAI DAT CHO ZWCAD (KHONG DUNG RIBBON - Palette + Menu)' -ForegroundColor Green
    if (Get-Process -Name 'ZWCAD' -ErrorAction SilentlyContinue) {
        Write-Host 'ZWCAD dang mo. Vui long dong ZWCAD truoc khi tiep tuc de cap nhat DLL an toan.' -ForegroundColor Yellow
        exit 2
    }

    if (-not $SkipBuild) {
        Write-Host '[1/3] Build & dong goi bundle ZWCAD (.NET net48, khong Ribbon)...' -ForegroundColor DarkGreen
        & $packageScript -Target ZWCAD
    }

    $sourceBundle = Join-Path $projectRoot 'bundle\TGIRR_CAD_ZWCAD.bundle'
    if (-not (Test-Path (Join-Path $sourceBundle 'Contents\Windows\TGIRR.Zwcad.dll'))) {
        throw "Khong tim thay bundle ZWCAD: $sourceBundle"
    }

    # Tim thu muc Support cua ZWCAD (vi du ZWCAD 2026)
    $zwSupportCandidates = @(
        "$env:APPDATA\ZWSOFT\ZWCAD\2026\en-US\Support",
        "$env:APPDATA\ZWSOFT\ZWCAD\2025\en-US\Support",
        "$env:APPDATA\ZWSOFT\ZWCAD\2024\en-US\Support"
    )
    $destSupport = $zwSupportCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

    if ($destSupport) {
        Write-Host "[2/3] Da tim thay thu muc Support ZWCAD: $destSupport" -ForegroundColor DarkGreen
        Write-Host '[3/3] Sao chep file LISP, Menu va DLL vao thu muc Support...' -ForegroundColor DarkGreen
        Get-ChildItem (Join-Path $sourceBundle 'Contents\Lisp') | Copy-Item -Destination $destSupport -Force
        Get-ChildItem (Join-Path $sourceBundle 'Contents\Windows') | Copy-Item -Destination $destSupport -Force
        Write-Host ''
        Write-Host 'CAI DAT ZWCAD THANH CONG!' -ForegroundColor Green
        Write-Host "Da sao chep file vao: $destSupport" -ForegroundColor White
    } else {
        Write-Host "[2/3] Bundle ZWCAD da dong goi tai: $sourceBundle" -ForegroundColor DarkGreen
        Write-Host 'Khong tu dong tim thay thu muc Support. Anh hay copy thu muc Contents vao thu muc Support cua ZWCAD.' -ForegroundColor Yellow
    }

    Write-Host ''
    Write-Host 'CHU Y QUAN TRONG (ZWCAD KHONG DUNG RIBBON):' -ForegroundColor Yellow
    Write-Host '  1. Mo ZWCAD, go APPLOAD va them TGIRRLoaderZ.lsp vao Startup Suite.' -ForegroundColor White
    Write-Host '  2. Go TGIRRLOAD de nap toan bo cong cu: bang Palette TGIRRPALETTE se tu dong mo!' -ForegroundColor White
    Write-Host '  3. (Tuy chon) Go MENULOAD, nap file TGIRR_CAD.mnu de co menu keo xuong.' -ForegroundColor White
    Write-Host ''
}

# -------------------------------------------------------------
# 3) Cai dat cho GstarCAD (KHONG DUNG RIBBON - Dung Palette + Menu)
# -------------------------------------------------------------
elseif ($Platform -eq 'GstarCAD') {
    Write-Host '>>> CAI DAT CHO GSTARCAD (KHONG DUNG RIBBON - Palette + Menu)' -ForegroundColor Cyan
    if (Get-Process -Name 'gcad' -ErrorAction SilentlyContinue) {
        Write-Host 'GstarCAD dang mo. Vui long dong GstarCAD truoc khi tiep tuc.' -ForegroundColor Yellow
        exit 2
    }

    if (-not $SkipBuild) {
        Write-Host '[1/3] Build & dong goi bundle GstarCAD (.NET net8.0, khong Ribbon)...' -ForegroundColor DarkCyan
        & $packageScript -Target GstarCAD
    }

    $sourceBundle = Join-Path $projectRoot 'bundle\TGIRR_CAD_GSTARCAD.bundle'
    if (-not (Test-Path (Join-Path $sourceBundle 'Contents\Windows\TGIRR.Gscad.dll'))) {
        throw "Khong tim thay bundle GstarCAD: $sourceBundle"
    }

    # Tim thu muc Support cua GstarCAD (ho tro ca en-WW, en-US tren moi phien ban R27, R26...)
    $gscadSupportCandidates = Get-ChildItem "$env:APPDATA\Gstarsoft\GstarCAD" -Recurse -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -eq 'Support' } |
        Select-Object -ExpandProperty FullName

    $gscadSupport = $gscadSupportCandidates | Select-Object -First 1

    # Dinh vi thu muc D:\LispCAD\TGIRR_CAD_GSTARCAD.bundle neu nguoi dung da cau hinh
    $userBundle = 'D:\LispCAD\TGIRR_CAD_GSTARCAD.bundle'
    if (Test-Path $userBundle) {
        Write-Host "  -> Tim thay thu muc bundle nguoi dung: $userBundle" -ForegroundColor DarkCyan
        Copy-Item -Path (Join-Path $sourceBundle 'Contents') -Destination $userBundle -Recurse -Force
        [Environment]::SetEnvironmentVariable('TGIRR_CAD_DIR_G', (Join-Path $userBundle 'Contents'), 'User')
        if (-not (Test-Path "HKCU:\Software\TGIRR")) { New-Item -Path "HKCU:\Software\TGIRR" -Force | Out-Null }
        Set-ItemProperty -Path "HKCU:\Software\TGIRR" -Name "GscadDir" -Value (Join-Path $userBundle 'Contents')
    }

    if ($gscadSupport) {
        Write-Host "[2/3] Da tim thay thu muc Support GstarCAD: $gscadSupport" -ForegroundColor DarkCyan
        Write-Host '[3/3] Sao chep file LISP, Menu va DLL vao thu muc Support...' -ForegroundColor DarkCyan
        Get-ChildItem (Join-Path $sourceBundle 'Contents\Lisp') | Copy-Item -Destination $gscadSupport -Force
        Get-ChildItem (Join-Path $sourceBundle 'Contents\Windows') | Copy-Item -Destination $gscadSupport -Force
        if (-not (Test-Path "HKCU:\Software\TGIRR")) { New-Item -Path "HKCU:\Software\TGIRR" -Force | Out-Null }
        Set-ItemProperty -Path "HKCU:\Software\TGIRR" -Name "GscadDir" -Value $gscadSupport
        Write-Host ''
        Write-Host 'CAI DAT GSTARCAD THANH CONG!' -ForegroundColor Green
        Write-Host "Da sao chep file vao: $gscadSupport" -ForegroundColor White
    } else {
        Write-Host "[2/3] Bundle GstarCAD da dong goi tai: $sourceBundle" -ForegroundColor DarkCyan
        Write-Host 'Da cap nhat vao thu muc bundle D:\LispCAD\TGIRR_CAD_GSTARCAD.bundle.' -ForegroundColor Green
    }

    Write-Host ''
    Write-Host 'CHU Y QUAN TRONG (GSTARCAD KHONG DUNG RIBBON):' -ForegroundColor Yellow
    Write-Host '  1. Mo GstarCAD, go APPLOAD va them TGIRRLoaderG.lsp vao Startup Suite.' -ForegroundColor White
    Write-Host '  2. Go TGIRRLOAD de nap toan bo cong cu: bang Palette TGIRRPALETTE se tu dong mo!' -ForegroundColor White
    Write-Host '  3. (Tuy chon) Go MENULOAD, nap file TGIRR_CAD.mnu de co menu keo xuong.' -ForegroundColor White
    Write-Host ''
}

# -------------------------------------------------------------
# 4) Dong goi tat ca
# -------------------------------------------------------------
elseif ($Platform -eq 'All') {
    Write-Host '>>> DONG GOI TOAN BO CHO 3 NEN TANG CAD...' -ForegroundColor Magenta
    & $packageScript -Target All
    Write-Host 'Toan bo bundle da san sang tai thu muc bundle\.' -ForegroundColor Green
}
