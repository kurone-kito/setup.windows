<#
.SYNOPSIS
The setup scripts by Boxstarter.
#>

Set-StrictMode -Version Latest

###########################################################################
### Constants

Get-CimInstance Win32_ComputerSystem `
  | Select-Object -ExpandProperty SystemType `
  | Set-Variable -name ARCH -option Constant -Scope local
Get-CimInstance win32_OperatingSystem `
  | Select-Object -ExpandProperty Version `
  | Set-Variable -name WINVER -option Constant -Scope local
Join-Path $env:TEMP 'kurone-kito.setup.windows.tmp' `
  | Set-Variable -name RUNNING_FILE -option Constant -Scope local

$ARCH -like 'ARM64*' `
  | Set-Variable -name IS_ARM64 -option Constant -Scope local
$WINVER -match '^1(0|1)\.' `
  | Set-Variable -name IS_WIN1X -option Constant -Scope local
Test-Path -Path C:\vagrant `
  | Set-Variable -name IS_VAGRANT -option Constant -Scope local

$global:CHOCO_INSTALLS = @()

###########################################################################
### Functions

# Add ---------------------------------------------------------------------
function Add-3DToolsInstallation() {
  $global:CHOCO_INSTALLS += @(
    @('freecad', '--params "/NoShortcut /WindowStyle:3"'), # * with desktop shortcut
    @('blender') # * with desktop shortcut
  )
  <#
  .SYNOPSIS
  Add the queue of 3D tools to install.
  #>
}

function Add-AudioAndBroadcastingInstallation() {
  $global:CHOCO_INSTALLS += ,@(
    'obs-studio', # * with desktop shortcut
    'autohotkey', # * vb-cable dependeds it but automate installation is not working
    'vb-cable',
    'vsthost'
  )
  if ($IS_ARM64) {
    $global:CHOCO_INSTALLS += ,@('voicemeeter') # ! <- ERROR? on ARM64
  }
  <#
  .SYNOPSIS
  Add the queue of audio and broadcasting tools to install.
  #>
}

function Add-BinaryToolsInstallation() {
  $global:CHOCO_INSTALLS += ,@('sqlite')
  $global:CHOCO_INSTALLS += @(
    @('7zip', 'ffmpeg', 'rpi-imager'),
    @('imagemagick') # * with desktop shortcut
  )
  <#
  .SYNOPSIS
  Add the queue of binary tools to install.
  #>
}

function Add-CLIToolsInstallation() {
  $global:CHOCO_INSTALLS += @(
    @(
      'git',
      '--params "/GitOnlyOnPath /NoAutoCrlf /NoGuiHereIntegration /NoShellIntegration /NoShellHereIntegration /SChannel /WindowsTerminal"'
    ), # !! DEPENDENCIES
    @('chezmoi', 'jq', 'sudo', 'winfetch'),
    @('unbound'),
    @('gnupg') # !! DEPENDENCIES
  )
  <#
  .SYNOPSIS
  Add the queue of CLI tools to install.
  #>
}

function Add-CloudStorageClientsInstallation() {
  # $global:CHOCO_INSTALLS += ,@('icloud') # * You should install iCloud from store.
  # $global:CHOCO_INSTALLS += ,@('adobe-creative-cloud', '--ignore-checksums') # ! <- depended to GUI interactive
  if (-not $IS_ARM64) {
    $global:CHOCO_INSTALLS += ,@('dropbox') # ! Error on ARM64 (only x86 binary)
  }
  <#
  .SYNOPSIS
  Add the queue of cloud storages client to install.
  #>
}

function Add-DeviceDriversInstallation() {
  if (-not $IS_ARM64) {
    $global:CHOCO_INSTALLS += ,@('logicoolgaming') # ! Error on ARM64 (only x86 binary)
  }
  $global:CHOCO_INSTALLS += ,@('scrcpy') # * with desktop shortcut
  <#
  .SYNOPSIS
  Add the queue of device drivers to install.
  #>
}


