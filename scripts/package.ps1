param([string]$AutoCADDir='')
$ErrorActionPreference='Stop'
$project = "$PSScriptRoot\..\src\ribbon\TGIRR.Ribbon.csproj"
if ($AutoCADDir) { dotnet build $project -c Release -p:AutoCADDir="$AutoCADDir" } else { dotnet build $project -c Release }
if ($LASTEXITCODE -ne 0) { throw "Ribbon build failed with exit code $LASTEXITCODE" }
Copy-Item "$PSScriptRoot\..\src\ribbon\bin\Release\net48\TGIRR.Ribbon.dll" "$PSScriptRoot\..\bundle\TGIRR_CAD_LISP.bundle\Contents\Windows\" -Force
$lispSource = "$PSScriptRoot\..\src\lisp"
$lispTarget = "$PSScriptRoot\..\bundle\TGIRR_CAD_LISP.bundle\Contents\Lisp"
$allowed = @('SBS.lsp','TL.lsp','TGL.lsp','VDNG.lsp')
Get-ChildItem $lispTarget -Filter '*.lsp' -ErrorAction SilentlyContinue | Remove-Item -Force
foreach ($file in $allowed) { Copy-Item (Join-Path $lispSource $file) $lispTarget -Force }
<#
foreach ($file in @('SBS.lsp','TL.lsp','TGL.lsp')) {
    $text = [IO.File]::ReadAllText((Join-Path $lispSource $file), [Text.Encoding]::UTF8)
    $parts += "
;;; ===== $file ====="
    $parts += $text.Trim()
}
$parts += '(prompt "\nTGIRR: Da nap day du SBS, TL, TGL, C+ va C-.")'
$parts += '(princ)'
[IO.File]::WriteAllText((Join-Path $lispTarget 'TGIRR_All.lsp'), ($parts -join "
") + "
", (New-Object Text.UTF8Encoding($true)))
 #>
Write-Host 'Bundle ready: bundle\TGIRR_CAD_LISP.bundle'
