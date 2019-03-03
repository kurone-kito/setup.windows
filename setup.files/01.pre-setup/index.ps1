Param([string]$User = 'vagrant', [string]$Password = 'vagrant');
Set-StrictMode -Version Latest

.\_auto-logon.ps1 -User $User -Password $Password
.\_virtualbox.ps1
.\_chocolatey.ps1
.\_boxstarter.ps1
