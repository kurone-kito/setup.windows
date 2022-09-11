<#
.SYNOPSIS
The entrypoint of the setup script.
#>
Set-StrictMode -Version Latest
Push-Location $PSScriptRoot

Write-Host 'Launched the additonal setup script. Continue...'

./mkcert.ps1
./choco-with-interactive.ps1
./unity.ps1

if (-not (Test-Path -Path C:\vagrant))
{
  ./docker.ps1
}

Pop-Location
