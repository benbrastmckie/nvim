# Implementation Summary: Task #573

- **Task**: 573 - Fix two single-assertion suite failures
- **Status**: [COMPLETED]
- **Started**: 2026-11-11T13:30:00Z
- **Completed**: 2026-11-11T14:00:00Z
- **Effort**: ~30 minutes
- **Dependencies**: Task 589 (test_suite_repo_root_walk_up_depth) -- completed; its commits
  `6a0d6a373` and `9bc6a7d18` carry the actual fix for both of this task's named failures
- **Artifacts**: plans/01_assertion-closure-confirmation.md, reports/01_assertion-failures-closed-by-589.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

This task was opened to diagnose and fix one failing assertion each in
`test-deploy-baseline-lib.sh` (29 passed, 1 failed) and `test-lint-deploy-caller-wrap.sh`
(10 passed, 1 failed). Both root causes were found and fixed entirely under task 589
(invocation-path-dependent repo-root resolution, migrated to `common_test_repo_root` /
`common_test_ext_root`), which closed before this task's research and plan were written. This
task's implementation is therefore closure-confirmation only: it re-measures both suites, from
both invocation paths, in this dispatch, and records that closure. No source file was changed by
this task.

## What Changed

- `specs/573_fix_two_single_assertion_suite_failures/summaries/01_assertion-closure-confirmation-summary.md` -- created (this file).
- No other file was modified. In particular, neither `test-deploy-baseline-lib.sh` nor
  `test-lint-deploy-caller-wrap.sh` was touched: the correct fix was to the shared root-cause
  resolver, and it already landed under task 589.

## Decisions

- No change was made to either suite's assertion or subject behaviour. Task 589 already
  performed the correct fix by migrating both suites' root-resolution logic to the existing
  `common_test_repo_root` / `common_test_ext_root` helpers. The addendum's own instruction --
  "Do not fix either symptom by relaxing a control case" -- is honored by not touching either
  assertion now that the shared underlying resolver is fixed.
- The task description's original exclusion of the `repair_stale_fixture_lib_dependency_lists`
  cluster as this task's cause is reconfirmed: neither suite ever used the
  `REQUIRED_LIBS`/`REQUIRED_SCRIPTS` fixture-copy mechanism, and task 589's actual fix for both
  suites was entirely about repo-root resolution, independently corroborating that exclusion.

## Plan Deviations

- None (implementation followed plan).

## Verification

### Phase 1 re-measurement (both invocation paths, captured verbatim in this dispatch)

| Suite | Deployed path (`.claude/scripts/tests/`) | Source-store path (`agent-system/extensions/core/scripts/tests/`) |
|---|---|---|
| `test-deploy-baseline-lib.sh` | 30 passed, 0 failed | 30 passed, 0 failed |
| `test-lint-deploy-caller-wrap.sh` | 7 passed, 0 failed | 7 passed, 0 failed |

`bash .claude/scripts/tests/run-all.sh --only test-deploy-baseline-lib.sh,test-lint-deploy-caller-wrap.sh`:
`[run-all] 2 passed, 0 failed (0 expected, 0 NEW), 0 skipped, 2 total`, exit 0.

`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-deploy-baseline-lib.sh,test-lint-deploy-caller-wrap.sh`:
`[run-all] 2 passed, 0 failed (0 expected, 0 NEW), 0 skipped, 2 total`, exit 0.

Both paths agree exactly on both suites' tallies -- no disagreement of the kind task 589 fixed.

**Carried-figure correction**: the task description's original standalone figures (29 passed/1
failed for `test-deploy-baseline-lib.sh`; 10 passed/1 failed for
`test-lint-deploy-caller-wrap.sh`) are stale, superseded by task 589's fix. Note also that
`test-lint-deploy-caller-wrap.sh`'s assertion *total* changed from 11 (10 passed + 1 failed) to 7
(7 passed + 0 failed), not merely a flip of one assertion's polarity: task 589's fix removed a
double-count in that suite's `EXTENSIONS_DIR` scan (which previously widened to the whole
repository when run from the deployed copy, double-counting every genuine caller site via the
deployed tree's own duplicate of the source files), rather than correcting one failing
assertion's result in place.

**`known-failures.txt` re-check**: neither `test-deploy-baseline-lib.sh` nor
`test-lint-deploy-caller-wrap.sh` appears in
`agent-system/extensions/core/scripts/tests/known-failures.txt` (grep returned no match for
either basename) -- no stale manifest row exists to retire for either suite, and none appeared
since this task's plan was authored.

**Re-read for drift**: both suite files (deployed and source-store copies) were re-read
immediately before measuring; `diff` between the two copies was empty for both files, confirming
no drift since plan authoring and no sibling-task interference.

### Scoped gate discharge (Batch Gate Deferral)

This dispatch runs inside a multi-task `/orchestrate` batch invocation whose dispatch file
carries a `## Batch Gate Deferral` directive for this plan's final phase (Phase 2, declared
`**Verification Tier**: full`). Per that directive, the complete gate set
(`bash .claude/scripts/verify-deploy.sh`) is deferred to the once-per-invocation batch-level
stage rather than independently run in this dispatch.

