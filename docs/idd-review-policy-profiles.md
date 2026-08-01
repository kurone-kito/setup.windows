# IDD Review Policy Profiles

IDD separates the execution loop from the pull request review policy as
much as possible. The default template still ships with a GitHub Copilot
advisory review step, but adopters should choose a profile explicitly
before they treat the imported workflow as final.

This page names the supported policy shapes and the instruction files
that need customization when a repository does not use the default.

## PR Review Profile Summary

| Profile            | Use when                                                                                      | Review signal                                                                          | Merge gate                                                                                            |
| ------------------ | --------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| `copilot-advisory` | The repository wants the distributed default.                                                 | GitHub Copilot is requested after review-fix pushes and before merge freshness checks. | CI, human/required reviewer states, unresolved conversations, and the Copilot advisory wait.          |
| `human-required`   | A maintainer, CODEOWNER, or required reviewer must approve every PR.                          | Human review is the authoritative review signal.                                       | CI, branch protection, required reviewer approval, and unresolved conversations.                      |
| `no-advisory`      | The repository intentionally relies on CI and branch protection without an advisory reviewer. | No bot advisory reviewer is requested by IDD.                                          | CI, branch protection, human review only when configured outside IDD, and unresolved conversations.   |
| `external-bot`     | The repository wants a non-Copilot advisory bot.                                              | A named review bot provides advisory feedback with a stable completion signal.         | CI, human/required reviewer states, unresolved conversations, and the external bot's advisory signal. |

## Default Profile

`copilot-advisory` is the only profile implemented directly by the
distributed template. It keeps the current behavior:

- E14 can request a Copilot re-review for the current PR head.
- F2 and F3 can wait or hold based on Copilot advisory state.
- Copilot and CI advisory comments are handled as PATH B feedback during
  review triage.

Use this profile when GitHub Copilot pull request review is available
and the operator accepts it as an advisory signal rather than a required
human approval.

The advisory wait windows, request cap, and CI wait defaults are named in
[IDD policy constants](policy-constants.md), so adopters can record those
values separately from the review profile choice.

## Profile Artifacts

The exported template includes profile artifacts under `profiles/`.
In the idd-skill source repository, find those artifacts at
`idd-template/profiles/`; in adopter repositories, they live at
`profiles/`. Each non-default artifact is a documented
patch surface that records adopter-owned values, files to edit, and
verification evidence for the selected profile.

Use the artifact when choosing `human-required`, `no-advisory`, or
`external-bot` instead of reconstructing the edit surface from memory.
The checklist below remains the policy contract; the artifact packages
that checklist into a reusable onboarding unit.

## Human-Required Profile

Use `human-required` when a person, CODEOWNER, or required reviewer is
the review authority. IDD can still collect and triage review feedback,
but the Copilot advisory wait should be removed or disabled.

Customize these surfaces after import:

- `.github/instructions/idd-review-fix.instructions.md`: remove the E14
  Copilot re-review request and wait path.
- `.github/instructions/idd-pre-merge.instructions.md`: make required
  reviewer approval and branch protection the explicit F2 review gate.
- `.github/instructions/idd-merge.instructions.md`: remove final
  Copilot advisory rechecks while keeping CI, claim, freshness, and
  unresolved-thread checks.
- Repository settings: configure CODEOWNERS, required reviews, or
  branch protection outside IDD.

## No-Advisory Profile

Use `no-advisory` only when the repository intentionally wants the
lightest PR policy: CI, branch protection, and any human review rules
configured outside IDD. This profile should not silently weaken an
existing required-review policy.

Customize the same phase files as `human-required`, but document that
there is no advisory reviewer to request, wait for, or recover. Keep the
normal review snapshot and triage phases because human comments can
still arrive on a PR.

## External-Bot Profile

Use `external-bot` when a repository wants an advisory reviewer such as
a third-party review bot instead of GitHub Copilot. Treat the bot as
advisory only if it has all of these properties:

- A stable GitHub actor identity or requested-reviewer signal.
- A clear way to prove the bot reviewed the current PR head.
- A clear completion, skipped, or unavailable state.
- A policy for classifying the bot's comments as PATH A or PATH B.

Customize these surfaces after import:

- `.github/instructions/idd-advisory-wait.instructions.md`: replace
  Copilot-specific fetch, request, pending, and wait logic with the
  external bot's equivalent signals.
- `.github/instructions/idd-review-fix.instructions.md`: request the
  external bot after pushes, or document why it is requested outside IDD.
- `.github/instructions/idd-pre-merge.instructions.md` and
  `.github/instructions/idd-merge.instructions.md`: replace Copilot
  advisory rechecks with the external bot gate.
- `.github/instructions/idd-review-snapshot.instructions.md` and
  `.github/instructions/idd-review-triage.instructions.md`: update PATH
  B rules if the external bot's comments are advisory.

If the external bot can produce blocking `CHANGES_REQUESTED` reviews or
decision-relevant comments, classify those items as PATH A unless the
operator explicitly narrows them.

### Configuring a primary and an optional secondary advisory bot

