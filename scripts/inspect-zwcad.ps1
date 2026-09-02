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
      "{0,-10} {1}" -f $m, $_.ToString()
    }
  } | Sort-Object
}

"==================== APPLICATION STATIC ===================="
$app = $asmManaged.GetType('ZwSoft.ZwCAD.ApplicationServices.Application')
$app.GetMembers([Reflection.BindingFlags] 'Public,Static') | Where-Object { $_.MemberType -in @('Method','Property') } | ForEach-Object { "{0,-10} {1}" -f $_.MemberType, $_.ToString() } | Sort-Object

"==================== EDITOR ===================="
DumpType $asmManaged 'ZwSoft.ZwCAD.EditorInput.Editor'

"==================== PROMPTENTITYOPTIONS ===================="
DumpType $asmManaged 'ZwSoft.ZwCAD.EditorInput.PromptEntityOptions'
"==================== PROMPTSELECTIONOPTIONS ===================="
DumpType $asmManaged 'ZwSoft.ZwCAD.EditorInput.PromptSelectionOptions'
"==================== PROMPTPOINTOPTIONS ===================="
DumpType $asmManaged 'ZwSoft.ZwCAD.EditorInput.PromptPointOptions'
"==================== SELECTIONFILTER / TYPEDVALUE ===================="
DumpType $asmManaged 'ZwSoft.ZwCAD.EditorInput.SelectionFilter'
DumpType $asmManaged 'ZwSoft.ZwCAD.EditorInput.TypedValue'
"==================== PROMPTENTITYRESULT / PROMPTPOINTRESULT / PROMPTSELECTIONRESULT ===================="
DumpType $asmManaged 'ZwSoft.ZwCAD.EditorInput.PromptEntityResult'
DumpType $asmManaged 'ZwSoft.ZwCAD.EditorInput.PromptPointResult'
DumpType $asmManaged 'ZwSoft.ZwCAD.EditorInput.PromptSelectionResult'
"==================== PROMPTSTATUS ===================="
DumpType $asmManaged 'ZwSoft.ZwCAD.EditorInput.PromptStatus'