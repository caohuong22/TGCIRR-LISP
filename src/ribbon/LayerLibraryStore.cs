using System;
using System.Collections.Generic;
using Microsoft.Win32;

namespace Tgirrr.CadLisp {
 /// <summary>
 /// Kho Layer tu them cua TGLADD. Dung dung khoa registry cua ban AutoLISP
 /// (HKCU\Software\TGIRR -> LayerLibrary) nen du lieu cu van doc duoc.
 /// </summary>
 internal static class LayerLibraryStore {
  const string SubKey = @"Software\TGIRR";
  const string ValueName = "LayerLibrary";

  internal static List<LayerEntry> Load() {
   try {
    using (RegistryKey key = Registry.CurrentUser.OpenSubKey(SubKey)) {
     return key == null ? new List<LayerEntry>() : LayerSetService.Parse(key.GetValue(ValueName) as string);
    }
   } catch (Exception) {
    return new List<LayerEntry>();
   }
  }

  internal static void Save(IEnumerable<LayerEntry> entries) {
   using (RegistryKey key = Registry.CurrentUser.CreateSubKey(SubKey)) {
    if (key != null) key.SetValue(ValueName, LayerSetService.Format(entries), RegistryValueKind.String);
   }
  }
 }
}
