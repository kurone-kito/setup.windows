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
### Phase 2 — WinGet Configuration (DSC or import, degraded mode)
###########################################################################
# Single point of profile selection (issue #67): switching this one value
# switches the DSC file, its import.json fallback, and its unapplied-
# resources list together, so they can't drift out of sync with each
# other the way three independently-edited references could. See
# README.md's "Minimal Install" section to switch to 'min'.
$ConfigProfile = 'full'
if ($ConfigProfile -notin @('full', 'min')) {
  # This selection controls what gets installed; failing loudly on a
  # typo (e.g. 'Min', 'mini') is safer than silently falling back to
  # full, which the previous `if ($ConfigProfile -eq 'min') {...} else
  # {...}` form would have done.
  Write-Error "Unknown ConfigProfile '$ConfigProfile' -- expected 'full' or 'min'. Aborting setup."
  return
}
$profileSuffix = if ($ConfigProfile -eq 'min') { '.min' } else { '' }
$dscFile = Join-Path $scriptRoot "configurations\packages$profileSuffix.dsc.yaml"
$importJsonFile = Join-Path $scriptRoot "configurations\packages$profileSuffix.import.json"
$unappliedResourcesFile = Join-Path $scriptRoot "configurations\packages$profileSuffix.unapplied.json"

. (Join-Path $scriptRoot 'libs\strategy.ps1')
$strategy = Test-ConfigurationStrategy
Write-Host "[Phase 2] Configuration route: $($strategy.Route) -- $($strategy.Reason)" -ForegroundColor Cyan
if ($strategy.Route -eq 'unsupported') {
  Write-Error "Unsupported winget capability: $($strategy.Reason) Aborting setup."
  return
}

if ($strategy.Route -eq 'dsc') {
  if (-not (Test-Path $dscFile)) {
    Write-Error "[Phase 2] DSC file not found: $dscFile. Aborting setup."
    return
  }
  Write-Host '[Phase 2] Applying WinGet Configuration (DSC)...' -ForegroundColor Cyan
  winget configure --accept-configuration-agreements --disable-interactivity $dscFile
  $exitCode = $LASTEXITCODE
  if ($exitCode -ne 0) {
    # Never re-route on a runtime failure (see libs/strategy.ps1's own
    # rationale): re-running under winget import risks a *partial
    # apply* on top of whatever this attempt already changed, and the
    # two routes cover different resource scopes -- a Registry/
    # OsVersion failure here would not even be attempted under import,
    # so switching wouldn't retry the same failure, it would silently
    # drop it. Abort instead, matching Phase 0's precedent for a
    # setup-blocking condition (Write-Error + return, not throw --
    # consistent within this script, and correct under Boxstarter's
    # $ErrorActionPreference = 'Continue').
    Write-Error "[Phase 2] winget configure failed (exit code $exitCode). Command: winget configure --accept-configuration-agreements --disable-interactivity `"$dscFile`". Aborting setup."
    return
  }
  Write-Host '[Phase 2] WinGet Configuration complete.' -ForegroundColor Green
}
elseif ($strategy.Route -eq 'import') {
  # import route (degraded mode): only PackageIdentifiers can be
  # expressed in import.json, so PSDscResources/Registry resources and
  # the OsVersion assertion from $dscFile are not applied here -- see
  # the unapplied-resources warning below.
  if (-not (Test-Path $importJsonFile)) {
    Write-Error "[Phase 2] import.json file not found: $importJsonFile. Aborting setup."
    return
  }
  Write-Host '[Phase 2] Applying WinGet import (degraded mode)...' -ForegroundColor Cyan
  # --ignore-unavailable: chosen so one package that's unavailable on
  # this machine/region (e.g. an msstore entry not offered here) does
  # not abort the whole import. This deliberately narrows what counts
  # as a Phase 2 failure on this route to *installation* failures, not
  # *availability* failures -- an asymmetry with the dsc route's exit-
  # code check, accepted because availability gaps are still visible
  # in winget's own per-package output in this log, satisfying "trace
  # which package was skipped" without extra bookkeeping here.
  winget import --accept-package-agreements --accept-source-agreements --disable-interactivity --ignore-unavailable $importJsonFile
  $exitCode = $LASTEXITCODE
  if ($exitCode -ne 0) {
    Write-Error "[Phase 2] winget import failed (exit code $exitCode). Command: winget import --accept-package-agreements --accept-source-agreements --disable-interactivity --ignore-unavailable `"$importJsonFile`". Aborting setup."
    return
  }
  Write-Host '[Phase 2] WinGet import complete.' -ForegroundColor Green

  if (Test-Path $unappliedResourcesFile) {
    # @(...) guards against ConvertFrom-Json unrolling a single-element
    # JSON array to a bare object, which would make .Count read $null
    # under Set-StrictMode instead of 1.
    $unapplied = @(Get-Content -Raw -Path $unappliedResourcesFile | ConvertFrom-Json)
    if ($unapplied.Count -gt 0) {
      Write-Warning "[Phase 2] Degraded mode: $($unapplied.Count) resource(s) from $dscFile were not applied by the import route:"
      foreach ($item in $unapplied) {
        Write-Warning "  - $($item.Resource) $($item.Id): $($item.Description)"
      }
    }
    else {
      Write-Host '[Phase 2] Degraded mode: no unapplied resources for this profile.' -ForegroundColor Green
    }
  }
  else {
    Write-Warning "[Phase 2] Unapplied-resources list not found: $unappliedResourcesFile -- skipping the degraded-mode warning."
  }
}
else {
  # Defensive guard, not a reachable branch under
  # Test-ConfigurationStrategy's documented contract (Route is always
  # 'dsc' | 'import' | 'unsupported', and 'unsupported' already
  # returned above) -- but Phase 2 chooses between two real winget
  # commands based on this value, so a future change to that contract
  # should fail loudly here instead of silently running winget import.
  Write-Error "[Phase 2] Unexpected configuration route '$($strategy.Route)'. Aborting setup."
  return
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
### Phase 6 — Remote Desktop
###########################################################################
# Not declarable as a PSDscResources/Registry resource: Boxstarter's
# Enable-RemoteDesktop calls the Win32_TerminalServiceSetting /
# Win32_TSGeneralSetting WMI methods (SetAllowTsConnections,
# SetUserAuthenticationRequired), not a direct registry write. See
# docs/dsc-migration-notes.md for the full rationale.
Write-Host '[Phase 6] Enabling Remote Desktop...' -ForegroundColor Cyan
Enable-RemoteDesktop
Write-Host '[Phase 6] Remote Desktop enabled.' -ForegroundColor Green

###########################################################################
### Phase 7 — Teardown
###########################################################################
Write-Host '[Phase 7] Finalizing...' -ForegroundColor Cyan
Enable-MicrosoftUpdate
Enable-UAC
Install-WindowsUpdate
Write-Host '[Phase 7] Setup complete!' -ForegroundColor Green
