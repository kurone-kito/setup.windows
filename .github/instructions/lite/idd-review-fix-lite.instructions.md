# IDD — Review Fix Phase (Lite) (E9–E15)

Lite profile for helper-enabled weak/local models. Same semantics as
`idd-review-fix.instructions.md`. Use only for a single claimed issue with
an open PR. If the repository is `instructions-only`, use the standard
review-fix instructions instead.

## Helper runtime contract

- Helper-enabled profiles: when a step names a helper or command set, use
  it. If a required helper is missing, fails, or disagrees with live
  state, stop and ask. Do not fall back silently to prose.
- `instructions-only`: do not use this lite file; use
  `idd-review-fix.instructions.md` instead.
- Any mismatch between this file and the standard review-fix phase is a
  bug in this file.
- **Command sets**: `fix-validate` (E9) and `post-fix-validate` (E12) are
  read from `.github/idd/config.json`'s `commands` mapping. If that file
  is missing or the command set cannot be read, stop and ask rather than
  guessing a command.

## Upstream-triage boundary

This file only executes triage dispositions someone else already made.
It never classifies, scores severity, or decides Accept/Reject itself —
those are E4-E8 judgment calls, excluded from every lite profile.

1. Before fixing anything, confirm every item from ReviewItems_snapshot
   that this round acts on already carries an `**Accepted**` or
   `**Rejected**` disposition from a prior E4-E8 pass.
2. If a ReviewItems_snapshot item has no recorded disposition, stop and
   ask. Do not triage it yourself, and do not guess its severity.
3. Only act on ReviewItems_snapshot items already marked `**Accepted**`.
   Leave `**Rejected**` items alone.
4. This boundary covers ReviewItems_snapshot items only — the ones E9
   fixes and E13 replies to. It does not cover E10's own critique
   findings (E10 fixes those directly, per its own step, the same
   self-review loop every phase uses) or E12's bounded cross-round
   batching allowance (which explicitly permits folding in bot-sourced
   comments not yet gone through triage, under its own separate
   conditions).

## Stop-and-ask conditions

- A ReviewItems_snapshot item with no recorded E4-E8 disposition is in
  scope for this round (see Upstream-triage boundary).
- The active claim is ambiguous, disputed, or lost.
- A required helper is missing, fails, or disagrees with live state.
- E10's critique loop repeats the same Accepted findings for more than
  `critiqueLoop.e10NoProgressHoldAfter` (default 3) passes without
  meaningful progress.
- E11 merge conflicts cannot be resolved cleanly, or the PR has
  unresolved review threads, unreplied comments, or a
  `CHANGES_REQUESTED` reviewer and no explicit operator confirmation
  exists to merge `main` into the feature branch anyway.
- A CI failure is neither clearly code-caused nor recognized
  infra-flaky/pre-existing, **except** the sole-failing
  `idd-advisory-convergence` check with `pending: false` and outstanding
  review reasons — that case routes to E1 per E15 step 9, not
  stop-and-ask.
- Advisory-wait reaches `HOLD`, `CAP_EXHAUSTED` with a `hold` route, or a
  pending-refresh-failed state.
- The claim-lock helper reports a collision (a different claim id
  already holds the worktree lock).

## Pre-mutation guard

Before any commit, push, merge, reply, resolve, reviewer request, or
other GitHub side effect, confirm all of the following:

1. The active claim still uses this session's claim id.
2. The current directory is the sibling worktree for the claimed branch.
3. `git branch --show-current` equals the claimed branch.
4. Acquire the worktree-local claim lock with the profile-selected
   `claim-lock` helper (`node scripts/claim-lock.mjs --acquire
   --worktree <this-worktree-path> --agent-id <id> --claim-id <id>`, or
   the package-manager-profile `idd:claim-lock` command with the same
   arguments — resolve the exact command from
   `docs/idd-helper-scripts.md` if unsure). A `collision` result is
   fail-closed: stop rather than proceed.
