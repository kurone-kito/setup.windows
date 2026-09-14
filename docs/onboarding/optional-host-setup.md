# Onboarding Reference — Optional Host Setup

Use this reference alongside `idd-template/ONBOARDING.md` when you want to
enable one of the optional host-level integrations it mentions but does not
walk through inline. None of these steps are required to finish the hearing
or the core import.

This page is the detailed companion for:

- Optional — enable the local worktree guard
- Optional — run idd-doctor as a CI health gate
- Optional — host idd-advisory-convergence as a required-check CI workflow
- Optional — mark the vendored helper bundle `linguist-vendored`

## Optional — enable the local worktree guard

The template ships an opt-in git hook set under `.githooks/` that
refuses commits and pushes made from the **primary** worktree while
HEAD is on an implementation branch (`issue/*` or `roadmap-audit/*`),
enforcing the B1 disposable-worktree rule locally. The hooks are pure
POSIX sh — no Node, `jq`, or other runtime dependency.

To enable it in the target repository:

1. Set `worktreeGuard.enabled` to `true` in `.github/idd/config.json`
   (the guard is off by default).
2. Point git at the shipped hooks. `core.hooksPath` is local and not
   committed, so each clone runs this once:

   ```sh
   git config core.hooksPath .githooks
   chmod +x .githooks/pre-commit .githooks/pre-push
   ```

