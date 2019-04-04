Set-StrictMode -Version Latest
refreshenv
$env:PSModulePath += ';C:\ProgramData\Boxstarter'

Import-Module Boxstarter.Chocolatey

$ScriptFilename = 'boxstarter_tasks.ps1'
$ScriptDir = (Split-Path -Parent $MyInvocation.MyCommand.Path);
Copy-Item "$ScriptDir\02.boxstarter\$ScriptFilename" $env:tmp
Install-BoxstarterPackage -PackageName "$env:tmp\$ScriptFilename"
