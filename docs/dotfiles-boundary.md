# Dotfiles Delegation Boundary

Roadmap #111 moves CLI tools and language runtimes from this
repository's winget/DSC definitions to
[`kurone-kito/dotfiles`](https://github.com/kurone-kito/dotfiles)'s
[mise](https://mise.jdx.dev/) configuration, in tracked waves. This
document is issue #104's inventory for the **first wave** —
Node.js, GitHub CLI, ghq, GitHub Copilot CLI, and git-vrc — recording
every in-repo dependency on each target. Three of the wave's five
implementation tracks merged **while this investigation was in
progress**: git-vrc (#105, PR #114), the full-profile `jdx.mise`
prerequisite for Node.js (#103, PR #113), and Node.js's own fnm
removal (#108, PR #117). Only GitHub CLI/ghq/GitHub Copilot CLI (#107)
remains open at the time of writing.

Two other documents in progress cover related but distinct ground:

- #110 (not yet merged) will update `README.md` / `README.ja.md` with
  the user-facing ownership boundary table and the `chezmoi apply`
  prerequisite, once #104/#107 have shipped (#103, #105, and #108
  already have). It is blocked by this issue and depends on it for the
  "operations that need `chezmoi apply`" list below.
- Roadmap issue #111 records the full cross-repo design rationale
  (why CLI tools move to dotfiles at all — the winget `portable`
  package / SSH symlink-traversal problem, and the `cmd.exe` PATH
  length limit) and the wave 2 plan. This document does not repeat
  that rationale; it only records **this repository's** current
  dependency surface.

Everything below reflects the state of `master` as investigated and
re-synced on 2026-08-14 (UTC), including after #105 (PR #114), #103
(PR #113), and #108 (PR #117) each merged mid-investigation the same
day. Statements about `kurone-kito/dotfiles` content are point-in-time
reads of that repository on the same date and can drift independently
of this repository.

**Scope note**: this document only records findings. It does not
change `.github/idd/config.json`, `configurations/*.dsc.yaml`, or (for
the still-open GitHub-CLI/ghq/Copilot-CLI removal work)
`libs/post-install.ps1` — those stay exactly as they are until #107
ships. `libs/post-install.ps1`'s git-vrc block (removed by #105) and
fnm block (removed by #108) were both already gone before this issue
merged (see the git-vrc and Node.js subsections below).

## 1. First-wave targets: in-repo dependencies

For each target, "today" describes current `master`; "after delegation"
describes the change once the named tracked issue ships. Anchors below
are DSC `resource`/`id` values and named script blocks rather than line
numbers — those are stable across `packages.dsc.yaml` regeneration,
while line numbers would drift on the next regeneration and go stale
immediately.

### Node.js

<!-- cspell:ignore Schniz -->

**Already delegated** — #108 merged as PR #117 on 2026-08-14, while
this issue was still in progress (its own prerequisite, #103's
full-profile `jdx.mise` addition, had merged as PR #113 earlier the
same day). `libs/post-install.ps1` no longer has any Node.js code: the
`### Node.js via fnm` block (`fnm env --use-on-cd`, `fnm install` per
version, `fnm default`) was removed in full, along with the
file-scoped `PSAvoidUsingInvokeExpression`
`SuppressMessageAttribute` that block needed (no other
`Invoke-Expression` use remains in the file). Alongside it, #108
removed: `pkg.fnm` (winget id `Schniz.fnm`) from
`configurations/packages.dsc.yaml` and its generated
`configurations/packages.import.json` fallback; the entire `Node` key
from `configurations/runtime-versions.psd1` (Unity/UnityCli entries
untouched); Node.js/`fnm` mentions from `README.md`/`README.ja.md`'s
architecture diagram, package list, and setup-step-5 summary (replaced
with a note that Node.js version management is dotfiles'
responsibility); the `fnm`/`Schniz` words from `.cspell.config.yml`;
and renamed the incidental `@{ Node = @{} }` fixture in
`tests/powershell/unity-cli-installer.Tests.ps1` /
`unity-editor-installer.Tests.ps1` to `@{ Other = @{} }`.
`docs/dsc-migration-notes.md`'s "Reviewing pinned Node/Unity versions"
section was also rewritten, gaining a new "Node.js ownership moved to
dotfiles (issue #108)" subsection that records the same delegation
this document does, independently.

**No in-repo Node.js provisioning definition remains** — that is
narrower than "no dependency": this repository still has a live
**runtime** dependency on Node.js/`npx`, documented in full in
[§2](#2-tooling-required-by-install-deps--fix-validate--pre-push-validate)
(`fix-validate`, `pre-push-validate`, `post-fix-validate`, and every
`idd-*` helper call all need it). What #108 removed is only this
repository's own means of *installing* Node.js — dotfiles now owns
that entirely, via `home/dot_config/mise/config.toml`'s
`node = "latest"` entry (confirmed live against `kurone-kito/dotfiles`
on 2026-08-14) — viable once #103 added `jdx.mise` to the full
profile (the min profile already had it). Both profiles have `mise`
unconditionally via winget today, but Node.js itself only comes from
it after `chezmoi apply` deploys that config entry — a present-day
condition, not a future one, same as git-vrc — see
[§4](#4-operations-gated-on-chezmoi-apply). This is also an
**intentional scope change**, not just a relocation: fnm allowed
multiple Node.js LTS lines to be installed side by side; `mise`
resolves to a single version per its config, so this repository no
longer supports that co-installed pattern — anyone who needs it must
configure it in dotfiles/mise directly.

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
- `README.md` / `README.ja.md` — both files' "Key categories" package
  summary lists "GitHub CLI" under **Development** (the full profile's
  section; #107 will need to update this line too).
- The IDD execution loop itself is built on the `gh` CLI. This is a
  **local-machine** dependency only — hosted GitHub Actions runners
  ship their own `gh` installation and are unaffected by this
  repository's or dotfiles' package choices. The full path list below
  is a point-in-time inventory (2026-08-14 UTC), classified by actual
  use; it will drift as this repository's own documentation changes —
  re-run the command to re-verify, but the classified list itself is
  what satisfies "every in-repo dependency location", not the command
  alone:

  ```sh
  grep -rl '\bgh\b' \
    .github/instructions/ docs/ .github/workflows/ .claude/skills/ \
    --exclude=dotfiles-boundary.md
  ```

  (`--exclude` is needed because this file's own prose quotes `gh`
  commands and would otherwise match itself. A bare `\bgh\b` replaces
  an earlier, narrower pattern that required a trailing space or a
  specific subcommand after `gh` — that version missed `gh` followed
  by punctuation (`gh-then-REST`, `` `gh` ``) and undercounted this
  list by 2 files. An earlier version still had a different bug — only
  the first alternative carried its own `\b`, so unanchored `gh
  issue`/`gh run` matched inside prose like "high issue(s)" — already
  fixed before this round.)

  <details>
  <summary>Classified file list (37 files)</summary>

  **Executes `gh`** (1): `.github/workflows/post-merge-cleanup.yml`
  (`gh pr view`, `gh api`, `gh pr comment`).

  **Instructs an agent to run `gh`** (26):
  `.claude/skills/issue-authoring/SKILL.md`,
  `.claude/skills/issue-authoring/references/contract.md`,
  `.github/instructions/idd-ci.instructions.md`,
  `.github/instructions/idd-claim.instructions.md`,
  `.github/instructions/idd-discover.instructions.md`,
  `.github/instructions/idd-merge-handoff.instructions.md`,
  `.github/instructions/idd-merge.instructions.md`,
  `.github/instructions/idd-pre-merge.instructions.md`,
  `.github/instructions/idd-pr-submit.instructions.md`,
  `.github/instructions/idd-resume-stall.instructions.md`,
  `.github/instructions/idd-review-fix.instructions.md`,
  `.github/instructions/idd-review-snapshot.instructions.md`,
  `.github/instructions/idd-review-triage.instructions.md`,
  `.github/instructions/idd-work.instructions.md`,
  `.github/instructions/lite/idd-ci-lite.instructions.md`,
  `.github/instructions/lite/idd-claim-lite.instructions.md`,
  `.github/instructions/lite/idd-merge-handoff-lite.instructions.md`,
  `.github/instructions/lite/idd-pr-submit-lite.instructions.md`,
  `.github/instructions/lite/idd-resume-stall-lite.instructions.md`,
  `.github/instructions/lite/idd-review-fix-lite.instructions.md`,
  `.github/instructions/lite/idd-review-snapshot-lite.instructions.md`,
  `docs/getting-started.md` (lists an authenticated `gh` CLI as a
  prerequisite for the agent running IDD),
  `docs/idd-advisory-wait-shell-fallback.md`,
  `docs/idd-comment-minimization.md`, `docs/idd-policy.md`,
  `docs/idd-workflow.md`.

  **Mentions `gh` in prose, without instructing execution** (10):
  `.claude/skills/issue-authoring/references/workflow-boundary.md`,
  `.github/instructions/idd-advisory-wait.instructions.md` (a
  backward-reference, "same gh-then-REST pattern as E14's...", to
  commands that actually live in `idd-review-fix.instructions.md`),
  `.github/instructions/idd-overview-core.instructions.md`,
  `.github/instructions/lite/idd-pre-merge-lite.instructions.md`,
  `.github/workflows/idd-advisory-convergence.yml` (a `#` comment
  explaining rerun recovery, not an executed step),
  `docs/customization.md`, `docs/idd-autonomy-contract.md`,
  `docs/idd-helper-scripts.md`,
  `docs/onboarding/template-distribution.md`, `docs/permissions.md`.

  </details>

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
| `post-fix-validate` | `npx -y markdownlint-cli2 --fix "**/*.md" && npx -y markdownlint-cli2 "**/*.md" && npx -y cspell lint "**" --no-progress && pwsh -c "Invoke-ScriptAnalyzer ..." && pwsh -c "Invoke-Pester ..."` — the union of `fix-validate` and `pre-push-validate`, so it needs the exact same tooling as both combined |

`install-deps` itself requires nothing directly, but this repository's
`helperRuntime.profile` is `ephemeral-npx` (see
[`docs/idd-policy.md`](idd-policy.md#helper-runtime-profile)): every
`idd-*` helper invocation (claim markers, review snapshots, CI-wait
state, merge readiness, this very digest update) runs through `npx`.
The Node.js dependency below therefore covers the whole IDD loop, not
just `fix-validate`/`pre-push-validate`. Using the same reproducible
approach as the GitHub CLI subsection above:

```sh
grep -rl '\bnpx\b' \
  .github/instructions/ docs/ .github/workflows/ .claude/skills/ \
  --exclude=dotfiles-boundary.md
```

<details>
<summary>Classified file list (20 files)</summary>

**Executes `npx`** (2): `.github/workflows/idd-advisory-convergence.yml`,
`.github/workflows/post-merge-cleanup.yml` — both run a pinned
`npx --yes --package ...` inside an actual `run:` step.

**Instructs an agent to run `npx`** (6): `docs/getting-started.md`
(lists Node.js/`npx` as a conditional agent prerequisite);
`docs/idd-policy.md` (the literal `npx --yes --package ...` waiver-helper
command); `docs/onboarding/placeholders.md` (the literal
`fix-validate`/`pre-push-validate` `npx` commands as onboarding
template text); `.github/instructions/idd-overview-core.instructions.md`
(the same command-table definitions reproduced in section 2's table
above); `docs/customization.md` and
`docs/onboarding/policy-decisions.md` (both give an imperative "run
the manifest helper..." followed by a literal
`npx --yes --package ...` code block).

**Mentions `npx` in prose, without instructing execution** (12): the
remaining files reference `npx`/`ephemeral-npx` as a **named helper
profile or capability**, not as a literal command to run at that
point — `.claude/skills/issue-authoring/references/contract.md`,
`docs/idd-advisory-wait-shell-fallback.md`,
`docs/idd-helper-scripts.md`,
`docs/onboarding/agent-entry-and-verification.md`,
`.github/instructions/idd-advisory-wait.instructions.md`,
`.github/instructions/idd-ci.instructions.md`,
`.github/instructions/idd-claim.instructions.md`,
`.github/instructions/idd-discover.instructions.md`,
`.github/instructions/lite/idd-advisory-wait-lite.instructions.md`,
`.github/instructions/lite/idd-ci-lite.instructions.md`,
`.github/instructions/lite/idd-claim-lite.instructions.md`,
`.github/instructions/lite/idd-review-fix-lite.instructions.md`.

</details>

| Tool | Needed by | Provisioning source today | After delegation |
| --- | --- | --- | --- |
| `npx` (Node.js) | `fix-validate`, `pre-push-validate`, `post-fix-validate`, every `idd-*` helper call | **Already delegated (#108, PR #117)** — this repository no longer installs Node.js at all, on either profile. Both profiles have `jdx.mise` via winget unconditionally, but Node.js itself only comes from `mise` reading dotfiles' `node = "latest"` entry, which needs `chezmoi apply` to deploy — see the Node.js subsection in [§1](#1-first-wave-targets-in-repo-dependencies) and the cross-cutting caveat in [§4](#4-operations-gated-on-chezmoi-apply) | N/A — already the target state |
| `gh` | The IDD loop's own bootstrap (not `fix-validate`/`pre-push-validate` directly) | full and min: `GitHub.cli` (winget) | dotfiles' `github:cli/cli` (mise) once #107 ships |
| `pwsh` (PowerShell 7) | `pre-push-validate`/`post-fix-validate` (`Invoke-ScriptAnalyzer`, `Invoke-Pester`) | Both profiles install PowerShell 7 today, via different package identities: full uses `pkg.pwsh` (Microsoft Store id `9MZ1SNWT0N5D`); min uses `Microsoft.PowerShell` (native winget id). Not a delegation-relevant gap — see [§3](#3-powershell-7-provisioning-in-the-full-profile-conclusion). | Unchanged — no first-wave track touches either `pwsh` package definition. |
| `PSScriptAnalyzer`, `Pester`, `powershell-yaml` (PowerShell modules) | `pre-push-validate`/`post-fix-validate` (`Invoke-ScriptAnalyzer`/`Invoke-Pester`); `powershell-yaml` is also required by `scripts/Build-Configurations.ps1` / `scripts/Test-PackageIds.ps1` | **No automated winget or dotfiles provisioning on either profile, for any of the three.** `.github/workflows/lint.yml` runs `Install-Module -Name <module> -RequiredVersion <pinned> -Force -Scope CurrentUser -Repository PSGallery` fresh on every CI run for all three. `docs/testing.md` documents the manual command for **local** development for `Pester`; `scripts/Build-Configurations.ps1`'s and `scripts/Test-PackageIds.ps1`'s own help-comment headers document the same manual command for `powershell-yaml`. Only `PSScriptAnalyzer` has no local-install documentation anywhere in this repository — just its CI provisioning in `lint.yml`. Nothing automates any of the three for a fresh local machine (either profile). | Unchanged — out of scope for the winget/dotfiles boundary; these are PowerShell Gallery modules, not OS packages. |

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

`Starship.Starship`, `Zellij.Zellij`, `JesseDuffield.lazygit`, and
`marlocarlo.psmux` are genuinely absent from full and present only in
min — but this is **not** a coherent "CLI shell tools" category split.
In `packages.min.dsc.yaml`, these four packages sit under three
different section comments (`lazygit`: "CLI SCM utilities"; `psmux`/
`Zellij`: "CLI session management tools"; only `Starship` shares "CLI
shell tools" with `Microsoft.PowerShell`), and full isn't missing
prompt-theming tooling generally — it installs `pkg.ohMyPosh` (Oh My
Posh, another prompt theme engine, msstore id `XP8K0HKJFRXGCK`) as a
direct counterpart to Starship. The accurate framing is
package-specific: full and min simply carry different, non-overlapping
selections of terminal/session tools, not a category full skips
wholesale. `README.md`'s min: "development tools only, no gaming/media"
framing still holds at the profile-purpose level; it just doesn't map
onto a single missing category the way the earlier version of this
section implied.

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

Rows 1-2 below apply **once** #107 ships; they do not apply to today's
`master`. Rows 3-5 (Node.js, git-vrc) already apply **today**, since
issues #108 and #105 each merged during this investigation. Row 6 is
unrelated to any first-wave track and `chezmoi apply` does not fix it
either — see the PowerShell-modules row in
[§2](#2-tooling-required-by-install-deps--fix-validate--pre-push-validate).

**Cross-cutting caveat for every "run `chezmoi apply` first" workaround
below**: dotfiles' `run_onchange_after_50-install-mise-tools.ps1.tmpl`
— the script that actually installs mise-managed tools (Node.js, `gh`,
`ghq`, the GitHub Copilot CLI, git-vrc) — starts with
`if (-not (Get-Command mise ...)) { Write-Host 'mise not found;
skipping.'; exit 0 }`. It **silently no-ops**, not fails, when `mise`
itself isn't on `PATH`.

Both profiles have `jdx.mise` via winget unconditionally (min always
did; full gained it via #103), so the predictable "no `mise` package
at all" failure mode does not apply to either profile. A subtler
version remains on **both**: `run_onchange_` scripts are keyed on a
content hash (the script's own header comment: "Re-runs when mise
config changes"), not on whether the previous run actually did the
work — chezmoi has no way to distinguish "did the work" from
"successfully chose to no-op" once the script exits `0` either way. If
`mise` isn't yet reachable on `PATH` in the shell `chezmoi apply` runs
in on a machine's **first** apply (for example, PATH hasn't refreshed
in the current session since winget just installed `jdx.mise`), the
no-op still gets recorded against that content hash. Installing `mise`
afterward, or reconnecting the session, does not change the hash — a
later plain `chezmoi apply` will **not** retry the script. The
workaround in that case is a manual `mise install && mise reshim` once
`mise` is reachable, not another `chezmoi apply`.

| Operation | Needs | Workaround |
| --- | --- | --- |
| IDD `gh`-based operations (claim, PR, review, merge) on a local machine | GitHub CLI, once #107 ships | Run `chezmoi apply` first (see the cross-cutting caveat above), or temporarily `winget install GitHub.cli` |
| Interactive use of `ghq` or the GitHub Copilot CLI as developer conveniences | ghq / GitHub Copilot CLI, once #107 ships | Run `chezmoi apply` first (see the cross-cutting caveat above), or temporarily `winget install x-motemen.ghq` / `winget install GitHub.Copilot` |
| `fix-validate` / `pre-push-validate` / `post-fix-validate` / any `idd-*` helper call (needs `npx`) on a local machine — **applies today** | Node.js | Run `chezmoi apply` first (see the cross-cutting caveat above). This repository has **no winget package for Node.js** as of #108 — a temporary local install must either reinstall `fnm` directly from the public winget catalog (`winget install Schniz.fnm`, not defined in this repo anymore) and then run `fnm env --use-on-cd \| Out-String \| Invoke-Expression` plus `fnm install <version> && fnm default <version>`, or install a self-contained Node.js package directly (e.g. `winget install OpenJS.NodeJS.LTS`) |
| Interactive use of the `git vrc` binary, or any operation needing it — **applies today** | git-vrc | Run `chezmoi apply` first (see the cross-cutting caveat above). This repository has **no winget package id for git-vrc** — a temporary local install must use the command the now-removed `post-install.ps1` block used to run: `cargo install --locked --git https://github.com/anatawa12/git-vrc.git`. That itself needs `cargo`: `Rustlang.Rust.MSVC` is full-profile only (`configurations/packages.min.dsc.yaml` has no Rust entry), so a min-profile machine needs Rust installed some other way (e.g. `winget install Rustlang.Rust.MSVC`) before this fallback works |
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
tracks with implementation issues (Node.js: #103 and #108, both
merged while this issue was in progress; GitHub CLI, ghq, and GitHub
Copilot CLI: #107, still open; git-vrc: #105, merged as PR #114 while
this issue was in progress). The one dependency that could look like a
reason to defer — the IDD loop's own bootstrap dependency on `gh` (§1,
§2) — is handled as **sequencing**, not deferral: #111 records that
issue #107 (which removes `GitHub.cli` from winget) depends on #104
(this issue) precisely so the bootstrap dependency is recorded before
the winget definition is removed, not so that removal is skipped.
Issues #103, #105, and #108 no longer need to be listed here as
blocked — all three already shipped. #107 specifically is gated on
this issue merging first — roadmap #111 records the dependency edge
between #107 and #104 explicitly (as "depends on"), and #107 itself is
filed as `Blocked by #104`. That is the sequencing this section is
about: a deliberate, temporary ordering gate on one target, not a
deferral of delegation itself.
