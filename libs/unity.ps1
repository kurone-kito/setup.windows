<#
.SYNOPSIS
Setup the Unity Editor
#>
Set-StrictMode -Version Latest
Push-Location $PSScriptRoot
Import-Module -Name ./.lib.psm1

if (Invoke-SelfWithPrivileges)
{
  Pop-Location
  exit
}

if (-not $args.Count)
{
  Invoke-Self
  Pop-Location
  exit
}

function Write-UnityHubSkippedLog
{
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

Write-Output 'Looking for Unity Hub...'

$UnityHub = $env:ProgramFiles `
| Join-Path -ChildPath 'Unity Hub' `
| Join-Path -ChildPath 'Unity Hub.exe'

if (-not (Test-Path $UnityHub))
{
  Write-UnityHubSkippedLog 'Unity Hub is not installed.'
  exit
}

Write-Output 'Enumerating installed Unity Editors...'

$versions = & $UnityHub -- --headless editors --installed | Out-String

function Install-UnityEditor
{
  param (
    [Parameter(Mandatory)][string]
    $version,

    [Parameter(Mandatory)][string]
    $changeset
  )

  if ($versions | Select-String -Pattern $version)
  {
    Write-UnityHubSkippedLog ('Unity Editor version {0} is already installed.' -f $version)
    return
  }

  $opts = '-- --headless install -v {0} -c {1} -m android -m documentation -m language-ja --cm' `
    -f $version, $changeset
  Start-Process $UnityHub -ArgumentList $opts -NoNewWindow -Wait

  <#
  .SYNOPSIS
  install the Unity Editor

  .PARAMETER version
  the version of the Unity Editor to install

  .PARAMETER changeset
  the changeset of the Unity Editor to install
  #>
}

Write-Output 'Starting Unity Hub...'
Start-Process $UnityHub -NoNewWindow -RedirectStandardOutput 'NUL'

$isSetupUnity = Read-Confirm 'To continue with the Unity setup, you will need to log in. Please login to your account in the running Unity Hub. If you are already logged in, press Y to install Unity. Otherwise, enter N to skip the Unity installation.'

if ($isSetupUnity -eq $False)
{
  Write-UnityHubSkippedLog 'canceled by user'
  exit
}

Install-UnityEditor -version '2019.4.31f1' -changeset 'bd5abf232a62'
Install-UnityEditor -version '2022.3.6f1' -changeset 'b9e6e7e9fa2d'
Install-UnityEditor -version '2022.3.22f1' -changeset '887be4894c44'

Pop-Location
