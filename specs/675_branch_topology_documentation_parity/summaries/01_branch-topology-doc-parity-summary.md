# Implementation Summary: Task #675

- **Task**: 675 - Rewrite the branch-strategy documentation to state the implemented integration-branch contract
- **Status**: [COMPLETED]
- **Started**: 2026-11-23T17:15:00Z
- **Completed**: 2026-11-23T18:50:00Z
- **Effort**: ~1.5 hours, four phases
- **Dependencies**: None blocking. `per_task_attribution_squash_landing` (completed) supplied the third ruling record this task documents; `two_root_classification_of_remaining_consumers` and `batch_worktree_cleanup_retention_orphan_report` are held and were deliberately not waited on.
- **Artifacts**: plans/01_branch-topology-doc-parity.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Rewrote the branch-strategy documentation to state the implemented, isolation-off integration-
branch contract rather than the original un-amended ruling: the primary tree stays on the
declared integration branch and is never switched; landing is a verification
(`task-landing-verify.sh`) run strictly before the completion status write, not a squash onto a
milestone ref; `milestone-ref-land.sh` is retired as a landing mechanism; and worktree isolation
at batch granularity is declared but not yet built, distinct from the per-dispatch isolation
question that stays a settled non-goal. Four files were rewritten or corrected; two files
verified as already current were confirmed, not edited; one file was re-verified and confirmed to
need no edit at all, per the task's own sweep instruction.

## What Changed

- `agent-system/extensions/core/context/standards/git-workflow-narrative.md` — Branch Strategy
  section (all five subsections) rewritten to the implemented contract: the two live admission
  refusals (`off_integration_branch`, `dirty_primary_tree`) and their exact arming condition;
  landing as a verification, not ref plumbing, with `milestone-ref-land.sh` named retired;
  the reviewable-unit ruling for merge strategy; the live `milestone-review-handoff.sh` behavior;
  and the worktree-isolation subsection split into the settled per-dispatch non-goal and the
  declared-but-unimplemented batch mode, naming the five held successor tasks by slug. Line count
  297 -> 324.
- `agent-system/extensions/core/rules/git-workflow.md` — new point-of-use `## Branch` section
  (additive; no branch rule existed before), stating which branch a commit lands on and the two
  admission refusals in one clause, pointing at the narrative and the declarations schema for
  detail.
- `agent-system/extensions/core/context/contracts/conclusion-stage.md` — milestone push/review
  handoff paragraph corrected: `milestone-review-handoff.sh` resolves the integration branch and
  reads landing proofs, records `review.ref` as `refs/heads/<integration branch>`, not a
  `refs/heads/milestone/<id>` ref landed by the now-retired `milestone-ref-land.sh`. Line count
  540 -> 542.
- `agent-system/extensions/core/context/standards/shared-worktree-discipline.md` — opening
  sentence split into two claims: per-dispatch/per-agent worktree isolation remains a settled
  non-goal (unaffected); batch-granularity isolation is a separate, declared-but-unimplemented
  mode, naming the held successors. The "Detached worktree" section's appeal to "the settled
  per-dispatch worktree-isolation question above" was re-checked and still reads correctly; no
  change was needed there. Line count 61 -> 67.
- `agent-system/extensions/core/index-entries.json` — `line_count` regenerated for all three
  edited `context/**` files across three editing phases.
- `agent-system/extensions/core/context/config/orchestrator-context-budget.json` — unplanned,
  outside the originally declared `file_scope`: a reviewed, dated Gate 20 eager-load baseline
  move (71,600 -> 71,800 B), required because the new `rules/git-workflow.md` Branch section (a
  necessary, non-duplicative new rule) pushed the measured eager-load total over the previously
  recorded baseline even after two compaction passes. See "Plan Deviations".

## Decisions

- Left `context/patterns/ref-plumbing-landing.md` and `context/standards/repo-level-declarations.md`
  untouched. Both were independently re-confirmed against the live scripts in Phase 4 (not just
  against the research report): `ref-plumbing-landing.md`'s "The Landing Mechanism" section
  already states the implemented contract and its concurrency-safety argument is intact;
  `repo-level-declarations.md`'s `integration_branch`/`worktree_isolation` sections already match
  the live predicate order, stop reasons, and fail-open table exactly.
