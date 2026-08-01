# IDD — Pre-Merge Conditions Phase (Lite) (F1-F2)

Lite profile for helper-enabled weak/local models. Covers only the
in-scope subset of `idd-pre-merge.instructions.md`: F1's read-only
branch-state check, and F2 as a single pre-merge-readiness helper read.
The standard F2's written prose fallback (discarding helper output and
judging live-fetched evidence directly) is out of scope for this file —
a broken helper is a stop-and-ask condition here, never a prompt to
reason about raw GitHub state yourself. If the repository is
`instructions-only`, use `idd-pre-merge.instructions.md` instead; this
lite file depends entirely on helper runtime and has no written,
non-helper alternative of its own for that case.

## Helper runtime contract

- This file's entire scope depends on two helpers. If either is
  missing, fails, returns invalid or incomplete JSON, or disagrees with
  directly-observable live GitHub state, stop and ask — do not fall
  back to prose judgment or hand-derive the missing evidence yourself.
- Any mismatch between this file and the standard Pre-Merge phase,
  **within this file's in-scope subset** (F1's read-only check and F2's
  helper-read verdict), is a bug in this file. The standard file's
  prose fallback and per-blocker remediation are deliberately excluded,
  not a mismatch to fix.

## Stop-and-ask conditions

- The active claim is ambiguous, disputed, or lost.
- The branch-conflict-state helper reports anything other than
  `syncRecommendation: "none"` (after the `recheck` retry budget in F1
  step 1, if applicable), or is unavailable, fails, or disagrees with
  live state.
- The pre-merge-readiness helper is missing, fails, returns invalid or
  incomplete JSON (missing any of the required top-level fields listed
  in `schemas/pre-merge-readiness.schema.json` — this file directly
  consumes `prHeadSha`, `ready`, and `blockers`, but any other missing
  required field equally signals a broken or contract-violating
  report), or disagrees with live GitHub state.
- The repository is `instructions-only` — this is not a stop-and-wait
  case: switch to `idd-pre-merge.instructions.md` instead, per the
  introduction above.

## F1 — Branch-state check (read-only)

This check never rebases, merges, or pushes.

1. Run the profile-selected branch-conflict-state helper: `node
   scripts/branch-conflict-state.mjs --pr <pr-number>`, or the
   package-manager-profile `idd:branch-conflict-state` command
   (resolve the exact command from `docs/idd-helper-scripts.md` if
   unsure). Read `syncRecommendation`:
   - `"none"`: the branch is conflict-free and, if branch protection
     requires an up-to-date head, already current — proceed to F2.
   - `"recheck"` (mergeability still computing, a transient state):
     re-run the helper after a short wait, up to 3 attempts; only a
     result still `"recheck"` after that budget falls through to stop
     per the condition above.
   - Any other value the helper currently reports (`"merge-main"` or
     `"hold-unknown"`), or the helper is unavailable, fails, or
     disagrees with live state: stop per the
     condition above — the merge-based resync and any content-conflict
     resolution are out of this lite file's scope; that path resumes
     through the E-phase branch-sync check in
     `idd-review-triage.instructions.md`.

## F2 — Pre-merge readiness (helper-read only)

1. Run the pre-merge-readiness helper: `node
   scripts/pre-merge-readiness.mjs --pr <pr-number> --claim-issue
   <issue-number> --claim-id <claim-id> --trusted-marker-logins
   <trusted-login-1>,<trusted-login-2>` (add `--agent-id <agent-id>` if
   known — it tightens the claim check but is optional; add `--nonce
   <nonce>` too, this session's own locally-recorded activation-nonce
   from claim time, whenever one was recorded for the active claim —
   omitting it silently skips the merge-time activation-nonce
   comparison), or the package-manager-profile
   `idd:pre-merge-readiness` command (resolve the exact command from
   `docs/idd-helper-scripts.md` if unsure). This is the same helper the
   standard F2 treats as the authoritative source for the merge
   decision.
2. If the helper fails, returns invalid or incomplete JSON (missing any
   of the required top-level fields listed in
   `schemas/pre-merge-readiness.schema.json`), or its evidence disagrees
   with directly-observable live GitHub state (for example, the claim
   is obviously lost): stop per the condition above. Do not discard the
   helper output and fall back to live-fetch-plus-prose judgment — that
   fallback is the judgment-heavy part the standard file allows and
   this lite file deliberately excludes.
3. Otherwise, record the verdict exactly as the helper reports it:
   `prHeadSha` (F2.5 needs this exact value for its merge command
   candidate — never re-derive it locally), `ready`, and, if `ready` is
   `false`, every entry in `blockers[]` — each a `gate` name plus a
   `detail` string. Do not interpret, re-route, or attempt to remedy
   individual blockers yourself (for example, waiting out a `ci` or
   `advisory-wait` blocker, or returning to E1 for a `review-currency`
   or `disposition-evidence` blocker) — that
   per-blocker routing is exactly the standard file's prose-heavy part
   this lite file excludes.
4. Proceed to `idd-merge-handoff-lite.instructions.md` (F2.5) with this
   recorded verdict, regardless of whether `ready` is `true` or
   `false`. Both outcomes hand off there — this file never runs
   `gh pr merge` or any other mutating merge action itself.
