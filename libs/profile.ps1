<#
.SYNOPSIS
#>
Set-StrictMode -Version Latest
Set-Location $PSScriptRoot

Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# We temporarily set the same execution policy as CurrentUser
# and then reconfigured it to prevent warnings.
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process

# If the profile does not exist, it will be generated.
$profDir = Split-Path -Parent $profile
New-Item -ErrorAction SilentlyContinue -Path $profDir -ItemType directory
New-Item -ErrorAction SilentlyContinue -Path $profile -ItemType file
