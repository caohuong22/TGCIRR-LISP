# TGIRR CAD — Bản cho GstarCAD

Bản port chạy trên **GstarCAD 2027** (API .NET `Gssoft.Gscad.*`, runtime **.NET 8.0**). Về chức năng tương đương bản AutoCAD, trừ một khác biệt quan trọng ở mục Giao diện bên dưới.

## Thành phần

| Nhóm | Lệnh | Chức năng | Viết bằng |
|---|---|---|---|
| CHỌN | SBS | Chọn đối tượng giống mẫu nằm phần lớn trong Polyline kín | AutoLISP |
| ĐO | TL | Cộng tổng chiều dài các đường đã chọn trước | AutoLISP |
| LAYER | TGL | Tạo bộ Layer tiêu chuẩn, đặt `TG-DRIP` làm layer hiện hành | AutoLISP |
| ĐÁNH SỐ | TGN | Đánh số đối tượng / vùng tưới bằng nhãn tròn/ellipse | AutoLISP + DCL |
| VĂN BẢN | CPLUS | Copy TEXT/MTEXT/Multileader/Attribute/Dimension Override theo quy luật | .NET |
| TƯỚI | VDNG | Vẽ dây nhỏ giọt bên trong Boundary kín | .NET |
| NÉT VẼ | TNET | Hộp thoại tạo/chỉnh sửa nét vẽ có chữ (file LIN) | .NET |

## Khác biệt so với bản AutoCAD

1. **Giao diện:** GstarCAD dùng ribbon riêng (file CUIX) chứ không phải `Autodesk.Windows.Ribbon`. Bản port dùng **PaletteSet dockable** (bảng công cụ neo được, API `Gssoft.Gscad.Windows.PaletteSet`) chứa các nút bấm tương tự Ribbon:
   - Gõ `TGIRRPALETTE` để mở/đóng bảng công cụ **TGIRR CAD** (loader `TGIRRLOAD` tự mở sau khi nạp).
   - Palette **tự nhớ vị trí, kích thước và trạng thái neo (dock)** giữa các lần mở CAD (lưu tại `%APPDATA%\TGIRR\palette-state.txt` — host không tự lưu nên plugin tự ghi khi di chuyển/thay đổi kích thước/ẩn).
   - **Quick Tools (palette riêng)**: mỗi nút đều có ★ ở góc phải (đang hiện mờ khi chưa ghim, rõ khi đã ghim) — bấm ★ để **ghim nút đó vào palette "TGIRR QUICK TOOLS" riêng biệt** (dockable, dock/kéo thả độc lập với palette chính; bấm ★ lần nữa để bỏ ghim). Gõ `TGIRRQUICK` để ẩn/hiện palette Quick Tools. Quick Tools **tự mở khi có nút ghim và tự ẩn khi bỏ ghim hết**; ★ được đồng bộ hai chiều giữa hai palette.
   - **Tìm nhanh lệnh**: gõ vào ô *Tìm lệnh* ở đầu palette (phím tắt `Ctrl+F`, `Enter` chạy lệnh khớp đầu tiên, `Esc` xoá lọc). Tìm được cả theo mã lệnh, tên nút và biệt danh (`BH`, `M2T`, `CVPLG`...).
   - **Thu gọn nhóm**: bấm vào tiêu đề nhóm (RANH GIỚI & BIÊN DẠNG / THIẾT KẾ & HỆ THỐNG / GHI CHÚ & TIỆN ÍCH) để đóng/mở; trạng thái thu gọn được nhớ (`%APPDATA%\TGIRR\palette-layout.txt`).
   - Danh sách ghim (`%APPDATA%\TGIRR\quick-tools.txt`), vị trí/kích thước/dock từng palette (`palette-state.txt`, `quick-palette-state.txt`) đều được nhớ giữa các phiên CAD; ghi file theo kiểu atomic nên không hỏng dữ liệu khi CAD bị crash. Lệnh bị xoá/đổi tên sẽ tự được gỡ khỏi danh sách ghim.
   - Đầu palette có hai nút: **⚡ Quick** (ẩn/hiện Quick Tools) và **⟳ Nạp lại** (chạy `TGIRRLOAD`).
   - Ngoài ra vẫn có menu kéo xuống `TGIRR_CAD.mnu` (dùng `MENULOAD`) và các **lệnh** gõ trực tiếp:
   - `SBS`, `TL`, `TGL`, `TGN` — lệnh AutoLISP
   - `CPLUS`, `VDNG`, `TNET` — lệnh .NET (`[CommandMethod]`)
