# IDD — CI Polling (Shared Helper)

Read this file when you need to wait for CI after a push. Callers
define their own **on-success** target before invoking this algorithm.

The shared CI wait defaults are listed in
[IDD policy constants](../../docs/policy-constants.md). Resolve via
`.github/idd/config.json` `ciWait.runningTimeout`,
`ciWait.generationTimeout`, and `ciWait.rerunPolicy` when present and
valid; otherwise keep the distributed defaults (`PT30M`, `PT10M`,
`rerun-once`).

When helper support is installed, use the profile-selected ci-wait
policy helper command as the canonical read-only policy resolver.

```sh
# source repo / vendored-node profile
node scripts/ci-wait-policy.mjs

# package-manager / ephemeral-npx profile
<profile-selected-ci-wait-policy-command>
```

Append `--rerun-count <count>` when the caller needs the deterministic
rerun-budget decision. Resolve
`<profile-selected-ci-wait-policy-command>` from
`docs/idd-helper-scripts.md`. Do not hardcode
`node scripts/ci-wait-policy.mjs` for profiles that don't vendor
`scripts/`.

## Shared policy keys

- `ciWait.runningTimeout`: max time polling a running required check
  before stalled-run recovery begins. Default: `PT30M` (30 min).
- `ciWait.generationTimeout`: max time to wait for required checks to
  appear at all. Default: `PT10M` (10 min).
- `ciWait.rerunPolicy`: rerun budget for infra/stalled CI recovery.
  Default: `rerun-once` — the first eligible infra/stalled route reruns
  exactly once, the next recurrence holds. `hold` — never auto-rerun;
  post a hold at the first eligible route.

## Inputs

Before polling, collect:

1. PR number and current PR head SHA.
2. The required-check set for the target base branch.
3. Current check/run statuses for the same head SHA.

Use GitHub server timestamps and states only.

## Required-check discovery

Determine required checks from branch protection or rulesets before
interpreting `gh pr checks` output.

1. Fetch ruleset summaries:

   ```sh
   gh api repos/{owner}/{repo}/rulesets --paginate
   ```

2. Fetch each ruleset detail:

   ```sh
   gh api repos/{owner}/{repo}/rulesets/{ruleset-id}
   ```

   Use detail payload rules only from enforcing rulesets that apply to
   the PR base branch.

3. Fetch branch protection checks for the base branch too (do not treat
   this as mutually exclusive with rulesets). URL-encode branch names
   before calling this endpoint:

   ```sh
   gh api repos/{owner}/{repo}/branches/{url-encoded-base-branch}/protection
   ```

