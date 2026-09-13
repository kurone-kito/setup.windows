# Workflow Boundary

This bundle handles issue authoring end to end under the authoring
hold: drafting and publishing are one continuous stage with no
per-step approval, and release from the authoring hold is the single
approval boundary that hands off to IDD execution.

## Two-stage contract

### Stage 1: Author-and-publish (under the hold)

- Skill drafts issues in the target repository. Each candidate moves
  through the readiness buckets: `deferred` → `ready` or an escalation
  bucket (`needs-decision`, `blocked-by-human`, `out-of-scope`)
- Before publishing a `ready` body, bundled skill runs the mechanical
  `audit-authored-issue` gate and the critique pass (both unchanged
  and still mandatory)
- Bundled skill then publishes directly under the configured authoring
  label (`issueAuthoring.authoringLabelName`, defaulting to
  `status:authoring`) — **no prior user approval of the drafted body
  is required**. If the current request asked only for a preview
  (drafts to look at before anything is created), bundled skill stops
  after reporting the proposed set instead of publishing; publishing
  is otherwise the default outcome of drafting, not an opt-in step
- If the label does not exist in the target repository, bundled skill
  creates it with `gh label create` before first use; label creation or
  application failure blocks publishing
- For existing issues, bundled skill applies the authoring label before
  updating issue content
- For new issues, bundled skill requires a capability-checked publication
  command that creates the issue with the authoring label atomically and
  carries an exact hidden publication token for target, anchor, set, and
  session. If the target runtime cannot provide that operation, stop before
  creating the issue. Never intentionally create an unlabeled issue for the
  Stage 1 set
- The publication token uses this exact HTML-first format:

  ```html
  <!-- <marker-prefix>-authoring-publication: target=<opaque-target-id>; anchor=<opaque-anchor-id>; set=<opaque-set-id>; session=<opaque-session-id>; token=<opaque-publication-token> -->
  ```

  The originating Stage 1 hold uses this append-only publication-intent
  record:

  ```html
  <!-- <marker-prefix>-authoring-publication-intent: target=<opaque-target-id>; anchor=<opaque-anchor-id>; set=<opaque-set-id>; session=<opaque-session-id>; token=<opaque-publication-token>; journal=<owner>/<repo>#<number>; issue=<owner>/<repo>#<number>|none; actor=<trusted-marker-actor>; state=<pending|member|cleanup|abandoned> -->
  ```

  Append `state=pending; issue=none` before creation, append the returned issue
  identity while it remains `pending`, append `member` only after owner-marker
  verification, and append `cleanup` before any safe-close mutation. Append
  `abandoned` only after closed/label-absent verification. The append-only
  replay selects the latest valid record for the exact token tuple; missing,
  conflicting, or out-of-order records fail closed, while `pending` and
  `cleanup` remain recovery holds.

  `journal` is the durable record location. For an existing set, use the
  verified originating Stage 1 hold; for a standalone set with no existing
  issue or anchor, use the repository-level authoring journal target
  configured at `issueAuthoring.journalIssue` in `.github/idd/config.json`
  (an `owner/repo#number` reference to a pre-existing, durable, comment-only
  issue) -- an unset `issueAuthoring.journalIssue` only blocks a standalone
  set; an existing set with a verified Stage 1 hold needs no journal
  configuration at all. Do not create that journal as part of the same set.
  If the applicable location cannot be resolved -- no verified Stage 1 hold
  for an existing set, or `issueAuthoring.journalIssue` unset or
  unverifiable for a standalone set -- stop with `blocked-by-human` before
  creating any target. On every paginated replay, require `actor` to equal
  the API author and verify that
  actor is a trusted marker login with the required write-level permission or
  configured bot/app trust. An untrusted, malformed, or conflicting
  exact-token record is not valid evidence; fail closed and retain the hold.

  Generate the opaque target/anchor IDs and publication token before creation
  and persist those preallocated IDs, the exact token, and `state=pending` in
  that journal before issuing the create. After a successful create, attach and
  verify the returned issue identities before appending the owner marker; an
  unverifiable pre-create write blocks creation, while an unverifiable
  post-create attachment leaves the issue held for recovery. Only verified
  owner-marker acquisition changes it to `member`, and only verified safe close
  changes it to `abandoned`
