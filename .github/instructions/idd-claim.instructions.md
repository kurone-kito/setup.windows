# IDD — Claim Phase (A5)

Read this file after `idd-suitability.instructions.md` (A4.5) passes for
the selected issue — whether selected via A4 or verified through an
explicit issue target (A0-T) — or after a successful re-claim decision
in the resume phase. It covers the five pre-checks, claim execution, and
claim verification.

## Canonical A5(a) path (helper-first)

When helper runtime is enabled, use the profile-selected claim approval
helper as the canonical A5(a) evidence collector.

```sh
# source repo / vendored-node
node scripts/claim-approval-gate.mjs --issue <issue-number>

# package-manager / ephemeral-npx
<profile-selected-claim-approval-command> --issue <issue-number>
```

Resolve `<profile-selected-claim-approval-command>` from
`docs/idd-helper-scripts.md`; do not hardcode `node scripts/...` for
non-vendored profiles.

Contract: `docs/idd-helper-scripts.md#claim-approval-evidence` (required
fields: `approved`, `reason`, `gateEnabled`,
`policy.maintainerApprovalActorPolicy`, `policy.approvalSignals`,
`checks`).

If the helper exits non-zero, returns invalid or incomplete JSON, or
conflicts with live approval state, ignore it and use the written A5(a)
path below. If fallback still cannot prove safe approval, treat
approval as missing.

## Pre-checks (all five must pass)

Re-fetch the issue immediately before running these checks.
All A5 checks are target-issue local: claims on related roadmap or
child issues do not block this check unless they appear on the selected
issue itself.

**(a) Issue-author approval gate** — Re-evaluate the repository-wide
issue-author approval rule immediately before claim, using the same
gate-enable, actor-policy, approval-signal, and fail-closed rules as
**A3.5** of `idd-discover.instructions.md`.

A bare organization `MEMBER` association never counts as approval;
neither do issue body text, a generated plan, or operator attention.

- If approval is missing for a roadmap/default discovery run, return to
  Discover using the same selection mode that produced this target so
  A3.5 can continue with the next eligible startable issue or the
  approval-needed stop path.
- If approval is missing for an explicit-target A0-T run, stop without
  claiming.

**(b) Assignee and project status** — no assignee set; if the project
is in use, its status must be "not started".

**(c) Claim state** — Re-read the issue and parse the **active claim**
using the shared claim-state rules:

When helper runtime is enabled, run the mechanical fresh-claim claimability
gate on a fresh marker fetch **immediately before** the claim write as the
canonical A5(c) evidence collector:

```sh
# source repo / vendored-node
node scripts/resume-claim-routing.mjs --issue <number> --fresh-claim-gate
```

It reuses the shared `resolveActiveClaim` / `evaluateResumeClaimRouting`
resolver and returns a `fresh_claim_gate.verdict` of `claimable |
already-claimed | stale-reclaimable` with the winning `{claim-id}`:

- `claimable` → proceed to the claim write below.
- `stale-reclaimable` → proceed with takeover (the stale path below).
- `already-claimed` → the issue is held by a live competitor, or a later
  competing / same-second claim raced in: do not post a claim. Apply the
  **already-claimed routing** defined here for the rest of this file:
  return to Discover using the same selection mode that produced this
  target (orphan-first: continue the A0-O capable path; roadmap mode:
  continue the A3-ready path) and select the next eligible issue; for an
  explicit-target A0-T run, report that the issue is already claimed and
  stop instead of falling back to Discover, per
  `idd-discover.instructions.md`'s A0-T stop-don't-fallback rule.

GitHub issue comments have no compare-and-swap, so this narrows — rather
than closes — the claim→write TOCTOU window; the 24 h stale-takeover
and same-second tie-break below remain the race-recovery backstop. If
the helper is unavailable or malformed, fall back to the written rules
below, which stay authoritative.

Use the `claim-stale-age` policy default from `docs/policy-constants.md`
for these stale checks (distributed default: `24 h`).

