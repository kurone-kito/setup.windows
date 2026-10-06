# IDD — Claim Phase (Lite) A5

Lite profile; same semantics as `idd-claim.instructions.md`, except
forced-handoff. Prefer helpers.

**Load alone** for Claim; do not open standard.

**Scope**: one selected issue; no open-ended Discover. Standard
"Return to Discover" branches mean **STOP and report; do not claim**.
Fresh candidate: before claim, if context pressure prevents completing Claim
through F4, report for handoff; stop; do not claim. Recovery unchanged.
Make no claim-stage event/marker, branch/worktree, or issue-state change.
(#3144; preventive)

## Helper runtime contract

1. **When helper runtime is enabled** (`package-manager`, vendored-node,
   or any profile that ships the helpers): run the commands below
   first. If a helper is **missing, fails, returns invalid JSON, or
   disagrees with live GitHub state** → **stop and ask**. Do **not**
   fall through to the written tables in that situation.
2. **When the repository is `instructions-only`** (no helper runtime
   shipped): skip the helper commands and use the written tables only.
   That is the sole path where the tables below are the primary
   control surface. The `--record-tokens`/`--read-tokens` check
   instead uses `docs/idd-helper-scripts.md`'s helper-free fallback.

Every `node scripts/<name>.mjs` command below is the **source-repo /
vendored-node** invocation form. Under `package-manager` /
`ephemeral-npx` profiles, `scripts/` is not vendored — resolve each
command's profile-selected equivalent from
`docs/idd-helper-scripts.md`. A helper missing on the active profile
is a missing-helper case under rule 1 (stop and ask), not a reason to
fall through.

`{agent-id}` is a tool/agent identifier shared across concurrent
sessions of the same agent type — pick or confirm one before the first
command below that needs it (Claim execution step 4 at the latest).
Appending a unique session token is recommended for auditability
(e.g., `copilot-8122ca35`), not required. `{agent-id}` alone is never
ownership proof; `{claim-id}` is the authoritative token.

## Stop-and-ask

Stop and ask the operator when:

- an expected helper is missing, fails, or disagrees with live state;
- pre-check (a)-(e) fails for any reason (see below) — no fallback
  candidate exists in lite scope;
- the fresh-claim gate returns `already-claimed` for a non-owner, or the
  written rules find a non-stale competitor;
- forced-handoff evidence exists but mismatches live claim/branch/PR
  state, or `forcedHandoff.mode` is not `human-gated`;
- claim verification (below) fails any race-safe check;
- branch pre-check (e) finds an orphaned branch with no active claim.

Never invent a forced-handoff marker. Only consume already-recorded,
human-gated forced-handoff evidence from a trusted actor.

## Pre-checks (a)-(e) — all five must pass

Re-fetch the issue immediately before running these checks. All five
are target-issue local: claims on related roadmap or child issues do
not block this check. Owner protocol:
`docs/idd-autonomy-contract.md#portable-authoring-owner-protocol`.

### (a) Issue-author approval

Helper-first:

```sh
node scripts/claim-approval-gate.mjs --issue <N>
```

Read `approved` / `reason` / `gateEnabled` / `checks` from the JSON
output. `instructions-only` profile: use the written rules below
directly (no helper exists for that profile).

- If `.github/idd/config.json` has `skipIssueAuthorApprovalGate: true`
  → skip this check.
- Otherwise use `maintainerApprovalActorPolicy` (default:
  `owners-and-maintainers-only`). `owners-and-maintainers-only` admits
  owners plus Maintain/Admin collaborators; `all-write-permission-actors`
  also admits Write collaborators. Do not reuse the trusted marker
  actor set for this check, and do not count automation or the current
  agent unless repository policy explicitly grants it maintainer
  approval authority.
- Startable when **any** holds: the issue author is self-authorized
  under that policy; the configured ready label
  (`approvalSignals.readyLabelName`, default `idd:ready`) is present —
  **only when repository policy reserves that label to maintainer
  approval actors** (otherwise anyone could apply it, so presence alone
  never counts) — fresh per `approvalSignals.labelFreshnessMode` when
  set to `event-freshness`, or presence alone under the `presence-only`
  default; or a visible `IDD ready` comment from a maintainer-approval
  actor, newer than the latest issue title/body/plan edit.
- Issue body text, a generated plan, operator attention, and a bare
  organization `MEMBER` association are **never** approval by
  themselves.
- Ambiguous or unavailable approval/permission state → fail closed
  (treat as not approved).
- Missing approval → **STOP**, do not claim.

### (b) Assignee and project status

The issue must have no assignee set. If a project is in use, its
status must be "not started". Either condition failing → **STOP**.

### (c) Claim state

**Check first, before the fresh-claim gate** (which always ignores
`--claim-id`, so it cannot tell "yours" from "a competitor's"), when
either holds: this session already recorded a `{claim-id}` for this
issue (resume/heartbeat continuation); or a trusted, live
forced-handoff marker names this session `newAgentId` — treat its
`newClaimId` as the `{claim-id}` to check, before Claim execution's
forced-handoff steps:

```sh
node scripts/resume-claim-routing.mjs --issue <N> --claim-id <your-or-newClaimId> [--nonce <your-recorded-nonce>] [--worktree <path>]
```

Pass `--nonce` only when this session already recorded one for that
`{claim-id}` (true after forced-handoff step 5); omit it otherwise.
Pass `--worktree <path>` once the B1 worktree exists.

<!-- dprint-ignore-start -->
| Top-level `state` / `action` | Meaning |
| --- | --- |
| `already_owned` / `keep` | Confirmed — see the two cases below |
| `owner_evidence_required` / `stop` | Retry once with `--worktree <path>`; still returned → Stop-and-ask (not a competitor), unless a forced-handoff successor: `docs/idd-resume-detail.md` §FH |
| anything else | Not yours — forced-handoff: Stop-and-ask; else fall through below |
<!-- dprint-ignore-end -->

`already_owned`/`keep` splits in two: if `--nonce` was passed above
(resume/heartbeat continuation), skip to Claim verification (or
Heartbeat). If it was omitted (first-time forced-handoff entry, not
yet activated by you), go to Claim execution step 5 (post your own
activation-nonce for `newClaimId`) first, then Claim verification's
**Forced-handoff adopt-verbatim** case (step 4's settle-delay + nonce
recompute only).

**Otherwise** (no recorded `{claim-id}`, no forced-handoff evidence, or
verified released-owner retry), run write-gate before claim write:

```sh
node scripts/resume-claim-routing.mjs --issue <N> --fresh-claim-gate
```

<!-- dprint-ignore-start -->
| Helper `fresh_claim_gate.verdict` | Action |
| --- | --- |
| `claimable` | Proceed to Claim execution (fresh) |
| `stale-reclaimable` | Proceed to Claim execution (takeover) |
| `already-claimed` | **STOP** unless `winning_claim_id` matches your verified released id |
<!-- dprint-ignore-end -->

Written fallback (`instructions-only` profile only — per the Helper
runtime contract above, any other profile stops-and-asks on a
missing/failing/malformed helper instead of using this fallback):
read issue comments chronologically. **Trusted marker actor** = the
current session (after it posts and verifies its own marker), a
configured trusted bot/App login for IDD automation, or a
Write/Maintain/Admin collaborator only when repository policy
explicitly allows collaborator-authored markers; ignore every other
author for claim state. A `claimed-by` with a **new** `{claim-id}`
becomes active only when there is no active claim and
`supersedes: none`, or its `supersedes:` matches the current active
claim's `{claim-id}` **and** that claim is already stale at the new
comment's `created_at`. A `claimed-by` whose `{claim-id}` matches the
active claim but whose `{agent-id}` **or `branch:`** differs from the
active claim is ignored as invalid — it is **not** a heartbeat
(heartbeat branch invariant; claim-id is public, not a secret). An
`unclaimed-by` releases only when both
`{agent-id}` and `{claim-id}` match the active claim. **Stale** =
latest valid `claimed-by`'s GitHub `created_at` is
≥ 24 h ago (`claim-stale-age`, default `24 h`). No active claim →
unclaimed, proceed fresh. Active claim already using a `{claim-id}`
this session **itself already recorded and verified** (a token merely
read from the current issue comments is never enough) → already
claimed by this session, continue with it (no new claim; use heartbeat
rules below). Any other active claim < 24 h old → **STOP**, even when
its `{agent-id}` matches yours — same-agent restarts never silently
inherit a non-stale claim. Any other active claim ≥ 24 h old → stale,
proceed with takeover.

**Legacy claims** (no `{claim-id}`): if the latest trusted legacy
`claimed-by` is followed by a later trusted legacy `unclaimed-by` from
the same agent, treat as unclaimed. Otherwise use its age as above; on
takeover, migrate with a fresh `{claim-id}` and `supersedes: none`.

**Forced-handoff** (`<!-- forced-handoff: {...} -->`): transfers the
active claim to `newAgentId` / `newClaimId` only when **all** hold: the
comment author is a trusted marker actor; the author (case-insensitive)
equals the marker's `forcedBy` field — unconditionally, a
deliberately stricter bind than the full spec's opt-in
(`requireAuthorMatchesForcedBy`) — this blocks a
same-identity self-signed hijack where a displaced session spoofs a
different `forcedBy` name while posting the marker itself; that author
is authorized under `forcedHandoff.authorityPolicy`;
`forcedHandoff.mode` is `human-gated`; `oldAgentId` / `oldClaimId` /
`branch` all match the active claim; and, when an open PR already backs
this claim, the marker's evidence has `contextScope` of
`issue-plus-pr` with `linkedPr` naming that PR — an issue-only
handoff is not enough once a PR exists. On success, the
successor claim is **sticky**: adopt
`newAgentId` / `newClaimId` **verbatim** as your own for the rest of
the run (do not mint a fresh pair), and still post your own
activation-nonce for `newClaimId` (see Claim verification below) — this
is the one activation path with no separate `claimed-by` post. On any
failure, the active claim is unchanged; treat it under the rules above.

### (d) Open PR

No helper. Re-check live GitHub state: an open PR may close or reference
this issue only when its head branch matches an inheritable claim — the
verified active, stale, released, forced-handoff (matching branch and
linked PR), or legacy migration source. Check linked issues and PR-body
closing keywords (bare mentions and `Refs #N` do not count). A
non-inheritable match → **STOP**.

### (e) Branch collision

Compute the branch name (`issue/<number>-<slug>`) with the helper:

```sh
node scripts/branch-name.mjs --number <N> --title "<issue-title>"
```

Written fallback (`instructions-only` profile only): lowercase the
title; replace every non `a-z`/`0-9`
character with `-`; split on `-` and drop empty tokens and the
stop-words `a`, `an`, `the`, `and`, `or`, `in`, `for`, `to`, `with`,
`from`; rejoin with `-`; cut to 40 chars (back off to the last `-`
before 40 if the cut lands mid-token **and** a `-` exists there;
otherwise keep the hard 40-char cut); strip trailing `-`; empty result
→ `task`.

```sh
git worktree list --porcelain -z
gh api "repos/{owner}/{repo}/git/matching-refs/heads/issue/<N>-" \
--jq '.[].ref | sub("^refs/heads/"; "")'
```

Parse NUL records; detached: require `git -C <worktree> rev-parse
--show-toplevel` to match the canonical recorded root before reading
`head-name`/`BISECT_START`; failure/mismatch → STOP. Absent:
unrelated, or non-prunable with no `rebase-*` dir and no
`BISECT_START`. Otherwise (prunable, invalid, target, malformed,
unreadable) → STOP as occupied/unreadable (#3154 review).

<!-- dprint-ignore-start -->
| Match found? | Action |
| --- | --- |
| No local/remote match | Proceed |
| Stale/released + live/unknown | **STOP** — owner/FH + id |
| Inheritable match, no live local worktree | Proceed — expected |
| Non-corresponding match + active claim | **STOP** — concurrent |
| Non-corresponding match + no active claim | **STOP** — hold/orphan review |
<!-- dprint-ignore-end -->

Before activation, re-fetch the authoring label and paginated owner
log. A current/incomplete hold blocks; only exact
anchor/set/session `release-complete` with verified snapshots permits
activation.

## Claim execution

Skip step 4 (the `claimed-by` post) in two cases, and treat them
differently for step 5:

- **Pre-check (c) found this session already owns the claim**: this is
  a continuation, not a fresh activation — keep the recorded
  `{claim-id}`/branch, post no new `claimed-by` **and no new
  activation-nonce**. Skip straight to Claim verification (or Heartbeat
  posting if you are extending the stale clock).
- **Forced-handoff adopt-verbatim**: the handoff marker itself already
  performed the transfer, so no separate `claimed-by` post is required
  or allowed — but this **is** a fresh activation, so still run step 5
  (activation-nonce) for it.

1. **Branch name**: takeover, forced-handoff, or a fresh claim whose
   pre-check (e) scan matched an inheritable branch (released claim,
   legacy migration source, or matching PR) → reuse it verbatim, never
   recompute from the title (which may have changed since). No
   inheritable match → use the name pre-check (e) computed.
2. **`{claim-id}`**: generate a fresh opaque token — **except**
   forced-handoff adopt-verbatim, which reuses the marker's
   `newClaimId` instead. Record it with the profile-selected
   `claim-lock` helper's `--record-tokens` mode (`--worktree <path>
   --agent-id <id> --claim-id <id>`; resolve the exact command from
   `docs/idd-helper-scripts.md`) before step 4.
3. **`{prior-claim-id}` / `supersedes:`**: `none` for a fresh claim or
   legacy migration; the active claim's `{claim-id}` for a stale
   takeover. Not applicable to forced-handoff (step 4 is skipped
   there).
4. Post via helper (renders and POSTs the canonical JSON body):

   ```sh
   node scripts/post-idd-marker.mjs --type claim --target issue <N> \
     --agent-id <agent-id> --claim-id <claim-id> \
     --supersedes <prior-claim-id|none> --branch <branch-name> \
     --timestamp <ISO8601> --apply
   ```

   Written fallback (`instructions-only` profile only) — `gh issue
   comment` and `gh api -f body=` both silently reject
   HTML-comment-first bodies, so post this exact body with a direct
   HTTP `POST` carrying a JSON payload instead — for example
   `gh api --method POST repos/{owner}/{repo}/issues/{N}/comments
   --input -` fed the JSON on stdin, or `curl` with
   `-H "Content-Type: application/json"` and
   `-d '{"body":"<exact body below>"}'`:

   ```markdown
   <!-- claimed-by: {agent-id} {claim-id} supersedes: {prior-claim-id|none} {ISO8601-timestamp} branch: {branch-name} -->

   _{agent-id}: issue claim — IDD automation marker. Do not edit._
   ```

   **Nothing appended after the note.** Any content before the token,
   after the note, or a malformed note grammar makes the whole comment
   unrecognized as a live claim event.

5. **Every fresh activation** (fresh claim, takeover, legacy migration,
   or forced-handoff adopt-verbatim) also posts an activation-nonce —
   never for a plain heartbeat. Record it with the same
   `--record-tokens` invocation as step 2 plus `--nonce <nonce>`
   (primary worktree) first:

   ```sh
   node scripts/post-idd-marker.mjs --type activation-nonce \
     --target issue <N> --agent-id <agent-id> --claim-id <claim-id> \
     --nonce <fresh-opaque-token> --timestamp <ISO8601> --apply
   ```

   ```markdown
   <!-- activation-nonce: {agent-id} {claim-id} {nonce} {ISO8601-timestamp} -->

   _{agent-id}: claim activation nonce — IDD automation marker. Do not edit._
   ```

   On a same-`{claim-id}` collision (2+ trusted nonce markers), the
   winner is the lexicographically earliest `{nonce}`.

## Heartbeat posting

Only when this session already owns the active claim and is extending
its stale clock (holding past 12 h, or a phase will exceed 12 h):
repost using the **same command and body as step 4 above**, with
`{branch}` copied **verbatim** from the original claim (never
recompute), `{claim-id}` / `{agent-id}` matching exactly, and
`supersedes:` unchanged — a mismatch is anomalous and does not refresh
the stale clock. Skip step 5 (activation-nonce).

## Claim verification

**Already-owned continuation (no new post)**: pre-check (c)'s
top-branch `already_owned` result verifies ownership. Skip checks 1–4, but run
step 5's authoring guard; post no new `claimed-by` or nonce. Checks 1–4
require a fresh `claimed-by` and apply only to fresh claims, takeovers, and
legacy migrations.

For fresh activation, after posting `claimed-by`, wait the settle delay
(`claim.verifySettleDelay`, default `PT5S`), re-read all issue comments, then
check steps 1–4. Step 5 applies to both paths:

1. Build the same-second contender set: every trusted `claimed-by`
   (including yours) sharing your event's `created_at` second.
2. 2+ contenders → the lexicographically earliest `{claim-id}` wins
   (case-sensitive ASCII compare).
3. The active claim now uses **your** `{claim-id}` after that
   tie-break. A later trusted `claimed-by` with a different `{claim-id}`
   never disputes this (#3268): Claim-state parsing rules 4/6 could never
   have activated it, so it stays diagnostic only.
4. If you posted an activation-nonce for this `{claim-id}`, recompute
   its winner and confirm it is yours (no marker posted → treat as
   passed).
5. Re-fetch the authoring label and paginated owner log. A
   current/incomplete hold contests this claim; only exact
   anchor/set/session `release-complete` with verified snapshots
   passes. If it
   contests the claim but steps 1–4 passed and the pair is still active, post
   and verify `unclaimed-by` before stopping. If ownership/nonce is ambiguous,
   retain the claim and stop; never release on failed evidence.

Any failure → claim contested → **STOP**, do not proceed.

**Forced-handoff adopt-verbatim** only: skip steps 1-3 (no
`claimed-by` was posted for this path). Repeat the authoring guard above
before posting the activation nonce; only step 4 applies — wait the settle
delay (`claim.verifySettleDelay`, default `PT5S`), then recompute the nonce
winner for the adopted `newClaimId` and confirm it is yours. Repeat the
authoring guard after nonce verification; on a mismatch or hold, re-resolve
the pair and nonce before fallback, and release only after both remain
verified.
The successor pair is **sticky**: it re-activates on every resolution
pass, so a later plain `claimed-by supersedes: none` will not take
effect. To move off it, either keep adopting it verbatim, or post
`unclaimed-by` for both the sticky pair and the original displaced
pair (exact `{agent-id}`/`{claim-id}` each), then claim fresh.

Once verified, record this `{claim-id}` (and any posted nonce) as your
claim token for the rest of the run. Every later mutation (commit,
push, comment, label, reply, resolve, reviewer request, merge) must
re-verify this claim is still active — recompute the nonce winner too
when you posted one, and stop if it no longer matches — and, inside
the implementation worktree, that cwd and `git branch --show-current`
both match the claimed branch, before proceeding — a mismatch means
the claim was lost; stop, do not mutate further.

**Digest**: after verification, upsert the issue's `idd-live-status`
digest (only when exactly one exists, or none) — `Phase: A5 claimed`,
`Claim`, `Branch`, `Open blockers: none`, `Next action: B1 create
branch and worktree`. Multiple digests → report their URLs, do not
edit either.

## Worktree-local lock (same-machine fast path)

Once the B1 worktree exists, before every mutation:

```sh
node scripts/claim-lock.mjs --acquire --worktree <path> \
  --agent-id <agent-id> --claim-id <claim-id>
```

Then run `--read-tokens --worktree <path> --claim-id <id>` and
require `present: true` with no `malformed`; otherwise recover per
`docs/idd-helper-scripts.md` (gated: each step succeeds,
`reacquired: true` both ends), else stop.

A matching `{claim-id}` re-acquires as a read-only check. A different
`{claim-id}` is always a collision — run `--fresh-claim-gate` directly
(not pre-check (c)):

- `already-claimed` naming **your own** verified `{claim-id}`, with a
  top-level `reason` that is not `released-claim-*`: only the local lock
  drifted (crash / worktree recreation) — you still own the GitHub
  claim. Retry the lock with `--takeover` directly.
- Every other result — a `released-claim-*` reason, `already-claimed`
  naming a different id, or `claimable`/`stale-reclaimable`: the claim
  itself was lost. **STOP** and report; post no new claim from this
  check. Re-entry is only through a fresh Resume or Discover pass.

No release step (F4 `git worktree remove` deletes it).

Then continue to `idd-work-lite.instructions.md` when pre-check (d)
matched no inherited open PR — except on `instructions-only`, where
that file declines the profile in its own header; use
`idd-work.instructions.md` instead. When it did, continue at
`idd-resume-lite.instructions.md` Step 2.
