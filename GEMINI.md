# Guidelines for Gemini / Antigravity CLI

This is the Antigravity CLI (formerly Gemini CLI) entry point.
[AGENTS.md](AGENTS.md) is this repository's canonical, tool-neutral
instruction source — see [`docs/ai-strategy.md`](docs/ai-strategy.md)
for the rationale. This file imports it directly below.

@AGENTS.md

See [`docs/idd-policy.md`](docs/idd-policy.md) for this repository's
recorded IDD policy decisions (merge policy, review policy, claim
timing, CI wait, helper runtime, and related settings).

## IDD Workflow

This project uses Issue-Driven Development (IDD) with parallel AI
agents. Start with [docs/idd-workflow.md](docs/idd-workflow.md) for the
cross-agent entry path and phase routing.

Before starting IDD work, open
`.github/instructions/idd-overview-core.instructions.md`. Open the routed
phase file manually when the current step changes.
