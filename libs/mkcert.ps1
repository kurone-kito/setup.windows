<#
.SYNOPSIS
Setup the unity
#>
Set-StrictMode -Version Latest
Set-Location $PSScriptRoot
Import-Module -Name ./.lib.psm1

function Write-MkcertSkippedLog {
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

if (-not (Get-Command mkcert)) {
  Write-MkcertSkippedLog 'mkcert is not installed'
  exit
}

mkcert --install
