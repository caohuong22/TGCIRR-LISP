using System;
using System.Collections.Generic;
using System.IO;
using System.Text;

namespace Tgirrr.CadLisp {
 /// <summary>
 /// Toan bo trang thai giao dien TGIRR nam trong %APPDATA%\TGIRR\:
 ///   palette-state.txt        geometry palette chinh  ("v1 dock x y w h")
 ///   quick-palette-state.txt  geometry palette Quick   ("v1 dock x y w h")
 ///   quick-tools.txt          danh sach lenh da ghim   ("v1 CMD|CMD")
 ///   palette-layout.txt       nhom dang thu gon       ("v1 collapsed=KEY,KEY")
 /// File duoc ghi atomic (temp + replace) nen khong bao gio roi trang thai doi.
 /// Chi dung System.* -> dung chung cho moi host va test duoc khong can CAD.
 /// </summary>
 internal static class PaletteStorage {
  /// <summary>
  /// Overide thu muc state (chi dung trong test de khong cham vao %APPDATA%\TGIRR that).
  /// </summary>
  internal static string RootOverride = null;

  internal static string Root {
   get {
    if (!string.IsNullOrEmpty(RootOverride)) return RootOverride;
    return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "TGIRR");
   }
  }

  internal static string FilePath(string name) { return Path.Combine(Root, name); }

  internal static string ReadText(string name) {
   try {
    string p = FilePath(name);
    return File.Exists(p) ? File.ReadAllText(p) : null;
   } catch { return null; }
  }

