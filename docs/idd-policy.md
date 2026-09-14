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
- **Comment-triggered rerun (non-required companion)**:
  `.github/workflows/idd-advisory-convergence-comment.yml` listens for
  `pull_request_review_comment`, `issue_comment`, and
  `pull_request_review` events. For the two comment-family triggers,
  only when the comment is classified IDD-originated (an E6/E13
  disposition reply, reply-identity stamp, a posted maintainer-
  authorized waiver comment, or other operational marker
  `scripts/review-comment-origin.mjs` already recognizes — ordinary
  human chatter like "LGTM" is not) does it rerun the existing
  `idd-advisory-convergence` required-check run for the PR's current
  HEAD SHA; a `pull_request_review` submission always reruns it
  unconditionally. `issue_comment` works for any PR, fork-originated or
  not: it always resolves to the default branch regardless of which
  issue or PR was commented on, so GitHub does not restrict its
  `GITHUB_TOKEN` to read-only the way it does for `pull_request`-family
  events. `pull_request_review_comment` and `pull_request_review` are
  for same-repository PRs only — a fork-originated PR falls back to the
  manual `gh run rerun` step below for those two, since GitHub does
  force a read-only `GITHUB_TOKEN` for them on fork PRs regardless of
  the workflow's own `permissions:`. The companion has a different job
  id and concurrency group from the required check itself, so it can
  never create or cancel that check-run directly (#2136,
  kurone-kito/setup.windows#124). This now also automates the
  waiver-comment rerun case: a maintainer-authorized waiver comment
  classifies as an operational marker, so posting one on a repository
  that hosts this companion no longer requires a separate manual
  `gh run rerun` step to take effect.
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
  npx --yes --package https://codeload.github.com/kurone-kito/idd-skill/tar.gz/1f90787ebf4021673ce6e5eb69741df331fd2037 \
    idd-external-check-waiver --pr <number> \
    --check idd-advisory-convergence \
    --reason "<short reason>" \
    --expires-in PT2H \
    --apply --yes
  ```

  **Posting a waiver comment no longer requires a separate manual rerun
  step on its own.** A PR comment is not one of
  `idd-advisory-convergence.yml`'s own trigger events, and a completed
  run's conclusion never changes on its own — but the repository also
  hosts the companion `idd-advisory-convergence-comment.yml` workflow
  (#163 reconciliation), which listens for `issue_comment` and, since a
  posted maintainer-authorized waiver comment classifies as an
  operational marker (IDD-originated), automatically reruns the
  existing `idd-advisory-convergence` run for the current HEAD SHA. If
  that automatic rerun does not land (e.g. the companion is disabled, or
  the fallback is faster), re-run the check manually instead via
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
  would force a rebase-and-rerun cascade on every unrelated merge.
  This is a deliberate tradeoff, not a fully-covered gap: IDD's F1
  branch-currency check (`branch-conflict-state`) only *prefers* a
  fresh CI result over an old green one when the base has advanced
  (`idd-pre-merge.instructions.md`'s `clean`/`behind-no-conflict`
  routing) rather than requiring it, and a bare CI rerun after the base
  moves can replay a `pull_request`-triggered run's stale merge-ref
  (`docs/idd-helper-scripts.md`'s `baseAdvancedSinceMergeBase` note).
  F2/F3 re-fetch the current HEAD's own status but do not themselves
  validate that HEAD against the latest `master`. Accepting that
  narrower, textual-conflict-freeness-only protection is the actual
  cost of avoiding the GitHub-enforced cascade.
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

### Trusted Marker Actors

**Current value** (`trustedMarkerActors` in
[`.github/idd/config.json`](../.github/idd/config.json)):
`["kurone-kito", "github-actions[bot]"]`.

`github-actions[bot]` is included because
[`.github/workflows/post-merge-cleanup.yml`](../.github/workflows/post-merge-cleanup.yml)
posts its F4 server-side-fallback `idd-cleanup-evidence` comments using
the workflow's `GITHUB_TOKEN`, which always authors as
`github-actions[bot]`. The workflow's own duplicate-prevention logic
already hardcodes this login as trusted, but the agent-side F4 dedup
check reads only `trustedMarkerActors` from
`.github/idd/config.json` — without this entry, an agent running F4
after the workflow already posted evidence cannot recognize that
comment as trusted and reposts a duplicate. This duplication was
observed for issue #129 (PR #131) on 2026-09-01 before this entry was
added (#132).

### Helper Runtime Profile

**Profile**: `ephemeral-npx`

**`helperRuntime.packageSpec`**:
`https://codeload.github.com/kurone-kito/idd-skill/tar.gz/1f90787ebf4021673ce6e5eb69741df331fd2037`
(repository override; distributed default is the mutable `main`
archive URL). Recorded explicitly so every helper-emitted
`ephemeral-npx` invocation string — not only a hand-typed one-shot
`--package-spec` flag — reflects this repository's actual reviewed
pin (matching [Upstream pin](#upstream-pin) below), rather than
silently resolving to a moving target.

Helper scripts run via `npx` against this pinned upstream package spec
rather than being vendored into this repository or installed as a
project dependency:

```sh
npx --yes --package https://codeload.github.com/kurone-kito/idd-skill/tar.gz/1f90787ebf4021673ce6e5eb69741df331fd2037 <idd-command>
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
[`.claude/skills/issue-authoring/`](../.claude/skills/issue-authoring/SKILL.md),
resynced to the current
[Upstream pin](#upstream-pin) commit
`1f90787ebf4021673ce6e5eb69741df331fd2037` (v0.11.0, 2026-09-12; #153),
up from the v0.7.0 commit this bundle was still pinned to before this
resync. Bundle-internal maintenance-doc links stay relinked to upstream
URLs — see the in-file note in `SKILL.md` — and the local-only
`agents/openai.yaml` file (no upstream counterpart) is untouched.

Adopts the **author-and-publish / hold-release** approval model the
bundle redesigned around in upstream v0.8.0: a drafted `ready` issue now
publishes immediately under a suppressing `status:authoring` label
(Discover skips issues carrying it) instead of waiting for a
per-issue publish approval; release still normally needs a later,
explicit **hold-release** (removing the label and handing the authored
set to the IDD execution loop) — the one documented exception is a
narrow, single-target, provenance-gated auto-release for a follow-up
issue explicitly marked `review-fix-loop-cutoff` at Stage 1 publication
time, which may complete release without waiting for that explicit
request. This repository adopts the new model as-is rather than
keeping the older per-issue pre-publish approval flow as a local
divergence.

This resync also fixes a known bug in the previously-pinned bundle
version (upstream `kurone-kito/idd-skill#2931`): `post-idd-marker` now
posts this bundle's `authoring-owner`/`authoring-publication-intent`
markers through the same trusted, byte-exact JSON path every other
operational marker uses, instead of a hand-computed `body-sha256` that
could silently mismatch and hide an acquire marker from the
hide-on-supersede sweep permanently. The companion
`sweep-authoring-markers` helper (upstream `kurone-kito/idd-skill#2935`;
see [IDD helper scripts](idd-helper-scripts.md)) replaces the former
8-step manual hide-on-supersede procedure with a single command.

- **`issueAuthoring.maxClarificationRounds`**: no override recorded in
  `.github/idd/config.json`; the bundle's distributed default of `3`
  rounds applies
- **`issueAuthoring.heartbeatCoalesceWindow`** (added v0.10.0): no
  override recorded; the bundle's distributed default (`PT2M`) applies
  (#155).
- **`issueAuthoring.journalIssue`** (added v0.10.0): set to
  `"kurone-kito/setup.windows#175"` (#172). #155 originally left this
  unset on the premise that this repository "has always
  cross-referenced flat orphan issues via `Blocked by #NNN` and has
  never needed a standalone authoring set" — that premise did not
  survive contact with the actual v0.11.0 authoring-hold model: any
  standalone Stage 1 set with no existing roadmap/anchor issue requires
  a configured journal, and #172 confirmed this repository's normal
  authoring pattern (flat orphan issues with no pre-existing anchor)
  is exactly that standalone-set case, so leaving the field unset would
  have permanently blocked this skill from ever drafting a fresh
  standalone issue. The rejected alternative — accept the limitation
  and restrict this skill to extending existing Stage-1-held sets only,
  falling back to plain `gh issue create` for genuinely new orphans —
  was set aside because it would make the skill's stated purpose
  (preparing IDD-ready orphan issues, this repository's dominant
  pattern) inapplicable to that pattern's own common case. #175 is a
  new issue created solely to serve as this durable, comment-only
  journal target and carries no other content.
  **Discovery-exclusion invariant** (Copilot review, PR #176): #175
  carries no `setup-windows-roadmap-id`/`setup-windows-blocked-by`
  marker and only the generic `enhancement` label, so nothing would
  otherwise stop A0-O from surfacing and claiming it as ordinary
  orphan work. It is kept permanently **closed** instead — A0-O's own
  candidate scan is scoped to open issues only
  (`idd-discover.instructions.md`'s "Search all open issues" step), so
  a closed #175 is never a Discover candidate, while GitHub still
  accepts comments on a closed issue (the journal's only actual use).
  Never reopen #175 or repurpose it as a work item.

### IDD Spec Audit Companion

**Status**: `installed` at
[`.claude/skills/idd-spec-audit/`](../.claude/skills/idd-spec-audit/SKILL.md)
(initially copied from the pinned upstream commit's
`skills/idd-spec-audit/`, then locally adapted with three in-file
changes: in `SKILL.md`, a `<!-- setup.windows: ... -->` comment
clarifying that its `.claude/**` mirror-tree exclusion has no
applicable target in this installation (so the issue-authoring bundle
stays in scope), and an ordinary prose edit to the Execution model's
report-output bullet clarifying that the report is emitted as output
rather than written into `references/report-template.md`; in
`references/report-template.md`, added per-file `Location A`/
`Location B` fields to the R2 finding shape, matching the `Location`
field every other rule set's shape already has; no bundle-internal
maintenance-doc links needed relinking, unlike the issue-authoring
companion above).

Read-only semantic audit of the IDD instruction corpus (leaked session
context, cross-file contradictions, fresh-memory completability gaps,
automation blockers, restatement-discipline drift). Never edits files
or mutates issues; adopted to sanity-check the instruction corpus after
the v0.7.0 → v0.11.0 pin resync (#152 and related issues).

**Pinned commit**:
`kurone-kito/idd-skill @ 1f90787ebf4021673ce6e5eb69741df331fd2037`
(v0.11.0, 2026-09-12). This was a fresh install with no prior local
copy to keep in lockstep, so it was pinned independently of the
repository-wide pin bump (#152 and related issues) rather than blocked
on it; that pin bump has since landed at the same commit, and the
three CI workflow YAML files (reconciled separately in #163) now agree
too, so this companion and the rest of the repository's
`idd-template/`-derived files are all at the same pin; see
[Upstream pin](#upstream-pin) below for the authoritative,
currently-landed repo-wide pin record.

### IDD Label Names

Distribution defaults, no `labels.roadmapLabelName` /
`labels.blockedByHumanLabelName` / `labels.needsDecisionLabelName`
override recorded in `.github/idd/config.json` (see
[Optional `policy.schema.json` Fields — Adopted](#optional-policyschemajson-fields--adopted)
below for the separate `labels.untrustedLabelerLogins` override that
*is* recorded):

- roadmap label: `roadmap`
- blocked-by-human label: `status:blocked-by-human`
- needs-decision label: `status:needs-decision`

### Optional `policy.schema.json` Fields — Adopted

This section records, per field, the maintainer decision on the
optional fields upstream (`kurone-kito/idd-skill`) added to
`schemas/policy.schema.json` between this repository's previous pin
(v0.7.0) and its current one (v0.11.0), following the resync tracked
by #152 and related issues. Adopted here (recorded in
`.github/idd/config.json`):

- **`authoringLanguage`**: `"en"`. This field predates the v0.7.0 →
  v0.11.0 pin gap itself (it already existed at v0.7.0) but had never
  been set. Its schema description treats an absent value as
  behaving like `en` (fail-safe default), yet this repository's own
  issue/PR history has consistently drifted to Japanese in practice —
  because, while the field stayed unset, PR-submit (the consumer that
  existed before #153) sat downstream of the interactive agent
  session's own conversational-language-match instruction (this
  repository's and the operator's global `CLAUDE.md` guidance), which
  filled the ambiguity the undocumented/unset default left open.
  Setting it explicitly to `"en"` (a fixed BCP-47 tag, not the literal
  `match-source`) removes that ambiguity for both current consumers
  going forward: PR-submit, and — since #153's resync — the
  `.claude/skills/issue-authoring/` bundle's `references/contract.md`
  for drafted issue bodies. With a fixed tag configured, drafted issue
  prose is governed deterministically by this field and is **not**
  overridden by the operator's live conversational language (that
  override only applies to the separate literal `match-source`
  setting, which this repository does not use). This also matches the
  `language: en` already configured in this repository's
  `.coderabbit.yaml` (the two settings are independently wired to
  nothing in common, but keeping them
  aligned is desirable for an open-source project). This does not
  retroactively change any already-published issue/PR, nor the fixed
  English wording the autopilot-suitability/effort footer visible-line
  mirror uses regardless of this setting, nor the discover/claim
  runtime (documented as not yet reading this field).
- **`mergePolicyAck`**: `"fully_autonomous_merge"` (an enum string
  matching `mergePolicy`'s own value, **not** a boolean). Diagnostics
  only — silences an `idd-doctor` warning confirming the maintainer
  has re-reviewed `mergePolicy: fully_autonomous_merge` without
  changing any merge-authority behavior.
- **`provider`**: `"github"`. GitHub is the only implemented and fully
  exercised provider — this repository's helpers use `gh`, `jq`, and
  `curl` for GitHub operations; non-GitHub adapters remain future
  work. Recording the selection carries zero behavioral risk.
- **`providerHealth`**: `{ minCorroboratingPrs: 2, samplingWindow:
  "PT24H" }`. Both values match the read-only provider-health
  classifier's own distributed defaults — recorded here for
  self-documentation, not to change behavior.
- **`localValidationEvidence`**: `{ maxAge: "PT4H" }`. Matches the
  existing default freshness window for an `idd-local-validation-evidence`
  marker — recorded for self-documentation.
- **`advisoryConvergence`**: `{ copilotReviewPollMaxWait: "PT60S" }`.
  This is the genuine pre-existing default (documented as matching the
  pre-`kurone-kito/idd-skill#2333` hardcoded 60000ms ceiling) —
  recording it changes nothing.
  `copilotReviewPollInterval` is deliberately left unset; see below.
- **`upstreamEscalation`**: `{ enabled: true }`. Opt-in toggle allowing
  a session to flag a high-confidence `idd-skill` upstream defect as a
  local `status:upstream-candidate` issue. The maintainer enabled this
  (2026-09-12) given this repository's ongoing upstream-tracking work
  (the v0.7.0 → v0.11.0 resync and its follow-ups) makes this kind of
  discovery routine going forward.
- **`critiqueLoop.delegate`**: `{ command: "npx -y markdownlint-cli2
  \"**/*.md\" && npx -y cspell lint \"**\" --no-progress && pwsh -c
  \"Invoke-ScriptAnalyzer -Path . -Recurse -Settings
  ./PSScriptAnalyzerSettings.psd1 -EnableExit\" && pwsh -c
  \"Invoke-Pester -Path ./tests/powershell -CI\"", mode: "combined" }`
  — the literal current `commands.pre-push-validate` value (keep this
  copy in sync if that command ever changes). This repository already
  runs this same command locally as `pre-push-validate` (markdownlint,
  cspell, PSScriptAnalyzer, Pester); pointing the C1 critique delegate
  at it surfaces those findings during self-review as well, not only
  at pre-push time. `pre-push-validate` is **not itself** one of the
  registered required CI checks — `.github/workflows/lint.yml`
  registers separate `lint`, `powershell-analyzer`, and `pester` jobs,
  and `configuration-drift` (a distinct check this command does not
  run) is also required — it only mirrors a subset of what those jobs
  cover, run locally under one umbrella name. `mode: "combined"` keeps
  the existing per-agent critique pass running unconditionally
  alongside the delegate — this only adds a signal, never removes
  one. The maintainer explicitly recorded this exact `command`/`mode`
  pairing in #155's own acceptance criteria, accepting the added
  per-round cost of running the full PSScriptAnalyzer/Pester suite on
  every C1/E10 pass in exchange for that self-review signal; revisit
  this trade-off as a separate decision if round-count data later
  shows it is not worth the cost, rather than silently swapping in a
  lighter delegate command here.
- **`labels.untrustedLabelerLogins`**: `["coderabbitai[bot]",
  "reviewpad[bot]"]`. This repository's `.coderabbit.yaml` sets
  `issue_enrichment.labeling.auto_apply_labels: true` with
  `labeling_instructions` covering only `bug`/`documentation`/
  `enhancement`/`question` — none of this repository's three reserved
  IDD labels (`roadmap`, `status:blocked-by-human`,
  `status:needs-decision`). Per the documented risk (see
  [Reserved-label guard recipe](customization.md#reserved-label-guard-recipe)),
  omitting a label from a semantic auto-labeler's own instructions does
  **not** restrict which labels it may actually apply — a real,
  previously unguarded risk, not a hypothetical one: a full-history
  sweep (`idd-suggest-untrusted-labelers`) confirmed `coderabbitai[bot]`
  has applied 11 labels historically in this repository, and
  `reviewpad[bot]` (an actor with no current configuration or workflow
  in this repository, so not affirmatively trusted) has applied 4. The
  sweep also surfaced `github-actions[bot]` (6 labeled events), which
  this list deliberately **excludes**: cross-checked against
  `.github/workflows/stale.yml`, the only workflow in this repository
  that applies labels via that identity, and confirmed it only ever
  applies the `stale` label — never one of the three reserved names —
  so it is this repository's own trusted automation, exactly the
  exclusion the recipe's guidance calls for. Guarded by the new
  [`.github/workflows/strip-untrusted-labels.yml`](../.github/workflows/strip-untrusted-labels.yml),
  hand-copied from the recipe's manual path (no local `idd-skill` clone
  is available in this environment for the generated-guard path via
  `idd-onboard --substitute`).
- **`issueAuthoring.journalIssue`**: `"kurone-kito/setup.windows#175"`
  — see the [Issue-Authoring Companion](#issue-authoring-companion)
  section above for the full rationale (#172).

### Optional `policy.schema.json` Fields — Intentionally Unset

Recorded here so a later session does not "fix" these as an oversight:

- **`developmentBranch`** — this repository has a single long-lived
  branch (`master`); the field's purpose (distinguishing a
  feature-integration branch from a trusted default branch) does not
  apply.
- **`discover.milestoneScope`** — this repository does not use GitHub
  milestones; this field's tie-break only has an effect when a
  matching-title OPEN milestone exists.
- **`advisoryConvergence.copilotReviewPollInterval`** — its own schema
  description states that the genuine existing default (a hardcoded
  7500ms interval) has no exact equivalent expressible in this field's
  required ISO 8601 duration format; recording an approximate value
  (e.g. `PT7S` or `PT8S`) would be an actual behavior change, not a
  restatement of the default, so it stays unset.
- **`providerOutage.*`** (`declarationTarget`, `maxValidity`,
  `maxParkedChanges`) — upstream's own customization guidance scopes
  this feature to repositories that have experienced a multi-hour
  advisory-review or Actions outage; this repository has no such
  history, and `declarationTarget` has no meaningful default (it must
  name a real issue). Fabricating one now would add an unused process
  with no benefit.
- **`advisoryWait.secondaryQuietWindow`** /
  **`advisoryWait.providerOutage.terminalWindow`** — both only take
  effect when `advisoryWait.secondaryBotLogin` is configured or an
  outage declaration is active; this repository configures no
  secondary advisory bot (`advisoryBotLogins` lists Copilot and
  CodeRabbit as advisory reviewers, not a separate `secondaryBotLogin`
  supplement) and has no outage-declaration history, so both remain
  no-ops either way.
- **`critiqueLoop.deferAfterRounds`** — the distributed default (`15`)
  is documented upstream as a provisional starting point pending real
  usage data; this repository has none yet to justify overriding it.
- **`critiqueLoop.telemetryHook`** — this repository has no external
  notification system to receive per-round critique telemetry.
- **`worktreeGuard.refuseBaseBranchCommits`** — a no-op as long as
  `developmentBranch` stays unset (the schema itself documents that
  this pure-POSIX-sh hook has no network access to resolve the live
  GitHub default branch, so it stays inert without `developmentBranch`
  set); kept unset in lockstep with that field.
- **`issueAuthoring.heartbeatCoalesceWindow`** — no operational data
  justifies overriding the distributed default (`PT2M`).

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
kurone-kito/idd-skill @ 1f90787ebf4021673ce6e5eb69741df331fd2037 (v0.11.0, 2026-09-12)
```

This repository additionally hosts the following template workflow
files as dogfooded copies, kept in sync manually on each pin bump.
All three are pinned to the same commit as above (issue #163
reconciled them up from the previous v0.7.0 pin):

- `.github/workflows/idd-advisory-convergence.yml` — also adds the
  `pull_request_target` trigger and the
  `idd-advisory-convergence-self-waiver` job (`kurone-kito/idd-skill#2657`)
  alongside the pre-existing `pull_request` trigger, per upstream's own
  documented transitional dual-trigger migration; `pull_request` stays
  active until `pull_request_target` has run cleanly on production PRs
  for a period, matching upstream's own stance
- `.github/workflows/idd-advisory-convergence-comment.yml` — also adds
  the `issue_comment` trigger and the debounced rerun logic
  (`kurone-kito/idd-skill#1381`/`#2638`), and the `pull_request_review`
  trigger moved here from the required workflow above; its
  "Classify review comment" step now uses the standard
  `npx --package <pin> idd-review-comment-origin` form now that
  upstream ships a published bin entry for it
  (`kurone-kito/idd-skill#2214`/`#2260`), replacing the previous
  runner-temp `npm install --prefix` workaround
- `.github/workflows/post-merge-cleanup.yml` — also adopts the
  duplicate-evidence-comment fix requiring both the prior recorded
  status and the current run's own outcome to be converged
  (`kurone-kito/idd-skill#2213`) before skipping a repeat post

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
