Set-StrictMode -Version Latest
Disable-UAC

$winver = (Get-WmiObject win32_OperatingSystem).Version
$wincap = (Get-WmiObject win32_OperatingSystem).Caption
$win8 = $winver -match '^6\.'
$win10 = $winver -match '^10\.'
$win10pro = $win10 -and ($wincap -match '(Pro|Enterprise|Education)')

$cache = Join-Path $env:TMP 'choco'
New-Item -Path $cache -ItemType directory -Force

# Managing on Chocolatey
cinst --cacheLocation="$cache" boxstarter

& { # Powershell 5.1
  cinst --cacheLocation="$cache" dotnetfx
  cinst --cacheLocation="$cache" powershell
}

### Winows 8.1 or 10 features
if ($win8 -or $win10) {
  # Without vagrant
  if ($win10pro -and !(Test-Path -Path C:\vagrant)) {
    cinst --cacheLocation="$cache" Microsoft-Hyper-V-All --source windowsfeatures
    cinst --cacheLocation="$cache" VirtualMachinePlatform --source windowsfeatures
    cinst --cacheLocation="$cache" HypervisorPlatform --source windowsfeatures
    cinst --cacheLocation="$cache" Containers-DisposableClientVM --source windowsfeatures
  }

  # NFS
  cinst --cacheLocation="$cache" ServicesForNFS-ClientOnly --source windowsfeatures
  cinst --cacheLocation="$cache" ClientForNFS-Infrastructure --source windowsfeatures
  cinst --cacheLocation="$cache" NFS-administration --source windowsfeatures
}

& { ### Common Windows features
  # Connection
  cinst --cacheLocation="$cache" TelnetClient --source windowsfeatures
  cinst --cacheLocation="$cache" TFTP --source windowsfeatures

  # Others
  cinst --cacheLocation="$cache" NetFx3 --source windowsfeatures
  cinst --cacheLocation="$cache" TIFFIFilter --source windowsfeatures
}

& { ### Windows features configure
  Set-ExplorerOptions -showHiddenFilesFoldersDrives -showFileExtensions
  Set-CornerNavigationOptions -EnableUpperLeftCornerSwitchApps -EnableUsePowerShellOnWinX
  Set-StartScreenOptions -DisableBootToDesktop -EnableShowStartOnActiveScreen -EnableShowAppsViewOnStartScreen -EnableSearchEverywhereInAppsView -DisableListDesktopAppsFirst
  Set-WindowsExplorerOptions -EnableShowHiddenFilesFoldersDrives -EnableShowFileExtensions -EnableExpandToOpenFolder -EnableShowRecentFilesInQuickAccess -EnableShowFrequentFoldersInQuickAccess -DisableShowRibbon

  if ($win10) {
    Get-WindowsCapability -Online `
    | Where-Object -Property Name -Match OpenSSH `
    | Where-Object -Property State -ne Installed `
    | ForEach-Object {
      Add-WindowsCapability -Online -Name $_.Name
    }
  }
}

& { ### VST Settings
  function Add-VST-Links {
    param(
      [Parameter(Mandatory = $true)]
      [System.IO.FileInfo]
      $ProgramFiles,

      [Parameter(Mandatory = $true)]
      [string]
      $CommonProgramFiles
    )

    $VSTMasterSrc = Join-Path "${CommonProgramFiles}" -ChildPath 'VST2'
    $CPFSteinberg = Join-Path "${CommonProgramFiles}" -ChildPath 'Steinberg'
    $PFSteinberg = Join-Path "${ProgramFiles}" -ChildPath 'Steinberg'
    New-Item -Path "${VSTMasterSrc}" -ItemType Directory -Force
    New-Item -Path "${CPFSteinberg}" -ItemType Directory -Force
    New-Item -Path "${PFSteinberg}" -ItemType Directory -Force

    New-Item -Path "${CPFSteinberg}" -ItemType SymbolicLink -Name 'VST2' -Value "${VSTMasterSrc}" -Force
    New-Item -Path "${ProgramFiles}" -ItemType SymbolicLink -Name 'VSTPlugins' -Value "${VSTMasterSrc}" -Force
    New-Item -Path "${PFSteinberg}" -ItemType SymbolicLink -Name 'VSTPlugins' -Value "${VSTMasterSrc}" -Force
  }

  Add-VST-Links -ProgramFiles "${env:ProgramFiles}" -CommonProgramFiles "${env:CommonProgramFiles}"
  Add-VST-Links -ProgramFiles "${env:ProgramFiles(x86)}" -CommonProgramFiles "${env:CommonProgramFiles(x86)}"
}

& { ### Runtimes
  # Microsoft
  # cinst --cacheLocation="$cache" vcredist-all # <- vcredist2005: Fail on Win10
  if ($win8) {
    cinst --cacheLocation="$cache" vcredist2005
  }
  cinst --cacheLocation="$cache" vcredist2008 vcredist2010 vcredist2012 vcredist2013 vcredist140 vcredist2015 vcredist2017
  cinst --cacheLocation="$cache" directx
}

& { ### Cloud storage
  # cinst --cacheLocation="$cache" adobe-creative-cloud # <- Error?
  cinst --cacheLocation="$cache" dropbox
  cinst --cacheLocation="$cache" icloud
}

& { # Browsers
  cinst --cacheLocation="$cache" firefox -params "l=ja-JP"
  cinst --cacheLocation="$cache" googlechrome
}

& { ### CLI tools
  cinst --cacheLocation="$cache" awscli
  cinst --cacheLocation="$cache" git.install -params '"/GitOnlyOnPath /NoAutoCrlf /WindowsTerminal /NoShellIntegration /SChannel"'
  cinst --cacheLocation="$cache" poshgit
  cinst --cacheLocation="$cache" gpg4win
  cinst --cacheLocation="$cache" sudo

  $SystemSSH = $false
  if ($win10) {
    $Installed = Get-WindowsCapability -Online `
    | Where-Object -Property Name -match OpenSSH `
    | Where-Object -Property State -eq Installed `
    | Measure-Object
    $SystemSSH = $Installed.Count -gt 0
  }
  if (! $SystemSSH) {
    cinst --cacheLocation="$cache" openssh -params '"/SSHServerFeature"'
  }
}

