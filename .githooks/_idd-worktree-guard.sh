# shellcheck shell=sh
# IDD disposable-worktree guard — shared check for the pre-commit and
# pre-push hooks. Pure POSIX sh: no node, jq, python, or other runtime
# dependency, so it works in any repository that adopts the IDD template.
#
# The guard is opt-in. It does nothing unless worktreeGuard.enabled is
# true in .github/idd/config.json. When enabled, it refuses a commit or
# push made from the PRIMARY worktree while HEAD is on an implementation
# branch (issue/* or roadmap-audit/*), because B1 requires that work to
# live in a sibling worktree. Run git with --no-verify to bypass it
# intentionally.

idd_worktree_guard_check() {
  # $1: human-readable action word ("commit" or "push").
  action="$1"

  # Single combined `git rev-parse` replaces three separate forked
  # pipelines (--show-toplevel; `git worktree list --porcelain | sed |
  # head` to find the primary worktree; --abbrev-ref HEAD), leaving
  # exactly two external-process forks -- this call and the `tr` below
  # -- on the common "enabled, not on a guarded branch" path with the
  # default worktreeGuard.branchPatterns; a configured override adds
  # two more `tr` forks in the patterns= block further down. A later
  # change must not silently regress either count.
  #
  # This must not gate on exit status: an unborn HEAD makes the
  # trailing --abbrev-ref HEAD resolution fail (git exits 128), but git
  # still prints the three preceding values, plus the literal token
  # "HEAD" it could not resolve, to stdout -- confirmed locally. That
  # "HEAD" line is indistinguishable from an actual detached HEAD's
  # --abbrev-ref output, so both already fall through the existing
  # branch != HEAD check below without special-casing. Whenever the
  # first value (toplevel) fails outright -- outside a work tree, or
  # inside a bare .git directory -- git prints nothing at all, so the
  # loop below leaves repo_root empty and the guard returns 0. The
  # trailing `|| true` keeps that non-zero exit from tripping a caller
  # that sources this file under `set -e`, matching the old code's own
  # `|| return 0` short-circuit.
  info=$(git rev-parse --show-toplevel --git-dir --git-common-dir --abbrev-ref HEAD 2>/dev/null) || true
  repo_root='' git_dir='' git_common_dir='' branch=''
  i=0
  while IFS= read -r line; do
    i=$((i + 1))
    case $i in
      1) repo_root=$line ;;
      2) git_dir=$line ;;
      3) git_common_dir=$line ;;
      4) branch=$line ;;
    esac
  done <<_IDD_WTG_EOF_
$info
_IDD_WTG_EOF_
  [ -n "$repo_root" ] || return 0

  config="$repo_root/.github/idd/config.json"
  [ -f "$config" ] || return 0

  # Opt-in gate: worktreeGuard.enabled must be true. Collapse whitespace
  # so both pretty-printed and minified JSON parse, then inspect only the
  # worktreeGuard object body so key order does not matter.
  compact=$(tr -d ' \t\r\n' < "$config")
  case "$compact" in
    *'"worktreeGuard":{'*) ;;
    *) return 0 ;;
  esac
  guard_body=${compact#*'"worktreeGuard":{'}
  guard_body=${guard_body%%\}*}
  case "$guard_body" in
    *'"enabled":true'*) ;;
    *) return 0 ;;
  esac

  # Only the primary worktree is guarded. In the primary worktree
  # --git-dir and --git-common-dir refer to the same directory (both
  # print ".git", or the same absolute path); in a linked worktree
  # --git-dir points at ".../worktrees/<name>" while --git-common-dir
  # still points at the shared repository -- confirmed locally. Sibling
  # worktrees are exactly where implementation branches are supposed to
  # live, so this is equivalent to the old primary-vs-repo_root check.
  [ "$git_dir" = "$git_common_dir" ] || return 0

  # Only implementation branches are guarded. The globs come from
  # worktreeGuard.branchPatterns, defaulting to issue/* and
  # roadmap-audit/* when the key is absent. (A detached HEAD, or an
  # unborn HEAD, reports "HEAD" here and never matches.)
  [ -n "$branch" ] && [ "$branch" != "HEAD" ] || return 0

  patterns='issue/* roadmap-audit/*'
  case "$guard_body" in
    *'"branchPatterns":['*)
      raw=${guard_body#*'"branchPatterns":['}
      raw=${raw%%]*}
      patterns=$(printf '%s' "$raw" | tr ',' ' ' | tr -d '"')
      ;;
  esac

  matched=0
  for pattern in $patterns; do
    # Unquoted $pattern is intentional: it enables glob matching of the
    # configured branch pattern against the branch name.
    # shellcheck disable=SC2254
    case "$branch" in
      $pattern) matched=1; break ;;
    esac
  done
  [ "$matched" = 1 ] || return 0

  printf 'IDD worktree guard: refusing to %s on "%s" from the primary worktree (%s).\n' \
    "$action" "$branch" "$repo_root" >&2
  printf 'B1 requires implementation branches to live in a sibling worktree, not the primary worktree.\n' >&2
  printf 'Create one, e.g.:  git worktree add ../<repo>.%s %s\n' \
    "$(printf '%s' "$branch" | tr '/' '-')" "$branch" >&2
  printf 'See B1 in .github/instructions/idd-work.instructions.md.\n' >&2
  printf '(To bypass intentionally, re-run the git command with --no-verify.)\n' >&2
  return 1
}