  /// <summary>Ghi atomic. Tra ve false khi loi (thieu quyen, dia day) - caller khong nen im lang.</summary>
  internal static bool TryWriteText(string name, string content) {
   string temp = null;
   try {
    Directory.CreateDirectory(Root);
    string final = FilePath(name);
    temp = final + ".tmp";
    File.WriteAllText(temp, content, new UTF8Encoding(false));
    if (File.Exists(final)) File.Replace(temp, final, null, true);
    else File.Move(temp, final);
    return true;
   } catch {
    try { if (temp != null && File.Exists(temp)) File.Delete(temp); } catch { }
    return false;
   }
  }
 }

 /// <summary>Vi tri / kich thuoc / trang thai neo da luu cua mot palette.</summary>
 internal sealed class PaletteGeometry {
  internal int Dock;
  internal int X = -1;
  internal int Y = -1;
  internal int Width = -1;
  internal int Height = -1;

  internal bool HasSize { get { return Width > 0 && Height > 0; } }
  internal bool IsFloating { get { return Dock == 0; } }

  /// <summary>Doc "v1 dock x y w h"; file khong ton tai hoesc sai dinh dang -> gia tri mac dinh.</summary>
  internal static PaletteGeometry Load(string fileName) {
   var g = new PaletteGeometry();
   string raw = PaletteStorage.ReadText(fileName);
   if (raw == null) return g;
   try {
    string[] parts = raw.Trim().Split(' ');
    if (parts.Length < 6 || parts[0] != "v1") return g;
    g.Dock = int.Parse(parts[1]);
    g.X = int.Parse(parts[2]);
    g.Y = int.Parse(parts[3]);
    g.Width = int.Parse(parts[4]);
    g.Height = int.Parse(parts[5]);
   } catch { }
   return g;
  }

  internal void Save(string fileName) {
   PaletteStorage.TryWriteText(fileName,
    "v1 " + Dock + " " + X + " " + Y + " " + Width + " " + Height);
  }

  internal PaletteGeometry Clone() {
   var g = new PaletteGeometry();
   g.Dock = Dock; g.X = X; g.Y = Y; g.Width = Width; g.Height = Height;
   return g;
  }

  internal void AssignFrom(PaletteGeometry other) {
   Dock = other.Dock; X = other.X; Y = other.Y; Width = other.Width; Height = other.Height;
  }
 }

 /// <summary>Cac lenh da ghim len palette Quick Tools (thu tu = thu tu ghim).</summary>
 internal static class PinStore {
  internal const string FileName = "quick-tools.txt";

  internal static List<string> Load() {
   var list = new List<string>();
   string raw = PaletteStorage.ReadText(FileName);
   if (raw == null) return list;
   try {
    if (!raw.StartsWith("v1 ")) return list;
    foreach (string s in raw.Substring(3).Split('|')) {
     string t = s.Trim();
     if (t.Length > 0 && !list.Contains(t)) list.Add(t);
    }
   } catch { }
   return list;
  }

  /// <summary>Loai bo lenh khong con trong catalog (rung khi command bi doi/xa), khong doi thu tu.</summary>
  internal static List<string> Pruned(List<string> pins, Func<string, bool> stillExists) {
   var list = new List<string>();
   if (pins == null) return list;
   foreach (string cmd in pins) {
    if (cmd == null || cmd.Length == 0) continue;
    if (!list.Contains(cmd) && stillExists(cmd)) list.Add(cmd);
   }
   return list;
  }

  internal static bool Save(IEnumerable<string> pins) {
   var list = new List<string>(pins);
   return PaletteStorage.TryWriteText(FileName, "v1 " + string.Join("|", list.ToArray()));
  }
 }

 /// <summary>
 /// Bat/tat nap tung goi LISP (tranh xung dot voi LISP khac).
 /// File %APPDATA%\TGIRR\load-settings.txt dinh dang "v1 disabled=ID,ID";
 /// TGIRRLoader*.lsp doc truc tiep file nay nen khong can .NET.
 /// </summary>
 internal static class LoadSettingsStore {
  internal const string FileName = "load-settings.txt";

  static HashSet<string> disabled;

  internal static bool IsEnabled(string id) {
   lock (typeof(LoadSettingsStore)) {
    if (disabled == null) disabled = Load();
    return !disabled.Contains(id ?? "");
   }
  }

  static HashSet<string> Load() {
   var set = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
   string raw = PaletteStorage.ReadText(FileName);
   if (raw == null) return set;
   try {
    string text = raw.Trim();
    if (!text.StartsWith("v1", StringComparison.OrdinalIgnoreCase)) return set;
    int pos = text.IndexOf("disabled=", StringComparison.OrdinalIgnoreCase);
    if (pos < 0) return set;
    foreach (string id in text.Substring(pos + 9).Split(',')) {
     string v = id.Trim();
     if (v.Length > 0) set.Add(v);
    }
   } catch { }
   return set;
  }

  internal static bool Save(ICollection<string> ids) {
   var list = new List<string>(ids);
   list.Sort(StringComparer.OrdinalIgnoreCase);
   lock (typeof(LoadSettingsStore)) {
    if (!PaletteStorage.TryWriteText(FileName, "v1 disabled=" + string.Join(",", list.ToArray()))) return false;
    disabled = new HashSet<string>(list, StringComparer.OrdinalIgnoreCase);
    return true;
   }
  }
 }

 /// <summary>Trang thai thu gon cua cac nhom tren palette chinh.</summary>
 internal static class GroupCollapseStore {
  internal const string FileName = "palette-layout.txt";
  static readonly string[] Prefixes = { "collapsed=" };

  internal static HashSet<string> Load() {
   var set = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
   string raw = PaletteStorage.ReadText(FileName);
   if (raw == null) return set;
   try {
    string[] tokens = raw.Trim().Split(new[] { ' ', '\r', '\n', '\t' }, StringSplitOptions.RemoveEmptyEntries);
    foreach (string token in tokens) {
     if (!token.StartsWith(Prefixes[0], StringComparison.OrdinalIgnoreCase)) continue;
     foreach (string key in token.Substring(Prefixes[0].Length).Split(',')) {
      string k = key.Trim();
      if (k.Length > 0) set.Add(k);
     }
    }
   } catch { }
   return set;
  }

  internal static bool Save(ICollection<string> collapsed) {
   var keys = new List<string>(collapsed);
   return PaletteStorage.TryWriteText(FileName, "v1 collapsed=" + string.Join(",", keys.ToArray()));
  }
 }
}
