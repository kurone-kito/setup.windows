<#
.SYNOPSIS
The libraries for setup scripts.
#>
Set-StrictMode -Version Latest

function Get-Options {
  param (
    [Parameter(Mandatory)][string]
    # Specifies the filename.
    $fileName
  )
  '-ExecutionPolicy Bypass -NoLogo -File "{0}" 1' -f $fileName
  <#
  .SYNOPSIS
  The function gets the options on PowerShell execution.
  .OUTPUTS
  System.String. The options.
  #>
}

function Get-IsAdmin {
  $user = [System.Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = [Security.Principal.WindowsPrincipal]$user
  $principal.IsInRole('Administrators')
  <#
  .SYNOPSIS
  The function gets whether the current user has privileges.
  .INPUTS
  None.
  .OUTPUTS
  System.Boolean. Whether the current user has privileges.
  #>
}

function Invoke-Self {
  $options = Get-Options $MyInvocation.ScriptName
  Start-Process powershell.exe -ArgumentList $options -Wait
  <#
  .SYNOPSIS
  The function invokes the caller script on the new window.
  .INPUTS
  None.
  #>
}

function Invoke-SelfWithPrivileges {
  if (Get-IsAdmin) {
    return $false
  }
  [Console]::WriteLine('Please elevate to privileges for installing an app')
  $options = Get-Options $MyInvocation.ScriptName
  Start-Process powershell.exe -ArgumentList $options -Wait -Verb RunAs
  return $true
  <#
  .SYNOPSIS
  The function invokes the caller script on the new window with elevate to privileges.
  .INPUTS
  None.
  .OUTPUTS
  System.Boolean. It returns true when it should exit to the caller script.
  Otherwise, returns false.
  #>
}

function Read-Confirm {
  param (
    [Parameter(Mandatory)][string]
    $question,
    [string]
    $description = ''
  )
  Write-Speech ($question + ' ' + $description) -stdout $false
  $choiceDescription = 'System.Management.Automation.Host.ChoiceDescription'
  $yes = new-object $choiceDescription('&Yes', 'Continue')
  $no = new-object $choiceDescription('&No', 'Skip')
  $choice = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
  $result = $host.ui.PromptForChoice($question, $description, $choice, 1)
  if ($result -eq 0) {
    $true
  } else {
    $false
  }
  <#
  .SYNOPSIS
  Prompts the user to confirm an action.
  .PARAMETER question
  The question to ask the user.
  .PARAMETER description
  The description of the question.
  .OUTPUTS
  true if the user confirmed, false if they did not.
  #>
}

function Request-Credential {
  $msg = 'Enter your password. It''s used for automatic login when the system reboots during the setup process.'
  [Console]::WriteLine($msg)
  $cred = Get-Credential $env:username -Message $msg
  if ($null -eq $cred) {
    [Console]::WriteLine('Abort.')
  }
  $cred
  <#
  .SYNOPSIS
  The function shows prompt and requests input the credential information.
  .INPUTS
  None.
  .OUTPUTS
  System.Management.Automation.PSCredential.
  It returns the credential information or null when user
  #>
}

function Write-SkippedMessage {
  param (
    [Parameter(Mandatory)][string]
    $app,
    [Parameter(ValueFromPipeline = $true, Mandatory = $true)][string]
    $due
  )
  'Skip installation of {0}: {1}' -f $app, $due | Write-Host
  <#
  .SYNOPSIS
  write a log message to the console
  .PARAMETER app
  the name of the app
  .PARAMETER due
  the reason why the installation is skipped
  #>
}

function Write-Speech {
  param (
    [Parameter(Mandatory)][string]
    $text,
    [boolean]
    $stdout = $true
  )
  $sapi = New-Object -ComObject SAPI.SpVoice
  # * NOTE: required the en-US locale to be installed
  $sapi.Voice = $sapi.GetVoices("Language=409") | Select-Object -First 1
  $sapi.Speak('Attention: ' + $text, 1)
  if ($stdout) {
    Write-Warning $text
  }
  <#
  .SYNOPSIS
  play text by voice
  NOTE: required the en-US locale to be installed
  .PARAMETER text
  The text to be played.
  .PARAMETER stdout
  whether to output the text to the console
  .OUTPUTS
  #>
}

Export-ModuleMember -Function *
