# IDD — Review Fix Phase (E9–E15)

Read this file after `idd-review-triage.instructions.md` (E8) finds
Accepted PATH A items. Covers implementing fixes, validating, pushing,
replying to reviewers, and waiting for CI — including E14's GitHub
Copilot advisory-review step, which follows even when another local
agent drives the workflow, since it depends on GitHub review state, not
the local CLI. E14's timing defaults are named in
[IDD policy constants](../../docs/policy-constants.md); refer there for
values, but keep the phase logic here unchanged.

Apply the
[shared claim revalidation gate](idd-overview-core.instructions.md#claim-revalidation-gate)
before E9, the E12 push, and each E13/E14/E15 GitHub side effect
(reply, resolve, reviewer request, hold comment, or digest update).

## E9 — Fix accepted issues

Fix all Accepted PATH A items from ReviewItems_snapshot. Run
**fix-validate**. Commit fixes atomically — one logical change per
commit.

**Within-round batching.** All of this round's Accepted PATH A fixes
travel as their own atomic commits, but push together in a single push
at E12 — do not push after each individual fix. See E12 for the push
step and the bounded cross-round allowance for comments arriving before
that push.

These fix-side rules complement the accept-side "Verify before accept"
rule in `idd-review-triage.instructions.md` (E5); each cuts the
advisory-review round count:

- **Fix the whole class, not just the flagged line.** Sweep the current
  diff (and adjacent sections) and fix every instance of a systemic
  finding in one commit — this converges faster than waiting for each
  instance to be re-flagged.
- **Verify any claim a fix adds.** Check any new precision (a name,
  value, path, or described behavior) against the actual implementation
  before committing.
- **Already fixed via batching.** A PATH A item Accepted (E4/E5) may
  already be folded into a prior E12 push — confirm the commit
  addresses it and let E13 cite that SHA, without duplicating the fix.

## E10 — Validate fixes with critique pass

Run a critique pass to verify that the fixes in E9 address the root
causes and are correct (see `idd-overview-appendix.instructions.md` for per-agent
implementation). The distributed defaults for the E10 guardrails are
listed in `docs/policy-constants.md`. Keep an E10 pass count for the
current E9 fix batch.

If the critique pass finds additional issues, fix them, commit
atomically, and run E10 again while the findings are converging.

Convergence guardrails:

- "Meaningful progress" means a pass removes at least one Accepted
  finding, narrows a remaining finding's root cause/scope, or yields a
  materially new fix direction. Reworded duplicates do not count.
- If the same Accepted findings recur for
  `critiqueLoop.e10NoProgressHoldAfter` consecutive E10 passes (default
  `3`) without progress, stop the auto-loop: post a hold comment
  summarizing the repeated findings and attempted fixes, and wait for a
  maintainer decision.
- Do not use this stop condition to bypass serious issues: unresolved
  High/Medium findings remain blockers until fixed or explicitly
  redirected by a maintainer.
- If the critique pass reports zero issues, proceed to E11.

## E11 — Resolve conflicts with main

Check for conflicts between the feature branch and `main`. If conflicts
exist, merge `main` into the feature branch (`git fetch origin main &&
git merge origin/main`), resolve them, and complete the merge. On a
signed-commit repo with non-interactive-hostile primary signing (GPG
pinentry / hardware-touch), use the
[signed-commit merge wrapper](../../docs/idd-helper-scripts.md#signed-commit-merge-wrapper-shared-git-procedure)
for the whole operation instead of the plain command.

**Active review gate**: same check as
`idd-review-triage.instructions.md`'s sync path step 1 — unresolved
review threads, unreplied comments, or a reviewer's
`CHANGES_REQUESTED` state require explicit operator confirmation before
this merge, since the merge commit will appear in PR history.

## E12 — Lint, test, push

Run **post-fix-validate**.

Then push the feature branch normally (E11 uses merge commits, not
rebase, so no force push is required).

**Bounded cross-round batching allowance.** A small number of review
comments can arrive before this push that fall outside this round's
scope and haven't gone through triage yet. Fold them into this same
pending push — each its own atomic commit — instead of starting a
fresh round per arrival, but only when **all** hold:

- Every comment since the last push is **bot-sourced**: the primary
  advisory bot's login (default Copilot: `copilot` /
  `copilot-pull-request-reviewer*`, matched via `isCopilotReviewerLogin`
  in `scripts/protocol-helpers.mjs`) or an `advisoryBotLogins` login,
  **regardless of PATH A/B** (Copilot's inline thread comments fall
  through to PATH A under E4's ambiguous-default rule; a
  `secondaryBotLogin` overlap still qualifies).
- Each comment is a small, confirmable fix whose claim was checked
  against live evidence (linter run, actual file/runtime behavior)
  before folding it in — the same **verify-before-accept discipline** E5
  codifies for PATH B (#814), applied to bot-sourced PATH A. Never fold
  in a bot-asserted-only finding.
- The resulting commit touches only files this round's pending fixes
  already touch, and re-runs **post-fix-validate** first (E12's own run
  already happened and misses a later fold-in).
- No CI-wait poll (E15) is currently in flight for this branch.

**Bound**: at most 3 additional commits, or 10 minutes since the first
accumulated commit — whichever comes first.

**Ends accumulation immediately** (push whatever has accumulated): a
PATH A item from a **human or CODEOWNER** arrives (bot-sourced alone
does not); any item requests a substantive code/logic change; any item
falls outside the touched-file scope; or either bound is reached.

**Non-goals**: never delays an in-flight CI wait (E15's mid-wait
fold-in rule is unchanged); never changes PATH A/B routing or triage
timing (still happens at the next E1 pass — only push timing changes);
and relaxes nothing else — E14 still re-reviews every push, the
per-HEAD `review-watermark` still invalidates on push, each E6 reply
stays individual, and the
[claim revalidation gate](idd-overview-core.instructions.md#claim-revalidation-gate)
still runs immediately before push.

## E13 — Reply to feedback

For each Accepted PATH A item whose source is reviewer feedback (review
thread, review body, or regular comment): reply describing which commits
fixed it and how.

Start every reply with one of these prefixes so that disposition is
unambiguous:

- `**Accepted** — fixed in {commit-sha or comma-separated list}: {brief explanation}`

- **Review threads**: after posting your reply, **immediately resolve
  the thread**. When helper runtime is enabled, the profile-selected
  resolve-review-thread command (`--pr <number> --comment-id <id>
  --apply`, with `--body`/`--claim-issue`/`--claim-id`; see
  `docs/idd-helper-scripts.md`) posts the reply and resolves in one
  call, replying before resolving so a failed reply never leaves a
  silently-resolved thread; the manual REST + GraphQL
  `resolveReviewThread` sequence is the fallback. Resolution means
  "agent acted", not "reviewer agreed" — a disagreeing reviewer can
  reopen the thread, re-surfacing it in the next E1 pass.
- **Regular comments**: reply only; do not resolve.
- **Persistent non-review notices**: a non-review notice already
  dispositioned `**Rejected** — {bot} did not review HEAD …` in a prior
  pass **carries that rejection forward** across this push — do not
  re-post it just because `updatedAt` bumped or the bot re-posted the
  same summary (see the E6 non-review-notice rule). Only a notice the
  bot replaces with an actual completed review needs a fresh
  disposition.

After E13 replies and resolutions are complete, upsert the PR live
status digest before E14 if the next route is still review-fix or CI
wait: `Phase` to `E13 feedback replied`, `Open blockers` to any
remaining reviewer/advisory/CI wait, `Next action` to E14 or E15, and
`Authoritative by` to the accepted replies, resolved threads, current
HEAD, and verified claim. Since E15 returns to E1 after CI, this edit
is safe and does not bypass the next E1 snapshot.

## E14 — Re-review request

**Human reviewers**: request a re-review from each reviewer whose
latest state is `CHANGES_REQUESTED` once their items are all addressed:

```sh
gh pr edit {pr-number} --add-reviewer {reviewer-login}
```

For an **advisory bot**, try the add-reviewer command with the bot's
**login** first — on some `gh` versions the GraphQL mutation fails a
bot login outright (`Could not resolve user with login '{login}'
(requestReviewsByLogin)`); on failure, fall back to REST
`requested_reviewers` with the bot's real account login (REST also
silently no-ops on a **display name**). See **Primary advisory bot**
below for the exact login each path needs.

**Primary advisory bot** (default Copilot; also invoked directly by
`idd-review-triage.instructions.md`'s **Zero-Accepted-PATH-A advisory
re-review gate**, reusing steps 1-4 and the polling loop below with its
own on-success target instead of E15): after every push, regardless of
reviewer state, request a re-review from the configured primary
advisory bot (`advisoryWait.primaryBotLogin`, default Copilot) if it
hasn't reviewed current HEAD SHA — subject to the re-review request
cap (`REQUEST_CAP` / `advisoryWait.requestCap`, default 30; a process
limit, not GitHub-enforced).

Substitute `{primary-advisory-bot}` below with that bare login (default
`copilot` → `@copilot`); the AW helpers keep `COPILOT_PENDING`/
`LAST_COPILOT_COMMIT` field names regardless of the configured bot. The
REST fallback needs `{primary-advisory-bot-rest-login}`:
`copilot-pull-request-reviewer[bot]` for the default, or
`{primary-advisory-bot}` itself for a non-default bot (already a real
login).

1. Fetch `PR_HEAD_SHA`:

   ```sh
   PR_HEAD_SHA=$(gh pr view {pr-number} --json headRefOid --jq '.headRefOid')
   ```

2. Run **AW1** (`idd-advisory-wait.instructions.md`). **SATISFIED** →
   E14 advisory-bot processing is done; proceed to E15.
3. Run **AW2** to fetch markers.
4. Apply the **AW3** decision table:
   - **SATISFIED** → proceed to E15.
   - **HOLD** → post the hold comment from **AW4** and stop.
   - **RECOVERY_NEEDED** (`COPILOT_PENDING` `"true"`, no same-head
     marker): post the recovery marker from **AW3-R**; do not
     re-request.
   - **CAP_EXHAUSTED** (`REQUEST_MARKER_COUNT` ≥ `REQUEST_CAP`, no
     same-head marker): if `CAP_EXHAUSTED_ROUTE` is `hold`, post the
     hold from **AW4** and stop; otherwise (`phase-specific`, default)
     skip the wait and proceed to E15.
   - **REQUEST_NEEDED**, `COPILOT_PENDING` `"false"` (cap not
     exhausted): request the bot's review and immediately post:

     ```sh
     gh pr edit {pr-number} --add-reviewer "@{primary-advisory-bot}"
     # on GraphQL login-resolution failure:
     gh api repos/{owner}/{repo}/pulls/{pr-number}/requested_reviewers \
       -X POST -f "reviewers[]={primary-advisory-bot-rest-login}"
     ```

     ```text
     advisory-wait: {agent-id} {head-SHA} {ISO8601-requested-at}
     ```

     Use `PR_HEAD_SHA` as `{head-SHA}`; post as plain text, not HTML.
   - **REQUEST_NEEDED**, `COPILOT_PENDING` `"true"` (unproven coverage —
     PR #1562): consult **`AW3-S`**'s `staleRequestRecovery` first —
     `"attempt"` runs its bounded remove/re-request/verify/mark cycle
     (independently capped, never the plain marker or `REQUEST_CAP`);
     `"cap-exhausted"` handles like **CAP_EXHAUSTED** above (no
     remove/re-request); `"not-applicable"` falls through to the
     polling loop unchanged (a same-head marker already anchors HEAD).
   - **WAIT**, or after a **REQUEST_NEEDED** / **RECOVERY_NEEDED** /
     **AW3-S** marker posts: enter the active polling loop below.
5. **Secondary advisory bot (optional, non-gating).** Request it once
   per HEAD when the helper reports `secondaryRequestNeeded: true` (or,
   in the shell fallback, AW3 yields **CAP_EXHAUSTED** or a
   stalled/rate-limited **SATISFIED**) and `advisoryWait.secondaryBotLogin`
   is configured and not yet requested for this HEAD — same
   gh-then-REST fallback as the primary, no `advisory-wait:` marker, and
   no change to the AW3 route. Its review is ordinary advisory input,
   returned by the E1 snapshot if it lands before merge; skipped when
   unconfigured.

Copilot and CI advisory bot comments are advisory; unanswered ones do
not block merge.

Whenever E14 posts a request/recovery marker or hold comment, update
the digest: the marker/hold as `Authoritative by`, the advisory
wait/hold reason as `Open blockers`, and polling/E15/maintainer action
as `Next action`.

**Active polling loop** (when `COPILOT_PENDING` is `"true"`, or right
after posting a **REQUEST_NEEDED**/**RECOVERY_NEEDED** marker above):

Do not post a new marker if a same-head one already exists — reuse the
**earliest** `createdAt` among same-head markers (the clock starts at
the first request, not the last).

Take a fresh activity snapshot (E1 Step 1's scope, excluding only
trusted operational markers) and record its highest `updatedAt` as the
**temporary polling watermark** — never post it as a `review-watermark`
comment. If empty, use the latest trusted same-claim `review-watermark`
comment's `createdAt` instead, or stop and return to E1 if none exists.

Poll every `POLL_INTERVAL_MINUTES` minutes:

1. Re-fetch `PR_HEAD_SHA`

   ```sh
   CURRENT_HEAD=$(gh pr view {pr-number} --json headRefOid --jq '.headRefOid')
   ```

   — if it changed, return to E1.
2. Re-read threads/bodies/comments (excluding trusted operational
   markers only — untrusted marker-shaped comments remain activity). Any
   `updatedAt` newer than the polling watermark → return to E1
   immediately.
3. Run **AW1**/**AW2** (refresh `COPILOT_PENDING`, `LAST_COPILOT_COMMIT`,
   `EARLIEST_SAME_HEAD_AT`; apply **AW5** if the latter is empty), then
   **AW3**: **SATISFIED** → exit, proceed to E15; **HOLD** → post
   **AW4**/**AW5** hold and stop; **WAIT** → keep polling.

Note: "advisory" means the agent need not accept every suggestion — not
that it may skip a review it explicitly requested. Human
`CHANGES_REQUESTED` reviewers are not advisory; they stay under the
hold/escalation path above.

## E15 — Wait for CI

Schedule a wake, or background this wait only if the
topology-safety condition holds (confirmed to route completion back to
this turn); otherwise wait synchronously — see
[wake-up discipline](idd-ci.instructions.md#wake-up-discipline).

Use `idd-ci.instructions.md` for the polling mechanics and timing. E15
reuses the same resolved `ciWait.runningTimeout`,
`ciWait.generationTimeout`, and `ciWait.rerunPolicy` values; omitted
keys preserve the distributed defaults. The outcome paths below are
authoritative and override the shared helper's generic outcomes for this
phase:

**While polling**: if new review threads or comments arrive during the
CI wait, note them. After CI resolves (any outcome), return to E1 before
proceeding to F — do not skip triage.

- **On success** → return to `idd-review-snapshot.instructions.md` (E1)
- **On failure / code-caused**: fix, run **fix-validate**, commit
  atomically, then return to E11
- **On failure / infra-flaky or pre-existing** (failure also present on
  `main`, unrelated to this branch): apply `ciWait.rerunPolicy` (default
  `rerun-once`) — rerun once and resume polling if it authorizes the
  current rerun; otherwise, or if the failure persists after that
  rerun, post a hold comment documenting it and stop. A maintainer must
  resolve or bypass the failing check; never auto-continue or treat as
  passed without human confirmation. Phrase the resume condition per
  the invariant-first guidance in `idd-overview-appendix.instructions.md`
  (Hold / suspend).
- **On cancelled / timed_out / code-caused**: fix, run **fix-validate**,
  commit, return to E11
- **On cancelled / timed_out / infra**: apply `ciWait.rerunPolicy` —
  re-push/rerun only when it authorizes the current rerun; if the route
  recurs after that rerun, or the policy is `hold`, post a hold comment
  and stop (do not loop). On success after the rerun, **return to E1**.
- **On failure / `idd-advisory-convergence` alone, `pending: false` with
  outstanding review reasons** (see `idd-ci.instructions.md`
  §Interpretation): return to E1, not E11 — neither code-caused nor
  infra. **Unless** a maintainer has since posted a valid external-check
  waiver for this HEAD, in which case apply `ciWait.rerunPolicy` instead
  — the rerun is what makes the check reflect the waiver (see D4's
  identical carve-out and `idd-pre-merge.instructions.md`'s External-check
  waivers).

When E15 stops on a CI hold, re-validate the claim, then update the
digest with `Phase: E15 hold`, the failing/missing checks in
`Open blockers`, and the maintainer/rerun expectation in `Next action`.
On CI success, do not edit the digest before returning to E1 — let the
next E1/F pass refresh review currency first.
