# Windows auto setup for developing environment

Desktop environment preference for Windows (10 to 11)  
Windows 10 〜 11 向けの作業環境セットアップスクリプト

## Overview

To reinstall OS more easily when Windows is unstable, we fully
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
- At least 150 GB of free space is required as system storage.
- Internet connection

## Usage

### A. Quick install (Recommended)

1. Open the following link **in Microsoft Edge**:  
   下記のリンクを **Microsoft Edge で**開きます:  
   <https://boxstarter.org/package/url?https://raw.githubusercontent.com/kurone-kito/setup.windows/master/boxstarter.ps1>
   - Or if, for some reason, you only want to install a minimal number of apps,
     use the URL below instead:  
     または諸事情で最小限のアプリのみをインストールしたい場合は、
     代わりに下記の URL を使用します:  
     <https://boxstarter.org/package/url?https://raw.githubusercontent.com/kurone-kito/setup.windows/master/boxstarter.min.ps1>
2. A confirmation dialog will appear asking permission to download,
   run ClickOnce, and allow UAC. Please allow all of them.  
   ダウンロード、ClickOnce の実行、そして UAC の許可を求める確認ダイアログが表示されます。
   それらにおいて、全て許可してください。
3. The terminal will start, and the setup will prompt you to enter the password
   for the current user account. It is required for an automatic reboot during
   setup; You should enter it correctly and press Enter at the end.  
   端末が起動し、セットアップで現在のユーザーアカウントのパスワードを入力するよう
   促されます。これは、セットアップ中に自動で再起動するために必要なものなので、
   正しく入力し、最後に Enter キーを押してください。
4. Some time rebooted, the installation is complete; it will wait for you to
   enter the Enter key to exit.  
   複数回再起動し、インストールが完了すると、Enter キーの入力待ちとなるため、
   Enter キーを入力して終了します。
5. Finally, restart Windows manually to complete the setup.  
   手動で Windows を再起動して、セットアップ完了です。

### B. Classic install

Clone or download and unzip this repository in advance, and run the following
command:  
予めこのリポジトリをクローン、もしくはダウンロードと解凍した上で、
下記のコマンドを実行します:

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

Unless otherwise specified, as a general rule, install via Winget.  
特筆なき場合、原則として Winget 経由でインストールします。

<details><summary>CLI Apps</summary>

|  note   | description                                                                         |
| :-----: | :---------------------------------------------------------------------------------- |
| **`!`** | **DEPENDENCIES**: Removing this app may cause this setup to stop working correctly. |
|  `-A`   | without ARM64 Architecture                                                          |

#### Benchmark

