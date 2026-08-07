using System;
using System.Globalization;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using Microsoft.Win32;

namespace Tgirrr.CadLisp
{
    public sealed class LinetypeWindow : Window
    {
        readonly TextBox name = Box("");
        readonly TextBox description = Box("");
        readonly TextBox dash = Box("15");
        readonly TextBox before = Box("2");
        readonly TextBox content = Box("");
        readonly TextBox style = Box("Standard");
        readonly TextBox y = Box("-1.32567");
        readonly TextBox scale = Box("2.5");
        readonly TextBox after = Box("19");
        readonly TextBox syntax = new TextBox();
        readonly CheckBox assign = Check("Chuyển đối tượng dùng nét cũ sang nét mới");
        readonly CheckBox selectedOnly = Check("Chỉ chuyển các đối tượng đang chọn");
        readonly RadioButton version = Radio("Tạo nét mới / phiên bản mới (_V2)", true);
        readonly RadioButton overwrite = Radio("Cập nhật định nghĩa gốc trong file", false);
        readonly Canvas preview = new Canvas
        {
            Height = 205,
            Background = new SolidColorBrush(Color.FromRgb(20, 29, 39)),
            Margin = new Thickness(14, 8, 14, 14)
        };
        readonly TextBlock spacingNote = new TextBlock
        {
            Foreground = new SolidColorBrush(Color.FromRgb(255, 202, 86)),
            TextWrapping = TextWrapping.Wrap,
            Margin = new Thickness(0, 4, 0, 4)
        };

        string path = LinetypeService.DefaultPath;
        string originalName = "";

        static readonly Brush WindowBrush = new SolidColorBrush(Color.FromRgb(27, 36, 48));
        static readonly Brush CardBrush = new SolidColorBrush(Color.FromRgb(38, 49, 63));
        static readonly Brush FieldBrush = new SolidColorBrush(Color.FromRgb(50, 63, 79));
        static readonly Brush CyanBrush = new SolidColorBrush(Color.FromRgb(84, 196, 232));
        static readonly Brush MutedBrush = new SolidColorBrush(Color.FromRgb(157, 174, 192));

