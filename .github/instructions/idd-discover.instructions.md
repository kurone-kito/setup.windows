# IDD — Discover Phase (A0-T–A4)

Read this file when starting a new task: finding and selecting the next
issue to work on, including an operator-provided exact issue target,
roadmap-audit handoff, candidate selection, and handoff to A4.5 and
claim. After A4 selects a viable candidate, run suitability triage via
`idd-suitability.instructions.md` (A4.5), then proceed to
`idd-claim.instructions.md` to claim it.

When helper support is enabled, use helper scripts from
`docs/idd-helper-scripts.md` first for A0-O/A3/A3.5/A4/A4.5 evidence.
Written decision tables remain authoritative when helper output is
missing or disagrees.

**Abort conditions**: A0-T, A1 (`orphan-first`/`roadmap` scope only —
see A0), A3 (default; see decision tree).
**Early stop condition**: A0-T, A4, or A4.5 (no claim made — see below).

## Authoring label guard

Use `issueAuthoring.authoringLabelName` (default: `status:authoring`) and
`issueAuthoring.authoringStaleAge` (default: `PT4H`). The label marks held
drafts and suppresses claims, so skip labeled issues. Unlabeled issues follow
`anchor` logs; incomplete generations block. Only exact
anchor/set/session `release-complete` gates release/guard; an absent label is
not proof; release clears it.

The
[portable owner resolver](../../docs/idd-autonomy-contract.md#portable-authoring-owner-protocol)
defines these owner-protocol terms for every helper profile. For
`instructions-only`, never infer membership from the label.

A0-T, A0-O, and A3 must treat a matching label as not startable. A0-T
reports `Issue #N is currently being authored` and stops before claim;
A0-O and A3 filter the issue out. For each skipped issue, fetch the
latest matching `labeled` timeline event. If the label age exceeds
`authoringStaleAge`, emit:

```text
Warning: Issue #N has carried the authoring label for {duration}; the authoring session may be stalled.
```

If the timestamp is unavailable, still skip the issue and report that the
stale-authoring age could not be checked.

## A0-T — Explicit issue target shortcut

Use this shortcut only when the current operator request contains one
unambiguous issue target in the current repository: either a single issue
number such as `#123` or a single issue URL whose owner and repository
match the current repository.

Do not use this shortcut for ambiguous inputs, multiple issue numbers,
cross-repository issue URLs, closed issues, inaccessible issues, pull
requests, discussions, commits, or any other non-issue target. Report the
reason and stop without claiming. Fall back to normal discovery only when
the operator explicitly asks for normal discovery in the same run; do not
silently search for another issue.

Run the steps below against a valid open target. Steps 1 and 2 apply
regardless of target type; only once step 2 confirms the target is not
a roadmap node does this shortcut skip A0-O, A1, A1.5, A2, and
candidate selection, continuing through steps 3-5 to A5 against that
issue only — a roadmap-node target instead follows step 2's own
routing:

1. Fetch the target issue. If it carries the configured authoring label,
   report `Issue #N is currently being authored`, run the
   stale-authoring warning check above, and stop without claiming — this
   check runs first and applies whether the target turns out to be an
   execution leaf or a roadmap node in step 2 below, so an
   authoring-held roadmap is never routed into step 2's traversal.
2. If the target issue carries the configured roadmap label or an
   `setup-windows-roadmap-id` marker — the same test
   **A2**'s roadmap-node/execution-leaf classification rule uses (an
   unmarked legacy umbrella isn't recognized here — retro-label it
   first, per A1's Legacy roots) — do not continue to steps 3-5.
   Instead:
   - Apply **A3**'s dependency bullet to the target itself (both
     visible `Blocked by #NNN` lines and hidden
     `setup-windows-blocked-by` markers) and its
     coordination/runtime-observation-precondition bullet; a
     dependency hit reports blocked, a coordination hit reports that
     criterion instead — either way this run stops (no fallback).
     Skip A3's other bullets here:
     **A1.5** already checks the roadmap's own blocked-by-human/
     needs-decision labels and claim state, and "no open dependent
     issues" does not apply to a root whose own children are its
     dependents.
   - Treat the target as the root **A1** would have selected: run
     **A1.5** against it. A1.5's own outcome governs what happens
     next: a close or non-autonomous-gap outcome ends this run here —
     report and stop, never falling back to A1 the way the normal
     roadmap path would; only a continue outcome proceeds.
   - Run **A2**'s traversal scoped to this root and its own
     descendants only (never a repository-wide search), then the
     normal **A3** → **A3.5** → **A4** sequence over that scoped set:
     A3.5 filters and continues with the remaining startable
     candidates exactly as in the normal roadmap path — no
     stop-without-fallback applies at this filtering step. This
     graph-scoped continuation excludes **A0**'s own A0-O
     orphan-fallback triggers (a)/(b)/(c) throughout: an empty or
     fully-discarded scoped set ends the run the same way A0-T's other
     failure branches do — report and stop.
   - Rank the survivors down to a single highest-suitability open
     child and run **A4.5** → **A5** against that one child only.
     `idd-suitability.instructions.md`'s and
     `idd-claim.instructions.md`'s existing A0-T-keyed
     stop-without-fallback rules apply to it unchanged: an A4.5
     rejection, a failed A5 Pre-check (a) approval re-verification, or
     a lost A5 claim race ends this run — report and stop — rather
     than falling back to the next-ranked survivor. Extending this
     branch to retry a subsequent survivor on such a failure is out of
     scope here.