- No active claim → unclaimed, proceed.
- Active claim already uses a `{claim-id}` that this current session had
  recorded before this check and has now verified → already claimed; do
  not post a new claim. Continue with that same `{claim-id}`. A token
  first learned by parsing the current issue comments is not enough.
- Any other active claim whose latest valid `claimed-by` comment has
  GitHub `created_at` < 24 h → claimed by another live session, even
  when the `agent-id` matches — apply the **already-claimed routing**
  above.
- Any other active claim whose latest valid `claimed-by` comment has
  GitHub `created_at` ≥ 24 h → stale, proceed with takeover.

Only the GitHub `created_at` of the latest **valid** `claimed-by`
comment in the active claim counts toward the stale calculation.

If the issue has no trusted new-format `claimed-by` comments but has
legacy claim comments from trusted marker actors, apply the **Legacy
claim migration** rules near the end of this file instead of the
bullets above — they resolve unclaimed-vs-stale status from the latest
trusted legacy claim using this same 24 h threshold and the
**already-claimed routing**.

**(d) Open PR** — A5(d) has no supported helper. Re-check live GitHub
PR state with the written rules below. No open PR may close or
reference this issue (check both linked issues and closing keywords in
PR bodies), unless that PR's head branch matches the `branch` field in
an inheritable claim comment. An inheritable claim comment is either:

- the already verified active claim for this current session, or
- the currently active stale claim you are taking over, or
- the latest trusted `claimed-by` comment that was later released by a
  matching trusted `unclaimed-by` comment (the last voluntarily released
  branch), or
- trusted forced-handoff evidence already verified by Resume Step 1,
  but only when its branch and linked PR fields match the live GitHub
  state, or
- the latest trusted legacy `claimed-by` comment when performing a
  legacy migration (see **Legacy claim migration** near the end of
  this file)

**(e) Branch collision** — Compute the branch name using the IDD naming
convention: `issue/<number>-<slug>`. Generate `<slug>` deterministically
from the issue title so parallel sessions converge on the same branch
name.

When helper runtime is enabled, compute the slug with the branch-name
helper instead of hand-tracing it:

```sh
# source repo / vendored-node
node scripts/branch-name.mjs --number <issue-number> --title <issue-title>

# package-manager / ephemeral-npx
<profile-selected-branch-name-command> --number <issue-number> --title <issue-title>
```

Resolve `<profile-selected-branch-name-command>` the same way as A5(a)
above. It prints `issue/<number>-<slug>` and implements the algorithm
below exactly. The written algorithm remains the canonical spec and
fallback; use it when the helper is unavailable or its output is
malformed:

1. Convert the issue title to lowercase.
2. Replace every character outside ASCII `a-z` and `0-9` with `-`.
3. Split on `-`, drop empty tokens, then remove only whole-token matches
   from this fixed stop-word set: `a`, `an`, `the`, `and`, `or`, `in`,
   `for`, `to`, `with`, `from`.
4. Rejoin the remaining tokens with single `-`.
5. If the slug is longer than 40 characters, cut it to the first
   40 characters. If that cut ends mid-token and there is a `-` before
   character 40, trim back to the last such `-`; if there is no `-`,
   keep the hard 40-character cut. Then strip any trailing `-`.
6. If the result is empty, use `task`.

**Worked examples** (shared verbatim with the helper's drift test in
`tests/branch-name.test.mts`):

- `Add the OAuth login flow` → `issue/42-add-oauth-login-flow`
- `Add a helper that computes the canonical issue/<number>-<slug> branch name`
  → `issue/901-add-helper-that-computes-canonical-issue`
- `!!!` → `issue/7-task`
- `日本語 calendar 機能` → `issue/99-calendar`

No remote branch with that name may exist, unless it matches the
`branch` field in an inheritable claim comment or trusted
forced-handoff evidence as defined in (d) above.

Before posting a claim, also perform a **scoped issue-wide branch
pattern check** — the fast-path collision detection that catches
parallel-session concurrency on the same issue (different slug
variants) before a new claim comment is posted.

