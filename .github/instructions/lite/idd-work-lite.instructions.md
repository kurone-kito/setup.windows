# IDD — Work and Self-Review Phase (Lite)

Lite profile for helper-enabled weak/local models. Same semantics as
`idd-work.instructions.md`. Use only for a single claimed issue. If the
repository is `instructions-only`, use the standard work instructions instead.

## Helper runtime contract

- Helper-enabled profiles: when a step names a helper or command set, use it.
  If a required helper is missing, fails, or disagrees with live state, stop
  and ask. Do not fall back silently to prose.
- `instructions-only`: do not use this lite file; use
  `idd-work.instructions.md` instead.
- Any mismatch between this file and the standard work phase is a bug in this
  file.

## Stop-and-ask conditions

- The active claim is ambiguous, disputed, or lost.
- The current directory is not the sibling worktree for the claimed branch.
  For a harness whose file-read/edit tools stay bound to the launch
  workspace (Grok Build observed), check those tools' own absolute-path
  access, not a shell `cd`/`pwd`.
- The claimed branch is not the current branch.
- A required helper or validation command is unavailable, invalid, or disagrees
  with live state.
- The claim-lock helper reports a collision (a different claim id already
  holds the worktree lock).
- The worktree is dirty and ownership is unclear.
- Multiple PRs match the claim branch.

## Pre-mutation guard

Before any commit, push, rebase, claim heartbeat, reply, resolve, reviewer
request, or other GitHub side effect, confirm all of the following:

1. The active claim still uses this session's claim id.
2. If this session posted an activation nonce for the current claim,
   confirm it still wins (no later trusted marker for this claim id
   won the tie-break instead).
3. The current directory is the sibling worktree for the claimed branch.
   For a harness whose file-read/edit tools stay bound to the launch
   workspace (Grok Build observed), use the sibling's absolute path for
   those tools rather than a shell `cd`/`pwd`.
4. `git branch --show-current` equals the claimed branch.
5. Acquire the worktree-local claim lock with the profile-selected
   `claim-lock` helper (`node scripts/claim-lock.mjs --acquire
   --worktree <this-worktree-path> --agent-id <id> --claim-id <id>`, or
   the package-manager-profile `idd:claim-lock` command with the same
   arguments — resolve the exact command from
   `docs/idd-helper-scripts.md` if unsure). A `collision` result is
   fail-closed: stop rather than proceed. Then, separately, run
   `--read-tokens --worktree <this-worktree-path> --claim-id <id>`
   and require `present: true` with no `malformed`; otherwise recover
   per `docs/idd-helper-scripts.md` (gated: each step succeeds,
   `reacquired: true` both ends), else stop.
6. If any check fails, stop.

## B1 — Create worktree

