param([string]$Root = (Split-Path -Parent $PSScriptRoot))
# ===========================================================================
# gen-icons.ps1 - Sinh icon BMP cho thanh cong cu native (***TOOLBARS).
#
#   src\catalog\tools.json  ->  src\menu\icons\<TAG>.bmp      (16x16, small)
#                               src\menu\icons\<TAG>_L.bmp    (32x32, large)
#
# Hinh ve nam trong src\shared\ToolIcons.cs (cung bo icon voi Ribbon va Palette),
# nen icon native va icon tren palette luon giong het nhau. Icon KHONG chua chu;
# ten lenh + cach dung ngan chi hien khi hover (tooltip sinh tu tools.json).
# ===========================================================================
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName PresentationCore, PresentationFramework, WindowsBase

if (-not ('Tgirrr.CadLisp.ToolIcons' -as [type])) {
    Add-Type -Path (Join-Path $Root 'src\shared\ToolIcons.cs') `
        -ReferencedAssemblies PresentationCore, PresentationFramework, WindowsBase, System.Xaml
}

$catalog = ([System.IO.File]::ReadAllText((Join-Path $Root 'src\catalog\tools.json'), [System.Text.Encoding]::UTF8) | ConvertFrom-Json)

$accentByGroup = @{}
foreach ($g in $catalog.groups) { $accentByGroup[$g.key] = $g.accent }

$accentColor = @{
    'Cyan'  = [System.Windows.Media.Color]::FromRgb(56, 189, 248)
    'Green' = [System.Windows.Media.Color]::FromRgb(52, 211, 153)
    'Amber' = [System.Windows.Media.Color]::FromRgb(251, 191, 36)
}
$defaultAccent = [System.Windows.Media.Color]::FromRgb(56, 189, 248)

$outDir = Join-Path $Root 'src\menu\icons'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
Get-ChildItem $outDir -Filter *.bmp -ErrorAction SilentlyContinue | Remove-Item -Force

$count = 0
foreach ($t in $catalog.tools) {
    $accent = $defaultAccent
    if ($t.group -and $accentByGroup.ContainsKey($t.group)) {
        $name = $accentByGroup[$t.group]
        if ($accentColor.ContainsKey($name)) { $accent = $accentColor[$name] }
    }
    $tag = $t.menu.tag
    [Tgirrr.CadLisp.ToolIcons]::SaveBmp($t.icon, $accent, (Join-Path $outDir ($tag + '.bmp')), 16)
    [Tgirrr.CadLisp.ToolIcons]::SaveBmp($t.icon, $accent, (Join-Path $outDir ($tag + '_L.bmp')), 32)
    $count += 2
}
Write-Host ("Icon: {0} file BMP -> {1}" -f $count, $outDir) -ForegroundColor Green
