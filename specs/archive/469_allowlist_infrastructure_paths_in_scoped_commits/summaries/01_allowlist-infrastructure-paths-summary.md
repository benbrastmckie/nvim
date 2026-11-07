# Implementation Summary: Task #469

- **Task**: 469 - Allowlist engine-written infrastructure paths in the file_scope Containment sites
- **Status**: [COMPLETED]
- **Started**: 2026-11-05T06:36:02Z
- **Completed**: 2026-11-05T08:58:00Z
- **Effort**: ~2.5 hours
- **Dependencies**: None (concurrent-territory serialization note only)
- **Artifacts**: plans/01_allowlist-infrastructure-paths.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

The file_scope Containment predicate was checked at three independent sites, two of which
hand-copied the same two-literal allowlist (`specs/TODO.md`, `specs/state.json`) and one of
which carried no allowlist at all, so `specs/events.jsonl` (and other engine-written state) was
silently dropped from any commit pathspec that named it. This implementation created one
canonical shared library (`scripts/lib/engine-written-state-paths-lib.sh`) defining the
four-member engine-written-state path set, migrated both existing hand-copied splices to source
it, added the net-new splice at the third site, recorded the landing in the standard, pinned the
new behavior with per-site paired admission/non-regression fixtures, and verified the fix
end-to-end with a real redeploy and an observed `specs/events.jsonl` commit.

## What Changed

- `agent-system/extensions/core/scripts/lib/engine-written-state-paths-lib.sh` — Created. Single
  canonical definition exporting `engine_written_state_paths`, printing
  `["specs/TODO.md","specs/state.json","specs/events.jsonl","specs/errors.json"]`, with the
  admission bar and rejected-candidate reasoning recorded in its header.
- `agent-system/extensions/core/scripts/tests/test-engine-written-state-paths-lib.sh` — Created.
  10 assertions covering shape, exact membership, the membership-creep tripwire, and
  source-time idempotence/silence.
- `agent-system/extensions/core/scripts/git-commit-scoped.sh` — V10's `containment_scope_arr`
  splice migrated from the hand-copied literal pair to a defensive source of the shared library,
  with a two-literal fallback on source/resolution failure (Decision 2).
