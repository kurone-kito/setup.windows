<#
.SYNOPSIS
Shared reader for configurations/runtime-versions.psd1 -- the single
source of truth for pinned Node, Unity Editor, and Unity CLI versions.

This file is dot-sourced (not imported as a module) from post-install.ps1
and unity-cli-installer.ps1 -- do not add Export-ModuleMember here.
#>
Set-StrictMode -Version Latest

function Get-RuntimeVersionsConfig {
  param (
    [Parameter(Mandatory)][string]$Path
  )
  if (-not (Test-Path -Path $Path -PathType Leaf)) {
    Write-Error "Runtime versions config not found: $Path"
    return $null
  }
  try {
    return Import-PowerShellDataFile -Path $Path -ErrorAction Stop
  }
  catch {
    Write-Error "Failed to read runtime versions config ${Path}: $_"
    return $null
  }
  <#
  .SYNOPSIS
  Reads and parses configurations/runtime-versions.psd1, returning $null
  (after Write-Error) on a missing or unreadable file instead of letting
  Import-PowerShellDataFile's own error surface, so every caller fails
  the same way regardless of which failure mode occurred.

  .OUTPUTS
  The parsed hashtable, or $null if the file is missing or malformed.
  Callers must check for $null and return/abort -- this function does
  not throw, matching Set-StrictMode callers that run under Boxstarter's
  Write-Error + return convention.
  #>
}
