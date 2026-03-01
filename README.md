# Windows Auto-Setup for Development Environment

![GitHub repo size](https://img.shields.io/github/repo-size/kurone-kito/setup.windows)

🌐 [日本語](README.ja.md)

Automated desktop environment setup for Windows 10 / 11, covering
development (Node.js, .NET, Rust, VRChat/Unity), gaming, and daily use.

## Architecture

```text
setup.cmd                        ← single entry point
  └─ Boxstarter (reboot-resilient orchestrator)
       └─ boxstarter.ps1
            ├─ Phase 0: OS support check        (libs/os-guard.ps1)
            ├─ Phase 1: Environment detection
            ├─ Phase 2: winget configure (DSC)   (configurations/packages.dsc.yaml)
            ├─ Phase 3: Chocolatey (fonts, vb-cable, posh-git)
            ├─ Phase 4: Architecture-conditional packages
            ├─ Phase 5: Post-install             (libs/post-install.ps1)
            │    ├─ fnm → Node.js 20/22/24/25
            │    ├─ cargo → git-vrc
            │    ├─ dotnet tool → VPM CLI
            │    ├─ Unity Hub → Unity 2022.3.22f1
            │    ├─ mkcert → local CA
            │    └─ Docker Desktop → image pulls
            └─ Phase 6: Windows Update & teardown
```

## OS Support

| Priority | OS                               | Status                            |
| :------: | -------------------------------- | --------------------------------- |
|    1     | Windows 11 Pro / Enterprise      | ✅ Fully supported                 |
|    2     | Windows 11 Home                  | ✅ Supported (Hyper-V unavailable) |
|    3     | Windows 10 22H2 Pro / Enterprise | ⚠️ EOL warning, best-effort        |
|    4     | Windows 10 22H2 Home             | ⚠️ EOL warning, best-effort        |
|    5     | Windows Server 2019+             | ⚠️ Limited testing                 |
|          | Windows 10 < 22H2                | ❌ Unsupported                     |

## System Requirements

- x86_64 or ARM64 processor
- Windows 10 22H2 (build 19045) or later
- At least 2 GB of RAM
- At least 150 GB of free disk space
- Internet connection

## Usage

Clone or download this repository, then run:

```cmd
.\setup.cmd
```

> **Note:** Do not run from a network (UNC) path. `cmd.exe` does not support
> UNC paths and may cause unexpected behavior.

The script will:

1. Install **Chocolatey** and **Boxstarter** if not already present
2. Launch `boxstarter.ps1` via `Install-BoxstarterPackage` (reboot-resilient)
3. Apply the **WinGet Configuration (DSC)** to install ~80 packages declaratively
4. Install remaining packages via Chocolatey (fonts and audio drivers)
5. Run post-install setup (Node.js, Rust/cargo packages, Unity, Docker images)
6. Enable Microsoft Update and run Windows Update

Boxstarter handles reboots automatically. If a reboot interrupts the process,
simply re-run `.\setup.cmd` — all phases are **idempotent**.

### Minimal Install

To use the lighter configuration (development tools only, no gaming/media):

Edit `boxstarter.ps1` and change the DSC file reference from
`packages.dsc.yaml` to `packages.min.dsc.yaml`.

## What Gets Installed

### Via WinGet Configuration (DSC)

See [configurations/packages.dsc.yaml](configurations/packages.dsc.yaml) for
the full list. Key categories:

- **Runtimes:** .NET SDK 8/10, Rust, Visual C++ Redistributable
- **Development:** Git, GitHub CLI, fnm, Android Studio
- **VRChat:** Unity Hub, VRChat Creator Companion, VRCX
- **Editors:** VS Code, Cursor, Sublime Text 4, Vim, Neovim
- **CLI Tools:** 7-Zip, FFmpeg, fzf, jq, yq, chezmoi, tealdeer, mkcert
- **Browsers:** Chrome, Firefox ESR, Tor Browser
- **Gaming:** Steam, Epic Games, EA Desktop, Minecraft, StepMania
- **Communication:** Discord, Slack, Zoom
- **Productivity:** Notion, OneNote, PowerToys, Grammarly, Kindle

### Via Chocolatey (winget unavailable)

- Fonts: HackGen, HackGen Nerd, Lato
- Audio: VB-CABLE Virtual Audio Device

### Via PowerShellGet

- posh-git

### Via Post-Install Scripts

- **Node.js** (via fnm): v20, v22, v24 (LTS), v25 (Current)
- **git-vrc** (via cargo): VRChat Git integration
- **VPM CLI** (via dotnet tool): VRChat package manager
- **Unity 2022.3.22f1**: Required by VRChat SDK/VCC
- **mkcert**: Local CA for HTTPS development
- **Docker images**: Base images (alpine, debian, ubuntu, node variants)

### Conditional (non-ARM64 only)

- Docker Desktop
- Oracle VirtualBox
- nektos/act (GitHub Actions local runner)

## Configuration vs. Settings

This project is responsible for **installation only**. OS preferences,
shell configuration, and dotfiles should be managed separately
(e.g., via [dotfiles](https://github.com/kurone-kito/dotfiles)).

## Testing

The legacy Vagrant-based test environment has been removed. Modern testing
approaches under consideration:

- **Windows Sandbox** — lightweight, disposable (no reboot testing)
- **Hyper-V VM** — full testing including reboots (Pro edition required)
- **GitHub Actions Windows Runner** — CI automation (desktop environment differences)

## License

[MIT](LICENSE)