- Immediately after a new issue is created and labeled, bundled skill
  appends its `mode=acquire` owner marker with the current set ID, then
  re-fetches labels, body, and owner comments before treating it as a set
  member
- If an allegedly atomic create unexpectedly returns an unlabeled issue,
  re-fetch its labels, body, current `claimed-by` state, and paginated
  owner-marker log before closing. If a trusted claim or owner marker from
  another session or set is present, do not close or overwrite the exposed
  issue; report the ownership conflict and stop. If no competing claim is
  present, apply and verify the authoring label as a safe hold, then re-fetch
  the claim and owner logs again before closing. If that hold or final
  re-read cannot be verified, leave the issue open and report the recovery
  hold. Deletion needs admin permission the authoring agent
  typically lacks (and `docs/permissions.md` forbids for normal IDD), so it
  is not the default recovery path
- If owner-marker append or verification is uncertain for a new issue,
  reconcile the returned comment ID and the paginated owner-marker log with
  bounded retries before closing. If a trusted marker is found, retain the
  label and recover or reopen the issue as a set member. Otherwise re-fetch
  labels, body, current `claimed-by` state, and the paginated owner-marker log;
  if that final read proves no competing claim or owner marker, append
  `state=cleanup` before closing the issue or removing its authoring label.
  Re-fetch and verify closed/label-absent state, then append
  `state=abandoned`. If any disposition or cleanup read is uncertain, retain
  `state=cleanup`, leave the issue held, and report the recovery hold.
- An atomically labeled publication is not set membership until its owner
  marker is verified. Persist each returned target identity in the durable
  originating Stage 1 hold before appending the marker. On resume, reconcile
  recorded identities and only issues carrying this set's exact publication
  token; an incomplete scan or unmarked match is a recovery hold, so never
  infer membership or completion from the shared label alone. If the final
  safe-close read proves no competing claim or marker, append `state=cleanup`
  before closing the issue or removing its authoring label. Re-fetch and verify
  closed/label-absent state, then append `state=abandoned`; otherwise leave the
  identity and label held for recovery.
