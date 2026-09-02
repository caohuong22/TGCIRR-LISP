param()
$ErrorActionPreference = 'SilentlyContinue'
$root = 'C:\Program Files\ZWSOFT\ZWCAD 2026'
$handler = [ResolveEventHandler]{ param($s,$e)
  $n = $e.Name.Substring(0,$e.Name.IndexOf(','))
  $cand = Join-Path $root ($n + '.dll')
  if (Test-Path $cand) { return [Reflection.Assembly]::ReflectionOnlyLoadFrom($cand) }
  try { return [Reflection.Assembly]::ReflectionOnlyLoad($e.Name) } catch { return $null }
}
[AppDomain]::CurrentDomain.add_ReflectionOnlyAssemblyResolve($handler)
$asmDb = [Reflection.Assembly]::ReflectionOnlyLoadFrom((Join-Path $root 'ZwDatabaseMgd.dll'))
$asmM  = [Reflection.Assembly]::ReflectionOnlyLoadFrom((Join-Path $root 'ZwManaged.dll'))

function Dump($asm, $typeName, $filter = '') {
  $t = $asm.GetType($typeName)
  "### $typeName"
  if (-not $t) { "  NOT FOUND"; return }
  $t.GetMembers([Reflection.BindingFlags]'Public,Instance,Static,DeclaredOnly') | ForEach-Object {
    if ($_.MemberType -in @('Method','Property','Field','Constructor')) {
      $s = $_.ToString()
      if ($s -notmatch 'add_|remove_|raise_' -and ($filter -eq '' -or $s -match $filter)) { "  {0}" -f $s }
    }
  } | Sort-Object -Unique
}

"##### PlanarEntity / Plane #####"
Dump $asmDb 'ZwSoft.ZwCAD.Geometry.PlanarEntity' 'Get|Set|Normal|Origin|PointOnPlane|CoordinateSystem|DistTo|Project|Constructor'
Dump $asmDb 'ZwSoft.ZwCAD.Geometry.Plane' 'Constructor|Get|Normal|Origin|Point|Coordinate|Project|IsOn'
"##### WorldPlane static refs #####"
$t = $asmDb.GetType('ZwSoft.ZwCAD.Geometry.WorldPlane')
if($t){ $t.GetMembers([Reflection.BindingFlags]'Public,Static') | ForEach-Object { $_.ToString() } } else { 'no WorldPlane type; search static Plane members' ; $asmDb.GetType('ZwSoft.ZwCAD.Geometry.Plane').GetMembers([Reflection.BindingFlags]'Public,Static') | ForEach-Object { $_.ToString() } }
"##### Point3d Convert2d overloads #####"
$asmDb.GetType('ZwSoft.ZwCAD.Geometry.Point3d').GetMethods() | Where-Object { $_.Name -eq 'Convert2d' } | ForEach-Object { $_.ToString() }
"##### Extents3d #####"
Dump $asmDb 'ZwSoft.ZwCAD.Geometry.Extents3d' 'MinPoint|MaxPoint|AddPoint|Constructor|CenterPoint'
"##### LineSegment2d #####"
Dump $asmDb 'ZwSoft.ZwCAD.Geometry.LineSegment2d' 'Direction|Length|StartPoint|EndPoint|IntersectWith|Constructor|GetLine'
"##### CircularArc2d #####"
Dump $asmDb 'ZwSoft.ZwCAD.Geometry.CircularArc2d' 'Radius|StartAngle|EndAngle|Center|IntersectWith|Constructor'
"##### Point3dCollection #####"
Dump $asmDb 'ZwSoft.ZwCAD.Geometry.Point3dCollection' 'Add|Count|Item|Constructor|Clear|RemoveAt'
"##### Vector3d essentials #####"
Dump $asmDb 'ZwSoft.ZwCAD.Geometry.Vector3d' 'DotProduct|XAxis|GetNormal|X|Y|Z|CrossProduct|Length|GetPerpendicularVector|Negate|MultiplyBy|op_Multiply'
"##### IntegerCollection / IntPtr #####"
Dump $asmDb 'ZwSoft.ZwCAD.Geometry.IntegerCollection' 'Add|Count|Item'
"##### Intersect enum #####"
Dump $asmDb 'ZwSoft.ZwCAD.DatabaseServices.Intersect' 'OnBothOperands|ExtendThis|ExtendArgument'
"##### Ribbon namespace (any) #####"
$asmM.GetExportedTypes() | Where-Object { $_.Namespace -match 'Ribbon' } | ForEach-Object { $_.FullName } | Sort-Object
"##### Ribbon.Commands members #####"
Dump $asmM 'ZwSoft.ZwCAD.Ribbon.Commands' ''