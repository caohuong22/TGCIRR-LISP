using System;
using System.Collections.Generic;
using Autodesk.AutoCAD.ApplicationServices;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.EditorInput;
using Autodesk.AutoCAD.Runtime;

namespace Tgirrr.CadLisp {
 /// <summary>
 /// Lenh TL: cong tong chieu dai cac duong da chon truoc (PICKFIRST), giong ban AutoLISP cu.
 /// </summary>
 public sealed class TotalLengthCommands {
  [CommandMethod("TL")]
  public void Run() {
   Document doc = Application.DocumentManager.MdiActiveDocument;
   if (doc == null) return;
   PromptSelectionResult selection = doc.Editor.SelectImplied();
   if (selection.Status != PromptStatus.OK || selection.Value == null || selection.Value.Count == 0) {
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
   Application.ShowAlertDialog(TotalLengthService.Message(TotalLengthService.Sum(lengths)));
  }
 }
}
