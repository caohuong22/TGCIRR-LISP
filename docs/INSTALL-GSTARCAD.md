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

1. **Giao diện:** GstarCAD dùng ribbon riêng (file CUIX/menu) chứ không phải `Autodesk.Windows.Ribbon`. Bản port cung cấp menu kéo xuống `TGIRR_CAD.mnu` (dùng `MENULOAD`) và các **lệnh** để gõ trực tiếp hoặc gán phím tắt:
   - `SBS`, `TL`, `TGL`, `TGN` — lệnh AutoLISP
   - `CPLUS`, `VDNG`, `TNET` — lệnh .NET (`[CommandMethod]`)
2. **Nạp plugin:** GstarCAD nạp DLL bằng lệnh `NETLOAD` (loader Lisp tự gọi `NETLOAD`).

## Cài đặt

1. Đóng gói: chạy `powershell -ExecutionPolicy Bypass -File scripts/package-gscad.ps1`.
   - Kết quả nằm ở `bundle/TGIRR_CAD_GSTARCAD.bundle/`:
     - `Contents/Lisp/` — các file `.lsp` + `TGN.dcl` + loader `TGIRRLoaderG.lsp` + menu `TGIRR_CAD.mnu`/`.mnl`
     - `Contents/Windows/TGIRR.Gscad.dll` — plugin .NET
2. Copy **tất cả file `Contents/Lisp`** (`.lsp`, `.dcl`, `.mnu`, `.mnl`) và `Contents/Windows/TGIRR.Gscad.dll` vào **cùng một thư mục riêng** (nằm trong Support File Search Path). Không trộn lẫn nhiều nơi để tránh loader dò nhầm bản cũ.
3. Mở GstarCAD, gõ `APPLOAD` và chọn `TGIRRLoaderG.lsp` (hoặc gõ `(load "TGIRRLoaderG.lsp")`).
4. **Xác định thư mục (1 lần):** gõ `TGIRRSETDIR`, chọn file `TGIRR.Gscad.dll` nơi bạn vừa copy. Lệnh sẽ ghi nhớ đường dẫn này.
5. Gõ `TGIRRLOAD` để nạp đầy đủ (cả Lisp lẫn `NETLOAD` DLL).
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