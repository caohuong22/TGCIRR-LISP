param(
    [ValidateSet('AutoCAD', 'ZWCAD', 'GstarCAD', 'All', '')]
    [string]$Platform = '',
    [switch]$SkipBuild,
    # AutoCAD: cai cho rieng nguoi dung (khong can quyen admin) hay cho moi nguoi.
    # Chi nen chon MOT noi: cung mot bundle o 2 noi co the bi CAD nap 2 lan.
    [ValidateSet('User', 'Machine')]
    [string]$Scope = 'User',
    # Go cai dat (chi xoa ban da cai, khong dung toi bundle trong repo).
    [switch]$Uninstall,
    # Thu muc Support tu chon cho ZWCAD/GstarCAD (bo trong = tu tim).
    [string]$SupportDir = ''
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

function Show-Header {
    Write-Host ''
    Write-Host '=============================================================' -ForegroundColor Cyan
    Write-Host '               CAI DAT BO CONG CU TGIRR CAD                  ' -ForegroundColor Cyan
    Write-Host '=============================================================' -ForegroundColor Cyan
    Write-Host ''
}

function Stop-IfRunning([string[]]$names, [string]$label) {
    $found = @()
    foreach ($n in $names) { if (Get-Process -Name $n -ErrorAction SilentlyContinue) { $found += $n } }
    if ($found.Count -gt 0) {
        Write-Host ("{0} dang mo. Hay dong {0} roi chay lai (DLL dang bi khoa)." -f $label) -ForegroundColor Yellow
        exit 2
    }
}

# Tim thu muc Support cua CAD theo ten hang (quyét moi phien ban, khong hard-code nam).
function Find-SupportDirs([string]$vendorFolder, [string]$probeFile) {
    $base = Join-Path $env:APPDATA $vendorFolder
    if (-not (Test-Path $base)) { return @() }
    $all = Get-ChildItem $base -Recurse -Directory -Filter 'Support' -ErrorAction SilentlyContinue
    $withProbe = @($all | Where-Object { Test-Path (Join-Path $_.FullName $probeFile) } | Select-Object -ExpandProperty FullName)
    if ($withProbe.Count -gt 0) { return $withProbe }
    # Chua cai lan nao: chon thu muc Support co nhieu file nhat (ban CAD moi nhat thuong dung).
    return @($all | Sort-Object { (Get-ChildItem $_.FullName -File -ErrorAction SilentlyContinue).Count } -Descending |
        Select-Object -First 1 -ExpandProperty FullName)
}

if (-not $Platform) {
    Show-Header
    Write-Host 'Chon nen tang CAD:' -ForegroundColor White
    Write-Host '  [1] AutoCAD   - Ribbon, tu nap qua ApplicationPlugins' -ForegroundColor Yellow
    Write-Host '  [2] ZWCAD     - Palette TGIRRPALETTE + Menu (khong Ribbon)' -ForegroundColor Green
    Write-Host '  [3] GstarCAD  - Palette TGIRRPALETTE + Menu (khong Ribbon)' -ForegroundColor Cyan
    Write-Host '  [4] Dong goi ca 3 CAD vao thu muc bundle\' -ForegroundColor Magenta
    Write-Host '  [Q] Thoat' -ForegroundColor DarkGray
    Write-Host ''
    $choice = Read-Host 'Nhap lua chon (1-4 hoac Q)'
    switch ($choice.Trim()) {
        '1' { $Platform = 'AutoCAD' }
        '2' { $Platform = 'ZWCAD' }
        '3' { $Platform = 'GstarCAD' }
        '4' { $Platform = 'All' }
        default { Write-Host 'Da huy.' -ForegroundColor DarkGray; exit 0 }
    }
}

Show-Header

# -------------------------------------------------------------
# GO CAI DAT
# -------------------------------------------------------------
if ($Uninstall) {
    $removed = @()
    foreach ($p in @(
        (Join-Path $env:APPDATA 'Autodesk\ApplicationPlugins\TGIRR_CAD_LISP.bundle'),
        (Join-Path $env:ProgramData 'Autodesk\ApplicationPlugins\TGIRR_CAD_LISP.bundle'))) {
        if (Test-Path $p) { Remove-Item $p -Recurse -Force; $removed += $p }
    }
    Write-Host 'Da go bundle AutoCAD:' -ForegroundColor Green
    if ($removed.Count -eq 0) { Write-Host '  (khong co ban nao)' -ForegroundColor DarkGray }
    foreach ($r in $removed) { Write-Host "  - $r" -ForegroundColor White }

    foreach ($spec in @(@{ Vendor = 'ZWSOFT'; Probe = 'TGIRRLoaderZ.lsp'; Label = 'ZWCAD' },
                        @{ Vendor = 'Gstarsoft'; Probe = 'TGIRRLoaderG.lsp'; Label = 'GstarCAD' })) {
        foreach ($dir in (Find-SupportDirs $spec.Vendor $spec.Probe)) {
            $files = Get-ChildItem $dir -File | Where-Object {
                $_.Name -like 'TGIRR*' -or $_.Name -like 'SBS.*' -or $_.Name -like 'HBD.*' -or
                $_.Name -like 'DOITEXT.*' -or $_.Name -eq 'TGIRR_CAD.mnu' -or $_.Name -eq 'TGIRR_CAD.mnl' -or
                $_.Extension -eq '.bmp'
            }
            if ($files.Count -eq 0) { continue }
            Write-Host ("Xoa file TGIRR trong {0}: {1}" -f $spec.Label, $dir) -ForegroundColor Yellow
            $files | Remove-Item -Force -ErrorAction SilentlyContinue
        }
    }
    Write-Host ''
    Write-Host 'Da go cai dat. Mo CAD de xac nhan (khong con tab/menu TGIRR).' -ForegroundColor Green
    exit 0
}

# -------------------------------------------------------------
# 1) AUTOCAD - Ribbon, tu nap qua ApplicationPlugins
# -------------------------------------------------------------
if ($Platform -eq 'AutoCAD' -or $Platform -eq 'All') {
    if ($Platform -eq 'AutoCAD') {
        Write-Host '>>> AUTOCAD (Ribbon tu nap)' -ForegroundColor Cyan
        Stop-IfRunning @('acad') 'AutoCAD'
        if (-not $SkipBuild) {
            Write-Host '[1/3] Build & dong goi...' -ForegroundColor DarkCyan
            & (Join-Path $PSScriptRoot 'package.ps1') -Target AutoCAD
            if ($LASTEXITCODE -ne 0) { throw 'Dong goi AutoCAD that bai' }
        }

        $sourceBundle = Join-Path $root 'bundle\TGIRR_CAD_LISP.bundle'
        if (-not (Test-Path (Join-Path $sourceBundle 'PackageContents.xml'))) {
            throw "Khong tim thay bundle: $sourceBundle (chay scripts\package.ps1 -Target AutoCAD)"
        }

        $targetRoot = if ($Scope -eq 'Machine') { Join-Path $env:ProgramData 'Autodesk\ApplicationPlugins' }
                      else { Join-Path $env:APPDATA 'Autodesk\ApplicationPlugins' }
        $dest = Join-Path $targetRoot 'TGIRR_CAD_LISP.bundle'
        $other = if ($Scope -eq 'Machine') { Join-Path $env:APPDATA 'Autodesk\ApplicationPlugins\TGIRR_CAD_LISP.bundle' }
                 else { Join-Path $env:ProgramData 'Autodesk\ApplicationPlugins\TGIRR_CAD_LISP.bundle' }

        Write-Host '[2/3] Sao chep bundle...' -ForegroundColor DarkCyan
        New-Item -ItemType Directory -Force -Path $targetRoot | Out-Null
        if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
        Copy-Item $sourceBundle $dest -Recurse -Force
        Write-Host "  -> $dest" -ForegroundColor White

        # Mot bundle o 2 noi co the bi AutoCAD nap 2 lan (trung lenh, 2 tab Ribbon).
        if (Test-Path $other) {
            Remove-Item $other -Recurse -Force
            Write-Host "  -> Da xoa ban trung o: $other" -ForegroundColor Yellow
        }

        Write-Host '[3/3] Kiem tra manifest...' -ForegroundColor DarkCyan
        try {
            $null = [xml](Get-Content (Join-Path $dest 'PackageContents.xml') -Raw)
            Write-Host '  -> PackageContents.xml hop le' -ForegroundColor Green
        } catch {
            throw "PackageContents.xml khong hop le: $($_.Exception.Message)"
        }

        Write-Host ''
        Write-Host 'CAI DAT AUTOCAD THANH CONG' -ForegroundColor Green
        Write-Host ("  Pham vi: {0} ({1})" -f $Scope, $(if ($Scope -eq 'Machine') { 'moi nguoi dung' } else { 'rieng ban' })) -ForegroundColor White
        Write-Host '  Mo AutoCAD: tab "TGIRR CAD LISP" se tu hien.' -ForegroundColor White
        Write-Host '  Go TGIRRSETTINGS de bat/tat tung lenh, TGIRRSTATUS de kiem tra.' -ForegroundColor White
        Write-Host ''
    }
}

# -------------------------------------------------------------
# 2) ZWCAD / GstarCAD - copy vao thu muc Support
# -------------------------------------------------------------
foreach ($spec in @(
    @{ Key = 'ZWCAD'; Vendor = 'ZWSOFT'; Probe = 'TGIRRLoaderZ.lsp'; Loader = 'TGIRRLoaderZ.lsp';
       Proc = 'ZWCAD'; Bundle = 'TGIRR_CAD_ZWCAD'; Dll = 'TGIRR.Zwcad.dll'; Label = 'ZWCAD' },
    @{ Key = 'GstarCAD'; Vendor = 'Gstarsoft'; Probe = 'TGIRRLoaderG.lsp'; Loader = 'TGIRRLoaderG.lsp';
       Proc = 'gcad'; Bundle = 'TGIRR_CAD_GSTARCAD'; Dll = 'TGIRR.Gscad.dll'; Label = 'GstarCAD' })) {

    if ($Platform -ne $spec.Key) { continue }

    Write-Host ("<<< {0} (Palette + Menu, khong Ribbon)" -f $spec.Label) -ForegroundColor Cyan
    Stop-IfRunning @($spec.Proc) $spec.Label

    if (-not $SkipBuild) {
        Write-Host '[1/3] Build & dong goi...' -ForegroundColor DarkCyan
        & (Join-Path $PSScriptRoot 'package.ps1') -Target $spec.Key
        if ($LASTEXITCODE -ne 0) { throw ("Dong goi {0} that bai" -f $spec.Label) }
    }

    $sourceBundle = Join-Path $root ("bundle\{0}.bundle" -f $spec.Bundle)
    if (-not (Test-Path (Join-Path $sourceBundle ('Contents\Windows\' + $spec.Dll)))) {
        throw "Khong tim thay bundle $($spec.Label): $sourceBundle"
    }

    $target = $SupportDir
    if (-not $target) {
        $found = @(Find-SupportDirs $spec.Vendor $spec.Probe)
        if ($found.Count -gt 0) { $target = $found[0] }
    }

    if (-not $target) {
        Write-Host ("[2/3] Khong tim thay thu muc Support cua {0}." -f $spec.Label) -ForegroundColor Yellow
        Write-Host '      Chay lai voi -SupportDir "duong dan thu muc Support", vi du:' -ForegroundColor White
        Write-Host ('        scripts\install-bundle.ps1 -Platform {0} -SkipBuild -SupportDir "C:\...\Support"' -f $spec.Key) -ForegroundColor DarkGray
        Write-Host ("      (Bundle da san sang tai {0})" -f $sourceBundle) -ForegroundColor White
        exit 3
    }

    Write-Host ("[2/3] Thu muc Support: {0}" -f $target) -ForegroundColor DarkCyan
    New-Item -ItemType Directory -Force -Path $target | Out-Null
    Get-ChildItem (Join-Path $sourceBundle 'Contents\Lisp') -File |
        Where-Object { $_.Extension -in '.lsp', '.mnu', '.mnl', '.bmp' } |
        Copy-Item -Destination $target -Force
    Copy-Item (Join-Path $sourceBundle ('Contents\Windows\' + $spec.Dll)) $target -Force

    # Ghi nho duong dan de loader tim thay DLL/LISP khi Support khong co trong search path.
    $envName = if ($spec.Key -eq 'ZWCAD') { 'TGIRR_CAD_DIR_Z' } else { 'TGIRR_CAD_DIR_G' }
    [Environment]::SetEnvironmentVariable($envName, $target, 'User')

    Write-Host '[3/3] Kiem tra...' -ForegroundColor DarkCyan
    $copied = @(Get-ChildItem $target -File | Where-Object { $_.Name -eq $spec.Loader -or $_.Name -eq $spec.Dll })
    if ($copied.Count -lt 2) { throw ("Thieu file sau khi copy vao {0}" -f $target) }
    Write-Host ("  -> {0} file da san sang" -f $copied.Count) -ForegroundColor Green

    Write-Host ''
    Write-Host ("CAI DAT {0} THANH CONG" -f $spec.Label) -ForegroundColor Green
    Write-Host ("  Thu muc: {0}" -f $target) -ForegroundColor White
    Write-Host ("  1. Mo {0}, go APPLOAD va them {1} vao Startup Suite (1 lan)." -f $spec.Label, $spec.Loader) -ForegroundColor White
    Write-Host '  2. Go TGIRRLOAD de nap day du - bang Palette TGIRRPALETTE tu mo.' -ForegroundColor White
    Write-Host '  3. Tuy chon: MENULOAD file TGIRR_CAD.mnu de co menu keo xuong.' -ForegroundColor White
    Write-Host ''
}

# -------------------------------------------------------------
# 3) Dong goi tat ca
# -------------------------------------------------------------
if ($Platform -eq 'All') {
    Write-Host '>>> DONG GOI CA 3 NEN TANG' -ForegroundColor Magenta
    & (Join-Path $PSScriptRoot 'package.ps1') -Target All
    if ($LASTEXITCODE -ne 0) { throw 'Dong goi that bai' }
    Write-Host 'Bundle san sang trong thu muc bundle\.' -ForegroundColor Green
    Write-Host 'Cai dat: scripts\install-bundle.ps1 -Platform AutoCAD (hoac ZWCAD / GstarCAD)' -ForegroundColor White
}

Write-Host ''
Write-Host 'Kiem tra trang thai: powershell -File scripts\doctor.ps1' -ForegroundColor DarkGray
