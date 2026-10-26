using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using ZwSoft.ZwCAD.ApplicationServices;
using ZwSoft.ZwCAD.Colors;
using ZwSoft.ZwCAD.DatabaseServices;
using ZwSoft.ZwCAD.EditorInput;
using ZwSoft.ZwCAD.Geometry;
using ZwSoft.ZwCAD.Runtime;

namespace Tgirrr.CadLisp {
 /// <summary>
 /// CVPL / CVP (xoa nguon) va CVPLG / CV2PL (giu nguon): chuyen LINE, ARC, CIRCLE,
 /// ELLIPSE, SPLINE, POLYLINE cu va REGION sang LWPOLYLINE, giu Layer/Mau/Net.
 /// </summary>
 public sealed class ConvertToPolylineCommands {
  const string FilterTypes = "LINE,ARC,CIRCLE,ELLIPSE,SPLINE,POLYLINE,LWPOLYLINE,REGION";

  sealed class EntityStyle {
   internal string Layer, Linetype;
   internal Color Color;
   internal LineWeight LineWeight;
   internal double LinetypeScale;
  }

  [CommandMethod("CVPL")]
  public void ConvertDelete() { Run(false); }

  [CommandMethod("CVP")]
  public void ConvertDeleteAlias() { Run(false); }

  [CommandMethod("CVPLG")]
  public void ConvertKeep() { Run(true); }

  [CommandMethod("CV2PL")]
  public void ConvertKeepAlias() { Run(true); }

  void Run(bool keep) {
   Document doc = ZwSoft.ZwCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;
   if (doc == null) return;
   Editor ed = doc.Editor;
   var filter = new SelectionFilter(new[] { new TypedValue((int)DxfCode.Start, FilterTypes) });
   PromptSelectionResult selection = ed.SelectImplied();
   if (selection.Status != PromptStatus.OK || selection.Value == null || selection.Value.Count == 0)
    selection = ed.GetSelection(filter);
   if (selection.Status != PromptStatus.OK || selection.Value == null || selection.Value.Count == 0) {
    ed.WriteMessage("\nCVPL: Không có đối tượng nào được chọn.");
    return;
   }
   ed.WriteMessage("\n[CVPL] Quét chọn LINE/ARC/CIRCLE/ELLIPSE/SPLINE/POLYLINE/REGION"
    + (keep ? " (GIỮ đối tượng nguồn):" : " (XÓA đối tượng nguồn):"));
   int made = 0, skipped = 0;
   using (doc.LockDocument()) {
    foreach (ObjectId id in selection.Value.GetObjectIds()) {
     bool isRegion;
     using (Transaction tr = doc.TransactionManager.StartTransaction()) {
      Entity entity = tr.GetObject(id, OpenMode.ForRead, false) as Entity;
      if (entity == null) { skipped++; continue; }
      isRegion = entity is Region;
      if (!isRegion && entity is Polyline) { skipped++; continue; }
      if (!isRegion && !(entity is Curve) && !(entity is Polyline2d) && !(entity is Polyline3d)) { skipped++; continue; }
     }
     try {
      int count = isRegion ? ConvertRegion(doc, ed, id, keep) : ConvertEntity(doc, id, keep);
      if (count > 0) made += count;
      else skipped++;
     } catch (System.Exception ex) {
      ed.WriteMessage("\nCVPL: Lỗi khi chuyển đối tượng - " + ex.Message);
      skipped++;
     }
    }
   }
   ed.WriteMessage("\nTGIRR [CVPL]: Đã chuyển " + made + " polyline mới"
    + (keep ? " (giữ nguồn)." : ", xóa đối tượng nguồn.")
    + " Bỏ qua " + skipped + " đối tượng.");
  }

  int ConvertEntity(Document doc, ObjectId id, bool keep) {
   using (Transaction tr = doc.TransactionManager.StartTransaction()) {
    Entity entity = tr.GetObject(id, OpenMode.ForRead, false) as Entity;
    if (entity == null) return 0;
    PolyPiece piece = PieceFrom(tr, entity);
    if (piece == null) return 0;
    var space = (BlockTableRecord)tr.GetObject(doc.Database.CurrentSpaceId, OpenMode.ForWrite);
    CreatePolyline(tr, space, piece, StyleOf(entity), piece.Elevation);
    if (!keep) {
     entity.UpgradeOpen();
     entity.Erase();
    }
    tr.Commit();
    return 1;
   }
  }

