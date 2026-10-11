using System;
using System.Collections.Generic;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Shapes;

namespace Tgirrr.CadLisp {
 /// <summary>
 /// Tema dark + style dung chung cho palette, Quick Tools va tooltip.
 /// File nay khong dung API CAD nen duoc copy nguyen van sang moi host.
 /// </summary>
 internal static class PaletteTheme {
  internal static readonly Color BgDark = Color.FromRgb(24, 32, 43);
  internal static readonly Color CardBg = Color.FromRgb(30, 41, 54);
  internal static readonly Color CardBorder = Color.FromRgb(46, 61, 79);
  internal static readonly Color BtnNormalBg = Color.FromRgb(36, 49, 66);
  internal static readonly Color BtnHoverBg = Color.FromRgb(48, 65, 88);
  internal static readonly Color BtnBorder = Color.FromRgb(50, 68, 90);
  internal static readonly Color MutedText = Color.FromRgb(157, 174, 192);
  internal static readonly Color DimText = Color.FromRgb(100, 116, 139);
  internal static readonly Color MainText = Color.FromRgb(240, 244, 248);
  internal static readonly Color Cyan = Color.FromRgb(56, 189, 248);
  internal static readonly Color Green = Color.FromRgb(52, 211, 153);
  internal static readonly Color Amber = Color.FromRgb(251, 191, 36);
  internal static readonly Color AccentInk = Color.FromRgb(15, 23, 42);

  /// <summary>Bep rung toi thieu de xep 2 cot nut; duoi muc nay xe 1 cot cho de doc.</summary>
  internal const int TwoColumnWidth = 300;

  /// <summary>★ khi chua ghim van hien (moc nho) de nguoi dung biet nut co the pin (F6).</summary>
  internal const double StarIdleOpacity = 0.45;

  internal static Color Accent(TgToolAccent a) {
   switch (a) {
    case TgToolAccent.Green: return Green;
    case TgToolAccent.Amber: return Amber;
    default: return Cyan;
   }
  }

  internal static Brush Brush(Color c) {
   var b = new SolidColorBrush(c);
   b.Freeze();
   return b;
  }

  internal static Brush Alpha(Color c, byte a) {
   var b = new SolidColorBrush(Color.FromArgb(a, c.R, c.G, c.B));
   b.Freeze();
   return b;
  }

  internal static readonly ControlTemplate ChipTemplate = CreateChipTemplate();

  static ControlTemplate CreateChipTemplate() {
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

  internal static Button MakeHeaderButton(string text, string tip, Brush foreground) {
   var b = new Button {
    Template = ChipTemplate,
    Content = text,
    FontSize = 10.5,
    Foreground = foreground,
    Background = Brush(Color.FromRgb(32, 43, 58)),
    BorderBrush = Brush(CardBorder),
    BorderThickness = new Thickness(1),
    Padding = new Thickness(6, 2, 6, 2),
    Cursor = Cursors.Hand,
    ToolTip = tip,
    FocusVisualStyle = null
   };
   b.MouseEnter += (s, e) => {
    b.Foreground = Brushes.White;
    b.BorderBrush = Brush(Cyan);
   };
   b.MouseLeave += (s, e) => {
    b.Foreground = foreground;
    b.BorderBrush = Brush(CardBorder);
   };
   return b;
  }

  internal static TextBlock MakeText(string text, double size, Color color, bool bold, Thickness margin) {
   var t = new TextBlock {
    Text = text,
    FontSize = size,
    FontWeight = bold ? FontWeights.SemiBold : FontWeights.Normal,
    Foreground = Brush(color),
    Margin = margin,
    TextWrapping = TextWrapping.Wrap
   };
   return t;
  }
 }

