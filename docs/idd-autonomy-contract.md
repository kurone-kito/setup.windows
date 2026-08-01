# IDD Autonomy Contract

<!-- cspell:words unminimize -->

This page classifies every externally visible mutation the IDD loop
performs — GitHub side effects (issue/PR comments, labels, claim
markers, reviewer requests, thread resolution, comment minimization,
merges) and git side effects (branches, commits, pushes) — as one of
two kinds:

- **Reversible**: a clean undo command or reversal path exists, named
  in the row. Some reversible mutations still have an eligibility
  precondition (for example, a stale-claim takeover requires the prior
  claim to be ≥ 24 h old) — that precondition governs when the action
  may run, not whether it can be undone afterward, so the row stays
  Reversible.
- **Irreversible**: no clean undo path exists, or the loop only runs
  it after a dedicated, named gate — a merge-readiness checklist, a
  human-gated policy, or (for a small set of GitHub-minimize actions)
  because no IDD instruction path ever reverses it. The row names the
  governing gate or the reason no reversal path exists.

**Default rule**: a mutation not listed in any table below is treated
as **irreversible** until it is classified here.

## Derivation disclaimer

This document is **derived from** the instruction corpus swept below —
it introduces no autonomy rule the instructions do not already state.
On any disagreement between this page and an instruction file, the
instruction file wins, and the disagreement is itself a bug: file an
issue so this page can be corrected.

## GitHub-minimize convention

Several rows below use `minimize-superseded-markers.mjs` or
`audit-pr-cleanup.mjs` to hide a stale or completed comment
(classifiers `OUTDATED` / `RESOLVED`). GitHub's API technically
supports reversing a minimize (`unminimizeComment`), but no IDD
instruction file ever invokes it — every minimize path in this
workflow is one-directional in practice. This page classifies all such
rows **irreversible** for that reason, stated once here rather than
repeated per row.

## Mutation classification

### Discovery & suitability (A0-A4.5)

No claim exists yet in this group; every row here runs before A5.

| Mutation                                                  | Reversible / Irreversible | Undo path / Governing gate         | Source                                   |
| --------------------------------------------------------- | ------------------------- | ---------------------------------- | ---------------------------------------- |
| Post "A4.5 suitability gate rejection" diagnostic comment | Reversible                | Ordinary comment; no state to undo | A4.5 (`idd-suitability.instructions.md`) |
| Apply optional `triage:{outcome}` label                   | Reversible                | Remove the label                   | A4.5 (`idd-suitability.instructions.md`) |

### Claim & ownership (A5)

| Mutation                                                        | Reversible / Irreversible | Undo path / Governing gate                                                                                                                                                                 | Source                                                                                                                      |
| --------------------------------------------------------------- | ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------- |
| Fresh claim (`claimed-by`, `supersedes: none`)                  | Reversible                | Post `unclaimed-by` with the same `{agent-id}`/`{claim-id}`                                                                                                                                | A5 (`idd-claim.instructions.md`)                                                                                            |
| Stale-claim takeover (`claimed-by`, `supersedes: <prior>`)      | Reversible                | Post `unclaimed-by`; a later session can claim fresh once released                                                                                                                         | A5 pre-check (c); eligible only when the prior claim is stale (≥ 24 h, `claim-stale-age`) and race-safe verification passes |
| Activation-nonce marker                                         | Reversible                | Superseded by the next claim's own nonce; carries no standalone state                                                                                                                      | A5 (`idd-claim.instructions.md`)                                                                                            |
| Heartbeat (`claimed-by`, same `{claim-id}`)                     | Reversible                | No-op if omitted; simply stops refreshing the stale clock                                                                                                                                  | A5 Heartbeat posting                                                                                                        |
| Release claim (`unclaimed-by`)                                  | Reversible                | Re-claim fresh later                                                                                                                                                                       | A5 / Abort (`idd-overview-appendix.instructions.md`)                                                                        |
| Hide superseded claim-chain markers (`OUTDATED`) after takeover | Irreversible              | See GitHub-minimize convention above                                                                                                                                                       | A5 "Hide displaced claim chain on takeover"                                                                                 |
| Consume forced-handoff marker (adopt-verbatim)                  | Irreversible              | Gate: `forcedHandoff.mode: human-gated`, authorized human actor, matching `oldAgentId`/`oldClaimId`/`branch`. Autopilot never authors this marker, only consumes already-recorded evidence | A5 Claim verification; `idd-overview-core.instructions.md` rule 7                                                           |

