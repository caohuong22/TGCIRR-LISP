@echo off
setlocal
cd /d "%~dp0"
echo =============================================================
echo   TGIRR CAD - BUILD (dong goi cho AutoCAD, ZWCAD, GstarCAD)
echo =============================================================
echo.
echo   [1] Kiem tra moi truong (doctor)
echo   [2] Build + dong goi ca 3 CAD
echo   [3] Build + cai cho AutoCAD
echo   [4] Build + cai cho ZWCAD
echo   [5] Build + cai cho GstarCAD
echo   [Q] Thoat
echo.
set /p CHOICE="Chon (1-5 hoac Q): "
if /i "%CHOICE%"=="Q" exit /b 0
if "%CHOICE%"=="1" goto doctor
if "%CHOICE%"=="2" goto all
if "%CHOICE%"=="3" goto acad
if "%CHOICE%"=="4" goto zwcad
if "%CHOICE%"=="5" goto gscad
echo Lua chon khong hop le.
pause
exit /b 1

:doctor
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\doctor.ps1"
goto done

:all
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\package.ps1" -Target All
goto done

:acad
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\install-bundle.ps1" -Platform AutoCAD
goto done

:zwcad
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\install-bundle.ps1" -Platform ZWCAD
goto done

:gscad
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\install-bundle.ps1" -Platform GstarCAD
goto done

:done
set "EXIT_CODE=%ERRORLEVEL%"
echo.
if not "%EXIT_CODE%"=="0" (
    echo [LOI] That bai. Ma loi: %EXIT_CODE%
) else (
    echo [XONG] Kiem tra trang thai: scripts\doctor.ps1
)
echo.
pause
exit /b %EXIT_CODE%