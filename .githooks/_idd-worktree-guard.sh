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

  repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || return 0
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

  # Only the primary worktree is guarded. The primary worktree is the
  # first entry reported by `git worktree list`; sibling worktrees are
  # exactly where implementation branches are supposed to live.
  primary=$(git worktree list --porcelain 2>/dev/null | sed -n 's/^worktree //p' | head -n 1)
  [ -n "$primary" ] || return 0
  [ "$primary" = "$repo_root" ] || return 0

  # Only implementation branches are guarded. The globs come from
  # worktreeGuard.branchPatterns, defaulting to issue/* and
  # roadmap-audit/* when the key is absent. (A detached HEAD reports
  # "HEAD" and never matches.)
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
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