### Roadmap audit (A1.5)

All rows below run under a `roadmap-audit/<number>-<slug>` coordination
claim, scoped to the roadmap issue only.

| Mutation                                                           | Reversible / Irreversible | Undo path / Governing gate                                                                                                                                               | Source                                                                                                                                  |
| ------------------------------------------------------------------ | ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------- |
| Roadmap-audit coordination claim                                   | Reversible                | Same as Claim & ownership above                                                                                                                                          | `idd-roadmap-audit.instructions.md`                                                                                                     |
| Post "IDD roadmap completion audit" comment + close roadmap        | Irreversible              | Gate: full completion-audit evidence — every child/descendant closed or complete, success criteria verified against repo state, bottom-up nested-roadmap order respected | `idd-roadmap-audit.instructions.md` "Audit passes"                                                                                      |
| Create a new follow-up issue for an autonomous gap                 | Reversible                | Close the created issue                                                                                                                                                  | `idd-roadmap-audit.instructions.md` "Autonomous gaps found"; eligible only after a narrow duplicate/reuse check finds no existing match |
| Link an existing issue as the follow-up for an autonomous gap      | Reversible                | Remove the added link from the roadmap task list                                                                                                                         | `idd-roadmap-audit.instructions.md` "Autonomous gaps found"; the duplicate/reuse check found a matching existing issue                  |
| Update roadmap task list with a follow-up link                     | Reversible                | Edit the roadmap body again                                                                                                                                              | `idd-roadmap-audit.instructions.md` "Autonomous gaps found"                                                                             |
| Apply needs-decision / blocked-by-human label (non-autonomous gap) | Reversible                | Remove the label once the gap is resolved                                                                                                                                | `idd-roadmap-audit.instructions.md` "Non-autonomous gaps found"                                                                         |
| Release roadmap-audit claim                                        | Reversible                | Re-claim if audit resumes                                                                                                                                                | `idd-roadmap-audit.instructions.md`                                                                                                     |

### Work, branch & worktree (B1-B3)

| Mutation                                                       | Reversible / Irreversible | Undo path / Governing gate                                                                                                                              | Source                                                                                                 |
| -------------------------------------------------------------- | ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| Create branch + sibling worktree                               | Reversible                | `git worktree remove` + `git branch -d`                                                                                                                 | B1 (`idd-work.instructions.md`)                                                                        |
| Post/refine the B2 implementation-plan issue comment           | Reversible                | Edit or post a follow-up comment                                                                                                                        | B2 (`idd-work.instructions.md`, `idd-work-lite.instructions.md`)                                       |
| B2.0 verify-then-close (a sibling PR already shipped the work) | Irreversible              | Gate: mechanical evidence only — a closed-by-merged-PR signal or a same-candidate-file signal — verified against the acceptance criteria before closing | B2.0 (`idd-work.instructions.md`)                                                                      |
| Local commit (before push)                                     | Reversible                | `git reset` / amend; nothing published yet                                                                                                              | B3, C5, E9 (`idd-work.instructions.md`, `idd-review-fix.instructions.md`)                              |
| Rebase onto `main` (pre-publication only)                      | Reversible                | `git rebase --abort` before the first push                                                                                                              | D1 (`idd-pr-submit.instructions.md`)                                                                   |
| Merge `main` into the feature branch (post-publication sync)   | Reversible                | `git merge --abort` / local reset — but only before its own push; once pushed it joins the Push row below and is no longer separately undoable          | E11, E-phase branch-sync check (`idd-review-fix.instructions.md`, `idd-review-triage.instructions.md`) |
| Delete local worktree + branch                                 | Reversible                | Can be recreated from the remote branch or claim state                                                                                                  | F4 (`idd-merge.instructions.md`)                                                                       |

### PR publication (D2-D3.5)

