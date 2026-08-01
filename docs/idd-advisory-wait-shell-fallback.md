# IDD — Advisory-Wait Shell Fallback (AW1 / AW2 / AW3-R / AW3-S / AW3-H detail)

This document contains the verbatim commands used by the shell
fallback for [advisory-wait](../.github/instructions/idd-advisory-wait.instructions.md):
`gh`/`gh api`/`jq` for AW1/AW2 evidence collection, and a mix of
`gh`/`gh api`/`curl`/`node scripts/...` for the AW3-R/AW3-S/AW3-H
marker-posting and cleanup mutations.

These commands only apply when helper-first cannot be trusted — see
the "Fail-closed fallback trigger" section in the instruction file.

The instruction file owns the contract (decision rules, ordering,
fail-closed handling, and what each step must produce); this document
is the command reference. If the contract and these commands diverge,
the contract wins and these commands must be updated.

## AW1

```sh
OWNER=$(gh repo view --json owner --jq '.owner.login')
REPO=$(gh repo view --json name --jq '.name')

LAST_COPILOT_COMMIT=$(
  gh api "repos/${OWNER}/${REPO}/pulls/{pr-number}/reviews" \
    --paginate \
    --jq '.[] | select(.user.login | startswith("copilot-pull-request-reviewer")) |
               {sa: .submitted_at, cid: .commit_id}' \
  | jq -rs 'sort_by(.sa) | last | .cid // ""'
)

COPILOT_PENDING=$(gh api "repos/${OWNER}/${REPO}/pulls/{pr-number}/requested_reviewers" \
  --jq '.users | any(.login == "Copilot" or (.login | startswith("copilot-pull-request-reviewer")))')

COPILOT_PENDING_COVERS_HEAD=$(
  gh api "repos/${OWNER}/${REPO}/issues/{pr-number}/timeline" \
    -H "Accept: application/vnd.github+json" \
    --paginate \
    | jq -r -s --arg sha "${PR_HEAD_SHA}" '
        (add // [])
        | to_entries
        | (map(select(.value.event == "committed"
             and ((.value.sha // .value.commit_id // "") == $sha)))
           | last | .key // null) as $head_index
        | (map(select(.value.event == "review_requested"
             and (((.value.requested_reviewer.login // "") == "Copilot")
                  or ((.value.requested_reviewer.login // "")
                      | startswith("copilot-pull-request-reviewer")))))
           | last | .key // null) as $request_index
        | ($head_index != null and $request_index != null and
           $request_index > $head_index)
      '
)
```

## AW2

```sh
ADVISORY_COMMENTS_JSON=$(
  gh api "repos/${OWNER}/${REPO}/issues/{pr-number}/comments" --paginate \
    | jq -s 'add // []'
)
CURRENT_MARKER_ACTOR=$(gh api user --jq '.login' 2>/dev/null || true)
TRUSTED_MARKER_ACTORS="${IDD_TRUSTED_MARKER_ACTORS:-}"
TRUST_COLLABORATOR_MARKERS="${IDD_TRUST_COLLABORATOR_MARKERS:-}"
TRUSTED_MARKER_LOGIN_JSON=$(
  {
    if [ -n "$CURRENT_MARKER_ACTOR" ]; then
      printf '%s\n' "$CURRENT_MARKER_ACTOR"
    fi
    printf '%s\n' "$TRUSTED_MARKER_ACTORS" | tr ',' '\n'
    if printf '%s\n' "$TRUST_COLLABORATOR_MARKERS" | grep -Eiq '^(1|true|yes)$'; then
      printf '%s\n' "$ADVISORY_COMMENTS_JSON" \
        | jq -r '.[] | select((.body // "") | test("^advisory-wait:|^advisory-wait-recovery:|^<!-- advisory-wait:")) | .user.login // empty' \
        | sort -fu \
        | while IFS= read -r login; do
          permission=$(
            gh api "repos/${OWNER}/${REPO}/collaborators/${login}/permission" \
              --jq '.permission' 2>/dev/null || true
          )
          case "$permission" in
            admin | maintain | write) printf '%s\n' "$login" ;;
          esac
        done
    fi
  } | jq -R -s 'split("\n") | map(ascii_downcase | select(length > 0)) | unique'
)

EARLIEST_SAME_HEAD_AT=$(
  printf '%s\n' "$ADVISORY_COMMENTS_JSON" \
    | jq -r \
      --arg sha "$PR_HEAD_SHA" \
      --argjson trusted_marker_logins "$TRUSTED_MARKER_LOGIN_JSON" '
        def marker_login: (.user.login // "" | ascii_downcase);
        def trusted_marker_actor:
          marker_login as $login
          | ($login | length > 0)
          and (($trusted_marker_logins | index($login)) != null);
        [.[] | select(
          trusted_marker_actor
          and (
            ((.body // "") | test("^advisory-wait: [^ ]+ " + $sha + "(?: |$)")) or
            ((.body // "") | test("^advisory-wait-recovery: [^ ]+ " + $sha + "(?: |$)")) or
            ((.body // "") | test("^<!-- advisory-wait: [^ ]+ " + $sha + " [^ ]+ -->$"))
          )
        )]
        | min_by(.created_at) | .created_at // ""
      '
)

REQUEST_MARKER_COUNT=$(
  printf '%s\n' "$ADVISORY_COMMENTS_JSON" \
    | jq -r \
      --argjson trusted_marker_logins "$TRUSTED_MARKER_LOGIN_JSON" '
        def marker_login: (.user.login // "" | ascii_downcase);
        def trusted_marker_actor:
          marker_login as $login
          | ($login | length > 0)
          and (($trusted_marker_logins | index($login)) != null);
        [.[] | select(
          trusted_marker_actor
          and ((.body // "") | test("^advisory-wait:|^<!-- advisory-wait:"))
        )]
        | length
      '
)
```

