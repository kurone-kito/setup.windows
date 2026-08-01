# IDD — Resume Stalled-Session Recovery (Lite)

Lite profile for weak / local models. Same semantics as
`idd-resume-stall.instructions.md`. Use only for a **non-owned** active
claim with **no** valid human-gated forced-handoff.

Enter from `idd-resume-lite.instructions.md` Step 0. After a successful
takeover, return to resume lite Step 1.

## Helper runtime contract

- **Helper-enabled profiles**: run the commands below. If a required
  helper is missing, fails, or disagrees with live state → **hold and
  stop** (do not claim). Do not invent a silent prose takeover path.
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

# Quiet-window evidence (always pass --now)
node scripts/stalled-session-quiet-check.mjs \
  --pr <pr-number> \
  --now "$NOW" \
  --claim-created-at <latest-valid-claimed-by-created_at>
```

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

Helper fields to read: top-level `quiet_window_met`, `reason`,
`latest_activity`; nested under `evidence`: `has_heartbeat_in_window`,
`has_ci_running`, `has_branch_tip_movement`.

| Result                                                         | Action                                                 |
| -------------------------------------------------------------- | ------------------------------------------------------ |
| `quiet_window_met` false, or incomplete/contradictory evidence | **Hold and stop** — no claim, push, or review mutation |
| `quiet_window_met` true                                        | Continue to S3                                         |

Quiet window alone never authorizes takeover.

## S3 — Stale threshold (ownership gate)

Takeover only if latest valid trusted `claimed-by` `created_at` is
**≥ 12 h** ago (`claim-stale-age`).

| Claim age | Action            |
| --------- | ----------------- |
| < 12 h    | **Hold and stop** |
| ≥ 12 h    | Continue to S4    |

`heartbeatOverdue` is **diagnostic only**. It does not shorten the 12 h
gate.

## S4 — Race-safe recheck (immediately before write)

1. Re-run `resume-claim-routing.mjs --issue <N>`.
2. Active claim still the same non-owned `{claim-id}`.
3. Still stale (≥ 12 h) now.
4. Fresh server `NOW` + re-run quiet-check; if new activity, STOP and
   restart from resume discovery.
5. Issue still open; PR not merged.
6. Plan A5 takeover with settle delay (`claim.verifySettleDelay`, default
   `PT5S`) and same-second claim-id tie-break.

Any failure → STOP and restart. Do not post takeover on stale evidence.

## S5 — Takeover

1. Post claim with fresh `{claim-id}` and `supersedes: <prior-claim-id>`
   via `post-idd-marker --type claim ... --apply` (or equivalent).
2. Wait settle delay; re-parse; confirm active claim is yours.
3. If lost: STOP.
4. If verified: return to `idd-resume-lite.instructions.md` Step 1, then
   Step 2/3.

## Hold behavior

On S2/S3 hold: **do not** post hold comments on the issue/PR (that can
reset quiet-window evidence). Log evidence in the session only and stop.

## Hold-and-stop (no issue/PR hold comment)

**Hold and stop** (session log only — same rule as Hold behavior above)
when helper runtime is expected but unavailable, when timestamps cannot
be server-anchored, or when claim/forced-handoff state is ambiguous.
Never invent forced-handoff consent.
