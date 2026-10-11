using ZwSoft.ZwCAD.ApplicationServices;
using ZwSoft.ZwCAD.Colors;
using ZwSoft.ZwCAD.DatabaseServices;
using ZwSoft.ZwCAD.EditorInput;
using ZwSoft.ZwCAD.Geometry;
using ZwSoft.ZwCAD.Runtime;
using System;
using System.Collections.Generic;
using System.Linq;

namespace Tgirrr.CadLisp {
 public sealed class DripLayoutCommands {
  [CommandMethod("VDNG")]
  public void Run() {
   var doc = ZwSoft.ZwCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;
   var ed = doc.Editor;
   var filter = new SelectionFilter(new[] { new TypedValue(0, "LWPOLYLINE,CIRCLE") });
   var selection = ed.GetSelection(new PromptSelectionOptions { MessageForAdding = "\nChọn một hoặc nhiều Boundary kín: " }, filter);
   if (selection.Status != PromptStatus.OK) return;

   // Hộp thoại — nếu người dùng bấm "Chọn hướng", quay lại bản vẽ pick 2 điểm rồi mở lại hộp thoại.
   DripLayoutWindow window;
   while (true) {
    window = new DripLayoutWindow(doc.Database.Insunits);
    if (Application.ShowModalWindow(window) != true) {
     if (!window.PickDirectionRequested) return;
     var pDir1 = ed.GetPoint(new PromptPointOptions("\nChọn điểm 1 xác định HƯỚNG dây nhỏ giọt: "));
     if (pDir1.Status != PromptStatus.OK) return;
     var opt2 = new PromptPointOptions("\nChọn điểm 2 xác định HƯỚNG dây nhỏ giọt (điểm đầu -> điểm cuối): ");
     opt2.UseBasePoint = true;
     opt2.BasePoint = pDir1.Value;
     var pDir2 = ed.GetPoint(opt2);
     if (pDir2.Status != PromptStatus.OK) return;
     var dv = pDir2.Value - pDir1.Value;
     if (Math.Abs(dv.X) < 1e-9 && Math.Abs(dv.Y) < 1e-9) { ed.WriteMessage("\nVDNG: 2 điểm trùng nhau — hủy chọn hướng."); return; }
     var next = new DripLayoutWindow(doc.Database.Insunits);
     next.SetDirection(dv.X, dv.Y);
     if (Application.ShowModalWindow(next) != true) return;
     window = next;
     break;
    }
    break;
   }

   int boundaries = 0, skipped = 0, segments = 0, paths = 0, curvedRegions = 0;
   double totalLength = 0;
   double? rowOrigin = null;
   Vector2d edgeDirection = default(Vector2d);
   bool haveEdge = false;
   Polyline seedArc = null;
   bool haveArc = false;
   double seedRadius = 0;
   if (window.UseEdge) {
    var pe = ed.GetPoint(new PromptPointOptions("\nVDNG: Pick 1 điểm trên cạnh chuẩn của Boundary (thẳng: offset song song; cong: bám cong theo cung): "));
    bool picked = pe.Status == PromptStatus.OK;
    if (!picked && pe.Status != PromptStatus.Cancel) return;
    var pick = picked ? new Point2d(pe.Value.X, pe.Value.Y) : new Point2d(0, 0);
    double bestDist = double.MaxValue;
    // Bấm Esc ở bước pick: bỏ qua hẳn việc tìm cạnh chuẩn để rơi về hướng trục dài của Boundary (không thoát lệnh).
    using (var tr0 = doc.TransactionManager.StartTransaction()) {
     foreach (var id in picked ? selection.Value.GetObjectIds() : new ObjectId[0]) {
      var ent = tr0.GetObject(id, OpenMode.ForRead) as Entity;
      var poly = ent as Polyline;
      if (poly == null) continue;
      int n = poly.NumberOfVertices;
      int count = poly.Closed ? n : n - 1;
      for (int i = 0; i < count; i++) {
       var st = poly.GetSegmentType(i);
       if (st == SegmentType.Line) {
        var seg = poly.GetLineSegment2dAt(i);
        var cp = seg.GetClosestPointTo(pick).Point;
        double dist = cp.GetDistanceTo(pick);
        if (dist < bestDist) {
         bestDist = dist;
         var d2 = seg.Direction;
         edgeDirection = new Vector2d(d2.X, d2.Y);
         var s2 = seg.StartPoint;
         rowOrigin = -d2.Y * s2.X + d2.X * s2.Y;
         haveEdge = true;
         haveArc = false;
         seedArc = null;
        }
       } else if (st == SegmentType.Arc) {
        var arcSeg = poly.GetArcSegment2dAt(i);
        var cpA = arcSeg.GetClosestPointTo(pick).Point;
        double distA = cpA.GetDistanceTo(pick);
        if (distA < bestDist) {
         bestDist = distA;
         seedRadius = arcSeg.Radius;
         var seed = new Polyline();
         seed.AddVertexAt(0, poly.GetPoint2dAt(i), poly.GetBulgeAt(i), 0, 0);
         seed.AddVertexAt(1, poly.GetPoint2dAt((i + 1) % n), 0, 0, 0);
         seed.Elevation = poly.Elevation;
         seedArc = seed;
         haveArc = true;
         haveEdge = false;
         rowOrigin = null;
        }
       }
      }
     }
     tr0.Commit();
    }
    if (haveArc) {
     ed.WriteMessage("\nVDNG: Cạnh chuẩn là CUNG bán kính " + seedRadius.ToString("0.###") + " — dây sẽ bám cong song song theo cung với bước = khoảng cách dây.");
    } else if (!haveEdge) {
     ed.WriteMessage(picked
      ? "\nVDNG: Không tìm thấy cạnh thẳng/cung gần điểm pick — dùng hướng tự động theo trục dài của Boundary."
      : "\nVDNG: Đã bỏ qua bước pick cạnh chuẩn — rải dây THẲNG song song TRỤC DÀI của Boundary.");
     rowOrigin = null;
    } else {
     ed.WriteMessage("\nVDNG: Cạnh chuẩn cách điểm pick " + bestDist.ToString("0.###") + " — dây sẽ offset song song từ cạnh này với bước = khoảng cách dây.");
    }
   }
   using (doc.LockDocument())
   using (var tr = doc.TransactionManager.StartTransaction()) {
    var db = doc.Database;
    var lt = (LayerTable)tr.GetObject(db.LayerTableId, OpenMode.ForRead);
    ObjectId layerId;
    if (!lt.Has("TG-DRIP")) {
     lt.UpgradeOpen();
     var layer = new LayerTableRecord { Name = "TG-DRIP", Color = Color.FromColorIndex(ColorMethod.ByAci, 34) };
     layerId = lt.Add(layer);
     tr.AddNewlyCreatedDBObject(layer, true);
    } else layerId = lt["TG-DRIP"];
    var space = (BlockTableRecord)tr.GetObject(db.CurrentSpaceId, OpenMode.ForWrite);

    foreach (var id in selection.Value.GetObjectIds()) {
     var entity = tr.GetObject(id, OpenMode.ForRead) as Entity;
     Polyline p = entity as Polyline;
     bool temporary = false;
     if (entity is Circle circle) { p = CircleBoundary(circle); temporary = true; }
     if (p != null && !temporary && !p.Closed && p.NumberOfVertices >= 3) {
      p.UpgradeOpen();
      p.Closed = true;
      ed.WriteMessage("\nVDNG: Đã tự đóng Boundary " + id.Handle + " (nối điểm cuối về điểm đầu).");
     }
     if (p == null || !p.Closed || p.NumberOfVertices < 3) {
      ed.WriteMessage("\nVDNG: Boundary " + id.Handle + " không hợp lệ — loại=" + (entity?.GetType().Name ?? "null") + ", Closed=" + (p != null && p.Closed) + ", số đỉnh=" + (p?.NumberOfVertices ?? 0) + ".");
      if (temporary) p?.Dispose();
      skipped++;
      continue;
     }
     try {
      Vector2d direction = haveEdge ? edgeDirection : (window.DirX.HasValue && !haveArc ? new Vector2d(window.DirX.Value, window.DirY.Value) : DripLayoutService.Direction(p));
      var regions = DripLayoutService.Inner(p, window.Inset);
      if (regions.Count == 0) {
       skipped++;
       ed.WriteMessage("\nVDNG: Boundary " + id.Handle + " không tạo được offset phía trong (khoảng lùi=" + window.Inset + ", diện tích=" + Math.Abs(p.Area) + "). Hãy giảm khoảng lùi hoặc kiểm tra Polyline tự giao/cạnh quá ngắn.");
       if (temporary) p.Dispose();
       continue;
      }
      double boundaryLength = 0;
      foreach (Polyline region in regions) {
       double regionLength = 0;
       double bestLen = 0, bestZ = 0, bestMidX = 0, bestMidY = 0;
       // Bám cong khi người dùng pick cạnh cung, hoặc TỰ ĐỘNG với ô dài hẹp có biên cong:
       // dây lướt mượt song song biên thay vì hàng thẳng cắt chéo hai đầu ô.
       Polyline autoSeed = haveArc ? null : DripLayoutService.AutoCurveSeed(region, window.Spacing);
       bool curveMode = haveArc || autoSeed != null;
       if (curveMode) {
        curvedRegions++;
        var curved = DripLayoutService.CurvedFollow(haveArc ? seedArc : autoSeed, region, window.Spacing);
        foreach (var c in curved) {
         regionLength += c.Length;
         if (c.Length > bestLen) {
          bestLen = c.Length;
          var mid = c.GetPointAtDist(c.Length / 2);
          bestMidX = mid.X; bestMidY = mid.Y; bestZ = mid.Z;
         }
         c.LayerId = layerId;
         c.ColorIndex = 256;
         c.LineWeight = LineWeight.ByLayer;
         space.AppendEntity(c);
         tr.AddNewlyCreatedDBObject(c, true);
         segments++;
        }
        // A selected curved edge may be too short, reversed, or separated
        // from the inset region for geometric extension. Never leave the
        // boundary empty: fall back to clipped straight rows in that region.
        if (curved.Count == 0) {
         var fillSegments = DripLayoutService.Fill(region, window.Spacing, direction, rowOrigin);
         regionLength = fillSegments.Sum(s => s.Length);
         foreach (var s in fillSegments) {
          if (s.Length > bestLen) {
           bestLen = s.Length;
           bestMidX = (s.StartPoint.X + s.EndPoint.X) / 2;
           bestMidY = (s.StartPoint.Y + s.EndPoint.Y) / 2;
           bestZ = s.StartPoint.Z;
          }
         }
         AppendSegments(tr, space, layerId, fillSegments, ref segments);
        }
        autoSeed?.Dispose();
       } else {
        var fillSegments = DripLayoutService.Fill(region, window.Spacing, direction, rowOrigin);
        regionLength = fillSegments.Sum(s => s.Length);
        foreach (var s in fillSegments) {
         if (s.Length > bestLen) {
          bestLen = s.Length;
          bestMidX = (s.StartPoint.X + s.EndPoint.X) / 2;
          bestMidY = (s.StartPoint.Y + s.EndPoint.Y) / 2;
          bestZ = s.StartPoint.Z;
         }
        }
        if (window.Serpentine && fillSegments.Count >= 2) {
         var path = DripLayoutService.SerpentinePath(fillSegments, direction, window.Spacing, region.Elevation);
         if (path != null) {
          foreach (var s in fillSegments) s.Dispose();
          path.LayerId = layerId;
          path.ColorIndex = 256;
          path.LineWeight = LineWeight.ByLayer;
          space.AppendEntity(path);
          tr.AddNewlyCreatedDBObject(path, true);
          paths++;
         } else {
          AppendSegments(tr, space, layerId, fillSegments, ref segments);
         }
        } else {
         AppendSegments(tr, space, layerId, fillSegments, ref segments);
        }
       }
       totalLength += regionLength;
       boundaryLength += regionLength;
       // The inset boundary is the perimeter/header pipe. Keep exactly the
       // single selected inward offset; branch rows terminate on this loop.
       region.LayerId = layerId;
       region.ColorIndex = 256;
       region.LineWeight = LineWeight.ByLayer;
       space.AppendEntity(region);
       tr.AddNewlyCreatedDBObject(region, true);
       if (window.Annotate && regionLength > 0 && bestLen > 0) {
        var note = MakeInsideNote(db.Insunits, window.Spacing, regionLength, direction, bestMidX, bestMidY, bestZ, bestLen);
        if (note != null) {
         note.LayerId = layerId;
         note.ColorIndex = 256;
         space.AppendEntity(note);
         tr.AddNewlyCreatedDBObject(note, true);
        }
       }
      }
      boundaries++;
      if (temporary) p.Dispose();
     } catch (System.Exception ex) {
      if (temporary) p?.Dispose();
      skipped++;
      ed.WriteMessage("\nVDNG: Bỏ qua Boundary " + id.Handle + " — " + ex.Message);
     }
    }
    seedArc?.Dispose();
    tr.Commit();
   }
   ed.WriteMessage("\nVDNG: Xử lý " + boundaries + " Boundary, bỏ qua " + skipped + ", tạo " + segments + " đoạn dây, " + paths + " đường zigzag" + (curvedRegions > 0 ? ", " + curvedRegions + " vùng bám cong theo biên" : "") + ".");
   if (totalLength > 0) {
    var iu = doc.Database.Insunits;
    double mm = totalLength * MmFactor(iu);
    if (mm >= 1000 && iu != UnitsValue.Undefined) ed.WriteMessage("\nVDNG: Tổng chiều dài dây = " + (mm / 1000.0).ToString("0.##") + " m.");
    else if (iu != UnitsValue.Undefined) ed.WriteMessage("\nVDNG: Tổng chiều dài dây = " + mm.ToString("0.##") + " mm.");
    else ed.WriteMessage("\nVDNG: Tổng chiều dài dây = " + totalLength.ToString("0.##") + " đơn vị bản vẽ (chưa rõ INSUNITS).");
   }
   if (boundaries > 0 && segments == 0 && paths == 0) ed.WriteMessage("\nVDNG: CẢNH BÁO — không tạo được đoạn dây nào. Hãy kiểm tra: (1) 'Khoảng cách giữa dây' quá lớn so với kích thước Boundary, (2) 'Khoảng lùi từ biên' quá lớn, (3) đơn vị nhập trong hộp thoại (mm/cm/m) khác đơn vị bản vẽ.");
  }

