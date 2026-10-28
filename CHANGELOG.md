# Lịch sử thay đổi

Phiên bản bundle AutoCAD đọc ở `bundle/TGIRR_CAD_LISP.bundle/PackageContents.xml`
(`AppVersion`). Mỗi mục dưới đây là một commit trên `main`.

## 1.6.0 — 28/10/2026

### Thêm mới

- **`KHO`** (nhóm IN ẤN & KHUNG TÊN): chèn khung bản vẽ **trống** `TGIRR_TB_A2.dwg`
  (chỉ nét khung + hệ ô, không logo/chữ/attribute); **tự đặt Page Setup** đúng khổ giấy,
  vùng in = Layout, tỷ lệ 1:1. Chọn khổ A1/A2/A3/A4; scale theo bề rộng giấy
  (`(paperW-20)/463.162`). Thiếu file mẫu thì tự quay về khung 180×70 mm.
- **`TENBV`**: điền/đồng bộ 12 trường cho khung đơn giản dự phòng (khung trống không có
  attribute — tự thêm text). Dữ liệu lưu trong dictionary `TGIRR_PROJECT`.
- Nhóm giao diện **IN ẤN & KHUNG TÊN** trên Ribbon (panel `KHUNG TÊN`), palette, menu
  và thanh công cụ native; icon mới `title-block`, `title-sync`.

### Sửa lỗi

- **`entmake` BLOCK/LWPOLYLINE thiếu marker lớp con** (`AcDbEntity`, `AcDbBlockBegin`,
  `AcDbPolyline`) làm AutoCAD 2025 bỏ qua block: khung không hiện hoặc các nét rơi ra
  paper space. Đã thêm đủ marker, kiểm tra block tồn tại sau khi tạo và xác minh INSERT.
- **`vl-catch-all-apply 'command`** gây lỗi `bad order function: COMMAND` khi tạo layer;
  đã thay bằng `entmod` cho layer và gọi `command` trực tiếp.
- **Khung dẫn xuất từ file mẫu còn nét logo** (logo vẽ bằng LINE/LWPOLYLINE, không phải
  OLE/hatch). Đã lọc bỏ toàn bộ logo/chữ/hatch/OLE, chỉ giữ nét khung + hệ ô (24 entity),
  không còn thông tin công trình/công ty trong asset.
- **Page Setup chọn nhầm khổ portrait** (A3 297×420 thay vì 420×297) nên Print/Preview
  không ra chỗ khung. Đã khớp media theo đúng kích thước ngang × dọc, đặt vùng in = Layout,
  tỷ lệ 1:1.
- **Đóng gói thiếu asset `.dwg`**: `package-config.ps1` và `install-bundle.ps1` đã copy
  thêm `*.dwg` để khung đi kèm cả 3 bundle.

### Ghi chú

- Block dùng layer `TG-KHUNG` và text style `TG-TITLE` (font `arial.ttf`).
- Chưa có bảng danh mục bản vẽ từ layout và in hàng loạt — dự kiến `MBAN`, `INLO`.

## 1.5.0 — 28/10/2026

Bản này gom 5 commit: giao diện icon, bật/tắt nạp lệnh, tách file giao diện,
sửa hộp thoại cài đặt và làm lại quy trình build/install.

### Thêm mới

- **Bộ icon dùng chung** `src/shared/ToolIcons.cs`: 19 hình vector, không vẽ chữ.
  `scripts/gen-icons.ps1` rasterize chính bộ này ra BMP 16/32 cho thanh công cụ native,
  nên Ribbon / palette / toolbar luôn giống nhau.
- **`TGIRRSETTINGS`** (+ nút ⚙ trên palette, panel GIAO DIỆN trên Ribbon): bật/tắt nạp
  **từng lệnh** — 9 lệnh AutoLISP (theo file) và 8 lệnh .NET. Lưu ngay mỗi lần tick vào
  `%APPDATA%\TGIRR\load-settings.txt`; đóng bằng X/Esc không mất thay đổi.
