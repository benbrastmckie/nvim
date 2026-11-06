# Implementation Summary: Task #385

- **Task**: 385 - Lean4 plan with zero Lean goals
- **Status**: [COMPLETED]
- **Started**: 2026-11-05
- **Completed**: 2026-11-06
- **Effort**: ~3.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_zero-lean-goals-plan-shape.md
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md

## Overview

Defined and implemented the sanctioned shape for a lean/lean4-typed implementation plan that
commits to no theorem, closing a specification gap where both available shapes (an omitted
section, or a present-but-empty section) collapsed into the same `exit 71` that
`lean-challenge-snapshot.sh` already used for a genuine config error. The mechanism settled on: a
literal, substring-matched marker line `<!-- lean-challenge-statements:none -->` inside a
*present* but block-free `## Lean Challenge Statements` section, recognized by a new internal
`extract_r1` status `3` and reported as a new, dedicated exit code `72`. All five plan phases
completed; the deployed `.claude/` tree was regenerated twice to pick up a registration gap
discovered mid-implementation.

## What Changed

- `agent-system/extensions/lean/scripts/lean-challenge-snapshot.sh` — new `extract_r1` status
  `3` (marker recognized inside a block-free section), new `ROUTE="zero-goal"` resolution arm,
  a three-way `GOALS_FILE` guard branch (zero-goal+empty -> informational exit `72`;
  zero-goal+non-empty -> hard `71` naming the inconsistency; every other route unchanged), and a
  new `72` row in the file-header exit-code block. Every other route (R1 plan-declared, R2
  git-baseline fallback, present-but-empty-without-marker) is byte-for-byte unchanged.
- `agent-system/extensions/core/context/formats/plan-format.md` — new
  `### Zero Lean Goals (no theorem deliverable)` subsection under the existing
  `## Lean Challenge Statements (format, lean/lean4 plans only)` section, stating the marker
  requirement, the "`**Goals**:` must also be empty" requirement, the Decisions-recording
  requirement, and the three contrasts (malformed-empty-section stays `71`, omitted-section
  routes to R2 unchanged, marker is opt-out not default); plus a one-clause pointer on
  numbered-section entry `6.`.
- `agent-system/extensions/lean/context/project/lean4/domain/challenge-snapshot.md` — new `72`
  row in the `## Exit-Code Vocabulary` table (between `71` and `73`), and a new
  `### Zero-Goal Marker` subsection (after `### Fail-loud on partial resolution`) documenting the
  marker mechanics and the settled `--compare`/Comparator disposition (no code change — the
  existing `challenge_missing` advisory already covers a zero-goal plan).
- `agent-system/extensions/lean/scripts/tests/test-lean-challenge-snapshot.sh` — four new
  regression cases `Z1`-`Z4` plus a header comment inventory update; `Z1`/`Z2`/`Z3` cover the
  deliberate no-op, the marker-plus-non-empty-Goals inconsistency, and the (previously
  untested) malformed present-but-block-free-and-marker-free section respectively; `Z4` is the
  anti-vacuity assertion pinning that `Z1`'s `72` and `Z3`'s `71` stay distinct.
- Three new fixtures under `agent-system/extensions/lean/scripts/tests/fixtures/challenge/`:
  `plan_zero_goal_marker.md`, `plan_zero_goal_marker_with_goals.md`,
  `plan_empty_section_no_marker.md`.
- `agent-system/extensions/lean/manifest.json` — registered the three new fixtures in
  `provides.scripts` (discovered missing during Phase 5's redeploy verification; without this,
  the deploy silently skipped copying them).
- `agent-system/extensions/lean/index-entries.json` — synced `challenge-snapshot.md`'s
  `line_count` (188 -> 221).
- `specs/state.json` — widened task 385's `file_scope` by two entries
  (`agent-system/extensions/lean/manifest.json`, `agent-system/extensions/lean/index-entries.json`)
  to admit the registration/sync fix above through the scoped-commit containment check.
- Regenerated deployed `.claude/` tree (twice — see Plan Deviations).

## Decisions

- The marker substring check is placed inside `extract_r1`'s existing `if not blocks:` branch,
  tested before the current stderr/`exit(2)` path — a miss leaves the malformed-section message
  and `exit(2)` byte-for-byte unchanged.
- The three-way `GOALS_FILE` branch preserves the guard's original position strictly before
  `cross_validate_identifiers`, keeping every non-zero-goal route's message and exit value
  unchanged.
