<#
.SYNOPSIS
Idempotently applies the winget pin declarations in
configurations/pinned-packages.psd1 via `winget pin add`, and reports
(without touching) any pin already on the machine that isn't declared.

This file is dot-sourced (not imported as a module) from boxstarter.ps1 --
do not add Export-ModuleMember here.
#>
Set-StrictMode -Version Latest

function Get-PinnedPackagesConfig {
  param (
    [Parameter(Mandatory)][string]$Path
  )
  if (-not (Test-Path -Path $Path -PathType Leaf)) {
    Write-Error "Pinned packages config not found: $Path"
    return $null
  }
  try {
    return Import-PowerShellDataFile -Path $Path -ErrorAction Stop
  }
  catch {
    Write-Error "Failed to read pinned packages config ${Path}: $_"
    return $null
  }
  <#
  .SYNOPSIS
  Reads and parses configurations/pinned-packages.psd1, matching
  libs/runtime-versions.ps1's Get-RuntimeVersionsConfig behavior for a
  missing or unreadable file (Write-Error + $null, not a throw) --
  written as its own small function rather than reused across files,
  since the two configs are unrelated concepts that happen to share a
  read pattern.

  .OUTPUTS
  The parsed hashtable, or $null if the file is missing or malformed.
  #>
}

function Invoke-WinGetPinListCommand {
  [CmdletBinding()]
  [OutputType([hashtable])]
  param ()
  $output = & winget pin list --disable-interactivity --accept-source-agreements 2>&1 | Out-String
  return @{ Output = $output; ExitCode = $LASTEXITCODE }
  <#
  .SYNOPSIS
  The only function with a real dependency on the installed `winget`
  binary for listing pins, kept to a couple of lines so Pester can mock
  it directly -- `winget` does not resolve via Get-Command on every
  machine this repo's tests run on (this Linux dev environment
  included), and Mock cannot intercept a command name Get-Command can't
  resolve at all (same constraint documented in
  libs/unity-editor-installer.ps1's Invoke-UnityEditorsListCommand).
  #>
}

function ConvertFrom-WinGetPinListOutput {
  [CmdletBinding()]
  [OutputType([hashtable[]])]
  param (
    [Parameter(Mandatory)][AllowEmptyString()][string]$Output
  )
  $lines = $Output -split "`r?`n"
  $requiredColumns = @('Id', 'Version', 'Source', 'Pin type')
  $headerIndex = -1
  $offsets = $null
  for ($i = 0; $i -lt $lines.Count; $i++) {
    $candidateOffsets = @{}
    foreach ($name in $requiredColumns) {
      $candidateOffsets[$name] = $lines[$i].IndexOf($name)
    }
    if (@($candidateOffsets.Values | Where-Object { $_ -lt 0 }).Count -eq 0) {
      $headerIndex = $i
      $offsets = $candidateOffsets
      break
    }
  }
  if ($headerIndex -lt 0) {
    return [hashtable[]]@()
  }
  $orderedColumns = @($requiredColumns | Sort-Object { $offsets[$_] })
  $firstDataLine = $headerIndex + 2
  $lastDataLine = $lines.Count - 1
  if ($firstDataLine -gt $lastDataLine) {
    return [hashtable[]]@()
  }
  $lastColumnStart = $offsets[$orderedColumns[-1]]
  $pins = foreach ($line in $lines[$firstDataLine..$lastDataLine]) {
    if ([string]::IsNullOrWhiteSpace($line) -or $line.Length -lt $lastColumnStart) {
      continue
    }
    $values = @{}
    for ($c = 0; $c -lt $orderedColumns.Count; $c++) {
      $columnName = $orderedColumns[$c]
      $start = $offsets[$columnName]
      if ($c -lt $orderedColumns.Count - 1) {
        $end = $offsets[$orderedColumns[$c + 1]]
        $values[$columnName] = $line.Substring($start, $end - $start).Trim()
      }
      else {
        $values[$columnName] = $line.Substring($start).Trim()
      }
    }
    @{
      Id      = $values['Id']
      Source  = $values['Source']
      Version = $values['Version']
      PinType = $values['Pin type']
    }
  }
  return [hashtable[]]@($pins)
  <#
  .SYNOPSIS
  Parses `winget pin list`'s human-readable table. There is no --format
  json (or any other machine-readable output) for this command:
  confirmed against microsoft/winget-cli#3051, which was closed as a
  duplicate of #1753 and redirected scripting use to the PowerShell
  module (Microsoft.WinGet.Client) -- but that module has no pin
  cmdlet at all as of this writing (no Add-WinGetPin/Get-WinGetPin
  exists in its Cmdlets source).

  The real, current column set is `Name | Id | Version | Source | Pin
  type` (five columns, Name first) -- confirmed from two independent,
  real terminal-output reproductions pasted into microsoft/winget-cli
  issues: #4340 (2024-04, winget v1.7.10861) and #5244 (2025-02, a
  different winget install). This is NOT what an earlier issue,
  #3013 (2023-02, winget v1.5.441-preview -- the first preview build
  with pinning at all), showed: a four-column `Id | Source | Version |
  Pin type` table with no Name column. #3013's own fix
  (microsoft/winget-cli#3016, "Fix order of pin labels") only
  reordered which value landed in which of ITS FOUR columns; #4340 and
  #5244 show a materially different, five-column shape that must have
  been added later. Only Id/Version/Source/Pin type are parsed here
  (Name is human-readable-only, not needed for drift matching) --
  their offsets are read from the header row and sorted by discovered
  position, not assumed to be in a fixed order, specifically because
  #3013 already proves this table's column order has shifted across
  winget-cli versions once before.

  A missing header row (no pins currently set -- e.g.
  microsoft/winget-cli#6325 (2026-06) shows the literal message "There
  are no pins configured." -- or an output shape this parser doesn't
  recognize) degrades to an empty array rather than an error: winget
  pin list itself is not known to fail via exit code merely for having
  zero pins, so treating "no header found" as "zero pins" is the
  correct default for the common case, and is tolerant of the exact
  empty-state wording changing again without a code change here.

  .OUTPUTS
  One hashtable per pin (Id/Source/Version/PinType, all strings).
  Version is not blank for Pinning/Blocking pins in current winget
  (both #4340 and #5244 show a concrete installed-version string for
  every pin type, not just Gating) -- see Get-WinGetPinDrift, which
  does not compare Version for non-Gating pins for exactly this reason.
  #>
}

