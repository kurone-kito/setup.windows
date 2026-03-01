<#
.SYNOPSIS
Post-install setup — handles tools that require imperative scripting
after the declarative DSC phase completes.

All steps are idempotent and safe to re-run after a reboot.
#>
Set-StrictMode -Version Latest

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

  # Node 20 (Iron)  — Maintenance LTS, EOL 2026-04-30
  # Node 22 (Jod)   — Maintenance LTS, EOL 2027-04-30
  # Node 24 (Krypton) — Active LTS, EOL 2028-04-30
  # Node 25 — Current (non-LTS), EOL 2026-06-01
  $nodeVersions = @(20, 22, 24, 25)
  foreach ($v in $nodeVersions) {
    Write-Host "  Installing Node.js v$v..." -ForegroundColor Gray
    fnm install $v
  }
  # Set the latest LTS as default
  fnm default 24
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
### VRChat SDK / VCC only supports Unity 2022.3.22f1 as of 2026-03
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

  # Unity 2022.3.22f1 — required by VRChat SDK / VCC
  Install-UnityEditor -Version '2022.3.22f1' -Changeset '887be4894c44'

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
  do {
    Start-Sleep 5
    $retries++
    docker version 2>$null | Out-Null
  } until ($? -or $retries -ge 60)

  if ($?) {
    $images = @(
      'hello-world', 'alpine', 'busybox', 'debian', 'ubuntu',
      'docker', 'docker:dind', 'docker:git',
      'node:20', 'node:20-alpine', 'node:20-slim',
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
