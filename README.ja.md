# Windows 開発環境 自動セットアップ

![GitHub repo size](https://img.shields.io/github/repo-size/kurone-kito/setup.windows)

🌐 [English](README.md)

Windows 10 / 11 向けのデスクトップ環境自動セットアップスクリプトです。
開発（.NET, Rust, VRChat/Unity）、ゲーミング、日常利用まで
一通りの環境を構築します。

## アーキテクチャ

```text
setup.cmd                        ← 唯一のエントリーポイント
  └─ Boxstarter（再起動耐性のあるオーケストレーター）
       └─ boxstarter.ps1
            ├─ Phase 0: OS サポート確認          (libs/os-guard.ps1)
            ├─ Phase 1: 環境検出
            ├─ Phase 2: winget configure または   (configurations/packages.dsc.yaml
            │    winget import（縮退モード）        または configurations/packages.import.json,
            │                                      libs/strategy.ps1)
            ├─ Phase 3: Chocolatey（フォント、vb-cable）+ posh-git（PowerShellGet）
            ├─ Phase 4: アーキテクチャ依存パッケージ
            ├─ Phase 5: インストール後セットアップ (libs/post-install.ps1)
            │    ├─ dotnet tool → VPM CLI
            │    ├─ install.ps1 → CodeRabbit CLI
            │    ├─ install.ps1 → Cursor CLI
            │    ├─ Unity Hub → Unity 2022.3.22f1
            │    ├─ mkcert → ローカル CA
            │    └─ Docker Desktop → イメージ pull
            ├─ Phase 6: リモートデスクトップ         (Enable-RemoteDesktop)
            └─ Phase 7: Windows Update & 後処理
```

## OS サポート

| 優先度 | OS                               | 状態                              |
| :----: | -------------------------------- | --------------------------------- |
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
3. **WinGet Configuration (DSC)** で 100 個のパッケージを宣言的にインストール
   （利用できない場合は **`winget import`**（縮退モード）にフォール
   バックし、適用できなかったリソースを報告）
4. Chocolatey で残りのパッケージ（フォント、オーディオドライバ）をインストール
5. インストール後セットアップ（VPM CLI, Unity, mkcert, Docker イメージ）
6. Microsoft Update を有効化し、Windows Update を実行

Boxstarter が自動的に再起動を処理します。再起動により処理が中断した場合は、
`.\setup.cmd` を再実行してください。全フェーズは**冪等**です。

### 最小インストール

軽量構成（開発ツールのみ、ゲーミング/メディア系なし）を使用する場合は、
`boxstarter.ps1` の Phase 2 にある `$ConfigProfile` を `'full'` から
`'min'` に変更してください。この 1 つの値が DSC ファイル・対応する
`import.json`・未適用リソース一覧をまとめて切り替えます。

## インストールされるもの

### WinGet Configuration (DSC) 経由

完全なリストは
[configurations/packages.dsc.yaml](configurations/packages.dsc.yaml) を
参照してください。主要カテゴリ:

- **ランタイム:** .NET SDK 8/10, Rust, Visual C++ 再頒布可能パッケージ
- **開発:** Git, Android Studio
- **VRChat:** Unity Hub, VRChat Creator Companion, VRCX
- **エディタ:** VS Code, Sublime Text 4, Vim, Neovim
- **CLI ツール:** 7-Zip, FFmpeg, fzf, jq, yq, chezmoi, tealdeer, mkcert
- **ブラウザ:** Chrome, Firefox ESR, Tor Browser
- **ゲーミング:** Steam, Epic Games, EA Desktop, Minecraft, StepMania
- **コミュニケーション:** Discord, Slack, Zoom
- **生産性:** Notion, OneNote, PowerToys, Grammarly, Kindle

> **注意:** GitHub CLI（`gh`）はこのリポジトリではインストールしなくなりました。
> [dotfiles](https://github.com/kurone-kito/dotfiles) が `mise` 経由で
> 管理します。

### Chocolatey 経由（winget にないもの）

- フォント: HackGen, HackGen Nerd, Lato
- オーディオ: VB-CABLE Virtual Audio Device

### PowerShellGet 経由

- posh-git

### インストール後スクリプト経由

- **VPM CLI**（dotnet tool 経由）: VRChat パッケージマネージャー
- **CodeRabbit CLI**（公式 `install.ps1` 経由）: AI コードレビュー CLI。
  バージョン固定はせず常に最新版へ更新する。Git for Windows が必須
- **Cursor CLI**（公式 `install.ps1` 経由）: 単体バイナリの AI コーディング
  エージェント CLI（`cursor-agent`）。バージョン固定はせず常に最新版へ
  更新する。前提コマンドは不要
- **Unity 2022.3.22f1**: VRChat SDK/VCC 必須バージョン
- **mkcert**: HTTPS 開発用ローカル CA
- **Docker イメージ**: ベースイメージ (alpine, debian, ubuntu, node 各種)

> **注意:** Node.js のバージョン管理はこのリポジトリの責務ではありません。
> [dotfiles](https://github.com/kurone-kito/dotfiles) が `mise` 経由で
> 管理します。

### 条件付き（非ARM64 のみ）

- Docker Desktop
- Oracle VirtualBox
- nektos/act（GitHub Actions ローカルランナー）

## 設定について

このプロジェクトは**インストールのみ**を責務とします。OS 設定、シェル設定、
dotfiles は別プロジェクト
（例: [dotfiles](https://github.com/kurone-kito/dotfiles)）で管理してください。

### 所有境界

<!-- cspell:ignore Inno -->

| 層 | 所有 | 例 |
| ------------------------ | --------------------------------------- | ---------------------------------------------------------------- |
| winget / DSC（本リポジトリ） | GUI アプリ、MSI・Inno・WiX・burn 系インストーラ、OS 設定 | Git, 7-Zip, GnuPG, Neovim, .NET SDK, Steam, Unity Hub |
| dotfiles（mise） | 委譲済みの CLI ツール、言語ランタイム | Node.js, GitHub CLI, ghq, GitHub Copilot CLI, git-vrc |
| dotfiles（管理対象 User PATH） | Windows の User PATH | `mise\shims`, `WinGet\Links`, `data.wingetUserPath.packages` 宣言分 |
| Chocolatey（本リポジトリ） | フォント、オーディオドライバ | HackGen, VB-CABLE |

すべての CLI ツールが dotfiles 側へ移ったわけではありません —
上表「例」列にある第 1 波の委譲対象 5 つのみです。本リポジトリは
他にも多くの CLI ツールを winget から直接インストールしています
（前述の[インストールされるもの](#インストールされるもの)の
「CLI ツール」を参照。例: 7-Zip, FFmpeg, fzf, jq, yq, chezmoi,
tealdeer, mkcert）。

本リポジトリ自身のスクリプトは Windows の User PATH を管理・書き込み
しません。例外は 3 つ、サードパーティ製の Unity CLI インストーラ、
CodeRabbit CLI インストーラ、Cursor CLI インストーラです
（`libs/unity-cli-installer.ps1` が Unity 公式の `install.ps1` を、
`libs/coderabbit-cli-installer.ps1` が CodeRabbit 公式の `install.ps1`
を、`libs/cursor-cli-installer.ps1` が Cursor 公式の `install.ps1` を
それぞれ呼び出し、各インストーラ自身の既知の副作用として User PATH へ
エントリを追加します — 本リポジトリのコードが直接書き込むものでは
ありません）。それ以外の
User PATH の所有権は dotfiles の管理対象パス reconciler にあります。
dotfiles の
`docs/winget-user-path.md` がその仕組みを、
`home/dot_config/powershell/lib/managed-paths.ps1` が管理対象パス集合の
単一の真実の源をそれぞれ記録しています。

### `setup.cmd` の後に `chezmoi apply` が必要

`setup.cmd` 単体では、もう Node.js・GitHub CLI・ghq・GitHub Copilot CLI・
git-vrc のいずれもインストールされません — この 5 つはすべて dotfiles の
`mise` 設定から入るようになりました。本リポジトリは `chezmoi` バイナリ
自体は導入します（前述の[インストールされるもの](#インストールされるもの)
参照）が、`chezmoi apply` を自動実行することはありません。`mise` が
`PATH` に反映された状態の新しいシェルで、`setup.cmd` 完了後に自分で
実行してください（`mise` が未反映のまま先に実行すると、ツール導入
ステップが黙って no-op になります）。dotfiles を適用しないと成立しない
操作の詳細な一覧と、先に実行してしまった場合の復旧手順は
[`docs/dotfiles-boundary.md`](docs/dotfiles-boundary.md#4-operations-gated-on-chezmoi-apply)
を、これらのツールを dotfiles 側へ寄せた根拠（`winget upgrade` を
ローカル / RDP の対話セッションから実行し、SSH からは実行しないという
運用ルールを含む）は
[§7](docs/dotfiles-boundary.md#7-why-cli-tools-moved-to-dotfiles-at-all)
を参照してください。

## テスト環境

レガシーの Vagrant ベースのテスト環境は削除しました。
現在検討中のモダンなテスト手法:

- **Windows Sandbox** — 軽量・使い捨て（再起動テスト不可）
- **Hyper-V VM** — 再起動含む完全テスト（Pro エディション以上が必要）
- **GitHub Actions Windows Runner** — CI 自動化（デスクトップ環境との差異あり）

## ライセンス

[MIT](LICENSE)
