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

The configured authoring label is `issueAuthoring.authoringLabelName`
(default: `status:authoring`); the stale threshold is
`issueAuthoring.authoringStaleAge` (default: `PT4H`).

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

For a valid open target, skip A0-O, A1, A1.5, A2, and candidate
selection. Before A5, run targeted readiness and viability checks against
that issue only:

1. Re-fetch the target issue.
2. If the target issue carries the configured authoring label, report
   `Issue #N is currently being authored`, run the stale-authoring
   warning check above, and stop without claiming.
3. Apply A3's readiness bullets to the target — no configured
   blocked-by-human/needs-decision label, no open blocking dependent
   issue (visible `Blocked by #NNN` or hidden
   `{{PROJECT_MARKER_PREFIX}}-blocked-by` marker, both resolved the
   same way A3 resolves them), no external human coordination required
   — plus one target-only check: no active, non-stale claim from a
   trusted marker actor exists on the target, other than a claim this
   session already recorded and verified (A4 Step 1.5 rules); a hit
   reports "already claimed", same as A5.
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
  Step 1 or Step 1.5 discards every one), or **trigger (c)** (A1 finds
  no roadmap issues). A0-O runs **at most once** per Discover pass as
  this fallback; once spent, a later A4 exhaustion reports and stops
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
NOT contain a `{{PROJECT_MARKER_PREFIX}}-roadmap-id` marker (not itself
a roadmap) or a `{{PROJECT_MARKER_PREFIX}}-blocked-by` marker, AND
otherwise passes A3's own readiness bullets (no configured
blocked-by-human/needs-decision label, no configured authoring label,
no open blocking dependent issue via either visible `Blocked by #NNN`
or hidden marker form, same fail-safe treatment on an unresolvable
reference).

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

**Claim-state annotation (optional).** When helper support is enabled,
`discover-orphan-filter` accepts an opt-in `--with-claim-state` flag
(plus `--current-claim-id`) that annotates each candidate with
active-claim eligibility, mirroring `discover-roadmap-graph`'s flag of
the same name — see `docs/idd-helper-scripts.md`. This lets an A0-O
caller fold live claim state into its output the same way the roadmap
path already can.

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
`{{PROJECT_MARKER_PREFIX}}-roadmap-id` marker.

**Legacy roots**: `--all-roadmaps` finds roots only by label or
`{{PROJECT_MARKER_PREFIX}}-roadmap-id` marker. Retro-label a legacy
umbrella, or configure **`discover.legacyRoots`** (issue numbers,
deduped against label/marker roots; invalid fails safe to none). See
`docs/idd-helper-scripts.md`.

