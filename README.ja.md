# Windows 開発環境 自動セットアップ

![GitHub repo size](https://img.shields.io/github/repo-size/kurone-kito/setup.windows)

🌐 [English](README.md)

Windows 10 / 11 向けのデスクトップ環境自動セットアップスクリプトです。
開発（Node.js, .NET, Rust, VRChat/Unity）、ゲーミング、日常利用まで
一通りの環境を構築します。

## アーキテクチャ

```text
setup.cmd                        ← 唯一のエントリーポイント
  └─ Boxstarter（再起動耐性のあるオーケストレーター）
       └─ boxstarter.ps1
            ├─ Phase 0: OS サポート確認          (libs/os-guard.ps1)
            ├─ Phase 1: 環境検出
            ├─ Phase 2: winget configure (DSC)   (configurations/packages.dsc.yaml)
            ├─ Phase 3: Chocolatey（フォント、vb-cable、posh-git）
            ├─ Phase 4: アーキテクチャ依存パッケージ
            ├─ Phase 5: インストール後セットアップ (libs/post-install.ps1)
            │    ├─ fnm → Node.js 20/22/24/25
            │    ├─ cargo → git-vrc
            │    ├─ dotnet tool → VPM CLI
            │    ├─ Unity Hub → Unity 2022.3.22f1
            │    ├─ mkcert → ローカル CA
            │    └─ Docker Desktop → イメージ pull
            └─ Phase 6: Windows Update & 後処理
```

## OS サポート

| 優先度 | OS                               | 状態                             |
| :----: | -------------------------------- | -------------------------------- |
|   1    | Windows 11 Pro / Enterprise      | ✅ 完全サポート                   |
|   2    | Windows 11 Home                  | ✅ サポート（Hyper-V 不可）       |
|   3    | Windows 10 22H2 Pro / Enterprise | ⚠️ EOL 警告あり、ベストエフォート |
|   4    | Windows 10 22H2 Home             | ⚠️ EOL 警告あり、ベストエフォート |
|   5    | Windows Server 2019+             | ⚠️ テスト限定的                   |
|        | Windows 10 22H2 未満             | ❌ 非サポート                     |

## システム要件

- x86_64 または ARM64 プロセッサ
- Windows 10 22H2（ビルド 19045）以降
- 2 GB 以上の RAM
- 150 GB 以上の空きディスク容量
- インターネット接続

## 使い方

このリポジトリをクローンまたはダウンロード・解凍した上で、以下を実行します:

```cmd
.\setup.cmd
```

> **注意:** ネットワーク（UNC）パスからの実行は避けてください。
> `cmd.exe` が UNC パスに対応していないため、予期しない動作となる可能性があります。

スクリプトは以下を実行します:

1. **Chocolatey** と **Boxstarter** が未インストールならインストール
2. `Install-BoxstarterPackage` 経由で `boxstarter.ps1` を起動（再起動耐性あり）
3. **WinGet Configuration (DSC)** で約 80 個のパッケージを宣言的にインストール
4. Chocolatey で残りのパッケージ（フォント、オーディオドライバ）をインストール
5. インストール後セットアップ（Node.js, Rust/cargo パッケージ, Unity, Docker イメージ）
6. Microsoft Update を有効化し、Windows Update を実行

Boxstarter が自動的に再起動を処理します。再起動により処理が中断した場合は、
`.\setup.cmd` を再実行してください。全フェーズは**冪等**です。

### 最小インストール

軽量構成（開発ツールのみ、ゲーミング/メディア系なし）を使用する場合は、
`boxstarter.ps1` 内の DSC ファイル参照を `packages.dsc.yaml` から
`packages.min.dsc.yaml` に変更してください。

## インストールされるもの

### WinGet Configuration (DSC) 経由

完全なリストは
[configurations/packages.dsc.yaml](configurations/packages.dsc.yaml) を
参照してください。主要カテゴリ:

- **ランタイム:** .NET SDK 8/10, Rust, Visual C++ 再頒布可能パッケージ
- **開発:** Git, GitHub CLI, fnm, Android Studio
- **VRChat:** Unity Hub, VRChat Creator Companion, VRCX
- **エディタ:** VS Code, Cursor, Sublime Text 4, Vim, Neovim
- **CLI ツール:** 7-Zip, FFmpeg, fzf, jq, yq, chezmoi, tealdeer, mkcert
- **ブラウザ:** Chrome, Firefox ESR, Tor Browser
- **ゲーミング:** Steam, Epic Games, EA Desktop, Minecraft, StepMania
- **コミュニケーション:** Discord, Slack, Zoom
- **生産性:** Notion, OneNote, PowerToys, Grammarly, Kindle

### Chocolatey 経由（winget にないもの）

- フォント: HackGen, HackGen Nerd, Lato
- オーディオ: VB-CABLE Virtual Audio Device

### PowerShellGet 経由

- posh-git

### インストール後スクリプト経由

- **Node.js**（fnm 経由）: v20, v22, v24 (LTS), v25 (Current)
- **git-vrc**（cargo 経由）: VRChat Git 統合
- **VPM CLI**（dotnet tool 経由）: VRChat パッケージマネージャー
- **Unity 2022.3.22f1**: VRChat SDK/VCC 必須バージョン
- **mkcert**: HTTPS 開発用ローカル CA
- **Docker イメージ**: ベースイメージ (alpine, debian, ubuntu, node 各種)

### 条件付き（非ARM64 のみ）

- Docker Desktop
- Oracle VirtualBox
- nektos/act（GitHub Actions ローカルランナー）

## 設定について

このプロジェクトは**インストールのみ**を責務とします。OS 設定、シェル設定、
dotfiles は別プロジェクト
（例: [dotfiles](https://github.com/kurone-kito/dotfiles)）で管理してください。

## テスト環境

レガシーの Vagrant ベースのテスト環境は削除しました。
現在検討中のモダンなテスト手法:

- **Windows Sandbox** — 軽量・使い捨て（再起動テスト不可）
- **Hyper-V VM** — 再起動含む完全テスト（Pro エディション以上が必要）
- **GitHub Actions Windows Runner** — CI 自動化（デスクトップ環境との差異あり）

## ライセンス

[MIT](LICENSE)
