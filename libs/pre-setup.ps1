<#
.SYNOPSIS
The entrypoint of the setup script.
#>
Set-StrictMode -Version Latest
Set-Location $PSScriptRoot

Write-Host 'Launched the setup script. Continue...'

$runningFile = Join-Path $env:TEMP 'kurone-kito.setup.windows.tmp';
New-Item -Type File $runningFile -Force

./profile.ps1
./boxstarter.ps1
./install.ps1
