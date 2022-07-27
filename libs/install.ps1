<#
.SYNOPSIS
Launch some installation script with the Boxstarter
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

$cred = Request-Credential
if (-not $cred) {
  exit
}

$env:KITO_SETUP_GUID = New-Guid
$src = Join-Path '..' 'boxstarter.ps1'
$dst = Join-Path $env:TEMP $('kito_setup_{0}.ps1' -f $env:KITO_SETUP_GUID)
Copy-Item -Path $src -Destination $dst

Install-BoxstarterPackage -PackageName $dst -Credential $cred
pause
