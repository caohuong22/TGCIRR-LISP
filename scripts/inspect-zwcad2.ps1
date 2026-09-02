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

function DumpType($asm, $typeName) {
  $t = $asm.GetType($typeName)
  "### $typeName"
  if (-not $t) { "  NOT FOUND"; return }
  $t.GetMembers([Reflection.BindingFlags] 'Public,Instance,Static') | ForEach-Object {
    $m = $_.MemberType
    if ($m -in @('Method','Property','Field')) {
      # only methods/props (skip events/ctors)
      if ($_.ToString() -notmatch 'add_|remove_| raise_') {
        "{0,-10} {1}" -f $m, $_.ToString()
      }
    }
  } | Sort-Object -Unique
}

"##### Application STATIC (filters DocumentManager etc) #####"
$app = $asmManaged.GetType('ZwSoft.ZwCAD.ApplicationServices.Application')
$app.GetMembers([Reflection.BindingFlags] 'Public,Static') | ForEach-Object {
  $s = $_.ToString()
  if ($s -match 'DocumentManager|MdiActiveDocument|Document') { "{0,-10} {1}" -f $_.MemberType, $s }
}

"##### DocumentManager / DocumentCollection #####"
DumpType $asmManaged 'ZwSoft.ZwCAD.ApplicationServices.DocumentCollection'
DumpType $asmManaged 'ZwSoft.ZwCAD.ApplicationServices.DocumentCollectionExtension'

"##### Database (key members only) #####"
$db = $asmDatabase.GetType('ZwSoft.ZwCAD.DatabaseServices.Database')
$db.GetMembers([Reflection.BindingFlags] 'Public,Instance,Static') | Where-Object {
  $s = $_.ToString()
  $s -match 'Insunit|CurrentSpaceId|LayerTableId|LinetypeTableId|BlockTableId|LoadLineTypeFile|Filename|Dispose|TransactionManager' -and $s -notmatch 'add_|remove_'
} | ForEach-Object { "{0,-10} {1}" -f $_.MemberType, $_.ToString() } | Sort-Object -Unique

"##### UnitsValue (Insunits) #####"
DumpType $asmDatabase 'ZwSoft.ZwCAD.DatabaseServices.UnitsValue'

"##### Color + ColorMethod #####"
DumpType $asmDatabase 'ZwSoft.ZwCAD.Colors.Color'
DumpType $asmDatabase 'ZwSoft.ZwCAD.Colors.ColorMethod'

"##### LineWeight #####"
DumpType $asmDatabase 'ZwSoft.ZwCAD.DatabaseServices.LineWeight'

"##### ObjectId essentials #####"
DumpType $asmDatabase 'ZwSoft.ZwCAD.DatabaseServices.ObjectId'

"##### Transaction / TransactionManager #####"
DumpType $asmDatabase 'ZwSoft.ZwCAD.DatabaseServices.Transaction'
DumpType $asmDatabase 'ZwSoft.ZwCAD.DatabaseServices.TransactionManager'

"##### DBObject / Entity #####"
DumpType $asmDatabase 'ZwSoft.ZwCAD.DatabaseServices.DBObject'
DumpType $asmDatabase 'ZwSoft.ZwCAD.DatabaseServices.Entity'