param()
# ===========================================================================
# port-config.ps1 - CAU HINH PORT dung chung cho:
#   scripts\port-zwcad.ps1   scripts\port-gscad.ps1   scripts\port-verify.ps1
# Day la LIST KE DUY NHAT cua cac file nguon. Them/bot file thi sua o day,
# roi chay: powershell -File scripts\port-verify.ps1
#
# Loai file:
#   RawFromRibbon    : src\ribbon, copy nguyen van (khong dung API CAD)
#   MappedFromRibbon : src\ribbon, thay namespace Autodesk.AutoCAD.* -> host
#   RawFromShared    : src\shared, copy nguyen van (chi System.*, WPF)
#   MappedFromShared : src\shared, thay namespace + token ten host
# ===========================================================================

$TgirrrRoot = Split-Path -Parent $PSScriptRoot
$TgirrrRibbonDir = Join-Path $TgirrrRoot 'src\ribbon'
$TgirrrSharedDir = Join-Path $TgirrrRoot 'src\shared'
$TgirrrMenuDir = Join-Path $TgirrrRoot 'src\menu'
$TgirrrMenuFile = 'TGIRR_CAD.mnu'

$TgirrrRawFromRibbon = @(
    'CopySequenceService.cs',
    'DripFillGeometry.cs',
    'CopySequenceWindow.cs',
    'LinetypeFile.cs',
    'LayerSetService.cs',
    'LayerLibraryStore.cs',
    'TotalLengthService.cs',
    'PolylineGeometry.cs',
    'NumberingService.cs',
    'NumberingWindow.cs'
)

$TgirrrMappedFromRibbon = @(
    'CopySequenceTarget.cs',
    'CopySequenceCommands.cs',
    'DripLayoutService.cs',
    'DripLayoutCommands.cs',
    'DripLayoutWindow.cs',
    'LinetypeService.cs',
    'LinetypeWindow.cs',
    'LinetypeCommands.cs',
    'LayerSetCommands.cs',
    'TotalLengthCommands.cs',
    'ConvertToPolylineCommands.cs',
    'NumberingCommands.cs'
)

# ToolCatalog.generated.cs duoc sinh tu src\catalog\tools.json (gen-catalog.ps1)
$TgirrrRawFromShared = @(
    'ToolCatalog.generated.cs',
    'ToolIcons.cs',
    'LoadSettingsWindow.cs',
    'PaletteState.cs',
    'PaletteTheme.cs',
    'ToolChip.cs',
    'PaletteContent.cs',
    'QuickToolsContent.cs'
)

$TgirrrMappedFromShared = @(
    'PaletteCommands.cs'
)

function Convert-TgirrrNamespaceText([string]$Text, [string]$Prefix) {
    $out = $Text
    $out = $out.Replace('Autodesk.AutoCAD.ApplicationServices', "$Prefix.ApplicationServices")
    $out = $out.Replace('Autodesk.AutoCAD.DatabaseServices', "$Prefix.DatabaseServices")
    $out = $out.Replace('Autodesk.AutoCAD.EditorInput', "$Prefix.EditorInput")
    $out = $out.Replace('Autodesk.AutoCAD.Geometry', "$Prefix.Geometry")
    $out = $out.Replace('Autodesk.AutoCAD.Colors', "$Prefix.Colors")
    $out = $out.Replace('Autodesk.AutoCAD.Runtime', "$Prefix.Runtime")
    $out = $out.Replace('Autodesk.AutoCAD.Windows', "$Prefix.Windows")
    return $out
}

