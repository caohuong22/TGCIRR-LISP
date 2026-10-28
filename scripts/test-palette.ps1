param()
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

# ===========================================================================
# test-palette.ps1 - Chay toan bo kiem tra cua TGIRR:
#   [1/4] src/catalog/tools.json -> menu + ToolCatalog + shim + docs (khong duoc lech)
#   [2/4] src/ribbon + src/shared -> src/zwcad + src/gscad (khong duoc lech)
#   [3/4] Build toan bo solution (gồm mọi test project)
#   [4/4] Chay MOI project trong tests\ (tu dong liet ke, khong hard-code)
# Chay: powershell -File scripts\test-palette.ps1
# ===========================================================================

Write-Host '[1/4] Kiem tra catalog (tools.json -> menu/docs/ToolCatalog/shim)' -ForegroundColor Cyan
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'gen-catalog.ps1') -Check
if ($LASTEXITCODE -ne 0) { throw 'Catalog drift: chay scripts/gen-catalog.ps1 roi commit lai dau ra.' }

Write-Host '[2/4] Kiem tra ban port ZWCAD / GstarCAD' -ForegroundColor Cyan
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'port-verify.ps1')
if ($LASTEXITCODE -ne 0) { throw 'Port drift: chay scripts/port-zwcad.ps1 va scripts/port-gscad.ps1.' }

# Moi test project deu duoc liet ke tu thu muc tests\ nen them project moi
# khong phai sua script nay.
$projects = Get-ChildItem (Join-Path $root 'tests') -Directory |
    ForEach-Object { Join-Path $_.FullName ($_.Name + '.csproj') } |
    Where-Object { Test-Path $_ } |
    Sort-Object
if ($projects.Count -eq 0) { throw 'Khong tim thay test project nao trong tests\' }

Write-Host ('[3/4] Build solution (TGIRR.slnx, {0} test project)' -f $projects.Count) -ForegroundColor Cyan
# Solution chua 3 project CAD can DLL tham chieu trong Reference\ (bi gitignore,
# ~155MB). May dev co Reference\ thi build that; CI/nguoi moi checkout thi bo qua
# va chi build cac test project (chi gom C# thuan, khong can API CAD).
$referenceDir = Join-Path $root 'Reference'
$hasReference = (Test-Path (Join-Path $referenceDir 'netstandard2.0\acmgd.dll')) -or
                (Test-Path (Join-Path $referenceDir 'Cad2023\net48\acmgd.dll'))
if ($hasReference) {
    dotnet build (Join-Path $root 'TGIRR.slnx') -c Release --nologo -v minimal
    if ($LASTEXITCODE -ne 0) { throw 'Build solution that bai' }
} else {
    Write-Host '  (bo qua: khong co Reference\ - chi build test project)' -ForegroundColor DarkGray
}

Write-Host '[4/4] Chay tat ca regression test' -ForegroundColor Cyan
$failed = New-Object System.Collections.Generic.List[string]
foreach ($p in $projects) {
    $name = [System.IO.Path]::GetFileNameWithoutExtension($p)
    Write-Host ("  -> {0}" -f $name) -ForegroundColor DarkGray
    dotnet run --project $p -c Release
    if ($LASTEXITCODE -ne 0) { $failed.Add($name) }
}
if ($failed.Count -gt 0) { throw ('Regression that bai: ' + ($failed -join ', ')) }

Write-Host ''
Write-Host ('TEST TGIRR: PASSED ({0} project)' -f $projects.Count) -ForegroundColor Green
