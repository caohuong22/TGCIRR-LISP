# Cai dat

Yeu cau AutoCAD 2021-2027+ 64-bit (net48 cho 2021-2024, net8.0 cho 2025-2026, net10.0 cho 2027+).

## Cai nhanh (khuyen dung)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\doctor.ps1          # kiem tra moi truong truoc
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\install-bundle.ps1  # menu chon CAD, build + cai
```

`install-bundle.ps1` tu build roi copy bundle vao dung noi, kiem tra manifest va bao viec can lam.
Tham so huu ich:

| Tham so | Y nghia |
|---|---|
| `-Platform AutoCAD\|ZWCAD\|GstarCAD\|All` | Bo qua menu chon |
| `-Scope User` (mac dinh) / `Machine` | Cai cho rieng ban (`%APPDATA%`, khong can admin) hay moi nguoi (`%ProgramData%`, can admin) |
| `-SkipBuild` | Chi cai lai tu bundle da dong goi |
| `-Uninstall` | Go cai dat |
| `-SupportDir "..."` | Chi dinh thu muc Support cho ZWCAD/GstarCAD |

**Chi cai o MOT noi.** Cung bundle o ca `%APPDATA%` va `%ProgramData%` co the bi AutoCAD nap
2 lan (trung lenh, 2 tab Ribbon). Script tu xoa ban trung; `doctor.ps1` canh bao neu phat hien.

## Build thu cong

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\package.ps1 -Target All
```

`package.ps1` kiem tra truoc khi build (dotnet SDK, DLL tham chieu, CAD dang chay) va bao loi
ro rang thay vi de MSBuild that bai kho hieu.

DLL tham chieu CAD nam trong `Reference\` va **bi gitignore** (~155MB). Sau khi clone:

- Copy DLL cua tung ban CAD vao `Reference\Cad2023\net48`, `Reference\Cad2026\net8.0`,
  `Reference\Cad2027` (AutoCAD), `Reference\Zwcad\net47`, `Reference\gstarCad` (ZWCAD/GstarCAD), hoac
- Tro toi ban CAD da cai: `scripts\package.ps1 -Target AutoCAD -AutoCADDir 'C:\Program Files\Autodesk\AutoCAD 2025\'`
  (chi build duoc TFM tuong ung voi ban CAD do).

Khong co DLL CAD thi van build/chay duoc test: `scripts\test-palette.ps1`.

Neu AutoCAD chan plugin, them thu muc bundle vao `TRUSTEDPATHS` va dat `SECURELOAD=1`.
Co the test Lisp doc lap bang APPLOAD file `src/lisp/TGIRRLoader.lsp`.

## Go cai dat

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\install-bundle.ps1 -Uninstall
```

## Bat/tat nap tung lenh (tranh xung dot LISP khac)

Manifest nap truc tiep `SBS.lsp`, `HBD.lsp`, `DOITEXT.lsp`, `TGIRRBAR.lsp`, `TGIRRCOMMANDS.lsp`
khi khoi dong (`TGIRRLoader.lsp` chay sau de ap dung cai dat). Loader doc
`%APPDATA%\TGIRR\load-settings.txt` (`v1 disabled=ID,ID`) va bo qua cac lenh da tat.

Bat/tat bang lenh `TGIRRSETTINGS` (hoac nut banh rang tren palette) - hop thoai liet ke **tung lenh**
theo file (SBS/SBSE/SCH, HBD/JH/SP2PL, DOITEXT/DOIMTEXT, KHO/TENBV, TGIRRBAR) va ca cac lenh .NET
(TL, TGN, TNET, TGL, TGLADD, CPLUS, VDNG, CVPL). Moi lan tick la luu ngay.
Tat mot lenh: file van nap nhung lenh do bi vo hieu hoa; tat het lenh cua mot file thi file
khong duoc nap. Lenh .NET duoc dang ky duoi ten noi bo `TGIRR<CMD>`; ten quen thuoc (`TL`, ...)
do shim LISP tao lai khi con bat, nen tat `TL` la LISP `TL` cua ban chay duoc. Nut cua lenh da
tat cung tu an khoi Ribbon/palette.

Khong can khoi dong lai CAD: go `TGIRRRELOAD` (nap lai theo cai dat) va `TGIRRDROP` (go ngay cac
lenh vua tat khoi phien hien tai). `TGIRRSTATUS` in trang thai nap de chan doan.
`scripts\doctor.ps1` kiem tra ca trang thai cai dat tren may.

## Giao dien chi co icon

Moi nut tren Ribbon, palette, Quick Tools va thanh cong cu native chi hien icon (khong co chu
tren nut). Hover vao nut de xem ten lenh (vd `HBD`) va cach dung ngan (`ID - cach dung`).
