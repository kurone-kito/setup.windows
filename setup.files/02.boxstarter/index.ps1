Set-StrictMode -Version Latest
Disable-UAC

& { ### Windows Update
    cinst kb2533552
    cinst kb2534366
    cinst kb2454826
    cinst kb976932 # Winows 7 SP1
    cinst ie11
    cinst dotnet4.5
    cinst netfx-4.7.2-devpack
    cinst powershell

    Enable-MicrosoftUpdate
    Install-WindowsUpdate -Full -acceptEula
}

& { ### Runtimes
    # Microsoft
    cinst vcredist-all
    cinst directx
    cinst silverlight
    cinst dotnetcore-sdk

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
    cinst notion
}

& { # Browsers
    cinst firefox -params "l=ja-JP"
    cinst googlechrome
}

& { ### Basic dev
    cinst powershell-core
    cinst git.install -params '"/GitAndUnixToolsOnPath /NoAutoCrlf /WindowsTerminal /NoShellIntegration /SChannel"'
    cinst vscode -params '"/NoDesktopIcon"'
}

& { ### Game dev
    cinst androidstudio
    cinst unity
}

& { ### JS dev
    cinst nodejs.install
    cinst yarn
    yarn global add windows-build-tools exp serverless
}

# Winows 7
if (((Get-WmiObject win32_OperatingSystem).Version) -lt 6.2) {
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
    if (((Get-WmiObject win32_OperatingSystem).Version) -gt 10) {
        cinst docker-desktop
    } else {
        cinst docker-toolbox
    }
}

& { ### Miscs
    # Multimedia
    cinst obs

    # Games
    cinst minecraft steam
}