        public LinetypeWindow()
        {
            Title = "TGIRR — Tạo và chỉnh sửa nét vẽ";
            Width = 860;
            Height = 790;
            MinWidth = 760;
            MinHeight = 680;
            WindowStartupLocation = WindowStartupLocation.CenterScreen;
            Background = WindowBrush;
            Foreground = Brushes.White;

            var page = new StackPanel { Margin = new Thickness(20) };
            var scroll = new ScrollViewer
            {
                Content = page,
                VerticalScrollBarVisibility = ScrollBarVisibility.Auto
            };
            Content = scroll;

            page.Children.Add(new TextBlock
            {
                Text = "TẠO NÉT VẼ CÓ CHỮ",
                FontSize = 22,
                FontWeight = FontWeights.Bold,
                Foreground = CyanBrush
            });
            page.Children.Add(new TextBlock
            {
                Text = "Nhập thông tin theo thứ tự bên dưới — phần xem trước sẽ cập nhật ngay.",
                Foreground = MutedBrush,
                Margin = new Thickness(0, 3, 0, 14)
            });

            var columns = new Grid();
            columns.ColumnDefinitions.Add(new ColumnDefinition());
            columns.ColumnDefinitions.Add(new ColumnDefinition());
            page.Children.Add(columns);

            var information = Card("1  THÔNG TIN NÉT");
            AddField(information, "Tên nét *", name, "VD: NET_CAP_NUOC");
            AddField(information, "Mô tả", description, "VD: --- CẤP NƯỚC ---");
            information.Children.Add(new TextBlock
            {
                Text = "XEM TRƯỚC NÉT",
                Foreground = CyanBrush,
                FontWeight = FontWeights.Bold,
                Margin = new Thickness(14, 8, 14, 0)
            });
            information.Children.Add(preview);
            columns.Children.Add(information);

            var geometry = Card("2  HÌNH HỌC VÀ CHỮ");
            Grid.SetColumn(geometry, 1);
            geometry.Margin = new Thickness(7, 0, 0, 0);
            AddField(geometry, "Chiều dài đoạn gạch", dash, null);
            AddField(geometry, "Khoảng trống trước chữ", before, null);
            AddField(geometry, "Chữ hiển thị trên nét", content, "VD: CẤP NƯỚC");
            geometry.Children.Add(spacingNote);
            geometry.Children.Add(Button("Áp dụng khoảng cách đẹp", ApplySpacing, false));

            var detailGrid = new Grid { Margin = new Thickness(0, 8, 0, 0) };
            detailGrid.ColumnDefinitions.Add(new ColumnDefinition());
            detailGrid.ColumnDefinitions.Add(new ColumnDefinition());
            var detailLeft = new StackPanel { Margin = new Thickness(0, 0, 5, 0) };
            var detailRight = new StackPanel { Margin = new Thickness(5, 0, 0, 0) };
            Grid.SetColumn(detailRight, 1);
            AddField(detailLeft, "Text Style", style, null);
            AddField(detailLeft, "Độ lệch Y", y, null);
            AddField(detailRight, "Tỷ lệ chữ", scale, null);
            AddField(detailRight, "Khoảng trống sau chữ", after, null);
            detailGrid.Children.Add(detailLeft);
            detailGrid.Children.Add(detailRight);
            geometry.Children.Add(detailGrid);
            columns.Children.Add(geometry);

            var output = Card("3  LƯU VÀ ÁP DỤNG");
            output.Margin = new Thickness(0, 12, 0, 0);
            page.Children.Add(output);

            var modes = new Grid();
            modes.ColumnDefinitions.Add(new ColumnDefinition());
            modes.ColumnDefinitions.Add(new ColumnDefinition());
            var modeLeft = new StackPanel();
            modeLeft.Children.Add(version);
            modeLeft.Children.Add(overwrite);
            var modeRight = new StackPanel();
            modeRight.Children.Add(assign);
            modeRight.Children.Add(selectedOnly);
            Grid.SetColumn(modeRight, 1);
            modes.Children.Add(modeLeft);
            modes.Children.Add(modeRight);
            output.Children.Add(modes);

            var fileActions = new WrapPanel { Margin = new Thickness(0, 9, 0, 0) };
            fileActions.Children.Add(Button("Chọn nét từ file", LoadFile, false));
            fileActions.Children.Add(Button("Chọn nét từ bản vẽ", LoadDrawing, false));
            fileActions.Children.Add(Button("Chọn file LIN", Choose, false));
            fileActions.Children.Add(Button("Sao chép cú pháp", Copy, false));
            output.Children.Add(fileActions);

            var mainActions = new WrapPanel { Margin = new Thickness(0, 6, 0, 0) };
            mainActions.Children.Add(Button("TẠO NÉT MỚI VÀ NẠP VÀO CAD", Create, true));
            mainActions.Children.Add(Button("Đóng", (s, e) => Close(), false));
            output.Children.Add(mainActions);


            syntax.IsReadOnly = true;
            syntax.Height = 62;
            syntax.TextWrapping = TextWrapping.Wrap;
            syntax.VerticalScrollBarVisibility = ScrollBarVisibility.Auto;
            syntax.Background = new SolidColorBrush(Color.FromRgb(20, 29, 39));
            syntax.Foreground = Brushes.White;
            syntax.BorderBrush = new SolidColorBrush(Color.FromRgb(65, 82, 100));
            syntax.Padding = new Thickness(9);
            page.Children.Add(syntax);

            foreach (var box in new[] { name, description, dash, before, content, style, y, scale, after })
                box.TextChanged += (s, e) => RefreshView();
            preview.SizeChanged += (s, e) => RefreshView();
            Loaded += (s, e) => RefreshView();
        }

        static TextBox Box(string value)
        {
            return new TextBox
            {
                Text = value,
                Margin = new Thickness(0, 3, 0, 8),
                Padding = new Thickness(8, 6, 8, 6),
                Background = FieldBrush,
                Foreground = Brushes.White,
                BorderBrush = new SolidColorBrush(Color.FromRgb(72, 90, 108)),
                CaretBrush = Brushes.White
            };
        }

        static CheckBox Check(string text)
        {
            return new CheckBox
            {
                Content = text,
                Foreground = Brushes.White,
                Margin = new Thickness(0, 4, 10, 4)
            };
        }

