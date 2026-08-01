# IDD — Design Rationale and Maintainer Notes

This document collects maintainer-facing rationale, diagnostics, and
narrative justifications that explain _why_ IDD phase rules exist as
they do. The rules themselves stay in
`.github/instructions/*.instructions.md`; this file is the place to
record the context that helps future maintainers evaluate edits to
those rules without bloating the auto-loaded instruction surface.

Each section corresponds to one phase file. Add new rationale entries
under the matching phase heading. Behavior-changing constraints
(fail-closed defaults, claim revalidation, marker authority) must
remain in the instruction files.

## Discover

### A0-O roadmap-first fallback triggers

The `roadmap-first` A0-O fallback originally fired only when **zero
candidates reached A3.5** (trigger (a)) — A2 found no open execution
leaves, or A3 filtered them all out as blocked. But a candidate can reach
A3.5 and still be unworkable: a workshop leaf that runs a real external
deployment, or a "published" convergence checkpoint, can pass A3 readiness
and A3.5 (the owner self-approves), then fail the A4 viability gate
(Autonomous completion). Because they reached A3.5, the
original trigger stayed suppressed, so A4 stopped with "no viable
issue" and never fell back to A0-O even when claimable orphan issues
existed — forcing an operator opt-in every loop. The same shadowing
occurred when A4 Step 1.5 eliminated the last A3.5-startable candidate.

Trigger (b) closes that gap: the fallback also fires when the roadmap
path yields no viable, startable, unclaimed candidate because A4
Step 1 viability discards them all or Step 1.5 eliminates the last.
Three guards keep it safe:

- **Approval hold precedence.** A non-empty A3.5 approval-needed
  bucket is not a true zero; the fallback fires on viability/claim
  exhaustion only, never on the approval hold, so it never re-scopes
  around the approval gate.
- **True zero only.** It fires only when no viable, startable,
  unclaimed roadmap candidate remains — never when A4 discards some
  candidates but keeps others.
- **At most once per pass.** A0-O runs at most once as the
  roadmap-first fallback per Discover pass. Once spent (via trigger
  (a), (b), or (c)), any later A4 Step 1 / Step 1.5 exhaustion —
  reachable only after trigger (b) — reports and stops (not an abort)
  without re-entering A0-O. A **trigger (a)** or **trigger (c)** A0-O
  run that finds no orphan routes to the A3 decision tree (both paths
  genuinely empty); a **trigger (b)** one reports and stops instead,
  because roadmap candidates reached A4 — an exhaustion the A3 tree's
  A2/A3-empty cases do not describe. This prevents an
  A1 ↔ A0-O or A4 ↔ A0-O loop.

When **trigger (a)** (zero A3.5-reaching candidates) and the orphan
fallback both yield nothing, discovery lands in the A3 decision tree,
exactly as the zero-reach-A3.5 case did before. **Trigger (b)** instead
reports and stops (not an abort): roadmap candidates reached A4, so the
A3 tree's A2/A3-empty reports would misdescribe the exhaustion.
Triggers (a) and (b) are scoped to roadmap traversal (A2→A3→A4) — the
A0-T explicit-target gate keeps its own no-fallback stop.

**Trigger (c)** closes a third gap, one step earlier than (a)/(b):
triggers (a) and (b) both presuppose A1 already found a roadmap to
traverse. When A1 itself finds **zero open roadmap issues** — not "the
roadmap's graph is exhausted" but "no roadmap exists at all" — the
original text still hard-aborted immediately, even though
`roadmap-first`'s whole purpose is to fall back to orphan work when
roadmap work runs dry. Before trigger (c), this surfaced naturally whenever
a repository drained its last open roadmap: the final tracked issue shipped,
the roadmap closed, and the next Discover pass found zero open roadmaps —
Discover correctly identified A1's documented abort condition and stopped,
a harder stop than (a)/(b) impose for what was, from an
operator's perspective, the same underlying situation (no roadmap work
available right now).

