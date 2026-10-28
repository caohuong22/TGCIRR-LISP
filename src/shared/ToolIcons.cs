using System;
using System.Collections.Generic;
using System.IO;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;

namespace Tgirrr.CadLisp {
 /// <summary>
 /// Bo icon vector dung chung cho Ribbon, palette, Quick Tools va thanh cong cu native.
 /// Moi lenh co mot hinh rieng, KHONG ve chu len icon; ten lenh + cach dung chi hien khi hover.
 /// Chi dung System.Windows.Media nen file nay duoc copy nguyen van sang moi host CAD.
 /// gen-icons.ps1 compile file nay roi rasterize ra BMP 16/32 cho toolbar native,
 /// nho vay icon tren moi be mat luon giong het nhau.
 /// </summary>
 public static class ToolIcons {
  static readonly Color Tile = Color.FromRgb(30, 41, 54);
  static readonly Color Ink = Color.FromRgb(232, 239, 247);
  static readonly Color Dim = Color.FromRgb(132, 150, 170);
  static readonly Color Yellow = Color.FromRgb(255, 196, 61);

  static readonly Dictionary<string, ImageSource> Cache = new Dictionary<string, ImageSource>();

  /// <summary>Icon cua mot lenh theo khoa trong tools.json ("icon").</summary>
  public static ImageSource For(string key, Color accent) {
   string cacheKey = (key ?? "") + "|" + accent.ToString();
   lock (Cache) {
    ImageSource cached;
    if (Cache.TryGetValue(cacheKey, out cached)) return cached;
   }
   var image = new DrawingImage(Art(key, accent));
   image.Freeze();
   lock (Cache) { Cache[cacheKey] = image; }
   return image;
  }

  /// <summary>Hinh ve goc (toa do 32x32) - dung cho ca WPF lan rasterize ra BMP.</summary>
  public static DrawingGroup Art(string key, Color accent) {
   var g = Canvas(accent);
   switch (key) {
    case "boundary": Boundary(g, accent); break;
    case "join-hatch": JoinHatch(g, accent); break;
    case "spline-polyline": SplinePolyline(g, accent); break;
    case "convert-polyline": ConvertPolyline(g, accent); break;
    case "select-similar": SelectSimilar(g, accent); break;
    case "select-exact": SelectExact(g, accent); break;
    case "select-hatch": SelectHatch(g, accent); break;
    case "drip": Drip(g, accent); break;
    case "linetype": Linetype(g, accent); break;
    case "layers": Layers(g, accent); break;
    case "layer-add": LayerAdd(g, accent); break;
    case "measure": Measure(g, accent); break;
    case "number": Number(g, accent); break;
    case "copy": Copy(g, accent); break;
    case "mtext-text": MTextToText(g, accent); break;
    case "text-mtext": TextToMText(g, accent); break;
    case "palette": Palette(g, accent); break;
    case "quick": Quick(g, accent); break;
    case "title-block": TitleBlock(g, accent); break;
    case "title-sync": TitleSync(g, accent); break;
    case "toolbar": Toolbar(g, accent); break;
    case "settings": Settings(g, accent); break;
    default: Fallback(g, accent); break;
   }
   g.Freeze();
   return g;
  }

  // ----- Rasterize (gen-icons.ps1 dung) --------------------------------------
  public static void SaveBmp(string key, Color accent, string path, int size) {
   var visual = new DrawingVisual();
   using (DrawingContext dc = visual.RenderOpen()) {
    dc.PushTransform(new ScaleTransform(size / 32.0, size / 32.0));
    dc.DrawDrawing(Art(key, accent));
    dc.Pop();
   }
   var rtb = new RenderTargetBitmap(size, size, 96, 96, PixelFormats.Pbgra32);
   rtb.Render(visual);

   int stride = size * 4;
   var src = new byte[size * stride];
   rtb.CopyPixels(src, stride, 0);
   var dst = new byte[size * size * 3];
   for (int i = 0, j = 0; i < src.Length; i += 4, j += 3) {
    dst[j] = src[i + 2];
    dst[j + 1] = src[i + 1];
    dst[j + 2] = src[i];
   }
   var bmp = BitmapSource.Create(size, size, 96, 96, PixelFormats.Bgr24, null, dst, size * 3);
   var encoder = new BmpBitmapEncoder();
   encoder.Frames.Add(BitmapFrame.Create(bmp));
   using (FileStream fs = File.Create(path)) encoder.Save(fs);
  }

