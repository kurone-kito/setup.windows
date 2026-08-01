# IDD — Review Triage Phase (E4–E8)

Read this file after `idd-review-snapshot.instructions.md` (E3) finds
ReviewItems_snapshot non-empty. Covers classifying, scoring, recording
dispositions, and counting accepted items.

Before posting any E-phase operational comment or GitHub reply, apply
the shared claim revalidation gate. The active claim must still use your
current `{claim-id}`.

**Skip condition E8**: if the Accepted PATH A count after verification
is zero, proceed to the **E-phase branch-sync check** below (its
no-sync-required `clean`/`behind-no-conflict` exit applies the
**Zero-Accepted-PATH-A advisory re-review gate**).

## E4 — Classify and score ReviewItems_snapshot

For each item in ReviewItems_snapshot, first classify it:

- **PATH A — actionable feedback**: human reviewer threads and regular
  comments, `CHANGES_REQUESTED` review bodies, and critique-pass
  findings that require a code change or maintainer decision.
- **PATH B — advisory feedback**: Copilot and CI advisory bot comments
  included by E1 for traceability, even when they do not require a code
  change.
- If classification is ambiguous, default to PATH A.

**Advisory non-review notice.** Before scoring a PATH B item, decide
whether it is a _completed_ advisory review of the current HEAD or an
**advisory non-review notice** — an advisory bot comment reporting that
it did **not** review the current HEAD: rate-limit / quota /
credit-exhaustion warnings, queued / in-progress status, a bare request
acknowledgement (e.g. CodeRabbit "Actions performed"), or an error /
"temporarily unavailable" notice. A non-review notice carries no
advisory result to score; handle it with the E6 non-review-notice rule
instead of the normal PATH B disposition.

Then apply path-specific scoring:

- **PATH A**: assess severity/relevance to PR intent. **High** (safety,
  correctness, requirement violations, CI stability) → **Accept
  forced**; **Low** (minor, unrelated to PR intent) → **Reject
  recommended**; **Medium** → judge by context.
- **PATH B**: no High/Medium/Low. Score only a _completed_ review of
  current HEAD as `Accepted` (confirmed/useful) or `Rejected`
  (noted, no action) — route a non-review notice to E6 instead.

## E5 — Record Accept / Reject decisions

Record a path-specific disposition for every item:

- **PATH A**: High-severity items are Accepted automatically;
  Medium/Low require an explicit Accept or Reject decision.
- **PATH B** (a _completed_ review of the current HEAD): `Accepted`
  means the advisory confirms the implementation or captures useful
  context; `Rejected` means noted, no action required. An advisory
  non-review notice (E4) is **not scored** here — record it, but always
  as `Rejected` per the E6 non-review-notice rule.

Accepted PATH B items do **not** enter review-fix. They are fully
handled in E6-E7.

**Resolved-thread duplicate pre-check (PATH B, before verification).**
Before verification below, check whether a new PATH B item — a review
thread or a regular comment (E6 supports both PATH B sources) — matches
an entry in this PR's resolved-thread index
(`idd-review-snapshot.instructions.md` E1 Step 3). Matching is scoped to
**this PR's** resolved threads only: a regular comment has no resolved
state of its own, but can still match a prior resolved thread's claim.

- Match the new item against the index by file area and substantive
  claim, requiring the identical claim rather than merely a related
  topic in the same file. (For example, a prior "raw SQL concatenation"
  rejection on `db/query.mts` does not match a new "missing index"
  comment on the same file: same file area, different claim.)
- On a match, open the linked prior thread — the index disposition alone
  is not proof. Re-confirm the new item raises that **same underlying
  claim**, not just a related one, then confirm the prior thread
  actually recorded a **reasoned rejection with citable evidence** (not
  a bare `**Rejected**`, and not the E6 non-review-notice rejection,
  which asserts no result was reviewed rather than rejecting a claim),
  then quickly recheck that the cited evidence still holds at the
  current HEAD — the diff moves between rounds, so a prior file/line
  citation can be stale.
- **Shortcut.** If the prior disposition was a reasoned rejection with
  evidence and that evidence still holds: reply to the new item with a
  fresh, individually-authored disposition citing the prior thread's URL
  and its evidence, then apply the existing E6 PATH B reply rules for
  that item's source — resolve immediately after replying for a review
  thread; reply only for a regular comment. Every recurrence still gets
  its own reply, so the 1:1 disposition-count / no-combined-replies rule
  (E6) is unchanged — only the reply's content is shortcut.