function Get-TgirrrTarget([string]$name) {
    switch ($name) {
        'ZWCAD' {
            return @{
                Name      = 'ZWCAD'
                Dst       = (Join-Path $TgirrrRoot 'src\zwcad')
                Prefix    = 'ZwSoft.ZwCAD'
                HostToken = '"ZWCAD"'
                Bundle    = 'TGIRR_CAD_ZWCAD'
                # ZWCAD: Line/Polyline chi co ctor khong doi so, Plane khong co ctor trong.
                Extra = {
                    param($leaf, $text)
                    $t = $text
                    if ($leaf -eq 'DripLayoutCommands.cs') {
                        $t = $t.Replace('new Polyline(2)', 'new Polyline()').Replace('new Polyline(4)', 'new Polyline()')
                    }
                    if ($leaf -eq 'DripLayoutService.cs') {
                        $t = $t.Replace('new Polyline(best.Segments.Count+1)', 'new Polyline()')
                        $t = $t.Replace('new Line(new Point3d(s.Start.X,s.Start.Y,boundary.Elevation),new Point3d(s.End.X,s.End.Y,boundary.Elevation))',
                            'new Line{StartPoint=new Point3d(s.Start.X,s.Start.Y,boundary.Elevation),EndPoint=new Point3d(s.End.X,s.End.Y,boundary.Elevation)}')
                        $t = $t.Replace('new Line(new Point3d(a.X,a.Y,boundary.Elevation),new Point3d(b.X,b.Y,boundary.Elevation))',
                            'new Line{StartPoint=new Point3d(a.X,a.Y,boundary.Elevation),EndPoint=new Point3d(b.X,b.Y,boundary.Elevation)}')
                        $t = $t.Replace('new Line(start-startTan*reach,start+startTan*reach)',
                            'new Line{StartPoint=start-startTan*reach,EndPoint=start+startTan*reach}')
                        $t = $t.Replace('new Line(end-endTan*reach,end+endTan*reach)',
                            'new Line{StartPoint=end-endTan*reach,EndPoint=end+endTan*reach}')
                        $t = $t.Replace('new Line(unique[i],unique[i+1])',
                            'new Line{StartPoint=unique[i],EndPoint=unique[i+1]}')
                        $t = $t.Replace('Convert2d(new Plane())', 'Convert2d(new Plane(new Point3d(0,0,0),new Vector3d(0,0,1)))')
                    }
                    return $t
                }
            }
        }
        'GstarCAD' {
            return @{
                Name      = 'GstarCAD'
                Dst       = (Join-Path $TgirrrRoot 'src\gscad')
                Prefix    = 'Gssoft.Gscad'
                HostToken = '"GstarCAD"'
                Bundle    = 'TGIRR_CAD_GSTARCAD'
                # GstarCAD co ctor cua Line/Polyline/Plane giong AutoCAD -> khong can patch them.
                Extra = {
                    param($leaf, $text)
                    return $text
                }
            }
        }
    }
    throw "Target khong ho tro: $name"
}

# Sinh noi dung file dich tu mot file nguon (khong ghi file).
function Convert-TgirrrSource {
    param(
        [Parameter(Mandatory = $true)][string]$SrcPath,
        [Parameter(Mandatory = $true)]$Target,
        [Parameter(Mandatory = $true)][bool]$Map
    )
    $leaf = Split-Path -Leaf $SrcPath
    $text = [System.IO.File]::ReadAllText($SrcPath, [System.Text.Encoding]::UTF8)
    if ($Map) {
        $text = Convert-TgirrrNamespaceText $text $Target.Prefix
        # ZWCAD/GstarCAD giu DocumentManager + ShowModalWindow trong Core.Application.
        $text = $text.Replace("$($Target.Prefix).ApplicationServices.Application.DocumentManager",
                              "$($Target.Prefix).ApplicationServices.Core.Application.DocumentManager")
        $text = $text.Replace("$($Target.Prefix).ApplicationServices.Application.ShowModalWindow",
                              "$($Target.Prefix).ApplicationServices.Core.Application.ShowModalWindow")
        $text = [regex]::Replace($text, '(?<![.\w])Application\.DocumentManager',
                              "$($Target.Prefix).ApplicationServices.Core.Application.DocumentManager")
        $text = [regex]::Replace($text, '(?<![.\w])Application\.ShowModalWindow',
                              "$($Target.Prefix).ApplicationServices.Core.Application.ShowModalWindow")
        if ($leaf -eq 'PaletteCommands.cs') {
            $text = $text.Replace('"AutoCAD"', $Target.HostToken)
        }
    }
    return & $Target.Extra $leaf $text
}

