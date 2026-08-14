# IDD Policy Record

This page records the IDD (Issue-Driven Development) policy decisions
made when this repository adopted the workflow (roadmap #55). It is the
human-readable counterpart to the machine-readable
[`.github/idd/config.json`](../.github/idd/config.json); keep both in
sync when either changes.

## IDD Policy Configuration

This repository uses the following IDD policies:

### Merge Policy

**Policy**: `fully_autonomous_merge`

### PR Review Policy

**Profile**: `copilot-advisory`

Advisory bots: `copilot-pull-request-reviewer[bot]`,
`coderabbitai[bot]`.

### Review-Thread Resolution Policy

**Policy**: `fast-agent-resolve`

### Critique-Loop Profile

**Profile**: distributed defaults (no `critiqueLoopProfile` override
recorded in `.github/idd/config.json`)

### Claim Timing

- **claim-stale-age**: `PT12H` (repository override; distributed
  default is `PT24H`)
- **claim-heartbeat-interval**: `PT6H` (repository override;
  distributed default is `PT12H`)

### CI Wait Policy

- **running timeout**: `PT10M` (repository override; distributed
  default is `PT30M`)
- **generation timeout**: `PT10M` (matches the distributed default)
- **rerun policy**: `rerun-once`

### CI Gate (External Checks)

- **Required-check gate**: `.github/workflows/idd-advisory-convergence.yml`
  (job id `idd-advisory-convergence`) asserts that the primary advisory
  bot's review has converged on the current PR HEAD, turning the F2
  advisory/disposition sub-gate into a non-bypassable GitHub status
  check. Branch-protection registration of this check as a required
  status check is recorded in
  [CI Gate (Required Status Checks)](#ci-gate-required-status-checks)
  below (#61).
- **`ciGate.externalChecks.waivable`**: `[{ "selector":
  "idd-advisory-convergence" }]` — this repository's only waivable
  external check.
- **`ciGate.externalCheckWaivers.mode`**: `maintainer-authorized`
  (repository override; distributed default is `disabled`). All other
  `externalCheckWaivers` fields (`authorityPolicy`, `maxValidity`) are
  not overridden and use the bundle's distributed defaults
  (`owners-and-maintainers-only`, `PT24H`).
- **Waiver path**: when installed, prefer the helper facade over
  hand-writing marker comments:

  ```sh
  npx --yes --package https://codeload.github.com/kurone-kito/idd-skill/tar.gz/4e8c7043edcb00dd8447dee83e7a17e5b2604d5d \
    idd-external-check-waiver --pr <number> \
    --check idd-advisory-convergence \
    --reason "<short reason>" \
    --expires-in PT2H \
    --apply --yes
  ```

  **Posting a waiver comment alone does not turn the check green.** A PR
  comment is not one of `idd-advisory-convergence.yml`'s trigger events,
  and a completed run's conclusion never changes on its own — after
  posting a valid waiver, re-run the check via
  `gh run rerun <run-id>` on the existing `pull_request`-family run for
  the current HEAD SHA (found via `gh run list
  --workflow=idd-advisory-convergence.yml --json
  databaseId,headSha,event,url`). **Prefer this over `workflow_dispatch`**:
  a manually dispatched run is not reliably associated with the PR's own
  HEAD SHA / required-check rollup (GitHub can attribute it to the
  default branch instead), so even a successful dispatched run may not
  actually clear the check. If no `pull_request`-family run exists yet
  for this HEAD, trigger one first (a new push, or re-opening the PR)
  rather than falling back to `workflow_dispatch`.
- **Post-merge cleanup**: `.github/workflows/post-merge-cleanup.yml`
  runs F4 cleanup (`idd-audit-pr-cleanup --apply --skip-claim-check`) as
  a server-side fallback after a PR merges, in case the merging session
  did not reach F4 itself. It cannot run for the PR that first
  introduces it (GitHub reads `pull_request_target` workflow files from
  the base branch) — that PR's own F4 cleanup goes through the normal
  IDD flow instead.

### CI Gate (Required Status Checks)

Resolves #61. `master`'s `main` ruleset (`~DEFAULT_BRANCH`) now carries a
`required_status_checks` rule, registered via the GitHub Rulesets API
(this repository uses rulesets rather than classic branch protection,
so the classic `GET .../branches/{branch}/protection` endpoint
correctly 404s — that is not a misconfiguration).

- **Required contexts**: `idd-advisory-convergence`, `lint`,
  `powershell-analyzer`, `pester`, `configuration-drift`. The first
  turns the F2 advisory/disposition sub-gate into a real GitHub-enforced
  block (this issue's purpose); `lint`, `powershell-analyzer`, and
  `pester` are the existing `Linting workflow` jobs that mirror
  **pre-push-validate** (Markdown/cspell lint, PSScriptAnalyzer,
  Pester); `configuration-drift` goes further — it also regenerates the
  DSC-derived artifacts and checks for a zero diff, a check
  **pre-push-validate** does not run locally. Registering all four
  closes the gap where a maintainer could merge past red CI through the
  merge button even though IDD's own F2 checklist already required them
  to be green.
- **Not registered**: `CodeRabbit`. Unlike `idd-advisory-convergence`
  and the four lint jobs, it is not itself an assertion of anything;
  it reports its own progress as a legacy commit status with context
  `CodeRabbit` (confirmed live: `state: success` even while its
  description reads `Review rate limited`). Registering it as a
  required check would therefore risk the opposite failure from a
  missing context — a rate-limited or otherwise-skipped review could
  still report `success` and satisfy the gate without having reviewed
  anything. The E1 activity-universe snapshot plus `review-watermark`
  delta remains the load-bearing safety net for CodeRabbit findings
  (see [Scope — Copilot-only settle/wait window](../.github/instructions/idd-advisory-wait.instructions.md#scope--copilot-only-settlewait-window)).
- **`strict_required_status_checks_policy`**: `false`. This repository
  runs several IDD issue branches concurrently; requiring every branch
  to be re-verified against the latest `master` before its checks count
  would force a rebase-and-rerun cascade on every unrelated merge. IDD's
  own F1 branch-currency check (`branch-conflict-state`) and F2/F3
  re-fetch-before-merge already cover staleness without that
  GitHub-enforced cascade.
- **Verification** (2026-08-14, live evidence): before this rule
  existed, PR #113 (issue #103) sat at `mergeStateStatus: UNSTABLE` with
  no enforced required checks. After registering the rule, #113 (all
  five contexts green, including a converged `idd-advisory-convergence`)
  flipped to `mergeStateStatus: CLEAN`, and concurrently PR #114 (issue
  #105), whose `idd-advisory-convergence` run had concluded `FAILURE`
  (not yet converged), showed `mergeStateStatus: BLOCKED` — confirming
  a PR whose advisory review has not converged is actually blocked from
  merging by the required check, not merely flagged as advisory.
- **`ciGate.trustEmptyProtectionReads`**: `true` (repository override;
  distributed default is `false`). This repository has no classic
  branch protection at all — only the `main`/`features` rulesets above
  — so `GET .../branches/master/protection` genuinely 404s. Per this
  repository's own [Credential Scope](#credential-scope) policy, no
  separate least-privilege worker identity exists: every IDD session in
  this repository (interactive or delegated) authenticates as the same
  account that registered the ruleset above. Read with `--include`
  under that exact identity: the ruleset read returns a raw `HTTP/2.0
  200 OK`, and the classic-protection read returns a raw `HTTP/2.0 404
  Not Found` (not a `403` reported as `404`) — confirmed
  2026-08-14. This is not a permission-scope artifact for *this*
  identity; a differently-scoped credential without `administration:
  read` (for example, a third-party review bot's own sandboxed
  credential, unrelated to any identity that actually runs
  `pre-merge-readiness` in this repository) could still see a `403` on
  the same endpoint, which is exactly the ambiguity
  `idd-ci.instructions.md`'s required-check-discovery step 4 is
  designed to fail closed on for an *unverified* identity — it does not
  apply once the specific identity in use has been read-verified, as
  here. That step otherwise treats every `404` on that endpoint as
  fail-closed regardless of what the ruleset read already found, which
  would have permanently blocked `pre-merge-readiness` even with the
  required-status-checks rule above fully satisfied. Opting in here is
  the documented escape hatch for exactly this verified case.

### Credential Scope

**Worker credentials**: same scope as any other IDD session running in
this repository — no separate least-privilege worker identity is
configured.

**Merge-capable credentials**: same as worker. `mergePolicy` is
`fully_autonomous_merge`, so no `separate_merge_agent` identity or
elevated merge-only credential set exists; any session holding a valid
claim may carry it through to merge.

### Helper Runtime Profile

**Profile**: `ephemeral-npx`

Helper scripts run via `npx` against the pinned upstream package spec
(see [Upstream pin](#upstream-pin) below) rather than being vendored
into this repository or installed as a project dependency:

```sh
npx --yes --package https://codeload.github.com/kurone-kito/idd-skill/tar.gz/4e8c7043edcb00dd8447dee83e7a17e5b2604d5d <idd-command>
```

### Issue-Author Approval Gate

- **Gate posture**: opted out
- **Opt-out state**: `skipIssueAuthorApprovalGate: true`
- **`maintainer-approval-actors` policy**: `owners-and-maintainers-only`
- **Approval signals**: not applicable — the gate itself is opted out,
  so no `approvalSignals.readyLabelName` /
  `approvalSignals.labelFreshnessMode` override is recorded
- **Missing-approval behavior**: not applicable for the same reason

### Issue-Authoring Companion

**Status**: `installed` at
[`.claude/skills/issue-authoring/`](../.claude/skills/issue-authoring/SKILL.md)
(copied from the pinned upstream commit's `skills/issue-authoring/`,
with bundle-internal maintenance-doc links relinked to upstream URLs —
see the in-file note in `SKILL.md`).

- **`issueAuthoring.maxClarificationRounds`**: no override recorded in
  `.github/idd/config.json`; the bundle's distributed default of `3`
  rounds applies

### IDD Label Names

Distribution defaults, no `labels.*` override recorded in
`.github/idd/config.json`:

- roadmap label: `roadmap`
- blocked-by-human label: `status:blocked-by-human`
- needs-decision label: `status:needs-decision`

## Worktree guard: local activation

`worktreeGuard.enabled: true` is set in
[`.github/idd/config.json`](../.github/idd/config.json), but
`core.hooksPath` is a per-clone Git config value and is **not**
committed to the repository. Run the following in every clone or
worktree that should enforce the guard (this is required again for
each newly created clone, worktree, or disposable environment):

```sh
git config core.hooksPath .githooks
chmod +x .githooks/pre-commit .githooks/pre-push
```

Without this step, `worktreeGuard.enabled: true` has no local effect:
`idd-doctor` reports the guard as enabled-but-inert (commit/push are
not actually blocked) until `core.hooksPath` is configured in that
clone.

## Upstream pin

Template files and helper scripts are pinned to:

```text
kurone-kito/idd-skill @ 4e8c7043edcb00dd8447dee83e7a17e5b2604d5d
```

When a future change bumps this pin, treat it as a **named-gap
import**, not a blind resync: reconcile only the specific files that
changed between the old and new pinned commit against this repository's
recorded policy values above (do not let an upstream default silently
overwrite an intentional local override such as the claim-timing or
CI-wait values), then re-run the onboarding verification checklist and
`idd-doctor` after reconciling, using the same pinned `npx` form shown
above:

```sh
npx --yes --package https://codeload.github.com/kurone-kito/idd-skill/tar.gz/<new-pinned-SHA> idd-onboard.mjs --verify
```

## Machine-readable policy file

`.github/idd/config.json` is the machine-readable record of the same
policy decisions above. When present and valid, its `commands` object
overrides the command table in
[`idd-overview-core.instructions.md`](../.github/instructions/idd-overview-core.instructions.md).
Keep this page and `.github/idd/config.json` aligned in the same
change whenever either is updated.
