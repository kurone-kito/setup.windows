<#
.SYNOPSIS
Installs and pins the Unity CLI (`unity` binary), idempotently, per
configurations/runtime-versions.psd1's UnityCli entry.

This file is dot-sourced (not imported as a module) from boxstarter.ps1
-- do not add Export-ModuleMember here.
#>
Set-StrictMode -Version Latest

. (Join-Path -Path $PSScriptRoot -ChildPath 'runtime-versions.ps1')

$Script:UnityCliInstallScriptUrl = 'https://public-cdn.cloud.unity3d.com/hub/prod/cli/install.ps1'
# $env:LOCALAPPDATA is Windows-only and absent on the Linux CI runner
# that runs this file's Pester tests -- guarded so dot-sourcing this
# file doesn't fail there. Every real caller passes -InstallDir
# explicitly or runs on Windows, where LOCALAPPDATA is always set.
$Script:UnityCliInstallDir = if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA 'Unity\bin' } else { $null }

function Get-InstalledUnityCliVersion {
  if (-not (Get-Command unity -CommandType Application -ErrorAction SilentlyContinue)) {
    return @{ Found = $false; Output = ''; ExitCode = $null }
  }
  $output = (& unity --version 2>&1 | Out-String).Trim()
  return @{ Found = $true; Output = $output; ExitCode = $LASTEXITCODE }
  <#
  .SYNOPSIS
  Runs `unity --version` if the binary is on PATH. This is the only
  function in this file with a real dependency on the installed CLI,
  kept to a few lines specifically so Pester can mock this single
  function and exercise every other function's logic without a real
  Unity CLI installed.

  .OUTPUTS
  Hashtable: Found ($false if `unity` isn't on PATH at all), Output (raw
  trimmed stdout+stderr text), ExitCode ($null when Found is $false).
  #>
}

function Test-UnityCliCurrent {
  param (
    [Parameter(Mandatory)][hashtable]$Installed,
    [Parameter(Mandatory)][string]$Target
  )
  if (-not $Installed.Found -or $Installed.ExitCode -ne 0) {
    return $false
  }
  return $Installed.Output -match [regex]::Escape($Target)
  <#
  .SYNOPSIS
  Decides whether an already-installed Unity CLI already matches the
  declared Target version.

  .DESCRIPTION
  `unity --version`'s exact output format isn't documented anywhere
  found during this issue's research (Unity's own CLI reference page
  covers every other command's output but not this one) and could not
  be verified on a real Windows machine either -- see the "Not verified
  on a real machine" note in this PR. A substring match against the
  declared Target is deliberately used instead of parsing an assumed
  exact format, so this stays correct even if the real output turns out
  to look different than expected (e.g. "unity-cli 1.0.0-beta.3" or
  just "1.0.0-beta.3" both match).
  #>
}