3. On a native-Windows checkout, add an explicit LF rule for the three
   shipped hook files to the target repository's own `.gitattributes`
   (the template does not ship one — see "Out of scope" in
   kurone-kito/idd-skill#2060):

   ```gitattributes
   .githooks/* text eol=lf
   ```

   Git for Windows' installer defaults to `core.autocrlf=true`
   ("Checkout Windows-style, commit Unix-style line endings"). With no
   `.gitattributes` override, that setting checks these files out as
   CRLF; the trailing `\r` then breaks the `.`/`source` line that loads
   `_idd-worktree-guard.sh`, hard-blocking every commit and push. A
   `*.sh` rule alone is not enough — `pre-commit` and `pre-push` ship
   without an extension, so they need this explicit `.githooks/*` path
   rule to be covered too.

4. Native-Windows adopters chaining fork-heavy tooling after the guard
   (a linter, `lint-staged`, and similar) are more exposed to a class
   of Cygwin/MSYS `fork()` fragility unrelated to this template
   (observed in `kurone-kito/builder-config`, 2026-08-14, cited in
   kurone-kito/idd-skill#2068 — a native-Windows commit failed inside
   `.githooks/pre-commit` with a Cygwin `dofork` failure ("died
   unexpectedly"); root cause is generic Git-for-Windows/Cygwin
   `fork()` emulation fragility, not a defect in this template or
   repository — see
   [git-for-windows/git#1176](https://github.com/git-for-windows/git/issues/1176)).
   Standard host-level remediations, none of them actionable from
   inside this repository, and each a temporary, last-resort
   mitigation requiring the operator's own administrator approval —
   restore the affected protection immediately once the guard's
   commit or push succeeds, and scope any antivirus exclusion as
   narrowly as the antivirus product allows (ideally just the
   `.githooks/` directory, not the whole repository or Git-for-Windows
   install tree, if the product supports that granularity): exclude
   the affected path(s) from antivirus real-time scanning; remove any
   duplicate or stale MSYS/Cygwin runtime DLL (`msys-2.0.dll` for Git
   for Windows itself, or `cygwin1.dll` if a separate Cygwin install is
   also on `PATH`) from `PATH`; and disable Mandatory ASLR for the
   affected `sh.exe`/`bash.exe` via Windows Security's Exploit
   Protection settings.

When `worktreeGuard.enabled` is absent or `false`, the hooks are a
no-op. To bypass the guard for a single intentional commit or push,
pass `--no-verify`. CI cannot detect this class of violation — a
primary-worktree mistake leaves no trace in the pushed history — so
this local hook, together with `idd-doctor --strict`, is the practical
enforcement surface.

### Coexisting with an existing hook manager

`core.hooksPath` is repository-wide git config, not scoped to whichever
worktree set it: activating or resetting it from any one worktree of a
clone changes hook resolution for every other worktree of that same
clone too, including the primary worktree.

An existing hook manager (Husky or similar) can silently reset
`core.hooksPath` back to its own hooks directory on every
install/prepare lifecycle run — Husky v9's default `prepare: "husky"`
script repoints `core.hooksPath` at `.husky/_` unconditionally, so a
routine `pnpm install` after activation leaves this guard unwired
again with no error. `idd-doctor`'s enabled-but-inert detection (below) correctly
flags this again, but nothing about the reset itself is a bug — do not
assume `core.hooksPath` is free to claim outright. Chain each existing
hook to the corresponding `.githooks/*` script instead, resolving the
repository root explicitly so the hook still works when git invokes it
from a subdirectory. When the hook manager doesn't define that hook
file yet (for example, Husky ships only `pre-commit` until an adopter
adds `pre-push` themselves), create it with the chain line as its
entire contents, using `exec` since nothing else needs to run
afterward. When the file already exists but has no terminal `exec` or
`exit` of its own, append the same `exec` form as its last line. When
the file already ends in a terminal `exec` or `exit`, don't `exec` the
chain line too — `exec` never returns, so it would swallow that
terminal command exactly as surely as appending after it would.
Instead insert an _invoked_ (not `exec`'d) call before it, propagating
a nonzero exit so a failing guard still stops the hook, while a
passing one lets control reach the manager's own terminal command
afterward. The B1 guard needs both hooks chained:

```sh
# .husky/pre-commit doesn't exist yet, or has no terminal exec/exit of its own
# -- create or append this as the last line:
exec "$(git rev-parse --show-toplevel)/.githooks/pre-commit" "$@"

# .husky/pre-commit already ends in a terminal exec/exit -- insert this line
# before it instead (not exec'd, so that command still runs):
"$(git rev-parse --show-toplevel)/.githooks/pre-commit" "$@" || exit $?
```

The same two forms apply to `.husky/pre-push`, substituting
`pre-push` for `pre-commit` throughout.

`idd-doctor`'s enabled-but-inert check follows a bounded one-level
dispatch: when the hook file at the resolved `core.hooksPath` does not
itself source the guard, it also checks the corresponding hook file in
`core.hooksPath`'s **parent** directory — the shape Husky v9's own
`.husky/_` split takes — for one of the two documented chain forms
above, and confirms the referenced `.githooks/<hook>` script itself
genuinely sources the guard (observed 2026-08-11 during PR #1948's
review; [#1951](https://github.com/kurone-kito/idd-skill/issues/1951)).
A setup that follows the recipe above for **both** hooks now reads as
wired, not enabled-but-inert. The check still does not trace an
arbitrary hook manager's own dispatch machinery beyond that one
documented level: it confirms a hook file exists **and is executable**
at `core.hooksPath` — since git itself silently skips a non-executable
one — but does not verify that file's own content genuinely hands off
to the parent sibling it trusts, so a present-but-inert or corrupted
dispatcher stub can still read as wired even though git never reaches
the parent chain (preventive; no observed incident yet). Conversely, a
manager using a different indirection shape entirely can still warn
even when the guard is genuinely reachable through it; a warning while
only one hook is chained, or while the chain targets a missing or
incorrect `.githooks/*` script, remains actionable as intended either
way.

Recognizing the two chain forms above is itself a bounded lexical
heuristic, not a shell parser: it matches the documented forms as an
ordinary standalone physical line and deliberately does not evaluate
quoting edge cases, variable expansion, here-docs, `eval`, subshell
wrapping, or other adversarial or unusual shell constructions that
could reach one of the two forms at runtime while lexically evading
this check, or vice versa (preventive; no observed incident yet). This
is a warning-level misconfiguration diagnostic, not a security
boundary — an operator who wants to fool it can simply not enable the
guard — so hardening against constructions beyond the documented
recipe stays out of scope absent an observed incident.

Fully replacing an existing hook manager instead of chaining it removes
that tool from the repository outright, so treat it as an alternative
worth knowing about, not the default recommendation. Under pnpm's
`shellEmulator: true`, a fully-replacing lifecycle script still needs
to be POSIX-control-flow-free — no `if`/`then`/`fi`, which
`shellEmulator`'s reduced grammar cannot parse. For example, a
replacement `package.json` `"prepare"` script needs a short-circuit
instead:

```sh
git rev-parse --git-dir > /dev/null 2>&1 || exit 0; git config core.hooksPath .githooks && chmod +x .githooks/pre-commit .githooks/pre-push
```

Neither path — chaining or fully replacing — is wired automatically by
this template: the operator (or an agent following this guide) has to
author and commit the chaining line or the replacement script
explicitly. Once committed, propagation to a future clone happens
through whichever install/prepare lifecycle now owns it there. For
chaining, that's the existing hook manager's own lifecycle — never
repoint git directly at `.githooks` there by manually repeating the
base activation step above, since a manager is still present and that
step would bypass it. For fully replacing, that's the repository's own
replacement lifecycle script; repeating the base activation step there
is harmless, since no manager remains to bypass and the step sets the
identical value the replacement script would. That base step stays the
right standalone action only for a clone with no hook manager involved
at all, where there is no lifecycle script to carry it forward.

### Activation in a coding-agent / ephemeral environment

The `git config core.hooksPath` step above is **local and uncommitted**, so
any environment that starts from a fresh clone per task never inherits it: a
coding agent such as the GitHub Copilot coding agent, an ephemeral container,
or a throwaway checkout all begin unwired. There, `worktreeGuard.enabled:
true` on its own enforces nothing — without `core.hooksPath` pointed at
`.githooks` the shipped hooks never run, so a lightweight model can commit
from the primary worktree undetected. CI cannot backstop this (the violation
leaves no pushed-history trace and CI checks out a detached HEAD), so
activation has to happen inside the agent's own setup.

Wire the hooks as the agent's environment-setup step — the first thing it
runs before any work, or the platform's setup mechanism (for the GitHub
Copilot coding agent, its `copilot-setup-steps` workflow). A
repository that fully replaces a hook manager (above) can keep this
command unconditional: no manager remains to bypass, and it sets the
same value the replacement script would. A repository that instead
chains an existing hook manager needs a different setup step: skip
this direct command — it would repoint git at `.githooks` and bypass
the chained manager — and instead make the agent's setup explicitly
run that manager's own install/prepare lifecycle (for example, a
`pnpm install` step), since a fresh ephemeral clone does not run it
automatically either; skipping the command without also running that
lifecycle leaves the guard unwired despite following this guidance.
Otherwise, for a repository with no hook manager involved:

```sh
git config core.hooksPath .githooks && chmod +x .githooks/pre-commit .githooks/pre-push
```

For the direct or fully-replacing path, because the agent re-runs this
every task, the guard stays active for the whole session — confirm it
actually took effect with `idd-doctor`, which surfaces an
**enabled-but-inert** finding when `worktreeGuard.enabled` is `true`
but `core.hooksPath` is not pointed at `.githooks` and no recognized
chain is present, the signal that the setup step silently did not run
(the chaining path below intentionally keeps `core.hooksPath` pointed
at the manager's own directory instead, so that condition alone does
not fire there). For the chaining path, `idd-doctor`'s
confirmation now covers the documented recipe the same way it covers
the direct/fully-replacing path above — a correctly chained setup
reads as wired once the manager's lifecycle has actually run.
Chain-line presence alone still isn't a safe substitute for running
`idd-doctor`, though: a fresh ephemeral clone checks out the committed
chain lines immediately, even when the setup lifecycle never ran and
`core.hooksPath` is still unset, which `idd-doctor` still correctly
reports as enabled-but-inert (`core.hooksPath = (unset)`; preventive,
no observed incident yet). If a custom dispatch shape falls outside
the documented one-level recipe (above; also preventive, no observed
incident yet), fall back to verifying both explicitly: that the
committed chain lines are present in the manager's hook files, and that
`git config --get core.hooksPath` resolves to the manager's own hooks
directory (not empty), confirming its lifecycle actually ran and wired
that value rather than just that the files exist. This is activation
guidance only; the adopter default stays opt-in **off**.

## Optional — run idd-doctor as a CI health gate

Running `idd-doctor` in CI catches repository-health regressions
(config/schema drift, unresolved placeholders, marker-prefix
inconsistency, missing required files) on every change. It is opt-in —
add a workflow such as one of the profile-specific examples below,
matching the repository's confirmed helper-runtime profile.

**`vendored-node`** — the helper bundle is copied into `scripts/`:

```yaml
name: IDD doctor health gate
on:
  pull_request:
permissions:
  contents: read
  issues: read
  pull-requests: read
jobs:
  idd-doctor:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          ref: ${{ github.sha }} # detached HEAD keeps the worktree check inert
          persist-credentials: false
      - run: node scripts/idd-doctor.mjs
        env:
          GH_TOKEN: ${{ github.token }}
          GH_ENTERPRISE_TOKEN: ${{ github.token }}
```

**`package-manager`** — the helper ships as an installed
`devDependency` invoked through the repository's package manager. This
example uses pnpm; swap the `pnpm/action-setup` step and the install /
invoke commands for npm or yarn equivalents if the repository uses a
different package manager:

```yaml
name: IDD doctor health gate
on:
  pull_request:
permissions:
  contents: read
  issues: read
  pull-requests: read
jobs:
  idd-doctor:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          ref: ${{ github.sha }} # detached HEAD keeps the worktree check inert
          persist-credentials: false
      - uses: pnpm/action-setup@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 24.x
          cache: pnpm
      - run: pnpm install --frozen-lockfile
      - run: pnpm exec idd-doctor
        env:
          GH_TOKEN: ${{ github.token }}
          GH_ENTERPRISE_TOKEN: ${{ github.token }}
```

**`ephemeral-npx`** — no helper files or `devDependency` are vendored;
resolve the helper command one-shot instead. Replace
`<reviewed-helper-spec>` with the same reviewed spec the repository's
other helper invocations use (see
[Onboarding Reference — Policy Decisions](policy-decisions.md#helper-runtime-profile)):

```yaml
name: IDD doctor health gate
on:
  pull_request:
permissions:
  contents: read
  issues: read
  pull-requests: read
jobs:
  idd-doctor:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          ref: ${{ github.sha }} # detached HEAD keeps the worktree check inert
          persist-credentials: false
      - uses: actions/setup-node@v4
        with:
          node-version: 24.x
      - run: npx --yes --package <reviewed-helper-spec> idd-doctor
        env:
          GH_TOKEN: ${{ github.token }}
          GH_ENTERPRISE_TOKEN: ${{ github.token }}
```

Both the extra `permissions:` scopes and a host-matching token are
required: without the correct host-scoped token (`GH_TOKEN` on
`github.com`/`ghe.com`; `GH_ENTERPRISE_TOKEN` on GHES — see below),
`gh` has no credential, so idd-doctor's GitHub-API-backed checks
silently skip or emit one generic warning, yet the job still reports
success — a green gate that checked less than it appears to (observed
on this repository's own workflow,
kurone-kito/idd-skill#1828). With them, the post-merge cleanup backlog
and autopilot-suitability checks actually run instead of being
silently skipped. The branch-protection probe stays unreadable
regardless: it needs a repository-administration permission that
GitHub Actions' `permissions:` model can't grant to `GITHUB_TOKEN`, so
it keeps warning even with these scopes added.

**Setting `GH_TOKEN` and `GH_ENTERPRISE_TOKEN` together.** `gh`'s
environment-variable auth resolution is host-scoped (`gh help
environment`): `GH_TOKEN`/`GITHUB_TOKEN` apply only when a command
targets `github.com` or a `ghe.com` subdomain, while a self-hosted
GitHub Enterprise Server (GHES) host reads
`GH_ENTERPRISE_TOKEN`/`GITHUB_ENTERPRISE_TOKEN` instead. `gh` only
reads the variable that matches its resolved host, so the three
examples above set both — harmless on `github.com` and additive on
GHES — instead of branching per host. If you copy one of these
examples onto a GHES-hosted repository, keep both lines rather than
deleting `GH_ENTERPRISE_TOKEN` as apparently redundant (preventive; no
observed incident yet).

**Setting the token alone is not sufficient by itself on GHES.** `gh
api`/`gh api graphql` resolve their target host from `GH_HOST`/
`--hostname` (or the CLI's configured default), not from the
checked-out repository's Git remote the way `gh pr view`/`gh issue
edit` do — so on a GHES-hosted repository, an unset `GH_HOST` would
otherwise send these calls to `api.github.com` using `GH_TOKEN`, with
`GH_ENTERPRISE_TOKEN` never read at all (observed 2026-08-11, a Codex
advisory review on
[kurone-kito/idd-skill#1959](https://github.com/kurone-kito/idd-skill/pull/1959)).
`src/scripts/gh-exec.mts`'s shared `ghApiJson`/`ghGraphql` wrappers now
resolve the correct `--hostname` automatically
([kurone-kito/idd-skill#1962](https://github.com/kurone-kito/idd-skill/issues/1962)),
preferring an explicit `GH_HOST` when set (in which case no
`--hostname` is added — `gh` already resolves it correctly on its
own) and otherwise, in GitHub Actions, deriving the host from the
`GITHUB_SERVER_URL` default environment variable (no workflow `env:`
change needed, and no behavior change at all on `github.com`, where it
already equals the default host). Outside Actions (a local
`idd-doctor` run) with neither signal set, they defer to `gh`'s own
single-authenticated-host default, same as `gh` itself.
`idd-advisory-convergence` (both the CI-hosted
required-check workflow and its underlying `advisory-convergence.mts`
GitHub-API calls) goes through these shared wrappers, so it is covered
end to end. `idd-doctor.mts`'s own few direct `gh api` call sites do
not route through `gh-exec.mts` and are **not** covered by this fix —
a GHES adopter relying on `idd-doctor`'s GitHub-API-backed checks
(post-merge cleanup backlog, autopilot-suitability) should still treat
host resolution there as an open gap.

This gate checks repository **health**, not the disposable-worktree rule:
CI cannot detect a primary-worktree B1 violation (it leaves no trace in
pushed history and CI checks out a detached HEAD), so worktree
enforcement stays local — the `core.hooksPath` hook above, the
cwd-vs-claim gate, and `idd-doctor --strict` run on a developer's
machine.

**Branch-glob vs CI-trigger.** Put PR-gating checks in the
`pull_request`-triggered workflow (as above). A `push` workflow filtered to a
**top-level branch glob** such as `'*'` silently skips the slash-namespaced
IDD branches (`issue/*`, `roadmap-audit/*`): a single-star glob does not match
across the `/`, so a gating job placed only under `on: push` with `'*'` never
runs on IDD branches. Use `pull_request` triggers (which fire on the PR
regardless of branch name), or a push filter that matches the slash namespace
(`'**'` or `'issue/**'`), for any check that must gate IDD pull requests.

## Optional — host idd-advisory-convergence as a required-check CI workflow

For repositories that vendor the IDD helper scripts, hosting the
`advisory-convergence` helper (`docs/idd-helper-scripts.md`) as a CI
workflow turns "Copilot's review converged on the current PR HEAD" from
an instruction the execution model must choose to honor into a
status check GitHub itself can enforce. It is opt-in — the template
already mirrors the workflow at
[`idd-template/.github/workflows/idd-advisory-convergence.yml`](../../.github/workflows/idd-advisory-convergence.yml)
and its comment-refresh companion
[`idd-template/.github/workflows/idd-advisory-convergence-comment.yml`](../../.github/workflows/idd-advisory-convergence-comment.yml);
copy both files into your repository's `.github/workflows/` to
enable it. Register only the required job id
`idd-advisory-convergence` as a status check — the companion is
non-required. They are not wired in automatically by importing the
rest of `idd-template/`, since adding a new required-status-check-able
workflow is a deliberate adopter decision, not a default.

Adjust the command to your helper-runtime profile, and the
`actions/checkout` version if needed — the mirrored file intentionally
uses the floating `@v4` form. The shipped runner default is
`ubuntu-slim`; override it via the `runner` workflow input or the
`CI_RUNNER_LABEL` repository variable (Settings > Secrets and
variables > Actions > Variables) rather than hand-editing `runs-on`.
Setting a self-hosted label is **required**, not optional, on GitHub
Enterprise Server, which does not support GitHub-hosted runners at
all — the same override also covers any organization that mandates
self-hosted runners even on github.com/GHEC. This
source repository's own copy at
`.github/workflows/idd-advisory-convergence.yml` instead pins a
specific `actions/checkout` SHA and hardcodes a custom runner label,
which is appropriate for its own hardened, dogfooded CI but not a
requirement for adopters. This workflow is read-only: it never mutates GitHub
state, only queries the GitHub API for reviews, review threads, and
waiver markers. `issues: read` is required in addition to
`pull-requests: read` because the helper reads the PR's own
conversation comments via the issue-comments REST endpoint, which
GitHub gates under the Issues permission category even when the issue
number is a pull request.

**Protect the workflow definition with CODEOWNERS.** A
`pull_request`-triggered workflow runs its definition from the pull
request's synthetic merge commit/ref before any job step can perform the
trusted `main` checkout. That checkout protects the helper and
configuration that the job runs, but it cannot protect a workflow
definition changed in the pull request. This is preventive guidance; no
observed incident is being claimed here.

Add CODEOWNERS coverage for the workflow and for the active CODEOWNERS
file itself. GitHub searches for `CODEOWNERS` in `.github/`, the
repository root, then `docs/`, so add the self-ownership entry at the
location that is active. For example, with `.github/CODEOWNERS`:

```text
/.github/workflows/idd-advisory-convergence.yml @maintainer-user
/.github/CODEOWNERS @maintainer-user
```

Replace `@maintainer-user` with an eligible non-author maintainer who has
write access. For a team, use the full `@organization/team-name` form;
the team must be visible and have explicit write access. The autonomous
pre-merge helper currently resolves direct user owners, not team
membership, so a team-only owner can leave Code Owner approval ambiguous;
use a direct user owner for autonomous merging or plan for a human merge
until team-membership resolution is supported (preventive; no observed
incident yet). An approval from the PR author does not count toward
required review or Code Owner gates, so choose a separate eligible owner
or document the intended reviewer or ruleset-bypass topology.

CODEOWNERS can nominate owners for other changed paths as well; an
approval from one of those owners can satisfy a repository-wide Code Owner
review without proving that the owner resolved for the protected workflow
or input paths approved. Keep every owner reachable through those changed
paths within the same trust boundary, or require a gate that verifies
approval from the owner resolved for the protected paths (preventive; no
observed incident yet).

Place these protection entries after broader or overlapping patterns. When
extending the file, move them after any new rule that also matches these
paths; CODEOWNERS uses the last matching rule. If the active file is
`/CODEOWNERS` or
`/docs/CODEOWNERS`, also add ownership entries for every higher-priority
supported location that could replace it (`/.github/CODEOWNERS`, and for
`/docs/CODEOWNERS`, `/CODEOWNERS` as well) (preventive; no observed
incident yet).

For every candidate location that an adopter may activate, copy the
complete workflow, broad-workflow, trusted-input, and active-CODEOWNERS
protection set into that candidate file before introducing it. Put its
self-ownership entry in that same complete set:
`/.github/CODEOWNERS @maintainer-user` in `.github/CODEOWNERS`,
`/CODEOWNERS @maintainer-user` in the repository-root file, and
`/docs/CODEOWNERS @maintainer-user` in the docs file, where each file is
used. A higher-priority file becomes active as soon as it exists, so a
candidate containing only its self-entry would replace the lower-priority
file and drop the workflow or trusted-input protections. Perform this
complete preparation in the trusted preliminary change as well, and keep
each self-ownership entry after overlapping rules in its own file
(preventive; no observed incident yet).

Establish the active CODEOWNERS file and the **Require review from Code
Owners** setting in a trusted preliminary change before introducing this
workflow or registering its required check. If bootstrapping both in one
PR is unavoidable, require equivalent explicit maintainer validation;
GitHub evaluates CODEOWNERS from the base branch when it requests
reviews, so a new CODEOWNERS file in the same PR cannot protect that
bootstrap change (preventive; no observed incident yet).

Also protect every trusted input that the workflow checks out from
`main`, not only the workflow file — for example `/.github/idd/`,
`/scripts/advisory-convergence.mjs`, and its transitive runtime inputs
(or an immutable protected artifact). The exact set depends on the
adopter's imports; inspect the workflow and helper before finalizing
the entries. The current PR run cannot be weakened by PR copies of
these paths because it checks out `main`, but later runs would trust
them after merge (preventive; no observed incident yet).

Also review repository or organization variables that select the runner,
such as `CI_RUNNER_LABEL`, together with self-hosted runner administration
and runner integrity. Require an equivalent protected trust boundary for
any self-hosted runner label (preventive; no observed incident yet).

Before enabling the required check, either pin every action used by this
merge gate to a verified full commit SHA, or explicitly accept and record the
action publishers and tag-movement trust scope for any mutable references.
The shipped workflow's `@v4` references are portable examples only; do not
treat CODEOWNERS as sufficient protection for mutable action references
(preventive; no observed incident yet).

Protect `/.github/workflows/` (or `/.github/`) regardless of whether
the required check uses `app_id: -1` or a producer-pinned Actions
integration, unless that integration is dedicated exclusively to this
check. An `app_id` identifies an integration, not an individual
workflow, so broad workflow ownership remains necessary to prevent
another workflow from emitting the same required-check name under the
accepted integration (preventive; no observed incident yet). For
`app_id: -1` (any producer), a single-file
rule does not bind the check to that workflow. A credential holder with
`statuses: write` or `checks: write` can still publish that name
directly; CODEOWNERS covers workflow-file changes only (preventive; no
observed incident yet). Either explicitly trust every credential that
can publish checks, or use a producer-pinned required check with a
specific integration `app_id`
after verifying that IDD can read and enforce that topology. A ruleset
`workflows` rule is not a drop-in source-bound alternative here
(preventive; no observed incident yet): IDD
cannot correlate its unnamed result to a check run and will keep CI
unresolved, so plan for a human merge or hold until the runtime supports
it. Then enable **Require review from Code Owners** on the protected
default branch, or the equivalent repository-ruleset requirement, and
enable **Dismiss stale pull request approvals when new commits are
pushed** (or its equivalent) so approval applies to the workflow
revision that will merge. Without those settings, CODEOWNERS only
requests or routes a review and does not make approval a merge gate.
The [dry-run — Readiness assessment](https://github.com/kurone-kito/idd-skill/blob/main/idd-template/ONBOARDING.md#dry-run--readiness-assessment)
report's `CODEOWNERS present` item checks only that a CODEOWNERS file
exists; it does not verify workflow-path coverage, producer binding, or
these required-review settings (preventive; no observed incident yet).

**Trusted-code checkout.** The checkout step pins `ref: main` (adjust
if your default branch differs) rather than the PR's own head, for
every trigger type including `workflow_dispatch`. The enforcement
script (`scripts/advisory-convergence.mjs`) and its config
(`.github/idd/config.json`) must run from the trusted branch, not a
PR's own copy — otherwise a PR could edit the verdict logic itself to
force `ready: true` and defeat the whole required-check gate. The
verdict still correctly evaluates the intended PR: `--pr <number>`
drives every live GitHub API call the script makes (reviews, threads,
comments), independent of what is checked out locally, so pinning the
checkout to the trusted branch costs nothing functionally.

Two automatic trigger types keep the required verdict current:
`pull_request` for the normal push case, and `pull_request_target` as
its tamper-resistant counterpart (see Trusted-code checkout above --
a same-repository PR cannot edit `pull_request_target`'s own copy of
this workflow file, unlike `pull_request`). Review-thread comments are
**not** on that required job, and neither is Copilot's review
submission (`pull_request_review`) — both instead refresh the
existing HEAD-associated required run from the non-required companion
`idd-advisory-convergence-comment.yml` workflow: an IDD-originated
comment (a disposition prefix, the reply-identity stamp, or an
operational marker the check already honors) calls
`rerun-advisory-convergence --apply`, while a review submission calls
`rerun-advisory-convergence --refresh-latest --apply` instead — a
review needs a fresh evaluation even if the gate is already green or
its rerun-once budget is already spent, which the plain `--apply`
path does not provide. Neither call reports `ready` itself. Ordinary
human prose (`LGTM`) does not create or
cancel the required check.

A thread being resolved or unresolved via the "Resolve conversation"
button (`pull_request_review_thread`) is a real GitHub webhook event,
but it is **not** one of the events GitHub Actions supports as a
workflow `on:` trigger — including it makes the whole workflow file
fail GitHub's schema validation (confirmed both against GitHub's own
trigger-events reference and empirically). Residual gap: if a
Copilot-authored thread is resolved or reopened with no accompanying
comment, push, or fresh Copilot review, this check keeps reporting
its last computed verdict until a push, a Copilot review, an
IDD-originated comment refresh, or a maintainer `workflow_dispatch`
fires.

**Human-reply retrigger.** A casual human reply used to start the
required `idd-advisory-convergence` job, fail or cancel the SHA
verdict, and look like "the reply got linted." That path is now the
companion comment workflow above, and only IDD-originated comments
refresh the required run. This is `idd-advisory-convergence`, not
`lint.yml`.
The shipped hybrid contract is present-tense: IDD replies carry
`<!-- {markerPrefix}-review-reply -->` after the visible
disposition body (this is **not** the E1 `review-watermark`);
unmarked human replies on human threads are presence-only and do
not let the owning session post bare prose on its own items;
Copilot threads still need an IDD disposition;
`reviewPolicy: human-required` / `no-advisory` makes Copilot clauses
`not_applicable`. See
[Hybrid review-reply identity](../idd-review-policy-profiles.md#hybrid-review-reply-identity-shipped).
Repositories that want human-led or gradual IDD adoption should
leave the check unregistered until they intend the Copilot-advisory
loop.

**Register it as a required status check.** Hosting the workflow alone
does not block merge — a maintainer must separately register
`idd-advisory-convergence` (the job id, which is also the
`ciGate.externalCheckWaivers` selector for this check — see
[policy constants](../policy-constants.md#advisory-review-defaults))
as a **required** status check in the repository's branch-protection
Ruleset, the same way other CI jobs are registered there. This is a
maintainer GitHub-settings action taken outside of IDD automation, not
something an agent applies on its own.

**Avoid the classic-API pinning trap.** This applies specifically to
GitHub's **classic** branch-protection API (`.../protection/...`) — a
separate mechanism from the Ruleset just described above; this section
does not claim Rulesets are unaffected, only that the classic API is
the one field-verified here. That classic API silently rewrites a
plain string-array `contexts` field into `app_id`-pinned `checks`
entries: a `PUT .../protection`
call configuring `contexts` comes back with a `checks` array carrying
an `app_id` (for example, `15368` for `github-actions[bot]` on
github.com — an implementation detail of that specific integration, not
a portable constant; a GHES instance or a future GitHub change can
differ). A pinned entry is exactly what the fail-closed "Source-pinned
required-check trust" default (`ciGate.trustSourcePinnedRequiredChecks`
— see the row in [Customizing IDD](../customization.md)) downgrades
to unresolved even when green, so an operator who registers this or any
other required check the straightforward way walks into that gate on
the very first PR, for a reason nothing in the classic API response
explains (observed 2026-08-11 onboarding a companion repository;
[kurone-kito/idd-skill#1925](https://github.com/kurone-kito/idd-skill/issues/1925)).

Use the narrower `PATCH .../required_status_checks` endpoint instead,
with an explicit `checks` array and `app_id: -1` (any producer) rather
than a plain `contexts` array. Substitute `{base-branch}` below with
the literal protected branch name (for example `main`) — do not use
`gh api`'s own `{branch}` magic placeholder, which silently resolves to
whatever branch is currently checked out locally, not the protected
branch (preventive; no observed incident yet — verified against
`gh api --help`'s own placeholder documentation, not a field-observed
adopter incident):

```sh
gh api --method PATCH \
  repos/{owner}/{repo}/branches/{base-branch}/protection/required_status_checks \
  --input - <<'JSON'
{"checks": [{"context": "idd-advisory-convergence", "app_id": -1}]}
JSON
```

**`PATCH` replaces the whole `checks` list — it does not merge into
it** (preventive; no observed incident yet). If the branch already
requires other checks (lint, build, tests, and so on), first fetch the
current array:

```sh
gh api \
  repos/{owner}/{repo}/branches/{base-branch}/protection/required_status_checks \
  --jq '.checks'
```

Then include every existing entry alongside the new one in the
`checks` array above — **except** an existing entry whose `context`
already matches the check being added (for example, an existing
pinned `idd-advisory-convergence` entry): replace that matching entry
rather than appending a second one, since a duplicate context name
where any entry is still pinned keeps the whole context classified as
source-pinned regardless of the other, unpinned entry (preventive; no
observed incident yet). Copy-pasting
the snippet unqualified on a branch that already has required checks
silently drops them, weakening the merge gate to only the newly added
check.

`app_id: -1` also trades away GitHub's producer-identity enforcement
for the check it names (preventive; no observed incident yet). It also
allows any credential with `statuses: write` or `checks: write` to publish
that literal name. Use it only when the adopter explicitly accepts that
trust scope and separately protects all workflow paths that could produce
the name; it is not a blanket recommendation for every required check.
A producer pin does not identify an individual workflow; keep broad
workflow ownership unless the integration is dedicated exclusively to
this check.
Keep a specific `app_id` pin
on any check where verifying the producer matters, and opt in to
`ciGate.trustSourcePinnedRequiredChecks: true` (see the row in
[Customizing IDD](../customization.md)) instead, once the operator
has verified out-of-band that the pinned integration is the sole
producer.

**Waiver-after-deadline escape path.** `--assert` exits non-zero for
any not-ready verdict, including the ordinary case where the primary
advisory bot has not yet reviewed the current PR HEAD — GitHub Actions
has no separate non-failing "pending" check state, so the check simply
**shows as failing** until it converges (by design: it must stay red
until Copilot reviews the HEAD). After `advisoryWait.convergenceDeadline`
(default 24h) elapses from the HEAD commit's own timestamp, the only
way to turn the check green without a fresh review is a valid
maintainer external-check waiver for that HEAD under the selector
`idd-advisory-convergence` — see
[External-Check Waiver Defaults](../policy-constants.md#external-check-waiver-defaults)
and the waiver policy surface in
[Customizing IDD](../customization.md#policy-constants).
That path only exists once `ciGate.externalCheckWaivers.mode` is
`maintainer-authorized` **and** `idd-advisory-convergence` is itself
registered under `ciGate.externalChecks.waivable`; enabling waiver mode
for some other external check never silently makes this one waivable
too. **Posting the waiver comment alone does not always turn the
check green**: a PR comment is not one of the **required**
`idd-advisory-convergence` workflow's own trigger events, and a
completed run's conclusion never changes on its own. A repository that
also hosts the companion `idd-advisory-convergence-comment.yml`
workflow (with its `issue_comment` trigger — as this repository does;
the workflow itself was added via kurone-kito/setup.windows#124,
reconciled to add that trigger in kurone-kito/setup.windows#163) gets
the check refreshed automatically instead: a posted
maintainer-authorized waiver comment classifies as an IDD-originated
operational marker and reruns the existing HEAD-associated required
run through that companion, the same as any other IDD-originated
regular PR comment — or, for a same-repository PR, a review-thread
reply (the companion skips that trigger for fork-originated PRs). If
that automatic rerun does not land, a maintainer must trigger a new
run manually instead —
push, a fresh review (same-repository PRs only — the companion also
skips `pull_request_review` for fork-originated PRs), the Actions UI
"Re-run jobs" button on the _existing_ PR-linked run for the
**current HEAD SHA**, or
`gh run rerun <run-id>` on that same run — for the required check to
actually reflect it.
`workflow_dispatch` does **not** reliably do this: a dispatched run has
no `pull_request` context of its own, so GitHub associates it with the
dispatch ref rather than the PR's HEAD SHA, and the resulting run's
conclusion can be invisible to that PR's required-check rollup. See
[kurone-kito/idd-skill's own dogfooded copy of `.github/workflows/idd-advisory-convergence.yml`](https://github.com/kurone-kito/idd-skill/blob/main/.github/workflows/idd-advisory-convergence.yml)'s
header comment for the full finding — this deliberately links the
upstream source repository's copy, not your own vendored workflow
file: the fuller investigation prose lives only in that dogfooded
original, and the portable stub this template mirrors at
`.github/workflows/idd-advisory-convergence.yml` in your own
repository does not carry it.

**The self-waiver provenance artifact is unavailable on GHES.** The
`idd-advisory-convergence-self-waiver` job's "Upload the posted
marker's provenance artifact" step pins `actions/upload-artifact` v4+
(currently `v7.0.1`), which needs the newer Artifacts service backend
that GitHub Enterprise Server does not support; GHES instead needs the
`v3.2.2` (or `v3.2.2-node20`) release, itself deprecated on
github.com. Because the
self-waiver mechanism fails closed, this never lets a forged waiver
through on GHES — the upload step simply fails, or produces no
artifact — but it does mean the self-referential-bootstrap-auto
mechanism can never actually complete on a GHES-hosted adopter,
degrading every genuine attempt to "no auto-waiver" and leaving only
the maintainer-authorized waiver path for every such PR (found by a
Codex review of kurone-kito/idd-skill#2914 during the
kurone-kito/idd-skill#2912 fix cycle, 2026-09-11). See
kurone-kito/idd-skill#2918 for the full tradeoff discussion and the
rationale for keeping the pinned version rather than adding a
runner-detection branch.

## Optional — mark the vendored helper bundle `linguist-vendored`

This step applies **only to the `vendored-node` profile** (the only
profile that copies helper files into your repository). The vendored
bundle is third-party code, so marking it `linguist-vendored` drops it
from your repository's language statistics and de-prioritizes it in code
search — useful when your own code is mostly docs or another language and
you do not want the copied `.mjs`/schema files to dominate the language
bar. (This is the adopter-side counterpart of the source repository's
`linguist-generated` artifacts; the semantics differ deliberately:
generated = first-party build output, vendored = copied third-party code.)

The helper-runtime manifest emits the exact lines from the same
`managedFiles` import-graph it uses to vend the bundle, so the attribute
list never drifts from what you copied. Append them to your
`.gitattributes`:

```sh
node scripts/helper-runtime-manifest.mjs --profile vendored-node \
  | node -e 'const m=JSON.parse(require("node:fs").readFileSync(0,"utf8"));process.stdout.write(m.profiles["vendored-node"].recommendedGitattributes.join("\n")+"\n")' \
  >> .gitattributes
```

Other profiles vend no files and emit no recommendation, so they need
nothing here.
