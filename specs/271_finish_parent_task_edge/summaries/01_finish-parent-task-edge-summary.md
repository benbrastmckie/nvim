# Implementation Summary: Task #271

- **Task**: 271 - Finish the parent_task edge: declare it in the schema, validate it, render it
  in TODO, and make it survive renumbering
- **Status**: [COMPLETED]
- **Started**: 2026-10-08T06:52:11Z
- **Completed**: 2026-10-08T07:43:03Z
- **Effort**: ~6 hours (matches plan estimate)
- **Dependencies**: None (the footprint-serialization edge on the null-safety fix task over
  `scripts/validate-state.sh` was dropped per the standing convention, as that task never
  stalled against this one)
- **Artifacts**: plans/01_finish-parent-task-edge.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md,
  shell-strict-mode.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md

## Overview

`active_projects[].parent_task` was a half-built field: two producers wrote it but zero
consumers read it -- undeclared in the schema, unchecked by the validator, unrendered in
TODO.md, and undocumented. This implementation finishes the edge end to end: declares the field
in `state-schema.json` with an explicit lineage-not-dependency contract, documents it in
`state-management-schema.md`, adds three advisory-first validator findings (self-parent, orphan,
cycle) to `validate-state.sh` with a written promotion criterion, renders it as a per-task
TODO.md line (never in the Task Order tree, by deliberate ruling), fixes a pre-existing
underscore-deleting renderer defect folded in from the dispatch, and settles renumber survival on
the live `commands/todo.md` checklist while keeping the deprecated `vault-operation.sh`
quarantined. All 8 plan phases closed; Phase 8 closed `[COMPLETED WITH EXCLUSIONS]` over 5
gate findings confirmed, with evidence, to belong to concurrent sibling tasks rather than this
one.

## What Changed

- `agent-system/extensions/core/context/schemas/state-schema.json` -- declared `parent_task` as
  an optional entry-level integer immediately after `dependencies`, with a description stating
  it is a lineage pointer, not a dependency edge, and that the convention is omit-the-key, never
  `null`.
- `agent-system/extensions/core/scripts/validate-state.sh` -- mirrored `parent_task` into
  `KNOWN_ENTRY_FIELDS`; added a new Check D6 block (self-parent, orphaned-parent, cyclic-parentage,
  all advisory `WARN`, `--strict` promotes) with a written PROMOTION CRITERION; updated the
  `--deep mode additionally checks:` header enumeration and the `--strict` exit-blocking-checks
  list.
- `agent-system/extensions/core/scripts/generate-task-order.sh` -- changed `build_graph()`'s
  underscore markup-strip from deletion (`gsub("_"; "")`) to escaping (`gsub("_"; "\_")`), closing
  the pre-existing "parenttask" rendering defect without reintroducing the emphasis hazard the
  original strip guarded against.
- `agent-system/extensions/core/context/reference/state-management-schema.md` -- added a
  `### Parent Task Field` section: field table, the non-dependency contrast paragraph, advisory
  validation bullets, the Format Conversion table, the Task-Order-tree exclusion rationale, and a
  "Renumber survival" paragraph recording the quarantine ruling on `vault-operation.sh`.
- `agent-system/extensions/core/scripts/generate-todo.sh` -- added `parent_task` as a trailing
  field in the single full-file jq pass, a trailing positional unpack, and a trailing
  `generate_task_entry()` parameter, rendering `- **Parent**: Task {N}` immediately after
  `- **Dependencies**:` only when non-empty.
- `agent-system/extensions/core/commands/todo.md` -- added a new checklist item to Step 5.7.7
  ("Update `parent_task` values") between "Update dependencies arrays" and "Rename task
  directories", so a vault renumbering operation rewrites parentage edges the same way it already
  rewrites dependency edges.
- `agent-system/extensions/core/scripts/tests/test-generate-task-order.sh` -- new underscore-
  survival case (1d, fixture 913) asserting the escape-not-delete behavior and the
  budget/word-boundary invariant; updated the `has_markup_hazard()` helper's comment to record
  the delete-vs-escape distinction.
- `agent-system/extensions/core/scripts/tests/test-validate-state.sh` -- 7 new Check D6 cases
  (clean parentage with status-combination regression guard, archived parent, orphan plus
  `--strict`, self-parent, two-node and three-node cycles each asserting non-hang via `timeout
  10`); fixed a pre-existing `SCHEMA_CANDIDATES` deploy-first ordering bug in the schema/validator
  drift test, discovered while verifying Phase 1.
