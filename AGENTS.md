# Guidelines for AI Agents (Codex CLI / OpenCode)

This is the shared entry point for Codex CLI and OpenCode; no
OpenCode-specific file is maintained separately.

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
  options.

## IDD (Issue-Driven Development)

This repository uses an Issue-Driven Development workflow for autonomous
and semi-autonomous contribution loops. Before starting IDD work, open
[`.github/instructions/idd-overview-core.instructions.md`](.github/instructions/idd-overview-core.instructions.md)
for the shared claim/marker/safety-gate definitions, then follow
[`docs/idd-workflow.md`](docs/idd-workflow.md) as the phase-by-phase entry
point (Discover → Claim → Work → PR Submit → CI Wait → Review Triage →
Review Fix → Merge → Cleanup → Loop). Phase routing is manual: when a
phase changes, open the routing target the current phase file names —
this repository does not auto-route between phase files.

See [`docs/idd-policy.md`](docs/idd-policy.md) for this repository's
recorded IDD policy decisions (merge policy, review policy, claim
timing, CI wait, helper runtime, and related settings).
