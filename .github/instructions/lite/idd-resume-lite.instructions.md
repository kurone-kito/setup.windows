# IDD — Resume Phase (Lite)

Lite profile for weak / local models. Same semantics as
`idd-resume.instructions.md`. Prefer helpers over prose.

**Load this file alone** for resume routing. Do not open the standard
resume file in the same turn.

## Helper runtime contract

1. **When helper runtime is enabled** (`package-manager`, vendored-node,
   or any profile that ships the helpers): run the commands below first.
   If a helper is **missing, fails, returns invalid JSON, or disagrees
   with live GitHub state** → **stop and ask**. Do **not** fall through
   to the written tables in that situation.
2. **When the repository is `instructions-only`** (no helper runtime
   shipped): skip the helper commands and use the written tables only.
   That is the sole path where the tables below are the primary control
   surface.

Never invent forced-handoff markers. Unattended sessions only
**consume** already-recorded human-gated forced-handoff evidence.

## Always run helpers first (helper-enabled profiles)

```sh
# Claim state (required before any mutation)
node scripts/resume-claim-routing.mjs --issue <N>

# Fresh-claim gate immediately before any claim write
node scripts/resume-claim-routing.mjs --issue <N> --fresh-claim-gate

# PR / CI / review resume route (when a PR may exist)
node scripts/resume-route-selection.mjs --issue <N>
```

Map helper fields to actions below.

## Required signals (collect once)

1. Active claim: `{claim-id}`, agent, branch, latest trusted `claimed-by`
   `created_at` — or unclaimed. Ignore untrusted marker authors.
2. Forced-handoff evidence (when present): approving human actor,
   displaced `{claim-id}`, branch, linked PR, evidence URL — only if
   `forced-handoff: human-gated` is recorded and authored by a trusted
   actor. When an open PR exists, require issue-plus-PR approval naming
   that PR. Record mismatches against live claim/branch/PR as Step 0
   STOP. Never invent or post forced-handoff markers from this session.
3. Open PR number + HEAD SHA, or `none`.
4. Latest activity `updatedAt` on issue/PR (comments, reviews, threads).
5. CI states for PR HEAD (or `none`).
6. `git worktree list`, local branch existence, worktree `git status`,
   unpushed commits, local HEAD SHA.

Use GitHub **server** timestamps only. Stale age default: **24 h**
(`claim-stale-age` / `claimTiming.staleAge`).

## Step 0 — Route classifier (first match wins)

| Condition                                                      | Action                                                                 |
| -------------------------------------------------------------- | ---------------------------------------------------------------------- |
| Issue closed or PR merged                                      | Step 1 cleanup only → STOP                                             |
| Valid human-gated forced-handoff matching live claim/branch/PR | Step 1 forced-handoff path (skip stall)                                |
| Forced-handoff evidence present but mismatches live state      | STOP — report mismatch; do not claim/push                              |
| Non-owned active claim, no valid forced-handoff                | Open `idd-resume-stall-lite.instructions.md`; return here if unblocked |
| Otherwise                                                      | Step 1                                                                 |

Quiet-window evidence never bypasses the 24 h stale threshold.

## Step 1 — Claim state (helper-first)

On helper-enabled profiles, run `resume-claim-routing.mjs --issue <N>`
(and stop-and-ask on failure — do not use the written table). Map:

| Helper `state` / `action`  | Action                                                                                           |
| -------------------------- | ------------------------------------------------------------------------------------------------ |
| `already_owned` / `keep`   | Keep same `{claim-id}` → Step 2 (if branch is `roadmap-audit/*`, A1.5 only → STOP)               |
| `unclaimed` / `re_claim`   | Fresh A5 claim → Step 2                                                                          |
| `stale` / `takeover`       | A5 takeover `supersedes: <prior-id>` → Step 2 (if branch is `roadmap-audit/*`, A1.5 only → STOP) |
| `non_inheritable` / `stop` | STOP — live competitor claim                                                                     |
| `disputed` / `stop`        | STOP — contested claim                                                                           |

After any helper map, still apply the `roadmap-audit/*` special case when
the active claim branch field starts with `roadmap-audit/`: coordination
only — re-run A1.5, skip worktree creation, STOP after roadmap-side
effects. Child-issue execution is not locked by that claim.

Written table (`instructions-only` profile only): first matching row.

| Claim state                                                                                 | Action                                                        |
| ------------------------------------------------------------------------------------------- | ------------------------------------------------------------- |
| Closed / PR merged                                                                          | Remove local worktree/branch → STOP                           |
| Active claim = this session's verified `{claim-id}` and branch starts with `roadmap-audit/` | Re-run A1.5 only → STOP                                       |
| Active claim = this session's verified `{claim-id}`                                         | → Step 2                                                      |
| Forced-handoff names this session's verified `{claim-id}` as displaced                      | STOP — displaced; no push/comment/resolve/merge               |
| Forced-handoff recovery confirmed for this session                                          | A5 re-claim after GitHub shows handoff → Step 2               |
| No active claim                                                                             | A5 re-claim → Step 2                                          |
| Active non-stale claim (other session, < 24 h)                                              | STOP                                                          |
| Active stale claim (other session, ≥ 24 h) and branch starts with `roadmap-audit/`          | A5 takeover `supersedes: <prior-id>`; re-run A1.5 only → STOP |
| Active stale claim (other session, ≥ 24 h)                                                  | A5 takeover `supersedes: <prior-id>` → Step 2                 |

All claim writes use A5 post-and-verify (`post-idd-marker` / claim helper
settle delay). Same-agent non-stale claims are **not** inheritable by
agent-id alone.

## Step 2 — Worktree

`{branch}` = active claim `branch:` field **verbatim**.

| Situation                               | Action                                                          |
| --------------------------------------- | --------------------------------------------------------------- |
| No worktree, PR or remote branch exists | Create sibling worktree for `{branch}` (B1 rules); install-deps |
| Worktree dirty with open reviews        | Stop and report; do not discard uncommitted work                |
| Worktree dirty, no reviews              | Finish or stash per operator policy; prefer stop-and-ask        |
| Worktree clean with unpushed commits    | → D1 / push path after claim revalidation                       |
| Worktree clean, no unpushed             | → Step 3                                                        |
| Multiple open PRs for the claim branch  | STOP — ambiguous                                                |
| No PR, no remote, no local branch       | → B1 fresh worktree                                             |

Primary worktree must stay on `main`. Never `git switch` the primary onto
the issue branch.

## Step 3 — PR / CI / review route (helper-first)

On helper-enabled profiles, run `resume-route-selection.mjs --issue <N>`
(and stop-and-ask on failure — do not use the written table). Map `route`:

| `route`                | Next phase                                                                            |
| ---------------------- | ------------------------------------------------------------------------------------- |
| `D1`                   | `idd-pr-submit-lite.instructions.md`, from D1 (sync/push/open PR)                     |
| `D4`                   | `idd-pr-submit-lite.instructions.md`, D4 section only (CI wait) — do not re-run D1-D3 |
| `E1` / `E15` / `Esync` | Review snapshot / CI wait / branch-sync                                               |
| `F1` / `F2`            | `idd-pre-merge-lite.instructions.md`, from the top (covers both F1 and F2)            |
| `stop`                 | STOP — report helper `reason`                                                         |

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

Stop and ask the operator when:

- helper runtime is expected but missing/failing;
- claim state is ambiguous or disputed;
- forced-handoff evidence is partial;
- worktree is dirty with unclear ownership;
- multiple PRs match the claim branch.

Do **not** run autonomous merge (F3+) on the lite tier.
