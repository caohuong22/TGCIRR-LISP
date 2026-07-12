using System;using System.Collections.Generic;using System.Globalization;using System.Text.RegularExpressions;
namespace Tgirrr.CadLisp {
 internal sealed class SequencePart { public int Start,Length;public string Value,Label;public bool Numeric;public override string ToString()=>Label; }
 internal enum SequenceKind { Number,Letters,Custom }
 internal enum CustomEnd { Stop,Cycle,Hold }
 internal sealed class SequenceSettings { public SequencePart Part;public SequenceKind Kind;public int Step=1;public string[] Values;public CustomEnd End; }
 internal static class CopySequenceService {
  internal static List<SequencePart> Parts(string text){var list=new List<SequencePart>();int n=0,a=0;foreach(Match m in Regex.Matches(text,@"[0-9]+|[A-Za-z]+")){bool num=char.IsDigit(m.Value[0]);if(num)n++;else a++;list.Add(new SequencePart{Start=m.Index,Length=m.Length,Value=m.Value,Numeric=num,Label=(num?"Cụm số "+n:"Cụm chữ "+a)+": "+m.Value});}return list;}
  static string Letters(long value){if(value<1)value=1;var s="";while(value>0){value--;s=(char)('A'+value%26)+s;value/=26;}return s;}
  static long LetterValue(string value){long n=0;foreach(char c in value.ToUpperInvariant())n=n*26+(c-'A'+1);return n;}
  internal static string Value(SequenceSettings s,int index){if(s.Kind==SequenceKind.Number){long start=long.Parse(s.Part.Value,CultureInfo.InvariantCulture),v=start+(long)s.Step*index;var raw=Math.Abs(v).ToString(CultureInfo.InvariantCulture).PadLeft(s.Part.Value.Length,'0');return(v<0?"-":"")+raw;}if(s.Kind==SequenceKind.Letters)return Letters(LetterValue(s.Part.Value)+(long)s.Step*index);if(s.Values==null||s.Values.Length==0)return null;int p=index-1;if(p<s.Values.Length)return s.Values[p];if(s.End==CustomEnd.Stop)return null;if(s.End==CustomEnd.Hold)return s.Values[s.Values.Length-1];return s.Values[p%s.Values.Length];}
  internal static string Apply(string original,SequenceSettings s,int index){var v=Value(s,index);return v==null?null:original.Substring(0,s.Part.Start)+v+original.Substring(s.Part.Start+s.Part.Length);}
 }
}
