using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.ApplicationServices;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
namespace Tgirrr.CadLisp {
 internal static class LinetypeService {
  internal static string DefaultPath { get { var dir=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments),"TGIRR CAD LISP");Directory.CreateDirectory(dir);return Path.Combine(dir,"TGIRR_Linetypes.lin"); } }
  internal static string Definition(string name,string description,double dash,double before,string text,string style,double y,double scale,double after){return LinetypeFile.Definition(name,description,dash,before,text,style,y,scale,after);}
  internal static List<LinetypeDefinition> Read(string path){return LinetypeFile.Read(path);}
  internal static void Save(string path,string name,string definition){LinetypeFile.Save(path,name,definition);}
  internal static List<string> DrawingNames(Document doc){return DrawingNamesAll(doc).Where(n=>n!="ByLayer"&&n!="ByBlock"&&n!="Continuous").ToList();}
  internal static List<string> DrawingNamesAll(Document doc){using(doc.LockDocument())using(var tr=doc.TransactionManager.StartTransaction()){var table=(LinetypeTable)tr.GetObject(doc.Database.LinetypeTableId,OpenMode.ForRead);return table.Cast<Autodesk.AutoCAD.DatabaseServices.ObjectId>().Select(id=>((LinetypeTableRecord)tr.GetObject(id,OpenMode.ForRead)).Name).OrderBy(n=>n).ToList();}}
  internal static void LoadAll(string path){var doc=Application.DocumentManager.MdiActiveDocument;var definitions=Read(path);if(definitions.Count==0)throw new InvalidOperationException("File LIN không có định nghĩa được hỗ trợ.");using(doc.LockDocument()){foreach(var definition in definitions){try{doc.Database.LoadLineTypeFile(definition.Name,path);}catch(Autodesk.AutoCAD.Runtime.Exception ex){if(ex.ErrorStatus!=Autodesk.AutoCAD.Runtime.ErrorStatus.DuplicateRecordName)throw;}}}}
  internal static string NextName(Document doc,string desired){using(doc.LockDocument())using(var tr=doc.TransactionManager.StartTransaction()){var table=(LinetypeTable)tr.GetObject(doc.Database.LinetypeTableId,OpenMode.ForRead);if(!table.Has(desired))return desired;for(int i=2;i<1000;i++){var n=desired+"_V"+i;if(!table.Has(n))return n;}throw new InvalidOperationException("Không thể tạo tên phiên bản mới.");}}
  internal static int LoadAndReplace(string path,string name,string oldName,bool replace,bool selectedOnly){var doc=Application.DocumentManager.MdiActiveDocument;var db=doc.Database;using(doc.LockDocument()){db.LoadLineTypeFile(name,path);if(!replace)return 0;Autodesk.AutoCAD.DatabaseServices.ObjectId[] ids;if(selectedOnly){var s=doc.Editor.SelectImplied();ids=s.Status==Autodesk.AutoCAD.EditorInput.PromptStatus.OK?s.Value.GetObjectIds():new Autodesk.AutoCAD.DatabaseServices.ObjectId[0];}else{using(var tr0=db.TransactionManager.StartTransaction()){var blocks=(BlockTable)tr0.GetObject(db.BlockTableId,OpenMode.ForRead);var all=new List<Autodesk.AutoCAD.DatabaseServices.ObjectId>();foreach(var bid in blocks){var btr=(BlockTableRecord)tr0.GetObject(bid,OpenMode.ForRead);if(btr.IsLayout)all.AddRange(btr.Cast<Autodesk.AutoCAD.DatabaseServices.ObjectId>());}ids=all.ToArray();}}
    int count=0;using(var tr=db.TransactionManager.StartTransaction()){foreach(var id in ids){var e=tr.GetObject(id,OpenMode.ForRead,false) as Entity;if(e!=null&&string.Equals(e.Linetype,oldName,StringComparison.OrdinalIgnoreCase)){e.UpgradeOpen();e.Linetype=name;count++;}}tr.Commit();}return count;}}
 }
}
