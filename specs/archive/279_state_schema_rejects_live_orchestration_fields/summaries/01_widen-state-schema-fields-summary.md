# Implementation Summary: Task #279

- **Task**: 279 - Reconcile state-schema.json with the live fields the orchestrator reads: rule per field (widen, migrate, or retire), and fix the blockers reader/comment contradiction
- **Status**: [COMPLETED]
- **Started**: 2026-10-02T19:24:20Z
- **Completed**: 2026-10-02T22:20:00Z
- **Effort**: ~3 hours
- **Dependencies**: None (coordinated with tasks 269/271 on shared files; no conflicts observed)
- **Artifacts**: plans/01_widen-state-schema-fields.md, summaries/01_widen-state-schema-fields-summary.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md, shell-strict-mode.md, source-store-deploy-boundary.md

## Overview

Applied the eight-field state-schema ruling from the research report: five fields (`active_goal`,
`blockers`, `previous_status`, `resume_phase`, `researched`) are now modelled in
`context/schemas/state-schema.json` and mirrored into `scripts/validate-state.sh`'s known-field
arrays (`active_goal` was already present from an earlier hand-fix); three top-level fields
(`artifacts`, `metadata`, `last_updated`) are deliberately retired with a consumer-runnable
migration script. Checks 3/4 moved to an advisory-first WARN-by-default posture with a written
promotion criterion. The postflight `blockers` reader/comment contradiction is resolved in the
reader's favor. A pre-existing, unrelated schema/validator drift (`research_questions`) was closed
and is now pinned by a new drift test.

## What Changed

- `agent-system/extensions/core/context/schemas/state-schema.json` — added `blockers` (array of
  strings), `previous_status` (`$ref: taskStatus`), `resume_phase` (integer), `researched`
  (string) to `definitions.projectEntry`, each with writer/reader provenance in its description
