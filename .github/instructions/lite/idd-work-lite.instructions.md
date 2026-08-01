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
2. The current directory is the sibling worktree for the claimed branch.
3. `git branch --show-current` equals the claimed branch.
4. The worktree-local claim lock is held.
5. If any check fails, stop.

## B1 — Create worktree

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
17. Do not use `wt new`.
18. If WorkTrunk uses a pre-start install hook, its first command must acquire
    the worktree lock before it installs anything.
19. If the hook cannot acquire the lock, create the worktree without the hook.
20. If WorkTrunk is unavailable, use
    `git worktree add <path> -b <branch-name> origin/main` for a fresh claim.
21. If WorkTrunk is unavailable and this is a takeover, use
    `git worktree add <path> <branch-name>` with the local branch.
22. If WorkTrunk is unavailable and only the remote branch exists, run
    `git fetch origin <branch-name>`.
23. If WorkTrunk is unavailable and only the remote branch exists, use
    `git worktree add <path> -b <branch-name> origin/<branch-name>`.
24. If WorkTrunk is unavailable and neither a local nor a remote branch
    exists (rare), treat it as a fresh claim while preserving the inherited
    branch name.
25. For manual `git worktree add` or WorkTrunk without a hook, acquire the
    worktree lock with the profile-selected `claim-lock` helper immediately
    after creation and before any install or other mutation.
26. Run `install-deps` on the manual/no-hook path.
27. Verify the primary worktree's HEAD is still on `main`.
28. Verify `git worktree list` shows the new path.
29. Verify the current directory is the new sibling worktree.
30. If any of steps 27-29 fails, the worktree-creation contract is violated:
    stop, post a hold note naming the failed check, and do not continue to
    B2 from the primary worktree.
31. Repair a contract violation by removing the misplaced branch from the
    primary worktree, after confirming no work is lost, then recreate the
    sibling worktree from step 12.

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
10. If validation fails in files this diff did not touch, suspect baseline
    drift or a stale install before blaming the change; verify with a fresh
    `install-deps` run in a clean worktree or a fresh-vs-stale
    `node_modules` comparison before assuming the failure traces to this diff.
11. If a test this diff did not touch fails once locally but passes in
    isolation while hosted CI is green, trust the hosted result and stop
    chasing it as a regression. This does not waive the `fix-validate` /
    `pre-push-validate` requirements.
12. When consolidating a wrapper function used at multiple call sites into one
    shared function, check whether any call site's old delegate path added
    options or behavior the shared function does not replicate.
13. If B3 or C must stop for a hold, post the hold reason, update the digest,
    and stop.

## C — Self-review

### C1 — Critique pass

1. Run a critique pass on the branch diff.
2. Ask whether the implementation is correct, whether the issue's requirements
   are satisfied, whether coverage is adequate, and whether any other problems
   exist.
3. The floor (referenced in C2, C4, and C5) is `fix-validate` passing against
   the branch's current HEAD. Re-run it after every new commit; it does not
   substitute for D2's `pre-push-validate` gate.

### C2 — Check for issues

1. If the critique pass reports one or more issues, continue to C3.
2. Otherwise, if the critique pass reports zero issues, check the `fix-validate`
   floor.
3. If the floor has not passed, continue to C5 to repair validation.
4. If the floor has passed, open and follow `idd-pr-submit-lite.instructions.md`
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
