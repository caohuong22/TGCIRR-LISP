using System;
using System.Collections.Generic;
using System.Linq;
namespace Tgirrr.CadLisp {
 internal struct DripPoint {internal readonly double X,Y;internal DripPoint(double x,double y){X=x;Y=y;}public static DripPoint operator +(DripPoint p,DripVector v)=>new DripPoint(p.X+v.X,p.Y+v.Y);}
 internal struct DripVector {internal readonly double X,Y;internal DripVector(double x,double y){X=x;Y=y;}internal double Dot(DripPoint p)=>X*p.X+Y*p.Y;public static DripVector operator *(DripVector v,double n)=>new DripVector(v.X*n,v.Y*n);}
 internal struct DripSegment {internal readonly DripPoint Start,End;internal DripSegment(DripPoint start,DripPoint end){Start=start;End=end;}internal double Length=>Math.Sqrt(Math.Pow(End.X-Start.X,2)+Math.Pow(End.Y-Start.Y,2));}
 internal static class DripFillGeometry {internal static List<DripSegment> Fill(IReadOnlyList<DripPoint> polygon,double spacing,DripVector direction){return Fill(polygon,spacing,direction,null);}
  /// <summary>Nếu rowOrigin khác null: các hàng dây nằm đúng tại các offset rowOrigin + k*spacing
  /// chiếu lên pháp tuyến (tức offset song song từ một cạnh chuẩn), thay vì lưới tuyệt đối.</summary>
  internal static List<DripSegment> Fill(IReadOnlyList<DripPoint> polygon,double spacing,DripVector direction,double? rowOrigin){if(polygon==null||polygon.Count<3)throw new ArgumentException("Boundary requires at least three vertices.");if(spacing<=0)throw new ArgumentOutOfRangeException(nameof(spacing));double magnitude=Math.Sqrt(direction.X*direction.X+direction.Y*direction.Y);if(magnitude<=1e-12)throw new ArgumentException("Direction must be non-zero.");direction=new DripVector(direction.X/magnitude,direction.Y/magnitude);var normal=new DripVector(-direction.Y,direction.X);double min=polygon.Min(normal.Dot),max=polygon.Max(normal.Dot);double scale=Math.Max(polygon.Max(p=>Math.Max(Math.Abs(p.X),Math.Abs(p.Y))),max-min);double tolerance=Math.Max(scale*1e-10,1e-8);var result=new List<DripSegment>();double startD=rowOrigin.HasValue?rowOrigin.Value+Math.Ceiling((min+tolerance-rowOrigin.Value)/spacing)*spacing:Math.Ceiling((min+tolerance)/spacing)*spacing;for(double d=startD;d<max-tolerance;d+=spacing){var hits=new List<double>();for(int i=0;i<polygon.Count;i++){DripPoint a=polygon[i],b=polygon[(i+1)%polygon.Count];double na=normal.Dot(a),nb=normal.Dot(b);if(!((na<=d&&nb>d)||(nb<=d&&na>d)))continue;double t=(d-na)/(nb-na);hits.Add(direction.Dot(new DripPoint(a.X+(b.X-a.X)*t,a.Y+(b.Y-a.Y)*t)));}hits.Sort();for(int i=0;i+1<hits.Count;i+=2){if(hits[i+1]-hits[i]<=tolerance)continue;var origin=new DripPoint(normal.X*d,normal.Y*d);result.Add(new DripSegment(origin+direction*hits[i],origin+direction*hits[i+1]));}}return result;}
  /// <summary>Trục dài (principal axis) của tập điểm, dùng khi Boundary KHÔNG có cạnh thẳng nào
  /// (CIRCLE, bồn oval/bầu dục vẽ bằng bulge) để dây chạy dọc theo trục dài của hình.
  /// Trả về vector (0,0) khi hình gần như đẳng hướng (tròn) — caller tự dùng hướng mặc định.</summary>
  internal static DripVector PrincipalAxis(IReadOnlyList<DripPoint> points){
   if(points==null||points.Count<3)return new DripVector(0,0);
   double mx=0,my=0;
   foreach(var q in points){mx+=q.X;my+=q.Y;}
   mx/=points.Count;my/=points.Count;
   double sxx=0,syy=0,sxy=0;
   foreach(var q in points){double dx=q.X-mx,dy=q.Y-my;sxx+=dx*dx;syy+=dy*dy;sxy+=dx*dy;}
   double trace=sxx+syy;
   if(trace<=0)return new DripVector(0,0);
   if(Math.Abs(sxy)<=trace*1e-9&&Math.Abs(sxx-syy)<=trace*1e-9)return new DripVector(0,0);
   double theta=0.5*Math.Atan2(2*sxy,sxx-syy);
   return new DripVector(Math.Cos(theta),Math.Sin(theta));
  }
  /// <summary>Tỉ lệ trục dài/trục ngắn (aspect) của tập điểm qua PCA — ô dài hẹp cho trị lớn, hình tròn ~ 1.
  /// Dùng quyết định ô có đủ "dải hẹp" để tự bám cong theo biên hay giữ hàng thẳng.</summary>
  internal static double AxisElongation(IReadOnlyList<DripPoint> points){
   if(points==null||points.Count<3)return 1;
   double mx=0,my=0;
   foreach(var q in points){mx+=q.X;my+=q.Y;}
   mx/=points.Count;my/=points.Count;
   double sxx=0,syy=0,sxy=0;
   foreach(var q in points){double dx=q.X-mx,dy=q.Y-my;sxx+=dx*dx;syy+=dy*dy;sxy+=dx*dy;}
   double trace=sxx+syy;
   if(trace<=0)return 1;
   double det=sxx*syy-sxy*sxy;
   double disc=Math.Sqrt(Math.Max(trace*trace/4.0-det,0));
   double l1=trace/2.0+disc,l2=trace/2.0-disc;
   return Math.Sqrt(l1/Math.Max(l2,l1*1e-12));
  }
  /// <summary>Nối các đoạn dây thành 1 đường zigzag liên tục (cuộn rắn bò): mỗi hàng đổi chiều, cuối hàng này nối sang đầu hàng kia.</summary>
  internal static List<DripPoint> Serpentine(List<DripSegment> segments,DripVector direction,double spacing){
   var path=new List<DripPoint>();
   if(segments==null||segments.Count==0||spacing<=0)return path;
   double mag=Math.Sqrt(direction.X*direction.X+direction.Y*direction.Y);
   if(mag<=1e-12)return path;
   var dir=new DripVector(direction.X/mag,direction.Y/mag);
   var normal=new DripVector(-dir.Y,dir.X);
   var rows=new List<List<DripSegment>>();
   double rowD=0;
   foreach(var s in segments){
    double d=normal.Dot(s.Start);
    if(rows.Count==0||Math.Abs(d-rowD)>spacing*0.25){rows.Add(new List<DripSegment>());rowD=d;}
    rows[rows.Count-1].Add(s);
   }
   for(int k=0;k<rows.Count;k++){
    var row=rows[k].OrderBy(s=>dir.Dot(s.Start)).ToList();
    bool forward=k%2==0;
    if(!forward)row.Reverse();
    foreach(var s in row){
     if(forward){path.Add(s.Start);path.Add(s.End);}
     else{path.Add(s.End);path.Add(s.Start);}
    }
   }
   return path;
  }
 }
}
