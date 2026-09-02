param()
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$src = Join-Path $root 'src\ribbon'
$dst = Join-Path $root 'src\zwcad'
New-Item -ItemType Directory -Force -Path $dst | Out-Null

# Files that only use System.* / WPF and need no namespace mapping.
$shared = @('CopySequenceService.cs', 'DripFillGeometry.cs', 'CopySequenceWindow.cs')

# Files that reference Autodesk.AutoCAD.* and must be namespace-mapped.
$ported = @(
  'CopySequenceTarget.cs',
  'CopySequenceCommands.cs',
  'DripLayoutService.cs',
  'DripLayoutCommands.cs',
  'DripLayoutWindow.cs',
  'LinetypeService.cs',
  'LinetypeWindow.cs',
  'LinetypeCommands.cs'
)

$subs = @(
  @('Autodesk.AutoCAD.ApplicationServices', 'ZwSoft.ZwCAD.ApplicationServices'),
  @('Autodesk.AutoCAD.DatabaseServices',    'ZwSoft.ZwCAD.DatabaseServices'),
  @('Autodesk.AutoCAD.EditorInput',         'ZwSoft.ZwCAD.EditorInput'),
  @('Autodesk.AutoCAD.Geometry',            'ZwSoft.ZwCAD.Geometry'),
  @('Autodesk.AutoCAD.Colors',              'ZwSoft.ZwCAD.Colors'),
  @('Autodesk.AutoCAD.Runtime',             'ZwSoft.ZwCAD.Runtime')
)

$enc = New-Object System.Text.UTF8Encoding($false)

foreach ($f in $shared) {
  $txt = [System.IO.File]::ReadAllText((Join-Path $src $f), $enc)
  [System.IO.File]::WriteAllText((Join-Path $dst $f), $txt, $enc)
}

foreach ($f in $ported) {
  $txt = [System.IO.File]::ReadAllText((Join-Path $src $f), $enc)
  foreach ($s in $subs) { $txt = $txt.Replace($s[0], $s[1]) }
  # ZWCAD keeps DocumentManager under ApplicationServices.Core.Application.
  # 1) Fix fully-qualified form (unique token) first.
  $txt = $txt.Replace('ApplicationServices.Application.DocumentManager', 'ApplicationServices.Core.Application.DocumentManager')
  # 2) Fix short form only when not already qualified (preceded by non-word char).
  $txt = [regex]::Replace($txt, '(?<![.\w])Application\.DocumentManager', 'ZwSoft.ZwCAD.ApplicationServices.Core.Application.DocumentManager')
  [System.IO.File]::WriteAllText((Join-Path $dst $f), $txt, $enc)
}

# ---- ZWCAD API differences: constructor shape differs from ObjectARX ----
# Line/Polyline in ZWCAD expose only a parameterless ctor + property setters.
# Plane has no parameterless ctor; use world XY plane explicitly.
$patchFile = {
  param($dir, $name, $pairs)
  $p = Join-Path $dir $name
  $txt = [System.IO.File]::ReadAllText($p, (New-Object System.Text.UTF8Encoding($false)))
  $orig = $txt
  foreach ($pr in $pairs) { $txt = $txt.Replace($pr[0], $pr[1]) }
  if ($txt -cne $orig) { [System.IO.File]::WriteAllText($p, $txt, (New-Object System.Text.UTF8Encoding($false))) }
}

& $patchFile $dst 'DripLayoutCommands.cs' @(
  @('new Polyline(2)', 'new Polyline()'),
  @('new Polyline(4)', 'new Polyline()')
)

& $patchFile $dst 'DripLayoutService.cs' @(
  @('new Polyline(best.Segments.Count+1)', 'new Polyline()'),
  @('new Line(new Point3d(s.Start.X,s.Start.Y,boundary.Elevation),new Point3d(s.End.X,s.End.Y,boundary.Elevation))',
    'new Line{StartPoint=new Point3d(s.Start.X,s.Start.Y,boundary.Elevation),EndPoint=new Point3d(s.End.X,s.End.Y,boundary.Elevation)}'),
  @('new Line(new Point3d(a.X,a.Y,boundary.Elevation),new Point3d(b.X,b.Y,boundary.Elevation))',
    'new Line{StartPoint=new Point3d(a.X,a.Y,boundary.Elevation),EndPoint=new Point3d(b.X,b.Y,boundary.Elevation)}'),
  @('new Line(start-startTan*reach,start+startTan*reach)',
    'new Line{StartPoint=start-startTan*reach,EndPoint=start+startTan*reach}'),
  @('new Line(end-endTan*reach,end+endTan*reach)',
    'new Line{StartPoint=end-endTan*reach,EndPoint=end+endTan*reach}'),
  @('new Line(unique[i],unique[i+1])',
    'new Line{StartPoint=unique[i],EndPoint=unique[i+1]}'),
  @('Convert2d(new Plane())', 'Convert2d(new Plane(new Point3d(0,0,0),new Vector3d(0,0,1)))')
)

Write-Host "Applied ZWCAD API patches."

Write-Host "Ported files into $dst"
Get-ChildItem $dst -File | ForEach-Object { Write-Host ("  " + $_.Name) }