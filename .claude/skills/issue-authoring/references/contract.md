# Bundled Issue Authoring Contract

This file keeps the `issue-authoring` bundle usable when it is installed
or copied outside this repository root. It mirrors the canonical
contract in `docs/issue-authoring-skill.md`. That canonical document
exists only inside this bundle's source repository — an installed copy
of this bundle should not expect it to be present.

## Target marker prefix

**Prefix-first**: resolve the target repository's hidden marker prefix
before emitting _any_ authoring marker — `roadmap-id`, `blocked-by`,
`autopilot-suitability`, or `effort`. Resolve it once, up front, not as
an afterthought once a marker is already half-drafted.

- Use the prefix documented by the target repository's onboarding or
  IDD instructions.
- In this source repository the prefix is `idd-skill`, but installed
  bundles must not assume that value elsewhere. Never default to
  `idd-skill` in an installed bundle; use it only when the target
  repository actually configured that value.
- If the prefix is not discoverable from the repository docs or user
  context, stop and ask instead of emitting a guessed marker
  (preventive; no observed incident yet). A prefix the operator already
  confirmed during an onboarding hearing (Steps 1A-1C of
  `idd-template/ONBOARDING.md`) counts as a resolved value under "user
  context" — even before it is committed anywhere in the target
  repository's tree — and does not require asking again.

## Trigger policy

Use this bundle when direct implementation would skip the issue hygiene
that the IDD execution loop depends on.

Invoke it when one or more of the following are true:

- the request is too large or ambiguous for one reviewable change
- the likely solution needs decomposition into multiple atomic tasks
- dependencies or execution order must be made explicit before work can
  start safely
- the user wants a roadmap, issue breakdown, or parallelizable work
  plan

Skip it when all of the following are true:

- the task fits one reviewable change
- verification is already clear
- no roadmap, dependency marker, or issue split is needed
- the user did not ask for issue drafting first

## Stable phases

The bundle uses two stable phases. These names mirror the canonical
contract and should stay stable for copied bundles.

### 1. Intake and Clarification

In this phase, the agent:

- inspects the relevant code, docs, and existing issues
- identifies assumptions and ambiguity that affect issue quality
- runs a secondary critique pass before drafting
- asks the user only the questions that block safe issue drafting

The critique pass is agent-neutral: use a subagent or rubber-duck
reviewer when available, otherwise run an explicit self-critique
locally. Clarification must be bounded; use the repository-local
`issueAuthoring.maxClarificationRounds` value when available,
otherwise default to 3 rounds. If safe drafting is still impossible
after that, stop and report the remaining blockers instead of looping
indefinitely.

**Under-clarification stop rule.** If, after bounded clarification, you
still cannot name the concrete surface to edit or an objective
verification for a candidate task, route it to `needs-decision` or ask
— do not publish a confidently-vague `ready` issue. Reliability over
speed. This is distinct from the "Under-specified" specificity band
below: that band judges an already-drafted body's wording, while this
rule stops publication earlier, during Intake, before a body is even
drafted.

### 2. Decompose and Draft

In this phase, the agent:

- restates the clarified request in implementation-facing terms
- splits work into atomic tasks
- checks whether each task is suitable for autonomous execution
- reuses or extends existing issues before creating new ones
- drafts orphan issues, roadmap packages, sub-issues, or non-ready
  buckets as appropriate

## Readiness buckets

Do not silently drop low-confidence or low-readiness work. Route each
candidate task into one stable bucket:

- **ready**: passes limited scope, clear verification, and autonomous
  completion
- **deferred**: plausible, but priority, timing, or decomposition is not
  strong enough for execution
- **needs-decision**: depends on a product, policy, or design choice
- **blocked-by-human**: waits on a person, credential, asset, or outside
  system
- **out-of-scope**: does not belong in the repository or skill scope

## Specificity target

Issue drafting should aim for a level of specificity where a
middle-tier cloud model can implement the task without drifting. This
is a practical drafting heuristic, not a hard model requirement. The
goal is to avoid both hidden assumptions that only a top-tier model can
infer and step-by-step runbooks that cost too much to author.

### Three specificity bands

| Band                | Practical signal                                                                                                          | Drafting response                                                                    |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| **Under-specified** | Stable execution likely depends on a frontier cloud model class                                                           | Add missing constraints, split scope, or make acceptance criteria more explicit      |
| **Target**          | A middle-tier cloud model class can implement the issue without drifting                                                  | Treat this as the preferred drafting target when the execution axes already pass     |
| **Over-specified**  | Even a lightweight local or compact cloud model class could follow the issue mechanically because it has become a runbook | Remove procedural micromanagement while keeping invariants, file anchors, and checks |

The capability tiers above are practical heuristics, not a fixed
compatibility matrix or runtime requirement.

### How the specificity target interacts with readiness

This heuristic does not replace the IDD execution axes:

- **Limited scope** still decides whether the work fits one issue or
  needs a roadmap.
- **Clear verification** still decides whether success is objectively
  checkable.
- **Autonomous completion** still decides whether the task can finish
  without outside coordination.

An issue can be specific yet still fail A4 or A4.5 because it is too
broad, not verifiable, or blocked on a human decision. Conversely, an
issue that passes those gates can still be under-specified if it leaves
too much implementation shape implicit. The drafting target is therefore
"ready and stable for a middle-tier model," not "maximally detailed."

## Executability gate for code spec-units

For a **code spec-unit** — a drafted unit whose acceptance criteria are
objectively executable (a script, function, or test the drafted issue
itself specifies) — an authoring session can validate the draft before
publishing by building a throwaway reference implementation against its
own stated acceptance check and accepting the draft only if that
reference implementation passes. This reuses the downstream execution
loop as an upstream ground-truth gate: it catches drafts whose
acceptance criteria are internally inconsistent, non-trivially
unsatisfiable, or otherwise not actually implementable, before a
downstream executor ever claims the issue. The reference implementation
is a discarded validation probe, never published — it does not cross the
Publication boundary below; only the drafted issue itself is published,
and building the probe does not start the IDD execution loop.

This is a **recommended practice for repositories or domains where a
drafted code spec-unit has an objectively executable acceptance
check**, not a change to this repository's own mechanical
`bin/idd-audit-authored-issue.mjs` checks or a new requirement on this
repository's own issue-authoring practice — most of this repository's
issues are multi-file engineering changes without a single executable
acceptance check to validate against.

- **Weak-model semantic self-review stays advisory.** When a weak
  authoring model reviews its own draft for semantic quality, treat the
  verdict as advisory only, never a hard veto on publishing — mirroring
  the narrow-question guidance for weak-model judgment calls in
  `docs/idd-workflow.md`'s Weak-model guardrails section.
- **Decompose and draft want different model traits.** Decomposition
  (judgment about scope and structure) tolerates a verbose reasoning
  model; the structured draft step (emitting the exact spec/acceptance-
  criteria block) is more reliable on a leaner, more literal model,
  whose chain-of-thought does not compete with the drafted block for
  token budget. Pick the model per sub-task, not per pipeline, when both
  are available.
- **Redraft and re-decomposition are limited rescue mechanisms, not
  reliable fixes.** A bounded redraft loop tends to re-roll rather than
  converge, because a weak author regenerates rather than incrementally
  fixes. Re-decomposing a repeatedly-failing unit is usually low-value
  too: most authoring failures are hard-but-atomic rather than
  over-broad, and splitting a hard-but-atomic unit tends to produce
  incoherent sub-units that do not recompose. Treat a code spec-unit
  that repeatedly fails this gate as a candidate for `needs-decision` or
  human/stronger-model authoring instead of looping indefinitely.

## Reuse-first issue policy

Before creating any new issue, check whether the work already has a
suitable home.

**Claim-state precondition (check this first).** Before reusing or
extending _any_ existing issue, determine whether it has an **active
claim** (its latest valid `claimed-by` comment is newer than the
configured `claim-stale-age`; distributed default 24 h) or an **open
PR**, or is otherwise actively executing. If so, you **MUST NOT edit its
body**: the working agent snapshots the issue body into its B2 plan and
treats that plan as authoritative — it never re-reads the body, so a
post-claim body edit is silently lost and becomes an implementation gap.
You **may** add a separate **comment** (never an edit or append to the
body), but **must not** rely on the claimed agent acting on it. Cover
the intended change with a **follow-up issue** (or a roadmap track around
it), and you **SHOULD** post a cross-reference comment on the claimed
issue linking the follow-up. Stale or reclaimable claims (latest
`claimed-by` older than `claim-stale-age`) are exempt — the next claimer
re-reads the latest body, so editing them is safe.

Then apply these checks in order:

1. If an existing open issue already matches the task and only lacks the
   new schema details, extend that issue instead of cloning it.
2. If an existing open roadmap already owns the initiative, add or
   refine task-list entries there instead of creating a competing
   umbrella.
3. If an existing issue is close but too broad, split follow-up work
   out of it rather than widening the original issue further. When the
   issue being split is itself a roadmap child, update the parent
   roadmap's `## Tracks` list in the same authoring action — add the
   new issue's link and adjust any sequencing notes (a short dated note
   is the observed good pattern) — subject to the claim-state
   precondition above applied to the roadmap issue's own claim/PR
   state, and record the provenance in the new issue's body (e.g.,
   `Split out of #<n>`).
4. If an existing issue has an **active claim**, an open PR, or is
   otherwise being actively executed, do **not** edit its body or
   repurpose it (see the claim-state precondition, which exempts
   stale/reclaimable claims); create a follow-up issue or extend the
   roadmap around it instead.
5. Create a brand-new issue only when no existing issue can absorb the
   work without harming ownership, clarity, or reviewability.

Report when the bundle reuses, extends, or declines to reuse an issue
so a later session can follow the reasoning.

**Recent-window scan for just-discovered problems.** The checks above
assume the work already has a candidate home to reuse or extend. When
instead authoring an ad hoc issue for a problem **just discovered**
during the current session — a build-breaking regression noticed
mid-session, for example, rather than a task drafted from an existing
backlog — run a recent-window duplicate scan immediately before
publishing: list the newest issues regardless of state and check
whether a concurrent session already authored the same problem.

```sh
gh issue list --repo <owner>/<repo> --state all --limit 20
# or, scoped to a recency window:
gh issue list --repo <owner>/<repo> --state all --search "created:>=<YYYY-MM-DD>"
```

A hit routes back into the checks above: extend the discovered issue
instead of publishing a duplicate. When the race slips past this scan
anyway (near-simultaneous discovery), the outcome is **anticipated and
self-resolving, not a coordination failure**: both sessions proceed
independently through their own claim and implementation cycle;
whichever PR merges first wins; the other session manually verifies
the fix already landed on the default branch, then closes its own
issue and (unmerged) PR as superseded, citing the verifying evidence.
This is the same manual verify-then-close judgment call the execution
loop's B2.0 supersession re-check (`idd-work.instructions.md`) applies
after claim — this scan only adds an earlier, pre-publish checkpoint.
A fast enough race can still surface even after B2.0; when it does, it
resolves the same way.

**Same-shape follow-up chains.** A different case from both checks
above: an issue whose own acceptance criteria explicitly ask for a
follow-up issue with the same acceptance criteria when the round does
not fully complete (a "retry again" pattern, e.g., an iterative
measurement or convergence task). Before drafting such a
same-shape successor, state what measurable forward progress the
just-completed round achieved — a changed metric, a narrowed diagnosis,
a newly-tested hypothesis, a newly-discovered and now-fixed blocker.
When the round produced no such signal (the same result, the same
diagnosis, no new information beyond the predecessor), route to
`needs-decision` (or an equivalent hold) instead of authoring another
identical-shape issue, and record why the chain paused so a later
session or human can see the reasoning. This is a sibling check, not a
replacement: the checks above guard against an accidental duplicate;
this guards against a correct-but-repeated pattern continuing past the
point it stops being useful.

## Output chooser

Choose the smallest safe output shape:

