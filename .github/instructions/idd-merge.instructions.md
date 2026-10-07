# IDD — Merge Execution Phase (F3–F5)

Read after `idd-merge-handoff.instructions.md` routes the claim.
Covers executing the merge (F3), cleanup (F4), and F5.

See [IDD policy constants](../../docs/policy-constants.md).

Before any mutating action in F3, apply the
[shared claim revalidation gate](idd-overview-core.instructions.md#claim-revalidation-gate).
F3 apply follows [the livelock rule](idd-review-triage.instructions.md#merge-development-branch-livelock-under-fast-moving-development-branch).

## F3 — Merge

1. Confirm the claim is still yours: the **active claim** must still use
   your current `{claim-id}`. If it is missing, released, or held by a
   different `{claim-id}` (even under the same agent ID), the claim was
   lost — report and stop.
2. Defensive route check: re-read the repository's recorded merge
   policy (missing → treat as `human_merge`, the distributed
   default). Then apply:
   - `fully_autonomous_merge`: continue.
   - `separate_merge_agent`: continue only when repository documentation
     explicitly records the **current session** as the designated
     merge-capable actor and the documented resume condition is
     satisfied; otherwise route to `idd-merge-handoff.instructions.md`
     and stop.
   - `human_merge` or unknown policy: route to
     `idd-merge-handoff.instructions.md` and stop.
3. Immediately before executing the merge command, do one final live
   fetch using the **exact same activity-universe scope as E1 Step 1**
   (all review threads, review bodies, and regular PR comments,
   excluding trusted agent operational marker comments), and compare it
   against the F2 snapshot carried forward from
   `idd-pre-merge.instructions.md`. When helper runtime is enabled,
   prefer the documented merge-gate helper reference in
   [`docs/idd-helper-scripts.md`](../../docs/idd-helper-scripts.md#stable-helper-evidence-outputs)
   to collect the snapshot tuple and broader `pre-merge-readiness` JSON
   report. Both helpers remain read-only evidence collectors only: if
   execution fails, output is invalid JSON, required sections are
   missing, or live GitHub state disagrees with it, discard helper
   output and run the live fetch directly — the written gate rules
   remain canonical. Return to E1 if any of F2's Review-currency
   return-to-E1 triggers apply, substituting the carried F2-snapshot
   fields for F2's own stored watermark fields: `{f2-head-SHA}` for
   `{head-SHA}`, `{f2-max-activity-updatedAt}` for
   `{max-activity-updatedAt}`, `{f2-total-item-count}` for
   `{total-item-count}`, and `{f2-latest-ci-completed-at}` for
   `{latest-ci-completed-at}` — this final fetch is the live side of
   each comparison, exactly as F2's own live snapshot was.

   The structural ack-only carve-out from F2 applies here verbatim:
   newer activity/count growth that helper evidence proves is
   post-disposition advisory-bot acknowledgement only
   (`ack-only-post-disposition`) does not force the return to E1; all
   other triggers above are unaffected.

   From that same final fetch, compute `F3_UNRESOLVED_ACTIONABLE_COUNT`
   using the exact F2 unresolved-thread rule and exceptions
   (non-awaiting-reviewer unresolved threads only; awaiting-reviewer
   classification must follow F2 verbatim, including AMD exclusion and
   conversation-resolution exception handling). If
   `F3_UNRESOLVED_ACTIONABLE_COUNT > 0`, stop and return to E1 — do not
   execute `gh pr merge` in this pass.

   If the carried F2 evidence includes helper-side
   `dispositionEvidence`, require `route == "proceed"` and
   `blockingCount == 0` before merge, except the F2 override when
   `soleCauseAckOnlyPostDisposition` is true. Any other missing item
   still returns to E1/E4. Use only the carried
   `pre-merge-readiness` `dispositionEvidence` shape here; E7 verifier
   fields (`passed`, `items[]`) are not merge-gate substitutes.

   Execute the merge immediately after this final fetch **and the claim
   re-validation and advisory state revalidation below**, with no other
   actions in between. Re-validate claim: re-read the issue and confirm
   the active claim still uses your current `{claim-id}` — if not, the
   claim was lost, report and stop.

   **Advisory state revalidation (blocking)**: the AW1 check just below
   is an instant state read, not itself a wait. If it escalates to a
   genuine wait, return to the F2 advisory bot wait check (backgrounds
   only if the topology-safety condition holds — confirmed to route
   completion back to this turn — otherwise waits synchronously): no
   single `gh` command blocks on Copilot review state, so run the AW
   poll loop as a foreground wait, never via `run_in_background` absent
   the confirmed condition — see
   [idd-ci.instructions.md's Wake-up
   discipline](idd-ci.instructions.md#wake-up-discipline).
   Re-fetch the HEAD SHA:

   ```sh
   PR_HEAD_SHA_F3=$(gh pr view {pr-number} --json headRefOid --jq '.headRefOid')
   ```

   Use `PR_HEAD_SHA_F3` as `PR_HEAD_SHA`. Run **AW1**
   (`idd-advisory-wait.instructions.md`):
   - If **SATISFIED** (`LAST_COPILOT_COMMIT == PR_HEAD_SHA_F3`) →
     proceed with the merge.
   - If `COPILOT_PENDING` is `"false"` (review completed or cancelled) →
     satisfied; proceed with the merge.
   - Otherwise (`COPILOT_PENDING` is `"true"`, not yet reviewed): run
     **AW2** and apply **AW3** — do not skip even if F2 already ran
     them, since F3 is a self-contained blocking gate:
     - **SATISFIED** → proceed with the merge.
     - **HOLD** → post the hold comment from **AW4** and stop.
     - **RECOVERY_NEEDED** → post the recovery marker from **AW3-R** and
       return to the F2 advisory bot wait check; do not merge in the
       same F3 pass that creates a recovery marker.
     - **CAP_EXHAUSTED** → post the cap-exhausted hold comment from
       **AW4** and stop.
     - **REQUEST_NEEDED** → return to E14 to refresh/request Copilot
       review and post a request marker; do not merge.
     - **WAIT** → do NOT execute the merge; return to the **F2 advisory
       bot wait check** in `idd-pre-merge.instructions.md` (go back to
       the first condition in F2), which reuses the existing same-HEAD
       marker — do not post a new one.

   If the optional helper output disagrees with the live fetch above,
   follow the live fetch and the written gate rules.

4. Merge the PR using a **merge commit**, binding to the validated SHA
   to prevent a race where a new push lands between the F3 freshness
   check and the merge itself.

   **Preferred path (helper runtime enabled)**: run the F3 merge helper
   documented in
   [`docs/idd-helper-scripts.md`](../../docs/idd-helper-scripts.md#merge-execution-f3).
   Pass `--closing-issues <n>,<m>` for a multi-issue close
   (forwarded to the collector). First run it in dry-run
   (no `--apply`) and confirm `ready: true` with
   an empty `blockers[]` — it wraps the read-only `pre-merge-readiness`
   gate and adds no new authority. Then re-run with `--apply`: when
   `ready`, it re-fetches the head SHA and re-validates the claim
   immediately before merging, fails closed (no merge) on head drift or
   lost claim, and runs the merge commit bound to the validated head
   (never squash/rebase). On a plain-merge failure it also applies step
   5's solo-CODEOWNER `--admin` fallback decision itself (recorded in
   `adminFallbackUsed`) — the gate checklist and decision table below
   stay canonical: if the helper is unavailable, its output is invalid,
   or its evidence conflicts with live GitHub state, discard it and use
   the manual gate + merge steps in this section.

   **Gate checklist** — confirm every field before merging; all must
   hold, and any unmet or unknown field is a NO-GO (fail closed — stop,
   do not merge):

   - current HEAD SHA **equals** the carried F2-snapshot head
     (`{f2-head-SHA}`);
   - PR `baseRefName` (fresh `gh pr view {pr-number} --json baseRefName`)
     **equals** `{development-branch}` — catches a retarget after D3's
     one-time check; a mismatch is a wrong-base hold, not a merge;
   - review-currency route is `proceed`;
   - `F3_UNRESOLVED_ACTIONABLE_COUNT` is `0`;
   - advisory `f3Outcome` is `SATISFIED` (the authoritative advisory
     gate — do not add stricter sub-conditions; e.g. a pending-window
     `SATISFIED` can keep `copilotPending` true and
     `LAST_COPILOT_COMMIT` off the head). **Manual-fallback
     equivalent** (helper unavailable or discarded): the AW1/AW2/AW3
     decision table (`idd-advisory-wait.instructions.md`), run in full
     for `PR_HEAD_SHA_F3`, returns `SATISFIED` — not merely any step 3
     branch that says "proceed with the merge";
   - no unwaived `copilot-terminal-unavailable` in the helper's
     `blockers[]` — separate from `f3Outcome`, not a stricter
     sub-condition on it
     ([Terminal routing](idd-advisory-wait.instructions.md#terminal-routing-1570)).
     **Manual-fallback equivalent**: apply that Terminal routing
     section in full — satisfied only when its **Unwaived** hold does
     not apply to this HEAD; its waiver/declaration validity rules are
     not paraphrased here;
   - all required CI checks pass for the current head;
   - claim ownership still uses your `{claim-id}`;
   - D3.5 steps 6-7 and D3.7 (`idd-pr-submit.instructions.md`) have
     been re-run against `${PR_HEAD_SHA_F3}` (#2749) — covers commits
     that landed between F2 and this final gate, for example a
     required `{development-branch}` sync. `closing-set` (readiness)
     evidences steps 6-7 here; D3.7 stays local. Before running them,
     confirm the local worktree is checked out at `${PR_HEAD_SHA_F3}`
     exactly (after fetch, the claim gate must confirm
     `git branch --show-current` is `{branch-name}`; else hold).
     Require empty `git status --porcelain` and
     `git merge-base --is-ancestor HEAD "${PR_HEAD_SHA_F3}"`;
     else hold. Run F2's
     shadow-path check against `${PR_HEAD_SHA_F3}`; any output or failure
     holds. Use `git switch {branch-name}` (not
     detached), recheck; reset on pass) — D3.5/D3.7 read local state, not
     the remote PR. Skip
     D3.5 steps 6-7 under the
     same non-default-`{development-branch}` exemption D3.5 itself
     carries. On a mismatch, fix it per D3.5/D3.7's own documented
     handling. Any fix here — whether or not it changes HEAD, since a
     PR-body edit alone (D3.7's remediation, or D3.5 step 6's) still
     counts — invalidates step 3's own **Re-validate claim** ("confirm
     the active claim still uses your current `{claim-id}`") and
     **Advisory state revalidation** (re-run AW1, escalating through
     AW2/AW3 as needed) checks above; re-run both of those before
     merging. If the fix additionally amended or rebased a commit
     (changing HEAD),
     return to E1 instead of just re-validating in place — F2's own
     snapshot is invalidated by a new HEAD. Otherwise repeat this field
     once; if it still fails, stop and do not merge.

   For the head-SHA field, use this **copy-paste-safe, fail-closed**
   check — both operands fully quoted, no glob, abort on mismatch —
   rather than re-deriving it ad hoc (a stray glob or unquoted operand
   can silently mis-gate this safety-sensitive step). `F2_HEAD_SHA` is
   the carried `{f2-head-SHA}`; `PR_HEAD_SHA_F3` is step 3's re-fetch:

   ```sh
   F2_HEAD_SHA="{f2-head-SHA}"   # the head recorded in the F2 snapshot
   if [ "$PR_HEAD_SHA_F3" != "$F2_HEAD_SHA" ]; then
     echo "F3 abort: head moved ${F2_HEAD_SHA} -> ${PR_HEAD_SHA_F3}" >&2
     exit 1  # do not merge — return to E1 per the freshness rules above
   fi
   ```

   Then merge, binding `--match-head-commit` to the **freshly validated**
   `${PR_HEAD_SHA_F3}` (never a stale, hardcoded, or unbound SHA), never
   squash or rebase:

   ```sh
   gh pr merge {pr-number} --merge --match-head-commit "${PR_HEAD_SHA_F3}"
   ```

   After the merge succeeds and claim ownership is re-validated, upsert
   the digest with `Phase: F3 merged`, `Open blockers: none`,
   `Next action: F4 cleanup then F5 discover`, and `Authoritative by`
   pointing to the merge commit and matched head SHA — not a merge
   gate, and must not happen before the successful merge command.
5. If merge fails:
   - `gh pr merge --merge` fails with "the base branch policy
     prohibits the merge" despite a passing Gate checklist and a
     configured pull-request-only bypass actor → that scoped bypass
     alone may not clear a solo-maintainer self-approval deadlock (see
     `docs/permissions.md`'s "Pull-request-only ruleset bypass"). Check
     `mergeGate.soloCodeownerAdminFallback` in `.github/idd/config.json`:
     - `"hold-and-report"` (opt-in) → keep the pre-#1521 behavior: do
       not retry the plain command or add `--admin`; post a hold
       comment with the GitHub error text and stop for a maintainer
       decision (kurone-kito/idd-skill#1493).
     - Anything else, including the key absent (distributed default
       `"auto-admin-retry"`) → retry exactly once with `--admin`, bound
       to the same validated head, only when every field in the
       [Solo-CODEOWNER `--admin` fallback field
       contract](../../docs/idd-helper-scripts.md#merge-execution-f3)
       holds: the Gate checklist (step 4) was fully green; the merge
       command's only reported failure is this exact GitHub error
       against a configured pull-request-only (or wider) bypass actor;
       and the report's `reviewerStates.codeownerSelfApproval` proves
       the PR author is the sole eligible codeowner (`status: "clear"`
       with a bypass-available `reason`, `prAuthorIsSoleEligibleCodeowner:
       true`, `codeownerEligibilityUnreadable: false`) — re-checked a
       second time immediately before the `--admin` call itself (real
       time passes between the plain merge's failure and the retry, and
       `--admin` bypasses the entire ruleset), with a fresh GitHub merge
       state of `mergeable: "MERGEABLE"` and `mergeStateStatus` settled
       to `"CLEAN"` or `"BEHIND"` also required.
       `isSafeSoloCodeownerAdminMergeState` still refuses
       `mergeStateStatus: "BLOCKED"`. When the base ruleset does not
       require CODEOWNER review, the `status: "clear"` trigger does not
       match and a `BLOCKED` state is not by itself a CODEOWNER
       deadlock; the remaining escalation on **this topology** is a
       human `--admin` (or `hold-and-report`). Distributed
       `auto-admin-retry` is unchanged when `status: "clear"` with a
       bypass-available `reason`, `prAuthorIsSoleEligibleCodeowner:
       true`, and `codeownerEligibilityUnreadable: false` hold. See
       `docs/permissions.md` (kurone-kito/idd-skill#1663) for this
       repository's own dated observation.
       `idd-merge-execute.mjs --apply` applies this automatically and
       records the outcome in the verdict's `adminFallbackUsed` field.

       ```sh
       gh pr merge {pr-number} --merge --match-head-commit "${PR_HEAD_SHA_F3}" --admin
       ```

       On success, continue the normal post-merge digest update
       exactly as after a successful plain merge (step 4). If any
       condition above does not hold, or the `--admin` retry also
       fails, post a hold comment with the GitHub error text(s) and
       stop for a maintainer decision (kurone-kito/idd-skill#1493,
       #1494) — the same hold-and-report outcome as the opt-in tier.
   - Base branch updated or conflict → return to
     `idd-pre-merge.instructions.md` F1
   - CI condition no longer met → return to
     `idd-pr-submit.instructions.md` D4 (CI wait)
   - Review condition no longer met → return to
     `idd-review-snapshot.instructions.md` E1
   - Conversation resolution required and unresolved threads remain →
     for each: **(a)** new reviewer activity (not awaiting-reviewer) →
     return to E1; **(b)** awaiting-reviewer thread whose latest reply
     is from an IDD agent without `**Awaiting maintainer decision**` →
     resolve it directly, then **restart `idd-pre-merge.instructions.md`
     F2** (to re-run the final freshness fetch); **(c)**
     awaiting-reviewer thread whose latest reply is from the PR author
     (not IDD agent) → post a brief acknowledgement reply, resolve it
     directly, then **restart `idd-pre-merge.instructions.md` F2**;
     **(d)** thread with `**Awaiting maintainer decision**` reply →
     post a hold comment and stop. Cases **(b)**-**(c)** together are
     the **F3 awaiting-reviewer restart-F2 path** cited elsewhere.

   When a merge failure routes to F1, D4, E1, or a hold, update the
   digest after recording the failure evidence: `Phase` to
   `F3 blocked`, the GitHub merge error or unresolved-thread class in
   `Open blockers`, `Next action` to the routed phase or maintainer
   action. If the path instead resolves/acknowledges awaiting-reviewer
   threads and restarts F2, do not update the digest before
   restarting — that activity would invalidate the restart and force an
   E1 snapshot even though E1 intentionally has no actionable
   awaiting-reviewer item; let the restarted F2 pass record blockers if
   it finds one.

## F4 — Cleanup

1. **Non-default development branch**: if `{development-branch}` is not
   the repository's default branch, GitHub did not auto-close any issue
   on merge (see `idd-pr-submit.instructions.md` D3.5) — close each
   issue in D3's deliberate closing set explicitly, not only the
   claimed issue: `gh issue close {issue-number} --comment "Merged via
   #{pr-number}."`.
2. Confirm the post-merge digest update above exists or repair it after
   re-validating the claim. Do not minimize the digest as an
   operational marker unless a future cleanup policy explicitly
   supports digest retirement.
3. Run merged-PR comment cleanup (must not run before F3 succeeds).
   Re-validate the active claim before each GitHub minimization
   mutation.

   Apply the following cleanup policy rules when evaluating candidates:

   - Feedback or review parent comments may be minimized as `RESOLVED`
     only after every actionable child review comment/thread under that
     parent is accepted or rejected, replied to as required, and
     resolved.
   - Known review-bot regular PR comments may be minimized only after
     merge, with a clear completed-review or stale-notification signal
     (a CodeRabbit no-action summary, a summary/review-trigger
     acknowledgement with a matching later IDD disposition, or — for
     CodeRabbit summaries specifically — once all its review threads
     are resolved with fresh IDD dispositions).
   - Bot review parent bodies without associated review threads
     (including Copilot error review bodies) are skipped by default
     unless a future policy narrows a safe cleanup class for them.
   - Trusted IDD operational marker comments may be minimized as
     `OUTDATED` only after merge, once the marker is no longer needed
     for resume, advisory wait, or review-currency checks. Candidate
     prefixes: `<!-- review-watermark:`, `<!-- review-baseline:`,
     `advisory-wait:`, `advisory-wait-recovery:`, `<!-- advisory-wait:`,
     `advisory-reroll:`.
   - Do not minimize comments with unresolved maintainer decisions,
     active holds, failed-CI context maintainers still need,
     non-operational human discussion, or content still in active F2/F3
     gates.

   **Mandatory apply decision tree** — follow this sequence; no path
   may exit without a recorded reason when cleanup candidates exist. In
   the idd-skill source repository, run the helper in dry-run mode
   first; in adopter repositories, skip to the GraphQL fallback below
   unless the helper scripts were explicitly installed.

   ```sh
   node scripts/audit-pr-cleanup.mjs --pr <pr-number> --dry-run --format table
   ```

   **In-flight cleanup-run wait (#2846)**: immediately before actually
   posting below (fresh each time, not cached from here — a run's
   status can change during dry-run/apply), check whether this PR's
   `post-merge-cleanup.yml` run is still in flight, waiting (bounded)
   for it to finish if so — see `docs/idd-comment-minimization.md`'s
   In-flight cleanup-run wait. Either way, continue to the rule below
   unchanged: it reads whatever that run may have posted and decides
   ownership from the marker's own recorded status.

   **Duplicate-success-record skip rule**: do not treat an earlier
   dry-run or apply-time read as the skip. Immediately before the
   actual POST — no other GitHub-mutating call in between — run this
   fresh re-check (mirrors `post-merge-cleanup.yml` including issue
   `#2213`; `bash`):

   ```sh
   TRUSTED_LOGINS=$(
     {
       jq -r '(.trustedMarkerActors // [])[]' .github/idd/config.json 2>/dev/null || true
       echo 'github-actions[bot]'
     } | tr '[:upper:]' '[:lower:]'
   )
   COMMENTS_FETCH_FAILED=0
   if ! COMMENTS_TSV=$(gh api --paginate \
     "repos/{owner}/{repo}/issues/<pr-number>/comments" \
     --jq '.[] | select(.body | startswith("<!-- idd-cleanup-evidence:")) | [.id, .user.login, (.body | split("\n")[0])] | @tsv'); then
     COMMENTS_FETCH_FAILED=1
   fi
   EXISTING_STATUS=""
   while IFS=$'\t' read -r candidate_id candidate_login candidate_marker_line; do
     [ -z "$candidate_id" ] && continue
     lower_login=$(printf '%s' "$candidate_login" | tr '[:upper:]' '[:lower:]')
     if printf '%s\n' "$TRUSTED_LOGINS" | grep -Fxq "$lower_login"; then
       EXISTING_STATUS=$(printf '%s' "$candidate_marker_line" \
         | sed -n 's/^<!-- idd-cleanup-evidence: \([^ ]*\) .*/\1/p')
     fi
   done <<< "$COMMENTS_TSV"
   THIS_RUN_STATUS="<this-run-status>"
   if [ "$COMMENTS_FETCH_FAILED" = "1" ]; then
     echo "RECHECK_RESULT=FETCH_FAILED"
   elif { [ "$EXISTING_STATUS" = "applied" ] || [ "$EXISTING_STATUS" = "clean" ]; } \
     && { [ "$THIS_RUN_STATUS" = "applied" ] || [ "$THIS_RUN_STATUS" = "clean" ]; }; then
     echo "RECHECK_RESULT=SKIP"
   else
     echo "RECHECK_RESULT=POST"
   fi
   ```

   Substitute `<pr-number>` and `<this-run-status>`. Guard the `gh api`
   assignment (`if ! …`) or a failed fetch reads as "no prior record".
   Do not POST from this print. Re-run at each evidence POST below and
   act on `RECHECK_RESULT`: `FETCH_FAILED` → post `recheck-failed`
   (never relabel the apply) per
   [docs/idd-comment-minimization.md](../../docs/idd-comment-minimization.md#re-check-fetch-failure-comment);
   `SKIP` → do not post; `POST` → that branch's evidence. Residual REST
   TOCTOU is accepted — see that same doc's server-side fallback
   section. SKIP requires the latest record **whose author is a
   trusted marker actor**. An untrusted commenter's marker-prefixed
   comment never counts as evidence.

   Evaluate the dry-run `status` field (this is a dry-run status; apply
   mode emits different values and is never invoked unless dry-run
   shows `needs-apply`):

   - **`clean`**: no candidates and no permission-blocked items.
     Proceed to step 4.

   - **`needs-apply`**: eligible candidates exist and the viewer can
     minimize them. Apply is mandatory. Re-validate the active claim,
     then run:

     ```sh
     node scripts/audit-pr-cleanup.mjs --pr <pr-number> --apply \
       --claim-issue <issue-number> --claim-id <claim-id> --format table
     ```

     After apply, record the outcome by the apply `status`. See
     `docs/idd-comment-minimization.md` for the exact formats:

     If the apply `status` is `applied` or `clean`: run the fresh
     re-check above **now** and act on `RECHECK_RESULT`. Proceed
     to step 4.

     The helper may retry a scan-and-minimize pass, bounded, when a
     rescan still reports candidates (read-after-write lag). Route by
     apply `status` even when `retryBoundExhausted: true`:
     `applied`/`clean` still post evidence (`retryAttempts` is
     informational); `incomplete`/`failed` still take the
     cleanup-failure path below.

     If the apply `status` is `failed`, `incomplete`, or
     `rescan-failed`: re-check, then post cleanup-failure (or
     `recheck-failed`) as above, including the
     `viewer-cannot-minimize` count when non-zero.
     `rescan-failed` means the confirming rescan itself errored after a
     mutation (already-applied work is preserved in the report but
     convergence was never confirmed) — note that distinction in the
     comment and re-run `--apply` to confirm convergence. Explicit
     evidence, not a merge gate — the merge already succeeded. Proceed
     to step 4.

   - **`permission-blocked`**: skipped items exist with
     `viewerCanMinimize: false` and no apply-eligible candidates found.
     Re-check, then post cleanup-permission-blocked (or
     `recheck-failed`) listing the blocked candidates and the count,
     then proceed to step 4.

   For the GraphQL fallback (helper unavailable): check
   `viewerCanMinimize` and `isMinimized` before minimizing; skip
   already-minimized comments and ones the viewer cannot minimize.
   Re-validate the active claim before each mutation. Before every
   evidence POST (success or permission-blocked), re-check and act on
   `RECHECK_RESULT`. If the viewer cannot minimize any detected
   candidates, post a cleanup-permission-blocked comment instead of
   exiting silently.

   See `docs/idd-comment-minimization.md` for the evidence comment
   format, cleanup-failure comment format, permission-blocked comment
   format, and fallback GraphQL commands.
4. Concurrent workers sharing one clone: serialize this fetch and
   step 5's `worktree remove` behind the
   [clone-scoped lock](../../docs/idd-helper-scripts.md#clone-scoped-lock).
   From the **primary worktree** (elsewhere would fast-forward the
   wrong branch), switch to `{development-branch}` (the PR's
   validated target; see
   [B1 Worktree creation Step 2](idd-work.instructions.md#b1--create-worktree-with-branch))
   and fast-forward it:

   ```sh
   git fetch origin
   git switch {development-branch} || git switch -c {development-branch} --track origin/{development-branch} \
     && git merge --ff-only origin/{development-branch}
   ```

   The switch falls back to a local tracking branch if the primary
   worktree has none yet (non-default `{development-branch}`: B1
   branches worktrees from origin).

   If the switch or fast-forward refuses over dirty primary-worktree
   paths, re-validate the claim, hold per
   [Hold / suspend](idd-overview-appendix.instructions.md#hold--suspend)
   as `primary-worktree-dirty` (the operator cleans those paths — never
   stash/discard them — then re-run step 4 through step 7), and
   stop before step 5 — primary-worktree state, so never remove the
   issue worktree because of it.

   Two more failures (stop before step 5; see
   [detail](../../docs/idd-helper-scripts.md#f4-branch-failure-routes)):

   - `already used by worktree` → hold as `development-branch-in-use`;
     name the path, don't touch it.
   - `Not possible to fast-forward, aborting.` → hold as
     `development-branch-diverged`; don't reset/rebase.

   Off-default `{development-branch}`: `git switch <default-branch>`
   once F4 completes/holds, for B1's checkout.
5. Run from the **primary worktree**, not one being removed.
   Removal discards ignored submodule data. Scope
   to `<path>`. Inspect leftovers under `-` (not a repo).

   Use `--untracked-files=normal` (not `all`). A clean submodule can
   still hide a stash or unpushed commit; tag-only detached history is
   not counted; local refs are:

   - `git -C <path> status --porcelain --ignored --untracked-files=normal`
   - `git -C <path> submodule status --recursive`
   - Probe:

     ```sh
     git -C <path> submodule foreach --recursive 'git status
     --porcelain --ignored --untracked-files=normal; git stash list; git rev-list --exclude=refs/tags/\* --glob=refs/\* --count --not --remotes || exit; git symbolic-ref -q HEAD >/dev/null || git rev-list HEAD --not --remotes --tags --count'
     ```

   Discard only reproducible configured-command output; preserve all else.
   Copy secrets (`.env`) outside `<path>` — never commit or push them.
   Preserve work in backup ref or external path. Before removal, `cd`
   to primary; stay; revalidate:

   ```sh
   node scripts/resume-claim-routing.mjs --issue <issue-number> \
     --claim-id <claim-id> --nonce <nonce> \
     --worktree <issue-worktree-path>
   ```

   `keep` / `already_owned` plus a matching lock means ours. Omitting
   `--worktree` (`owner_evidence_required` /
   `claim-id-match-without-independent-owner-evidence`) is incomplete:
   re-run with the flag. A remaining `stop` means do
   not remove the worktree. `git worktree remove --force` runs only
   after failure `working trees containing submodules cannot be moved
   or removed`, and only after leftovers are preserved. Revalidate
   `--worktree` immediately before that retry.
   [Removed-cwd](../../docs/idd-helper-scripts.md#f4-branch-failure-routes).
   Then:

   - `git worktree remove <path>`.
   - `git branch -d <branch-name>` (`-D` is denied; see
     `docs/permissions.md`). Local `{development-branch}`
     was fast-forwarded in step 4, so this shouldn't fail with
     `error: the branch '<branch-name>' is not fully merged`. If it
     still does, compare `git rev-parse <branch-name>` with `gh pr
     view {pr-number} --json state,headRefOid`: matching `MERGED`
     head → keep it, re-validate claim, comment: operator may run
     `git branch -D <branch-name>`, continue to step 6 (`Next action:
     none`); otherwise hold `local-branch-unmerged-commits`, stop
     before step 7, keep claim.

6. If GitHub auto-delete is disabled: delete the remote branch too.
   (WorkTrunk may run steps 5–6; step 4 stays a plain git operation.)
7. Re-validate the active claim before each mutation below. If it
   still uses your `{claim-id}`, upsert the claimed issue's own digest
   with `Phase: F4 complete`, `Claim: none`, `Branch: none`, `Open
   blockers: none`, `Next action: none`, and `Authoritative by`
   pointing to the merge commit — mirroring F3's own PR-digest
   upsert, but for the issue, so a closed/merged issue never sticks
   at a stale digest phase (`#3079`). Proceed only when
   the upsert reports `create`, `update`, or `noop`; on `duplicate` or
   any other failure, keep the claim, re-validate, then post a hold
   comment with the helper output, and stop for repair. Re-validate
   again; if it still uses your `{claim-id}`, for each issue in step
   1's closing set (none: skip), read
   `gh issue view {issue-number} --json state` once; if open,
   re-validate, then close it as step 1 does (a racing close counts); if
   either fails, hold as above with its error (no `unclaimed-by`, no
   retry). Then post `unclaimed-by` for your own
   `{agent-id}` / `{claim-id}` (see
   [Unclaim format](idd-overview-core.instructions.md#unclaim-format))
   to release the claim now that cleanup is complete (`#2220`). If
   either re-validation finds anything other than your `{claim-id}`
   — including no active claim — stop that mutation: the claim was
   lost.

## F5 — Loop

Return to `idd-discover.instructions.md` only when continuing in-process.
F4-complete/F5 is the **safe session-exit boundary**: under context
pressure, exit directly here; a fresh session re-enters Discover — see
the autopilot operating model in
[`docs/idd-workflow.md`](../../docs/idd-workflow.md).