5. If any check fails, stop.

## E9 — Fix accepted issues

1. Fix every Accepted PATH A item from the current ReviewItems_snapshot.
2. Run `fix-validate`.
3. Commit fixes atomically — one logical change per commit.
4. When an accepted finding is one instance of a systemic class, sweep
   the current diff and adjacent touched sections and fix every
   instance in the same commit.
5. When a fix introduces a precision (a name, value, path, or described
   behavior) to satisfy a reviewer, verify it against the actual
   implementation before committing.
6. If an Accepted item is already fixed by a prior commit in this same
   round, do not duplicate the fix. Confirm the existing commit
   addresses it and let E13 cite that SHA.
7. Do not push yet. All of this round's fixes push together at E12.

## E10 — Validate fixes with critique pass

1. Run a critique pass to verify the E9 fixes address the root causes
   and are correct.
2. If the critique pass reports zero issues, continue to E11.
3. If it reports additional issues, fix them, commit atomically, and
   run E10 again.
4. Count "meaningful progress" as removing at least one Accepted
   finding, narrowing a remaining finding's root cause or scope, or
   producing a materially new fix direction. A reworded duplicate
   finding does not count.
5. If the same Accepted findings recur for more than
   `critiqueLoop.e10NoProgressHoldAfter` (default 3) consecutive E10
   passes without meaningful progress, stop the loop, post a hold
   comment summarizing the repeated findings and attempted fixes, and
   wait for a maintainer decision.
6. Do not use step 5 to bypass a serious issue: unresolved High or
   Medium findings stay blockers until fixed or explicitly redirected
   by a maintainer.

## E11 — Resolve conflicts with main

1. Check for conflicts between the feature branch and `main`.
2. If none exist, continue to E12.
3. If conflicts exist, and the PR has unresolved review threads,
   unreplied comments, or a reviewer's latest state is
   `CHANGES_REQUESTED`, get explicit operator confirmation before
   merging — the merge commit will appear in the PR history.
4. Run `git fetch origin main && git merge origin/main`.
5. On a signed-commit repo whose primary signing is non-interactive
   hostile (GPG pinentry or hardware-touch) but that provides a
   fallback signing wrapper for arbitrary git subcommands (pass
   `-c gpg.format=ssh -c user.signingkey=<abs-path> -c
   commit.gpgsign=true` to `git` before the subcommand — `git -c …
   merge`, not `git merge -c …`; a commit-only alias like
   `git commit-ssh` will not run `merge`), run this merge through that
   wrapper, not the plain command.
6. Resolve any conflicts and complete the merge.
7. If the merge needed `--continue`, run it through the same wrapper
   used in step 5 (`git -c … merge --continue`), never the plain
   `git merge --continue` — the wrapper must own the whole operation, or
   the merge commit reverts to the stalling primary signing.

## E12 — Lint, test, push

1. Run `post-fix-validate`.
2. Push the feature branch normally — E11 uses merge commits, so no
   force push is required.
3. Before this push, a small number of review comments may arrive that
   fall outside this round's scope and have not yet gone through
   triage. Fold them into this same pending push, each as its own
   atomic commit, only when every one of steps 4-7 holds.
4. Every comment that arrived since the last push is bot-sourced:
   authored by the primary advisory bot's login — for the Copilot
   default, any login equal to `copilot` or starting with
   `copilot-pull-request-reviewer` counts, matching
   `isCopilotReviewerLogin` — or an `advisoryBotLogins` login,
   regardless of PATH A/B. A login also configured as
   `secondaryBotLogin` still qualifies as bot-sourced.
5. Each such comment is a small, confirmable fix whose claim you
   checked against live evidence (a linter run, actual file content,
   actual runtime behavior) before folding it in. Never fold in a
   bot-asserted-only finding.
6. The resulting commit touches only files this round's pending fixes
   already touch, and you re-ran `post-fix-validate` first.
