# IDD — Advisory-Wait Shell Fallback (AW1 / AW2 / AW3-R / AW3-S / AW3-H / F2 detail)

This document contains the verbatim commands used by the shell
fallback for [advisory-wait](../.github/instructions/idd-advisory-wait.instructions.md)
and for F2's **Advisory convergence** bullet in
[pre-merge](../.github/instructions/idd-pre-merge.instructions.md):
`gh`/`gh api`/`jq` for AW1/AW2 evidence collection and the F2
convergence / `dispositionEvidence` assertion, and a mix of
`gh`/`gh api`/`curl`/`node scripts/...` for the AW3-R/AW3-S/AW3-H
marker-posting and cleanup mutations.

These commands only apply when helper-first cannot be trusted — see
the "Fail-closed fallback trigger" section in the instruction file.

**Prerequisite**: a standalone `jq` binary on `PATH`. `gh api --jq` is
built into `gh` and needs nothing extra, but the commands below piping
into `jq -r`/`jq -s` need the real binary, which neither `gh` nor Git
for Windows installs (see ONBOARDING.md's Step 0 execution-environment
prerequisites).

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
    --jq '.[] | select(.user.login == "copilot-pull-request-reviewer" or .user.login == "copilot-pull-request-reviewer[bot]") |
               {sa: .submitted_at, cid: .commit_id}' \
  | jq -rs 'sort_by(.sa) | last | .cid // ""'
)

COPILOT_PENDING=$(gh api "repos/${OWNER}/${REPO}/pulls/{pr-number}/requested_reviewers" \
  --jq '.users | any(.login == "Copilot" or .login == "copilot-pull-request-reviewer" or .login == "copilot-pull-request-reviewer[bot]")')
# Observed once: requested_reviewers can lag a successful re-request
# or empty on submit, so false is not idle proof.
# LAST_COPILOT_COMMIT == PR_HEAD_SHA remains the SATISFIED signal.

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
                      == "copilot-pull-request-reviewer")
                  or ((.value.requested_reviewer.login // "")
                      == "copilot-pull-request-reviewer[bot]"))))
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
        | jq -r '.[] | select((.body // "") | test("^advisory-wait:|^advisory-wait-recovery:|^<!-- advisory-wait:|^advisory-reroll:")) | .user.login // empty' \
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
# instructions-only profile, or any profile if the helper is unavailable —
# manually, matching the grammar renderAdvisoryWaitRecoveryMarker emits:
GH_TOKEN="${GH_TOKEN:-$(gh auth token)}"
curl -X POST "https://api.github.com/repos/{owner}/{repo}/issues/{pr-number}/comments" \
  -H "Authorization: Bearer ${GH_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"body\":\"advisory-wait-recovery: {agent-id} {PR_HEAD_SHA} {ISO8601-recovery-time} claim:{claim-id} attempt:{n}\"}"
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

## F2

F2's **Advisory convergence** bullet (see
[pre-merge](../.github/instructions/idd-pre-merge.instructions.md))
has two halves. Helper-first stays first: when a helper runtime
exists, run `advisory-convergence.mjs --assert` (or the
profile-selected command) and read
`pre-merge-readiness` `dispositionEvidence`. Use this section only on
`instructions-only`, or when those helpers are unavailable.