- **Orphan issue**: one autonomous task can finish the work, no
  roadmap-level coordination is needed, and the target repository
  discovers orphans — i.e. `issue-scope` is `roadmap-first` (the
  default; orphans are picked up as the fallback when no roadmap work is
  startable) or `orphan-first` (orphans first). If the repository uses
  `orphan-first-policy: maintainer-approved`, surface the required
  post-publication maintainer approval step. If the repository sets
  `issue-scope: roadmap` (roadmap-only) or disables public orphan-first
  discovery with `orphan-first-policy: public-disabled`, surface that
  constraint and prefer a roadmap package instead.
- **Roadmap plus sub-issues**: the request needs visible sequencing,
  parallel tracks, multiple ready issues, or multi-session handoff.
- **Stable non-ready buckets**: some work is deferred, blocked by a
  human, waiting on a decision, or outside the repository scope.

When the repository keeps the broader issue-author approval gate,
surface the same post-publication approval step for orphan issues,
roadmaps, and sub-issues whenever the issue author is not
self-authorizing under the repository's
`maintainer-approval-actors` policy. The configured ready label from
`approvalSignals.readyLabelName` (default: `idd:ready`) is accepted
according to `approvalSignals.labelFreshnessMode` (`presence-only` by
default, optional `event-freshness`), while standalone `IDD ready`
comments from a maintainer approval actor must stay fresh against the
latest issue content and generated-plan update (or an equivalent
draft-stability signal). Until that approval condition is satisfied,
route the draft to the
approval-needed fallback bucket instead of the normal ready-to-start
set.

## Human-dependency isolation

Treat unresolved human dependency as a side effect that should be
isolated away from ready execution issues whenever possible.

- **Front-load** human-dependent work when coding cannot start safely
  until a person provides a decision, credential, permission,
  maintainer-only action, external setup, or policy choice, or until an
  unavailable system becomes usable again.
- **Back-load** human-dependent work when the remaining dependency is
  subjective review, publication choice, optional polish, or another
  post-implementation judgment that should not block an otherwise
  autonomous core change.
- Keep the central execution issue as close as possible to a pure
  autonomous unit: clear repository-local scope, no hidden human handoff
  in the implementation steps or acceptance criteria, and objective
  verification.
- Preserve unavoidable human-dependent work in an explicit stable
  bucket, dependency edge, or approval-needed hold rather than mixing it
  into a ready issue.
- Route unresolved choices to `needs-decision`, route waiting on people,
  credentials, maintainer-only actions, or unavailable systems to
  `blocked-by-human`, use `deferred` when timing or decomposition is not
  strong enough yet, and keep approval-gated ready work in the
  approval-needed hold instead of the normal ready-to-start set.
- If a task cannot be expressed without unresolved human coordination in
  the middle of implementation, it is not yet `ready`.

This principle complements the execution axes rather than replacing
them: it is a practical way to protect autonomous completion and clear
verification during issue drafting.

## Hidden human-dependency validation

Before publishing a `ready` issue, run a short pre-publication check for
hidden human dependency. Treat this as a routing aid, not a rigid
wording linter: the question is whether the work still depends on
unresolved human action, not whether the draft used one forbidden
phrase.

Ask these checks:

1. Does implementation require credentials, external access, hardware,
   or infrastructure that the executing agent cannot already reach? If
   yes, route the work to `blocked-by-human` unless that dependency can
   be front-loaded into a separate prerequisite issue.
2. Does any implementation step or acceptance criterion depend on a
   product, policy, or design decision that has not been made? If yes,
   route the work to `needs-decision`.
3. Do the acceptance criteria require subjective human approval instead
   of objective verification? If yes, rewrite the ready issue around
   measurable checks and back-load the optional review or publication
   judgment.
4. Does a roadmap narrative hide human-dependent work inside prose while
   the visible task list presents the item as execution-ready? If yes,
   preserve that work in an explicit stable bucket, approval-needed
   hold, or blocking issue instead of burying it in the narrative.
5. Is any dependency marker being used only to group related work or
   express preference order? If yes, remove the fake blocker and use
   task-list structure or sequencing notes instead. Keep dependency
   edges only for true start blockers.

Normal post-implementation code review, merge approval, or publication
choice does not by itself make an otherwise autonomous issue non-ready.
The ready issue should still carry its own objective verification even
when a human will look at the result afterward.

## Codebase-fidelity validation

Before publishing a `ready` issue, run a short pre-publication check that
the spec stays faithful to the existing codebase. Treat this as a routing
aid, not a rigid wording linter: A4.5 suitability triage is structural and
does not read the codebase, so a spec that contradicts established
semantics can still pass that gate and only surface the mismatch in
advisory review, costing extra review-fix round-trips.

Ask these checks:

1. When an issue reuses an existing identifier or field name, confirm the
   specified value matches that name's established semantics in the
   codebase — do not overload a name with a new shape or source.
   **Remedy**: mint a new, distinctly named field instead of overloading
   the existing one. Worked example: a candidate issue's acceptance
   criterion reads "set `retryAttempts` to the elapsed wait time in
   milliseconds" — `retryAttempts` already means a whole-pass apply
   attempt _count_ in `audit-pr-cleanup.mts`'s `CleanupAuditReport`, so
   reusing it for a duration overloads an established name with an
   incompatible shape. Fix: mint a new field instead, e.g.
   `retryWaitMs`, and leave `retryAttempts` untouched.
2. Flag values that are mutable at runtime — specify a live read at the
   point of use rather than a one-time capture at construction.
3. When an issue proposes to **delete, replace, or "align to upstream"**
   code, first check the target for an intentional-divergence signal — a
   local change made on purpose to differ from upstream. If one is present,
   require the issue body to acknowledge that divergence and justify
   overriding it, rather than silently reverting hardening a consumer added
   deliberately (blind "resync to upstream" resets are a recurring
   Discover→plan-cycle waste when the divergence turns out to be
   intentional). The recommended portable signal is a canonical inline
   code-comment convention (for example a `do-not-revert:` / `idd-divergence:`
   marker) — it travels with vendored files and needs no repo-wide label
   taxonomy. An owner/CODEOWNERS marker or a referenced tracking issue may
   also serve, but the code-comment convention is the recommended default.
   Do not hard-code any single consumer's divergence-tracking mechanism.
