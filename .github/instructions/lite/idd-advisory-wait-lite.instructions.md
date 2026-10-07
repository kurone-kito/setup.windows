# IDD — Copilot Advisory-Wait Protocol (Lite)

Lite profile for helper-enabled weak/local models. Same semantics as
`idd-advisory-wait.instructions.md`, for E14 and E1 Step 2's advisory
precondition. E1 Step 2 accepts a matching `lastCopilotCommit` directly;
off-head `SATISFIED` requires active-claim `staleRequestRecovery` to be
`not-applicable` or its AW3-S/cap route complete. `hold` is ineligible.
If the repository is `instructions-only`, use the full-size
advisory-wait instructions instead.

## Helper runtime contract

- Helper-enabled profiles: use the named helper commands below. If the
  advisory-wait-state evidence/decision helper is missing, fails,
  returns invalid JSON, or disagrees with live state, stop and ask —
  never a manual per-field fetch or hand-derived decision. This
  doesn't restrict marker _posting_ — the manual JSON `POST` under
  Markers stays that step's canonical fallback.
- `instructions-only`: do not use this lite file.
- Any mismatch between this file and
  `idd-advisory-wait.instructions.md` is a bug in this file.

## Scope boundary (E1 Step 2 and E14; F2/F3 excluded)

This file covers E14 and E1's Step 2 precondition: fast/helper-first
paths plus terminal `SATISFIED`/phase-specific `CAP_EXHAUSTED`
eligibility. E1 does not inherit E14 request/poll actions. F2's
live-fetch fallback, F3's merge call, stall recovery, and same-HEAD
reroll are out of scope; E14's settled-elapsed case (`#2327`) has its
own table.

A lite session excludes A0-A4.5/E4-E8 and F3-F5; it uses only E1 Step
2, E14, lite F1-F2 read-only helpers, and F2.5 handoff-stop. If it
reaches an excluded call site, stop and ask a stronger session/human.

**Do not build a substitute wait for a non-primary bot** — same
prohibition as the full-size file's Scope section: rely on the
standard E1/review-watermark/F2/F3 safety net, never a custom poll on
any bot but `advisoryWait.primaryBotLogin`.

## Stop-and-ask conditions

- A required field is missing, the helper exits non-zero, returns
  invalid JSON, or its evidence disagrees with live state.
- `outcome` is `CAP_EXHAUSTED` with the `hold` route (`HOLD`'s only
  route — see Helper-first canonical path below).
- `earliestSameHeadAt` empties during active polling (marker
  disappeared).
- A pending Copilot request can't be refreshed, or an advisory-wait
  marker can't be posted or read.
- This file is reached from an F2 prose-fallback or F3 call site (see
  Scope boundary above).

## Fast path — common case

Run the Helper-first canonical path below. Once `lastCopilotCommit`
equals `prHeadSha`, the gate is **SATISFIED** — take the caller's
`SATISFIED` action. For off-head `SATISFIED`, apply the header's
`staleRequestRecovery`; lite hands off `attempt` for AW3-S.

## Helper-first canonical path

```sh
node scripts/advisory-wait-state.mjs --pr <pr-number> --claim-id <claim-id> \
  --agent-id <agent-id> \
  --trusted-marker-logins "<trusted-login-1>,<trusted-login-2>"
```

Resolve the package-manager / ephemeral-npx equivalent from
`docs/idd-helper-scripts.md`.

Required fields (stop and ask if any are missing): `prHeadSha`,
`lastCopilotCommit`, `copilotPending`,
`copilotPendingCoversHead`, `outcome`, `f3Outcome`, `secondaryBotLogin`,
`secondaryBotLogins`, `secondaryRequestLogins`, `secondaryRequestNeeded`,
`earliestSameHeadAt`, `requestMarkerCount`, `requestCap`,
`pendingWindowMinutes`, `settledWindowMinutes`, `pollIntervalMinutes`,
`capExhaustedRoute`, `trustedMarkerSummary`. Every field is always
present, even empty/false/`[]` — validate presence, not truthiness;
include `staleRequestRecovery`; reject unbound output.

