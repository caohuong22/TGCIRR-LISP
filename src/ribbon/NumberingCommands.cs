using System;
using System.Collections.Generic;
using System.Globalization;
using Autodesk.AutoCAD.ApplicationServices;
using Autodesk.AutoCAD.Colors;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.EditorInput;
using Autodesk.AutoCAD.Geometry;
using Autodesk.AutoCAD.Runtime;

namespace Tgirrr.CadLisp {
 /// <summary>
 /// TGN: danh so doi tuong hoac vung tuoi bang nhan ellipse/tron + TEXT tren layer TG-number.
 /// </summary>
 public sealed class NumberingCommands {
  const string LayerName = "TG-number";
  static NumberSettings last = new NumberSettings();

  sealed class PathInfo {
   internal ObjectId Id;
   internal double Start;
   internal double Total;
  }

  [CommandMethod("TGN")]
  public void Run() {
   Document doc = Application.DocumentManager.MdiActiveDocument;
   if (doc == null) return;
   Editor ed = doc.Editor;
   var window = new NumberingWindow(last.Clone());
   if (Application.ShowModalWindow(window) != true) return;
   NumberSettings settings = window.Settings;
   last = settings.Clone();

   PromptSelectionResult selection = ed.GetSelection();
   if (selection.Status != PromptStatus.OK || selection.Value == null || selection.Value.Count == 0) {
    ed.WriteMessage("\nTGN: Không có đối tượng hợp lệ được chọn.");
    return;
   }

   var items = new List<NumberItem>();
   int skipped = 0;
   using (Transaction tr = doc.TransactionManager.StartTransaction()) {
    int index = 0;
    foreach (ObjectId id in selection.Value.GetObjectIds()) {
     Entity entity = tr.GetObject(id, OpenMode.ForRead, false) as Entity;
     if (entity == null || (settings.RegionsOnly && !IsClosedRegion(entity))) { skipped++; continue; }
     Extents3d extents;
     try { extents = entity.GeometricExtents; }
     catch (System.Exception) { skipped++; continue; }
     items.Add(new NumberItem {
      Index = index++,
      X = (extents.MinPoint.X + extents.MaxPoint.X) / 2.0,
      Y = (extents.MinPoint.Y + extents.MaxPoint.Y) / 2.0,
      Z = (extents.MinPoint.Z + extents.MaxPoint.Z) / 2.0
     });
    }
   }
   if (skipped > 0) ed.WriteMessage("\nTGN: Bỏ qua " + skipped + " đối tượng không phải vùng kín.");
   if (items.Count == 0) {
    ed.WriteMessage("\nTGN: Không có đối tượng hợp lệ được chọn.");
    return;
   }

   if (settings.Order == NumberOrder.Path) {
    PathInfo path = PickPath(doc, ed);
    if (path == null) return;
    ApplyPathDistances(doc, items, path);
    items = NumberingService.Sort(items, NumberOrder.Path);
   } else {
    items = NumberingService.Sort(items, settings.Order);
   }

   int made;
   using (doc.LockDocument()) {
    using (Transaction tr = doc.TransactionManager.StartTransaction()) {
     var space = (BlockTableRecord)tr.GetObject(doc.Database.CurrentSpaceId, OpenMode.ForWrite);
     EnsureLayer(tr, doc.Database);
     int number = settings.Start;
     foreach (NumberItem item in items) {
      var center = new Point3d(item.X, item.Y, item.Z);
      CreateEllipse(tr, space, center, settings.Width, settings.Height);
      CreateText(tr, doc.Database, space, center, number.ToString(CultureInfo.InvariantCulture), settings.TextHeight);
      number += settings.Step;
     }
     made = items.Count;
     tr.Commit();
    }
   }
   ed.WriteMessage("\nTGN: Đã đánh số " + made + " đối tượng trên layer " + LayerName + ".");
  }

  static bool IsClosedRegion(Entity entity) {
   if (entity is Circle) return true;
   var polyline = entity as Polyline;
   if (polyline != null) return polyline.Closed;
   var polyline2d = entity as Polyline2d;
   if (polyline2d != null) return polyline2d.Closed;
   var polyline3d = entity as Polyline3d;
   if (polyline3d != null) return polyline3d.Closed;
   return false;
  }

