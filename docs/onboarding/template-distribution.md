# Template Distribution Maintainer Reference

Use this page when maintaining the file distribution surface for
`idd-template/ONBOARDING.md`. The onboarding entry point remains the
operator-facing import path; this page explains how the file list and
fetch examples stay correct when the template gains, removes, or moves
files.

This is primarily a maintainer reference for the `idd-skill` source
repository. Adopters who receive it with the copied template can treat it
as background unless they intentionally customize their local template
distribution lists.

## Distribution surfaces

The template has three distribution surfaces:

1. **Core template files** copied from `idd-template/` into the adopter
   repository. These include `.github/idd/`, `.github/instructions/`,
   `docs/`, and `profiles/`.
2. **Optional issue-authoring companion files** copied from
   `skills/issue-authoring/` only when the operator explicitly opts into
   pre-execution issue drafting.
3. **Local-copy installs** where an agent copies the full
   `idd-template/` directory from a cloned `idd-skill` checkout instead
   of fetching individual files.

`idd-template/ONBOARDING.md` keeps the executable import snippets for
the first two surfaces so a raw-URL onboarding run can still complete
without opening this reference first.

## Generated file lists

The authoritative generated lists are configured in
`audit/sync-manifest.json`:

- `generatedBlocks[].id == "idd-template-core-files"` owns the core
  template file list.
- `generatedBlocks[].id == "issue-authoring-companion-files"` owns the
  optional issue-authoring companion list.
- `shellFileLists` ties each generated list to the `gh api` and `curl`
  loops in `idd-template/ONBOARDING.md`.

When adding a core template file, update both `sourceGlobs` and `paths`
for `idd-template-core-files` when the new path is not already covered.
The docs audit compares those entries with the repository files and
fails if the generated block or shell loops are stale.

When adding an optional issue-authoring companion file, update the
`issue-authoring-companion-files` block instead. Do not put optional
companion files in the core template list unless the execution loop
requires every adopter to receive them.

## Remote fetch examples

The `gh api` and `curl` loops in `idd-template/ONBOARDING.md` intentionally
list every file instead of fetching directories. This keeps raw-content
imports deterministic and makes missing files visible during onboarding.

For a new core file, ensure that both loops include the path after the
generated list is updated. The audit checks the shell lists against the
same generated block, so a path that appears in one loop but not the
other is treated as stale documentation.

For nested documentation such as `docs/onboarding/*.md`, the existing
loop body creates parent directories with `mkdir -p "$(dirname
"${DEST}/${FILE}")"`. No extra top-level `mkdir -p` entry is required
for each nested docs directory.

## Local-copy installs

The local-copy path is intentionally broader than the remote-fetch path:
copy the contents of `idd-template/` while preserving relative paths.
That means new core files under `idd-template/` are automatically covered
by local-copy installs after they are committed.

Keep the local-copy prose in `idd-template/ONBOARDING.md` short. Use this
reference for maintenance details and the generated remote-fetch snippets
for exact file coverage.

## Maintenance checklist

Before merging a distribution-surface change, verify:

- `audit/sync-manifest.json` includes every required new core file.
- the generated core file block in `idd-template/ONBOARDING.md` includes
  the new path.
- the `gh api` and `curl` loops in `idd-template/ONBOARDING.md` include
  the same path.
- optional issue-authoring files remain in the optional companion list.
- `idd-template/README.md` mentions the new reference page when it is
  part of the exported template documentation set.
- `node scripts/audit-docs.mjs --check` passes.