function Add-DevToolsInstallation() {
  $global:CHOCO_INSTALLS += @(
    @(
      'visualstudio2017buildtools',
      '--package-parameters "--allWorkloads --includeRecommended --includeOptional --passive"'
    ),
    @(
      'visualstudio2019buildtools',
      '--package-parameters "--allWorkloads --includeRecommended --includeOptional --passive"'
    ),
    @(
      'visualstudio2022buildtools',
      '--package-parameters "--allWorkloads --includeRecommended --includeOptional --passive"'
    ),
    @('antlr4', 'awscli', 'cmake', 'mkcert'),
    @('android-sdk', 'ngrok', 'sublimetext3'),
    @('insomnia-rest-api-client', 'unity-hub'), # * with desktop shortcut
    @('vim', '--params "/NoContextmenu /NoDesktopShortcuts"'),
    @('vscode', '--params "/NoDesktopIcon"'),
    @('mono') # * Can't continue during Visual Studio installation
  )
  <#
  .SYNOPSIS
  Add the queue of development tools to install.
  #>
}

function Add-DocumentationToolsInstallation() {
  $global:CHOCO_INSTALLS += @(
    @('plantuml', '--params="/NoShortcuts"'),
    @('cheat', 'graphviz', 'tldr', 'wkhtmltopdf')
  )
  $global:CHOCO_INSTALLS += ,@(
    'grammarly-for-windows', 'kindle', 'notion' # * with desktop shortcut
  )
  # $global:CHOCO_INSTALLS += ,@('messenger', 'slack', 'skype') # * You should install from store.
  if (-not $IS_ARM64) {
    $global:CHOCO_INSTALLS += ,@('pandoc') # ! Hangs on ARM64
  }
  <#
  .SYNOPSIS
  Add the queue of documentation tools to install.
  #>
}

function Add-FontsInstallation() {
  $global:CHOCO_INSTALLS += ,@(
    'cascadiafonts',
    'firacode',
    'font-hackgen',
    'font-hackgen-nerd',
    'lato'
  )
  <#
  .SYNOPSIS
  Add the queue of fonts to install.
  #>
}

function Add-GamesInstallation() {
  $global:CHOCO_INSTALLS += @(
    @('epicgameslauncher', 'steam-client'), # * with desktop shortcut
    @('origin', 'steamcmd', 'stepmania'),
    @('minecraft-launcher', '--params="/NOICON"')
  )
  <#
  .SYNOPSIS
  Add the queue of games to install.
  #>
}

function Add-MessagingToolsInstallation() {
  $global:CHOCO_INSTALLS += @(
    @('discord', 'mattermost-desktop', 'zoom'), # * with desktop shortcut
    @('gitter', 'keybase'),
    @('mmctl')
  )
  # $global:CHOCO_INSTALLS += ,@('messenger', 'slack', 'skype') # * You should install from store.
  <#
  .SYNOPSIS
  Add the queue of messaging tools to install.
  #>
}

function Add-PackageManagersInstallation() {
  $global:CHOCO_INSTALLS += ,@('choco-protocol-support')
  $global:CHOCO_INSTALLS += ,@(
    'chocolateygui', '--params="/DefaultToDarkMode /Global"'
  )
  if (-not $IS_WIN1X) {
    $global:CHOCO_INSTALLS += ,@('powershell-packagemanagement')
  }
  <#
  .SYNOPSIS
  Add the queue of package managers to install.
  #>
}

function Add-RemoteClientsInstallation() {
  $global:CHOCO_INSTALLS += ,@('git-lfs', 'gh', 'glab', 'svn')
  $global:CHOCO_INSTALLS += @(
    @('tor', 'vnc-viewer'),
    @(
      'amazon-workspaces', # * with desktop shortcut
      'authy-desktop', # * with desktop shortcut
      'teamviewer' # * with desktop shortcut
    )
  )
  if (-not $IS_ARM64) {
    $global:CHOCO_INSTALLS += ,@(
      'openvpn', # ! Error? on ARM64
      '--params "/SELECT_SHORTCUTS=0 /SELECT_LAUNCH=0"'
    )
  }
  if ((Get-OpenSSHInstalls) -eq 0) {
    $global:CHOCO_INSTALLS += ,@('openssh', '--params "/SSHServerFeature"')
  }
  <#
  .SYNOPSIS
  Add the queue of remote clients to install.
  #>
}