- **Fall through** unchanged to "Verify before accept (PATH B)" below
  when there is no match, re-confirmation shows the new item is not
  actually the same underlying claim, the matched disposition is not a
  reasoned rejection with evidence, the cited evidence no longer holds
  at current HEAD, or the new occurrence carries genuinely new
  information the prior thread did not address.

**Worked example.** A bot re-raises "this workflow step needs
`contents: write`" two rounds after an identical claim on the same file
was rejected with evidence (the step only uploads an artifact). Confirm
the claim and evidence still hold at current HEAD, reply `**Rejected**
— same claim as {prior thread URL}: verified false there; unchanged at
current HEAD.`, then resolve the thread.

**Verify before accept (PATH B).** A PATH B advisory often asserts a fact
about the runtime, CI, or an artifact. Before `Accept`ing it, verify the
claim against the live runtime / artifact / CI run, not the comment text
alone: confirmed → `Accept` and act; **false on the live evidence** →
disposition it `Rejected` and cite the contradicting evidence (the real
run conclusion, file contents, or artifact) — a verified-false advisory
is a reasoned rejection, not an action item.

**Reasoned-rejection convergence.** The iterate-to-zero loop may converge
by reasoned rejection of peripheral or verified-false items — not every
comment needs a code change. Record the reason in the disposition reply;
"a bot raised it" alone never forces a change.

**Worked example.** A bot flags a "credential leak" on a config-only file
that in fact holds only public placeholders. Reply `**Rejected** —
verified: the flagged file contains only public placeholders; no
credential is present.`

## E6 — Post disposition replies

Apply the reply rules below after E5 records a disposition.

PATH A — Accepted items:

- Do not reply in triage solely to acknowledge the acceptance. Accepted
  reviewer feedback is replied to after the fix work in
  `idd-review-fix.instructions.md`.

PATH A — Rejected reviewer feedback:

For each Rejected PATH A item whose source is reviewer feedback:

- Reply using the format: `**Rejected** — {reason}`
- **Exception**: if the source is a CODEOWNER or required reviewer, do
  not reject unilaterally. Reply using the format:
  `**Awaiting maintainer decision** — {your reasoning}` and wait for the
  maintainer's response.
- After posting your reply, **immediately resolve the thread** — except
  for `**Awaiting maintainer decision**`. When helper runtime is enabled,
  the profile-selected resolve-review-thread command (`--pr <number>
  --comment-id <id> --apply`, with `--body`/`--claim-issue`/`--claim-id`;
  see `docs/idd-helper-scripts.md`) posts the reply and resolves in one
  call, replying before resolving so a failed reply never leaves a
  silently-resolved thread; the manual REST + GraphQL
  `resolveReviewThread` sequence is the fallback. Resolving means "agent
  acted", not "reviewer agreed" — a disagreeing reviewer can reopen the
  thread, which re-surfaces it in a future E1 pass.
- **Exception to immediate resolution**: for a review-thread AMD, leave
  it unresolved (do **NOT** resolve) so F2's "Unresolved threads = 0"
  gate blocks merge until the maintainer responds, and post a separate
  hold comment explaining what you're waiting for. A regular-comment AMD
  (CODEOWNER/required-reviewer feedback with no thread) cannot use that
  gate structurally — instead post the hold comment stating you will
  **not** merge until the decision appears, and stop. Either way, wait
  for the response in a future E1 pass: agreement closes the AMD (reply
  to confirm, remove the hold); an override moves it to Accepted.
- **When an `Awaiting maintainer decision` thread re-appears in ReviewItems_snapshot**:
  scan the activity universe for a **qualifying response** — a reply on
  this thread, or a separate comment/review that clearly references
  this item — from a **qualifying person** (any CODEOWNER, required
  reviewer, or a collaborator with Write/Maintain/Admin access per
  `GET /repos/{owner}/{repo}/collaborators/{username}/permission`),
  excluding the acting agent and the PR author, posted **after** your
  AMD comment. A general comment/review from a qualifying person that
  does not reference this item does not count.

  If a qualifying response exists, apply the transitions below.
  Otherwise, ensure a hold comment exists (post one if not), then
  stop — do not re-reply or resolve; resume when the response appears
  in a future E1 pass.
