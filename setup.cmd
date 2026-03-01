@echo off
setlocal

echo ============================================================
echo  setup.windows ? automated environment setup
echo ============================================================
echo.

REM --- Unblock all PowerShell scripts ---
powershell -Command "Get-ChildItem -Recurse '%~dp0libs\*.ps1' | Unblock-File"
powershell -Command "Get-ChildItem -Recurse '%~dp0libs\*.psm1' | Unblock-File"

REM --- Ensure Chocolatey is available (needed for Boxstarter) ---
where choco >nul 2>&1
if errorlevel 1 (
  echo Installing Chocolatey...
  powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))"
)

REM --- Ensure Boxstarter is available ---
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "if (-not (Get-Module -ListAvailable -Name Boxstarter.Chocolatey)) { choco install boxstarter -y }"

REM --- Run the main setup via Boxstarter (provides reboot resilience) ---
echo.
echo Starting Boxstarter setup (reboot-resilient)...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "Import-Module Boxstarter.Chocolatey; Install-BoxstarterPackage -PackageName '%~dp0boxstarter.ps1' -DisableReboots:$false"

echo.
echo ============================================================
echo  Setup complete. Please reboot if prompted.
echo ============================================================
pause
