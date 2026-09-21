$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
$src = Join-Path $root 'bundle\TGIRR_CAD_LISP.bundle'
$dests = @(
    "$env:APPDATA\Autodesk\ApplicationPlugins\TGIRR_CAD_LISP.bundle",
    "$env:ProgramData\Autodesk\ApplicationPlugins\TGIRR_CAD_LISP.bundle"
)

foreach ($dest in $dests) {
    if (Test-Path $dest) {
        Write-Host "Dong bo bundle den: $dest" -ForegroundColor Cyan
        Copy-Item (Join-Path $src 'PackageContents.xml') (Join-Path $dest 'PackageContents.xml') -Force
        Copy-Item (Join-Path $src 'Contents\Lisp\*') (Join-Path $dest 'Contents\Lisp') -Recurse -Force
        try {
            Copy-Item (Join-Path $src 'Contents\Windows\*') (Join-Path $dest 'Contents\Windows') -Recurse -Force -ErrorAction Stop
            Write-Host "  -> Chep DLL thanh cong!" -ForegroundColor Green
        } catch {
            Write-Host "  -> DLL dang bi khoa boi tien trinh CAD dang chay: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "Khong tim thay thu muc: $dest" -ForegroundColor DarkGray
    }
}
Write-Host "Dong bo hoan tat!" -ForegroundColor Green
