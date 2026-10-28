using System.Collections.Generic;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Shapes;

namespace Tgirrr.CadLisp {
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
   RebuildBody();
   // Palette Quick Tools cung co the doi ★ -> view nay phai theo (F3).
   PinService.Changed += RefreshPins;
   PreviewKeyDown += OnKeyDown;
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
    var settingsBtn = PaletteTheme.MakeHeaderButton("⚙", "Bật/tắt nạp từng LISP (TGIRRSETTINGS) — tránh xung đột với LISP khác",
    PaletteTheme.Brush(PaletteTheme.MutedText));
    settingsBtn.Click += (s, e) => ToolRunner.Run("TGIRRSETTINGS", true);
    var reloadBtn = PaletteTheme.MakeHeaderButton("⟳ Nạp lại", "Nạp lại toàn bộ Lisp + plugin (" + CadHost.ReloadCommand + ")",
     PaletteTheme.Brush(PaletteTheme.MutedText));
    reloadBtn.Click += (s, e) => ToolRunner.Run(CadHost.ReloadCommand, false);
    right.Children.Add(quickBtn);
    right.Children.Add(new TextBlock { Text = " ", FontSize = 10.5 });
    right.Children.Add(settingsBtn);
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
   string line = tool.Cmd + " \u2014 " + ToolChip.ShortUsage(tool);
   if (tool.RequiresSelection) line += "  \u2022  nên chọn trước đối tượng";
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

   var groupBody = new WrapPanel {
    Orientation = Orientation.Horizontal,
    Visibility = isOpen ? Visibility.Visible : Visibility.Collapsed,
    Margin = new Thickness(0, 2, 0, 0)
   };
   foreach (TgToolInfo tool in tools) {
    Button b = Chip(tool);
    b.Margin = new Thickness(0, 0, 4, 4);
    groupBody.Children.Add(b);
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
}
