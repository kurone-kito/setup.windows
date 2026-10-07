# IDD — Resume Phase (Lite)

Lite profile for weak/local models. Same semantics as
`idd-resume.instructions.md`; load it alone for resume routing.

## Helper runtime contract

1. **When helper runtime is enabled** (`package-manager`, `ephemeral-npx`
   — see `docs/idd-helper-scripts.md` — or vendored-node): run the
   commands below. If a helper is **missing, fails, returns
   invalid JSON, or disagrees with live GitHub state** → **stop and
   ask**. Do **not** fall through to the written tables.
2. **When the repository is `instructions-only`** (no helper runtime
   shipped): skip the helper commands and use the written tables only.

## Always run helpers first (helper-enabled profiles)

```sh
# Claim state (before mutation)
node scripts/resume-claim-routing.mjs --issue <N> [--claim-id <id>] [--nonce <nonce>] [--worktree <path>]

# Fresh-claim gate immediately before any claim write
node scripts/resume-claim-routing.mjs --issue <N> --fresh-claim-gate

# PR / CI / review resume route (when a PR may exist)
node scripts/resume-route-selection.mjs --issue <N>
```

Pass `--claim-id` once this session recorded and verified one,
`--nonce` if this session recorded one for that claim-id, and
`--worktree` once the B1 worktree exists.

Map helper fields to actions below.

## Required signals (collect once)

Collect once: active `{claim-id}`/agent/branch from trusted markers (or
unclaimed); trusted `forced-handoff: human-gated` proof (actor, displaced
claim, branch, PR, URL; mismatches are Step 0 STOP); open PR+HEAD or
`none`; latest issue/PR activity; PR-HEAD CI; and local worktree/branch/
status/HEAD. When an open PR backs the claim, the proof must also have
`contextScope: issue-plus-pr` with `linkedPr` naming that live PR.
Never invent or post forced-handoff markers.

Use GitHub **server** timestamps only. Stale age default: **24 h**
(`claim-stale-age` / `claimTiming.staleAge`).

## Step 0 — Route classifier (first match wins)

| Condition                                                      | Action                                                            |
| -------------------------------------------------------------- | ----------------------------------------------------------------- |
| Issue closed or PR merged                                      | STOP — report; do not remove worktree/branch                      |
| Valid human-gated forced-handoff matching live claim/branch/PR | Step 1 forced-handoff path (skip stall)                           |
| Forced-handoff evidence present but mismatches live state      | STOP — report mismatch; do not claim/push                         |
| Non-owned active claim + operator-present + input received     | Operator-present path (below); skip stall                         |
| Non-owned active claim, no valid forced-handoff                | `idd-resume-stall-lite.instructions.md`; then Step 1 if unblocked |
| Otherwise                                                      | Step 1                                                            |

Quiet-window evidence never bypasses the 24 h stale threshold.

### Operator-present release

