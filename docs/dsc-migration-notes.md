# DSC Migration Notes

This document records what happened to each file removed when
`migrate-to-dsc` was merged into `master` (issue #63), and lists the
Windows configuration processing that has no replacement yet.

## Removed files and their relocation

| Removed file | Disposition |
| --- | --- |
| `Vagrantfile` | Not relocated. It defined the Windows VM used for manual E2E validation; that validation mechanism is dropped by this migration and its replacement is explicitly deferred (see roadmap #62's "保留" section). |
| `test` | Not relocated. Shell launcher that provisioned the `Vagrantfile` VM and ran the manual E2E check; removed alongside `Vagrantfile` for the same reason. |
| `additional-setup.cmd` | Not relocated as a separate file. Its role (unblock `libs/*.ps1` and invoke the setup entrypoint) is absorbed into the rewritten `setup.cmd`, which now unblocks scripts and drives `boxstarter.ps1` via `Install-BoxstarterPackage` directly. |
| `boxstarter.min.ps1` | Replaced by `configurations/packages.min.dsc.yaml` (primary path) and `configurations/packages.min.import.json` (degraded-mode fallback) — the "min" profile is now data (a DSC/import document), not a hand-maintained parallel script. |
| `libs/additional-setup.ps1` | Relocated to `libs/post-install.ps1`. The old file only sequenced calls to `mkcert.ps1` / `unity.ps1` / `docker.ps1` (skipping `docker.ps1` under `C:\vagrant`); `post-install.ps1` inlines that logic directly. |
| `libs/docker.ps1` | Relocated to `libs/post-install.ps1` (the "Docker Desktop" section). |
| `libs/edgeTweaks.ps1` | Relocated to `configurations/packages.dsc.yaml`'s `edge.hideFirstRun` `PSDscResources/Registry` resource — a declarative registry-value resource instead of an imperative script. |
| `libs/mkcert.ps1` | Relocated to `libs/post-install.ps1` (the "mkcert" section). |
| `libs/pre-setup.ps1` | Not relocated as a separate file. Its role (unblock scripts, launch Boxstarter against `boxstarter.ps1`) is absorbed into the rewritten `setup.cmd`, which now drives Boxstarter directly via `Install-BoxstarterPackage` rather than delegating to a PowerShell entrypoint script. |
| `libs/unity.ps1` | Relocated to `libs/post-install.ps1` (the "Unity Editor via Unity Hub CLI" section). |
| `t/deploy.ps1` | Not relocated. Deployed `t/sw-launcher.cmd` into the `Vagrantfile` VM for the manual E2E flow; removed alongside `Vagrantfile` / `test` for the same reason. |
| `t/sw-launcher.cmd` | Not relocated. Launched `setup.cmd` from inside the `Vagrantfile` VM as part of the manual E2E flow; removed alongside `Vagrantfile` / `test` for the same reason. |

## Windows configuration processing with no DSC replacement (as of this merge)

The following processing existed in the pre-migration `boxstarter.ps1`
but has no equivalent in `configurations/packages.dsc.yaml`,
`configurations/packages.min.dsc.yaml`, or `libs/*.ps1` after this
merge. Restoring these is out of scope for issue #63 (tracked by
roadmap #62's #64).

### Boxstarter setting commands (5)

Recorded verbatim from the pre-migration `boxstarter.ps1`:

```powershell
Set-ExplorerOptions -showHiddenFilesFoldersDrives -showFileExtensions
Set-StartScreenOptions -DisableBootToDesktop -EnableShowStartOnActiveScreen -EnableShowAppsViewOnStartScreen -EnableSearchEverywhereInAppsView -DisableListDesktopAppsFirst
Set-BoxstarterTaskbarOptions -MultiMonitorOn -MultiMonitorMode All -MultiMonitorCombine Always
Set-WindowsExplorerOptions -EnableShowHiddenFilesFoldersDrives -EnableShowFileExtensions -EnableExpandToOpenFolder -EnableShowRecentFilesInQuickAccess -EnableShowFrequentFoldersInQuickAccess -DisableShowRibbon
Enable-RemoteDesktop
```

### Explorer / Search registry values (4)

| Registry path | Value name | Type | Value |
| --- | --- | --- | --- |
| `HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced` | `NavPaneExpandToCurrentFolder` | DWord (implicit via `Set-ItemProperty`) | `1` |
| `HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced` | `SeparateProcess` | DWord (implicit via `Set-ItemProperty`) | `1` |
| `HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced` | `ShowCompColor` | DWord (implicit via `Set-ItemProperty`) | `1` |
| `HKCU:\Software\Microsoft\Windows\CurrentVersion\Search` | `SearchboxTaskbarMode` | DWord (implicit via `Set-ItemProperty`) | `1` |

### Disk Cleanup sageset registrations (19)

All 19 entries share the same registry shape: base path
`HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\<name>`,
value name `StateFlags0001`, type `DWord`, value `2`.

`<name>` values:

```text
Active Setup Temp Folders
BranchCache
D3D Shader Cache
Delivery Optimization Files
Diagnostic Data Viewer database files
Downloaded Program Files
Internet Cache Files
Old ChkDsk Files
Recycle Bin
RetailDemo Offline Content
Setup Log Files
System error memory dump files
System error minidump files
Temporary Files
Thumbnail Cache
Update Cleanup
User file versions
Windows Defender
Windows Error Reporting Files
```
