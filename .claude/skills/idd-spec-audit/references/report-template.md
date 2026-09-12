# IDD Spec Audit Report

Fill in every bracketed placeholder. Do not omit a rule-set section
even when it has zero findings — write "No findings." instead of
deleting the heading, so a reader can tell the rule set ran rather than
was skipped.

## Run metadata

- **Date**: `[ISO date the audit ran]`
- **Passes (N)**: `[integer, default 3]`
- **Scope swept**: `[list every in-scope path actually read this run]`
- **Aggregation**: union with overlap dedup, no quorum filter

## R1 — Leaked session context

`[repeat per finding; write "No findings." if empty]`

- **File**: `[path]`
- **Location**: `[line number or section heading]`
- **Quote**: `[short quote of the offending text]`
- **Why it is a finding**: `[one line]`
- **Appeared in**: `[K]/[N]`

## R2 — Cross-file contradictions (closed v1 concept index)

`[repeat per finding; write "No findings." if empty]`

- **Concept**: `[one entry from the closed v1 index]`
- **Files in conflict**: `[path A]` vs. `[path B]`
- **Quote A**: `[short quote]`
- **Quote B**: `[short quote]`
- **Why they conflict**: `[one line]`
- **Appeared in**: `[K]/[N]`

## R3 — Fresh-memory completability

`[repeat per finding; write "No findings." if empty]`

- **File**: `[path]`
- **Location**: `[line number or section heading]`
- **Quote**: `[short quote of the offending text]`
- **What is missing**: `[unresolved reference / implied prerequisite /
  missing exit condition / half-named cross-reference]`
- **Appeared in**: `[K]/[N]`

## R4 — Automation blockers (autonomy cross-check)

`[repeat per finding; write "No findings." if empty]`

- **File**: `[path]`
- **Location**: `[line number or section heading]`
- **Quote**: `[short quote of the confirm/escalate instruction]`
- **Autonomy Contract row**: `[matching mutation row, or "no row —
  default irreversible applies"]`
- **Classification**: `[Reversible / Irreversible]`
- **Why it is a finding**: `[one line — only Reversible rows attached
  to an unneeded confirmation gate qualify]`
- **Appeared in**: `[K]/[N]`

## R5 — Restatement discipline (closed v1 concept index)

`[repeat per finding; write "No findings." if empty]`

- **File**: `[path]`
- **Location**: `[line number or section heading of the restatement]`
- **Restatement quote**: `[short quote of the restating text]`
- **Canonical rule**: `[path#section or line the restatement diverges
  from]`
- **Canonical quote**: `[short quote of the canonical rule]`
- **Scope divergence**: `[broader / narrower / unconditional-vs-conditional
  — one line]`
- **Recommended remedy**: `[cite the canonical section instead of
  restating it inline]`
- **Appeared in**: `[K]/[N]`

## Summary

- **Total findings**: `[count across all five rule sets]`
- **Files touched by at least one finding**: `[count]`
- **Notable patterns across passes**: `[one or two lines, or "None."]`
