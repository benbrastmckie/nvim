# Implementation Summary: Task #657

- **Task**: 657 - Branch-topology ruling, then milestone automation and review gates
- **Status**: [COMPLETED]
- **Started**: 2026-11-20T00:00:00Z
- **Completed**: 2026-11-20T04:00:00Z
- **Effort**: ~4 hours
- **Dependencies**: 654 (completed), 656 (completed)
- **Artifacts**: plans/01_branch-topology-milestone-automation.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

This task ruled on branch topology and landing strategy first (Element 1), then built milestone
automation and review gates on top of that ruling (Element 2). All 7 plan phases completed. The
ruling keeps the single-shared-working-tree posture, reinstates no form of worktree isolation,
and lands a milestone's review history via `git commit-tree` + compare-and-swap `git update-ref`
rather than `checkout`/`git merge --squash`. The milestone-completion push/review step prepares
(never pushes) through the existing `/please` + `/merge` consent-gated path.

## What Changed

- `specs/decisions/branch-topology-and-landing-strategy.md` — new decision record, rulings R1-R8.
- `specs/decisions/commit-layer-cluster-ordering.md` — dated amendment note recording the ruling's effect.
- `specs/state.json` / `specs/TODO.md` — 655 gains dependency 517; 655's description gained a ruling-landed revision block.
- `agent-system/extensions/core/scripts/milestone-ref-land.sh` — new: ref-plumbing milestone landing plus `--verify` mode.
- `agent-system/extensions/core/scripts/tests/test-milestone-ref-land.sh` — new: 7-case suite.
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` — landing + verify check before the completion status write, refuse-and-defer on failure.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` — 4 new cases (A/B/C landing refusal, success, pass-through).
- `agent-system/extensions/core/scripts/milestone-review-handoff.sh` — new: prepares the push/review request, never pushes.
- `agent-system/extensions/core/scripts/tests/test-milestone-review-handoff.sh` — new: 8-case suite.
- `agent-system/extensions/core/scripts/orchestrate-conclusion-roadmap.sh` — non-fatal handoff invocation after a successful regenerate.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-conclusion-roadmap.sh` — 2 new cases (wiring, non-fatal failure).
- `agent-system/extensions/core/context/standards/git-workflow-narrative.md` — Branch Strategy section replaced with the ruled contract.
- `agent-system/extensions/core/context/patterns/ref-plumbing-landing.md` — new pattern document.
- `agent-system/extensions/core/context/contracts/conclusion-stage.md` — Step 5 documents the handoff as a non-fatal companion.
- `agent-system/extensions/core/index-entries.json` / `agent-system/extensions/core/manifest.json` — registration for the new context file and scripts.
- `agent-system/extensions/core/scripts/tests/suite-classification.data` — two new suite rows.
- `specs/ROADMAP.md` — regenerated; 655's blocked token now includes 517.

## Decisions

- Worktree isolation is NOT reinstated (ruling R5); the binding-evidence mechanism is engaged by name in the decision record.
- The `657 -> 553` edge is deliberately NOT written; it was already resolved onto 655.
- Milestone review history is built by ref plumbing, never `checkout`/`git merge --squash`.
- The milestone-completion step prepares the push/review request; it never pushes or mints a grant.
- `orchestrate-conclusion-roadmap.sh`'s existing unconditional regenerate and `orchestrate-batch-gate.sh`'s existing complete-gate trigger are recorded as confirmations (R7), not rebuilt.

## Plan Deviations

- Phase 4's call-site edit and test extension were written alongside Phase 3's script for continuity, before Phase 4's own formal phase-closure bookkeeping ran. No functional deviation.
- `context/standards/git-integration.md` (Phase 6) was found to state no branch behavior at all; recorded as a finding rather than edited, per the plan's own Scope Hypothesis.
- A pre-existing test-methodology gap (not caused by this task) was found and fixed during Phase 5: `test-orchestrate-conclusion-roadmap.sh`'s deploy-tree-first SUT resolution was silently testing a stale deployed copy until a mid-task redeploy was run.

## Verification

- Build: N/A (shell scripts + markdown).
- Tests: `test-milestone-ref-land.sh` 7/7, `test-milestone-review-handoff.sh` 8/8, `test-orchestrate-cycle-postflight.sh` 350/350, `test-orchestrate-conclusion-roadmap.sh` 35/35. All passing against the deployed tree.
- `sync-manifest-scripts.sh --check`, `generate-context-line-counts.sh --check`, `check-extension-docs.sh`, `lint-unit-integration-boundary.sh`, `lint-shellcheck.sh`, `lint-state-writer-boundary.sh`, `check-task-references.sh`, `check-record-versioning.sh`: all pass (0 blocking) on every touched file.
- `deploy-headless.sh`: `RESULT=landed_verify_clean`.
- Files verified: Yes.

## Impacts

- Future `/orchestrate` completions of a milestone-batch task now land that task's work onto a milestone review ref before the completion status write, closing the postflight non-landing defect the reaffirmation record names.
- A milestone whose batches all complete now gets a prepared, never-autonomous push/review handoff.
- `branch_aware_orchestration_and_squash_landing` (655)'s description is revised to match the ruling and now depends on `stage_regenerated_derived_files_in_phase_commits` (517).

## Follow-ups

- `branch_aware_orchestration_and_squash_landing` (655) still owns the `repo-level-declarations.md` schema row for the `integration_branch` key and its admission-time assertion.
- A `test-lint-state-writer-boundary.sh` flake was observed once under the scoped batch-gate check and once more while redeploying; it passes in isolation (28/0) both times and is already a documented load-induced flake, not attributable to this task.

## References

- Plan: `specs/657_branch_topology_ruling_and_milestone_automation/plans/01_branch-topology-milestone-automation.md`
- Decision record: `specs/decisions/branch-topology-and-landing-strategy.md`
- Research report: `specs/657_branch_topology_ruling_and_milestone_automation/reports/01_branch-topology-milestone-automation.md`
