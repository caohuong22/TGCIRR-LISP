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

# Tooltip ngan cho nut toolbar native: "ID - cach dung ngan" (mot dong).
function Get-ShortTip($t) {
    $text = ''
    if (-not [string]::IsNullOrWhiteSpace($t.tip.usage)) { $text = $t.tip.usage }
    elseif (-not [string]::IsNullOrWhiteSpace($t.tip.desc)) { $text = $t.tip.desc }
    else { $text = $t.menu.help }
    $cut = $text.IndexOf('. ')
    if ($cut -gt 12) { $text = $text.Substring(0, $cut) }
    $text = $text.Trim().TrimEnd('.')
    if ($text.Length -gt 64) {
        $text = $text.Substring(0, 61)
        $space = $text.LastIndexOf(' ')
        if ($space -gt 30) { $text = $text.Substring(0, $space) }
        $text = $text.TrimEnd(',', ';', ':') + '...'
    }
    return ($t.id + ' - ' + $text)
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
    if ([string]::IsNullOrEmpty($t.icon)) { throw "tools.json: $($t.id) thieu icon" }
    if ($t.role -eq 'tool') {
        if (-not $groups.ContainsKey($t.group)) { throw "tools.json: $($t.id) tham chieu group la '$($t.group)'" }
        if ([string]::IsNullOrEmpty($t.ribbonPanel)) { throw "tools.json: $($t.id) thieu ribbonPanel" }
    }
}
$order = @($tools | ForEach-Object { $_.id })
if (($order | Sort-Object -Unique).Count -ne $order.Count) { throw 'tools.json: thu tu xuat hien bi trung' }

# --- Kiem tra cac lenh LISP co the bat/tat nap --------------------------------
$loadUnits = @($catalog.loadUnits)
if ($loadUnits.Count -eq 0) { throw 'tools.json: thieu loadUnits' }
$loadCommands = @()
foreach ($u in $loadUnits) {
    if ([string]::IsNullOrEmpty($u.file)) { throw 'tools.json: loadUnits thieu file' }
    if (@($u.commands).Count -eq 0) { throw "tools.json: loadUnits $($u.file) thieu commands" }
    $loadCommands += @($u.commands)
}
if (($loadCommands | Sort-Object -Unique).Count -ne $loadCommands.Count) { throw 'tools.json: loadUnits.commands bi trung' }
foreach ($cmd in $loadCommands) {
    $tool = $tools | Where-Object { $_.cmd -eq $cmd -or (@($_.aliases) -contains $cmd) } | Select-Object -First 1
    if (-not $tool) { throw "tools.json: loadUnits.commands co '$cmd' nhung khong co trong tools" }
}

