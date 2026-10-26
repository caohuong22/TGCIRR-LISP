using System;
using System.Globalization;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;

namespace Tgirrr.CadLisp {
 /// <summary>Hop thoai TGN: pham vi, quy luat so, kich thuoc nhan va thu tu danh so.</summary>
 public sealed class NumberingWindow : Window {
  readonly RadioButton objects = new RadioButton { Content = "Đối tượng được chọn", IsChecked = true, Margin = new Thickness(0, 2, 0, 2) };
  readonly RadioButton regions = new RadioButton { Content = "Vùng tưới (Polyline kín / Circle)", Margin = new Thickness(0, 2, 0, 2) };
  readonly TextBox start, step, width, height, textHeight;
  readonly ComboBox order = new ComboBox { Margin = new Thickness(0, 2, 0, 0), Padding = new Thickness(5, 3, 5, 3) };
  readonly TextBlock error = new TextBlock { Foreground = new SolidColorBrush(Color.FromRgb(240, 120, 120)), TextWrapping = TextWrapping.Wrap, Margin = new Thickness(0, 8, 0, 0) };
  internal NumberSettings Settings;

  internal NumberingWindow(NumberSettings current) {
   NumberSettings value = current ?? new NumberSettings();
   Title = "TGIRR — Đánh số đối tượng / vùng tưới";
   Width = 560;
   Height = 500;
   MinWidth = 520;
   MinHeight = 460;
   WindowStartupLocation = WindowStartupLocation.CenterScreen;
   ResizeMode = ResizeMode.CanResizeWithGrip;
   Background = new SolidColorBrush(Color.FromRgb(36, 45, 57));
   Foreground = Brushes.White;
   FontFamily = new FontFamily("Segoe UI");

   start = Box(value.Start.ToString(CultureInfo.InvariantCulture));
   step = Box(value.Step.ToString(CultureInfo.InvariantCulture));
   width = Box(Format(value.Width));
   height = Box(Format(value.Height));
   textHeight = Box(Format(value.TextHeight));
   if (value.RegionsOnly) { regions.IsChecked = true; objects.IsChecked = false; }

   var root = new StackPanel { Margin = new Thickness(16) };
   Content = root;
   root.Children.Add(new TextBlock {
    Text = "ĐÁNH SỐ ĐỐI TƯỢNG / VÙNG TƯỚI",
    FontSize = 14,
    FontWeight = FontWeights.SemiBold,
    Foreground = new SolidColorBrush(Color.FromRgb(86, 190, 232)),
    Margin = new Thickness(0, 0, 0, 8)
   });
   root.Children.Add(Header("PHẠM VI ĐÁNH SỐ"));
   root.Children.Add(objects);
   root.Children.Add(regions);

   var columns = new Grid { Margin = new Thickness(0, 10, 0, 0) };
   columns.ColumnDefinitions.Add(new ColumnDefinition());
   columns.ColumnDefinitions.Add(new ColumnDefinition());
   var rules = new StackPanel { Margin = new Thickness(0, 0, 8, 0) };
   rules.Children.Add(Header("QUY LUẬT SỐ"));
   rules.Children.Add(Field("Số bắt đầu", start));
   rules.Children.Add(Field("Bước nhảy", step));
   Grid.SetColumn(rules, 0);
   columns.Children.Add(rules);
   var sizes = new StackPanel { Margin = new Thickness(8, 0, 0, 0) };
   sizes.Children.Add(Header("KÍCH THƯỚC NHÃN"));
   sizes.Children.Add(Field("Độ rộng khung", width));
   sizes.Children.Add(Field("Chiều cao khung", height));
   sizes.Children.Add(Field("Chiều cao chữ", textHeight));
   Grid.SetColumn(sizes, 1);
   columns.Children.Add(sizes);
   root.Children.Add(columns);

   root.Children.Add(Header("THỨ TỰ ĐÁNH SỐ", 12));
   order.ItemsSource = new[] {
    "Theo thứ tự chọn",
    "Trái sang phải, trên xuống dưới",
    "Trên xuống dưới, trái sang phải",
    "Theo đường dẫn Polyline"
   };
   order.SelectedIndex = (int)value.Order;
   root.Children.Add(order);
   root.Children.Add(new TextBlock {
    Text = "Có thể quét chọn nhiều đối tượng. Khung là hình tròn khi độ rộng bằng chiều cao.",
    TextWrapping = TextWrapping.Wrap,
    Opacity = 0.75,
    Margin = new Thickness(0, 10, 0, 0)
   });
   root.Children.Add(error);

   var actions = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right, Margin = new Thickness(0, 12, 0, 0) };
   var accept = new Button { Content = "ĐÁNH SỐ", Width = 120, Padding = new Thickness(10, 7, 10, 7), FontWeight = FontWeights.SemiBold, Background = new SolidColorBrush(Color.FromRgb(58, 118, 162)), Foreground = Brushes.White, Margin = new Thickness(0, 0, 8, 0) };
   accept.Click += delegate { if (Build(true)) { DialogResult = true; Close(); } };
   var cancel = new Button { Content = "Hủy", Width = 90, Padding = new Thickness(10, 7, 10, 7) };
   cancel.Click += delegate { DialogResult = false; Close(); };
   actions.Children.Add(accept);
   actions.Children.Add(cancel);
   root.Children.Add(actions);
   Loaded += delegate { if (Build(false)) { error.Text = ""; } };
  }

  static string Format(double value) { return value.ToString("0.###", CultureInfo.CurrentCulture); }

  static TextBlock Header(string text, double top = 4) {
   return new TextBlock { Text = text, FontWeight = FontWeights.SemiBold, Foreground = new SolidColorBrush(Color.FromRgb(86, 190, 232)), Margin = new Thickness(0, top, 0, 4) };
  }

  static TextBox Box(string text) {
   return new TextBox { Text = text, Margin = new Thickness(0, 1, 0, 4), Padding = new Thickness(5, 3, 5, 3) };
  }

  static StackPanel Field(string label, Control control) {
   var panel = new StackPanel();
   panel.Children.Add(new TextBlock { Text = label, Margin = new Thickness(0, 0, 0, 1) });
   panel.Children.Add(control);
   return panel;
  }

  static bool TryDouble(string text, out double value) {
   return double.TryParse(text, NumberStyles.Float, CultureInfo.CurrentCulture, out value)
       || double.TryParse(text, NumberStyles.Float, CultureInfo.InvariantCulture, out value);
  }

  bool Build(bool showError) {
   int startValue, stepValue;
   double widthValue, heightValue, textValue;
   if (!int.TryParse(start.Text.Trim(), NumberStyles.Integer, CultureInfo.InvariantCulture, out startValue)
    || !int.TryParse(step.Text.Trim(), NumberStyles.Integer, CultureInfo.InvariantCulture, out stepValue)
    || !TryDouble(width.Text, out widthValue) || !TryDouble(height.Text, out heightValue) || !TryDouble(textHeight.Text, out textValue)
    || !NumberingService.Validate(stepValue, widthValue, heightValue, textValue)) {
    if (showError) error.Text = NumberingService.ValidationError;
    return false;
   }
   error.Text = "";
   Settings = new NumberSettings {
    Start = startValue,
    Step = stepValue,
    Width = widthValue,
    Height = heightValue,
    TextHeight = textValue,
    RegionsOnly = regions.IsChecked == true,
    Order = (NumberOrder)Math.Max(0, order.SelectedIndex)
   };
   return true;
  }
 }
}
