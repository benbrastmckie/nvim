# Research Report: Task #573

**Task**: 573 - Fix two single-assertion suite failures
**Started**: 2026-11-11T10:14:56Z
**Completed**: 2026-11-11T10:35:00Z
**Effort**: ~20 minutes (re-measurement only; root cause and fix were already delivered by task 589)
**Dependencies**: task 589 (test_suite_repo_root_walk_up_depth) -- completed, commits
  `6a0d6a373` and `9bc6a7d18`
**Sources/Inputs**:
- `specs/589_test_suite_repo_root_walk_up_depth/summaries/01_test-root-resolution-remedy-summary.md`
- `specs/589_test_suite_repo_root_walk_up_depth/plans/01_test-root-resolution-remedy.md`
- Direct standalone re-execution of both named suites, from both the source-store and the
  deployed invocation path
- `git log` on both affected files
- `specs/state.json` (project status for 573 and 589)
**Artifacts**:
- This report (`specs/573_fix_two_single_assertion_suite_failures/reports/01_assertion-failures-closed-by-589.md`)
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Both of this task's two single-assertion failures were already root-caused and fixed by task
  589, which closed before this dispatch ran (`515a0b8fe task 589: complete implementation`).
- Direct standalone re-execution, performed in this dispatch, confirms closure: both suites now
  pass fully, with identical tallies from the source-store and deployed invocation paths --
  `test-deploy-baseline-lib.sh` 30 passed / 0 failed (was 29/1), `test-lint-deploy-caller-wrap.sh`
  7 passed / 0 failed (was 10/1).