1. **Local worktree scan**: Check whether any local worktree matches the
   pattern `issue/<number>-*`:

   ```sh
   git worktree list | grep "issue/<number>-"
   ```

2. **Remote branch scan** (scoped Refs API, not repo-wide):
   Query the Refs API with the issue-number prefix only, to stay within
   the scope invariant defined in idd-overview-appendix.instructions.md:

   ```sh
   gh api "repos/{owner}/{repo}/git/matching-refs/heads/issue/<number>-" \
     --jq '.[].ref | sub("^refs/heads/"; "")'
   ```

   The Refs API returns fully-qualified `refs/heads/issue/<number>-…`
   refs; `sub("^refs/heads/"; "")` strips that prefix so each result
   compares directly against the short `issue/<number>-…` form stored in a
   claim `branch` field — otherwise an inheritable or active-claim branch
   reads as non-corresponding and trips a false reroute or hold below.

3. **Collision action tree**:

   - **If no local worktree or remote branch matches `issue/<number>-*`**:
     Proceed to claim posting (the safe, single-session path).

   - **If a match is found and corresponds to an inheritable claim or
     trusted forced-handoff evidence** (its `branch` matches one of the
     branches allowed in (d) above): proceed to claim posting — the
     branch is expected.

   - **If a match is found, does NOT correspond to an inheritable claim,
     AND an active non-stale claim on this issue references that branch**:
     Treat as **claimed by a concurrent session** running in parallel —
     apply the **already-claimed routing** above. This is the scale-out
     path that lets multiple sessions work different issues when one has
     concurrent claims.

   - **If a match is found, does NOT correspond to an inheritable claim,
     AND no active claim references that branch**:
     Document the branch name and post a **hold note** to the issue: "_A5
     pre-check (e) detected an unexpected branch `issue/<number>-*`
     without an active claim. Possible orphaned branch from a crashed or
     stale session. Stopping for operator review._" Stop and wait for
     operator input. Do not post a claim or continue the workflow.

## Claim execution

Skip the claim-posting steps below if pre-check (c) classified the
issue as already claimed by this current session: keep the previously
recorded `{claim-id}` and branch, and post no new claim. The Heartbeat
posting rules below still apply whenever you extend the active claim's
stale clock; then proceed to Claim verification.

Determine `{branch-name}`:

- **Re-claim / takeover / forced-handoff recovery**: use the exact
  branch name from the inheritable claim comment or trusted
  forced-handoff evidence identified in pre-check (d). Do not compute a
  new name.
- **Fresh claim**: compute a new name using the IDD naming convention:
  `issue/<number>-<slug>` where `<slug>` follows the deterministic title
  normalization algorithm from pre-check (e).

Generate a fresh `{claim-id}` — **except in forced-handoff recovery**, where
the successor adopts the marker's pre-recorded `new-agent-id` / `new-claim-id`
pair instead of minting a claim-id or keeping its own agent-id (see _Claim
verification_ below). Determine `{prior-claim-id}`:

- **Takeover of an active claim** (stale claim recovery) → the current
  active claim's `{claim-id}`
- **Forced-handoff recovery** → `none` once the human-gated handoff has
  released or cleared the displaced claim in GitHub state; if the
  displaced non-stale claim is still active, stop and wait for the
  handoff mechanism instead of inventing a local superseding claim
- **Migration from a legacy claim**, **fresh claim**, or claim after a
  released / unclaimed state → `none`