function Add-RuntimesInstallation() {
  $global:CHOCO_INSTALLS += @(
    @(
      'vcredist-all',
      'dotnetfx',
      'dotnet-runtime',
      'dotnetcore-runtime',
      'directx'
    ),
    @('xna31', '--ignore-checksums'),
    @('xna'),
    @('rpgtkoolvx-rtp', 'rpgtkoolvxace-rtp'),
    @(
      'adoptopenjdkjre',
      '--params="/ADDLOCAL=FeatureMain,FeatureEnvironment,FeatureJarFileRunWith,FeatureJavaHome,FeatureIcedTeaWeb"'
    )
  )
  <#
  .SYNOPSIS
  Add the queue of runtimes to install.
  #>
}

function Add-ShellExtensionsInstallation() {
  $global:CHOCO_INSTALLS += @(
    @('powershell'), # !! DEPENDENCIES
    @(
      'pwsh',
      '--install-arguments="ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 REGISTER_MANIFEST=1 ENABLE_PSREMOTING=1 USE_MU=1 ENABLE_MU=1"',
      '--packageparameters "/CleanUpPath"'
    ),
    @(
      'oh-my-posh',
      'poshgit' # ! <- CLI ERROR (but not stack)
    )
  )
  <#
  .SYNOPSIS
  Add the queue of shell extensions to install.
  #>
}

function Add-VirtualizationToolsInstallation() {
  if (-not $IS_ARM64) {
    $global:CHOCO_INSTALLS += ,@( # ! Error? on ARM64
      'virtualbox', '--params "/ExtensionPack /NoDesktopShortcut"'
    )
  }
  if ($IS_WIN1X) {
    $global:CHOCO_INSTALLS += ,@('docker-desktop') # * with desktop shortcut
  } else {
    $global:CHOCO_INSTALLS += ,@('docker-toolbox')
  }
  $global:CHOCO_INSTALLS += @(
    @('act-cli'),
    @('gitlab-runner', '--params "/Service"')
  )
  $global:CHOCO_INSTALLS += ,@(
    'dosbox-x', '--ignore-checksums' # * with desktop shortcut
  )
  <#
  .SYNOPSIS
  Add the queue of virtualization tools to install.
  #>
}

function Add-WebBrowserInstallation() {
  if (-not $IS_WIN1X) {
    $global:CHOCO_INSTALLS += ,@('microsoft-edge')
  }
  $global:CHOCO_INSTALLS += @(
    @('elinks'),
    @('googlechrome'), # * with desktop shortcut
    @('chromium', '--pre'), # * with desktop shortcut
    @('tor-browser', '--params "/Locale:ja-JP"'), # * with desktop shortcut
    @('firefoxesr', '--params "/l:ja-JP /NoDesktopShortcut /RemoveDistributionDir"')
  )
  <#
  .SYNOPSIS
  Add the queue of web browsers to install.
  #>
}

function Add-WSLInstallation() {
  if ($IS_WIN1X) {
    $global:CHOCO_INSTALLS += @(
      @('wsl2', '--params "/Version:2 /Retry:true"'),
      @('wsl-ubuntu-2204')
    )
  }
  <#
  .SYNOPSIS
  Add the queue of WSL2 to install.
  #>
}

# Get ---------------------------------------------------------------------
function Get-OpenSSHInstalls() {
  Get-WindowsCapability -Online `
    | Where-Object -Property Name -match OpenSSH `
    | Where-Object -Property State -eq Installed `
    | Measure-Object `
    | Select-Object -ExpandProperty Count
  <#
  .SYNOPSIS
  Get the number of OpenSSH installations.
  #>
}

# Install -----------------------------------------------------------------
function Install-ChocoPackages() {
  $global:CHOCO_INSTALLS | ForEach-Object {
    choco install @_
  }
  <#
  .SYNOPSIS
  Install the queued packages with Chocolatey.
  #>
}

function Install-FNM() {
  choco install fnm
  fnm env --use-on-cd | Out-String | Invoke-Expression
  Install-NodeJS -NodeVersion 14 -NPMVersion 6
  Install-NodeJS -NodeVersion 16
  Install-NodeJS -NodeVersion 18
  <#
  .SYNOPSIS
  Install the Node.js via FNM, and install some global packages.
  #>
}

