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
`<!-- setup-windows-blocked-by: X -->` marker that points
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
`hash(session-token) mod band-size`) instead of always index 0, spreading
concurrent sessions across _different_ eligible issues up front.

`session-token` must be a per-session-unique value, never the bare,
session-shared `{agent-id}` alone: `idd-overview-core.instructions.md`
defines `{agent-id}` as shared across concurrent sessions of the same
agent type, with a unique session suffix only recommended, not required.
Sessions that follow that core definition literally and omit the suffix
all hash to the identical index and converge on the same issue — the
same converge-and-collide shape as the 3-way race above. This specific
bare-agent-id collapse is preventive; no observed incident yet —
kurone-kito/idd-skill#1694 identified it by inspection of the two
files' definitions, not from a collision that already happened.
`idd-discover.instructions.md` closes the gap by requiring the
session-suffixed `{agent-id}` or, when the agent-id carries no unique
component, a session-local fallback token generated once at Discover
entry and reused for the session — with enough entropy
(random or UUID-derived) to stay distinct across sessions launched at
the same moment, since a bare timestamp alone would not.

It is off by default and reorders **only within** a same-score tie band so
the documented score-then-lowest-number ranking is the unchanged single-
session and fallback behavior. The load-bearing invariant is that the
branch name (`issue/<n>-<slug>`) derives from the issue, not selection
order, so spreading sessions across different issues never breaks the
same-issue branch convergence that A5(e) and the `branch-name` helper rely
on. The desync never crosses score bands and never bypasses the A4.5/A5
gates; the in-band offset function is replaceable without affecting these
invariants.

### A4 Step 2 — Rationale: milestone-scope preference

A GitHub milestone groups scope for a release (e.g. `v0.8.0`) purely as
human-facing material; Discover never read it before
kurone-kito/idd-skill#2340. A4 Step 2
already ranks by suitability score, then the optional concurrent-selection
desync, then the effort hint — none of which prefer the work a release is
actually waiting on, so concurrent autopilot sessions drain the backlog
issue-by-issue with no way to converge on a milestone's scope first. An
operator's only lever was re-explaining the priority to every session by
hand.

`discover.milestoneScope` (optional string; unset means off) closes that
gap the same way `selectionDesync` and the effort hint do: a **soft**,
same-score-band-only preference, never a gate. When set, a candidate whose
**OPEN** milestone title equals the configured value sorts ahead of other
candidates in the same suitability-score tie band, positioned after
selection-desync (session spread stays available even within a
milestone-preferred set) and before the effort hint (release intent
outranks size preference, but both still apply only inside one band).

The preference is symmetric-neutral by construction: an unset or empty
`discover.milestoneScope`, a candidate with no milestone, a **closed**
milestone, or a missing `milestone` field from the API all collapse to
the same "no preference" case, so a partial or stale read never
silently misroutes a candidate — it just falls through to the
pre-existing effort/issue-number order. Closed milestones are
deliberately excluded (not merely ranked lower) so a candidate never
keeps sorting ahead of its band after its release has already shipped.
`discover-roadmap-graph` and `discover-orphan-filter` surface the
resolved `milestone` title in their own outputs so the ranking input is
visible evidence, not a value an agent has to re-fetch to audit a pick.

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
own to compare against in the first place. Cold recovery
(kurone-kito/idd-skill#1529) now fail-closes: a resume that holds no
local nonce treats 2+ trusted activation-nonce markers for the active
claim-id as `disputed`/`stop` rather than guessing an owner.
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

### Claim release has no compare-and-swap: deferred (2026-08-13)

While resolving kurone-kito/idd-skill#1985 (PR kurone-kito/idd-skill#1993's
"Operator-present release" recovery path), round 6 review found that the
claim-marker protocol has no atomic compare-and-swap for releasing a
claim: `idd-claim.instructions.md`'s Claim-state parsing rule 5 releases
a claim via `unclaimed-by` on an exact `{agent-id}`/`{claim-id}` match
alone, with no check on whether the releasing session's belief ("no
later claimant activity") is still true at write time (preventive; no
observed incident yet). The maintainer accepted this as a documented,
bounded residual risk for kurone-kito/idd-skill#1985 specifically —
blast radius already limited
by the pre-existing claim revalidation gate, since a session that loses
its claim mid-window detects it on its own next required pre-mutation
check and stops, making this a detectable lost-claim event rather than
silent double-ownership. kurone-kito/idd-skill#2000 recorded the broader
protocol-level question that decision deliberately left open: should the
claim-marker protocol close this gap generally, beyond that one path?

