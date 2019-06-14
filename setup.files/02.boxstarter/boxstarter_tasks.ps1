Set-StrictMode -Version Latest
Disable-UAC

$cache = Join-Path $env:TMP 'choco'

$winver = (Get-WmiObject win32_OperatingSystem).Version
$wincap = (Get-WmiObject win32_OperatingSystem).Caption
$win7 = $winver -match '^6\.1'
$win8 = $winver -match '^6\.(2|3)'
$win10 = $winver -match '^10\.'
$win10pro = $win10 -and ($wincap -match '(Pro|Enterprise)')

# Managing on Chocolatey
cinst --cacheLocation="$cache" boxstarter

if ($win7) {
  cinst --cacheLocation="$cache" kb976932 # Winows 7 SP1
}

if ($win7 -or $win8) {
  cinst --cacheLocation="$cache" ie11
}

if ($win7) {
  cinst --cacheLocation="$cache" dotnet4.5
}

& { # Powershell 5.1
  cinst --cacheLocation="$cache" dotnetfx
  cinst --cacheLocation="$cache" powershell
}

### Winows 8.1 or 10 features
if ($win8 -or $win10) {
  # Without vagrant
  if ($win10pro -and !(Test-Path -Path C:\vagrant)) {
    cinst --cacheLocation="$cache" Microsoft-Hyper-V-All --source windowsfeatures
  }

  # NFS
  cinst --cacheLocation="$cache" ServicesForNFS-ClientOnly --source windowsfeatures
  cinst --cacheLocation="$cache" ClientForNFS-Infrastructure --source windowsfeatures
  cinst --cacheLocation="$cache" NFS-administration --source windowsfeatures

  # Others
  cinst --cacheLocation="$cache" NetFx3 --source windowsfeatures
}

& { ### Common Windows features
  # Connection
  cinst --cacheLocation="$cache" TelnetClient --source windowsfeatures
  cinst --cacheLocation="$cache" TFTP --source windowsfeatures

  # Others
  cinst --cacheLocation="$cache" TIFFIFilter --source windowsfeatures
}

& { ### Windows features configure
  Set-ExplorerOptions -showHiddenFilesFoldersDrives -showFileExtensions
  Set-CornerNavigationOptions -EnableUpperLeftCornerSwitchApps -EnableUsePowerShellOnWinX
  Set-StartScreenOptions -DisableBootToDesktop -EnableShowStartOnActiveScreen -EnableShowAppsViewOnStartScreen -EnableSearchEverywhereInAppsView -DisableListDesktopAppsFirst
  Set-WindowsExplorerOptions -EnableShowHiddenFilesFoldersDrives -EnableShowFileExtensions -EnableExpandToOpenFolder -EnableShowRecentFilesInQuickAccess -EnableShowFrequentFoldersInQuickAccess -DisableShowRibbon
}

& { ### Runtimes
  # Microsoft
  # cinst --cacheLocation="$cache" vcredist-all # <- vcredist2005: Fail on Win10
  if ($win7 -or $win8) {
    cinst --cacheLocation="$cache" vcredist2005
  }
  cinst --cacheLocation="$cache" vcredist2008 vcredist2010 vcredist2012 vcredist2013 vcredist140 vcredist2015 vcredist2017
  cinst --cacheLocation="$cache" directx
  cinst --cacheLocation="$cache" silverlight

  # Adobe
  cinst --cacheLocation="$cache" flashplayeractivex
  cinst --cacheLocation="$cache" flashplayerplugin
  cinst --cacheLocation="$cache" flashplayerppapi
}

### Security
if ($win7) {
  cinst --cacheLocation="$cache" microsoftsecurityessentials
}

& { ### Cloud storage
  cinst --cacheLocation="$cache" adobe-creative-cloud
  cinst --cacheLocation="$cache" dropbox
  cinst --cacheLocation="$cache" icloud
  if ($win7) {
    cinst --cacheLocation="$cache" onedrive
  }
}

& { # Browsers
  cinst --cacheLocation="$cache" firefox -params "l=ja-JP"
  cinst --cacheLocation="$cache" googlechrome
}