The `advisoryWait.primaryBotLogin` and `advisoryWait.secondaryBotLogin`
config fields let a profile choose which bot the advisory-wait gate tracks and
add an **optional, non-gating** fallback. Set
`advisoryWait.primaryBotLogin` to route the gate to a non-Copilot bot (it
defaults to Copilot). Set `advisoryWait.secondaryBotLogin` to a second
requestable review bot when the repository wants a fallback while the primary
is throttled: IDD then requests the secondary **once per HEAD** only when the
primary is cap-exhausted or stalled / rate-limited. The secondary is a
**supplement only** — it never satisfies the primary advisory-wait gate, never
receives a primary `advisory-wait` marker, and its output is ordinary advisory
input (classified PATH A / PATH B by the snapshot and triage rules). Leaving
`advisoryWait.secondaryBotLogin` unset (or equal to the primary) keeps
single-bot behavior. Pick a secondary whose `--add-reviewer` request appears
on the PR timeline so the once-per-HEAD guard can observe it.

## PR Review Profile Edit Surfaces

Use this checklist when a repository records a PR review profile during
onboarding or changes it later. The checklist is the review-policy
contract: the selected profile is not complete until the repository has
recorded the decision, updated the matching phase behavior, and captured
verification evidence.

Apply these shared checks for every profile:

- Record the selected PR review profile in repository documentation that
  future IDD sessions read.
- Record the review-thread resolution profile separately; it is not
  implied by the PR review profile.
- When maintaining the idd-skill source repository, keep source docs and
  exported template docs in sync; when adopting this template, keep
  copied docs and local onboarding notes in sync.
- Run the repository's documented validation commands after editing
  docs or phase instructions.

### `copilot-advisory` Edit Surface

Use the distributed template behavior when Copilot advisory review is
available and desired.

- Documentation: record that the repository keeps `copilot-advisory`.
- Phase instructions: keep
  `.github/instructions/idd-advisory-wait.instructions.md`,
  `.github/instructions/idd-review-fix.instructions.md`,
  `.github/instructions/idd-pre-merge.instructions.md`,
  `.github/instructions/idd-merge.instructions.md`,
  `.github/instructions/idd-review-snapshot.instructions.md`, and
  `.github/instructions/idd-review-triage.instructions.md` aligned with
  the imported default.
- Policy values: record whether the repository keeps or customizes the
  advisory wait and request-cap defaults listed in
  [IDD policy constants](policy-constants.md).
- Verification evidence: confirm that Copilot can be requested or
  observed on a PR and that the E14/F2/F3 advisory wait paths still name
  Copilot intentionally.

### `human-required` Edit Surface

Use this profile when a maintainer, CODEOWNER, or required reviewer is
the authoritative review gate.

- Documentation: record the human review authority, required reviewer
  source, and branch protection or CODEOWNERS rule that enforces it.
- `.github/instructions/idd-review-fix.instructions.md`: remove the E14
  Copilot re-review request and wait path, or replace it with a
  human-review handoff that cannot be mistaken for an advisory bot wait.
- `.github/instructions/idd-advisory-wait.instructions.md`: mark the
  Copilot advisory wait helper unused by this profile, or remove local
  references to it from the customized phase flow.
- `.github/instructions/idd-pre-merge.instructions.md`: make required
  human approval, branch protection, unresolved conversations, CI,
  freshness, and claim evidence the F2 gate.
- `.github/instructions/idd-merge.instructions.md`: remove final
  Copilot advisory rechecks while keeping CI, claim, freshness, required
  review, and unresolved-thread checks.
- `.github/instructions/idd-review-snapshot.instructions.md` and
  `.github/instructions/idd-review-triage.instructions.md`: keep human
  comments in the review universe and remove assumptions that Copilot
  advisory PATH B items must appear.
- Repository settings: configure CODEOWNERS, required reviews, or branch
  protection outside IDD.
- Verification evidence: capture a dry-run or PR-state example showing
  that a PR without required human approval cannot proceed to merge.

### `no-advisory` Edit Surface

Use this profile only when the repository intentionally relies on CI,
branch protection, and any human review rules configured outside IDD.

- Documentation: record that no advisory reviewer is requested or waited
  on, and confirm that this does not weaken an existing required-review
  policy.
- `.github/instructions/idd-review-fix.instructions.md`: remove the E14
  advisory request and wait path.
- `.github/instructions/idd-advisory-wait.instructions.md`: mark the
  advisory wait helper unused by this profile, or remove local
  references to it from the customized phase flow.
- `docs/idd-advisory-wait-shell-fallback.md`: mark the doc unused by
  this profile, or remove local references to it, matching the
  `idd-advisory-wait.instructions.md` disposition above.
- `.github/instructions/idd-pre-merge.instructions.md`: gate on CI,
  branch protection, unresolved conversations, freshness, and claim
  evidence without requiring an advisory reviewer.
- `.github/instructions/idd-merge.instructions.md`: remove final
  advisory rechecks while keeping the other F3 safety gates.
