Set-StrictMode -Version Latest

# If the profile does not exist, it will be generated.
$profDir = Split-Path -Parent $profile
New-Item -ErrorAction SilentlyContinue -Path $profDir -ItemType directory
New-Item -ErrorAction SilentlyContinue -Path $profile -ItemType file

if (Get-Command choco -ea SilentlyContinue) {
  choco upgrade -y chocolatey
}
else {
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
