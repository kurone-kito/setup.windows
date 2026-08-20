# Onboarding Reference — Agent Entry and Verification

Use this reference alongside `idd-template/ONBOARDING.md` when you need
the detailed agent-entry examples and expanded verification guidance
that the thin onboarding entry point now links to.

This page is the detailed companion for:

- Step 5 — update agent entry files
- Step 6 — verification checklist

## Agent entry files

By default, leave the target repository with root entry files for every
manually-routed non-Copilot agent named in `docs/idd-workflow.md`:
`CLAUDE.md`, `AGENTS.md`, and `GEMINI.md`.

Keep these rules explicit:

- If the file already exists, append or adapt an IDD workflow section
  without replacing unrelated repository guidance.
- If the file is missing, create a minimal stub. When at least one
  existing file among `CLAUDE.md`, `AGENTS.md`, `GEMINI.md`, or an
  already-present `.github/copilot-instructions.md` already carries
  repository-specific guidance beyond the shared IDD workflow section,
  do not let the new stub drop it: add a short pointer in the new file
  to the existing file(s) that own that guidance, instead of copying
  the prose into every stub — several copies trade the
  asymmetry problem for a divergence problem the next edit will miss
  (observed 2026-07-27, kurone-kito/idd-skill#1717). Apply this the
  same way for `CLAUDE.md`, `AGENTS.md`, and `GEMINI.md`; no runtime is
  a special case, and `.github/copilot-instructions.md` counts as a
  guidance source even though it isn't itself one of the three stubbed
  files. If guidance is already split across more than one existing
  file with different content, point the new stub at every file that
  owns part of it (or consolidate first) — a pointer to only one owner
  would repeat the same drop this rule exists to prevent. Where no
  existing file carries repository-specific guidance, the plain stub
  below remains correct.
- Only skip creating a missing root agent entry file when the operator
  explicitly opts out of adding new files.

**`excludeAgent` warning**: `idd-overview-core.instructions.md` sets
`excludeAgent: "code-review"` in its frontmatter, and that is correct
there — it keeps the review agent out of the IDD _execution_ protocol
files that only an implementing agent needs. If the target
repository's repository-specific engineering guidance instead lives in
its own `.github/instructions/*.instructions.md` constraint file, do
not cargo-cult that frontmatter onto it. `excludeAgent` belongs on IDD
protocol files, not on constraint files — copying it onto a constraint
file hides those rules from precisely the reviewer that most needs to
see them (preventive; no observed incident yet).

### Shared IDD workflow stub

All three root entry files should point agents to the same workflow
entry path:

```markdown
## IDD Workflow

This project uses Issue-Driven Development (IDD) with parallel AI
agents. Start with [docs/idd-workflow.md](docs/idd-workflow.md) for the
cross-agent entry path and phase routing.

Before starting IDD work, open
`.github/instructions/idd-overview-core.instructions.md`. Open the routed
phase file manually when the current step changes.
```

### CLAUDE.md

If `CLAUDE.md` already exists, add the shared IDD workflow section
above and adapt the surrounding wording to the existing document style.

If `CLAUDE.md` does not exist, create a minimal file such as below.
When `AGENTS.md`, `GEMINI.md`, or an existing
`.github/copilot-instructions.md` already carries repository-specific
guidance, add one line near the top per owning file, pointing to it
— for example, `See AGENTS.md for repository-specific rules.` —
instead of copying that guidance here:

```markdown
# Guidelines for AI Agents

## Immediate rules

- Match the conversational language to the user's language.
- Write comments and documentation in English unless there is a clear
  project-specific reason otherwise.
- If uncertainty, hidden risk, or missing context blocks a safe change,
  stop and ask a concise question before proceeding.

## IDD Workflow

This project uses Issue-Driven Development (IDD) with parallel AI
agents. Start with [docs/idd-workflow.md](docs/idd-workflow.md) for the
cross-agent entry path and phase routing.

Before starting IDD work, open
`.github/instructions/idd-overview-core.instructions.md`. Open the routed
phase file manually when the current step changes.
```

### AGENTS.md (for Codex CLI, OpenCode, and Grok Build)

`AGENTS.md` is the shared agents.md-standard entry file for Codex CLI,
OpenCode, and Grok Build: each auto-loads `AGENTS.md` from the
repository root natively, so this single file covers those runtimes
and neither OpenCode nor Grok Build needs a dedicated root file of its
own. Do not create `GROK.md`. `idd-doctor` still checks only
`AGENTS.md`, `CLAUDE.md`, and `GEMINI.md` — do not add a `GROK.md`
check.

If `AGENTS.md` already exists, add the shared IDD workflow section and
keep the wording explicit that Codex CLI, OpenCode, and Grok Build
agents should manually open
`.github/instructions/idd-overview-core.instructions.md`
and the routed phase file before starting IDD work.

If `AGENTS.md` does not exist, create a minimal file such as below.
When `CLAUDE.md`, `GEMINI.md`, or an existing
`.github/copilot-instructions.md` already carries repository-specific
guidance, add one line near the top per owning file, pointing to it
— for example, `See CLAUDE.md for repository-specific rules.` —
instead of copying that guidance here:

```markdown
# Guidelines for AI Agents

## Immediate rules

- Match the conversational language to the user's language.
- Write comments and documentation in English unless there is a clear
  project-specific reason otherwise.
- If uncertainty, hidden risk, or missing context blocks a safe change,
  stop and ask a concise question before proceeding.

## IDD Workflow

This project uses Issue-Driven Development (IDD) with parallel AI
agents. Start with [docs/idd-workflow.md](docs/idd-workflow.md) for the
cross-agent entry path and phase routing.

Before starting IDD work, open
`.github/instructions/idd-overview-core.instructions.md`. Open the routed
phase file manually when the current step changes.
```

#### OpenCode: optional `opencode.json` recipe

OpenCode's native `AGENTS.md` auto-load already delivers the IDD
workflow stub above to every session; the steps below are an
**optional** Copilot-parity recipe, not a requirement.

- OpenCode's `opencode.json` `instructions` array can point at
  additional rule files, but every listed file loads
  **unconditionally** into every session — unlike GitHub Copilot's
  `applyTo` frontmatter, which OpenCode does not read (frontmatter in
  a loaded file is inert there). Skip this recipe for weak or local
  models (see
  [Weak-model guardrails](../idd-workflow.md#weak-model-guardrails)):
  the extra context can crowd out task-relevant content instead of
  helping.
- When an operator does opt in, list only the shared entry file, not
  the whole `.github/instructions/` directory, to approximate the
  Copilot `applyTo` scoping without flooding every session:

  ```json
  {
    "$schema": "https://opencode.ai/config.json",
    "instructions": [".github/instructions/idd-overview-core.instructions.md"]
  }
  ```

- If the operator installs the optional `issue-authoring` companion
  from Step 2 under one of the native roots OpenCode reads —
  `.claude/skills/`, `.opencode/skills/`, or `.agents/skills/` — it is
  already available without an additional copy. Keep the selected
  destination recorded in the onboarding policy; do not add the same skill
  ID to another root merely to support a second runtime (preventive; no
  observed incident yet).
- If a target repository runs OpenCode as an autonomous worker under
  its own GitHub identity (not just an interactive assistant), add
  that login to `trustedMarkerActors` (and the advisory-bot lists if
  it also reviews) in `.github/idd/config.json` — a config-values edit
  only; `schemas/policy.schema.json` stays agent-agnostic.

#### Grok Build: no extra root file

Grok Build auto-loads `AGENTS.md` (and `CLAUDE.md` when present). Do
not create `GROK.md`. It discovers the optional `issue-authoring`
companion under `.claude/skills/` the same way OpenCode does — do not
add a `.grok/skills/` install root.

If a target repository runs Grok Build as an autonomous worker under
its own GitHub identity (not just an interactive assistant), add that
login to `trustedMarkerActors` (and the advisory-bot lists if it also
reviews) in `.github/idd/config.json` — a config-values edit only;
`schemas/policy.schema.json` stays agent-agnostic.

### Issue-authoring companion verification

When the optional companion is installed, verify the source-versus-
destination contract separately from the entry-file checks:

- The canonical source inventory remains `skills/issue-authoring/` in the
  idd-skill checkout and includes `SKILL.md` plus all bundled references.
- The selected target destination is recorded alongside the `installed`
  decision in the policy record. The Codex example is
  `.agents/skills/issue-authoring/SKILL.md`.
- The `gh api`, `curl`, and local-copy examples write every source file under
  that selected destination and do not fall back to target
  `skills/issue-authoring/`.
- A default onboarding import adds no checked-in `.agents/skills/` or
  `.opencode/skills/` mirror. A mixed-runtime target uses one native copy
  plus an explicit manual route unless the operator deliberately accepts
  identical duplicates (preventive; no observed incident yet).

### GEMINI.md

If `GEMINI.md` already exists, apply the same IDD workflow section as
`AGENTS.md`, adapted to the Antigravity CLI (formerly Gemini CLI)
wording and still pointing to `docs/idd-workflow.md`.

If `GEMINI.md` does not exist, create a minimal file such as below.
When `CLAUDE.md`, `AGENTS.md`, or an existing
`.github/copilot-instructions.md` already carries repository-specific
guidance, add one line near the top per owning file, pointing to it
— for example, `See AGENTS.md for repository-specific rules.` —
instead of copying that guidance here:

```markdown
# Guidelines for AI Agents

## Immediate rules

- Match the conversational language to the user's language.
- Write comments and documentation in English unless there is a clear
  project-specific reason otherwise.
- If uncertainty, hidden risk, or missing context blocks a safe change,
  stop and ask a concise question before proceeding.

## IDD Workflow

This project uses Issue-Driven Development (IDD) with parallel AI
agents. Start with [docs/idd-workflow.md](docs/idd-workflow.md) for the
cross-agent entry path and phase routing.

Before starting IDD work, open
`.github/instructions/idd-overview-core.instructions.md`. Open the routed
phase file manually when the current step changes.
```

### .github/copilot-instructions.md (if present)

If `.github/copilot-instructions.md` already exists, add a parallel IDD
workflow section there as well so GitHub Copilot execution surfaces
receive the same entry path. Keep the
`excludeAgent: "code-review"` behavior in
`.github/instructions/idd-overview-core.instructions.md`; repository-wide
Copilot guidance may still apply during review.

If `.github/copilot-instructions.md` carries repository-specific
guidance that none of `CLAUDE.md`, `AGENTS.md`, or `GEMINI.md` already
has, it is a guidance source for the carry-over rule above too: point
each newly created stub at it the same way a stub would point at a
sibling entry file.

## Verification details

Use the Step 6 checklist in `idd-template/ONBOARDING.md` as the final
go/no-go gate. When you need the concrete evidence behind those shorter
checks, confirm the detailed items below.

### Imported files and profile artifacts

- [ ] Every `idd-*.instructions.md` file listed in the generated core
      file list is present in `.github/instructions/`.
- [ ] `docs/getting-started.md`, `docs/concepts.md`,
      `docs/customization.md`, `docs/reference.md`,
      `docs/policy-constants.md`, `docs/idd-workflow.md`,
      `docs/idd-review-policy-profiles.md`,
      `docs/idd-helper-scripts.md`,
      `docs/idd-comment-minimization.md`,
      `docs/idd-resume-detail.md`,
      `docs/idd-advisory-wait-shell-fallback.md`,
      `docs/idd-design-rationale.md`, and `docs/permissions.md`
      are present.
- [ ] `profiles/README.md` and the non-default profile artifacts under
      `profiles/` are present.

### Recorded policies and selected companions

- [ ] The operator's selected PR review policy profile is recorded, and
      the matching edit-surface checklist in
      `docs/idd-review-policy-profiles.md` is complete.
- [ ] If the selected PR review policy profile is non-default, the
      matching `profiles/<profile>/README.md` artifact was applied and
      its verification evidence is recorded.
- [ ] The operator's selected review-thread resolution policy is
      recorded, and any non-default profile has matching phase-file
      customizations.
- [ ] The operator's selected critique-loop profile is recorded, and any
      non-default profile has matching phase-file customizations.
- [ ] The operator's selected CI wait policy values
      (`ciWait.runningTimeout`, `ciWait.generationTimeout`,
      `ciWait.rerunPolicy`) are explicitly recorded for the target
      repository.
- [ ] The operator's selected merge policy is recorded in repository
      documentation, the F3 handoff behavior matches that policy, and
      worker credentials match that boundary.
- [ ] Ownership timing policy values `claim-stale-age` and
      `claim-heartbeat-interval` are explicitly recorded for the target
      repository.
- [ ] The selected helper runtime profile is recorded, including whether
      the repository stays on `instructions-only` or opted into
      `package-manager`, `vendored-node`, or `ephemeral-npx`.
- [ ] If the operator opted into issue authoring, the native destination
      recorded in the policy contains `SKILL.md` and every bundled reference
      file.

### Placeholder, marker, and config alignment

- [ ] No `{{...}}` placeholders remain in any copied file.
- [ ] `.github/instructions/idd-overview-core.instructions.md` has
      `applyTo: "**"` and `excludeAgent: "code-review"` in its
      frontmatter.
- [ ] The `Project commands` table in
      `.github/instructions/idd-overview-core.instructions.md`
      contains the correct commands for this project.
- [ ] If the project chooses `issue-scope: orphan-first`, the
      `orphan-first-policy` value is recorded as `none`,
      `maintainer-approved`, or `public-disabled`. Public repositories
      use either `maintainer-approved` or `public-disabled`, not `none`.
- [ ] The `setup-windows-roadmap-id` and
      `setup-windows-blocked-by` marker names in
      `.github/instructions/idd-discover.instructions.md` and
      `.github/instructions/idd-overview-core.instructions.md`
      match the prefix chosen for this project.
- [ ] If `.github/idd/config.json` is used, it matches the recorded
      `iddVersion`, marker prefix, merge/review/thread policies,
      claim timing values, CI wait values, `trustedMarkerActors`, and
      command values.

### Agent entry files

- [ ] `CLAUDE.md` exists and references `docs/idd-workflow.md`, unless
      the operator explicitly opted out of creating it.
- [ ] `AGENTS.md` exists and references `docs/idd-workflow.md`, unless
      the operator explicitly opted out of creating it; this single
      file covers Codex CLI, OpenCode, and Grok Build.
- [ ] `GEMINI.md` exists and references `docs/idd-workflow.md`, unless
      the operator explicitly opted out of creating it.
- [ ] Among the entry files the operator did not opt out of creating,
      `CLAUDE.md`, `AGENTS.md`, and `GEMINI.md` agree on
      repository-specific engineering guidance: each file either
      carries that guidance directly, or points to the file(s) that
      own it (a sibling entry file, an existing
      `.github/copilot-instructions.md`, or more than one when
      guidance is split) — no entry file silently drops guidance
      another existing file already carries (observed 2026-07-27,
      kurone-kito/idd-skill#1717).
- [ ] If `.github/copilot-instructions.md` existed before onboarding,
      it now includes the IDD workflow reference as well.
- [ ] If the operator opted into the optional `opencode.json`
      Copilot-parity recipe, the target repository's `opencode.json`
      lists only
      `.github/instructions/idd-overview-core.instructions.md`.
- [ ] If the operator did not opt into that recipe, no `opencode.json`
      file was added to the target repository as part of onboarding.
