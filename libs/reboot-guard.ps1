<#
.SYNOPSIS
Detects pending-reboot indicators that can make Boxstarter's own
reboot-pending check loop forever before boxstarter.ps1 ever runs.

This file is dot-sourced (not imported as a module) from setup.cmd --
do not add Export-ModuleMember here.
#>
Set-StrictMode -Version Latest

function Test-PendingRebootIndicators {
  <#
  .SYNOPSIS
  Checks the same pending-reboot indicators Boxstarter's own
  Get-PendingReboot (Boxstarter.Bootstrapper) references, without
  depending on the Boxstarter module. Some of these are known false-
  positive sources (see README.md's Troubleshooting section).
  .OUTPUTS
  PSCustomObject with one boolean property per indicator:
  ComponentBasedServicing, WindowsUpdateAutoUpdate,
  PendingFileRenameOperations, ComputerRenamePending.
  #>
  $componentBasedServicing = Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
  $windowsUpdateAutoUpdate = Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'

  $pendingFileRenameProps = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction SilentlyContinue
  $pendingFileRenameOperations = [bool]($pendingFileRenameProps -and $pendingFileRenameProps.PendingFileRenameOperations)

  $activeNameProps = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName' -Name ComputerName -ErrorAction SilentlyContinue
  $pendingNameProps = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName' -Name ComputerName -ErrorAction SilentlyContinue
  $activeName = if ($activeNameProps) { $activeNameProps.ComputerName } else { $null }
  $pendingName = if ($pendingNameProps) { $pendingNameProps.ComputerName } else { $null }
  $nameMismatch = [bool]($activeName -and $pendingName -and $activeName -ne $pendingName)
  $joinDomainPending = Test-Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\JoinDomain'
  $avoidSpnSetPending = Test-Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\AvoidSpnSet'
  $computerRenamePending = [bool]($nameMismatch -or $joinDomainPending -or $avoidSpnSetPending)

  [pscustomobject]@{
    ComponentBasedServicing     = $componentBasedServicing
    WindowsUpdateAutoUpdate     = $windowsUpdateAutoUpdate
    PendingFileRenameOperations = $pendingFileRenameOperations
    ComputerRenamePending       = $computerRenamePending
  }
}