- **Per-target ownership is separate from the hold label.** The configured
  authoring label is a shared claim-suppression lock, not a session lock. Before
  editing an existing issue or roadmap, the skill must fetch a fresh target
  snapshot and resolve its complete claim state, including trusted forced-handoff
  successors and activation-nonce winners, plus its active `claimed-by` and
  open-PR state. A trusted forced-handoff successor is active even without a new
  `claimed-by`; any active execution is a conflict, so do not establish the
  hold. Apply the label if it is absent, then append a hidden owner comment
  using the resolved marker prefix:

  ```html
  <!-- <marker-prefix>-authoring-owner: target=<owner>/<repo>#<number>; anchor=<owner>/<repo>#<number>; mode=acquire|resume|bootstrap|heartbeat|release|release-guard|release-complete; owner=<opaque-owner-token>; set=<opaque-set-id>; session=<opaque-session-id>; body-sha256=<64-lowercase-hex|none>; snapshot-sha256=<64-lowercase-hex|none>; supersedes=<opaque-owner-token|none> -->
  ```

  _Issue-authoring ownership marker. Do not edit or delete._

  Use the same `body-sha256` and `snapshot-sha256` semantics as the portable
  owner protocol: target markers persist the exact fresh body digest, and the
  anchor-only `release-complete` marker carries the recomputed set snapshot.
  New markers missing these fields are not valid for a new generation; legacy
  markers are migration input only and cannot prove completion.

  Append this HTML-first body with a direct JSON `POST` to the issue-comments
  endpoint; do not rely on `gh issue comment` or `gh api -f body=` for the
  owner marker. Verify the returned comment ID and body after posting, then
  re-read the active claim and open-PR state again. If execution began during
  acquisition, stop without editing and leave the verified hold for explicit
  recovery.

  Owner tokens are per target: never compare a child target's `owner` value
  literally with the anchor's `owner` value. Every owner-marker log read for a
  target or anchor must use paginated issue-comment retrieval (for example,
  `gh api --paginate` or an API equivalent) and deterministic GitHub comment
  order (`created_at`, then comment ID); never rely on a single API page.

  Resolve the set anchor before appending any target marker. `anchor` records
  the canonical owner/repository/issue identity of that anchor; the anchor's
  own marker uses its `target` as the `anchor`, and every other marker in the
  set repeats the same value. A missing or mismatching `anchor` makes a
  marker invalid for set membership, resume, or release. A legacy marker
  without an anchor cannot resume a multi-target set; when no parent roadmap
  identifies the anchor, stop and bootstrap a fresh explicitly designated
  anchor instead of choosing a different lead implicitly.

  Only a trusted target-repository marker actor makes a marker valid: the
  current authenticated actor after posting and verifying it **and** passing
  a Write/Maintain/Admin permission check, a configured trusted bot or app,
  or an explicitly enabled Write/Maintain/Admin collaborator. Comment-only
  access is insufficient. If permission cannot be verified and no explicit
  bot/app trust applies, ignore and report the marker; syntax alone never
  grants ownership. For `acquire`, `bootstrap`, and `resume`, `owner` is a
  newly generated opaque per-target owner token; `supersedes=none` for
  `acquire` and `bootstrap`, while `resume` names the prior owner token.
  For any owner marker needed by a later session, the author's trust must also
  be re-evaluable from durable policy: `trustedMarkerActors`, a configured
  trusted bot or app, or an explicitly enabled collaborator whose permission
  can be re-read. The current-session actor path is provisional and cannot
  make a historical marker trusted by itself. Without a durable trust source,
  leave the label and hold in place and report recovery; do not treat the
  marker as set membership or ownership evidence.
  For `release`, retain the current owner token in `owner` and set
  `supersedes` to that same current owner token; `supersedes=none` is invalid
  for a release marker. For `heartbeat`, retain the current owner, set, and
  anchor, set `supersedes` to that same owner token, and do not open or close
  a generation; it only renews the current owner's freshness.
  `release-guard` is valid only on the set anchor. It retains the anchor's
  current owner, set, anchor, and session, and sets `supersedes` to that owner
  token. Append and reconcile it after release-marker preflight but before the
  first label removal. It is the Discover-visible guard for a provisional set
  release and does not close any generation.
  `release-complete` is valid only on the set anchor. It retains the
  anchor's current owner, set, anchor, and session, and sets `supersedes`
  to that owner token. Append and verify it only after every target's
  release marker and label removal has been verified. It is the durable
  terminal event for the set: a later reapplication of the authoring label
  must start a fresh set generation rather than resuming the completed set.
  Within an open generation, the first valid acquisition, bootstrap, or
  resume marker by GitHub comment order wins. A
  `resume` marker opens a new generation only for the exact interrupted set
  and matching prior owner token. A `release` marker must match the current
  owner and set, but remains provisional while its set release is in
  progress; an individual label removal never closes that target's
  generation. During the owning set's own Stage 2 (observed 2026-09-09,
  kurone-kito/idd-skill#2791), the heartbeat renewal and the pre-removal
  ownership recheck must treat that set's provisional `mode=release`
  markers and the anchor's `mode=release-guard` as the expected state
  rather than as a competing generation; the acquisition-time rule that
  a target carrying a release marker cannot be re-acquired until that
  release's `release-complete` is found applies to a later session's
  fresh acquisition of the child, not to the releasing set's own
  rechecks or to a resume of the exact interrupted set, which stays
  the established recovery path when `release-complete` is missing;
  the releasing set's own rechecks never change the current winner,
  unlike a valid resume marker for that exact set, which does. Only
  after a fresh re-read verifies every target's release
  marker and label removal and the anchor's `release-complete` marker does
  the set-level release close all target generations, after which a later
  `acquire` starts a new generation. The
  active generation's freshness is the GitHub `created_at`
  of its latest trusted acquisition, bootstrap, resume, or heartbeat marker;
  a resume marker refreshes that clock, and the label event alone never
  supersedes a fresh owner marker. The current generation's winner owns the
  target; any other
  session must stop without editing and leave the label in place. Do not
  edit or delete owner comments.
