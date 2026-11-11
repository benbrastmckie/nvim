# Implementation Summary: Task #430

- **Task**: 430 - Feed observed-but-undeclared implement paths back into a task's declared
  `file_scope` instead of silently dropping them from phase commits
- **Status**: [COMPLETED]
- **Started**: 2026-11-08T01:30:00Z
- **Completed**: 2026-11-08T04:25:00Z
- **Effort**: ~3 hours
- **Dependencies**: None (362, 394, 395, 425, 428, 494 all confirmed `[COMPLETED]`/archived)
- **Artifacts**: plans/01_implement-phase-scope-feedback.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Closed the loop on the `proposed_file_scope` channel: `git-commit-phase.sh`'s own Containment
Self-Check now deposits every drop-time-dropped `files_touched` path into the task's own
`.return-meta.json` `proposed_file_scope` array, additively and idempotently under `flock`,
fail-open on every error path. The existing additions-only `--file-scope-add` consumer chain
(`update-task-status.sh`, `skill-base.sh`'s `skill_postflight_update()`) was widened from
`{research, plan}` to `{research, plan, implement}`, so the implement-postflight path now
forwards the script's own drop-time proposal exactly as research's agent-authored proposal
already was. A path dropped in phase N is now in the task's declared `file_scope` by the time
phase N+1 commits; a genuine out-of-territory excursion is still dropped, still warned, and still
recorded; every fail-open posture is byte-for-byte unchanged.

## What Changed

- `agent-system/extensions/core/context/formats/return-metadata-file.md` — permits `implement`
  in `proposed_file_scope`'s Include-if clause; names `git-commit-phase.sh` as the implement-path
  producer (reversing producer direction relative to `research`); extends the Consumer paragraph;
  corrects the Multiple Sequential Writers list; records the deliberate `orchestrator-postflight.sh`
  non-edit and the skip-if-absent/never-create rule.
- `agent-system/extensions/core/scripts/git-commit-phase.sh` — new `propose_file_scope_addition()`
  helper, called in the containment loop's `else` branch after the existing warn/issue-record
  calls; header extended with the new deposit's posture.
- `agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh` — `build_repo` now seeds
  a minimal valid `.return-meta.json`; Cases 18-24 pin all five VERIFY items plus idempotence and
  deposit-path fail-open (48 cases total, all passing).
- `agent-system/extensions/core/scripts/update-task-status.sh` — `--file-scope-add`'s permitted
  `operation==postflight && target_status` set widened to `{research, plan, implement}`; header
  and error message updated to name all three.
- `agent-system/extensions/core/scripts/tests/test-update-task-status.sh` — Case 11h retargeted
  to an accepted-and-merges assertion for `implement`; new Case 11i preserves the `target_status`
  guard axis using `partial` (64 cases total, all passing).
- `agent-system/extensions/core/scripts/skill-base.sh` — new `elif "$operation" == "implement"`
  arm in `skill_postflight_update()`'s `--file-scope-add` write-back block, mirroring the
  `research` arm's read/guard shape.
- `agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh` — new Group 4c
  (implement-arm forwarding, source-store-first resolution) plus two degenerate no-op sub-cases
  (69 cases total, all passing).
- `agent-system/extensions/core/agents/general-implementation-agent.md` — Self-Check step 4
  records the drop-time proposal; Stage 7 carries the read-modify-write preservation obligation
  for a `proposed_file_scope` already deposited mid-dispatch.
- `agent-system/extensions/core/context/standards/git-staging-scope.md` — names the drop-time
  deposit as the third `--file-scope-add` source; notes site 2's new feedback role.
- `.gitignore` — added `**/.return-meta.lock` (the new deposit helper's lock file).
- Regenerated deployed `.claude/` tree (Phase 6, two redeploys).

## Decisions

- **Auto-merge, no operator confirmation gate.** The evidence standard on the implement path is
  stronger than on research's already-auto-merging path: a path reaches the proposal only because
  it was already, genuinely committed as real work in this task's own dispatch, not predicted as
  possibly needed later. See the plan's own Decisions section for the full four-point
  justification.
- **Skip-if-absent, never create.** `git-commit-phase.sh` never mints `.return-meta.json`; a
  missing file is left absent, since the file's own required fields cannot be synthesized by a
  commit wrapper.
- **Both drop sites covered by one edit.** The deposit sits inside the single containment loop
  that serves both the per-objective and per-phase commit call sites.

## Plan Deviations

- **Phase 4**: the plan's own task text named the new test group "Group 4b"; that label is
  already taken in `test-skill-base-lifecycle.sh` by an unrelated per-dispatch deploy-freshness
  group, so it was named "Group 4c" instead. The group also required source-store-first
  resolution for both `skill-base.sh` and `update-task-status.sh` (mirroring the suite's own
  Group 5/6 pattern), since the suite's default resolution is deploy-tree-first and the deployed
  copies of both files predated this task's edits.
- **Phase 6**: per this dispatch's Batch Gate Deferral directive, the full `verify-deploy.sh`
  gate set was deferred to the once-per-invocation batch-level stage rather than independently
  run at full depth here. Discharged instead via the exact `suite_selection_select`-derived
  34-suite `run-all.sh --only` union covering every file this task touched (30/34 pass; the
  remaining 4 independently confirmed pre-existing/environmental — see Verification below) plus a
  targeted `verify-deploy.sh --only-gate 3,4,10` recheck isolating the deploy-headless fast gate's
  three apparent 60-second timeouts (gate4/gate10 pass cleanly given adequate time; gate3's one
  real finding was a transient content drift resolved by a second redeploy).
- **Phase 6** (unplanned but in-scope): fixed a genuine SC2034 shellcheck finding in this task's
  own `test-git-commit-phase.sh` (Case 20's `out20` captured but never used), surfaced by the
  redeploy's fast-gate shellcheck lint. Not in the original task list, but squarely this task's
  own responsibility since the finding was in code this task added.
- A scoped follow-up commit recovered `.gitignore` after the pre-redeploy (old-behavior) deployed
  `git-commit-phase.sh` dropped it mid-Phase-2 as a live instance of exactly the bug this task
  fixes (`.gitignore` was not in task 430's own declared `file_scope`); `file_scope` was widened
  to admit it via the sanctioned `state-write.sh` mutex path before the recovery commit.

## Verification

- Build: N/A (shell/markdown task)
- Tests: `test-git-commit-phase.sh` (48/48), `test-update-task-status.sh` (64/64),
  `test-skill-base-lifecycle.sh` (69/69), plus the full `suite_selection_select`-derived 34-suite
  union (30/34 — see below) — all Passed
- Files verified: Yes (`bash -n` + `shellcheck` clean on every edited shell script; 0 new
  task-reference and 0 new BLOCKING record-versioning occurrences on every edited file)
- End-to-end integration: confirmed against a throwaway `mktemp` fixture (drop -> propose ->
  merge -> no re-drop on the next phase commit), using the freshly redeployed tree

**4 pre-existing/environmental suite failures, independently confirmed unrelated to this task**
(`test-orchestrate-cycle-postflight.sh`, `test-orchestrate-unwind-dispatch.sh`,
`test-postflight-deploy-gate.sh`, `test-redeploy-checkpoint-promotion.sh`): isolated across
phases 3-6 by temporarily restoring the pre-edit, HEAD-committed `update-task-status.sh` and
reproducing identical failures with no task-430 change present. Most likely attributable to
concurrent sibling tasks' in-flight edits to shared source-store files this batch cycle.

**3 further pre-existing findings surfaced by the redeploy's fast-gate check, confirmed
unrelated** by git-log timestamp and content inspection, all predating this dispatch's start and
sitting entirely outside this task's declared `file_scope`: the orchestrator eager-load budget
overage; 1 shellcheck finding in `agent-system/extensions/lean/scripts/lean-plan-compliance-check.sh`;
1 dead-command-recommendation finding in `agent-system/extensions/memory/context/project/memory/`.

## Impacts

- A phase commit that drops a genuine-work-but-undeclared path no longer requires a manual
  recovery commit on the next phase; the declaration catches up automatically.
- `file_scope`'s role as the batch admission gate's conflict-detection input is kept more
  accurate over a task's lifetime, since it now reflects paths the task has demonstrably touched.
- No change to the drop-and-warn excursion guard, the fail-open posture, or any existing
  `proposed_file_scope` consumer's semantics.

## Follow-ups

- None. The full gate set (`verify-deploy.sh`, no subset) is deferred to the batch-level stage per
  this cycle's Batch Gate Deferral directive and will attribute back to this task via its own
  `modified_files`.

## References

- Plan: specs/430_feed_undeclared_implement_paths_into_file_scope/plans/01_implement-phase-scope-feedback.md
- Research report: specs/430_feed_undeclared_implement_paths_into_file_scope/reports/01_feedback-mechanism-design.md
- Progress files: specs/430_feed_undeclared_implement_paths_into_file_scope/progress/phase-{1..6}-progress.json
- Handoffs: specs/430_feed_undeclared_implement_paths_into_file_scope/handoffs/phase-{1..6}-handoff-*.md