  int ConvertRegion(Document doc, Editor ed, ObjectId id, bool keep) {
   EntityStyle style;
   double elevation;
   using (Transaction tr = doc.TransactionManager.StartTransaction()) {
    Entity source = tr.GetObject(id, OpenMode.ForRead, false) as Entity;
    if (source == null) return 0;
    style = StyleOf(source);
    elevation = source.GeometricExtents.MinPoint.Z;
   }
   ObjectId explodeId = id;
   if (keep) explodeId = CloneRegion(doc, id);
   if (explodeId.IsNull) return 0;
   HashSet<ObjectId> before = SpaceIds(doc);
   try {
    ed.Command("_.EXPLODE", explodeId);
    int guard = 0;
    while (guard++ < 5 && CommandActive("EXPLODE")) ed.Command("");
   } catch (System.Exception ex) {
    ed.WriteMessage("\nCVPL: Không explode được REGION - " + ex.Message);
    if (keep) EraseQuietly(doc, explodeId);
    return 0;
   }
   HashSet<ObjectId> after = SpaceIds(doc);
   List<ObjectId> pieces = after.Where(x => !before.Contains(x)).ToList();
   if (pieces.Count == 0) {
    ed.WriteMessage("\nCVPL: REGION không tạo được đường biên.");
    if (keep) EraseQuietly(doc, explodeId);
    return 0;
   }
   int made = 0;
   using (Transaction tr = doc.TransactionManager.StartTransaction()) {
    var space = (BlockTableRecord)tr.GetObject(doc.Database.CurrentSpaceId, OpenMode.ForWrite);
    var geometry = new List<PolyPiece>();
    foreach (ObjectId pieceId in pieces) {
     Entity entity = tr.GetObject(pieceId, OpenMode.ForRead, false) as Entity;
     if (entity == null) continue;
     PolyPiece piece = PieceFrom(tr, entity);
     if (piece != null) geometry.Add(piece);
     entity.UpgradeOpen();
     entity.Erase();
    }
    foreach (PolyPiece piece in PolylineGeometry.Join(geometry, PolylineGeometry.JoinTolerance)) {
     CreatePolyline(tr, space, piece, style, elevation);
     made++;
    }
    tr.Commit();
   }
   return made;
  }

  ObjectId CloneRegion(Document doc, ObjectId id) {
   using (Transaction tr = doc.TransactionManager.StartTransaction()) {
    var region = tr.GetObject(id, OpenMode.ForRead, false) as Region;
    if (region == null) return ObjectId.Null;
    var clone = (Region)region.Clone();
    var space = (BlockTableRecord)tr.GetObject(doc.Database.CurrentSpaceId, OpenMode.ForWrite);
    space.AppendEntity(clone);
    tr.AddNewlyCreatedDBObject(clone, true);
    tr.Commit();
    return clone.ObjectId;
   }
  }

  void EraseQuietly(Document doc, ObjectId id) {
   try {
    using (Transaction tr = doc.TransactionManager.StartTransaction()) {
     Entity entity = tr.GetObject(id, OpenMode.ForRead, false) as Entity;
     if (entity == null || entity.IsErased) return;
     entity.UpgradeOpen();
     entity.Erase();
     tr.Commit();
    }
   } catch (System.Exception) { }
  }

  HashSet<ObjectId> SpaceIds(Document doc) {
   using (Transaction tr = doc.TransactionManager.StartTransaction()) {
    var space = (BlockTableRecord)tr.GetObject(doc.Database.CurrentSpaceId, OpenMode.ForRead);
    return new HashSet<ObjectId>(space.Cast<ObjectId>());
   }
  }

  static bool CommandActive(string name) {
   string commands = Application.GetSystemVariable("CMDNAMES") as string;
   return commands != null && commands.IndexOf(name, StringComparison.OrdinalIgnoreCase) >= 0;
  }

