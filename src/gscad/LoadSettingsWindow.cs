using System;
using System.Collections.Generic;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Media;
using System.Windows.Shapes;

namespace Tgirrr.CadLisp {
 /// <summary>
 /// Hop thoai TGIRRSETTINGS: bat/tat nap tung lenh (AutoLISP va .NET) cua TGIRR.
 /// Moi lan tick/bam nut la ghi file ngay (%APPDATA%\TGIRR\load-settings.txt), nen
 /// dong hop thoai bang X hay Esc deu khong lam mat thay doi.
 /// LISP da nap trong phien hien tai khong go duoc: thay doi ap dung tu lan
 /// khoi dong CAD ke tiep (hoac sau khi chay lai TGIRRLOAD).
 /// </summary>
 public sealed class LoadSettingsWindow : Window {
  readonly List<string> commands = new List<string>();
  readonly List<CheckBox> boxes = new List<CheckBox>();
  readonly TextBlock error = new TextBlock {
   Foreground = Fill(ErrorText),
   FontSize = 11,
   TextWrapping = TextWrapping.Wrap,
   Margin = new Thickness(0, 8, 0, 0),
   Visibility = Visibility.Collapsed
  };
  readonly TextBlock counter = new TextBlock {
   FontSize = 11,
   Foreground = Fill(TextDim),
   Margin = new Thickness(0, 10, 0, 0)
  };
  readonly TextBlock saved = new TextBlock {
   FontSize = 11,
   Foreground = Fill(OkText),
   Margin = new Thickness(0, 2, 0, 0),
   Text = "Đã lưu. Khởi động lại CAD (hoặc gõ TGIRRLOAD) để áp dụng."
  };
  bool loading = true;

  // Mau tuong minh: khong phu thuoc theme native cua CAD (theme sang lam chu
  // CheckBox thanh mau dam, chim vao nen toi cua hop thoai).
  static readonly Color PanelBg = Color.FromRgb(30, 41, 54);
  static readonly Color TextMain = Color.FromRgb(232, 240, 248);
  static readonly Color TextDim = Color.FromRgb(178, 194, 210);
  static readonly Color AccentCyan = Color.FromRgb(86, 190, 232);
  static readonly Color BoxBg = Color.FromRgb(22, 30, 41);
  static readonly Color BoxBorder = Color.FromRgb(96, 118, 145);
  static readonly Color ErrorText = Color.FromRgb(255, 138, 138);
  static readonly Color OkText = Color.FromRgb(126, 214, 150);

  static SolidColorBrush Fill(Color c) {
   var b = new SolidColorBrush(c);
   b.Freeze();
   return b;
  }

  public LoadSettingsWindow() {
   Title = "TGIRR — Cài đặt nạp Lệnh";
   Width = 560;
   SizeToContent = SizeToContent.Height;
   MaxHeight = 760;
   ResizeMode = ResizeMode.NoResize;
   WindowStartupLocation = WindowStartupLocation.CenterScreen;
   Background = Fill(PanelBg);
   Foreground = Fill(TextMain);
   FontFamily = new FontFamily("Segoe UI");
   Resources.Add(typeof(CheckBox), BuildCheckBoxStyle());

   var root = new StackPanel { Margin = new Thickness(16) };
   // To nen tuong minh cho toan bo noi dung: khong de lo mau nen cua CAD.
   Content = new Border {
    Background = Fill(PanelBg),
    Child = new ScrollViewer {
     Background = Fill(PanelBg),
     Content = root,
     VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
     HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled,
     MaxHeight = 700
    }
   };

   root.Children.Add(new TextBlock {
    Text = "BẬT / TẮT NẠP LỆNH",
    FontSize = 14,
    FontWeight = FontWeights.SemiBold,
    Foreground = Fill(AccentCyan),
    Margin = new Thickness(0, 0, 0, 6)
   });
   root.Children.Add(new TextBlock {
    Text = "Bỏ dấu lệnh không muốn nạp nếu trùng tên với bộ LISP khác. Mỗi lần tick là lưu ngay. " +
           "Tắt hết lệnh của một file thì file đó không được nạp. Lệnh đã nạp trong phiên hiện tại " +
           "không gỡ được — áp dụng từ lần khởi động CAD sau (hoặc gõ TGIRRLOAD).",
    FontSize = 11,
    Foreground = Fill(TextDim),
    TextWrapping = TextWrapping.Wrap,
    Margin = new Thickness(0, 0, 0, 10)
   });

   var quick = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(0, 0, 0, 4) };
   var all = Button("Chọn tất cả", false);
   all.Click += (s, e) => SetAll(true);
   var none = Button("Bỏ chọn hết", false);
   none.Click += (s, e) => SetAll(false);
   quick.Children.Add(all);
   quick.Children.Add(none);
   root.Children.Add(quick);

   foreach (TgToolCatalog.TgLoadUnit unit in TgToolCatalog.LoadUnits) {
    root.Children.Add(Section(unit.File, unit.Note));
    foreach (string command in unit.Commands) AddCommand(root, command, null);
   }

