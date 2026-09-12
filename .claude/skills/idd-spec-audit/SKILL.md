---
name: idd-spec-audit
description: Semantic audit of the IDD instruction corpus for leaked session context, cross-file contradictions, fresh-memory completability gaps, automation blockers, and restatement-discipline drift. Use on request to audit .github/instructions, the issue-authoring skill bundle, and the installed agent entry files (CLAUDE.md, AGENTS.md, GEMINI.md, .github/copilot-instructions.md). Read-only — never edits files or mutates issues.
---

# IDD Spec Audit

<!-- cspell:words soloscrum -->

`scripts/audit-docs.mjs` catches byte-level drift — sync-pair mismatches,
budgets, config-vs-instruction agreement — but not semantic drift: prose
that contradicts a sibling file, leaked session context, passages that
are not completable from a cold read, or wording that stalls an
autonomous step. This skill runs that check as N parallel LLM read
passes, adapted from `mew-ton/soloscrum`'s `define-pr-lifecycle` audit
model.

## Scope

- **Audit targets** (findings may cite these): `.github/instructions/**/*.md`
  (including `lite/`), the issue-authoring skill bundle at its
  installed location, and every agent entry file present in this
  installation (`CLAUDE.md`, `AGENTS.md`, `GEMINI.md`, and
  `.github/copilot-instructions.md`). All but the first are
  conditional on the adopter's own setup: onboarding creates each
  entry file unless the operator explicitly opted out of it, the
  issue-authoring companion is opt-in, and
  `.github/copilot-instructions.md` is touched only if it already
  existed — skip an audit target that does not exist in the current
  installation rather than fail the run over it. Cover every present
  entry file, not just `CLAUDE.md`: onboarding requires `CLAUDE.md`,
  `AGENTS.md`, and `GEMINI.md` to agree on repository-specific
  guidance, so a cross-file contradiction (R2) or a restatement-scope
  drift (R5) can land in any of them. Audit every target that does
  exist regardless of whether this installation happens to regenerate
  it from an upstream source (for example, this source repository
  regenerates `.github/instructions/**` from `idd-template/` via
  `audit/sync-manifest.json`) — this skill audits the corpus a worker
  session actually reads, not any upstream source, so being a
  regenerated target never exempts a file here.