4. **Distinguish a permission error from a genuine empty result** on
   each of the three reads above. (Ruleset-**detail**, step 2, only
   runs once per ruleset ID step 1 already returned, so an empty step-1
   list means step 2 is skipped, not called with an empty result.) A
   `403` on any of the three reads means the read itself failed — the
   token lacks permission — not that no required checks exist; never
   substitute an empty array/object for it. Record it as **unreadable**.

   **Treat every `404` on these reads exactly like a `403` by
   default.** None of the three endpoints documents `403` as a possible
   response at all, so a `404` is _structurally_ ambiguous between
   "genuinely nothing configured" and "the token cannot read this" —
   see
   [design rationale](../../docs/idd-design-rationale.md#404-vs-403-ambiguity-on-branch-protectionruleset-reads)
   for the full GitHub-documentation citations behind this rule. A
   repository may opt out and restore the pre-`#1377` trusting behavior
   (a `404` on these reads is genuinely empty) by recording
   `ciGate.trustEmptyProtectionReads: true` in `.github/idd/config.json`
   — a git-committed, human-authorized policy decision, not a runtime
   check of the caller's token scope. Absent or `false` keeps the
   fail-closed default.

   If any of the three reads is **unreadable** (a confirmed `403`, or
   an untrusted `404` per above), **fail closed**: do not fall through
   to step 6 below. Post a hold comment stating "cannot determine
   required checks: protection/ruleset unreadable" and stop. This is
   distinct from the genuine `noRequiredChecksConfigured` case in step
   6, which requires every read to have returned a genuine, trusted
   result — a `200`, or a `404` trusted under
   `ciGate.trustEmptyProtectionReads` — never an unreadable one.

5. Build the required-check set as the union of enforcing-ruleset checks
   and branch-protection checks, using only the genuine (readable, not
   unreadable) results from step 4. Keep expected check source metadata
   (GitHub App/integration) when configured.

6. If neither source yields a required-check set, and step 4 found no
   unreadable result: **not** automatically a hold — it's the same
   `noRequiredChecksConfigured: true` state F2's CI gate already
   interprets (`idd-pre-merge.instructions.md`). Reuse
   `pre-merge-readiness`'s `ci.presentRunConclusion` when available;
   otherwise derive the equivalent from actual runs at the head SHA:
   `all-passing` may proceed; `pending` → wait/re-check; `some-failing`
   or `none` (no runs) → **hold** — never treat an empty required-check
   set as a vacuous pass. Full routing table:
   [F2 — Pre-merge condition check](idd-pre-merge.instructions.md#f2--pre-merge-condition-check).

When caller phases already provide a trusted required-check set, reuse
that set instead of re-deriving it.

## Polling algorithm

1. Fetch current checks for the PR:

   ```sh
   gh pr checks {pr-number} --json name,state,bucket,startedAt,completedAt,link
   ```

   **Duplicate-name-safe, HEAD-pinned reads**: `gh pr checks` can collapse
   same-named checks across workflows. When helper support is installed,
   read the profile-selected `ci-wait-state` snapshot instead (keyed by
   `(checkName, workflowName)`, live `headRefOid`); see
   `docs/idd-helper-scripts.md`.

   ```sh
   # source repo / vendored-node profile
   node scripts/ci-wait-state.mjs --pr {pr-number}

   # package-manager / ephemeral-npx profile
   <profile-selected-ci-wait-state-command> --pr {pr-number}
   ```

2. Normalize check states:
   - treat `skipped`, `neutral`, and `not_applicable` as pass-equivalent
   - treat `pending`, `requested`, `waiting`, `queued`,
     `in_progress`, and the Commit-Status `expected` state as running
   - keep `failure`, `cancelled`, `timed_out`, `action_required`,
     `startup_failure`, and `stale` as non-pass
3. Evaluate only checks in the required-check set, and match expected
   check source when the required definition includes an app/integration
   constraint.
4. Repeat at a reasonable interval until a terminal route in the table
   below is reached.

Measure each running check's `ciWait.runningTimeout` window from its
server `startedAt`. When absent (a queued check not yet started), the
running-timeout hasn't begun: keep polling, capped at
`ciWait.generationTimeout`. Some running states (e.g. a Commit-Status
`expected` context) never report `startedAt` — when
`ciWait.generationTimeout` elapses with still none, post a hold and
escalate rather than poll indefinitely. Never anchor the window to a
client clock.

Do not rely on `gh pr checks` command exit code as the gate decision.
The decision must be based on normalized required-check states.

## Rerun mechanics

When the resolved `ciWait.rerunPolicy` says rerun, rerun the exact
failed or stalled run:

- rerun whole run: `gh run rerun <run-id>`
- rerun failed jobs only: `gh run rerun --failed <run-id>`

Extract `<run-id>` from the failing check `link` field (for example:
`https://github.com/{owner}/{repo}/actions/runs/<run-id>/job/<job-id>`),
or query the Actions API for runs filtered to the current PR head SHA and
check name.

If GH CLI cannot resolve a run ID, use Actions REST endpoints directly
for the same run before posting a hold.

**`idd-advisory-convergence` specifically** (when hosted as a required
check): `workflow_dispatch` does **not** reliably refresh the PR's
required-check rollup for current HEAD — a manually dispatched run has
no `pull_request` context to associate with the PR's HEAD SHA (full
investigation: this repo's dogfooded
[`.github/workflows/idd-advisory-convergence.yml`](https://github.com/kurone-kito/idd-skill/blob/main/.github/workflows/idd-advisory-convergence.yml)
header comment — not present in the portable stub this template
ships). For a stuck or stale rollup entry, apply the rerun mechanic
above (`gh run rerun <run-id>` on the _existing_ PR-linked run)
instead of `workflow_dispatch`.

A second cause: GitHub gates a bot-triggered run (e.g. Copilot's
`pull_request_review`/`pull_request_review_comment` event) to
`action_required`, and the bot event alone never refreshes the check.
Recover by rerunning the _existing_ non-bot `pull_request`-triggered
run for this HEAD (subject to `ciWait.rerunPolicy`) — never the gated
bot run itself, which keeps the original actor's privileges and
re-enters `action_required` (approve via `POST
/repos/{owner}/{repo}/actions/runs/{run_id}/approve` if it must run).
The check also self-heals on the next non-bot trigger — a push or a
**review-thread** reply, not a regular PR comment (no `issue_comment`
subscription).

**Helper-first**: prints this diagnosis and ordered rerun plan, read-only.

```sh
# source repo / vendored-node profile
node scripts/rerun-advisory-convergence.mjs --pr <n>

# package-manager / ephemeral-npx profile
<profile-selected-rerun-advisory-convergence-command> --pr <n>
```

Resolve `<profile-selected-rerun-advisory-convergence-command>` from
`docs/idd-helper-scripts.md`; do not hardcode `node scripts/...` for
non-vendored profiles.

**Terminal-waiver recheck (`#1570`)**: once a maintainer waives a proven
`COPILOT_UNAVAILABLE` state
([Terminal routing](idd-advisory-wait.instructions.md#terminal-routing-1570)),
rerun this SAME existing run via the mechanic above — never
`workflow_dispatch`.

## Interpretation

<!-- dprint-ignore-start -->
| State (required checks only, normalized) | Action |
| --- | --- |
| All required checks are generated and pass-equivalent | → **on-success** (caller-defined) |
| Any required check is non-pass `failure`, `action_required`, `startup_failure`, or `stale` | Inspect the log. Infra/flaky: apply `ciWait.rerunPolicy` (default `rerun-once`) — rerun the exact failed run once and resume polling, or hold and stop. Code-caused: fix, **fix-validate**, commit atomically, return to caller's pre-push step. `action_required`/`startup_failure`/`stale` rarely clear on a blind rerun — if it needs a maintainer action or fresh run, hold rather than loop reruns. Exception: `idd-advisory-convergence` stuck at `action_required` from a gated bot run recovers by rerunning the existing run per `ciWait.rerunPolicy` (see §Rerun mechanics). Exception 2: `idd-advisory-convergence` alone non-pass with `pending: false` and outstanding review reasons — D4/E15 exit to E1 (both carve out a just-posted maintainer waiver, which still needs the rerun — see D4); F2/F3 unaffected. |
| Any required check is non-pass `cancelled` or `timed_out` | Code-caused: fix, **fix-validate**, commit atomically, return to caller's pre-push step. Infra-caused: apply `ciWait.rerunPolicy`; rerun/re-push only within budget, otherwise hold and stop. |
| Any required check is running (`pending`/`requested`/`waiting`/`expected`/...) | Continue waiting. After `ciWait.runningTimeout` (from server `startedAt`; default 30 min) with no completion, apply `ciWait.rerunPolicy` — rerun once and resume, or hold and stop if the route recurs or policy is `hold`. |
| Required checks are not generated after `ciWait.generationTimeout` | Treat as running (default 10 min). If the workflow run doesn't exist at all when that window elapses, hold and escalate to a maintainer, then stop. |
<!-- dprint-ignore-end -->

## Hold-and-report failure shapes

Recognize this shape in one pass; hold-and-report instead of the
infra-vs-code triage above:

- **Account-level Actions billing / spend-limit block**: every job in
  every workflow fails near-instantly with an identical platform banner
  (the run starts but no steps execute, unlike a normal step failure).
  Non-transient — a rerun reproduces it, no code change fixes it. Skip
  `ciWait.rerunPolicy`; post a hold comment naming the block and stop for
  a maintainer.

## Wake-up discipline

This advisory, tool-agnostic note keeps the **wait itself cheap**: the
dominant cost is each re-invocation's context re-read (worse past the
prompt-cache TTL), not the idle time.

**Portability**: under supervisor/worker topologies, a background
wait's completion notification often reaches only the supervisor, so
the worker's turn stalls until re-prompted — the topology-safety
condition below accounts for this.

- **No interim polling turns** — schedule one wake at the **expected**
  completion, or background only if the topology is confirmed to route
  completion back to this turn; otherwise wait synchronously. Never
  insert "is it done yet?" turns or end this turn assuming an
  unconfirmed background/async notification resumes it — that stalls
  silently under supervisor/worker topologies.
- **Batch post-wait actions** into one turn once the wait resolves
  (disposition, replies, marker, next gate together).
- **Scope post-fix re-validation** to the changed surface when provably
  outside the full build/test suite, instead of re-running everything.

This trims only wasteful dimensions (context re-read, CI minutes) —
review rounds stay full. Same discipline applies to the advisory-wait
and review-fix wait points.

**Known residual risk**: workers can still stall here — expected and
budgeted. Recovery: one message citing live state (PR number, check
states, local worktree HEAD SHA).
