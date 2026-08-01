<#
.SYNOPSIS
Regenerates a DSC configuration's import.json fallback and unapplied-
resources list from its dsc.yaml source of truth.

.DESCRIPTION
configurations/*.dsc.yaml is hand-maintained; configurations/*.import.json
and configurations/*.unapplied.json are generated from it by this
script and must never be hand-edited. See docs/dsc-migration-notes.md.

Requires the powershell-yaml module (Install-Module -Name
powershell-yaml -RequiredVersion 0.4.12 -Scope CurrentUser).

.PARAMETER DscPath
Path to the source dsc.yaml file.

.PARAMETER ImportJsonPath
Path to write the generated import.json to. Defaults to $DscPath
with its trailing ".dsc.yaml" replaced by ".import.json".

.PARAMETER UnappliedResourcesPath
Path to write the generated unapplied-resources list to. Defaults to
$DscPath with its trailing ".dsc.yaml" replaced by ".unapplied.json".

.EXAMPLE
./scripts/Build-Configurations.ps1 -DscPath ./configurations/packages.dsc.yaml

.EXAMPLE
./scripts/Build-Configurations.ps1 -DscPath ./configurations/packages.min.dsc.yaml
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [string] $DscPath,

  [string] $ImportJsonPath,

  [string] $UnappliedResourcesPath
)

Set-StrictMode -Version Latest

# SourceDetails values are not present in dsc.yaml (it only carries
# settings.source: winget|msstore); these are the real winget/msstore
# entries already committed in configurations/packages.min.import.json,
# reproduced here as the single place that maps a known source name to
# the SourceDetails winget import.json needs to resolve it.
$knownSourceDetail = [ordered]@{
  winget  = [ordered]@{
    Argument   = 'https://cdn.winget.microsoft.com/cache'
    Identifier = 'Microsoft.Winget.Source_8wekyb3d8bbwe'
    Name       = 'winget'
    Type       = 'Microsoft.PreIndexed.Package'
  }
  msstore = [ordered]@{
    Argument   = 'https://storeedgefd.dsx.mp.microsoft.com/v9.0'
    Identifier = 'StoreEdgeFD'
    Name       = 'msstore'
    Type       = 'Microsoft.Rest'
  }
}

if (-not (Test-Path -Path $DscPath -PathType Leaf)) {
  throw "DscPath '$DscPath' does not exist or is not a file."
}

if (-not $ImportJsonPath) {
  if ($DscPath -notlike '*.dsc.yaml') {
    throw "Cannot derive -ImportJsonPath from -DscPath '$DscPath' (does not end with '.dsc.yaml'); pass -ImportJsonPath explicitly."
  }
  $ImportJsonPath = $DscPath -replace '\.dsc\.yaml$', '.import.json'
}

if (-not $UnappliedResourcesPath) {
  if ($DscPath -notlike '*.dsc.yaml') {
    throw "Cannot derive -UnappliedResourcesPath from -DscPath '$DscPath' (does not end with '.dsc.yaml'); pass -UnappliedResourcesPath explicitly."
  }
  $UnappliedResourcesPath = $DscPath -replace '\.dsc\.yaml$', '.unapplied.json'
}

Import-Module powershell-yaml -RequiredVersion 0.4.12 -ErrorAction Stop
. (Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath 'libs', 'configuration-builder.ps1')

$document = ConvertFrom-Yaml -Yaml (Get-Content -Raw -Path $DscPath) -Ordered
$resource = @($document['properties']['resources'])
$assertion = @($document['properties']['assertions'])

$split = Split-DscResource -Resource $resource -Assertion $assertion
$importJson = ConvertTo-PackagesImportJson -Grouped $split.Grouped -SourceDetail $knownSourceDetail
$unappliedJson = ConvertTo-UnappliedResourceJson -Unapplied $split.Unapplied

[System.IO.File]::WriteAllText($ImportJsonPath, $importJson)
[System.IO.File]::WriteAllText($UnappliedResourcesPath, $unappliedJson)

Write-Output "Wrote $ImportJsonPath ($($split.Grouped.Values | ForEach-Object { $_.Count } | Measure-Object -Sum | Select-Object -ExpandProperty Sum) packages) and $UnappliedResourcesPath ($($split.Unapplied.Count) entries)."
