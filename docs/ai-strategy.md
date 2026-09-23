# AI agent instruction strategy

This repository is worked on by several AI coding agents:

- **GitHub Copilot** — reads
  [`.github/copilot-instructions.md`](../.github/copilot-instructions.md);
  GitHub also auto-discovers `AGENTS.md` directly.
- **Codex CLI**, **OpenCode**, and **Grok Build** — each auto-loads
  [`AGENTS.md`](../AGENTS.md) from the repository root natively; no
  dedicated file is maintained for any of them.
- **Claude Code** — reads [`CLAUDE.md`](../CLAUDE.md).
- **Antigravity CLI** (formerly Gemini CLI) — reads
  [`GEMINI.md`](../GEMINI.md).

## Canonical guidance

[`AGENTS.md`](../AGENTS.md) is the single, canonical, tool-neutral
instruction source for this repository, following the
[AGENTS.md](https://agents.md) convention. It carries the
conversational-language rule, the English-comments/docs rule, the
Plan-mode pause rule, this repository's own detailed
"## IDD (Issue-Driven Development)" walkthrough, and the Coding
standards / Commit rules / Verification sections.

`CLAUDE.md` and `GEMINI.md` are thin adapters: a short framing line, a
standalone `@AGENTS.md` import line (Claude Code resolves `@`-imports
natively; whether Antigravity CLI's own import mechanism also resolves
this exact line is unconfirmed — a tool that instead reads the file as
plain text simply sees the literal line either way, which is why the
next item does not depend on import support), and the literal
[shared IDD workflow stub](onboarding/agent-entry-and-verification.md#shared-idd-workflow-stub)
kept verbatim so it stays discoverable without depending on import
support.

`.github/copilot-instructions.md` is a thin pointer plus one genuinely
Copilot-specific note (GitHub Copilot already auto-discovers
`AGENTS.md` directly, so it carries no `@AGENTS.md` import line) and the
same literal stub, path-adjusted for its `.github/` location.

## Change policy

- Edit `AGENTS.md` for any change to repository-specific engineering
  guidance (conversational rules, coding standards, commit rules,
  verification commands, or the IDD walkthrough). The three adapters
  should not need a matching edit for this kind of change.
- Edit an adapter file directly only for framing prose specific to that
  tool (for example, a Copilot-mode terminology note).
- Keep every adapter's "## IDD Workflow" heading and stub wording
  byte-identical to
  [`docs/onboarding/agent-entry-and-verification.md`](onboarding/agent-entry-and-verification.md#shared-idd-workflow-stub)'s
  canonical text, modulo only the `.github/`-relative path adjustment
  `.github/copilot-instructions.md` needs for its own location (and the
  MD013-driven line-wrap shift that adjustment can cause — the rendered
  text stays identical either way). This
  keeps the block mechanically discoverable by that onboarding
  document's checklist and by the `idd-spec-audit` skill, independent of
  whether a given tool's runtime resolves `@`-imports.
- `AGENTS.md` intentionally does **not** also carry a second, literal
  copy of the generic stub: its own "## IDD (Issue-Driven Development)"
  section already references `docs/idd-workflow.md` and drops no
  guidance, which is what the onboarding checklist actually requires. A
  future edit should not try to "complete" the pattern by adding the
  stub there too — that would reintroduce the duplication this file
  exists to remove, in the one file meant to be the single source.

## Maintenance notes

- If a new pointer needs to be reachable from every entry file, add it
  to `AGENTS.md`'s own content and let the adapters carry it forward
  through the `@AGENTS.md` import, plus a directly-stated line in each
  adapter file for a pointer that must stay reachable even where a
  tool's runtime does not resolve `@`-imports (see the `docs/idd-policy.md`
  pointer that ships this way in `CLAUDE.md`, `GEMINI.md`, and
  `.github/copilot-instructions.md` today).
- `idd-spec-audit` and the onboarding checklist in
  `docs/onboarding/agent-entry-and-verification.md` both expect the
  literal "## IDD Workflow" heading and stub prose; do not reword it
  when editing an adapter file's surrounding framing text.

## History

Before this repository's AGENTS.md consolidation
([#189](https://github.com/kurone-kito/setup.windows/issues/189)),
`CLAUDE.md`, `GEMINI.md`, `.github/copilot-instructions.md`, and
`AGENTS.md` each carried an independent, near-identical copy of the same
"Guidelines for AI Agents"
content: the conversational-language rule, the English-comments/docs
rule, the Plan-mode pause rule, and an
"## IDD (Issue-Driven Development)" section pointing at
`docs/idd-workflow.md` and `docs/idd-policy.md`. Four independent copies
of the same guidance trade the single-file asymmetry problem for a
divergence problem the next edit is likely to miss (observed
2026-07-27,
[kurone-kito/idd-skill#1717](https://github.com/kurone-kito/idd-skill/issues/1717)).
This repository moved to the single-source-plus-adapters layout above to
remove that risk while keeping every tool's own expected entry point
intact.
