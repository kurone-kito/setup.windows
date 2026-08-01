# DSC Migration Notes

This document records what happened to each file removed when
`migrate-to-dsc` was merged into `master` (issue #63), and the
disposition of the Windows configuration processing that had no DSC
equivalent at that point (declared as a DSC resource by issue #64, or
recorded as staying imperative and why).

## `dsc.yaml` is the single source of truth

`configurations/packages.dsc.yaml` (full profile) and
`configurations/packages.min.dsc.yaml` (min profile) are hand-
maintained. Everything else under `configurations/` is generated from
one of them by `scripts/Build-Configurations.ps1` and must never be
hand-edited:

| Generated file | Generated from | Purpose |
| --- | --- | --- |
| `packages.import.json` | `packages.dsc.yaml` | `winget import` fallback for the degraded route (issue #65) |
| `packages.unapplied.json` | `packages.dsc.yaml` | Machine-readable list of resources the import.json route cannot express (non-`WinGetPackage` resources and `properties.assertions` entries) |
| `packages.min.import.json` | `packages.min.dsc.yaml` | Same as above, min profile |
| `packages.min.unapplied.json` | `packages.min.dsc.yaml` | Same as above, min profile |

To add, remove, or change a package or resource: edit the relevant
`dsc.yaml` file only, then regenerate both of its outputs:

```powershell
./scripts/Build-Configurations.ps1 -DscPath ./configurations/packages.dsc.yaml
./scripts/Build-Configurations.ps1 -DscPath ./configurations/packages.min.dsc.yaml
```

The generator is deterministic (same input always produces byte-
identical output) and requires the `powershell-yaml` module. CI's
`configuration-drift` job (`.github/workflows/lint.yml`) reruns it on
every push/PR and fails if the committed generated files don't match
what regeneration produces, so a `dsc.yaml` edit that isn't followed
by regeneration is caught before merge rather than silently drifting.

## The import route is degraded mode, and routes never switch mid-run

`boxstarter.ps1`'s Phase 2 picks one of two routes via
`libs/strategy.ps1`'s `Test-ConfigurationStrategy`, before any package
installation starts:

- **`dsc`**: `winget configure` against `packages.dsc.yaml`. Applies
  every resource -- packages, `PSDscResources/Registry` values, and the
  `OsVersion` assertion.
- **`import`**: `winget import` against `packages.import.json`,
  **degraded mode**. `import.json` can only express `PackageIdentifier`s
  (schema: <https://aka.ms/winget-packages.schema.2.0.json>, not a file
  checked into this repository), so the Registry resources and the
  assertion are silently out of scope for this command -- Phase 2
  reads `packages.unapplied.json` afterward and warns about each one
  by name, so this is visible to the person running setup instead of a
  silent gap.

Both routes check `$LASTEXITCODE` after the winget call and treat any
non-zero exit as a failure: Phase 2 logs the failed route, exit code,
and the exact command, then aborts setup (`Write-Error` + `return`,
matching Phase 0's precedent for a setup-blocking condition).

**Routes never switch after Phase 2 starts**, on either route's
failure. Re-routing risks a *partial apply* on top of whatever the
first attempt already changed, and the two routes cover different
resource scopes -- a `PSDscResources/Registry` or `OsVersion` failure
under `winget configure` would not even be attempted under
`winget import`, so switching would not retry the same failure, it
would silently drop it. (A bad package ID or a transient single-
package error is the one failure class that genuinely repeats under
either route, since both install the same packages -- but the policy
is "never switch," not "switch only when it would help," precisely
because Phase 2 cannot tell which failure class it hit from the exit
code alone.) `Test-ConfigurationStrategy` runs once, before Phase 2,
and its result is not re-evaluated.

The import route passes `--ignore-unavailable` to `winget import`, so
one package unavailable on the current machine/region does not abort
the whole import. This narrows what counts as a Phase 2 failure on
this route to *installation* failures, not *availability* failures --
an asymmetry with the dsc route's exit-code check, accepted because
availability gaps are still visible in winget's own per-package output
in the Boxstarter log.

## Verifying package ids before running setup

A wrong or stale `WinGetPackage` id is not fixed by Phase 2's route
fallback (above): the `import` route queries the same winget, the
same id, against the same source, and fails identically. `scripts/
Test-PackageIds.ps1` checks id validity independently of route
selection and without installing anything, via `winget show --exact
--id <id> --source <source>`:

```powershell
./scripts/Test-PackageIds.ps1 -DscPath ./configurations/packages.dsc.yaml
./scripts/Test-PackageIds.ps1 -DscPath ./configurations/packages.min.dsc.yaml
```

It reuses `libs/configuration-builder.ps1`'s `Split-DscResource` to
extract id/source pairs, so parsing is not duplicated between the
generation track (issue #66) and this verification track.

Results are classified three ways -- **Confirmed** (count only),
**NotFound**, and **Indeterminate** -- and the two failure classes are
never merged. Only winget-cli's own documented
`APPINSTALLER_CLI_ERROR_NO_APPLICATIONS_FOUND` exit code
(`-1978335212`, from
[`AppInstallerErrors.h`](https://github.com/microsoft/winget-cli/blob/master/src/AppInstallerSharedLib/Public/AppInstallerErrors.h))
counts as NotFound; every other non-zero exit (a source-open failure,
a network error, anything this script doesn't specifically recognize)
is Indeterminate. Reporting a network outage as a bad package id would
destroy this check's own credibility, so the exit codes differ too:
`1` if any id was NotFound, `2` if only Indeterminate ids occurred, `0`
if every id was Confirmed.

Run this after adding or changing a package in either `dsc.yaml` file,
and whenever setup fails on a specific package -- to tell a genuine
id/source problem apart from a transient install failure before
re-running the whole setup. Requires a real `winget` on PATH, so it
only runs on Windows; not wired into CI (a Linux runner has no
`winget` to check against -- see issue #69).

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

## Disposition of the remaining Windows configuration processing

Issue #63 left the following pre-migration `boxstarter.ps1` processing
without a DSC equivalent. Issue #64 investigated each item against
Boxstarter's own source (`chocolatey/boxstarter`,
`Boxstarter.WinConfig/*.ps1`) and, for each, either declared it as a
`PSDscResources/Registry` resource in `configurations/packages.dsc.yaml`,
restored it imperatively, or recorded why it should not be restored at
all.

### Boxstarter setting commands (5)

Recorded verbatim from the pre-migration `boxstarter.ps1`:

```powershell
Set-ExplorerOptions -showHiddenFilesFoldersDrives -showFileExtensions
Set-StartScreenOptions -DisableBootToDesktop -EnableShowStartOnActiveScreen -EnableShowAppsViewOnStartScreen -EnableSearchEverywhereInAppsView -DisableListDesktopAppsFirst
Set-BoxstarterTaskbarOptions -MultiMonitorOn -MultiMonitorMode All -MultiMonitorCombine Always
Set-WindowsExplorerOptions -EnableShowHiddenFilesFoldersDrives -EnableShowFileExtensions -EnableExpandToOpenFolder -EnableShowRecentFilesInQuickAccess -EnableShowFrequentFoldersInQuickAccess -DisableShowRibbon
Enable-RemoteDesktop
```

Disposition of each command:

- **`Set-ExplorerOptions -showHiddenFilesFoldersDrives -showFileExtensions`**
  — Not declared as a separate resource. This cmdlet is deprecated in
  Boxstarter's own source and internally forwards to
  `Set-WindowsExplorerOptions -EnableShowHiddenFilesFoldersDrives
  -EnableShowFileExtensions`, writing the exact same
  `Explorer\Advanced\Hidden` / `HideFileExt` values as the fourth
  command below. The original script called both, so this call was
  fully redundant; declaring `explorer.showHiddenFiles` /
  `explorer.showFileExtensions` once (from the fourth command) covers
  it without duplication.
- **`Set-StartScreenOptions ...`** — Not declared. All five switches
  this call sets (`OpenAtLogon`, `MonitorOverride`, `MakeAllAppsDefault`,
  `GlobalSearchInApps`, `DesktopFirst`) write under
  `HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartPage`,
  a Windows 8/8.1 Start *Screen* key. Boxstarter's own implementation
  guards every write with `if (Test-Path -Path $startPageKey)`; on
  Windows 10/11 — the only OS tier this repository's
  `Microsoft.Windows.Developer/OsVersion` assertion (build 19045+)
  supports — that key does not exist, so the pre-migration script
  wrote nothing here on any machine this repo targets. Declaring it as
  a `Force: true` DSC resource would *create* registry state the old
  script never created, which is a behavior change, not a faithful
  migration. Not declared, and not restored to `boxstarter.ps1` either
  (the call was already absent after #63's rewrite — this only
  documents why it stays absent). This is the one command in this list
  where the discriminating fact is that its target key is dead across
  the *entire* supported OS range; `Explorer\Advanced`, `Explorer`,
  and `Explorer\Ribbon` (used by the declared resources below) are all
  live on Windows 10 22H2+, so the same `Test-Path`-guard concern does
  not apply to them.
- **`Set-BoxstarterTaskbarOptions -MultiMonitorOn -MultiMonitorMode All
  -MultiMonitorCombine Always`** — Declared as
  `taskbar.multiMonitorEnabled` (`MMTaskbarEnabled=1`),
  `taskbar.multiMonitorMode` (`MMTaskbarMode=0`), and
  `taskbar.multiMonitorGlomLevel` (`MMTaskbarGlomLevel=0`), all under
  `HKCU:\...\Explorer\Advanced`. The function also has a
  byte-array-manipulation branch (`StuckRects2\Settings`) for
  dock/auto-hide switches, but the original call never used those
  switches, so it isn't represented here. The function ends with
  `Restart-Explorer`, which DSC does not replicate — the setting takes
  effect at next sign-in instead of immediately.
- **`Set-WindowsExplorerOptions ...`** — Declared as
  `explorer.showHiddenFiles` (`Advanced\Hidden=1`),
  `explorer.showFileExtensions` (`Advanced\HideFileExt=0`),
  `explorer.navPaneExpandToCurrentFolder`
  (`Advanced\NavPaneExpandToCurrentFolder=1`),
  `explorer.showRecentInQuickAccess` (`Explorer\ShowRecent=1`),
  `explorer.showFrequentInQuickAccess` (`Explorer\ShowFrequent=1`), and
  `explorer.hideRibbon` (`Explorer\Ribbon\MinimizedStateTabletModeOff=1`).
  This function also ends with `Restart-Explorer` (same caveat as
  above).
- **`Enable-RemoteDesktop`** — Not declared; kept as a literal call in
  `boxstarter.ps1`'s Phase 6. Boxstarter's implementation enables
  Remote Desktop through WMI method calls
  (`Win32_TerminalServiceSetting.SetAllowTsConnections`,
  `Win32_TSGeneralSetting.SetUserAuthenticationRequired`), not a direct
  registry write, so `PSDscResources/Registry` cannot express it.
  (Its own doc comment also claims it enables a firewall rule, but the
  implementation contains no firewall-rule code — that claim is not
  repeated here since it wasn't verified against the source.)

### Explorer / Search registry values (4)

Declared in `configurations/packages.dsc.yaml`, all HKCU /
`securityContext: current`:

| Resource id | Registry path | Value name | Type | Value |
| --- | --- | --- | --- | --- |
| `explorer.navPaneExpandToCurrentFolder` | `HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced` | `NavPaneExpandToCurrentFolder` | Dword | `1` |
| `explorer.separateProcess` | `HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced` | `SeparateProcess` | Dword | `1` |
| `explorer.showCompColor` | `HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced` | `ShowCompColor` | Dword | `1` |
| `search.searchboxTaskbarMode` | `HKCU:\Software\Microsoft\Windows\CurrentVersion\Search` | `SearchboxTaskbarMode` | Dword | `1` |

### Disk Cleanup sageset registrations (19)

Declared in `configurations/packages.dsc.yaml` as `sageset.<slug>`, all
HKLM / `securityContext: elevated`. All 19 entries share the same
registry shape: base path
`HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\<name>`,
value name `StateFlags0001`, type `Dword`, value `2`. `Force: true`
follows the same style as the resources above; on a system where a
given `VolumeCaches\<name>` subkey does not already exist, it will
create the key rather than fail.

| Resource id | `<name>` |
| --- | --- |
| `sageset.activeSetupTempFolders` | Active Setup Temp Folders |
| `sageset.branchCache` | BranchCache |
| `sageset.d3dShaderCache` | D3D Shader Cache |
| `sageset.deliveryOptimizationFiles` | Delivery Optimization Files |
| `sageset.diagnosticDataViewerDatabaseFiles` | Diagnostic Data Viewer database files |
| `sageset.downloadedProgramFiles` | Downloaded Program Files |
| `sageset.internetCacheFiles` | Internet Cache Files |
| `sageset.oldChkDskFiles` | Old ChkDsk Files |
| `sageset.recycleBin` | Recycle Bin |
| `sageset.retailDemoOfflineContent` | RetailDemo Offline Content |
| `sageset.setupLogFiles` | Setup Log Files |
| `sageset.systemErrorMemoryDumpFiles` | System error memory dump files |
| `sageset.systemErrorMinidumpFiles` | System error minidump files |
| `sageset.temporaryFiles` | Temporary Files |
| `sageset.thumbnailCache` | Thumbnail Cache |
| `sageset.updateCleanup` | Update Cleanup |
| `sageset.userFileVersions` | User file versions |
| `sageset.windowsDefender` | Windows Defender |
| `sageset.windowsErrorReportingFiles` | Windows Error Reporting Files |

### min profile inclusion

None of the resources above are included in
`configurations/packages.min.dsc.yaml`. The min profile's existing
non-package resources (`windows11-native-nvme-driver-{1,2,3}`) enable
hardware functionality that can matter for correct operation on
affected devices; the Explorer/Taskbar/Search/sageset resources above
are convenience UI/cleanup preferences with no functional necessity.
Keeping the min profile limited to packages plus that one
hardware-enablement exception preserves its "minimal" intent.
