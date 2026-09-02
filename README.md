# TGIRR CAD LISP

Thư viện AutoLISP + .NET tiếng Việt gồm công cụ bố trí tưới, đánh số đối tượng/vùng tưới và hỗ trợ bản vẽ, hỗ trợ **3 nền tảng CAD**:

| Nền tảng | Ribbon | Thư mục nguồn | Đóng gói | Tài liệu |
|---|---|---|---|---|
| AutoCAD 2021–2025+ (64-bit) | Có (tự tạo) | `src/ribbon/` | `scripts/package.ps1` | [INSTALL.md](docs/INSTALL.md) |
| ZWCAD 2026 | Lệnh (CUIX thủ công) | `src/zwcad/` | `scripts/package-zwcad.ps1` | [INSTALL-ZWCAD.md](docs/INSTALL-ZWCAD.md) |
| GstarCAD 2027 | Lệnh (menu thủ công) | `src/gscad/` | `scripts/package-gscad.ps1` | [INSTALL-GSTARCAD.md](docs/INSTALL-GSTARCAD.md) |

## Cài đặt (AutoCAD)

1. Chạy `powershell -ExecutionPolicy Bypass -File scripts/package.ps1`.
2. Đóng AutoCAD hoàn toàn.
3. Copy `bundle/TGIRR_CAD_LISP.bundle` vào `C:\ProgramData\Autodesk\ApplicationPlugins\` và ghi đè bản cũ.
4. Mở lại AutoCAD, chọn tab **TGIRR CAD LISP**.

Ribbon được xếp theo ba hàng. Khi rê chuột lên nút, AutoCAD hiển thị tên lệnh, mô tả chức năng và hướng dẫn bằng tiếng Việt.

Xem [docs/INSTALL.md](docs/INSTALL.md) và [docs/COMMANDS.md](docs/COMMANDS.md).
