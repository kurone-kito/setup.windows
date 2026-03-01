<#
.SYNOPSIS
Boxstarter orchestrator — thin wrapper that drives winget configuration (DSC),
Chocolatey (fonts only), and post-install scripts.

This file is executed by Boxstarter via Install-BoxstarterPackage, which
provides reboot resilience. After each reboot Boxstarter re-runs this script
from the top; every phase is therefore written to be idempotent.
#>
Set-StrictMode -Version Latest

###########################################################################
### Phase 0 — OS support check
###########################################################################
$scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
. (Join-Path $scriptRoot 'libs\os-guard.ps1')
$osResult = Test-OsSupport
if (-not $osResult.Supported) {
  Write-Error 'Unsupported OS. Aborting setup.'
  return
}

###########################################################################
### Phase 1 — Environment detection
###########################################################################
Get-CimInstance Win32_ComputerSystem `
  | Select-Object -ExpandProperty SystemType `
  | Set-Variable -Name ARCH -Option Constant -Scope local
$ARCH -like 'ARM64*' `
  | Set-Variable -Name IS_ARM64 -Option Constant -Scope local

###########################################################################
### Phase 2 — WinGet Configuration (DSC)
###########################################################################
$dscFile = Join-Path $scriptRoot 'configurations\packages.dsc.yaml'
if (Test-Path $dscFile) {
  Write-Host '[Phase 2] Applying WinGet Configuration (DSC)...' -ForegroundColor Cyan
  winget configure --accept-configuration-agreements --disable-interactivity $dscFile
  Write-Host '[Phase 2] WinGet Configuration complete.' -ForegroundColor Green
}
else {
  Write-Warning "[Phase 2] DSC file not found: $dscFile — skipping."
}

###########################################################################
### Phase 3 — Chocolatey packages (only what winget cannot provide)
###########################################################################
Write-Host '[Phase 3] Installing Chocolatey packages...' -ForegroundColor Cyan

# Fonts — no winget equivalent
choco install font-hackgen -y
choco install font-hackgen-nerd -y
choco install lato -y

# VB-CABLE — virtual audio device (no winget package)
choco install vb-cable -y

# posh-git — install via PowerShellGet for a more modern approach
if (-not (Get-Module -ListAvailable -Name posh-git)) {
  Install-Module posh-git -Scope CurrentUser -Force -AllowClobber
}

Write-Host '[Phase 3] Chocolatey packages complete.' -ForegroundColor Green

###########################################################################
### Phase 4 — Architecture-conditional packages (non-ARM64)
###########################################################################
if (-not $IS_ARM64) {
  Write-Host '[Phase 4] Installing architecture-conditional packages...' -ForegroundColor Cyan
  winget install -eh --accept-package-agreements --accept-source-agreements --disable-interactivity --id nektos.act
  winget install -eh --accept-package-agreements --accept-source-agreements --disable-interactivity --id Docker.DockerDesktop
  winget install -eh --accept-package-agreements --accept-source-agreements --disable-interactivity --id Oracle.VirtualBox
  Write-Host '[Phase 4] Architecture-conditional packages complete.' -ForegroundColor Green
}
else {
  Write-Host '[Phase 4] ARM64 detected — skipping act, Docker Desktop, VirtualBox.' -ForegroundColor Yellow
}

###########################################################################
### Phase 5 — Post-install setup (fnm, cargo, Unity, mkcert, Docker)
###########################################################################
$postInstall = Join-Path $scriptRoot 'libs\post-install.ps1'
if (Test-Path $postInstall) {
  Write-Host '[Phase 5] Running post-install setup...' -ForegroundColor Cyan
  & $postInstall
  Write-Host '[Phase 5] Post-install setup complete.' -ForegroundColor Green
}

###########################################################################
### Phase 6 — Teardown
###########################################################################
Write-Host '[Phase 6] Finalizing...' -ForegroundColor Cyan
Enable-MicrosoftUpdate
Enable-UAC
Install-WindowsUpdate
Write-Host '[Phase 6] Setup complete!' -ForegroundColor Green
