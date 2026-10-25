using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;

namespace Tgirrr.CadLisp {
 internal sealed class LinetypeDefinition { public string Name,Description,Text,Style,SourcePath;public double Dash,Before,Y,Scale,After; }

 /// <summary>
 /// Doc/ghi file .LIN va sinh dinh nghia net co chu. Tach khoi LinetypeService
 /// (khong dung API CAD) de test hoi quy duoc.
 /// </summary>
 internal static class LinetypeFile {
  static double D(string v){return double.Parse(v,CultureInfo.InvariantCulture);}

  internal static string Definition(string name,string description,double dash,double before,string text,string style,double y,double scale,double after){string F(double v)=>v.ToString("0.######",CultureInfo.InvariantCulture);return "*"+name+","+description+Environment.NewLine+"A,"+F(Math.Abs(dash))+",-"+F(Math.Abs(before))+(string.IsNullOrWhiteSpace(text)?",-"+F(Math.Abs(after)):",[\""+text.Replace("\"","'")+"\","+style+",y="+F(y)+",s="+F(scale)+",u=0],-"+F(Math.Abs(after)));}

  internal static List<LinetypeDefinition> Read(string path){var result=new List<LinetypeDefinition>();if(!File.Exists(path))return result;var lines=File.ReadAllLines(path,Encoding.UTF8);for(int i=0;i<lines.Length-1;i++){if(!lines[i].TrimStart().StartsWith("*")||!lines[i+1].TrimStart().StartsWith("A,"))continue;var header=lines[i].Trim().Substring(1).Split(new[]{','},2);var body=lines[++i].Trim();try{var d=new LinetypeDefinition{Name=header[0].Trim(),Description=header.Length>1?header[1].Trim():"",Style="Standard",Scale=1,SourcePath=path};var complex=Regex.Match(body,"^A,([^,]+),([^,]+),\\[\\\"([^\\\"]*)\\\",([^,\\]]+)([^\\]]*)\\],([^,]+)$",RegexOptions.IgnoreCase);if(complex.Success){d.Dash=Math.Abs(D(complex.Groups[1].Value));d.Before=Math.Abs(D(complex.Groups[2].Value));d.Text=complex.Groups[3].Value;d.Style=complex.Groups[4].Value.Trim();var opts=complex.Groups[5].Value;var ym=Regex.Match(opts,@"y=([^,]+)",RegexOptions.IgnoreCase);var sm=Regex.Match(opts,@"s=([^,]+)",RegexOptions.IgnoreCase);d.Y=ym.Success?D(ym.Groups[1].Value):0;d.Scale=sm.Success?D(sm.Groups[1].Value):1;d.After=Math.Abs(D(complex.Groups[6].Value));}else{var p=body.Split(',');d.Dash=Math.Abs(D(p[1]));d.Before=p.Length>2?Math.Abs(D(p[2])):0;d.After=p.Length>3?Math.Abs(D(p[3])):d.Before;}result.Add(d);}catch{}}
   return result;}

  internal static void Save(string path,string name,string definition){var encoding=new UTF8Encoding(false);var old=File.Exists(path)?File.ReadAllText(path,Encoding.UTF8):"";var lines=old.Replace("\r\n","\n").Split('\n').ToList();var marker="*"+name+",";for(int i=0;i<lines.Count;i++)if(lines[i].StartsWith(marker,StringComparison.OrdinalIgnoreCase)){lines.RemoveAt(i);if(i<lines.Count&&lines[i].TrimStart().StartsWith("A,"))lines.RemoveAt(i);break;}while(lines.Count>0&&string.IsNullOrWhiteSpace(lines.Last()))lines.RemoveAt(lines.Count-1);File.WriteAllText(path,(lines.Count>0?string.Join(Environment.NewLine,lines)+Environment.NewLine:"")+definition+Environment.NewLine,encoding);}
 }
}
