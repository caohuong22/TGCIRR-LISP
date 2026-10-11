param(
    [switch]$Check
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

# ===========================================================================
# gen-catalog.ps1 - Sinh cac "mat na giao dien" tu NGUON THAT DUY NHAT:
#   src\catalog\tools.json
# Dau ra:
#   src\menu\TGIRR_CAD.mnu                 (menu keo xuong ZWCAD / GstarCAD)
#   src\shared\ToolCatalog.generated.cs     (palette + Quick Tools + Ribbon tooltip)
#   docs\COMMANDS.md                        (bang lenh giua 2 marker GENERATED)
#   bundle\TGIRR_CAD_{ZWCAD,GSTARCAD}.bundle\Contents\Lisp\TGIRR_CAD.mnu
# Che do -Check: khong ghi file, bao loi neu bat ky dau ra nao lech (dung cho CI).
# ===========================================================================

function Read-Utf8([string]$path) {
    return [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
}

function ConvertTo-AsciiLabel([string]$text) {
    if ([string]::IsNullOrEmpty($text)) { return '' }
    $normalized = $text.Normalize([System.Text.NormalizationForm]::FormD)
    $sb = New-Object System.Text.StringBuilder
    foreach ($ch in $normalized.ToCharArray()) {
        $category = [System.Globalization.CharUnicodeInfo]::GetUnicodeCategory($ch)
        if ($category -eq [System.Globalization.UnicodeCategory]::NonSpacingMark) { continue }
        [void]$sb.Append($ch)
    }
    $result = $sb.ToString().Normalize([System.Text.NormalizationForm]::FormC)
    $result = $result.Replace([string][char]0x0110, 'D').Replace([string][char]0x0111, 'd')
    $result = $result.Replace([string][char]0x2014, '-').Replace([string][char]0x2013, '-')
    $result = $result.Replace([string][char]0x2192, '->')
    $result = $result.Replace([string][char]0x2605, '*').Replace([string][char]0x2606, '*')
    $out = New-Object System.Text.StringBuilder
    foreach ($ch in $result.ToCharArray()) {
        if ([int]$ch -ge 32 -and [int]$ch -lt 127) { [void]$out.Append($ch) }
    }
    return ($out.ToString() -replace '\s+', ' ').Trim()
}

function ConvertTo-CsharpLiteral([string]$text) {
    if ($null -eq $text) { return '""' }
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append('"')
    foreach ($ch in $text.ToCharArray()) {
        $code = [int]$ch
        if ($ch -eq '"') { [void]$sb.Append('\"') }
        elseif ($ch -eq '\') { [void]$sb.Append('\\') }
        elseif ($code -ge 32 -and $code -lt 127) { [void]$sb.Append($ch) }
        else { [void]$sb.AppendFormat('\u{0:x4}', $code) }
    }
    [void]$sb.Append('"')
    return $sb.ToString()
}

function Format-Direct([string]$id, $aliases) {
    $names = @($id) + @($aliases)
    return (($names | ForEach-Object { '`' + $_ + '`' }) -join ', ')
}

# --- Doc va kiem tra catalog -------------------------------------------------
$catalog = (Read-Utf8 (Join-Path $root 'src\catalog\tools.json')) | ConvertFrom-Json
$groups = @{}
foreach ($g in $catalog.groups) { $groups[$g.key] = $g }
$groupOrder = @($catalog.groups | ForEach-Object { $_.key })
$tools = @($catalog.tools)

$ids = @($tools | ForEach-Object { $_.id })
if (($ids | Sort-Object -Unique).Count -ne $ids.Count) { throw 'tools.json: id bi trung' }
$tags = @($tools | ForEach-Object { $_.menu.tag })
if (($tags | Sort-Object -Unique).Count -ne $tags.Count) { throw 'tools.json: menu.tag bi trung' }
foreach ($t in $tools) {
    if (-not $t.menu -or (-not $t.menu.tag) -or (-not $t.menu.label) -or (-not $t.menu.help)) {
        throw "tools.json: $($t.id) thieu menu.tag/label/help"
    }
    if (@($t.hosts).Count -eq 0) { throw "tools.json: $($t.id) khong khai bao host" }
    if ($t.role -eq 'tool') {
        if (-not $groups.ContainsKey($t.group)) { throw "tools.json: $($t.id) tham chieu group la '$($t.group)'" }
        if ([string]::IsNullOrEmpty($t.ribbonPanel)) { throw "tools.json: $($t.id) thieu ribbonPanel" }
    }
}
$order = @($tools | ForEach-Object { $_.id })
if (($order | Sort-Object -Unique).Count -ne $order.Count) { throw 'tools.json: thu tu xuat hien bi trung' }

# --- Kiem tra panel Ribbon (moi lenh AutoCAD xuat dung 1 lan) ----------------
$ribbonSeen = @{}
foreach ($p in @($catalog.ribbonPanels)) {
    if ([string]::IsNullOrEmpty($p.title)) { throw 'tools.json: ribbonPanels co panel thieu title' }
    foreach ($item in @($p.items)) {
        $tool = $tools | Where-Object { $_.id -eq $item.id } | Select-Object -First 1
        if (-not $tool) { throw "tools.json: ribbonPanels tham chieu lenh la '$($item.id)'" }
        if ($tool.role -eq 'ui') { throw "tools.json: lenh giao dien $($item.id) khong duoc nam trong ribbonPanels" }
        if (@($tool.hosts) -notcontains 'AutoCAD') { throw "tools.json: $($item.id) o Ribbon nhung khong ho tro AutoCAD" }
        if ($tool.ribbonPanel -ne $p.title) { throw "tools.json: $($item.id) thieu ribbonPanel khac voi '$($p.title)'" }
        if ($ribbonSeen.ContainsKey($item.id)) { throw "tools.json: $($item.id) xuat hien 2 lan trong ribbonPanels" }
        $ribbonSeen[$item.id] = $p.title
        if ([string]::IsNullOrEmpty($item.icon)) { throw "tools.json: $($item.id) thieu icon trong ribbonPanels" }
    }
}
foreach ($t in $tools) {
    if ($t.role -eq 'tool' -and (@($t.hosts) -contains 'AutoCAD') -and (-not $ribbonSeen.ContainsKey($t.id))) {
        throw "tools.json: $($t.id) ho tro AutoCAD nhung khong co trong ribbonPanels (thieu nut Ribbon)"
    }
}

# --- 1) src\menu\TGIRR_CAD.mnu ----------------------------------------------
$menu = New-Object System.Collections.Generic.List[string]
$menu.Add('***MENUGROUP=TGIRR')
$menu.Add('')
$menu.Add('')
$menu.Add('***POP1')
$menu.Add('**TGIRR_CAD')
$helps = New-Object System.Collections.Generic.List[string]
foreach ($t in $tools) {
    if ($t.menu.separatorBefore) { $menu.Add((' ' * 17) + '[--]') }
    $name = ('ID_TGIRR_{0}' -f $t.menu.tag).PadRight(16) + ' '
    $menu.Add(('{0}[{1}]^C^C{2}' -f $name, (ConvertTo-AsciiLabel $t.menu.label), $t.cmd))
    $helps.Add(('{0}[{1}]' -f $name, (ConvertTo-AsciiLabel $t.menu.help)))
}
$menu.Add('')
$menu.Add('***HELPSTRINGS')
foreach ($h in $helps) { $menu.Add($h) }
$menuText = ($menu -join "`r`n") + "`r`n"

# --- 2) src\shared\ToolCatalog.generated.cs ---------------------------------
$rows = New-Object System.Collections.Generic.List[string]
$index = 0
foreach ($t in $tools) {
    $index++
    $isTool = ($t.role -ne 'ui')
    $accent = 'TgToolAccent.Cyan'
    $groupKey = 'null'
    $groupTitle = 'null'
    if ($isTool) {
        switch ($groups[$t.group].accent) {
            'Green' { $accent = 'TgToolAccent.Green' }
            'Amber' { $accent = 'TgToolAccent.Amber' }
            default { $accent = 'TgToolAccent.Cyan' }
        }
        $groupKey = ConvertTo-CsharpLiteral $t.group
        $groupTitle = ConvertTo-CsharpLiteral $groups[$t.group].title
    }
    $aliasList = @($t.aliases)
    $aliasExpr = if ($aliasList.Count -eq 0) { 'TgToolCatalog.NoAliases' }
                 else { 'new[] { ' + (($aliasList | ForEach-Object { ConvertTo-CsharpLiteral $_ }) -join ', ') + ' }' }
    $hostExpr = 'new[] { ' + ((@($t.hosts) | ForEach-Object { ConvertTo-CsharpLiteral $_ }) -join ', ') + ' }'
    $panel = if ($isTool) { ConvertTo-CsharpLiteral $t.ribbonPanel } else { 'null' }
    $runner = if ($t.runner) { ConvertTo-CsharpLiteral $t.runner } else { '""' }
    $flagTool = if ($isTool) { 'true' } else { 'false' }
    $flagKeep = if ($t.keepSelection) { 'true' } else { 'false' }
    $flagPick = if ($t.requiresSelection) { 'true' } else { 'false' }
    $lines = @(
        '       new TgToolInfo(',
        ('         id: {0}, cmd: {1}, label: {2},' -f (ConvertTo-CsharpLiteral $t.id), (ConvertTo-CsharpLiteral $t.cmd), (ConvertTo-CsharpLiteral $t.label)),
        ('         aliases: {0}, groupKey: {1}, groupTitle: {2}, accent: {3},' -f $aliasExpr, $groupKey, $groupTitle, $accent),
        ('         ribbonPanel: {0}, hosts: {1}, order: {2}, isTool: {3},' -f $panel, $hostExpr, $index, $flagTool),
        ('         keepSelection: {0}, requiresSelection: {1}, runner: {2},' -f $flagKeep, $flagPick, $runner),
        ('         tipTitle: {0}, tipDesc: {1},' -f (ConvertTo-CsharpLiteral $t.tip.title), (ConvertTo-CsharpLiteral $t.tip.desc)),
        ('         tipUsage: {0}, tipCommand: {1},' -f (ConvertTo-CsharpLiteral $t.tip.usage), (ConvertTo-CsharpLiteral $t.tip.command)),
        ('         menuTag: {0}, menuLabel: {1},' -f (ConvertTo-CsharpLiteral $t.menu.tag), (ConvertTo-CsharpLiteral $t.menu.label)),
        ('         menuHelp: {0})' -f (ConvertTo-CsharpLiteral $t.menu.help))
    )
    $rows.Add(($lines -join "`n"))
}

$cs = New-Object System.Collections.Generic.List[string]
$cs.Add('// <auto-generated/>')
$cs.Add('// Sinh tu src/catalog/tools.json boi scripts/gen-catalog.ps1 - KHONG sua tay file nay.')
$cs.Add('// Muon doi nhan lenh, tooltip, nhom, menu hay bang lenh: sua tools.json roi chay:')
$cs.Add('//   powershell -NoProfile -ExecutionPolicy Bypass -File scripts/gen-catalog.ps1')
$cs.Add('namespace Tgirrr.CadLisp {')
$cs.Add(' internal enum TgToolAccent { Cyan, Green, Amber }')
$cs.Add('')
$cs.Add(' /// <summary>Mot cong cu trong catalog, dung chung cho palette, Quick Tools, menu va docs.</summary>')
$cs.Add(' internal sealed class TgToolInfo {')
$cs.Add('  internal readonly string Id, Cmd, Label, GroupKey, GroupTitle, RibbonPanel, Runner;')
$cs.Add('  internal readonly string TipTitle, TipDesc, TipUsage, TipCommand, MenuTag, MenuLabel, MenuHelp;')
$cs.Add('  internal readonly string[] Aliases, Hosts;')
$cs.Add('  internal readonly TgToolAccent Accent;')
$cs.Add('  internal readonly bool IsTool, KeepSelection, RequiresSelection;')
$cs.Add('  internal readonly int Order;')
$cs.Add('  internal TgToolInfo(string id, string cmd, string label, string[] aliases, string groupKey, string groupTitle,')
$cs.Add('    TgToolAccent accent, string ribbonPanel, string[] hosts, int order, bool isTool, bool keepSelection,')
$cs.Add('    bool requiresSelection, string runner, string tipTitle, string tipDesc, string tipUsage, string tipCommand,')
$cs.Add('    string menuTag, string menuLabel, string menuHelp) {')
$cs.Add('      Id = id; Cmd = cmd; Label = label; Aliases = aliases; GroupKey = groupKey; GroupTitle = groupTitle;')
$cs.Add('      Accent = accent; RibbonPanel = ribbonPanel; Hosts = hosts; Order = order; IsTool = isTool;')
$cs.Add('      KeepSelection = keepSelection; RequiresSelection = requiresSelection; Runner = runner;')
$cs.Add('      TipTitle = tipTitle; TipDesc = tipDesc; TipUsage = tipUsage; TipCommand = tipCommand;')
$cs.Add('      MenuTag = menuTag; MenuLabel = menuLabel; MenuHelp = menuHelp;')
$cs.Add('    }')
$cs.Add('    internal bool Supports(string host) {')
$cs.Add('      foreach (var h in Hosts) if (h == host) return true;')
$cs.Add('      return false;')
$cs.Add('    }')
$cs.Add('    /// <summary>Chu hien thi tren badge cua nut (chinh la ten lenh).</summary>')
$cs.Add('    internal string Badge { get { return Id; } }')
$cs.Add('    /// <summary>Nhan tren dong menu: "TITLE - Mo ngan".</summary>')
$cs.Add('    internal string TipHeadline { get { return TipTitle; } }')
$cs.Add('  }')
$cs.Add('')
$cs.Add(' /// <summary>Nguon duy nhat ve danh muc cong cu TGIRR.</summary>')
$cs.Add(' internal static class TgToolCatalog {')
$cs.Add('  internal static readonly string[] NoAliases = new string[0];')
$cs.Add('  internal static readonly TgToolInfo[] All = new TgToolInfo[] {')
$cs.Add(($rows -join ",`n"))
$cs.Add('  };')
$cs.Add('')
$cs.Add('  /// <summary>Danh sach nut hien thi tren palette cua host dang chay.</summary>')
$cs.Add('  internal static TgToolInfo[] ForHost(string host) {')
$cs.Add('    var list = new System.Collections.Generic.List<TgToolInfo>();')
$cs.Add('    foreach (var t in All) if (t.IsTool && t.Supports(host)) list.Add(t);')
$cs.Add('    list.Sort(delegate(TgToolInfo a, TgToolInfo b) { return a.Order.CompareTo(b.Order); });')
$cs.Add('    return list.ToArray();')
$cs.Add('  }')
$cs.Add('')
$cs.Add('  /// <summary>Cac nut cua mot nhom tren palette.</summary>')
$cs.Add('  internal static TgToolInfo[] ForGroup(string host, string groupKey) {')
$cs.Add('    var list = new System.Collections.Generic.List<TgToolInfo>();')
$cs.Add('    foreach (var t in ForHost(host)) if (t.GroupKey == groupKey) list.Add(t);')
$cs.Add('    return list.ToArray();')
$cs.Add('  }')
$cs.Add('')
$cs.Add('  /// <summary>Thu tu nhom dung theo khai bao "groups" trong tools.json.</summary>')
$cs.Add('  internal static string[] GroupKeys(string host) {')
$cs.Add('    var keys = new System.Collections.Generic.List<string>();')
$cs.Add('    foreach (var t in ForHost(host)) if (t.GroupKey != null && !keys.Contains(t.GroupKey)) keys.Add(t.GroupKey);')
$cs.Add('    return keys.ToArray();')
$cs.Add('  }')
$cs.Add('')
$cs.Add('  /// <summary>Mot panel tren Ribbon AutoCAD: tieu de + thu tu nut (nguon: ribbonPanels).</summary>')
$cs.Add('  internal sealed class TgRibbonPanel {')
$cs.Add('    internal readonly string Title;')
$cs.Add('    internal readonly TgToolInfo[] Items;')
$cs.Add('    internal TgRibbonPanel(string title, TgToolInfo[] items) { Title = title; Items = items; }')
$cs.Add('  }')
$cs.Add('')
$cs.Add('  internal static readonly TgRibbonPanel[] RibbonPanels = new[] {')
$panelRows = foreach ($p in @($catalog.ribbonPanels)) {
    $ids = (@($p.items) | ForEach-Object { 'Find(' + (ConvertTo-CsharpLiteral $_.id) + ')' }) -join ', '
    ('    new TgRibbonPanel(' + (ConvertTo-CsharpLiteral $p.title) + ', new TgToolInfo[] { ' + $ids + ' })')
}
$cs.Add(($panelRows -join ",`n"))
$cs.Add('  };')
$cs.Add('')
$cs.Add('  /// <summary>Icon cua mot nut Ribbon, theo ribbonPanels[].items[].icon trong tools.json.</summary>')
$cs.Add('  internal static string RibbonIconByKey(string id) {')
$iconRows = foreach ($p in @($catalog.ribbonPanels)) {
    foreach ($item in @($p.items)) {
        ('      if (id == ' + (ConvertTo-CsharpLiteral $item.id) + ') return ' + (ConvertTo-CsharpLiteral $item.icon) + ';')
    }
}
$cs.Add(($iconRows -join "`r`n"))
$cs.Add('    return "select";')
$cs.Add('  }')
$cs.Add('')
$cs.Add('  internal static TgToolInfo Find(string id) {')
$cs.Add('    foreach (var t in All) if (t.Id == id) return t;')
$cs.Add('    return null;')
$cs.Add('  }')
$cs.Add(' }')
$cs.Add('}')
$csText = ($cs -join "`r`n") + "`r`n"

# --- 3) Bang lenh trong docs\COMMANDS.md ------------------------------------
$doc = New-Object System.Collections.Generic.List[string]
$doc.Add('| Nhóm (Panel) | Lệnh | Chức năng | Gõ trực tiếp? |')
$doc.Add('|---|---|---|---|')
foreach ($t in $tools) {
    $doc.Add(('| {0} | {1} | {2} | Có ({3}) |' -f $t.docs.section, $t.id, $t.docs.function, (Format-Direct $t.id @($t.aliases))))
}

$docsPath = Join-Path $root 'docs\COMMANDS.md'
$beginMark = '<!-- BEGIN GENERATED COMMAND TABLE (source: src/catalog/tools.json) -->'
$endMark = '<!-- END GENERATED COMMAND TABLE -->'
$tableText = ($doc -join "`n")

# --- Ghi file / kiem tra drift ----------------------------------------------
function Write-Target([string]$path, [string]$text) {
    $current = if (Test-Path $path) { Read-Utf8 $path } else { '' }
    $same = ($current.Length -gt 0) -and ($current.Replace("`r`n", "`n") -eq $text.Replace("`r`n", "`n"))
    $name = $path.Substring($root.Length + 1)
    if ($same) { Write-Host "  [OK]   $name" -ForegroundColor Green; return $true }
    if ($Check) { Write-Host "  [LECH] $name khong khop tools.json" -ForegroundColor Red; return $false }
    $dir = Split-Path -Parent $path
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    [System.IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "  [SINH] $name" -ForegroundColor Yellow
    return $true
}

$drift = @()
Write-Host '== Sinh giao dien tu src\catalog\tools.json ==' -ForegroundColor Cyan

$menuPath = Join-Path $root 'src\menu\TGIRR_CAD.mnu'
if (-not (Write-Target $menuPath $menuText)) { $drift += $menuPath }
foreach ($bundleLisp in @('TGIRR_CAD_ZWCAD', 'TGIRR_CAD_GSTARCAD')) {
    $p = Join-Path $root "bundle\$bundleLisp.bundle\Contents\Lisp\TGIRR_CAD.mnu"
    if (Test-Path (Split-Path -Parent $p)) {
        if (-not (Write-Target $p $menuText)) { $drift += $p }
    }
}
$csPath = Join-Path $root 'src\shared\ToolCatalog.generated.cs'
if (-not (Write-Target $csPath $csText)) { $drift += $csPath }

if (Test-Path $docsPath) {
    $docsRaw = Read-Utf8 $docsPath
    $bi = $docsRaw.IndexOf($beginMark)
    $ei = $docsRaw.IndexOf($endMark)
    if ($bi -lt 0 -or $ei -le $bi) { throw "docs/COMMANDS.md thieu cap marker GENERATED COMMAND TABLE" }
    $newDocs = $docsRaw.Substring(0, $bi + $beginMark.Length) + "`n" + $tableText + "`n" + $docsRaw.Substring($ei)
    if (-not (Write-Target $docsPath $newDocs)) { $drift += $docsPath }
} else {
    Write-Host '  [BO QUA] docs/COMMANDS.md khong ton tai' -ForegroundColor DarkGray
}

if ($drift.Count -gt 0) {
    if ($Check) { throw ("Catalog drift (" + $drift.Count + " file): " + (($drift | ForEach-Object { Split-Path $_ }) -join ', ')) }
}
Write-Host '== Catalog OK ==' -ForegroundColor Green
