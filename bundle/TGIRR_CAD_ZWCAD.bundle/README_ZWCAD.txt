# TGIRR CAD cho ZWCAD

## Cai dat
1. Build: chay scripts/package-zwcad.ps1
2. Copy thu muc Contents vao thu muc luu lisp (vi du C:\Users\<user>\AppData\Roaming\ZWSOFT\ZWCAD\2026\en-US\Support hoac mot thu muc tim duoc trong Support File Search Path).
3. Mo ZWCAD, go APPLOAD va chon TGIRRLoaderZ.lsp, hoac go (load "TGIRRLoaderZ.lsp").
4. Go TGIRRLOAD de nap day du (SBS, TL, TGL, TGN + CPLUS, VDNG, TNET).

## Lenh
- SBS  : chon doi tuong giong mau trong bien kin (LISP)
- TL   : tong chieu dai (LISP)
- TGL  : tao bo layer chuan (LISP)
- TGN  : danh so doi tuong/vung tuoi (LISP + DCL)
- CPLUS: copy theo quy luat (.NET)
- VDNG : rai day nho giot (.NET)
- TNET : tao net ve co chu (.NET)

Luu y: ZWCAD khong co ribbon lap trinh tuong AutoCAD; cac lenh duoc go bang ten hoac gan phim tat/menu qua CUI.