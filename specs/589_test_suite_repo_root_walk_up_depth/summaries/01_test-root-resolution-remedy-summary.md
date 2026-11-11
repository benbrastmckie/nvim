# Implementation Summary: Task #589

- **Task**: 589 - Test suite repo-root walk-up depth is invocation-path dependent
- **Status**: [COMPLETED]
- **Started**: 2026-11-11T07:32:06Z
- **Completed**: 2026-11-11T09:25:00Z
- **Effort**: ~2 hours
- **Dependencies**: None (task 573 depends on this one)
- **Artifacts**: plans/01_test-root-resolution-remedy.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Five core test suites (plus one further, adjacent suite discovered during the sweep) computed
their own repository root by walking up a fixed number of path segments from their own script
directory. That depth was correct only for the source-store invocation path and resolved outside
the repository (or to the wrong directory) when the same suite ran from its deployed copy,
exactly as `run-all.sh`'s gate 8 invokes it. All six affected suites were migrated to the existing
`common_test_repo_root`/`common_test_ext_root` helpers (git-rooted, invocation-path independent),
and a sibling production-script defect (`orchestrate-build-aux-dispatch.sh`'s deployed-mode model
resolution) was fixed the same way. A second, independently pre-existing defect was discovered
and fixed along the way (see Plan Deviations).

## What Changed

- `agent-system/extensions/core/scripts/tests/test-gate-cache-lib.sh` — root computation
  migrated to `common_test_repo_root "$SCRIPT_DIR"` plus an empty-root guard; separately, its
  case11 (sourced-library implementation-digest sensitivity) now resolves the perturbed `lib/`
  directory the same way the SUT's own `gate_cache_libdir_digest` does (source-store-first,
  deployed-fallback), rather than a path that varies by invocation path.
- `agent-system/extensions/core/scripts/tests/test-gate-registry-resolution.sh` — same root-
  computation migration.
- `agent-system/extensions/core/scripts/tests/test-deploy-baseline-lib.sh` — same root-computation
  migration, plus correction of a comment that stated the removed fixed-depth relationship as the
  mechanism.
- `agent-system/extensions/core/scripts/tests/test-lint-deploy-caller-wrap.sh` — `EXTENSIONS_DIR`
  migrated to `common_test_ext_root(common_test_repo_root(...))` plus an empty/non-directory
  guard, so its file scan no longer widens to the whole repository (double-counting every genuine
  caller via its own deploy-tree duplicate) when run from the deployed copy.
- `agent-system/extensions/core/scripts/tests/test-gate-cache-equivalence.sh` — same
  `common_test_repo_root` migration (an adjacent suite not in the task's named five, carrying the
  identically-shaped defect at a different walk depth; discovered and confirmed via Phase 1's
  measurement sweep).
