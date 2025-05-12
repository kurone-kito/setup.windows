<#
.SYNOPSIS
The setup scripts by Boxstarter.
#>

Set-StrictMode -Version Latest

###########################################################################
### Collect information on the current environment.

Get-CimInstance Win32_ComputerSystem `
| Select-Object -ExpandProperty SystemType `
| Set-Variable -Name ARCH -Option Constant -Scope local
Get-CimInstance win32_OperatingSystem `
| Select-Object -ExpandProperty Version `
| Set-Variable -Name WINVER -Option Constant -Scope local
$ARCH -like 'ARM64*' `
| Set-Variable -Name IS_ARM64 -Option Constant -Scope local

###########################################################################
### Set the windows options

### Boxstarter options
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

###########################################################################
### Functions
function Install-WingetApps()
{
  param (
    [Parameter(Mandatory)][string]
    $id
  )
  winget install -eh --accept-package-agreements --accept-source-agreements --disable-interactivity --id $id
  <#
  .SYNOPSIS
  Install the application via Winget
  .PARAMETER id
  the id of the application
  #>
}

###########################################################################
### install the dependencies for the setup

choco feature disable -n=skipPackageUpgradesWhenNotInstalled
choco feature enable -n=useRememberedArgumentsForUpgrades

### Package managers
choco install choco-protocol-support
choco install winget-cli
Install-WingetApps 9NBLGGH4NNS1 # App Installer
# Install-WingetApps Chocolatey.ChocolateyGUI
# Install-WingetApps SomePythonThings.WingetUIStore

### Runtimes
Install-WingetApps 9PDSCC711RVF # English Language Pack
Install-WingetApps 9N1W692FV4S1 # Japanese Language Pack
Install-WingetApps Microsoft.DirectX
Install-WingetApps Microsoft.XNARedist
Install-WingetApps Microsoft.DotNet.Framework.DeveloperPack_4
choco install vcredist-all

### Conversion for texts
Install-WingetApps stedolan.jq
Install-WingetApps MikeFarah.yq

### Downloads
Install-WingetApps Git.Git
Install-WingetApps dandavison.delta
Install-WingetApps GitHub.GitLFS

### Fonts
choco install font-hackgen
choco install font-hackgen-nerd
choco install lato

### Signature
Install-WingetApps GnuPG.GnuPG
Install-WingetApps Schniz.fnm

### Text editors
Install-WingetApps vim.vim
Install-WingetApps Neovim.Neovim

###########################################################################
### install CLI applications

### Benchmark tools
Install-WingetApps Fastfetch-cli.Fastfetch

### Binary tools
Install-WingetApps 7zip.7zip
Install-WingetApps Gyan.FFmpeg
Install-WingetApps ImageMagick.ImageMagick

### Configuration tools
Install-WingetApps twpayne.chezmoi

### Database tools
Install-WingetApps SQLite.SQLite

### Development tools
Install-WingetApps Microsoft.BuildTools2015
Install-WingetApps Microsoft.VisualStudio.2019.BuildTools
Install-WingetApps Microsoft.VisualStudio.2022.BuildTools
Install-WingetApps Microsoft.DotNet.SDK.6
Install-WingetApps Microsoft.DotNet.SDK.8
Install-WingetApps Rustlang.Rust.MSVC
choco install antlr4

### Documentation tools
Install-WingetApps wkhtmltopdf.wkhtmltox
choco install cheat

### Files
Install-WingetApps junegunn.fzf
choco install svn

### Games
# Install-WingetApps Valve.SteamCMD

### GitHub
### Virtualizations
# if (!$IS_ARM64) {
#   Install-WingetApps nektos.act
# }
Install-WingetApps GitHub.cli

### Remote tools
# Install-WingetApps Amazon.AWSCLI
Install-WingetApps FiloSottile.mkcert
# Install-WingetApps Ngrok.Ngrok
# choco install tor

### Shell
Install-WingetApps 9MZ1SNWT0N5D # Microsoft.PowerShell
Install-WingetApps XP8K0HKJFRXGCK # Oh My Posh
choco install poshgit

### Virtualization tools
Install-WingetApps 9NZ3KLHXDJP5 # Ubuntu 24.04 LTS
Install-WingetApps Hashicorp.Vagrant

### Web browsers
Install-WingetApps TwibrightLabs.Links

###########################################################################
### install GUI applications

### 3D tools
# Install-WingetApps 9PP3C07GTVRH # Blender
# Install-WingetApps FreeCAD.FreeCAD

### Audio & Broadcasting
# Install-WingetApps 9PFHDD62MXS1 # Apple Music
# Install-WingetApps XPFFH613W8V6LV # OBS Studio
# Install-WingetApps iZotope.ProductPortal
# Install-WingetApps VB-Audio.Voicemeeter
# choco install autohotkey # ! vb-cable dependeds it but automate installation is not working
# choco install reflector-4
# choco install vb-cable

### Authentication tools
# Install-WingetApps Keybase.Keybase

### Benchmark tools
Install-WingetApps 9PGZKJC81Q7J # CineBench

### Cloud storages
# Install-WingetApps XPDLPKWG9SW2WD # Adobe Creative Cloud
# Install-WingetApps 9PKTQ5699M62 # iCloud

### Configuration tools
Install-WingetApps XP89DCGQ3K6VLD # Microsoft.PowerToys

### Development tools
# Install-WingetApps Google.AndroidStudio
# Install-WingetApps Unity.UnityHub
# Install-WingetApps VRChat.CreatorCompanion

### Devices
# Install-WingetApps Logitech.GHUB
# Install-WingetApps Logitech.LGS

### Documentation tools
Install-WingetApps XPDDXX9QW8N9D7 # Grammarly
Install-WingetApps 9NBLGGH5R558 # Microsoft To Do
# Install-WingetApps Amazon.Kindle
# Install-WingetApps Notion.Notion

### Games
# Install-WingetApps ElectronicArts.EADesktop
# Install-WingetApps EpicGames.EpicGamesLauncher
# Install-WingetApps Mojang.MinecraftLauncher
# Install-WingetApps Valve.Steam
# Install-WingetApps StepMania.StepMania

### IDE tools
Install-WingetApps CursorAI,Inc.Cursor
Install-WingetApps SublimeHQ.SublimeText.4
Install-WingetApps XP9KHM4BK9FZ7Q # Visual Studio Code

### Messaging tools
Install-WingetApps 9WZDNCRDK3WP # Slack
# Install-WingetApps XPDC2RH70K22MN # Discord
# Install-WingetApps 9WZDNCRF0083 # Messenger
# Install-WingetApps 9WZDNCRFJ364 # Skype
# Install-WingetApps XP99J3KP4XZ4VV # Zoom

### Office tools
Install-WingetApps XPFFZHVGQWWLHB # Microsoft OneNote

### Remote tools
# Install-WingetApps TeamViewer.TeamViewer
# Install-WingetApps 9WZDNCRFJ3PS # Microsoft Remote Desktop
# Install-WingetApps XP99DVCPGKTXNJ # RealVNC Viewer
Install-WingetApps oldj.switchhosts

### Social apps
# Install-WingetApps 9WZDNCRFJ2WL # Facebook
# Install-WingetApps 9NBLGGH5L9XT # Instagram
# Install-WingetApps 9MXBP1FB84CQ # Threads by Instagram
# Install-WingetApps 9WZDNCRFJ140 # Twitter
# Install-WingetApps VRCX.VRCX

### Terminal
Install-WingetApps 9N0DX20HK701 # Windows Terminal

### Virtualization tools
# Install-WingetApps joncampbell123.DOSBox-X
# if (!$IS_ARM64) {
#   Install-WingetApps Docker.DockerDesktop
#   Install-WingetApps Oracle.VirtualBox
# }

### Web browsers
Install-WingetApps Google.Chrome
Install-WingetApps Mozilla.Firefox.ESR
# Install-WingetApps TorProject.TorBrowser

###########################################################################
### Install apps via without Chocolatey

### Node.js via FNM
if (Get-Command fnm -ErrorAction SilentlyContinue | Out-Null)
{
  fnm env --use-on-cd | Out-String | Invoke-Expression
  @(20, 22, 23, 24) | ForEach-Object { fnm install $_; fnm default $_ }
}

### git-vrc
if (Get-Command git -ErrorAction SilentlyContinue | Out-Null)
{
  if (Get-Command cargo -ErrorAction SilentlyContinue | Out-Null)
  {
    cargo install --locked --git 'https://github.com/anatawa12/git-vrc.git'
    git vrc install --config --global
  }
}

### Scoop
Invoke-WebRequest -useb get.scoop.sh | Invoke-Expression

### Vagrant plugins
if (Get-Command vagrant -ErrorAction SilentlyContinue | Out-Null)
{
  $env:Path += ';C:\HashiCorp\Vagrant\bin'
  $installedPlugins = vagrant plugin list | Out-String
  @('vagrant-reload') `
    | Where-Object { $installedPlugins -notlike ('*{0}*' -f $_) } `
    | ForEach-Object { vagrant plugin install $_ }
  vagrant plugin update
}

### VrChat Creator Companion
$env:Path += ';C:\Program Files\dotnet'
dotnet tool install --global vrchat.vpm.cli

###########################################################################
### Add the sageset for the Clean Manager
@(
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
) | ForEach-Object {
  $baseUri = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\'
  New-ItemProperty `
    -Path ($baseUri + $_) `
    -Name StateFlags0001 `
    -PropertyType DWord `
    -Value 2 `
    -Force `
    | Out-Null
}

###########################################################################
### Teardown

Enable-MicrosoftUpdate
Enable-UAC
Install-WindowsUpdate
