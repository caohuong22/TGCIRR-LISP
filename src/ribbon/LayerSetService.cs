using System;
using System.Collections.Generic;
using System.Globalization;
using System.Text;

namespace Tgirrr.CadLisp {
 /// <summary>Mot mau Layer trong bo chuan hoac trong kho Layer tu them.</summary>
 internal sealed class LayerEntry {
  internal string Name, Color, Linetype;

  internal LayerEntry(string name, string color, string linetype) {
   Name = name;
   Color = color;
   Linetype = linetype;
  }
 }

 /// <summary>
 /// Du lieu thuan C# cho TGL: bo Layer chuan + doc/ghi kho Layer dang chuoi
 /// S-expression ("(\"Ten\" \"Mau\" \"Net\")") de tuong thich voi kho cua ban AutoLISP cu.
 /// </summary>
 internal static class LayerSetService {
  internal const string DefaultColor = "7";
  internal const string DefaultLinetype = "Continuous";
  internal const string CurrentLayer = "TG-DRIP";

  internal static readonly LayerEntry[] Standard = new[] {
   new LayerEntry("TG-DRIP", "34", "Continuous"),
   new LayerEntry("TG-DKT", "2", "Continuous"),
   new LayerEntry("TG-MAIN PIPE", "1", "Continuous"),
   new LayerEntry("TG-BOUND", "7", "Continuous"),
   new LayerEntry("TG-SIG", "7", "Continuous"),
   new LayerEntry("TG-TEXT", "7", "Continuous"),
   new LayerEntry("TG-FREEZE", "7", "Continuous"),
   new LayerEntry("TG-VUNG", "7", "Continuous"),
   new LayerEntry("TG-BDK", "7", "Continuous"),
   new LayerEntry("TG-PIPE 32", "40", "Continuous"),
   new LayerEntry("TG-PIPE 40", "3", "Continuous"),
   new LayerEntry("TG-PIPE 50", "6", "Continuous"),
   new LayerEntry("TG-PIPE 63", "6", "Continuous"),
   new LayerEntry("TG-PIPE 75", "5", "Continuous"),
   new LayerEntry("TG-PIPE 90", "5", "Continuous"),
   new LayerEntry("TG-SPR", "1", "Continuous"),
   new LayerEntry("TG-VALVE", "42", "Continuous"),
   new LayerEntry("TG-WIRE", "42", "Continuous"),
   new LayerEntry("TG-CUV", "150", "Continuous"),
   new LayerEntry("TG-XOE", "42", "Continuous"),
   new LayerEntry("TG-XA KHI", "114", "Continuous"),
   new LayerEntry("TG-QCV", "7", "Continuous"),
   new LayerEntry("TG-LDPE 20", "4", "Continuous"),
   new LayerEntry("TG-number", "7", "Continuous")
  };

  /// <summary>Mau ACI hop le (1-255); gia tri loi quay ve mau 7 nhu ban LISP.</summary>
  internal static string NormalizeColor(string value) {
   int aci;
   if (int.TryParse((value ?? "").Trim(), NumberStyles.Integer, CultureInfo.InvariantCulture, out aci) && aci >= 1 && aci <= 255)
    return aci.ToString(CultureInfo.InvariantCulture);
   return DefaultColor;
  }

  /// <summary>Doc chuoi do vl-prin1-to-string sinh ra; bo qua phan tu hong.</summary>
  internal static List<LayerEntry> Parse(string raw) {
   var result = new List<LayerEntry>();
   if (string.IsNullOrWhiteSpace(raw)) return result;
   int i = 0;
   while (i < raw.Length) {
    if (raw[i] != '(') { i++; continue; }
    i++;
    var parts = new List<string>();
    while (i < raw.Length && raw[i] != ')') {
     if (char.IsWhiteSpace(raw[i])) { i++; continue; }
     if (raw[i] == '"') {
      i++;
      var text = new StringBuilder();
      while (i < raw.Length && raw[i] != '"') {
       if (raw[i] == '\\' && i + 1 < raw.Length) i++;
       text.Append(raw[i]);
       i++;
      }
      if (i < raw.Length) i++;
      parts.Add(text.ToString());
     } else {
      int start = i;
      while (i < raw.Length && raw[i] != ')' && !char.IsWhiteSpace(raw[i])) i++;
      parts.Add(raw.Substring(start, i - start));
     }
    }
    if (i < raw.Length && raw[i] == ')') i++;
    if (parts.Count == 3 && !string.IsNullOrWhiteSpace(parts[0]))
     result.Add(new LayerEntry(parts[0].Trim(), NormalizeColor(parts[1]), string.IsNullOrWhiteSpace(parts[2]) ? DefaultLinetype : parts[2].Trim()));
   }
   return result;
  }

  /// <summary>Ghi theo dung dinh dang ma AutoLISP <c>read</c> doc lai duoc.</summary>
  internal static string Format(IEnumerable<LayerEntry> entries) {
   var text = new StringBuilder();
   if (entries == null) return "";
   foreach (LayerEntry entry in entries) {
    if (entry == null || string.IsNullOrWhiteSpace(entry.Name)) continue;
    text.Append("(\"").Append(Escape(entry.Name)).Append("\" \"")
        .Append(Escape(entry.Color)).Append("\" \"")
        .Append(Escape(entry.Linetype)).Append("\")");
   }
   return text.ToString();
  }

  static string Escape(string value) {
   return (value ?? "").Replace("\\", "\\\\").Replace("\"", "\\\"");
  }
 }
}
