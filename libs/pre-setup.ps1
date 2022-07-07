<#
.SYNOPSIS
The entrypoint of the setup script.
#>
Set-StrictMode -Version Latest
Set-Location $PSScriptRoot

Write-Host 'Launched the setup script. Continue...'

$progressFile = Join-Path $env:TEMP 'kurone-kito.setup.windows.tmp';
New-Item -Type File $progressFile -Force

Get-ChildItem -Recurse *.ps1 | Unblock-File

./profile.ps1
./boxstarter.ps1
./install.ps1
