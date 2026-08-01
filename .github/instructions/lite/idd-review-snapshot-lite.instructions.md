# IDD — Review Snapshot Phase (Lite) (E1-E3)

Lite profile for helper-enabled weak/local models. Same semantics as
`idd-review-snapshot.instructions.md`. Use only for the single issue this
session already claimed, with an open PR whose CI has passed or that
already has reviews. If the repository is `instructions-only`, use the
standard review-snapshot instructions instead.

## Helper runtime contract

- Helper-enabled profiles: when a step names a helper or command set, use
  it. If a required helper is missing, fails, or disagrees with live
  state, stop and ask. Do not fall back silently to prose.
- `instructions-only`: do not use this lite file; use
  `idd-review-snapshot.instructions.md` instead.
- Any mismatch between this file and the standard review-snapshot phase
  is a bug in this file.

## Triage hand-off boundary (E4-E8 excluded)

This file only fetches, freezes, and routes ReviewItems_snapshot. It
never classifies findings, scores severity, or decides Accept/Reject —
those are E4-E8 judgment calls, excluded from every lite profile, the
same boundary `idd-review-fix-lite.instructions.md` states on its own
downstream side (it only executes dispositions an E4-E8 pass already
made).

1. E3's non-empty-list outcome hands off to
   `idd-review-triage.instructions.md` (E4-E8). A stronger session or a
   human runs that pass — this lite file never runs E4-E8 itself, even
   when a finding looks trivial to classify.
2. If you catch yourself judging severity, deciding Accept/Reject, or
   assigning a PATH before handing off to E4, stop and ask instead.

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
   confirm it still wins (no later trusted marker for this claim id won
   the tie-break instead).
3. The current directory is the sibling worktree for the claimed branch.
4. `git branch --show-current` equals the claimed branch.
5. Acquire the worktree-local claim lock with the profile-selected
   `claim-lock` helper (`node scripts/claim-lock.mjs --acquire
   --worktree <this-worktree-path> --agent-id <id> --claim-id <id>`, or
   the package-manager-profile `idd:claim-lock` command with the same
   arguments — resolve the exact command from
   `docs/idd-helper-scripts.md` if unsure). A `collision` result is
   fail-closed: stop rather than proceed.
6. If any check fails, stop.

## E1 — Fetch review items into ReviewItems_snapshot

### CI-completion precondition (before Step 1)

Before taking the Step 1 snapshot, confirm every CI run that counts
toward the merge gate has completed, including any opt-in or
label-triggered job enabled at this quiescent point. If the primary
advisory bot already reviewed an earlier head of this PR, an automatic
same-head re-review is expected — run the advisory-wait-state helper and
check its own `lastCopilotCommit == prHeadSha` fast-path fields (from
`idd-advisory-wait-lite.instructions.md`; both read fresh from that
helper's output, independent of Step 1's `{head-SHA}` below, which is not
captured yet at this point) and wait for that re-review to land first,
bounded by that file's advisory-wait windows if it never does. Only
once this precondition is satisfied, continue to Step 1.

### Step 1 — Snapshot the activity universe

1. Read the current PR HEAD SHA once — `gh pr view {pr-number} --json
   headRefOid --jq '.headRefOid'` — and store it as `{head-SHA}`. Do not
   re-read the HEAD SHA anywhere else in E1; reuse this stored value.
2. Run the profile-selected `review-activity-snapshot` helper to collect
   `{head-SHA}`, `{max-activity-updatedAt}`, `{total-item-count}`, and
   `{latest-ci-completed-at}`: `node scripts/review-activity-snapshot.mjs
   --pr {pr-number} --trusted-marker-logins
   "<trusted-login-1>,<trusted-login-2>"`, or the package-manager
   equivalent (resolve from `docs/idd-helper-scripts.md`). This is the
   Step 2 watermark's data source, not a triage tool. The helper emits
   both `latestCiCompletedAt` and `latestPassingCiCompletedAt`;
   `{latest-ci-completed-at}` is always the latter — the latest
   _passing_ (or treated-as-passed) completion, never the latest
   completion regardless of outcome.