Trigger (c) fires at A1, before A1.5/A2/A3 ever run. Like trigger (a),
an A0-O run it invokes that finds no orphan candidates routes to
the A3 decision tree — the **true zero** and **at most once** guards
above apply unchanged. The **approval hold precedence** guard doesn't apply
to trigger (c) the same way: only the roadmap-side A3.5 pass is
absent, since there is no roadmap candidate for it to run on — A0-O's
own A3.5 pass on any orphan candidates it finds still runs and can
still produce its own approval-needed bucket. Because
(a)/(b) require A1 to have found a roadmap and (c) requires it to have
found none, the three triggers are mutually exclusive within one
Discover pass — so "at most once per pass" holds automatically across
all three, not only within the (a)/(b) pair.

The `orphan-first` symmetric case — orphan candidates all failing A4,
which would fall back to the roadmap path — is a separate concern and
out of scope here.

### A3 — Diagnostic: all candidates blocked by an open roadmap

When the A3 decision tree reports zero ready-to-start candidates and
every candidate is blocked by an
`<!-- {{PROJECT_MARKER_PREFIX}}-blocked-by: X -->` marker that points
to an open roadmap, the markers may be misused as grouping tags.
Sub-tasks that run while the roadmap is open belong in the task list
(`- [ ] #NNN`); the `blocked-by` marker is reserved for issues that
must wait for a separate roadmap to close first. Treat this pattern
as a likely authoring defect, not a real dependency stall.

### A4 Step 1.5 — Rationale: active-claim pre-scan

Active-claim pre-scans eliminate known collisions deterministically
and reduce wasted claim-post-recheck cycles, improving scale-out
efficiency when multiple sessions start simultaneously. Without the
pre-scan, parallel sessions all claim the lowest-numbered viable
candidate at the same second, then race the same-second tie-break;
the pre-scan moves the resolution earlier in the pipeline so most
sessions never touch the same issue.

### A4 Step 2 — Rationale: concurrent-selection desync

A4 Step 1.5 (active-claim pre-scan) and A5(e) (collision detection plus
same-second tie-break) only resolve a selection collision **reactively**:
a losing session has already posted its claim and snapshot, then re-enters
Discover and — because Step 2's tie-break is the fully deterministic
lowest-issue-number — **re-collides** on the next candidate. Observed in a
multi-session run as a 3-way race on one score-5 issue whose two losers
then re-collided on the next lowest number.

The opt-in `discover.selectionDesync: session-offset` knob adds a
**proactive** desync: within a single highest-score tie band it picks the
entry at `selectDesyncedIndex(session-token, band-size)` (a pure
`hash(session-token) mod band-size`, the token being the selection-time
`{agent-id}`) instead of always index 0, spreading concurrent sessions
across _different_ eligible issues up front.

It is off by default and reorders **only within** a same-score tie band so
the documented score-then-lowest-number ranking is the unchanged single-
session and fallback behavior. The load-bearing invariant is that the
branch name (`issue/<n>-<slug>`) derives from the issue, not selection
order, so spreading sessions across different issues never breaks the
same-issue branch convergence that A5(e) and the `branch-name` helper rely
on. The desync never crosses score bands and never bypasses the A4.5/A5
gates; the in-band offset function is replaceable without affecting these
invariants.

### A4 — Scored-vs-unscored floor tie-breaker: what still ties afterward

Moved from the Discover phase file to keep the capped instruction
surface lean. After the scored-vs-unscored floor tie-breaker resolves
the mixed case, the remaining tie-breakers (concurrent-selection
desync, effort hint, lowest issue number) still apply in unchanged
relative order — for example, between two genuinely-scored candidates,
or between two unscored candidates when no genuinely-scored one is
present at that value.

## Claim resolution

### Forced-handoff strictness: strict resume vs. lenient relay-merge

Both the resume-routing read (`evaluateResumeClaimRouting` in
`resume-claim-routing.mts`) and the pre-merge write-gate
(`summarizeClaimValidation` in `protocol-helpers.mts`) resolve the active claim
through the **single** shared `resolveActiveClaim`, so there is no forked
claim-state logic. They deliberately pass **different** forced-handoff options,
and that difference is intentional policy, not drift:

