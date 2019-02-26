@echo off

rem It execute recursive using UAC when without administrator privileges.
whoami /groups | Find "High Mandatory Level" > NUL
if not errorlevel 1 goto RUN
echo You must elevate to administrator mode, because continue setup.
powershell -Command Start-Process -Verb runas "%~0"
exit /b %ERRORLEVEL%

rem run scripts
:RUN

rem move to script directory
cd setup.files
powershell -NoProfile -ExecutionPolicy RemoteSigned .\index.ps1 %1

rem move to batch place
cd %~dp0
