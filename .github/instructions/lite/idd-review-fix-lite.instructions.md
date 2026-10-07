# IDD — Review Fix Phase (Lite) (E9–E15)

Lite helper profile; claimed open PRs only. `instructions-only` uses the
standard file.

## Helper runtime contract

- Use every named helper or command set. Missing, failing, or disagreeing
  helpers are stop-and-ask conditions; never fall back silently to prose.
- `instructions-only` uses `idd-review-fix.instructions.md`.
- **Command sets**: `fix-validate` (E9) and `post-fix-validate` (E12) are
  read from `.github/idd/config.json`'s `commands` mapping. If that file
  is missing or the command set cannot be read, stop and ask rather than
  guessing a command. Judge each run by exit status (Bash
  `${PIPESTATUS[0]}`/`set -o pipefail`); a `tail`/`head` filter can't
  prove success (#3139).

## Upstream-triage boundary

This file executes only prior E4-E8 dispositions; it never classifies
severity or decides Accept/Reject.

1. Before fixing, confirm every acted-on ReviewItems_snapshot item has an
   `**Accepted**` or `**Rejected**` disposition from E4-E8.
2. An undispositioned item is stop-and-ask; do not triage or guess it.
3. Act only on `**Accepted**` items and leave `**Rejected**` items alone.
4. This boundary covers E9 fixes and E13 replies only. E10 critique
   findings and E12's bounded cross-round batching follow their own rules.

## Stop-and-ask conditions

- A ReviewItems_snapshot item with no recorded E4-E8 disposition is in
  scope for this round (see Upstream-triage boundary).
- The active claim is ambiguous, disputed, or lost.
- A required helper is missing, fails, or disagrees with live state.
- E10's critique loop repeats the same Accepted findings for
  `critiqueLoop.e10NoProgressHoldAfter` (default 3) passes without
  meaningful progress.
- E10's `critiqueLoop.delegate` under `on-success` or `never` left no
  readable findings list (vacuous verdict, not a clean zero-issue round).
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
2. If this session posted an activation nonce for the current claim,
   confirm it still wins (no later trusted marker for this claim id
   won the tie-break instead).
3. The current directory is the sibling worktree for the claimed branch.
4. `git branch --show-current` equals the claimed branch.
5. Acquire the worktree-local claim lock with the profile-selected
   `claim-lock` helper (`node scripts/claim-lock.mjs --acquire
   --worktree <this-worktree-path> --agent-id <id> --claim-id <id>`, or
   the package-manager-profile `idd:claim-lock` command with the same
   arguments — resolve the exact command from
   `docs/idd-helper-scripts.md` if unsure). A `collision` result is
   fail-closed: stop rather than proceed. Then, separately, run
   `--read-tokens --worktree <this-worktree-path> --claim-id <id>`
   and require `present: true` with no `malformed`; otherwise recover
   per `docs/idd-helper-scripts.md` (gated: each step succeeds,
   `reacquired: true` both ends), else stop.
6. If any check fails, stop.

## E9 — Fix accepted issues

1. PATH A/PATH B (from `idd-review-triage.instructions.md` E4): PATH A
   is actionable feedback: human reviewer threads, regular comments,
   `CHANGES_REQUESTED` bodies, critique-pass findings that require a
   code change or maintainer decision, and Copilot inline
   review-thread comments; PATH B is advisory feedback: Copilot's and
   CI advisory bots' review-summary bodies and regular comments,
   included for traceability, even when they do not require a code
   change.
2. Fix every Accepted PATH A item from the current ReviewItems_snapshot.
3. Run `fix-validate`.
4. Commit fixes atomically — one logical change per commit.
5. When an accepted finding is one instance of a systemic class, sweep
   the current diff and adjacent touched sections and fix every
   instance in the same commit.
6. When a fix introduces a precision (a name, value, path, or described
   behavior) to satisfy a reviewer, verify it against the actual
   implementation before committing.
7. If an Accepted PATH A item is already fixed by an earlier commit --
   this round's own prior fix, or a previous round's E12 push --
   confirm the commit addresses it, applying the same file-path-touch
   check as
   `idd-review-snapshot-lite.instructions.md`'s Cold-start edge case 1.
   Do not duplicate the fix; let E13 cite that SHA.
8. Do not push yet. All of this round's fixes push together at E12.

## E10 — Validate fixes with critique pass

Per-agent pass: resolve `critiqueLoop.subagentWaitCeiling` (`PT20M` default)
with harness timeout, not wrapper (#3449). Applies only to per-agent
subagents; shell-delegate rules unchanged. Background waits require cleanup;
suppress late output. `mode` only decides whether per-agent starts from
delegate. Started timeout/cancel/interruption/error passes without findings use
self-critique and record no return in every mode. Unbounded: skip delegation;
self-critique and record risk.

1. Resolve `critiqueLoop.delegate` the same way
   `idd-work-lite.instructions.md` C1 does: helper-first
   `critique-delegate` (`node scripts/idd-critique-delegate.mjs` or
   `idd:critique-delegate`). `usable: false` → per-agent only; only
   `usable: true` uses `command`/`mode`. Then run delegate and/or
   per-agent per `mode` (`fallback` default, `combined`, `on-success`,
   `never`) and union when both ran. Never assume they stack. Stop
   and ask if that helper is missing, fails, or disagrees.
   `critiqueLoop.telemetryHook` remains C1-only and is never consulted
   here. That resolve-and-run is the critique pass verifying E9
   fixes; not a second pass. Apply these lenses only within a
   per-agent pass, composing when both fit: **Mutation / write-side**
   (the diff implements a helper that mutates GitHub state, mutates git
   state, or performs a merge) — Fail-closed inputs; Validate/execute
   scope parity; Unsafe-output suppression; Schema strictness parity.
   **Gate-mirroring** (the diff implements a helper that predicts,
   mirrors, or pre-checks another gate's decision) — Validation-path
   parity; Input completeness; Whole-identity comparison; Snapshot
   identity; Point-in-time parity.
2. If no mechanism produced a readable findings list — a
   `critiqueLoop.delegate` `mode` of `on-success` or `never` whose
   delegate failed without emitting one — post a hold comment and
   stop; do not treat it as zero issues and do not continue to E11. A
   successful empty list, or a failed delegate that still emitted a
   readable list, is a genuine result.
3. If the critique pass reports zero issues, continue to E11.
4. If it reports additional issues, fix them, commit atomically, and
   run E10 again.
5. Count "meaningful progress" as removing at least one Accepted
   finding, narrowing a remaining finding's root cause or scope, or
   producing a materially new fix direction. A reworded duplicate
   finding does not count.
6. If the same Accepted findings recur for
   `critiqueLoop.e10NoProgressHoldAfter` (default 3) consecutive E10
   passes without meaningful progress, stop the loop, post a hold
   comment summarizing the repeated findings and attempted fixes, and
   wait for a maintainer decision.
7. Do not use step 6 to bypass a serious issue: unresolved High or
   Medium findings stay blockers until fixed or explicitly redirected
   by a maintainer.
8. **No confidence exception.** A fix's scope, or your own
   confidence in it, never excuses skipping this pass — E10 must run
   for every E9 fix batch before E11. Pushed a skipped round?
   Disclose it, name the round(s), run E10 against the accumulated
   diff to a clean pass, then return to E1 before F1 — see
   `idd-review-fix.instructions.md`'s E10 repair path for the full
   procedure.
9. Heuristic: several new, non-repeated same-area findings across
   rounds (3-4) may mean one structural fix converges faster than
   another patch. If that fix keeps drawing new findings, prefer
   simplifying/removing the mechanism over a second redesign -- only
   once confirmed non-required by the issue's acceptance criteria or
   contract; if required, stop for a maintainer decision.
10. Third tier: when each new finding is instead a genuine, distinct gap
    against an open-ended external correctness domain (a grammar,
    protocol, or wire format) rather than a symptom of one mechanism,
    tiers 1-2 do not apply -- there is no mechanism to simplify, since
    coverage of that domain is itself the acceptance criterion. Once
    several rounds each surface a genuinely new in-scope gap rather than
    repeating one, list every outstanding gap with evidence and the
    round count in a hold comment and stop for a maintainer decision
    (`#2865`).

## E11 — Resolve conflicts with main

1. Check state with the profile-selected branch-conflict-state helper:
   `node scripts/branch-conflict-state.mjs --pr {pr-number}`, or the
   package-manager-profile `idd:branch-conflict-state` command
   (resolve the exact command from `docs/idd-helper-scripts.md` if
   unsure) — reflects the last pushed head, not local unpushed fixes.
   Missing, failing, or disagreeing? Stop and ask (Helper runtime
   contract above) — no non-helper fallback here.
2. Not a confirmed conflict (clean, behind-no-conflict, computing,
   dirty, force-push-exception, unknown)? Skip the merge, continue to
   E12 — F1 (`idd-pre-merge-lite.instructions.md`) handles those
   downstream.
3. Conflict (`mergeable` `CONFLICTING`)? Unresolved review threads,
   unreplied comments, or reviewer state `CHANGES_REQUESTED`: get
   explicit operator confirmation first — the merge commit will appear
   in the PR history.
4. Run `git fetch origin main && git merge origin/main`. On
   non-interactive-hostile primary signing (GPG pinentry or
   hardware-touch) with a fallback wrapper, run the whole merge
   (including `--continue`) through that wrapper instead — see
   `docs/idd-helper-scripts.md#signed-commit-merge-wrapper-shared-git-procedure`
   for the command form and the commitlint `-m` requirement.
5. Resolve conflicts, complete the merge.

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
   regardless of PATH A/B. A configured `secondaryBotLogin` login
   still qualifies as bot-sourced.
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
9. This never delays/holds/interrupts an in-flight CI wait, or changes
   PATH A/B routing/triage timing — only push timing changes. A
   folded-in comment gets **no** disposition reply this round; it
   keeps its PATH classification and individual E6 reply for
   E1/E4-E7. E14 still requests a fresh primary-bot re-review each
   push; `review-watermark` still invalidates too.
10. Apply the pre-mutation guard immediately before this push.
11. Re-apply the pre-mutation guard immediately before this edit —
    it is a separate mutation after the already-guarded push. If this
    round's fix changes a claim the PR body makes (round count, a
    residual limitation, a scope statement — wherever it appears),
    fetch the current full body, edit only that claim in the fetched
    copy, and post the full result back:

    ```sh
    gh pr edit {pr-number} --body-file <path>
    ```

    `--body-file` replaces the whole body, so never pass a partial
    file (it would drop the closing-keyword line). After posting,
    repeat the lite pr-submit doc's step 5 closing-set check — edited
    prose can introduce a stray keyword-adjacent reference.

## E13 — Reply to feedback

1. For each Accepted PATH A item whose source is reviewer feedback
   (review thread, review body, or regular comment), reply describing
   which commits fixed it and how.
2. Start every reply with:
   `**Accepted** — fixed in {commit-sha or comma-separated list}: {brief explanation}`,
   followed by the reply-identity stamp
   `<!-- {markerPrefix}-review-reply -->`
   (`idd-review-triage.instructions.md` E6). Citing a commit that did
   not fix this item in the current round requires it to have already
   passed the file-path-touch check (E9 item 7, or
   `idd-review-snapshot-lite.instructions.md`'s Cold-start edge case 1).
3. For a review thread, post the reply and resolve it in one call with
   the profile-selected `resolve-review-thread` helper (`--pr`,
   `--comment-id`, `--body`, `--claim-issue`, `--claim-id`, `--apply`;
   package-manager / ephemeral-npx equivalent in
   `docs/idd-helper-scripts.md`), which appends the stamp and replies
   before resolving, so a failed reply never leaves a silently-resolved
   thread.
4. For a regular comment, reply only and append the stamp yourself; do
   not resolve. Any reply posted another way (the manual fallback)
   must append the stamp itself too.
5. If a non-review notice (rate-limit / usage-limit / review-limit) was
   already dispositioned `**Rejected** — {bot} did not review HEAD …` in
   a prior pass, carry that rejection forward. Do not re-post an
   identical rejection just because the notice's timestamp bumped or the
   bot re-posted the same summary. Only disposition it again if the bot
   replaced the notice with an actual completed review of the current
   HEAD.
6. After all replies and resolutions complete, update the PR live
   status digest if the next route is still review-fix or CI wait:
   `Phase` to `E13 feedback replied`, `Open blockers` to any
   remaining reviewer, advisory, or CI wait, `Next action` to E14 or
   E15, and `Authoritative by` to the replies, resolved threads,
   current HEAD, and verified claim.

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
   --claim-id {claim-id} --agent-id {agent-id}
   --trusted-marker-logins "<trusted-login-1>,<trusted-login-2>"` in
   the source/vendored profile; resolve the package-manager /
   ephemeral-npx equivalent from `docs/idd-helper-scripts.md`). If it
   fails, returns invalid JSON, or is missing any field from
   `idd-advisory-wait-lite.instructions.md`'s own Required fields list,
   stop and ask — do not fall back to a manual per-field fetch.
4. Read the helper's `outcome` field and apply this decision table, top
   to bottom, first match wins:
   - Off-head `SATISFIED` with `staleRequestRecovery.action ==
     "attempt"` → hand off for AW3-S; never E15.
   - Off-head `SATISFIED` with recovery `cap-exhausted` → follow
     `capExhaustedRoute`: `phase-specific` → E15; `hold` → stop/ask.
   - `SATISFIED`, `copilotPending` `false`,
     `copilotPendingCoversHead` `false` (elapsed-only, `#2327`) → apply
     step 10, then E15.
   - `SATISFIED` (otherwise) → apply step 10 first, then continue to
     E15.
   - `RECOVERY_NEEDED`: post the recovery marker
     `advisory-wait-recovery: {agent-id} {PR_HEAD_SHA}
     {ISO8601-recovery-time}` as plain text. Do not request another
     review. Then go to the polling loop below.
   - `REQUEST_NEEDED`, `copilotPending` `false`: try add-reviewer and
     REST. Post
     `advisory-wait: {agent-id} {PR_HEAD_SHA} {ISO8601-requested-at}`
     as plain text only after current-attempt evidence: a newer event
     after HEAD or a fresh node absent from the pre-request snapshot;
     exit status is not evidence (issue `#3500`). If absent, see
     [AW3-S fallback](../../../docs/idd-advisory-wait-shell-fallback.md#registration-proven-review-request);
     use its account-typed fallback; never hard-code ids. Still absent:
     stop and ask; poll only after success. Status `3` means claim/HEAD
     guard failure: stop and return to E1. Status `1`/`2` means primary
     registration is unproven/unreadable: stop/ask, not poll.
   - `REQUEST_NEEDED`, `copilotPending` `true` (a request is already
     pending but unproven for current HEAD, no same-head marker to
     anchor polling): lite does not track the claim-id/agent-id the
     full protocol's bounded `AW3-S` remove/re-request cycle requires —
     stop and ask rather than remove, re-request, or enter the
     marker-based polling loop below with no marker.
   - `CAP_EXHAUSTED`: apply step 10 first — it is a non-gating
     supplement that fires on cap exhaustion independent of the
     cap-exhausted route. Then, if the helper's `capExhaustedRoute` is
     `hold`, post a hold comment and stop; otherwise (`phase-specific`,
     the default) continue to E15.
   - `WAIT`: go to (or stay in) the polling loop below.
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
   highest `updatedAt` as a temporary polling watermark. If a deferred
   baseline exists and this is newer, return to E1; otherwise use the fresh
   maximum as the watermark. Never post it. For an empty snapshot, use the
   latest trusted same-claim watermark `createdAt`, then the deferred E1
   baseline, then the same-claim `review-baseline` `createdAt`; never use
   a marker-shaped comment as that baseline. If none exists, return E1.
8. Poll on the interval from the helper's `pollIntervalMinutes`. Each
   cycle: re-fetch the current head; if it differs from `PR_HEAD_SHA`,
   stop polling and return to `idd-review-snapshot-lite.instructions.md`
   (E1). Otherwise re-read threads, review bodies, and regular comments
   (excluding trusted operational markers); if anything has `updatedAt`
   newer than the polling watermark, stop polling and return to E1.
   Otherwise re-run the step-3 helper. If it fails, returns invalid
   JSON, or is missing required fields, stop and ask — do not fall back
   to a manual per-field fetch. If `earliestSameHeadAt` is now empty,
   post a hold comment noting the advisory-wait marker for
   `PR_HEAD_SHA` disappeared during polling and stop. Before a terminal
   result, reapply step 4's first-match table: off-head `SATISFIED` with
   `attempt` hands off for AW3-S; `cap-exhausted` follows
   `capExhaustedRoute`. Only then may `SATISFIED` apply step 10 and go E15.
9. Otherwise keep polling — the helper already folds
   `pendingWindowMinutes`/`settledWindowMinutes` into `outcome` on
   every call, so a stalled or silent advisory bot still ends the loop
   as `SATISFIED` without a hand-derived check.
10. **Optional secondary advisory bot(s) (non-gating).** Use the most
    recent step-3/step-8 helper output's `secondaryRequestNeeded` and
    `secondaryRequestLogins` fields directly — do not re-derive the
    request/already-requested condition manually.
    `secondaryBotLogin` accepts one login or a list. When
    `secondaryRequestNeeded` is `true`, request **every** login in
    `secondaryRequestLogins` once each (never only the first), using
    the guarded procedure, replacing primary placeholders and
    `BOT_REST_LOGIN`/bare form; type selects `botIds`/`userIds`;
    `1`/`2` skip and `3` stops. No marker.
    Each review is ordinary advisory input, picked up by the next E1
    snapshot if it lands before merge. Skip this step entirely when
    `secondaryRequestNeeded` is `false`.
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
3. If new review threads/comments arrive, return to E1 immediately;
   otherwise continue waiting for CI.
4. On success: return to `idd-review-snapshot-lite.instructions.md`
   (E1) — do not skip triage.
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