- **Resume routing is strict.** It sets `requireAuthorMatchesForcedBy: true`
  (rule 7's author/`forcedBy` binding) and never passes `prFirstCommitAt`.
  Resume is a _takeover_ decision, so it must block the same-identity
  self-signed hijack and reject an issue-only handoff that targets a PR-backed
  claim.
- **The merge write-gate is lenient.** It leaves `requireAuthorMatchesForcedBy`
  at its off default and passes `prFirstCommitAt`, applying the Part-B allowance
  (kurone-kito/idd-skill#1058, an issue-only handoff predating the PR). The
  merge gate re-validates an _already-verified_ session and must tolerate a
  maintainer-authorized handoff relayed by a separate automation actor;
  authorization then rests on `isAuthorizedForcedHandoff` alone.

Because the two callers apply different strictness, they can return **different
verdicts for the same corrected-handoff state** — resume may report
`already_owned` while the merge gate reports `claimLost`. This is expected: the
verdicts answer different questions (may I take over? vs. does this verified
session still own the write?).

The split is kept intentionally (see kurone-kito/idd-skill#1155): the structural
risk the adopter raised — two divergent resolvers — is already removed by the
shared `resolveActiveClaim`, and forcing both sides strict would break the
legitimate relay use-case. Any future change here must preserve the single
resolver (do not fork `resolveActiveClaim`) and the resume-side
self-signed-hijack block.

### Activation-nonce: why a separate marker, and what stays deferred

kurone-kito/idd-skill#1480 found a verified near-miss: two independent
sessions can both adopt-verbatim the identical forced-handoff sticky
successor pair and both pass every `claim-id`-based check identically,
because nothing is posted at adopt-verbatim time to distinguish "the
session that legitimately adopted this pair" from "a second session that
also adopted it." kurone-kito/idd-skill#1522 closes that gap with a
standalone `activation-nonce` marker (`idd-claim.instructions.md`)
rather than a new field on `claimed-by`: adopt-verbatim posts no
`claimed-by` at all, so a field living inside `claimed-by`'s body could
never appear on the one path that motivates the mechanism. The winner rule
— lexicographically earliest `{nonce}` among however many trusted markers
exist for a `{claim-id}` — is a pure function of the observed nonce set
(mirroring the existing `{claim-id}` same-second tie-break), so two
colliding sessions compute the identical winner independently, with no
"both back off" livelock.

**Scope for #1522**: the issue's acceptance criteria name the **Claim
revalidation gate** (`idd-overview-core.instructions.md`) as the enforcement
point, and that gate is fully wired: it fires before any mutating step for a
live session holding its own posted nonce, and — since adopt-verbatim posts
no `claimed-by` and so never enters _Claim verification_ at all — the
adopt-verbatim paragraph in `idd-claim.instructions.md` carries its own
inline verify-then-compare instruction, the one path #1480 actually
exercises. Beyond the AC's letter, `evaluateResumeClaimRouting`
(`resume-claim-routing.mts`) also accepts `--claim-id`/`--nonce` and is
unit-tested, anticipating Resume Step 1 wiring — but the documented Resume
Step 1 invocation (`idd-resume.instructions.md`) never threads either flag
through, and a resumed process has no local memory of which nonce was its
own to compare against in the first place. That cold-recovery design
(kurone-kito/idd-skill#1529) is a natural fast-follow (the same shared
parse/render primitives already support it) — not a silent design gap.
The merge write-gate half landed separately: `summarizeClaimValidation`
(`protocol-helpers.mts`) now shares the same `findActivationNonceWinner`
primitive via `pre-merge-readiness.mjs`'s `--nonce` flag
(kurone-kito/idd-skill#1528), closing the one AC-adjacent surface #1522
deliberately deferred. The instruction-level half landed separately too:
`idd-pre-merge.instructions.md`'s F2 now instructs the session to pass
its own locally-recorded activation-nonce as `--nonce` when invoking the
readiness collector (kurone-kito/idd-skill#1615), so the merge-time
write-gate's comparison is no longer a documented-but-unreachable
no-op.

### Wrong-branch commit recovery: cherry-pick, never force-push

kurone-kito/idd-skill#815 named the risk directly: parallel worktrees
let a `git switch` move a checkout out from under another run, so a
commit lands on the wrong branch — typically the primary worktree's
`main`, or another issue's branch. The Claim revalidation gate in
`idd-overview-core.instructions.md` keeps the mechanical steps to a
one-line pointer to stay inside its byte budget; this page owns the
full procedure.

Recover by **cherry-picking** the misplaced commit onto the correct
issue branch (in its own sibling worktree), then restoring the
contaminated branch:

- **Unpushed** contaminated branch (typically the primary worktree's
  `main`): `git reset --hard` it back to its upstream.
- **Already pushed or shared**: do **not** `git reset --hard` then
  force-push to erase the misplaced commit — that is the forbidden
  force-push. Instead `git revert` the misplaced change, or let the
  operator evacuate the branch.

Either way, preserve that branch's real history and move only the
misplaced commit. `scripts/idd-doctor.mjs` warns on the same
primary-worktree-HEAD symptom this gate catches at mutation time.

## Work and self-review

### B1 Step 3 — install-deps silent under-install detection

Two independent fresh-worktree sessions observed a lockfile-frozen
package-manager install report apparent success while silently leaving
a key dependency binary missing (root cause unconfirmed; suspected
package-manager store/hardlink race). A thin generic wrapper around the
configured install command closes this gap: run the install, verify a
key binary exists, retry the install exactly once if it does not
(including when the install command itself fails), and fail loudly
with an actionable message if it is still missing after the retry. The
existing install-deps idempotency contract is preserved — the wrapper
never deletes or resets state, so reruns in fresh, reused, or recreated
worktrees still need no manual cleanup (kurone-kito/idd-skill#1237).

### B2.1 — Premise verification (decision-transcription issues)

Field evidence showed a worker asked to transcribe a maintainer's
already-recorded decision into documentation, where the decision's own
rationale asserted a checkable fact about what a prior change shipped
that the shipped code's own comment contradicted. The worker held,
surfaced the primary-source evidence, and only continued after the
maintainer corrected the record via an addendum. Nothing in the shared
instructions prompted that judgment call, and a documentation-only PR
has no test suite to catch a silently transcribed false premise later
(kurone-kito/idd-skill#1390).

### B3 — De-duplication refactor: check for behavior parity, not just body equivalence

Closes a real regression class: consolidating a wrapper function used
at multiple call sites into one shared function silently dropped
options or behavior (timeouts, stdio handling, error translation, etc.)
that some call sites' old delegate paths had been adding, because the
function bodies otherwise looked equivalent. It was caught only by an
ad hoc critique pass and a reviewer comment, not by written
implementation guidance (kurone-kito/idd-skill#1238).

### B3 — Dependency drift vs. own diff: a typecheck/lint diagnostic

A `typecheck`/`lint` failure in a file the current diff never touched
can look like a bug in the diff itself, when it is really dependency
drift or a broken `main` baseline — a real incident cost debugging time
this way before the guidance below existed
(kurone-kito/idd-skill#1164, kurone-kito/idd-skill#1193).

### B3 — Local test flakiness under concurrent load: hosted CI is authoritative

Field evidence from many concurrent local worktree sessions on one
machine showed delegated workers hitting local test timeouts on specs
their diff never touched; every failure passed an isolated re-run and
the hosted CI run (a dedicated, non-shared runner) stayed green each
time. This was plain CPU/resource contention, but each occurrence cost
real investigation before a worker could conclude "environmental, not
my change" — and the pattern recurs more as adopters scale out
concurrent sessions (kurone-kito/idd-skill#1391). Hosted CI governs
when it disagrees with a local outcome for the same commit; that does
not waive the fix-validate / pre-push-validate requirements themselves.

## Review triage

### Merge-main livelock under fast-moving `main`

Under heavy concurrent-session load, `main` can advance before one
{sync path → E1 → F1/F2} cycle finishes, re-triggering
`behind-no-conflict`; naive repetition livelocks, never reaching F3
while `main` keeps moving. The fix is procedural, not structural: post
the `review-watermark` as the last action before F3's
`idd-merge-execute.mjs --apply` on every pass, so anything that happens
after — a CI rerun settling, a new disposition reply, another `main`
advance — stales it and fails `--apply` closed on `review-currency`
rather than merging on data the retry has since invalidated.

### Zero-Accepted-PATH-A advisory re-review gate

Without this gate, E8's zero-Accepted-PATH-A path would skip E14 (the
only step that requests a fresh primary-advisory-bot review) entirely,
so a PR whose Copilot findings were all Rejected in a given pass could
reach F2's advisory-convergence check with the bot never having
reviewed the resulting HEAD. The gate closes that gap by running E14's
Primary advisory bot procedure at the now-stable HEAD whenever the last
non-empty snapshot this episode zeroed out on a completed-review PATH B
disposition, before proceeding to F1.

## Advisory wait

### AW3-S vs AW3-R: why two recovery paths

`AW3-R` fires only once the pending Copilot request is already proven
to cover HEAD (`COPILOT_PENDING_COVERS_HEAD = true`) and just needs a
missing marker anchored. The opposite, unproven case — a pending
request whose association with current HEAD cannot yet be confirmed —
cannot be resolved by `AW3-R`'s marker-only path, since there is
nothing yet to anchor. `AW3-S` adds a bounded remove/re-request/
verify/mark cycle for that case, deliberately capped far below the
ordinary `REQUEST_CAP` (30) by an independent per-HEAD recovery-cycle
budget (default 2), because each cycle mutates live reviewer state
(remove + re-request) rather than merely posting a marker.

### Terminal Copilot stall-recovery contract: why a separate signal

`COPILOT_UNAVAILABLE` is a signal structurally independent from every
existing advisory-satisfied field, rather than folded into
`outcome`/`f3Outcome` directly. Keeping it independent means a future
readiness rollup can consume it without risking a silent, accidental
widening of what already counts as "advisory satisfied" — the terminal
signal only ever unlocks a maintainer waiver path, never merge
readiness on its own. `AW3-S`'s `"cap-exhausted"` classification
deliberately does not by itself prove `COPILOT_UNAVAILABLE`: a HEAD can
exhaust its recovery-cycle budget while the terminal window has not yet
elapsed, or while a fresh same-HEAD review has since landed — either
fact alone would make an immediate terminal declaration premature.

### Non-Copilot advisory convergence is intentionally not a merge gate

kurone-kito/idd-skill#909 (2026-06-17) decided, in the idd-skill source
repository's own configuration, that the Copilot advisory-wait /
convergence protocol stays **Copilot-only** there, where Copilot is
the configured `advisoryWait.primaryBotLogin`. An adopter repository
may mirror or override that posture. Configured secondary, non-primary
`advisoryBotLogins` (e.g. a CodeRabbit or Codex connector) get no
equivalent merge-blocking required check. (A repository using the
`external-bot` profile to route `advisoryWait.primaryBotLogin` to a
non-Copilot bot instead would gate on that bot's convergence the same
way — this reaffirmation is scoped to the non-primary advisory bots,
not to "non-Copilot" as a fixed identity.) kurone-kito/idd-skill#899
recorded the deliberate scope and its two-part safety net: **pre-merge**, the E1
activity-universe snapshot plus `review-watermark` delta catches a late
finding before merge by forcing a return to E1 when the F2/F3
pre-merge gate detects new activity; **post-merge**, a merged-PR
unresolved-feedback sweep (kurone-kito/idd-skill#931) — a
manually-invoked, read-only detector whose output an operator feeds
into fresh issue authoring, not an automatic recovery path. It
surfaces two kinds of item: (1) a top-level regular comment or
`CHANGES_REQUESTED` review body with **no later** IDD disposition
anywhere on the PR (its collectors compare each item's timestamp
against a single global disposition cutoff, not a per-item reply
check, so an item posted before the latest disposition counts as
"addressed" even when that disposition was for something else
entirely, including a disposition reply found inside a review thread —
the global cutoff folds those in even though this collector's own
output only ever lists top-level comments and review bodies, never
thread items); and (2) any review thread still **unresolved** at
merge time and not opened by an IDD agent itself, regardless of
whether it carries a disposition reply (that collector filters on
resolution state and origin-comment author, flagging
`dispositioned: true`/`false` either way). Symmetrically, the sweep
has **no backstop** for: a comment or review body with _any_ later
disposition, correct or not; a thread an IDD agent itself opened; or
a review thread that was **resolved** — whether with a correct
disposition, a false disposition, or no disposition reply at all.
Resolving a thread removes it from consideration outright.

kurone-kito/idd-skill#1352 re-opened the question after a required-check
promotion shipped for the Copilot dimension, and after a weak-model
structural audit found a concrete non-Copilot fail-open: the review-triage
phase can mis-classify a non-Copilot bot's **non-review notice**
(rate-limit, "usage limits reached", queued) as a completed clean review,
and the disposition verifier validates the model's own self-report rather
than live GitHub — so an omitted or false disposition passes. Under
`fully_autonomous_merge`, that path can reach merge without a
GitHub-side block.

The maintainer **reaffirmed kurone-kito/idd-skill#909** on
kurone-kito/idd-skill#1352 (2026-07-14): the operational objections are
unchanged and still outweigh a hard gate — non-Copilot bots are capricious
(a run may post nothing at all, and a review bot's first post is often a
PR summary rather than actionable findings), re-review is mention-only
with no clean per-HEAD completion signal, and pinging a bot risks waking a
lenient reviewer mid-merge. The mis-classification and self-attested-
disposition fail-opens are therefore recorded as an **accepted risk**
under `fully_autonomous_merge`, not a defect — the pre-merge snapshot
net still catches a late-arriving finding before merge, but a false
disposition it already produced has no sweep backstop (see above),
same as kurone-kito/idd-skill#909 originally decided to accept. A
repository that reaches this same conclusion
independently should record it here rather than re-litigating it on every
structural audit.

## CI

### 404-vs-403 ambiguity on branch-protection/ruleset reads

None of the three required-check-discovery endpoints (branch
protection, ruleset list, ruleset detail) documents `403` as a possible
response at all: the branch-protection reference lists only
`200`/`404`
(<https://docs.github.com/en/rest/branches/branch-protection#get-branch-protection>),
and the ruleset-list/ruleset-detail references list only
`200`/`404`/`500`
(<https://docs.github.com/en/rest/repos/rules#get-all-repository-rulesets>,
<https://docs.github.com/en/rest/repos/rules#get-a-repository-ruleset>).
GitHub's own REST troubleshooting guide documents this as general API
behavior: a `404` on a private resource substitutes for `403` to avoid
confirming the resource's existence, and insufficient token scope is a
listed cause of a `404` on a resource that actually exists
(<https://docs.github.com/en/rest/using-the-rest-api/troubleshooting-the-rest-api#404-not-found-for-an-existing-resource>).
Because these endpoints never document `403`, a `404` on any of them
is structurally ambiguous between "genuinely nothing configured" and
"the token cannot read this" — the response body cannot resolve that
ambiguity, and an actor's collaborator role cannot either (role is not
proof the caller's own token carries the scope the endpoint requires).
This is why `idd-ci.instructions.md`'s Required-check discovery step 4
treats every `404` on these reads exactly like a `403` unless the
repository opts out via `ciGate.trustEmptyProtectionReads: true`.

## Pre-merge

### The non-advisory pre-merge dimensions are model-attested, not GitHub-side enforced

The pre-merge condition check (`idd-pre-merge.instructions.md`) and the
merge-time re-verification (`idd-merge.instructions.md`) gate claim
ownership/freshness, late non-Copilot review currency, non-Copilot
unresolved threads, and `dispositionEvidence` completeness through a
deterministic readiness helper. Unreplied comments are a separate
case: that helper's rollup deliberately excludes them, so this
dimension is gated only by the written checklist. None of these
dimensions has a dedicated GitHub-side
required check backing it — unlike the Copilot advisory-convergence
dimension that can be promoted to a trusted-checkout required check
(kurone-kito/idd-skill#1341, kurone-kito/idd-skill#1342). (A repository
that separately turns on GitHub's branch-protection
conversation-resolution requirement gets GitHub-side enforcement for
the unresolved-threads dimension specifically, as a side effect of
that unrelated setting — see the conversation-resolution exception in
`idd-pre-merge.instructions.md` — but that is opt-in and not part of
this reaffirmed posture.)

The helper is explicitly allowed to be **discarded**: the pre-merge phase
states that when helper execution fails, its output is invalid, or live
GitHub state disagrees with it, the session discards the helper output and
falls back to a direct live fetch plus the written prose rules. A weak
model can reach the merge command via that self-attested prose path
without the deterministic verdict actually forcing the block.

A repository choosing to accept this posture (kurone-kito/idd-skill#1353
reaffirmed it 2026-07-14) should record why: the "discard on
unavailable/invalid/conflict → prose fallback" clause is a deliberate
adopter-resilience valve (the helper runtime is optional, and a pure
PR-level required check cannot see a session's live `claim-id`/`agent-id`
context the way the model-run helper can); a full session-aware required
check can also fight a deliberately narrow CI trigger topology
(kurone-kito/idd-skill#832, which keeps CI scoped to `pull_request` only,
so nothing re-checks the merge commit itself) and existing checklist
hardening (kurone-kito/idd-skill#993). Under `fully_autonomous_merge`
this is then an **accepted risk**; adopter repos that keep a human
merge step retain that human as the backstop the autonomous path lacks. A
repository that reaches this same conclusion independently should record
it here rather than re-litigating it on every structural audit.

## Instruction delivery

### Skill-based on-demand delivery of phase instructions: no-go (2026-07-16)

kurone-kito/idd-skill#1416 investigated packaging IDD phase instructions
(`.github/instructions/idd-*.instructions.md`) as Claude-compatible
skill bundles (`SKILL.md` under `.claude/skills/` / `.opencode/skills/`),
on demand, motivated by kurone-kito/idd-skill#1413's OpenCode support
track: OpenCode's only conditional-loading mechanism is skills, unlike
Copilot's `applyTo` frontmatter. The full findings live in the source
repository's `docs/skills-delivery-investigation.md`, which reaffirms
and extends `docs/claude-skill-strategy.md`'s prior Claude-Code-only
no-go (which evaluated wrapping the whole execution loop as a skill) to
explicitly cover OpenCode.

The decision: **no-go**, for either agent, under the current phase-file
boundaries. Once an OpenCode entry-file generalization ships
(kurone-kito/idd-skill#1414), OpenCode gains the same
routing-table-plus-on-demand-Read mechanism Claude Code already has, so
a skill wrapper would change only _how_ a phase file is requested, not
_whether_ it already loads on demand. More importantly, neither runtime
documents a "must load unconditionally" primitive for skills — every
invocation path is either an explicit model/user action or a subagent
preload, never a forced load at session start — so converting a
load-bearing phase file (e.g. `idd-claim.instructions.md`,
`idd-pre-merge.instructions.md`) into a skill would replace a
deterministic routing-table read with a probabilistic model judgment
call, weakening exactly the fail-closed guarantee the overview-core
claim-revalidation gate relies on those phase files being read for. A
third synchronized surface alongside the canonical template and the
generated instruction files would also multiply the drift matrix for
every phase-file edit.

Conditions that would revisit this: recorded evidence of routing-table
navigation failures on either agent at a material rate; either runtime
documenting a mandatory/required skill-invocation primitive; or explicit
adopter demand for skill-form delivery with a concrete use case the
routing table does not already serve. A project that reaches this same
conclusion independently should record it here rather than re-running
the investigation.

## Documentation conventions

### Cite the observed incident

kurone-kito/idd-skill#1596 adopted this convention after observing that
`mew-ton/soloscrum` cites a concrete incident for each entry in its
anti-pattern lists (for example, "Observed 2026-05-09 on issues 8 and
9" in that project's own tracker — not this repository's). A citation
raises the authority of a documented prohibition for
both humans and weak models — the rule reads as field evidence, not
authorial preference — and lets a later session check whether the
cited incident still motivates the rule.

When documentation or instruction text names an anti-pattern or
failure mode, cite the concrete incident that motivated it: a date
plus an issue or PR reference, when one exists. When no such incident
exists — the rule is preventive rather than a response to something
that already happened — say so explicitly, using the phrase
"preventive; no observed incident yet", so the absence of a citation
reads as a deliberate statement rather than an omission.

The convention applies **forward**, to new or edited passages only.
Retrofitting an existing passage with a citation is in scope on
budget-exempt `docs/` surfaces, but out of scope for
`.github/instructions/` files — do not edit an instruction file
solely to add a citation; those bundle budgets already sit near their
ceiling (see the headroom review in kurone-kito/idd-skill#1525).