4. When an issue drafts a **template resync or reimport** (pulling a
   newer `idd-template/` revision into a repository that already
   adopted IDD), consult the **upstream target ref's** copy of
   `docs/customization.md`'s "Documentation lint compatibility"
   section (added 2026-08-05, commit `6ceaa6dd`) before treating
   `.markdownlint.yml` / `.markdownlint-cli2.yaml` / `.cspell.config.yml`
   as unchanged. `docs/customization.md` is itself part of the
   imported core file set, so it resolves in an installed or adopter
   context once present — but an adopter whose prior import predates
   that commit has no such section in their own local copy yet, which
   is exactly the named gap to document in the resync issue, not a
   documentation-consultation failure. Either the target ref's
   `docs/customization.md` section or, from a source checkout of
   `idd-skill` itself, `idd-template/ONBOARDING.md`'s "Re-importing"
   section, documents the same named gap: an adopter's own rule
   customizations for these files need a by-hand merge into the new
   import rather than an assumed carry-forward, and
   `idd-onboard.mjs --import` reports a `blockedOverwrites` finding
   instead of silently keeping a same-named local file as-is, unless
   the import used `--force`, which still writes the file and reports
   it in the verdict JSON (`plan` as an `overwrite` entry,
   `filesChanged`, and `written`) but omits it from
   `blockedOverwrites` so the import is not blocked (observed
   2026-08-12/13 on an
   adopter repository, `setup.ubuntu`, kurone-kito/idd-skill#2012).
5. When drafting a resync issue's Background, run a mechanical
   placeholder diff against the **upstream `idd-skill` source
   repository's** `idd-template/` trees at the two relevant refs —
   never a tree inside the target/adopter repository itself, which
   retains no local `idd-template/` directory of its own once IDD is
   imported.
   - **Baseline ref.** Use the exact tag or commit SHA actually
     imported at the adopter's prior onboarding when it is explicitly
     recorded (for example in the original onboarding PR/commit
     message) or when the operator can confirm it directly. Do not
     infer it from the adopter's current file content: neither a diff
     against the import commit nor a reverse- or forward-substitution
     content-match against a candidate upstream tree reliably pins a
     single ref — onboarding substitutes placeholder values and
     permits legitimate post-substitution edits, an import commit's
     diff itself only records the already-transformed adopter
     snapshot, and more than one upstream commit can plausibly yield
     the same imported subset. When no explicit record or operator
     confirmation is available, report the baseline as
     unresolved/ambiguous in the resync issue itself rather than
     guessing one from content alone. Do not construct `v<iddVersion>`
     (`.github/idd/config.json`) as the baseline without this check:
     `iddVersion` is only a coarse signal and can be stale, an adopter
     still on `0.1.0` has no matching tag at all (`CHANGELOG.md`
     records that `0.1.0` predates the tag discipline), and an adopter
     who pinned a raw
     commit SHA at import time instead of a tag may have no
     `v<iddVersion>` tag matching what they actually imported either.
   - **Target ref.** The new release/ref the resync targets.
   - **Scope.** Intersect both trees with the Step 2 "File list" core
     file set as it reads **at the target ref**
     (`idd-template/ONBOARDING.md`'s generated file-list block) plus
     whichever optional profile artifacts the adopter selected, not
     the complete `idd-template/` tree — a file such as
     `idd-template/ONBOARDING.md` itself is never copied into an
     adopter, so reporting it as changed is noise. Use the target
     ref's manifest, not the baseline ref's: a file the target release
     newly added to the core or a selected profile is exactly the kind
     of change a resync issue must report, and the baseline ref's own
     manifest predates it.
   - **Token filter.** Compare each ref's own placeholder table in
     effect at that ref, not today's list applied to both — a
     placeholder added or removed between the two refs is itself
     exactly the kind of token-identity change this check exists to
     report, and reusing one ref's list for the other's tree would
     hide that change. At a ref from commit `e55ccd9c` (2026-05-12)
     onward, that table is Onboarding Reference — Placeholder Values'
     "Final placeholder meanings" table
     (`docs/onboarding/placeholders.md`). An older ref has no such
     file — the placeholders were documented directly inside
     `idd-template/ONBOARDING.md`'s own "Step 1C — Collect placeholder
     values" section instead; use that section's list as the
     allowlist for a baseline ref that old. Never match every
     `{{...}}`-shaped span unfiltered either way — an unrestricted
     match also catches ordinary GitHub Actions expressions such as
     `${{ github.token }}` in an imported workflow file.
   - **Excluded paths.** Skip `docs/onboarding/placeholders.md`,
     `docs/customization.md`, and `docs/onboarding/policy-decisions.md`
     — these deliberately keep `{{...}}` tokens literal to document
     the placeholder syntax itself, so diffing them misidentifies
     literal documentation as an outstanding substitution.

   Compare the actual token identities per changed file, not only the
   aggregate occurrence count: a same-count one-for-one placeholder
   swap changes what an adopter must substitute without changing the
   count. Name any file whose placeholder tokens changed, rather than
   asserting a file needs no placeholder substitution as an unverified
   default (observed 2026-08-12/13 on an adopter repository,
   `setup.ubuntu`, kurone-kito/idd-skill#2012).

## Live-observed claim citation

When a drafted issue's Background section (or its `## Goal` / `## Why
this matters` equivalent, per the schema in use) asserts a "live
observed" runtime behavior claim (as opposed to a claim verifiable by
reading static source), cite a concrete, checkable artifact for it — a
permalink, a PR/comment/run ID, or an inline reproduction snippet —
rather than only a prose description of the observed event. A drafting
session that already has the artifact in hand (a PR review thread, a
workflow run, an adopter's own report) should cite it directly instead
of paraphrasing from memory; a worked example already exists elsewhere
in this file: "(observed 2026-08-12/13 on an adopter repository,
`setup.ubuntu`, kurone-kito/idd-skill#2012)".

This is not a mechanical `audit-authored-issue` gate check: a
live-observed claim is prose-level and not reliably machine-detectable
without a high false-positive risk. Apply this discipline at drafting
time instead, before an unsupported claim ships in one of these
sections that another session or reviewer cannot independently
re-verify.

## Dependency minimization

Encode a dependency edge only when it reflects a true correctness,
availability, or ordering constraint.

- keep independent sibling tasks as roadmap task-list entries, with
  short sequencing or parallelization notes when that helps reviewers or
  later agents
- use visible or sequential dependency markers only when the issue
  cannot start safely until the dependency resolves
- do not create an artificial serial chain when sibling tasks could be
  reviewed and verified independently
- do not split one natural, cohesive change into artificial sibling
  issues only to widen parallel execution
- whenever an issue's own narrative states that its work cannot safely
  start until another named issue resolves, encode `Blocked by #NNN`
  for that issue rather than leaving the constraint as prose-only
  sequencing. Discover and A4.5 honor the hard `Blocked by` edge, not
  a narrative "runs after #NNN" note: A4.5 Actionability inspects the
  body, not completability, so a narrative-only dependency reports the
  issue startable the moment its other filters pass, and claiming it
  then means either violating the asserted constraint or doing the
  referenced issue's unresolved work first. This rule is general, not
  limited to a fixed list of cases; the two recurring patterns below
  are illustrative, not exhaustive
- **example — docs or operator-help child that documents behavior
  implemented by sibling issues**: encode `Blocked by #NNN` for those
  implementation issues (or otherwise sequence the docs child to run
  after they merge) so the documentation is written against **shipped**
  behavior. Describing designed-but-unshipped behavior in the present
  tense is a recurring advisory-review-thrash pattern; "describe shipped
  behavior" is a true ordering constraint, so this edge is consistent
  with the encode-only-a-real-constraint rule above
- **example — finalize or verify track whose acceptance criteria
  assert state produced by sibling implementation tracks**: encode
  `Blocked by #NNN` on **each** such sibling rather than stating the
  ordering only in prose. A prose-sequenced finalize track reports
  startable the moment its build foundation closes, and claiming it
  then means either failing its acceptance criteria or doing
  the siblings' unmerged work
- once a `Blocked by #NNN` / `Depends on #NNN` reference resolves —
  the referenced issue closes **with its required outcome verified as
  delivered**, not merely closed as not-planned, superseded without an
  equivalent implementation, or later reopened — revisit the blocked
  issue's own body and remove that reference and its explanatory wait
  prose, rather than leaving it in place as inert history, but keep
  any prose identifying the delivered artifact or interface this
  issue's own scope depends on. A line naming several references
  (`Blocked by #10, #11`) keeps the still-open ones — remove only the
  resolved reference, and remove the whole line only once every
  reference on it has resolved. When the
  underlying constraint is not actually met, reopen the prerequisite
  issue or repoint the dependency line at an open replacement issue
  instead of leaving a stale edge in place:
  `discover-readiness-check` blocks only on an `OPEN` referenced
  issue, regardless of why it closed, so retaining the edge alone does
  not keep the dependent issue blocked. (Observed 2026-08-13 on issue
  #1994's `Blocked by #1985` note, after #1985 closed; reported in
  #2002.) This cleanup is more than tidiness: stale wait-explaining
  prose can trip `checkVerifiability`'s subjective-approval heuristic
  in
  `suitability-triage.mts`, which matches either a single line
  combining a subjective-subject word (`maintainer`, `stakeholder`,
  `human`, `opinion`, `judgment`/`judgement`, `ux`, or `feel` — not
  only authority nouns) with a gate word (`approval`, `sign-off`/
  `signoff`, `decision`, or `preference`), or a gate word followed
  within 80 characters — including across lines — by a
  subjective-subject word.
  This still fires even though the structural dependency filter
  already correctly treats the closed reference as unblocking

When an issue keeps a dependency edge, justify each dependency edge in
the surrounding issue body and confirm that the split still preserves
natural cohesion.

## Nested roadmap nodes

Use a nested roadmap when one roadmap track needs its own coordination
boundary, active child list, or multi-session handoff. A nested roadmap
is still a roadmap node, not a normal execution candidate.

Authoring rules:

- reference the nested roadmap from the parent roadmap task list instead
  of hiding it in prose
- give the nested roadmap its own roadmap marker and `## Tracks` section
  that links the active child work it coordinates
- treat the nested roadmap as a coordination/audit node for discovery
  and roadmap audit; do not draft it as normal A3/A4/A5 execution work
- use two-level or three-level nesting only when the intermediate
  roadmap has its own active child work or handoff boundary
- do not use `Blocked by #NNN` or
  `<!-- <marker-prefix>-blocked-by: ... -->` only to group leaf issues
  under an active nested roadmap; reserve those encodings for true
  execution dependencies or sequential roadmap dependencies between
  separate roadmaps

Validation expectations:

- each nested roadmap node is linked from its parent roadmap task list
- each nested roadmap node links its own active child work from its body
- cycles, duplicate references, and closed intermediate roadmaps with
  hidden open descendants must be surfaced as validation failures or
  explicit follow-up notes, not silently normalized away

## Required dependency encoding

- Roadmap identity via `<!-- <marker-prefix>-roadmap-id: ... -->`
- Active child issues via roadmap task-list links
- Issue-to-issue dependencies via `Blocked by #NNN`
- Sequential roadmap dependencies via
  `<!-- <marker-prefix>-blocked-by: ... -->` only when a separate
  roadmap
  must close first

## Required draft content

### Candidate files format

The `## Candidate files` section is not free-form prose: the
`discover-shared-file-overlap` evidence helper parses it as machine input
for the A4 Step 2 high-contention shared-file check (see
[High-contention shared-file overlap](https://github.com/kurone-kito/idd-skill/blob/main/docs/policy-constants.md#high-contention-shared-files)).
Populate it accurately rather than as a loose reading aid for humans.
Optional for an orphan or roadmap issue; required for a
[child issue under a roadmap](#child-issue-under-a-roadmap) (see
[Required draft content](#required-draft-content) below).

- List each candidate file path inside backticks, one path (or one
  bullet) per line — for example `` - `src/scripts/idd-onboard.mts` ``.
  The parser extracts every backtick-quoted path in the section,
  including continuation lines of a multi-line bullet.
- A bullet with no backticks at all still falls back to its leading
  path-like token, but backtick-quoting every path is the reliable form
  and should always be used.
- The section ends at the next Markdown heading, **of any level** —
  even a deeper subheading closes it. Anything inside it that looks
  like a path — backtick-quoted or a bare bulleted leading token — is
  parsed as a candidate file, so keep unrelated notes, caveats, or
  subheadings outside the section.

### Orphan issue

- title with a concise user-facing summary
- `## Background` or `## Goal`
- `## Proposed change`
- `## Acceptance criteria`
- an autopilot-suitability footer at the end of the body (visible
  line + `<!-- <marker-prefix>-autopilot-suitability: N -->` marker;
  see [Autopilot-suitability score](#autopilot-suitability-score))
- an optional effort footer next to it (visible line +
  `<!-- <marker-prefix>-effort: S|M|L -->` marker; see
  [Effort hint](#effort-hint)) — a soft Discover selection tie-breaker,
  fail-safe on absence

Validation expectations:

- no `<marker-prefix>-roadmap-id` marker
- no `<marker-prefix>-blocked-by` marker
- acceptance criteria are explicitly verifiable
- the issue stays discoverable under the target repository's
  `issue-scope` setting
- exactly one autopilot-suitability footer with an integer 1-5
  marker; a score of `1` carries the configured `blocked-by-human` label
  (default `status:blocked-by-human`), unless an
  `authoring-bucket: needs-decision` marker substitutes the configured
  needs-decision label instead (see
  [Authoring-bucket marker](#authoring-bucket-marker))
- passes the `audit-authored-issue` mechanical pre-publish gate for the
  `orphan` shape (see [Mechanical pre-publish gate](#mechanical-pre-publish-gate))

### Roadmap issue

- title that describes the umbrella initiative
- `## Goal`
- `## Background` or `## Why this matters`
- `## Tracks`
- `## Success criteria`
- one `<!-- <marker-prefix>-roadmap-id: <roadmap-id> -->` marker
- an autopilot-suitability footer at the end of the body (visible
  line + `<!-- <marker-prefix>-autopilot-suitability: N -->` marker)
- an optional effort footer next to it (visible line +
  `<!-- <marker-prefix>-effort: S|M|L -->` marker; see
  [Effort hint](#effort-hint)) — a soft Discover selection tie-breaker,
  fail-safe on absence

Validation expectations:

- every active child issue or nested roadmap node is referenced from the
  roadmap body
- the roadmap explains why multiple issues exist
- sequencing and blocking are explicit
- each dependency edge is justified and preserves natural cohesion
- nested roadmap entries stay identifiable as coordination/audit nodes
  instead of normal execution leaves
- exactly one autopilot-suitability footer with an integer 1-5
  marker; a score of `1` carries the configured `blocked-by-human` label
  (default `status:blocked-by-human`), unless an
  `authoring-bucket: needs-decision` marker substitutes the configured
  needs-decision label instead (see
  [Authoring-bucket marker](#authoring-bucket-marker))
- passes the `audit-authored-issue` mechanical pre-publish gate for the
  `roadmap` shape (see [Mechanical pre-publish gate](#mechanical-pre-publish-gate))

### Child issue under a roadmap

- title with a concrete task summary
- `## Background`
- `## Proposed change`
- `## Acceptance criteria`
- `## Candidate files` (see
  [Candidate files format](#candidate-files-format) above)
- optional dependency line or sequential roadmap marker when needed
- an autopilot-suitability footer at the end of the body (visible
  line + `<!-- <marker-prefix>-autopilot-suitability: N -->` marker)
- an optional effort footer next to it (visible line +
  `<!-- <marker-prefix>-effort: S|M|L -->` marker; see
  [Effort hint](#effort-hint)) — a soft Discover selection tie-breaker,
  fail-safe on absence

Validation expectations:

- the issue is referenced from its parent roadmap task list
- acceptance criteria are locally verifiable
- `## Candidate files` lists the files the child is expected to touch,
  so the A4 Step 2 high-contention shared-file check
  (`discover-shared-file-overlap`) can actually engage instead of
  silently no-opping for lack of input
- any dependency marker is resolvable, intentionally chosen, and
  justified
- the issue can be claimed independently without absorbing sibling work
- exactly one autopilot-suitability footer with an integer 1-5
  marker; a score of `1` carries the configured `blocked-by-human` label
  (default `status:blocked-by-human`), unless an
  `authoring-bucket: needs-decision` marker substitutes the configured
  needs-decision label instead (see
  [Authoring-bucket marker](#authoring-bucket-marker))
- passes the `audit-authored-issue` mechanical pre-publish gate for the
  `child` shape (see [Mechanical pre-publish gate](#mechanical-pre-publish-gate))

## Drafted issue prose language

A drafted issue's human-readable prose sections — `## Background` (or
`## Goal`/`## Why this matters`), `## Proposed change`,
`## Acceptance criteria`, and the roadmap shape's `## Tracks` /
`## Success criteria` — follow the target repository's resolved
`authoringLanguage` value from `.github/idd/config.json`:

- A fixed BCP-47-shaped tag (for example `en`, `ja`, `fr`) makes the
  drafted prose use that language.
- The literal `match-source` matches the operator's live conversational
  language during an interactive/hearing issue-authoring session.
- An absent field defaults to English.

See `docs/customization.md`'s Authoring Language section for the full
field definition.

**Marker/footer carve-out**: this never changes any HTML-comment
marker's machine-parsed format, nor any visible-line mirror whose exact
wording a mechanical regex parses. Concretely, the autopilot-suitability
and effort footers' visible lines (`_Autopilot suitability: N / 5 ...`
/ `_Effort: S | M | L ...`) must stay in their exact canonical English
wording regardless of `authoringLanguage`, since `audit-authored-issue`
matches them against a fixed English-phrase regex.

## A4.5 Suitability Gate Alignment

When an issue is published and reaches the IDD discover phase, the A4.5
pre-claim gate will evaluate it against seven suitability checks. The
authoring skill should catch these issues before publishing:

| Check                    | Authoring Bucket     | How to Prevent                                                                  |
| ------------------------ | -------------------- | ------------------------------------------------------------------------------- |
| Repository Fit (Check 1) | `out-of-scope`       | Ensure issue is scoped to this repository; escalate if it crosses boundaries    |
| Coherence (Check 2)      | `ready` or escalated | Validate issue body against schema before publish                               |
| Safety/trust (Check 3)   | `ready` or escalated | Screen issue body for code injection and untrusted markers                      |
| Duplicates (Check 4)     | `ready` or escalated | Run reuse-first checks before creating a new issue                              |
| Actionability (Check 5)  | `ready` or escalated | Ensure the issue describes concrete work; escalate if blocked by human decision |
| Autonomy (Check 6)       | `ready` or escalated | Ensure agent can complete without external coordination                         |
| Verifiability (Check 7)  | `ready` or escalated | Ensure success is verifiable; escalate if it requires subjective approval       |

**Check 7 escape-hatch pattern**: an either/or acceptance-criteria bullet
where one branch is a substantive change and the other reads as "or
document the gap/tradeoff" is not an automatic Check 7 PASS -- the
documentation branch must itself name a concrete, checkable requirement,
or evaluate it on its own merits and route to `needs-decision`. See
`idd-suitability.instructions.md`'s Edge Cases section ("Escape-hatch
acceptance criteria") for the full worked example.

Pre-publish validation checklist:

1. **Coherence**: Issue body is well-formed, title+description are
   clear, intent is parseable
2. **Safety**: No code injection, marker injection, or untrusted input
   in issue body
3. **Uniqueness**: Reuse-first check passed; no duplicate or superseded
   work
4. **Human dependency isolation**: Ready issues do not hide unresolved
   decisions, credentials, subjective approvals, or mid-implementation
   human handoffs
5. **Mechanical audit**: the drafted body passes the
   `audit-authored-issue` linter for its declared shape (see
   [Mechanical pre-publish gate](#mechanical-pre-publish-gate))

If any check is uncertain, route the issue to `needs-decision` or
`blocked-by-human` during drafting instead of publishing a
marginally-ready issue.

## Mechanical pre-publish gate

Before publishing a drafted `ready` **orphan, roadmap, or child** body
(the shapes the linter supports), run the `audit-authored-issue`
linter against it when a helper runtime is available. Before newly
publishing a body into the **`needs-decision`** or **`blocked-by-human`**
bucket instead, also run it, passing
`--expect-bucket <needs-decision|blocked-by-human>` (choose the one
matching value): without this, the two mechanical
checks below that key off the `authoring-bucket` marker
(see [Authoring-bucket marker](#authoring-bucket-marker)) never
actually fire in practice, since a non-`ready` body is otherwise never
run through this gate at all — exactly the gap that let #2636/#2637
publish without their required label (#2639 follow-up). `--expect-bucket`
requires the matching marker to be present, failing when it is absent
or disagrees; omit it for a `ready` publish or an edit to an
already-published legacy body, where the marker stays optional and
fail-safe on absence as documented in that section. `deferred` and
`out-of-scope` bodies are not audited by this gate either way. It
mechanically re-checks a subset of the structural rules this contract
states in prose — the autopilot-suitability marker's
exactly-one/coherent-value rule, the one-directional check that a
suitability score of `1` (or an `authoring-bucket: blocked-by-human`
marker, when present) carries the configured `blocked-by-human` label
(it does not check the reverse: a non-`1` score paired with the label
still passes), the equivalent one-directional check for
`authoring-bucket: needs-decision` and the configured
`needsDecisionLabelName` label, markerPrefix consistency across every
authoring marker, the declared shape's required section headings, the
roadmap-id/blocked-by dependency-marker rules, and visible/hidden line
agreement for the suitability and effort footers — so a weak model does
not have to hold every rule in its head at once while drafting.

The linter also emits one **advisory, warning-severity-only** finding
(`prose-dependency`): it flags an issue/PR reference (`#<digits>` or a
full GitHub issue/PR URL) that appears near coordination language (for
example "before", "after", "once", "until", "predates", "gate"/"gated",
"requires", "lands first") with no corresponding encoding for that
reference as one of four recognized forms: a `Blocked by #NNN` line, a
`Depends on #NNN` line, a task-list checkbox item (`- [ ] #NNN`), or a
`Refs #NNN (non-blocking)` line — the same forms
`extractBlockedByIssueNumbers` / `extractDependencyIssueNumbers` /
`extractNonBlockingReferenceIssueNumbers` already recognize elsewhere
in this contract. A task-list checkbox counts regardless of which
heading it sits under, so a roadmap's own `## Tracks` membership list
already satisfies this — it is not a separate "dependency-only" list.
Use `Refs #NNN (non-blocking)` (multi-target: `Refs #NNN, #NNN
(non-blocking)`) for a reference that is deliberately informational —
a roadmap narrative naming a related, currently-blocked follow-up
issue with no ETA, for example — never for a real dependency: unlike
the other three forms,
`discover-roadmap-graph.mts`'s traversal never enters this reference's
target at all, so it cannot become an A1.5 closure-audit blocker, and
this check treats it as already-encoded the same as the other three
forms (#2236). This catches the pattern this contract's own
[Hidden human-dependency validation](#hidden-human-dependency-validation)
check 4 warns about in prose — a hard precondition stated only in
narrative text, not encoded as a real dependency marker. A full-URL
reference is inherently local only when it actually names the current
repository, since a cross-repo dependency cannot be encoded with these
repository-local markers at all — flagging it would recommend an
impossible fix. When the caller supplies the current `owner/repo`
(`--current-repo`, defaulting to `$GITHUB_REPOSITORY` in CI), a
full-URL reference naming a different repository is never flagged;
without that context, a full-URL reference is still flagged by
default (unchanged behavior) — unless its issue/PR number happens to
already appear as a local `Blocked by` / `Depends on` / task-list
marker elsewhere in the body, in which case it is treated as already
encoded like any other match. A Markdown link's target may carry
trailing content after the issue/PR number and before the link's
closing paren — a URL fragment (`#issuecomment-123`), a trailing `/`,
or a quoted link title (`"..."` or `'...'`) — and the link is still
recognized as one match; without this, the label's own bare `#NNN`
would otherwise leak through to the bare-`#` check and be misjudged
independently of the link's (possibly cross-repo) target. A local
`owner/repo#N` shorthand (e.g. `kurone-kito/idd-skill#4321`) is also
recognized, but with the reverse default from the full-URL case above:
it is flagged only when `--current-repo` is supplied **and**
case-insensitively matches `owner/repo`; naming a different repository,
or omitting `--current-repo`, always excludes it, since this shorthand
was never recognized at all before and a bare `owner/repo` cannot be
assumed local without confirmation. A reference-style Markdown link
(`[text][ref]` with a separate `[ref]: target` definition elsewhere in
the body) is recognized the same way as the inline-link form above,
including the same `currentRepo`-based local/cross-repo comparison; a
`ref` with no matching definition is left as literal text and falls
through to the bare-`#` check like any other unrecognized shape. A
quoted link title may contain a backslash-escaped quote matching its own
delimiter (`\"` inside a `"..."` title, or `\'` inside a `'...'` title)
without ending the title early and losing the rest of the link. An empty
or whitespace-only `--current-repo` (or `$GITHUB_REPOSITORY`) is treated
the same as omitting it entirely, rather than as a known repository that
can never match. A nested/child list item's reference is evaluated
together with its full ancestor chain's coordination-language text
instead of being scoped away from it, while a sibling bullet at the same
indentation — nested or top-level — still starts its own separate scope,
so a tight list (no blank line between sibling items) never reads two
consecutive bullets' coordination language as one continuous sentence.
This holds for every nested child under a given parent, at any depth — not
only the first. A continuation line resuming at an ancestor's own
indentation, after a deeper child has already opened, is attributed to
that ancestor rather than the deepest open child. A loose list (a blank
line between sibling items) preserves the same ancestor scope across
the blank line, as long as the following item's own marker is no deeper
than whatever is still open at the end of the preceding item — a
same-depth sibling, or a resumption at a shallower ancestor's own
level — and the preceding item ends in a list marker rather than
trailing plain prose (once plain prose follows the last marker, the
list reads as already having ended, so the blank line is not bridged).
A blank line directly followed by a more deeply indented marker is also
not bridged, to avoid grafting an unrelated item onto an open ancestor
as a false child. Unlike every other check above, a
`prose-dependency` warning never flips `passed` to `false` and never
changes the linter's exit code: it prompts the author to either
convert the prose into a proper dependency marker or consciously
confirm the reference is a mere breadcrumb.

```sh
node scripts/audit-authored-issue.mjs --shape <orphan|roadmap|child> \
  --marker-prefix <resolved-target-prefix> \
  --body-file <path-to-drafted-body> [--label <label>]... \
  [--expect-bucket <needs-decision|blocked-by-human>]
```

Or, for npx/package-manager profiles, the equivalent
`idd-audit-authored-issue` command. Pass `--stdin` instead of
`--body-file` when the drafted body is not yet written to disk.
**Always pass `--marker-prefix`** with the prefix resolved under
[Target marker prefix](#target-marker-prefix): without it, the linter
falls back to reading `.github/idd/config.json` from the current
working directory, and if that file is missing or unreadable — for
example when running from an installed bundle without a local
checkout of the target repository's config — it silently defaults to
this source repository's own `idd-skill` prefix, which produces a
false pass or fail against the wrong prefix instead of an error.

**No helper runtime available (`instructions-only` profile).** The
linter cannot run without Node.js and the vendored `scripts/`
directory, and an `instructions-only` install is a first-class
supported fallback, not a degraded one. Unavailability is never a
waiver: manually re-verify the same checks listed above against this
contract's prose and the [Draft schemas](#required-draft-content)
before publishing.

A `passed: false` report (or non-zero exit, or a failed manual
re-verification) means the draft is not ready to publish yet,
regardless of how complete the narrative reads — fix every reported
finding and re-run before treating the issue as `ready`. The linter (or
its manual equivalent) is a mechanical structural check, not a
substitute for the judgment-based checks above (human-dependency
isolation, codebase fidelity, reuse-first) — passing it is necessary,
not sufficient, for `ready`.

## Autopilot-suitability score

> **Status.** Active contract. Authoring **emits** the score footer
> and Discover **ranks and routes** candidates by it (roadmap #759,
> fully merged). The score stays advisory: it never bypasses the
> A4.5/A5 gates and is fail-safe on absence.

Authored issues carry a persisted **autopilot-suitability score**
from 1 to 5 (higher = more autopilot-suitable). It is the durable,
graded form of the **Autonomous completion** execution axis: the
author makes the judgment once, while context is fresh, so the
Discover phase can rank and route candidates by a cheap read
instead of re-deriving autonomy per candidate.

| Score | Meaning                     | Typical signals                                                                                                          |
| ----- | --------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| 5     | Autopilot-ideal             | Fully specified; deterministic verification (tests/lint/CI/mechanical); no external systems; no human judgment; isolated |
| 4     | Strongly autopilot-suitable | Well-specified and verifiable; minor ambiguity resolvable from repo context; no external/human dependency                |
| 3     | Borderline / mixed          | Autopilot can likely finish but with notable judgment, weaker verification, or review-attention risk                     |
| 2     | Mostly human                | Agent may draft a partial result; completion needs human judgment, an asset, or review the agent cannot supply           |
| 1     | Human-only                  | Interactive credentials, real deployment, subjective/design/product judgment, or external coordination                   |

Scores below the configured discovery floor
(`autopilotSuitability.floor`, default `3`) designate
**human-oriented issues**: in autopilot runs Discover routes them
to humans rather than autopilot.

The score is recorded as a **footer at the end of the issue
body** — a visible line paired with a hidden, prefix-aware
machine marker, mirroring the `claimed-by` convention (visible
note + HTML marker):

```text
---

_Autopilot suitability: N / 5 -- higher is more autopilot-suitable;
below the configured floor is human-oriented._

<!-- {marker-prefix}-autopilot-suitability: N -->
```

Binding rules:

- **Authoritative value = the HTML marker**, read prefix-aware via
  `createMarkerRegex(markerPrefix, "autopilot-suitability")` exactly
  as `roadmap-id` / `blocked-by` are. `N` is an integer 1-5. The
  visible line is a human-readable mirror authoring keeps in sync;
  discovery parses only the marker.
- **Authoring marker, not operational marker.** This is body
  content like `roadmap-id`; it must never be added to
  `OPERATIONAL_MARKERS` in `scripts/protocol-helpers.mjs` or
  subjected to F4 minimization.
- **One source of truth.** A score of `1` must agree with
  `status:blocked-by-human`; never publish a contradiction.
- **Advisory, never a gate.** The score only ranks/routes
  candidates. The A4.5 suitability gate and A5 claim safety checks
  still run unchanged on whatever issue is selected; a high score
  never bypasses a gate.
- **Fail-safe on absence.** A missing, non-integer, or
  out-of-range marker means "no score": Discover evaluates the
  issue the normal way and never skips it. Pre-existing issues
  with no score keep flowing.

Backfill is opportunistic: when an existing open issue without a
score footer is next edited by the authoring flow, add one. No
bulk backfill of the existing backlog is required. The claim-state
precondition still applies — never add the footer to the body of an
actively-claimed or open-PR issue; defer it to a follow-up instead.

## Effort hint

Authored issues may also carry an **effort hint** — an author-time
`S | M | L` size estimate, recorded once while context is fresh, that
Discover consumes as a **soft selection tie-breaker** so autopilot tends
to clear small issues first and leave large ones for a fresh session.
Effort is distinct from the autopilot-suitability score: suitability
captures _autonomy_ (can an agent finish unattended), while effort
captures _size_ (a fully-autonomous issue can still be large).

| Hint         | Scope                                                                                             | Uncertainty                                                                                        | Example signals                                                                                     |
| ------------ | ------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| **S** Small  | Touches one module or a small, contained file set                                                 | Little to no open design decision remains once the plan is drafted                                 | One module / a few files; a single reviewable change; little or no review back-and-forth expected   |
| **M** Medium | Touches a helper plus its callers, or one instruction surface together with its mirrors and tests | At most one open design decision remains, resolvable during planning without a separate hold       | A helper plus its callers, or one instruction surface with mirrors and tests                        |
| **L** Large  | Touches a new helper family, or spans a multi-file rewrite across several instruction surfaces    | Two or more open design decisions remain, or one decision whose resolution could reshape the scope | A new helper family, multi-file instruction rewrites, or work that tends to span many review rounds |

**Calibration note.** Observed agent token usage or wall-clock duration
from previously completed issues may be used to sanity-check a chosen
band, but those are calibration observations only, never the unit
itself: model speed shifts release to release, and concurrent agent
runs distort wall-clock comparison. Do not anchor a hint to a specific
token count or duration.

**Mis-scope routing.** An estimate that does not fit even the `L`
row's scope-and-uncertainty definition is a mis-scope smell: the draft
likely bundles multiple intents. Return to
[Decompose and Draft](#2-decompose-and-draft) and split at intent level
instead of publishing one oversized issue labeled `L`.

The hint is recorded as a **footer at the end of the issue body** — a
visible line paired with a hidden, prefix-aware machine marker, beside
the autopilot-suitability footer:

```text
---

_Effort: S | M | L -- author-estimated size; a soft autopilot
selection tie-breaker only._

<!-- {marker-prefix}-effort: S|M|L -->
```

Binding rules:

- **Authoritative value = the HTML marker**, read prefix-aware exactly
  as `autopilot-suitability` is. `S | M | L` is upper-cased on parse.
  The visible line is a human-readable mirror authoring keeps in sync;
  discovery parses only the marker.
- **Authoring marker, not operational marker.** Like
  `autopilot-suitability`, it is body content and must never be added to
  `OPERATIONAL_MARKERS` or subjected to F4 minimization.
- **Soft tie-breaker, never a gate.** Effort only reorders candidates
  **within** a single suitability-score band, after the score and
  optional desync rules and **before** the lowest-issue-number tie-break.
  It never skips, gates, crosses a score band, or bypasses the A4.5/A5
  gates, and a large (`L`) issue stays fully claimable when it is the only
  ready work.
- **Fail-safe on absence.** A missing, non-`S|M|L`, or conflicting
  marker means "no effort hint": it sorts as the neutral middle, as-if
  `M`, per `idd-discover.instructions.md` A4 Step 2. Pre-existing issues
  with no effort footer keep flowing.

Backfill is opportunistic and follows the same claim-state precondition
as the suitability footer.

## Authoring-bucket marker

A newly authored issue in the `needs-decision` or `blocked-by-human`
readiness bucket (see [Readiness buckets](#readiness-buckets)) carries a
hidden, machine-readable **authoring-bucket marker** recording which of
those two axes applies, so `audit-authored-issue.mts` can mechanically
enforce the matching label the same way it already enforces
`status:blocked-by-human` for a suitability score of `1`
(`checkSuitabilityBlockedByHuman`) — see
[Mechanical pre-publish gate](#mechanical-pre-publish-gate)'s
`--expect-bucket` flag for the enforcement path. `ready` and other
buckets omit the marker entirely; so does a legacy body already
published before this marker existed.

```text
<!-- {marker-prefix}-authoring-bucket: needs-decision|blocked-by-human -->
```

Binding rules:

- **Two axes only.** Scoped to the two buckets that require a label
  (`needs-decision`, `blocked-by-human`) — `deferred` and `out-of-scope`
  have none, so they carry no marker.
- **Folds the existing suitability-1 check.** When present, this marker
  decides `suitability-blocked-by-human`'s applicability instead of the
  suitability score: `blocked-by-human` requires
  `status:blocked-by-human` regardless of score; `needs-decision` means
  that check does not apply, even at a suitability score of `1`. Absent
  or malformed, `checkSuitabilityBlockedByHuman` falls back to the
  pre-existing suitability-1-only rule — no backfill onto issues
  published before this marker existed.
- **Authoring marker, not operational marker.** Like
  `autopilot-suitability`, it is body content and must never be added to
  `OPERATIONAL_MARKERS` or subjected to F4 minimization.
- **Fail-safe on absence, except when explicitly expected.** A missing
  or malformed marker means "no bucket": both mechanical checks above
  fall back to their pre-existing behavior. The gate's `--expect-bucket`
  flag is the deliberate exception — passed only for a body newly
  published into that bucket, it turns "no bucket" into a hard failure
  instead (`authoring-bucket-marker-required`).

Backfill is opportunistic and follows the same claim-state precondition
as the suitability footer.

## Upstream-candidate marker

A locally authored issue may additionally carry a hidden
**upstream-candidate marker** recording that its root cause was judged
to be a defect in an `idd-template`-sourced instruction, doc, or
helper itself, not in the current repository. See
[Upstream-candidate escalation](https://github.com/kurone-kito/idd-skill/blob/main/idd-template/.github/instructions/idd-overview-appendix.instructions.md#upstream-candidate-escalation)
for the qualifying criteria; this section documents only the
marker/label pair.

```text
<!-- {marker-prefix}-upstream-candidate: true -->
```

Binding rules:

- **Opt-in, gated.** Produced only when `upstreamEscalation.enabled`
  is `true` in `.github/idd/config.json`; absent or `false` means
  this marker and label are never applied.
- **Paired with a label.** Carries the GitHub label
  `status:upstream-candidate` alongside the marker;
  `audit-authored-issue.mts`'s `upstream-candidate-marker-label` check
  enforces the two agree, gated on the same
  `upstreamEscalation.enabled` toggle.
- **Authoring marker, not operational marker.** Like
  `autopilot-suitability`, it is body content and must never be added
  to `OPERATIONAL_MARKERS` or subjected to F4 minimization.
- **Local-only.** Never a cross-repository write. The marker and label
  exist entirely within the current repository; nothing is ever
  posted upstream by this workflow.

## Authoring hold and release

Issue authoring uses a two-stage contract: drafting and publishing
happen together under an authoring hold; release from that hold is the
only approval boundary.

- **Stage 1 — author-and-publish.** Once a drafted `ready` body passes
  the mechanical `audit-authored-issue` gate (see
  [Mechanical pre-publish gate](#mechanical-pre-publish-gate)) and the
  critique pass, publish it directly under the configured authoring
  label (`issueAuthoring.authoringLabelName`, defaulting to
  `status:authoring`) — no separate user approval of the drafted body
  is required. The label doubles as the draft marker for the held
  issue and the claim-suppression lock that keeps Discover from
  selecting it: held issues ARE the drafts, so in-place edits, roadmap
  relationship wiring, and re-lint of already-published bodies all
  happen under that same lock. If a session is interrupted before the
  set is fully wired, leave the label in place — that keeps Discover from
  selecting the unfinished set, while its owner markers preserve the set
  identity and target membership for a later verified resume.
- **New-issue ownership.** New-issue publication requires a
  capability-checked create-with-label operation that creates the issue with
  the authoring label atomically and carries an exact hidden publication token
  for target, anchor, set, and session. If the target runtime cannot provide
  that operation, stop before creation. Before the create, generate the
  opaque target/anchor IDs and token because issue numbers are not yet known,
  and carry this exact HTML-first body line:

  ```html
  <!-- <marker-prefix>-authoring-publication: target=<opaque-target-id>; anchor=<opaque-anchor-id>; set=<opaque-set-id>; session=<opaque-session-id>; token=<opaque-publication-token> -->
  ```

  The originating Stage 1 hold uses this append-only publication-intent
  record:

  ```html
  <!-- <marker-prefix>-authoring-publication-intent: target=<opaque-target-id>; anchor=<opaque-anchor-id>; set=<opaque-set-id>; session=<opaque-session-id>; token=<opaque-publication-token>; journal=<owner>/<repo>#<number>; issue=<owner>/<repo>#<number>|none; actor=<trusted-marker-actor>; state=<pending|member|cleanup|abandoned> -->
  ```

  Append the visible note below immediately after this HTML comment, joined
  by a single newline (no blank line between them, matching the
  `authoring-owner` marker's own posted shape) — this exact pairing is the
  canonical rendered template `matchCanonicalAuthoringMarkerFamily`
  (`marker-helpers.mts`) matches for the hide-on-supersede step below.
  Historical comments predating this canonical pin may use a different
  separator, note text, or no note at all (#2750); those never
  byte-exact-match the canonical template and are correctly left visible —
  expected fail-closed behavior, not retroactive cleanup:

  ```text
  _Issue-authoring publication-intent record. Do not edit or delete._
  ```

  `issue` is the returned canonical issue identity or `none`. Append
  `state=pending; issue=none` before creation, then append the returned
  identity while it remains `pending`, append `member` only after the owner
  marker is verified, and append `cleanup` before any safe-close mutation.
  Append `abandoned` only after closed/label-absent verification. On resume,
  paginate the hold log and select the latest valid record for the exact token
  tuple; missing, conflicting, or out-of-order records fail closed, while
  `pending` and `cleanup` remain recovery holds.

  `journal` is the durable record location. For an existing set, use the
  verified originating Stage 1 hold; for a standalone set with no existing
  issue or anchor, use the repository-level authoring journal target
  configured at `issueAuthoring.journalIssue` in `.github/idd/config.json`
  (an `owner/repo#number` reference to a pre-existing, durable, comment-only
  issue) -- an unset `issueAuthoring.journalIssue` only blocks a standalone
  set; an existing set with a verified Stage 1 hold needs no journal
  configuration at all. Do not create that journal as part of the same set.
  If the applicable location cannot be resolved -- no verified Stage 1 hold
  for an existing set, or `issueAuthoring.journalIssue` unset or
  unverifiable for a standalone set -- stop with `blocked-by-human` before
  creating any target. On every paginated replay, require `actor` to equal
  the API author and verify that
  actor is a trusted marker login with the required write-level permission or
  configured bot/app trust. An untrusted, malformed, or conflicting
  exact-token record is not valid evidence; fail closed and retain the hold.

  Persist the preallocated target/anchor IDs, exact token, and `state=pending`
  in that journal before issuing the create. After a successful create,
  attach and verify the returned issue identities on that pending record before
  appending the owner marker. If the pre-create hold write cannot be verified,
  do not create; if the post-create identity attachment cannot be verified,
  leave the returned issue held for recovery. Transition to `member` only after
  owner-marker verification or `abandoned` only after verified safe close and
  label removal. On resume, match the exact token and persisted identities; an
  incomplete scan or state mismatch is a recovery hold. Never
  intentionally create an unlabeled issue for the Stage 1 set. If an
  allegedly atomic request unexpectedly
  returns an unlabeled issue, re-fetch its labels, body, current `claimed-by`
  state, and paginated owner-marker log before closing. If a trusted claim or
  marker from another session or set is present, do not close or overwrite
  the exposed issue; report the ownership conflict and stop. If no competing
  claim is present, apply and verify the authoring label as a safe hold before
  closing. Re-fetch the current claim and paginated owner log again after that
  recovery hold is verified and before closing. If either the hold or final
  re-read cannot be verified, leave the issue open and report the recovery
  hold. Immediately after a successfully labeled issue is
  created, append a `mode=acquire` owner marker with the current set ID and a
  new owner token. Re-fetch labels, body, and owner comments before treating
  the issue as a set member. If marker append or verification is uncertain,
  reconcile the returned comment ID and the paginated owner-marker log with
  bounded retries before closing. If a trusted marker is found, retain the
  label and recover or reopen the issue as a set member; otherwise leave the
  label in place, re-fetch labels, body, current `claimed-by` state, and the
  paginated owner-marker log again. If the final read proves no competing claim
  or owner marker, append `state=cleanup` before closing the issue or removing
  its authoring label. Re-fetch and verify closed/label-absent state, then
  append `state=abandoned`; if any disposition or cleanup read is uncertain,
  retain `state=cleanup`, leave the issue held, and report the recovery hold.
- An atomically labeled publication is not set membership until its owner
  marker is verified. Persist each returned target identity in the durable
  originating Stage 1 hold before appending the marker. On resume, reconcile
  recorded identities and only issues carrying this set's exact publication
  token; an incomplete scan or unmarked match is a recovery hold, so never
  infer membership or completion from the shared label alone. If the final
  safe-close read proves no competing claim or marker, append `state=cleanup`
  before closing the issue or removing its authoring label. Re-fetch and verify
  closed/label-absent state, then append `state=abandoned`; otherwise leave the
  identity and label held for recovery.
- **Per-target ownership.** The configured label is a shared
  claim-suppression lock, not a session owner token. Before editing an
  existing issue or roadmap, fetch a fresh snapshot and resolve its complete
  claim state, including trusted forced-handoff successors and activation-nonce
  winners, plus its active `claimed-by` and open-PR state. A trusted
  forced-handoff successor is active even without a new `claimed-by`; any
  active execution is a conflict, so do not establish the authoring hold.
  Apply the label if it is absent, then append a
  hidden owner comment with the resolved marker prefix:

  ```html
  <!-- <marker-prefix>-authoring-owner: target=<owner>/<repo>#<number>; anchor=<owner>/<repo>#<number>; mode=acquire|resume|bootstrap|heartbeat|release|release-guard|release-complete; owner=<opaque-owner-token>; set=<opaque-set-id>; session=<opaque-session-id>; body-sha256=<64-lowercase-hex|none>; snapshot-sha256=<64-lowercase-hex|none>; supersedes=<opaque-owner-token|none> -->
  ```

  _Issue-authoring ownership marker. Do not edit or delete._

  Join the HTML comment and the visible note above by a single newline (no
  blank line between them) -- this exact pairing, for any `mode`, is the
  canonical rendered template `matchCanonicalAuthoringMarkerFamily`
  (`marker-helpers.mts`) matches for the hide-on-supersede step below.
  Historical comments predating this canonical pin may use a blank-line
  separator instead (#2750); those never byte-exact-match the canonical
  template and are correctly left visible -- expected fail-closed behavior,
  not retroactive cleanup.

  The companion uses the same `body-sha256` and `snapshot-sha256` fields as the
  portable owner protocol. Target markers hash the exact UTF-8 body from the
  fresh read immediately before posting; anchor-only `release-guard` uses
  `body-sha256=none`, while anchor-only `release-complete` carries the required
  canonical set snapshot digest. Persist the per-target body digests and
  snapshot inputs in the originating hold and re-fetch/recompute them before
  accepting completion. New markers missing these fields are not valid for a
  new generation; treat legacy markers only as migration input and fail closed
  when the required snapshot cannot be verified.

  Append this HTML-first body with a direct JSON `POST` to the issue-comments
  endpoint; do not rely on `gh issue comment` or `gh api -f body=` for the
  owner marker. Verify the returned comment ID and body after posting, then
  re-fetch the target's active claim and open-PR state again. If execution
  began during acquisition, stop without editing and leave the verified hold
  for explicit recovery.

  Owner tokens are per target: never compare a child target's `owner` value
  literally with the anchor's `owner` value. Every owner-marker log read for a
  target or anchor must use paginated issue-comment retrieval (for example,
  `gh api --paginate` or an API equivalent) and deterministic GitHub comment
  order (`created_at`, then comment ID); never rely on a single API page.

  Resolve the set anchor before appending any target marker. `anchor` records
  the canonical owner/repository/issue identity of that anchor; the anchor's
  own marker uses its `target` as the `anchor`, and every other marker in the
  set repeats the same value. A missing or mismatching `anchor` makes a
  marker invalid for set membership, resume, or release. A legacy marker
  without an anchor cannot resume a multi-target set; when no parent roadmap
  identifies the anchor, stop and bootstrap a fresh explicitly designated
  anchor instead of choosing a different lead implicitly.

  Only a trusted target-repository marker actor makes a marker valid: the
  current authenticated actor after posting and verifying it **and** passing
  a Write/Maintain/Admin permission check, a configured trusted bot or app,
  or an explicitly enabled Write/Maintain/Admin collaborator. Comment-only
  access is insufficient. If permission cannot be verified and no explicit
  bot/app trust applies, ignore and report the marker; syntax alone never
  grants ownership. For `acquire`, `bootstrap`, and `resume`, `owner` is a
  newly generated opaque per-target owner token; `supersedes=none` for
  `acquire` and `bootstrap`, while `resume` names the prior owner token.
  For any owner marker needed by a later session, the author's trust must also
  be re-evaluable from durable policy: `trustedMarkerActors`, a configured
  trusted bot or app, or an explicitly enabled collaborator whose permission
  can be re-read. The current-session actor path is provisional and cannot
  make a historical marker trusted by itself. Without a durable trust source,
  leave the label and hold in place and report recovery; do not treat the
  marker as set membership or ownership evidence.
  For `release`, retain the current owner token in `owner` and set
  `supersedes` to that same current owner token; `supersedes=none` is invalid
  for a release marker. For `heartbeat`, retain the current owner, set, and
  anchor, set `supersedes` to that same owner token, and do not open or close
  a generation; it only renews the current owner's freshness.
  `release-guard` is valid only on the set anchor. It retains the anchor's
  current owner, set, anchor, and session, and sets `supersedes` to that owner
  token. Append and reconcile it after release-marker preflight but before the
  first label removal. It is the Discover-visible guard for a provisional set
  release: it does not close any generation, and it remains active until the
  anchor's durable `release-complete` marker is reconciled.
  `release-complete` is valid only on the set anchor. It retains the
  anchor's current owner, set, anchor, and session, and sets `supersedes`
  to that owner token. Append and verify it only after every target's
  release marker and label removal has been verified. It is the durable
  terminal event for the set: a later reapplication of the authoring label
  must start a fresh set generation rather than resuming the completed set.
  Within an open generation, the first valid acquisition, bootstrap, or
  resume marker by GitHub comment order wins. A
  `resume` marker opens a new generation only for the exact interrupted set
  and matching prior owner token. A `release` marker must match the current
  owner and set, but remains provisional while its set release is in
  progress; an individual label removal never closes that target's
  generation. During the owning set's own Stage 2 (observed 2026-09-09,
  kurone-kito/idd-skill#2791), the heartbeat renewal and the pre-removal
  ownership recheck must treat that set's provisional `mode=release`
  markers and the anchor's `mode=release-guard` as the expected state
  rather than as a competing generation; the acquisition-time rule that
  a target carrying a release marker cannot be re-acquired until that
  release's `release-complete` is found applies to a later session's
  fresh acquisition of the child, not to the releasing set's own
  rechecks or to a resume of the exact interrupted set, which stays
  the established recovery path when `release-complete` is missing;
  the releasing set's own rechecks never change the current winner,
  unlike a valid resume marker for that exact set, which does. Only
  after a fresh re-read verifies every target's release
  marker and label removal and the anchor's `release-complete` marker does
  the set-level release close all target generations, after which a later
  `acquire` starts a new generation. The
  active generation's freshness is the GitHub `created_at`
  of its latest trusted acquisition, bootstrap, resume, or heartbeat marker; a
  resume marker refreshes that clock, and the label event alone never
  supersedes a fresh owner marker. The current generation's winner owns the
  target; any other session must stop without editing and leave the label in
  place. Owner
  comments are append-only and must not be edited or deleted.
- For a new Stage 1 set, generate one opaque set ID and reuse it in every owner
  marker for that set. When resuming an interrupted set, recover and verify
  its persisted set ID from the exact trusted owner markers and reuse it
  instead of generating a replacement. Persist the resolved anchor identity in
  every marker as well. Before resuming, enumerate the anchor's `## Tracks`
  and a repository-wide paginated issue-comment scan scoped to trusted owner
  markers whose exact `anchor` and `set` match; merge the results by comment
  order and block if enumeration is incomplete. These append-only comments
  are the durable set, anchor, and target membership record; a resume may
  include only targets whose valid markers identify that exact set and anchor.
  Never infer set membership or the anchor from the shared label alone.
- A non-anchor target cannot prove that its previous set finished from its
  local owner-marker log alone. Before accepting a fresh `mode=acquire` for a
  child whose prior generation has a `mode=release` or
  `mode=release-guard` marker, follow its exact persisted `anchor` identity
  and fetch that anchor's paginated owner-marker log. Require a trusted
  `mode=release-complete` marker for the exact anchor/set/session generation
  represented by the child's current release marker, including the current
  anchor owner for that release generation; never accept an older or newer
  set's completion. Owner tokens are per target, so do not compare the child
  owner token literally with the anchor owner token. If the completion marker
  is absent, malformed, or cannot be fetched conclusively, treat the prior
  release as interrupted: do not acquire the child as a new set, and instead
  resume that exact set or leave its hold in place. A child log, an absent
  label, or a session-local read is never completion evidence. Once the
  anchor completion is reconciled, the old set is closed and a new acquisition
  may start a new generation.
- Acquire one set anchor before acquiring any other target: when the set has
  a parent roadmap, first publish a valid roadmap shell under the authoring
  hold, with all required roadmap headings/markers and an empty `## Tracks`
  list allowed only until child issue numbers exist; then acquire and verify
  that roadmap as the set anchor. Only after that anchor is verified may the
  session publish and acquire child targets, and it must wire their real
  numbers into `## Tracks` before release. When no parent roadmap exists, use
  the designated lead target as the anchor. The anchor winner serializes
  acquisition for the whole set; no session may publish or acquire children
  independently. Before each child acquisition or resume, append and verify
  a same-owner heartbeat on the anchor (or reuse one per the coalesce rule
  below), re-fetch the anchor's paginated log, and require its current owner
  token, set, anchor, and session. Append the child marker only after that
  validation, then immediately re-fetch both anchor and child and require the
  same anchor ownership; if either read changes, leave the child hold in
  place and stop rather than forming a split set. If any target cannot be
  acquired under that anchor, stop all body and relationship edits, leave
  labels and append-only markers in place, and require an exact verified
  resume of that set rather than allowing a split ownership set.
  After each `acquire`/`resume`/`bootstrap` marker POST, wait the configured
  `claim.verifySettleDelay`, replay the full paginated log, and choose the
  winner by deterministic comment order; an immediate local read never
  authorizes edits. Apply the same settle delay and full paginated replay after
  every heartbeat before it authorizes an edit or label removal.
- **Heartbeat coalescing (`issueAuthoring.heartbeatCoalesceWindow`,
  default `PT2M`, #2768).** Before appending any heartbeat at the three
  sites in this section (the anchor heartbeat above, "Renew before every
  edit" below, and Stage 2's pre-label-removal heartbeat below), first
  replay the target's paginated owner-marker log. Reuse the latest
  trusted marker instead of appending a new one when **all four** hold:
  it is for the same owner, set, and session; its `mode` is `acquire`,
  `bootstrap`, `resume`, or `heartbeat`; its GitHub `created_at` is
  younger than the configured window; and its `body-sha256` equals the
  digest of the body just fetched. Re-fetch and verify the reused marker
  exactly as a freshly posted one would be — only the redundant POST is
  skipped, never the replay or ownership verification. Any other case —
  an older marker, a different owner/set/session, a mode outside that
  list, a changed body digest, or the marker cannot be found
  conclusively — keeps today's append-and-verify path. This window never
  applies to `acquire`, `bootstrap`, `resume`, `release`,
  `release-guard`, or `release-complete` markers; only a `heartbeat`
  append may be skipped.
- **Hide superseded owner/publication-intent markers.** Opportunistic:
  see the mandatory Stage 2 sweep below for the mechanism this contract
  actually relies on. Measured 2026-09-11 across 22 issues published
  after this per-post step first shipped (#2750/#2821): of 95
  expected-hideable `authoring-owner`/`authoring-publication-intent`
  comments, only 3 (about 3%) were actually minimized (#2896). Following
  this step in the moment is correct and still worth doing when
  convenient -- every comment it hides is one the Stage 2 sweep below
  does not have to -- but it is not something this contract can depend
  on by itself: a step invoked 3-9+ times per issue, buried mid-protocol
  with no mechanical enforcement, is too easy to skip under load. Once a
  fresh `authoring-owner` marker (any `mode`, including the first,
  generation-opening `acquire`/`bootstrap`) or `authoring-publication-intent`
  record (any `state`) has been posted and its own POST and re-fetch/verify
  above have both succeeded -- never before, and never interleaved with
  posting -- scan that same target's prior comments (the target issue for
  `authoring-owner`; the journal issue named in the record's own `journal`
  field for `authoring-publication-intent`, which naturally also hides other
  authoring sets' already superseded journal records on that shared journal
  -- intentional, since the journal read path is the same paginated scan and
  is unaffected either way) and minimize (classifier `OUTDATED`) every prior
  comment from a trusted marker actor whose body is a byte-exact match of the
  canonical rendered template for the same marker family.
  `matchCanonicalAuthoringMarkerFamily` (`marker-helpers.mts`, re-exported by
  `protocol-helpers.mts`) implements that check: it parses the candidate,
  re-renders the parsed fields with `renderAuthoringOwnerMarker` /
  `renderAuthoringPublicationIntentMarker`, and requires the result to equal
  the candidate's body exactly. A candidate that deviates from the template
  in any way -- reordered or extra fields, altered spacing, trailing
  content, a different visible note -- is never minimized; leave it visible
  rather than guessing. Skip the just-posted comment itself and any
  candidate whose `isMinimized` is already `true` (idempotent; the minimize
  helper's own probe already enforces this).

  Convert each eligible candidate's REST comment id to its GraphQL node id
  (the paginated comment list already carries it as `node_id` -- no extra
  fetch needed) and call the existing minimize helper -- reuse it rather
  than reimplementing the mutation:

  ```sh
  node scripts/minimize-superseded-markers.mjs --subject-ids <id1,id2,...> \
    --classifier OUTDATED --trusted-marker-logins <trusted-login-1,...> \
    --apply
  ```

  Or, for npx/package-manager profiles, the equivalent
  `idd-minimize-superseded-markers` command.

  **Best-effort, never blocking.** A permission error, an unreadable
  comment list, or an unavailable helper runtime (`instructions-only`
  profile, or Node.js absent) skips this step silently and continues the
  normal marker-posting flow unmodified -- this must never retry-loop or
  fail the authoring flow. Mirrors `docs/idd-comment-minimization.md`'s
  framing: this is UI cleanup only and never replaces the append-only
  audit trail.

  **Scope.** In scope: `authoring-owner` and `authoring-publication-intent`
  only. Out of scope: `authoring-publication` -- a body-line token embedded
  in the newly created issue's own body at creation time, not a comment, so
  there is nothing to minimize -- and every marker family already covered
  by the post-merge F4 cleanup driver (for example `claimed-by`,
  `review-watermark`, `advisory-wait`; see `docs/idd-comment-minimization.md`).
  Do not add `authoring-owner`, `authoring-publication-intent`, or
  `authoring-publication` to `OPERATIONAL_MARKERS`, and do not fold this
  step or the Stage 2 sweep below into the F4 driver: minimization for
  this marker family stays a separate, earlier-lifecycle behavior owned
  by the issue-authoring protocol itself, not the post-merge cleanup
  driver -- whether triggered opportunistically here or mandatorily at
  Stage 2 release.
- **Conflict check before every edit.** Immediately before each body or
  roadmap relationship update, re-fetch both the target and the set anchor
  (the same fresh snapshot serves both roles when the target is the anchor).
  Re-read the target's active `claimed-by` and open-PR state as well; any
  active execution is a conflict, even when the body and label are unchanged.
  Require each target's expected owner token independently, plus the same set,
  anchor, and owning session, and require the expected body/label snapshot on
  the edited target to remain unchanged. An unexpected change, competing owner,
  malformed owner marker, or inability to prove a unique owner on either target
  is a conflict: do not overwrite the target, leave the authoring label in
  place, and record a safe alternative.
  Prefer an atomic acquisition helper when the target runtime provides one;
  otherwise this append-only conflict check is mandatory, including for
  `instructions-only` installs.
- **Renew before every edit.** After that conflict check and immediately
  before the body or relationship mutation, append and verify a trusted
  `mode=heartbeat` marker for the set anchor first (or reuse one per the
  heartbeat-coalescing rule above), then re-fetch and verify its current
  owner, set, anchor, and session. Only after the anchor renewal
  succeeds, append and verify the edited target's heartbeat when it is a
  distinct target (reuse applies here too), then re-fetch both and require
  each target's expected owner token independently, plus the same set,
  anchor, owning session, and expected target snapshot. If either
  heartbeat cannot be posted/reused or verified, or a newer owner appears,
  stop without editing. A heartbeat never starts a new generation and
  never authorizes release.
- A target already held by another set is unavailable. A later session may
  resume only when the invocation identifies the exact interrupted set and
  the hold is past `issueAuthoring.authoringStaleAge`; append a
  `mode=resume` owner marker with a new owner token and `supersedes` value
  matching the prior owner token before repeating the acquisition check. For
  a stale held target with no valid owner marker, append a trusted
  `mode=bootstrap` marker with the current set ID, a new owner token, and
  `supersedes=none`; this starts a new generation and is not evidence of any
  prior set membership. The first valid bootstrap marker wins. Staleness
  alone never authorizes takeover: use the latest trusted generation marker's
  GitHub `created_at` for marked targets, and the label event only for
  legacy-unowned bootstrap. A competing active marker still stops the
  session.
- **Stage 2 — release.** Before removing the authoring label, run a
  release checklist: every child issue is referenced from its parent
  roadmap's `## Tracks` list; no unsubstituted placeholder remains in
  any published body; the `audit-authored-issue` linter (or its manual
  fallback) is green on every published body in the set. Keep the authoring
  label in place until the checklist passes and the user explicitly requests
  release from the authoring hold, except for the narrow auto-release
  exception below. Keep the set anchor held until every other
  target's label removal is verified, and remove the anchor label last. For
  every target, first re-fetch owner comments during release-marker preflight.
  **Mandatory release-time hide-on-supersede sweep (#2896, #2935).** At
  this same point -- before the reuse-or-append decision below, so a
  retried or resumed release (which reuses an existing `release` marker
  and never appends a new one) still runs the sweep every time this
  preflight step is reached -- run the single fetch-driven sweep command
  against the target issue and the journal issue named in this session's
  own records:

  ```sh
  node scripts/sweep-authoring-markers.mjs --issue <target-issue-number> \
    --issue <journal-issue-number> \
    --marker-prefix <resolved-target-prefix> \
    --trusted-marker-logins <trusted-login-1,...> \
    --deadline-ms 300000 --apply || true
  ```

  The trailing `|| true` keeps this step's own non-zero exit (a fetch or
  mutation failure) from aborting an automated `set -e` release script:
  the sweep's exit code exists for a caller that wants to check its
  outcome directly, not to make this attempted-not-blocking step itself
  block release when run inline (#2935 review, round 5, Copilot) --
  read the sweep's own JSON/table report, not its exit status, to see
  whether anything needs a human look.

  The journal setting can itself name a **different** repository (a
  full `owner/repo#number` reference); when it does, pass that shape to
  `--issue` instead of a bare number -- that one `--issue` is fetched
  from its own repository while every bare-number `--issue` in the same
  invocation still uses the current repository (or `--owner`/`--repo`,
  given together or not at all). Or, for
  npx/package-manager profiles, the equivalent
  `idd-sweep-authoring-markers` command. One invocation performs the
  whole sweep that used to be an ~8-step manual procedure (#2935): it
  fetches each `--issue`'s comments via GraphQL (selecting `isMinimized`
  directly -- REST's issue-comments endpoint never carries that field,
  so this command never falls back to REST), classifies every comment
  with `matchCanonicalAuthoringMarkerFamily` (`marker-helpers.mts`,
  unchanged), determines "newest" only among **trusted-actor** matches
  per family (#2896 review, Codex -- an untrusted actor's later
  byte-exact comment must never be mistaken for the live marker to keep,
  since `minimize-superseded-markers.mjs` itself refuses to minimize any
  comment outside `--trusted-marker-logins` regardless of this
  selection, so wrongly treating the untrusted comment as newest would
  instead select the legitimate trusted marker for minimization --
  exactly backwards; mirrors `checkAuthoringMarkerMinimizationBacklog`'s
  own audit-side rule -- the two share one implementation,
  `classifyAuthoringMarkerFamily` in `marker-helpers.mts`, so they cannot
  drift), excludes any candidate already `isMinimized: true`, and
  minimizes (classifier `OUTDATED`) every remaining eligible candidate in
  one mutation pass -- reusing `minimize-superseded-markers.mjs`'s own
  `runMinimize` rather than reimplementing the mutation. `--deadline-ms`
  bounds the WHOLE invocation (every `--issue`'s own GraphQL pagination
  plus the final minimize pass, for example `--deadline-ms 300000` --
  five minutes), guarding against the same degraded-GitHub-API risk a
  large, long-lived shared journal's full history would otherwise pose.

  Attempt this once per target here, and once more on the anchor
  immediately before the release-complete preflight below; this is the
  sweep the contract depends on, but "mandatory" means **attempted**, not
  blocking -- a failed invocation (permission error, an unreadable
  comment list, or an unavailable helper runtime) skips silently and
  never stops release, matching the opportunistic step's own best-effort
  framing. See the **Closing sweep** bullet below for the third sweep
  point this preflight sweep alone does not cover, and for the explicit
  `authoring-marker-minimization-backlog` invocation that makes each
  sweep attempt's outcome a visible, countable signal instead of silence.
  If a valid current-owner/set `mode=release` marker already exists, reuse the
  earliest matching GitHub comment ID; otherwise append one with `supersedes`
  equal to the current owner token, re-fetch to verify it, and record its
  comment ID. Complete that preflight for the whole set before removing any
  label. A retry of an open generation must reuse the recorded or earliest
  matching marker and never append an indistinguishable duplicate. Then, before
  removing any label, append or reuse the anchor-only `mode=release-guard`
  marker and re-fetch the anchor's paginated owner-marker log with bounded
  retries, requiring the exact current owner, set, anchor, session, and marker
  body. If that guard is not found conclusively, leave all labels in place and
  stop. The guard suppresses Discover for the whole set during the provisional
  label-removal window; it does not close the set. Then,
  immediately before each label removal, append and verify the set anchor's
  `mode=heartbeat` first (or reuse one per the heartbeat-coalescing rule
  above), re-fetching it and requiring its current owner, set, anchor, and
  session. Only after that succeeds, append and verify the target
  heartbeat when it is distinct (one marker serves both roles when they
  coincide; reuse applies here too), then re-fetch both and require each
  target's expected owner token independently, plus the shared
  set/anchor/session, recorded release-marker comment, and expected
  label/body snapshot. Remove non-anchor labels one
  target at a time and re-fetch each result. After the final anchor label
  removal is verified, re-fetch every target and verify its current release
  marker, absent label, and expected body snapshot; any drift leaves the set
  open and prevents completion. Immediately before the release-complete
  reuse-or-append decision below, repeat the same mandatory sweep once
  more -- the same `sweep-authoring-markers.mjs` command above, now
  scoped to `--issue <anchor-issue-number> --issue <journal-issue-number>`
  -- covering the anchor's own owner-marker log and the journal's
  publication-intent log -- idempotent with every earlier target's own
  sweep above, since a comment either was already minimized or was not
  yet the newest for its family either way. Then reuse the earliest
  valid current-owner/set/session `mode=release-complete`
  marker on the anchor, or append one and record its returned comment ID.
  Re-fetch that ID and the anchor's paginated owner-marker log with bounded
  retries, requiring the exact current owner, set, anchor, session, and marker
  body. Treat a successful POST or a verification timeout as inconclusive until
  this reconciliation finishes: if the trusted marker is found, keep the
  labels absent and close the set; if a complete fresh read conclusively proves
  that no trusted marker was appended, reapply the authoring label to every
  target and leave the set generations open; if reads remain inconclusive,
  keep the release guard and current labels/state in place, leave the set held,
  and record a recovery hold. Never infer marker absence or roll back from a
  verification timeout. Treat every release marker, heartbeat, label removal,
  and completion marker as provisional: no target generation closes until every
  target's
  release marker and label removal are verified and the durable completion
  marker is reconciled, at which point the set-level release closes all target
  generations together. If any later removal or verification fails, re-fetch
  every target
  already processed, retrying a failed post-removal read with a bounded fresh
  read, restore its authoring label while the current owner/set still matches,
  and verify the restored set state; leave every target generation open and
  stop. If restoration cannot be completed or a newer owner has appeared,
  record a set-level recovery hold and never claim a partial release. Release
  is a human action; nothing in this bundle auto-releases a held issue set,
  except the narrow, marker-scoped exception immediately below.
- **Closing sweep (after Stage 2 closes, #2896 review, Codex; #2935).**
  The two sweep points above run _before_ Stage 2's own later marker
  appends for the same generation -- the per-target `release` marker,
  the pre-label-removal heartbeat each target receives immediately
  before its own label removal, and (on the anchor) `release-guard` and
  `release-complete` itself. None of those markers exist yet when their
  target's preflight sweep runs, so the preflight sweep(s) alone can
  never clear them, and a target's Stage 2 for a given generation runs
  only once -- there is no future preflight sweep that would ever
  revisit them. Once the set-level release actually closes (the
  successful-close branch immediately above: the trusted
  `release-complete` marker is found and every label is confirmed
  absent), attempt the mandatory sweep one more time, in a single
  invocation covering every target's now-final owner-marker log (the
  anchor's included this time, not just its own) and the journal's
  publication-intent log:

  ```sh
  node scripts/sweep-authoring-markers.mjs --issue <target-1> \
    --issue <target-2> ... --issue <anchor-issue-number> \
    --issue <journal-issue-number-or-owner/repo#number> \
    --marker-prefix <resolved-target-prefix> \
    --trusted-marker-logins <trusted-login-1,...> \
    --deadline-ms 300000 --apply || true
  ```

  Same attempted-not-blocking framing (and the same `|| true` reasoning
  above): a failed invocation here does not reopen the set or roll back
  the close already recorded above.

  **Make every sweep attempt's outcome visible.** Immediately after each
  of the three sweep attempts in this section (per-target preflight,
  anchor-before-release-complete, and this closing sweep), run
  `audit-authored-issue.mjs`'s `authoring-marker-minimization-backlog`
  check and note its reported count -- always with `--trusted-marker-logins`
  (or the equivalent `trustedMarkerActors` option on `auditAuthoredIssue()`)
  set to the same trusted actors the sweep itself used, so the check's
  own eligibility rule matches what the sweep could actually clear;
  omitting it makes the count overstate the real backlog by including
  untrusted-authored matches the sweep was never going to touch.
  **Normalize the author field before writing the comments-file JSON**
  (#2896 review, Codex): the paginated GitHub REST/GraphQL response
  this section already fetches exposes a comment's author nested as
  `user.login` (REST) or `author.login` (GraphQL), never as a flat
  `author` string -- write each entry's `--comments-file` /
  `--journal-comments-file` JSON with `author` set to that nested
  login, not passed through unmapped. Skipping this normalization does
  not error: every comment silently loses its author, the trust filter
  above then excludes every candidate as unknown-author, and the count
  falsely reports zero backlog even when the sweep was skipped or
  failed entirely -- the opposite failure mode from omitting
  `--trusted-marker-logins` (that overstates; this understates to
  nothing).
  **Feed it the sweep's own post-mutation result, never the
  pre-mutation snapshot the sweep read.** The minimize mutation applies
  directly to GitHub; it never updates an in-memory or on-disk comment
  snapshot. Before running the check, update the just-fetched snapshot's
  `isMinimized` field to `true` for every candidate the sweep command's
  own report (`sweep-authoring-markers.mjs`'s `items[]`, each entry
  tagged with the family it belongs to and keyed by subject id) lists
  with **either** `status: "applied"` **or**
  `status: "skipped", reason: "already-minimized"` -- the latter fires
  whenever the fetched snapshot's own `isMinimized` was already stale or
  absent for a comment GitHub already considers minimized (for example
  one an earlier sweep or the opportunistic per-post step already
  cleared), and counts exactly the same as a fresh `"applied"` for this
  update: both mean the comment is minimized now, regardless of which
  attempt did it. Missing either status keeps that comment's snapshot
  entry wrongly `isMinimized: false`. Re-fetching the paginated log
  fresh **via GraphQL** (matching the sweep's own fetch above) is an
  acceptable alternative to this snapshot update, not merely a
  fallback -- either one produces the same accurate post-sweep state.
  A REST re-fetch is not a valid alternative here (#2896 review,
  Codex): REST's issue-comments endpoint never carries `isMinimized`
  at all, so a REST re-fetch is exactly as blind to minimization state
  as the stale pre-mutation snapshot this paragraph exists to correct
  -- it produces a different but equally wrong snapshot, not an
  accurate one.
  Skipping both and auditing the unmodified pre-mutation snapshot reports
  every comment the sweep (or a prior one) already minimized as
  still-outstanding backlog, making even a fully successful, fully
  idempotent sweep look like it failed. A nonzero count after this update
  means the
  sweep attempt genuinely did not fully clear the backlog it was
  supposed to (a partial permission failure or a genuine defect) --
  record it, but never block release on it; this is the mechanical
  signal that makes a skipped or partially-failed sweep attempt visible
  instead of silent, the same kind of gap that went unnoticed for weeks
  in the original per-post-only instruction this section replaces
  (measured effectiveness cited above).

  **When the backlog check itself cannot run, record that fact through a
  runtime-independent path (#2896 review, Codex).** The check depends on
  the same paginated comment snapshot and the same helper runtime
  (Node.js) as the sweep it audits, so the one scenario this whole
  mechanism exists to catch -- the sweep silently skipped because the
  helper runtime is unavailable (`instructions-only` profile, or Node.js
  absent), or because the paginated comment fetch itself failed -- is
  exactly the scenario in which the mechanical count also cannot run,
  leaving no signal at all if nothing else is done. When either the
  sweep or the audit could not run for this reason, still post an
  explicit plain-text note through a path that needs no helper runtime
  (a `gh`/HTTP comment on the target, or the session's own live status
  digest) -- for example "hide-on-supersede sweep skipped this cycle:
  helper runtime unavailable" -- naming the reason. This never blocks
  release either; it only ensures a fully-silent skip never happens even
  in the one failure mode the mechanical signal cannot itself cover.
- **Narrow auto-release exception (review-fix-loop-cutoff).** A
  follow-up issue whose body carried the exact marker
  `<!-- <marker-prefix>-authoring-defer-source: review-fix-loop-cutoff -->` at
  Stage 1 publication time — part of the initial `authoring-publication` body
  write, never added by a later edit — may complete the full Stage 2
  sequence above (release-marker preflight, release-guard, heartbeat
  renewal, verified label removal, release-complete reconciliation,
  every other mechanical gate unchanged) without the "user explicitly
  requests release" precondition, immediately after Stage 1 publication
  completes for that issue. The exception is additive, not a
  relaxation: it replaces only that one precondition; it applies only
  to the single target carrying the marker, never to a roadmap anchor
  or a sibling target in the same authoring set that lacks it; and a
  marker added after Stage 1 publication never qualifies a target
  retroactively. **Provenance check (`#2877`):** before honoring this
  exception, the releasing session must recompute the target's current
  body-sha256 from a fresh read and compare it against that same
  target's own `mode=acquire` owner marker's `body-sha256` (hashed from
  the fresh read taken immediately before that marker was posted, so it
  already reflects the published body — see "Per-target ownership"
  above). A mismatch — the body changed since Stage 1 acquire — fails
  closed: the auto-release exception does not apply for that release
  attempt (this does not retroactively fail Stage 1 itself), and the
  target falls back to the ordinary human-release-request precondition.
  Perform this comparison immediately before the label-removal step
  itself, not only once earlier in the sequence -- matching this
  section's existing discipline of re-verifying immediately before
  each removal for owner/set/anchor/session and the expected
  label/body snapshot -- so a body edit landing between an earlier
  check and the actual removal cannot silently bypass this
  precondition. The `authoring-owner-provenance` helper (`node
  scripts/authoring-owner-provenance.mjs --issue <number>`; see
  `docs/idd-helper-scripts.md`) performs and verifies this comparison
  mechanically (`#2891`). This
  exists because
  `idd-review-triage.instructions.md`'s round-count cutoff files this
  exact marker on a follow-up issue during unattended autonomous
  execution, where no human is present to issue a release request —
  left under the ordinary human-gated boundary above, that deferred
  work would sit under the authoring label indefinitely on a fully
  autonomous repository, silently defeating the point of deferring it
  at all (preventive; no observed incident yet). **Roadmap-anchor
  scope (accepted limitation, `#2877`):** the "never to a roadmap
  anchor" exclusion above is permanent, not a gap awaiting a fix — a
  roadmap anchor carrying this marker under `issue-scope: roadmap`
  with orphan discovery disabled still requires the ordinary
  human-gated explicit release request, since this exception's
  single-target design intentionally does not extend to anchor
  release. See `docs/idd-autonomy-contract.md`'s Stage 2 label-removal
  row for the same note in table form. **Sequencing with the
  originating issue (`#2877`):** the round-count cutoff's follow-up
  issue also carries a `Refs #<originating-issue>` line back to the
  deferred work (the D3 follow-up-issue rule in
  `idd-pr-submit.instructions.md`); `discover-readiness-check.mts`
  treats that specific `Refs` reference as a hard blocker — resolved
  the same way an ordinary `Blocked by #<N>` line is — while
  `#<originating-issue>` stays open, a narrow exception to `Refs`
  otherwise being non-blocking everywhere else in this workflow. The
  marked follow-up must carry exactly one `Refs` keyword line naming
  exactly one issue: nothing in body text lets Discover safely tell the
  true origin apart from an unrelated `Refs` citation that also starts
  its own line, or apart from a second number on the same line, so more
  than one line or more than one number fails closed instead of
  guessing.

## Publication boundary

Publishing a drafted `ready` body under the authoring hold does not
need a separate user approval once it passes the mechanical
`audit-authored-issue` gate and the critique pass — see
[Authoring hold and release](#authoring-hold-and-release) above for the
full two-stage contract. Removing the authoring label and starting the
IDD execution loop both require the user's explicit hold-release
request, except the narrow auto-release exception documented in
[Authoring hold and release](#authoring-hold-and-release) above; nothing
else authorizes either.
