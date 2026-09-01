<#
.SYNOPSIS
Installs and updates the Cursor CLI (`cursor-agent` / `agent` binaries),
idempotently delegating to Cursor's own official install script.

This file is dot-sourced (not imported as a module) from
libs/post-install.ps1 -- do not add Export-ModuleMember here.
#>
Set-StrictMode -Version Latest

$Script:CursorCliInstallScriptUrl = 'https://cursor.com/install?win32=true'
# $env:LOCALAPPDATA is Windows-only and absent on the Linux CI runner
# that runs this file's Pester tests -- guarded so dot-sourcing this
# file doesn't fail there. Every real caller runs on Windows, where
# LOCALAPPDATA is always set.
#
# This points at the *versions* directory
# (%LocalAppData%\cursor-agent\versions), not a fixed install directory
# like CodeRabbit CLI's -- per the issue's AI-summary research, Cursor's
# installer lays binaries out under a per-version subdirectory
# (...\versions\<version>\), which this repository has not verified by
# reading the vendor script. Adding this parent directory to PATH is the
# best defensive approximation available without asserting an unverified
# exact layout; see Add-CursorCliToProcessPath below and
# docs/dsc-migration-notes.md for the full caveat.
$Script:CursorCliInstallDir = if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA 'cursor-agent\versions' } else { $null }

