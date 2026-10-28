using System;
using System.Collections.Generic;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;

namespace Tgirrr.CadLisp {
 /// <summary>
 /// Mot nut lenh (chip) dung chung cho palette chinh, Quick Tools va Ribbon:
 /// nhan, tooltip, ★ deu lay tu TgToolCatalog nen khong the lech giua cac nen CAD.
 /// </summary>
 internal static class ToolChip {
  internal static Button Create(TgToolInfo tool, bool fromQuickPalette, List<ToolChip.Star> stars) {
   Color accent = PaletteTheme.Accent(tool.Accent);
   var b = new Button {
    Template = PaletteTheme.ChipTemplate,
    Width = 44,
    Height = 44,
    Background = PaletteTheme.Brush(PaletteTheme.BtnNormalBg),
    BorderBrush = PaletteTheme.Brush(PaletteTheme.BtnBorder),
    BorderThickness = new Thickness(1),
    Padding = new Thickness(0),
    Cursor = Cursors.Hand,
    FocusVisualStyle = null,
    Tag = tool.Id
   };

   var grid = new Grid();
   grid.Children.Add(new Image {
    Source = ToolIcons.For(tool.Icon, accent),
    Width = 28,
    Height = 28,
    Stretch = Stretch.Uniform,
    HorizontalAlignment = HorizontalAlignment.Center,
    VerticalAlignment = VerticalAlignment.Center,
    IsHitTestVisible = false
   });

   var star = new TextBlock {
    Text = "☆",
    FontSize = 10,
    Background = Brushes.Transparent,
    HorizontalAlignment = HorizontalAlignment.Right,
    VerticalAlignment = VerticalAlignment.Top,
    Margin = new Thickness(0, 0, 2, 0),
    Cursor = Cursors.Hand
   };
   star.PreviewMouseLeftButtonDown += (s, e) => e.Handled = true;
   star.PreviewMouseLeftButtonUp += (s, e) => {
    e.Handled = true;
    PinService.Toggle(tool.Id);
   };
   grid.Children.Add(star);
   if (stars != null) stars.Add(new ToolChip.Star(tool.Id, star, fromQuickPalette));

   b.Content = grid;

   b.MouseEnter += (s, e) => {
    b.Background = PaletteTheme.Brush(PaletteTheme.BtnHoverBg);
    b.BorderBrush = new SolidColorBrush(accent);
    star.Opacity = 1;
   };
   b.MouseLeave += (s, e) => {
    b.Background = PaletteTheme.Brush(PaletteTheme.BtnNormalBg);
    b.BorderBrush = PaletteTheme.Brush(PaletteTheme.BtnBorder);
    ApplyStarVisual(tool.Id, star, fromQuickPalette, false);
   };

   b.ToolTip = CreateToolTip(tool);
   b.Click += (s, e) => RunTool(tool);
   ApplyStarVisual(tool.Id, star, fromQuickPalette, false);
   return b;
  }

  /// <summary>Gui lenh cua tool xuong CAD.</summary>
  internal static void RunTool(TgToolInfo tool) {
   if (!ToolRunner.Run(tool.Cmd, tool.KeepSelection)) {
    ToolRunner.Notify("Khong gui duoc lenh " + tool.Id + " - hay mo ban ve roi bam lai nut.");
   }
  }

  /// <summary>
  /// Ve ★ theo trang thai ghim: da ghim = mau vang, ro 1.0; chua ghim = mo 0.45
  /// (hover len thi ro den 1.0). Kieu nay gui tinh nang pin ma khong loa nhieu.
  /// </summary>
  internal static void ApplyStarVisual(string id, TextBlock star, bool fromQuickPalette, bool hover) {
   bool pinned = PinService.Contains(id);
   star.Text = pinned ? "★" : "☆";
   star.Foreground = pinned ? PaletteTheme.Brush(PaletteTheme.Amber) : PaletteTheme.Brush(PaletteTheme.MutedText);
   star.Opacity = pinned ? 1 : (hover ? 1 : PaletteTheme.StarIdleOpacity);
   star.ToolTip = pinned
    ? "Bo ghim khoi Quick Tools (TGIRRQUICK)"
    : "Ghim vao Quick Tools - palette rieng luc nao cung san sang";
  }

  internal static ToolTip CreateToolTip(TgToolInfo tool) {
   Color accent = PaletteTheme.Accent(tool.Accent);
   var panel = new StackPanel { MaxWidth = 280 };
   // Hover chi hien ten lenh + cach dung ngan (yeu cau UI: nut chi co icon).
   string head = tool.Cmd;
   if (tool.Aliases != null && tool.Aliases.Length > 0) head += "  (" + string.Join(", ", tool.Aliases) + ")";
   panel.Children.Add(PaletteTheme.MakeText(head, 12, accent, true, new Thickness(0)));
   panel.Children.Add(PaletteTheme.MakeText(tool.TipDesc, 11, PaletteTheme.MainText, false, new Thickness(0, 3, 0, 0)));
   string usage = ShortUsage(tool);
   if (!string.IsNullOrEmpty(usage)) {
    panel.Children.Add(PaletteTheme.MakeText("Cách dùng: " + usage, 10.5, PaletteTheme.MutedText, false, new Thickness(0, 3, 0, 0)));
   }
   if (tool.RequiresSelection) {
    panel.Children.Add(PaletteTheme.MakeText("Chọn trước đối tượng rồi bấm nút", 10.5, PaletteTheme.DimText, false, new Thickness(0, 3, 0, 0)));
   }
   return new ToolTip {
    Background = PaletteTheme.Brush(PaletteTheme.BgDark),
    Foreground = PaletteTheme.Brush(PaletteTheme.MainText),
    BorderBrush = new SolidColorBrush(accent),
    BorderThickness = new Thickness(1),
    Padding = new Thickness(8, 6, 8, 7),
    Content = panel
   };
  }

  /// <summary>Cau cach dung ngan nhat (1 cau, toi da ~120 ky tu) cho tooltip va dong trang thai.</summary>
  internal static string ShortUsage(TgToolInfo tool) {
   string text = string.IsNullOrEmpty(tool.TipUsage) ? tool.TipDesc : tool.TipUsage;
   if (string.IsNullOrEmpty(text)) return "";
   int cut = text.IndexOf(". ");
   if (cut > 12) text = text.Substring(0, cut);
   text = text.Trim().TrimEnd('.');
   if (text.Length > 120) {
    text = text.Substring(0, 117);
    int space = text.LastIndexOf(' ');
    if (space > 60) text = text.Substring(0, space);
    text = text.TrimEnd(',', ';', ':') + "...";
   }
   return text;
  }

  /// <summary> ★ cua mot nut, giu WeakReference de cap nhat khi danh sach ghim doi.</summary>
  internal sealed class Star {
   readonly string id;
   readonly bool fromQuickPalette;
   readonly WeakReference<TextBlock> reference;

   internal Star(string id, TextBlock star, bool fromQuickPalette) {
    this.id = id;
    this.fromQuickPalette = fromQuickPalette;
    reference = new WeakReference<TextBlock>(star);
   }

   internal void Refresh() {
    TextBlock star;
    if (!reference.TryGetTarget(out star)) return;
    try { ApplyStarVisual(id, star, fromQuickPalette, false); } catch { }
   }
  }
 }
}
