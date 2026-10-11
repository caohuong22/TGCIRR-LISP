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
    ed?.WriteMessage("\n[TGIRR] Đã hiển thị Ribbon Tab 'TGIRR CAD LISP'.\n");
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
    // Moi panel + nut sinh tu TgToolCatalog (nguồn src/catalog/tools.json),
    // nen tooltip cua Ribbon khong the lech voi palette / menu / docs.
    foreach (TgToolCatalog.TgRibbonPanel def in TgToolCatalog.RibbonPanels){
      var items=new List<RibbonItem>();
      foreach (TgToolInfo tool in def.Items){
        if(tool==null)continue;
        var tip=new RibbonToolTip{Title=tool.TipTitle,Content=tool.TipDesc,Command=tool.TipCommand};
        if(!string.IsNullOrEmpty(tool.TipUsage)) tip.ExpandedContent="Cách dùng:\n"+tool.TipUsage;
        var image=IconFor(TgToolCatalog.RibbonIconByKey(tool.Id));
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

  static ImageSource IconFor(string key){
    switch(key){
      case "exact": return ExactSelectIcon();
      case "boundary": return BoundaryIcon();
      case "joinhatch": return JoinHatchIcon();
      case "measure": return MeasureIcon();
      case "layers": return LayerIcon();
      case "linetype": return LinetypeIcon();
      case "copynumber": return CopyNumberIcon();
      case "dotext": return DoiTextIcon();
      default: return Icon();
    }
  }
  static ImageSource Icon(){var g=new DrawingGroup();var cyan=new SolidColorBrush(Color.FromRgb(78,190,232));var white=new SolidColorBrush(Color.FromRgb(232,239,247));var muted=new SolidColorBrush(Color.FromRgb(132,150,170));var yellow=new SolidColorBrush(Color.FromRgb(255,196,61));var dark=new SolidColorBrush(Color.FromArgb(180,30,40,53));var boundary=new Pen(cyan,1.6){DashStyle=new DashStyle(new double[]{2.2,1.4},0)};var fine=new Pen(white,1.35);var dim=new Pen(muted,1.1);var focus=new Pen(yellow,1.8);g.Children.Add(new GeometryDrawing(dark,null,new RectangleGeometry(new Rect(1,1,30,30),3,3)));g.Children.Add(new GeometryDrawing(null,boundary,new RectangleGeometry(new Rect(4,5,24,21),1,1)));g.Children.Add(new GeometryDrawing(null,dim,new EllipseGeometry(new Point(10,12),3.2,3.2)));g.Children.Add(new GeometryDrawing(null,dim,new LineGeometry(new Point(17,9),new Point(24,14))));g.Children.Add(new GeometryDrawing(null,fine,new RectangleGeometry(new Rect(7,18,6,4))));g.Children.Add(new GeometryDrawing(null,focus,new EllipseGeometry(new Point(21,20),3.5,3.5)));var cursor=new StreamGeometry();using(var c=cursor.Open()){c.BeginFigure(new Point(24,22),true,true);c.LineTo(new Point(29,29),true,false);c.LineTo(new Point(25.5,28),true,false);c.LineTo(new Point(23.5,31),true,false);c.LineTo(new Point(22,23),true,false);}cursor.Freeze();g.Children.Add(new GeometryDrawing(white,new Pen(new SolidColorBrush(Color.FromRgb(25,32,43)),0.8),cursor));var image=new DrawingImage(g);image.Freeze();return image;}
  static ImageSource ExactSelectIcon(){var g=new DrawingGroup();var cyan=new SolidColorBrush(Color.FromRgb(78,190,232));var white=new SolidColorBrush(Color.FromRgb(232,239,247));var yellow=new SolidColorBrush(Color.FromRgb(255,196,61));var dark=new SolidColorBrush(Color.FromArgb(180,30,40,53));var boundary=new Pen(cyan,1.6){DashStyle=new DashStyle(new double[]{2.2,1.4},0)};g.Children.Add(new GeometryDrawing(dark,null,new RectangleGeometry(new Rect(1,1,30,30),3,3)));g.Children.Add(new GeometryDrawing(null,boundary,new RectangleGeometry(new Rect(3,4,26,22),1,1)));var fT=new FormattedText("T",System.Globalization.CultureInfo.InvariantCulture,FlowDirection.LeftToRight,new Typeface("Segoe UI Bold"),10,cyan,1);g.Children.Add(new GeometryDrawing(cyan,null,fT.BuildGeometry(new Point(6,7))));var fEq=new FormattedText("=",System.Globalization.CultureInfo.InvariantCulture,FlowDirection.LeftToRight,new Typeface("Segoe UI Bold"),12,yellow,1);g.Children.Add(new GeometryDrawing(yellow,null,fEq.BuildGeometry(new Point(14,6))));var cursor=new StreamGeometry();using(var c=cursor.Open()){c.BeginFigure(new Point(24,22),true,true);c.LineTo(new Point(29,29),true,false);c.LineTo(new Point(25.5,28),true,false);c.LineTo(new Point(23.5,31),true,false);c.LineTo(new Point(22,23),true,false);}cursor.Freeze();g.Children.Add(new GeometryDrawing(white,new Pen(new SolidColorBrush(Color.FromRgb(25,32,43)),0.8),cursor));var image=new DrawingImage(g);image.Freeze();return image;}
  static ImageSource MeasureIcon(){var g=new DrawingGroup();var cyan=new SolidColorBrush(Color.FromRgb(78,190,232));var white=new SolidColorBrush(Color.FromRgb(232,239,247));var yellow=new SolidColorBrush(Color.FromRgb(255,196,61));var dark=new SolidColorBrush(Color.FromArgb(180,30,40,53));g.Children.Add(new GeometryDrawing(dark,null,new RectangleGeometry(new Rect(1,1,30,30),3,3)));var curve=new StreamGeometry();using(var c=curve.Open()){c.BeginFigure(new Point(4,23),false,false);c.BezierTo(new Point(9,5),new Point(19,29),new Point(28,8),true,false);}curve.Freeze();g.Children.Add(new GeometryDrawing(null,new Pen(cyan,2),curve));g.Children.Add(new GeometryDrawing(yellow,null,new EllipseGeometry(new Point(4,23),2.2,2.2)));g.Children.Add(new GeometryDrawing(yellow,null,new EllipseGeometry(new Point(28,8),2.2,2.2)));g.Children.Add(new GeometryDrawing(null,new Pen(white,1.2),new LineGeometry(new Point(7,27),new Point(25,27))));for(int x=8;x<=24;x+=4)g.Children.Add(new GeometryDrawing(null,new Pen(white,1),new LineGeometry(new Point(x,24),new Point(x,29))));var image=new DrawingImage(g);image.Freeze();return image;}
  static ImageSource LayerIcon(){var g=new DrawingGroup();var dark=new SolidColorBrush(Color.FromArgb(180,30,40,53));var edge=new Pen(new SolidColorBrush(Color.FromRgb(225,235,245)),1);g.Children.Add(new GeometryDrawing(dark,null,new RectangleGeometry(new Rect(1,1,30,30),3,3)));AddLayerShape(g,16,8,new SolidColorBrush(Color.FromRgb(78,190,232)),edge);AddLayerShape(g,16,14,new SolidColorBrush(Color.FromRgb(255,196,61)),edge);AddLayerShape(g,16,20,new SolidColorBrush(Color.FromRgb(77,210,142)),edge);var image=new DrawingImage(g);image.Freeze();return image;}
  static void AddLayerShape(DrawingGroup g,double x,double y,Brush fill,Pen edge){var geo=new StreamGeometry();using(var c=geo.Open()){c.BeginFigure(new Point(x,y-5),true,true);c.LineTo(new Point(x+11,y),true,false);c.LineTo(new Point(x,y+5),true,false);c.LineTo(new Point(x-11,y),true,false);}geo.Freeze();g.Children.Add(new GeometryDrawing(fill,edge,geo));}
  static ImageSource LinetypeIcon(){var g=new DrawingGroup();var dark=new SolidColorBrush(Color.FromArgb(180,30,40,53));var cyan=new SolidColorBrush(Color.FromRgb(78,190,232));var yellow=new SolidColorBrush(Color.FromRgb(255,196,61));g.Children.Add(new GeometryDrawing(dark,null,new RectangleGeometry(new Rect(1,1,30,30),3,3)));g.Children.Add(new GeometryDrawing(null,new Pen(cyan,2),new LineGeometry(new Point(3,17),new Point(10,17))));g.Children.Add(new GeometryDrawing(null,new Pen(cyan,2),new LineGeometry(new Point(22,17),new Point(29,17))));var f=new FormattedText("A",System.Globalization.CultureInfo.InvariantCulture,FlowDirection.LeftToRight,new Typeface("Segoe UI Semibold"),13,yellow,1);g.Children.Add(new GeometryDrawing(yellow,null,f.BuildGeometry(new Point(12,8))));g.Children.Add(new GeometryDrawing(null,new Pen(Brushes.White,1),new LineGeometry(new Point(5,25),new Point(27,25))));var image=new DrawingImage(g);image.Freeze();return image;}
  static ImageSource CopyNumberIcon(){return CopyStepIcon("+");}
  static ImageSource CopyMinusIcon(){return CopyStepIcon("−");}
  static ImageSource CopyStepIcon(string sign){var g=new DrawingGroup();var dark=new SolidColorBrush(Color.FromArgb(180,30,40,53));var white=new SolidColorBrush(Color.FromRgb(232,239,247));var cyan=new SolidColorBrush(Color.FromRgb(78,190,232));var yellow=new SolidColorBrush(Color.FromRgb(255,196,61));g.Children.Add(new GeometryDrawing(dark,null,new RectangleGeometry(new Rect(1,1,30,30),3,3)));g.Children.Add(new GeometryDrawing(null,new Pen(cyan,1.5),new RectangleGeometry(new Rect(5,5,15,17),1,1)));g.Children.Add(new GeometryDrawing(null,new Pen(white,1.5),new RectangleGeometry(new Rect(11,10,15,17),1,1)));var f=new FormattedText(sign,System.Globalization.CultureInfo.InvariantCulture,FlowDirection.LeftToRight,new Typeface("Segoe UI Bold"),13,yellow,1);g.Children.Add(new GeometryDrawing(yellow,null,f.BuildGeometry(new Point(17,12))));var image=new DrawingImage(g);image.Freeze();return image;}
  static ImageSource BoundaryIcon(){var g=new DrawingGroup();var cyan=new SolidColorBrush(Color.FromRgb(78,190,232));var green=new SolidColorBrush(Color.FromRgb(77,210,142));var dark=new SolidColorBrush(Color.FromArgb(180,30,40,53));g.Children.Add(new GeometryDrawing(dark,null,new RectangleGeometry(new Rect(1,1,30,30),3,3)));for(int i=6;i<=22;i+=4){g.Children.Add(new GeometryDrawing(null,new Pen(green,1){DashStyle=new DashStyle(new double[]{1.5,1.5},0)},new LineGeometry(new Point(i,22),new Point(i+6,10))));}g.Children.Add(new GeometryDrawing(null,new Pen(cyan,2),new RectangleGeometry(new Rect(4,7,24,18),2,2)));var image=new DrawingImage(g);image.Freeze();return image;}
  static ImageSource JoinHatchIcon(){var g=new DrawingGroup();var cyan=new SolidColorBrush(Color.FromRgb(78,190,232));var yellow=new SolidColorBrush(Color.FromRgb(255,196,61));var dark=new SolidColorBrush(Color.FromArgb(180,30,40,53));g.Children.Add(new GeometryDrawing(dark,null,new RectangleGeometry(new Rect(1,1,30,30),3,3)));var path=new StreamGeometry();using(var c=path.Open()){c.BeginFigure(new Point(4,8),true,true);c.LineTo(new Point(18,8),true,false);c.LineTo(new Point(18,13),true,false);c.LineTo(new Point(27,13),true,false);c.LineTo(new Point(27,24),true,false);c.LineTo(new Point(13,24),true,false);c.LineTo(new Point(13,19),true,false);c.LineTo(new Point(4,19),true,false);}path.Freeze();g.Children.Add(new GeometryDrawing(new SolidColorBrush(Color.FromArgb(60,77,210,142)),new Pen(cyan,1.8),path));g.Children.Add(new GeometryDrawing(null,new Pen(yellow,1.5),new LineGeometry(new Point(8,13),new Point(23,19))));var image=new DrawingImage(g);image.Freeze();return image;}
  static ImageSource DoiTextIcon(){var g=new DrawingGroup();var dark=new SolidColorBrush(Color.FromArgb(180,30,40,53));var cyan=new SolidColorBrush(Color.FromRgb(78,190,232));var white=new SolidColorBrush(Color.FromRgb(232,239,247));var yellow=new SolidColorBrush(Color.FromRgb(255,196,61));g.Children.Add(new GeometryDrawing(dark,null,new RectangleGeometry(new Rect(1,1,30,30),3,3)));var fM=new FormattedText("M",System.Globalization.CultureInfo.InvariantCulture,FlowDirection.LeftToRight,new Typeface("Segoe UI Bold"),11,cyan,1);g.Children.Add(new GeometryDrawing(cyan,null,fM.BuildGeometry(new Point(3,5))));g.Children.Add(new GeometryDrawing(null,new Pen(yellow,1.5),new LineGeometry(new Point(14,11),new Point(18,11))));var arrow=new StreamGeometry();using(var c=arrow.Open()){c.BeginFigure(new Point(17,8.5),true,true);c.LineTo(new Point(20.5,11),true,false);c.LineTo(new Point(17,13.5),true,false);}arrow.Freeze();g.Children.Add(new GeometryDrawing(yellow,null,arrow));var fT=new FormattedText("T",System.Globalization.CultureInfo.InvariantCulture,FlowDirection.LeftToRight,new Typeface("Segoe UI Bold"),11,white,1);g.Children.Add(new GeometryDrawing(white,null,fT.BuildGeometry(new Point(22,5))));var linePen=new Pen(cyan,1.4);var linePenMuted=new Pen(white,1.2);g.Children.Add(new GeometryDrawing(null,linePen,new LineGeometry(new Point(4,20),new Point(27,20))));g.Children.Add(new GeometryDrawing(null,linePenMuted,new LineGeometry(new Point(4,24),new Point(23,24))));g.Children.Add(new GeometryDrawing(null,linePen,new LineGeometry(new Point(4,28),new Point(26,28))));g.Children.Add(new GeometryDrawing(yellow,null,new EllipseGeometry(new Point(2,20),1,1)));g.Children.Add(new GeometryDrawing(yellow,null,new EllipseGeometry(new Point(2,24),1,1)));g.Children.Add(new GeometryDrawing(yellow,null,new EllipseGeometry(new Point(2,28),1,1)));var image=new DrawingImage(g);image.Freeze();return image;}
 }
 public sealed class LispHandler:ICommand{readonly string command;readonly bool preserveSelection;public LispHandler(string value,bool keepSelection=false){command=value;preserveSelection=keepSelection;}public event EventHandler CanExecuteChanged{add{}remove{}}public bool CanExecute(object parameter)=>Autodesk.AutoCAD.ApplicationServices.Application.DocumentManager.MdiActiveDocument!=null;public void Execute(object parameter){var doc=Autodesk.AutoCAD.ApplicationServices.Application.DocumentManager.MdiActiveDocument;if(doc!=null)doc.SendStringToExecute((preserveSelection?"":"\x1b\x1b")+"_."+command+" ",true,false,false);}}
 public sealed class WindowHandler:ICommand{readonly string command;public WindowHandler(string value){command=value;}public event EventHandler CanExecuteChanged{add{}remove{}}public bool CanExecute(object parameter)=>Autodesk.AutoCAD.ApplicationServices.Application.DocumentManager.MdiActiveDocument!=null;public void Execute(object parameter){var doc=Autodesk.AutoCAD.ApplicationServices.Application.DocumentManager.MdiActiveDocument;if(doc!=null)doc.SendStringToExecute((command=="TNET"?"\x1b\x1b":"")+"_."+command+" ",true,false,false);}}
}
