# Onboarding Reference — Placeholder Values

Use this reference with `idd-template/ONBOARDING.md` when you need the
full derivation and replacement rules for the template placeholders.

This page is the detailed companion for:

- Step 1A — auto-derive candidate values
- Step 1C — finalize placeholder values
- Step 4 — replace placeholders after copying template files

## Derived evidence to collect

Before asking the operator to type values manually, inspect the target
repository and propose candidate values for the placeholders below.

### `{{REPO_NAME}}`

Read the repository short name from the git remote or GitHub API. The
remote name is the most reliable source.

### `{{PROJECT_MARKER_PREFIX}}`

Start from the repository name, lowercase it, and normalize it into a
short hyphenated marker prefix. The final value must match:

```text
^[a-z][a-z0-9-]{1,31}$
```

That means 2-32 characters, lowercase, starting with a letter.

### `{{TRUSTED_MARKER_ACTOR}}`

List the GitHub logins allowed to post trusted IDD markers in
`.github/idd/config.json`. This placeholder is intentionally singular:
it fills one quoted JSON array entry, so replace it with a single
JSON-escaped login string first. Examples:

- one trusted marker actor → `"trusted-user-a"`

If the target repository needs more than one trusted marker actor, add
the extra quoted array entries manually after the first replacement, for
example:

- multiple trusted marker actors → `"trusted-user-a", "trusted-bot-a"`

Derive the candidate list from the people or bots allowed to post
trusted claim, release, watermark, baseline, and advisory markers for
the target repository. Keep the value aligned with any helper
invocations that pass `--trusted-marker-logins`.

### `{{INSTALL_DEPS_COMMAND}}`

Look for the target repository's dependency tooling and propose the
matching install command:

- declared `packageManager` metadata or exactly one supported lockfile
  (`pnpm-lock.yaml`, `package-lock.json`, or `yarn.lock`) →
  the matching package-manager install command
- bare `package.json` without those signals → do not infer
  `npm install` from that alone; use repository-specific docs or ask the
  operator to confirm the real install command
- `requirements.txt` → `pip install -r requirements.txt`
- `pyproject.toml` → use the repository's declared Python tool
  (for example `poetry install`, `pdm install`, `hatch env create`, or
  `uv sync`)
- `go.mod` → `go mod download`
- `Gemfile` → `bundle install`
- no standard dependency tooling → `true`

If both `pyproject.toml` and `requirements.txt` are present, confirm
which workflow should drive the IDD command rows.

### `{{FIX_VALIDATE_COMMANDS}}`

Propose an auto-fix plus validate sequence that matches the existing
tooling. Common patterns:

- Node.js with a relevant project script:
  `<pm> run lint:fix && <pm> run lint`
- Node.js without a relevant script but with `npx` available:
  `npx <linter> --fix && npx <linter>`
- Python: `black . && isort .` or equivalent
- Go: `go fmt ./...`
- Rust: `cargo fmt`
- no relevant auto-fix tooling: `true`

### `{{PRE_PUSH_VALIDATE_COMMANDS}}`

Propose a non-mutating lint/build/test sequence. Common patterns:

- Node.js with project scripts:
  `<pm> run lint && <pm> run build && <pm> run test`
- Node.js without a relevant script but with `npx` available:
  `npx <linter> && npx <builder> && npx <test-runner>`
- Python: `pylint . && python -m pytest`
- Go: `go vet ./... && go test ./...`
- Rust: `cargo check && cargo test`
- no relevant verification command: `true`

### `{{POST_FIX_VALIDATE_COMMANDS}}`

Usually a superset of `fix-validate` and `pre-push-validate`.

## Tooling boundary

IDD does not require Node.js or pnpm. Use the target repository's
existing tooling for every command row. Set a row to `true` only when no
relevant tool exists for that step.

For the full fallback order and policy matrix, see
[Tooling boundary](../customization.md#tooling-boundary).

## Final placeholder meanings

After Step 1A and Step 1C, you should have final values for these seven
placeholders:

| Placeholder                      | Meaning                                                   | Example                            |
| -------------------------------- | --------------------------------------------------------- | ---------------------------------- |
| `{{REPO_NAME}}`                  | Repository short name used in worktree examples           | `my-app`                           |
| `{{PROJECT_MARKER_PREFIX}}`      | Hidden issue-body marker prefix                           | `my-app`                           |
| `{{TRUSTED_MARKER_ACTOR}}`       | Single JSON-escaped login allowed to post trusted markers | `trusted-user-a`                   |
| `{{FIX_VALIDATE_COMMANDS}}`      | Auto-fix plus validate command row                        | `npm run lint:fix && npm run lint` |
| `{{PRE_PUSH_VALIDATE_COMMANDS}}` | Non-mutating verify command row                           | `npm run lint && npm run test`     |
| `{{POST_FIX_VALIDATE_COMMANDS}}` | Post-fix validate command row                             | `npm run lint:fix && npm test`     |
| `{{INSTALL_DEPS_COMMAND}}`       | Dependency install command, or `true` when unnecessary    | `npm install`                      |

### No-op substitution

Only the command placeholders may be set to `true` when a step does not
apply to the target project. For example:

- no dependency install step →
  `{{INSTALL_DEPS_COMMAND}} = true`
- no relevant auto-fix command →
  `{{FIX_VALIDATE_COMMANDS}} = true`

Keep `{{INSTALL_DEPS_COMMAND}}` safe to rerun across retries, takeovers,
and recreated worktrees.

## Marker prefix notes

`{{PROJECT_MARKER_PREFIX}}` appears in two hidden issue-body markers:

- roadmap identity marker:
  `<!-- {{PROJECT_MARKER_PREFIX}}-roadmap-id: {unique-id} -->`
- blocked-by marker:
  `<!-- {{PROJECT_MARKER_PREFIX}}-blocked-by: {roadmap-id} -->`

Validate a proposed prefix with:

```sh
printf '%s\n' "<prefix>" | grep -Eq '^[a-z][a-z0-9-]{1,31}$'
```

### Correct use of `blocked-by`

The `blocked-by` marker expresses a hard sequential dependency. Use it
only when an issue must wait for a referenced roadmap to close before
work can start.

Do **not** use it to group sub-tasks under an active roadmap. Tasks that
should proceed while the roadmap is still open belong in the roadmap's
task list as `- [ ] #NNN` entries.

## Replacement pass

After copying the template files into the target repository, replace the
seven placeholders above globally. Then verify that no `{{...}}` strings
remain in the copied files.
