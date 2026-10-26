using System;
using System.Collections.Generic;
using System.Linq;

namespace Tgirrr.CadLisp {
 internal struct PolyVertex {
  internal double X, Y;
  internal PolyVertex(double x, double y) { X = x; Y = y; }
 }

 /// <summary>
 /// Mot doan duong da chuan hoa: Points[i] -> Points[i+1] co bulge Bulges[i].
 /// Polyline kin: bulge cuoi la doan noi diem cuoi ve diem dau.
 /// </summary>
 internal sealed class PolyPiece {
  internal readonly List<PolyVertex> Points = new List<PolyVertex>();
  internal readonly List<double> Bulges = new List<double>();
  internal bool Closed;
  internal double Elevation;

  internal PolyPiece Clone() {
   var copy = new PolyPiece { Closed = Closed, Elevation = Elevation };
   copy.Points.AddRange(Points);
   copy.Bulges.AddRange(Bulges);
   return copy;
  }
 }

 /// <summary>
 /// Hinh hoc thuan C# cho CVPL: tao doan (line/arc/circle/sample), dao chieu va noi
 /// cac manh roi thanh polyline lien tuc (dung cho REGION sau khi explode).
 /// </summary>
 internal static class PolylineGeometry {
  internal const int SampleCount = 128;
  internal const double JoinTolerance = 1e-6;

  /// <summary>Goc quet nguoc chieu kim dong ho trong (0, 2*pi].</summary>
  internal static double Sweep(double start, double end) {
   double delta = end - start;
   while (delta <= 0) delta += 2 * Math.PI;
   while (delta > 2 * Math.PI) delta -= 2 * Math.PI;
   return delta;
  }

  internal static double BulgeFromAngles(double start, double end) {
   return Math.Tan(Sweep(start, end) / 4.0);
  }

  internal static PolyPiece Line(PolyVertex a, PolyVertex b) {
   return FromVerticesInternal(new[] { a, b }, new[] { 0.0 }, false, 0);
  }

  internal static PolyPiece Arc(double cx, double cy, double radius, double start, double end, double elevation) {
   double sweep = Sweep(start, end);
   double finish = start + sweep;
   var piece = FromVerticesInternal(
    new[] {
     new PolyVertex(cx + radius * Math.Cos(start), cy + radius * Math.Sin(start)),
     new PolyVertex(cx + radius * Math.Cos(finish), cy + radius * Math.Sin(finish))
    },
    new[] { Math.Tan(sweep / 4.0) }, false, elevation);
   return piece;
  }

  internal static PolyPiece Circle(double cx, double cy, double radius, double elevation) {
   double b = Math.Tan(Math.PI / 8.0);
   var points = new[] {
    new PolyVertex(cx + radius, cy),
    new PolyVertex(cx, cy + radius),
    new PolyVertex(cx - radius, cy),
    new PolyVertex(cx, cy - radius)
   };
   return FromVerticesInternal(points, new[] { b, b, b, b }, true, elevation);
  }

  internal static PolyPiece Sampled(IEnumerable<PolyVertex> points, bool closed, double elevation) {
   if (points == null) return null;
   var list = points.ToList();
   if (closed && list.Count > 1 && Near(list[0], list[list.Count - 1], JoinTolerance)) list.RemoveAt(list.Count - 1);
   if (list.Count < 2) return null;
   var bulges = new double[closed ? list.Count : list.Count - 1];
   return FromVerticesInternal(list, bulges, closed, elevation);
  }

  internal static PolyPiece FromVertices(IEnumerable<PolyVertex> points, IEnumerable<double> bulges, bool closed, double elevation) {
   if (points == null) return null;
   var list = points.ToList();
   if (list.Count < 2) return null;
   var bulgeList = bulges == null ? new List<double>() : bulges.ToList();
   if (closed) {
    while (bulgeList.Count < list.Count) bulgeList.Add(0.0);
    if (bulgeList.Count > list.Count) bulgeList = bulgeList.Take(list.Count).ToList();
   } else {
    while (bulgeList.Count < list.Count - 1) bulgeList.Add(0.0);
    if (bulgeList.Count > list.Count - 1) bulgeList = bulgeList.Take(list.Count - 1).ToList();
   }
   return FromVerticesInternal(list, bulgeList, closed, elevation);
  }

