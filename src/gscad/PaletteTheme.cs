using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;

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
}
