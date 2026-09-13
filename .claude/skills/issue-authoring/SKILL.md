---
name: issue-authoring
description: Draft or refine IDD-ready GitHub issues, roadmap issues, and sub-issues before the normal IDD execution loop begins. Use when a request is too large or ambiguous for one reviewable change, when work needs decomposition or dependency encoding, or when the user asks for issue drafting, roadmap planning, or parallelizable task breakdown.
---

# Issue Authoring

Use this skill to prepare issue-ready work before execution starts.
Keep the skill concise and treat the repository docs as the canonical
source for the full contract and schema.
The canonical source bundle lives in this repository; install copies in
the agent-specific skill directory your runtime reads.

## Stable Phases

Use two stable phases:

1. **Intake and Clarification** — inspect relevant context, identify
   ambiguity, run a secondary critique or explicit self-critique, and
   ask only the questions that block safe issue drafting. Keep
   clarification bounded; use the repository-local
   `issueAuthoring.maxClarificationRounds` value when available,
   otherwise default to 3 rounds. **Under-clarification stop rule**: if,
   after bounded clarification, you still cannot name the concrete
   surface to edit or an objective verification for a candidate task,
   route it to `needs-decision` or ask — do not publish a
   confidently-vague `ready` issue. Reliability over speed.
2. **Decompose and Draft** — restate the request in implementation
   terms, split it into atomic tasks, classify readiness, reuse existing
   issues when safe, and draft the smallest issue shape that preserves
   dependencies and reviewability.

Preserve low-readiness work in stable buckets: ready, deferred,
needs-decision, blocked-by-human, and out-of-scope.

## Workflow

1. Read the bundled contract in
   [references/contract.md](references/contract.md).
2. Reuse or extend an existing issue before creating a new one — but
   never edit the body of an actively-claimed or open-PR issue (its
   claimed agent will not pick the change up); cover it with a follow-up
   issue instead. See the contract's claim-state precondition.
3. Choose the smallest safe output shape:
   - orphan issue for one ready autonomous task only when the target
     repository discovers orphans (`issue-scope: roadmap-first`, the
     default, via the orphan fallback, or `orphan-first`) and any
     configured `orphan-first-policy` approval step can be completed
     after drafting
   - roadmap plus sub-issues for multi-task or multi-session work
   - stable non-ready buckets for deferred, needs-decision,
     blocked-by-human, or out-of-scope work
4. **Prefix-first**: resolve the target repository's marker prefix
   before emitting any authoring marker — `roadmap-id`, `blocked-by`,
   `autopilot-suitability`, or `effort`. Use the prefix documented by
   the target repository's onboarding or IDD docs, and ask the user
   instead of guessing when the prefix is not discoverable. Never
   default to this source repository's `idd-skill` prefix in an
   installed bundle.
5. Keep dependencies machine-readable and minimal:
   - roadmap identity via
     `<!-- <marker-prefix>-roadmap-id: ... -->`
   - active child issues via roadmap task-list links
   - issue-to-issue dependencies via `Blocked by #NNN`
   - sequential roadmap dependencies via
     `<!-- <marker-prefix>-blocked-by: ... -->` only when a separate
     roadmap
     must close first
   - keep independent sibling work in roadmap task lists unless a true
     correctness, availability, or ordering constraint requires a
     dependency edge
