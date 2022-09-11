<#
.SYNOPSIS
Setup the unity
#>
Set-StrictMode -Version Latest
Push-Location $PSScriptRoot
Import-Module -Name ./.lib.psm1

function Write-MkcertSkippedLog
{
  param (
    [Parameter(Mandatory)][string]
    $due
  )
  Write-SkippedMessage -app 'mkcert' $due
  <#
  .SYNOPSIS
  write a log message to the console
  .PARAMETER due
  the reason why the installation is skipped
  #>
}

if (Get-Command mkcert -ErrorAction SilentlyContinue | Out-Null)
{
  mkcert --install
}
else
{
  Write-MkcertSkippedLog 'mkcert is not installed'
}

Pop-Location
