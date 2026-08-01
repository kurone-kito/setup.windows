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
