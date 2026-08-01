# No-Advisory Review Policy Artifact

Use this artifact only when the repository intentionally relies on CI,
branch protection, unresolved-conversation checks, and any human review
rules configured outside IDD. Apply the complete surface below as one
workflow change so later agents do not wait for a reviewer that the
repository no longer uses.

## Adopter-Owned Values

Record these values before editing phase behavior:

- Reason no IDD-managed advisory reviewer is used:
- Branch protection rule:
- Human review rule outside IDD, if any:
- Review-thread resolution profile:
- Merge policy:
- Verification PR or dry-run reference:

## Patch Surface

| File                                                       | Required local edit                                                                                                                        |
| ---------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| `.github/instructions/idd-review-fix.instructions.md`      | Remove the E14 advisory request and wait path.                                                                                             |
| `.github/instructions/idd-advisory-wait.instructions.md`   | Mark the advisory wait helper unused by this profile, or remove local references to it from the customized phase flow.                     |
| `docs/idd-advisory-wait-shell-fallback.md`                 | Mark the doc unused by this profile, or remove local references to it, matching the `idd-advisory-wait.instructions.md` disposition above. |
| `.github/instructions/idd-pre-merge.instructions.md`       | Gate on CI, branch protection, unresolved conversations, freshness, and claim evidence without requiring an advisory reviewer.             |
| `.github/instructions/idd-merge.instructions.md`           | Remove final advisory rechecks while keeping CI, claim, freshness, branch protection, and unresolved-thread checks.                        |
| `.github/instructions/idd-review-snapshot.instructions.md` | Keep human comments in scope and remove advisory-only PATH B requirements.                                                                 |
| `.github/instructions/idd-review-triage.instructions.md`   | Keep human review comments in the review universe and remove advisory-only disposition requirements.                                       |
| `docs/idd-review-policy-profiles.md`                       | Record the selected `no-advisory` profile and link to the local verification evidence.                                                     |
| `docs/customization.md` or another local policy document   | Record why no IDD-managed advisory reviewer is used and which outside gates still protect merges.                                          |

## Verification Evidence

Capture all of these before marking onboarding complete:

- Evidence that review-fix, pre-merge, and merge phases no longer
  request or wait for an advisory reviewer.
- A PR-state example showing CI and branch protection still gate
  merges.
- Confirmation that unresolved conversations remain visible to review
  snapshot and pre-merge checks.
- The final local diff showing every file in the patch surface was
  reviewed.

## Completion Note

```markdown
PR review policy profile: no-advisory
Reason:
Branch protection rule:
Review-thread resolution profile:
Verification evidence:
Profile artifact applied: profiles/no-advisory/README.md
```