- `**Goals**:` must also be empty for the marker to take effect; marker-plus-non-empty-Goals is
  a hard `71` self-inconsistency, never the new `72`.

## Plan Deviations

- Phase 5: Phase 4's three new fixtures were not registered in
  `agent-system/extensions/lean/manifest.json`'s `provides.scripts`, so the first
  `deploy-headless.sh` run did not deploy them. Discovered via `check-extension-docs.sh`'s
  post-deploy completeness check; fixed by adding the three entries and running the deploy a
  second time, which deployed them correctly. See `progress/phase-5-progress.json`'s
  `deviations` array.
- Phase 5's "run the full gate set" task item was discharged under this dispatch's Batch Gate
  Deferral directive (this task shares its `/orchestrate` batch cycle with concurrently-dispatched
  task 29) rather than independently run to a fully clean `verify-deploy.sh`. Scoped checks
  (`--only-gate 3,4`, plus a full `check-extension-docs.sh` read) confirmed every remaining
  doc-lint failure is independently attributable to either pre-existing, unrelated repo drift or
  task 29's own declared-scope in-flight work — none to this task's own touched files. The
  complete gate set is deferred to the batch stage, per the dispatch's directive.
- The `agent-system/extensions/lean/manifest.json` and `index-entries.json` registration/sync
  fixes required widening task 385's declared `file_scope` (two entries added) before the
  scoped-commit containment check would admit them — both files were untouched by any other
  task's declared scope at commit time.

## Verification

- Build: N/A (shell script + markdown; no compile step).
- Tests: `bash agent-system/extensions/lean/scripts/tests/test-lean-challenge-snapshot.sh` — 37
  passed, 0 failed, 0 skipped (33 pre-existing cases + new `Z1`-`Z4`). Confirmed identical against
  the deployed copy (`bash .claude/scripts/tests/test-lean-challenge-snapshot.sh`) after redeploy.
  Two deliberate temporary mutations were run and reverted during Phase 4, confirming `Z1`/`Z4`
  go RED under each while `R21` stays green (new cases are not vacuous).
- Files verified: Yes — all planned files modified/created; marker literal confirmed
  byte-for-byte identical across the script, `plan-format.md`, and `challenge-snapshot.md`, in
  both the source store and the deployed copies.
- `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4` plus a full
  `check-extension-docs.sh` read: zero remaining failures attributable to this task (see Plan
  Deviations). The complete gate set is deferred to the batch stage per the dispatch's directive.

## Impacts

- A lean4-typed plan with no theorem deliverable now has one sanctioned, mechanically-checkable
  shape, distinguishable from a malformed section by exit-code value (`72` vs `71`) rather than by
  stderr-text parsing or omission convention.
- `--compare`/Comparator behaviour for such a plan is unchanged by design: no manifest is ever
  produced, so the existing advisory `challenge_missing` preflight verdict already covers it.
- Ordinary lean4 plans (R1 plan-declared, R2 git-baseline fallback) are completely unaffected —
  every pre-existing route's exact message and exit code is preserved byte-for-byte.

## Follow-ups

- Pre-existing, out-of-scope `provides.scripts` registration gaps were observed in
  `agent-system/extensions/lean/manifest.json` for fixtures `plan_r18_paren_goals.md`,
  `plan_r19_multiline_paren_goals.md`, `plan_r20_non_goals_only.md`, `plan_r21_empty_goals.md`,
  and for `lean-plan-compliance-check.sh`/`tests/test-lean-plan-compliance-check.sh`. None are
  touched by this task and none were introduced by it; left unfixed as genuinely out of this
  task's declared scope. Worth a small follow-up task to run
  `bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --write` and review the
  result.
- The already-documented, pre-existing gap (the `74` exit code is in the script header but
  missing from `challenge-snapshot.md`'s Exit-Code Vocabulary table) remains unaddressed, as
  explicitly scoped out by this plan's Non-Goals.

## References

- Plan: `specs/385_lean4_plan_with_zero_lean_goals/plans/01_zero-lean-goals-plan-shape.md`
- Report: `specs/385_lean4_plan_with_zero_lean_goals/reports/01_zero-lean-goals-plan-shape.md`
- Progress files: `specs/385_lean4_plan_with_zero_lean_goals/progress/phase-{1..5}-progress.json`
- Handoffs: `specs/385_lean4_plan_with_zero_lean_goals/handoffs/phase-{1..5}-handoff-*.md`
