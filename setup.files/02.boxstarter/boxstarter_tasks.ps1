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
  if ($win10) {
    cinst --cacheLocation="$cache" vcredist2008 vcredist2010 vcredist2012 vcredist2013 vcredist140 vcredist2015 vcredist2017
  }
  else {
    cinst --cacheLocation="$cache" vcredist-all
  }
  cinst --cacheLocation="$cache" directx
}

& { ### Cloud storage
  # cinst --cacheLocation="$cache" adobe-creative-cloud # <- Error?
  cinst --cacheLocation="$cache" dropbox
  cinst --cacheLocation="$cache" icloud
}

& { # Browsers
  cinst --cacheLocation="$cache" microsoft-edge
  cinst --cacheLocation="$cache" chromium --pre
  cinst --cacheLocation="$cache" firefox -params "'/l:ja-JP /NoDesktopShortcut /RemoveDistributionDir'"
  cinst --cacheLocation="$cache" googlechrome
  cinst --cacheLocation="$cache" kindle
}

& { ### CLI tools
  cinst --cacheLocation="$cache" git -params "'/GitOnlyOnPath /NoAutoCrlf /WindowsTerminal /NoShellIntegration /SChannel'"
  # Invoke-WebRequest -useb get.scoop.sh | Invoke-Expression # <- Error?
  cinst --cacheLocation="$cache" poshgit
  cinst --cacheLocation="$cache" gpg4win
  cinst --cacheLocation="$cache" hub
  cinst --cacheLocation="$cache" jq
  cinst --cacheLocation="$cache" sudo
  cinst --cacheLocation="$cache" svn

  $SystemSSH = $false
  if ($win10) {
    $Installed = Get-WindowsCapability -Online `
    | Where-Object -Property Name -match OpenSSH `
    | Where-Object -Property State -eq Installed `
    | Measure-Object
    $SystemSSH = $Installed.Count -gt 0
  }
  if (! $SystemSSH) {
    cinst --cacheLocation="$cache" openssh -params "'/SSHServerFeature'"
  }
}

& { ### Basic dev
  # SDKs
  cinst --cacheLocation="$cache" openjdk
  cinst --cacheLocation="$cache" netfx-4.7.2-devpack
  cinst --cacheLocation="$cache" dotnetcore-sdk

  cinst --cacheLocation="$cache" powershell-core --install-arguments='"ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 REGISTER_MANIFEST=1 ENABLE_PSREMOTING=1"' --packageparameters '"/CleanUpPath"'
}

& { ### Editor
  cinst --cacheLocation="$cache" grammarly
  cinst --cacheLocation="$cache" notion
  cinst --cacheLocation="$cache" vim --params "'/NoDesktopShortcuts /RestartExplorer'"
  cinst --cacheLocation="$cache" vscode -params '"/NoDesktopIcon"'

  $VSCodeExtensions = @(
    'aaron-bond.better-comments',
    'alefragnani.Bookmarks',
    'asvetliakov.snapshot-tools',
    'britesnow.vscode-toggle-quotes',
    'chrislajoie.vscode-modelines',
    'coenraads.bracket-pair-colorizer-2',
    'DavidAnson.vscode-markdownlint',
    'dbaeumer.vscode-eslint',
    'denco.confluence-markup',
    'donjayamanne.githistory',
    'eamodio.gitlens',
    'EditorConfig.EditorConfig',
    'eg2.vscode-npm-script',
    'esbenp.prettier-vscode',
    'fallenwood.vimL',
    'GrapeCity.gc-excelviewer',
    'jebbs.plantuml',
    'kumar-harsh.graphql-for-vscode',
    'marcostazi.VS-code-vagrantfile',
    'mikestead.dotenv',
    'ms-azuretools.vscode-docker',
    'MS-CEINTL.vscode-language-pack-ja',
    'ms-vscode.js-debug-nightly',
    'ms-vscode.powershell',
    'ms-vscode.vscode-typescript-next',
    'ms-vscode-remote.vscode-remote-extensionpack',
    'msjsdiag.debugger-for-chrome',
    'orta.vscode-jest',
    'satokaz.vscode-bs-ctrlchar-remover',
    'sidneys1.gitconfig',
    'VisualStudioExptTeam.vscodeintellicode',
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
  cinst --cacheLocation="$cache" visualstudio2019community --package-parameters "--allWorkloads --includeRecommended --includeOptional --passive --locale ja-JP"
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
