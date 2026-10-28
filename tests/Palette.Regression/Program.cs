using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using Tgirrr.CadLisp;

/// <summary>
/// Test hoi quy cho danh muc cong cu TGIRR: moi "mat na" giao dien (palette, Quick Tools,
/// menu keo xuong, bang lenh trong docs, nut + tooltip Ribbon) deu phai duoc sinh tu
/// CUNG MOT nguon src/catalog/tools.json. Chay: scripts/test-palette.ps1
/// </summary>
internal static class Program {
 static int passed, failed;
 static string Root;

 static void Check(string name, bool ok) {
  if (ok) { passed++; Console.WriteLine("PASS: " + name); }
  else { failed++; Console.WriteLine("FAIL: " + name); }
 }

 static string Norm(string s) { return s.Replace("\r\n", "\n"); }

 static string Read(string rel) {
  return File.ReadAllText(Path.Combine(Root, rel.Replace('/', Path.DirectorySeparatorChar)), Encoding.UTF8);
 }

 static int Main() {
  Root = FindRoot();
  if (Root == null) {
   Console.WriteLine("FAIL: khong tim thay thu muc goc repo (chua src/catalog/tools.json)");
   return 1;
  }

  List<TgToolInfo> all = TgToolCatalog.All.ToList();
  List<TgToolInfo> tools = all.Where(t => t.IsTool).ToList();

  Console.WriteLine("== 1. Catalog (duoc sinh tu src/catalog/tools.json) ==");
  Check("catalog co du lenh", all.Count >= 13);
  Check("id khong trung", all.Select(t => t.Id).Distinct().Count() == all.Count);
  Check("menu.tag khong trung", all.Select(t => t.MenuTag).Distinct().Count() == all.Count);
  Check("order khong trung", all.Select(t => t.Order).Distinct().Count() == all.Count);
  Check("badge = id voi moi nut", tools.TrueForAll(t => t.Badge == t.Id));
  Check("moi lenh co it nhat 1 host", all.TrueForAll(t => t.Hosts.Length > 0));
  string[] validHosts = { "AutoCAD", "ZWCAD", "GstarCAD" };
  Check("chi dung ten host hop le", all.TrueForAll(t => t.Hosts.All(h => validHosts.Contains(h))));
  Check("alias khong trung voi id lenh khac",
   all.SelectMany(t => t.Aliases).All(a => tools.TrueForAll(x => x.Id != a)));
  Check("alias khong trung nhau",
   all.SelectMany(t => t.Aliases).Distinct().Count() == all.SelectMany(t => t.Aliases).Count());
  Check("moi nut palette co nhan, nhom va tooltip day du",
   tools.TrueForAll(t => !string.IsNullOrEmpty(t.Label) && !string.IsNullOrEmpty(t.GroupKey)
    && !string.IsNullOrEmpty(t.GroupTitle) && !string.IsNullOrEmpty(t.TipTitle)
    && !string.IsNullOrEmpty(t.TipDesc) && !string.IsNullOrEmpty(t.TipCommand)));
  Check("lenh giao dien (role ui) khong co nhom palette",
   all.Where(t => !t.IsTool).All(t => t.GroupKey == null));
  Check("moi nut palette khai bao panel Ribbon", tools.TrueForAll(t => !string.IsNullOrEmpty(t.RibbonPanel)));
  Check("moi lenh co icon", all.TrueForAll(t => !string.IsNullOrEmpty(t.Icon)));
  Check("icon khong trung nhau (moi lenh 1 hinh rieng)",
   all.Select(t => t.Icon).Distinct().Count() == all.Count);

  Console.WriteLine("== 2. Moi lenh phai that su ton tai trong ma nguon ==");
  string lispAll = ReadDir("src/lisp", "*.lsp");
  string managed = ReadDir("src/ribbon", "*.cs") + ReadDir("src/zwcad", "*.cs") + ReadDir("src/gscad", "*.cs");
  foreach (TgToolInfo t in all) {
   Check("lenh " + t.Cmd + " duoc dinh nghia (LSP defun c: hoac [CommandMethod])",
    HasCommand(lispAll, managed, t.Cmd));
   foreach (string alias in t.Aliases) {
    Check("biet danh " + alias + " cua " + t.Id + " ton tai", HasCommand(lispAll, managed, alias));
   }
  }

  CheckCatalogCoversAllProductCommands(all);
  CheckDotNetShims(all);

  Console.WriteLine("== 3. Menu keo xuong (src/menu + 2 bundle) ==");
  string menu = Read("src/menu/TGIRR_CAD.mnu");
  Check("menu co MENUGROUP=TGIRR", menu.Contains("***MENUGROUP=TGIRR"));
  Check("menu co phan HELPSTRINGS", menu.Contains("***HELPSTRINGS"));
  foreach (TgToolInfo t in all) {
   Check("menu co item " + t.MenuTag, menu.Contains("ID_TGIRR_" + t.MenuTag));
   Check("menu go dung lenh " + t.Cmd, Norm(menu).Contains("^C^C" + t.Cmd + "\n"));
   Check("menu co helpstring " + t.MenuTag, HelpDefined(menu, t.MenuTag));
  }
  Check("menu khong con item la", MenuItemsKnown(menu, all));
  Check("menu chi dung ASCII (an toan cho CAD menu)",
   menu.All(ch => ch == '\r' || ch == '\n' || (ch >= 32 && ch < 127)));
  foreach (string bundle in new[] { "TGIRR_CAD_ZWCAD", "TGIRR_CAD_GSTARCAD" }) {
   string rel = "bundle/" + bundle + ".bundle/Contents/Lisp/TGIRR_CAD.mnu";
   Check("bundle " + bundle + " co menu",
    File.Exists(Path.Combine(Root, rel.Replace('/', Path.DirectorySeparatorChar))));
   Check("bundle " + bundle + " menu khong lech src/menu", Norm(Read(rel)) == Norm(menu));
  }

  Console.WriteLine("== 3b. Toolbar native: nut va icon khop catalog ==");
  foreach (TgToolInfo t in tools) {
   Check("toolbar co nut " + t.Id,
    menu.Contains("\"" + t.MenuTag + ".bmp\"") && menu.Contains("\"" + t.MenuTag + "_L.bmp\""));
   Check("tooltip toolbar " + t.Id + " co ten lenh", menu.Contains("_Button(\"" + t.Id + " - "));
   Check("icon toolbar va bundle khop cho " + t.Id, NativeToolbarAssetsMatch(t.MenuTag));
  }

  Console.WriteLine("== 4. Bang lenh trong docs/COMMANDS.md ==");
  string docs = Read("docs/COMMANDS.md");
  int bi = docs.IndexOf("BEGIN GENERATED COMMAND TABLE");
  int ei = docs.IndexOf("END GENERATED COMMAND TABLE");
  Check("docs co cap marker bang lenh", bi >= 0 && ei > bi);
  string table = (bi >= 0 && ei > bi) ? docs.Substring(bi, ei - bi) : "";
  foreach (TgToolInfo t in all) {
   string row = DocsRow(table, t.Id);
   Check("docs co dong " + t.Id, row.Length > 0);
   Check("docs liet ke day du biet danh cua " + t.Id, row.Length > 0 && t.Aliases.All(a => row.Contains(a)));
  }
  Check("docs ke den 2 lenh giao dien", table.Contains("TGIRRPALETTE") && table.Contains("TGIRRQUICK"));

  Console.WriteLine("== 5. Ribbon AutoCAD do danh muc dieu khien ==");
  string plugin = Read("src/ribbon/Plugin.cs");
  Check("Ribbon duyet TgToolCatalog.RibbonPanels",
   plugin.Contains("TgToolCatalog.RibbonPanels") && plugin.Contains("TgToolCatalog.RibbonIconByKey"));
  Check("Ribbon dung bo icon vector dung chung",
   plugin.Contains("ToolIcons.For") && plugin.Contains("PaletteTheme.Accent(tool.Accent)"));
  Check("Palette dung bo icon vector dung chung", Read("src/shared/PaletteContent.cs").Contains("ToolIcons.For(tool.Icon"));
  Check("Palette khong con hien nhan chu tren nut", !Read("src/shared/PaletteContent.cs").Contains("Text = tool.Badge"));
  Check("Ribbon khong con hard-code chuoi tooltip", !plugin.Contains("new RibbonToolTip{Title=\""));
  foreach (TgToolInfo t in tools.Where(x => x.Supports("AutoCAD"))) {
   Check("Ribbon sinh nut cho " + t.Id, RibbonHas(t.Id));
  }
  int ribbonTotal = TgToolCatalog.RibbonPanels.Sum(p => p.Items.Count(i => i != null));
  int acadTools = tools.Count(t => t.Supports("AutoCAD"));
  int acadUiInRibbon = all.Count(t => !t.IsTool && t.Supports("AutoCAD") && RibbonHas(t.Id));
  Check("so nut Ribbon = lenh AutoCAD + nut giao dien (" + ribbonTotal + ")",
   ribbonTotal == acadTools + acadUiInRibbon);
  Check("Ribbon co nut Quick Tools (TGIRRQUICK)", RibbonHas("TGIRRQUICK"));
  Check("ten panel Ribbon khong trung lap",
   TgToolCatalog.RibbonPanels.Select(p => p.Title).Distinct().Count() == TgToolCatalog.RibbonPanels.Length);
  foreach (var panel in TgToolCatalog.RibbonPanels) {
   Check("panel Ribbon '" + panel.Title + "' co nut", panel.Items.Length > 0);
   // Lenh giao dien (role ui) khong co ribbonPanel rieng nen duoc phep null.
   Check("nut cua panel '" + panel.Title + "' khai bao dung panel",
    panel.Items.Where(i => i != null).All(i => i.RibbonPanel == panel.Title || !i.IsTool));
  }

  Console.WriteLine("== 6. Hai ban port palette dung chung metadata ==");
  string canonical = Read("src/shared/ToolCatalog.generated.cs");
  Check("ToolCatalog ban ZWCAD khong lech", Norm(Read("src/zwcad/ToolCatalog.generated.cs")) == Norm(canonical));
  Check("ToolCatalog ban GstarCAD khong lech", Norm(Read("src/gscad/ToolCatalog.generated.cs")) == Norm(canonical));
  string zwPalette = Read("src/zwcad/PaletteCommands.cs");
  string gsPalette = Read("src/gscad/PaletteCommands.cs");
  Check("port ZWCAD dung namespace ZwSoft", zwPalette.Contains("ZwSoft.ZwCAD"));
  Check("port GstarCAD dung namespace Gssoft", gsPalette.Contains("Gssoft.Gscad"));
  Check("khong con token host chua dien",
   !zwPalette.Contains("@@TGIRR_HOST@@") && !gsPalette.Contains("@@TGIRR_HOST@@"));
  Check("CadHost.Name cua ZWCAD duoc dien", zwPalette.Contains("Name = \"ZWCAD\""));
  Check("CadHost.Name cua GstarCAD duoc dien", gsPalette.Contains("Name = \"GstarCAD\""));
  Check("palette khong con warm-up hack (GC.KeepAlive)",
   !zwPalette.Contains("GC.KeepAlive") && !gsPalette.Contains("GC.KeepAlive"));
  Check("palette co co che chong ghi de resize (userAdjusted/echo)",
   zwPalette.Contains("userAdjusted") && zwPalette.Contains("echoW"));
  foreach (string hostName in new[] { "ZWCAD", "GstarCAD" }) {
   TgToolInfo[] paletteTools = TgToolCatalog.ForHost(hostName);
   Check("palette " + hostName + " co " + paletteTools.Length + " nut (>= 13)", paletteTools.Length >= 13);
   Check("moi nut " + hostName + " thuoc dung 1 nhom",
    paletteTools.All(t => !string.IsNullOrEmpty(t.GroupKey)));
   int sumGroups = TgToolCatalog.GroupKeys(hostName).Sum(k => TgToolCatalog.ForGroup(hostName, k).Length);
   Check("tong nut theo nhom bang tong nut palette (" + hostName + ")", sumGroups == paletteTools.Length);
  }

  Console.WriteLine("== 7. State stores: doc/ghi/round-trip/prune ==");
  string temp = Path.Combine(Path.GetTempPath(), "tgirr-palette-test-" + Guid.NewGuid().ToString("N"));
  PaletteStorage.RootOverride = temp;
  try {
   var pins = new List<string> { "VDNG", "HBD", "GHOSTCMD", "VDNG" };
   Check("ghi danh sach ghim duoc", PinStore.Save(pins));
   List<string> loaded = PinStore.Load();
   Check("doc ghim giu thu tu va khong trung",
    loaded.Count == 3 && loaded[0] == "VDNG" && loaded[1] == "HBD" && loaded[2] == "GHOSTCMD");
   List<string> pruned = PinStore.Pruned(loaded, id => TgToolCatalog.Find(id) != null);
   Check("prune loai lenh khong con trong catalog",
    pruned.Count == 2 && pruned[0] == "VDNG" && pruned[1] == "HBD");
   Check("Find nhan lenh that, bac lenh la",
    TgToolCatalog.Find("HBD") != null && TgToolCatalog.Find("GHOSTCMD") == null);
   Check("ghi state khong de lai file .tmp", Directory.GetFiles(temp, "*.tmp").Length == 0);

   var geo = new PaletteGeometry { Dock = 1, X = 100, Y = 200, Width = 320, Height = 520 };
   geo.Save("palette-state.txt");
   PaletteGeometry back = PaletteGeometry.Load("palette-state.txt");
   Check("geometry round-trip", back.Dock == 1 && back.X == 100 && back.Y == 200
    && back.Width == 320 && back.Height == 520 && back.HasSize);
   Check("geometry doc duoc dinh dang cu v1", LoadGeometry("legacy.txt", "v1 2 5 6 700 800").Dock == 2);
   Check("geometry rac tra ve gia tri mac dinh", LoadGeometry("junk.txt", "rong").Width == -1);
   Check("IsFloating chi dung khi Dock = 0",
    new PaletteGeometry { Dock = 0 }.IsFloating && !new PaletteGeometry { Dock = 8 }.IsFloating);
   Check("Clone tao ban doc lap", new PaletteGeometry { Width = 10 }.Clone().Width == 10);
   Check("AssignFrom copy du 5 truong", AssignOk());

   var collapsed = new HashSet<string>(StringComparer.OrdinalIgnoreCase) { "BOUNDARY", "util" };
   Check("ghi nhom thu gon duoc", GroupCollapseStore.Save(collapsed));
   HashSet<string> loadedSet = GroupCollapseStore.Load();
   Check("doc nhom thu gon khong pham hoa",
    loadedSet.Count == 2 && loadedSet.Contains("boundary") && loadedSet.Contains("UTIL"));
  } finally {
   PaletteStorage.RootOverride = null;
   try { Directory.Delete(temp, true); } catch { }
  }

  Console.WriteLine("== 8. Nguon that phai nam trong repo ==");
  Check("src/catalog/tools.json ton tai", File.Exists(Path.Combine(Root, "src", "catalog", "tools.json")));
  string packageContents = Read("bundle/TGIRR_CAD_LISP.bundle/PackageContents.xml");
  Check("AutoCAD nap truc tiep cac file LISP khi khoi dong (khong phu thuoc loader)",
   packageContents.Contains("ModuleName=\"./Contents/Lisp/SBS.lsp\" LoadOnAutoCADStartup")
   && packageContents.Contains("ModuleName=\"./Contents/Lisp/HBD.lsp\" LoadOnAutoCADStartup")
   && packageContents.Contains("ModuleName=\"./Contents/Lisp/DOITEXT.lsp\" LoadOnAutoCADStartup")
   && packageContents.Contains("ModuleName=\"./Contents/Lisp/TGIRRBAR.lsp\" LoadOnAutoCADStartup"));
  Check("AutoCAD nap file shim lenh .NET khi khoi dong",
   packageContents.Contains("ModuleName=\"./Contents/Lisp/TGIRRCOMMANDS.lsp\" LoadOnAutoCADStartup"));
  Check("shim lenh .NET tu doc cai dat (khong phu thuoc loader)",
   Read("src/lisp/TGIRRCOMMANDS.lsp").Contains("TGIRR:CMDSET-DISABLED"));
  string shimText = Read("src/lisp/TGIRRCOMMANDS.lsp");
  foreach (TgToolCatalog.TgLoadUnit unit in TgToolCatalog.LoadUnits) {
   foreach (string cmd in unit.Commands) {
    Check("shim tu go lenh LISP " + cmd + " khi bi tat",
     shimText.Contains("(setq C:" + cmd + " nil)"));
   }
  }
  string toolbarLisp = Read("src/lisp/TGIRRBAR.lsp");
  Check("TGIRRBAR tu tim bundle AutoCAD ngoai Support Path",
   toolbarLisp.Contains("getenv \"APPDATA\"") && toolbarLisp.Contains("getenv \"PROGRAMDATA\"")
   && toolbarLisp.Contains("ApplicationPlugins") && toolbarLisp.Contains("TGIRR_CAD_LISP.bundle"));
  Check("TGIRRBAR go dung ten toolbar hien thi tren AutoCAD",
   toolbarLisp.Contains("(command \"_.-TOOLBAR\" \"TGIRR CAD\" \"\" \"_Show\")")
   && !toolbarLisp.Contains("\"TB_TGIRR\" \"_Show\""));
  Check("TGIRRBAR khong bao thanh cong khi -TOOLBAR con dang mo",
   toolbarLisp.Contains("(logand 1 (getvar \"CMDACTIVE\"))"));
  foreach (string f in new[] { "PaletteCommands.cs", "PaletteContent.cs", "PaletteState.cs", "ToolCatalog.generated.cs", "ToolIcons.cs", "LoadSettingsWindow.cs" }) {
   Check("src/shared/" + f + " ton tai", File.Exists(Path.Combine(Root, "src", "shared", f)));
  }

  Console.WriteLine("== 9. Cai dat bat/tat nap LISP (TGIRRSETTINGS) ==");
  Check("catalog co lenh TGIRRSETTINGS", all.Any(t => t.Id == "TGIRRSETTINGS"));
  Check("catalog khai bao du file LISP co the tat", TgToolCatalog.LoadUnits.Length >= 4);
  string[] lispCommands = TgToolCatalog.LoadUnitCommands();
  Check("hop thoai liet ke du 9 lenh LISP", lispCommands.Length == 9);
  foreach (string cmd in new[] { "SBS", "SBSE", "SCH", "HBD", "JH", "SP2PL", "DOITEXT", "DOIMTEXT", "TGIRRBAR" }) {
   Check("hop thoai cai dat co lenh " + cmd, Array.IndexOf(lispCommands, cmd) >= 0);
   Check("lenh " + cmd + " thuoc mot file LISP", TgToolCatalog.LoadUnitFor(cmd) != null);
  }
  Check("lenh .NET khong nam trong danh sach LISP", TgToolCatalog.LoadUnitFor("TNET") == null);
  foreach (TgToolCatalog.TgLoadUnit unit in TgToolCatalog.LoadUnits) {
   Check("file " + unit.File + " co lenh", unit.Commands.Length > 0);
  }
  foreach (string f in new[] { "src/lisp/TGIRRLoader.lsp", "src/lisp/TGIRRLoaderZ.lsp", "src/lisp/TGIRRLoaderG.lsp" }) {
   string lisp = Read(f);
   Check(Path.GetFileName(f) + " doc cai dat nap", lisp.Contains("TGIRR:DISABLED-LIST") && lisp.Contains("TGIRRSETTINGS"));
   Check(Path.GetFileName(f) + " nap theo nhom lenh", lisp.Contains("LOAD-GROUP"));
   foreach (TgToolCatalog.TgLoadUnit unit in TgToolCatalog.LoadUnits) {
    Check(Path.GetFileName(f) + " nap " + unit.File, lisp.Contains("\"" + unit.File + "\""));
   }
  }
  string acadLoader = Read("src/lisp/TGIRRLoader.lsp");
  Check("TGIRRLoader tu tim bundle AutoCAD ngoai Support Path",
   acadLoader.Contains("ApplicationPlugins") && acadLoader.Contains("TGIRR_CAD_LISP.bundle")
   && acadLoader.Contains("TGIRR:DIR-EXISTS"));
  foreach (string f in new[] { "src/lisp/TGIRRLoader.lsp", "src/lisp/TGIRRLoaderZ.lsp", "src/lisp/TGIRRLoaderG.lsp" }) {
   Check(Path.GetFileName(f) + " nap file shim lenh .NET", Read(f).Contains("TGIRRCOMMANDS.lsp"));
  }
  Check("hop thoai cai dat co ca lenh .NET", Read("src/shared/LoadSettingsWindow.cs").Contains("ManagedTools"));
  Check("hop thoai cai dat luu ngay khi tick (khong can nut Luu)",
   Read("src/shared/LoadSettingsWindow.cs").Contains("OnToggled") && Read("src/shared/LoadSettingsWindow.cs").Contains("LoadSettingsStore.Save"));
  Check("loader khong dung read+setq dong (nguon gay dung nap)",
   !acadLoader.Contains("(read (strcat \"C:\""));
  Check("loader boc moi nhom lenh trong bao loi",
   acadLoader.Contains("TGIRR:SAFE") && acadLoader.Contains("vl-catch-all-apply 'eval"));
  Check("co lenh nap lai khong can khoi dong CAD", acadLoader.Contains("c:TGIRRRELOAD") && acadLoader.Contains("c:TGIRRDROP"));
  Check("co lenh chan doan TGIRRSTATUS", acadLoader.Contains("c:TGIRRSTATUS"));
  string tempDir = Path.Combine(Path.GetTempPath(), "tgirr-load-settings-" + Guid.NewGuid().ToString("N"));
  try {
   PaletteStorage.RootOverride = tempDir;
   Check("luu danh sach LISP tat", LoadSettingsStore.Save(new[] { "SBS", "DOITEXT" }));
   Check("ap dung danh sach LISP tat",
    LoadSettingsStore.IsEnabled("HBD") && !LoadSettingsStore.IsEnabled("SBS") && !LoadSettingsStore.IsEnabled("DOITEXT"));
   Check("file cai dat dung dinh dang",
    File.ReadAllText(Path.Combine(tempDir, "load-settings.txt")).Trim() == "v1 disabled=DOITEXT,SBS");
   Check("tat lenh .NET thi palette an nut",
    TgToolCatalog.ForHost("AutoCAD").Any(t => t.Id == "TL"));
   LoadSettingsStore.Save(new[] { "TL", "SBS" });
   Check("TL bi tat thi khong con trong palette",
    TgToolCatalog.ForHost("AutoCAD").All(t => t.Id != "TL"));
   Check("cac lenh khac van hien", TgToolCatalog.ForHost("AutoCAD").Any(t => t.Id == "TGN"));
  } finally {
   PaletteStorage.RootOverride = null;
   try { Directory.Delete(tempDir, true); } catch { }
  }

  Console.WriteLine();
  Console.WriteLine("Palette regression: " + passed + " tests passed, " + failed + " failed.");
  return failed == 0 ? 0 : 1;
 }

