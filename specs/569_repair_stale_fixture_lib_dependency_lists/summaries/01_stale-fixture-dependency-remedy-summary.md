# Implementation Summary: Task #569

- **Task**: 569 - Repair stale fixture lib dependency lists
- **Status**: [COMPLETED]
- **Started**: 2026-11-11T00:00:00Z
- **Completed**: 2026-11-11T01:45:00Z
- **Effort**: ~2 hours
- **Dependencies**: None
- **Artifacts**: plans/01_stale-fixture-dependency-remedy.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Three fixture-based test suites failed because their curated dependency-copy lists omitted
`lib/project-number-inuse.sh`, which `state-write.sh` unconditionally sources. Each suite's
fixture copy of `state-write.sh` aborted on the missing `source`, so every fixture `state.json`
write failed and surfaced as a generic exit-2 write failure. All three suites were repaired with
a minimal, additive dependency-list fix, the three now-stale `known-failures.txt` rows were
retired, and the deployed tree was regenerated and re-verified.

## What Changed

- `agent-system/extensions/core/scripts/tests/test-postflight-deploy-gate.sh` — appended
  `project-number-inuse.sh` to the `REQUIRED_LIBS` array (one line; drives both the existence
  check and the fixture copy loop).
- `agent-system/extensions/core/scripts/tests/test-redeploy-checkpoint-promotion.sh` — appended
  `project-number-inuse.sh` to the `REQUIRED_LIBS` array (one line, identical pattern).
- `agent-system/extensions/core/scripts/tests/test-orchestrate-predispatch-review.sh` — added a
  `require_file "$CORE_DIR/lib/project-number-inuse.sh"` pre-flight check (with an explanatory
  comment citing `state-write.sh`'s unconditional `source`, per this suite's existing
  comment-per-addition convention) and a matching `setup_sandbox()` copy line. This suite has no
  named dependency array, so it needed two edit sites rather than one.
- `agent-system/extensions/core/scripts/tests/known-failures.txt` — deleted the three now-stale
  `real-defect|...|needs-owner` rows, one per suite fixed above.
- A regenerated `.claude/` deploy tree (whole-tree claim, not a tracked deliverable).

## Decisions

- Did not build a runtime drift detector (`lint-test-fixture-dependency-drift.sh`) that would
  derive each fixture's copy list from the subject script's own `source` lines. The research
  report's corpus-wide re-derivation found zero drift beyond these three suites, so a runtime
  change replacing the arrays would touch 8+ otherwise-working suites to fix a defect that is not
  currently recurring elsewhere. A lint-time drift detector is the right-sized durable remedy and
  is recorded below as a follow-up candidate, not built in this task.
- `test-orchestrate-unwind-dispatch.sh` was left untouched. Its own `REQUIRED_LIB_SCRIPTS` array
  already carried `project-number-inuse.sh`; the research report's scope correction (three
  suites, not four) was re-confirmed in this dispatch and the plan excluded this suite from every
  phase's file list.
- Did not touch the audit-evidence gate in `state-write.sh` (a same-day, unrelated commit). That
  gate fires only on new `active_projects` entries; every affected fixture pre-seeds
  `active_projects` and transitions `status` only, so the gate is never reached.

## Plan Deviations

- **Task 4.6** altered: the plan's own verification step called for running gate 8 unscoped
  (`bash .claude/scripts/verify-deploy.sh --only-gate 8 <repo_root>`). This dispatch's own
  Batch Gate Deferral directive (this task is one of several `implement`-phase dispatches inside
  one multi-task `/orchestrate` batch invocation) supersedes that for this final, full-tier
  phase: the scoped `run-all.sh --only SUITE[,...]` narrowing was run instead, covering the three
  fixed suites plus Phase 1's own Tier-Justification covering set
  (`test-generate-task-order.sh`, `test-orchestrate-cycle-plan.sh`,
  `test-orchestrate-cycle-postflight.sh`, `test-skill-base-lifecycle.sh`) and
  `test-orchestrate-unwind-dispatch.sh`. Result: exit 0, 7 passed, 1 failed (1 expected — see
  Verification below), 0 NEW. An initial attempt to run the full, unscoped gate 8 battery
  directly was abandoned mid-run: it is legitimately long-running (186-193 suites, confirmed not
  hung via process-tree CPU inspection) and, more importantly, not what the directive asks for —
  gate 8 as invoked by `verify-deploy.sh` does not pass `--fail-on-new` internally, so it fails on
  ANY roster-listed row regardless of this task's fix (a pre-existing, unrelated row,
  `test-orchestrate-cycle-postflight.sh`, already makes it non-green).