| Mutation                                 | Reversible / Irreversible | Undo path / Governing gate                                                                                                                                                  | Source                                                                      |
| ---------------------------------------- | ------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------- |
| First push (publishes the branch)        | Irreversible              | No ordinary undo: force-push is forbidden after publication except a narrow, explicitly-authorized repository exception. Reversal requires a new commit (e.g. `git revert`) | D2 (`idd-pr-submit.instructions.md`)                                        |
| Subsequent push (E12, E15 retries)       | Irreversible              | Same as first push — published history is append-only by policy                                                                                                             | E12 (`idd-review-fix.instructions.md`)                                      |
| Create PR                                | Reversible                | Close the PR                                                                                                                                                                | D3 (`idd-pr-submit.instructions.md`)                                        |
| Edit PR body (closing keyword fix, D3.5) | Reversible                | Edit again                                                                                                                                                                  | D3, D3.5 (`idd-pr-submit.instructions.md`)                                  |
| Request a human/CODEOWNER reviewer       | Reversible                | `gh pr edit --remove-reviewer`                                                                                                                                              | D3, E13 (`idd-pr-submit.instructions.md`, `idd-review-fix.instructions.md`) |

### Review markers & dispositions (E1-E15)

| Mutation                                                                              | Reversible / Irreversible | Undo path / Governing gate                                                               | Source                                                                          |
| ------------------------------------------------------------------------------------- | ------------------------- | ---------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| Post `review-watermark` marker                                                        | Reversible                | Superseded by the next watermark at the next E1 pass                                     | E1 (`idd-review-snapshot.instructions.md`)                                      |
| Post `review-baseline` marker                                                         | Reversible                | Superseded by the next baseline at the next E2 pass                                      | E2 (`idd-review-snapshot.instructions.md`)                                      |
| Hide superseded same-claim watermark/baseline (`OUTDATED`)                            | Irreversible              | See GitHub-minimize convention above                                                     | E1 "Hide superseded same-claim watermarks"                                      |
| Post `**Accepted**` / `**Rejected**` disposition reply                                | Reversible                | Reviewer can reopen the thread or a maintainer can override, prompting a follow-up reply | E6, E13 (`idd-review-triage.instructions.md`, `idd-review-fix.instructions.md`) |
| Post `**Awaiting maintainer decision**` reply                                         | Reversible                | Superseded once the maintainer responds (confirm or override)                            | E6 (`idd-review-triage.instructions.md`)                                        |
| Resolve a review thread                                                               | Reversible                | The reviewer can reopen it; the agent must not undo its own resolution unilaterally      | E6, E13 (`idd-review-triage.instructions.md`, `idd-review-fix.instructions.md`) |
| Escalate + apply needs-decision label, release claim (unresolved `CHANGES_REQUESTED`) | Reversible                | Remove the label and re-claim once the reviewer responds                                 | E6 (`idd-review-triage.instructions.md`)                                        |
| Create a new issue ("reject now, do eventually")                                      | Reversible                | Close the created issue                                                                  | E6 (`idd-review-triage.instructions.md`)                                        |

### Advisory-wait markers (AW1-AW6)

| Mutation                                                      | Reversible / Irreversible | Undo path / Governing gate                                                  | Source                                                   |
| ------------------------------------------------------------- | ------------------------- | --------------------------------------------------------------------------- | -------------------------------------------------------- |
| Post `advisory-wait:` request marker                          | Reversible                | Superseded by the next marker for a later HEAD, or by the SATISFIED outcome | AW3 REQUEST_NEEDED (`idd-advisory-wait.instructions.md`) |
| Post `advisory-wait-recovery:` marker                         | Reversible                | Same as above                                                               | AW3-R (`idd-advisory-wait.instructions.md`)              |
| Post `advisory-reroll:` marker                                | Reversible                | Same as above                                                               | AW6 (`idd-advisory-wait.instructions.md`)                |
| Request/remove primary or secondary bot reviewer              | Reversible                | `gh pr edit --remove-reviewer` / re-request                                 | E14 (`idd-review-fix.instructions.md`)                   |
| Hide superseded `advisory-wait*` markers (`OUTDATED`)         | Irreversible              | See GitHub-minimize convention above                                        | AW3-H (`idd-advisory-wait.instructions.md`)              |
| Approve a gated Actions run (bot-triggered `action_required`) | Reversible                | Does not destroy state; only unblocks a run                                 | `idd-ci.instructions.md` Rerun mechanics                 |

