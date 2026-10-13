@echo off
setlocal
cd /d "%~dp0"
set "GRADLE_HOME=%~dp0runtime\gradle-9.5.1"
if not exist "%GRADLE_HOME%\bin\gradle.bat" (
  echo CyberCircuit Gradle runtime is not installed yet.
  echo Run Install-CyberCircuit.bat and use BUILD + INSTALL once to bootstrap the runtime.
  exit /b 1
)
if exist "%~dp0runtime\jdk-25\bin\java.exe" set "JAVA_HOME=%~dp0runtime\jdk-25"
if defined JAVA_HOME set "PATH=%JAVA_HOME%\bin;%PATH%"
set "GRADLE_USER_HOME=%LOCALAPPDATA%\CyberCircuit\GradleUserHome"
if not exist "%GRADLE_USER_HOME%" mkdir "%GRADLE_USER_HOME%" >nul 2>&1
call "%GRADLE_HOME%\bin\gradle.bat" --no-daemon --no-parallel -Dorg.gradle.internal.instrumentation.agent=false %*
set "ERR=%ERRORLEVEL%"
exit /b %ERR%