**What "true CAS" would actually require.** Two GitHub-native mechanisms
give genuine atomic compare-and-swap, and both were considered and
rejected rather than being unavailable:

- **Non-force git ref updates** (e.g. `refs/idd/claims/issue-N`) — a ref
  update only succeeds as a fast-forward of its current value, which is
  real CAS with zero external infrastructure. Rejected because it
  abandons the append-only, human-readable, trusted-actor comment ledger
  the entire IDD claim/audit/trust model is built on.
- **GitHub Actions concurrency groups** — routing claim mutations through
  a per-issue-serialized dispatched workflow gives real mutual exclusion.
  Rejected on added latency, a hard dependency on Actions, and
  incompatibility with the `instructions-only` helper profile, which by
  design requires no workflow at all.

Neither is impossible — both trade away a load-bearing IDD design
property (portability, comment-ledger auditability, or
infrastructure-free operation) that this repository has consistently
protected elsewhere.

**What's actually achievable without new infrastructure.** The claim
protocol already has a self-healing, re-derivable consistency check for
the _take_ side: Claim-state parsing rule 4 re-evaluates whether a
superseded claim was genuinely stale **at the new comment's own
`created_at`**, from the live comment timeline — not from whatever the
superseding session believed when it decided to act. If a heartbeat
lands between a session's stale-check read and its takeover post,
replaying the timeline correctly invalidates the takeover. This is
optimistic concurrency with post-hoc detection, not true atomicity, but
it is genuinely self-healing. The _release_ side (rule 5) has no
equivalent: it is a bare identity match with no timeline-derived
liveness predicate. The parser-level fix would mirror rule 4's pattern
for releases — e.g. an `unclaimed-by` variant that embeds the timestamp
of the pause-evidence comment it is anchored to, honored only if no
trusted claimant activity has a `created_at` between that anchor and the
release event itself, re-derivable by any future parser exactly like
rule 4's staleness check already is. This would need a **new sibling
marker type** alongside the existing `unclaimed-by`, not a field added
to that same token: the existing token is parsed by a strict whole-body
anchor regex requiring exactly its current fields and nothing else, so
every existing (and every not-yet-upgraded) parser would read an
extended token as malformed and silently lose the release event. A new
sibling type keeps old parsers on today's accepted-risk behavior while
letting new parsers apply the stronger check.

**Coverage is inherently partial either way.** Even with the parser
extension, only comment-visible activity (heartbeats, comments, reviews)
is re-derivable from the timeline. The Operator-present release path's
own prose predicate also considers branch/PR movement, which a
comment-timeline parser cannot see. Rule 4's existing stale-clock has the
identical limitation today (only heartbeats refresh it, not pushes), so
this would be consistent with the existing design rather than a new gap
— but it means even the "real" fix would not fully close the class of
race the round-6 finding raised.

**Revisit triggers.** Reconsider this only if either becomes true:

- An **actually-observed** instance of this race class occurs (not a
  theoretical review finding) — i.e., a session genuinely loses work or
  produces confusing state because of a stale-read release, takeover, or
  forced-handoff decision.
- This repository's operating model shifts toward materially higher
  concurrent-session, multi-writer load on the same issues (today's
  desync/contention tooling — `discover.selectionDesync`,
  `discover-shared-file-overlap` — targets _different_-issue
  parallelism, not concurrent claim decisions on the _same_ issue).

