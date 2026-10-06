---
type: reference
title: IDD Resume — Detail Reference
description: Provides the full narrative detail behind idd-resume.instructions.md's compact routing tables for branches that need careful judgment.
tags: [resume, recovery]
---

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
PR input is required, then prompts for an optional successor agent-id
(leaving it blank keeps the displaced agent's own id -- the default --
while entering a value selects that entered agent-id as the successor,
which may still match the displaced agent-id if re-entered verbatim).
It previews the resolved successor IDs and marker, printing a warning
when the resolved successor still matches the displaced agent-id, and
then requires a final `y/N` confirmation before posting anything to
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

**Successor whose clone still holds the predecessor's worktree** — Step 1
of `idd-resume.instructions.md` maps `owner_evidence_required` (reason
`claim-id-match-without-independent-owner-evidence`) to "retry once with
`--worktree`, else stop". For a forced-handoff successor whose clone still
holds the predecessor's worktree `W` for the claimed branch, that stop
persists on every retry: the handoff marker made this session's
`new-claim-id` the active claim, but `W`'s `idd-claim.lock` still names the
displaced claim-id and `W` holds no generated-claim record for the new one.
The stop at `kurone-kito/idd-skill#3597` (2026-09-30) is the observed
instance. Every other `owner_evidence_required` case keeps "stop", except
an `unreadable` occupancy probe caused by an unrelated record, which §LWR's
paragraph on an unrelated worktree record covers. §LWR's steps 1-5 apply to
none of them: they recover a stale or released claim's occupied worktree,
not a live forced-handoff claim. Apply the recipe below only when all of
these hold:

- A routing call that passed this session's `--claim-id` and `--worktree W`
  returned `owner_evidence_required`, and
  `evidence.forced_handoff.new_claim_id` equals this session's claim-id while
  `old_claim_id` does not (the four-flag call below adds `--nonce` and
  `--fresh-claim-gate` once the nonce steps are done). Pass
  `evidence.forced_handoff.new_agent_id` as
  `--agent-id` on the `claim-lock` calls below that take it
  (`--record-tokens` and `--acquire`; `--check` and the routing helper take
  none): it usually equals the displaced agent-id, but a marker may name a
  distinct successor id, and a lock or record written under another
  agent-id leaves routing at `owner_evidence_required` (preventive; no
  observed incident yet).
- `evidence.activation_nonce_winner` is non-null and equals this session's
  nonce, after the nonce steps of `idd-claim.instructions.md` (its
  Activation-nonce format and Claim verification sections: post the nonce,
  wait `claim.verifySettleDelay`, confirm the winner, including the label and
  authoring-hold guard it repeats around that step). A nonce marker that
  is not yet visible looks the same as agreement in a bare
  `owner_evidence_required`, so check the winner again immediately before
  the takeover.
- `fresh_claim_gate.verdict` is `already-claimed`,
  `fresh_claim_gate.winning_claim_id` equals this session's claim-id, and
  the top-level `reason` is not a `released-claim-*` reason; the further
  conditions of the takeover authorization in `docs/idd-helper-scripts.md`
  (claim-lock section) apply.