3. Independently fetch, in one pass before applying any filter: every
   review thread (resolved or not — paginate until `hasNextPage` is
   `false`, never stop at a fixed page size), every review body
   submission, and every regular PR comment. The helper above reports
   counts and timestamps only; this raw item set is what Step 3 filters.
4. From that raw set, exclude trusted-agent operational marker comments
   whose body starts with one of these prefixes, authored by a trusted
   marker actor:

   - `<!-- review-watermark:`
   - `<!-- review-baseline:`
   - `<!-- claimed-by:`
   - `<!-- unclaimed-by:`
   - `advisory-wait:`
   - `advisory-wait-recovery:`
   - `<!-- advisory-wait:`
   - `advisory-reroll:`

   Never exclude a marker-shaped comment from an untrusted author; keep
   it and flag it as suspicious if it affects a decision.
5. Non-Copilot advisory safety net: when the repository configures
   non-Copilot `advisoryBotLogins` (for example CodeRabbit), this
   full-universe snapshot plus the Step 2 watermark delta is the only
   safety net for their late-arriving findings — never skip or narrow
   this fetch even when Copilot's own advisory-wait window already looks
   satisfied.

### Step 2 — Record the watermark

Post one marker per E1 pass. Prefer the one-command path: `node
scripts/post-idd-marker.mjs --type watermark --from-pr {pr-number}
--expected-head-sha {head-SHA} --agent-id <id> --claim-id <id>
--trusted-marker-logins "<trusted-login-1>,<trusted-login-2>" --apply`
(or the package-manager equivalent). Always pass `--expected-head-sha`
with the exact Step 1 `{head-SHA}`; the helper fails closed — posts
nothing — when the branch moved since Step 1. On that failure, do not
retry Step 2 as-is: return to Step 1 and re-snapshot the moved branch.

The manual six-field fallback — `--type watermark --target pr
{pr-number} --agent-id <id> --claim-id <id> --head-sha {head-SHA}
--max-activity-at {max-activity-updatedAt|none} --total-item-count
{total-item-count} --ci-completed-at {latest-ci-completed-at|none}
--apply` — stays available when `--from-pr` cannot run.

The rendered body is exactly:

```markdown
<!-- review-watermark: {agent-id} {claim-id} {head-SHA} {max-activity-updatedAt|none} {total-item-count} {latest-ci-completed-at|none} -->

_{agent-id}: review triage snapshot — IDD automation marker. Do not edit._
```

Match the PR body's language for the visible note; default to English
when ambiguous. Nothing may follow the note — any content appended
after it, or appended directly after the token with no note, makes the
whole comment unrecognized as a live watermark.

On resume or restart, read the latest trusted `review-watermark`
comment whose `{claim-id}` matches the current active claim to restore
all six values. Ignore watermarks from any other claim or untrusted
author; a legacy watermark with no `{claim-id}` is not resumable. If no
trusted same-claim watermark exists, rerun E1 from scratch. After a
forced handoff, all prior-claim watermarks are foreign restore markers
— ignore them, never hide or delete them, and rerun E1 under the
successor claim.

After the new watermark is verified to exist, minimize every strictly
older trusted same-claim `review-watermark` / `review-baseline` comment
as `OUTDATED`: `node scripts/minimize-superseded-markers.mjs
--subject-ids "<id1>,<id2>,..." --classifier OUTDATED
--trusted-marker-logins "<trusted-login-1>,<trusted-login-2>" --apply`.
Skip this cleanup entirely (not a stop condition) when the new watermark
was not verified, the candidate set is empty, or the helper is
unavailable — F4 catches any leftovers later. Never hide a
different-claim watermark here.

