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
$asmManaged  = [Reflection.Assembly]::ReflectionOnlyLoadFrom((Join-Path $root 'ZwManaged.dll'))
$asmDatabase = [Reflection.Assembly]::ReflectionOnlyLoadFrom((Join-Path $root 'ZwDatabaseMgd.dll'))

function DumpType($asm, $typeName, $filter = '') {
  $t = $asm.GetType($typeName)
  "### $typeName"
  if (-not $t) { "  NOT FOUND"; return }
  $t.GetMembers([Reflection.BindingFlags] 'Public,Instance,Static,DeclaredOnly') | ForEach-Object {
    $m = $_.MemberType
    if ($m -in @('Method','Property','Field','Constructor')) {
      $s = $_.ToString()
      if ($s -notmatch 'add_|remove_|raise_' -and ($filter -eq '' -or $s -match $filter)) {
        "{0,-12} {1}" -f $m, $s
      }
    }
  } | Sort-Object -Unique
}

"##### How to get DocumentCollection singleton #####"
$asmManaged.GetType('ZwSoft.ZwCAD.ApplicationServices.DocumentCollection').GetMembers([Reflection.BindingFlags]'Public,Static') | ForEach-Object { $_.ToString() }
"--- Application static: DocumentManager? ---"
$asmManaged.GetType('ZwSoft.ZwCAD.ApplicationServices.Application').GetMembers([Reflection.BindingFlags]'Public,Static') | Where-Object { $_.ToString() -match 'get_|Manager' } | ForEach-Object { $_.ToString() } | Sort-Object

"##### TypedValue #####"
DumpType $asmDatabase 'ZwSoft.ZwCAD.DatabaseServices.TypedValue'
"##### SelectionSet #####"
DumpType $asmManaged 'ZwSoft.ZwCAD.EditorInput.SelectionSet' 'GetObjectIds|Constructor|Count|Item'
"##### OpenMode #####"
DumpType $asmDatabase 'ZwSoft.ZwCAD.DatabaseServices.OpenMode'
"##### TransactionManager (GetObject/StartTransaction) #####"
DumpType $asmDatabase 'ZwSoft.ZwCAD.DatabaseServices.TransactionManager' 'GetObject|StartTransaction|NumOf|Dispose'
"##### Transaction GetObject #####"
$asmDatabase.GetType('ZwSoft.ZwCAD.DatabaseServices.Transaction').GetMethods() | Where-Object { $_.Name -eq 'GetObject' } | ForEach-Object { $_.ToString() }
"##### BlockTableRecord / SymbolTable #####"
DumpType $asmDatabase 'ZwSoft.ZwCAD.DatabaseServices.BlockTableRecord' 'AppendEntity|Cast|ObjectId|Name'
DumpType $asmDatabase 'ZwSoft.ZwCAD.DatabaseServices.SymbolTable' 'Has|this|Add|Cast'
"##### LayerTableRecord / LayerTable #####"
DumpType $asmDatabase 'ZwSoft.ZwCAD.DatabaseServices.LayerTableRecord' 'Name|Color|Linetype|Constructor'
DumpType $asmDatabase 'ZwSoft.ZwCAD.DatabaseServices.LayerTable' ''
"##### LinetypeTable / LinetypeTableRecord #####"
DumpType $asmDatabase 'ZwSoft.ZwCAD.DatabaseServices.LinetypeTable' 'Has|Add|Cast'
DumpType $asmDatabase 'ZwSoft.ZwCAD.DatabaseServices.LinetypeTableRecord' 'Name'
"##### Polyline (key) #####"
DumpType $asmDatabase 'ZwSoft.ZwCAD.DatabaseServices.Polyline' 'AddVertexAt|Closed|NumberOfVertices|GetPoint2dAt|GetSegmentType|GetLineSegment2dAt|GetArcSegment2dAt|Elevation|Area|GetOffsetCurves|StartPoint|EndPoint|GetBulgeAt|GetFirstDerivative|GetPointAtDist|SetPointAt|NumberOf'
"##### Geometry Point3d/Vector3d/Matrix3d/Point2d/Vector2d #####"
DumpType $asmDatabase 'ZwSoft.ZwCAD.Geometry.Point3d' 'Displacement|DistanceTo|X|Y|Z|Origin|DotProduct|GetAsVector|Convert2d'
DumpType $asmDatabase 'ZwSoft.ZwCAD.Geometry.Matrix3d' 'Displacement'
DumpType $asmDatabase 'ZwSoft.ZwCAD.Geometry.Point2d' 'X|Y|GetAsVector'
DumpType $asmDatabase 'ZwSoft.ZwCAD.Geometry.Vector2d' 'XAxis|GetNormal|GetPerpendicularVector|X|Y'
"##### Text entities #####"
DumpType $asmDatabase 'ZwSoft.ZwCAD.DatabaseServices.DBText' 'TextString|Position|Constructor'
DumpType $asmDatabase 'ZwSoft.ZwCAD.DatabaseServices.MText' 'Contents|Location|Constructor'
DumpType $asmDatabase 'ZwSoft.ZwCAD.DatabaseServices.MLeader' 'ContentType|MText|TextLocation|Constructor'
DumpType $asmDatabase 'ZwSoft.ZwCAD.DatabaseServices.AttributeReference' 'Tag|TextString|Position|OwnerId|Constructor'
DumpType $asmDatabase 'ZwSoft.ZwCAD.DatabaseServices.Dimension' 'DimensionText|TextPosition|Constructor'
DumpType $asmDatabase 'ZwSoft.ZwCAD.DatabaseServices.BlockReference' 'AttributeCollection|BlockId|Position|Constructor'
DumpType $asmDatabase 'ZwSoft.ZwCAD.DatabaseServices.Line' 'StartPoint|EndPoint|Constructor'
DumpType $asmDatabase 'ZwSoft.ZwCAD.DatabaseServices.Circle' 'Radius|Center|Constructor'
"##### ContentType #####"
DumpType $asmDatabase 'ZwSoft.ZwCAD.DatabaseServices.ContentType'
"##### AttributeCollection #####"
DumpType $asmDatabase 'ZwSoft.ZwCAD.DatabaseServices.AttributeCollection' 'AppendAttribute|Item|Count'
"##### DBObjectCollection / AddNewlyCreatedDBObject #####"
DumpType $asmDatabase 'ZwSoft.ZwCAD.DatabaseServices.DBObjectCollection' 'Add|Count|Item'
DumpType $asmDatabase 'ZwSoft.ZwCAD.DatabaseServices.Transaction' 'AddNewlyCreatedDBObject'