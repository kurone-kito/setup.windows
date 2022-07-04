<#
.SYNOPSIS
installation script of the Boxstarter
#>
Set-StrictMode -Version Latest
Set-Location $PSScriptRoot
Import-Module -Name ./.lib.psm1

if (Invoke-SelfWithPrivileges) {
  exit
}

if (-not $args.Count) {
  Invoke-Self
  exit
}

function Write-SkippedMessage {
  param (
    [Parameter(Mandatory)][string]
    $due
  )
  Write-Host "Skip installation of Unity Editor: ${due}"
  <#
  .SYNOPSIS
  write a log message to the console
  .PARAMETER due
  the reason why the installation is skipped
  #>
}


$UnityHub = [IO.Path]::Combine($env:ProgramFiles, 'Unity Hub', 'Unity Hub.exe')
if (-not (Test-Path $UnityHub)) {
  Write-SkippedMessage 'Unity Hub is not installed.'
  exit
}

$version = '2019.4.31f1'
$changeset = 'bd5abf232a62'
$versions = & $UnityHub -- --headless editors --installed | Out-String
if (-not ($versions | Select-String -Pattern $version)) {
  Write-SkippedMessage "Unity Editor version ${version} is already installed."
  exit
}

Start-Process $UnityHub

$isSetupUnity = Out-Confirm 'To continue with the Unity setup, you will need to log in. Please login to your account in the running Unity Hub. If you are already logged in, press Y to install Unity. Otherwise, enter N to skip the Unity installation.'

if ($isSetupUnity -ne $True) {
  Write-SkippedMessage "canceled by user"
  exit
}

(& $UnityHub -- --headless install --version $version `
  --changeset $changeset --childModules --module android `
  --module documentation --module language-ja) -or $true
