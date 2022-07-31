<#
.SYNOPSIS
The setup scripts by Boxstarter.
#>

Set-StrictMode -Version Latest

$runningFile = Join-Path $env:TEMP 'kurone-kito.setup.windows.tmp';

###########################################################################
### Functions

function Set-Prepare {

  Disable-UAC
  choco feature enable -n=allowEmptyChecksums
  <#
  .SYNOPSIS
  #>
}

function Set-Teardown {
  choco feature disable -n=allowEmptyChecksums
  Enable-UAC
  <#
  .SYNOPSIS
  #>
}

###########################################################################
### Preparation

Set-Prepare
New-Item -Type File $runningFile -Force

choco feature disable -n=skipPackageUpgradesWhenNotInstalled
choco feature enable -n=useRememberedArgumentsForUpgrades

###########################################################################
### Collect information on the current environment.

$isWin1X = (Get-CimInstance win32_OperatingSystem).Version -match '^1(0|1)\.'
$isArm64 = (Get-CimInstance Win32_ComputerSystem).SystemType -like "ARM64*"

$vagrant = Test-Path -Path C:\vagrant

###########################################################################
### Create the Cache directory
$cacheGuid = if (-not [System.String]::IsNullOrWhiteSpace($env:KITO_SETUP_GUID)) {
  $env:KITO_SETUP_GUID
} else {
  New-Guid
}
$cacheDir = Join-Path $env:TEMP $cacheGuid
New-Item -ErrorAction SilentlyContinue -Path $cacheDir -ItemType directory

# ? FAQ: Why do you specify the cache explicitly?
# When using Vagrant, you can place the cache folder externally to minimize
# downloads and make it easier to verify that it works. Also, Boxstarter
# may recursively create an implicit cache folder named “chocolatey”, which
# sometimes has a full path longer than 248 characters. By making the cache
# folder explicit, It can minimize the length of the path.
# see: https://github.com/chocolatey/boxstarter/issues/241

###########################################################################
### Install the corresponding guest tool when the
### current environment is a virtual PC environment.

### Virtualbox Windows Additions

# ! The current environment is a Vagrant environment does not
# ! necessarily mean that it is a Virtualbox environment.
# ! Also, the method of determining this is somewhat unreliable.
if ($vagrant) {
  cinst --cacheLocation="$cacheDir" virtualbox-guest-additions-guest.install
}

###########################################################################
### Remove the pre-installed apps
Get-AppxPackage *BubbleWitch* | Remove-AppxPackage
Get-AppxPackage *DisneyMagicKingdom* | Remove-AppxPackage
Get-AppxPackage *DolbyAccess* | Remove-AppxPackage
Get-AppxPackage king.com.CandyCrush* | Remove-AppxPackage
Get-AppxPackage *HiddenCityMysteryofShadows* | Remove-AppxPackage
Get-AppxPackage *MarchofEmpires* | Remove-AppxPackage
Get-AppxPackage *Netflix* | Remove-AppxPackage
Get-AppxPackage Microsoft.MicrosoftOfficeHub | Remove-AppxPackage

###########################################################################
### Windows Features

### System configuration
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

@(
  # Virtualization
  'Microsoft-Hyper-V-All',
  'VirtualMachinePlatform',
  'HypervisorPlatform',
  'Containers-DisposableClientVM',
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
) | Where-Object {
  $info = clist $_ --source windowsfeatures
  $info -and $info -like '*State : Disabled*'
} | ForEach-Object {
  cinst --cacheLocation="$cacheDir" $_ --source windowsfeatures
}