 // ----- helpers -------------------------------------------------------------

 static bool AssignOk() {
  var a = new PaletteGeometry { Dock = 3, X = 1, Y = 2, Width = 3, Height = 4 };
  var b = new PaletteGeometry();
  b.AssignFrom(a);
  return b.Dock == 3 && b.X == 1 && b.Y == 2 && b.Width == 3 && b.Height == 4;
 }

 static bool HasCommand(string lisp, string managed, string cmd) {
  if (lisp.IndexOf("(defun c:" + cmd, StringComparison.OrdinalIgnoreCase) >= 0) return true;
  return managed.Contains("CommandMethod(\"" + cmd + "\"");
 }

 static void CheckCatalogCoversAllProductCommands(List<TgToolInfo> all) {
  Console.WriteLine("== 2b. Catalog bao phu tat ca lenh nguoi dung ==");
  var catalog = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
  foreach (TgToolInfo t in all) {
   catalog.Add(t.Cmd);
   foreach (string alias in t.Aliases) catalog.Add(alias);
  }

  string lisp = Read("src/lisp/SBS.lsp") + Read("src/lisp/HBD.lsp")
   + Read("src/lisp/DOITEXT.lsp") + Read("src/lisp/TGIRRBAR.lsp");
  var commands = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
  foreach (Match m in Regex.Matches(lisp, @"(?i)\(defun\s+c:([A-Za-z0-9_]+)")) commands.Add(m.Groups[1].Value);

  string managed = ReadDir("src/ribbon", "*.cs") + ReadDir("src/shared", "*.cs");
  foreach (Match m in Regex.Matches(managed, @"(?i)CommandMethod\s*\(\s*""([A-Za-z0-9_]+)""")) commands.Add(m.Groups[1].Value);

  var hostOnly = new HashSet<string>(new[] { "TGIRR_RIBBON", "TGIRRRIBBON" }, StringComparer.OrdinalIgnoreCase);
  foreach (string cmd in commands.Where(c => !hostOnly.Contains(c)).OrderBy(c => c, StringComparer.OrdinalIgnoreCase)) {
   // Lenh .NET dang ky ten noi bo TGIRR<CMD>; catalog van dung ten quen thuoc <CMD>.
   string publicName = cmd;
   if (!catalog.Contains(publicName) && publicName.StartsWith("TGIRR", StringComparison.OrdinalIgnoreCase)
    && catalog.Contains(publicName.Substring(5)))
    publicName = publicName.Substring(5);
   Check("lenh nguoi dung " + cmd + " co trong catalog", catalog.Contains(publicName));
  }
 }

