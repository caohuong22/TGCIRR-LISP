using System;
using System.Collections.Generic;
using System.Globalization;

namespace Tgirrr.CadLisp {
 /// <summary>
 /// Tinh tong chieu dai cho lenh TL. Phan thuan C# (khong phu thuoc CAD) de test hoi quy.
 /// </summary>
 internal static class TotalLengthService {
  internal const string EmptyMessage =
   "Chưa chọn đối tượng hợp lệ.\n\nHãy chọn trước Line, Arc, Circle, Polyline, Ellipse hoặc Spline, sau đó bấm TL.";

  internal static double Sum(IEnumerable<double> lengths) {
   double total = 0;
   if (lengths == null) return total;
   foreach (double length in lengths) {
    if (double.IsNaN(length) || double.IsInfinity(length) || length <= 0) continue;
    total += length;
   }
   return total;
  }

  /// <summary>rtos cua CAD dung dau cham thap phan, khong phu thuoc culture Windows.</summary>
  internal static string Message(double total) {
   return "Tổng chiều dài = " + total.ToString("0.####", CultureInfo.InvariantCulture);
  }
 }
}
