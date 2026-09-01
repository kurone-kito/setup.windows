<#
.SYNOPSIS
Refreshes the current process's $env:Path from the persisted
Machine/User PATH values, so a tool installed earlier in this same
PowerShell process (e.g. by WinGet Configuration in Phase 2) is
reliably detected by a later Get-Command-based check in the same
process (e.g. Phase 5's dotnet/vagrant/mkcert/git checks) without
waiting for a reboot or a fresh process (issue #129).

This file is dot-sourced (not imported as a module) from both
libs/post-install.ps1 and libs/coderabbit-cli-installer.ps1 -- do not
add Export-ModuleMember here.
#>
Set-StrictMode -Version Latest

function Get-RegistryPathValue {
  [CmdletBinding()]
  [OutputType([string])]
  param (
    [Parameter(Mandatory)]
    [ValidateSet('Machine', 'User')]
    [string]$Scope
  )
  [System.Environment]::GetEnvironmentVariable('Path', $Scope)
  <#
  .SYNOPSIS
  Reads the persisted PATH value for the given scope -- the same value
  Windows installers themselves write to (Machine backs onto HKLM's
  ...\Session Manager\Environment, User onto HKCU's Environment) -- via
  .NET's [System.Environment]::GetEnvironmentVariable(name, target)
  overload.

  .DESCRIPTION
  Isolated into its own one-line function purely so Pester's Mock can
  intercept it -- Mock cannot intercept a bare static .NET method call.
  This mirrors the existing pattern already used elsewhere in this
  repository for the same reason (e.g.
  libs/unity-editor-installer.ps1's Invoke-UnityEditorsListCommand,
  libs/unity-cli-installer.ps1's Get-InstalledUnityCliVersion).

  Verified empirically that on the non-Windows runner this file's own
  Pester suite executes on, the Machine/User overload does not throw --
  it returns $null -- so no platform guard is added here; an
  accidentally-unmocked call in a new test fails on a clear assertion
  mismatch instead of an unrelated platform exception. A guard keyed on
  $IsWindows is deliberately avoided too: libs/post-install.ps1 and
  libs/coderabbit-cli-installer.ps1 (this file's two callers) are
  intentionally kept compatible with Windows PowerShell 5.1 (no
  #Requires -Version 7.0, unlike scripts/*.ps1 -- see
  docs/dsc-migration-notes.md's "PowerShell 7+ requirement" section),
  where $IsWindows does not exist and would itself throw under this
  repository's blanket Set-StrictMode -Version Latest.

  .OUTPUTS
  String, or $null if the scope has no persisted PATH value.
  #>
}

function Sync-ProcessPath {
  [CmdletBinding()]
  param ()
  $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
  $existing = @($env:Path -split ';' | Where-Object { $_ -ne '' })
  $additions = @(
    (Get-RegistryPathValue -Scope Machine), (Get-RegistryPathValue -Scope User)
  ) `
    | Where-Object { $_ } `
    | ForEach-Object { $_ -split ';' } `
    | Where-Object { $_ -ne '' }
  $merged = @(
    foreach ($entry in @($existing) + @($additions)) {
      $normalized = $entry.TrimEnd('\', '/')
      if ($seen.Add($normalized)) {
        $entry
      }
    }
  )
  $env:Path = $merged -join ';'
  <#
  .SYNOPSIS
  Rebuilds the current process's $env:Path by merging the Machine-scope
  and User-scope PATH values read live from the registry (via
  Get-RegistryPathValue) on top of whatever is already in $env:Path.

  .DESCRIPTION
  A child installer (WinGet Configuration in Phase 2, or an msi/exe run
  from Phase 2/3/4) only ever updates the persisted Machine/User PATH --
  it cannot reach back into boxstarter.ps1's own already-running
  process to update *its* $env:Path, and only a brand-new process picks
  up a persisted PATH change. Call this immediately before any
  Get-Command-based tool-existence check that must reliably detect a
  tool installed earlier in the same process (issue #129).

  Existing $env:Path entries are preserved, never replaced, so a
  process-only PATH addition that is not registry-backed -- for
  example libs/coderabbit-cli-installer.ps1's own
  Add-CoderabbitCliToProcessPath appending its install dir directly --
  is never dropped by this merge. Entries are deduplicated case- and
  trailing-separator-insensitively, keeping each entry's first
  occurrence and its original relative order (existing entries first,
  then any new Machine-scope entries, then any new User-scope entries)
  -- the same dedup semantics Add-CoderabbitCliToProcessPath already
  uses, for consistency.
  #>
}