& { ### CLI tools
  cinst --cacheLocation="$cache" awscli
  cinst --cacheLocation="$cache" git.install -params '"/GitOnlyOnPath /NoAutoCrlf /WindowsTerminal /NoShellIntegration /SChannel"'
  cinst --cacheLocation="$cache" gpg4win
  cinst --cacheLocation="$cache" openssh -params '"/SSHServerFeature"'
  cinst --cacheLocation="$cache" sudo
}

& { ### Basic dev
  # SDKs
  cinst --cacheLocation="$cache" netfx-4.7.2-devpack
  cinst --cacheLocation="$cache" dotnetcore-sdk

  cinst --cacheLocation="$cache" powershell-core
  cinst --cacheLocation="$cache" visualstudio2017community --package-parameters "--includeRecommended --includeOptional --passive --locale ja-JP"
}

& { ### Editor
  cinst --cacheLocation="$cache" grammarly
  cinst --cacheLocation="$cache" notion
  cinst --cacheLocation="$cache" vscode -params '"/NoDesktopIcon"'
}

& { ### VSCode Extensions
  $VSCodeExtensions = @(
    'asvetliakov.snapshot-tools',
    'davidanson.vscode-markdownlint',
    'dbaeumer.vscode-eslint',
    'denco.confluence-markup',
    'donjayamanne.githistory',
    'eamodio.gitlens',
    'editorconfig.editorconfig',
    'eg2.vscode-npm-script',
    'esbenp.prettier-vscode',
    'fallenwood.viml',
    'jebbs.plantuml',
    'jpoissonnier.vscode-styled-components',
    'kelvin.vscode-sshfs',
    'marcostazi.vs-code-vagrantfile',
    'mikestead.dotenv',
    'ms-ceintl.vscode-language-pack-ja',
    'ms-vscode.csharp',
    'msjsdiag.debugger-for-chrome',
    'orta.vscode-jest',
    'peterjausovec.vscode-docker',
    'satokaz.vscode-bs-ctrlchar-remover',
    'sidneys1.gitconfig',
    'visualstudioexptteam.vscodeintellicode',
    'vscoss.vscode-ansible'
  )
  $env:Path += ";$($env:ProgramFiles)\Microsoft VS Code\bin"
  $VSCodeExtensions | ForEach-Object {
    code --install-extension $_
  }
}

### Office tools
if ($win7) {
  cinst --cacheLocation="$cache" adobereader -params '"/EnableUpdateService /UpdateMode:3"'
  cinst --cacheLocation="$cache" thunderbird -params "l=ja-JP"
}

& { ### JS dev
  cinst --cacheLocation="$cache" nodejs.install
  $env:Path += ";$($env:ProgramFiles)\nodejs"
  npm install -g yarn
  # npm install -g windows-build-tools # !! Freeze !!
  npm install -g exp
  npm install -g serverless
}

& { ### Game dev
  cinst --cacheLocation="$cache" androidstudio
  cinst --cacheLocation="$cache" unity
}

& { ### SNS, IM
  cinst --cacheLocation="$cache" discord.install
  cinst --cacheLocation="$cache" keybase
  if ($win7) {
    cinst --cacheLocation="$cache" skype
    cinst --cacheLocation="$cache" slack
  }
}

& { ### Virtualization
  cinst --cacheLocation="$cache" virtualbox -params '"/NoDesktopShortcut"'
  cinst --cacheLocation="$cache" vagrant

  # Docker
  if ($win10pro) {
    cinst --cacheLocation="$cache" docker-desktop
  }
  else {
    cinst --cacheLocation="$cache" docker-toolbox
  }
}

& { ### Miscs
  # Fonts
  cinst --cacheLocation="$cache" noto

  # Utils
  cinst --cacheLocation="$cache" autohotkey
  cinst --cacheLocation="$cache" crystaldiskmark

  # Multimedia
  cinst --cacheLocation="$cache" obs-studio

  # Games
  cinst --cacheLocation="$cache" minecraft
  cinst --cacheLocation="$cache" steam
}

& { ### Windows Update
  Install-WindowsUpdate -Full -acceptEula
  Enable-MicrosoftUpdate
}

& { ### Setup home folder
  Push-Location $env:home
  mkdir .ssh
  mkdir src\my

  Pop-Location
}

Enable-UAC
