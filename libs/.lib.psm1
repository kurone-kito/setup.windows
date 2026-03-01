<#
.SYNOPSIS
Shared utility functions for setup scripts.
#>
Set-StrictMode -Version Latest

function Get-IsAdmin
{
  $user = [System.Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = [Security.Principal.WindowsPrincipal]$user
  $principal.IsInRole('Administrators')
  <#
  .SYNOPSIS
  Returns whether the current user has administrator privileges.
  .OUTPUTS
  System.Boolean.
  #>
}

function Invoke-Self
{
  $options = Join-PSOptions $MyInvocation.ScriptName
  Start-Process powershell.exe -ArgumentList $options -Wait
  <#
  .SYNOPSIS
  Re-launches the calling script in a new window.
  #>
}

function Invoke-SelfWithPrivileges
{
  if (Get-IsAdmin)
  {
    return $false
  }
  [Console]::WriteLine('Please elevate to privileges for installing an app')
  $options = Join-PSOptions $MyInvocation.ScriptName
  Start-Process powershell.exe -ArgumentList $options -Wait -Verb RunAs
  return $true
  <#
  .SYNOPSIS
  Re-launches the calling script elevated. Returns $true if the caller
  should exit (because a new elevated process was started).
  .OUTPUTS
  System.Boolean.
  #>
}

function Join-PSOptions
{
  param (
    [Parameter(Mandatory)][string]
    $fileName
  )
  '-ExecutionPolicy Bypass -NoLogo -File "{0}" 1' -f $fileName
  <#
  .SYNOPSIS
  Builds the PowerShell execution options string.
  .OUTPUTS
  System.String.
  #>
}

function Out-Beep
{
  if ([System.Environment]::OSVersion.Platform -eq 'Win32NT')
  {
    [Console]::Beep(2000, 100)
    [Console]::Beep(1000, 100)
  }
  else
  {
    Write-Host "`a"
  }
  <#
  .SYNOPSIS
  Emits a short beep alert.
  #>
}

function Read-Confirm
{
  param (
    [Parameter(Mandatory)][string]
    $question,
    [string]
    $description = ''
  )
  $choiceDescription = 'System.Management.Automation.Host.ChoiceDescription'
  $yes = New-Object $choiceDescription('&Yes', 'Continue')
  $no = New-Object $choiceDescription('&No', 'Skip')
  $choice = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
  $result = $host.ui.PromptForChoice($question, $description, $choice, 1)
  return $result -eq 0
  <#
  .SYNOPSIS
  Prompts the user to confirm an action (Yes/No).
  .OUTPUTS
  System.Boolean. $true if confirmed, $false otherwise.
  #>
}

function Write-SkippedMessage
{
  param (
    [Parameter(Mandatory)][string]
    $app,
    [Parameter(ValueFromPipeline = $true, Mandatory = $true)][string]
    $due
  )
  'Skip installation of {0}: {1}' -f $app, $due | Write-Host
  <#
  .SYNOPSIS
  Logs a message about a skipped installation step.
  #>
}

Export-ModuleMember -Function *