- **When the maintainer eventually responds** (their response surfaces
  in a future E1 pass as an unresolved thread or new reply):
  - If the maintainer **agrees with your rejection**: reply summarizing
    the agreed decision (e.g.,
    `**Rejection confirmed by maintainer** — {summary}`) and resolve the
    thread.
  - If the maintainer **disagrees**: move the item from Rejected to
    Accepted and proceed through the fix flow. Resolve the thread after
    fixing.
  - If the maintainer's response arrived in a separate PR comment or
    review rather than in the original thread: mirror the decision onto
    the original thread and resolve the thread. Also **reply to the
    maintainer's separate comment** (e.g., "Decision mirrored to the
    review thread — {link}") so that F2's unreplied-comments gate does
    not block merge on that comment.
- For a `CHANGES_REQUESTED` review body you are rejecting: post a PR
  comment explaining your reasoning and ask the reviewer to reconsider.
  - If the reviewer does not respond and the state does not change: post
    a hold comment (keep the claim) and stop. Check elapsed time on the
    next heartbeat or resume:
    - After `reviewEscalation.changesRequestedFirstEscalation` (default
      `PT24H`) with no response: escalate to a maintainer via issue or
      PR comment.
    - After `reviewEscalation.changesRequestedSecondEscalation` (default
      `PT48H`) with no escalation response: consider adding the
      configured needs-decision label
      (`labels.needsDecisionLabelName`, default `status:needs-decision`)
      and releasing the claim; remove the label and re-claim once
      resolved.
  - Clearing F2's `CHANGES_REQUESTED` gate always requires the review
    **state** itself to change — a reviewer state change (re-submit as
    `COMMENTED`/`APPROVED`) or an admin dismissal via
    `PUT /repos/{owner}/{repo}/pulls/{pull_number}/reviews/{review_id}/dismissals`.
    A comment merely agreeing with your rejection is **never sufficient**
    on its own, whether posted by the original reviewer or by a
    different maintainer/admin — ask them to change state or dismiss
    explicitly.
  - If the reviewer responds and disagrees: move the item to Accepted
    and proceed through the fix flow.
  - If the reviewer responds (either way): restart from E1.
- If you decide "Reject now but should do eventually": open a new issue.
  The new issue's body must include a `Refs #NNN` line on its own
  line (not narrative prose) back to the originating issue — use
  `Refs` specifically and reference the issue, never the PR: a
  referenced PR is recorded as an unresolved reference by
  `discover-roadmap-graph`, and only the `Refs` relationship is
  cycle-exempt for a closed leaf, so a different keyword (e.g.
  `Closes`) or a PR target leaves the reference unresolved until
  the issue body is corrected. Mention the originating PR in prose
  if useful. Mirrors the A1.5 rule in `idd-roadmap-audit.instructions.md`.

Use these prefixes so that disposition is always unambiguous:

- PATH B acceptance marker (only for a _completed_ review of the current
  HEAD): `**Accepted** — {what the advisory comment confirmed}`
- Ordinary rejection: `**Rejected** — {reason}`
- CODEOWNER / required reviewer exception:
  `**Awaiting maintainer decision** — {reasoning}`

Two requirements make the F2/F3 disposition-evidence gate recognize an
`**Accepted**` / `**Rejected**` disposition — `isDispositionComment` reads
"the body **starts with** that marker" and pairs dispositions to advisory
comments **1:1 by count** (`**Awaiting maintainer decision**` is a
separate PATH A signal, not part of this pairing):

- The marker must be the **first bytes of the comment body** — no
  heading, block quote, code fence, or preamble before it (a code-fenced
  marker fails this on its own — the fence delimiters, not the marker,
  are the first bytes), or the gate counts zero dispositions for that
  comment.
- Post **one disposition reply per advisory item** — never combine
  several markers into one comment; the 1:1 pairing clears only one item
  per comment, leaving the rest flagged `missing-disposition-evidence`.

PATH B — Advisory items (completed review of the current HEAD):

- Reply immediately with a decision marker, even when no code change is
  needed. Use `**Accepted**` / "no findings / no action required"
  framing **only** when the advisory is a completed review of the
  current HEAD:
  - `**Accepted** — {what the advisory comment confirmed}`
  - `**Rejected** — {why no action is required}`
- **Review threads**: resolve immediately after posting the marker.
- **Regular comments**: reply only.
- Do not send PATH B items to review-fix. Their work is complete once
  the marker is posted and any thread resolution is done.

