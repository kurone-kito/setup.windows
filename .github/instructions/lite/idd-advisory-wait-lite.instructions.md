# IDD — Copilot Advisory-Wait Protocol (Lite)

Lite profile for helper-enabled weak/local models. Same semantics as
the full-size Copilot advisory-wait protocol file, restricted to the
**E14-caller subset only**. Used by
`idd-review-fix-lite.instructions.md`'s E14 step, and read (fast-path
fields only) by `idd-review-snapshot-lite.instructions.md`'s E1
CI-completion precondition. If the repository is `instructions-only`,
use the full-size advisory-wait instructions instead of this file.

## Helper runtime contract

- Helper-enabled profiles: use the named helper commands below. If the
  advisory-wait-state evidence/decision helper is missing, fails,
  returns invalid JSON, or disagrees with live state, stop and ask —
  never fall back to a manual per-field fetch or a hand-derived
  decision. This does not restrict marker _posting_: the manual JSON
  `POST` under Markers below is the established canonical fallback for
  that mechanical step, not a decision-making shortcut.
- `instructions-only`: do not use this lite file.
- Any mismatch between this file and the full-size advisory-wait
  protocol file is a bug in this file.

## Scope boundary (F2/F3 excluded)

This file covers only the E14 caller: the fast path, the helper-first
canonical path, and the outcome table's E14 column. It does **not**
cover, and a lite session must never attempt:

- F2's live-fetch-plus-prose fallback for when the merge-readiness
  helper is unavailable, invalid, or discarded.
- F3's merge-time call site.
- The terminal Copilot stall-recovery contract (bounded stale-request
  recovery, the `COPILOT_UNAVAILABLE` signal, and its waiver routing)
  and the same-HEAD advisory reroll — both are F2/F3-only mechanisms
  this file does not reproduce.

A lite session's own routing (A0-A4.5 excluded, E4-E8 excluded, the
lite F1-F2 helper-read-only subset, the lite F2.5 handoff-stop, F3-F5
excluded) never reaches those call sites. If it somehow does anyway,
stop and ask for a stronger session or a human to run the full-size
advisory-wait instructions directly.

## Stop-and-ask conditions

- A required helper field is missing, the helper exits non-zero,
  returns invalid JSON, or its evidence disagrees with live state.
- `outcome` is `CAP_EXHAUSTED` with the `hold` route — the only way
  this file's routing reaches `HOLD`, which is always caller-derived,
  never a helper-emitted `outcome` value (see Helper-first canonical
  path below).
- `earliestSameHeadAt` becomes empty during active polling (the marker
  disappeared).
- A pending Copilot request cannot be refreshed, or an advisory-wait
  marker cannot be posted or read.
- This file is reached from an F2 prose-fallback or F3 call site (see
  Scope boundary above).

## Fast path — common case

Run the Helper-first canonical path below. Once its `lastCopilotCommit`
field equals its `prHeadSha` field, the gate is **SATISFIED** — skip
everything else below and take the caller's `SATISFIED` action. Enter
the rest of this file only when they differ.

## Helper-first canonical path

```sh
node scripts/advisory-wait-state.mjs --pr <pr-number> \
  --trusted-marker-logins "<trusted-login-1>,<trusted-login-2>"
```

Resolve the package-manager / ephemeral-npx equivalent from
`docs/idd-helper-scripts.md`.