  // ----- Khung chung --------------------------------------------------------
  static DrawingGroup Canvas(Color accent) {
   var g = new DrawingGroup();
   g.Children.Add(new GeometryDrawing(new SolidColorBrush(Tile), null,
    new RectangleGeometry(new Rect(0, 0, 32, 32))));
   g.Children.Add(new GeometryDrawing(null, new Pen(new SolidColorBrush(accent), 1.1),
    new RectangleGeometry(new Rect(0.55, 0.55, 30.9, 30.9), 3, 3)));
   return g;
  }

  static SolidColorBrush Fill(Color c) {
   var b = new SolidColorBrush(c);
   b.Freeze();
   return b;
  }

  static Pen Stroke(Color c, double width) {
   var p = new Pen(Fill(c), width);
   p.StartLineCap = PenLineCap.Round;
   p.EndLineCap = PenLineCap.Round;
   p.LineJoin = PenLineJoin.Round;
   p.Freeze();
   return p;
  }

  static Pen Dashed(Color c, double width) {
   var p = new Pen(Fill(c), width);
   p.DashStyle = new DashStyle(new double[] { 1.6, 1.4 }, 0);
   p.Freeze();
   return p;
  }

  static void Add(DrawingGroup g, Brush fill, Pen pen, Geometry geo) {
   g.Children.Add(new GeometryDrawing(fill, pen, geo));
  }

  static void Box(DrawingGroup g, Brush fill, Pen pen, double x, double y, double w, double h) {
   Add(g, fill, pen, new RectangleGeometry(new Rect(x, y, w, h)));
  }

  static void RBox(DrawingGroup g, Brush fill, Pen pen, double x, double y, double w, double h, double r) {
   Add(g, fill, pen, new RectangleGeometry(new Rect(x, y, w, h), r, r));
  }

  static void Dot(DrawingGroup g, Brush fill, double cx, double cy, double r) {
   Add(g, fill, null, new EllipseGeometry(new Point(cx, cy), r, r));
  }

  static Geometry Poly(bool closed, params double[] xy) {
   var geo = new StreamGeometry();
   using (StreamGeometryContext c = geo.Open()) {
    c.BeginFigure(new Point(xy[0], xy[1]), closed, closed);
    for (int i = 2; i + 1 < xy.Length; i += 2) c.LineTo(new Point(xy[i], xy[i + 1]), true, false);
   }
   geo.Freeze();
   return geo;
  }

  static Geometry Curve(double x1, double y1, double cx1, double cy1, double cx2, double cy2, double x2, double y2) {
   var geo = new StreamGeometry();
   using (StreamGeometryContext c = geo.Open()) {
    c.BeginFigure(new Point(x1, y1), false, false);
    c.BezierTo(new Point(cx1, cy1), new Point(cx2, cy2), new Point(x2, y2), true, false);
   }
   geo.Freeze();
   return geo;
  }

  static void Arrow(DrawingGroup g, double x1, double y1, double x2, double y2) {
   Add(g, null, Stroke(Yellow, 1.4), Poly(false, x1, y1, x2, y2));
   double a = Math.Atan2(y2 - y1, x2 - x1);
   double len = 3.4;
   Add(g, null, Stroke(Yellow, 1.4), Poly(false,
    x2, y2,
    x2 - len * Math.Cos(a - 0.5), y2 - len * Math.Sin(a - 0.5)));
   Add(g, null, Stroke(Yellow, 1.4), Poly(false,
    x2, y2,
    x2 - len * Math.Cos(a + 0.5), y2 - len * Math.Sin(a + 0.5)));
  }