- For a new Stage 1 set, generate one opaque set ID and reuse it in every owner
  marker for that set. When resuming an interrupted set, recover and verify
  its persisted set ID from the exact trusted owner markers and reuse it
  instead of generating a replacement. Persist the resolved anchor identity in
  every marker as well. Before resuming, enumerate the anchor's `## Tracks`
  and a repository-wide paginated issue-comment scan scoped to trusted owner
  markers whose exact `anchor` and `set` match; merge the results by comment
  order and block if enumeration is incomplete. These append-only comments
  are the durable set, anchor, and target membership record; a resume may
  include only targets whose valid markers identify that exact set and anchor.
  Never infer set membership or the anchor from the shared label alone.
- A non-anchor target cannot prove that its previous set finished from its
  local owner-marker log alone. Before accepting a fresh `mode=acquire` for a
  child whose prior generation has a `mode=release` or `mode=release-guard`
  marker, follow its exact persisted `anchor` identity and fetch that anchor's
  paginated owner-marker log. Require a trusted `mode=release-complete` marker
  for the exact anchor/set/session generation represented by the child's
  current release marker, including the current anchor owner for that release
  generation; never accept an older or newer set's completion. Owner tokens
  are per target, so do not compare the child owner token literally with the
  anchor owner token. If the completion marker is absent, malformed, or cannot
  be fetched conclusively, treat the prior release as interrupted: do not
  acquire the child as a new set, and instead resume that exact set or leave
  its hold in place. A child log, an absent label, or a session-local read is
  never completion evidence. Once the anchor completion is reconciled, the
  old set is closed and a new acquisition may start a new generation.
- Acquire one set anchor before acquiring any other target: when the set has
  a parent roadmap, first publish a valid roadmap shell under the authoring
  hold, with all required roadmap headings/markers and an empty `## Tracks`
  list allowed only until child issue numbers exist; then acquire and verify
  that roadmap as the set anchor. Only after that anchor is verified may the
  session publish and acquire child targets, and it must wire their real
  numbers into `## Tracks` before release. When no parent roadmap exists, use
  the designated lead target as the anchor. The anchor winner serializes
  acquisition for the whole set; no session may publish or acquire children
  independently. Before each child acquisition or resume, append and verify
  a same-owner heartbeat on the anchor, re-fetch the anchor's paginated log,
  and require its current owner token, set, anchor, and session. Append the
  child marker only after that validation, then immediately re-fetch both
  anchor and child and require the same anchor ownership; if either read
  changes, leave the child hold in place and stop rather than forming a split
  set. If any target cannot be acquired under that anchor, stop all body and
  relationship edits, leave labels and append-only markers in place, and
  require an exact verified resume of that set rather than allowing a split
  ownership set.
  After each `acquire`/`resume`/`bootstrap` marker POST, wait the configured
  `claim.verifySettleDelay`, replay the full paginated log, and choose the
  winner by deterministic comment order; an immediate local read never
  authorizes edits. Apply the same settle delay and full paginated replay after
  every heartbeat before it authorizes an edit or label removal.
- **Re-read before every edit.** Immediately before each body or roadmap
  relationship update, re-fetch both the target and the set anchor (the same
  fresh snapshot serves both roles when the target is the anchor). Require each
  target's expected owner token independently, plus the same set, anchor, and
  owning session, and require the expected body/label snapshot on the edited
  target to remain unchanged. Also re-read its active `claimed-by` and open-PR
  state; any active claim or open PR is a conflict. An unexpected change,
  competing owner, malformed owner marker, or inability to prove a unique
  owner on either target is a conflict: stop without editing, leave the
  authoring label in place, and record the safe alternative.
