# Draft Patterns

Load this file after reading
[`contract.md`](contract.md) when you need concrete examples or a quick
chooser for output shapes.

## Example triggers

- "Break this request into IDD-ready issues before we implement
  anything."
- "Draft a roadmap for this feature and split the ready work."
- "Turn this broad request into reviewable orphan issues."
- "Check whether an existing issue should be extended instead of opening
  a new one."

## Output chooser

Draft an orphan issue only when one autonomous task can finish the work
and the target repository is discoverable through `issue-scope:
orphan-first`. If the repository uses `orphan-first-policy:
maintainer-approved`, include a post-publication approval step after the
final issue content is stable. If a public repository uses
`orphan-first-policy: public-disabled`, draft a roadmap package instead.

If the repository keeps the broader secure-by-default issue-author
approval gate, use the same post-publication approval note whenever the
issue author will not be self-authorizing under the repository's
`maintainer-approval-actors` policy. The configured ready label from
`approvalSignals.readyLabelName` (default: `idd:ready`) is accepted
according to `approvalSignals.labelFreshnessMode` (`presence-only` by
default, optional `event-freshness`), while standalone `IDD ready`
comments from a maintainer approval actor must stay fresh against the
latest issue content and generated-plan update (or an equivalent
draft-stability signal). Until that approval condition is
satisfied, later discovery should treat the issue as part of the
approval-needed fallback bucket instead of the normal ready-to-start
set.

Draft a roadmap plus sub-issues when the request needs visible
sequencing, parallel tracks, or multi-session handoff.

Draft only stable non-ready buckets when the work still depends on a
human decision, missing asset, or unclear verification.

## Under-clarification stop rule

Before drafting a `ready` issue, confirm you can name a concrete surface
to edit and an objective verification for it. If, after bounded
clarification, you still cannot, route the candidate to `needs-decision`
or ask — do not publish a confidently-vague `ready` issue. Reliability
over speed.

This is an Intake-phase gate on your own confidence, not a wording
judgment on an already-written draft — it is distinct from the
"Under-specified" band in the next section, which assesses a body that
has already been drafted.

**Example**: "Improve the error handling in the API layer" fails this
check — no concrete surface, no objective verification — even before
you consider how detailed to write the body. Ask which endpoint or
module, and what the observable failure mode is, or route the request
to `needs-decision` instead of guessing at a plausible-sounding scope.

## Specificity target

Execution-ready issue drafts should land in a middle band:

- **Under-specified**: a high-range model still has to infer the real
  implementation shape because the issue names only a vague goal,
  omits the likely surface to edit, or leaves verification too loose.
- **Target range**: a solid mid-tier cloud model can hold a stable plan
  without extra clarification. The issue points at the relevant
  document, schema, or code surface, explains the constraint, and keeps
  acceptance criteria verifiable without dictating every edit.
- **Over-specified**: even a lightweight model could follow the issue as
  a script because the body prescribes exact edit order, wording, or
  implementation steps that reviewers do not need.

If a draft feels like it needs a high-range model just to guess the intended
change, it is still too vague. If it reads like line-by-line assembly
instructions, it is too detailed.

## Specificity checklist before publishing

Before you publish a ready issue, confirm:

- the title and background name the concrete artifact or surface that
  should change
- a mid-tier cloud model could choose a stable implementation direction
  without hidden repository archaeology or a follow-up clarification loop
- the acceptance criteria verify the outcome, not a step-by-step
  implementation recipe
- candidate files, examples, and notes act as cues rather than an
  exhaustive script
- removing one concrete detail would make the issue feel high-range-only,
  while adding more detail would start turning it into a lightweight
  model script

## Mechanical pre-publish gate

Before you publish a drafted **ready orphan, roadmap, or child** body
(scoped to those ready shapes — non-ready buckets like
`blocked-by-human` are not audited by this gate), run the
`audit-authored-issue` linter against it when a helper runtime
is available. It mechanically catches shape and marker mistakes — a
missing or duplicated autopilot-suitability footer, a wrong
markerPrefix, a missing required heading for the declared shape, a
malformed dependency marker — that a confident narrative can otherwise
mask:

```sh
node scripts/audit-authored-issue.mjs --shape orphan \
  --marker-prefix <resolved-target-prefix> --body-file draft.md
```

