Set-StrictMode -Version Latest

if (Get-Command choco -ea SilentlyContinue) {
  choco upgrade -y chocolatey
}
else {
  New-Item -Path (Split-Path -Parent $profile) -ItemType directory -Force
  New-Item -ErrorAction Ignore -Path $profile -ItemType file
  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process
  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

  [System.Net.ServicePointManager]::SecurityProtocol = `
    [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
  $client = New-Object System.Net.WebClient
  $installer = $client.DownloadString('https://chocolatey.org/install.ps1')
  Invoke-Expression $installer

  . $profile
  $ChocoInstallPath = "$($env:SystemDrive)\ProgramData\Chocolatey\bin"
  $env:Path += ";$ChocoInstallPath"
  $env:ChocolateyInstall = Convert-Path "$((Get-Command choco).path)\..\.."
  Import-Module "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
  RefreshEnv
  choco feature enable -n=useRememberedArgumentsForUpgrades
}
