# Onboarding Reference — Policy Decisions

Use this reference alongside `idd-template/ONBOARDING.md` when you need
the detailed policy-decision guidance that the thin onboarding entry
point now links to.

This page is the detailed companion for:

- Step 1B — confirm operator policy decisions
- Step 2 — re-check the selected policy before importing files
- Step 3 — record the selected policy in repository documentation

## Decisions that require explicit operator confirmation

These choices cannot be safely inferred from repository structure alone.
Keep the operator-confirmation boundary explicit.

### Merge policy

Choose exactly one merge policy before unattended runs begin:

- `fully_autonomous_merge` (distributed default): one trusted agent
  session may execute merge phase F3 after the normal claim, freshness,
  CI, advisory, and review gates pass
- `human_merge`: worker sessions stop at the merge-policy handoff gate
  and a human maintainer performs the merge
- `separate_merge_agent`: worker sessions stop at the default handoff
  gate and a separately authorized merge-capable actor performs the
  final merge path

Use `fully_autonomous_merge` as the proposed default unless the
operator explicitly opts out. For public or OSS repositories, recommend
`human_merge` before granting unattended credentials. For repositories
where lightweight-tier ("weak-model") sessions run the loop unattended,
recommend `human_merge` or `separate_merge_agent` instead of
`fully_autonomous_merge`, since that tier should not run the
autonomous merge phases. See
[Model capability expectations](../idd-workflow.md#model-capability-expectations).

### Credential scope

Review `docs/permissions.md` with the operator before granting
unattended or merge-capable credentials. Choose the narrowest access
profile that can complete the intended phase.

Keep these boundaries explicit:

- `fully_autonomous_merge`: one trusted agent session may receive the
  merge-capable credential set needed to continue through F3
- `human_merge`: worker sessions must not receive merge-capable
  credentials because merge remains a human step
- `separate_merge_agent`: ordinary worker sessions stop at the handoff
  gate, while only the separately authorized merge-capable actor
  receives the stronger credentials needed for the final path

Record the selected credential boundary next to the merge policy so
future sessions can tell whether worker credentials and merge-capable
credentials are intentionally different.

### PR review policy profile

Choose whether the repository keeps the distributed GitHub Copilot
advisory review profile or applies a non-default review profile:

- `copilot-advisory` (distributed default)
- `no-advisory`
- another profile documented in `docs/idd-review-policy-profiles.md`

For non-default profiles, use the matching `profiles/<profile>/README.md`
artifact after import and update every listed phase file before treating
onboarding as complete.

### Review-thread resolution policy

Choose exactly one review-thread resolution profile:

- `fast-agent-resolve` (distributed default)
- `hybrid-reviewer-ack`
- `strict-reviewer-resolve`

If the repository chooses a non-default profile, update the review
snapshot, triage, review-fix, pre-merge, and merge phase files named in
`docs/idd-review-policy-profiles.md`.

### Critique-loop profile

Confirm whether the repository keeps the distributed critique-loop
defaults from `docs/policy-constants.md` or documents a local override.
At minimum, record whether the repository uses the shipped guardrails or
intentionally customizes the critique-loop behavior before unattended
execution begins.

### CI wait policy

Confirm whether the repository keeps the distributed CI wait defaults or
records a local override. The default profile is:

- `ciWait.runningTimeout`: `PT30M` (30 min)
- `ciWait.generationTimeout`: `PT10M` (10 min)
- `ciWait.rerunPolicy`: `rerun-once`

If the repository customizes any of these values, keep
`.github/idd/config.json`,
`.github/instructions/idd-ci.instructions.md`,
`.github/instructions/idd-review-fix.instructions.md`, and
`.github/instructions/idd-pre-merge.instructions.md` aligned in the
same change.

### Issue-author approval gate

Choose whether the repository keeps the distributed secure-by-default
issue-author approval gate or records a current config opt-out:

Onboarding should ask this question explicitly before unattended
execution is allowed to start.

- `enabled-by-default` (distributed default): unattended work requires a
  self-authorizing issue author or a fresh explicit maintainer approval
  signal before claim
- config opt-out: set `skipIssueAuthorApprovalGate: true` in
  `.github/idd/config.json` and record the same decision in
  human-readable policy notes

When the gate stays enabled:

- explicit-target execution stops before claim when approval is missing
- discovery keeps underprivileged unapproved issues in an
  approval-needed fallback bucket instead of treating them as
  ready-to-start
- GitHub organization `MEMBER` association alone is not enough to count
  as approval authority

### `maintainer-approval-actors` policy

Choose exactly one approval-actor policy for repositories that keep the
issue-author approval gate enabled:

- `owners-and-maintainers-only` (recommended default): only owners and
  collaborators with Maintain or Admin permission count as approval
  actors
- `all-write-permission-actors`: collaborators with Write permission may
  also approve issue start

Keep this human-readable policy choice distinct from the machine-readable
`maintainerApprovalActorPolicy` config field. When
`.github/idd/config.json` is present, record the same enum there so the
distributed discover/claim runtime uses the documented approval model.
The optional `maintainerApprovalActors` config field is a
schema-supported explicit GitHub login allowlist, but the distributed
runtime does not enforce that explicit allowlist yet.

### Issue-authoring companion

Confirm whether the operator wants the optional issue-authoring skill and,
when installed, record the one native destination selected for the target
runtime:

- `installed`: copy the canonical source bundle at
  `skills/issue-authoring/` into one selected native skill directory, such as
  `.agents/skills/issue-authoring/` for Codex CLI or OpenCode,
  `.claude/skills/issue-authoring/` for Claude Code, or
  `.opencode/skills/issue-authoring/` for OpenCode. Record
  the selected destination alongside the `installed` status.
- `not installed`: continue without the companion

The canonical source path and the installed destination are separate values:
the destination is not a second source-of-truth copy. Do not add the same
skill ID to multiple runtime roots by default (preventive; no observed incident
yet); a mixed-runtime target should
use one native copy plus an explicit manual route unless the operator
deliberately accepts identical duplicates. The companion helps draft
IDD-ready issues and roadmaps. By default, it publishes each drafted
`ready` body directly under the configured authoring label once it
passes the mechanical pre-publish gate and the critique pass — no
separate publish approval step — unless the current request explicitly
asked for a preview instead. Releasing that authoring hold is the
single boundary within the companion's own workflow that still needs an
explicit request: publishing under the hold alone does not start the
main execution loop, because Discover treats an issue carrying the
authoring label as not startable while the hold remains. The
issue-author approval gate described above still applies independently
once the hold is released.

### Helper runtime profile

Auto-propose a helper runtime profile only when repository evidence
shows a supported package-manager path or another real Node.js helper
path, but require explicit operator confirmation before recording
anything other than `instructions-only`. Choose the runtime profile in
this order:

1. `package-manager` when the target repository declares supported
   `packageManager` metadata or has exactly one supported pnpm, npm, or
   yarn lockfile
2. `vendored-node` when Node.js is available and helper files may be
   copied into the repository, but package-manager evidence is missing
   or ambiguous
3. `ephemeral-npx` only when vendoring is not preferred and a
   resolvable one-shot helper command already exists
4. `instructions-only` fallback when none of the above applies

Repositories without Node.js remain fully supported through
`instructions-only`.

Run this manifest helper from the target repository root when helper
support is enabled:

```sh
npx --yes --package <reviewed-helper-spec> \
  idd-helper-bundle-manifest --profile <selected-profile>
```

If `package-manager` auto-detection does not resolve npm, pnpm, or yarn,
pass `--package-manager <npm|pnpm|yarn>` explicitly. Pass
`--package-spec <pinned-spec>` when the repository wants the helper to
emit a reviewed tag, commit, tarball, or internal mirror URL. Treat
`refs/heads/main` as a manual opt-in when the repository explicitly
wants a mutable helper source instead of a reviewed pinned spec.

**pnpm `allowBuilds` requirement for a git-hosted pinned spec.** When a
`package-manager` repository using pnpm pins the `devDependencies` entry
to a git-hosted spec (for example
`"@kurone-kito/idd-skill": "github:kurone-kito/idd-skill#v0.4.0"`), a
clean `pnpm install` fails:

```text
[ERR_PNPM_GIT_DEP_PREPARE_NOT_ALLOWED] Failed to prepare git-hosted
package fetched from "https://codeload.github.com/kurone-kito/idd-skill/
tar.gz/<sha>": The git-hosted package "@kurone-kito/idd-skill@0.4.0"
needs to execute build scripts but is not in the "allowBuilds"
allowlist.
```

pnpm treats a git-hosted dependency's build scripts as untrusted by
default and refuses to run them until the repository explicitly allows
it. Add an `allowBuilds` entry for the helper package to
`pnpm-workspace.yaml` to unblock the install:

```yaml
allowBuilds:
  "@kurone-kito/idd-skill@https://codeload.github.com/kurone-kito/idd-skill/tar.gz/<sha>": true
```

The allowlist key form differs for a git-hosted dependency. A
**registry** dependency only needs the bare package name (for example
`"@biomejs/biome": true`), but a **git-hosted** dependency needs the
full `<name>@<resolved-tarball-url>` key — the bare package name alone
silently does not match and reproduces the same
`ERR_PNPM_GIT_DEP_PREPARE_NOT_ALLOWED` error. Copy the exact
`fetched from "..."` URL from pnpm's own error output above rather than
guessing the resolved-tarball-URL shape; it is not the same as the
`github:owner/repo#ref` shorthand written in `devDependencies`, and it
changes per resolved commit.

### IDD label names

Confirm whether the repository keeps the three distributed IDD label
names or maps them onto an existing local label taxonomy:

- `labels.roadmapLabelName` (distributed default `roadmap`)
- `labels.blockedByHumanLabelName` (distributed default
  `status:blocked-by-human`)
- `labels.needsDecisionLabelName` (distributed default
  `status:needs-decision`)

**Auto-labeler risk.** If the repository runs a semantic issue
auto-labeler — a bot such as CodeRabbit's issue enrichment that infers
labels from issue content instead of applying only labels a human or
workflow explicitly requests — that labeler can apply any of these
three configured label names to an ordinary issue on its own judgment,
regardless of which label names the repository chose. The failure is
silent: nothing errors, and the issue simply stops being an execution
candidate (a spurious `labels.roadmapLabelName` match) or gets parked
behind a hold (a spurious `labels.blockedByHumanLabelName` or
`labels.needsDecisionLabelName` match — both are Discover's
roadmap-level blocker gates) with no visible cause. This has been
observed in the field: in one fresh template import, `coderabbitai[bot]`
applied the roadmap label to all eight children of one authored roadmap
batch — an 8/8 hit rate, not an occasional misfire — and separately
applied the blocked-by-human label to an issue that had been authored
with the needs-decision label, so the risk is not limited to one label
name.

**Omitting a label from the labeler's instructions is not a
restriction.** A semantic labeler's own configuration (for example, a
`labeling_instructions` list scoped to content labels) supplies
per-label guidance for the labels the product is told about — it does
not narrow which labels the product's own auto-labeling heuristic may
apply on its own. Leaving the three IDD label names out of that
configuration does not stop the labeler from applying them; do not
recommend or rely on that omission as a mitigation.