- `agent-system/extensions/core/scripts/orchestrate-build-aux-dispatch.sh` — `EXT_ROOT` converted
  from a single fixed-depth string to an ordered, invocation-path-independent candidate list
  (source-store glob first and unchanged, a git-rooted `agent-system/extensions` glob second, the
  deployed `agents/` tree directly third), closing a production defect that silently emptied the
  `model` field for every aux dispatch when the script ran from its deployed location.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-aux-dispatch.sh` — stale
  explanatory comment corrected to describe the new candidate ordering.
- `specs/589_test_suite_repo_root_walk_up_depth/progress/phase-1-baseline.json` — full
  before/after measurement record for all seven candidates across both invocation paths.

## Decisions

- Reused the existing `common_test_repo_root`/`common_test_ext_root` test helpers directly inside
  the one production script (`orchestrate-build-aux-dispatch.sh`) rather than inlining a second,
  non-test-prefixed resolution: they are already transitively in scope via that script's own
  `skill-base.sh` → `lib/common.sh` load chain (on both its deployed and source-store-fallback
  branches) and have no test-only side effects. Recorded via `issue-record.sh`.
- `test-verify-deploy-gate-selection-crash-net.sh` (the second adjacent candidate examined in
  Phase 5) received no edit: it resolves an objectively wrong root under the deployed path
  (confirmed via rsync/cp stderr noise) but its single assertion does not depend on the
  mis-resolved path, so its tally is identical under both invocation paths — a legitimate
  `passes-both` outcome under the plan's own measurement-first methodology.
- The complete gate set (`verify-deploy.sh` with no `--only-gate`) was deferred to the
  batch-level stage per this dispatch's Batch Gate Deferral directive; this phase instead
  discharged its verification via the directive's named scoped narrowing (`--only-gate 8`) plus
  direct, standalone runs of every suite this task touched.

## Plan Deviations

- **Phase 4**'s `EXT_ROOT` candidate-list construction was relocated to immediately after
  `skill-base.sh` is sourced, rather than at the plan-named line 56: `common_test_repo_root`/
  `common_test_ext_root` are not in scope until that source line runs, and `EXT_ROOT` was not
  used anywhere between the two locations, so this is a pure relocation with no behavior change
  for the existing, passing candidate-1 path.
- **Phase 6** found and fixed a second, independently pre-existing defect beyond the plan's named
  edit list: `test-gate-cache-lib.sh`'s case11 perturbed `$CORE_DIR/lib` (invocation-path
  dependent) to probe implementation-digest sensitivity, but the SUT's own digest resolution
  (`gate_cache_libdir_digest`) is source-store-first/deployed-fallback — identical to other
  resolvers in the same library — so perturbing the deployed copy from the deployed invocation
  path never touched what the digest actually hashes. This was masked by the primary ROOT defect
  (which made every case in that suite fail via a `CANNOT_COMPUTE` sentinel) until the ROOT fix
  unmasked it as case11's own, independent failure. Fixed by resolving the same directory the SUT
  resolves before picking a file to perturb. This was completed, not deferred, since it was
  required to meet the plan's own stated Goal that all five named suites pass from both
  invocation paths.
- **Phase 6**'s "run the complete gate set" verification step was deferred to the batch-level
  stage per this dispatch's Batch Gate Deferral directive (see Decisions above).
- **Phase 6** also surfaced, but left unresolved and out of scope, a discrepancy in
  `verify-deploy.sh`'s own `gate8_run` wrapper: it reports an overall FAIL for gate 8, while
  byte-for-byte reproduction of its underlying `run-all.sh` invocation (tried three times, with
  and without `GATE_MUTEX_HELD=1` exported) consistently returns exit 0 with 0 NEW failures and
  none of this task's suites in the failing-suite roster. The wrapper's own exit-code handling —
  a file this task did not edit — was not further investigated given the cost per reproduction
  attempt (10-20 minutes); recorded via `issue-record.sh` for a separate task.

## Verification

- Build: N/A (shell scripts; `bash -n` syntax-checked on every edited file)
- Tests: All six affected suites (five named plus the one adjacent fix) report identical, green
  tallies from both the source-store and deployed invocation paths: `test-deploy-baseline-lib.sh`
  30/0, `test-gate-cache-lib.sh` 28/0, `test-gate-registry-resolution.sh` 44/0,
  `test-lint-deploy-caller-wrap.sh` 7/0, `test-orchestrate-build-aux-dispatch.sh` 22/0,
  `test-gate-cache-equivalence.sh` 17/0.
- Files verified: Yes — deployed copies confirmed byte-identical to the source store for every
  edited file after the final redeploy.

## Impacts

- Gate 8 (`run-all.sh`'s full suite sweep, as invoked from the deployed tree) no longer carries a
  spurious, root-cause-unrelated new failure for any of these six suites.
- `orchestrate-build-aux-dispatch.sh`'s `model` field now resolves correctly for every aux
  dispatch kind when the script runs from its deployed location — previously silently empty in
  production, not only under test.
- Both of task 573's two single-assertion failures are now closed: `test-deploy-baseline-lib.sh`'s
  "control: a genuinely matching warm-cache entry was expected to skip gate 1 but did not"
  assertion (29/1 before, 30/0 after) and `test-lint-deploy-caller-wrap.sh`'s classification
  assertion (10/1 before, 7/0 after). Task 573 owns the re-measurement and closure of its own
  record; this task hands it the evidence (recorded via `issue-record.sh`) without editing task
  573's own artifacts.

## Follow-ups

- A `lint-test-root-resolution.sh` closing this class by construction (the shape
  `lint-test-harness-adoption.sh` models) was identified as a worthwhile follow-up during
  planning but intentionally not built here — see the plan's Non-Goals. Evidence for the class's
  membership: the five originally-named suites plus the one adjacent suite confirmed affected in
  Phase 5, and the two further suites (`test-verify-deploy-gate-selection-crash-net.sh`,
  carrying the identically-shaped fixed-depth pattern but not actually affected) examined and
  found unaffected in the same sweep.
- The `verify-deploy.sh` `gate8_run` wrapper discrepancy (see Plan Deviations) is unresolved and
  recorded via `issue-record.sh` for a separate task to investigate.
- A pre-existing, unrelated gate-24 (`lint-dead-command-recommendations.sh`) finding in two memory
  extension docs (`/ide` dead command references) and a pre-existing `[SKIP]` for
  `test-source-store-path-lib.sh` (lost executable bit) were both observed during this task's
  redeploy runs and recorded via `issue-record.sh`; neither is in this task's scope.

## References

- Plan: `specs/589_test_suite_repo_root_walk_up_depth/plans/01_test-root-resolution-remedy.md`
- Baseline before/after record:
  `specs/589_test_suite_repo_root_walk_up_depth/progress/phase-1-baseline.json`
- `specs/569_repair_stale_fixture_lib_dependency_lists/` — unrelated prior cluster this task's
  description distinguishes itself from (neither affected suite uses that cluster's fixture-copy
  mechanism)
