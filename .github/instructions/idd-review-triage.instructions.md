# IDD — Review Triage Phase (E4–E8)

Read after E3 finds non-empty `ReviewItems_snapshot`; cold E4 runs that
file's Cold-start first.

Before E-phase side effects, apply the [claim revalidation gate](idd-overview-core.instructions.md#claim-revalidation-gate).

**Skip E8**: zero Accepted PATH A → branch-sync if Step 2 was not
deferred (its `clean`/`behind-no-conflict` exit applies the
**Zero-Accepted-PATH-A advisory re-review gate**). Missing evidence →
E1; otherwise continue to E14/E15 in `idd-review-fix.instructions.md`.

## E4 — Classify and score ReviewItems_snapshot

Once per triage pass, snapshot the claimed issue body. Trust an
out-of-scope statement only if it predates the B2 plan
(`idd-work.instructions.md`): a later author edit must not
force-reject a finding. Fetch `userContentEdits`, not `updatedAt`,
paginating until `pageInfo.hasNextPage` is false; a missing, failed, or
incomplete fetch fails closed. Each `diff` is the full post-edit body:
use the latest `editedAt` at or before the plan post, else the
creation-time body, never the live body. A statement absent from that
snapshot needs a maintainer comment.

For each item in ReviewItems_snapshot, first classify it:

- **PATH A — actionable feedback**: human reviewer threads and regular
  comments, `CHANGES_REQUESTED` review bodies, critique-pass findings
  that require a code change or maintainer decision, and Copilot
  inline review-thread comments.
- **PATH B — advisory feedback**: Copilot's and CI advisory bots'
  review-summary bodies and regular comments included by E1 for
  traceability, even when they do not require a code change.
- If classification is ambiguous, default to PATH A.
- Record each PATH A actor's permission standing (CODEOWNER, required
  reviewer, Triage/Write/Maintain/Admin, or none) — E5's cap reads it.

**Advisory non-review notice.** Before scoring a PATH B item, decide
whether it is a _completed_ advisory review of the current HEAD or an
**advisory non-review notice** — an advisory bot comment reporting that
it did **not** review the current HEAD: rate-limit / quota /
credit-exhaustion warnings, queued / in-progress status, a bare request
acknowledgement (e.g. CodeRabbit "Actions performed"), or an error /
"temporarily unavailable" notice. A non-review notice carries no
advisory result to score; handle it under E6's non-review-notice rule
instead.

Then apply path-specific scoring:

- **PATH A**: assess severity/relevance to PR intent. **High** (safety,
  correctness, requirement violations, CI stability) → **Accept
  forced**, gated by "Verify before accept" and the actor-permission cap
  (E5); **Low** (minor, unrelated to PR intent) → **Reject
  recommended**; **Medium** → judge by context.
- **PATH B**: no High/Medium/Low. Score only a _completed_ review of
  current HEAD as `Accepted` (confirmed/useful) or `Rejected`
  (noted, no action) — route a non-review notice to E6 instead.
