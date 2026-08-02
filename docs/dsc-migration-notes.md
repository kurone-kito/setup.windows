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
same id, against the same source, and fails identically.
`scripts/Test-PackageIds.ps1` checks id validity independently of
route selection and without installing anything, via
`winget show --exact --id <id> --source <source>`:

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
only runs on Windows -- not wired into CI yet (issue #69 confirmed
`winget` itself is usable on GitHub Actions' `windows-latest` runner,
but whether to actually add a CI job for `scripts/Test-PackageIds.ps1`
is a separate decision, out of that issue's scope).

## Is `winget` usable on GitHub Actions' Windows runner? (issue #69)

Investigated whether `scripts/Test-PackageIds.ps1` (above) could run
in CI on a `windows-latest` GitHub Actions runner, via a temporary
`workflow_dispatch`/push-triggered probe workflow (removed after this
investigation, per the issue's own scope -- no permanent CI job was
added).

**Runner**: `windows-latest`, image `windows-2025-vs2026`
(`ImageVersion=20260714.173.1`), Microsoft Windows Server 2025
(`10.0.26100`, Datacenter). **Observed**: 2026-08-01T23:27Z (run
[30723356166](https://github.com/kurone-kito/setup.windows/actions/runs/30723356166)).
`windows-latest` is a moving target -- GitHub periodically retargets it
to a newer image -- so this observation is tied to the image version
above, not to "`windows-latest`" as a permanent guarantee.

| Check | Result |
| --- | --- |
| `winget` preinstalled | Yes -- found at `C:\Users\runneradmin\AppData\Local\Microsoft\WindowsApps\winget.exe`, no extra install step needed |
| `winget --version` | `v1.11.510`, exit `0` |
| `winget show --exact --id Git.Git --source winget --accept-source-agreements --disable-interactivity` | Succeeded non-interactively, exit `0`, returned full package metadata |
| `winget show --exact --id XP9KHM4BK9FZ7Q --source msstore --accept-source-agreements --disable-interactivity` | Succeeded non-interactively, exit `0`, returned full package metadata |

The `msstore` query printed a one-time notice about the source's terms
of transaction and its geographic-region requirement, but
`--accept-source-agreements` covered it without any interactive
prompt or authentication -- no token, login, or secret was configured
for this probe.

**Recommendation: achievable without additional dependencies.** This
scopes to what was actually tested here -- the `winget` CLI itself.
Both the `winget` and `msstore` sources are queryable non-interactively
on a stock `windows-latest` runner, with the same flags
`scripts/Test-PackageIds.ps1` already uses -- no third-party action,
no extra install step for `winget`. Running `Test-PackageIds.ps1`
itself would still need its existing `powershell-yaml` 0.4.12
prerequisite provisioned the same way the `pester` and
`configuration-drift` jobs already do
(`Install-Module -Name powershell-yaml -RequiredVersion 0.4.12 ...`,
`.github/workflows/lint.yml`) -- not a new dependency this
investigation introduces, just one worth naming explicitly rather than
letting "no additional dependencies" read as covering the whole
script. Wiring `Test-PackageIds.ps1` into an actual CI job (matrix
over both profiles, on `windows-latest`) is a reasonable follow-up,
but is a separate decision left to a future issue, per
issue #69's own scope.

## Can the Chocolatey route and the ARM64 branch be declared? (issue #71)

Two pieces of `boxstarter.ps1` sit outside `configurations/*.dsc.yaml`:
Phase 3's Chocolatey packages (`font-hackgen`, `font-hackgen-nerd`,
`lato`, `vb-cable`, plus `posh-git` via `Install-Module`), and Phase
4's `if (-not $IS_ARM64) { ... }` branch around `act` / Docker Desktop
/ VirtualBox. This is investigation only -- no `dsc.yaml`, generator,
or `boxstarter.ps1` change is made here; implementation (if any) is a
future issue's scope.

### Chocolatey packages

`Microsoft.WinGet.DSC/WinGetPackage` can only install winget packages,
so declaring a Chocolatey package needs a separate DSC resource
module. The obvious candidate, [`chocolatey/cChoco`](https://github.com/chocolatey/cChoco),
**is archived** -- confirmed via the GitHub API
(`archived: true`, archived 2026-06-29) and its own `readme.md`:
"cChoco has now been archived, and will not have any further updates
or support... we recommend using
[Chocolatey Module](https://github.com/chocolatey-community/Chocolatey-Module)."

That successor (`chocolatey-community/Chocolatey-Module`, PSGallery
module name `chocolatey`) is actively maintained (pushed 2026-06-19,
41 stars, class-based DSC resources). It provides a `ChocolateyPackage`
resource (`Name`, `Version`, `Ensure`, `ChocolateyOptions`, `Source`,
`Credential`) that checks `Test-ChocolateyInstall` before acting --
already satisfied in this repo: `setup.cmd` bootstraps Chocolatey
itself via the official `install.ps1` when `choco` isn't found on
PATH, then separately runs `choco install boxstarter -y` to install
Boxstarter (which requires Chocolatey to already be present) --
Chocolatey is present well before Phase 2/3 ever run.

**Recommendation: declare it**, via `resource: chocolatey/ChocolateyPackage`
per package, `securityContext: elevated` (matching today's system-wide
install). `ChocolateyPackage` is not a `Microsoft.WinGet.DSC/WinGetPackage`
resource, so `Split-DscResource` (issue #66) already buckets it into
the unapplied-resources list with zero generator changes -- the same
mechanism that already covers `PSDscResources/Registry` and the
`OsVersion` assertion. Caveat: `chocolatey-community/Chocolatey-Module`
publishes a preview release on every merge to `main`, so it's
comparatively new and fast-moving next to `PSDscResources` -- worth a
trial run before committing fully.

### `posh-git` (PowerShell module)

No well-maintained DSC resource exists specifically for "install this
PowerShell module." Two candidates checked:

- `PSModule` (in `PowerShell/PackageManagementProviderResource`):
  **archived**, last pushed 2018-04-12 -- 8 years stale.
- `Microsoft.PowerShell.PSResourceGet`: actively maintained (Microsoft's
  own package manager, pushed 2026-07-31), but its own module reference
  docs list only cmdlets (`Install-PSResource`, `Find-PSResource`,
  etc.) -- it is a package-manager module, not a DSC resource provider.
  No `[DscResource()]` class ships in it.

**Recommendation: declare it via `PSDscResources/Script`** -- the same
`PSDscResources` module this repo already resolves successfully via
`winget configure` for the `PSDscResources/Registry` resources
(issue #64), though `Script` itself would be a new resource type for
this repo, not one already in use. Idempotency: `TestScript`/`GetScript` check
`Get-Module -ListAvailable -Name posh-git`; `SetScript` runs
`Install-Module posh-git -Scope CurrentUser -Force -AllowClobber`,
identical to today's imperative line. `securityContext: current`
(`CurrentUser` scope, no elevation, matching today). Also not a
`WinGetPackage` resource, so it lands in the unapplied-resources list
automatically.

### Architecture (ARM64) conditional exclusion

Three approaches compared, evaluating file count, maintenance cost,
and impact on `scripts/Build-Configurations.ps1` (issue #66):

**A. Separate config files per architecture** (crossed with the
full/min profile axis: 2 profiles x 2 architectures). File count goes
from 2 `dsc.yaml` sources (6 total with their generated files) to 4
(12 total). The ~102 packages common to both architectures would need
to stay in sync across 2 files per profile, to exclude just 3
ARM64-incompatible packages. `Build-Configurations.ps1` needs no code
change (it already takes an arbitrary `-DscPath`), just 2 more
invocations wired into CI/docs. The dsc route and the import-fallback
route stay consistent by construction, since the ARM64 file simply
never lists the excluded packages.

**B. Single file, assertion-gated exclusion via `dependsOn`.** WinGet
Configuration assertions can gate individual resources through
`dependsOn`: a failed assertion skips its dependents without failing
the run (per the
[official authoring guide](https://learn.microsoft.com/en-us/windows/package-manager/configuration/create)).
But: no off-the-shelf architecture-assertion resource exists --
checked `Microsoft.Windows.Developer`'s full resource list
(`DeveloperMode`, `OsVersion`, `Taskbar`, `WindowsExplorer`,
`UserAccessControl`, `EnableDarkMode`, `ShowSecondsInClock`,
`EnableRemoteDesktop`, `EnableLongPathSupport`, `PowerPlanSetting`,
`WindowsCapability`, `NetConnectionProfile`,
`AdvancedNetworkSharingSetting`, `FirewallRule`) -- none check
processor architecture, so this option would also need a bespoke
`PSDscResources/Script`-based assertion. More importantly, **this
option breaks with the generator as it stands today**:
`Split-DscResource` has no concept of `dependsOn` -- it extracts every
`Microsoft.WinGet.DSC/WinGetPackage` resource's id/source
unconditionally, so an assertion-gated package would still appear in
`import.json` for every architecture including ARM64, where the dsc
route correctly skips it but the import-fallback route would not. That
route/generator mismatch is a gap this option introduces, not one it
inherits. On top of that, winget-cli's own issue tracker documents
ARM64-specific `winget configure` problems (`Repair-WinGetPackageManager`
failing on ARM64, general install failures on ARM64) -- the underlying
DSC engine's ARM64 support is itself immature right now.

**C. Stay imperative** (today's `if (-not $IS_ARM64) { ... }` block).
Zero migration cost, zero new risk, but does not satisfy roadmap #62's
stated success condition of full replacement.

**Recommendation: stay imperative for now.** Option A is technically
sound but a large maintenance-cost jump to exclude just 3 packages;
Option B is unsound against the current generator and rests on an
immature winget-cli ARM64 story. If ARM64 exclusions grow beyond this
narrow case, Option A -- not Option B -- is the correct path to
revisit.

### Roadmap #62 success-condition amendment

Because architecture conditionals are recommended to stay imperative,
roadmap #62's stated success condition ("procedural `winget install` /
`choco install` enumeration fully replaced by declarative definitions")
cannot be met exactly as worded. Proposed amendment: narrow it to
"every package/resource that does not require runtime branching is
declared," with `boxstarter.ps1` Phase 4's architecture branch recorded
as a documented, intentional exception (linking here), revisitable if
a sound single-file mechanism becomes available.

## Reviewing pinned Node/Unity versions (issue #73)

`libs/post-install.ps1` installs Node.js (via fnm) and the Unity Editor
(via Unity Hub CLI). Both used to have hardcoded version numbers,
including one comment block that named its own EOL dates while
continuing to install two already-EOL'd Node releases -- the versions
went stale and nothing surfaced it. Both are now declared in
`configurations/runtime-versions.psd1` instead.

### Why `.psd1`, not YAML or JSON

`scripts/Build-Configurations.ps1` and `scripts/Test-PackageIds.ps1`
already depend on the `powershell-yaml` module to parse `dsc.yaml`, but
`libs/post-install.ps1` has no module dependency today. `.psd1` is
parsed by `Import-PowerShellDataFile`, a built-in cmdlet -- so this file
does not add a new module dependency for a Boxstarter phase that
previously had none. It also allows a `#`-prefixed comment directly
above each entry, same as the hardcoded declarations it replaces.

### Where to look for the next EOL

Every entry in `configurations/runtime-versions.psd1` carries its own
`Eol` (Node) or `VerifiedDate` (Unity, which has no EOL concept)
alongside `Reason` -- the file itself is the answer to "when does this
go stale," no separate tracking needed. `Node.Default` is a distinct
key (not "first entry wins"), so reordering or trimming `Versions`
can't silently change which version `fnm default` selects.

### Review cadence

- **Node**: re-check the
  [official release schedule](https://github.com/nodejs/Release)
  (`schedule.json`) whenever a version's `Eol` in
  `runtime-versions.psd1` has passed, or at least whenever an issue
  like this one revisits the file. Drop any version past its `Eol`,
  and confirm `fnm` itself supports whichever version is added, since a
  version fnm doesn't yet recognize will fail `fnm install` outright.
- **Unity**: no fixed EOL, so `VerifiedDate` records when the pinned
  version/changeset pair was last confirmed against VRChat's own
  [current-version page](https://creators.vrchat.com/sdk/upgrade/current-unity-version/).
  Re-check that page periodically (it has changed roughly once a year
  historically) and whenever a VRChat SDK/VCC upgrade is suspected.
  If the version changes, get the matching changeset from
  [Unity's release API](https://services.api.unity.com/unity/editor/release/v1/releases)
  (query by `?version=<version>`) in the same change -- a
  mismatched changeset makes Unity Hub's
  `install -v <version> -c <changeset>` fail outright. If the version
  is still current, update `VerifiedDate` only.

### 2026-08-02 verification (this issue)

- Node 20 (EOL 2026-04-30) and Node 25 (EOL 2026-06-01) are past EOL as
  of this issue's filing (2026-07-28) and have been dropped.
  Node 22 (Maintenance LTS, EOL 2027-04-30) is kept for projects still
  pinned to it; Node 24 (Active LTS, EOL 2028-04-30) is the default.
  Source: `nodejs/Release`'s `schedule.json`, fetched 2026-08-02.
- Unity `2022.3.22f1` is still the version named on VRChat's
  current-version page (last updated there 2025-10-03, confirmed
  2026-08-02) -- version unchanged, so only `VerifiedDate` was updated.
  The paired changeset `887be4894c44` was independently confirmed
  against Unity's own release API (`services.api.unity.com`), which
  returns that exact changeset for `2022.3.22f1`'s Windows x86_64
  download.

## Installing the Unity CLI (issue #76)

Unity's CLI (`unity` binary) is a second, official way to manage Unity
Editor installs, distinct from Unity Hub's unofficial `-- --headless`
interface already used by `libs/post-install.ps1`. This issue installs
only the CLI binary itself, via Unity's own installer script
(`https://public-cdn.cloud.unity3d.com/hub/prod/cli/install.ps1`), from
`libs/unity-cli-installer.ps1`. Switching Editor installation from Hub
to CLI is a separate, later issue's scope.

### The stable channel does not exist yet (verified 2026-08-02)

The Unity CLI's own docs list `beta` in every Windows example, without
saying whether that's a preference or a necessity. Checked directly
against the CDN itself:

| Manifest | URL | HTTP status |
| --- | --- | --- |
| stable/GA | `.../cli/latest.json` | **404** |
| beta | `.../cli/latest-beta.json` | 200 (`1.0.0-beta.3`) |
| alpha | `.../cli/latest-alpha.json` | 404 |

Beta is not merely recommended -- as of this verification, it is the
*only* channel with a published build. `configurations/runtime-versions.psd1`'s
`UnityCli.Channel` records this as `beta` with the reason and the date
checked, per the review-cadence pattern issue #73 established. Re-check
these three URLs when reviewing this entry; a `latest.json` 200 would
mean a stable release has shipped.

### `-Target` pins the version; `-Channel` only matters unpinned

Reading `install.ps1`'s own source (not just its docs) matters here:
when `-Target` is a concrete version (not `"latest"`), the script
fetches that version's own manifest directly
(`.../cli/<version>/latest.json`) and never consults `-Channel` /
`$env:UNITY_CLI_CHANNEL` at all -- channel selection only resolves what
`"latest"` means. `runtime-versions.psd1` pins `Target` to
`1.0.0-beta.3` (the exact version confirmed available above), so
`Channel: beta` is recorded for traceability only; it has no effect on
this pinned install. If `Target` is ever changed back to `"latest"`,
`Channel` starts mattering again.

### Never invoke `install.ps1`'s downloaded content as an in-process scriptblock

`install.ps1` calls `exit 1` on several of its own failure paths. This
matters more than it looks: invoking downloaded script content
in-process (e.g. `& [scriptblock]::Create($content) -Target ...`, or
the official `irm ... | iex` one-liner with parameters spliced into the
string) runs that `exit` in the *caller's own process*. Confirmed
empirically with a minimal repro (a scriptblock containing `exit 1`
invoked via `& $sb`, followed by a line that never printed) -- `exit`
inside an in-process-invoked scriptblock terminates the entire
PowerShell host, not just the scriptblock, silently aborting whatever
of `boxstarter.ps1` was still queued behind it. `Invoke-UnityCliInstaller`
in `libs/unity-cli-installer.ps1` downloads `install.ps1` to a temp file
and runs it via `Start-Process -Wait -PassThru` in a **separate**
process instead, so its exit code can be inspected and handled without
risk to the calling process.

### `install.ps1` itself is not pinned

Unlike the binary it downloads (SHA-256 verified by the script itself),
`install.ps1` is fetched fresh on every run and is not pinned by hash
or version. This is the same trust model as any curl-pipe-to-shell
bootstrap (Chocolatey's own installer, Scoop's) -- a compromise of
Unity's CDN could serve a different script. Recorded here as a known,
accepted risk rather than left implicit; mitigating it (e.g. pinning
and re-verifying a hash of `install.ps1` itself) is out of this issue's
scope.

### PATH is not live in the current process after install

`install.ps1` updates the persistent User-scope PATH
(`[System.Environment]::SetEnvironmentVariable(..., "User")`) and
broadcasts `WM_SETTINGCHANGE` so new shells and Explorer pick it up --
but never touches `$env:Path` in its own process, let alone the
calling one. `Sync-UnityCli` calls `Add-UnityCliToProcessPath` both
before checking whether the CLI is already installed (so an existing
install from a prior run is found) and after a fresh install (so
`unity` is callable later in the same `boxstarter.ps1` run without a
new shell).

### Unity Hub stays installed; `com.unity.pipeline` is out of scope

`configurations/packages.dsc.yaml` keeps `Unity.UnityHub`. VRChat
Creator Companion may recognize installed Editors through Hub, and
removing Hub without confirming that would risk breaking VCC; whether
Hub can eventually be dropped is left to a future issue, not decided
here. Separately, `com.unity.pipeline` (a beta Unity package that talks
to a running Editor over local HTTP, requiring the CLI as a
precondition) is installed into a Unity **project**, not this
machine-setup repository -- out of scope here beyond this note.

### Not verified on a real machine

Like issue #68's package-id checker, this Windows-only script could not
be run against a real `unity` binary or `install.ps1` invocation from
this Linux development environment. `libs/post-install.ps1` and
`boxstarter.ps1` are also never executed directly in this environment
even for smoke-testing, since doing so risks running real installers
present on the shared machine's PATH (learned the hard way during
issue #73). What *is* verified: `install.ps1`'s actual source was read
end to end (not assumed from its docs), the channel-manifest HTTP
checks above were run for real, and `Sync-UnityCli`'s idempotency and
error-handling logic is covered by Pester with
`Get-InstalledUnityCliVersion` / `Invoke-UnityCliInstaller` mocked --
see `tests/powershell/unity-cli-installer.Tests.ps1`.

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