  static void AppendSegments(Transaction tr, BlockTableRecord space, ObjectId layerId, List<Line> fillSegments, ref int segments) {
   foreach (var segment in fillSegments) {
    var line = new Polyline();
    line.AddVertexAt(0, new Point2d(segment.StartPoint.X, segment.StartPoint.Y), 0, 0, 0);
    line.AddVertexAt(1, new Point2d(segment.EndPoint.X, segment.EndPoint.Y), 0, 0, 0);
    line.Elevation = segment.StartPoint.Z;
    segment.Dispose();
    line.LayerId = layerId;
    line.ColorIndex = 256;
    line.LineWeight = LineWeight.ByLayer;
    space.AppendEntity(line);
    tr.AddNewlyCreatedDBObject(line, true);
    segments++;
   }
  }

  static string BuildNote(UnitsValue insunits, double spacing, double length) {
   string unitName = insunits == UnitsValue.Millimeters ? "mm" : insunits == UnitsValue.Centimeters ? "cm" : insunits == UnitsValue.Meters ? "m" : "đv";
   double spacingMm = spacing * MmFactor(insunits);
   double lengthM = length * MmFactor(insunits) / 1000.0;
   string note = "DÂY NHỎ GIỌT - KC " + spacingMm.ToString("0.#") + "mm";
   if (insunits != UnitsValue.Undefined) note += " - DÀI " + lengthM.ToString("0.##") + "m";
   else note += " - DÀI " + length.ToString("0.##") + " " + unitName + " (chưa rõ INSUNITS)";
   return note;
  }

