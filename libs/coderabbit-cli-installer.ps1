<#
.SYNOPSIS
Installs and updates the CodeRabbit CLI (`coderabbit` / `cr` binaries),
idempotently delegating to CodeRabbit's own official install script.

This file is dot-sourced (not imported as a module) from
libs/post-install.ps1 -- do not add Export-ModuleMember here.
#>
Set-StrictMode -Version Latest

$Script:CoderabbitCliInstallScriptUrl = 'https://cli.coderabbit.ai/install.ps1'
# $env:LOCALAPPDATA is Windows-only and absent on the Linux CI runner
# that runs this file's Pester tests -- guarded so dot-sourcing this
# file doesn't fail there. Every real caller runs on Windows, where
# LOCALAPPDATA is always set.
$Script:CoderabbitCliInstallDir = if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA 'Programs\coderabbit' } else { $null }

function Add-CoderabbitCliToProcessPath {
  param (
    [string]$InstallDir = $Script:CoderabbitCliInstallDir
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
  Adds the CodeRabbit CLI install directory to the *current process's*
  $env:Path.

  .DESCRIPTION
  The official install.ps1 is documented to persist the user-scope PATH
  (per docs.coderabbit.ai/cli/windows), but -- unlike Unity's
  install.ps1, whose PATH-update mechanics were confirmed by reading
  its source end to end -- whether it also touches the calling
  process's own $env:Path was not independently verified from
  CodeRabbit's script source (see docs/dsc-migration-notes.md). This
  function is added defensively so a `coderabbit` / `cr` call later in
  the same boxstarter.ps1 run works even if it does not -- not to
  support a version-match check, since this installer does not pin or
  compare versions.

  A null/empty InstallDir (e.g. the default on a machine without
  $env:LOCALAPPDATA, such as this file's own Linux Pester run) is a
  no-op rather than an error -- there is nothing to add.
  #>
}

function Invoke-CoderabbitCliInstaller {
  [CmdletBinding()]
  [OutputType([int])]
  param (
    [string]$InstallScriptUrl = $Script:CoderabbitCliInstallScriptUrl
  )
  $tempScript = Join-Path ([System.IO.Path]::GetTempPath()) "coderabbit-cli-install-$([guid]::NewGuid().ToString('N')).ps1"
  try {
    try {
      Invoke-WebRequest -Uri $InstallScriptUrl -OutFile $tempScript -UseBasicParsing -ErrorAction Stop
    }
    catch {
      Write-Error "Failed to download the CodeRabbit CLI installer from ${InstallScriptUrl}: $_"
      return 1
    }
    $originalCi = $env:CI
    try {
      # Suppresses the installer's interactive login prompt (unverified
      # AI-summary behavior of the vendor script; not read from its
      # source directly, see docs/dsc-migration-notes.md). Scoped to
      # this call only -- CODERABBIT_API_KEY is deliberately never set
      # here, so auth stays a manual post-install step for the user.
      $env:CI = '1'
      $shell = (Get-Process -Id $PID).Path
      $process = Start-Process -FilePath $shell -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $tempScript
      ) -NoNewWindow -Wait -PassThru
      return $process.ExitCode
    }
    finally {
      if ($null -eq $originalCi) {
        Remove-Item -Path Env:\CI -ErrorAction SilentlyContinue
      }
      else {
        $env:CI = $originalCi
      }
    }
  }
  finally {
    Remove-Item -Path $tempScript -Force -ErrorAction SilentlyContinue
  }
  <#
  .SYNOPSIS
  Downloads CodeRabbit's own install.ps1 and runs it to install or
  update the CLI to its latest version.

  .DESCRIPTION
  Runs install.ps1 in a SEPARATE process via Start-Process, never
  in-process -- mirrors libs/unity-cli-installer.ps1's
  Invoke-UnityCliInstaller and its documented reason
  (docs/dsc-migration-notes.md): an in-process scriptblock invocation
  of downloaded content lets that script's own `exit` terminate the
  *entire calling PowerShell process*, not just the scriptblock, which
  would silently abort the rest of boxstarter.ps1's phases. A separate
  process confines that risk to the child, so its exit code can be
  inspected and handled by the caller instead.

  install.ps1's own script is not pinned by hash or version, the same
  trust model as any curl-pipe-to-shell bootstrap (Chocolatey, Scoop);
  see docs/dsc-migration-notes.md for the recorded risk.

  The download itself is wrapped in its own try/catch (mirrors issue
  #98's Unity CLI fix): a network failure (DNS, connection refused,
  non-2xx status) throws a terminating error from Invoke-WebRequest
  that would otherwise propagate uncaught past this function and into
  Sync-CoderabbitCli. Caught here and turned into a non-zero return
  instead.

  .OUTPUTS
  The child process's exit code, or a non-zero value (currently 1) if
  the installer script itself could not be downloaded. Callers cannot
  distinguish a download failure from an install.ps1 failure by exit
  code value alone -- only by whether it's zero.
  #>
}

function Sync-CoderabbitCli {
  [CmdletBinding()]
  param ()

  if ($null -eq (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Warning '[coderabbit-cli] git not found -- skipping CodeRabbit CLI.'
    return
  }

  Add-CoderabbitCliToProcessPath

  Write-Host '[coderabbit-cli] Installing/updating CodeRabbit CLI...' -ForegroundColor Cyan
  $exitCode = Invoke-CoderabbitCliInstaller
  if ($exitCode -ne 0) {
    Write-Error "CodeRabbit CLI installer exited with code ${exitCode}."
    return
  }

  Add-CoderabbitCliToProcessPath
  Write-Host '[coderabbit-cli] CodeRabbit CLI installation complete.' -ForegroundColor Green
  <#
  .SYNOPSIS
  Idempotent entry point: installs or updates the CodeRabbit CLI to its
  latest version on every call.

  .DESCRIPTION
  Checks for `git` itself (the official installer's own prerequisite)
  rather than relying on a caller-side guard the way the dotnet/mkcert
  sections of libs/post-install.ps1 do -- this keeps the check
  independently testable via
  tests/powershell/coderabbit-cli-installer.Tests.ps1 without dot-
  sourcing post-install.ps1's Test-CommandExists helper.

  Unlike libs/unity-cli-installer.ps1's Sync-UnityCli, this function
  does not pin a target version or skip when a matching version is
  already installed -- CodeRabbit CLI intentionally always tracks
  latest here (same "always update" policy as the VPM CLI section of
  libs/post-install.ps1), so every call re-runs the official installer
  and relies on its own idempotent staging/rollback behavior.
  #>
}