- `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` — Added Z15 (positive:
  `specs/events.jsonl`), Z16 (positive: `specs/errors.json`), Z17 (paired negative,
  non-regression), Z18 (fallback). Added the shared library to `REQUIRED_SCRIPTS` so fixtures
  actually source it.
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` — WORK (h)'s
  `effective_file_scope_json` splice migrated to source the shared library (unconditionally at
  the top, matching `derived-artifact-probe-lib.sh`'s own convention), with the Decision 2
  fallback implemented at the call site.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` — Added an
  "Engine-written-state allowlist" fixture block (candidate #719) with 8 assertions: admission
  (no ADVISORY, no EXCURSION DROPPED, present in commit) paired with a genuine excursion still
  caught in the same run.
- `agent-system/extensions/core/scripts/git-commit-phase.sh` — Net-new `file_scope_arr` splice
  added inside the existing non-empty guard (this site previously carried zero allowlist), with
  the same shared-library source and Decision 2 fallback. The untouched fixed `stage_paths` seed
  got a one-line comment distinguishing it from the new, tested splice.
- `agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh` — Added Case 13
  (positive admission of `specs/events.jsonl`/`specs/errors.json` paired with a genuine-excursion
  non-regression assertion in the same fixture) and Case 14 (fail-open re-assertion).
- `agent-system/extensions/core/context/standards/git-staging-scope.md` — "Three Containment
  sites, not one" amended to state all three sites now share one definition. The former "Site 1
  carries its own engine-written-state allowlist" paragraph retitled and rewritten around the
  shared library, its four members, the admission bar, the Decision 2 fallback, and the Non-Goal
  (never added to any `stage_paths` seed).
- `agent-system/extensions/core/manifest.json` and `agent-system/extensions/core/index-entries.json`
  — Fixed on disk (via sanctioned mechanical repair scripts) to register the two new files and
  correct a `line_count` entry, but deliberately left UNCOMMITTED by this task (outside its
  declared `file_scope`; `index-entries.json`'s diff is also entangled with unrelated sibling
  tasks' own pending fixes). See Plan Deviations and Follow-ups below.

## Decisions

- **Consolidation verdict**: one canonical shared library (not three independently-maintained
  hand-copied lists), modelled on `derived-artifact-probe-lib.sh`'s proven shape.
- **Membership verdict**: `specs/TODO.md`, `specs/state.json`, `specs/events.jsonl`,
  `specs/errors.json` — and nothing wider. `specs/CHANGE_LOG.md`, `specs/ROADMAP.md`,
  `specs/README.md`, and any task-owned `specs/{NNN}_*/` path were each considered and rejected
  against the admission bar (engine-written on behalf of every/many tasks AND never legitimately
  declarable in any one task's own `file_scope`).
- **Fallback (Decision 2)**: every consumer falls back to the hardcoded two-literal pair on a
  source or resolution failure, so a library failure reproduces each site's pre-shared-library
  behavior exactly rather than narrowing it. Pinned by a dedicated fixture at each migrated site.
- **Staging-side verdict**: no staging-side fix was needed — the defect was confined to the
  predicate's allowlist, confirmed by Phase 6's real end-to-end observation.

## Plan Deviations

- **Task 2.5** (altered): Added `lib/engine-written-state-paths-lib.sh` to
  `test-git-commit-scoped.sh`'s `REQUIRED_SCRIPTS` array and chmod-exclusion lists — not an
  explicit plan bullet, but required so fixture repos actually have the library to source.
- **Task 3.3** (altered): Decision 2's fallback for Site 1 is implemented entirely at the WORK
  (h) call site, not at the (unconditional, sibling-matching) top-level source line — an
  unconditional source cannot itself express a fallback on a missing file.
- **Task 3-suite** (deferred): `test-orchestrate-cycle-postflight.sh`'s 25 pre-existing,
  unrelated `[FAIL]` assertions (confirmed via byte-identical pre-edit comparison) are left
  unfixed — out of this task's scope — and recorded in the issue log.
- **Task 5-infra** (altered): `manifest.json` (+2 `provides.scripts` entries) and
  `index-entries.json` (one `line_count` correction) were fixed on disk via sanctioned mechanical
  repair scripts so gate 3 reads cleanly, but deliberately left uncommitted by this task — both
  are outside its declared `file_scope`, and `index-entries.json`'s diff is entangled with
  unrelated sibling tasks' own pending fixes already present before this task touched the file.
- **Task 6-gate8** (deferred): the complete, un-narrowed gate set (`verify-deploy.sh` with every
  gate, including gate 8's full `tests/run-all.sh`) was deferred to the batch-level stage per the
  dispatch's own Batch Gate Deferral directive (this plan's final phase declares `Verification
  Tier: full`). `deploy-headless.sh`'s own internal `--skip-slow` call already covered gates
  1-7, 9-25 (38 checks, 0 failures) as a side effect of the redeploy.

## Verification

- Build: N/A (shell scripts and markdown; no build step)
- Tests: `test-engine-written-state-paths-lib.sh` (10/10), `test-git-commit-scoped.sh` (70/70),
  `test-orchestrate-cycle-postflight.sh` (279 passed / 25 pre-existing, unrelated failures —
  confirmed via byte-identical pre-edit comparison), `test-git-commit-phase.sh` (24/24). All
  three non-tautology sanity probes (temporarily widening the library and observing the paired
  negative go red) passed.
- Files verified: Yes — redeploy reached `RESULT=landed_verify_clean`; all three deployed sites
  plus the deployed library confirmed present via `grep`; a real commit (`98968cfab9`) carrying
  a genuine 2462-line `specs/events.jsonl` delta (spanning 111 distinct task numbers) was
  observed with no drop warning and no new `scope excursion` issue entry.

## Impacts

- A fifth future infrastructure path now costs one edit in one file
  (`engine-written-state-paths-lib.sh`), not three independent hand-copied splices.
- `specs/events.jsonl` and `specs/errors.json` are no longer silently dropped from any commit
  pathspec that names them, at any of the three Containment sites.
- The drop-and-warn posture for a genuine out-of-scope path is unchanged and freshly pinned at
  all three sites by paired non-regression fixtures.

## Follow-ups

- Commit `agent-system/extensions/core/manifest.json` and `index-entries.json`'s already-on-disk
  fixes (the two `provides.scripts` entries and the `line_count` corrections) — deliberately
  left uncommitted by this task; see Plan Deviations (task 5-infra) for the full reasoning. A
  future commit (by this batch's postflight, or a subsequent task) should pick these up rather
  than leaving them stranded.
- `test-orchestrate-cycle-postflight.sh`'s 25 pre-existing, unrelated `[FAIL]` assertions remain
  unfixed (out of this task's scope); recorded in the issue log (class "pre-existing test
  failure", severity costly) for separate triage.
- The source-store-wide `stage_paths=("${task_dir}/" "specs/TODO.md" "specs/state.json" ...)`
  migration across per-extension implementation agents remains separately-scoped follow-up
  ground, as `git-staging-scope.md`'s own "Scope of the `git-commit-phase.sh` migration"
  paragraph already records (unchanged by this task).

## References

- Plan: `specs/469_allowlist_infrastructure_paths_in_scoped_commits/plans/01_allowlist-infrastructure-paths.md`
- Research report: `specs/469_allowlist_infrastructure_paths_in_scoped_commits/reports/01_allowlist-infrastructure-paths.md`
- Standard landing: `agent-system/extensions/core/context/standards/git-staging-scope.md`
- Per-phase progress files and handoffs:
  `specs/469_allowlist_infrastructure_paths_in_scoped_commits/progress/phase-{1..6}-progress.json`,
  `specs/469_allowlist_infrastructure_paths_in_scoped_commits/handoffs/`
