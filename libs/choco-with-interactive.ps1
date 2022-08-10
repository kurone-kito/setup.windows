<#
.SYNOPSIS
Setup some apps with interactive prompts.
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

Write-Speech 'If this is your first setup, some installer may need to be interacted with to continue it; follow the instructions in the GUI to continue the process.'

choco install -y drobo-dashboard # Cannot automation