PATH B — Advisory non-review notice (rate-limit / quota / queued / bare
ack / error, as defined in E4):

- A non-review notice is never evidence of a completed review — never
  disposition it as confirmation, "no findings", or "reviewed, no
  action needed". It also doesn't prove no review exists: disposition
  any separate _completed_ review of current HEAD under the
  completed-review rules above.
- **Helper-first (optional).** When helper runtime is enabled, the
  `disposition-non-review-notices` helper (see
  `docs/idd-helper-scripts.md`) detects these notices and emits (dry-run)
  or posts (`--apply`) the canonical disposition below — marker-first, one
  per notice, idempotently and fail-closed. The written rule here stays
  authoritative; the manual `gh api` path is the fallback.
- **Disposition it deterministically in the current pass — no
  re-request, no wait.** The notice itself is always `**Rejected**`
  (never `**Accepted**` — it carries no advisory result):
  `**Rejected** — {bot} did not review HEAD {sha} ({reason}); this is
  not a completed review (source: #issuecomment-{id})`. Use the bot's
  GitHub login for `{bot}` (e.g. `coderabbitai[bot]`) so the
  carry-forward rule below can attribute per-bot. A separate _completed_
  review of current HEAD, if present, is its own snapshot item —
  disposition that one as `**Accepted**` under the completed-review
  rules, not this notice. **Re-validate first**: a completed review can
  race in after the E1 snapshot but before this rejection posts. If it
  has, disposition that review instead and take a fresh E1 snapshot, so
  the rejection's later timestamp doesn't filter the completed review
  out of the next pass.
- **Carry the rejection forward across pushes.** Once a notice carries a
  `**Rejected** — {bot} did not review HEAD …` reply, that disposition
  persists across later HEAD changes and pushes while the same notice
  persists and the bot still hasn't reviewed any HEAD — a bumped
  `updatedAt` or a re-posted identical summary needs no fresh rejection;
  the F2/F3 disposition-evidence gate carries the existing one forward.
  Scoped per bot (by GitHub login): one bot's carried rejection never
  clears another's undispositioned notice. Re-disposition only when the
  bot replaces the notice with an actual completed review — disposition
  that under the completed-review rules instead.
- **Never auto-request a fresh review to "upgrade" a notice.** Requesting
  review state is owned solely by the advisory-wait protocol
  (`idd-advisory-wait.instructions.md`, AW3 `REQUEST_NEEDED` → E14); a
  maintainer may manually re-trigger a non-Copilot bot. A later
  completed review is dispositioned normally on the next E1 pass.
  **Never post an `advisory-wait` marker for a non-Copilot bot** —
  AW2/AW3 treat any trusted same-HEAD marker as Copilot evidence,
  wrongly satisfying the Copilot gate and consuming its cap. (The
  **Zero-Accepted-PATH-A advisory re-review gate** below is a sanctioned
  exception — it never triggers on a notice alone.)
- **Fail-closed honesty**: never cite a non-review notice as evidence
  that the advisory reviewer reviewed the current HEAD — not in the
  disposition reply, the `Authoritative by` line, or the PR live status
  digest.
- **Non-blocking boundary**: this rule does not make PATH B a merge
  blocker. The blocking advisory gate remains the Copilot advisory-wait
  protocol in `idd-advisory-wait.instructions.md`, which is unchanged.

## E7 — Verify recorded dispositions

When helper runtime is enabled, prefer the read-only verifier command:

```sh
idd-review-disposition-verify --items '<json>'
```

In the source repository, `node scripts/review-disposition-verify.mjs`
is equivalent. E7 consumes helper fields `passed`, `items[].passed`,
`items[].checks`, and `items[].issues`. This helper never posts replies
or resolves threads: all E6 mutations remain manual and authoritative.
Discard helper output and apply the written checks below directly if
execution fails, output is invalid, or it conflicts with observed
review state.

Before leaving triage, verify every ReviewItems_snapshot item has the
evidence required by its path:

- Every PATH A item has a recorded classification and an Accept or
  Reject decision.
- Every Rejected PATH A item whose source is reviewer feedback has the
  required rejection or `**Awaiting maintainer decision**` reply posted,
  and any non-AMD thread resolution is complete.
- Every PATH B item has a posted `**Accepted**` or `**Rejected**`
  marker. Review threads are resolved immediately after the marker.