- [Fastfetch](https://github.com/fastfetch-cli/fastfetch)

#### Configuration tools

- [chezmoi](https://www.chezmoi.io/)

#### Convert tools for Media binary

- [FFmpeg](https://www.ffmpeg.org/)
- [ImageMagick](https://imagemagick.org/index.php)

#### Convert tools for Texts

- **`!`** [jq](https://stedolan.github.io/jq/)
- **`!`** [yq](https://mikefarah.gitbook.io/yq)

#### Database

- [SQLite](https://www.sqlite.org/)

#### Development

- [ANTLR](https://www.antlr.org/) (via Chocolatey)
- [fnm: Fast Node Manager](https://fnm.vercel.app/)
  - Node.js (via fnm)
    - v18 LTS Hydrogen
    - v20 LTS Iron
    - v22 LTS Jod
    - v23
    - v24
- [Mono](https://www.mono-project.com/)
- [Microsoft Visual Studio Build Tools](https://www.visualstudio.com/)
  - version 2015
  - version 2019
  - version 2022
- [Rust](https://www.rust-lang.org/)
  - Microsoft Visual Studio ABI

#### Documentation

- [Tealdeer](https://dbrgn.github.io/tealdeer/)
- [wkhtmltopdf](https://wkhtmltopdf.org/)

#### Files management

- [7-Zip](https://www.7-zip.org/)

#### Packages manager

- **`!`** [BoxStarter](https://boxstarter.org) (via Chocolatey)
- **`!`** [Chocolatey](https://chocolatey.org) (via Chocolatey)
  - [Chocolatey `choco://` Protocol support](https://github.com/bcurran3/ChocolateyPackages/tree/master/choco-protocol-support)
    (via Chocolatey)
- **`!`** [Windows Package Manager](https://learn.microsoft.com/windows/package-manager/)
  (via Chocolatey)
- [Scoop](https://scoop.sh) (directly install)
- [SteamCMD](https://developer.valvesoftware.com/wiki/SteamCMD)

#### Runtime

- [Visual C++ Redistributable Packages](https://docs.microsoft.com/cpp/windows/latest-supported-vc-redist)
  (via Chocolatey)
- **`!`** [Microsoft .NET Framework Runtime](https://support.microsoft.com/topic/9d23f658-3b97-68ab-d013-aa3c3e7495e0)
- [Microsoft .NET SDK](https://dotnet.microsoft.com/)
  - v6
  - v8

#### Testing

- [mkcert](https://mkcert.dev/)
- [ngrok](https://ngrok.com/)

#### Version control system

- [Apache Subversion](https://subversion.apache.org/) (via Chocolatey)
- **`!`** [Git](https://git-scm.com/)
  - **`!`** [Git Large File Storage](https://git-lfs.github.com/)
  - **`!`** [git-delta: A viewer for git and diff output](https://github.com/dandavison/delta)
- [GitHub CLI](https://cli.github.com/)

#### Remote

- [awscli](https://aws.amazon.com/cli/)
- [SwitchHosts](https://switchhosts.vercel.app/)

#### Shell

- **`!`** [Microsoft PowerShell](https://microsoft.com/PowerShell)
- [Microsoft PowerShell Core](https://microsoft.com/PowerShell)
- [Oh My Posh](https://ohmyposh.dev/)
- [posh-git](https://dahlbyk.github.io/posh-git/) (via Chocolatey)

#### Signature

- **`!`** [GnuPG: The GNU Privacy Guard](https://gnupg.org/)

#### Text Browsing

- [cheat](https://github.com/cheat/cheat) (via Chocolatey)
- [Links](http://links.twibright.com/)

#### Text editors

- [Neovim](https://neovim.io/)
- [Vim](https://www.vim.org/)

#### Virtualizations

- [act](https://github.com/nektos/act)
- `(-A)` [Vagrant](https://www.vagrantup.com/)
  - plugins (via Vagrant)
    - [Vagrant Reload Provisioner](https://github.com/aidanns/vagrant-reload)

</details>

<details><summary>Desktop Apps</summary>

| note | description                |
| :--: | :------------------------- |
| `-A` | without ARM64 Architecture |

#### 3D Modeling

- [Blender](https://www.blender.org/)
- [FreeCAD](https://www.freecadweb.org/)

#### Audios, Videos, and Broadcasting

- [Apple Music](https://www.apple.com/apple-music/)
- [iZotope Product Portal](https://www.izotope.com/)
- [OBS Studio](https://obsproject.com/)
- [Reflector 4](https://www.airsquirrels.com/reflector/)
- [VB-CABLE Virtual Audio Device](https://vb-audio.com/Cable/)
- [VoiceMeeter](https://vb-audio.com/Voicemeeter/)

#### Authentication

- [Keybase](https://keybase.io/)

#### Benchmark

- [MAXON Cinebench](https://www.maxon.net/ja/cinebench)

#### Configuration tools

- [Microsoft PowerToys](https://learn.microsoft.com/windows/powertoys/)

#### Development

- [Android SDK](https://developer.android.com/)
- [Unity Hub](https://unity3d.com/)
- [VRChat Creator Companion](https://vcc.docs.vrchat.com/)

#### Devices

- [AutoHotkey](https://www.autohotkey.com/)
- [logicool G Hub](https://gaming.logicool.co.jp/innovation/g-hub.html)

#### Documents and Office apps

- [Amazon Kindle](https://www.amazon.com/kindle)

#### Games

- [Epic Games Launcher](https://www.epicgames.com/store/download)
- [EA Desktop](https://www.ea.com/ea-app)
- [Minecraft Java Edition](https://www.minecraft.net/)
- [Steam](https://store.steampowered.com/)
- [Stepmania](https://www.stepmania.com/)

#### Memos and Tasks

- [Grammarly](https://www.grammarly.com/)
- [Microsoft To Do](https://to-do.microsoft.com/)
- [Notion](https://www.notion.so/)

#### Messaging

- [Discord](https://discord.com/)
- [Facebook Messenger](https://www.messenger.com/)
- [Skype](https://www.skype.com/)
- [Slack](https://slack.com/)
- [Zoom](https://zoom.us/)

#### Packages manager

- [Chocolatey GUI](https://github.com/chocolatey/ChocolateyGUI)
- [WingetUI](https://www.marticliment.com/wingetui/)

#### Remote

- [Real VNC Viewer](https://www.realvnc.com/connect/download/viewer/)
- [TeamViewer](https://www.teamviewer.com/)
- [Windows Terminal](https://github.com/microsoft/terminal)

#### Runtime

- [Microsoft DirectX](https://www.microsoft.com/download/details.aspx?id=35)

#### Social

- [Facebook](https://www.facebook.com/)
- [Instagram](https://www.instagram.com/)
- [Threads by Instagram](https://www.threads.net/)
- [VRCX](https://github.com/vrcx-team/VRCX/tree/master)
- [X/Twitter](https://x.com/)

#### Storage

- [Adobe Creative Cloud](https://www.adobe.com/creativecloud.html)
- [iCloud](https://www.apple.com/icloud/)

#### Text editors

- [Cursor](https://www.cursor.so/)
- [Sublime Text](https://www.sublimetext.com/)
- [Visual Studio Code](https://code.visualstudio.com/)

#### Virtualizations

- `(-A)` [Docker Desktop](https://www.docker.com/products/docker-desktop)
- [DOSBox-X](https://dosbox-x.com)
- `(-A)` [Oracle VM Virtualbox + Extension Pack](https://www.virtualbox.org/)
- [Windows Subsystem for Linux](https://docs.microsoft.com/windows/wsl/)
- [Ubuntu 24.04 LTS for WSL2](https://ubuntu.com/download/desktop)

#### Web browsers

- [Google Chrome](https://www.google.com/chrome/)
- [Mozilla Firefox ESR](https://www.mozilla.org/firefox/)
- [Tor Browser](https://www.torproject.org/projects/torbrowser.html)

</details>

<details><summary>Fonts</summary>

- [白源: HackGen Nerd](https://github.com/yuru7/HackGen) (via Chocolatey)
- [Lato](https://fonts.google.com/specimen/Lato) (via Chocolatey)

</details>

## Additional setup

Boxstarter, used in our main setup, is not good at setups requiring keystrokes
or other operations. For example, it automatically skips after 30 seconds if it
accepts keyboard input on any display. To work around this, we have provided an
additional setup batch script that does not use Boxstarter.  
メインのセットアップで使用している Boxstarter はキー入力などのインタラクションを
要求するセットアップを不得意としており、例えば何らかの表示をした上で
キーボード入力を受け付けると、30 秒で自動的にスキップしてしまう特性があります。
これを回避するために、Boxstarter を用いない、追加のセットアップ バッチ
スクリプトを用意しました。

Setup will provide voice notification whenever possible if your action is
required, so please follow the guidance.  
ユーザーの行動が必要な場合、セットアップはできる限り音声で通知していますので、
ガイダンスに従ってください。

### Usage

```PowerShell
PS> .\additional-setup
```

### Apps install

- [Unity Editor](https://unity3d.com/) (via Unity Hub)
  - version 2019.4.31f1
    - Module: Android Build Support
    - Module: Documentation
    - Module: Language Pack (Japanese)
  - version 2022.3.6f1
    - Module: Android Build Support
    - Module: Documentation
    - Module: Language Pack (Japanese)
  - version 2022.3.22f1
    - Module: Android Build Support
    - Module: Documentation
    - Module: Language Pack (Japanese)

### Initialize for web-frontend development environment

The script creates and installs a local CA in the system root store, and
generates locally-trusted certificates using the mkcert.  
セットアップ スクリプトは mkcert を使用して、システムルートストアにローカル
CA を作成してインストールし、ローカルで信頼できる証明書を生成します。

Also, by starting Firefox in this process, if the root store does not exist,
it will be initialized.  
また、この工程で Firefox を起動することにより、
ルートストアが存在しない場合、初期化します。

### Pulls some docker images

<details><summary>list</summary>

| Image                         | Tag                                                                                                                                                  |
| :---------------------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------- |
| `hello-world`                 | _`latest`_                                                                                                                                           |
| `alpine`                      | _`latest`_                                                                                                                                           |
| `busybox`                     | _`latest`_                                                                                                                                           |
| `debian`                      | _`latest`_                                                                                                                                           |
| `ubuntu`                      | _`latest`_                                                                                                                                           |
| `docker`                      | `dind`, `git`, _`latest`_                                                                                                                            |
| `node`                        | `18`, `18-alpine`, `18-slim`, `20`, `20-alpine`, `20-slim`, `22`, `22-alpine`, `22-slim`, `23`, `23-alpine`, `23-slim`, `24`, `24-alpine`, `24-slim` |
| `ghcr.io/catthehacker/ubuntu` | `act-22.04`, `act-latest`, ~~`ubuntu:full-20.04`~~, ~~`ubuntu:full-latest`~~                                                                         |

</details>

## Test on Virtualbox

Notice: The test environment provided by this repository has been out of
maintenance for some time and may not work. Therefore, it may be more
reliable to build your virtual environment and run it instead of using
this one.  
注意: このリポジトリはテスト用の仮想環境を提供していますが、
長らくメンテナンスをサボっていたため、動作しない可能性が高いです。
各々で独自の仮想環境を構築し、その上で動作検証をした方がより確実でしょう。

The test requires a desktop OS that Bash can use. e.g. macOS, Ubuntu desktop.  
テストには Bash が使えるデスクトップ OS、例えば、、macOS や Ubuntu などが必要です。

If you are testing on macOS on the ARM64 architecture, please run the setup
directly on Parallels, not on this test script.  
ARM64 アーキテクチャの macOS 上でテストする場合は、このテストスクリプトではなく、
Parallels 上で直接セットアップを実行してください。

### 1. Dependencies

- [Virtualbox](https://www.virtualbox.org)
- [Vagrant](https://www.vagrantup.com)
  - vagrant-reload plugin

Dependencies auto installation is available on only Mac.
In other platforms, you should install manually theirs before testing.

### 2. Start testing environment

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

## See also

- [kurone-kito/dotfiles](https://github.com/kurone-kito/dotfiles)
- [kurone-kito/setup.macos](https://github.com/kurone-kito/setup.macos)

## Contributing

Welcome to contribute to this repository! For more details,
please refer to [CONTRIBUTING.md](.github/CONTRIBUTING.md).

## License

MIT
