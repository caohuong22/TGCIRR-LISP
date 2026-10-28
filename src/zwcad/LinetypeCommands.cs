using ZwSoft.ZwCAD.ApplicationServices;
using ZwSoft.ZwCAD.Runtime;

namespace Tgirrr.CadLisp {
 /// <summary>
 /// Lệnh TNET: mở hộp thoại tạo/chỉnh sửa nét vẽ có chữ.
 /// Cho phép gõ TNET trực tiếp tại dòng lệnh AutoCAD, ngoài nút Ribbon.
 /// </summary>
 public sealed class LinetypeCommands {
  [CommandMethod("TGIRRTNET")]
  public void Run() {
   ZwSoft.ZwCAD.ApplicationServices.Core.Application.ShowModalWindow(new LinetypeWindow());
  }
 }
}