- Only Accepted PATH A items remain candidates for
  `idd-review-fix.instructions.md`. PATH B items are fully closed out in
  triage.

If any check fails, do not continue. Return to E4-E6 as needed until the
missing evidence is recorded.

After E7 succeeds, update the PR live status digest only when it will
not invalidate a merge-bound E1 snapshot — when triage posts a hold and
stops, when Accepted PATH A items remain and the next route is E9, or
when a fresh E1 snapshot follows before F2. Set `Phase` to `E triage`,
summarize remaining Accepted PATH A work or `none` in `Open blockers`,
`Next action` to E9 or F2 as appropriate, and cite the disposition
replies plus the trusted review-watermark in `Authoritative by`. If
ReviewItems_snapshot is empty and the next step is F2, defer the digest
update unless you intentionally return to E1 afterward.

## E8 — Accepted PATH A count check

If the Accepted PATH A count is zero → proceed to the
**E-phase branch-sync check** below.

Otherwise continue to `idd-review-fix.instructions.md`.

## E-phase branch-sync check

After the review loop confirms no PATH A items remain (from E3 or E8),
check the current branch state before routing to F-phase. This gate uses
merge-from-`main` (never rebase) when synchronization is required,
preserving review history on the already-published PR branch.

When helper runtime is enabled, call:
`idd-branch-conflict-state --pr {pr-number}`

Otherwise read branch state directly:

```sh
gh pr view {pr-number} --json mergeable,mergeStateStatus
```

Route based on `branchState` from the helper (or `mergeable` /
`mergeStateStatus` from `gh pr view`):

- **`clean`** or **`behind-no-conflict`** when branch protection does not
  require an up-to-date head: **first** apply the
  **Zero-Accepted-PATH-A advisory re-review gate** below if it applies
  (no-op otherwise). **Then**, if E6 posted any disposition reply this
  pass, refresh the `review-watermark` for the same `{head-SHA}`
  (recompute `{max-activity-updatedAt}` / `{total-item-count}` /
  `{latest-ci-completed-at}`, following the E1 Step 2 rules) — otherwise
  F2's review-currency check treats your own dispositions as new
  activity and bounces back to E1 needlessly. Skip the refresh on the
  sync path (E1 re-snapshots after merging `main`) or on a hold. `clean`
  here means conflict-freeness only — see the `baseAdvancedSinceMergeBase`
  note under F1 in `idd-pre-merge.instructions.md`. **Then** proceed to
  `idd-pre-merge.instructions.md` (F1).
- **`behind-no-conflict`** when branch protection or recorded repository
  policy requires an up-to-date head, or undetermined (fail closed, per
  F1): → **sync path** below.
- **`content-conflict`** (`mergeable` is `CONFLICTING`): → **sync path**
  below.
- **`computing`** (`syncRecommendation` is `recheck`): `mergeable` is
  `UNKNOWN` / null because GitHub computes mergeability asynchronously and
  has not settled — a **transient** state. Do **not** hold. Re-poll after a
  short wait, up to a small fixed attempt budget (distributed default: 3
  attempts, a few seconds apart), then route by the first settled result.
  Only a state that is **still** `computing` / `unknown` after the budget
  falls through to the hold below.
- **`dirty`** (`mergeStateStatus` is `DIRTY`) or **`unknown`**: hold; post
  a PR comment documenting the state and stop. Do not proceed to F-phase
  without confirmed branch-state evidence.

**Sync path** (merge-from-`main`):

1. **Active review gate**: unresolved review threads, unreplied
   comments, or a reviewer's `CHANGES_REQUESTED` state require explicit
   operator confirmation before this merge, since the merge commit will
   appear in PR history.
