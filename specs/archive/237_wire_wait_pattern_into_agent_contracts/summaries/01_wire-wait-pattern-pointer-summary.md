# Implementation Summary: Task #237

- **Task**: 237 - Wire the external-process wait pattern into the general implementation and research agent contracts
- **Status**: [COMPLETED]
- **Started**: 2026-09-19T01:25:00Z
- **Completed**: 2026-09-19T01:35:00Z
- **Effort**: ~20 minutes
- **Dependencies**: 236 (created `context/patterns/external-process-wait.md`)
- **Artifacts**: plans/01_wire-wait-pattern-pointer.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Added a short "External Process Wait Discipline" pointer block, plus one load-on-demand
`## Context References` line, to both `general-research-agent.md` and
`general-implementation-agent.md` in the source store. Each block cites the pattern file's
numbered rules (1, 2, 3, 5, 6) by reference rather than restating their mechanics, and each
routes the "then handoff" step of Rule 6 to the file's own existing handoff stage (Stage 3.6 in
research, Stage 4C in implementation).

## What Changed

- `agent-system/extensions/core/agents/general-research-agent.md` — added a Context References
  line pointing to `external-process-wait.md`, and a new `### External Process Wait Discipline`
  subsection between Stage 3.5 (Context Exhaustion Monitoring) and Stage 3.6 (Handoff on Context
  Pressure), with MUST bullets (Rules 1, 5, 6) and MUST NOT bullets (Rules 2, 3).
- `agent-system/extensions/core/agents/general-implementation-agent.md` — added a Context
  References line pointing to `external-process-wait.md`, and a bold-label
  `**External Process Wait Discipline**` block inside Stage 4.5's bullet list, before the
  "Derive `project_name`" paragraph, with the same MUST/MUST NOT bullet shape (Rule 6 naming
  Stage 4C below instead of Stage 3.6).

## Decisions

- Followed the research report's exact ready-to-apply text verbatim (it had already been
  test-fit and reverted during research), rather than redrafting.
- Left the plan-level `- **Status**:` field on the plan file untouched — that field is owned by
  the state-sync/postflight machinery, not this dispatch's phase-heading updates.
- Confirmed `lint-contract-compliance.sh` is scoped to hard-mode contract wiring only and does
  not apply to these two non-hard core agent files, so it was not run against them beyond noting
  the scope mismatch.

## Plan Deviations

- None (implementation followed plan)

## Verification

- Build: N/A
- Tests: N/A
- Files verified: Yes — `grep -c "external-process-wait"` returns 3 in each file (Context
  References line plus two mentions inside the block); both blocks sit at their researched
  anchors; `check-task-references.sh` scoped to `agent-system/extensions/core/agents` reports 0
  occurrences; `lint-agent-contracts.sh` passes 104/104 checks with 0 failures; both blocks cite
  Rules 1, 2, 3, 5, 6 matching the pattern file's `### N.` headings; no lines in the added text
  exceed ~100 characters; `git status` after all three phase commits shows no stray edits to
  `.claude/**`, extension agents, or sibling-territory files from this task.

## Impacts

- A dispatched `general-research-agent` or `general-implementation-agent` subagent now has an
  explicit, load-on-demand pointer to the bounded-wait discipline whenever it must wait on a
  long-running external/remote process (e.g. a CI run), directly addressing the incident that
  motivated this task (unbounded `gh run watch`, Monitor-driven wake-ups, and no-op filler calls
  burning context).

## Follow-ups

- A follow-up task, scoped explicitly to the four `-hard` extension agent variants
  (`cslib-implementation-hard-agent.md`, `lean-implementation-hard-agent.md`,
  `cslib-research-hard-agent.md`, `lean-research-hard-agent.md`), to wire the same pointer since
  they already carry a matching Context Exhaustion Monitoring stage.
- A separate evaluation of whether the remaining non-hard extension implementation/research
  agents need a lighter-weight Context Exhaustion Monitoring anchor added first, before they can
  carry the same pointer.

## References

- specs/237_wire_wait_pattern_into_agent_contracts/plans/01_wire-wait-pattern-pointer.md
- specs/237_wire_wait_pattern_into_agent_contracts/reports/01_wire_wait_pattern_pointer.md
- agent-system/extensions/core/context/patterns/external-process-wait.md
