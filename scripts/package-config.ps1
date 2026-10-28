param()
# ===========================================================================
# package-config.ps1 - Cau hinh dong goi dung chung.
#
# Danh sach file LISP can copy vao bundle KHONG khai bao lai o day: no duoc
# suy ra tu src\catalog\tools.json (muc "loadUnits"), de them/bot LISP chi
# phai sua catalog. Sua o 3 script package truoc day la nguon su that thu 2.
# ===========================================================================

$TgirrrRoot = Split-Path -Parent $PSScriptRoot

function Get-TgirrrCatalog {
    return ([System.IO.File]::ReadAllText((Join-Path $TgirrrRoot 'src\catalog\tools.json'),
        [System.Text.Encoding]::UTF8) | ConvertFrom-Json)
}

# Tra ve danh sach file .lsp can co trong bundle, theo thu tu nap:
# cac file trong loadUnits -> TGIRRCOMMANDS.lsp (sinh tu catalog) -> loader.
function Get-TgirrrLispFiles([string]$LoaderName) {
    $catalog = Get-TgirrrCatalog
    $files = New-Object System.Collections.Generic.List[string]
    foreach ($unit in @($catalog.loadUnits)) {
        if ($unit.file -and -not $files.Contains($unit.file)) { $files.Add($unit.file) }
    }
    # Asset DWG (khung ten mau...) nam cung thu muc src\lisp, copy theo danh sach nay.
    $lispDir = Join-Path $TgirrrRoot 'src\lisp'
    Get-ChildItem $lispDir -Filter '*.dwg' -File -ErrorAction SilentlyContinue | ForEach-Object {
        if (-not $files.Contains($_.Name)) { $files.Add($_.Name) }
    }
    if (-not $files.Contains('TGIRRCOMMANDS.lsp')) { $files.Add('TGIRRCOMMANDS.lsp') }
    if ($LoaderName -and -not $files.Contains($LoaderName)) { $files.Add($LoaderName) }
    return $files.ToArray()
}
