# Implementation Summary: Task #392

- **Task**: 392 - Refactor present extension commands (/grant, /budget, /funds, /timeline, /talk)
- **Status**: [COMPLETED]
- **Started**: 2026-04-09T12:00:00Z
- **Completed**: 2026-04-09T13:30:00Z
- **Effort**: 1.5 hours
- **Artifacts**:
  - [Plan](../plans/02_refactor-present-commands.md)
  - [Summary](02_refactor-present-commands-summary.md) (this file)
- **Standards**: status-markers.md, artifact-management.md, tasks.md, summary-format.md

## Overview

Unified all 5 present extension commands to use `language: "present"` with `task_type` for subtype differentiation, standardized model specifications to `opus`, fixed routing in manifest and index entries, and added structural enhancements (grant pre-task intake, timeline Stage 0 restructure, talk --design flag).

## What Changed

- All 5 commands (grant, budget, timeline, funds, talk) now create tasks with `language: "present"` and appropriate `task_type`
- All model specifications changed from `claude-opus-4-5-20251101` to `opus` (5 commands, 1 agent)
- 17 grant-domain index-entries.json entries updated from `"languages": ["grant"]` to `"languages": ["present"]`
- Removed bare `"grant"` key from manifest.json implement routing (dead code)
- EXTENSION.md routing table updated: grant row now shows `present | grant`
- Grant command: Added Stage 0 with 4 AskUserQuestion calls (mechanism, content paths, regulatory, constraints), stores as `forcing_data`
- Timeline command: Moved 3 existing forcing questions from research mode to pre-task Stage 0, extended to 6 questions (mechanism, period, aims count, milestones, regulatory, aims path)
- Talk command: Added `--design` flag for post-research design confirmation (theme, message ordering, section emphasis), stores as `design_decisions`

## Decisions

- Grant-agent dynamic context query changed from `languages == "grant"` to `languages == "present" and agents == "grant-agent"` to avoid returning all present entries
- Design confirmation for talks handled at command level (not agent level) per existing AskUserQuestion constraints on agents
- Budget command validation simplified from checking both "budget" and "grant" to just "present"

## Impacts

- All present extension tasks will now route correctly through the unified `language: "present"` with `task_type` differentiation
- Existing tasks with old language values ("grant", "budget", "timeline") in state.json would need manual migration if any existed (none currently active)
- The planner agent should check for `design_decisions` in task metadata when planning talk tasks

## Follow-ups

- Consider updating the present extension README.md to document all 5 command capabilities comprehensively
- Consider extracting a shared forcing-question framework for cross-command consistency

## References

- `specs/392_refactor_present_extension_commands/reports/01_refactor-present-commands.md`
- `specs/392_refactor_present_extension_commands/reports/02_team-research.md`
- `specs/392_refactor_present_extension_commands/plans/02_refactor-present-commands.md`
