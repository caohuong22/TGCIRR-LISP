using Autodesk.AutoCAD.DatabaseServices;
using System;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;

namespace Tgirrr.CadLisp {
 public sealed class DripLayoutWindow : Window {
  static double lastInsetMeters = 0.1, lastSpacingMeters = 0.33;
  static bool lastSerpentine = true, lastAnnotate = true;
  static bool lastUseDirection, lastUseEdge = true;
  static double? lastDirX, lastDirY;

  readonly TextBox inset = Input(0), spacing = Input(0);
  readonly ComboBox units = new ComboBox { Padding = new Thickness(6, 4, 6, 4), MinWidth = 150 };
  readonly TextBlock insetLabel = new TextBlock(), spacingLabel = new TextBlock(), source = new TextBlock { Foreground = new SolidColorBrush(Color.FromRgb(171, 190, 207)) };
  readonly CheckBox serpentineCheck = new CheckBox { Content = "Nối dây liên tục kiểu zigzag (1 cuộn rắn bò)", Foreground = Brushes.White, VerticalContentAlignment = VerticalAlignment.Center, IsChecked = lastSerpentine };
  readonly CheckBox annotateCheck = new CheckBox { Content = "Ghi chú thông số + tổng chiều dài dây", Foreground = Brushes.White, VerticalContentAlignment = VerticalAlignment.Center, IsChecked = lastAnnotate };
  readonly CheckBox directionCheck = new CheckBox { Content = "Chọn hướng dây trên bản vẽ (2 điểm)", Foreground = Brushes.White, VerticalContentAlignment = VerticalAlignment.Center, IsChecked = lastUseDirection };
  readonly CheckBox edgeCheck = new CheckBox { Content = "Offset từ cạnh chuẩn: pick 1 điểm trên cạnh của Boundary", Foreground = Brushes.White, VerticalContentAlignment = VerticalAlignment.Center, IsChecked = lastUseEdge };
  readonly Button clearDirection = new Button { Content = "XÓA HƯỚNG ĐÃ CHỌN", Padding = new Thickness(8, 3, 8, 3), Margin = new Thickness(10, 0, 0, 0), HorizontalAlignment = HorizontalAlignment.Left, VerticalAlignment = VerticalAlignment.Center };
  readonly TextBlock directionHint = new TextBlock { Foreground = new SolidColorBrush(Color.FromRgb(171, 190, 207)), TextWrapping = TextWrapping.Wrap };

  internal double Inset, Spacing;
  internal bool Serpentine, Annotate, UseEdge;
  /// <summary>Hướng dây do người dùng chỉ định (đã chuẩn hóa); null = tự động theo cạnh dài nhất.</summary>
  internal double? DirX, DirY;
  readonly UnitsValue drawingUnits;
  UnitsValue displayedUnit;
  bool pickDirectionRequested;

  /// <summary>true khi người dùng bấm "Chọn hướng" — caller cần pick 2 điểm rồi mở lại dialog.</summary>
  internal bool PickDirectionRequested => pickDirectionRequested;

