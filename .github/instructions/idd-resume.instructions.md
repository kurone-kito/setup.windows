# IDD — Resume Phase

Use this file when taking over a crashed or rate-limited session with no
prior session context. Read `idd-overview-core.instructions.md` for shared
definitions (claim format, stale threshold, abort, hold). For full narrative
detail on each routing branch, see
[`docs/idd-resume-detail.md`](../../docs/idd-resume-detail.md).

Resume stale checks use the `claim-stale-age` policy default from
`docs/policy-constants.md` (distributed default: `24 h`).

## Required Inputs

Collect all signals before routing. Use GitHub server timestamps only.

| Signal                   | What to collect                                                                                                                                                                            |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Claim state              | Active `{claim-id}`, agent-id, branch, latest valid `claimed-by` `created_at`; `none` if unclaimed. Record suspicious marker-shaped comments from untrusted authors separately.            |
| Forced-handoff evidence  | Approving human, displaced `{claim-id}`, branch, linked PR, evidence URL — only when `forced-handoff: human-gated`. When an open PR exists, require issue-plus-PR approval naming that PR. |
| Open PR and current HEAD | PR number + current HEAD SHA; or `none`.                                                                                                                                                   |
| Activity recency         | Latest `updatedAt` across issue comments, review threads, review bodies, PR comments. Include PR `createdAt`/`updatedAt` when a PR exists.                                                 |
| PR HEAD movement         | Baseline: latest trusted watermark/baseline marker SHA if present, else current PR HEAD. Then confirm whether commits were added after that baseline.                                      |
| CI state                 | Check states for PR HEAD; latest completed `completedAt`; latest successful `completedAt`; or `none`.                                                                                      |
| Worktrees                | `git worktree list` output.                                                                                                                                                                |
| Local branch             | Whether the branch named in the claim comment exists locally.                                                                                                                              |
| Worktree state           | `git status` in worktree (if it exists); otherwise `missing`.                                                                                                                              |
| Unpushed commits         | `git log @{u}..HEAD` in worktree. Treat all commits as unpushed if no upstream is configured.                                                                                              |
| Local HEAD SHA           | `git rev-parse HEAD` in worktree.                                                                                                                                                          |
| Live digest state        | Count of `<!-- idd-live-status: current -->` comments on issue/PR. Do not use digest text to route resume.                                                                                 |

## Step 0 — Route classifier

Evaluate in order; take the first matching row.

| Condition                                                                                 | Route                                                              |
| ----------------------------------------------------------------------------------------- | ------------------------------------------------------------------ |
| Issue closed or PR merged                                                                 | Step 1 (cleanup only)                                              |
| `forced-handoff: human-gated` + valid evidence matching active/inheritable state          | Step 1 forced-handoff path (skip stall check)                      |
| `forced-handoff: human-gated` + evidence exists but mismatches live claim/branch/PR state | STOP — report mismatch; do not claim, push, or mutate review state |
| Non-owned active claim + no valid forced-handoff evidence                                 | `idd-resume-stall.instructions.md`; then Step 1 if unblocked       |
| Otherwise                                                                                 | Step 1                                                             |

Autopilot and unattended agents must never invent, request, or broaden
forced handoff; they may only consume already-recorded human-gated evidence.
Use only externally observable evidence: trusted claim heartbeat timestamps,
PR head movement, remote branch tip movement, review/comment activity, and CI
timestamps.
Quiet-window evidence does not bypass the shared stale threshold.
If stalled-session routing returns hold/inconclusive, stop.

- Conversational or chat-based operator approval given mid-session never
  substitutes for the TTY-gated `idd-force-handoff` helper's own `y/N`
  confirmation — this holds even when the operator explicitly says to
  proceed.
- When an operator asks the agent to proceed with forced handoff, the
  agent's correct action is to report the stalled-claim evidence back,
  never to author or post the `forced-handoff` marker itself. Where the
  repository vends a force-handoff helper, hand the operator a
  concrete, runnable invocation resolved for its configured profile
  from `docs/idd-helper-scripts.md` (for example
  `node scripts/force-handoff.mjs` under `vendored-node`, or
  `npm run idd:force-handoff` under `package-manager`); under
  `instructions-only` (no helper runtime vended), the operator instead
  posts the manual consent text and marker documented in
  `docs/customization.md` themselves.

## Step 1 — Identify claim state

When helper runtime is enabled, you may collect Step 1 evidence with:

```sh
node scripts/resume-claim-routing.mjs --issue {issue-number}
```

Use helper output as evidence mapped to this table, not as an
authoritative replacement:

- `state: already_owned` + `action: keep` → continue with the same
  `{claim-id}` route.
- `state: unclaimed` + `action: re_claim` → no-active-claim route.
- `state: stale` + `action: takeover` → stale-claim takeover route.
- `state: non_inheritable` + `action: stop` → active non-stale claim
  stop route.
- `state: disputed` + `action: stop` → contested-claim stop route.

If helper runtime is absent, helper output is invalid, or helper evidence
disagrees with live GitHub state, use the written table below and treat
it as authoritative.

Evaluate in order; take the first matching row.