- **Renew before every edit.** After that conflict check and immediately
  before the body or relationship mutation, append and verify a trusted
  `mode=heartbeat` marker for the set anchor first, then re-fetch and verify
  its current owner, set, anchor, and session. Only after the anchor renewal
  succeeds, append and verify the edited target's heartbeat when it is a
  distinct target, then re-fetch both and require each target's expected owner
  token independently, plus the same set, anchor, owning session, and expected
  target snapshot. If either heartbeat cannot be posted or verified, or a
  newer owner appears, stop without editing. A heartbeat never starts a new
  generation and never authorizes release.
- A target already held by another set is unavailable. A later session may
  resume only when the invocation identifies the exact interrupted set and
  the hold is past `issueAuthoring.authoringStaleAge`; it must append a
  `mode=resume` owner marker with a new owner token and `supersedes` value
  matching the prior owner token before re-running the same acquisition check.
  For a stale held target with no valid owner marker, append a trusted
  `mode=bootstrap` marker with the current set ID, a new owner token, and
  `supersedes=none`; this starts a new generation and is not evidence of any
  prior set membership. The first valid bootstrap marker wins. Staleness
  alone never authorizes takeover: use the latest trusted generation marker's
  GitHub `created_at` for marked targets, and the label event only for
  legacy-unowned bootstrap. A competing active marker still stops the
  session. If the target runtime provides an atomic acquisition helper, use
  it; otherwise this append-only conflict check is mandatory, including for
  `instructions-only` installs.
- **The held issue IS the draft.** In-place body edits, roadmap
  relationship wiring (publish/acquire the roadmap anchor first, then
  publish/acquire children and wire their real issue numbers), and re-lint of
  already-published bodies all happen on the published issue, under the same
  label — not in a session-local buffer that a later session cannot see
- **Interrupted-session guard.** If a Stage 1 session stops before the
  set is fully wired and stable, the authoring label stays on every
  issue it already published, and its owner markers stay in place. The
  label suppresses Discover while the markers preserve set identity and
  target membership for a later verified resume; a later session must not
  infer either from the label alone.

### Stage 2: Release (the single approval boundary)

