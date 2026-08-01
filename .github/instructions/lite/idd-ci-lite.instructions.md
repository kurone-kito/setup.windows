# IDD — CI Polling (Lite)

Lite profile for helper-enabled weak/local models. Same semantics as the
full-size CI-polling shared helper file. Used by lite phase files that wait for
CI after a push (e.g., `idd-review-fix-lite.instructions.md`'s E15
step). If the repository is `instructions-only`, use the full-size
CI-polling instructions instead of this file.

## Helper runtime contract

- Helper-enabled profiles: use the named helper commands below. If a
  required helper is missing, fails, returns invalid JSON, or disagrees
  with live state, stop and ask — never fall back to a manual per-field
  fetch or prose judgment.
- `instructions-only`: do not use this lite file.
- Any mismatch between this file and the full-size CI-polling shared
  helper file is a bug in this file.

## Stop-and-ask conditions

- A required helper is missing, fails, returns invalid JSON, or
  disagrees with live state.
- Any required-check discovery read below is unreadable (a confirmed
  `403`, or an untrusted `404`) — the ruleset list, any per-ruleset
  detail call, or the branch-protection read.
- A non-pass check is not clearly code-caused or recognized
  infra-flaky/pre-existing, except the sole-failing
  `idd-advisory-convergence` exception the caller's own routing names.
- The rerun budget (`ciWait.rerunPolicy`) is already exhausted for the
  current failure.
- Every job in every workflow fails near-instantly with an identical
  platform banner (an Actions billing/spend-limit block).
- A running check never reports `startedAt` and `ciWait.generationTimeout`
  elapses with still no `startedAt`.

## Helper-first canonical path

1. Resolve policy: `node scripts/ci-wait-policy.mjs` (append
   `--rerun-count <count>` for the rerun-budget decision). Resolve the
   package-manager / ephemeral-npx equivalent from
   `docs/idd-helper-scripts.md`. This helper already resolves
   `ciWait.*` from `.github/idd/config.json` and emits the final
   `runningTimeout` / `generationTimeout` / `rerunPolicy` values
   directly — never read that config file yourself.
2. Fetch duplicate-name-safe, HEAD-pinned check state:
   `node scripts/ci-wait-state.mjs --pr {pr-number}` (or the
   package-manager equivalent).
3. If either helper is unavailable, exits non-zero, or returns
   invalid/incomplete JSON, stop and ask.

## Timing defaults

For context only — the policy helper above already resolves and
emits these; the distributed defaults below are what it falls back to
when the repository sets no `ciWait.*` config, not values to derive by
hand:

- `ciWait.runningTimeout`: `PT30M` — max time a running required check
  may stay running, measured from its server `startedAt`, before the
  stalled-run route applies.
- `ciWait.generationTimeout`: `PT10M` — max time to wait for required
  checks to appear at all, or for a `startedAt` to appear on a
  started-less running state.
- `ciWait.rerunPolicy`: `rerun-once` — the first eligible infra or
  stalled route reruns exactly once; the next recurrence stops and
  asks. `hold` never auto-reruns; it stops and asks at the first
  eligible route.

## Required-check discovery

Before interpreting checks, determine the required-check set:

1. `gh api repos/{owner}/{repo}/rulesets --paginate`, then
   `gh api repos/{owner}/{repo}/rulesets/{ruleset-id}` for each id
   returned.
2. `gh api repos/{owner}/{repo}/branches/{url-encoded-base-branch}/protection`.
3. A `403` on any of these reads is unreadable — stop and ask; never
   substitute an empty result. Treat a `404` the same as a `403`
   (unreadable) unless `.github/idd/config.json` sets
   `ciGate.trustEmptyProtectionReads: true`, in which case a `404`
   means genuinely empty.
4. Union the enforcing-ruleset checks and branch-protection checks from
   the genuine (non-unreadable) reads only.
5. If neither source yields a required-check set and no read was
   unreadable, derive from the PR head SHA's actual runs instead: all
   passing → proceed to the caller's on-success target; any pending →
   keep polling; any failing, or no runs at all → stop and ask. Never
   treat an empty required-check set as a vacuous pass.

## Polling algorithm

1. Fetch checks with the Helper-first canonical path above — never
   `gh pr checks` directly, since it can collapse same-named checks
   across workflows.
2. Normalize states: `skipped` / `neutral` / `not_applicable` → pass;
   `pending` / `requested` / `waiting` / `queued` / `in_progress` /
   Commit-Status `expected` → running; `failure` / `cancelled` /
   `timed_out` / `action_required` / `startup_failure` / `stale` →
   non-pass.
3. Evaluate only checks in the required-check set.
4. Repeat at a reasonable interval until a terminal outcome below is
   reached. Anchor every timeout to the check's own server `startedAt`,
   never a client clock.

## Interpretation

- All required checks generated and pass-equivalent → the caller's
  on-success target.
- Any non-pass `failure` / `action_required` / `startup_failure` /
  `stale`: if code-caused, fix it, run **fix-validate**, commit
  atomically, then return to the caller's pre-push step. If
  infra-flaky, apply `ciWait.rerunPolicy` (rerun the exact run once and
  resume polling, or stop and ask on `hold`). `action_required` /
  `startup_failure` / `stale` rarely clear on a blind rerun — stop and
  ask, except the `idd-advisory-convergence` gated-bot-rerun case named
  in Rerun mechanics below.
- Any non-pass `cancelled` / `timed_out`: same code-caused vs.
  infra-caused split as above.
- Any required check running: keep polling. After
  `ciWait.runningTimeout` elapses with no completion, apply
  `ciWait.rerunPolicy` once; the same route recurring after that rerun,
  or a `hold` policy, is a stop-and-ask.
- Required checks not yet generated: treat as running, capped at
  `ciWait.generationTimeout`. If the workflow run does not exist at all
  when that window elapses, stop and ask.

## Rerun mechanics

- Rerun the exact failed or stalled run: `gh run rerun <run-id>` (whole
  run) or `gh run rerun --failed <run-id>` (failed jobs only). Extract
  `<run-id>` from the failing check's `link` field, or query the
  Actions API for runs filtered to the current PR head SHA and check
  name.
- `idd-advisory-convergence`'s own `workflow_dispatch` trigger does not
  reliably refresh the PR's required-check rollup for the current HEAD
  SHA. Rerun the existing PR-linked run for the current HEAD instead of
  dispatching a new one.
- A gated bot-triggered run (for example, Copilot posting its review)
  can stick at `action_required`. Rerun the existing non-bot run that
  already executed for this HEAD, subject to `ciWait.rerunPolicy`;
  never rerun the gated bot run itself.
- Helper-first diagnosis (read-only): `node
  scripts/rerun-advisory-convergence.mjs --pr <n>`. Resolve the
  package-manager equivalent from `docs/idd-helper-scripts.md`.

## Wake-up discipline

Schedule one wake at the expected completion interval, or background
the wait only when the topology is confirmed to route completion back
to this turn; otherwise wait synchronously. Batch every post-wait
action (disposition, replies, marker, next gate) into one turn. Do not
insert "is it done yet?" turns.
