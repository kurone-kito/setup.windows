<#
.SYNOPSIS
Setup the Unity Editor
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

function Write-UnityHubSkippedLog {
  param (
    [Parameter(Mandatory)][string]
    $due
  )
  Write-SkippedMessage -app 'Unity Editor' $due
  <#
  .SYNOPSIS
  write a log message to the console
  .PARAMETER due
  the reason why the installation is skipped
  #>
}

$UnityHub = [IO.Path]::Combine($env:ProgramFiles, 'Unity Hub', 'Unity Hub.exe')
if (-not (Test-Path $UnityHub)) {
  Write-UnityHubSkippedLog 'Unity Hub is not installed.'
  exit
}

$version = '2019.4.31f1'
$changeset = 'bd5abf232a62'
$versions = & $UnityHub -- --headless editors --installed | Out-String
if ($versions | Select-String -Pattern $version) {
  Write-UnityHubSkippedLog ('Unity Editor version {0} is already installed.' -f $version)
  exit
}

Start-Process $UnityHub -NoNewWindow -RedirectStandardOutput 'NUL'

$isSetupUnity = Read-Confirm 'To continue with the Unity setup, you will need to log in. Please login to your account in the running Unity Hub. If you are already logged in, press Y to install Unity. Otherwise, enter N to skip the Unity installation.'

if ($isSetupUnity -ne $True) {
  Write-UnityHubSkippedLog 'canceled by user'
  exit
}

$opts = '-- --headless install -v {0} -c {1} -m android -m documentation -m language-ja --cm' `
  -f $version, $changeset
Start-Process $UnityHub -ArgumentList $opts -NoNewWindow -Wait