Required fields (stop and ask if any are missing — matching
`idd-review-fix-lite.instructions.md`'s E14 field list exactly):
`prHeadSha`, `lastCopilotCommit`, `copilotPending`,
`copilotPendingCoversHead`, `outcome`, `f3Outcome`, `secondaryBotLogin`,
`secondaryRequestNeeded`, `earliestSameHeadAt`, `requestMarkerCount`,
`requestCap`, `pendingWindowMinutes`, `settledWindowMinutes`,
`pollIntervalMinutes`, `capExhaustedRoute`, `trustedMarkerSummary`. The
helper always emits every one of these (`secondaryBotLogin: ""` and
`secondaryRequestNeeded: false` when no secondary bot is configured,
`f3Outcome` unused by E14 but still present) — none is ever absent on a
well-formed response, so validating all of them catches a malformed
helper without treating any of them as truly optional.

The helper computes the outcome directly from live evidence — never
compute it by hand from raw timestamps. Allowed `outcome` values:
`SATISFIED`, `REQUEST_NEEDED`, `RECOVERY_NEEDED`, `CAP_EXHAUSTED`,
`WAIT`. `HOLD` is a caller-derived routing state, never an emitted
enum value.

The helper already resolves `advisoryWait.*` from
`.github/idd/config.json` and emits the final values directly in
`requestCap`, `pendingWindowMinutes`, `settledWindowMinutes`,
`pollIntervalMinutes`, and `capExhaustedRoute` — never read that config
file yourself. A missing one of these fields is not a "config absent"
case to resolve by hand; it is a malformed helper response (see
Required fields above), so stop and ask instead. For context only, the
distributed defaults the helper falls back to when the repository sets
no `advisoryWait.*` config are: `requestCap` 30,
`pendingWindowMinutes` 30, `settledWindowMinutes` 10,
`pollIntervalMinutes` 2, `capExhaustedRoute` `phase-specific`.

## E14 outcome → action

<!-- dprint-ignore-start -->
| Outcome | E14 action |
| --- | --- |
| `SATISFIED` | proceed to CI wait |
| `REQUEST_NEEDED` | remove the stale pending request if one exists, request Copilot, post the request marker, then poll |
| `RECOVERY_NEEDED` | post the recovery marker (do not request another review), then poll |
| `CAP_EXHAUSTED` | `phase-specific` (default): proceed to CI wait. `hold`: stop and ask (`HOLD`'s only route; see above) |
| `WAIT` | keep polling |
<!-- dprint-ignore-end -->

`capExhaustedRoute: phase-specific` is what lets E14 continue past
`CAP_EXHAUSTED`; F2 and F3 always hold on it instead, but that
distinction lives entirely in the excluded scope above.

## Markers

Request (plain text, not an HTML comment):
`advisory-wait: {agent-id} {PR_HEAD_SHA} {ISO8601-requested-at}`.

Recovery (plain text):
`advisory-wait-recovery: {agent-id} {PR_HEAD_SHA} {ISO8601-recovery-time}`.
Rules: do not request another review on this path; the clock starts
from this marker's own GitHub `created_at`, never an embedded
timestamp; if it cannot be posted or read, stop and ask.

Helper-first posting: `post-idd-marker --type advisory --target pr
<pr-number> --agent-id <id> --head-sha <sha> --timestamp <ts> --apply`
(request marker) or `--type advisory-recovery` with the same fields
(recovery marker). Resolve the package-manager equivalent from
`docs/idd-helper-scripts.md`. The manual JSON `POST` is the fallback
when the helper is unavailable.

Only a trusted marker actor's comment `created_at` counts for the
clock. Never use commit author or committer timestamps as advisory
proof.

## Polling guidance (protocol-level only)

This section covers only what the AW3 protocol itself defines. Whether
to abort this wait early on a moved HEAD or newly arrived review
activity is the caller's own job — `idd-review-fix-lite.instructions.md`'s
E14 already owns and fully defines that abort-and-restart logic; this
file does not duplicate it.

1. Reuse the existing same-head marker (`earliestSameHeadAt`) instead
   of posting a new one, unless none exists yet.
2. On each cycle, at the interval from `pollIntervalMinutes`, re-run
   the Helper-first canonical path above for a fresh `outcome`.
3. If `earliestSameHeadAt` is now empty, stop and ask (see
   Stop-and-ask conditions).
4. If `outcome` is now `SATISFIED`, exit this wait and continue. The
   helper already folds the `pendingWindowMinutes` /
   `settledWindowMinutes` elapsed-window check into this same
   `outcome` value on every fresh call — including the stalled or
   rate-limited case where the primary bot never reviews this HEAD —
   so this step alone covers that case. Never re-derive the
   elapsed-window decision by hand from the raw window values; that
   would risk drifting from the helper if the protocol changes it.
5. Otherwise (`outcome` is `WAIT`, or any other non-terminal value),
   keep polling.

## Secondary advisory bot (non-gating, optional)

When the helper's `secondaryRequestNeeded` is `true`, request
`secondaryBotLogin` once for this HEAD using the same request
mechanics above. Post no `advisory-wait:` marker for it — it never
satisfies the primary gate and never consumes the primary's request
cap. Skip this step entirely when `secondaryRequestNeeded` is `false`.

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

Skip this step (not a stop-and-ask condition) when the candidate set is
empty or the helper is unavailable — later cleanup catches leftovers.