**Convergence assertion — semantics.** `converged` is the three
conjuncts from
[Advisory convergence (F2)](idd-helper-scripts.md#advisory-convergence-f2),
restated verbatim: the latest primary-bot review's `commit_id` equals
the current HEAD **and** that review carries zero actionable items
**and** every current-HEAD primary-bot-authored review thread is
resolved **or** carries a valid disposition marker. Do not add or
relax a conjunct. Treat a missing review, an unreadable
`commit_id`/`HEAD`, or an unreadable item count as not converged.

**`dispositionEvidence` half — semantics.** Derive the same
conclusion F2 names in prose: `route` is `proceed` only when
`blockingCount == 0`, meaning both `missingRegularComments` (any
outstanding non-thread regular PR comment from a non-agent author,
including the PR author, lacking a fresh disposition marker) and
`missingThreads` (any review thread, resolved or unresolved, still
lacking one) are empty. A missing or malformed result is unmet. The
ack-only override stays in the instruction file; do not re-derive it
here.

```sh
OWNER=$(gh repo view --json owner --jq '.owner.login')
REPO=$(gh repo view --json name --jq '.name')
PR_HEAD_SHA=$(gh pr view {pr-number} --json headRefOid --jq '.headRefOid')

# Latest primary-bot review (same login set as AW1).
LATEST_REVIEW_JSON=$(
  gh api "repos/${OWNER}/${REPO}/pulls/{pr-number}/reviews" --paginate \
    --jq '.[] | select(.user.login == "copilot-pull-request-reviewer"
          or .user.login == "copilot-pull-request-reviewer[bot]") |
          {sa: .submitted_at, cid: .commit_id, id: .id}' \
  | jq -rs 'sort_by(.sa) | last // {}'
)
LATEST_REVIEW_CID=$(printf '%s' "${LATEST_REVIEW_JSON}" | jq -r '.cid // ""')
LATEST_REVIEW_ID=$(printf '%s' "${LATEST_REVIEW_JSON}" | jq -r '.id // empty')

# Actionable items = posted review comments on that review.
if [ -n "${LATEST_REVIEW_ID}" ]; then
  ACTIONABLE_ITEM_COUNT=$(
    gh api "repos/${OWNER}/${REPO}/pulls/{pr-number}/reviews/${LATEST_REVIEW_ID}/comments" \
      --paginate --jq 'length' | awk '{s+=$1} END {print s+0}'
  )
else
  ACTIONABLE_ITEM_COUNT=""
fi

CONJUNCT1=$([ "${LATEST_REVIEW_CID}" = "${PR_HEAD_SHA}" ] && echo true || echo false)
CONJUNCT2=$([ "${ACTIONABLE_ITEM_COUNT}" = "0" ] && echo true || echo false)

# Current-HEAD primary-bot threads: resolved OR a *fresh* **Accepted** /
# **Rejected** reply (after the latest non-disposition comment).
# Paginate until hasNextPage is false.
THREADS_JSON=$(gh api graphql --paginate -f query='
  query($owner:String!, $repo:String!, $number:Int!, $endCursor:String) {
    repository(owner:$owner, name:$repo) {
      pullRequest(number:$number) {
        reviewThreads(first:100, after:$endCursor) {
          pageInfo { hasNextPage endCursor }
          nodes {
            isResolved
            comments(first:100) {
              pageInfo { hasNextPage }
              nodes { author { login } body createdAt commit { oid } }
            }
          }
        }
      }
    }
  }' -F owner="${OWNER}" -F repo="${REPO}" -F number={pr-number} \
  --jq '.data.repository.pullRequest.reviewThreads.nodes')

# F2 accepts only IDD-agent / trusted-marker authors (same set the helper
# reuses as iddAgentLogins). Empty set fails closed.
CURRENT_MARKER_ACTOR=$(gh api user --jq '.login' 2>/dev/null || true)
IDD_AGENT_LOGIN_JSON=$(
  {
    printf '%s\n' "${IDD_AGENT_LOGINS:-}" | tr ',' '\n'
    printf '%s\n' "${IDD_TRUSTED_MARKER_ACTORS:-}" | tr ',' '\n'
    if [ -n "${CURRENT_MARKER_ACTOR}" ]; then
      printf '%s\n' "${CURRENT_MARKER_ACTOR}"
    fi
  } | sed '/^[[:space:]]*$/d' | sort -fu | jq -Rsc 'split("\n") | map(select(length > 0))'
)

# Originating comment is nodes[0]. A truncated comments page is unmet.
# A disposition is fresh only when it is later than every non-disposition
# comment on the thread (same rule as hasFreshDisposition) and the
# author is an IDD agent / trusted marker actor.
CONJUNCT3=$(printf '%s' "${THREADS_JSON}" | jq -rs --arg sha "${PR_HEAD_SHA}" --argjson agents "${IDD_AGENT_LOGIN_JSON}" '
  def author_login: (.author.login // .user.login // "");
  def is_idd_agent:
    ((author_login | ascii_downcase) as $u
      | ($agents | map(ascii_downcase) | index($u)) != null);
  def is_disp:
    ((.body | startswith("**Accepted**") or startswith("**Rejected**")))
    and is_idd_agent;
  def latest_feedback:
    [.comments.nodes[] | select(is_disp | not) | .createdAt]
    | if length == 0 then null else max end;
  def has_fresh_disp:
    latest_feedback as $fb
    | .comments.nodes | any(is_disp and ($fb == null or .createdAt > $fb));
  add
  | map(select(
      ((.comments.nodes[0].author.login == "copilot-pull-request-reviewer")
        or (.comments.nodes[0].author.login
            == "copilot-pull-request-reviewer[bot]"))
      and (.comments.nodes | any((.commit.oid // "") == $sha))
    ))
  | all((.comments.pageInfo.hasNextPage | not)
      and (.isResolved or has_fresh_disp))
')

CONVERGED=$([ "${CONJUNCT1}" = true ] && [ "${CONJUNCT2}" = true ] && [ "${CONJUNCT3}" = true ] && echo true || echo false)

# dispositionEvidence: later **Accepted** / **Rejected** markers, 1:1
# by count (E6). Non-agent regular comments and every review thread.
COMMENTS_JSON=$(
  gh api "repos/${OWNER}/${REPO}/issues/{pr-number}/comments" --paginate \
    | jq -s 'add // []'
)
DISPOSITION_JSON=$(printf '%s' "${COMMENTS_JSON}" | jq -c --argjson agents "${IDD_AGENT_LOGIN_JSON}" '
  map(select(
    (.body | startswith("**Accepted**") or startswith("**Rejected**"))
    and (((.user.login // "") | ascii_downcase) as $u
      | ($agents | map(ascii_downcase) | index($u)) != null)
  ))
')
MISSING_REGULAR=$(printf '%s\n' "${COMMENTS_JSON}" "${DISPOSITION_JSON}" | jq -s --argjson bots '["copilot-pull-request-reviewer","copilot-pull-request-reviewer[bot]","coderabbitai[bot]","coderabbitai","chatgpt-codex-connector","chatgpt-codex-connector[bot]"]' --argjson agents "${IDD_AGENT_LOGIN_JSON}" '
  .[0] as $comments | .[1] as $disp
  | ($comments
     | map(select(
         (.user.login as $u | ($bots | index($u) | not))
         and (((.user.login // "") | ascii_downcase) as $u
           | ($agents | map(ascii_downcase) | index($u)) == null)
         and (.body | startswith("**Accepted**") or startswith("**Rejected**") | not)
         and (.body | startswith("<!--") | not)
       ))
     | sort_by(.created_at)) as $out
  | ($disp | sort_by(.created_at)) as $ds
  | reduce $out[] as $c (
      {unused: $ds, missing: 0};
      ((.unused | to_entries
        | map(select(.value.created_at > $c.created_at))
        | first) as $hit
      | if $hit == null then .missing += 1
        else .unused |= del(.[$hit.key])
        end)
    )
  | .missing
')
MISSING_THREADS=$(printf '%s' "${THREADS_JSON}" | jq -rs --argjson agents "${IDD_AGENT_LOGIN_JSON}" '
  def author_login: (.author.login // .user.login // "");
  def is_idd_agent:
    ((author_login | ascii_downcase) as $u
      | ($agents | map(ascii_downcase) | index($u)) != null);
  def is_disp:
    ((.body | startswith("**Accepted**") or startswith("**Rejected**")))
    and is_idd_agent;
  def latest_feedback:
    [.comments.nodes[] | select(is_disp | not) | .createdAt]
    | if length == 0 then null else max end;
  def has_fresh_disp:
    latest_feedback as $fb
    | .comments.nodes | any(is_disp and ($fb == null or .createdAt > $fb));
  add
  | map(select(.comments.pageInfo.hasNextPage or (has_fresh_disp | not)))
  | length
')

echo "converged=${CONVERGED} conjuncts=${CONJUNCT1},${CONJUNCT2},${CONJUNCT3}"
echo "missingRegularComments=${MISSING_REGULAR} missingThreads=${MISSING_THREADS}"
# proceed iff CONVERGED is true AND both missing counts are 0.
```