  static EntityStyle StyleOf(Entity entity) {
   return new EntityStyle {
    Layer = entity.Layer,
    Color = entity.Color,
    Linetype = entity.Linetype,
    LineWeight = entity.LineWeight,
    LinetypeScale = entity.LinetypeScale
   };
  }

  static PolyPiece PieceFrom(Transaction tr, Entity entity) {
   var line = entity as Line;
   if (line != null) {
    PolyPiece piece = PolylineGeometry.Line(Vertex(line.StartPoint), Vertex(line.EndPoint));
    piece.Elevation = line.StartPoint.Z;
    return piece;
   }
   var arc = entity as Arc;
   if (arc != null) {
    PolyPiece piece = PolylineGeometry.Arc(arc.Center.X, arc.Center.Y, arc.Radius, arc.StartAngle, arc.EndAngle, arc.Center.Z);
    piece.Elevation = arc.Center.Z;
    return piece;
   }
   var circle = entity as Circle;
   if (circle != null) {
    PolyPiece piece = PolylineGeometry.Circle(circle.Center.X, circle.Center.Y, circle.Radius, circle.Center.Z);
    piece.Elevation = circle.Center.Z;
    return piece;
   }
   var poly2d = entity as Polyline2d;
   if (poly2d != null) return FromOldPolyline(tr, (IEnumerable)poly2d, poly2d.Closed, 0);
   var poly3d = entity as Polyline3d;
   if (poly3d != null) return FromOldPolyline(tr, (IEnumerable)poly3d, poly3d.Closed, 0);
   var curve = entity as Curve;
   if (curve != null) {
    var points = new List<PolyVertex>();
    double first = curve.StartParam;
    double last = curve.EndParam;
    for (int i = 0; i <= PolylineGeometry.SampleCount; i++) {
     double param = first + (last - first) * i / PolylineGeometry.SampleCount;
     points.Add(Vertex(curve.GetPointAtParameter(param)));
    }
    bool closed = PolylineGeometry.Near(points[0], points[points.Count - 1], 1e-7);
    PolyPiece piece = PolylineGeometry.Sampled(points, closed, 0);
    if (piece != null) piece.Elevation = curve.GetPointAtParameter(first).Z;
    return piece;
   }
   return null;
  }

  static PolyPiece FromOldPolyline(Transaction tr, IEnumerable vertices, bool closed, double elevation) {
   var points = new List<PolyVertex>();
   var bulges = new List<double>();
   foreach (ObjectId vertexId in vertices) {
    var vertex2d = tr.GetObject(vertexId, OpenMode.ForRead) as Vertex2d;
    if (vertex2d != null) {
     points.Add(Vertex(vertex2d.Position));
     bulges.Add(vertex2d.Bulge);
     elevation = vertex2d.Position.Z;
     continue;
    }
    var vertex3d = tr.GetObject(vertexId, OpenMode.ForRead) as PolylineVertex3d;
    if (vertex3d != null) {
     points.Add(Vertex(vertex3d.Position));
     bulges.Add(0.0);
    }
   }
   PolyPiece piece = PolylineGeometry.FromVertices(points, bulges, closed, elevation);
   return piece;
  }

  static PolyVertex Vertex(Point3d point) { return new PolyVertex(point.X, point.Y); }

  static void CreatePolyline(Transaction tr, BlockTableRecord space, PolyPiece piece, EntityStyle style, double elevation) {
   var polyline = new Polyline();
   for (int i = 0; i < piece.Points.Count; i++) {
    double bulge = i < piece.Bulges.Count ? piece.Bulges[i] : 0.0;
    polyline.AddVertexAt(i, new Point2d(piece.Points[i].X, piece.Points[i].Y), bulge, 0, 0);
   }
   polyline.Closed = piece.Closed;
   polyline.Elevation = piece.Elevation != 0 ? piece.Elevation : elevation;
   if (style != null) {
    polyline.Layer = style.Layer;
    polyline.Color = style.Color;
    polyline.Linetype = style.Linetype;
    polyline.LineWeight = style.LineWeight;
    polyline.LinetypeScale = style.LinetypeScale;
   }
   space.AppendEntity(polyline);
   tr.AddNewlyCreatedDBObject(polyline, true);
  }
 }
}