 /// <summary>
 /// Mot nut lenh (chip) dung chung cho palette chinh, Quick Tools va Ribbon:
 /// nhan, tooltip, ★ deu lay tu TgToolCatalog nen khong the lech giua cac nen CAD.
 /// </summary>
 internal static class ToolChip {
  internal static Button Create(TgToolInfo tool, bool fromQuickPalette, List<ToolChip.Star> stars) {
   Color accent = PaletteTheme.Accent(tool.Accent);
   var b = new Button {
    Template = PaletteTheme.ChipTemplate,
    Height = 31,
    HorizontalAlignment = HorizontalAlignment.Stretch,
    HorizontalContentAlignment = HorizontalAlignment.Left,
    VerticalContentAlignment = VerticalAlignment.Center,
    Background = PaletteTheme.Brush(PaletteTheme.BtnNormalBg),
    BorderBrush = PaletteTheme.Brush(PaletteTheme.BtnBorder),
    BorderThickness = new Thickness(1),
    Padding = new Thickness(5, 2, 5, 2),
    Cursor = Cursors.Hand,
    FocusVisualStyle = null,
    Tag = tool.Id
   };

   var dock = new DockPanel { LastChildFill = true };

   var badge = new Border {
    Background = PaletteTheme.Alpha(accent, 38),
    BorderBrush = PaletteTheme.Alpha(accent, 120),
    BorderThickness = new Thickness(1),
    CornerRadius = new CornerRadius(3),
    Padding = new Thickness(3, 1, 3, 1),
    VerticalAlignment = VerticalAlignment.Center,
    MinWidth = 36
   };
   badge.Child = new TextBlock {
    Text = tool.Badge,
    Foreground = new SolidColorBrush(accent),
    FontSize = 10.5,
    FontWeight = FontWeights.Bold,
    TextAlignment = TextAlignment.Center
   };
   DockPanel.SetDock(badge, Dock.Left);
   dock.Children.Add(badge);

   var star = new TextBlock {
    FontSize = 12,
    Background = Brushes.Transparent,
    VerticalAlignment = VerticalAlignment.Center,
    Margin = new Thickness(0, 0, 2, 0),
    Cursor = Cursors.Hand
   };
   star.PreviewMouseLeftButtonDown += (s, e) => e.Handled = true;
   star.PreviewMouseLeftButtonUp += (s, e) => {
    e.Handled = true;
    PinService.Toggle(tool.Id);
   };
   DockPanel.SetDock(star, Dock.Right);
   dock.Children.Add(star);
   if (stars != null) stars.Add(new ToolChip.Star(tool.Id, star, fromQuickPalette));

   dock.Children.Add(new TextBlock {
    Text = tool.Label,
    Foreground = PaletteTheme.Brush(PaletteTheme.MainText),
    FontSize = 11,
    FontWeight = FontWeights.SemiBold,
    Margin = new Thickness(5, 0, 0, 0),
    VerticalAlignment = VerticalAlignment.Center,
    TextTrimming = TextTrimming.CharacterEllipsis
   });
   b.Content = dock;

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
   panel.Children.Add(PaletteTheme.MakeText(tool.TipTitle, 11.5, accent, true, new Thickness(0)));
   panel.Children.Add(PaletteTheme.MakeText(tool.TipDesc, 11, PaletteTheme.MainText, false, new Thickness(0, 3, 0, 0)));
   if (!string.IsNullOrEmpty(tool.TipUsage)) {
    panel.Children.Add(PaletteTheme.MakeText(tool.TipUsage, 10.5, PaletteTheme.MutedText, false, new Thickness(0, 3, 0, 0)));
   }
   string tail = tool.TipCommand;
   if (tool.RequiresSelection) {
    tail = (string.IsNullOrEmpty(tail) ? "" : tail + "  \u2022  ") + "Chon truoc doi tuong roi bam nut";
   }
   if (!string.IsNullOrEmpty(tail)) {
    panel.Children.Add(PaletteTheme.MakeText(tail, 10.5, PaletteTheme.DimText, false, new Thickness(0, 3, 0, 0)));
   }
   if (tool.Aliases != null && tool.Aliases.Length > 0) {
    panel.Children.Add(PaletteTheme.MakeText("Biet danh: " + string.Join(", ", tool.Aliases) + "  (gõ trực tiếp được)",
     10.5, PaletteTheme.DimText, false, new Thickness(0, 3, 0, 0)));
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

 /// <summary>
 /// Noi dung palette chinh TGIRR CAD: header (thuong hieu, ⚡ Quick Tools, ⟳ Nạp lại),
 /// o tim lenh, cac nhom nut co the thu gon + dong trang thai.
 /// Toan bo nut sinh tu TgToolCatalog cho host dang chay.
 /// </summary>
 public sealed class PaletteContent : UserControl {
  readonly string host = CadHost.Name;
  readonly List<ToolChip.Star> stars = new List<ToolChip.Star>();
  readonly HashSet<string> collapsed = GroupCollapseStore.Load();
  readonly StackPanel body = new StackPanel();
  readonly StackPanel root = new StackPanel { Margin = new Thickness(10, 8, 10, 8) };
  TextBox search;
  TextBlock hint;
  TextBlock status;
  string filter = "";
  int columns = 2;
  bool rebuilding;

  public PaletteContent() {
   Background = PaletteTheme.Brush(PaletteTheme.BgDark);
   root.Children.Add(BuildHeader());
   root.Children.Add(BuildSearchBox());
   root.Children.Add(body);
   root.Children.Add(BuildStatusLine());
   Content = new ScrollViewer {
    Content = root,
    VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
    HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled
   };
   columns = PickColumns(ActualWidth);
   SizeChanged += OnWidthChanged;
   RebuildBody();
   // Palette Quick Tools cung co the doi ★ -> view nay phai theo (F3).
   PinService.Changed += RefreshPins;
   PreviewKeyDown += OnKeyDown;
  }

  static int PickColumns(double width) {
   return width >= PaletteTheme.TwoColumnWidth ? 2 : 1;
  }

  void OnWidthChanged(object sender, SizeChangedEventArgs e) {
   int next = PickColumns(e.NewSize.Width);
   if (next == columns) return;
   columns = next;
   RebuildBody();
  }

  void OnKeyDown(object sender, KeyEventArgs e) {
   bool ctrl = (Keyboard.Modifiers & ModifierKeys.Control) == ModifierKeys.Control;
   if (ctrl && e.Key == Key.F) {
    if (search != null) { search.Focus(); search.SelectAll(); }
    e.Handled = true;
   } else if (e.Key == Key.Escape && search != null && search.IsKeyboardFocusWithin && filter.Length > 0) {
    search.Text = "";
    e.Handled = true;
   }
  }

  // ----- Header --------------------------------------------------------------
  FrameworkElement BuildHeader() {
   var dock = new DockPanel { Margin = new Thickness(2, 2, 2, 6), LastChildFill = true };

   var left = new StackPanel { Orientation = Orientation.Horizontal, VerticalAlignment = VerticalAlignment.Center };
   var logo = new Border {
    Background = PaletteTheme.Brush(PaletteTheme.Cyan),
    CornerRadius = new CornerRadius(3),
    Padding = new Thickness(4, 1, 4, 1),
    Margin = new Thickness(0, 0, 6, 0)
   };
   logo.Child = new TextBlock {
    Text = "TG",
    FontSize = 10.5,
    FontWeight = FontWeights.Bold,
    Foreground = PaletteTheme.Brush(PaletteTheme.AccentInk)
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

   var right = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right };
   var quickBtn = PaletteTheme.MakeHeaderButton("⚡ Quick", "Mở/đóng palette Quick Tools riêng (TGIRRQUICK)",
    PaletteTheme.Brush(PaletteTheme.MutedText));
   quickBtn.Click += (s, e) => ToolRunner.Run("TGIRRQUICK", true);
   var reloadBtn = PaletteTheme.MakeHeaderButton("⟳ Nạp lại", "Nạp lại toàn bộ Lisp + plugin (" + CadHost.ReloadCommand + ")",
    PaletteTheme.Brush(PaletteTheme.MutedText));
   reloadBtn.Click += (s, e) => ToolRunner.Run(CadHost.ReloadCommand, false);
   right.Children.Add(quickBtn);
   right.Children.Add(new TextBlock { Text = " ", FontSize = 10.5 });
   right.Children.Add(reloadBtn);
   DockPanel.SetDock(right, Dock.Right);

   dock.Children.Add(left);
   dock.Children.Add(right);
   return dock;
  }

  // ----- O tim lenh ----------------------------------------------------------
  FrameworkElement BuildSearchBox() {
   var box = new Border {
    Background = PaletteTheme.Brush(PaletteTheme.CardBg),
    BorderBrush = PaletteTheme.Brush(PaletteTheme.CardBorder),
    BorderThickness = new Thickness(1),
    CornerRadius = new CornerRadius(4),
    Padding = new Thickness(6, 3, 6, 3),
    Margin = new Thickness(0, 0, 0, 7)
   };
   var grid = new Grid();
   grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
   grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });

   var glass = new TextBlock {
    Text = "⌕",
    FontSize = 12,
    Foreground = PaletteTheme.Brush(PaletteTheme.DimText),
    VerticalAlignment = VerticalAlignment.Center,
    Margin = new Thickness(0, 0, 5, 0)
   };
   Grid.SetColumn(glass, 0);
   grid.Children.Add(glass);

   search = new TextBox {
    Background = Brushes.Transparent,
    Foreground = PaletteTheme.Brush(PaletteTheme.MainText),
    CaretBrush = PaletteTheme.Brush(PaletteTheme.MainText),
    BorderThickness = new Thickness(0),
    FontSize = 11.5,
    VerticalContentAlignment = VerticalAlignment.Center,
    AcceptsReturn = false
   };
   hint = new TextBlock {
    Text = "Tìm lệnh (mã, tên, biệt danh)...  Ctrl+F",
    FontSize = 11.5,
    Foreground = PaletteTheme.Brush(PaletteTheme.DimText),
    IsHitTestVisible = false,
    VerticalAlignment = VerticalAlignment.Center
   };
   var stack = new Grid();
   stack.Children.Add(search);
   stack.Children.Add(hint);
   Grid.SetColumn(stack, 1);
   grid.Children.Add(stack);

   search.TextChanged += (s, e) => {
    filter = (search.Text ?? "").Trim();
    UpdateHint();
    RebuildBody();
   };
   search.GotKeyboardFocus += (s, e) => UpdateHint();
   search.LostKeyboardFocus += (s, e) => UpdateHint();
   search.PreviewKeyDown += (s, e) => {
    if (e.Key == Key.Enter) { RunFirstMatch(); e.Handled = true; }
   };
   UpdateHint();

   box.Child = grid;
   return box;
  }

  void UpdateHint() {
   if (hint == null || search == null) return;
   hint.Visibility = (search.Text.Length == 0 && !search.IsKeyboardFocusWithin)
    ? Visibility.Visible : Visibility.Collapsed;
  }

  void RunFirstMatch() {
   foreach (TgToolInfo t in TgToolCatalog.ForHost(host)) {
    if (Matches(t)) { ToolChip.RunTool(t); return; }
   }
  }

  // ----- Body theo catalog ---------------------------------------------------
  bool Matches(TgToolInfo t) {
   if (filter.Length == 0) return true;
   string q = filter.ToLowerInvariant();
   if (t.Id.ToLowerInvariant().Contains(q)) return true;
   if (t.Label != null && t.Label.ToLowerInvariant().Contains(q)) return true;
   if (t.TipTitle != null && t.TipTitle.ToLowerInvariant().Contains(q)) return true;
   if (t.TipDesc != null && t.TipDesc.ToLowerInvariant().Contains(q)) return true;
   foreach (string alias in t.Aliases) {
    if (!string.IsNullOrEmpty(alias) && alias.ToLowerInvariant().Contains(q)) return true;
   }
   return false;
  }

  void RebuildBody() {
   rebuilding = true;
   body.Children.Clear();
   stars.Clear();
   foreach (string key in TgToolCatalog.GroupKeys(host)) {
    TgToolInfo[] all = TgToolCatalog.ForGroup(host, key);
    var visible = new List<TgToolInfo>();
    foreach (TgToolInfo t in all) if (Matches(t)) visible.Add(t);
    if (visible.Count == 0) continue;
    bool isOpen = filter.Length > 0 || !collapsed.Contains(key);
    body.Children.Add(BuildGroup(key, all[0].GroupTitle, PaletteTheme.Accent(all[0].Accent), visible, isOpen));
   }
   if (body.Children.Count == 0) {
    body.Children.Add(new TextBlock {
     Text = "Không tìm thấy lệnh nào khớp \u201c" + filter + "\u201d. Xoá ô tìm để xem đủ danh mục.",
     Foreground = PaletteTheme.Brush(PaletteTheme.DimText),
     FontSize = 11,
     TextWrapping = TextWrapping.Wrap,
     Margin = new Thickness(4, 2, 4, 6)
    });
   }
   RefreshPins();
   ResetStatus();
   rebuilding = false;
  }

  Button Chip(TgToolInfo tool) {
   var b = ToolChip.Create(tool, false, stars);
   b.MouseEnter += (s, e) => ShowToolStatus(tool);
   b.MouseLeave += (s, e) => ResetStatus();
   return b;
  }

  void ShowToolStatus(TgToolInfo tool) {
   if (status == null || rebuilding) return;
   string line = tool.TipTitle;
   if (tool.RequiresSelection) line += "  \u2022  nên chọn trước đối tượng";
   else if (tool.Aliases != null && tool.Aliases.Length > 0) line += "  \u2022  biệt danh: " + string.Join(", ", tool.Aliases);
   status.Text = line;
  }

  FrameworkElement BuildGroup(string key, string title, Color accent, List<TgToolInfo> tools, bool isOpen) {
   var card = new Border {
    Background = PaletteTheme.Brush(PaletteTheme.CardBg),
    BorderBrush = PaletteTheme.Brush(PaletteTheme.CardBorder),
    BorderThickness = new Thickness(1),
    CornerRadius = new CornerRadius(5),
    Padding = new Thickness(6, 4, 6, 6),
    Margin = new Thickness(0, 0, 0, 6)
   };
   var panel = new StackPanel();

   var header = new Button {
    Template = PaletteTheme.ChipTemplate,
    Background = Brushes.Transparent,
    BorderBrush = Brushes.Transparent,
    BorderThickness = new Thickness(0),
    Padding = new Thickness(1, 2, 1, 3),
    Cursor = Cursors.Hand,
    HorizontalContentAlignment = HorizontalAlignment.Left,
    FocusVisualStyle = null,
    ToolTip = isOpen ? "Thu gọn nhóm này" : "Mở rộng nhóm này"
   };
   var headerRow = new StackPanel { Orientation = Orientation.Horizontal };
   headerRow.Children.Add(new TextBlock {
    Text = isOpen ? "▾" : "▸",
    FontSize = 10,
    Width = 12,
    Foreground = PaletteTheme.Brush(PaletteTheme.DimText),
    VerticalAlignment = VerticalAlignment.Center
   });
   headerRow.Children.Add(new Rectangle {
    Width = 3,
    Height = 11,
    Fill = new SolidColorBrush(accent),
    Margin = new Thickness(2, 0, 5, 0),
    VerticalAlignment = VerticalAlignment.Center
   });
   headerRow.Children.Add(new TextBlock {
    Text = title,
    FontSize = 10.5,
    FontWeight = FontWeights.SemiBold,
    Foreground = new SolidColorBrush(accent),
    VerticalAlignment = VerticalAlignment.Center
   });
   headerRow.Children.Add(new TextBlock {
    Text = " (" + tools.Count + ")",
    FontSize = 10,
    Foreground = PaletteTheme.Brush(PaletteTheme.DimText),
    VerticalAlignment = VerticalAlignment.Center
   });
   header.Content = headerRow;
   header.Click += (s, e) => {
    if (collapsed.Contains(key)) collapsed.Remove(key);
    else collapsed.Add(key);
    GroupCollapseStore.Save(collapsed);
    RebuildBody();
   };
   panel.Children.Add(header);

   var groupBody = new StackPanel { Visibility = isOpen ? Visibility.Visible : Visibility.Collapsed };
   for (int i = 0; i < tools.Count; i += columns) {
    if (columns == 2 && i + 1 < tools.Count) {
     var grid = new Grid { Margin = new Thickness(0, 0, 0, 3) };
     grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
     grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
     var b1 = Chip(tools[i]);
     b1.Margin = new Thickness(0, 0, 2, 0);
     grid.Children.Add(b1);
     Grid.SetColumn(b1, 0);
     var b2 = Chip(tools[i + 1]);
     b2.Margin = new Thickness(2, 0, 0, 0);
     grid.Children.Add(b2);
     Grid.SetColumn(b2, 1);
     groupBody.Children.Add(grid);
    } else {
     var b = Chip(tools[i]);
     b.Margin = new Thickness(0, 0, 0, 3);
     groupBody.Children.Add(b);
    }
   }
   panel.Children.Add(groupBody);
   card.Child = panel;
   return card;
  }

  // ----- Dong trang thai -----------------------------------------------------
  FrameworkElement BuildStatusLine() {
   status = new TextBlock {
    Text = " ",
    Foreground = PaletteTheme.Brush(PaletteTheme.DimText),
    FontSize = 10.5,
    TextAlignment = TextAlignment.Center,
    TextWrapping = TextWrapping.Wrap,
    Margin = new Thickness(0, 2, 0, 2)
   };
   return status;
  }

  void ResetStatus() {
   if (status == null || rebuilding) return;
   status.Text = TgToolCatalog.ForHost(host).Length + " lệnh \u2022 " + PinService.Count +
    " đã ghim Quick Tools \u2022 Ctrl+F tìm \u2022 bấm ★ để ghim";
  }

  /// <summary>Goi khi danh sách ghim đổi ở nơi khác (Quick Tools) để ★ không lệch (F3).</summary>
  internal void RefreshPins() {
   for (int i = stars.Count - 1; i >= 0; i--) stars[i].Refresh();
   if (!rebuilding) ResetStatus();
  }
 }

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
    b.Height = 27;
    b.MinWidth = 120;
    b.Margin = new Thickness(0, 0, 4, 4);
    b.HorizontalAlignment = HorizontalAlignment.Left;
    panel.Children.Add(b);
   }
   empty.Visibility = tools.Count == 0 ? Visibility.Visible : Visibility.Collapsed;
  }
 }
}
