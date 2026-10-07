# IDD — Review Snapshot Phase (Lite) (E1-E3)

Lite profile for claimed PRs; `instructions-only` uses standard file.

## Helper runtime contract

- Missing, failing, or disagreeing helpers: stop and ask; never fall back
  silently to prose.
- `instructions-only` uses `idd-review-snapshot.instructions.md`.

## Triage hand-off boundary (E4-E8 excluded)

Fetch/route; never classify/decide. Non-empty E3 hands off to
`idd-review-triage.instructions.md`. Deferred Step 2 carries the E1
SHA, activity baseline, `watermark deferred`, and reason; E14 uses it
temporarily, never as a `review-watermark`. Missing: rerun E1; never
branch-sync/F1/F2 unverified.

## Stop-and-ask conditions

- The active claim is ambiguous, disputed, or lost.
- A required helper is missing, fails, returns invalid JSON, or
  disagrees with live state.
- The claim-lock helper reports a collision (a different claim id
  already holds the worktree lock).

## Pre-mutation guard

Before any commit, comment, marker post, reply, resolve, or other
GitHub side effect, confirm all of the following:

1. The active claim still uses this session's claim id.
2. If this session posted an activation nonce for the current claim,
   confirm it still wins (no later trusted marker for this claim id
   won the tie-break instead).
3. The current directory is the sibling worktree for the claimed branch.
4. `git branch --show-current` equals the claimed branch.
5. Acquire the worktree-local claim lock with the profile-selected
   `claim-lock` helper (`node scripts/claim-lock.mjs --acquire
   --worktree <this-worktree-path> --agent-id <id> --claim-id <id>`, or
   the package-manager-profile `idd:claim-lock` command with the same
   arguments, or the ephemeral-npx equivalent (see
   `docs/idd-helper-scripts.md`). A `collision` result is
   fail-closed: stop rather than proceed. Then, separately, run
   `--read-tokens --worktree <this-worktree-path> --claim-id <id>`
   and require `present: true` with no `malformed`; otherwise recover
   per `docs/idd-helper-scripts.md` (gated: each step succeeds,
   `reacquired: true` both ends), else stop.
6. If any check fails, stop.

## E1 — Fetch review items into ReviewItems_snapshot

### CI-completion precondition (for Step 2)

Run AW1 with `--pr`, `--claim-id`, `--agent-id`,
`--trusted-marker-logins`, then profile-selected `ci-wait-state` with
`--pr` (see `docs/idd-helper-scripts.md`).
`requiredChecks.status: success`; `no-required-checks` only with
non-empty all-success `checks[]`; `pending`/`failing`/`missing` defer
Step 2. Require `outcome: SATISFIED`, or `CAP_EXHAUSTED` with
`capExhaustedRoute: phase-specific`; otherwise stop/ask. Require
`copilotRecovery.activeClaimProvided: true`; same-head:
`lastCopilotCommit == prHeadSha`, off-head needs
`staleRequestRecovery.action` `not-applicable` or completed AW3-S/cap;
`attempt`: stop and hand off to full; never E15; `hold` defers. Take
Steps 1 and 3;
use E15 for CI, E14 for advisory (E14 first when both pending).
If incomplete, skip Step 2, wait before branch-sync/F2, then post from
E1.

### Step 1 — Snapshot the activity universe

1. Read the current PR HEAD SHA once — `gh pr view {pr-number} --json
   headRefOid --jq '.headRefOid'` — and store it as `{head-SHA}`. Never
   re-read it elsewhere in E1 — reuse this value, except for the
   deferred E3 check below.
2. Run the profile-selected `review-activity-snapshot` helper for
   `{head-SHA}`, `{max-activity-updatedAt}`, `{total-item-count}`, and
   `{latest-ci-completed-at}`: `node
   scripts/review-activity-snapshot.mjs --pr {pr-number}
   --trusted-marker-logins "<trusted-login-1>,<trusted-login-2>"`, or its
   package-manager equivalent. It supplies Step 2 data and
   `embeddedFindings` for Step 3; raw triage fetch remains required.
   Use `latestPassingCiCompletedAt`, not the latest completion.
3. Independently fetch, in one pass before filtering: every review
   thread (resolved or not — paginate until `hasNextPage` is `false`,
   never stop at a fixed page size), every review body submission, and
   every regular PR comment. The helper above reports counts/timestamps
   only; this raw set is what Step 3 filters.
4. From that raw set, exclude trusted-agent operational marker comments
   whose body starts with one of these prefixes, authored by a trusted
   marker actor:

   - `<!-- review-watermark:`
   - `<!-- review-baseline:`
   - `<!-- zero-accepted-path-a-gate:`
   - `<!-- claimed-by:`
   - `<!-- unclaimed-by:`
   - `advisory-wait:`
   - `advisory-wait-recovery:`
   - `<!-- advisory-wait:`
   - `advisory-reroll:`
   - `review-ack:`
   - `copilot-unavailable:`
   - `<!-- idd-external-check-waiver:` (also from
     `github-actions[bot]` when that login is not configured)
   - `<!-- idd-local-validation-evidence:`
   - the live-status digest (any form)

   Never exclude an untrusted-author marker-shaped comment; flag it as
   suspicious if it affects a decision.
5. Fetch bot activity; lite F2 skips
   `secondaryQuietWindow`.

### Step 2 — Record the watermark

After deferral, rerun Step 1 for fresh `latest-ci-completed-at`; never
reuse deferred value.

Post a marker per E1 pass when satisfied. Prefer
the one-command path: `node
scripts/post-idd-marker.mjs --type watermark --from-pr {pr-number}
--expected-head-sha {head-SHA} --agent-id <id> --claim-id <id>
--trusted-marker-logins "<trusted-login-1>,<trusted-login-2>" --apply`
(or the package-manager equivalent). Always pass `--expected-head-sha`
with the exact Step 1 `{head-SHA}`; the helper fails closed (posts
nothing) when the branch moved since Step 1 — on that failure, return
to Step 1 and re-snapshot the moved branch, not a Step 2 retry.

The manual six-field fallback — `--type watermark --target pr
{pr-number} --agent-id <id> --claim-id <id> --head-sha {head-SHA}
--max-activity-at {max-activity-updatedAt|none} --total-item-count
{total-item-count} --ci-completed-at {latest-ci-completed-at|none}
--apply` — stays available when `--from-pr` cannot run. Before using it,
require each required `(checkName, workflowName)`
producer to pass for `{head-SHA}` and verify advisory identity/event;
raw names are insufficient. Otherwise skip Step 2 and use E15/E14.

The rendered body is exactly:

```markdown
<!-- review-watermark: {agent-id} {claim-id} {head-SHA} {max-activity-updatedAt|none} {total-item-count} {latest-ci-completed-at|none} -->

_{agent-id}: review triage snapshot — IDD automation marker. Do not edit._
```

Match the PR body's language for the visible note (default English if
ambiguous). Nothing may follow the note — content after it, or after
the token with no note, makes the whole comment unrecognized as a live
watermark.

