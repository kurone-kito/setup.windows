Set-StrictMode -Version Latest
refreshenv
$env:PSModulePath += ";C:\ProgramData\Boxstarter"

Import-Module Boxstarter.Chocolatey

$ScriptDir = (Split-Path -Parent $MyInvocation.MyCommand.Path);
Copy-Item "$ScriptDir\02.boxstarter\index.ps1" $env:tmp
Install-BoxstarterPackage -PackageName "$env:tmp\index.ps1"
