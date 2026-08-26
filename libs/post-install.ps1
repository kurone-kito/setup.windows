<#
.SYNOPSIS
Post-install setup — handles tools that require imperative scripting
after the declarative DSC phase completes.

All steps are idempotent and safe to re-run after a reboot.
#>
param()

Set-StrictMode -Version Latest

###########################################################################
### Runtime version config (issue #73) — Unity versions live in
### configurations/runtime-versions.psd1, not hardcoded here. See that
### file for each version's EOL/verification info and the reason it is
### pinned, and docs/dsc-migration-notes.md for the review cadence.
###
### Only the path is needed here -- Sync-UnityEditor (below) loads and
### validates the file itself (non-terminating error, no throw, on a
### missing/malformed file), so parsing it a second time up front would
### only make an unrelated config problem skip VPM CLI / Vagrant /
### mkcert / Docker too, not just the Unity step that actually needs it.
###########################################################################
$runtimeVersionsFile = $PSScriptRoot `
  | Join-Path -ChildPath '..' `
  | Join-Path -ChildPath 'configurations' `
  | Join-Path -ChildPath 'runtime-versions.psd1'

###########################################################################
### Helper — correct command existence check (fixes the Out-Null bug)
###########################################################################
function Test-CommandExists {
  param (
    [Parameter(Mandatory)][string]$Name
  )
  $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
  <#
  .SYNOPSIS
  Returns $true if a command exists on PATH, $false otherwise.
  This avoids the historic `Get-Command ... | Out-Null` bug where the
  pipeline always evaluates to $null ($false).
  #>
}

###########################################################################
### VRChat Creator Companion CLI (dotnet tool)
###########################################################################
if (Test-CommandExists dotnet) {
  Write-Host '[post-install] Installing VRChat VPM CLI...' -ForegroundColor Cyan
  dotnet tool install --global vrchat.vpm.cli 2>$null
  dotnet tool update --global vrchat.vpm.cli
  Write-Host '[post-install] VPM CLI setup complete.' -ForegroundColor Green
}
else {
  Write-Warning '[post-install] dotnet not found — skipping VPM CLI.'
}

###########################################################################
### CodeRabbit CLI — no winget package; official installer requires Git
### (issue #126). See libs/coderabbit-cli-installer.ps1 for the
### install.ps1 download/execution details and docs/dsc-migration-notes.md
### for the recorded remote-script-execution risk.
###########################################################################
if (Test-CommandExists git) {
  . (Join-Path -Path $PSScriptRoot -ChildPath 'coderabbit-cli-installer.ps1')
  Sync-CoderabbitCli
}
else {
  Write-Warning '[post-install] git not found — skipping CodeRabbit CLI.'
}

###########################################################################
### Vagrant plugins
###########################################################################
if (Test-CommandExists vagrant) {
  Write-Host '[post-install] Setting up Vagrant plugins...' -ForegroundColor Cyan
  $installedPlugins = vagrant plugin list | Out-String
  @('vagrant-reload') `
    | Where-Object { $installedPlugins -notlike ('*{0}*' -f $_) } `
    | ForEach-Object { vagrant plugin install $_ }
  vagrant plugin update
  Write-Host '[post-install] Vagrant plugins complete.' -ForegroundColor Green
}

###########################################################################
### mkcert — local CA for development
###########################################################################
if (Test-CommandExists mkcert) {
  Write-Host '[post-install] Setting up mkcert local CA...' -ForegroundColor Cyan
  mkcert --install
  Write-Host '[post-install] mkcert setup complete.' -ForegroundColor Green
}
else {
  Write-Warning '[post-install] mkcert not found — skipping local CA setup.'
}

###########################################################################
### Unity Editor via the Unity CLI (`unity install`)
### Pinned version/changeset/modules live in
### configurations/runtime-versions.psd1. Installed and verified by
### libs/unity-editor-installer.ps1 -- see docs/dsc-migration-notes.md
### for why this replaced Unity Hub's unofficial `-- --headless`
### interface (issue #74). Unity Hub itself remains a declared package
### (configurations/packages.dsc.yaml) since VRChat Creator Companion
### may rely on Hub recognizing installed Editors -- only the Editor
### install path moved.
###########################################################################
. (Join-Path -Path $PSScriptRoot -ChildPath 'unity-editor-installer.ps1')
Sync-UnityEditor -ConfigPath $runtimeVersionsFile

###########################################################################
### Docker Desktop — start and pull base images
### (skipped inside Vagrant VMs)
###########################################################################
$DockerDesktop = $env:ProgramFiles `
  | Join-Path -ChildPath Docker `
  | Join-Path -ChildPath Docker `
  | Join-Path -ChildPath 'Docker Desktop.exe'

if ((Test-Path $DockerDesktop) -and -not (Test-Path 'C:\vagrant')) {
  Write-Host '[post-install] Starting Docker Desktop and pulling images...' -ForegroundColor Cyan

  Start-Process $DockerDesktop
  $retries = 0
  $dockerReady = $false
  do {
    Start-Sleep 5
    $retries++
    docker version 2>$null | Out-Null
    $dockerReady = $LASTEXITCODE -eq 0
  } until ($dockerReady -or $retries -ge 60)

  if ($dockerReady) {
    $images = @(
      'hello-world', 'alpine', 'busybox', 'debian', 'ubuntu',
      'docker', 'docker:dind', 'docker:git',
      'node:22', 'node:22-alpine', 'node:22-slim',
      'node:24', 'node:24-alpine', 'node:24-slim'
    )
    foreach ($img in $images) {
      Write-Host "  Pulling $img..." -ForegroundColor Gray
      docker pull $img
    }
    Write-Host '[post-install] Docker images pulled.' -ForegroundColor Green
  }
  else {
    Write-Warning '[post-install] Docker Desktop did not start within timeout — skipping image pulls.'
  }
}

Write-Host '[post-install] All post-install steps complete.' -ForegroundColor Green
