using System;
using System.Collections.Generic;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;

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
   Foreground = new SolidColorBrush(Color.FromRgb(240, 120, 120)),
   FontSize = 11,
   TextWrapping = TextWrapping.Wrap,
   Margin = new Thickness(0, 8, 0, 0),
   Visibility = Visibility.Collapsed
  };
  readonly TextBlock counter = new TextBlock {
   FontSize = 11,
   Foreground = new SolidColorBrush(Color.FromRgb(150, 170, 190)),
   Margin = new Thickness(0, 10, 0, 0)
  };
  readonly TextBlock saved = new TextBlock {
   FontSize = 11,
   Foreground = new SolidColorBrush(Color.FromRgb(120, 200, 140)),
   Margin = new Thickness(0, 2, 0, 0),
   Text = "Đã lưu. Khởi động lại CAD (hoặc gõ TGIRRLOAD) để áp dụng."
  };
  bool loading = true;

  public LoadSettingsWindow() {
   Title = "TGIRR — Cài đặt nạp Lệnh";
   Width = 560;
   SizeToContent = SizeToContent.Height;
   MaxHeight = 760;
   ResizeMode = ResizeMode.NoResize;
   WindowStartupLocation = WindowStartupLocation.CenterScreen;
   Background = new SolidColorBrush(Color.FromRgb(36, 45, 57));
   Foreground = Brushes.White;
   FontFamily = new FontFamily("Segoe UI");

   var root = new StackPanel { Margin = new Thickness(16) };
   Content = new ScrollViewer {
    Content = root,
    VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
    HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled,
    MaxHeight = 700
   };

   root.Children.Add(new TextBlock {
    Text = "BẬT / TẮT NẠP LỆNH",
    FontSize = 14,
    FontWeight = FontWeights.SemiBold,
    Foreground = new SolidColorBrush(Color.FromRgb(86, 190, 232)),
    Margin = new Thickness(0, 0, 0, 6)
   });
   root.Children.Add(new TextBlock {
    Text = "Bỏ dấu lệnh không muốn nạp nếu trùng tên với bộ LISP khác. Mỗi lần tick là lưu ngay. " +
           "Tắt hết lệnh của một file thì file đó không được nạp. Lệnh đã nạp trong phiên hiện tại " +
           "không gỡ được — áp dụng từ lần khởi động CAD sau (hoặc gõ TGIRRLOAD).",
    FontSize = 11,
    Foreground = new SolidColorBrush(Color.FromRgb(170, 185, 200)),
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

  static TextBlock Section(string title, string note) {
   return new TextBlock {
    Text = title + (string.IsNullOrEmpty(note) ? "" : "  •  " + note),
    FontSize = 10.5,
    FontWeight = FontWeights.SemiBold,
    Foreground = new SolidColorBrush(Color.FromRgb(120, 200, 240)),
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

  static Button Button(string text, bool accent) {
   var b = new Button {
    Content = text,
    MinWidth = 92,
    Padding = new Thickness(10, 4, 10, 4),
    Margin = new Thickness(0, 0, 8, 0),
    FontSize = 12,
    Background = new SolidColorBrush(accent ? Color.FromRgb(56, 189, 248) : Color.FromRgb(52, 66, 86)),
    Foreground = new SolidColorBrush(accent ? Color.FromRgb(15, 23, 42) : Colors.White),
    BorderThickness = new Thickness(0),
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
