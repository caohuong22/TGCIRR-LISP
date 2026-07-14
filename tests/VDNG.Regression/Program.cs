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
  Console.WriteLine($"VDNG regression: {passed} tests passed.");
 }
}
