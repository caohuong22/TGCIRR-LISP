param(
    # 'Auto' = dong bo noi da co bundle; 'User'/'Machine' = chi noi do.
    [ValidateSet('Auto', 'User', 'Machine')]
    [string]$Scope = 'Auto'
)
$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
$src = Join-Path $root 'bundle\TGIRR_CAD_LISP.bundle'

$userDest = Join-Path $env:APPDATA 'Autodesk\ApplicationPlugins\TGIRR_CAD_LISP.bundle'
$machineDest = Join-Path $env:ProgramData 'Autodesk\ApplicationPlugins\TGIRR_CAD_LISP.bundle'

$existing = @()
if (Test-Path $userDest) { $existing += $userDest }
if (Test-Path $machineDest) { $existing += $machineDest }
if ($existing.Count -eq 0) {
    Write-Host 'Chua cai bundle AutoCAD. Chay: scripts\install-bundle.ps1 -Platform AutoCAD -SkipBuild' -ForegroundColor Yellow
    return
}

$dests = switch ($Scope) {
    'User' { @($userDest) }
    'Machine' { @($machineDest) }
    default { $existing }
}
$dests = @($dests | Where-Object { Test-Path $_ })

if ($Scope -eq 'Auto' -and $existing.Count -gt 1) {
    Write-Host 'Bundle dang cai o CA HAI noi (co the bi AutoCAD nap 2 lan).' -ForegroundColor Yellow
    Write-Host '  Chon 1 noi: scripts\install-bundle.ps1 -Platform AutoCAD -SkipBuild -Scope User' -ForegroundColor Yellow
}

$cadRunning = [bool](Get-Process -Name 'acad' -ErrorAction SilentlyContinue)

foreach ($dest in $dests) {
    Write-Host "Dong bo bundle den: $dest" -ForegroundColor Cyan
    Copy-Item (Join-Path $src 'PackageContents.xml') (Join-Path $dest 'PackageContents.xml') -Force
    Copy-Item (Join-Path $src 'Contents\Lisp\*') (Join-Path $dest 'Contents\Lisp') -Recurse -Force
    if ($cadRunning) {
        # AutoCAD dang giu DLL: copy se loi va de lai ban cu -> phai noi ro.
        Write-Host '  -> BO QUA DLL: AutoCAD dang chay, dong CAD roi chay lai de cap nhat DLL.' -ForegroundColor Yellow
        continue
    }
    try {
        Copy-Item (Join-Path $src 'Contents\Windows\*') (Join-Path $dest 'Contents\Windows') -Recurse -Force -ErrorAction Stop
        Write-Host '  -> Chep DLL thanh cong!' -ForegroundColor Green
    } catch {
        Write-Host "  -> Khong chep duoc DLL: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host '     Dong CAD roi chay lai: scripts\package.ps1 -Target AutoCAD' -ForegroundColor Yellow
    }
}
Write-Host 'Dong bo hoan tat!' -ForegroundColor Green

