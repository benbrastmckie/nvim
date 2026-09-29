# Implementation Summary: Task #162

- **Task**: 162 - Formalize "Files to modify" and harvest file_scope
- **Status**: [COMPLETED]
- **Started**: 2026-09-28T23:00:00Z
- **Completed**: 2026-09-29T06:00:00Z
- **Effort**: ~6.75 hours (estimate held)
- **Dependencies**: None
- **Artifacts**: plans/01_files-to-modify-harvest.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Formalized the already-universal `**Files to modify**:` per-phase plan convention in
`plan-format.md`, built `plan-file-scope-harvest.sh` to union every phase's list into a
deduplicated JSON array, and wired that harvest into every live plan-postflight call site
(including a fifth, previously-unnamed site discovered during implementation) so
`state.json`'s `active_projects[].file_scope` is now populated at plan time. A one-shot,
idempotent, cross-repo-capable backfill script (`backfill-file-scope.sh`) closed the historical
gap for existing plan-bearing tasks, run for real against both this repo (a legitimate no-op)
and `~/Projects/BimodalLogic` (7 tasks backfilled, left uncommitted for user review).

## What Changed

- `agent-system/extensions/core/context/formats/plan-format.md` — added `**Files to modify:**`
  as a required per-phase field with its grammar (both punctuation forms, both the bare and
  list-item-wrapped header rendering, description-stripping, continuation-line tolerance), a
  "Consumers of this field" subsection, and a Scope-Hypothesis-is-not-a-harvest-source
  cross-reference.
- `agent-system/extensions/core/scripts/plan-file-scope-harvest.sh` (new) — the sole harvester:
  one positional plan-file argument, JSON array on stdout, non-zero reserved for usage errors
  only. Tolerates both punctuation forms and the list-item-wrapped field rendering discovered
  during Phase 2.
- `agent-system/extensions/core/scripts/tests/test-plan-file-scope-harvest.sh` (new) — 17
  assertions covering every grammar case.
- `agent-system/extensions/core/scripts/update-task-status.sh` — widened `--file-scope-add`'s
  restriction from `research`-only to `{research, plan}`.
- `agent-system/extensions/core/scripts/tests/test-update-task-status.sh` — added cases 11g/11h
  covering the widened restriction.
- `agent-system/extensions/core/scripts/orchestrator-postflight.sh` — added a `plan` harvest
  branch (this script is orphaned with no live callers; see Decisions).
- `agent-system/extensions/core/scripts/reconcile-task-status.sh` — added a shared
  `harvest_file_scope_args()` helper, wired at both `postflight ... plan ...` replay sites.
- `agent-system/extensions/core/skills/skill-reviser/SKILL.md` — Stage 7 now harvests and
  forwards `--file-scope-add`, so `/revise` re-harvests.
- `agent-system/extensions/core/scripts/skill-base.sh` — **the fifth, actually-live site**:
  widened `skill_postflight_update()`'s `_fsa_args` gate to also harvest on `operation=="plan"`,
  resolving the latest plan file from `${_task_dir}/plans/*.md`.
- `agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh` — added Group 4a
  (two new cases: positive harvest, plan-less-stays-absent) and added
  `plan-file-scope-harvest.sh` to `build_fixture_repo()`'s required-scripts list.
- `agent-system/extensions/core/scripts/backfill-file-scope.sh` (new) — one-shot, idempotent,
  `--dry-run`/`--state-file`-capable backfill, calling the harvester as a subprocess and writing
  through `state-write.sh` with a single batched jq filter.
- `agent-system/extensions/core/scripts/tests/test-backfill-file-scope.sh` (new) — 13 assertions
  covering dry-run/real-run/idempotence/never-overwrite/plan-less.
- `agent-system/extensions/core/manifest.json` — added `plan-file-scope-harvest.sh`,
  `backfill-file-scope.sh`, and their test files to `provides.scripts`.
- Regenerated `.claude/**` deploy tree (six deploys during this task; final state clean, 33/33
  verify-deploy checks).
- `~/Projects/BimodalLogic/specs/state.json` — 7 tasks backfilled with `file_scope`, left
  **uncommitted** for the user to review and commit (Decision 8).

## Decisions

1. **Union, not overwrite.** Every write is additive; never subtractive, never a replacement.
2. **A plan revision re-harvests.** All four (now five) plan-postflight call sites re-run the
   harvest on every invocation, including `/revise` and reconciliation self-heal.
3. **Harvest failure is a loud non-fatal warning, never fatal to postflight.** Verified via a
   real induced failure (chmod 000 plan file) at the orchestrator-postflight.sh logic pattern:
   warning printed, exit 0 reached.
4. **The field is documented required; validator gating is deferred** (explicit Non-Goal).
5. **`**Scope Hypothesis**:` does not inform the harvest** — cross-referenced in plan-format.md.
6. **Plan-less tasks: leave `file_scope` absent**, never `[]`, never inferred. The backfill
   reports this population by count rather than silently skipping it.
7. **The backfill is cross-repo capable via `--state-file`**, repo root derived from that path.
8. **A cross-repo real run leaves the target repo uncommitted** — confirmed:
   `~/Projects/BimodalLogic/specs/state.json` is modified but not committed by this task.