        static RadioButton Radio(string text, bool selected)
        {
            return new RadioButton
            {
                Content = text,
                IsChecked = selected,
                Foreground = Brushes.White,
                Margin = new Thickness(0, 4, 10, 4)
            };
        }

        static StackPanel Card(string title)
        {
            var panel = new StackPanel
            {
                Background = CardBrush,
                Margin = new Thickness(0, 0, 7, 0)
            };
            panel.Children.Add(new TextBlock
            {
                Text = title,
                Foreground = CyanBrush,
                FontWeight = FontWeights.Bold,
                FontSize = 14,
                Margin = new Thickness(14, 14, 14, 10)
            });
            return panel;
        }

        static void AddField(Panel panel, string label, TextBox field, string hint)
        {
            panel.Children.Add(new TextBlock
            {
                Text = label,
                Foreground = Brushes.White,
                FontWeight = FontWeights.SemiBold
            });

            if (string.IsNullOrWhiteSpace(hint))
            {
                panel.Children.Add(field);
                return;
            }

            var holder = new Grid();
            var placeholder = new TextBlock
            {
                Text = hint,
                Foreground = MutedBrush,
                FontStyle = FontStyles.Italic,
                Margin = new Thickness(10, 9, 0, 0),
                IsHitTestVisible = false
            };
            holder.Children.Add(field);
            holder.Children.Add(placeholder);
            Action update = () => placeholder.Visibility = string.IsNullOrEmpty(field.Text)
                ? Visibility.Visible
                : Visibility.Collapsed;
            field.TextChanged += (s, e) => update();
            update();
            panel.Children.Add(holder);
        }

        static Button Button(string text, RoutedEventHandler handler, bool primary)
        {
            var button = new Button
            {
                Content = text,
                Margin = new Thickness(0, 5, 8, 2),
                Padding = primary ? new Thickness(18, 9, 18, 9) : new Thickness(11, 7, 11, 7),
                FontWeight = primary ? FontWeights.Bold : FontWeights.Normal,
                Background = primary ? CyanBrush : new SolidColorBrush(Color.FromRgb(61, 75, 92)),
                Foreground = primary ? new SolidColorBrush(Color.FromRgb(15, 31, 42)) : Brushes.White,
                BorderThickness = new Thickness(0)
            };
            button.Click += handler;
            return button;
        }

        double N(TextBox box, string label)
        {
            double value;
            if (!double.TryParse(box.Text.Replace(',', '.'), NumberStyles.Float, CultureInfo.InvariantCulture, out value))
                throw new InvalidOperationException(label + " không hợp lệ.");
            return value;
        }

        string Def()
        {
            return LinetypeService.Definition(
                name.Text.Trim(), description.Text.Trim(), N(dash, "Đoạn gạch"),
                N(before, "Khoảng trước"), content.Text, style.Text.Trim(),
                N(y, "Độ lệch Y"), N(scale, "Tỷ lệ chữ"), N(after, "Khoảng sau"));
        }

