# Onboarding Reference — Issue-Mediated Bootstrap

Use this reference alongside `idd-template/ONBOARDING.md` when the
operator wants an audited bootstrap trail instead of the distributed
default direct-import ("theirs-flow") path. This page is the detailed
companion for the pointer subsection between Step 1C and Step 2.

**This mode is opt-in, not a replacement.** The existing direct-import
path (Steps 2, 4, 5, and 6 as already written in
`idd-template/ONBOARDING.md`) remains the default for every adopter who
does not explicitly choose this alternate. A brand-new repository
usually has no configured CI, branch protection, or Copilot review bot
yet, so routing the very first, most fragile action through a full
review-gated PR would add fragility without benefit for solo or simple
adopters.

## When to choose this mode

Theirs-flow accepts the template as a trusted baseline and imports it
with a direct commit — no GitHub issue, no PR-mediated review — then
hands off to the normal claim -> work -> PR -> CI -> merge loop for
everything that follows. Every other change an IDD-run project makes
flows through an issue and a reviewed PR; the bootstrap import itself
is the one exception.

Choose issue-mediated bootstrap instead when the operator wants that
exception closed from day zero — for example, a team whose change-control
policy requires every repository mutation to have a reviewable record, or
an operator who simply prefers not to grant an agent a direct-commit
path even for the first action. Treat this as an explicit operator
choice made alongside the other Step 1B policy decisions (see
[Onboarding Reference — Policy Decisions](policy-decisions.md)), not an
automatic upgrade applied whenever a review bot happens to be available.
If the operator does not state a preference, propose theirs-flow (the
default) and only switch modes on explicit confirmation.

**Prerequisite: the target repository needs a first commit.** GitHub
cannot open a pull request against a repository with no commits at
all — there is no default branch to target yet. A truly empty
repository must get its base commit some other way (for example, an
initial commit unrelated to IDD) before issue-mediated bootstrap's
issue -> branch -> PR flow can run; creating that first commit is
outside this alternate's own scope.

## Drafting the bootstrap issue

