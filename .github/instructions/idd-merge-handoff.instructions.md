# IDD — Merge Policy Handoff Phase (F2.5)

Read this file after `idd-pre-merge.instructions.md` (F2) satisfies all
pre-merge conditions. It decides whether the current session can proceed
to merge execution or must stop and hand off.

Before any mutating action in this phase, apply the claim revalidation
gate. If an active claim exists, it must still use your current
`{claim-id}`. If no active claim exists, continue only for the
designated `separate_merge_agent` actor path or the
`fully_autonomous_merge` policy path (see Step 1); all other paths must
stop and report.

## F2.5 — Resolve merge policy route

1. Confirm claim ownership context:
   - If an **active claim** exists, it must still use your current
     `{claim-id}`. If it is held by a different `{claim-id}` (even under
     the same agent ID), the claim was lost — report this and stop.
   - If no active claim exists, continue only for the designated
     `separate_merge_agent` actor path in step 5, or the
     `fully_autonomous_merge` policy path in step 6. Other paths must
     stop.
2. Read the repository's recorded merge policy from repository
   documentation that future IDD sessions read. If no policy is
   recorded, treat it as `fully_autonomous_merge` (distributed default).
3. If the recorded value is not one of `fully_autonomous_merge`,
   `human_merge`, or `separate_merge_agent`, treat it as an unknown merge
   policy: stop, post a hold comment, and request maintainer decision.
4. If the recorded policy is `human_merge`, stop before the final
   freshness fetch and before `gh pr merge`. After claim revalidation,
   post a concise handoff summary comment that includes:
   - PR number and branch
   - full F2 snapshot (`{f2-head-SHA}`, `{f2-max-activity-updatedAt}`,
     `{f2-total-item-count}`, `{f2-latest-ci-completed-at|none}`)
   - the F2 readiness evidence
   - unresolved-thread count, advisory state, and CI state
   - active `{claim-id}`
   - merge command candidate:

   ```sh
   gh pr merge {pr-number} --merge --match-head-commit "{f2-head-SHA}"
   ```

   For `human_merge`, hand off to the human maintainer.
5. If the recorded policy is `separate_merge_agent`, apply this split:
   - If repository documentation explicitly records that the **current
     session** is the designated merge-capable actor and the documented
     resume condition is satisfied:
     1. If this session does not yet hold a verified active `{claim-id}`,
        establish ownership through `idd-claim.instructions.md` A5 and
        then return to this handoff phase.
     2. If this session has not yet recorded F2 evidence for the current
        `{claim-id}`, do not reuse worker-side handoff context. Return
        to `idd-pre-merge.instructions.md` and run F2 once to record a
        fresh snapshot for this merge-capable session, then return here.
     3. If this session already has fresh F2 evidence for the current
        `{claim-id}`, continue directly to `idd-merge.instructions.md`.
   - Otherwise:
     - If the merge-capable actor or resume condition is not recorded,
       post a hold comment and stop (do not release the worker claim).
     - If a different merge-capable actor is recorded, post a handoff
       summary comment using the same required fields listed in step 4,
       then release the worker claim with `unclaimed-by` using the
       current `{claim-id}` and stop. If the claim was already lost, do
       not post release.
6. When the policy is `fully_autonomous_merge`, continue directly to
   `idd-merge.instructions.md`.
