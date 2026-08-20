# IDD Documentation Index

Use this page as the entry point to this documentation bundle. If you
are an agent working in this repository for the first time, start with
[Getting started](getting-started.md) or [Core concepts](concepts.md);
otherwise use the table below to find a page by topic.

Upstream (`kurone-kito/idd-skill`) generates this table from an OKF
(Open Knowledge Format) frontmatter block on each page. This
repository's own `docs/` bundle does not carry that frontmatter — it
was intentionally stripped from imported pages to match this
repository's existing plain-`# Heading`-only convention (no local
`docs-bundle-frontmatter` checker is configured) — so this table is a
plain, hand-maintained index instead of a generated one.

## Reference Map

The table below is maintained by hand in this repository. The
`audit:generated` marker around it is retained only as an
import/template-drift aid for future pin bumps (it lets a diff against
upstream's generated version locate the matching block quickly) — no
local tooling in this repository actually regenerates this table from
it.

<!-- audit:generated id=idd-template-docs-index-okf-table -->

<!-- dprint-ignore-start -->
| Type | Page | Description |
| ---- | ---- | ----------- |
| guide | [Customizing IDD](customization.md) | Lists which IDD surfaces adopters can safely customize and points to the authoritative file for each policy. |
| guide | [Getting Started with IDD](getting-started.md) | Walks a new adopter through the shortest safe path from deciding to adopt IDD to running the first Issue-Driven Development loop. |
| guide | [IDD Review Policy Profiles](idd-review-policy-profiles.md) | Names the supported PR review policy profiles and the instruction files an adopter must edit to select one other than the Copilot-advisory default. |
| guide | [Permissions and Threat Model](permissions.md) | Defines the credential profiles, merge-policy boundaries, and threat model an operator must choose before granting IDD agents GitHub access. |
| concept | [Core IDD Concepts](concepts.md) | Introduces the loop-engineering vocabulary and mental model behind the IDD phase instructions before diving into phase-by-phase rules. |
| reference | [IDD — Advisory-Wait Shell Fallback (AW1 / AW2 / AW3-R / AW3-S / AW3-H / F2 detail)](idd-advisory-wait-shell-fallback.md) | Provides the verbatim gh, gh api, jq, and curl commands the advisory-wait and F2 advisory-convergence shell fallbacks use when helper support cannot be trusted. |
| reference | [IDD Autonomy Contract](idd-autonomy-contract.md) | Classifies every externally visible IDD mutation as reversible or irreversible and names the gate or undo path for each. |
| reference | [IDD Comment Minimization](idd-comment-minimization.md) | Defines the live status digest contract and the safe procedure for minimizing completed review feedback and stale operational markers after merge. |
| reference | [IDD — Concept Ownership Matrix](idd-concept-ownership.md) | Answers which actor may touch a given IDD concept at a given phase without re-reading every instruction file. |
| reference | [IDD Resume — Detail Reference](idd-resume-detail.md) | Provides the full narrative detail behind idd-resume.instructions.md's compact routing tables for branches that need careful judgment. |
| reference | [Onboarding Reference — Agent Entry and Verification](onboarding/agent-entry-and-verification.md) | Provides the detailed agent-entry examples and verification checklist referenced by ONBOARDING.md steps 5 and 6. |
| reference | [Onboarding Reference — Issue-Mediated Bootstrap](onboarding/issue-mediated-bootstrap.md) | Documents an opt-in alternate bootstrap path that imports the IDD template through a reviewed issue-branch-PR cycle instead of theirs-flow's direct, unreviewed commit. |
| reference | [Onboarding Reference — Placeholder Values](onboarding/placeholders.md) | Provides the full derivation and replacement rules for every template placeholder used during onboarding. |
| reference | [Onboarding Reference — Policy Decisions](onboarding/policy-decisions.md) | Provides the detailed policy-decision guidance behind ONBOARDING.md's operator-confirmation steps. |
| reference | [Template Distribution Maintainer Reference](onboarding/template-distribution.md) | Explains how the template's generated file-distribution lists in ONBOARDING.md stay correct as files are added, removed, or moved. |
| reference | [IDD Policy Constants](policy-constants.md) | Inventories the distributed IDD policy defaults and names which configuration surface owns each one. |
| reference | [IDD Detailed Reference](reference.md) | Maps each operational question to the authoritative phase file or policy page that answers it. |
| workflow | [IDD workflow guide](idd-workflow.md) | Routes each agent to its entry file and the phase file matching its current state. |
| design | [IDD — Design Rationale and Maintainer Notes](idd-design-rationale.md) | Collects maintainer-facing rationale for why IDD phase rules exist as they do, organized by phase file. |
| design | [IDD Helper Script Evaluation](idd-helper-scripts.md) | Records the current adoption decision and trade-offs for IDD's optional helper scripts so future reviews do not re-evaluate them from scratch. |
<!-- dprint-ignore-end -->

<!-- /audit:generated -->