Draft the bootstrap issue only after Steps 1A-1C conclude ("the
hearing"): the operator-confirmed placeholder values and the Step 1B
policy decisions must already be settled, because the issue body has to
carry them.

**The issue body must be self-contained.** Unlike a normal IDD issue,
there is no `.github/idd/config.json` yet in the target repository for
an executing session to read those values from — the target repository
is still pre-import. Embed the confirmed values for the placeholders
listed in [Onboarding Reference — Placeholder
Values](placeholders.md) directly in the issue body (the resolved
values themselves, not a reference to where they live), together with
the confirmed Step 1B decisions (merge policy, PR review profile,
review-thread resolution policy, and the rest of the list in
[Onboarding Reference — Policy Decisions](policy-decisions.md)).

**Pin the process reference.** The issue's process section must point
at idd-skill's own canonical `idd-template/ONBOARDING.md` Steps 2
(fetch or copy template files), 4 (replace placeholders), 5 (update
agent entry files), and 6 (verification checklist) — pinned to a
specific released tag or commit SHA, for example:

```text
https://raw.githubusercontent.com/kurone-kito/idd-skill/<tag-or-sha>/idd-template/ONBOARDING.md
```

Never reference the unpinned `/main/` URL for this purpose: an unpinned
reference can drift between when the issue is authored and when it is
executed, so the steps a reviewer approved may not be the steps that
actually ran (preventive; no observed incident yet).

**Pinning the entry-point link alone is not enough.** Step 2's own file
fetch commands carry their own source reference independent of which
`ONBOARDING.md` revision you read them from, and Option A has **two**
independent fetch loops that each need pinning separately:

- the recommended `gh api` loop calls the Contents API
  (`repos/kurone-kito/idd-skill/contents/idd-template/{path}`) with no
  `ref` parameter, so it always resolves the default branch regardless
  of any URL elsewhere in the document — pin it by appending
  `?ref=<tag-or-sha>` to that endpoint;
- the `curl` fallback loop uses a hardcoded `Base URL:`
  (`https://raw.githubusercontent.com/kurone-kito/idd-skill/main/idd-template/`)
  — pin it by replacing `main` with the same `<tag-or-sha>` there.

Option B copies whatever revision is currently checked out in the local
clone — pin it by checking out that exact tag or SHA before running
Option B. Reading a pinned `ONBOARDING.md` does not, by itself, pin any
of these three fetches. In the issue's process section, explicitly
instruct all three substitutions above — otherwise the actual imported
file contents can still drift even though the instructions document
you read were pinned.

**If the confirmed helper runtime profile is `vendored-node`**, its
profile-conditional helper bundle needs more than a pin. The
single-file direct download in upstream's
[Profile-conditional helper files](https://github.com/kurone-kito/idd-skill/blob/main/idd-template/docs/onboarding/template-distribution.md#profile-conditional-helper-files-vendored-node)
section (not carried into this repository's own copy of
`template-distribution.md`, which does not use `vendored-node`) supplies
only `minimize-superseded-markers.mjs`, not the complete `vendored-node`
bundle — per that section, getting every file the profile requires
needs a full `idd-skill` clone (not just the `idd-template/` subtree),
checked out at the same `<tag-or-sha>`, with this run from it:

```sh
node scripts/idd-onboard.mjs --import \
  --source "$CLONE_DIR" --target "$TARGET_REPO" --profile vendored-node
```

`--import` rejects calls without an explicit `--source`, and since the
natural place to run this command is from inside that same clone,
`--target` also needs to be explicit (its default is the current
directory, which without an explicit value would import into the
clone itself instead of the adopter repository). `$CLONE_DIR` and
`$TARGET_REPO` are shell variables the executor sets at run time, not
angle-bracket author-time fills — keep them as shell variables (never
angle brackets) in the generated issue body, since the issue-authoring
release contract's checklist requires no unsubstituted placeholder
remain before the authoring hold is released
(`skills/issue-authoring/references/contract.md`, "Authoring hold and
release"), and this value has nothing to substitute until the
executor actually runs the command. Direct the issue's process
section to that full-clone path rather than the single-file download,
so this issue's own acceptance criterion below ("every file required
by the selected helper runtime profile") is actually satisfiable.

### The status:authoring hold still applies

The issue-authoring skill's normal authoring-hold/release contract
still governs this draft: while the `status:authoring` label is present,
no session should treat the draft as ready, and removing the label is
what releases it for execution. That contract keeps working pre-import
because the label lives on the GitHub issue itself, not in the
repository tree — it needs no local IDD instructions to be present yet.

### Fill-in bootstrap-issue body template

Use this as the starting shape so an onboarding agent does not have to
improvise a self-contained body from scratch each time. It follows the
issue-authoring skill's orphan-issue schema (`## Background`,
`## Proposed change`, `## Acceptance criteria`, plus the
autopilot-suitability footer). Fill in every bracketed value before
publishing, but not all of them come from the same source: the named
`<value>` fields (repository name, marker prefix, and so on) come from
the Steps 1A-1C hearing; `<tag-or-sha>` is chosen separately, at pin
time, not derived from the hearing itself; and the `vendored-node`
clone/target path placeholders are executor run-time values, not
author-time fills — they apply only when `vendored-node` is the
confirmed helper runtime profile, so delete that entire conditional
sentence and command block when a different profile was selected,
rather than leaving unresolved placeholders or a command that does not
apply behind:

````markdown
## Background

This repository has not yet imported the IDD (Issue-Driven Development)
workflow. The operator chose the issue-mediated bootstrap path over the
direct-import default: this issue is the reviewable record of that
import instead of an unreviewed direct commit.

## Proposed change

Import the IDD template into this repository by following
`idd-template/ONBOARDING.md` Steps 2, 4, 5, and 6, pinned to
[<tag-or-sha>](https://raw.githubusercontent.com/kurone-kito/idd-skill/<tag-or-sha>/idd-template/ONBOARDING.md)
— never the unpinned `/main/` reference. This pin covers the
instructions themselves; also pin the actual file fetch in Step 2, all
three of: append `?ref=<tag-or-sha>` to the `gh api` loop's Contents
API endpoint (the recommended default — it has no `ref` and otherwise
always resolves the default branch regardless of the curl base URL),
use `<tag-or-sha>` (not `main`) in the `curl` fallback's base URL, and
check out `<tag-or-sha>` in the local clone before running Option B. If
the confirmed helper runtime profile is `vendored-node`, its complete
helper bundle needs a full `idd-skill` clone checked out at
`<tag-or-sha>`, with this run from it:

```sh
node scripts/idd-onboard.mjs --import \
  --source "$CLONE_DIR" --target "$TARGET_REPO" --profile vendored-node
```

Both `--source` and an explicit `--target` are required — `--target`
defaults to the current directory, which would import into the clone
itself if left unset while running from inside it. `$CLONE_DIR` and
`$TARGET_REPO` stay shell variables (never angle brackets) in the
published issue body: the release checklist requires no unsubstituted
placeholder remain before the authoring hold is released, and these
have nothing to substitute until the executor runs the command. The
single-file direct download documented in `template-distribution.md`'s
"Profile-conditional helper files" section supplies only
`minimize-superseded-markers.mjs`, not the rest of the profile's
bundle, so it alone does not satisfy this issue's acceptance criterion
below.

Use these operator-confirmed values, already collected during the
hearing (Steps 1A-1C), instead of re-deriving them:

- Repository name: <value>
- Marker prefix: <value>
- Trusted marker actor: <value>
- Fix-validate commands: <value>
- Pre-push-validate commands: <value>
- Post-fix-validate commands: <value>
- Install-deps command: <value>

And these confirmed Step 1B policy decisions — record them per Step 3
alongside the Steps 2/4/5/6 import above, since Step 3 is a local
recording action rather than a pinned remote-fetch step:

- Merge policy: <value>
- PR review policy profile: <value>
- Review-thread resolution policy: <value>
- Critique-loop profile: <value>
- Credential scope: <value>
- Claim-timing defaults: <value>
- CI wait policy defaults: <value>
- Issue-author approval gate: <value>
- Maintainer approval actor policy: <value>
- Issue-authoring companion status (core-bootstrap, temporary): not
  installed (always, regardless of the operator's real choice below —
  see the note below)
- Issue-authoring companion target state (the operator's real Step 1B
  choice, for the companion follow-up issue to read later): <installed,
  native destination `<value>` | not installed>
- Helper runtime profile: <value>
- IDD label names: <value>
- Up-to-date-head ruleset check: <value>
- Bootstrap execution mode: issue-mediated (this issue's own execution
  path)

This is a single, atomically-reviewable change: the core import,
placeholder substitution, and agent-entry-file updates land together,
and Step 6 verification confirms the result before merge. Worktree
guard activation, the `idd-doctor` CI health gate, and the
`idd-advisory-convergence` required-check workflow are explicitly out
of scope here and may follow later as separate issues, at the
operator's discretion, once this one merges. The issue-authoring
companion install follows as its own separate issue **only when the
companion target state above is `installed`** — do not draft a
companion-install follow-up for an operator who chose `not installed`.

Once this issue merges, also draft a welcome/next-steps issue by
default — unlike the optional add-ons above, this one is not left to
the operator's discretion. Give it the same autopilot-suitability
score `1` and confirmed blocked-by-human label this issue carries (it
must stay off the Discover -> Claim -> Work loop too), and derive its
2-3 example next-step prompts from a fresh post-merge
repository-evidence read, not the pre-import dry-run report.

**Record `not installed` here even when the operator wants the
companion — and explicitly defer the matching Step 6 item, not just
the recorded value.** `ONBOARDING.md`'s Step 6 checklist item
("If the operator opted into issue authoring, the companion skill
files are present…") triggers on the operator's **real hearing
decision**, not on whatever this issue's policy field happens to
record — recording `not installed` alone does not make that checklist
item pass for an operator who genuinely opted in, since the files
still won't be there. This issue's own acceptance criteria therefore
explicitly exclude that one Step 6 item when the operator opted in (see
below); do not claim "every Step 6 item passes" in that case without
that carve-out. Once the follow-up issue installs the companion, it
also updates the recorded policy value to `installed`.

Execution for this issue is issue -> branch -> PR -> (a human or a
narrowly-scoped, pre-authorized agent) merge — not the full autonomous
Discover -> Claim -> Work loop. Discover cannot select this issue: no
`.github/instructions/idd-*.instructions.md` or `.github/idd/config.json`
exist in this repository's tree yet to route it. IDD's own CI and
advisory-review checks (`idd-doctor`, `idd-advisory-convergence`) are
not yet configured in this repository at this stage — that is expected,
not a skipped gate. This repository may already have its own CI,
branch protection, or review bot from before choosing IDD; those keep
gating this PR normally and are not affected by this note.

## Acceptance criteria

- Every file listed in `idd-template/ONBOARDING.md` Step 2's core
  `### File list` (plus any file required by the selected helper
  runtime profile) is present in this repository — not the optional
  issue-authoring companion files, which this issue defers (see above).
- No onboarding placeholder strings remain, per Step 4 (outside the
  meta-docs that intentionally keep them literal).
- Root agent entry files exist and reference the IDD workflow, per Step 5.
- Every Step 6 verification checklist item passes, **except** the
  issue-authoring-companion item when the operator opted into the
  companion during the hearing — that one item is intentionally
  deferred to the companion follow-up issue and does not gate this
  issue's completion.
- The confirmed Step 1B policy decisions are recorded in the imported
  repository per Step 3.

---

_Autopilot suitability: 1 / 5 -- higher is more autopilot-suitable;
below the configured floor is human-oriented. This issue is not
Discover-routable before import completes; a human or a
narrowly-scoped, pre-authorized agent executes it directly instead._

<!-- <marker-prefix>-autopilot-suitability: 1 -->
````

Replace `<marker-prefix>` in the marker with the confirmed marker-prefix
value from the hearing before publishing — see the `PROJECT_MARKER_PREFIX`
placeholder in
[Onboarding Reference — Placeholder Values](placeholders.md) for how
that value is derived. The suitability score of `1` reflects that
Discover structurally cannot route this issue pre-import, not a quality
judgment about the change itself; per the issue-authoring skill's
contract, a score of `1` also carries the `status:blocked-by-human`
label, which correctly signals that this issue needs a human or a
narrowly-scoped, pre-authorized agent rather than the ordinary
autonomous loop. Use the operator-confirmed `labels.blockedByHumanLabelName`
value from Step 1B for both issue publication and label creation below —
default to `status:blocked-by-human` only when that default was actually
selected, never unconditionally. A pre-import repository may not have
that label yet — create it first if `gh issue create --label
"<confirmed-label-name>"` fails because the label is missing:
`gh label create "<confirmed-label-name>"`.

## Scope: exactly one issue

Keep the core import as a single issue: the template file copy,
placeholder substitution, and agent-entry-file updates, together with
Step 6 verification, all land as one cohesive, atomically-reviewable
change. A half-imported tree fails `--verify` — for example, agent entry
files that reference an IDD workflow whose instruction files were never
copied — so this work cannot be safely split across multiple issues or
merged in a partial state (preventive; no observed incident yet).

## Optional add-ons stay separate follow-ups

Draft any of the following as separate follow-up issues instead of
folding them into the core bootstrap issue, when the operator wants
them:

- worktree guard activation
- the `idd-doctor` CI health gate
- the `idd-advisory-convergence` required-check workflow
- the issue-authoring companion install — **only** when the operator's
  Step 1B companion decision was `installed`; do not draft this
  follow-up for an operator who chose `not installed`, since there is
  nothing for it to do
- a welcome/next-steps issue — unlike its sibling bullets above, which
  are drafted only on request, draft this one **by default** whenever
  the operator chose issue-mediated bootstrap (details below)

None of these are required for the repository to become
IDD-operational, and unlike the core import, each one can run through
the real Discover -> Claim -> Work loop once the core bootstrap issue
merges — the local IDD instructions and policy files that Discover needs
already exist by then — with one exception: the welcome/next-steps issue
must not run through that loop at all (see below).

**Welcome/next-steps issue, in detail.** Once the core bootstrap issue
merges, draft it automatically — do not wait for a separate request, the
way its four sibling bullets do. The whole premise of choosing the
guided path over theirs-flow is that the operator is less likely to
already know IDD, so gating this one add-on on a separate ask would
defeat the point.

This is also the one add-on that must stay off the Discover -> Claim ->
Work loop entirely, unlike its four sibling bullets above: its whole
body is a reference to read, not something to build, so an autopilot
agent selecting it would attempt to "implement" prose that describes
nothing (preventive; no observed incident yet). Give it the same
autopilot-suitability score `1` and the
operator-confirmed `labels.blockedByHumanLabelName` value the core
bootstrap issue itself carries (Step 1B item 12) — never the
distributed default label name unconditionally.

Draft its body as 2-3 example prompts the operator can literally copy
and try next, phrased as concrete requests mirroring the operator's own
examples ("start issue authoring to implement {inferred gap}", "run the
IDD loop"). Derive `{inferred gap}` and the other prompt content using
the same repository-evidence-read method the optional Dry-run readiness
report already performs
([Dry-run — Readiness assessment](https://github.com/kurone-kito/idd-skill/blob/main/idd-template/ONBOARDING.md#dry-run--readiness-assessment))
— detected package manager, missing prerequisites, and so on — rather
than inventing a new inference mechanism. Run that read **fresh, after
this merge**, not reused from the pre-import dry-run's stored output:
the repository's package manager, test commands, and missing
prerequisites can differ once the bootstrap import lands, and a stale
pre-import finding can prompt the operator to fix a gap the import
already closed. Condition the prompt set on
the recorded Step 1B companion decision: only include an issue-authoring
prompt (e.g. "start issue authoring to implement {inferred gap}") when
that decision was `installed`; for `not installed`, substitute a prompt
that does not depend on the companion skill (e.g. "run the IDD loop" or
a repository-evidence-derived task prompt), so every welcome issue's
prompts are ones the operator can actually run.

## Execution: issue -> branch -> PR -> merge, not the full loop

Executing the bootstrap issue itself is issue -> branch ->
PR -> (a human or a narrowly-scoped, pre-authorized agent) merge —
explicitly not the full autonomous Discover -> Claim -> Work loop:

- **Discover cannot select the issue.** No
  `.github/instructions/idd-*.instructions.md` or
  `.github/idd/config.json` exist in the target repository's tree yet to
  route it — there is nothing for Discover to read.
- **IDD's own CI and advisory-review gates are structurally
  inapplicable at this stage, not silently skipped** — only the
  IDD-specific checks (`idd-doctor`, `idd-advisory-convergence`) have
  nothing to run against yet, since the instruction and config files
  they depend on don't exist pre-import. Name that explicitly in the PR
  description rather than leaving it implicit, so a reviewer does not
  mistake the absence of those specific checks for a skipped gate on an
  otherwise-normal PR. This does **not** extend to any CI, branch
  protection, or review bot the target repository already had before
  choosing IDD — those keep gating the bootstrap PR exactly as they did
  before, and this note is never grounds for disregarding them.

Once this PR merges, the repository is IDD-operational and every
subsequent change — including the optional add-ons above — runs through
the normal claim -> work -> PR -> CI -> merge loop, with the one
exception already noted above: the welcome/next-steps issue is not
executed as code at all. Unlike this bootstrap issue's own
issue -> branch -> PR -> merge execution, the welcome issue has nothing
to implement, so a human (or the same narrowly-scoped, pre-authorized
agent) reads it and closes it directly once acknowledged — no branch,
PR, or merge.
