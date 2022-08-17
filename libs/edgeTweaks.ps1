<#
.SYNOPSIS
Hide the first run experience of the Edge
#>
Set-StrictMode -Version Latest
Push-Location $PSScriptRoot
Import-Module -Name ./.lib.psm1

if (Invoke-SelfWithPrivileges) {
  Pop-Location
  exit
}

if (-not $args.Count) {
  Invoke-Self
  Pop-Location
  exit
}

$edgeRegKey = 'HKCU:\SOFTWARE\Policies\Microsoft\Edge'
New-Item $edgeRegKey -Force | Out-Null
New-ItemProperty `
  -Path $edgeRegKey `
  -Name HideFirstRunExperience `
  -PropertyType DWord `
  -Value 1 `
  -Force `
  | Out-Null

Pop-Location
