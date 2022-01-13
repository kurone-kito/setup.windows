@echo off

rem It executes recursive using UAC when without administrator privileges.
whoami /groups | Find "High Mandatory Level" > NUL
if not errorlevel 1 goto RUN
echo You should elevate to administrator privileges because of continued setup.
timeout /T 3 /NOBREAK
powershell -Command Start-Process -Verb runas "%~0"
exit /b %ERRORLEVEL%

rem run scripts
:RUN

cd %~dp0setup.files
powershell -NoProfile -ExecutionPolicy Bypass .\index.ps1
