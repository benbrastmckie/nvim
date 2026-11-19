# Implementation Summary: Task #564

- **Task**: 564 - Fix validate-artifact.sh Tier Justification false positive (sentinel domination in `suite_selection_select`)
- **Status**: [COMPLETED]
- **Started**: 2026-11-19T00:00:00Z
- **Completed**: 2026-11-19T03:10:00Z
- **Effort**: ~2 hours
- **Dependencies**: 505 (already archived/[COMPLETED]; satisfied)
- **Artifacts**: plans/01_compositional-suite-selection-union.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`suite_selection_select` short-circuited to the `__FULL_SWEEP__` sentinel the moment any one
touched path in a multi-path call resolved to no suite, discarding every suite already found for
the other paths. This made the sentinel a ceiling imposed on the whole set rather than a floor
contributed by its own member, so `validate-artifact.sh`'s Tier Justification check read an
honest, narrow suite-list claim over a mixed touched set as a fabrication. All five plan phases
landed: the selector's aggregation is now compositional, its two production call sites
(`verify-deploy.sh`'s Gate 8 narrowing and `validate-artifact.sh`'s Tier Justification check) are
adapted to the new contract, the authoring contract text in `plan-format.md` documents the
mixed-set case, the new semantics are pinned with fixtures across three suites, and the deployed
tree has been regenerated and verified to match the source store byte-for-byte.

## What Changed

- `agent-system/extensions/core/scripts/lib/suite-selection-lib.sh` — `suite_selection_select`
  accumulates every path's resolution into a running union instead of short-circuiting; an
  unmappable path contributes the sentinel as one more member rather than replacing the whole
  result. `suite_selection_select_annotated` carries the sentinel through as a bare,
  unclassified line for a mixed set rather than losing its real suites' classified rows. The
  PUBLIC API header, the canonical Usage snippet, and a new per-path-composition warning were
  rewritten to match.
- `agent-system/extensions/core/scripts/verify-deploy.sh` — Gate 8's `--gate8-touched` detection
  changed from "the resolved array is exactly `[sentinel]`" to "the resolved array CONTAINS the
  sentinel anywhere", preserving the conservative full-battery fallback for any touched set with
  an unmappable path, mixed or not.
- `agent-system/extensions/core/scripts/validate-artifact.sh` — the Tier Justification check's
  sentinel-claim branch is restated as a contains-sentinel-AND-length-1 test (sentinel-only
  claims still correctly flagged over a mixed set); the suitelist-claim branch strips the
  sentinel token out of the actual set before computing missing/extra, so an honest mixed-set
  suite-list claim no longer reads as fabricated or under-verifying.
- `agent-system/extensions/core/context/formats/plan-format.md` — the Tier Justification
  authoring contract now documents the mixed-set case: the match obligation is qualified (name
  the real suites, never the sentinel token, for a mixed output), the `__FULL_SWEEP__` case
  bullet states the sentinel claim is honest only when it is the selector's entire output, a
  per-path-composition warning was added in the author-facing voice, and the Enforcement-level
  subsection states the sentinel-only-vs-sentinel-stripped comparison rule explicitly.
- `agent-system/extensions/core/scripts/tests/test-run-all-selection.sh` — Case 3 flipped from
  pinning the old short-circuit to pinning the new compositional union; four new cases added
  (a mixed bookkeeping+real-target set, an all-sentinel set, the preserved all-mappable
  invariant, and a synthetic two-phase plan driven through `validate-artifact.sh` as a real
  subprocess asserting 0 Tier Justification warnings).
- `agent-system/extensions/core/scripts/tests/test-gate8-suite-selection.sh` — a new Case G pins
  the Gate 8 fail-safe regression for a mixed mapped+unmapped `--gate8-touched` set, using a
  bystander suite in its fixture to distinguish a correct full-discovery fallback from an
  incorrect narrow-to-the-mapped-path-alone outcome.
- `agent-system/extensions/core/scripts/tests/test-validate-artifact.sh` — two new Tier
  Justification cases over a mixed touched set: an honest suite-list claim draws no finding, and
  a sentinel-only claim over the same mixed set correctly warns.
- Deployed `.claude/` tree regenerated via `deploy-headless.sh`; no file under it was
  hand-authored by this task.

## Decisions