3. Apply A3's readiness bullets to the target (the same blocked-by,
   human-coordination, and runtime-observation checks, resolved the
   same way) — plus one target-only check: no active, non-stale claim
   from a trusted marker actor exists on the target, other than a
   claim this session already recorded and verified (A4 Step 1.5
   rules); a hit reports "already claimed", same as A5.
4. Run the normal A4 viability gate against the target only.
5. Apply the **A3.5** issue-author approval gate against the target.
   If A3.5 classifies it as not startable, report that the gate
   blocked claim and stop before A5 (no fallback, per the rule above).

If any targeted readiness or viability check fails, report the exact
failed criterion and stop without claiming (no fallback, per the rule
above).

If all checks pass, the target is selected. Continue to
[`idd-suitability.instructions.md`](idd-suitability.instructions.md)
for suitability triage. A4.5 follows the same standards as roadmap
paths. If A4.5 passes, proceed to `idd-claim.instructions.md` A5.
A5 claim-state, open-PR, takeover, branch-collision, and
claim-verification rules remain unchanged.

## A0 — Check issue-scope setting

Read the **issue-scope** value from the Project commands table in
`idd-overview-core.instructions.md`.

- If `issue-scope` is `roadmap`: skip A0-O and proceed to A1 as normal.
- If `issue-scope` is `roadmap-first` (the default): proceed to A1 as
  normal, falling back to **A0-O** before the A3 decision tree when the
  roadmap path yields **no viable, startable, unclaimed candidate** —
  **trigger (a)** (zero candidates reach A3.5: A2 found none, or A3
  filtered them all), **trigger (b)** (candidates reach A3.5 but A4
  Step 1, Step 1.5, or Step 2's floor skip discards every one), or
  **trigger (c)** (A1 finds no roadmap issues). A0-O runs **at most
  once** per Discover pass as this fallback; once spent, a later A4
  exhaustion reports and stops
  (not an abort) without re-entering A0-O. A non-empty A3.5
  approval-needed bucket is not a true zero and never triggers this
  fallback. See
  [A0-O fallback triggers](../../docs/idd-design-rationale.md#a0-o-roadmap-first-fallback-triggers).
- If `issue-scope` is `orphan-first`: proceed to A0-O.

## A0-O — Discover orphan issues

Read the **orphan-first-policy** value from the Project commands table
in `idd-overview-core.instructions.md` before any repo-wide orphan issue
search.

When A0-O runs as the `roadmap-first` fallback, every exit below that
would re-enter **A1** or reach the **A3 decision tree** is redirected by
the invoking trigger instead — (a)/(c) to the A3 decision tree, (b) (A4
exhaustion) to the A4 **"report and stop"** terminal — since A1 already
ran and must not be re-entered (no A1 ↔ A0-O or A4 ↔ A0-O loop).

- If `orphan-first-policy` is `public-disabled`: for a public repository
  (or when visibility cannot be determined), skip A0-O without searching
  open issues, using the same trigger-based redirect above. For private
  or internal repositories, continue with A0-O.
- For `none` and `maintainer-approved`, continue with A0-O.

Search all open issues in the repository. Collect every issue that does
NOT contain an `setup-windows-roadmap-id` marker (not itself
a roadmap) or an `setup-windows-blocked-by` marker, AND
otherwise passes A3's own readiness bullets (the same five criteria A3
lists; do not re-derive them here).

Apply the configured policy before passing A0-O candidates to A3.5:

- `none` (the default): apply no extra orphan-first approval gate.
- `maintainer-approved`: apply A3.5's **Approval signals** check (using
  its Maintainer approval actor definition) to each candidate, keeping
  only those that satisfy at least one signal. A3.5's
  `skipIssueAuthorApprovalGate` shortcut does **not** bypass this
  filter — orphan-first `maintainer-approved` is independent of the
  repository-wide gate enable.