On resume or restart, read the latest trusted same-claim
`review-watermark` to restore all six values. Ignore watermarks from
any other claim or untrusted author; a legacy watermark with no
`{claim-id}` isn't resumable. If no trusted same-claim watermark
exists, rerun E1 from scratch. After a forced handoff, prior-claim
watermarks are foreign restore markers — ignore, never hide or
delete, and rerun E1 under the successor claim.

After the new watermark is verified, minimize every strictly older
trusted same-claim `review-watermark`/`review-baseline` comment as
`OUTDATED`: `node scripts/minimize-superseded-markers.mjs
--subject-ids "<id1>,<id2>,..." --classifier OUTDATED
--trusted-marker-logins "<trusted-login-1>,<trusted-login-2>" --apply`.
Skip this cleanup (not a stop condition) when the new watermark isn't
verified, the candidate set is empty, or the helper is unavailable —
F4 catches leftovers later. Never hide a different-claim watermark
here.

Do not touch the PR live status digest after posting this watermark
unless the next route is E1, an F3-blocked reroute to F1/D4, a
hold/stop, or post-merge cleanup — a digest edit after the watermark
counts as new activity, forcing a fresh E1 snapshot before F2.

### Step 3 — Filter into ReviewItems_snapshot

From the raw Step 1 set, select into **ReviewItems_snapshot** and
record each item's source URL:

- **Unresolved review threads** (`isResolved=false`) — exclude when the
  last substantive reply is by an IDD agent or PR author with no reviewer
  reply; keep reopened threads and `**Awaiting maintainer decision**`
  replies active.
- **Review bodies** whose reviewer's latest state is
  `CHANGES_REQUESTED` — exclude any already replied-to and
  re-review-requested in a prior E13/E14 pass.
