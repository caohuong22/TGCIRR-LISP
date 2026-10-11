param()
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'port-config.ps1')

# ===========================================================================
# port-verify.ps1 - Kiem tra cac ban port (src\zwcad, src\gscad) + menu trong
# bundle co tra dung nguon (src\ribbon, src\shared, src\menu) khong.
# Khong ghi bat cu file nao. Dung trong CI / scripts\test-palette.ps1.
# ===========================================================================

$failures = New-Object System.Collections.Generic.List[string]

Write-Host '== Kiem tra ban port khong lech nguon ==' -ForegroundColor Cyan
foreach ($target in @('ZWCAD', 'GstarCAD')) {
    $drift = Get-TgirrrPortDrift $target
    if ($drift.Count -eq 0) {
        Write-Host ("  [OK]   {0} (+ bundle menu)" -f $target) -ForegroundColor Green
    } else {
        foreach ($d in $drift) { $failures.Add("$target : $d"); Write-Host "  [LECH] $target :: $d" -ForegroundColor Red }
        Write-Host ("  -> Chay scripts\port-{0}.ps1 de dong bo" -f $(if ($target -eq 'ZWCAD') { 'zwcad' } else { 'gscad' })) -ForegroundColor DarkGray
    }
}

# Ba ban palette phai giong nhau sau khi chuan hoa namespace.
function ConvertTo-NormalizedPalette([string]$path, [string]$prefix) {
    $text = Read-TgirrrUtf8 $path
    $text = $text.Replace($prefix + '.', 'CAD.')
    $text = $text.Replace('"ZWCAD"', '"HOST"').Replace('"GstarCAD"', '"HOST"')
    return $text
}

foreach ($leaf in @('PaletteCommands.cs', 'PaletteContent.cs')) {
    $zp = Join-Path $TgirrrRoot "src\zwcad\$leaf"
    $gp = Join-Path $TgirrrRoot "src\gscad\$leaf"
    if (-not (Test-Path $zp) -or -not (Test-Path $gp)) {
        $failures.Add("palette drift: thieu $leaf o src\zwcad hoac src\gscad")
        continue
    }
    $a = ConvertTo-NormalizedPalette $zp 'ZwSoft.ZwCAD'
    $b = ConvertTo-NormalizedPalette $gp 'Gssoft.Gscad'
    if ($a -ne $b) {
        $failures.Add("palette drift: $leaf lech giua ZWCAD va GstarCAD (sau khi chuan hoa namespace)")
        Write-Host "  [LECH] $leaf khong giong nhau giua hai host" -ForegroundColor Red
    } else {
        Write-Host "  [OK]   $leaf giong nhau giua ZWCAD va GstarCAD" -ForegroundColor Green
    }
}

if ($failures.Count -gt 0) {
    throw ("Port drift (" + $failures.Count + "):`n  " + ($failures -join "`n  "))
}
Write-Host '== Port verify OK ==' -ForegroundColor Green
