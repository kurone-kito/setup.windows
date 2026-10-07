# IDD — Merge Policy Handoff Phase (Lite) (F2.5)

Lite profile for helper-enabled weak/local models. Read this file after
`idd-pre-merge-lite.instructions.md` records its F2 verdict, whether
`ready` is `true` or `false`. This file's job is to draft and post a
handoff comment quoting that evidence, then read the repository's
recorded `mergePolicy` only to decide whether to release the worker
claim afterward. It never evaluates whether autonomous merge should
proceed and never continues to `idd-merge.instructions.md` (F3-F5) —
those stay fully out of scope for this profile regardless of policy.
Unlike the standard `idd-merge-handoff.instructions.md`, this file does
not evaluate the standard file's step 5 prose-recorded sub-cases
(whether the current session is the designated merge-capable actor, or
whether an actor and resume condition are recorded) — it reads only the
machine-readable
`mergePolicy` value below. Consequently, when the repository records no
merge-capable actor, releasing the claim here returns the issue to
Discover with no designated merger, where the standard file would hold
and keep the claim instead — expect repeated claim and handoff-comment
churn on that issue until someone merges it. If the repository is
`instructions-only`, use `idd-merge-handoff.instructions.md` instead.

## Stop-and-ask conditions

- The active claim is ambiguous, disputed, or lost.
- No F2 verdict was recorded (this file was opened without first
  completing `idd-pre-merge-lite.instructions.md`).

## Pre-mutation guard

Before posting the handoff comment, confirm all of the following (F2.5
step 3 repeats checks 1-4 immediately before posting, and step 4
repeats checks 1-4 again immediately before releasing) — this mirrors
the canonical claim-revalidation gate's cwd-vs-claim check
(`idd-overview-core.instructions.md`), which gates a comment mutation
the same as a commit or push:

1. The active claim still uses this session's `{claim-id}`. If it is
   missing, released, or held by a different `{claim-id}` (even under
   the same agent id), the claim was lost — stop per the condition
   above without posting.
2. If this session posted an activation nonce for the current claim,
   confirm it still wins (no later trusted marker for this claim id
   won the tie-break instead).
3. Confirm this session is running from the implementation worktree
   named in the active claim's `branch:` field: `git rev-parse
   --show-toplevel` must resolve to the sibling worktree path the B1
   naming convention expects (`../<repo-name>.<normalized-branch>`,
   `/` → `-`), and `git branch --show-current` must equal the active
   claim's `branch:` value. If either check fails, stop and report —
   do not auto-relocate or mutate from the wrong worktree or branch.
4. Acquire the worktree-local claim lock with the profile-selected
   `claim-lock` helper (`node scripts/claim-lock.mjs --acquire
   --worktree <this-worktree-path> --agent-id <id> --claim-id <id>`, or
   the package-manager-profile `idd:claim-lock` command with the same
   arguments, or the ephemeral-npx equivalent — resolve the exact
   command from `docs/idd-helper-scripts.md` if unsure). A `collision` result is
   fail-closed: stop rather than proceed. Then, separately, run
   `--read-tokens --worktree <this-worktree-path> --claim-id <id>`
   and require `present: true` with no `malformed`; otherwise recover
   per `docs/idd-helper-scripts.md` (gated: each step succeeds,
   `reacquired: true` both ends), else stop.
5. If any check fails, stop.

## F2.5 — Draft and post the handoff comment

1. Read the recorded merge policy before composing the comment below.
   First run `git fetch origin main` (concurrent workers sharing one
   clone: serialize this behind the clone-scoped lock,
   `docs/idd-helper-scripts.md#clone-scoped-lock`, the same as B1's own
   fetch). If the fetch itself fails, do not fall back to a
   possibly-stale local `origin/main` — an
   already-existing ref must never substitute for a fresh fetch, or a
   later failure could silently authorize a release against outdated
   policy. Only after a successful fetch, read the config file from
   there — `git show origin/main:.github/idd/config.json` — never the
   local worktree's own possibly-edited copy on this PR's branch, so a
   PR cannot change its own release route (the #2373 trusted-ref
   reasoning). Resolve `mergePolicy`:
   - A successful fetch followed by `git show` failing with the
     expected missing-path error (no `config.json` at that ref): treat
     it as `human_merge` (the schema's documented default for an
     absent `config.json`).
   - Every other outcome — the fetch itself failing, a `git show`
     error other than the missing-path case, a config file that fails
     to parse, a config file without a `mergePolicy` key
     (schema-invalid, since the key is required whenever the file
     exists), or a present value other than `fully_autonomous_merge`,
     `human_merge`, or `separate_merge_agent` — treat it as
     unrecognized. Record, for step 2's comment: the underlying
     fetch/show/parse failure; the unrecognized value itself; or, when
     the config file parsed but had no `mergePolicy` key, a note that
     the key was absent.