  public DripLayoutWindow(UnitsValue drawingUnits) {
   this.drawingUnits = drawingUnits;
   if (lastUseDirection && lastDirX.HasValue) { DirX = lastDirX; DirY = lastDirY; }
   Title = "TGIRR — Rải dây nhỏ giọt";
   Width = 560;
   Height = 470;
   MinWidth = 520;
   MinHeight = 430;
   WindowStartupLocation = WindowStartupLocation.CenterScreen;
   ResizeMode = ResizeMode.CanResizeWithGrip;
   Background = new SolidColorBrush(Color.FromRgb(36, 45, 57));
   Foreground = Brushes.White;
   FontFamily = new FontFamily("Segoe UI");
   var root = new StackPanel { Margin = new Thickness(18) };
   Content = root;
   root.Children.Add(new TextBlock { Text = "RẢI DÂY NHỎ GIỌT", FontSize = 16, FontWeight = FontWeights.SemiBold, Foreground = new SolidColorBrush(Color.FromRgb(202, 139, 67)), Margin = new Thickness(0, 0, 0, 10) });

   var unitRow = new Grid { Margin = new Thickness(0, 0, 0, 8) };
   unitRow.ColumnDefinitions.Add(new ColumnDefinition());
   unitRow.ColumnDefinitions.Add(new ColumnDefinition());
   var up = new StackPanel();
   up.Children.Add(new TextBlock { Text = "Đơn vị nhập" });
   units.ItemsSource = new[] { "Tự động theo bản vẽ", "Milimét (mm)", "Centimét (cm)", "Mét (m)", "Đơn vị bản vẽ" };
   units.SelectedIndex = DefaultIndex(drawingUnits);
   displayedUnit = SelectedUnit();
   units.SelectionChanged += (s, e) => ChangeUnit();
   up.Children.Add(units);
   unitRow.Children.Add(up);
   var sp = new StackPanel { Margin = new Thickness(10, 0, 0, 0) };
   sp.Children.Add(new TextBlock { Text = "Nguồn nhận diện" });
   sp.Children.Add(source);
   Grid.SetColumn(sp, 1);
   unitRow.Children.Add(sp);
   root.Children.Add(unitRow);

   var fields = new Grid();
   fields.ColumnDefinitions.Add(new ColumnDefinition());
   fields.ColumnDefinitions.Add(new ColumnDefinition());
   AddField(fields, 0, insetLabel, inset);
   AddField(fields, 1, spacingLabel, spacing);
   root.Children.Add(fields);

   var options = new Border {
    Background = new SolidColorBrush(Color.FromRgb(29, 39, 51)),
    CornerRadius = new CornerRadius(4),
    Padding = new Thickness(10, 8, 10, 8),
    Margin = new Thickness(0, 10, 0, 0)
   };
   var optPanel = new StackPanel();
   optPanel.Children.Add(new TextBlock { Text = "TÙY CHỌN", FontSize = 11, Foreground = new SolidColorBrush(Color.FromRgb(202, 139, 67)), Margin = new Thickness(0, 0, 0, 6) });
   var dirRow = new StackPanel { Orientation = Orientation.Horizontal };
   dirRow.Children.Add(directionCheck);
   dirRow.Children.Add(clearDirection);
   optPanel.Children.Add(dirRow);
   optPanel.Children.Add(directionHint);
   optPanel.Children.Add(edgeCheck);
   optPanel.Children.Add(serpentineCheck);
   optPanel.Children.Add(annotateCheck);
   options.Child = optPanel;
   root.Children.Add(options);

   root.Children.Add(new Border {
    Background = new SolidColorBrush(Color.FromRgb(29, 39, 51)),
    CornerRadius = new CornerRadius(4),
    Padding = new Thickness(10, 8, 10, 8),
    Margin = new Thickness(0, 10, 0, 10),
    Child = new TextBlock {
     Text = "Không chọn hướng: dây rải theo cạnh dài nhất của Boundary. Đường offset phía trong được giữ lại để nối các đầu dây.",
     TextWrapping = TextWrapping.Wrap,
     Foreground = new SolidColorBrush(Color.FromRgb(171, 190, 207))
    }
   });

   var buttons = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right };
   var close = new Button { Content = "ĐÓNG", Width = 82, Padding = new Thickness(8, 7, 8, 7), Margin = new Thickness(0, 0, 8, 0) };
   close.Click += (s, e) => Close();
   buttons.Children.Add(close);
   var run = new Button { Content = "RẢI DÂY", Width = 112, Padding = new Thickness(8, 7, 8, 7), FontWeight = FontWeights.SemiBold, Background = new SolidColorBrush(Color.FromRgb(156, 99, 44)), Foreground = Brushes.White, IsDefault = true };
   run.Click += (s, e) => Run();
   buttons.Children.Add(run);
   root.Children.Add(buttons);

   clearDirection.Click += (s, e) => {
    DirX = null;
    DirY = null;
    lastDirX = null;
    lastDirY = null;
    lastUseDirection = directionCheck.IsChecked == true;
    UpdateDirectionHint();
   };

   PreviewKeyDown += (s, e) => {
    if (e.Key == Key.Enter || (e.Key == Key.Space && !(Keyboard.FocusedElement is TextBox))) {
     Run();
     e.Handled = true;
    }
   };
   UpdateDirectionHint();
   ShowMeters();
   UpdateLabels();
  }

  void Run() {
   if (!double.TryParse(inset.Text, out double a) || a < 0 || !double.TryParse(spacing.Text, out double b) || b <= 0) {
    MessageBox.Show("Khoảng lùi phải không âm và khoảng cách dây phải lớn hơn 0.", "VDNG");
    return;
   }
   var selected = SelectedUnit();
   if (selected == UnitsValue.Undefined) {
    MessageBox.Show("Bản vẽ chưa khai báo đơn vị. Vui lòng chọn mm, cm hoặc m.", "VDNG");
    return;
   }
   double factor = Factor(selected, drawingUnits);
   Inset = a * factor;
   Spacing = b * factor;
   Serpentine = serpentineCheck.IsChecked == true;
   Annotate = annotateCheck.IsChecked == true;
   UseEdge = edgeCheck.IsChecked == true;
   lastInsetMeters = a * Mm(selected) / 1000.0;
   lastSpacingMeters = b * Mm(selected) / 1000.0;
   lastSerpentine = Serpentine;
   lastAnnotate = Annotate;
   lastUseEdge = UseEdge;
   if (directionCheck.IsChecked == true) {
    lastUseDirection = true;
    if (!DirX.HasValue) {
     pickDirectionRequested = true;
     // Không gọi Hide()/Close() ở đây: gán DialogResult sẽ tự đóng dialog modal.
     DialogResult = false;
     return;
    }
    DialogResult = true;
    Close();
    return;
   }
   lastUseDirection = false;
   lastDirX = null;
   lastDirY = null;
   DirX = null;
   DirY = null;
   DialogResult = true;
   Close();
  }

