# IDD — Roadmap Audit Phase (A1.5)

Read this file after A1 selects an open roadmap and before A2
enumerates child issues.

## A1.5 — Audit completed roadmaps

After A1 selects an open roadmap, inspect whether the roadmap appears
complete before enumerating more work. This step belongs in Discover
because Discover owns roadmap selection and global readiness. F4 remains
scoped to the just-merged PR and local cleanup while holding only the
child issue claim; it must not close a parent roadmap as a side effect.
F5 still loops back here, so the next Discover pass can evaluate parent
roadmap state after child PRs merge.

Run the completion audit only when the selected roadmap has explicit
child work such as task-list issue references or GitHub sub-issue
relationships. If the roadmap has no explicit child work, report that
it is childless or malformed and continue to A2; do not close it based
on absence of candidates.

Fetch the selected roadmap, its explicit child references, transitive
descendants, GitHub sub-issue children, and linked or closing PR
evidence for those child issues. Use the same outbound traversal
sources as A2, including closed umbrella children, so open descendants
cannot be hidden behind a closed direct child. This step must not use
repo-wide search to add unrelated work to the roadmap. The only
repo-wide search allowed in A1.5 is a narrow duplicate/reuse check for
a specific autonomous gap before creating a follow-up issue; use those
results only to link existing gap work or avoid creating a duplicate,
not to widen A2 candidates.

When the selected roadmap graph includes descendant issues that are
themselves roadmap nodes, such as descendants carrying the configured
roadmap label from `labels.roadmapLabelName` (default: `roadmap`) or a
`{{PROJECT_MARKER_PREFIX}}-roadmap-id` marker, treat those
descendants as **nested roadmaps** rather than as normal execution
leaves. A nested roadmap is a coordination/audit node in the recursive
hierarchy: it may remain open while its own leaf descendants are still
executing, and its presence does not by itself widen A2 candidates
outside the selected roadmap graph.

- If the roadmap itself carries the configured blocked-by-human label
  from `labels.blockedByHumanLabelName` (default:
  `status:blocked-by-human`) or configured needs-decision label from
  `labels.needsDecisionLabelName` (default: `status:needs-decision`),
  report the blocker and stop before A2. Do not continue selecting
  child issues under a blocked roadmap.
- If any referenced child or descendant issue is open, inaccessible, or
  unresolved, report the provenance path and reason, then continue to
  A2, unless the open descendant is a nested roadmap with at least one
  reachable leaf descendant and all of those reachable leaf descendants
  are closed or otherwise complete. In that special case, treat the
  nested roadmap as the next completion target and continue applying
  the bottom-up rules below before routing to A2.
- If any referenced child or descendant has an open linked or closing
  PR that is not merged or otherwise obsolete, treat that child work as
  unresolved, report the PR, and continue to A2.
- If any open or unresolved child or descendant has the configured
  blocked-by-human or needs-decision label, report the blocker and
  continue to A2 or stop according to the normal ready-to-start
  rules. Do not treat stale blocker labels on closed children as
  audit blockers when their referenced descendants are resolved.
- If an open leaf issue sits under an open nested roadmap, treat the
  nested roadmap and every ancestor roadmap on that provenance path as
  unresolved. Report the deepest blocking path and continue to A2.
- If a nested roadmap has no reachable leaf descendants after
  traversal, treat it as childless or malformed and continue to A2. Do
  not treat an empty reachable-leaf set as proof of completion.
- If a nested roadmap remains open after at least one reachable leaf
  descendant exists and all reachable leaf descendants are closed or
  otherwise complete, treat that nested roadmap as the **next
  completion target**. Do not close its parent first. Re-evaluate the
  graph bottom-up so the deepest completed nested roadmap is audited and
  closed before its parent roadmap is considered complete.
- If a nested roadmap appears closed but still has an open, inaccessible,
  or otherwise unresolved descendant, treat that descendant as the
  controlling unresolved state. Report the contradictory provenance path
  and continue to A2; do not infer parent completion from the nested
  roadmap's closed state alone.
- If traversal or helper output reports a cycle or duplicate reference
  inside the recursive roadmap graph, preserve that evidence and treat
  the affected path as unresolved until the graph can be interpreted
  safely. Do not guess at a closure order when the traversal graph is
  ambiguous.
- If all referenced child and descendant work is closed or otherwise
  complete, compare the roadmap success criteria against the closed
  child issues, linked merged PRs, task-list state, follow-up comments,
  and the current repository state where feasible. Do not infer
  completion from checkbox state alone.

