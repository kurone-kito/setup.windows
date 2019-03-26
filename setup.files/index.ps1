Set-StrictMode -Version Latest

[string]$User = Read-Host '[Auto Login] username:'
[string]$Password = Read-Host '[Auto Login] password:'

.\01.pre-setup.ps1 -User $User -Password $Password
.\02.boxstarter.ps1