2. **Nạp plugin:** GstarCAD nạp DLL bằng lệnh `NETLOAD` (loader Lisp tự gọi `NETLOAD`).

## Cài đặt

1. Đóng gói: chạy `powershell -ExecutionPolicy Bypass -File scripts/package-gscad.ps1`.
   - Kết quả nằm ở `bundle/TGIRR_CAD_GSTARCAD.bundle/`:
     - `Contents/Lisp/` — các file `.lsp` + `TGN.dcl` + loader `TGIRRLoaderG.lsp` + menu `TGIRR_CAD.mnu`/`.mnl`
     - `Contents/Windows/TGIRR.Gscad.dll` — plugin .NET
2. Copy vào thư mục riêng (nằm trong Support File Search Path). Có 2 cách:
   - **Cách gọn (flat):** copy tất cả file trong `Contents/Lisp` (`.lsp`, `.dcl`, `.mnu`, `.mnl`) và `Contents/Windows/TGIRR.Gscad.dll` vào **cùng một thư mục**.
   - **Giữ cấu trúc bundle:** copy nguyên cả 2 thư mục `Contents/Lisp` và `Contents/Windows` vào. Loader tự dò được cả `\Lisp` lẫn `\Windows`, nên cả 2 cách đều chạy.
   Không trộn lẫn nhiều nơi để tránh loader dò nhầm bản cũ.
3. Mở GstarCAD, gõ `APPLOAD` và chọn `TGIRRLoaderG.lsp` (hoặc gõ `(load "TGIRRLoaderG.lsp")`).
4. **Xác định thư mục (1 lần):** gõ `TGIRRSETDIR`, chọn file `TGIRR.Gscad.dll` nơi bạn vừa copy. Lệnh sẽ ghi nhớ đường dẫn này.
5. Gõ `TGIRRLOAD` để nạp đầy đủ (cả Lisp lẫn `NETLOAD` DLL) — bảng công cụ **TGIRR CAD** sẽ tự mở. Nếu muốn mở/đóng lại, gõ `TGIRRPALETTE`.
6. Thêm menu: gõ `MENULOAD`, duyệt chọn `TGIRR_CAD.mnu`, chọn **TGIRR CAD** rồi bấm *Load*. Menu kéo xuống **TGIRR CAD** sẽ xuất hiện trên thanh menu.

> Mẹo: nếu `TGIRRLOAD` báo không tìm thấy `.lsp`/`.dll`, có nghĩa loader đang trỏ sai thư mục (do findfile dò theo search path). Chạy lại `TGIRRSETDIR` để trỏ cứng vào đúng chỗ.

## Lưu ý về .NET

- DLL `TGIRR.Gscad.dll` build cho **net8.0-windows** — phù hợp runtime .NET 8 của GstarCAD 2027.
- Nếu GstarCAD chặn `NETLOAD` vì bảo mật, thêm thư mục chứa DLL vào danh sách tin cậy (Trusted paths).
- Nguồn port: `src/gscad/` — được sinh tự động từ `src/ribbon/` qua `scripts/port-gscad.ps1` (map namespace `Autodesk.AutoCAD.*` → `Gssoft.Gscad.*`).

## Khác biệt API đã xử lý khi port

- Namespace gốc GstarCAD là `Gssoft.Gscad.*` (khác hẳn `Autodesk.AutoCAD.*` và `ZwSoft.ZwCAD.*`).
- `Application.DocumentManager` nằm ở `Gssoft.Gscad.ApplicationServices.Core.Application.DocumentManager` (lớp `Application` cơ sở chỉ có `ShowModalWindow(Uri)`).
- `Application.ShowModalWindow(System.Windows.Window)` cũng nằm ở `Core.Application`.
- Về constructor và phần lớn các kiểu trong `Geometry`/`DatabaseServices`, GstarCAD tương thích trực tiếp với ObjectARX (không cần vá như ZWCAD).