7. No CI-wait poll (E15) is currently in flight for this branch.
8. Stop accumulating and push immediately once any of these happens: a
   PATH A item from a human or CODEOWNER reviewer arrives (bot-sourced
   alone does not count); any item requests a substantive code/logic
   change, not a small textual fix; any item falls outside the
   touched-file scope from step 6; you have accumulated 3 additional
   commits; or 10 minutes have passed since the first accumulated
   commit.
9. This allowance never delays, holds, or interrupts an in-flight CI
   wait, and never changes PATH A/B routing or triage timing — only
   push timing changes. A folded-in comment does **not** get a
   disposition reply in this round — it keeps its formal PATH
   classification and individual E6 disposition reply for the next
   E1/E4-E7 pass, exactly like the standard file. E14 still requests a
   fresh primary-bot re-review after every push. The per-HEAD
   `review-watermark` still invalidates on this push.
10. Apply the pre-mutation guard immediately before this push.

## E13 — Reply to feedback

1. For each Accepted PATH A item whose source is reviewer feedback
   (review thread, review body, or regular comment), reply describing
   which commits fixed it and how.
2. Start every reply with:
   `**Accepted** — fixed in {commit-sha or comma-separated list}: {brief explanation}`
3. For a review thread, immediately resolve the thread after posting
   the reply. Reply first, resolve second, so a failed reply never
   leaves a silently-resolved thread.
4. For a regular comment, reply only; do not resolve.
5. If a non-review notice (rate-limit / usage-limit / review-limit) was
   already dispositioned `**Rejected** — {bot} did not review HEAD …` in
   a prior pass, carry that rejection forward. Do not re-post an
   identical rejection just because the notice's timestamp bumped or the
   bot re-posted the same summary. Only disposition it again if the bot
   replaced the notice with an actual completed review of the current
   HEAD.
6. After all replies and resolutions in this step are complete, update
   the PR live status digest: `Phase` to `E13 feedback replied`, `Open
   blockers` to any remaining reviewer, advisory, or CI wait, `Next
   action` to E14 or E15, and `Authoritative by` to the replies,
   resolved threads, current HEAD, and verified claim.

## E14 — Re-review request

1. For each human reviewer whose latest state is `CHANGES_REQUESTED` and
   whose items are all addressed, request a re-review:
   `gh pr edit {pr-number} --add-reviewer {reviewer-login}`.
2. Fetch the current head:
   `PR_HEAD_SHA=$(gh pr view {pr-number} --json headRefOid --jq '.headRefOid')`.
3. Run the profile-selected `advisory-wait-state` helper — the
   canonical evidence collector per
   `idd-advisory-wait-lite.instructions.md`'s helper-first path (`node
   scripts/advisory-wait-state.mjs --pr {pr-number}
   --trusted-marker-logins "<trusted-login-1>,<trusted-login-2>"` in
   the source/vendored profile; resolve the package-manager /
   ephemeral-npx equivalent from `docs/idd-helper-scripts.md`). If it
   fails, returns invalid JSON, or is missing required fields
   (`prHeadSha`, `lastCopilotCommit`, `copilotPending`,
   `copilotPendingCoversHead`, `outcome`, `f3Outcome`,
   `secondaryBotLogin`, `secondaryRequestNeeded`, `earliestSameHeadAt`,
   `requestMarkerCount`, `requestCap`, `pendingWindowMinutes`,
   `settledWindowMinutes`, `pollIntervalMinutes`, `capExhaustedRoute`,
   `trustedMarkerSummary` — the full contract in
   `docs/idd-helper-scripts.md#stable-helper-evidence-outputs` and
   `schemas/advisory-wait-state.schema.json`), stop and ask — do not
   fall back to a manual per-field fetch.