- **`TGIRRLOAD` / `TGIRRRELOAD`**: nạp lại LISP theo cài đặt, không cần khởi động lại CAD.
- **`TGIRRDROP`**: gỡ ngay các lệnh vừa tắt khỏi phiên hiện tại (AutoCAD không tự gỡ lệnh).
- **`TGIRRSTATUS`**: in thư mục LISP, số lệnh đang tắt và trạng thái `SBS`/`HBD`/`TL`.
- **`scripts/doctor.ps1`**: kiểm tra .NET SDK, DLL tham chiếu `Reference\`, bundle đã đóng gói,
  bản đã cài, `load-settings.txt`, CAD đang chạy; cảnh báo khi cài trùng 2 nơi.
- **`scripts/package-config.ps1`**: danh sách file LISP đóng gói suy ra từ
  `tools.json → loadUnits` (trước đây khai báo lặp ở 3 script).
- **CI** `.github/workflows/ci.yml`: `gen-catalog -Check` + `port-verify` + toàn bộ regression.

### Thay đổi

- **Giao diện chỉ có icon**: bỏ chữ trên nút ở Ribbon, palette, Quick Tools và thanh công cụ
  native; hover hiện tên lệnh + cách dùng ngắn.
- **Lệnh .NET đổi sang tên nội bộ** `TGIRR<CMD>` (`TGIRRTL`, `TGIRRCPLUS`, …).
  `TGIRRCOMMANDS.lsp` (sinh tự động) tạo lại tên quen thuộc `c:TL`, `c:TGL`… **chỉ khi lệnh còn bật**
  — nhờ vậy tắt `TL` là LISP `TL` của người dùng chạy được.
- **`TL`**: nếu chưa có pickset thì hỏi chọn đối tượng; kết quả in cả ra dòng lệnh lẫn hộp thoại.
- **Tách `PaletteContent.cs`** (623 dòng) thành `PaletteTheme.cs`, `ToolChip.cs`,
  `PaletteContent.cs`, `QuickToolsContent.cs` — chỉ di chuyển code, không đổi hành vi.
- **`install-bundle.ps1`**: `-Scope User|Machine` (mặc định `User`, không cần admin),
  `-Uninstall`, `-SupportDir`, tự tìm thư mục Support ZWCAD/GstarCAD (bỏ hard-code năm và
  đường dẫn `D:\LispCAD`), tự xóa bản trùng ở nơi còn lại.
- **`package.ps1`**: preflight (dotnet SDK, DLL tham chiếu theo từng TFM, CAD đang chạy) với
  thông báo lỗi kèm cách xử lý; thêm `-AllowRunningCad`.
- **`build.bat`, `scripts\CAI_DAT_TGIRR.bat`**: thành menu (kiểm tra môi trường / build /
  cài từng CAD / gỡ cài đặt).
- **`scripts/test-palette.ps1`**: chạy **mọi** project trong `tests/` (tự liệt kê) thay vì 2/7;
  build solution khi có `Reference\`.
- `tests/Palette.Regression` được thêm vào `TGIRR.slnx` (trước đây build solution bỏ sót).
- `.gitattributes`: tắt tự đổi LF/CRLF (`port-verify` so sánh byte nên đổi dòng gây drift giả).

### Sửa lỗi

- **Không lệnh nào chạy sau khi bật hết**: loader dùng `read` + `eval` động nên một lệnh lỗi làm
  dừng cả quá trình nạp. Nay mọi thao tác gỡ lệnh viết literal và mỗi bước bọc
  `vl-catch-all-apply`.
- **Loader chọn sai thư mục**: dùng `cons` nên thứ tự bị đảo, `ROAMABLEROOTPREFIX` (luôn tồn tại)
  được chọn trước bundle → không tìm thấy file `.lsp`. Nay ưu tiên
  `findfile → APPDATA → PROGRAMDATA → ROAMABLEROOTPREFIX` (append).
- **Manifest khai báo sai lệnh**: `PackageContents.xml` liệt kê lệnh AutoLISP (`SBSE`, `DOITEXT`,
  `M2T`) trong `ComponentEntry` .NET và thiếu `TGIRRTL`. Nay khối `<Commands>` được sinh từ chính
  `[CommandMethod]` trong mã nguồn.
- **AutoCAD không nạp gì khi manifest chỉ trỏ loader**: nay manifest nạp trực tiếp 5 file LISP
  (`SBS`, `HBD`, `DOITEXT`, `TGIRRBAR`, `TGIRRCOMMANDS`); loader chạy sau để áp dụng cài đặt.
- **Scan lệnh / Quick Tools rỗng**: `TGIRRQUICK` mở palette kể cả khi chưa ghim lệnh nào
  (trước đây chỉ in một dòng rồi thoát).
- **Hộp thoại cài đặt bị chìm chữ**: `CheckBox` ăn theo theme native (chữ đậm trên nền tối).
  Nay tự vẽ `ControlTemplate` cho CheckBox và Button, tô nền tường minh.
- **`Trigger` có `TargetName` đặt trong `Style.Triggers`** gây `InvalidOperationException`;
  chuyển vào `ControlTemplate.Triggers`.
- **Cài trùng 2 nơi**: bundle ở cả `%APPDATA%` và `%ProgramData%` có thể bị AutoCAD nạp 2 lần.
  `install-bundle.ps1` chỉ cài 1 nơi, `doctor.ps1` cảnh báo nếu phát hiện.
- **`sync-bundle.ps1`** im lặng khi DLL bị khóa bởi CAD đang chạy → nay bỏ qua rõ ràng kèm chỉ dẫn.

### Dọn dẹp

- Bỏ member chết trong `ToolCatalog.generated.cs` (`Badge`, `TipHeadline`) và
  `LoadSettingsStore.Disabled`.
- Chuyển 4 script một lần `inspect-zwcad*.ps1` vào `scripts/dev/`.
- README / `docs/INSTALL.md` / `docs/COMMANDS.md` cập nhật theo giao diện icon, lệnh cài đặt mới
  và các lệnh `TGIRRSETTINGS` / `TGIRRLOAD` / `TGIRRDROP` / `TGIRRSTATUS`.

### Nâng cấp từ 1.4.0

1. Chạy `scripts\install-bundle.ps1 -Platform AutoCAD` (tự build + cài, tự xóa bản trùng).
2. Mở AutoCAD. Nếu trước đó lệnh không chạy: gõ `TGIRRSTATUS` để xem trạng thái, `TGIRRLOAD` để
   nạp lại.
3. Muốn nhường tên lệnh cho LISP khác: `TGIRRSETTINGS` → bỏ tick lệnh đó → `TGIRRDROP`.

## 1.4.0

- Giao diện Palette + Quick Tools, ghim lệnh bằng ★, menu/toolbar native cho ZWCAD & GstarCAD.
- Danh mục lệnh một nguồn duy nhất: `src/catalog/tools.json` sinh menu, tooltip, Ribbon, docs.
- Port tự động `src/ribbon` + `src/shared` → `src/zwcad`, `src/gscad`.