The scoped discharge actually covering this phase's own touched file (the summary artifact
itself, under `specs/**`) is the **unmappable-criterion path**: neither
`run-all.sh --only SUITE[,...]` nor `verify-deploy.sh --only-gate N[,...]` expresses "validate a
specs/** summary artifact against summary-format.md" -- that is `validate-artifact.sh`'s own
job, which the plan's own Testing & Validation section already names directly. Run instead:

```
bash .claude/scripts/validate-artifact.sh \
  specs/573_fix_two_single_assertion_suite_failures/summaries/01_assertion-closure-confirmation-summary.md \
  summary
```

Result: **PASS** -- `[PASS] summary artifact is valid (0 warning(s))`, exit 0 (see Appendix below
for the test-suite verbatim output).

The complete gate set (`verify-deploy.sh`) still runs exactly once for the whole batch at the end
of this invocation; its result is attributed back to this task via its own `modified_files`
(this summary file only).

- Build: N/A (meta task, no build step)
- Tests: Passed (both named suites, both invocation paths; see table above)
- Files verified: Yes -- summary file exists, is non-empty, and `validate-artifact.sh` passes on it.
- `git status --short`: footprint is this task's own directory only (plan checkbox/heading
  edits, progress files, handoffs, and this summary) -- no modification to either suite file or
  to `known-failures.txt`.

## Impacts

- Closes task 573 with zero source-file change: the fix for both of this task's named failures
  was delivered entirely by task 589.
- Confirms task 589's root-resolution fix is durable under both invocation paths for the two
  suites this task was responsible for, adding independent re-verification beyond task 589's own
  summary claims.

## Follow-ups

- None new. The two residual, out-of-scope items already recorded under task 589's own summary
  (the `verify-deploy.sh` `gate8_run` wrapper exit-code discrepancy, and a prospective
  `lint-test-root-resolution.sh` closing this defect class by construction) remain owned there
  and are not duplicated here.

## References

- `specs/573_fix_two_single_assertion_suite_failures/plans/01_assertion-closure-confirmation.md`
- `specs/573_fix_two_single_assertion_suite_failures/reports/01_assertion-failures-closed-by-589.md`
- `specs/589_test_suite_repo_root_walk_up_depth/summaries/01_test-root-resolution-remedy-summary.md`
- `specs/589_test_suite_repo_root_walk_up_depth/plans/01_test-root-resolution-remedy.md`

## Appendix: Verbatim Command Output (this dispatch)

```
$ bash .claude/scripts/tests/run-all.sh --only test-deploy-baseline-lib.sh,test-lint-deploy-caller-wrap.sh
[run-all] Mode: deployed (scripts root: /home/benjamin/.config/nvim/.claude/scripts)
[run-all] Discovered 2 suite(s).
[run-all] [RUN]  /home/benjamin/.config/nvim/.claude/scripts/tests/test-deploy-baseline-lib.sh
[run-all] [PASS] /home/benjamin/.config/nvim/.claude/scripts/tests/test-deploy-baseline-lib.sh
[run-all] [RUN]  /home/benjamin/.config/nvim/.claude/scripts/tests/test-lint-deploy-caller-wrap.sh
[run-all] [PASS] /home/benjamin/.config/nvim/.claude/scripts/tests/test-lint-deploy-caller-wrap.sh
[run-all] 2 passed, 0 failed (0 expected, 0 NEW), 0 skipped, 2 total

$ bash .claude/scripts/tests/test-deploy-baseline-lib.sh
Results: 30 passed, 0 failed

$ bash .claude/scripts/tests/test-lint-deploy-caller-wrap.sh
Results: 7 passed, 0 failed

$ bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-deploy-baseline-lib.sh,test-lint-deploy-caller-wrap.sh
[run-all] Mode: source-store (extensions root: /home/benjamin/.config/nvim/agent-system/extensions)
[run-all] Discovered 2 suite(s).
[run-all] [RUN]  /home/benjamin/.config/nvim/agent-system/extensions/core/scripts/tests/test-deploy-baseline-lib.sh
[run-all] [PASS] /home/benjamin/.config/nvim/agent-system/extensions/core/scripts/tests/test-deploy-baseline-lib.sh
[run-all] [RUN]  /home/benjamin/.config/nvim/agent-system/extensions/core/scripts/tests/test-lint-deploy-caller-wrap.sh
[run-all] [PASS] /home/benjamin/.config/nvim/agent-system/extensions/core/scripts/tests/test-lint-deploy-caller-wrap.sh
[run-all] 2 passed, 0 failed (0 expected, 0 NEW), 0 skipped, 2 total

$ bash agent-system/extensions/core/scripts/tests/test-deploy-baseline-lib.sh
Results: 30 passed, 0 failed

$ bash agent-system/extensions/core/scripts/tests/test-lint-deploy-caller-wrap.sh
Results: 7 passed, 0 failed
```
