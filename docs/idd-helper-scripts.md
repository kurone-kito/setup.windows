# IDD Helper Script Evaluation

This document records the current decision on optional helper scripts for
the IDD workflow. It exists so future reviews can reference the trade-off
directly instead of re-evaluating the same suggestion from scratch.

## Decision

In the idd-skill source repository, the following optional helpers were adopted:

**Discover & Claim Phase Helpers (Phase 1):**

- `scripts/discover-orphan-filter.mjs` for A0-O orphan issue detection and
  filtering (referenced in
  [kurone-kito/idd-skill#390](https://github.com/kurone-kito/idd-skill/issues/390)),
  with opt-in `--with-claim-state` / `--current-claim-id` active-claim
  annotation parity with `discover-roadmap-graph`'s flag of the same name
  (referenced in
  [kurone-kito/idd-skill#1395](https://github.com/kurone-kito/idd-skill/issues/1395))
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
  [kurone-kito/idd-skill#391](https://github.com/kurone-kito/idd-skill/issues/391))
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
  whether `merge-main`, `hold-unknown`, or no action is needed without
  mutating the worktree or PR branch (added in 0.2.0)
- `scripts/verify-install-deps.mjs` for B1 Step 3 `install-deps`: runs
  the underlying install command, verifies a key post-install binary
  exists, retries the install exactly once if it does not, and fails
  loudly rather than continuing in a silently under-installed state
  (referenced in
  [kurone-kito/idd-skill#1237](https://github.com/kurone-kito/idd-skill/issues/1237)).
  Source-repo internal helper; not distributed via the package-manager
  / ephemeral-npx profiles.

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
    `effort: "S" | "M" | "L" | null, sourceRoots: number[] }]` — the union of
    open execution leaves. Each leaf records every roadmap root it is reachable
    from in `sourceRoots` (provenance); a leaf shared by sibling epics appears
    **once** and is never double-counted.
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
    never changes the 24h stale-takeover threshold
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
    `autopilotSuitability` **descending**, tie-broken by issue number
    **ascending** (stable). A missing or out-of-range score is treated as
    the configured suitability floor for ordering so unscored work is not
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

### Discover Viability Gate Contract

`scripts/discover-viability-gate.mjs` evaluates the A4 viability gate for
one or more issues.

- **Inputs**: `--issue <number>` (repeatable) or `--issues <n1,n2,...>`,
  with optional `--csv`, `--owner <owner>`, and `--repo <repo>`.
- **JSON output**:
  - `viable`: `[{ number: number, title: string }]`
  - `discarded`: `[{ number: number, title: string,`
    `failedCriteria: string[], criteria?: [{ id: string, name: string,`
    `result: "pass" | "fail", evidence: string }] }]`
  - `summary`: `{ total: number, viableCount: number,`
    `discardedCount: number, discardedByCriterion: Record<string, number> }`
- **Error conditions**: missing issue arguments or unknown flags throw;
  loader or GitHub failures surface as errors; not-found or non-open
  issues are reported in `discarded` with `failedCriteria` instead of
  crashing.
- **Example**:

  ```json
  {
    "viable": [{ "number": 123, "title": "trim helper docs" }],
    "discarded": [{ "number": 124, "title": "rewrite workflow", "failedCriteria": ["limited_scope", "autonomous_completion"] }],
    "summary": { "total": 2, "viableCount": 1, "discardedCount": 1, "discardedByCriterion": { "limited_scope": 1, "autonomous_completion": 1 } }
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
  <id1,id2>` (default `bundle-review,bundle-merge`), `--now <ISO8601>`, and
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
  instructions remain authoritative.

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
  `--owner` / `--repo` / `--agent-id` / `--trusted-marker-logins`.
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
- **Fail-closed**: `--apply` requires `--body` and the
  `--claim-issue` / `--claim-id` pair, re-validates the active claim before
  **each** of the reply and the resolve (scoped to trusted marker authors,
  aborting on a targeting `forced-handoff`), and binds the mutation to the
  claimed PR by requiring the active claim's branch to equal the PR's head
  branch. GraphQL `errors` fail fast rather than masquerading as a missing
  thread, and a partial apply (reply posted, resolve not confirmed) still
  reports the posted `replyId`.
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

### External-check waiver contract

Issue `#666` defines the policy and marker contract before the operator
facade and F-phase consumer land. The contract is intentionally
auditable and fail-closed.

```md
<!-- idd-external-check-waiver: {agent-id} {claim-id|none} {head-sha} check:{check-selector} reason:{reason-token} expires:{iso8601} -->

_{actor}: external check waiver for IDD F phase._
```

Interpretation rules:

- `agent-id`, `claim-id`, `head-sha`, `check`, `reason`, and `expires`
  come from the marker body.
- The issuer is the GitHub comment author and the issued timestamp is
  the comment `created_at`. Do not duplicate either field inside the
  marker body.
- `check` may be an exact selector or a glob pattern, matching the
  `ciGate.externalChecks.*[].selector` plus `matchMode` contract.
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
  `git -C <worktree> rev-parse --absolute-git-dir`, then atomically
  create an `idd-claim.lock` file there with an exclusive file-create
  API (`open(..., O_CREAT|O_EXCL)` on POSIX, or the PowerShell
  `FileMode.CreateNew` equivalent), writing the same JSON holder shape
  (`agentId`, `claimId`, `acquiredAt`). A path that already exists is a
  collision; a matching holder may re-acquire, and a missing,
  malformed, or unreadable holder is also a collision. Never delete or
  override a different holder — enable a helper runtime for an
  authorized takeover instead. Both profiles share the `idd-claim.lock`
  namespace, so a helper-runtime session and an instructions-only
  session see the same lock.

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
- Without `--apply`, it never calls `gh run rerun` (or any other mutating
  command) itself. Pass `--apply` (#1766) to execute the printed plan:
  it reruns each rerun-eligible instance in order (recovery-refresh first
  when one applies), waits for each to reach a genuinely new completed
  attempt (polled via the actions/runs API, not `gh run watch`, to avoid
  racing a just-issued rerun's stale pre-rerun status) before starting
  the next, and stops early once the recomputed plan is fully resolved --
  a `bot-gated-skip`, `awaiting-fresh-review`, or rerun-budget-held
  instance is never rerun
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
`--override-budget` flag or equivalent. A specific combination sits
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
- `ci.discardedNonPassingRequiredChecks` (#1745) surfaces a same-name/type/
  workflowName required-check instance discarded by the latest-per-producer
  dedup while the surviving representative is pass-equivalent -- e.g. a
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
  waived)`).
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
  workflow's `pull_request` `synchronize` trigger fires before the
  separate `pull_request_review` trigger's review has landed. Every other
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
  wrapper; (2) a review that lands while this poll is asleep can still
  start a fresh `pull_request_review`-triggered run in the hosting
  workflow's own PR-scoped `cancel-in-progress` concurrency group,
  cancelling this run before it observes the review — a narrower win than
  "never needs an external rerun again"; see the full analysis in
  `runAdvisoryConvergenceWithPoll`'s doc comment
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
  waived)`); the terminal state alone never sets `ready: true`. A
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
| Token | Fires when... |
| ----------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `scope-not-applicable` | `applicability.status` is `not_applicable` OR `indeterminate` (#1686) -- either `advisoryWait.convergenceScope: "idd-claimed"` and this PR has no verified linked claim/branch or has a broken/ambiguous claim linkage, or (#1906) `advisoryWait.exemptBotAuthoredPrs: true` under `"all-prs"` scope exempted a Bot-authored PR with no claim history. Offering a same-HEAD reroll is pointless in any of these cases. |
| `review-pending` | The primary bot has not yet reviewed current HEAD (`pending: true`). Always co-occurs with `review-item-count-unknown` below, since an off-HEAD review reports no usable item count. |
| `unresolved-copilot-threads` | `threads.satisfied` is `false` -- at least one Copilot-authored thread is neither resolved nor validly dispositioned. |
| `missing-regular-comment-disposition` | `dispositionEvidence.missingRegularCommentCount` is non-zero -- an outstanding regular (non-thread) PR comment still lacks a fresh disposition marker. |
| `review-item-count-unknown` | The latest review's comment count is unavailable -- either the review is off-HEAD (co-firing with `review-pending` above, since `resolveLatestCopilotReviewClause` reports `itemCount: null` for any non-matching-HEAD review), or it is on current HEAD but the count itself is unavailable (a GraphQL nullable-field edge case). |
| `review-item-count-not-positive` | The latest review's `itemCount` is a known `0` AND `suppressedCount` (#1880) is also `0` -- already fully converged, nothing (posted or suppressed) to reroll for. |
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
- `syncRecommendation` values: `none`, `merge-main`, `policy-required-update`,
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

### Everyday `git commit` (and `git commit --amend`) fallback

The merge wrapper above covers the occasional `main`-sync merge; B3
authors far more plain `git commit` calls than merges, and the same
non-interactive-hostile primary signer blocks those exactly the same
way. The paragraph above notes that a commit-only alias such as `git
commit-ssh` cannot run `merge` — that is not a limitation to route
around here, it is the positive complement: for plain `git commit` /
`git commit --amend`, a commit-only signing alias is exactly the right
tool.

**When to switch**: only after the configured primary signer has
already failed non-interactively on this commit (pinentry / TTY EOF /
hardware-touch timeout). This is a documented recovery step, not an
unconditional first attempt, and it does not change the signing ladder
in `idd-overview-appendix.instructions.md`'s "Commit signing" section:
try the configured primary signer first, fall back to this wrapper on a
non-interactive block, and keep `--no-gpg-sign` as the final,
last-resort fallback — used only after this wrapper has also failed or
is unavailable, never as the first move.

**Check for a configured alias first** — a commit-signing alias is
scoped to whatever git config level defines it (often the operator's
global config, not this repository), so its presence varies by
environment and must not be assumed:

```sh
git config --get alias.commit-ssh
```

If that prints a value (a shell function or a plain command string),
the current environment has a commit-only signing alias configured. In
issues #136-#139, this repository's IDD loop used exactly one such
alias, `git commit-ssh` (wrapping `git -c gpg.format=ssh -c
user.signingkey=<path-to-ssh-public-key> -c commit.gpgsign=true
commit`), after the primary GPG signer blocked non-interactively in
each case. When an alias is present, invoke it by name instead of
reconstructing the raw `-c` flags — pass `--no-edit` on `--amend` so a
missing `-m` reuses the existing message instead of launching
`$EDITOR`, which can hang in the same non-interactive session this
fallback targets:

```sh
git commit-ssh -m "type(scope): subject"
git commit-ssh --amend --no-edit
```

If `git config --get alias.commit-ssh` (or an equivalent
locally-configured alias) prints nothing — a different operator's
machine, a fresh clone, or a CI runner without this global alias — use
the same raw `-c` form as the merge wrapper above, applied to `commit`
instead of `merge`:

```sh
git -c gpg.format=ssh -c user.signingkey=<abs-path> -c commit.gpgsign=true commit -m "type(scope): subject"
git -c gpg.format=ssh -c user.signingkey=<abs-path> -c commit.gpgsign=true commit --amend --no-edit
```

Record a non-default signing outcome — this wrapper (alias or raw
form) or the `--no-gpg-sign` last resort — per
`idd-overview-appendix.instructions.md`'s "Commit signing" section,
which already limits that reporting duty to non-default outcomes; the
default configured primary signer needs no separate report.

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
[post-idd-marker-schema]: https://kurone-kito.github.io/idd-skill/schemas/post-idd-marker.schema.json
[pre-merge-readiness-schema]: https://kurone-kito.github.io/idd-skill/schemas/pre-merge-readiness.schema.json
[resolve-review-thread-schema]: https://kurone-kito.github.io/idd-skill/schemas/resolve-review-thread.schema.json
