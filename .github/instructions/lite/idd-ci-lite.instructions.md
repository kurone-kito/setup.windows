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
- `requiredChecks.status` is `source-pinned` (a real, pinned gating
  check whose provenance the helper cannot verify — its name may be
  unresolvable, or resolvable-and-passing but not confirmably from the
  pinned source).
- `requiredChecks.status` is `unreadable` (a protection/ruleset read
  could not be determined) — never fall back to `checks[]`.
- A non-pass check is not clearly code-caused or recognized
  infra-flaky/pre-existing, except the sole-failing
  `idd-advisory-convergence` exception the caller's own routing names.
- The rerun budget (`ciWait.rerunPolicy`) is already exhausted for the
  current failure.
- Every job in every workflow fails near-instantly with an identical
  platform banner (an Actions billing/spend-limit block).
- **Exception — provider outage** (`providerHealth` `unavailable`) as
  sole blocker: park, don't stop-and-ask, then release the claim — see
  `docs/idd-helper-scripts.md#provider-outage-park-helper`.
- A running check never reports `startedAt` and `ciWait.generationTimeout`
  elapses with still no `startedAt`.

## Helper-first canonical path

1. Resolve policy: `node scripts/ci-wait-policy.mjs` (append
   `--run-id <run-id>` — preferred, derives the rerun budget from
   `run_attempt` — or `--rerun-count <count>` as a manual fallback).
   Resolve the package-manager / ephemeral-npx equivalent from
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
emits these; not values to derive by hand. Distributed fallbacks when
the repository sets no `ciWait.*` config: `runningTimeout` `PT30M`
(max time a required check may stay running, from its server
`startedAt`), `generationTimeout` `PT10M` (max time to wait for a
required check to appear, or for `startedAt` to appear on a
started-less running state), `rerunPolicy` `rerun-once` (the first
eligible infra/stalled route reruns once; `hold` always stops and asks
instead).

## Required-check discovery

Never derive this by hand — the Helper-first canonical path's
`ci-wait-state` call already resolves the required-check set as
`requiredChecks`; manual `gh api .../rulesets` / `.../protection`
derivation belongs only to `idd-ci.instructions.md` (the full-size
CI-polling shared helper file), never this one. Read
`requiredChecks.status`:

- `success`: every required check passed — proceed per Interpretation
  below.
- `pending` or `missing`: keep polling (a required check is still
  running, or one expected has not posted a result yet).
- `failing`: at least one required check is non-passing — apply
  Interpretation below to it.
- `no-required-checks`: a repository can legitimately have none while
  still running normal CI — fall back to `checks[]`'s own per-check
  `status` (already bucketed by the helper as `success` / `pending` /
  `failure` / `unknown`, distinct from step 2's raw-state normalization
  below): every entry `success` → proceed; any `pending`/`unknown` →
  keep polling (`unknown` isn't settled yet, so treat it like
  `pending`); any `failure`, or `checks[]` itself empty → stop and ask.
  Never treat an empty required-check set as a vacuous pass.
- `source-pinned`: stop and ask (see Stop-and-ask conditions above).
- `unreadable`: stop and ask (see Stop-and-ask conditions above).

## Polling algorithm

1. Fetch checks with the Helper-first canonical path above — never
   `gh pr checks` directly, since it can collapse same-named checks
   across workflows.
2. Normalize states: `skipped` / `neutral` / `not_applicable` → pass;
   `pending` / `requested` / `waiting` / `queued` / `in_progress` /
   Commit-Status `expected` → running; `failure` / `cancelled` /
   `timed_out` / `action_required` / `startup_failure` / `stale` →
   non-pass.
3. Evaluate only checks in the required-check set — except the
   `no-required-checks` fallback above, which evaluates every present
   check instead.
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
- Required `idd-advisory-convergence` runs use `pull_request` /
  `pull_request_target`; the non-required companion
  `idd-advisory-convergence-comment.yml` handles Copilot
  `pull_request_review` submissions, IDD-originated
  `pull_request_review_comment`, and qualifying `issue_comment` events.
  Its bot-triggered run can be `action_required`
  and cannot refresh the required check. For a review submission use
  `--refresh-latest --apply`; comment paths use plain `--apply`. Only
  IDD-originated review-thread replies or qualifying IDD-originated PR
  comments refresh; ordinary comments/replies are filtered.
- The required `idd-advisory-convergence` workflow's `workflow_dispatch`
  trigger does not reliably refresh the PR's
  required-check rollup for the current HEAD SHA. Rerun the existing
  non-bot PR-linked run for that HEAD instead of dispatching a new one;
  never rerun a gated bot run.
- Rerun same-HEAD `CANCELLED` siblings marked `rerun-eligible`.
  Ordinary plans hold `action_required`, `pending`, `unresolved`,
  `awaiting-fresh-review`, `rerun-budget-held`. If every withheld
  instance is a live-coverage recovery that was not promoted with used
  `rerun-once` budget (#3504), run `--refresh-latest --apply` once; poll;
  `hold` or mixed cases hold.
- Helper-first diagnosis (read-only): `node
  scripts/rerun-advisory-convergence.mjs --pr <n>`. Resolve the
  package-manager equivalent from `docs/idd-helper-scripts.md`.

## Wake-up discipline

Schedule one wake at the expected completion interval, or background
the wait only when the topology is confirmed to route completion back
to this turn; otherwise wait synchronously. Before a heavy local
command expected to run long, set an execution-timeout override — the
tool's own per-invocation timeout (e.g. Claude Code's Bash
`timeout` parameter), not an in-command utility (issue `#3449`) —
near the tool's ceiling, not its default (`#2933`). Never blindly
re-issue
an already-backgrounded heavy command — check first if it's still
running, then await or reuse it. Batch every post-wait
action (disposition, replies, marker, next gate) into one turn. Do not
insert "is it done yet?" turns. Never end a turn on a future-tense wait
promise ("I will wait...") with no wait mechanism actually armed — arm
one of the mechanisms above first. No wait mechanism here may poll a
non-primary bot's review state either — see
`idd-advisory-wait-lite.instructions.md`'s Scope boundary section.