| Claim state                                                                                     | Route                                                                                                                         |
| ----------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| Issue closed or PR merged                                                                       | Clean up local worktree and branch; STOP                                                                                      |
| Active claim = this session's verified `{claim-id}` + branch field starts with `roadmap-audit/` | Re-run A1.5; skip worktree creation; STOP after roadmap-side effects. Coordination-only: does not lock child-issue execution. |
| Active claim = this session's verified `{claim-id}`                                             | Continue with same `{claim-id}`; ignore stale FH evidence citing a different displaced `{claim-id}`; → Step 2                 |
| FH evidence names this session's already-verified `{claim-id}`                                  | STOP — current session is displaced; do not push, comment, resolve, request reviewers, or merge                               |
| Forced-handoff recovery confirmed (§FH)                                                         | Re-claim via A5 after GitHub reflects handoff; cite evidence in digest `Authoritative by`; → Step 2                           |
| No new-format claims + legacy `claimed-by` + later trusted `unclaimed-by` (same agent)          | Treat as unclaimed → fresh A5 claim → Step 2                                                                                  |
| No new-format claims + legacy `claimed-by`, age < 24 h                                          | STOP — not inheritable even if agent-id matches                                                                               |
| No new-format claims + legacy `claimed-by`, age ≥ 24 h                                          | Migrate via A5 with `supersedes: none`; → Step 2                                                                              |
| No active claim                                                                                 | Re-claim via A5; → Step 2                                                                                                     |
| Active non-stale claim (< 24 h, other session)                                                  | STOP — not inheritable even if agent-id matches                                                                               |
| Active stale claim (≥ 24 h, other session) + branch field starts with `roadmap-audit/`          | Takeover via A5 with `supersedes: <prior-id>`; then re-run A1.5; STOP after roadmap-side effects                              |
| Active stale claim (≥ 24 h, other session)                                                      | Takeover via A5 with `supersedes: <prior-id>`; → Step 2                                                                       |

All re-claims, migrations, and takeovers must use A5 race-safe verification
from `idd-claim.instructions.md`. Forced-handoff recovery never waives the
normal A5 branch-collision and open-PR safety checks.

A branch left by a stale or released claim is inheritable. An open PR or
remote branch may be reused when it matches the branch in the stale active
claim, the latest released claim, or trusted forced-handoff evidence whose
branch and linked PR fields still match live GitHub state.

After routing, repair a missing or stale digest from the parsed claim state,
PR state, CI state, and review activity when safe under the claim
revalidation gate. See §Digest in `docs/idd-resume-detail.md` for
multi-digest and forced-handoff edge cases. Do not use digest text to route.

## Step 2 — Locate or restore worktree

`{branch}` = branch field from the verified active claim (verbatim; do not
recompute). When creating a worktree, follow the B1 worktree creation
sub-procedure and run **install-deps** as specified there.

| PR exists      | Remote branch | Local state                | Action   |
| -------------- | ------------- | -------------------------- | -------- |
| yes (1 match)  | —             | no worktree                | §W1      |
| yes (1 match)  | —             | rebase in progress         | §W2      |
| yes (1 match)  | —             | dirty, reviews exist       | §W3      |
| yes (1 match)  | —             | dirty, no reviews          | §W4      |
| yes (1 match)  | —             | clean, unpushed            | §W5      |
| yes (1 match)  | —             | clean, no unpushed         | → Step 3 |
| yes (multiple) | —             | —                          | §W6      |
| no             | yes           | —                          | §W7      |
| no             | no            | no worktree, no branch     | → B1     |
| no             | no            | no worktree, branch exists | §W8      |
| no             | no            | dirty                      | → B3     |
| no             | no            | clean, unpushed            | → D1     |
| no             | no            | clean, no unpushed         | → B2     |

Section numbers §W1–§W8 and §FH are detail entries in
`docs/idd-resume-detail.md`.

After routing, refresh the digest only when the route materially changes what
a human should expect next (e.g., `Phase: resume → B3`, `Phase: resume → D1`,
`Phase: resume → F2`). Set `Authoritative by` to the claim, PR/branch, CI,
and review evidence used for the routing decision.

## Step 3 — Determine PR and CI/review state

When helper runtime is enabled, you may collect Step 3 routing evidence
with:

```sh
node scripts/resume-route-selection.mjs --issue {issue-number}
```

Map helper `route` to the Step 3 table outcomes:

- `D1`, `D4`, `E1`, `E15`, `Esync`, `F1`, `F2` → matching row outcome.
- `stop` → stop and report the helper reason; do not mutate state.

Before any mutation after helper-assisted routing, still re-check live
claim ownership, current PR HEAD, and current CI/review state in this
phase's authoritative tables. If helper runtime is absent or helper
output is invalid, use the written table below directly.

| CI state                              | Reviews                                                              | Action                                             |
| ------------------------------------- | -------------------------------------------------------------------- | -------------------------------------------------- |
| Required checks not yet generated     | no reviews                                                           | Wait for generation → D4 logic                     |
| Required checks not yet generated     | reviews exist                                                        | Wait for generation → E15 logic                    |
| `queued` or `in_progress`             | no reviews (first push)                                              | D4 CI (`idd-ci.instructions.md`, on-success → E1)  |
| `queued` or `in_progress`             | reviews exist (post-fix push)                                        | E15 CI (`idd-ci.instructions.md`, on-success → E1) |
| `failure` / `cancelled` / `timed_out` | no reviews                                                           | D4 failure/cancelled branch                        |
| `failure` / `cancelled` / `timed_out` | reviews exist                                                        | E15 failure/cancelled branch                       |
| `success`                             | unresolved threads / unreplied comments / active `CHANGES_REQUESTED` | → E1                                               |
| `success`                             | none of the above; branch clean                                      | → F2                                               |
| `success`                             | none of the above; branch behind (no content conflict)               | → F1 (policy check, then F2 or Esync)              |
| `success`                             | none of the above; branch has content conflict                       | → Esync (E-phase branch-sync check)                |
| `success`                             | none of the above; branch dirty or unknown state                     | → hold/stop                                        |

For forced-handoff recovery on an open PR: treat the final `success` row as
→ E1 until the successor has posted its own same-claim review watermark and
baseline for the current `{claim-id}`. Prior-claim operational markers are
not reusable even when the branch and HEAD are unchanged.