# --- Danh muc lenh (moi lenh AutoCAD xuat dung 1 lan) ------------------------
$ribbonSeen = @{}
foreach ($p in @($catalog.ribbonPanels)) {
    if ([string]::IsNullOrEmpty($p.title)) { throw 'tools.json: ribbonPanels co panel thieu title' }
    foreach ($item in @($p.items)) {
        $tool = $tools | Where-Object { $_.id -eq $item.id } | Select-Object -First 1
        if (-not $tool) { throw "tools.json: ribbonPanels tham chieu lenh la '$($item.id)'" }
        if (@($tool.hosts) -notcontains 'AutoCAD') { throw "tools.json: $($item.id) o Ribbon nhung khong ho tro AutoCAD" }
        # role 'ui' khong co ribbonPanel rieng nen chi kiem tra panel cho lenh cong cu.
        if ($tool.role -ne 'ui' -and $tool.ribbonPanel -ne $p.title) { throw "tools.json: $($item.id) thieu ribbonPanel khac voi '$($p.title)'" }
        if ($ribbonSeen.ContainsKey($item.id)) { throw "tools.json: $($item.id) xuat hien 2 lan trong ribbonPanels" }
        $ribbonSeen[$item.id] = $p.title
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
    $helps.Add(('{0}[{1}]' -f $name, (ConvertTo-AsciiLabel (Get-ShortTip $t))))
}
$menu.Add('')
$menu.Add('***TOOLBARS')
$menu.Add('**TB_TGIRR')
$tbName = 'ID_TB_TGIRR'.PadRight(16) + ' '
$menu.Add(('{0}[_Toolbar("TGIRR CAD", _Floating, _Show, 200, 200)]' -f $tbName))
foreach ($t in $tools) {
    if ($t.role -ne 'tool') { continue }
    $btn = ('ID_TGIRR_{0}' -f $t.menu.tag).PadRight(16) + ' '
    # Nut toolbar chi hien icon; chu nay la tooltip khi hover (ten lenh + cach dung ngan).
    $label = ConvertTo-AsciiLabel (Get-ShortTip $t)
    $small = ('"' + $t.menu.tag + '.bmp"')
    $large = ('"' + $t.menu.tag + '_L.bmp"')
    $menu.Add(('{0}[_Button("{1}", {2}, {3})]^C^C{4}' -f $btn, $label, $small, $large, $t.cmd))
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
    $flagManaged = if ($t.managed) { 'true' } else { 'false' }
    $lines = @(
        '       new TgToolInfo(',
        ('         id: {0}, cmd: {1}, label: {2}, icon: {3},' -f (ConvertTo-CsharpLiteral $t.id), (ConvertTo-CsharpLiteral $t.cmd), (ConvertTo-CsharpLiteral $t.label), (ConvertTo-CsharpLiteral $t.icon)),
        ('         aliases: {0}, groupKey: {1}, groupTitle: {2}, accent: {3},' -f $aliasExpr, $groupKey, $groupTitle, $accent),
        ('         ribbonPanel: {0}, hosts: {1}, order: {2}, isTool: {3},' -f $panel, $hostExpr, $index, $flagTool),
        ('         keepSelection: {0}, requiresSelection: {1}, runner: {2}, managed: {3},' -f $flagKeep, $flagPick, $runner, $flagManaged),
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
$cs.Add('  internal readonly string Id, Cmd, Label, Icon, GroupKey, GroupTitle, RibbonPanel, Runner;')
$cs.Add('  internal readonly string TipTitle, TipDesc, TipUsage, TipCommand, MenuTag, MenuLabel, MenuHelp;')
$cs.Add('  internal readonly string[] Aliases, Hosts;')
$cs.Add('  internal readonly TgToolAccent Accent;')
$cs.Add('  internal readonly bool IsTool, KeepSelection, RequiresSelection, Managed;')
$cs.Add('  internal readonly int Order;')
$cs.Add('  internal TgToolInfo(string id, string cmd, string label, string icon, string[] aliases, string groupKey, string groupTitle,')
$cs.Add('    TgToolAccent accent, string ribbonPanel, string[] hosts, int order, bool isTool, bool keepSelection,')
$cs.Add('    bool requiresSelection, string runner, bool managed, string tipTitle, string tipDesc, string tipUsage, string tipCommand,')
$cs.Add('    string menuTag, string menuLabel, string menuHelp) {')
$cs.Add('      Id = id; Cmd = cmd; Label = label; Icon = icon; Aliases = aliases; GroupKey = groupKey; GroupTitle = groupTitle;')
$cs.Add('      Accent = accent; RibbonPanel = ribbonPanel; Hosts = hosts; Order = order; IsTool = isTool;')
$cs.Add('      KeepSelection = keepSelection; RequiresSelection = requiresSelection; Runner = runner; Managed = managed;')
$cs.Add('      TipTitle = tipTitle; TipDesc = tipDesc; TipUsage = tipUsage; TipCommand = tipCommand;')
$cs.Add('      MenuTag = menuTag; MenuLabel = menuLabel; MenuHelp = menuHelp;')
$cs.Add('    }')
$cs.Add('    internal bool Supports(string host) {')
$cs.Add('      foreach (var h in Hosts) if (h == host) return true;')
$cs.Add('      return false;')
$cs.Add('    }')
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
$cs.Add('    foreach (var t in All) if (t.IsTool && t.Supports(host) && LoadSettingsStore.IsEnabled(t.Id)) list.Add(t);')
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
$cs.Add('  /// <summary>Mot file LISP cung cac lenh no dinh nghia (nguon: loadUnits trong tools.json).</summary>')
$cs.Add('  internal sealed class TgLoadUnit {')
$cs.Add('    internal readonly string File, Note;')
$cs.Add('    internal readonly string[] Commands;')
$cs.Add('    internal TgLoadUnit(string file, string[] commands, string note) {')
$cs.Add('      File = file; Commands = commands; Note = note;')
$cs.Add('    }')
$cs.Add('    internal bool Defines(string command) {')
$cs.Add('      foreach (var c in Commands) if (c == command) return true;')
$cs.Add('      return false;')
$cs.Add('    }')
$cs.Add('  }')
$cs.Add('')
$cs.Add('  /// <summary>Cac file LISP nguoi dung co the bat/tat nap de tranh xung dot.</summary>')
$cs.Add('  internal static readonly TgLoadUnit[] LoadUnits = new[] {')
$unitRows = foreach ($u in $loadUnits) {
    $cmds = (@($u.commands) | ForEach-Object { ConvertTo-CsharpLiteral $_ }) -join ', '
    ('    new TgLoadUnit({0}, new[] {{ {1} }}, {2})' -f (ConvertTo-CsharpLiteral $u.file), $cmds, (ConvertTo-CsharpLiteral $u.note))
}
$cs.Add(($unitRows -join ",`n"))
$cs.Add('  };')
$cs.Add('')
$cs.Add('  /// <summary>Toan bo lenh do cac file LISP dinh nghia (de liet ke trong hop thoai cai dat).</summary>')
$cs.Add('  internal static string[] LoadUnitCommands() {')
$cs.Add('    var list = new System.Collections.Generic.List<string>();')
$cs.Add('    foreach (var u in LoadUnits) foreach (var c in u.Commands) list.Add(c);')
$cs.Add('    return list.ToArray();')
$cs.Add('  }')
$cs.Add('')
$cs.Add('  /// <summary>Lenh .NET: ten nguoi dung -> ten lenh noi bo (TGIRR + ten).</summary>')
$cs.Add('  internal static string ManagedCommand(string id) { return "TGIRR" + id; }')
$cs.Add('')
$cs.Add('  /// <summary>Cac lenh do DLL .NET dinh nghia (co the tat de nhuong ten cho LISP khac).</summary>')
$cs.Add('  internal static TgToolInfo[] ManagedTools() {')
$cs.Add('    var list = new System.Collections.Generic.List<TgToolInfo>();')
$cs.Add('    foreach (var t in All) if (t.IsTool && t.Managed) list.Add(t);')
$cs.Add('    return list.ToArray();')
$cs.Add('  }')
$cs.Add('')
$cs.Add('  /// <summary>File LISP dinh nghia mot lenh, hoac null neu lenh khong thuoc LISP nao.</summary>')
$cs.Add('  internal static string LoadUnitFor(string command) {')
$cs.Add('    foreach (var u in LoadUnits) if (u.Defines(command)) return u.File;')
$cs.Add('    return null;')
$cs.Add('  }')
$cs.Add('')
$cs.Add('  /// <summary>Khoa icon cua mot lenh, theo "icon" trong tools.json.</summary>')
$cs.Add('  internal static string RibbonIconByKey(string id) {')
$iconRows = foreach ($t in $tools) {
    ('      if (id == ' + (ConvertTo-CsharpLiteral $t.id) + ') return ' + (ConvertTo-CsharpLiteral $t.icon) + ';')
}
$cs.Add(($iconRows -join "`r`n"))
$cs.Add('    return "crosshair";')
$cs.Add('  }')
$cs.Add('')
$cs.Add('  internal static TgToolInfo Find(string id) {')
$cs.Add('    foreach (var t in All) if (t.Id == id) return t;')
$cs.Add('    return null;')
$cs.Add('  }')
$cs.Add(' }')
$cs.Add('}')
$csText = ($cs -join "`r`n") + "`r`n"

# --- 2b) src\lisp\TGIRRCOMMANDS.lsp: shim cho lenh .NET ----------------------
# Lenh .NET duoc dang ky duoi ten noi bo TGIRR<CMD> (khong the trung LISP khac).
# LISP shim c:<CMD> chi duoc dinh nghia khi lenh con bat trong TGIRRSETTINGS,
# nho vay tat mot lenh la LISP cua nguoi dung cung ten co the chay.
$shim = New-Object System.Collections.Generic.List[string]
$shim.Add(';;; TGIRRCOMMANDS.lsp - SINH TU DONG tu src/catalog/tools.json (scripts/gen-catalog.ps1).')
$shim.Add(';;; KHONG sua tay file nay.')
$shim.Add(';;;')
$shim.Add(';;; Cac lenh .NET (TL, TGN, TNET, TGL, TGLADD, CPLUS, VDNG, CVPL...) duoc dang ky')
$shim.Add(';;; duoi ten noi bo TGIRR<CMD> de khong bao gio trung voi LISP cua nguoi dung.')
$shim.Add(';;; File nay tao lai ten quen thuoc c:<CMD> nhung chi khi lenh con duoc bat trong')
$shim.Add(';;; TGIRRSETTINGS (xem TGIRR:LOAD-ENABLED-P trong loader).')
$shim.Add('(vl-load-com)')
$shim.Add('')
$shim.Add(';; Doc cai dat bat/tat (file nay tu doc duoc, khong phu thuoc loader).')
$shim.Add('(defun TGIRR:CMDSET-FILE (/ appdata)')
$shim.Add('  (setq appdata (getenv "APPDATA"))')
$shim.Add('  (if (and appdata (> (strlen appdata) 0))')
$shim.Add('    (strcat appdata "\\TGIRR\\load-settings.txt")')
$shim.Add('    nil))')
$shim.Add('')
$shim.Add('(defun TGIRR:CMDSET-TOKENS (text / pos out tok)')
$shim.Add('  (setq out nil)')
$shim.Add('  (while (and text (setq pos (vl-string-search "," text)))')
$shim.Add('    (setq tok (substr text 1 pos)')
$shim.Add('          text (substr text (+ pos 2)))')
$shim.Add('    (if (> (strlen tok) 0) (setq out (cons tok out))))')
$shim.Add('  (if (and text (> (strlen text) 0)) (setq out (cons text out)))')
$shim.Add('  (reverse out))')
$shim.Add('')
$shim.Add('(defun TGIRR:CMDSET-DISABLED (/ path fh line rest pos)')
$shim.Add('  (setq path (TGIRR:CMDSET-FILE))')
$shim.Add('  (setq line nil)')
$shim.Add('  (if (and path (findfile path) (setq fh (open path "r")))')
$shim.Add('    (progn')
$shim.Add('      (setq line (read-line fh))')
$shim.Add('      (close fh)))')
$shim.Add('  (setq rest (if (and line (= (substr line 1 2) "v1")) (substr line 3) ""))')
$shim.Add('  (setq pos (vl-string-search "disabled=" rest))')
$shim.Add('  (if pos (TGIRR:CMDSET-TOKENS (substr rest (+ pos 10))) nil))')
$shim.Add('')
$shim.Add('(defun TGIRR:LOAD-ENABLED-P (id)')
$shim.Add('  (not (member id (TGIRR:CMDSET-DISABLED))))')
$shim.Add('')
$shim.Add(';; Toan bo lenh TGIRR quan ly duoc (de canh bao khi tat sach).')
$allCommands = @()
foreach ($t in $tools) {
    if ($t.role -ne 'tool') { continue }
    $allCommands += ('"' + $t.cmd + '"')
}
$shim.Add(('(setq *TGIRR:ALL-COMMANDS* (list {0}))' -f ($allCommands -join ' ')))
$shim.Add('')
$shim.Add('(defun TGIRR:RUN (command / doc)')
$shim.Add('  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))')
$shim.Add('  (vla-SendCommand doc (strcat command " ")))')
$shim.Add('')
foreach ($t in $tools) {
    if (-not $t.managed) { continue }
    $shim.Add((';; {0} -> {1}' -f $t.id, ('TGIRR' + $t.cmd)))
    $shim.Add(('(if (TGIRR:LOAD-ENABLED-P "{0}") (defun c:{1} () (TGIRR:RUN "{2}")))' -f $t.id, $t.cmd, ('TGIRR' + $t.cmd)))
    foreach ($alias in @($t.aliases)) {
        if ([string]::IsNullOrEmpty($alias)) { continue }
        $shim.Add(('(if (TGIRR:LOAD-ENABLED-P "{0}") (defun c:{1} () (TGIRR:RUN "{2}")))' -f $t.id, $alias, ('TGIRR' + $alias)))
    }
}
$shim.Add('')
$shim.Add(';; Go cac lenh LISP bi tat (file .lsp da duoc manifest nap truoc file nay).')
$shim.Add(';; Viet truc tiep tung lenh, khong dung eval/read.')
foreach ($u in $loadUnits) {
    foreach ($cmd in @($u.commands)) {
        if ([string]::IsNullOrEmpty($cmd)) { continue }
        $shim.Add(('(if (not (TGIRR:LOAD-ENABLED-P "{0}")) (setq C:{1} nil))' -f $cmd, $cmd))
    }
}
$shim.Add('')
$shim.Add('(princ)')
$shimText = ($shim -join "`r`n") + "`r`n"

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
foreach ($bundleLisp in @('TGIRR_CAD_LISP', 'TGIRR_CAD_ZWCAD', 'TGIRR_CAD_GSTARCAD')) {
    $p = Join-Path $root "bundle\$bundleLisp.bundle\Contents\Lisp\TGIRR_CAD.mnu"
    if (Test-Path (Split-Path -Parent $p)) {
        if (-not (Write-Target $p $menuText)) { $drift += $p }
        # Icon BMP phai nam cung thu muc .mnu de _Button tim thay
        $iconSrc = Join-Path $root 'src\menu\icons'
        if (Test-Path $iconSrc) {
            Copy-Item (Join-Path $iconSrc '*.bmp') (Split-Path -Parent $p) -Force
        }
    }
}
$csPath = Join-Path $root 'src\shared\ToolCatalog.generated.cs'
if (-not (Write-Target $csPath $csText)) { $drift += $csPath }
$shimPath = Join-Path $root 'src\lisp\TGIRRCOMMANDS.lsp'
if (-not (Write-Target $shimPath $shimText)) { $drift += $shimPath }

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