2. Merge `main` into the feature branch:
   `git fetch origin main && git merge origin/main`. Use the
   [signed-commit merge wrapper](../../docs/idd-helper-scripts.md#signed-commit-merge-wrapper-shared-git-procedure)
   when primary signing is non-interactive-hostile.
3. If conflicts arise, resolve them and complete the merge with that
   same procedure — mirrors the D1 rebase note.
4. Run **post-fix-validate**.
5. Push the feature branch normally (no force push required for merge
   commits).
6. Return to `idd-review-snapshot.instructions.md` (E1).

## Merge-main livelock under fast-moving `main`

Under heavy concurrent-session load, `main` can advance faster than one
sync cycle finishes, livelocking naive retries before ever reaching F3
(background:
[design rationale](../../docs/idd-design-rationale.md#merge-main-livelock-under-fast-moving-main)).

**Rule**: post the watermark as the **last** action before F3's
`idd-merge-execute.mjs --apply`, every pass — anything after (a CI
rerun settling, a new disposition reply, another `main` advance)
stales it, failing `--apply` closed on `review-currency` regardless
of CI color; re-post before retrying. A stale `idd-advisory-convergence`
rollup: see [rerun mechanics](idd-ci.instructions.md#rerun-mechanics).

## Zero-Accepted-PATH-A advisory re-review gate

Applies only from the branch-sync check's no-sync-required `clean` /
`behind-no-conflict` exit, and only when the last non-empty
`ReviewItems_snapshot` pass this episode had zero Accepted PATH A items
**and** at least one PATH B item got a _completed-review_ disposition
(never a notice-only rejection — see the E6 non-review-notice rule).
Otherwise a no-op: a true-virgin empty snapshot (no PATH B ever
dispositioned this episode) never fires it; a later-pass empty snapshot
after a sync loop-back still does, since the lookback still finds the
prior non-empty pass. (Rationale for the gap this closes:
[design rationale](../../docs/idd-design-rationale.md#zero-accepted-path-a-advisory-re-review-gate).)
Run this gate **after** any branch-sync merge settles — requesting
first would let a later merge invalidate the review just obtained.

Run E14's **Primary advisory bot** procedure
(`idd-review-fix.instructions.md` E14) at this now-stable HEAD — steps
1-4 plus the active polling loop when it applies; skip Human reviewers
and the secondary-bot step. Substitute "resume the branch-sync check's
no-sync-required `clean` exit (watermark-refresh, then F1)" for each of
E14's four "proceed to E15" exits (step 2's `SATISFIED`, step 4's AW3
`SATISFIED` and `CAP_EXHAUSTED` default, and the polling loop's
`SATISFIED` exit). Every other exit — every "return to E1" and every
hold-and-stop exit — halts exactly as in a normal E9-E15 pass; never
redirect a hold to branch-sync or F1.

E14's own fresh AW1 check already makes this gate inert once the bot
has reviewed current HEAD, so it never duplicates a request, and never
fires when the bot's latest review already covers HEAD but still
carries items — **AW6** (#1511) handles that residual from F2 instead.

## Advisory courtesy-ack convergence

A trusted advisory bot's post-disposition courtesy reply (e.g. "thanks
for confirming") advances the PR's `updatedAt`, which a naive
review-currency check would treat as new activity and loop the
review/snapshot cycle forever.

**Rule**: once every `ReviewItems_snapshot` item has an
`**Accepted**`/`**Rejected**` disposition at the **current HEAD SHA**, a
later **ack-only** comment from a trusted advisory bot does not reopen
the loop — bind the merge to current HEAD and proceed. An **ack-only**
comment opens no new thread, carries no `CHANGES_REQUESTED`, and raises
no new finding; anything else re-opens the loop normally.

_Example_: after you disposition a CodeRabbit thread `**Rejected**`,
CodeRabbit replies "Thanks for confirming" on it — no new thread or
finding, so the `updatedAt` advance is ignored; continue to F-phase on
the current HEAD.

**Helper evidence**: when the advisory-bot identity is configured, the
activity-snapshot / `pre-merge-readiness` evidence emits the structural
half of this classification (`reviewCurrency.live.ackOnly.items`,
`reviewCurrency.comparisonReason: ack-only-post-disposition`); the
agent still confirms the semantic residual (no new finding), and this
never weakens the disposition-evidence or unreplied-comment backstops.

**Disposition-evidence parity (advisory-only)**: the same ack can also
re-trip the `dispositionEvidence` backstop on an already-resolved
thread (`route: return-to-e1`). `pre-merge-readiness` flags each such
thread `ackOnlyPostDisposition: true`; when
`dispositionEvidence.soleCauseAckOnlyPostDisposition` is `true` (every
blocking item is one such thread), autopilot may deterministically
override `return-to-e1` and proceed (see `idd-pre-merge.instructions.md`
F2). Any non-ack blocking cause keeps it `false`, so the backstop holds
otherwise. (`inPlaceEditOnly`/`soleCauseInPlaceEditOnly`, #1313, is a
stricter subset — not an override path of its own.)
