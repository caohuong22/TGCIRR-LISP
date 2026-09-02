param()
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$src = Join-Path $root 'src\ribbon'
$dst = Join-Path $root 'src\gscad'
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
  @('Autodesk.AutoCAD.ApplicationServices', 'Gssoft.Gscad.ApplicationServices'),
  @('Autodesk.AutoCAD.DatabaseServices',    'Gssoft.Gscad.DatabaseServices'),
  @('Autodesk.AutoCAD.EditorInput',         'Gssoft.Gscad.EditorInput'),
  @('Autodesk.AutoCAD.Geometry',            'Gssoft.Gscad.Geometry'),
  @('Autodesk.AutoCAD.Colors',              'Gssoft.Gscad.Colors'),
  @('Autodesk.AutoCAD.Runtime',             'Gssoft.Gscad.Runtime')
)

$enc = New-Object System.Text.UTF8Encoding($false)

foreach ($f in $shared) {
  $txt = [System.IO.File]::ReadAllText((Join-Path $src $f), $enc)
  [System.IO.File]::WriteAllText((Join-Path $dst $f), $txt, $enc)
}

foreach ($f in $ported) {
  $txt = [System.IO.File]::ReadAllText((Join-Path $src $f), $enc)
  foreach ($s in $subs) { $txt = $txt.Replace($s[0], $s[1]) }

  # GstarCAD keeps DocumentManager AND the WPF ShowModalWindow overload under
  # ApplicationServices.Core.Application (the base Application only exposes
  # ShowModalWindow(Uri)). Fix fully-qualified forms (unique token) first.
  $txt = $txt.Replace('ApplicationServices.Application.DocumentManager', 'ApplicationServices.Core.Application.DocumentManager')
  $txt = $txt.Replace('ApplicationServices.Application.ShowModalWindow', 'ApplicationServices.Core.Application.ShowModalWindow')
  # Then fix the short form when not already qualified (preceded by non-word char).
  $txt = [regex]::Replace($txt, '(?<![.\w])Application\.DocumentManager', 'Gssoft.Gscad.ApplicationServices.Core.Application.DocumentManager')
  $txt = [regex]::Replace($txt, '(?<![.\w])Application\.ShowModalWindow', 'Gssoft.Gscad.ApplicationServices.Core.Application.ShowModalWindow')

  [System.IO.File]::WriteAllText((Join-Path $dst $f), $txt, $enc)
}

Write-Host "Ported files into $dst"
Get-ChildItem $dst -File | ForEach-Object { Write-Host ("  " + $_.Name) }