 /// <summary>Lenh .NET phai co shim c:LISP tao lai ten quen thuoc, co dieu kien bat/tat.</summary>
 static void CheckDotNetShims(List<TgToolInfo> tools) {
  Console.WriteLine("== 2c. Lenh .NET: ten noi bo + shim LISP bat/tat duoc ==");
  string shim = Read("src/lisp/TGIRRCOMMANDS.lsp");
  Check("shim co ham gui lenh TGIRR:RUN", shim.Contains("(defun TGIRR:RUN"));
  foreach (TgToolInfo t in tools.Where(x => x.Managed)) {
   string guard = "(if (TGIRR:LOAD-ENABLED-P \"" + t.Id + "\") (defun c:" + t.Cmd;
   Check("shim cho " + t.Cmd + " co dieu kien bat/tat", shim.Contains(guard));
   Check("shim " + t.Cmd + " goi lenh noi bo " + TgToolCatalog.ManagedCommand(t.Id),
    shim.Contains("(TGIRR:RUN \"" + TgToolCatalog.ManagedCommand(t.Id) + "\")"));
  }
  Check("khong con lenh .NET trung ten LISP ngoai",
   tools.Where(x => x.Managed).All(x => shim.Contains("c:" + x.Cmd)));
  Check("shim liet ke toan bo lenh de canh bao tat sach",
   shim.Contains("*TGIRR:ALL-COMMANDS*") && tools.Where(t => t.IsTool).All(t => shim.Contains("\"" + t.Cmd + "\"")));
  foreach (string f in new[] { "src/lisp/TGIRRLoader.lsp", "src/lisp/TGIRRLoaderZ.lsp", "src/lisp/TGIRRLoaderG.lsp" }) {
   string lisp = Read(f);
   Check(Path.GetFileName(f) + " canh bao khi tat het lenh",
    lisp.Contains("TGIRR:WARN-IF-ALL-OFF") && lisp.Contains("TAT CA lenh dang bi tat"));
  }
 }

