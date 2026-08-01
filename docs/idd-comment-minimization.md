# IDD Comment Minimization

<!-- cspell:words AAAAB Unminimize Wpaqs unminimized -->

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

Run minimization only after one of these is true:

- the PR has already merged
- a maintainer explicitly starts a merged-PR audit

Do not minimize comments during active E or F gates. In particular, do
not minimize comments that still determine review currency, advisory
wait state, unresolved-thread state, unreplied-comment state, hold
state, or a pending maintainer decision.

### Server-side fallback (optional)

The idd-skill source repository ships a
`.github/workflows/post-merge-cleanup.yml` workflow that triggers
on `pull_request_target.closed` events filtered to `merged == true`.
The workflow invokes the helper:

```sh
node scripts/audit-pr-cleanup.mjs --pr <N> --apply --skip-claim-check --format json
```

It then parses the report and posts the canonical
`<!-- idd-cleanup-evidence: ... -->` comment so every actually-merged
PR receives evidence within a few minutes even when the agent did
not run F4 manually.

The template (`idd-template/`) does **not** ship this workflow
because `scripts/audit-pr-cleanup.mjs` is part of the optional
helper bundle and is not present in default instructions-only
installs. Adopters who install the helper can copy the source
workflow file as-is; permissions required are
`contents: read`, `issues: write`, and `pull-requests: write`, plus
`pull_request_target` (not `pull_request`) so that fork PRs can
post comments under a writeable `GITHUB_TOKEN`.

The agent F4 step in `idd-merge.instructions.md` remains the
canonical, mandatory contract. The server-side workflow is a
backstop, not a replacement: same helper, same candidate rules,
same evidence comment shape, non-blocking on errors. Double-posting is
prevented by the cleanup-evidence record itself, not by Actions
concurrency: the workflow skips when any `<!-- idd-cleanup-evidence:`
comment already exists, and the agent F4 step skips its own post when a
prior success record is already present — including the one the workflow
posted. The workflow's PR-keyed `concurrency` group only serializes
workflow runs against each other; it does not gate the agent's local F4.

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

Bot review parent bodies with no associated review threads are skipped
by design, including Copilot error review bodies. They remain visible
until a narrower policy proves that hiding them cannot obscure advisory
review state or maintainer-relevant context.

IDD operational marker comments may be minimized as `OUTDATED` only when
the PR is merged and the marker is no longer needed for resume, advisory
wait, or review-currency checks. Candidate prefixes are:

- `<!-- review-watermark:`
- `<!-- review-baseline:`
- `advisory-wait:`
- `advisory-wait-recovery:`
- `<!-- advisory-wait:`
- `advisory-reroll:`

Always skip candidates when any of these are true:

- `viewerCanMinimize=false`
- `isMinimized=true`
- the comment contains an active hold or
  `**Awaiting maintainer decision**`
- the comment contains failed-CI or reviewer context still needed by
  maintainers
- the comment is non-operational human discussion
- the comment still participates in an active F2 or F3 gate

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

| Dry-run `status`     | Action                                                        |
| -------------------- | ------------------------------------------------------------- |
| `clean`              | No candidates and no permission-blocked items. Proceed to F4  |
|                      | step 3.                                                       |
| `needs-apply`        | Run apply (mandatory). Post a cleanup evidence comment.       |
| `permission-blocked` | Post a cleanup-permission-blocked comment, then proceed to F4 |
|                      | step 3.                                                       |

After apply, if `status` is `failed` or `incomplete`, post a
cleanup-failure comment. A cleanup failure after a successful F3 merge
does not re-block the merge; it is an explicit record only.

### Cleanup evidence comment

Post this comment to the PR after a successful or partial apply. The
HTML comment token on the first line acts as a stable machine-readable
marker so a resuming agent — or a concurrent `post-merge-cleanup`
workflow run — can detect that evidence was already posted. The
**agent-side** rule keys on the prior **success** record: **skip the
post when a `<!-- idd-cleanup-evidence:` comment recording a successful
outcome (`applied` / `clean`) already exists on the PR**, so the agent
never stacks a duplicate success record — even when this run's own apply
returned `applied` for residual markers a concurrent `post-merge-cleanup`
workflow run minimized first; still post when no prior success record
exists, or to correct an existing `failed` / `incomplete` /
`permission-blocked` record. The `post-merge-cleanup` workflow instead
uses a simpler presence-only guard (it skips on any existing marker),
which suffices for its single-shot post-merge run:

```markdown
<!-- idd-cleanup-evidence: {status} applied:{N} failed:{N} skipped:{N} viewer-cannot-minimize:{N} -->

**F4 Cleanup Evidence**

| Field              | Value                                  |
| ------------------ | -------------------------------------- |
| Status             | applied / failed / incomplete          |
| Applied            | N                                      |
| Failed             | N                                      |
| Skipped            | N                                      |
| Permission-blocked | N                                      |
| Notes              | reason for any failed or skipped items |
```

### Cleanup-failure comment

Post this comment when apply `status` is `failed` or `incomplete`. If
`viewer-cannot-minimize > 0` is also non-zero, include the blocked count
in the same comment rather than posting a separate permission-blocked
comment:

```markdown
<!-- idd-cleanup-evidence: {status} applied:{N} failed:{N} skipped:{N} viewer-cannot-minimize:{N} -->

**F4 Cleanup Failure**

Cleanup candidates were detected but not all could be applied.

- Status: failed / incomplete
- Failed: N candidates (reason: ...)
- Unapplied: N candidates
- Permission-blocked: N candidates (if any)

This does not re-block the merge. A maintainer may run cleanup
manually: `node scripts/audit-pr-cleanup.mjs --pr <N> --apply --skip-claim-check`
```

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