### Merge execution (F2.5-F3)

| Mutation                                                                           | Reversible / Irreversible | Undo path / Governing gate                                                                                                                                                                                                                         | Source                                          |
| ---------------------------------------------------------------------------------- | ------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------- |
| Post merge-policy handoff summary comment (`human_merge` / `separate_merge_agent`) | Reversible                | Ordinary comment; the merge itself (not this comment) is what is gated                                                                                                                                                                             | F2.5 (`idd-merge-handoff.instructions.md`)      |
| `gh pr merge --merge` (plain)                                                      | Irreversible              | Gate: full F2/F2.5/F3 checklist — review currency, advisory convergence `SATISFIED`, all required CI green, zero unresolved actionable threads, claim ownership current, `fully_autonomous_merge` / eligible `separate_merge_agent` policy routing | F3 Gate checklist (`idd-merge.instructions.md`) |
| `gh pr merge --merge --admin` (solo-CODEOWNER fallback)                            | Irreversible              | Gate: the plain-merge Gate checklist fully green **and** `reviewerStates.codeownerSelfApproval.status: clear` with `prAuthorIsSoleEligibleCodeowner: true` and `codeownerEligibilityUnreadable: false`, re-verified immediately before the call    | F3 step 5 (`idd-merge.instructions.md`)         |

### Post-merge cleanup (F4)

| Mutation                                                              | Reversible / Irreversible | Undo path / Governing gate                                                                                                                  | Source                           |
| --------------------------------------------------------------------- | ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------- |
| Minimize PR comments (`RESOLVED` / `OUTDATED`) via `audit-pr-cleanup` | Irreversible              | See GitHub-minimize convention above; additionally gated by the mandatory-apply decision tree (only after PR merged, only eligible classes) | F4 (`idd-merge.instructions.md`) |
| Post cleanup evidence / failure / permission-blocked comment          | Reversible                | Ordinary comment; explicit evidence, not a merge gate                                                                                       | F4 (`idd-merge.instructions.md`) |
| Delete remote branch (when GitHub auto-delete is disabled)            | Reversible                | Content is preserved via the merge commit on `main`; only runs after a successful merge                                                     | F4 (`idd-merge.instructions.md`) |
| Update local `main`                                                   | Reversible                | Trivial fast-forward re-fetch                                                                                                               | F4 (`idd-merge.instructions.md`) |

### Live status digest & hold comments

| Mutation                                             | Reversible / Irreversible | Undo path / Governing gate                                                                                            | Source                                                                                                  |
| ---------------------------------------------------- | ------------------------- | --------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| Create or upsert the `idd-live-status` digest        | Reversible                | Edited freely on the next authoritative re-read; the digest is UI-only and never authoritative for workflow decisions | `idd-overview-appendix.instructions.md` "Live status digest"                                            |
| Post a hold comment (stop and wait for a maintainer) | Reversible                | Ordinary comment; superseded by a follow-up comment once the block clears and the phase resumes                       | `idd-overview-appendix.instructions.md` "Hold / suspend"; invoked across every phase file's hold routes |

### CI recovery

| Mutation                        | Reversible / Irreversible | Undo path / Governing gate                                                  | Source                                   |
| ------------------------------- | ------------------------- | --------------------------------------------------------------------------- | ---------------------------------------- |
| Rerun a CI run (`gh run rerun`) | Reversible                | Idempotent retry; destroys no state; bounded by `ciWait.rerunPolicy` budget | `idd-ci.instructions.md` Rerun mechanics |

## Not covered

Two mutation-adjacent actions are deliberately out of this page because
autopilot never performs them — only a human maintainer does:

- **Authoring a `forced-handoff` marker.** Autopilot only consumes
  already-recorded, human-gated forced-handoff evidence (see Claim &
  ownership above); it never authors one itself.
- **Posting an external-check waiver.** A trusted maintainer authorizes
  skipping a specific registered check under
  `ciGate.externalCheckWaivers`; the loop only reads and validates
  `waiverEvidence`, never posts a waiver.

## Coverage

This page was derived from a full sweep of every
`.github/instructions/*.instructions.md` file (18 files) and every
`.github/instructions/lite/*.instructions.md` file (4 files) in this
repository at authoring time.