## Plan Deviations

- **Phase 2**: discovered a fourth grammar wrinkle beyond the research report's three — a
  per-phase field (including `Files to modify`) may be rendered as its own top-level list item
  (`- **Files to modify**:`) with indented (`  - \`path\``) entries. This is a SANCTIONED
  rendering (`plan-format.md`'s own compact example template already uses it), found via a real
  local plan (`specs/207_fix_zotero_export_path1_truncation`). Fixed by widening the harvester's
  header/entry/field-label-terminator detection to tolerate an optional leading list marker, with
  a dedicated negative test proving the following field's own sub-bullets don't leak in as bogus
  paths.
- **Phase 3**: an interim `deploy-headless.sh` run was needed mid-phase (not deferred entirely to
  Phase 6), because `test-update-task-status.sh` always builds its fixture from the DEPLOYED
  tree. This surfaced an unrelated doc-lint FAIL (Phase 2's two new files missing from
  `manifest.json`'s `provides.scripts`), fixed immediately.
- **Phase 4 (major)**: the dispatch's four named call sites turned out to be incomplete.
  `orchestrator-postflight.sh` — one of the four — was confirmed **orphaned with zero live
  callers** (its own header note, corroborated by `skills/skill-git-workflow/SKILL.md`'s
  "Relationship to orchestrator-postflight.sh" section). The actually-live plan-postflight path
  for both `/orchestrate` engines is `skill_postflight_update()` in `skill-base.sh`. This fifth
  site was found and wired, with two new fixture-based tests. Without this correction, the whole
  phase's harvest would never have fired for a real `/orchestrate` plan-postflight run.
- **Phase 4**: `reconcile-task-status.sh`'s two call sites share one `harvest_file_scope_args()`
  helper rather than duplicating the harvest-and-degrade logic inline twice.
- **Phase 5**: found and fixed a real jq bug while writing the test suite — a batched
  `map(if ($updates | has(.project_number|tostring)) ...)` filter silently no-ops, because a jq
  function argument is evaluated against the function's own input, not the outer `map(.)` item.
  Fixed via `. as $item | ...`.
- **Phase 6**: corrected `plan-format.md`'s "Consumers of this field" subsection from four
  consumers to three — `skill-orchestrate/SKILL.md` no longer independently carries the
  "Files to modify" heading dependency (pre-existing, unrelated refactor collapsed its own H1
  territory block into `orchestrate-cycle-plan.sh`). Documentation-accuracy fix only; the heading
  string itself is unbroken and this task made zero edits to any of the three named files.

## Verification

- Build: N/A (no compiled artifacts)
- Tests: 133/133 assertions passed across 5 suites (`test-plan-file-scope-harvest.sh` 17/17,
  `test-update-task-status.sh` 32/32, `test-backfill-file-scope.sh` 13/13,
  `test-skill-base-lifecycle.sh` 38/38, `test-force-phases.sh` 33/33 — the latter two included
  because Phase 4's fifth-site fix touched shared `skill-base.sh`)
- Files verified: Yes — `shellcheck` clean on every new/changed shell file (only pre-existing,
  codebase-wide info-level notices, none introduced by this task's diffs)
- `check-task-references.sh --quiet`: PASS, 0 unexempted occurrences
- `verify-deploy.sh`: PASS, 33/33 checks, final deploy clean

## Coverage (actual, superseding plan-time/dispatch-time estimates)

| Repo | Before | After | Backfilled |
|------|--------|-------|------------|
| This repo (`/home/benjamin/.config/nvim`) | 29/30 | 29/30 | 0 (legitimate no-op; the one uncovered task, 268, has no plan) |
| `~/Projects/BimodalLogic` | 29/64 | 36/64 | 7 |

`~/Projects/BimodalLogic/specs/state.json` is left **uncommitted** for the user's own review and
commit (Decision 8) — this task never commits inside another repository.

## Impacts

- Every future `/plan` (and `/revise`, and reconciliation self-heal) call now populates
  `file_scope` automatically, closing the gap the collision guard and territory contracts have
  relied on being closed.
- `backfill-file-scope.sh` is reusable for any other sibling repo with the same gap.
- One BimodalLogic task (410) has a plan but harvested nothing — flagged, not investigated
  further (out of this task's scope; worth a follow-up if that repo's plan corpus has its own
  grammar variant).

## Follow-ups

- Investigate BimodalLogic task 410's empty harvest (possibly a lean-specific plan-format
  variant not attested locally).
- The user should review and commit `~/Projects/BimodalLogic/specs/state.json`'s backfilled
  `file_scope` entries at their convenience.
- `scripts/validate-artifact.sh` promotion to enforce the required field (explicit Non-Goal here,
  per plan-format.md's advisory-first-then-promote staging).

## References

- Plan: `specs/162_formalize_files_to_modify_and_harvest_file_scope/plans/01_files-to-modify-harvest.md`
- Research: `specs/162_formalize_files_to_modify_and_harvest_file_scope/reports/01_files-to-modify-harvest.md`
- Progress files and phase-end handoffs under
  `specs/162_formalize_files_to_modify_and_harvest_file_scope/{progress,handoffs}/`