- The user's explicit hold-release request is the only approval this
  bundle's workflow requires — except the narrow review-fix-loop-cutoff
  auto-release exception in
  [Authoring hold and release](contract.md#authoring-hold-and-release) —
  and it authorizes IDD execution for the released issues
- Before removing the authoring label, bundled skill runs a release
  checklist that absorbs the rigor of the dropped middle step:
  - every child issue is referenced from its parent roadmap's
    `## Tracks` list
  - no unsubstituted placeholder (a leftover `#TBD`, template
    stand-in, or similar) remains in any published body
  - the `audit-authored-issue` linter (or its manual fallback under
    `instructions-only`) is green on every published body in the set
- Keep the set anchor held until every other target's label removal is
  verified, and remove the anchor label last. For every target, first
  re-fetch owner comments during release-marker preflight. If a valid
  current-owner/set `mode=release` marker already exists, reuse the earliest
  matching GitHub comment ID; otherwise append one with `supersedes` equal to
  the current owner token, re-fetch to verify it, and record its comment ID.
  Complete that preflight for the whole set before removing any label. A
  retry of an open generation must reuse the recorded or earliest matching
  marker and never append an indistinguishable duplicate. Then, before
  removing any label, append or reuse the anchor-only `mode=release-guard`
  marker and re-fetch the anchor's paginated owner-marker log with bounded
  retries, requiring the exact current owner, set, anchor, session, and marker
  body. If that guard is not found conclusively, leave all labels in place and
  stop. The guard suppresses Discover for the whole set during the provisional
  label-removal window; it does not close the set. Then, immediately
  before each label removal, append and verify the set anchor's
  `mode=heartbeat` first, re-fetching it and requiring its current owner, set,
  anchor, and session. Only after that succeeds, append and verify the target
  heartbeat when it is distinct (one marker serves both roles when they
  coincide), then re-fetch both and require each target's expected owner token
  independently, plus the shared set/anchor/session, recorded release-marker
  comment, and expected label/body snapshot. Remove non-anchor labels one
  target at a time and re-fetch each result. After the final anchor label
  removal is verified, re-fetch every target and verify its current release
  marker, absent label, and expected body snapshot; any drift leaves the set
  open and prevents completion. Then reuse the earliest
  valid current-owner/set/session `mode=release-complete` marker on the anchor,
  or append one and record its returned comment ID. Re-fetch that ID and the
  anchor's paginated owner-marker log with bounded retries, requiring the exact
  current owner, set, anchor, session, and marker body. Treat a successful POST
  or a verification timeout as inconclusive until reconciliation finishes: if
  the trusted marker is found, keep the labels absent and close the set; if a
  complete fresh read conclusively proves that no trusted marker was appended,
  reapply the authoring label to every target and leave the set generations
  open; if reads remain inconclusive, keep the release guard and current
  labels/state in place, leave the set held, and record a recovery hold. Never
  infer marker absence or roll back from a verification timeout. Treat every
  release marker,
  heartbeat, label removal, and completion marker as provisional: no target
  generation closes until every target's release marker and label removal are
  verified and the durable completion marker is reconciled, at which point the
  set-level release closes all target generations together. If any later
  removal or verification fails, re-fetch every target already processed,
  retrying a failed post-removal read with a bounded fresh read, restore its
  authoring label while the current owner/set still matches, and verify the
  restored set state; leave every target generation open and stop. If
  restoration cannot be completed or a newer owner has appeared, record a
  set-level recovery hold and never claim a partial release.
- Bundled skill removes the authoring label from all published issues
  only after the release checklist passes and the user's release
  request is explicit, except the narrow review-fix-loop-cutoff
  auto-release exception in
  [Authoring hold and release](contract.md#authoring-hold-and-release)
- Release remains a human action; nothing in this bundle auto-releases
  a held issue set, except that same narrow, marker-scoped exception

## A4.5 Gate Timing

The IDD discover phase evaluates published issues through the A4.5
pre-claim suitability gate. This gate runs after an issue is published
but before it is claimed for work.

**Why A4.5 exists**: Issues drafted with incomplete information or from
assumptions that did not hold when published may fail A4.5 checks
(incoherent, unsafe, duplicate, etc.). A4.5 catches these before they
waste agent time during work.

**Prevention during drafting**: This bundle is where coherence, safety,
and uniqueness should be validated **before** publishing. A4.5 runs
seven suitability checks; the three that drafting can most directly
prevent (coherence, safety, uniqueness) correspond to bucket escalation
triggers during drafting:

- If an issue might be incoherent → escalate to `needs-decision` during
  drafting
- If an issue might contain untrusted input → escalate to `blocked-by-human`
  or fix during drafting
- If an issue might be a duplicate → run reuse-first checks during
  drafting before publishing

When these prevent-during-drafting checks are applied correctly, published
issues will pass A4.5; if they do not, A4.5 will catch them at discover
time and report the specific failure (unclear, invalid, duplicate).

## Use this bundle to

- prepare IDD-ready orphan issues when the target repository discovers
  orphans (`issue-scope: roadmap-first`, the default, via the orphan
  fallback, or `orphan-first`), including any required
  `orphan-first-policy` approval handoff
- prepare roadmap packages and child issues when work needs visible
  sequencing or parallel tracks
- surface non-ready buckets instead of guessing through blockers

## Do not use this bundle to

- start the Discover -> Claim -> Work loop implicitly
- treat bundled references as a replacement for repository execution
  instructions
- publish a body that has not passed the mechanical
  `audit-authored-issue` gate and the critique pass
- remove the authoring label from any issue without an explicit
  release request, except the narrow review-fix-loop-cutoff
  auto-release exception in
  [Authoring hold and release](contract.md#authoring-hold-and-release)

## Handoff to execution

Once the authoring label is removed from every issue in a released
set — via the user's explicit release request, or, for a single
marked target only, the narrow review-fix-loop-cutoff auto-release
exception — execution is authorized: the repository's normal entry
file and routed `.github/instructions/*.instructions.md` phase files
(Discover, Claim, Work) may pick up the released issue(s). This bundle
does not itself start that loop.