- `agent-system/extensions/core/scripts/validate-state.sh` — added the same 4 names plus the
  pre-existing `research_questions` drift fix to `KNOWN_ENTRY_FIELDS`; added a ruled-retired
  comment above `KNOWN_TOP_LEVEL_FIELDS`; moved Checks 3/4 from `log_fail` to `log_warn` with
  actionable messages and PROMOTION CRITERION comment blocks; updated the header's `--strict`
  paragraph and per-check summary
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` — fixed the
  `verdict == "blocked"` branch's `blockers` reader to tolerate both scalar-string and
  array-of-strings shapes (`(.blockers // ["Unspecified blocker"]) | if type == "array" then
  join("; ") else . end`); corrected the sibling branch's false "never written by any script"
  comment
- `agent-system/extensions/core/scripts/orchestrate-triage-classify.sh` — added a one-line
  provenance comment at the `previous_status` read (no behavioral change)
- `agent-system/extensions/core/scripts/migrate-state-legacy-fields.sh` — new, consumer-runnable,
  idempotent migration script: retires the three dead top-level fields and normalizes legacy
  scalar-string `blockers` to arrays, printing every dropped/normalized value before writing;
  writes exclusively through a deployed `state-write.sh`; refuses `specs/archive/state.json` and
  any path outside the invoking repo
- `agent-system/extensions/core/scripts/tests/test-validate-state.sh` — 5 new fixture groups
  (widened-field positive fixture, legacy scalar-blockers tolerance, `research_questions`
  regression guard, retired-fields WARN negative fixture with a `--strict` companion, and the
  schema-to-validator drift test modelled on `test-status-vocabulary.sh`); updated one pre-existing
  fixture ("stray top-level field") whose hard-FAIL expectation was superseded by the Check 3/4
  posture change
- `agent-system/extensions/core/context/reference/state-management-schema.md` — added 4 rows to
  the Project Entry Fields table; added a new "Retired Top-Level Fields" subsection with each
  field's last known value recorded verbatim; added an "Unknown-field enforcement posture" note
- `agent-system/extensions/core/context/patterns/inline-status-update.md`,
  `context/patterns/jq-escaping-workarounds.md` — provenance notes on the stale `resume_phase`/
  `researched` snippets
- `agent-system/extensions/core/context/processes/implementation-workflow.md` — marked superseded
  at its head

## Decisions

- Five fields WIDEN, three fields RETIRE — per the research report's ruling, re-verified against
  the live consumer repo at implementation time; no deviation from the ruling itself.
- `blockers` canonical shape is array of strings; the postflight reader tolerates both shapes
  through the migration window.
- Checks 3/4 advisory-first (WARN by default, `--strict` promotes), matching the existing Checks
  8-11 precedent, with a concrete two-part promotion criterion recorded in-script.
- The pre-existing `research_questions` schema/validator drift (unrelated to the original eight
  fields, discovered while building the plan) was closed in Phase 1 and pinned by the new drift
  test, since it is the identical defect class this task exists to fix.

## Plan Deviations

- **Phase 1, "Add `active_goal`"**: already present in both the schema and the validator (settled
  by hand before this task alongside `deployment_versions`); verified in place rather than
  re-added.
- **Phase 3, Testing & Validation**: one pre-existing fixture ("stray top-level field -> nonzero
  exit") asserted Check 3's now-superseded hard-FAIL behavior. Updated it to assert the new
  default-mode WARN + exit 0, with a new `--strict` companion case preserving the original
  detection intent.
- **Phase 6, task-ref-ok marker**: applied defensively on the `artifacts` row of the Retired
  Top-Level Fields table (quoted legacy consumer-repo data, not a task citation), though the
  write-time gate did not in fact block this specific edit.

## Verification

- Build: N/A (no compiled artifact)
- Tests: `test-validate-state.sh` 35/35 passed (including the new drift test, sanity-checked via a
  negative control); `test-orchestrate-triage-classify.sh` 60/60 passed (no regression from the
  provenance-comment edit)
- Files verified: Yes — every file listed above read and diffed before commit
- `shellcheck` clean (zero NEW findings; every finding present is pre-existing, confirmed via
  `git stash` diff) on all five touched/created scripts
- `check-task-references.sh` reports 0 unexempted occurrences in the touched `context/` and
  `scripts/` subtrees
- End-to-end validated against a scratchpad copy of the real consumer repo's `specs/state.json`
  (`~/Projects/BimodalLogic`): pre-migration 8 PASS/17 WARN/0 FAIL (all four top-level and four
  entry fields either fully resolved or advisory-only); post-migration 9 PASS/14 WARN/0 FAIL with
  only `parent_task` (owned by task 271) remaining. `~/Projects/BimodalLogic` itself was never
  written to (confirmed via `git status`/md5sum before and after).

## Nine-Failure Walkthrough

See the plan's Phase 7 "Nine-Failure Walkthrough" table
(`plans/01_widen-state-schema-fields.md`) for the full per-field resolution mapping. Summary: five
WIDEN (`active_goal`, `blockers`, `previous_status`, `researched`, `resume_phase`), three
RETIRE-with-migration (`artifacts`, `metadata`, top-level `last_updated`), one explicitly out of
scope (`parent_task`, owned by task 271's work item).

## Impacts

- Any consumer repo carrying these eight fields (or the `research_questions` drift) no longer gets
  an unexplained hard FAIL from `validate-state.sh` in default mode.
- A consumer repo owner can now run `migrate-state-legacy-fields.sh` once to permanently clear the
  three legacy top-level fields and normalize `blockers`, with a printed audit trail.
- The `orchestrate-cycle-postflight.sh` blocked-verdict aux signal now renders correctly for both
  `blockers` shapes instead of silently emitting raw JSON for array values.
- Future schema/validator drift of this class is caught immediately by the new drift test rather
  than surfacing as a confusing validator FAIL in some other repo.

## Follow-ups

- `parent_task` remains for task 271 to model, per that task's own file_scope and work item (1);
  271 should re-derive its widening against the shape this task leaves `definitions.projectEntry`
  in (additive, no conflict expected).
- The transitional dual-shape `blockers` reader in `orchestrate-cycle-postflight.sh` is intended to
  be removed once the migration has run broadly enough that no scalar-string `blockers` value is
  expected to appear; the `--strict`-mode fixture in `test-validate-state.sh` makes this transition
  visible (not a removal date commitment).
- Running `migrate-state-legacy-fields.sh` against `~/Projects/BimodalLogic`'s real
  `specs/state.json` is that repo owner's own separate action — deliberately not performed by this
  task.
- Re-deploying the source store to `.claude/` (so the deployed validator reflects these changes) is
  the loader's own action (`<leader>al` / `bash .claude/scripts/deploy-headless.sh`), not part of
  this task.

## References

- `specs/279_state_schema_rejects_live_orchestration_fields/plans/01_widen-state-schema-fields.md`
- `specs/279_state_schema_rejects_live_orchestration_fields/reports/01_state-schema-field-ruling.md`
- `specs/279_state_schema_rejects_live_orchestration_fields/.dispatch/22.md`
