using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
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
  Check("Ribbon khong con hard-code chuoi tooltip", !plugin.Contains("new RibbonToolTip{Title=\""));
  foreach (TgToolInfo t in tools.Where(x => x.Supports("AutoCAD"))) {
   Check("Ribbon sinh nut cho " + t.Id, RibbonHas(t.Id));
  }
  int ribbonTotal = TgToolCatalog.RibbonPanels.Sum(p => p.Items.Count(i => i != null));
  int acadTools = tools.Count(t => t.Supports("AutoCAD"));
  Check("so nut Ribbon = so lenh ho tro AutoCAD (" + ribbonTotal + ")", ribbonTotal == acadTools);
  Check("ten panel Ribbon khong trung lap",
   TgToolCatalog.RibbonPanels.Select(p => p.Title).Distinct().Count() == TgToolCatalog.RibbonPanels.Length);
  foreach (var panel in TgToolCatalog.RibbonPanels) {
   Check("panel Ribbon '" + panel.Title + "' co nut", panel.Items.Length > 0);
   Check("nut cua panel '" + panel.Title + "' khai bao dung panel",
    panel.Items.Where(i => i != null).All(i => i.RibbonPanel == panel.Title));
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
  foreach (string f in new[] { "PaletteCommands.cs", "PaletteContent.cs", "PaletteState.cs", "ToolCatalog.generated.cs" }) {
   Check("src/shared/" + f + " ton tai", File.Exists(Path.Combine(Root, "src", "shared", f)));
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
