@echo off
setlocal EnableExtensions
cd /d "%~dp0"
set "JDK=%~dp0runtime\jdk-25"
set "GRADLE=%~dp0runtime\gradle-9.5.1\bin\gradle.bat"
if not exist "%GRADLE%" set "GRADLE=%LOCALAPPDATA%\CyberCircuit\GradleRuntime\9.5.1\bin\gradle.bat"
if not exist "%JDK%\bin\java.exe" (
  echo CyberCircuit bundled JDK 25 is missing.
  echo Run Install-CyberCircuit.bat and click GET JDK 25 first.
  pause
  exit /b 1
)
if not exist "%JDK%\bin\javac.exe" (
  echo CyberCircuit bundled JDK 25 is incomplete: javac.exe is missing.
  echo Run Install-CyberCircuit.bat and repair/download JDK 25.
  pause
  exit /b 1
)
if not exist "%GRADLE%" (
  echo CyberCircuit Gradle runtime is missing.
  echo Run Install-CyberCircuit.bat and click BUILD + INSTALL once to bootstrap it.
  pause
  exit /b 1
)
set "JAVA_HOME=%JDK%"
set "PATH=%JAVA_HOME%\bin;%PATH%"
echo.
echo === CyberCircuit Client 26.2 build ===
echo Java: %JAVA_HOME%
echo Gradle: %GRADLE%
echo.
set "GRADLE_USER_HOME=%LOCALAPPDATA%\CyberCircuit\ManualGradle-%RANDOM%-%RANDOM%"
if not exist "%GRADLE_USER_HOME%" mkdir "%GRADLE_USER_HOME%" >nul 2>&1
call "%GRADLE%" --no-daemon --no-parallel --no-watch-fs -Dorg.gradle.internal.instrumentation.agent=false -Dorg.gradle.vfs.watch=false build %*
set "ERR=%ERRORLEVEL%"
echo.
if "%ERR%"=="0" (echo BUILD SUCCESSFUL) else (echo BUILD FAILED ^(code %ERR%^) )
pause
exit /b %ERR%
