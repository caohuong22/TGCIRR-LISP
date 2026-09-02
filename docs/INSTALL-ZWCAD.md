# TGIRR CAD — Bản cho ZWCAD

Bản port chạy trên **ZWCAD 2026** (API .NET `ZwSoft.ZwCAD.*`, runtime .NET Framework 4.0/4.8). Về chức năng tương đương bản AutoCAD, trừ một khác biệt quan trọng ở mục Giao diện bên dưới.

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

1. **Giao diện:** ZWCAD **không có API lập trình Ribbon** như AutoCAD (`Autodesk.Windows.RibbonTab`). Ribbon ZWCAD phải tạo bằng **file CUIX**.
   Bản port cung cấp menu kéo xuống `TGIRR_CAD.mnu` (dùng `MENULOAD`) và các **lệnh** để gõ trực tiếp hoặc gán phím tắt:
   - `SBS`, `TL`, `TGL`, `TGN` — lệnh AutoLISP
   - `CPLUS`, `VDNG`, `TNET` — lệnh .NET (`[CommandMethod]`)
2. **Nạp plugin:** không có cơ chế `.bundle` + `PackageContents.xml` như AutoCAD. ZWCAD nạp DLL bằng lệnh `NETLOAD`.

## Cài đặt

1. Đóng gói: chạy `powershell -ExecutionPolicy Bypass -File scripts/package-zwcad.ps1`.
   - Kết quả nằm ở `bundle/TGIRR_CAD_ZWCAD.bundle/`:
     - `Contents/Lisp/` — các file `.lsp` + `TGN.dcl` + loader `TGIRRLoaderZ.lsp` + menu `TGIRR_CAD.mnu`/`.mnl`
     - `Contents/Windows/TGIRR.Zwcad.dll` — plugin .NET
2. Copy vào thư mục riêng (nằm trong Support File Search Path). Có 2 cách:
   - **Cách gọn (flat):** copy tất cả file trong `Contents/Lisp` (`.lsp`, `.dcl`, `.mnu`, `.mnl`) và `Contents/Windows/TGIRR.Zwcad.dll` vào **cùng một thư mục**.
   - **Giữ cấu trúc bundle:** copy nguyên cả 2 thư mục `Contents/Lisp` và `Contents/Windows` vào. Loader tự dò được cả `\Lisp` lẫn `\Windows`, nên cả 2 cách đều chạy.
   Không trộn lẫn nhiều nơi để tránh loader dò nhầm bản cũ.
3. Mở ZWCAD, gõ `APPLOAD` và chọn `TGIRRLoaderZ.lsp` (hoặc gõ `(load "TGIRRLoaderZ.lsp")`).
4. **Xác định thư mục (1 lần):** gõ `TGIRRSETDIR`, chọn file `TGIRR.Zwcad.dll` nơi bạn vừa copy. Lệnh sẽ ghi nhớ đường dẫn này.
5. Gõ `TGIRRLOAD` để nạp đầy đủ (cả Lisp lẫn `NETLOAD` DLL).
6. Thêm menu: gõ `MENULOAD`, duyệt chọn `TGIRR_CAD.mnu`, chọn **TGIRR CAD** rồi bấm *Load*. Menu kéo xuống **TGIRR CAD** sẽ xuất hiện trên thanh menu.

> Mẹo: nếu `TGIRRLOAD` báo không tìm thấy `.lsp`/`.dll`, có nghĩa loader đang trỏ sai thư mục (do findfile dò theo search path). Chạy lại `TGIRRSETDIR` để trỏ cứng vào đúng chỗ.

## Lưu ý về .NET

- DLL `TGIRR.Zwcad.dll` build cho **net48** (mục tiêu mặc định) — phù hợp runtime .NET Framework 4.x của ZWCAD.
- Nếu ZWCAD chặn `NETLOAD` vì bảo mật, thêm thư mục chứa DLL vào danh sách tin cậy (Trusted paths) của ZWCAD.
- Nguồn port: `src/zwcad/` — được sinh tự động từ `src/ribbon/` qua `scripts/port-zwcad.ps1` (map namespace `Autodesk.AutoCAD.*` → `ZwSoft.ZwCAD.*` + vá khác biệt constructor).

## Khác biệt API đã xử lý khi port

- `Line`/`Polyline`: ZWCAD chỉ có constructor không tham số (dùng setter `StartPoint`/`EndPoint`).
- `Plane`: không có constructor không tham số (dùng `new Plane(new Point3d(0,0,0), new Vector3d(0,0,1))`).
- `TypedValue`: nằm ở `ZwSoft.ZwCAD.DatabaseServices` (không phải `EditorInput`).
- Truy cập document: `ZwSoft.ZwCAD.ApplicationServices.Core.Application.DocumentManager.MdiActiveDocument`.