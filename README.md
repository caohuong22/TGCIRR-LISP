# TGIRR CAD LISP

Thư viện AutoLISP + .NET tiếng Việt gồm công cụ bố trí tưới, đánh số đối tượng/vùng tưới và hỗ trợ bản vẽ, hỗ trợ **3 nền tảng CAD**:

| Nền tảng | Giao diện | Thư mục nguồn | Đóng gói | Tài liệu |
|---|---|---|---|---|
| AutoCAD 2021–2025+ (64-bit) | Ribbon tự động | `src/ribbon/` | `package.ps1 -Target AutoCAD` | [INSTALL.md](docs/INSTALL.md) |
| ZWCAD 2026 | **Không dùng Ribbon** (PaletteSet `TGIRRPALETTE` + Menu) | `src/zwcad/` | `package.ps1 -Target ZWCAD` | [INSTALL-ZWCAD.md](docs/INSTALL-ZWCAD.md) |
| GstarCAD 2027 | **Không dùng Ribbon** (PaletteSet `TGIRRPALETTE` + Menu) | `src/gscad/` | `package.ps1 -Target GstarCAD` | [INSTALL-GSTARCAD.md](docs/INSTALL-GSTARCAD.md) |

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

- Double-click file `scripts/CAI_DAT_TGIRR.bat` để mở menu cài đặt tự động cho AutoCAD, ZWCAD hoặc GstarCAD.
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
- **Test hồi quy**:
  ```powershell
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test-palette.ps1  # catalog + port + state stores
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test-vdng.ps1     # build, package, soi hash DLL, VDNG
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test-cplus.ps1    # CPLUS
  ```
- **Đồng bộ bản đã cài vào AutoCAD** (không build lại): `scripts/sync-bundle.ps1`.

