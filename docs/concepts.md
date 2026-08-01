# Core IDD Concepts

Use this page when you want the mental model before reading the phase
rules. It explains the vocabulary that appears throughout the IDD loop
without replacing the authoritative instructions in
`.github/instructions/`.

For the shortest procedural path, start with
[Getting started](getting-started.md). For phase routing and file
ownership, use the [IDD workflow guide](idd-workflow.md).

## IDD as Loop Engineering

**Loop engineering** is the practice of designing the system that runs
an agent through an act -> observe -> decide -> repeat cycle, instead
of hand-prompting each step: its **trigger**, its **topology** (single-
or multi-agent orchestration), its **verifier**, and its **stop
rules**. Anthropic frames the same idea as **agentic loops**; IDD is a
concrete, GitHub-native implementation of it.

| Loop element | IDD's implementation                                                                                                    |
| ------------ | ----------------------------------------------------------------------------------------------------------------------- |
| Trigger      | Discover picks a ready roadmap or orphan issue without silently widening scope.                                         |
| Topology     | The phase pipeline, roadmap decomposition into sub-issues, and worktree-isolated parallel agents.                       |
| Verifier     | CI gates plus advisory bots (Copilot / CodeRabbit / Codex), review triage, and disposition / unresolved-thread gates.   |
| Stop rules   | Merge gates recheck claim, freshness, CI, advisory, and review state; the issue being closed is the terminal condition. |

Looping harder is not automatically looping better: assuming enough
iterations will eventually converge on a correct result ("loopmaxxing")
is a known failure mode, not a property that emerges for free. IDD
avoids it by pairing every loop turn with the verifier and stop-rule
gates above, and by recording claims, review snapshots, decisions, and
cleanup markers as the durable issue-comment state described throughout
this page — so progress is auditable rather than assumed.

See [Discover](../.github/instructions/idd-discover.instructions.md),
[review triage](../.github/instructions/idd-review-triage.instructions.md),
and [merge execution](../.github/instructions/idd-merge.instructions.md)
for the phase files behind this table.

## Claims and Heartbeats

IDD agents coordinate through GitHub issue comments instead of a
central scheduler. When an agent starts work, it posts a machine-readable
claim marker that names the issue, branch, agent, and claim identifier.
Other agents read the issue comment history before starting so they do
not pick the same work.

The claim identifier is a correlation token for one claim lineage. It is
not a secret, and an agent must already have recorded and verified that
token before treating it as its own. Heartbeat comments refresh a live
claim so long-running sessions do not look abandoned.

Operational details live in
[claim phase](../.github/instructions/idd-claim.instructions.md) and the
shared definitions in
[IDD overview](../.github/instructions/idd-overview-core.instructions.md).

## Review Snapshots

PR review activity can change while an agent is fixing feedback. IDD
uses review snapshots to mark the review state that was inspected at a
specific PR head. A later phase can then tell whether new review
activity arrived after that point.

Snapshots keep review handling resumable. If a different agent resumes,
it can compare the recorded snapshot with current PR activity instead of
guessing which comments were already seen.

See the
[review snapshot phase](../.github/instructions/idd-review-snapshot.instructions.md)
for the exact marker format and collection rules.

## PATH A and PATH B

IDD separates review findings into two paths:

- **PATH A** is actionable feedback. Human review comments, requested
  changes, and critique findings belong here when they may require a
  code change or maintainer decision.
- **PATH B** is advisory feedback. Copilot and CI advisory bot comments
  are tracked for traceability, accepted or rejected during triage, and
  closed out without entering the review-fix phase.

This split keeps advisory noise visible without letting it block the
same way as human requested changes. When a source is ambiguous, IDD
treats it as PATH A until a maintainer narrows it.

See the
[review triage phase](../.github/instructions/idd-review-triage.instructions.md)
for scoring, disposition, and marker requirements.

## Advisory Review Waits

The distributed default PR policy includes GitHub Copilot as an
advisory reviewer. Advisory review can lag behind CI or human review, so
IDD has a wait protocol that decides when to keep waiting, request a
re-review, proceed, or hold.

This is a policy choice, not a requirement of the core issue and claim
model. Repositories that do not want the default Copilot advisory policy
can choose another review profile and update the listed phase files.

See [review policy profiles](idd-review-policy-profiles.md) and the
[advisory wait protocol](../.github/instructions/idd-advisory-wait.instructions.md).

## Merge Freshness Gates

Before merge, IDD rechecks the claim, PR head, CI state, review state,
unresolved conversations, and recent comments. These gates make sure the
agent merges the same work that was validated and does not race with a
new review or another session.

The merge phase is also where repository credential policy matters.
Many teams should let a worker agent prepare the PR, then let a human or
separate merge-capable agent run the final gate.

See [permissions and threat model](permissions.md),
[pre-merge conditions](../.github/instructions/idd-pre-merge.instructions.md),
and [merge execution](../.github/instructions/idd-merge.instructions.md).

## Cleanup Markers

IDD leaves an audit trail in issues and pull requests so another agent
can resume work. After a PR merges, cleanup can hide stale operational
markers and completed feedback when it is safe, while preserving the
history GitHub needs for auditability.

Cleanup is intentionally conservative. It should make active issues and
PRs easier to read without deleting the evidence needed to understand
what happened.

See [comment minimization](idd-comment-minimization.md) for the live
status digest contract, cleanup policy, and helper notes.

## Where to Read Next

- [IDD as Loop Engineering](#idd-as-loop-engineering) for the
  trigger/topology/verifier/stop-rules framing this page opens with.
- [Getting started](getting-started.md) for the first adoption path.
- [IDD workflow guide](idd-workflow.md) for routing and phase ownership.
- [Permissions and threat model](permissions.md) before granting
  credentials.
- [Review policy profiles](idd-review-policy-profiles.md) before
  changing PR review behavior.