 static bool NativeToolbarAssetsMatch(string tag) {
  string[] bundles = { "TGIRR_CAD_LISP", "TGIRR_CAD_ZWCAD", "TGIRR_CAD_GSTARCAD" };
  foreach (string name in new[] { tag + ".bmp", tag + "_L.bmp" }) {
   string source = Path.Combine(Root, "src", "menu", "icons", name);
   if (!File.Exists(source)) return false;
   byte[] expected = File.ReadAllBytes(source);
   foreach (string bundle in bundles) {
    string actual = Path.Combine(Root, "bundle", bundle + ".bundle", "Contents", "Lisp", name);
    if (!File.Exists(actual) || !expected.SequenceEqual(File.ReadAllBytes(actual))) return false;
   }
  }
  return true;
 }

 static bool HelpDefined(string menu, string tag) {
  int i = menu.IndexOf("***HELPSTRINGS", StringComparison.Ordinal);
  return i >= 0 && menu.Substring(i).Contains("ID_TGIRR_" + tag);
 }

 static bool MenuItemsKnown(string menu, List<TgToolInfo> all) {
  foreach (string raw in menu.Split('\n')) {
   string line = raw.Trim();
   if (!line.StartsWith("ID_TGIRR_")) continue;
   string token = line.Split(new[] { ' ', '[' }, StringSplitOptions.RemoveEmptyEntries)[0];
   string tag = token.Substring("ID_TGIRR_".Length);
   if (tag == "CAD") continue;
   if (!all.Exists(t => t.MenuTag == tag)) return false;
  }
  return true;
 }

