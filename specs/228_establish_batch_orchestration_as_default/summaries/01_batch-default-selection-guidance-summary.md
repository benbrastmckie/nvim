# Implementation Summary: Task #228

- **Task**: 228 - Establish batch orchestration as the documented default, with batch-selection
  criteria and an explicit conflict rule
- **Status**: [COMPLETED]
- **Started**: 2026-09-18T23:28:45Z
- **Completed**: 2026-09-19T00:25:00Z
- **Effort**: ~1 hour
- **Dependencies**: None
- **Artifacts**: plans/01_batch-default-selection-guidance.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Documentation-only change in the source store (`agent-system/extensions/core/`). Added one
canonical section, `## Batching Is the Default: Selection Criteria and Conflict Resolution`, to
`context/patterns/batch-orchestration-guardrails.md`, establishing that batching related open
tasks into one `/orchestrate` invocation is the normal way to work this system, with an explicit
dominance rule (shared file territory > topic cohesion > graph shape/width) and a definite winner
for each of the three pairwise conflicts. Three entry-point files were updated to point at it
without restating it, and `multi-task-operations.md`'s Overview no longer frames single-task
input as "the common case".

## What Changed

- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` — widened the
  opening paragraph by one clause (admission control -> admission control and batch composition);
  inserted the new canonical section (posture statement, "Why batch-as-default" collision-
  visibility argument, the three selection criteria, the dominance rule with three numbered
  sub-rules, a three-row pairwise-conflict table with a definite winner in each row, the
  `MAX_TASKS=8` batch-size-cap rule, a "territory is a human judgment, not a machine derivation"
  scope note, and a deterministic worked example (`A`-`E`, plus an `F` variant demonstrating
  territory-beats-topic)).
- `agent-system/extensions/core/commands/orchestrate.md` — appended a one-sentence pointer to the
  new section under the Constraints bullet that already states the mechanism is uniform for a
  batch of one or many.
- `agent-system/extensions/core/merge-sources/claudemd.md` — appended a one-sentence pointer to
  the same section at the end of the "Multi-task syntax" paragraph.
- `agent-system/extensions/core/context/patterns/multi-task-operations.md` — reframed the
  Overview's opening sentence (no longer says workflow commands "traditionally accept a single
  task number") and replaced the "(zero overhead for common case)" design-principle bullet with
  "(no special-casing overhead for a batch of one)"; added a pointer sentence to the canonical
  section. Scope was kept to the Overview only, per the plan's Non-Goals.

## Decisions

- Followed the plan's three required fixes to the research-drafted text rather than pasting it
  verbatim: dropped the internally-contradictory "avoid a batch that is neither connected nor
  independent" clause (rule 3 is now a residual tie-breaker, not an exclusion rule); replaced the
  non-actionable "Situational" answer to the topic-vs-width conflict with a crisp "topic beats
  width" rule (fill open slots with dispatch-safe same-topic candidates before any off-topic
  filler); added the `MAX_TASKS=8` batch-size-cap subsection (list territory-mandatory members
  first so a trim can never split a territory group; if a territory group alone exceeds 8, run
  consecutive batches and accept the visibility loss explicitly).
- Left `index-entries.json`'s stale `line_count` for the guardrails entry untouched (declared
  1097, actual 1213 after the new section) because the file is currently dirty with a concurrent
  sibling task's own declared-scope, in-flight changes — recorded below as a follow-up rather than
  risking a collision on a file outside this task's `file_scope`.

## Plan Deviations

- None (implementation followed plan).

## Verification

- Build: N/A (documentation-only)
- Tests: N/A
- Files verified: Yes — `grep -c "^## Batching Is the Default"` returns 1; the conflict table has
  exactly three rows, none reading "Situational"; no "avoid a batch that is neither connected nor
  independent" clause remains; `MAX_TASKS` and the trim/ordering rule are present; `grep -n
  "common case"` in `multi-task-operations.md` returns nothing; `grep -rn "Batching Is the
  Default"` across the four touched files returns exactly 4 hits (the guardrails heading plus one
  pointer each in `orchestrate.md`, `claudemd.md`, `multi-task-operations.md`); neither pointer
  file contains "dominance", "territory >", or a conflict table; `check-task-references.sh`
  reports 0 unexempted occurrences in all four touched files; `git log --stat` over this task's
  four implementation commits (`625afda1f`, `89c221ea7`, `ea849d410`, `5f5b69efa`, plus the
  phase-3 and status commits `77a1e466c`, `a222695de`) touches only the four `file_scope` files
  and this task's own `specs/228_...` artifacts — no script, predicate, or dispatch-path file was
  modified.

## Impacts

- A reader with several open same-topic tasks now has one canonical place to learn which tasks to
  batch into a single `/orchestrate N[,N-N]` invocation, with a definite rule for every conflict
  between the three selection criteria, rather than no guidance at all (the gap this task's
  research confirmed was real via a zero-hit grep across the three candidate files).
- No behavioral change: no script, admission predicate, wave-computation, or dispatch-path file
  was touched. The change is purely how the existing, already-uniform batching mechanism is
  framed and how a human should choose what to batch.

## Follow-ups

- `agent-system/extensions/core/index-entries.json`'s `batch-orchestration-guardrails.md` entry
  has a stale `line_count` (declared 1097, actual 1213). Run
  `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --write` once the
  file is free of the concurrent sibling task's in-flight, declared-scope changes. Optionally add
  `"selection"`/`"batch-composition"` to that entry's `keywords` array at the same time.
- `multi-task-operations.md`'s Overview still describes `/research`, `/plan`, and `/implement` as
  the commands this pattern extends, even though the file's own Section 6 "Superseded note" says
  those commands (and the skill layer they dispatched to) have since been deleted, leaving
  `/orchestrate` as the sole multi-task-capable entry point. This second staleness was flagged by
  research as out of this task's required Acceptance scope (only the "common case" phrase was
  required to change) and is left for separate work.

## References

- Plan: `specs/228_establish_batch_orchestration_as_default/plans/01_batch-default-selection-guidance.md`
- Research report: `specs/228_establish_batch_orchestration_as_default/reports/01_batch-selection-criteria.md`
- Commits: `625afda1f`, `89c221ea7`, `ea849d410`, `5f5b69efa`, `77a1e466c`, `a222695de`
