---
type: workflow
title: IDD workflow guide
description: Routes each agent to its entry file and the phase file matching its current state.
tags: [workflow, phase-routing]
---

# IDD workflow guide

This document is the neutral entry point for the repository's
Issue-Driven Development (IDD) workflow across GitHub Copilot, Codex
CLI, OpenCode, Grok Build, Cursor CLI, Claude Code, and Antigravity CLI
(formerly Gemini CLI).

Use it when you need to answer three questions quickly:

- Which repo entry file should I read first?
- Which IDD instruction files load automatically for my agent?
- When does the workflow rely on GitHub Copilot review state rather than
  on my local CLI?

This guide's `.github/` distribution, tooling, and Copilot-advisory
review steps describe today's only implemented provider, GitHub. IDD
defines a provider-neutral adapter boundary internally as a staged
foundation for future non-GitHub adapters; see
[Provider Portability](customization.md#provider-portability) for the
capability-group model and staged rollout order. Nothing below assumes
that boundary is exercised by a shipped adapter yet.

## Start sequence

If you arrived here from your agent's entry file, pick up at step 2. If
you are reading this guide first, start at step 1.

1. Read the entry file for your agent or surface (see table below).
2. Read `.github/instructions/idd-overview-core.instructions.md`.
3. Read the phase file that matches your current state.
4. If you are editing package-specific code, also follow the matching
   scoped instruction file in `.github/instructions/`.

## Entry points and auto-load expectations

| Agent / surface         | Read first                        | Automatically available IDD context                                                                                                                                                                                                                   | Open manually                                                                                                                                                                                                                       |
| ----------------------- | --------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| GitHub Copilot surfaces | `.github/copilot-instructions.md` | `.github/instructions/idd-overview-core.instructions.md` for execution surfaces; package-scoped `.instructions.md` files in VS Code Copilot when editing matching paths                                                                               | The routed phase file when the current step changes                                                                                                                                                                                 |
| Codex CLI               | `AGENTS.md`                       | None from `.github/instructions/`                                                                                                                                                                                                                     | `.github/instructions/idd-overview-core.instructions.md` and the routed phase file                                                                                                                                                  |
| OpenCode                | `AGENTS.md`                       | `AGENTS.md` itself — OpenCode's native rules mechanism auto-loads it; none from `.github/instructions/`                                                                                                                                               | `.github/instructions/idd-overview-core.instructions.md` and the routed phase file                                                                                                                                                  |
| Grok Build              | `AGENTS.md`                       | `AGENTS.md` and `CLAUDE.md` when both exist (same contract; Grok Build loads every matching filename, unlike OpenCode's first-match); none from `.github/instructions/`                                                                               | `.github/instructions/idd-overview-core.instructions.md` and the routed phase file; see [B1's harness-native worktree tool caveat](../.github/instructions/idd-work.instructions.md#worktree-creation)                              |
| Cursor CLI              | `AGENTS.md`                       | `AGENTS.md` and `CLAUDE.md` when both exist (Cursor always applies `CLAUDE.md`; treat the shared contract as `AGENTS.md`; do not follow Claude-only adapter bullets such as `--vendor claude` outside Claude Code); none from `.github/instructions/` | `.github/instructions/idd-overview-core.instructions.md` and the routed phase file                                                                                                                                                  |
| Claude Code             | `CLAUDE.md`                       | None from `.github/instructions/` by default                                                                                                                                                                                                          | `.github/instructions/idd-overview-core.instructions.md` and the routed phase file; see [B1's harness-native worktree tool caveat](../.github/instructions/idd-work.instructions.md#worktree-creation) before using `EnterWorktree` |
| Antigravity CLI         | `GEMINI.md`                       | None from `.github/instructions/`                                                                                                                                                                                                                     | `.github/instructions/idd-overview-core.instructions.md` and the routed phase file                                                                                                                                                  |

When the `issue-authoring` or `idd-spec-audit` companion bundle is
installed under `.claude/skills/` in a target repository, OpenCode,
Grok Build, and Cursor CLI also discover it there through
`.claude/skills/` compatibility. Do not add checked-in
`.cursor/skills/` or `.agents/skills/` mirrors for those companions
(preventive; no observed incident yet).

During IDD, do not call Grok Build's `enter_plan_mode` (it blocks
non-plan-file edits). Do not switch into Cursor Plan mode / `/plan`
(or SwitchMode Plan) in a way that blocks non-plan-file edits. Do not
let the bundled `review`, `pr-babysit`, or `execute-plan` skills
replace IDD E/F phases or spawn extra worktrees. (Preventive; no
observed incident yet.)

During onboarding, create or update `CLAUDE.md`, `AGENTS.md`, and
`GEMINI.md` so each non-Copilot agent listed above has a stable first
file to read. GitHub Copilot remains an update-if-present surface via
`.github/copilot-instructions.md`. Skipping creation of a missing root
entry file should be an explicit operator choice, not the default.

## Model capability expectations

The workflow above assumes at least a **middle-tier cloud-class**
model for the full Discover → Claim → Work → PR → Review → Merge → F4
loop, reusing the three model-capability classes from the optional
issue-authoring companion's specificity target: **frontier**,
**middle-tier cloud**, and **lightweight local or compact cloud**. (If
your repository installed that companion, its specificity target
documents these three classes in detail; the terminology here stands
on its own otherwise.)

Classify models on **two independent axes**, not context size alone:

1. **Context sufficiency** — can the window hold the entry file,
   `idd-overview-core.instructions.md`, the routed phase file, and tool
   schemas at once?
2. **Self-direction capability** — can the model plan and track a
   multi-turn loop across claim / work / PR / review steps, not merely
   answer one well-specified prompt?

A large context window does **not** imply self-direction. Field
experience has included models that clear a 100K+ context bar yet fail
to drive a multi-step agentic loop without external orchestration.
Likewise, self-direction and **local runtime speed** on the adopter's
hardware are separate considerations: a model that clears both
capability axes can still be impractical if it is too slow on
CPU-only (or other constrained) local hardware. This guide does not
pin a normative tokens-per-second floor; operators should measure on
their own targets.

- **Frontier** and **middle-tier cloud** classes need no additional
  guardrails beyond the rest of this guide; this is the assumed
  default for every phase file above. They are expected to clear both
  axes under normal operator hardware.
- **Lightweight local or compact cloud** (the supported low tier):
  models that have **both** sufficient context **and** demonstrated
  self-direction for contained, fully-specified tasks, but still show
  weak adherence to long multi-file instruction sets (the phi-4-mini
  class — roughly 128K context, tool calling supported — is the
  reference example). Treat "tool calling supported" as a
  runtime-specific claim, not a guarantee: field evidence found that a
  local ONNX serving stack silently degraded structured tool-calls to
  plain text with no error, so a model's stated capability listing tool
  calling does not mean structured tool-calls are reliably available in
  practice — see [Weak-model guardrails](#weak-model-guardrails) for
  the harness-owned mitigation. Confine this tier to narrowly-scoped
  roles under operator supervision:
  - executing a single, fully-specified `idd:ready` issue rather than
    Discover's open-ended candidate selection;
  - preferring a deterministic helper command (see
    [IDD helper script evaluation](idd-helper-scripts.md)) over prose
    judgment wherever one exists for the current step;
  - drafting output for human review rather than running the
    autonomous merge phases.
- **Large-context, non-self-directing** (named out-of-band class):
  models that clear the context-sufficiency bar but cannot reliably
  self-direct a multi-turn execution loop. They are **not** admitted
  into the supported lightweight tier by context size alone. Prefer a
  harness-orchestrated execution mode for this class (the model stays a
  step-level worker; the harness owns phase routing, tool selection,
  and acceptance gates). That path is an open investigation rather than
  a shipped workflow profile — track the corresponding investigation
  issue in the repository that filed it (for example
  [kurone-kito/idd-skill#1555](https://github.com/kurone-kito/idd-skill/issues/1555)
  in the source repository).
- **Unsupported (context floor)**: a model whose context window cannot
  hold the entry file, `idd-overview-core.instructions.md`, the routed
  phase file, and tool schemas at the same time — the
  qwen2.5-coder-1.5b class (roughly 32K context) is the practical
  cutoff example. Below this floor, IDD execution is out of scope; such
  a model can still be a downstream _consumer_ of an artifact this
  workflow produces, just not an IDD execution agent.

### Weak-model guardrails

When a lightweight-tier model runs any part of this loop:

- Prefer a documented helper command over prose interpretation
  wherever [IDD helper script evaluation](idd-helper-scripts.md) lists
  one for the current step **and the repository's helper runtime is
  not the `instructions-only` profile**; treat an expected helper that
  is missing or failing as a stop-and-ask condition, never a silent
  fallback to prose judgment. On the default `instructions-only`
  profile, following the documented Markdown / `gh` / `jq` procedure
  directly is the normal, supported path for this tier too, not a stop
  condition.
- **Weak-tier tool/retrieval contract**: have the harness — not the
  model — own tool execution, query construction, and input-slice
  quality (a clean, column-labeled, minimal slice rather than a raw
  dump), and gate tool/retrieval use on a cheap uncertainty signal (for
  example, self-consistency sampling: sample k responses, treat
  unanimity as sufficient to skip retrieval and disagreement as the
  trigger to search) rather than firing augmentation unconditionally.
  Field evidence found unconditional "always augment on failure"
  net-negative on a weak model (3/7 correct, below a 4/7
  no-augmentation baseline) because retrieval corrupted facts the model
  already knew, while a harness-owned self-consistency gate recovered
  "don't retrieve what you already know" and a harness-owned web search
  took a weak model from 1/4 to 4/4 correct on factual questions.
- Retrieval augmentation is more reliably useful for a QA/spec step —
  two conditions must hold: a knowledge gap exists, and the needed fact
  is in the returned snippet — than for a mid-code-fix step, which
  chains a third condition (the model must also transcribe the fact
  correctly into code). It is not a substitute for fixing logic or
  truncation failures, which retrieval cannot address.
- Narrow the question before adding judges: when a weak model has to
  judge semantic quality, ask a narrow, falsifiable check instead of an
  open-ended review. The failure mode is correlated bias, not
  independent noise, so majority voting does not repair it; keep the
  result advisory, not veto-bearing.
- Parse structured output leniently with a bounded retry: for fixed
  formats, strip common Markdown wrappers, require at least one
  discriminating field, normalize and de-duplicate the results, and
  retry once with a short example before treating the attempt as failed.
  This applies only to weak-model output readers and does not change the
  byte-exact marker verification used for published IDD markers.
- See the upstream IDD repository's lite-profile roadmap/design note
  (`docs/weak-model-lite-profile-design.md`) for the E9-E15
  upstream-triage boundary; the E4 narrow-rubric result is recorded
  there as future nuance, not as a scope change here. This note does not
  change the upstream repository's Copilot advisory-review convergence
  scope decision or the lite-profile exclusion of
  `idd-review-triage.instructions.md`.
- Do not run the autonomous merge phases (F3 onward) on this tier. See
  the merge-policy recommendation for weak-model sessions in
  [Onboarding Reference — Policy Decisions](onboarding/policy-decisions.md#merge-policy).
- This is additional to, not a replacement for, the uniform C-phase
  objective diff validation floor in
  [Critique pass invocation](#critique-pass-invocation): that floor
  exists precisely because judging whether a same-response
  self-critique is truly independent is the kind of fragile runtime
  self-detection a weak model could get wrong, so it applies uniformly
  regardless of declared model tier.
- **Acceptance-check rigor**: any per-unit acceptance check gating
  weak-tier generated output should include multiple boundary cases,
  explicit assertions, and a timeout — the timeout specifically is
  what turns an infinite loop into a caught failure instead of a hang.
  A narrow check (one or two cases) can let a fragile generation with a
  real defect pass undetected.
- **Clean-artifact generation**: a generation prompt driving weak-tier
  output should instruct the model to produce a clean, importable
  artifact — the target definitions and needed imports only — and
  explicitly forbid embedding the acceptance test, assertions, prints,
  or a self-invoking entrypoint block (Python's `__main__` guard, for
  example), and forbid importing the artifact under construction. The
  acceptance check itself — the literal test code, assertions, and
  expected outputs, as distinct from the behavioral acceptance
  criteria described in the prompt —
  must never be shown to the generating model, since a weak model that
  sees the test tends to reproduce it inline rather than keeping the
  two separated.

These tiers are practical operating guidance, not a new enforced
runtime gate: `.github/instructions/idd-suitability.instructions.md`'s
Edge Cases already treat an agent's inability to reliably perform a
check as a PASS (fail-closed only for Check 3, Trust/Safety), so this
section documents an operator-facing expectation rather than a new
A4/A4.5 check.

### Model selection and prompting for the weak tier

Independent field evidence surfaced three predictable model-selection
and prompting mistakes at the weak-local tier that the capability-tier
classification above does not warn against on its own:

- **Loop-stability-versus-single-shot mismatch**: a model's single-shot
  coding pass rate does not predict whether it can hold a multi-turn
  agentic loop without spiraling — the single-shot-coding knee and the
  agentic-loop-stability knee can sit at different model sizes
  entirely. Do not select a model for loop execution on a single-shot
  battery alone. Use a cheap smoke test instead: can the model run N
  turns on a simple task without spiraling? Gate model selection for
  loop execution on that result, not the single-shot score.
- **Reasoning-model spec-drift**: for mechanical, fully-specified,
  single-clause steps, prefer a literal, low-reasoning model over a
  verbose reasoning model — select for obedience, not cleverness, at
  this tier. A reasoning model can "improve" on a literal instruction
  instead of obeying it (for example, returning a different type than
  specified, or renaming a referenced symbol so downstream code
  breaks), while costing substantially more tokens and wall-time than a
  leaner, non-reasoning model that follows the spec literally. More
  reasoning is not automatically a safer default for this kind of step.
- **Full-agent-wrapper degradation**: at the weak tier, prefer a
  direct, minimal-prompt generation path — feeding only the atomic task
  and its acceptance context — over routing the same request through a
  full agent session with its system prompt and instruction stack. The
  added context (system-prompt injection, a large per-turn instruction
  stack) can push a small model past its reliable zone, so the same
  model that succeeds on a direct minimal prompt can fail through the
  full agent wrapper.

These are adopter-facing model-selection and prompting heuristics, not
a new requirement on your repository's own instructions or tooling.

### Lite instruction profile opt-in

The guardrails above assume a session already knows to look for a
condensed instruction bundle, when your repository ships one. This
subsection records how a repository declares that opt-in and how a
session resolves it, so the convention reads as part of the tier
guidance above rather than a parallel mechanism.

**Opt-in signal (recorded convention).** A repository declares its
lite-profile choice with an `.github/idd/config.json` policy field,
`instructionProfile`, following the same repository-local
policy-field pattern as `mergePolicy`, `reviewPolicy`, and the other
fields in
[Repository-local IDD policy](customization.md#repository-local-idd-policy):

- `"standard"` (default; equivalent to the field being absent) —
  every phase uses its standard
  `.github/instructions/idd-*.instructions.md` file, unconditionally.
- `"lite"` — a lightweight-tier session prefers the condensed
  `.github/instructions/lite/idd-*-lite.instructions.md` bundle for
  any phase that has shipped one, and falls back to the standard file
  for every phase that has not (see the mapping and fallback below).

A machine-readable config field, rather than a routing note folded
into `CLAUDE.md` / `AGENTS.md` / `GEMINI.md` prose, follows the
upstream lite-profile design's content principle on mechanical,
fail-closed control surfaces (see `docs/weak-model-lite-profile-design.md`
in the source repository): mechanical, fail-closed control surfaces
carry the safety weight for this tier, not prose judgment. A prose
routing note is itself a cross-file reference a weak-adherence
session could drop — exactly the failure mode the lite profile exists
to route around.

**Recorded convention, not yet wired.** `instructionProfile` is not
yet part of the published policy schema
(<https://kurone-kito.github.io/idd-skill/schemas/policy.schema.json>,
whose root object rejects unknown properties), and no phase file or
the routing table in `idd-overview-core.instructions.md` reads it
today. This subsection records the intended shape for a future change
to add the schema field and the routing read against. **Do not set the
field yet**: if your repository validates `.github/idd/config.json`
against that schema (for example with `idd-doctor` or an equivalent
schema check), adding `instructionProfile` today fails that
validation outright, because the schema's root object rejects unknown
properties — it is not merely inert. Until the schema follow-up
lands, point a lite-tier session at the right files with an explicit
operator instruction, or have it open the phase files below manually.

**Phase → lite file mapping** — the "Lite file" column names the path
a shipped file would use, not a guarantee that your repository has
one: check your own `.github/instructions/lite/` directory before
trusting this table to stay current. A template import may already
include some or all of these files (the upstream IDD repository
dogfoods its own lite-execution-profile roadmap and this table
mirrors its current state), or none, depending on when you imported
and whether your repository has authored any of its own:

| Phase                    | Standard file                         | Lite file                                       |
| ------------------------ | ------------------------------------- | ----------------------------------------------- |
| A5 Claim                 | `idd-claim.instructions.md`           | `lite/idd-claim-lite.instructions.md`           |
| B1-C6 Work               | `idd-work.instructions.md`            | `lite/idd-work-lite.instructions.md`            |
| D1-D4 PR-submit          | `idd-pr-submit.instructions.md`       | `lite/idd-pr-submit-lite.instructions.md`       |
| E1-E3 Review-snapshot    | `idd-review-snapshot.instructions.md` | `lite/idd-review-snapshot-lite.instructions.md` |
| E9-E15 Review-fix        | `idd-review-fix.instructions.md`      | `lite/idd-review-fix-lite.instructions.md`      |
| F1-F2 helper-read subset | `idd-pre-merge.instructions.md`       | `lite/idd-pre-merge-lite.instructions.md`       |
| F2.5 handoff-stop        | `idd-merge-handoff.instructions.md`   | `lite/idd-merge-handoff-lite.instructions.md`   |
| Resume                   | `idd-resume.instructions.md`          | `lite/idd-resume-lite.instructions.md`          |
| Resume-stall             | `idd-resume-stall.instructions.md`    | `lite/idd-resume-stall-lite.instructions.md`    |

The F1-F2 and F2.5 rows cover a **partial** slice of their standard
files only: the lite F1-F2 file covers just F1's read-only branch
check and reading the `pre-merge-readiness` helper verdict, never the
standard file's written prose fallback; the lite F2.5 file covers
just the handoff-stop outcome, never autonomous-merge routing.
Neither falls back to the standard file for its excluded sub-case
within the same phase — both instead treat that sub-case as a
stop-and-ask condition (a broken/missing helper for F1-F2; anything
but the handoff-stop outcome for F2.5).

`idd-ci.instructions.md` and `idd-advisory-wait.instructions.md` are
shared helper files, not phases of their own, so they never appear as
a row in the table above. Each now ships a standalone lite sibling
instead — `lite/idd-ci-lite.instructions.md` and
`lite/idd-advisory-wait-lite.instructions.md` — that a lite caller
references one hop away (content principle 3), rather than restating
every load-bearing rule from the full-size file inline, which is
content principle 1's default for a lite file with no in-scope
sibling to reference. The
advisory-wait lite sibling covers only the **E14-caller subset**: F2's
prose fallback and F3's merge-time call site stay excluded, matching
the split-by-caller scoping for this file recorded in the upstream IDD
repository's lite-profile roadmap/design note
(`docs/weak-model-lite-profile-design.md`, "Phase scoping").

**Explicit fallback.** Every phase without a row above falls back to
its standard instruction file — this is the documented default, not
an implied gap. Some phases lack a lite file because a repository's
own lite-profile track has not shipped one yet even though it is in
scope by design; others are permanently excluded by design — the
open-ended selection, judgment-heavy classification, and autonomous
merge phases (Discover, Suitability, Review-triage, and Merge) stay on
the standard file always, regardless of how much of a repository's
lite-profile work has landed. A lite-opted-in session encountering
either case reads the standard file the same way a standard-tier
session would.

## IDD file map

| File                                                         | Role                                                                                                                                                                                            |
| ------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `.github/instructions/idd-overview-core.instructions.md`     | Shared definitions, command sets, routing table, critique-pass mapping                                                                                                                          |
| `.github/instructions/idd-overview-appendix.instructions.md` | Reference and implementation detail for core: live status digest, abort/hold templates, commit signing, critique-pass detail, and template-sync guidance                                        |
| `.github/instructions/idd-discover.instructions.md`          | A0-T–A4: find a viable issue and classify roadmap vs. leaf nodes during traversal, then hand off to the A4.5 row below                                                                          |
| `.github/instructions/idd-roadmap-audit.instructions.md`     | A1.5: audit roadmap completion, including bottom-up recursive roadmap closure, before A2                                                                                                        |
| `.github/instructions/idd-suitability.instructions.md`       | A4.5: pre-claim suitability triage — filter incoherent, unsafe, duplicated, or out-of-scope candidates before claim                                                                             |
| `.github/instructions/idd-claim.instructions.md`             | A5: run claim pre-checks and claim verification                                                                                                                                                 |
| `.github/instructions/idd-work.instructions.md`              | B1-B3 + C1-C6: create worktree, plan, implement, and self-review                                                                                                                                |
| `.github/instructions/idd-pr-submit.instructions.md`         | D1-D4: rebase, validate, push, open PR, and wait for CI                                                                                                                                         |
| `.github/instructions/idd-ci.instructions.md`                | D4/E15 helper: shared CI polling helper used by later phases                                                                                                                                    |
| `.github/instructions/idd-advisory-wait.instructions.md`     | AW1-AW5 helper: shared Copilot advisory-wait protocol (E14, F2, F3)                                                                                                                             |
| `.github/instructions/idd-review-snapshot.instructions.md`   | E1–E3: fetch activity snapshot, run critique, check if ReviewItems_snapshot is empty                                                                                                            |
| `.github/instructions/idd-review-triage.instructions.md`     | E4–E8: classify items, score, record dispositions, and run E-phase branch-sync check before F-phase                                                                                             |
| `.github/instructions/idd-review-fix.instructions.md`        | E9-E15: fix accepted review items and push follow-up commits (merge-from-`{development-branch}`, not rebase)                                                                                    |
| `.github/instructions/idd-pre-merge.instructions.md`         | F1: final read-only branch-state check; F2: verify all pre-merge conditions                                                                                                                     |
| `.github/instructions/idd-merge-handoff.instructions.md`     | F2.5: resolve merge-policy handoff vs autonomous merge routing                                                                                                                                  |
| `.github/instructions/idd-merge.instructions.md`             | F3–F5: execute the merge, clean up, and loop back to discover                                                                                                                                   |
| `.github/instructions/idd-resume.instructions.md`            | Resume Step 0-3: route crash, stalled, stale-takeover, or clean continuation                                                                                                                    |
| `.github/instructions/idd-resume-stall.instructions.md`      | Resume S1-S5: handle stalled-session recovery with a dedicated safety gate                                                                                                                      |
| `.github/instructions/lite/idd-*-lite.instructions.md`       | Condensed weak-model-tier phase files for phases with a shipped lite bundle; see [Lite instruction profile opt-in](#lite-instruction-profile-opt-in) for the mapping and standard-file fallback |
| `docs/idd-review-policy-profiles.md`                         | PR review policy profiles and customization surfaces                                                                                                                                            |
| `docs/idd-comment-minimization.md`                           | Live status digest contract and post-merge comment minimization policy                                                                                                                          |

## ReviewItems_snapshot lifecycle

`ReviewItems_snapshot` is a session-local collection, scoped to the
current claim, created from E1's activity-universe fetch — not a
literally immutable value a later session may reuse as-is.

| Phase   | Operation                                                                                                   | State     |
| ------- | ----------------------------------------------------------------------------------------------------------- | --------- |
| E1      | Fetch threads/reviews/comments, exclude trusted operational markers, and freeze the current item universe   | created   |
| E2      | Run critique pass and append newly found findings to the same snapshot scope                                | extended  |
| E3      | Evaluate empty/non-empty routing based on the frozen snapshot plus E2 findings                              | evaluated |
| E4-E8   | Classify, score, disposition, and verify each snapshot item (PATH A/PATH B) without redefining the snapshot | triaged   |
| E9-E11  | Fix Accepted PATH A items, validate with a critique pass, and resolve conflicts with `{development-branch}` | actioned  |
| E12     | Lint, test, and push the commit(s) addressing the actioned items                                            | committed |
| E13-E14 | Reply to each snapshot item with its disposition, resolve its thread, and request re-review                 | replied   |
| E15     | CI resolves for the pushed commit(s) and the loop returns to E1, ending this snapshot's role for the round  | complete  |

The name intentionally emphasizes snapshot semantics: E1-E3 builds and
gates on a time-locked view, E4-E8 triages that view, and E9-E15 drives
it to completion, normally within the current session, before the next
E1 fetch supersedes it.

**Cross-session hygiene**: because the snapshot is session-local, a
resumed or forced-handoff session must not inherit a prior session's
`ReviewItems_snapshot`, watermark, or baseline markers as still
authoritative for its own review pass. Rebuild from a fresh E1 fetch
instead, and treat prior-claim operational markers as non-reusable even
when the branch and HEAD are unchanged — see
`idd-resume.instructions.md`'s CI/review routing table and its
forced-handoff recovery note for the authoritative rule.

**Cold entry outside Resume**: `idd-resume.instructions.md` owns
mid-review resume routing -- see its Step 3 table and forced-handoff
note, and `docs/idd-resume-detail.md` §W3/§W5. Where any of those
routes lands a session at E4 or E9 without a `ReviewItems_snapshot`
from its own E1-E3 pass, the cold-start reconstruction section below
applies; reconciling §W3's own dirty-worktree instructions with that
section's stop-and-reconcile rule is a follow-up to
`idd-resume-detail.md` itself, not a gap this section can close by
restating Resume's routing here. The gap this section closes directly
spans two paths:
`idd-overview-core.instructions.md`'s phase-routing entries for
"Snapshot done" / "Review feedback accepted," followed without having
just run E1, and an orchestrator fan-out delegation brief that hands a
worker straight into mid-review (see
[Orchestrator fan-out variant](#orchestrator-fan-out-variant) below).
`idd-review-snapshot.instructions.md`'s cold-start reconstruction
section is the named procedure for both, including the two edge cases
a naive rebuild could get wrong.

## Artifact taxonomy and ownership

This exported template is instruction-template-first. Keep these
ownership boundaries explicit:

- **Live repository instructions**:
  `.github/instructions/*.instructions.md` are the canonical workflow
  rules that drive the execution loop.
- **Agent entry files**: `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, and
  `.github/copilot-instructions.md` tell each agent where to start.
- **Workflow docs**: files under `docs/` explain architecture, policy,
  and onboarding, but should not replace the operational instruction
  files.
- **Native skill bundles**: optional `SKILL.md` bundles may sit beside
  this template in a downstream repository, but they are separate from
  the exported instruction surface and must document their own boundary
  to the execution loop.

Some older project text may still use "skill files" as shorthand, but
these instruction files are not agent-native `SKILL.md` bundles.

The distributed workflow remains an instruction template first. Native
skills can sit beside it as optional helpers, but they do not replace
these execution-layer files.

If you need to understand or change distributed timing defaults, start
with [IDD policy constants](policy-constants.md). It names the claim,
advisory, CI, and critique-loop defaults and points to the instruction
files that own each value.

When helper support is enabled, the discover and suitability phases may
use the helper-backed evidence collectors first, but the Markdown
instruction files remain the final authority whenever helper output is
missing or disagrees.

When an operator gives exactly one issue target, Discover can verify that
target directly before Claim. The shortcut avoids broad roadmap
enumeration, but it still applies targeted readiness checks, the A4
viability gate, and the A4.5 suitability gate before the normal A5 claim
safety checks.

### Completed-draft adversarial review

The Intake critique of an emerging interpretation stays in Intake.
After a roadmap, child, or orphan body is drafted, a separate review
runs before `audit-authored-issue` and before publication. Review a
roadmap shell while `## Tracks` may still be empty, then each child,
then the parent again before saving real child numbers into
`## Tracks`.

The reviewer receives the exact title and body plus only the user's
goal, confirmed constraints and design choices, relevant evidence or
file references, relationship context for a multi-issue set, and the
issue-authoring critique checklist. That checklist checks the confirmed
goal, a concrete surface and objective verification, hidden human
dependencies, true dependency edges, the specificity target range, and
candidate files used as cues. It does not receive the whole
conversation or unbounded work instructions.

Resolve `idd-issue-authoring-delegate` when a helper runtime can run
it. Where that helper is available as a script file, the equivalent is:

```sh
node scripts/idd-issue-authoring-delegate.mjs [--policy <path>] [--no-user-global]
```

The helper does not invoke the command and does not read
`critiqueLoop.delegate`. If the resolver cannot be run, or `usable` is
false, keep the agent-native reviewer or a structured self-critique.
That is not a failed review. When `usable` is true, the modes match the
C/E delegate:

| mode                 | delegate succeeded           | delegate failed              |
| -------------------- | ---------------------------- | ---------------------------- |
| `fallback` (default) | native reviewer does not run | native reviewer runs         |
| `combined`           | both run                     | both run                     |
| `on-success`         | both run                     | native reviewer does not run |
| `never`              | native reviewer does not run | native reviewer does not run |

Union the findings whenever both mechanisms run. After `usable: true`,
a missing command, non-zero exit, timeout, cancellation, or unreadable
findings is a failure. A readable empty list is a clean verdict. If no
mechanism that ran returns a readable list, do not publish: do not
create an issue, update a body, change a label, or append a marker. An
existing held issue keeps its label and previous body. A failure is
never a clean review.

The reviewer must be read-only and returns a findings list only: it must
not create or update issues, change labels, or append markers. That is a
trust-based contract, not an enforced sandbox, because the configured
command runs in the caller's environment as executable configuration.
Prefer a non-context-inheriting reviewer, and use a read-only capability
or sandbox where the harness offers one.
kurone-kito/idd-skill#3448 records the observed risk that a
context-inheriting no-mutation dispatch still publishes. Bound the
delegated command with
`issueAuthoring.adversarialReview.waitCeiling`
(default `PT20M`) through the caller's own wait and cleanup. Do not wrap
the configured command in a timeout utility. The ceiling does not read
`critiqueLoop.subagentWaitCeiling`, and a user-global ceiling is
ignored. Use the same caller-side bound for the native reviewer, so a
hung native pass is not an unbounded substitute. The configured command
is trusted executable configuration and may transmit the supplied draft
and evidence packet. The caller sends the draft to the command on stdin as
one JSON object (`title`, `body`, and a bounded `packet`), described by the
[issue-authoring review input schema][issue-authoring-review-input-schema].
The normative checklist and disposition rule live in the
[issue-authoring skill contract](https://github.com/kurone-kito/idd-skill/blob/main/docs/issue-authoring-skill.md#completed-draft-adversarial-review).

### User-global issue-authoring delegate default

A local runtime may also inherit `issueAuthoring.adversarialReview.delegate`
from the same optional user-global file the critique delegate uses when the
repository leaves the repo-local field genuinely absent. A GitHub-hosted or
other remote agent surface is not meant to consult this layer, but the helper
detects only `GITHUB_ACTIONS=true` on its own; pass `--no-user-global` on any
other remote surface. The file path and the qualified-root rule are the ones in
[User-global critique delegate default](#user-global-critique-delegate-default)
(`$XDG_CONFIG_HOME/idd-skill/config.json`, falling back to
`$HOME/.config/idd-skill/config.json`); a missing, unreadable, invalid-JSON, or
non-object file is treated as absent, and the layer is opt-in.

Resolution order: a repo-local `issueAuthoring.adversarialReview.delegate` (a
configured object, an explicit JSON `null` disable, or a malformed value)
always wins outright and never inherits the global layer, so an explicit
repo-local `null` keeps the native reviewer even when a global delegate exists.
A repo-local `issueAuthoring` or `adversarialReview` that is not an object, or
an `adversarialReview` with a key other than `delegate` and `waitCeiling`, is
malformed in the same way, so a typo cannot inherit a global command. Only when
the repo-local delegate is entirely absent does the global fragment apply;
absent both, the native reviewer or structured self-critique above runs
unchanged. A malformed or explicit-`null` global fragment, including an
`adversarialReview` with an unknown key, is treated the same as a missing one.
`GITHUB_ACTIONS=true` always skips the global layer, and `--no-user-global`
skips it on any other remote surface the caller recognizes (see
[Effective issue-authoring adversarial review delegate](idd-helper-scripts.md#effective-issue-authoring-adversarial-review-delegate)).
This resolver reads only that fragment: it never reads `critiqueLoop.delegate`,
and the critique delegate never reads it.

Example (a generic local draft reviewer, not a specific product):

```json
{
  "issueAuthoring": {
    "adversarialReview": {
      "delegate": { "command": "my-local-draft-reviewer" }
    }
  }
}
```

The optional `mode` takes the same values as the critique delegate and defaults
to `fallback`. `issueAuthoring.adversarialReview.waitCeiling` stays
repository-local (default `PT20M`), so a user-global ceiling is ignored. The
command is trusted executable configuration and may transmit the issue draft it
receives, so neither the user-global nor the repo-local config file should hold
secrets.

## External-signal entry path

The Discover -> Claim -> Work loop above only reads issues already
present in your tracker. A repository fed by an external signal source
(error tracker, alert, support intake) needs a distinct on-ramp into
issue-authoring before that loop ever sees anything.

1. **Triage** (optional, agent-local): classify the incoming signal and
   dedupe it against existing open issues or roadmap nodes before
   drafting anything new. IDD does not define this stage's tooling — a
   webhook receiver, a scheduled poll, or a manual review are all
   equally valid, repository- or agent-specific integrations.
2. **Hand off to issue-authoring**: once a signal survives triage as a
   genuinely new, actionable item, feed its content to the
   `issue-authoring` companion the same way a human-authored idea
   would be if your repository has installed one (see
   [Artifact taxonomy and ownership](#artifact-taxonomy-and-ownership)
   above). The companion produces a normal, schema-conformant IDD
   issue.
3. **Rejoin the normal loop**: the produced issue is claimable by
   Discover like any other issue — nothing about its external origin is
   visible to A0-A5.

Because the triage stage is optional and agent-local, an issue produced
this way must never cite the triage tooling itself as a completion
dependency: its acceptance criteria stay implementable by any agent,
including one lacking that specific integration.

A sibling entry path exists for a signal whose _root cause_ lives in a
different repository (the `idd-skill` distribution itself) rather than
in this one: see
[Upstream-candidate escalation](../.github/instructions/idd-overview-appendix.instructions.md#upstream-candidate-escalation)
in the reference appendix for the qualifying criteria and the local
marker/label convention it produces.

## Issue-author approval contract

Repositories may also keep a secure-by-default issue-author approval
gate ahead of Claim. The distributed discover and claim instructions
already enforce this behavior: explicit-target runs stop before claim
when the selected issue lacks the required approval, and discovery keeps
underprivileged unapproved issues in an approval-needed fallback bucket
instead of treating them as ready to start. Approval actors are a
repository-local policy choice and remain distinct from trusted
operational marker actors; CODEOWNERS mismatch does not replace this
pre-start gate.

## CODEOWNERS and Merge Gates

CODEOWNERS are evaluated after work reaches the pull request, not during
Discover or Claim. They become part of the PR review and merge gates in
E and F phases: review snapshots must report required approval and
CODEOWNER satisfaction, and F2/F3 must prove that unresolved review
state, advisory state, CI, and branch freshness are all current for the
same head.

Autonomous operation therefore requires a satisfiable GitHub merge
topology in addition to a recorded IDD merge policy. If the PR author is
also the only matching CODEOWNER, GitHub's self-approval limit can make
required CODEOWNER review impossible to satisfy. In that topology, IDD
must wait for an eligible non-author reviewer, use a deliberately
configured pull-request-only ruleset bypass for the trusted merge actor,
or stop for a repository policy change.

## Suitability policy handoff

A4.5 outcomes should map to explicit repository policy, not ad hoc
session choices. Keep the mapping in [Customizing IDD](customization.md)
for labels, comment-and-stop defaults, and close boundaries:

- uncertain outcomes (`unclear`, `needs-decision`, `blocked-by-human`)
  stay open by default with a concise routing comment, then A4.5 keeps
  scanning remaining candidates in the same run;
- high-confidence `duplicate`, `invalid`, and `out-of-scope` outcomes
  are read-only by default and require explicit A4.5 mutation-policy
  customization before close/label side effects;
- configured ready-label approval ownership is separate from trusted
  marker actor authority for operational claim/review markers.

## Grooming pass for rejected and below-floor issues (optional)

A4.5 rejections and below-floor autopilot-suitability scores
accumulate into a backlog that ordinary Discover never revisits on its
own. An optional, human-initiated **Groom** phase lets an operator
batch-review that backlog and clear entries whose blocker has become
answerable. This is distinct from durably recording a rejection so it
does not silently resurface (a separate concern, tracked upstream as
[kurone-kito/idd-skill#2243](https://github.com/kurone-kito/idd-skill/issues/2243)
in the source repository) -- grooming is about _reversing_ a rejection
later, once circumstances change.

**Classify before spending operator time.** Sort each candidate into
one of three buckets:

- **execution-blocked** -- no operator input helps; only further agent
  work can resolve it. Leave these for Discover/Claim to pick up
  normally once unblocked.
- **decision-blocked** -- a genuine human call is required (a product
  tradeoff, an ambiguous acceptance criterion, an already-recorded
  policy choice). A bounded question set can resolve these.
- **fact-blocked** -- the rejection cited a fact (a dependency, a
  blocking issue) that may no longer hold.

**Re-check facts before drafting a question.** For a fact-blocked
candidate, check whether any issue or PR the original rejection cited
as a blocker has since closed or merged -- a cached readiness snapshot
can be stale, and a closed blocker is a "free" suitability lever that
costs nothing to re-apply.

**Verify feasibility before drafting a question.** Before drafting a
decision-blocked question, confirm every option it offers is actually
buildable against the codebase's current architecture, with no
undisclosed scope expansion -- a new persistence layer, a new
dependency, or a change to an unrelated component's contract. A
competing-options question can read as complete because every option
sounds coherent in English, while only an implementing session's actual
codebase familiarity reveals that one option needs a capability the
architecture does not have. If an option fails this check, either drop
it from the question or disclose the scope expansion it would require
as part of the question itself, so the operator chooses with the same
information an implementing session would need (field evidence observed
2026-09-10,
[kurone-kito/idd-skill#2805](https://github.com/kurone-kito/idd-skill/issues/2805)
in the source repository).

**Never override a deliberate decision.** When the original rejection
recorded a genuinely deliberate empirical or product decision (not
merely an unanswered question), grooming must never resolve it
unilaterally. Offer "keep the existing decision" as one of the
operator's own answer choices instead.

**Explain before asking.** Give the operator the background and
tradeoffs behind each question before asking it, rather than bundling
several unrelated technical topics into one dense batch.

**Apply the operator's answers back onto the issue**: update the score
footer, remove or update the `triage:{outcome}` label -- and the
configured needs-decision label too, when the hold-and-return rule
below applied it to this same candidate, so Discover's own A3
readiness filter stops excluding it -- revise acceptance criteria to
reflect the decision, and record the
decision as inline prose in the issue body: `Maintainer decision (<provenance>,
Groom hearing, <date>): <resolution text>` -- the shape
`suitability-triage.mjs`'s Check 7 recognizes as a resolved
decision
([kurone-kito/idd-skill#2661](https://github.com/kurone-kito/idd-skill/issues/2661)
in the source repository); a comment may additionally note the
decision, but the body itself is what re-triage reads. This exact line
is also exempt from A4's own `autonomous_completion` gate
(`discover-viability-gate.mjs`,
[kurone-kito/idd-skill#2763](https://github.com/kurone-kito/idd-skill/issues/2763)
in the source repository), so a re-groomed issue is not discarded
before Check 7 ever sees it. The next
ordinary Discover pass then
picks the issue up normally -- grooming itself never claims or works
the issue (see
[Mutation Policy and Coordination Rule](../.github/instructions/idd-suitability.instructions.md#mutation-policy-and-coordination-rule)).

**Hold when a recorded resolution proves infeasible.** The feasibility
check above reduces the risk of drafting an infeasible option, but does
not eliminate it -- the same field evidence (2026-09-10,
[kurone-kito/idd-skill#2805](https://github.com/kurone-kito/idd-skill/issues/2805)
in the source repository) shows infeasibility that only became visible
once an implementing session was deep enough into the codebase to see
it. When a session reaches implementation and finds the Groom-recorded
resolution cannot be built as specified, it must hold the candidate as
decision-blocked again, rather than silently reinterpreting,
downscoping, or unilaterally picking a different resolution: apply the
configured needs-decision label and release the claim, the same
general hold mechanism the shared Hold / suspend rules in
`.github/instructions/idd-overview-appendix.instructions.md` already
document. Record exactly what made the recorded option infeasible in
the hold comment, so the next Groom pass has the information a
corrected question needs. That later pass removes the needs-decision
label as part of applying its own operator's answers back onto the
issue (above), alongside the `triage:{outcome}` label and the score
footer, rather than leaving the label in place indefinitely or
removing it without recording a genuinely buildable replacement.
That replacement must strike through or otherwise replace the
infeasible `Maintainer decision` line rather than merely append beside
it -- re-triage's own `hasResolvedDecision` check treats every unstruck
occurrence as live and has no way to tell which one is current, so an
unstruck infeasible line can keep reading as resolved alongside its
replacement. Removing the label here does not itself trigger the
appendix's usual removal-and-re-claim pairing: like the adjacent
`triage:{outcome}` removal above, the actual re-claim happens through
the next ordinary Discover pass reading the now-label-free issue, not
through the Groom pass itself, which -- as already stated above --
never claims or works the issue.

**Worked example.** An issue was rejected `needs-decision` at score
`2/5` because its acceptance criteria read "add caching, or document
why caching is unsafe here" -- an unresolved subjective call under
A4.5's escape-hatch guidance. Grooming classifies it decision-blocked,
explains the caching-correctness-vs-simplicity tradeoff, and asks the
operator to choose between TTL-based expiry and explicit
invalidation-on-write. After the operator picks TTL-based expiry, the
acceptance criteria are rewritten to "cache reads for up to 60 seconds
via TTL-based expiry; no explicit invalidation path is required", the
score footer is raised to `4/5`, and the `triage:needs-decision` label
is removed after the body records `Maintainer decision (Groom hearing,
2026-06-27): TTL-based expiry, chosen over explicit
invalidation-on-write for simplicity`.

## Roadmap completion audits

Discover owns roadmap-level state. After it finds an open roadmap, it
can audit whether all explicitly referenced child work is complete
before selecting the next issue. Passing audits post a concise evidence
summary and close the roadmap; failing audits either add/link
autonomous follow-up issues or route human-dependent gaps to an explicit
blocked or needs-decision state. Roadmap-level side effects still use a
temporary claim on the roadmap issue itself, so concurrent agents do not
close or edit the same roadmap at the same time.
This roadmap claim is a coordination lock only: child issue claims stay
independent execution locks and can proceed in parallel unless blocked
by their own readiness or dependency rules. Roadmap-level blocker labels
still gate selection as described in Discover.

This audit intentionally lives before A2 rather than in F4. F4 is
limited to the PR that just merged and the local cleanup for that child
issue. F5 then loops back to Discover, where roadmap completion can be
checked with the broader parent context.

## Resume routing model

Resume now starts with a deterministic external-signal classifier before
claim-state branching. The classifier routes each run into one of four
paths: crash recovery, progress-stalled or rate-limit recovery,
stale-claim takeover, or ordinary clean continuation. This keeps crash
and stall handling separate without requiring the stalled session to
publish a final self-report.

## Autopilot operating model

The execution loop is **one issue = one short-lived session**: drive a
single Discover → Claim → Work → PR → Review → Merge → F4 cleanup cycle to
completion, then let the session end. All durable loop state — claims, PRs,
and issue/PR status — lives in the forge (GitHub), not in the agent's
context, so the loop does not need to be carried in one long-lived process:
a thin external runner or scheduler (or a dynamic-paced loop primitive)
re-enters Discover for the next unclaimed issue in a fresh session. This
composes with IDD's existing model — it ships no daemon and relies on an
external scheduler to drive the loop.

### Live-session E/F orientation

When a live session still owns its claim but is unsure what to check next
mid E/F-phase — not after a crash, takeover, or missing review snapshot —
use the existing gates as a navigation aid. The observed navigation failure
is recorded in source issue `kurone-kito/idd-skill#3494` (2026-09-26).
With helper runtime, use the
profile-selected `pre-merge-readiness` invocation documented under
[merge-gate evidence](idd-helper-scripts.md#merge-gate-evidence) for the
current PR, passing `--pr <n> --claim-issue <n>` and current
`--claim-id`, `--agent-id`, and `--nonce` flags when available. Route by its
`ready`/`blockers` verdict and then its `branchCurrency`, `threads`,
`unrepliedComments`, `reviewerStates`, `advisoryWait`, `ci`,
`dispositionEvidence`, `secondaryQuietWindow`, `claim`, and `closingSet`
sections to the existing E-phase or F-phase section that resolves the
blocker. Without helper runtime, use `idd-resume.instructions.md` Step 3's
CI-state × review-state table for the same routing. This is a pointer only:
it changes no phase behavior and creates no new rule.

Treat the **context window as a first-class, exhaustible resource**,
alongside wall-clock time and token budget. A single session that runs
F5 → Discover → … → F5 in-process accumulates every issue's tool output,
diffs, CI logs, and review threads, so each later issue pays a steadily
larger context-re-read cost — a direct cause of mid-run context exhaustion.
The monolithic single-session loop is therefore the **anti-pattern**;
prefer short sessions that exit at the F4/F5 boundary and let the runner
start the next one.

F4-complete / F5 is therefore the recommended **safe session-exit boundary**.
When context pressure hits mid-issue, a session can die mid-flight and leave a
partially-progressed issue (claimed, branch pushed, PR open, or mid-review) for
a later session to untangle. Finishing the current issue to the F4/F5 boundary
and exiting there converts that uncontrolled failure into a controlled handoff —
durable claim and PR state plus the existing resume phase let a fresh session
pick up cleanly at Discover, rather than starting another issue and risking a
mid-loop death.

Mid-review carries a narrower, equivalent boundary, and each point
below shares two conditions: no pending `Awaiting maintainer
decision` item remains, thread or regular comment (E7 permits one to
stay unresolved during triage, so its absence needs a separate check
at exit), and the worktree is clean with no local-ahead commit still
unpushed (the cold-start reconstruction section's edge case 2 pushes
one first, via E10-E12, before any point applies). A session may
deliberately exit after E3 completes with an empty snapshot (E1's
watermark alone is not enough -- E2's critique pass must actually run
first, which Resume's clean/successful-PR route to F2 does not
guarantee), after E8 finds zero Accepted PATH A items, or after a
round completes **both** E13 and E14: the
first point has no dispositions to preserve; the other two leave
every reviewer-visible disposition durable on GitHub. A successor
re-enters through Resume's own routing. E14 belongs in that boundary,
not only E13 — E1 Step 3 excludes a `CHANGES_REQUESTED` review body
only once it has **both** a reply and a re-review request, so exiting
right after E13's replies but before E14 requests review leaves that
body's exclusion condition unmet, and a fresh E1 pass re-surfaces it.
Exiting anywhere between
E4 and a round's completed E14 is not recommended — an Accepted-PATH-A
decision carries no durable marker until E13 posts it (E6 defers that
reply on purpose), and a `CHANGES_REQUESTED` body needs E14's request
too for its own exclusion to hold — so a session forced to exit or
resume there instead relies on the recovery procedure the
[ReviewItems_snapshot lifecycle](#reviewitems_snapshot-lifecycle)
section names.

This boundary covers same-session continuation and orchestrator
fan-out delegation, which already carries the active claim verbatim to
the next worker (see [Orchestrator delegation](../.github/instructions/idd-claim.instructions.md#orchestrator-delegation)).
It does not by itself authorize a genuine cross-session handoff: the
claim stays active and owned until released, so an unrelated session
that simply shows up hits `idd-resume.instructions.md`'s
non-owned-active-claim stop path. A deliberate operator-driven handoff
at this boundary uses [Operator-present release](../.github/instructions/idd-resume.instructions.md#operator-present-release)
instead of a new mechanism.

Short sessions need cheap ramp-up, which the "facts live in docs and
helpers, not in session memory" design already supports: a fresh session
reconstructs what it needs from the instruction files, `.github/idd/`
config, and forge state. This guidance is **advisory** — a recommended
practice with its rationale, not a hard requirement — and
**runner-agnostic**, since this repository ships no runner.

### E/F edge cases from field reports

Three situations from 2026-09-30 field reports have no complete written
answer in the phase files. None changes a gate; each cites its reported
incident.

- **A commit on the PR branch that this session did not write.** A
  maintainer applied Copilot Autofix in the GitHub web UI (committer
  `web-flow`, trailer "Co-authored-by: Copilot Autofix powered by AI")
  on a pull request that had one `github-advanced-security[bot]` thread.
  Reported 2026-09-30 (kurone-kito/idd-skill#3678): the thread ended
  resolved and outdated with no reply, the successor's local branch was
  one commit behind origin, and the `Bash tests (bats)` check was red on
  that commit because the autofix changed a shape a test mock relied on;
  nothing but CI validated the diff. Fetch and fast-forward the local
  branch (a branch behind origin is the benign case), let E1 take the
  moved head (`diffReviewSnapshot` already routes a moved head to E1 as
  `head-changed`), and run the repository's objective validation on that
  diff, because only CI has validated it. A resolved bot thread needs no
  marker-first reply: `classifyReviewThreadForGate` returns `resolved`
  for any resolved thread whoever wrote it, so it does not count toward
  the unresolved-threads gate, and the disposition-evidence gate skips
  it once the E1 watermark on the moved head is newer than its last
  external comment, so that E1 pass, not a reply, is what clears it. The
  fix itself stays unvalidated until CI or E12's lint and test step says
  otherwise. Whether the commit subject follows a convention is adopter
  policy.

- **A pull request that must not close its claimed issue.** Reported
  2026-09-30 (kurone-kito/idd-skill#3678): an acceptance criterion that
  only a later session can check after the merge (a throwaway pull
  request that must show a CI check passing) led an orchestrator to tell
  the worker to write `Refs`, not a closing keyword. The F2 collector
  then had no fitting mode: with `--claim-issue N` the closing set is
  `[N]` and `--closing-issues` must include the claimed issue number,
  while `--claimless` skips claim revalidation, so claim ownership was
  covered only by a gate script the session wrote. Split the issue
  instead, through the `issue-authoring` skill: an implementation issue
  that closes with its pull request and the closing keyword D3 requires,
  and a verification issue that carries the post-merge check. Do not use
  a `Refs`-only body for the claimed issue, and do not use `--claimless`
  to get around the closing set.

- **A closing link that stays empty.** D3.5 already says to wait, and
  not to edit the body, toggle draft, or close and reopen, while the
  pull request is under 4 hours old (by `createdAt`) and its keyword
  matches step 3's regex (kurone-kito/idd-skill#3660). Two adopters'
  reports add what it does not say: across seven pull requests the field
  stayed empty for 1 h 04 min to at least 2 h 24 min and healed without
  action, and the delay is neither a fixed age nor a shared clock time,
  so a session cannot plan the wait. To tell quickly whether the fault
  is platform-wide, sample one unrelated recent pull request that has a
  closing keyword and read its `closingIssuesReferences`: if that is
  also empty, keep waiting. The operator may also add the
  issue-to-pull-request link by hand in the web UI's Development
  sidebar.

### Orchestrator fan-out variant

A long-lived orchestrating session may run Discover and Claim itself and
delegate each claimed issue's B-through-F execution to an isolated
subagent, instead of a thin external runner re-entering a fresh session
per issue. This is an **explicitly supported alternative** to the
one-issue-one-session model above, not a replacement for it — the
monolithic-loop anti-pattern is about a single session accumulating every
issue's diff, CI log, and review-thread noise in its own context, and
the orchestrator avoids exactly that: its own context holds only claim
tokens, branch names, and each worker's final report, while the
per-issue noise stays inside each short-lived worker's own throwaway
context. Cross-issue bookkeeping (the claimed set, a concurrency budget,
one desync token reused across the run) is also cheaper to keep in one
orchestrating session than to reconstruct per invocation of a stateless
external scheduler.

Running this variant safely requires:

- **A non-context-inheriting delegation mechanism for the full
  B-through-F4 worker role, whenever the calling tool offers one — a
  strong preference, not merely a suggestion, per
  [Orchestrator delegation](../.github/instructions/idd-claim.instructions.md#orchestrator-delegation).**
  A context-inheriting worker (one that receives the orchestrator's
  complete conversation, such as Claude Code's `fork` subagent) can let
  the orchestrator's own recent framing compete with, and sometimes
  override, the delegation brief's own role statement — the same
  problem [Critique pass invocation](#critique-pass-invocation) already
  avoids for Claude Code's narrower critique-pass role, since that row
  also picks a fresh `general-purpose` agent rather than a
  context-inheriting one. Extend that same preference to this full
  worker role whenever the tool exposes the choice; a
  context-inheriting mechanism is a fallback only for when no
  non-context-inheriting alternative exists, and even careful brief
  wording (the explicit role-statement text in
  [Orchestrator delegation](../.github/instructions/idd-claim.instructions.md#orchestrator-delegation))
  does not reliably close its residual role-misread risk — a
  documented known limitation.
- **A small concurrency cap**, sized against CI-minute cost,
  shared-file contention, and host capacity rather than raised without
  bound. The optional `discover-shared-file-overlap` helper (see
  [IDD helper script evaluation](idd-helper-scripts.md#discover-shared-file-overlap-contract))
  reports high-contention shared-file overlap evidence to inform both
  the cap and the delegation order. Neither CI-minute cost nor
  shared-file contention reflects host capacity: a worker's own build
  and test children compete for the same cores and memory as every other
  session on the host, so run a cheap preflight before each dispatch.
  Compare the 1-minute load average (`uptime`) with the core count
  (`nproc`, or `sysctl -n hw.ncpu` on macOS), and read the available
  memory (`MemAvailable` in `/proc/meminfo`, or the platform
  equivalent). As starting values an operator may tune — this guide's
  own starting choice, not measured limits — start no new worker while
  the 1-minute load exceeds the core count or the available memory is
  under 2 GiB; dispatch fewer workers or wait instead. In one
  orchestrated private downstream adopter's run (reported 2026-09-30,
  kurone-kito/idd-skill#3677), a delegated worker's tool calls stopped
  returning and the runtime ended it (`Agent stalled: no progress for
  600s`) while the 1-minute load average read 90.87 on 24 cores and no
  memory was available, and full-suite runs failed on timeouts in
  unrelated specs that all passed alone.
- **Full per-issue gating before every delegation.** The orchestrator
  runs the complete A4.5/A5 suitability and claim gates (and the A4
  viability gate that precedes them) for each issue before handing it to
  a worker; claiming several issues concurrently is never a shortcut
  around those gates.
- **A delegation brief that restates the background-wait topology
  warning and the worker's exit boundary.** Each worker's brief must
  carry the
  [wake-up discipline](../.github/instructions/idd-ci.instructions.md#wake-up-discipline)
  topology-safety condition, so a worker never assumes an unconfirmed
  background wait resumes its own turn: the worker must wait
  synchronously or with a confirmed topology-safe wake for any
  backgrounded command, and must not end its turn until that wait has
  a confirmed result (kurone-kito/idd-skill#2221,
  kurone-kito/idd-skill#2624). When the orchestrating session already
  has a same-session sibling worker that stalled this way, the brief
  must cite that sibling failure by name. The brief must also state that
  the worker's B-through-F execution ends at F4-complete: the worker
  reports its final result back to the orchestrator instead of
  independently entering F5's Discover step, so Discover/Claim
  ownership stays with the orchestrator alone.
- **A delegation brief that requires issue-number-namespaced
  scratchpad filenames.** Concurrently delegated workers can share
  the orchestrating session's own scratchpad directory —
  session-scoped rather than subagent-scoped in at least one harness
  (e.g. Claude Code) — so a generic filename (`pr-body.md`,
  `commit-msg.txt`, `plan-draft.md`, etc.) one worker writes under
  its brief can collide with, and be silently overwritten by, a
  sibling worker writing the same name under its own brief. Each
  delegation brief must instruct its worker to prefix every
  scratchpad file it creates with the issue number (for example
  `2878-pr-body.md`), or to create and use an issue-numbered
  scratchpad subdirectory, instead of a generic filename a sibling
  worker might independently produce too under its own brief
  (observed 2026-09-10,
  kurone-kito/idd-skill#2900). This is a separate requirement from
  the background-wait topology-safety condition above — a
  namespacing convention for concurrent scratchpad writes, not a
  wake-up-discipline concern.
- **The delegation brief carries the claim token verbatim, nonce
  included — and the worker actively revalidates it.** The worker
  adopts the orchestrator's already-verified `{agent-id}` / `{claim-id}`
  pair as its own for the run (mirroring forced-handoff adopt-verbatim),
  carrying the orchestrator's current activation nonce rather than
  minting a new one — a minted nonce would collide with the
  orchestrator's for the same `{claim-id}` and flag legitimate
  delegation as a second activation. Before each mutation, the worker
  recomputes the nonce winner and confirms it still matches the carried
  value, the same safety check a self-posting session performs. See
  [Orchestrator delegation](../.github/instructions/idd-claim.instructions.md#orchestrator-delegation).
- **Serialized worktree/clone lifecycle operations when workers share
  one clone.** Concurrent `git fetch` / `git worktree add` / `git
  worktree remove` / local `{development-branch}` updates from the
  same primary clone can collide; serialize these specific operations
  behind the [clone-scoped lock](idd-helper-scripts.md#clone-scoped-lock),
  or give concurrent workers separate clones, once the concurrency cap
  allows more than one worker at a time.
- **Resume-specific recovery when a worker dies mid-turn.** Re-verify
  claim ownership and worktree state before continuing; treat any
  uncommitted work found in the worktree as unverified input to check,
  never as something to trust or silently discard. Also check for a
  stale clone-scoped lock before redelegating -- skip this check under
  `instructions-only` running one worker at a time, which never
  contends for the lock; see
  [Clone-scoped lock](idd-helper-scripts.md#clone-scoped-lock) for that
  profile's own multi-worker-one-clone caveat: run
  `node scripts/clone-lock.mjs --check` (or the profile-selected
  `idd:clone-lock` command with `--check`, per that same section, for
  the literal per-profile invocation) and, if it reports the lock
  present, follow that same section's manual-recovery procedure in
  full -- by design this lock never auto-recovers a stale holder
  (observed 2026-09-01, kurone-kito/idd-skill#2223,
  kurone-kito/idd-skill#2389) -- before delegating a fresh subagent
  with a resume-specific briefing rather than resuming the dead
  worker's own
  context. The exception is a worker the runtime can still message or
  resume (for example by its agent id), such as one it reported stalled
  or ended while its claim and worktree were still intact: resuming that
  same worker with freshly verified facts is an accepted, cheaper path
  than a fresh subagent, provided the orchestrator first verified the
  claim, the worktree, and the child processes the worker still has
  running (for example in the process table). Those children are waited
  for, by PID, and never duplicated by a second copy — a fresh worker
  would start a second heavy run on the same host. On an in-place
  resume, still run the same lock check: a present lock whose
  `holderAlive` is true is expected and is waited for, never removed; a
  present lock whose holder is gone is stale and takes the
  manual-recovery procedure above. A worker that can no longer be
  messaged keeps the fresh-subagent path above. In a downstream
  adopter's run (reported 2026-09-30, kurone-kito/idd-skill#3677), the
  orchestrator verified claim routing, `git log`, the pull request list,
  and the process table, sent one message to the same worker with those
  facts and one instruction (wait for the child by PID, do not start a
  second full run), and the worker continued from its own context and
  reached F2 in about 80 minutes without repeating work.
- **A delegation brief resuming mid-review at E4 or E9 must run the
  cold-start reconstruction.** A fresh worker dispatched straight into
  E4 or E9 without a `ReviewItems_snapshot` from its own E1-E3 pass
  must not assume `ReviewItems_snapshot` still reflects live state —
  see the ReviewItems_snapshot lifecycle section's Cold entry outside
  Resume
  note above and `idd-review-snapshot.instructions.md`'s cold-start
  reconstruction section. This covers only those two named entry
  points; a brief that instead hands a worker into E10, E13, E14, or
  E15 has no supported cold-entry route yet -- stop and report rather
  than improvising one.
- **Independently verify a worker's reported terminal outcome before
  trusting it.** A worker's final-turn text describes what it
  _attempted_, not proof of what actually landed on the forge. Before
  dispatching the next worker or otherwise acting on a reported "merged"
  outcome, confirm live GitHub state directly — for example
  `gh pr view <n> --json state,mergedAt` and
  `gh issue view <n> --json state,closedAt` — rather than trusting the
  worker's own narrative. A runtime's completed notice that says the
  worker still has background work of its own running, or that its
  result may be interim, is not final: check the worktree and the claim,
  and wait for the worker to resume while there is live evidence of the
  background work it reported (a running child process, a background
  task the runtime still lists as running, or new worktree changes),
  restarting the wait on each new piece of evidence; after one runtime
  stall interval (the runtime's own no-progress limit) with none and no
  resume, apply the dangling-state check below. A completed notice with
  no such statement is a real stop: verify its outcome as above. In a
  downstream adopter's run (reported 2026-09-30,
  kurone-kito/idd-skill#3677), one worker ended its turn four times with
  "still waiting on the review delegate; I will continue when it lands"
  while a background task of its own was running, the harness reported
  each stop as completed with an interim note, and each time the worker
  resumed on its own; a fifth notice carried no such note and was a real
  stop, so an orchestrator that read "completed" as final would have
  verified "merged?", found no, and re-delegated.
- **Check for dangling or broken state after an ambiguous worker
  dispatch.** When a worker's turn ends without a clean final report
  (stalled, killed, timed out) — especially if its last visible action
  was a mutating step such as an F3 merge-execution command — check for
  a PR left in a failed-merge-attempt state (e.g.
  `gh pr view <n> --json mergeable,mergeStateStatus`) or an orphaned
  claim before dispatching further workers, rather than assuming success
  or failure either way.

### Discover re-run cadence

Re-running the full Discover enumeration this session established
(`discover-roadmap-graph`, and `discover-orphan-filter` when A0/A0-O
routes there) after every delegated-worker completion is too
expensive; a 2026-09-09 hearing decided to document a re-run cadence
instead (kurone-kito/idd-skill#2706). A re-run always repeats the mode
and routing already in force for this session — A1's single-root or
cross-roadmap choice, and A0/A0-O's own `issue-scope` and
`orphan-first-policy` routing — refreshing the same search, never
widening it to a broader mode this session never selected.

- **Do not re-run** Discover after every delegated-worker completion.
  Dispatch the next worker from the previously enumerated graph
  instead, after a fresh target-local A3 readiness check for that
  specific candidate (the configured authoring label, and any
  newly-added open dependency) — the per-delegation A4/A4.5/A5 gates
  above do not repeat A3's own exclusions, so a candidate that became
  blocked only after the graph was built would otherwise slip through
  uncaught.
- **Do re-run** on any of the following: a worker reports exhaustion
  or no startable candidate remains in the graph already in hand, or
  that graph is stale enough that the orchestrator no longer trusts it
  for the next dispatch — for example when a completed issue may have
  unblocked a dependent still listed as not-ready. A worker merely
  finishing the issue it was dispatched for is not by itself a reason
  to re-run: that happens on every successful dispatch, so treating it
  as a trigger would collapse straight back into the every-completion
  cadence the first bullet rules out. Wait for the helper's own
  process exit before parsing its output — never a mid-run stdout
  read — per
  [A2's helper read timing note](../.github/instructions/idd-discover.instructions.md#a2--enumerate-sub-issues).
- **On a caller-side tool timeout** during the Discover invocation —
  the orchestrator's own tool-invocation wrapper (for example a
  bounded Bash-tool or subprocess timeout) elapsing while the helper
  process may still be running to completion, not the helper itself
  erroring or exiting non-zero — give that same invocation one more
  attempt with a longer time budget (re-attach to the still-running
  process when the tool only stopped waiting rather than killing it;
  otherwise reissue the command) before concluding anything failed.
  Only a second timeout under the longer budget counts as an A2
  enumeration failure, unchanged from today's A2 rule; a helper that
  actually errors or exits non-zero is already an A2 enumeration
  failure on the first occurrence.
- **An exhausted pool** (Discover returned no startable candidate and no
  worker is running). This applies only when no worker is running, and
  only to an orchestrator that stays alive by design, for example one
  re-invoked by a loop runner: A4's exhaustion exit still reports the
  discarded issues and stops, and this bullet changes that for no
  session — the report-and-stop still happens first, and this bullet
  governs only how an orchestrator that its runner keeps alive waits
  afterward. It complements the first bullet above, never overrides it:
  that bullet rules out re-running after every completion, and the **Do
  re-run** bullet's no-startable-candidate trigger is spent by the
  Discover run that returned this empty pool, so it does not recur on a
  timer. Wait for an external change instead of re-running Discover on a
  timer: poll with one GraphQL query shape, paginated by cursor until
  every page is read, for the open issues' numbers, labels, and state
  (not per-issue REST reads) about every 2 minutes, and re-run Discover
  only on one of three events: an issue closed, a new issue without an
  authoring or blocking label appeared, or such a label was removed —
  those events, not elapsed time, are what make the graph stale here.
  The interval is deliberately shorter than the roughly 4-minute race
  seen in a downstream adopter's run (reported 2026-09-30,
  kurone-kito/idd-skill#3677): a second orchestrator claimed the next
  serial issue about 4 minutes after its blocker closed, so the wait
  also decides who wins. A helper for the query is optional and not part
  of this guidance.
- **Optional hint cache**: this section decides _when_ to re-run.
  With `githubApi.readCache.enabled`, a re-run inside `maxAge` is served
  from a hint instead (see the helper-script
  [Discover hint cache](idd-helper-scripts.md#discover-hint-cache)),
  which changes only what a re-run costs, never when one is owed.

## Live Status Digests

Use the live status digest contract in
[IDD comment minimization](idd-comment-minimization.md) when an active
run needs one human-facing current-status comment. Digest text is never
workflow evidence by itself: claim parsing, review currency, advisory
waits, CI, merge readiness, and roadmap audits still read trusted
operational markers and GitHub state.

During resume, repair a missing or stale digest only after the route and
claim state are known. Duplicate marked digests are preserved as audit
history and reported for repair; unattended agents must continue from
the authoritative markers and GitHub state rather than picking a digest
arbitrarily.

Phase files now define digest update points rather than leaving them to
agent judgment. Issue digests are refreshed after claim verification,
planning, meaningful C-loop decisions, hold, abort, and resume route
selection. PR digests are refreshed for review-fix progress, advisory
wait or CI holds, pre-merge blockers, merge failures, and post-merge
cleanup.

Agents deliberately avoid editing a PR digest between a valid E1 review
watermark and a successful F3 merge path. A digest edit can be PR
activity, so successful F2 passes carry their activity snapshot forward
without touching the digest; blocked reroutes and hold paths may update
the digest because they stop or leave merge intent anyway, and so may
an F2 pass blocked only on `secondaryQuietWindow`, since that wait no
longer perturbs review currency. The F3 awaiting-reviewer restart-F2
path is the exception: it skips digest updates so the restarted F2 pass
does not self-invalidate review currency.

### Roadmap-claim contention playbook

Use this playbook when multiple sessions are active:

- **Do continue child execution** when a roadmap claim is present, unless
  a normal readiness gate blocks the child issue. Claims are per issue.
- **Do treat `roadmap-audit/*` as coordination-only** for roadmap
  side-effects (comment/edit/label/follow-up/close), not as a global
  execution lock.
- **Do stop and defer on fresh non-owned claims**. If a claim is active,
  non-stale, and not yours, treat it as not inheritable.
- **Do take over only stale non-owned claims** according to shared stale
  thresholds and `supersedes` rules; do not force ownership changes.
- **Do heartbeat only for owned active claims**, and release
  roadmap-audit claims promptly after roadmap-side effects finish.
- **Do not bypass blocker labels, dependency checks, or claim
  revalidation gates** while resolving contention.

## Roadmap Claim Guardrails

Roadmap-audit claims are coordination-only. Use them only while the
roadmap issue itself is being mutated, then release them once that
roadmap-side effect is complete. They are not a proxy lock for child
claims.

Recursive roadmap hierarchies still follow that rule. Leaf execution
issues finish first, then the deepest completed nested roadmap is
audited and closed under its own `roadmap-audit/*` claim, and only then
is the parent roadmap re-evaluated. Bottom-up closure keeps roadmap
claims scoped to the exact roadmap issue being mutated instead of
turning one parent claim into a lock over child or sibling work.

If the roadmap claim remains open after the roadmap-side effect is done,
or if it appears to serialize child execution, treat that as a misuse
signal: revalidate ownership and stale timing before continuing, then
heartbeat, release, or take over rather than holding the claim open.

The docs audit keeps this guidance synchronized with the exported
template so unattended runs can spot drift.

## Copilot review instruction scope

The heavy shared overview keeps `applyTo: "**"` so GitHub Copilot
execution surfaces can receive the IDD entry context automatically.
However, it also sets `excludeAgent: "code-review"` so Copilot code
review does not ingest the full operational workflow as reviewer-side
context.

This is an intentional middle path between the evaluated alternatives:
keeping review coupled to the full overview, narrowing `applyTo` and
risking execution-agent discoverability, or splitting a separate
reviewer-only instruction file. Copilot code review may still use the
lightweight repository-wide `.github/copilot-instructions.md`; only the
heavier `idd-overview-core.instructions.md` is excluded from review.

## F2 merge-readiness evidence checklist

Before executing F3 merge, F2 must record concrete evidence for merge
readiness rather than relying on a single reviewer signal.

Required evidence fields:

1. Activity-universe snapshot values:
   `{head-SHA}`, `{max-activity-updatedAt|none}`,
   `{total-item-count}`, `{latest-ci-completed-at|none}`.
2. Unresolved-thread evidence: total unresolved threads, actionable
   unresolved count (non-awaiting-reviewer), and AMD thread presence.
3. Unreplied regular-comment evidence: count of non-IDD-agent comments
   without a later IDD-agent reply.
4. Reviewer-state evidence: latest `CHANGES_REQUESTED` states for human,
   required, and CODEOWNER reviewers, plus required approval/CODEOWNER
   satisfaction.
5. Advisory-wait evidence: AW outcome for the current HEAD, marker
   coverage (`EARLIEST_SAME_HEAD_AT`), and merge-gate satisfaction.
6. CI evidence: required-check generation and pass status for all
   required checks on the current HEAD.

Mixed reviewer ecosystems are expected. The same checklist applies
across human reviews and advisory bot surfaces (Copilot, CodeRabbit,
Codex connectors, CI bots); "one bot says clean" is never sufficient by
itself.

**Authoritative source for the final-merge fields.** Bind every CI and
activity value in this checklist to the **live `pre-merge-readiness` run on
the current HEAD** — that helper is the authoritative source for the
F2/F3 merge decision. The `review-activity-snapshot` helper builds the
**E-phase** activity universe (E1) and must **not** be reused as the
F-phase merge decision: the two can disagree in the window just before
merge ("ci-pass-drift"), so reading CI/activity from the E-phase snapshot
instead of the live pre-merge run risks merging on stale evidence. See
[IDD helper script evaluation](idd-helper-scripts.md#merge-gate-evidence)
for each helper's phase role.

## Review Policy Profiles

The execution loop is cross-agent, while PR review policy is a
repository choice. See
[IDD review policy profiles](idd-review-policy-profiles.md) before
customizing the default Copilot advisory behavior.

## Default PR policy: Copilot advisory review

The core IDD flow is cross-agent, but the distributed default PR policy
still includes a GitHub Copilot advisory review step in later PR
phases.

- `idd-review-fix.instructions.md` can request a GitHub Copilot
  re-review for the current PR head.
- `idd-merge.instructions.md` can wait or hold based on that GitHub
  review state.
- This dependency is on GitHub's review integration, not on every local
  agent using Copilot as its CLI.
- Adopters who do not want that default PR policy should choose another
  review policy profile, apply the matching
  `profiles/<profile>/README.md` artifact, and follow the PR review
  profile edit-surface checklist in
  [IDD review policy profiles](idd-review-policy-profiles.md).
- Expect non-default profile changes to cover review-fix, advisory-wait,
  pre-merge, merge, review-snapshot, and review-triage surfaces; the
  exact edits vary by profile.

Non-Copilot agents can still drive the workflow end to end, but they
should expect those later phases to interact with Copilot as a GitHub
reviewer because that is part of this repository's current PR policy.

## Maintainer-Authorized External-Check Waivers

Some repositories classify a small set of repo-external checks as
waivable so IDD can recover when a third-party integration becomes
stuck, unavailable, or rate-limited even though repository-owned
validation is already healthy. This is a human-authorized escape hatch,
not an automatic merge bypass.

High-level maintainer flow:

1. Let IDD reach an F2 hold and confirm that the blocker is a
   configured external check rather than a repository-owned or
   GitHub-required gate.
2. Run the optional waiver facade in dry-run mode to inspect the exact
   comment body, matched check, active claim, current PR HEAD, and
   expiry before any mutation.
3. Post the canonical waiver comment only through the helper's apply
   path, then resume IDD on the same PR head.
4. Keep every other gate intact: review currency, unresolved threads,
   unreplied comments, required reviews, claim ownership, and GitHub
   merge topology still have to pass normally.

Normal PR approvals or casual maintainer comments such as "continue" are
not sufficient waiver evidence. In solo-maintainer repositories, this
helper-generated comment is the auditable authorization surface because
self-approval cannot express the required claim, head, check, and expiry
proof.

A waiver posted before its own effectiveness precondition is met is
valid but inert until then; see
[`idd-pr-submit.instructions.md`'s D4](../.github/instructions/idd-pr-submit.instructions.md)
for the mechanical check.

## Optional helper scripts

The idd-skill source repository that ships this template currently includes the
following optional helper scripts:

- `scripts/resume-claim-routing.mjs` (read-only Resume Step 1 claim
  routing evidence)
- `scripts/resume-route-selection.mjs` (read-only Resume Step 3 route
  selection evidence)
- `scripts/review-activity-snapshot.mjs` (read-only E/F activity and CI
  snapshot metrics)
- `scripts/advisory-wait-state.mjs` (read-only advisory-wait evidence
  and AW outcome reporting)
- `scripts/external-check-waiver.mjs` (maintainer dry-run/apply facade
  for canonical external-check waiver comments on the current PR head;
  added in 0.2.0)
- `scripts/pre-merge-readiness.mjs` (read-only F2/F3 readiness evidence
  collection)
- `scripts/review-disposition-verify.mjs` (read-only E7 disposition
  verification evidence)
- `scripts/live-status-digest.mjs` (issue or PR live status digest
  dry-run and claim-checked upsert)
- `scripts/audit-pr-cleanup.mjs` (post-merge cleanup audit and optional
  apply mode)
- `scripts/merged-pr-feedback-sweep.mjs` (read-only, manually-invoked
  post-merge sweep that scans merged PRs for unresolved review threads
  and undispositioned advisory feedback, handing JSON to the
  issue-authoring skill)

Shell / `gh` / `jq` snippets in
`.github/instructions/*.instructions.md` remain the canonical portable
path for repositories that stay on `instructions-only`. When helper
runtime is enabled, these shipped helpers are the preferred evidence
collection path, while live GitHub checks and written gate rules remain
authoritative.

See [IDD helper script evaluation](idd-helper-scripts.md) for the
current inventory of high-friction query patterns, the adopted helper
scope in the idd-skill source repository, and the criteria for future helper
changes.

See [IDD comment minimization](idd-comment-minimization.md) for the live
status digest helper, post-merge cleanup helper, GraphQL fallback command
shape, and merged-PR experiment for hiding completed feedback and stale
operational markers without deleting the audit trail.

## Critique pass invocation

A **critique pass** is an independent review of a plan or diff that
produces a list of issues with severity, correctness, and coverage
assessment. The goal and expected output are the same regardless of
agent; only the mechanism differs.

| Agent           | How to run a critique pass                                                                                                                                                                                                                                                                                                                                                                             |
| --------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Copilot         | Launch a subagent in Agent mode; use the calling phase's critique checklist as the prompt                                                                                                                                                                                                                                                                                                              |
| Claude Code     | `Agent(subagent_type="general-purpose")` with the calling phase's critique checklist                                                                                                                                                                                                                                                                                                                   |
| Codex CLI       | Use one bounded read-only native subagent review when supported and suitable; parent waits for and collects the result. Fallback: structured self-critique when delegation is unavailable, disabled, unsuitable, or fails.                                                                                                                                                                             |
| OpenCode        | Launch a subagent via OpenCode's Task tool (e.g. the built-in `general` subagent, or a `subtask: true` command) — an independent mechanism                                                                                                                                                                                                                                                             |
| Grok Build      | Independent `spawn_subagent` with the calling phase's critique checklist. Fallback: structured self-critique when delegation is unavailable, unsuitable, or fails (unsuitable: the subagent returns no findings list, or its search beyond the named scope is open-ended rather than a targeted trace of code the change depends on or affects).                                                       |
| Cursor CLI      | Launch an independent Cursor `Task` tool subagent with `subagent_type="generalPurpose"` (or the nearest equivalent general-purpose subagent) using the calling phase's critique checklist; parent waits for and collects the result. Fallback: structured self-critique when delegation is unavailable, unsuitable, or fails. Do not substitute Cursor product review skills for IDD E-phase critique. |
| Antigravity CLI | Self-critique or use Antigravity's native multi-step task mechanism if available                                                                                                                                                                                                                                                                                                                       |

The brief given to a delegated per-agent critique subagent states the
five rules below, each followed here by its citation per
[Cite the observed incident](idd-design-rationale.md#cite-the-observed-incident).
These rules apply to the brief for a delegated per-agent critique
subagent only; structured self-critique and `critiqueLoop.delegate`
commands are unchanged. The brief is a prospective constraint, not an
enforced sandbox, like the trust-based contract the
[Completed-draft adversarial review](#completed-draft-adversarial-review)
subsection describes for the issue-authoring reviewer.

1. **Read-only.** Apart from creating and writing in its own scratch
   directory (see the scratch-directory rule), the pass writes nothing
   to the worktree or the git directory and leaves no file elsewhere,
   changes no branch, posts no marker or comment, and runs no `gh`
   command other than a read-only query. For example it may read files
   and run `git log`, `show`, `diff` and `grep`; any other command,
   apart from creating and filling its own scratch directory, runs only
   when the brief names it, and that includes a test run (invoked
   directly, for example `node --test <file>` for a Node project, not
   through a package-manager script, with its temporary and cache
   output directed into the scratch directory) and a helper script.
   Observed 2026-10-01, during the E2 critique of
   `kurone-kito/idd-skill#3648`; no issue records the incident itself.
   The issue-authoring analogue is `kurone-kito/idd-skill#3448`.
2. **No package manager or hook installer, no `node_modules` writes.**
   No package-manager command that can install, link or run a script
   (for example `pnpm`, `npm`, `npx`), no other command that installs
   hooks or links packages (for example `husky`), and no copying,
   linking or writing of the worktree's `node_modules`. Observed
   2026-10-01, during the E2 critique of `kurone-kito/idd-skill#3648`
   (no issue records the incident itself), and 2026-09-30 in an
   issue-authoring draft review (no issue filed).
3. **Scratch files only in its own directory.** Scratch files go only
   in a directory the subagent creates (for example with `mktemp -d`)
   outside the repository and the session scratchpad. When the parent
   has already created a scratch directory outside the repository and
   the session scratchpad and named it in the brief (the Claude Code
   recipe below has the parent create a scratch directory and name it
   in the launch prompt), the subagent uses only that directory and
   creates none. This rule is preventive; no observed incident yet (the
   `kurone-kito/idd-skill#3648` vector was the symlink, not the
   location).
4. **No reading of session-private state.** The subagent does not read
   the claim lock file `idd-claim.lock`, the `idd-generated-*` files in
   the git directory, the session scratchpad (except a file the brief
   names), the parent session's transcript, or the operator's notes and
   per-user agent memory files. Observed 2026-09-24, during work on
   `kurone-kito/idd-skill#3253` (no issue records the incident itself),
   for the session scratchpad; observed 2026-10-01 (no issue filed), for
   the operator's notes and per-user agent memory files; for the claim
   lock file, the `idd-generated-*` files and the parent session's
   transcript: preventive; no observed incident yet.
5. **No background process left running.** The subagent ends every
   background process the subagent itself started before it returns.
   Observed 2026-10-01, during the plan critique for
   `kurone-kito/idd-skill#3705` (no issue records the incident itself).

The parent bounds its wait for each delegated per-agent critique pass by
the resolved `critiqueLoop.subagentWaitCeiling`. Enforce that ceiling
through the harness's own per-invocation timeout control, never through a
timeout utility wrapped inside the delegated command, following the
principle from issue `kurone-kito/idd-skill#3449`. Where the harness supports
it, launching in
the background and applying a bounded wait is an equivalent way to enforce
the same ceiling only when the harness also cancels or cleans up the timed-out
subagent and ignores any late output. Otherwise the background process may
continue consuming resources or race with the structured fallback, so do not
use that pattern as an equivalent implementation.

Reaching the ceiling without a findings list is a delegation failure. A
wait that ends through cancellation, interruption, or error without a
findings list is also a delegation failure. Either outcome routes to the
row's structured self-critique fallback, or to "perform the critique as a
structured self-review step" for a row without an explicit fallback, and
the critique result records that the delegated pass did not return.

A harness whose delegation primitive offers no way to bound the wait
cannot honor the ceiling. Record that residual risk explicitly and use
structured self-critique as the unattended-safe path for that harness.

For Claude Code, whose `Agent` tool has no timeout parameter, the
following recipe is conditional on `Agent` launching asynchronously, as it
does today: it returns at once, and only a later notification reports that
the pass ended, which may never come if the subagent stalls. Where a
harness call blocks until the subagent ends, nothing can interrupt it and
the "cannot honor the ceiling" paragraph above applies instead. A Claude
Code session:

1. Checks, before launching, that it can arm a wake-up with one of the
   mechanisms the
   [wake-up discipline](../.github/instructions/idd-ci.instructions.md#wake-up-discipline)
   section names (that section also notes that a bare `sleep` may be
   refused) and that `TaskStop` is available (a tool listed only as
   deferred counts once it has been loaded, which must happen before the
   launch). When it cannot confirm both, it does not launch, records the
   residual risk as the "cannot honor the ceiling" paragraph above
   requires, and uses structured self-critique.
2. Creates, before the launch, a unique scratch directory outside the
   worktree, names it in the launch prompt, and tells the subagent to put
   any scratch file only under it and to start any background job with a
   working directory under it.
3. Launches the pass with `Agent`, notes the launch time, and arms the
   wake-up for the ceiling, deliberately the ceiling and not the expected
   completion because the ceiling is the only moment a decision is
   needed, cancelling or ignoring that wake once that pass has returned.
4. When the ceiling is reached and no findings list has arrived, stops the
   subagent with `TaskStop` and the agent id the launch returned. That is
   the delegation failure defined above, so the structured self-critique
   fallback runs, the critique result records that the delegated pass did
   not return, and a result that arrives later is discarded even if it is
   usable (a repository whose passes legitimately run longer sets a larger
   `critiqueLoop.subagentWaitCeiling`). A findings list that has already
   arrived when the session acts is used. If the launch returned no agent
   id or `TaskStop` fails, the session records the residual risk and takes
   the same fallback, because it cannot confirm the stop.
5. Once the pass has returned, been stopped, or the stop could not be
   confirmed, lists the processes left running and ends by process id only
   those whose working directory or command line is under the scratch
   directory, never the session's own shell or the listing command itself.
   It reports any other leftover as residual risk, without ending it, and
   it never ends processes by a name pattern. It removes the scratch
   directory by its exact literal path (never a possibly unset shell
   variable) only after that cleanup and only when no process under it
   remains; otherwise it leaves the directory and records the residual
   risk.

In a session that passed the check in item 1, stopping with `TaskStop` and
this cleanup are how the Claude Code pattern meets the equivalence
condition above. Whether a background job survives `TaskStop` was not
replayed. The observations behind this recipe follow; none was recorded in
an issue or pull request before this recipe:

- On 2026-10-01, during the plan critique for kurone-kito/idd-skill#3705
  (later pull request kurone-kito/idd-skill#3712), a delegated pass
  returned after about 33 minutes against the 20-minute ceiling and the
  session waited it out, neither stopping the subagent nor recording a
  delegation failure. After that subagent's result was delivered, an
  enumeration it had started in the background was still using about 108%
  of a CPU on the shared host until the parent ended it by process id.
  Neither is recorded in that issue or pull request.
- In a replay on 2026-10-02 (no issue), `TaskStop` with the agent id the
  launch returned stopped a running subagent, and the foreground process
  it had been running was gone eight seconds later.
- On 2026-09-30, in an operator session during the work on pull request
  kurone-kito/idd-skill#3605, a name-pattern kill ended the session's own
  shell, which is why step 5 never ends processes by a name pattern. No
  issue or pull request records that incident itself.

For Codex delegation, the parent collects the reviewer result before
continuing; if delegation fails, use the structured fallback.

For Grok Build, the critique brief must give the subagent the actual
artifact under review (file references by their sibling-worktree
absolute paths, never a relative path or a bare `cd`; a diff by an
absolute-worktree diff command or revision range; or a plan by its
literal text), the issue's requirements or acceptance criteria in
every case — even when the calling phase's own checklist wording
does not name them explicitly, since a correctness assessment is
meaningless without them — and any other checklist input the calling
phase names, such as the E9 findings under verification for E10.
Instruct the subagent to stay within that scope except for a targeted
trace of code the change depends on or affects — `spawn_subagent`'s
working-directory parameter does not rebind Grok's
file tools (that rebind gap is kurone-kito/idd-skill#2819). This
constrains the pass prospectively but does not guarantee compliance —
the unsuitable fallback above still applies when the subagent wanders
past it
anyway.

When a phase file says "run a critique pass", apply the row for your
agent above. If no subagent mechanism is available, perform the critique
as a structured self-review step within the same response.

### Repository-configurable critique delegate

A repository may point C1 or E10 at a reviewer other than the
per-agent mechanism above by setting `critiqueLoop.delegate` in
`.github/idd/config.json` (see
[Customization Surfaces](customization.md#customization-surfaces) and
[Configuration Authority Hierarchy](policy-constants.md#configuration-authority-hierarchy)):
a `command` string is a shell command run against the branch's current
diff, and `mode` selects **when the per-agent mechanism above also
runs**:

<!-- dprint-ignore-start -->
| `mode` | delegate succeeded | delegate failed |
| --- | --- | --- |
| `combined` | per-agent pass runs | per-agent pass runs |
| `fallback` (default) | no per-agent pass | per-agent pass runs |
| `on-success` | per-agent pass runs | no per-agent pass |
| `never` | no per-agent pass | no per-agent pass |
<!-- dprint-ignore-end -->

`combined` is the one value that does not consult the delegate's
outcome — it runs both mechanisms on every pass. The other three
observe that outcome first. Wherever both mechanisms run in the same
pass (always under `combined`, and after a successful delegate under
`on-success`), their reported issues are unioned.

**Delegate failed** means the same set of conditions in every mode: the
command is absent, exits non-zero, times out, or its output cannot be
read as a findings list. It is never narrowed to the process exit
status alone, so a delegate that exits `0` but returns unreadable
output counts as failed under `fallback` and `on-success` alike.
Exit-code conventions differ between reviewers — a lint-style tool
signals _findings exist_ with a non-zero exit rather than _the tool
broke_ — which is why `on-success` exists at all.

**Fail-closed hold.** Under `on-success` and `never`, a failed delegate
can leave C1 with no critique findings at all. The hold condition is
that state itself, not the failure classification: when the mechanisms
that actually ran produced no readable findings list, C1 records a hold
rather than a clean "zero issues reported" verdict, and C2 does not
advance to PR submission on that vacuous result. A delegate that trips
one of the conditions above but still emitted a readable findings list
has produced critique — those findings are the pass's output and C1
continues to C3 scoring on them. `fallback`'s fall-through to the
per-agent mechanism is unchanged. (Written here in C1's own step
vocabulary — `C2`/`C3`; see "E10 delegate support" below for the same
hold applied in E10's own vocabulary.)

The hold turns on a **missing or unreadable** findings list, never on
an empty one. A delegate that succeeded and reported no issues has
produced a readable findings list that happens to be empty: that is a
genuine clean verdict, and C2 proceeds to the objective diff validation
floor exactly as it would with no delegate configured. Only the
no-readable-list state is vacuous.

Delegate output is read the same way a subagent's critique response is
read today — free-form findings scored through the existing C3
High/Medium/Low process; no new machine-readable output schema is
introduced. Absent `critiqueLoop.delegate` entirely keeps today's
per-agent-only behavior with zero change.

Configuration-time fail-safe (distinct from the runtime behavior
above): a non-object `critiqueLoop.delegate`, one whose `command` is
missing, empty, whitespace-only, non-string, or supplied through the
prototype chain rather than as an own property, or one carrying any key
beyond `command`/`mode`, is treated the same as an absent delegate —
the calling pass (C1 or E10) uses the per-agent mechanism, never
attempting the delegate at all. A present but non-object
**`critiqueLoop`** parent (a string, array, or `null`) is a
repository-local configuration error rather than an absent key: it
fails closed to the per-agent mechanism and, like a malformed
`delegate`, blocks user-global inheritance instead of letting a global
delegate stand in for it. A present but **unrecognized `mode`** is
unusable the same way: effective delegate resolution reports a
repository-local one as malformed, so it neither runs nor inherits the
user-global layer, and reports an unusable user-global fragment as
absent. Either way the calling pass falls back to the per-agent
mechanism rather than running the delegate under an assumed default.
(A direct `normalizePolicyConfig` caller — a different consumer, not
the delegate resolution path used by C1 or E10 — still collapses such
a value to the `fallback` default, which is why both behaviors have
their own regression tests.) `.github/idd/config.json` schema
validation separately rejects an unsupported `mode` value or any key
other than `command`/`mode` before the file is accepted, so this state
normally reaches C1 or E10 only through the unvalidated user-global
file.

The C-phase's objective diff validation floor described below applies
**uniformly** whether a delegate is configured or not, in every mode,
and regardless of what the delegate reports — this surface changes
which mechanism produces critique findings, never the load-bearing
`fix-validate` gate. That holds for the fail-closed hold above too: the
hold stops a vacuous clean verdict from advancing, it never lets one
through.

When a runtime falls back to structured same-response self-review
instead of an independent subagent mechanism (see the table above; a
runtime's own native multi-step mechanism, such as Antigravity's when
available, counts as independent), treat that self-critique verdict as
**advisory only** — it is not sufficient by itself to let the C-phase
skip to PR submission. The C-phase's objective diff validation floor (the
**fix-validate** command set that C5 also runs; see
`.github/instructions/idd-work.instructions.md` C1/C2/C4) is the
**load-bearing** gate instead — independent of D2's own
**pre-push-validate** gate.
This floor applies **uniformly** to every runtime — including
subagent-capable ones — rather than being conditioned on a runtime
self-classifying as "no-subagent". Uniform application keeps the gate
deterministic and avoids relying on fragile runtime self-detection that
a weak model could get wrong.

### User-global critique delegate default

A local runtime (one that reads the operator's own `$HOME`) may also
inherit a `critiqueLoop.delegate` from a user-global file when the
repository leaves the repo-local field genuinely absent — a
GitHub-hosted or other remote agent surface is not meant to consult this
layer, but the helper detects only `GITHUB_ACTIONS=true` on its own (pass
`--no-user-global` on any other remote surface). Resolution order: repo-local
`critiqueLoop.delegate` (a configured object, an explicit JSON `null`
disable, or a malformed value) always wins outright and never inherits
the global layer — an explicit repo-local `null` forces the per-agent
mechanism even when a global delegate exists, and a malformed
repo-local value fails closed to the per-agent mechanism the same way;
only when repo-local is entirely absent does the global file apply;
absent both, the per-agent mechanism above runs unchanged. A malformed
or explicit-`null` **global** fragment is treated the same as a
missing one — silently falls back to the per-agent mechanism — which
is distinct from repo-local `null`'s stronger role of actively
disabling any inherited delegate.

The global file lives at `$XDG_CONFIG_HOME/idd-skill/config.json`,
falling back to `$HOME/.config/idd-skill/config.json` when
`XDG_CONFIG_HOME` is unset or not a **qualified root**. A qualified
root is judged against the **running platform**, not accepted in any
form: on Windows only a drive-letter root (`C:\…` or `C:/…`) or a UNC
root (`\\server\…`) qualifies, and on POSIX only a `/…` path does —
`//…` is excluded there, as is a Windows-shaped value, and a
current-drive root such as `\config` is excluded on Windows even though
`path.isAbsolute` calls it absolute. A relative or otherwise unqualified
value is ignored rather than joined against the process's working
directory, so the global config can never resolve inside the checkout
under review. A missing, unreadable,
invalid-JSON, or non-object global file is silently treated as
absent — this layer is opt-in and never required for OSS adopters.
Only the
`critiqueLoop.delegate` fragment is read by this resolver. The same file
can also carry `critiqueLoop.telemetryHook` (read only by the telemetry
hook resolver) and `issueAuthoring.adversarialReview.delegate` (read only
by the issue-authoring delegate resolver); every other key is ignored by
all three, and repository-local `.github/idd/config.json` stays the sole
authority for every other policy surface.

Example (a generic local reviewer, not a specific product):

```json
{ "critiqueLoop": { "delegate": { "command": "my-local-reviewer --diff" } } }
```

Any configured delegate command — repo-local or user-global — is
executable configuration: it may transmit source code or other data
available to its process to an external service, so enabling one is a
deliberate operator/repository choice, and neither config file should
hold secrets. This surface changes only which mechanism supplies
critique findings; the C-phase objective diff validation floor above,
the E-phase Copilot advisory-convergence policy, required checks, and
merge gates are all unchanged.

The critique content passed to a configured delegate is the branch diff
only — never the two lenses below or the rest of the per-agent
checklist. (This is about what the delegate invocation sends as
critique input, not a sandboxing guarantee on what the command can
otherwise access — see the executable-configuration warning above.)
Passing checklist content to an external command is a capability change
with its own design questions (whether the reviewer accepts input at
all, what happens if it ignores it) that this surface does not make
today. Under a successful delegate with `mode: fallback` (the default),
or under `mode: never`, the per-agent pass does not run at all, so an
operator relying solely on a delegate should expect the lenses below
are not applied to that PR's diff.

### Repository-configurable critique telemetry hook

A repository may also configure a per-round C-phase telemetry
notification by setting `critiqueLoop.telemetryHook` in
`.github/idd/config.json` (see
[Customization Surfaces](customization.md#customization-surfaces) and
[Configuration Authority Hierarchy](policy-constants.md#configuration-authority-hierarchy)):
a `command` string is a shell command invoked once per C-phase round,
with a JSON payload written to its stdin. Unlike `critiqueLoop.delegate`
above, this hook never supplies critique findings and never gates
C-phase control flow — it is a pure observability side channel.

The hook is invoked at two points in the C-phase loop, documented in
both the full-profile work file (C2 and C4) and the lite work file
(`lite/idd-work-lite.instructions.md`, matching steps): at the end of
C4, once the round's Accept/Reject decision is final (before C5, PR
submission, or a hold); and at C2's zero-issue exit, so a clean round
that skips C3/C4 entirely still emits a record (with zero
findings/accepted/rejected counts).

The JSON payload written to the hook command's stdin:

```json
{
  "phase": "C",
  "round": 2,
  "repo": "owner/repo",
  "issue": 123,
  "pr": null,
  "findingsCount": 3,
  "severityBreakdown": { "high": 1, "medium": 1, "low": 1 },
  "acceptedCount": 2,
  "rejectedCount": 1,
  "delegateUsed": true,
  "delegateCommand": "coderabbit-critique",
  "timestamp": "2026-09-08T12:00:00Z"
}
```

`pr` is `null` before a PR exists for this issue; `delegateCommand` is
present only when `delegateUsed` is `true`.

**Fire-and-forget.** A missing command, non-zero exit, timeout, or any
other failure invoking the hook is silently ignored and never blocks,
holds, delays, or otherwise changes C-phase control flow — unlike
`critiqueLoop.delegate`'s fail-closed hold semantics described above,
this is a pure side channel. The C-phase objective diff validation
floor and every other C-phase gate apply identically whether the hook
is configured, missing, or failing.

### User-global critique telemetry hook default

A local runtime (one that reads the operator's own `$HOME`) may also
inherit a `critiqueLoop.telemetryHook` from a user-global file when the
repository leaves the repo-local field genuinely absent — a
GitHub-hosted or other remote agent surface is not meant to consult this
layer, but the helper detects only `GITHUB_ACTIONS=true` on its own (pass
`--no-user-global` on any other remote surface). Resolution order: repo-local
`critiqueLoop.telemetryHook` (a configured object, an explicit JSON
`null` disable, or a malformed value) always wins outright and never
inherits the global layer — an explicit repo-local `null` disables the
hook entirely even when a global hook exists, and a malformed
repo-local value fails closed to "no hook" the same way; only when
repo-local is entirely absent does the global file apply; absent both,
no hook runs. A malformed or explicit-`null` **global** fragment is
treated the same as a missing one — silently falls back to "no hook" —
which is distinct from repo-local `null`'s stronger role of actively
disabling any inherited hook.

The global file lives at the same path, and under the same
qualified-root rules, as the critique delegate's own user-global file
above (`$XDG_CONFIG_HOME/idd-skill/config.json`, falling back to
`$HOME/.config/idd-skill/config.json`). Only the
`critiqueLoop.telemetryHook` fragment is read by this resolver. The same
file can also carry `critiqueLoop.delegate` (read only by the critique
delegate resolver) and `issueAuthoring.adversarialReview.delegate` (read
only by the issue-authoring delegate resolver); every other key is
ignored by all three, and repository-local `.github/idd/config.json`
stays the sole authority for every other policy surface.

Example (a generic local notifier, not a specific product):

```json
{ "critiqueLoop": { "telemetryHook": { "command": "my-critique-notifier" } } }
```

Any configured hook command — repo-local or user-global — is executable
configuration: it may transmit source code or other data available to
its process to an external service, so enabling one is a deliberate
operator/repository choice, and neither config file should hold
secrets. This surface only emits a per-round observability record; it
never changes which mechanism supplies critique findings, the C-phase
objective diff validation floor, the E-phase Copilot
advisory-convergence policy, required checks, or merge gates.

### E10 delegate support; telemetry hook stays C1-only

`idd-review-fix.instructions.md`'s own critique pass (E10) also
consults `critiqueLoop.delegate`, using the exact same resolution
chain, `mode` semantics, and fail-closed hold behavior described above
for C1 — including the `idd-critique-delegate` helper and the
`instructions-only` resolution order. E10 states the fail-closed hold
in its own vocabulary: when the mechanisms that actually ran under
`on-success`/`never` leave no readable findings list, that is a hold
(the shared Hold / suspend rules in
`idd-overview-appendix.instructions.md` apply), never a clean "zero
issues, proceed to E11" round.

`critiqueLoop.telemetryHook` remains scoped to the C1 critique pass
only; E10 never consults it, regardless of configuration. Extending
the telemetry hook to E10 remains a separate, not-yet-scoped change.

### E2 after a clean C1 on the same HEAD

E2's first pass (`idd-review-snapshot.instructions.md`) is kept even
when C1 ran clean on the tree that became the pull request's head: C1
having reviewed that head is not a reason to skip it. What E2 must not
do is repeat C1. C1's rounds already ran the configured mechanism (for
example the delegate plus the per-agent pass under `combined`), while
E2's incremental scope keys off a same-claim `review-baseline` that
neither C nor D posts, so a first E2 pass scopes to the full branch diff
(and does so again after a takeover). Briefed like C1, it asks for the
same review a second time.

Name C1's lens and its finding count in the E2 brief and ask for a
different lens, for example an **adversarial** one: try to break the
change, and run the new tests against mutants of it (small deliberate
defects in the code under test) so each mutant must fail a named test. A
takeover successor that cannot recover C1's lens or count says so in the
brief and picks a lens the C1 checklist did not use. Reported 2026-09-30
by an adopter (kurone-kito/idd-skill#3678): on a small guard-plus-tests
change, C1 with a checklist lens reported three Low items, while E2 with
an adversarial lens ran the new specs against five mutants of the guard,
reported one Low item, and showed every mutant failing a named test.
That is evidence C1 could not produce, and it let the session reject the
Low item without another push. The
[mutation / write-side helper lens](#mutation--write-side-helper-lens)
and the [gate-mirroring helper lens](#gate-mirroring-helper-lens) below
apply at E2 exactly as at C1, on top of the lens chosen here; the first
concerns helpers that mutate GitHub or git state, not mutation testing.

### Mutation / write-side helper lens

When the diff under critique implements a helper that **mutates GitHub
state, mutates git state, or performs a merge** (read-only helpers are
out of scope), also apply this lens — each check below targets a gap
class that a clean general critique repeatedly missed and that later
review then surfaced one finding per round:

- **Fail-closed inputs**: guards use strict checks (`=== true`, explicit
  pattern/enum validation) so a non-boolean, empty, missing, or malformed
  value blocks the mutation rather than passing it.
- **Validate/execute scope parity**: the repo, identity, and HEAD the
  gate validates are the same ones the mutation runs against — no split
  between a read-side collector's scope and the executed `gh` / git
  command; reject ambiguous partial scoping.
- **Unsafe-output suppression**: a not-ready or invalid verdict never
  emits a copy-pasteable command bound to an unvalidated value.
- **Schema strictness parity**: output schemas match the values the
  helper actually produces and mirror sibling-helper strictness (SHA
  patterns, enums), so the published contract is no looser than the
  runtime.

### Gate-mirroring helper lens

When the diff under critique implements a helper whose purpose is to
**predict, mirror, or pre-check a decision some other gate makes** —
where "agrees with that gate" is the whole contract — also apply this
lens. It is orthogonal to the write-side lens above rather than an
alternative to it: a helper that both mutates state and mirrors a gate
gets both, and their checks do not overlap.

Extracting the shared decision into one function is the right first
move and does not finish the job, because **sharing a function
equalizes the computation, not the arguments**. Two callers still
diverge whenever one passes fewer inputs, a laxer validation path, an
older snapshot, or a stale point in time. Enumerate the gate's inputs
once, against this list, rather than discovering them one per review
round:

- **Validation-path parity**: the helper reads configuration through the
  same validating reader the gate uses, not a rawer resolver that skips
  a schema or subtree check. A gate that rejects a whole config section
  when any sibling key is invalid, and falls back to a default, must not
  be mirrored by a helper that reads the one key directly.
- **Input completeness**: every optional argument that widens or narrows
  the gate's own verdict is passed, not just the ones the happy path
  needs. An omitted exception parameter silently removes the exception.
- **Whole-identity comparison**: every field the gate binds on is
  compared — both the fields the shared value carries and the ones it
  does not, which the caller must then supply itself. A shared record
  that omits an identity field is not evidence that the field does not
  matter.
- **Snapshot identity**: all inputs to one verdict come from a single
  read. Two reads that can straddle a change produce a verdict about no
  state that ever existed.
- **Point-in-time parity**: state re-read after a mutation is
  re-resolved rather than reused from before it, whenever the gate would
  see the newer state.

Each check names a way a mirror can disagree with its gate while the
shared code is itself correct, so a passing unit test on the shared
function is not evidence for any of them. The gap class was observed on
[kurone-kito/idd-skill#2330](https://github.com/kurone-kito/idd-skill/pull/2330),
where a correct extraction still took seven advisory rounds, five of
them this one shape.

[issue-authoring-review-input-schema]: https://kurone-kito.github.io/idd-skill/schemas/issue-authoring-review-input.schema.json