- `W` comes from `git worktree list --porcelain`: exactly one linked
  worktree for the claimed branch, showing `branch refs/heads/<branch>` and
  neither `prunable` nor `locked`. If no record names the claimed branch
  while routing still says `owner_evidence_required` (a worktree left
  mid-rebase by the dead predecessor lists only `detached`), stop.
  `git -C W symbolic-ref --quiet --short HEAD` must print the branch (that
  is the routing check itself), and none of
  `git -C W rev-parse --git-path rebase-merge`, `rebase-apply`,
  `MERGE_HEAD` or `BISECT_START` may name an existing path (they live in the
  worktree's own git directory, not in `W/.git`, which is a file there). A
  worktree left mid-rebase lets the takeover succeed while routing still
  returns `owner_evidence_required` (preventive; no observed incident yet).
  Merge and dirty state do not change routing and are only a safety check:
  the takeover adopts whatever uncommitted or unpushed work the predecessor
  left, so run the content-scope audit (§CSA) before any of it is pushed.
  Otherwise do not run `--takeover`: report to the operator, and retry Step
  1 after `W` has been cleaned up.
- `claim-lock --check --worktree W` shows a holder (`holder.claimId`) equal
  to `old_claim_id`. If it already shows this session's claim-id and
  agent-id (a takeover done earlier), skip the takeover and only record the
  claim identity; if no lock exists (`present` is false), use the normal
  `--acquire`. Any other holder, including this session's claim-id under
  another agent-id, means stop.

The recommended order (it differed between the sessions that hit the stop;
treat it as recommended, not observed): adopt the marker's agent-id and
claim-id; check the lock holder; record the claim identity against `W`; post
this session's own activation nonce, wait, and confirm the winner; run the
four-flag routing call once and read `fresh_claim_gate.verdict` and
`winning_claim_id`; check the lock holder again; take the lock over; re-run
routing. Run every
`claim-lock` call with `W` as the current directory and with `--worktree W`
(every mode accepts it, and the cwd rule in `docs/idd-helper-scripts.md`
applies), through the profile-selected claim-lock command:

1. `--check --worktree W` and require the holder condition above (the
   holder is `old_claim_id`, this session's own claim-id and agent-id, or
   no lock exists); only then `--record-tokens --worktree W --agent-id
   <new_agent_id> --claim-id <new_claim_id> --nonce <nonce>`. That call
   overwrites the record keyed by the claim-id without a holder check, so
   run before the check it would replace another session's token record.
   The target is `W`, not the primary checkout that
   `idd-claim.instructions.md` names for a fresh claim: recording in the
   primary lets the takeover succeed while routing still returns
   `owner_evidence_required` (preventive; no observed incident yet).
2. Post the nonce, wait, and confirm the winner, then run the routing call.
3. `--check --worktree W` again and branch on the result. A holder equal
   to `old_claim_id`: `--acquire --takeover --worktree W --agent-id
   <new_agent_id> --claim-id <new_claim_id>`, then confirm the output's
   `holder.claimId` equals `old_claim_id`. This session's own claim-id and
   agent-id: skip the takeover. No lock (`present` is false): the normal
   `--acquire` with the same flags, no `--takeover`. Any other holder:
   stop. A displaced predecessor that is somehow still running is
   displaced by definition.
4. Re-run the routing call and expect `already_owned`. If it still returns
   `owner_evidence_required` with `occupancy_probe` `unreadable`, §LWR's
   paragraph on an unrelated worktree record applies.

The trust basis is the human-gated forced-handoff marker, the nonce winner,
and the `--check` run immediately before the takeover. `resume-claim-routing`
and `claim-lock` keep their fail-closed behavior; nothing here changes them.

**Content-scope audit** — Once the successor's post-handoff routing
(Step 2 in `idd-resume.instructions.md`) lands it on §W7 or §W8 with
inherited commits on `{branch}`, run the content-scope audit described
in §CSA before those commits are pushed or bundled into a PR. The
displaced session is by definition unreachable, so its own planning
comment can never substitute for this independent check.

**Inherited plan comment** — The displaced session may also have posted a B2
plan. Where it left no commits, §CSA's committed range is empty, but the
dirty-state note in the recipe above still covers any uncommitted work;
where it left commits, §CSA covers them but not the plan.
`idd-work.instructions.md`'s B3 self-check accepts only the refined,
post-critique plan, and a successor cannot verify that the predecessor's
critique pass ran. On the no-PR route that enters B3 (a dirty worktree) the
successor therefore treats the inherited comment as an unverified draft: it
re-verifies the plan against the issue and the code, runs its own critique
pass, posts a refined plan before entering B3, and adds the refined plan
comment, never the inherited draft, to `Authoritative by` alongside the
evidence §FH and Step 2 require. It never relies on the predecessor's
critique having run. The same holds after an ordinary stale takeover. The
no-PR rows that route to B2 draft their own plan anyway. The routes that
skip both B2 and B3 (a clean worktree with unpushed commits and §W8 with
unpushed commits go to D1, and §W7 resumes from C1) have no B3 self-check
to satisfy, so the successor does not rely on the inherited plan there.
Reported 2026-09-30 in `kurone-kito/dotfiles`
(the round for issue `dotfiles#530`): the successor did this as a judgment
call. Its two failure modes are building on an unreviewed draft and redoing
reviewed work (preventive; no observed incident yet).

## §MC — F4 Cleanup Routing for a Merged or Closed Issue

Applies to Step 1's merged-PR and closed-issue rows in
`idd-resume.instructions.md` (kurone-kito/idd-skill#3319; preventive, no
observed incident yet — a resuming session finding the PR merged while the
prior worker was still running F4 could otherwise remove that worker's
live worktree).

**Displaced-session safety.** The owned row's "claim = this session's
verified `{claim-id}`" condition means a **freshly re-parsed** active
claim per the shared claim-state rules
(`idd-claim.instructions.md`), including rule 7's forced-handoff
transfer: once a valid forced-handoff marker names this session's claim
displaced, the active claim becomes the successor's pair, so the owned
row no longer matches for this session at all — this is the same
"verified" every other claim-matching row in Step 1 already relies on,
not a new exposure. The "FH evidence names this session's
already-verified `{claim-id}`" row — positioned right after the owned and
unowned rows, before the catch-all row — is the explicit backstop against
a stale evaluation, since it checks this session's own recorded
`{claim-id}` against FH evidence directly rather than against whatever
the active claim currently is; it must run before the catch-all so a
displaced session stops silently per §FH's no-mutation rule instead of
reaching the catch-all's hold comment.

**Development-branch resolution.** Both rows resolve `{development-branch}`
the same way B1's Worktree creation Step 2 does — re-resolve it here if
entered directly (for example, on resume) without a fresh B1 pass, the same
caveat this document's §CSA section and `idd-pr-submit.instructions.md`'s
D1 use for the same variable.

**Sanctioned direct F4 entry.** The opening entry condition in
[`idd-merge.instructions.md`](../.github/instructions/idd-merge.instructions.md)
describes the common F3-first path, where merge-handoff's job is deciding
whether _this_ session may execute the merge under the repository's
recorded policy (`fully_autonomous_merge` / `human_merge` /
`separate_merge_agent`). Both rows here enter F4 directly, never F3, and
only once the PR is already merged — the decision merge-handoff exists to
make is already resolved by then, so there is nothing left for it to route.
This is the sanctioned exception these two rows establish, not a bypass of
a still-open decision.

**Ownership condition.** The owned row (active claim = this session's
verified `{claim-id}`) runs the full `idd-merge.instructions.md` F4
contract (steps 4-7, plus step 1 when `{development-branch}` is not the
default branch and a closing-set issue is still open) because this session
can satisfy F4's own claim-revalidation gate at each mutation. On this row,
`{branch}` is the active claim's own `branch:` field — the same binding
Step 2 uses, available here without waiting for Step 2 because the claim
is already verified. This is also
what makes F4's own `primary-worktree-dirty` hold's resume instruction
(re-run step 4 through step 7 once the hold clears) reachable from Resume
for the first time — previously nothing routed a resuming session back
into F4 at all. The unowned row applies only when **no claim is currently active**
and the issue's most recent claim was released (never a claim that was
never made — see below); a live competing claim (even mid-F4 itself) still
falls to the catch-all row, not this one. It binds `{branch}` to that
released claim's own branch, since Step 2's usual binding rule (`{branch}`
= the verified _active_ claim's branch) has nothing to bind to on this
row. It runs
local-only steps: F4 step 4 (fast-forward `{development-branch}`) and step
5's `git branch -d` bullet. It skips step 5's `git worktree remove`
(nothing local to remove — see the worktree condition below), step 6
(remote branch deletion needs the same authority as a held claim), and step
7 (its revalidation gate stops on any claim that is not this session's,
including none). On this row, step 4's own `primary-worktree-dirty` guard
still applies, but degrades to a plain hold comment rather than F4's usual
Hold / suspend: there is no held claim on this row to suspend. All three
of F4's newer holds (kurone-kito/idd-skill#3327) —
`development-branch-in-use`, `development-branch-diverged` (both step 4),
and `local-branch-unmerged-commits` (step 5) — degrade the same way: each
assumes the owned row's held claim and later steps (naming that claim,
"keep claim", "stop before step 7"), none of which this row has. Post a
plain hold comment describing the branch/worktree state instead and stop;
do not treat any of their wording as an instruction to claim the issue.
A merged PR
whose issue was **never claimed at all** has no released-claim branch to
bind and nothing local to clean up — it falls to the catch-all row below,
not this one.

