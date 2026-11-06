# Implementation Summary: Task #418

- **Task**: 418 - Make the lint-fixture-test family's subject resolution explicit and self-declaring
- **Status**: [IN PROGRESS]
- **Started**: 2026-11-06T21:00:00Z
- **Completed**: (not yet -- phases 4-8 remain)
- **Effort**: ~4 hours so far of an estimated 11
- **Dependencies**: None
- **Artifacts**: plans/01_explicit-subject-resolution.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

This round landed Phases 1-3 of an 8-phase plan that replaces the lint-fixture-test family's
implicit deploy-tree-first/source-store-fallback subject resolution with an explicit,
mode-selectable, self-declaring mechanism. Phase 1 added the two new shared-library functions.
Phase 2 shipped the gate-27 content lint with a full migration-pending allowlist. Phase 3
migrated all 20 Group A (shared-helper-caller) suites onto the explicit form. Phases 4-8 --
the local-duplicate and inline-loop migrations, the documentation correction, and the final
redeploy/full-gate-set pass -- remain.

This dispatch was a re-prompt of an earlier run that completed real Phase 3 work but died on an
API transport error before any wrap-up artifact was written. This summary, together with
`.return-meta.json` and `.orchestrator-handoff.json`, is that wrap-up.

## What Changed

- `agent-system/extensions/core/scripts/lib/common.sh` -- added `common_test_resolve_subject`
  and `common_test_declare_subject` (Phase 1, already committed: `c51aa1e4f`).
- `agent-system/extensions/core/scripts/lint/lint-subject-resolution-declaration.sh` -- new
  gate-27 two-layer content lint (Phase 2, committed `91954aa3e`/`8edccf7e0`); this round
  (Phase 3, commit `4b178352b`) shrank its allowlist by the 20 Group A entries and added two
  permanent exemptions: `test-common-lib.sh` (its own regression suite for the resolver
  functions) and `test-task-type-detect.sh` (a legitimate, intentionally-unmigrated
  single-candidate `REAL_EXT_ROOT` lookup that is not a deployed/source-store subject pair).
- 19 of the 20 Group A test suites under `agent-system/extensions/core/scripts/tests/` --
  migrated every `common_test_resolve_candidate` subject-resolution call site to
  `common_test_resolve_subject` with an explicit mode plus a `common_test_declare_subject` call.
  `test-gate-out-derived-staleness.sh` and `test-install-uninstall-extension.sh` moved to
  `mode=source-store` (the two confirmed non-default-order callers); the rest moved to
  `mode=deploy-tree-first`. (`test-common-lib.sh`, the 20th Group A member, already carried its
  own resolver fixtures from Phase 1 and needed no further edit this round.)
- `test-audit-task-proposals.sh`, `test-validate-task-creation-audit.sh` -- corrected a stale
  structural-model doc comment that still named `common_test_resolve_candidate`; the comment's
  mere mention of that token, combined with an unrelated `.claude/scripts` literal elsewhere in
  the same file, was tripping gate-27's file-level check 4 as a false positive.

## Decisions

- `test-task-type-detect.sh`'s `REAL_EXT_ROOT` lookup (a single-candidate extensions-directory
  resolution, not a deployed/source-store subject pair) stays on the old
  `common_test_resolve_candidate` helper by design, per the plan's "leave non-subject uses on the
  old helper" instruction. Because gate-27's Layer-1 check 4 is documented as file-level (not
  call-site-level) and cannot distinguish this call from the migrated one in the same file, it is
  recorded as a permanent allowlist exemption rather than relying on the commit message alone.
- The two stale doc-comment mentions of `common_test_resolve_candidate` were reworded to
  describe the resolver generically ("the explicit mode-selectable subject resolver in
  lib/common.sh") rather than naming either literal function token, after an initial attempt to
  rename them to `common_test_resolve_subject` instead tripped the lint's separate
  resolve_subject/declare_subject count-balance check (check 3) via the same file-level
  limitation.

## Plan Deviations

- None (implementation followed the plan; the two allowlist additions and comment corrections
  above are closing-the-gap fixes within Phase 3's own stated scope, not deviations from it).

## Verification

- Build: N/A (shell scripts)
- Tests: `run-all.sh --only` over the 20 Group A suites plus
  `test-lint-subject-resolution-declaration.sh`, `test-gate-registry-resolution.sh`,
  `test-manifest-scripts-sync.sh`, `test-deploy-verify-wiring.sh` -- 23 passed, 1 failed (see
  below), 0 skipped.
- `lint-subject-resolution-declaration.sh --verbose` (gate 27 itself): exit 0, 0 violations, 52
  exempted files.
- `lint-gate-registry.sh --verbose`: exit 0, 7/7 checks passed (gate 27's row is well-formed and
  contiguous).
- Files verified: Yes (all 20 pass `bash -n`).
- One pre-existing, unrelated failure: `test-lint-unit-integration-boundary.sh` fails against the
  live deployed tree because two deployed suites (`test-mcp-merge-target.sh`,
  `test-validate-no-python-state-write.sh`) have no row in
  `.claude/scripts/tests/suite-classification.data`. This is independent of subject resolution --
  confirmed by inspecting the failure (a classification-data gap, not a resolution-mode issue)
  and by the fact that these two files are untouched by this task's Group A migration. Not fixed
  here; attributed to a different task's territory.

## Impacts

- The 20 Group A suites now print a `[SUBJECT] <absolute path>` declaration for every resolved
  subject, making a vacuous (stale-deployed-copy) run visibly distinguishable from a genuine one.
- The gate-27 lint's allowlist shrank from 51 entries (50 migration-pending Group A/B/C plus 1
  self-exemption) to the Group B (12) and Group C (38) migration-pending entries plus 4 permanent
  exemptions (the lint's own fixture suite, `test-common-lib.sh`, `test-task-type-detect.sh`, and
  -- carried from Phase 2 -- the two non-subject-resolution `candidate` users).

## Follow-ups

- Phase 4: migrate the 12 Group B local-duplicate-function suites.
- Phase 5-6: migrate the 38 Group C inline-loop suites in two batches.
- Phase 7: correct the stale population figure and document the three-shape taxonomy.
- Phase 8: redeploy and run the complete gate set with an explicit source-store TARGET.
- The pre-existing `test-lint-unit-integration-boundary.sh` classification-data gap (two deployed
  suites with no row in `suite-classification.data`) is unrelated to this task and was not fixed.

## References

- `specs/418_explicit_lint_fixture_test_subject_resolution/plans/01_explicit-subject-resolution.md`
- `specs/418_explicit_lint_fixture_test_subject_resolution/reports/01_explicit-subject-resolution.md`
- `specs/418_explicit_lint_fixture_test_subject_resolution/progress/phase-1-progress.json`
- `specs/418_explicit_lint_fixture_test_subject_resolution/progress/phase-2-progress.json`
- `specs/418_explicit_lint_fixture_test_subject_resolution/progress/phase-3-progress.json`