$installedOpenSSH = $false
$caps = Get-Command Get-WindowsCapability -ErrorAction:SilentlyContinue
if ($caps) {
  $cap = Get-WindowsCapability -Online
  @(
    # Languages and fonts
    'en-US',
    'es-ES',
    'fr-FR',
    'ja-JP',
    'zh-CN',

    # Others
    'DirectX',
    'OpenSSH',
    'ShellComponents',
    'StorageManagement',
    'Tools.DeveloperMode.Core',
    'XPS.Viewer'
  ) | ForEach-Object {
    $cap `
    | Where-Object -Property Name -Match $_ `
    | Where-Object -Property State -ne Installed `
    | ForEach-Object {
      Write-Output $_.Name
      Add-WindowsCapability -Name $_.Name -ErrorAction:SilentlyContinue -Online
    }
  }

  $Installed = Get-WindowsCapability -Online `
    | Where-Object -Property Name -match OpenSSH `
    | Where-Object -Property State -eq Installed `
    | Measure-Object
  $installedOpenSSH = $Installed.Count -gt 0
}

if (Test-PendingReboot) {
  Invoke-Reboot
}

###########################################################################
### Install apps via Chocolatey

### Runtimes
cinst --cacheLocation="$cacheDir" vcredist-all
cinst --cacheLocation="$cacheDir" dotnetfx # !! DEPENDENCIES
cinst --cacheLocation="$cacheDir" dotnet-runtime
cinst --cacheLocation="$cacheDir" dotnetcore-runtime
cinst --cacheLocation="$cacheDir" directx
cinst --cacheLocation="$cacheDir" xna31 --ignore-checksums
cinst --cacheLocation="$cacheDir" xna
cinst --cacheLocation="$cacheDir" adoptopenjdkjre --params='/ADDLOCAL=FeatureMain,FeatureEnvironment,FeatureJarFileRunWith,FeatureJavaHome,FeatureIcedTeaWeb'
cinst --cacheLocation="$cacheDir" rpgtkoolvx-rtp
cinst --cacheLocation="$cacheDir" rpgtkoolvxace-rtp

### Configurations
cinst --cacheLocation="$cacheDir" chezmoi

### CLI Tools
cinst --cacheLocation="$cacheDir" git -params '/GitOnlyOnPath /NoAutoCrlf /NoGuiHereIntegration /NoShellIntegration /NoShellHereIntegration /SChannel /WindowsTerminal' # !! DEPENDENCIES
cinst --cacheLocation="$cacheDir" git-lfs
cinst --cacheLocation="$cacheDir" gh
cinst --cacheLocation="$cacheDir" glab
cinst --cacheLocation="$cacheDir" jq
cinst --cacheLocation="$cacheDir" sudo

### Shell
cinst --cacheLocation="$cacheDir" oh-my-posh
cinst --cacheLocation="$cacheDir" powershell # !! DEPENDENCIES
cinst --cacheLocation="$cacheDir" powershell-core --install-arguments='"ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 REGISTER_MANIFEST=1 ENABLE_PSREMOTING=1"'
cinst --cachcation="$cacheDir" poshgit # ! <- CLI ERROR (but not stack)

### Package Management
cinst --cacheLocation="$cacheDir" boxstarter # * with desktop shortcut
cinst --cacheLocation="$cacheDir" choco-protocol-support
cinst --cacheLocation="$cacheDir" chocolatey
cinst --cacheLocation="$cacheDir" chocolateygui --params="'/DefaultToDarkMode /Global'"
if (-not $isWin1X) {
  cinst --cacheLocation="$cacheDir" powershell-packagemanagement
}

### Audio & Broadcasting
cinst --cacheLocation="$cacheDir" obs-studio # * with desktop shortcut
cinst --cacheLocation="$cacheDir" autohotkey # * vb-cable dependeds it but automate installation is not working
cinst --cacheLocation="$cacheDir" vb-cable
cinst --cacheLocation="$cacheDir" vsthost
if (-not $isArm64) {
  cinst --cacheLocation="$cacheDir" voicemeeter # ! <- ERROR? on ARM64
}

### 3D
cinst --cacheLocation="$cacheDir" blender # * with desktop shortcut
cinst --cacheLocation="$cacheDir" freecad --params "/NoShortcut /WindowStyle:3" # * with desktop shortcut

### Binary tools
cinst --cacheLocation="$cacheDir" ffmpeg
cinst --cacheLocation="$cacheDir" rpi-imager
cinst --cacheLocation="$cacheDir" imagemagick # * with desktop shortcut
cinst --cacheLocation="$cacheDir" sqlite

### Cloud storages
# cinst --cacheLocation="$cacheDir" adobe-creative-cloud --ignore-checksums # ! <- depended to GUI interactive
if (-not $isArm64) {
  cinst --cacheLocation="$cacheDir" dropbox # ! Error on ARM64 (only x86 binary)
}
# You should install iCloud from store.

### Development: for CLI
cinst --cacheLocation="$cacheDir" antlr4
cinst --cacheLocation="$cacheDir" cmake
cinst --cacheLocation="$cacheDir" fnm
cinst --cacheLocation="$cacheDir" visualstudio2017buildtools --package-parameters '--allWorkloads --includeRecommended --includeOptional --passive'
cinst --cacheLocation="$cacheDir" visualstudio2019buildtools --package-parameters '--allWorkloads --includeRecommended --includeOptional --passive'
cinst --cacheLocation="$cacheDir" visualstudio2022buildtools --package-parameters '--allWorkloads --includeRecommended --includeOptional --passive'

# Development: IDE
cinst --cacheLocation="$cacheDir" vim --params "'/NoContextmenu /NoDesktopShortcuts /RestartExplorer'"
cinst --cacheLocation="$cacheDir" sublimetext3
cinst --cacheLocation="$cacheDir" vscode --params '"/NoDesktopIcon"'

### Development: for Mobile apps
cinst --cacheLocation="$cacheDir" androidstudio
cinst --cacheLocation="$cacheDir" mono
cinst --cacheLocation="$cacheDir" unity-hub

# Development: for Web apps
cinst --cacheLocation="$cacheDir" awscli
cinst --cacheLocation="$cacheDir" mkcert
cinst --cacheLocation="$cacheDir" ngrok
cinst --cacheLocation="$cacheDir" insomnia-rest-api-client # * with desktop shortcut

### Devices
if (-not $isArm64) {
  cinst --cacheLocation="$cacheDir" logicoolgaming # ! ignored the cacheDir
}
cinst --cacheLocation="$cacheDir" scrcpy # * with desktop shortcut

### Documentations
cinst --cacheLocation="$cacheDir" graphviz
cinst --cacheLocation="$cacheDir" kindle # * with desktop shortcut
if (-not $isArm64) {
  cinst --cacheLocation="$cacheDir" pandoc # ! Hangs on ARM64
}
cinst --cacheLocation="$cacheDir" plantuml --params="'/NoShortcuts'"
cinst --cacheLocation="$cacheDir" tldr
cinst --cacheLocation="$cacheDir" wkhtmltopdf

### Files
cinst --cacheLocation="$cacheDir" 7zip
cinst --cacheLocation="$cacheDir" svn

### Fonts
cinst --cacheLocation="$cacheDir" cascadiafonts
cinst --cacheLocation="$cacheDir" firacode
cinst --cacheLocation="$cacheDir" font-hackgen
cinst --cacheLocation="$cacheDir" font-hackgen-nerd
cinst --cacheLocation="$cacheDir" lato

### Games
cinst --cacheLocation="$cacheDir" epicgameslauncher # * with desktop shortcut
cinst --cacheLocation="$cacheDir" minecraft-launcher --params="'/NOICON'"
cinst --cacheLocation="$cacheDir" origin
cinst --cacheLocation="$cacheDir" steam-client # * with desktop shortcut
cinst --cacheLocation="$cacheDir" steamcmd
cinst --cacheLocation="$cacheDir" stepmania

### Messaging
cinst --cacheLocation="$cacheDir" discord # * with desktop shortcut
cinst --cacheLocation="$cacheDir" gitter
cinst --cacheLocation="$cacheDir" keybase
cinst --cacheLocation="$cacheDir" mattermost-desktop # * with desktop shortcut
cinst --cacheLocation="$cacheDir" mmctl
cinst --cacheLocation="$cacheDir" zoom # * with desktop shortcut
# You should install FB-Messenger, Skype and Slack from store.

### Remote tools
cinst --cacheLocation="$cacheDir" authy-desktop # * with desktop shortcut
cinst --cacheLocation="$cacheDir" amazon-workspaces
if (-not $isArm64) {
  cinst --cacheLocation="$cacheDir" openvpn --params "'/SELECT_SHORTCUTS=0 /SELECT_LAUNCH=0'" # ! Error? on ARM64
}
cinst --cacheLocation="$cacheDir" teamviewer # * with desktop shortcut
cinst --cacheLocation="$cacheDir" tor
cinst --cacheLocation="$cacheDir" vnc-viewer
if (-not $installedOpenSSH) {
  cinst --cacheLocation="$cacheDir" openssh --params "'/SSHServerFeature'"
}

### Signature
cinst --cacheLocation="$cacheDir" unbound
cinst --cacheLocation="$cacheDir" gnupg # !! DEPENDENCIES

### Tasks & Memos
cinst --cacheLocation="$cacheDir" grammarly-for-windows
cinst --cacheLocation="$cacheDir" notion # * with desktop shortcut
# You should install Microsoft To Do from store.

### Virtualizations
if (-not $isArm64) {
  cinst --cacheLocation="$cacheDir" virtualbox --params '/ExtensionPack /NoDesktopShortcut' # ! Error? on ARM64
  cinst --cacheLocation="$cacheDir" vagrant # ! Hangs on ARM64 only on Boxstarter
}
if ($isWin1X) {
  cinst --cacheLocation="$cacheDir" docker-desktop # * with desktop shortcut
} else {
  cinst --cacheLocation="$cacheDir" docker-toolbox
}
cinst --cacheLocation="$cacheDir" act-cli
cinst --cacheLocation="$cacheDir" gitlab-runner --params '/Service'
cinst --cacheLocation="$cacheDir" dosbox-x --ignore-checksums

### Web browsers
if (-not $isWin1X) {
  cinst --cacheLocation="$cacheDir" microsoft-edge
}
cinst --cacheLocation="$cacheDir" chromium --pre # * with desktop shortcut
cinst --cacheLocation="$cacheDir" elinks
cinst --cacheLocation="$cacheDir" firefoxesr --params "'/l:ja-JP /NoDesktopShortcut /RemoveDistributionDir'"
cinst --cacheLocation="$cacheDir" tor-browser --params '/Locale:ja-JP' # * with desktop shortcut
cinst --cacheLocation="$cacheDir" googlechrome # * with desktop shortcut

### WSL
if ($isWin1X) {
  cinst --cacheLocation="$cacheDir" wsl2 --params '/Version:2 /Retry:true'
  cinst --cacheLocation="$cacheDir" wsl-ubuntu-2204
}

###########################################################################
### Install apps via without Chocolatey

### Node.js
if (Get-Command fnm -ErrorAction SilentlyContinue | Out-Null) {
  $ErrorActionPreference = 'silentlycontinue'
  fnm uninstall 14
  fnm install 14
  fnm uninstall 14
  fnm install 16
  fnm uninstall 14
  fnm install 18
  fnm default 18
  $ErrorActionPreference = 'continue'
}

### Vagrant plugins
if (Get-Command vagrant -ErrorAction SilentlyContinue | Out-Null) {
  $installedPlugins = vagrant plugin list | Out-String
  @(
    'vagrant-disksize',
    'vagrant-reload',
    'vagrant-vbguest'
  ) `
    | Select-Object { '*{0}*' -f $_ } `
    | Where-Object { -not $installedPlugins -like $_ } `
    | ForEach-Object { vagrant plugin install $_ }
  vagrant plugin update
}

###########################################################################
### Update
Enable-MicrosoftUpdate
Install-WindowsUpdate -acceptEula

choco upgrade -y all

###########################################################################
### Post install

if (Test-PendingReboot) {
  Invoke-Reboot
}

###########################################################################
### Teardown
Remove-Item $runningFile -Force
Set-Teardown