  static void Star(DrawingGroup g, double cx, double cy, double outer, double inner, Color color) {
   var geo = new StreamGeometry();
   using (StreamGeometryContext c = geo.Open()) {
    for (int i = 0; i < 10; i++) {
     double ang = Math.PI / 2 + i * Math.PI / 5;
     double r = (i % 2 == 0) ? outer : inner;
     var p = new Point(cx + r * Math.Cos(ang), cy - r * Math.Sin(ang));
     if (i == 0) c.BeginFigure(p, true, true);
     else c.LineTo(p, true, false);
    }
   }
   geo.Freeze();
   Add(g, Fill(color), null, geo);
  }

  /// <summary>Duong hatch cheo trong mot vung chu nhat (bieu tuong vat lieu/hatch).</summary>
  static void Hatch(DrawingGroup g, Color color, double x, double y, double w, double h) {
   for (double dx = -h; dx < w; dx += 3.6) {
    double x1 = x + Math.Max(0, dx);
    double y1 = y + h - Math.Max(0, Math.Min(h, -dx));
    double x2 = x + Math.Min(w, dx + h);
    double y2 = y + Math.Min(h, h - Math.Max(0, dx + h - w));
    if (x1 > x2) continue;
    Add(g, null, Stroke(color, 0.9), Poly(false, x1, y1, x2, y2));
   }
  }

  static void Cursor(DrawingGroup g) {
   Add(g, Fill(Ink), new Pen(Fill(Color.FromRgb(20, 28, 38)), 0.8),
    Poly(true, 23, 21, 30, 30, 26, 29, 24, 32, 22, 23));
  }

  // ----- Tung icon ----------------------------------------------------------
  static void Boundary(DrawingGroup g, Color accent) {
   Add(g, null, Dashed(accent, 1.3), new RectangleGeometry(new Rect(4, 5, 24, 22), 2, 2));
   Hatch(g, Ink, 8, 10, 16, 12);
   Dot(g, Fill(Yellow), 26.5, 25.5, 1.8);
  }

  static void JoinHatch(DrawingGroup g, Color accent) {
   Add(g, null, Dashed(accent, 1.1), new RectangleGeometry(new Rect(3.5, 9, 11.5, 16)));
   Add(g, null, Dashed(accent, 1.1), new RectangleGeometry(new Rect(15, 9, 11.5, 16)));
   Hatch(g, Ink, 5, 11, 8, 12);
   Hatch(g, Ink, 17, 11, 8, 12);
   Add(g, null, Stroke(Yellow, 1.6), Poly(false, 25, 3.5, 25, 8.5));
   Add(g, null, Stroke(Yellow, 1.6), Poly(false, 22.5, 6, 27.5, 6));
  }

  static void SplinePolyline(DrawingGroup g, Color accent) {
   Add(g, null, Stroke(Ink, 1.5), Curve(3, 25, 7, 8, 13, 26, 16, 11));
   Dot(g, Fill(accent), 3, 25, 1.6);
   Dot(g, Fill(accent), 16, 11, 1.6);
   Add(g, null, Stroke(accent, 1.5), Poly(false, 20, 25, 24, 18, 26, 24, 29, 14));
   Arrow(g, 17.5, 15, 19.5, 17.5);
  }

  static void ConvertPolyline(DrawingGroup g, Color accent) {
   Add(g, null, Stroke(Ink, 1.4), new EllipseGeometry(new Point(8, 10), 3.4, 3.4));
   Add(g, null, Stroke(Ink, 1.4), Curve(4, 24, 8, 16, 11, 27, 14, 21));
   Add(g, null, Stroke(Dim, 1.3), Poly(false, 5, 16.5, 12, 16.5));
   Add(g, null, Stroke(accent, 1.5), Poly(false, 19, 24, 23, 16, 26, 23, 29, 13));
   Arrow(g, 16, 19, 18.5, 19);
  }