- `.github/instructions/idd-review-snapshot.instructions.md` and
  `.github/instructions/idd-review-triage.instructions.md`: keep human
  comments in scope and remove advisory-only PATH B requirements.
- Verification evidence: capture a PR-state example showing that the
  workflow no longer requests or waits for an advisory reviewer, while
  CI and branch protection remain merge gates.

### `external-bot` Edit Surface

Use this profile when a named non-Copilot bot supplies the advisory
signal.

- Documentation: record the bot actor, how the bot is requested, the
  current-head coverage signal, completion or skipped state, timeout
  policy, and unavailable-state recovery path.
- `.github/instructions/idd-advisory-wait.instructions.md`: replace
  Copilot-specific fetch, request, pending, recovery, and wait logic with
  the external bot's equivalent signals.
- `.github/instructions/idd-review-fix.instructions.md`: request the
  external bot after review-fix pushes, or document why an outside
  system requests it.
- `.github/instructions/idd-pre-merge.instructions.md`: replace Copilot
  advisory checks with the external bot gate for the current PR head.
- `.github/instructions/idd-merge.instructions.md`: repeat the external
  bot freshness gate immediately before merge.
- `.github/instructions/idd-review-snapshot.instructions.md` and
  `.github/instructions/idd-review-triage.instructions.md`: define which
  bot comments are PATH A, which are PATH B, and how blocked or
  unavailable bot states are surfaced.
- Verification evidence: capture a PR-state example showing the bot
  reviewed the current head and that stale, missing, or unavailable bot
  state blocks or holds according to the recorded policy.

## Review Thread Resolution Profiles

Review-thread resolution is a separate policy from who reviews the PR.
The distributed default is `fast-agent-resolve`: after an agent accepts
and fixes feedback, rejects it with a recorded rationale, or handles PATH
B advisory feedback, the agent may resolve the associated thread. This
means "the agent acted on the thread," not "the reviewer agreed."

Repositories that use a different review culture can choose a stricter
profile during onboarding:

| Profile                   | Use when                                                                                  | Agent may resolve                                                                                      | Merge consequence                                                                                           |
| ------------------------- | ----------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------- |
| `fast-agent-resolve`      | The repository wants the distributed default and values a fast agent-managed review loop. | Human and bot threads after accepted fixes, rejected rationales, or PATH B advisory handling.          | F2/F3 may proceed once remaining unresolved threads are either resolved or classified as awaiting reviewer. |
| `hybrid-reviewer-ack`     | Human reviewers expect to confirm human-thread fixes, but bot/advisory threads can close. | Bot/advisory threads; human threads only after reviewer or maintainer acknowledgement.                 | F2/F3 must hold human review threads open until acknowledgement appears and branch protection is satisfied. |
| `strict-reviewer-resolve` | The team treats thread resolution as reviewer-owned.                                      | No human threads; optionally no bot threads unless the repository documents that exception separately. | F2/F3 must wait for reviewer or maintainer resolution before merge.                                         |

Changing away from `fast-agent-resolve` is a workflow change. Update
these files together with the recorded profile decision:

- `.github/instructions/idd-review-triage.instructions.md`: adjust E6
  thread-resolution behavior after PATH A and PATH B dispositions, and
  E7 verification so stricter profiles do not require the fast default.
- `.github/instructions/idd-review-snapshot.instructions.md`: adjust E1
  awaiting-reviewer filtering when human threads must remain visible
  until reviewer acknowledgement.
- `.github/instructions/idd-review-fix.instructions.md`: adjust E13
  resolution after accepted feedback fixes.
- `.github/instructions/idd-pre-merge.instructions.md`: adjust F2
  unresolved-thread handling and awaiting-reviewer exclusions.
- `.github/instructions/idd-merge.instructions.md`: adjust F3
  conversation-resolution fallback behavior.
- Repository settings: confirm whether branch protection requires
  conversation resolution, because that setting can make unresolved
  acknowledged threads block regardless of the selected profile.

## Selection Checklist

Before considering onboarding complete, record the selected profile in
the target repository's local documentation or onboarding notes.

- Choose `copilot-advisory` when the default GitHub Copilot advisory
  path is available and desired.
- Choose `human-required` when human approval is mandatory.
- Choose `no-advisory` only after confirming the repository accepts CI
  and branch protection as sufficient gates.
- Choose `external-bot` only after proving the bot's reviewer identity,
  current-head coverage signal, and wait/timeout behavior.
- For any non-default PR review profile, apply the matching artifact
  from `profiles/` and record its verification evidence.
- Record the review-thread resolution profile separately. Keep
  `fast-agent-resolve` for the distributed default, or customize the
  phase files listed above before choosing `hybrid-reviewer-ack` or
  `strict-reviewer-resolve`.
- Complete the matching PR review profile edit-surface checklist before
  marking onboarding done. Documentation-only recording is sufficient
  only for `copilot-advisory` when the imported default remains
  unchanged.

Changing the profile is a workflow change, not only a documentation
change. Update the phase files that enforce review and merge behavior in
the same pull request as the profile decision.
