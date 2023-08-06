<!-- markdownlint-disable MD024 -->

# Windows auto setup for develop environment

Desktop environment preference for Windows (10 to 11)  
Windows 10 〜 11 向けの作業環境セットアップスクリプト

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

## System requirements

- x86, x64, or ARM64 computer
- Windows 10 21H2 or later, or 11
- At least 2 GB of physical RAM.
- At least 150 GB of free space is required as a system storage.
- Internet connection

## Usage

### A. Quick install (Recommended)

1. Open the follow link **in Microsoft Edge**:  
   下記のリンクを **Microsoft Edge で**開きます:  
   <https://boxstarter.org/package/url?https://raw.githubusercontent.com/kurone-kito/setup.windows/master/boxstarter.ps1>
   - Or if, for some reason, you only want to install a minimal number of apps, use the URL below instead:  
     または諸事情で最小限のアプリのみをインストールしたい場合は、代わりに下記の URL を使用します:  
     <https://boxstarter.org/package/url?https://raw.githubusercontent.com/kurone-kito/setup.windows/master/boxstarter.min.ps1>
2. A confirmation dialog will appear asking permission to download, run ClickOnce, and allow UAC. Please allow all of them.  
   ダウンロード、ClickOnce の実行、そして UAC の許可を求める確認ダイアログが表示されます。それらにおいて、全て許可してください。
3. The terminal will start, and the setup will prompt you to enter the password for the current user account. It is required for an automatic reboot during setup; You should enter it correctly and press Enter at the end.  
   端末が起動し、セットアップで現在のユーザーアカウントのパスワードを入力するよう促されます。これは、セットアップ中に自動で再起動するために必要なものなので、正しく入力し、最後に Enter キーを押してください。
4. Some time rebooted, the installation is complete; it will wait for you to enter the Enter key to exit.  
   複数回再起動し、インストールが完了すると、Enter キーの入力待ちとなるため、Enter キーを入力して終了します。
5. Finally, restart Windows manually to complete the setup.  
   手動で Windows を再起動して、セットアップ完了です。

### B. Classic install

Clone or download and unzip this repository in advance, and run the following command:  
予めこのリポジトリをクローン、もしくはダウンロードと解凍した上で下記のコマンドを実行します:

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
|  `-M`   | Exclude when using minimal setups                                                   |

#### Configuration tools