Concurrent workers sharing one clone: serialize every `fetch`/`merge
--ff-only`/worktree add/remove call below (and F4 cleanup's own
worktree removal) behind the
[clone-scoped lock](../../../docs/idd-helper-scripts.md#clone-scoped-lock).

1. On the primary worktree, run `git fetch origin main`.
2. On the primary worktree, run `git log origin/main..main --oneline`.
3. If step 2 outputs any lines, stop and report: local `main` has unpushed
   commits. Do not force-reset `main`.
4. Fast-forward local `main` with `git merge --ff-only origin/main`.
5. Keep the primary worktree on `main` throughout B1. Do not use
   `git switch -c <branch-name>`, `git checkout -b <branch-name>`, or a
   standalone `git branch <branch-name>` followed by in-place commits in the
   primary worktree — each of these violates this rule.
6. Reuse the existing branch name verbatim for takeover.
7. Run `git worktree list` (and `git worktree list --porcelain` when checking
   prunable entries). If a sibling worktree already exists, inspect that exact
   path with the profile-selected `claim-lock` helper before reuse or removal.
8. If `git worktree list --porcelain` marks the entry `prunable` and its path
   is already absent, remove that stale entry with
   `git worktree remove --force <path-from-list>` and continue.
9. Run `git branch --list {branch-name}`. If the branch exists locally, reuse it
   only when it is an inheritable takeover branch; otherwise delete it with
   `git branch -d {branch-name}`.
10. If deletion is refused, check whether a remote branch or open PR exists for
    this branch. If so, treat it as inheritable and reuse it. If not, post a
    hold comment and stop for manual cleanup.
11. If the target path exists but is not listed in `git worktree list`, stop
    and report for manual cleanup.
12. Create the sibling worktree at `../<repo-name>.<normalized-branch>`.
13. Define `normalized-branch` as the branch name with each `/` replaced by
    `-`.
14. Use WorkTrunk if available.
15. In automation, use `wt switch --create -b <base-branch> <branch-name> -x true`
    (`<base-branch>` is normally `main`).
16. On Windows, use `git-wt switch --create -b <base-branch> <branch-name> -x true`,
    or the same `wt switch` form if `git-wt` is unavailable.
17. If the `[pre-start]` hook's install command has not already been
    approved, `wt switch --create` hangs non-interactively even with
    `-x <noop>` (`Cannot prompt for approval in non-interactive
    environment`). Before the first `wt switch --create` in such an
    environment, run `wt config approvals add --yes` once from the
    primary worktree to pre-approve it (issue `#2797`); this is scoped
    to the git project, so sibling worktrees inherit it, and is
    narrower than the global `-y`/`--yes` flag, which would also skip
    approval for any other command WorkTrunk runs on that call.
18. Do not use `wt new`.
19. If WorkTrunk uses a pre-start install hook, its first command must
    acquire the worktree lock, then — as a separate call — run
    `--record-tokens --worktree <this-worktree-path> --agent-id <id>
    --claim-id <id> --nonce <nonce>` (same nonce value as the A5 write;
    omitting `--nonce` drops it, since the helper overwrites rather than
    merges) for this worktree's own copy, before it installs anything.
20. If the hook cannot acquire the lock or record tokens, create the
    worktree without the hook.
21. If WorkTrunk is unavailable, use
    `git worktree add <path> -b <branch-name> origin/main` for a fresh claim.
22. If WorkTrunk is unavailable and this is a takeover, use
    `git worktree add <path> <branch-name>` with the local branch.
23. If WorkTrunk is unavailable and only the remote branch exists, run
    `git fetch origin <branch-name>`.
24. If WorkTrunk is unavailable and only the remote branch exists, use
    `git worktree add <path> -b <branch-name> origin/<branch-name>`.
25. If WorkTrunk is unavailable and neither a local nor a remote branch
    exists (rare), treat it as a fresh claim while preserving the inherited
    branch name.
26. For manual `git worktree add` or WorkTrunk without a hook, acquire the
    worktree lock with the profile-selected `claim-lock` helper, then — as
    a separate call — run `--record-tokens --worktree <this-worktree-path>
    --agent-id <id> --claim-id <id> --nonce <nonce>` (same nonce value as
    the A5 write; omitting `--nonce` drops it, since the helper overwrites
    rather than merges) for this worktree's own copy, immediately after
    creation and before any install or other mutation.
27. Run `install-deps` on the manual/no-hook path.
28. Verify the primary worktree's HEAD is still on `main`.
29. Verify `git worktree list` shows the new path.
30. Verify the current directory is the new sibling worktree. For a
    harness whose file-read/edit tools stay bound to the launch
    workspace (Grok Build observed), use the sibling's absolute path
    for those tools rather than a shell `cd`/`pwd`.
31. If any of steps 28-30 fails, the worktree-creation contract is violated:
    stop, post a hold note naming the failed check, and do not continue to
    B2 from the primary worktree.
32. Repair a contract violation by removing the misplaced branch from the
    primary worktree, after confirming no work is lost, then recreate the
    sibling worktree from step 12.
33. If WorkTrunk reported `Cannot change directory — shell integration
    installed but not active`, treat every later command's working
    directory as unverified until confirmed (e.g. `pwd`), not only at
    steps 28-30.

## B2 — Create and refine plan

1. Run `git fetch origin main`.
2. Re-read the issue and do the cheap supersession check. Treat a title-only
   match as no hit.
3. If a merged PR already closed the issue, stop.
4. If a merged PR since the claim time already touched a scoped candidate file,
   verify the acceptance criteria on current `main`.
5. If the criteria fully hold, close the issue with a comment referencing the
   superseding PR.
6. If the criteria only partly hold, keep the issue open, record the overlap
   in the plan, and plan only the remaining work.
7. Draft an issue comment plan for the exact change set.
8. Run a critique pass on the plan.
9. Post the refined final plan as a follow-up or update to the same issue
   comment.
10. After the final plan comment, update the live status digest to `B2 planned`,
    `Open blockers: none` unless the plan found a blocker, `Next action: B3
    implement`, and `Authoritative by` pointing at the claim and plan comment.

## B2.1 — Premise verification

If the issue is a decision-transcription issue — it records or restates a prior
human decision whose rationale asserts a checkable fact about shipped behavior —
verify that fact against the prior change's actual code or docs before drafting
the plan. If the prior change or the asserted fact cannot be verified, stop and
hold with the primary-source evidence (file, line, or excerpt, or the reason
verification was inconclusive) in the hold comment, until a maintainer
addendum resolves it.

## B3 — Implement

1. Before the first implementation edit, confirm the final B2 plan comment
   exists on the issue.
2. If it does not exist, stop and return to B2 to post it.
3. If code already landed before that checkpoint was noticed, disclose the
   ordering deviation on the issue.
4. Post the plan retroactively.
5. Implement the plan.
6. Critique the completed diff.
7. Run `fix-validate` before each commit.
8. Keep commits atomic.
9. If `fix-validate` changes files, stage and commit them before continuing.
10. Verify a commit actually landed before trusting a subsequent push: a
    `commit-msg` hook (for example commitlint's body-max-line-length) can
    silently reject a commit with a long single-line body, and the
    following push then reports "Everything up-to-date" as if nothing
    were wrong. Prefer `git commit -F <file>` with a pre-wrapped body
    file, and compare `git rev-parse HEAD` before/after (or check the
    reported commit hash) before treating a push as confirmation.
11. If validation fails in files this diff did not touch, suspect baseline
    drift or a stale install before blaming the change; verify with a fresh
    `install-deps` run in a clean worktree or a fresh-vs-stale
    `node_modules` comparison before assuming the failure traces to this diff.
12. If a test this diff did not touch fails once locally but passes in
    isolation while hosted CI is green, trust the hosted result and stop
    chasing it as a regression. This does not waive the `fix-validate` /
    `pre-push-validate` requirements.
13. When consolidating a wrapper function used at multiple call sites into one
    shared function, check whether any call site's old delegate path added
    options or behavior the shared function does not replicate.
14. If B3 or C must stop for a hold, post the hold reason, update the digest,
    and stop.

**Unplanned follow-up work**: If B–C reveals a separate follow-up, do not call
`gh issue create` or the REST issues API. This direct-creation anti-pattern is
documented in the [B–C design rationale](../../../docs/idd-design-rationale.md#work-and-self-review).
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

After Stage 1 publishes and acquires a valid parent roadmap shell as the set
anchor (or the designated lead when no parent roadmap exists), then
publishes/acquires every ready child under that anchor and wires real numbers
into the roadmap, leave the authoring label on every published or updated
target (issues and roadmaps) and resume B–C. If interrupted, leave labels on every
published or updated target (issues and roadmaps), stop B–C, and resume only
after a later pass completes
the set. After anchor acquisition, persist and verify exact `anchor`/`set`
identities in the originating issue's durable Stage 1 hold; resume must recover
it, not infer from the label or choose another lead. If Stage 1 publishes
nothing (including after clarification or a non-ready bucket), comment that
outcome before resuming and, once a PR exists,
list it in the PR's recommended follow-ups. Do not release the Stage 1 B–C
hold; never release a follow-up or start a second loop. If the companion is unavailable,
record the proposal in a separate comment and PR follow-ups; do not create it
ad hoc or improvise worker-side authoring.

## C — Self-review

### C1 — Critique pass

A critique pass asks whether the implementation is correct, whether the issue's
requirements are satisfied, whether coverage is adequate, and whether any other
problems exist. Every mechanism below answers those questions. They are what a
pass asks, never a separate pass to run on top of the one that ran.

1. Resolve the delegate verdict with the profile-selected
   `critique-delegate` helper (`node scripts/idd-critique-delegate.mjs`, or
   the package-manager-profile `idd:critique-delegate` command — resolve
   the exact command from `docs/idd-helper-scripts.md` if unsure). Read its
   `usable` field as the step 2 verdict directly — never re-derive it — and,
   when `usable` is `true`, its `source`/`command`/`mode` fields as the
   delegate to run in step 4. This file is helper-enabled only — an
   `instructions-only` repository never reaches this step, since it uses
   `idd-work.instructions.md` instead (see Helper runtime contract above,
   which is where that repository's own prose delegate contract lives): if
   the helper is missing, fails, or disagrees with live state, stop and ask
   per that contract instead of falling back to prose.
2. `usable: false` means no delegate at this layer — go straight to step 3.
   `usable: true` means the helper already applied every configuration
   fail-safe (an unusable repository-local value never runs and blocks
   user-global inheritance; an unusable user-global fragment counts as
   absent; an unusable delegate never applies `mode`); use its `command`
   and `mode` as-is in steps 4-5.
3. If no usable delegate remains, run the per-agent critique pass on the branch
   diff and go to step 7.
4. Otherwise run the delegate's `command` against the branch diff. It **failed**
   if the command is absent, exits non-zero, times out, or its output cannot be
   read as a findings list. Otherwise it **succeeded** — including when it
   returns a readable list with no issues in it. Failure only decides whether
   the per-agent pass runs in step 5; it never discards a readable findings
   list the delegate did emit, which stays part of this pass's output.
5. Read `mode` (`fallback` when the key is absent; a present unrecognized value
   was already routed out by step 2) to decide whether the per-agent pass also
   runs: `combined`
   always, without waiting on the delegate's outcome; `fallback` only when the
   delegate failed; `on-success` only when it succeeded; `never` not at all.
   Run the per-agent pass when `mode` says to. When `mode` withholds it, do not
   answer the questions above yourself instead — the delegate's findings are
   this pass's whole output, which is the duplicate cost `never` exists to
   avoid.
6. If both ran, union their reported issues.
7. These lenses apply only within a per-agent pass (step 3 or step 5) —
   when only the delegate ran instead (a successful delegate under
   `fallback`, or any delegate under `never`), it never sees them, and
   do not apply them yourself in its place. When a per-agent pass did
   run, also apply, composing when both fit: **Mutation / write-side**
   (the diff implements a helper that mutates GitHub state, mutates git
   state, or performs a merge) — Fail-closed inputs; Validate/execute
   scope parity; Unsafe-output suppression; Schema strictness parity.
   **Gate-mirroring** (the diff implements a helper that predicts,
   mirrors, or pre-checks another gate's decision) — Validation-path
   parity; Input completeness; Whole-identity comparison; Snapshot
   identity; Point-in-time parity.
8. The floor (referenced in C2, C4, and C5) is `fix-validate` passing against
   the branch's current HEAD. Re-run it after every new commit; it does not
   substitute for D2's `pre-push-validate` gate.

### C2 — Check for issues

1. If the critique pass reports one or more issues, continue to C3.
2. Otherwise, if zero issues came back because no mechanism produced a readable
   findings list — a `critiqueLoop.delegate` `mode` of `on-success` or `never`
   whose delegate failed at C1 step 4 without emitting one — that verdict is
   vacuous, not clean. Post a hold and stop; do not treat it as zero issues.
   Neither a delegate that succeeded and returned a readable list with no issues
   in it, nor one that failed but still emitted a readable list, is this case:
   both are genuine results, so continue to step 3.
3. Otherwise, if the critique pass reports zero issues, check the `fix-validate`
   floor.
4. If the floor has not passed, continue to C5 to repair validation.
5. If the floor has passed, open and follow `idd-pr-submit-lite.instructions.md`
   now.

### C3 — Score issues

1. Treat high issues as safety, correctness, requirement, or CI blockers.
2. Treat medium issues by context.
3. Treat low issues as minor improvements unrelated to PR intent.

### C4 — Accept / Reject and loop check

1. Accept high issues.
2. If accepted issues remain and the floor has not passed, continue to C5.
3. Otherwise, if no accepted issues remain and the floor has passed, open and
   follow `idd-pr-submit-lite.instructions.md` now.
4. Otherwise, if only low accepted issues remain after more than 3 loops and
   the floor has passed, open and follow `idd-pr-submit-lite.instructions.md` now.
5. Otherwise continue to C5.

### C5 — Fix accepted issues

1. Run `fix-validate`.
2. If the floor still has not passed and there are no accepted issues, stop
   and ask.
3. Fix the accepted issues.
4. Rerun `fix-validate`.
5. If anything changed, commit atomically.

### C6 — Return to C1

1. Repeat the critique loop until it is clean.
2. Treat the low-issue more-than-3-loop exit as clean once the floor has
   passed.
3. Do not widen scope into review triage or merge phases from this file.
