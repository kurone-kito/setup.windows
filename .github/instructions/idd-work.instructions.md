# IDD — Work and Self-Review Phase (B + C)

Read this file after a successful claim. It covers worktree creation (B1),
planning (B2), implementation (B3), and the self-review loop (C).

---

## B1 — Create worktree (with branch)

Before creating, check for local conflicts in this order:

1. Ensure the local `main` branch is up to date and has no local
   commits. Run this from the primary worktree while on `main`:

   ```sh
   git fetch origin main
   git log origin/main..main --oneline
   ```

   If the second command outputs any lines, local `main` has unpushed
   commits — stop and report, do not force-reset `main`. Otherwise,
   fast-forward to origin:

   ```sh
   git merge --ff-only origin/main
   ```

   After this `main` fast-forward, do **not** change the primary
   worktree's HEAD off `main` for any reason during B1 — see
   Anti-patterns below for the forbidden commands and the allowed
   HEAD-preserving exceptions (read-only inspection, and the
   HEAD-preserving branch/worktree commands used by Steps 2-3 below and
   by Worktree creation).

2. Run `git worktree list` — if a worktree for the branch already
   exists, inspect and acquire its
   [worktree-local claim lock](idd-claim.instructions.md#worktree-local-lock-file-same-machine-collision)
   before reusing or removing it (same helper commands as there); do
   not run `git worktree remove` while the lock check is still a
   collision — resolve it via the Claim-state rule in
   `idd-claim.instructions.md`, and only remove the path once the
   current claim is authorized to take it over. Reusing it keeps the
   acquired lock; removing it means recreating the path and
   re-acquiring the lock before any install or other mutation (removal
   must precede branch deletion — git blocks deleting a checked-out
   branch).

   If `git worktree list --porcelain` marks the entry `prunable` with
   its path already absent, there is no live worktree to protect —
   clean that stale entry with `git worktree remove --force
   <path-from-list>` and continue (the only removal exception before a
   lock check).
3. Run `git branch --list {branch-name}` — if the branch still exists
   locally after step 2, reuse it when inheritable (claim takeover).
   Otherwise (unexpected leftover) delete it: `git branch -d
   {branch-name}`. If deletion is refused (unmerged commits), treat it
   as inheritable and reuse it when a remote branch or open PR exists;
   otherwise post a hold comment and stop for manual cleanup — do not
   force-delete without confirming no remote or PR claim is tied to it.

Then create the worktree below; for a takeover, reuse the exact branch
name from the existing claim comment instead of generating a new one.

### Anti-patterns

The following commands MUST NOT be used to create the implementation
branch in the primary worktree:

- `git switch -c <branch-name>` — switches the primary worktree to
  the issue branch and skips worktree creation entirely.
- `git checkout -b <branch-name>` — equivalent failure mode.
- A standalone `git branch <branch-name>` then in-place commits in the
  primary worktree — defeats the sibling-worktree invariant even though
  `git branch` alone does not move HEAD.

The primary worktree's HEAD MUST remain on `main` throughout B1; if it
ever leaves `main`, stop immediately and follow the B1 self-check
repair path below.

### Worktree creation

**Naming convention**: the worktree directory lives as a sibling of the
repository root. Compute the path as
`../<repo-name>.<normalized-branch>` where `<normalized-branch>` is the
branch name with every `/` replaced by `-`.

Example: repo `{{REPO_NAME}}`, branch `issue/123-add-foo` → worktree path
`../{{REPO_NAME}}.issue-123-add-foo`.

**Step 1 — Check for orphaned path**: if the target path already exists
but is not listed in `git worktree list`, stop and report for manual
cleanup before continuing.

**Step 2 — Create**: use **WorkTrunk** if available. The create verb is
`wt switch --create` (the older `wt new` subcommand was removed):

- macOS/Linux: `wt switch --create -b <base-branch> <branch-name>`
- Windows: `git-wt switch --create -b <base-branch> <branch-name>`, or the
  same `wt switch --create -b <base-branch> <branch-name>` if `git-wt` is
  unavailable

`<base-branch>` is normally `main`. In a **non-interactive / automation**
context, append `-x <noop>` (e.g. `-x true`) — otherwise WorkTrunk tries
to change the caller's directory and can hang; `-x` makes it create, run
the pre-start hook, and exit cleanly.

If WorkTrunk is not available, choose the correct case:

<!-- dprint-ignore-start -->
| Case | Command |
| --- | --- |
| Fresh claim | `git worktree add <path> -b <branch-name> origin/main` |
| Takeover — local branch exists | `git worktree add <path> <branch-name>` |
| Takeover — remote branch only | `git fetch origin && git worktree add <path> -b <branch-name> origin/<branch-name>` |
| Takeover — neither local nor remote (rare) | treat as fresh claim; preserve the inherited branch name |
<!-- dprint-ignore-end -->

For manual `git worktree add`, or WorkTrunk without an install hook,
acquire the [worktree-local lock file](idd-claim.instructions.md#worktree-local-lock-file-same-machine-collision)
immediately after the worktree exists, **before Step 3** —
`install-deps` itself writes into the worktree and runs lifecycle
hooks, so acquiring the lock any later leaves that install unprotected.

WorkTrunk's pre-start hook runs before the create command returns. If it
installs dependencies, its **first** command must acquire the lock for
the new worktree with the current `{agent-id}` / `{claim-id}`, then run
the install — acquiring the lock afterward is too late. Under
`package-manager`, the new worktree's `idd:claim-lock` bin may not exist
yet: invoke a pre-install-available helper from the primary worktree
with the new path as `--worktree`, or use the helper-free fallback
below. If neither is available, skip the automatic install hook and
follow the manual lock-then-install path above.

For `instructions-only` (no helper runtime), use the helper-free
fallback under
[Worktree-local claim lock](../../docs/idd-helper-scripts.md#worktree-local-claim-lock)
before the first mutation; it shares the same `idd-claim.lock`
namespace and F4 removal behavior as above.

**Step 3 — Install deps**: after worktree creation, ensure dependencies
are installed:

- **WorkTrunk with a pre-start install hook** (e.g.,
  `[pre-start].install` in `.config/wt.toml`): The hook must acquire the
  lock before installing, as described above; after the hook succeeds,
  skip this step.
- **Manual `git worktree add` or WorkTrunk without a hook**: `cd` into
  the newly created worktree, then run **install-deps**.

`install-deps` must remain safe to rerun during retries, takeovers, and
recreated worktrees without manual cleanup.

A fresh worktree can report `install-deps` success while a package
manager silently under-installs a dependency binary. If observed, the
`install-deps` command should verify a key post-install artifact and
retry the install exactly once before failing loudly — see the
`verify-install-deps` helper in `docs/idd-helper-scripts.md`. See
[rationale](../../docs/idd-design-rationale.md#b1-step-3--install-deps-silent-under-install-detection).

### B1 self-check

Before continuing to B2, verify all of the following:

- `git -C <primary-worktree-root> rev-parse --abbrev-ref HEAD` returns
  `main`.
- `git worktree list` includes the new sibling worktree path.
- The agent's current working directory is the new sibling worktree
  path, not the primary worktree.

If any check fails, the B1 worktree-creation contract has been
violated: stop, post a hold note describing which check failed, and do
not continue to B2 from the primary worktree. Repair by removing the
misplaced branch (after confirming no work is lost) and recreating the
sibling worktree through the Worktree creation steps above.

## B2 — Create and refine plan

### B2.0 — Supersession re-check (before planning)

A4.5's duplicate/supersession check ran once, at pre-claim triage. A
sibling PR can ship the whole deliverable during the claim→plan gap
under concurrent execution, so re-check once the B1 worktree exists and
**before writing any code or drafting the plan below**, using a
mechanical file/close-based signal stronger than A4.5's title/
declaration heuristic (a weak **title-only** match is **not** a hit
here). Keep it cheap: one fetch plus a bounded merged-PR scan.

1. `git fetch origin main`.
2. **Closed-by-a-merged-PR signal**: re-fetch the issue; if it is now closed
   with a linked closing PR, the deliverable already shipped:

   ```sh
   gh issue view <number> --json state,closedByPullRequestsReferences \
     --jq 'select(.state == "CLOSED") | .closedByPullRequestsReferences[].number'
   ```

3. **Same-target-files signal**: otherwise scan PRs merged **at or after the
   active claim's `created_at`** (a small bounded window) and check whether any
   changed a file the issue scopes under its `## Candidate files`:

   ```sh
   gh pr list --repo <owner>/<repo> --state merged \
     --search "merged:>=<claim-created-at>" --json number,mergedAt --limit 50
   # then, for each candidate, compare its files to the issue's Candidate files:
   gh pr view <n> --json files --jq '.files[].path'
   ```

**On a hit → verify-then-close** (never silent re-implementation, and never an
auto-close on a weak signal): confirm the issue's acceptance criteria already
hold on current `main`, then close the issue with a comment referencing the
superseding PR. If the criteria only **partly** hold, keep the issue open,
record the overlap, and plan only the genuinely-remaining work. On no hit,
continue with the plan below.

### B2.1 — Premise verification (decision-transcription issues)

Apply this check only when **both** hold: the issue's deliverable is to
record or act on an already-recorded human decision, and that decision's
rationale asserts a specific checkable fact about what a prior change
actually shipped. Out of scope for ordinary feature or bugfix issues.

Before drafting the plan, verify the asserted fact against the prior
change's actual shipped code or documentation rather than treating the
decision's rationale as ground truth. If the prior change cannot be
identified, or its shipped state cannot be checked, treat verification
as inconclusive and follow the conflict path below — do not default to
continuing. See
[rationale](../../docs/idd-design-rationale.md#b21--premise-verification-decision-transcription-issues).

**On a genuine conflict or inconclusive verification**: follow the
shared Hold / suspend rules in `idd-overview-appendix.instructions.md`,
and include the primary-source evidence (or the reason verification was
inconclusive) in the hold comment. Do not silently propagate the
unverified premise, and do not unilaterally overwrite the recorded
decision — the correction must land as a maintainer addendum, not a
silent edit. Resume planning only after the addendum is recorded.

On no conflict, continue with the plan below.

Draft an implementation plan and post it as an issue comment, then run
a critique pass for correctness and concreteness (see
`idd-overview-appendix.instructions.md` for per-agent implementation),
and post the refined final plan as a follow-up or update to the same
comment. After the final plan comment is posted and claim ownership is
re-validated, update the issue live status digest: `Phase` is `B2
planned`, `Open blockers` is `none` unless the plan found a blocker,
`Next action` is `B3 implement`, and `Authoritative by` points to the
plan comment and verified claim.

## B3 — Implement

**Plan-comment checkpoint**: before writing any implementation code,
confirm the B2 plan comment already exists on the issue. If it does
not, stop and return to B2. If code was already written before this
checkpoint is noticed, disclose the ordering deviation on the issue,
post the plan retroactively with an explicit note about the
reordering, and run the C1 critique pass against the completed diff.

Implement the plan, running **fix-validate** before each atomic commit
(one logical change per commit).

**De-duplication refactors**: when consolidating a wrapper function used
at multiple call sites, check whether any call site's old delegate path
added behavior (timeouts, stdio handling, error translation, etc.) that
the new shared function does not replicate — not just whether the
function bodies look equivalent. See
[rationale](../../docs/idd-design-rationale.md#b3--de-duplication-refactor-check-for-behavior-parity-not-just-body-equivalence).

**Unexpected validation failures**: a `typecheck`/`lint` failure in a
file this diff did not touch may signal dependency drift or a broken
`main` baseline — verify with a fresh-vs-stale `node_modules` comparison
or a clean **install-deps** rerun before assuming the failure traces to
this diff. See
[rationale](../../docs/idd-design-rationale.md#b3--dependency-drift-vs-own-diff-a-typechecklint-diagnostic).

**Local test flakiness under concurrent load**: a test this diff did
not touch that fails or times out locally, then passes an isolated
re-run while hosted CI for the same push stays green, signals CPU /
resource contention from concurrent sessions, not a defect in this
diff. Re-run once in isolation; if it passes and hosted CI stays green,
trust the hosted result — **authoritative over local validation for
this diagnosis**, though this does not waive the fix-validate /
pre-push-validate requirements above. Otherwise treat it as a real
failure and fix it. See
[rationale](../../docs/idd-design-rationale.md#b3--local-test-flakiness-under-concurrent-load-hosted-ci-is-authoritative).

If B3 or C must stop for a hold, use the shared Hold / suspend rules in
`idd-overview-appendix.instructions.md` and update the issue digest with the
blocking condition before stopping. Do not use the digest as the only
record of unfinished work; material decisions still need issue comments
or commits.

---

## C — Self-Review Loop

### C1 — Critique pass

Run a critique pass on this branch's diff. Ask it to check whether the
implementation is correct, whether the issue's requirements are
satisfied, whether adequate test coverage exists, and whether any other
problems exist. See `idd-overview-appendix.instructions.md` for per-agent
implementation. The distributed defaults for the C-phase skip and loop
guards are listed in `docs/policy-constants.md`.

**Objective diff validation floor**: neither C2 nor C4 below may skip to
`idd-pr-submit.instructions.md` unless **fix-validate** — the same
command set C5 runs — has passed against the branch's current HEAD;
re-run it after every new commit. This floor is independent of D2's own
**pre-push-validate** gate and never substitutes for it, and it applies
**uniformly** regardless of self-classifying as "no-subagent" (see
`docs/idd-workflow.md`'s "Critique pass invocation" section): on a
no-subagent runtime, where critique degrades to same-response
self-critique, the critique verdict is **advisory** and this floor is
**load-bearing** instead. If the floor has not passed, C2 and C4
continue to C5 instead of skipping, even when their other skip
condition is otherwise met.

After each critique loop decision, update the issue digest only if the
next action changes materially: for example, `C accepted fixes` before
C5, `C clean` before moving to PR submission, or a hold state when
guardrails stop the loop.

### C2 — Check for issues

Zero issues reported: skip to `idd-pr-submit.instructions.md` when the
floor (C1) has passed, else continue to C5. One or more issues:
continue to C3 regardless of the floor — C4 applies the floor check
after Accept/Reject scoring.

### C3 — Score issues

For each issue reported, assess severity and relevance to PR intent:

- **High** (safety, correctness, requirement violations, CI stability) →
  **Accept forced**, regardless of PR intent
- **Low** (minor improvements unrelated to PR intent) → **Reject
  recommended**
- **Medium** → judge by context

### C4 — Accept / Reject and loop check

Decide Accept or Reject for each issue. Then check:

- Accept count = 0 **and** the floor (C1) has passed → skip to
  `idd-pr-submit.instructions.md`
- Loop count >
  `critiqueLoop.cPhaseLowSeveritySkipAfter` (distributed default: `3`)
  and all remaining Accepts are Low **and** the floor has passed → skip
  to `idd-pr-submit.instructions.md`

If a bullet's condition holds except the floor, continue to C5 to
satisfy the floor only; the second bullet's remaining Low Accepts stay
unfixed, per the guard.

Otherwise continue to C5.

### C5 — Fix accepted issues

Fix any Accepted issues the guard above does not exempt (there may be
none — see C4). Then run **fix-validate**: a pass from before this
step's own edits does not satisfy the floor, so re-run it now and fix
anything it reports.

An unmet floor is not a new failure class: run or fix **fix-validate**
the same way the Project commands table handles a failing
**pre-push-validate** ("If lint fails, run fix-validate, commit, then
re-run pre-push-validate").

If anything changed, commit atomically.

### C6 — Return to C1

Go back to C1 for the next review pass.