  static void SelectSimilar(DrawingGroup g, Color accent) {
   Add(g, null, Dashed(accent, 1.2), new RectangleGeometry(new Rect(3.5, 5, 19, 18), 2, 2));
   Box(g, Fill(accent), null, 6, 8, 5, 5);
   Box(g, Fill(accent), null, 13, 8, 5, 5);
   Box(g, Fill(accent), null, 6, 15, 5, 5);
   Box(g, Fill(Dim), null, 13, 15, 5, 5);
   Cursor(g);
  }

  static void SelectExact(DrawingGroup g, Color accent) {
   Add(g, null, Dashed(accent, 1.2), new RectangleGeometry(new Rect(3.5, 5, 19, 18), 2, 2));
   Box(g, Fill(accent), null, 6, 8, 5, 5);
   Box(g, Fill(accent), null, 13, 8, 5, 5);
   Box(g, Fill(accent), null, 6, 15, 5, 5);
   Add(g, null, Stroke(Yellow, 2), Poly(false, 13.5, 18, 15.5, 20, 19.5, 14));
  }

  static void SelectHatch(DrawingGroup g, Color accent) {
   Add(g, null, Dashed(accent, 1.2), new RectangleGeometry(new Rect(3.5, 6, 20, 19), 2, 2));
   Hatch(g, Ink, 6, 9, 15, 13);
   Add(g, null, Stroke(Yellow, 1.6), new EllipseGeometry(new Point(25, 8), 2.6, 2.6));
  }

  static void Drip(DrawingGroup g, Color accent) {
   RBox(g, null, Stroke(Ink, 1.2), 3.5, 8, 25, 19, 2);
   Add(g, null, Stroke(accent, 1.5), Poly(false, 6, 23, 11, 13, 15, 23, 19, 13, 23, 23));
   Add(g, Fill(Yellow), null, Poly(true, 26, 8, 27.6, 11, 26, 12.6, 24.4, 11));
  }

  static void Linetype(DrawingGroup g, Color accent) {
   Box(g, Fill(Ink), null, 8, 9, 16, 2.6);
   Box(g, Fill(Ink), null, 11, 14, 10, 2.6);
   Add(g, null, Stroke(accent, 2.0), Poly(false, 3.5, 24, 9, 24));
   Box(g, Fill(accent), null, 11.5, 23.2, 1.8, 1.8);
   Add(g, null, Stroke(accent, 2.0), Poly(false, 15, 24, 20.5, 24));
   Box(g, Fill(accent), null, 23, 23.2, 1.8, 1.8);
   Add(g, null, Stroke(accent, 2.0), Poly(false, 26.5, 24, 29, 24));
  }

  static void Layers(DrawingGroup g, Color accent) {
   Add(g, null, Stroke(accent, 1.4), Poly(true, 16, 5, 27, 10, 16, 15, 5, 10));
   Add(g, null, Stroke(Ink, 1.3), Poly(false, 5, 15, 16, 20, 27, 15));
   Add(g, null, Stroke(Dim, 1.2), Poly(false, 5, 20, 16, 25, 27, 20));
  }

  static void LayerAdd(DrawingGroup g, Color accent) {
   Add(g, null, Stroke(accent, 1.4), Poly(true, 15, 5, 25, 9.5, 15, 14, 5, 9.5));
   Add(g, null, Stroke(Ink, 1.2), Poly(false, 5, 14, 15, 18.5, 25, 14));
   Add(g, null, Stroke(Yellow, 1.8), Poly(false, 25, 19, 25, 25));
   Add(g, null, Stroke(Yellow, 1.8), Poly(false, 22, 22, 28, 22));
  }