Predicate: claimant-authored comment after latest valid `claimed-by`
that records a deliberate pause and the same awaited input now
received here; no later trusted claimant heartbeat, branch/PR
movement, or comment/review (this path's step-1 comment excepted).
Else stall-lite. Steps 1-2 are pre-claim (stall windows do not apply).

1. Post the operator input as a normal comment; ask a human to drop
   any needs-decision/blocked-by-human label (never this session).
2. Re-read; if claim and predicate still hold, post a trusted
   `unclaimed-by` matching the held `{agent-id}` / `{claim-id}`.
3. Confirm unclaimed; else STOP.
4. Fresh-claim-gate; A5 `supersedes: none` → Step 1 with
   `--claim-id`/`--nonce` of that claim.

## Step 1 — Claim state (helper-first)

On helper-enabled profiles, run the Claim-state command above
(stop-and-ask on failure — do not use the written table). Map:

| Helper `state` / `action`          | Action                                                         |
| ---------------------------------- | -------------------------------------------------------------- |
| `already_owned` / `keep`           | Keep same `{claim-id}` → Step 2                                |
| `owner_evidence_required` / `stop` | Retry `--worktree <path>` once; else STOP unless §FH successor |
| `unclaimed` / `re_claim`           | Fresh A5 claim → Step 2                                        |
| `stale` / `takeover`               | Forced-handoff: retry below; else A5 takeover                  |
| `non_inheritable` / `stop`         | Forced-handoff: retry below; else STOP — live competitor claim |
| `disputed` / `stop`                | STOP — contested claim                                         |

`local_worktree_occupied` / `stop` → STOP — see §LWR; verify claim-id
against occupied, unreadable, or unknown local worktree state
(#3141).

Forced-handoff: pass `new_claim_id` into Step 1. On
`non_inheritable`/`stop`, `stale`/`takeover`, or
`local_worktree_occupied`/`stop` with `evidence.forced_handoff`, retry
`--claim-id <evidence.forced_handoff.new_claim_id>` before STOP.
Retry `already_owned`: STOP if `new_agent_id` is not this
session or `old_claim_id` is this session's claim (displaced).
Else adopt the pair; unless this session recorded a nonce for
`new_claim_id`, post one; wait settle; confirm the nonce winner;
Step 2.

After any helper map, `roadmap-audit/*` is still A1.5-only (no
worktree; child issues are not locked).

Written table (`instructions-only` profile only): first matching row.

| Claim state                                                                                 | Action                                                        |
| ------------------------------------------------------------------------------------------- | ------------------------------------------------------------- |
| Active claim = this session's verified `{claim-id}` and branch starts with `roadmap-audit/` | Re-run A1.5 only → STOP                                       |
| Active claim = this session's verified `{claim-id}`                                         | → Step 2                                                      |
| Forced-handoff names this session's verified `{claim-id}` as displaced                      | STOP — displaced; no push/comment/resolve/merge               |
| Forced-handoff recovery confirmed for this session                                          | A5 re-claim after GitHub shows handoff → Step 2               |
| Stale/released + local worktree occupied or unreadable                                      | STOP — see §LWR; verify owner                                 |
| No active claim                                                                             | A5 re-claim → Step 2                                          |
| Active non-stale claim (other session, < 24 h)                                              | STOP                                                          |
| Active stale claim (other session, ≥ 24 h) and branch starts with `roadmap-audit/`          | A5 takeover `supersedes: <prior-id>`; re-run A1.5 only → STOP |
| Active stale claim (other session, ≥ 24 h)                                                  | A5 takeover `supersedes: <prior-id>` → Step 2                 |

All claim writes use A5 post-and-verify (`post-idd-marker` / claim helper
settle delay). Same-agent non-stale claims are **not** inheritable by
agent-id alone.

## Step 2 — Worktree

`{branch}` = active claim `branch:` field **verbatim**.

| Situation                              | Action                                                          |
| -------------------------------------- | --------------------------------------------------------------- |
| PR exists, no worktree                 | Create sibling worktree (B1); install-deps, then re-match below |
| Remote branch, no PR, no worktree      | Create sibling worktree (B1); install-deps                      |
| Worktree dirty with open reviews       | Stop and report; do not discard uncommitted work                |
| Worktree dirty, no reviews             | Finish or stash per operator policy; prefer stop-and-ask        |
| Worktree clean with unpushed commits   | → D1 / push path after claim revalidation                       |
| Worktree clean, no unpushed            | → Step 3                                                        |
| Multiple open PRs for the claim branch | STOP — ambiguous                                                |
| No PR, no remote, no local branch      | → B1 fresh worktree                                             |

Primary worktree must stay on `main`. Never `git switch` the primary onto
the issue branch.

## Step 3 — PR / CI / review route (helper-first)

On helper-enabled profiles, run `resume-route-selection.mjs --issue <N>`
(and stop-and-ask on failure — do not use the written table). Map
`route`:

- `D1` → `idd-pr-submit-lite.instructions.md`, from D1 (sync/push/open
  PR)
- `D4` → `idd-pr-submit-lite.instructions.md`, D4 section only (CI
  wait) — do not re-run D1-D3
- `E1` → `idd-review-snapshot-lite.instructions.md`
- `E15` → `idd-review-fix-lite.instructions.md` E15 (invokes
  `idd-ci-lite.instructions.md` for polling)
- `Esync` → `idd-review-triage.instructions.md` **E-phase
  branch-sync check** (classification only). Redirect non-lite
  exits: `clean` → `idd-pre-merge-lite.instructions.md`; step 6 →
  `idd-review-snapshot-lite.instructions.md` (E1)
- `F1` / `F2` → `idd-pre-merge-lite.instructions.md`, from the top
  (covers both F1 and F2)
- `stop` → STOP — report helper `reason`

Before any mutation after routing: re-validate claim ownership, PR HEAD,
and CI live state.

Written table (`instructions-only` profile only):

| CI      | Reviews                                    | Action                |
| ------- | ------------------------------------------ | --------------------- |
| Running | none                                       | D4 CI wait → E1       |
| Running | exist                                      | E15 CI wait → E1      |
| Failed  | none / exist                               | D4 / E15 failure path |
| Success | unresolved / unreplied / CHANGES_REQUESTED | → E1                  |
| Success | clean reviews; branch clean                | → F2                  |
| Success | clean; branch behind only                  | → F1 then F2 or sync  |
| Success | content conflict                           | → Esync               |

Forced-handoff recovery on an open PR: final success still → **E1** until
this claim posts its own review-watermark and baseline.

## Claim revalidation (inline)

Before commit, push, claim heartbeat, or merge:

1. Active claim `{claim-id}` still matches this session.
2. Mutation cwd is the worktree for the claim `branch:` when in scope.

If claim lost: STOP. Do not post further operational markers.

## Stop-and-ask

Stop and ask when a helper is missing/failing, claim/forced-handoff
is ambiguous, the worktree is dirty, or multiple PRs match.
Do **not** run autonomous merge (F3+) on the lite tier.
