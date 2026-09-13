# IDD — Work and Self-Review Phase (B + C)

Read this file after a successful claim. It covers worktree creation (B1),
planning (B2), implementation (B3), and the self-review loop (C).

If this agent is running as a delegated worker under the
[orchestrator fan-out variant](../../docs/idd-workflow.md#orchestrator-fan-out-variant),
the same
[wake-up discipline](idd-ci.instructions.md#wake-up-discipline)
topology-safety condition applies throughout B through F4: never end a
turn assuming an unconfirmed background wait resumes it, even when the
delegation brief itself already restates the warning -- wait
synchronously or with a confirmed topology-safe wake for any
backgrounded command, and confirm the result before ending the turn.

---

## B1 — Create worktree (with branch)

Before creating, check for local conflicts in this order. Concurrent
workers sharing one clone: serialize every `git fetch`/`merge --ff-only`/
worktree add/remove call against the shared clone -- here, and at F4
cleanup's own worktree removal -- behind the
[clone-scoped lock](../../docs/idd-helper-scripts.md#clone-scoped-lock)
(see the [fan-out variant](../../docs/idd-workflow.md#orchestrator-fan-out-variant)
for when this applies).

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

Example: repo `setup.windows`, branch `issue/123-add-foo` → path
`../setup.windows.issue-123-add-foo`.

**Harness-native worktree tools**: an agent harness's own worktree
primitive (e.g. Claude Code's `EnterWorktree`) is a third path outside
the two enumerated below. Use one only when both its target directory
can be pinned to the sibling path above and its branch to
`issue/<number>-<slug>` — never a tool-chosen default. `EnterWorktree`
always places the worktree under a harness-owned directory
(`.claude/worktrees/agent-<hash>`), never the sibling path — never use
it here. Grok Build's `grok --worktree`, subagent `isolation:
worktree`, and `x.ai/git/worktree/*` likewise can't pin either — never
use them (same class as #1930). When a tool can't pin both, use
`git worktree add` below (or WorkTrunk) instead.

**Step 1 — Check for orphaned path**: if the target path already exists
but is not listed in `git worktree list`, stop and report for manual
cleanup before continuing.

**Step 2 — Create**: `<base-branch>` below is `{development-branch}` —
resolve it first: read `developmentBranch` from
`.github/idd/config.json`, else `gh repo view --json
defaultBranchRef --jq .defaultBranchRef.name`; validate the result
([defaults](../../docs/policy-constants.md#branch-synchronization-defaults)),
fail closed if invalid/absent on `origin`, never fall back. Then
`git fetch origin {development-branch}` (may be missing/stale
otherwise). Use **WorkTrunk** if available (create verb:
`wt switch --create`; `wt new` was removed):

- macOS/Linux: `wt switch --create -b <base-branch> <branch-name>`
- Windows: `git-wt switch --create -b <base-branch> <branch-name>`, or the
  same `wt switch --create -b <base-branch> <branch-name>` if `git-wt` is
  unavailable

Non-interactive/automation: append `-x <noop>` (e.g. `-x true`) so
WorkTrunk creates, runs the pre-start hook, and exits without
changing the caller's directory.

**Pre-start hook approval hang** (confirmed live 2026-09-09, issue
`#2797`): even with `-x <noop>`, `wt switch --create` still hangs
non-interactively when the `[pre-start]` hook's own install command has
not already been approved — WorkTrunk's own `approvals.toml` mechanism
prompts for command approval on first run and fails outright outside a
TTY, with `Cannot prompt for approval in non-interactive environment. To
skip prompts in CI/CD, add --yes`. Before the first `wt switch --create`
in such an environment, run `wt config approvals add --yes` once from
the primary worktree to pre-approve the project's hook and alias
commands (stored in `~/.config/worktrunk/approvals.toml`, scoped to the
git project so the approval carries over to every sibling worktree).
This one-time pre-approval step is narrower than adding the global
`-y`/`--yes` flag to every `wt switch` call, which would also silently
skip approval for any other command WorkTrunk runs on that invocation —
prefer the pre-approval step for that reason.

If WorkTrunk is unavailable, choose the correct case:

<!-- dprint-ignore-start -->
| Case | Command |
| --- | --- |
| Fresh claim | `git worktree add <path> -b <branch-name> origin/{development-branch}` |
| Takeover — local branch exists | `git worktree add <path> <branch-name>` |
| Takeover — remote branch only | `git fetch origin && git worktree add <path> -b <branch-name> origin/<branch-name>` |
| Takeover — neither local nor remote (rare) | treat as fresh claim; preserve the inherited branch name |
<!-- dprint-ignore-end -->

For manual `git worktree add`, WorkTrunk without an install hook, or a
compliant pinned harness-native tool (per "Harness-native worktree
tools" above), acquire the
[worktree-local lock file](idd-claim.instructions.md#worktree-local-lock-file-same-machine-collision)
immediately after the worktree exists, **before Step 3** —
`install-deps` itself writes into the worktree and runs lifecycle
hooks, so acquiring the lock any later leaves that install unprotected.
Also re-run `--record-tokens` (with the same `{nonce}` the A5 write
used — `--record-tokens` overwrites rather than merges, so omitting it
here drops the nonce from this worktree's own copy) for this
worktree's own copy of the
[generated-tokens record](idd-claim.instructions.md#worktree-local-lock-file-same-machine-collision)
at the same point — the A5 copy lives in the primary worktree's admin
directory, not this one, so the later Claim revalidation gate's
`--read-tokens` check has nothing to find here until this step runs it.

WorkTrunk's pre-start hook runs before the create command returns. If it
installs dependencies, its **first** command must acquire the lock for
the new worktree with the current `{agent-id}` / `{claim-id}` and
re-run `--record-tokens` (with the same `{nonce}` the A5 write used),
then run the install — doing either afterward is too late. Under
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
- **Manual `git worktree add`, WorkTrunk without a hook, or a
  compliant pinned harness-native tool**: `cd` into the newly created
  worktree, then run **install-deps**.

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
  path, not the primary worktree; a launch-workspace-bound file-tool
  harness (Grok Build observed) needs this absolute path, not
  `cd`/`pwd`.

If any check fails, the B1 worktree-creation contract has been
violated: stop, post a hold note describing which check failed, and do
not continue to B2 from the primary worktree. Repair by removing the
misplaced branch (after confirming no work is lost) and recreating the
sibling worktree through the Worktree creation steps above.

The optional local `_idd-worktree-guard.sh` hook (enabled via
`worktreeGuard.enabled: true`) automates part of this self-check by
refusing a commit/push from the primary worktree while HEAD matches an
implementation-branch pattern (default `issue/*`, `roadmap-audit/*`).
It does **not** catch skipping B1 and committing on the base
branch — set `worktreeGuard.refuseBaseBranchCommits: true` (#2801) to
also refuse that case.

If WorkTrunk reports its `Cannot change directory — shell integration
installed but not active` diagnostic, re-verify the current working
directory on every later command — see
[rationale](../../docs/idd-design-rationale.md#worktrunk-cwd-caveat).

### Already inside a host-isolated worktree

If this agent's own environment is already a host-isolated worktree
from the harness or orchestrator, "primary worktree" above does not
apply: there is no separate worktree to manage or return to. Skip
Worktree creation; run **install-deps** and verify
`git rev-parse --abbrev-ref HEAD` returns the claimed
`issue/<number>-<slug>` branch as the substitute for the B1
self-check. On a mismatch, post a hold note and stop for the harness
or orchestrator — never remove or recreate this checkout.

At F4, skip the primary-worktree fetch/switch/merge and `git worktree
remove` steps; let the harness reclaim it and finish the rest (issue
close, digest, comment cleanup).

## B2 — Create and refine plan

### B2.0 — Supersession re-check (before planning)

A4.5's duplicate/supersession check ran once, at pre-claim triage. A
sibling PR can ship the whole deliverable during the claim→plan gap
under concurrent execution, so re-check once the B1 worktree exists and
**before writing any code or drafting the plan below**, using a
mechanical file/close-based signal stronger than A4.5's title/
declaration heuristic (a weak **title-only** match is **not** a hit
here). Keep it cheap: one fetch plus a bounded merged-PR scan.

1. `git fetch origin {development-branch}` (concurrent workers sharing
   one clone: behind the
   [clone-scoped lock](../../docs/idd-helper-scripts.md#clone-scoped-lock),
   same as B1).
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
hold on current `{development-branch}`, then close the issue with a
comment referencing the superseding PR. If the criteria only
**partly** hold, keep the issue open,
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

### B2.2 — Example field-name verification

When the issue's "Proposed change" or "Acceptance criteria" cites an
existing schema field, config key, or token as an example (not one it
adds), verify it exists as cited; fix or drop if not, hold if unclear
(`#2806`).

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

### B3 self-check

Before implementing, verify B2 actually finished, not merely started:
the B2 plan comment reflects the refined, post-critique plan (draft →
critique pass → refined final plan posted as a follow-up or update to
the same comment) -- a draft posted before its critique pass does not
satisfy this. Claim ownership revalidation needs no separate check
here: it already applies to every B3 mutation via the
[claim revalidation gate](idd-overview-core.instructions.md#claim-revalidation-gate).
If the plan is not actually finalized, stop and return to B2.

The following is a repair path only for an ordering violation that has
already occurred, not an alternative route: disclose the deviation on
the issue, name the skipped checkpoint step (the B3 self-check above),
post the plan retroactively with an explicit note about the
reordering, and run the C1 critique pass against the completed diff.

Implement the plan, running **fix-validate** before each atomic commit
(one logical change per commit). Non-interactive-hostile signing: use
the [signed-commit merge wrapper](../../docs/idd-helper-scripts.md#signed-commit-merge-wrapper-shared-git-procedure)
instead.

**Verify a commit actually landed before trusting a subsequent push.**
A `commit-msg` hook (e.g. commitlint's body-max-line-length) can
silently reject a long single-line body, so no commit is created but
the next `git push` reports "Everything up-to-date" — a misleading
no-op. Prefer `git commit -F <file>` with a pre-wrapped body over a
long `-m` message, and confirm the commit landed (compare `git
rev-parse HEAD` before/after, or check the reported commit hash)
before trusting the push.

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

**Editing a docs/instructions file**: before editing any `docs/**.md`
or `.github/instructions/**.md` file, check whether it is a generated
mirror. A `.github/instructions/**.instructions.md` file carries an
`idd-generated-from` banner at its top when it is one -- the banner
itself names the canonical source and the resync command, valid only
for an `exact`/`concreted`-style pair. A `docs/**.md` file may not
carry that banner even when it is a mirror; check this repository's
sync manifest (for example `audit/sync-manifest.json` in the
`idd-skill` source repository, or your own repository's equivalent
config) for an entry naming this file as a mirror target instead, and
follow that entry's own mode contract. An `exact`/`concreted`-style
entry auto-regenerates the mirror from its named canonical source when
the resync command runs -- edit only that source, never the mirror
directly, or the edit is silently discarded on the next sync. Any
other mode (for example one that only requires certain text or
patterns to be present, with no single canonical source to
auto-regenerate from) follows its own stated contract instead --
consult the manifest entry itself rather than assuming auto-regenerate
applies. See
[rationale](../../docs/idd-design-rationale.md#b3--edit-the-canonical-source-of-a-generated-docsinstructions-file-not-its-mirror).

If B3 or C must stop for a hold, use the shared Hold / suspend rules in
`idd-overview-appendix.instructions.md` and update the issue digest with the
blocking condition before stopping. Do not use the digest as the only
record of unfinished work; material decisions still need issue comments
or commits.

**Unplanned follow-up work**: If B–C reveals a separate follow-up, do not call
`gh issue create` or the REST issues API. This direct-creation anti-pattern is
documented in the [B–C design rationale](../../docs/idd-design-rationale.md#work-and-self-review).
If the optional `issue-authoring`
companion is installed, invoke its Stage 1 hold/contract. Its reuse-first
check must reject targets under another hold. A target with the configured
authoring label outside this session's set is unavailable unless this pass
explicitly resumes that interrupted set; verify its set identity from the
companion's durable owner markers and add its
published issues to the working set first. Unrelated holds stay unavailable.
If the companion builds an optional discarded validation probe
(throwaway, unpublished), run it in a separate temporary worktree;
otherwise skip it. Never run or discard that probe in the current issue
worktree.
Before every edit, require per-target atomic or append-only owner-marker
acquisition and a fresh body/label re-read; on conflict, keep the label, stop,
and use another target or a separate comment.

For a set, use a valid parent roadmap shell as anchor when present; otherwise
use the designated lead. A roadmap's `## Tracks` may be empty until child
numbers exist. Then publish/acquire ready children under that anchor,
renew/revalidate it around each acquisition, wire numbers into any roadmap,
leave the authoring label on every target, then resume B–C.
After anchor acquisition, persist/verify exact `anchor`/`set` in the originating
issue's durable Stage 1 hold; resume must recover it, not infer from label or
choose another lead. On interruption, retain labels, stop B–C, and resume only
after completion. If Stage 1 publishes nothing (including after a non-ready
bucket), comment it before resuming and list it in PR follow-ups once PR
exists. Keep Stage 1 B–C hold; never release
a follow-up or start a second loop. If the companion is unavailable, record the
proposal in a comment/PR follow-ups; never create it ad hoc or improvise
worker-side authoring.

---

## C — Self-Review Loop

### C1 — Critique pass

Run a critique pass on this branch's diff. Ask it to check whether the
implementation is correct, whether the issue's requirements are
satisfied, whether adequate test coverage exists, and whether any other
problems exist. See `idd-overview-appendix.instructions.md` for per-agent
implementation. The distributed defaults for the C-phase skip and loop
guards are listed in `docs/policy-constants.md`. A repository may
configure `critiqueLoop.delegate` to point this step at a different
reviewer instead of the per-agent mechanism. When helper runtime is
enabled, resolve the effective `critiqueLoop.delegate` with the
[`idd-critique-delegate`](../../docs/idd-helper-scripts.md#effective-c1-critique-delegate)
helper — `node scripts/idd-critique-delegate.mjs` for source-repo /
vendored-node profiles; for package-manager / ephemeral-npx, resolve
the profile-selected command from `docs/idd-helper-scripts.md` rather
than hardcoding that bare binary name — instead of hand-deriving it;
for `instructions-only` execution, apply the
resolution order directly instead: repo-local `critiqueLoop.delegate`
always wins outright, and only when it is genuinely absent does a
local runtime's user-global config file apply. A repository may also
configure `critiqueLoop.telemetryHook` for a separate fire-and-forget
per-round JSON record (round, repo, issue, PR,
findings/severity/accepted/rejected counts, delegate usage, timestamp)
that C2/C4 below invoke but that never gates control flow; see
`docs/idd-workflow.md`'s "Critique pass invocation" section for both.

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

**Telemetry hook**: on a zero-issue round (either branch above — a
round that continues to C5 for the floor only is still a zero-finding
round and must not lose its record), invoke `critiqueLoop.telemetryHook`
(C1) with zero findings/accepted/rejected counts — fire-and-forget.

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

**Telemetry hook**: once final (before C5, PR submission, or C4's own
hold) invoke `critiqueLoop.telemetryHook` (C1) with this round's
findings, severity, accepted/rejected counts, and delegate usage —
fire-and-forget. A delegate's own fail-closed hold (`docs/idd-workflow.md`)
stops before C2 and has no telemetry record.

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
