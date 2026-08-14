# Dotfiles Delegation Boundary

Roadmap #111 moves CLI tools and language runtimes from this
repository's winget/DSC definitions to
[`kurone-kito/dotfiles`](https://github.com/kurone-kito/dotfiles)'s
[mise](https://mise.jdx.dev/) configuration, in tracked waves. This
document is issue #104's inventory for the **first wave** —
Node.js, GitHub CLI, ghq, GitHub Copilot CLI, and git-vrc — recording
every in-repo dependency on each target before any of the wave's
implementation tracks (#103, #105, #107, #108) ship.

Two other documents in progress cover related but distinct ground:

- #110 (not yet merged) will update `README.md` / `README.ja.md` with
  the user-facing ownership boundary table and the `chezmoi apply`
  prerequisite, once #104/#105/#107/#108 have shipped. It is blocked
  by this issue and depends on it for the "operations that need
  `chezmoi apply`" list below.
- Roadmap issue #111 records the full cross-repo design rationale
  (why CLI tools move to dotfiles at all — the winget `portable`
  package / SSH symlink-traversal problem, and the `cmd.exe` PATH
  length limit) and the wave 2 plan. This document does not repeat
  that rationale; it only records **this repository's** current
  dependency surface.

Everything below reflects the state of `master` as investigated on
2026-08-14. Statements about `kurone-kito/dotfiles` content are
point-in-time reads of that repository on the same date and can drift
independently of this repository.

**Scope note**: this document only records findings. It does not
change `.github/idd/config.json`, `libs/post-install.ps1`, or any
`configurations/*.dsc.yaml` file — those stay exactly as they are
today until their own tracked issues (#103/#105/#107/#108) ship.

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
- `libs/post-install.ps1` — the `### Node.js via fnm` block: runs
  `fnm env --use-on-cd`, then `fnm install` for each version and
  `fnm default` from `configurations/runtime-versions.psd1`'s `Node`
  table.
- `configurations/runtime-versions.psd1` — the `Node` table (pinned
  versions, EOL dates, default version), consumed only by the
  `post-install.ps1` block above.
- `README.md` / `README.ja.md` — the architecture diagram and package
  list both name `fnm` as the Node.js install path.

The min profile already ships `jdx.mise` (`mise-en-place-mise`
resource in `packages.min.dsc.yaml`) but does not install Node.js via
winget at all today; a min-profile machine already needs `chezmoi
apply` for Node.js. Issue #103 (open PR #113) adds `jdx.mise` to the
full profile as a prerequisite for #108, which will remove `pkg.fnm`,
the `post-install.ps1` fnm block, and the `Node` table above once mise
is available on both profiles.

### GitHub CLI

- `configurations/packages.dsc.yaml` (`id: GitHub.cli`, full profile)
  **and** `configurations/packages.min.dsc.yaml` (`id: GitHub.cli`,
  min profile) both install it today.
- The IDD execution loop itself is built on the `gh` CLI: 22
  `.github/instructions/*.md` files (including their `lite/`
  counterparts) and 2 `.github/workflows/*.yml` files
  (`idd-advisory-convergence.yml`, `post-merge-cleanup.yml`) invoke
  `gh` — 24 files in total. This is a **local-machine**
  dependency only — hosted GitHub Actions runners ship their own `gh`
  installation and are unaffected by this repository's or dotfiles'
  package choices.

Issue #107 removes `GitHub.cli` from both profiles' winget
definitions (along with ghq and GitHub Copilot CLI, below) once this
issue records the IDD-loop bootstrap dependency — see [Dependency
ordering, not deferral](#6-dependency-ordering-not-deferral).

### ghq

- `configurations/packages.min.dsc.yaml` (`id: ghq`, winget id
  `x-motemen.ghq`, min profile only) is the only reference in this
  repository. No script, workflow, or instruction file invokes the
  `ghq` binary. **None.**

### GitHub Copilot CLI

- `configurations/packages.min.dsc.yaml` (`id: github-copilot-cli`,
  winget id `GitHub.Copilot`, min profile only) is the only package
  reference. Every other "Copilot" occurrence in this repository
  (`docs/`, `.github/instructions/`) refers to the unrelated GitHub
  Copilot Pull Request Reviewer **advisory bot**
  (`copilot-pull-request-reviewer[bot]`) used by the IDD review
  workflow, not the `copilot` CLI binary. No script or instruction
  invokes the CLI binary. **None.**

### git-vrc

- `libs/post-install.ps1` — the `### git-vrc (VRChat Git integration
  via cargo)` block: `cargo install --locked --git
  https://github.com/anatawa12/git-vrc.git`, followed by `git vrc
  install --config --global` (writes the `[filter "vrc"]` block into
  the global gitconfig).
- For context only (not owned by this repository): dotfiles'
  `home/dot_config/git/config.tmpl` already defines the equivalent
  `[filter "vrc"]` block with `clean`/`smudge`/`required` directives,
  confirmed live against `kurone-kito/dotfiles` on 2026-08-14. Once
  #105 ships, dotfiles owns both the binary (`github:anatawa12/git-vrc`
  via mise) and the git filter configuration.

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
| `npx` (Node.js) | `fix-validate`, `pre-push-validate`, every `idd-*` helper call | full: `Schniz.fnm` (winget); min: `jdx.mise` (dotfiles, needs `chezmoi apply`) | Both profiles converge on dotfiles' `node = "latest"` (mise) once #108 ships |
| `gh` | The IDD loop's own bootstrap (not `fix-validate`/`pre-push-validate` directly) | full and min: `GitHub.cli` (winget) | dotfiles' `github:cli/cli` (mise) once #107 ships |
| `pwsh` (PowerShell 7) | `pre-push-validate` (`Invoke-ScriptAnalyzer`, `Invoke-Pester`) | min only: `Microsoft.PowerShell` (winget). **Not present in the full profile, and not present in dotfiles' `mise/config.toml`** (confirmed live against `kurone-kito/dotfiles` on 2026-08-14 — no `powershell`/`pwsh` mise tool entry exists) | Unchanged — no first-wave track adds a `pwsh` provisioning path. See [§3](#3-microsoftpowershell-missing-from-the-full-profile-conclusion). |
| `PSScriptAnalyzer`, `Pester`, `powershell-yaml` (PowerShell modules) | `pre-push-validate` (`Invoke-ScriptAnalyzer`/`Invoke-Pester`); `powershell-yaml` is also required by `scripts/Build-Configurations.ps1` / `scripts/Test-PackageIds.ps1` | **No winget or dotfiles provisioning at all.** `.github/workflows/lint.yml` runs `Install-Module -Name <module> -RequiredVersion <pinned> -Force -Scope CurrentUser -Repository PSGallery` fresh on every CI run; no equivalent exists for a local machine. | Unchanged — out of scope for the winget/dotfiles boundary; these are PowerShell Gallery modules, not OS packages. |

## 3. `Microsoft.PowerShell` missing from the full profile: conclusion

**Evidence.** The full profile (`packages.dsc.yaml`) omits the entire
"CLI shell tools" cluster that the min profile groups together:
`Starship.Starship`, `Zellij.Zellij`, `JesseDuffield.lazygit`,
`marlocarlo.psmux`, and `Microsoft.PowerShell` are all absent from
full and all present in min. This is not a PowerShell-specific
omission — full still carries several other CLI tools (`jqlang.jq`,
`MikeFarah.yq`, `twpayne.chezmoi`, `dbrgn.tealdeer`,
`FiloSottile.mkcert`, `junegunn.fzf`, `dandavison.delta`). The split
matches `README.md`'s own framing: min is "development tools only, no
gaming/media" (a CLI/terminal-focused profile), while full is a
general desktop setup (development, gaming, VRChat, daily use) that
includes core development requirements (Git, GitHub CLI, fnm, Android
Studio) but not the terminal power-user shell cluster. Git history
shows this split was introduced whole, in the initial DSC-migration
commit (`fe038c8`), with no later commit narrowing PowerShell out on
its own.

**Conclusion (two-sided).**

- For the full profile's intended audience — a general desktop setup —
  the omission is **consistent with an intentional category split**,
  not an isolated gap: it tracks the same terminal-shell-tools cluster
  as Starship/Zellij/lazygit/psmux, all of which are also absent.
- For the developer/IDD-agent use case this issue is investigating,
  the omission is a **real, unresolved functional gap**: a
  full-profile machine has no automatic path to `pwsh` at all —
  neither winget (full profile) nor dotfiles (confirmed above, no
  `mise` entry) provisions it. Unlike the Node.js/GitHub CLI gaps
  elsewhere in this document, `chezmoi apply` does **not** close this
  one. No first-wave or first-wave-adjacent tracked issue (#103,
  #105, #107, #108) adds a `pwsh` provisioning path to either profile
  or to dotfiles.

Both readings are recorded because they answer different questions:
the profile design is coherent as shipped, but it leaves
`pre-push-validate` unusable out of the box on a fresh full-profile
machine. See the workaround in [§4](#4-operations-gated-on-chezmoi-apply).

## 4. Operations gated on `chezmoi apply`

The first four rows below apply **once** the named tracked issue
ships; they do not apply to today's `master`. The last row is
different and included for completeness: it is a **present-day** gap
(unaffected by any first-wave track shipping) that `chezmoi apply`
does not fix at all — see [§3](#3-microsoftpowershell-missing-from-the-full-profile-conclusion).

| Operation | Needs | Workaround |
| --- | --- | --- |
| IDD `gh`-based operations (claim, PR, review, merge) on a local machine | GitHub CLI, once #107 ships | Run `chezmoi apply` first, or temporarily `winget install GitHub.cli` |
| `fix-validate` / `pre-push-validate` / any `idd-*` helper call (needs `npx`) on a local machine | Node.js, once #108 ships | Run `chezmoi apply` first, or temporarily install Node.js (e.g. `winget install Schniz.fnm`) |
| Interactive use of `ghq`, `copilot`, or `git vrc` as developer conveniences | ghq / GitHub Copilot CLI / git-vrc, once #107 / #105 ship | Run `chezmoi apply` first, or temporarily `winget install <package-id>` |
| The `git vrc` clean/smudge filter for VRChat assets (unitypackage/prefab-friendly diffs) | dotfiles' `home/dot_config/git/config.tmpl` `[filter "vrc"]` block, once #105 ships | Run `chezmoi apply` first, or manually add the equivalent `[filter "vrc"]` block to the global gitconfig |
| `pre-push-validate`'s `pwsh`-based checks on a full-profile machine, today | `pwsh` — **not** fixed by `chezmoi apply`, ever, under the current dotfiles definition | Manually `winget install Microsoft.PowerShell`, or select the min profile |

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
tracks with open implementation issues (Node.js: #103/#108; GitHub
CLI, ghq, and GitHub Copilot CLI: #107; git-vrc: #105). The one
dependency that could look like a reason to defer — the IDD loop's own
bootstrap dependency on `gh` (§1, §2) — is handled as **sequencing**,
not deferral: #111 records that #107 (which removes `GitHub.cli` from
winget) depends on #104 (this issue) precisely so the bootstrap
dependency is recorded before the winget definition is removed, not so
that removal is skipped. This issue does not block #103, #105, #107,
or #108 from proceeding.