- The shared root cause was invocation-path-dependent repo-root resolution: both suites computed
  their repository root via a fixed-depth walk-up tuned for the source-store path, which resolved
  outside the repository (or to the deployed tree's own duplicate content) when run from the
  deployed copy, as `run-all.sh` gate 8 does.
- Neither suite used this task's originally-suspected cluster mechanism
  (`repair_stale_fixture_lib_dependency_lists`'s `REQUIRED_LIBS`/`REQUIRED_SCRIPTS` fixture-copy
  pattern) -- confirmed correctly excluded by the task description, and task 589's actual fix
  (migration to `common_test_repo_root`/`common_test_ext_root`) independently corroborates that
  exclusion.
- No further change to either suite's assertion or subject behaviour is warranted: the addendum's
  own instruction ("Do not fix either symptom by relaxing a control case") is satisfied by
  construction -- task 589 fixed the root-cause resolver, not either suite's assertion logic.
- Recommendation: proceed directly to closing task 573 at the implement phase with a no-op/
  confirmation-only implementation (or close without an implementation phase, per whatever this
  repository's convention is for a task whose fix landed entirely under a dependency task) --
  there is no further code change for this task to make.

## Context & Scope

This task was opened to diagnose and fix one failing assertion each in two independently
reproducing suites:

- `test-deploy-baseline-lib.sh`: 29 passed, 1 failed (standalone)
- `test-lint-deploy-caller-wrap.sh`: 10 passed, 1 failed (standalone)

The task description explicitly ruled out the initially-suspected cause
(`repair_stale_fixture_lib_dependency_lists`'s `REQUIRED_LIBS`/`REQUIRED_SCRIPTS` fixture-copy
mechanism), noting neither suite uses it, and asked whoever worked the task to determine, for
each suite, whether the assertion or the subject behaviour was wrong before changing either.

A later addendum (orchestration conclusion stage, 2026-11-10) recorded a root-cause candidate
discovered incidentally during unrelated work (task 587): both suites are among five whose
repo-root resolution hardcodes a walk-up depth tuned for the source-store path, which resolves
outside the repository when invoked from the deployed tree (as gate 8 of `run-all.sh` does). That
candidate cause was assigned to a new, dedicated task -- 589 -- on which 573 was made to depend,
with an explicit instruction to re-measure both assertions after 589 landed rather than assume
either survived it.

This dispatch's scope was exactly that re-measurement, now that task 589 has completed
(`specs/state.json` status `completed`; commits `6a0d6a373` "task 589 phase 2: migrate three
repo-root walk-up suites to common_test_repo_root" and `9bc6a7d18` "task 589 phase 3: make
test-lint-deploy-caller-wrap.sh scan root invocation-path independent").

## Findings

### Codebase Patterns

- Both suites exist in two locations, as is standard for this repository's source-store/deploy
  split: `agent-system/extensions/core/scripts/tests/{suite}.sh` (source store) and
  `.claude/scripts/tests/{suite}.sh` (deployed copy). Both were re-measured from both locations.
- `git log --oneline -- <both files>` shows no commits touching either file since task 589's two
  phase commits, confirming no intervening work altered either suite after 589's fix landed.

### Direct Re-measurement (this dispatch)

Ran both suites standalone, from both invocation paths, with no other suites running
concurrently:

| Suite | Path | Result |
|---|---|---|
| `test-deploy-baseline-lib.sh` | deployed (`.claude/scripts/tests/`) | 30 passed, 0 failed |
| `test-deploy-baseline-lib.sh` | source store (`agent-system/extensions/core/scripts/tests/`) | 30 passed, 0 failed |
| `test-lint-deploy-caller-wrap.sh` | deployed (`.claude/scripts/tests/`) | 7 passed, 0 failed |
| `test-lint-deploy-caller-wrap.sh` | source store (`agent-system/extensions/core/scripts/tests/`) | 7 passed, 0 failed |

The specific assertion originally failing in `test-deploy-baseline-lib.sh` --
"control: a genuinely matching warm-cache entry was expected to skip gate 1 but did not" -- now
reads `[PASS] control: a genuinely matching warm-cache entry DOES skip gate 1 (SKIP-CACHED),
confirming the harness itself is wired correctly` in both re-runs, with no accompanying
chmod/mtime sandbox-artifact stderr noise of the kind originally observed alongside the failure.

`test-lint-deploy-caller-wrap.sh`'s total assertion count dropped from 11 (10 passed + 1 failed)
to 7 (7 passed + 0 failed) rather than simply flipping one assertion's polarity. This matches
task 589's own documented fix for this suite: its `EXTENSIONS_DIR` scan previously widened to the
whole repository when run from the deployed copy (resolving outside the repo via the same
fixed-depth walk-up defect), double-counting every genuine caller site via the deployed tree's
own duplicate of the source files. Migrating `EXTENSIONS_DIR` to
`common_test_ext_root(common_test_repo_root(...))` eliminated that double-count, which is why the
assertion total itself shrank rather than only its pass/fail split. The suite's one remaining
classification assertion ("exactly the two known genuine caller sites ... were found") now
passes cleanly in both locations.

### External Resources

Not applicable -- this was a pure codebase re-verification task with no external research
required, consistent with the agent-routing table's `meta` task-type classification.

## Decisions

- No change to either suite's assertion or subject behaviour is made by this task. Task 589
  already performed the correct fix (migrating both suites' root-resolution logic to the
  existing `common_test_repo_root`/`common_test_ext_root` helpers), and the addendum's own
  instruction -- "Do not fix either symptom by relaxing a control case" -- is honored by not
  touching either assertion now that the shared underlying resolver is fixed.
- The task description's original exclusion of the `repair_stale_fixture_lib_dependency_lists`
  cluster (task 569) as this task's cause is reconfirmed: task 589's fix for both suites was
  entirely about repo-root resolution, with no `REQUIRED_LIBS`/`REQUIRED_SCRIPTS` fixture-copy
  mechanism involved at any point.
- This task's record is narrowed to closure-confirmation only: both named failures are closed,
  with no residual unknown-cause failure remaining under this task's scope.

## Recommendations

1. Proceed to the implement phase (or an equivalent closure step, per this repository's own
   convention for a task whose underlying fix landed entirely under a dependency task) to mark
   task 573 complete. There is no source-code change left for this task to make: both target
   suites are green from both invocation paths, confirmed by direct re-execution in this
   dispatch, not merely by citing task 589's own summary.
2. If this repository's workflow requires an implementation-phase artifact even when no code
   change is needed, that phase should record this report's re-measurement evidence (the table
   above) as its verification, rather than re-running a diagnosis that has already been completed
   twice (once during task 589, once in this dispatch).
3. No new task is needed for either suite. The two residual, out-of-scope items task 589's own
   summary flagged (the `verify-deploy.sh` gate8_run wrapper exit-code discrepancy, and a
   follow-up `lint-test-root-resolution.sh` to close this defect class by construction) are
   already recorded via `issue-record.sh` under task 589 and are not this task's responsibility
   to re-open or duplicate.

## Risks & Mitigations

- **Risk**: Relying solely on task 589's summary without independent re-verification could miss
  a regression introduced between 589's own verification and this dispatch.
  **Mitigation**: Applied -- this dispatch independently re-ran both suites from both invocation
  paths rather than trusting the summary's claimed tallies at face value; the results matched
  exactly (30/0 and 7/0 both ways).
- **Risk**: A future edit to either suite, or to `common_test_repo_root`/`common_test_ext_root`
  themselves, could silently reintroduce invocation-path sensitivity.
  **Mitigation**: Out of this task's scope; task 589's own follow-up (a
  `lint-test-harness-adoption.sh`-shaped `lint-test-root-resolution.sh` closing the class by
  construction) is the correct long-term mitigation and is already recorded as a follow-up under
  589, not duplicated here.

## Context Extension Recommendations

None. This task required no new context documentation -- the relevant pattern
(invocation-path-dependent repo-root resolution and its `common_test_repo_root`/
`common_test_ext_root` fix) is already fully documented in task 589's own plan and summary
artifacts, which this report cites rather than restates.

## Appendix

- Commands run (this dispatch):
  - `bash .claude/scripts/tests/test-deploy-baseline-lib.sh`
  - `bash agent-system/extensions/core/scripts/tests/test-deploy-baseline-lib.sh`
  - `bash .claude/scripts/tests/test-lint-deploy-caller-wrap.sh`
  - `bash agent-system/extensions/core/scripts/tests/test-lint-deploy-caller-wrap.sh`
  - `git log --oneline -- agent-system/extensions/core/scripts/tests/test-deploy-baseline-lib.sh agent-system/extensions/core/scripts/tests/test-lint-deploy-caller-wrap.sh`
- References:
  - `specs/589_test_suite_repo_root_walk_up_depth/summaries/01_test-root-resolution-remedy-summary.md`
  - `specs/589_test_suite_repo_root_walk_up_depth/plans/01_test-root-resolution-remedy.md`
