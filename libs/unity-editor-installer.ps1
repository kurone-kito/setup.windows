<#
.SYNOPSIS
Installs and tracks the declared Unity Editor version via the Unity
CLI (`unity install`), per configurations/runtime-versions.psd1's
Unity entry.

This file is dot-sourced (not imported as a module) from
libs/post-install.ps1 -- do not add Export-ModuleMember here.
#>
Set-StrictMode -Version Latest

. (Join-Path -Path $PSScriptRoot -ChildPath 'runtime-versions.ps1')

function Invoke-UnityEditorsListCommand {
  [CmdletBinding()]
  [OutputType([hashtable])]
  param ()
  $output = & unity editors -i --format json 2>&1 | Out-String
  return @{ Output = $output; ExitCode = $LASTEXITCODE }
  <#
  .SYNOPSIS
  Runs `unity editors -i --format json` and returns its raw output and
  exit code, with no parsing.

  .DESCRIPTION
  The only function in this file that invokes the real `unity` binary
  for listing installed Editors, kept to a single line specifically so
  Pester can mock it directly. Pester's Mock requires the target
  command to already resolve via Get-Command -- mocking the bare
  `unity` command name itself does not work on a machine with no
  `unity` binary anywhere on PATH (such as this file's own Linux
  Pester run), so the real shell-out is isolated here instead of
  inline inside Get-InstalledUnityEditors.

  .OUTPUTS
  Hashtable: Output (raw stdout+stderr text), ExitCode.
  #>
}

