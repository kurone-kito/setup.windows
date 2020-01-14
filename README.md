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
