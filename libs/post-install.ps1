<#
.SYNOPSIS
Post-install setup — handles tools that require imperative scripting
after the declarative DSC phase completes.

All steps are idempotent and safe to re-run after a reboot.
#>
[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingInvokeExpression', '', Justification = 'fnm official env-init incantation (fnm env --use-on-cd)')]
param()

Set-StrictMode -Version Latest

###########################################################################
### Runtime version config (issue #73) — Node/Unity versions live in
### configurations/runtime-versions.psd1, not hardcoded here. See that
### file for each version's EOL/verification info and the reason it is
### pinned, and docs/dsc-migration-notes.md for the review cadence.
###########################################################################
. (Join-Path -Path $PSScriptRoot -ChildPath 'runtime-versions.ps1')
$runtimeVersionsFile = $PSScriptRoot `
  | Join-Path -ChildPath '..' `
  | Join-Path -ChildPath 'configurations' `
  | Join-Path -ChildPath 'runtime-versions.psd1'
$runtimeVersions = Get-RuntimeVersionsConfig -Path $runtimeVersionsFile
if ($null -eq $runtimeVersions) {
  return
}

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
### Node.js via fnm
###########################################################################
if (Test-CommandExists fnm) {
  Write-Host '[post-install] Setting up Node.js via fnm...' -ForegroundColor Cyan
  fnm env --use-on-cd | Out-String | Invoke-Expression

  $nodeConfig = $runtimeVersions.Node
  foreach ($entry in @($nodeConfig.Versions)) {
    Write-Host "  Installing Node.js v$($entry.Version) ($($entry.Status), EOL $($entry.Eol))..." -ForegroundColor Gray
    fnm install $entry.Version
  }
  fnm default $nodeConfig.Default
  Write-Host '[post-install] Node.js setup complete.' -ForegroundColor Green
}
else {
  Write-Warning '[post-install] fnm not found — skipping Node.js setup.'
}

###########################################################################
### git-vrc (VRChat Git integration via cargo)
###########################################################################
if (Test-CommandExists git) {
  if (Test-CommandExists cargo) {
    Write-Host '[post-install] Installing git-vrc...' -ForegroundColor Cyan
    cargo install --locked --git 'https://github.com/anatawa12/git-vrc.git'
    git vrc install --config --global
    Write-Host '[post-install] git-vrc setup complete.' -ForegroundColor Green
  }
  else {
    Write-Warning '[post-install] cargo not found — skipping git-vrc.'
  }
}
else {
  Write-Warning '[post-install] git not found — skipping git-vrc.'
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
### Unity Editor via Unity Hub CLI
### Pinned version/changeset live in configurations/runtime-versions.psd1
###########################################################################
$UnityHub = $env:ProgramFiles `
  | Join-Path -ChildPath 'Unity Hub' `
  | Join-Path -ChildPath 'Unity Hub.exe'

if (Test-Path $UnityHub) {
  Write-Host '[post-install] Setting up Unity Editor...' -ForegroundColor Cyan

  $versions = & $UnityHub -- --headless editors --installed | Out-String

  function Install-UnityEditor {
    param (
      [Parameter(Mandatory)][string]$Version,
      [Parameter(Mandatory)][string]$Changeset
    )
    if ($versions | Select-String -Pattern $Version) {
      Write-Host "  Unity $Version is already installed — skipping." -ForegroundColor Gray
      return
    }
    $opts = '-- --headless install -v {0} -c {1} -m android -m documentation -m ios -m language-ja --cm' `
      -f $Version, $Changeset
    Write-Host "  Installing Unity $Version..." -ForegroundColor Gray
    Start-Process $UnityHub -ArgumentList $opts -NoNewWindow -Wait
  }

  $unityConfig = $runtimeVersions.Unity
  Install-UnityEditor -Version $unityConfig.Version -Changeset $unityConfig.Changeset

  Write-Host '[post-install] Unity Editor setup complete.' -ForegroundColor Green
}
else {
  Write-Warning '[post-install] Unity Hub not found — skipping Unity Editor setup.'
}

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
