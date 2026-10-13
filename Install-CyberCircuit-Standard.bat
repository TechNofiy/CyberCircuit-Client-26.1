@echo off
setlocal
cd /d "%~dp0"
echo CyberCircuit Client 26.2 v25 - Standard PowerShell launcher
echo.
rem Use a process-only bypass so local script execution policy cannot prevent the GUI from opening.
rem This does NOT permanently change Windows execution policy.
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0CyberCircuitInstaller.ps1"
set "ERR=%ERRORLEVEL%"
if not "%ERR%"=="0" (
  echo.
  echo PowerShell did not run the installer. Error code: %ERR%
  pause
)
exit /b %ERR%
