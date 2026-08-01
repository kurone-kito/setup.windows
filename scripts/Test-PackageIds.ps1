<#
.SYNOPSIS
Verifies that every WinGetPackage id/source pair in a dsc.yaml file
actually exists, without installing anything.

.DESCRIPTION
A wrong or stale package id is not fixed by boxstarter.ps1's route
fallback (issue #67): the import route queries the same winget, same
id, same source, and fails the same way. This script checks id
validity independently of route selection, via `winget show`, so a
typo or a package removed from its source can be caught before
running setup.

Requires the powershell-yaml module (Install-Module -Name
powershell-yaml -RequiredVersion 0.4.12 -Scope CurrentUser) and a
working `winget` on PATH -- this script only runs on Windows.

Run this after adding or changing a package in dsc.yaml, and whenever
setup fails on a specific package, to tell a genuine id/source problem
apart from a transient install failure. See
docs/dsc-migration-notes.md for the full guidance.

.PARAMETER DscPath
Path to the dsc.yaml file to verify (packages.dsc.yaml or
packages.min.dsc.yaml).

.EXAMPLE
./scripts/Test-PackageIds.ps1 -DscPath ./configurations/packages.dsc.yaml

.EXAMPLE
./scripts/Test-PackageIds.ps1 -DscPath ./configurations/packages.min.dsc.yaml
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [string] $DscPath
)

Set-StrictMode -Version Latest

if (-not (Test-Path -Path $DscPath -PathType Leaf)) {
  throw "DscPath '$DscPath' does not exist or is not a file."
}

Import-Module powershell-yaml -RequiredVersion 0.4.12 -ErrorAction Stop
. (Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath 'libs', 'configuration-builder.ps1')
. (Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath 'libs', 'package-id-checker.ps1')

$document = ConvertFrom-Yaml -Yaml (Get-Content -Raw -Path $DscPath) -Ordered
$resource = @($document['properties']['resources'])
$assertion = @($document['properties']['assertions'])
$split = Split-DscResource -Resource $resource -Assertion $assertion

$result = Test-PackageIdList -Grouped $split.Grouped

Write-Output "Confirmed: $($result.Confirmed.Count) package(s) exist."

if ($result.NotFound.Count -gt 0) {
  Write-Output "Not found ($($result.NotFound.Count)):"
  foreach ($item in $result.NotFound) {
    Write-Output "  - $($item.Id) ($($item.Source)) exit=$($item.ExitCode)"
  }
}

if ($result.Indeterminate.Count -gt 0) {
  Write-Output "Indeterminate ($($result.Indeterminate.Count)):"
  foreach ($item in $result.Indeterminate) {
    Write-Output "  - $($item.Id) ($($item.Source)) exit=$($item.ExitCode)"
  }
}

exit (Get-PackageIdCheckExitCode -Result $result)
