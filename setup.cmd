@echo off
setlocal

echo ============================================================
echo  setup.windows - automated environment setup
echo ============================================================
echo.

REM --- Unblock all PowerShell scripts ---
powershell -Command "Get-ChildItem -Recurse '%~dp0libs\*.ps1' | Unblock-File"

REM --- Check for pending-reboot indicators before installing anything ---
REM (a stale/false-positive indicator here can otherwise make Boxstarter
REM  loop rebooting forever without ever running this repo's setup logic)
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  ". '%~dp0libs\reboot-guard.ps1'; $r = Test-PendingRebootIndicators; $flagged = $r.PSObject.Properties.Name | Where-Object { $r.$_ }; if ($flagged) { Write-Warning ('Pending-reboot indicator(s) detected: ' + ($flagged -join ', ')); Write-Warning 'This may be a real pending reboot (reboot and re-run), or a known false positive -- see README.md Troubleshooting.'; Write-Warning 'If unresolved, Boxstarter can loop rebooting forever without ever running this repo''s setup logic.'; Write-Warning 'To proceed anyway, set SETUP_IGNORE_PENDING_REBOOT=1 and re-run setup.cmd.'; if ($env:SETUP_IGNORE_PENDING_REBOOT -ne '1') { exit 1 } else { Write-Warning 'SETUP_IGNORE_PENDING_REBOOT=1 is set; continuing despite the indicator(s) above.' } }"
if errorlevel 1 (
  echo.
  echo Aborting: unresolved pending-reboot indicator detected. See README.md Troubleshooting section.
  pause
  exit /b 1
)

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
