# Implementation Summary: Task #486

- **Task**: 486 - Stop a required extension manifest.json registration being dropped from a phase commit as a scope excursion
- **Status**: [COMPLETED]
- **Started**: 2026-11-22T00:25:00Z
- **Completed**: 2026-11-23T16:00:00Z
- **Effort**: 3.5 hours
- **Dependencies**: None (430, 446, 484, 494, 541 all confirmed completed/archived by the research round)
- **Artifacts**: plans/01_manifest-containment-splice.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Implemented the research round's Option (1) ruling: a fourth, local, non-declared splice into
the Containment Self-Check's `file_scope_arr` that admits a touched extension's own
`manifest.json` whenever that same extension's own `scripts/` tree (excluding
`scripts/deprecated/`) is also present in a phase's `files_touched`. The splice is derived by a
pure string operation over `files_touched` — no filesystem, `git`, or `jq` lookup — and mutates
only the in-script array, never `specs/state.json`'s declared `file_scope`. Testing surfaced a
plan premise error mid-implementation: the widening also had to be mirrored into
`git-commit-scoped.sh`'s own, independent Site-3 V10 containment resolution, or the Site-2
widening alone turned the pre-existing silent drop into a loud completeness-check failure. Both
sites now carry the identical derivation, pinned by five new fixture cases, and the mechanism is
documented in `git-staging-scope.md`.

## What Changed

- `agent-system/extensions/core/scripts/git-commit-phase.sh` — added the fourth `file_scope_arr`
  splice (Site 2) plus its documenting header comment, inside the existing non-empty-guard,
  after the derived-output-prefix splice and before `is_contained()`.
- `agent-system/extensions/core/scripts/git-commit-scoped.sh` — mirrored the identical
  extension-manifest widening into the V10 `containment_scope_arr` resolution (Site 3); required
  because Site 2's admission alone does not change what Site 3 independently re-derives from raw
  `specs/state.json`, and the two sites must agree or the post-commit completeness check fails.
- `agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh` — five new fixture cases
  (45-49): the admit case, the `deprecated/` exclusion, the cross-extension negative case, the
  genuine-out-of-territory-path survival case (collapsed single issue row), and three fail-open
  shape-variants. The trailing-slash case was folded into the pre-existing Case 12 rather than
  duplicated.
- `agent-system/extensions/core/context/standards/git-staging-scope.md` — new paragraph in the
  "Three Containment sites, not one" section ("A fourth per-site widening, at sites 2 and 3
  only") documenting the trigger, the effect, the local-only guarantee, and the one-sentence
  rejection of Options (2) and (3).
- `agent-system/extensions/core/index-entries.json` — regenerated `line_count` for the edited
  doc, produced automatically by `deploy-headless.sh`'s `generate-context-line-counts.sh --write`
  step.

## Decisions

- Option (1) (prevent the first drop via a structural widening) adopted in full per the research
  round; Options (2) (pre-commit nag) and (3) (rely on the general declaration-staleness
  mechanism alone) rejected on the evidence cited in the plan's Research Integration section.
- The widening is local to each script's in-memory array only; it is never written back to
  `specs/state.json`'s declared `file_scope`, keeping the batch-admission gate's
  conflict-detection input untouched.

## Plan Deviations

- **Phase 2** (altered): the plan's Non-Goals originally excluded any change to
  `git-commit-scoped.sh`'s Site-3 V10 guard, on the premise that a Site-2-only splice would
  suffice. Writing the admit fixture (Case 45) disproved this directly — Site 2's widening
  admits the manifest path into the positive pathspec handed to `git-commit-scoped.sh`, whose own
  independent V10 resolution still dropped it, turning the pre-existing recoverable drop into a
  loud completeness-check failure (exit 6). Resolved by mirroring the identical pure-string
  derivation into `git-commit-scoped.sh`'s own `containment_scope_arr` resolution, and adding that
  file to Phase 2's own Files to modify. Recorded via `issue-record.sh --class "plan premise
  error"`.
- **Phase 2** (folded): the trailing-slash fixture was folded into the pre-existing Case 12
  (which already pins that behaviour unmodified by this task's splice) rather than duplicated, per
  the phase's own Scope Hypothesis fold-instead-of-duplicate instruction.

## Verification

- Build: N/A
- Tests: Passed — `test-git-commit-phase.sh` (44 pre-existing + 5 new cases) and
  `test-git-commit-scoped.sh` both green; the admit fixture was confirmed non-vacuous (fails when
  the splice is reverted, per Phase 2's own verification step).
- Files verified: Yes
- Scoped discharge (Batch Gate Deferral): `verify-touched.sh` over all five touched paths selected
  32 suites, 32 passed, 0 failed, against the freshly redeployed tree.
- `sync-manifest-scripts.sh --check` clean (no new script file added by this task).
- `check-task-references.sh` and the record-versioning lint report 0 unexempted / 0 BLOCKING
  findings across all four edited `agent-system/**` files.

## Impacts

- A phase that extracts a new shared shell library under an extension's `scripts/` tree and also
  edits that extension's `manifest.json` in the same change no longer has that registration
  silently dropped from the closing commit — the structurally-derivable obligation is now
  admitted at both containment sites before the commit fires.
- The fix is narrow: it does not touch the trailing-slash normalization, the engine-written-paths
  allowlist, or the fail-open posture on a missing/empty/malformed `file_scope`, all of which
  remain pinned by existing and new fixtures.

## Follow-ups

- None — the three territory-edge records cited in the originating dispatch
  (`feed_undeclared_implement_paths_into_file_scope`,
  `close_the_plan_to_file_scope_reconciliation_gap`,
  `collapse_perpath_scope_excursion_issue_rows_into_one`) were re-derived during planning and
  confirmed already landed; no further coordination is outstanding.

## References

- specs/486_manifest_registration_dropped_from_phase_commit/plans/01_manifest-containment-splice.md
- specs/486_manifest_registration_dropped_from_phase_commit/reports/01_manifest-registration-containment-rule.md
