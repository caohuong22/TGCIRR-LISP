using System;
using System.Collections.Generic;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Shapes;
using ZwSoft.ZwCAD.Runtime;
using ZwSoft.ZwCAD.Windows;

namespace Tgirrr.CadLisp {
 /// <summary>
 /// Lenh TGIRRPALETTE: bat/tat Palette cong cu TGIRR CAD.
 /// </summary>
 public sealed class PaletteCommands {
  static PaletteSet _ps;
  static PaletteGeometryKeeper _keeper;
  static readonly Guid PaletteId = new Guid("4A5F71BD-560C-4A2D-A537-88D83B106F79");

  [CommandMethod("TGIRRPALETTE")]
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
     // Tu luu/phuc hoi vi tri, kich thuoc, trang thai neo: %APPDATA%\TGIRR\palette-state.txt
     _keeper = new PaletteGeometryKeeper(_ps, "palette-state.txt", 290, 460, 260, 300);
     _keeper.ApplyAndAttach();
     _ps.AddVisual("TGIRR CAD", new PaletteContent());
     _ps.Visible = true;
     _keeper.PostShow();
     // Palette Quick Tools RIENG (dockable doc lap): tu mo neu da co nut ghim tu phien truoc
     QuickPalette.EnsureSynced();
    } else {
     if (_ps.Visible && _keeper != null) _keeper.PersistNow();
     _ps.Visible = !_ps.Visible;
    }
    if (_ps.Visible) {
     try { _ps.Activate(0); } catch { }
    }
   } catch (System.Exception ex) {
    var ed = ZwSoft.ZwCAD.ApplicationServices.Application.DocumentManager.MdiActiveDocument?.Editor;
    ed?.WriteMessage("\n[TGIRR] Loi bat Palette TGIRR CAD: " + ex.Message + "\n");
   }
  }

 }

 /// <summary>
 /// Lenh TGIRRQUICK + quan ly palette Quick Tools RIENG: mot PaletteSet dockable doc lap
 /// chua cac nut duoc ghim (★ tu Palette TGIRR CAD). Tu mo khi co nut ghim, tu an khi bo ghim het.
 /// Vi tri/kich thuoc/trang thai neo nho rieng qua %APPDATA%\TGIRR\quick-palette-state.txt.
 /// </summary>
 public sealed class QuickPalette {
  static PaletteSet _qp;
  static PaletteGeometryKeeper _keeper;
  static QuickToolsContent _content;
  static readonly Guid QuickId = new Guid("9B2F6C31-4E7A-4D5F-8A1C-3F7E2B9D5C46");

  [CommandMethod("TGIRRQUICK")]
  public void Toggle() {
   try {
    if (PaletteContent.PinnedCount == 0) {
     var ed = ZwSoft.ZwCAD.ApplicationServices.Application.DocumentManager.MdiActiveDocument?.Editor;
     ed?.WriteMessage("\n[TGIRR] Quick Tools dang trong — mo Palette TGIRR CAD, bam ☆ o nut cong cu de ghim vao Quick Tools.\n");
     return;
    }
    if (_qp == null) { Create(); return; }
    if (_qp.Visible && _keeper != null) _keeper.PersistNow();
    _qp.Visible = !_qp.Visible;
   } catch (System.Exception ex) {
    var ed = ZwSoft.ZwCAD.ApplicationServices.Application.DocumentManager.MdiActiveDocument?.Editor;
    ed?.WriteMessage("\n[TGIRR] Loi bat/tat Quick Tools: " + ex.Message + "\n");
   }
  }

  /// <summary>Goi khi palette chinh mo (dau phien CAD): co nut ghim thi tao + hien Quick Tools.</summary>
  internal static void EnsureSynced() {
   try {
    if (PaletteContent.PinnedCount > 0 && _qp == null) Create();
    else if (_content != null) _content.Refresh();
   } catch { }
  }

  /// <summary>Goi khi danh sach ghim thay doi: cap nhat noi dung, hien khi co ghim, an khi bo het.</summary>
  internal static void OnPinsChanged() {
   try {
    if (_content != null) _content.Refresh();
    if (PaletteContent.PinnedCount == 0) {
     if (_qp != null) { try { _qp.Visible = false; } catch { } }
     return;
    }
    if (_qp == null) Create();
    else { try { _qp.Visible = true; } catch { } }
   } catch { }
  }

  static void Create() {
   // Chac chan Catalog da duoc xay (nguoi dung co the go TGIRRQUICK truoc khi mo palette chinh)
   if (!PaletteContent.HasCatalog) { var warm = new PaletteContent(); GC.KeepAlive(warm); }
   _qp = new PaletteSet("TGIRR QUICK TOOLS", QuickId);
   _qp.Style = PaletteSetStyles.ShowAutoHideButton |
               PaletteSetStyles.ShowCloseButton |
               PaletteSetStyles.ShowPropertiesMenu |
               PaletteSetStyles.Snappable;
   _qp.DockEnabled = DockSides.Left | DockSides.Right | DockSides.Top | DockSides.Bottom;
   _qp.MinimumSize = new System.Drawing.Size(150, 64);
   _keeper = new PaletteGeometryKeeper(_qp, "quick-palette-state.txt", 300, 130, 150, 64);
   _keeper.ApplyAndAttach();
   _content = new QuickToolsContent();
   _qp.AddVisual("Quick Tools", _content);
   _qp.Visible = true;
   _keeper.PostShow();
  }
 }

 /// <summary>
 /// Tu luu + phuc hoi dock/vi tri/kich thuoc cua mot PaletteSet qua %APPDATA%\TGIRR\(ten file)
 /// (host CAD khong tu nho giua cac phien). Chong ca cac truong hop host "quen": bo qua Size
 /// dat truoc khi hien, reset kich thuoc luc layout, khong ban event SizeChanged khi keo tha.
 /// </summary>
 sealed class PaletteGeometryKeeper {
  readonly PaletteSet ps;
  readonly string fileName;
  readonly int defW, defH, minW, minH;
  int[] savedGeom;
  System.Windows.Threading.DispatcherTimer pollTimer;
  int lastDock = int.MinValue, lastX = int.MinValue, lastY = int.MinValue, lastW = int.MinValue, lastH = int.MinValue;

  internal PaletteGeometryKeeper(PaletteSet ps, string fileName, int defW, int defH, int minW, int minH) {
   this.ps = ps; this.fileName = fileName;
   this.defW = defW; this.defH = defH; this.minW = minW; this.minH = minH;
  }

  /// <summary>Phuc hoi dock/vi tri/kich thuoc da luu (Dock truoc, Size/Location sau) va gan event — goi TRUOC khi Visible=true.</summary>
  internal void ApplyAndAttach() {
   int dock = 0, x = -1, y = -1, w = defW, h = defH;
   bool have = PaletteStateStore.TryLoad(fileName, ref dock, ref x, ref y, ref w, ref h);
   w = Math.Max(minW, Math.Min(w, 4000));
   h = Math.Max(minH, Math.Min(h, 4000));
   savedGeom = new[] { have ? dock : 0, x, y, w, h };
   bool docked = false;
   if (have && dock != 0) {
    try { ps.Dock = (DockSides)dock; docked = true; } catch { }
   }
   if (!docked) { try { ps.Dock = DockSides.None; } catch { } }
   SetSizeClamped(w, h);
   // Chi dat vi tri khi noi (dock thi host tu xep) va con nam tren man hinh ao (tranh man hinh phu bi rut).
   if (!docked && have && x >= 0 && y >= 0 && IsOnVirtualScreen(x, y)) {
    try { ps.Location = new System.Drawing.Point(x, y); } catch { }
   }
   ps.SizeChanged += (s, e) => Persist(e.Width, e.Height);
   ps.PaletteSetMoved += (s, e) => Persist(null, null);
   ps.Saving += (s, e) => Persist(null, null);
   ps.StateChanged += (s, e) => { if (e.NewState == StateEventIndex.Hide) Persist(null, null); };
  }

  /// <summary>Goi SAU khi Visible=true: ap lai geometry (host hay bo qua gia tri dat truoc khi hien),
  /// giu dung gia tri da luu ~2.25s dau (host co the reset nhieu lan luc layout), roi dua polling bat thay doi.</summary>
  internal void PostShow() {
   if (savedGeom == null) return;
   System.Windows.Threading.Dispatcher.CurrentDispatcher.BeginInvoke(new Action(() => {
    ReapplySavedGeometry();
    Persist(savedGeom[3], savedGeom[4]);
   }), System.Windows.Threading.DispatcherPriority.Loaded);
   var settle = new System.Windows.Threading.DispatcherTimer { Interval = TimeSpan.FromMilliseconds(450) };
   int ticks = 0;
   settle.Tick += (s, e) => {
    ticks++;
    try {
     var sz = ps.Size;
     if (sz.Width != savedGeom[3] || sz.Height != savedGeom[4]) ReapplySavedGeometry();
    } catch { }
    if (ticks >= 5) { settle.Stop(); Persist(savedGeom[3], savedGeom[4]); }
   };
   settle.Start();
   StartPolling();
  }

  internal void PersistNow() { Persist(null, null); }

  void ReapplySavedGeometry() {
   try { if (!ps.Visible) return; } catch { return; }
   SetSizeClamped(savedGeom[3], savedGeom[4]);
   if (savedGeom[0] == 0 && savedGeom[1] >= 0 && savedGeom[2] >= 0 && IsOnVirtualScreen(savedGeom[1], savedGeom[2])) {
    try { ps.Location = new System.Drawing.Point(savedGeom[1], savedGeom[2]); } catch { }
   }
  }

  void SetSizeClamped(int w, int h) {
   try { ps.Size = new System.Drawing.Size(Math.Max(minW, Math.Min(w, 4000)), Math.Max(minH, Math.Min(h, 4000))); } catch { }
  }

  /// <summary>Doc trang thai hien tai (uu tien kich thuoc that tu event args) va ghi file khi hop le.</summary>
  void Persist(int? widthOverride, int? heightOverride) {
   try {
    if (ps == null) return;
    int dock = 0, x = 0, y = 0, w = 0, h = 0;
    try { dock = (int)ps.Dock; } catch { }
    try { x = ps.Location.X; y = ps.Location.Y; } catch { }
    try { w = ps.Size.Width; h = ps.Size.Height; } catch { }
    if (widthOverride.HasValue && widthOverride.Value > 0) w = widthOverride.Value;
    if (heightOverride.HasValue && heightOverride.Value > 0) h = heightOverride.Value;
    if (w <= 0 || h <= 0) return;
    lastDock = dock; lastX = x; lastY = y; lastW = w; lastH = h;
    PaletteStateStore.Save(fileName, dock, x, y, w, h);
   } catch { }
  }

  /// <summary>Polling nhe trong luc palette hien — du phong khi host khong ban event luc keo tha.</summary>
  void StartPolling() {
   if (pollTimer != null) return;
   pollTimer = new System.Windows.Threading.DispatcherTimer { Interval = TimeSpan.FromMilliseconds(700) };
   pollTimer.Tick += (s, e) => {
    try {
     if (!ps.Visible) return;
     int dock = 0, x = 0, y = 0, w = 0, h = 0;
     try { dock = (int)ps.Dock; } catch { }
     try { x = ps.Location.X; y = ps.Location.Y; } catch { }
     try { w = ps.Size.Width; h = ps.Size.Height; } catch { }
     if (dock != lastDock || x != lastX || y != lastY || w != lastW || h != lastH) Persist(null, null);
    } catch { }
   };
   pollTimer.Start();
  }

  static bool IsOnVirtualScreen(int x, int y) {
   double l = SystemParameters.VirtualScreenLeft, t = SystemParameters.VirtualScreenTop;
   double w = SystemParameters.VirtualScreenWidth, h = SystemParameters.VirtualScreenHeight;
   return x + 60 > l && x < l + w && y + 20 > t && y < t + h;
  }
 }

 /// <summary>Luu dock/vi tri/kich thuoc cua tung Palette vao %APPDATA%\TGIRR\(ten file), dinh dang "v1 dock x y w h".</summary>
 static class PaletteStateStore {
  static string StateDir { get { return System.IO.Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "TGIRR"); } }
  static string FileFor(string name) { return System.IO.Path.Combine(StateDir, name); }
  internal static void Save(string file, int dock, int x, int y, int w, int h) {
   try {
    System.IO.Directory.CreateDirectory(StateDir);
    System.IO.File.WriteAllText(FileFor(file), "v1 " + dock + " " + x + " " + y + " " + w + " " + h);
   } catch { }
  }
  internal static bool TryLoad(string file, ref int dock, ref int x, ref int y, ref int w, ref int h) {
   try {
    if (!System.IO.File.Exists(FileFor(file))) return false;
    var parts = System.IO.File.ReadAllText(FileFor(file)).Split(' ');
    if (parts.Length < 6 || parts[0] != "v1") return false;
    dock = int.Parse(parts[1]); x = int.Parse(parts[2]); y = int.Parse(parts[3]);
    w = int.Parse(parts[4]); h = int.Parse(parts[5]);
    return true;
   } catch { return false; }
  }
 }

 /// <summary>Luu danh sach nut duoc ghim vao %APPDATA%\TGIRR\quick-tools.txt (dinh dang "v1 CMD|CMD...").</summary>
 static class QuickToolStore {
  static string StateDir { get { return System.IO.Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "TGIRR"); } }
  static string StateFile { get { return System.IO.Path.Combine(StateDir, "quick-tools.txt"); } }
  internal static void Save(List<string> pins) {
   try {
    System.IO.Directory.CreateDirectory(StateDir);
    System.IO.File.WriteAllText(StateFile, "v1 " + string.Join("|", pins.ToArray()));
   } catch { }
  }
  internal static List<string> Load() {
   var list = new List<string>();
   try {
    if (!System.IO.File.Exists(StateFile)) return list;
    var txt = System.IO.File.ReadAllText(StateFile);
    if (!txt.StartsWith("v1 ")) return list;
    foreach (var s in txt.Substring(3).Split('|')) {
     var t = s.Trim();
     if (t.Length > 0 && !list.Contains(t)) list.Add(t);
    }
   } catch { }
   return list;
  }
 }

 /// <summary>
 /// Giao dien WPF tinh gon cua palette cong cu TGIRR CAD.
 /// </summary>
 public sealed class PaletteContent : UserControl {
  static readonly Color BgDark = Color.FromRgb(24, 32, 43);
  static readonly Color CardBg = Color.FromRgb(30, 41, 54);
  static readonly Color CardBorder = Color.FromRgb(46, 61, 79);
  static readonly Color BtnNormalBg = Color.FromRgb(36, 49, 66);
  static readonly Color BtnHoverBg = Color.FromRgb(48, 65, 88);
  static readonly Color BtnPressedBg = Color.FromRgb(22, 30, 40);
  static readonly Color BtnBorder = Color.FromRgb(50, 68, 90);
  static readonly Color MutedText = Color.FromRgb(157, 174, 192);

  // Accent Colors cho 3 nhom
  static readonly Color CyanAccent = Color.FromRgb(56, 189, 248);   // Ranh gioi & Bien dang
  static readonly Color GreenAccent = Color.FromRgb(52, 211, 153);  // Thiet ke & Tuoi
  static readonly Color AmberAccent = Color.FromRgb(251, 191, 36);  // Ghi chu & Tien ich

  static readonly ControlTemplate ButtonTemplate = CreateButtonTemplate();

  public PaletteContent() {
   Background = new SolidColorBrush(BgDark);
   var root = new StackPanel { Margin = new Thickness(10, 8, 10, 8) };

   // Header thanh thuong hieu + nut nap lai
   root.Children.Add(MakeHeader());

   // Nhom 1: Ranh gioi & Bien dang (HBD, JH, SBS)
   root.Children.Add(MakeGroup(
    "RANH GIỚI & BIÊN DẠNG",
    CyanAccent,
    MakeActionButton("HBD", "Bound Hatch",
     "HBD — Vẽ đường bao Hatch cỏ",
     "Tự động tạo đường bao Boundary Polyline kín quanh các Hatch cỏ trên layer TG-BOUND (hỗ trợ join mảng giáp nhau).",
     "Lệnh: HBD (hoặc BH, TGBOUND)", CyanAccent, true, false),
    MakeActionButton("JH", "Gộp Hatch",
     "JH — Gộp các Hatch thành 1",
     "Hợp nhất các Hatch phân mảnh giáp nhau thành 1 Hatch duy nhất và tạo đường bao chung trên layer TG-BOUND.",
     "Lệnh: JH (hoặc MH, JOINHATCH)", CyanAccent, true, false),
    MakeActionButton("CVPL", "Convert sang Polyline",
     "CVPL — Convert LINE/ARC/CIRCLE/SPLINE sang Polyline",
     "Chuyển LINE, ARC, CIRCLE, ELLIPSE, SPLINE, POLYLINE kiểu cũ và REGION thành LWPOLYLINE; giữ layer/màu/nét; UNDO 1 bước. Gõ CVPLG để giữ đối tượng nguồn.",
     "Lệnh: CVPL (hoặc CVP, CVPLG)", CyanAccent, true, false),
    MakeActionButton("SBS", "Chọn theo mẫu",
     "SBS — Chọn đối tượng giống mẫu trong vùng",
     "Chọn các đối tượng nằm trong Polyline kín có cùng layer, màu sắc, kiểu nét hoặc tên Block với mẫu.",
     "Lệnh: SBS", CyanAccent, false, false),
    MakeActionButton("SBSE", "Chọn chính xác",
     "SBSE — Chọn chính xác theo mẫu (trùng chữ)",
     "Chọn các đối tượng trong vùng Polyline kín có cùng layer, màu, kiểu nét và BẮT BUỘC trùng nội dung chữ với TEXT/MTEXT.",
     "Lệnh: SBSE", CyanAccent, false, false)
   ));

   // Nhom 2: Thiet ke & He thong (VDNG, TNET, TGL)
   root.Children.Add(MakeGroup(
    "THIẾT KẾ & HỆ THỐNG",
    GreenAccent,
    MakeActionButton("VDNG", "Dây nhỏ giọt",
     "VDNG — Rải dây nhỏ giọt",
     "Vẽ dây nhỏ giọt tự do có bo góc hoặc offset song song theo đường ranh giới bên trong boundary kín.",
     "Lệnh: VDNG", GreenAccent, false, false),
    MakeActionButton("TNET", "Nét vẽ có chữ",
     "TNET — Tạo nét vẽ có chữ (LIN)",
     "Mở hộp thoại trực quan thiết kế nét vẽ AutoCAD/ZWCAD có chữ và nạp trực tiếp vào bản vẽ.",
     "Cửa sổ: TNET", GreenAccent, false, false),
    MakeActionButton("TGL", "Tạo Layer chuẩn hoặc thêm Layer vào kho",
     "TGL — Tạo bộ Layer tiêu chuẩn / thêm Layer vào kho",
     "Khởi tạo nhanh bộ 23 layer chuẩn TGIRR (tên, màu, nét) và đặt TG-DRIP làm layer hiện hành.",
     "Lệnh: TGL", GreenAccent, false, true)
   ));

   // Nhom 3: Ghi chu & Tien ich (TL, TGN, CPLUS)
   root.Children.Add(MakeGroup(
    "GHI CHÚ & TIỆN ÍCH",
    AmberAccent,
    MakeActionButton("TL", "Đo chiều dài",
     "TL — Tính tổng chiều dài",
     "Cộng dồn tổng chiều dài của tất cả Line, Polyline, Arc, Circle, Spline, Ellipse được chọn trước.",
     "Lệnh: TL (chọn trước rồi bấm nút)", AmberAccent, true, false),
    MakeActionButton("TGN", "Đánh số nhãn",
     "TGN — Đánh số vùng tưới / đối tượng",
     "Tự động đánh số thứ tự trong nhãn tròn hoặc ellipse theo tọa độ hoặc bám theo đường Polyline.",
     "Lệnh: TGN", AmberAccent, false, false),
    MakeActionButton("CPLUS", "Copy theo quy luật",
     "CPLUS — Copy văn bản theo quy luật",
     "Sao chép Text, MText, Multileader, Block Attribute hoặc Dimension tăng dần theo số, chữ hoặc danh sách.",
     "Cửa sổ / Lệnh: CPLUS", AmberAccent, false, true),
    MakeActionButton("DOITEXT", "Đổi MText → Text",
     "DOITEXT — Đổi MText sang Text & Gom list",
     "Chuyển đổi MText sang Text tại chỗ hoặc gom nhiều MText thành 1 danh sách cột thẳng hàng đều đặn.",
     "Lệnh: DOITEXT (hoặc M2T)", AmberAccent, false, false)
   ));

   // Footer
   root.Children.Add(new TextBlock {
    Text = "Gõ TGIRRPALETTE để ẩn / hiện • Bấm ☆ ở mỗi nút để ghim vào palette Quick Tools riêng (TGIRRQUICK)",
    Foreground = new SolidColorBrush(Color.FromRgb(100, 116, 139)),
    FontSize = 10.5,
    TextAlignment = TextAlignment.Center,
    Margin = new Thickness(0, 4, 0, 2)
   });

   Content = new ScrollViewer {
    Content = root,
    VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
    HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled
   };
  }

  static FrameworkElement MakeHeader() {
   var dock = new DockPanel { Margin = new Thickness(2, 2, 2, 8) };

   // Left: TG Logo + Brand Title
   var left = new StackPanel { Orientation = Orientation.Horizontal, VerticalAlignment = VerticalAlignment.Center };
   var logo = new Border {
    Background = new SolidColorBrush(CyanAccent),
    CornerRadius = new CornerRadius(3),
    Padding = new Thickness(4, 1, 4, 1),
    Margin = new Thickness(0, 0, 6, 0)
   };
   logo.Child = new TextBlock {
    Text = "TG",
    FontSize = 10.5,
    FontWeight = FontWeights.Bold,
    Foreground = new SolidColorBrush(Color.FromRgb(15, 23, 42))
   };
   left.Children.Add(logo);

   left.Children.Add(new TextBlock {
    Text = "TGIRR CAD",
    FontSize = 13,
    FontWeight = FontWeights.Bold,
    Foreground = Brushes.White,
    VerticalAlignment = VerticalAlignment.Center
   });
   DockPanel.SetDock(left, Dock.Left);
   dock.Children.Add(left);

   // Right: Reload button
   var reloadBtn = new Button {
    Template = ButtonTemplate,
    Content = "⟳ Nạp lại",
    FontSize = 10.5,
    Foreground = new SolidColorBrush(MutedText),
    Background = new SolidColorBrush(Color.FromRgb(32, 43, 58)),
    BorderBrush = new SolidColorBrush(CardBorder),
    BorderThickness = new Thickness(1),
    Padding = new Thickness(6, 2, 6, 2),
    Cursor = Cursors.Hand,
    HorizontalAlignment = HorizontalAlignment.Right,
    ToolTip = "Nạp lại toàn bộ Lisp & Plugin TGIRR (TGIRRLOAD)"
   };
   reloadBtn.MouseEnter += (s, e) => {
    reloadBtn.Foreground = Brushes.White;
    reloadBtn.BorderBrush = new SolidColorBrush(CyanAccent);
   };
   reloadBtn.MouseLeave += (s, e) => {
    reloadBtn.Foreground = new SolidColorBrush(MutedText);
    reloadBtn.BorderBrush = new SolidColorBrush(CardBorder);
   };
   reloadBtn.Click += (s, e) => Run("TGIRRLOAD", false);
   DockPanel.SetDock(reloadBtn, Dock.Right);
   dock.Children.Add(reloadBtn);

   return dock;
  }

  static FrameworkElement MakeGroup(string title, Color accent, params Button[] buttons) {
   var card = new Border {
    Background = new SolidColorBrush(CardBg),
    BorderBrush = new SolidColorBrush(CardBorder),
    BorderThickness = new Thickness(1),
    CornerRadius = new CornerRadius(5),
    Padding = new Thickness(6, 5, 6, 6),
    Margin = new Thickness(0, 0, 0, 6)
   };

   var panel = new StackPanel();

   // Header nhom: vach mau + tieu de
   var titleRow = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(1, 0, 0, 5) };
   titleRow.Children.Add(new Rectangle {
    Width = 3,
    Height = 11,
    Fill = new SolidColorBrush(accent),
    Margin = new Thickness(0, 0, 5, 0),
    VerticalAlignment = VerticalAlignment.Center
   });
   titleRow.Children.Add(new TextBlock {
    Text = title,
    FontSize = 10.5,
    FontWeight = FontWeights.SemiBold,
    Foreground = new SolidColorBrush(accent),
    VerticalAlignment = VerticalAlignment.Center
   });
   panel.Children.Add(titleRow);

   for (int i = 0; i < buttons.Length; i += 2) {
    if (i + 1 < buttons.Length) {
     var grid = new Grid { Margin = new Thickness(0, 0, 0, 3) };
     grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
     grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });

     var b1 = buttons[i];
     var b2 = buttons[i + 1];
     b1.Margin = new Thickness(0, 0, 2, 0);
     grid.Children.Add(b1);
     Grid.SetColumn(b1, 0);

     b2.Margin = new Thickness(2, 0, 0, 0);
     grid.Children.Add(b2);
     Grid.SetColumn(b2, 1);

     panel.Children.Add(grid);
    } else {
     var b = buttons[i];
     b.Margin = new Thickness(0, 0, 0, 3);
     panel.Children.Add(b);
    }
   }

   card.Child = panel;
   return card;
  }

  // ----- Quick tools: danh muc nut + danh sach ghim — hien thi tren palette Quick Tools RIENG -----
  internal sealed class QuickToolInfo {
   internal readonly string Cmd, Label, TipTitle, TipDesc, TipCmd;
   internal readonly Color Accent;
   internal readonly bool KeepSelection;
   internal QuickToolInfo(string cmd, string label, string t, string d, string c, Color a, bool k) {
    Cmd = cmd; Label = label; TipTitle = t; TipDesc = d; TipCmd = c; Accent = a; KeepSelection = k;
   }
  }
  static readonly Dictionary<string, QuickToolInfo> Catalog = new Dictionary<string, QuickToolInfo>();
  static readonly List<string> Pinned = QuickToolStore.Load();

  internal static bool HasCatalog { get { return Catalog.Count > 0; } }
  internal static int PinnedCount { get { return Pinned.Count; } }

  /// <summary>Danh sach nut duoc ghim theo thu tu ghim (chi tra ve nut con trong Catalog).</summary>
  internal static List<QuickToolInfo> PinnedInfos() {
   var list = new List<QuickToolInfo>();
   foreach (var cmd in Pinned) {
    QuickToolInfo info;
    if (Catalog.TryGetValue(cmd, out info)) list.Add(info);
   }
   return list;
  }

  static bool IsPinned(string cmd) { return Pinned.Contains(cmd); }

  static bool TogglePin(string cmd) {
   bool now;
   if (Pinned.Contains(cmd)) { Pinned.Remove(cmd); now = false; }
   else { Pinned.Add(cmd); now = true; }
   QuickToolStore.Save(Pinned);
   QuickPalette.OnPinsChanged();
   return now;
  }

  internal static Button MakeActionButton(
   string cmd,
   string label,
   string tipTitle,
   string tipDesc,
   string tipCmd,
   Color accent,
   bool keepSelection,
   bool isWide,
   bool pinned = false
  ) {
   Catalog[cmd] = new QuickToolInfo(cmd, label, tipTitle, tipDesc, tipCmd, accent, keepSelection);
   var b = new Button {
    Template = ButtonTemplate,
    Height = isWide ? 29 : 31,
    HorizontalAlignment = HorizontalAlignment.Stretch,
    HorizontalContentAlignment = HorizontalAlignment.Left,
    VerticalContentAlignment = VerticalAlignment.Center,
    Background = new SolidColorBrush(BtnNormalBg),
    BorderBrush = new SolidColorBrush(BtnBorder),
    BorderThickness = new Thickness(1),
    Padding = new Thickness(isWide ? 7 : 5, 2, isWide ? 7 : 5, 2),
    Cursor = Cursors.Hand,
    FocusVisualStyle = null
   };

   var dock = new DockPanel { LastChildFill = true };

   // Badge ma lenh
   var badge = new Border {
    Background = new SolidColorBrush(Color.FromArgb(38, accent.R, accent.G, accent.B)),
    BorderBrush = new SolidColorBrush(Color.FromArgb(120, accent.R, accent.G, accent.B)),
    BorderThickness = new Thickness(1),
    CornerRadius = new CornerRadius(3),
    Padding = new Thickness(3, 1, 3, 1),
    VerticalAlignment = VerticalAlignment.Center,
    MinWidth = isWide ? 44 : 36
   };
   badge.Child = new TextBlock {
    Text = cmd,
    Foreground = new SolidColorBrush(accent),
    FontSize = 10.5,
    FontWeight = FontWeights.Bold,
    TextAlignment = TextAlignment.Center
   };
   DockPanel.SetDock(badge, Dock.Left);
   dock.Children.Add(badge);

   // Sao ghim Quick tools: hover moi hien (nút đã ghim thì hiện luôn), bam de ghim/bo ghim
   bool starred = pinned || IsPinned(cmd);
   var pin = new TextBlock {
    Text = starred ? "★" : "☆",
    FontSize = 12,
    Background = Brushes.Transparent,
    Foreground = new SolidColorBrush(starred ? AmberAccent : MutedText),
    VerticalAlignment = VerticalAlignment.Center,
    Margin = new Thickness(0, 0, 2, 0),
    Cursor = Cursors.Hand,
    ToolTip = starred ? "Bỏ ghim khỏi Quick tools" : "Ghim lên Quick tools",
    Opacity = starred ? 1 : 0
   };
   pin.PreviewMouseLeftButtonDown += (s, e) => e.Handled = true;
   pin.PreviewMouseLeftButtonUp += (s, e) => {
    e.Handled = true;
    bool now = TogglePin(cmd);
    pin.Text = now ? "★" : "☆";
    pin.Foreground = new SolidColorBrush(now ? AmberAccent : MutedText);
    pin.ToolTip = now ? "Bỏ ghim khỏi Quick tools" : "Ghim lên Quick tools";
    pin.Opacity = now ? 1 : 0;
   };
   DockPanel.SetDock(pin, Dock.Right);
   dock.Children.Add(pin);

   // Nhan chuc nang
   var text = new TextBlock {
    Text = label,
    Foreground = new SolidColorBrush(Color.FromRgb(240, 244, 248)),
    FontSize = 11,
    FontWeight = FontWeights.SemiBold,
    Margin = new Thickness(5, 0, 0, 0),
    VerticalAlignment = VerticalAlignment.Center,
    TextTrimming = TextTrimming.CharacterEllipsis
   };
   dock.Children.Add(text);

   b.Content = dock;

   // Hover & Press animations
   var normalBg = new SolidColorBrush(BtnNormalBg);
   var hoverBg = new SolidColorBrush(BtnHoverBg);
   var pressedBg = new SolidColorBrush(BtnPressedBg);
   var normalBorder = new SolidColorBrush(BtnBorder);
   var hoverBorder = new SolidColorBrush(accent);

   b.MouseEnter += (s, e) => {
    b.Background = hoverBg;
    b.BorderBrush = hoverBorder;
    bool p2 = IsPinned(cmd);
    pin.Text = p2 ? "★" : "☆";
    pin.Foreground = new SolidColorBrush(p2 ? AmberAccent : MutedText);
    pin.ToolTip = p2 ? "Bỏ ghim khỏi Quick tools" : "Ghim lên Quick tools";
    pin.Opacity = 1;
   };
   b.MouseLeave += (s, e) => {
    b.Background = normalBg;
    b.BorderBrush = normalBorder;
    pin.Opacity = IsPinned(cmd) ? 1 : 0;
   };
   b.PreviewMouseLeftButtonDown += (s, e) => {
    b.Background = pressedBg;
   };
   b.PreviewMouseLeftButtonUp += (s, e) => {
    b.Background = hoverBg;
   };

   // Tooltip
   b.ToolTip = CreateToolTip(cmd, tipTitle, tipDesc, tipCmd, accent);

   // Click
   b.Click += (s, e) => Run(cmd, keepSelection);

   return b;
  }

  static ToolTip CreateToolTip(string cmd, string title, string desc, string shortcut, Color accent) {
   var tip = new ToolTip {
    Background = new SolidColorBrush(Color.FromRgb(20, 28, 38)),
    BorderBrush = new SolidColorBrush(accent),
    BorderThickness = new Thickness(1),
    Foreground = Brushes.White,
    Padding = new Thickness(10, 8, 10, 8),
    MaxWidth = 280
   };
   var panel = new StackPanel();
   panel.Children.Add(new TextBlock {
    Text = title,
    FontWeight = FontWeights.Bold,
    FontSize = 12,
    Foreground = new SolidColorBrush(accent),
    Margin = new Thickness(0, 0, 0, 4)
   });
   panel.Children.Add(new TextBlock {
    Text = desc,
    FontSize = 11,
    Foreground = new SolidColorBrush(Color.FromRgb(203, 213, 225)),
    TextWrapping = TextWrapping.Wrap,
    Margin = new Thickness(0, 0, 0, 6)
   });
   panel.Children.Add(new TextBlock {
    Text = shortcut,
    FontSize = 10,
    FontStyle = FontStyles.Italic,
    Foreground = new SolidColorBrush(Color.FromRgb(148, 163, 184))
   });
   tip.Content = panel;
   return tip;
  }

  static ControlTemplate CreateButtonTemplate() {
   var template = new ControlTemplate(typeof(Button));
   var border = new FrameworkElementFactory(typeof(Border));
   border.Name = "border";
   border.SetValue(Border.CornerRadiusProperty, new CornerRadius(4));
   border.SetValue(Border.BackgroundProperty, new TemplateBindingExtension(Button.BackgroundProperty));
   border.SetValue(Border.BorderBrushProperty, new TemplateBindingExtension(Button.BorderBrushProperty));
   border.SetValue(Border.BorderThicknessProperty, new TemplateBindingExtension(Button.BorderThicknessProperty));
   border.SetValue(Border.PaddingProperty, new TemplateBindingExtension(Button.PaddingProperty));

   var cp = new FrameworkElementFactory(typeof(ContentPresenter));
   cp.SetValue(ContentPresenter.HorizontalAlignmentProperty, new TemplateBindingExtension(Button.HorizontalContentAlignmentProperty));
   cp.SetValue(ContentPresenter.VerticalAlignmentProperty, new TemplateBindingExtension(Button.VerticalContentAlignmentProperty));
   border.AppendChild(cp);
   template.VisualTree = border;
   return template;
  }

  static void Run(string cmd, bool keepSelection) {
   var doc = ZwSoft.ZwCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;
   if (doc != null) {
    doc.SendStringToExecute((keepSelection ? "" : "\x1b\x1b") + cmd + " ", true, false, false);
   }
  }
 }

 /// <summary>
 /// Noi dung WPF cua palette Quick Tools RIENG: WrapPanel cac nut duoc ghim (★),
 /// dung chung kieu nut va tooltip voi PaletteContent. Bam ★ tren nut de bo ghim.
 /// </summary>
 sealed class QuickToolsContent : UserControl {
  readonly WrapPanel panel = new WrapPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(7, 5, 3, 1) };

  public QuickToolsContent() {
   Background = new SolidColorBrush(Color.FromRgb(24, 32, 43));
   Content = new ScrollViewer {
    Content = panel,
    VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
    HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled
   };
   Refresh();
  }

  internal void Refresh() {
   panel.Children.Clear();
   foreach (var info in PaletteContent.PinnedInfos()) {
    var b = PaletteContent.MakeActionButton(info.Cmd, info.Label, info.TipTitle, info.TipDesc, info.TipCmd, info.Accent, info.KeepSelection, false, true);
    b.Height = 27;
    b.MinWidth = 120;
    b.Margin = new Thickness(0, 0, 4, 4);
    b.HorizontalAlignment = HorizontalAlignment.Left;
    panel.Children.Add(b);
   }
  }
 }
}