- **Reference-only inputs** (read for R2/R4, never a finding target):
  `docs/idd-concept-ownership.md` (R2's closed concept-index seed) and
  `docs/idd-autonomy-contract.md` (R4's reversible/irreversible source
  of truth), both at `docs/` in an installed repository. Both are read
  in full every pass.
- **Out of scope as an audit target / finding source**: this skill's
  own bundle wherever it is installed (`skills/idd-spec-audit/**` — the
  skill necessarily reads its own bundle, this `SKILL.md` and
  `references/report-template.md`, to run at all, but no finding ever
  cites a file there); any generated mirror tree in this installation,
  if one exists (for example, in this source repository, `.claude/**`,
  since every file there mirrors a canonical source elsewhere); and
  every other file under `docs/**` besides the two reference-only
  inputs above (summary docs rely on the files they cite by design, so
  they are not audited as if they were the primary spec).

## Rule sets

Run all five rule sets on every pass; do not skip one to save time. A
finding names the rule set, the file, the line or section, and a short
quote of the offending text.

### R1 — leaked session context

Flag prose that reads as belonging to one session's transcript rather
than a durable spec: time-relative phrasing without an absolute anchor
("recently", "the issue we just fixed"), first-person session voice
("I noticed", "we decided earlier"), narration of an edit instead of a
stated rule ("changed this to require X"), or a workaround described in
prose with no tracking link back to the issue that motivated it.

### R2 — cross-file contradictions (closed v1 concept index)

Compare every in-scope file against every other in-scope file for a
direct contradiction over the same concept. Check only the concepts
below — this is a **closed v1 index**; do not add concepts to it while
auditing. Expanding the index is a spec change, not an in-audit
decision — file an issue instead of widening scope mid-run. The index
is finalized against IDD — Concept Ownership Matrix
(`docs/idd-concept-ownership.md`, `#1593`):

- claim-marker and activation-nonce semantics;
- advisory-convergence satisfaction;
- merge-gate order (F2/F2.5/F3);
- the "ready = absence of `status:*` labels" definition;
- phase-digest rules;
- forced-handoff marker semantics;
- the suitability/effort footer contracts.

### R3 — fresh-memory completability

Flag a passage that a worker session starting from a cold read (no
prior conversation, no memory of another file) could not complete:
an unresolved reference ("as described above" with no anchor), an
implied prerequisite never stated as a precondition, a missing exit
condition (a loop or wait with no stated end state), or a half-named
cross-reference (a phase or marker name used before it is defined).

### R4 — automation blockers (autonomy cross-check)

Cross-check every instruction that asks an agent to pause, confirm, or
escalate against IDD Autonomy Contract (`docs/idd-autonomy-contract.md`,
`#1592`)'s reversible/irreversible classification, using that table as
a comparison baseline rather than re-deriving it from prose — but not
as unconditionally authoritative: the contract's own derivation
disclaimer states that on any disagreement with an instruction file,
the instruction file wins and the contract is the one that needs
correcting:

- an instruction to "confirm with the user" (or equivalent) attached to
  a mutation the contract classifies **Reversible** is a finding only
  once the instruction's own described undo path confirms the mutation
  really is reversible — its named undo path means no confirmation
  gate is needed there;
- the same phrase attached to a mutation the contract classifies
  **Irreversible** is expected behavior and must never be flagged;
- when the table's classification looks wrong against the
  instruction's actual described behavior, do not flag the
  instruction as defective — `docs/idd-autonomy-contract.md` is out of
  scope as a finding target, so note the suspected contract drift
  outside this skill's normal finding flow instead (preventive; no
  observed incident yet — #2782).

A mutation with no row in the contract falls back to the contract's own
default (irreversible); that default governs the contract itself; do
not extend R4 to independently police no-row mutations beyond the two
cases above.

### R5 — restatement discipline (closed v1 concept index)

Flag a passage that restates a rule defined canonically elsewhere in
the corpus when the restatement's scope does not match the canonical
rule's scope: broader than the canonical rule, narrower than it, or
phrased as unconditional where the canonical rule is conditional (has
stated exceptions, applies only under a named runtime profile, or only
within a bounded phase range).

**Scope is the same closed v1 concept index R2 uses** — reuse the
exact list in [R2](#r2--cross-file-contradictions-closed-v1-concept-index)
above rather than introduce a second, open-ended index. A restatement
of a concept outside that index is out of R5's scope; do not flag it,
no matter how sloppily it is worded. This keeps R5 from treating every
emphatic sentence in the corpus as a finding — the rule exists to
catch a scope drift on the seven concepts already load-bearing enough
to have a closed index, not to police prose style generally.

**Preferred remedy**: cite the canonical section instead of restating
it inline. Prefer `See [<section>](<path>#<anchor>)` (or an equivalent
plain-text pointer to the file/section) over reproducing a
multi-clause rule's conditions in a second location — inline
restatement of a multi-clause rule is the exact failure mode this rule
set exists to catch, and the instruction bundles are already close to
their byte budgets, so citing is also the cheaper fix. Note the
preferred remedy in the finding so the reader does not have to
re-derive it.

## Execution model

- Run **N parallel, independent, read-only** passes over the scope
  above, skipping any Audit target absent from this installation (see
  the Scope section's conditional-target note). Default `N = 3`;
  accept a `--passes N`-style argument to adjust it.
- **Aggregate by union**, deduplicating findings that describe the same
  file/section/issue across passes. Annotate each surviving finding
  with `Appeared in: K/N` (how many of the N passes independently
  raised it) as **informational context only**.
- **Never apply a quorum filter.** A finding raised by only one pass is
  reported exactly like one raised by all N — sampling variance is not
  evidence of invalidity, and dropping low-`K` findings would silently
  discard true positives that one pass framed differently from the
  others.
- **Read-only, always.** This skill never edits an in-scope file and
  never opens, closes, comments on, or labels a GitHub issue. Route
  every finding back through the normal issue-authoring flow (see the
  `issue-authoring` skill) for a human or a later session to act on;
  when the issue-authoring companion is not installed (Scope's
  conditional-target note), route findings through this
  installation's normal manual issue-filing process instead.
- Write the aggregated result using
  [references/report-template.md](references/report-template.md).

## See also

- [references/report-template.md](references/report-template.md) for
  the report shape.
- IDD Autonomy Contract (`docs/idd-autonomy-contract.md`) — R4's
  closed source of truth.
- IDD — Concept Ownership Matrix (`docs/idd-concept-ownership.md`) —
  R2's concept-index seed.