- Did not edit `context/standards/git-staging-scope.md`. Re-verified the sweep's negative finding
  directly (grep for `cherry-pick|squash|milestone|landing|integration branch|per-dispatch
  working-tree isolation`): five hits, all non-stale — one scored-but-unadopted remedy mention
  (per-dispatch working-tree isolation, unaffected by either amendment), three "landing"/"original
  landing" mentions about the unrelated Phase-Commit Containment Self-Check's path-widening
  history, and one "cherry-pick" in the generic in-progress-merge-state detection list for
  `commit-source-store-path.sh`. No stale branch/worktree-topology claim found; no edit made.
- Did not name task 685 (`stack_pr_submission_from_integration_branch`, status `planned`,
  building the review-branch-cutting step) anywhere in the rewrite. It is not a held task and the
  plan's task list does not require citing it; the review-ref mechanism is described generically
  with a pointer to `ref-plumbing-landing.md`'s "The Landing Mechanism" section instead.
- Retitled two subsections of `git-workflow-narrative.md`'s Branch Strategy to match their
  rewritten content ("Milestone Review History..." -> "Landing Is a Verification..."; "Worktree
  Isolation: Not Reinstated" -> "Worktree Isolation: Declared But Not Yet Built at Batch
  Granularity"). Both are content-accuracy fixes, not record-versioning language.

## Plan Deviations

- **Phase 4, task 5 ("Redeploy the source store")** altered: the first `deploy-headless.sh` run
  landed but failed verification (`landed_verify_red`) on Gate 20, the orchestrator eager-context-
  budget lock. Phase 2's new `rules/git-workflow.md` Branch section, though required by the plan,
  pushed the measured eager-load total 311 B over the recorded baseline. Two compaction passes on
  the new section's own wording recovered 152 B (down to a 160 B residual), and the remainder was
  closed by a reviewed, dated baseline move in
  `agent-system/extensions/core/context/config/orchestrator-context-budget.json`
  (71,600 -> 71,800 B), following that file's own extensively-documented convention for necessary,
  non-duplicative new rule content (recorded as a new dated entry in the file's own `note` field).
  The second `deploy-headless.sh` run landed clean (41 checks, 0 failures). This edit was outside
  the task's originally declared `file_scope`; it is a coupled config surface for the eager rule
  file this task was required to edit, in the same spirit as the already-anticipated
  `index-entries.json` coupling.

## Verification

- Build: N/A (documentation-only task)
- Tests: Passed — `verify-touched.sh` run per phase (Phase 1: 7/7 selected suites pass; Phase 2:
  4/4; Phase 3: 10 selected + 98 OWED-fallback suites, 108/108 pass; Phase 4 whole-task sweep:
  113/113 pass across all six touched paths). `verify-deploy.sh --skip-unchanged --only-gate 3,4`
  (doc-lint, task-reference-lint): 3/3 checks pass on the redeployed tree. `deploy-headless.sh`:
  landed and verified clean on the second attempt. `generate-context-line-counts.sh --check`:
  608/608 exact, zero drift.
- Files verified: Yes

## Impacts

- A reader of either `rules/git-workflow.md` or `git-workflow-narrative.md`'s Branch Strategy
  section can now name the branch their work lands on, the two admission refusals and their
  exact arming condition, and distinguish built landing-verification machinery from the
  declared-but-unimplemented batch-worktree mode, with every stated constant grep-verifiable
  against a live script.
- `conclusion-stage.md` and `shared-worktree-discipline.md` no longer describe retired or
  ambiguously-scoped machinery as live.
- The repository's Gate 20 eager-context-budget baseline moved from 71,600 B to 71,800 B, a
  small, reviewed, dated increase consistent with the file's own established pattern; no other
  ceiling moved.

## Follow-ups

- None. The task's own non-goals (re-arguing the three ruling records; documenting the
  batch-worktree contract as live; editing `git-staging-scope.md`; rewriting the two
  already-current pages; building or un-holding any held successor task) were honored throughout.

## References

- Plan: `specs/675_branch_topology_documentation_parity/plans/01_branch-topology-doc-parity.md`
- Research report: `specs/675_branch_topology_documentation_parity/reports/01_branch-topology-doc-parity.md`
- Ruling records: `specs/decisions/branch-topology-and-landing-strategy.md`,
  `specs/decisions/batch-worktree-isolation-and-task-squash-landing.md`,
  `specs/decisions/isolation-off-landing-verification-and-review-time-squash.md`
