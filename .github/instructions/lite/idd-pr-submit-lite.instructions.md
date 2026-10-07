# IDD — PR Submit Phase (Lite) (D1-D4)

Lite profile for helper-enabled weak/local models. Same semantics as
`idd-pr-submit.instructions.md`. Use only for the single issue this
session already claimed and implemented. If the repository is
`instructions-only`, use the standard PR-submit instructions instead.

## Helper runtime contract

- Helper-enabled profiles: when a step names a helper or command set, use
  it. If a required helper is missing, fails, or disagrees with live
  state, stop and ask. Do not fall back silently to prose.
- **Command sets**: `fix-validate` and `pre-push-validate` (named below)
  are read from `.github/idd/config.json`'s `commands` mapping. If that
  file is missing or the command set cannot be read, stop and ask rather
  than guessing a command. Judge each run by exit status (Bash
  `${PIPESTATUS[0]}`/`set -o pipefail`); a `tail`/`head` filter can't
  prove success (#3139).
- `instructions-only`: do not use this lite file; use
  `idd-pr-submit.instructions.md` instead.
- Any mismatch between this file and the standard PR-submit phase is a
  bug in this file.

## Stop-and-ask conditions

- The active claim is ambiguous, disputed, or lost.
- The current directory is not the sibling worktree for the claimed
  branch, or the claimed branch is not the current branch.
- A required helper or validation command is unavailable, invalid, or
  disagrees with live state.
- The branch already exists on the remote **and** has an open PR **and**
  the branch-conflict-state helper's `syncRecommendation` is not `none`
  (after the `recheck` retry budget in D1 step 1, if applicable) — this
  file covers only the pre-first-push rebase; the post-publication
  merge-based resync or a closer live-state read is out of scope.
  (A pushed branch with **no** open PR yet is not this case: skip
  straight to D2 (claim re-read, **pre-push-validate**, then a normal
  push — never force), then D3. An open PR with
  `syncRecommendation: none` is not this case either: run D3.5's
  check, then skip straight to D4.)
- D1's rebase hits a content conflict this session cannot resolve
  mechanically.
- After D1, `git branch --show-current` is empty (detached HEAD) and one
  re-attach-and-re-rebase attempt still fails.
- D3.5's closing-keyword self-check, or the `closingIssuesReferences`
  match (a pending registration excepted), still fails after one edit.
- The required-check set for D4 cannot be determined: `ci-wait-state`'s
  `requiredChecks.status` reports `unreadable` (protection or ruleset
  reads are unreadable), `source-pinned`, or `no-required-checks` with
  an empty or failing `checks[]` fallback — see D4 step 3/4.
- Any required check other than `idd-advisory-convergence` reaches a
  failing terminal state, or `idd-advisory-convergence` is failing
  without satisfying D4 step 8's exception.
- D2's push needs `--force-with-lease` outside the one named exception
  below.
- D4's polling detects the PR head SHA changed mid-wait (someone else
  pushed while this session was waiting).

## Pre-mutation guard

Before any commit, push, rebase, claim heartbeat, reply, resolve,
reviewer request, or other GitHub side effect, confirm all of the
following:

1. The active claim still uses this session's claim id.
2. If this session posted an activation nonce for the current claim,
   confirm it still wins (no later trusted marker for this claim id
   won the tie-break instead).
3. The current directory is the sibling worktree for the claimed branch:
   run `git rev-parse --show-toplevel` and compare it to
   `../<repo-name>.<normalized-branch>` (the claimed branch with every
   `/` replaced by `-`), resolved from the active claim's `branch:`
   field per the B1 naming convention. A mismatch means stop; do not
   auto-relocate.
4. `git branch --show-current` equals the claimed branch.
5. Acquire the worktree-local claim lock with the profile-selected
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
6. If any check fails, stop.

## D1 — Sync main before first push

This section's rebase only applies **before the branch's first push**.

