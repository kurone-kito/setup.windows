@echo off

cd %~dp0.test
powershell -NoProfile -ExecutionPolicy Bypass .\index.ps1
