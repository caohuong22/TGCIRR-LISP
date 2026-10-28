using System;
using System.Collections.Generic;
using Autodesk.AutoCAD.ApplicationServices;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.EditorInput;
using Autodesk.AutoCAD.Runtime;

namespace Tgirrr.CadLisp {
 /// <summary>
 /// Lenh TL: cong tong chieu dai cac duong da chon truoc (PICKFIRST), giong ban AutoLISP cu.
 /// Neu chua chon gi thi hoi chon doi tuong, nho vay bam nut tren toolbar/menu
 /// (^C^C xoa pickset) van dung duoc thay vi chi hien hop thoai "chua chon".
 /// </summary>
 public sealed class TotalLengthCommands {
  [CommandMethod("TGIRRTL")]
  public void Run() {
   Document doc = Application.DocumentManager.MdiActiveDocument;
   if (doc == null) return;
   PromptSelectionResult selection = doc.Editor.SelectImplied();
   if (selection.Status != PromptStatus.OK || selection.Value == null || selection.Value.Count == 0) {
    var options = new PromptSelectionOptions {
     MessageForAdding = "\nChọn Line, Arc, Circle, Polyline, Ellipse hoặc Spline để cộng chiều dài: "
    };
    selection = doc.Editor.GetSelection(options);
   }
   if (selection.Status != PromptStatus.OK || selection.Value == null || selection.Value.Count == 0) {
    doc.Editor.WriteMessage("\n" + TotalLengthService.EmptyMessage + "\n");
    Application.ShowAlertDialog(TotalLengthService.EmptyMessage);
    return;
   }
   var lengths = new List<double>();
   using (Transaction tr = doc.TransactionManager.StartTransaction()) {
    foreach (ObjectId id in selection.Value.GetObjectIds()) {
     Curve curve = tr.GetObject(id, OpenMode.ForRead, false) as Curve;
     if (curve == null) continue;
     try { lengths.Add(curve.GetDistanceAtParameter(curve.EndParam)); }
     catch (Autodesk.AutoCAD.Runtime.Exception) { }
    }
   }
   string message = TotalLengthService.Message(TotalLengthService.Sum(lengths));
   // Ghi ca ra dong lenh: mot so may tat hop thoai (FILEDIA/CMDECHO), khi do
   // nguoi dung van thay ket qua thay vi tuong lenh khong chay.
   doc.Editor.WriteMessage("\n" + message + "\n");
   Application.ShowAlertDialog(message);
  }
 }
}
