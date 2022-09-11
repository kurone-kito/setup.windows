<#
.SYNOPSIS
The libraries for setup scripts.
#>
Set-StrictMode -Version Latest

function Add-Link
{
  param(
    [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
    [System.IO.FileInfo]
    $Source,

    [Parameter(Mandatory = $true)]
    [string]
    $Destination
  )

  $FileName = $Source.Name
  $FullPath = $Source.FullName
  $Replace = Join-Path $Destination -ChildPath $FileName
  if (Test-Path -Path $Replace)
  {
    Remove-Item -Force $Replace
  }
  New-Item -Path $Destination -ItemType SymbolicLink -Name $FileName -Value $FullPath
  <#
  .SYNOPSIS
  Add a symbolic link to a file.
  .PARAMETER Source
  The source file.
  .PARAMETER Destination
  The destination directory.
  #>
}

function Add-Links
{
  param(
    [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
    [string]
    $Source,

    [Parameter(Mandatory = $true)]
    [string]
    $Destination
  )

  New-Item -Path $Destination -ItemType Directory -Force
  Get-ChildItem -Path $Source -Attributes !Directory `
  | ForEach-Object { $_ | Add-Link -Destination $Destination }
  <#
  .SYNOPSIS
  Add symbolic links to files.
  .PARAMETER Source
  The source directory.
  .PARAMETER Destination
  The destination directory.
  #>
}

function Get-IsAdmin
{
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

function Invoke-BoxstarterFromURL
{
  param(
    [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
    [string]
    $Packages
  )
  $iePath = $env:ProgramFiles `
  | Join-Path -ChildPath 'Internet Explorer' `
  | Join-Path -ChildPath 'iexplore.exe'
  [Environment]::GetFolderPath('Startup') `
  | Join-Path -ChildPath 'boxstarter-post-restart.bat' `
  | New-TouchFile
  $url = 'https://boxstarter.org/package/' + $Packages
  Start-Process $iePath -ArgumentList $url
  Out-Beep
  <#
  .SYNOPSIS
  Invoke the boxstarter from a URL.
  .PARAMETER Packages
  The package name(s).
  #>
}

function Invoke-Self
{
  $options = Join-PSOptions $MyInvocation.ScriptName
  Start-Process powershell.exe -ArgumentList $options -Wait
  <#
  .SYNOPSIS
  The function invokes the caller script on the new window.
  .INPUTS
  None.
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
  The function invokes the caller script on the new window with elevate to privileges.
  .INPUTS
  None.
  .OUTPUTS
  System.Boolean. It returns true when it should exit to the caller script.
  Otherwise, returns false.
  #>
}

function Join-PSOptions
{
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

function New-TouchFile
{
  param(
    [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
    [string]
    $Path
  )
  if (-not (Test-Path -Path $Path))
  {
    New-Item -Path $Path -ItemType File | Out-Null
  }
  <#
  .SYNOPSIS
  Create a file.
  .PARAMETER Path
  The path of the file.
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
  The function makes a beep alert.
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
  '{0} {1}' -f $question, $description | Write-Speech -stdout $false
  $choiceDescription = 'System.Management.Automation.Host.ChoiceDescription'
  $yes = New-Object $choiceDescription('&Yes', 'Continue')
  $no = New-Object $choiceDescription('&No', 'Skip')
  $choice = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
  $result = $host.ui.PromptForChoice($question, $description, $choice, 1)
  [System.Runtime.Interopservices.Marshal]::ReleaseComObject($yes) `
  | Out-Null
  [System.Runtime.Interopservices.Marshal]::ReleaseComObject($no) `
  | Out-Null
  $result -eq 0
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

function Request-Credential
{
  $msg = 'Enter your password. It''s automatic login when the system reboots during the setup process.'
  [Console]::WriteLine($msg)
  [Console]::Beep(2000, 100); [Console]::Beep(1000, 100)
  $cred = Get-Credential $env:username -Message $msg
  if ($null -eq $cred)
  {
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
  write a log message to the console
  .PARAMETER app
  the name of the app
  .PARAMETER due
  the reason why the installation is skipped
  #>
}

function Write-Speech
{
  param (
    [Parameter(ValueFromPipeline = $true, Mandatory = $true)][string]
    $text,
    [boolean]
    $stdout = $true
  )
  $sapi = New-Object -ComObject SAPI.SpVoice
  # * NOTE: required the en-US locale to be installed
  $sapi.Voice = $sapi.GetVoices('Language=409') | Select-Object -First 1
  $sapi.Speak('Attention: {0}' -f $text, 1)
  [System.Runtime.Interopservices.Marshal]::ReleaseComObject($sapi) `
  | Out-Null
  if ($stdout)
  {
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