function Get-CurrentWinGetPins {
  [CmdletBinding()]
  [OutputType([hashtable[]])]
  param ()
  $result = Invoke-WinGetPinListCommand
  if ($result.ExitCode -ne 0) {
    Write-Error "'winget pin list' exited with code $($result.ExitCode): $($result.Output)"
    return [hashtable[]]@()
  }
  return [hashtable[]]@(ConvertFrom-WinGetPinListOutput -Output $result.Output)
}

function Test-PinnedPackageEntry {
  param (
    [Parameter(Mandatory)]$Entry
  )
  if ($Entry -isnot [hashtable]) {
    return $false
  }
  if (-not $Entry.Contains('Id') -or -not $Entry.Contains('Source') -or
    -not $Entry.Contains('PinType') -or -not $Entry.Contains('Reason')) {
    return $false
  }
  if ([string]::IsNullOrWhiteSpace($Entry.Id) -or [string]::IsNullOrWhiteSpace($Entry.Source) -or
    [string]::IsNullOrWhiteSpace($Entry.Reason)) {
    return $false
  }
  if ($Entry.PinType -notin @('Pinning', 'Blocking', 'Gating')) {
    return $false
  }
  if ($Entry.PinType -eq 'Gating' -and
    (-not $Entry.Contains('VersionRange') -or [string]::IsNullOrWhiteSpace($Entry.VersionRange))) {
    return $false
  }
  return $true
  <#
  .SYNOPSIS
  Validates one configurations/pinned-packages.psd1 entry. Per-entry
  (not whole-config) so one malformed entry doesn't block every other
  declared pin from being applied -- Sync-WinGetPins filters the
  declared list through this and reports what it skips, the same
  "don't let one bad item take down the whole run" posture as
  Get-InstalledUnityEditors's per-item field probing.

  $Entry is deliberately untyped, with an explicit `-isnot [hashtable]`
  check as the first condition, rather than a `[hashtable]$Entry`
  parameter: a typed parameter rejects a non-hashtable item (e.g. a
  stray string in the Pins array) via a terminating parameter-binding
  error, not a $false return -- confirmed empirically, and that error
  is NOT caught by the Where-Object scriptblock that calls this
  function, so it would abort the entire Sync-WinGetPins run instead of
  just skipping the one bad entry.

  Checks Id/Source/Reason/VersionRange for non-empty, non-whitespace
  values, not just key presence: a key present with an empty string
  (e.g. `Reason = ''`) would otherwise pass validation and reach
  Get-WinGetPinAddArguments, producing a broken `winget pin add --id ''
  ...` call that fails at runtime instead of being rejected here.
  #>
}

