<#
.SYNOPSIS
Decides, without side effects, which winget-based configuration route
boxstarter.ps1 should use: the primary `dsc` route (`winget configure`
against configurations/packages.dsc.yaml) or the degraded `import`
route (`winget import` against the .import.json fallback).

This file is dot-sourced (not imported as a module) from
boxstarter.ps1's Phase 2 -- do not add Export-ModuleMember here.
#>
Set-StrictMode -Version Latest

function Test-ConfigurationStrategy {
  if (-not (Get-Command winget -CommandType Application -ErrorAction SilentlyContinue)) {
    return @{
      Route  = 'unsupported'
      Reason = 'winget was not found on PATH. The import.json route also depends on winget, so no route can run.'
    }
  }

  $wingetVersion = (winget --version | Select-Object -First 1) -replace '^v', ''

  winget configure --help *> $null
  $configureExitCode = $LASTEXITCODE
  $configureAvailable = $configureExitCode -eq 0

  if ($configureAvailable) {
    return @{
      Route  = 'dsc'
      Reason = "winget $wingetVersion recognizes the 'configure' subcommand (winget configure --help exited 0)."
    }
  }

  return @{
    Route  = 'import'
    Reason = "winget $wingetVersion does not recognize the 'configure' subcommand (winget configure --help exited $configureExitCode)."
  }
  <#
  .SYNOPSIS
  Tests which winget configuration route is available and returns the
  selected route together with the evidence used to select it.

  .DESCRIPTION
  Candidates considered for the probe, and why `winget configure --help`
  was the one chosen:
  - winget command existence (Get-Command) -- kept. This is the
    precondition for every route: import.json also depends on winget,
    so a missing winget makes the whole setup unsupported regardless
    of which route would otherwise be picked.
  - `winget --version` compared against a known minimum -- rejected as
    the primary signal. Which release made `configure` non-experimental
    is a moving target tied to Microsoft's own release cadence; hard-
    coding a version threshold here would silently go stale. The
    version string is still captured and included in the reason text
    as supporting evidence, not as the decision itself.
  - `winget settings export`'s experimentalFeatures.configuration flag
    -- rejected. Whether that flag exists or matters depends on the
    installed winget's own settings schema, which has changed across
    releases; parsing it is more brittle than asking winget directly
    whether it recognizes the subcommand.
  - `winget configure --help` exit code -- chosen. It asks winget
    directly whether it recognizes the `configure` subcommand on this
    machine, right now, without installing or changing anything.
    Exit 0 means `configure` is available (dsc route); any non-zero
    exit means it isn't (import route).

  This function performs no installation and changes no configuration
  -- every winget call here is a read-only `--help`/`--version`
  invocation.

  Route selection happens once, here, before any package installation
  starts. It is intentionally NOT re-evaluated if `winget configure`
  fails partway through Phase 2: a mid-run failure is either a bad
  package ID or a transient single-package error, and neither is fixed
  by silently switching to the import route -- id/source mismatches
  fail identically under `winget import`, and transient failures are a
  retry concern, not a routing concern. Re-routing after a partial
  `winget configure` apply would also layer a second, differently-
  scoped install operation on top of whatever the first one already
  changed. See issue #65 for the full rationale.

  .OUTPUTS
  Hashtable with Route ('dsc' | 'import' | 'unsupported') and Reason
  (string describing the evidence behind the selected route). Returning
  a hashtable from a `Test-` function follows the same precedent as
  `Test-OsSupport` in libs/os-guard.ps1, per issue #65's own naming
  request.
  #>
}