function Invoke-UnityCliInstaller {
  param (
    [Parameter(Mandatory)][string]$Target,
    [Parameter(Mandatory)][string]$Channel,
    [string]$InstallScriptUrl = $Script:UnityCliInstallScriptUrl
  )
  $tempScript = Join-Path ([System.IO.Path]::GetTempPath()) "unity-cli-install-$([guid]::NewGuid().ToString('N')).ps1"
  try {
    try {
      Invoke-WebRequest -Uri $InstallScriptUrl -OutFile $tempScript -UseBasicParsing -ErrorAction Stop
    }
    catch {
      Write-Error "Failed to download the Unity CLI installer from ${InstallScriptUrl}: $_"
      return 1
    }
    $shell = (Get-Process -Id $PID).Path
    $process = Start-Process -FilePath $shell -ArgumentList @(
      '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $tempScript,
      '-Target', $Target, '-Channel', $Channel
    ) -NoNewWindow -Wait -PassThru
    return $process.ExitCode
  }
  finally {
    Remove-Item -Path $tempScript -Force -ErrorAction SilentlyContinue
  }
  <#
  .SYNOPSIS
  Downloads Unity's own install.ps1 and runs it to install the pinned
  Target version.

  .DESCRIPTION
  Runs install.ps1 in a SEPARATE process via Start-Process, never
  in-process (e.g. never `& [scriptblock]::Create($downloadedContent)`).
  install.ps1 itself calls `exit 1` on several failure paths -- an
  in-process scriptblock invocation confirmed empirically to terminate
  the *entire calling PowerShell process* on `exit`, not just return
  from the scriptblock, which would silently abort the rest of
  boxstarter.ps1's phases on any Unity CLI installer failure. A
  separate process confines that `exit` to the child, so its exit code
  can be inspected and handled by the caller instead.

  install.ps1's own script is not pinned by hash or version -- only the
  binary it downloads is (SHA-256, verified by install.ps1 itself). This
  is the same trust model as any curl-pipe-to-shell bootstrap (Chocolatey,
  Scoop); see docs/dsc-migration-notes.md for the recorded risk.

  The download itself is wrapped in its own try/catch (issue #98): a
  network failure (DNS, connection refused, non-2xx status) throws a
  terminating error from Invoke-WebRequest that would otherwise
  propagate uncaught past this function, past Sync-UnityCli, and into
  boxstarter.ps1's Phase 5. Caught here and turned into a non-zero
  return instead, so it flows through the same
  "$exitCode -ne 0 -> Write-Error, return" handling in Sync-UnityCli
  that an install.ps1 failure already goes through -- one failure path
  for both causes rather than two.

  .OUTPUTS
  The child process's exit code, or a non-zero value (currently 1) if
  the installer script itself could not be downloaded. Callers cannot
  distinguish a download failure from an install.ps1 failure by exit
  code value alone -- install.ps1 can itself legitimately exit 1 on
  its own failure paths -- only by whether it's zero. install.ps1 does
  not call `exit 0` on its success path, so a clean run's exit code is
  whatever a script falling off the end returns (0).
  #>
}

function Add-UnityCliToProcessPath {
  param (
    [string]$InstallDir = $Script:UnityCliInstallDir
  )
  if ([string]::IsNullOrEmpty($InstallDir)) {
    return
  }
  $current = @($env:Path -split ';' | Where-Object { $_ -ne '' })
  $target = $InstallDir.TrimEnd('\', '/')
  $alreadyPresent = $current | Where-Object {
    [string]::Equals($_.TrimEnd('\', '/'), $target, [System.StringComparison]::OrdinalIgnoreCase)
  }
  if (-not $alreadyPresent) {
    $env:Path = (@($current) + $InstallDir) -join ';'
  }
  <#
  .SYNOPSIS
  Adds the Unity CLI install directory to the *current process's*
  $env:Path.

  .DESCRIPTION
  install.ps1 updates the persistent User-scope PATH (via
  [System.Environment]::SetEnvironmentVariable(..., "User")) and
  broadcasts WM_SETTINGCHANGE, but neither reaches the environment of
  the already-running boxstarter.ps1 process -- confirmed by reading
  install.ps1's own source, which never touches $env:Path. Without
  this, a `unity` call later in the same setup run would fail even
  immediately after a successful install.

  A null/empty InstallDir (e.g. the default on a machine without
  $env:LOCALAPPDATA, such as this file's own Linux Pester run) is a
  no-op rather than an error -- there is nothing to add.
  #>
}

function Sync-UnityCli {
  param (
    [Parameter(Mandatory)][string]$ConfigPath
  )
  $config = Get-RuntimeVersionsConfig -Path $ConfigPath
  if ($null -eq $config) {
    return
  }
  if (-not $config.Contains('UnityCli') -or
    -not $config.UnityCli.Contains('Target') -or -not $config.UnityCli.Contains('Channel')) {
    Write-Error "Runtime versions config ${ConfigPath} is missing a UnityCli.Target/UnityCli.Channel entry."
    return
  }
  $unityCli = $config.UnityCli

  Add-UnityCliToProcessPath

  $installed = Get-InstalledUnityCliVersion
  if (Test-UnityCliCurrent -Installed $installed -Target $unityCli.Target) {
    Write-Host "[unity-cli] Unity CLI $($unityCli.Target) already installed -- skipping." -ForegroundColor Gray
    return
  }

  Write-Host "[unity-cli] Installing Unity CLI $($unityCli.Target) (channel: $($unityCli.Channel))..." -ForegroundColor Cyan
  $exitCode = Invoke-UnityCliInstaller -Target $unityCli.Target -Channel $unityCli.Channel
  if ($exitCode -ne 0) {
    Write-Error "Unity CLI installer exited with code ${exitCode}."
    return
  }

  Add-UnityCliToProcessPath
  Write-Host '[unity-cli] Unity CLI installation complete.' -ForegroundColor Green
  <#
  .SYNOPSIS
  Idempotent entry point: installs the Unity CLI only if it isn't
  already at the declared Target version, per
  configurations/runtime-versions.psd1's UnityCli entry.
  #>
}
