Set-StrictMode -Version Latest
Disable-UAC

# Managing on Chocolatey
cinst boxstarter

$winver = (Get-WmiObject win32_OperatingSystem).Version
$win7 = $winver -match '^6\.1'
$win8 = ($winver -match '^6\.(2|3)')
$win10 = $winver -match '^10\.'

if ($win7) {
    # Prepare of SP1
    cinst kb2533552
    cinst kb2534366
    cinst kb2454826

    cinst kb976932 # Winows 7 SP1
}

if ($win7 -or $win8) {
    cinst ie11
}

if ($win7) {
    cinst dotnet4.5
}

& { # Powershell 5.1
    cinst dotnetfx
    cinst powershell
}

### Winows 8.1 or 10 features
if ($win8 -or $win10) {
    # Without vagrant
    if (!(Test-Path -Path C:\vagrant)) {
        cinst Microsoft-Hyper-V-All --source windowsfeatures
    }

    # NFS
    cinst ServicesForNFS-ClientOnly --source windowsfeatures
    cinst ClientForNFS-Infrastructure --source windowsfeatures
    cinst NFS-administration --source windowsfeatures

    # Others
    cinst NetFx3 --source windowsfeatures
}

& { ### Common Windows features
    # Connection
    cinst TelnetClient --source windowsfeatures
    cinst TFTP --source windowsfeatures

    # Others
    cinst TIFFIFilter --source windowsfeatures
}

& { ### Windows features configure
    Set-ExplorerOptions -showHiddenFilesFoldersDrives -showFileExtensions
    Set-CornerNavigationOptions -EnableUpperLeftCornerSwitchApps -EnableUsePowerShellOnWinX
    Set-StartScreenOptions -DisableBootToDesktop -EnableShowStartOnActiveScreen -EnableShowAppsViewOnStartScreen -EnableSearchEverywhereInAppsView -DisableListDesktopAppsFirst
    if ($win7) {
        Set-WindowsExplorerOptions -EnableShowHiddenFilesFoldersDrives -EnableShowFileExtensions -EnableExpandToOpenFolder -EnableShowRecentFilesInQuickAccess -EnableShowFrequentFoldersInQuickAccess -DisableShowRibbon
    }
    else {
        Set-WindowsExplorerOptions -EnableShowHiddenFilesFoldersDrives -EnableShowFileExtensions -EnableExpandToOpenFolder -EnableShowRecentFilesInQuickAccess -EnableShowFrequentFoldersInQuickAccess -DisableShowRibbon -EnableSnapAssist
    }
}

& { ### Runtimes
    # Microsoft
    cinst vcredist-all
    cinst directx
    cinst silverlight

    # Adobe
    cinst flashplayeractivex
    cinst flashplayerplugin
    cinst flashplayerppapi
    cinst adobeshockwaveplayer
    cinst adobeair
}

& { ### Cloud storage
    cinst adobe-creative-cloud
    cinst dropbox
}

& { # Browsers
    cinst firefox -params "l=ja-JP"
    cinst googlechrome
}

& { ### Basic dev
    # SDKs
    cinst netfx-4.7.2-devpack
    cinst dotnetcore-sdk

    cinst powershell-core
    cinst git.install -params '"/GitAndUnixToolsOnPath /NoAutoCrlf /WindowsTerminal /NoShellIntegration /SChannel"'
    cinst git-lfs
    cinst visualstudio2017community --package-parameters "--includeRecommended --includeOptional --passive --locale ja-JP"
}

& { ### Editor
    cinst grammarly
    cinst notion
    cinst vscode -params '"/NoDesktopIcon"'
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
        'ms-vscode.powershell',
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

& { ### Game dev
    cinst androidstudio
    cinst unity
}

& { ### JS dev
    cinst nodejs.install
    npm install -g yarn
    yarn global add windows-build-tools exp serverless
}

### Tools for Winows 7
if ($win7) {
    cinst microsoftsecurityessentials
    cinst adobereader -params '"/EnableUpdateService /UpdateMode:3"'
    cinst thunderbird -params "l=ja-JP"
    
    cinst onedrive
    cinst skype
    cinst slack
}

& { ### SNS, IM
    cinst discord.install
    cinst keybase
}

& { ### Virtualization
    cinst virtualbox -params '"/NoDesktopShortcut"'
    cinst vagrant

    # Docker
    if ($win10) {
        cinst docker-desktop
    }
    else {
        cinst docker-toolbox
    }
}

& { ### Miscs
    # Utils
    cinst sudo
    cinst crystaldiskmark

    # Multimedia
    cinst obs

    # Games
    cinst minecraft
    cinst steam
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
