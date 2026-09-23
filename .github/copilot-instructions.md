# Guidelines for AI Agents

This is the GitHub Copilot entry point. On GitHub.com, Copilot's
**cloud agent** and **code review** surfaces auto-discover
[`AGENTS.md`](../AGENTS.md) at the repository root directly — no import
line is needed here for them. **GitHub.com Copilot Chat does not**: it
reads only this file and does not treat `AGENTS.md` as a supported
instruction source, so the guidance below is repeated here for that
surface specifically, rather than only pointed at. (Support differs by
IDE/extension surface too — see `docs/ai-strategy.md` if you need the
detail — so treat "auto-discovers" as GitHub.com-specific, not
universal.) `AGENTS.md` is this repository's canonical, tool-neutral
instruction source regardless; see
[`../docs/ai-strategy.md`](../docs/ai-strategy.md) for the rationale.

- The conversational language should match the user's language.
  For example, if the user speaks in Japanese, respond in Japanese.
- However, comments and documentation should be written in English unless
  there is a clear context otherwise.
- If uncertainty, hidden risk, or missing context blocks a safe change,
  pause the current action and ask a direct question instead of
  continuing autonomously — the same guidance `AGENTS.md` states as
  "switch to Plan mode," restated here without assuming a fixed mode
  name, since Copilot's own mode terminology can vary by surface and
  version.

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