**Ask this question during onboarding**: does anything in this
repository, or an installed GitHub App, auto-apply labels to issues
based on content? If yes, and the repository keeps the distributed IDD
label names (or any other label such an auto-labeler could plausibly
infer), adopt the guard recipe in
[Customizing IDD — Reserved-label guard recipe](../customization.md#reserved-label-guard-recipe)
before relying on unattended discovery or hold semantics.

### Bootstrap execution mode

Confirm whether the initial IDD import itself runs through the
distributed direct-import default or through the optional
issue-mediated alternate:

- `direct-import` (distributed default, "theirs-flow"): Steps 2, 4, 5,
  and 6 import the template with a direct, unreviewed commit, then hand
  off to the normal claim -> work -> PR -> CI -> merge loop for every
  subsequent change.
- `issue-mediated`: routes that same import through a reviewable
  issue -> branch -> PR -> merge cycle instead, using the placeholder
  values and Step 1B policy decisions already confirmed earlier in the
  hearing. Choose this when the operator wants every repository
  mutation — including the very first one — to have a reviewable
  record, or simply prefers not to grant an agent a direct-commit path.

If the operator does not state a preference, propose `direct-import`
and only switch modes on explicit confirmation. See
[Onboarding Reference — Issue-Mediated
Bootstrap](issue-mediated-bootstrap.md) for the full procedure and
prerequisites.

## Related default policies to confirm

The onboarding entry point should also confirm whether the repository
keeps the distributed claim-timing defaults from `docs/policy-constants.md`:

- `claim-stale-age`: `24 h`
- `claim-heartbeat-interval`: `12 h`

Record whether the repository keeps these defaults before unattended
workers begin running.

It should also confirm whether the repository keeps the distributed CI
wait defaults:

- `ciWait.runningTimeout`: `PT30M` (30 min)
- `ciWait.generationTimeout`: `PT10M` (10 min)
- `ciWait.rerunPolicy`: `rerun-once`

Record whether the repository keeps these defaults before unattended
workers begin running.

It should also confirm whether the repository's GitHub ruleset leaves
"Require branches to be up to date before merging"
(`required_status_checks.strict_required_status_checks_policy`)
disabled:

- Recommended: disabled. Measured evidence shows enabling it can force
  a `main`-sync merge on every merely-`BEHIND` PR and multiplies Copilot
  advisory-review rounds without adding review value — a before/after
  commit sample measured the sync-merge share fall from ~27% to ~3.7%
  once this repository disabled it
  ([kurone-kito/idd-skill#1817](https://github.com/kurone-kito/idd-skill/issues/1817)).
  This benefit only holds when the automation token can read the
  ruleset — an unreadable ruleset read still fails closed to forcing
  the sync path regardless of the live setting.
- Trade-off: disabling it means the final pre-merge CI run may not
  reflect the very latest `main`, which IDD's own conflict-triggered
  `main`-sync merge (E11) and F1/F2 freshness checks still catch when
  it matters for correctness.

Record whether the repository keeps this setting disabled before
unattended workers begin running.

It should also confirm that any required status check registered
through GitHub's classic branch-protection API uses the explicit
`checks` array rather than a plain string-array `contexts` field:

- Recommended: register required checks with an explicit `checks`
  array. Use `app_id: -1` (any producer) for `idd-advisory-convergence`
  specifically — only the adopter's own hosted workflow ever produces a
  check with that exact name — but not as a blanket choice for every
  required check: keep a specific `app_id` pin on any check where
  verifying the producer matters. GitHub's classic API silently
  rewrites a `contexts` `PUT` into `app_id`-pinned `checks` entries,
  and a pinned entry is exactly what the fail-closed "Source-pinned
  required-check trust" default
  (`ciGate.trustSourcePinnedRequiredChecks` — see the row in
  [Customizing IDD](../customization.md)) downgrades to unresolved even
  when green, so an operator who configures branch protection the
  straightforward way walks into that gate on the very first PR
  (observed 2026-08-11 onboarding a companion repository;
  [kurone-kito/idd-skill#1925](https://github.com/kurone-kito/idd-skill/issues/1925)).
  See [ONBOARDING.md's required-status-check registration
  step](https://github.com/kurone-kito/idd-skill/blob/main/idd-template/ONBOARDING.md#optional--host-idd-advisory-convergence-as-a-required-check-ci-workflow)
  for the working `PATCH` snippet, including the merge caveat (`PATCH`
  replaces the whole `checks` list) and the producer-pinning trade-off
  of `app_id: -1`.

Record whether the repository's required-check registration avoids the
string-array `contexts` pinning trap before unattended workers begin
running.

## Recording the selected policies

Create a local policy section in repository documentation (for example
in `.github/copilot-instructions.md`, `AGENTS.md`, or a dedicated
`docs/idd-policy.md`) and make it easy for future IDD sessions to find.

Use a structure like this:

```markdown
## IDD Policy Configuration

This repository uses the following IDD policies:

### Merge Policy

**Policy**: `{fully_autonomous_merge | human_merge | separate_merge_agent}`

### PR Review Policy

**Profile**: `{copilot-advisory | no-advisory | other}`

### Review-Thread Resolution Policy

**Policy**: `{fast-agent-resolve | hybrid-reviewer-ack | strict-reviewer-resolve}`

### Critique-Loop Profile

**Profile**: `{distributed defaults | repository override}`

### Claim Timing

- **claim-stale-age**: 24 h (or repository override)
- **claim-heartbeat-interval**: 12 h (or repository override)

### CI Wait Policy

- **running timeout**: `PT30M` / 30 min (or repository override)
- **generation timeout**: `PT10M` / 10 min (or repository override)
- **rerun policy**: `{rerun-once | hold}`

### Up-to-Date-Head Ruleset

**Policy**: `{disabled (recommended) | enabled}`

### Required-Check Registration

- **Classic-API `contexts` pinning trap avoided**:
  `{yes | no / not applicable}`
- **Producer-identity choice**: `{app_id: -1 (any producer) |
  intentionally pinned}`
- **If intentionally pinned, `ciGate.trustSourcePinnedRequiredChecks`
  opt-in recorded**: `{yes | no / not applicable}`

### Credential Scope

**Worker credentials**: `{least-privilege worker scope}`

**Merge-capable credentials**: `{same as worker | separate stronger scope | not granted}`

### Helper Runtime Profile

**Profile**: `{instructions-only | package-manager | vendored-node | ephemeral-npx}`

### Issue-Author Approval Gate

- **Gate posture**: `{enabled-by-default | opted-out}`
- **Opt-out state**:
  `{gate remains default-enabled | skipIssueAuthorApprovalGate: true opt-out}`
- **`maintainer-approval-actors` policy**:
  `{owners-and-maintainers-only | all-write-permission-actors}`
- **Approval signals**:
  `{configured ready label | standalone IDD ready comment | both}`
- **`approvalSignals.readyLabelName`**:
  `{idd:ready | custom ready label}`
- **`approvalSignals.labelFreshnessMode`**:
  `{presence-only | event-freshness}`
- **Missing-approval behavior**:
  `{explicit-target stop-before-claim + discovery approval-needed fallback bucket}`

### Issue-Authoring Companion

**Status**: `{installed | not installed}`

**Native destination**: `{.agents/skills/issue-authoring/ | .claude/skills/issue-authoring/ | .opencode/skills/issue-authoring/ | not applicable}`

- **`issueAuthoring.maxClarificationRounds`**:
  `{3 | custom finite bound}`

### Bootstrap Execution Mode

**Mode**: `{direct-import | issue-mediated}`
```

When the repository uses a non-default merge, review, or thread policy,
describe the local effect in prose near the selected value so future
agents do not need to infer what changed.

## Machine-readable policy file

`.github/idd/config.json` is the machine-readable record of the same
policy decisions. When present and valid, its `commands` object
overrides the command table values in
`idd-overview-core.instructions.md`. The non-command policy fields are a
machine-readable mirror that should stay aligned with the owning
instruction files and human-readable policy notes, including
`claimTiming.*` and `ciWait.*` when the repository records those
settings explicitly.

Keep these rules in mind:

- the JSON file is optional; the Markdown instructions remain the
  fallback when the JSON file is absent or invalid
- keep the human-readable policy section and `.github/idd/config.json`
  aligned in the same change
- treat non-command policy fields as synchronized metadata, not as a
  substitute for updating the instruction files that own phase behavior
- if the repository chooses a `maintainer-approval-actors` policy,
  record the same enum in `maintainerApprovalActorPolicy` when
  `.github/idd/config.json` is present
- if the repository also chooses an explicit `maintainerApprovalActors`
  list, record it as an optional array of GitHub login strings and keep
  it aligned with the human-readable issue-author approval notes
- treat `maintainerApprovalActors` as distinct from the
  `maintainer-approval-actors` policy choice: the config field is an
  explicit allowlist, while the policy choice records the broader
  approval model that the distributed runtime already enforces
- use `skipIssueAuthorApprovalGate: true` when the repository
  intentionally opts out; omitted or `false` keeps the gate enabled
- replace `kurone-kito` in `trustedMarkerActors` with a
  single JSON-escaped GitHub login string first, then add any extra
  quoted array entries manually for additional trusted marker actors
- keep command strings JSON-escaped instead of pasting fragile raw shell
- keep `helperRuntime.profile` aligned with the human-readable helper
  runtime section when helper support is enabled
- set `helperRuntime.packageSpec` only when the repository has pinned a
  reviewed tarball, mirror URL, or commit archive for its `ephemeral-npx`
  helper install; omit it to keep the mutable default archive URL

The file validates against the canonical schema at:

<https://kurone-kito.github.io/idd-skill/schemas/policy.schema.json>

To validate locally from a checkout of `idd-skill`, run:

```sh
node scripts/validate-schemas.mjs
```
