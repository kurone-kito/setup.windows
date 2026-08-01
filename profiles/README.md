# IDD Review Policy Profile Artifacts

This directory packages the supported non-default PR review policy
profiles as adopter-facing artifacts. Each profile README is a
documented patch surface: it names the files to edit, the local values
to fill in, and the verification evidence to capture before onboarding
is complete.

Use these artifacts only when the target repository does not keep the
distributed `copilot-advisory` profile. Copy them with the rest of the
template, choose exactly one non-default profile, and apply the chosen
profile as one unit.

## Available Artifacts

| Profile          | Use when                                                             | Artifact                                   |
| ---------------- | -------------------------------------------------------------------- | ------------------------------------------ |
| `human-required` | A maintainer, CODEOWNER, or required reviewer must approve every PR. | [human-required](human-required/README.md) |
| `no-advisory`    | The repository intentionally has no IDD-managed advisory reviewer.   | [no-advisory](no-advisory/README.md)       |
| `external-bot`   | A named non-Copilot bot supplies the advisory review signal.         | [external-bot](external-bot/README.md)     |

## How to Apply an Artifact

1. Import the default template files first.
2. Open the selected profile README.
3. Fill in every adopter-owned value listed by the profile.
4. Edit every file in the profile's patch surface during the same
   change.
5. Capture the verification evidence named by the profile.
6. Record the completion note in repository documentation that future
   IDD sessions read.

Do not combine profiles unless the repository first documents a new
local policy. Mixed profile behavior is harder for later agents to
verify and should be treated as a separate workflow customization.

## Artifact Contract

Every profile artifact must record:

- The local values the adopter owns.
- The complete file list affected by the profile.
- The intended edit for each file.
- The evidence required to prove the selected policy is active.
- A completion note format that can be copied into local repository
  documentation.

When maintaining a repository that adopts this template, keep these artifacts
aligned with `docs/idd-review-policy-profiles.md` and `../ONBOARDING.md`.