        void RefreshView()
        {
            try
            {
                var dashLength = Math.Abs(N(dash, "Đoạn gạch"));
                var gapBefore = Math.Abs(N(before, "Khoảng trước"));
                var gapAfter = Math.Abs(N(after, "Khoảng sau"));
                var textScale = Math.Abs(N(scale, "Tỷ lệ chữ"));
                var yOffset = N(y, "Độ lệch Y");
                var suggested = dashLength + 2 * gapBefore;
                spacingNote.Text = "Gợi ý khoảng sau: " + dashLength.ToString("0.###") + " + 2 × " +
                    gapBefore.ToString("0.###") + " = " + suggested.ToString("0.###");

                syntax.Text = string.IsNullOrWhiteSpace(name.Text)
                    ? "Nhập Tên nét để xem cú pháp LIN hoàn chỉnh."
                    : Def();
                preview.Children.Clear();

                var previewWidth = preview.ActualWidth;
                if (previewWidth <= 40) previewWidth = 780;
                var left = 18.0;
                var right = previewWidth - 18.0;
                var centerY = preview.ActualHeight > 0 ? preview.ActualHeight / 2.0 : 56.0;
                var displayText = content.Text ?? "";

                // Đo chữ ở đơn vị tương đối trước, sau đó cùng quy đổi mọi thành phần
                // để ba chu kỳ LIN vừa khung xem trước và vẫn giữ đúng tỷ lệ với nhau.
                var measureSize = Math.Max(textScale, 0.1);
                var measured = new FormattedText(displayText, CultureInfo.CurrentUICulture,
                    FlowDirection.LeftToRight, new Typeface("Segoe UI"), measureSize, Brushes.White, 1.0);
                var textUnits = string.IsNullOrWhiteSpace(displayText) ? 0.0 : measured.WidthIncludingTrailingWhitespace;
                var cycleUnits = dashLength + gapBefore + textUnits + gapAfter;
                if (cycleUnits <= 0.000001)
                    throw new InvalidOperationException("Tổng chiều dài một chu kỳ nét phải lớn hơn 0.");

                const int visibleCycles = 3;
                var pixelsPerUnit = (right - left) / (cycleUnits * visibleCycles);
                var fontPixels = Math.Max(8.0, textScale * pixelsPerUnit);
                var textPreview = new FormattedText(displayText, CultureInfo.CurrentUICulture,
                    FlowDirection.LeftToRight, new Typeface("Segoe UI"), fontPixels, Brushes.White, 1.0);
                var textWidth = string.IsNullOrWhiteSpace(displayText)
                    ? 0.0
                    : textPreview.WidthIncludingTrailingWhitespace;
                var baselineY = centerY - textPreview.Height / 2.0 - yOffset * pixelsPerUnit;

                var x = left;
                for (var cycle = 0; cycle < visibleCycles && x < right; cycle++)
                {
                    var dashEnd = Math.Min(x + dashLength * pixelsPerUnit, right);
                    if (dashEnd > x)
                    {
                        preview.Children.Add(new System.Windows.Shapes.Line
                        {
                            X1 = x,
                            Y1 = centerY,
                            X2 = dashEnd,
                            Y2 = centerY,
                            Stroke = CyanBrush,
                            StrokeThickness = 2
                        });
                    }

                    x = dashEnd + gapBefore * pixelsPerUnit;
                    if (!string.IsNullOrWhiteSpace(displayText) && x < right)
                    {
                        var textBlock = new TextBlock
                        {
                            Text = displayText,
                            Foreground = Brushes.White,
                            Background = preview.Background,
                            FontFamily = new FontFamily("Segoe UI"),
                            FontSize = fontPixels,
                            LineHeight = fontPixels,
                            Padding = new Thickness(0)
                        };
                        Canvas.SetLeft(textBlock, x);
                        Canvas.SetTop(textBlock, baselineY);
                        preview.Children.Add(textBlock);
                        x += textWidth;
                    }
                    x += gapAfter * pixelsPerUnit;
                }

                var dimensions = new TextBlock
                {
                    Text = "Gạch " + dashLength.ToString("0.###") +
                        "  •  Trước " + gapBefore.ToString("0.###") +
                        "  •  Chữ " + (string.IsNullOrWhiteSpace(displayText) ? "(không có)" : displayText) +
                        "  •  Sau " + gapAfter.ToString("0.###"),
                    Foreground = MutedBrush,
                    FontSize = 11
                };
                Canvas.SetLeft(dimensions, left);
                Canvas.SetTop(dimensions, preview.ActualHeight > 0 ? preview.ActualHeight - 21 : 91);
                preview.Children.Add(dimensions);
            }
            catch
            {
                preview.Children.Clear();
                syntax.Text = "Vui lòng nhập các thông số hình học hợp lệ.";
                spacingNote.Text = "Nhập chiều dài đoạn gạch và khoảng trước để xem gợi ý.";
            }
        }

        void ApplySpacing(object sender, RoutedEventArgs e)
        {
            try
            {
                after.Text = (N(dash, "Đoạn gạch") + 2 * N(before, "Khoảng trước"))
                    .ToString("0.###", CultureInfo.InvariantCulture);
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message, "Không thể tính khoảng cách");
            }
        }