function Add-CursorCliToProcessPath {
  param (
    [string]$InstallDir = $Script:CursorCliInstallDir
  )
  if ([string]::IsNullOrEmpty($InstallDir)) {
    return
  }
  $current = @($env:Path -split ';' | Where-Object { $_ -ne '' })
  $target = $InstallDir.TrimEnd('\', '/')
  $seenTarget = $false
  $deduped = @(
    foreach ($entry in $current) {
      $isTarget = [string]::Equals($entry.TrimEnd('\', '/'), $target, [System.StringComparison]::OrdinalIgnoreCase)
      if ($isTarget) {
        if ($seenTarget) {
          continue
        }
        $seenTarget = $true
      }
      $entry
    }
  )
  if ($seenTarget) {
    $env:Path = $deduped -join ';'
  }
  else {
    $env:Path = (@($deduped) + $InstallDir) -join ';'
  }
  <#
  .SYNOPSIS
  Adds the Cursor CLI install directory to the *current process's*
  $env:Path.

  .DESCRIPTION
  The official installer is documented (AI-summary, unverified -- see
  docs/dsc-migration-notes.md) to persist the User-scope PATH and
  reflect that into the calling process's own $env:Path. This function
  is added defensively, mirroring
  libs/coderabbit-cli-installer.ps1's Add-CoderabbitCliToProcessPath, so
  a `cursor-agent` / `agent` call later in the same boxstarter.ps1 run
  works even if the vendor installer does not update the current
  process -- not to support a version-match check, since this installer
  does not pin or compare versions.

  Unlike CodeRabbit CLI's install directory, the default InstallDir here
  ($Script:CursorCliInstallDir) is the *versions* parent directory, not
  a directory that directly contains the executables -- the AI-summary
  research behind this issue was unable to confirm whether the real
  binaries live directly under it or one level deeper, under a
  per-version subdirectory. This function is a defensive backup, not
  the primary PATH mechanism: the vendor installer's own persistent
  User-PATH write (also unverified) is expected to reference whatever
  the correct concrete path actually is.

  A null/empty InstallDir (e.g. the default on a machine without
  $env:LOCALAPPDATA, such as this file's own Linux Pester run) is a
  no-op rather than an error -- there is nothing to add.

  Also normalizes away any pre-existing duplicate entries for
  InstallDir (case/trailing-separator insensitive), keeping the first
  occurrence's position and dropping the rest, so repeated calls
  converge on exactly one entry even if duplicates existed before this
  function's first call in the current process.
  #>
}

function Invoke-CursorCliInstaller {
  [CmdletBinding()]
  [OutputType([int])]
  param (
    [string]$InstallScriptUrl = $Script:CursorCliInstallScriptUrl
  )
  $tempScript = Join-Path ([System.IO.Path]::GetTempPath()) "cursor-cli-install-$([guid]::NewGuid().ToString('N')).ps1"
  try {
    try {
      Invoke-WebRequest -Uri $InstallScriptUrl -OutFile $tempScript -UseBasicParsing -ErrorAction Stop
    }
    catch {
      Write-Error "Failed to download the Cursor CLI installer from ${InstallScriptUrl}: $_"
      return 1
    }
    $shell = (Get-Process -Id $PID).Path
    # Start-Process -ArgumentList joins array elements with a bare
    # space and does not quote them itself (this is documented
    # Start-Process behavior, not a bug) -- an unquoted $tempScript
    # would truncate at the first space in a TEMP path containing
    # one, so it's quoted explicitly here.
    $process = Start-Process -FilePath $shell -ArgumentList @(
      '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$tempScript`""
    ) -NoNewWindow -Wait -PassThru
    return $process.ExitCode
  }
  finally {
    Remove-Item -Path $tempScript -Force -ErrorAction SilentlyContinue
  }
  <#
  .SYNOPSIS
  Downloads Cursor's own install script and runs it to install or
  update the CLI to its latest version.

  .DESCRIPTION
  Runs the installer in a SEPARATE process via Start-Process, never
  in-process -- mirrors libs/coderabbit-cli-installer.ps1's
  Invoke-CoderabbitCliInstaller and libs/unity-cli-installer.ps1's
  Invoke-UnityCliInstaller (docs/dsc-migration-notes.md): an in-process
  scriptblock invocation of downloaded content lets that script's own
  `exit` terminate the *entire calling PowerShell process*, not just
  the scriptblock, which would silently abort the rest of
  boxstarter.ps1's phases. A separate process confines that risk to the
  child, so its exit code can be inspected and handled by the caller
  instead.

  Unlike Invoke-CoderabbitCliInstaller, this function does not set any
  CI-suppression environment variable before launching the child
  process. CodeRabbit's own AI-summary research specifically named `CI`
  as the variable its installer checks to suppress an interactive login
  prompt; this issue's AI-summary research for Cursor's installer could
  not confirm whether an equivalent suppression variable exists at all,
  let alone its name. Setting an unverified environment variable (e.g.
  a generic `CI=1`) against a script this repository has not read end
  to end risks changing other unverified behavior too -- for example,
  some vendor installers skip persisting the User PATH, or alter their
  install layout, specifically when they detect a CI environment. Doing
  nothing is the conservative choice here; if this script does have an
  interactive prompt that blocks non-interactive execution, that will
  surface as a hang or non-zero exit at real invocation time and can be
  addressed then, per the issue's own documented fallback ("if
  unnecessary, leave a note in a code comment").

  install.ps1 itself is not pinned by hash or version, the same trust
  model as any curl-pipe-to-shell bootstrap (Chocolatey, Scoop,
  CodeRabbit CLI, Unity CLI); see docs/dsc-migration-notes.md for the
  recorded risk.

  The download itself is wrapped in its own try/catch (mirrors issue
  #98's Unity CLI fix and Invoke-CoderabbitCliInstaller): a network
  failure (DNS, connection refused, non-2xx status) throws a
  terminating error from Invoke-WebRequest that would otherwise
  propagate uncaught past this function and into Sync-CursorCli. Caught
  here and turned into a non-zero return instead.

  .OUTPUTS
  The child process's exit code, or a non-zero value (currently 1) if
  the installer script itself could not be downloaded. Callers cannot
  distinguish a download failure from an install script failure by exit
  code value alone -- only by whether it's zero.
  #>
}

function Sync-CursorCli {
  [CmdletBinding()]
  param ()

  Add-CursorCliToProcessPath

  Write-Host '[cursor-cli] Installing/updating Cursor CLI...' -ForegroundColor Cyan
  $exitCode = Invoke-CursorCliInstaller
  if ($exitCode -ne 0) {
    Write-Error "Cursor CLI installer exited with code ${exitCode}."
    return
  }

  Add-CursorCliToProcessPath
  Write-Host '[cursor-cli] Cursor CLI installation complete.' -ForegroundColor Green
  <#
  .SYNOPSIS
  Idempotent entry point: installs or updates the Cursor CLI to its
  latest version on every call.

  .DESCRIPTION
  Unlike libs/coderabbit-cli-installer.ps1's Sync-CoderabbitCli, this
  function does not check for any prerequisite external command before
  installing (no `git`-equivalent check) -- the issue's AI-summary
  research found Cursor's official installer has no external-command
  dependency, unlike CodeRabbit CLI's installer, which requires Git.
  Because there is no such check, this function also does not call
  libs/process-path-sync.ps1's Sync-ProcessPath: that call exists in
  Sync-CoderabbitCli solely to make its `git` Get-Command check see a
  tool installed earlier in the same process (issue #129) -- with no
  prerequisite check here, calling it would have no effect.

  Like Sync-CoderabbitCli, this function does not pin a target version
  or skip when a matching version is already installed -- Cursor CLI
  intentionally always tracks latest here (same "always update" policy
  as the VPM CLI and CodeRabbit CLI sections of
  libs/post-install.ps1), so every call re-runs the official installer
  and relies on its own idempotent staging/rollback behavior.

  No authentication step is invoked or scripted here: `cursor-agent
  login` (or its equivalent) stays a manual step for the user, the same
  boundary already drawn for CodeRabbit CLI's `coderabbit auth login`.
  #>
}
