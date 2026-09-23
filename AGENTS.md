# Guidelines for AI Agents

This is the shared, canonical entry point for Codex CLI, OpenCode, and
Grok Build — each auto-loads `AGENTS.md` from the repository root
natively, so no separate file is maintained for any of them. (Grok
Build has a few IDD-specific caveats; see
[`docs/idd-workflow.md`](docs/idd-workflow.md#entry-points-and-auto-load-expectations).)
Following
the [AGENTS.md](https://agents.md) convention, this file is also this
repository's canonical, tool-neutral instruction source: `CLAUDE.md`,
`GEMINI.md`, and
[`.github/copilot-instructions.md`](.github/copilot-instructions.md)
import or point back to it instead of duplicating its content. See
[`docs/ai-strategy.md`](docs/ai-strategy.md) for the rationale.

This project sets up the dev environment for Windows.

When contributing to this repository using AI agents, adhere to the
following guidelines to ensure high-quality contributions that align with
the project's standards and practices:

- The conversational language should match the user's language.
  For example, if the user speaks in Japanese, respond in Japanese.
- However, comments and documentation should be written in English unless
  there is a clear context otherwise.
- If uncertainties, concerns, or other implementation issues arise while
  running in Agent mode, promptly switch to Plan mode and ask the user
  questions. In such cases, provide one or more recommended response
  options. **Grok Build exception**: do not call `enter_plan_mode`
  during IDD work — it blocks non-plan-file edits (see
  [`docs/idd-workflow.md`](docs/idd-workflow.md#entry-points-and-auto-load-expectations)).
  Ask the question directly in your normal response instead.

## IDD (Issue-Driven Development)

This repository uses an Issue-Driven Development workflow for autonomous
and semi-autonomous contribution loops. Before starting IDD work, open
[`.github/instructions/idd-overview-core.instructions.md`](.github/instructions/idd-overview-core.instructions.md)
for the shared claim/marker/safety-gate definitions, then follow
[`docs/idd-workflow.md`](docs/idd-workflow.md) as the phase-by-phase entry
point (Discover → Claim → Work → PR Submit → CI Wait → Review Triage →
Review Fix → Merge → Cleanup → Loop). Phase routing is manual: when a
phase changes, open the next-phase file the current phase instructions
name — this repository does not auto-route between phase files.

See [`docs/idd-policy.md`](docs/idd-policy.md) for this repository's
recorded IDD policy decisions (merge policy, review policy, claim
timing, CI wait, helper runtime, and related settings).

## Coding standards

Mirrors [`.editorconfig`](.editorconfig):

- 2-space indent
- LF line endings
- Trim trailing whitespace, except in Markdown where trailing spaces may
  be significant
- Always end a file with a final newline

Separately — this convention is not encoded in `.editorconfig` — file
naming is lowercase with hyphens, unless a platform or tool convention
requires otherwise (for example the PascalCase
`scripts/Build-Configurations.ps1` and `scripts/Test-PackageIds.ps1`
PowerShell scripts).

## Commit rules

This project follows [Conventional
Commits](https://www.conventionalcommits.org/). A commit message
template is available at [`.gitmessage`](.gitmessage); opt in per clone
with:

```sh
git config commit.template .gitmessage
```

## Verification

Before pushing, run the commands recorded as `commands.pre-push-validate`
in [`.github/idd/config.json`](.github/idd/config.json) — for this
repository that covers markdownlint, cspell, PSScriptAnalyzer, and
Pester.

## IDD Workflow

This project uses Issue-Driven Development (IDD) with parallel AI
agents. Start with [docs/idd-workflow.md](docs/idd-workflow.md) for the
cross-agent entry path and phase routing.

Before starting IDD work, open
`.github/instructions/idd-overview-core.instructions.md`. Open the routed
phase file manually when the current step changes.
