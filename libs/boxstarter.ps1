<#
.SYNOPSIS
installation script of the Boxstarter
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

if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
  . {
    Invoke-WebRequest -useb https://boxstarter.org/bootstrapper.ps1
  } | Invoke-Expression;
  Get-Boxstarter -Force
}
choco upgrade -y boxstarter
