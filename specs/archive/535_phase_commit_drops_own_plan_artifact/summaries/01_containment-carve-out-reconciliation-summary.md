# Implementation Summary: Task #535

- **Task**: 535 - Carve a task's own specs/ artifacts out of git-commit-phase.sh's containment filter, so a task's own plan file is never dropped from its own phase commit.
- **Status**: [COMPLETED]
- **Started**: 2026-11-23T03:55:00Z
- **Completed**: 2026-11-23T04:05:00Z
- **Effort**: ~1 hour
- **Dependencies**: None (port_containment_strip_to_git_commit_scoped already completed; satisfied in fact)
- **Artifacts**: plans/01_containment-carve-out-reconciliation.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

The code-level carve-out (`git-commit-phase.sh`'s own-task-directory and engine-written-state
splices into `is_contained()`'s scope array) was already landed before this dispatch began, per
the plan's own re-measurement. This implementation closed the two remaining gaps the plan
identified: a standards document still described the carve-out's mechanism inaccurately, and the
regression suite did not yet pin a dotfile sitting directly at the task-directory root, nor a
positive demonstration that the post-commit completeness check actually runs (rather than being
silently disarmed) in the single-own-file case.

## What Changed

- `agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh` — added Case 40 (two
  dotfiles directly at the task-directory root — `specs/999_probe/.return-meta.json` and
  `specs/999_probe/.orchestrator-handoff.json` — land with no drop warning and no scope-excursion
  issue row) and Case 41 (a fixture whose sole `files_touched` entry is the task's own plan
  artifact reaches `exit 6` via a planted pre-commit hook, proving the completeness check ran
  rather than being disarmed; a sibling unhooked run confirms the ordinary case returns `rc=0`
  with none of the four skip-family warnings). Suite grew from 98 to 104 assertions, all green.
- `agent-system/extensions/core/context/standards/git-staging-scope.md` — replaced the false
  "structurally outside its reach" mechanism sentence in the "Staging-Layer Containment Filter"
  subsection with an accurate account: the task's own resolved task directory, `specs/TODO.md`,
  and `specs/state.json` are explicit, tested members of each site's own scope array (admitted,
  not skipped); the plan path supplied via `--plan-path` is the one genuinely untested carve-out,
  since it reaches `stage_paths` on a separate code path. Added one sentence noting the
  containment test is plain bash case-pattern matching, not filesystem glob expansion.
- Regenerated deploy mirrors of both files under `.claude/` via `deploy-headless.sh`
  (`RESULT=landed_verify_clean`).
- `agent-system/extensions/core/index-entries.json` — synced the `line_count` field for
  `git-staging-scope.md`, a declared derived-output surface this task's own edit staled; landed
  without `--task` attribution since the path falls outside this task's declared `file_scope`
  (the sanctioned no-task-context commit path `git-commit-scoped.sh` already supports).

## Decisions

- Numbered the two new fixtures 40 and 41 (the suite's live tail was at 39/98 assertions),
  matching the plan's Scope Hypothesis.
- Performed the fails-first demonstration with a standalone scratch probe script outside the
  source store, rather than by temporarily editing the real suite or script, so
  `git-commit-phase.sh` stayed byte-identical throughout (confirmed via `git diff`, empty both
  before and after).
- Case 41's observed pre-fix behavior is `rc=5` (`git-commit-scoped.sh`'s own V8 partial-commit
  mismatch), not the plan's hypothesized `rc=0` — recorded as the actual measurement rather than
  silently matching the hypothesis, since the plan path never survives containment filtering to
  reach the completeness check at all pre-fix. Both outcomes equally demonstrate "not `rc=6`",
  i.e. the disarmament.
- Did not re-implement `is_contained()`, `file_scope_arr`'s construction, or any other logic in
  `git-commit-phase.sh` — per the plan's explicit non-goal, since route (a) was already landed.
- Did not edit `agents/general-implementation-agent.md` — its prose is the correct specification
  this task's fixtures verify against.

## Plan Deviations

- None (implementation followed plan).

## Verification

- Build: N/A
- Tests: Passed — `test-git-commit-phase.sh` 104/104 assertions green, both in the source store
  and against the deployed copy.
- Files verified: Yes — both edited files are byte-identical between source store and deployed
  mirrors (`diff -q`).
- Fails-first demonstration: both new regression cases fail against a scratch-reverted copy of
  `git-commit-phase.sh` (own-task-directory and engine-written-state splices removed) and pass
  against the real, untouched script.
- Deploy: `deploy-headless.sh` reported `RESULT=landed_verify_clean` (41 checks, 0 failures).
- Scoped touched-path check (`verify-touched.sh` over both edited files): 5 suites selected, 5
  passed, 0 failed. The complete gate set is deferred to this invocation's orchestration close
  per the Batch Gate Deferral directive.

## Impacts

- A future phase commit whose sole self-reported `files_touched` entry is the task's own plan
  artifact (or another task-directory dotfile) now has regression coverage proving the
  completeness check runs rather than being silently disarmed — the specific failure mode the
  originating record identified as the real cost (not data loss, but a disabled safety gate).
- The standards document a future implementer reads before touching this filter no longer states
  a mechanism that contradicts the code it describes.

## Follow-ups

- None.

## References

- `specs/535_phase_commit_drops_own_plan_artifact/plans/01_containment-carve-out-reconciliation.md`
- `specs/535_phase_commit_drops_own_plan_artifact/reports/01_containment-filter-carve-out.md`
- `specs/535_phase_commit_drops_own_plan_artifact/issues.jsonl`