## AW3-R

Post via the profile-selected post-idd-marker command (source repo /
vendored-node: `node scripts/post-idd-marker.mjs`; package-manager /
ephemeral-npx: resolve from `docs/idd-helper-scripts.md`)
`--type advisory-recovery --target pr <pr-number> --agent-id <id>
--head-sha <PR_HEAD_SHA> --timestamp <ISO8601> --apply`, or manually:

```sh
GH_TOKEN="${GH_TOKEN:-$(gh auth token)}"
curl -X POST "https://api.github.com/repos/{owner}/{repo}/issues/{pr-number}/comments" \
  -H "Authorization: Bearer ${GH_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"body\":\"advisory-wait-recovery: {agent-id} {PR_HEAD_SHA} {ISO8601-recovery-time}\"}"
```

## AW3-S

Only when `staleRequestRecovery` is `"attempt"` (instruction file's
Eligibility check). Steps 2 and 4 (verify removal/HEAD; verify
association) are read-only checks the instruction file specifies
directly — no command block needed here.

```sh
# Step 1 — remove the stale request
gh pr edit {pr-number} --remove-reviewer "@{primary-advisory-bot}"
# on a GraphQL login-resolution failure:
gh api repos/{owner}/{repo}/pulls/{pr-number}/requested_reviewers \
  -X DELETE -f "reviewers[]={primary-advisory-bot-rest-login}"

# Step 3 — request again, after step 2 verifies the removal
gh pr edit {pr-number} --add-reviewer "@{primary-advisory-bot}"
# on a GraphQL login-resolution failure:
gh api repos/{owner}/{repo}/pulls/{pr-number}/requested_reviewers \
  -X POST -f "reviewers[]={primary-advisory-bot-rest-login}"

# Step 5 — post exactly one bound marker, only after step 4 verifies
# source repo / vendored-node profile:
node scripts/post-idd-marker.mjs --type advisory-recovery --target pr <pr-number> \
  --agent-id <id> --claim-id <id> --head-sha <PR_HEAD_SHA> \
  --attempt <n> --timestamp <ISO8601> --apply
# package-manager / ephemeral-npx profile, resolve the command name from
# docs/idd-helper-scripts.md:
<profile-selected-post-idd-marker-command> --type advisory-recovery \
  --target pr <pr-number> --agent-id <id> --claim-id <id> \
  --head-sha <PR_HEAD_SHA> --attempt <n> --timestamp <ISO8601> --apply
```

## AW3-H

```sh
# source repo / vendored-node profile:
node scripts/minimize-superseded-markers.mjs \
  --subject-ids "<id1>,<id2>,..." \
  --classifier OUTDATED \
  --trusted-marker-logins "<trusted-login-1>,<trusted-login-2>" \
  --apply
# package-manager / ephemeral-npx profile, resolve the command name from
# docs/idd-helper-scripts.md:
<profile-selected-minimize-superseded-markers-command> \
  --subject-ids "<id1>,<id2>,..." \
  --classifier OUTDATED \
  --trusted-marker-logins "<trusted-login-1>,<trusted-login-2>" \
  --apply
```
