# IDD — Copilot Advisory-Wait Protocol

Shared advisory-wait protocol used by **E14**
(`idd-review-fix.instructions.md`), **F2** (`idd-pre-merge.instructions.md`),
and **F3** (`idd-merge.instructions.md`). Policy constants (cap/windows)
are named in
[`docs/policy-constants.md`](../../docs/policy-constants.md); this file
owns behavior.

## Scope — Copilot-only settle/wait window

This protocol's settle/wait window covers **Copilot only**. Other
`advisoryBotLogins` (e.g. CodeRabbit) get **no** wait window here —
deliberately (`external-bot` profile in
[`docs/idd-review-policy-profiles.md`](../../docs/idd-review-policy-profiles.md)
swaps the single bot instead of gating every configured one).

For non-Copilot bots, the load-bearing safety net for late-arriving
findings is the **E1 activity-universe snapshot + `review-watermark`
delta** (`idd-review-snapshot.instructions.md`), re-checked by the
F2/F3 merge-readiness gate
([`idd-pre-merge.instructions.md`](idd-pre-merge.instructions.md)),
which forbids a bare CI-green merge without a fresh covering snapshot.

## Fast path — common case

The advisory bot usually reviews current HEAD within minutes, reducing
the gate to one check: poll `LAST_COPILOT_COMMIT`; once it equals
`PR_HEAD_SHA`, the gate is **SATISFIED** — skip the AW2-AW5 machinery
and take the caller's `SATISFIED` action (E14 → E15, F2 → CI check, F3
→ merge; common to both the canonical path and shell-fallback AW3 row
one). Enter the full protocol below **only** when
`LAST_COPILOT_COMMIT != PR_HEAD_SHA`.

