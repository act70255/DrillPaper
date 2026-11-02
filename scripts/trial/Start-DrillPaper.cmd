@echo off
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-DrillPaper.ps1" -CheckOnly
if errorlevel 1 goto failed
if /i "%~1"=="-CheckOnly" exit /b 0
start "" /D "%~dp0" "%~dp0DrillPaper.exe" --management
exit /b %errorlevel%
:failed
if /i not "%~1"=="-CheckOnly" pause
exit /b 1
