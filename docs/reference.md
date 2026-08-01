# IDD Detailed Reference

Use this page when you already know the IDD loop exists and need the
authoritative phase file or policy page for a specific operational
question. It is a navigation surface, not a replacement for the phase
instructions themselves.

For first-time adoption, start with [Getting started](getting-started.md)
or [Core concepts](concepts.md) before using this reference.

## Phase Map

| Need                              | Phase  | Authoritative source                                                                        |
| --------------------------------- | ------ | ------------------------------------------------------------------------------------------- |
| Shared definitions and commands   | All    | [IDD overview](../.github/instructions/idd-overview-core.instructions.md)                   |
| Select the next issue             | A0-A4  | [Discover](../.github/instructions/idd-discover.instructions.md)                            |
| Audit roadmap completion          | A1.5   | [Roadmap audit](../.github/instructions/idd-roadmap-audit.instructions.md)                  |
| Evaluate issue suitability        | A4.5   | [Suitability triage](../.github/instructions/idd-suitability.instructions.md)               |
| Claim an issue safely             | A5     | [Claim](../.github/instructions/idd-claim.instructions.md)                                  |
| Create a worktree and self-review | B-C    | [Work and self-review](../.github/instructions/idd-work.instructions.md)                    |
| Open or update the pull request   | D      | [PR submit](../.github/instructions/idd-pr-submit.instructions.md)                          |
| Interpret CI while waiting        | D/E/F  | [CI polling](../.github/instructions/idd-ci.instructions.md)                                |
| Snapshot review activity          | E1-E3  | [Review snapshot](../.github/instructions/idd-review-snapshot.instructions.md)              |
| Triage review items               | E4-E8  | [Review triage](../.github/instructions/idd-review-triage.instructions.md)                  |
| Fix accepted review feedback      | E9-E15 | [Review fix](../.github/instructions/idd-review-fix.instructions.md)                        |
| Check pre-merge gates             | F1-F2  | [Pre-merge conditions](../.github/instructions/idd-pre-merge.instructions.md)               |
| Resolve merge-policy handoff      | F2.5   | [Merge policy handoff](../.github/instructions/idd-merge-handoff.instructions.md)           |
| Merge, clean up, and loop         | F3-F5  | [Merge execution](../.github/instructions/idd-merge.instructions.md)                        |
| Resume after a crash or handoff   | Resume | [Resume](../.github/instructions/idd-resume.instructions.md)                                |
| Recover from a stalled session    | Resume | [Resume stalled-session recovery](../.github/instructions/idd-resume-stall.instructions.md) |
| Wait for Copilot advisory state   | E/F    | [Advisory wait](../.github/instructions/idd-advisory-wait.instructions.md)                  |

## Policy and Support Pages

| Topic                                  | Read                                                        |
| -------------------------------------- | ----------------------------------------------------------- |
| Cross-agent entry path                 | [IDD workflow guide](idd-workflow.md)                       |
| Review policy choices                  | [IDD review policy profiles](idd-review-policy-profiles.md) |
| Distributed policy defaults            | [IDD policy constants](policy-constants.md)                 |
| Credential boundaries and threat model | [Permissions](permissions.md)                               |
| Safe adopter customization surfaces    | [Customization](customization.md)                           |
| Live digest and comment cleanup        | [IDD comment minimization](idd-comment-minimization.md)     |
| Helper-script adoption policy          | [IDD helper script evaluation](idd-helper-scripts.md)       |
| Reversible vs. gated mutations         | [IDD autonomy contract](idd-autonomy-contract.md)           |

## Maintainer Note

If you maintain an IDD distribution source repository, keep exported
template files and generated onboarding lists in sync when adding or
removing reference pages. In the idd-skill source repository, that means
updating `audit/sync-manifest.json`, `idd-template/ONBOARDING.md`, and
`idd-template/README.md` in the same change.
