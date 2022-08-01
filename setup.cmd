@echo off

powershell -Command "Get-ChildItem -Recurse %~dp0libs\*.ps1 | Unblock-File"

powershell -NoProfile -ExecutionPolicy Bypass %~dp0libs\pre-setup.ps1
