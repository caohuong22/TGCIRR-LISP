using System;
using System.Collections.Generic;
using System.Windows.Threading;
using Gssoft.Gscad.Windows;

namespace Tgirrr.CadLisp {
 /// <summary>
 /// Host dang chay. Chuoi "GstarCAD" duoc scripts\port-config.ps1 thay bang
 /// "ZWCAD" / "GstarCAD" khi sinh src\zwcad va src\gscad tu file nay.
 /// KHONG sua tay hai ban da port - chung la dau ra cua file nguon nay.
 /// </summary>
 internal static class CadHost {
  internal const string Name = "GstarCAD";

  /// <summary>Lenh nap lai toan bo Lisp + plugin .NET cua TGIRR.</summary>
  internal const string ReloadCommand = "TGIRRLOAD";
 }

 /// <summary>
 /// Gui lenh xuong command line cua CAD tu palette.
 /// keepSelection = true giu pickset dang co (lenh kieu "chon truoc roi bam nut");
 /// false thi gui 2 lan Esc de huy pickset dang ro truoc khi chay lenh.
 /// </summary>
 internal static class ToolRunner {
  internal static bool Run(string cmd, bool keepSelection) {
   try {
    var doc = Gssoft.Gscad.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;
    if (doc == null) return false;
    doc.SendStringToExecute((keepSelection ? "" : "\x1b\x1b") + cmd + " ", true, false, false);
    return true;
   } catch { return false; }
  }

  /// <summary>In dong bao ra command line thay vi im lang khi loi (F8).</summary>
  internal static void Notify(string message) {
   try {
    var ed = Gssoft.Gscad.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument?.Editor;
    if (ed != null) ed.WriteMessage("\n[TGIRR] " + message + "\n");
   } catch { }
  }
 }

 /// <summary>
 /// Danh sach lenh da ghim ★ - mot nguon that cho palette chinh va palette Quick Tools.
 /// Moi thay doi deu bao cho ca hai view nen ★ khong the lech nhau (F3).
 /// Lenh bi doi ten/xa se bi prune ngay luc doc (F8).
 /// </summary>
 internal static class PinService {
  static readonly List<string> Pins = LoadPins();

  internal static event Action Changed = delegate { };

  static Func<string, bool> Known {
   get { return delegate(string id) { return TgToolCatalog.Find(id) != null; }; }
  }

  static List<string> LoadPins() {
   try {
    List<string> pins = PinStore.Load();
    List<string> pruned = PinStore.Pruned(pins, Known);
    if (pruned.Count != pins.Count) {
     PinStore.Save(pruned);
     return pruned;
    }
    return pins;
   } catch (Exception ex) {
    ToolRunner.Notify("Loi doc danh sach lenh da ghim: " + ex.Message);
    return new List<string>();
   }
  }

  internal static int Count { get { lock (Pins) return Pins.Count; } }

  internal static bool Contains(string id) { lock (Pins) return Pins.Contains(id); }

  /// <summary>Lenh da ghim, con ton tai va duoc host dang chay ho tro, theo thu tu ghim.</summary>
  internal static List<TgToolInfo> PinnedTools() {
   var list = new List<TgToolInfo>();
   lock (Pins) {
    foreach (string id in Pins) {
     TgToolInfo t = TgToolCatalog.Find(id);
     if (t != null && t.Supports(CadHost.Name)) list.Add(t);
    }
   }
   return list;
  }

  internal static bool Toggle(string id) {
   bool now;
   lock (Pins) {
    if (Pins.Contains(id)) { Pins.Remove(id); now = false; }
    else { Pins.Add(id); now = true; }
    PinStore.Save(Pins);
   }
   Changed();
   return now;
  }
 }