function Get-InstalledUnityEditors {
  [CmdletBinding()]
  [OutputType([string[]])]
  param ()
  $result = Invoke-UnityEditorsListCommand
  if ($result.ExitCode -ne 0) {
    Write-Error "'unity editors -i --format json' exited with code $($result.ExitCode): $($result.Output)"
    return [string[]]@()
  }
  try {
    $envelope = $result.Output | ConvertFrom-Json -ErrorAction Stop
  }
  catch {
    Write-Error "Failed to parse 'unity editors -i --format json' output: $_"
    return [string[]]@()
  }
  if ($null -eq $envelope) {
    Write-Error "'unity editors -i --format json' returned a null envelope: $($result.Output)"
    return [string[]]@()
  }
  $successProperty = $envelope.PSObject.Properties['success']
  $dataProperty = $envelope.PSObject.Properties['data']
  if (-not $successProperty -or -not $successProperty.Value -or
    -not $dataProperty -or $null -eq $dataProperty.Value) {
    Write-Error "'unity editors -i --format json' returned an unexpected envelope shape (missing/false success or missing/null data): $($result.Output)"
    return [string[]]@()
  }
  $versions = foreach ($item in @($dataProperty.Value)) {
    $property = $item.PSObject.Properties['version']
    if (-not $property) {
      $property = $item.PSObject.Properties['Version']
    }
    if ($property) {
      $property.Value
    }
  }
  return [string[]]@($versions | Where-Object { $_ })
  <#
  .SYNOPSIS
  Returns the installed Editor version strings that
  Invoke-UnityEditorsListCommand's output could identify.

  .DESCRIPTION
  The JSON envelope (`success`/`command`/`data`/`errors`/`warnings`) is
  documented (docs.unity.com's CLI reference, "Format selection"
  table), but the exact shape of each item inside `data` for the
  `editors` command is not documented anywhere found during this
  issue's research -- the same situation `Test-UnityCliCurrent`
  (libs/unity-cli-installer.ps1, issue #76) was in for `unity
  --version`'s output. Rather than assume an unverified deep shape,
  this probes a small, explicit set of plausible field names per item
  ('version', 'Version') and skips any item where neither is present,
  so an unexpected real shape degrades to "not recognized" instead of
  crashing the whole install path.

  This function's only dependency is Invoke-UnityEditorsListCommand's
  return value (no direct call to `unity`), so its parsing logic --
  the part actually worth testing -- is fully exercisable by mocking
  that one function, without needing a real Unity CLI installed.

  .OUTPUTS
  String[]: the version string of each installed Editor this function
  could identify. Callers must not assume a non-empty result is
  preserved across a plain assignment -- see the `@(...)` note on
  Sync-UnityEditor's call site.
  #>
}

function Test-UnityCliAvailable {
  $null -ne (Get-Command unity -CommandType Application -ErrorAction SilentlyContinue)
  <#
  .SYNOPSIS
  Returns $true if the Unity CLI (`unity`) is on PATH, $false
  otherwise.

  .DESCRIPTION
  Isolated into its own function (the same pattern as
  Test-CommandExists in libs/post-install.ps1) purely so
  Sync-UnityEditor's Pester tests can mock this one check instead of
  requiring a real `unity` binary on PATH.
  #>
}

function Test-UnityEditorInstalled {
  param (
    [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Installed,
    [Parameter(Mandatory)][string]$Target
  )
  foreach ($version in $Installed) {
    if ([string]::Equals($version, $Target, [System.StringComparison]::Ordinal)) {
      return $true
    }
  }
  return $false
  <#
  .SYNOPSIS
  Decides whether the declared Target version is already installed, by
  exact string match against the installed Editor versions -- never a
  regex or substring match.

  .DESCRIPTION
  The prior Unity Hub CLI implementation used
  `$versions | Select-String -Pattern $Version`, which treated the
  version as a regex: a declared "2022.3.22f1" would also match an
  installed "2022X3Y22f1"-shaped string, because '.' matches any
  character in a regex. This function is the fix (issue #74) -- exact,
  ordinal equality only.
  #>
}

function Get-UnityEditorDrift {
  param (
    [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Declared,
    [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Installed
  )
  $missing = @($Declared | Where-Object { -not (Test-UnityEditorInstalled -Installed $Installed -Target $_) })
  $extra = @($Installed | Where-Object { -not (Test-UnityEditorInstalled -Installed $Declared -Target $_) })
  return @{ MissingVersions = $missing; ExtraVersions = $extra }
  <#
  .SYNOPSIS
  Compares the declared Editor version(s) against what's actually
  installed and reports the difference.

  .DESCRIPTION
  Report-only: never deletes or otherwise acts on an installed-but-
  undeclared Editor. Unity Editors are side-by-side, and a version
  installed for a different project must not be removed as a side
  effect of this comparison -- an explicit constraint in issue #74.

  .OUTPUTS
  Hashtable: MissingVersions (declared but not installed), ExtraVersions
  (installed but not declared). Both use the same exact-match semantics
  as Test-UnityEditorInstalled.
  #>
}

function Invoke-UnityInstallCommand {
  [CmdletBinding()]
  [OutputType([int])]
  param (
    [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$ArgumentList
  )
  & unity @ArgumentList
  return $LASTEXITCODE
  <#
  .SYNOPSIS
  Runs `unity` with the given argument list and returns its exit code.

  .DESCRIPTION
  The only function in this file that invokes the real `unity` binary
  for installing an Editor, isolated for the same reason
  Invoke-UnityEditorsListCommand is: Pester can only mock a command
  that already resolves via Get-Command, and no `unity` binary exists
  on PATH on this file's own Linux Pester run. Invoke-UnityEditorInstall
  builds the argument list (the part worth testing); this function's
  only job is the real process invocation.

  .OUTPUTS
  Int: `unity`'s real exit code.
  #>
}

function Invoke-UnityEditorInstall {
  param (
    [Parameter(Mandatory)][string]$Version,
    [Parameter(Mandatory)][string]$Changeset,
    [string[]]$Modules = @()
  )
  $moduleArgs = foreach ($module in $Modules) { '-m'; $module }
  $argumentList = @('install', $Version, '-c', $Changeset) + @($moduleArgs) + @('--cm')
  $exitCode = Invoke-UnityInstallCommand -ArgumentList $argumentList
  switch ($exitCode) {
    0 { Write-Host "  Unity $Version installed." -ForegroundColor Gray }
    130 { Write-Error "Unity $Version install was interrupted (exit code 130 -- Ctrl+C)." }
    default { Write-Error "Unity $Version install failed with exit code ${exitCode}." }
  }
  return $exitCode
  <#
  .SYNOPSIS
  Runs `unity install <Version> -c <Changeset> -m <module> [-m
  <module>...] --cm` and returns its exit code.

  .DESCRIPTION
  --cm (also install each module's child modules) is always passed,
  matching the prior Unity Hub CLI invocation's behavior. Kept as-is
  rather than reconsidered as part of this refactor, so switching
  install paths doesn't also silently change what gets installed --
  issue #74's own explicit instruction.

  Unity's documented exit codes
  (docs.unity.com/en-us/unity-cli/unity-cli-reference) are more
  granular than a simple "0 success / 1 error / 130 interrupted": 0
  success, 1 general error, 2 usage error, 3 auth/authorization
  failure, 4 configuration required, 6 the command's primary operation
  itself failed (e.g. install failed), 130 interrupted (Ctrl+C /
  SIGINT), 143 terminated (SIGTERM). Only 0 (success) and 130
  (user-interrupted, logged distinctly per this issue's acceptance
  criteria) get special handling; every other non-zero code is treated
  uniformly as a failure and logged with its exact value, since a real
  install failure can surface as 1, 2, 3, 4, or 6 depending on the
  cause -- "1" does not uniquely mean "install failed".

  .OUTPUTS
  Int: the `unity install` process's real exit code.
  #>
}

function Sync-UnityEditor {
  param (
    [Parameter(Mandatory)][string]$ConfigPath
  )
  $config = Get-RuntimeVersionsConfig -Path $ConfigPath
  if ($null -eq $config) {
    return
  }
  if (-not $config.Contains('Unity') -or
    -not $config.Unity.Contains('Version') -or -not $config.Unity.Contains('Changeset') -or
    -not $config.Unity.Contains('Modules')) {
    Write-Error "Runtime versions config ${ConfigPath} is missing a Unity.Version/Unity.Changeset/Unity.Modules entry."
    return
  }
  $unityConfig = $config.Unity

  if (-not (Test-UnityCliAvailable)) {
    # throw, not Write-Error + return: this is a function, not a script's
    # own top level -- `return` here only exits Sync-UnityEditor and lets
    # libs/post-install.ps1's later steps (Docker, mkcert, etc.) run
    # normally under Boxstarter's default $ErrorActionPreference =
    # 'Continue', silently reaching "setup complete" despite the Unity
    # Editor step never running. Verified empirically: a dot-sourced
    # function's `Write-Error` + `return` does not halt its caller's
    # later statements, unlike `return` at a script's own top level
    # (the case this repo's existing Write-Error + return convention,
    # e.g. Phase 0's OS check, actually relies on). `throw` propagates
    # as a terminating error through post-install.ps1 (invoked via `&`
    # from boxstarter.ps1) and aborts the whole run -- the correct
    # outcome here, since a missing Unity CLI means the earlier
    # Sync-UnityCli step (issue #76) itself already failed silently.
    throw 'Unity CLI (`unity`) is not on PATH -- cannot install or verify the Unity Editor. The Unity CLI installer (libs/unity-cli-installer.ps1) must run before this step; there is no Unity Hub CLI fallback (issue #74).'
  }

  # -ErrorAction Stop: Get-InstalledUnityEditors returns an empty array
  # (not a thrown error) when it can't determine the installed list, so
  # that other callers can degrade gracefully. Sync-UnityEditor cannot --
  # treating "couldn't tell" the same as "genuinely nothing installed"
  # would attempt an install based on a false premise instead of
  # reporting the real problem (`unity editors` itself failing).
  # -ErrorAction Stop escalates Get-InstalledUnityEditors's own
  # Write-Error calls to terminating for this call only.
  #
  # @(...) guards against PowerShell's own empty-array-collapses-to-$null
  # behavior across a function-call boundary (confirmed empirically:
  # `$x = Get-Foo` is $null, not an empty array, when Get-Foo's only
  # output is `return @()`) -- without this, an environment with zero
  # installed Editors would fail Get-UnityEditorDrift's
  # [AllowEmptyCollection()] binding instead of reporting zero drift.
  try {
    $installed = @(Get-InstalledUnityEditors -ErrorAction Stop)
  }
  catch {
    Write-Error "Could not determine installed Unity Editors -- aborting rather than risk installing based on unknown state: $_"
    return
  }
  $target = $unityConfig.Version
  $drift = Get-UnityEditorDrift -Declared @($target) -Installed $installed

  foreach ($version in $drift.ExtraVersions) {
    Write-Host "[unity-editor] Installed but not declared: $version (left as-is -- Editors are side-by-side)." -ForegroundColor Yellow
  }

  if ($drift.MissingVersions.Count -eq 0) {
    Write-Host "[unity-editor] Unity $target already installed -- skipping." -ForegroundColor Gray
    return
  }

  Write-Host "[unity-editor] Installing Unity $target (modules: $($unityConfig.Modules -join ', '))..." -ForegroundColor Cyan
  $exitCode = Invoke-UnityEditorInstall -Version $target -Changeset $unityConfig.Changeset -Modules $unityConfig.Modules
  if ($exitCode -ne 0) {
    return
  }

  Write-Host '[unity-editor] Unity Editor installation complete.' -ForegroundColor Green
  <#
  .SYNOPSIS
  Idempotent entry point: installs the declared Unity Editor version
  only if it isn't already installed, and reports (without deleting)
  any installed Editor versions the declared config doesn't name.
  #>
}
