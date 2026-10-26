using System;
using System.Collections.Generic;

namespace Tgirrr.CadLisp {
 internal enum NumberOrder { Pick, X, Y, Path }

 internal sealed class NumberSettings {
  internal int Start = 1;
  internal int Step = 1;
  internal double Width = 8.0;
  internal double Height = 8.0;
  internal double TextHeight = 3.0;
  internal bool RegionsOnly;
  internal NumberOrder Order = NumberOrder.Pick;

  internal NumberSettings Clone() {
   return new NumberSettings {
    Start = Start, Step = Step, Width = Width, Height = Height,
    TextHeight = TextHeight, RegionsOnly = RegionsOnly, Order = Order
   };
  }
 }

 internal sealed class NumberItem {
  internal int Index;
  internal double X, Y, Z, PathDistance;
 }

 /// <summary>Thuat toan thuan C# cho TGN: kiem tra tham so, sap xep va khoang cach theo duong dan.</summary>
 internal static class NumberingService {
  internal const string ValidationError = "Nhập số hợp lệ; kích thước > 0 và bước nhảy khác 0.";
  const double Tolerance = 1e-8;

  internal static bool Validate(int step, double width, double height, double textHeight) {
   return step != 0 && width > 0 && height > 0 && textHeight > 0;
  }

  /// <summary>Khoang cach tren polyline ke tu diem bat dau, quay vong khi qua cuoi.</summary>
  internal static double PathDistance(double closest, double start, double total) {
   return closest >= start ? closest - start : (total - start) + closest;
  }

  internal static List<NumberItem> Sort(IEnumerable<NumberItem> items, NumberOrder order) {
   var list = new List<NumberItem>(items ?? new NumberItem[0]);
   switch (order) {
    case NumberOrder.X: list.Sort(CompareX); break;
    case NumberOrder.Y: list.Sort(CompareY); break;
    case NumberOrder.Path: list.Sort(delegate(NumberItem a, NumberItem b) { return a.PathDistance.CompareTo(b.PathDistance); }); break;
    default: list.Sort(delegate(NumberItem a, NumberItem b) { return a.Index.CompareTo(b.Index); }); break;
   }
   return list;
  }

  static int CompareX(NumberItem a, NumberItem b) {
   if (Math.Abs(a.Y - b.Y) > Tolerance) return b.Y.CompareTo(a.Y);
   return a.X.CompareTo(b.X);
  }

  static int CompareY(NumberItem a, NumberItem b) {
   if (Math.Abs(a.X - b.X) > Tolerance) return a.X.CompareTo(b.X);
   return b.Y.CompareTo(a.Y);
  }
 }
}
