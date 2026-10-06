---
type: reference
title: IDD — Advisory-Wait Shell Fallback (AW1 / AW2 / AW3-R / AW3-S / AW3-H / F2 detail)
description: Provides the verbatim gh, gh api, jq, and curl commands the advisory-wait and F2 advisory-convergence shell fallbacks use when helper support cannot be trusted.
tags: [advisory-wait, shell-fallback]
---

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

The two filter interfaces are separate. `gh api --jq` accepts one jq
filter string as its option value:

```sh
gh api "repos/${OWNER}/${REPO}/pulls/{pr-number}" --jq '.head.sha'
```

When a filter needs shell variables, pipe the JSON to standalone `jq`,
where `--arg` binds a value for the filter:

```sh
gh api "repos/${OWNER}/${REPO}/pulls/{pr-number}" \
  | jq --arg expected "${PR_HEAD_SHA}" '.head.sha == $expected'
```

Observed 2026-09-19 in issue [#3142][jq-incident], round 21 of the
[field-feedback gist][jq-feedback-gist]: an agent copied standalone
`jq --arg` syntax into `gh api --jq`, causing the command to fail before
the intended check. This is an observed failure, not preventive guidance.

[jq-incident]: https://github.com/kurone-kito/idd-skill/issues/3142
[jq-feedback-gist]: https://gist.github.com/kurone-kito/9f2d7871542cb2f7a255f92a7c1232d0

Do not pass standalone jq options to `gh api`; keep the API call and jq
process as separate commands.

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
  --jq '.users | any((.login // "" | ascii_downcase) as $l | $l == "copilot" or $l == "copilot-pull-request-reviewer" or $l == "copilot-pull-request-reviewer[bot]")')
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
             and (((.value.requested_reviewer.login // "" | ascii_downcase) as $l
                  | $l == "copilot"
                  or $l == "copilot-pull-request-reviewer"
                  or $l == "copilot-pull-request-reviewer[bot]"))))
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
        | jq -r '.[] | select((.body // "") | test("^advisory-wait:|^advisory-wait-recovery:|^<!--\\s*advisory-wait:|^advisory-reroll:")) | .user.login // empty' \
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
            ((.body // "") | test("^advisory-wait:\\s+\\S+\\s+" + $sha + "\\s+\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(?:\\.\\d+)?Z\\s*$")) or
            ((.body // "") | test("^advisory-wait-recovery:\\s+\\S+\\s+" + $sha + "\\s+\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(?:\\.\\d+)?Z(?:\\s+claim:\\S+\\s+attempt:[1-9]\\d*)?\\s*$")) or
            ((.body // "") | test("^<!--\\s*advisory-wait:\\s+\\S+\\s+" + $sha + "\\s+\\S+\\s*-->\\s*$"))
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
          and ((.body // "") | test("^advisory-wait:|^<!--\\s*advisory-wait:"))
        )]
        | length
      '
)

# #2327: head-scoped, request-only (excludes advisory-wait-recovery:) --
# distinct from EARLIEST_SAME_HEAD_AT above (a recovery-only marker also
# satisfies that) and from REQUEST_MARKER_COUNT above (not head-scoped).
SAME_HEAD_REQUEST_MARKER_PRESENT=$(
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
            ((.body // "") | test("^advisory-wait:\\s+\\S+\\s+" + $sha + "\\s+\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(?:\\.\\d+)?Z\\s*$")) or
            ((.body // "") | test("^<!--\\s*advisory-wait:\\s+\\S+\\s+" + $sha + "\\s+\\S+\\s*-->\\s*$"))
          )
        )] | length > 0
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

## Registration-proven review request

E14's `REQUEST_NEEDED` branch uses this procedure in its default
event-or-node mode. AW3-S step 3 below calls it with `aw3-s`, which
requires the event-after-HEAD mode because a request node is not tied to
a commit. Snapshot both matching proofs before the first mutation: the
latest `review_requested` event and the matching `reviewRequests` node
ids. Post an E14 `advisory-wait` marker only when a re-read finds a
newer matching event after the current HEAD `committed` event, or a
request node whose id was absent from the snapshot. AW3-S accepts only
the newer event after HEAD. An older event, exit status, or HTTP 201 is
not evidence. Observed 2026-09-26 in issue
`#3500` (refs issues `#3481` and `#3491`): both calls returned success
while `requested_reviewers` stayed empty and no `review_requested` event
was recorded.

```sh
BOT_REST_LOGIN={primary-advisory-bot-rest-login}
export BOT_REST_LOGIN
PR_NODE_ID=$(gh pr view {pr-number} --json id --jq '.id')
if [ -z "${PR_HEAD_SHA:-}" ]; then
  PR_HEAD_SHA=$(gh pr view {pr-number} --json headRefOid --jq '.headRefOid')
fi
BOT_REST_LOGIN_BARE=${BOT_REST_LOGIN%\[bot\]}
export BOT_REST_LOGIN_BARE
claim_revalidate() {
  # Run from the issue worktree. The profile-selected resume-claim-routing
  # command (source repo / vendored-node: `node scripts/resume-claim-routing.mjs`;
  # package-manager / ephemeral-npx: resolve from `docs/idd-helper-scripts.md`)
  # with `--assert` exits non-zero on any verdict except already_owned/keep.
  # That proves the claim id (and the activation nonce when --nonce is given
  # and a winner marker exists) and, when a worktree occupies the claimed
  # branch, its lock, generated tokens and cwd. With no worktree on that
  # branch it proves the claim id (and nonce) only.
  # Never pipe it: a pipe hides its exit status. Its stderr line names the
  # verdict and, on owner_evidence_required, the failed proof.
  <profile-selected-resume-claim-routing-command> --issue {issue-number} \
    --claim-id {claim-id} --nonce {nonce} --assert >/dev/null || return 2
  LIVE_PR_HEAD_SHA=$(gh pr view {pr-number} --json headRefOid --jq '.headRefOid') || return 2
  [ "$LIVE_PR_HEAD_SHA" = "$PR_HEAD_SHA" ] || {
    echo "PR HEAD moved; restart from E1" >&2
    return 2
  }
}
head_timeline_index() {
  local result
  result=$(gh api repos/{owner}/{repo}/issues/{pr-number}/timeline --paginate) || return 1
  printf '%s' "$result" | jq -r -s --arg sha "$PR_HEAD_SHA" '
    (add // [])
    | to_entries
    | map(select(.value.event == "committed"
        and ((.value.sha // .value.commit_id // "") == $sha)))
    | last | .key // empty' || return 1
}
request_event() {
  local result
  result=$(gh api repos/{owner}/{repo}/issues/{pr-number}/timeline --paginate) || return 1
  printf '%s' "$result" | jq -r -s '
    def matches_configured_reviewer($login):
      ($login.login // "" | ascii_downcase) as $l
      | ($login.type // "" | ascii_downcase) as $type
      | (env.BOT_REST_LOGIN_BARE | ascii_downcase) as $bare
      | (env.BOT_REST_LOGIN | ascii_downcase) as $configured
      | (($type == "user" and $l == $configured)
         or ($type == "bot"
             and ($l == $bare
             or $l == ($bare + "[bot]")
             or (($bare == "copilot"
                  or $bare == "copilot-pull-request-reviewer")
                 and ($l == "copilot"
                      or $l == "copilot-pull-request-reviewer"
                      or $l == "copilot-pull-request-reviewer[bot]")))));
    (add // [])
    | to_entries
    | map(select(.value.event == "review_requested"
        and matches_configured_reviewer(.value.requested_reviewer)))
    | last
    | if . == null then empty
      else [.value.id, .value.created_at, .key] | @tsv end' || return 1
}
request_nodes() {
  local result
  result=$(gh api graphql -F owner={owner} -F repo={repo} -F number={pr-number} -f query='query($owner:String!,$repo:String!,$number:Int!){repository(owner:$owner,name:$repo){pullRequest(number:$number){reviewRequests(first:100){nodes{id requestedReviewer{__typename ... on Bot{login} ... on User{login}}}}}}}') || return 1
  printf '%s' "$result" |
    jq -r '
      def matches_configured_reviewer($login):
        ($login.login // "" | ascii_downcase) as $l
        | ($login.__typename // "" | ascii_downcase) as $type
        | (env.BOT_REST_LOGIN_BARE | ascii_downcase) as $bare
        | (env.BOT_REST_LOGIN | ascii_downcase) as $configured
        | (($type == "user" and $l == $configured)
           or ($type == "bot"
               and ($l == $bare
               or $l == ($bare + "[bot]")
               or (($bare == "copilot"
                    or $bare == "copilot-pull-request-reviewer")
                   and ($l == "copilot"
                        or $l == "copilot-pull-request-reviewer"
                        or $l == "copilot-pull-request-reviewer[bot]")))));
      .data.repository.pullRequest.reviewRequests.nodes[]
      | select(matches_configured_reviewer(.requestedReviewer))
      | .id'
}
registration_attempt() {
  local evidence_mode=${1:-e14}
  case "$evidence_mode" in
    e14|aw3-s) ;;
    *) echo "unknown registration evidence mode" >&2; return 2 ;;
  esac
  HEAD_TIMELINE_INDEX=
  if [ "$evidence_mode" = "aw3-s" ]; then
    HEAD_TIMELINE_INDEX=$(head_timeline_index) || {
      echo "HEAD timeline snapshot unreadable" >&2
      return 2
    }
    [ -n "$HEAD_TIMELINE_INDEX" ] || {
      echo "HEAD committed timeline event absent" >&2
      return 2
    }
  else
    # E14 may use a fresh request node when GitHub has not exposed the
    # current HEAD's committed timeline event yet. Event proof remains
    # preferred when the index is available, but it is not mandatory in
    # this mode.
    HEAD_TIMELINE_INDEX=$(head_timeline_index) || HEAD_TIMELINE_INDEX=
  fi
  EVENT_BEFORE=$(request_event) || { echo "event snapshot unreadable" >&2; return 2; }
  NODES_BEFORE=
  if [ "$evidence_mode" != "aw3-s" ]; then
    NODES_BEFORE=$(request_nodes) || { echo "request-node snapshot unreadable" >&2; return 2; }
  fi
  registration_ok() {
    EVENT_AFTER=$(request_event) || return 2
    EVENT_ID=$(printf '%s\n' "$EVENT_AFTER" | cut -f1)
    EVENT_INDEX=$(printf '%s\n' "$EVENT_AFTER" | cut -f3)
    EVENT_NEW=false
    case "$EVENT_INDEX" in
      ''|*[!0-9]*) ;;
      *)
        if [ -n "$EVENT_ID" ] \
          && [ -n "$HEAD_TIMELINE_INDEX" ] \
          && ! printf '%s\n' "$EVENT_BEFORE" | cut -f1 | grep -Fxq "$EVENT_ID" \
          && [ "$EVENT_INDEX" -gt "$HEAD_TIMELINE_INDEX" ]; then
          EVENT_NEW=true
        fi
        ;;
    esac
    [ "$EVENT_NEW" = true ] && return 0
    [ "$evidence_mode" = "aw3-s" ] && return 1
    NODES_AFTER=$(request_nodes) || return 2
    NODE_FRESH=false
    while IFS= read -r node; do
      [ -n "$node" ] && ! printf '%s\n' "$NODES_BEFORE" | grep -Fxq "$node" && NODE_FRESH=true
    done <<EOF
$NODES_AFTER
EOF
    [ "$NODE_FRESH" = true ]
  }
  registration_check() {
    local max_attempts=1 attempt=1 status=1
    [ "$evidence_mode" = "aw3-s" ] && max_attempts=3
    while [ "$attempt" -le "$max_attempts" ]; do
      if registration_ok; then return 0; else status=$?; fi
      [ "$status" -eq 2 ] && return 2
      [ "$attempt" -eq "$max_attempts" ] && return 1
      sleep 1
      attempt=$((attempt + 1))
    done
    return "$status"
  }

  # Re-run the shared claim revalidation gate immediately before every
  # reviewer-request mutation. A failed gate must stop this attempt.
  claim_revalidate || return 3
  gh pr edit {pr-number} --add-reviewer "@{primary-advisory-bot}" || :
  if registration_check; then status=0; else status=$?; fi
  if [ "$status" -eq 0 ]; then
    claim_revalidate || return 3
    return 0
  fi
  [ "$status" -eq 2 ] && return 2

  claim_revalidate || return 3
  gh api repos/{owner}/{repo}/pulls/{pr-number}/requested_reviewers \
    -X POST -f "reviewers[]={primary-advisory-bot-rest-login}" || :
  if registration_check; then status=0; else status=$?; fi
  if [ "$status" -eq 0 ]; then
    claim_revalidate || return 3
    return 0
  fi
  [ "$status" -eq 2 ] && return 2

  # Resolve the id and account type live. The GraphQL mutation has separate
  # userIds and botIds inputs; user(login:) does not resolve a Bot, and using
  # botIds for a User-typed configured reviewer silently loses the request.
  REVIEWER_JSON=$(gh api "users/{primary-advisory-bot-rest-login}") || return 2
  REVIEWER_NODE_ID=$(printf '%s' "$REVIEWER_JSON" | jq -r '.node_id // empty') || return 2
  REVIEWER_TYPE=$(printf '%s' "$REVIEWER_JSON" | jq -r '(.type // "") | ascii_downcase') || return 2
  [ -n "$REVIEWER_NODE_ID" ] || return 2
  claim_revalidate || return 3
  case "$REVIEWER_TYPE" in
    bot)
      jq -n --arg id "$PR_NODE_ID" --arg reviewer "$REVIEWER_NODE_ID" \
        '{query:"mutation($id:ID!,$reviewer:[ID!]!){ requestReviews(input:{pullRequestId:$id,botIds:$reviewer,union:true}){ clientMutationId } }",variables:{id:$id,reviewer:[$reviewer]}}' |
        gh api graphql --input - || :
      ;;
    user)
      jq -n --arg id "$PR_NODE_ID" --arg reviewer "$REVIEWER_NODE_ID" \
        '{query:"mutation($id:ID!,$reviewer:[ID!]!){ requestReviews(input:{pullRequestId:$id,userIds:$reviewer,union:true}){ clientMutationId } }",variables:{id:$id,reviewer:[$reviewer]}}' |
        gh api graphql --input - || :
      ;;
    *)
      echo "configured reviewer account type is not Bot or User" >&2
      return 2
      ;;
  esac
  if registration_check; then status=0; else status=$?; fi
  if [ "$status" -eq 0 ]; then
    claim_revalidate || return 3
    return 0
  fi
  [ "$status" -eq 2 ] && return 2
  echo "registration evidence absent" >&2
  return 1
}

# E14 stops/asks on status 1 or 2. Status 3 means the claim/HEAD guard
# failed and stops the route for an E1 restart. AW3-S may recheck status 1,
# but status 2 is unreadable evidence: hold via AW4 and never count a cycle.
REGISTRATION_STATUS=0
registration_attempt e14 || REGISTRATION_STATUS=$?

case "$REGISTRATION_STATUS" in
  0)
    # The marker is a separate GitHub mutation. Revalidate after registration
    # evidence is proven and immediately before posting it.
    claim_revalidate || exit 2
    <profile-selected-post-idd-marker-command> --type advisory --target pr <pr-number> \
      --agent-id <id> --head-sha <PR_HEAD_SHA> --timestamp <ISO8601> --apply
    # instructions-only profile: post the same advisory-wait body manually
    # through the GitHub issue-comments API, preserving the marker grammar.
    ;;
  1 | 2 | 3)
    echo "E14 registration did not prove a safe marker step; stop and ask" >&2
    exit 2
    ;;
  *)
    echo "E14 registration returned an unexpected status" >&2
    exit 2
    ;;
esac
```

The post-request reads must run after each mutating attempt. The
`EVENT_BEFORE`/`NODES_BEFORE` values are the baselines for the selected
mode. E14 can carry a fresh node proof when the event is delayed, but AW3-S
requires the event-after-HEAD proof because a request node has no commit
association. E14 posts its
`advisory-wait` marker only when `REGISTRATION_STATUS` is `0`; statuses
`1`/`2` stop and ask, while status `3` stops for an E1 restart. AW3-S
uses step 4 only after readable event evidence; status `2` routes to AW4
and cannot count a failed cycle or post a marker.

## AW3-S

Only when `staleRequestRecovery` is `"attempt"` (instruction file's
Eligibility check). Steps 2 and 4 (verify removal/HEAD; verify
association) are read-only checks the instruction file specifies
directly — no command block needed here.

```sh
revalidate_head() {
  <profile-selected-resume-claim-routing-command> --issue {issue-number} \
    --claim-id {claim-id} --nonce {nonce} --assert >/dev/null || return 2
  LIVE_PR_HEAD_SHA=$(gh pr view {pr-number} --json headRefOid --jq '.headRefOid') || return 2
  [ "$LIVE_PR_HEAD_SHA" = "$PR_HEAD_SHA" ] || {
    echo "PR HEAD moved; restart from E1" >&2
    return 2
  }
}

# Resolve and validate the entry before any destructive mutation. A
# non-pending entry starts at Step 3 and must not remove a request that may
# have become visible during propagation (#2327, #3507).
if [ -z "${AW3S_ENTRY:-}" ]; then
  case "${COPILOT_PENDING:-}" in
    true) AW3S_ENTRY=pending ;;
    false) AW3S_ENTRY=non-pending ;;
    *)
      echo "AW3-S requires AW3S_ENTRY or COPILOT_PENDING from the AW3 decision" >&2
      exit 2
      ;;
  esac
fi
case "$AW3S_ENTRY" in
  pending | non-pending) ;;
  *)
    echo "AW3-S entry must be pending or non-pending" >&2
    exit 2
    ;;
esac

# Step 1 — remove the stale request. PENDING entry only (COPILOT_PENDING
# was "true"). Skip this step entirely for the non-pending entry (#2327 --
# COPILOT_PENDING was already "false", nothing is pending to remove) and
# start at Step 3 instead.
if [ "$AW3S_ENTRY" = "pending" ]; then
  revalidate_head || exit 2
  gh pr edit {pr-number} --remove-reviewer "@{primary-advisory-bot}"
  # on a GraphQL login-resolution failure, this DELETE is an attempt only:
  # a 422 "Could not resolve to a User node" for the default bot (PR #3471)
  # is not a removal result -- retry gh pr edit --remove-reviewer alone
  # (3 attempts) before any AW4 hold; never conclude from this call or an
  # empty requested_reviewers read (#2167, #3503).
  revalidate_head || exit 2
  gh api repos/{owner}/{repo}/pulls/{pr-number}/requested_reviewers \
    -X DELETE -f "reviewers[]={primary-advisory-bot-rest-login}"
fi

# Step 3 — request again (non-pending entry: the first mutating step;
# pending entry: after step 2 verifies the removal). Run the
# registration-proven review request above in AW3-S mode. Its
# event snapshots precede both mutations, but step 4 accepts only
# a fresh review_requested event after HEAD's committed event.
if ! command -v registration_attempt >/dev/null 2>&1; then
  echo "AW3-S requires the shared registration procedure" >&2
  exit 2
fi
REGISTRATION_STATUS=0
registration_attempt aw3-s || REGISTRATION_STATUS=$?

# AW3S_ENTRY is now "pending" or "non-pending" from AW3's decision.
# Pending success is counted; pending status 1 returns without a marker.
# Non-pending status 0 is ordinary success and also returns without a
# marker; only its status 1 failure reaches the counted marker below.
case "$REGISTRATION_STATUS" in
  2)
    echo "AW3-S evidence unreadable; route to AW4" >&2
    exit 2
    ;;
  3)
    echo "AW3-S claim/HEAD guard failed; restart from E1" >&2
    exit 2
    ;;
  0 | 1) ;;
  *)
    echo "AW3-S registration returned an unexpected status" >&2
    exit 2
    ;;
esac
if [ "$AW3S_ENTRY" = "pending" ] && [ "$REGISTRATION_STATUS" -eq 1 ]; then
  echo "AW3-S pending request still unproven; return to polling" >&2
  exit 1
fi
if [ "$AW3S_ENTRY" = "non-pending" ] && [ "$REGISTRATION_STATUS" -eq 0 ]; then
  echo "AW3-S re-request registered; return without counting" >&2
  exit 0
fi

# Step 5 -- post exactly one bound marker, only once step 4 reaches a
# counted disposition: proven re-registration for a pending entry, or
# proven failure-to-register within the same short budget for a
# non-pending entry (#2327 -- see the instruction file's step 4).
# Re-run the shared claim gate and compare the live PR head immediately
# before posting; on either mismatch, abort and restart from E1.
revalidate_head || exit 2
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

`--subject-ids` needs a GraphQL node id, not a REST numeric id —
convert first: `gh api repos/{owner}/{repo}/issues/comments/{comment_id}
-q '.node_id'` (other kinds: pass `--help` to the command below).

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
