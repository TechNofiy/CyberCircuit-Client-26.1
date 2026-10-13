@echo off
setlocal EnableExtensions
set "ROOT=%~dp0.."
set "OUT=%LOCALAPPDATA%\CyberCircuit"
if not exist "%OUT%" mkdir "%OUT%"
set "CSC=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if not exist "%CSC%" set "CSC=%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe"
if not exist "%CSC%" (
  echo ERROR: Microsoft .NET Framework C# compiler was not found.
  exit /b 2
)
set "TMP=%TEMP%\CyberCircuitLauncher-%RANDOM%-%RANDOM%"
mkdir "%TMP%" >nul 2>nul
>"%TMP%\compile.rsp" echo /nologo
>>"%TMP%\compile.rsp" echo /target:winexe
>>"%TMP%\compile.rsp" echo /optimize+
>>"%TMP%\compile.rsp" echo /out:"%TMP%\CyberCircuitLauncher.exe"
if exist "%ROOT%\launcher\CyberCircuitIcon.ico" >>"%TMP%\compile.rsp" echo /win32icon:"%ROOT%\launcher\CyberCircuitIcon.ico"
>>"%TMP%\compile.rsp" echo /reference:System.dll
>>"%TMP%\compile.rsp" echo /reference:System.Drawing.dll
>>"%TMP%\compile.rsp" echo /reference:System.Windows.Forms.dll
>>"%TMP%\compile.rsp" echo /reference:System.Core.dll
>>"%TMP%\compile.rsp" echo "%ROOT%\launcher\CyberCircuitLauncher.cs"
"%CSC%" @"%TMP%\compile.rsp"
if errorlevel 1 goto :fail
copy /y "%TMP%\CyberCircuitLauncher.exe" "%OUT%\CyberCircuitLauncher.exe" >nul
if errorlevel 1 goto :fail
copy /y "%OUT%\CyberCircuitLauncher.exe" "%ROOT%\CyberCircuitLauncher.exe" >nul 2>nul
rmdir /s /q "%TMP%" >nul 2>nul
exit /b 0
:fail
set "ERR=%ERRORLEVEL%"
echo ERROR: launcher build failed with code %ERR%.
rmdir /s /q "%TMP%" >nul 2>nul
exit /b %ERR%