**Candidate files (if ever pursued)**, named as they land once imported
(the `idd-template/` prefix drops from this document's own path, and
`src/scripts/*.mts` never ships — an adopter's `vendored-node` profile
gets the generated `.mjs` copy instead; `package-manager`/`ephemeral-npx`
resolve the same logic through the installed package rather than a
local file; `instructions-only` has no helper runtime at all, so this
deferred work would need direct instruction-level parsing rules there
instead of a helper file. The repository-local
`docs/idd-design-rationale.md` mirror keeps the source-tree paths,
since those genuinely exist there):

- `.github/instructions/idd-claim.instructions.md` (Claim-state
  parsing rules, marker format)
- `.github/instructions/idd-overview-core.instructions.md`
  (Claim format / Unclaim format sections)
- `.github/instructions/idd-resume.instructions.md` (Operator-present
  release Step 2 — the actual writer of today's bare `unclaimed-by`; a
  guarded release marker needs this call site too, or the race it
  targets would remain unguarded here)
- `scripts/marker-helpers.mjs` (marker regex/parsing; `vendored-node`
  only)
- `scripts/protocol-helpers.mjs` (marker classification;
  `vendored-node` only)

Deliberately deferred, not `needs-decision`: there is no currently
blocking choice, since kurone-kito/idd-skill#1985 already resolved its
own narrower question. This record moved here from
kurone-kito/idd-skill#2000, which stayed open only as a findable record
until one of the revisit triggers above fires.

### Context-inheriting delegation residual risk

