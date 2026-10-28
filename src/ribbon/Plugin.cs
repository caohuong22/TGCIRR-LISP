using Autodesk.AutoCAD.Runtime;
using Autodesk.Windows;
using System;
using System.Windows;
using System.Windows.Input;
using System.Collections.Generic;
using System.Windows.Media;
[assembly: ExtensionApplication(typeof(Tgirrr.CadLisp.Plugin))]
namespace Tgirrr.CadLisp {
 public sealed class Plugin : IExtensionApplication {
  public void Initialize(){
    ComponentManager.ItemInitialized+=OnItem;
    Autodesk.AutoCAD.ApplicationServices.Application.Idle+=OnIdle;
    Build();
  }
  public void Terminate(){
    ComponentManager.ItemInitialized-=OnItem;
    Autodesk.AutoCAD.ApplicationServices.Application.Idle-=OnIdle;
  }
  void OnItem(object sender,RibbonItemEventArgs e)=>Build();
  void OnIdle(object sender,EventArgs e){
    if(ComponentManager.Ribbon!=null){
      Autodesk.AutoCAD.ApplicationServices.Application.Idle-=OnIdle;
      Build();
    }
  }

  [CommandMethod("TGIRR_RIBBON")]
  [CommandMethod("TGIRRRIBBON")]
  public static void ShowRibbonCommand(){
    var doc=Autodesk.AutoCAD.ApplicationServices.Application.DocumentManager.MdiActiveDocument;
    if(ComponentManager.Ribbon==null){
      doc?.SendStringToExecute("_.RIBBON ",true,false,false);
    }
    Build();
    var ribbon=ComponentManager.Ribbon;
    if(ribbon!=null){
      var tab=ribbon.FindTab("TGIRR_TAB");
      if(tab!=null){
        tab.IsVisible=true;
        tab.IsActive=true;
      }
    }
    var ed=doc?.Editor;
    ed?.WriteMessage("\n[TGIRR] ÄÃ£ hiá»ƒn thá»‹ Ribbon Tab 'TGIRR CAD LISP'.\n");
  }
  static void Build(){
    var ribbon=ComponentManager.Ribbon;
    if(ribbon==null)return;
    var existing=ribbon.FindTab("TGIRR_TAB");
    if(existing!=null){
      existing.IsVisible=true;
      return;
    }
    var tab=new RibbonTab{Id="TGIRR_TAB",Title="TGIRR CAD LISP",IsVisible=true};
    // Moi panel + nut sinh tu TgToolCatalog (nguá»“n src/catalog/tools.json),
    // nen tooltip cua Ribbon khong the lech voi palette / menu / docs.
    foreach (TgToolCatalog.TgRibbonPanel def in TgToolCatalog.RibbonPanels){
      var items=new List<RibbonItem>();
      foreach (TgToolInfo tool in def.Items){
        if(tool==null)continue;
        // Lenh da tat trong TGIRRSETTINGS thi khong hien nut (nhuong ten cho LISP khac).
        if(!LoadSettingsStore.IsEnabled(tool.Id))continue;
        var tip=new RibbonToolTip{Title=tool.TipTitle,Content=tool.TipDesc,Command=tool.TipCommand};
        if(!string.IsNullOrEmpty(tool.TipUsage)) tip.ExpandedContent="CÃ¡ch dÃ¹ng:\n"+tool.TipUsage;
        var image=IconFor(tool);
        items.Add(new RibbonButton{
          Text=tool.Id,
          ShowText=false,
          Size=RibbonItemSize.Large,
          Orientation=System.Windows.Controls.Orientation.Vertical,
          CommandHandler=HandlerFor(tool),
          Image=image,
          LargeImage=image,
          ToolTip=tip
        });
      }
      if(items.Count==0)continue;
      var source=new RibbonPanelSource{Title=def.Title};
      foreach (RibbonItem item in items) source.Items.Add(item);
      tab.Panels.Add(new RibbonPanel{Source=source});
    }
    ribbon.Tabs.Add(tab);
    tab.IsActive=true;
  }

  /// <summary>"window" = mo hop thoai dung rieng (TNET); con lai go lenh qua command line.</summary>
  static System.Windows.Input.ICommand HandlerFor(TgToolInfo tool){
    if(tool.Runner=="window") return new WindowHandler(tool.Cmd);
    return new LispHandler(tool.Cmd,tool.KeepSelection);
  }

  /// <summary>Icon vector dung chung (src/shared/ToolIcons.cs) cho moi be mat.</summary>
  static ImageSource IconFor(TgToolInfo tool) {
    return ToolIcons.For(TgToolCatalog.RibbonIconByKey(tool.Id), PaletteTheme.Accent(tool.Accent));
  }
 }
 public sealed class LispHandler:ICommand{readonly string command;readonly bool preserveSelection;public LispHandler(string value,bool keepSelection=false){command=value;preserveSelection=keepSelection;}public event EventHandler CanExecuteChanged{add{}remove{}}public bool CanExecute(object parameter)=>Autodesk.AutoCAD.ApplicationServices.Application.DocumentManager.MdiActiveDocument!=null;public void Execute(object parameter){var doc=Autodesk.AutoCAD.ApplicationServices.Application.DocumentManager.MdiActiveDocument;if(doc!=null)doc.SendStringToExecute((preserveSelection?"":"\x1b\x1b")+"_."+command+" ",true,false,false);}}
 public sealed class WindowHandler:ICommand{readonly string command;public WindowHandler(string value){command=value;}public event EventHandler CanExecuteChanged{add{}remove{}}public bool CanExecute(object parameter)=>Autodesk.AutoCAD.ApplicationServices.Application.DocumentManager.MdiActiveDocument!=null;public void Execute(object parameter){var doc=Autodesk.AutoCAD.ApplicationServices.Application.DocumentManager.MdiActiveDocument;if(doc!=null)doc.SendStringToExecute((command=="TNET"?"\x1b\x1b":"")+"_."+command+" ",true,false,false);}}
}