1. Check whether the branch has been pushed:
   `git ls-remote --exit-code origin "refs/heads/{branch-name}"`
   (the `refs/heads/` prefix matters: a bare branch name also matches a
   same-named tag). Exit 2 means no matching branch — continue with
   steps 2-9 below. Exit 0 means the branch already exists on the
   remote; stop on any other nonzero exit status. When it already
   exists, do not rebase it — instead check for an open PR:
   `gh pr list --head {branch-name} --state open --json number --jq
   '.[0].number // empty'` (`// empty` avoids misreading an empty
   list's literal `null` as a real PR number).
   - No output (empty): D2's push already happened in an earlier,
     interrupted session. Skip the rest of D1 (nothing to rebase) and
     continue at D2 (claim re-read, **pre-push-validate**, then a
     normal push — never force), then D3.
   - An open PR exists: read its `syncRecommendation` with the
     profile-selected branch-conflict-state helper —
     `node scripts/branch-conflict-state.mjs --pr <pr-number>`, or the
     package-manager-profile `idd:branch-conflict-state` command
     (resolve the exact command from `docs/idd-helper-scripts.md` if
     unsure) — it already accounts for whether a merely-`BEHIND` head
     needs a resync (an up-to-date-head branch-protection requirement)
     rather than treating every non-`CLEAN` state the same:
     - `syncRecommendation: "none"`: D1-D3 already happened in an
       earlier session. Run D3.5's closing-keyword check first — it is
       idempotent, and a session that crashed between D3 and D3.5 would
       otherwise never verify the keyword — then continue to D4 (wait for
       CI).
     - `syncRecommendation: "recheck"` (mergeability still computing):
       re-run the helper after a short wait, up to 3 attempts; only a
       result still `"recheck"` after that budget falls through to stop
       per the condition above.
     - Any other value (`"merge-base"`, `"policy-required-update"`,
       `"force-push-exception"`, `"hold-unknown"`, or the helper is
       unavailable, fails, or disagrees with live GitHub state): stop
       per the condition above (out of this file's scope).
2. Run `git fetch origin main`.
3. If `git merge-base HEAD origin/main` equals `origin/main`, the branch
   already contains every commit on `main` — skip the rebase and go to
   D2.
4. **Before rebasing**: if primary commit signing is non-interactive-
   hostile (GPG pinentry, or a hardware-touch path) and the repository
   provides **no** fallback wrapper for arbitrary git subcommands, stop
   and ask before running the rebase at all — replaying even one commit
   re-signs it, and a hostile path with no wrapper has no safe
   non-interactive way to do that.
5. Rebase onto `origin/main`. When primary signing is
   non-interactive-hostile and a subcommand wrapper exists, run the
   rebase through it from the start: `git -c gpg.format=ssh -c
   user.signingkey=<abs-path> -c commit.gpgsign=true rebase origin/main`
   (or a repo alias; a commit-only alias will not run `rebase`).
   Otherwise run plain `git rebase origin/main`.
6. If the rebase hits a content conflict, resolve it and continue the
   rebase. On the signed-commit repo case in step 5, continue with the
   **wrapper's own** `--continue` form, not plain `git rebase
   --continue` — the plain form re-signs through primary signing and
   stalls.
7. Failed write — rebase in progress, index holds the replay, branch
   tip still the pre-rebase commit, and the commit object was never
   written with no staged content conflict: run `git rebase --abort` to
   restore the branch tip, then
   restart the **full** rebase through the configured wrapper's `rebase
   origin/main` form. Use SSH `-c` or step 5's alias.
   This replays the stack; never replace with a one-commit cherry-pick.
   Do not run `git commit --amend -S` or `git commit --amend '-S'`.
   Step 6 `--continue` stays for a staged content conflict.
8. After the **entire** rebase completes (not per-conflict, mid-rebase):
   if any file was hand-edited during conflict resolution, run
   **fix-validate** now, against the final rebased state, and commit
   any resulting changes before continuing. Then verify both:
   - `git branch --show-current` is non-empty (HEAD is not detached).
   - The expected local commit appears in `git log --oneline
     origin/main..HEAD` (not local `main`, which this file never
     fast-forwards and so can be stale).
9. If a finished rebase left HEAD detached, re-attach once with
   `git checkout {branch-name}`, repeat this D1 rebase (through the
   same signing wrapper on a signed-commit repo), then re-verify both
   checks in step 8. If recovery still fails, stop and post a hold
   note naming the branch state.

Once the branch is pushed, treat it as published review history: a
later resync merges `main` into the branch through the E-phase review
loop instead of returning to this D1 rebase path.

## D2 — Verify claim, lint, push

1. Re-read the issue. The active claim must still use this session's
   claim id. If it is missing, released, or held by a different claim id
   (even under the same agent id), the claim was lost — stop.
2. Run **pre-push-validate**. (E2E tests are verified by CI; do not run
   them locally.)
3. Push the branch: `git push -u origin {branch-name}` — plain on
   first publication or a no-open-PR resume (D1 step 1). Use
   `--force-with-lease` only when every one of these holds: the
   branch is already published, a repository policy explicitly
   permits a force-push exception here, and this exact exception
   already required a rebase. If any of those does not hold, stop
   per the condition above — do not push with `--force-with-lease`
   and do not continue in this lite flow; the merge-based resync path
   is out of scope.
4. New CI job: land it `workflow_dispatch`-only first (if its workflow
   file isn't on `main` yet, land a bootstrap PR for just the trigger
   wiring first — `gh workflow run` can't dispatch a branch-only
   file), validate with a manual dispatch run, commit the trigger-flip
   edit, re-run **pre-push-validate**, and push, before D3.

## D3 — Create PR

1. Before drafting the body, check whether
   `.github/pull_request_template.md` exists; if it does, shape the
   body to that template's sections from the start.
2. Create the PR using GH CLI (`gh pr create`) or GH MCP, with a body
   satisfying the rules below.
3. The PR body must include: a concise summary, a closing keyword line
   for the claimed issue, recommended follow-up issues (if any), and
   background/rationale only when it materially affects review. Ground
   any background/rationale only in the issue discussion, commits,
   diff, or explicit operator instructions — omit rather than
   speculate. The prose sections follow the resolved `authoringLanguage` value
   from `.github/idd/config.json` (fixed tag, the claimed issue's own body
   language for `match-source`, or English if absent — see
   [Authoring Language](../../../docs/customization.md#authoring-language));
   this never changes a machine-parsed marker or exact-regex-matched
   visible line — the closing keyword line stays canonical English,
   since GitHub's parser and D3.5's regex below match only English
   keyword forms.
4. **Closing keyword**: write a plain-text line such as `Closes #N` for
   the claimed issue number, on its own line. GitHub recognizes these
   keyword forms (case-insensitive): `close`, `closes`, `closed`, `fix`,
   `fixes`, `fixed`, `resolve`, `resolves`, `resolved`. Never wrap the
   keyword in inline code, a fenced code block, or a block-quote `>`
   prefix — GitHub does not detect the keyword in any of those forms,
   and the linked issue will not auto-close on merge.
5. **Negation-blind detection**: GitHub matches a keyword immediately
   adjacent to a `#N` with no concept of negation — never place one
   next to a `#N` you don't intend to close, even inside a "not"
   clause; reorder the sentence instead.
6. **Multiple closes**: repeat the keyword for each issue — `Closes #1,
   closes #2` closes both; `Closes #1, #2` closes only the first.
7. If CODEOWNERS or expected reviewers are not auto-assigned, request
   them explicitly: `gh pr edit {pr-number} --add-reviewer
   {reviewer-login}`.
8. **Do not create follow-up issues directly** — never call `gh issue
   create` (or the REST issues API) yourself. Recommended follow-ups
   stay in the PR body prose above; if one is important enough to file
   now, invoke the `issue-authoring` skill (Stage 1 hold; continue
   to its Stage 2 narrow auto-release exception when the published
   body carries the `review-fix-loop-cutoff` defer-source marker).
9. **Live-operator-directed immediate-fix carve-out**: a live operator
   may direct an unrelated blocking-bug side-fix instead of routing it
   through `issue-authoring` first. Cross-reference the originating
   issue with `Refs #N` — never `Closes`/`Fixes`/`Resolves`. D3.5
   applies only to the side-fix's linked issue, if any. Branch/
   worktree/claim mechanics: undefined; see
   `idd-pr-submit.instructions.md`'s carve-out.

### D3.5 — Verify closing keyword detection

1. Fetch the PR body: `gh pr view {pr-number} --json body --jq '.body'`.
2. Strip fenced code blocks, inline-code spans, and block-quoted lines
   from the body.
3. Search the remaining plain text for the claimed issue number `<N>`
   with this pattern, kept on one line (do not reflow it — a line break
   inside the alternation would silently break the `resolve` branch):

   ```text
   (?im)\b(close[sd]?|fix(e[sd])?|resolve[sd]?)\s+#<N>\b
   ```

   Matching case-insensitively (`Closes`, `CLOSES`, and `closes` all
   count).
4. If no match: edit the PR body to add a correctly placed plain-text
   closing line, then repeat steps 1-3 once. If it still fails, stop and
   post a hold note citing the PR URL.
5. Confirm the closing set matches exactly: `gh pr view {pr-number}
   --json closingIssuesReferences --jq
   '.closingIssuesReferences[].number'` must list precisely the
   deliberate closing set (normally just `<N>`).
   - An extra entry usually means an unrelated `#M` sits next to a
     keyword elsewhere in the body — separate them.
   - A missing entry whose keyword matches step 3's regex for that
     number, on a PR whose `createdAt` (`gh pr view {pr-number} --json
     createdAt`) is under 4 hours before now (UTC), is GitHub's async
     registration (`kurone-kito/idd-skill#3632`): do not edit the body,
     toggle draft, or close and reopen; go on to D4 and poll
     `closingIssuesReferences` the same way. Otherwise (keyword absent,
     or still missing at 4 hours) apply step 4's path, re-placing the
     keyword line.
   - Repeat once after any edit. If it still fails (pending registration
     excepted), stop and post a hold note citing the PR URL.
6. A commit message closing keyword counts too: never place one next
   to an issue outside the closing set. F2's `closing-set` blocker
   re-checks the set and messages against final HEAD (skipped on a
   non-default `{development-branch}`), blocking the handoff on a
   stray match.

## D4 — Wait for CI

These are two different helpers with different jobs: the policy helper
never reads live check state, and the state helper never resolves
timeouts. Use both, not either alone.

**Waiting mode**: wait synchronously by default. Only background this
wait when it is confirmed to route completion back to this same
session/turn; otherwise it can strand the session past its handoff point
with no one left to act on the result.

**HEAD-drift detection**: on the first poll, record `ci-wait-state`'s
`headRefOid`. On every later poll in this same wait, compare the fresh
`headRefOid` against that recorded value. If it differs, someone pushed
to this branch while waiting — stop per the condition above rather than
proceeding to E1 on results for a HEAD this session never validated. Do
not resume this wait on its own: a fresh D4 entry over the new HEAD is
for whoever resolves the stop.

**Duplicate check instances**: the state helper's `checks[]` array can
hold more than one entry for the same `checkName` — a rerun leaves the
earlier instance in place alongside the fresh one, and the raw array is
not pre-deduped. It is keyed by `(checkName,
workflowName)` so two independent checks sharing a display name across
workflows stay distinct. Before evaluating `checks[]` below (steps 3,
5, and 6 all read it): for a **`required`** entry (steps 5 and 6's own
set), reduce by `checkName` alone — the required-check gate itself
matches by name alone, and a rerun's `workflowName` can differ from
the run it supersedes. For a **non-required** entry (step 3's
fallback), reduce by the full `(checkName, workflowName)` pair
instead, to avoid conflating independent checks. Either way: an entry
with no `completedAt` (still in flight) always outranks one that has
completed, regardless of `startedAt` — a live rerun can never be older
than the run it supersedes. Once both have completed, the later
`completedAt` wins.

1. Use the profile-selected **ci-wait-policy** helper to resolve the
   running/generation timeouts and the rerun budget:
   `node scripts/ci-wait-policy.mjs`, or the package-manager-profile
   `idd:ci-wait-policy` command (resolve the exact command from
   `docs/idd-helper-scripts.md` if unsure). This helper is read-only and
   does not poll CI itself.
2. Use the profile-selected **ci-wait-state** helper for the actual
   required-check snapshot (poll it again on each wait iteration):
   `node scripts/ci-wait-state.mjs --pr <pr-number>`, or the
   package-manager-profile `idd:ci-wait-state` command (same
   `docs/idd-helper-scripts.md` resolution as above). Read its
   `requiredChecks.status` field: `success`, `pending`, `failing`,
   `missing`, `no-required-checks`, `source-pinned`, or `unreadable`.
   If either helper is unavailable, fails, or disagrees with live
   GitHub state, stop and ask — do not re-derive branch-protection or
   ruleset rules by hand.
3. **`no-required-checks`**: a repository can legitimately have no
   _required_ checks while still running normal CI, so this is not
   automatically a stop. Instead, fall back to the same helper's
   `checks[]` array (every check present for this HEAD, not just
   required ones) and its per-check `status`: every entry `success` →
   proceed to step 7; any entry `pending` or `unknown` → continue at
   step 6, which applies its timeout math to every entry this route
   names, not only `required` ones (poll again — `unknown` isn't a
   settled result yet, so treat it like `pending`); any entry `failure`
   → stop per the condition above; `checks[]` itself empty (no CI ran
   at all for this HEAD) → stop per the condition above.
4. **`unreadable`** (a branch-protection or ruleset read could not be
   determined) or **`source-pinned`** (a ruleset or integration-pinned
   required check exists but cannot be enumerated by name): always
   stop per the condition above — never treat either like
   `no-required-checks`.
5. **`failing`**: check every `checks[]` entry where `required` is
   true and its `checkName` is not `idd-advisory-convergence`
   (`requiredChecks.missingNames` is always empty for this status —
   see step 6's `missing` route for that case). If **all** are
   `success`, `idd-advisory-convergence` is the sole non-passing
   required check — go to step 8's exception instead of stopping
   here. If **any** has `status: "failure"`, stop per the condition
   above (outside this file's mechanical scope to fix or rerun).
   Otherwise — none failed, but at least one is still
   `pending`/`unknown` — apply step 6's timeout/on-timeout handling to
   just those unsettled entries, never `idd-advisory-convergence`
   itself (already completed), then re-read this step once they
   settle.
6. **`pending`** or **`missing`** (an expected required check has not
   posted a result yet), or any `pending`/`unknown` entry reached via
   step 3's fallback: keep polling until `success`, `failing`, or a
   timeout. Entries to evaluate: for this direct route,
   every still-non-`success` required entry, plus each name in
   `requiredChecks.missingNames` (a required check with no `checks[]`
   entry at all); for step 3's fallback, every still-non-`success`
   entry regardless of `required` (a `no-required-checks` repository
   marks none `required`). **Determine
   timeout from server timestamps, not a client clock estimate**: the
   helper always reports `startedAt` as a string, empty when absent —
   test for non-empty, not merely present. If it is non-empty, elapsed
   is server time minus `startedAt`, timed out past ci-wait-policy's
   `runningTimeout`. If it is empty (queued) or the entry is a
   `missingNames` name with no `checks[]` entry at all, elapsed is
   server time minus this wait's own first poll time, timed out past
   `generationTimeout` instead — its running-timeout has not begun.
   **On timeout**: identify the stalled check (`checkName` plus `url`
   if present). No case below has a run `gh run rerun` can target
   unless the entry has both `type: "check-run"` and a non-empty
   `url` — stop per the condition above and post a hold note naming
   the check for any of: it is a `missingNames` name with no
   `checks[]` entry at all (so no `url` either); its entry has `type:
   "status-context"` (a Commit-Status), whose `url` points at an
   external target rather than an Actions run; or its entry has `type:
   "check-run"` but an empty `url` (the upstream `detailsUrl` was
   itself absent). Otherwise resolve the rerun
   decision directly from the run's own live state:
   `node scripts/ci-wait-policy.mjs --run-id <run-id-from-url>`
   (`--owner`/`--repo` when targeting a different repository) — this
   derives the budget mechanically from the run's own `run_attempt`
   field, never this wait's own memory. If it allows
   a rerun, rerun that check once as a **whole-run rerun, not
   `--failed`** (`gh run rerun <run-id-from-url>`) — a stalled check
   has no failed jobs to selectively rerun, only a run that never
   finished — and resume polling. If it is `hold`, or the timeout
   recurs after a rerun, stop per the condition above and post a hold
   note.
7. **`success`**: proceed to `idd-review-snapshot-lite.instructions.md`
   (E1).
8. **Exception**: if `idd-advisory-convergence` is the only
   non-passing required check, and that check's own run-log JSON verdict
   reports `pending: false` with outstanding review reasons (thread
   disposition or actionable item count on the latest review), this is
   not a CI-wait state — it turns green only after E-phase disposition,
   downstream of D4.
   - **Bot-gated `action_required`**: if instead `idd-advisory-convergence`
     is stuck at `action_required` from a gated bot-triggered run (for
     example Copilot's review event) pending approval, this is a
     stalled run, not a downstream-of-D4 state. A rerun of the gated
     run itself keeps the original actor's privileges and re-enters
     `action_required`, and `checks[]` carries no actor/event field to
     tell which instance is safe to rerun instead — use the
     profile-selected **rerun-advisory-convergence** helper
     (`node scripts/rerun-advisory-convergence.mjs --pr <pr-number>`,
     read-only) to classify every instance and print the exact `gh run
     rerun` command for the rerun-eligible one, run that command
     verbatim, then resume step 6's polling for this one check.
   - If a maintainer has posted a valid **and effective** external-check
     waiver for this exact HEAD (effective per
     `idd-pr-submit.instructions.md` D4: `deadline.passed` is true or
     `terminal.state` is `COPILOT_UNAVAILABLE`): rerun the
     `idd-advisory-convergence` check once (`gh run rerun --failed
     <run-id>`, using the run id from `checks[]`'s entry for it) so it
     re-evaluates and reflects the waiver, then resume step 6's normal
     polling for this one check instead of reading
     `requiredChecks.status` a single time immediately — a fresh rerun
     is asynchronous and commonly still `pending` right after it
     starts. If it settles to `success`, go to step 7. If step 6's own
     timeout elapses while it is still non-passing, stop per the
     condition above — do not rerun a second time.
   - Absent an effective waiver for this HEAD: exit CI-wait now and
     proceed directly to E1. This never relaxes the merge gate: the
     check stays required, and F2 re-verifies it independently before
     merge.