 static bool RibbonHas(string id) {
  foreach (var panel in TgToolCatalog.RibbonPanels) {
   foreach (TgToolInfo t in panel.Items) if (t != null && t.Id == id) return true;
  }
  return false;
 }

 static string DocsRow(string table, string id) {
  foreach (string line in table.Split('\n')) {
   if (line.Contains("| " + id + " |")) return line;
  }
  return "";
 }

 static PaletteGeometry LoadGeometry(string name, string content) {
  Directory.CreateDirectory(PaletteStorage.Root);
  File.WriteAllText(Path.Combine(PaletteStorage.Root, name), content, new UTF8Encoding(false));
  return PaletteGeometry.Load(name);
 }

 static string ReadDir(string rel, string pattern) {
  string dir = Path.Combine(Root, rel.Replace('/', Path.DirectorySeparatorChar));
  if (!Directory.Exists(dir)) return "";
  var sb = new StringBuilder();
  foreach (string f in Directory.GetFiles(dir, pattern)) {
   try { sb.Append(File.ReadAllText(f, Encoding.UTF8)); } catch { }
  }
  return sb.ToString();
 }

 static string FindRoot() {
  var dir = new DirectoryInfo(AppContext.BaseDirectory);
  while (dir != null) {
   if (File.Exists(Path.Combine(dir.FullName, "src", "catalog", "tools.json"))) return dir.FullName;
   dir = dir.Parent;
  }
  return null;
 }
}