- [chezmoi](https://www.chezmoi.io/)
- [winfetch](https://github.com/kiedtl/winfetch)

#### Convert tools for Media binary

- `(-M)` [FFmpeg](https://www.ffmpeg.org/)
- `(-M)` [ImageMagick](https://imagemagick.org/index.php)

#### Convert tools for Texts

- [jq](https://stedolan.github.io/jq/)

#### Database

- [SQLite](https://www.sqlite.org/)

#### Development

- [ANTLR](https://www.antlr.org/)
- [CMake](https://cmake.org)
- [fnm: Fast Node Manager](https://fnm.vercel.app/)
  - Node.js (via fnm)
    - v16 LTS Gallium
    - v18 LTS Hydrogen
    - v20
- [Mono](https://www.mono-project.com/)
- `(-M)` [Microsoft Visual Studio Build Tools](https://www.visualstudio.com/)
  - version 2017
  - version 2019
  - version 2022
- [Rust](https://www.rust-lang.org/)
  - GNU ABI
  - Microsoft Visual Studio ABI

#### Documentation

- [Graphviz](https://graphviz.org/)
- `(-A)` [pandoc](https://pandoc.org/)
- [PlantUML](https://plantuml.com/)
- [tldr pages](https://tldr.sh)
- [wkhtmltopdf](https://wkhtmltopdf.org/)

#### Files management

- `(-M)` [7-Zip](https://www.7-zip.org/)

#### Packages manager

- **`!`** [BoxStarter](https://boxstarter.org)
- **`!`** [Chocolatey](https://chocolatey.org)
- [Chocolatey `choco://` Protocol support](https://github.com/bcurran3/ChocolateyPackages/tree/master/choco-protocol-support)
- [Scoop](https://scoop.sh) (directly install)
- [SteamCMD](https://developer.valvesoftware.com/wiki/SteamCMD)

#### Runtime

- [Visual C++ Redistributable Packages](https://docs.microsoft.com/cpp/windows/latest-supported-vc-redist)
- [AdoptOpenJDK](https://adoptopenjdk.net/)
- **`!`** [Microsoft .NET Framework Runtime](https://support.microsoft.com/topic/9d23f658-3b97-68ab-d013-aa3c3e7495e0)
- [Microsoft .NET Core Runtime](https://dotnet.microsoft.com/download#macos)

#### Testing

- [mkcert](https://mkcert.dev/)
- `(-M)` [ngrok](https://ngrok.com/)

#### Version control system

- [Apache Subversion](https://subversion.apache.org/)
- **`!`** [Git](https://git-scm.com/)
  - **`!`** [Git Large File Storage](https://git-lfs.github.com/)
  - [git-delta: A viewer for git and diff output](https://github.com/dandavison/delta)
- [GitHub CLI](https://cli.github.com/)
- [GLab: GitLab CLI tool](https://glab.readthedocs.io/)

#### Remote

- [awscli](https://aws.amazon.com/cli/)
- `(-MX)` [OpenSSH](https://www.openssh.com/) (install via the Windows feature when on Windows 10 or 11)

#### Shell

- **`!`** [Microsoft PowerShell](https://microsoft.com/PowerShell)
- [Microsoft PowerShell Core](https://microsoft.com/PowerShell)
- [Oh My Posh](https://ohmyposh.dev/)
- [posh-git](https://dahlbyk.github.io/posh-git/)
- [sudo](https://github.com/janhebnes/chocolatey-packages/tree/master/Sudo)

#### Signature

- **`!`** [GnuPG: The GNU Privacy Guard](https://gnupg.org/)
- `(-M)` [Unbound](https://www.nlnetlabs.nl/projects/unbound/)

#### Text Browsing

- [cheat](https://github.com/cheat/cheat)
- [ELinks](http://www.elinks.cz/)

#### Text editors

- [Vim](https://www.vim.org/)

#### Virtualizations

- [act](https://github.com/nektos/act)
- [GitLab Runner](https://gitlab.com/gitlab-org/gitlab-runner)
- `(-A)` [Vagrant](https://www.vagrantup.com/)
  - plugins (via Vagrant)
    - [vagrant-disksize](https://github.com/sprotheroe/vagrant-disksize)
    - [Vagrant Reload Provisioner](https://github.com/aidanns/vagrant-reload)
    - [vagrant-vbguest](https://github.com/dotless-de/vagrant-vbguest)

</details>
<!-- markdownlint-enable MD033 -->

<!-- markdownlint-disable MD033 -->
<details><summary>Desktop Apps</summary>

| note | description                       |
| :--: | :-------------------------------- |
| `-A` | without ARM64 Architecture        |
| `-M` | Exclude when using minimal setups |

#### 3D Modeling

- `(-M)` [Blender](https://www.blender.org/)
- `(-M)` [FreeCAD](https://www.freecadweb.org/)

#### Audios, Videos, and Broadcasting

- `(-M)` [OBS Studio](https://obsproject.com/)
- `(-M)` [Reflector 4](https://www.airsquirrels.com/reflector/)
- `(-M)` [VB-CABLE Virtual Audio Device](https://vb-audio.com/Cable/)
- `(-AM)` [VoiceMeeter](https://vb-audio.com/Voicemeeter/)
- `(-M)` [VSTHost](https://www.hermannseib.com/english/vsthost.htm)

#### Authentication

- `(-M)` [Authy Desktop](https://www.authy.com/)
- `(-M)` [Keybase](https://keybase.io/)

#### Cloud storages

- `(-AM)` [Dropbox](https://www.dropbox.com/)

#### Development

- `(-M)` [Android SDK](https://developer.android.com/)
- `(-M)` [Unity Hub](https://unity3d.com/)

#### Devices

- `(-M)` [AutoHotkey](https://www.autohotkey.com/)
- `(-M)` [scrcpy](https://github.com/Genymobile/scrcpy)
- `(-M)` [logicool G Hub](https://gaming.logicool.co.jp/innovation/g-hub.html)
- `(-M)` [Raspberry Pi Imager](https://www.raspberrypi.org/software/)

#### Documents and Office apps

- `(-M)` [Amazon Kindle](https://www.amazon.com/kindle)

#### Games

- `(-M)` [EPIC Games Launcher](https://www.epicgames.com/store/download)
- `(-M)` [Origin (EA Desktop)](https://www.origin.com/)
- `(-M)` [Minecraft Java Edition](https://www.minecraft.net/)
- `(-M)` [Steam](https://store.steampowered.com/)
- `(-M)` [Stepmania](https://www.stepmania.com/)

#### Memos and Tasks

- `(-M)` [Grammarly](https://www.grammarly.com/)
- `(-M)` [Notion](https://www.notion.so/)

#### Messaging and Socials

- `(-M)` [Discord](https://discord.com/)
- `(-M)` [Gitter](https://gitter.im/)
- `(-M)` [Mattermost / with CLI tools](https://mattermost.com/)
- `(-M)` [Zoom](https://zoom.us/)

#### Packages manager

- `(-M)` [Chocolatey GUI](https://github.com/chocolatey/ChocolateyGUI)

#### Remote

- `(-M)` [Amazon Workspaces](https://clients.amazonworkspaces.com/)
- `(-A)` [OpenVPN](https://openvpn.net/)
- `(-M)` [Real VNC Viewer](https://www.realvnc.com/connect/download/viewer/)
- `(-M)` [TeamViewer](https://www.teamviewer.com/)

#### Runtime

- [Microsoft DirectX](https://www.microsoft.com/download/details.aspx?id=35)
- Microsoft XNA Framework
  - [v3.1](https://www.microsoft.com/download/details.aspx?id=15163)
  - [v4.0](https://www.microsoft.com/download/details.aspx?id=20914)
- `(-M)` [RPG Tkool VX / Ace RTP](https://tkool.jp)

#### Text editors

- `(-M)` [Sublime Text](https://www.sublimetext.com/)
- [Visual Studio Code](https://code.visualstudio.com/)

#### Virtualizations

- [Docker Desktop](https://www.docker.com/products/docker-desktop)
- `(-M)` [DOSBox-X](https://dosbox-x.com)
- `(-AM)` [Oracle VM Virtualbox + Extension Pack](https://www.virtualbox.org/)
- [Windows Subsystem for Linux](https://docs.microsoft.com/windows/wsl/)
- [Ubuntu 22.04 LTS for WSL2](https://ubuntu.com/download/desktop)

#### Web browsers

- [Google Chrome](https://www.google.com/chrome/)
- [Chromium](https://www.chromium.org/Home)
- `(-M)` [Insomnia](https://insomnia.rest/)
- [Mozilla Firefox ESR](https://www.mozilla.org/firefox/)
- `(-M)` [Tor Browser](https://www.torproject.org/projects/torbrowser.html)

</details>
<!-- markdownlint-enable MD033 -->

<!-- markdownlint-disable MD033 -->
<details><summary>Fonts</summary>

- [Cascadia Code](https://github.com/microsoft/cascadia-code)
- [Fira Code: free monospaced font with programming ligatures](https://github.com/tonsky/FiraCode)
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
|  `-M`   | Exclude when using minimal setups                                                   |

- Virtualization features
  - **`!`** Hyper-V
  - **`!`** Virtual Machine Platform
  - **`!`** Hypervisor Platform
  - **`!`** Windows Subsystem for Linux
- Network client
  - NFS Client
  - NFS Administration tools
  - **`!`** OpenSSH
  - Telnet client
  - TFTP client
- Languages
  - en-US
  - `(-M)` es-ES
  - `(-M)` fr-FR
  - ja-JP
  - `(-M)` zh-CN
- Others
  - **`!`** .NET Framework 3.5
  - Microsoft Defender Application Guard
  - TIFF IFilter
  - Windows Developer Mode
  - Windows Feature Experience Pack
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

- [Unity version 2019.4.31f1](https://unity3d.com/) (via Unity Hub)
  - Module: Android Build Support
  - Module: Documentation
  - Module: Language Pack (Japanese)

### Initialize for web-frontend development environment

The script creates and installs a local CA in the system root store, and generates locally-trusted certificates using the mkcert.  
セットアップ スクリプトは mkcert を使用して、システムルートストアにローカル CA を作成してインストールし、ローカルで信頼できる証明書を生成します。

Also, by starting Firefox in this process, if the root store does not exist, it will be initialized.  
また、この工程で Firefox を起動することにより、ルートストアが存在しない場合、初期化します。

### Pulls some docker images

<!-- markdownlint-disable MD033 -->
<details><summary>list</summary>

| Image                         | Tag                                                                                              |
| :---------------------------- | :----------------------------------------------------------------------------------------------- |
| `hello-world`                 | _`latest`_                                                                                       |
| `alpine`                      | _`latest`_                                                                                       |
| `busybox`                     | _`latest`_                                                                                       |
| `debian`                      | _`latest`_                                                                                       |
| `ubuntu`                      | _`latest`_                                                                                       |
| `docker`                      | `dind`, `git`, _`latest`_                                                                        |
| `node`                        | `16`, `16-alpine` `16-bullseye-slim`, `18`, `18-alpine`, `18-slim`, `20`, `20-alpine`, `20-slim` |
| `gitlab/gitlab-runner`        | _`latest`_                                                                                       |
| `ghcr.io/catthehacker/ubuntu` | `act-22.04`, `act-latest`, ~~`ubuntu:full-20.04`~~, ~~`ubuntu:full-latest`~~                     |

</details>
<!-- markdownlint-enable MD033 -->

## Test on Virtualbox

Notice: The test environment provided by this repository has been out of
maintenance for some time and may not work. Therefore, it may be more
reliable to build your virtual environment and run it instead of using
this one.  
注意: このリポジトリはテスト用の仮想環境を提供していますが、
長らくメンテナンスをサボっていたため、動作しない可能性が高いです。
各々で独自の仮想環境を構築し、その上で動作検証をした方がより確実でしょう。

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