A1.5 can publish roadmap-level GitHub side effects before a child task
issue is selected. In recursive hierarchies, the immediate audit target
may be the selected roadmap or the deepest completed nested roadmap
discovered beneath it. Before any such side effect, coordinate on the
**exact roadmap issue being mutated**:

Treat `stale` and `non-stale` in this section using the
`claim-stale-age` policy default from `docs/policy-constants.md`
(distributed default: `24 h`).

- Roadmap claim ownership gates roadmap-side mutations only. Do not
  treat a non-stale roadmap claim as a global lock over A2/A3 child
  discovery or child A5 checks.
- Run the A5 claim-state, open-PR, and branch-collision checks against
  the roadmap issue. Do not apply A5's assignee or project
  `not started` readiness gate to roadmap-audit claims; roadmap
  ownership and project status may represent parent coordination rather
  than task readiness. If an active non-stale claim uses any
  `{claim-id}` other than one already recorded by this current session
  before this check and now verified, do not mutate the roadmap; report
  the claim and continue to A2 or stop according to the normal
  ready-to-start rules. A matching agent ID alone is not ownership
  proof, and neither is a token first learned by parsing the current
  roadmap comments.
- If the roadmap is unclaimed or stale, post and verify a normal
  `claimed-by` comment for the roadmap issue using a
  `roadmap-audit/<number>-<slug>` branch field. This is a logical
  coordination name, not a work branch, and it does not require
  creating a branch or worktree unless the audit also needs git
  changes.
- In recursive hierarchies, do not reuse one roadmap-audit claim across
  parent, child, or sibling roadmap mutations. Each roadmap comment,
  follow-up issue link, body edit, label change, or close action must
  be scoped to the roadmap issue being mutated at that moment.
- If the active roadmap claim already uses this current session's
  previously recorded and verified `{claim-id}`, continue with that same
  claim and do not post a new claim.
- Re-validate that roadmap claim before every roadmap comment,
  follow-up issue creation, body edit, label change, or close action.
- If the roadmap remains open and no PR branch will continue from the
  audit, release the roadmap-audit claim before returning to A2 or
  stopping.
- Example: when another agent holds a non-stale roadmap claim, do not
  mutate that roadmap in A1.5, but continue to A2/A3 and allow child
  issues that pass readiness and A5 to proceed.

Immediately before posting any completion summary, creating follow-up
issues, editing the roadmap body, changing labels, or closing the
roadmap, re-fetch the roadmap and child state and confirm the audit
input still matches the evidence.

Apply one outcome:

- **Audit passes**: post an `IDD roadmap completion audit` comment with
  a concise evidence summary, then close the roadmap. In recursive
  hierarchies, this outcome applies only when the selected roadmap is
  the deepest remaining open roadmap on its path whose descendants are
  all complete. After closing a nested roadmap, release that
  roadmap-audit claim, re-fetch the ancestor graph, and return to
  `idd-discover.instructions.md` (A1) so the parent roadmap can be
  re-evaluated from fresh state. No child task issue is claimed.
- **Autonomous gaps found**: create or link follow-up issues using the
  repository's issue-authoring rules, update the roadmap task list with
  those links, and continue to A2 so the new work can be discovered.
  Before creating a new issue, run the narrow A1.5 duplicate/reuse
  check for that gap and link a matching existing issue instead. New
  follow-up issue bodies must reference the roadmap (for example
  `Refs #NNN`) so a later audit can rediscover them. After creating a
  follow-up issue, update the roadmap task list with that link before
  creating another. If the roadmap update fails or the roadmap claim is
  lost after issue creation, create no more issues; report the created
  issue link so the next audit can link it before considering
  duplicates.
- **Non-autonomous gaps found**: comment with the decision or human
  blocker, apply the configured needs-decision or blocked-by-human
  label when those labels exist, and do not close the roadmap. Stop
  before A2 after reporting a non-autonomous gap, even if the
  repository does not have the blocker labels, so the same unattended
  run cannot select child work under a roadmap that needs human input.

**Child issue split.** A further roadmap-currency trigger, orthogonal to
the three outcomes above: when a child issue is split into two or more
issues, bring the roadmap task list and sequencing notes current in the
same action, per the issue-authoring contract's same-action rule
(`skills/issue-authoring/references/contract.md`).
