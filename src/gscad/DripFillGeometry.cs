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
