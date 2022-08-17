<#
.SYNOPSIS
Setup some apps with interactive prompts.
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

Write-Speech 'If this is your first setup, some installer may need to be interacted with to continue it; follow the instructions in the GUI to continue the process.'

choco install -y drobo-dashboard # Cannot automation

Pop-Location
