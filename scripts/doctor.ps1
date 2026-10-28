param([switch]$Quiet)
# ===========================================================================
# doctor.ps1 - Chan doan nhanh: may nay co build va nap TGIRR vao CAD duoc khong?
#
#   powershell -File scripts\doctor.ps1
#
# Kiem tra: .NET SDK, DLL tham chieu trong Reference\, noi dung bundle,
# ban da cai trong ApplicationPlugins (AutoCAD) / Support (ZWCAD, GstarCAD),
# file cau hinh nguoi dung (%APPDATA%\TGIRR) va tien trinh CAD dang chay.
# Khong sua gi - chi bao trang thai va viec can lam.
# ===========================================================================
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

$okCount = 0; $warnCount = 0; $badCount = 0
function Ok([string]$m) { $script:okCount++; if (-not $Quiet) { Write-Host ("  [OK]   {0}" -f $m) -ForegroundColor Green } }
function Warn([string]$m) { $script:warnCount++; if (-not $Quiet) { Write-Host ("  [!]    {0}" -f $m) -ForegroundColor Yellow } }
function Bad([string]$m) { $script:badCount++; if (-not $Quiet) { Write-Host ("  [LOI]  {0}" -f $m) -ForegroundColor Red } }

Write-Host ''
Write-Host '=============================================================' -ForegroundColor Cyan
Write-Host '            TGIRR - KIEM TRA MOI TRUONG BUILD/LOAD            ' -ForegroundColor Cyan
Write-Host '=============================================================' -ForegroundColor Cyan

Write-Host ''
Write-Host '1. Cong cu build' -ForegroundColor Cyan
if (Get-Command dotnet -ErrorAction SilentlyContinue) {
    Ok ("dotnet SDK " + ((& dotnet --version) 2>$null))
} else {
    Bad 'Khong co dotnet SDK - cai .NET SDK 8.0+ (https://dot.net/download)'
}

Write-Host ''
Write-Host '2. DLL tham chieu CAD (Reference\)' -ForegroundColor Cyan
$refs = @(
    @{ Name = 'AutoCAD 2021-2024 (net48)'; Path = 'Reference\Cad2023\net48\acmgd.dll' },
    @{ Name = 'AutoCAD 2025-2026 (net8.0)'; Path = 'Reference\Cad2026\net8.0\acmgd.dll' },
    @{ Name = 'AutoCAD 2027 (net10.0)'; Path = 'Reference\Cad2027\acmgd.dll' },
    @{ Name = 'ZWCAD (net48)'; Path = 'Reference\Zwcad\net47\ZwManaged.dll' },
    @{ Name = 'GstarCAD (net8.0)'; Path = 'Reference\gstarCad\GcMgd.dll' }
)
$missingCad = 0
foreach ($r in $refs) {
    if (Test-Path (Join-Path $root $r.Path)) { Ok $r.Name } else { Warn ("{0} - thieu {1}" -f $r.Name, $r.Path); $missingCad++ }
}
if ($missingCad -gt 0) {
    Write-Host '         -> Chi build duoc nen tang co DLL. Xem docs/INSTALL.md muc "Build tu ma nguon".' -ForegroundColor DarkGray
}

Write-Host ''
Write-Host '3. Bundle da dong goi' -ForegroundColor Cyan
$bundles = @(
    @{ Name = 'AutoCAD'; Path = 'bundle\TGIRR_CAD_LISP.bundle'; Probe = 'PackageContents.xml' },
    @{ Name = 'ZWCAD'; Path = 'bundle\TGIRR_CAD_ZWCAD.bundle'; Probe = 'Contents\Windows\TGIRR.Zwcad.dll' },
    @{ Name = 'GstarCAD'; Path = 'bundle\TGIRR_CAD_GSTARCAD.bundle'; Probe = 'Contents\Windows\TGIRR.Gscad.dll' }
)
foreach ($b in $bundles) {
    $full = Join-Path $root $b.Path
    if (Test-Path (Join-Path $full $b.Probe)) {
        $dll = Get-ChildItem (Join-Path $full 'Contents\Windows') -Filter *.dll -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($dll) { Ok ("{0} - DLL {1:HH:mm dd/MM}" -f $b.Name, $dll.LastWriteTime) } else { Ok $b.Name }
    } else {
        Warn ("{0} - chua dong goi (chay scripts\package.ps1 -Target {1})" -f $b.Name, $b.Name)
    }
}

