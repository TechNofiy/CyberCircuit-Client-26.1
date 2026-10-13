@echo off
setlocal
cd /d "%~dp0"
rem Process-only PowerShell policy override so this launcher can start on PCs that block local .ps1 files.
rem This does NOT change the machine or user execution-policy setting.
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0CyberCircuitInstaller.ps1"
set "ERR=%ERRORLEVEL%"
if not "%ERR%"=="0" (
  echo.
  echo CyberCircuit Installer failed to start. Error code: %ERR%
  echo The window will stay open so you can read the error.
  pause
)
exit /b %ERR%