- **Task 4.7** deferred: "Run the complete gate set" is deferred to the batch stage per the same
  Batch Gate Deferral directive — it runs once for the whole `/orchestrate` batch invocation, not
  independently per task, and its result is attributed back to this task by its own
  `modified_files`.

## Verification

- Build: N/A (shell scripts; no build step)
- Tests:
  - `test-postflight-deploy-gate.sh`: 29 passed, 0 failed (was 17 passed, 12 failed).
  - `test-redeploy-checkpoint-promotion.sh`: 17 passed, 0 failed (was 10 passed, 7 failed).
  - `test-orchestrate-predispatch-review.sh`: 37 passed, 0 failed (was 35 passed, 2 failed). No
    `No such file or directory` text for `lib/project-number-inuse.sh` remains in its output.
  - `test-orchestrate-unwind-dispatch.sh`: unchanged, 21 passed, 0 failed; `git diff` across all
    four phases shows no hunk in this file.
  - Scoped covering check (`run-all.sh --only` across the three fixed suites plus the Phase 1
    Tier-Justification set and `test-orchestrate-unwind-dispatch.sh`, with `--fail-on-new`): exit
    0, 7 passed, 1 failed (1 expected: `test-orchestrate-cycle-postflight.sh`, a pre-existing,
    unrelated `needs-owner` roster row — status-transition/artifact-linking defect in postflight,
    not touched by this task), 0 NEW.
  - Deployed-tree confirmation: `grep -c project-number-inuse` on each of the three suites'
    deployed counterparts under `.claude/scripts/tests/` returns 1, 1, and 3 respectively; the
    deployed `known-failures.txt` names none of the three suites.
  - `known-failures.txt`: the three rows for the fixed suites are deleted; no other row changed
    (verified by diffing against the pre-task version — exactly 3 lines removed, nothing else).
- Files verified: Yes

## Impacts

- The three fixture suites now correctly exercise `state-write.sh`'s real behavior instead of
  aborting before any assertion under test can run, restoring their value as regression coverage.
- `known-failures.txt` is back in agreement with observed reality for these three suites, so the
  roster stops being misleading to the next reader (its own header states it is the single
  source of truth for which suites are known-failing).
- No change to any assertion, fixture shape, or logic under test in any of the three suites — the
  fix is purely additive dependency-declaration repair.

## Follow-ups

- **`lint-test-fixture-dependency-drift.sh`** (not built here): a lint-time check that would
  derive each fixture's dependency-copy list from the subject script's own `source` lines and
  flag drift, closing this defect class by construction. Sized by the evidence already gathered:
  the corpus-wide re-derivation performed during this task's research and planning found zero
  drift anywhere else in the corpus beyond the three suites fixed here, so this detector is a
  guard against recurrence, not a fix for a currently-live defect. Recorded as a follow-up
  candidate, not a blocker.
- The complete gate set for the whole `/orchestrate` batch invocation (deferred per this
  dispatch's Batch Gate Deferral directive) still needs to run once, at the end of the batch, and
  its result is attributed back to this task by its own `modified_files`.
- `test-orchestrate-cycle-postflight.sh`'s existing, unrelated `needs-owner` roster row
  (status-transition/artifact-linking defect in postflight acceptance cases 6/7/8b) remains open
  and was not touched by this task.

## References

- Plan: specs/569_repair_stale_fixture_lib_dependency_lists/plans/01_stale-fixture-dependency-remedy.md
- Research report: specs/569_repair_stale_fixture_lib_dependency_lists/reports/01_stale-fixture-dependency-lists.md
- Issue log: specs/569_repair_stale_fixture_lib_dependency_lists/issues.jsonl
