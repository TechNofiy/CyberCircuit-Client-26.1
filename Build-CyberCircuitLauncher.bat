@echo off
setlocal
call "%~dp0launcher\Build-CyberCircuitLauncher.bat"
if errorlevel 1 (
  echo.
  echo CyberCircuit Launcher build failed.
  pause
  exit /b %errorlevel%
)
echo.
echo CyberCircuitLauncher.exe is ready in %%LOCALAPPDATA%%\CyberCircuit
pause