- `public-disabled`: for private or internal repositories, behave the
  same as `none`.

**Autopilot floor.** In autopilot runs, pass `--autopilot` to
`discover-orphan-filter`; skip `routed_to_human` candidates (never
reach A3.5). No helper: apply A4 Step 2's floor rule verbatim,
including `enabled: false`, to each footer.

At least one orphan issue remains after the policy is applied: pass the
remaining set directly to **A3.5**, skipping A1–A3.

No orphan issues remain: the next step depends on which path invoked
A0-O:

- **`orphan-first` primary path**: fall back to the roadmap path. Proceed
  to **A1** and continue with the normal
  A1 → A1.5 → A2 → A3 → A3.5 → A4 sequence.
- **`roadmap-first` fallback**: the roadmap path already ran, so do **not**
  re-enter A1. This exit is redirected by the invoking trigger per the
  guard atop A0-O.

The A3 decision tree (abort / ask operator in unattended mode) is
reached only when every active discovery path returns zero: both paths
for `orphan-first` and `roadmap-first` (orphan + roadmap fallback,
either order); just the roadmap path for `roadmap`.

**Claim-state annotation (optional).** `discover-orphan-filter`
accepts `--with-claim-state` (plus `--current-claim-id`), mirroring
`discover-roadmap-graph`'s flag of the same name — see
`docs/idd-helper-scripts.md`.

## A1 — Find the roadmap

Use GH CLI or GH MCP to find the roadmap among open issues, identified
by the configured roadmap label (project field) from
`labels.roadmapLabelName` (default: `roadmap`) or by recognizing it as
an umbrella issue. Under `roadmap` or `orphan-first` scope, report and
abort if no roadmap issue exists. Under `roadmap-first` scope, this is
**trigger (c)**: fall back to **A0-O** instead.

**Autopilot cross-roadmap mode (optional, additive).** When several
roadmaps run in parallel and the active autopilot-suitable work may live
under **sibling** epics, do not commit to a single umbrella here. Instead,
enumerate the open execution leaves across **all** open roadmap roots and
rank them by autopilot-suitability (see A2), then carry the top-ranked
candidate through the normal A3/A4/A4.5/A5 gates. This is additive: the
single-root selection above stays the default; orphan-first filtering
still applies only to true orphans, since cross-roadmap leaves are
reached via a parent roadmap's task list and never carry their own
`setup-windows-roadmap-id` marker.

**Legacy roots**: `--all-roadmaps` finds roots only by label or
`setup-windows-roadmap-id` marker. Retro-label a legacy
umbrella, or configure **`discover.legacyRoots`** (issue numbers,
deduped against label/marker roots; invalid fails safe to none). See
`docs/idd-helper-scripts.md`.

## A1.5 — Audit completed roadmaps

After A1 selects an open roadmap, read
`idd-roadmap-audit.instructions.md` before continuing to A2. That file
owns the full A1.5 completion audit, roadmap-side claim rules, and the
close/link/stop outcomes that can occur before child-issue enumeration
resumes here.

## A2 — Enumerate sub-issues

Starting from the roadmap found in A1 and not closed by A1.5,
recursively collect all issues it references. Include transitively
referenced issues. Collect only **open** issues.

**Allowed traversal sources** (outbound references only):

