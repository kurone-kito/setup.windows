# Human-Required Review Policy Artifact

Use this artifact when a maintainer, CODEOWNER, or required reviewer is
the authoritative review gate for every PR. Apply the complete surface
below as one workflow change; documentation alone does not make this
profile active.

## Adopter-Owned Values

Record these values before editing phase behavior:

- Required reviewer source:
- Branch protection rule:
- CODEOWNERS path or reviewer team:
- Review-thread resolution profile:
- Merge policy:
- Verification PR or dry-run reference:

## Patch Surface

| File                                                       | Required local edit                                                                                                                                      |
| ---------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `.github/instructions/idd-review-fix.instructions.md`      | Remove the E14 Copilot re-review request and advisory wait. Replace it with a human-review handoff only if the repository wants that handoff documented. |
| `.github/instructions/idd-advisory-wait.instructions.md`   | Mark the Copilot advisory wait helper unused by this profile, or remove local references to it from the customized phase flow.                           |
| `.github/instructions/idd-pre-merge.instructions.md`       | Make required human approval, branch protection, unresolved conversations, CI, freshness, and claim evidence the F2 gate.                                |
| `.github/instructions/idd-merge.instructions.md`           | Remove final Copilot advisory rechecks while keeping CI, claim, freshness, required review, and unresolved-thread checks.                                |
| `.github/instructions/idd-review-snapshot.instructions.md` | Keep human comments in the review universe and remove assumptions that Copilot advisory PATH B items must appear.                                        |
| `.github/instructions/idd-review-triage.instructions.md`   | Keep human review comments as decision-relevant feedback and remove Copilot-specific advisory requirements.                                              |
| `docs/idd-review-policy-profiles.md`                       | Record the selected `human-required` profile and link to the local verification evidence.                                                                |
| `docs/customization.md` or another local policy document   | Record the reviewer authority, branch protection rule, and review-thread resolution profile.                                                             |

## Verification Evidence

Capture all of these before marking onboarding complete:

- A PR-state example or branch protection dry run showing that a PR
  without required human approval cannot merge.
- Evidence that the review-fix and pre-merge phases no longer request
  or wait for Copilot advisory review.
- Confirmation that unresolved conversations and CI remain merge gates.
- The final local diff showing every file in the patch surface was
  reviewed.

## Completion Note

```markdown
PR review policy profile: human-required
Required reviewer source:
Branch protection rule:
Review-thread resolution profile:
Verification evidence:
Profile artifact applied: profiles/human-required/README.md
```
