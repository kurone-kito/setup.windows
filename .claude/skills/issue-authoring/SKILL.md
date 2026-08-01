---
name: issue-authoring
description: Draft or refine IDD-ready GitHub issues, roadmap issues, and sub-issues before the normal IDD execution loop begins. Use when a request is too large or ambiguous for one reviewable change, when work needs decomposition or dependency encoding, or when the user asks for issue drafting, roadmap planning, or parallelizable task breakdown.
---

# Issue Authoring

Use this skill to prepare issue-ready work before execution starts.
Keep the skill concise and treat the repository docs as the canonical
source for the full contract and schema.
The canonical source bundle lives in this repository; install copies in
the agent-specific skill directory your runtime reads.

## Stable Phases

Use two stable phases:

1. **Intake and Clarification** — inspect relevant context, identify
   ambiguity, run a secondary critique or explicit self-critique, and
   ask only the questions that block safe issue drafting. Keep
   clarification bounded; use the repository-local
   `issueAuthoring.maxClarificationRounds` value when available,
   otherwise default to 3 rounds. **Under-clarification stop rule**: if,
   after bounded clarification, you still cannot name the concrete
   surface to edit or an objective verification for a candidate task,
   route it to `needs-decision` or ask — do not publish a
   confidently-vague `ready` issue. Reliability over speed.
2. **Decompose and Draft** — restate the request in implementation
   terms, split it into atomic tasks, classify readiness, reuse existing
   issues when safe, and draft the smallest issue shape that preserves
   dependencies and reviewability.

Preserve low-readiness work in stable buckets: ready, deferred,
needs-decision, blocked-by-human, and out-of-scope.

## Workflow

1. Read the bundled contract in
   [references/contract.md](references/contract.md).
2. Reuse or extend an existing issue before creating a new one — but
   never edit the body of an actively-claimed or open-PR issue (its
   claimed agent will not pick the change up); cover it with a follow-up
   issue instead. See the contract's claim-state precondition.
3. Choose the smallest safe output shape:
   - orphan issue for one ready autonomous task only when the target
     repository discovers orphans (`issue-scope: roadmap-first`, the
     default, via the orphan fallback, or `orphan-first`) and any
     configured `orphan-first-policy` approval step can be completed
     after drafting
   - roadmap plus sub-issues for multi-task or multi-session work
   - stable non-ready buckets for deferred, needs-decision,
     blocked-by-human, or out-of-scope work
4. **Prefix-first**: resolve the target repository's marker prefix
   before emitting any authoring marker — `roadmap-id`, `blocked-by`,
   `autopilot-suitability`, or `effort`. Use the prefix documented by
   the target repository's onboarding or IDD docs, and ask the user
   instead of guessing when the prefix is not discoverable. Never
   default to this source repository's `idd-skill` prefix in an
   installed bundle.
5. Keep dependencies machine-readable and minimal:
   - roadmap identity via
     `<!-- <marker-prefix>-roadmap-id: ... -->`
   - active child issues via roadmap task-list links
   - issue-to-issue dependencies via `Blocked by #NNN`
   - sequential roadmap dependencies via
     `<!-- <marker-prefix>-blocked-by: ... -->` only when a separate
     roadmap
     must close first
   - keep independent sibling work in roadmap task lists unless a true
     correctness, availability, or ordering constraint requires a
     dependency edge
6. Before publishing a ready orphan, roadmap, or child body, run the
   `audit-authored-issue` linter against it as the mechanical
   pre-publish gate — see
   [Mechanical pre-publish gate](references/contract.md#mechanical-pre-publish-gate)
   in the bundled contract, including the manual fallback for
   `instructions-only` installs with no helper runtime. Resolve every
   reported failure before treating the issue as ready.
7. When the user explicitly authorizes publication, manage the authoring
   label for each created or updated issue:
   - resolve `issueAuthoring.authoringLabelName`, defaulting to
     `status:authoring`
   - create the label with `gh label create` before first use when the
     target repository does not already have it
   - treat label creation or application failure as a publishing blocker
   - apply the label before updating an existing issue
   - create new issues with the label when supported, or apply the label
     immediately after creation
   - if post-create label application fails, close the created issue
     before stopping; deletion needs admin permission the authoring
     agent typically lacks (and `docs/permissions.md` forbids for normal
     IDD), so it is not the default path
   - remove the label from all published issues only after the full set is
     published, the user confirms the result, and the user explicitly
     requests release from the authoring hold for IDD execution
   - leave the label in place if publishing is interrupted before release
8. Stop at the approval boundary. Drafting issues does not authorize
   publishing them or starting the IDD execution loop unless the user
   explicitly asked for that.

## Reference Routing

- For the bundled contract, output schemas, and discoverability guard:
  read [references/contract.md](references/contract.md).
- For the bundled boundary between pre-approval drafting and the IDD
  execution loop: read
  [references/workflow-boundary.md](references/workflow-boundary.md).
- For concrete drafting patterns and example prompts: read
  [references/draft-patterns.md](references/draft-patterns.md).
- When editing this bundle inside the upstream source repository
  (`kurone-kito/idd-skill`), keep the bundled references synchronized
  with its canonical maintenance docs:
  [`docs/issue-authoring-skill.md`](https://github.com/kurone-kito/idd-skill/blob/main/docs/issue-authoring-skill.md)
  and
  [`docs/idd-workflow.md`](https://github.com/kurone-kito/idd-skill/blob/main/docs/idd-workflow.md)
  — upstream's own self-hosting copies, distinct from this repository's
  imported `docs/idd-workflow.md`. Not applicable when working from an
  adopter repository such as this one.
  <!-- setup.windows: relinked from upstream's original relative
  ../../docs/... paths, which resolve incorrectly for this bundle's
  .claude/skills/issue-authoring/ install location and pointed at
  upstream-only maintenance docs this repository does not carry. -->

## Output Checklist

- Preserve low-readiness work in stable buckets instead of dropping it.
- Keep acceptance criteria explicitly verifiable.
- Keep human-dependent setup, review, and approval work isolated from
  ready execution issues whenever possible.
- Link every active child issue from its roadmap body.
- Justify each dependency edge and keep independent sibling work as
  roadmap task-list entries.
- Record reuse or extension decisions when the skill does not create a
  new issue.
- Avoid widening drafting output beyond the user request without saying
  so.
- Run the `audit-authored-issue` linter (or its manual fallback in
  `instructions-only` installs) against every drafted ready body and
  resolve every reported failure before publishing.
- Name a concrete surface to edit and an objective verification for
  every `ready` candidate; route anything else to `needs-decision` or
  ask instead of guessing (the under-clarification stop rule).
- Resolve the target repository's marker prefix before emitting any
  authoring marker; never assume this source repository's `idd-skill`
  prefix in an installed bundle (the prefix-first rule).