Keep the wait itself cheap per the
[wake-up discipline](idd-ci.instructions.md#wake-up-discipline): a
single wake at the **expected** completion, or background only if the
topology-safety condition holds; otherwise wait synchronously. Batch
all post-wait actions into one turn.

## 1. Canonical path (helper-first)

When helper support is installed, this is the canonical evidence
collector (resolve `<profile-selected-advisory-wait-command>` from
`docs/idd-helper-scripts.md`; never hardcode `node scripts/...` for
non-vendored profiles):

```sh
# source repo / vendored-node profile
node scripts/advisory-wait-state.mjs \
  --pr <pr-number> \
  --trusted-marker-logins "<trusted-login-1>,<trusted-login-2>"

# package-manager / ephemeral-npx profile
<profile-selected-advisory-wait-command> \
  --pr <pr-number> \
  --trusted-marker-logins "<trusted-login-1>,<trusted-login-2>"
```

Contract: `docs/idd-helper-scripts.md#stable-helper-evidence-outputs`
and `schemas/advisory-wait-state.schema.json`.

Required helper fields: `prHeadSha`, `lastCopilotCommit`,
`copilotPending`, `copilotPendingCoversHead`, `outcome`, `f3Outcome`,
`earliestSameHeadAt`, `requestMarkerCount`, `requestCap`,
`pendingWindowMinutes`, `settledWindowMinutes`, `pollIntervalMinutes`,
`capExhaustedRoute`, `trustedMarkerSummary`.

Optional non-gating secondary-bot fields (not in the `outcome`/
`f3Outcome` enums; see **Secondary advisory bot supplement** below):
`secondaryBotLogin` (empty when unconfigured or equal to the primary)
and `secondaryRequestNeeded`.

Allowed `outcome`/`f3Outcome` values: `SATISFIED`, `REQUEST_NEEDED`,
`RECOVERY_NEEDED`, `CAP_EXHAUSTED`, `WAIT`. `HOLD` is a protocol-level
routing state for AW4/AW5 fail-closed stops only — caller-derived, not
emitted by helper enums.

Resolve the policy from helper output when available; otherwise read
`.github/idd/config.json` `advisoryWait.*`, falling back to the
distributed defaults in `docs/policy-constants.md`: `REQUEST_CAP`,
`PENDING_WINDOW_MINUTES`, `SETTLED_WINDOW_MINUTES`,
`POLL_INTERVAL_MINUTES`, `CAP_EXHAUSTED_ROUTE`.

`CAP_EXHAUSTED_ROUTE` must remain fail-closed: `phase-specific`
(default) — E14 skips to E15, F2/F3 hold; `hold` — E14, F2, and F3 all
hold on `CAP_EXHAUSTED`.

### Caller mapping

<!-- dprint-ignore-start -->
| Outcome | E14 | F2 | F3 |
| --- | --- | --- | --- |
| `SATISFIED` | proceed to E15 | continue to CI check | proceed with merge |
| `REQUEST_NEEDED` | request Copilot + marker + poll | return to E14 | return to E14 |
| `RECOVERY_NEEDED` | post recovery marker + poll | post recovery marker + poll | post recovery marker; return to F2 |
| `CAP_EXHAUSTED` | use `CAP_EXHAUSTED_ROUTE` | post cap-exhausted hold and stop | post cap-exhausted hold and stop |
| `WAIT` | continue polling | poll then restart F2 from top | do not merge; return to F2 |
| `HOLD` | post hold and stop | post hold and stop | post hold and stop |
<!-- dprint-ignore-end -->

### Secondary advisory bot supplement (non-gating)

Orthogonal to the table above: changes no `outcome`/`f3Outcome` or
route, never satisfies the primary gate, posts no `advisory-wait`
marker. Full trigger condition (`secondaryRequestNeeded`/`CAP_EXHAUSTED`/
stalled `SATISFIED`) and request procedure:
`idd-review-fix.instructions.md`'s E14 step 5.

### F3-specific interpretation

**Precedence**: when helper output is valid, **F3 uses `f3Outcome`
exclusively** (the **F3** column reads from it); `Outcome` governs
**E14**, **F2**, and shell-fallback rows only (no `f3Outcome` there).

- F3 must use `f3Outcome` when helper output is available.
- If `copilotPending` is `false`, F3 treats advisory wait as satisfied.
- If `copilotPending` is `true`, F3 must not merge on `WAIT`,
  `REQUEST_NEEDED`, or `RECOVERY_NEEDED`.

## 2. Fail-closed fallback trigger

Do **not** proceed on helper output unless all required fields and
enums are valid and consistent with protocol expectations. Switch to
shell fallback (AW1-AW5) immediately if: helper is unavailable, exits
non-zero, or returns invalid JSON; required fields are missing; an
enum value is outside the allowed set; or helper evidence disagrees
with live state in a way that affects routing.

If fallback cannot establish safe evidence, route to hold (`AW4` or
`AW5`) and stop.

## 3. Shell fallback (AW1-AW5)

Use this path whenever helper-first cannot be trusted.

### AW1 — Copilot review state

AW3 inputs:

- `LAST_COPILOT_COMMIT` — `commit_id` of the latest Copilot review
  (empty if none); equals `PR_HEAD_SHA` short-circuits to **SATISFIED**.
- `COPILOT_PENDING` — `true` if Copilot is in `requested_reviewers`.
- `COPILOT_PENDING_COVERS_HEAD` — `true` if the latest Copilot
  `review_requested` event follows current HEAD's `committed` event.

See [shell fallback AW1](../../docs/idd-advisory-wait-shell-fallback.md#aw1)
for commands.

### AW2 — Advisory marker evidence

AW3 inputs:

- `TRUSTED_MARKER_LOGIN_JSON` — JSON list of trusted marker logins:
  current actor, configured trusted actors, plus write/maintain/admin
  collaborators when `IDD_TRUST_COLLABORATOR_MARKERS` is on.
- `EARLIEST_SAME_HEAD_AT` — earliest `created_at` of a trusted marker
  matching `advisory-wait`, `advisory-wait-recovery`, or
  `<!-- advisory-wait: … -->` for current `PR_HEAD_SHA` (empty if none).
- `REQUEST_MARKER_COUNT` — count of trusted `advisory-wait` markers
  (excludes recovery markers).

See [shell fallback AW2](../../docs/idd-advisory-wait-shell-fallback.md#aw2)
for commands.

Rules:

- only trusted marker actors can start or extend advisory clocks
- same-head clock anchor is marker `created_at` (not embedded text)
- request-cap counting excludes recovery markers
- refresh AW2 evidence at each polling cycle
- never use commit author/committer timestamps as advisory proof

### AW3 — Decision table

Evaluate top-to-bottom; first match wins.

<!-- dprint-ignore-start -->
| `LAST_COPILOT_COMMIT` | `COPILOT_PENDING` | Marker state | Head proof / cap | Elapsed | Outcome |
| --- | --- | --- | --- | --- | --- |
| `== PR_HEAD_SHA` | any | any | any | any | `SATISFIED` |
| `!= PR_HEAD_SHA` | `"true"` | no same-head marker | `COPILOT_PENDING_COVERS_HEAD=true` | — | `RECOVERY_NEEDED` |
| `!= PR_HEAD_SHA` | `"true"` | no same-head marker | not proven; `REQUEST_MARKER_COUNT` < `REQUEST_CAP` | — | `REQUEST_NEEDED` |
| `!= PR_HEAD_SHA` | `"true"` | no same-head marker | not proven; `REQUEST_MARKER_COUNT` >= `REQUEST_CAP` | — | `CAP_EXHAUSTED` |
| `!= PR_HEAD_SHA` | `"true"` | marker exists | any | >= `PENDING_WINDOW_MINUTES` min | `SATISFIED` |
| `!= PR_HEAD_SHA` | `"true"` | marker exists | any | < `PENDING_WINDOW_MINUTES` min | `WAIT` |
| `!= PR_HEAD_SHA` | `"false"` | marker exists | any | >= `SETTLED_WINDOW_MINUTES` min | `SATISFIED` |
| `!= PR_HEAD_SHA` | `"false"` | marker exists | any | < `SETTLED_WINDOW_MINUTES` min | `WAIT` |
| `!= PR_HEAD_SHA` | `"false"` | no same-head marker | `REQUEST_MARKER_COUNT` >= `REQUEST_CAP` | — | `CAP_EXHAUSTED` |
| `!= PR_HEAD_SHA` | `"false"` | no same-head marker | `REQUEST_MARKER_COUNT` < `REQUEST_CAP` | — | `REQUEST_NEEDED` |
<!-- dprint-ignore-end -->

### AW3-R — Recovery marker

Use only when AW3 outcome is `RECOVERY_NEEDED`. Post:

```text
advisory-wait-recovery: {agent-id} {PR_HEAD_SHA} {ISO8601-recovery-time}
```

Helper-first via the profile-selected post-idd-marker command
(`--type advisory-recovery --target pr <pr-number> --agent-id <id>
--head-sha <PR_HEAD_SHA> --timestamp <ISO8601> --apply`) — emits the
plain-text form with no visible note so AW2 still matches. Manual
`POST`: [shell fallback AW3-R](../../docs/idd-advisory-wait-shell-fallback.md#aw3-r).
The same command posts the `advisory-wait:` request form (E14's
`REQUEST_NEEDED` marker) via `--type advisory` with the same fields.

Rules:

- do not request another Copilot review in this path
- advisory clock starts from marker comment `created_at`
- if marker cannot be posted/read, route to `AW4` recovery-failed hold

### AW3-S — Bounded stale-request recovery (`#1571`)

Fires for the unproven-coverage case (`COPILOT_PENDING_COVERS_HEAD =
false`, no same-head marker) — E14's `REQUEST_NEEDED`-pending sub-case;
distinct from `AW3-R` (proven coverage). Bounds remove/re-request with
the independent, per-HEAD recovery-cycle cap from the
[terminal contract](#terminal-copilot-stall-recovery-contract-state-policy-markers-clock)
(default 2), not `REQUEST_CAP` (30) —
[why two paths](../../docs/idd-design-rationale.md#aw3-s-vs-aw3-r-why-two-recovery-paths).

**Eligibility.** Run `advisory-wait-state` with `--claim-id`/`--agent-id`
set to the active claim (omitting either reads the budget as the full
un-decremented cap — the classifier fails closed to
`"not-applicable"`/`active-claim-not-provided`) and read
`staleRequestRecovery`: `"not-applicable"` → ordinary handling
unchanged; `"cap-exhausted"` → do **not** remove or re-request, handle
like `CAP_EXHAUSTED` (`CAP_EXHAUSTED_ROUTE`); `"attempt"` → run the
cycle below. Without helper runtime, derive the same decision from
AW1-AW2 plus the terminal contract's remaining budget (trusted bound
`advisory-wait-recovery:` markers only).

**Bounded cycle** (only when `"attempt"`). Before each mutating step,
re-verify the active claim
([claim revalidation gate](idd-overview-core.instructions.md#claim-revalidation-gate))
and that HEAD hasn't moved since the attempt started; either failure
aborts without mutating or counting a cycle — discard and restart from
E1 against the new HEAD. Commands for every step (same gh-then-REST
pattern as E14's **Primary advisory bot**):
[shell fallback AW3-S](../../docs/idd-advisory-wait-shell-fallback.md#aw3-s).

1. **Remove** the stale request. If it fails because the bot is no
   longer pending, re-run AW1-AW3 and re-evaluate `staleRequestRecovery`;
   any other failure posts the `AW4` pending-refresh-failed hold and
   stops — no cycle counted.
2. **Verify** removal and current HEAD before proceeding.
3. **Request** Copilot again, same fallback pattern.
4. **Verify association**: confirm `review_requested` follows HEAD's
   `committed` event (same proof as `COPILOT_PENDING_COVERS_HEAD`). Not
   yet true is ordinary lag, not failure — do **not** redo steps 1-3;
   re-check alone after a brief pause (default: 3 attempts, a few
   seconds apart). Still unproven after that budget: abort without
   posting a marker or counting a cycle, return to the polling loop
   (or E1) next interval — never tight-loop on unresolved lag.
5. **Post exactly one** bound marker, only once every prior step is
   verified. `<n>` is `completedCycleCount + 1`; posting last avoids
   double-counting, since only marker **presence** counts toward budget.

**Ordinary counters are untouched**: excluded from `requestMarkerCount`
and `#1511`'s reroll accounting, but **does** count as a same-head
marker for the AW2 clock (blocking a second mutation for the same
verified HEAD within one pass).

### AW3-H — Hide superseded advisory-wait markers

After a new `advisory-wait`/`advisory-wait-recovery` marker is verified
for the current `PR_HEAD_SHA`, minimize every trusted prior
`advisory-wait*` marker whose embedded HEAD SHA does **not** match, as
`OUTDATED` (cuts F4 backlog and review-page noise). Find candidate IDs
(trusted `advisory-wait*` markers with a differing embedded SHA), then
call the minimize-markers command:
[shell fallback AW3-H](../../docs/idd-advisory-wait-shell-fallback.md#aw3-h).

Skip entirely if the new marker was not verified, the candidate set is
empty, or the helper is unavailable — F4 cleanup catches them later.
Never hide a marker for the **current** `PR_HEAD_SHA`: AW2's
`EARLIEST_SAME_HEAD_AT` anchor needs at least one visible same-head
marker.

### AW4 — Hold templates

#### Pending refresh failed

> Copilot review is pending, but the PR timeline does not prove the
> request was created after HEAD `{PR_HEAD_SHA}`, and E14 could not
> refresh it. A maintainer must verify or request the Copilot review
> before this can continue. Do not merge until resolved.

#### Recovery failed

> Copilot review is pending for HEAD `{PR_HEAD_SHA}` but no
> advisory-wait marker can be posted or read. A maintainer must verify
> the Copilot advisory-wait state before this can continue. Do not
> merge until resolved.

#### Cap exhausted

> The configured per-PR Copilot re-review cap is exhausted. A maintainer must
> manually request and evaluate a Copilot review before merge.

### AW5 — Missing-marker recovery during polling

If `EARLIEST_SAME_HEAD_AT` becomes empty during active polling, post
this hold and stop:

> Advisory-wait marker for HEAD `{PR_HEAD_SHA}` is missing during
> polling; elapsed time cannot be computed. A maintainer must verify
> the Copilot advisory-wait state before this can continue.

## AW6 — Same-HEAD advisory reroll

F2-only (`#1511`) on `sameHeadReroll.eligible`; see
`docs/idd-helper-scripts.md`. `requestable`: post the marker below
**before** requesting the review, then poll (not E14's loop).
`inFlight`: poll only. Else F2's route; `!inFlight`: E1.

```text
advisory-reroll: {agent-id} {PR_HEAD_SHA} {ISO8601-requested-at}
```

Plain text, no HTML comment (matches `advisory-wait:`/
`advisory-wait-recovery:`'s shape). Helper-first: the profile-selected
post-idd-marker command (`--type advisory-reroll --target pr
<pr-number> --agent-id <id> --head-sha <PR_HEAD_SHA> --timestamp
<ISO8601> --apply`); manual JSON `POST` is the fallback. If it cannot
be posted or verified, fail closed to AW4's **Recovery failed** hold
(mirrors AW3-R's routing on the same failure).

## Terminal Copilot stall-recovery contract (state, policy, markers, clock)

`#1572` defines the state/policy/marker contract for a terminal
`COPILOT_UNAVAILABLE` signal that `AW3-S` above gates via its bounded
recovery cycle
([why a separate signal](../../docs/idd-design-rationale.md#terminal-copilot-stall-recovery-contract-why-a-separate-signal)).
`AW3-S`'s `"cap-exhausted"` still falls back to `CAP_EXHAUSTED_ROUTE`,
not [Terminal routing](#terminal-routing-1570) below — cycle exhaustion
alone never proves `COPILOT_UNAVAILABLE` (see **State**).

- **Policy**: `advisoryWait.recoveryCycleCap` (integer ≥ 1, default
  **2**) bounds completed recovery cycles per PR HEAD;
  `advisoryWait.terminalWindow` (ISO 8601 duration, default **`PT12H`**)
  is the post-exhaustion window before state can turn terminal.
- **Markers, trust-filtering, clock anchor**: full grammar/criteria in
  [helper scripts](../../docs/idd-helper-scripts.md#advisory-wait-evidence).
  Brief: a bound `advisory-wait-recovery:` marker (`{agent-id}
  {PR_HEAD_SHA} {ISO8601-timestamp} claim:{claim-id} attempt:{n}`)
  counts only from a trusted actor with matching claim/HEAD; the clock
  anchors on the earliest qualifying marker; remaining budget = cap
  minus completed-cycle count. Post with the profile-selected
  post-idd-marker command (`--type advisory-recovery --claim-id <id>
  --attempt <n>`, plus `--agent-id --head-sha --timestamp`).
- **State**: `COPILOT_UNAVAILABLE` only when all three hold, from
  trusted evidence — cap exhausted (`completedCycleCount >= cap`),
  terminal window elapsed since the anchor, and no current-HEAD
  Copilot review (`lastCopilotCommit != PR_HEAD_SHA`). Any missing or
  ambiguous evidence fails closed to `NOT_TERMINAL` with a
  machine-readable reason.
- **Non-bypass by construction**: `COPILOT_UNAVAILABLE` is structurally
  independent of every advisory-satisfied field (`outcome`, `f3Outcome`,
  future rollups) — neither derives from the other. Consumers may treat
  it only as waiver _eligibility_, never as satisfaction or readiness
  on its own.

### Terminal routing (`#1570`)

One `idd-external-check-waiver:` marker (selector
`idd-advisory-convergence`, current HEAD, active claim) satisfies both
consumers: the CI check's `terminal` field (its waiver hatch also opens
on `COPILOT_UNAVAILABLE` independent of `deadline.passed` — `ready`
still needs a valid waiver), and F2/F3's `advisoryWait.copilotUnavailable`/
`copilotUnavailableWaived` (`f3Outcome` unchanged; unwaived adds
`copilot-terminal-unavailable` to `blockers[]`, additive to
`advisory-wait` — do not merge on `f3Outcome: SATISFIED` alone here).

**Unwaived**: post this hold and stop (no E14 loop, no merge bypass):

> Copilot is terminally unavailable on HEAD `{PR_HEAD_SHA}`: the
> recovery cycle is exhausted and the terminal window elapsed with no
> current-HEAD review. A maintainer must post an
> `idd-external-check-waiver:` marker for selector
> `idd-advisory-convergence`, this HEAD, and the active claim before
> this PR can proceed.

**Waived**: rerun the existing `idd-advisory-convergence` run (never
`workflow_dispatch` — see Rerun mechanics below); both fields recompute
every call, so an expired/invalid marker reverts automatically.
