# Getting Started with IDD

Use this guide when you want the shortest safe path from deciding a
repository should adopt IDD to the first Issue-Driven Development loop.
It is procedural on purpose. Deeper rules stay in the workflow and
phase reference files.

## Before You Start

Choose the repository that will adopt IDD and confirm who is allowed to
grant agent credentials, review pull requests, and merge. Review
`docs/permissions.md` before giving an unattended or merge-capable agent
access to GitHub.

The agent that imports or runs IDD needs access to:

- `git`
- an authenticated `gh` CLI or equivalent GitHub integration
- `jq`
- Node.js/npm with `npx` (optional; only required if the project's
  validate commands use `npx`. Non-Node.js projects should set validate
  commands to their project tooling or to `true` as a no-op — see
  [Tooling boundary](customization.md#tooling-boundary))
- a REST client such as `curl` for reliable operational marker posting

## 1. Import the Template

Open an agent session in the target repository and ask it to import the
IDD template from the idd-skill source repository. If the template has
already been copied, start from the local `ONBOARDING.md` file instead.

The onboarding guide copies the portable instruction files, asks for
project-specific command values, and updates agent entry files such as
`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, or Copilot instructions.

### Validate the import with IDD doctor (optional)

After importing IDD, run the doctor script once in a repository that
has the helper installed to catch common setup drift:

```sh
node scripts/idd-doctor.mjs
```

The report checks core IDD file presence, unresolved placeholders,
marker-prefix consistency, command-table sanity, and (when `gh` access
is available) branch-protection and required-check signals.

## 2. Choose the Review Policy

Before the first full loop, decide whether the default Copilot advisory
review policy applies. If it does not, choose another profile from
`docs/idd-review-policy-profiles.md`, apply the matching
`profiles/<profile>/README.md` artifact, and capture its verification
evidence before agents reach PR review and merge phases.

Keep this decision explicit. Review policy changes are workflow changes,
not just documentation preferences.

### Merge policy

Before unattended runs begin, choose and record a merge policy with
`fully_autonomous_merge` preselected as the distributed default, and ask
whether the operator wants an explicit opt-out to `human_merge` or
prefers `separate_merge_agent` as a non-default split-authority profile.
Keep the selected policy in repository documentation that future IDD
sessions read. Missing policy defaults to `fully_autonomous_merge`;
unknown recorded policy values must stop with a maintainer hold until
corrected.

## 3. Prepare Issues

IDD works from GitHub Issues. At least one issue should be ready before
the loop starts:

- limited enough for one reviewable change
- verifiable with lint, tests, CI, or another explicit check
- autonomous, with no unresolved human decision or external blocker

For broad requests, use the optional issue-authoring companion to draft
a roadmap and focused child issues before starting the execution loop.
Use task-list links to group active roadmap work. Reserve
`idd-skill-blocked-by` markers for true sequential dependencies on a
separate roadmap.

When a project has genuine parallel tracks or multi-session coordination
boundaries, nested roadmap hierarchies let each track close
independently before the parent roadmap closes. See
[Recursive Roadmap Hierarchies](idd-workflow.md#recursive-roadmap-hierarchies)
in the workflow guide for structure examples, the grouping-versus-dependency
distinction, and how discovery and bottom-up audit behave across levels.

## 4. Start the Loop

Ask the agent to start the IDD workflow in the target repository. The
agent should read the repository entry file, then route through
`docs/idd-workflow.md` and the phase files under `.github/instructions/`.

The normal loop is:

1. Discover a ready roadmap or orphan issue.
2. Claim exactly one issue with an ownership marker.
3. Create a branch and worktree.
4. Implement, validate, and self-review.
5. Open a pull request.
6. Triage review feedback and fix accepted items.
7. Recheck CI, review freshness, advisory state, and claim ownership.
8. Merge with a merge commit and clean up stale operational markers.

## 5. Know Where to Go Next

Use the repository's broader docs index as the high-level map when one
exists. Use `docs/idd-workflow.md` when an agent or maintainer needs
phase routing details, and use `.github/instructions/*.instructions.md`
as the authoritative execution rules.

Keep the README short. It should help a first-time reader understand
what IDD is, why it exists, and which guide to read next.
