using System;
using System.Collections.Generic;
using System.Linq;
using Tgirrr.CadLisp;

class Tests {
 static int passed;
 static void Check(string name, bool ok) { if (!ok) throw new Exception("FAILED: " + name); Console.WriteLine("PASS: " + name); passed++; }
 static NumberItem Item(int index, double x, double y, double distance = 0) {
  return new NumberItem { Index = index, X = x, Y = y, Z = 0, PathDistance = distance };
 }
 static string Ids(IEnumerable<NumberItem> items) { return string.Join(",", items.Select(x => x.Index.ToString())); }

 static void Main() {
  // --- Kiem tra tham so ---
  Check("valid settings", NumberingService.Validate(1, 8, 8, 3));
  Check("step zero rejected", !NumberingService.Validate(0, 8, 8, 3));
  Check("negative step allowed", NumberingService.Validate(-2, 8, 8, 3));
  Check("zero width rejected", !NumberingService.Validate(1, 0, 8, 3));
  Check("negative height rejected", !NumberingService.Validate(1, 8, -1, 3));
  Check("zero text height rejected", !NumberingService.Validate(1, 8, 8, 0));

  // --- Khoang cach theo duong dan ---
  Check("path distance after start", Math.Abs(NumberingService.PathDistance(30, 10, 100) - 20) < 1e-9);
  Check("path distance wraps", Math.Abs(NumberingService.PathDistance(5, 10, 100) - 95) < 1e-9);
  Check("path distance at start", Math.Abs(NumberingService.PathDistance(10, 10, 100)) < 1e-9);
  Check("path distance at end", Math.Abs(NumberingService.PathDistance(100, 0, 100) - 100) < 1e-9);

  // --- Thu tu chon (giu nguyen) ---
  var pick = new[] { Item(2, 5, 5), Item(0, 1, 1), Item(1, 9, 9) };
  Check("pick keeps selection order", Ids(NumberingService.Sort(pick, NumberOrder.Pick)) == "0,1,2");

  // --- Trai sang phai, tren xuong duoi: Y giam dan, cung hang thi X tang ---
  var rows = new[] {
   Item(0, 10, 0), Item(1, 0, 0), Item(2, 5, 10), Item(3, 0, 10)
  };
  Check("sort x rows top-down then left-right", Ids(NumberingService.Sort(rows, NumberOrder.X)) == "3,2,1,0");

  // --- Tren xuong duoi, trai sang phai: X tang, cung cot thi Y giam ---
  var columns = new[] {
   Item(0, 10, 0), Item(1, 0, 0), Item(2, 0, 10), Item(3, 10, 10)
  };
  Check("sort y columns left-right then top-down", Ids(NumberingService.Sort(columns, NumberOrder.Y)) == "2,1,3,0");
  Check("sort x tolerance groups rows", Ids(NumberingService.Sort(new[] { Item(0, 5, 10), Item(1, 1, 9.999999999) }, NumberOrder.X)) == "1,0");
  Check("sort y tolerance groups columns", Ids(NumberingService.Sort(new[] { Item(0, 0, 0), Item(1, 0.000000001, 10) }, NumberOrder.Y)) == "1,0");

  // --- Theo duong dan ---
  var path = new[] {
   Item(0, 0, 0, 40), Item(1, 0, 0, 5), Item(2, 0, 0, 20)
  };
  Check("sort path ascending", Ids(NumberingService.Sort(path, NumberOrder.Path)) == "1,2,0");

  Check("sort empty", NumberingService.Sort(null, NumberOrder.X).Count == 0);

  Console.WriteLine($"TGN regression: {passed} tests passed.");
 }
}
