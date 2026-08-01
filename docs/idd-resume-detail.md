# IDD Resume — Detail Reference

This document provides full narrative for the routing branches and worktree
actions referenced by `idd-resume.instructions.md`. The compact decision
tables in that file are the authoritative runtime contract; this document
provides the detail needed when a branch requires careful judgment.

## §FH — Forced-Handoff Recovery

A forced-handoff recovery path applies when the repository records
`forced-handoff: human-gated` and valid trusted evidence exists for the
selected issue. Collect evidence under the contract in `docs/customization.md`:
record the approving human, old claim ID, branch, linked PR (if any), and
evidence URL.

The recommended operator path for collecting that evidence is the
interactive `idd-force-handoff` helper. It asks for the issue number
first, checks live open PRs on the active claim branch to decide whether
PR input is required, previews the generated successor IDs and marker,
and then requires a final `y/N` confirmation before posting anything to
GitHub. Outside an interactive TTY it must fail closed. The lower-level
`idd-forced-handoff-marker` helper remains available for rendering or
inspection, but it is not the primary maintainer workflow.

**Validity checks** — treat evidence as unusable and do not route
forced-handoff if:

- Any field required by the current approval-note format is missing or
  contradictory.
- An open PR exists and the approval text does not name that PR (an
  issue-only approval is insufficient for PR-scoped recovery).
- The evidence `{claim-id}`, branch, or linked PR does not match the live
  active claim or inheritable released branch/PR state — stop and report
  the mismatch; do not claim, push, or mutate review state.
- The forced-handoff **authorization gate** does not hold. See
  [`idd-claim.instructions.md` rule 7](../.github/instructions/idd-claim.instructions.md#claim-state-parsing)
  for the full criteria — apply it in addition to the checks above; it
  is not restated here.

**Re-claim rule** — Re-claim only after the human-gated handoff mechanism
has already updated the GitHub claim stream to a released or
successor-ready state. If the displaced non-stale claim still remains
active, stop and wait rather than inventing a local superseding claim.
Once GitHub state reflects the handoff outcome, continue via
`idd-claim.instructions.md` on the branch named in the forced-handoff evidence.
The verified `forced-handoff` marker has already set the active claim to its
pre-recorded `new-agent-id` / `new-claim-id` pair (rule 7), so the successor
**adopts both verbatim** as its own `{agent-id}` / `{claim-id}` for the rest
of the run — including `--agent-id` and `--claim-id` at F2/F3's
`pre-merge-readiness` — rather than minting a claim-id or keeping its own
agent-id (an invented agent-id silently fails later checks as
`agent-id-mismatch`; see `idd-claim.instructions.md`'s Claim verification
section). No separate `claimed-by` post is required for the transfer itself.
This adopted claim is **sticky** (re-derived on every resolution pass); see
the same section for the adopt-verbatim vs. release-then-fresh reconciliation
paths if a fresh claim appears not to take effect.

**Displaced-session guard** — If the forced-handoff evidence names a
`{claim-id}` that this current session had already verified before this
routing step, this session is the displaced old session. Stop immediately.
Do not push, comment, reply, resolve threads, request reviewers, or merge
until a maintainer reassigns ownership.

The successor must cite the forced-handoff evidence in its resume report or
digest `Authoritative by`. It must not reuse the displaced old `{claim-id}` as
its own — always use the marker's assigned `new-claim-id`. (`{agent-id}` may
legitimately equal the displaced claim's agent-id; only `{claim-id}` must
always be the fresh marker-assigned value.)

## §W1 — PR exists (1 match), no worktree

Run `git fetch origin` from the primary worktree (this is a
HEAD-preserving command and is safe there). If a local branch named
`{branch}` exists, check for unpushed commits:
`git log origin/{branch}..{branch} --oneline`.

- **Commits appear**: create the sibling worktree from the existing
  local branch using the B1 naming convention:
  `git worktree add <sibling-worktree-path> {branch}`. If reviews
  exist on the PR → resume from E11; if no reviews → D1.
- **No local commits**: reset the branch first from the primary
  worktree (HEAD-preserving):
  `git branch -f {branch} origin/{branch}`, then create the sibling
  worktree: `git worktree add <sibling-worktree-path> {branch}`.

If no local branch named `{branch}` exists, create from remote (still
from the primary worktree, HEAD-preserving): `git branch {branch}
origin/{branch}`, then create the sibling worktree:
`git worktree add <sibling-worktree-path> {branch}`.