   // Lenh .NET: dang ky noi bo TGIRR<CMD>, shim LISP chi tao khi con bat.
   root.Children.Add(Section("TGIRR.Ribbon.dll (lệnh .NET)", "Tắt để nhường tên lệnh cho LISP khác (ví dụ TL)."));
   foreach (TgToolInfo tool in TgToolCatalog.ManagedTools()) AddCommand(root, tool.Id, tool.Label);

   root.Children.Add(counter);
   root.Children.Add(error);
   root.Children.Add(saved);

   var close = Button("Đóng", true);
   close.Click += (s, e) => { DialogResult = true; Close(); };
   var buttons = new StackPanel {
    Orientation = Orientation.Horizontal,
    HorizontalAlignment = HorizontalAlignment.Right,
    Margin = new Thickness(0, 12, 0, 0)
   };
   buttons.Children.Add(close);
   root.Children.Add(buttons);

   loading = false;
   UpdateCounter();
   SavedVisible(false);
   Loaded += (s, e) => close.Focus();
  }

  /// <summary>
  /// Template CheckBox tu ve: chu luon mau sang, o tick nen toi + vien ro.
  /// Dung vi template native cua CAD an theo theme (chu den tren nen toi).
  /// </summary>
  static Style BuildCheckBoxStyle() {
   var style = new Style(typeof(CheckBox));

   var panel = new FrameworkElementFactory(typeof(StackPanel));
   panel.SetValue(StackPanel.OrientationProperty, Orientation.Horizontal);

   var box = new FrameworkElementFactory(typeof(Border));
   box.Name = "box";
   box.SetValue(Border.WidthProperty, 15.0);
   box.SetValue(Border.HeightProperty, 15.0);
   box.SetValue(Border.CornerRadiusProperty, new CornerRadius(3));
   box.SetValue(Border.BackgroundProperty, Fill(BoxBg));
   box.SetValue(Border.BorderBrushProperty, Fill(BoxBorder));
   box.SetValue(Border.BorderThicknessProperty, new Thickness(1));
   box.SetValue(FrameworkElement.VerticalAlignmentProperty, VerticalAlignment.Center);

   var mark = new FrameworkElementFactory(typeof(TextBlock));
   mark.Name = "mark";
   mark.SetValue(TextBlock.TextProperty, "\u2713");
   mark.SetValue(TextBlock.FontSizeProperty, 11.0);
   mark.SetValue(TextBlock.FontWeightProperty, FontWeights.Bold);
   mark.SetValue(TextBlock.ForegroundProperty, Fill(Color.FromRgb(15, 23, 42)));
   mark.SetValue(FrameworkElement.HorizontalAlignmentProperty, HorizontalAlignment.Center);
   mark.SetValue(FrameworkElement.VerticalAlignmentProperty, VerticalAlignment.Center);
   mark.SetValue(UIElement.VisibilityProperty, Visibility.Collapsed);
   box.AppendChild(mark);
   panel.AppendChild(box);

   var content = new FrameworkElementFactory(typeof(ContentPresenter));
   content.SetValue(FrameworkElement.MarginProperty, new Thickness(7, 0, 0, 0));
   content.SetValue(FrameworkElement.VerticalAlignmentProperty, VerticalAlignment.Center);
   panel.AppendChild(content);

   var template = new ControlTemplate(typeof(CheckBox)) { VisualTree = panel };
   // TargetName chi hop le trong ControlTemplate.Triggers (khong phai Style.Triggers).
   var on = new Trigger { Property = ToggleButton.IsCheckedProperty, Value = true };
   on.Setters.Add(new Setter(Border.BackgroundProperty, Fill(AccentCyan), "box"));
   on.Setters.Add(new Setter(Border.BorderBrushProperty, Fill(AccentCyan), "box"));
   on.Setters.Add(new Setter(UIElement.VisibilityProperty, Visibility.Visible, "mark"));
   template.Triggers.Add(on);

   var hover = new Trigger { Property = UIElement.IsMouseOverProperty, Value = true };
   hover.Setters.Add(new Setter(Border.BorderBrushProperty, Fill(AccentCyan), "box"));
   template.Triggers.Add(hover);

   style.Setters.Add(new Setter(Control.ForegroundProperty, Fill(TextMain)));
   style.Setters.Add(new Setter(Control.BackgroundProperty, Brushes.Transparent));
   style.Setters.Add(new Setter(Control.FocusVisualStyleProperty, null));
   style.Setters.Add(new Setter(Control.PaddingProperty, new Thickness(0, 2, 0, 2)));
   style.Setters.Add(new Setter(Control.CursorProperty, System.Windows.Input.Cursors.Hand));
   style.Setters.Add(new Setter(Control.TemplateProperty, template));
   return style;
  }