The helper computes `outcome` directly from live evidence — never by
hand from raw timestamps. Allowed values: `SATISFIED`,
`REQUEST_NEEDED`, `RECOVERY_NEEDED`, `CAP_EXHAUSTED`, `WAIT`. `HOLD` is
caller-derived, never emitted.

The helper already resolves `advisoryWait.*` from
`.github/idd/config.json`, emitting final values in `requestCap`,
`pendingWindowMinutes`, `settledWindowMinutes`, `pollIntervalMinutes`,
and `capExhaustedRoute` — never read that config yourself. A missing
field here isn't "config absent" — it's a malformed helper response
(see Required fields above); stop and ask.

## E14 outcome → action

<!-- dprint-ignore-start -->
| Outcome | E14 action |
| --- | --- |
| `SATISFIED` | proceed to CI wait |
| `REQUEST_NEEDED` | `copilotPending`: false → registration-proven request + marker, then poll; true (no marker) → no `AW3-S` here — stop and ask |
| `RECOVERY_NEEDED` | post the recovery marker (do not request another review), then poll |
| `CAP_EXHAUSTED` | `phase-specific` (default): proceed to CI wait. `hold`: stop and ask (`HOLD`'s only route; see above) |
| `WAIT` | keep polling |
<!-- dprint-ignore-end -->

`capExhaustedRoute: phase-specific` lets E14 continue past
`CAP_EXHAUSTED`; F2/F3 always hold on it (excluded scope, above).

## Markers

Request (plain text, not an HTML comment):
`advisory-wait: {agent-id} {PR_HEAD_SHA} {ISO8601-requested-at}`.

Recovery (plain text):
`advisory-wait-recovery: {agent-id} {PR_HEAD_SHA} {ISO8601-recovery-time}`.
Rules: never request another review on this path; the clock is this
marker's own GitHub `created_at`, never an embedded timestamp; stop and
ask if it can't be posted or read.

Helper-first posting: `post-idd-marker --type advisory --target pr
<pr-number> --agent-id <id> --head-sha <sha> --timestamp <ts> --apply`
(request) or `--type advisory-recovery` with the same fields
(recovery). Resolve the package-manager equivalent from
`docs/idd-helper-scripts.md`. The manual JSON `POST` is the fallback
when the helper is unavailable.

Only a trusted marker actor's comment `created_at` counts for the
clock — never commit author/committer timestamps.

## Polling guidance (protocol-level only)

This section covers only what the AW3 protocol itself defines. Aborting
this wait early on a moved HEAD or new review activity is the caller's
own job (owned by `idd-review-fix-lite.instructions.md`'s E14; not
duplicated here).

1. Reuse the existing same-head marker (`earliestSameHeadAt`) instead
   of posting a new one, unless none exists yet.
2. Each cycle, at the `pollIntervalMinutes` interval, re-run the
   Helper-first canonical path for a fresh `outcome`.
3. If `earliestSameHeadAt` is now empty, stop and ask (see
   Stop-and-ask conditions).
4. If `outcome` is now `SATISFIED`, exit this wait and continue. The
   helper already folds `pendingWindowMinutes`/`settledWindowMinutes`
   into `outcome` on every call, including the stalled/rate-limited
   case — never re-derive that decision by hand from raw window
   values.
5. Otherwise (`outcome` is `WAIT`, or any other non-terminal value),
   keep polling.

## Secondary advisory bot(s) (non-gating, optional)

`secondaryBotLogin` accepts one login or a list. When
`secondaryRequestNeeded` is `true`, request **every** login in
`secondaryRequestLogins` once each (never only the first), using the
same mechanics above. Post no `advisory-wait:` marker for any — none
satisfy the primary gate or consume its cap. Skip when
`secondaryRequestNeeded` is `false`.

## Marker hygiene (optional)

After a new marker is verified to exist for the current HEAD, minimize
every trusted prior advisory-wait-family marker whose embedded HEAD
differs, as `OUTDATED`:

```sh
node scripts/minimize-superseded-markers.mjs \
  --subject-ids "<id1>,<id2>,..." \
  --classifier OUTDATED \
  --trusted-marker-logins "<login-1>,<login-2>" \
  --apply
```

Skip (not stop-and-ask) when the candidate set is empty or the helper
is unavailable — later cleanup catches leftovers.
