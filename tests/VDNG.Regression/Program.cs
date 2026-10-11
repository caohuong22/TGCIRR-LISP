using System;
using System.Collections.Generic;
using System.Linq;
using Tgirrr.CadLisp;
class Tests {
 static int passed;
 static DripPoint P(double x,double y)=>new DripPoint(x,y);
 static void Check(string name,bool ok){if(!ok)throw new Exception("FAILED: "+name);Console.WriteLine("PASS: "+name);passed++;}
 static List<DripSegment> Fill(DripPoint[] p,double s=1)=>DripFillGeometry.Fill(p,s,new DripVector(1,0));
 static void Main(){
  var rectangle=Fill(new[]{P(0,0),P(10,0),P(10,5),P(0,5)});Check("rectangle count",rectangle.Count==4);Check("rectangle lengths",rectangle.All(x=>Math.Abs(x.Length-10)<1e-8));
  var five=Fill(new[]{P(0,0),P(10,0),P(10,5),P(5,6),P(0,5)});Check("five vertex real boundary",five.Count>0&&five.All(x=>x.Length>0));
  var concave=Fill(new[]{P(0,0),P(6,0),P(6,2),P(2,2),P(2,6),P(0,6)});Check("concave split",concave.Count==5);Check("concave stays inside",concave.All(x=>x.Length<=6.0000001));
  var vertex=Fill(new[]{P(0,0),P(5,2),P(10,0),P(10,5),P(0,5)});Check("vertex crossing no zero segments",vertex.Count>0&&vertex.All(x=>x.Length>1e-8));
  var large=Fill(new[]{P(10000000,10000000),P(10000010,10000000),P(10000010,10000005),P(10000000,10000005)});Check("large coordinates",large.Count==4&&large.All(x=>Math.Abs(x.Length-10)<1e-6));
  var wide=Fill(new[]{P(0,0),P(10,0),P(10,2),P(0,2)},5);Check("spacing wider than boundary",wide.Count==0);
  bool rejected=false;try{Fill(new[]{P(0,0),P(1,0),P(1,1)},0);}catch(ArgumentOutOfRangeException){rejected=true;}Check("invalid spacing rejected",rejected);
  var angled=DripFillGeometry.Fill(new[]{P(0,0),P(4,4),P(2,6),P(-2,2)},1,new DripVector(1,1));Check("angled direction",angled.Count>0&&angled.All(x=>x.Length>0));
  // --- Serpentine (zigzag nối dây liên tục) ---
  var rect4=Fill(new[]{P(0,0),P(10,0),P(10,5),P(0,5)});
  var sp=DripFillGeometry.Serpentine(rect4,new DripVector(1,0),1);
  Check("serpentine covers all points",sp.Count==rect4.Count*2);
  // Mỗi bước liền kề trong path: cùng hàng (ngang) hoặc cùng biên độ hàng (đứng, nối 2 hàng kế nhau)
  bool okSteps=true;
  for(int i=0;i+1<sp.Count;i++){
   double dx=sp[i+1].X-sp[i].X,dy=sp[i+1].Y-sp[i].Y;
   bool horizontal=Math.Abs(dy)<1e-9&&dx!=0;
   bool vertical=Math.Abs(dx)<1e-9&&Math.Abs(dy-1)<1e-9;
   if(!horizontal&&!vertical){okSteps=false;break;}
  }
  Check("serpentine steps are row or jump",okSteps);
  Check("serpentine path is continuous from first segment",Math.Abs(sp[0].Y-rect4.Min(s=>s.Start.Y))<1e-9||Math.Abs(sp[0].Y-rect4[0].Start.Y)<1e-9);
  var one=Fill(new[]{P(0,0),P(10,0),P(10,1.5),P(0,1.5)});
  Check("single row serpentine",one.Count==1&&DripFillGeometry.Serpentine(one,new DripVector(1,0),1).Count==2);
  var none=DripFillGeometry.Serpentine(new List<DripSegment>(),new DripVector(1,0),1);
  Check("serpentine empty input",none.Count==0);
  var badVec=DripFillGeometry.Serpentine(rect4,new DripVector(0,0),1);
  Check("serpentine zero direction rejected",badVec.Count==0);
  // --- Offset từ cạnh chuẩn (rowOrigin) ---
  var grid=DripFillGeometry.Fill(new[]{P(0,0),P(10,0),P(10,5),P(0,5)},1,new DripVector(1,0));
  var fromEdge=DripFillGeometry.Fill(new[]{P(0,0),P(10,0),P(10,5),P(0,5)},1,new DripVector(1,0),0.0);
  Check("edge origin equals grid when origin on grid",grid.Count==fromEdge.Count);
  Check("rows terminate on offset boundary",fromEdge.All(s=>Math.Abs(s.Start.X-0)<1e-9&&Math.Abs(s.End.X-10)<1e-9));
  Check("rows preserve requested spacing",fromEdge.Zip(fromEdge.Skip(1),(a,b)=>Math.Abs((b.Start.Y-a.Start.Y)-1.0)<1e-9).All(x=>x));
  var half=DripFillGeometry.Fill(new[]{P(0,0),P(10,0),P(10,5),P(0,5)},1,new DripVector(1,0),0.5);
  Check("edge origin offsets rows",half.Count==5&&half.All(s=>Math.Abs((s.Start.Y-0.5)%1.0)<1e-9||Math.Abs((s.Start.Y-0.5)%1.0-1.0)<1e-9));
  // --- Truc dai cua bien khong co canh thang (CIRCLE / bon oval ve bang bulge) ---
  var oval=new List<DripPoint>();
  for(int i=0;i<180;i++){double t=2*Math.PI*i/180;oval.Add(P(60*Math.Cos(t),25*Math.Sin(t)));}
  var axisOval=DripFillGeometry.PrincipalAxis(oval);
  Check("oval nhan truc dai (ngang)",Math.Abs(axisOval.X)-1<1e-6&&Math.Abs(axisOval.Y)<1e-6);
  var round=new List<DripPoint>();
  for(int i=0;i<120;i++){double t=2*Math.PI*i/120;round.Add(P(30*Math.Cos(t),30*Math.Sin(t)));}
  var axisRound=DripFillGeometry.PrincipalAxis(round);
  Check("hinh tron dang huong -> tra ve (0,0) de dung mac dinh",axisRound.X==0&&axisRound.Y==0);
  var tilted=new List<DripPoint>();
  for(int i=0;i<180;i++){double t=2*Math.PI*i/180;tilted.Add(P(50*Math.Cos(t),12*Math.Sin(t)));}
  var axisTilted=DripFillGeometry.PrincipalAxis(tilted);
  Check("bon dai nam ngang: truc dai ~0 deg",Math.Abs(axisTilted.Y)<1e-6||Math.Abs(Math.Abs(Math.Atan2(axisTilted.Y,axisTilted.X))-Math.PI)<1e-6);
  // --- Huong tu dong cua o dai hep nhieu dinh/cung phai la TRUC DAI (de day chay doc o, khong phai canh ngan) ---
  var strip=new List<DripPoint>();
  for(int i=0;i<=40;i++)strip.Add(P(i*2.5,0.5+Math.Sin(i*0.3)*0.2));
  for(int i=40;i>=0;i--)strip.Add(P(i*2.5,4.5+Math.Sin(i*0.3)*0.2));
  var axisStrip=DripFillGeometry.PrincipalAxis(strip);
  Check("o dai hep nhieu dinh nhan truc doc o",Math.Abs(axisStrip.X)>0.999&&Math.Abs(axisStrip.Y)<0.045);
  var stripRows=DripFillGeometry.Fill(strip,1,new DripVector(axisStrip.X,axisStrip.Y));
  Check("o dai hep ra hang day doc theo truc dai",stripRows.Count==4&&stripRows.All(s=>s.Length>99));
  var circlePts=new List<DripPoint>();
  for(int i=0;i<120;i++){double t=2*Math.PI*i/120;circlePts.Add(P(20*Math.Cos(t),20*Math.Sin(t)));}
  var axisCircle=DripFillGeometry.PrincipalAxis(circlePts);
  Check("hinh tron tra ve (0,0) de roi ve huong mac dinh",axisCircle.X==0&&axisCircle.Y==0);
  // --- Aspect (do dai hep) dung quyet dinh o co tu bam cong theo bien hay giu hang thang ---
  var stripPts=new List<DripPoint>();
  for(int i=0;i<=40;i++)stripPts.Add(P(i*2.5,0));
  for(int i=40;i>=0;i--)stripPts.Add(P(i*2.5,4));
  Check("o dai hep 100x4 aspect >= 5",DripFillGeometry.AxisElongation(stripPts)>=5);
  Check("hinh vuong aspect ~ 1",Math.Abs(DripFillGeometry.AxisElongation(new[]{P(0,0),P(10,0),P(10,10),P(0,10)})-1)<0.05);
  double ovalAspect=DripFillGeometry.AxisElongation(oval);
  Check("oval 60x25 aspect trong khoang 1.8-2.6 (khong tu bam cong)",ovalAspect>1.8&&ovalAspect<2.6);
  Console.WriteLine($"VDNG regression: {passed} tests passed.");
 }
}
