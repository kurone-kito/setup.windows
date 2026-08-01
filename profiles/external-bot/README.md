# External-Bot Review Policy Artifact

Use this artifact when a named non-Copilot bot supplies the advisory
review signal. Do not complete this profile with a generic bot name or
an unstated completion signal; the adopter must fill in the bot actor
and the current-head completion proof before the profile is active.

## Adopter-Owned Values

Record these values before editing phase behavior:

- Bot actor: `<external-bot-login>`
- Bot request mechanism: `<external-bot-request-command-or-event>`
- Current-head coverage signal:
  `<external-bot-current-head-signal>`
- Completion or skipped signal:
  `<external-bot-completion-signal>`
- Timeout and unavailable-state policy:
- PATH A comment rules:
- PATH B advisory comment rules:
- Review-thread resolution profile:
- Merge policy:
- Verification PR or dry-run reference:

## Patch Surface

| File                                                       | Required local edit                                                                                                                             |
| ---------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| `.github/instructions/idd-advisory-wait.instructions.md`   | Replace Copilot-specific fetch, request, pending, recovery, and wait logic with the external bot's actor and current-head completion signals.   |
| `.github/instructions/idd-review-fix.instructions.md`      | Request the external bot after review-fix pushes, or document the outside system that requests it.                                              |
| `.github/instructions/idd-pre-merge.instructions.md`       | Replace Copilot advisory checks with the external bot gate for the current PR head.                                                             |
| `.github/instructions/idd-merge.instructions.md`           | Repeat the external bot freshness gate immediately before merge.                                                                                |
| `.github/instructions/idd-review-snapshot.instructions.md` | Fetch the external bot activity and expose enough metadata to prove whether it covered the current PR head.                                     |
| `.github/instructions/idd-review-triage.instructions.md`   | Define which bot comments are PATH A, which are PATH B, and how blocked or unavailable bot states are surfaced.                                 |
| `docs/idd-review-policy-profiles.md`                       | Record the selected `external-bot` profile, the bot actor, and the completion signal without hiding adopter-owned values in phase instructions. |
| `docs/customization.md` or another local policy document   | Record the request mechanism, timeout policy, unavailable-state recovery path, and verification evidence.                                       |

## Verification Evidence

Capture all of these before marking onboarding complete:

- A PR-state example showing the configured bot reviewed the current
  head.
- Evidence that stale, missing, pending, skipped, or unavailable bot
  states block or hold according to the recorded policy.
- Confirmation that PATH A and PATH B bot comment rules are written in
  review triage guidance.
- The final local diff showing every file in the patch surface was
  reviewed.

## Completion Note

```markdown
PR review policy profile: external-bot
Bot actor:
Current-head coverage signal:
Completion or skipped signal:
Timeout and unavailable-state policy:
PATH A comment rules:
PATH B advisory comment rules:
Verification evidence:
Profile artifact applied: profiles/external-bot/README.md
```
