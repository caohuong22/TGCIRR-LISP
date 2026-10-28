# Cai dat

Yeu cau AutoCAD 2021-2025+ 64-bit (.NET Framework 4.8 cho CAD 2021-2024 hoac .NET 8.0 cho CAD 2025+).

Build bang `scripts/package.ps1`. Sau do copy ca thu muc `.bundle` vao `C:\ProgramData\Autodesk\ApplicationPlugins`. Neu AutoCAD chan plugin, them thu muc bundle vao `TRUSTEDPATHS` va dat `SECURELOAD=1`. Co the test Lisp doc lap bang APPLOAD file `src/lisp/TGIRRLoader.lsp`.

Go cai dat bang cach xoa thu muc bundle va khoi dong lai AutoCAD.

## Bat/tat nap tung LISP (tranh xung dot)

Bundle chi nap `TGIRRLoader.lsp` khi khoi dong; loader doc
`%APPDATA%\TGIRR\load-settings.txt` (`v1 disabled=ID,ID`) va bo qua cac lenh da tat.
Bat/tat bang lenh `TGIRRSETTINGS` (hoac nut banh rang tren palette) - hop thoai liet ke **tung lenh**
theo file (SBS/SBSE/SCH, HBD/JH/SP2PL, DOITEXT/DOIMTEXT, TGIRRBAR) va ca cac lenh .NET
(TL, TGN, TNET, TGL, TGLADD, CPLUS, VDNG, CVPL). Moi lan tick la luu ngay.
Tat mot lenh: file van nap nhung lenh do bi vo hieu hoa; tat het lenh cua mot file thi file
khong duoc nap. Lenh .NET duoc dang ky duoi ten noi bo `TGIRR<CMD>`; ten quen thuoc (`TL`, ...)
do shim LISP tao lai khi con bat, nen tat `TL` la LISP `TL` cua ban chay duoc. Nut cua lenh da
tat cung tu an khoi Ribbon/palette.

Khong can khoi dong lai CAD: go `TGIRRRELOAD` (nap lai theo cai dat) va `TGIRRDROP` (go ngay cac
lenh vua tat khoi phien hien tai). `TGIRRSTATUS` in trang thai nap de chan doan.

## Giao dien chi co icon

Moi nut tren Ribbon, palette, Quick Tools va thanh cong cu native chi hien icon (khong co chu
tren nut). Hover vao nut de xem ten lenh (vd `HBD`) va cach dung ngan (`ID - cach dung`).