- **Scope fence (PATH A and PATH B).** A finding that asks to
  introduce, or further broaden, a change class the claimed issue's own
  body explicitly places out of scope scores `Low` (PATH A) or
  `Rejected` (PATH B) and disposes **Reject forced**, regardless of
  technical correctness or tractability, from the point that class is
  introduced onward. A refinement or bug fix inside an
  already-introduced instance of that class is still in-scope work and
  scores normally. This fence
  overrides PATH A's High-tier `Accept forced` rule: even a
  correctness finding that would introduce or broaden a fenced class
  does not reach `Accept forced` merely for being High-severity.
  Record a rejected instance as a known limitation in the PR body's
  follow-up-issues content (`idd-pr-submit.instructions.md` — mapped
  onto the template's "Follow-up issues" section when one exists), not
  a defect. Edit it at E4 under E12's "PR body sync" safeguards
  (`idd-review-fix.instructions.md`: claim revalidation first, fetch
  the full body, edit only this claim, post the full result back,
  re-check `closingIssuesReferences`), even when E8's zero-Accepted-
  PATH-A skip bypasses E9-E15 and E12 (`#3495`).

## E5 — Record Accept / Reject decisions

Record a path-specific disposition for every item:

- **PATH A**: High-severity items reach Accepted only via "Verify
  before accept" below, or — when the actor-permission cap applies —
  an explicit maintainer confirmation reply; Medium/Low require an
  explicit Accept or Reject decision, except a scope-fenced finding
  (E4), which is Reject forced regardless of severity.
- **PATH B** (a _completed_ review of the current HEAD): `Accepted`
  means the advisory confirms the implementation or captures useful
  context; `Rejected` means noted, no action required. An advisory
  non-review notice (E4) is **not scored** here — record it, but always
  as `Rejected` per the E6 non-review-notice rule.

**Actor-permission cap (PATH A).** Before an Accept, check whether the
actor is a CODEOWNER, required reviewer, or holds Triage/Write/Maintain/
Admin access (`GET
/repos/{owner}/{repo}/collaborators/{username}/permission`). Absent all
three, assertion alone never reaches Accept forced — only "Verify before
accept" confirming the claim, or an explicit maintainer confirmation
reply, gets it there. Otherwise cap it at Rejected with the reasoned
reply E6 requires. CODEOWNER/required-reviewer AMD handling is unchanged.

Accepted PATH B items do **not** enter review-fix. They are fully
handled in E6-E7.

**Verify before accept (PATH A and PATH B).** A PATH A or PATH B item
often asserts a fact — about safety, correctness, the runtime, CI, or an
artifact. Before `Accept`ing it, confirm the claim against live evidence
(a code read, reproduction, or an equivalent check), not the comment
text alone — the actor-permission cap above is the only exception, via
maintainer confirmation for an unprivileged PATH A actor: confirmed →
`Accept` and act; **false on the live evidence** → disposition it
`Rejected` and cite the contradicting evidence (the code as read, the
real run conclusion, file contents, or artifact) — a verified-false
claim is a reasoned rejection, not an action item (scoped to this
verification only — not E4/E5's Low-severity/no-action `Rejected`
routes); **inconclusive** (neither confirmed nor contradicted — the
needed check has no route here, not merely low confidence) → for an
actor-permission-capped, reviewer-feedback PATH A item, route it
through the CODEOWNER/required-reviewer AMD hold (E6) instead of
`Rejected`, using E6's marker (a critique-pass finding stays under
the unchanged cap above).

**Resolved-thread duplicate pre-check (PATH B, before verification).**
Before verification above, check whether a new PATH B item — a review
thread or regular comment (E6 supports both sources) — matches an entry
in this PR's resolved-thread index (`idd-review-snapshot.instructions.md`
E1 Step 3), scoped to **this PR's** resolved threads only: a regular
comment has no resolved state of its own but can still match a prior
resolved thread's claim.

- Match by file area and substantive claim — the identical claim, not
  merely a related topic in the same file.
- On a match, open the linked prior thread (the index disposition alone
  is not proof); re-confirm the **same underlying claim**, that the
  prior thread recorded a **reasoned rejection with citable evidence**
  (not a bare `**Rejected**`, nor the E6 non-review-notice rejection,
  which asserts no result was reviewed), and that the cited evidence
  still holds at current HEAD — a prior file/line citation can go stale
  between rounds.
- **Shortcut.** If the prior rejection's evidence still holds: reply
  with a fresh, individually-authored disposition citing the prior
  thread's URL and evidence, then apply E6's PATH B reply rules for
  that item's source (resolve after replying for a thread; reply only
  for a regular comment). Every recurrence still gets its own reply —
  only the content is shortcut.
