Set-StrictMode -Version Latest

# Functions ###############################################################
function Deploy-Launcher() {
  param(
    [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
    [string]
    $ProjectHome
  )

  $launcherName = 'sw-launcher.cmd'
  $launcherPath = $ProjectHome `
    | Join-Path -ChildPath t `
    | Join-Path -ChildPath $launcherName
  Copy-Item $launcherPath ([Environment]::GetFolderPath('Startup')) -Force

    <#
    .SYNOPSIS
    deploy a launcher file to the startup folder
    .DESCRIPTION
    It is a roundabout way that WinRM cannot interfere with the GUI and
    will run as a background process even if the browser is launched
    directly.
    .PARAMETER ProjectHome
    the project home directory
    #>
}

function Expand-SystemDisk() {
  $regexp = 'disk (\d+)\s+(\w+)\s+(\d+ .?b)\s+(\d+ .?b)  (.*)'
  $diskList = 'list disk' | diskpart | Select-String -Pattern $regexp
  $matchGroups = $diskList[0] `
    | Select-Object -ExpandProperty Matches `
    | Select-Object -ExpandProperty Groups
  $rawFree = $matchGroups[4] `
    | Select-Object -ExpandProperty Value `
    | Select-String -Pattern "^[0-9]+" `
    | Select-Object -ExpandProperty Matches `
    | Select-Object -ExpandProperty Value
  $free = [int]$rawFree * 1024
  if ($free -gt 0) {
    # ? NOTE: `New-TemporaryFile` cmdlet supports Powershell v5 or later
    $tmpPath = Join-Path $env:TEMP ([Guid]::NewGuid())
    Write-Host $tmpPath
    New-Item -Path $tmpPath -ItemType File | Out-Null
    @'
select disk 0
select vol 0
extend size={0}
exit
'@ -f $free | Set-Content $tmpPath
    diskpart /s $tmpPath
    Remove-Item $tmpPath -Force
  }
  <#
  .SYNOPSIS
  Expand the system disk to the maximum size
  #>
}

function Get-ProjectHome() {
  $shell = New-Object -ComObject Shell.Application
  $result = $shell.NameSpace('shell:Downloads') `
    | Select-Object -ExpandProperty Self `
    | Select-Object -ExpandProperty Path `
    | Join-Path -ChildPath setup.windows
  [System.Runtime.Interopservices.Marshal]::ReleaseComObject($shell) `
    | Out-Null
  $result

  <#
  .SYNOPSIS
  get the home path to the setup.windows folder
  #>
}

# #########################################################################

# Correct the pathes
$swHome = Get-ProjectHome

# Expand the system disk to the maximum size
Expand-SystemDisk

# The batch may fail if run on a network folder; copy it to the download
# folder first since the entity in the Vagrant sync folder is the network
# folder.
robocopy.exe C:\vagrant $swHome /mir /dcopy:dat /xd .git /xd .vagrant

# ? If you want to do minimal provisioning, comment out the following line.
Deploy-Launcher -ProjectHome $swHome

# Shortening the connection between WinRM and Vagrant reduces the amount of
# coffee you drink!
sc.exe config winrm start=auto

# Never turn off the display of the Vagrant VM.
powercfg -change -monitor-timeout-ac 0
powercfg -change -monitor-timeout-dc 0

# The script dares to enable the cumbersome UAC to reproduce a more
# realistic test environment.
New-ItemProperty `
  -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System `
  -Name EnableLUA `
  -PropertyType DWord `
  -Value 1 `
  -Force `
  | Out-Null