kurone-kito/idd-skill#2624 adopted a documented positive-framed
mitigation for the [Orchestrator delegation](../.github/instructions/idd-claim.instructions.md#orchestrator-delegation)
context-inheriting fallback: the delegation brief must state
explicitly that the delegate is the sole worker for the named issue,
with no peer workers to coordinate with or wait on. That issue was
scoped to the wake-up-discipline stall pattern and did not evaluate
this mitigation against a different, related failure mode: a
context-inheriting delegate mistaking itself for the orchestrator that
dispatched it, rather than the worker the brief names it as.

kurone-kito/idd-skill#2802 recorded direct field evidence, from this
project's own dogfooding, that neither that positive-framed
mitigation, nor an added explicit negative instruction naming the
failure mode directly, reliably prevents it: three independent
occurrences of a context-inheriting delegate (sharing the
orchestrator's own full conversation transcript) opening its first
turn by describing having delegated to, and now waiting on, a
sub-worker that did not exist — the delegate itself was the intended
worker — even when the brief's role-reassignment wording matched the
documented mitigation nearly verbatim, and even when a further attempt
added an explicit negative instruction naming the confusion directly.
Each occurrence needed an explicit follow-up message (or abandoning
delegation entirely) to correct. See kurone-kito/idd-skill#2802 for the
full narrative and observation counts.

**Adopted mitigation**: state the non-context-inheriting delegation
mechanism as a strong preference, not merely a suggestion, whenever
the calling tool offers one, and record the context-inheriting
fallback's residual role-misread risk explicitly as a known, accepted
limitation next to the delegation-brief wording, rather than
continuing to iterate on brief wording that field evidence shows does
not reliably close the gap.

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

### WorkTrunk cwd caveat

An adopter session, using WorkTrunk's automation-safe invocation (`wt
switch --create ... -x true`), observed a `Cannot change directory —
shell integration installed but not active` diagnostic that did not fail
the command. From that point onward, the agent harness's own tool output
repeatedly reported the shell's working directory as reverted to the primary
worktree root, even immediately after a command that had run correctly in the
sibling worktree. Attribution between the harness's own working-directory
tracking and WorkTrunk's shell-integration hook could not be isolated (no
control-group session was available), so this stays a documented structural
gap in B1's guidance, not a claim against either component: the one-time
B1 self-check gives no signal to keep re-verifying the working directory
after this diagnostic appears, even though the "working directory persists
between commands" assumption can silently stop holding from that point
on (kurone-kito/idd-skill#2332).

**What to do**: once this diagnostic appears, treat the working directory
as unverified for every later command in the session — confirm it (e.g.
`pwd`) before trusting a command that depends on the current directory,
rather than assuming it still matches the last-known worktree.

### B1 self-check — Grok Build file tools bound to launch workspace

A Grok Build session's file-read and file-edit tools resolve relative
paths against the session's launch workspace — the primary clone,
whose HEAD B1 keeps on `main` — not the shell's current directory, so
a `cd` into the sibling worktree does not rebind them. Reproduced by
creating a sibling worktree, writing a unique marker only into that
worktree's uncommitted `README.md`, then running Grok's
workspace-default grep for the marker: it found nothing, while the
same grep given the sibling's absolute path found it immediately. A
shell `cd` into the sibling and a `pwd` reporting the sibling path
both looked like a passing B1 self-check throughout
(kurone-kito/idd-skill#2819, 2026-09-10).

This is a different failure class from
kurone-kito/idd-skill#2114's off-convention worktree-creation
primitives (`grok --worktree`, `isolation: worktree`,
`x.ai/git/worktree/*`): there, B1 creates the wrong worktree
altogether; here the worktree is correct and only the file tools'
workspace binding stays stale. It sits alongside
kurone-kito/idd-skill#2332's WorkTrunk cwd-tracking caveat above as
another way a harness's own working-directory signal can drift from
what B1's self-check actually verifies.

**What to do**: for a harness whose file-read/edit tools stay bound to
the launch workspace, pass every such tool call the sibling worktree's
absolute path instead of relying on a shell `cd`; a shell `pwd`
reporting the sibling path is not evidence those tools moved with it.

### C1/B2 critique pass — Grok `spawn_subagent` needs a bounded fallback

Grok Build's critique-pass row, unlike Codex CLI's, had no fallback
when `spawn_subagent` is unavailable, unsuitable, or fails — Grok
_has_ `spawn_subagent`, so a successful-but-unbounded pass never fell
back to a structured self-critique. In the Grok Build IDD loop that
shipped kurone-kito/idd-skill#2814 for issue kurone-kito/idd-skill#2774
(observed 2026-09-09, kurone-kito/idd-skill#2814): B2 plan critique
ran 387 s across 43 tool calls, C1 diff critique ran 575 s across 40
tool calls, and a C1 re-critique whose brief named two files plus
`git diff origin/main...HEAD` and said "keep this short" still ran
172 s across 25 tool calls and opened extra search rather than staying
on the named slice. The findings were usable, but one docs-only issue
spent roughly 19 minutes in critique subagents; Claude Code's `Agent`
path for the same C1 role is typically a short bounded review, while
Grok's general-purpose subagent treated the checklist as an
open-ended explore (kurone-kito/idd-skill#2825).

This is a different Grok gap from kurone-kito/idd-skill#2819's file
tools bound to the launch workspace (above) and closed
kurone-kito/idd-skill#2114's worktree-creation primitives: those are
B1 worktree/tool-cwd; this is the C1/B2 critique _mechanism_ row.

**What to do**: give Grok's critique row the same fallback class Codex
already has (structured self-critique when delegation is unavailable,
unsuitable, or fails) without inventing a wall-clock or tool-call cap,
and require the critique brief to name the files or diff under review
so an unsuitable pass is easier to distinguish from a thorough one.

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

### B2.2 — Example field-name verification

Issue kurone-kito/idd-skill#2806's own "Proposed change" section cited
an illustrative gate field, `claimValid: false`, that did not exist
anywhere in `schemas/pre-merge-readiness.schema.json` — the real
fields are `claim.matchesExpectedClaim` / `claim.claimLost`. B2.1 did
not apply because that issue was an ordinary bugfix issue, not
decision-transcription, and the fabricated field appeared in an
illustrative example, not a rationale claim, so nothing in the written
instructions caught it during that issue's own implementation, PR
kurone-kito/idd-skill#2875; a Codex review caught it instead, after
the text had already shipped once. A maintainer hearing recorded on
kurone-kito/idd-skill#2878 added this narrow, adjacent check rather
than broadening B2.1's own condition.

### B3 — De-duplication refactor: check for behavior parity, not just body equivalence

Closes a real regression class: consolidating a wrapper function used
at multiple call sites into one shared function silently dropped
options or behavior (timeouts, stdio handling, error translation, etc.)
that some call sites' old delegate paths had been adding, because the
function bodies otherwise looked equivalent. It was caught only by an
ad hoc critique pass and a reviewer comment, not by written
implementation guidance (kurone-kito/idd-skill#1238).

### B–C — Follow-up discovery bypassed issue authoring

On 2026-08-24, issue #2231 recorded that B-phase workers discovering
separate follow-up work had no unconditional in-file route to the optional
issue-authoring companion and had been observed creating issues directly.
The B–C guard now routes that work through Stage 1 or preserves it in a
durable issue comment when the companion is unavailable
(kurone-kito/idd-skill#2231).

### Stage 1 — Shared hold ownership conflict

On 2026-08-24, issue #2231 also recorded that a shared authoring label did
not identify the session holding a follow-up target, leaving concurrent
passes able to race through reuse and body wiring. The per-target trusted
owner-marker protocol, visible-note JSON posting, persisted anchor identity,
fresh re-reads, and same-owner heartbeat renewal before edits close that
observed conflict path (kurone-kito/idd-skill#2231).

### Stage 1 — Non-atomic new-issue publication window

During the 2026-08-24 remediation of issue #2231, review verified a concrete
create-then-label race: a newly created follow-up could exist without the
authoring label between two separate mutations, allowing another Discover
pass to see it before the hold was applied. The atomic create-with-label
requirement, capability check, and stop-before-create fallback close that
publication window (kurone-kito/idd-skill#2231).

### Stage 2 — Set-level release rollback safety

The same remediation exposed a set-level rollback hazard: if an early label
removal closed its target generation before a later removal failed, the
restoration owner check could fail and leave that target visible to Discover.
Release markers are therefore provisional until every target, with the anchor
last, has been verified; release retries reuse the verified marker comment ID
instead of appending an indistinguishable duplicate. Anchor identity is
persisted in every owner marker, and every Stage 1 edit re-reads both the
target and the set anchor (kurone-kito/idd-skill#2231).

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

### B3 — Edit the canonical source of a generated docs/instructions file, not its mirror

An adopter repository that generates some of its own `docs/**.md` or
`.github/instructions/**.md` files from a canonical source (via a
sync-docs-style tool) can lose a fix silently: an agent edits the
generated mirror directly, the change looks correct locally, but the
next sync run regenerates the mirror from its canonical source and
discards the edit without any error -- a real incident cost a
revert-and-redo cycle before the guidance below existed
(kurone-kito/idd-skill#2548). The mistake is easy to make because the
mirror and its canonical source are often byte-identical or
near-identical, giving no visual cue at a glance. Only a
`.github/instructions/**.instructions.md` mirror is guaranteed to
carry a visible `idd-generated-from` banner at its top; a `docs/**.md`
mirror may not, depending on the sync tool's own behavior, so the
banner check alone can miss exactly the file class most likely to be
mistaken for hand-editable prose. Checking the sync tool's own
manifest for a matching target entry closes that gap for `docs/**.md`
files, at the cost of one extra lookup.

### C1 — Search sibling code for the same defect shape before closing

A bug fix scoped to the single reported call site can leave the
identical defect shape unpatched elsewhere in the same file, or in an
independently-maintained sibling implementation of the same logic.
`kurone-kito/idd-skill#1471` fixed a stale-multi-instance-rollup
defect in one file; a follow-up C1 pass on that same PR separately
found the identical shape in an independently-maintained equivalent
file, filed as `kurone-kito/idd-skill#1478` -- outside the original
issue's own acceptance criteria. `kurone-kito/idd-skill#2475` (a
shared, loop-wide de-duplication `Set` that let only the
alphabetically-first named actor be credited when a single reply
named several) repeated the pattern in the same file: the reported bug
and its initial fix covered only one function, and a separate critique
pass -- run to verify the fix, not to search for new work -- found the
identical shape unpatched in a second, structurally separate loop
elsewhere in that file. When a bug's root cause is a reusable defect
shape rather than a one-off typo, search the rest of the containing
file -- and any independently-maintained sibling implementation of the
same logic -- for the same shape before treating the fix, or a C1
critique of it, as complete (observed 2026-09-03,
kurone-kito/idd-skill#2552).

## PR submit

### D2 — Adding a new CI job: dispatch-first rollout

An adopter repository whose review automation (for example a Copilot
or Codex code-review app) re-runs on every push accumulates review
cost roughly 1:1 with commit count, independent of which files or CI
jobs a given push touches. A new CI job whose target runner cannot be
exercised locally compounds this: each debugging attempt needs a real
push-and-wait round trip, so every unverified hypothesis about why the
job fails costs a full review cycle on top of the CI minutes spent.
Landing the job `workflow_dispatch`-first and validating it via manual
dispatch runs does not reduce that review cost by itself -- the review
re-run is driven by the push, not by the job's trigger wiring -- but
it does stop an unproven job from auto-running (and burning runner
minutes, and adding failure noise) on every unrelated push during the
same pull request's remaining lifetime. The one path that does avoid
review cost entirely is iterating a Windows-/macOS-targeted job on a
branch with no open PR yet: review automation that only fires on
PR-associated pushes never runs during that shakeout, so a push to a
PR-less branch never triggers a review at all -- this is why that
non-PR shakeout pattern is worth documenting as an option, scoped to
CI-infrastructure-focused work, even though it deviates from the
normal early-PR-then-iterate practice.

Observed 2026-09-10 on PR kurone-kito/idd-skill#2897 (issue
kurone-kito/idd-skill#2892): three independently-reasoned, unverified
commits debugging a native-Windows-only CI hang in a new
`lint-windows` job each triggered a fresh full Copilot and Codex
review and left the job's own regression test failing at a
near-identical elapsed time each round -- direct evidence none of the
three changed anything that mattered, and each round could only be
diagnosed by pushing and waiting on a real run, since the repository's
own IDD implementation sessions are WSL/Linux-only and cannot exercise
a `windows-latest` runner locally (kurone-kito/idd-skill#2892,
non-blocking).

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

### An advisory bot's embedded-but-unthreaded findings: mirror the detection scope, not the gate scope

A review bot can embed a specific, file/line-cited finding inside its
review body's prose (an older collapsible-section format, e.g.
CodeRabbit's "Nitpick comments" / "Outside diff range comments") with
**no** corresponding threaded review comment of its own (observed
2026-09-03, kurone-kito/idd-skill#2197's live sweep,
kurone-kito/idd-skill#2559).
Because E1 Step 3's "Review bodies" rule only pulls a review into
`ReviewItems_snapshot` when its state is `CHANGES_REQUESTED`, and this
bot-review-state pattern reports `COMMENTED` instead, the whole review
body — not just the embedded finding — was invisible to E1, and E4-E8
never Accepted or Rejected it.

This is the same class of gap Copilot's `suppressedCount` handling
already closes (kurone-kito/idd-skill#1880,
`advisory-convergence.mts`): a finding that exists in a bot's review
but has no GitHub thread of its own. For a non-gating PATH B advisory
bot, mirror kurone-kito/idd-skill#1880's _detection pattern_ (parse
the embedded findings, compare against threaded-comment count) but
not its _gate-enforcement scope_: an uncovered finding becomes an
ordinary PATH B
`ReviewItems_snapshot` entry, not a new merge-blocking check.

One sharp regex edge worth recording: matching a severity word like
"Trivial" against a markdown-italic-wrapped segment (`_Trivial_`) with
`\bTrivial\b` never matches — regex `\b` treats `_` as a word
character, so there is no boundary between the closing `_` and the
preceding letter. Drop the trailing `\b` rather than trying to work
around it with lookarounds, when the surrounding text is already
narrowly scoped enough that the ambiguity risk is negligible.

### E4/E5 round-count defer cutoff

E4/E5 scored each PATH A item Low/Medium/High with no ceiling on how
many review-fix loop rounds (E1-E15) a PR could cycle through while new
Low-severity findings kept arriving. `critiqueLoop.e10NoProgressHoldAfter`
is a narrower guard: it only fires when the **same** Accepted finding
recurs without progress across consecutive E10 passes — its own
"meaningful progress" carve-out explicitly does not fire when each round
surfaces a genuinely new finding, since that is convergence, not
stagnation, by its own definition. A PR where successive rounds each
raise a different, real Low-severity finding (e.g., one advisory bot
converges, then a second bot's own first review arrives after the first
bot's findings are fixed, itself finding something new) triggered no
existing guard while extending indefinitely.

Observed as Copilot review-submission counts climbing into the dozens
on a handful of PRs in this repository's own dogfooding history
(kurone-kito/idd-skill#2863); each review-submission count tracks one
full E1-E15 loop iteration, since E14 requests a fresh review after
every push, regardless of reviewer state.

Only Low-severity PATH A items are eligible for the deferral
disposition — Medium and High stay fully blocking, matching
`e10NoProgressHoldAfter`'s own precedent ("unresolved High/Medium
findings remain blockers until fixed or explicitly redirected by a
maintainer"). The default threshold (`15`) is a starting point,
expected to be tuned once a repository has enough review-fix-loop
history to judge it, not a final calibration.

`Reject (defer)` reuses the existing `**Rejected**`-prefixed reply
format instead of introducing a new top-level disposition category:
`isDispositionComment` already parses "starts with `**Rejected**`," and
F2/F3 pair dispositions to advisory comments 1:1 by count — a new
category would require touching that parser and gate for no functional
gain, since a deferred item's terminal state (rejected, with a reason
and a linked follow-up) is identical in shape to an ordinary rejection.

#### Sequencing the deferred follow-up against its originating issue (kurone-kito/idd-skill#2877)

E6's follow-up-issue rule requires a `Refs #<originating-issue>` line
on the deferred-work follow-up, and `Refs` is deliberately non-blocking
everywhere else in this workflow (including `discover-roadmap-graph`'s
cycle exemption) so an ordinary citation never stalls Discover. That
general rule is wrong for this one follow-up shape specifically: the
deferred work cannot be meaningfully implemented before the PR/issue it
was deferred from actually lands, yet nothing stopped Discover from
picking up the follow-up immediately. Rather than changing `Refs`'s
general semantics, `discover-readiness-check.mts` adds a narrow,
marker-scoped rule: when a candidate's body carries the
`<!-- setup-windows-authoring-defer-source: review-fix-loop-cutoff -->`
marker, its `Refs #<N>` reference is resolved the same way an ordinary
`Blocked by #<N>` line is — excluded from Discover while `#<N>` stays
open. An unmarked issue's `Refs` lines are completely unaffected.

### review-ack worked example

A review posts a regular-comment finding plus a suppressed one.
Disposition the regular-comment finding normally (`**Rejected** —
verified placeholders-only`), then also post `review-ack:
claude-code-1a2b3c4d 4b825dc642cb6eb9a060e54bf8d69288fbee4904
2026-08-19T00:10:00Z` (plain text, no HTML comment) to cover the
suppressed one — the regular-comment rejection alone never sets
`converged`, and this is not a license to skip **AW6** or the fix flow
when the suppressed finding needs a code change.

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

### Microsoft APM as an additional distribution channel: no-go (2026-08-02)

kurone-kito/idd-skill#1727 investigated whether the source repository
should distribute the IDD template through
[Microsoft APM](https://github.com/microsoft/apm) (Agent Package
Manager), a pre-1.0 MIT-licensed package manager for agent context,
beside the existing `idd-template/ONBOARDING.md` raw-fetch-and-copy
flow. The full findings live in the source repository's
`docs/apm-distribution-strategy.md`.

The decision: **no-go** for the core template. Five payload classes
(`.github/workflows/idd-advisory-convergence.yml`, `.githooks/`,
`.github/idd/config.json`, `profiles/`, `idd-template/docs/**`) have no
APM primitive at all — APM's `hooks` primitive is a false-friend name
collision with `.githooks/`, since it covers harness-runtime
lifecycle callbacks, not git hooks. The phase-instruction corpus's real
activation key is workflow-step position, which does not map onto
APM's file-glob-scoped `applyTo` frontmatter; encoding it either way
degrades current behavior (a meaningless glob, or folding every phase
file into the always-loaded compiled context and blowing the
`instructionSizeBudgets`/`bundleBudgets` caps). APM's `apm.lock.yaml`
pins per-file content hashes, which is structurally incompatible with
the template's 26 `{{...}}` placeholder occurrences that onboarding
substitutes in place — every onboarded repository would carry
permanent, unresolvable drift from completion onward. Multi-target
compilation also breaks the corpus's own cross-references (bare-prose
mentions of `<name>.instructions.md`, the large majority of the
corpus's ~200 such references) on every non-Copilot target, since each
target compiles instructions to a different directory and, for several
targets, a different file extension. Net, adopting APM for the phase
corpus reproduces the "third synchronized surface" objection that
already decided the skill-delivery no-go above, now as a new external
CLI dependency rather than a same-repo generated file tree.

The one favorable exception: `skills/issue-authoring/` already
conforms to APM's skill-frontmatter contract, already uses the
`references/` convention, carries no placeholders, and its drift
arithmetic is net-neutral — APM's skill-bundle deployment would
plausibly **replace**, not add to, the existing
`skills/issue-authoring` → `.claude/skills/issue-authoring`
`mode: "exact"` sync pair. That exception is recorded as a named
revisit condition, not an adoption; APM's pre-1.0 release cadence (10
tagged releases in roughly 6.5 weeks as of this analysis) is an
independent, ongoing maintenance-risk factor even for that narrow case.

Conditions that would revisit this: APM reaching a stable schema; APM's
`instructions` primitive gaining a workflow-step-scoped activation mode;
explicit adopter demand with a concrete use case the raw-URL path does
not already serve; or a bounded pilot of `skills/issue-authoring/`
alone. A project that reaches this same conclusion independently should
record it here rather than re-running the investigation.

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
`.github/instructions/` files: do not edit an instruction file solely
to add a citation. That exemption is not retrofit-only — a brand-new
`.github/instructions/` passage that names an anti-pattern or failure
mode is exempt from the citation requirement too, for the same
reason: those bundle budgets already sit near their ceiling (see the
headroom review in kurone-kito/idd-skill#1525; scope clarified by
kurone-kito/idd-skill#1647 after CodeRabbit read the original wording
as covering only retrofits).

When an instruction passage's motivating incident is worth recording
in full, put the date-plus-reference in a paired
`docs/idd-design-rationale.md` entry and link to it by section anchor,
as most cited passages already do. A bare issue-number aside directly
in the instruction text remains acceptable in place of that link when
no paired entry exists — both forms fit inside the tight
instruction-bundle budget that motivates the exemption; neither is
required.

### Trace a documented output field to its print/return call site, not a type or variable name

While drafting kurone-kito/idd-skill#2474's documentation of
field-name variance across that repository's evidence-collector helper
scripts, an initial pass made several confident, specific claims about
which top-level JSON keys a given helper actually returns. A
fact-checking pass found that roughly half of those claims were wrong
— not because the underlying behavior was misunderstood, but because a
TypeScript **type name** or an internal **local variable name** had
been mistaken for an actual printed/returned field. For example,
`advisory-convergence.mts`'s printed object was described as returning
a `verdict` field: `verdict` is only the local variable name holding
the whole printed document (the `AdvisoryConvergenceVerdict` type),
never a key nested inside it. `discover-viability-gate.mts` was
described as returning a `passed` field: `passed` exists only on an
internal per-issue helper result and is never copied into the printed
top-level object. A second, independent verification pass, re-tracing
every claim to the file's actual `JSON.stringify(...)` /
`process.stdout.write(...)` call site rather than to the nearest
plausible-looking name, caught and corrected every instance before the
documentation merged (observed 2026-09-03,
kurone-kito/idd-skill#2474).

When documenting what a script or function actually returns or
prints, trace every claimed field name to its literal
`JSON.stringify(...)` / `process.stdout.write(...)` / `return` call
site in the current source — never infer it from a type name, an
interface field, or a local variable name that merely looks like it
could be the same thing.
