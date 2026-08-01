<#
.SYNOPSIS
Pure-ish helpers for verifying that dsc.yaml's WinGetPackage ids
actually exist in their declared source, via `winget show`. Used by
scripts/Test-PackageIds.ps1.

This file is dot-sourced (not imported as a module) -- do not add
Export-ModuleMember here.
#>
Set-StrictMode -Version Latest

# winget-cli's own documented exit code for "no package found matching
# input criteria" (APPINSTALLER_CLI_ERROR_NO_APPLICATIONS_FOUND,
# 0x8A150014 = -1978335212 as a signed 32-bit exit code), from
# https://github.com/microsoft/winget-cli/blob/master/src/AppInstallerSharedLib/Public/AppInstallerErrors.h.
# Any OTHER non-zero exit (source-open failure, network error, an
# error this script doesn't specifically recognize) is treated as
# Indeterminate, not NotFound -- see Test-PackageExistence's doc
# comment.
$Script:PackageNotFoundExitCode = -1978335212

function Invoke-WingetShow {
  param(
    [Parameter(Mandatory)]
    [string] $Id,

    [Parameter(Mandatory)]
    [string] $Source
  )

  winget show --exact --id $Id --source $Source --accept-source-agreements --disable-interactivity *> $null
  return $LASTEXITCODE
  <#
  .SYNOPSIS
  Runs `winget show` for one package id/source pair (no install, no
  configuration change) and returns its exit code.

  .DESCRIPTION
  The only function in this file with a real winget dependency --
  kept to this one call specifically so Pester tests can mock this
  single function and exercise every other function's classification
  logic without winget installed (this Linux dev environment has no
  winget at all).

  .OUTPUTS
  Int32 exit code ($LASTEXITCODE after the winget invocation).
  #>
}

function Test-PackageExistence {
  param(
    [Parameter(Mandatory)]
    [string] $Id,

    [Parameter(Mandatory)]
    [string] $Source
  )

  $exitCode = Invoke-WingetShow -Id $Id -Source $Source

  $status = if ($exitCode -eq 0) {
    'Confirmed'
  }
  elseif ($exitCode -eq $Script:PackageNotFoundExitCode) {
    'NotFound'
  }
  else {
    'Indeterminate'
  }

  return [pscustomobject][ordered]@{
    Id       = $Id
    Source   = $Source
    Status   = $status
    ExitCode = $exitCode
  }
  <#
  .SYNOPSIS
  Classifies one package id/source pair as Confirmed, NotFound, or
  Indeterminate.

  .DESCRIPTION
  Only winget's own documented "no package found" exit code
  ($Script:PackageNotFoundExitCode) is treated as NotFound. Every
  other non-zero exit -- a source-open failure, a network error, or an
  exit code this script doesn't specifically recognize -- is
  Indeterminate, deliberately, so a transient network problem is never
  reported as a bad package id. Conflating the two would destroy this
  check's own credibility (issue #68).

  .OUTPUTS
  pscustomobject { Id; Source; Status; ExitCode }.
  #>
}

function Test-PackageIdList {
  param(
    [Parameter(Mandatory)]
    [System.Collections.IDictionary] $Grouped
  )

  $checked = [System.Collections.Generic.List[object]]::new()
  foreach ($source in $Grouped.Keys) {
    foreach ($id in @($Grouped[$source])) {
      $checked.Add((Test-PackageExistence -Id $id -Source $source))
    }
  }

  return [ordered]@{
    Confirmed     = @($checked | Where-Object { $_.Status -eq 'Confirmed' })
    NotFound      = @($checked | Where-Object { $_.Status -eq 'NotFound' })
    Indeterminate = @($checked | Where-Object { $_.Status -eq 'Indeterminate' })
  }
  <#
  .SYNOPSIS
  Runs Test-PackageExistence over every id/source pair in a
  Split-DscResource Grouped map (libs/configuration-builder.ps1,
  reused here rather than re-parsing dsc.yaml) and buckets the
  results.

  .OUTPUTS
  Ordered hashtable with Confirmed / NotFound / Indeterminate, each an
  array of Test-PackageExistence's pscustomobject.
  #>
}

function Get-PackageIdCheckExitCode {
  param(
    [Parameter(Mandatory)]
    [System.Collections.IDictionary] $Result
  )

  if (@($Result.NotFound).Count -gt 0) {
    return 1
  }
  if (@($Result.Indeterminate).Count -gt 0) {
    return 2
  }
  return 0
  <#
  .SYNOPSIS
  Maps a Test-PackageIdList result to a process exit code.

  .DESCRIPTION
  1 if any id was confirmed NotFound (checked first -- a confirmed bad
  id is more actionable than an indeterminate one, so it takes
  priority even when both occurred in the same run). 2 if only
  Indeterminate ids occurred -- a distinct code from NotFound, per
  issue #68's own requirement that the two never share an exit code.
  0 if every id was Confirmed.
  #>
}

function Invoke-PackageIdCheck {
  param(
    [Parameter(Mandatory)]
    [string] $DscPath
  )

  $document = ConvertFrom-Yaml -Yaml (Get-Content -Raw -Path $DscPath) -Ordered
  $resource = @($document['properties']['resources'])
  $assertion = @($document['properties']['assertions'])
  $split = Split-DscResource -Resource $resource -Assertion $assertion
  $result = Test-PackageIdList -Grouped $split.Grouped

  $lines = [System.Collections.Generic.List[string]]::new()
  $lines.Add("Confirmed: $($result.Confirmed.Count) package(s) exist.")
  $lines.Add("Not found ($($result.NotFound.Count)):")
  foreach ($item in $result.NotFound) {
    $lines.Add("  - $($item.Id) ($($item.Source)) exit=$($item.ExitCode)")
  }
  $lines.Add("Indeterminate ($($result.Indeterminate.Count)):")
  foreach ($item in $result.Indeterminate) {
    $lines.Add("  - $($item.Id) ($($item.Source)) exit=$($item.ExitCode)")
  }

  return [ordered]@{
    Lines    = $lines
    Result   = $result
    ExitCode = (Get-PackageIdCheckExitCode -Result $result)
  }
  <#
  .SYNOPSIS
  Runs the full package-id check for one dsc.yaml file: parse, split,
  test, format, and compute the exit code.

  .DESCRIPTION
  Everything scripts/Test-PackageIds.ps1 needs, factored out into one
  function so Pester can exercise the whole pipeline -- including
  output formatting and exit-code selection -- without spawning a
  child process or calling `exit` directly from a test. Requires
  Split-DscResource (libs/configuration-builder.ps1) and
  ConvertFrom-Yaml (the powershell-yaml module) to already be
  available in the caller's scope; scripts/Test-PackageIds.ps1 dot-
  sources configuration-builder.ps1 before this file for that reason.

  The "Not found" and "Indeterminate" headers are always printed, with
  a 0 count when empty, so a caller never has to infer "section
  missing" as "zero" -- the output shape is the same whether every id
  was confirmed or not.

  .OUTPUTS
  Ordered hashtable: Lines (array of output strings, ready to print),
  Result (Test-PackageIdList's bucketed result), ExitCode
  (Get-PackageIdCheckExitCode's result for Result).
  #>
}