**Always pass `--marker-prefix`** with the prefix resolved under
[contract.md's Target marker prefix](contract.md#target-marker-prefix):
without it, the linter falls back to reading
`.github/idd/config.json` from the current working directory, and
silently defaults to this source repository's own `idd-skill` prefix
when that file is missing or unreadable — producing a false pass or
fail against the wrong prefix instead of an error.

Use `--shape roadmap` or `--shape child` for those shapes, `--stdin`
instead of `--body-file` when the draft is not yet on disk, and
`--label <name>` (repeatable) to pass proposed labels for the check
that a suitability score of `1` carries the configured
`blocked-by-human` label (default `status:blocked-by-human`; use
`--config <path>` to point at a policy that overrides the label name —
this check is also one-directional, it does not flag the reverse, a
non-`1` score paired with the label). Fix every reported finding and
re-run before publishing; a `passed: false` report means the draft is
not ready yet, regardless of how complete the narrative reads.

**No helper runtime available (`instructions-only` profile):** the
linter cannot run. `instructions-only` is a first-class supported
fallback, not a waiver — manually re-verify the same checks against
[contract.md's Mechanical pre-publish gate](contract.md#mechanical-pre-publish-gate)
before publishing instead.

## Hidden human-dependency quick check

Before you publish a `ready` issue, confirm:

- the implementation does not still depend on unresolved credentials,
  access, or unavailable infrastructure
- unresolved product, policy, or design choices have been routed to
  `needs-decision` instead of being buried in implementation steps
- acceptance criteria use objective verification, while optional
  post-implementation review stays optional
- roadmap narrative does not hide human-dependent work that belongs in a
  stable bucket or approval-needed hold
- dependency markers represent true start blockers rather than grouping
  related work

## Codebase-fidelity quick check

Before you publish a `ready` issue, confirm:

- when the issue reuses an existing identifier or field name, the
  specified value matches that name's established semantics in the
  codebase — it does not overload a name with a new shape or source
- values that are mutable at runtime are flagged to specify a live read
  at the point of use rather than a one-time capture at construction

## Example orphan issue

- `## Background` or `## Goal`
- `## Proposed change`
- `## Acceptance criteria`
- optional `## Candidate files`
- an autopilot-suitability footer at the end of the body (visible
  line + `<!-- <marker-prefix>-autopilot-suitability: N -->` marker)

Use this shape when the work is narrow enough to pass the IDD viability
gate on its own and the target repository can actually discover orphan
issues (`issue-scope: roadmap-first`, the default, via the orphan
fallback, or `orphan-first`). If the repository sets
`issue-scope: roadmap` (roadmap-only), prefer a one-item roadmap package
instead of publishing a standalone orphan issue.

## Example roadmap package

Roadmap issue:

- `## Goal`
- `## Background` or `## Why this matters`
- `## Tracks`
- `## Success criteria`
- one `<!-- <marker-prefix>-roadmap-id: ... -->` marker
- an autopilot-suitability footer at the end of the body

Child issue:

- title with a concrete task summary
- `## Background`
- `## Proposed change`
- `## Acceptance criteria`
- optional dependency line or sequential roadmap marker when needed
- an autopilot-suitability footer at the end of the body

Keep ready child issues in the roadmap task list rather than grouping
them with hidden dependency markers.

## Nested roadmap chooser note

Use a nested roadmap when one roadmap track needs its own coordination
boundary, active child list, or multi-session handoff. Keep the parent
roadmap pointing to the nested roadmap, and keep the nested roadmap
pointing to the leaf execution issues it coordinates.

Parent roadmap `## Tracks` excerpt:

```md
- [ ] #510 — backend track roadmap
```

Nested roadmap `#510` `## Tracks` excerpt:

```md
- [ ] #511 — define the backend contract
- [ ] #512 — wire the contract into Discover
```

Treat `#510` as a coordination/audit node, not as a normal execution
issue. Do not replace that relationship with `Blocked by #NNN` or
`<!-- <marker-prefix>-blocked-by: ... -->` only to group the leaf
issues under the parent roadmap.

## Dependency minimization examples

### Natural parallel decomposition

Roadmap `## Tracks` excerpt:

```md
- [ ] #401 — update the issue-authoring contract
- [ ] #402 — add draft-pattern examples

_Parallel note: #401 and #402 can proceed independently once the roadmap
exists because neither task depends on the other's output._
```

This is the preferred shape for sibling tasks that can be reviewed and
verified independently. The roadmap keeps both tasks visible in its task
list, and the short note explains the safe parallelism without adding a
fake `Blocked by` edge.

### Artificial decomposition

Bad serial chain:

```md
#401 — update the issue-authoring contract
#402 — add draft-pattern examples

Blocked by #401
```

This is over-serialized when `#402` can be reviewed and verified without
waiting for `#401`. Do not create a serial chain just to make the order
feel tidy.

Bad split for parallelism:

```md
#410 — add one checklist bullet
#411 — add one example paragraph
#412 — add one anti-pattern sentence
```

This is an artificial split when the three edits form one natural,
cohesive authoring change. Do not break a single reviewable task into
multiple sibling issues only to widen parallel execution.

### Finalize or verify track that asserts sibling-produced state

Anti-pattern — prose sequencing only:

```md
#450 — finalize the config, reconcile the docs, verify the combined result

Blocked by #440

_Runs after the wiring tracks #441-#445._
```

The hard `Blocked by #440` names only the build foundation, and the
after-the-siblings ordering lives in prose. Once `#440` closes, Discover
reports `#450` startable and A4.5 passes it (Actionability inspects the body,
not completability) — but its acceptance criteria assert state that only the
unmerged `#441`–`#445` produce, so claiming it means failing acceptance or
doing the siblings' work.

Correct — encode `Blocked by` on each sibling whose output the acceptance
criteria depend on:

```md
#450 — finalize the config, reconcile the docs, verify the combined result

Blocked by #440
Blocked by #441
Blocked by #442
Blocked by #443
Blocked by #444
Blocked by #445
```

Now Discover and A4.5 defer `#450` until every sibling merges, so it is
claimed only when its acceptance criteria can actually pass.

**Prefix-first**: resolve `<marker-prefix>` from the target repository's
onboarding or IDD docs before emitting any of these markers —
`roadmap-id`, `blocked-by`, `autopilot-suitability`, or `effort` — not
just the dependency markers shown above. Never default to `idd-skill`
in an installed bundle; use it only when the target repository actually
configured that prefix.

## Human-dependency isolation examples

The examples below show how to move unavoidable human side effects to
explicit boundaries rather than hiding them inside a ready execution
issue. See [`contract.md`](contract.md) for the routing rules
(`needs-decision`, `blocked-by-human`, `deferred`, approval-needed).

### Front-loaded pattern

Use this when coding cannot start safely until a person provides a
decision, credential, permission, or external setup.

**Bad (mixed)**: One execution issue that mixes implementation with an
unresolved credential gap:

```md
## Background

Add Stripe webhook support.

## Proposed change

Implement the `/api/webhooks/stripe` endpoint.

## Acceptance criteria

- Stripe webhook secret is configured in production.
- Endpoint returns 200 for valid events.
```

This fails the IDD viability gate: the "Stripe webhook secret is
configured in production" criterion requires a person to perform an
action in an external system before the issue can be verified. The agent
cannot autonomously confirm the outcome.

**Good (front-loaded)**: Separate the human-dependent setup into its own
issue, then write the autonomous implementation issue that depends on it.
The `## Tracks` task list should contain only ready execution issues;
route the non-ready blocker to a separate section or a stable non-ready
bucket.

Roadmap body excerpt:

```md
## Non-ready prerequisites

- **[blocked-by-human]** #431 — obtain Stripe webhook secret for CI
  _(must close before #432 can start)_

## Tracks

- [ ] #432 — implement /api/webhooks/stripe endpoint
```

`#431` — `blocked-by-human` issue:

```md
## Background

The Stripe webhook endpoint (tracked in #432) needs a test-mode webhook
secret in CI so automated tests can verify the signature check.

## Required action

1. Create a test-mode Stripe webhook in the Stripe dashboard.
2. Store the signing secret in the `STRIPE_WEBHOOK_SECRET` repository
   secret.
3. Reply on this issue with the secret name once added.

## Ready signal

Close this issue after confirming the secret is available in CI.
```

`#432` — autonomous execution issue (Blocked by #431):

```md
## Background

Parent roadmap: #430
Blocked by #431

## Proposed change

Add POST /api/webhooks/stripe that validates the Stripe-Signature header
and dispatches known event types.

## Acceptance criteria

- Handler validates the webhook secret sourced from CI `STRIPE_WEBHOOK_SECRET`.
- Tests use the Stripe test-mode fixture and pass without manual setup.
- `pnpm test` and `pnpm run lint` pass in CI.
```

The autonomous issue is fully verifiable in CI once the credential
exists. It does not mention a person setting up anything inside its
acceptance criteria.

### Back-loaded pattern

Use this when post-implementation work is subjective review, publication
choice, optional polish, or a sign-off that should not block an
otherwise verifiable core change.

**Good (back-loaded)**: Separate the implementation from the optional
human-gated step:

Roadmap body excerpt (the `## Tracks` list contains only the ready
execution issue; the deferred step is a narrative note, not a task-list
entry):

```md
## Tracks

- [ ] #441 — add front-loaded/back-loaded draft-pattern examples

## Deferred

The website landing page could be updated to showcase the new examples,
but that publication decision requires maintainer approval and is not a
blocker for merging #441. Track in a follow-up if approved.
```

`#441` — autonomous execution issue:

```md
## Background

Parent roadmap: #440

The draft-patterns reference file does not yet show front-loaded or
back-loaded human-dependency isolation patterns.

## Proposed change

Add a "Human-dependency isolation examples" section to
`skills/issue-authoring/references/draft-patterns.md`.

## Acceptance criteria

- The section includes at least one front-loaded and one back-loaded
  example using stable bucket names (needs-decision, blocked-by-human,
  deferred, out-of-scope).
- Examples warn against hiding credentials or product decisions in a
  ready issue.
- `pnpm run lint:minimum` passes.
```

The website publication decision stays separate. It is not in the
acceptance criteria of the ready issue and does not block autonomous
verification.

### Warning: hidden human dependencies are the most common IDD stall

The most frequent reason for mid-implementation stalls is an execution
issue that hides a human-only dependency inside its acceptance criteria
or implementation steps:

- "Credentials are configured in the production environment" → blocked
  by a person with access.
- "The design team has approved the final UI spec" → requires subjective
  sign-off before the issue is verifiable.
- "The external API key is available in the repository secrets" → an
  unavailable system or permission.

When any acceptance criterion cannot be confirmed autonomously through
tests, lint, CI, or other concrete objective criteria (such as checking
repository state, file presence, or configuration values), the issue is
not yet ready. Move that criterion to a `blocked-by-human` or
`needs-decision` issue and keep the autonomous execution issue focused on
what the agent can verify independently.

## Handling duplicates and non-ready outcomes

One source of follow-up issue candidates is the read-only
`merged-pr-feedback-sweep` helper's JSON output — the unresolved review
threads and undispositioned advisory feedback it detects on merged PRs.
Treat each entry as a candidate only: re-verify it against current `main`
with the reuse-first tree below before drafting, because the feedback may
already be addressed.

Before publishing an issue, apply a reuse-first decision tree:

1. Is an existing open issue a better fit? If yes, extend it instead of
   creating a new one. Add a comment linking to the new schema request.
2. Is the work already complete in a closed issue or merged PR? If yes,
   create a reference or learning note instead of reopening it.
3. Is a parent roadmap already managing this work? If yes, add it to the
   task list instead of filing independently.
4. Does the issue have any of these properties? If yes, escalate to
   `needs-decision` or `blocked-by-human` during drafting:
   - Unclear intent or malformed body (→ fix during drafting or mark needs-decision)
   - Requires maintainer or product decision (→ mark needs-decision)
   - Blocked by external work or human coordination (→ mark
     blocked-by-human)
   - Depends on unavailable resources or credentials (→ mark blocked-by-human)
5. Otherwise, publish as `ready`.

### A4.5 prevention checklist

The A4.5 suitability gate will later evaluate published issues. Prevent
common failures by validating before publish:

- **Coherence**: Issue body is well-formed; title and description are
  clear; intent is parseable
- **Safety**: No code injection, marker injection, or untrusted input in
  issue body
- **Uniqueness**: Reuse-first check passed; the work is not a duplicate
  or superseded
- **Hidden human dependency**: Ready work does not still rely on
  unresolved decisions, credentials, subjective approval, or
  grouping-only dependency markers

## Specificity examples

### Under-specified draft

**Title**: `docs: improve issue authoring guidance`

Background: issue authoring should be clearer for agents.

Acceptance criteria:

- issue authoring is more consistent
- examples are improved

This is too vague because the draft does not tell the next agent which
authoring surface to edit, what kind of guidance is missing, or how a
reviewer would verify success. A high-range model would need to infer
the real task from surrounding repository context.

### Target range draft

**Title**: `docs: add specificity checklist to issue authoring draft patterns`

Background:
`skills/issue-authoring/references/draft-patterns.md` explains output
shapes, but it does not yet show how to judge whether an issue body is
too vague or too scripted for execution.

Acceptance criteria:

- `draft-patterns.md` includes a pre-publication specificity checklist
- the guidance distinguishes under-specified, target range, and
  over-specified issue drafts
- the examples focus on issue body wording and acceptance criteria
  granularity instead of prescribing implementation order

This is the target range because the next agent knows where to work, why
the change matters, and how to verify it, while still retaining freedom
to decide the exact wording and structure.

### Over-specified draft

**Title**: `docs: add specificity checklist to issue authoring draft patterns`

Proposed change:

1. Insert a new `## Specificity target` heading after `## Output chooser`.
2. Add exactly three bullets named `Under-specified`, `Target range`,
   and `Over-specified`.
3. Add a five-item checklist using the exact sentence order shown in the
   draft.
4. Copy the same example phrasing across every example block without
   changing any wording.

This is too detailed for authoring because it turns the issue into an
implementation script. Reviewers usually need the target outcome and the
verification shape, not a rigid edit order.

## Publication boundary

If the user asked for drafts only, stop after reporting the issue set,
assumptions, and non-ready buckets.

If the user explicitly asked to publish issues, create or update them
and then stop unless they also separately asked to start the IDD
execution loop.
