<#
.SYNOPSIS
Pure parsing/grouping/serialization helpers for regenerating
configurations/*.import.json and the unapplied-resources list from
configurations/*.dsc.yaml. Used by scripts/Build-Configurations.ps1.

This file is dot-sourced (not imported as a module) -- do not add
Export-ModuleMember here.
#>
Set-StrictMode -Version Latest

function Split-DscResource {
  param(
    [Parameter(Mandatory)]
    [AllowEmptyCollection()]
    [object[]] $Resource,

    [AllowEmptyCollection()]
    [object[]] $Assertion = @()
  )

  $grouped = [ordered]@{}
  $unapplied = [System.Collections.Generic.List[object]]::new()

  foreach ($item in $Resource) {
    if ($item['resource'] -eq 'Microsoft.WinGet.DSC/WinGetPackage') {
      $source = $item['settings']['source']
      $packageId = $item['settings']['id']
      if ([string]::IsNullOrEmpty($source) -or [string]::IsNullOrEmpty($packageId)) {
        throw "WinGetPackage resource '$($item['id'])' is missing settings.source or settings.id."
      }
      if (-not $grouped.Contains($source)) {
        $grouped[$source] = [System.Collections.Generic.List[string]]::new()
      }
      $grouped[$source].Add($packageId)
      continue
    }
    $unapplied.Add([pscustomobject][ordered]@{
        Resource    = $item['resource']
        Id          = $item['id']
        Description = $item['directives']['description']
      })
  }

  foreach ($item in $Assertion) {
    $unapplied.Add([pscustomobject][ordered]@{
        Resource    = $item['resource']
        Id          = if ($item.Contains('id')) { $item['id'] } else { $null }
        Description = $item['directives']['description']
      })
  }

  return [ordered]@{
    Grouped   = $grouped
    Unapplied = $unapplied
  }
  <#
  .SYNOPSIS
  Splits a parsed dsc.yaml document's `properties.resources` and
  `properties.assertions` into WinGetPackage entries (grouped by
  settings.source, in first-encounter order) and everything else --
  the "unapplied resources" the import.json route cannot express.

  .DESCRIPTION
  Grouping is by first-encounter order, not a fixed known-source list,
  so this function stays generic and testable with fixture source
  names that don't exist in the real configuration. Mapping a source
  name to its SourceDetails (Argument/Identifier/Name/Type) is a
  separate concern, handled by ConvertTo-PackagesImportJson.

  Throws if a WinGetPackage resource is missing settings.source or
  settings.id, naming the offending resource's own id, rather than
  letting a null/empty key reach $grouped (an OrderedDictionary throws
  a cryptic "Key cannot be null" on that) or silently emitting an
  invalid PackageIdentifier.

  .OUTPUTS
  Ordered hashtable with Grouped (ordered dictionary of source name ->
  list of PackageIdentifier strings, insertion order = first-
  encounter order in $Resource) and Unapplied (list of pscustomobject
  { Resource; Id; Description }, resources before assertions, each
  group in input order). Id is $null for assertions, which carry no
  `id` key in dsc.yaml.
  #>
}

function ConvertTo-PackagesImportJson {
  param(
    [Parameter(Mandatory)]
    [System.Collections.IDictionary] $Grouped,

    [Parameter(Mandatory)]
    [System.Collections.IDictionary] $SourceDetail
  )

  $unknown = @($Grouped.Keys | Where-Object { -not $SourceDetail.Contains($_) })
  if ($unknown.Count -gt 0) {
    throw "Unknown WinGetPackage source(s) '$($unknown -join ', ')' -- add SourceDetails for them to the -SourceDetail map passed to this function."
  }

  $line = [System.Collections.Generic.List[string]]::new()
  $line.Add('{')
  $line.Add('  "$schema": "https://aka.ms/winget-packages.schema.2.0.json",')
  $line.Add('  "Sources": [')

  $sourceNames = @($Grouped.Keys)
  for ($i = 0; $i -lt $sourceNames.Count; $i++) {
    $name = $sourceNames[$i]
    $packages = @($Grouped[$name])
    $detail = $SourceDetail[$name]

    $line.Add('    {')
    $line.Add('      "Packages": [')
    for ($j = 0; $j -lt $packages.Count; $j++) {
      $comma = if ($j -lt $packages.Count - 1) { ',' } else { '' }
      $line.Add("        { ""PackageIdentifier"": ""$($packages[$j])"" }$comma")
    }
    $line.Add('      ],')
    $line.Add('      "SourceDetails": {')
    $line.Add("        ""Argument"": ""$($detail.Argument)"",")
    $line.Add("        ""Identifier"": ""$($detail.Identifier)"",")
    $line.Add("        ""Name"": ""$($detail.Name)"",")
    $line.Add("        ""Type"": ""$($detail.Type)""")
    $line.Add('      }')
    $comma = if ($i -lt $sourceNames.Count - 1) { ',' } else { '' }
    $line.Add("    }$comma")
  }

  $line.Add('  ]')
  $line.Add('}')

  return (($line -join "`n") + "`n")
  <#
  .SYNOPSIS
  Renders a source-grouped package list as winget-packages.schema.2.0
  JSON text.

  .DESCRIPTION
  Formatted to match the hand-written style already committed in
  configurations/packages.min.import.json (2-space indent, one
  Packages entry per line, no trailing commas) instead of
  ConvertTo-Json's default multi-line-per-property expansion, so
  regenerating an unchanged input reproduces the committed file
  byte-for-byte rather than only semantically equivalently.

  Throws if $Grouped references a source with no entry in
  $SourceDetail, rather than silently emitting a Sources[] entry
  without SourceDetails -- winget needs SourceDetails to resolve a
  source, and a missing entry would produce an import.json winget
  cannot use. The error names the caller-supplied -SourceDetail map,
  not a specific caller script, so this function stays reusable by
  any caller that supplies its own source knowledge.

  .OUTPUTS
  The complete file text, LF-terminated, ending with exactly one
  trailing newline.
  #>
}

function ConvertTo-UnappliedResourceJson {
  param(
    [Parameter(Mandatory)]
    [AllowEmptyCollection()]
    [object[]] $Unapplied
  )

  return (($Unapplied | ConvertTo-Json -Depth 5 -AsArray) + "`n")
  <#
  .SYNOPSIS
  Renders the unapplied-resources list (see Split-DscResource) as
  formatted JSON text for a later execution track to read and surface
  as warnings.

  .OUTPUTS
  The complete file text, LF-terminated, ending with exactly one
  trailing newline. Always a JSON array, even for zero or one entries
  (-AsArray via the pipeline, which unrolls $Unapplied item-by-item so
  a single- or zero-element list isn't collapsed to a bare object) --
  a downstream reader never has to special-case a bare object.
  #>
}
