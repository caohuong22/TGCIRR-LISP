using Gssoft.Gscad.ApplicationServices;
using Gssoft.Gscad.Runtime;

namespace Tgirrr.CadLisp {
 /// <summary>
 /// Lệnh TNET: mở hộp thoại tạo/chỉnh sửa nét vẽ có chữ.
 /// Cho phép gõ TNET trực tiếp tại dòng lệnh AutoCAD, ngoài nút Ribbon.
 /// </summary>
 public sealed class LinetypeCommands {
  [CommandMethod("TNET")]
  public void Run() {
   Gssoft.Gscad.ApplicationServices.Core.Application.ShowModalWindow(new LinetypeWindow());
  }
 }
}