- **Fall through** unchanged to "Verify before accept" above on no
  match, a different underlying claim, a disposition that isn't a
  reasoned rejection with evidence, stale evidence, or genuinely new
  information the prior thread didn't address.

**Defer (`critiqueLoop.deferAfterRounds` / `critiqueLoop.deferByUrgency`).**
Two triggers dispose any human or automated reviewer's PATH A item
**Reject (defer)** instead of normal judgment — never PATH B, a
scope-fenced item, an Accepted item mid-fix
(`e10NoProgressHoldAfter`), or a CODEOWNER/required-reviewer item
(E6 AMD). Reply
`**Rejected** — deferred to follow-up issue #<n> ({clause}): {reason}`.

- **Round-count** (`deferAfterRounds`, default `12`, Low-only). Once
  the PR's total, paginated
  `copilot-pull-request-reviewer[bot]` review count (PR-wide, not
  per-claim; never one page's `length`) hits the threshold, an
  undispositioned Low-severity (E4) item is eligible. Clause:
  `round <round>/<threshold>`.
- **Adopt-now urgency** (`deferByUrgency`, default `off` — E4/E5
  unchanged when off; `low`/`low-and-medium` from round 1).
  Eligibility is the higher of the E4 tier and Copilot's label — the
  `alt="<Level> severity"` text next to its `#discussion_r<id>` link
  in the Open section of any `<!-- ccr-overview-v2 -->` review. The
  floor never replaces E4's tier: unknown severity never defers in these modes.
  **Adopt-now** (never eligible) when any holds: (a) a regression this PR's diff
  introduced relative to its merge base; (b) the claimed issue's
  acceptance criteria or requirement are unmet; (c) a
  defect in shipped behavior — code, helper output, CI result, or
  instruction text that changes what an agent does — or a
  safety/CI-stability problem, excluding wording/clarity polish and
  extra test coverage for already-working behavior; (d) another item
  in the same E5 pass is already Accepted (any severity), so a push
  is certain, and this fix stays within that push's files. Otherwise
  eligible within the ceiling (`low`: Low; `low-and-medium`: Low or
  Medium — High never eligible). A null urgency still defers. Clause:
  `adopt-now: no; severity <tier>[, Copilot <label>]`.
- **`severity-tiered`** replaces that allowlist from round 1. Judge
  validity and E4 severity (a false claim is Rejected), then urgency by
  the fix's marginal review-wave cost: `very-low` < `low` < `medium` <
  `high`. The matrix decides; regression, unmet requirements,
  correctness, and safety never override. `very-low`: wording/formatting
  changing no behavior; `low`: extra tests, comments, or naming for
  already-correct behavior; `medium`: local maintainability, or a
  correctness risk short of `high`; `high`: an adopt-now (a)-(c)
  condition. Unknown E4 severity counts as Medium; the floor only
  raises. Unscored urgency never defers. High defers only at `very-low`
  (Accept forced does not win); Medium or unknown, not at `high`; Low at
  every scored urgency. Clause: `urgency <level>; severity <tier>[,
  Copilot <label>]`.

Bundle one E5 pass's deferred items into one follow-up issue (E6; do
not append). Each keeps an AC bullet, exactly one
`Refs #<originating-issue>` line, and the
`<!-- setup-windows-authoring-defer-source: review-fix-loop-cutoff -->`
marker, then issue-authoring's Stage 2 narrow auto-release, not the Stage 1
hold. See
[rationale](../../docs/idd-design-rationale.md#e4e5-adopt-now-urgency-defer).

## E6 — Post disposition replies

Apply the reply rules below after E5 records a disposition.

PATH A — Accepted items:

- Do not reply in triage solely to acknowledge the acceptance. Accepted
  reviewer feedback is replied to after the fix work in
  `idd-review-fix.instructions.md`.

PATH A — Rejected/inconclusive reviewer feedback:

For each Rejected or inconclusive (E5) PATH A item whose source is
reviewer feedback:

- Reply using the format: `**Rejected** — {reason}` — unless the
  Exception below applies.
- **Exception**: if the source is a CODEOWNER or required reviewer, or
  the item is E5's inconclusive outcome, do not reject unilaterally.
  Reply using the format:
  `**Awaiting maintainer decision** — {your reasoning}` (name the
  unavailable check when inconclusive) and wait for the maintainer's
  response.
- After posting your reply, **immediately resolve the thread** — except
  for `**Awaiting maintainer decision**`. When helper runtime is enabled,
  the profile-selected resolve-review-thread command (`--pr <number>
  --comment-id <id> --apply`, with `--body`/`--claim-issue`/`--claim-id`
  or `--claimless`; see `docs/idd-helper-scripts.md`) posts the reply
  and resolves in one
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
  for the response in a future E1 pass (see the transitions below).
- **When an `Awaiting maintainer decision` item re-appears in ReviewItems_snapshot**:
  scan the activity universe for a **qualifying response** — a reply on
  this item, or a separate comment/review that clearly references
  this item — from a **qualifying person** (any CODEOWNER, required
  reviewer, or a collaborator with Write/Maintain/Admin access per
  `GET /repos/{owner}/{repo}/collaborators/{username}/permission`),
  excluding the acting agent and the PR author, posted **after** your
  AMD comment. A general comment/review not referencing this item
  doesn't count.

  If a qualifying response exists, apply the transitions below;
  otherwise ensure a hold comment exists (post one if not) and stop —
  do not re-reply or resolve; resume when the response appears in a
  future E1 pass.
- **When the maintainer eventually responds** (their response surfaces
  in a future E1 pass as an unresolved thread or new reply):
  - If the maintainer **agrees no action is needed**: reply summarizing
    the agreed decision (e.g.,
    `**Rejection confirmed by maintainer** — {summary}`) and resolve the
    thread.
  - If the maintainer **disagrees**: move the item to Accepted and
    proceed through the fix flow. Resolve the thread after fixing.
  - If the maintainer's response arrived in a separate PR comment/review
    rather than the original thread: mirror the decision onto the
    original thread and resolve it, and **reply to the maintainer's
    separate comment** (e.g., "Decision mirrored to the review thread —
    {link}") so F2's unreplied-comments gate doesn't block merge on it.
  - **No thread (regular-comment AMD)**: apply the same
    agree/disagree logic in a new comment naming it (no reply
    endpoint exists); skip every "resolve the thread" step above.
- For a `CHANGES_REQUESTED` review body you are rejecting: post a PR
  comment explaining your reasoning and ask the reviewer to reconsider.
  - If the reviewer does not respond and the state does not change: post
    a hold comment (keep the claim) and stop. Check elapsed time on the
    next heartbeat or resume:
    - After `reviewEscalation.changesRequestedFirstEscalation` (default
      `PT24H`) with no response: escalate to a maintainer via issue or
      PR comment.
    - After `reviewEscalation.changesRequestedSecondEscalation` (default
      `PT48H`) with no escalation response: apply the
      **Needs-decision claim release** rule in
      `idd-overview-appendix.instructions.md` (Hold / suspend).
  - Clearing F2's `CHANGES_REQUESTED` gate always requires the review
    **state** itself to change — a reviewer state change (re-submit as
    `COMMENTED`/`APPROVED`) or an admin dismissal via
    `PUT /repos/{owner}/{repo}/pulls/{pull_number}/reviews/{review_id}/dismissals`.
    A comment merely agreeing is **never sufficient** on its own,
    whether from the original reviewer or another maintainer/admin —
    ask them to change state or dismiss explicitly.
  - If the reviewer responds and disagrees: move the item to Accepted
    and proceed through the fix flow.
  - If the reviewer responds (either way): restart from E1.
- If you decide "Reject now but should do eventually": open a new issue
  following `idd-pr-submit.instructions.md` D3's follow-up-issue rule —
  never call `gh issue create` (or the REST issues API) directly; use
  the `issue-authoring` skill.
  The new issue's body must include a `Refs #NNN` line on its own
  line (not narrative prose) back to the originating issue — use
  `Refs` specifically and reference the issue, never the PR: a
  referenced PR is recorded as an unresolved reference by
  `discover-roadmap-graph`, and only the `Refs` relationship is
  cycle-exempt for a closed leaf, so a different keyword (e.g.
  `Closes`) or a PR target leaves the reference unresolved until
  the issue body is corrected.

Two requirements let F2/F3's disposition-evidence gate recognize an
`**Accepted**`/`**Rejected**` disposition: `isDispositionComment` reads
"starts with that marker," pairing dispositions to advisory comments
**1:1 by count** (`**Awaiting maintainer decision**` is a separate PATH A
signal, excluded from this pairing):

- The marker must be the **first bytes of the comment body** — no
  heading, block quote, code fence, or preamble before it (a code-fenced
  marker fails this on its own — the fence delimiters, not the marker,
  are the first bytes), or the gate counts zero dispositions for that
  comment.
- After the visible prefix, include the prefix-aware reply-identity
  stamp
  `<!-- {markerPrefix}-review-reply -->`
  (use the repository `markerPrefix`, default `idd-skill`; helpers
  inject it; a manual `gh api` JSON body must append it). The stamp is
  utterance identity, not an E1 `review-watermark`, and it must not
  replace the required `**Accepted**` / `**Rejected**` first bytes.
  F2 treats an unmarked human reply on a **human-authored** thread as
  presence-only; it does **not** treat that as a completed IDD
  disposition. Copilot / configured-advisory-bot threads still require
  a stamped or legacy trusted IDD disposition (or resolution). E7
  still fails a recorded PATH A agent reply that lacks this marker
  contract — presence-only is an evaluation rule for other people's
  replies, not a license to post bare prose on the session's own
  items.
- Post **one disposition reply per advisory item** — never combine
  several markers into one comment; the 1:1 pairing clears only one item
  per comment, leaving the rest flagged `missing-disposition-evidence`.

PATH B — Advisory items (completed review of current HEAD):

- Reply immediately with a decision marker, even with no code change
  needed:
  - `**Accepted** — {what the advisory comment confirmed}`
  - `**Rejected** — {why no action is required}`
- **Review threads**: resolve immediately after posting. **Regular
  comments**: reply only.
- PATH B never enters review-fix — work is complete once the marker
  (and any thread resolution) is posted.

**`review-ack:` marker — Clause 1 vs Clause 2.** Posting `**Accepted**`/
`**Rejected**` above satisfies advisory-convergence's Clause 2 (thread/
comment disposition) only. When the latest Copilot review on current
HEAD also reports `suppressedCount > 0` (a finding folded into a
`<details><summary>Suppressed comments (N)</summary>` block with no
thread/comment ID of its own — see `docs/idd-helper-scripts.md`),
Clause 1's `suppressedCount` term needs its own coverage
(`suppressedCount === 0 || hasValidReviewAck`) regardless of any Clause
2 disposition elsewhere in the review. After confirming the suppressed
finding(s) are handled (fixed, or judged as needing no action), post
`review-ack:` for the current HEAD SHA — only a
`trustedMarkerActors`-authored marker counts; an untrusted poster's is
ignored, not rejected at post time (helper-first: `post-idd-marker
--type review-ack --from-pr <pr-number> --agent-id <id> --timestamp
<ISO8601> --apply`):

```text
review-ack: {agent-id} {PR_HEAD_SHA} {ISO8601-acknowledged-at}
```

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
- **Paraphrase, never reproduce, a bot's trigger or command string in
  `{reason}`.** Advisory bots scan comment bodies for their own
  command-trigger strings even inside code spans, so quoting a bot's
  literal review-request mention verbatim — fenced or not — can fire
  it as though manually requested; describe the situation in your own
  words instead. Canonical paraphrase for the low-star/manual-trigger
  skip-review case: "requires a manually triggered review for
  low-star repositories".
- **Carry the rejection forward across pushes.** Once a notice's
  `**Rejected** — {bot} did not review HEAD …` reply exists, it
  persists across later HEAD changes/pushes while the notice persists
  and the bot still hasn't reviewed any HEAD — a bumped `updatedAt` or
  a re-posted identical summary needs no fresh rejection; F2/F3's
  disposition-evidence gate carries it forward. Scoped per bot (GitHub
  login): one bot's carried rejection never clears another's
  undispositioned notice. Re-disposition only when the bot posts an
  actual completed review instead, under the completed-review rules.
- **Never auto-request a fresh review to "upgrade" a notice** — that
  belongs solely to the advisory-wait protocol
  (`idd-advisory-wait.instructions.md`, AW3 `REQUEST_NEEDED` → E14); a
  maintainer may manually re-trigger a non-Copilot bot, and a later
  completed review dispositions normally next E1 pass. **Never post an
  `advisory-wait` marker for a non-Copilot bot** — AW2/AW3 treat any
  trusted same-HEAD marker as Copilot evidence, wrongly satisfying the
  Copilot gate and consuming its cap (the **Zero-Accepted-PATH-A
  advisory re-review gate** below is a sanctioned exception, never
  triggered by a notice alone).
- **Fail-closed, non-blocking**: never cite a non-review notice as
  evidence the advisory reviewer reviewed current HEAD — not in the
  disposition reply, `Authoritative by`, or the live status digest;
  and this rule never makes PATH B a merge blocker — the Copilot
  advisory-wait protocol (`idd-advisory-wait.instructions.md`) remains
  the blocking gate, unchanged.

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

- Every PATH A item has a recorded classification and an Accept,
  Reject, or AMD decision (including E5 inconclusive). Every Accepted
  item cites its "Verify before accept" evidence, or the maintainer
  confirmation reply when actor-permission capped.
- Every Rejected or inconclusive PATH A item whose source is reviewer
  feedback has the required rejection or
  `**Awaiting maintainer decision**` reply posted, and any non-AMD
  thread resolution is complete.
- Every PATH B item has a posted `**Accepted**` or `**Rejected**`
  marker. Review threads are resolved immediately after the marker.
- Only Accepted PATH A items remain candidates for
  `idd-review-fix.instructions.md`. PATH B items are fully closed out in
  triage.

If any check fails, do not continue. Return to E4-E6 as needed until the
missing evidence is recorded.

After E7, update live digest only when safe for merge-bound E1: on hold,
Accepted PATH A → E9, or fresh E1 before F2. Set `Phase` to
`E triage`, put Accepted PATH A/`none` in blockers, set Next to E9/F2,
cite dispositions/watermark. For skipped Step 2 due to incomplete
CI/advisory, cite E1 Step 1 SHA plus
`watermark deferred, CI/advisory incomplete`. If snapshot empty and
next F2, defer digest unless returning E1.

## E8 — Accepted PATH A count check

Zero Accepted PATH A + deferred Step 2 → the E14/E15 wait route in
`idd-review-fix.instructions.md`; otherwise branch-sync. Non-zero →
`idd-review-fix.instructions.md`.

## E-phase branch-sync check

After no PATH A items remain (E3/E8),
check the current branch state before routing to F-phase. This gate uses
merge-from-`{development-branch}` (never rebase) when synchronization is
required, preserving review history on the already-published PR branch.
`{development-branch}` is the value resolved by
[B1 Worktree creation Step 2](idd-work.instructions.md#b1--create-worktree-with-branch).

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
  (no-op otherwise). **Then**, if E6 posted a disposition reply or the
  gate above posted a marker this pass, refresh the `review-watermark`
  for the same `{head-SHA}` (recompute `{max-activity-updatedAt}` /
  `{total-item-count}` / `{latest-ci-completed-at}`, following the E1
  Step 2 rules) — otherwise F2's review-currency check treats this as
  new activity and bounces back to E1 needlessly. Skip the refresh on
  the sync path (E1 re-snapshots after merging `{development-branch}`)
  or on a hold. `clean`
  here means conflict-freeness only — see the `baseAdvancedSinceMergeBase`
  note under F1 in `idd-pre-merge.instructions.md`. **Then** proceed to
  `idd-pre-merge.instructions.md` (F1).
- **`behind-no-conflict`** when branch protection or recorded repository
  policy requires an up-to-date head, or undetermined (fail closed, per
  F1): → **sync path** below.
- **`content-conflict`** (`mergeable` is `CONFLICTING`): → **sync path**
  below.
- **`computing`** (`syncRecommendation` is `recheck`): `mergeable` is
  `UNKNOWN` / null because GitHub hasn't finished computing mergeability —
  a **transient** state. Do **not** hold. Re-poll after a short wait, up
  to a small fixed attempt budget (distributed default: 3 attempts, a
  few seconds apart), then route by the first settled result. Only a
  state that is **still** `computing` / `unknown` after the budget falls
  through to the hold below.
- **`dirty`**, **`unknown`**, or an unlisted state (e.g.
  `force-push-exception`): hold; post a PR comment documenting the
  state and stop. Do not proceed to F-phase without confirmed
  branch-state evidence.

**Sync path** (merge-from-`{development-branch}`):

1. **Active review gate**: unresolved review threads, unreplied
   comments, or a reviewer's `CHANGES_REQUESTED` state require explicit
   operator confirmation before this merge, since the merge commit will
   appear in PR history.
2. Merge `{development-branch}` into the feature branch:
   `git fetch origin && git merge
   origin/{development-branch}`. Use the
   [signed-commit merge wrapper](../../docs/idd-helper-scripts.md#signed-commit-merge-wrapper-shared-git-procedure)
   when primary signing is non-interactive-hostile — its merge
   invocation includes a conventional `-m` subject (e.g. `chore: merge
   origin/{development-branch} into the claimed branch`) so commitlint
   doesn't reject the merge commit.
3. If conflicts arise, resolve them and complete the merge with that
   same procedure — mirrors the D1 rebase note.
4. Run **post-fix-validate**.
5. Push the feature branch normally (no force push required for merge
   commits).
6. Return to `idd-review-snapshot.instructions.md` (E1).

## Merge-development-branch livelock under fast-moving {development-branch}

`{development-branch}` can advance faster than one sync finishes
(background:
[design rationale](../../docs/idd-design-rationale.md#merge-main-livelock-under-fast-moving-main)).

**Rule**: post the watermark as the **last** action before F3's
`idd-merge-execute.mjs --apply`, every pass. Use F2's review-currency
rules for later activity, including its own-agent procedural-comment and ack-only
carve-outs. A stale `idd-advisory-convergence` rollup: see [rerun mechanics](idd-ci.instructions.md#rerun-mechanics).

## Zero-Accepted-PATH-A advisory re-review gate

Applies only from the branch-sync check's no-sync-required `clean` /
`behind-no-conflict` exit, and fires under either of two conditions:
(a) the last non-empty `ReviewItems_snapshot` pass at current
HEAD had zero Accepted PATH A items **and** at least one PATH B item
got a _completed-review_ disposition (never a notice-only rejection —
see the E6 non-review-notice rule), as recorded by the durable
`zero-accepted-path-a-gate` marker below; or (b) current HEAD is eligible for
**AW3-S**'s settled-window (non-pending) entry (running
`advisory-wait-state` reports `staleRequestRecovery.action` as
`"attempt"` for that entry) — a defense-in-depth backstop
([rationale](../../docs/idd-design-rationale.md#zero-accepted-path-a-advisory-re-review-gate)).
Otherwise a no-op.

**Durable state.** The gate posts which condition, (a) or (b), and its
HEAD SHA to a dedicated marker (not folded into `review-watermark`'s
schema), via the same trusted direct HTTP `POST` mechanics:

```markdown
<!-- zero-accepted-path-a-gate: {agent-id} {claim-id} {a|b} {head-SHA} -->

_{agent-id}: Zero-Accepted-PATH-A gate state — IDD automation marker. Do not edit._
```

Before evaluating (a), read back the latest same-claim, trusted-author
marker: a HEAD match means the gate already applies for its recorded
condition; any other `{head-SHA}` — a push always advances HEAD — is
stale, so (a) must be reproduced fresh there, or the gate falls
through to (b). Post a fresh
marker the first time (a) or (b) is observed true (skip a duplicate),
replacing in-session memory so the gate survives a crash or resume.
Run this gate **after** any branch-sync merge settles — requesting
first would let a later merge invalidate the review just obtained.

Run E14's **Primary advisory bot** procedure
(`idd-review-fix.instructions.md` E14) at this now-stable HEAD — steps
1-4 plus the active polling loop when it applies; skip Human reviewers
and the secondary-bot step. Substitute "resume the branch-sync check's
no-sync-required `clean` exit (watermark-refresh, then F1)" for each of
E14's six "proceed to E15" exits (step 2's `SATISFIED`, step 4's AW3
`SATISFIED` and `CAP_EXHAUSTED` default, and the polling loop's
`SATISFIED` exit). Every other exit — every "return to E1" and every
hold-and-stop exit — halts exactly as in a normal E9-E15 pass; never
redirect a hold to branch-sync or F1.

E14's own fresh AW1 check already makes this gate inert once the bot
has reviewed current HEAD, so it never duplicates a request, and never
fires when the bot's latest review already covers HEAD but still
carries items — **AW6** (#1511) handles that residual from F2 instead.

## Advisory courtesy-ack convergence

**Rule**: a trusted advisory bot's courtesy reply bumps the PR's
`updatedAt`, but once every `ReviewItems_snapshot` item has an
`**Accepted**`/`**Rejected**` disposition at the **current HEAD SHA**,
that later **ack-only** comment does not reopen the loop — bind the
merge to current HEAD and proceed. An **ack-only** comment opens no
thread, carries no `CHANGES_REQUESTED`, and raises no new finding;
anything else re-opens the loop.

**Helper evidence**: with advisory-bot identity set,
`pre-merge-readiness`'s `reviewCurrency.live.ackOnly.items` /
`reviewCurrency.comparisonReason: ack-only-post-disposition` supply
this; the agent confirms no new finding, never weakening the
disposition-evidence or unreplied-comment backstops.

**Disposition-evidence parity (advisory-only)**: the same ack can also
re-trip the `dispositionEvidence` backstop on an already-resolved
thread (`route: return-to-e1`). `pre-merge-readiness` flags each such
thread `ackOnlyPostDisposition: true`; when
`dispositionEvidence.soleCauseAckOnlyPostDisposition` is `true` (every
blocking item is one such thread), autopilot may deterministically
override `return-to-e1` and proceed (see `idd-pre-merge.instructions.md`
F2). Any non-ack blocking cause keeps it `false`, so the backstop holds
otherwise. (`inPlaceEditOnly`/`soleCauseInPlaceEditOnly`, #1313, is a
stricter subset — not an override path of its own.) A
verify-then-confirm reply (analysis before the confirmation verb)
isn't recognized, so #2125's override doesn't fire (recognized
replies are unaffected). A repeating `missingThreads` entry that's a
no-new-content advisory-bot reply needs a hold comment; stop instead
of re-posting the disposition (#3324).
