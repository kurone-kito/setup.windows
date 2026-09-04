# Windows Auto-Setup for Development Environment

![GitHub repo size](https://img.shields.io/github/repo-size/kurone-kito/setup.windows)

🌐 [日本語](README.ja.md)

Automated desktop environment setup for Windows 10 / 11, covering
development (.NET, Rust, VRChat/Unity), gaming, and daily use.

## Architecture

```text
setup.cmd                        ← single entry point
  └─ Boxstarter (reboot-resilient orchestrator)
       └─ boxstarter.ps1
            ├─ Phase 0: OS support check        (libs/os-guard.ps1)
            ├─ Phase 1: Environment detection
            ├─ Phase 2: winget configure or      (configurations/packages.dsc.yaml
            │    winget import (degraded mode)    or configurations/packages.import.json,
            │                                      libs/strategy.ps1)
            ├─ Phase 3: Chocolatey (fonts, vb-cable) + posh-git (PowerShellGet)
            ├─ Phase 4: Architecture-conditional packages
            ├─ Phase 5: Post-install             (libs/post-install.ps1)
            │    ├─ dotnet tool → VPM CLI
            │    ├─ install.ps1 → CodeRabbit CLI
            │    ├─ install script → Cursor CLI
            │    ├─ winget --scope machine --installer-type wix → PowerShell 7 (pwsh)
            │    ├─ Unity Hub → Unity 2022.3.22f1
            │    ├─ mkcert → local CA
            │    └─ Docker Desktop → image pulls
            ├─ Phase 6: Remote Desktop            (Enable-RemoteDesktop)
            └─ Phase 7: Windows Update & teardown
```

## OS Support

| Priority | OS                               | Status                             |
| :------: | -------------------------------- | ---------------------------------- |
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
3. Apply the **WinGet Configuration (DSC)** to install 100 packages
   declaratively when available, otherwise fall back to
   **`winget import`** (degraded mode) and report any resources it
   could not apply
4. Install remaining packages via Chocolatey (fonts and audio drivers)
5. Run post-install setup (VPM CLI, Unity, mkcert, Docker images)
6. Enable Microsoft Update and run Windows Update

Boxstarter handles reboots automatically. If a reboot interrupts the process,
simply re-run `.\setup.cmd` — all phases are **idempotent**.

### Minimal Install

To use the lighter configuration (development tools only, no gaming/media):

Edit `boxstarter.ps1`'s Phase 2 and change `$ConfigProfile` from `'full'`
to `'min'`. This single value selects the DSC file, its `import.json`
fallback, and its unapplied-resources list together.

## What Gets Installed

### Via WinGet Configuration (DSC)

See [configurations/packages.dsc.yaml](configurations/packages.dsc.yaml) for
the full list. Key categories:

- **Runtimes:** .NET SDK 8/10, Rust, Visual C++ Redistributable
- **Development:** Git, Android Studio
- **VRChat:** Unity Hub, VRChat Creator Companion, VRCX
- **Editors:** VS Code, Sublime Text 4, Vim, Neovim
- **CLI Tools:** 7-Zip, FFmpeg, fzf, jq, yq, chezmoi, tealdeer, mkcert
- **Browsers:** Chrome, Firefox ESR, Tor Browser
- **Gaming:** Steam, Epic Games, EA Desktop, Minecraft, StepMania
- **Communication:** Discord, Slack, Zoom
- **Productivity:** Notion, OneNote, PowerToys, Grammarly, Kindle

> **Note:** GitHub CLI (`gh`) is no longer installed by this repository.
> It is [dotfiles](https://github.com/kurone-kito/dotfiles)'s
> responsibility, via `mise`.

### Via Chocolatey (winget unavailable)

- Fonts: HackGen, HackGen Nerd, Lato
- Audio: VB-CABLE Virtual Audio Device

### Via PowerShellGet

- posh-git

### Via Post-Install Scripts

- **VPM CLI** (via dotnet tool): VRChat package manager
- **CodeRabbit CLI** (via official `install.ps1`): AI code review CLI,
  always updated to latest (no version pin); requires Git for Windows
- **Cursor CLI** (via official install script): standalone
  `cursor-agent` AI coding agent CLI, always updated to latest (no
  version pin); no prerequisite command required
- **PowerShell 7 (pwsh)** (via
  `winget install --scope machine --installer-type wix`): installed at
  machine scope, not through WinGet Configuration (DSC), because
  `Microsoft.WinGet.DSC/WinGetPackage` cannot request `--scope
  machine`. `--installer-type wix` forces the WiX/MSI installer over
  the MSIX bundle winget would otherwise pick (see
  `docs/dsc-migration-notes.md` for the risk that a future manifest
  drops WiX/MSI entirely, and why this isn't mitigated with a
  `--version` pin). Machine scope keeps pwsh's path stable enough to
  later serve as Windows OpenSSH Server's `DefaultShell`
- **Unity 2022.3.22f1**: Required by VRChat SDK/VCC
- **mkcert**: Local CA for HTTPS development
- **Docker images**: Base images (alpine, debian, ubuntu, node variants)

> **Note:** Node.js version management is not handled by this repository.
> It is [dotfiles](https://github.com/kurone-kito/dotfiles)'s
> responsibility, via `mise`.

### Conditional (non-ARM64 only)

- Docker Desktop
- Oracle VirtualBox
- nektos/act (GitHub Actions local runner)

## Configuration vs. Settings

This project is responsible for **installation only**. OS preferences,
shell configuration, and dotfiles should be managed separately
(e.g., via [dotfiles](https://github.com/kurone-kito/dotfiles)).

### Ownership boundary

<!-- cspell:ignore Inno -->

| Layer                          | Owns                                                      | Examples                                                                          |
| ------------------------------ | --------------------------------------------------------- | --------------------------------------------------------------------------------- |
| winget / DSC (this repository) | GUI apps, MSI/Inno/WiX/burn-style installers, OS settings | Git, 7-Zip, GnuPG, Neovim, .NET SDK, Steam, Unity Hub                             |
| dotfiles (mise)                | Delegated CLI tools, language runtimes                    | Node.js, GitHub CLI, ghq, GitHub Copilot CLI, git-vrc                             |
| dotfiles (managed User PATH)   | The Windows User PATH                                     | `mise\shims`, `WinGet\Links`, packages declared in `data.wingetUserPath.packages` |
| Chocolatey (this repository)   | Fonts, audio drivers                                      | HackGen, VB-CABLE                                                                 |

Not every CLI tool moved to dotfiles — only the five first-wave
delegation targets in the "Examples" column above did. This
repository still installs many other CLI tools directly via winget
(see "CLI Tools" under [What Gets Installed](#what-gets-installed)
above, e.g. 7-Zip, FFmpeg, fzf, jq, yq, chezmoi, tealdeer, mkcert).

This repository's own scripts do not manage or write the Windows User
PATH — the three exceptions are the third-party Unity CLI installer
(`libs/unity-cli-installer.ps1` invokes Unity's own `install.ps1`), the
third-party CodeRabbit CLI installer
(`libs/coderabbit-cli-installer.ps1` invokes CodeRabbit's own
`install.ps1`), and the third-party Cursor CLI installer
(`libs/cursor-cli-installer.ps1` invokes Cursor's own official install
script), which each persist an entry there as their own side effect,
not something this repository's code does directly. User PATH
ownership
otherwise belongs to dotfiles' managed-path reconciler: dotfiles'
`docs/winget-user-path.md` documents the mechanism, and
`home/dot_config/powershell/lib/managed-paths.ps1` is its single
source of truth for the managed-path set.

### `chezmoi apply` is required after `setup.cmd`

`setup.cmd` alone no longer installs Node.js, GitHub CLI, ghq, GitHub
Copilot CLI, or git-vrc — all five now come from dotfiles' `mise`
configuration. This repository installs the `chezmoi` binary itself
(see [What Gets Installed](#what-gets-installed) above) but never runs
`chezmoi apply` automatically; run it yourself after `setup.cmd`
completes, from a fresh shell so `mise` is already on `PATH` (an
earlier apply, before `mise` is reachable, silently no-ops the
tool-install step). See
[`docs/dotfiles-boundary.md`](docs/dotfiles-boundary.md#4-operations-gated-on-chezmoi-apply)
for the full list of operations that do not work until dotfiles has
been applied and the recovery path if the first apply ran too early,
and [§7](docs/dotfiles-boundary.md#7-why-cli-tools-moved-to-dotfiles-at-all)
for the rationale behind moving these tools to dotfiles in the first
place (including the operational rule to run `winget upgrade` from a
local or RDP interactive session, never over SSH).

## Troubleshooting

### `setup.cmd` reboots repeatedly and `[Phase 0]` never appears

**Symptom**: running `setup.cmd` reboots the machine over and over, and
none of `boxstarter.ps1`'s `[Phase 0]`-`[Phase 7]` console output ever
shows up.

**Cause**: before `boxstarter.ps1` ever runs, Boxstarter's own
pre-flight check evaluates several pending-reboot registry indicators
and reboots immediately if any are set — without invoking this repo's
setup logic even once. One of those indicators,
`PendingFileRenameOperations`, is a known false-positive source (some
antivirus products leave stale entries there that a normal reboot does
not clear).

`setup.cmd` now runs a pre-check (`libs/reboot-guard.ps1`'s
`Test-PendingRebootIndicators`) immediately before it invokes
Boxstarter -- after the Chocolatey/Boxstarter bootstrap steps, so a
reboot-pending state left behind by either of those is still caught. If
any indicator is set, it prints which one(s) and aborts instead of
letting Boxstarter get stuck in the loop above.

**Investigation**: from an elevated PowerShell prompt, check the same
indicators directly:

```powershell
Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction SilentlyContinue
# Computer-rename pending (mismatch, or either key present):
(Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName' -Name ComputerName -ErrorAction SilentlyContinue).ComputerName
(Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName' -Name ComputerName -ErrorAction SilentlyContinue).ComputerName
Test-Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\JoinDomain'
Test-Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\AvoidSpnSet'
```

**Recovery**:

1. Reboot once normally, then re-run `setup.cmd`. A genuine pending
   reboot usually clears this way.
2. If the indicator doesn't clear (most often a stale
   `PendingFileRenameOperations` entry), remove it after confirming the
   referenced file operation is no longer relevant:

   ```powershell
   Remove-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations
   ```

3. If the machine ever got stuck in the reboot loop before this guard
   existed (or after bypassing it), Boxstarter leaves side effects
   behind that it would normally undo in its own Phase 7 teardown —
   which never ran. Check and restore as needed:
   - `EnableLUA` under
     `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System`
     should be `1` (UAC enabled)
   - `AutoAdminLogon` under
     `HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon`
     should be removed or `0`
   - Remove `boxstarter-post-restart.bat` from
     `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\` if
     present

To bypass the pre-check entirely (for example, once you've confirmed an
indicator is a known false positive), set
`SETUP_IGNORE_PENDING_REBOOT=1` before re-running `setup.cmd`.

## Testing

The legacy Vagrant-based test environment has been removed. Modern testing
approaches under consideration:

- **Windows Sandbox** — lightweight, disposable (no reboot testing)
- **Hyper-V VM** — full testing including reboots (Pro edition required)
- **GitHub Actions Windows Runner** — CI automation (desktop environment differences)

## License

[MIT](LICENSE)
