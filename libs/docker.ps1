<#
.SYNOPSIS
Setup the Docker desktop
#>
Set-StrictMode -Version Latest
Set-Location $PSScriptRoot
Import-Module -Name ./.lib.psm1

if (Invoke-SelfWithPrivileges) {
  exit
}

if (-not $args.Count) {
  Invoke-Self
  exit
}

function Write-DockerSkippedLog {
  param (
    [Parameter(Mandatory)][string]
    $due
  )
  Write-SkippedMessage -app 'Docker Desktop' $due
  <#
  .SYNOPSIS
  write a log message to the console
  .PARAMETER due
  the reason why the installation is skipped
  #>
}

$DockerDesktop = [IO.Path]::Combine($env:ProgramFiles, 'Docker', 'Docker', 'Docker Desktop.exe')

if (-not (Test-Path $DockerDesktop)) {
  Write-SkippedMessage 'Docker Desktop is not installed.'
  exit
}

Write-Speech 'If this is your first setup, Docker may need to be interacted with to continue it; follow the instructions in the GUI to continue the process.'

Start-Process $DockerDesktop

do {
  sleep 5
  docker version | Out-Null
} until ($?)

Write-Information 'Installing some containers for Docker.'
Write-Warning 'DO NOT CHANGE the settings of Docker Desktop on this setup running.'

docker pull hello-world
docker pull alpine
docker pull busybox
docker pull debian
docker pull ubuntu
docker pull docker
docker pull docker:dind
docker pull docker:git
docker pull node:14
docker pull node:14-alpine
docker pull node:14-bullseye-slim
docker pull node:16
docker pull node:16-alpine
docker pull node:16-bullseye-slim
docker pull node:18
docker pull node:18-alpine
docker pull node:18-slim
docker pull gitlab/gitlab-runner
docker pull ghcr.io/catthehacker/ubuntu:act-22.04
docker pull ghcr.io/catthehacker/ubuntu:act-latest

# ! Commented out because the container is too lerge!
# docker pull ghcr.io/catthehacker/ubuntu:full-20.04
# docker pull ghcr.io/catthehacker/ubuntu:full-latest