- Task-list entries in the roadmap or any recursively discovered issue
- Issue cross-references indicating a work dependency or task
  relationship (e.g., `Closes #NNN`, `Refs #NNN`, explicit sub-issue
  lines)
- GitHub sub-issue relationships (parent → child)

**Excluded from traversal**:

- Inbound backlinks (issues referencing the roadmap without being
  referenced by it)
- Incidental narrative mentions (e.g., "Similar to #NNN") lacking an
  explicit task, sub-issue, or dependency relationship

Traverse referenced issues regardless of open/closed state. Issues
carrying the configured roadmap label or an
`<!-- setup-windows-roadmap-id: ... -->` marker are
**roadmap nodes**; any other issue is an **execution leaf**. Include
only open execution leaves in the candidate set; never advance roadmap
nodes to A3/A4/A4.5/A5, but traverse closed nodes too (so descendants
aren't hidden). The A1 root roadmap starts the traversal and is
excluded from the open roadmap-node set.

**Permitted repo-wide queries** — only the following scoped lookups may
touch issues outside the roadmap traversal graph:

- **A0-T only**: the scoped body-content lookup needed to resolve
  `setup-windows-blocked-by` markers on the explicit target.
  The result is used solely to determine targeted readiness and is not
  added to any candidate set.
- **A0-O only** (when `issue-scope` is `orphan-first`, or when
  `issue-scope` is `roadmap-first` and A0-O runs as the roadmap-path
  fallback): a repo-wide open-issue query to find issues without
  `setup-windows-roadmap-id` or
  `setup-windows-blocked-by` markers.
- **A1 only**: any method (including `gh issue list`, `gh search`, or
  label-based queries) to locate the roadmap issue itself.
- **A1.5 only**: a narrow duplicate/reuse lookup for one specific
  autonomous gap before creating a follow-up issue. The result may only
  be linked to the selected roadmap or used to avoid creating a
  duplicate; it must not be added to the A2 candidate set.
- **A3 only**: a body-content search (e.g.,
  `gh search issues --match-body`) to find the issue with a matching
  `setup-windows-roadmap-id` marker when checking
  `setup-windows-blocked-by` dependency markers (see A3
  below). The result is used solely to determine blocked status and is
  not added to the A2 candidate set.
- **A4.5 only**: a narrow duplicate/reuse search for the candidate
  selected in A4 Step 2 (title match, body-content, or fuzzy match to
  detect known open or closed issues that supersede or duplicate it).
  The result is used solely to determine duplicate status for the
  selected candidate and is not added to any candidate set.

**Prohibited in all other contexts** — the following must not be used in
any phase except as listed above, or when A3 step 5 explicit opt-in
authorizes an alternate scope for the current run:

- `gh issue list` or any variant
- `gh search` or any variant
- Any repo-wide or label-based query

**Handling unresolvable references**:

- Infrastructure or tool failure (API error, auth failure, rate limit,
  or the roadmap body cannot be fetched): **A2 enumeration failure** —
  abort immediately and report. No fallback.
- A specific outbound reference not found or inaccessible: record it as
  unresolvable with the reason, skip that branch, and continue
  traversal. Not an enumeration failure.

**Termination.** Do not re-expand a target already on the current
traversal path; record the back-edge as a cycle with its path and
continue with the next reference.

**Single visit.** A node is identified by issue number; a node
reached again through another path is the same node — collect it
once, never enter it into the candidate set twice.

**Provenance.** Keep and report every distinct path that reaches a
node, not only the first — the same rule the cross-roadmap union
below already applies to a leaf reachable from several roadmap
roots.

**Helper read timing.** The `discover-roadmap-graph` helper (see
[IDD helper script evaluation](../../docs/idd-helper-scripts.md)) is
long-running on large graphs, emitting the whole graph in one final
stdout write. Redirect stdout to a file and wait for process exit before
parsing — a zero-byte or mid-run read is **"still running," not** an A2
enumeration failure.

Report every A2 execution candidate with its provenance paths (e.g.
`#222 → #228 → #257`), any open roadmap nodes, cycles, duplicate
references, and unresolvable references before passing to A3.

**Autopilot cross-roadmap union (optional, additive).** When A1 elected
the cross-roadmap mode, enumerate from **each** open roadmap root and
take the **union** of open execution leaves, de-duplicating a leaf
reached from several roots (record every source root as provenance;
never double-count). Rank by autopilot-suitability **descending**,
tie-broken by issue number **ascending**, using the same
scored-vs-unscored floor tie-breaker as A4 Step 2. The
`discover-roadmap-graph` helper's `--all-roadmaps` mode produces exactly
this ranked union (see
[IDD helper script evaluation](../../docs/idd-helper-scripts.md)). The
score is an advisory ranking hint only — A3/A4/A4.5/A5 still run on the
selected candidate.

## A3 — Filter to ready-to-start

Under concurrency, check a candidate's **active-claim eligibility** (the
non-stale claim filter below) **first**, before investing in its
viability or scope analysis: a parallel agent may already hold the
issue, and scope work that displaces the claim check produces redundant
PRs. The claim check is cheap — run it first per candidate.