**Worktree condition.** "No local worktree matches `{branch}`" means
`git worktree list` reports no entry for that branch at all — a plain
absence check, not the A5(e) collision scan's occupied/unreadable/absent
classification. A worktree that does exist for `{branch}` while the claim
is released falls to the catch-all row instead: without a held claim to
revalidate against, this session cannot tell whether that worktree is
safely idle or another session's live workspace, so it holds rather than
guesses.

**Closed-with-no-PR and catch-all rows.** Closing an issue without a
merging PR leaves nothing for F4 to reconcile, so this row holds instead.
The catch-all row covers every other closed/merged combination (a live
competing claim, an unverified worktree state, forced-handoff evidence
naming this session as displaced, or a merged PR whose issue was never
claimed at all) the same way: each needs a human or a future resume pass
with better evidence, never a mechanical removal.

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
  Then go to Step 3.

If no local branch named `{branch}` exists, create from remote (still
from the primary worktree, HEAD-preserving): `git branch {branch}
origin/{branch}`, then create the sibling worktree:
`git worktree add <sibling-worktree-path> {branch}`. Then go to Step 3.

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

1. Fetch the remote tip with a fully-qualified destination refspec --
   unlike a bare `git fetch origin {branch}`, this does not depend on
   the clone's configured fetch refspec to refresh
   `refs/remotes/origin/{branch}`:

   ```sh
   git fetch origin +refs/heads/{branch}:refs/remotes/origin/{branch}
   ```

2. `git branch {branch} origin/{branch}` — create the local branch
   without moving primary HEAD.
3. `git worktree add <sibling-worktree-path> {branch}` — create the
   sibling worktree using the B1 naming convention.

Before resuming, run the content-scope audit (§CSA, below) against
`{branch}` — nothing on it has been through a PR yet. Then resume from
C1 inside the new worktree. C exits to D1 immediately if the critique
pass finds nothing new.

