<#
.SYNOPSIS
Installs PowerShell 7 (pwsh) at machine scope via winget, so its path
is stable enough to later serve as Windows OpenSSH Server's
DefaultShell.

This file is dot-sourced (not imported as a module) from
libs/post-install.ps1 -- do not add Export-ModuleMember here.
#>
Set-StrictMode -Version Latest

# $env:LOCALAPPDATA / $env:ProgramFiles are Windows-only and absent on
# the Linux CI runner that runs this file's Pester tests -- guarded so
# dot-sourcing this file doesn't fail there. Every real caller runs on
# Windows, where both are always set.
$Script:PwshMsixAliasPath = if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\pwsh.exe' } else { $null }
$Script:PwshMachineScopeExePath = if ($env:ProgramFiles) { Join-Path $env:ProgramFiles 'PowerShell' -AdditionalChildPath '7', 'pwsh.exe' } else { $null }

function Get-PwshInstallArguments {
  [CmdletBinding()]
  [OutputType([string[]])]
  param ()
  return [string[]]@(
    'install', '--id', 'Microsoft.PowerShell', '--source', 'winget',
    '--scope', 'machine', '--installer-type', 'wix', '--version', '7.6.*',
    '--exact', '--accept-package-agreements', '--accept-source-agreements',
    '--disable-interactivity'
  )
  <#
  .SYNOPSIS
  Builds the `winget install` argument list for machine-scope pwsh.
  Pure (no `winget` call), so this is tested directly without mocking
  Invoke-PwshInstallCommand at all -- mirrors
  libs/winget-pin-sync.ps1's Get-WinGetPinAddArguments /
  Invoke-WinGetPinAddCommand split.

  .DESCRIPTION
  --scope machine forces a machine-wide install; --installer-type wix
  forces the WiX/MSI installer over the MSIX bundle winget would
  otherwise pick by its own installer-type precedence (MSIX >
  MSI/Wix). --version 7.6.* pins to the last minor line confirmed (at
  authoring time) to still ship a WiX/MSI installer -- PowerShell
  7.7+ is reported to drop it in favor of MSIX-only distribution, which
  would make --installer-type wix fail to resolve against an unpinned
  "latest" install. See docs/dsc-migration-notes.md (issue #147) for
  the full rationale, including the winget-pkgs#95172 caveat about
  --scope machine alone and the plan for revisiting this pin once
  7.7's installer situation is confirmed against a real winget
  environment.

  .OUTPUTS
  String array of `winget` CLI arguments.
  #>
}

function Invoke-PwshInstallCommand {
  [CmdletBinding()]
  [OutputType([int])]
  param (
    [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$ArgumentList
  )
  & winget @ArgumentList
  return $LASTEXITCODE
  <#
  .SYNOPSIS
  The only function with a real dependency on the installed `winget`
  binary, kept to a single call so Pester can mock it directly --
  `winget` does not resolve via Get-Command on every machine this
  repo's tests run on (this Linux dev environment included), and Mock
  cannot intercept a command name Get-Command can't resolve at all
  (same constraint documented in libs/winget-pin-sync.ps1's
  Invoke-WinGetPinListCommand and libs/unity-editor-installer.ps1's
  Invoke-UnityEditorsListCommand).

  .OUTPUTS
  Int32 exit code ($LASTEXITCODE after the winget invocation).
  #>
}

function Test-PwshUserScopeCoexistence {
  [CmdletBinding()]
  [OutputType([bool])]
  param (
    [string]$AliasPath = $Script:PwshMsixAliasPath
  )
  if ([string]::IsNullOrEmpty($AliasPath)) {
    return $false
  }
  return Test-Path -Path $AliasPath -PathType Leaf
  <#
  .SYNOPSIS
  Detects a pre-existing user-scope MSIX pwsh execution alias.

  .DESCRIPTION
  A machine that ran this repository's setup before this migration may
  already have MSIX-installed pwsh at
  %LOCALAPPDATA%\Microsoft\WindowsApps\pwsh.exe (an App Execution
  Alias, implemented as an NTFS reparse point). This function only
  detects it; it is never uninstalled here, because the winget package
  identity actually installed on a given machine (the msstore
  9MZ1SNWT0N5D listing vs. the winget-source Microsoft.PowerShell
  manifest's own MSIX bundle) cannot be determined with confidence
  from this repository alone. See docs/dsc-migration-notes.md (issue
  #147).

  A null/empty AliasPath (e.g. the default on a machine without
  $env:LOCALAPPDATA, such as this file's own Linux Pester run) is
  $false rather than an error.

  .OUTPUTS
  $true if the user-scope MSIX execution alias exists, otherwise
  $false.
  #>
}

function Test-PwshMachineScopeInstalled {
  [CmdletBinding()]
  [OutputType([bool])]
  param (
    [string]$ExePath = $Script:PwshMachineScopeExePath
  )
  if ([string]::IsNullOrEmpty($ExePath)) {
    return $false
  }
  return Test-Path -Path $ExePath -PathType Leaf
  <#
  .SYNOPSIS
  Verifies pwsh actually landed at the expected machine-scope path.

  .DESCRIPTION
  `winget install` can return exit code 0 for outcomes short of "the
  machine-scope package is now present" -- for example a no-op against
  an already-tracked package under a different installer technology
  (see Sync-Pwsh's coexistence-conflict handling). Checking for the
  WiX/MSI installer's actual target path
  (%ProgramFiles%\PowerShell\7\pwsh.exe) turns that kind of silent
  false-success into a detectable warning instead of an unverified
  "installation complete" message.

  A null/empty ExePath (e.g. the default on a machine without
  $env:ProgramFiles, such as this file's own Linux Pester run) is
  $false rather than an error.

  .OUTPUTS
  $true if the machine-scope pwsh.exe exists, otherwise $false.
  #>
}

function Sync-Pwsh {
  [CmdletBinding()]
  param ()

  Write-Host '[pwsh] Installing/updating PowerShell 7 (pwsh) at machine scope...' -ForegroundColor Cyan
  $exitCode = Invoke-PwshInstallCommand -ArgumentList (Get-PwshInstallArguments)
  $coexists = Test-PwshUserScopeCoexistence

  if ($exitCode -ne 0) {
    if ($coexists) {
      Write-Error "winget install for PowerShell 7 exited with code ${exitCode}. A user-scope MSIX PowerShell 7 execution alias already exists at %LOCALAPPDATA%\Microsoft\WindowsApps\pwsh.exe -- winget can reject installing a different installer technology (MSI/WiX) over an already-tracked MSIX package. Manually uninstalling the existing MSIX package (winget uninstall) before re-running may be required. See docs/dsc-migration-notes.md (issue #147)."
    }
    else {
      Write-Error "winget install for PowerShell 7 exited with code ${exitCode}."
    }
    return
  }

  if (-not (Test-PwshMachineScopeInstalled)) {
    Write-Error '[pwsh] winget install for PowerShell 7 exited 0, but pwsh.exe was not found at the expected machine-scope path (%ProgramFiles%\PowerShell\7\pwsh.exe). Treat this as a failed install -- winget can report success for a no-op it silently declined to apply. See docs/dsc-migration-notes.md (issue #147).'
    return
  }

  Write-Host '[pwsh] PowerShell 7 (pwsh) machine-scope installation complete.' -ForegroundColor Green

  if ($coexists) {
    Write-Warning '[pwsh] A user-scope MSIX PowerShell 7 execution alias was found at %LOCALAPPDATA%\Microsoft\WindowsApps\pwsh.exe. It is left in place -- it may still take PATH precedence over the machine-scope install depending on PATH ordering. See docs/dsc-migration-notes.md (issue #147) for why this is not removed automatically.'
  }
  <#
  .SYNOPSIS
  Idempotent entry point: installs or updates PowerShell 7 (pwsh) to
  machine scope on every call.

  .DESCRIPTION
  Machine-scope MSI installs write their own machine Path registry
  value as part of the installer's own custom action, so unlike
  libs/coderabbit-cli-installer.ps1 / libs/cursor-cli-installer.ps1,
  no bespoke Add-*ToProcessPath function is needed here --
  libs/process-path-sync.ps1's Sync-ProcessPath already merges
  Machine/User PATH from the registry into the current process on
  demand.

  The user-scope-coexistence check runs unconditionally (both success
  and failure paths) so it can be correlated with a failed install --
  a pre-existing MSIX package is a plausible cause of winget rejecting
  the machine-scope install as a different installer technology, not
  just a PATH-ordering concern. A "successful" (exit 0) install is
  additionally verified against the actual machine-scope binary path,
  since winget can report success for an outcome that did not actually
  apply the requested change.
  #>
}