- **Embedded CodeRabbit findings:** add one PATH B item per
  `embeddedFindings[].uncoveredCount`; only `COMMENTED` CodeRabbit
  reviews qualify. Inspect other bots' `COMMENTED` bodies for threadless
  findings. See the [#2197/#2559 rationale](../../../docs/idd-design-rationale.md#an-advisory-bots-embedded-but-unthreaded-findings-mirror-the-detection-scope-not-the-gate-scope).
- **Regular comments** where the last speaker is not an IDD agent and no
  reply from **you** exists after the comment, or whose latest IDD-agent
  reply starts with `**Awaiting maintainer decision**` — exclude periodic
  bots; keep Copilot/CI comments for PATH B, including E6 notices.

Also carry a light **resolved-thread index** (`isResolved=true`) with
file/area, claim, source URL, and any disposition marker. Never re-add
resolved threads to ReviewItems_snapshot; use the index only for E5's
duplicate pre-check.

## E2 — Critique pass

Run one critique pass on the branch's changes every E1-E3 pass (always).
Add any newly found issues to
ReviewItems_snapshot.

Per-agent E2: resolve `critiqueLoop.subagentWaitCeiling` (`PT20M` default) with
a harness timeout, not a wrapper (#3449). Only per-agent; shell-delegate rules
unchanged. Background waits require cleanup; suppress late output.
Timeout/cancel/interruption/error without findings uses self-critique fallback;
mark failure/risk, never clean or phase-level `mode` wait. Without
bound/cleanup, self-critique; record risk/no return.

Apply these lenses when they fit (composing when both do):
**Mutation / write-side** (the diff implements a helper that mutates
GitHub state, mutates git state, or performs a merge) — Fail-closed
inputs; Validate/execute scope parity; Unsafe-output suppression;
Schema strictness parity. **Gate-mirroring** (the diff implements a
helper that predicts, mirrors, or pre-checks another gate's decision) —
Validation-path parity; Input completeness; Whole-identity comparison;
Snapshot identity; Point-in-time parity.

**Incremental scope**: on later passes within the same claim, review the
diff since the previous E2 head, tracked by a same-claim
baseline whose GraphQL `lastEditedAt` was resolved via node id/
`includeEditState` and is explicitly `null`; use a full-branch diff if
that proof fails, after a rebase, multi-fix batch, non-ancestor baseline,
or active-claim change. Do not infer edit state from the body, `updatedAt`,
author, or claim. ReviewItems_snapshot is session-local — do not inherit
a previous claim's critique findings unless persisted as reviewer-visible
comments.

Before critique, set `{e2-review-head-SHA}` to Step 1's `{head-SHA}`;
do not capture another HEAD. Reread HEAD before posting. If it changed,
discard the pass and return to E1; otherwise post a baseline pinned to
the captured SHA: `node
scripts/post-idd-marker.mjs --type baseline --target pr {pr-number}
--agent-id <id> --claim-id <id> --sha {e2-review-head-SHA} --apply`, or
the package-manager equivalent. Never record a newer SHA; reread HEAD
after posting and return to E1 if it changed. Rendered body:

```markdown
<!-- review-baseline: {agent-id} {claim-id} {SHA} -->

_{agent-id}: critique baseline — IDD automation marker. Do not edit._
```

Match the PR body's language, same rule as the watermark; nothing may
follow the note here either.

## E3 — Empty/non-empty routing

When Step 2 was deferred, reread the live PR HEAD before E3. A mismatch
with Step 1's `{head-SHA}` returns to E1 for a fresh snapshot; never route
stale items into E3/E4.

- **Empty, Step 2 ready** → `idd-pre-merge-lite.instructions.md` (F1);
  not triage.
- **Empty, Step 2 deferred** → E15 for CI or E14 for advisory; both:
  E14 first, then E1 before F1/F2.
- **Non-empty** → stop; hand off to `idd-review-triage.instructions.md`
  (E4).

## Cold-start ReviewItems_snapshot reconstruction

Read this entering E4/E9 without this episode's ReviewItems_snapshot
(lost/restarted session, or mid-review delegation hand-off).

**Procedure**: rerun Step 1-3 (Step 2 posts the watermark when eligible —
never a second one), then edge case 2's steps 1-3 unconditionally
before E3, then E2, E3. Only when E3 is non-empty, hand off E4-E8
fully before E9. An edge-case-1 item routed to E14 runs E14 after edge
case 2's own push (if any, targeting post-push HEAD), before
branch-sync.

**Edge case 1 — item with no completed disposition.** Covers a lost
session mid-classification, a landed-but-unreplied E12 push, or a
`CHANGES_REQUESTED` body missing only its E14 request. Already has an
E13 `**Accepted** — fixed in` reply with no reviewer reply/reopen
since → skip reclassification, straight to E14. Otherwise
Step 3/E4-E8 decide as usual, flagging whether a commit newer than the
item's timestamp touches its anchored path(s) (thread `path` or a
file named in a regular comment's context) and fixes it (a lost E12
push, or edge case 2's diff below): a match reads **false** against
E5's claim-truth test by design, so an in-scope reviewer-feedback
PATH A item can Accept, not wrongly Reject, and cite it (cap
included) — E9 skipped, E13 still cites it. No match: never coverage,
normal handling applies.

**Edge case 2 — an E9 fix committed but not pushed.** GitHub can't see
this; an empty E3 alone isn't proof nothing needs recovery (F2
resets the worktree before merge). Run unconditionally in the same
surviving claimed worktree:

1. `PR_HEAD` = Step 1's stored `{head-SHA}` — never re-fetch (races an
   external rewrite).
2. `git merge-base --is-ancestor "$PR_HEAD" HEAD` — failure (rewrite,
   diverged worktree): stop and ask, never fall through to edge case 1.
3. `git status --porcelain` must be clean — dirty can't attribute
   lines to items: stop and ask, never guess.
4. `git log "$PR_HEAD"..HEAD` non-empty: record the diff (edge case 1
   covers it too); it still needs E10-E12 to validate and push before
   branch-sync. **E3 empty**: resume at E10, not E12 (a cold session
   can't know if E10's critique already ran; fail-closed governs).
   **E3 non-empty**: hand off E4-E8 first; the receiving flow's own E8
   decides E9, but E10-E12 for the diff still runs even if E8 accepts
   zero items.

Clean worktree, no local-ahead commits: E3's routing applies unchanged;
a fresh or lost worktree falls back to edge case 1, re-triaged from
scratch.