Anti-patterns (do not substitute these for steps 2–3): `git switch -c
{branch} origin/{branch}` or `git checkout -b {branch}
origin/{branch}` — both move the primary worktree's HEAD to the
issue branch and skip worktree creation. See
[B1 Anti-patterns](../.github/instructions/idd-work.instructions.md#anti-patterns)
for the full rule.

## §W8 — No PR, no remote branch, no worktree, local branch exists

Restore the worktree from the local branch. Then route:

- Unpushed commits exist → run the content-scope audit (§CSA, below)
  against `{branch}`, then D1.
- No unpushed commits → B2 (no inherited commit content to audit).

## §CSA — Content-Scope Audit for Inherited Commits

Applies wherever §W7 or §W8 resumes work from commit(s) this session
itself did not just author on `{branch}` — including after §FH routes
there via forced-handoff recovery — whether recovering its own crashed
prior turn or taking over from a different, possibly-dead session.
Neither case has a live author left to confirm what was actually
verified, so before any of these commits get pushed or bundled into a
PR, the resuming session must independently audit their content
against the target issue's own declared scope (observed 2026-09-21 on
an adopter repository, reported via kurone-kito/idd-skill#3166: an
inherited unpushed commit correctly implemented an issue's declared
requirements but also silently bundled in a third, undeclared feature,
justified only by the dead session's own stale, unverifiable
"maintainer-authorized" planning comment).

