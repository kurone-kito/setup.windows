Param([string]$User = 'vagrant', [string]$Password = 'vagrant');
Set-StrictMode -Version Latest

Push-Location .\01.pre-setup
.\index.ps1 -User $User -Password $Password
Pop-Location
