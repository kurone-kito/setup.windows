# IDD — Concept Ownership Matrix

Use this page to answer "may this actor touch this concept, right now?"
without re-reading every phase file. It is a navigation and quick-check
aid, not a policy surface: it changes no phase behavior and creates no
new rule.

## Derivation and authority disclaimer

This matrix is derived by sweeping the current
`.github/instructions/*.instructions.md` corpus, including the `lite/`
subdirectory. The instruction files remain the sole authoritative source
for phase behavior. Where this document and an instruction file
disagree, the instruction file wins, and the disagreement is a bug in
this document, not a second valid interpretation — please file an issue
so the mismatch can be corrected. This document never overrides, relaxes,
or extends a gate defined in `.github/instructions/`.

## Actor classes

| Actor class           | Meaning                                                                                                                                                                                                                                                                                             |
| --------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Worker session        | The IDD agent instance holding the active claim for an issue, executing phases A5 through F2.5, or holding the coordination-only `roadmap-audit/*` claim while running A1.5 on a roadmap issue.                                                                                                     |
| Merge-capable session | The actor authorized to execute F3. Under `fully_autonomous_merge` this is the same worker session; under `separate_merge_agent` it is a distinct designated session; under `human_merge` it is the human maintainer.                                                                               |
| Human maintainer      | A repository owner or collaborator acting outside the automated loop — approving issues, resolving holds, authorizing forced handoff or an external-check waiver, or merging manually.                                                                                                              |
| Advisory bot          | Copilot's PR review integration plus any bot configured in `advisoryBotLogins` (for example CodeRabbit or a Codex connector). Not a required-reviewer or `CHANGES_REQUESTED` gate, but its review threads still count toward F2's unresolved-threads backlog gate until dispositioned and resolved. |
| GitHub platform       | Mechanical behavior GitHub itself performs once the right input exists — closing-keyword auto-close, CI run execution, mergeability computation.                                                                                                                                                    |

## Concept-ownership matrix

Phases are cited using the routing letters from
[IDD workflow guide](idd-workflow.md) and
[Detailed reference](reference.md). "Creator" is the phase/actor that
first brings the concept into existence for a given issue/PR cycle;
"Mutator" is who may change it afterward; "Verifier" is who reads it
back as evidence for a gate.

