@echo off

rem It execute recursive using UAC when without administrator privileges.
whoami /groups | Find "High Mandatory Level" > NUL
if not errorlevel 1 goto RUN
echo You must elevate to administrator mode, because continue setup.
powershell -Command Start-Process -Verb runas "%~0"
exit /b %ERRORLEVEL%
:RUN

powershell -NoProfile -ExecutionPolicy Unrestricted setup.files\index.ps1 %1