function Get-WinGetPinAddArguments {
  [CmdletBinding()]
  [OutputType([string[]])]
  param (
    [Parameter(Mandatory)][hashtable]$Entry
  )
  $arguments = @(
    'pin', 'add', '--id', $Entry.Id, '-s', $Entry.Source,
    '--disable-interactivity', '--accept-source-agreements'
  )
  switch ($Entry.PinType) {
    'Blocking' { $arguments += '--blocking' }
    'Gating' { $arguments += @('--version', $Entry.VersionRange) }
    'Pinning' { <# default winget pin add behavior -- no extra flag #> }
    default { throw "Unknown PinType '$($Entry.PinType)' for package '$($Entry.Id)'." }
  }
  return [string[]]$arguments
  <#
  .SYNOPSIS
  Builds the `winget pin add` argument list for one declared entry.
  Pure (no `winget` call), so this is tested directly without mocking
  Invoke-WinGetPinAddCommand at all. The `default` throw is a defensive
  guard, not a reachable branch under Test-PinnedPackageEntry's contract
  (Sync-WinGetPins only ever calls this with an already-validated
  entry) -- kept so a future PinType value added to the validator
  without a matching case here fails loudly instead of silently
  applying a plain Pinning pin.
  #>
}

function Invoke-WinGetPinAddCommand {
  [CmdletBinding()]
  [OutputType([int])]
  param (
    [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$ArgumentList
  )
  & winget @ArgumentList
  return $LASTEXITCODE
}

function Get-WinGetPinDrift {
  param (
    [Parameter(Mandatory)][AllowEmptyCollection()][hashtable[]]$Declared,
    [Parameter(Mandatory)][AllowEmptyCollection()][hashtable[]]$Current
  )
  $toAdd = @()
  $matching = @()
  $mismatched = @()
  foreach ($entry in $Declared) {
    $existing = $Current | Where-Object {
      [string]::Equals($_.Id, $entry.Id, [System.StringComparison]::Ordinal) -and
      [string]::Equals($_.Source, $entry.Source, [System.StringComparison]::Ordinal)
    } | Select-Object -First 1
    if ($null -eq $existing) {
      $toAdd += $entry
      continue
    }
    $typeMatches = [string]::Equals($existing.PinType, $entry.PinType, [System.StringComparison]::Ordinal)
    $versionMatches = if ($entry.PinType -eq 'Gating') {
      [string]::Equals($existing.Version, $entry.VersionRange, [System.StringComparison]::Ordinal)
    }
    else {
      # Pinning/Blocking carry no declared target version -- winget pin
      # list's Version column shows the currently-installed version for
      # every pin type, not just Gating, so there is nothing meaningful
      # to compare it against here.
      $true
    }
    if ($typeMatches -and $versionMatches) {
      $matching += $entry
    }
    else {
      $mismatched += @{ Declared = $entry; Current = $existing }
    }
  }
  $undeclared = $Current | Where-Object {
    $currentPin = $_
    -not ($Declared | Where-Object {
        [string]::Equals($_.Id, $currentPin.Id, [System.StringComparison]::Ordinal) -and
        [string]::Equals($_.Source, $currentPin.Source, [System.StringComparison]::Ordinal)
      })
  }
  return @{
    ToAdd      = @($toAdd)
    Matching   = @($matching)
    Mismatched = @($mismatched)
    Undeclared = @($undeclared)
  }
  <#
  .SYNOPSIS
  Classifies each declared pin against the machine's current pins
  (matched by Id+Source, ordinal): ToAdd (declared, not present at
  all), Matching (present with the declared PinType, and for Gating
  also the declared VersionRange), Mismatched (present but pinned
  differently than declared -- e.g. a plain pin where Blocking is
  declared), or Undeclared (present but not in
  configurations/pinned-packages.psd1 at all). Pure classification, no
  `winget` call -- Sync-WinGetPins only ever adds ToAdd entries; it
  never removes Undeclared pins or corrects Mismatched ones, since
  either could be silently discarding an operator's own manual `winget
  pin` choice (see docs/dsc-migration-notes.md's "why report-only"
  rationale). Both are surfaced as warnings instead.

  Version is only compared for Gating: real `winget pin list` output
  shows a concrete installed-version string in the Version column
  regardless of pin type (confirmed in microsoft/winget-cli#4340 and
  #5244), so there is no "must be blank" value to check for
  Pinning/Blocking, and comparing it would misclassify a correctly
  applied pin as Mismatched.
  #>
}

function Sync-WinGetPins {
  param (
    [Parameter(Mandatory)][string]$ConfigPath
  )
  $config = Get-PinnedPackagesConfig -Path $ConfigPath
  if ($null -eq $config) {
    return
  }
  if (-not $config.Contains('Pins')) {
    Write-Error "Pinned packages config ${ConfigPath} is missing a Pins entry."
    return
  }

  $declaredRaw = @($config.Pins)
  $declared = @($declaredRaw | Where-Object { Test-PinnedPackageEntry -Entry $_ })
  $invalidCount = $declaredRaw.Count - $declared.Count
  if ($invalidCount -gt 0) {
    $entryNoun = if ($invalidCount -eq 1) { 'entry' } else { 'entries' }
    Write-Warning "[winget-pin] Skipping $invalidCount malformed $entryNoun in ${ConfigPath} (missing Id/Source/PinType/Reason, an unknown PinType, or a Gating entry missing VersionRange)."
  }

  try {
    $current = @(Get-CurrentWinGetPins -ErrorAction Stop)
  }
  catch {
    Write-Error "Could not determine current winget pins -- aborting rather than risk re-pinning based on unknown state: $_"
    return
  }

  $drift = Get-WinGetPinDrift -Declared $declared -Current $current

  foreach ($entry in $drift.ToAdd) {
    $addArguments = Get-WinGetPinAddArguments -Entry $entry
    $exitCode = Invoke-WinGetPinAddCommand -ArgumentList $addArguments
    if ($exitCode -eq 0) {
      Write-Host "[winget-pin] Pinned $($entry.Id) ($($entry.PinType))." -ForegroundColor Gray
    }
    else {
      Write-Error "[winget-pin] 'winget pin add' for $($entry.Id) exited with code ${exitCode}."
    }
  }

  foreach ($item in $drift.Mismatched) {
    $currentDescription = $item.Current.PinType
    if ($item.Current.Version) {
      $currentDescription = "$currentDescription ($($item.Current.Version))"
    }
    $declaredDescription = $item.Declared.PinType
    if ($item.Declared.PinType -eq 'Gating') {
      $declaredDescription = "$declaredDescription ($($item.Declared.VersionRange))"
    }
    Write-Warning "[winget-pin] $($item.Declared.Id) is pinned as $currentDescription, not the declared $declaredDescription -- left as-is, not corrected."
  }

  foreach ($pin in $drift.Undeclared) {
    $pinDescription = "$($pin.PinType)"
    if ($pin.Version) {
      $pinDescription = "$pinDescription $($pin.Version)"
    }
    Write-Warning "[winget-pin] Undeclared pin found (not in ${ConfigPath}, left as-is): $($pin.Id) ($($pin.Source), $pinDescription)."
  }

  if ($drift.ToAdd.Count -eq 0) {
    Write-Host '[winget-pin] No missing declared pins to add.' -ForegroundColor Gray
  }
  <#
  .SYNOPSIS
  Idempotent entry point: adds any pin declared in
  configurations/pinned-packages.psd1 that isn't already set, and
  reports (Write-Warning, never modifies) any pin that's mismatched or
  undeclared. Safe to call every run -- a second call with nothing
  changed on the machine adds nothing (ToAdd is empty once every
  declared pin is present and matching).

  Uses Write-Error + return (not throw) on its own internal failure
  paths, matching libs/unity-cli-installer.ps1's Sync-UnityCli
  convention: unlike libs/unity-editor-installer.ps1's Sync-UnityEditor
  (issue #74), there is no acceptance-criterion here requiring this
  step specifically to halt the entire boxstarter.ps1 run -- `winget`
  itself is already an unconditional prerequisite for every earlier
  phase of that script (Phase 2-4 call it directly with no availability
  guard), so adding a hard-stop just for the pin step would be new,
  inconsistent behavior this issue never asked for.
  #>
}
