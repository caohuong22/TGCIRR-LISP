using System;
using System.Collections.Generic;
using System.Linq;
using Tgirrr.CadLisp;

class Tests {
 static int passed;
 static void Check(string name, bool ok) { if (!ok) throw new Exception("FAILED: " + name); Console.WriteLine("PASS: " + name); passed++; }

 static void Main() {
  // --- Bo Layer chuan ---
  Check("standard layer count", LayerSetService.Standard.Length == 24);
  Check("standard has spaced names", LayerSetService.Standard.Any(x => x.Name == "TG-MAIN PIPE") && LayerSetService.Standard.Any(x => x.Name == "TG-PIPE 32"));
  Check("standard current layer exists", LayerSetService.Standard.Any(x => x.Name == LayerSetService.CurrentLayer));
  Check("standard colors are ACI", LayerSetService.Standard.All(x => { int aci; return int.TryParse(x.Color, out aci) && aci >= 1 && aci <= 255; }));
  Check("standard linetypes", LayerSetService.Standard.All(x => x.Linetype == "Continuous"));

  // --- Mau ACI ---
  Check("color 34", LayerSetService.NormalizeColor("34") == "34");
  Check("color trims", LayerSetService.NormalizeColor(" 42 ") == "42");
  Check("color zero -> 7", LayerSetService.NormalizeColor("0") == "7");
  Check("color 256 -> 7", LayerSetService.NormalizeColor("256") == "7");
  Check("color text -> 7", LayerSetService.NormalizeColor("abc") == "7");
  Check("color empty -> 7", LayerSetService.NormalizeColor("") == "7");
  Check("color null -> 7", LayerSetService.NormalizeColor(null) == "7");

  // --- Doc kho Layer (dinh dang vl-prin1-to-string cua ban LISP) ---
  var one = LayerSetService.Parse("(\"TG-PIPE 32\" \"40\" \"Continuous\")");
  Check("parse one record", one.Count == 1 && one[0].Name == "TG-PIPE 32" && one[0].Color == "40" && one[0].Linetype == "Continuous");
  var many = LayerSetService.Parse("(\"A\" \"1\" \"Continuous\")(\"B\" \"2\" \"DASHED\")");
  Check("parse many records", many.Count == 2 && many[1].Name == "B" && many[1].Linetype == "DASHED");
  Check("parse empty", LayerSetService.Parse("").Count == 0 && LayerSetService.Parse(null).Count == 0);
  Check("parse ignores malformed", LayerSetService.Parse("(\"A\" \"1\")(\"B\" \"2\" \"Continuous\")junk").Count == 1);
  Check("parse accepts unquoted", LayerSetService.Parse("(RAW 5 Continuous)").Count == 1);

  // --- Ghi kho Layer ---
  var entries = new List<LayerEntry> { new LayerEntry("TG-X", "7", "Continuous"), new LayerEntry("CO NGOAC \"X\"", "2", "DASHED") };
  string raw = LayerSetService.Format(entries);
  var back = LayerSetService.Parse(raw);
  Check("format/parse roundtrip", back.Count == 2 && back[1].Name == "CO NGOAC \"X\"" && back[1].Color == "2");
  Check("format skips empty names", LayerSetService.Format(new[] { new LayerEntry("", "7", "Continuous"), new LayerEntry("OK", "7", "Continuous") }) == "(\"OK\" \"7\" \"Continuous\")");
  Check("format null", LayerSetService.Format(null) == "");

  // --- Total length ---
  Check("sum empty", TotalLengthService.Sum(new double[0]) == 0);
  Check("sum null", TotalLengthService.Sum(null) == 0);
  Check("sum values", Math.Abs(TotalLengthService.Sum(new[] { 1.5, 2.25 }) - 3.75) < 1e-9);
  Check("sum ignores invalid", Math.Abs(TotalLengthService.Sum(new[] { 1.0, -2.0, double.NaN, double.PositiveInfinity }) - 1.0) < 1e-9);
  Check("message invariant decimal", TotalLengthService.Message(1234.5) == "Tổng chiều dài = 1234.5");
  Check("message zero", TotalLengthService.Message(0) == "Tổng chiều dài = 0");
  Check("message rounds 4 decimals", TotalLengthService.Message(2.123456) == "Tổng chiều dài = 2.1235");
  Check("empty selection message", TotalLengthService.EmptyMessage.Contains("Chưa chọn đối tượng hợp lệ"));

  Console.WriteLine($"LayerSet regression: {passed} tests passed.");
 }
}
