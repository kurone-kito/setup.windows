# IDD — Pre-Merge Conditions Phase (F1–F2)

Read after the E-phase branch-sync check confirms no sync is required,
or when returning to merge-gate checks after a sync cycle. Covers F1
(read-only branch-state check) and F2 (pre-merge checklist).

This phase's GitHub Copilot advisory review gate depends on GitHub
review state, not the local CLI, so follow it under any local agent.

F2's merge-gate timing defaults are named in
[IDD policy constants](../../docs/policy-constants.md) — canonical,
not an override.

Before any F-phase mutating action, apply the
[shared claim revalidation gate](idd-overview-core.instructions.md#claim-revalidation-gate).

After a forced handoff on an open PR, the successor must rebuild
review state through E1/E2 under its own `{claim-id}` before
merge-bound routing continues — a live status digest or prior-claim
marker is UI/audit context only, and cannot satisfy review currency,
claim ownership, advisory wait, or CI gates.

When all F2 conditions are satisfied, proceed to
`idd-merge-handoff.instructions.md`.

## F1 — Final branch-state check

Read the current branch state. When helper runtime is enabled, call:
`idd-branch-conflict-state --pr {pr-number}`

Otherwise read the state directly:

```sh
gh pr view {pr-number} --json mergeable,mergeStateStatus,headRefOid,baseRefName
git fetch --no-tags origin {base-branch}
git merge-base {pr-head-sha} FETCH_HEAD
# vs: git rev-parse FETCH_HEAD; mismatch/unresolvable = baseAdvancedSinceMergeBase: true below (best-effort)
```

This check is read-only — F1 does not rebase, merge, or push.

- **`clean`** (`mergeable` is `MERGEABLE` and `mergeStateStatus` is
  `CLEAN`) or **`behind-no-conflict`** when no up-to-date-head policy
  applies: proceed to F2. `clean` is conflict-freeness only — if
  `baseAdvancedSinceMergeBase: true`, prefer a fresh CI result over an
  old green check.
- **`behind-no-conflict`** when branch protection or recorded policy
  requires an up-to-date head, or unreadable/ambiguous (fails closed),
  or **`content-conflict`** (`mergeable` is `CONFLICTING`): return to
  the E-phase branch-sync check in `idd-review-triage.instructions.md`,
  first setting `Phase: F1 sync-required`, the branch state in `Open
  blockers`, and `Next action: E-phase branch-sync` on the digest.
- **`computing`** (`syncRecommendation` is `recheck`): `mergeable` is
  `UNKNOWN` / null because GitHub has not settled mergeability yet
  (common right after E1 posts its watermark/baseline) — transient, not
  terminal. Do **not** hold; re-poll after a short wait (default: 3
  attempts, a few seconds apart), then route by the first settled
  result. Only if still `computing`/`unknown` after the budget, fall
  through to the terminal hold below.
- **`dirty`** (`mergeStateStatus` is `DIRTY`), **`unknown`**, or any
  other state the bullets above do not name (for example
  `force-push-exception`): hold; post a PR comment documenting the
  branch state and stop. A maintainer must clear the hold.

## F2 — Pre-merge condition check

Verify **all** conditions below; each states its required evidence and
failure route. The F2 snapshot at the end records the final
activity-universe values the handoff phase consumes.

Do not treat "one bot says clean" as sufficient evidence — checks must
cover the full activity universe (human reviewers plus advisory bot
surfaces such as Copilot, CodeRabbit, Codex connectors, and CI bots).

The advisory-wait window is Copilot-only
(`idd-advisory-wait.instructions.md`) and does not cover non-Copilot
`advisoryBotLogins`. That is this window, not all of F2: configured
`secondaryQuietWindow` is the quiet-window blocker below (until
`elapsed: true`, not until `secondaryBotLogin`'s logins review HEAD).
F2/F3 MUST NOT merge on bare CI-green: **Review currency** must
confirm a fresh `review-watermark` covers latest activity, so a late
non-Copilot finding still returns to E1.

**Nonce passthrough**: when invoking the readiness collector below
(directly, or via the documented merge-gate helper reference), pass
`--nonce {nonce}` — this session's own locally-recorded activation-nonce
from claim time (`idd-claim.instructions.md`'s activation-nonce format) —
alongside `--claim-id`, extending Claim-verification-step-4's nonce
collision check to this merge-time write-gate (Resume-phase cold
recovery stays a distinct, not-yet-wired case — see
[rationale](../../docs/idd-design-rationale.md#activation-nonce-why-a-separate-marker-and-what-stays-deferred),
kurone-kito/idd-skill#1529). Omitting `--nonce` silently skips the
merge-time comparison rather than failing closed, so pass it whenever a
nonce was recorded for the active claim.

**No claimed issue**: the readiness collector requires
`--claim-issue <issue-number>` (with `--claim-id`) or `--claimless`
(#2017) — pass `--claimless` for a PR with no linked issue
(`closingIssuesReferences` empty) or a valid `reason:bootstrap`
out-of-loop marker; it cannot combine with `--claim-issue`/`--claim-id`,
and otherwise fails closed on a non-empty `closingIssuesReferences`. See
[docs/idd-helper-scripts.md's Readiness command](../../docs/idd-helper-scripts.md).

**Multi-issue close**: pass `--closing-issues <n>,<m>` (D3) with the
full set (else a `closing-set` mismatch).

**Polling loop failure mode**: a zero exit with the full readiness
JSON (`ready: false` + `blockers`) is not-ready-yet — keep polling. A
non-zero exit with `{ "error": ... }` is a **call failure**: a usage
error (e.g. missing `--claim-issue`/`--claimless`) carries a `hint` —
fix before retrying; a live `gh` lookup failure lacks one — use
judgment (calls can fail transiently). Conflating either `{error}`
shape with not-ready-yet (kurone-kito/idd-skill#2707) turns a real
failure into a silent stall. A `deferred-followup-unreconciled` blocker
never clears by polling: follow its `detail`.

- **Review currency** (live re-fetch required, freshness gate): read the
  most recent `<!-- review-watermark: {agent-id} {claim-id} … -->`
  comment whose embedded `{claim-id}` matches the current active claim
  and whose GitHub author is a trusted marker actor (the first two
  fields, agent-id and claim-id, already located this comment). Extract:
  (c) `{head-SHA}`; (d) `{max-activity-updatedAt}` (`none` if empty);
  (e) `{total-item-count}`; (f) `{latest-ci-completed-at}` (`none` if
  empty). If no trusted same-claim watermark exists, return to E1
  unconditionally. Legacy watermarks without `{claim-id}` must not be
  reused across a restart or takeover, and same-claim watermarks from
  untrusted authors must be ignored and reported as suspicious context
  when they affect routing. Forced-handoff successors treat prior-claim
  watermarks the same way even when branch and HEAD are unchanged. Do
  not delete, hide, minimize, or unmark open-PR operational markers
  during this recovery; with no trusted same-claim watermark for the
  successor claim, return to E1 and rebuild review state there.
  When helper runtime is enabled, prefer the documented merge-gate
  helper reference in
  [`docs/idd-helper-scripts.md`](../../docs/idd-helper-scripts.md#stable-helper-evidence-outputs)
  to collect this evidence (the fields listed at that anchor). Helpers
  remain read-only evidence collectors. Distinguish two failure shapes
  before deciding whether to retry. On an
  **infrastructure/transport failure** — the invocation itself fails
  with no well-formed gate result at all (a bare network/transport
  error such as a connection failure, timeout, or DNS failure, or a
  retryable `5xx`/`429` HTTP status with no substantive JSON body —
  never a non-retryable `4xx` such as `401`/`403`/`404`, which is
  code-/auth-caused, not transient), **or returns well-formed JSON
  whose sole content is a collection/transport-failure placeholder
  rather than a real gate criterion** (for example a non-empty
  `blockers` array whose only entry describes the collection failure
  itself, not any actual merge-readiness criterion) — retry the
  identical invocation once, mirroring the CI-wait algorithm's own
  infra-vs-code retry distinction (`ciWait.rerunPolicy`,
  `idd-ci.instructions.md`) rather than inventing a new pattern; if the
  retry fails the same way, fall back to the discard-and-fetch-directly
  path below unchanged — a single bounded attempt, not a loop. A
  **substantive non-passing gate result** — the helper ran to
  completion and returned well-formed JSON with real gate fields backed
  by an actual merge-readiness criterion (for example
  `claim.matchesExpectedClaim: false`), not a collection-failure
  placeholder — is never retried; continue trusting it at face value,
  unchanged from today. For every other case —
  output is invalid JSON, required sections are missing, or live GitHub
  state disagrees with it — discard helper output and fetch the
  activity universe snapshot (same scope as E1 Step 1) plus current CI
  state for the HEAD SHA directly, unchanged and without retry — the
  instruction rules remain canonical. Return to E1 if **any** of the
  following is true:
  - The current PR HEAD SHA differs from the stored `{head-SHA}` (a new
    push after E1's snapshot, even if the watermark posted later).
  - The stored value is `none` and the live snapshot is non-empty
    (empty at E1 time, now has review activity).
  - The stored value is not `none`, and any fetched item's `updatedAt`
    is strictly newer than `{max-activity-updatedAt}` (new activity
    since the last E1 run).
  - The stored value is not `none`, and the live total item count
    exceeds `{total-item-count}` (new items at the same max timestamp,
    missed by the previous check).
  - The current latest CI pass `completedAt` for HEAD differs from
    `{latest-ci-completed-at}` in the watermark (a new CI run completed
    after E1's snapshot; if `none`, any current CI pass triggers
    re-evaluation) — commonly a late label-triggered job; sequence it
    before E1, this is not a fault.

  Structural ack-only carve-out: when the only trigger above is newer
  activity/count growth that helper evidence proves is solely
  post-disposition advisory-bot acknowledgement
  (`reviewCurrency.live.ackOnly.items` all ack-only, sibling
  `reviewCurrency.live.effective` current,
  `reviewCurrency.comparisonReason: ack-only-post-disposition`), the advisory
  courtesy-ack convergence rule in `idd-review-triage.instructions.md`
  applies — do not return to E1 for that activity alone (still confirm
  the semantic residual; every other trigger/gate is unaffected).

  A current-claim agent's own post-watermark disposition replies are
  expected convergence activity, not reviewer input, and the watermark
  refresh on the E-phase branch-sync `clean` / `behind-no-conflict`
  route already re-covers them. The same holds for any other
  own-agent-authored procedural or status comment posted after the
  watermark (for example, a hold comment explaining a blocker) that
  introduces no reviewer or bot finding of its own — it is expected
  convergence activity too, though the branch-sync route's own
  refresh does not independently re-cover it. If a return-to-E1 is
  triggered solely by disposition replies, other own-agent
  procedural or status comments of that kind, or both, refresh the
  watermark directly instead; every other F2 trigger and gate is
  unaffected.

  Third-party advisory bot skip-review carve-out: the same applies to
  a third-party advisory bot's own skip-review or no-action notice
  posted after the watermark — when helper evidence shows it carries
  no reviewer finding or actionable content, a return-to-E1 triggered
  solely by that notice refreshes the watermark directly instead; a
  mixed-cause trigger still returns to E1 normally.
- **Advisory bot wait** (restart-safe enforcement): schedule a wake, or
  background only if the topology-safety condition holds (confirmed to
  route completion back to this turn) — otherwise wait synchronously:
  no single `gh` command blocks on Copilot review state (unlike a CI
  run), so run the AW poll loop below as a foreground wait, never via
  `run_in_background` absent the confirmed condition — see
  [idd-ci.instructions.md's Wake-up
  discipline](idd-ci.instructions.md#wake-up-discipline).
  `PR_HEAD_SHA` is already available from the review-currency check
  above. Apply the advisory-wait protocol
  (`idd-advisory-wait.instructions.md`):

  1. Run **AW1**. If **SATISFIED** → this check is **satisfied**;
     continue to the **CI** check. (This short circuit is always the
     proven-coverage case — `LAST_COPILOT_COMMIT == PR_HEAD_SHA` —
     since AW1 alone has no marker data to evaluate the settled-window
     sub-case below; it never consults **AW3-S**.)
  2. Run **AW2** to fetch markers.
  3. Apply the **AW3** decision table:
     - **SATISFIED**, `COPILOT_PENDING` `"false"`, `COPILOT_PENDING_COVERS_HEAD`
       `"false"` (settled by elapsed time alone, never proven the
       request reached Copilot — `#2327`): consult **AW3-S**'s
       `staleRequestRecovery.action` first, the same way E14 step 4
       does. `"attempt"` runs its bounded cycle (non-pending entry:
       skip **Remove**, start at **Request**; a proven
       failure-to-register completes the cycle per the entry's
       inverted step 4/5 disposition), **then** continue to the CI
       check (this accumulates recovery-cycle evidence toward
       `COPILOT_UNAVAILABLE`; the check's own satisfied status is
       unaffected). `"cap-exhausted"` handles like **CAP_EXHAUSTED**
       below instead — post the hold and **stop**; do not continue to
       the CI check for this action (the mandatory stop from
       **CAP_EXHAUSTED** below still applies; this recovery-cap
       exhaustion does not waive it). `"not-applicable"` falls through
       unchanged and continues to the CI check.
     - **SATISFIED** (otherwise) → this check is **satisfied**;
       continue to the CI check.
     - **HOLD** → post the hold comment from **AW4** and stop.
     - **RECOVERY_NEEDED** → post the recovery marker from **AW3-R**
       without requesting another Copilot review, then enter the normal
       WAIT polling path using refreshed AW2/AW3 state. Then **go back
       to the first condition in F2**.
     - **CAP_EXHAUSTED** → post the cap-exhausted hold comment from
       **AW4** and stop.
     - **REQUEST_NEEDED** → return to E14 to request Copilot review and
       post a fresh marker. Do not post a new request in F2.
     - **WAIT** (`COPILOT_PENDING` is `"true"`, elapsed <
       `PENDING_WINDOW_MINUTES` min) → wait the remainder of the window
       (poll every `POLL_INTERVAL_MINUTES` min, refreshing
       `EARLIEST_SAME_HEAD_AT` per **AW2** each iteration, applying
       **AW5** if the marker disappears), then **go back to the first
       condition in F2** to re-evaluate all conditions.
     - **WAIT** (`COPILOT_PENDING` is `"false"`, elapsed <
       `SETTLED_WINDOW_MINUTES` min) → wait the remainder of the settled
       window (same polling rules), then **go back to the first
       condition in F2**.

  GitHub removes a reviewer from `requested_reviewers` on review
  submission or manual cancellation — either counts as no longer
  pending for merge purposes.

  **Terminal Copilot unavailability**: not gated above — see
  [Terminal routing](idd-advisory-wait.instructions.md#terminal-routing-1570);
  an unwaived `copilot-terminal-unavailable` in `blockers[]` stops here
  with that section's hold regardless.
- **Secondary advisory bot quiet window** (opt-in; unset never blocks):
  when `advisoryWait.secondaryQuietWindow` (#2335) is configured,
  `secondaryQuietWindow.elapsed` must be `true`. A
  `secondary-quiet-window` blocker means that window has not elapsed
  since the last substantive review activity; wait (poll per
  `advisoryWait.pollInterval`), then re-evaluate F2. When issue
  `#2544`'s settled buffer clamps the wait, the blocker names that
  buffer apart from the configured window.
- **CI**: Current PR head SHA has all required CI checks generated and
  all passing (→ run CI wait per `idd-ci.instructions.md` using the
  same resolved `ciWait.runningTimeout`, `ciWait.generationTimeout`, and
  `ciWait.rerunPolicy` values; on-success → re-evaluate F2; code-caused
  → `Phase: F2 ci-failure`, E15's code-caused route).

  `pre-merge-readiness` reads `.github/idd/config.json` from the PR's
  trusted **base** ref, not the PR head. When this PR introduces a
  `ciGate.*` key its own F2 evaluation needs, follow
  [ciGate F2 bootstrap](../../docs/customization.md#cigate-f2-bootstrap).
  F2 stays fail-closed here; the human off-ramp in that section is not
  an F2/F3 action.

  **No required checks configured**: When `pre-merge-readiness` reports
  `ci.noRequiredChecksConfigured: true` (unprotected branch, or no
  required status checks), the CI gate is **not** satisfied vacuously.
  Route by `ci.presentRunConclusion` over the actual HEAD runs:
  - `all-passing` → the CI gate may pass (every present run green).
  - `pending` → wait per `idd-ci.instructions.md`, then re-evaluate F2.
  - `some-failing`, or `none` (no runs at all) → **hold**; never merge
    on a vacuous green.

  **External-check waivers**: When `pre-merge-readiness` reports a check
  `coveredByWaiver: true`, a trusted maintainer authorized skipping it
  for the current head SHA and claim. Treat it as passing for F2/F3
  routing **only when**:
  - `waiverEvidence.valid` is non-empty for that check's selector
  - The waiver actor is a trusted marker login
  - The waiver `headSha` matches the current PR HEAD
  - The waiver `claimId` matches the active claim
  - The waiver `expiresAt` is in the future

  Waivers never bypass review currency, advisory wait, unresolved
  threads, unreplied comments, required reviews, disposition evidence,
  or claim ownership. Non-empty `waiverEvidence.wrongHead`, `wrongClaim`,
  `unauthorized`, `expired`, or `malformed` are suspicious context, never
  valid permissions. A waiver posted before its effectiveness
  precondition is met stays valid but inert until then — see
  `idd-pr-submit.instructions.md`'s D4 for the mechanical check.

  **Local validation evidence** (#2323): `pre-merge-readiness`'s
  `localValidationEvidence` field reports whether HEAD-pinned local
  evidence exists for an active `ciGate` outage
  ([`docs/idd-helper-scripts.md`](../../docs/idd-helper-scripts.md#local-validation-evidence-helper))
  — informational only, never a passing check or waiver: an
  unavailable required check stays a CI-gate blocker regardless. With
  required checks unavailable, merges queue until the platform check
  rollup is restored (an out-of-band privileged operation).
- **Required reviews**: required approvals count is satisfied and all
  CODEOWNER approvals are obtained. When helper evidence's
  `reviewerStates.codeownerSelfApproval` `status` is `deadlock` or
  `possible_deadlock`, include it as diagnostic evidence only ([field contract](../../docs/idd-helper-scripts.md#merge-gate-evidence)),
  never permission to bypass this gate. If approvals are absent but no
  open actionable review items exist (`ReviewItems_snapshot` empty), do
  **not** route to E1 — request CODEOWNER/required reviewers directly
  (if not already requested), post a hold comment, and stop. Return to
  E1 only when actual review threads or comments exist (→
  `idd-review-snapshot.instructions.md`).
- **No `CHANGES_REQUESTED`** (human/required/CODEOWNER reviewers only):
  no such reviewer's latest state is `CHANGES_REQUESTED` (→ if not yet
  addressed, return to review triage; if addressed and re-review
  requested, wait up to 30 min, then post a hold comment and stop if no
  response). Advisory bot reviewers (Copilot, CI bots) are exempt —
  their `CHANGES_REQUESTED` does not block merge once the advisory wait
  window completes.
- **Unresolved threads = 0** (backlog gate): no unresolved review
  threads remain, excluding **awaiting-reviewer threads**. Classify
  each unresolved thread:

  | Condition                                                                                                       | Classification              |
  | --------------------------------------------------------------------------------------------------------------- | --------------------------- |
  | IDD/author latest substantive; no later reviewer comment, reopen, or AMD reply ("Awaiting maintainer decision") | `awaiting-reviewer`         |
  | Thread contains an IDD-agent reply starting `**Awaiting maintainer decision**`                                  | `AMD-thread` (not awaiting) |
  | Reviewer commented or reopened (with or without new text) after the latest IDD-agent/PR-author comment          | `not awaiting-reviewer`     |
  | Reviewer has the latest substantive comment (no later IDD-agent/PR-author reply)                                | `not awaiting-reviewer`     |

  `→ return to review triage` if any non-awaiting-reviewer (including
  AMD-thread) unresolved threads remain — E6 will detect any pending
  maintainer response and post a hold.

  Exception: if the repo's branch protection requires conversation
  resolution, the awaiting-reviewer exclusion does not apply and all
  unresolved awaiting-reviewer threads must be resolved here. For each
  remaining unresolved awaiting-reviewer thread under that exception:

  | Latest reply author                        | Action                                                                     |
  | ------------------------------------------ | -------------------------------------------------------------------------- |
  | IDD agent (and no AMD reply on the thread) | resolve directly, then restart F2                                          |
  | PR author (not an IDD agent)               | post a brief acknowledgement reply, then resolve directly, then restart F2 |

  Do **not** route to E1; E1 filters out awaiting-reviewer threads
  and would surface no actionable item.
- **Unreplied comments = 0**: no regular comment from a non-IDD-agent
  lacks a subsequent IDD-agent comment — "subsequent" meaning any
  IDD-agent regular comment posted at a strictly later timestamp (→
  return to review triage). Copilot and CI advisory bot comments are
  handled earlier in the PATH B triage flow (E4-E7) and excluded here.
- **Advisory convergence** (exit-code obligation for Copilot-authored
  review threads, not a judgment call): run `node
  scripts/advisory-convergence.mjs --pr {pr-number} --assert` (or the
  profile-selected `idd-advisory-convergence` command). Non-zero exit
  routes to E1/E4 (check **AW6** first when
  `sameHeadReroll.eligible`; an `ack-suppressed` next-action means
  Clause 1's `suppressedCount` term still needs coverage — see
  `idd-review-triage.instructions.md`'s `review-ack:` paragraph (E6)
  instead of rerolling); `ready: true` satisfies. On
  `instructions-only`, both halves use the [F2 `gh`/`jq` fallback](../../docs/idd-advisory-wait-shell-fallback.md#f2).
  Separately, require `dispositionEvidence.route` to be `proceed`
  (`dispositionEvidence.blockingCount == 0` — both
  `missingRegularComments` (any outstanding non-thread regular PR
  comment from a non-agent author, including the PR author, lacking a
  later IDD-agent reply — a fresh disposition marker for advisory-bot
  comments, or any later IDD-agent body for a human comment) and
  `missingThreads` (any review thread still lacking a clearing reply)
  are empty). Evaluation splits by origin: a **human-authored** thread
  whose latest item is unmarked human prose is presence-only and is
  not `unresolved-without-fresh-disposition` solely for lacking
  `**Accepted**`; a **Copilot / configured-advisory-bot** thread still
  needs a stamped or legacy trusted IDD disposition (or resolution for
  Clause 2). An unmarked human `ok` must not clear those advisory
  threads. The `advisory-convergence.mjs --assert` check above only
  enforces the _unresolved_ Copilot-authored subset of `missingThreads`
  (resolution alone satisfies its own Clause 2 without a fresh
  disposition); it never covers a non-Copilot thread or any
  `missingRegularComments` entry, so this check stays necessary even
  when that one passes. Treat
  a missing or malformed `dispositionEvidence` object, or a non-list
  `missingRegularComments`/`missingThreads`, as unmet, never vacuously
  satisfied. A `route: return-to-e1` result routes to E1/E4 with that
  evidence — except the ack-only override below.

  Disposition-evidence ack-only override: when
  `dispositionEvidence.soleCauseAckOnlyPostDisposition` is `true` (every
  blocking item is a `missingThreads` entry with
  `ackOnlyPostDisposition: true`, `missingRegularComments` empty — full
  condition in `idd-review-triage.instructions.md`'s "Disposition-evidence
  parity (advisory-only)" paragraph), autopilot may deterministically
  override `return-to-e1` and proceed on the current HEAD SHA. Distinct
  from the `reviewCurrency` carve-out above (E1-snapshot staleness) and
  applied by the agent, not `pre-merge-readiness`'s own rollup. The
  signal never changes `route` itself; any other blocking cause makes it
  `false`, and the gate still routes to E1/E4. Fails closed: an unusable
  check makes this condition unmet.
- **Closing-set and impact-checklist re-verification**:
  `closingSet`/`closing-set` evidences this section's re-run of
  D3.5 steps 6-7 only; re-derive D3.7 below locally.
  After fetch, the claim gate must confirm
  `git branch --show-current` is `{branch-name}`; else hold.
  Require empty `git status --porcelain` and
  `git merge-base --is-ancestor HEAD "$PR_HEAD_SHA"`; else hold. Under
  `set -o pipefail`, run
  `git ls-tree -r -z --full-tree --name-only "$PR_HEAD_SHA" |
  (cd "$(git rev-parse --show-toplevel)" &&
  GIT_LITERAL_PATHSPECS=1 xargs -0 git ls-files -z -o --exclude-standard --)`
  and again with `-o -i`; any output or failure holds. Use
  `git switch {branch-name}` (not
  detached), recheck; reset on pass)
  — D3.5/D3.7 read local state, not the remote PR. Then re-run
  `idd-pr-submit.instructions.md`'s D3.5 steps
  6-7 (the `closingIssuesReferences` set comparison and the
  commit-message closing-keyword scan) and D3.7 (the
  IDD-impact-checklist re-derivation) against that HEAD. Skip D3.5
  steps 6-7 under D3.5's own non-default-`{development-branch}`
  exemption. On a mismatch: for a closing-set drift, apply D3.5 step
  6's own remediation, except a missing entry it classes as pending
  registration (`kurone-kito/idd-skill#3632`), which is no drift: keep
  polling the `closing-set` blocker, no repair or hold; for a stray
  commit-message match, apply D3.5 step 7's own remediation (amend or
  rebase); for a checklist drift, apply D3.7's own mismatch handling.
  If the fix amended or rebased a commit (changing HEAD), return to
  this list's first condition instead of only repeating it — the new
  HEAD invalidates the checks above. Otherwise, repeat this condition
  once. If it still fails (pending registration excepted), post a hold
  note and stop — do not proceed to F3.

When any F2 condition routes to a hold/stop or back to E1/E14, update
the digest after recording the blocking evidence and before
stopping/returning: `Phase` to the failing check, `Open blockers` to
the unmet condition, `Next action` to the required
reviewer/CI/advisory/maintainer/agent action, `Authoritative by` to the
F2 evidence fetched. If every condition is satisfied, do **not** edit
the digest before F3 — carry the F2 snapshot forward unchanged for
F3's freshness check.

Note: `required_approvals` is ruleset-fetched; only `CHANGES_REQUESTED`
and missing CODEOWNER approvals block. When satisfied, record the
live-fetch result as the **F2 snapshot** — current PR HEAD SHA
(`{f2-head-SHA}`), highest `updatedAt` across fetched items
(`{f2-max-activity-updatedAt}`, `none` if empty), total item count
(`{f2-total-item-count}`), latest CI pass `completedAt` for HEAD
(`{f2-latest-ci-completed-at|none}`) — carry all four into the handoff
phase, then proceed to `idd-merge-handoff.instructions.md`.