6. Before publishing a ready orphan, roadmap, or child body, run the
   `audit-authored-issue` linter against it as the mechanical
   pre-publish gate — see
   [Mechanical pre-publish gate](references/contract.md#mechanical-pre-publish-gate)
   in the bundled contract, including the manual fallback for
   `instructions-only` installs with no helper runtime. Resolve every
   reported failure before treating the issue as ready. Before newly
   publishing a body into the `needs-decision` or `blocked-by-human`
   bucket instead, also run the linter, passing
   `--expect-bucket <needs-decision|blocked-by-human>` (choose the one
   matching value) — the same gate section's `--expect-bucket` flag
   requires the matching `authoring-bucket` marker for that publish,
   closing the gap where a non-ready body would otherwise never be
   audited at all.
7. Publish each `ready` drafted body directly under the authoring hold
   once it passes the mechanical gate (step 6) and the critique pass
   (the Intake and Clarification phase above) — no separate publish
   approval is needed. Only skip publishing when the current request
   explicitly asked for a preview instead. Manage the authoring label
   for each created or updated issue:
   - resolve `issueAuthoring.authoringLabelName`, defaulting to
     `status:authoring`
   - create the label with `gh label create` before first use when the
     target repository does not already have it
   - treat label creation or application failure as a publishing blocker
   - apply the label before updating an existing issue
   - acquire per-target ownership before editing an existing issue or
     roadmap; the shared label is a claim-suppression lock, not an owner
     token. Follow the append-only owner-marker and re-read protocol in
     [references/workflow-boundary.md](references/workflow-boundary.md)
     and stop without editing when ownership or the target snapshot
     conflicts
   - for a new Stage 1 set, generate one opaque set ID and reuse it in every
     owner marker for that set; when resuming an interrupted set, recover and
     verify its persisted set ID from the exact trusted owner markers and
     reuse it instead of generating a replacement; never infer set membership
     from the label alone
   - when a set includes a parent roadmap, publish a valid roadmap shell under
     the authoring hold before any child; acquire and verify that roadmap as
     the set anchor, leaving its `## Tracks` list empty only until child issue
     numbers exist. Without a parent roadmap, use the designated lead target
     as the anchor
   - acquire and verify the set anchor before publishing or acquiring any
     child; do not acquire children independently, and stop all edits if any
     target cannot join that anchor's verified set
   - before each child acquisition or resume, append and verify a same-owner
     anchor heartbeat (or reuse one — see the heartbeat-coalescing rule
     below), re-fetch the anchor's paginated log, then append the child
     marker and immediately re-fetch both anchor and child. Stop with the
     label in place if anchor ownership changed between those reads
   - **Heartbeat coalescing** (`issueAuthoring.heartbeatCoalesceWindow`,
     default `PT2M`): before appending a heartbeat, replay the target's
     paginated log; reuse the latest trusted marker instead of appending
     when it is the same owner/set/session, its mode is
     `acquire`/`bootstrap`/`resume`/`heartbeat`, it is younger than the
     window, and its `body-sha256` matches the just-fetched body — re-fetch
     and verify the reused marker exactly as a fresh one. This window never
     applies to `acquire`, `bootstrap`, `resume`, `release`,
     `release-guard`, or `release-complete` appends themselves — only a
     `heartbeat` append may be skipped
   - persist the anchor's canonical repository/issue identity in every owner
     marker for the set; the anchor marker points to itself, and a resume must
     stop if the interrupted set's anchor cannot be proven
   - immediately before every Stage 1 body or relationship edit, re-fetch both
     the edited target and the set anchor; require each target's expected owner
     token independently, plus the same set, anchor, and owning session, and
     require an unchanged expected target snapshot before editing
   - immediately before that edit, renew both generations with a trusted
     same-owner-per-target heartbeat marker (one marker when target and anchor
     coincide; reuse applies here too), re-fetch and verify both, and stop if
     renewal or ownership verification fails
   - create new issues only through a capability-checked publication command
     that applies the authoring label atomically and carries an exact hidden
     publication token for target, anchor, set, and session; if that operation
     is unavailable, stop before creating the issue — never intentionally
     create an unlabeled issue
   - the hidden publication token is this exact HTML-first body line:

     ```html
     <!-- <marker-prefix>-authoring-publication: target=<opaque-target-id>; anchor=<opaque-anchor-id>; set=<opaque-set-id>; session=<opaque-session-id>; token=<opaque-publication-token> -->
     ```

   - The originating Stage 1 hold uses this append-only publication-intent
     record:

     ```html
     <!-- <marker-prefix>-authoring-publication-intent: target=<opaque-target-id>; anchor=<opaque-anchor-id>; set=<opaque-set-id>; session=<opaque-session-id>; token=<opaque-publication-token>; journal=<owner>/<repo>#<number>; issue=<owner>/<repo>#<number>|none; actor=<trusted-marker-actor>; state=<pending|member|cleanup|abandoned> -->
     ```

     `issue` is the returned canonical issue identity or `none`. Append
     `state=pending; issue=none` before creation, then append the returned
     identity while it remains `pending`, append `member` only after the owner
     marker is verified, and append `cleanup` before any safe-close mutation.
     Append `abandoned` only after closed/label-absent verification. On
     resume, paginate the hold log and select the latest valid record for the
     exact token tuple; missing, conflicting, or out-of-order records fail
     closed, while `pending` and `cleanup` remain recovery holds.

     `journal` is the durable record location. For an existing set, use the
     verified originating Stage 1 hold; for a standalone set with no existing
     issue or anchor, use the repository-level authoring journal target
     configured at `issueAuthoring.journalIssue` in `.github/idd/config.json`
     (an `owner/repo#number` reference to a pre-existing, durable,
     comment-only issue) -- an unset `issueAuthoring.journalIssue` only
     blocks a standalone set; an existing set with a verified Stage 1 hold
     needs no journal configuration at all. Do not create that journal as
     part of the same set. If the applicable location cannot be resolved --
     no verified Stage 1 hold for an existing set, or
     `issueAuthoring.journalIssue` unset or unverifiable for a standalone
     set -- stop with `blocked-by-human` before creating any target. On
     every paginated replay, require `actor` to equal the API author and
     verify that actor is a trusted marker login with the required write-level
     permission or configured bot/app trust. An untrusted, malformed, or
     conflicting exact-token record is not valid evidence; fail closed and
     retain the hold.

     Generate the opaque IDs and token before creation because issue numbers
     are not yet known; before issuing the create, persist those preallocated
     IDs, the exact token, and `state=pending` in that journal. After
     a successful create, attach and verify the returned issue identities on
     that pending record before appending the owner marker. If the pre-create
     hold write cannot be verified, do not create; if the post-create identity
     attachment cannot be verified, leave the returned issue held for recovery.
     Transition to `member` only after owner-marker verification or
     `abandoned` only after the verified safe close and label removal. On
     resume, match the exact token and persisted identities; an incomplete
     scan or state mismatch is recovery.
   - immediately after a new issue is created and labeled, append its
     `mode=acquire` owner marker with the current set ID, then re-fetch the
     labels, body, and owner comments before treating it as a set member
   - an atomically labeled publication is not set membership until its owner
     marker is verified; persist each returned target identity in the journal
     before appending the marker. On resume, reconcile
     recorded identities and only issues carrying this set's exact publication
     token; an incomplete scan or unmarked match is a recovery hold, so never
     infer membership or completion from the shared label alone
   - if owner-marker append or verification is uncertain for a new issue,
     reconcile the returned comment ID and the paginated owner-marker log with
     bounded retries before closing; if a trusted marker is found, retain the
     label and recover or reopen the issue as a set member. Otherwise re-fetch
     labels, body, current `claimed-by` state, and the paginated owner-marker
     log; if that final read proves no competing claim or owner marker, append
     `state=cleanup` before closing the issue or removing its authoring label.
     Re-fetch and verify closed/label-absent state, then append
     `state=abandoned`. If any disposition or cleanup read is uncertain,
     retain `state=cleanup`, leave the issue held, and report the recovery hold
   - if an allegedly atomic create unexpectedly returns an unlabeled issue,
     re-fetch its labels, body, current `claimed-by` state, and paginated
     owner-marker log before closing. If a trusted claim or owner marker from
     another session/set is present, do not close or overwrite the exposed
     issue; report the ownership conflict and stop. If no competing claim is
     present, apply and verify the authoring label as a safe hold, then
     re-fetch its labels, body, current `claimed-by` state, and paginated
     owner-marker log again before closing. If that hold or final re-read
     cannot be verified, leave the issue open and report the recovery hold.
     Deletion needs admin permission and is not the default recovery path
   - held issues under the label ARE the drafts: do in-place body
     edits, roadmap relationship wiring, and re-lint of already-published
     bodies on the published issue itself, under the same label
   - if a session is interrupted before the set is fully wired, leave the
     label and owner markers in place — the label suppresses Discover and
     the markers preserve the set identity for a later verified resume
   - read every target and anchor owner-marker log with paginated retrieval and
     deterministic comment order; never rely on a single API page
   - after the release checklist passes and the user explicitly requests
     release — or, for a single target whose body carried the
     review-fix-loop-cutoff marker at Stage 1 publication time (never a
     marker added later), the narrow auto-release exception in
     [Authoring hold and release](references/contract.md#authoring-hold-and-release)
     — preflight and verify or reuse a matching `mode=release` marker
     for every target (with `supersedes` equal to the current owner token)
     before removing any label; record its GitHub comment ID, never append a
     duplicate on retry, append and reconcile an anchor-only
     `mode=release-guard` marker before the first label removal, keep the set
     anchor held, and remove it last. Recheck
     each target's expected owner token independently, plus the shared
     set/anchor/session, recorded marker, and expected snapshot immediately
     before each removal. Renew and verify the set anchor heartbeat first
     (reuse applies here too), re-fetching its current owner, set, anchor,
     and session; only then renew and verify the target heartbeat when
     distinct (one marker when they coincide; reuse applies here too).
     Remove non-anchor labels one at a time and
     verify the whole set. After the final anchor label removal is verified,
     reuse or append the anchor-only `mode=release-complete` marker and record
     its comment ID. Reconcile that ID and the paginated anchor log with
     bounded retries; a successful POST or verification timeout is
     inconclusive. If the trusted marker is found, keep labels absent and
     close the set. If a complete fresh read conclusively proves that no
     trusted marker was appended, restore labels for every target and leave
     every target generation open. If reads remain inconclusive, keep the
     release guard and current labels/state in place, leave the set held, and
     record a recovery hold. Never infer marker absence or roll back from a
     verification timeout. Discover must treat the reconciled release guard as
     suppressing every target until the anchor completion marker is found.
     Treat each release marker, removal, and completion
     marker as provisional until the durable completion event is reconciled.
     If a later removal or verification fails, retry a failed post-removal
     read with a bounded fresh read, restore labels for already processed
     targets while the owner/set still match, verify the restored set, and
     leave every target generation open
8. Stop at the single approval boundary: release. Publishing under the
   hold does not by itself authorize starting the IDD execution loop —
   only the user's explicit release request does, except the narrow
   review-fix-loop-cutoff auto-release exception in
   [Authoring hold and release](references/contract.md#authoring-hold-and-release).

## Reference Routing

- For the bundled contract, output schemas, and discoverability guard:
  read [references/contract.md](references/contract.md).
- For the bundled two-stage authoring/release contract and the
  boundary with the IDD execution loop: read
  [references/workflow-boundary.md](references/workflow-boundary.md).
- For concrete drafting patterns and example prompts: read
  [references/draft-patterns.md](references/draft-patterns.md).
- When editing this bundle inside the upstream source repository
  (`kurone-kito/idd-skill`), keep the bundled references synchronized
  with its canonical maintenance docs:
  [`docs/issue-authoring-skill.md`](https://github.com/kurone-kito/idd-skill/blob/main/docs/issue-authoring-skill.md)
  and
  [`docs/idd-workflow.md`](https://github.com/kurone-kito/idd-skill/blob/main/docs/idd-workflow.md)
  — upstream's own self-hosting copies, distinct from this repository's
  imported `docs/idd-workflow.md`. Not applicable when working from an
  adopter repository such as this one.
  <!-- setup.windows: relinked from upstream's bare repo-root-relative
  filenames, which name docs this bundle's .claude/skills/issue-authoring/
  install location does not carry, to upstream URLs instead. -->

## Output Checklist

- Preserve low-readiness work in stable buckets instead of dropping it.
- Keep acceptance criteria explicitly verifiable.
- Keep human-dependent setup, review, and approval work isolated from
  ready execution issues whenever possible.
- Link every active child issue from its roadmap body.
- Justify each dependency edge and keep independent sibling work as
  roadmap task-list entries.
- Record reuse or extension decisions when the skill does not create a
  new issue.
- Avoid widening drafting output beyond the user request without saying
  so.
- Run the `audit-authored-issue` linter (or its manual fallback in
  `instructions-only` installs) against every drafted ready body, and
  against every body newly published into `needs-decision` or
  `blocked-by-human` with `--expect-bucket`; resolve every reported
  failure before publishing.
- Name a concrete surface to edit and an objective verification for
  every `ready` candidate; route anything else to `needs-decision` or
  ask instead of guessing (the under-clarification stop rule).
- Resolve the target repository's marker prefix before emitting any
  authoring marker; never assume this source repository's `idd-skill`
  prefix in an installed bundle (the prefix-first rule).