Do not create or edit the PR live status digest after posting this
watermark unless the next route is back to E1, an F3 blocked reroute
that returns to F2's restart path, a hold/stop, or post-merge cleanup —
a digest edit after the watermark counts as new activity and forces a
fresh E1 snapshot before F2 can pass.

### Step 3 — Filter into ReviewItems_snapshot

From the raw Step 1 set, select into **ReviewItems_snapshot** and
record each item's source URL:

- **Unresolved review threads** (`isResolved=false`) — exclude a thread
  only when its latest substantive reply is from any IDD agent or the
  PR author, and no reviewer has replied since. Keep it active anyway,
  even in that case, when either holds: the reviewer reopened it after
  that latest agent/author reply, even with no new text; or the thread
  contains an agent reply starting with `**Awaiting maintainer
  decision**` (stays a blocker regardless of maintainer response).
- **Review bodies** whose reviewer's latest state is
  `CHANGES_REQUESTED` — exclude one already replied to and
  re-review-requested in a prior E13/E14 pass.
- **Regular comments** where the last speaker is not any IDD agent and
  no reply from you postdates that comment — exclude periodic
  notification bots (Renovate, etc.). Keep Copilot and CI advisory bot
  comments; they route through PATH B in E4-E7 (non-review notices —
  rate-limit / quota / queued / bare acknowledgement / error — get
  dispositioned under the E6 non-review-notice rule, not here).

Also carry forward, from the same Step 1 thread set, a light
**resolved-thread index** (`isResolved=true`): for each, the file/area,
a short claim summary, the source URL, and any recorded `**Accepted**` /
`**Rejected**` disposition marker. Do not add resolved threads back
into ReviewItems_snapshot. This index is a routing hint only for E5's
duplicate pre-check in `idd-review-triage.instructions.md` — it tells
triage where a recurrence might be, not what to conclude.

## E2 — Critique pass

Run one critique pass on the branch's changes every E1-E3 pass — this is
a deterministic "always run one" step, not a judgment call whether to
run it. Add any newly found issues to ReviewItems_snapshot.

**Incremental scope**: on the second and later passes within the same
claim, scope the review to the diff since the previous E2's head SHA,
tracked by the latest trusted same-claim `review-baseline` comment.
Reset to the full-branch diff after any of: a rebase, a multi-fix batch,
the baseline SHA is not an ancestor of the current HEAD, no trusted
same-claim baseline exists, or the active claim changed (restart,
takeover, or forced handoff). ReviewItems_snapshot is session-local — do
not inherit a previous claim's critique findings unless they were
already persisted as reviewer-visible comments.

After the critique pass completes, read the current PR HEAD SHA again
and store it as `{e2-head-SHA}` — `gh pr view {pr-number} --json
headRefOid --jq '.headRefOid'` — since it can differ from Step 1's
stored `{head-SHA}` if the branch moved during E1/E2, and the baseline
must record what the critique pass actually reviewed. Post a new
baseline with `{e2-head-SHA}`: `node scripts/post-idd-marker.mjs --type
baseline --target pr {pr-number} --agent-id <id> --claim-id <id> --sha
{e2-head-SHA} --apply`, or the package-manager equivalent. Rendered
body:

```markdown
<!-- review-baseline: {agent-id} {claim-id} {SHA} -->

_{agent-id}: critique baseline — IDD automation marker. Do not edit._
```

Match the PR body's language for the visible note, same rule as the
watermark. The same "nothing after the note" rule applies here too.

## E3 — Empty/non-empty routing

- **ReviewItems_snapshot is empty** → proceed to the E-phase branch-sync
  check in `idd-review-triage.instructions.md`.
- **ReviewItems_snapshot is non-empty** → this lite session's job for
  this PR ends here. Do not classify or disposition any item yourself
  (see Triage hand-off boundary above); hand off to
  `idd-review-triage.instructions.md` (E4) for a stronger session or a
  human to run.