& { ### Basic dev
  # SDKs
  cinst --cacheLocation="$cache" netfx-4.7.2-devpack
  cinst --cacheLocation="$cache" dotnetcore-sdk

  cinst --cacheLocation="$cache" powershell-core
}

& { ### Editor
  cinst --cacheLocation="$cache" grammarly
  cinst --cacheLocation="$cache" notion
  cinst --cacheLocation="$cache" vim
  cinst --cacheLocation="$cache" vscode -params '"/NoDesktopIcon"'

  $VSCodeExtensions = @(
    'asvetliakov.snapshot-tools',
    'chrislajoie.vscode-modelines',
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
    'ms-azuretools.vscode-docker',
    'ms-ceintl.vscode-language-pack-ja',
    'ms-vscode.powershell',
    'ms-vscode.vscode-typescript-next',
    'ms-vscode-remote.vscode-remote-extensionpack',
    'msjsdiag.debugger-for-chrome',
    'orta.vscode-jest',
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

& { ### JS dev
  cinst --cacheLocation="$cache" python # Need for aws
  cinst --cacheLocation="$cache" nodist

  $nodist = [IO.Path]::Combine(${env:ProgramFiles(x86)}, 'Nodist', 'bin')
  $env:Path += ";$($nodist)"
  nodist + 10
  nodist + 12
  nodist + 13
  nodist global 13
  npm install -g serverless
  npm install -g yarn
  # npm install -g windows-build-tools # !! Freeze !!
}

& { ### Web dev
  cinst --cacheLocation="$cache" mkcert
}

& { ### Game dev
  cinst --cacheLocation="$cache" androidstudio
  cinst --cacheLocation="$cache" unity-hub
}

& { ### SNS, IM
  cinst --cacheLocation="$cache" discord.install
  cinst --cacheLocation="$cache" keybase
  # You should install FB-Messenger, Skype and Slack from store.
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
  cinst --cacheLocation="$cache" drobo-dashboard
  cinst --cacheLocation="$cache" wkhtmltopdf

  # Multimedia
  cinst --cacheLocation="$cache" obs-studio

  # Games
  cinst --cacheLocation="$cache" minecraft
  cinst --cacheLocation="$cache" steam
}

& { ### Windows Update
  Enable-MicrosoftUpdate
  Install-WindowsUpdate -Full -acceptEula
}

& { ### Setup home folder
  Push-Location $env:home
  mkdir .ssh
  mkdir src\my

  Pop-Location
}

Enable-UAC
