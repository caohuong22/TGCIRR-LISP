using System;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using ZwSoft.ZwCAD.Runtime;
using ZwSoft.ZwCAD.Windows;

namespace Tgirrr.CadLisp {
 /// <summary>
 /// Lenh TGIRRPALETTE: bat/tat Palette cong cu TGIRR.
 /// ZWCAD khong co Ribbon lap trinh duoc (khac AutoCAD), nen dung
 /// PaletteSet dockable voi cac nut bam WPF thay cho Ribbon.
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
    _ps.MinimumSize = new System.Drawing.Size(300, 360);
    _ps.Size = new System.Drawing.Size(320, 520);
    _ps.AddVisual("TGIRR CAD", new PaletteContent());
    _ps.Visible = true;      // lan dau: hien ngay
   } else {
    _ps.Visible = !_ps.Visible; // lan sau: bat/tat
   }
   if (_ps.Visible) _ps.Activate(0);
  }
 }

 /// <summary>Noi dung WPF cua palette: cac nut lenh SBS/TL/TGL/TGN/CPLUS/VDNG/TNET.</summary>
 public sealed class PaletteContent : UserControl {
  static readonly Brush WindowBrush = new SolidColorBrush(Color.FromRgb(27, 36, 48));
  static readonly Brush CardBrush = new SolidColorBrush(Color.FromRgb(38, 49, 63));
  static readonly Brush FieldBrush = new SolidColorBrush(Color.FromRgb(50, 63, 79));
  static readonly Brush CyanBrush = new SolidColorBrush(Color.FromRgb(84, 196, 232));
  static readonly Brush MutedBrush = new SolidColorBrush(Color.FromRgb(157, 174, 192));
  static readonly Brush YellowBrush = new SolidColorBrush(Color.FromRgb(255, 196, 61));

  public PaletteContent() {
   Background = WindowBrush;
   var page = new StackPanel { Margin = new Thickness(14) };

   page.Children.Add(new TextBlock {
    Text = "TGIRR CAD",
    FontSize = 20,
    FontWeight = FontWeights.Bold,
    Foreground = CyanBrush,
    Margin = new Thickness(0, 0, 0, 2)
   });
   page.Children.Add(new TextBlock {
    Text = "Bấm nút để chạy lệnh tương ứng.",
    Foreground = MutedBrush,
    FontSize = 12,
    Margin = new Thickness(0, 0, 0, 12)
   });

   page.Children.Add(Group("CHỌN", MakeButton("SBS", "Chọn đối tượng giống mẫu", "trong vùng polyline kín")));
   page.Children.Add(Group("ĐO", MakeButton("TL", "Tổng chiều dài", "các đường đã chọn trước")));
   page.Children.Add(Group("LAYER", MakeButton("TGL", "Tạo bộ Layer chuẩn", "đặt TG-DRIP làm layer hiện hành")));
   page.Children.Add(Group("ĐÁNH SỐ", MakeButton("TGN", "Đánh số đối tượng / vùng tưới", "bằng nhãn tròn / ellipse")));
   page.Children.Add(Group("VĂN BẢN", MakeButton("CPLUS", "Copy theo quy luật", "TEXT/MTEXT/Multileader/Attribute/Dim")));
   page.Children.Add(Group("TƯỚI", MakeButton("VDNG", "Rải dây nhỏ giọt", "bên trong boundary kín")));
   page.Children.Add(Group("NÉT VẼ", MakeButton("TNET", "Tạo nét vẽ có chữ", "mở hộp thoại tạo/sửa file LIN")));

   page.Children.Add(new TextBlock {
    Text = "Để mở/đóng bảng này: gõ TGIRRPALETTE tại dòng lệnh.",
    Foreground = MutedBrush,
    FontSize = 11,
    TextWrapping = TextWrapping.Wrap,
    Margin = new Thickness(0, 14, 0, 4)
   });

   Content = new ScrollViewer { Content = page, VerticalScrollBarVisibility = ScrollBarVisibility.Auto };
  }

  static StackPanel Group(string title, params Button[] buttons) {
   var g = new StackPanel { Margin = new Thickness(0, 6, 0, 2) };
   g.Children.Add(new TextBlock {
    Text = title,
    Foreground = YellowBrush,
    FontSize = 11,
    FontWeight = FontWeights.SemiBold,
    Margin = new Thickness(2, 0, 0, 4)
   });
   foreach (var b in buttons) g.Children.Add(b);
   return g;
  }

  static Button MakeButton(string cmd, string title, string desc) {
   var b = new Button {
    HorizontalAlignment = HorizontalAlignment.Stretch,
    HorizontalContentAlignment = HorizontalAlignment.Left,
    Background = CardBrush,
    BorderBrush = new SolidColorBrush(Color.FromRgb(60, 78, 100)),
    BorderThickness = new Thickness(1),
    Padding = new Thickness(12, 8, 12, 8),
    Margin = new Thickness(0, 0, 0, 6),
    Cursor = System.Windows.Input.Cursors.Hand
   };
   var sp = new StackPanel();
   sp.Children.Add(new TextBlock {
    Text = cmd + "  —  " + title,
    Foreground = Brushes.White,
    FontSize = 13,
    FontWeight = FontWeights.SemiBold
   });
   sp.Children.Add(new TextBlock {
    Text = desc,
    Foreground = MutedBrush,
    FontSize = 11,
    TextWrapping = TextWrapping.Wrap
   });
   b.Content = sp;
   b.Click += (s, e) => Run(cmd);
   return b;
  }

  static void Run(string cmd) {
   var doc = ZwSoft.ZwCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;
   if (doc != null) doc.SendStringToExecute("\x1b\x1b" + cmd + " ", true, false, false);
  }
 }
}