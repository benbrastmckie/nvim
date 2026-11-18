# Implementation Summary: Task #505

- **Task**: 505 - Suite selection fails to resolve a covering suite for non-core extension source paths
- **Status**: [COMPLETED]
- **Started**: 2026-11-15
- **Completed**: 2026-11-16
- **Effort**: ~2 hours
- **Dependencies**: None (ordering-only note with `plan_format_tier_justification_fixes`; no file overlap, no edge filed)
- **Artifacts**: plans/01_non-core-suite-selection-mapping.md, summaries/01_non-core-suite-selection-mapping-summary.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`suite-selection-lib.sh` previously derived its scripts/tests roots exactly once, from its own
file location, and evaluated every mapping stratum against that single tree -- so a touched path
under a non-core extension's `scripts/` could never resolve to its own extension's paired suite
and falsely escalated to `__FULL_SWEEP__`. All 5 plan phases are complete: the library now
resolves per-touched-path extension roots, `suite_selection_classify` reaches non-core suites on
real evidence, four new fixtures pin the required behaviours, the library's header carries a
freshly re-derived figure, and the fix has been redeployed and verified from both a source-store
and a deployed vantage point.

## What Changed

- `agent-system/extensions/core/scripts/lib/suite-selection-lib.sh` -- added `_ssl_extensions_parent`
  (the shared `core/manifest.json` marker-check helper) and `_ssl_roots_for_path` (per-touched-path
  extension-root resolution), threaded through all three strata of `_ssl_resolve_one`; broadened
  `suite_selection_classify`'s suite-file lookup with a per-extension fallback loop sharing the
  same marker-check helper; rewrote the SCOPE and RESOLUTION-ORDER CLASSIFICATION header blocks
  with the corrected behaviour description and a freshly measured, reproducible figure.
- `agent-system/extensions/core/scripts/tests/test-run-all-selection.sh` -- added four new pinning
  cases (case3b non-core resolution, case3c genuinely-uncovered-path sentinel preservation plus
  case3c-unmapped, case3d deployed-mode-unchanged via a synthetic fixture, case3e classification
  reaches non-core suites), all dynamically derived from the live corpus, inserted between case3
  and PART 2 so cases 4-25 keep their existing numbers.
- A regenerated deployed `.claude/**` tree (gitignored deploy artifact, not a committed output).

## Decisions

- Classification was EXTENDED to non-core suites rather than justified as legitimately core-only:
  the carried "0 of 19" figure was a measurement artifact of the suite-file lookup only ever
  checking this library's own default tree, not a genuine corpus property.
- Resolution is scoped to the ONE extension a touched path itself names, never a cross-extension
  grep, to avoid risking a coincidental basename collision changing core-path behaviour too.
- The marker-check helper (`_ssl_extensions_parent`) is shared between the selection half
  (`_ssl_roots_for_path`) and the classification half (`suite_selection_classify`'s fallback
  loop), per the plan's explicit instruction to avoid two copies of the same marker check.

## Plan Deviations

- Phase 1 task 1.4: the plan's literal core-path output prediction (`suite_selection_select` on
  `suite-selection-lib.sh` printing exactly `test-run-all-selection.sh`) did not hold before or
  after the edit -- the unedited library already returned three suites via a pre-existing
  stratum-(b) grep reference. Byte-identical output before/after the edit is the real
  no-narrowing evidence, and was confirmed. Logged to the issue log (class "plan premise
  inaccurate", severity minor).
- Phase 3's case3e derivation guard was narrowed mid-phase: a skip is now reserved for a true
  deployed vantage point (no extensions root at all); a source-store-mode derivation failure is
  a hard FAIL instead, discovered via the load-bearing check for this exact case.
- Phase 5's "run the complete gate set" task was discharged against this dispatch's Batch Gate
  Deferral scoped tier (sanctioned by the dispatch file, not self-initiated): `bash
  .claude/scripts/tests/run-all.sh --only "test-lint-shellcheck-parallel.sh,test-measure-gate-costs.sh,test-orchestrate-build-dispatch.sh,test-run-all-selection.sh,test-validate-artifact.sh,test-verify-deploy-gate-selection.sh"`
  passed 6/0. The complete gate set runs once for the whole `/orchestrate` batch at the end of
  this cycle and is attributed back to this task by its own `modified_files`.

## Verification

- Build: N/A (shell library, no build step)
- Tests: Passed -- `test-run-all-selection.sh` 36/0 from the source-store vantage point, 32/0
  from the deployed vantage point (4 non-core-derivation cases cleanly skip there, as expected).
  Each of the three new cases most directly tied to this task's code changes (case3b, case3d,
  case3e) was independently confirmed load-bearing by temporarily reverting the corresponding
  Phase 1/Phase 2 code and observing the matching case fail, then restoring.
- `lint-shellcheck.sh` exits 0 on both edited files throughout.
- `deploy-headless.sh` completed (`RESULT=landed_verify_clean`), with its own embedded
  `verify-deploy.sh` run passing clean (43 checks, 0 failures) as a side effect.
- Files verified: Yes.

## Impacts

- Any future plan whose Tier Justification needs to name a covering suite for a non-core
  extension source-store path can now rely on `suite_selection_select` to name it directly,
  instead of hand-naming the suite as a workaround (the pattern two tasks hit in the originating
  incident).
- The library header's SCOPE and classification notes now describe the corrected,
  extension-aware behaviour and carry a reproducible measurement rather than a stale, carried
  figure.

## Follow-ups

- None required by this task. The research report's separately-noted gap (7 missing
  `books`/`typst` rows in `suite-classification.data`) remains an explicit non-goal and a
  candidate for a future, separately-scoped task.
- The known limitation (a bare relative touched path with no
  `agent-system/extensions/<ext>/scripts/` segment falls through to the library-local tree) is
  documented in the header as an accepted gap, not a defect.

## References

- Plan: `specs/505_suite_selection_non_core_extension_paths/plans/01_non-core-suite-selection-mapping.md`
- Research report: `specs/505_suite_selection_non_core_extension_paths/reports/01_suite-selection-non-core-mapping.md`
- Progress files: `specs/505_suite_selection_non_core_extension_paths/progress/phase-{1..5}-progress.json`
- Handoffs: `specs/505_suite_selection_non_core_extension_paths/handoffs/phase-{1..5}-handoff-*.md`