function Install-NodeJS() {
  param(
    [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
    [string]
    $NodeVersion,
    [string]
    $NPMVersion = 'latest'
  )
  fnm install $NodeVersion
  fnm default $NodeVersion

  # https://qiita.com/Qoo_Rus/items/afb52517e0e17b720990
  npm install -g --silent 'agentkeepalive@latest'
  npm install -g --silent "npm@${NPMVersion}"
  npm upgrade -g --silent
  npm install -g --silent 'yarn@berry'
  <#
  .SYNOPSIS
  Install the Node.js and some global packages.
  #>
}

function Install-SomeWindowsCapability() {
  $installList = @(
    # Languages and fonts
    'en-US',
    'es-ES',
    'fr-FR',
    'zh-CN',
    'Language.Basic.*ja-JP', # ! ERROR?? on Vagrant Win10 (intel)
    'Language.Fonts.Jpan'

    # Others
    'DirectX',
    'OpenSSH',
    'ShellComponents',
    # 'StorageManagement', # ! ERROR?? on Vagrant Win11 (intel)
    'Tools.DeveloperMode.Core',
    'XPS.Viewer'
  )

  $caps = Get-WindowsCapability -Online `
    | Where-Object -Property State -ne Installed
  $installList | ForEach-Object {
    $target = $_
    $caps `
    | Where-Object -Property Name -Match $target `
    | Select-Object -ExpandProperty Name
  } | ForEach-Object {
    Write-BoxstarterMessage ('installing {0}...' -f $_)
    Add-WindowsCapability `
      -Name $_ `
      -ErrorAction:SilentlyContinue `
      -Online
  }

  <#
  .SYNOPSIS
  Install the queued Windows capabilities.
  #>
}