4. Read the helper's `outcome` field and apply this decision table, top
   to bottom, first match wins:
   - `SATISFIED` → continue to E15.
   - `RECOVERY_NEEDED`: post the recovery marker
     `advisory-wait-recovery: {agent-id} {PR_HEAD_SHA}
     {ISO8601-recovery-time}` as plain text. Do not request another
     review. Then go to the polling loop below.
   - `REQUEST_NEEDED`: if `copilotPending` is true, first remove the
     stale pending request with `gh pr edit {pr-number}
     --remove-reviewer "@{primary-advisory-bot}"` (on a GraphQL
     login-resolution failure, retry via `gh api
     repos/{owner}/{repo}/pulls/{pr-number}/requested_reviewers -X
     DELETE -f "reviewers[]={primary-advisory-bot-rest-login}"`; if
     removal fails because the bot is no longer pending, re-run this
     step from the top; if it fails for any other reason, post a hold
     comment and stop). Then request the review with `gh pr edit
     {pr-number} --add-reviewer "@{primary-advisory-bot}"` (on the same
     GraphQL failure, retry via `gh api
     repos/{owner}/{repo}/pulls/{pr-number}/requested_reviewers -X POST
     -f "reviewers[]={primary-advisory-bot-rest-login}"`). Immediately
     post `advisory-wait: {agent-id} {PR_HEAD_SHA}
     {ISO8601-requested-at}` as plain text, not an HTML comment. Then go
     to the polling loop below.
   - `CAP_EXHAUSTED`: apply step 10 below (the secondary-bot check)
     first — it is a non-gating supplement that fires on cap exhaustion
     independent of the cap-exhausted route. Then, if the helper's
     `capExhaustedRoute` is `hold`, post a hold comment and stop;
     otherwise (`phase-specific`, the default) continue to E15.
   - `WAIT`: if `copilotPending` is true and elapsed time since
     `earliestSameHeadAt` is at least the helper's
     `pendingWindowMinutes`, apply step 10 below (the secondary-bot
     check) first, then continue to E15; if `copilotPending` is false
     and elapsed time is at least `settledWindowMinutes`, do the same;
     otherwise go to the polling loop below.
5. The default primary advisory bot is Copilot: use `copilot` for
   `{primary-advisory-bot}` (the add/remove-reviewer login) and
   `copilot-pull-request-reviewer[bot]` for
   `{primary-advisory-bot-rest-login}` (the REST fallback login). A
   repository may configure a different bot in
   `advisoryWait.primaryBotLogin` — when it does, use that configured
   login for **both** placeholders, since a configured login is already
   the real account login.
6. Whenever this step posts an advisory request marker, recovery
   marker, or hold comment, update the digest with the current advisory
   state, that marker or comment as `Authoritative by`, and the next
   polling or maintainer action in `Next action`.
