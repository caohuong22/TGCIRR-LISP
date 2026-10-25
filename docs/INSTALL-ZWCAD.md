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

1. **Giao diện:** ZWCAD **không có API lập trình Ribbon** như AutoCAD (`Autodesk.Windows.RibbonTab`). Thay vào đó bản port dùng **PaletteSet dockable** (bảng công cụ neo được, API `ZwSoft.ZwCAD.Windows.PaletteSet`) chứa các nút bấm tương tự Ribbon:
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
- **Thanh công cụ icon native**: gõ `TGIRRBAR` để bật thanh **TGIRR CAD** (mỗi lệnh là 1 nút icon 16×16/32×32, dock trái/phải/trên, kéo thả tự do, tooltip tiếng Việt). Lệnh tự thêm thư mục chứa icon vào Support File Search Path, tự `MENULOAD` nếu chưa nạp rồi bật thanh. Đây là thanh native của CAD nên nhẹ và gọn hơn palette.
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
5. Gõ `TGIRRLOAD` để nạp đầy đủ (cả Lisp lẫn `NETLOAD` DLL) — bảng công cụ **TGIRR CAD** sẽ tự mở. Nếu muốn mở/đóng lại, gõ `TGIRRPALETTE`.
6. Thêm menu: gõ `MENULOAD`, duyệt chọn `TGIRR_CAD.mnu`, chọn **TGIRR CAD** rồi bấm *Load*. Menu kéo xuống **TGIRR CAD** sẽ xuất hiện trên thanh menu.
7. **Thanh công cụ icon**: gõ `TGIRRBAR` — lệnh tự thêm thư mục chứa icon vào Support File Search Path, nạp menu (nếu chưa) và bật thanh **TGIRR CAD**. Chuột phải lên thanh để dock hoặc đổi icon nhỏ/lớn; vị trí được CAD nhớ trong workspace.

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