# Danh sach cap (src -> dst) day du cho mot target + menu cua bundle.
function Get-TgirrrPortPlan {
    param([Parameter(Mandatory = $true)][string]$TargetName)
    $t = Get-TgirrrTarget $TargetName
    $plan = New-Object System.Collections.Generic.List[object]
    foreach ($f in $TgirrrRawFromRibbon) {
        $plan.Add([pscustomobject]@{ Src = (Join-Path $TgirrrRibbonDir $f); Dst = (Join-Path $t.Dst $f); Map = $false })
    }
    foreach ($f in $TgirrrMappedFromRibbon) {
        $plan.Add([pscustomobject]@{ Src = (Join-Path $TgirrrRibbonDir $f); Dst = (Join-Path $t.Dst $f); Map = $true })
    }
    foreach ($f in $TgirrrRawFromShared) {
        $plan.Add([pscustomobject]@{ Src = (Join-Path $TgirrrSharedDir $f); Dst = (Join-Path $t.Dst $f); Map = $false })
    }
    foreach ($f in $TgirrrMappedFromShared) {
        $plan.Add([pscustomobject]@{ Src = (Join-Path $TgirrrSharedDir $f); Dst = (Join-Path $t.Dst $f); Map = $true })
    }
    $plan.Add([pscustomobject]@{
        Src = (Join-Path $TgirrrMenuDir $TgirrrMenuFile)
        Dst = (Join-Path $TgirrrRoot "bundle\$($t.Bundle).bundle\Contents\Lisp\$TgirrrMenuFile")
        Map = $false
    })
    return $plan
}

function Read-TgirrrUtf8([string]$path) {
    return [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
}

# Ghi cac file dich cua mot target. Tra ve danh sach file da thay doi.
function Write-TgirrrPort([string]$TargetName) {
    $t = Get-TgirrrTarget $TargetName
    $enc = New-Object System.Text.UTF8Encoding($false)
    if (-not (Test-Path $t.Dst)) { New-Item -ItemType Directory -Force -Path $t.Dst | Out-Null }
    $changed = New-Object System.Collections.Generic.List[string]
    foreach ($item in (Get-TgirrrPortPlan $TargetName)) {
        if (-not (Test-Path $item.Src)) { throw "Thieu file nguon: $($item.Src)" }
        $text = Convert-TgirrrSource -SrcPath $item.Src -Target $t -Map ([bool]$item.Map)
        $dir = Split-Path -Parent $item.Dst
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
        $same = (Test-Path $item.Dst) -and ((Read-TgirrrUtf8 $item.Dst) -eq $text)
        if (-not $same) {
            [System.IO.File]::WriteAllText($item.Dst, $text, $enc)
            $changed.Add($item.Dst.Substring($TgirrrRoot.Length + 1))
        }
    }
    return $changed
}

# Liet ke nhung file dich lech so voi nguon (khong ghi bat cu thu gi).
function Get-TgirrrPortDrift([string]$TargetName) {
    $t = Get-TgirrrTarget $TargetName
    $drift = New-Object System.Collections.Generic.List[string]
    foreach ($item in (Get-TgirrrPortPlan $TargetName)) {
        if (-not (Test-Path $item.Src)) { $drift.Add("THIEU NGUON: " + $item.Src); continue }
        $text = Convert-TgirrrSource -SrcPath $item.Src -Target $t -Map ([bool]$item.Map)
        if (-not (Test-Path $item.Dst)) { $drift.Add("THIEU FILE: " + $item.Dst.Substring($TgirrrRoot.Length + 1)); continue }
        if ((Read-TgirrrUtf8 $item.Dst) -ne $text) { $drift.Add("LECH: " + $item.Dst.Substring($TgirrrRoot.Length + 1)) }
    }
    return $drift
}
