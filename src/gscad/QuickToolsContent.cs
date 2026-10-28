using System.Collections.Generic;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;

namespace Tgirrr.CadLisp {
 /// <summary>
 /// Noi dung palette Quick Tools rieng: chip theo thu tu ghim, co empty-state,
 /// va tu prune lenh khong con trong catalog.
 /// </summary>
 public sealed class QuickToolsContent : UserControl {
  readonly WrapPanel panel = new WrapPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(7, 5, 3, 1) };
  readonly List<ToolChip.Star> stars = new List<ToolChip.Star>();
  readonly TextBlock empty = new TextBlock {
   Text = "Chưa ghim lệnh nào. Mở palette TGIRR CAD rồi bấm ★ trên nút công cụ để ghim vào đây.",
   Foreground = PaletteTheme.Brush(PaletteTheme.DimText),
   FontSize = 10.5,
   TextWrapping = TextWrapping.Wrap,
   Margin = new Thickness(2, 2, 6, 6),
   Visibility = Visibility.Collapsed
  };

  public QuickToolsContent() {
   Background = PaletteTheme.Brush(PaletteTheme.BgDark);
   var outer = new StackPanel();
   outer.Children.Add(panel);
   outer.Children.Add(empty);
   Content = new ScrollViewer {
    Content = outer,
    VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
    HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled
   };
   PinService.Changed += Refresh;
   Refresh();
  }

  internal void Refresh() {
   panel.Children.Clear();
   stars.Clear();
   List<TgToolInfo> tools = PinService.PinnedTools();
   foreach (TgToolInfo tool in tools) {
    var b = ToolChip.Create(tool, true, stars);
    b.Margin = new Thickness(0, 0, 4, 4);
    b.HorizontalAlignment = HorizontalAlignment.Left;
    panel.Children.Add(b);
   }
   empty.Visibility = tools.Count == 0 ? Visibility.Visible : Visibility.Collapsed;
  }
 }
}
