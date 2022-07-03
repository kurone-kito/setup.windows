@echo off

echo Welcome to the setup.windows!
echo Preparing...

powershell -Command "Unblock-File %~dp0libs\pre-setup.ps1"
powershell -NoProfile -ExecutionPolicy Bypass %~dp0libs\pre-setup.ps1