  static TextBlock Section(string title, string note) {
   return new TextBlock {
    Text = title + (string.IsNullOrEmpty(note) ? "" : "  •  " + note),
    FontSize = 10.5,
    FontWeight = FontWeights.SemiBold,
    Foreground = Fill(AccentCyan),
    Margin = new Thickness(0, 9, 0, 2),
    TextWrapping = TextWrapping.Wrap
   };
  }

  void AddCommand(StackPanel root, string command, string label) {
   TgToolInfo tool = TgToolCatalog.Find(command);
   string text = string.IsNullOrEmpty(label) ? (tool == null ? command : command + " — " + tool.Label)
    : command + " — " + label;
   var cb = new CheckBox {
    Content = text,
    IsChecked = LoadSettingsStore.IsEnabled(command),
    FontSize = 12,
    Margin = new Thickness(14, 3, 0, 0),
    ToolTip = tool == null ? command : ShortTip(command, tool)
   };
   cb.Checked += (s, e) => OnToggled();
   cb.Unchecked += (s, e) => OnToggled();
   commands.Add(command);
   boxes.Add(cb);
   root.Children.Add(cb);
  }

  static string ShortTip(string command, TgToolInfo tool) {
   string usage = ToolChip.ShortUsage(tool);
   return string.IsNullOrEmpty(usage) ? command : command + " — " + usage;
  }

  /// <summary>Template nut tu ve: nen/phu deu tuong minh, khong an theo theme CAD.</summary>
  static readonly ControlTemplate ButtonTemplate = BuildButtonTemplate();

  static ControlTemplate BuildButtonTemplate() {
   var border = new FrameworkElementFactory(typeof(Border));
   border.SetValue(Border.CornerRadiusProperty, new CornerRadius(4));
   border.SetValue(Border.BackgroundProperty, new TemplateBindingExtension(Control.BackgroundProperty));
   border.SetValue(Border.BorderBrushProperty, new TemplateBindingExtension(Control.BorderBrushProperty));
   border.SetValue(Border.BorderThicknessProperty, new TemplateBindingExtension(Control.BorderThicknessProperty));
   border.SetValue(Border.PaddingProperty, new TemplateBindingExtension(Control.PaddingProperty));
   var cp = new FrameworkElementFactory(typeof(ContentPresenter));
   cp.SetValue(FrameworkElement.HorizontalAlignmentProperty, HorizontalAlignment.Center);
   cp.SetValue(FrameworkElement.VerticalAlignmentProperty, VerticalAlignment.Center);
   border.AppendChild(cp);
   return new ControlTemplate(typeof(Button)) { VisualTree = border };
  }

  static Button Button(string text, bool accent) {
   var b = new Button {
    Content = text,
    MinWidth = 92,
    Padding = new Thickness(10, 4, 10, 4),
    Margin = new Thickness(0, 0, 8, 0),
    FontSize = 12,
    Template = ButtonTemplate,
    Background = Fill(accent ? AccentCyan : Color.FromRgb(52, 66, 86)),
    Foreground = Fill(accent ? Color.FromRgb(15, 23, 42) : Colors.White),
    BorderThickness = new Thickness(0),
    FocusVisualStyle = null,
    Cursor = System.Windows.Input.Cursors.Hand,
    FontWeight = accent ? FontWeights.SemiBold : FontWeights.Normal
   };
   return b;
  }

  void SetAll(bool value) {
   loading = true;
   foreach (CheckBox cb in boxes) cb.IsChecked = value;
   loading = false;
   OnToggled();
  }

  /// <summary>Ghi file ngay moi lan thay doi (khong can nut Luu).</summary>
  void OnToggled() {
   if (loading) return;
   UpdateCounter();
   if (!LoadSettingsStore.Save(CurrentDisabled())) {
    error.Text = "Không ghi được file cài đặt. Kiểm tra quyền ghi thư mục %APPDATA%\\TGIRR.";
    error.Visibility = Visibility.Visible;
    SavedVisible(false);
    return;
   }
   error.Visibility = Visibility.Collapsed;
   SavedVisible(true);
  }

  List<string> CurrentDisabled() {
   var disabled = new List<string>();
   for (int i = 0; i < commands.Count; i++) {
    if (boxes[i].IsChecked != true) disabled.Add(commands[i]);
   }
   return disabled;
  }

  void SavedVisible(bool visible) {
   saved.Visibility = visible ? Visibility.Visible : Visibility.Collapsed;
  }

  void UpdateCounter() {
   int on = 0;
   foreach (CheckBox cb in boxes) if (cb.IsChecked == true) on++;
   counter.Text = "Đang bật " + on + "/" + boxes.Count + " lệnh" + (on == boxes.Count ? "  (mặc định)" : "");
   if (on == 0) {
    error.Text = "Không lệnh nào được bật — TGIRR sẽ không nạp gì sau khi khởi động lại CAD.";
    error.Visibility = Visibility.Visible;
   } else if (error.Text.StartsWith("Không lệnh nào")) {
    error.Visibility = Visibility.Collapsed;
   }
  }
 }
}