  static void Measure(DrawingGroup g, Color accent) {
   Add(g, null, Stroke(accent, 1.5), Poly(false, 5, 17, 27, 17));
   Add(g, null, Stroke(accent, 1.5), Poly(false, 5, 14, 5, 20));
   Add(g, null, Stroke(accent, 1.5), Poly(false, 27, 14, 27, 20));
   Add(g, null, Stroke(Ink, 1.1), Poly(false, 10, 12, 10, 22));
   Add(g, null, Stroke(Ink, 1.1), Poly(false, 16, 12, 16, 22));
   Add(g, null, Stroke(Ink, 1.1), Poly(false, 22, 12, 22, 22));
   Arrow(g, 8, 17, 24, 17);
  }

  static void Number(DrawingGroup g, Color accent) {
   RBox(g, null, Stroke(accent, 1.4), 5, 5, 15, 11, 2.5);
   Add(g, Fill(Ink), null, Poly(true, 8, 16, 12, 16, 8, 20));
   Box(g, Fill(Ink), null, 8, 9, 9, 2);
   Add(g, null, Stroke(Dim, 1.2), Poly(false, 14, 19, 20, 25));
   Dot(g, Fill(Yellow), 21.5, 26, 2.2);
  }

  static void Copy(DrawingGroup g, Color accent) {
   RBox(g, null, Stroke(accent, 1.4), 4, 5, 13, 13, 2);
   RBox(g, null, Stroke(Ink, 1.3), 12, 13, 13, 13, 2);
   Add(g, null, Stroke(Yellow, 1.8), Poly(false, 25.5, 5, 25.5, 11));
   Add(g, null, Stroke(Yellow, 1.8), Poly(false, 22.5, 8, 28.5, 8));
  }

  static void MTextToText(DrawingGroup g, Color accent) {
   Add(g, null, Dashed(accent, 1.1), new RectangleGeometry(new Rect(3.5, 6, 11, 20), 1.5, 1.5));
   Box(g, Fill(Ink), null, 5.5, 9, 7, 2);
   Box(g, Fill(Ink), null, 5.5, 13, 7, 2);
   Box(g, Fill(Ink), null, 5.5, 17, 7, 2);
   Arrow(g, 15.5, 16, 20.5, 16);
   Box(g, Fill(Ink), null, 22, 13.5, 6.5, 2.4);
   Box(g, Fill(Dim), null, 22, 18, 6.5, 2.4);
  }

  static void TextToMText(DrawingGroup g, Color accent) {
   Box(g, Fill(Ink), null, 3.5, 8, 7, 2.2);
   Box(g, Fill(Ink), null, 3.5, 13.5, 7, 2.2);
   Box(g, Fill(Ink), null, 3.5, 19, 7, 2.2);
   Arrow(g, 11.5, 15, 16.5, 15);
   Add(g, null, Stroke(accent, 1.2), Poly(false, 19, 6, 19, 25));
   Box(g, Fill(Ink), null, 21, 8, 7, 2);
   Box(g, Fill(Ink), null, 21, 13, 7, 2);
   Box(g, Fill(Ink), null, 21, 18, 7, 2);
  }

  static void Palette(DrawingGroup g, Color accent) {
   RBox(g, null, Stroke(accent, 1.3), 3, 4, 26, 24, 2);
   Add(g, null, Stroke(Ink, 1.1), Poly(false, 3, 9.5, 29, 9.5));
   Box(g, Fill(accent), null, 6, 12.5, 7, 4.5);
   Box(g, Fill(Ink), null, 15.5, 12.5, 7, 4.5);
   Box(g, Fill(Ink), null, 6, 19, 7, 4.5);
   Box(g, Fill(accent), null, 15.5, 19, 7, 4.5);
   Star(g, 25.5, 6.8, 3.2, 1.4, Yellow);
  }

  static void Quick(DrawingGroup g, Color accent) {
   Star(g, 16, 14.5, 9.5, 4.1, Yellow);
   Add(g, null, Stroke(accent, 1.8), Poly(false, 6, 27, 26, 27));
  }

