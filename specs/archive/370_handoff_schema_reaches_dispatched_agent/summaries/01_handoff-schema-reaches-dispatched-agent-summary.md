# Implementation Summary: Task #370

- **Task**: 370 - Make the `.orchestrator-handoff.json` schema reach the dispatched agent before it writes the handoff
- **Status**: [COMPLETED]
- **Started**: 2026-10-09T05:08:17Z
- **Completed**: 2026-10-09T06:55:00Z
- **Effort**: ~1.7 hours
- **Dependencies**: None declared
- **Artifacts**: plans/01_handoff-schema-reaches-dispatched-agent.md, reports/01_handoff_schema_reaches_dispatched_agent.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Implemented route (b) from the task description and plan: repaired the one agent contract
(`lean-implementation-hard-agent.md`) whose handoff-writing section omitted the `artifacts`
requirement, corrected the now-stale architecture-doc claim naming this gap, and added a new
section-scoped lint check (`check_j_handoff_section_artifacts`) to `lint-agent-contracts.sh` so
this regression class is caught mechanically rather than discovered only when the validator
fails after work is already done. All four phases completed; Phase 4 closed with one recorded,
reasoned exclusion attributable to a concurrently-dispatched sibling task, not to this task's
own work.

## What Changed

- `agent-system/extensions/lean/agents/lean-implementation-hard-agent.md` — Stage 5's handoff
  JSON example gained `"artifacts": [{"path": "...", "type": "summary", "summary": "..."}]`,
  lost the stale `"continuation_context": null` line, and gained an `artifacts`-linking-rationale
  paragraph (stating the `partial`-status conditional explicitly, citing
  `context/contracts/wrap-up.md`) plus a `continuation_path` population rule and a "never write
  the nested object" instruction, mirroring the already-correct `cslib-implementation-hard-agent.md`.
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` — the Writers table's Notes
  cell no longer asserts the now-closed "Two known, named, unlanded gaps" claim; it states the
  current design (every writer carries the `artifacts`-shape spec and the `partial`-status
  conditional, and emits only the flat `continuation_path`).
- `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` — new
  `check_j_handoff_section_artifacts()` (Check J), registered in `main()` after Check I. Bounds
  its scan to each writer's own handoff-writing section (two recognized heading forms, excluding
  "never write one" research-agent headings), and detects either live statement form (prose
  `{type, path, summary}` triple or quoted JSON keys) rather than reusing Check F's whole-file
  `has_artifacts_object_shape` unmodified (which would have failed 44 of 45 correct writers).
  FAILs loudly, never silently, on a heading-drift case.
- `agent-system/extensions/core/scripts/tests/test-lint-agent-contracts-handoff-section.sh` — new
  fixture-driven test file (auto-discovered by `run-all.sh`, no manual registration) covering all
  six required cases: prose-form PASS, JSON-form PASS, missing-artifacts FAIL, the Check-F-blind-
  spot FAIL, the never-write-one skip, and the heading-drift FAIL.

## Decisions

- **Route (b)** was selected and implemented exactly as researched and planned: the fix lives in
  the implementation agents' own contracts plus a lint-able, mechanically-checkable rule — never
  a second, unread prose document (the task's explicit failure condition).
- **The `partial`-status conditional ("ALSO DECIDE")** — settled, not re-decided: `artifacts` is
  always a required array; non-empty is required only when `status` is
  `researched`/`planned`/`implemented`; `[]` is legal and expected for
  `partial`/`blocked`/`failed`. This was already the consistent rule across
  `context/schemas/orchestrator-handoff-schema.json`, `scripts/validate-handoff.sh`, and
  `context/contracts/wrap-up.md` (re-confirmed read-only during Phase 1); this task's job was to
  make it reachable by the dispatched agent, which it now is, stated inline in the repaired
  Stage 5 contract.
- **Check J's detection predicate** accepts either of the two live statement forms (prose triple
  or quoted JSON keys) rather than an exact-sentence match or Check F's unmodified predicate —
  measured during planning and re-confirmed during implementation that the latter would fail 44
  of 45 correct writers.
- **No ordering edge against the file-overlapping, unscheduled backlog item** was added (per the
  plan's reasoning): the one shared file (`lint-agent-contracts.sh`) was edited as a pure
  append, and the one test-file overlap was removed entirely by using a new test file, so the
  overlap is resolved by construction rather than by blocking this task's whole scope behind
  unrelated, unscheduled work.

## Plan Deviations

- **Phase 4, Task 4** (`verify-deploy.sh` complete gate set): altered. 34 of 35 gates PASS; the
  one remaining failure (doc-lint's `STRICT_CORE_DEPLOY` advisory for
  `agent-system/extensions/books/scripts/books-observe.sh`) is caused by a concurrently-dispatched,
  unrelated sibling task's in-flight, uncommitted edits to the `books` extension (28 uncommitted
  files at measurement time; last real commit on that file was an unrelated prior task) — outside
  this task's declared `file_scope` and unresolvable by further work in this dispatch. A first
  full run also showed a second, transient failure (content-hash mismatch on
  `general-implementation-agent.md`/`lean-implementation-agent.md`, both in a concurrent sibling's
  declared `file_scope` per this dispatch's own Territory section) that self-resolved once that
  sibling committed mid-wait, confirming the diagnosis. See the plan's Phase 4 Reasoned
  Exclusions table for the full record.
- One recorded, non-fatal issue (not a deviation from a plan step, but worth noting): the plan's
  Phase 3 covering-suite list named `test-verify-deploy-context-budget.sh`, which is unrelated,
  pre-existing, and independently slow/flaky (confirmed via `git log` that no commit of this
  task touches it) — excluded from the green-verification claim; the other five named suites all
  pass cleanly.

## Verification

- Build: N/A (no build system for this change)
- Tests: Passed — `lint-agent-contracts.sh` reports Check J 45/45 PASS, 0 FAIL, overall lint
  PASSED WITH WARNINGS (13 pre-existing, unrelated heartbeat-adoption warnings); new test file
  `test-lint-agent-contracts-handoff-section.sh` passes all 6 fixture assertions and is
  auto-discovered by `run-all.sh`; regression demonstrated live (reverting Phase 1's fix in a
  scratch copy makes Check J FAIL specifically on `lean-implementation-hard-agent.md` with the
  expected message, then the scratch copy was removed).
- Files verified: Yes — deployed `.claude/agents/lean-implementation-hard-agent.md` and
  `.claude/scripts/lint/lint-agent-contracts.sh` confirmed byte-identical to their source-store
  counterparts after `deploy-headless.sh`.

## Impacts

- A dispatched `lean-implementation-hard-agent` now reads the `artifacts` requirement, its
  object shape, and the `partial`-status conditional directly in the Stage 5 contract it follows
  when writing `.orchestrator-handoff.json` — closing the exact gap the measured incident
  exposed, before the validator runs rather than after.
- Any future agent file whose handoff-writing section drifts away from stating this requirement
  will now FAIL `lint-agent-contracts.sh` (gate 6 of `verify-deploy.sh`) by name, rather than the
  gap surfacing only in a live `/orchestrate` run's validator failure.

## Follow-ups

- None required by this task's acceptance bar. The task description's own backlog reconciliation
  found no open task to fold this into; a lint-able mechanical check was explicitly preferred
  over a new document per the task's stated failure condition.
- The books-extension doc-lint advisory recorded as a Phase 4 exclusion is expected to clear on
  its own once that unrelated, concurrently-dispatched sibling task commits; no follow-up task is
  needed for it.

## References

- Plan: `specs/370_handoff_schema_reaches_dispatched_agent/plans/01_handoff-schema-reaches-dispatched-agent.md`
- Report: `specs/370_handoff_schema_reaches_dispatched_agent/reports/01_handoff_schema_reaches_dispatched_agent.md`
- Progress files: `specs/370_handoff_schema_reaches_dispatched_agent/progress/phase-{1,2,3,4}-progress.json`
- Handoffs: `specs/370_handoff_schema_reaches_dispatched_agent/handoffs/phase-{1,2,3}-handoff-*.md`