`<sibling-worktree-path>` follows the B1 naming convention (sibling
of the repository root, with `/` in branch name replaced by `-`).

Anti-patterns (do not substitute these for the sequence above):

- `git switch -c {branch} origin/{branch}` — moves the primary
  worktree's HEAD to the issue branch and skips worktree creation.
- `git checkout -b {branch} origin/{branch}` — equivalent failure.

See [B1 Anti-patterns](../.github/instructions/idd-work.instructions.md#anti-patterns)
for the full rule.

## §W2 — PR exists (1 match), rebase in progress

Check `.git/rebase-merge` and `.git/rebase-apply` in the worktree. Continue
or abort the rebase as appropriate for the situation. Then route:

- No reviews yet on the PR → D1
- Reviews exist → E11

## §W3 — PR exists (1 match), dirty, reviews exist

Resume from E9 (treat as mid-review-fix): run **fix-validate**, commit
fixes, run **post-fix-validate**, push, then go to Step 3.

## §W4 — PR exists (1 match), dirty, no reviews

Run **fix-validate**, commit any unfinished work. Then re-validate the
claim (D2 step 1): re-read the issue and confirm the active claim still
uses your current `{claim-id}`. If it does not, report and stop. Otherwise
run **pre-push-validate**, push, then wait for CI
(`idd-ci.instructions.md`, D4 on-success → E1).

## §W5 — PR exists (1 match), clean, unpushed

Sync main (D1 rebase) + **pre-push-validate** + push (D2), then go to
Step 3.

## §W6 — PR exists (multiple matches)

Try to match by the claimed/inherited branch name from Step 1. If exactly
one PR matches, treat as "1 match" and use the corresponding §W1–§W5 row.

If zero or still multiple PRs match after the branch filter, re-validate
claim ownership:

- Active claim still uses your current `{claim-id}`: post `unclaimed-by`
  with that `{claim-id}`, report the ambiguity, and abort.
- Claim already lost: report and abort without posting a release.

## §W7 — No PR, remote branch exists

From the primary worktree (HEAD stays on `main`):

1. `git fetch origin {branch}` — fetch the remote tip.
2. `git branch {branch} origin/{branch}` — create the local branch
   without moving primary HEAD.
3. `git worktree add <sibling-worktree-path> {branch}` — create the
   sibling worktree using the B1 naming convention.

Then resume from C1 inside the new worktree. C exits to D1
immediately if the critique pass finds nothing new.

Anti-patterns (do not substitute these for steps 2–3): `git switch -c
{branch} origin/{branch}` or `git checkout -b {branch}
origin/{branch}` — both move the primary worktree's HEAD to the
issue branch and skip worktree creation. See
[B1 Anti-patterns](../.github/instructions/idd-work.instructions.md#anti-patterns)
for the full rule.

## §W8 — No PR, no remote branch, no worktree, local branch exists

Restore the worktree from the local branch. Then route:

- Unpushed commits exist → D1
- No unpushed commits → B2

## §Digest — Digest Repair Guidance

After Step 1 establishes the route and verifies any current-session claim,
repair a missing or stale live status digest from the parsed claim state,
PR state, CI state, and review activity when doing so is safe under the
claim revalidation gate.

**Multiple marked digests** — If multiple comments whose first line is
`<!-- idd-live-status: current -->` exist, preserve them all, report their
URLs, and continue routing from trusted markers and GitHub state rather than
digest text. Do not choose one arbitrarily during an unattended run.

**Stale takeover or legacy migration** — The repaired digest belongs to the
new verified `{claim-id}` only after that claim is active. Include the
superseded or migrated claim marker in `Authoritative by` and do not reuse
prior-claim `review-watermark` or `review-baseline` comments.

**Non-owned, non-stale claim** — Do not edit the digest. Stalled-session
handling records evidence in session logs only unless the claim becomes
yours.

**Forced-handoff on an open PR** — Do not delete, hide, minimize, or
otherwise unmark prior-claim operational markers. They remain audit context
while the successor rebuilds fresh markers under its own `{claim-id}`.
Refresh the digest only after the successor's verified claim is active and
a same-claim watermark has been posted. Live status digests are UI-only
handoff context and do not satisfy review currency, claim ownership,
advisory wait, or CI gates.
