param([string]$Root = (Split-Path -Parent $PSScriptRoot))
# ===========================================================================
# gen-icons.ps1 - Sinh icon BMP cho thanh cong cu native (***TOOLBARS).
#
#   src\catalog\tools.json  ->  src\menu\icons\<TAG>.bmp      (16x16, small)
#                               src\menu\icons\<TAG>_L.bmp    (32x32, large)
#
# Icon duoc ve bang System.Drawing (khong can file nguon): o nen toi + vien
# mau theo nhom + chu viet tat 1-3 ky tu, doc duoc o 16x16.
# Chay lai bat cu luc nao sau khi them/bot lenh trong tools.json.
# ===========================================================================
Add-Type -AssemblyName System.Drawing

$catalog = ([System.IO.File]::ReadAllText((Join-Path $Root 'src\catalog\tools.json'), [System.Text.Encoding]::UTF8) | ConvertFrom-Json)

$accentByGroup = @{}
foreach ($g in $catalog.groups) { $accentByGroup[$g.key] = $g.accent }

$accentColor = @{
    'Cyan'  = [System.Drawing.Color]::FromArgb(56, 189, 248)
    'Green' = [System.Drawing.Color]::FromArgb(52, 211, 153)
    'Amber' = [System.Drawing.Color]::FromArgb(251, 191, 36)
}
$tileColor   = [System.Drawing.Color]::FromArgb(37, 51, 68)
$borderColor = [System.Drawing.Color]::FromArgb(15, 23, 34)

# Chu viet tat hien thi tren icon (toi da 3 ky tu cho 16x16)
$glyphs = @{
    'SBS' = 'SB'; 'SBSE' = 'SE'; 'HBD' = 'HB'; 'JH' = 'JH'; 'SP2PL' = 'SP'
    'CVPL' = 'CV'; 'VDNG' = 'VD'; 'TNET' = 'TN'; 'TGL' = 'LG'; 'TL' = 'TL'
    'TGN' = 'NO'; 'CPLUS' = 'C+'; 'DOITEXT' = 'M2T'; 'DOIMTEXT' = 'T2M'
    'TGIRRPALETTE' = 'PAL'; 'TGIRRQUICK' = 'QT'; 'TGIRRBAR' = 'BAR'
}

function Get-Glyph([string]$id) {
    if ($glyphs.ContainsKey($id)) { return $glyphs[$id] }
    $clean = ($id -replace '[^A-Za-z0-9]', '').ToUpperInvariant()
    if ($clean.Length -eq 0) { return '?' }
    if ($clean.Length -le 2) { return $clean }
    return $clean.Substring(0, 2)
}

function New-Icon([string]$path, [int]$size, [string]$glyph, [System.Drawing.Color]$accent) {
    $bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit

    $g.Clear($tileColor)
    $pen = New-Object System.Drawing.Pen($accent, 1)
    $g.DrawRectangle($pen, 0, 0, $size - 1, $size - 1)
    $pen.Dispose()

    $maxWidth = $size - 3
    $maxHeight = $size - 4
    $fontSize = [Math]::Max(6.0, [Math]::Round($size * 0.72, 1))
    $font = $null
    $measured = $null
    while ($fontSize -ge 5.0) {
        if ($font) { $font.Dispose() }
        $font = New-Object System.Drawing.Font('Arial', [single]$fontSize, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
        $measured = $g.MeasureString($glyph, $font)
        if ($measured.Width -le $maxWidth -and $measured.Height -le $maxHeight) { break }
        $fontSize -= 0.5
    }

    $brush = New-Object System.Drawing.SolidBrush($accent)
    $x = [single](($size - $measured.Width) / 2.0)
    $y = [single](($size - $measured.Height) / 2.0)
    $g.DrawString($glyph, $font, $brush, $x, $y)
    $brush.Dispose()
    $font.Dispose()
    $g.Dispose()

    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Bmp)
    $bmp.Dispose()
}

$outDir = Join-Path $Root 'src\menu\icons'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
Get-ChildItem $outDir -Filter *.bmp -ErrorAction SilentlyContinue | Remove-Item -Force

$count = 0
foreach ($t in $catalog.tools) {
    if ($t.role -ne 'tool') { continue }
    $accentName = $accentByGroup[$t.group]
    $accent = $accentColor[$accentName]
    if (-not $accent) { $accent = [System.Drawing.Color]::FromArgb(148, 163, 184) }
    $tag = $t.menu.tag
    $glyph = Get-Glyph $t.id
    New-Icon (Join-Path $outDir ($tag + '.bmp'))    16 $glyph $accent
    New-Icon (Join-Path $outDir ($tag + '_L.bmp'))  32 $glyph $accent
    $count += 2
}
Write-Host ("Icon: {0} file BMP -> {1}" -f $count, $outDir) -ForegroundColor Green