  static PolyPiece FromVerticesInternal(IReadOnlyList<PolyVertex> points, IReadOnlyList<double> bulges, bool closed, double elevation) {
   var piece = new PolyPiece { Closed = closed, Elevation = elevation };
   piece.Points.AddRange(points);
   piece.Bulges.AddRange(bulges);
   return piece;
  }

  internal static PolyPiece Reverse(PolyPiece source) {
   if (source == null || source.Points.Count < 2) return source == null ? null : source.Clone();
   var result = new PolyPiece { Closed = source.Closed, Elevation = source.Elevation };
   for (int i = source.Points.Count - 1; i >= 0; i--) result.Points.Add(source.Points[i]);
   int n = source.Points.Count;
   if (source.Closed) {
    for (int i = 0; i < n; i++) result.Bulges.Add(-source.Bulges[(n - 2 - i + n) % n]);
   } else {
    for (int i = 0; i < n - 1; i++) result.Bulges.Add(-source.Bulges[n - 2 - i]);
   }
   return result;
  }

  internal static bool Near(PolyVertex a, PolyVertex b, double tolerance) {
   return Math.Abs(a.X - b.X) <= tolerance && Math.Abs(a.Y - b.Y) <= tolerance;
  }

  /// <summary>Noi cac manh roi theo diem dau/cuoi; manh kin duoc giu nguyen thanh vong rieng.</summary>
  internal static List<PolyPiece> Join(IEnumerable<PolyPiece> pieces, double tolerance) {
   var output = new List<PolyPiece>();
   var open = new List<PolyPiece>();
   if (pieces != null) {
    foreach (PolyPiece piece in pieces) {
     if (piece == null || piece.Points.Count < 2) continue;
     if (piece.Closed) {
      output.Add(piece.Clone());
      continue;
     }
     if (piece.Points.Count > 2 && Near(piece.Points[0], piece.Points[piece.Points.Count - 1], tolerance)) {
      var loop = piece.Clone();
      CloseLoop(loop);
      output.Add(loop);
      continue;
     }
     open.Add(piece.Clone());
    }
   }
   while (open.Count > 0) {
    PolyPiece chain = open[0];
    open.RemoveAt(0);
    bool progress = true;
    while (!chain.Closed && progress) {
     progress = false;
     PolyVertex last = chain.Points[chain.Points.Count - 1];
     for (int i = 0; i < open.Count; i++) {
      PolyPiece candidate = open[i];
      if (Near(last, candidate.Points[0], tolerance)) {
       Append(chain, candidate);
       open.RemoveAt(i);
       progress = true;
       break;
      }
      if (Near(last, candidate.Points[candidate.Points.Count - 1], tolerance)) {
       Append(chain, Reverse(candidate));
       open.RemoveAt(i);
       progress = true;
       break;
      }
     }
     if (!chain.Closed && chain.Points.Count > 2 && Near(chain.Points[0], chain.Points[chain.Points.Count - 1], tolerance))
      CloseLoop(chain);
    }
    output.Add(chain);
   }
   return output;
  }

  static void Append(PolyPiece chain, PolyPiece next) {
   for (int i = 1; i < next.Points.Count; i++) chain.Points.Add(next.Points[i]);
   chain.Bulges.AddRange(next.Bulges);
  }

  /// <summary>Diem cuoi trung diem dau: bo diem trung va giu bulge cua doan noi lam bulge dong kin.</summary>
  static void CloseLoop(PolyPiece piece) {
   piece.Points.RemoveAt(piece.Points.Count - 1);
   piece.Closed = true;
  }
 }
}