  static PathInfo PickPath(Document doc, Editor ed) {
   while (true) {
    var options = new PromptEntityOptions("\nChọn Polyline làm đường dẫn <Esc để hủy>: ");
    options.SetRejectMessage("\nTGN: Đường dẫn phải là Polyline.");
    options.AddAllowedClass(typeof(Polyline), false);
    options.AddAllowedClass(typeof(Polyline2d), false);
    options.AddAllowedClass(typeof(Polyline3d), false);
    PromptEntityResult pick = ed.GetEntity(options);
    if (pick.Status != PromptStatus.OK) return null;
    double total;
    using (Transaction tr = doc.TransactionManager.StartTransaction()) {
     var curve = tr.GetObject(pick.ObjectId, OpenMode.ForRead, false) as Curve;
     if (curve == null) continue;
     total = curve.GetDistanceAtParameter(curve.EndParam);
    }
    var pointOptions = new PromptPointOptions("\nChọn điểm bắt đầu trên đường dẫn <Enter/Space = từ đầu Polyline>: ") { AllowNone = true };
    PromptPointResult point = ed.GetPoint(pointOptions);
    double start = 0;
    if (point.Status == PromptStatus.OK) {
     using (Transaction tr = doc.TransactionManager.StartTransaction()) {
      var curve = tr.GetObject(pick.ObjectId, OpenMode.ForRead, false) as Curve;
      if (curve != null) {
       try {
        Point3d wcs = point.Value.TransformBy(ed.CurrentUserCoordinateSystem);
        start = curve.GetDistAtPoint(curve.GetClosestPointTo(wcs, false));
       } catch (System.Exception) { start = 0; }
      }
     }
    }
    return new PathInfo { Id = pick.ObjectId, Start = start, Total = total };
   }
  }

  static void ApplyPathDistances(Document doc, List<NumberItem> items, PathInfo path) {
   using (Transaction tr = doc.TransactionManager.StartTransaction()) {
    var curve = tr.GetObject(path.Id, OpenMode.ForRead, false) as Curve;
    if (curve == null) return;
    foreach (NumberItem item in items) {
     try {
      Point3d closest = curve.GetClosestPointTo(new Point3d(item.X, item.Y, item.Z), false);
      item.PathDistance = NumberingService.PathDistance(curve.GetDistAtPoint(closest), path.Start, path.Total);
     } catch (System.Exception) {
      item.PathDistance = double.MaxValue;
     }
    }
   }
  }

  static void EnsureLayer(Transaction tr, Database db) {
   var layers = (LayerTable)tr.GetObject(db.LayerTableId, OpenMode.ForRead);
   if (layers.Has(LayerName)) return;
   layers.UpgradeOpen();
   var layer = new LayerTableRecord {
    Name = LayerName,
    Color = Color.FromColorIndex(ColorMethod.ByAci, 7)
   };
   layers.Add(layer);
   tr.AddNewlyCreatedDBObject(layer, true);
  }

  static void CreateEllipse(Transaction tr, BlockTableRecord space, Point3d center, double width, double height) {
   Vector3d major;
   double ratio;
   if (width >= height) {
    major = new Vector3d(width / 2.0, 0, 0);
    ratio = height / width;
   } else {
    major = new Vector3d(0, height / 2.0, 0);
    ratio = width / height;
   }
   var ellipse = new Ellipse(center, new Vector3d(0, 0, 1), major, ratio, 0, 2.0 * Math.PI) {
    Layer = LayerName
   };
   space.AppendEntity(ellipse);
   tr.AddNewlyCreatedDBObject(ellipse, true);
  }

  static void CreateText(Transaction tr, Database db, BlockTableRecord space, Point3d center, string label, double textHeight) {
   var text = new DBText {
    TextString = label,
    Height = textHeight,
    Position = center,
    HorizontalMode = TextHorizontalMode.TextCenter,
    VerticalMode = TextVerticalMode.TextVerticalMid,
    Layer = LayerName,
    TextStyleId = db.Textstyle
   };
   text.AlignmentPoint = center;
   space.AppendEntity(text);
   tr.AddNewlyCreatedDBObject(text, true);
  }
 }
}