 /// <summary>
 /// Luu va phuc hoi dock / vi tri / kich thuoc cua mot PaletteSet
 /// (%APPDATA%\TGIRR\(ten file)) vi host CAD khong tu nho giua cac phien.
 /// Keeper phan biet "echo" do chinh SetSizeClamped sinh ra voi thao tac keo tha cua
 /// nguoi dung, nen resize luc mo palette khong con bi gia tri cu ghi de (F5).
 /// </summary>
 internal sealed class PaletteGeometryKeeper {
  const int MaxSize = 4000;

  readonly PaletteSet ps;
  readonly string fileName;
  readonly int defW, defH, minW, minH;
  readonly Dispatcher ui;

  PaletteGeometry saved;
  readonly bool hadSaved;
  bool attached, userAdjusted;
  int echoW, echoH;
  DispatcherTimer settle, debounce;

  internal PaletteGeometryKeeper(PaletteSet paletteSet, string file,
   int defaultW, int defaultHeight, int minimumW, int minimumH) {
   ps = paletteSet;
   fileName = file;
   defW = defaultW; defH = defaultHeight; minW = minimumW; minH = minimumH;
   ui = Dispatcher.CurrentDispatcher;
   saved = PaletteGeometry.Load(file);
   hadSaved = saved.HasSize;
   if (!hadSaved) { saved.Width = defW; saved.Height = defH; }
   ClampSaved();
  }

  /// <summary>Goi TRUOC khi hien palette: dat neo + kich thuoc va gan event.</summary>
  internal void ApplyAndAttach() {
   bool docked = false;
   if (hadSaved && !saved.IsFloating) {
    try { ps.Dock = (DockSides)saved.Dock; docked = true; } catch { }
   }
   if (!docked) { try { ps.Dock = DockSides.None; } catch { } }
   SetSizeClamped(saved.Width, saved.Height);
   if (hadSaved && saved.IsFloating && IsOnScreen(saved.X, saved.Y)) {
    try { ps.Location = new System.Drawing.Point(saved.X, saved.Y); } catch { }
   }
   if (attached) return;
   attached = true;
   ps.SizeChanged += (s, e) => OnSizeChanged(e.Width, e.Height);
   ps.PaletteSetMoved += (s, e) => QueuePersist();
   ps.Saving += (s, e) => QueuePersist();
   ps.StateChanged += (s, e) => {
    if (e.NewState == StateEventIndex.Hide) QueuePersist();
   };
  }

  /// <summary>
  /// Goi SAU khi hien palette: host hay bo qua kich thuoc dat luc chua hien nen can ap lai.
  /// Settle giu gia tri da luu vai tick, nhung dung ngay khi phat hien user keo tha.
  /// </summary>
  internal void PostShow() {
   ui.BeginInvoke(new Action(delegate { ReapplySaved(); QueuePersist(); }), DispatcherPriority.Loaded);
   if (settle != null) { try { settle.Stop(); } catch { } }
   settle = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(300) };
   int ticks = 0;
   settle.Tick += delegate {
    ticks++;
    try {
     if (!IsVisible()) { settle.Stop(); return; }
     if (!userAdjusted && !MatchesSaved()) ReapplySaved();
    } catch { }
    if (ticks >= 6) { settle.Stop(); PersistNow(); }
   };
   settle.Start();
  }

  /// <summary>Ghi ngay lap tuc (dung truoc khi an/dong palette).</summary>
  internal void PersistNow() {
   try { if (debounce != null) debounce.Stop(); } catch { }
   WriteState();
  }

  void OnSizeChanged(int width, int height) {
   if (width <= 0 || height <= 0) { QueuePersist(); return; }
   if (width == echoW && height == echoH) return; // echo cua SetSizeClamped
   userAdjusted = true;
   QueuePersist();
  }

