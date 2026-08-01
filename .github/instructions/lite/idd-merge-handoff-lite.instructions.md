# IDD — Merge Policy Handoff Phase (Lite) (F2.5)

Lite profile for helper-enabled weak/local models. Read this file after
`idd-pre-merge-lite.instructions.md` records its F2 verdict, whether
`ready` is `true` or `false`. This file has exactly one job: draft and
post a handoff comment quoting that evidence, then stop. It never
evaluates whether autonomous merge should proceed, never reads or
branches on the repository's recorded merge policy
(`fully_autonomous_merge` included), and never continues to
`idd-merge.instructions.md` (F3-F5) — those stay fully out of scope for
this profile regardless of policy. If the repository is
`instructions-only`, use `idd-merge-handoff.instructions.md` instead.

## Stop-and-ask conditions

- The active claim is ambiguous, disputed, or lost.
- No F2 verdict was recorded (this file was opened without first
  completing `idd-pre-merge-lite.instructions.md`).

## Pre-mutation guard

Before posting the handoff comment, confirm all of the following:

1. The active claim still uses this session's `{claim-id}`. If it is
   missing, released, or held by a different `{claim-id}` (even under
   the same agent id), the claim was lost — stop per the condition
   above without posting.
2. If this session posted an activation nonce for the current claim,
   confirm it still wins (no later trusted marker for this claim id
   won the tie-break instead).
3. Acquire the worktree-local claim lock with the profile-selected
   `claim-lock` helper (`node scripts/claim-lock.mjs --acquire
   --worktree <this-worktree-path> --agent-id <id> --claim-id <id>`, or
   the package-manager-profile `idd:claim-lock` command with the same
   arguments — resolve the exact command from
   `docs/idd-helper-scripts.md` if unsure). A `collision` result is
   fail-closed: stop rather than proceed.
4. If any check fails, stop.

## F2.5 — Draft and post the handoff comment

1. Compose a comment containing:
   - The PR number and branch.
   - The recorded F2 verdict: `prHeadSha` (the HEAD this verdict
     applies to — include it regardless of `ready`, so a reader is
     never left guessing which commit the blocker list describes),
     `ready` (`true`/`false`), and, if `false`, every `blockers[]`
     entry verbatim (`gate` plus `detail`).
   - The active `{claim-id}`.
   - If `ready` is `true`: the merge command candidate, for the
     operator or a stronger-tier session to review and run —
     `gh pr merge {pr-number} --merge --match-head-commit "{prHeadSha}"`
     (using the recorded `prHeadSha` value from F2, not a locally
     re-derived SHA).
2. Post the comment.
3. Stop. Do not run `gh pr merge`, `idd-merge-execute.mjs`, or any
   other command that would merge, close, or otherwise mutate the PR
   beyond this one comment — a human or a designated merge-capable
   session decides and executes the actual merge from here.
