@echo off
setlocal
cd /d "%~dp0"
echo =============================================================
echo   TGIRR CAD - DONG GOI CHO AUTOCAD, ZWCAD VA GSTARCAD
echo   (ZWCAD va GstarCAD KHONG dung Ribbon - dung Palette + Menu)
echo =============================================================
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\package.ps1" -Target All
set "EXIT_CODE=%ERRORLEVEL%"
echo.
if not "%EXIT_CODE%"=="0" (
    echo [LOI] Dong goi that bai. Ma loi: %EXIT_CODE%
) else (
    echo [THANH CONG] Toan bo bundle da san sang trong thu muc bundle\
)
echo.
pause
exit /b %EXIT_CODE%