  /// <summary>Gán hướng dây (do người dùng pick 2 điểm) và làm mới dòng gợi ý.</summary>
  internal void SetDirection(double x, double y) {
   double mag = Math.Sqrt(x * x + y * y);
   if (mag < 1e-9) { DirX = null; DirY = null; }
   else { DirX = x / mag; DirY = y / mag; }
   lastDirX = DirX;
   lastDirY = DirY;
   UpdateDirectionHint();
  }

  internal void UpdateDirectionHint() {
   bool has = DirX.HasValue && DirY.HasValue;
   clearDirection.IsEnabled = has;
   if (has) {
    double deg = Math.Atan2(DirY.Value, DirX.Value) * 180.0 / Math.PI;
    if (deg < 0) deg += 360;
    directionHint.Text = "Hướng hiện tại: " + deg.ToString("0.#") + "° — bấm RẢI DÂY để áp dụng, hoặc bấm XÓA HƯỚNG ĐÃ CHỌN để chọn lại cho ô khác.";
   } else {
    directionHint.Text = "Chưa chọn hướng — dây rải theo cạnh dài nhất. Tích chọn rồi bấm RẢI DÂY để chỉ 2 điểm xác định hướng.";
   }
   directionHint.Margin = new Thickness(22, 2, 0, 6);
  }

  UnitsValue SelectedUnit() {
   if (units.SelectedIndex == 0) return drawingUnits;
   if (units.SelectedIndex == 1) return UnitsValue.Millimeters;
   if (units.SelectedIndex == 2) return UnitsValue.Centimeters;
   if (units.SelectedIndex == 3) return UnitsValue.Meters;
   return drawingUnits;
  }

  void ChangeUnit() {
   var next = SelectedUnit();
   if (next == UnitsValue.Undefined) { UpdateLabels(); return; }
   double a, b;
   if (double.TryParse(inset.Text, out a) && displayedUnit != UnitsValue.Undefined) lastInsetMeters = a * Mm(displayedUnit) / 1000.0;
   if (double.TryParse(spacing.Text, out b) && displayedUnit != UnitsValue.Undefined) lastSpacingMeters = b * Mm(displayedUnit) / 1000.0;
   displayedUnit = next;
   ShowMeters();
   UpdateLabels();
  }

  void ShowMeters() {
   var u = SelectedUnit();
   if (u == UnitsValue.Undefined) return;
   inset.Text = (lastInsetMeters * 1000.0 / Mm(u)).ToString("0.########");
   spacing.Text = (lastSpacingMeters * 1000.0 / Mm(u)).ToString("0.########");
  }

  void UpdateLabels() {
   var u = SelectedUnit();
   var symbol = Symbol(u);
   insetLabel.Text = "Khoảng lùi từ biên (" + symbol + ")";
   spacingLabel.Text = "Khoảng cách giữa dây (" + symbol + ")";
   source.Text = "INSUNITS = " + drawingUnits + (drawingUnits == UnitsValue.Undefined ? " — cần chọn thủ công" : "");
  }

  static int DefaultIndex(UnitsValue u) => u == UnitsValue.Undefined ? 4 : 0;
  static string Symbol(UnitsValue u) => u == UnitsValue.Millimeters ? "mm" : u == UnitsValue.Centimeters ? "cm" : u == UnitsValue.Meters ? "m" : "DU";
  static double Mm(UnitsValue u) => u == UnitsValue.Millimeters ? 1 : u == UnitsValue.Centimeters ? 10 : u == UnitsValue.Meters ? 1000 : 1;
  static double Factor(UnitsValue input, UnitsValue drawing) => drawing == UnitsValue.Undefined ? 1 : Mm(input) / Mm(drawing);
  static TextBox Input(double v) => new TextBox { Text = v.ToString(), Padding = new Thickness(7, 5, 7, 5) };

  static void AddField(Grid g, int c, TextBlock label, Control input) {
   var p = new StackPanel { Margin = new Thickness(c == 0 ? 0 : 7, 0, c == 0 ? 7 : 0, 0) };
   p.Children.Add(label);
   p.Children.Add(input);
   Grid.SetColumn(p, c);
   g.Children.Add(p);
  }
 }
}
