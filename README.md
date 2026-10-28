# TGIRR CAD LISP

Thư viện AutoLISP + .NET tiếng Việt gồm công cụ bố trí tưới, đánh số đối tượng/vùng tưới và hỗ trợ bản vẽ, hỗ trợ **3 nền tảng CAD**:

| Nền tảng | Giao diện | Thư mục nguồn | Đóng gói | Tài liệu |
|---|---|---|---|---|
| AutoCAD 2021–2027+ (64-bit) | Ribbon tự động (net48 / net8.0 / net10.0) | `src/ribbon/` | `package.ps1 -Target AutoCAD` | [INSTALL.md](docs/INSTALL.md) |
| ZWCAD 2026 | **Không dùng Ribbon** (PaletteSet `TGIRRPALETTE` + Menu) | `src/zwcad/` | `package.ps1 -Target ZWCAD` | [INSTALL-ZWCAD.md](docs/INSTALL-ZWCAD.md) |
| GstarCAD 2027 | **Không dùng Ribbon** (PaletteSet `TGIRRPALETTE` + Menu) | `src/gscad/` | `package.ps1 -Target GstarCAD` | [INSTALL-GSTARCAD.md](docs/INSTALL-GSTARCAD.md) |

## Giao diện

- Mọi nút trên **Ribbon, palette `TGIRRPALETTE`, Quick Tools và thanh công cụ native `TGIRRBAR`**
  chỉ hiện **icon** (không có chữ). Hover vào nút để xem **tên lệnh** + **cách dùng ngắn**.
- Icon vẽ từ một nguồn duy nhất [`src/shared/ToolIcons.cs`](src/shared/ToolIcons.cs);
  `scripts/gen-icons.ps1` rasterize chính bộ này ra BMP 16/32 cho toolbar native.
- Palette có ô tìm lệnh (Ctrl+F), ★ để ghim vào **Quick Tools** (`TGIRRQUICK`).

## Bật/tắt nạp từng lệnh (tránh xung đột LISP khác)

- Gõ **`TGIRRSETTINGS`** (hoặc nút ⚙ trên palette): bỏ dấu lệnh không muốn nạp —
  **lưu ngay mỗi lần tick**, đóng bằng X/Esc cũng không mất.
- Danh sách gồm 9 lệnh AutoLISP (SBS/SBSE/SCH, HBD/JH/SP2PL, DOITEXT/DOIMTEXT, TGIRRBAR)
  và 8 lệnh .NET (CVPL, VDNG, TNET, TGL, TGLADD, TL, TGN, CPLUS).
- Lệnh .NET đăng ký **tên nội bộ `TGIRR<CMD>`**; `TGIRRCOMMANDS.lsp` (sinh tự động) tạo lại tên
  quen thuộc `TL`, `TGL`… nên tắt `TL` là LISP `TL` của anh chạy được.
- Không cần khởi động lại CAD: **`TGIRRLOAD`/`TGIRRRELOAD`** (nạp lại theo cài đặt),
  **`TGIRRDROP`** (gỡ lệnh vừa tắt khỏi phiên hiện tại), **`TGIRRSTATUS`** (chẩn đoán).
- Cấu hình lưu ở `%APPDATA%\TGIRR\load-settings.txt` (`v1 disabled=ID,ID`).

## Đóng gói (Build & Package)

- **Đóng gói tất cả 3 CAD:** double-click `build.bat` ở thư mục gốc, hoặc chạy:
  ```powershell
  powershell -ExecutionPolicy Bypass -File scripts/package.ps1
  ```
- **Đóng gói từng CAD:**
  ```powershell
  powershell -ExecutionPolicy Bypass -File scripts/package.ps1 -Target ZWCAD      # ZWCAD (Không dùng Ribbon)
  powershell -ExecutionPolicy Bypass -File scripts/package.ps1 -Target GstarCAD  # GstarCAD (Không dùng Ribbon)
  powershell -ExecutionPolicy Bypass -File scripts/package.ps1 -Target AutoCAD   # AutoCAD (Dùng Ribbon)
  ```

## Cài đặt nhanh

- Double-click `scripts\CAI_DAT_TGIRR.bat` (cài đặt / gỡ cài đặt), hoặc `build.bat` ở thư mục gốc
  (menu: kiểm tra môi trường, build + đóng gói, build + cài từng CAD).
- Kiểm tra trước khi build: `powershell -File scripts\doctor.ps1` — báo .NET SDK, DLL tham chiếu
  `Reference\`, bundle đã đóng gói, bản đã cài, `load-settings.txt` và CAD đang chạy.
- Cài bằng dòng lệnh:
  ```powershell
  powershell -File scripts\install-bundle.ps1 -Platform AutoCAD        # -Scope User (mặc định) hoặc Machine
  powershell -File scripts\install-bundle.ps1 -Platform ZWCAD -SkipBuild
  powershell -File scripts\install-bundle.ps1 -Uninstall                # gỡ cài đặt
  ```
  Chỉ cài ở **một** nơi: bundle trùng ở cả `%APPDATA%` và `%ProgramData%` có thể bị AutoCAD nạp 2 lần.
- Hoặc xem chi tiết từng nền tảng:
  - [Hướng dẫn cài đặt AutoCAD (Ribbon)](docs/INSTALL.md)
  - [Hướng dẫn cài đặt ZWCAD (Palette + Menu)](docs/INSTALL-ZWCAD.md)
  - [Hướng dẫn cài đặt GstarCAD (Palette + Menu)](docs/INSTALL-GSTARCAD.md)
  - [Danh mục lệnh TGIRR CAD](docs/COMMANDS.md)

## Kiểm thử và danh mục giao diện

- **Danh mục lệnh là nguồn duy nhất**: [`src/catalog/tools.json`](src/catalog/tools.json) khai báo tên nút,
  tooltip, nhóm palette, mục menu, dòng tài liệu và nút/thứ tự Ribbon cho cả 3 nền tảng.
  Sinh lại các file giao diện: `powershell -File scripts/gen-catalog.ps1`
  (kiểm tra lệch: thêm `-Check`).
- **Bản port ZWCAD/GstarCAD tự sinh** từ `src/ribbon` + `src/shared`: `scripts/port-zwcad.ps1`,
  `scripts/port-gscad.ps1`; kiểm tra không lệch nguồn: `scripts/port-verify.ps1`.
- **Danh sách file LISP đóng gói** suy ra từ `tools.json` (`loadUnits`) qua
  `scripts/package-config.ps1` — không khai báo lại trong script package.
- **Test hồi quy** (chạy **mọi** project trong `tests/`, tự động liệt kê):
  ```powershell
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test-palette.ps1
  ```
  Script kiểm tra: catalog drift, port drift, build solution (nếu có `Reference/`), rồi chạy
  7 project regression. Các script chuyên biệt vẫn dùng được: `test-vdng.ps1`, `test-cplus.ps1`,
  `test-native.ps1` (kèm build + so hash DLL trong bundle).
- **CI** ([.github/workflows/ci.yml](.github/workflows/ci.yml)) chạy trên Windows:
  `gen-catalog -Check` + `port-verify` + toàn bộ regression test.
- **Đồng bộ bản đã cài vào AutoCAD** (không build lại): `scripts/sync-bundle.ps1`.

