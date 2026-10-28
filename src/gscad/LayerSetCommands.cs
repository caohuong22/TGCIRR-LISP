using System;
using System.Collections.Generic;
using System.Globalization;
using Gssoft.Gscad.ApplicationServices;
using Gssoft.Gscad.Colors;
using Gssoft.Gscad.DatabaseServices;
using Gssoft.Gscad.EditorInput;
using Gssoft.Gscad.Runtime;

namespace Tgirrr.CadLisp {
 /// <summary>
 /// Lenh TGL (bo Layer chuan) va TGLADD (them Layer vao kho) - ban native thay AutoLISP.
 /// </summary>
 public sealed class LayerSetCommands {
  [CommandMethod("TGIRRTGL")]
  public void CreateStandardLayers() {
   Document doc = Gssoft.Gscad.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;
   if (doc == null) return;
   var items = new List<LayerEntry>(LayerSetService.Standard);
   items.AddRange(LayerLibraryStore.Load());
   using (doc.LockDocument()) {
    using (Transaction tr = doc.TransactionManager.StartTransaction()) {
     foreach (LayerEntry item in items) {
      bool missingLinetype;
      EnsureLayer(doc.Database, tr, item, out missingLinetype);
     }
     LayerTable layers = (LayerTable)tr.GetObject(doc.Database.LayerTableId, OpenMode.ForRead);
     if (layers.Has(LayerSetService.CurrentLayer)) doc.Database.Clayer = layers[LayerSetService.CurrentLayer];
     tr.Commit();
    }
   }
   doc.Editor.WriteMessage("\nĐã tạo xong bộ Layer tiêu chuẩn và chuyển Layer hiện hành về " + LayerSetService.CurrentLayer + "!");
  }

  [CommandMethod("TGIRRTGLADD")]
  public void AddLayerToLibrary() {
   Document doc = Gssoft.Gscad.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument;
   if (doc == null) return;
   Editor ed = doc.Editor;
   PromptResult name = ed.GetString(new PromptStringOptions("\nTên Layer mới: ") { AllowSpaces = true });
   if (name.Status != PromptStatus.OK || string.IsNullOrWhiteSpace(name.StringResult)) {
    ed.WriteMessage("\nTGLADD: Chưa nhập tên Layer.");
    return;
   }
   PromptResult color = ed.GetString(new PromptStringOptions("\nMàu ACI (1-255, mặc định 7): ") { AllowSpaces = true });
   string aci = LayerSetService.NormalizeColor(color.Status == PromptStatus.OK ? color.StringResult : "");
   PromptResult linetype = ed.GetString(new PromptStringOptions("\nTên linetype (mặc định Continuous): ") { AllowSpaces = true });
   string ltype = linetype.Status == PromptStatus.OK && !string.IsNullOrWhiteSpace(linetype.StringResult)
    ? linetype.StringResult.Trim()
    : LayerSetService.DefaultLinetype;
   var entry = new LayerEntry(name.StringResult.Trim(), aci, ltype);
   List<LayerEntry> items = LayerLibraryStore.Load();
   int index = items.FindIndex(x => string.Equals(x.Name, entry.Name, StringComparison.OrdinalIgnoreCase));
   if (index >= 0) items[index] = entry;
   else items.Add(entry);
   try {
    LayerLibraryStore.Save(items);
   } catch (System.Exception ex) {
    ed.WriteMessage("\nTGLADD: Không lưu được kho Layer - " + ex.Message);
    return;
   }
   bool missingLinetype;
   using (doc.LockDocument()) {
    using (Transaction tr = doc.TransactionManager.StartTransaction()) {
     EnsureLayer(doc.Database, tr, entry, out missingLinetype);
     tr.Commit();
    }
   }
   if (missingLinetype)
    ed.WriteMessage("\nTGLADD: Chưa nạp linetype '" + ltype + "'. Layer vẫn được lưu, sẽ gán nét khi nạp LIN.");
   ed.WriteMessage("\nTGLADD: Đã thêm vào kho Layer: " + entry.Name + " [màu " + aci + ", nét " + ltype + "].");
  }

  static void EnsureLayer(Database db, Transaction tr, LayerEntry item, out bool missingLinetype) {
   missingLinetype = false;
   if (item == null || string.IsNullOrWhiteSpace(item.Name)) return;
   string linetype = string.IsNullOrWhiteSpace(item.Linetype) ? LayerSetService.DefaultLinetype : item.Linetype.Trim();
   LinetypeTable linetypes = (LinetypeTable)tr.GetObject(db.LinetypeTableId, OpenMode.ForRead);
   bool hasLinetype = linetypes.Has(linetype);
   missingLinetype = !hasLinetype;
   LayerTable layers = (LayerTable)tr.GetObject(db.LayerTableId, OpenMode.ForRead);
   ObjectId id;
   if (layers.Has(item.Name)) {
    id = layers[item.Name];
   } else {
    layers.UpgradeOpen();
    var record = new LayerTableRecord { Name = item.Name };
    id = layers.Add(record);
    tr.AddNewlyCreatedDBObject(record, true);
   }
   var layer = (LayerTableRecord)tr.GetObject(id, OpenMode.ForWrite);
   layer.Color = Color.FromColorIndex(ColorMethod.ByAci, short.Parse(LayerSetService.NormalizeColor(item.Color), CultureInfo.InvariantCulture));
   if (hasLinetype) layer.LinetypeObjectId = linetypes[linetype];
  }
 }
}