**Note**: Repo-wide or label-based issue queries are permitted only in
the scoped contexts A2 enumerates below (**A0-T**, **A0-O**, **A1**,
**A1.5**, **A3**, **A4.5**); outside those, they are prohibited.

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
`<!-- {{PROJECT_MARKER_PREFIX}}-roadmap-id: ... -->` marker are
**roadmap nodes**; any other issue is an **execution leaf**. Include
only open execution leaves in the candidate set; never advance roadmap
nodes to A3/A4/A4.5/A5, but traverse closed nodes too (so descendants
aren't hidden). The A1 root roadmap starts the traversal and is
excluded from the open roadmap-node set.

**Permitted repo-wide queries** — only the following scoped lookups may
touch issues outside the roadmap traversal graph:

- **A0-T only**: the scoped body-content lookup needed to resolve
  `{{PROJECT_MARKER_PREFIX}}-blocked-by` markers on the explicit target.
  The result is used solely to determine targeted readiness and is not
  added to any candidate set.
- **A0-O only** (when `issue-scope` is `orphan-first`, or when
  `issue-scope` is `roadmap-first` and A0-O runs as the roadmap-path
  fallback): a repo-wide open-issue query to find issues without
  `{{PROJECT_MARKER_PREFIX}}-roadmap-id` or
  `{{PROJECT_MARKER_PREFIX}}-blocked-by` markers.
- **A1 only**: any method (including `gh issue list`, `gh search`, or
  label-based queries) to locate the roadmap issue itself.
- **A1.5 only**: a narrow duplicate/reuse lookup for one specific
  autonomous gap before creating a follow-up issue. The result may only
  be linked to the selected roadmap or used to avoid creating a
  duplicate; it must not be added to the A2 candidate set.
- **A3 only**: a body-content search (e.g.,
  `gh search issues --match-body`) to find the issue with a matching
  `{{PROJECT_MARKER_PREFIX}}-roadmap-id` marker when checking
  `{{PROJECT_MARKER_PREFIX}}-blocked-by` dependency markers (see A3
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

**Helper read timing.** The `discover-roadmap-graph` helper (see
[IDD helper script evaluation](../../docs/idd-helper-scripts.md)) is
long-running on large graphs, emitting the whole graph in one final
stdout write. Redirect stdout to a file and wait for process exit before
parsing — a zero-byte or mid-run read is **"still running," not** an A2
enumeration failure.

Report every A2 execution candidate with its provenance path (e.g.
`#222 → #228 → #257`), any open roadmap nodes, and unresolvable
references before passing to A3.

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
  `<!-- {{PROJECT_MARKER_PREFIX}}-blocked-by: {roadmap-id} -->` markers —
  find the issue whose body contains a matching
  `<!-- {{PROJECT_MARKER_PREFIX}}-roadmap-id: {roadmap-id} -->`; treat as
  blocked if that issue is open, if no issue matches (fail-safe — a
  migration integrity problem such as a typo, deleted issue, or
  incomplete migration), or if any matching issue is open.
- No external human coordination required to start; otherwise keep
  scanning

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

   See [Discover — A3 Diagnostic](../../docs/idd-design-rationale.md#a3---diagnostic-all-candidates-blocked-by-an-open-roadmap)
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
`<!-- {{PROJECT_MARKER_PREFIX}}-autopilot-suitability: N -->` footer, or the
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
instead of index 0 — a pure `hash(session-token) mod band-size` over
the band ordered by ascending issue number, `session-token` being this
session's `{agent-id}`. Compute it with the CLI instead of hand-tracing
`scripts/policy-helpers.mjs`:

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

**Author-recorded effort hint (soft tie-breaker).** When candidates
remain tied after the score and optional desync rules, prefer the
**lower-effort** candidate before the lowest-issue-number tie-break.
Read the authored `<!-- {{PROJECT_MARKER_PREFIX}}-effort: S|M|L -->` footer
(or the `discover-roadmap-graph` node's `effort`): `S` < `M` < `L`, with
a missing or invalid hint as the **neutral middle** (`M`). **Soft**
rule: reorders only within a single score tie band, never skips,
gates, or crosses a band; the `discover-roadmap-graph` union already
emits this order.

**High-contention shared-file overlap (advisory).** Concurrent
autopilot sessions tend to edit the same F-phase bundle instruction
files (`bundle-review` / `bundle-merge`) and `audit/sync-manifest.json`.
As a **soft** tie-breaker evaluated after score / desync / effort but
before the final lowest-issue-number tie-break, prefer a candidate
whose `## Candidate files` do **not** overlap an
actively-claimed or open-PR issue on one of those files; the optional
`discover-shared-file-overlap` helper (see
[IDD helper scripts](../../docs/idd-helper-scripts.md)) reports each
candidate's `overlapFlag` and `recommendedOrder`. **Never a hard gate**
— overlap never overrides the score or crosses a band. See the
[high-contention shared-file convention](../../docs/policy-constants.md#high-contention-shared-files).

After picking, proceed to **A4.5** (`idd-suitability.instructions.md`).

## A4.5 — Pre-Claim Issue-Suitability Triage

Read [`idd-suitability.instructions.md`](idd-suitability.instructions.md)
for the full suitability triage protocol: seven checks, failure outcomes,
mutation policy, coordination rules, decision flow, and edge cases.

## Roadmap markers

Two hidden HTML comment markers are used in issue bodies to support the
discover phase:

- **Roadmap identity** (`{{PROJECT_MARKER_PREFIX}}-roadmap-id`): placed in
  the roadmap issue body; A3 uses it to resolve `blocked-by` dependency
  lookups. A1 identifies the roadmap by its configured label or umbrella
  structure, not by this marker.
- **Sequential dependency** (`{{PROJECT_MARKER_PREFIX}}-blocked-by`): placed
  in an issue body to express a hard dependency — this issue **cannot
  start until** the roadmap with the matching `roadmap-id` is closed.

**Do not use `{{PROJECT_MARKER_PREFIX}}-blocked-by` to group sub-tasks under
an active roadmap.** Sub-tasks that should be worked on while the
roadmap is open belong in the roadmap's task list as `- [ ] #NNN`
entries; `blocked-by` is reserved for issues that must wait for a
separate, prior roadmap to close (cross-phase sequential dependency) —
see the
[A3 diagnostic](../../docs/idd-design-rationale.md#a3---diagnostic-all-candidates-blocked-by-an-open-roadmap)
for the resulting deadlock pattern.

## Scope invariant (summary)

Do not widen issue-selection scope beyond the roadmap traversal except
for the explicit query allowlist already defined in A0-T, A0-O, A1,
A1.5, A3, and A4.5, or for a same-run operator opt-in per A3 step 5
(never inferred from prior or standing instructions). A single explicit
target authorizes only that issue.