  static void Toolbar(DrawingGroup g, Color accent) {
   RBox(g, null, Stroke(accent, 1.3), 3, 8, 26, 11, 2);
   Box(g, Fill(Ink), null, 5.5, 10.5, 5.5, 6);
   Box(g, Fill(Ink), null, 13, 10.5, 5.5, 6);
   Box(g, Fill(Ink), null, 20.5, 10.5, 5.5, 6);
   Star(g, 16, 24, 4.6, 2.0, Yellow);
  }

  static void Settings(DrawingGroup g, Color accent) {
   // Banh rang: 8 rang + lo giua.
   var ring = new StreamGeometry();
   using (StreamGeometryContext c = ring.Open()) {
    for (int i = 0; i < 8; i++) {
     double a0 = i * Math.PI / 4;
     double a1 = a0 + Math.PI / 8;
     double a2 = a0 + Math.PI / 4;
     var p0 = new Point(16 + 10 * Math.Cos(a0), 16 + 10 * Math.Sin(a0));
     var p1 = new Point(16 + 12.5 * Math.Cos(a1), 16 + 12.5 * Math.Sin(a1));
     var p2 = new Point(16 + 10 * Math.Cos(a2), 16 + 10 * Math.Sin(a2));
     if (i == 0) c.BeginFigure(p0, true, true);
     else c.LineTo(p0, true, false);
     c.LineTo(p1, true, false);
     c.LineTo(p2, true, false);
    }
   }
   ring.Freeze();
   Add(g, Fill(accent), null, ring);
   Add(g, Fill(Tile), null, new EllipseGeometry(new Point(16, 16), 4.6, 4.6));
   Add(g, null, Stroke(Ink, 1.1), new EllipseGeometry(new Point(16, 16), 4.6, 4.6));
   Dot(g, Fill(Yellow), 26.5, 6.5, 2.4);
  }

  static void TitleBlock(DrawingGroup g, Color accent) {
   // To giay + khung bao trong + khung ten goc phai duoi.
   Box(g, null, Stroke(Ink, 1.2), 4, 4.5, 24, 23);
   Add(g, null, Stroke(accent, 1.0), new RectangleGeometry(new Rect(6.5, 7, 19, 18)));
   Box(g, Fill(accent), null, 15.5, 7, 10, 5.5);
   Add(g, null, Stroke(Tile, 0.9), Poly(false, 15.5, 8.8, 25.5, 8.8));
   Add(g, null, Stroke(Tile, 0.9), Poly(false, 15.5, 10.6, 25.5, 10.6));
   Add(g, null, Stroke(Ink, 1.0), Poly(false, 9, 14.5, 23, 14.5));
   Add(g, null, Stroke(Ink, 1.0), Poly(false, 9, 18, 23, 18));
   Add(g, null, Stroke(Ink, 1.0), Poly(false, 9, 21.5, 23, 21.5));
  }

  static void TitleSync(DrawingGroup g, Color accent) {
   // To giay ben trai, mui ten dong bo sang phai = dien thong tin hang loat.
   Box(g, null, Stroke(Ink, 1.2), 3, 5, 16, 22);
   Box(g, Fill(accent), null, 5, 6.5, 12, 5);
   Add(g, null, Stroke(Ink, 1.1), Poly(false, 5, 14.5, 17, 14.5));
   Add(g, null, Stroke(Ink, 1.1), Poly(false, 5, 18, 17, 18));
   Add(g, null, Stroke(Ink, 1.1), Poly(false, 5, 21.5, 17, 21.5));
   Arrow(g, 20, 16, 28.5, 16);
  }

  static void Fallback(DrawingGroup g, Color accent) {
   Add(g, null, Stroke(accent, 1.4), new EllipseGeometry(new Point(16, 16), 8, 8));
   Add(g, null, Stroke(Ink, 1.2), Poly(false, 16, 4, 16, 12));
   Add(g, null, Stroke(Ink, 1.2), Poly(false, 16, 28, 16, 20));
   Add(g, null, Stroke(Ink, 1.2), Poly(false, 4, 16, 12, 16));
   Add(g, null, Stroke(Ink, 1.2), Poly(false, 28, 16, 20, 16));
  }
 }
}
