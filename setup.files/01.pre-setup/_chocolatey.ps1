Set-StrictMode -Version Latest

if (Get-Command choco -ea SilentlyContinue) {
  choco upgrade -y chocolatey
}
else {
  New-Item -Path (Split-Path -Parent $profile) -ItemType directory -Force
  New-Item -Path $profile -ItemType file
  Set-ExecutionPolicy Bypass -Scope Process -Force;
  Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

  . $profile
  $ChocoInstallPath = "$($env:SystemDrive)\ProgramData\Chocolatey\bin"
  $env:Path += ";$ChocoInstallPath"
  $env:ChocolateyInstall = Convert-Path "$((Get-Command choco).path)\..\.."
  Import-Module "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
  RefreshEnv
  choco feature enable -n=useRememberedArgumentsForUpgrades
}
