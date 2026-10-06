---
type: reference
title: IDD Comment Minimization
description: Defines the live status digest contract and the safe procedure for minimizing completed review feedback and stale operational markers after merge.
tags: [comment-minimization, cleanup]
---

# IDD Comment Minimization

<!-- cspell:words AAAAB Unminimize Wpaqs unminimized upserts -->

This note defines the safe path for hiding completed IDD review feedback
and stale operational marker comments after a pull request has merged.

Minimization is UI cleanup. It preserves the audit trail and must never
replace review triage, conversation resolution, CI, advisory wait, or
merge gates.

## Live Status Digest Contract

A live status digest is an editable, human-facing issue or pull request
comment that summarizes the current IDD run. It is UI state only. It
must never replace trusted operational markers, review state, CI state,
branch protection, or GitHub issue and pull request state as workflow
evidence.

The first line of every current digest comment is this stable marker:

```html
<!-- idd-live-status: current -->
```

At most one current digest may exist per issue or pull request. Agents
find the digest by searching comments on that issue or PR for the marker
above. The marker is an identifier, not authority: a digest posted by an
untrusted actor or a digest whose text disagrees with trusted markers is
ignored for workflow decisions and repaired only after the authoritative
state has been re-read.

The ordinary digest helper (`live-status-digest.mjs`) enforces this
author boundary mechanically: only a current-digest comment authored by
a trusted marker actor is ever updated or counted toward the
duplicate-digest check. Review-activity counting
(`buildActivitySnapshotSummary`) excludes a digest-marker comment only
when its author is that same trusted marker actor. Unreplied-comment
and disposition-evidence counting (`summarizeRegularCommentsForGate`,
`summarizeDispositionEvidenceForGate`) instead exclude a digest-marker
comment when its author is a trusted marker actor OR a recognized
IDD-agent author -- otherwise an agent's own digest posted outside the
trusted set would count as a genuine reply and wrongly clear earlier,
still-unanswered feedback as already addressed. A digest-marker comment
whose author is in neither set is left alone by the ordinary helper --
it neither rewrites nor deletes it -- and counts as ordinary PR/issue
activity requiring the normal review disposition, exactly like any
other stranger's comment. A recognized IDD-agent author who is not a
trusted marker actor is also left alone by that helper, but those same
unreplied-comment and disposition-evidence gates still exclude that
digest, so it does not count as ordinary activity. The
maintainer-gated repair path below is the one exception: it
deliberately sees and can retire every current-marker comment
regardless of author, since its whole purpose is clearing a
duplicate-digest state a maintainer has already reviewed
(kurone-kito/idd-skill#3337).

Each digest should contain these fields in a compact, editable form:

| Field              | Meaning                                                             |
| ------------------ | ------------------------------------------------------------------- |
| `Phase`            | The current IDD phase or resume route                               |
| `Claim`            | Active claim owner and claim age, or `none`                         |
| `Branch`           | Current work branch or `none`                                       |
| `Last checked`     | ISO 8601 time when the digest was last refreshed from trusted state |
| `Open blockers`    | Human decision, CI, review, dependency, or claim blocker summary    |
| `Next action`      | The next expected agent, maintainer, CI, or reviewer action         |
| `Authoritative by` | The marker, CI, review, issue, or PR evidence the summary came from |

Only the current claim owner should update the digest during normal IDD
execution, and only after the claim revalidation gate passes. Maintainers
may repair a digest outside an active claim, but that repair does not
claim workflow ownership. Roadmap-audit digests follow the same rule:
the roadmap-audit claim gates edits to the roadmap issue digest only,
not child issue execution.

If the digest is missing during resume, recreate it from the parsed
claim state, PR state, CI state, and review activity after the resume
route is known. If the digest is stale, update the existing marked
comment from that same authoritative state. If multiple marked digest
comments exist, do not delete, minimize, or guess which one is
authoritative during an unattended run; preserve the audit history,
report the duplicate URLs, and use trusted markers and GitHub state for
all workflow decisions until a repair path selects one current digest.

### Maintainer-gated duplicate repair

The ordinary digest helper remains fail-closed when it finds multiple current
digest markers. A maintainer may repair that state only through the separate
explicit repair mode; routine claim ownership and normal `--apply` upserts
never select a digest implicitly.

Start with a fresh dry-run and choose the exact current comment to retain:

```sh
node scripts/live-status-digest.mjs --issue <issue-number> \
  --repair-duplicate --retain-comment-id <comment-id> --dry-run
```

The dry-run reports the complete paginated current-digest set and a
SHA-256 snapshot. Apply only with the exact IDs and snapshot hash from that
fresh output:

```sh
node scripts/live-status-digest.mjs --issue <issue-number> \
  --repair-duplicate --retain-comment-id <comment-id> --apply \
  --expected-current-digest-ids "<id>,<id>" \
  --expected-current-digest-sha256 "<snapshot-sha256>" \
  --claim-issue <repair-claim-issue> \
  --claim-id <active-claim-id> \
  --agent-id <claim-agent-id>
```

The authenticated `gh` viewer must be an owner or maintainer, verified through
the repository collaborator-permission endpoint. Missing or inconclusive
permission data fails closed; configured trusted marker actors and issue
authors do not authorize this repair. For an issue target, the claim issue
must equal the target issue; for a PR target, the PR must link exactly one
issue in its `closingIssuesReferences` and the claim issue must equal that
issue. A PR that links zero or more than one issue fails closed, because no
unique repair lease exists. Before every mutation the helper
re-fetches the complete comment set and target state and compares the exact
current-digest IDs, target state, and per-comment body hashes with the latest
expected snapshot. Apply also requires the active IDD claim named by
`--claim-issue`, `--claim-id`, and `--agent-id`; that claim is revalidated
immediately before each retirement and evidence write so compliant repair
writers are serialized. Any drift, selected-comment change, lost claim, or
inconclusive read stops the operation without claiming success.

Every non-retained current digest is retired by changing only its first-line
marker to `<!-- idd-live-status: historical -->`. The full table and any
suffix content remain recoverable; comments are never deleted or minimized.
A fresh postcondition read must prove that exactly one current digest remains
and that every selected duplicate has the planned historical body. Retirement
and evidence bodies are sent as JSON through stdin so an HTML-comment-first
body cannot be truncated by `gh api -f body=...`. If a mutation response is
ambiguous, the helper re-reads the affected comment and target before
recording whether the planned retirement landed and uses that fresh
postflight snapshot in recovery evidence; if an evidence response is
ambiguous, it reconciles only a newly observed exact marker/body authored by
the authenticated repair actor and never blindly retries the POST. The helper
then posts structured evidence with marker
`<!-- idd-live-status-repair: v1 -->`, naming the actor, retained and retired
comment IDs, pre/post entry hashes, target state, and snapshot hashes. A
partial mutation, failed postcondition, or failed evidence write is reported
as `repair-recovery-hold` and requires manual recovery. GitHub does not
generally guarantee conditional requests for unsafe methods such as PATCH, so
the helper does not treat an ETag or `If-Match` header as a compare-and-swap
authority. The active IDD claim coordinates compliant writers; fresh reads,
the verified PATCH response, and the postcondition still surface any
out-of-band drift through the recovery-hold path rather than claiming success.

This preventive maintainer path is grounded in the observed duplicate-digest
incident recorded by issue #3158: dantalion issue #216 closed after its
handoff recorded eleven current digest comments and the normal helper refused
to apply with `action=duplicate, canApply=false`.

## Live Status Digest Helper

In the idd-skill source repository, the helper is available; use dry-run
first. In adopter repositories, see the [Fallback GraphQL](#fallback-graphql)
section unless the helper scripts were explicitly installed.

```sh
node scripts/live-status-digest.mjs --issue <issue-number> --dry-run \
  --phase "<phase>" \
  --claim "<agent-id> / <claim-id>" \
  --branch "<branch-name>" \
  --open-blockers "<blocker-summary>" \
  --next-action "<next-action>" \
  --authoritative-by "<trusted-evidence>"
```

Use `--pr <pr-number>` for pull request digests. If `--last-checked`
is omitted, the helper writes the current UTC time. The helper emits
stable JSON by default; add `--format table` for terminal inspection or
`--include-body` when reviewing the rendered Markdown.

Apply mode is explicit and claim-checked:

```sh
node scripts/live-status-digest.mjs --issue <issue-number> --apply \
  --claim-issue <issue-number> --claim-id <claim-id> \
  --phase "<phase>" \
  --claim "<agent-id> / <claim-id>" \
  --branch "<branch-name>" \
  --open-blockers "<blocker-summary>" \
  --next-action "<next-action>" \
  --authoritative-by "<trusted-evidence>"
```

During ordinary IDD execution, pass the active issue and claim id so the
helper re-reads the claim before mutating. Maintainer-led repairs outside
an active claim may use `--skip-claim-check`, but routine agents should
not. The helper creates a digest when none exists, updates the single
current digest when one exists, and reports `noop` when the current
digest already matches the requested fields.

If multiple marked digests exist, the helper exits non-zero and reports
their URLs plus a repair path. It does not choose between duplicates,
delete comments, minimize comments, or edit immutable operational
markers.

The JSON report includes these fields:

| Field        | Purpose                                                      |
| ------------ | ------------------------------------------------------------ |
| `mode`       | `dry-run` or `apply`                                         |
| `action`     | `create`, `update`, `noop`, or `duplicate`                   |
| `canApply`   | Whether apply mode may mutate without duplicate repair       |
| `commentId`  | Current or newly written digest comment ID, when known       |
| `url`        | Direct link to the digest comment, when known                |
| `duplicates` | Duplicate marked digest comments that block unattended edits |
| `repairPath` | Human repair guidance for duplicate marked digests           |

## Timing

F4 (merge-gated) cleanup is the default timing for every marker or
comment kind not explicitly classified `wired` in `MARKER_HIDE_POLICY`
(`src/scripts/marker-helpers.mts`). For those, run minimization only
after one of these is true:

- the PR has already merged
- a maintainer explicitly starts a merged-PR audit

**Exception -- hide-at-post-time for `wired` families** (issue #731,
issue #733, issue #2751, issue #2754, issue #2755). A `wired` family
may be minimized immediately after its own new instance's POST+verify
succeeds, pre-merge, using that family's documented
supersession/grouping key -- never for any other reason during an
active E or F gate. Six families ship this today, in two different
mechanisms:

- **Agent-followed instruction step** -- the calling phase's own
  instructions direct the agent to run the minimize step by hand
  (`node scripts/minimize-superseded-markers.mjs ... --apply`) after
  posting: the claim chain
  (`claimed-by:`/`unclaimed-by:`, grouped by
  `supersedes:` lineage, `idd-claim.instructions.md`), `review-watermark:`/
  `review-baseline:` (grouped by same claim-id,
  `idd-review-snapshot.instructions.md`), and the `advisory-wait` family
  (`advisory-wait:`/`advisory-wait-recovery:`/`<!-- advisory-wait:`/
  `advisory-reroll:`, grouped by embedded HEAD SHA mismatch, AW3-H,
  `idd-advisory-wait.instructions.md`).
- **Code-automated inside the helper itself** (#2754, #2755) -- no
  agent-followed instruction step exists or is needed for these
  three, since their grouping keys are purely mechanical:
  `review-ack:` (grouped by embedded HEAD SHA mismatch) and
  `copilot-unavailable:` (grouped by the same `claim:` value and a
  strictly lower `attempt:` number -- a same-or-higher attempt is left
  alone) are both hidden by
  `post-idd-marker.mjs` itself right after its own new marker POSTs
  successfully (`--apply --type review-ack` / `--type
  copilot-unavailable`); `<!-- idd-local-validation-evidence:`
  (also grouped by embedded HEAD SHA mismatch, mirroring AW3-H) is
  hidden by `local-validation-evidence.mjs` itself right after its own
  `--record --apply` POST succeeds -- see
  [this helper's doc](idd-helper-scripts.md#local-validation-evidence-helper).
  All three scan the target's other comments for same-family comments
  the new one supersedes and reuse
  `scripts/minimize-superseded-markers.mjs`'s `runMinimize` for the
  actual mutation -- best-effort: any failure there (a permission
  error, an unreadable comment list) is swallowed and never blocks or
  retries the marker post that already succeeded (preventive; no
  observed incident yet — #2788). This mechanism lives
  inside the built `.mjs` helpers, so it only runs where a helper
  runtime is configured (`vendored-node`, `package-manager`, or
  `ephemeral-npx`); under `instructions-only` (or wherever the helper
  is otherwise unavailable), an agent posts these markers' plain-text
  bodies by hand instead, and no equivalent manual minimize step
  exists yet for them the way the agent-followed instruction step
  above already gives the claim chain / review-watermark-baseline /
  advisory-wait families -- these three markers accumulate like an
  `f4-only` family until a future track adds one.

A family classified `f4-only` has
no such wiring yet and follows the default F4-only timing above until a
future track adds it -- concretely, the post-merge F4 batch means
`audit-pr-cleanup.mts`'s generic marker-prefix match
(`operationalMarkerPrefix`) against comments on the merged PR itself,
which recognizes the full `OPERATIONAL_MARKERS` set directly. The
running code never parses this document, so the vendored helper's own
dry run never depends on the Candidate Rules section below staying in
sync with `MARKER_HIDE_POLICY`. Only the manual GraphQL fallback, which
has no code behind it and uses that list as its literal operating
procedure, was narrowed when that list fell behind (issue #2778
reconciled the two and added a mechanical drift-guard test,
`tests/marker-helpers-facade.test.mts`, so a future drift fails closed
instead of recurring silently). A third `MARKER_HIDE_POLICY` kind,
`excluded`, covers markers deliberately kept out of both groupings
(each for the reason on its own
entry in `MARKER_HIDE_POLICY`). Two of those are permanently outside F4's
reach for different reasons: `<!-- forced-handoff:` carries its own
explicit F4 exemption (`audit-pr-cleanup.mts` hardcodes a skip for that
prefix regardless of merge state), and `<!-- activation-nonce:` is a
related marker in the same claim exchange as the wired claim chain above
but is posted to the claim **issue**, not the PR -- F4's PR-scoped
`audit-pr-cleanup.mts` structurally never sees it, so it has no F4
cleanup path even though it is not `wired` either. The remaining
`excluded` entries carry no such exemption; whether F4's generic rule
actually reaches each of them depends on where that family is posted.

Do not minimize comments during active E or F gates for any other
reason. In particular, do not minimize comments that still determine
review currency, advisory wait state, unresolved-thread state,
unreplied-comment state, hold state, or a pending maintainer decision --
including a `wired` family's own comment outside the narrow
POST+verify-triggered exception above.

### Server-side fallback (optional)

The idd-skill source repository ships a
`.github/workflows/post-merge-cleanup.yml` workflow that triggers
on `pull_request_target.closed` events filtered to `merged == true`.
The workflow invokes the helper:

```sh
node scripts/audit-pr-cleanup.mjs --pr <N> --apply --skip-claim-check --format json
```

It then parses the report and posts the canonical
`<!-- idd-cleanup-evidence: ... -->` comment so a merged PR still
receives evidence when the agent did not run F4 manually. Across 395
successful runs from 2026-09-01 through 2026-09-23, elapsed time
(`updatedAt` minus `createdAt`) was p50 71 s, p90 136 s, p95 157 s,
and max 352 s. A cleanup step that reaches its own timeout still
posts `timeout` evidence before the job cap, instead of leaving no
marker.

The template (`idd-template/`) ships a generic counterpart at
`idd-template/.github/workflows/post-merge-cleanup.yml`, part of the
core file set `idd-onboard.mjs --import` copies automatically.
Earlier template versions omitted this file because
`scripts/audit-pr-cleanup.mjs` is part of the optional `vendored-node`
helper bundle and is not present in default `instructions-only`
installs, so a literal copy would only ever work for one profile. The
template copy instead resolves the cleanup-audit invocation through
the repository's configured `helperRuntime.profile` (see
[Helper Runtime Profiles](idd-helper-scripts.md#helper-runtime-profiles)):
it runs the equivalent invocation under `vendored-node`,
`package-manager`, and `ephemeral-npx`, and skips the audit and
evidence-comment steps entirely under `instructions-only` (or when no
profile is configured), where no runnable helper command exists for
any profile. Permissions required are `contents: read`,
`issues: write`, and `pull-requests: write`, plus
`pull_request_target` (not `pull_request`) so that fork PRs can
post comments under a writeable `GITHUB_TOKEN`.

The agent F4 step in `idd-merge.instructions.md` remains the
canonical, mandatory contract. The server-side workflow is a
backstop, not a replacement: same helper, same candidate rules,
same evidence comment shape, non-blocking on errors. Each side keys
off the same trusted-author `<!-- idd-cleanup-evidence:` record: the
workflow skips only when **both** the **latest** trusted-author
comment already records a successful outcome (`applied` or `clean`;
posted by `github-actions[bot]` or a configured `trustedMarkerActors`
login — an untrusted commenter's marker-prefixed comment never
counts) **and this run's own outcome is also `applied`/`clean`**
(issue `#2213`'s both-converged rule — a prior success alone must
never suppress this run's own non-success evidence), and the agent F4
step skips its own post under that same both-converged rule —
including when the workflow itself posted the prior success record. A
trusted comment recording any other status (`failed`, `incomplete`,
`permission-blocked`, `rescan-failed`, `time-budget-exhausted`,
`recheck-failed`, `helper-error`, `timeout`) does not
suppress either side,
so a `workflow_dispatch` rerun after a `rescan-failed` post still
posts fresh evidence (preventive; no observed incident yet — issue
`#2043`). `helper-error` and `timeout` are server-side fallback
statuses with cleanup-failure meaning: the workflow ran but printed
no parseable report, or the cleanup step ended without reporting.
Neither is a successful apply, so neither suppresses a later post.
The workflow's PR-keyed `concurrency` group only serializes
workflow runs against each other; it does not gate the agent's local
F4.

That first read-then-post is not itself atomic. Observed 2026-09-09 on
`kurone-kito/dotfiles#396`: a CodeRabbit review caught duplicate
`idd-cleanup-evidence` comments because each side's check ran once
early in the pass, with enough wall-clock in between for both to
observe "no success record" and both post. Double-posting is therefore
narrowed by **double-checked locking**, not prevented outright: each
side still starts from the record above, but must additionally run a
**second, freshly-fetched re-check immediately before its own POST
call** — with no other GitHub-mutating call in between, and never
reusing a comment list gathered earlier in the same run — and skip
only when that fresh read's latest trusted record **and** this run's
own outcome are both in `applied`/`clean`. This shrinks the race
window from "an entire workflow/agent run" to the gap between that
final re-check and the POST call actually landing on GitHub, for each
side independently. It does not close the window: **GitHub's REST API
for issue/PR comments has no atomic create-if-absent / compare-and-swap
primitive**, so two independent processes can still both observe "no
success record" if their fresh reads interleave inside that narrowed
gap. A GitHub Data API ref-creation lock (`POST .../git/refs`, which
does reject a duplicate atomically) was considered and rejected: it
would need `contents: write` on `post-merge-cleanup.yml`, a
`pull_request_target`-triggered workflow whose own header comment
declares the current least-privilege permission set a trust invariant
future edits must preserve, for a comment-deduplication fix that does
not warrant widening it. This is the same accepted, bounded limitation
already recorded for the claim protocol
(`.github/instructions/idd-claim.instructions.md`,
`.github/instructions/idd-resume.instructions.md`) — narrow the window
via re-check, then live with the remainder — and, in the same
underlying "no compare-and-swap" limitation but a different,
post-hoc-reconciliation mechanism, for the external-check-waiver
helper. See the
[waiver helper](idd-helper-scripts.md#external-check-waiver-helper),
which tolerates a duplicate write and reconciles by re-reading after
the fact rather than narrowing the pre-write window. See
[idd-merge.instructions.md's F4](../.github/instructions/idd-merge.instructions.md#f4--cleanup)
for the literal re-check command both the agent F4 step and
`post-merge-cleanup.yml` run.

**In-flight cleanup-run wait (#2846).** Before the agent's F4 step
decides whether to post its own evidence comment (the
duplicate-success-record rule above — only the agent can run this
wait; the workflow itself cannot block on its own run without
deadlocking), also check whether this PR's own
`post-merge-cleanup.yml` check run is still in flight — narrowing the
residual race the
marker-comment check alone cannot fully close: a run that has started
but not yet posted its comment leaves no marker for that rule to find,
so without this earlier wait both sides can still post within the same
few-second window after merge (observed 2026-09-09 on
`kurone-kito/dotfiles#396`: a live CodeRabbit review caught exactly
this duplicate `idd-cleanup-evidence` comment on an adopter's PR). This
wait only narrows the window, it does not close it: GitHub registers
the check run asynchronously after the triggering webhook fires, so a
run that has not yet been created has no entry here to find yet; that
residual sliver is an accepted fail-open gap, not something this check
claims to close.

`gh pr checks` surfaces this `pull_request_target`-triggered run as a
normal PR check even though it fires after merge — verified on PR
`#2855`, 2026-09-10. Filter on whatever `name:` the adopter's own copy
of the workflow actually declares; this repository's dogfooded copy
and the template both currently say `Post-merge cleanup`.

```sh
gh pr checks <pr-number> --json workflow,bucket --jq \
  'map(select(.workflow == "Post-merge cleanup")) | any(.bucket == "pending")'
```

- **A nonzero exit alone is not failure.** `gh pr checks` exits `8`
  whenever _any_ check on the PR is still pending (its own documented
  behavior — `gh pr checks --help`), even when this query's own
  stdout is valid; a script that aborts under `set -e` on that exit
  code, or that treats any nonzero status as "lookup failed", falls
  through and skips the wait below entirely, leaving the race this
  check exists to narrow. Capture and parse stdout regardless of exit
  status; only _no parseable output at all_ counts as a lookup
  failure.
- **`false`, or no parseable output at all** (old `gh`, no network, a
  GitHub Enterprise Server version without this data, or no run found
  for this PR): not in flight. Continue to the duplicate-success-record
  skip rule unchanged — it reads whatever that run may have posted (if
  any) and adjudicates on the marker's own recorded status, regardless
  of how the run itself concluded.
- **`true`**: the run is in flight. Poll the same query at a reasonable
  interval until it returns `false`, bounded by
  `ciWait.generationTimeout` (default `PT10M`) measured from this
  first `true` observation. A single bound suffices here. The source
  workflow's job cap is 10 minutes, which this default already covers,
  so a queued-versus-running split does not change the wait. The
  template job cap is longer because that copy installs dependencies
  before an 8-minute cleanup step; past this bound the existing
  fail-open still applies. Past
  that bound with the run still in flight, treat it the same as
  "not in flight" and continue to the duplicate-success-record skip
  rule unchanged — a resulting duplicate comment is this check's
  accepted fail-open default, the same one the "not in flight" case
  above already accepts.

## GitHub mechanism

GitHub GraphQL exposes `minimizeComment`:

```graphql
mutation($id: ID!, $classifier: ReportedContentClassifiers!) {
  minimizeComment(input: { subjectId: $id, classifier: $classifier }) {
    minimizedComment {
      __typename
      ... on IssueComment {
        id
        url
        isMinimized
        minimizedReason
        viewerCanUnminimize
      }
      ... on PullRequestReview {
        id
        url
        isMinimized
        minimizedReason
        viewerCanUnminimize
      }
      ... on PullRequestReviewComment {
        id
        url
        isMinimized
        minimizedReason
        viewerCanUnminimize
      }
    }
  }
}
```

The mutation requires a node ID and a `ReportedContentClassifiers`
value. The relevant classifiers are:

- `RESOLVED` for completed feedback or review parent comments
- `OUTDATED` for stale IDD operational markers

Schema checks on 2026-05-09 confirmed that `IssueComment`,
`PullRequestReview`, and `PullRequestReviewComment` expose
`isMinimized`, `minimizedReason`, `viewerCanMinimize`, and
`viewerCanUnminimize`. The `gh pr` command group did not expose a
first-class minimize/hide command, so the portable path is
`gh api graphql`.

## Candidate Rules

Feedback or review parent comments may be minimized as `RESOLVED` only
when all of these are true:

- the PR is merged or the cleanup is part of an explicit merged-PR audit
- every actionable child review comment or thread under that parent has
  been accepted or rejected under IDD rules
- required replies have been posted
- all child threads are resolved
- the reviewer has no active `CHANGES_REQUESTED` state that still gates
  the PR

Known review-bot regular PR comments may be minimized after merge only
when they have a clear completed-review or stale-notification signal.
Current safe classes are:

- CodeRabbit summary / walkthrough comments that explicitly report no
  actionable comments
- CodeRabbit summary / walkthrough comments that have no unresolved
  known-bot review threads and either a later IDD disposition that names
  CodeRabbit or resolved CodeRabbit review threads with fresh IDD
  dispositions
- CodeRabbit review-trigger acknowledgements after a later IDD
  disposition that names CodeRabbit confirms the requested review
  completed
- A Codex usage-limit notice (from the Codex connector) that has a
  later trusted IDD disposition explicitly bound to that exact notice
  via its `(source: #issuecomment-{id})` reference and naming the
  Codex connector, mirroring the CodeRabbit disposition-evidence
  requirement above. The binding is exact, never order- or count-based
  -- a disposition that does not carry this notice's own id never
  resolves it, even when it names the right bot. This is an
  F4-cleanup-only recognition path -- the F2/F3 merge-gate readiness
  checks carry their own separate, multi-bot-safe disposition
  carry-forward for the same notice and do not opt into it.

Bot review parent bodies with no associated review threads are skipped
by design, including Copilot error review bodies. They remain visible
until a narrower policy proves that hiding them cannot obscure advisory
review state or maintainer-relevant context.

IDD operational marker comments may be minimized as `OUTDATED` only when
the PR is merged and the marker is no longer needed for resume, advisory
wait, or review-currency checks. Candidate prefixes are:

- `<!-- claimed-by:`
- `<!-- unclaimed-by:`
- `<!-- review-watermark:`
- `<!-- review-baseline:`
- `<!-- zero-accepted-path-a-gate:`
- `advisory-wait:`
- `advisory-wait-recovery:`
- `<!-- advisory-wait:`
- `advisory-reroll:`
- `review-ack:`
- `copilot-unavailable:`
- `<!-- idd-local-validation-evidence:`

This list tracks every `OPERATIONAL_MARKERS` prefix
(`src/scripts/marker-helpers.mts`) classified `wired` or `f4-only` in
`MARKER_HIDE_POLICY` -- i.e. everything except the `excluded` prefixes
below (issue #2778). **Excluded from this list** -- these are also
`OPERATIONAL_MARKERS` prefixes, but deliberately never candidates for
this manual `OUTDATED` fallback (full reasoning in each entry's own
`MARKER_HIDE_POLICY` record; see also "## Timing" above):

- `<!-- activation-nonce:` -- issue-scoped (posted to the claim issue,
  not the PR) and has no hide-at-post-time wiring yet (caught by
  Copilot review on PR #2759).
- `<!-- forced-handoff:` -- permanent maintainer-authority audit record
  of a claim transfer; never minimize it.
- `<!-- idd-external-check-waiver:` -- maintainer-authority marker; a
  correct grouping key needs the embedded `check:` selector, and hiding
  a still-relevant waiver for a different check would hide live
  authorization (roadmap #2751 Background).
- `<!-- idd-provider-outage-declaration:` and
  `<!-- idd-provider-outage-advanced:` -- issue-scoped, cross-PR
  declare/advance protocol with no clean single-PR grouping key
  (roadmap #2751 Background).
- `<!-- idd-provider-outage-park:` -- needs claim-lineage-aware
  supersession the marker carries no reference for (roadmap #2751
  Background).
- `<!-- idd-out-of-loop:` -- live authorization evidence for the
  bootstrap PR, like the waiver marker above (kurone-kito/idd-skill#3328).

Always skip candidates when any of these are true:

- `viewerCanMinimize=false`
- `isMinimized=true`
- the comment contains an active hold or
  `**Awaiting maintainer decision**`
- the comment contains failed-CI or reviewer context still needed by
  maintainers
- the comment is non-operational human discussion
- the comment still participates in an active F2 or F3 gate

## Side-effects on authoring-owner scan

When `authoring-set-members` scans for issue-authoring ownership
markers, it evaluates every trusted `authoring-owner` comment it
finds. Minimizing one of these comments as `OUTDATED` (GitHub returns
the reason in lowercase: `outdated`) causes the scan to **skip** that
comment rather than failing closed on an unparseable or malformed
body. The comment is not counted as a set member and does not block
the evaluation. Any other `minimizedReason`, including `resolved` and
absent, leaves the ordinary fail-closed behavior in place. Observed
2026-09-27, issue kurone-kito/idd-skill#3553: a minimized comment
with an empty `body-sha256` on closed issue #2689 caused
`authoring-set-members` to fail closed on the Stage 2 release of
issue #3547.

## Dry Run Shape

In the idd-skill source repository, the helper is available; start with
a dry-run. In adopter repositories, see the
[Fallback GraphQL](#fallback-graphql) section unless the helper scripts
were explicitly installed.

```sh
node scripts/audit-pr-cleanup.mjs --pr <pr-number> --dry-run --format table
```

The helper defaults to JSON output for stable machine inspection; use
`--format table` for a compact terminal view. Before applying
minimization, the dry-run report must show candidate and skipped rows
with at least these fields:

| Field               | Purpose                                                            |
| ------------------- | ------------------------------------------------------------------ |
| `subjectId`         | GraphQL node ID passed to `minimizeComment`                        |
| `url`               | Direct audit link                                                  |
| `type`              | `IssueComment`, `PullRequestReview`, or `PullRequestReviewComment` |
| `classifier`        | `RESOLVED` or `OUTDATED`                                           |
| `viewerCanMinimize` | Capability state used for candidate / skip decisions               |
| `isMinimized`       | Current minimization state used for candidate / skip decisions     |
| `reason`            | Why the candidate is safe                                          |

Candidate rows must have `viewerCanMinimize=true` and
`isMinimized=false`. Skipped rows may report the opposite states and
must include the skip reason.

The helper also reports skipped cleanup-shaped nodes with reasons such
as already minimized, no minimization permission, unresolved associated
review threads, missing accept/reject dispositions, unsafe hold or
decision context, no completed-review signal on a known-bot regular
comment, no associated review threads on a bot review parent, untrusted
operational marker author, or a non-merged PR.

## Apply Shape

Apply mode is explicit:

```sh
node scripts/audit-pr-cleanup.mjs --pr <pr-number> --apply \
  --claim-issue <issue-number> --claim-id <claim-id> --format table
```

During an IDD F4 cleanup, pass the active issue and claim id. The helper
re-reads the issue and verifies the active claim before every
`minimizeComment` mutation. Maintainer-led audits outside an active IDD
claim may use `--skip-claim-check`, but ordinary IDD agents should not.

During claim verification, the helper ignores `claimed-by` and
`unclaimed-by` markers whose GitHub author is not trusted. By default,
trusted marker authors are the current authenticated GitHub actor plus
the union of the logins listed in `IDD_TRUSTED_MARKER_ACTORS` and the
`trustedMarkerActors` list in `.github/idd/config.json`; the resolved
list and its source mix are emitted in the report
(`trustedMarkerActors`, `trustedMarkerActorsSources`). Set
`IDD_TRUST_COLLABORATOR_MARKERS=true` only when the repository
explicitly allows any Write, Maintain, or Admin collaborator to post
operational markers.

The same trust check applies before minimizing operational marker-shaped
comments. Untrusted marker-shaped comments remain visible as suspicious
context instead of being hidden as stale automation noise.

The helper applies only safe candidates and reports applied, skipped,
and failed rows. A helper failure is still cleanup-only context; it does
not retroactively block a merge that already passed F3.

## Mandatory F4 Cleanup Contract

F4 cleanup apply is mandatory when candidates exist and the viewer can
minimize them. No path may exit F4 without a recorded reason when
cleanup candidates are detected.

### Decision tree

After the dry-run, evaluate the `status` field and follow the
corresponding path:

| Dry-run `status`     | Action                                                       |
| -------------------- | ------------------------------------------------------------ |
| `clean`              | No candidates and no permission-blocked items. Proceed to F4 |
|                      | step 3.                                                      |
| `needs-apply`        | Run apply (mandatory). Re-check, then post cleanup evidence. |
| `permission-blocked` | Re-check, then post cleanup-permission-blocked, then F4      |
|                      | step 3.                                                      |

After apply, if `status` is `failed`, `incomplete`, or `rescan-failed`,
run the same pre-POST re-check and act on `RECHECK_RESULT`:
`FETCH_FAILED` → post `recheck-failed`, `POST` → post a cleanup-failure
comment, `SKIP` → do not post. A cleanup failure after a successful F3
merge does not re-block the merge; it is an explicit record only.

### Cleanup evidence comment

Post this comment to the PR after a successful or partial apply, and
when the workflow's cleanup step ends with no apply report
(`helper-error` or `timeout`). The
HTML comment token on the first line acts as a stable machine-readable
marker so a resuming agent — or a concurrent `post-merge-cleanup`
workflow run — can detect that evidence was already posted. The
[In-flight cleanup-run wait](#server-side-fallback-optional) above
runs first, delaying only until any in-flight `post-merge-cleanup.yml`
run finishes (or the wait bound elapses) — this marker-based rule is
what actually adjudicates ownership once that run, if any, has had its
chance to post. Both
the **agent-side** F4 step and the `post-merge-cleanup` workflow then
key on the prior **success** record. **Skip the post only when both a
fresh, immediate re-check (see [the double-checked-locking re-check
under Server-side fallback](#server-side-fallback-optional)) finds the
latest trusted `<!-- idd-cleanup-evidence:` comment recording a
successful outcome (`applied` / `clean`) and this run's own outcome is
also `applied`/`clean`** (issue `#2213`'s both-converged rule) —
narrowing, not fully preventing, duplicate success records; a prior
success record alone must never suppress this run's own
`failed`/`incomplete`/`rescan-failed`/`time-budget-exhausted`/`recheck-failed`/`helper-error`/`timeout`
evidence, even
when this run's own apply returned `applied` for residual markers the
other side already minimized first; still post when no prior success
record exists, or to correct an existing `failed` / `incomplete` /
`permission-blocked` / `rescan-failed` / `time-budget-exhausted` /
`recheck-failed` record — a
`rescan-failed`
record in particular invites a retry, so a later `workflow_dispatch`
rerun (or agent F4 re-run) must post fresh evidence for its own
outcome rather than leave stale non-success evidence as the PR's only
record (preventive; no observed incident yet — issue `#2043`):

```markdown
<!-- idd-cleanup-evidence: {status} applied:{N} failed:{N} skipped:{N} viewer-cannot-minimize:{N} retry-attempts:{N} retry-bound-exhausted:{true|false} -->

**F4 Cleanup Evidence**

| Field                            | Value                                                                                                  |
| -------------------------------- | ------------------------------------------------------------------------------------------------------ |
| Status                           | applied / clean / failed / incomplete / rescan-failed / time-budget-exhausted / helper-error / timeout |
| Applied                          | N                                                                                                      |
| Failed                           | N                                                                                                      |
| Skipped                          | N                                                                                                      |
| Permission-blocked               | N                                                                                                      |
| Retry attempts (bound-exhausted) | N (true / false)                                                                                       |
| Notes                            | reason for any failed or skipped items                                                                 |
```

`retry-attempts` / `retry-bound-exhausted` mirror
`audit-pr-cleanup.mjs --apply`'s own `retryAttempts` /
`retryBoundExhausted` JSON fields (its internal whole-pass retry, see
issue 2011): a `true` bound-exhausted value with an otherwise
`applied`/`clean` status is informational, not a cleanup failure — a
fresh rescan still found candidates after the bound, not that
anything went wrong. A `rescan-failed` status (below) always takes the
cleanup-failure path regardless of `retry-bound-exhausted`, since the
confirming rescan itself never completed.

A `time-budget-exhausted` status (`--time-budget-seconds`,
kurone-kito/idd-skill#3321) means this run's own apply-pass wall-time
budget ran out mid-pass: every row already applied before that point is
preserved, the remaining candidates are listed as-is, and no confirming
rescan runs for this invocation — a later invocation (a
`workflow_dispatch` rerun or a local F4 pass) rescans from scratch. It
never collapses into `applied`, `clean`, or `incomplete`, and it is not
itself a cleanup failure (below); local F4 never passes
`--time-budget-seconds`, so this status is only ever reported by the
server-side `post-merge-cleanup.yml` invocation.

### Cleanup-failure comment

Post this comment when apply `status` is `failed`, `incomplete`, or
`rescan-failed`. `rescan-failed` means the confirming rescan after a
mutation errored (a transient GraphQL/`gh` failure) — already-applied
work is preserved in the report, but convergence was never confirmed;
note that distinction and suggest a re-run rather than describing it as
a per-candidate failure. If `viewer-cannot-minimize > 0` is also
non-zero, include the blocked count in the same comment rather than
posting a separate permission-blocked comment:

```markdown
<!-- idd-cleanup-evidence: {status} applied:{N} failed:{N} skipped:{N} viewer-cannot-minimize:{N} -->

**F4 Cleanup Failure**

Cleanup candidates were detected but not all could be applied.

- Status: failed / incomplete / rescan-failed
- Failed: N candidates (reason: ...)
- Unapplied: N candidates
- Permission-blocked: N candidates (if any)

This does not re-block the merge. A maintainer may run cleanup
manually: `node scripts/audit-pr-cleanup.mjs --pr <N> --apply --skip-claim-check`
```

### Re-check-fetch-failure comment

Agent-side F4 only: post this comment when the
[re-check](#server-side-fallback-optional) immediately before posting
prints `RECHECK_RESULT=FETCH_FAILED` — the apply itself may have fully
converged, but the pre-post duplicate-record fetch (`gh api`) failed
(auth, rate limit, transient network error), so this run cannot safely
know whether a prior success record already exists. **Never relabel
this as `failed`/`incomplete`/`rescan-failed`**: those are established
apply-level outcomes with their own meaning elsewhere in this
contract — notably, they never suppress a later run's own success
post, unlike `applied`/`clean` — so reusing one here would misrepresent
a possibly-fully-converged apply as broken to any later reader of this
PR's evidence trail, and could skew a later run's own both-converged
decision. `recheck-failed` is its own status value instead, carrying
the real apply outcome (`apply-status`) alongside it so nothing is
lost. The server-side `post-merge-cleanup.yml` workflow has no
equivalent failure mode — a failed `gh api` fetch there aborts the
whole step under the workflow's own `bash -eo pipefail` before any
comment is attempted, rather than reaching a posting decision at all:

```markdown
<!-- idd-cleanup-evidence: recheck-failed apply-status:{applied|clean|failed|incomplete|rescan-failed} applied:{N} failed:{N} skipped:{N} viewer-cannot-minimize:{N} -->

**F4 Re-check Fetch Failure**

The duplicate-record re-check itself failed immediately before
posting; the apply outcome below may still be fully converged.

| Field                 | Value                                                                |
| --------------------- | -------------------------------------------------------------------- |
| Status                | recheck-failed                                                       |
| Apply status (actual) | applied / clean / failed / incomplete / rescan-failed                |
| Applied               | N                                                                    |
| Failed                | N                                                                    |
| Skipped               | N                                                                    |
| Permission-blocked    | N                                                                    |
| Notes                 | re-check `gh api` fetch failure reason (auth / rate-limit / network) |

This does not re-block the merge. A maintainer or a later F4/workflow
pass may re-run the re-check to confirm convergence.
```

A `recheck-failed` record does not suppress a later run's own success
post, the same non-suppression behavior `failed`/`incomplete`/
`rescan-failed`/`helper-error`/`timeout` already have. The
`Apply status (actual)` row above lists only the agent recheck
apply enum (`applied` / `clean` / `failed` / `incomplete` /
`rescan-failed`). `helper-error` and `timeout` are workflow
evidence statuses, not apply outcomes, so that row excludes them.

### Cleanup-permission-blocked comment

Post this comment when dry-run `status` is `permission-blocked` (no
apply-eligible candidates exist, only viewer-cannot-minimize items).
This status is only emitted in dry-run mode; it is never emitted during
apply (apply failures use `failed` or `incomplete` instead):

```markdown
<!-- idd-cleanup-evidence: permission-blocked applied:0 failed:0 skipped:N viewer-cannot-minimize:{N} -->

**F4 Cleanup Permission Blocked**

Cleanup candidates were detected but the current viewer cannot minimize
them (`viewerCanMinimize: false`).

- Permission-blocked: N candidates

This does not re-block the merge. A maintainer with minimize permission
may run cleanup manually: `node scripts/audit-pr-cleanup.mjs --pr <N> --apply --skip-claim-check`
```

## Fallback GraphQL

If the helper is unavailable, use the direct GraphQL capability checks
below.

Example capability check for one node ID:

```sh
gh api graphql \
  -f query='query($id:ID!){
    node(id:$id){
      __typename
      ... on IssueComment{id url isMinimized minimizedReason viewerCanMinimize}
      ... on PullRequestReview{id url isMinimized minimizedReason viewerCanMinimize}
      ... on PullRequestReviewComment{id url isMinimized minimizedReason viewerCanMinimize}
    }
  }' \
  -f id="$SUBJECT_ID"
```

Call `minimizeComment` only after the dry run shows
`viewerCanMinimize=true` and `isMinimized=false`.

Example mutation call:

```sh
gh api graphql \
  -f query='mutation($id:ID!,$classifier:ReportedContentClassifiers!){
    minimizeComment(input:{subjectId:$id,classifier:$classifier}){
      minimizedComment{
        __typename
        ... on IssueComment{id url isMinimized minimizedReason viewerCanUnminimize}
        ... on PullRequestReview{id url isMinimized minimizedReason viewerCanUnminimize}
        ... on PullRequestReviewComment{id url isMinimized minimizedReason viewerCanUnminimize}
      }
    }
  }' \
  -f id="$SUBJECT_ID" \
  -f classifier="$CLASSIFIER"
```

## Experiment

Experiment date: 2026-05-09.

Target: merged PR
[#78](https://github.com/kurone-kito/idd-skill/pull/78), merged at
2026-05-09T05:36:33Z.

Dry-run selection:

| Subject                     | Type                | Classifier | Reason                                                        |
| --------------------------- | ------------------- | ---------- | ------------------------------------------------------------- |
| `IC_kwDOSWpaqs8AAAABBvMrqA` | `IssueComment`      | `OUTDATED` | `review-watermark` marker on merged PR #78                    |
| `IC_kwDOSWpaqs8AAAABBvM34w` | `IssueComment`      | `OUTDATED` | `review-baseline` marker on merged PR #78                     |
| `IC_kwDOSWpaqs8AAAABBvNZCw` | `IssueComment`      | `OUTDATED` | `advisory-wait` marker on merged PR #78                       |
| `PRR_kwDOSWpaqs79uxOa`      | `PullRequestReview` | `RESOLVED` | CodeRabbit parent review body whose child thread was resolved |

All four dry-run candidates had `viewerCanMinimize=true` and
`isMinimized=false`.

Applied results:

| Subject                     | URL                                                                             | API result                                                                 |
| --------------------------- | ------------------------------------------------------------------------------- | -------------------------------------------------------------------------- |
| `IC_kwDOSWpaqs8AAAABBvMrqA` | <https://github.com/kurone-kito/idd-skill/pull/78#issuecomment-4411567016>      | `isMinimized=true`, `minimizedReason=outdated`, `viewerCanUnminimize=true` |
| `IC_kwDOSWpaqs8AAAABBvM34w` | <https://github.com/kurone-kito/idd-skill/pull/78#issuecomment-4411570147>      | `isMinimized=true`, `minimizedReason=outdated`, `viewerCanUnminimize=true` |
| `IC_kwDOSWpaqs8AAAABBvNZCw` | <https://github.com/kurone-kito/idd-skill/pull/78#issuecomment-4411578635>      | `isMinimized=true`, `minimizedReason=outdated`, `viewerCanUnminimize=true` |
| `PRR_kwDOSWpaqs79uxOa`      | <https://github.com/kurone-kito/idd-skill/pull/78#pullrequestreview-4256895898> | `isMinimized=true`, `minimizedReason=resolved`, `viewerCanUnminimize=true` |

Skipped examples:

- active or non-operational human discussion
- CodeRabbit walkthrough comments that were informational rather than
  stale IDD markers
- accepted/rejected disposition comments, because they are part of the
  review audit trail
- child review comments, because the experiment only needed to prove
  parent review body and operational marker behavior

The API observation confirms that minimized comments remain addressable
by URL and can be unminimized by a viewer with permission.

Public GitHub UI observation for PR #78 showed minimized operational
comments collapsed behind a minimized-comment placeholder and the
resolved feedback area marked as resolved. The underlying comment URLs
remained addressable.
