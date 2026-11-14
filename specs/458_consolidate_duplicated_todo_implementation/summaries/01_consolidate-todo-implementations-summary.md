# Implementation Summary: Task #458

- **Task**: 458 - consolidate_duplicated_todo_implementation
- **Status**: [COMPLETED]
- **Started**: 2026-11-14T06:55:52Z
- **Completed**: 2026-11-14T12:20:00Z
- **Effort**: ~5.5 hours
- **Dependencies**: None live (459 complete; 626 depends on this task)
- **Artifacts**: plans/01_consolidate-todo-implementations.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Collapsed the two divergent `/todo` implementations into one authoritative implementation,
`agent-system/extensions/core/commands/todo.md`, by removing `skills/skill-todo/SKILL.md`
outright (1027 lines, never dispatched by either consumer system) together with every
mechanical registration (manifest.json, lint allowlist, test subject, deployed copy,
`.claude-extensions.json`) and reconciling every remaining prose/comment reference. Fixed the
`archived_projects`-blind orphan/misplaced-directory detection bug once, in the survivor, across
all three read-back scans, pinned by a new behavioral+static regression suite with a positive
case and a negative control. Net result: a reduction of 945 lines across the 22 source paths
this task touched (13978 -> 13033), a clean redeploy, and a scoped gate run confirming every
gate the plan names is green except gate 8's pre-existing, confirmed-unrelated findings.

## What Changed

- `agent-system/extensions/core/commands/todo.md` — all three read-back jq filters (orphans-in-specs,
  orphans-in-archive, misplaced-directory scan) switched from `.completed_projects[]` to
  `(.completed_projects + .archived_projects)[]`; the archive-WRITE jq and vault count/reinit
  sites left untouched (already correct).
- `agent-system/extensions/core/scripts/tests/test-todo-archived-projects-scan.sh` — Created.
  New regression suite: behavioral half (fixed-filter positive case + pre-fix-filter negative
  control against a two-entry fixture) plus a static half asserting zero remaining bare
  read-back filters and exactly three fixed-filter sites.
- `agent-system/extensions/core/scripts/tests/suite-classification.data` — one new `unit` row
  for the new suite.
- `agent-system/extensions/core/manifest.json` — `skill-todo` removed from `extension.skills[]`;
  `tests/test-todo-archived-projects-scan.sh` added to `provides.scripts` (a plan gap found and
  closed in Phase 2 — without it the deploy copier never deployed the new test file).
- `agent-system/extensions/core/skills/skill-todo/SKILL.md` — Deleted (1027 lines).
- `agent-system/extensions/core/scripts/lint/lint-state-writer-boundary.sh` — `skill-todo`
  exemption-registry entry removed.
- `agent-system/extensions/core/scripts/tests/test-todo-move-pair-staging.sh` — Stage 15 shape
  (subject resolution, behavioral pair, static half, header bullets) removed; header rewritten
  to describe a single surviving recipe. 24/24 cases pass with the three surviving site shapes
  (Step 5D/5E.1/5F) and their negative controls intact.
- `.claude-extensions.json` / `.claude/skills/skill-todo/` — deployed copy purged and the root
  deploy ledger regenerated; no longer lists `skill-todo`.
- `agent-system/extensions/core/context/architecture/system-overview.md` — `/todo` routing row
  no longer names a skill.
- `agent-system/extensions/core/context/reference/skill-agent-mapping.md` — `skill-todo` row
  removed.
- `agent-system/extensions/core/merge-sources/claudemd.md` — `skill-todo` mapping row removed.
- `agent-system/extensions/core/README.md` — `skill-todo/` tree entry removed.
- `agent-system/extensions/core/context/patterns/roadmap-update.md` — names `commands/todo.md`
  instead of the removed skill.
- `agent-system/extensions/core/context/patterns/context-protective-lead.md` — `skill-todo` row
  annotated as historical (point-in-time audit record), matching the existing
  `skill-orchestrator` row's convention.
- `agent-system/extensions/core/context/patterns/task-lock.md` — dropped `skill-todo` from the
  `--state-file`/`--init` caller list; moved it into the "since deleted outright" framing
  rather than leaving it among state-write.sh survivors.
