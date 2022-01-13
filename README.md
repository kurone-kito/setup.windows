# Windows auto setup for develop environment

Desktop environment preference for Windows (8.1, 10)
Windows 8.1, 10 向けの作業環境セットアップスクリプト

## Overview

In order to reinstall OS more easily when Windows is unstable, we fully automated the installation of some apps.  
Windows が不安定な時、OS をより手軽に再インストールするために、アプリのインストールを全自動化します。

Two tools: [Chocolatey](https://chocolatey.org) and [BoxStarter](https://boxstarter.org), were very helpful in developing this project.  
このプロジェクトの開発には、[Chocolatey](https://chocolatey.org) と [BoxStarter](https://boxstarter.org) の二つのツールが役立ちました。

## Usage

```PowerShell
PS Admin> .\setup
```

## Test on Virtualbox

Test require a desktop OS that bash can use. e.g. macOS, Ubuntu desktop.  
テストには bash が使えるデスクトップ OS、例えば、、macOS や Ubuntu などが必要です。

### 1. Dependenciea

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

## Test on Windows 11 on Parallels

下記は Apple M1 + macOS Monterey + Parallels Desktop 17 での検証です。
この環境では現状、Vagrant での使用が難しいため、手動の手順を記します。
事前に Microsoft アカウントが必要です。

1. [Windows Insider Preview Downloads](https://www.microsoft.com/software-download/windowsinsiderpreviewiso)
   から、“Windows 11 on ARM Insider Preview” をダウンロードします。
2. ダウンロードした VHDX を開くと、Parallels が自動的に認識し、仮称 PC
   の構築を開始します。
3. 以後、適宜スナップショットを作成することで、手戻りを最小化できます。
4. Windows Update を候補が出現しなくなるまで全て適用し、インストール済みの
   Microsoft Store アプリも全て更新します。
5. ロケールに合わせて、キーボードの設定を更新します。
   1. `Settings` アプリを開き、`Time & Language` > `Language & Region` >
      (Current Language) の中から、`Language option` を選択します。
   2. `Add a keyboard` を選択し、`- Parallels` 接尾辞のあるキーボード
      レイアウトを選択します。
   3. 使用しないキーボード レイアウトを削除します。
6. スタートボタンにおけるコンテキスト メニューから、`Windows Terminal`
   が起動できるかどうかを検証し、そうでない場合再リンクします。
   1. `Settings` アプリを開き、`Apps` > `Advanced app settings` >
      `App execution aliases` を選択します。
   2. 一覧の中から、`Windows Terminal` を無効化し、再度有効化します。
   3. `Windows Terminal` をアンインストールし、`Microsoft Store`
      アプリから再度インストールします。