7. **Active polling loop.** Do not post a new marker if a same-head
   marker already exists; reuse the one with the earliest `createdAt`
   (the helper's `earliestSameHeadAt` already gives you this). Take a
   fresh activity snapshot (same scope as E1 Step 1) and record its
   highest `updatedAt` as a temporary polling watermark — do not post
   it as a `review-watermark` comment. If the snapshot is empty, use
   the `createdAt` of the latest `review-watermark` comment whose
   `{claim-id}` matches the current active claim and whose author is a
   trusted marker actor instead. If no trusted same-claim watermark
   exists, stop polling and return to E1 to create one.
8. Poll on the interval from the helper's `pollIntervalMinutes`. Each
   cycle: re-fetch the current head; if it differs from `PR_HEAD_SHA`,
   stop polling and return to `idd-review-snapshot.instructions.md`
   (E1). Otherwise re-read threads, review bodies, and regular comments
   (excluding trusted operational markers); if anything has `updatedAt`
   newer than the polling watermark, stop polling and return to E1.
   Otherwise re-run the step-3 helper. If it fails, returns invalid
   JSON, or is missing required fields, stop and ask — do not fall back
   to a manual per-field fetch. If `earliestSameHeadAt` is now empty,
   post a hold comment noting the advisory-wait marker for
   `PR_HEAD_SHA` disappeared during polling and stop. If `outcome` is
   now `SATISFIED`, exit polling and continue to E15.
9. Otherwise re-apply the elapsed-window check from step 4's `WAIT`
   branch using the refreshed helper output: if the window is now
   satisfied, apply step 10 below (the secondary-bot check) first, then
   exit polling and continue to E15 — the primary bot never reviewed
   this HEAD, which is exactly the stalled/rate-limited case step 10
   exists for. Else keep polling. A stalled or silent advisory bot must
   not cause unbounded polling — this elapsed-window re-check is what
   times the loop out even when the bot never reviews the current HEAD.
10. **Optional secondary advisory bot (non-gating).** Use the most
    recent step-3/step-8 helper output's `secondaryRequestNeeded` and
    `secondaryBotLogin` fields directly — do not re-derive the
    request/already-requested condition manually. When
    `secondaryRequestNeeded` is `true`, request `secondaryBotLogin`
    once for this HEAD using the same gh-then-REST fallback as the
    primary in step 4. Post no `advisory-wait:` marker for the
    secondary — it must never satisfy the primary gate or consume the
    primary's request cap — and never let it change the route already
    decided above. The secondary's review is ordinary advisory input,
    picked up by the next E1 snapshot if it lands before merge. Skip
    this step entirely when `secondaryRequestNeeded` is `false` (which
    also covers no secondary configured, per the helper contract).
11. Advisory feedback is advisory: you are not obligated to accept
    every suggestion, but you must still wait for a review you
    explicitly requested. A human `CHANGES_REQUESTED` reviewer is not
    advisory and stays under the hold/escalation path in the standard
    file.

## E15 — Wait for CI

1. Schedule a wake, or background this wait only if the topology-safety
   condition is confirmed to route completion back to this turn;
   otherwise wait synchronously.
2. Use `idd-ci-lite.instructions.md` for the polling mechanics and
   timing (required-check discovery, state normalization, and the
   shared `ciWait.runningTimeout` / `ciWait.generationTimeout` /
   `ciWait.rerunPolicy` values). The outcomes below override its generic
   routing for this phase.
3. If new review threads or comments arrive during the wait, note them
   but keep waiting for CI.
4. On success: return to `idd-review-snapshot.instructions.md` (E1) —
   do not skip triage.
5. On failure that is code-caused: fix it, run `fix-validate`, commit
   atomically, then return to E11.
6. On failure that is infra-flaky or pre-existing (also failing on
   `main`, unrelated to this branch): apply `ciWait.rerunPolicy`. If it
   authorizes a rerun, rerun once and resume polling. If the failure
   persists after that rerun, or the policy is `hold`, post a hold
   comment documenting the pre-existing failure and stop for a
   maintainer.
7. On cancelled or timed-out that is code-caused: fix it, run
   `fix-validate`, commit, return to E11.
8. On cancelled or timed-out that is infra-caused: apply
   `ciWait.rerunPolicy`. Re-push or rerun only when the policy
   authorizes the current rerun; if the same outcome recurs after that
   rerun, or the policy is `hold`, post a hold comment and stop. On
   success after the rerun, return to E1.
9. If `idd-advisory-convergence` is the sole failing required check and
   its own verdict reports `pending: false` with outstanding review
   reasons, return to E1, not E11 — this is neither code-caused nor
   infra. Unless a maintainer has posted a valid external-check waiver
   for this HEAD, in which case apply `ciWait.rerunPolicy` instead so
   the rerun reflects the waiver.
10. When this step stops on a CI hold, update the digest: `Phase` to
    `E15 hold`, the failing or missing checks in `Open blockers`, and
    the maintainer or rerun expectation in `Next action`. On success, do
    not edit the digest before returning to E1.