<!-- dprint-ignore-start -->
| Concept | Creator | Mutator | Verifier |
| --- | --- | --- | --- |
| Issue body | Human maintainer (or the issue-authoring skill) | Human maintainer; the issue-authoring skill before an active claim or open PR exists; worker session only for roadmap task-list updates (A1.5) | A0-T/A3/A3.5 readiness checks |
| Status / blocker labels (`status:authoring`, `status:blocked-by-human`, `status:needs-decision`, `idd:ready`, `triage:{outcome}`) | Human maintainer for the ready label; issue-authoring skill for `status:authoring`; worker session for `status:needs-decision`/`status:blocked-by-human` (A1.5 non-autonomous gap, E6 escalation) or the optional diagnostic `triage:` label (A4.5) | Issue-authoring skill removes `status:authoring`; human maintainer removes `status:blocked-by-human`/`status:needs-decision`/`idd:ready` regardless of which actor applied it — resolving that blocker is the human judgment the label exists to enforce | A0/A3/A3.5/A4.5 gates |
| Claim marker (`claimed-by`) | Worker session, A5 | Worker session (heartbeat, `unclaimed-by`) or a later worker session (stale takeover, A5/Resume-stall S5) | Claim revalidation gate before every mutation; Resume Step 1 |
| Activation-nonce marker | Worker session, alongside every fresh claim activation (A5) | Immutable once posted; superseded implicitly by the next activation's nonce | Claim verification step 5; claim revalidation gate |
| Heartbeat | Worker session holding the claim, re-posting `claimed-by` with the same `{claim-id}` | Worker session, every ≤ 12 h while holding | Claim-state parsing rule 3.5 (heartbeat branch invariant) |
| Roadmap task list | Human maintainer (or issue-authoring skill) at roadmap authoring time | Worker session running the A1.5 roadmap-audit claim (adds follow-up links, keeps sequencing current) | A1.5 completion audit |
| Branch | Worker session, B1 | Worker session (pushes at D2/E12; merge-from-`main` at E-phase sync/E11) | B1 self-check; cwd-vs-claim check in the claim revalidation gate |
| Worktree | Worker session, B1 | Worker session (reuse/recreate on takeover) | B1 self-check; worktree-local claim lock |
| PR title / body | Worker session, D3 | Worker session (D3.5 closing-keyword self-check edits, later E-phase updates) | D3.5 self-check; F2 disposition-evidence check |
| Closing keyword | Worker session, in the PR body at D3 | Worker session, if D3.5 finds it missing or miswrapped | D3.5 self-check; GitHub platform at F3 merge (mechanical auto-close) |
| Review threads | Human reviewer or advisory bot, during CI/E-phase | Worker session (replies at E6/E13); reviewer (reopen) | E1 snapshot; E7 verification; F2 unresolved-threads gate |
| `review-watermark` / `review-baseline` markers | Worker session, E1/E2 | Worker session (re-post to refresh; minimize a superseded one as `OUTDATED`) | F2/F3 review-currency check |
| Disposition replies (`**Accepted**` / `**Rejected**` / `**Awaiting maintainer decision**`) | Worker session, E6/E13 | Worker session mirrors a human maintainer's later decision onto an AMD thread | E7 verifier; F2/F3 disposition-evidence gate |
| `advisory-wait` / `advisory-wait-recovery` markers | Worker session, E14 or F2/F3 per the advisory-wait protocol | Worker session (minimize a superseded same-PR marker as `OUTDATED`) | AW1-AW3 decision table |
| CI checks | GitHub platform, triggered by push or review events | Worker session may request a rerun, subject to `ciWait.rerunPolicy` | D4/E15/F2 CI gate |
| Live status digest | Worker session (or merge-capable session), after any phase transition | Worker session, re-validating the claim before each edit | Human-facing only — never authoritative for a state transition |
| Forced-handoff marker | Human maintainer only (`forced-handoff: human-gated`, an authorized actor) | Not mutated once posted | Successor worker session (Claim-state parsing rule 7); Resume Step 0/1 |
| External-check waiver comment (`idd-external-check-waiver`) | Human maintainer only, under the repository's `ciGate.externalCheckWaivers` policy | Not mutated once posted; superseded by a fresh waiver | F2/F3 CI gate (`waiverEvidence` checks) |
| Merge commit | Merge-capable session, F3 | Not mutated after creation | F2/F2.5/F3 gate checklist, immediately before merge |
| Generated instruction-file / doc mirrors — **only in a repository that runs the sync tooling** (e.g. the idd-skill source repository's own `idd-template/` → `.github/instructions/`, `idd-template/docs/` → `docs/`; a typical adopter repository has no `idd-template/` after import, so this concept does not apply there) | Worker session, alongside the canonical source edit that requires it | Worker session, via the sync tooling `--apply` mode | The docs/instructions audit tooling |
<!-- dprint-ignore-end -->

## Terminal-state gating

A concept's **terminal state** is the point after which the loop no
longer expects further routine mutation for that issue/PR cycle. This
section names, for each concept with a meaningful terminal state, which
actor/phase is authorized to reach it — a stricter question than the
matrix's general "who mutates" column above.

<!-- dprint-ignore-start -->
| Concept | Terminal state | Authorized actor / phase |
| --- | --- | --- |
| Issue | Closed | GitHub platform via the PR's closing keyword at F3 merge (execution-leaf issues); worker session running the A1.5 roadmap-audit claim (roadmap issues); worker session directly at B2.0 on a verified supersession hit (acceptance criteria already met by a merged sibling PR); human maintainer may also close manually |
| Claim | Released or superseded | Worker session (`unclaimed-by` on abort); a later worker session via stale takeover (A5, Resume-stall S5); human-gated forced handoff transfers it without a release step |
| Roadmap task list / roadmap issue | Closed | Worker session running the A1.5 roadmap-audit claim, only once every child and descendant is closed or otherwise complete |
| Branch and worktree | Deleted | Worker or merge-capable session, F4 — only after F3 merge succeeds |
| Review thread | Resolved | Worker session, immediately after posting a disposition reply (E6/E13) — **except** an `**Awaiting maintainer decision**` reply, which leaves the thread unresolved until a maintainer responds (F2's unresolved-threads gate relies on this); or a human reviewer resolving their own thread |
| PR | Merged | Merge-capable session, F3, only once the full F2/F2.5 gate checklist holds |
| `review-watermark` / `review-baseline` / `advisory-wait*` markers | Superseded / minimized as `OUTDATED` | Worker session, after a newer valid marker of the same kind exists for the same claim or HEAD |
| Claim-marker chain (`claimed-by`/`unclaimed-by`/heartbeat) | Superseded / minimized as `OUTDATED` | Worker session, but **only** the prior claim-id's chain after a verified `supersedes: <prior-id>` takeover — a same-claim heartbeat chain must never be hidden; it is the active-claim audit trail |
| External-check waiver | Expired, or consumed | Worker session, rerunning the waived check so it reflects the waiver; expiry itself is a time-driven transition (`expiresAt`) that needs no actor |
| Blocked-by-human / needs-decision label | Removed | Human maintainer only, after resolving the underlying blocker |
<!-- dprint-ignore-end -->

No advisory bot ever takes any concept to a terminal state: advisory
findings are input to a worker session's disposition, never a gate a
bot satisfies by itself.

## See also

- [Core IDD concepts](concepts.md) for the vocabulary behind these rows.
- [Detailed reference](reference.md) for the phase-file map these
  citations point into.
- [IDD policy constants](policy-constants.md) for the timing values
  (stale age, heartbeat interval, advisory windows) referenced above.
