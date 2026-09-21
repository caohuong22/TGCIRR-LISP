using System;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Shapes;
using Gssoft.Gscad.Runtime;
using Gssoft.Gscad.Windows;

namespace Tgirrr.CadLisp {
 /// <summary>
 /// Lenh TGIRRPALETTE: bat/tat Palette cong cu TGIRR CAD.
 /// </summary>
 public sealed class PaletteCommands {
  static PaletteSet _ps;

  [CommandMethod("TGIRRPALETTE")]
  public void Show() {
   if (_ps == null) {
    _ps = new PaletteSet("TGIRR CAD");
    _ps.Style = PaletteSetStyles.ShowAutoHideButton |
                PaletteSetStyles.ShowCloseButton |
                PaletteSetStyles.ShowPropertiesMenu;
    _ps.DockEnabled = DockSides.Left | DockSides.Right;
    _ps.MinimumSize = new System.Drawing.Size(250, 320);
    _ps.Size = new System.Drawing.Size(280, 420);
    _ps.AddVisual("TGIRR CAD", new PaletteContent());
    _ps.Visible = true;
   } else {
    _ps.Visible = !_ps.Visible;
   }
   if (_ps.Visible) _ps.Activate(0);
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
     "Mở hộp thoại trực quan thiết kế nét vẽ AutoCAD/GstarCAD có chữ và nạp trực tiếp vào bản vẽ.",
     "Cửa sổ: TNET", GreenAccent, false, false),
    MakeActionButton("TGL", "Tạo 23 Layer tưới chuẩn",
     "TGL — Tạo bộ Layer tiêu chuẩn",
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
    Text = "Gõ TGIRRPALETTE để ẩn / hiện bảng công cụ",
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

  static Button MakeActionButton(
   string cmd,
   string label,
   string tipTitle,
   string tipDesc,
   string tipCmd,
   Color accent,
   bool keepSelection,
   bool isWide
  ) {
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
   };
   b.MouseLeave += (s, e) => {
    b.Background = normalBg;
    b.BorderBrush = normalBorder;
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
   var doc = Gssoft.Gscad.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;
   if (doc != null) {
    doc.SendStringToExecute((keepSelection ? "" : "\x1b\x1b") + cmd + " ", true, false, false);
   }
  }
 }
}