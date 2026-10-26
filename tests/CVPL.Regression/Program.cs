using System;
using System.Collections.Generic;
using System.Linq;
using Tgirrr.CadLisp;

class Tests {
 static int passed;
 static void Check(string name, bool ok) { if (!ok) throw new Exception("FAILED: " + name); Console.WriteLine("PASS: " + name); passed++; }
 static PolyVertex P(double x, double y) { return new PolyVertex(x, y); }
 static bool Near(double a, double b) { return Math.Abs(a - b) < 1e-9; }

 static void Main() {
  // --- Line / Arc / Circle ---
  var line = PolylineGeometry.Line(P(0, 0), P(10, 5));
  Check("line points", line.Points.Count == 2 && Near(line.Points[1].X, 10) && Near(line.Points[1].Y, 5));
  Check("line not closed", !line.Closed && line.Bulges.Count == 1 && Near(line.Bulges[0], 0));

  var arc = PolylineGeometry.Arc(0, 0, 5, 0, Math.PI / 2, 2);
  Check("arc endpoints", Near(arc.Points[0].X, 5) && Near(arc.Points[0].Y, 0) && Near(arc.Points[1].X, 0) && Near(arc.Points[1].Y, 5));
  Check("arc bulge", arc.Bulges.Count == 1 && Math.Abs(arc.Bulges[0] - Math.Tan(Math.PI / 8)) < 1e-9);
  Check("arc elevation", Near(arc.Elevation, 2));

  var half = PolylineGeometry.Arc(0, 0, 1, Math.PI, 0, 0);
  Check("arc wraps past 2pi", half.Bulges.Count == 1 && Math.Abs(half.Bulges[0] - 1.0) < 1e-9);

  var circle = PolylineGeometry.Circle(1, 2, 5, 3);
  Check("circle 4 points closed", circle.Points.Count == 4 && circle.Closed && circle.Bulges.Count == 4);
  Check("circle bulges", circle.Bulges.All(b => Math.Abs(b - Math.Tan(Math.PI / 8)) < 1e-9));
  Check("circle elevation", Near(circle.Elevation, 3));

  // --- Sample + closed detection ---
  var sampled = PolylineGeometry.Sampled(new[] { P(0, 0), P(10, 0), P(10, 10), P(0, 0) }, true, 0);
  Check("sampled drops duplicate end", sampled.Points.Count == 3 && sampled.Closed);
  var sampledOpen = PolylineGeometry.Sampled(new[] { P(0, 0), P(5, 5), P(10, 0) }, false, 0);
  Check("sampled open", sampledOpen.Points.Count == 3 && !sampledOpen.Closed && sampledOpen.Bulges.Count == 2);
  Check("sampled too few", PolylineGeometry.Sampled(new[] { P(0, 0) }, false, 0) == null);

  // --- Reverse ---
  var open = PolylineGeometry.FromVertices(new[] { P(0, 0), P(10, 0), P(20, 0) }, new[] { 0.5, 0.0 }, false, 0);
  var reversed = PolylineGeometry.Reverse(open);
  Check("reverse open points", reversed.Points[0].X == 20 && reversed.Points[2].X == 0);
  Check("reverse open bulges", Math.Abs(reversed.Bulges[0]) < 1e-9 && Math.Abs(reversed.Bulges[1] + 0.5) < 1e-9);

  var loop = PolylineGeometry.FromVertices(new[] { P(0, 0), P(10, 0), P(10, 10), P(0, 10) }, new[] { 1.0, 2.0, 3.0, 4.0 }, true, 0);
  var loopBack = PolylineGeometry.Reverse(loop);
  Check("reverse closed points", loopBack.Points[0].X == 0 && loopBack.Points[0].Y == 10 && loopBack.Points[3].X == 0 && loopBack.Points[3].Y == 0);
  Check("reverse closed bulges", loopBack.Bulges.SequenceEqual(new[] { -3.0, -2.0, -1.0, -4.0 }));

  // --- Join ---
  var a = PolylineGeometry.Line(P(0, 0), P(10, 0));
  var b = PolylineGeometry.Line(P(10, 0), P(10, 10));
  var joined = PolylineGeometry.Join(new[] { a, b }, 1e-6);
  Check("join two lines", joined.Count == 1 && joined[0].Points.Count == 3 && !joined[0].Closed);

  var reversedPiece = PolylineGeometry.Line(P(10, 10), P(10, 0));
  var joinedReverse = PolylineGeometry.Join(new[] { a, reversedPiece }, 1e-6);
  Check("join reversed piece", joinedReverse.Count == 1 && Near(joinedReverse[0].Points[2].Y, 10));

  var square = new[] {
   PolylineGeometry.Line(P(0, 0), P(10, 0)),
   PolylineGeometry.Line(P(10, 0), P(10, 10)),
   PolylineGeometry.Line(P(10, 10), P(0, 10)),
   PolylineGeometry.Line(P(0, 10), P(0, 0))
  };
  var closed = PolylineGeometry.Join(square, 1e-6);
  Check("join closes square", closed.Count == 1 && closed[0].Closed && closed[0].Points.Count == 4);
  Check("join closed bulges", closed[0].Bulges.Count == 4);

  var separate = PolylineGeometry.Join(new[] { PolylineGeometry.Line(P(0, 0), P(1, 0)), PolylineGeometry.Line(P(5, 5), P(6, 5)) }, 1e-6);
  Check("join keeps separate pieces", separate.Count == 2);

  var alreadyClosed = PolylineGeometry.Circle(0, 0, 1, 0);
  var kept = PolylineGeometry.Join(new[] { alreadyClosed }, 1e-6);
  Check("join keeps closed input", kept.Count == 1 && kept[0].Closed && kept[0].Points.Count == 4);

  var gap = PolylineGeometry.Line(P(0, 0), P(10, 0));
  var nearGap = PolylineGeometry.Line(P(10.0000005, 0), P(20, 0));
  Check("join tolerance", PolylineGeometry.Join(new[] { gap, nearGap }, 1e-6).Count == 1);
  Check("join outside tolerance", PolylineGeometry.Join(new[] { gap, PolylineGeometry.Line(P(10.001, 0), P(20, 0)) }, 1e-6).Count == 2);

  Check("join ignores short pieces", PolylineGeometry.Join(new[] { PolylineGeometry.Line(P(0, 0), P(0, 0)), a }, 1e-6).Count == 1);

  // --- FromVertices padding ---
  var padded = PolylineGeometry.FromVertices(new[] { P(0, 0), P(1, 1) }, null, false, 0);
  Check("bulges padded", padded.Bulges.Count == 1 && padded.Bulges[0] == 0);

  Console.WriteLine($"CVPL regression: {passed} tests passed.");
 }
}