- `agent-system/extensions/core/context/standards/git-staging-scope.md` — "Two mechanisms"
  framing collapsed to the one live call site (`commands/todo.md`'s accumulator); the
  hand-written-`git add`-line shape kept as a described-but-not-exemplified general pattern.
- `agent-system/extensions/core/context/standards/task-reference-exemptions.md` — `.memory/**`
  coverage claim re-grounded on a verified live writer (the memory extension's `skill-learn`,
  invoked by `/distill --learn`), not a substituted, unverified one.
- `agent-system/extensions/core/scripts/validate-state.sh` — comment re-grounded on the sparse
  archive-entry shape itself, no producer named.
- `agent-system/extensions/core/scripts/tests/test-validate-state.sh` — fixture (h)'s comment
  and pass message re-grounded the same way; the assertion itself unchanged (78/78 pass).
- `agent-system/extensions/core/scripts/skill-base.sh` — comment re-pointed at `commands/todo.md`'s
  own archival jq, which has the identical shape.
- `agent-system/extensions/core/scripts/lib/engine-written-state-paths-lib.sh` — CHANGE_LOG
  comment corrected to state no live path writes it (fact only, no verdict on whether it should).
- `agent-system/extensions/core/scripts/lint/lint-postflight-boundary.sh` — `skill-todo` removed
  from the direct-execution-skills comment list.
- `agent-system/extensions/core/scripts/deprecated/README.md` — both quarantine notes now name
  `commands/todo.md` alone as the authoritative implementation.

## Decisions

- `commands/todo.md` is the survivor; `skill-todo` removed outright (plan's option (b)), not
  thin-delegated — it is the only implementation either consumer system dispatches, is smaller,
  and its removal leaves `context/reference/state-management-schema.md`'s vault-renumbering
  attribution true without any edit to that file.
- `skill-todo`'s "TODO.md orphan" detection dropped as obsolete, not ported: TODO.md is
  generated from state.json, so the condition it guarded against is structurally unreachable
  under current tooling.
- Task 626 (names `skills/skill-todo/SKILL.md`, now nonexistent, in its own `file_scope`) is
  flagged for its next revision, not edited here, per the plan's explicit instruction.

## Plan Deviations

- **Task 2 (manifest.json edit)**: added a second `manifest.json` edit (a `provides.scripts`
  registration for the Phase-1-created test file) beyond the phase's planned `extension.skills[]`
  removal — a plan gap, not an intentional skip. Without it the deploy copier never actually
  deployed the new test file.
- **Phase 4's "run the complete battery" task**: discharged against this dispatch's own Batch
  Gate Deferral directive (one of several implement-phase dispatches inside a multi-task
  `/orchestrate` batch invocation) as a scoped `verify-deploy.sh --only-gate 5,6,8,9,10,12,13`
  plus a standalone `validate-index.sh`, deferring the complete, unscoped gate set to the
  batch-level stage rather than running it independently in this dispatch.
- **Phase 2 and Phase 4's literal "zero `skill-todo` hits" / "every gate green" verification
  bullets**: not satisfied verbatim. Each phase's own `#### Reasoned Exclusions` table in the
  plan records the specific, evidenced reason — pre-existing out-of-scope findings (gates 4, 20,
  29), environment-flaky lints that pass standalone (gates 21, 23), two gate-8 suite failures
  confirmed unrelated to `skill-todo`/`todo.md` by direct content inspection, and two deliberate
  `skill-todo` string retentions the plan's own per-task instructions required keeping (a
  historical audit annotation and a "since deleted outright" statement).

## Verification

- Build: N/A (markdown/shell configuration task)
- Tests: `test-todo-archived-projects-scan.sh` 6/6, `test-todo-move-pair-staging.sh` 24/24,
  `test-validate-state.sh` 78/78, `run-all.sh` (gate 8) 186 passed / 7 failed (5 already-tracked
  `known-failures.txt` rows + 2 confirmed-unrelated NEW failures, reconfirmed identical across
  three independent re-runs)
- Files verified: Yes — `skill-todo/SKILL.md` absent from source store and deployed tree;
  `manifest.json` clean; gates 5, 6, 9, 10, 12, 13 green; `validate-index.sh` PASSED (309
  entries, 76092 lines); `check-task-references.sh`/`check-record-versioning.sh` show zero
  findings in any file this task touched

## Impacts

- `/todo` now has exactly one authoritative implementation; `Skill(skill-todo)` is deliberately
  and completely deregistered.
- The `archived_projects`-blind detection bug is fixed once, pinned by a regression test; an
  abandoned-then-archived task directory is no longer reported as an orphan.
- The vault operation (task renumbering) now exists in exactly one live place, making
  `context/reference/state-management-schema.md`'s existing attribution true by construction
  rather than merely accurate by luck.
- Net reduction of 945 lines across this task's own touched paths (13978 -> 13033).

## Follow-ups

- Task 626 names `skills/skill-todo/SKILL.md` (now nonexistent) in its own `file_scope`; its
  wiring target should become `commands/todo.md` when it is next revised.
- `agent-system/extensions/core/index-entries.json`'s line-count auto-repair (triggered by this
  task's own edits) landed on disk via the Phase 4 redeploy but was dropped from this task's
  commit by the Containment Self-Check (not in this task's declared `file_scope`); it remains an
  uncommitted, correct, mechanical correction for a future task or routine deploy cycle to pick
  up.
- Gate 8's two "NEW" suite failures (`test-deploy-propagation.sh`, `test-gate-registry-resolution.sh`)
  are confirmed unrelated to this task but are not yet recorded in
  `scripts/tests/known-failures.txt`; a follow-up could add rows there, owned by whoever
  triages those suites' root causes (a documented "two-engine defect" and the pre-existing
  gate-29 typescript violation, respectively).

## References

- Plan: `specs/458_consolidate_duplicated_todo_implementation/plans/01_consolidate-todo-implementations.md`
- Report: `specs/458_consolidate_duplicated_todo_implementation/reports/01_consolidate-todo-implementations.md`
- Handoffs: `specs/458_consolidate_duplicated_todo_implementation/handoffs/phase-{1,2,3,4}-handoff-*.md`