2. Compose a comment containing:
   - The PR number and branch.
   - The recorded F2 verdict: `prHeadSha` (the HEAD this verdict
     applies to — include it regardless of `ready`, so a reader is
     never left guessing which commit the blocker list describes),
     `ready` (`true`/`false`), and, if `false`, every `blockers[]`
     entry verbatim (`gate` plus `detail`).
   - The active `{claim-id}`.
   - Step 1's `mergePolicy` outcome, verbatim: the resolved value (an
     unrecognized value included); the recorded failure when step 1
     hit a fetch, read, or parse failure; a note that the `mergePolicy`
     key itself was absent from an otherwise-readable config file; or
     a note that the config file was absent (the successful-fetch
     missing-path case only).
   - If `ready` is `true`: the merge command candidate, for the
     operator or a stronger-tier session to review and run —
     `gh pr merge {pr-number} --merge --match-head-commit "{prHeadSha}"`
     (using the recorded `prHeadSha` value from F2, not a locally
     re-derived SHA).
3. Immediately before posting, repeat the pre-mutation guard in full
   (checks 1-4) — step 1's fetch and read may have taken time since
   the initial guard, during which another session could have
   released or replaced the claim, or the worktree could have moved.
   If any check fails, stop per the condition above without posting.
   Otherwise, post the comment.
4. Decide whether to release the worker claim, gated on both the
   `mergePolicy` resolved in step 1 and the recorded F2 verdict:
   - `ready: false`: keep the claim under every `mergePolicy` value —
     the standard file never reaches its own release step with an
     unready verdict either.
   - `human_merge`, `fully_autonomous_merge`, or an unrecognized
     `mergePolicy` value: keep the claim (no release), regardless of
     `ready`.
   - `mergePolicy` is `separate_merge_agent` **and** `ready: true` —
     the only case that releases:
     1. Repeat the pre-mutation guard in full (checks 1-4: the active
        claim still uses this session's `{claim-id}`; the activation
        nonce, if posted, still wins; the worktree is still the one
        named in the claim's `branch:` field, on that branch; and
        reacquire the worktree-local `claim-lock` plus
        `--read-tokens`) immediately before this mutation — the
        elapsed time since posting the comment means those local
        invariants cannot be assumed to still hold. If any check
        fails, post no release.
     2. Otherwise, post `unclaimed-by` for this session's `{agent-id}`
        / `{claim-id}` with the profile-selected `post-idd-marker`
        helper (fields: agent id, claim id, timestamp; resolve the
        package-manager / ephemeral-npx form from
        `docs/idd-helper-scripts.md`; the direct JSON `POST` in
        `idd-overview-core.instructions.md`'s Unclaim format is the
        fallback):

        ```sh
        node scripts/post-idd-marker.mjs --type unclaim --target issue \
          <issue-number> --agent-id <agent-id> --claim-id <claim-id> \
          --timestamp <ISO8601-timestamp> --apply
        ```

        Then re-read the issue and confirm the release is the latest
        trusted claim-state marker.
5. Stop. Do not run `gh pr merge`, `idd-merge-execute.mjs`, or any
   other command that would merge, close, or otherwise mutate the PR
   beyond this comment and, when step 4 applies, the claim release —
   a human or a designated merge-capable session decides and executes
   the actual merge from here.
