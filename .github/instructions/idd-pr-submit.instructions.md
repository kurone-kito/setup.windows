# IDD — PR Submit Phase (D)

Read this file after the self-review loop passes. It covers
pre-publication main sync, claim verification, tests, pushing, PR
creation, and waiting for CI.

Before the D1 sync and D2 push, apply the
[shared claim revalidation gate](idd-overview-core.instructions.md#claim-revalidation-gate).

## D1 — Sync main before first push

If the branch has not been pushed yet, sync it onto `main` before the
first push — the routine pre-publication history cleanup step. First run
`git fetch origin main`, then check whether the branch is **already
current** with `origin/main`: if `git merge-base HEAD origin/main` equals
`origin/main` (behind-count 0), the branch already contains every commit
on `main`, so the rebase would be a pure no-op. **Skip the rebase entirely
and proceed to D2** — D1's pre-publication synchronization goal is already
met. In a sibling-worktree setup a no-op `git rebase origin/main` can still
detach HEAD at the upstream tip without replaying the local commit, and
re-running that no-op rebase re-detaches every time, so the bounded
recovery below cannot converge for the no-op case; skipping it is the clean
exit.

Otherwise the branch **is** behind `origin/main`: rebase it onto `main`
(`git rebase origin/main`), then apply the post-rebase verification and
bounded recovery below.

After the first D-phase push, do not reuse D1 as the normal
synchronization path. Later branch updates should return through the
E-phase review loop and, by default, merge `main` into the published PR
branch so the synchronization diff is reviewable.

This D-phase file records the publication boundary only: post-push
synchronization itself runs through `idd-review-triage.instructions.md`'s
E-phase branch-sync check (`Esync`), which uses the
`branch-conflict-state` helper when helper runtime is enabled (a
`gh pr view` fallback otherwise), and `idd-resume.instructions.md`
already routes a content-conflicting branch there on restart.

If D1 itself reveals content conflicts before the first push, resolve
them and continue the rebase. After completing the rebase, if any files
were manually edited during conflict resolution, run **fix-validate**
and commit any resulting changes before proceeding.

On a signed-commit repo whose primary signing is non-interactive-hostile
(GPG pinentry or a hardware-touch path) but that provides a fallback
signing wrapper for arbitrary git subcommands (pass
`-c gpg.format=ssh -c user.signingkey=<abs-path> -c commit.gpgsign=true`
to `git` before the subcommand — `git -c … rebase`, not `git rebase -c …`
— or use a repo alias that wraps any subcommand; a commit-only alias like
`git commit-ssh` will not run `rebase`),
**run the initial `git rebase origin/main` above through that wrapper —
not the plain command — and continue it with the wrapper's own
`--continue` form**; the wrapper must own the whole operation. Plain
`git rebase --continue` re-signs the replayed commit through the
configured primary signing, which stalls non-interactively right after
the conflict is already resolved. This is the normal-path complement to
the recovery-path re-signing in Post-rebase verification below.

### Post-rebase verification

In a sibling-worktree setup, a rebase can leave HEAD **detached at the
upstream tip without replaying the local commit**: the branch ref is
preserved, but HEAD is moved off it. After the rebase completes and before
D2, verify both:

1. `git branch --show-current` is **non-empty** — HEAD is on the claimed
   branch, not detached.
2. The expected local commit is present in `main..HEAD` (for example,
   `git log --oneline main..HEAD` lists it).

If HEAD is detached (current branch empty), **auto-recover once**: re-attach
to the claimed branch with `git checkout {branch-name}` (the local commit is
preserved on the branch ref), re-run the D1 rebase, then re-verify both
checks. The re-rebase re-signs through the configured commit-signing path —
do not hardcode an ad-hoc key. On the signed-commit repos in the rebase
note above, run the re-rebase through that same fallback wrapper (the
repo's blessed fallback, not an ad-hoc pin), since the plain re-rebase
would stall on the non-interactive primary signing. If
recovery still fails (HEAD still detached or the
expected commit absent), post a hold note documenting the branch state and
stop; do not push.

This is the same divergence the shared
[claim revalidation gate](idd-overview-core.instructions.md#claim-revalidation-gate)
catches at the next mutation (current branch ≠ claimed branch); detecting it
here turns a confusing later failure into an immediate, recoverable signal.

## D2 — Verify claim, lint, test, push

1. Re-read the issue to confirm the claim is still yours: the **active
   claim** must still use your current `{claim-id}`. If the active claim
   is missing, released, or held by a different `{claim-id}` (even under
   the same agent ID), the claim was lost — report this and stop.
2. Run **pre-push-validate**.

   (E2E tests are verified by CI; do not run them locally.)
3. Push the branch to the remote. On the first publication push, use a
   normal push. If you are recovering an already-published branch under
   an explicit force-push exception, use `--force-with-lease` only when
   repository policy permits it and the exceptional route already
   required a rebase; otherwise stop and return to the merge-based sync
   path.

Once the branch is pushed, treat it as published review history. A PR
that is merely `BEHIND` does not force a branch update by itself unless
branch protection or explicit repository policy requires an up-to-date
head before merge.

## D3 — Create PR

Before drafting the PR body, check whether the repository defines
`.github/pull_request_template.md`. If it exists, shape the PR body to
follow that template's section structure from the start, rather than
drafting free-form text and reconciling it against the template
afterward — repository review tooling (for example, CodeRabbit's
default description check) can compare the PR description against
that template when present, and a mismatched body can trigger an
avoidable advisory finding. If no template file exists, use the
structure below directly.

Use GH CLI or GH MCP to create the pull request. The PR body must
include the following content, mapped onto the template's sections
when one exists:

- A concise summary of the branch's changes
- A closing keyword on its own line linking the claimed issue (see
  Closing keyword below)
- Recommended follow-up issues (if any)
- Relevant background/rationale, when it materially affects review (for
  example, reuse constraints, intentional trade-offs, or non-goals).
  Include only context grounded in the issue discussion, commits, diff,
  or explicit operator instructions; omit rather than speculate.

### Closing keyword

The closing keyword must appear in the PR **body** (not the title) as
plain markdown text. Write a line such as Closes #N, Fixes #N, or
Resolves #N (case-insensitive) where N is the claimed issue number.
Render that example literally in the body — no backticks, no code
fences, no block-quote prefix.

When referring to keyword forms _as forms_ (not as the literal body
text), inline code is fine in surrounding prose; the no-wrapper
constraint applies only to the actual PR body content that GitHub
must parse.

GitHub recognizes the following keyword forms: close, closes, closed,
fix, fixes, fixed, resolve, resolves, resolved.

#### Anti-patterns

GitHub's closing-keyword detection does NOT activate when the keyword
is wrapped in any of these markdown forms — even if the underlying
text is correct:

- inline code (backtick-wrapped, e.g. `` `Closes #1` ``) — not
  detected
- fenced code block (triple backtick or triple tilde) — not detected
- block quote prefix (`>` at line start) — not detected

When detection fails, GitHub will not auto-close the linked issue on
merge and the issue↔PR linking surfaces (sidebar, timeline) will not
populate.

**Mirror false-positive — negation-blind detection**: the same literal
matching runs in the other direction too. GitHub's detector matches a
recognized keyword form immediately adjacent to a `#N` reference and
has no concept of negation — wrapping the keyword in surrounding
"not" / "deliberately" / "isn't" wording does not stop detection when
the keyword itself still sits next to the `#N` it must not close. Keep
every recognized keyword form (`close`, `closes`, `closed`, `fix`,
`fixes`, `fixed`, `resolve`, `resolves`, `resolved`) structurally apart
from any reference it must not close:

- Risky — a keyword sits directly before the reference, even inside a
  negation clause: "this PR does not close #42" (`close` is
  immediately adjacent to `#42`; GitHub cannot see the "not").
- Safe — reorder so no recognized keyword is adjacent to the
  reference: "Refs #42 (deliberately not a closing keyword — see the
  discussion there for why this PR does not resolve it directly)".
  Here `resolve` is followed by "it", not a `#N` token, so nothing
  adjacent to `#42` matches.

Do not rely on careful phrasing alone as the only safeguard — the
strengthened check in D3.5 below verifies `closingIssuesReferences`
against the deliberate closing set exactly, catching a spurious extra
close even if phrasing slips.

#### Multiple closing issues

When the PR closes more than one issue, repeat the keyword for each
reference. Both keywords must appear in plain body text for GitHub to
auto-close both issues:

- Works — a body line written as Closes #1, closes #2 (GitHub parses
  each keyword + reference pair).
- Does **not** work — a body line written as Closes #1, #2 (no
  keyword precedes the second reference, so #2 is not auto-closed).

After creating the PR, if the repository has CODEOWNER rules or expected
reviewers that are not auto-assigned by GitHub, request them explicitly:

```sh
gh pr edit {pr-number} --add-reviewer {reviewer-login}
```

### D3.5 — Verify closing keyword detection

After PR creation and before D4, confirm GitHub recognized the
closing keyword for the claimed issue. Resume routing should re-enter
this sub-step when a session restarts after PR creation but before CI
completion.

1. Re-fetch the PR body:

   ```sh
   gh pr view <pr-number> --json body --jq '.body'
   ```

2. Strip regions GitHub does not parse for closing keywords:

   - lines inside fenced code blocks (triple backtick or triple tilde)
   - spans inside inline code (single backticks)
   - lines beginning with `>` (block-quote prefix) after leading
     whitespace

3. Search the remaining plain-text body for a closing keyword
   referencing the **claimed issue number** `<N>`, using a regex
   equivalent to:

   ```text
   (?im)\b(close[sd]?|fix(e[sd])?|resolve[sd]?)\s+#<N>\b
   ```

4. **If no match in the stripped body**:

   - Edit the PR body with
     `gh pr edit <pr-number> --body <updated-body>` to add a
     correctly placed plain-text closing keyword line (e.g.,
     `Closes #<N>` as its own line, outside any code fence or
     block quote).
   - Repeat steps 1–3 once.
   - If the second self-check still fails, post a hold note on the
     issue citing the PR URL and stop. Do not proceed to D4.

5. **If the keyword exists only inside a stripped region**: report
   which wrapper form was detected (inline code, fenced block, or
   block-quote prefix) and apply the same edit-and-recheck path
   as step 4.

6. **Confirm the closing set matches exactly**: GitHub's
   `closingIssuesReferences` field on the PR
   (`gh pr view <pr-number> --json closingIssuesReferences --jq
   '.closingIssuesReferences[].number'`) lists every issue GitHub plans
   to close when the PR merges. Compare it against the deliberate
   closing set from D3 — normally just the claimed issue `<N>`, or the
   full deliberate multi-issue set when "Multiple closing issues" above
   applies. The two sets must be **exactly** equal; steps 1-5 above
   only confirm the claimed issue `<N>` is present, so this step is the
   only one that catches either direction of mismatch:

   - **An extra entry** (a `closingIssuesReferences` issue outside the
     deliberate set) is most often the negation-blind false-positive
     documented above, where an unrelated `#M` reference ends up
     adjacent to a recognized keyword elsewhere in the body. Edit the
     PR body to separate the keyword from that `#M` reference.
   - **A missing entry** (a deliberate multi-issue-close target absent
     from `closingIssuesReferences`) means its keyword did not
     register — apply the same edit-and-recheck path as step 4 for
     that issue number.

   Repeat this step once after either fix. If it still fails, post a
   hold note on the issue citing the PR URL and stop. Do not proceed to
   D4.

## D4 — Wait for CI

Schedule a wake, or background this wait only if the
topology-safety condition holds (confirmed to route completion back to
this turn); otherwise wait synchronously. Delegate polling mechanics to
`idd-ci.instructions.md`.

- **On success** → proceed to `idd-review-snapshot.instructions.md`
- **`idd-advisory-convergence` is the sole non-pass required check, and
  its own verdict — a JSON object printed in that check's run log, whose
  `pending` field is distinct from any GitHub check-run status —
  reports `pending: false` with outstanding review reasons** (thread
  disposition, actionable item count on the latest review, or
  both; see `idd-ci.instructions.md` §Interpretation for this shared
  trigger condition) → this is not a CI-wait state: the
  check turns green only after E-phase disposition, which is downstream
  of D4, so continued polling cannot resolve it, and a
  `ciWait.rerunPolicy` rerun only reproduces the same red **unless a
  maintainer has since posted a valid external-check waiver for this
  HEAD** — that case still needs the rerun, to make the check reflect
  the waiver (a pre-existing F2/F3 concern this branch leaves unchanged;
  see `idd-pre-merge.instructions.md`'s External-check waivers). Absent
  a waiver, exit CI-wait and proceed directly to
  `idd-review-snapshot.instructions.md` (E1) instead, matching the phase
  routing table's "PR open, CI running, reviews exist" row. This does
  not relax the merge gate — the check stays required, and F2
  re-verifies it independently before merge.
