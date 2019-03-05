Set-StrictMode -Version Latest

if (Get-Command choco -ea SilentlyContinue) {
    Write-Output 'Chocolatey: Already installed. skip...'
}
else {
    New-Item -Path (Split-Path -Parent $profile) -ItemType directory -Force
    New-Item -Path $profile -ItemType file
    Set-ExecutionPolicy Bypass -Scope Process -Force;
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    . $profile
    $ChocoInstallPath = "$($env:SystemDrive)\ProgramData\Chocolatey\bin"
    $env:ChocolateyInstall = "$($env:SystemDrive)\ProgramData\Chocolatey"
    $env:Path += ";$ChocoInstallPath"
    choco feature enable -n=useRememberedArgumentsForUpgrades
}
