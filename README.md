<!-- markdownlint-disable MD024 -->

# Windows auto setup for develop environment

Desktop environment preference for Windows (8.1 to 11)  
Windows 8.1 〜 11 向けの作業環境セットアップスクリプト

## Overview

In order to reinstall OS more easily when Windows is unstable, we fully
automated the installation of some apps. Two tools:
[Chocolatey](https://chocolatey.org) and
[BoxStarter](https://boxstarter.org),
were very helpful in developing this project.  
Windows が不安定な時、OS をより手軽に再インストールするために、
アプリのインストールを全自動化します。このプロジェクトの開発には、
[Chocolatey](https://chocolatey.org) と
[BoxStarter](https://boxstarter.org) との、2 つのツールが役立ちました。

## Usage

```PowerShell
PS> .\setup
```

Do not run from a network folder. The `cmd.exe` does not support UNC paths,
which may cause unexpected behavior.  
ネットワークフォルダからの実行は避けてください。`cmd.exe` が UNC
パスに対応していないため、予期しない動作となる可能性があります。

### Prompt

1. Setup will ask for two UAC confirmations at the start of execution.  
   セットアップは実行開始時に 2 回の UAC 確認を求めます。
2. Setup then asks for login information for a fully automated restart.  
   その後、セットアップは再起動の全自動化のためのログイン情報の入力を求めます。

## Details

### Apps install

Unless otherwise specified, as a general rule, install via Chocolatey.  
特筆なき場合、原則として Chocolatey 経由でインストールします。

<!-- markdownlint-disable MD033 -->
<details><summary>CLI Apps</summary>

|  note   | description                                                                         |
| :-----: | :---------------------------------------------------------------------------------- |
| **`!`** | **DEPENDENCIES**: Removing this app may cause this setup to stop working correctly. |
|  `-A`   | without ARM64 Architecture                                                          |
|  `-X`   | without Windows 10 / 11                                                             |

#### Convert tools for Media binary

- [FFmpeg](https://www.ffmpeg.org/)
- [ImageMagick](https://imagemagick.org/index.php)

#### Convert tools for Texts

- [jq](https://stedolan.github.io/jq/)

#### Database

- [SQLite](https://www.sqlite.org/)

#### Development

- [ANTLR](https://www.antlr.org/)
- [CMake](https://cmake.org)
- [fnm: Fast Node Manager](https://fnm.vercel.app/)
  - Node.js (via fnm)
    - v14 LTS Fermium
    - v16 LTS Gallium
    - v18
- [Mono](https://www.mono-project.com/)
- [Microsoft Visual Studio Build Tools](https://www.visualstudio.com/)
  - `(-A)` version 2015
  - version 2017
  - version 2019
  - version 2022

#### Documentation

- [Graphviz](https://graphviz.org/)
- [pandoc](https://pandoc.org/)
- [PlantUML](https://plantuml.com/)
- [tldr pages](https://tldr.sh)
- [wkhtmltopdf](https://wkhtmltopdf.org/)

#### Files management

- [7-Zip](https://www.7-zip.org/)

#### Packages manager

- [BoxStarter](https://boxstarter.org)
- [Chocolatey](https://chocolatey.org) (directly install)
- [Chocolatey `choco://` Protocol support](https://github.com/bcurran3/ChocolateyPackages/tree/master/choco-protocol-support)
- `(-X)` [PowerShell Package Manager](https://www.powershellgallery.com)
- [SteamCMD](https://developer.valvesoftware.com/wiki/SteamCMD)

#### Runtime

- [Visual C++ Redistributable Packages](https://docs.microsoft.com/cpp/windows/latest-supported-vc-redist)
- [AdoptOpenJDK](https://adoptopenjdk.net/)
- **`!`** [Microsoft .NET Framework Runtime](https://support.microsoft.com/topic/9d23f658-3b97-68ab-d013-aa3c3e7495e0)
- [Microsoft .NET Core Runtime](https://dotnet.microsoft.com/download#macos)

#### Testing

- [mkcert](https://mkcert.dev/)
- [ngrok](https://ngrok.com/)

#### Version control system

- [Apache Subversion](https://subversion.apache.org/)
- **`!`** [Git](https://git-scm.com/)
  - **`!`** [Git Large File Storage](https://git-lfs.github.com/)
  - [git-delta: A viewer for git and diff output](https://github.com/dandavison/delta)
- [GitHub Hub](https://hub.github.com/)

#### Remote

- [awscli](https://aws.amazon.com/cli/)
- `(-X)` [OpenSSH](https://www.openssh.com/) (install via the Windows feature when on Windows 10 or 11)

#### Shell

- **`!`** [Microsoft PowerShell](https://microsoft.com/PowerShell)
- [Microsoft PowerShell Core](https://microsoft.com/PowerShell)
- [Oh My Posh](https://ohmyposh.dev/)
- [posh-git](https://dahlbyk.github.io/posh-git/)
- [sudo](https://github.com/janhebnes/chocolatey-packages/tree/master/Sudo)

#### Signature

- **`!`** [GnuPG: The GNU Privacy Guard](https://gnupg.org/)
- **`!`** [Unbound](https://www.nlnetlabs.nl/projects/unbound/)

#### Text Browsing

- [cheat](https://github.com/cheat/cheat)
- [ELinks](http://www.elinks.cz/)

#### Text editors

- [GNU Nano](https://www.nano-editor.org)
- [Vim](https://www.vim.org/)

#### Virtualizations

- [act](https://github.com/nektos/act)
- [GitLab Runner](https://gitlab.com/gitlab-org/gitlab-runner)
- `(-A)` [Vagrant](https://www.vagrantup.com/)

</details>
<!-- markdownlint-enable MD033 -->

<!-- markdownlint-disable MD033 -->
<details><summary>Desktop Apps</summary>

| note | description                |
| :--: | :------------------------- |
| `-A` | without ARM64 Architecture |
| `-X` | without Windows 10 / 11    |
| `-8` | without Windows 8.1        |

#### 3D Modeling

- [Blender](https://www.blender.org/)
- [FreeCAD](https://www.freecadweb.org/)

#### Audios, Videos, and Broadcasting

- [OBS Studio](https://obsproject.com/)
- [VB-CABLE Virtual Audio Device](https://vb-audio.com/Cable/)
- `(-A)` [VoiceMeeter](https://vb-audio.com/Voicemeeter/)
- [VSTHost](https://www.hermannseib.com/english/vsthost.htm)

#### Authentication

- [Authy Desktop](https://www.authy.com/)
- [Keybase](https://keybase.io/)

#### Cloud storages

- `(-A)` [Dropbox](https://www.dropbox.com/)

#### Development

- [Android Studio](https://developer.android.com/studio)
- [Unity Hub](https://unity3d.com/)

#### Devices

- [scrcpy](https://github.com/Genymobile/scrcpy)
<!-- - [Drobo Dashboard](https://www.drobo.com/) -->
- [logicool G Hub](https://gaming.logicool.co.jp/innovation/g-hub.html)
- [Raspberry Pi Imager](https://www.raspberrypi.org/software/)

#### Documents and Office apps

- [Amazon Kindle](https://www.amazon.com/kindle)

#### Games

- [EPIC Games Launcher](https://www.epicgames.com/store/download)
- [Origin (EA Desktop)](https://www.origin.com/)
- [Minecraft Java Edition](https://www.minecraft.net/)
- [Steam](https://store.steampowered.com/)
- [Stepmania](https://www.stepmania.com/)

#### Memos and Tasks

- [Grammarly](https://www.grammarly.com/)
- [Notion](https://www.notion.so/)

#### Messaging and Socials

- [Discord](https://discord.com/)
- [Gitter](https://gitter.im/)
- [Mattermost / with CLI tools](https://mattermost.com/)
- [Zoom](https://zoom.us/)

#### Packages manager

- [Chocolatey GUI](https://github.com/chocolatey/ChocolateyGUI)

#### Remote

- `(-A)` [OpenVPN](https://openvpn.net/)
- [Real VNC Viewer](https://www.realvnc.com/connect/download/viewer/)
- [TeamViewer](https://www.teamviewer.com/)

#### Runtime

- [Microsoft DirectX](https://www.microsoft.com/download/details.aspx?id=35)
- Microsoft XNA Framework
  - [v3.1](https://www.microsoft.com/download/details.aspx?id=15163)
  - [v4.0](https://www.microsoft.com/download/details.aspx?id=20914)
- [RPG Tkool VX / Ace RTP](https://tkool.jp)

#### Text editors

- [GitHub Atom Editor](https://atom.io/)
- [Sublime Text](https://www.sublimetext.com/)
- [Visual Studio Code](https://code.visualstudio.com/)

#### Virtualizations

- `(-8)` [Docker Desktop](https://www.docker.com/products/docker-desktop)
- `(-X)` [Docker Toolbox](https://docs.docker.com/toolbox/)
- [DOSBox-X](https://dosbox-x.com)
- `(-A)` [Oracle VM Virtualbox + Extension Pack](https://www.virtualbox.org/)
- [Windows Subsystem for Linux](https://docs.microsoft.com/windows/wsl/)

#### Web browsers

- [Google Chrome](https://www.google.com/chrome/)
- [Chromium](https://www.chromium.org/Home)
- [Insomnia](https://insomnia.rest/)
- `(-X)` [Microsoft Edge](https://www.microsoft.com/edge)
- [Mozilla Firefox ESR](https://www.mozilla.org/firefox/)
- [Tor Browser](https://www.torproject.org/projects/torbrowser.html)

</details>
<!-- markdownlint-enable MD033 -->

<!-- markdownlint-disable MD033 -->
<details><summary>Fonts</summary>

- [白源: HackGen Nerd](https://github.com/yuru7/HackGen)
- [Lato](https://fonts.google.com/specimen/Lato)

</details>
<!-- markdownlint-enable MD033 -->

<!-- markdownlint-disable MD033 -->
<details><summary>Windows features</summary>

NOTICE: In the Home edition, some features are excluded and installed.

|  note   | description                                                                         |
| :-----: | :---------------------------------------------------------------------------------- |
| **`!`** | **DEPENDENCIES**: Removing this app may cause this setup to stop working correctly. |
|  `-8`   | without Windows 8.1                                                                 |

- Virtualization features
  - **`!`** Hyper-V
  - **`!`** Virtual Machine Platform
  - **`!`** Hypervisor Platform
  - Windows Sandbox
  - **`!`** `(-8)` Windows Subsystem for Linux
- Network client
  - NFS Client
  - NFS Administration tools
  - **`!`** `(-8)` OpenSSH (install via the Chocolatey when on Windows 8.1)
  - Telnet client
  - TFTP client
- Languages
  - en-US
  - es-ES
  - fr-FR
  - ja-JP
  - zh-CN
  - Language-specific fonts
- Others
  - **`!`** .NET Framework 3.5
  - Microsoft Defender Application Guard
  - TIFF IFilter
  - Windows Developer Mode
  - Windows Feature Experience Pack
  - Windows Storage Management
  - XPS Viewer

</details>
<!-- markdownlint-enable MD033 -->

## Additional setup

Boxstarter, used in our main setup, is not good at setups requiring keystrokes or other operations. For example, it automatically skips after 30 seconds if it accepts keyboard input on any display. To work around this, we have provided an additional setup batch script that does not use Boxstarter.  
メインのセットアップで使用している Boxstarter はキー入力などの操作を要求するセットアップを不得意としており、例えば何らかの表示をした上でキーボード入力を受け付けると、30 秒で自動的にスキップしてしまう特性があります。これを回避するために、Boxstarter を用いない、追加のセットアップ バッチ スクリプトを用意しました。

Setup will provide voice notification whenever possible if your action is required, so please follow the guidance.  
ユーザーの行動が必要な場合、セットアップはできる限り音声で通知していますので、ガイダンスに従ってください。

### Usage

```PowerShell
PS> .\additional-setup
```

### Apps install

- Unity version 2019.4.31f1 (via Unity Hub)

## Test on Virtualbox

Test require a desktop OS that bash can use. e.g. macOS, Ubuntu desktop.  
テストには bash が使えるデスクトップ OS、例えば、、macOS や Ubuntu などが必要です。

If you are testing on macOS on the ARM64 architecture, please run the setup directly on Parallels, not on this test script.  
ARM64 アーキテクチャの macOS 上でテストする場合は、このテストスクリプトではなく、Parallels 上で直接セットアップを実行してください。

### 1. Dependencies

- [Virtualbox](https://www.virtualbox.org)
- [Vagrant](https://www.vagrantup.com)
  - vagrant-reload plugin

Dependencies auto installation has available on only Mac yet.
In other platform, you should install manually theirs before testing.

### 2. Start to testing environment

```sh
./test win{8.1|10}
```

Specify the version of Windows.

### 3. Start to test

```bat
Admin> cd \vagrant
Admin> .\setup
```

### 4. Destroy

Use vagrant.

```SH
vagrant destory -f
```