function Install-SomeWindowsFeatures() {
  $installList = @(
    # Virtualization
    'Microsoft-Hyper-V-All',
    'VirtualMachinePlatform',
    'HypervisorPlatform',
    'Microsoft-Windows-Subsystem-Linux',

    # NFS
    'ServicesForNFS-ClientOnly',
    'ClientForNFS-Infrastructure',
    'NFS-administration',

    # Connection
    'TelnetClient',
    'TFTP',

    # Others
    'NetFx3',
    'TIFFIFilter',
    'Windows-Defender-ApplicationGuard'
  )
  try {
    $disabledFeatures = choco find -s windowsfeatures `
      | Select-String Disabled `
      | Select-Object -ExpandProperty Line `
      | Select-String -Pattern '^[A-Za-z0-9-]+' `
      | Select-Object -ExpandProperty Matches `
      | Select-Object -ExpandProperty Value
    $diff = Compare-Object `
      -ReferenceObject $installList `
      -DifferenceObject $disabledFeatures `
      -PassThru `
      -IncludeEqual `
      -ExcludeDifferent
    choco install @diff -s windowsfeatures
  } catch {
    Write-BoxstarterMessage `
      -Message 'Notice: Chocolatey search for Windows features failed so it will install all listed components. So slightly increases the installation process but does not affect the installation results.' `
      -NoLogo `
      -Color DarkYellow
    choco install @installList -s windowsfeatures
  }
  <#
  .SYNOPSIS
  Install some Windows features.
  #>
}

function Install-Vagrant() {
  choco install vagrant
  $env:Path += ';C:\HashiCorp\Vagrant\bin'
  $installedPlugins = vagrant plugin list | Out-String
  @('vagrant-disksize', 'vagrant-reload', 'vagrant-vbguest') `
    | Where-Object { $installedPlugins -notlike ('*{0}*' -f $_) } `
    | ForEach-Object { vagrant plugin install $_ }
  vagrant plugin update
  <#
  .SYNOPSIS
  Install Vagrant and some plugins.
  #>
}

# Pop ---------------------------------------------------------------------
function Pop-Preparation() {
  Remove-Item $RUNNING_FILE -Force
  Enable-UAC
  <#
  .SYNOPSIS
  Remove the preparation settings.
  #>
}

# Push --------------------------------------------------------------------
function Push-Preparation() {
  New-Item -Type File $RUNNING_FILE -Force | Out-Null
  Disable-UAC
  <#
  .SYNOPSIS
  Set the preparation settings.
  #>
}

# Remove ------------------------------------------------------------------
function Remove-SomeAppx() {
  @(
    '*BubbleWitch*',
    '*DisneyMagicKingdom*',
    '*DolbyAccess*',
    'king.com.CandyCrush*',
    '*HiddenCityMysteryofShadows*',
    '*MarchofEmpires*',
    '*Netflix*',
    'Microsoft.MicrosoftOfficeHub'
  ) | ForEach-Object { Get-AppxPackage $_ | Remove-AppxPackage }
  <#
  .SYNOPSIS
  Remove some Appx packages.
  #>
}

# Set ---------------------------------------------------------------------
function Set-ChocoFeatures() {
  choco feature disable -n=skipPackageUpgradesWhenNotInstalled
  choco feature enable -n=useRememberedArgumentsForUpgrades
  <#
  .SYNOPSIS
  Set the Chocolatey features.
  #>
}

function Set-CleanManagerSageSet() {
  $baseUri = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\'
  $keys = @(
    'Active Setup Temp Folders',
    'BranchCache',
    'D3D Shader Cache',
    'Delivery Optimization Files',
    'Diagnostic Data Viewer database files',
    'Downloaded Program Files',
    'Internet Cache Files',
    'Old ChkDsk Files',
    'Recycle Bin',
    'RetailDemo Offline Content',
    'Setup Log Files',
    'System error memory dump files',
    'System error minidump files',
    'Temporary Files',
    'Thumbnail Cache',
    'Update Cleanup',
    'User file versions',
    'Windows Defender',
    'Windows Error Reporting Files'
  )
  $keys | ForEach-Object {
    New-ItemProperty `
      -Path ($baseUri + $_) `
      -Name StateFlags0001 `
      -PropertyType DWord `
      -Value 2 `
      -Force `
      | Out-Null
  }
  <#
  .SYNOPSIS
  Set the CleanManager SageSet.
  #>
}

function Set-WindowsOptions() {
  Set-CornerNavigationOptions -EnableUpperLeftCornerSwitchApps -EnableUsePowerShellOnWinX
  Set-ExplorerOptions -showHiddenFilesFoldersDrives -showFileExtensions
  Set-StartScreenOptions -DisableBootToDesktop -EnableShowStartOnActiveScreen -EnableShowAppsViewOnStartScreen -EnableSearchEverywhereInAppsView -DisableListDesktopAppsFirst
  Set-BoxstarterTaskbarOptions -MultiMonitorOn -MultiMonitorMode All -MultiMonitorCombine Always
  Set-WindowsExplorerOptions -EnableShowHiddenFilesFoldersDrives -EnableShowFileExtensions -EnableExpandToOpenFolder -EnableShowRecentFilesInQuickAccess -EnableShowFrequentFoldersInQuickAccess -DisableShowRibbon
  Enable-RemoteDesktop

  ### Explorer options
  Set-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name NavPaneExpandToCurrentFolder -Value 1
  Set-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name SeparateProcess -Value 1
  Set-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name ShowCompColor -Value 1

  ### Taskbar options
  Set-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Search -Name SearchboxTaskbarMode -Value 1
  <#
  .SYNOPSIS
  Set the Windows options.
  #>
}

###########################################################################
### Main

Push-Preparation
Set-ChocoFeatures
choco install boxstarter chocolatey

###########################################################################
### Windows Features

Remove-SomeAppx
Set-WindowsOptions

Set-CleanManagerSageSet
cleanmgr /dc /sagerun:1

Install-SomeWindowsCapability
Install-SomeWindowsFeatures

###########################################################################
### Install apps via Chocolatey

Add-RuntimesInstallation
Add-CLIToolsInstallation
Add-ShellExtensionsInstallation
Add-PackageManagersInstallation

Add-FontsInstallation
Add-AudioAndBroadcastingInstallation
Add-CloudStorageClientsInstallation
Add-WebBrowserInstallation

Add-DocumentationToolsInstallation
Add-DevToolsInstallation
Add-BinaryToolsInstallation
Add-DeviceDriversInstallation

Add-3DToolsInstallation
Add-GamesInstallation
Add-MessagingToolsInstallation

Add-RemoteClientsInstallation
Add-VirtualizationToolsInstallation
Add-WSLInstallation

Install-ChocoPackages

###########################################################################
### Install apps via without Chocolatey

Install-FNM
Install-Vagrant

Invoke-WebRequest -useb get.scoop.sh | Invoke-Expression

###########################################################################
### Update
Enable-MicrosoftUpdate
Install-WindowsUpdate

###########################################################################
### Teardown
Pop-Preparation
