@echo off

echo Welcome to the setup.windows!
echo Preparing...

powershell -Command "Unblock-File %~dp0pre\index.ps1"
powershell -NoProfile -ExecutionPolicy Bypass %~dp0pre\index.ps1