        void Create(object sender, RoutedEventArgs e)
        {
            try
            {
                var doc = Autodesk.AutoCAD.ApplicationServices.Application.DocumentManager.MdiActiveDocument;
                var requested = name.Text.Trim();
                if (string.IsNullOrWhiteSpace(requested))
                    throw new InvalidOperationException("Anh hãy nhập Tên nét trước khi tạo và nạp vào CAD.");

                var old = originalName == "" ? requested : originalName;
                var final = requested;
                var overwriteMode = overwrite.IsChecked == true;

                if (overwriteMode)
                {
                    if (MessageBox.Show(
                        "AutoCAD không cho nạp đè trực tiếp Linetype đang tồn tại.\n\nTool sẽ:\n" +
                        "1. Ghi đè định nghĩa tên gốc trong file LIN.\n" +
                        "2. Tạo một phiên bản mới trong bản vẽ hiện tại.\n" +
                        "3. Chuyển đối tượng nếu anh đã chọn tùy chọn chuyển.\n\nTiếp tục?",
                        "TGIRR", MessageBoxButton.YesNo, MessageBoxImage.Warning) != MessageBoxResult.Yes)
                        return;

                    var originalDefinition = LinetypeService.Definition(
                        old, description.Text.Trim(), N(dash, "Đoạn gạch"), N(before, "Khoảng trước"),
                        content.Text, style.Text.Trim(), N(y, "Độ lệch Y"),
                        N(scale, "Tỷ lệ chữ"), N(after, "Khoảng sau"));
                    LinetypeService.Save(path, old, originalDefinition);
                    final = LinetypeService.NextName(doc, old);
                    name.Text = final;
                    LinetypeService.Save(path, final, Def());
                }
                else
                {
                    if (LinetypeService.DrawingNamesAll(doc).Any(n =>
                        string.Equals(n, requested, StringComparison.OrdinalIgnoreCase)))
                        final = LinetypeService.NextName(doc, requested);
                    name.Text = final;
                    LinetypeService.Save(path, final, Def());
                }

                var moved = LinetypeService.LoadAndReplace(
                    path, final, old, assign.IsChecked == true, selectedOnly.IsChecked == true);
                MessageBox.Show(
                    "Đã nạp nét mới '" + final + "'.\n" +
                    "Định nghĩa gốc trong file: '" + old + "'.\n" +
                    "Đã chuyển " + moved + " đối tượng.\n\n" +
                    "Lưu ý: AutoCAD không hỗ trợ thay nóng record cùng tên; bản vẽ hiện tại dùng '" + final + "'.",
                    "TGIRR", MessageBoxButton.OK, MessageBoxImage.Information);
                originalName = final;
            }
            catch (Autodesk.AutoCAD.Runtime.Exception ex)
            {
                MessageBox.Show("Lỗi AutoCAD: " + ex.ErrorStatus + "\n" + ex.Message,
                    "Không thể chỉnh sửa nét", MessageBoxButton.OK, MessageBoxImage.Error);
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message, "Không thể chỉnh sửa nét",
                    MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        void ApplyDef(LinetypeDefinition definition)
        {
            originalName = definition.Name;
            path = definition.SourcePath;
            name.Text = definition.Name;
            description.Text = definition.Description;
            dash.Text = definition.Dash.ToString(CultureInfo.InvariantCulture);
            before.Text = definition.Before.ToString(CultureInfo.InvariantCulture);
            content.Text = definition.Text ?? "";
            style.Text = definition.Style ?? "Standard";
            y.Text = definition.Y.ToString(CultureInfo.InvariantCulture);
            scale.Text = definition.Scale.ToString(CultureInfo.InvariantCulture);
            after.Text = definition.After.ToString(CultureInfo.InvariantCulture);
            RefreshView();
        }

        void LoadFile(object sender, RoutedEventArgs e)
        {
            var dialog = new OpenFileDialog { Filter = "AutoCAD Linetype (*.lin)|*.lin" };
            if (dialog.ShowDialog() == true)
                Pick(LinetypeService.Read(dialog.FileName), "Chọn nét từ file LIN");
        }

        void LoadDrawing(object sender, RoutedEventArgs e)
        {
            var doc = Autodesk.AutoCAD.ApplicationServices.Application.DocumentManager.MdiActiveDocument;
            string typeName = null;
            Hide();
            try
            {
                var options = new Autodesk.AutoCAD.EditorInput.PromptEntityOptions(
                    "\nChọn Pline hoặc đối tượng có nét cần chỉnh sửa: ");
                var picked = doc.Editor.GetEntity(options);
                if (picked.Status != Autodesk.AutoCAD.EditorInput.PromptStatus.OK) return;

                using (doc.LockDocument())
                using (var transaction = doc.Database.TransactionManager.StartTransaction())
                {
                    var entity = transaction.GetObject(picked.ObjectId,
                        Autodesk.AutoCAD.DatabaseServices.OpenMode.ForRead) as
                        Autodesk.AutoCAD.DatabaseServices.Entity;
                    if (entity != null)
                    {
                        typeName = entity.Linetype;
                        if (typeName.Equals("ByLayer", StringComparison.OrdinalIgnoreCase))
                        {
                            var layers = (Autodesk.AutoCAD.DatabaseServices.LayerTable)transaction.GetObject(
                                doc.Database.LayerTableId, Autodesk.AutoCAD.DatabaseServices.OpenMode.ForRead);
                            var layer = (Autodesk.AutoCAD.DatabaseServices.LayerTableRecord)transaction.GetObject(
                                layers[entity.Layer], Autodesk.AutoCAD.DatabaseServices.OpenMode.ForRead);
                            var record = (Autodesk.AutoCAD.DatabaseServices.LinetypeTableRecord)transaction.GetObject(
                                layer.LinetypeObjectId, Autodesk.AutoCAD.DatabaseServices.OpenMode.ForRead);
                            typeName = record.Name;
                        }
                    }
                }
            }
            finally
            {
                Show();
                Activate();
            }

            if (string.IsNullOrWhiteSpace(typeName) ||
                typeName.Equals("ByBlock", StringComparison.OrdinalIgnoreCase) ||
                typeName.Equals("Continuous", StringComparison.OrdinalIgnoreCase))
            {
                MessageBox.Show(
                    "Đối tượng không có custom Linetype để chỉnh sửa (ByBlock hoặc Continuous). " +
                    "Hãy chọn nét từ file LIN.", "TGIRR", MessageBoxButton.OK,
                    MessageBoxImage.Information);
                return;
            }

            var found = LinetypeService.Read(path).FirstOrDefault(x =>
                string.Equals(x.Name, typeName, StringComparison.OrdinalIgnoreCase));
            if (found == null)
            {
                MessageBox.Show(
                    "Đã đọc được nét hiệu lực '" + typeName + "' nhưng không tìm thấy cú pháp trong file:\n" +
                    path + "\n\nHãy bấm Chọn nét từ file và chọn đúng file LIN nguồn.",
                    "TGIRR", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }
            ApplyDef(found);
            MessageBox.Show("Đã nạp nét hiệu lực '" + typeName + "' lên form chỉnh sửa.", "TGIRR");
        }

        void Pick(System.Collections.Generic.List<LinetypeDefinition> definitions, string title)
        {
            if (definitions.Count == 0)
            {
                MessageBox.Show("Không tìm thấy định nghĩa nét phù hợp.");
                return;
            }

            var picker = new Window
            {
                Title = title,
                Width = 400,
                Height = 400,
                Owner = this,
                WindowStartupLocation = WindowStartupLocation.CenterOwner
            };
            var list = new ListBox
            {
                ItemsSource = definitions,
                DisplayMemberPath = "Name",
                Margin = new Thickness(10)
            };
            list.MouseDoubleClick += (s, e) =>
            {
                if (list.SelectedItem == null) return;
                ApplyDef((LinetypeDefinition)list.SelectedItem);
                picker.Close();
            };
            picker.Content = list;
            picker.ShowDialog();
        }

        void Choose(object sender, RoutedEventArgs e)
        {
            var dialog = new SaveFileDialog
            {
                Filter = "AutoCAD Linetype (*.lin)|*.lin",
                FileName = System.IO.Path.GetFileName(path)
            };
            if (dialog.ShowDialog() == true) path = dialog.FileName;
        }

        void Copy(object sender, RoutedEventArgs e)
        {
            if (string.IsNullOrWhiteSpace(name.Text))
            {
                MessageBox.Show("Anh hãy nhập Tên nét trước khi sao chép cú pháp.", "TGIRR");
                return;
            }
            Clipboard.SetText(Def());
        }
    }
}