  /// <summary>Tạo ghi chú nằm GỌN BÊN TRONG vùng rải: canh giữa hàng dây dài nhất, xoay theo hướng dây, chiều cao chữ tự giới hạn theo khoảng cách dây và chiều dài hàng.</summary>
  static DBText MakeInsideNote(UnitsValue insunits, double spacing, double regionLength, Vector2d direction, double midX, double midY, double midZ, double rowLen) {
   string text = BuildNote(insunits, spacing, regionLength);
   if (text.Length == 0) return null;
   double dx = direction.X, dy = direction.Y;
   double mag = Math.Sqrt(dx * dx + dy * dy);
   if (mag < 1e-9) return null;
   dx /= mag; dy /= mag;
   double rot = Math.Atan2(dy, dx);
   if (dx < 0) { rot += Math.PI; dx = -dx; dy = -dy; }
   double h = Math.Min(spacing * 0.4, rowLen * 0.85 / (0.6 * text.Length));
   if (h <= 0) return null;
   double upX = -dy, upY = dx;
   var align = new Point3d(midX + upX * spacing * 0.18, midY + upY * spacing * 0.18, midZ);
   var note = new DBText {
    TextString = text,
    Height = h,
    Rotation = rot,
    HorizontalMode = TextHorizontalMode.TextMid,
    VerticalMode = TextVerticalMode.TextBase,
    Position = align,
    AlignmentPoint = align
   };
   return note;
  }

  static double MmFactor(UnitsValue u) => u == UnitsValue.Millimeters ? 1 : u == UnitsValue.Centimeters ? 10 : u == UnitsValue.Meters ? 1000 : 1;

  static Polyline CircleBoundary(Circle circle) {
   var p = new Polyline();
   double r = circle.Radius, x = circle.Center.X, y = circle.Center.Y, bulge = Math.Tan(Math.PI / 8);
   p.AddVertexAt(0, new Point2d(x + r, y), bulge, 0, 0);
   p.AddVertexAt(1, new Point2d(x, y + r), bulge, 0, 0);
   p.AddVertexAt(2, new Point2d(x - r, y), bulge, 0, 0);
   p.AddVertexAt(3, new Point2d(x, y - r), bulge, 0, 0);
   p.Closed = true;
   return p;
  }
 }
}
