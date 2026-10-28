@echo off
setlocal
cd /d "%~dp0.."
echo =============================================================
echo   TGIRR CAD - CAI DAT / GO CAI DAT
echo =============================================================
echo.
echo   [1] Cai dat (chon CAD o buoc tiep theo)
echo   [2] Go cai dat
echo   [Q] Thoat
echo.
set /p CHOICE="Chon (1-2 hoac Q): "
if /i "%CHOICE%"=="Q" exit /b 0
if "%CHOICE%"=="1" goto install
if "%CHOICE%"=="2" goto uninstall
echo Lua chon khong hop le.
pause
exit /b 1

:install
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-bundle.ps1"
goto done

:uninstall
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-bundle.ps1" -Uninstall
goto done

:done
set "EXIT_CODE=%ERRORLEVEL%"
echo.
if not "%EXIT_CODE%"=="0" echo That bai. Ma loi: %EXIT_CODE%
pause
exit /b %EXIT_CODE%