  void QueuePersist() {
   if (debounce == null) {
    debounce = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(350) };
    debounce.Tick += delegate { try { debounce.Stop(); } catch { } WriteState(); };
   }
   debounce.Stop();
   debounce.Start();
  }

  void ReapplySaved() {
   if (!IsVisible()) return;
   SetSizeClamped(saved.Width, saved.Height);
   if (saved.IsFloating && IsOnScreen(saved.X, saved.Y)) {
    try { ps.Location = new System.Drawing.Point(saved.X, saved.Y); } catch { }
   }
  }

  bool IsVisible() { try { return ps.Visible; } catch { return false; } }

  bool MatchesSaved() {
   try {
    System.Drawing.Size sz = ps.Size;
    return sz.Width == saved.Width && sz.Height == saved.Height;
   } catch { return true; }
  }

  void SetSizeClamped(int w, int h) {
   int cw, ch;
   ClampSize(w, h, out cw, out ch);
   echoW = cw; echoH = ch;
   try { ps.Size = new System.Drawing.Size(cw, ch); } catch { }
  }

  /// <summary>Doc trang thai hien tai cua palette va ghi file khi co thay doi that.</summary>
  void WriteState() {
   try {
    var next = new PaletteGeometry();
    try { next.Dock = (int)ps.Dock; } catch { next.Dock = saved.Dock; }
    try { next.X = ps.Location.X; next.Y = ps.Location.Y; } catch { next.X = saved.X; next.Y = saved.Y; }
    try {
     System.Drawing.Size sz = ps.Size;
     next.Width = sz.Width; next.Height = sz.Height;
    } catch { next.Width = saved.Width; next.Height = saved.Height; }
    if (next.Width <= 0 || next.Height <= 0) return;
    int cw, ch;
    ClampSize(next.Width, next.Height, out cw, out ch);
    next.Width = cw; next.Height = ch;
    if (SameAs(next, saved)) return;
    saved.AssignFrom(next);
    saved.Save(fileName);
   } catch (Exception ex) {
    ToolRunner.Notify("Loi luu trang thai palette (" + fileName + "): " + ex.Message);
   }
  }

  static bool SameAs(PaletteGeometry a, PaletteGeometry b) {
   return a.Dock == b.Dock && a.X == b.X && a.Y == b.Y && a.Width == b.Width && a.Height == b.Height;
  }

  void ClampSaved() {
   int w, h;
   ClampSize(saved.Width, saved.Height, out w, out h);
   saved.Width = w; saved.Height = h;
  }

  void ClampSize(int w, int h, out int ow, out int oh) {
   ow = w <= 0 ? defW : w;
   oh = h <= 0 ? defH : h;
   if (ow < minW) ow = minW;
   if (oh < minH) oh = minH;
   if (ow > MaxSize) ow = MaxSize;
   if (oh > MaxSize) oh = MaxSize;
  }

  /// <summary>Chong phuc hoi cua so nam ngoai man hinh ao (rut man hinh phu).</summary>
  static bool IsOnScreen(int x, int y) {
   double l = System.Windows.SystemParameters.VirtualScreenLeft;
   double t = System.Windows.SystemParameters.VirtualScreenTop;
   double w = System.Windows.SystemParameters.VirtualScreenWidth;
   double h = System.Windows.SystemParameters.VirtualScreenHeight;
   return x + 60 > l && x < l + w && y + 20 > t && y < t + h;
  }
 }

 /// <summary>
 /// Lenh TGIRRQUICK + palette Quick Tools RIENG (PaletteSet dockable doc lap),
 /// chua cac nut da ghim ★: tu mo khi co nut ghim, tu an khi bo ghim het.
 /// Geometry nho rieng %APPDATA%\TGIRR\quick-palette-state.txt.
 /// </summary>
 public sealed class QuickPalette {
  static PaletteSet _qp;
  static PaletteGeometryKeeper _keeper;
  static readonly Guid QuickId = new Guid("9B2F6C31-4E7A-4D5F-8A1C-3F7E2B9D5C46");

  static QuickPalette() {
   // Ghi/bo ghi tu dau nao (palette chinh hay Quick Tools) cung chay qua day.
   PinService.Changed += OnPinsChanged;
  }

  [Gssoft.Gscad.Runtime.CommandMethod("TGIRRQUICK")]
  public void Toggle() {
   try {
    if (PinService.Count == 0) {
     ToolRunner.Notify("Quick Tools dang trong - mo palette TGIRR CAD roi bam ★ o nut cong cu de ghim vao day.");
     return;
    }
    if (_qp == null) { Create(); return; }
    if (_qp.Visible) _keeper.PersistNow();
    _qp.Visible = !_qp.Visible;
   } catch (Exception ex) {
    ToolRunner.Notify("Loi bat/tat Quick Tools: " + ex.Message);
   }
  }

  /// <summary>Goi khi palette chinh mo: da co nut ghim thi mo Quick Tools theo.</summary>
  internal static void EnsureSynced() {
   try {
    if (PinService.Count > 0 && _qp == null) Create();
   } catch (Exception ex) {
    ToolRunner.Notify("Loi dong bo Quick Tools: " + ex.Message);
   }
  }

  static void Create() {
   _qp = new PaletteSet("TGIRR QUICK TOOLS", QuickId);
   _qp.Style = PaletteSetStyles.ShowAutoHideButton |
               PaletteSetStyles.ShowCloseButton |
               PaletteSetStyles.ShowPropertiesMenu |
               PaletteSetStyles.Snappable;
   _qp.DockEnabled = DockSides.Left | DockSides.Right | DockSides.Top | DockSides.Bottom;
   _qp.MinimumSize = new System.Drawing.Size(150, 64);
   _keeper = new PaletteGeometryKeeper(_qp, "quick-palette-state.txt", 300, 130, 150, 64);
   _keeper.ApplyAndAttach();
   _qp.AddVisual("Quick Tools", new QuickToolsContent());
   _qp.Visible = true;
   _keeper.PostShow();
  }

  static void OnPinsChanged() {
   try {
    if (PinService.Count == 0) {
     if (_qp != null) _qp.Visible = false;
     return;
    }
    if (_qp == null) Create();
    else _qp.Visible = true;
   } catch (Exception ex) {
    ToolRunner.Notify("Loi cap nhat Quick Tools: " + ex.Message);
   }
  }
 }

 /// <summary>
 /// Lenh TGIRRPALETTE: bat/tat bang cong cu TGIRR CAD (palette chinh).
 /// </summary>
 public sealed class PaletteCommands {
  static PaletteSet _ps;
  static PaletteGeometryKeeper _keeper;
  static readonly Guid PaletteId = new Guid("4A5F71BD-560C-4A2D-A537-88D83B106F79");

  [Gssoft.Gscad.Runtime.CommandMethod("TGIRRPALETTE")]
  public void Show() {
   try {
    if (_ps == null) {
     _ps = new PaletteSet("TGIRR CAD", PaletteId);
     _ps.Style = PaletteSetStyles.ShowAutoHideButton |
                 PaletteSetStyles.ShowCloseButton |
                 PaletteSetStyles.ShowPropertiesMenu |
                 PaletteSetStyles.Snappable;
     _ps.DockEnabled = DockSides.Left | DockSides.Right | DockSides.Top | DockSides.Bottom;
     _ps.MinimumSize = new System.Drawing.Size(260, 300);
     _keeper = new PaletteGeometryKeeper(_ps, "palette-state.txt", 320, 520, 260, 300);
     _keeper.ApplyAndAttach();
     _ps.AddVisual("TGIRR CAD", new PaletteContent());
     _ps.Visible = true;
     _keeper.PostShow();
     // Quick Tools (palette doc lap): tu mo neu phien truoc da co nut ghim.
     QuickPalette.EnsureSynced();
    } else {
     if (_ps.Visible) _keeper.PersistNow();
     _ps.Visible = !_ps.Visible;
    }
    if (_ps.Visible) { try { _ps.Activate(0); } catch { } }
   } catch (Exception ex) {
    ToolRunner.Notify("Loi bat palette TGIRR CAD: " + ex.Message);
   }
  }
 }
}
