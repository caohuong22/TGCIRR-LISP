using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Tgirrr.CadLisp;

class Tests {
 static int passed;
 static void Check(string name, bool ok) { if (!ok) throw new Exception("FAILED: " + name); Console.WriteLine("PASS: " + name); passed++; }
 static string Nl { get { return Environment.NewLine; } }

 static void Main() {
  string dir = Path.Combine(Path.GetTempPath(), "TGIRR_TNET_" + Guid.NewGuid().ToString("N"));
  Directory.CreateDirectory(dir);
  try {
   // --- Sinh dinh nghia ---
   string simple = LinetypeFile.Definition("DASH", "Dashes", 0.5, 0.25, "", "Standard", 0, 1, 0.75);
   Check("definition simple", simple == "*DASH,Dashes" + Nl + "A,0.5,-0.25,-0.75");
   string complex = LinetypeFile.Definition("TXT", "Text", 2.5, 1.25, "ABC", "Standard", 0.5, 0.8, 3);
   Check("definition complex", complex == "*TXT,Text" + Nl + "A,2.5,-1.25,[\"ABC\",Standard,y=0.5,s=0.8,u=0],-3");
   Check("definition quotes replaced", LinetypeFile.Definition("Q", "", 1, 1, "A\"B", "Standard", 0, 1, 1).Contains("[\"A'B\","));
   Check("definition uses absolute values", LinetypeFile.Definition("N", "", -2, -1, "", "Standard", 0, 1, -3).Contains("A,2,-1,-3"));

   // --- Doc file LIN ---
   string path = Path.Combine(dir, "test.lin");
   File.WriteAllText(path, "*DASH,Dashes" + Nl + "A,0.5,-0.25" + Nl + "*TXT,Text" + Nl + "A,2.5,-1.25,[\"ABC\",Standard,y=0.5,s=0.8,u=0],-3" + Nl);
   List<LinetypeDefinition> list = LinetypeFile.Read(path);
   Check("read count", list.Count == 2);
   Check("read simple fields", list[0].Name == "DASH" && list[0].Description == "Dashes" && Math.Abs(list[0].Dash - 0.5) < 1e-9 && Math.Abs(list[0].Before - 0.25) < 1e-9 && Math.Abs(list[0].After - 0.25) < 1e-9);
   Check("read complex fields", list[1].Name == "TXT" && list[1].Text == "ABC" && list[1].Style == "Standard" && Math.Abs(list[1].Y - 0.5) < 1e-9 && Math.Abs(list[1].Scale - 0.8) < 1e-9 && Math.Abs(list[1].After - 3) < 1e-9);

   string broken = Path.Combine(dir, "broken.lin");
   File.WriteAllText(broken, "*BAD" + Nl + "not-a-pattern" + Nl + "*GOOD" + Nl + "A,1,-0.1" + Nl);
   Check("read ignores malformed", LinetypeFile.Read(broken).Count == 1 && LinetypeFile.Read(broken)[0].Name == "GOOD");
   Check("read missing file", LinetypeFile.Read(Path.Combine(dir, "missing.lin")).Count == 0);

   // --- Ghi file LIN ---
   string output = Path.Combine(dir, "output.lin");
   LinetypeFile.Save(output, "DASH", simple);
   Check("save creates file", File.Exists(output) && LinetypeFile.Read(output).Count == 1);
   LinetypeFile.Save(output, "TXT", complex);
   Check("save appends", LinetypeFile.Read(output).Count == 2);
   string updated = LinetypeFile.Definition("DASH", "Updated", 3, 0.3, "", "Standard", 0, 1, 0.3);
   LinetypeFile.Save(output, "DASH", updated);
   List<LinetypeDefinition> after = LinetypeFile.Read(output);
   Check("save replaces old definition", after.Count == 2 && after.Count(x => x.Name == "DASH") == 1 && Math.Abs(after.First(x => x.Name == "DASH").Dash - 3) < 1e-9);
   Check("save keeps other definitions", after.Any(x => x.Name == "TXT"));

   // --- Vong lap Definition -> Save -> Read ---
   string roundtrip = Path.Combine(dir, "roundtrip.lin");
   LinetypeFile.Save(roundtrip, "TXT", complex);
   LinetypeDefinition read = LinetypeFile.Read(roundtrip).Single();
   Check("roundtrip text", read.Text == "ABC" && read.Style == "Standard");
   Check("roundtrip numbers", Math.Abs(read.Dash - 2.5) < 1e-9 && Math.Abs(read.Before - 1.25) < 1e-9 && Math.Abs(read.Y - 0.5) < 1e-9 && Math.Abs(read.Scale - 0.8) < 1e-9 && Math.Abs(read.After - 3) < 1e-9);
   Check("roundtrip source path", read.SourcePath == roundtrip);

   Console.WriteLine($"TNET regression: {passed} tests passed.");
  } finally {
   try { Directory.Delete(dir, true); } catch (Exception) { }
  }
 }
}
