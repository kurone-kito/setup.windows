# Dotfiles Delegation Boundary

Roadmap #111 moves CLI tools and language runtimes from this
repository's winget/DSC definitions to
[`kurone-kito/dotfiles`](https://github.com/kurone-kito/dotfiles)'s
[mise](https://mise.jdx.dev/) configuration, in tracked waves. This
document is issue #104's inventory for the **first wave** —
Node.js, GitHub CLI, ghq, GitHub Copilot CLI, and git-vrc — recording
every in-repo dependency on each target. git-vrc (#105, PR #114)
already merged during this investigation; Node.js/GitHub CLI/ghq/
GitHub Copilot CLI (#103/#107/#108) are still open at the time of
writing.

Two other documents in progress cover related but distinct ground:

- #110 (not yet merged) will update `README.md` / `README.ja.md` with
  the user-facing ownership boundary table and the `chezmoi apply`
  prerequisite, once #104/#107/#108 have shipped (#105 already has).
  It is blocked by this issue and depends on it for the "operations
  that need `chezmoi apply`" list below.
- Roadmap issue #111 records the full cross-repo design rationale
  (why CLI tools move to dotfiles at all — the winget `portable`
  package / SSH symlink-traversal problem, and the `cmd.exe` PATH
  length limit) and the wave 2 plan. This document does not repeat
  that rationale; it only records **this repository's** current
  dependency surface.

Everything below reflects the state of `master` as investigated and
re-synced on 2026-08-14 (UTC), including after #105 (PR #114) merged
mid-investigation the same day. Statements about `kurone-kito/dotfiles`
content are point-in-time reads of that repository on the same date
and can drift independently of this repository.

**Scope note**: this document only records findings. It does not
change `.github/idd/config.json`, `configurations/*.dsc.yaml`, or (for
the still-open targets) `libs/post-install.ps1` — those stay exactly
as they are until their own tracked issues (#103/#107/#108) ship.
`libs/post-install.ps1`'s git-vrc block specifically was already
removed by #105 before this issue merged; see the git-vrc subsection
below.

## 1. First-wave targets: in-repo dependencies

For each target, "today" describes current `master`; "after delegation"
describes the change once the named tracked issue ships. Anchors below
are DSC `resource`/`id` values and named script blocks rather than line
numbers — those are stable across `packages.dsc.yaml` regeneration,
while line numbers would drift on the next regeneration and go stale
immediately.

### Node.js

- `configurations/packages.dsc.yaml` — `pkg.fnm` resource
  (`id: pkg.fnm` / winget id `Schniz.fnm`, full profile only; not
  present in `packages.min.dsc.yaml`).
- `configurations/packages.import.json` (generated fallback for the
  full profile's degraded `winget import` route — `boxstarter.ps1`
  runs `winget import` against this file only when `libs/strategy.ps1`'s
  capability detection selects the `import` route upfront because
  `winget configure` isn't available on this machine; a runtime
  `winget configure` failure aborts setup outright, it does not fall
  back to `import`) also lists the `Schniz.fnm` `PackageIdentifier`, an
  active second installation path for the same package.
- `libs/post-install.ps1` — the `### Node.js via fnm` block: runs
  `fnm env --use-on-cd`, then `fnm install` for each version and
  `fnm default` from `configurations/runtime-versions.psd1`'s `Node`
  table.
- `configurations/runtime-versions.psd1` — the `Node` table (pinned
  versions, EOL dates, default version), consumed only by the
  `post-install.ps1` block above.
- `README.md` / `README.ja.md` — the architecture diagram and package
  list both name `fnm` as the Node.js install path, and both files'
  setup-step-5 one-line summary ("Run post-install setup (Node.js, VPM
  CLI, Unity, mkcert, Docker images)") still names Node.js explicitly.
- `boxstarter.ps1` — the `### Phase 5 — Post-install setup (fnm,
  cargo, Unity, mkcert, Docker)` banner comment names `fnm`.
- `PSScriptAnalyzerSettings.psd1` — the comment explaining why
  `PSAvoidUsingInvokeExpression` isn't globally excluded specifically
  cites fnm's `fnm env --use-on-cd | Out-String | Invoke-Expression`
  call in `libs/post-install.ps1` as the one existing occurrence the
  file-scoped suppression covers; that occurrence disappears with the
  fnm block.
- `libs/runtime-versions.ps1` — the dot-sourced reader's own doc
  comment names it "the single source of truth for pinned Node, Unity
  Editor, and Unity CLI versions".
- `docs/dsc-migration-notes.md`'s "Reviewing pinned Node/Unity
  versions (issue #73)" section owns the fnm/Node review guidance
  that #108 will need to rewrite once `Schniz.fnm` and the `Node`
  table are removed.
- `tests/powershell/unity-cli-installer.Tests.ps1` and
  `unity-editor-installer.Tests.ps1` both use `@{ Node = @{} }` as a
  fixture for a config file with an unrelated section present but the
  Unity-specific one missing — incidental, not a functional
  dependency, but worth #108 double-checking these fixtures still make
  sense once the `Node` key disappears from `runtime-versions.psd1`.

The min profile already ships `jdx.mise` (`mise-en-place-mise`
resource in `packages.min.dsc.yaml`) via winget, but that installs only
the `mise` tool itself — not Node.js. Node.js comes from `mise` reading
dotfiles' `node = "latest"` entry in `mise/config.toml`, which requires
`chezmoi apply` to deploy; a min-profile machine has `mise` unconditionally
but still needs `chezmoi apply` before `mise` actually installs Node.js.
Issue #103 (open PR #113) adds `jdx.mise` to the full profile as a
prerequisite for #108, which will remove `pkg.fnm`, the
`post-install.ps1` fnm block, and the `Node` table above once mise is
available on both profiles.

### GitHub CLI

- `configurations/packages.dsc.yaml` (resource id `pkg.ghCli`, winget
  id `GitHub.cli`, full profile) **and**
  `configurations/packages.min.dsc.yaml` (resource id `github-cli`,
  winget id `GitHub.cli`, min profile) both install it today.
- `configurations/packages.import.json` and
  `configurations/packages.min.import.json` (both profiles' generated
  `winget import` fallbacks) also list the `GitHub.cli`
  `PackageIdentifier` — the same degraded-route consideration as
  Node.js above.
- The IDD execution loop itself is built on the `gh` CLI. This is a
  **local-machine** dependency only — hosted GitHub Actions runners
  ship their own `gh` installation and are unaffected by this
  repository's or dotfiles' package choices. Prose enumeration of this
  surface was found incomplete twice already during this review, so
  it's recorded here as a **reproducible command** instead of a
  hand-maintained list — re-run it to get the current, exact set
  rather than trusting a snapshot that will drift:

  ```sh
  grep -rl '\bgh \|gh api\|gh pr\|gh issue\|gh run\|gh repo' \
    .github/instructions/ docs/ .github/workflows/ \
    --exclude=dotfiles-boundary.md
  ```

  (`--exclude` is needed because this file's own prose quotes `gh`
  commands and would otherwise match itself.) As of this snapshot
  (2026-08-14): 22 files under `.github/instructions/` (including
  `lite/`) that instruct an agent to run `gh`; 9 files under `docs/`
  that do the same (`customization.md`,
  `idd-advisory-wait-shell-fallback.md`, `idd-autonomy-contract.md`,
  `idd-comment-minimization.md`, `idd-helper-scripts.md`,
  `idd-policy.md`, `idd-workflow.md`, `onboarding/template-distribution.md`,
  `permissions.md`); and, under `.github/workflows/`, only
  `post-merge-cleanup.yml` actually **executes** `gh` (`gh pr view`,
  `gh api`, `gh pr comment`) — the grep also matches
  `idd-advisory-convergence.yml`, but only because it references a
  `gh run rerun` recovery command inside a comment; it does not
  execute `gh` in any step.

Issue #107 removes `GitHub.cli` from both profiles' winget
definitions (along with ghq and GitHub Copilot CLI, below) once this
issue records the IDD-loop bootstrap dependency — see [Dependency
ordering, not deferral](#6-dependency-ordering-not-deferral).

### ghq

- `configurations/packages.min.dsc.yaml` (`id: ghq`, winget id
  `x-motemen.ghq`, min profile only), and
  `configurations/packages.min.import.json` (min profile's generated
  `winget import` fallback, same `PackageIdentifier`). No script,
  workflow, or instruction file invokes the `ghq` binary. **None.**

### GitHub Copilot CLI

- `configurations/packages.min.dsc.yaml` (`id: github-copilot-cli`,
  winget id `GitHub.Copilot`, min profile only), and
  `configurations/packages.min.import.json` (min profile's generated
  `winget import` fallback, same `PackageIdentifier`). Every other
  "Copilot" occurrence in this repository
  (`docs/`, `.github/instructions/`) refers to GitHub Copilot as a
  reviewer, IDE, or agent surface — the Pull Request Reviewer
  **advisory bot** (`copilot-pull-request-reviewer[bot]`) used by the
  IDD review workflow, VS Code Copilot instructions/chat, or the
  Copilot coding-agent entry listed in `docs/idd-workflow.md`'s
  entry-points table — never the `copilot` CLI binary itself. No
  script or instruction invokes the CLI binary. **None.**

### git-vrc

**Already delegated** — #105 merged as PR #114 on 2026-08-14, while
this issue was still in progress. `libs/post-install.ps1` no longer
has any git-vrc code: the `### git-vrc (VRChat Git integration via
cargo)` block (`cargo install --locked --git
https://github.com/anatawa12/git-vrc.git`, followed by `git vrc
install --config --global`) was removed in full, along with the
git/cargo existence-check guards that existed only for it, and
`README.md`/`README.ja.md`'s post-install summaries were updated to
match. `Rustlang.Rust.MSVC` stays in `packages.dsc.yaml` as a language
runtime — the delegation removed only git-vrc's own install step, not
Rust generally.

**Current in-repo dependency: none.** dotfiles now owns both the
binary (`github:anatawa12/git-vrc` via mise) and the git filter
configuration (`home/dot_config/git/config.tmpl`'s `[filter "vrc"]`
block with `clean`/`smudge`/`required` directives, confirmed live
against `kurone-kito/dotfiles` on 2026-08-14). Since #105 already
shipped, git-vrc's `chezmoi apply` dependency is a present-day
condition, not a future one — see [§4](#4-operations-gated-on-chezmoi-apply).

## 2. Tooling required by `install-deps` / `fix-validate` / `pre-push-validate`

`.github/idd/config.json`'s `commands` block:

| Command | Definition |
| --- | --- |
| `install-deps` | `true` (no-op) |
| `fix-validate` | `npx -y markdownlint-cli2 --fix "**/*.md" && npx -y markdownlint-cli2 "**/*.md"` |
| `pre-push-validate` | `npx -y markdownlint-cli2 "**/*.md" && npx -y cspell lint "**" --no-progress && pwsh -c "Invoke-ScriptAnalyzer ..." && pwsh -c "Invoke-Pester ..."` |

`install-deps` itself requires nothing directly, but this repository's
`helperRuntime.profile` is `ephemeral-npx` (see
[`docs/idd-policy.md`](idd-policy.md#helper-runtime-profile)): every
`idd-*` helper invocation (claim markers, review snapshots, CI-wait
state, merge readiness, this very digest update) runs through `npx`.
The Node.js dependency below therefore covers the whole IDD loop, not
just `fix-validate`/`pre-push-validate`.

| Tool | Needed by | Provisioning source today | After delegation |
| --- | --- | --- | --- |
| `npx` (Node.js) | `fix-validate`, `pre-push-validate`, every `idd-*` helper call | full: `Schniz.fnm` (winget) + `libs/post-install.ps1`. min: `jdx.mise` (winget, unconditional) installs the `mise` tool, but Node.js itself comes from dotfiles' `node = "latest"` entry, which needs `chezmoi apply` to deploy | Both profiles converge on dotfiles' `node = "latest"` (mise) once #108 ships |
| `gh` | The IDD loop's own bootstrap (not `fix-validate`/`pre-push-validate` directly) | full and min: `GitHub.cli` (winget) | dotfiles' `github:cli/cli` (mise) once #107 ships |
| `pwsh` (PowerShell 7) | `pre-push-validate` (`Invoke-ScriptAnalyzer`, `Invoke-Pester`) | Both profiles install PowerShell 7 today, via different package identities: full uses `pkg.pwsh` (Microsoft Store id `9MZ1SNWT0N5D`); min uses `Microsoft.PowerShell` (native winget id). Not a delegation-relevant gap — see [§3](#3-powershell-7-provisioning-in-the-full-profile-conclusion). | Unchanged — no first-wave track touches either `pwsh` package definition. |
| `PSScriptAnalyzer`, `Pester`, `powershell-yaml` (PowerShell modules) | `pre-push-validate` (`Invoke-ScriptAnalyzer`/`Invoke-Pester`); `powershell-yaml` is also required by `scripts/Build-Configurations.ps1` / `scripts/Test-PackageIds.ps1` | **No automated winget or dotfiles provisioning on either profile, for any of the three.** `.github/workflows/lint.yml` runs `Install-Module -Name <module> -RequiredVersion <pinned> -Force -Scope CurrentUser -Repository PSGallery` fresh on every CI run for all three. `docs/testing.md` documents the manual command for **local** development for `Pester`; `scripts/Build-Configurations.ps1`'s and `scripts/Test-PackageIds.ps1`'s own help-comment headers document the same manual command for `powershell-yaml`. Only `PSScriptAnalyzer` has no local-install documentation anywhere in this repository — just its CI provisioning in `lint.yml`. Nothing automates any of the three for a fresh local machine (either profile). | Unchanged — out of scope for the winget/dotfiles boundary; these are PowerShell Gallery modules, not OS packages. |

## 3. PowerShell 7 provisioning in the full profile: conclusion

The issue's premise, as originally investigated, was that
`Microsoft.PowerShell` exists only in `packages.min.import.json` and is
absent from the full profile. **That premise is true only at the
package-identity level, and the functional conclusion it implies —
that full-profile machines lack PowerShell 7 — is false.**

**Evidence.** `configurations/packages.dsc.yaml` (full profile) has a
`pkg.pwsh` resource under its "CLI — Shell" section:

```yaml
- resource: Microsoft.WinGet.DSC/WinGetPackage
  id: pkg.pwsh
  directives:
    description: PowerShell 7
  settings:
    id: "9MZ1SNWT0N5D"
    source: msstore
```

`9MZ1SNWT0N5D` is the Microsoft Store listing for PowerShell 7 — the
same product as `packages.min.dsc.yaml`'s `Microsoft.PowerShell`
(native winget id), just distributed through a different source
(`msstore` vs. `winget`). `configurations/packages.import.json` (full
profile's generated fallback) also carries `9MZ1SNWT0N5D`, so the
degraded `winget import` route installs it too. An initial pass over
this document searched only for the literal winget id string
`Microsoft.PowerShell` and missed the Store-sourced entry — a search
methodology gap, not a real provisioning gap.

The full profile does still omit the rest of the "CLI shell tools"
cluster that the min profile groups together — `Starship.Starship`,
`Zellij.Zellij`, `JesseDuffield.lazygit`, and `marlocarlo.psmux` are
genuinely absent from full and present only in min (`packages.min.dsc.yaml`
groups them under the same section as `Microsoft.PowerShell`). That
narrower category split — full skips terminal-prompt/multiplexer/TUI
tooling but not PowerShell itself — remains consistent with `README.md`'s
framing (min: "development tools only, no gaming/media"; full: general
desktop setup including core dev tools like Git, GitHub CLI, fnm,
Android Studio).

**Conclusion.** There is no full-profile PowerShell 7 gap, present-day
or otherwise: both profiles install it, through different package
identities. Nothing in this section motivates a `chezmoi apply`
workaround or a winget-install workaround for `pwsh` itself. The actual
local-provisioning gap adjacent to this question is the PowerShell
**modules** (`PSScriptAnalyzer`/`Pester`/`powershell-yaml`) that
`pre-push-validate` also needs — see the last row of [§2](#2-tooling-required-by-install-deps--fix-validate--pre-push-validate)'s
table, which affects both profiles equally and is unrelated to the
winget/dotfiles delegation boundary this issue covers.

## 4. Operations gated on `chezmoi apply`

Rows 1-3 below apply **once** #107/#108 ship; they do not apply to
today's `master`. Rows 4-5 (git-vrc) already apply **today**, since
issue #105 merged during this investigation. Row 6 is unrelated to any
first-wave track and `chezmoi apply` does not fix it either — see the
PowerShell-modules row in [§2](#2-tooling-required-by-install-deps--fix-validate--pre-push-validate).

**Cross-cutting caveat for every "run `chezmoi apply` first" workaround
below**: dotfiles' `run_onchange_after_50-install-mise-tools.ps1.tmpl`
— the script that actually installs mise-managed tools (Node.js, `gh`,
`ghq`, the GitHub Copilot CLI, git-vrc) — starts with
`if (-not (Get-Command mise ...)) { Write-Host 'mise not found;
skipping.'; exit 0 }`. It **silently no-ops**, not fails, when `mise`
itself isn't on `PATH`.

This bites the **full** profile predictably: it has no `mise` at all
today (only `jdx.mise` via winget, min profile only, unconditional)
until #103 (open PR #113) ships, so `chezmoi apply` alone does **not**
provision any of these tools on full today — it needs #103 to land
first, or a manual `mise install` after installing `mise` itself some
other way.

It can also bite the **min** profile, more subtly: `run_onchange_`
scripts are keyed on a content hash (the script's own header comment:
"Re-runs when mise config changes"), not on whether the previous run
actually did the work — chezmoi has no way to distinguish "did the
work" from "successfully chose to no-op" once the script exits `0`
either way. If `mise` isn't yet reachable on `PATH` in the shell
`chezmoi apply` runs in on a min-profile machine's **first** apply
(for example, PATH hasn't refreshed in the current session since
winget just installed `jdx.mise`), the no-op still gets recorded
against that content hash. Installing `mise` afterward, or
reconnecting the session, does not change the hash — a later plain
`chezmoi apply` will **not** retry the script. The workaround in that
case is a manual `mise install && mise reshim` once `mise` is
reachable, not another `chezmoi apply`.

| Operation | Needs | Workaround |
| --- | --- | --- |
| IDD `gh`-based operations (claim, PR, review, merge) on a local machine | GitHub CLI, once #107 ships | Run `chezmoi apply` first (see the cross-cutting caveat above), or temporarily `winget install GitHub.cli` |
| `fix-validate` / `pre-push-validate` / any `idd-*` helper call (needs `npx`) on a local machine | Node.js, once #108 ships | Run `chezmoi apply` first (see the cross-cutting caveat above). Temporary alternative: `winget install Schniz.fnm` alone only reinstalls the empty version-manager binary once the `post-install.ps1` fnm block that ran `fnm env`/`fnm install`/`fnm default` is gone — it must be followed by `fnm env --use-on-cd \| Out-String \| Invoke-Expression` (session-scoped; without it `node`/`npx` stay off `PATH` even after installing a version) and a manual `fnm install <version> && fnm default <version>`, or install a self-contained Node.js package directly (e.g. `winget install OpenJS.NodeJS.LTS`) |
| Interactive use of `ghq` or the GitHub Copilot CLI as developer conveniences | ghq / GitHub Copilot CLI, once #107 ships | Run `chezmoi apply` first (see the cross-cutting caveat above), or temporarily `winget install x-motemen.ghq` / `winget install GitHub.Copilot` |
| Interactive use of the `git vrc` binary, or any operation needing it — **applies today** | git-vrc | Run `chezmoi apply` first (see the cross-cutting caveat above). This repository has **no winget package id for git-vrc** — a temporary local install must use the command the now-removed `post-install.ps1` block used to run: `cargo install --locked --git https://github.com/anatawa12/git-vrc.git` |
| The `git vrc` clean/smudge filter for VRChat assets (unitypackage/prefab-friendly diffs) — **applies today** | dotfiles' `home/dot_config/git/config.tmpl` `[filter "vrc"]` block | Run `chezmoi apply` first (see the cross-cutting caveat above), or manually add the equivalent `[filter "vrc"]` block to the global gitconfig — **and** install the `git-vrc` binary via the cargo command in the row above first, or the filter's `git vrc clean`/`git vrc smudge` invocations fail with no such subcommand |
| `pre-push-validate`'s `pwsh`-based checks needing `PSScriptAnalyzer`/`Pester`/`powershell-yaml`, on either profile, today | The PowerShell Gallery modules — see [§2](#2-tooling-required-by-install-deps--fix-validate--pre-push-validate); not fixed by `chezmoi apply`, ever, under the current dotfiles definition | Manually run `Install-Module -Name <module> -RequiredVersion <pinned> -Force -Scope CurrentUser -Repository PSGallery` for all three, using the pinned versions in `.github/workflows/lint.yml` (`docs/testing.md` documents this for `Pester`; `scripts/Build-Configurations.ps1`/`Test-PackageIds.ps1`'s help headers document it for `powershell-yaml`; `PSScriptAnalyzer` has no local documentation) |

**Unrelated existing caveat, noted for accuracy**: this repository's
own code only ever modifies the current process's `$env:Path`
(`libs/unity-cli-installer.ps1`'s `Add-UnityCliToProcessPath`). The
*downloaded* Unity CLI installer it invokes (Unity's own
`install.ps1`) does persist an entry to the User PATH registry as a
documented side effect of installing the Unity CLI. This is orthogonal
to the first-wave delegation targets — Unity CLI is not one of them —
and is recorded here only so the User PATH claim in [§5](#5-user-path-ownership)
is not overstated.

## 5. User PATH ownership

User PATH ownership belongs to dotfiles, confirmed live against
`kurone-kito/dotfiles` on 2026-08-14:

- `home/dot_config/powershell/lib/managed-paths.ps1` is the single
  source of truth for the managed-path set: static entries
  (`WinGet\Links`, `%LOCALAPPDATA%\mise\shims`, `Zellij`,
  `GnuWin32\bin`, `~/.local/bin`, `~/.cargo\bin`) plus the winget
  package directories declared in `data.wingetUserPath.packages`.
- `home/run_onchange_after_35-register-path.ps1.tmpl` reconciles the
  User PATH registry value from that managed-path set on `chezmoi
  apply` (removes all managed entries, then re-adds the desired set at
  the front, preserving any unmanaged entries).
- The mechanism and its rationale are documented at dotfiles'
  `docs/winget-user-path.md`.

This repository does not write the persistent User PATH: no script
under `libs/` or `scripts/` calls
`[System.Environment]::SetEnvironmentVariable(..., 'User')` or
otherwise touches the `HKCU\Environment` registry key (verified by
repository-wide search). The one process-scope `$env:Path` write, and
the one third-party persistent-PATH side effect, are noted in [§4](#4-operations-gated-on-chezmoi-apply)'s
caveat — neither is this repository writing User PATH itself. This
repository must continue to avoid writing User PATH: doing so would
create a second writer racing dotfiles' reconciler over the same
registry value.

## 6. Dependency ordering, not deferral

The investigation found no technical reason to defer any of the five
first-wave targets. **No deferred targets.**

Roadmap issue #111's tracks list does not defer any of Node.js, GitHub
CLI, ghq, GitHub Copilot CLI, or git-vrc — all five are first-wave
tracks with implementation issues (Node.js: #103/#108, both open;
GitHub CLI, ghq, and GitHub Copilot CLI: #107, open; git-vrc: #105,
merged as PR #114 while this issue was in progress). The one
dependency that could look like a reason to defer — the IDD loop's own
bootstrap dependency on `gh` (§1, §2) — is handled as **sequencing**,
not deferral: #111 records that #107 (which removes `GitHub.cli` from
winget) depends on #104 (this issue) precisely so the bootstrap
dependency is recorded before the winget definition is removed, not so
that removal is skipped. This issue does not block #103 or #108, which
proceed independently (#105 no longer needs to be listed here — it
already shipped). #107 specifically is gated on this issue merging
first — roadmap #111 records "#107 depends on #104", and #107 itself
is filed as `Blocked by #104`. That is the sequencing this section is
about: a deliberate, temporary ordering gate on one target, not a
deferral of delegation itself.
