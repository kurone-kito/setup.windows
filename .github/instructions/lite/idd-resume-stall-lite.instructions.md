# IDD — Resume Stalled-Session Recovery (Lite)

Lite profile for weak / local models. Same semantics as
`idd-resume-stall.instructions.md`. Use only for a **non-owned** active
claim with **no** valid human-gated forced-handoff.

Enter from `idd-resume-lite.instructions.md` Step 0. After a successful
takeover, return to resume lite Step 1.

## Helper runtime contract

- **Helper-enabled profiles** (`package-manager`/`ephemeral-npx`/
  vendored-node: see `docs/idd-helper-scripts.md`): run the commands
  below. If a required helper is missing, fails, or disagrees with
  live state → **hold and stop** (do not claim). Do not invent a
  silent prose takeover path.
- **`instructions-only`**: use the written S1–S5 steps without helpers,
  still with a server-anchored `now` for the quiet window.

## Helper-first commands (helper-enabled profiles)

```sh
# Confirm non-owned claim
node scripts/resume-claim-routing.mjs --issue <N>

# Server-anchored now (required for quiet window)
SERVER_NOW=$(gh api repos/<owner>/<repo>/issues/<N> --include \
  | grep -i '^date:' | head -1 | sed 's/^[Dd]ate: *//' | tr -d '\r')
NOW=$(node -e "console.log(new Date(process.argv[1]).toISOString().replace(/\.\d{3}Z$/, 'Z'))" "$SERVER_NOW")

# Quiet-window evidence (always pass --now). Requires --pr; skip if none.
node scripts/stalled-session-quiet-check.mjs \
  --pr <pr-number> \
  --now "$NOW" \
  --claim-created-at <latest-valid-claimed-by-created_at>
```

No PR: do not invent `--pr`. Skip the helper (not a helper
failure). Decide S2 from the written bullets using the claim
`branch:` remote tip SHA and update time (no remote branch: treat
absence as no movement only if also absent at S2); S4 step 5 re-reads that tip
and repeats the written S2 checks against a fresh `NOW`; hold
on movement or incomplete evidence.

Never use the local wall clock as `now`. Re-derive a **fresh** `NOW`
before S4; do not reuse the S2 value.

## S1 — Is this a stall case?

| Condition                                                                                  | Action                                    |
| ------------------------------------------------------------------------------------------ | ----------------------------------------- |
| No active claim, or active claim is this session's `{claim-id}`                            | Return to resume lite                     |
| Valid forced-handoff matches the active claim or an inheritable released branch / PR state | Return to resume lite forced-handoff path |
| Active claim is another `{claim-id}`                                                       | Continue to S2                            |

## S2 — Quiet window (30 min, evidence only)

Require **no** external progress in the last 30 minutes:

- no trusted heartbeat on the active claim;
- no PR head or remote branch tip movement;
- no CI `queued` / `in_progress`;
- no new review/comment/CI completion activity.

Helper fields: `quiet_window_met`, `reason`, `latest_activity`.

| Result                                                         | Action                                                 |
| -------------------------------------------------------------- | ------------------------------------------------------ |
| `quiet_window_met` false, or incomplete/contradictory evidence | **Hold and stop** — no claim, push, or review mutation |
| `quiet_window_met` true                                        | Continue to S3                                         |

Quiet window alone never authorizes takeover.

## S3 — Stale threshold (ownership gate)

Takeover only if latest valid trusted `claimed-by` `created_at` is
**≥ 24 h** ago (`claim-stale-age`).

| Claim age | Action            |
| --------- | ----------------- |
| < 24 h    | **Hold and stop** |
| ≥ 24 h    | Continue to S4    |

`heartbeatOverdue` is **diagnostic only**. It does not shorten the 24 h
gate.

Before S4/posting, rerun helper; require `stale`/`takeover`,
`evidence.local_worktree.status: absent`; fail → **STOP** (#3141).

## S4 — Race-safe recheck (immediately before write)

1. Run `idd-claim-lite.instructions.md` pre-checks (d)/(e); either
   failing → STOP.
2. Re-run `resume-claim-routing.mjs --issue <N>`.
3. Active claim still the same non-owned `{claim-id}`.
4. Still stale (≥ 24 h) now.
5. Fresh server `NOW` + re-run quiet-check (no PR: written S2, not
   helper); if new activity, STOP and restart from resume discovery.
6. Issue still open; PR not merged.
7. Plan A5 takeover with settle delay (`claim.verifySettleDelay`, default
   `PT5S`) and same-second claim-id tie-break.

Any failure → STOP and restart. Do not post takeover on stale evidence.

## S5 — Takeover

Route through `idd-claim-lite.instructions.md`: pre-checks (a)-(e) in
full, then Claim execution with `supersedes: <prior-claim-id>`
(`--record-tokens` before the post and the activation-nonce), then
Claim verification.

Lost → STOP. Verified → return to `idd-resume-lite.instructions.md`
Step 1 with `--claim-id`/`--nonce`.

## Hold behavior

On S2/S3 hold, missing helper, unanchored timestamps, or ambiguous
claim/forced-handoff: session log only (no issue/PR comment); on
`local_worktree_occupied` (S3/S4), include §LWR fields
(`docs/idd-resume-detail.md`). Never invent forced-handoff consent.
