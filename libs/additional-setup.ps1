<#
.SYNOPSIS
The entrypoint of the setup script.
#>
Set-StrictMode -Version Latest
Set-Location $PSScriptRoot

Write-Host 'Launched the additonal setup script. Continue...'

./unity.ps1
