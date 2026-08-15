@echo off
chcp 65001 >nul
echo === WSL VHDX Compact ===
echo.
echo 1. Finding VHDX...
set VHDX_PATH=
for /f "delims=" %%F in ('dir /s /b "%LOCALAPPDATA%\wsl\ext4.vhdx" 2^>nul') do set VHDX_PATH=%%F
if "%VHDX_PATH%"=="" (
    echo ERROR: VHDX not found at %%LOCALAPPDATA%%\wsl\
    pause
    exit /b 1
)
echo    Found: %VHDX_PATH%
for %%Z in ("%VHDX_PATH%") do echo    Size before: %%~zZ bytes

echo.
echo 2. Shutting down WSL...
wsl --shutdown
if %ERRORLEVEL% neq 0 (
    echo ERROR: wsl --shutdown failed
    pause
    exit /b 1
)
echo    OK

echo.
echo 3. Compacting VHDX via DiskPart...
echo select vdisk file="%VHDX_PATH%" > "%TEMP%\compact.txt"
echo attach vdisk readonly >> "%TEMP%\compact.txt"
echo compact vdisk >> "%TEMP%\compact.txt"
echo detach vdisk >> "%TEMP%\compact.txt"
echo exit >> "%TEMP%\compact.txt"

diskpart /s "%TEMP%\compact.txt"

echo.
echo 4. Size after:
for %%Z in ("%VHDX_PATH%") do echo    Size: %%~zZ bytes
for %%Z in ("%VHDX_PATH%") do set /a "size_gb=%%~zZ/1073741824" && echo    That is roughly: %%size_gb%% GB

echo.
echo 5. Cleanup
del "%TEMP%\compact.txt" 2>nul

echo.
echo Done! WSL will start fresh next time you use it.
echo Press any key to exit.
pause >nul
