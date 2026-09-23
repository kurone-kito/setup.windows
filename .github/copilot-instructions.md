# Guidelines for AI Agents

This is the GitHub Copilot entry point. GitHub Copilot automatically
discovers [`AGENTS.md`](../AGENTS.md) at the repository root, so this
file does not import it explicitly the way `CLAUDE.md`/`GEMINI.md` do —
see [`../docs/ai-strategy.md`](../docs/ai-strategy.md) for the rationale.
`AGENTS.md` is this repository's canonical, tool-neutral instruction
source.

One Copilot-specific note: when uncertainty, hidden risk, or missing
context blocks a safe change, pause the current action and ask a direct
question instead of continuing autonomously — the same guidance
`AGENTS.md` states as "switch to Plan mode," restated here without
assuming a fixed mode name, since Copilot's own mode terminology can
vary by surface and version.

See [`../docs/idd-policy.md`](../docs/idd-policy.md) for this
repository's recorded IDD policy decisions (merge policy, review policy,
claim timing, CI wait, helper runtime, and related settings).

## IDD Workflow

This project uses Issue-Driven Development (IDD) with parallel AI
agents. Start with [docs/idd-workflow.md](../docs/idd-workflow.md) for
the cross-agent entry path and phase routing.

Before starting IDD work, open
`.github/instructions/idd-overview-core.instructions.md`. Open the routed
phase file manually when the current step changes.