Write-Host ''
Write-Host '4. Ban da cai tren may' -ForegroundColor Cyan
$acadRoots = @(
    (Join-Path $env:APPDATA 'Autodesk\ApplicationPlugins\TGIRR_CAD_LISP.bundle'),
    (Join-Path $env:ProgramData 'Autodesk\ApplicationPlugins\TGIRR_CAD_LISP.bundle')
)
$installed = @()
foreach ($p in $acadRoots) { if (Test-Path $p) { $installed += $p } }
if ($installed.Count -eq 0) {
    Warn 'AutoCAD: chua cai (chay scripts\install-bundle.ps1 -Platform AutoCAD)'
} elseif ($installed.Count -gt 1) {
    # Hai ban cung ProductCode co the lam CAD nap plugin 2 lan.
    Warn ("AutoCAD: cai o CA HAI noi (nen chi giu 1):`r`n         " + ($installed -join "`r`n         "))
} else {
    $dll = Get-Item (Join-Path $installed[0] 'Contents\Windows\2026\TGIRR.Ribbon.dll') -ErrorAction SilentlyContinue
    if ($dll) { Ok ("AutoCAD - {0} (DLL {1:HH:mm dd/MM})" -f $installed[0], $dll.LastWriteTime) } else { Ok ("AutoCAD - " + $installed[0]) }
}

$zwSupport = @()
if (Test-Path (Join-Path $env:APPDATA 'ZWSOFT')) {
    $zwSupport = Get-ChildItem (Join-Path $env:APPDATA 'ZWSOFT') -Recurse -Directory -Filter 'Support' -ErrorAction SilentlyContinue |
        Where-Object { Test-Path (Join-Path $_.FullName 'TGIRRLoaderZ.lsp') } | Select-Object -ExpandProperty FullName
}
if ($zwSupport.Count -gt 0) { Ok ("ZWCAD - " + $zwSupport[0]) } else { Warn 'ZWCAD: chua thay TGIRRLoaderZ.lsp trong thu muc Support' }

$gsSupport = @()
if (Test-Path (Join-Path $env:APPDATA 'Gstarsoft')) {
    $gsSupport = Get-ChildItem (Join-Path $env:APPDATA 'Gstarsoft') -Recurse -Directory -Filter 'Support' -ErrorAction SilentlyContinue |
        Where-Object { Test-Path (Join-Path $_.FullName 'TGIRRLoaderG.lsp') } | Select-Object -ExpandProperty FullName
}
if ($gsSupport.Count -gt 0) { Ok ("GstarCAD - " + $gsSupport[0]) } else { Warn 'GstarCAD: chua thay TGIRRLoaderG.lsp trong thu muc Support' }

Write-Host ''
Write-Host '5. Cau hinh nguoi dung (%APPDATA%\TGIRR)' -ForegroundColor Cyan
$cfgDir = Join-Path $env:APPDATA 'TGIRR'
if (Test-Path $cfgDir) {
    $loadSettings = Join-Path $cfgDir 'load-settings.txt'
    if (Test-Path $loadSettings) {
        $line = ([IO.File]::ReadAllText($loadSettings)).Trim()
        $disabled = @()
        if ($line -match 'disabled=(.*)$') { $disabled = ($Matches[1] -split ',') | Where-Object { $_ } }
        if ($disabled.Count -eq 0) { Ok 'Tat ca lenh dang bat (load-settings.txt)' }
        else { Warn ("Dang tat {0} lenh: {1}" -f $disabled.Count, ($disabled -join ', ')) }
    } else {
        Ok 'Chua co load-settings.txt (mac dinh: bat tat ca)'
    }
    $pins = Join-Path $cfgDir 'quick-tools.txt'
    if (Test-Path $pins) { Ok ('Quick Tools: ' + ([IO.File]::ReadAllText($pins)).Trim()) }
} else {
    Ok 'Chua co %APPDATA%\TGIRR (se tao o lan chay dau)'
}

Write-Host ''
Write-Host '6. Tien trinh CAD dang chay' -ForegroundColor Cyan
$running = @()
foreach ($p in @(@{ n = 'acad'; l = 'AutoCAD' }, @{ n = 'ZWCAD'; l = 'ZWCAD' }, @{ n = 'gcad'; l = 'GstarCAD' })) {
    if (Get-Process -Name $p.n -ErrorAction SilentlyContinue) { $running += $p.l }
}
if ($running.Count -gt 0) {
    Warn (($running -join ', ') + ' dang chay - dong CAD truoc khi cap nhat DLL')
} else {
    Ok 'Khong co CAD nao dang chay'
}

Write-Host ''
Write-Host '=============================================================' -ForegroundColor Cyan
Write-Host ("  OK: {0}   Canh bao: {1}   Loi: {2}" -f $okCount, $warnCount, $badCount) -ForegroundColor White
if ($badCount -gt 0) {
    Write-Host '  -> Sua cac muc [LOI] truoc khi build.' -ForegroundColor Red
} elseif ($warnCount -gt 0) {
    Write-Host '  -> Build va nap duoc; xem cac muc [!] neu gap loi khi chay.' -ForegroundColor Yellow
} else {
    Write-Host '  -> Moi thu san sang.' -ForegroundColor Green
}
Write-Host ''