Post the claim comment using the exact format and posting mechanics
already defined in
[Claim format](idd-overview-core.instructions.md#claim-format) — do not
re-derive them here. `emit-marker` (`--type claimed-by`, emit-only) also
renders the body without posting.

**Nothing appended after the note.** A `claimed-by` / `unclaimed-by`
marker body must be exactly the HTML comment token followed by, at
most, the single italic note from Claim format above — never more. Any
deviation
— trailing content, a missing note, or a note that fails the required
grammar — fails the parser's whole-body anchor, so the comment is not
recognized as a live claim event. Such a deviation is still
**detectable** as a malformed marker
(`detectMalformedOperationalMarker` in `marker-helpers.mts`) rather
than reading as unremarkable "other" content, but detection is
diagnostic only: never salvage a malformed post as valid — always
re-post a clean marker with nothing appended. A marker merely quoted
or embedded mid-prose (not the literal first bytes of the body) is
never treated as live or flagged; anti-spoofing is unaffected.

**Also post an [activation-nonce marker](#activation-nonce-format)** for
every fresh `{claim-id}` this section generates (fresh claim, takeover, or
legacy migration) — not on a plain heartbeat, which reuses the existing
`{claim-id}`.

## Activation-nonce format

Post this alongside every claim **activation** — fresh claim, takeover,
legacy migration, or forced-handoff adopt-verbatim (see _Claim
verification_ below); never skip it for any activation path:

```markdown
<!-- activation-nonce: {agent-id} {claim-id} {nonce} {ISO8601-timestamp} -->

_{agent-id}: claim activation nonce — IDD automation marker. Do not edit._
```

`{nonce}` is a fresh opaque token; record it locally alongside `{agent-id}`
/ `{claim-id}`. When 2+ trusted markers exist for one `{claim-id}` (a
collision), the winner is the lexicographically earliest `{nonce}`
(mirrors the `{claim-id}` same-second tie-break in _Claim verification_).
No marker posted for a `{claim-id}` means no comparison, never a mismatch.
When helper runtime is enabled, post it with
`post-idd-marker --type activation-nonce --target issue <number> --apply`
(agent-id / claim-id / nonce / timestamp fields; see
`docs/idd-helper-scripts.md`).

## Heartbeat posting

When posting a heartbeat (the issue is already claimed by this current
session and you are extending its stale clock), copy the `{branch}`
field **verbatim** from the original `claimed-by` comment — do not
recompute or derive a new name. The heartbeat's `{claim-id}` and
`{agent-id}` must match the original claim exactly, and `{branch}` must
match exactly too, to satisfy the heartbeat branch invariant (rule 3.5
in this file's Claim-state parsing section).

## Claim verification

After posting `claimed-by`, wait for the configured settle delay to let
GitHub eventual consistency settle. Use `.github/idd/config.json`
`claim.verifySettleDelay` (distributed default: `PT5S`), then re-read
the full issue comment stream and parse the active claim in
chronological order using the shared claim-state rules. Apply all
race-safe checks below:

1. Build the same-second contender set from **all** trusted `claimed-by`
   markers (including your own) that share your claim event's `created_at`
   second.
2. If that set has two or more contenders, the winner is the
   lexicographically earliest `{claim-id}` (case-sensitive ASCII compare)
   among them. This race-safe tie-break extends the shared parsing rules
   for this verification step, and a two-way same-second collision (your
   marker plus one competitor) is resolved here rather than slipping past
   as a single-element set.
3. Verify that the active claim now uses **your** `{claim-id}` after the
   same-second tie-break is applied.
4. Verify no trusted competing `claimed-by` with a different
   `{claim-id}` appears in a strictly later `created_at` second than
   your claim event.
5. If you posted an [activation-nonce marker](#activation-nonce-format) for
   this `{claim-id}`, recompute its winner and verify it equals yours. This
   catches a second session that adopted the identical `{claim-id}` via
   forced-handoff, where steps 1–4 see nothing to disagree about (both
   `{claim-id}`s genuinely match). No marker posted: treat as passed.

If any check fails, treat the claim as contested. Return to Discover
using the same selection mode that produced this target and pick the
next eligible issue (orphan-first: continue the A0-O capable path;
roadmap mode: continue the A3-ready path). Do not retry the same issue.
For explicit-target A0-T runs, report the contested claim and stop
unless the operator has explicitly switched to normal discovery.

Once verified, record this `{claim-id}` as your current claim token for
the rest of the workflow.

When the new claim came from forced-handoff recovery, the verified
`forced-handoff` marker has already set the active claim to its
pre-recorded `new-agent-id` / `new-claim-id` pair (Claim-state parsing
rule 7). Adopt **both fields verbatim** as your own `{agent-id}` /
`{claim-id}` for the rest of the run — including `--agent-id` and
`--claim-id` at F2/F3's `pre-merge-readiness` — instead of minting a
fresh claim-id or keeping your own native agent-id; no separate
`claimed-by supersedes: none` post is required for the transfer itself.

**Adopt-verbatim is still an activation**: post your own
[activation-nonce marker](#activation-nonce-format) for `new-claim-id`
too (see the
[rationale](../../docs/idd-design-rationale.md#activation-nonce-why-a-separate-marker-and-what-stays-deferred)
for why this path needs its own nonce). Verify it the same way step 5
above does: wait `claim.verifySettleDelay`, recompute the nonce winner
for `new-claim-id`, and confirm it is yours — the only nonce check
that fires here, since posting no `claimed-by` means this path never
enters _Claim verification_ above. On mismatch, treat the claim as
contested and return to Discover, exactly as the "If any check fails"
clause above.

Always use the marker's assigned `new-agent-id` / `new-claim-id`
exactly as recorded — never invent an ad hoc `claimed-by`, and never
reuse the displaced old `{claim-id}` as your own (`{agent-id}` may
legitimately equal the displaced claim's agent-id; only `{claim-id}`
must always be the fresh marker-assigned value). An invented native
agent-id silently fails every later heartbeat or F2/F3 check as
`agent-id-mismatch` / `claimLost`. Cite the trusted forced-handoff
evidence in the issue digest or resume report's `Authoritative by`
field.

**The successor claim is sticky**, not a one-shot unlock: forced-handoff
re-derives the adopted pair as the active claim on every resolution
pass, so a later `claimed-by supersedes: none` does not activate
(Claim-state parsing rule 4 requires no active claim for it to take
effect) and instead reads as contested. Reconcile via
**adopt-verbatim** (keep using the recorded pair, as above) or
**release-then-fresh** (post `unclaimed-by` for the sticky pair — and,
to be safe, the displaced original pair too — using each pair's exact
recorded `{agent-id}` / `{claim-id}`, then post a fresh `claimed-by
supersedes: none` with a self-chosen pair).

### Orchestrator delegation

An orchestrating session that has posted and verified a claim's
`{agent-id}` / `{claim-id}` pair may delegate it verbatim to an
isolated subagent worker in the delegation brief. The worker adopts
both fields verbatim as its own claim token — mirroring adopt-verbatim
above — instead of minting a fresh claim or being treated as
claim-less; see the ownership-proof exception in
[Claim-state parsing](#claim-state-parsing). No separate `claimed-by`
post is required for the delegation itself.

**Carry the nonce, don't mint one — and still revalidate it.** The
brief must also carry the orchestrator's current activation nonce
verbatim; minting a new nonce for the same `{claim-id}` creates the
exact two-nonce collision step 5 above exists to catch, flagging
legitimate delegation as a second activation. The worker still
performs the Claim revalidation gate's nonce check
(`idd-overview-core.instructions.md`) using the carried value: before
each mutation, recompute the nonce winner for the `{claim-id}` and
confirm it still equals the carried nonce. A different winner (e.g. a
later forced-handoff collision the orchestrator never saw) means the
worker is no longer the winning activation — treat that the same as any
other lost claim.

### Hide displaced claim chain on takeover

When the verified new claim was posted with `supersedes: <prior-id>`
(stale takeover or forced-handoff recovery — **not** legacy migration,
which always uses `supersedes: none`), minimize the displaced claim's
marker chain on the issue as `OUTDATED` once this session has recorded
its own verified `{claim-id}`. Find every trusted `claimed-by` /
`unclaimed-by` / heartbeat comment whose embedded `{claim-id}` equals
`<prior-id>` and call:

```sh
node scripts/minimize-superseded-markers.mjs \
  --subject-ids "<id1>,<id2>,..." \
  --classifier OUTDATED \
  --trusted-marker-logins "<trusted-login-1>,<trusted-login-2>" \
  --apply
```

Skip this step entirely if:

- the new claim has `supersedes: none` (fresh claim — there is no
  displaced chain to hide);
- the takeover claim was not verified (do not hide the prior chain
  until the successor is observable as the active claim);
- the candidate set is empty (no trusted markers carry the prior
  `{claim-id}`);
- the helper is unavailable. Subsequent F4 cleanup still picks up
  any missed candidates.

**Do not** hide a same-`{claim-id}` heartbeat chain from a normal
heartbeat post; heartbeats refresh the stale clock but do not
supersede prior markers, and the visible heartbeat chain is the
active-claim audit trail.

After claim verification, upsert the issue live status digest when there
is exactly one marked digest or none. Use the verified `claimed-by`
comment as the authority: set `Phase` to `A5 claimed`, `Claim` to the
current `{agent-id}` / `{claim-id}`, `Branch` to the verified branch,
`Open blockers` to `none`, and `Next action` to `B1 create branch and
worktree`. If multiple marked digests exist, report their URLs and
continue from the verified claim without editing a digest.

The verified `branch:` field is also the input to the cwd-vs-claim
check that every later mutation must satisfy — see the
[Claim revalidation gate](idd-overview-core.instructions.md#claim-revalidation-gate)
for the full algorithm.

### Worktree-local lock file (same-machine collision)

A same-machine fast path complementing the cross-machine claim check
above. Acquire once the B1 worktree exists (before the first mutation),
then re-run alongside every later pre-mutation check:
`node scripts/claim-lock.mjs --acquire --worktree <path> --agent-id
{agent-id} --claim-id {claim-id}`.

A matching `{claim-id}` re-acquires as a read-only check; a different
`{claim-id}` is always a collision, regardless of lock age. Run
`resume-claim-routing.mjs --issue <n> --fresh-claim-gate`: `already-claimed`
for a different active claim means the claim is lost (stop); if the
active claim's `{claim-id}` is the current claim, retry the local lock
with `--takeover`; `claimable`/`stale-reclaimable` also retries with
`--takeover` after the claim transition completes. If the helper is
unavailable or malformed, fall back to this file's Claim-state parsing
rules below for the same verdict. No release step — `git worktree
remove` at F4 deletes the lock with the worktree, so a crashed
session's leftover lock resolves the same way. See
`docs/idd-helper-scripts.md`'s Worktree-local claim lock entry for
mechanical detail.

Then continue to `idd-work.instructions.md`.

## Claim-state parsing

To determine the current active claim, read issue comments
chronologically and apply these rules:

1. Start with **no active claim**.
2. Ignore any `claimed-by` or `unclaimed-by` marker whose GitHub comment
   author is not a trusted marker actor.
3. A `claimed-by` whose `{agent-id}` AND `{claim-id}` both match the
   current active claim is a candidate **heartbeat**. Before recognizing
   it as a heartbeat, apply rule 3.5.
   3.5. **Heartbeat branch invariant**: A heartbeat candidate is
   recognized only when `{branch}` exactly matches the currently active
   claim's `{branch}`; if it differs, treat the comment as
   **anomalous** — it does not refresh the stale clock or update any
   claim state. Surface an anomalous heartbeat as a warning when it
   affects a routing decision (e.g., resume or worktree selection); the
   **detecting session** continues with its own verified claim
   unchanged, no corrective comment required.
4. A `claimed-by` with a **new** `{claim-id}` becomes the active claim
   only if either:
   - there is no active claim AND its `supersedes:` value is `none`, or
   - its `supersedes:` value exactly matches the current active claim's
     `{claim-id}`, and the current active claim is already **stale** at
     the new comment's GitHub `created_at` timestamp.
5. An `unclaimed-by` releases the claim only if its `{agent-id}` AND
   `{claim-id}` both match the current active claim. Otherwise ignore it
   as a stale release from a superseded session.
6. Any `claimed-by` whose `{claim-id}` matches the active claim but
   whose `{agent-id}` differs, or whose `{claim-id}` was already
   superseded, or whose `supersedes:` value does not match the current
   active claim when one exists, is ignored as a stale or invalid event.
7. A `<!-- forced-handoff: { … } -->` marker (parsed by
   `parseForcedHandoffComment` in `scripts/protocol-helpers.mjs`)
   transfers the active claim to the named successor only when **all**
   hold:
   - the comment **author** is a trusted marker actor (rule 2);
   - the author **equals** the marker's `forcedBy` (case-insensitive)
     when the caller opts in to strict binding
     (`requireAuthorMatchesForcedBy: true`; Resume routing opts in by
     default to block the same-identity self-signed hijack path).
     Callers accepting maintainer-authorized handoffs relayed by a
     separate automation actor leave it off and rely on
     `isAuthorizedForcedHandoff` alone;
   - that author is an authorized maintainer under
     `forcedHandoff.authorityPolicy` — `owners-and-maintainers-only`
     accepts `role_name == admin / maintain` or `permission == admin`;
     `all-write-permission-actors` additionally accepts
     `role_name == write` or `permission == write` so custom write-base
     roles still satisfy the loose policy;
   - `forcedHandoff.mode` is `human-gated` (default `disabled`);
   - `oldAgentId` / `oldClaimId` / `branch` all match the active claim.

   When all hold, replace the active claim with the successor
   (`newAgentId` / `newClaimId`, same `branch`, `supersedes =
   oldClaimId`). On any failure — typically an unauthorized
   `forcedBy`, an author/`forcedBy` mismatch, or `mode != human-gated`
   — leave the active claim unchanged and warn if it affects a routing
   decision.

Same-agent restarts never silently inherit or supersede an active
non-stale claim: if the current session already recorded and verified
the active `{claim-id}`, continue with that same token and use
heartbeats — do not post a fresh takeover claim. If the session cannot
prove ownership, the active claim is treated as owned by another live
session until released or stale, even when `{agent-id}` matches.
**Exception**: a worker that received the pair through a documented
[orchestrator delegation](#orchestrator-delegation) is treated as
having proven ownership through the orchestrator's own recorded
verification. Self-signed forced-handoff markers from the same identity
never transfer ownership: rule 7 rejects them unless the author is an
authorized maintainer. After a successor posts a fresh claim,
later heartbeats from the displaced old `{claim-id}` are ignored as
stale — they do not reclaim ownership or refresh the stale clock.

## Legacy claim migration

Older issues may still contain the legacy claim format:

```html
<!-- claimed-by: {agent-id} {ISO8601-timestamp} branch: {branch-name} -->
```

and the matching legacy release format:

```html
<!-- unclaimed-by: {agent-id} {ISO8601-timestamp} -->
```

Treat trusted legacy comments as **migration-only** inputs:

- If an issue has no trusted new-format `claimed-by` comments yet, first
  check whether the latest trusted legacy `claimed-by` comment is
  followed by a later trusted legacy `unclaimed-by` comment from the
  same agent. If so, treat the issue as **unclaimed**; skip directly to
  posting a fresh new-format claim with `supersedes: none`.
- Otherwise, compare the latest trusted legacy `claimed-by` comment's
  GitHub `created_at` against the `claim-stale-age` threshold
  (distributed default: `24 h`): younger → claimed by another live
  session, even when `{agent-id}` matches — apply the
  **already-claimed routing** above; older → stale, proceed and replace
  it with a new-format claim. A matching legacy agent ID is not enough
  to prove same live-session ownership.
- Then immediately post a new-format `claimed-by` comment with a fresh
  `{claim-id}` and visible note before any further side effects, using
  `supersedes: none` for that one-time migration claim (the legacy
  format has no `{claim-id}` to reference).
- After a new-format claim exists, ignore all legacy claim and unclaim
  comments for active-claim parsing and revalidation.