From A2, keep only issues that satisfy **all** of the following:

- No configured blocked-by-human or needs-decision label
- No configured authoring label
- No open dependent issues (parent epics / aggregate issues that are
  still open are acceptable)
- All dependency issues are closed or otherwise completed. Two forms:
  (a) visible `Blocked by #NNN` lines — an open or unresolvable
  reference is treated as blocked (fail-safe); (b) hidden
  `<!-- setup-windows-blocked-by: {roadmap-id} -->` markers —
  find the issue whose body contains a matching
  `<!-- setup-windows-roadmap-id: {roadmap-id} -->`; treat as
  blocked if that issue is open, if no issue matches (fail-safe — a
  migration integrity problem such as a typo, deleted issue, or
  incomplete migration), or if any matching issue is open.
- No external human coordination or prose-only
  runtime/production-observation precondition ("confirmed in
  production", "observed live", "runtime-observation"; issue #2467)
  required to start; otherwise keep scanning

**When A2 finds zero candidates, or zero issues survive A3 filtering**,
apply this decision tree — do not silently expand scope:

1. **A2 enumeration failure** (infrastructure or tool issue — see A2):
   abort immediately and report. No fallback. (Unresolvable individual
   references are already pruned in A2 and do not trigger this step.)

2. **A2 empty — only open roadmap nodes remain**: report each node and
   its provenance path (A1.5 audit needed); do not treat them as
   candidates. Proceed to step 5.

3. **A2 empty — no candidates** (no roadmap nodes either): report zero
   open candidates and any skipped references, then proceed to step 5.

4. **A3 filtered to zero** (A2 found execution candidates but all were
   filtered out): report each candidate and the filter criterion it
   failed, then proceed to step 5.

   See [Discover — A3 Diagnostic](../../docs/idd-design-rationale.md#a3--diagnostic-all-candidates-blocked-by-an-open-roadmap)
   for the marker-misuse pattern this case typically indicates.

5. **Request explicit opt-in** — ask the operator: "No roadmap-scoped
   issues are available. Do you want to expand the search scope for this
   run? If so, specify the alternate scope." An agent is **unattended**
   if it cannot wait for and receive a same-run operator reply.

   - **Unattended mode, or the operator declines/does not respond**:
     abort and report.
   - **Operator grants opt-in**: use the operator-specified scope for
     this run only — prior or standing instructions never count as
     opt-in.

## A3.5 — Apply issue-author approval gate

A0-T (explicit target) and A0-O (`maintainer-approved`) cite this
section instead of restating the algorithm.

**Gate enable / disable**: If `.github/idd/config.json` is valid and
`skipIssueAuthorApprovalGate` is `true`, the gate is disabled — keep
every ready candidate startable. Otherwise the gate is enabled; use
`maintainerApprovalActorPolicy` from `.github/idd/config.json` when
present, defaulting to `owners-and-maintainers-only`.

**Maintainer approval actor**: a human repository actor allowed by the
current `maintainerApprovalActorPolicy` — `owners-and-maintainers-only`
(default) admits owners plus Maintain/Admin collaborators;
`all-write-permission-actors` adds Write collaborators. Never reuse the
trusted marker actor set or count automation/the current agent unless
policy explicitly grants that authority. Verify permission with the
collaborator permission API.

A bare organization `MEMBER` association, by itself, is not approval;
neither is issue body text, a generated plan, nor operator attention.

**Self-authorization fallback when the permission read is unavailable
(#2148).** The bare-`MEMBER` rule above governs an approval-comment
actor or the `idd:ready` label actor, both of which require a
successful permission read. For the issue-author self-authorization
signal specifically, when the collaborator permission API is
unavailable (503, empty, or otherwise unreadable), the issue's own
live `author_association` substitutes instead of failing closed:
`OWNER` always self-authorizes; `MEMBER` self-authorizes under both
`owners-and-maintainers-only` and `all-write-permission-actors`. This
matches `claim-approval-gate.mjs`'s shipped behavior and does not
widen either other signal.

**Approval signals** (any one satisfies, when the gate is enabled):

- the issue author is self-authorized under the current
  maintainer-approval actor policy;
- the configured ready label from `approvalSignals.readyLabelName`
  (default: `idd:ready`), present when policy reserves it to
  maintainer approval actors. Under `event-freshness`
  (`approvalSignals.labelFreshnessMode`), its latest `labeled` event
  must postdate the latest issue title/body edit and any generated-plan
  update; `presence-only` (default) accepts label presence alone;
- a visible approval comment from a maintainer approval actor whose
  trimmed body equals `IDD ready` or contains `IDD ready` as a
  standalone line, newer than the latest issue title/body edit and
  any generated-plan update (or an equivalent draft-stability signal).

If freshness cannot be determined for a label or comment signal,
require a fresh approval comment or a re-applied ready label.

**Fail-closed**: when approval state or permission resolution is
unavailable or ambiguous, fail closed unless the repository explicitly
opted out via `skipIssueAuthorApprovalGate`.

**Candidate routing**: candidates that fail the gate are not
ready-to-start — keep them visible in an **approval-needed fallback
bucket** ordered by ascending issue number, and continue to A4 with
only the startable candidates. This gate never widens previously
excluded A0-O `orphan-first-policy` candidates back into scope.

If no startable candidates remain but the approval-needed fallback
bucket is non-empty:

- **Unattended mode**: report that only approval-needed fallback issues
  remain and stop without claiming. Do not auto-claim from the fallback
  bucket.
- **Attended mode**: ask the operator whether to obtain approval or to
  opt out explicitly in `.github/idd/config.json`. Do not treat operator
  attention alone as approval.

## A4 — Gate, then pick

### Step 1 — Viability gate

For each **startable** candidate from A3.5, evaluate **all three**
criteria. Fail any one → discard the issue.

- **Limited scope** — Pass: changes confined to a few files or one
  module. Fail: touches multiple subsystems; redesigns a public
  interface.
- **Clear verification** — Pass: outcome verified by lint / test / CI —
  including adding or updating targeted automated tests as part of the
  work. Fail: success depends on UX or product judgment.
- **Autonomous completion** — Pass: no external coordination, human
  decision, unavailable system, or product judgment required to
  **complete** the work. Fail: requires operator to provide
  credentials; requires a product decision before the work can finish.

**Structural-evidence demotion (#2767)**: Limited scope / Autonomous
completion (never Clear verification) may demote to `warn` per
`idd-suitability.instructions.md`'s matching edge case.

If **no issue** survives the gate:

- if the approval-needed fallback bucket from A3.5 is non-empty, apply
  A3.5's own approval-needed routing (above) instead of falling back;
- otherwise, apply the **exhaustion-exit routing** defined here: under
  **`roadmap-first`** scope in the roadmap-traversal flow (A2→A3→A4; not
  the A0-T gate, which stops a failed target with no fallback), route to
  the **A0-O** roadmap-first fallback (A0 trigger (b)) if it has not run
  this pass. Once spent, or under `issue-scope: roadmap` (A0-O skipped),
  report the discarded issues with the criterion each failed, then
  **stop** — not an abort. Do not post `unclaimed-by` because no claim
  was made.

### Step 1.5 — Active-claim pre-scan

Before selecting from the surviving viable issues, eliminate candidates
carrying a concurrent active non-stale claim, in ascending issue-number
order:

- Scan the **top N** survivors (ordered by ascending issue number),
  where `N` is `.github/idd/config.json`
  `discover.activeClaimPreScanBatchSize` (distributed default: `10`).
- For each candidate, fetch the issue and parse comments per the
  shared claim-state rules in `idd-claim.instructions.md`, including
  forced-handoff and legacy markers, not just
  `claimed-by`/`unclaimed-by`. No current bulk helper's
  `--with-claim-state` flag is forced-handoff-aware, so loop the
  single-issue `resume-claim-routing.mjs --fresh-claim-gate` resolver
  per candidate, or apply the full parsing rules manually. A candidate
  is **ineligible** when parsing yields an active claim whose latest
  valid `claimed-by` comment has GitHub `created_at` within
  `claim-stale-age` of now (equivalently, `created_at > now -
  claim-stale-age`; `docs/policy-constants.md`; distributed default:
  `24 h`); otherwise it **remains eligible**.

After scanning the current batch:

- **At least one eligible candidate in the batch**: proceed to Step 2
  to rank and select.
- **All `N` in this batch are claimed but viable survivors remain**:
  continue with the next batch (`N+1`–`2N`, then `2N+1`–`3N`, …) until
  an eligible candidate is found.
- **Entire viable candidate set exhausted** (all surviving viable
  candidates are claimed): resolve the exit by scope (see the note
  below).

When the entire viable candidate set is exhausted (the last bullet
above): if the A3.5 approval-needed bucket is non-empty, apply A3.5's
own approval-needed routing, also reporting the claimed-survivor
exhaustion (the approval hold takes precedence — not a true zero);
otherwise apply Step 1's **exhaustion-exit routing** above, reporting
that all viable issues are currently claimed in place of a discard
criterion. Retry later.

See [Discover — A4 Step 1.5 Rationale](../../docs/idd-design-rationale.md#a4-step-15--rationale-active-claim-pre-scan)
for why this pre-scan exists.

### Step 2 — Select

Among the surviving viable and unclaimed issues (after Step 1.5), pick
the **highest authored autopilot-suitability score** (the
`<!-- setup-windows-autopilot-suitability: N -->` footer, or the
`discover-roadmap-graph` node's `autopilotSuitability`), tie-broken by
**lowest issue number**. In autopilot runs, skip scores below
`autopilotSuitability.floor` (default `3`) as human-oriented; a missing
or out-of-range score defaults to the floor and is never skipped
(subject to the scored-vs-unscored tie-breaker below). Advisory only —
the pick still passes A4.5/A5 unchanged and never bypasses a gate. When
`autopilotSuitability.enabled` is `false`, ignore the score entirely and
select by **lowest issue number**.

**Scored-vs-unscored floor tie-breaker.** When the highest-score tie
band pairs an unscored candidate (missing or out-of-range score,
defaulted to the floor as defined above) against a candidate genuinely
scored exactly at the floor value, the genuinely-scored candidate wins
the tie: an explicit author judgment outranks a default fallback. See
[rationale](../../docs/idd-design-rationale.md#a4--scored-vs-unscored-floor-tie-breaker-what-still-ties-afterward)
for how the remaining tie-breakers below apply after this rule.

**Concurrent-selection desync (opt-in, off by default).** When
`discover.selectionDesync` is `session-offset` (default `off`) and the
highest-score tie band has more than one eligible candidate, pick the
band entry at index `selectDesyncedIndex(session-token, band-size)`
instead of index 0 — FNV-1a 32-bit over the token's UTF-16 code units
(offset basis `0x811c9dc5`, prime `0x01000193`, wrap to 32 bits after
every multiply, then unsigned right-shift and modulo `band-size`) over
the band ordered by ascending issue number.

`session-token` **must be per-session-unique**: the bare, session-shared
`{agent-id}` from `idd-overview-core.instructions.md` alone is **not** a
compliant token. Use the session-suffixed `{agent-id}` (e.g.,
`copilot-8122ca35`) when this session already appends one; otherwise
generate a session-local token once at Discover entry — it must carry
enough entropy to stay distinct across sessions launched at the same
moment (a random or UUID-derived value; a bare timestamp alone is not
sufficient, since same-second concurrent launches would still collide)
— and reuse that same value for every A4 Step 2 selection this session
makes, including re-entry after a collision. See
[rationale](../../docs/idd-design-rationale.md#a4-step-2--rationale-concurrent-selection-desync)
for why a bare shared token defeats this mechanism. Compute the index
with the CLI instead of hand-tracing `scripts/policy-helpers.mjs`:

```sh
# source repo / vendored-node
node scripts/select-desynced-index.mjs --token <session-token> --band-size <band-size>

# package-manager / ephemeral-npx
<profile-selected-select-desynced-index-command> --token <session-token> --band-size <band-size>
```

Resolve `<profile-selected-select-desynced-index-command>` from
`docs/idd-helper-scripts.md` (do not hardcode `node scripts/...` for
non-vendored profiles); the formula above is the canonical fallback
when the helper is unavailable. It reorders **only within** a single
score tie band, never across bands, and never bypasses A4.5/A5. With
`off`, a single-entry band, or no applicable score, keep the
deterministic **lowest issue number** pick. See
[rationale](../../docs/idd-design-rationale.md#a4-step-2--rationale-concurrent-selection-desync).

**Configured milestone-scope preference.** `discover.milestoneScope`
(`#2340`) prefers a same-score-band candidate whose OPEN milestone
matches, after desync and before effort — see
[rationale](../../docs/idd-design-rationale.md#a4-step-2--rationale-milestone-scope-preference).

**Author-recorded effort hint (soft tie-breaker).** When candidates
remain tied after the score and optional desync rules, prefer the
**lower-effort** candidate before the lowest-issue-number tie-break.
Read the authored `<!-- setup-windows-effort: S|M|L -->` footer
(or the `discover-roadmap-graph` node's `effort`): `S` < `M` < `L`, with
a missing or invalid hint as the **neutral middle** (`M`). **Soft**
rule: reorders only within a single score tie band, never skips,
gates, or crosses a band; the `discover-roadmap-graph` union already
emits this order.

**High-contention shared-file overlap (advisory).** Concurrent sessions
tend to edit the same F-phase bundle files and `audit/sync-manifest.json`.
**Soft** tie-breaker after
score/desync/milestone/effort: prefer a candidate whose `## Candidate
files` do **not** overlap an actively-claimed or open-PR issue on one of
those; `discover-shared-file-overlap` (see
[IDD helper scripts](../../docs/idd-helper-scripts.md)) reports
`overlapFlag`/`recommendedOrder`, or `manifestMissing: true` with an
empty set. See the
[convention](../../docs/policy-constants.md#high-contention-shared-files)
for the current bundle ids.

After picking, proceed to **A4.5** (`idd-suitability.instructions.md`).

## A4.5 — Pre-Claim Issue-Suitability Triage

Read [`idd-suitability.instructions.md`](idd-suitability.instructions.md)
for the full suitability triage protocol: seven checks, failure outcomes,
mutation policy, coordination rules, decision flow, and edge cases.

## Roadmap markers

Two hidden HTML comment markers are used in issue bodies to support the
discover phase:

- **Roadmap identity** (`setup-windows-roadmap-id`): in the
  roadmap issue body; A3 uses it for `blocked-by` lookups. A1 finds the
  roadmap by its label or umbrella structure, not this marker.
- **Sequential dependency** (`setup-windows-blocked-by`): in an
  issue body — this issue **cannot start until** the roadmap with the
  matching `roadmap-id` is closed.

**Do not use `setup-windows-blocked-by` to group sub-tasks under
an active roadmap** — those belong in the roadmap's task list as
`- [ ] #NNN` entries. `blocked-by` is only for a separate, prior
roadmap that must close first; see the
[A3 diagnostic](../../docs/idd-design-rationale.md#a3--diagnostic-all-candidates-blocked-by-an-open-roadmap)
for the deadlock this prevents.

## Scope invariant (summary)

Do not widen issue-selection scope beyond A2's query allowlist (A0-T,
A0-O, A1, A1.5, A3, A4.5) or a same-run operator opt-in per A3 step 5
(never inferred from standing instructions). An explicit target
authorizes only that issue, except when A0-T step 2 classifies it as a
roadmap node: then it authorizes normal selection scoped to that
roadmap's own descendants only, never an unrelated orphan issue (A0-O
stays excluded, per A0-T step 2).