- **Layer-ownership ruling (the task's own point 2)**: the selector layer
  (`suite-selection-lib.sh`) owns the fix, not `validate-artifact.sh`'s consumption of it. The
  two consumer-side edits are necessary adaptations to a changed API, not a second, independent
  fix of the same defect. Recorded in the Phase 1 commit message body per the task's own
  requirement.
- Gate 8's own fail-safe stays conservative by design: any sentinel presence in the resolved set
  falls back to the full battery, even though the compositional library also returns real
  suites alongside it — Gate 8 is execution-critical and must not narrow when any touched path's
  own coverage is unknown. This is a deliberately narrower choice than the generic library
  header's own Usage snippet documents for an advisory caller like the Tier Justification check,
  which may narrow over the sentinel-stripped output for its own comparison purposes.
- The Gate 8 fail-safe regression fixture was placed in `test-gate8-suite-selection.sh`, not
  either of the plan's two named candidates — see Plan Deviations below.

## Plan Deviations

- **Phase 4, Gate 8 fail-safe regression task**: placed in `tests/test-gate8-suite-selection.sh`
  rather than either of the plan's two named candidates (`test-run-all-selection.sh` /
  `test-verify-deploy-gate-selection.sh`). That file is the suite already dedicated to the exact
  `--gate8-touched`/`GATE8_TOUCHED` mechanism (stubbed-run-all.sh cases A-F already pin the
  absent-flag, single-mappable, multi-path-union, unmappable, cache-ineligibility, and
  argument-validation shapes for this same function); the other named candidate tests a disjoint
  mechanism (`--only-gate`, which gates run, not what Gate 8 itself narrows to internally). This
  phase's touched-file set and Tier Justification were widened and re-measured accordingly.
- **Phases 2, 4, and 5**: the plan's own `verify-touched.sh` scoped-check verification step timed
  out three separate times under this session's sustained heavy concurrent multi-task
  `/orchestrate` batch load (measured load average 8.28 during the Phase 5 occurrence), each time
  stuck on the identical trio of load-sensitive suites that each complete in well under a minute
  standalone — confirmed environmental contention, not a defect in this task's edits. Substituted
  direct per-vantage-point suite runs and, for Phase 5, a byte-for-byte source-store/deployed
  parity diff, as the covering evidence each time. Recorded via `issue-record.sh` at each
  occurrence.

## Verification

- Build: N/A (no compiled artifact)
- Tests: `test-run-all-selection.sh` 40/0 (source-store), 36/0 (deployed, with 3 vantage-dependent
  non-core cases cleanly skipping as designed); `test-validate-artifact.sh` 148/0 (deployed);
  `test-gate8-suite-selection.sh` 26/0 (deployed)
- Files verified: Yes — source-store/deployed byte-for-byte parity confirmed for all seven
  modified files; `deploy-headless.sh` reported `RESULT=landed_verify_clean`, 41 checks, 0
  failures

## Impacts

- A plan author can now declare a phase's real `Files to modify` scope honestly (including a
  bookkeeping path alongside a real narrow target) without the Tier Justification check
  misreading the claim as fabricated, or inventing a spurious workaround incentive to
  under-declare file scope.
- Gate 8's own `--gate8-touched` narrowing is now provably correct for a mixed mapped+unmapped
  touched set (previously it would have handed the literal sentinel string to `run-all.sh
  --only`, an invalid token, for that exact shape).
- `suite_selection_select`'s per-path-composition hazard (composing per-path invocations
  disagreeing with one multi-path call) is now documented in the library's own header and in the
  authoring contract, closing the authoring half of the defect alongside the mechanical half.

## Follow-ups

- The territory edge this task's own description names (`validate_artifact_corpus_resolution`,
  the deployed-vs-source-store corpus-mismatch escalation mode) remains a separate, disjoint
  defect, unaffected by this fix and not addressed here.
- A future, separately-scheduled invocation of `verify-touched.sh` over this task's modified
  paths (under lower host load than this session's batch) would close out the one verification
  step this task could not complete directly; nothing about this task's own correctness depends
  on it, per the direct evidence already gathered.

## References

- Plan: `specs/564_fix_validateartifactsh_tier_justification_false_po/plans/01_compositional-suite-selection-union.md`
- Report: `specs/564_fix_validateartifactsh_tier_justification_false_po/reports/01_tier-justification-sentinel-domination.md`
- Progress files: `specs/564_fix_validateartifactsh_tier_justification_false_po/progress/phase-{1..5}-progress.json`
- Handoffs: `specs/564_fix_validateartifactsh_tier_justification_false_po/handoffs/phase-{1..5}-handoff-*.md`
