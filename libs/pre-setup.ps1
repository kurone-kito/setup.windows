<#
.SYNOPSIS
The entrypoint of the setup script.
#>
Set-StrictMode -Version Latest
Push-Location $PSScriptRoot
Import-Module -Name ./.lib.psm1

Write-Host 'Launched the setup script. Continue...'

./edgeTweaks.ps1
'url?https://raw.githubusercontent.com/kurone-kito/setup.windows/{0}/boxstarter.ps1' `
  -f 'test' `
| Invoke-BoxstarterFromURL

Pop-Location