**Diff range**: `{branch}`'s full range against `{development-branch}`,
not merely commits unpushed relative to `{branch}`'s own remote tip —
§W7 creates the local branch directly from `origin/{branch}`, so a
same-branch unpushed-only diff is empty by construction there even
though nothing on that branch has been through a PR yet.
`{development-branch}` is the value resolved in
[B1's Worktree creation](../.github/instructions/idd-work.instructions.md#worktree-creation)
step — re-resolve it here if this file is entered directly (for
example, on resume) without a fresh B1 pass, the same caveat
`idd-pr-submit.instructions.md`'s D1 uses for the same variable. For
example:

```sh
git fetch origin +refs/heads/{development-branch}:refs/remotes/origin/{development-branch}
git diff origin/{development-branch}...{branch}
```

**Audit**: diff that range against the issue's own `## Proposed
change`, `## Acceptance criteria`, and `## Candidate files` sections.
Treat any change that does not trace to a declared requirement the same
way a fresh implementation would treat unrequested scope: flag it for
removal, or require an explicit, evidenced justification recorded on
the issue — never accept a stale planning comment's own self-asserted
authorization as sufficient by itself. This is a diff review, not a new
gate or helper.

This audits for scope _creep_; it does not replace C1's own critique
pass, which verifies declared requirements are _met_ — the two checks
are complementary, and §W7 still resumes from C1 after this audit.

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

## §LWR — Local Worktree Recovery

A local worktree matching a stale or released claim's branch counts as occupied
(observed 2026-09-19, `kurone-kito/idd-skill#3141`): a matching live worktree
could still hold a same-host session's uncommitted work, so Resume and Claim
stop, and Discover marks the candidate ineligible, rather than assume the
claim is abandoned. In a shared-clone
setup this stop has no defined recovery when the worktree's own session
actually crashed, so its issue can never reach the normal stale takeover. This
section defines that recovery. Step 2 (below) is operator-run, never
automated, and checks no process-liveness signal —
`src/scripts/claim-lock.mts`'s header records why:
this "deliberately excludes any local liveness signal (e.g. process PID)... the
process invoking this CLI is a one-shot child that exits the moment the call
returns, so a recorded PID would be a tombstone before any competing session
could ever observe it as 'alive'".

**Primary path: the `local-worktree-recovery` helper** (kurone-kito/idd-skill#3536)
consolidates steps 1, 3, and 4 below into a single invocation, composed from
the `resume-claim-routing`, `claim-lock`, and `clone-lock` building-block
helpers rather than reimplementing their logic — see
[Local worktree recovery](idd-helper-scripts.md#local-worktree-recovery) for
the full CLI surface and invocation forms per `helperRuntime.profile`. It
never checks step 2 mechanically either: `--operator-confirmed-no-live-session`
is your own explicit attestation for that step, required before any mutation,
regardless of `--apply` or what step 1 finds. Default mode is dry-run (no
mutation); pass `--apply` once you have independently performed step 2 and
reviewed the dry-run's reported plan. The written procedure below remains the
canonical spec this helper's own behavior must match, the authoritative
fallback for an `instructions-only` profile, and the reference for any step
the helper's dry-run output doesn't make self-explanatory.

**An unrelated worktree record.** Resume Step 1 routes only a forced-handoff
successor to §FH, so any other session stops on `owner_evidence_required`
and reports the failed proof; an operator may then apply this paragraph, and
for either trigger below an operator confirms every action. It is the only
part of §LWR that applies to an `owner_evidence_required`
verdict, and it also covers a `local_worktree_occupied` result whose
top-level `reason` ends `-local-worktree-unreadable` when `paths` names a
record that is not the claimed branch's own. Steps 1-5 below recover the
claimed branch's own record. The triggers differ by verdict:

- `owner_evidence_required`: `evidence.owner_evidence.occupancy_probe` is
  `unreadable` (the `warnings[]` line reads `owner evidence required: first
  failed proof is occupancy_probe (unreadable)`) although the proofs before
  it hold, that is `worktree_identity`, `claim_lock_matches`,
  `generated_tokens_match` and `agent_and_branch_match` are all `true`.
- `local_worktree_occupied`: the top-level `reason` ends
  `-local-worktree-unreadable` (the `warnings[]` line reads `cannot verify
  local worktree occupancy for <stale|released> branch <branch>: ...`) and
  `evidence.local_worktree.paths` names a record other than the claimed
  branch's own.

The probe reads every record in `git worktree list --porcelain`, not only
the claimed branch's, and a record it cannot classify makes it fail closed
for any branch. `evidence.local_worktree.paths` names the record to look
at; when it is empty the listing failed or could not be parsed, so read
`evidence.local_worktree.reason` instead. A record the probe could not
resolve to the claimed branch (the shapes below) is never preserved or
removed by steps 1-5. After clearing a record, re-run the routing call
that stopped. For empty `paths`, or a shape not listed below, no bullet
applies: stop and report. Reported 2026-09-30 by the `kurone-kito/dotfiles`
adopter (the round for issues `dotfiles#533` and `dotfiles#534`): about 45
minutes until a peer's scratch worktree record disappeared, on a pin that
predates the fix for issue `kurone-kito/idd-skill#3205` (PR
`kurone-kito/idd-skill#3206`), so that record may have been the plain
detached case that fix covers rather than one of the shapes below. Every
shape below, except an unmounted volume, was replayed on git 2.53.0
against an unrelated branch, and none has an observed incident of its own
(preventive; no observed incident yet):

- A detached record whose directory was removed with `rm -rf` reads
  `unreadable`, and `git worktree list --porcelain` flags it `prunable`.
  git prints that same line for a deleted directory, an unmounted volume,
  a directory moved by hand and a directory whose `.git` file is gone. Act
  only when the operator confirms the directory was deleted and `test ! -e
  <path>` holds; repair a moved worktree with `git worktree repair
  <new-path>`, never remove it. Otherwise stop and report. If both hold, point a
  backup ref at the listing's `HEAD <sha>` (`git update-ref
  refs/idd-lwr/unrelated-<sha> <sha>`) and confirm that `git rev-parse
  --verify refs/idd-lwr/unrelated-<sha>` prints the same `<sha>`; key the
  ref by the commit, because an admin id can be reused and a second
  `update-ref` on the same name silently replaces the first backup. A
  detached tip may be kept only by that record, and removal leaves the
  commit unreferenced, so `git gc` may delete it later. Leave the ref in
  place and report it. Last, run `git worktree remove --force <path>`,
  behind the clone-scoped lock when workers share the clone, as B1 does;
  once the lock is held, re-run the routing call and `test ! -e <path>`,
  and remove only if the same conditions still hold. Do not use a plain
  `git worktree prune` here: it is clone-wide, so it also clears other gone
  detached records before they have a backup ref, and it removes the admin
  directory of a record whose `.git` file is gone.
- The same record, locked, also reads `unreadable` but is not flagged
  `prunable`, and a plain prune leaves it. Read its `locked <reason>` line.
  Unlock it (`git worktree unlock <path>`) only when the operator
  confirms the directory was deleted and `test ! -e <path>` holds. The
  reason is free text written by whoever locked it, so it is evidence for
  that confirmation, not a substitute for it, and a reason such as "on
  removable media" means stop and report. Once unlocked it is an ordinary
  gone record, the previous bullet. `git worktree remove --force` alone
  fails on a locked record and needs `--force` twice, but that bypasses the
  unlock rule; the rule above still decides.
- A foreign detached worktree in the middle of a rebase, a `git am` or a
  bisect reads `unreadable` when that work was started from a detached
  HEAD. A rebase's `head-name` is the literal `detached HEAD`, a `git am`
  has no `head-name` at all, and a bisect's `BISECT_START` is a bare
  commit id, so none of them names a branch. Only its owner clears it, by
  finishing or aborting that work (`git rebase --abort`, `git am --abort`,
  `git bisect reset`), never this session; otherwise stop and report the
  path to the operator.
- A clean detached record, a locked clean detached record, a record on a
  named branch whose directory is gone, a rebase in progress on a named
  branch, and a cherry-pick or merge conflict all read `absent`. They are
  not the cause.

1. **Confirm the block.** Run the profile-selected `resume-claim-routing`
   helper (`docs/idd-helper-scripts.md`; source-repo/vendored-node: `node
   scripts/resume-claim-routing.mjs --issue <n>`); a
   `local_worktree_occupied` result reports
   `evidence.local_worktree.paths` and a top-level `reason`
   starting `stale-claim-...` or `released-claim-...`. Under a reason ending
   `-local-worktree-occupied`, `<path>` is the claimed branch's own record,
   even when `git worktree list --porcelain` shows it `detached` in the
   middle of a rebase or bisect (step 3 handles that). Under a reason
   ending `-local-worktree-unreadable`, go on only through the prunable
   skip-ahead below, which needs a record that shows `branch
   refs/heads/<branch>`, is flagged `prunable`, is unlocked, and whose
   `<path>` is absent on disk; every other `-local-worktree-unreadable`
   result is the unrelated-record paragraph's case and stops here. If
   `<path>` no longer exists on disk (a prunable record), skip to `git
   worktree remove --force <path-from-list>`, behind the clone-scoped lock
   when workers share the clone (re-run the routing call and re-check that
   `<path>` is still absent once the lock is held) — mirroring B1's own
   same-shape recovery rule for a prunable entry
   (`idd-work.instructions.md`). Steps 3-4 have nothing to preserve or
   remove here. Keep that command rather than a
   plain `git worktree prune`: prune is clone-wide (replayed on git 2.53.0,
   one prune cleared an unrelated record together with the claimed
   branch's own), though it does remove an unlocked prunable record at
   once. The 3-month expiry belongs to `gc.worktreePruneExpire`, which only
   `git gc` applies. A locked record is never flagged `prunable`, so this
   skip-ahead does not reach it; unlocking it is the operator's call, and
   once unlocked it is prunable and the skip-ahead applies. Otherwise (a
   `-local-worktree-occupied` reason) run the profile-selected
   `claim-lock` helper's check form (source-repo/vendored-node: `node
   scripts/claim-lock.mjs --check --worktree <path>`) to read which
   claim-id holds the lock. Proceed only when that claim-id matches the
   stale or released claim being recovered, or the lock is absent (a
   legacy pre-claim-id release). Stop for every other outcome — a
   different claim-id (a live session may still own it), or a malformed
   or unreadable lock — unless a separately authorized owner-resume or
   forced-handoff path applies.
2. **Rule out a live session.** Outside the helpers, independently
   confirm no session is still working in the worktree — the helpers
   never check process liveness (see the citation above).
3. **Preserve.** When `<path>` is a linked worktree, run this step and
   step 4 from the **surviving primary worktree**, never from `<path>`
   itself — the same cwd rule F4 uses for its own removal
   (`idd-merge.instructions.md`), since a shell inside `<path>`
   becomes invalid the moment it's removed. When `<path>` is itself
   the primary worktree (step 4's own primary-worktree branch below),
   there is no other primary worktree to run from — run both steps'
   commands from `<path>` instead; neither step removes the primary
   worktree itself, only checks out a different branch there, so the
   shell stays valid throughout. Check for
   an in-progress rebase, merge,
   cherry-pick, or bisect using git state, not a literal `.git/...`
   path — `.git` at a linked worktree's root is a file, not a
   directory, so a hardcoded path check silently never matches: `git
   -C <path> rev-parse -q --verify MERGE_HEAD` (merge), `test -d
   "$(git -C <path> rev-parse --git-path rebase-merge)"` or
   `rebase-apply` (rebase), `git -C <path> rev-parse -q --verify
   CHERRY_PICK_HEAD` (cherry-pick), or `test -f "$(git -C <path>
   rev-parse --git-path BISECT_LOG)"` (bisect) — `rev-parse
   --git-path` alone only prints the path, the same reason the rebase
   check above already wraps its own `--git-path` result in `test -d`.
   Any match means back up the
   pre-operation branch tip before continuing — this recovery
   abandons the interrupted operation itself rather than resuming it.
   For an in-progress rebase specifically, `HEAD` is the in-progress
   replay tip, not the pre-operation tip: read the pre-operation tip
   from `$(git -C <path> rev-parse --git-path rebase-merge)/orig-head`
   or `rebase-apply/orig-head` (whichever the detection above matched)
   instead.

   Before the first step-3 mutation, acquire the
   [clone-scoped lock](idd-helper-scripts.md#clone-scoped-lock) for the
   shared primary clone and keep it held through all preservation and step-4
   removal commands. In a helper-enabled profile, the
   `local-worktree-recovery` helper does this in-process. In an
   `instructions-only` profile, wrap the step-3 and step-4 command sequence
   in the profile-selected `clone-lock --exec -- ...` form; do not release the
   lock between preservation and removal. This prevents a stale same-claim
   session from reacquiring its worktree lock while preservation is still in
   progress (Codex review, PR `#3550`, comment `#4116882321`). Stop if the
   clone-scoped lock cannot be acquired.

   Inspect `<path>` the way F4's own removal step already does, not
   just its superproject status — a submodule's own uncommitted or
   unpushed work is otherwise invisible here
   (`idd-merge.instructions.md`); tag-only detached history is not
   counted, but local refs are:
   See issue `#3540` for the observed upstream-tag incident.

   - `git -C <path> status --porcelain --ignored --untracked-files=normal`
   - `git -C <path> log @{u}..HEAD` (or all commits when there is no
     upstream) for this worktree's own unpushed commits
   - `git -C <path> submodule status --recursive`
   - Probe:

     ```sh
     git -C <path> submodule foreach --recursive 'git status
     --porcelain --ignored --untracked-files=normal; git stash list; git rev-list --exclude=refs/tags/\* --glob=refs/\* --count --not --remotes || exit; git symbolic-ref -q HEAD >/dev/null || git rev-list HEAD --not --remotes --tags --count'
     ```

   Let `<tag>` be `idd-lwr <claim-id>`, or `idd-lwr legacy` when step 1
   found no lock (the legacy pre-claim-id release case has no
   `<claim-id>` to tag with). Record the pre-step count of `git -C
   <path> stash list` entries already carrying `<tag>` (normally `0`,
   but a stale one can survive an earlier interrupted attempt at this
   same recovery) as the baseline. When
   the top-level status shows a line not prefixed `!!` (a tracked or
   untracked change — `--ignored` always lists ignored paths too, e.g.
   `node_modules/`, so their presence alone is not a signal to stash),
   save it with `git -C <path> stash push --include-untracked -m
   "<tag>"`, and do the same inside every submodule whose own status
   showed a tracked or untracked change. A submodule `submodule
   status` reports `-` (uninitialized) is not a git repository at
   all — `submodule foreach` never visits it and no `git -C` command
   works there, so F4 treats its contents as plain filesystem
   leftovers, not a repo: copy any files under that path to a
   location outside `<path>` directly (e.g. `cp -r`), and verify that
   copy landed instead of a stash entry. The tag distinguishes this
   recovery's own entries from a sibling worktree's (`stash` is
   repository-wide), and the baseline count distinguishes a fresh
   success from a stale leftover on a retried attempt. Stash entries
   live in the shared repository, not the worktree's own private
   admin directory, so they survive step 4's removal. If `stash push`
   instead fails on unmerged paths the backed-up operation left
   behind, fail closed: copy the conflicted files out to a path
   outside `<path>` — mirroring F4's own "copy other work to a
   different ref or path" rule — rather than treating the branch-tip
   backup alone as sufficient preservation. Preserve unpushed commits
   — this worktree's own and every submodule's — on a backup ref:
   record the intended tip first (`git -C <path> rev-parse HEAD`, or
   the pre-operation tip captured above for an in-progress rebase),
   then `git -C <path> update-ref refs/idd-lwr/<branch> <that-sha>`
   (or the same scoped to a submodule's own path), or a bundle,
   instead of pushing them to the issue branch. A stale
   `refs/idd-lwr/<branch>` left by an earlier interrupted attempt at
   this same recovery can otherwise satisfy step 4's existence check
   even when this attempt's own `update-ref` never ran — recording
   and later comparing the OID closes that gap the same way the
   stash `<tag>` closes it for stash entries. `--include-untracked` does not
   stash ignored files, so
   copy those out separately too: secrets (e.g. `.env`) — never
   commit or push them — and any other non-reproducible ignored data.
   A worktree (and every submodule) with no tracked or untracked
   change has nothing to stash: `stash push` reports no local changes
   to save and creates no new entry, so step 4 skips the stash check
   for it.
4. **Remove.** Keep the clone-scoped lock acquired before step 3 held through
   either branch's fresh claim/lock re-check and the mutation that follows —
   the checkout on the
   primary-worktree branch, or `git worktree remove` on the ordinary
   linked-worktree branch. Do not release the lock after preservation and
   reacquire it here: a concurrent session can acquire or replace
   `idd-claim.lock` during that gap, so the preserved snapshot would be
   stale. The lock serializes
   `worktree add`/`remove` and `fetch` against the shared primary
   clone (`src/scripts/clone-lock.mts`'s own documented scope), while also
   keeping the preservation and removal sequence one exclusion window.

   While that lock is already held — not step 1's earlier read —
   re-run the confirm-the-block check, using the same
   profile-selected `resume-claim-routing` and `claim-lock` helper
   forms step 1 above resolves (a bare `resume-claim-routing.mjs`
   invocation is not portable outside the source-repo/vendored-node
   profile). This is the fresh re-check for the ordinary
   linked-worktree branch: it runs only after the lock is held, not
   only before `git worktree remove`. Stop if the result no longer
   matches: a live session resumed the claim, a different claim-id
   now holds the lock, or the branch no longer reports
   `local_worktree_occupied` — the situation changed since step 1,
   and `idd-merge.instructions.md`'s own F4 worktree-removal step
   revalidates the claim and lock before every removal for the same
   reason. Then confirm each step 3 action actually succeeded — the
   `<tag>` entry count in `git -C <path> stash list` (and each
   submodule's) rose by exactly one past the baseline only where
   step 3 found a change to stash, any unmerged-path fallback copy
   landed outside `<path>`, any `-` submodule's copied files landed
   outside `<path>`, `git -C <path> rev-parse --verify
   refs/idd-lwr/<branch>` resolves **to the recorded tip OID** — not
   merely that it resolves at all, which a stale ref could also
   satisfy — (or the submodule-scoped equivalent) only where step 3
   found unpushed commits to back up, and any copied-out ignored
   files landed outside the worktree — before removing anything.
   For a linked worktree, top-level local-only refs also require copying
   its private worktree git-admin directory before removal; a deinitialized
   submodule's private admin data is preserved under the same rule when it
   contains relevant stashes, local-only refs, or an interrupted operation.
   Symlink targets inside any soon-to-be-removed source are materialized in
   the backup, and special files fail closed instead of being copied as
   regular files. These are preventive safeguards; no observed incident
   yet. Stop and do not run `git worktree remove`, `--force` included, if
   any of them failed.

   If `<path>` is the primary worktree — the path the first `worktree`
   line of `git worktree list --porcelain` reports, distinct from
   every subsequent linked-worktree stanza — `git worktree remove`
   cannot remove it, and its admin directory is shared by every
   concurrent session in the same clone and is never cleaned up by
   removal (`src/scripts/claim-lock.mts`'s own documented scope). This
   is typically the anti-pattern §W7 warns against (checking out the
   issue branch directly in the primary worktree instead of adding a
   linked one). The clone-scoped lock is already held, so this
   branch's fresh `claim-lock` re-check runs only after that
   acquisition, not before it and not only before the checkout.
   Re-run step 1's profile-selected `claim-lock` check form on the
   primary worktree now, immediately before acting — not step 1's
   earlier read, which is stale once a concurrent session could have
   replaced this shared admin directory's lock during the wait to
   acquire the clone-scoped lock. Hold the lock through the final
   lock check and deletion. A concurrent session can use the shared
   primary clone's topology at any point between the checkout and
   the deletion otherwise. Only if that fresh check still matches
   this primary worktree's lock to the claim-id being recovered, or
   — for a legacy release — still finds no lock at all (matching
   step 1's own absent-lock finding): clear any interrupted operation
   (`rebase --quit`, `merge --abort`, `cherry-pick --abort`, or
   `bisect reset`), then run `git -C <path> checkout
   {development-branch}` there to release the branch and retry the
   confirmed-absent routing check up to three total observations — re-resolve
   `{development-branch}` per §CSA's note above if this file is
   entered without a fresh B1 pass — confirm `resume-claim-routing.mjs`
   now reports this branch's `evidence.local_worktree.status` as
   `absent`, then, only when that fresh check found a lock, remove
   that one lock file (`rm "$(git -C <path>
   rev-parse --absolute-git-dir)/idd-claim.lock"`) — the same deletion
   `git worktree remove` performs for a linked worktree, done by hand
   here since removal itself isn't possible — before releasing the
   lock and continuing to step 5. Otherwise (a different holder, or a
   lock that now exists where step 1 found none) stop; the situation
   changed again. Leave the
   generated-tokens record: it is keyed per claim-id, not per branch,
   and `claim-lock.mts` already documents it as never expected to be
   cleaned up.

   Otherwise the same lock is already held, and the confirm-the-block
   re-check above already ran while holding it. Run `git worktree
   remove <path>`, then `git worktree prune` — as F4's own step 5
   (`idd-merge.instructions.md`). If it fails with `fatal: working
   trees containing submodules cannot be moved or removed`, retry
   `git worktree remove --force <path>` after confirming step 3's
   preservation already succeeded — the other allowed case is a dirty
   removal failure after a fresh, complete unmerged-path fallback copy;
   generic dirty-removal failures remain a hold. This also deletes
   that worktree's claim lock and generated-tokens record, since both
   live in its own private git-admin directory.
5. **Re-enter.** Re-run Resume from Step 0. A now-`absent` worktree
   lets a stale claim take the normal stale-takeover path through A5,
   and a released claim take a fresh A5 claim. Route any preserved
   commits through §CSA.

**Wake condition.** Every stop on `local_worktree_occupied` (Resume
Step 1, `idd-resume-stall.instructions.md` S3/S4, the lite equivalents,
and Claim pre-check (e)) records this in the session's own stop report
or log — never as an issue/PR comment on a non-owned claim:

- the branch;
- the worktree path(s);
- the probe status (`occupied`/`unreadable`/`unknown`);
- the blocking claim-id and its latest valid `claimed-by` time, or
  `none` for a legacy pre-claim-id release (`docs/idd-helper-scripts.md`);
- the checkable invariant: `resume-claim-routing` reports
  `evidence.local_worktree.status: absent` for this branch (after this
  section's steps), or a newer valid heartbeat for the blocking
  claim-id appears. Either observation only means re-enter Resume
  Step 0 (step 5); a fresh heartbeat lands on the active non-stale
  claim stop there, never on a takeover.
