Param($cred);
# [PSCredential] cannot detect on PS2.0 ??
Set-StrictMode -Version Latest

RefreshEnv
$env:PSModulePath += ';C:\ProgramData\Boxstarter'
Import-Module Boxstarter.Chocolatey

$ScriptFilename = 'boxstarter_tasks.ps1'
$ScriptDir = (Split-Path -Parent $MyInvocation.MyCommand.Path);
Copy-Item "$ScriptDir\$ScriptFilename" $env:tmp
Install-BoxstarterPackage -PackageName "$env:tmp\$ScriptFilename" -Credential $cred