- `specs/TODO.md` -- regenerated during Phase 8 to resync with the deployed renderer's escape fix
  (superseded by a concurrent sibling's own independent regen landing the identical byte-for-byte
  content before this task's own commit).

## Decisions

- Parentage renders only in the per-task TODO.md entry, never in the Task Order tree:
  `generate-task-order.sh`'s indentation channel is already pre-committed to *dependency*
  semantics by its own display strings, and overloading it with a second relation would make
  every indent ambiguous.
- An archived parent is expected, settled lineage, not an orphan finding -- the orphan check's
  known-number set unions `active_projects` with the sibling `archive/state.json`'s terminal
  arrays, mirroring the existing `dependencies` dangling-reference precedent.
- Self-parent edges are excluded from the cycle-walk's chain map entirely (not merely detected
  and skipped), so a self-parent produces exactly one WARN, never two.
- The deprecated `scripts/deprecated/vault-operation.sh` stays quarantined; the live renumber
  checklist in `commands/todo.md` Step 5.7.7 is the one and only edit target for renumber
  survival.
- Phase 8 closed `[COMPLETED WITH EXCLUSIONS]`: `verify-deploy.sh` reported 6 failing gates, one
  of which (TODO.md sync) was this task's own responsibility and was repaired; the other 5 were
  confirmed, with evidence, to belong to concurrent sibling tasks' file_scope and were recorded
  as reasoned exclusions rather than silently ignored.

## Plan Deviations

- **Task 1.4** altered: fixed a pre-existing `SCHEMA_CANDIDATES` deploy-first ordering bug in
  `test-validate-state.sh`'s drift test (inconsistent with the sibling `WIDEN_VALIDATOR_CANDIDATES`
  in the same block), discovered when it produced a false drift FAIL after editing only the
  source store.
- **Task 4.8** altered: discovered and worked around a bash 5.3 `set -u` gotcha -- a bare
  `declare -A arr` that never receives an element throws "unbound variable" on a later
  `"${#arr[@]}"` reference. Fixed by initializing the two new D6 associative arrays with an
  explicit `=()`.
- **Task 5** (verification step): strengthened the `--strict` orphan-promotion test case to
  assert the orphan-specific WARN text, not just the overall exit code, after discovering the
  original assertion was vacuous against an unrelated WARN on the minimal fixture.
- **Phase 8** (verification step): closed `[COMPLETED WITH EXCLUSIONS]` rather than plain
  `[COMPLETED]` -- see the plan's own `#### Reasoned Exclusions` table for the full, evidenced
  accounting of the 5 gate findings excluded as belonging to concurrent sibling tasks, plus the
  one (TODO.md sync) that was this task's responsibility and was repaired within the phase.

## Verification

- Build: N/A (no compiled artifact)
- Tests: Passed -- `test-validate-state.sh` 45/45, `test-generate-task-order.sh` 18/18 (both
  invoked directly, never through the shared `run-all.sh` runner)
- Files verified: Yes -- shellcheck clean on all 6 touched shell scripts (no new finding
  relative to the Phase 1 baseline; strict-mode classes unchanged); `check-task-references.sh`
  reports 0 occurrences on all 8 touched files individually; `jq empty` confirms the schema JSON
  parses; the bidirectional schema-to-validator drift test passes

## Impacts

- A future `/task --review` follow-up or `/spawn`-created task recorded with `parent_task` is
  now schema-valid, validated for orphan/self/cycle integrity, visible in its TODO.md entry, and
  survives a vault renumbering operation.
- The deployed consumer repo's six live `parent_task` entries (recording real expansion lineage
  from a parent task that is itself still active there) become schema-valid the next time that
  repo deploys, with **no data change, no backfill performed, and no non-null value deleted
  anywhere** -- satisfying the sibling schema task's hard constraint trivially, since this task
  never writes, alters, or deletes any `parent_task` value in any repo. The six entries were
  evidence gathered read-only from that separate repository; it was never an edit target.
- The "parenttask" Task Order rendering defect (and the identical underscore-deletion defect for
  any other underscored title, e.g. `file_scope`/`modified_files`) is now fixed for every
  affected task, not just this one.

## Follow-ups

- The written PROMOTION CRITERION for the three new Check D6 findings specifies two measurable
  conditions (two consecutive zero-finding live measurements, plus one real vault operation
  surviving the new renumber sub-step) before they move from advisory `WARN` to blocking `FAIL`.
  No action is needed now; a future audit should re-check this criterion once those conditions
  plausibly hold.
- The deployed `.claude/` tree was not redeployed this cycle (by design -- four concurrent
  sibling tasks share the working tree). The operator's next `deploy-headless.sh` run will pick
  up all of this task's changes atomically.

## References

- Plan: `specs/271_finish_parent_task_edge/plans/01_finish-parent-task-edge.md`
- Research report: `specs/271_finish_parent_task_edge/reports/01_parent-task-edge-contract.md`
- Progress files: `specs/271_finish_parent_task_edge/progress/phase-{1..8}-progress.json`
- Handoffs: `specs/271_finish_parent_task_edge/handoffs/phase-{1..8}-handoff-*.md`
