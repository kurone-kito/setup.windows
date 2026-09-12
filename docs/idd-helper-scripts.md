# IDD Helper Script Evaluation

This document records the current decision on optional helper scripts for
the IDD workflow. It exists so future reviews can reference the trade-off
directly instead of re-evaluating the same suggestion from scratch.

## Flag-name and field-name conventions

Several helpers require a specific flag name that does not match
instinct, and throw rather than defaulting to a same-named flag from a
different helper. `--issue` is the sharpest trap: it is a genuine,
functioning flag on several other helpers -- required outright on
`forced-handoff-marker.mjs` and `claim-approval-gate.mjs`, and
required as one of a small set of mutually exclusive input flags on
`discover-viability-gate.mjs` (or `--issues`) and
`suitability-triage.mjs` (or `--body-file` / `--stdin`) -- which primes
the instinct to reach for it elsewhere. `audit-authored-issue.mjs` also
accepts a genuine, functioning `--issue`: normally optional (it only
sharpens the `authoring-owner-marker-trail` check's target match), but
required once `--new-issue` and `--journal-comments-file` are both
given, so the journal cross-check always has a resolvable issue
identity to verify against. But the claim-revalidation flag
on most mutation-capable helpers is named `--claim-issue` instead, and
requiredness varies by helper:

- **Unconditionally required** (modulo an explicit opt-out):
  `pre-merge-readiness.mjs` throws without `--claim-issue` unless
  `--claimless` is passed.
- **Required only under `--apply`, with an explicit opt-out**:
  `audit-pr-cleanup.mjs` and `live-status-digest.mjs` both accept
  `--skip-claim-check` in place of `--claim-issue`/`--claim-id`.
- **Required only under `--apply`, with no opt-out**:
  `disposition-non-review-notices.mjs` and `resolve-review-thread.mjs`.
  None of these four ever need the flag outside `--apply`.
- **Optional, with auto-discovery when omitted**:
  `advisory-convergence.mjs` (falls back to the PR's closing-issue
  references) and `idd-roadmap-audit-execute.mjs` (the flag, when
  given, is only cross-checked against `--roadmap`; the apply-mode
  identity flag there is `--claim-id`, not `--claim-issue`).

`live-status-digest.mjs` is the one helper where `--issue` and
`--claim-issue` coexist as genuinely different flags: `--issue` is the
digest's own target (mutually exclusive with `--pr`), and
`--claim-issue` is the separate claim-revalidation flag -- the two are
not interchangeable there either. (`idd-merge-execute.mjs` forwards
any flag it does not recognize verbatim to `pre-merge-readiness.mjs`,
so `--claim-issue` reaches it transitively even though it declares no
such flag of its own.)

No single top-level decision/verdict field name is consistent across
the evidence-collector family. This reflects organic accretion across
many independently authored helpers rather than a recorded design
decision, and no normalization is currently planned. Read each
helper's own `--help` output or its documented JSON shape rather than
assuming a field name carries over -- a name that looks like a field in
the source (a type or local-variable name) is not necessarily one of
the printed object's own top-level keys. Representative examples:
`advisory-convergence.mjs` and `pre-merge-readiness.mjs` both return a
top-level `ready` boolean (the latter alongside `blockers`);
`idd-roadmap-audit-execute.mjs` also returns `ready`;
`discover-readiness-check.mjs` returns `ready` in its default
per-issue mode, but a structurally different `{eligible,
eligible_count, total}` shape under `--swarm-floor`;
`discover-viability-gate.mjs` returns `viable` and `discarded` (not
`passed` -- that name exists only on an internal per-issue helper,
never copied into the printed output); `suitability-triage.mjs`
returns `passed` for its live `--issue` invocation, but its offline
`--body-file`/`--stdin` mode intentionally carries no aggregate
`passed` value at all; `claim-approval-gate.mjs` returns `approved`.
The mutation-style helpers overlap rather than cleanly splitting on
one field: `audit-pr-cleanup.mjs` exposes both `mode`
(`dry-run`/`apply`) and `status` (a seven-value vocabulary: `clean`,
`needs-apply`, `permission-blocked`, `rescan-failed`, `failed`,
`incomplete`, `applied`); `disposition-non-review-notices.mjs` prints
no `status` key at all in its default dry-run mode, and its `status`
value (`applied`/`failed`) under `--apply` is still driven only by
`applied`/`failed` -- `--apply` output also carries a separate
`staleSkipped` array (#2695: Codex summary items whose live state
was re-checked and found no longer Completed immediately before
posting), which does not affect `status`; `resolve-review-thread.mjs`
returns `mode` (`dry-run`/`apply`) alongside its own separate
`status?` (`applied`/`failed`).

## Contents API permission-masking probe (kurone-kito/idd-skill#2716)

`loadTrustedIddConfig` (`src/scripts/idd-config.mts`) fetches
`.github/idd/config.json` at a trusted `ref` via the GitHub Contents API
and returns `null` (documented-defaults fallback) only on a confirmed
404; any other failure, including a permission denial, throws instead of
guessing. Whether GitHub's Contents API masks a `403` (permission denied)
as a `404` for a token lacking Contents read access was an open empirical
question -- a related masking pattern is already documented for the
branch-protection/ruleset endpoints specifically (`trustEmptyProtectionReads`,
see `docs/policy-constants.md`).

**Verified 2026-09-08**: no masking observed for the Contents API. A
disposable **private** repository
(`kurone-kito/idd-skill-issue-2716-contents-api-probe`, intentionally
retained rather than deleted -- see kurone-kito/idd-skill#2716) ran a GitHub
Actions workflow declaring `permissions: { contents: none }` at the job
level, then used the workflow's own ephemeral `GITHUB_TOKEN` to request
an existing file at a valid ref via
`GET /repos/{owner}/{repo}/contents/{path}?ref={sha}`. Response:
`403` with body `{"message": "Resource not accessible by integration"}`
-- a genuine, unambiguous permission denial, not a `404`. The repo is
**private** deliberately: a public repo's `contents: none` token can
still read publicly-visible content and return `200`, which would prove
nothing about masking.

`loadTrustedIddConfig`'s existing fail-closed `deriveGhHttpStatus(error)
=== 404` check is therefore correct as written and needs no change for
this finding. See the function's own JSDoc for the same note attached
directly to its contract.

## Decision

In the idd-skill source repository, the following optional helpers were adopted:

### Helper contract classes

Every helper below falls into one of two contract classes:

- **Evidence collectors** — read-only. They never post comments, resolve
  review threads, merge, or close anything; they emit machine-readable
  evidence (usually JSON) for the calling phase to interpret.
- **Dry-run-by-default authoring helpers** — capable of mutating GitHub
  state (posting a comment, resolving a thread, merging, closing), but
  only under an explicit `--apply` flag (plus interactive confirmation
  where noted); the default invocation always prints what it would do
  without acting.

Going forward, a per-helper bullet should state only what doesn't
already follow from its class — an additional confirmation step, a
narrower evidence scope, an unusual flag name — not a restatement of
the class itself; existing bullets are not retrofitted by this
preamble. Whenever a helper cannot complete autonomously, its own
bullet documents the fallback path beside the helper's invocation, not
in this preamble, since the fallback differs per helper.

**Discover & Claim Phase Helpers (Phase 1):**

- `scripts/discover-orphan-filter.mjs` for A0-O orphan issue detection and
  filtering (referenced in
  [kurone-kito/idd-skill#390](https://github.com/kurone-kito/idd-skill/issues/390)),
  with opt-in `--with-claim-state` / `--current-claim-id` active-claim
  annotation parity with `discover-roadmap-graph`'s flag of the same name
  (referenced in
  [kurone-kito/idd-skill#1395](https://github.com/kurone-kito/idd-skill/issues/1395)).
  Default-on (not opt-in): excludes a candidate whose most recent trusted
  `A4.5 suitability gate rejection` comment carries a still-current
  `<!-- {prefix}-triage-verdict: <outcome> -->` marker for one of the four
  non-label outcomes, bucketed under `filtered.triage_verdict_rejected`
  (referenced in
  [kurone-kito/idd-skill#2243](https://github.com/kurone-kito/idd-skill/issues/2243);
  see its `--help` for the fetch-scope and staleness details)
- `scripts/discover-roadmap-graph.mjs` for A1.5/A2 recursive roadmap graph
  enumeration and classification
- `scripts/idd-roadmap-audit-execute.mjs` for the A1.5 roadmap-completion
  mutation: dry-run gates only the mechanical completion preconditions
  (all descendants closed/complete, no open/unresolved/nested-roadmap
  blocker) via the roadmap-graph traversal and emits `{ready, blockers,
  evidenceBody}` — it does **not** verify the roadmap's free-form success
  criteria or autonomy-gap items, which the caller must confirm
  separately before `--apply`; `--apply` re-validates the roadmap-audit
  claim and the graph immediately before mutating, then posts the
  evidence comment, closes the completed roadmap, and releases the claim
  (referenced in
  [kurone-kito/idd-skill#1071](https://github.com/kurone-kito/idd-skill/issues/1071))
- `scripts/discover-readiness-check.mjs` for A3 readiness criterion
  evaluation (referenced in
  [kurone-kito/idd-skill#391](https://github.com/kurone-kito/idd-skill/issues/391)).
  Default-on (not opt-in): the same triage-verdict marker exclusion as
  `discover-orphan-filter.mjs` above, surfaced as a
  `triage_verdict:<outcome>` entry in `filteredOut[].reasons` (referenced
  in
  [kurone-kito/idd-skill#2243](https://github.com/kurone-kito/idd-skill/issues/2243))
- `scripts/discover-viability-gate.mjs` for A4 viability gate evaluation
  across limited scope, clear verification, and autonomous completion
  criteria (referenced in
  [kurone-kito/idd-skill#505](https://github.com/kurone-kito/idd-skill/issues/505))
- `scripts/discover-shared-file-overlap.mjs` for read-only A4 Step 2
  high-contention shared-file overlap evidence: it flags candidate issues
  whose `## Candidate files` collide with actively-claimed / open-PR work on
  the F-phase bundle instruction files (referenced in
  [kurone-kito/idd-skill#1019](https://github.com/kurone-kito/idd-skill/issues/1019))
- `scripts/select-desynced-index.mjs` for the A4 Step 2 concurrent-selection
  desync band-index computation; deterministic and network-free (referenced
  in
  [kurone-kito/idd-skill#1397](https://github.com/kurone-kito/idd-skill/issues/1397))
- `scripts/suitability-triage.mjs` for A4.5 seven-check suitability
  evaluation (referenced in
  [kurone-kito/idd-skill#392](https://github.com/kurone-kito/idd-skill/issues/392)),
  including Check 4's high-confidence duplicate/superseded tier
  (closing-PR reference and same-candidate-files overlap, excluding
  high-contention files) (referenced in
  [kurone-kito/idd-skill#1484](https://github.com/kurone-kito/idd-skill/issues/1484)).
  `--body-file <path>` / `--stdin`, mutually exclusive with `--issue`, run
  a local/offline dry-run of six of the seven checks (every check except
  `duplicate_or_superseded`, which needs a live search index) against a
  drafted issue's text before it is ever published -- the same exported
  check functions the live path uses, not a reimplementation. The output
  carries `"mode": "local"` and no `outcome`/`passed`/`failedCheck` field
  of any kind, so a local six-of-seven pass can never be mistaken for a
  live `--issue <n>` verdict; `duplicate_or_superseded` always reports
  `"not_evaluated"`, never omitted (referenced in
  [kurone-kito/idd-skill#2102](https://github.com/kurone-kito/idd-skill/issues/2102))
- `scripts/claim-approval-gate.mjs` for A5(a) issue-author approval
  verification; A5(d) open-PR conflict checks remain manual by design
  (referenced in
  [kurone-kito/idd-skill#393](https://github.com/kurone-kito/idd-skill/issues/393))
- `scripts/branch-name.mjs` for the A5(e) canonical
  `issue/<number>-<slug>` branch-name slug computation; deterministic and
  network-free (referenced in
  [kurone-kito/idd-skill#901](https://github.com/kurone-kito/idd-skill/issues/901))
- `scripts/emit-marker.mjs` for emitting the per-cycle `claimed-by` /
  `review-watermark` / `review-baseline` marker bodies (emit-only, no
  network write; referenced in
  [kurone-kito/idd-skill#900](https://github.com/kurone-kito/idd-skill/issues/900))
- `scripts/post-idd-marker.mjs` for rendering and POSTing any operational
  marker (`claim` / `unclaim` / `activation-nonce` / `watermark` /
  `baseline` / `advisory` / `advisory-recovery` / `advisory-reroll`) via
  the reliable JSON path that HTML-comment-first bodies require
  (referenced in
  [kurone-kito/idd-skill#1047](https://github.com/kurone-kito/idd-skill/issues/1047))
- `scripts/resume-claim-routing.mjs` for Resume Step 1 claim-state
  evaluation and takeover routing (referenced in
  [kurone-kito/idd-skill#394](https://github.com/kurone-kito/idd-skill/issues/394))
- `scripts/resume-route-selection.mjs` for Resume Step 3 PR/CI/review
  state routing (referenced in
  [kurone-kito/idd-skill#395](https://github.com/kurone-kito/idd-skill/issues/395))

**Work & Submit Phase Helpers:**

- `scripts/branch-conflict-state.mjs` for read-only branch conflict and
  synchronization state classification; used by D/E/F routing to decide
  whether `merge-base`, `hold-unknown`, or no action is needed without
  mutating the worktree or PR branch (added in 0.2.0)
- `scripts/verify-install-deps.mjs` for B1 Step 3 `install-deps`: runs
  the underlying install command, verifies a key post-install binary
  exists, retries the install exactly once if it does not, and fails
  loudly rather than continuing in a silently under-installed state
  (referenced in
  [kurone-kito/idd-skill#1237](https://github.com/kurone-kito/idd-skill/issues/1237)).
  Source-repo internal helper; not distributed via the package-manager
  / ephemeral-npx profiles.
- `scripts/idd-critique-delegate.mjs` for the effective
  `critiqueLoop.delegate` verdict consumed by both C1 and E10:
  `usable`, `source`, `command`, `mode`, and a machine-readable
  `reason` when unusable, delegating entirely to the existing exported
  resolvers (referenced in
  [kurone-kito/idd-skill#2329](https://github.com/kurone-kito/idd-skill/issues/2329))
- `scripts/idd-critique-telemetry-hook.mjs` for the C-phase effective
  `critiqueLoop.telemetryHook` verdict (`usable`, `source`, `command`,
  and a machine-readable `reason` when unusable), plus fire-and-forget
  invocation via `--invoke`: pipe the per-round JSON payload on stdin
  and it invokes the resolved hook, always exiting `0` regardless of
  the hook's own success or failure (referenced in
  [kurone-kito/idd-skill#2679](https://github.com/kurone-kito/idd-skill/issues/2679))
- `scripts/authoring-owner-provenance.mjs` for the review-fix-loop-cutoff
  auto-release exception's provenance check
  (`skills/issue-authoring/references/contract.md`): computes the sha256
  of a live issue body's exact UTF-8 content and compares it against that
  same issue's own Stage 1 `mode=acquire` `authoring-owner` marker's
  recorded `body-sha256`, reporting a machine-readable
  `pass`/`mismatch`/`not-found` verdict — `not-found` is never treated as
  a pass. Read-only: never posts, labels, or mutates anything (referenced
  in
  [kurone-kito/idd-skill#2891](https://github.com/kurone-kito/idd-skill/issues/2891)).
  Anchors on the target's own trusted, owner-marker-shaped comments
  (every one still containing the case-insensitive
  `<marker-prefix>-authoring-owner:` token, whether or not it parses),
  taken in deterministic comment order. If ANY of those comments was
  edited after posting (`updatedAt` differs from `createdAt`), the whole
  log is rejected up front, before a first candidate is even chosen — an
  editor cannot make the true Stage 1 acquire vanish from consideration
  by editing it into something unparseable or retargeting it, letting a
  later acquire silently win instead (PR #2901 review round 6, Copilot;
  contract.md: owner comments are append-only). Past that check, the
  _first_ candidate in comment order is scrutinized whatever its shape —
  not merely the first one that happens to parse and match this target —
  and must itself parse, name this issue as its target, and be a valid
  Stage 1 `mode=acquire` marker, or this reports `not-found` rather than
  silently skipping it for a later, validly-parsing marker (PR #2901
  review round 7, Copilot). "Valid" means every condition contract.md
  attaches to a genuine acquire: `mode=acquire` itself (every other mode
  — `bootstrap`, `resume`, `heartbeat`, `release`, ... — presupposes a
  prior acquire, so a well-formed history never opens with one);
  `supersedes=none` (contract.md requires this specifically for
  `acquire`); a real 64-hex `body-sha256`, never the sentinel `none`; and
  its own `anchor` names the same issue as its own `target` (a mismatch
  means the marker declares itself a multi-target set's non-anchor
  child, out of scope for this single-target-orphan helper) (PR #2901
  review round 5, chatgpt-codex-connector and Copilot). Only it, not any
  later marker, is guaranteed to have hashed the body as published: a
  same-generation racer, a `bootstrap`/`resume` recovery, or a legitimate
  re-acquisition after a full release cycle all hash whatever body is
  live at their own posting time, not the originally published one —
  comparing against any of those instead would make the check pass
  trivially for a body edited before that later marker (PR #2901 review,
  chatgpt-codex-connector across four rounds). `target` comparisons fold
  case, since GitHub owner/repo names are case-insensitive. Two accepted
  limitations, both fail-closed (never a false `pass`): a marker whose
  own `anchor` differs from its own `target` (a multi-target set's
  non-anchor child, out of scope here); and tampering with the true
  Stage 1 acquire that leaves no authoring-owner token at all — deleting
  it outright, or editing it into ordinary prose — which cannot be
  detected by a live comment-log reader (PR #2901 review rounds 5-7,
  chatgpt-codex-connector and Copilot)

**Review & Merge Phase Helpers:**

- `scripts/review-activity-snapshot.mjs` for read-only E/F review
  activity and CI snapshot metrics
- `scripts/advisory-wait-state.mjs` for read-only advisory-wait evidence
  collection and AW outcome reporting
- `scripts/ci-wait-policy.mjs` for read-only CI wait policy resolution
  and rerun-budget decisions
- `scripts/ci-wait-state.mjs` for a read-only, single-shot D-phase CI
  snapshot: per-check status keyed by `(checkName, workflowName)`, the
  live `headRefOid`, and a required-checks rollup
- `scripts/pre-merge-readiness.mjs` for read-only F2/F3 readiness
  evidence collection
- `scripts/idd-merge-execute.mjs` for the F3 merge gate: a dry-run
  verdict by default and, with `--apply`, the bound merge execution; it
  wraps `pre-merge-readiness` and adds no new decision authority
- `scripts/advisory-convergence.mjs` for the F2 advisory/disposition
  sub-gate (#1340): a deterministic `converged`/`ready` verdict with an
  exit-code contract via `--assert`, claim-independent so it also works
  as a required-check-able CI verdict. Stdout is always the JSON
  verdict only. When `--assert` fails (`ready` is false), a compact
  English next-action block is written to stderr _before_ that JSON so
  a GitHub Actions log surfaces the recovery command first (`#2142`).
  The block is derived from verdict fields, not from rewriting
  `reasons[]`. The same catalog is also emitted on the verdict as
  `nextActions` (`#2143`): each item is a stable `token`, a one-line
  English `summary`, and the command or phase `pointer` the stderr
  block already printed. A ready verdict has `nextActions: []`; `ready`
  does not depend on the field. Under `GITHUB_ACTIONS=true` a
  `::notice::` line is added as extra surfacing; it is not a substitute
  for the stderr block. `reasons[]` wording and the `--assert`
  exit-code contract stay unchanged.
- `scripts/rerun-advisory-convergence.mjs` (#1431) for a rerun-plan
  diagnosis of stuck `idd-advisory-convergence` check-run rollups,
  read-only by default: fetches every check-run instance for a PR's
  current HEAD SHA (paged commit check-runs API), classifies each as
  `pass` / `pending` / `bot-gated-skip` / `unresolved` /
  `awaiting-fresh-review` / `rerun-eligible`, and prints the ordered,
  deduplicated `gh run rerun <id>` recovery plan for the rerun-eligible
  instances (each command includes `-R owner/repo` when the repository
  is known) — referenced from `idd-ci.instructions.md` §Rerun mechanics
  as the preferred way to produce that plan. An instance whose own
  advisory-convergence job-log verdict reports that the latest Copilot
  review does not cover the current HEAD is classified
  `awaiting-fresh-review` rather than `rerun-eligible` (#1775), so the
  diagnosis (and `--apply`) never burn the rerun-once budget on a
  failure only a fresh review can clear. That historical job-log verdict
  is an immutable snapshot from when the run executed, so it can go
  stale once a fresh review actually lands afterward — a live check
  (reusing `advisory-convergence.mjs`'s own latest-review evidence)
  recovers the instance back to `rerun-eligible` once the current HEAD
  is genuinely covered; live coverage that is unreadable or not yet
  established leaves the hold exactly as before (#1806). When the
  rollup is stuck on a
  bot-gated instance alongside an already-passing non-bot
  pull_request-family instance, it additionally offers a
  `recoveryRefreshPlan` — populated even alongside a non-empty rerun
  plan when every rerun-eligible instance there is itself bot-triggered
  (#1745; rerunning a bot-triggered instance does not supply the
  non-bot trigger the recovery-refresh option exists to provide):
  rerunning the already-passing instance is the documented way to force
  a fresh non-bot evaluation and clear the stale rollup. Pass `--apply`
  (#1766) to execute that same plan instead of only diagnosing it:
  reruns each rerun-eligible instance in order (recovery-refresh first
  when one applies), waits for each to reach a genuinely new completed
  attempt before starting the next, and stops early once the recomputed
  plan is fully resolved — never a `bot-gated-skip`,
  `awaiting-fresh-review`, or rerun-budget-held instance.
- `scripts/live-status-digest.mjs` for issue or PR live status digest
  discovery, rendering, dry-run, and claim-checked upsert
- `scripts/audit-pr-cleanup.mjs` for post-merge comment cleanup auditing
- `scripts/minimize-superseded-markers.mjs` for in-flight per-marker
  `minimizeComment` of strictly superseded markers — `review-watermark`/
  `review-baseline` (E1 Step 2), `advisory-wait`/`advisory-wait-recovery`/
  `advisory-reroll` (advisory-wait AW3-H), or `claimed-by` (claim
  takeover) — after the replacement marker is verified

  Per-helper trust model: `minimize-superseded-markers` resolves its
  trusted-author gate with the same `flag > env > config` ladder as the
  evidence helpers (the singular `trustedMarkerActorsSource` names the
  winning source) and stays self-contained so the template copy works
  without `protocol-helpers.mjs`. `audit-pr-cleanup` and
  `forced-handoff-marker` instead **union** the configured sources —
  viewer, flag (where accepted), `IDD_TRUSTED_MARKER_ACTORS`, and the
  config `trustedMarkerActors` list — with the optional
  collaborator-permission trust; their JSON evidence reports the
  resolved viewer-plus-configured list and the plural
  `trustedMarkerActorsSources` mix. Collaborator trust never appears in
  the list itself: both helpers add a `collaborators` source tag when
  collaborator permission actually trusted an author, and
  `audit-pr-cleanup` additionally reports the capability as
  `collaboratorTrustEnabled`. Config-listed actors therefore widen
  trust explicitly while collaborator-permission trust stays opt-in
  (the `IDD_TRUST_COLLABORATOR_MARKERS` environment variable or the
  `trustCollaboratorMarkers` config field)
- `scripts/sweep-authoring-markers.mjs` (#2935) for the fetch-driven
  hide-on-supersede sweep the issue-authoring contract's Stage 2 release
  flow depends on: given one or more `--issue` targets, it fetches each
  issue's comments via GraphQL (selecting `isMinimized`, which REST
  never carries), classifies every comment with
  `matchCanonicalAuthoringMarkerFamily`, keeps only the newest
  trusted-actor match per `authoring-owner`/`authoring-publication-intent`
  family, and minimizes every other eligible candidate in one mutation
  pass via `minimize-superseded-markers.mjs`'s own `runMinimize` —
  replacing the ~8-step manual paginate/classify/filter procedure the
  contract previously described in prose at three separate points. Same
  mandatory trusted-author gate as `minimize-superseded-markers` (no
  `--allow-untrusted` escape hatch: this sweep's own "newest"
  determination depends on the trust filter)
- `scripts/review-disposition-verify.mjs` for read-only E7 disposition
  marker presence verification across PATH A and PATH B items
- `scripts/disposition-non-review-notices.mjs` for dry-run/apply
  dispositioning of advisory non-review notices (rate-limit / usage-limit)
  and the CodeRabbit summary walkthrough on a PR — emitting or posting the
  canonical E6 `**Rejected** — {bot} did not review HEAD …` per notice and
  `**Accepted** — {bot} summary walkthrough …` per current summary,
  marker-first, idempotently and fail-closed (only classifier-recognized
  notices and the exact summary marker)
- `scripts/resolve-review-thread.mjs` for the E13 write-side disposition:
  post the reply to the review thread that owns a review comment **and**
  resolve that thread in one invocation — dry-run by default, `--apply`
  re-validates the active claim and posts the reply before resolving
  (a failed reply never leaves a silently-resolved thread)

**Operator Recovery Helpers:**

- `scripts/external-check-waiver.mjs` for dry-run/apply generation of
  maintainer-authorized external-check waiver comments tied to an active
  PR claim
- `scripts/force-handoff.mjs` for the interactive TTY-only
  `idd-force-handoff` operator facade that drives issue input, optional
  PR confirmation from live branch state, and final `y/N` consent
- `scripts/forced-handoff-marker.mjs` for low-level forced-handoff
  marker rendering and inspection when maintainers need the canonical
  payload without the interactive facade

**Post-Merge Audit Helpers:**

- `scripts/merged-pr-feedback-sweep.mjs` for read-only detection of
  unresolved / unaddressed advisory feedback on merged PRs, fed manually to
  the issue-authoring skill (referenced in
  [kurone-kito/idd-skill#931](https://github.com/kurone-kito/idd-skill/issues/931))

**Utility and Diagnostic Commands:**

The following commands are shipped alongside the issue-loop helpers but are
not phase helpers. They are support utilities and are distinguished here so
future inventory reviews do not need to re-infer their role from code.

- `scripts/idd-doctor.mjs` (`idd-doctor`) — onboarding and configuration
  diagnostics; reads repository config and helper runtime wiring, reports
  gaps without mutating any state. Its post-merge cleanup-backlog check
  scans merged PRs in a default 14-day window with one serial `gh api`
  call per PR and streams per-PR progress to stderr (stdout, including
  `--json`, stays clean). For a local run during a merge burst, pass
  `--cleanup-backlog-window-days 1` to keep it fast, mirroring CI.
- `scripts/helper-runtime-manifest.mjs` (`idd-helper-bundle-manifest`) —
  import helper and manifest inspector; emits machine-readable helper wiring
  for all four profiles (`package-manager`, `vendored-node`,
  `ephemeral-npx`, and `instructions-only`). Its output always carries a
  `runningBuild: { version, commandListScope: "running-build" }` field
  disclosing that `commandCatalog` describes only the currently running
  helper build, independent of any `--package-spec` target -- a per-profile
  `profiles.<profile>.commands` entry still embeds the supplied
  `--package-spec` in its composed install/invocation strings, but
  `commandCatalog` itself never changes (referenced in
  [kurone-kito/idd-skill#1923](https://github.com/kurone-kito/idd-skill/issues/1923)).
- `scripts/phase-id-resolver.mjs` (`idd-phase-id-resolver`) — phase ID
  normalization utility; resolves canonical phase IDs from aliases and
  validates token format.

### Discover Roadmap Graph Contract

`scripts/discover-roadmap-graph.mjs` evaluates the recursive A1.5/A2
roadmap graph for one selected roadmap issue. It also offers an additive
cross-roadmap autopilot discovery mode (`--all-roadmaps`) that unions the
open execution leaves across every open roadmap root; the single-root
default below is unchanged.

- **Inputs**: `--issue <number>`, with optional `--owner <owner>`,
  `--repo <repo>`, and `--policy <path>`. `--issue` and `--all-roadmaps`
  are mutually exclusive; exactly one mode must be selected. Passing both,
  or neither, is an error.
- **JSON output**:
  - `root`: `{ number: number, title: string, state: string,`
    `classification: "roadmap" | "execution", roadmapMarkerId: string }`
  - `nodes`: `[{ number: number, title: string, state: string,`
    `labels: string[], classification: "roadmap" | "execution",`
    `roadmapMarkerId: string, depth: number }]`
  - `edges`: `[{ source: number, target: number, relationship: string,`
    `evidence: string }]`
  - `provenancePaths`: `[{ target: number, path: number[] }]`
  - `roadmapNodes`: `number[]` — nested roadmap nodes discovered through
    traversal; **excludes** the root roadmap (A1 traversal entry point)
  - `executionCandidates`: `number[]`
  - `diagnostics`: `{ duplicateReferences: object[], cycles: object[],`
    `inaccessibleReferences: object[], unresolvedReferences: object[] }`
  - `summary`: `{ rootNumber: number, nodeCount: number, edgeCount: number,`
    `roadmapNodeCount: number, executionCandidateCount: number,`
    `duplicateReferenceCount: number, cycleCount: number,`
    `inaccessibleReferenceCount: number, unresolvedReferenceCount: number,`
    `maxDepth: number }`
- **Cross-roadmap autopilot mode (`--all-roadmaps`)**: discovers every
  **open** roadmap root (an open issue carrying the `roadmap` label **or**
  an `<!-- setup-windows-roadmap-id: ... -->` marker **or** a
  configured `discover.legacyRoots` issue number, deduped against the
  label/marker roots), runs the single-root enumeration above from each
  root, and returns a **union** of open execution leaves. The output
  shape differs from single-root mode:
  - `mode`: `"all-roadmaps"`
  - `roots`: `[{ number: number, title: string, state: string,`
    `roadmapMarkerId: string }]` — every open roadmap root enumerated
  - `leaves`: `[{ number: number, title: string, state: string,`
    `labels: string[], classification: "execution",`
    `roadmapMarkerId: string, autopilotSuitability: number | null,`
    `effort: "S" | "M" | "L" | null, milestone: string | null,`
    `sourceRoots: number[] }]` — the union of open execution leaves. Each
    leaf records every roadmap root it is reachable from in `sourceRoots`
    (provenance); a leaf shared by sibling epics appears **once** and is
    never double-counted. `milestone` (`#2340`) is the leaf's **open**
    milestone title, or `null` when it has no milestone, the milestone is closed,
    or the field is absent from the API response — the input to
    `discover.milestoneScope`'s A4 Step 2 tie-breaker (see
    [Discover](../.github/instructions/idd-discover.instructions.md)); this
    same field is emitted by `discover-orphan-filter.mjs`'s `orphans` /
    `routed_to_human` candidates too, though that helper does not itself
    read `discover.milestoneScope`.
  - **Opt-in leaf annotations** (additive; absent flags leave the leaf shape
    byte-stable and make no extra API call). `--with-claim-state` adds
    `activeClaim` (always an object: `{ present, stale, claimId, agentId,`
    `heartbeatOverdue }`, plus `ownedByCurrentSession` when
    `--current-claim-id` is passed) and `claimEligible: boolean` on each
    open leaf. Both `discover-roadmap-graph.mjs` and
    `discover-orphan-filter.mjs` emit this exact shape under
    `--with-claim-state`. `heartbeatOverdue` (#1433) is `true` when the
    latest valid `claimed-by`/heartbeat `created_at` is at or past the
    configured `claimTiming.heartbeatInterval` (default `PT12H`), with no
    later trusted heartbeat; `false` otherwise, including whenever
    `present` is `false`. It is **purely diagnostic**: unlike `stale`, it
    never feeds `claimEligible` or `readiness.startable` below, and it
    never changes the 12h stale-takeover threshold (this repository's
    configured `claimTiming.staleAge`; distributed default `24h`)
    (`idd-resume-stall.instructions.md` S3). `--with-readiness` adds
    `readiness: { ready: boolean, reasons: string[], authoringHeld: boolean,`
    `startable: boolean }` — the A3 startability of each open leaf (dependency
    resolution across visible `Blocked by #N` / `Depends on #N` / task-list refs
    and hidden `setup-windows-blocked-by` markers, plus
    authoring-hold), where `reasons` lists the sorted filter reasons (e.g.
    `blocked_by_open_issue:#N`) and is empty when `ready`, and `startable` is
    `ready` **and** not claim-blocked (it folds
    in `claimEligible` when `--with-claim-state` also ran; otherwise claim
    eligibility is unknown and treated as non-blocking). `authoringHeld`
    reports label **presence** only — `--with-readiness` does not compute the
    stale-authoring warning (it would cost a discarded per-leaf timeline fetch
    and does not change startability). `--with-claim-state` itself is not
    forced-handoff-aware — it intentionally excludes forced-handoff and
    legacy markers as a best-effort **soft signal**; a discovery-time survey
    across many candidates must either loop the single-issue
    `resume-claim-routing.mjs --fresh-claim-gate` resolver per candidate or
    apply `idd-claim.instructions.md`'s full parsing rules manually to catch
    a more-recent forced-handoff transfer. Both annotations are **soft**
    discovery hints — the A3/A4/A4.5/A5 gates remain authoritative.
  - `diagnostics`: same four buckets as single-root mode, deduped across
    every per-root enumeration.
  - `summary`: `{ rootCount: number, leafCount: number,`
    `scoredLeafCount: number, sharedLeafCount: number,`
    `duplicateReferenceCount: number, cycleCount: number,`
    `inaccessibleReferenceCount: number, unresolvedReferenceCount: number }`.
    Under `--with-readiness` the summary additionally carries
    `startableCount` and `readyCount` (integers aggregating the leaves'
    `readiness.startable` / `readiness.ready`), so a swarm controller reads
    "is there more startable work?" without iterating every leaf; both are
    absent otherwise so the flag-absent shape stays byte-stable.
  - **Ranking** (global-by-score): `leaves` is sorted by
    `autopilotSuitability` **descending**, then an optional
    `discover.milestoneScope` match (`#2340`), then `effort`
    **ascending** (`S` < `M` < `L`), then issue number **ascending**
    (stable). A missing or out-of-range score is treated as the
    configured suitability floor for ordering so unscored work is not
    buried, but a coherently scored leaf never ranks below an unscored leaf
    at the same effective value — scored work always sorts first at a tie.
    The score is an advisory ranking hint only; it never replaces the
    A4.5 suitability gate or the A5 claim safety checks.
- **Legacy roots (`discover.legacyRoots`, #1315)**: a repository that
  adopted IDD after already running an ad-hoc "umbrella issue"
  convention may have legacy roots that predate both the `roadmap`
  label and the `setup-windows-roadmap-id` marker, so they
  are never found by the two searches above (the graph walker still
  follows their `Blocked by #NNN` references once reached from
  elsewhere; only root _discovery_ has no path to them). Two
  independent mitigations, usable together or separately:
  - **Retro-label** the legacy umbrella with the configured roadmap
    label — the label search is exact and complete, so this alone
    makes it discoverable with no config change.
  - **`discover.legacyRoots`** in `.github/idd/config.json` — an array
    of issue numbers (schema: integers, minimum `1`) unioned into the
    root set on every `--all-roadmaps` run and deduped against the
    label/marker roots. No extra `gh` search or fetch: the configured
    numbers are added directly, and each still goes through the normal
    per-root enumeration, so a stale or now-closed configured root is
    handled the same way a race-closed label/marker root already is. A
    missing or invalid value (non-array, or any non-positive-integer
    entry) fails safe to no extra roots — the whole array is rejected
    rather than silently dropping just the bad entry.
    Use retro-labeling when the legacy umbrella should also pick up other
    label-driven behavior; use `discover.legacyRoots` when it should not
    (e.g. the label would incorrectly surface it in label-based UI
    elsewhere).
- **Error conditions**: missing `--issue` (and no `--all-roadmaps`),
  combining `--issue` with `--all-roadmaps`, unknown flags, an unreadable
  root roadmap, or incomplete `subIssues` GraphQL data throw. Missing or
  inaccessible descendants are reported in `diagnostics` instead of
  crashing.
- **Behavior boundary**: the helper is evidence-only. It may read issue
  bodies and GitHub sub-issue relationships, but it must not claim
  issues, edit roadmap bodies, close roadmap nodes, or decide readiness
  by itself.
- **Runtime / read timing**: the helper is **long-running** on large
  roadmaps — it issues many sequential API calls and emits the whole graph
  in a single final stdout write, with no progress line or completion
  sentinel. Redirect stdout to a file and wait for process exit before
  parsing; a zero-byte or partial read from a still-running (or
  just-finished) helper means **"still running," not** an A2 enumeration
  failure.

### Discover Readiness Sweep (`--swarm-floor`)

`scripts/discover-readiness-check.mjs --swarm-floor <N>` is the canonical
end-of-session "is any startable work left?" one-liner. It ignores
`--issue` / `--issues`, sweeps **every** open issue in the repository
(orphans included, pull requests excluded), runs the same A3 readiness plus
autopilot-suitability evaluation, and reports the issues that are ready
**and** at or above floor `N`:

```sh
node scripts/discover-readiness-check.mjs --swarm-floor <N>
```

- **Output**: `{ eligible, eligible_count, total }` — `eligible` is the
  ready-and-at/above-floor set (each `{ number, title, autopilotSuitability,
  belowFloor }`), `eligible_count` its length, and `total` the number of open
  issues swept. A "no score" issue is never below floor, matching the
  discovery ranker, so it stays eligible.
- **Use**: an `eligible_count == 0` result means Discover has no startable
  work at floor `N`, so an autopilot / swarm loop may stop scriptably.
- **Floor range**: `N` is the autopilot-suitability 1-5 band. A non-integer
  or out-of-range `N` is a **hard error**, not a silent coercion to the
  default floor — otherwise a typo (e.g. `--swarm-floor 50`) would quietly
  answer at floor 3 and be misread as "floor-50 work exists."
- **Boundary**: read-only and advisory — selecting the next issue still runs
  the A3/A4/A4.5/A5 gates. Optional flags: `--owner` / `--repo` / `--policy`
  / `--now`.
- **kurone-kito/idd-skill#2243 triage-verdict cost note**: the default-on
  triage-verdict exclusion (see the `discover-readiness-check.mjs` bullet
  above) runs for every candidate every cheaper check already lets
  through, so a full repo-wide `--swarm-floor` sweep makes one extra
  comments-plus-timeline API call pair per otherwise-ready candidate, not
  just per swept issue.

### Discover Viability Gate Contract

`scripts/discover-viability-gate.mjs` evaluates the A4 viability gate for
one or more issues.

- **Inputs**: `--issue <number>` (repeatable) or `--issues <n1,n2,...>`,
  with optional `--csv`, `--owner <owner>`, and `--repo <repo>`.
- **JSON output**:
  - `viable`: `[{ number: number, title: string, criteria?: [{ id: string,`
    `name: string, result: "pass" | "warn" | "fail", evidence: string }] }]`
    -- `criteria` is present only when at least one criterion was
    structural-evidence-**demoted** (`#2767`: a lexical `fail` that all
    three structural signals -- `verificationCommand`,
    `candidateFilesExist`, `trustedEditor` -- demote to a `warn`-annotated
    pass); an ordinary fully-passed issue keeps the pre-`#2767` two-field
    shape, `criteria` omitted entirely, not an empty array.
  - `discarded`: `[{ number: number, title: string,`
    `failedCriteria: string[], criteria?: [{ id: string, name: string,`
    `result: "pass" | "warn" | "fail", evidence: string }] }]`
  - `summary`: `{ total: number, viableCount: number,`
    `discardedCount: number, discardedByCriterion: Record<string, number> }`
- **Error conditions**: missing issue arguments or unknown flags throw;
  loader or GitHub failures surface as errors; not-found or non-open
  issues are reported in `discarded` with `failedCriteria` instead of
  crashing.
- **Example**:

  ```json
  {
    "viable": [
      { "number": 123, "title": "trim helper docs" },
      {
        "number": 125,
        "title": "add retry to flaky helper",
        "criteria": [
          {
            "id": "limited_scope",
            "name": "Limited scope",
            "result": "warn",
            "evidence": "Structural evidence (verification command, candidate file, trusted editor) demotes an otherwise-failing lexical scan."
          }
        ]
      }
    ],
    "discarded": [{ "number": 124, "title": "rewrite workflow", "failedCriteria": ["limited_scope", "autonomous_completion"] }],
    "summary": { "total": 3, "viableCount": 2, "discardedCount": 1, "discardedByCriterion": { "limited_scope": 1, "autonomous_completion": 1 } }
  }
  ```

### Discover Shared File Overlap Contract

`scripts/discover-shared-file-overlap.mjs` is the read-only file-contention
companion to the `discover-roadmap-graph` `--with-claim-state` claim-eligibility
annotation. For a set of candidate issues it reports the high-contention shared
files each would touch (parsed from its `## Candidate files` section) and
whether any overlap an actively-claimed or open-PR issue, and it emits the soft
A4 Step 2 de-prioritization order. Evidence-only: it claims nothing.

- **Inputs**: `--candidate <number>` (repeatable) or `--candidates <n1,n2>`,
  with optional `--owner <owner>`, `--repo <repo>`, `--policy <path>`,
  `--manifest <path>` (default `audit/sync-manifest.json`), `--bundles
  <id1,id2,...>` (default
  `bundle-core,bundle-review-triage-phase,bundle-review-fix-phase,bundle-merge-phase`),
  `--now <ISO8601>`, and
  `--check-overlap`. The cross-issue active-set discovery (open PRs plus the
  claim comments of issues that have a remote `issue/<n>-*` branch, resolved
  with the shared claim-state rules and the configured claim stale age) is
  **gated behind `--check-overlap`** because it adds GitHub API cost; without it
  each candidate's high-contention files are still reported. **Coverage**
  (best-effort, no repo-wide comment scan): open-PR overlap scans open PRs
  (bounded by the `gh pr list` page cap); active-claim overlap covers every
  issue that has a remote `issue/<n>-*` branch (every IDD claim creates one once
  pushed, paginated to the end), so a non-stale claim held by another session is
  detected even when it is outside the unclaimed candidate set being ranked. A
  claim whose branch is not yet pushed is picked up once it appears remotely.
- **High-contention set**: the union of the named bundles' member files plus
  `audit/sync-manifest.json`. Instruction files are keyed by their repo-wide
  unique basename so a source path, mirror path, or bare citation all match.
- **JSON output**:
  - `repository`: `{ owner: string, repo: string }`
  - `checkedOverlap`: `boolean`
  - `manifestMissing`: `boolean` — `true` when `--manifest`'s target file does
    not exist (`ENOENT`); the CLI still exits 0, with `highContentionFiles`
    reported as an empty set rather than fabricated from the manifest path
    itself. A manifest that fails to parse (invalid JSON syntax) keeps the
    prior fail-closed behavior (the CLI throws), unchanged. A manifest that
    parses but has an unexpected shape (e.g. `{}`, a non-array
    `bundleBudgets`) is not validated here — `resolveHighContentionFiles`
    silently treats it as contributing no bundle files, a pre-existing
    behavior this change does not alter.
  - `highContentionFiles`: `string[]` (sorted)
  - `candidates`: `[{ number: number, score: number | null,`
    `effectiveScore: number, candidateFiles: string[],`
    `highContentionTouched: string[], overlaps: [{ number: number,`
    `reason: "claim" | "pr", files: string[] }], overlapFlag: boolean }]`
  - `recommendedOrder`: `number[]` — candidate numbers after the soft
    tie-breaker (score desc, then non-overlapping first within a score band,
    then issue number). It does **not** apply `discover.selectionDesync`; the
    agent layers the overlap nudge after its own desync pick. Advisory only;
    never a hard gate.
  - `summary`: `{ candidateCount: number, flaggedCount: number,`
    `activeIssueCount: number }`
- **Behavior boundary**: evidence-only and heuristic. `## Candidate files` are
  advisory cues, not an exhaustive manifest, so the overlap signal must stay a
  soft A4 Step 2 tie-breaker — never a claim gate. The written discover
  instructions remain authoritative. A candidate whose issue body carries no
  `## Candidate files` section is a structural no-op for this check —
  `candidateFiles` comes back `[]` and `overlapFlag` comes back `false`
  regardless of real file contention, not a signal that no contention exists
  (`#2462`); the
  `issue-authoring` skill's roadmap-child contract requires the section for
  exactly this reason.

The exported template remains portable without a `scripts/` directory.
Adopters can copy the helper separately when they want the same
repository-local convenience, otherwise the documented GraphQL fallback
remains the portable path.

Absent helper runtime configuration means `instructions-only`. Repositories
that do not opt into helper support should still be able to copy the
Markdown instructions, run the portable shell / `gh` / `jq` procedures,
and complete the workflow without a Node.js dependency.

## Helper Runtime Profiles

When a repository imports the IDD template, helper support should be
selected from one of these profiles:

| Profile             | Intended use                                                                                                                | Dependency model                                                               | Portability expectation                                                                                                                 |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------- |
| `package-manager`   | The adopter already uses pnpm, npm, or yarn for the repository.                                                             | Reuse the repository's existing package manager and pre-resolved dependencies. | Preferred when a package manager project already exists; do not fall back to ad hoc `npx` in this mode.                                 |
| `vendored-node`     | The adopter has Node.js available but does not want helper execution to depend on registry resolution at runtime.           | Copy a local helper bundle into the repository during import.                  | Keeps helper execution repository-local while remaining optional.                                                                       |
| `ephemeral-npx`     | The adopter has Node.js available, does not vend helper files, and can resolve a runnable helper command at execution time. | Resolve helper execution through one-shot `npx` commands.                      | Reserved for cases where a published or otherwise resolvable helper command already exists; otherwise fall back to `instructions-only`. |
| `instructions-only` | The adopter does not want or cannot use helper scripts.                                                                     | No helper runtime. Agents follow the Markdown instructions directly.           | First-class supported fallback; no helper config is required.                                                                           |

## Import-Time Selection Order

Helper runtime choice is an import-time policy decision. Use repository
evidence to decide whether helper support should be proposed for
operator confirmation. If helper support is not confirmed, keep
`instructions-only`.

1. If supported `packageManager` metadata or exactly one supported
   lockfile is present, propose `package-manager`.
2. Otherwise, if Node.js is available and the import flow is allowed to
   copy helper files, propose `vendored-node`.
3. Otherwise, if Node.js is available and a published or otherwise
   resolvable helper command exists for one-shot execution, propose
   `ephemeral-npx`.
4. Otherwise, use `instructions-only`.

This selection order exists to keep helper support optional without
turning every adopter into a Node.js-first repository. The written
decision tables remain the canonical protocol regardless of which helper
profile is selected.

### Practical footprint guidance

Practical loop pressure depends on the helper runtime choice:

- Prefer helper runtime support when you want lower day-to-day
  context pressure in the E/F phases: helper commands collect
  evidence, while merge and mutation decisions still follow the
  written gates.
- Keep `instructions-only` when your repository avoids Node.js or
  helper tooling, or your team prefers a fully manual
  shell/`gh`/`jq` path.
- Expect variance either way: local policy additions, local docs, and
  extra repository instructions can make your practical footprint
  smaller or larger than the idd-skill source repository.

## Profile Wiring Surface

Use `idd-helper-bundle-manifest` as the canonical import helper for these
profiles. It is published from this source repository as both
`scripts/helper-runtime-manifest.mjs` and the package bin
`idd-helper-bundle-manifest`, so adopters can inspect one machine-readable
manifest instead of hand-maintaining helper file lists. The manifest's
top-level `recommendation` field uses the same package-manager evidence
class as onboarding: supported `packageManager` metadata or exactly one
supported lockfile can recommend `package-manager`; ambiguous
package-manager signals can still recommend `vendored-node`; otherwise
it stays fail-closed at `instructions-only` and never treats bare
`package.json` presence as enough evidence to assume npm or a real
Node.js helper path.

- `package-manager`: run the manifest from the target repository root and
  let it detect npm, pnpm, or yarn (or pass `--package-manager` if
  detection is ambiguous). The output includes the package-manager
  install command, the `@kurone-kito/idd-skill` helper dependency, and a
  `package.json` scripts block that calls stable `idd-*` bins without
  assuming pnpm.
- `vendored-node`: use the manifest's `managedFiles` list to copy the
  helper bundle into matching paths in the target repository, then run
  the emitted local `node scripts/...` commands. The profile output also
  carries a `recommendedGitattributes` list — one
  `<path> linguist-vendored` line per managed file — to append to the
  adopter's `.gitattributes`, so the vendored bundle is treated as the
  third-party code it is: `linguist-vendored` drops it from language
  statistics and de-prioritizes it in code search. This is the
  adopter-side counterpart of the source repository's own
  `linguist-generated` artifacts; only `vendored-node` vends files, so
  only it emits the recommendation.
- `ephemeral-npx`: use the manifest's one-shot `npx --yes --package
  <helper-package-spec> idd-*` commands without copying helper files
  into the repository. The default helper package spec is an HTTPS
  archive URL, and `--package-spec` lets adopters pin a reviewed tarball
  or mirror URL explicitly. Persist that same pin in
  `.github/idd/config.json` as the optional `helperRuntime.packageSpec`
  field so it is reflected consistently in every helper-emitted
  `ephemeral-npx` invocation string (including the manifest CLI's own
  default and idd-doctor's remediation hints), not only a one-shot
  `--package-spec` flag on a single invocation. An explicit
  `--package-spec` flag still wins over the configured value when both
  are present.
- `instructions-only`: keep helper dependencies, helper files, and helper
  wrapper scripts out of the target repository entirely.

**Authoritative invocation surface per profile.** Under `vendored-node`, the
canonical invocation is `node scripts/<name>.mjs`; the `package-manager` / `npx`
`bin/` facade (the `idd-*` bin wrappers) is **redundant** in this profile and
may be skipped — keeping it only adds a second surface to align with the
instruction files for no portability gain. Under `package-manager` and
`ephemeral-npx`, the `bin/` facade (`idd-*` bins, invoked through the
`package.json` scripts or `npx`) **is** the authoritative surface and should be
retained. `instructions-only` uses neither. When an instruction shows a
`node scripts/...` command, resolve it to your profile's authoritative surface
rather than maintaining both.

**Authoring rule for instructions/docs.** A mandatory helper step (one
with no skip/fallback wording) must always name an `instructions-only`
fallback, since that profile has no helper runtime at all. Every helper
invocation written into `.github/instructions/**`, `docs/**`, or their
`idd-template/` sources must use a form the `helper-runtime-manifest`
command table actually produces for some profile — `node
scripts/<name>.mjs`, a `package.json` `idd:<name>` script, or the
`idd-<name>` bin command. Separately, a file that is itself part of the
distributed template (anything under `idd-template/`, or a generated
copy of it — see `resolveDistributedFiles()` in
`tests/helper-invocation-profile.test.mts`) must never prescribe the
source repository's own `bin/<name>.mjs` build-artifact path, which no
adopter profile vends; a source-repo-only page (no `idd-template/`
counterpart) may still discuss that path when its subject genuinely is
this repository's own tooling.
`tests/helper-invocation-profile.test.mts` enforces both rules
mechanically.

To switch profiles later, rerun the manifest with both
`--profile <target-profile>` and `--from-profile <current-profile>`. The
switch section reports the files, dependency entries, and `package.json`
scripts to add or remove for that transition.

The adopted helper boundaries are intentionally narrow:

- `claim-approval-gate.mjs` is read-only, evaluates only the A5(a)
  issue-author approval gate, and emits machine-readable approval
  evidence
- it resolves collaborator permission, ready-label freshness, and
  approval-comment freshness under repository policy, then fails closed
  when ambiguity remains
- it does not claim issues, inspect A5(d) open-PR conflicts, or bypass
  the written claim rules; live PR conflict checks remain manual until a
  stable contract can cover inheritable-branch and linked-issue
  exceptions

- `force-handoff.mjs` is intentionally operator-facing and interactive;
  it asks for the issue number before any mutation, derives whether PR
  input is required from live open PR state on the active claim branch,
  previews the generated marker and successor IDs, and posts only after
  an explicit `y` confirmation
- it must fail closed outside a TTY and is not available to autopilot
  or unattended agent contexts
- it does not replace the forced-handoff policy contract; it is the
  recommended maintainer workflow for producing canonical evidence under
  that contract

- `forced-handoff-marker.mjs` is a lower-level render and inspection
  helper that can plan or emit the canonical marker body for a specific
  issue, claim, branch, and optional PR context
- it is useful for audited debugging and manual inspection, but normal
  maintainer recovery should prefer `idd-force-handoff`
- it does not authorize handoff on its own; the same human-gated policy
  and live-claim validation rules still apply

- `review-activity-snapshot.mjs` is read-only, emits machine-readable
  metrics, and does not evaluate accept/reject dispositions or merge
  decisions
- it does not replace the E/F gate decision tables; it only reduces
  command-copy variance when collecting canonical snapshot fields

- `advisory-wait-state.mjs` is read-only, emits machine-readable AW1-AW3
  evidence plus the computed AW outcome, and never requests reviewers,
  posts markers, or mutates PR state
- it does not replace the advisory-wait decision table; it only reduces
  command-copy variance when collecting canonical AW evidence

- `ci-wait-policy.mjs` is read-only, resolves `ciWait.*` defaults from
  `.github/idd/config.json`, and can evaluate whether the current rerun
  count still permits an automatic rerun
- `--run-id <run-id>` (with `--owner`/`--repo`, defaulting to the local
  checkout's own repository) derives that rerun count mechanically from
  the live run's `run_attempt` field via `gh api
  repos/{owner}/{repo}/actions/runs/{run-id}`, the same pattern
  `rerun-advisory-convergence.mjs` already uses for its own budget check
  — preferred over passing `--rerun-count` by hand, since `run_attempt`
  is live GitHub state and cross-session-safe by construction; `--rerun-count`
  keeps working unchanged when `--run-id` is omitted, and serves as an
  explicit fallback when the `--run-id` lookup fails
- it does not poll CI, rerun workflows, or replace the CI decision
  table; it only reduces config-copy variance when callers need the
  shared CI wait defaults

- `pre-merge-readiness.mjs` is read-only, emits machine-readable F2/F3
  evidence including review currency, unresolved-thread state,
  unreplied comments, reviewer states, advisory state, CI, claim
  validation, and `waiverEvidence` (parsed external-check waiver comments
  classified as `valid`, `expired`, `wrongHead`, `wrongClaim`,
  `unauthorized`, `malformed`, `notConfigured`, or `modeDisabled` —
  `notConfigured` for a valid waiver naming a check the policy never
  declared waivable in `ciGate.externalChecks.waivable`, `modeDisabled`
  (`#2046`) for an otherwise-valid, configured-waivable waiver while
  `ciGate.externalCheckWaivers.mode` is not `maintainer-authorized`
  (schema default: `disabled`) — mirroring `advisory-convergence.mjs`'s
  own mode guard, so a `waivable` list left over from a prior
  `maintainer-authorized` configuration can never make this gate report
  a check covered on its own; only a `valid` waiver for a
  configured-waivable check is reported with `coveredByWaiver: true` and
  treated as passing by the CI gate)
- (`#2021`) a `valid` waiver for the `idd-advisory-convergence` selector
  specifically only becomes `coveredByWaiver: true` once the SAME
  deadline/terminal precondition `advisory-convergence.mjs`'s own gate
  enforces has also opened — a 24h deadline anchored on the current HEAD
  commit's own `committedDate`, or proven terminal Copilot
  unavailability. The output's `advisoryConvergenceWaiverPrecondition`
  field always reports this evaluation (`deadlineMinutes`,
  `headCommittedAt`, `elapsedMinutes`, `deadlinePassed`,
  `terminalUnavailable`, `open`), so an agent never has to re-derive the
  remaining time-to-deadline by hand when a `ci` blocker cites a posted
  but not-yet-active waiver
- (preventive; no observed incident yet — `#2034`) each
  `waiverEvidence.valid` entry now also carries the waiver comment's
  own `createdAt` (`'none'` when unparseable, which fails closed). A
  matched check only becomes `coveredByWaiver: true`
  once its own live run's `completedAt` is at or after the moment the
  waiver became genuinely active — the waiver's `createdAt` alone for
  a generic waivable check. For `idd-advisory-convergence`
  specifically, that moment is the later of the waiver's `createdAt`
  and the `#2021` deadline precondition-open moment when the
  precondition opened via the 24h deadline (a real, computable
  timestamp); when it opened via proven terminal Copilot
  unavailability instead, there is no equivalent timestamp to compare
  against, so the cutoff there is the waiver's `createdAt` alone, same
  as the generic case. A check whose live run last completed before
  its applicable cutoff stays reported as blocked even though a
  `valid` waiver marker exists, since it was never actually re-run
  since the waiver took effect — mirroring
  `idd-advisory-wait.instructions.md`'s Terminal-routing guidance to
  rerun the check after posting a waiver, instead of leaving that as
  an unenforced manual step. When this is what withholds coverage for
  `idd-advisory-convergence`, the `ci` blocker's detail names the
  stale run's `completedAt` and the waiver's own `createdAt`
- it does not replace the pre-merge or merge decision tables; it only
  reduces command-copy variance when collecting canonical merge-gate
  evidence

- `idd-merge-execute.mjs` defaults to dry-run and stays read-only in
  that mode: it reuses `pre-merge-readiness` to evaluate the F3 gates and
  prints `{ ready, blockers, mergeCommand }` without merging
- apply mode (`--apply`) is the only mutating path: when `ready` it
  re-fetches the head SHA and re-validates the claim immediately before
  merging, fails closed (no merge) on head drift or lost claim, and runs
  a merge commit bound to the validated head — never squash or rebase
- it adds no new decision authority (`decisionAuthority: instructions`):
  it does not replace the written F3 gate checklist or decision table,
  and on any helper failure or evidence conflict the agent falls back to
  the manual F3 steps

- `live-status-digest.mjs` defaults to dry-run, supports issue and PR
  targets, and mutates only with explicit `--apply`
- apply mode re-validates an active claim unless a maintainer explicitly
  uses `--skip-claim-check`
- it creates or updates only the single current digest comment and
  refuses duplicate marked digests with repair URLs instead of choosing
  one, deleting, or minimizing audit history
- digest text remains non-authoritative UI state; phase decisions still
  come from trusted markers and GitHub state

- `audit-pr-cleanup.mjs` defaults to dry-run and prints stable JSON
  unless `--format table` is requested
- apply mode is explicit and can re-validate an active claim before
  every minimization mutation
- known review-bot regular comments are considered only after merge and
  only when they match a completed-review or stale-notification signal
- cleanup remains best-effort and never becomes a merge gate
- direct GraphQL fallback commands remain documented in
  `docs/idd-comment-minimization.md`

- `review-disposition-verify.mjs` is read-only, takes a JSON array of
  ReviewItems_snapshot items, and emits per-item verification evidence
- it checks E7 disposition requirements: decision recorded, marker
  present and matching, and thread resolution correct per path and type
- it never posts replies, resolves threads, or mutates any GitHub state
- thread-resolution checks are gated on `type === "review_thread"`;
  non-thread items must have `threadResolved: null`, not `true`/`false`
- PATH A AMD items must have the thread unresolved; PATH A Rejected and
  PATH B items must have review threads resolved
- PATH A Accepted items pass without a marker (reply is handled in
  review-fix, not triage)
- written E7 rules in `idd-review-triage.instructions.md` remain
  authoritative; this helper only reduces command-copy variance when
  confirming marker presence before triage exits

### Non-review-notice disposition (E6 helper-first)

- Command:
  `node scripts/disposition-non-review-notices.mjs --pr <number>`
  (dry-run); add `--apply --claim-issue <n> --claim-id <id>` to post.
  Pass `--advisory-bot-logins` / `--trusted-marker-logins` to override the
  defaults.
- A rate-limit/usage-limit notice this helper dispositions can coexist
  with a passing GitHub _check_ from the same bot -- the check is a
  liveness signal only, not confirmation of a genuine review against
  current HEAD;
  see [re-trigger guidance](policy-constants.md#advisory-review-defaults)
  (#2466).
- Detects advisory-bot regular comments that the single-sourced
  `isAdvisoryNonReviewNotice` classifier (`protocol-helpers`) recognizes
  (rate-limit / usage-limit), and emits / posts the canonical
  `**Rejected** — {bot-login} did not review HEAD {sha} ({reason}); this
  is not a completed review (source: #issuecomment-{id})` —
  marker-first, one comment per notice, naming the bot login so the
  carry-forward attributes it author-scoped. The trailing
  `(source: #issuecomment-{id})` names the source notice's own comment id
  so repeat notices from the same bot at the same HEAD stay
  byte-distinguishable (#1482); it is a human-readable disambiguator only
  and plays no part in gate recognition or pairing.
- **Idempotent**: per advisory bot, existing trusted
  `isNonReviewNoticeDisposition` comments naming that bot already cover
  that many of its notices, so a re-run posts nothing new.
- **CodeRabbit summary walkthrough (#1122)**: it also auto-posts a
  marker-first `**Accepted** — {bot-login} summary walkthrough at HEAD
  {sha} …` for the CodeRabbit summary marker
  (`<!-- This is an auto-generated comment: summarize by coderabbit.ai -->`),
  which the gate scores through its general updatedAt-aware pairing rather
  than the notice carry-forward. Because CodeRabbit edits the summary on each
  re-review, the acceptance is re-dispositioned **per HEAD** by timestamp
  (skipped only while a trusted acceptance naming the bot is strictly newer
  than the summary's activity and no older undispositioned non-agent comment
  could consume it under the gate's global pairing), and is skipped outright
  when CodeRabbit
  already reports "No actionable comments were generated" (the gate classifies
  that RESOLVED). It never resolves a review thread — actionable findings stay
  their own threads, gated independently. The body names the bot by its login
  (never the standalone word "CodeRabbit") so per-HEAD re-disposition is
  preserved.
- **Fail-closed**: only classifier-recognized notices are dispositioned;
  real reviews and review threads are never touched. `--apply`
  re-validates the active claim and retries once on a transient post
  failure.
- Stable contract: [`disposition-non-review-notices.schema.json`][disposition-non-review-notices-schema].
- The written E6 non-review-notice rule in
  `idd-review-triage.instructions.md` stays authoritative; this helper is
  the helper-first convenience path with the manual `gh api` fallback
  retained.

### E13 reply-and-resolve (resolve-review-thread)

- Command:
  `node scripts/resolve-review-thread.mjs --pr <number> --comment-id <id>`
  (dry-run); add `--body "<disposition>" --apply --claim-issue <n>
  --claim-id <id>` to post the reply and resolve the thread. Optional
  `--owner` / `--repo` / `--agent-id` / `--trusted-marker-logins`. For a
  claimless PR (`closingIssuesReferences` empty), pass `--claimless`
  instead of `--claim-issue`/`--claim-id` (#2616, mirrors
  `pre-merge-readiness.mjs`'s `--claimless`, #2017).
- Maps `--comment-id` (the review comment's REST id) to its owning review
  thread by matching it against the `databaseId` of the comments inside each
  GraphQL `reviewThreads` node (both the threads and the nested comments
  connections are paginated to completion), then in
  `--apply` posts the reply against the thread's **top-level** comment (REST
  `pulls/.../comments/{root-id}/replies` — GitHub does not support replies to
  replies, so a `--comment-id` naming a later reply still resolves the right
  thread) and resolves the thread (GraphQL `resolveReviewThread`). Reply
  first, resolve second, so a failed reply never resolves the thread without a
  disposition.
- **`--apply` appends the reply-identity stamp**
  `<!-- {markerPrefix}-review-reply -->` after the visible
  `**Accepted**` / `**Rejected**` body (same injection as
  `disposition-non-review-notices --apply`). A manual `gh api` JSON
  body must append that stamp itself. The stamp is utterance
  identity; it is not an E1 `review-watermark`. See
  [Hybrid review-reply identity](idd-review-policy-profiles.md#hybrid-review-reply-identity-shipped).
- **Dry-run** reports the resolved `threadId` and current `alreadyResolved`
  state without posting; a comment with no owning thread omits `threadId`
  and includes an `error` note.
- **Fail-closed**: `--apply` requires `--body` and, unless `--claimless`,
  the `--claim-issue` / `--claim-id` pair; absent `--claimless` it
  re-validates the active claim before **each** of the reply and the
  resolve (scoped to trusted marker authors, aborting on a targeting
  `forced-handoff`), and binds the mutation to the claimed PR by requiring
  the active claim's branch to equal the PR's head branch. `--claimless`
  itself fails closed against a non-empty `closingIssuesReferences`.
  GraphQL `errors` fail fast rather than masquerading as a missing thread,
  and a partial apply (reply posted, resolve not confirmed) still reports
  the posted `replyId`.
- Stable contract: [`resolve-review-thread.schema.json`][resolve-review-thread-schema].
- The written E13 reply-and-resolve rule in
  `idd-review-fix.instructions.md` stays authoritative; this helper is the
  helper-first convenience path with the manual REST + GraphQL fallback
  retained.

## Stable Helper Evidence Outputs

### Operator forced-handoff helpers

- Command: `node scripts/force-handoff.mjs`
- Published bin: `idd-force-handoff`
- Contract:
  - interactive TTY only
  - asks for issue input before any mutation
  - asks for PR input only when a live open PR exists on the active
    claim branch and PR-scoped evidence is required
  - prints the generated successor IDs and marker preview before the
    final confirmation
  - posts nothing unless the final confirmation is exactly `y`

- Command: `node scripts/forced-handoff-marker.mjs --issue <number> --plan ...`
- Published bin: `idd-forced-handoff-marker`
- Stable contract:
  [`forced-handoff-marker.schema.json`][forced-handoff-marker-schema]
- Intended use:
  - render or inspect canonical forced-handoff marker payloads
  - support audited debugging or manual review of the exact body
  - stay distinct from the interactive operator facade above

The references in this subsection apply only when a repository
explicitly installs the matching helpers and records a human-gated
forced-handoff policy. Repositories that stay on the default disabled
policy must not expose either helper as an active recovery path.

The references in this section apply only when a repository explicitly
installs the matching helper scripts. Repositories that stay on the
default `instructions-only` profile keep using the written shell /
`gh` / `jq` procedures in the phase instructions and do not need a
`scripts/` directory.

### External-check waiver helper

- Command:
  `node scripts/external-check-waiver.mjs --pr <number> --check
  <selector> --reason <text> (--expires <iso8601> | --expires-in
  <duration>)`
- Published bin: `idd-external-check-waiver`
- Contract:
  - dry-run is the default; the helper prints the canonical comment body
    plus claim/check/authority evidence before any mutation
  - in normal mode, `--apply` posts the PR comment only after verifying
    the linked issue's active claim, the current PR HEAD SHA, the live
    check state, waivable-selector coverage, and maintainer/admin
    authority
  - non-interactive apply is refused unless `--yes` is provided after a
    prior dry-run review; interactive TTY runs may confirm with `y/N`
  - the helper fails closed when authority cannot distinguish owner,
    Maintain, or Admin from plain Write access, when the requested check
    is not configured in `ciGate.externalChecks.waivable`, or when the
    expiry exceeds `ciGate.externalCheckWaivers.maxValidity`
  - `--claimless` (#1905) mode renders a claimless waiver -- literal
    claim-id `none` -- instead of resolving a linked issue's active
    claim; use it for a PR with no IDD claim at all (an automated
    dependency-update PR such as Dependabot, Renovate, or ImgBot).
    Cannot combine with `--issue` or `--claim-id`. In this mode,
    `--apply` verifies that no active claim resolves for the PR instead
    of resolving one, while still applying the same HEAD, live-check,
    selector, expiry, and authority checks as normal mode -- the helper
    blocks with a clear reason if the PR turns out to have a resolvable
    active claim after all, since a `none` waiver only ever satisfies
    the consumer-side gate (`summarizeExternalCheckWaivers` in
    `protocol-helpers.mts`) when no claim resolves there, so posting one
    against a claimed PR would just be rejected `wrongClaim`.
  - for the `idd-advisory-convergence` selector specifically (#2328), the
    report carries `advisoryConvergenceWaiverPrecondition`, built by the
    same shared function `pre-merge-readiness` publishes it from, and a
    closed hatch is a blocking reason. That check never treats a posted
    waiver as active until its precondition opens, so posting one earlier
    produces a marker the gate ignores. Only the exact selector is gated:
    the gate itself never counts a glob waiver for this check either.
  - the helper evaluates only the **deadline** opener, never terminal
    Copilot unavailability, which needs trusted advisory-wait
    recovery-marker state it does not collect. The report says so with
    `terminalEvaluated: false`, and the blocking reason states that the
    deadline has not passed rather than claiming no opener applies.
    `--allow-closed-precondition` posts anyway, for an operator who knows
    the terminal opener does apply; the precondition is still reported as
    closed, so the override is visible in the output.
  - the deadline itself is read from the **raw** policy document, not the
    normalized one: `normalizePolicyConfig` does not carry
    `advisoryWait.convergenceDeadline` through, so reading it from the
    normalized policy would silently substitute the 24h default for a
    repository that configured something shorter.
  - `--apply` is idempotent (#2328): it reuses an existing valid waiver
    for the same selector, HEAD, and claim instead of appending a second
    marker, reporting `reusedWaiver` with that comment's id and url and
    posting nothing. The earliest match wins, so a retry converges on one
    marker. Validity comes from `summarizeExternalCheckWaivers`, so an
    expired, wrong-HEAD, or wrong-claim waiver is never reused. Reuse wins
    over a freshly requested expiry: re-running with a different
    `--expires-in` reports the existing marker rather than posting a second
    one carrying the new value, matching the release-marker rule that a
    retry must never append an indistinguishable duplicate. To change an
    expiry, let the existing waiver lapse or supersede it deliberately.
  - the reuse check and the post are **not** one atomic step, and GitHub
    comments have no compare-and-swap -- the same limitation the claim
    protocol records for its own markers. Two concurrent `--apply` runs
    can therefore both observe no waiver and both post. That is reconciled
    after the fact rather than prevented: the helper re-reads once the post
    lands, and when more than one valid waiver exists for the selector it
    reports them all in `concurrentWaivers`, warns on stderr, and names the
    earliest, which is the one a deterministic reader resolves to. It does
    not delete the extras -- removing a marker another session just posted
    is a maintainer's call, not the helper's -- so minimize them by hand.
    That post-write read degrades to a warning rather than failing closed:
    the waiver already exists and the write cannot be undone, so a read
    failure reports `reconcileInconclusive` and still renders the applied
    result with its comment url. Only the pre-write read fails closed, where
    an unreadable list could actually cause the duplicate.

### External-check waiver contract

Issue `#666` defines the policy and marker contract before the operator
facade and F-phase consumer land. The contract is intentionally
auditable and fail-closed.

```md
<!-- idd-external-check-waiver: {agent-id} {claim-id|none} {head-sha} check:{check-selector} reason:{reason-token} expires:{iso8601} -->

_{actor}: external check waiver for IDD F phase._
```

`run-id:{run-id}` is an optional trailing field (kurone-kito/idd-skill#2657,
Copilot review PR #2895: shown as its own separate extended form below, so
neither snippet reads as though the field were required):

```md
<!-- idd-external-check-waiver: {agent-id} {claim-id|none} {head-sha} check:{check-selector} reason:{reason-token} expires:{iso8601} run-id:{run-id} -->

_{actor}: external check waiver for IDD F phase._
```

the posting GitHub Actions run's own `GITHUB_RUN_ID`, carried verbatim (not
percent-encoded -- it is a numeric run id, not free text). Every
person-authored waiver omits it and parses exactly as before this field
existed; it exists only for the automated `self-referential-bootstrap-auto`
waiver kind below.

Interpretation rules:

- `agent-id`, `claim-id`, `head-sha`, `check`, `reason`, and `expires`
  come from the marker body.
- The issuer is the GitHub comment author and the issued timestamp is
  the comment `created_at`. Do not duplicate either field inside the
  marker body.
- `check` may be an exact selector or a glob pattern, matching the
  `ciGate.externalChecks.*[].selector` plus `matchMode` contract.
- `check:` and `reason:` hold single whitespace-free tokens in the raw
  marker body: the authoring helper percent-encodes the check selector
  and reason text with `encodeURIComponent` when writing the marker,
  and decodes them back via `decodeURIComponent` on read (falling back
  to an empty string -- which fails closed -- on a decode error). A
  hand-written value containing a space or another character outside
  the `check:\S+`/`reason:\S+` shape parses as malformed with no
  automatic warning or reply unless percent-encoded first (a space
  becomes `%20`); prefer the authoring helper below over hand-writing
  the marker so this encoding is applied automatically.
- Missing or unparseable body fields, unknown selectors, expired
  comments, wrong HEAD, wrong claim, or untrusted authors must fail
  closed.
- `claim-id` accepts the case-insensitive literal sentinel `none`
  (#1905) alongside an arbitrary claim id, declaring a deliberately
  claimless waiver. It satisfies the claim-binding check only when the
  gate independently confirms no claim resolves for the PR (an empty
  active claim id) -- on a PR with a resolvable active claim, `none` is
  never accepted and still fails closed to the same wrong-claim
  rejection as any other mismatched claim id; this never weakens the
  #1077 fail-closed-on-empty-claim guarantee for a non-`none` claim id.
- A valid waiver can apply only to checks listed in
  `ciGate.externalChecks.waivable` and only when
  `ciGate.externalCheckWaivers.mode` enables maintainer authorization.
- Repo-owned required checks and GitHub-required checks remain
  non-waivable at the contract layer. An IDD waiver never substitutes
  for GitHub ruleset bypass.
- When the optional facade is installed, prefer helper-first usage:
  - dry-run:

    ```sh
    idd-external-check-waiver --pr 123 \
      --check "CodeRabbit" \
      --reason "rate limit" \
      --expires-in PT2H
    ```

  - apply after review:

    ```sh
    idd-external-check-waiver --pr 123 \
      --check "CodeRabbit" \
      --reason "rate limit" \
      --expires-in PT2H \
      --apply --yes
    ```

  - claimless PR (dry-run), e.g. a Dependabot PR with no IDD claim whose
    primary-bot review never lands (observed 2026-08-05, #1904 -- 1 of
    18 sampled `dependabot[bot]`-authored pull requests in this
    repository's own history ever received a Copilot review):

    ```sh
    idd-external-check-waiver --pr 123 \
      --claimless \
      --check "idd-advisory-convergence" \
      --reason "Dependabot PR, Copilot review never lands" \
      --expires-in PT2H
    ```

  - inspect the rendered body first; do not hand-write or copy raw
    marker comments into the PR
  - in solo-maintainer repositories, this helper-generated comment is
    the authorization path; a normal PR approval is not equivalent

#### Automated self-referential-bootstrap-auto waiver (kurone-kito/idd-skill#2657)

A narrow, documented exception to "human maintainer only" above: when a
PR's own diff touches `idd-advisory-convergence`'s committed trigger-file
allowlist (the check's own source, its policy inputs, or its workflow
files -- a fixed, committed set of paths, never derived from imports),
that PR cannot benefit from its own fix to the checker while still
unmerged. This source repository's own copy of the allowlist -- checked
both by its own top-level workflow's posting step and, at consume time,
by `resolveSelfReferentialTriggerFiles` recognizing this exact
repository -- lists a hand-curated set of `.mts`/workflow paths, its real
checker files, regardless of its own configured `helperRuntime.profile`
(`package-manager`, chosen for its own IDD dependency, unrelated to this
workflow's own file layout). For every other repository, both the
distributed `idd-template/` posting step and `resolveSelfReferentialTriggerFiles`
independently derive a profile-appropriate set instead, on a
profile-invariant base of the two workflow paths plus
`.github/idd/config.json`, adding: compiled `scripts/*.mjs` paths for
`vendored-node`; the dependency manifest and lockfiles for
`package-manager`; nothing further for `ephemeral-npx` (whose own
checker version pin already lives in the base set's config file, via
`helperRuntime.packageSpec` -- see
[Customizing IDD](customization.md)); or nothing further for any other
profile. The config file is included for every profile, not only
`ephemeral-npx` (kurone-kito/idd-skill#2657, Codex review round 8):
both this posting job and the verdict job check out the trusted default
branch, never the PR head, so a PR that fixes a broken checker by
migrating `helperRuntime.profile` itself (e.g. `package-manager` to
`ephemeral-npx`, to work around a broken lockfile/manager detection)
resolves the OLD, still-broken profile on both sides -- scoping the
config file to only the profile a PR happens to migrate TO would leave
every other profile's own migration-via-config-only fix unable to
trigger this bypass, the exact trap this mechanism exists to escape.
Since a `vendored-node`/`package-manager`
adopter never ships this source repository's own `src/scripts/*.mts`
files, an
unconditional match against them left the mechanism both non-functional
for adopters and gameable via a PR touching a path that does not exist in
their own checkout at all. `idd-advisory-convergence.yml` detects this
from a
separate job with `issues: write` as its only write permission (the
verdict job stays read-only; it additionally gains `actions: read`,
required for the run-id trust verification's own
`GET /repos/{owner}/{repo}/actions/runs/{run-id}` call in a private
repository) and posts a marker as `github-actions[bot]` via
`GITHUB_TOKEN`, using the CLI's `--auto-bootstrap` mode. The verdict job
also runs `needs:` this posting job (with `if: ${{ !cancelled() }}` so it
still runs when the posting job skips) so an allowlisted PR's own
bootstrap marker is guaranteed to exist -- posted or definitively not --
before the verdict job ever fetches PR comments; without that ordering
the two jobs race, since posting a PR comment does not itself trigger a
fresh run of this workflow:

```sh
idd-external-check-waiver --pr 123 \
  --check "idd-advisory-convergence" \
  --reason "self-referential-bootstrap-auto" \
  --run-id "$GITHUB_RUN_ID" \
  --auto-bootstrap \
  --apply --yes
```

`--auto-bootstrap` differs from ordinary usage in exactly five ways:

- it skips the collaborator-authority check entirely (there is no human
  actor to authorize -- the trust model below replaces it);
- `--reason` must equal the literal token `self-referential-bootstrap-auto`
  (a value the parser rejects for every other purpose) and `--run-id` is
  required; `--expires`/`--expires-in` are rejected -- the expiry is
  always computed internally, independent of
  `advisoryWait.convergenceDeadline`. The base window is the PR's HEAD
  commit timestamp plus a fixed `PT24H`, but two further rules apply
  (Codex review, PR #2895): the duration clamps to the configured
  `ciGate.externalCheckWaivers.maxValidity` when that is shorter than
  `PT24H` (an adopter with a stricter configured maximum still gets a
  marker, just a shorter-lived one, instead of every post being
  rejected by that same policy's own validation), and if the
  HEAD-anchored result would already be non-future (a stale HEAD from a
  `reopened` trigger with no new commit), the window anchors on the
  current time instead, so a stale-enough PR still gets a
  genuinely-future expiry rather than one rejected outright;
- it resolves the linked issue's real active claim exactly like the
  ordinary path when exactly one resolves, but falls back to the same
  claimless `none` binding `--claimless` renders (rather than blocking)
  when ZERO candidates resolve at all (Codex review, PR #2895) -- the
  fixed workflow invocation never passes `--issue`/`--claim-id`/
  `--claimless`, so a fully claimless allowlisted PR under the default
  `advisoryWait.convergenceScope: "all-prs"` (no linked issue, e.g. a
  human-authored checker-file edit outside IDD) would otherwise be
  permanently unable to post this waiver. Safe because the consumer's own
  `none`-sentinel match (below) only ever succeeds when it independently
  finds no active claim either, so this can never paper over a genuine
  claim mismatch. Restricted to the zero-candidate case specifically, not
  an AMBIGUOUS one (more than one candidate resolves, Copilot review, PR
  #2895): some claim genuinely exists there, just not uniquely
  identified from this input, and this file's own claim resolution
  cannot prove `advisory-convergence.mts`'s own (different)
  claim-resolution mechanism would treat that ambiguity the same way, so
  an ambiguous PR still blocks. Explicitly combining the literal
  `--claimless` flag with `--auto-bootstrap` is still rejected as
  redundant caller error;
- it never reuses an existing marker (kurone-kito/idd-skill#2657, Codex
  review round 2, PR #2895): the generic reuse scan every other
  `--apply` invocation runs first (to avoid double-posting on a retry)
  is skipped entirely here, since it correlates only on selector,
  reason, HEAD, and claim -- never the `run-id:`/event-type trust chain
  below -- so a same-repository PR-controlled `pull_request` workflow
  could otherwise prepost a same-reason marker with no verifiable
  `run-id:` and trick this job into believing a valid waiver already
  exists, skipping its own post. Always attempting to post is at worst
  a harmless extra marker; the consumer's trust check below already
  accepts any candidate that verifies;
- when the post succeeds, the job's own workflow steps additionally
  upload a run-scoped GitHub Actions artifact named
  `idd-self-waiver-marker-<comment-id>-<body-digest>`
  (kurone-kito/idd-skill#2912, round 2, extended round 3, extended round
  4) -- the posted comment's own numeric id, a literal `-`, and the
  SHA-256 hex digest of that comment's exact body, and nothing else, as
  the artifact's name (never its content, so the consumer never needs to
  download or unzip it). This is the channel condition 7 below reads to
  bind a marker to the run's own trusted execution: artifacts are scoped
  to the run that uploaded them by the Actions runtime's own dedicated
  upload token, never by the shared `GITHUB_TOKEN` `permissions:`
  surface an issue comment (or a check run) is created and mutated
  through, so no OTHER same-repository workflow run can add, edit, or
  remove an entry from this specific run's own artifact list. The body
  digest is hashed from an API-returned body on both the posting and
  consuming sides, so an unedited comment digests identically regardless
  of which side computed it -- specifically, the posting side hashes
  ONLY the `body` field GitHub's create-comment response returns for the
  exact POST that created the comment, never a later re-read. An earlier
  design (round 3) instead preferred a body observed in a LATER, separate
  post-write re-read (falling back to the locally-sent string only when
  that re-read came up empty, and labeling the result
  `ExternalCheckWaiverReport.bodyDigestSource: 'constructed'` when it
  did) -- a Copilot review of that round's own commit found this opened a
  window: a same-repository `issues: write` workflow could edit the
  genuine comment's body between the POST returning and that later
  re-read running, and the reconcile-preferring design would then hash
  and report the FORGED body as trustworthy. Round 4 removed that
  fallback entirely; `bodyDigestSource` no longer exists, and the digest
  is reported only when the create-comment response itself carried a
  body.

The marker is honored only when **all** of the following hold, verified
by `advisory-convergence.mts` itself (not the generic
`resolveTrustedCollaboratorMarkerLogins` trust surface, since this check
needs a live per-marker run lookup no other consumer needs):

1. the comment author is exactly `github-actions[bot]`;
2. the `reason:` token is exactly `self-referential-bootstrap-auto`;
3. `GET /repos/{owner}/{repo}/actions/runs/{run-id}` for the marker's
   `run-id:` returns `path` equal to
   `.github/workflows/idd-advisory-convergence.yml`, `head_sha` equal to
   the marker's `{head-sha}`, and `head_repository.full_name` equal to
   the current repository;
4. that same response's `event` field is exactly `pull_request_target`,
   never `pull_request` -- closing the gap where a same-repository PR
   editing the workflow YAML can still trigger a `pull_request`-triggered
   run of it during a `pull_request`/`pull_request_target` migration
   window (kurone-kito/idd-skill#2764 Phase 1);
5. the PR's own changed files (fetched independently at consume time,
   never trusted from the posting job's own internal check) include at
   least one path from the trigger-file allowlist above
   (kurone-kito/idd-skill#2657, Codex review, PR #2895) -- conditions 3
   and 4 alone only prove the marker cites a genuine
   `pull_request_target` run of this exact workflow file/head/repo, not
   that the run's own allowlist check found a match, so without this a
   same-repository PR could forge a marker citing the ordinary verdict
   job's own trivially-discoverable run id for its own HEAD and bypass
   advisory convergence for a change that never touched the allowlist at
   all;
6. `GET /repos/{owner}/{repo}/actions/runs/{run-id}/jobs` for that same
   `run-id:` reports the run's own `idd-advisory-convergence-self-waiver`
   job's "Post the self-referential-bootstrap-auto waiver" step with
   `conclusion: success`, AND the marker comment's own `createdAt` falls
   within that step's `[started_at, completed_at]` execution window
   (kurone-kito/idd-skill#2912) -- conditions 3 and 4 alone prove only
   that SOME genuine run of the right shape exists, never that THAT run's
   own job actually posted THIS specific comment; a same-repository
   `pull_request`-triggered workflow (untrusted, but able to post
   `github-actions[bot]`-authored comments the same way the genuine
   posting job does) can discover a legitimate, concurrently running
   `pull_request_target` run's id via the public Actions API and cite it
   in a forged marker, satisfying conditions 1-5 without having been
   posted by that run's job at all. Binding to the post step's own
   recorded conclusion and execution window closes this; and
7. the marker's own comment `(id, body digest)` pair appears in the SET
   of such pairs the cited `run-id:`'s own trusted job execution recorded
   actually posting, recovered from a run-scoped GitHub Actions artifact
   that job uploads immediately after posting (named
   `idd-self-waiver-marker-<comment-id>-<body-digest>` -- see
   `listWorkflowRunArtifacts` in `provider-adapter-github.mts`)
   (kurone-kito/idd-skill#2912, round 2, extended round 3, extended round
   4) -- condition 6
   above proves only that the cited run's job succeeded and posted SOME
   comment within a tight execution window, never THIS EXACT comment (and
   never that its content stayed unchanged since); a same-repository
   `pull_request`-triggered workflow can post a forged marker inside that
   same window, wait for the genuine marker to post, and then either
   DELETE it (`issues: write` permits deleting ANY issue comment on the
   repository, not only ones the deleting token itself authored), leaving
   the forged marker as the sole survivor of a plain "no duplicate
   currently visible" scan (round 1's gap), or EDIT it in place --
   `issues: write` permits rewriting an existing comment's body too,
   which preserves that comment's `id` and `createdAt` while replacing
   its content, so binding on `id` alone (round 2) would still accept the
   rewritten body. Binding on the `(id, body digest)` pair instead of `id`
   alone closes both: artifacts are scoped to the run that uploaded them
   by the Actions runtime's own dedicated upload token, never by the
   shared `GITHUB_TOKEN` `permissions:` surface comments (and condition
   6's own job/step data) are read and, in the comment's case, mutated
   through -- so no unrelated run can add, edit, or remove an entry from
   that trusted set regardless of which `permissions:` it self-grants,
   and a LATER edit to the live comment changes its digest without being
   able to retroactively change what the artifact already recorded.
   Deleting or editing the genuine comment only removes/changes it in the
   live comment scan condition 7 itself needs to correlate an entry back
   to its own `id` (two distinct candidates sharing the same cited run id
   AND the same wall-clock second are ambiguous for that correlation and
   both fail closed, never guessing a winner) -- it degrades this
   mechanism to "no auto-waiver", never "the forged or edited marker
   validates". The one residual: an attacker who additionally
   self-grants the broader, repository-wide `actions: write` permission
   could delete the genuine run's own artifact through Actions' own
   artifact-management endpoint, which still only degrades to "no
   auto-waiver", never a forged one -- outside the `issues: write`-scoped
   threat model this condition (and the independent review findings that
   prompted both rounds) are framed against.

A marker missing `run-id:`, whose run, run-jobs, or run-artifacts data
cannot be resolved, targets another head SHA or repository, ran under
any event other than `pull_request_target`, whose PR diff does not touch
the trigger-file allowlist, whose cited run's own posting step did not
report `success` within its own execution window, or whose own comment
`(id, body digest)` pair is absent from (or ambiguous within) the cited
run's artifact-recorded trusted set, is rejected the same way a manual
waiver from an untrusted actor is today. Unlike an ordinary
maintainer-authorized waiver (gated behind
`deadlinePassed || terminalUnavailable`), a valid
self-referential-bootstrap-auto waiver is evaluated **unconditionally** --
it makes `ready` true immediately, without waiting for the deadline clock
or a proven Copilot outage, since the whole point is bootstrapping a fix
to the deadline mechanism itself. It stays gated on the applicability
scope, though: under `convergenceScope: "idd-claimed"`, a PR whose
linked issue's claim history is ambiguous or lacks a currently active
claim resolves `indeterminate`, not `not_applicable` -- deliberately
kept **not** self-bootstrap-eligible (Copilot review, PR #2895, round
10), unlike the ordinary maintainer waiver's own `not_applicable`-only
gate, since that path requires an actual human judgment call that this
one never makes. Do not widen this exception to any other reason
token, actor, or check selector.

**A narrow, inherent dead zone remains** (kurone-kito/idd-skill#2657,
Codex review, PR #2895, round 9): being in the trigger-file allowlist
does not mean every possible bug in that file can be self-bootstrapped.
Both the posting job and the verdict job always check out the
repository's default branch, never the PR head -- required so neither
job ever executes PR-controlled code with `issues: write` -- so a bug
specifically WITHIN the code that decides whether/how to invoke
`--auto-bootstrap` (its own branches in `external-check-waiver.mts`),
the four Actions-API methods the trust chain above itself calls
(`getWorkflowRun`, `getWorkflowRunJobs`, `listWorkflowRunArtifacts`,
`listChangeRequestChangedFiles` in `provider-adapter-github.mts`), or the
seven conditions' own verification functions in `advisory-convergence.mts`
(`verifySelfReferentialBootstrapWaiverRun`,
`verifySelfReferentialBootstrapWaiverProvenance`,
`verifySelfReferentialBootstrapWaiverArtifactBinding`, and the rest) cannot
be rescued by this mechanism: the OLD, buggy version of exactly that
code is what would have to decide to trust the fix. This is the same
fixed point every self-hosting bootstrap has, and isolating marker
emission into a
smaller module would shrink it, never eliminate it. The rest of each
listed file's surface -- most of it, since each implements far more
than this one trust path -- remains genuinely bootstrappable as
described above. For the residual case, the
[maintainer-authorized waiver backstop](#external-check-waiver-contract)
this repository already configures is the documented human off-ramp
for precisely this situation, not a gap this mechanism itself needs to
close.

### Provider health helper

- Command: `node scripts/provider-health.mjs [--owner <owner>] [--repo <repo>]`
- Published bin: `idd-provider-health`
- Stable contract:
  [`provider-health.schema.json`][provider-health-schema]
- Purpose (#2319): IDD already observes advisory-review and Actions
  degradation, but only one pull request at a time, in three
  unconnected places (an advisory bot's rate-limit/quota comment
  classified as a non-review notice, the Actions billing/spend-limit
  block CI shape, and `advisory-wait-state.mts`'s own per-pull-request
  terminal state). Nothing aggregates those signals across pull
  requests, so a session cannot distinguish "this pull request is
  stuck" from "the service is down for everything". This read-only
  classifier supplies the shared, cross-pull-request verdict other
  tracks may read.
- Emits a `healthy | degraded | unavailable | unknown` verdict for each
  of two services, `advisory-review` and `ci-actions`, aggregated from
  already-observable per-pull-request evidence:
  - `advisory-review`: a trusted `advisory-wait:` request marker with
    neither a subsequent `review_requested` timeline event nor a
    submitted review from the primary bot, anchored to the marker's own
    embedded requested-at timestamp and gated by the same
    `advisoryWait.settledWindowMinutes` grace period
    `evaluateStaleRequestRecoveryAction` (#2327, `advisory-wait-state.mts`)
    already applies for a single pull request -- reused here, read
    across several, rather than re-derived.
  - `ci-actions`: a completed workflow run whose every job executed zero
    steps -- the documented account-level Actions billing/spend-limit
    block shape (the run starts but no steps run, unlike an ordinary
    step failure); an ordinary code-caused failure contributes no
    evidence either way.
- Corroboration is counted over **distinct pull-request identities**,
  never observation count, per the configured
  `providerHealth.minCorroboratingPrs` (default `2`): a single pull
  request's failure burst always caps at `degraded`, never
  `unavailable`. `unknown` is the floor for every insufficient,
  contradictory, or unreadable evidence path -- never `unavailable`.
- Read-only by construction: emits no marker, mutates no issue, pull
  request, or check, and exposes no field named or shaped as a
  merge-readiness or CI-gate result. Nothing in this repository's F2/F3
  merge gate or `idd-advisory-convergence` check consumes this helper's
  output -- see the provider outage declaration helper below for the
  decoupling this implies for `providerOutage`.

### Provider outage declaration helper

- Command:
  `node scripts/provider-outage-declaration.mjs --service <name>
  [--declare | --record-advanced | --list-advanced] [options]`
- Published bin: `idd-provider-outage-declaration`
- Stable contract:
  [`provider-outage-declaration.schema.json`][provider-outage-declaration-schema]
- Purpose (#2320): substitute one repository-scoped, time-boxed
  declaration for repeatedly posting a per-pull-request
  external-check-waiver during a sustained provider outage, read from
  the configured `providerOutage.declarationTarget` issue so no
  repository file has to change while the outage is in progress.
- Modes:
  - default (resolve): reports whether an active, valid declaration
    exists for `--service`, recomputed live on every call -- nothing is
    cached, and an expired declaration reverts with no cleanup step.
  - `--declare`: renders a new declaration marker; `--apply` posts it to
    the declaration-target issue only after the acting GitHub user
    passes the same `ciGate.externalCheckWaivers.authorityPolicy`
    authority check the external-check-waiver helper's create path uses
    (owner, Maintain, or Admin by default) -- reusing that resolver
    rather than adding a second trust path. Requires exactly one of
    `--expires` or `--expires-in`; the requested window is rejected when
    it exceeds `providerOutage.maxValidity` (default `PT24H`).
  - `--record-advanced --pr <n> --head-sha <40-hex>`: records that a
    pull request was advanced under the currently active declaration,
    so a post-recovery sweep can re-request its advisory review.
    `--apply` refuses when no declaration is active for `--service`.
  - `--list-advanced`: lists every recorded advancement from trusted
    markers on the declaration-target issue. Entries are **HEAD-pinned**
    -- a later push to the same pull request produces a distinct entry
    rather than overwriting the earlier one, so the sweep re-requests
    review per recorded HEAD.
- Non-bypassing by construction: an active declaration alone never
  relieves anything. The consuming caller must independently prove the
  pull request's own terminal advisory-unavailable state (the same
  per-pull-request proof the `idd-advisory-convergence` waiver
  precondition already requires) before a declaration-relieved selector
  applies, and relief is scoped to exactly the selectors listed in
  `ciGate.externalChecks.waivable` -- it never relieves a CI conclusion,
  branch freshness, claim state, or unresolved threads, which stay
  evaluated exactly as they already are.
- Decoupled from the provider-health classifier (#2319/#2327):
  declaration validity is actor authority, service, timestamps, and
  expiry only. An absent or `unknown` provider-health verdict never
  invalidates an otherwise-valid declaration, and this helper accepts no
  verdict input at all.
- Consumed by both gates the `idd-advisory-convergence` waiver already
  relieves
  ([kurone-kito/idd-skill#2353](https://github.com/kurone-kito/idd-skill/issues/2353)):
  `advisory-convergence.mjs`'s own CI-check verdict and
  `pre-merge-readiness.mjs`'s F2/F3 merge gate each independently resolve
  a declaration for service `idd-advisory-convergence` on the configured
  `providerOutage.declarationTarget` issue, gated exactly as the
  non-bypassing bullet above describes -- and both additionally require
  `ciGate.externalCheckWaivers.mode` to be `maintainer-authorized`, the
  same mode gate a direct per-pull-request waiver already requires.
  Declare with that exact service name (`--service
  idd-advisory-convergence`) for either gate to honor it; a declaration
  for any other service name relieves nothing here.

### Provider outage park helper

- Command:
  `node scripts/provider-outage-park.mjs [--park --pr <n> --issue <n>
  --service <name> --blockers <name1,name2> --claim-id <id> --agent-id
  <id>] [--apply]`
- Published bin: `idd-provider-outage-park`
- Stable contract (the posted `idd-provider-outage-park` marker payload,
  not the list-mode stdout shape below):
  [`provider-outage-park.schema.json`][provider-outage-park-schema]
- Purpose (#2321): every current route for an unavailable external
  service ends in a hold, which keeps the claim live until
  `claimTiming.staleAge` elapses -- the session can neither continue nor
  pick up different work, and the outage keeps producing more pull
  requests stuck the same way. Parking releases the claim immediately
  instead, at no cost to any quality gate: it never resolves a thread,
  satisfies a gate, or merges.
- Modes:
  - default (list, read-only): lists every open pull request carrying a
    trusted `idd-provider-outage-park` marker, each with its parked
    service's current `provider-health` verdict and `resumable` (true
    only once that verdict is `healthy`). Sorted by `parkedAt` then pull
    request number for deterministic re-entry order. Reports `count` and
    `boundReached` against `providerOutage.maxParkedChanges` (default
    `10`) as information only -- this mode never blocks a park. The open
    pull request read is bounded (default 50, most-recently-updated
    first); `sampleTruncated` is `true` when more open pull requests may
    exist beyond that sample, and `boundReached` fails closed to `true`
    in that case regardless of the sampled `count`.
  - `--park`: fetches the pull request's live head SHA, re-checks the
    named service's live `provider-health` verdict is `unavailable`, and
    requires every entry in `--blockers` (the caller's own fresh
    `pre-merge-readiness` blocker-gate names) to map to that service --
    `advisory-review` only for `advisory-wait` /
    `copilot-terminal-unavailable`; `ci-actions` only for `ci` /
    `discarded-required-check-siblings`. Any other blocker, or an empty
    `--blockers`, refuses to park. `--apply` posts the marker (naming the
    service and the full `--blockers` list, per the issue's own
    acceptance criteria) to the pull request; releasing the originating
    issue's claim is a separate, existing step the caller takes
    afterward (`unclaimed-by`), not performed by this command.
- Same claim-gating contract as `post-idd-marker.mjs`: this command
  performs no claim/state gating itself -- the calling phase runs its
  own claim-revalidation gate before `--apply`.
- Read-only by construction in list mode: exposes no field named or
  shaped as a merge-readiness or CI-gate result, mirroring the
  provider-health helper above.

### Local validation evidence helper

- Command:
  `node scripts/local-validation-evidence.mjs --pr <n> --head-sha <40-hex>
  [--record] [options]`
- Published bin: `idd-local-validation-evidence`
- Stable contract:
  [`local-validation-evidence.schema.json`][local-validation-evidence-schema]
- Purpose (#2323): record that a local command set (typically
  `pre-push-validate`) ran against a pull request's exact HEAD, as
  HEAD-pinned, actor-trust-filtered, expiring evidence -- so a queue
  caused by a required-check Actions outage recovers on a rerun rather
  than a re-review.
- Modes:
  - default (resolve): reports whether unexpired, actor-trusted evidence
    exists for `--head-sha` covering every `--required-checks` name,
    **only while** an active provider-outage declaration
    ([above](#provider-outage-declaration-helper)) exists for
    `--service` (default `ci-actions`). Recency is measured from the
    marker comment's own `created_at` against `localValidationEvidence.maxAge`
    (default `PT4H`), never an embedded timestamp.
  - `--record --covers <names> --outcome <pass|fail>`: renders and (with
    `--apply`) posts the evidence marker to the pull request.
- **Hide-at-post-time (#2755).** After a successful `--record --apply`
  POST, this helper also hides (classifier `OUTDATED`) prior
  `idd-local-validation-evidence:` comments whose embedded HEAD SHA
  differs from the one just recorded, grouped by embedded HEAD SHA
  mismatch mirroring the `advisory-wait` AW3-H rule -- see
  [Comment minimization](idd-comment-minimization.md#timing). Best-effort:
  any failure there never blocks or retries the marker post that already
  succeeded. `--trusted-marker-logins a,b` gates that step's trusted-author
  check (falls back to `IDD_TRUSTED_MARKER_ACTORS` /
  `.github/idd/config.json`'s `trustedMarkerActors`, the same ladder as
  every other `minimize-superseded-markers.mjs` caller).
- **Never a merge gate.** `pre-merge-readiness.mts` reports this
  helper's resolution as its own additive `localValidationEvidence`
  field; `computePreMergeReadinessBlockers` (protocol-helpers.mts) has
  no reference to that field, so it can never remove or downgrade a
  required-check blocker. Evidence changes what is _known_, never what
  is _green_ -- an unavailable required platform check stays listed as
  a blocker regardless of evidence. Restoring the platform check rollup
  is an out-of-band privileged operation outside the autonomous loop.
- On recovery, drive re-verification from the evidence marker's own
  `headSha` (`evaluateLocalValidationEvidenceRecovery`): a pull request
  whose HEAD advanced past the recorded evidence is re-validated, never
  merged on the stale record.

### A4 viability gate

- Command: `node scripts/discover-viability-gate.mjs --issue <number>`
  (repeatable; or `--issues <n1,n2,...>`)
- Optional CSV output: append `--csv` flag
- Stable output schema (JSON mode):

  ```json
  {
    "viable": [{ "number": 123, "title": "..." }],
    "discarded": [
      { "number": 124, "title": "...", "failedCriteria": ["limited_scope"] }
    ],
    "summary": {
      "total": 2,
      "viableCount": 1,
      "discardedCount": 1,
      "discardedByCriterion": { "limited_scope": 1 }
    }
  }
  ```

- Stable fields consumed by A4: `viable[].number`, `discarded[].number`,
  `discarded[].failedCriteria`, and `summary.viableCount`
- `viable[]` entries also carry an optional `criteria` array (`#2767`,
  same shape as `discarded[].criteria`) whenever structural evidence
  demoted a criterion to a `warn`-annotated pass; omitted for an
  ordinarily fully-passed issue, so this stays additive to the stable
  two-field shape above -- see the Discover Viability Gate Contract
  section for the full `criteria` shape and a worked example.
- The helper evaluates the three A4 viability criteria (limited scope, clear
  verification, autonomous completion) against fetched issue bodies; it does
  not post claims or mutate any state

### Claim approval evidence

- Source repo / vendored-node command:
  `node scripts/claim-approval-gate.mjs --issue <issue-number>`
- Package-manager / ephemeral-npx command: use the
  profile-selected `idd:claim-approval-gate` command from the helper
  runtime manifest wiring above; the literal invocation is:

  ```sh
  npx --yes --package <helper-package-spec> \
    idd-claim-approval-gate --issue <issue-number>
  ```

- Optional freshness override: append
  `--generated-plan-updated-at <ISO8601>` when the caller already has
  authoritative generated-plan freshness evidence to reuse
- Stable fields consumed by the instructions: `approved`, `reason`,
  `gateEnabled`, `policy.skipIssueAuthorApprovalGate`,
  `policy.maintainerApprovalActorPolicy`, `policy.approvalSignals`,
  `checks`, and `timelineAvailable`
- `checks` remain stable by `id`: `gate_enabled`,
  `author_self_authorized`, `ready_label_present`,
  `ready_comment_fresh`, and `ambiguity_guard`
- the helper is intentionally scoped to A5(a); A5(d) open-PR conflict
  checks stay on the written live GitHub path because inheritable-branch
  and linked-issue exceptions do not yet have a supported helper
  contract

### Worktree-local claim lock

- Source repo / vendored-node commands:
  `node scripts/claim-lock.mjs --acquire --worktree <path> --agent-id <id>
  --claim-id <id> [--takeover]`
  and `node scripts/claim-lock.mjs --check --worktree <path>`
- Package-manager / ephemeral-npx command: use the profile-selected
  `idd:claim-lock` command from the helper runtime manifest wiring above;
  the literal invocations are:

  ```sh
  npx --yes --package <helper-package-spec> \
    idd-claim-lock --acquire --worktree <path> --agent-id <id> \
    --claim-id <id> [--takeover]

  npx --yes --package <helper-package-spec> \
    idd-claim-lock --check --worktree <path>
  ```

- Same-machine fast path complementing the cross-machine claim check (see
  the [worktree-local lock file](../.github/instructions/idd-claim.instructions.md#worktree-local-lock-file-same-machine-collision)
  subsection of `idd-claim.instructions.md` for the full protocol)
- Before removing an existing linked worktree, acquire/check its lock and
  resolve any collision through the current claim. A worktree must not be
  removed while another claim still holds its lock.
- WorkTrunk pre-start install hooks run before `wt switch --create` returns;
  configure the hook to acquire the lock as its first command, before the
  install. Under `package-manager`, the new worktree's bin may not exist
  until that install completes, so invoke a pre-install-available helper
  from the primary worktree with the new path as its explicit target, or
  use the helper-free exclusive file-create fallback. If neither is
  available, disable the automatic install and acquire the lock immediately
  after worktree creation.
- Stable `--acquire` `mode` values: `acquired` (fresh create, a read-only
  same-`claim-id` reacquire that writes nothing, or an authorized
  `--takeover` override — disambiguated by the optional `reacquired` /
  `forcedTakeover` boolean fields) or `collision` (a different `claim-id`
  already holds the lock, or the existing path is malformed/unreadable —
  retry with `--takeover` only after
  `resume-claim-routing.mjs --fresh-claim-gate` authorizes it: a
  `claimable` verdict, a `stale-reclaimable` verdict, or an
  `already-claimed` verdict whose `winning_claim_id` matches a
  `claim-id` the caller has already independently verified as its own).
  A `holder`
  snapshot of the previous occupant is reported on **both** a plain
  `collision` and an authorized takeover, not only on takeover.
- `reacquired: true` also carries an optional `racedCreate: true` flag
  (#2917 review, Codex): set when this exact
  invocation's own first read found the lock absent and its own
  exclusive-create attempt then lost a race to a concurrent same-`claim-id`
  creator, so the eventual match came from a later retry, not the
  invocation's first look. A caller trusting `reacquired: true` as
  evidence the lock predates this call (as the backfill-tokens recovery
  route does) must also require `racedCreate` to be absent/`false`.
- The `--acquire` CLI exits `0` only for `acquired` and exits `2` for
  `collision`, so a hook can safely chain installation or another mutation
  with `&&`; `--check` remains read-only and exits `0` for a reported state.
- `--check` reports `{ path, present, holder?, malformed? }` read-only,
  never creating, mutating, or deleting the lock; `malformed: true` means
  a lock file exists but could not be parsed as a well-formed lock body
- Deliberately has no local staleness judgment (no PID-liveness check):
  the process invoking this CLI exits the moment the call returns, so a
  recorded PID would never usefully represent a live competing session.
  The configured GitHub `claim-stale-age` stays the sole staleness
  authority; this lock only ever reports `collision` or acquires.
- No explicit release verb: the lock lives inside the worktree's own
  private git-admin directory (`git rev-parse --absolute-git-dir`), so
  `git worktree remove` at F4 deletes it together with the worktree
- **`instructions-only` helper-free fallback** (no helper runtime
  available): resolve the private admin directory with
  `git -C <worktree> rev-parse --absolute-git-dir`, then read the
  `idd-claim.lock` path first, before writing anything. Present,
  well-formed, and its holder matches (`agentId`, `claimId`) →
  re-acquired without writing — this call's own first read found the
  lock already there, mirroring the helper's `reacquired: true` with no
  `racedCreate`. Absent → write the same JSON holder shape (`agentId`,
  `claimId`, `acquiredAt`) to a same-directory temporary file with a
  unique name (for example `idd-claim.lock.tmp-<pid>-<random>`); once
  that temp file is fully written and closed, publish it into the
  final `idd-claim.lock` path atomically: on POSIX, `link()` the temp
  file into `idd-claim.lock` and then `unlink()` the temp file (never
  `rename()`, which would silently replace an existing destination
  instead of failing); on Windows/PowerShell, a no-overwrite move of
  the fully-written temp file into the final path (for example
  `[System.IO.File]::Move`, which throws when the destination already
  exists). This mirrors `createLockFileExclusively` in
  `src/scripts/claim-lock.mts`. Never create the final
  `idd-claim.lock` path directly and write into it as two separate
  steps — a concurrent same-claim-id reader could then observe a torn
  or empty body at that path and misreport a collision (#2920). If the
  publish step then fails because the final path now
  exists (`EEXIST` on POSIX, or the platform-equivalent
  already-exists failure on Windows), remove your own temporary file
  and re-read the final path to confirm the holder matches, but treat
  this outcome as a race, not as evidence the lock predates this call —
  never equal it to a lock this same read already found present (the
  helper's `racedCreate: true`, #2917 review, Codex). A path that
  already exists with a non-matching, missing, malformed, or
  unreadable holder is a collision either way. Never delete or
  override a different holder — enable a helper runtime for an
  authorized takeover instead. Both profiles share the
  `idd-claim.lock` namespace, so a helper-runtime session and an
  instructions-only session see the same lock.

### Worktree-local generated-tokens record

- A sibling artifact to the worktree-local claim lock above, in the same
  admin directory, answering a narrower question (#2719): not "does
  anyone else hold this worktree" but "did _this_ session actually
  generate the `{agent-id}`/`{claim-id}` it is about to trust, on disk,
  independent of possibly-compacted conversation memory." Referenced by
  the "Generated-tokens record" paragraph in
  [`idd-claim.instructions.md`'s Worktree-local lock file section](../.github/instructions/idd-claim.instructions.md#worktree-local-lock-file-same-machine-collision).
- Source repo / vendored-node commands:
  `node scripts/claim-lock.mjs --record-tokens --worktree <path>
  --agent-id <id> --claim-id <id> [--nonce <nonce>]`,
  `node scripts/claim-lock.mjs --read-tokens --worktree <path>
  --claim-id <id>`, and
  `node scripts/claim-lock.mjs --backfill-tokens --worktree <path>
  --claim-id <id>`
- Package-manager / ephemeral-npx command: use the same profile-selected
  `idd:claim-lock` command as the lock above; the literal invocations are:

  ```sh
  npx --yes --package <helper-package-spec> \
    idd-claim-lock --record-tokens --worktree <path> --agent-id <id> \
    --claim-id <id> [--nonce <nonce>]

  npx --yes --package <helper-package-spec> \
    idd-claim-lock --read-tokens --worktree <path> --claim-id <id>

  npx --yes --package <helper-package-spec> \
    idd-claim-lock --backfill-tokens --worktree <path> --claim-id <id>
  ```

- **When to call `--record-tokens`**: once at A5 claim time, right after
  generating `{agent-id}`/`{claim-id}`, before posting the `claimed-by`
  marker (the B1 worktree does not exist yet, so `<path>` is then the
  _primary_ worktree); again with `--nonce` right before posting the
  activation-nonce marker; a third time at B1 once the sibling worktree
  exists, again with `--nonce` carried over from the A5 write --
  mirroring the lock's own `--acquire` step, but into a distinct file in
  the new worktree's own admin directory, so the earlier primary-worktree
  write's `nonce` field must be copied forward rather than omitted (the
  B1 write is not a re-read-then-rewrite of the same file). Keyed by
  `--claim-id` (a content-hash-suffixed, sanitized filename), so two
  sessions generating two different claim-ids resolve to different paths
  (an astronomically unlikely, not provably impossible, chance of
  collision from the truncated hash suffix) even while sharing the
  primary worktree's admin directory. No collision or `--takeover`
  concept: this is per-claim-id evidence, not a mutual-exclusion
  primitive, so re-invoking for the same `--claim-id` is always a safe,
  idempotent overwrite. Exits `0` unless a filesystem error occurs.
  **Scope**: a `--read-tokens` hit against the **shared primary**
  worktree path is bootstrap evidence only, not proof of current-session
  ownership by itself — see `claim-lock.mts`'s own "Scope of the
  ownership proof" header comment (#2879 review). Always resolve
  `--read-tokens`/`--acquire` against the caller's own current cwd, never
  an explicit different worktree's path.
- **When to call `--read-tokens`**: alongside every later `--acquire`
  re-run, before trusting a `{claim-id}` recalled only from context.
  Reports `{ path, present, malformed?, record? }` read-only, mirroring
  `--check`'s own shape: `present: true` with `record` means a
  well-formed record for exactly this `--claim-id` exists; `present:
  true, malformed: true` means a file exists at the resolved path but
  cannot be trusted as this claim-id's record (corrupt content, or an
  internal `claimId` field that disagrees with the path it was found
  at); `present: false` means this claim-id was never recorded. Treat
  `malformed` the same as absent for an ownership check — never trust a
  claim-id this record does not affirmatively confirm.
- **When to call `--backfill-tokens`** (#2884): the recovery route the
  Claim revalidation gate's step 5 documents for an absent or malformed
  `--read-tokens` result -- a worktree whose B1 predates this
  generated-tokens-record feature (a rollout gap: PR #2879 review, Codex
  P1) never gets a record written, so `--read-tokens` fails closed
  forever with no recovery otherwise. Reads the existing `idd-claim.lock`
  file at `<path>` (the same resolution `--check` uses) and writes only
  when it is present and its own `claimId` matches the given
  `--claim-id` exactly, using the lock's own `agentId` and no `--nonce`
  (matching a fresh pre-nonce `--record-tokens` call) unless a
  well-formed record for this `--claim-id` is already present, in which
  case its own `nonce` is preserved rather than silently erased (the
  documented recovery route only ever reaches this command when
  `--read-tokens` reported absent/malformed -- meaning no well-formed
  record exists yet -- but the CLI itself does not enforce that
  precondition, so it guards against a direct out-of-band invocation
  too, #2917 review): reports
  `backfilled`. An absent lock reports `lock-absent`; an unparseable or
  otherwise unreadable lock (for example a directory at the lock path)
  reports `lock-malformed`; a lock present for a different `claimId`
  reports `lock-mismatch` (naming the actual holder); a matching lock
  whose own record path is a directory reports `record-blocked` instead
  of deleting it -- the lock only authenticates the lock, not this
  separate path, and the path's hash suffix is not collision-proof, so
  lock authority alone never authorizes replacing it (#2917 review,
  Copilot) -- all four write nothing. Exits `0` for `backfilled` and `2`
  for the four failure statuses, mirroring `--acquire`'s own collision
  exit-code contract so a
  caller can chain `--backfill-tokens && --read-tokens`. Performs no
  GitHub round-trip, matching `--acquire`'s own same-machine, no-network
  design -- the caller is responsible for having already independently
  confirmed the live claim-id via GitHub before ever reaching this
  recovery step; this command only ever reconciles local worktree state,
  never adjudicates claim ownership itself. Re-invoking after a
  successful backfill is always a safe, idempotent overwrite (reports
  `backfilled` again), matching `--record-tokens`'s own idempotency
  contract -- there is no separate `already-present` status. The Claim
  revalidation gate (step 5, `idd-overview-core.instructions.md`, and
  the equivalent step in every lite guard) reaches this route only
  through a chain in which **each step gates the next** -- proceed to
  the next step only on the exact result shown, and stop fail-closed on
  any other result:
  0. The gate's own initial `--acquire` reports `reacquired: true` with
  no `racedCreate` -- a fresh `acquired` (lock just created),
  `forcedTakeover: true`, or `reacquired: true` with `racedCreate:
     true` (this call itself raced a concurrent creator for the same
  claim-id, so the match is not proof the lock predates this gate
  pass) are never legitimate backfill evidence.
  1. `--check` reports the lock `present`, holder matching
     `{claim-id}`.
  2. `--backfill-tokens` reports `backfilled`.
  3. The retried `--read-tokens` reports `present: true` (no
     `malformed`).
  4. A final `--acquire`, run again immediately before the mutation,
     reports `reacquired: true` with no `racedCreate` -- the same
     requirement as step 0, applied again because a fresh `acquired`
     here would mean the lock vanished mid-recovery (for example a
     concurrent takeover) and this step would otherwise create a new
     one and let the mutation proceed with no real token evidence.

  This closes gaps three review rounds each found real: the window
  between the initial acquire and the mutation that a concurrent
  takeover could exploit; a literal reading of the sequence as an
  unconditional run-these-in-order list rather than a chain each link
  of which must actually succeed; and `reacquired: true` alone being
  trusted as proof of pre-existence when a same-claim-id race can
  produce it for a lock that is in fact only microseconds old
  (`acquireClaimLock`'s own `EEXIST`-retry loop,
  `src/scripts/claim-lock.mts`) (#2917 review, Codex and Copilot).
  Residual, named rather than hidden: a _third_ process arriving after
  such a race has already settled sees `reacquired: true` with no
  `racedCreate` on its own first read, the same way it would for a
  lock that is genuinely years old -- this mechanism only ever detects
  a race this specific call itself observed, never a lock's true age;
  the Claim revalidation gate's own GitHub-verified claim check (steps
  1-4 before this one) is the actual authority this is defense in
  depth for, not a replacement for it.
- No explicit release verb, no cleanup across takeovers: like the lock
  file, the record lives inside the worktree's own private git-admin
  directory, so `git worktree remove` at F4 deletes it together with the
  worktree. The _primary_-worktree copy written at A5 (before the B1
  worktree exists) is not cleaned up by that removal — an accepted
  residual, since giving this record cross-worktree, pre-acquisition
  visibility is explicitly out of scope (see the lock file's own
  cross-worktree-visibility note above). This is a deliberate choice,
  not an oversight: the file is a few hundred bytes, untracked (never
  shown by `git status`), and has no working-tree impact, so leaving it
  in place is cheaper than adding narrowly-scoped cleanup machinery for
  it. See issue `kurone-kito/idd-skill#2944` for the full reasoning
  record and the cleanup-vs-document-intent tradeoff it considered —
  qualified with the owner/repo here since this file is distributed
  via `idd-template/`, where a bare `#2944` would resolve against
  whichever repository copied it in.
- **`instructions-only` helper-free fallback, write side** (no helper
  runtime available — `instructions-only` is the distributed default
  profile, see
  [Helper Runtime Profile](customization.md#helper-runtime-profile) —
  so this path is the common case, not an edge case): resolve the
  private admin directory the same way as the lock file above, then
  atomically create-or-replace a file there matching this pattern
  (kept in a fenced block, not a prose code span, so a Markdown
  reflow can't break the filename across a line -- #2879 review,
  Codex P1):

  ```text
  idd-generated-tokens-<sanitized-claim-id>-<8-hex-char sha256 prefix>.json
  ```

  `<sanitized-claim-id>`: non-`[A-Za-z0-9._-]` characters replaced with
  `_`, then truncated to 64 characters, so a long claim-id can't push
  the filename past the filesystem's `NAME_MAX` -- #2879 review, Codex
  P1. `<8-hex-char sha256 prefix>`: the first 8 hex characters of the
  SHA-256 digest of the **original, pre-sanitize, pre-truncate**
  `{claim-id}`, UTF-8-encoded -- not the sanitized or truncated form,
  so a fallback and the CLI (or two fallback implementations) agree on
  the same path for the same claim-id (#2879 review, Codex P2). Write
  `{ agentId, claimId, nonce?, recordedAt }`. No exclusive-create
  semantics needed for **this record file itself** (unlike the lock
  file): a plain atomic replace is correct here since the record is
  idempotent evidence, not a mutual-exclusion primitive -- except a
  directory already occupying this exact path, which this fallback
  never replaces or deletes either, matching
  `recordGeneratedClaimTokens`'s own absolute invariant in
  `src/scripts/claim-lock.mts` (PR #2879 regression test; #2917 review,
  Copilot); stop fail-closed instead. **This is scoped to the record
  file's own replace step only** -- it does not exempt the coordination
  below: the separate `.writelock` guard the next bullet introduces
  _does_ need an exclusive create, every time, even though the record
  replace it wraps does not (#2922 review round 8, Copilot). Skipping
  the guard because "no exclusive-create semantics needed" was read as
  covering this whole write reopens the exact nonce-clobber race #2922
  reported.
- **`instructions-only` write-lock coordination** (#2922 -- applies to
  this write side and to the backfill side below, which performs a
  read-then-write of the same record): before writing, coordinate
  against a concurrent writer for the same `{claim-id}` the way the
  CLI's `recordGeneratedClaimTokens` and `backfillGeneratedClaimTokens`
  do (`withGeneratedTokensWriteLock`, `src/scripts/claim-lock.mts`):
  atomically create a same-directory `<resolved-path>.writelock` guard
  file (exclusive create -- fails if it already exists), retrying
  roughly every 5 ms for up to 5 seconds if it does, **writing a fresh,
  unique per-attempt token as the guard's own body** (a random value,
  or `pid:timestamp:random` -- any scheme unique per attempt is fine).
  **Only once that create call itself has actually succeeded** -- never
  before it, and never merely because this invocation _attempted_ one --
  arm a cleanup handler (a shell `trap`, or the agent's own equivalent of
  a `finally` block) that runs on **every exit path from this point
  forward, success or failure alike**, then perform the write (or, for
  the backfill side, the read that captures the existing `nonce` and the
  write that follows it). Arming the handler any earlier (for example a
  `trap` set up before the create attempt) is not ownership-safe: a
  failed create -- whether from `EEXIST` or from exhausting the 5-second
  wait budget below -- proves nothing was created by this invocation, so
  a handler armed that early would remove a **different, possibly
  concurrent, holder's own guard** instead, reopening the exact ABA race
  #2922's CLI-side fix (`withGeneratedTokensWriteLock`'s own
  `openSync`/`writeSync`/`closeSync` ownership tracking) exists to close
  (#2922 review round 6, CodeRabbit). The cleanup handler itself must be
  **token-verified, not unconditional** (#2922 review round 11,
  Copilot): re-read the guard and remove it only if it still holds the
  exact token this attempt wrote, mirroring the CLI's own
  `releaseGeneratedTokensWriteLockIfOwned` (and, before it,
  `releaseCloneLock` in `src/scripts/clone-lock.mts`) -- an operator can
  legitimately remove a guard by hand per the fail-closed timeout
  guidance below while this invocation's own write is still genuinely in
  flight, and a new writer can recreate it before this invocation's
  cleanup runs; an unconditional removal there would delete that new
  writer's guard instead of its own, letting two writers proceed at
  once. Treat a guard that is simply already gone (removed by hand, or
  already released) the same as a token mismatch -- nothing left for
  this cleanup to remove, not an error. This narrows rather than
  eliminates the race (verifying the token and removing the guard are
  still two separate steps, not one atomic operation), which is an
  accepted limitation shared with the CLI's own implementation -- see
  the doc comment on `withGeneratedTokensWriteLock` in
  `src/scripts/claim-lock.mts` for the full rationale. An agent that
  removes the guard solely after a successful write and skips cleanup
  when that write itself fails leaves the same orphaned-guard problem
  the CLI's own code was separately reviewed for (#2922 review round 4,
  Copilot): every later writer for this exact `{claim-id}` then waits
  the full 5 seconds and fails closed until an operator manually removes
  it. Unlike the record file's own body, the guard file's content is
  read back by this same cleanup handler to verify ownership before
  removing it -- no other, contending reader ever needs to inspect it,
  so no atomic-visibility trick is needed beyond the exclusive create
  itself. If the 5-second wait budget is exhausted, stop fail-closed and
  report the guard path for manual removal rather than writing anyway
  (an earlier revision of the CLI's own lock self-reclaimed an aged
  guard automatically; three independent reviewers found that unsafe --
  see the doc comment on `withGeneratedTokensWriteLock` for why
  fail-closed is the current answer) -- a pre-existing guard this
  invocation did not itself create is never removed on any path, success
  or failure. Skipping this coordination reopens the exact race #2922
  reported for the CLI path: a concurrent writer's fresher `nonce` can be
  silently lost, including between an `instructions-only` session and a
  helper-runtime session sharing the same worktree.
- **`instructions-only` helper-free fallback, read side** (#2879 review,
  Codex P1 -- the mandatory `--read-tokens` check in the Claim
  revalidation gate has no helper-free path without this): resolve the
  same filename for the queried `{claim-id}`, using the same sanitize-
  then-truncate rule as the write side, then reproduce the same three
  outcomes as the CLI's own `--read-tokens` above: a missing file is
  `present: false`; a file that exists but is unparseable JSON, or whose
  parsed `claimId` field disagrees with the queried `{claim-id}`, is
  `present: true, malformed: true`; only a well-formed record whose
  `claimId` field matches is plain `present: true`. Treat `malformed`
  the same as absent for the ownership check -- fail closed on both.
- **`instructions-only` helper-free fallback, backfill side** (#2884 --
  the same class of gap PR #2879's Codex P1 review flagged for
  `--read-tokens` above: a mandatory gate-recovery step needs a
  helper-free path too, and `instructions-only` is the distributed
  default profile): resolve the worktree-local lock file the same way as
  the lock section above and parse it the same way `--check` does --
  but only when your own _first read_ in the acquire step above already
  found the lock present and matching, never when it was absent there
  and your own publish-into-place attempt then failed because the final
  path already existed. That failure means a concurrent same-claim-id
  writer landed between your read and your publish -- a race, not
  evidence the lock predates this gate pass; the helper's own
  `racedCreate: true` marks exactly this case (#2917 review, Codex).
  Only when it parses as well-formed and its `claimId`
  field equals the active `{claim-id}` exactly, apply the write-side
  fallback above -- write-lock coordination included, wrapped around
  this whole read-then-write, not just the write -- using the lock's
  own `agentId`, carrying forward an existing well-formed record's own
  `nonce` when present, otherwise no `nonce` (#2917 review, Copilot) --
  except when the record's own
  resolved path is already occupied by a directory: leave it and its
  contents untouched and stop fail-closed instead, mirroring the CLI's
  own `record-blocked` status (`backfillGeneratedClaimTokens`,
  `src/scripts/claim-lock.mts`) -- a matching lock authenticates the
  lock, not that separate path, and the path's hash suffix is not
  collision-proof, so lock authority alone never authorizes replacing it
  (#2917 review, Copilot). An absent lock, a lock that fails to parse, a
  lock whose `claimId` differs, or a lock your own first read did not
  already find present and matching all leave the existing fail-closed
  stop unchanged -- write nothing.

### Clone-scoped lock

- Source repo / vendored-node commands:

  ```sh
  node scripts/clone-lock.mjs --exec --agent-id <id> [--repo <path>] \
    [--timeout-ms <n>] -- <command> [args...]

  node scripts/clone-lock.mjs --check [--repo <path>]
  ```

- Package-manager / ephemeral-npx command: use the profile-selected
  `idd:clone-lock` command from the helper runtime manifest wiring
  above; the literal invocations are:

  ```sh
  npx --yes --package <helper-package-spec> \
    idd-clone-lock --exec --agent-id <id> [--repo <path>] \
    [--timeout-ms <n>] -- <command> [args...]

  npx --yes --package <helper-package-spec> \
    idd-clone-lock --check [--repo <path>]
  ```

- A mutual-exclusion mutex around `git worktree add`/`remove` and
  `git fetch` against the _shared_ primary clone — unlike the
  worktree-local claim lock above, this blocks (retrying with backoff)
  rather than reporting an immediate collision, and serializes
  concurrent workers sharing one clone rather than guarding one
  worktree's own claim identity. See the
  [Orchestrator fan-out variant](idd-workflow.md#orchestrator-fan-out-variant)
  for when to reach for it.
- `--exec` acquires, runs `<command>` with stdio inherited and `cwd`
  set to `--repo`, then releases the lock even if the command fails,
  exiting with the command's own exit code; exits `3` if the lock
  could not be acquired within `--timeout-ms` (default 120000).
- `--check` reports `{ path, present, holder?, malformed?,
  holderAlive? }` read-only; `holderAlive` (diagnostic only, from
  `process.kill(pid, 0)`) reports whether the recorded holder still
  appears to be running.
- **No automatic stale-lock recovery**: a held lock is never taken
  over, regardless of how long it has been held or whether its
  recorded holder is still alive. `--exec` exits `3` on a
  `--timeout-ms` timeout, naming the lock path and the recorded
  holder's pid in the error message; once you have independently
  confirmed that holder is gone, remove the lock file by hand and
  retry — the same recovery git's own `index.lock` expects on a
  stale-lock collision.
- **`instructions-only` helper-free fallback (no helper runtime
  available)**: this lock is a same-machine convenience for
  parallel autonomous fan-out, not a correctness requirement — an
  `instructions-only` session running one worker at a time never
  contends for it. Where an `instructions-only` profile does run
  concurrent workers sharing one clone, serialize `git worktree
  add`/`remove`/`fetch` by giving each worker its own clone instead
  (see the Orchestrator fan-out variant linked above), rather than
  hand-rolling this lock's protocol.

### Canonical branch name

- Source repo / vendored-node command:
  `node scripts/branch-name.mjs --number <issue-number> --title <issue-title>`
- Package-manager / ephemeral-npx command: use the profile-selected
  `idd:branch-name` command from the helper runtime manifest wiring above;
  the literal invocation is:

  ```sh
  npx --yes --package <helper-package-spec> \
    idd-branch-name --number <issue-number> --title <issue-title>
  ```

- Prints a single plain line `issue/<number>-<slug>`, implementing the
  `idd-claim.instructions.md` pre-check (e) slug algorithm exactly
  (lowercase, replace `[^a-z0-9]` with `-`, drop empty tokens and the
  whole-token stop-words, rejoin with `-`, apply the 40-character
  mid-token-aware cut, then fall back to `task` when empty)
- Deterministic and network-free; the agent keeps branch-naming authority
  and the written algorithm stays the canonical fallback
- The `tests/branch-name.test.mts` drift test re-derives the pre-check (e)
  "Worked examples" table, so the prose and the helper cannot diverge

### Concurrent-selection desync index

- Source repo / vendored-node command:
  `node scripts/select-desynced-index.mjs --token <session-token> --band-size <band-size>`
- Package-manager / ephemeral-npx command: use the profile-selected
  `idd:select-desynced-index` command from the helper runtime manifest
  wiring above; the literal invocation is:

  ```sh
  npx --yes --package <helper-package-spec> \
    idd-select-desynced-index --token <session-token> --band-size <band-size>
  ```

- Prints a single plain integer line: the band index chosen by the A4
  Step 2 `discover.selectionDesync: session-offset` rule, implementing
  `selectDesyncedIndex` (a pure FNV-1a 32-bit hash of the session token,
  modulo the tie-band size) exactly
- Deterministic and network-free; a missing token or a non-positive /
  non-integer band size exits non-zero with a clear message instead of
  silently returning the library function's safe-default `0`
- The written formula in `idd-discover.instructions.md` stays the
  canonical spec and fallback when the helper is unavailable

### Per-cycle marker bodies

- Source repo / vendored-node command:
  `node scripts/emit-marker.mjs --type <type> <fields...>` where `<type>` is
  `claimed-by`, `review-watermark`, or `review-baseline`
- Package-manager / ephemeral-npx command: use the profile-selected
  `idd:emit-marker` command from the helper runtime manifest wiring above;
  the literal invocation is:

  ```sh
  npx --yes --package <helper-package-spec> \
    idd-emit-marker --type <type> <fields...>
  ```

- Prints the exact ready-to-post marker body (HTML token + visible "Do not
  edit" note) to stdout; **emit-only, no network write** — the agent posts
  it via the documented HTTP path
- Fields per type: `claimed-by` takes `--agent-id --claim-id --supersedes
  --timestamp --branch`; `review-watermark` takes `--agent-id --claim-id
  --head-sha --max-activity-at --total-item-count --ci-completed-at`;
  `review-baseline` takes `--agent-id --claim-id --sha`
- The written marker formats in `idd-overview-core` (claim) and
  `idd-review-snapshot` (watermark/baseline) stay canonical; the render
  functions live in `protocol-helpers` with byte-shape tests

### Post operational markers (write-side)

- Source repo / vendored-node command:
  `node scripts/post-idd-marker.mjs --type <type> --target <issue|pr> <number> <fields...>`
  (dry-run prints a JSON envelope whose `body` field is the marker); add
  `--apply` to POST it.
- Package-manager / ephemeral-npx command: use the profile-selected
  `idd:post-idd-marker` command from the helper runtime manifest wiring
  above; the literal invocation is:

  ```sh
  npx --yes --package <helper-package-spec> \
    idd-post-idd-marker --type <type> --target <issue|pr> <number> <fields...>
  ```

- Write-side companion to `emit-marker`: it renders the canonical body for
  each operational marker `<type>` (`claim`, `unclaim`, `activation-nonce`,
  `watermark`, `baseline`, `advisory`, `advisory-recovery`,
  `advisory-reroll`) by reusing the single-sourced `protocol-helpers`
  renderers, then POSTs it as a JSON document (`{"body": …}`) via
  `gh api --method POST .../comments --input -`. The JSON path is
  mandatory because `gh issue comment` / `gh api -f body=` silently
  reject the HTML-comment-first claim-family bodies. `-f` also treats a
  leading `@` as a literal character — only `-F` reads `@file` contents.
- The `claim` / `unclaim` / `activation-nonce` / `watermark` / `baseline`
  bodies are HTML-comment-first with a visible "Do not edit" note;
  `advisory` / `advisory-recovery` / `advisory-reroll` are the
  **plain-text** `advisory-wait:` / `advisory-wait-recovery:` /
  `advisory-reroll:` forms (no visible note) so the AW2 / shell-fallback
  recognizers still match.
- Fields per type: `claim` takes `--agent-id --claim-id --supersedes
  --timestamp --branch`; `unclaim` takes `--agent-id --claim-id --timestamp`;
  `activation-nonce` takes `--agent-id --claim-id --nonce --timestamp` (see
  `idd-claim.instructions.md`'s Activation-nonce format for when to
  post it and the collision it detects, kurone-kito/idd-skill#1522);
  `watermark` takes `--agent-id --claim-id --head-sha --max-activity-at
  --total-item-count --ci-completed-at`; `baseline` takes `--agent-id
  --claim-id --sha`; `advisory` / `advisory-recovery` / `advisory-reroll`
  take `--agent-id --head-sha --timestamp`.
- One-command watermark (`watermark` only): `--from-pr <n>` derives
  `--head-sha` / `--max-activity-at` / `--total-item-count` /
  `--ci-completed-at` from a fresh `review-activity-snapshot` of PR `<n>` and
  posts the marker to PR `<n>`, so only `--agent-id` / `--claim-id` (+ `--apply`)
  are still supplied (it always targets the PR; an explicit non-pr `--target`
  is rejected). It maps the snapshot's
  `latestPassingCiCompletedAt` to `--ci-completed-at` (the latest _passing_ CI
  completion, matching the E1 `{latest-ci-completed-at}` contract), forwards
  optional `--trusted-marker-logins` / `--advisory-bot-logins` to the snapshot
  child so its counts match the manual path, and rejects the four manual
  snapshot fields as ambiguous. Unlike the manual dry-run it reads from GitHub
  (it spawns the snapshot), but still posts nothing without `--apply`.
- `--from-pr` HEAD pin (`--expected-head-sha <sha>`): optional, `--from-pr`
  only. Pass the E1 Step 1 stored `{head-SHA}` here to guard against the
  branch moving between Step 1 and the Step 2 post: if the fresh snapshot's
  live HEAD no longer matches (case-insensitive compare), the CLI fails
  closed — it writes a `refusing to post watermark` message to stderr and
  exits non-zero **before** any POST, rather than silently posting a
  watermark keyed to a HEAD newer than Step 1 actually snapshotted. Rejected
  (exits non-zero, no `gh` call) when passed without `--from-pr`, since manual
  mode already supplies `--head-sha` directly with nothing to compare it
  against.
- `--from-pr` unaddressed-activity warning (`warnings`, kurone-kito/idd-skill#1833):
  the JSON envelope (dry-run and `--apply` alike) carries an optional
  `warnings` string array, present only when the fresh snapshot's
  `dispositionEvidence.missingRegularCommentCount` /
  `dispositionEvidence.missingThreadCount` are non-zero — comments or
  threads with **no** disposition reply at all, whose activity this watermark's
  `max-activity-at` / `total-item-count` are about to fold in as if
  already reviewed. Surfaces the same evidence
  `missing-disposition-evidence` blocks on at F2, but at watermark-post
  time instead of only later via the readiness report. Diagnostic-only:
  never blocks the post or changes `mode` / `body`. Deliberately **not**
  based on the snapshot's `ackOnly` evidence, which is the carve-out that
  marks post-disposition advisory-bot courtesy acks safe to fold in —
  warning on that would fire on the routine, benign path.
- **No claim/state gating** (the `emit-marker` philosophy): this is a
  single-marker render+POST primitive, so the calling phase must run its
  claim-revalidation gate before `--apply`, exactly as the manual POST path it
  replaces already requires.
- Stable contract: [`post-idd-marker.schema.json`][post-idd-marker-schema].

### Resume claim and route evidence

- Claim routing command:
  `node scripts/resume-claim-routing.mjs --issue <issue-number>`
- Stable fields consumed by resume instructions: `state`, `action`,
  `reason`, `active_claim`, `claim_id_checked`, `stale_age_ms`, `now`,
  `warnings`, and `evidence`
- Stable enums:
  - `state`:
    `unclaimed|already_owned|stale|non_inheritable|disputed`
  - `action`: `re_claim|takeover|keep|stop`
- Optional `--nonce <token>` (kurone-kito/idd-skill#1522): when `--claim-id`
  matches the active claim, also requires it to equal the winning trusted
  `activation-nonce` marker for that claim-id (`evidence.activation_nonce_winner`);
  a mismatch routes `state`/`reason` to `disputed` /
  `activation-nonce-mismatch` instead of `already_owned`. Omit it (or leave
  the claim-id's nonce not posted) to skip the comparison unchanged.
- `evidence.forced_handoff` (kurone-kito/idd-skill#2178): populated on
  **any** call, including a bare `--issue` call with no `--claim-id`,
  whenever a trusted, rule-7-valid `forced-handoff` marker's successor
  pair (`{old_agent_id, old_claim_id, new_agent_id, new_claim_id,
  forced_by, timestamp}`, `timestamp` the transferring comment's GitHub
  `created_at`) matches the resolved active claim; `null` otherwise. A
  bare `--issue` call whose `evidence.forced_handoff` is non-null but
  whose `state`/`action` still reads `non_inheritable`/`stop` should
  retry with `--claim-id <evidence.forced_handoff.new_claim_id>` to
  check adoption eligibility — that second call is what can turn the
  verdict into `already_owned`/`keep`.

- Step 3 route command:
  `node scripts/resume-route-selection.mjs --issue <issue-number>`
- Stable fields consumed by resume instructions: `route`, `reason`,
  `state`, and `evidence`
- Stable enum:
  - `route`: `D1|D4|E1|E15|Esync|F1|F2|stop`

### Advisory-wait evidence

- Command: `node scripts/advisory-wait-state.mjs --pr <pr-number>`
- Stable contract:
  [`advisory-wait-state.schema.json`][advisory-wait-state-schema]
- Stable fields consumed by the instructions: `prHeadSha`,
  `lastCopilotCommit`, `copilotPending`,
  `copilotPendingCoversHead`, `outcome`, `f3Outcome`,
  `earliestSameHeadAt`, `requestMarkerCount`, `requestCap`,
  `pendingWindowMinutes`, `settledWindowMinutes`,
  `pollIntervalMinutes`, `capExhaustedRoute`, and
  `trustedMarkerSummary`
- Optional `--claim-id <id> --agent-id <id>` (kurone-kito/idd-skill#1572):
  when both are supplied, binds two independent, claim/HEAD-scoped
  evidence objects to the active claim: `copilotRecovery` (the terminal
  `COPILOT_UNAVAILABLE` stall-recovery state) and `staleRequestRecovery`
  (kurone-kito/idd-skill#1571; `AW3-S`'s bounded stale-request recovery
  eligibility — `attempt` / `cap-exhausted` / `not-applicable`). Omitting
  either flag leaves `copilotRecovery.state` at `NOT_TERMINAL` and makes
  the recovery-cycle budget read as the full un-decremented cap — always
  pass both when consulting `staleRequestRecovery` for a mutation
  decision (see `idd-advisory-wait.instructions.md`'s `AW3-S`).

**Terminal stall-recovery marker contract** (`#1572`;
`idd-advisory-wait.instructions.md`'s Terminal Copilot stall-recovery
contract cites this section for the full grammar). `advisory-wait-recovery:`
supports an _optional_ bound form —
`advisory-wait-recovery: {agent-id} {PR_HEAD_SHA} {ISO8601-timestamp}
claim:{claim-id} attempt:{n}` (`n` a positive integer, `n >= 1`; `0` is
invalid) — recognized as recovery-cycle evidence only when every one of
these holds, each excluding the marker independently: the comment
author is a trusted marker actor; the body
parses as the bound five-field shape; the embedded agent id and claim
id match the active claim; the embedded HEAD SHA matches current PR
HEAD; the comment's GitHub `created_at` is a valid ISO 8601 UTC
timestamp. The clock anchor is the GitHub `created_at` of the
_earliest_ qualifying marker (embedded timestamps are diagnostics
only, mirroring the `review-watermark`/claim-heartbeat clock rule); the
completed-cycle count is qualifying-marker _presence_, never the
largest embedded `attempt`; `remaining budget = max(cap -
completedCycleCount, 0)`. Omitting both `--claim-id`/`--attempt` when
posting renders the legacy 3-field form byte-for-byte (`AW3-R`'s
procedure is unchanged); passing only one fails closed. The legacy
form stays a recognized marker but is not usable recovery-cycle
evidence, excluded from counting/anchoring like a malformed marker. A
terminal marker, `copilot-unavailable:` (same five fields, all
required, no legacy form), has no defined trigger yet — deciding when
to post it is the consuming track's job.

### CI wait policy resolution

- Source repo / vendored-node command:
  `node scripts/ci-wait-policy.mjs`
- Package-manager / ephemeral-npx command: use the
  profile-selected `idd:ci-wait-policy` command from the helper runtime
  manifest wiring above; the literal invocation is:

  ```sh
  npx --yes --package <helper-package-spec> \
    idd-ci-wait-policy
  ```

- Optional rerun-budget evaluation, preferred mechanical form: append
  `--run-id <run-id>` (with `--owner`/`--repo`, defaulting to the local
  checkout's own repository when omitted) to derive `rerunCount =
  run_attempt - 1` from the live Actions run (`gh api
  repos/{owner}/{repo}/actions/runs/{run-id}`), the same `run_attempt`
  pattern `rerun-advisory-convergence.mjs` already uses for its own
  budget check
- Optional rerun-budget evaluation, manual/offline form: append
  `--rerun-count <count>` to the selected command instead — this keeps
  working unchanged when `--run-id` is omitted, and serves as the
  explicit fallback if `--run-id`'s live lookup fails (network/
  permission error, or a missing/non-numeric `run_attempt` in the
  fetched payload). `--run-id` takes precedence over `--rerun-count`
  only when both are given and the live lookup succeeds; with no
  `--rerun-count` fallback, a failed `--run-id` lookup exits non-zero
  with a clear reason instead of silently resolving to a `0` rerun count
- Stable fields consumed by instructions or helpers:
  `policy.runningTimeout`, `policy.runningTimeoutMs`,
  `policy.generationTimeout`, `policy.generationTimeoutMs`,
  `policy.rerunPolicy`, and optional `rerunDecision.action` /
  `rerunDecision.reason`. When `--run-id` was given: `rerunCountSource`
  (`"run-id"` or `"rerun-count"`, reporting which source ultimately
  supplied `rerunDecision`'s `rerunCount`), `runAttempt` (the fetched
  run's raw `run_attempt`, only present on a successful live lookup),
  and `runIdLookupError` (only present when the live lookup failed but a
  `--rerun-count` fallback was available). When `--run-id` resolves a
  `timed_out`/`cancelled` conclusion, the helper also emits
  `failureClass` and `siblingSweep` (a same-window
  `gh run list --workflow=<name> --limit 15` of completed sibling runs)
  and `resolveCiRerunDecision` may return
  `reason: "evidence-gated-extra-rerun"` for exactly one extra attempt
  after the default `rerun-once` budget is spent -- only when every
  other completed sibling in the ±1 h window succeeded and at least one
  such sibling exists (#1997). No corroboration, a sibling non-success,
  `rerunCount >= 2`, or a non-timeout/cancelled conclusion still holds.
- it remains read-only; the command does not poll CI, rerun workflows,
  or post any GitHub comment

### CI wait state snapshot

- Source repo / vendored-node command:
  `node scripts/ci-wait-state.mjs --pr <pr-number>`
- Package-manager / ephemeral-npx command: use the
  profile-selected `idd:ci-wait-state` command from the helper runtime
  manifest wiring above; the literal invocation is:

  ```sh
  npx --yes --package <helper-package-spec> \
    idd-ci-wait-state --pr <pr-number>
  ```

- Single-shot, read-only: fetches `gh pr view`'s
  `headRefOid`/`statusCheckRollup` plus the base branch's active rules and
  classic branch protection, then reuses the same
  `summarizeBranchReviewRequirements` required-check-name resolution
  `pre-merge-readiness` already relies on — no forked required-check
  discovery.
- Stable fields consumed by D-phase polling: top-level `headRefOid` (for
  caller-side HEAD-drift detection between polls); `checks[]`, each keyed
  by both `checkName` and (trimmed) `workflowName` so two check runs
  sharing a display name across different triggering workflows are never
  collapsed into one entry, plus a normalized `status`
  (`success|pending|failure|unknown` — a commit-status `error` state
  buckets as `failure`, same as `failure`) and `required` flag; and
  `requiredChecks` (`names`, `missingNames`, `allRequiredPresent`,
  `allRequiredPassing`, `anyRequiredPending`, `anyRequiredFailing`,
  `anyRequiredUnknown`, `requiredCheckSourcePinned`,
  `requiredCheckSourcePinnedUnresolved`, and a top-level `status` of
  `success|pending|failing|missing|no-required-checks|source-pinned`)
- **Source-pinned required checks**: when a ruleset `workflows` rule or an
  app/integration-pinned classic required check is in force but cannot be
  enumerated by name, `requiredCheckSourcePinned` is `true` and `status` is
  `source-pinned` — never `no-required-checks` — so a caller cannot
  mistake an unresolvable required-check source for a vacuous pass. When
  every named required check is instead present and pass-equivalent but a
  pinned rule entry also names one of them, `status` is still
  `source-pinned` (not `success`) by default, because no producer-identity
  data is fetched anywhere in this codebase's check-run reads to verify the
  pinning (#1689) — set `ciGate.trustSourcePinnedRequiredChecks: true` in
  `.github/idd/config.json` to opt in once the repository operator has
  verified the pinned integration out-of-band; see the "Source-pinned
  required-check trust" row in [Customizing IDD](customization.md).
  `requiredCheckSourcePinnedUnresolved` is `true` when at least one pinned
  source has no resolved check name at all (a `workflows` rule, or a
  pinned classic entry with no `context`/`name`/`check`); the opt-in never
  clears `status` back to `success` while this is `true`, even when a
  separate, named-and-pinned check on the same required-check set would
  itself qualify.
- it remains read-only; the command performs no reruns and posts no
  GitHub comment

### Rerun-plan diagnosis (stuck advisory-convergence)

- Source repo / vendored-node command:

  ```sh
  node scripts/rerun-advisory-convergence.mjs --pr <pr-number> [--check-name <name>] [--apply]
  ```

- Package-manager / ephemeral-npx command: use the
  profile-selected `idd:rerun-advisory-convergence` command from the
  helper runtime manifest wiring above, with `[--check-name <name>]`
  and `[--apply]` appended the same way; the literal invocation is:

  ```sh
  npx --yes --package <helper-package-spec> \
    idd-rerun-advisory-convergence --pr <pr-number> [--check-name <name>] [--apply]
  ```

- Rerun-plan diagnosis (#1431) for a stuck `idd-advisory-convergence`
  required-check rollup, read-only by default: fetches every check-run
  instance for the PR's current HEAD SHA (paged commit check-runs API,
  `filter=all`), classifies each as `pass` / `pending` / `bot-gated-skip` /
  `unresolved` / `awaiting-fresh-review` / `rerun-eligible`, and prints
  the ordered, deduplicated `gh run rerun <id>` recovery plan for the
  rerun-eligible instances -- referenced from `idd-ci.instructions.md`
  §Rerun mechanics as the preferred way to produce that plan. An
  instance whose own advisory-convergence job-log verdict reports that
  the latest Copilot review does not cover the current HEAD is
  classified `awaiting-fresh-review` rather than `rerun-eligible`
  (#1775), so neither the diagnosis nor `--apply` burns the rerun-once
  budget on a failure only a fresh review can clear
- That job-log verdict is an immutable snapshot from when the run
  executed, so it can go stale once a fresh review lands after the run
  already failed. `rerun-advisory-convergence.mjs` also checks a LIVE
  signal (reusing `advisory-convergence.mjs`'s own latest-review
  evidence: whether the latest trusted primary-bot review's commit now
  matches the PR's current HEAD) and, when that live check confirms
  coverage, reclassifies the instance back to `rerun-eligible` instead
  of leaving it stuck forever -- the diagnosis JSON's per-instance
  `reason` field distinguishes this live-coverage recovery from an
  ordinary rerun-eligible instance. Live coverage that cannot be
  established (unreadable, or genuinely not yet covered) leaves the
  historical hold exactly as before this recovery path existed --
  fail-closed, never an invented rerun (#1806)
- Also reports a `recoveryRefreshPlan` when the rollup is stuck on a
  bot-gated instance alongside an already-passing non-bot
  pull_request-family instance — populated even alongside a non-empty
  sequential rerun plan when every rerun-eligible instance there is itself
  bot-triggered (#1745; rerunning a bot-triggered instance does not supply
  the non-bot trigger the recovery-refresh option exists to provide) — and
  honors the resolved `ciWait.rerunPolicy`: a `"hold"` policy, or an
  instance whose own
  `runAttempt` already exhausted the `"rerun-once"` budget, withholds the
  corresponding plan entries with an explanatory `rerunPolicyHoldNotice`
  instead of silently omitting them
- Also reports a `liveCoverageRecoveryPlan` (kurone-kito/idd-skill#2549):
  a narrow, separately-bounded exception for an instance that is
  BOTH the live-coverage-recovery case above AND itself
  `rerun-budget-held` (its own `runAttempt` already exhausted the
  `"rerun-once"` budget) AND has a sibling instance for the same check
  that already classifies `pass` -- proof the rollup is otherwise
  already resolved, so rerunning this one is bounded cleanup of a
  redundant stale sibling on an already-covered HEAD, never a second
  automated rerun-budget grant. Every other `rerun-budget-held`
  instance (including the waiver-rebind case below) keeps the
  unconditional withholding unchanged; each promoted instance's
  original hold reason is named both in the plan document
  (`originalHoldReason`) and in the `--apply` summary
- Without `--apply`, it never calls `gh run rerun` (or any other mutating
  command) itself. Pass `--apply` (#1766) to execute the printed plan:
  it reruns each rerun-eligible instance in order (recovery-refresh
  first, then the sequential plan, then `liveCoverageRecoveryPlan`
  last), waits for each to reach a genuinely new completed attempt
  (polled via the actions/runs API, not `gh run watch`, to avoid racing
  a just-issued rerun's stale pre-rerun status) before starting the
  next, and stops early once the recomputed plan is fully resolved --
  a `bot-gated-skip`, `awaiting-fresh-review`, or rerun-budget-held
  instance is never rerun outside the narrow `liveCoverageRecoveryPlan`
  exception just above, and the same `MAX_APPLY_RERUNS` safety bound
  covers all three plan sections together, not a second loop
- `--check-name <name>` (#1935) overrides the check-run name searched for
  and reported, defaulting to `idd-advisory-convergence` when omitted
  (byte-identical output to before this flag existed). Use it when the
  job that produces the check has a `name:` display-name key on top of
  an unchanged job id -- GitHub Actions then names the check-run after
  that display name instead of the job id, so the default search
  silently finds nothing; see the job-definition comment in
  `.github/workflows/idd-advisory-convergence.yml` for the full warning.
  The not-found message names whichever check-run name was actually
  searched, so a mismatch names its own cause instead of only its
  symptom

### Manual recovery: budget-held instance after a waiver rebind

`rerun-advisory-convergence.mjs --apply` deliberately never touches a
`bot-gated-skip`, `awaiting-fresh-review`, or `rerun-budget-held`
instance (see above) -- that withholding is correct and load-bearing
on its own, and this section does not change it: the script keeps
withholding these instances from its own plan, and gains no
`--override-budget` flag or equivalent. `liveCoverageRecoveryPlan`
above (#2549) is a separate, much narrower automated exception (a
live-coverage-recovered instance with an already-passing sibling
proving the rollup is otherwise resolved) -- it does not apply to the
waiver-rebind case below, which still requires this manual procedure.
A specific combination sits
outside what the withholding alone can resolve: an
`idd-advisory-convergence` instance already went `rerun-budget-held`
from a genuinely-failed attempt, and only afterward does a maintainer
post a valid `idd-external-check-waiver:` marker covering the current
HEAD and check. The held instance's recorded failure predates the
waiver and has nothing left to say about current mergeability, but the
waiver alone does not make GitHub re-evaluate an already-completed
check-run.

This is a maintainer-authorized manual override, not a helper flag and
not something a worker performs unprompted -- the same deliberate
human-judgment-gate philosophy as
`ciGate.externalCheckWaivers.mode: "maintainer-authorized"` itself.
Confirm all three before running it:

1. The held instance's own run targets the PR's current HEAD SHA, not
   a stale, already-superseded push.
2. A maintainer-authorized `idd-external-check-waiver:` marker (see
   the marker format above) now covers that same HEAD and check
   selector, and is itself valid -- unexpired, correctly claim-bound,
   posted by a trusted actor.
3. The held instance's recorded failure reason (the rerun-plan
   diagnosis's `rerunPolicyHoldNotice` for that instance, or the run's
   own log) predates the waiver -- the waiver is the reason to
   reconsider this instance, not an unrelated later development.

Only once all three hold, issue `gh run rerun <run-id>` on that
specific instance directly -- a one-time, visible, auditable exception
to the budget withholding, not a config flag exercisable as
reflexively as any other CLI option.

### Merge-gate evidence

- When helper runtime is enabled, these commands are the preferred
  evidence collection path for E1/F2/F3 review-currency and merge-gate
  checks.
- Snapshot command: `node scripts/review-activity-snapshot.mjs`
  with `--pr <pr-number>` and
  `--trusted-marker-logins "<trusted-login-1>,<trusted-login-2>"`
  (optionally `--advisory-bot-logins "<bot-1>,<bot-2>"`; the identity
  also resolves from `IDD_ADVISORY_BOT_LOGINS` or the config
  `advisoryBotLogins` field, with the source echoed in
  `ackOnly.source`)
- Stable E1/F2/F3 snapshot tuple: `headSha`,
  `maxActivityUpdatedAt`, `totalItemCount`,
  `latestPassingCiCompletedAt`, and `counts`
- Additional CI completion field: `latestCiCompletedAt` reports the
  latest terminal run of any state; watermark and merge-gate checks use
  `latestPassingCiCompletedAt`
- Structural ack-only evidence (requires a current helper copy): the
  snapshot and `reviewCurrency.live` emit `ackOnly` (configured bots,
  source, `dispositionsPresent`, `latestDispositionAt`, per-item list)
  and `effective` activity values; `comparisonReason:
  ack-only-post-disposition` marks a review-currency pass that relied
  on them. The semantic residual stays with the agent per the
  courtesy-ack convergence rule, and the disposition-evidence and
  unreplied-comment gates are unaffected
- Disposition-evidence counters (kurone-kito/idd-skill#1833): the
  snapshot also emits `dispositionEvidence` (`missingRegularCommentCount`,
  `missingThreadCount`) — the same `summarizeDispositionEvidenceForGate`
  evidence the F2 `missing-disposition-evidence` gate uses, trimmed to
  its two counters (mirrors `advisory-convergence.mjs`'s own trimmed
  projection of the same evidence, not `pre-merge-readiness.mjs`'s
  richer field). A `--from-pr` watermark post
  (`node scripts/post-idd-marker.mjs`) reads these to warn, in its own
  success output, when the watermark it is about to post already covers
  comments/threads that were never actually dispositioned
- Readiness command: `node scripts/pre-merge-readiness.mjs`
  with `--pr <pr-number>`, `--claim-issue <issue-number>`,
  `--claim-id <claim-id>`, optional `--nonce <token>` (this session's own
  locally-recorded activation-nonce from claim time;
  kurone-kito/idd-skill#1522, kurone-kito/idd-skill#1528 — omit when no
  nonce was recorded for the active claim, which stays backward
  compatible), and
  `--trusted-marker-logins "<trusted-login-1>,<trusted-login-2>"`.
  `--claimless` (#2017) is the no-issue alternative: it cannot combine
  with `--claim-issue` or `--claim-id`, and it is honored only when the
  PR's `closingIssuesReferences` is empty (otherwise fail closed and
  pass `--claim-issue`). It skips claim fetch/revalidation and emits
  the not-applicable / unclaimed ownership shape (claim-id `none`); CI,
  review, advisory, thread, and branch-currency gates still run.
  `idd-merge-execute` still requires `--claim-issue`.
- Stable contract:
  [`pre-merge-readiness.schema.json`][pre-merge-readiness-schema]
- Stable sections consumed by the instructions: `reviewCurrency`,
  `threads`, `unrepliedComments`, `reviewerStates`,
  `advisoryWait` (including the effective advisory policy fields), `ci`,
  `claim`, `branchCurrency`, and optional `dispositionEvidence`
- `branchCurrency` (#1513) pairs the PR's live `mergeable` /
  `mergeStateStatus` with whether the base branch's protection or ruleset
  requires an up-to-date head before merge. `requiresUpToDateHead` is
  `true` when a readable ruleset or classic-protection rule confirms it,
  or when the underlying protection/ruleset read is unreadable (fails
  closed to `true` rather than reporting "no requirement");
  `requiresUpToDateHeadSource` records which (`ruleset`,
  `classic-protection`, `unreadable-fail-closed`, or `none`). A live
  `mergeStateStatus: "BEHIND"` paired with `requiresUpToDateHead: true`
  is a `branch-currency` merge-gate blocker (see below); `UNKNOWN` is the
  async-still-computing state F1 and the E-phase branch-sync check
  already re-poll, not a blocker here.
- `ci.discardedNonPassingRequiredChecks` (#1745) surfaces a same-producer
  (name/type/workflowName/workflowPath -- kurone-kito/idd-skill#2919 widened
  this from the original name/type/workflowName 3-tuple) required-check
  instance discarded by the latest-per-producer dedup while the surviving
  representative is pass-equivalent -- e.g. a
  `CANCELLED` bot-triggered instance sitting alongside the `SUCCESS`
  instance the dedup selected as "latest", the live PR #1741 divergence
  where `ci.status: "success"` disagreed with GitHub's own
  `statusCheckRollup.state: "FAILURE"` for the same commit. Always
  emitted (empty array, never omitted, when nothing was discarded). A
  non-empty list does not by itself gate F2/F3; it is a prompt to
  double-check the live GitHub rollup rather than trusting a bare
  `ci.status: "success"`. Combined with live
  `mergeStateStatus: "BLOCKED"` it is also a
  `discarded-required-check-siblings` merge-gate blocker (#2127):
  recover via `rerun-advisory-convergence`, do not merge or `--admin`.
  An empty or absent list never fires that gate, so a CODEOWNER-only
  `BLOCKED` path is unchanged.
- `ci.sourcePinnedRequiredCheckNames` (#1689) lists the required check
  names whose green state was downgraded to `ci.status: "unknown"` because
  their ruleset/classic-protection entry is source-pinned
  (`app_id`/`integration_id`) and the `ciGate.trustSourcePinnedRequiredChecks`
  opt-in was not set. Producer verification itself is not implemented (no
  GitHub App identity is fetched for a live check-run anywhere in this
  codebase); the opt-in is a human-authorized trust decision, not a
  runtime check. Evidence only (empty array, never omitted, when no such
  downgrade occurred) --
  `computePreMergeReadinessBlockers` uses it to name the source-pinned
  cause in the `ci` blocker detail instead of a generic "CI is not
  all-passing" message; see [Customizing IDD](customization.md)'s
  "Source-pinned required-check trust" row for the opt-in.
  `ci.sourcePinnedUnresolved` is a sibling boolean, `true` when the
  downgrade fired at least partly because of a pinned source with no
  resolved check name (a ruleset `workflows` rule, or a pinned entry with
  no `context`/`name`/`check`) -- distinct from
  `sourcePinnedRequiredCheckNames` being empty, which alone is ambiguous
  between "no pinning" and "pinning exists but is unnamed." The
  `trustSourcePinnedRequiredChecks` opt-in never clears this cause, even
  when a separate, named-and-pinned check on the same required-check set
  would itself qualify.
- `ci.identityUnresolvedRequiredCheckNames` (kurone-kito/idd-skill#2919,
  round 2) mirrors `ci.sourcePinnedRequiredCheckNames`'s own shape for a
  different unverifiable-producer case: required check names whose green
  state was downgraded to `ci.status: "unknown"` because this collection
  pass could not fully resolve their real workflow-file producer identity
  (`workflowPath`) -- a parse failure on some but not all live instances, a
  thrown `listCheckRunWorkflowPaths` call, an empty resolved path, a
  run-id count exceeding the collector's own lookup ceiling, or a
  `detailsUrl` that repeats -- either among the resolved
  `checkSuite.workflowRun` associations or among the live rollup's own
  matching instances -- and so cannot be joined back to a single instance
  safely (kurone-kito/idd-skill#2926). Today this can only ever name
  `idd-advisory-convergence`, the one check name `pre-merge-readiness`
  attempts `workflowPath` resolution for. Evidence only (empty array, never
  omitted, when no such downgrade occurred) -- `computePreMergeReadinessBlockers`
  uses it (alongside `ci.preDowngradeStatus` below) to name the
  identity-unresolved cause in the `ci` blocker detail.
- `ci.preDowngradeStatus` (kurone-kito/idd-skill#2919, round 5) is the
  dedup+waiver-adjusted `ci.status` classification captured BEFORE either
  the source-pinned or identity-unresolved downgrade above could narrow
  it -- `"success"` here means every OTHER required check was already
  fully resolved as passing, so any non-success final `ci.status` can only
  be attributed to those two named downgrades. `computePreMergeReadinessBlockers`
  reads this to decide whether a genuinely separate, concurrent CI failure
  (an unrelated required check that is actually failing/pending/missing)
  also needs naming in the `ci` blocker detail, rather than letting a
  pinned/identity-unresolved cause's own detail text silently replace it.
  `"unknown"` when no required checks are configured, mirroring
  `ci.status`'s own initial default in that case.
- Authoritative phase role: the live `pre-merge-readiness` run on the
  current HEAD is the **authoritative source for the final-merge CI and
  activity fields** at F2/F3. The `review-activity-snapshot` helper builds
  the **E-phase** activity universe (E1) for review currency; do not reuse
  its CI/activity values as the F-phase merge decision (they can diverge in
  the pre-merge window)
- `reviewerStates.codeownerSelfApproval` diagnoses whether CODEOWNER
  approval can be satisfied by an eligible non-author owner or an
  applicable ruleset or classic pull-request bypass. `deadlock` and
  `possible_deadlock` statuses should be surfaced in F2 evidence and
  hold comments, but they do not grant bypass permission. The
  `currentUserCanBypass` token records the known GitHub ruleset value
  (`unknown`, `never`, `always`, `pull_requests_only`, `exempt`, or
  `mixed`).
- A `clear` diagnostic means the helper found a GitHub topology that
  appears satisfiable for the current actor; it is still evidence for
  the written F2/F3 gates, not an IDD policy override or permission to
  skip review, CI, freshness, advisory, unresolved-thread, or claim
  checks. Note that `clear` alone does not distinguish the genuine
  solo-CODEOWNER self-approval deadlock from a topology where a
  distinct non-author codeowner simply has not reviewed yet (both can
  report `status: "clear"`) — see `prAuthorIsSoleEligibleCodeowner`
  below for the field that does distinguish them.
- `prAuthorIsSoleEligibleCodeowner` (#1521) is an additive topology
  fact, independent of `status`/`reason`: `true` only when the PR
  author is the sole eligible codeowner (no team codeowners, no email
  codeowners, at least one eligible direct-user codeowner, and every
  eligible direct-user codeowner equals the author). This is the only
  field the F3 solo-CODEOWNER `--admin` fallback (below) may key on; a
  genuinely outstanding review from a different, non-author codeowner
  reports this as `false` even when `status` is `"clear"` via the
  bypass-actor carve-out.
- `codeownerEligibilityUnreadable` (#1521) is `true` when at least one
  direct-user codeowner's collaborator-permission lookup failed for a
  reason OTHER than "not a collaborator" (403/5xx/network/timeout).
  `prAuthorIsSoleEligibleCodeowner` is forced to `false` whenever this
  is `true`, regardless of how narrow the (possibly incomplete)
  eligible set otherwise looks: a transient lookup failure for a
  genuinely eligible non-author codeowner must never be silently
  treated the same as that codeowner having no write access at all.
- `advisoryWait.copilotUnavailable` / `advisoryWait.copilotUnavailableWaived`
  (kurone-kito/idd-skill#1570): a caller-precomputed terminal
  `COPILOT_UNAVAILABLE` verdict (kurone-kito/idd-skill#1572's
  `buildCopilotRecoverySummary`) and whether a valid maintainer
  `idd-advisory-convergence` external-check waiver clears it. `f3Outcome`
  is unchanged by these fields; instead, `copilotUnavailable: true` with
  `copilotUnavailableWaived: false` adds a dedicated
  `copilot-terminal-unavailable` entry to `blockers[]`, additive to the
  existing `advisory-wait` blocker. Observed incident:
  kurone-kito/idd-skill#1562 (a Copilot review request that never proved
  it covered current HEAD). See `idd-advisory-wait.instructions.md`'s
  Terminal routing section.
- `reviewCurrency.comparisonRoute` remains advisory evidence only. Agents
  must still apply written instruction checks against live GitHub state.
- Fail closed: if helper execution fails, output is invalid JSON,
  required fields/sections are missing, or helper evidence conflicts with
  live GitHub state, discard helper output and use the portable manual
  fetch path.

### Merge execution (F3)

- Preferred F3 path when helper runtime is enabled: dry-run first to
  inspect the verdict, then `--apply` to execute the bound merge.
- Command: `node scripts/idd-merge-execute.mjs --pr <pr-number>
  --claim-issue <issue-number> --claim-id <claim-id>` plus the same
  optional flags as `pre-merge-readiness` (`--agent-id`, `--owner`,
  `--repo`, `--trusted-marker-logins`, `--advisory-bot-logins`); add
  `--apply` to merge.
- Stable contract:
  [`idd-merge-execute.schema.json`][idd-merge-execute-schema]
- It WRAPS the read-only `pre-merge-readiness` collector and adds no new
  decision authority (`decisionAuthority: instructions`). `ready` is
  `true` only when every F3 gate holds: review-currency
  `comparisonRoute == "proceed"`, `threads.actionableCount == 0`,
  advisory `f3Outcome == "SATISFIED"`, CI all-passing (the F2/F3
  no-required-checks fallback included), required/CODEOWNER reviews
  satisfied, claim ownership matches, disposition evidence both
  routes proceed and is unblocked (`dispositionEvidence.route ==
  "proceed"` **and** `dispositionEvidence.blockingCount == 0`; `route`
  alone is not sufficient), and branch currency does not block (#1513: a
  live `mergeStateStatus: "BEHIND"` paired with a confirmed-or-assumed
  `branchCurrency.requiresUpToDateHead: true` fails closed as a
  `branch-currency` blocker before `--apply` ever calls `gh pr merge`).
  A live `mergeStateStatus: "BLOCKED"` paired with a non-empty
  `ci.discardedNonPassingRequiredChecks` list is a
  `discarded-required-check-siblings` blocker (#2127).
  Each failing gate is listed in `blockers[]`
  as `{ gate, detail }`.
- Dry-run (default) is read-only: it prints `ready`, `blockers`, and
  `mergeCommand` (a `gh pr merge <pr> --merge --match-head-commit
  <validated-head>` bound to the freshly fetched head) and never merges.
  It exits non-zero when not ready.
- `--apply` is the only mutating path. If not `ready` it exits non-zero
  without merging. If `ready` it re-fetches the head SHA and re-validates
  the claim immediately before merging and **fails closed** (exit
  non-zero, no merge, clear message) on any head drift or lost claim.
  Otherwise it runs the merge commit bound to the validated head and
  reports the result. It never squash- or rebase-merges.
- **Solo-CODEOWNER `--admin` fallback (#1521).** If the plain merge
  command fails with GitHub's "base branch policy prohibits the merge"
  error, the helper checks `mergeGate.soloCodeownerAdminFallback` in
  `.github/idd/config.json` (distributed default `auto-admin-retry`;
  absent behaves the same). Unless the repository has set it to
  `hold-and-report`, it retries exactly once with `--admin`, bound to
  the same validated head, but ONLY when the freshly re-validated
  report's `reviewerStates.codeownerSelfApproval` has `status: "clear"`
  with `reason` `"pull-request-bypass-available"` or
  `"ruleset-bypass-available"` **and**
  `prAuthorIsSoleEligibleCodeowner: true` **and**
  `codeownerEligibilityUnreadable: false`. Those last two fields are
  the multi-CODEOWNER safety property: additive to `status`/`reason`,
  they prove the PR author is the sole eligible codeowner (no team or
  email codeowners, every eligible direct-user codeowner is the
  author, and every direct-user codeowner's permission lookup actually
  succeeded). A genuinely outstanding review from a different,
  non-author codeowner reports `prAuthorIsSoleEligibleCodeowner: false`
  even when `status` is still `"clear"` via the bypass-actor carve-out
  (that carve-out resolves before the non-author-owner check runs in
  `summarizeCodeownerSelfApproval`), and a transient/auth/rate-limit
  permission-lookup failure reports `codeownerEligibilityUnreadable:
  true` rather than silently narrowing the eligible set — both
  register as their own unmet condition and never trigger this retry.
  The helper also re-validates the SAME gate and eligibility fact a
  SECOND time, immediately before the `--admin` call itself: real time
  passes between the plain merge's failure and the retry, and
  `--admin` bypasses the entire ruleset (not just the CODEOWNER rule),
  so a blocker that appeared in that interval must still abort the
  fallback rather than being silently bypassed. Immediately before the
  retry it also requires live GitHub merge state
  `mergeable: "MERGEABLE"` and `mergeStateStatus: "CLEAN"` or
  `"BEHIND"`; blocked, unknown, or unreadable state aborts the fallback
  rather than allowing a generic policy error to trigger `--admin`.
  `"BLOCKED"` stays excluded because field evidence
  (kurone-kito/idd-skill#1663, 2026-08-06 and 2026-08-17) showed it is
  often cancelled or stale required-check instances, a missing
  review-watermark, or incomplete F2 — not a confirmed CODEOWNER
  deadlock. A live `"BLOCKED"` paired with discarded required-check
  siblings is the separate `discarded-required-check-siblings` gate
  (kurone-kito/idd-skill#2127), not a reason to admit `"BLOCKED"` into
  the `--admin` retry. See `docs/permissions.md` for the `code_quality`
  ruleset-rule read path and its F3 limitation.
  The verdict's `adminFallbackUsed` field records whether the fallback
  fired (`true`) whenever it was attempted, regardless of whether the
  `--admin` retry itself ultimately succeeded. Any merge failure that
  does not match this exact shape — a different error, an ineligible
  topology, or the opt-in `hold-and-report` policy — falls through
  unchanged to the pre-#1521 hold-and-report path.
- **Local-head-drift warning (#2453).** In both dry-run and `--apply`,
  the helper best-effort reads the invoking process's local git branch
  and HEAD. When that local branch equals the PR's own `headRefName`
  and the local HEAD differs from `prHeadSha`, the verdict's
  `localHeadDrift` field is set to `{ localHeadSha, remoteHeadSha }` and
  a warning is also printed on stderr — the signature of an unpushed
  commit about to be silently left behind. It is advisory only: `null`
  whenever the check cannot run (no git repo, a different or detached
  branch, or an unreadable local/remote read) or finds no divergence,
  and it never gates `ready` or blocks the merge.
- Fail closed: if helper execution fails, output is invalid JSON,
  required fields are missing, or helper evidence conflicts with live
  GitHub state, discard helper output and run the manual F3 gate +
  merge steps in `idd-merge.instructions.md`. The written F3 decision
  table and gate checklist remain canonical.

### Advisory convergence (F2)

- Read-only policy-engine helper (#1340) that deterministically asserts
  whether the primary advisory bot's ("Copilot's") review has _converged_
  on the current PR HEAD: `converged` = (the latest primary-bot review's
  `commit_id` equals the current HEAD **and** that review carries zero
  actionable items) **and** (every current-HEAD primary-bot-authored review
  thread is resolved **or** carries a valid disposition marker).
- Command: `node scripts/advisory-convergence.mjs --pr <pr-number>
  [--claim-issue <issue-number>] [--owner <owner>] [--repo <repo>]
  [--trusted-marker-logins "<login1,login2>"]
  [--advisory-bot-logins "<bot1,bot2>"] [--now <ISO8601>] [--assert]`.
  Unlike `pre-merge-readiness`, no claim flags are required: the linked
  issue (and its active claim, needed only for the waiver check below) is
  auto-discovered from the PR's closing references, the same way
  `external-check-waiver.mjs`'s `--apply` path already resolves it — so
  this helper also works as a claim-independent, required-check-able CI
  verdict (the intended shape for #1341's workflow).
- Stable contract:
  [`advisory-convergence.schema.json`][advisory-convergence-schema]
- Every invocation other than `--help`/`-h` prints the JSON verdict.
  Without `--assert` it always exits `0` (report-only). With `--assert` it
  exits non-zero unless `ready` is `true` (`ready = not_applicable ||
  converged || ((deadline passed || terminal-unavailable) && validly
  waived) || autoWaiverValid`, the last disjunct added by
  kurone-kito/idd-skill#2657 -- see the self-referential-bootstrap-auto
  waiver section above; `waiver.autoWaiverValid` in the verdict reports
  it directly, since every other `waiver.*` field stays gated behind the
  deadline/terminal precondition this new disjunct is not).
- **Structured `nextActions` (`#2143`)**: the verdict also reports a
  `nextActions` array populated from the same catalog the `--assert`
  failure stderr block uses (`collectAssertNextActions`). Each item
  has `token` (stable enum), `summary` (one-line English), and
  `pointer` (the command or phase pointer already printed on stderr;
  multi-command pointers are newline-separated). Ready verdicts emit
  `nextActions: []`. `ready` does not depend on this field, and
  `reasons[]` stays diagnostic state -- do not overload it.
- **Review-policy applicability (`#2137`)**: this helper reads
  `reviewPolicy` from `.github/idd/config.json`. Exact
  `human-required` or `no-advisory` classifies the PR `not_applicable`
  (reasons `review-policy-human-required` /
  `review-policy-no-advisory`) so `--assert` exits 0 through the
  existing `scopeNotApplicable` path, not by faking `converged`.
  Copilot review/thread clauses do not apply; human approval and
  conversation resolution stay on branch protection and the phase
  files. `copilot-advisory`, absent, or an invalid value keep today's
  fail-closed Copilot applicability. `external-bot` keeps the
  configured `primaryBotLogin` path. A trusted human approve is never
  a Copilot substitute under `copilot-advisory`. Do not invent a new
  `convergenceScope` value for this. Do not register
  `idd-advisory-convergence` as a required check unless the policy
  actually wants an advisory-bot gate.
- **Bounded "not reviewed yet" poll (`#2015`)**: the CLI entry point runs
  through `runAdvisoryConvergenceWithPoll`, not `runAdvisoryConvergence`
  directly. When (and only when) the verdict's sole blocking reason is
  literally "`{bot}` has not reviewed this pull request yet" — the primary
  bot has never reviewed the PR at all yet, not merely an off-HEAD review —
  it polls a short, bounded window (every
  `DEFAULT_COPILOT_REVIEW_POLL_INTERVAL_MS`, default 7.5s, up to
  `DEFAULT_COPILOT_REVIEW_POLL_MAX_WAIT_MS`, default 60s) before its real
  `--assert`-driven exit, absorbing the common race where the hosting
  workflow's `pull_request`/`pull_request_target` `synchronize` trigger
  fires before the primary bot's own review has landed. (Through
  Phase 1 of the shipped `idd-advisory-convergence.yml` template's own
  trigger topology, `#2764`, a review landing refreshed this same run
  via a direct `pull_request_review` trigger on the hosting workflow
  itself; that trigger now lives on the non-required companion
  `idd-advisory-convergence-comment.yml` instead, which reruns the
  existing required run via
  `rerun-advisory-convergence.mjs --refresh-latest --apply` (not the
  budget-gated plain `--apply` the two comment-family triggers share) --
  see that flag's own doc comment in `rerun-advisory-convergence.mts`
  for why a review submission needs the stronger mode. This move keeps
  the required workflow's own trigger list free of a same-repository
  PR's ability to disable or reshape a review-triggered rerun of its
  required check, though the companion itself stays exactly as
  PR-editable as that former direct trigger was; the push-triggered
  gate (via `pull_request_target`, also `#2764`) is what actually stays
  trusted.) Every other
  not-ready reason (an off-HEAD review, unresolved threads, an
  indeterminate claim scope, a deadline/terminal reason, etc.) still fails
  immediately with no wait, exactly as before this addition — the
  exit-code contract and `ready` formula above are otherwise unchanged.
  The poll's bound is wall-clock (a deadline, not a sleep-count): each
  sleep is capped to the remaining budget, and a re-check is never
  launched once a sleep has already consumed all of it (PR #2023 review
  round 2). Known residuals (PR #2023 review): (1) a re-check that starts
  just _before_ the deadline (while genuine budget remains) can still run
  long, bounded only by `gh-exec.mts`'s own per-call `gh` timeouts (up to
  120s for a paginated call, `#1675`), not by `maxWaitMs` — closing that
  gap would mean threading a remaining-budget deadline into every `gh`
  call inside `collectFromGitHub`, out of scope for this narrow poll
  wrapper; (2) as of `#2764` Phase 1, a review landing while this poll
  is asleep no longer starts a fresh trigger directly in the hosting
  workflow's own PR-scoped `cancel-in-progress` concurrency group (see
  the parenthetical above) — it instead reaches this run only
  indirectly, via the companion's `gh run rerun` on an already-terminal
  instance. Whether that indirect path can still race and cancel a
  still-polling sibling is not re-derived here; see the full poll
  analysis in `runAdvisoryConvergenceWithPoll`'s doc comment
  (`src/scripts/advisory-convergence.mts`).
- **Deadlock / deadline policy**: while the primary bot has not reviewed
  the current HEAD, `pending` is `true` and the gate is not ready. After
  `advisoryWait.convergenceDeadline` (default 24h; see
  [policy constants](policy-constants.md#advisory-review-defaults)) has
  elapsed since the current HEAD commit's own timestamp, the only pass
  path is a valid maintainer external-check waiver for that HEAD under the
  selector `idd-advisory-convergence` (reusing the same
  `<!-- idd-external-check-waiver: ... -->` marker format and validity
  rules as `external-check-waiver.mjs`). Gated by the same two-dimensional
  opt-in every other external-check waiver already requires:
  `ciGate.externalCheckWaivers.mode == "maintainer-authorized"` **and**
  `idd-advisory-convergence` registered under
  `ciGate.externalChecks.waivable` — enabling waiver mode for some other
  external check never silently makes this gate waivable too.
- **Terminal Copilot unavailability (`#1570`)**: the verdict also reports
  a `terminal` field (kurone-kito/idd-skill#1572's
  `CopilotRecoverySummary` shape — cap/window/clock evidence and
  `state: "NOT_TERMINAL" | "COPILOT_UNAVAILABLE"`), reported separately
  from `deadline`. When `terminal.state` is `COPILOT_UNAVAILABLE`, the
  SAME waiver escape hatch above also opens — independent of whether the
  ordinary deadline has passed — but `ready` still requires a valid
  waiver in addition (`ready = not_applicable || converged ||
  ((deadline.passed || terminal.state == "COPILOT_UNAVAILABLE") &&
  waived) || autoWaiverValid`, the last disjunct unaffected by this
  section — kurone-kito/idd-skill#2657's self-referential-bootstrap-auto
  waiver above); the terminal state alone never sets `ready: true`. A
  `not_applicable` applicability (including `reviewPolicy`
  `human-required` / `no-advisory`) is an independent ready path and
  does not change this waiver rule. Observed incident:
  kurone-kito/idd-skill#1562. See `idd-advisory-wait.instructions.md`'s
  Terminal routing section for the full hold/rerun sequence.
- **Eligibility-relevant disposition-evidence counters (`#1719`)**: the
  verdict also reports a `dispositionEvidence` field —
  `{ missingRegularCommentCount, missingThreadCount }` — a narrow,
  counters-only projection of the same evidence
  `summarizeDispositionEvidenceForGate` already computes for this gate. It
  exposes the numeric input behind `sameHeadReroll.eligible`'s
  `missing-regular-comment-disposition` term (see below) directly on the
  report, instead of only its pass/fail verdict. Not the same shape as
  `pre-merge-readiness.mjs`'s own `dispositionEvidence` field (which
  additionally carries `route` / `blockingCount` / full missing-item lists
  for the F2 merge gate) — this gate's `dispositionEvidence` never gates
  anything by itself.
- Reuses the existing evidence modules — `isCopilotReviewerLogin` /
  `readAdvisoryPrimaryBotLogin`, `resolveAdvisoryBotLogins`,
  `resolveTrustedMarkerActors`, `summarizeDispositionEvidenceForGate`,
  `summarizeClaimValidation`, and `summarizeExternalCheckWaivers` — rather
  than duplicating review- or waiver-parsing logic; only the
  Copilot-thread-authorship filter and the review-item-count read are new.
- Claim resolution for the waiver escape hatch is forced-handoff-aware and
  collaborator-marker-trust-aware (#1344, #1347), matching
  `pre-merge-readiness.mjs` in spirit: with `forcedHandoff.mode:
  "human-gated"` enabled, a verified handoff on the linked claim issue
  transfers `activeClaimId` to the successor (including the Part B (#1058)
  allowance for an `issue-only` handoff that predates the PR); with
  `markerTrust.allowCollaboratorMarkers` (or
  `IDD_TRUST_COLLABORATOR_MARKERS`) enabled, a Write/Maintain/Admin
  collaborator's marker-shaped comment on the PR **or on the linked claim
  issue** adds them to the trusted-marker set — claim and forced-handoff
  markers are always posted to the claim issue, never the PR, so the
  claim-issue side is not optional coverage. This gate auto-discovers
  among every issue the PR closes (unlike `pre-merge-readiness.mjs`'s
  single required `--claim-issue`), so the collaborator scan and the
  active-claim disambiguation both cover every candidate issue's comments,
  not just the one ultimately picked. Both stay no-ops when the repository leaves
  them at their (disabled) defaults.
- Fail closed: if helper execution fails, output is invalid JSON, or
  required fields are missing, discard helper output and apply the
  written F2 advisory/disposition sub-gate check manually.
- `advisoryWait.convergenceScope` controls whether advisory convergence
  applies to every PR or only verified IDD-owned PRs. The default
  `all-prs` keeps the helper applicable everywhere. `idd-claimed`
  narrows it so a verified linked claim with a matching PR head branch
  is `applicable`; a verified linked claim still stays `applicable`
  when branch data is unavailable; and a PR with no verified linked
  claim AND no claim-marker history at all (a genuine non-IDD
  contribution, including manual/dependency PRs) is `not_applicable`.
  Claimless maintainer waivers stay outside this conditional scope; the
  normal deadline-based waiver path still applies only to applicable,
  verified IDD-owned PRs. Invalid or unreadable config values still
  normalize back to `all-prs` in trusted config reads.
  - `status: "indeterminate"` (#1686): a third outcome, distinct from
    both `applicable` and `not_applicable`, for a PR that carries real
    evidence of IDD claim activity but whose claim linkage cannot be
    resolved cleanly right now -- a claim-branch mismatch against an
    active trusted claim, closing references ambiguous between two or
    more actively-claimed issues, or a stale/released claim (claim
    marker history exists, but no claim currently resolves active).
    Unlike `not_applicable`, `indeterminate` never lets `ready` become
    `true` through ordinary convergence -- only the existing
    deadline/terminal-plus-maintainer-waiver escape hatch can still
    clear it (and, for the ambiguous/stale-history cases, no
    `activeClaimId` exists to bind a waiver to in the first place, so
    those two are effectively not waivable in practice; the
    branch-mismatch case does have a real `activeClaimId` and stays
    genuinely waivable). See
    `computeAdvisoryConvergenceVerdict`'s `AdvisoryConvergenceApplicability`
    doc comment (advisory-convergence.mts) for the full contract.
- `advisoryWait.exemptBotAuthoredPrs` (#1906): opt-in, off by default,
  and effective only under `convergenceScope: "all-prs"` (`idd-claimed`
  already resolves the same PR shape `not_applicable` via the
  `idd-claimed-no-verified-linked-issue-claim` branch just above, so this
  flag changes nothing there). When `true`, a PR whose author resolves to
  a GitHub Bot-typed account (fetched via a small dedicated GraphQL
  `__typename` query) AND has no claim-marker history at all resolves
  to `not_applicable` (reason `bot-authored-no-claim-history`), letting
  a recurring automated dependency-update PR (Dependabot, Renovate,
  ImgBot, or similar) pass
  the gate without a fresh per-PR maintainer waiver. A Bot-typed author
  that DOES have claim-marker history, or any human-authored PR, is
  never exempted regardless of this flag. The `scope-not-applicable`
  same-HEAD-reroll token below already covers this new `not_applicable`
  cause too, since its underlying check reads `applicability.status`
  generically, not `convergenceScope` specifically.

#### Bounded same-HEAD advisory reroll (AW6, #1511)

`converged`'s Clause 1 reads a **static** snapshot of the primary bot's
review item count, taken once at submission. When that review already
covers current HEAD but carried N>0 items that triage then legitimately
**Rejected** and resolved, `converged` stays false permanently for that
HEAD: rejecting the items and resolving their threads never changes the
stored count, and nothing else refreshes it without a new push. This is
exactly the residual AW1's own `SATISFIED` short-circuit cannot escape
(`commit_id == HEAD` never changes across a same-HEAD reroll), and the
reason the Zero-Accepted-PATH-A advisory re-review gate
(`idd-review-triage.instructions.md`) deliberately does not re-request
in this state.

The verdict's `sameHeadReroll` field group surfaces this residual as
evidence, purely additively: `converged` / `waived` / `ready` are
computed with **no reference to it at all**, so it can never let the
gate pass on anything but the primary bot's own real signal.

| Field               | Meaning                                                                                                                                                                                                                                                                                                                                                                                       |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `eligible`          | `matchesHead: true`, `itemCount` known AND (`itemCount > 0` OR `suppressedCount > 0`, #1880), every Copilot-authored thread resolved or validly dispositioned, AND no outstanding regular-comment disposition evidence (`dispositionEvidence.missingRegularCommentCount === 0`) -- the static count is the ONLY thing keeping `converged` false, with no other triage work still outstanding. |
| `ineligibleReasons` | `#1719`: one stable, machine-readable token per failing term of the `eligible` conjunction above (empty exactly when `eligible` is `true`), so a caller can self-diagnose a stuck reroll without re-deriving the rule by hand. See below for the token list and the report-mode example.                                                                                                      |
| `count`             | Trusted `advisory-reroll:` marker count matching the current HEAD (resets on a new push, since a new HEAD's markers start over).                                                                                                                                                                                                                                                              |
| `cap`               | Configured bounded budget, `advisoryWait.sameHeadRerollCap` (default 2, deliberately conservative but > 1: same-SHA re-review is not a guaranteed one-shot off-ramp).                                                                                                                                                                                                                         |
| `exhausted`         | `count >= cap`: stop rerolling, fall through to the existing deadline-plus-maintainer-waiver backstop (#1512) or hold.                                                                                                                                                                                                                                                                        |
| `latestAt`          | GitHub `created_at` of the latest trusted same-HEAD reroll marker, or `''` -- **never** the marker's embedded, agent-supplied timestamp (same anchor rule AW2 already states for `advisory-wait:`).                                                                                                                                                                                           |
| `inFlight`          | `true` while a reroll marker exists, no primary-bot review has been submitted after it yet, **and** the configured `advisoryWait.pendingWindow` has not yet elapsed since it was posted. Recomputed fresh from GitHub state on every call (never in-session memory), so a crash mid-poll can never cause a duplicate reroll request.                                                          |
| `requestable`       | `eligible && !exhausted && !inFlight` -- the exact instant it is safe to request a fresh same-HEAD reroll.                                                                                                                                                                                                                                                                                    |

**`ineligibleReasons` tokens (`#1719`)**: one entry per failing term, in
the same order the `eligible` conjunction is written in
`advisory-convergence.mts`. Computed from the exact same six terms
`eligible` itself reduces from -- the array and the boolean are
structurally unable to disagree.

<!-- dprint-ignore-start -->
| Token                                    | Fires when...                                                                                                                                          |
| ----------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `scope-not-applicable`                    | `applicability.status` is `not_applicable` OR `indeterminate` (#1686) -- either `advisoryWait.convergenceScope: "idd-claimed"` and this PR has no verified linked claim/branch or has a broken/ambiguous claim linkage, or (#1906) `advisoryWait.exemptBotAuthoredPrs: true` under `"all-prs"` scope exempted a Bot-authored PR with no claim history. Offering a same-HEAD reroll is pointless in any of these cases. |
| `review-pending`                          | The primary bot has not yet reviewed current HEAD (`pending: true`). Always co-occurs with `review-item-count-unknown` below, since an off-HEAD review reports no usable item count. |
| `unresolved-copilot-threads`              | `threads.satisfied` is `false` -- at least one Copilot-authored thread is neither resolved nor validly dispositioned.                                   |
| `missing-regular-comment-disposition`     | `dispositionEvidence.missingRegularCommentCount` is non-zero -- an outstanding regular (non-thread) PR comment still lacks a fresh disposition marker.  |
| `review-item-count-unknown`               | The latest review's comment count is unavailable -- either the review is off-HEAD (co-firing with `review-pending` above, since `resolveLatestCopilotReviewClause` reports `itemCount: null` for any non-matching-HEAD review), or it is on current HEAD but the count itself is unavailable (a GraphQL nullable-field edge case). |
| `review-item-count-not-positive`          | The latest review's `itemCount` is a known `0` AND `suppressedCount` (#1880) is also `0` -- already fully converged, nothing (posted or suppressed) to reroll for.                        |
<!-- dprint-ignore-end -->

**Updated by kurone-kito/idd-skill#2050** (revised after PR #2054 review --
scoped to the LATEST review, not the PR-wide `copilotThreadCount`): when
zero threads THIS review opened exist at all and `review.itemCount > 0`,
the top-level `reasons` array's item-count entry is extended with a
pointer to check the review body directly -- the shape of the reported
adopter incident: a "Comments suppressed due to low confidence" item
embedded in the review's own body text counts toward `itemCount` but never
surfaces as a review thread, so no thread query can ever explain it. When
this review's own threads exist, are all resolved/dispositioned, AND their
count covers `itemCount` instead, Clause 1's `itemCount` half is satisfied
directly via that review-scoped thread-disposition evidence -- the
review-body pointer no longer applies to that case. An older review's
already-resolved thread, or a count of review-scoped threads smaller than
`itemCount`, both still block (see the two dedicated regression tests
added for each shape).

**`suppressedCount` (kurone-kito/idd-skill#1880).** A distinct,
`itemCount === 0` shape of the same underlying problem: GitHub Copilot
can fold a finding into a `<details><summary>Suppressed comments
(N)</summary>` block in the review's top-level `body` instead of
posting it as a comment at all, so `comments.totalCount` (`itemCount`)
stays `0` while a real finding still exists. Observed incident: PR
kurone-kito/idd-skill#1875, merged 2026-08-05 (a Copilot review on that
PR had `comments.totalCount: 0` with a body still containing an
unaddressed `Suppressed comments (1)` finding).
`resolveLatestCopilotReviewClause` (review-clause.mts) parses this
heading into `review.suppressedCount`, and Clause 1's `satisfied`
computation and `reviewItemCountPositiveTerm` above both treat
`suppressedCount > 0` the same way they already treat `itemCount > 0` --
blocking convergence with a dedicated top-level reason, and keeping the
same-HEAD reroll recovery path available for it, since `suppressedCount`
is read from the same static per-submission review snapshot `itemCount`
is.

**`suppressedCount` reroll reliability caveat (kurone-kito/idd-skill#1934).**
The mechanism-sharing argument above is a statement about how the two
counts are read (same static per-submission snapshot), not a claim
about convergence rate: `#1511`'s empirical basis -- 200 recent merged
PRs, 678 Copilot reviews, 16 same-commit re-review groups -- covers
`itemCount` transitions only, and no equivalent sample exists for
`suppressedCount`. Field evidence contradicts treating the extension as
equally reliable: two independent `kurone-kito/lints-config` PRs,
observed 2026-08-10/11 (`#243`, `#245`), each ran the same-HEAD reroll
to its `cap: 2` limit with no `suppressedCount: 0` outcome and no
content change between reviews; both converged only after an actual
content change plus a fresh, non-reroll review. Too small a sample to
establish a rate, but
sufficient to mark the `suppressedCount` reroll path **unvalidated for
convergence** -- treat cap exhaustion on a suppressed-only block as an
anticipated outcome routed to the deadline/waiver backstop **or hold**
(same split as the `exhausted` field above and the AW6 procedure's own
step 5, including for adopters who keep the distributed
`ciGate.externalCheckWaivers.mode: disabled` default), not a diagnosis
failure.

**Disposition-aware resolution (kurone-kito/idd-skill#2050).** A
same-HEAD reroll (above) is not the only escape hatch for `suppressedCount`
today. `resolveLatestCopilotReviewClause` (review-clause.mts) itself stays
purely mechanical -- `computeAdvisoryConvergenceVerdict`
(advisory-convergence.mts) now computes a disposition-aware OVERRIDE of its
`satisfied` field as a thin caller-side wrapper (not inside
`resolveLatestCopilotReviewClause`, since the override needs evidence --
review-scoped thread data, PR comments, `trustedMarkerLogins` -- that pure
function does not receive), reported on the verdict's own `review.satisfied`
in place of the raw mechanical value:

```text
matchesHead
  && (itemCount === 0 || (itemCount is known AND >= itemCount thread(s)
      THIS review opened cover it AND all of them are resolved/dispositioned))
  && (suppressedCount === 0 || hasValidReviewAck)
```

The `itemCount` half is bound to the LATEST review specifically
(`classifyThreadIdsForReview`, matching each thread's originating comment's
`pullRequestReview.id` against the review's own GraphQL node id, now also
exposed as `review.reviewId`) -- NOT `threads.satisfied` (Clause 2's
PR-WIDE, review-agnostic set) directly: an older, already-dispositioned
thread from a DIFFERENT review must never stand in for the CURRENT
review's own coverage, and `threads.satisfied` is additionally vacuous when
zero Copilot-authored threads exist at all -- both variants of the same
`#1719` incident shape above (a positive `itemCount` with no real thread
evidence). `itemCount: null` (unknown count) also fails closed here rather
than treating "at least one resolved thread exists" as sufficient, and the
number of covering threads must be at least `itemCount` -- one dispositioned
thread does not cover a review that posted two items (Copilot + CodeRabbit
review, PR #2054). `hasValidReviewAck` is `true` when a trusted
`review-ack:` marker's OWN `created_at` postdates the latest Copilot
review's `submittedAt` (never the marker's embedded timestamp), so any
later review automatically invalidates a pre-existing ack.

The `review-ack:` marker matches `advisory-reroll:`'s field shape and
posting path exactly (see
[`idd-advisory-wait.instructions.md`](../.github/instructions/idd-advisory-wait.instructions.md)'s
`suppressedCount`-unvalidated note in its AW6 section):

```text
review-ack: {agent-id} {PR_HEAD_SHA} {ISO8601-acknowledged-at}
```

Plain text, no HTML comment. Post via `post-idd-marker.mjs --type
review-ack --target pr <pr-number> --agent-id <id> --head-sha
<PR_HEAD_SHA> --timestamp <ISO8601> --apply` (or `--from-pr <pr-number>`
to derive `--head-sha` live) once the review's findings are fixed or
dispositioned. `post-idd-marker.mjs` itself performs no author gating (any
caller with `gh` credentials can POST); only a marker authored by a
`trustedMarkerActors` login is honored when `idd-advisory-convergence`
later reads it back -- an untrusted poster's marker is ignored, not
rejected at post time. `idd-advisory-convergence` re-checks
live GitHub state, so re-run it (`gh run rerun <run-id>`) after posting --
the marker itself does not retrigger the check.

**AW6 procedure** (`idd-advisory-wait.instructions.md`), invoked only
from F2 on a non-zero `--assert` exit:

1. If `sameHeadReroll.eligible` is `false`, the carve-out does not
   apply; fall through to F2's normal route-to-E1/E4. `ineligibleReasons`
   names the failing term(s) directly, without re-deriving the rule by
   hand.
2. If `requestable` is `true`: **post the marker before requesting the
   review**, as plain text (no HTML comment, matching `advisory-wait:`'s
   shape):

   ```text
   advisory-reroll: {agent-id} {head-SHA} {ISO8601-requested-at}
   ```

   `post-idd-marker --type advisory-reroll --target pr <pr-number>
   --agent-id <id> --head-sha <PR_HEAD_SHA> --timestamp <ISO8601>
   --apply` renders and posts this marker when helper runtime is
   enabled. **Deliberately not** `advisory-wait:` -- this marker is
   counted separately so it can neither consume nor be masked by the
   advisory-wait request cap (`REQUEST_CAP`). **Fail closed to a hold**
   (mirroring AW3-R) if the marker cannot be posted or verified: an
   untracked request could otherwise silently exceed the bounded
   budget on the next pass.

   **Only after** the marker is verified posted, request a fresh
   same-HEAD review from the primary advisory bot using the identical
   gh-then-REST remove-reviewer→add-reviewer commands as E14 step 4's
   `REQUEST_NEEDED` path (`idd-review-fix.instructions.md`). This order
   is load-bearing, not incidental: `inFlight` (below) anchors on the
   marker's GitHub `created_at`, so posting the marker **first**
   guarantees it predates any review the bot submits in response. Doing
   it in the other order opens a race -- a bot fast enough to respond
   between the request and the marker post would submit a review whose
   `submittedAt` is _earlier_ than `latestAt`, so
   `hasFreshReviewSinceLastReroll` would never see it as an answer and
   `inFlight` would stay `true` for the full pending window despite already
   being answered (observed 2026-07-18, #1517). If the request itself then
   fails after the marker already posted, treat that the same as a failed
   request elsewhere in this protocol: fail closed to a hold rather than
   silently leaving a marker with no matching request behind. Then poll (step
   4).
3. If `requestable` is `false` because `inFlight` is `true`: a reroll
   is already awaiting the bot's response (including on a freshly
   resumed/restarted session). Do not post another marker; poll
   directly (step 4).
4. **Polling** is self-contained -- it deliberately does **not** reuse
   E14's active polling loop, which is built around AW1's
   `LAST_COPILOT_COMMIT != PR_HEAD_SHA` distinction. That distinction is
   always false across a same-HEAD reroll (the commit never changes),
   so reusing it would exit on the very first tick without the bot
   doing anything. Instead: every `advisoryWait.pollInterval` minutes
   (the same constant AW3 already uses), re-run
   `advisory-convergence.mjs --pr <pr-number>` (report mode is enough)
   and re-read `sameHeadReroll.inFlight`. `true` → keep polling.
   `false` → exit polling and return to
   `idd-review-snapshot.instructions.md` (E1), regardless of _why_ it
   cleared -- a fresh review landed, or the pending window simply
   elapsed with no answer at all. E1's normal snapshot re-triages
   whatever the bot's fresh review actually contains: a flat or worse
   outcome, or a genuinely new finding, flows through the ordinary
   E4-E8 path exactly like any other review, never suppressed or
   auto-accepted by this carve-out. Do not re-assert F2 directly from
   this step; returning to E1 first is what guarantees a new finding
   is never skipped.
5. If `requestable` is `false` because `exhausted` is `true` (or
   `eligible` is `false`): no reroll. Fall through to F2's existing
   route-to-E1/E4 -- the same deadline-plus-maintainer-waiver backstop
   or hold path a permanently non-converged HEAD already falls to
   today. Same-SHA re-review is not a guaranteed off-ramp, so this
   bounded carve-out is deliberately paired with, never a replacement
   for, that backstop.

Fail closed the same way mid-poll or if the verdict JSON is missing or
unusable: treat the carve-out as not applicable / stop and post a hold,
same as `AW4`/`AW5`.

### E7 disposition verification

- Preferred command when helper runtime is enabled:
  `idd-review-disposition-verify --items '<json>'`
- Source repository equivalent:
  `node scripts/review-disposition-verify.mjs --items '<json>'`
- Input: JSON array of ReviewItems_snapshot items, each with `id`,
  `path` (`"A"` or `"B"`), `type`, `decision`, `markerReply`, and
  `threadResolved`
- Output schema (stable fields):

  ```json
  {
    "passed": true,
    "summary": "All 3 items verified.",
    "totalCount": 3,
    "passedCount": 3,
    "failedCount": 0,
    "items": [{
      "id": "...",
      "path": "A",
      "checks": {
        "decisionRecorded": true,
        "markerPresent": true,
        "markerMatchesDecision": true,
        "threadResolutionCorrect": true
      },
      "passed": true,
      "issues": []
    }]
  }
  ```

- Stable fields consumed at E7: `passed`, `items[].passed`,
  `items[].checks`, and `items[].issues`
- Read-only boundary: the helper never posts replies, resolves threads,
  or performs any E6 mutation.
- Fail closed: if execution fails, output is invalid JSON, required
  fields are missing, or output conflicts with observed triage evidence,
  discard helper output and apply written E7 checks directly.

### Branch conflict and synchronization state evidence

- Preferred command when helper runtime is enabled:
  `idd-branch-conflict-state --pr <pr-number>`
- Source repository equivalent:
  `node scripts/branch-conflict-state.mjs --pr <pr-number>`
- Output schema (stable fields):

  ```json
  {
    "protocolVersion": "1",
    "prNumber": 123,
    "prHeadSha": "abc...",
    "prBaseSha": "def...",
    "published": true,
    "mergeable": "MERGEABLE",
    "mergeStateStatus": "CLEAN",
    "branchState": "clean",
    "syncRecommendation": "none",
    "baseAdvancedSinceMergeBase": false,
    "readOnly": true,
    "worktreeUnchanged": true,
    "diagnostics": {
      "mergeableSource": "github-mergeable",
      "conflictFiles": [],
      "notes": []
    }
  }
  ```

- `branchState` values: `clean`, `behind-no-conflict`, `content-conflict`,
  `dirty`, `force-push-exception`, `computing`, `unknown` (`computing` is the
  transient still-computing mergeability that callers re-poll; `unknown` stays
  terminal)
- `syncRecommendation` values: `none`, `merge-base`, `policy-required-update`,
  `force-push-exception`, `recheck`, `hold-unknown` (`recheck` pairs with
  `computing`)
- `baseAdvancedSinceMergeBase` (boolean): `true` when the base ref has moved
  past this PR's merge-base, computed independently of `syncRecommendation` so
  it does not change any existing `syncRecommendation` value. `false` is
  **overloaded**: it means either a confirmed-unmoved base, or that the
  check was skipped / the merge-base could not be resolved (e.g. missing
  local history); the two are distinguished only via `diagnostics.notes`
  (an "undetermined" entry marks the latter), never by this field alone. A
  `clean` / `none` verdict is textual conflict-freeness only, not whole-tree
  CI-invariant freedom (line-count budgets, generated-file drift, lockfile
  consistency, and similar checks a full test suite enforces against the
  whole tree); when this field is `true` alongside `syncRecommendation: none`,
  `diagnostics.notes` also carries an advisory note naming the blind spot. A
  `pull_request`-triggered CI run is pinned to a merge-ref computed at trigger
  time, so a bare rerun after base moves can replay that stale state.
- Stable fields consumed by D/E/F routing: `branchState`,
  `syncRecommendation`, `published`, `readOnly`, `worktreeUnchanged`
- Read-only boundary: the helper never runs `git merge`, `git rebase`, or
  any command that leaves merge state, index changes, or working-tree
  changes. The `readOnly` and `worktreeUnchanged` fields confirm this.
- Fail closed: if execution fails, output is invalid JSON, or required
  fields are missing, discard helper output and apply written D4/E-phase
  branch-sync checks directly.

### Effective C1 critique delegate

- Preferred command when helper runtime is enabled:
  `idd-critique-delegate [--policy <path>] [--no-user-global]`
- Source repository equivalent:
  `node scripts/idd-critique-delegate.mjs [--policy <path>] [--no-user-global]`
- Output schema (stable fields):

  ```json
  {
    "usable": true,
    "source": "repository-local",
    "command": "my-local-reviewer --diff",
    "mode": "fallback",
    "reason": null
  }
  ```

- `source` values: `repository-local`, `user-global`, `none`
- `reason` values (only when `usable` is `false`):
  `repository-local-explicit-disable` (repo-local `critiqueLoop.delegate`
  is the JSON `null` sentinel), `invalid-repository-local-delegate` (a
  malformed repo-local value, which fails closed and never inherits a
  user-global delegate), `not-configured` (absent at every layer)
- `usable: true` always carries a non-null `command`/`mode` and a null
  `reason`; `usable: false` always carries null `command`/`mode` and a
  non-null `reason`
- Resolution order matches
  [User-global critique delegate default](idd-workflow.md#user-global-critique-delegate-default)
  exactly: a configured, disabled (`null`), or malformed repository-local
  `critiqueLoop.delegate` always wins outright and never inherits the
  user-global layer; only when repository-local is entirely absent does
  an optional `$XDG_CONFIG_HOME/idd-skill/config.json` (or
  `$HOME/.config/idd-skill/config.json`) fragment apply
- Under `GITHUB_ACTIONS=true` the user-global layer is always skipped
  (repository-local resolution is unaffected), matching the documented
  invariant that a GitHub-hosted or other remote agent surface never
  consults it; `--no-user-global` skips it explicitly on any other
  remote surface the caller recognizes but this helper cannot
  auto-detect from a single provider variable
- Deterministic and network-free; delegates entirely to the existing
  exported resolvers (`resolveEffectiveCritiqueLoopDelegateFromEnv` in
  `idd-config.mts`, `resolveEffectiveCritiqueLoopDelegate` /
  `parseCritiqueLoopDelegate` in `policy-helpers.mts`) with no
  reimplemented validation rule (referenced in
  [kurone-kito/idd-skill#2329](https://github.com/kurone-kito/idd-skill/issues/2329))

### Effective C-phase critique telemetry hook

- Preferred command when helper runtime is enabled:
  `idd-critique-telemetry-hook [--policy <path>] [--no-user-global]`
- Source repository equivalent:
  `node scripts/idd-critique-telemetry-hook.mjs [--policy <path>] [--no-user-global]`
- Output schema (stable fields):

  ```json
  {
    "usable": true,
    "source": "repository-local",
    "command": "notify-critique-telemetry --json",
    "reason": null
  }
  ```

- `source` values: `repository-local`, `user-global`, `none`
- `reason` values (only when `usable` is `false`):
  `repository-local-explicit-disable` (repo-local
  `critiqueLoop.telemetryHook` is the JSON `null` sentinel),
  `invalid-repository-local-telemetry-hook` (a malformed repo-local
  value, which fails closed and never inherits a user-global hook),
  `not-configured` (absent at every layer)
- `usable: true` always carries a non-null `command` and a null
  `reason`; `usable: false` always carries a null `command` and a
  non-null `reason`
- Resolution order matches
  [User-global critique telemetry hook default](idd-workflow.md#user-global-critique-telemetry-hook-default)
  exactly: a configured, disabled (`null`), or malformed repository-local
  `critiqueLoop.telemetryHook` always wins outright and never inherits
  the user-global layer; only when repository-local is entirely absent
  does an optional `$XDG_CONFIG_HOME/idd-skill/config.json` (or
  `$HOME/.config/idd-skill/config.json`) fragment apply
- Under `GITHUB_ACTIONS=true` the user-global layer is always skipped
  (repository-local resolution is unaffected), matching the documented
  invariant that a GitHub-hosted or other remote agent surface never
  consults it; `--no-user-global` skips it explicitly on any other
  remote surface the caller recognizes but this helper cannot
  auto-detect from a single provider variable
- `--invoke` reads a JSON payload from stdin (see
  [Repository-configurable critique telemetry hook](idd-workflow.md#repository-configurable-critique-telemetry-hook)
  for the payload shape) and, only if a hook resolved as usable,
  invokes its command with that payload on the child's stdin.
  Fire-and-forget: a missing command, non-zero exit, timeout, or any
  other failure is silently ignored; this mode always exits `0` and
  never writes to stdout/stderr, unlike the plain resolution mode above
  -- the whole point is that a caller never has to inspect this
  process's own result
- Deterministic and network-free for resolution; `--invoke` is the one
  exception (it spawns the resolved command) and is bounded by a
  default 5-second timeout plus a forced kill, so it can never block or
  delay its caller; delegates resolution entirely to the existing
  exported resolvers (`resolveEffectiveCritiqueLoopTelemetryHookFromEnv`
  in `idd-config.mts`, `resolveEffectiveCritiqueLoopTelemetryHook` /
  `inspectCritiqueLoopTelemetryHookLayer` in `policy-helpers.mts`) with
  no reimplemented validation rule (referenced in
  [kurone-kito/idd-skill#2679](https://github.com/kurone-kito/idd-skill/issues/2679))

### S2 quiet-window evidence

- When helper runtime is enabled, Resume/S2 should call the
  profile-selected
  `idd-stalled-session-quiet-check --pr <pr-number> --now <server-anchored-ISO8601>`
  command first (see `idd-resume-stall.instructions.md` for how to
  derive the server-anchored value).
  `node scripts/stalled-session-quiet-check.mjs --pr <pr-number> --now <server-anchored-ISO8601>`
  is the vendored equivalent.
- `--now <ISO8601>` is CLI-optional (the helper falls back to its local
  clock without it) but Resume/S2 and its S4 re-run always pass it
  explicitly, per the "server timestamps only" mandate in
  `idd-resume-stall.instructions.md` — omitting it there reintroduces
  the executor-local-clock skew gap.
  Other optional parameters: `--quiet-window-ms <ms>`,
  `--claim-created-at <ISO8601>`, and `--policy <path>`
- Stable fields consumed by the instructions: `quiet_window_met`,
  `quiet_window_ms`, `window_start`, `now`, `latest_activity`,
  `latest_activity_type`, `reason`, and `evidence`
  (`activity_count_in_window`, `blocking_activities`,
  `has_heartbeat_in_window`, `has_ci_running`,
  `has_branch_tip_movement`)
- `ci-running` activities always break the quiet window regardless
  of their timestamp; all other types are checked against
  `window_start = now - quiet_window_ms`
- Before takeover, re-run the helper against live GitHub state and pair
  it with the written Resume/S2-S4 checks for the same active claim,
  stale-threshold gating, closed/merged guards, and A5 race-safe claim
  verification. `quiet_window_met = true` alone is never sufficient.

### Merged-PR feedback sweep

- Source repo / vendored-node command:
  `node scripts/merged-pr-feedback-sweep.mjs`. Source-repo internal
  helper; not distributed via the package-manager / ephemeral-npx
  profiles (it is a maintainer-run sweep, never an adopter-facing
  step in the phase instructions).
- A **manually-invoked**, read-only detector (no schedule, no mutation). It
  scans MERGED PRs and surfaces feedback that was left unattended at merge:
  - **Window selector**: `--since <ISO8601>` and/or `--days <N>`, or
    `--pr <n>` (repeatable) / `--prs <n1,n2,...>`; `--limit <N>` caps the
    `--since`/`--days` enumeration. When both `--since` and `--days` are
    given, the later (more recent) cutoff wins, narrowing the window to the
    intersection; `--pr`/`--prs` bypass the date window entirely, so the
    reported `sweepWindow.since` and `days` are then `null`. Optional
    `--owner`, `--repo`,
    `--trusted-marker-logins`, and `--advisory-bot-logins` (same convention
    as `review-activity-snapshot`). `--idd-agent-logins` (or
    `IDD_AGENT_LOGINS`) names the agent accounts whose comments are
    dispositions / are not feedback — distinct from trusted-marker actors so a
    human maintainer who is a trusted-marker actor still has their review
    feedback surfaced; it defaults to the trusted-marker actors. Numeric flags
    reject non-integer values, and the PR connections are paged to completion
    so large PRs do not silently truncate.
  - **Surfaces**: review threads with `isResolved == false` (excluding
    threads the IDD agent itself opened; each carries a `dispositioned` flag
    from the in-thread disposition check), and regular comments /
    `CHANGES_REQUESTED` review bodies from non-IDD-agent authors that have
    **no later IDD-agent disposition** (`**Accepted**` / `**Rejected**` /
    `**Awaiting maintainer decision**`). A non-`CHANGES_REQUESTED` review from
    a _configured_ advisory-bot author (the same narrower identity check as
    the summary-walkthrough exclusion below, not the broader `isKnownReviewBot`)
    is also surfaced when its body carries a CodeRabbit
    `<summary>⚠️ Outside diff range comments (N)</summary>`-shaped block with
    `N >= 1` (#2194) — GitHub embeds a finding directly in the review body
    text, rather than as a normal inline review comment, when it targets a
    line the diff-hunk view cannot host; `N == 0` or an absent block is an
    ordinary walkthrough/summary review with nothing outside the diff and
    stays unsurfaced. Trusted IDD operational markers, IDD
    disposition comments, any HTML comment beginning with `<!-- idd-` (for
    example cleanup-evidence, excluded regardless of author — including CI
    automation such as `github-actions[bot]`), and a genuine CodeRabbit
    summary-walkthrough comment are all excluded from the feedback set
    unconditionally, regardless of disposition state, so the sweep and E6
    classify a CodeRabbit summary-walkthrough comment identically instead of
    disagreeing. The summary-walkthrough exclusion requires **all three** of:
    the author matching the _configured_ advisory-bot identity set (the same
    `--advisory-bot-logins` / `IDD_ADVISORY_BOT_LOGINS` / config resolution as
    above, falling back to the CodeRabbit/Codex defaults when nothing is
    configured — the same fallback E6 itself applies, and deliberately
    narrower than the broader `isKnownReviewBot` recognition used for the
    `advisoryBot` flag below, so a repo that configures `advisoryBotLogins` to
    omit CodeRabbit makes both the sweep and E6 leave a CodeRabbit summary
    undispositioned rather than only E6), the shared `isReviewSummaryComment`
    classifier — the same single-sourced predicate E6's
    `disposition-non-review-notices` uses to auto-`**Accepted**` a summary —
    and `!isAdvisoryNonReviewNotice` (a CodeRabbit comment can carry both the
    summary marker and a rate/usage-limit notice; E6 classifies that
    combination as a non-review notice, never a summary acceptance, so the
    sweep must not exclude it either). Advisory non-review notices
    (rate/usage-limit) are
    deliberately **not** excluded this way — an undispositioned one left on a
    merged PR still indicates a skipped E6 disposition and stays a genuine
    signal. Each finding carries an `advisoryBot` flag (`isKnownReviewBot` or a
    configured `advisoryBotLogins` author) so the operator can prioritize human
    feedback over capricious advisory-bot noise.
- JSON output keys: `sweepWindow`, `trustedMarkerActors`,
  `advisoryBotLogins`, `iddAgentLogins`, `prs` (each entry has `number`,
  `mergedAt`, `mergeCommit`, `unresolvedThreads`, and `unaddressedComments`),
  and `summary` (`prCount`, `flaggedPrCount`, `unresolvedThreadCount`,
  `unaddressedCommentCount`).
- Read-only boundary: the helper performs no minimization, no posting, and no
  issue creation. **Handoff**: the JSON is the input an operator hands to the
  issue-authoring skill, which re-verifies each candidate against current
  `main` (reuse-first / not-already-fixed) and drafts follow-up issues
  bucketed by readiness. The helper does deterministic detection; the
  judgment-heavy re-verification, drafting, and publish stay operator-gated.
- **Operator runbook**: this helper is a **manual spot-check audit**, not a
  phase step — its absence from the executable phase instruction files is
  by design, not an oversight.
  - **Intent**: it exists as a spot-check for runs where a lightweight
    model (for example a GPT-5.4-mini or Haiku-class model) has been
    driving the IDD loop and may have left feedback with **no E-phase
    disposition at all, or a thread left unresolved**, letting a merge
    complete — by whichever actor was authorized to run it — with that
    feedback unaddressed. (Per this project's
    [Weak-model guardrails](idd-workflow.md#weak-model-guardrails), a
    lightweight-tier session must not itself run the autonomous merge
    phases, so the sweep audits the aftermath of that policy, not a
    weak-model self-merge.) The sweep detects exactly those two gaps —
    it has **no backstop** for a _false-but-present_ disposition or an
    already-resolved thread; see the boundary recorded in
    `idd-design-rationale.md`.
  - **When to run it** (non-binding trigger guidance, not a policy gate):
    after a weak-model-driven backlog drain, on a periodic spot-audit
    cadence, or when a fail-open is suspected on a specific PR (via
    `--pr` / `--prs`). For a drain larger than the default `--limit`
    (100), pass the drained PR numbers via `--pr` / `--prs`, or an
    explicit `--since` with an adequate `--limit`, so older PRs are not
    silently omitted.
  - **Reading the output**: prioritize `summary.unresolvedThreadCount` —
    the higher-value signal — over `summary.unaddressedCommentCount`, and
    use each finding's `advisoryBot` flag to deprioritize capricious
    advisory-bot items in favor of human feedback. Triage the output this
    way before the **Handoff** step above hands it to the issue-authoring
    skill for re-verification.
  - **Scope boundary**: per the maintainer decision recorded in
    [kurone-kito/idd-skill#909](https://github.com/kurone-kito/idd-skill/issues/909)
    and reaffirmed in
    [kurone-kito/idd-skill#1352](https://github.com/kurone-kito/idd-skill/issues/1352)
    — decisions specific to this repository's own configuration, not a
    universal adopter policy — this sweep is a detection aid only: never
    an automatic recovery path or a retroactive merge gate.

### Untrusted-labeler login sweep

- Source repo / vendored-node command:

  ```sh
  node scripts/idd-suggest-untrusted-labelers.mjs [--owner <owner>] [--repo <repo>] [--format table|json]
  ```

- Package-manager / ephemeral-npx command: use the profile-selected
  `idd:suggest-untrusted-labelers` command from the helper runtime
  manifest wiring above; the literal invocation is:

  ```sh
  npx --yes --package <helper-package-spec> \
    idd-suggest-untrusted-labelers [--owner <owner>] [--repo <repo>] [--format table|json]
  ```

- Automates the full-history sweep technique the
  [Reserved-label guard recipe](customization.md#reserved-label-guard-recipe)
  already documents in prose: paginates `GET
  /repos/{owner}/{repo}/issues/events` to completion, keeping only
  entries where `event == "labeled"` and the actor's `type == "Bot"`
  (the REST Issue Event object's `actor` field — a nullable simple-user
  object — not the webhook payload's `sender` field), deduplicates by
  `actor.login`, and prints each distinct bot login with a count of
  `labeled` events attributed to it (`--format table`, the default) or
  the full result as JSON (`--format json`, including `scannedEventCount`
  and `pageCount` completeness evidence). `--owner`/`--repo` default to
  the current repository via `gh repo view` auto-detection.
- Pages manually (`page=1,2,...` with `per_page=100`), not via `gh api
  --paginate` in one subprocess call: the repository-level endpoint
  embeds the full parent `issue` object in every event, and `gh`'s
  synchronous execution path this repository's helpers share exposes no
  `maxBuffer` override, so an unbounded repository-wide sweep pages one
  request at a time instead of risking a single oversized buffered
  response.
- **Read-only, unconditionally**: performs no write operation of any
  kind — no `.github/idd/config.json` edit, no GitHub mutation (no
  label change, no comment, no other write call). It only proposes
  candidates for a human to review; recording an accepted candidate's
  login stays a manual, adopter-owned edit after judging each
  candidate's event count. Add it to `labels.untrustedLabelerLogins` in
  `.github/idd/config.json` and (re-)run the `idd-onboard` CLI's
  `--substitute` stage to generate `strip-untrusted-labels.yml` (see the
  [Reserved-label guard recipe](customization.md#reserved-label-guard-recipe)'s
  "Preferred: generated guard" path for the exact invocation), or add it
  as one of that recipe's `<labeler-bot-login-N>` placeholders when
  following that recipe's manual fallback instead — see that recipe for
  when each path applies.
  Not a phase step in any
  `idd-*.instructions.md` file — like the Merged-PR feedback sweep
  above, this is a manually-invoked, operator-run spot-check, run once
  when first building the reserved-label guard's bot-login list and
  again after enabling new automation or after a long gap (a bot with
  no history yet can still start labeling later).

## Signed-Commit Merge Wrapper (Shared Git Procedure)

`idd-review-triage.instructions.md`'s E-phase sync path and
`idd-review-fix.instructions.md`'s E11 both merge `main` into the feature
branch with `git fetch origin main && git merge origin/main`. On a repo
whose primary commit signing is non-interactive-hostile (GPG pinentry /
hardware-touch) and that configures a fallback signing wrapper for
arbitrary git subcommands, run the **merge** step — including a
`--continue` after conflict resolution — through that wrapper, never the
plain command (`git fetch` creates no commit and needs no signing):

```sh
git -c gpg.format=ssh -c user.signingkey=<abs-path> -c commit.gpgsign=true merge -m "chore: merge origin/main into the claimed branch" origin/main
# resolve conflicts if any, then:
git -c gpg.format=ssh -c user.signingkey=<abs-path> -c commit.gpgsign=true merge --continue
```

Include the conventional `-m` subject so a `commit-msg` hook that runs
commitlint accepts the merge commit (a subject without a `type:` prefix
fails the hook and leaves `MERGE_HEAD` in place). Repositories without
that hook can keep the same subject; it does not change unsigned
`git merge` elsewhere. `merge --continue` reuses `MERGE_MSG` and needs
no second `-m`.

Pass the `-c` flags to `git` itself, before the subcommand (`git -c …
merge`, not `git merge -c …`); a commit-only alias such as `git
commit-ssh` will not run `merge`. Even a clean, conflict-free merge
commits immediately, so the wrapper must own the operation from the
first `merge` call, not just a later `--continue` — otherwise the merge
commit reverts to the stalling primary signer. This is the normal-path
complement to the recovery-path re-signing in
`idd-pr-submit.instructions.md` (Post-rebase verification) and
`idd-overview-core.instructions.md` (cwd-vs-claim cherry-pick recovery).

This wrapper also applies to an ordinary per-commit `git commit` in B3
(`idd-work.instructions.md`), not only a merge or rebase continuation:

```sh
git -c gpg.format=ssh -c user.signingkey=<abs-path> -c commit.gpgsign=true commit -F <message-file>
```

Unlike the merge case above, a commit-only alias such as `git
commit-ssh` is sufficient here — a single `commit` invocation needs no
`--continue` step to re-sign.

**Bounded timeout for every invocation** (commit, merge, or rebase): if
the wrapper has not completed within 2 minutes, treat it as stuck
rather than a signing failure worth retrying — a whole-command,
root-cause-agnostic bound (it deliberately does not try to isolate the
signer subprocess) that applies even to an invocation still producing
output: an inactivity-only trigger would leave a merge or rebase that
keeps emitting output free to run indefinitely without ever completing,
which is not actually bounded (preventive; no observed incident yet —
raised in PR #2906 review). First check whether the process **tree** —
the wrapper's git invocation and any descendants such as the signer
subprocess, not just the top-level command — is still running: per
`idd-ci.instructions.md`'s "Wake-up discipline" guidance on a heavy
local command that auto-backgrounds past a tool's default timeout, do
not start a second wrapper invocation alongside it. This whole
recovery procedure depends on being able to snapshot and signal the
process tree — if `pgrep`/`ps` (or an equivalent process-listing and
signaling mechanism) are not available on the host, that dependency
cannot be met: stop and post a hold note rather than falling back
without the cleanup guarantee, the same fail-closed treatment the
`lsof` case below already gets. It also depends on already knowing
which process is this invocation's own: "the git PID" below is the PID
recorded when this wrapper invocation itself was launched, never one
recovered afterward by searching the process table — launch the
wrapper (the original invocation and every fallback or continuation
alike) as `<wrapper command> & echo "wrapper-pid=$!"; wait "$!"` so the
PID lands in the tool's own output at launch, an unambiguous launch
record that survives a later timeout, since shell state such as a bare
`$!` does not itself persist between separate tool calls. B1's
sibling-worktree model already puts several concurrent workers on one
host, so a generic `pgrep`/`ps` pattern match (for example, on the
command name `git commit`) can just as easily match another worker's
unrelated git invocation, and signaling that tree would terminate
someone else's in-progress work instead of this one's (preventive; no
observed incident yet — raised in PR #2906 review). If no such
launch-time handle was recorded, that dependency is unmet too: hold,
the same as the missing-`pgrep`/`ps` case above, rather than search for
a substitute. Otherwise, snapshot the whole set to signal: the git PID
itself **and** its descendants, found by walking from the git PID (for
example, recursively via `pgrep -P`) — a
"descendant" walk alone omits the root git process, leaving it able to
keep running (and keep `index.lock` held) after only its children are
signaled. Immediately send SIGTERM to every recorded PID in that
whole set, not `-9` — git's own signal handler cleans up `index.lock`,
and a descendant such as the signer subprocess can outlive a `kill`
scoped to only the git parent (reproduced 2026-09-11 in PR #2906
review). Snapshot and signal back-to-back, with nothing in between:
that is what keeps a bare recorded PID number trustworthy without
needing a separate identity check, since the gap in which an exited
PID could be reused by an unrelated process stays sub-second on any
real host. Then wait up to 30 seconds for each recorded PID
individually to exit (not a fresh tree walk); SIGTERM is asynchronous,
so checking state immediately can race git's own unwind (still
removing `index.lock`) or observe stale state.

Even a PID snapshot is best-effort, not a guarantee: a child that gets
reparented (commonly to init) before the snapshot is taken is never
recorded at all, so it survives untouched no matter how promptly the
recorded PIDs are signaled. The same is true of a recorded PID that
simply outlasts the 30-second wait — for example a process stuck in
uninterruptible I/O, which cannot receive a signal until it leaves
that state (preventive; no observed incident yet). Whether either kind
of survivor is safe to proceed past depends on what it can be: a
signer subprocess is only a resource leak to report, since the
unsigned fallback below never invokes one and so cannot race it — but
the whole-command timeout this section opens with is root-cause-
agnostic (it can equally fire on a hung hook, not only a stalled
signer), and a hook process that survives could still be reading or
writing the working tree or index. Proceeding with the fallback while
an unidentified or non-signer descendant might still be touching
repository state risks the fallback's own git operation racing it, so
treat that case as blocking: stop and post a hold note documenting the
surviving PID(s) rather than falling back, reserving the
resource-leak-and-continue treatment for a descendant identifiable as
the signer itself.

Separately, the lock-ownership check keeps its original (round-6)
purpose: a leftover `index.lock` after the tree is confirmed gone does
not prove it belongs to this invocation — a hook, another command, or
the signer itself could hold it instead, the same ambiguity the
clone-scoped lock's own "no automatic stale-lock recovery" convention
already treats as unsafe to guess past. Confirm no other process
still has the lock file open — a hook or the signer subprocess itself
could hold it, not only another `git` command, and not necessarily
one running from this worktree's directory (an absolute-path or
`git -C` invocation holds the same lock without it) — with `lsof` on
the `--git-path index.lock` path; where `lsof` is not available,
ownership cannot be reliably confirmed at all, so treat it as
unconfirmed rather than substituting a weaker check — before removing
it yourself
(`rm -f "$(git rev-parse --git-path index.lock)"`, not a literal
`.git/index.lock` path, the same linked-worktree rule the rebase-state
check below uses); if ownership cannot be confirmed, leave the lock in
place and stop with a hold note instead of forcing the removal.

Either way — the tree exited on its own, was terminated with nothing
left but an identified signer leak, or the checks above otherwise
allow proceeding — verify what actually happened before falling back;
a killed or already-exited process can leave the operation completed,
mid-progress, or never started at all:

- **Plain commit**: compare `git rev-parse HEAD` before/after the
  wrapper call, the same check B3's "Verify a commit actually landed"
  paragraph already prescribes. Landed → stop, do not re-commit.
  Otherwise, before falling back to `--no-gpg-sign`, also compare the
  index's tree hash — from running `git write-tree` before the wrapper
  call and again now — rather than comparing `git status --porcelain`
  and `git diff --cached --stat` output: `git commit -F` commits the
  index, so this content-addressed hash is what actually proves it
  unchanged, whereas status/diff-stat output only shows that a hook
  mutated the index without moving `HEAD` (reproduced 2026-09-11 in PR
  #2906 review, via a hook that staged an extra file and slept) — it
  cannot also catch a hook that swaps one tracked line's content for
  another of the same shape, leaving both reports unchanged
  (preventive; no observed incident yet). Unstaged working-tree
  changes are intentionally excluded from this check: `git commit -F`
  alone never commits them, so they cannot reach the fallback commit
  regardless of what changed there. Unchanged → fall back to
  `--no-gpg-sign`
  (`idd-overview-appendix.instructions.md`'s "Commit signing" section).
  Changed → stop and post a hold note for review instead of falling
  back.
- **Merge or rebase, state still present**: name the state via git, not
  a literal path — in a linked worktree (every B1 sibling worktree)
  `.git` at the worktree root is a _file_ pointing elsewhere, so a
  hardcoded `.git/rebase-merge` check silently never matches. Use
  `git rev-parse -q --verify MERGE_HEAD` for a merge, or
  `test -d "$(git rev-parse --git-path rebase-merge)"` (or
  `rebase-apply`) for a rebase. Either succeeding means the operation is
  mid-progress: complete it with `-c commit.gpgsign=false` on the
  `--continue` form — a plain `--continue` re-signs through the stalled
  primary signer, and `--no-gpg-sign` itself is not a `--continue` flag.
- **Merge or rebase, no state present**: absent state alone does not
  prove the operation succeeded — the timeout can equally fire before
  Git ever creates that state (nothing to `--continue`), or, for a
  rebase specifically, leave `HEAD` detached at the upstream tip
  without replaying the local commit, the same sibling-worktree failure
  mode `idd-pr-submit.instructions.md`'s D1 "Post-rebase verification"
  already documents and defines the same predicate for: current branch
  non-empty (not detached) and the expected local commit present in
  `origin/{development-branch}..HEAD` for a rebase; for a merge, either
  `HEAD` advanced past its pre-call value or
  `git merge-base --is-ancestor origin/{development-branch} HEAD`
  already succeeds — an already-current merge exits `0` having created
  neither a new `HEAD` nor `MERGE_HEAD`, and is success, not a failed
  attempt. For a rebase specifically, D1's two checks alone are not
  enough here: D1 verifies a rebase that already completed, but a
  timeout that fires **before** the rebase ever starts leaves the
  untouched, still-behind branch passing both checks trivially (it was
  never detached, and its own feature commit was already present in
  `origin/{development-branch}..HEAD` before this attempt began) —
  require `git merge-base --is-ancestor origin/{development-branch}
  HEAD` to succeed too, the same upstream-incorporated check the merge
  case above already uses, so a rebase that never actually ran is not
  mistaken for one that did. Verified → stop. Not verified → re-attach
  to the branch if
  detached (`git checkout {branch-name}`; the commit is preserved on
  the branch ref) and rerun the original merge or rebase command
  **unsigned** (`git -c commit.gpgsign=false merge …` / `rebase …`, not
  the SSH-signing wrapper), exactly once, under this same 2-minute
  bound — mirroring D1's own bounded auto-recovery. If that rerun times
  out or still fails the same verification, post a hold note
  documenting the branch state and stop, the same as D1's own recovery
  does when it is exhausted.

No step in this recovery procedure waits indefinitely: the original
wrapper invocation and every fallback or continuation share the same
2-minute bound, and the termination wait above has its own 30-second
bound — every step that exceeds its bound routes to the same
terminate-and-verify-or-hold outcome, not a fresh unbounded wait. A
hook or other non-signing cause can hang the plain-commit
`--no-gpg-sign` fallback or the `--continue` completion just as it
hung the original attempt; if either does not itself complete within
2 minutes, apply the same terminate-and-verify procedure to it, and if
it still does not resolve, post a hold note and stop rather than
retrying further.

Observed hanging with no output for an extended, unbounded period on
2026-09-10 (issue #2844 / PR #2870, commit `7be8acc9`, later confirmed
unsigned).

## Friction Inventory

The workflow areas most likely to benefit from optional helpers are:

| Candidate                       | Status             | Helper level                       | Mutation risk | Canonical fallback path                                                 | Drift risk                                                                               | Estimated payoff / byte reduction                                       |
| ------------------------------- | ------------------ | ---------------------------------- | ------------- | ----------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| A4 viability gate               | Adopted helper     | Read-only evaluator                | Low           | A4 viability criteria list in `idd-discover.instructions.md`            | Low — criteria are deterministic pattern matches against issue body text                 | Low to medium — roughly 100 to 200 bytes of repeated A4 criterion prose |
| Claim-state parsing             | Reserve candidate  | Read-only parser                   | Low           | Claim rules in `.github/instructions/idd-overview-core.instructions.md` | High — claim parsing is subtle and any divergence would create false ownership decisions | Medium — roughly 200 to 400 bytes of repeated marker-parsing prose      |
| Review activity snapshots       | Adopted helper     | Read-only evidence collector       | Low           | E1/F2/F3 activity-universe fetches via `gh` / GitHub API                | Medium — helper output must keep matching the review-currency rules exactly              | High — roughly 600 to 900 bytes of repeated multi-surface fetch prose   |
| Live status digest edits        | Adopted helper     | Dry-run by default, explicit apply | Medium        | Phase-specific digest discovery and update flow                         | Medium — digest text must remain UI-only and never look authoritative                    | Medium — roughly 300 to 500 bytes of repeated digest-upsert prose       |
| Advisory-wait state             | Adopted helper     | Read-only evidence collector       | Low           | `.github/instructions/idd-advisory-wait.instructions.md`                | Medium — helper must expose evidence without hiding the canonical decision table         | Very high — roughly 900 to 1400 bytes of repeated AW command prose      |
| Pre-merge readiness             | Adopted helper     | Read-only evidence collector       | Low           | `.github/instructions/idd-pre-merge.instructions.md` and F3 live fetch  | Medium — helper must stay evidence-only and preserve the written merge gates             | Very high — roughly 1200 to 1800 bytes of repeated merge-evidence prose |
| Post-merge cleanup candidates   | Adopted helper     | Dry-run by default, explicit apply | High          | GraphQL minimize-comment fallback flow                                  | Medium — minimization safety still depends on exact review/marker rules                  | Medium — roughly 400 to 700 bytes of repeated GraphQL audit prose       |
| E7 disposition verification     | Adopted helper     | Read-only evidence verifier        | Low           | E7 verification steps in `idd-review-triage.instructions.md`            | Low — verification logic is deterministic and path/type rules are stable                 | Low to medium — roughly 150 to 300 bytes of repeated E7 pre-exit checks |
| Branch protection/ruleset reads | Deferred candidate | Read-only API adapter              | Low           | Direct ruleset / branch-protection API reads                            | Medium — repository support varies and incomplete coverage could create false confidence | Low to medium — roughly 150 to 300 bytes of repeated ruleset prose      |
| Branch conflict state           | Adopted helper     | Read-only evidence collector       | Low           | D4/E-phase branch-sync checks in `idd-pr-submit.instructions.md`        | Medium — helper must stay evidence-only and preserve the written sync gates              | Medium — roughly 300 to 500 bytes of repeated branch-state prose        |

### Ranked roadmap candidate list for the source roadmap

The ranking distinguishes immediate roadmap picks from documented
reserve candidates:

1. **Advisory-wait state** — **implemented now**. The AW protocol had
   the highest command-copy burden, a stable read-only evidence shape,
   and a clear non-goal boundary, so the source roadmap landed it first
   as
   [kurone-kito/idd-skill#308](https://github.com/kurone-kito/idd-skill/issues/308).
2. **Pre-merge readiness** — **implemented now**. F2/F3 collect the
   largest evidence set in the workflow and already compose existing
   pure protocol logic, making a read-only helper valuable without
   moving merge authority out of the instructions. This maps directly to
   the source follow-up issue
   [kurone-kito/idd-skill#309](https://github.com/kurone-kito/idd-skill/issues/309).
3. **Claim-state parsing** — **reserve, defer for now**. The payoff is
   real, but claim ownership drift would be more dangerous than
   shell-copy variance, so this should wait until helper runtime
   profiles and the higher-payoff read-only gates are settled.

### Explicit deferrals

- **Branch protection/ruleset reads** stay deferred for this roadmap.
  They are useful support data, but repository variance and narrower
  byte savings make them a worse first investment than AW/F2 helpers.
- **Live status digest** and **post-merge cleanup** are already adopted
  in narrow forms, so they are inventory baselines rather than new
  roadmap targets.

### Inventory Non-goals

- Do not turn this inventory into a commitment to helperize every phase.
- Do not rank mutating merge or review actions ahead of read-only
  evidence collectors.
- Do not let helper candidates replace the written decision tables.
- Do not use this inventory to justify a separate npm package before the
  local/template profile path is proven.

## Trade-off

Helper scripts can improve copy/paste reliability and make some
review-state checks easier to audit locally. That benefit is real,
especially for advisory-wait, review-snapshot, and post-merge cleanup
commands.

The portability cost is also real. The exported IDD template is meant to
work in repositories that can copy Markdown instruction files without
adopting a runtime, package manager, or repository-local script
directory. If helper scripts are introduced too early, every operational
rule must be maintained twice: once in the instructions that agents read,
and once in code that agents run.

For now, the safer balance is to keep pre-merge and advisory
instructions canonical while allowing three read-only evidence helpers,
one live digest upsert helper, and one post-merge cleanup helper. Merge
safety still depends on the written checks, not on helper output alone.

## Non-goals

This helper policy does **not** imply the following:

- Node.js becomes mandatory for repositories that only copy the Markdown
  instructions
- helper output becomes authoritative over the written decision tables
- helpers perform mutating review or merge actions by default; mutation
  must remain explicit in the written instructions
- the project is committed to publishing a separate npm package before
  the local and templated helper profiles are proven

## Future Adoption Criteria

If additional helper scripts are revisited, they should satisfy all of
the following:

- They are optional and never required to execute the exported template.
- They are read-only by default; mutating actions remain explicit in the
  phase instructions.
- They output stable machine-readable JSON that can be inspected and
  compared by agents.
- They keep the shell / `gh` / `jq` fallback documented beside the helper
  path.
- They have a small test fixture set for marker parsing and snapshot
  filtering.
- They are introduced only after the corresponding instruction protocol
  has stabilized enough that drift risk is lower than command-copy risk.

Good future candidates remain read-only evidence collectors for
pre-merge readiness or later claim-state inspection. They should not
replace the written decision tables.

[advisory-convergence-schema]: https://kurone-kito.github.io/idd-skill/schemas/advisory-convergence.schema.json
[advisory-wait-state-schema]: https://kurone-kito.github.io/idd-skill/schemas/advisory-wait-state.schema.json
[disposition-non-review-notices-schema]: https://kurone-kito.github.io/idd-skill/schemas/disposition-non-review-notices.schema.json
[forced-handoff-marker-schema]: https://kurone-kito.github.io/idd-skill/schemas/forced-handoff-marker.schema.json
[idd-merge-execute-schema]: https://kurone-kito.github.io/idd-skill/schemas/idd-merge-execute.schema.json
[local-validation-evidence-schema]: https://kurone-kito.github.io/idd-skill/schemas/local-validation-evidence.schema.json
[post-idd-marker-schema]: https://kurone-kito.github.io/idd-skill/schemas/post-idd-marker.schema.json
[pre-merge-readiness-schema]: https://kurone-kito.github.io/idd-skill/schemas/pre-merge-readiness.schema.json
[provider-health-schema]: https://kurone-kito.github.io/idd-skill/schemas/provider-health.schema.json
[provider-outage-declaration-schema]: https://kurone-kito.github.io/idd-skill/schemas/provider-outage-declaration.schema.json
[provider-outage-park-schema]: https://kurone-kito.github.io/idd-skill/schemas/provider-outage-park.schema.json
[resolve-review-thread-schema]: https://kurone-kito.github.io/idd-skill/schemas/resolve-review-thread.schema.json
